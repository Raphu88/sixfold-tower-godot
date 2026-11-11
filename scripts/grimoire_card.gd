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


## The small drawing for an entry (Drawing draws it). Picked, in order:
## a glyph made for that very id (GLYPHS: today's forms, variations,
## effects and the spell types where it matters); else read from its data
## so new content gets a sensible picture by itself: the words of its line
## (WORDS: "a wall of wind" is a wall, "three small bolts in a fan" a fan),
## then its numbers (NUMBERS: a radius is a ring, a speed a bolt...), then
## its class or kind. "" draws the medallion (the bond's or the essence's emblem).
static func glyph_for(e: Dictionary) -> String:
	if String(e.get("glyph", "")) != "":
		return String(e["glyph"])
	var kind := String(e.get("kind", ""))
	if KIND_GLYPHS.has(kind):
		return KIND_GLYPHS[kind]
	if e.has("tech") and e["tech"] is Dictionary:
		var shape := String(e["tech"].get("shape", ""))
		return form_glyph(shape)
	if String(e.get("form", "")) != "":
		return form_glyph(String(e["form"]))
	if String(e.get("variation", "")) != "":
		return variation_glyph(String(e["variation"]))
	if kind == "effect":
		return effect_glyph(String(e.get("id", "")))
	var sp: Dictionary = e["spell"] if e.get("spell") is Dictionary else {}
	if sp.is_empty() and (kind == "spell" or e.has("type")):
		sp = _find_spell(String(e.get("id", "")))
	if not sp.is_empty() or e.has("type"):
		return spell_glyph(sp if not sp.is_empty() else {"type": e.get("type", ""), "desc": e.get("does", ""), "name": e.get("name", "")})
	return String(GLYPHS.get(String(e.get("id", "")), ""))


## A form's glyph: its own, else its line's words, its numbers or its class.
static func form_glyph(id: String) -> String:
	if GLYPHS.has(id):
		return GLYPHS[id]
	var f: Dictionary = _lib().form(id)
	if f.is_empty():
		return ""
	var g := from_words(String(f.get("says", "")) + " " + String(f.get("name", "")))
	if g == "":
		g = from_numbers(f)
	return g if g != "" else String(CLASS_GLYPHS.get(String(f.get("class", "")), "arc"))


## A variation's glyph: its own, else its line's words or its numbers.
static func variation_glyph(id: String) -> String:
	if GLYPHS.has(id):
		return GLYPHS[id]
	var v: Dictionary = _lib().variation(id)
	var g := from_words(String(v.get("says", "")) + " " + String(v.get("name", "")))
	if g == "":
		g = from_numbers(v)
	return g if g != "" else "spark"


## An effect's glyph: its own, else its line's words or its numbers; else
## "" (its essence's emblem).
static func effect_glyph(id: String) -> String:
	if GLYPHS.has(id):
		return GLYPHS[id]
	var fx: Dictionary = _lib().effect(id)
	var g := from_words(String(fx.get("says", "")) + " " + String(fx.get("name", "")))
	return g if g != "" else from_numbers(fx)


## A bond spell's glyph: its type's own, else its line's words, else its
## first step's numbers; else "" (the bond's emblem).
static func spell_glyph(sp: Dictionary) -> String:
	var type := String(sp.get("type", ""))
	if GLYPHS.has(type):
		return GLYPHS[type]
	var g := from_words(String(sp.get("desc", sp.get("says", ""))) + " " + String(sp.get("name", "")))
	if g != "":
		return g
	var steps: Dictionary = sp.get("steps", {}) if sp.get("steps") is Dictionary else {}
	var nums := {}
	for s in steps:
		if steps[s] is Dictionary:
			nums.merge(steps[s])
	return from_numbers(nums)


## The first of WORDS found in a line ("" if none).
static func from_words(text: String) -> String:
	var t := " " + text.to_lower() + " "
	for w in WORDS:
		if t.contains(w[0]):
			return w[1]
	return ""


## The first of NUMBERS an entry has ("" if none).
static func from_numbers(d: Dictionary) -> String:
	for n in NUMBERS:
		if d.has(n[0]):
			return n[1]
	return ""


static func _lib():
	return load("res://scripts/library.gd")


## A bond spell (or a tower's alternative) by id ({} if none).
static func _find_spell(id: String) -> Dictionary:
	if id == "":
		return {}
	var B = load("res://scripts/bonds.gd")
	for b in B.BONDS:
		for sp in B.BONDS[b].get("spells", []):
			if String(sp.get("id", "")) == id:
				return sp
	var forks: Dictionary = _lib().MARK_FORKS
	for b in forks:
		for k in forks[b]:
			if forks[b][k] is Dictionary and String(forks[b][k].get("id", "")) == id:
				return forks[b][k]
	return {}


## Glyphs made for an id: today's forms, variations and effects, and the
## spell types where the words would mislead. (Anything not here is read
## from its data: glyph_for.)
const GLYPHS := {
	# forms
	"strike": "arc", "shout": "cone", "bolt": "arrow", "volley": "fan", "dash": "chevron", "leap": "hop", "shell": "shield", "push": "burst",
	"pull": "pull", "mark": "target", "sight": "eye", "within": "heart",
	# variations
	"wide": "ring", "long": "long", "quick": "chevron", "split": "fan", "lingering": "pool", "chain": "zig", "delayed": "clock",
	"mirrored": "mirror", "echo": "echo", "charged": "spark",
	# effects
	"burn": "flame", "slow": "drop", "reach": "swirl", "stagger": "hex", "pierce": "pierce", "cut": "blade", "heal": "heart", "erode": "crack",
	"spark": "zig",
	# bond spell types ("chain" is the variation's zig too)
	"ball_lightning": "orb", "overcharge": "spark", "rod": "rod", "thunderhead": "storm", "lift": "up", "cyclone": "swirl",
	"shot": "pierce", "hawkeye": "eye", "track": "target", "rain": "rain", "surge": "wave", "riptide": "swirl", "maelstrom": "swirl",
	"barrier": "shield", "absorb": "shield", "unbreakable": "shield", "challenge": "target", "drain": "pull", "siphon": "pull", "drink": "drop",
	"blades": "fan", "recall": "pull", "edges": "burst", "kindle": "flame", "lash": "arc", "trap": "rune", "inscribe": "rune", "ward": "ring",
	"sigil": "rune", "quake": "crack", "fault": "crack", "sandwall": "wall", "sinkhole": "pool", "spit": "arrow", "cloud": "cloud", "veil": "cloud",
	"decoy": "mirror", "vanish": "eye", "ashfall": "rain", "fireball": "orb", "firewall": "wall", "cluster": "burst", "meteor": "down",
	"aura": "aura", "wingburst": "burst", "firebirdform": "flame", "phoenix": "flame", "rekindle": "heart", "overheat": "flame",
}
## The tree's other kinds of node.
const KIND_GLYPHS := {"gift": "gift", "kinds": "kinds", "capstone": "crown", "forms": "arc"}
## A form's class, when nothing else says (library.gd FORMS "class").
const CLASS_GLYPHS := {"hit": "arc", "move": "chevron", "shell": "shield", "self": "heart", "mark": "target", "sight": "eye"}
## Words in a line and the glyph they mean, the first found wins (so the
## more telling ones come first).
const WORDS := [
	["orb", "orb"], ["wall", "wall"], ["beam", "beam"], ["cone", "cone"], [" fan", "fan"], ["copies", "fan"], ["shards", "fan"], ["blades", "fan"],
	["cyclone", "swirl"], ["whirl", "swirl"], ["maelstrom", "swirl"], ["vortex", "swirl"],
	["lightning", "zig"], [" leap", "zig"], ["chain", "zig"], ["jump", "zig"], ["spark", "zig"],
	["rain", "rain"], ["meteor", "down"], ["slam", "down"], ["launch", "up"], ["lift", "up"], ["float", "up"], ["aloft", "up"],
	["pierc", "pierce"], ["arrow", "arrow"], [" shot", "arrow"], ["bolt", "arrow"], ["spit", "arrow"], ["thrown", "arrow"],
	["shell", "shield"], ["barrier", "shield"], ["shield", "shield"], ["block", "shield"], ["absorb", "shield"], ["cloak", "shield"], ["less damage", "shield"],
	["cloud", "cloud"], ["smoke", "cloud"], ["mist", "cloud"], [" fog", "cloud"], ["veil", "cloud"], ["lose sight", "cloud"],
	["rune", "rune"], ["sigil", "rune"], ["trap", "rune"], [" sign", "rune"], ["inscri", "rune"],
	[" ring", "ring"], ["circle", "ring"], [" ward", "ring"], ["around you", "aura"], ["pulses", "aura"], ["beats", "aura"], ["aura", "aura"],
	["quake", "crack"], ["fault", "crack"], ["tremor", "crack"], ["erode", "crack"], ["armour", "crack"], ["unravel", "crack"], ["fray", "crack"],
	["pool", "pool"], ["field", "pool"], ["floor", "pool"], ["patch", "pool"], ["sinkhole", "pool"], ["rubble", "pool"],
	["drag", "pull"], ["pull", "pull"], ["drain", "pull"], ["siphon", "pull"], ["recall", "pull"], ["drinks", "pull"], ["together", "pull"],
	["heal", "heart"], ["health", "heart"], ["mend", "heart"], ["stamina", "heart"], ["yourself", "heart"],
	["wave", "wave"], ["surge", "wave"], [" tide", "wave"], ["carries", "wave"], ["current", "wave"],
	["flame", "flame"], ["fire", "flame"], ["burn", "flame"], ["blaze", "flame"], ["heat", "flame"], ["kindle", "flame"],
	["freeze", "drop"], ["slow", "drop"], ["chill", "drop"], ["venom", "drop"], ["bleed", "drop"], ["poison", "drop"],
	[" see", "eye"], ["sight", "eye"], ["vanish", "eye"], ["unseen", "eye"],
	["aim at", "target"], [" mark", "target"], ["track", "target"], ["challenge", "target"],
	["burst", "burst"], ["blast", "burst"], ["explode", "burst"], ["throws foes", "burst"],
	["dash", "chevron"], ["trail", "chevron"], ["stride", "chevron"], ["faster", "chevron"],
	[" hop", "hop"], ["vault", "hop"],
	["charge", "spark"], ["stun", "spark"], ["harder", "spark"],
	["decoy", "mirror"], ["afterimage", "mirror"], ["behind", "mirror"],
	["again", "echo"], ["echo", "echo"], ["moment later", "clock"], ["later", "clock"],
	["parry", "blade"], [" cut", "blade"], ["stagger", "hex"], ["blow", "arc"], ["strike", "arc"], ["swing", "arc"], ["touch", "arc"],
]
## Numbers an entry has and the glyph they mean, the first found wins.
const NUMBERS := [
	["copies", "fan"], ["count", "fan"], ["leaps", "zig"], ["hop", "zig"], ["shield", "shield"], ["absorb", "shield"], ["lift", "up"],
	["patch", "pool"], ["delay", "clock"], ["speed", "arrow"], ["arc", "cone"], ["dist", "chevron"], ["length", "beam"], ["radius", "ring"],
	["reach", "long"], ["windup", "chevron"], ["duration", "clock"], ["damage", "arc"],
]


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


## The card's small drawing: a medallion in its colour with its emblem, or
## a glyph of what it does (a cone, a fan of bolts, a ring...) on a disc of
## its colour, the emblem of its bond or essence as a small seal at its
## edge; a lock for something not learned yet; an empty socket for an empty
## slot; a dotted ring for something not written yet (its glyph faint inside).
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
		elif glyph != "":
			disc_into(b, c, r, col)
		else:
			UI.medallion_into(b, c, r, col, affinity, clampf(fill, 0.0, 1.0), step, 0.35, faint)
		b.flush(self)
		if placeholder:
			if glyph != "":
				draw_glyph(self, glyph, c, r * 0.5, Color(col, 0.45))
			else:
				draw_string(UI.font("display"), c + Vector2(-4, 6), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, int(r), Color(col, 0.5))
		elif not locked and not empty and glyph != "":
			draw_glyph(self, glyph, c, r * 0.6, col.lightened(0.5))
			if affinity != "":
				# The bond's (or lead essence's) emblem as a small seal at its edge.
				var s := c + Vector2(r * 0.72, r * 0.72)
				var sb := UI.Draw.Batch.new()
				sb.dot(s, r * 0.36 + 1.4, UI.OUTLINE)
				sb.dot(s, r * 0.36, col.darkened(0.55))
				UI.emblem_into(sb, s, r * 0.27, affinity, col.lightened(0.15), 0.8)
				sb.flush(self)
			if fill < 0.999:
				# How full it is (a technique filling): a thin ring.
				draw_arc(c, r + 1.5, -PI * 0.5, -PI * 0.5 + TAU * clampf(fill, 0.0, 1.0), 28, Color(col.lightened(0.3), 0.9), 1.6, true)

	## A glyph's disc: rimmed in its colour, darker inside, lit from the top.
	static func disc_into(b, c: Vector2, r: float, col: Color) -> void:
		b.dot(c, r + 1.6, UI.OUTLINE)
		b.dot(c, r, col.darkened(0.62))
		b.dot(c + Vector2(-r * 0.12, -r * 0.14), r * 0.78, Color(col.darkened(0.45), 0.6))
		b.arc(c, r - 1.4, 0.0, TAU, 28, Color(col, 0.85), 1.6)
		b.arc(c, r - 1.4, PI * 1.05, PI * 1.6, 8, Color(col.lightened(0.5), 0.55), 1.2)

	## A glyph of what something does, `s` its half-size. Every glyph is a
	## few lines and dots, drawn in one colour.
	static func draw_glyph(ci: CanvasItem, g: String, c: Vector2, s: float, col: Color) -> void:
		var w := maxf(1.4, s * 0.16)
		var soft := Color(col, 0.55)
		match g:
			"arc":
				ci.draw_arc(c + Vector2(-s * 0.5, 0), s, -0.9, 0.9, 12, col, w * 1.4, true)
				ci.draw_arc(c + Vector2(-s * 0.9, 0), s, -0.7, 0.7, 10, soft, w, true)
			"cone":
				ci.draw_polyline(PackedVector2Array([c + Vector2(s, -s * 0.7), c + Vector2(-s, 0), c + Vector2(s, s * 0.7)]), col, w, true)
				ci.draw_arc(c + Vector2(-s, 0), s * 2.0, -0.6, 0.6, 10, col, w, true)
				ci.draw_arc(c + Vector2(-s, 0), s * 1.35, -0.55, 0.55, 8, soft, w * 0.8, true)
			"arrow":
				ci.draw_line(c + Vector2(-s, 0), c + Vector2(s, 0), col, w, true)
				ci.draw_polyline(PackedVector2Array([c + Vector2(s * 0.4, -s * 0.5), c + Vector2(s, 0), c + Vector2(s * 0.4, s * 0.5)]), col, w, true)
				ci.draw_line(c + Vector2(-s, -s * 0.3), c + Vector2(-s * 0.55, 0), soft, w * 0.8, true)
				ci.draw_line(c + Vector2(-s, s * 0.3), c + Vector2(-s * 0.55, 0), soft, w * 0.8, true)
			"long":
				ci.draw_line(c + Vector2(-s, 0), c + Vector2(s, 0), col, w, true)
				ci.draw_polyline(PackedVector2Array([c + Vector2(s * 0.55, -s * 0.4), c + Vector2(s, 0), c + Vector2(s * 0.55, s * 0.4)]), col, w, true)
				for k in [-0.6, -0.25]:
					ci.draw_line(c + Vector2(s * k, -s * 0.35), c + Vector2(s * k, s * 0.35), soft, w * 0.8, true)
			"pierce":
				ci.draw_line(c + Vector2(-s, s * 0.35), c + Vector2(s, -s * 0.35), col, w, true)
				ci.draw_polyline(PackedVector2Array([c + Vector2(s * 0.45, -s * 0.6), c + Vector2(s, -s * 0.35), c + Vector2(s * 0.62, s * 0.05)]), col, w, true)
				ci.draw_line(c + Vector2(-s * 0.1, -s * 0.7), c + Vector2(-s * 0.1, s * 0.7), soft, w * 1.3, true)
			"fan":
				for a in [-0.45, 0.0, 0.45]:
					var d := Vector2.from_angle(a)
					ci.draw_line(c - Vector2(s * 0.85, 0) + d * s * 0.15, c - Vector2(s * 0.85, 0) + d * s * 1.75, col, w, true)
					ci.draw_circle(c - Vector2(s * 0.85, 0) + d * s * 1.75, w * 1.1, col)
			"chevron":
				for k in [-0.5, 0.3]:
					ci.draw_polyline(PackedVector2Array([c + Vector2(k * s - s * 0.3, -s * 0.6), c + Vector2(k * s + s * 0.3, 0), c + Vector2(k * s - s * 0.3, s * 0.6)]), col if k > 0.0 else soft, w, true)
			"hop":
				ci.draw_arc(c + Vector2(0, s * 0.5), s, PI, TAU, 12, col, w, true)
				ci.draw_circle(c + Vector2(s, s * 0.5), w * 1.4, col)
				ci.draw_arc(c + Vector2(s, s * 0.6), s * 0.45, PI * 1.1, PI * 1.9, 6, soft, w * 0.8, true)
			"shield":
				var sh := PackedVector2Array([c + Vector2(-s * 0.8, -s * 0.75), c + Vector2(0, -s), c + Vector2(s * 0.8, -s * 0.75),
					c + Vector2(s * 0.7, s * 0.1), c + Vector2(0, s), c + Vector2(-s * 0.7, s * 0.1), c + Vector2(-s * 0.8, -s * 0.75)])
				ci.draw_polyline(sh, col, w, true)
				ci.draw_line(c + Vector2(0, -s * 0.7), c + Vector2(0, s * 0.65), soft, w * 0.8, true)
			"ring":
				for k in [0.4, 0.7, 1.0]:
					ci.draw_arc(c, s * k, 0.0, TAU, 20, Color(col, 1.1 - k * 0.6), w, true)
			"aura":
				ci.draw_circle(c, s * 0.28, col)
				for k in [0.62, 1.0]:
					for i in 4:
						var a0: float = i * TAU / 4.0 + 0.25 + float(k)
						ci.draw_arc(c, s * k, a0, a0 + 1.0, 6, Color(col, 1.2 - k * 0.7), w * 0.9, true)
			"burst":
				ci.draw_circle(c, s * 0.3, col)
				for a in 8:
					var d := Vector2.from_angle(a * TAU / 8.0 + 0.2)
					ci.draw_line(c + d * s * 0.5, c + d * s * (1.0 if a % 2 == 0 else 0.78), col if a % 2 == 0 else soft, w, true)
			"pull":
				ci.draw_line(c + Vector2(s, 0), c + Vector2(-s, 0), col, w, true)
				ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.4, -s * 0.5), c + Vector2(-s, 0), c + Vector2(-s * 0.4, s * 0.5)]), col, w, true)
				ci.draw_arc(c + Vector2(s * 0.7, 0), s * 0.35, -PI * 0.5, PI * 0.5, 6, soft, w * 0.8, true)
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
				ci.draw_arc(c + Vector2(0, s * 0.3), s, PI * 0.05, PI * 0.95, 12, Color(col, 0.7), w, true)
				ci.draw_arc(c + Vector2(0, s * 0.3), s, PI * 1.05, PI * 1.95, 12, Color(col, 0.4), w, true)
				ci.draw_circle(c + Vector2(0, s * 0.3), s * 0.4, Color(col, 0.5))
				ci.draw_line(c + Vector2(-s * 0.2, -s * 0.2), c + Vector2(-s * 0.2, -s * 0.75), soft, w * 0.8, true)
				ci.draw_line(c + Vector2(s * 0.25, -s * 0.1), c + Vector2(s * 0.25, -s * 0.55), soft, w * 0.8, true)
			"zig":
				ci.draw_polyline(PackedVector2Array([c + Vector2(-s, -s * 0.6), c + Vector2(-s * 0.1, -s * 0.05), c + Vector2(-s * 0.35, s * 0.15), c + Vector2(s, s * 0.6)]), col, w * 1.2, true)
				ci.draw_circle(c + Vector2(-s, -s * 0.6), w, col)
				ci.draw_circle(c + Vector2(s, s * 0.6), w * 1.2, col)
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
			"flame":
				var fl := PackedVector2Array([c + Vector2(0, s * 0.9), c + Vector2(-s * 0.55, s * 0.45), c + Vector2(-s * 0.55, -s * 0.05), c + Vector2(-s * 0.25, -s * 0.5),
					c + Vector2(s * 0.1, -s), c + Vector2(s * 0.2, -s * 0.45), c + Vector2(s * 0.5, -s * 0.2), c + Vector2(s * 0.58, s * 0.4), c + Vector2(0, s * 0.9)])
				ci.draw_polyline(fl, col, w, true)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0, s * 0.7), c + Vector2(-s * 0.25, s * 0.35), c + Vector2(0, -s * 0.15), c + Vector2(s * 0.25, s * 0.35)]), soft)
			"drop":
				var dr := PackedVector2Array([c + Vector2(0, -s)])
				for i in 11:
					var a := PI + PI * i / 10.0
					dr.append(c + Vector2(0, s * 0.3) + Vector2(-cos(a), -sin(a)) * s * 0.6)
				dr.append(c + Vector2(0, -s))
				ci.draw_polyline(dr, col, w, true)
				ci.draw_circle(c + Vector2(-s * 0.18, s * 0.25), w * 0.9, soft)
			"swirl":
				var sw := PackedVector2Array()
				for i in 18:
					var k := float(i) / 17.0
					sw.append(c + Vector2.from_angle(k * TAU * 1.3) * s * (0.15 + 0.85 * k))
				ci.draw_polyline(sw, col, w, true)
			"hex":
				var hx := PackedVector2Array()
				for i in 7:
					hx.append(c + Vector2.from_angle(-PI * 0.5 + TAU * i / 6.0) * s * 0.9)
				ci.draw_polyline(hx, col, w, true)
				ci.draw_line(c + Vector2(0, -s * 0.9), c, soft, w * 0.8, true)
				ci.draw_line(c, c + Vector2.from_angle(PI / 6.0) * s * 0.9, soft, w * 0.8, true)
				ci.draw_line(c, c + Vector2.from_angle(PI * 5.0 / 6.0) * s * 0.9, soft, w * 0.8, true)
			"blade":
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.9, s * 0.9), c + Vector2(s * 0.75, -s * 0.95), c + Vector2(s * 0.95, -s * 0.75), c + Vector2(-s * 0.6, s * 0.95)]), col)
				ci.draw_line(c + Vector2(-s * 0.55, s * 0.15), c + Vector2(-s * 0.05, s * 0.65), col, w * 1.3, true)
			"crack":
				ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.2, -s), c + Vector2(s * 0.15, -s * 0.35), c + Vector2(-s * 0.2, s * 0.1), c + Vector2(s * 0.2, s * 0.55), c + Vector2(0, s)]), col, w, true)
				ci.draw_line(c + Vector2(s * 0.15, -s * 0.35), c + Vector2(s * 0.75, -s * 0.5), soft, w * 0.8, true)
				ci.draw_line(c + Vector2(-s * 0.2, s * 0.1), c + Vector2(-s * 0.75, s * 0.3), soft, w * 0.8, true)
			"up", "down":
				var dir := Vector2(0, -1) if g == "up" else Vector2(0, 1)
				for k in [-0.45, 0.45]:
					var base := c + Vector2(s * k, 0) - dir * s * 0.85
					var tip := c + Vector2(s * k, 0) + dir * s * 0.85
					var cc := soft if k < 0.0 else col
					ci.draw_line(base, tip, cc, w, true)
					ci.draw_polyline(PackedVector2Array([tip - dir * s * 0.4 + Vector2(-s * 0.28, 0), tip, tip - dir * s * 0.4 + Vector2(s * 0.28, 0)]), cc, w, true)
			"wall":
				for i in 3:
					var y := c.y - s * 0.75 + s * 0.55 * i
					ci.draw_line(Vector2(c.x - s * 0.9, y), Vector2(c.x + s * 0.9, y), col if i == 0 else soft, w, true)
					var off := s * (0.35 if i % 2 == 0 else -0.1)
					ci.draw_line(Vector2(c.x + off, y), Vector2(c.x + off, y + s * 0.55), soft, w * 0.8, true)
			"beam":
				ci.draw_line(c + Vector2(-s, 0), c + Vector2(s, 0), col, w * 2.2, true)
				ci.draw_line(c + Vector2(-s, -s * 0.35), c + Vector2(s, -s * 0.35), soft, w * 0.7, true)
				ci.draw_line(c + Vector2(-s, s * 0.35), c + Vector2(s, s * 0.35), soft, w * 0.7, true)
			"rune":
				ci.draw_arc(c, s, 0.0, TAU, 20, col, w, true)
				var tri := PackedVector2Array()
				for i in 4:
					tri.append(c + Vector2.from_angle(-PI * 0.5 + TAU * i / 3.0) * s * 0.7)
				ci.draw_polyline(tri, soft, w * 0.9, true)
				ci.draw_circle(c, w * 1.1, col)
			"cloud":
				for p in [[-0.45, 0.15, 0.4], [0.05, -0.15, 0.5], [0.5, 0.15, 0.38]]:
					ci.draw_arc(c + Vector2(p[0], p[1]) * s, s * p[2], PI * 0.9, PI * 2.1, 10, col, w, true)
				ci.draw_line(c + Vector2(-s * 0.85, s * 0.5), c + Vector2(s * 0.88, s * 0.5), col, w, true)
			"rain":
				for k in 4:
					var x := c.x - s * 0.75 + s * 0.5 * k
					ci.draw_line(Vector2(x + s * 0.2, c.y - s * 0.8), Vector2(x - s * 0.1, c.y + s * 0.6), col if k % 2 == 0 else soft, w, true)
				ci.draw_line(c + Vector2(-s, s * 0.9), c + Vector2(s, s * 0.9), soft, w * 0.8, true)
			"wave":
				for row in 2:
					var pts := PackedVector2Array()
					for i in 13:
						var k := float(i) / 12.0
						pts.append(c + Vector2((k - 0.5) * s * 2.0, (row - 0.5) * s * 0.8 + sin(k * TAU * 1.5) * s * 0.22))
					ci.draw_polyline(pts, col if row == 0 else soft, w, true)
			"rod":
				ci.draw_line(c + Vector2(0, -s), c + Vector2(0, s), col, w * 1.3, true)
				ci.draw_circle(c + Vector2(0, -s), w * 1.4, col)
				ci.draw_polyline(PackedVector2Array([c + Vector2(-s, -s * 0.2), c + Vector2(-s * 0.4, s * 0.1), c + Vector2(-s * 0.6, s * 0.25), c + Vector2(-s * 0.05, s * 0.5)]), soft, w, true)
			"storm":
				ci.draw_arc(c + Vector2(-s * 0.3, -s * 0.2), s * 0.45, PI * 0.9, PI * 2.0, 8, col, w, true)
				ci.draw_arc(c + Vector2(s * 0.3, -s * 0.25), s * 0.5, PI * 1.0, PI * 2.1, 8, col, w, true)
				ci.draw_line(c + Vector2(-s * 0.8, s * 0.1), c + Vector2(s * 0.85, s * 0.1), col, w, true)
				ci.draw_polyline(PackedVector2Array([c + Vector2(s * 0.1, s * 0.15), c + Vector2(-s * 0.15, s * 0.55), c + Vector2(s * 0.1, s * 0.55), c + Vector2(-s * 0.1, s)]), col, w, true)
			"kinds":
				for i in 3:
					var p := c + Vector2.from_angle(-PI * 0.5 + TAU * i / 3.0) * s * 0.62
					ci.draw_circle(p, s * 0.26, col if i == 0 else soft)
					ci.draw_line(p, c, soft, w * 0.8, true)
			"gift":
				var dm := PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.8, 0), c + Vector2(0, s), c + Vector2(-s * 0.8, 0), c + Vector2(0, -s)])
				ci.draw_polyline(dm, col, w, true)
				ci.draw_circle(c, s * 0.25, col)
			"crown":
				ci.draw_polyline(PackedVector2Array([c + Vector2(-s * 0.85, s * 0.55), c + Vector2(-s * 0.85, -s * 0.35), c + Vector2(-s * 0.4, s * 0.05),
					c + Vector2(0, -s * 0.7), c + Vector2(s * 0.4, s * 0.05), c + Vector2(s * 0.85, -s * 0.35), c + Vector2(s * 0.85, s * 0.55), c + Vector2(-s * 0.85, s * 0.55)]), col, w, true)
			_:
				ci.draw_circle(c, s * 0.35, soft)
