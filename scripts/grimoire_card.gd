extends Button
## THE GRIMOIRE CARD: one entry of the climber's book, the same card wherever
## an ability shows (the Abilities section, the Tree, and later the essence
## bench), so its words are written once. Drawn in code:
##
##   [drawing]  Name                                   tag     [how it's cast]
##              One plain line: what it does.                  what it costs
##              numbers (a short line, when given)
##              + more: the full numbers (press the card to open them)
##
## `entry` (a Dictionary) says what to show; every key is optional:
##   id, kind ("spell", "technique", "mark", "form", "variation", "effect",
##   "gift", "kinds", "capstone", "later", "empty"), part, name, color,
##   affinity (an essence: the medallion's emblem), glyph (the small
##   drawing: glyph_for() picks one from a form, spell type or variation),
##   does (the one plain line), numbers (a short line of numbers), press (the
##   button that casts it: a key badge), cost (what it costs or how it
##   fills), tag / tag_color (a word beside the name), echo ("echoes Gale
##   Lift"), more (lines in BBCode, shown when opened), fill (0..1, the
##   medallion's ring), locked (dimmed, a lock), state (the tree's: "owned",
##   "in_use", "available", "ready", "passed", "learnable", "locked",
##   "placeholder", "later": tints and fades the card).
## A Button, so the keys, the controller, a click and a tap all reach it
## (menu.gd's touch taps press it). Press it: "more" opens or closes
## (toggled_more), unless `press_only` (the tree uses the press to select).

const UI := preload("res://scripts/ui.gd")
signal toggled_more(id: String, on: bool)

var entry := {}
var words := {}  # "more" and "less"
var small := false
var opened := false
var press_only := false  # a press only emits pressed (the tree selects the card)
var selected := false  # drawn with a gilt edge (the tree's chosen card)
var body: VBoxContainer
var more_box: VBoxContainer
var more_label: Label
const PAD := Vector2(12, 8)
## The states that dim a card, and how much.
const FADE := {"passed": 0.5, "placeholder": 0.55, "later": 0.5, "locked": 0.75}


func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	set_meta("ability", entry.get("id", ""))
	set_meta("ability_part", entry.get("part", ""))
	set_meta("locked", entry.get("locked", false))
	set_meta("grimoire", true)
	_style()
	if not press_only:
		pressed.connect(_toggle)
	_build()


func _style() -> void:
	var col: Color = entry.get("color", UI.FAINT)
	var locked: bool = entry.get("locked", false)
	var st := String(entry.get("state", ""))
	var normal := UI.card(Color(col, 0.75) if not locked else Color(0, 0, 0, 0), not locked, 10.0)
	normal.top = Color(0.12, 0.1, 0.1, 0.92)
	normal.bottom = Color(0.085, 0.07, 0.08, 0.92)
	if locked or st in ["placeholder", "later"]:
		normal.top = Color(0.085, 0.076, 0.09, 0.9)
		normal.bottom = Color(0.07, 0.062, 0.075, 0.9)
	if selected or st == "ready":
		normal.edge = Color(UI.GOLD, 0.95)
	var hover := UI.card(UI.GOLD, not locked, 10.0)
	hover.top = Color(0.17, 0.14, 0.13, 0.98)
	if not locked:
		hover.strip = col
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", hover)
	add_theme_stylebox_override("focus", UI.focus_box())
	modulate.a = float(FADE.get(st, 1.0))


func _build() -> void:
	var col: Color = entry.get("color", UI.FAINT)
	var locked: bool = entry.get("locked", false)
	var st := String(entry.get("state", ""))
	var dim: bool = locked or st in ["placeholder", "later"]
	body = VBoxContainer.new()
	body.add_theme_constant_override("separation", 2)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.set_anchors_preset(Control.PRESET_FULL_RECT)
	body.offset_left = PAD.x + 3.0
	body.offset_right = -PAD.x
	body.offset_top = PAD.y
	body.offset_bottom = -PAD.y
	add_child(body)
	body.minimum_size_changed.connect(_sync_height)
	body.resized.connect(_sync_height)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10 if small else 12)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(h)
	# The small drawing: the medallion, with its glyph.
	var icon := Drawing.new()
	icon.col = col
	icon.affinity = entry.get("affinity", "")
	icon.locked = locked
	icon.fill = float(entry.get("fill", 1.0))
	icon.empty = entry.get("kind", "") == "empty"
	icon.glyph = String(entry.get("glyph", glyph_for(entry)))
	icon.placeholder = st in ["placeholder", "later"]
	icon.custom_minimum_size = Vector2(32, 32) if small else Vector2(40, 40)
	icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(icon)
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 0)
	mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(mid)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(top)
	var n := _l(entry.get("name", ""), "display", 18 if small else 20, col.lightened(0.2) if not dim else UI.DIM)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	top.add_child(n)
	var tag: String = entry.get("tag", "")
	if tag != "":
		var tl := _l(tag, "body", 12 if small else 13, entry.get("tag_color", UI.FAINT))
		tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(tl)
	var d := _l(entry.get("does", ""), "body", 14 if small else 15, UI.TEXT if not dim else UI.DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size.x = 120.0
	mid.add_child(d)
	if String(entry.get("numbers", "")) != "":
		var nl := _l(entry["numbers"], "mono", 11 if small else 12, UI.DIM if not dim else UI.FAINT)
		nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		nl.custom_minimum_size.x = 120.0
		mid.add_child(nl)
	if String(entry.get("echo", "")) != "":
		var el := _l(entry["echo"], "body", 12 if small else 13, Color(UI.VIOLET, 0.95))
		el.set_meta("echo", true)
		mid.add_child(el)
	# How it's cast and what it costs, at the right.
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 1)
	side.mouse_filter = Control.MOUSE_FILTER_IGNORE
	side.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(side)
	if entry.get("press", "") != "":
		var kb := KeyBadge.new()
		kb.key = entry["press"]
		kb.col = col.lightened(0.3)
		kb.size_flags_horizontal = Control.SIZE_SHRINK_END
		side.add_child(kb)
	if entry.get("cost", "") != "":
		var cl := _l(entry["cost"], "mono", 12, UI.GOLD if not dim else UI.FAINT)
		cl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		side.add_child(cl)
	more_label = _l("", "body", 11 if small else 12, UI.FAINT)
	more_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	side.add_child(more_label)
	# More: the full numbers.
	more_box = VBoxContainer.new()
	more_box.add_theme_constant_override("separation", 2)
	more_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(more_box)
	for line in entry.get("more", []):
		var r := RichTextLabel.new()
		r.bbcode_enabled = true
		r.fit_content = true
		r.scroll_active = false
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.custom_minimum_size.x = 160.0
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		r.add_theme_font_override("normal_font", UI.font("body"))
		r.add_theme_font_size_override("normal_font_size", 13 if small else 14)
		r.add_theme_color_override("default_color", UI.DIM if not locked else UI.FAINT)
		r.text = line
		more_box.add_child(r)
	_show_more()


func _l(text: String, role: String, sz: int, c: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.style_label(l, role, sz, c)
	return l


func _show_more() -> void:
	var has: bool = not entry.get("more", []).is_empty() and not press_only
	more_box.visible = opened and has
	more_label.text = String(words.get("less" if opened else "more", "")) if has else ""
	_sync_height()


func _toggle() -> void:
	if entry.get("more", []).is_empty():
		return
	opened = not opened
	_show_more()
	toggled_more.emit(String(entry.get("id", "")), opened)


## Its height follows its contents (the wrapped text, and "more" when open).
func _sync_height() -> void:
	if body == null:
		return
	var h := body.get_combined_minimum_size().y + PAD.y * 2.0
	if absf(custom_minimum_size.y - h) > 0.5:
		custom_minimum_size.y = h


## The small drawing for an entry: from its form, its spell's type or its variation.
static func glyph_for(e: Dictionary) -> String:
	var id := String(e.get("form", e.get("variation", e.get("type", ""))))
	if id == "" and e.has("tech"):
		id = String(e["tech"].get("shape", ""))
	return String(GLYPHS.get(id, ""))


## Which drawing each form, variation and spell type gets (Drawing draws them).
const GLYPHS := {
	"strike": "arc", "shout": "cone", "bolt": "arrow", "volley": "fan", "dash": "chevron", "leap": "hop", "shell": "shield", "push": "ring",
	"pull": "pull", "mark": "target", "sight": "eye", "within": "heart",
	"wide": "ring", "long": "arrow", "quick": "chevron", "split": "fan", "lingering": "pool", "chain": "zig", "delayed": "clock",
	"mirrored": "mirror", "echo": "echo", "charged": "spark",
	"ball_lightning": "orb", "overcharge": "spark", "rod": "zig", "thunderhead": "zig",
}


## A key badge: the button to press ("Q", "LB + X", "tap"), drawn like the HUD's.
class KeyBadge extends Control:
	const UI := preload("res://scripts/ui.gd")
	var key := ""
	var col := Color(0.91, 0.75, 0.42)
	const SIZE := 13

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var w: float = UI.font("mono").get_string_size(key, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x + 8.0
		custom_minimum_size = Vector2(maxf(w, SIZE + 5.0), SIZE + 6.0)

	func _draw() -> void:
		UI.draw_key(self, Vector2(size.x - custom_minimum_size.x, 0.0), key, SIZE, col)


## The card's small drawing: a medallion in its colour with its emblem (or
## a glyph of what it does: a cone, a fan of bolts, a ring...); a lock for
## something not learned yet; an empty socket for an empty slot; a dotted
## ring for something not written yet.
class Drawing extends Control:
	const UI := preload("res://scripts/ui.gd")
	var col := Color.WHITE
	var affinity := ""
	var glyph := ""
	var locked := false
	var empty := false
	var placeholder := false
	var faint := false
	var step := 0
	var fill := 1.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) * 0.5 - (6.0 if step > 0 else 3.0)
		var b := UI.Draw.Batch.new()
		if empty:
			UI.socket_into(b, c, r, 0.0)
		elif placeholder:
			b.dot(c, r, Color(0.1, 0.09, 0.11))
			for i in 12:
				var a := float(i) * TAU / 12.0
				b.arc(c, r - 1.0, a, a + 0.28, 3, Color(col, 0.4), 1.6)
		elif locked:
			b.dot(c, r + 1.6, UI.OUTLINE)
			b.dot(c, r, Color(0.1, 0.095, 0.13))
			b.arc(c, r - 2.0, 0.0, TAU, 28, Color(col, 0.25), 2.0)
			UI.lock_into(b, c, r * 0.62, Color(UI.FAINT, 0.95))
		elif glyph != "" and affinity == "":
			b.dot(c, r + 1.6, UI.OUTLINE)
			b.dot(c, r, col.darkened(0.6))
			b.arc(c, r - 1.5, 0.0, TAU, 28, Color(col, 0.8), 1.6)
		else:
			UI.medallion_into(b, c, r, col, affinity, clampf(fill, 0.0, 1.0), step, 0.35, faint)
		b.flush(self)
		if placeholder:
			draw_string(UI.font("display"), c + Vector2(-4, 6), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(r), Color(col, 0.5))
		elif not locked and not empty and glyph != "" and affinity == "":
			draw_glyph(self, glyph, c, r * 0.62, col.lightened(0.45))

	## A glyph of what something does, `s` its half-size.
	static func draw_glyph(ci: CanvasItem, g: String, c: Vector2, s: float, col: Color) -> void:
		var w := maxf(1.4, s * 0.16)
		match g:
			"arc":
				ci.draw_arc(c + Vector2(-s * 0.5, 0), s, -0.9, 0.9, 12, col, w * 1.4, true)
			"cone":
				ci.draw_polyline(PackedVector2Array([c + Vector2(s, -s * 0.7), c + Vector2(-s, 0), c + Vector2(s, s * 0.7)]), col, w, true)
				ci.draw_arc(c + Vector2(-s, 0), s * 2.0, -0.6, 0.6, 10, col, w, true)
			"arrow":
				ci.draw_line(c + Vector2(-s, 0), c + Vector2(s, 0), col, w, true)
				ci.draw_polyline(PackedVector2Array([c + Vector2(s * 0.4, -s * 0.5), c + Vector2(s, 0), c + Vector2(s * 0.4, s * 0.5)]), col, w, true)
			"fan":
				for a in [-0.45, 0.0, 0.45]:
					var d := Vector2.from_angle(a)
					ci.draw_line(c - d * s * 0.8, c + d * s, col, w, true)
					ci.draw_circle(c + d * s, w * 1.1, col)
			"chevron":
				for k in [-0.5, 0.3]:
					ci.draw_polyline(PackedVector2Array([c + Vector2(k * s - s * 0.3, -s * 0.6), c + Vector2(k * s + s * 0.3, 0), c + Vector2(k * s - s * 0.3, s * 0.6)]), col, w, true)
			"hop":
				ci.draw_arc(c + Vector2(0, s * 0.5), s, PI, TAU, 12, col, w, true)
				ci.draw_circle(c + Vector2(s, s * 0.5), w * 1.4, col)
			"shield":
				ci.draw_arc(c, s, 0.0, TAU, 20, col, w, true)
				ci.draw_arc(c, s * 0.6, 0.0, TAU, 16, Color(col, 0.6), w * 0.8, true)
			"ring":
				for k in [0.4, 0.7, 1.0]:
					ci.draw_arc(c, s * k, 0.0, TAU, 20, Color(col, 1.1 - k * 0.6), w, true)
			"pull":
				ci.draw_line(c + Vector2(s, 0), c + Vector2(-s, 0), col, w, true)
				ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.4, -s * 0.5), c + Vector2(-s, 0), c + Vector2(-s * 0.4, s * 0.5)]), col, w, true)
			"target":
				ci.draw_arc(c, s, 0.0, TAU, 20, col, w, true)
				ci.draw_circle(c, w * 1.5, col)
				for a in 4:
					var d := Vector2.from_angle(a * PI * 0.5)
					ci.draw_line(c + d * s * 0.6, c + d * s * 1.2, col, w, true)
			"eye":
				ci.draw_arc(c + Vector2(0, s * 0.5), s, PI * 1.2, PI * 1.8, 10, col, w, true)
				ci.draw_arc(c - Vector2(0, s * 0.5), s, PI * 0.2, PI * 0.8, 10, col, w, true)
				ci.draw_circle(c, s * 0.3, col)
			"heart":
				ci.draw_circle(c + Vector2(-s * 0.35, -s * 0.15), s * 0.42, col)
				ci.draw_circle(c + Vector2(s * 0.35, -s * 0.15), s * 0.42, col)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.75, 0), c + Vector2(s * 0.75, 0), c + Vector2(0, s * 0.85)]), col)
			"pool":
				ci.draw_arc(c + Vector2(0, s * 0.3), s, 0.0, TAU, 20, Color(col, 0.7), w, true)
				ci.draw_circle(c + Vector2(0, s * 0.3), s * 0.4, Color(col, 0.5))
			"zig":
				ci.draw_polyline(PackedVector2Array([c + Vector2(-s, -s * 0.6), c + Vector2(-s * 0.2, 0), c + Vector2(-s * 0.4, s * 0.1), c + Vector2(s, s * 0.6)]), col, w * 1.2, true)
			"clock":
				ci.draw_arc(c, s, 0.0, TAU, 20, col, w, true)
				ci.draw_line(c, c + Vector2(0, -s * 0.7), col, w, true)
				ci.draw_line(c, c + Vector2(s * 0.5, 0), col, w, true)
			"mirror":
				ci.draw_line(c + Vector2(0, -s), c + Vector2(0, s), Color(col, 0.6), w, true)
				ci.draw_polyline(PackedVector2Array([c + Vector2(s * 0.3, -s * 0.5), c + Vector2(s, 0), c + Vector2(s * 0.3, s * 0.5)]), col, w, true)
				ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.3, -s * 0.5), c + Vector2(-s, 0), c + Vector2(-s * 0.3, s * 0.5)]), col, w, true)
			"echo":
				ci.draw_arc(c + Vector2(-s * 0.4, 0), s * 0.5, -1.2, 1.2, 10, col, w, true)
				ci.draw_arc(c + Vector2(-s * 0.4, 0), s * 0.9, -1.0, 1.0, 10, Color(col, 0.6), w, true)
				ci.draw_arc(c + Vector2(-s * 0.4, 0), s * 1.3, -0.8, 0.8, 10, Color(col, 0.35), w, true)
			"spark":
				for a in 8:
					var d := Vector2.from_angle(a * PI * 0.25)
					ci.draw_line(c + d * s * 0.3, c + d * s * (1.0 if a % 2 == 0 else 0.6), col, w, true)
			"orb":
				ci.draw_circle(c, s * 0.55, Color(col, 0.6))
				ci.draw_circle(c, s * 0.3, col)
				for a in 3:
					var d := Vector2.from_angle(a * TAU / 3.0 + 0.4)
					ci.draw_line(c + d * s * 0.55, c + d * s, col, w, true)
