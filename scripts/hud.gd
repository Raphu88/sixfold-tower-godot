extends Node2D
## Screen overlay: vignette, health and stamina, weapons, both bonds,
## controls (H to toggle) and messages.

const BondScript := preload("res://scripts/bond.gd")
const Palette := preload("res://scripts/palette.gd")

const GOLD := Color(0.95, 0.8, 0.5)
const TEXT := Color(0.86, 0.83, 0.9)
const DIM_TEXT := Color(0.62, 0.59, 0.67)

var main
var vignette: GradientTexture2D
var panel: StyleBoxFlat
var slot: StyleBoxFlat
var slot_on: StyleBoxFlat
var hp_trail := 1.0  # the lagging "damage taken" chunk
var sta_trail := 1.0
var show_help := true


func _ready() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 1))
	g.add_point(0.55, Color(0, 0, 0, 0))
	vignette = GradientTexture2D.new()
	vignette.gradient = g
	vignette.fill = GradientTexture2D.FILL_RADIAL
	vignette.fill_from = Vector2(0.5, 0.5)
	vignette.fill_to = Vector2(1.0, 1.0)
	vignette.width = 256
	vignette.height = 256
	panel = _box(Color(0.06, 0.05, 0.08, 0.82), Color(0.32, 0.28, 0.36, 0.9), 6)
	slot = _box(Color(0.06, 0.05, 0.08, 0.75), Color(0.3, 0.27, 0.34, 0.8), 5)
	slot_on = _box(Color(0.14, 0.11, 0.08, 0.9), GOLD, 5)


func _box(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(1)
	b.set_corner_radius_all(radius)
	b.anti_aliasing = true
	return b


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_help"):
		show_help = not show_help
	var p = main.player
	if p != null:
		# The trail holds for a moment, then drains down to the real value.
		hp_trail = move_toward(hp_trail, p.hp / p.max_hp, delta * (0.6 if hp_trail > p.hp / p.max_hp else 10.0))
		sta_trail = move_toward(sta_trail, p.sta / p.max_sta, delta * (0.8 if sta_trail > p.sta / p.max_sta else 10.0))
	queue_redraw()


func _draw() -> void:
	var p = main.player
	if p == null:
		return
	var font := ThemeDB.fallback_font
	var size := get_viewport_rect().size

	draw_texture_rect(vignette, Rect2(Vector2.ZERO, size), false, Color(1, 1, 1, 0.75))
	# Getting hurt flashes the screen edges red.
	if main.hurt_flash > 0.0:
		draw_texture_rect(vignette, Rect2(Vector2.ZERO, size), false, Color(0.9, 0.08, 0.05, main.hurt_flash / 0.35))

	# Health and stamina.
	draw_style_box(panel, Rect2(16, 14, 286, 56))
	_bar(Vector2(28, 24), 262.0, 14.0, p.hp / p.max_hp, hp_trail, Color(0.78, 0.22, 0.2))
	_bar(Vector2(28, 46), 262.0 * p.max_sta / 100.0, 10.0, p.sta / p.max_sta, sta_trail, Color(0.45, 0.72, 0.38))

	# Weapons.
	for i in p.Weapons.ORDER.size():
		var id: String = p.Weapons.ORDER[i]
		var r := Rect2(16 + i * 50, 78, 44, 44)
		var on: bool = id == p.weapon
		draw_style_box(slot_on if on else slot, r)
		_weapon_icon(id, r.get_center() + Vector2(0, -2), GOLD if on else DIM_TEXT)
		draw_string(font, r.position + Vector2(4, 13), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GOLD if on else DIM_TEXT)
	draw_string(font, Vector2(170, 105), p.Weapons.WEAPONS[p.weapon]["name"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, TEXT)

	# Bonds, bottom left.
	var y := size.y - 112.0
	if main.touch_active:
		y = 132.0  # out from under your thumbs
	for part in ["hand", "legs"]:
		var b = p.bonds.get(part)
		if b == null:
			continue
		_bond_panel(b, part, Vector2(16, y), font)
		y += 50.0

	# Controls, top right.
	if main.touch_active:
		pass  # the touch buttons are labelled; no keyboard help needed
	elif show_help:
		var help := [
			["WASD", "move"], ["Shift", "sprint"], ["Space", "roll"],
			["Left click", "strike / hold to draw"], ["Right click", "parry"],
			["1 2 3 / wheel", "weapon"], ["Q  E", "cast bonds"],
			["[  ]", "bond step (testing)"], ["M", "music"], ["R", "restart"], ["H", "hide controls"],
		]
		var box := Rect2(size.x - 262, 14, 246, 20 + help.size() * 17)
		draw_style_box(panel, box)
		for i in help.size():
			var row_y := box.position.y + 24 + i * 17
			draw_string(font, Vector2(box.position.x + 12, row_y), help[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GOLD)
			draw_string(font, Vector2(box.position.x + 106, row_y), help[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT)
	else:
		draw_string(font, Vector2(size.x - 120, 26), "H  controls", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, DIM_TEXT)

	# Messages: a banner across the middle.
	var msg := ""
	var sub := ""
	if p.dead:
		msg = "YOU FELL"
		sub = "Press R to climb again"
	elif main.cleared:
		msg = "ROOM CLEARED"
		sub = "Burns heal at the stair. Press R to fight again"
	if msg != "":
		var band := Rect2(0, size.y / 2.0 - 70.0, size.x, 90.0)
		draw_rect(band, Color(0, 0, 0, 0.55))
		draw_line(band.position, Vector2(band.end.x, band.position.y), Color(GOLD, 0.4), 1.0)
		draw_line(Vector2(0, band.end.y), band.end, Color(GOLD, 0.4), 1.0)
		var col := Color(0.9, 0.3, 0.25) if p.dead else GOLD
		draw_string_outline(font, Vector2(0, band.position.y + 48), msg, HORIZONTAL_ALIGNMENT_CENTER, size.x, 34, 6, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(0, band.position.y + 48), msg, HORIZONTAL_ALIGNMENT_CENTER, size.x, 34, col)
		draw_string(font, Vector2(0, band.position.y + 74), sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, TEXT)


func _bar(pos: Vector2, width: float, height: float, ratio: float, trail: float, color: Color) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	trail = clampf(trail, 0.0, 1.0)
	draw_rect(Rect2(pos - Vector2(1, 1), Vector2(width + 2, height + 2)), Color(0, 0, 0, 0.8))
	draw_rect(Rect2(pos, Vector2(width, height)), Color(color.darkened(0.75), 0.9))
	if trail > ratio:
		draw_rect(Rect2(pos + Vector2(width * ratio, 0), Vector2(width * (trail - ratio), height)), Color(1.0, 0.85, 0.6, 0.8))
	draw_rect(Rect2(pos, Vector2(width * ratio, height)), color)
	draw_rect(Rect2(pos, Vector2(width * ratio, height * 0.4)), Color(1, 1, 1, 0.15))


func _bond_panel(b, part: String, pos: Vector2, font: Font) -> void:
	var r := Rect2(pos, Vector2(420, 44))
	draw_style_box(panel, r)
	var col: Color = b.color()
	var key := "Q" if part == "hand" else "E"
	var c := pos + Vector2(22, 22)
	# The sigil: a ring that fills with essence, the cast key in the middle.
	draw_circle(c, 15.0, Color(0, 0, 0, 0.6))
	draw_arc(c, 15.0, 0.0, TAU, 32, Color(col, 0.25), 3.0)
	var ratio: float = b.essence / b.capacity()
	draw_arc(c, 15.0, -PI / 2.0, -PI / 2.0 + TAU * ratio, 32, col, 3.0)
	var can_cast: bool = b.essence >= b.cost()
	draw_string(font, c + Vector2(-5, 5), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col if can_cast else DIM_TEXT)
	var title := "%s  ·  %s  ·  step %d" % [b.display_name(), BondScript.PART_NAMES[part], b.step]
	draw_string(font, pos + Vector2(46, 17), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
	# Essence bar with a tick at the spell's cost.
	var bar := Rect2(pos + Vector2(46, 24), Vector2(140, 6))
	draw_rect(bar, Color(1, 1, 1, 0.08))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), col)
	var cost_x: float = bar.position.x + bar.size.x * b.cost() / b.capacity()
	draw_line(Vector2(cost_x, bar.position.y - 2), Vector2(cost_x, bar.end.y + 2), Color(1, 1, 1, 0.8), 1.0)
	var note: String = "%s · %s" % [b.spell_name(), BondScript.PART_FILLS[part]]
	var note_col := DIM_TEXT
	if b.burned:
		note = BondScript.PART_BURN[part]
		note_col = Color(1.0, 0.45, 0.35)
	draw_string(font, pos + Vector2(46, 40), note, HORIZONTAL_ALIGNMENT_LEFT, 365, 11, note_col)


func _weapon_icon(id: String, c: Vector2, col: Color) -> void:
	match id:
		"fists":
			draw_circle(c + Vector2(-4, 2), 5.0, col)
			draw_circle(c + Vector2(5, -2), 5.0, col)
		"sword":
			draw_line(c + Vector2(-9, 9), c + Vector2(9, -9), col, 3.0)
			draw_line(c + Vector2(-9, 2), c + Vector2(-2, 9), col, 2.5)
		"bow":
			draw_arc(c + Vector2(-4, 0), 11.0, -1.1, 1.1, 12, col, 2.5)
			draw_line(c + Vector2(-4, 0) + Vector2.from_angle(-1.1) * 11.0, c + Vector2(-4, 0) + Vector2.from_angle(1.1) * 11.0, col, 1.0)
			draw_line(c + Vector2(-6, 0), c + Vector2(10, 0), col, 1.5)
