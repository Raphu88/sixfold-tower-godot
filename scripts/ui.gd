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


## A small padlock, for slots that aren't open yet.
static func draw_lock(ci: CanvasItem, c: Vector2, s: float, col: Color) -> void:
	ci.draw_arc(c + Vector2(0, -s * 0.25), s * 0.38, PI, TAU, 10, col, maxf(1.0, s * 0.14), true)
	ci.draw_rect(Rect2(c + Vector2(-s * 0.55, -s * 0.2), Vector2(s * 1.1, s * 0.85)), col)
	ci.draw_circle(c + Vector2(0, s * 0.18), s * 0.13, Color(0, 0, 0, 0.6))
