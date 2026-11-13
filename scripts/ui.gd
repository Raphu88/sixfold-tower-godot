extends RefCounted
## The interface's shared look: the palette, the fonts, the panel, button,
## slot and card styles, the ornaments (double rules, corner flourishes,
## eyebrow labels) and the drawn pieces (bars, gems, medallions, emblems),
## used by the HUD (hud.gd), the menus (menu.gd, rail.gd and the pages) and
## the touch buttons, so they read as one set. (The world's colours are in
## palette.gd; the interface's are here.)
##
## The look: a deep violet-indigo night, gilt edges and lettering, warm
## parchment ink, thin-bordered cards with a soft inner glow, small gothic
## eyebrow labels, and essence colours for essence things. Every title,
## label, button and name is set in Grenze Gotisch, the text under them in
## its plain sibling Grenze, and words written in the world or quoted in
## Cormorant Garamond Italic (all SIL Open Font License, in assets/fonts
## with their OFL.txt; see ROLES). Everything else is drawn in code.

# --- the palette ------------------------------------------------------------------
## The night: from the void behind everything up to a raised button's face.
static var VOID := Color(0.051, 0.043, 0.071)  # #0d0b12
static var STONE := Color(0.106, 0.094, 0.137)  # #1b1823
static var STONE_2 := Color(0.141, 0.125, 0.18)  # #24202e
static var STONE_3 := Color(0.176, 0.157, 0.224)  # #2d2839
## Thin lines: a card's edge, and a brighter one for hover and dividers.
static var LINE := Color(0.227, 0.204, 0.275)  # #3a3446
static var LINE_HI := Color(0.416, 0.376, 0.502)  # #6a6080
## Gilt: lettering, the chosen thing, ornament. GILT_HI is its lit edge,
## GILT_DEEP its shadow (a primary button's lower half).
static var GILT := Color(0.886, 0.71, 0.353)  # #e2b55a
static var GILT_HI := Color(0.97, 0.85, 0.58)
static var GILT_DEEP := Color(0.42, 0.29, 0.1)
## A cool periwinkle for the Entity and secondary highlights, and violet.
static var PERIWINKLE := Color(0.56, 0.69, 1.0)  # #8fb0ff
static var VIOLET := Color(0.79, 0.65, 1.0)  # #c9a6ff
static var BLOOD := Color(0.816, 0.314, 0.247)  # #d0503f

# Interface colours (the names the rest of the game uses)
static var GOLD := Color(0.91, 0.75, 0.42)  # gilt, a touch brighter for small lettering
static var TEXT := Color(0.925, 0.89, 0.81)  # parchment ink, #ece3cf
static var DIM := Color(0.66, 0.62, 0.71)  # muted, #9a92a6 lifted for small text
static var FAINT := Color(0.45, 0.41, 0.53)
static var PANEL := Color(0.075, 0.064, 0.1, 0.9)
static var PANEL_EDGE := Color(0.91, 0.75, 0.42, 0.22)
static var MENU_PANEL := Color(0.09, 0.078, 0.118, 0.97)
static var SLOT := Color(0.07, 0.06, 0.095, 0.94)
static var SLOT_EDGE := Color(0.3, 0.27, 0.36, 0.95)
static var SLOT_ON := Color(0.2, 0.145, 0.07, 0.96)
static var BUTTON := Color(0.176, 0.157, 0.224)  # STONE_3
static var BUTTON_HOVER := Color(0.22, 0.196, 0.28)
static var BUTTON_DOWN := Color(0.3, 0.22, 0.12)
static var SHADE := Color(0.03, 0.024, 0.045, 0.8)
static var GOOD := Color(0.56, 0.88, 0.52)
static var BAD := Color(0.98, 0.5, 0.42)
static var HEALTH := Color(0.78, 0.22, 0.2)
static var STAMINA := Color(0.45, 0.72, 0.38)
## The Entity's speech bubbles (its own colours are in entity.gd).
static var ENTITY_BG := Color(0.11, 0.09, 0.19)
static var ENTITY_EDGE := Color(0.79, 0.75, 1.0, 0.42)

## The train between climbs (train_view.gd draws it behind its pages):
## brass trim and rivets, oxblood cars, a bottle-green engine, warm windows.
const TRAIN_BRASS := Color(0.86, 0.64, 0.3)
const TRAIN_COPPER := Color(0.72, 0.4, 0.24)
const TRAIN_CAR := Color(0.33, 0.13, 0.12)
const TRAIN_ENGINE := Color(0.14, 0.27, 0.23)
const TRAIN_IRON := Color(0.12, 0.11, 0.13)
const TRAIN_ROOF := Color(0.2, 0.17, 0.19)
const TRAIN_WINDOW := Color(1.0, 0.76, 0.42)
const TRAIN_SMOKE := Color(0.72, 0.68, 0.74)
const TRAIN_SKY := [Color(0.05, 0.04, 0.09), Color(0.17, 0.1, 0.17), Color(0.46, 0.25, 0.2)]
const TRAIN_GROUND := Color(0.07, 0.06, 0.07)

## Text sizes (at the desktop scale; phones draw everything 1.5x bigger).
## Grenze is narrow for its size, so text can sit a point above what a
## plain sans would use and take no more room across.
const SIZE_SMALL := 13
const SIZE_BODY := 15
const SIZE_LABEL := 17
const SIZE_HEADING := 32
## Eyebrow labels (a small gothic label over a title or section).
const SIZE_EYEBROW := 14
## Words written in the world, quoted or spoken (rule panels, riddles, the
## Makers' words, mottos, flavour lines). Cormorant is small for its size
## (a low x-height), so inscriptions sit two points above body text.
const SIZE_INSCRIPTION := 17

## How long menus take to fade in and out (seconds).
const FADE_IN := 0.12
const FADE_OUT := 0.1


# --- fonts ------------------------------------------------------------------------
## The font files (SIL OFL; see assets/fonts and CREDITS.md): the gothic
## display face, its plain sibling for text, and a fine italic for
## inscriptions. Grenze and Cormorant are variable fonts: one file holds
## every weight, and ROLES picks one.
const FONT_FILES := {
	"gothic": "res://assets/fonts/grenze_gotisch/GrenzeGotisch-Bold.ttf",
	"text": "res://assets/fonts/grenze/Grenze-VariableFont_wght.ttf",
	"fine": "res://assets/fonts/cormorant_garamond/CormorantGaramond-Italic-VariableFont_wght.ttf",
}
## The roles every script asks for (font(role)): [file, weight (0: the
## file's own), tabular figures]. Figures are always lining (not old-style),
## so numbers sit level.
##   display      Grenze Gotisch Bold: every title, heading, label, button,
##                tab, name and banner (in mixed case: see titled())
##   eyebrow      the same, for the small label over a title or section
##   body         Grenze Medium: descriptions, hints, numbers in text
##   regular      Grenze Regular
##   bold         Grenze SemiBold: a word picked out in body text
##   mono         Grenze SemiBold with tabular figures: key badges and
##                numbers that must line up
##   inscription  Cormorant Garamond SemiBold Italic: words written in the
##                world, quoted or spoken (see SIZE_INSCRIPTION)
##   italic       the same as inscription
const ROLES := {
	"display": ["gothic", 0, false],
	"eyebrow": ["gothic", 0, false],
	"body": ["text", 500, false],
	"regular": ["text", 400, false],
	"bold": ["text", 600, false],
	"mono": ["text", 600, true],
	"inscription": ["fine", 600, false],
	"italic": ["fine", 600, false],
}
static var _fonts := {}


## A font by its role (see ROLES): "display", "eyebrow", "body", "regular",
## "bold", "mono", "inscription" or "italic".
static func font(kind := "body") -> Font:
	if _fonts.is_empty():
		setup_fonts()
	return _fonts.get(kind, _fonts.get("body", ThemeDB.fallback_font))


## Loads the fonts once and makes the body font the game's default (every
## Control, and every label drawn with ThemeDB.fallback_font). Grenze has
## no arrows, so the fine italic stands behind the other two for those (its
## lines are shorter, so it doesn't make any line taller).
static func setup_fonts() -> void:
	if not _fonts.is_empty():
		return
	var files := {}
	for k in FONT_FILES:
		files[k] = load(FONT_FILES[k]) if ResourceLoader.exists(FONT_FILES[k]) else null
	if files["text"] == null:
		return  # (no fonts imported: keep Godot's own)
	for k in ROLES:
		var role: Array = ROLES[k]
		var base: Font = files[role[0]] if files[role[0]] != null else files["text"]
		var v := FontVariation.new()
		v.base_font = base
		if int(role[1]) > 0:
			v.variation_opentype = {"weight": int(role[1])}
		v.opentype_features = {"lnum": 1, "tnum": 1} if role[2] else {"lnum": 1, "pnum": 1}
		var fb: Array[Font] = []
		if role[0] == "gothic":
			fb.append(files["text"])
		if role[0] != "fine" and files["fine"] != null:
			fb.append(files["fine"])
		v.fallbacks = fb
		if role[0] == "text":
			# Grenze's lines are tall for its size (room for blackletter
			# capitals): three pixels off top and bottom keep text blocks
			# about as compact as before, at the sizes text is set in.
			v.spacing_top = -3
			v.spacing_bottom = -3
		elif role[0] == "gothic":
			# The same lines (Grenze Gotisch shares them): a little off, so
			# a column of gothic labels stays as compact as plain ones, and
			# still clears the capitals' tops and the descenders.
			v.spacing_top = -3
			v.spacing_bottom = -2
		_fonts[k] = v
	ThemeDB.fallback_font = _fonts["body"]


## Words in the gothic face read best in mixed case (blackletter capitals
## run together): "THE KRAKEN'S TOWER" and "the kraken's tower" both become
## "The Kraken's Tower". Mixed-case text keeps its capitals; only the first
## letters of its words are raised (small words like "of" stay low).
static func titled(t: String) -> String:
	if t == "":
		return t
	var shout := t == t.to_upper() and t != t.to_lower()
	var small := ["of", "the", "a", "an", "to", "and", "in", "on", "at", "for", "or", "by", "is"]
	var words := (t.to_lower() if shout else t).split(" ")
	var first := true
	for i in words.size():
		var w: String = words[i]
		if w == "" or not w.left(1).is_valid_identifier():
			continue
		if first or not (w in small):
			words[i] = w.left(1).to_upper() + w.substr(1)
		first = false
	return " ".join(words)


## A theme for Controls in the new look: the body font, ink text, and the
## gilt-edged buttons, toggles and sliders (menu.gd builds on it).
static func theme() -> Theme:
	var t := Theme.new()
	t.default_font = font("body")
	t.default_font_size = 18
	# Buttons and toggles are labels: the gothic face.
	t.set_font("font", "Button", font("display"))
	t.set_font("font", "CheckButton", font("display"))
	t.set_stylebox("panel", "PanelContainer", menu_panel())
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		t.set_stylebox(state, "Button", button_box(state))
	t.set_stylebox("focus", "CheckButton", focus_box())
	t.set_stylebox("focus", "HSlider", focus_box())
	for k in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		t.set_stylebox(k, "CheckButton", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color(1.0, 0.97, 0.9))
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", FAINT)
	t.set_color("font_focus_color", "Button", Color(1.0, 0.97, 0.9))
	t.set_color("font_hover_pressed_color", "Button", GOLD)
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_hover_color", "CheckButton", Color(1.0, 0.97, 0.9))
	t.set_color("font_focus_color", "CheckButton", GOLD)
	t.set_color("font_pressed_color", "CheckButton", TEXT)
	t.set_color("font_color", "Label", TEXT)
	# Sliders: a thin dark groove, gilt where it's filled, a gilt knob.
	var groove := box(Color(VOID, 0.9), LINE, 3)
	groove.content_margin_top = 3
	groove.content_margin_bottom = 3
	t.set_stylebox("slider", "HSlider", groove)
	var fill := box(Color(GILT, 0.75), Color(GILT_HI, 0.6), 3)
	fill.content_margin_top = 3
	fill.content_margin_bottom = 3
	t.set_stylebox("grabber_area", "HSlider", fill)
	t.set_stylebox("grabber_area_highlight", "HSlider", fill)
	# Scroll bars: slim, a violet groove and a gilt-edged grip.
	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, box(Color(VOID, 0.6), Color(0, 0, 0, 0), 3))
		t.set_stylebox("grabber", bar, box(Color(LINE_HI, 0.7), Color(0, 0, 0, 0), 3))
		t.set_stylebox("grabber_highlight", bar, box(Color(GILT, 0.6), Color(0, 0, 0, 0), 3))
		t.set_stylebox("grabber_pressed", bar, box(Color(GILT, 0.85), Color(0, 0, 0, 0), 3))
	return t


# --- panels, buttons, slots ---------------------------------------------------------

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
	var b := box(PANEL, PANEL_EDGE, 6)
	b.shadow_color = Color(0, 0, 0, 0.3)
	b.shadow_size = 3
	return b


## An item or gear slot; `on` for the one in hand: a dark inset well with a
## thin edge (gilt for the one in hand).
static func slot(on := false) -> StyleBoxFlat:
	var b := box(SLOT_ON if on else SLOT, GOLD if on else SLOT_EDGE, 5)
	if on:
		b.shadow_color = Color(GILT, 0.22)
		b.shadow_size = 4
	return b


## The menus' big panel: a deep violet slab, lighter at the top, edged with a
## thin line and a gilt hairline inside it, gilt flourishes at the corners.
static func menu_panel() -> StyleBox:
	var b := Ornate.new()
	b.top = Color(0.13, 0.115, 0.17, 0.98)
	b.bottom = Color(0.06, 0.052, 0.082, 0.98)
	b.edge = Color(LINE_HI, 0.7)
	b.inner = Color(GILT, 0.16)
	b.corners = Color(GILT, 0.7)
	b.glow = Color(0.62, 0.5, 0.95, 0.07)
	b.radius = 8.0
	b.shadow = 14.0
	b.grain = true
	b.set_content_margin_all(22.0)
	return b


## A card inside a page (a mark, a spell, a camp choice): stone, a thin
## line edge, a faint glow along the top; `accent` tints the edge and glow
## (an essence's colour), `strip` draws a coloured bar down its left side.
static func card(accent := Color(0, 0, 0, 0), strip := false, margin := 12.0) -> Ornate:
	var b := Ornate.new()
	b.top = Color(0.13, 0.115, 0.165, 0.95)
	b.bottom = Color(0.085, 0.075, 0.11, 0.95)
	b.edge = Color(LINE, 1.0) if accent.a <= 0.0 else Color(accent.lerp(LINE, 0.45), 0.9)
	b.glow = Color(1, 1, 1, 0.035) if accent.a <= 0.0 else Color(accent, 0.1)
	b.radius = 6.0
	b.highlight = true
	if strip and accent.a > 0.0:
		b.strip = accent
	b.set_content_margin_all(margin)
	if strip:
		b.content_margin_left = margin + 3.0
	return b


## A button's look in one state ("normal", "hover", "pressed", "focus",
## "disabled"): a raised violet face, lit along its top edge.
static func button_box(state: String) -> StyleBox:
	if state == "focus":
		return focus_box()
	var b := Ornate.new()
	b.radius = 6.0
	b.highlight = true
	b.drop = true
	match state:
		"hover":
			b.top = Color(0.235, 0.21, 0.3)
			b.bottom = Color(0.16, 0.14, 0.21)
			b.edge = Color(GILT, 0.5)
			b.glow = Color(GILT, 0.06)
		"pressed":
			b.top = Color(0.22, 0.16, 0.09)
			b.bottom = Color(0.3, 0.22, 0.12)
			b.edge = Color(GILT, 0.6)
			b.highlight = false
			b.drop = false
		"disabled":
			b.top = Color(0.13, 0.12, 0.16, 0.6)
			b.bottom = Color(0.1, 0.09, 0.13, 0.6)
			b.edge = Color(LINE, 0.6)
			b.highlight = false
			b.drop = false
		_:
			b.top = Color(0.18, 0.16, 0.23)
			b.bottom = Color(0.12, 0.106, 0.16)
			b.edge = Color(0.25, 0.22, 0.31)
	button_margins(b)
	return b


## The gilded look of a page's main button (or the chosen tab): a warm
## gold-brown face, a gilt edge and lit top.
static func primary_box(state := "normal") -> StyleBox:
	var b := Ornate.new()
	b.radius = 6.0
	b.highlight = true
	b.drop = state != "pressed"
	b.top = Color(0.36, 0.26, 0.12) if state != "hover" else Color(0.44, 0.32, 0.15)
	b.bottom = Color(0.2, 0.14, 0.06) if state != "hover" else Color(0.26, 0.18, 0.08)
	b.edge = Color(GILT, 0.85 if state == "hover" else 0.7)
	b.glow = Color(GILT_HI, 0.12)
	button_margins(b)
	return b


## Keys and controller: the focused control's gilt outline, with a soft glow.
static func focus_box() -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.draw_center = false
	s.set_corner_radius_all(7)
	s.anti_aliasing = true
	s.border_color = GILT_HI
	s.set_border_width_all(2)
	s.set_expand_margin_all(2)
	s.shadow_color = Color(GILT, 0.35)
	s.shadow_size = 6
	button_margins(s)
	return s


static func button_margins(s: StyleBox) -> void:
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 5
	s.content_margin_bottom = 6


## The Entity's speech bubble: deep violet, lighter at the top, a soft
## lavender edge and a periwinkle bar down its left side.
static func entity_bubble(margin := 10.0) -> StyleBox:
	var b := Ornate.new()
	b.top = Color(0.15, 0.125, 0.22, 0.96)
	b.bottom = Color(0.085, 0.07, 0.13, 0.96)
	b.edge = ENTITY_EDGE
	b.glow = Color(PERIWINKLE, 0.08)
	b.strip = Color(PERIWINKLE, 0.85)
	b.radius = 9.0
	b.shadow = 10.0
	b.highlight = true
	b.set_content_margin_all(margin)
	b.content_margin_left = margin + 3.0
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
## HUD sizes (a setting): how much bigger or smaller the HUD is drawn, on
## top of the Interface size.
const HUD_SCALES := {"small": 0.85, "normal": 1.0, "large": 1.2}
const HUD_SCALE_ORDER := ["small", "normal", "large"]
## Interface sizes (a setting, shared by every climber): how big the whole
## interface is drawn (menus, the rail, the train's interface, the HUD and
## the touch buttons), as [on a computer, on a phone]. The phone draws
## everything bigger; its Normal is 1.25x what the phone used to show (1.5x,
## now Small). (The game world keeps its size: see WORLD_ZOOMS.)
const UI_SIZES := {"small": [0.85, 1.5], "normal": [1.0, 1.875], "large": [1.2, 2.25], "larger": [1.4, 2.5]}
const UI_SIZE_ORDER := ["small", "normal", "large", "larger"]
const UI_SIZE_NAMES := {"small": "Small", "normal": "Normal", "large": "Large", "larger": "Larger"}
## World zoom (a setting): how close the camera is to the climber, times
## the zoom the game always used (main.gd CAMERA_ZOOM). A phone also starts
## a little closer (PHONE_WORLD) than it used to.
const WORLD_ZOOMS := {"normal": 1.0, "closer": 1.2, "closest": 1.4}
const WORLD_ZOOM_ORDER := ["normal", "closer", "closest"]
const WORLD_ZOOM_NAMES := {"normal": "Normal", "closer": "Closer", "closest": "Closest"}
const PHONE_WORLD := 1.15


## The interface's scale (the root's content scale factor) for an
## Interface size, on a phone (touch) or a computer.
static func view_scale(size: String, touch: bool) -> float:
	var row: Array = UI_SIZES.get(size, UI_SIZES["normal"])
	return float(row[1] if touch else row[0])


## How many of the device's own (CSS) pixels one view pixel takes on this
## viewport: what a finger or an eye measures. (On the web the canvas is
## drawn at the device's full resolution, devicePixelRatio pixels per CSS
## pixel; elsewhere a window pixel is one.)
static func device_px(vp: Viewport) -> float:
	var k := vp.get_final_transform().get_scale().x if vp is Window else 1.0
	var dpr := DisplayServer.screen_get_scale() if OS.has_feature("web") else 1.0
	return k / maxf(dpr, 0.01)


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


## A small filled arrow for comparisons: pointing up (better) or down (worse).
static func arrow_into(b, c: Vector2, r: float, up: bool, col: Color) -> void:
	var k := -1.0 if up else 1.0
	b.polygon(PackedVector2Array([c + Vector2(0, k * r), c + Vector2(r, -k * r * 0.6), c + Vector2(-r, -k * r * 0.6)]), col)


## A piece's condition (wear, 0 to 1) as a thin bar: green, amber, then red.
static func wear_into(b, r: Rect2, k: float) -> void:
	var col := GOOD if k > 0.5 else (Color(0.95, 0.75, 0.35) if k > 0.25 else BAD)
	b.rect(r, Color(0, 0, 0, 0.55))
	b.rect(Rect2(r.position, Vector2(r.size.x * clampf(k, 0.0, 1.0), r.size.y)), col)


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
	var mono := font("mono")
	var w := maxf(mono.get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 8.0, size + 5.0)
	var r := Rect2(at, Vector2(w, size + 5.0))
	ci.draw_style_box(_key_box(), r)
	draw_text(ci, mono, Vector2(r.position.x, r.end.y - 4.0), key, HORIZONTAL_ALIGNMENT_CENTER, w, size, col)
	return r.size


static var _key_style: StyleBoxFlat


static func _key_box() -> StyleBoxFlat:
	if _key_style == null:
		_key_style = box(Color(0.05, 0.043, 0.07, 0.94), Color(GOLD, 0.5), 4)
		_key_style.border_width_bottom = 2
	return _key_style


# --- the ornate box ----------------------------------------------------------------------
## A StyleBox drawn in code: a rounded slab filled with a vertical gradient
## (`top` to `bottom`), an optional soft shadow under it, a faint glow along
## its top, a lit top edge (`highlight`) and a dark lip under it (`drop`),
## its `edge` line, a hairline just inside it (`inner`), a coloured `strip`
## down its left side, gilt flourishes at the `corners`, and a faint
## engraved `grain`. Used for the menus' panel, cards, buttons and bubbles.
class Ornate extends StyleBox:
	var top := Color(0.13, 0.115, 0.17)
	var bottom := Color(0.06, 0.052, 0.082)
	var edge := Color(0, 0, 0, 0)
	var inner := Color(0, 0, 0, 0)
	var corners := Color(0, 0, 0, 0)
	var glow := Color(0, 0, 0, 0)
	var strip := Color(0, 0, 0, 0)
	var radius := 6.0
	var shadow := 0.0
	var highlight := false
	var drop := false
	var grain := false

	func _get_draw_rect(rect: Rect2) -> Rect2:
		return rect.grow(shadow) if shadow > 0.0 else rect

	func _draw(ci: RID, rect: Rect2) -> void:
		var rs := RenderingServer
		var r := radius
		if shadow > 0.0:
			for i in 4:
				var k := float(i + 1) / 4.0
				var g := rect.grow(shadow * k * 0.9)
				g.position.y += shadow * 0.35
				var pts := rounded(g, r + shadow * k * 0.6)
				rs.canvas_item_add_polygon(ci, pts, PackedColorArray([Color(0, 0, 0, 0.11 * (1.0 - k * 0.7))]))
		if drop:
			var lip := rect
			lip.position.y += 2.0
			rs.canvas_item_add_polygon(ci, rounded(lip, r), PackedColorArray([Color(0, 0, 0, 0.4)]))
		# The fill: colours an affine function of y, so any triangulation is exact.
		var pts := rounded(rect, r)
		var cols := PackedColorArray()
		for p in pts:
			cols.append(top.lerp(bottom, clampf((p.y - rect.position.y) / maxf(rect.size.y, 1.0), 0.0, 1.0)))
		rs.canvas_item_add_polygon(ci, pts, cols)
		if grain and rect.size.y > 40.0:
			# Faint engraved lines, like a worked metal plate.
			var lines := PackedVector2Array()
			var y := rect.position.y + 6.0
			while y < rect.end.y - 6.0:
				lines.append(Vector2(rect.position.x + r, y))
				lines.append(Vector2(rect.end.x - r, y))
				y += 3.0
			rs.canvas_item_add_multiline(ci, lines, PackedColorArray([Color(1, 1, 1, 0.012)]), 1.0)
		if glow.a > 0.0:
			# A soft light along the top, fading down a third of the way.
			var gh := minf(rect.size.y * 0.42, 90.0)
			var band := Rect2(rect.position + Vector2(1, 1), Vector2(rect.size.x - 2, gh))
			var gp := rounded(band, maxf(r - 1.0, 0.0), true)
			var gc := PackedColorArray()
			for p in gp:
				gc.append(Color(glow, glow.a * clampf(1.0 - (p.y - band.position.y) / gh, 0.0, 1.0)))
			rs.canvas_item_add_polygon(ci, gp, gc)
		if strip.a > 0.0:
			var sr := Rect2(rect.position + Vector2(1, 1), Vector2(3, rect.size.y - 2))
			rs.canvas_item_add_polygon(ci, rounded(sr, minf(1.5, r)), PackedColorArray([strip]))
		if highlight:
			rs.canvas_item_add_line(ci, rect.position + Vector2(r, 1.0), Vector2(rect.end.x - r, rect.position.y + 1.0), Color(1, 1, 1, 0.07), 1.0)
		if edge.a > 0.0:
			var loop := rounded(rect.grow(-0.5), r)
			loop.append(loop[0])
			rs.canvas_item_add_polyline(ci, loop, PackedColorArray([edge]), 1.0, true)
		if inner.a > 0.0 and rect.size.x > 24.0 and rect.size.y > 24.0:
			var il := rounded(rect.grow(-4.0), maxf(r - 3.0, 1.0))
			il.append(il[0])
			rs.canvas_item_add_polyline(ci, il, PackedColorArray([inner]), 1.0, true)
		if corners.a > 0.0 and rect.size.x > 60.0 and rect.size.y > 60.0:
			for cx in [0, 1]:
				for cy in [0, 1]:
					_flourish(ci, rect, cx, cy)

	## A rounded rectangle's outline as points (a few per corner); `top_only`
	## rounds only the top corners.
	static func rounded(r: Rect2, rad: float, top_only := false) -> PackedVector2Array:
		var pts := PackedVector2Array()
		rad = clampf(rad, 0.0, minf(r.size.x, r.size.y) * 0.5)
		if rad < 0.5:
			return PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
		var n := 4 if rad < 8.0 else 6
		var centres := [Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.end.x - rad, r.end.y - rad),
			Vector2(r.position.x + rad, r.end.y - rad), Vector2(r.position.x + rad, r.position.y + rad)]
		for k in 4:
			if top_only and (k == 1 or k == 2):
				pts.append(Vector2(r.end.x, r.end.y) if k == 1 else Vector2(r.position.x, r.end.y))
				continue
			var a0 := -PI * 0.5 + PI * 0.5 * k
			for i in n + 1:
				var a := a0 + PI * 0.5 * i / n
				pts.append(centres[k] + Vector2(cos(a), sin(a)) * rad)
		return pts

	## A gilt flourish at one corner: two short rules meeting in a small
	## diamond, with a curl inside.
	func _flourish(ci: RID, rect: Rect2, cx: int, cy: int) -> void:
		var rs := RenderingServer
		var sx := 1.0 if cx == 0 else -1.0
		var sy := 1.0 if cy == 0 else -1.0
		var o := Vector2(rect.position.x if cx == 0 else rect.end.x, rect.position.y if cy == 0 else rect.end.y)
		var c := o + Vector2(sx, sy) * 8.0
		var arm := 18.0
		var col := corners
		rs.canvas_item_add_line(ci, c + Vector2(sx * 4.0, 0), c + Vector2(sx * arm, 0), col, 1.0, true)
		rs.canvas_item_add_line(ci, c + Vector2(0, sy * 4.0), c + Vector2(0, sy * arm), col, 1.0, true)
		rs.canvas_item_add_polygon(ci, PackedVector2Array([c + Vector2(0, -3), c + Vector2(3, 0), c + Vector2(0, 3), c + Vector2(-3, 0)]), PackedColorArray([col]))
		rs.canvas_item_add_circle(ci, c + Vector2(sx * arm + sx * 3.0, 0), 1.2, col)
		rs.canvas_item_add_circle(ci, c + Vector2(0, sy * arm + sy * 3.0), 1.2, col)


## A rounded rectangle's outline as points (a few per corner); `top_only`
## rounds only the top corners.
static func rounded(r: Rect2, rad: float, top_only := false) -> PackedVector2Array:
	return Ornate.rounded(r, rad, top_only)


# --- ornaments and labels ------------------------------------------------------------------

## A double rule with a gilt diamond in the middle (dividers under titles).
static func draw_divider(ci: CanvasItem, from: Vector2, to: Vector2, col := GOLD, diamond := true) -> void:
	var mid := (from + to) * 0.5
	var gap := 9.0 if diamond else 0.0
	var fade := Color(col, 0.0)
	# Each half fades out toward its end.
	for side in [-1.0, 1.0]:
		var end := from if side < 0.0 else to
		var start := mid + (end - mid).normalized() * gap
		ci.draw_polyline_colors(PackedVector2Array([start, end]), PackedColorArray([Color(col, col.a * 0.55), fade]), 1.0, true)
		ci.draw_polyline_colors(PackedVector2Array([start + Vector2(0, 3), end + Vector2(0, 3)]), PackedColorArray([Color(col, col.a * 0.22), fade]), 1.0, true)
	if diamond:
		var c := mid + Vector2(0, 1.5)
		ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, -4), c + Vector2(4, 0), c + Vector2(0, 4), c + Vector2(-4, 0)]), Color(col, col.a * 0.9))
		ci.draw_circle(c + Vector2(-8, 0), 1.0, Color(col, col.a * 0.6))
		ci.draw_circle(c + Vector2(8, 0), 1.0, Color(col, col.a * 0.6))


# --- drawn text (and the layout audit) ---------------------------------------
# Text drawn in code (a slot's tag, a card's lines, the rail) goes through
# draw_text / draw_text_lines: CanvasItem.draw_string and
# draw_multiline_string with the same arguments. While the layout audit
# watches (tests/layout_audit_driver.gd sets text_notes to a list), each
# string also notes where it went and how wide it wanted to be, so the audit
# can tell a line cut short, or two lines on top of each other, without
# rendering anything. In play text_notes is null and nothing is noted.

## The layout audit's notes: null, or a list of {"ci", "text", "rect" (in the
## canvas item's own space), "need" (the width the words want), "room" (the
## width they were given, -1 for no limit), "cut" (lines that didn't fit)}.
static var text_notes = null


## Draws one line of text, as CanvasItem.draw_string does; given a `width`
## the words don't fit, they are drawn smaller (no smaller than FIT_FLOOR)
## before any are cut.
static func draw_text(ci: CanvasItem, f: Font, at: Vector2, text: String, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, size := 16, col := Color.WHITE) -> void:
	if width > 0.0:
		size = fit_floor(f, text, size, width)
	ci.draw_string(f, at, text, align, width, size, col)
	if text_notes != null:
		note_text(ci, f, at, text, align, width, size)


## How tall `text` is wrapped into `width` (for a drawn control that grows
## with its words).
static func text_height(f: Font, text: String, width: float, size: int) -> float:
	return f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, maxf(width, 20.0), size).y


## Draws wrapped text, as CanvasItem.draw_multiline_string does.
static func draw_text_lines(ci: CanvasItem, f: Font, at: Vector2, text: String, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, size := 16, max_lines := -1, col := Color.WHITE) -> void:
	ci.draw_multiline_string(f, at, text, align, width, size, max_lines, col)
	if text_notes != null:
		note_text(ci, f, at, text, align, width, size, max_lines, true)


## Notes a drawn string for the layout audit (see text_notes).
static func note_text(ci: CanvasItem, f: Font, at: Vector2, text: String, align: int, width: float, size: int, max_lines := -1, wrapped := false) -> void:
	if text_notes == null or text.strip_edges() == "":
		return
	var need := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var shown := need
	var h := f.get_height(size)
	var cut := 0
	if wrapped and width > 0.0:
		var all := f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, width, size)
		var lines := maxi(1, int(round(all.y / maxf(h, 1.0))))
		if max_lines > 0 and lines > max_lines:
			cut = lines - max_lines
			lines = max_lines
		shown = minf(all.x, width)
		need = shown  # (it wraps: the width is never the trouble)
		h *= lines
	elif width >= 0.0:
		shown = minf(need, width)
	var x := at.x
	if width >= 0.0 and align == HORIZONTAL_ALIGNMENT_CENTER:
		x += (width - shown) * 0.5
	elif width >= 0.0 and align == HORIZONTAL_ALIGNMENT_RIGHT:
		x += width - shown
	text_notes.append({"ci": ci, "text": text, "rect": Rect2(x, at.y - f.get_ascent(size), shown, h), "need": need, "room": width, "cut": cut})


## The smallest (view px) a drawn line shrinks to before it's cut: on a
## phone the view is drawn 1.5 to 2.5 times bigger, so this is still 14 to
## 22 px on the glass.
const FIT_FLOOR := 9


## Draws one line of text shrunk to fit `width` if it must (no smaller than
## `floor_size`): a long name in a narrow card keeps all its letters. Returns
## the size it was drawn at.
static func draw_text_fit(ci: CanvasItem, f: Font, at: Vector2, text: String, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, size := 16, col := Color.WHITE, floor_size := FIT_FLOOR) -> int:
	var fs := fit_floor(f, text, size, width, floor_size)
	draw_text(ci, f, at, text, align, width, fs, col)
	return fs


## The size a line can be drawn at to fit `width`, no smaller than `floor_size`.
static func fit_floor(f: Font, text: String, size: int, width: float, floor_size := FIT_FLOOR) -> int:
	if width <= 0.0:
		return size
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if w <= width:
		return size
	var fs := clampi(int(floor(size * width / w)), mini(floor_size, size), size)
	while fs > floor_size and f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
		fs -= 1
	return fs


## Notes for the layout audit that a string was shortened by hand before
## it was drawn (its end swapped for "..."): `text` whole, the `width` it had.
static func note_cut(ci: CanvasItem, f: Font, text: String, width: float, size: int) -> void:
	if text_notes != null:
		text_notes.append({"ci": ci, "text": text, "rect": Rect2(), "need": f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x, "room": width, "cut": 0})


# --- words kept whole ---------------------------------------------------------

## Keeps a button's or a label's words whole in whatever width it's given
## (a narrow phone, a big Interface size): when they don't fit, the letters
## shrink, no smaller than `floor_size`; if they still don't fit, they wrap
## onto more lines (and the button or label grows taller). Call it once the
## control has its font size; it follows the control's size from then on.
static func keep_text(c: Control, floor_size := 10) -> void:
	c.set_meta("keep_floor", floor_size)
	c.clip_text = true  # (it can be made narrower than its words: then they shrink or wrap)
	if not c.resized.is_connected(_keep_text):
		c.resized.connect(_keep_text.bind(c))
	if c.is_inside_tree():
		_keep_text.call_deferred(c)
	else:
		c.ready.connect(_keep_text.bind(c), CONNECT_ONE_SHOT)


static func _keep_text(c: Control) -> void:
	if not is_instance_valid(c) or c.size.x < 1.0:
		return
	var floor_size := int(c.get_meta("keep_floor", 10))
	var base := int(c.get_meta("keep_base", 0))
	if base <= 0:
		base = c.get_theme_font_size("font_size")
		c.set_meta("keep_base", base)
	var f: Font = c.get_theme_font("font")
	var room: float = c.size.x
	if c is Button:
		var sb: StyleBox = c.get_theme_stylebox("normal")
		room -= sb.get_minimum_size().x if sb != null else 0.0
		if c.icon != null:
			room -= c.icon.get_width() + c.get_theme_constant("h_separation")
		if c is CheckButton or c is CheckBox:
			var ic: Texture2D = c.get_theme_icon("checked")
			room -= (ic.get_width() if ic != null else 0.0) + c.get_theme_constant("h_separation")
	var text: String = c.text
	if c is Label and c.uppercase:
		text = text.to_upper()
	var fs := base
	var need := f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var wrap := false
	if need > room and room > 0.0:
		fs = clampi(int(floor(base * room / need)), mini(floor_size, base), base)
		while fs > floor_size and f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room:
			fs -= 1
		wrap = f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > room
	if c.get_theme_font_size("font_size") != fs:
		c.add_theme_font_size_override("font_size", fs)
	var mode := TextServer.AUTOWRAP_WORD_SMART if wrap else TextServer.AUTOWRAP_OFF
	if c.autowrap_mode != mode:
		c.autowrap_mode = mode
	if c is Label:
		# (a wrapping label must not clip, or it asks for no height at all)
		if c.clip_text == wrap:
			c.clip_text = not wrap
		c.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING


## A small gothic label (an eyebrow over a title, a section's name), in
## mixed case (titled()). Returns its width.
static func draw_eyebrow(ci: CanvasItem, at: Vector2, text: String, col := GOLD, size := SIZE_EYEBROW, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> float:
	var f := font("eyebrow")
	var t := titled(text)
	draw_text(ci, f, at, t, align, width, size, col)
	return f.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x


## A title in the display face (Grenze Gotisch), with a soft dark halo so
## it reads over anything. All-capital text is shown in mixed case.
static func draw_title(ci: CanvasItem, at: Vector2, text: String, size: int, col := GOLD, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, halo := 0.6) -> void:
	var f := font("display")
	text = title_case(text)
	size = fit_size(f, text, size, width)
	if halo > 0.0:
		ci.draw_string_outline(f, at + Vector2(0, 2), text, align, width, size, maxi(4, size / 5), Color(0, 0, 0, halo * 0.6))
		ci.draw_string_outline(f, at, text, align, width, size, 3, Color(0.12, 0.07, 0.03, halo))
	draw_text(ci, f, at, text, align, width, size, col)


## A label or name in the display face, drawn plainly (or with an outline
## of `outline` px so it reads over the world). All-capital text is shown
## in mixed case.
static func draw_label(ci: CanvasItem, at: Vector2, text: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := 0, outline_col := Color(0, 0, 0, 0.8)) -> void:
	var f := font("display")
	text = title_case(text)
	size = fit_size(f, text, size, width)
	if outline > 0:
		ci.draw_string_outline(f, at, text, align, width, size, outline, outline_col)
	draw_text(ci, f, at, text, align, width, size, col)


## The size a line can be drawn at to fit `width`: a long name on a narrow
## card shrinks instead of losing its end, no smaller than FIT_FLOOR (or 60%
## of `size`, for big lettering).
static func fit_size(f: Font, text: String, size: int, width: float) -> int:
	return fit_floor(f, text, size, width, maxi(FIT_FLOOR, int(ceil(size * 0.6))) if size > 18 else FIT_FLOOR)


## Words written in the world or quoted, in the fine italic (`outline` px
## of dark behind them when they sit over the world).
static func draw_inscription(ci: CanvasItem, at: Vector2, text: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0, outline := 0, outline_col := Color(0, 0, 0, 0.8)) -> void:
	var f := font("inscription")
	if outline > 0:
		ci.draw_string_outline(f, at, text, align, width, size, outline, outline_col)
	draw_text(ci, f, at, text, align, width, size, col)


## Gothic titles read best in mixed case (blackletter capitals run
## together): "THE KRAKEN'S TOWER" becomes "The Kraken's Tower". In mixed
## text only a shouted word of four letters or more is lowered ("RARE: Coral
## Trident" becomes "Rare: Coral Trident"; short ones like "HUD" stay), and
## the rest is left as it is (titled() also raises lower case).
static func title_case(t: String) -> String:
	if t == t.to_lower():
		return t
	if t == t.to_upper():
		return titled(t)
	var words := t.split(" ")
	var changed := false
	for i in words.size():
		var w: String = words[i]
		if w.length() >= 4 and w == w.to_upper() and w.to_lower() != w:
			var letters := 0
			for ch in w:
				if ch.to_lower() != ch:
					letters += 1
			if letters >= 4:
				words[i] = w.left(1) + w.substr(1).to_lower()
				changed = true
	return " ".join(words) if changed else t


## A Label in a role's font (see ROLES). Gothic labels show all-capital
## text in mixed case; eyebrows are always titled().
static func style_label(l: Label, kind: String, size: int, col: Color) -> Label:
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	if kind == "eyebrow":
		l.text = titled(l.text)
	elif kind == "display":
		l.text = title_case(l.text)
	return l


# --- the rail's icons ----------------------------------------------------------------------
## Line icons for the menu's rail (rail.gd), drawn in code like the old
## game's stroked icons: `id` is the rail item, `c` its centre, `s` its half
## size. Unknown ids draw a small diamond.
static func draw_icon(ci: CanvasItem, id: String, c: Vector2, s: float, col: Color, w := 1.6) -> void:
	var u := s / 10.0  # (drawn on a 20 x 20 grid around the centre)
	var P := func(x: float, y: float) -> Vector2: return c + Vector2(x, y) * u
	match id:
		"resume":  # a door ajar with light spilling out
			ci.draw_polyline(PackedVector2Array([P.call(-6, 9), P.call(-6, -7), P.call(-2, -9), P.call(6, -9), P.call(6, 9)]), col, w, true)
			ci.draw_colored_polygon(PackedVector2Array([P.call(-2, -6), P.call(4, -8), P.call(4, 9), P.call(-2, 7)]), Color(col, 0.35))
			ci.draw_line(P.call(-9, 9), P.call(9, 9), col, w, true)
		"train":  # a small engine
			ci.draw_polyline(PackedVector2Array([P.call(-9, 5), P.call(-9, -3), P.call(-1, -3), P.call(-1, -8), P.call(5, -8), P.call(5, 5)]), col, w, true)
			ci.draw_line(P.call(5, -1), P.call(9, 1), col, w, true)
			ci.draw_line(P.call(9, 1), P.call(9, 5), col, w, true)
			ci.draw_line(P.call(-10, 5), P.call(10, 5), col, w, true)
			ci.draw_arc(P.call(-5, 7.5), 2.2 * u, 0, TAU, 12, col, w, true)
			ci.draw_arc(P.call(3, 7.5), 2.2 * u, 0, TAU, 12, col, w, true)
			ci.draw_line(P.call(-6, -3), P.call(-6, -8), col, w, true)
		"climber":  # head and shoulders
			ci.draw_arc(P.call(0, -4), 4.2 * u, 0, TAU, 20, col, w, true)
			ci.draw_arc(P.call(0, 10), 8.0 * u, PI * 1.08, PI * 1.92, 16, col, w, true)
		"inventory":  # a satchel
			ci.draw_polyline(PackedVector2Array([P.call(-8, -3), P.call(8, -3), P.call(7, 9), P.call(-7, 9), P.call(-8, -3)]), col, w, true)
			ci.draw_arc(P.call(0, -3), 4.0 * u, PI, TAU, 12, col, w, true)
			ci.draw_line(P.call(-8, 2), P.call(8, 2), col, w, true)
			ci.draw_rect(Rect2(P.call(-1.5, 1), Vector2(3, 3) * u), col)
		"archive":  # an open book
			ci.draw_polyline(PackedVector2Array([P.call(0, -5), P.call(-4, -8), P.call(-9, -8), P.call(-9, 7), P.call(-4, 7), P.call(0, 9), P.call(4, 7), P.call(9, 7), P.call(9, -8), P.call(4, -8), P.call(0, -5), P.call(0, 9)]), col, w, true)
			ci.draw_line(P.call(-6.5, -4), P.call(-3, -4), Color(col, 0.6), 1.0, true)
			ci.draw_line(P.call(-6.5, -1), P.call(-3, -1), Color(col, 0.6), 1.0, true)
			ci.draw_line(P.call(3, -4), P.call(6.5, -4), Color(col, 0.6), 1.0, true)
		"settings":  # a cog
			ci.draw_arc(c, 3.0 * u, 0, TAU, 16, col, w, true)
			var cog := PackedVector2Array()
			for i in 17:
				var a := TAU * i / 16.0
				var rr := 8.6 if i % 2 == 0 else 6.4
				cog.append(c + Vector2.from_angle(a) * rr * u)
			ci.draw_polyline(cog, col, w, true)
		"controls":  # a controller
			var pad := PackedVector2Array()
			for i in 13:
				var a := PI + PI * i / 12.0
				pad.append(P.call(0, 0) + Vector2(cos(a) * 9.0, sin(a) * 5.0) * u)
			pad.append(P.call(8, 6))
			pad.append(P.call(4, 3))
			pad.append(P.call(-4, 3))
			pad.append(P.call(-8, 6))
			pad.append(pad[0])
			ci.draw_polyline(pad, col, w, true)
			ci.draw_line(P.call(-6, -1), P.call(-2, -1), col, w, true)
			ci.draw_line(P.call(-4, -3), P.call(-4, 1), col, w, true)
			ci.draw_circle(P.call(4, -2), 1.2 * u, col)
			ci.draw_circle(P.call(6.5, 0), 1.2 * u, col)
		"dev":  # a wrench
			ci.draw_line(P.call(-7, 7), P.call(2, -2), col, w * 1.3, true)
			ci.draw_arc(P.call(4.5, -4.5), 4.5 * u, PI * 0.95, PI * 2.55, 16, col, w, true)
		"over":  # a turning arrow (start over)
			ci.draw_arc(c, 7.5 * u, -PI * 0.35, PI * 1.45, 24, col, w, true)
			var tip := c + Vector2.from_angle(-PI * 0.35) * 7.5 * u
			ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-1, -4) * u, tip + Vector2(4, 1) * u, tip + Vector2(-3, 3) * u]), col)
		"exit":  # a doorway and an arrow leaving
			ci.draw_polyline(PackedVector2Array([P.call(1, -9), P.call(-7, -9), P.call(-7, 9), P.call(1, 9)]), col, w, true)
			ci.draw_line(P.call(-2, 0), P.call(9, 0), col, w, true)
			ci.draw_polyline(PackedVector2Array([P.call(5, -4), P.call(9, 0), P.call(5, 4)]), col, w, true)
		"car":  # your car: a window and a lamp
			ci.draw_polyline(PackedVector2Array([P.call(-9, 8), P.call(-9, -6), P.call(9, -6), P.call(9, 8), P.call(-9, 8)]), col, w, true)
			ci.draw_arc(P.call(0, 1), 4.0 * u, PI, TAU, 10, col, w, true)
			ci.draw_line(P.call(-4, 1), P.call(-4, 5), col, w, true)
			ci.draw_line(P.call(4, 1), P.call(4, 5), col, w, true)
			ci.draw_line(P.call(-9, -9), P.call(9, -9), col, w, true)
		_:
			ci.draw_colored_polygon(PackedVector2Array([P.call(0, -6), P.call(6, 0), P.call(0, 6), P.call(-6, 0)]), col)


# --- the HUD's pieces and the selection wheels -----------------------------------------
## Drawn into a Batch like the pieces above, in the menus' look: gilt-framed
## gauges with a dark bezel and a gloss, engraved medallions, chamfered
## plates and cartouches, banners as soft bands between gilt rules, the
## touch buttons' bezel, and the selection wheels. Rings, frames and
## gradients are built straight into the batch as strips (no round joints),
## so the HUD stays cheap to redraw on a phone.

## A ring (or an arc of one, `from` to `to` in radians) `w` wide, as a strip of quads.
static func ring_into(b, c: Vector2, r: float, w: float, col: Color, from := 0.0, to := TAU, n := 0) -> void:
	if n <= 0:
		n = clampi(int(r * absf(to - from) / 3.5), 6, 72)
	var r0 := maxf(r - w * 0.5, 0.0)
	var r1 := r + w * 0.5
	var p := PackedVector2Array()
	p.resize(n * 6)
	var d0 := Vector2.from_angle(from)
	var pi0 := c + d0 * r0
	var po0 := c + d0 * r1
	for i in n:
		var d := Vector2.from_angle(lerpf(from, to, float(i + 1) / n))
		var pi1 := c + d * r0
		var po1 := c + d * r1
		var k := i * 6
		p[k] = pi0
		p[k + 1] = po0
		p[k + 2] = po1
		p[k + 3] = pi0
		p[k + 4] = po1
		p[k + 5] = pi1
		pi0 = pi1
		po0 = po1
	b.pts.append_array(p)
	b._color(col, n * 6)


## A disc shaded from `inner` at its centre to `outer` at its edge (a fan).
static func fan_into(b, c: Vector2, r: float, inner: Color, outer: Color, n := 40) -> void:
	var p := PackedVector2Array()
	var q := PackedColorArray()
	p.resize(n * 3)
	q.resize(n * 3)
	var prev := c + Vector2(r, 0)
	for i in n:
		var nxt := c + Vector2.from_angle(TAU * float(i + 1) / n) * r
		p[i * 3] = c
		p[i * 3 + 1] = prev
		p[i * 3 + 2] = nxt
		q[i * 3] = inner
		q[i * 3 + 1] = outer
		q[i * 3 + 2] = outer
		prev = nxt
	b.pts.append_array(p)
	b.cols.append_array(q)


## A convex polygon shaded from `top` to `bottom` down its height.
static func vgrad_into(b, pts: PackedVector2Array, top: Color, bottom: Color) -> void:
	var y0 := INF
	var y1 := -INF
	var mid := Vector2.ZERO
	for v in pts:
		y0 = minf(y0, v.y)
		y1 = maxf(y1, v.y)
		mid += v
	mid /= float(pts.size())
	var h := maxf(y1 - y0, 0.001)
	var mc := top.lerp(bottom, (mid.y - y0) / h)
	var n := pts.size()
	for i in n:
		var a := pts[i]
		var c2 := pts[(i + 1) % n]
		b.pts.append_array([mid, a, c2])
		b.cols.append_array([mc, top.lerp(bottom, (a.y - y0) / h), top.lerp(bottom, (c2.y - y0) / h)])


## A rectangle with its corners cut (`cut` across): the plates, slots and gauges.
static func chamfer(r: Rect2, cut: float) -> PackedVector2Array:
	cut = clampf(cut, 0.0, minf(r.size.x, r.size.y) * 0.5)
	var a := r.position
	var e := r.end
	return PackedVector2Array([Vector2(a.x + cut, a.y), Vector2(e.x - cut, a.y), Vector2(e.x, a.y + cut), Vector2(e.x, e.y - cut),
		Vector2(e.x - cut, e.y), Vector2(a.x + cut, e.y), Vector2(a.x, e.y - cut), Vector2(a.x, a.y + cut)])


## A frame between two outlines with the same number of points (outer and
## inner), shaded from `top` to `bottom`: a gilt frame lit along its top.
static func frame_into(b, outer: PackedVector2Array, inner: PackedVector2Array, top: Color, bottom: Color) -> void:
	var y0 := INF
	var y1 := -INF
	for v in outer:
		y0 = minf(y0, v.y)
		y1 = maxf(y1, v.y)
	var h := maxf(y1 - y0, 0.001)
	var n := outer.size()
	for i in n:
		var j := (i + 1) % n
		var o0 := outer[i]
		var o1 := outer[j]
		var i0 := inner[i]
		var i1 := inner[j]
		var co0 := top.lerp(bottom, (o0.y - y0) / h)
		var co1 := top.lerp(bottom, (o1.y - y0) / h)
		var ci0 := top.lerp(bottom, clampf((i0.y - y0) / h, 0.0, 1.0))
		var ci1 := top.lerp(bottom, clampf((i1.y - y0) / h, 0.0, 1.0))
		b.pts.append_array([o0, o1, i1, o0, i1, i0])
		b.cols.append_array([co0, co1, ci1, co0, ci1, ci0])


## A small diamond (a stud, a finial, a rule's centre).
static func diamond_into(b, c: Vector2, r: float, col: Color, squash := 1.0) -> void:
	b.pts.append_array([c + Vector2(0, -r), c + Vector2(r * squash, 0), c + Vector2(0, r), c + Vector2(0, -r), c + Vector2(0, r), c + Vector2(-r * squash, 0)])
	b._color(col, 6)


## A quad shaded left to right (`a` at the left edge, `z` at the right): bands and rules.
static func hgrad_into(b, r: Rect2, a: Color, z: Color) -> void:
	var p0 := r.position
	var p1 := Vector2(r.end.x, r.position.y)
	var p2 := r.end
	var p3 := Vector2(r.position.x, r.end.y)
	b.pts.append_array([p0, p1, p2, p0, p2, p3])
	b.cols.append_array([a, z, z, a, z, a])


## The gilt the HUD is edged with, lit along the top (GILT_HI) and shadowed
## below; `dim` for a quiet line instead.
static func gilt_pair(alpha := 1.0, dim := false) -> Array:
	if dim:
		return [Color(LINE_HI, 0.95 * alpha), Color(LINE, 0.95 * alpha)]
	return [Color(GILT_HI, alpha), Color(GILT_DEEP.lerp(GILT, 0.35), alpha)]


## A gauge in a gilt frame: a dark bezel, a gilt frame, an inset trough with
## engraved notches at the quarters, the fill shaded and glossed with a lit
## leading edge, and small gilt finials at both ends. `trail` (above k)
## shows recent loss. `ticks` notches (0 for none).
static func gauge_into(b, r: Rect2, k: float, col: Color, trail := -1.0, trail_col := Color(1.0, 0.85, 0.6, 0.85), ticks := 4, alpha := 1.0) -> void:
	var slim := r.size.y < 9.0
	var cut := 2.0 if slim else 3.0
	var g := 2.0 if slim else 2.5  # the frame's reach outside the fill
	var gp := gilt_pair(alpha)
	vgrad_into(b, chamfer(r.grow(g + 1.2), cut + 1.2), Color(OUTLINE, 0.9 * alpha), Color(OUTLINE, 0.75 * alpha))
	frame_into(b, chamfer(r.grow(g), cut + 1.0), chamfer(r.grow(g - (0.9 if slim else 1.1)), cut + 0.6), gp[0], gp[1])
	var mid := r.position.y + r.size.y * 0.5
	if not slim:  # the finials: a gilt diamond at each end
		for x in [r.position.x - g - 3.2, r.end.x + g + 3.2]:
			diamond_into(b, Vector2(x, mid), 3.6, Color(OUTLINE, 0.9 * alpha), 0.85)
			diamond_into(b, Vector2(x, mid), 2.4, gp[0], 0.8)
	# The trough: darker at the top, as if set into the frame.
	vgrad_into(b, chamfer(r, cut), Color(col.darkened(0.88), alpha), Color(col.darkened(0.72), alpha))
	k = clampf(k, 0.0, 1.0)
	if trail > k:
		var tr := Rect2(r.position, Vector2(r.size.x * clampf(trail, 0.0, 1.0), r.size.y))
		vgrad_into(b, chamfer(tr, cut), Color(trail_col, trail_col.a * alpha), Color(trail_col.darkened(0.3), trail_col.a * alpha))
	if k > 0.0:
		var fr := Rect2(r.position, Vector2(maxf(r.size.x * k, 1.0), r.size.y))
		vgrad_into(b, chamfer(fr, minf(cut, fr.size.x * 0.5)), Color(col.lightened(0.18), alpha), Color(col.darkened(0.38), alpha))
		if fr.size.x > 4.0:
			# The gloss: a soft light across the top of the fill.
			var gl := Rect2(fr.position + Vector2(1.5, 1.0), Vector2(fr.size.x - 3.0, r.size.y * 0.38))
			vgrad_into(b, chamfer(gl, 0.0), Color(1, 1, 1, 0.3 * alpha), Color(1, 1, 1, 0.02 * alpha))
		if k < 1.0:
			b.rect(Rect2(Vector2(fr.end.x - 1.0, r.position.y), Vector2(1.0, r.size.y)), Color(col.lightened(0.6), 0.75 * alpha))
	for i in range(1, ticks):
		var x := r.position.x + r.size.x * float(i) / ticks
		b.rect(Rect2(Vector2(x - 0.5, r.position.y), Vector2(1.0, r.size.y)), Color(OUTLINE, 0.45 * alpha))
		b.rect(Rect2(Vector2(x + 0.5, r.position.y + 1.0), Vector2(1.0, r.size.y - 1.0)), Color(1, 1, 1, 0.06 * alpha))


## Engraved hatching over part of a gauge (health lost to a burned heart or
## a wound): a tint and fine diagonal lines.
static func hatch_into(b, r: Rect2, col: Color) -> void:
	b.rect(r, Color(col, col.a * 0.55))
	var x := r.position.x - r.size.y
	while x < r.end.x:
		var x0 := maxf(x, r.position.x)
		var x1 := minf(x + r.size.y, r.end.x)
		if x1 > x0 + 0.5:
			b.line(Vector2(x0, r.end.y - (x0 - x)), Vector2(x1, r.end.y - (x1 - x)), Color(col.lightened(0.3), col.a), 1.0)
		x += 4.0


## A slot for the weapon in hand or an item: a chamfered well in a dark
## bezel, framed in gilt (`on`, the one in hand) or in a quiet line, with
## small gilt studs at its corners when on.
static func slot_into(b, r: Rect2, on := false, accent := Color(0, 0, 0, 0), alpha := 1.0) -> void:
	var gp := gilt_pair(alpha, not on)
	vgrad_into(b, chamfer(r.grow(2.2), 6.2), Color(OUTLINE, 0.92 * alpha), Color(OUTLINE, 0.8 * alpha))
	frame_into(b, chamfer(r.grow(1.2), 5.6), chamfer(r, 5.0), gp[0], gp[1])
	vgrad_into(b, chamfer(r, 5.0), Color(STONE_2 if not on else Color(0.22, 0.16, 0.08), 0.96 * alpha), Color(VOID, 0.96 * alpha))
	if accent.a > 0.0:
		glow_into(b, r.get_center() + Vector2(0, r.size.y * 0.1), r.size.x * 0.44, accent, 0.7 * alpha)
	b.rect(Rect2(r.position + Vector2(5.0, 1.0), Vector2(r.size.x - 10.0, 1.0)), Color(1, 1, 1, 0.08 * alpha))
	if on:
		for cx in [r.position.x + 1.6, r.end.x - 1.6]:
			for cy in [r.position.y + 1.6, r.end.y - 1.6]:
				diamond_into(b, Vector2(cx, cy), 1.5, Color(GILT_HI, 0.9 * alpha))


## A plate for the HUD's small panels (the essence counter, the weapon
## popup, the key hints): a chamfered slab, lighter at the top, a thin edge
## and a gilt hairline along its top that fades to both ends. `alpha` fades it.
static func plate_into(b, r: Rect2, alpha := 1.0, edge := Color(0, 0, 0, 0)) -> void:
	var e := edge if edge.a > 0.0 else Color(LINE_HI, 0.8)
	vgrad_into(b, chamfer(r.grow(1.0), 5.0), Color(OUTLINE, 0.7 * alpha), Color(OUTLINE, 0.7 * alpha))
	frame_into(b, chamfer(r, 4.5), chamfer(r.grow(-1.0), 4.0), Color(e.lightened(0.15), e.a * alpha), Color(e.darkened(0.3), e.a * 0.8 * alpha))
	vgrad_into(b, chamfer(r.grow(-1.0), 4.0), Color(STONE_2, 0.9 * alpha), Color(VOID, 0.9 * alpha))
	var hw := (r.size.x - 12.0) * 0.5
	hgrad_into(b, Rect2(r.position + Vector2(6.0, 2.0), Vector2(hw, 1.0)), Color(GILT, 0.0), Color(GILT, 0.35 * alpha))
	hgrad_into(b, Rect2(r.position + Vector2(6.0 + hw, 2.0), Vector2(hw, 1.0)), Color(GILT, 0.35 * alpha), Color(GILT, 0.0))


## A cartouche for a status line (a shut door, a challenge's rule): a dark
## plate with pointed ends, edged in `col`, a stud beyond each point.
static func cartouche_into(b, r: Rect2, col: Color, alpha := 1.0) -> void:
	var h := r.size.y * 0.5
	var mid := r.position.y + h
	var cx := r.get_center().x
	var outer := PackedVector2Array([Vector2(r.position.x, mid), Vector2(r.position.x + h, r.position.y), Vector2(r.end.x - h, r.position.y),
		Vector2(r.end.x, mid), Vector2(r.end.x - h, r.end.y), Vector2(r.position.x + h, r.end.y)])
	var ins := 1.3
	var inner := PackedVector2Array([Vector2(r.position.x + ins * 1.8, mid), Vector2(r.position.x + h + ins * 0.5, r.position.y + ins), Vector2(r.end.x - h - ins * 0.5, r.position.y + ins),
		Vector2(r.end.x - ins * 1.8, mid), Vector2(r.end.x - h - ins * 0.5, r.end.y - ins), Vector2(r.position.x + h + ins * 0.5, r.end.y - ins)])
	var shadow := PackedVector2Array()
	for v in outer:
		shadow.append(v + (v - Vector2(cx, mid)).normalized() * 1.6)
	vgrad_into(b, shadow, Color(OUTLINE, 0.6 * alpha), Color(OUTLINE, 0.75 * alpha))
	vgrad_into(b, inner, Color(STONE_2, 0.88 * alpha), Color(VOID, 0.92 * alpha))
	frame_into(b, outer, inner, Color(col.lightened(0.2), col.a * alpha), Color(col.darkened(0.35), col.a * alpha))
	for x in [r.position.x - 5.0, r.end.x + 5.0]:
		diamond_into(b, Vector2(x, mid), 2.4, Color(col, col.a * 0.85 * alpha))


## A banner across the screen (a floor's news, a fall): a soft dark band
## that fades out to both sides, between thin gilt rules that fade the same
## way, each with a diamond at its centre.
static func band_into(b, r: Rect2, alpha := 1.0, rule := GILT, shade := 0.6) -> void:
	var cx := r.get_center().x
	var half := r.size.x * 0.5
	var dark := Color(VOID, shade * alpha)
	var clear := Color(VOID, 0.0)
	hgrad_into(b, Rect2(r.position, Vector2(half, r.size.y)), clear, dark)
	hgrad_into(b, Rect2(Vector2(cx, r.position.y), Vector2(half, r.size.y)), dark, clear)
	for y in [r.position.y, r.end.y - 1.0]:
		var lit := Color(rule, 0.75 * alpha)
		var off := Color(rule, 0.0)
		hgrad_into(b, Rect2(Vector2(r.position.x + half * 0.2, y), Vector2(half * 0.8 - 6.0, 1.0)), off, lit)
		hgrad_into(b, Rect2(Vector2(cx + 6.0, y), Vector2(half * 0.8 - 6.0, 1.0)), lit, off)
		diamond_into(b, Vector2(cx, y + 0.5), 3.2, Color(OUTLINE, 0.8 * alpha))
		diamond_into(b, Vector2(cx, y + 0.5), 2.2, Color(rule.lightened(0.2), 0.95 * alpha))


## Thin gilt rules either side of a centred title, fading outward, each
## starting at a stud: `cx` the centre, `gap` half the title's width.
static func flank_into(b, cx: float, y: float, gap: float, reach: float, col: Color) -> void:
	for side in [-1.0, 1.0]:
		var x0: float = cx + side * gap
		var x1: float = cx + side * (gap + reach)
		var r := Rect2(Vector2(minf(x0, x1), y), Vector2(absf(x1 - x0), 1.0))
		if side > 0.0:
			hgrad_into(b, r, col, Color(col, 0.0))
		else:
			hgrad_into(b, r, Color(col, 0.0), col)
		diamond_into(b, Vector2(x0 - side * 3.0, y + 0.5), 2.0, col)


## A mark's medallion on the HUD: an engraved gilt rim with four studs, a
## gauge ring filling with essence, the emblem in a dark well. `ready`
## glows in the bond's colour; `burned` reddens the rim and cracks the face;
## `faint` dims it all.
static func seal_into(b, c: Vector2, r: float, col: Color, affinity: String, k: float, ready: bool, faint := false, burned := false) -> void:
	if ready:
		glow_into(b, c, r * 1.95, col, 0.8)
	b.dot(c, r + 3.0, Color(OUTLINE, 0.9))
	var rim_hi := Color(BLOOD.lightened(0.25), 0.95) if burned else (Color(GILT_HI, 0.95) if not faint else Color(LINE_HI, 0.9))
	var rim_lo := Color(BLOOD.darkened(0.4), 0.95) if burned else (Color(GILT_DEEP.lerp(GILT, 0.3), 0.95) if not faint else Color(LINE, 0.9))
	ring_into(b, c, r + 1.4, 1.8, rim_lo)
	ring_into(b, c, r + 1.6, 1.0, rim_hi, PI * 0.95, PI * 2.05)  # lit along the top
	for i in 4:
		var d := Vector2.from_angle(-PI / 2.0 + i * PI / 2.0)
		diamond_into(b, c + d * (r + 1.5), 1.7, Color(OUTLINE, 0.9))
		diamond_into(b, c + d * (r + 1.5), 1.0, rim_hi)
	var ring := maxf(2.0, r * 0.17)
	ring_into(b, c, r - ring * 0.5, ring, col.darkened(0.68))
	if k > 0.0:
		var a1 := -PI / 2.0 + TAU * clampf(k, 0.0, 1.0)
		ring_into(b, c, r - ring * 0.5, ring, Color(col if ready else col.darkened(0.15), 0.55 if faint else 1.0), -PI / 2.0, a1)
		ring_into(b, c, r - ring * 0.25, ring * 0.3, Color(col.lightened(0.5), 0.25 if faint else 0.55), -PI / 2.0, a1)
	var inner := r - ring - 0.6
	fan_into(b, c, inner, col.darkened(0.6 if ready else 0.72), Color(0.04, 0.035, 0.06), 24)
	emblem_into(b, c + Vector2(0, 0.3), inner * 0.7, affinity, col if not faint else col.darkened(0.35), 1.0 if r > 14.0 else 0.0)
	if burned:
		var crack := Color(1.0, 0.45, 0.32, 0.9)
		b.path(PackedVector2Array([c + Vector2(-r * 0.9, -r * 0.35), c + Vector2(-r * 0.35, -r * 0.1), c + Vector2(-r * 0.1, -r * 0.45), c + Vector2(r * 0.35, r * 0.05)]), crack, 1.0)
		b.path(PackedVector2Array([c + Vector2(r * 0.8, r * 0.5), c + Vector2(r * 0.3, r * 0.3), c + Vector2(r * 0.1, r * 0.75)]), crack, 1.0)


## A touch button's face: a dark bezel, a gilt ring, a glassy translucent
## face with a gloss along the top. `fill` draws an essence arc inside the
## ring (a mark filling, a bow drawn); `ready` glows and lights the ring in
## `col`; `pressed` tints the face; `quiet` dims the gilt (small buttons).
static func button_into(b, c: Vector2, r: float, col: Color, pressed := false, ready := false, fill := 0.0, quiet := false) -> void:
	if ready:
		glow_into(b, c, r * 1.4, col, 0.9)
	ring_into(b, c, r + 0.4, 3.4, Color(OUTLINE, 0.5))
	fan_into(b, c, r - 1.0, Color(0.07, 0.06, 0.1, 0.32 if not pressed else 0.55), Color(0.03, 0.025, 0.045, 0.58 if not pressed else 0.72), 32)
	var gilt := Color(GILT_HI, 0.8) if pressed else Color(GILT, 0.5 if quiet else 0.62)
	ring_into(b, c, r - 0.8, 1.5, gilt)
	ring_into(b, c, r - 0.6, 1.0, Color(GILT_HI, 0.35 if quiet else 0.5), PI * 1.1, PI * 1.9)
	ring_into(b, c, r - 3.4, 1.0, Color(OUTLINE, 0.45))
	if ready:
		ring_into(b, c, r - 0.8, 2.6, Color(col, 0.95))
	if fill > 0.0:
		ring_into(b, c, r - 5.6, 3.6, Color(col.darkened(0.6), 0.5))
		ring_into(b, c, r - 5.6, 3.6, Color(col, 0.9), -PI / 2.0, -PI / 2.0 + TAU * clampf(fill, 0.0, 1.0))
	# The gloss: a pale crescent along the top of the glass.
	ring_into(b, c + Vector2(0, r * 0.06), r - 7.0, 2.0, Color(1, 1, 1, 0.1), PI * 1.15, PI * 1.85)
	if pressed:
		b.dot(c, r - 3.0, Color(col, 0.16))


## A selection wheel (the spell ring, the item ring, the tool ring...): the
## world dimmed behind it, a dark disc with an engraved gilt rim, engraved
## spokes between the options, the pointed-at sector washed in its colour,
## each option in a medallion with its icon and name, the hovered one
## lifted and glowing, its cost as gems on a pendant. `opts` holds, for
## each option: "name", "col" (its colour), "icon" (a Callable(batch,
## centre, size, colour)), and optionally "badge" (a count), "gems"
## ([[colour, amount], ...]), "note" (a word in place of the cost) and
## "off" (it can't be used now: greyed). `view` is the screen's size.
static func draw_wheel(ci: CanvasItem, c: Vector2, ring_r: float, opts: Array, sel: int, accent: Color, view: Vector2) -> void:
	var n := opts.size()
	if n == 0:
		return
	var R := ring_r + 36.0
	var b := Draw.Batch.new()
	b.rect(Rect2(Vector2.ZERO, view), Color(VOID, 0.4))
	glow_into(b, c, R * 1.25, Color(0, 0, 0), 2.2)
	# The disc: clear at the centre (the climber shows through), dark at the rim.
	fan_into(b, c, R - 3.0, Color(0.06, 0.05, 0.09, 0.32), Color(0.06, 0.05, 0.09, 0.9), 48)
	var sector := TAU / float(n)
	if sel >= 0 and sel < n:
		# The pointed-at sector, washed in the option's colour.
		var a0 := -PI / 2.0 + sector * (float(sel) - 0.5)
		var sc: Color = opts[sel]["col"]
		var steps := maxi(4, int(24.0 * sector / TAU) + 4)
		for i in steps:
			var t0 := a0 + sector * float(i) / steps
			var t1 := a0 + sector * float(i + 1) / steps
			b.pts.append_array([c + Vector2.from_angle(t0) * 16.0, c + Vector2.from_angle(t0) * (R - 4.0), c + Vector2.from_angle(t1) * (R - 4.0),
				c + Vector2.from_angle(t0) * 16.0, c + Vector2.from_angle(t1) * (R - 4.0), c + Vector2.from_angle(t1) * 16.0])
			b.cols.append_array([Color(sc, 0.0), Color(sc, 0.2), Color(sc, 0.2), Color(sc, 0.0), Color(sc, 0.2), Color(sc, 0.0)])
		ring_into(b, c, R - 4.0, 2.0, Color(sc, 0.85), a0 + 0.04, a0 + sector - 0.04)
	# The rim: a dark bezel, a gilt band lit along the top, a hairline inside it, engraved ticks between.
	ring_into(b, c, R, 5.0, Color(OUTLINE, 0.92))
	ring_into(b, c, R - 0.4, 2.0, Color(GILT_DEEP.lerp(GILT, 0.45), 0.95))
	ring_into(b, c, R - 0.2, 1.0, Color(GILT_HI, 0.75), PI * 1.05, PI * 1.95)
	ring_into(b, c, R - 6.5, 1.0, Color(GILT, 0.3))
	for i in 48:
		var d := Vector2.from_angle(TAU * i / 48.0)
		b.line(c + d * (R - 6.0), c + d * (R - 2.5 if i % 4 == 0 else R - 4.0), Color(GILT, 0.32), 1.0)
	# The spokes, engraved between the options, a stud where each meets the rim.
	if n > 1:
		for i in n:
			var d := Vector2.from_angle(-PI / 2.0 + sector * (float(i) + 0.5))
			b.line(c + d * 18.0, c + d * (R - 7.0), Color(OUTLINE, 0.75), 2.0)
			b.line(c + d * 18.0 + d.orthogonal() * 1.2, c + d * (R - 7.0) + d.orthogonal() * 1.2, Color(GILT, 0.16), 1.0)
			diamond_into(b, c + d * (R - 1.0), 3.4, Color(OUTLINE, 0.95))
			diamond_into(b, c + d * (R - 1.0), 2.2, GILT_HI)
	# The hub: a thin ring round the climber.
	ring_into(b, c, 15.0, 3.0, Color(OUTLINE, 0.6))
	ring_into(b, c, 15.0, 1.2, Color(accent.lerp(GILT, 0.5), 0.7))
	# The options: the hovered one last, on top.
	var order: Array = range(n)
	if sel >= 0 and sel < n:
		order.erase(sel)
		order.append(sel)
	var words: Array = []  # [pos, text, colour, size, kind]
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.006)
	for i in order:
		var o: Dictionary = opts[i]
		var on: bool = i == sel
		var off: bool = o.get("off", false)
		var col: Color = o["col"] if not off else Color(0.55, 0.54, 0.6)
		var mr := 23.0 if on else 19.0
		var at := c + Vector2.from_angle(-PI / 2.0 + sector * i) * ring_r + (Vector2(0, -3.0) if on else Vector2.ZERO)
		if on:
			b.dot(at + Vector2(0, 5.0), mr + 2.0, Color(0, 0, 0, 0.45))  # lifted: its shadow below
			glow_into(b, at, mr * 2.0, col, 1.1 + 0.5 * pulse)
		b.dot(at, mr + 2.6, Color(OUTLINE, 0.95))
		ring_into(b, at, mr + 0.8, 2.2, Color(col, 0.95) if on else Color(GILT_DEEP.lerp(GILT, 0.4), 0.9 if not off else 0.5))
		ring_into(b, at, mr + 1.0, 1.0, Color(col.lightened(0.5), 0.9) if on else Color(GILT_HI, 0.55 if not off else 0.25), PI * 1.05, PI * 1.95)
		fan_into(b, at, mr - 0.4, col.darkened(0.55 if on else 0.75), Color(0.035, 0.03, 0.05), 28)
		ring_into(b, at, mr - 2.6, 1.0, Color(col, 0.35 if on else 0.18))
		var icon = o.get("icon")
		if icon is Callable and icon.is_valid():
			icon.call(b, at + Vector2(0, -1.0), mr * (0.5 if on else 0.46), Color(col.lightened(0.25 if on else 0.0), 1.0 if not off else 0.6))
		if not on:  # (the hovered one is named under the wheel)
			words.append([at + Vector2(0, mr + 15.0), String(o.get("name", "")), Color(TEXT, 0.82 if not off else 0.5), 10, "name"])
		# The cost (gems on a pendant under the medallion), a count, or a word.
		var gems: Array = o.get("gems", [])
		if String(o.get("note", "")) != "":
			if not on:
				words.append([at + Vector2(0, mr + 25.0), String(o["note"]), Color(DIM, 0.85), 9, "note"])
		elif not gems.is_empty():
			var gw := 22.0 * gems.size()
			var gr := Rect2(at + Vector2(-gw * 0.5, mr - 5.0), Vector2(gw, 11.0))
			vgrad_into(b, chamfer(gr.grow(1.0), 3.0), Color(OUTLINE, 0.95), Color(OUTLINE, 0.95))
			vgrad_into(b, chamfer(gr, 2.6), Color(STONE_2, 0.98), Color(VOID, 0.98))
			for g in gems.size():
				var gc := Vector2(gr.position.x + 7.0 + 22.0 * g, gr.get_center().y)
				gem_into(b, gc, 3.6, gems[g][0])
				words.append([gc + Vector2(5.0, 3.8), str(gems[g][1]), Color(0.96, 0.93, 0.86), 9, "num"])
		if String(o.get("badge", "")) != "":
			var bc := at + Vector2(mr * 0.72, mr * 0.72)
			b.dot(bc, 7.4, Color(OUTLINE, 0.95))
			b.dot(bc, 6.2, Color(0.1, 0.085, 0.13))
			ring_into(b, bc, 6.2, 1.0, Color(GILT, 0.7))
			words.append([bc + Vector2(0, 3.6), String(o["badge"]), GILT_HI, 10, "badge"])
	b.flush(ci)
	var body := font("body")
	var mono := font("mono")
	for w in words:
		var f: Font = mono if w[4] in ["num", "badge"] else body
		var at: Vector2 = w[0]
		if w[4] == "num":
			ci.draw_string_outline(f, at, w[1], HORIZONTAL_ALIGNMENT_LEFT, -1, w[3], 3, Color(0, 0, 0, 0.9))
			draw_text(ci, f, at, w[1], HORIZONTAL_ALIGNMENT_LEFT, -1, w[3], w[2])
			continue
		var wid := 40.0 if w[4] == "badge" else 84.0
		if w[4] == "name":  # (names in the gothic face, like every label)
			draw_label(ci, at - Vector2(wid * 0.5, 0), w[1], w[3] + 2, w[2], HORIZONTAL_ALIGNMENT_CENTER, wid, 3, Color(0, 0, 0, 0.9))
			continue
		ci.draw_string_outline(f, at - Vector2(wid * 0.5, 0), w[1], HORIZONTAL_ALIGNMENT_CENTER, wid, w[3], 3, Color(0, 0, 0, 0.9))
		draw_text(ci, f, at - Vector2(wid * 0.5, 0), w[1], HORIZONTAL_ALIGNMENT_CENTER, wid, w[3], w[2])


## Under a wheel: the pointed-at option's name in the display face between
## gilt rules, and its text. `top` is the name's baseline.
static func draw_wheel_caption(ci: CanvasItem, cx: float, top: float, w: float, title: String, text: String, col: Color, text_size := 14, lines := 2) -> void:
	var x := cx - w * 0.5
	var tw := minf(font("display").get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x, w)
	var b := Draw.Batch.new()
	flank_into(b, cx, top - 6.0, tw * 0.5 + 10.0, 54.0, Color(col, 0.7))
	b.flush(ci)
	draw_title(ci, Vector2(x, top), title, 20, col.lightened(0.25), HORIZONTAL_ALIGNMENT_CENTER, w, 0.8)
	if text != "":
		var body := font("body")
		ci.draw_multiline_string_outline(body, Vector2(x, top + 18.0), text, HORIZONTAL_ALIGNMENT_CENTER, w, text_size, lines, 4, Color(0, 0, 0, 0.85))
		draw_text_lines(ci, body, Vector2(x, top + 18.0), text, HORIZONTAL_ALIGNMENT_CENTER, w, text_size, lines, TEXT)
