extends Node2D
## Screen overlay: health, stamina, both bonds, controls and messages.

const BondScript := preload("res://scripts/bond.gd")

var main


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var p = main.player
	if p == null:
		return
	var font := ThemeDB.fallback_font
	var size := get_viewport_rect().size

	# A red edge flash when you get hurt.
	if main.hurt_flash > 0.0:
		var a: float = main.hurt_flash / 0.35 * 0.45
		var edge := 28.0
		var col := Color(0.85, 0.1, 0.08, a)
		draw_rect(Rect2(0, 0, size.x, edge), col)
		draw_rect(Rect2(0, size.y - edge, size.x, edge), col)
		draw_rect(Rect2(0, edge, edge, size.y - edge * 2.0), col)
		draw_rect(Rect2(size.x - edge, edge, edge, size.y - edge * 2.0), col)

	_bar(Vector2(24, 20), 240.0, p.hp / p.max_hp, Color(0.82, 0.31, 0.25), "Health")
	_bar(Vector2(24, 44), 240.0, p.sta / p.max_sta, Color(0.5, 0.78, 0.45), "Stamina")

	var y := size.y - 120.0
	for part in ["hand", "legs"]:
		var b = p.bonds.get(part)
		if b == null:
			continue
		var key := "Q" if part == "hand" else "E"
		var title := "%s mark: %s, step %d" % [BondScript.PART_NAMES[part], b.display_name(), b.step]
		draw_string(font, Vector2(24, y), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 15, b.color())
		var ratio: float = b.essence / b.capacity()
		draw_rect(Rect2(Vector2(24, y + 6), Vector2(220, 8)), Color(1, 1, 1, 0.1))
		draw_rect(Rect2(Vector2(24, y + 6), Vector2(220 * ratio, 8)), b.color())
		var cost_x: float = 24.0 + 220.0 * b.cost() / b.capacity()
		draw_line(Vector2(cost_x, y + 4), Vector2(cost_x, y + 16), Color(1, 1, 1, 0.8), 1.0)
		var note: String = "[%s] %s, costs %d. %s" % [key, b.spell_name(), int(b.cost()), BondScript.PART_FILLS[part]]
		if b.burned:
			note = BondScript.PART_BURN[part]
		var note_col := Color(1.0, 0.45, 0.35) if b.burned else Color(0.75, 0.72, 0.8)
		draw_string(font, Vector2(252, y + 15), note, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, note_col)
		y += 48.0

	var help := [
		"WASD move, Shift sprint, Space roll",
		"Left click strike (3-hit chain), Right click parry",
		"Q / E cast, [ ] change bond step",
		"R restart",
	]
	for i in help.size():
		draw_string(font, Vector2(size.x - 300, 24 + i * 18), help[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.75, 0.72, 0.8))

	var msg := ""
	if p.dead:
		msg = "You fell. Press R to climb again."
	elif main.cleared:
		msg = "Room cleared. Burns heal at the stair. Press R to fight again."
	if msg != "":
		draw_string(font, Vector2(0, size.y / 2.0 - 140.0), msg, HORIZONTAL_ALIGNMENT_CENTER, size.x, 22, Color(1.0, 0.9, 0.7))


func _bar(pos: Vector2, width: float, ratio: float, color: Color, label: String) -> void:
	draw_rect(Rect2(pos, Vector2(width, 14)), Color(0, 0, 0, 0.5))
	draw_rect(Rect2(pos, Vector2(width * clampf(ratio, 0.0, 1.0), 14)), color)
	draw_string(ThemeDB.fallback_font, pos + Vector2(width + 8, 12), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.82, 0.9))
