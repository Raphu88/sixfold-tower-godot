extends RefCounted
## The Abilities page: what you can cast right now, and how. It's the
## climber screen's first tab (menu.gd: menu.open("abilities") opens it
## from anywhere, the train included; holding Tab or the Climber button
## peeks at it during a climb and letting go returns to the game).
##
## Marked climbers: each mark's bond (its body part, essence and step, the
## button that casts it), then every spell it has or will have: learned
## ones with the button to press, their cost and what they do; ones not
## learned yet dimmed, "learned at step N".
## The Unbound: their six techniques, one per mark button: the part, the
## essences, the shape, what it does in plain words, how it fills, its
## strain and boost.
## Each entry is a card: press it (Enter, A, a click or a tap) for "more",
## the full numbers. On the train the page also offers "Try your
## abilities" (practice.gd) and, for the Unbound, "Change techniques".
##
## Also here, in plain data with the rest of their words: the short names
## on the phone's cast buttons (short_lines), the first-cast toasts' lines
## (toast_line) and the long-press card (card_lines), which hud, touch and
## ability_hints.gd draw.

const Bonds := preload("res://scripts/bonds.gd")
const ProfileScript := preload("res://scripts/profile.gd")
const Unbound := preload("res://scripts/unbound.gd")
const Tech := preload("res://scripts/technique.gd")
const Essence := preload("res://scripts/essence.gd")
const Controls := preload("res://scripts/controls.gd")
const Entity := preload("res://scripts/entity.gd")
const UI := preload("res://scripts/ui.gd")

## Every word on the page and in the hints. {climber}, {cast} and the like
## become the keys, controller buttons or touch words in use (entity.gd KEYS).
const TEXT := {
	"tab": "Abilities",
	"title": "Abilities",
	"intro_marks": "Each mark's button casts its chosen spell. Hold the button to pick another spell from its ring.",
	"intro_unbound": "Six techniques, one on each mark button. Each fills as its part does its work; a full one casts for nothing. Cast one early and it strains that part.",
	"intro_none": "No marks yet. Your first climb is bondless: at its top the tower's beast takes notice, and the body part you used most takes your first mark.",
	"peek": "During a climb, {abilities} to look at this page; let go to return.",
	"mark_sub": "%s mark  ·  %s essence  ·  %s",
	"mark_step": "step %d of 5",
	"mark_faint": "faint",
	"mark_more": "Body: %s, %s.   Passive: %s, %s.",
	"tech_sub": "%s  ·  %s  ·  %s",
	"empty": "Empty slot",
	"empty_does": "Nothing on this button yet. Build a technique on the train: Your car, then Techniques.",
	"empty_sub": "%s button",
	# The button to press: [keys, controller, touch].
	"press": ["%s", "%s + %s", "tap"],
	"hold": ["hold %s", "hold %s + %s", "hold, slide"],
	"press_caption": "to cast",
	"hold_caption": "to pick it",
	"ring_note": "hold for the ring",
	"selected": "on the button",
	"learned": "learned  ·  step %d",
	"locked": "learned at step %d",
	"cost": "%d essence",
	"fill": "full at %d",
	"strain": "+%d strain",
	"more": "+ more",
	"less": "- less",
	# The "more" lines.
	"more_stats": "[color=#%s]Numbers[/color]  %s",
	"more_fill": "[color=#%s]Fills[/color]  The %s %s. It holds %d essence at step %d.",
	"more_tech_fill": "[color=#%s]Fills[/color]  %s (your %s). Full at %d, a cast spends nothing; it's %d of %d now.",
	"more_strain": "[color=#%s]Strain[/color]  +%d to your %s each cast, up to +%d more if it isn't full. Past 70 that part hits harder but may waver; at 100 it erupts.",
	"more_boost": "[color=#%s]Boost[/color]  Carry %s unbanked and a cast spends it for +%d%% power (%s).",
	"boost_on": "on",
	"boost_off": "switched off",
	"more_kinds": "[color=#%s]Essences[/color]  %s",
	"kind_lead": "%s leads: %s",
	"kind_part": "%s at %s: %s",
	"share": ["full strength", "half strength", "a third"],
	"more_power": "[color=#%s]Strength[/color]  Your %s is level %d: x%s power.",
	"more_shape": "[color=#%s]Shape[/color]  %s",
	# Buttons under the list.
	"try": "Try your abilities",
	"try_note": "On the train, Try your abilities opens a safe practice room.",
	"change": "Change techniques",
	"steps": "Every mark's steps",
	"all": "All your abilities",
	# The phone's long-press card and the HUD's hover and ready labels.
	"card_hint": "All of them: {abilities}",
	"tip_all": "All your abilities: {abilities}",
	"card_fill": "Fill %d / %d  ·  +%d strain",
	"card_cost": "Costs %d  ·  holds %d / %d",
	"ready": "%s ready",
}
## Names of the shape numbers in "more" (technique.gd SHAPES).
const SHAPE_WORDS := {"damage": "damage %s", "reach": "reach %s", "arc": "arc %s°", "speed": "speed %s", "range": "range %s",
	"dist": "distance %s", "radius": "radius %s", "shield": "shield %s", "duration": "lasts %s s", "force": "throw %s",
	"length": "length %s", "width": "width %s", "near": "around you %s"}
## The order the Unbound's cards show in: the mark buttons' order (Q E F C X V).
const ORDER := ["hand", "legs", "heart", "brow", "throat", "back"]


# --- the words for the input in use ------------------------------------------------

## The column of a [keys, controller, touch] list for the input in use.
static func mode(main) -> int:
	if main == null:
		return 0
	if main.touch_active:
		return 2
	return 1 if main.pad_active else 0


## Fills {climber}, {cast}... for the input in use (entity.gd KEYS).
static func fill(main, text: String) -> String:
	var m: String = ["keys", "pad", "touch"][mode(main)]
	return Entity.fill_keys(text, m, main.pad_ps if main != null else false)


## The button that casts a part's mark (or technique), in words: "Q",
## "LB + X", "tap"; `hold` for the spell ring ("hold Q").
static func press(main, part: String, hold := false) -> String:
	var m := mode(main)
	var list: Array = TEXT["hold" if hold else "press"]
	match m:
		1:
			var ps: bool = main.pad_ps
			return list[1] % [Controls.pad_name("lb", ps, true), Controls.pad_name(Controls.PART_PAD[part], ps, true)]
		2:
			return list[2]
	return list[0] % Bonds.PART_KEYS[part]


# --- the entries -----------------------------------------------------------------------

## What the climber can cast, in order: for a marked climber each mark
## ("mark") followed by its spells ("spell"); for the Unbound a technique
## ("technique", or "empty") per mark button. Each is a dictionary: kind,
## part (the button), id, name, color, affinity, sub, does, press, cost,
## locked, learn, selected, step, more (lines; needs `menu` for a spell's numbers).
static func entries(main, menu = null) -> Array:
	var prof = main.profile
	var out: Array = []
	if prof == null:
		return out
	if Unbound.is_on(prof):
		var techs: Array = Unbound.state(prof)["techs"]
		for i in Unbound.PARTS.size():
			var button: String = Unbound.PARTS[i]
			var t = techs[i] if i < techs.size() else {}
			if Tech.valid(t):
				out.append(_technique(main, button, i, t))
			else:
				out.append({"kind": "empty", "part": button, "id": "tech_%d" % i, "name": TEXT["empty"], "color": UI.FAINT, "affinity": "",
					"sub": TEXT["empty_sub"] % Bonds.PART_NAMES[button], "does": TEXT["empty_does"], "press": press(main, button), "cost": "",
					"locked": true, "learn": 0, "selected": false, "step": 0, "more": [], "tag": "", "tag_color": UI.DIM})
		return out
	for part in Bonds.PARTS:
		if not prof.bonds.has(part):
			continue
		var info: Dictionary = prof.bonds[part]
		var data: Dictionary = Bonds.BONDS[info["id"]]
		var step := ProfileScript.step_for_xp(float(info["xp"]))
		var faint: bool = info.get("faint", false)
		var known: Array = data["spells"].filter(func(sp): return int(sp["learn"]) <= step)
		var bd = main.player.bonds.get(part) if main.player != null else null
		var sel_id: String = String(bd.spell()["id"]) if bd != null and bd.has_method("spell") and not known.is_empty() else (String(known[0]["id"]) if not known.is_empty() else "")
		out.append({"kind": "mark", "part": part, "id": info["id"], "name": data["name"], "color": data["color"], "affinity": data["affinity"],
			"sub": TEXT["mark_sub"] % [Bonds.PART_NAMES[part], Essence.display(data["affinity"]), TEXT["mark_faint"] if faint else TEXT["mark_step"] % step],
			"does": TEXT["mark_more"] % [data["body"]["name"], data["body"]["desc"], data["passive"]["name"], data["passive"]["desc"]],
			"press": press(main, part) if mode(main) != 2 else _sel_name(data, sel_id), "cost": TEXT["ring_note"] if known.size() > 1 else "", "locked": false, "learn": 1,
			"selected": false, "step": step, "faint": faint, "more": []})
		var i := 0
		for sp in data["spells"]:
			i += 1
			var learn := int(sp["learn"])
			var locked := learn > step
			var at := step if not locked else learn
			var vals := _values(sp, at)
			var cost := float(vals.get("cost", 0.0)) * (1.25 if faint else 1.0)
			var selected: bool = not locked and String(sp["id"]) == sel_id
			var more: Array = []
			if menu != null:
				var g := UI.GOLD.to_html(false)
				var stats: String = menu._spell_stats(sp, at)
				if stats != "":
					more.append(TEXT["more_stats"] % [g, ("At step %d: " % learn if locked else "") + stats])
				var changes: String = menu._spell_changes(sp, step)
				if changes != "":
					more.append(changes)
				more.append(TEXT["more_fill"] % [g, Bonds.PART_NAMES[part].to_lower(), Bonds.PART_FILLS[part], int(30 + 10 * step), step])
			out.append({"kind": "spell", "part": part, "id": sp["id"], "name": sp["name"], "color": data["color"], "affinity": data["affinity"],
				"sub": data["name"], "does": _sentence(sp["desc"]), "press": "" if locked else press(main, part, not selected and known.size() > 1),
				"cost": TEXT["cost"] % int(round(cost)) if cost > 0.0 else "", "locked": locked, "learn": learn, "selected": selected,
				"step": step, "index": i, "more": more,
				"tag": TEXT["locked"] % learn if locked else (TEXT["selected"] if selected and known.size() > 1 else ""), "tag_color": UI.FAINT if locked else UI.GOOD})
	return out


## A phone's cast button shows its chosen spell's name: that's "its button".
static func _sel_name(data: Dictionary, id: String) -> String:
	for sp in data["spells"]:
		if String(sp["id"]) == id:
			return String(sp["name"])
	return String(data["name"])


static func _technique(main, button: String, i: int, t: Dictionary) -> Dictionary:
	var prof = main.profile
	var part := String(t["part"])
	var lead := Tech.lead(t)
	var kinds: Array = t["kinds"].map(func(k): return Tech.display(String(k)))
	var charge := Tech.charge(t, prof)
	var bd = main.player.bonds.get(button) if main.player != null else null
	var have: float = float(bd.essence) if bd != null and "tech" in bd else 0.0
	var g := UI.GOLD.to_html(false)
	var more: Array = []
	more.append(TEXT["more_tech_fill"] % [g, _sentence(String(Bonds.PART_FILLS[part]).trim_prefix("fills ")).trim_suffix("."), Bonds.PART_NAMES[part].to_lower(), int(round(charge)), int(have), int(round(charge))])
	more.append(TEXT["more_strain"] % [g, int(Tech.strain(t)), Bonds.PART_NAMES[part].to_lower(), int(Tech.EMPTY_STRAIN)])
	var on: bool = bool(Unbound.state(prof).get("boost", true))
	more.append(TEXT["more_boost"] % [g, Tech.cost_text(t, prof), int(Tech.BOOST * 100.0), TEXT["boost_on"] if on else TEXT["boost_off"]])
	var bits: Array = []
	for n in t["kinds"].size():
		var k := String(t["kinds"][n])
		var phrase := _kind_phrase(t, k)
		bits.append(TEXT["kind_lead"] % [Tech.display(k), phrase] if n == 0 else TEXT["kind_part"] % [Tech.display(k), TEXT["share"][mini(n, 2)], phrase])
	more.append(TEXT["more_kinds"] % [g, ";  ".join(bits)])
	var power: float = Unbound.power(prof, part)
	var sh: Dictionary = Tech.SHAPES[t["shape"]]
	var nums: Array = ["wind-up %s s" % _num(Tech.windup(t))]
	for k in SHAPE_WORDS:
		if sh.has(k):
			var v: float = float(sh[k]) * (power if k in ["damage", "shield"] else 1.0)
			nums.append(SHAPE_WORDS[k] % _num(v))
	more.append(TEXT["more_shape"] % [g, "  ·  ".join(nums)])
	more.append(TEXT["more_power"] % [g, Bonds.PART_NAMES[part].to_lower(), Unbound.level(prof, part), _num(power)])
	return {"kind": "technique", "part": button, "id": "tech_%d" % i, "name": Tech.title(t), "color": Tech.color(lead),
		"affinity": lead if lead in Unbound.NATURAL else "", "sub": TEXT["tech_sub"] % [Unbound.PART_NAMES[part], sh["name"], ", ".join(kinds)],
		"does": Tech.describe(t), "press": press(main, button), "cost": "%s  ·  %s" % [TEXT["fill"] % int(round(charge)), TEXT["strain"] % int(Tech.strain(t))],
		"locked": false, "learn": 1, "selected": true, "step": Unbound.level(prof, part), "fill": have / maxf(charge, 0.01), "more": more, "tech": t,
		"tag": TEXT["tech_sub"] % [Unbound.PART_NAMES[part], sh["name"], ", ".join(kinds)], "tag_color": UI.DIM}


## What one essence does in a technique, in a few words (technique.gd KINDS).
static func _kind_phrase(t: Dictionary, k: String) -> String:
	var cls: String = Tech.SHAPES[t["shape"]]["class"]
	var key := "hit"
	match cls:
		"self":
			key = "self"
		"shell":
			key = "shell"
		"sight":
			key = "near"
	if cls == "move" and k == "air":
		return String(Tech.KINDS[k]["move"])
	return String(Tech.KINDS[k][key])


## A spell's numbers at a step (the latest step at or below it that sets each wins).
static func _values(sp: Dictionary, at: int) -> Dictionary:
	var vals := {}
	var steps: Dictionary = sp["steps"]
	for s in range(1, at + 1):
		if steps.has(s):
			for k in steps[s]:
				vals[k] = steps[s][k]
	return vals


static func _num(f: float) -> String:
	if absf(f - roundf(f)) < 0.01:
		return "%d" % int(roundf(f))
	return ("%.2f" % f).rstrip("0").rstrip(".")


static func _sentence(t: String) -> String:
	if t == "":
		return t
	return t.left(1).to_upper() + t.substr(1) + ("" if t.ends_with(".") else ".")


# --- the short words in play -------------------------------------------------------

## A bond's (or technique's) one line for a toast or a card: "Ember Bolt: a
## bolt thrown where you aim; it burns what it hits".
static func toast_line(bd) -> String:
	return "%s: %s" % [spell_name(bd), short_does(bd)]


## The spell its button casts now (a technique: its name).
static func spell_name(bd) -> String:
	if "tech" in bd:
		return Tech.title(bd.tech)
	return String(bd.spell_name())


## What it does, in a few words.
static func short_does(bd) -> String:
	if "tech" in bd:
		var t: Dictionary = bd.tech
		var says: String = Tech.SHAPES[t["shape"]]["says"]
		return "%s; it %s" % [says.left(1).to_lower() + says.substr(1), _kind_phrase(t, Tech.lead(t))]
	return String(bd.spell_desc())


## The once-per-climber key of what a bond casts (a technique by what it's made of).
static func cast_key(bd) -> String:
	if "tech" in bd:
		var t: Dictionary = bd.tech
		return "tech:%s:%s:%s" % [t["part"], t["shape"], ",".join(t["kinds"])]
	return "spell:%s" % String(bd.spell()["id"])


## The lines of the phone's long-press card: [title, what it does, the numbers].
static func card_lines(main, bd) -> Array:
	var numbers := ""
	if "tech" in bd:
		numbers = TEXT["card_fill"] % [int(bd.essence), int(round(bd.capacity())), int(Tech.strain(bd.tech))]
	else:
		numbers = TEXT["card_cost"] % [int(round(bd.cost())), int(bd.essence), int(bd.capacity())]
	return [spell_name(bd), _sentence(short_does(bd)), numbers, fill(main, TEXT["card_hint"])]


## A name split for a small round button: one line if it fits `width`,
## else two (balanced at a space), never more. Returns the lines.
static func short_lines(text: String, font: Font, size: int, width: float) -> Array:
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width or not text.contains(" "):
		return [text]
	var words := text.split(" ")
	var best := [text]
	var best_w := INF
	for cut in range(1, words.size()):
		var a := " ".join(words.slice(0, cut))
		var b := " ".join(words.slice(cut))
		var w := maxf(font.get_string_size(a, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x, font.get_string_size(b, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x)
		if w < best_w:
			best_w = w
			best = [a, b]
	return best


# --- the page --------------------------------------------------------------------------

## The Abilities tab (menu.gd's climber screen calls this after its header and tabs).
static func build(menu) -> void:
	var main = menu.main
	var prof = main.profile
	var small: bool = menu.compact()
	var list := entries(main, menu)
	var open: Dictionary = menu.get_meta("abilities_open", {})
	var intro := TEXT["intro_none"]
	if Unbound.is_on(prof):
		intro = TEXT["intro_unbound"]
	elif not prof.bonds.is_empty():
		intro = TEXT["intro_marks"]
	if not (small and not list.is_empty()):
		menu._note(fill(main, intro))
	var group: Node = menu.box  # (a mark's spells sit a little in under it)
	for e in list:
		if e["kind"] == "mark":
			_mark_head(menu, e, small)
			var indent := MarginContainer.new()
			indent.add_theme_constant_override("margin_left", 14 if small else 22)
			indent.mouse_filter = Control.MOUSE_FILTER_IGNORE
			menu.box.add_child(indent)
			group = VBoxContainer.new()
			group.add_theme_constant_override("separation", 6)
			group.mouse_filter = Control.MOUSE_FILTER_IGNORE
			indent.add_child(group)
			continue
		var card := AbilityCard.new()
		card.small = small
		card.entry = e
		card.words = {"more": TEXT["more"], "less": TEXT["less"]}
		card.opened = open.has(e["id"])
		card.toggled_more.connect(func(id, on):
			var o: Dictionary = menu.get_meta("abilities_open", {})
			if on:
				o[id] = true
			else:
				o.erase(id)
			menu.set_meta("abilities_open", o))
		group.add_child(card)
	# What next: practice (on the train), the techniques page, every step.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var can_try: bool = main.on_train and not list.is_empty() and main.practice != null
	if can_try:
		var tb: Button = menu._button(TEXT["try"], func(): main.practice.start(), row)
		tb.set_meta("try_abilities", true)
		menu._primary(tb)
		tb.custom_minimum_size.x = 200.0
	if Unbound.is_on(prof) and main.on_train:
		var cb: Button = menu._button(TEXT["change"], menu.open.bind("techniques", true), row)
		cb.set_meta("change_techniques", true)
		cb.custom_minimum_size.x = 180.0
	elif not prof.bonds.is_empty() and not Unbound.is_on(prof):
		var sb: Button = menu._button(TEXT["steps"], menu._set_climber_tab.bind("marks"), row)
		sb.custom_minimum_size.x = 180.0
	if row.get_child_count() > 0:
		menu._gap(2)
		menu.box.add_child(row)
	else:
		row.queue_free()
	if not small:
		var notes: Array = []
		if not main.on_train and not list.is_empty():
			notes.append(TEXT["try_note"])
		if mode(main) != 1:
			notes.append(fill(main, TEXT["peek"]))
		if not notes.is_empty():
			menu._note("  ".join(notes))


## A mark's header: its medallion, name, part, essence and step, the button
## that casts it, and (on a computer) its body and passive in a line.
static func _mark_head(menu, e: Dictionary, small: bool) -> void:
	var pc := PanelContainer.new()
	var st := UI.card(Color(e["color"], 0.55), true, 8.0)
	st.top = Color(0.1, 0.088, 0.13, 0.9)
	st.bottom = Color(0.075, 0.066, 0.1, 0.9)
	pc.add_theme_stylebox_override("panel", st)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.set_meta("ability_mark", e["part"])
	menu.box.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	pc.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	v.add_child(h)
	var icon := AbilityIcon.new()
	icon.col = e["color"]
	icon.affinity = e["affinity"]
	icon.step = int(e["step"])
	icon.faint = bool(e.get("faint", false))
	icon.custom_minimum_size = Vector2(34, 34) if small else Vector2(40, 40)
	h.add_child(icon)
	var names := VBoxContainer.new()
	names.add_theme_constant_override("separation", -4)
	names.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	names.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(names)
	var n := Label.new()
	n.text = e["name"]
	UI.style_label(n, "display", 20 if small else 23, Color(e["color"]).lightened(0.15))
	names.add_child(n)
	var s := Label.new()
	s.text = e["sub"]
	UI.style_label(s, "body", 13, UI.DIM)
	names.add_child(s)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 0)
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(side)
	var kb := KeyBadge.new()
	kb.key = e["press"]
	kb.col = Color(e["color"]).lightened(0.25)
	kb.size_flags_horizontal = Control.SIZE_SHRINK_END
	side.add_child(kb)
	if e["cost"] != "":
		var rn := Label.new()
		rn.text = e["cost"]
		UI.style_label(rn, "body", 12, UI.FAINT)
		rn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		side.add_child(rn)
	if not small:
		var d := Label.new()
		d.text = e["does"]
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 200.0
		UI.style_label(d, "body", 13, UI.DIM)
		v.add_child(d)


## One ability: its medallion (a lock if not learned yet), name and tag,
## the line under the name, what it does, the button to press and its cost
## or fill. Press it for more: the full numbers. A Button, so the keys, the
## controller, a click and a tap all reach it (menu.gd's touch taps press it).
class AbilityCard extends Button:
	const UI := preload("res://scripts/ui.gd")
	signal toggled_more(id: String, on: bool)
	var entry := {}
	var words := {}  # "more" and "less" (abilities.gd TEXT)
	var small := false
	var opened := false
	var body: VBoxContainer
	var more_box: VBoxContainer
	var more_label: Label
	const PAD := Vector2(12, 8)

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		set_meta("ability", entry.get("id", ""))
		set_meta("ability_part", entry.get("part", ""))
		set_meta("locked", entry.get("locked", false))
		var col: Color = entry.get("color", UI.FAINT)
		var locked: bool = entry.get("locked", false)
		var normal := UI.card(Color(col, 0.75) if not locked else Color(0, 0, 0, 0), not locked, 10.0)
		if locked:
			normal.top = Color(0.085, 0.076, 0.11, 0.9)
			normal.bottom = Color(0.07, 0.062, 0.09, 0.9)
		var hover := UI.card(UI.GOLD, not locked, 10.0)
		hover.top = Color(0.16, 0.14, 0.2, 0.98)
		if not locked:
			hover.strip = col
		add_theme_stylebox_override("normal", normal)
		add_theme_stylebox_override("hover", hover)
		add_theme_stylebox_override("pressed", hover)
		add_theme_stylebox_override("focus", UI.focus_box())
		pressed.connect(_toggle)
		_build()

	func _build() -> void:
		var col: Color = entry.get("color", UI.FAINT)
		var locked: bool = entry.get("locked", false)
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
		var icon := AbilityIcon.new()
		icon.col = col
		icon.affinity = entry.get("affinity", "")
		icon.locked = locked
		icon.fill = float(entry.get("fill", 1.0))
		icon.empty = entry.get("kind", "") == "empty"
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
		var n := _l(entry.get("name", ""), "display", 18 if small else 20, col.lightened(0.2) if not locked else UI.DIM)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.clip_text = true
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		top.add_child(n)
		var tag: String = entry.get("tag", "")
		if tag != "":
			var tl := _l(tag, "body", 12 if small else 13, entry.get("tag_color", UI.FAINT))
			tl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			top.add_child(tl)
		var d := _l(entry.get("does", ""), "body", 14 if small else 15, UI.TEXT if not locked else UI.DIM)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 120.0
		mid.add_child(d)
		# The button and the cost, at the right.
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
			var cl := _l(entry["cost"], "mono", 12, UI.GOLD if not locked else UI.FAINT)
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
		var has: bool = not entry.get("more", []).is_empty()
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


## An ability's medallion: in its bond's (or lead essence's) colour with its
## emblem; a lock for a spell not learned yet; an empty socket for an empty slot.
class AbilityIcon extends Control:
	const UI := preload("res://scripts/ui.gd")
	var col := Color.WHITE
	var affinity := ""
	var locked := false
	var empty := false
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
		elif locked:
			b.dot(c, r + 1.6, UI.OUTLINE)
			b.dot(c, r, Color(0.1, 0.095, 0.13))
			b.arc(c, r - 2.0, 0.0, TAU, 28, Color(col, 0.25), 2.0)
			UI.lock_into(b, c, r * 0.62, Color(UI.FAINT, 0.95))
		else:
			UI.medallion_into(b, c, r, col, affinity, clampf(fill, 0.0, 1.0), step, 0.35, faint)
		b.flush(self)

