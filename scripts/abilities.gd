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
const Library := preload("res://scripts/library.gd")
const TreeRules := preload("res://scripts/tree.gd")
## Every entry is a grimoire card (grimoire_card.gd: the same card the
## book's Tree and the essence bench show).
const GrimoireCard := preload("res://scripts/grimoire_card.gd")
const KeyBadge := GrimoireCard.KeyBadge
## The Tree (tree_view.gd): every entry links to its node there, "On the body map".
const TreeView := preload("res://scripts/tree_view.gd")

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
		# The tree's choices (tree.gd): a fork's chosen side, or today's until it's chosen.
		var choices := TreeRules.mark_choices(prof, String(info["id"]))
		var known: Array = TreeRules.bond_spells(String(info["id"]), step, choices)
		var shown: Array = TreeRules.bond_spells(String(info["id"]), TreeRules.MAX_STEP, choices)
		var alt3 := TreeRules.alt_change(String(info["id"]), choices) if step >= 3 else {}
		var bd = main.player.bonds.get(part) if main.player != null else null
		var sel_id: String = String(bd.spell()["id"]) if bd != null and bd.has_method("spell") and not known.is_empty() else (String(known[0]["id"]) if not known.is_empty() else "")
		out.append({"kind": "mark", "part": part, "id": info["id"], "name": data["name"], "color": data["color"], "affinity": data["affinity"],
			"sub": TEXT["mark_sub"] % [Bonds.PART_NAMES[part], Essence.display(data["affinity"]), TEXT["mark_faint"] if faint else TEXT["mark_step"] % step],
			"does": TEXT["mark_more"] % [data["body"]["name"], data["body"]["desc"], Bonds.passive_at(String(info["id"]), step)["name"], Bonds.passive_at(String(info["id"]), step)["desc"]],
			"press": press(main, part) if mode(main) != 2 else _sel_name({"spells": shown, "name": data["name"]}, sel_id), "cost": TEXT["ring_note"] if known.size() > 1 else "", "locked": false, "learn": 1,
			"selected": false, "step": step, "faint": faint, "more": []})
		var i := 0
		for sp in shown:
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
			var does := _sentence(sp["desc"])
			if not alt3.is_empty() and sp.get("changes", {}).has(3):
				does += " %s: %s" % [alt3.get("name", ""), _sentence(String(alt3.get("desc", "")))]  # (the step-3 variation chosen)
			out.append({"kind": "spell", "part": part, "id": sp["id"], "name": sp["name"], "color": data["color"], "affinity": data["affinity"],
				"type": String(sp.get("type", "")), "sub": data["name"], "does": does, "press": "" if locked else press(main, part, not selected and known.size() > 1),
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
		"tag": TEXT["tech_sub"] % [Unbound.PART_NAMES[part], sh["name"], ", ".join(kinds)], "tag_color": UI.DIM,
		"echo": _echo_text(t)}


## "echoes Gale Lift" when a technique comes close to a bond's spell (library.gd ECHOES).
static func _echo_text(t: Dictionary) -> String:
	var e := Library.echo_of(t)
	return Library.TEXT["echoes"] % e["name"] if not e.is_empty() else ""


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
	# An entry reached from the Tree ("In your abilities"): picked out, scrolled to.
	var focus := String(menu.get_meta("abilities_focus", ""))
	if focus != "":
		menu.remove_meta("abilities_focus")
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
		var card := GrimoireCard.new()
		card.small = small
		card.entry = e
		card.words = {"more": TEXT["more"], "less": TEXT["less"]}
		card.opened = open.has(e["id"])
		card.selected = focus != "" and String(e["id"]) == focus
		card.toggled_more.connect(func(id, on):
			var o: Dictionary = menu.get_meta("abilities_open", {})
			if on:
				o[id] = true
			else:
				o.erase(id)
			menu.set_meta("abilities_open", o))
		# Beside it, "On the body map": the book's Tree with it picked out.
		var at: Array = TreeView.node_of(main, e)
		if at.is_empty():
			group.add_child(card)
		else:
			var line := HBoxContainer.new()
			line.add_theme_constant_override("separation", 6)
			line.mouse_filter = Control.MOUSE_FILTER_IGNORE
			group.add_child(line)
			line.add_child(card)
			line.add_child(_map_link(menu, at, small))
		if card.selected:
			_scroll_to(menu, card)
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
		sb.set_meta("help", "steps")  # (the Entity's explanation of it: entity_help.gd)
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


## "On the body map": a small link beside an entry that turns the book to
## the Tree, its node picked out (tree_view.gd open_tree). `at`: [part, bud key].
static func _map_link(menu, at: Array, small: bool) -> Button:
	var b := TreeView.MapLink.new()
	b.menu = menu
	b.small = small
	b.text = TreeView.TEXT["on_map"]
	b.tooltip_text = TreeView.TEXT["on_map"]
	b.set_meta("map_link", "%s|%s" % at if String(at[1]) != "" else String(at[0]))
	b.pressed.connect(TreeView.open_tree.bind(menu, String(at[0]), String(at[1])))
	return b


## The page scrolls to a card once it's laid out (reached from the Tree).
static func _scroll_to(menu, card: Control) -> void:
	menu.get_tree().create_timer(0.05, true).timeout.connect(func():
		if is_instance_valid(card) and card.is_inside_tree() and menu.scroll != null:
			menu.scroll.ensure_control_visible(card))


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
	var at: Array = TreeView.node_of(menu.main, e)
	if not at.is_empty():
		h.add_child(_map_link(menu, at, small))
	if not small:
		var d := Label.new()
		d.text = e["does"]
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size.x = 200.0
		UI.style_label(d, "body", 13, UI.DIM)
		v.add_child(d)


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

