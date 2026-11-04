extends Node2D
## Screen overlay: vignette, health and stamina, weapons, both bonds,
## controls (H to toggle) and messages.

const BondScript := preload("res://scripts/bond.gd")
const Palette := preload("res://scripts/palette.gd")
const Essence := preload("res://scripts/essence.gd")

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
var show_help := false  # the keyboard controls panel (a setting)


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
	if p.barrier_hp > 0.0:
		# The Warden's barrier: a gold band over the health bar.
		var bw: float = 262.0 * clampf(p.barrier_hp / p.max_hp, 0.0, 1.0)
		draw_rect(Rect2(Vector2(28, 24), Vector2(bw, 6)), Color(1.0, 0.85, 0.45, 0.85))
	if p.max_health() < p.max_hp:
		# A burned heart caps your health: show the lost part as scorched.
		var cap_x: float = 28.0 + 262.0 * p.max_health() / p.max_hp
		draw_rect(Rect2(Vector2(cap_x, 24), Vector2(290.0 - cap_x, 14)), Color(1.0, 0.35, 0.2, 0.35))
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

	# Essence gathered since the last stair (lost if you fall before it).
	var ex := 16.0
	var any_essence := false
	for kind in Essence.KINDS:
		var amt: float = main.run_essence.get(kind, 0.0)
		if amt <= 0.0:
			continue
		any_essence = true
		var ec := Essence.color(kind)
		draw_circle(Vector2(ex + 6, 140), 5.0, ec)
		draw_string(font, Vector2(ex + 15, 145), str(int(amt)), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, TEXT)
		ex += 52.0
	if any_essence:
		draw_string(font, Vector2(ex + 2, 145), "unbanked", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM_TEXT)

	# Bonds (marks), bottom left; on phones, up top out from under your thumbs.
	var parts: Array = BondScript.Bonds.PARTS.filter(func(pt): return p.bonds.has(pt))
	var y := size.y - 12.0 - 50.0 * parts.size()
	if main.touch_active:
		y = 156.0
	for part in parts:
		var b = p.bonds[part]
		if main.touch_active:
			_bond_compact(b, part, Vector2(12, y), font)
			y += 37.0
		else:
			_bond_panel(b, part, Vector2(16, y), font)
			y += 50.0
	# Where the next mark is forming (while any body part is still unmarked).
	if parts.size() < BondScript.Bonds.PARTS.size():
		var fh := _forming_height(p)
		if main.touch_active:
			_draw_forming(p, Vector2(12, y + 2), font)
		else:
			_draw_forming(p, Vector2(16, size.y - 12.0 - 50.0 * parts.size() - fh - 8.0), font)

	# Controls, top right.
	if main.touch_active:
		pass  # the touch buttons are labelled; no keyboard help needed
	elif show_help:
		var help := [
			["WASD", "move"], ["Shift", "sprint"], ["Space", "roll"], ["Z", "jump"],
			["Left click", "strike / hold to draw"], ["Right click", "parry"],
			["1 2 3 / wheel", "weapon"], ["Q E F C X V", "cast marks"],
			["Esc", "menu"], ["M", "music"], ["R", "restart"], ["H", "hide controls"],
		]
		var box := Rect2(size.x - 262, 14, 246, 20 + help.size() * 17)
		draw_style_box(panel, box)
		for i in help.size():
			var row_y := box.position.y + 24 + i * 17
			draw_string(font, Vector2(box.position.x + 12, row_y), help[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GOLD)
			draw_string(font, Vector2(box.position.x + 106, row_y), help[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT)
	else:
		draw_string(font, Vector2(size.x - 120, 26), "Esc  menu", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, DIM_TEXT)

	# Floor counter, top centre.
	var floor_text: String = main._floor_title()
	draw_string_outline(font, Vector2(0, 30), floor_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, 5, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(0, 30), floor_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, GOLD)
	draw_string(font, Vector2(0, 48), "%s  ·  best %d" % [main.tower_data()["short"], main.best_floor], HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, DIM_TEXT)
	if main.stair_open and not main.climbing:
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.005)
		var left: int = main.enemies().size()
		var stair_text := "The stair is open"
		if left > 0:
			stair_text += "  ·  %d %s left" % [left, "foe" if left == 1 else "foes"]
		draw_string_outline(font, Vector2(0, 68), stair_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, 4, Color(0, 0, 0, 0.7))
		draw_string(font, Vector2(0, 68), stair_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(1.0, 0.88, 0.6, pulse))

	# A new floor: its number and what changed, fading out.
	if not main.banner.is_empty():
		var b: Dictionary = main.banner
		var a: float = clampf(b["t"] / 0.6, 0.0, 1.0)
		var top := size.y * 0.3
		draw_string_outline(font, Vector2(0, top), b["title"], HORIZONTAL_ALIGNMENT_CENTER, size.x, 40, 7, Color(0, 0, 0, 0.8 * a))
		draw_string(font, Vector2(0, top), b["title"], HORIZONTAL_ALIGNMENT_CENTER, size.x, 40, Color(GOLD, a))
		var ly := top + 30.0
		for line in b["lines"]:
			draw_string_outline(font, Vector2(0, ly), line, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, 4, Color(0, 0, 0, 0.8 * a))
			draw_string(font, Vector2(0, ly), line, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, Color(TEXT, a))
			ly += 22.0

	# Messages: a banner across the middle.
	var msg := ""
	var sub := ""
	if p.dead and not main.first_climb:
		msg = "YOU FELL ON FLOOR %d" % main.floor_num
		sub = "Best: floor %d.  %s to climb again" % [main.best_floor, "Tap R" if main.touch_active else "Press R"]
	if msg != "":
		var band := Rect2(0, size.y / 2.0 - 70.0, size.x, 90.0)
		draw_rect(band, Color(0, 0, 0, 0.55))
		draw_line(band.position, Vector2(band.end.x, band.position.y), Color(GOLD, 0.4), 1.0)
		draw_line(Vector2(0, band.end.y), band.end, Color(GOLD, 0.4), 1.0)
		var col := Color(0.9, 0.3, 0.25) if p.dead else GOLD
		draw_string_outline(font, Vector2(0, band.position.y + 48), msg, HORIZONTAL_ALIGNMENT_CENTER, size.x, 34, 6, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(0, band.position.y + 48), msg, HORIZONTAL_ALIGNMENT_CENTER, size.x, 34, col)
		draw_string(font, Vector2(0, band.position.y + 74), sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, TEXT)

	# Between floors the screen fades to black.
	if main.fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, main.fade))

	_draw_boss_bar(size, font)
	if not main.regard.is_empty():
		_draw_regard(size, font)
	if not main.victory.is_empty():
		_draw_victory(size, font)
	if main.choosing_tower:
		_draw_tower_choice(size, font)
	_draw_quarry(p, size, font)
	if p.pick_open:
		_draw_spell_ring(p, font)


func _bar(pos: Vector2, width: float, height: float, ratio: float, trail: float, color: Color) -> void:
	ratio = clampf(ratio, 0.0, 1.0)
	trail = clampf(trail, 0.0, 1.0)
	draw_rect(Rect2(pos - Vector2(1, 1), Vector2(width + 2, height + 2)), Color(0, 0, 0, 0.8))
	draw_rect(Rect2(pos, Vector2(width, height)), Color(color.darkened(0.75), 0.9))
	if trail > ratio:
		draw_rect(Rect2(pos + Vector2(width * ratio, 0), Vector2(width * (trail - ratio), height)), Color(1.0, 0.85, 0.6, 0.8))
	draw_rect(Rect2(pos, Vector2(width * ratio, height)), color)
	draw_rect(Rect2(pos, Vector2(width * ratio, height * 0.4)), Color(1, 1, 1, 0.15))


## The phone version: sigil, name and essence bar only.
func _bond_compact(b, part: String, pos: Vector2, font: Font) -> void:
	var r := Rect2(pos, Vector2(196, 34))
	draw_style_box(panel, r)
	var col: Color = b.color()
	var c := pos + Vector2(17, 17)
	var ratio: float = b.essence / b.capacity()
	draw_circle(c, 11.0, Color(0, 0, 0, 0.6))
	draw_arc(c, 11.0, 0.0, TAU, 28, Color(col, 0.25), 2.5)
	draw_arc(c, 11.0, -PI / 2.0, -PI / 2.0 + TAU * ratio, 28, col, 2.5)
	var label: String = b.display_name()
	if b.burned:
		label = "%s burned!" % BondScript.PART_NAMES[part]
	draw_string(font, pos + Vector2(34, 14), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1.0, 0.45, 0.35) if b.burned else col)
	var bar := Rect2(pos + Vector2(34, 21), Vector2(150, 5))
	draw_rect(bar, Color(1, 1, 1, 0.08))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), col)
	var cost_x: float = bar.position.x + bar.size.x * b.cost() / b.capacity()
	draw_line(Vector2(cost_x, bar.position.y - 2), Vector2(cost_x, bar.end.y + 2), Color(1, 1, 1, 0.8), 1.0)


func _bond_panel(b, part: String, pos: Vector2, font: Font) -> void:
	var r := Rect2(pos, Vector2(420, 44))
	draw_style_box(panel, r)
	var col: Color = b.color()
	var key: String = BondScript.Bonds.PART_KEYS[part]
	var c := pos + Vector2(22, 22)
	# The sigil: a ring that fills with essence, the cast key in the middle.
	draw_circle(c, 15.0, Color(0, 0, 0, 0.6))
	draw_arc(c, 15.0, 0.0, TAU, 32, Color(col, 0.25), 3.0)
	var ratio: float = b.essence / b.capacity()
	draw_arc(c, 15.0, -PI / 2.0, -PI / 2.0 + TAU * ratio, 32, col, 3.0)
	var can_cast: bool = b.essence >= b.cost()
	draw_string(font, c + Vector2(-5, 5), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, col if can_cast else DIM_TEXT)
	var title := "%s  ·  %s  ·  %s" % [b.display_name(), BondScript.PART_NAMES[part], "faint" if b.faint else "step %d" % b.step]
	draw_string(font, pos + Vector2(46, 17), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, col)
	# Essence bar with a tick at the spell's cost.
	var bar := Rect2(pos + Vector2(46, 24), Vector2(140, 6))
	draw_rect(bar, Color(1, 1, 1, 0.08))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * ratio, bar.size.y)), col)
	var cost_x: float = bar.position.x + bar.size.x * b.cost() / b.capacity()
	draw_line(Vector2(cost_x, bar.position.y - 2), Vector2(cost_x, bar.end.y + 2), Color(1, 1, 1, 0.8), 1.0)
	var known: int = b.spells().size()
	var note: String = "%s%s: %s" % [b.spell_name(), "  (%d/%d, hold %s to pick)" % [b.selected + 1, known, key] if known > 1 else "", b.spell_desc()]
	var note_col := DIM_TEXT
	if b.burned:
		note = BondScript.PART_BURN[part] + " · overdraw again and it tears (costs health)"
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


## The Regard: the beast's eye opens on you, and your first mark takes hold.
func _draw_regard(size: Vector2, font: Font) -> void:
	var rg: Dictionary = main.regard
	var t: float = rg["t"]
	var info: Dictionary = BondScript.Bonds.BONDS[rg["id"]]
	var col: Color = info["color"]
	var fell: bool = rg["fell"]
	var part_name: String = BondScript.PART_NAMES[rg["part"]]
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.03, clampf(t / 0.8, 0.0, 0.96)))
	var c := Vector2(size.x / 2.0, size.y * 0.3)
	# The eye opens.
	var open := clampf((t - 0.4) / 1.2, 0.0, 1.0)
	open = open * open * (3.0 - 2.0 * open)
	var w := minf(size.x * 0.36, 300.0)
	var h := 70.0 * open
	var lid := PackedVector2Array()
	for i in 33:
		var k := float(i) / 32.0
		lid.append(c + Vector2(lerpf(-w, w, k), -sin(PI * k) * h))
	for i in 33:
		var k := float(i) / 32.0
		lid.append(c + Vector2(lerpf(w, -w, k), sin(PI * k) * h))
	draw_colored_polygon(lid, Color(0.95, 0.85, 0.55, 0.12 + 0.1 * open))
	draw_polyline(lid + PackedVector2Array([lid[0]]), Color(1.0, 0.85, 0.5, 0.8 * open + 0.1), 2.5, true)
	if open > 0.2:
		var iris := 52.0 * minf(1.0, open * 1.2)
		draw_circle(c, iris, Color(col, 0.55))
		draw_circle(c, iris * 0.62, Color(col.lightened(0.3), 0.8))
		draw_circle(c, iris * 0.28, Color(0.02, 0.02, 0.03, 0.95))
		draw_arc(c, iris, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 2.0)
	# The mark grows beneath it.
	var mk := clampf((t - 1.6) / 1.0, 0.0, 1.0)
	if mk > 0.0:
		var mc := c + Vector2(0, 130)
		var mcol := Color(col, (0.55 if fell else 1.0) * mk)
		draw_circle(mc, 10.0, mcol)
		var lines := 3 if fell else 6
		for i in lines:
			var a := -PI / 2.0 + TAU * float(i) / float(lines)
			draw_line(mc + Vector2.from_angle(a) * 14.0, mc + Vector2.from_angle(a) * (14.0 + 26.0 * mk), mcol, 3.0)
	var texts: Array = []
	if fell:
		texts = [
			"You fell, but %s was watching." % main.beast_name(),
			"Essence takes hold in your %s, faintly." % part_name,
			"You bear a faint %s mark." % info["name"],
			"It will grow once it has soaked up more essence.",
		]
	else:
		texts = [
			"You reached the top. %s has watched you climb." % main.beast_name().capitalize(),
			"Essence takes hold in your %s." % part_name,
			"You bear the %s mark." % info["name"],
			"%s: %s." % [info["spells"][0]["name"], BondScript.PART_FILLS[rg["part"]]],
		]
	var title_a := clampf((t - 0.2) / 0.6, 0.0, 1.0)
	draw_string_outline(font, Vector2(0, size.y * 0.3 - 110), "THE REGARD", HORIZONTAL_ALIGNMENT_CENTER, size.x, 34, 7, Color(0, 0, 0, 0.8 * title_a))
	draw_string(font, Vector2(0, size.y * 0.3 - 110), "THE REGARD", HORIZONTAL_ALIGNMENT_CENTER, size.x, 34, Color(GOLD, title_a))
	var ty := size.y * 0.3 + 190.0
	for i in texts.size():
		var a := clampf((t - 1.4 - i * 0.45) / 0.5, 0.0, 1.0)
		var tc := col.lightened(0.2) if i == 2 else TEXT
		draw_string(font, Vector2(0, ty), texts[i], HORIZONTAL_ALIGNMENT_CENTER, size.x, 17 if i == 2 else 15, Color(tc, a))
		ty += 26.0
	if main.regard_done():
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
		var prompt := "Tap to begin your next climb" if main.touch_active else "Press Space or click to begin your next climb"
		draw_string(font, Vector2(0, size.y - 40), prompt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(DIM_TEXT, 0.5 + 0.5 * pulse))


func _forming_height(p) -> float:
	var unmarked: int = BondScript.Bonds.PARTS.size() - p.bonds.size()
	return 44.0 + 15.0 * unmarked


## A small panel: how much each unmarked body part has soaked (the leader is
## where the next mark will form) and which bond it would be right now.
func _draw_forming(p, pos: Vector2, font: Font) -> void:
	var unmarked: Array = BondScript.Bonds.PARTS.filter(func(pt): return not p.bonds.has(pt))
	var r := Rect2(pos, Vector2(214, _forming_height(p)))
	draw_style_box(panel, r)
	var title := "Your mark is forming" if main.first_climb else "Your next mark"
	draw_string(font, pos + Vector2(10, 16), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, DIM_TEXT)
	var leader: String = main.leading_part()
	var lead_soak := maxf(main.part_soak(leader) if leader != "" else 0.0, 1.0)
	var y := pos.y + 24.0
	for part in unmarked:
		var v: float = main.part_soak(part) / lead_soak if main.first_climb else main.soak_fraction(part)
		var on: bool = part == leader
		var name_col := GOLD if on else DIM_TEXT
		draw_string(font, Vector2(pos.x + 10, y + 9), BondScript.PART_NAMES[part], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, name_col)
		var bar := Rect2(Vector2(pos.x + 56, y + 2), Vector2(148, 7))
		draw_rect(bar, Color(1, 1, 1, 0.07))
		draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(v, 0.0, 1.0), bar.size.y)), Color(GOLD, 0.9) if on else Color(TEXT, 0.35))
		y += 15.0
	var bid: String = main.predicted_bond()
	if bid == "":
		draw_string(font, Vector2(pos.x + 10, y + 13), "Every way you fight soaks in", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM_TEXT)
	else:
		var info: Dictionary = BondScript.Bonds.BONDS[bid]
		draw_string(font, Vector2(pos.x + 10, y + 13), "Would be:", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM_TEXT)
		draw_string(font, Vector2(pos.x + 68, y + 13), "%s (%s)" % [info["name"], BondScript.PART_NAMES[leader]], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, info["color"])


# --- choosing a tower --------------------------------------------------------------

const TowersData := preload("res://scripts/towers.gd")


func tower_card_rect(i: int, size: Vector2) -> Rect2:
	var total := TowersData.ORDER.size()
	var rows := 2 if total > 4 else 1
	var n := int(ceil(float(total) / rows))  # cards per row
	var w := minf(260.0, (size.x - 40.0 - 16.0 * (n - 1)) / n)
	var h := 230.0 if rows == 1 else minf(160.0, (size.y - 170.0) / 2.0)
	var x0 := (size.x - (w * n + 16.0 * (n - 1))) / 2.0
	var row := i / n
	var col := i % n
	var top := size.y * 0.5 - (h * rows + 12.0 * (rows - 1)) * 0.5 + 30.0
	return Rect2(Vector2(x0 + col * (w + 16.0), top + row * (h + 12.0)), Vector2(w, h))


## Which tower card is under a point on screen (-1 for none).
func tower_card_at(pos: Vector2) -> int:
	var size := get_viewport_rect().size
	for i in TowersData.ORDER.size():
		if tower_card_rect(i, size).has_point(pos):
			return i
	return -1


func _unhandled_input(event: InputEvent) -> void:
	if main != null and main.choosing_tower and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := tower_card_at(get_local_mouse_position())
		if i >= 0:
			main.choose_tower(TowersData.ORDER[i])


func _draw_tower_choice(size: Vector2, font: Font) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.03, 0.88))
	var title := "CHOOSE A TOWER"
	var top_y := tower_card_rect(0, size).position.y
	draw_string_outline(font, Vector2(0, top_y - 46.0), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 32, 6, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(0, top_y - 46.0), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 32, GOLD)
	var sub := "Each tower's monsters and essence shape the marks you'll form."
	draw_string(font, Vector2(0, top_y - 20.0), sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, DIM_TEXT)
	for i in TowersData.ORDER.size():
		var id: String = TowersData.ORDER[i]
		var t: Dictionary = TowersData.TOWERS[id]
		var r := tower_card_rect(i, size)
		var ec := Essence.color(t["essence"])
		var last: bool = id == main.profile.last_tower
		var box := slot_on if last else panel
		draw_style_box(box, r)
		draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 5)), Color(t["torch"], 0.7))
		var x := r.position.x + 14.0
		var y := r.position.y + 34.0
		var narrow := r.size.x < 200.0 or r.size.y < 200.0  # many cards, or a phone
		draw_string(font, Vector2(x, y), t["short"] if narrow else t["name"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28.0, 17, TEXT)
		y += 24.0
		draw_circle(Vector2(x + 6, y - 5), 6.0, ec)
		draw_string(font, Vector2(x + 18, y), "%s essence" % Essence.display(t["essence"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ec)
		y += 18.0
		draw_multiline_string(font, Vector2(x, y + 4), t["blurb"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28.0, 11 if narrow else 13, 4 if r.size.y < 200.0 else 7, DIM_TEXT)
		var hint := "Tap" if main.touch_active else "Press %d" % (i + 1)
		draw_string(font, Vector2(r.position.x, r.end.y - 14.0), hint, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13, GOLD if last else DIM_TEXT)


# --- hold to pick ----------------------------------------------------------------

## The ring of a mark's spells, around the climber (or the held button on a
## phone). The highlighted one is cast when you let go.
func _draw_spell_ring(p, font: Font) -> void:
	var b = p.bonds.get(p.pick_part)
	if b == null:
		return
	var known: Array = b.spells()
	var c: Vector2 = main.pick_anchor if main.touch_active else p.get_global_transform_with_canvas().origin
	var ring_r := 78.0
	draw_circle(c, ring_r + 34.0, Color(0, 0, 0, 0.45))
	var col: Color = b.color()
	for i in known.size():
		var a := -PI / 2.0 + TAU * float(i) / float(known.size())
		var at := c + Vector2.from_angle(a) * ring_r
		var on: bool = i == p.pick_index
		draw_circle(at, 25.0 if on else 21.0, Color(0.05, 0.04, 0.07, 0.92))
		draw_arc(at, 25.0 if on else 21.0, 0.0, TAU, 28, Color(col, 1.0 if on else 0.45), 3.0 if on else 1.5)
		var words: PackedStringArray = known[i]["name"].split(" ")
		for w in words.size():
			draw_string(font, at + Vector2(-30, 4 + (w - (words.size() - 1) / 2.0) * 11.0), words[w], HORIZONTAL_ALIGNMENT_CENTER, 60, 10, Color(col.lightened(0.3), 1.0) if on else DIM_TEXT)
	if p.pick_index >= 0 and p.pick_index < known.size():
		var sp: Dictionary = known[p.pick_index]
		draw_string_outline(font, c + Vector2(-160, ring_r + 54.0), sp["name"], HORIZONTAL_ALIGNMENT_CENTER, 320, 15, 4, Color(0, 0, 0, 0.8))
		draw_string(font, c + Vector2(-160, ring_r + 54.0), sp["name"], HORIZONTAL_ALIGNMENT_CENTER, 320, 15, col.lightened(0.2))
		draw_multiline_string_outline(font, c + Vector2(-170, ring_r + 72.0), sp["desc"], HORIZONTAL_ALIGNMENT_CENTER, 340, 12, 2, 4, Color(0, 0, 0, 0.8))
		draw_multiline_string(font, c + Vector2(-170, ring_r + 72.0), sp["desc"], HORIZONTAL_ALIGNMENT_CENTER, 340, 12, 2, TEXT)


## Hunter's Quarry: the last foe you struck is always marked, and an arrow at
## the screen edge points to it when it's out of sight.
func _draw_quarry(p, size: Vector2, font: Font) -> void:
	if not p.has_bond("hunter") or p.quarry == null or not is_instance_valid(p.quarry) or p.quarry.dead:
		return
	var at: Vector2 = p.quarry.get_global_transform_with_canvas().origin
	var col := Color(0.85, 0.63, 0.42)
	var inner := Rect2(Vector2(24, 24), size - Vector2(48, 48))
	if inner.has_point(at):
		var top := at + Vector2(0, -p.quarry.radius * 1.6 - 14.0)
		draw_colored_polygon(PackedVector2Array([top + Vector2(-6, -8), top + Vector2(6, -8), top]), Color(col, 0.9))
	else:
		var center := size / 2.0
		var dir := (at - center).normalized()
		var edge := Vector2(clampf(at.x, inner.position.x, inner.end.x), clampf(at.y, inner.position.y, inner.end.y))
		var side := dir.orthogonal()
		draw_colored_polygon(PackedVector2Array([edge + dir * 10.0, edge - dir * 6.0 + side * 8.0, edge - dir * 6.0 - side * 8.0]), Color(col, 0.9))


# --- bosses ------------------------------------------------------------------------

## A beast's health, as a long bar under the floor counter.
func _draw_boss_bar(size: Vector2, font: Font) -> void:
	for e in main.enemies():
		if not e.is_boss():
			continue
		var w := minf(460.0, size.x - 120.0)
		var r := Rect2(Vector2((size.x - w) / 2.0, 84), Vector2(w, 12))
		var name: String = main.beast_name().to_upper()
		draw_string_outline(font, Vector2(0, 78), name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, 4, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(0, 78), name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, GOLD)
		draw_rect(r.grow(2.0), Color(0, 0, 0, 0.8))
		draw_rect(r, Color(0.3, 0.1, 0.08, 0.9))
		draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(e.hp / e.max_hp, 0.0, 1.0), r.size.y)), Color(0.85, 0.3, 0.22))
		draw_line(Vector2(r.position.x + r.size.x * 0.5, r.position.y), Vector2(r.position.x + r.size.x * 0.5, r.end.y), Color(1, 1, 1, 0.35), 1.0)
		return


## The climb is complete: the beast has fallen.
func _draw_victory(size: Vector2, font: Font) -> void:
	var v: Dictionary = main.victory
	var t: float = v["t"]
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.03, clampf(t / 0.8, 0.0, 0.94)))
	var a := clampf((t - 0.3) / 0.6, 0.0, 1.0)
	var top := size.y * 0.32
	draw_string_outline(font, Vector2(0, top), "CLIMB COMPLETE", HORIZONTAL_ALIGNMENT_CENTER, size.x, 40, 7, Color(0, 0, 0, 0.8 * a))
	draw_string(font, Vector2(0, top), "CLIMB COMPLETE", HORIZONTAL_ALIGNMENT_CENTER, size.x, 40, Color(GOLD, a))
	draw_string(font, Vector2(0, top + 34), "%s yields." % String(v["beast"]).capitalize(), HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color(TEXT, a))
	var ly := top + 70.0
	for line in v["lines"]:
		draw_string(font, Vector2(0, ly), line, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(DIM_TEXT, a))
		ly += 22.0
	if main.overlay_done():
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
		var prompt := "Tap to climb again" if main.touch_active else "Press Space or click to climb again"
		draw_string(font, Vector2(0, size.y - 40), prompt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(DIM_TEXT, 0.5 + 0.5 * pulse))
