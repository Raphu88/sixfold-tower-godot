extends RefCounted
## THE TECHNIQUES TAB: the Unbound's techniques, on the climber screen (a
## tab of its own, shown only while the climber is Unbound: menu.gd
## climber_tabs). Everything about a technique is here, in one place, built
## with menu.gd's helpers (so the mouse, the keys, a controller and a tap
## all work, and every button has the Entity's hover/hold help):
##
##   SLOTS      six buttons along the top, one per body part (its mark
##              button's key on it): choose one to see and change it.
##   CARD       the chosen slot. A drawn PREVIEW: a brass-bound glass globe
##              with the form's shape inside, the part's essences poured in
##              (what leads fills most of it) and the variation's fitting on
##              its spout, beside a strain dial (out of 100, red past 70).
##              Beside it, in plain words: its name, what it does, "Echoes
##              ..." when the mix comes close to a bond's spell, how it fills
##              and what one cast strains, the part's level. A part not yet
##              at level 3 says how far it has to go.
##   FORM       the forms this part has opened (the hand's Strike and Bolt,
##              Volley later...); the ones still locked dark with their level.
##   EFFECTS    a button for each essence in the part (its own mix, leading
##              first): its effect, press for the next that has opened. The
##              essences themselves are the part's: the Body tab moves them.
##   VARIATION  None, then each variation (drawn on the globe as a fitting
##              on its spout): press one to put it on, again to take it off;
##              those not yours yet sit dark.
##   NAME and BOOST, then where each kind of banked essence flows (routing).
##   GIFTS      what the Abilities tab shows a marked climber, for the six
##              Nodes in plain words: each Node's minor ability and gift (or
##              when it comes; a sleeping Node only that it sleeps), and on
##              the train "Try your abilities" (the practice room).
##
## Every press changes the slot AT ONCE (saved and carried straight away):
## there's no draft and no "Set" button, so nothing can be lost by choosing
## another slot or closing the book. A change that finds an echo is noted
## for the climber (tree.gd note_echo) and said under the card.
##
## WHEN: as before (the essence bench stood on the train), techniques change
## only ON THE TRAIN, between climbs. Anywhere else the tab shows everything,
## its buttons off, with a line saying where to change them.
##
## Rules first (no drawing; the tests use them), then the tab, then the
## drawings. Every word is in TEXT.

const Unbound := preload("res://scripts/unbound.gd")
const Tech := preload("res://scripts/technique.gd")
const Library := preload("res://scripts/library.gd")
const TreeRules := preload("res://scripts/tree.gd")
const Controls := preload("res://scripts/controls.gd")
const UI := preload("res://scripts/ui.gd")
const Art := preload("res://scripts/train_art.gd")
const BodyMove := preload("res://scripts/body_move.gd")

## The tab's id on the climber screen.
const TAB_ID := "techniques"
## How long the last change's line stays under the card (ms).
const SAID_MS := 12000

static var TEXT := {
	"tab": "Techniques",
	"slot": "%s  %s",
	"slot_sleep": "%s · level %d",
	"slot_asleep": "%s · asleep",
	"locked": "You can look here anywhere. Techniques change only on the train, between climbs.",
	"title": "%s  ·  %s",
	"level": "%s: level %d of %d  ·  size %s of %d",
	"asleep": "At level %d it carries a technique: %s more size. It grows as you use it.",
	"sleeping": "This Node is asleep. Essence routed to it soaks in, and when enough has, it wakes; at level %d it carries a technique.",
	"core_tech": "Core technique: your core essence leads this part",
	"fill": "%s: full at %d, then it casts for nothing  ·  strain +%d of 100",
	"boost": "Boost: spends %s you carry unbanked for +%d%% power",
	"boost_on": "Boost casts: on",
	"boost_off": "Boost casts: off",
	"name": "Name (optional)",
	"form": "Form",
	"form_locked": "%s · level %d",
	"effects": "Effects",
	"effect": "%s %s: %s",
	"leads": "(leads)",
	"share": "%d%%",
	"more": "  ›",
	"essences_note": "These essences are your %s's own mix. To change them, move essence on the Body tab.",
	"fill_note": "Use makes a Node grow; the Body tab can move essence into your %s from another Node (or feed it while it sleeps).",
	"body": "Body tab",
	"variation": "Variation",
	"none": "None",
	"routes": "Where banked essence pools",
	"route": "%s  →  %s",
	"route_note": "Tap a kind to send it to another Node from now on (a sleeping Node soaks it in and wakes sooner). Its natural Node is marked *.",
	"note": "Every press changes the technique at once: there's nothing to set and nothing to lose. Its essences come from the part itself; the form, each essence's effect and the variation are yours.",
	"set": "%s now casts %s.",
	"set_echo": "%s now casts %s. Found an echo: %s",
	"effect_locked": "%s opens at %d %s pooled.",
	"strain": "strain",
	"echoes": "Echoes %s: %s",
	"one_line": "%s: %s",
	"touch": "; a touch of %s",
	"empty_line": "This Node carries a technique once it reaches level 3. It grows as you use it.",
	"gifts": "What Your Nodes Give",
	"gift_asleep": "%s: asleep. It wakes once enough essence has soaked into it.",
	"gift_minor": "%s: %s",
	"gift_has": "Gift: %s, %s.",
	"gift_at": "Gift at level %d: %s, %s.",
	"try": "Try your abilities",
	"try_note": "On the train, Try your abilities opens a safe practice room with training dummies.",
}
## Each variation's fitting, in the order they're offered.
const FITTING_ORDER := ["wide", "long", "quick", "split", "lingering", "chain", "delayed", "mirrored", "echo", "charged"]


# --- the rules (no drawing: the tests use these) ------------------------------------------

## The tab's ribbon: [id, name] (menu.gd climber_tabs adds it for the Unbound).
static func tab() -> Array:
	return [TAB_ID, String(TEXT["tab"])]


## Techniques change only on the train (as they did at the essence bench).
static func can_edit(main) -> bool:
	return main != null and main.profile != null and Unbound.is_on(main.profile) and bool(main.on_train)


## The chosen slot (0..5), shared with the climber screen's other pages.
static func slot(menu) -> int:
	return clampi(int(menu.get_meta("tech_slot", 0)), 0, Unbound.PARTS.size() - 1)


## The forms of a part, for the Form row: [form id, owned?, level that opens
## it]. Forms not written yet aren't shown.
static func forms(prof, part: String) -> Array:
	var out: Array = []
	var owned: Array = TreeRules.owned_forms(prof, part)
	for id in Library.forms_of(part):
		var f := Library.form(id)
		if not Library.built(f) and not id in owned:
			continue
		out.append([id, id in owned, int(f.get("opens", 1))])
	return out


## The technique with another form of its part (one its tree has opened).
static func set_form(prof, t: Dictionary, form: String) -> Dictionary:
	var out := t.duplicate(true)
	var part := String(out.get("part", "hand"))
	if not form in TreeRules.owned_forms(prof, part):
		return out
	var keep_name := String(out.get("name", "")) != "" and Tech.valid(out) and String(out["name"]) != Tech.auto_name(out)
	out["shape"] = form
	if not keep_name:
		out["name"] = ""
	_unname(out)
	Unbound.sync_tech(prof, out, part)  # (its essences are the part's own)
	return out


## The effects open to an essence for this climber: its base, then each
## that has opened (enough pooled: tree.gd effect_open).
static func effects_for(prof, kind: String) -> Array:
	var out: Array = []
	for id in Library.effects_of(kind):
		if id == String(Library.BASE.get(kind, "")) or TreeRules.effect_open(prof, id):
			out.append(id)
	return out


## The next effect open to one of the technique's essences.
static func cycle_effect(prof, t: Dictionary, kind: String) -> Dictionary:
	var out := t.duplicate(true)
	if not kind in out.get("kinds", []):
		return out
	var opts := effects_for(prof, kind)
	var now := Tech.effect_of(out, kind)
	var next: String = opts[(opts.find(now) + 1) % opts.size()] if not opts.is_empty() else now
	if not (out.get("effects") is Dictionary):
		out["effects"] = {}
	if next == String(Library.BASE.get(kind, "")):
		out["effects"].erase(kind)
	else:
		out["effects"][kind] = next
	if out["effects"].is_empty():
		out.erase("effects")
	return out


## What opens next for an essence that has only its base effect ("" if nothing).
static func effect_next(prof, kind: String) -> String:
	for id in Library.effects_of(kind):
		var fx := Library.effect(id)
		if Library.built(fx) and not TreeRules.effect_open(prof, id) and float(fx.get("opens", 0)) > 0.0:
			return TEXT["effect_locked"] % [String(fx["name"]), int(fx["opens"]), Tech.display(kind)]
	return ""


## A variation pressed: put on (in place of another), or taken off ("" takes
## off whatever is on).
static func fit(prof, t: Dictionary, vid: String) -> Dictionary:
	var out := t.duplicate(true)
	if vid == "" or vid in Tech.variations(out):
		out.erase("vars")
	elif vid in TreeRules.owned_variations(prof):
		out["vars"] = [vid]
	else:
		return out
	_unname(out)
	return out


## A ready-made recipe's name goes once it's changed (it would no longer fit).
static func _unname(t: Dictionary) -> void:
	for id in Tech.RECIPES:
		if String(t.get("name", "")) == String(Tech.RECIPES[id]["name"]):
			t["name"] = ""


## What it does, in one line: its form, its lead's effect, a touch of the rest.
static func one_line(t: Dictionary) -> String:
	if not Tech.valid(t):
		return TEXT["empty_line"]
	var sh: Dictionary = Tech.shape(t)
	var cls := String(sh.get("class", "hit"))
	var key: String = {"self": "self", "shell": "shell", "sight": "near"}.get(cls, "hit")
	var lead := String(t["kinds"][0])
	var fx := Library.effect(Tech.effect_of(t, lead))
	var phrase := String(fx.get("move", fx.get(key, "")) if cls == "move" else fx.get(key, fx.get("hit", "")))
	var line: String = TEXT["one_line"] % [String(sh["name"]), phrase]
	var rest: Array = []
	for i in range(1, t["kinds"].size()):
		rest.append(String(Library.effect(Tech.effect_of(t, String(t["kinds"][i]))).get("name", "")).to_lower())
	if not rest.is_empty():
		line += TEXT["touch"] % " and ".join(rest)
	return line


## "Echoes Gale Lift: lifts the light foes..." ("" if it echoes nothing).
static func echo_line(t: Dictionary) -> String:
	if not Tech.valid(t):
		return ""
	var e := Library.echo_of(t)
	if e.is_empty():
		return ""
	var says := String(load("res://scripts/spells/unbound_effects.gd").echo_says(t))
	return TEXT["echoes"] % [e["name"], says] if says != "" else Library.TEXT["echoes"] % e["name"]


## Puts `t` into slot `i` at once (saved, carried straight away) and notes an
## echo found. Only on the train, for a part half full. True if it changed.
static func apply(menu, i: int, t: Dictionary) -> bool:
	var main = menu.main
	var prof = main.profile
	if not can_edit(main) or i < 0 or i >= Unbound.PARTS.size() or not Tech.valid(t) or not Unbound.tech_ready(prof, Unbound.PARTS[i]):
		return false
	var techs: Array = Unbound.state(prof)["techs"]
	if str(techs[i]) == str(t):
		return false
	techs[i] = t.duplicate(true)
	var found := TreeRules.note_echo(prof, techs[i])
	prof.save()
	main._give_bonds()
	var key := _key(menu, i)
	var where: String = key if key != "" else Unbound.node_name(Unbound.PARTS[i])
	var line: String = TEXT["set_echo"] % [where, Tech.title(techs[i]), Library.echo_of(techs[i])["name"]] if found else TEXT["set"] % [where, Tech.title(techs[i])]
	menu.set_meta("tech_said", {"line": line, "ms": Time.get_ticks_msec(), "echo": found})
	return true


## The key that casts slot `i` ("" on a phone, where its button shows it).
static func _key(menu, i: int) -> String:
	var main = menu.main
	var part: String = Unbound.PARTS[i]
	if main.touch_active:
		return ""
	if main.pad_active:
		return Controls.pad_name(Controls.PART_PAD[part], main.pad_ps, true)
	return String(main.BondScript.Bonds.PART_KEYS[part])


# --- the tab -------------------------------------------------------------------------------

## The tab, into the climber screen's box (menu.gd _page_climber).
static func build(menu) -> void:
	var main = menu.main
	var prof = main.profile
	var small: bool = menu.compact()
	var told: String = main.tip_now("unbound_techniques")  # (the first time: what this tab does)
	if told != "":
		menu.box.add_child(menu.Entity.says(told, 30.0 if small else 38.0))
	Unbound.sync_techs(prof)
	var edit := can_edit(main)
	var sel := slot(menu)
	# The six slots, one per part (its mark button's key on it).
	var grid: GridContainer = menu._grid(3 if small else 6, 6)
	for i in Unbound.PARTS.size():
		var part: String = Unbound.PARTS[i]
		var t := Unbound.tech_of(prof, i)
		var key := _key(menu, i)
		var label: String = Tech.title(t) if Tech.valid(t) else (TEXT["slot_sleep"] % [Unbound.node_name(part), Unbound.level(prof, part)] if Unbound.awake(prof, part) else TEXT["slot_asleep"] % Unbound.node_name(part))
		var b: Button = menu._button(TEXT["slot"] % [key, label] if key != "" else label, _pick_slot.bind(menu, i), grid)
		UI.keep_text(b)  # (its words whole: smaller, then wrapped, never cut)
		b.custom_minimum_size.x = 0
		b.set_meta("tech_slot", i)
		b.set_meta("help", "tech_slot")
		if Tech.valid(t):
			b.add_theme_color_override("font_color", Tech.color(Tech.lead(t)).lightened(0.15))
		if i == sel:
			b.add_theme_color_override("font_color", menu.GOLD)
			b.add_theme_stylebox_override("normal", _sel_box())
	if not edit:
		var ll: Label = menu._small_label(TEXT["locked"], Color(UI.GOLD, 0.85))
		ll.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ll.custom_minimum_size.x = 280.0
		ll.set_meta("tech_locked", true)
		menu.box.add_child(ll)
	var part: String = Unbound.PARTS[sel]
	var t := Unbound.tech_of(prof, sel)
	_card(menu, part, t)
	_map_row(menu, sel, part, t)
	if not t.is_empty():
		_form_row(menu, part, t, edit)
		_effect_row(menu, part, t, edit)
		_variation_row(menu, t, edit)
		_name_row(menu, sel, t, edit)
	else:
		_body_row(menu, part, false)
	_routes(menu, edit)
	_gifts(menu)
	_practice(menu)
	if not small:
		menu._note(TEXT["note"])


## "On the body map" under the card (as the Abilities tab has for a marked
## climber's spells): the book's Tree on this technique's form.
static func _map_row(menu, sel: int, part: String, t: Dictionary) -> void:
	if not Tech.valid(t):
		return
	var TreeView = load("res://scripts/tree_view.gd")
	var at: Array = TreeView.node_of(menu.main, {"kind": "technique", "part": part, "tech": t, "id": "tech_%d" % sel})
	if at.is_empty():
		return
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.box.add_child(row)
	row.add_child(load("res://scripts/abilities.gd")._map_link(menu, at, menu.compact()))


## What the Abilities tab shows a marked climber, for the Unbound: each
## Node's minor ability and gift in plain words (a sleeping Node: only that
## it sleeps).
static func _gifts(menu) -> void:
	var prof = menu.main.profile
	menu._section(TEXT["gifts"])
	var g: GridContainer = menu._grid(1 if menu.compact() else 2, 6)
	g.set_meta("tech_gifts", true)
	for part in Unbound.PARTS:
		var line := ""
		var col: Color = menu.DIM
		if not Unbound.awake(prof, part):
			line = TEXT["gift_asleep"] % Unbound.node_name(part)
			col = menu.FAINT
		else:
			var gift: Dictionary = Unbound.GIFTS.get(part, {})
			var gl: String = TEXT["gift_has"] % [String(gift.get("name", "")), String(gift.get("desc", ""))] if Unbound.has_gift(prof, part) \
				else TEXT["gift_at"] % [Unbound.GIFT_LEVEL, String(gift.get("name", "")), String(gift.get("desc", ""))]
			line = TEXT["gift_minor"] % [Unbound.node_name(part), Unbound.minor_text(prof, part)] + " " + gl
			col = Tech.color(Unbound.lead(prof, part) if Unbound.lead(prof, part) != "" else String(Unbound.PART_KIND[part])).lightened(0.3)
		var l: Label = menu._small_label(line, col)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 240.0
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.set_meta("tech_gift", part)
		g.add_child(l)


## "Try your abilities" (the practice room, on the train), as the Abilities tab offers it.
static func _practice(menu) -> void:
	var main = menu.main
	if main.on_train and main.practice != null:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		menu._gap(2)
		menu.box.add_child(row)
		var tb: Button = menu._button(TEXT["try"], func(): main.practice.start(), row)
		tb.set_meta("try_abilities", true)
		tb.custom_minimum_size.x = 220.0
		UI.keep_text(tb)
	elif not menu.compact():
		menu._note(TEXT["try_note"])


## The chosen slot's card: the drawn preview, and what it does in plain words.
static func _card(menu, part: String, t: Dictionary) -> void:
	var main = menu.main
	var prof = main.profile
	var small: bool = menu.compact()
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_box(Tech.color(Tech.lead(t)) if not t.is_empty() else UI.FAINT))
	card.set_meta("tech_card", part)
	menu.box.add_child(card)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10 if small else 16)
	card.add_child(row)
	# The preview: the globe and the strain dial (drawn below).
	var pv := HBoxContainer.new()
	pv.add_theme_constant_override("separation", 2)
	pv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(pv)
	var globe := Globe.new()
	globe.form = String(t.get("shape", Library.BASE_FORMS[part][0]))
	globe.cls = String(Library.form(globe.form).get("class", "hit"))
	globe.kinds = t.get("kinds", []).duplicate()
	globe.fitting = Tech.variations(t)[0] if not t.is_empty() and not Tech.variations(t).is_empty() else ""
	globe.dark = t.is_empty()
	globe.custom_minimum_size = Vector2(108, 100) if small else Vector2(150, 138)
	pv.add_child(globe)
	var gauge := Gauge.new()
	gauge.strain = Tech.strain(t) if not t.is_empty() else 0.0
	gauge.custom_minimum_size = Vector2(62, 72) if small else Vector2(78, 84)
	gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	gauge.visible = Unbound.awake(prof, part)  # (a sleeping Node shows no numbers)
	pv.add_child(gauge)
	# The words.
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3 if small else 5)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(col)
	var lv := Unbound.level(prof, part)
	var head: String = TEXT["title"] % [Unbound.node_name(part), Tech.title(t)] if not t.is_empty() else Unbound.node_name(part)
	var hl: Label = menu._small_label(head, Tech.color(Tech.lead(t)).lightened(0.25) if not t.is_empty() else menu.TEXT)
	hl.add_theme_font_size_override("font_size", 18 if small else 20)
	hl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hl.set_meta("tech_title", true)
	col.add_child(hl)
	if t.is_empty() and not Unbound.awake(prof, part):
		_line(col, TEXT["sleeping"] % Unbound.TECH_LEVEL, menu.TEXT, 15).set_meta("tech_asleep", true)  # (no numbers while it sleeps)
	elif t.is_empty():
		var need := maxf(0.0, float(Unbound.LEVELS[Unbound.TECH_LEVEL - 1]) - Unbound.size(prof, part))
		_line(col, TEXT["asleep"] % [Unbound.TECH_LEVEL, Unbound._num(need)] if need > 0.0 else Tech.TEXT["empty"], menu.TEXT, 15).set_meta("tech_asleep", true)
		_line(col, Unbound.minor_text(prof, part), menu.DIM, 14)
	else:
		if bool(t.get("core", false)):
			_line(col, TEXT["core_tech"], Tech.color(String(prof.path)).lightened(0.2), 14)
		_line(col, Tech.describe(t), menu.TEXT, 15 if small else 16).set_meta("tech_desc", true)
		if Unbound.tech_young(prof, part):
			_line(col, Unbound.TEXT["young"] % [int(round(Unbound.power(prof, part) * 100.0)), Unbound.FULL_TECH_LEVEL], menu.DIM, 14).set_meta("tech_young", true)
		var echo := echo_line(t)
		if echo != "":
			_line(col, echo, Color(0.79, 0.65, 1.0), 14).set_meta("tech_echo", true)
		var fills: String = String(main.BondScript.Bonds.PART_FILLS[part])
		fills = fills.substr(0, 1).to_upper() + fills.substr(1)  # ("Fills when you parry")
		_line(col, TEXT["fill"] % [fills, int(round(Tech.charge(t, prof))), int(round(Tech.strain(t)))], menu.GOLD, 14)
		var on: bool = bool(Unbound.state(prof).get("boost", true))
		_line(col, TEXT["boost"] % [Tech.cost_text(t, prof), int(Tech.BOOST * 100.0)], menu.GOLD if on else menu.DIM, 14)
	if Unbound.awake(prof, part):
		_line(col, TEXT["level"] % [Unbound.node_name(part), lv, Unbound.MAX_LEVEL, Unbound._num(Unbound.size(prof, part)), int(Unbound.Core.CAP)], menu.DIM, 13)
	var said: Dictionary = menu.get_meta("tech_said", {})
	if not said.is_empty() and Time.get_ticks_msec() - int(said.get("ms", 0)) < SAID_MS:
		_line(col, String(said["line"]), Color(0.79, 0.65, 1.0) if bool(said.get("echo", false)) else UI.GOOD, 14).set_meta("tech_said", true)


static func _line(parent: Node, text: String, col: Color, fs: int) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 200.0
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


## Form: the forms the part has opened, the one in use gilded; locked ones dark.
static func _form_row(menu, part: String, t: Dictionary, edit: bool) -> void:
	var prof = menu.main.profile
	menu._section(TEXT["form"])
	var list := forms(prof, part)
	var g: GridContainer = menu._grid(3 if menu.compact() else maxi(3, mini(6, list.size())), 6)
	for f in list:
		var id: String = f[0]
		var name := String(Library.form(id).get("name", id))
		var b: Button = menu._button(name if f[1] else TEXT["form_locked"] % [name, int(f[2])], _set_form.bind(menu, id), g)
		UI.keep_text(b)
		b.set_meta("tech_form", id)
		b.set_meta("help", "tech_form")
		b.disabled = not edit or not f[1]
		if id == String(t["shape"]):
			_chosen(menu, b)


## Effects: one button for each essence in the part, leading first.
static func _effect_row(menu, part: String, t: Dictionary, edit: bool) -> void:
	var prof = menu.main.profile
	menu._section(TEXT["effects"])
	var g: GridContainer = menu._grid(1 if menu.compact() else 3, 6)
	var kinds: Array = t["kinds"]
	var w := Tech.weights(t)
	for i in kinds.size():
		var k := String(kinds[i])
		var fx := Library.effect(Tech.effect_of(t, k))
		var opts := effects_for(prof, k)
		var tag: String = TEXT["leads"] if i == 0 else TEXT["share"] % int(round(100.0 * float(w.get(k, 0.0))))
		var b: Button = menu._button(TEXT["effect"] % [Tech.display(k), tag, String(fx.get("name", ""))] + (TEXT["more"] if opts.size() > 1 else ""), _cycle_fx.bind(menu, k), g)
		UI.keep_text(b)
		b.add_theme_color_override("font_color", Tech.color(k).lightened(0.3))
		b.set_meta("tech_fx", k)
		b.set_meta("help", "tech_fx")
		b.tooltip_text = String(fx.get("says", ""))
		b.disabled = not edit
	_body_row(menu, part, true)


## A line on where the part's essences come from, and the way to the Body
## tab (where essence moves between parts).
static func _body_row(menu, part: String, awake: bool) -> void:
	var nl: Label = menu._small_label((TEXT["essences_note"] if awake else TEXT["fill_note"]) % Unbound.node_name(part), menu.DIM)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.custom_minimum_size.x = 280.0
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	menu.box.add_child(row)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(nl)
	var bb: Button = menu._button(TEXT["body"], BodyMove.open_body.bind(menu), row)
	bb.set_meta("help", "ub_body_open")
	bb.custom_minimum_size.x = 120.0
	UI.keep_text(bb)


## Variation: None, then each written variation; the one on gilded, the
## ones not yours yet dark.
static func _variation_row(menu, t: Dictionary, edit: bool) -> void:
	var prof = menu.main.profile
	menu._section(TEXT["variation"])
	var owned: Array = TreeRules.owned_variations(prof)
	var on: String = Tech.variations(t)[0] if not Tech.variations(t).is_empty() else ""
	var ids: Array = [""]
	for vid in FITTING_ORDER:
		if Library.built(Library.variation(vid)):
			ids.append(vid)
	var g: GridContainer = menu._grid(4 if menu.compact() else 6, 6)
	for vid in ids:
		var v := Library.variation(vid) if vid != "" else {}
		var b: Button = menu._button(String(v.get("name", vid)) if vid != "" else TEXT["none"], _fit.bind(menu, vid), g)
		UI.keep_text(b)
		b.set_meta("tech_fitting", vid)
		b.set_meta("help", "tech_fitting")
		b.disabled = not edit or (vid != "" and not vid in owned)
		if vid != "":
			b.tooltip_text = String(v.get("says", ""))
		if vid == on:
			_chosen(menu, b)


## Its name (optional) and the boost switch.
static func _name_row(menu, i: int, t: Dictionary, edit: bool) -> void:
	var prof = menu.main.profile
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	menu._gap(2)
	menu.box.add_child(row)
	var name := LineEdit.new()
	name.placeholder_text = "%s: %s" % [TEXT["name"], Tech.auto_name(t)]
	name.text = String(t.get("name", "")) if String(t.get("name", "")) != Tech.auto_name(t) else ""
	name.max_length = 24
	name.custom_minimum_size.y = 38
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.editable = edit
	name.set_meta("help", "tech_name")
	name.text_submitted.connect(func(s): _rename(menu, i, s))
	name.focus_exited.connect(func(): if is_instance_valid(name) and is_instance_valid(menu): _rename(menu, i, name.text, false))
	row.add_child(name)
	var on: bool = bool(Unbound.state(prof).get("boost", true))
	var tb: Button = menu._button(TEXT["boost_on"] if on else TEXT["boost_off"], _toggle_boost.bind(menu), row)
	tb.set_meta("tech_boost", true)
	tb.set_meta("help", "tech_boost")
	tb.custom_minimum_size.x = 170.0
	tb.disabled = not edit
	UI.keep_text(tb)


## Where each kind of banked essence pools (routing).
static func _routes(menu, edit: bool) -> void:
	var prof = menu.main.profile
	menu._section(TEXT["routes"])
	var og: GridContainer = menu._grid(2 if menu.compact() else 3, 6)
	for k in Unbound.NATURAL:
		var to := Unbound.part_for(prof, k)
		var ob: Button = menu._button(TEXT["route"] % [Tech.display(k), Unbound.PART_NAMES[to] + ("*" if to == Unbound.NATURAL[k] else "")], _route.bind(menu, k), og)
		ob.add_theme_color_override("font_color", Tech.color(k).lightened(0.2))
		ob.set_meta("route", k)
		ob.set_meta("help", "ub_route")
		ob.disabled = not edit
	if not menu.compact():
		menu._note(TEXT["route_note"])


## The one in use, gilded (still gilded while the buttons are off, away
## from the train).
static func _chosen(menu, b: Button) -> void:
	menu._primary(b)
	b.add_theme_stylebox_override("disabled", UI.primary_box("normal"))
	b.add_theme_color_override("font_disabled_color", Color(UI.GILT_HI, 0.8))


static func _sel_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.2, 0.16, 0.1, 0.9)
	sb.border_color = UI.GOLD
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(6)
	return sb


static func _card_box(col: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.06, 0.05, 0.08, 0.92)
	sb.border_color = Color(col, 0.8)
	sb.set_border_width_all(2)
	sb.border_width_top = 5
	sb.set_corner_radius_all(6)
	sb.set_content_margin_all(10)
	return sb


# --- presses -------------------------------------------------------------------------------

## The tab built again where it was (no fade, no jump to the top), the focus
## back on what was pressed (keys and controller).
static func _redraw(menu, meta: String, value) -> void:
	var sv: int = menu.scroll.scroll_vertical
	menu._want_focus = {"meta": meta, "value": value}
	menu._quiet = true
	menu.open("climber", menu.opened_direct)
	menu._quiet = false
	# (the new page is laid out over the next frames: put the scroll back once it is)
	for i in 3:
		menu.scroll.scroll_vertical = sv
		await menu.get_tree().process_frame
		if not is_instance_valid(menu) or menu.page != "climber":
			return
	menu.scroll.scroll_vertical = sv


static func _pick_slot(menu, i: int) -> void:
	menu.set_meta("tech_slot", i)
	menu.remove_meta("tech_said")
	menu.main.sfx("ui_confirm", 1.0, -4.0, 0.0)
	_redraw(menu, "tech_slot", i)


static func _set_form(menu, form: String) -> void:
	var prof = menu.main.profile
	var i := slot(menu)
	if apply(menu, i, set_form(prof, Unbound.tech_of(prof, i), form)):
		menu.main.sfx("craft_rune", 1.0, -4.0, 0.0)
	_redraw(menu, "tech_form", form)


static func _cycle_fx(menu, kind: String) -> void:
	var prof = menu.main.profile
	var i := slot(menu)
	if effects_for(prof, kind).size() < 2:
		# Nothing else open yet: say what opens next.
		var next := effect_next(prof, kind)
		if next != "":
			menu.set_meta("tech_said", {"line": next, "ms": Time.get_ticks_msec(), "echo": false})
	elif apply(menu, i, cycle_effect(prof, Unbound.tech_of(prof, i), kind)):
		menu.main.sfx("glint", 1.2, -6.0, 0.0)
	_redraw(menu, "tech_fx", kind)


static func _fit(menu, vid: String) -> void:
	var prof = menu.main.profile
	var i := slot(menu)
	if apply(menu, i, fit(prof, Unbound.tech_of(prof, i), vid)):
		menu.main.sfx("equip_heavy", 1.3, -6.0, 0.0)
	_redraw(menu, "tech_fitting", vid)


static func _rename(menu, i: int, s: String, redraw := true) -> void:
	if not is_instance_valid(menu) or not can_edit(menu.main):
		return
	var techs: Array = Unbound.state(menu.main.profile)["techs"]
	if not Tech.valid(techs[i]) or String(techs[i].get("name", "")) == s.strip_edges():
		return
	techs[i]["name"] = s.strip_edges()
	menu.main.profile.save()
	menu.main._give_bonds()
	if redraw:
		_redraw(menu, "help", "tech_name")


## Casts boost from carried essence (on), or never spend it (off).
static func _toggle_boost(menu) -> void:
	if not can_edit(menu.main):
		return
	var st: Dictionary = Unbound.state(menu.main.profile)
	st["boost"] = not bool(st.get("boost", true))
	menu.main.profile.save()
	menu.main._give_bonds()
	_redraw(menu, "tech_boost", true)


static func _route(menu, kind: String) -> void:
	if not can_edit(menu.main):
		return
	var prof = menu.main.profile
	var at := Unbound.PARTS.find(Unbound.part_for(prof, kind))
	Unbound.route(prof, kind, Unbound.PARTS[(at + 1) % Unbound.PARTS.size()])
	prof.save()
	_redraw(menu, "route", kind)


# --- drawn in code -------------------------------------------------------------------------

## Draws a form's shape (inside the globe) in a circle of radius `r` at `c`.
static func draw_form(ci: CanvasItem, form: String, cls: String, c: Vector2, r: float, col: Color, w := 2.0) -> void:
	match form:
		"strike":
			ci.draw_arc(c + Vector2(-r * 0.3, 0), r * 0.8, -0.9, 0.9, 16, col, w * 1.6, true)
			ci.draw_line(c + Vector2(-r * 0.7, r * 0.5), c + Vector2(-r * 0.1, -r * 0.1), Color(col, 0.6), w)
		"bolt":
			ci.draw_line(c + Vector2(-r * 0.8, 0), c + Vector2(r * 0.55, 0), col, w * 1.4)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.85, 0), c + Vector2(r * 0.4, -r * 0.3), c + Vector2(r * 0.4, r * 0.3)]), col)
		"volley":
			for a in [-0.4, 0.0, 0.4]:
				var dir := Vector2.from_angle(a)
				ci.draw_line(c - dir * r * 0.7, c + dir * r * 0.5, col, w)
				ci.draw_colored_polygon(PackedVector2Array([c + dir * r * 0.8, c + dir * r * 0.45 + dir.orthogonal() * r * 0.18, c + dir * r * 0.45 - dir.orthogonal() * r * 0.18]), col)
		"dash":
			for i in 3:
				var x := -r * 0.6 + i * r * 0.45
				ci.draw_polyline(PackedVector2Array([c + Vector2(x, -r * 0.35), c + Vector2(x + r * 0.3, 0), c + Vector2(x, r * 0.35)]), Color(col, 0.5 + 0.25 * i), w * 1.3, true)
		"leap":
			var pts := PackedVector2Array()
			for i in 13:
				var f := float(i) / 12.0
				pts.append(c + Vector2(lerpf(-r * 0.8, r * 0.6, f), r * 0.35 - sin(f * PI) * r * 0.9))
			ci.draw_polyline(pts, col, w, true)
			ci.draw_arc(c + Vector2(r * 0.6, r * 0.42), r * 0.3, 0.0, TAU, 16, col, w, true)
		"shell":
			ci.draw_arc(c, r * 0.75, PI, TAU, 20, col, w * 1.8, true)
			ci.draw_line(c + Vector2(-r * 0.75, 0), c + Vector2(r * 0.75, 0), col, w * 1.4)
			ci.draw_circle(c + Vector2(0, -r * 0.15), r * 0.12, col)
		"push":
			ci.draw_circle(c, r * 0.14, col)
			for i in 2:
				ci.draw_arc(c, r * (0.45 + 0.35 * i), 0.0, TAU, 24, Color(col, 0.9 - 0.3 * i), w, true)
		"shout":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.7, 0), c + Vector2(r * 0.8, -r * 0.55), c + Vector2(r * 0.8, r * 0.55)]), Color(col, 0.35))
			ci.draw_polyline(PackedVector2Array([c + Vector2(r * 0.8, -r * 0.55), c + Vector2(-r * 0.7, 0), c + Vector2(r * 0.8, r * 0.55)]), col, w, true)
			ci.draw_arc(c + Vector2(-r * 0.7, 0), r * 1.4, -0.36, 0.36, 10, col, w, true)
		"pull":
			ci.draw_line(c + Vector2(r * 0.8, 0), c + Vector2(-r * 0.5, 0), col, w * 1.4)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-r * 0.2, -r * 0.35), c + Vector2(-r * 0.6, 0), c + Vector2(-r * 0.2, r * 0.35)]), col, w * 1.4, true)
			ci.draw_arc(c + Vector2(r * 0.8, 0), r * 0.2, PI * 0.5, PI * 1.5, 8, col, w, true)
		"mark":
			ci.draw_arc(c, r * 0.65, 0.0, TAU, 24, col, w, true)
			ci.draw_arc(c, r * 0.3, 0.0, TAU, 16, col, w, true)
			for a in 4:
				var dir := Vector2.from_angle(a * PI * 0.5)
				ci.draw_line(c + dir * r * 0.5, c + dir * r * 0.9, col, w)
		"sight":
			var pts := PackedVector2Array()
			for i in 17:
				var f := float(i) / 16.0
				pts.append(c + Vector2(lerpf(-r * 0.85, r * 0.85, f), -sin(f * PI) * r * 0.45))
			for i in 17:
				var f := float(i) / 16.0
				pts.append(c + Vector2(lerpf(r * 0.85, -r * 0.85, f), sin(f * PI) * r * 0.45))
			ci.draw_polyline(pts, col, w, true)
			ci.draw_circle(c, r * 0.24, col)
		"within":
			var pts := PackedVector2Array()
			for i in 25:
				var a := float(i) / 24.0 * TAU
				pts.append(c + Vector2(16.0 * pow(sin(a), 3), -(13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a))) * r / 22.0)
			ci.draw_colored_polygon(pts, Color(col, 0.3))
			ci.draw_polyline(pts, col, w, true)
		_:
			# A new form drawn by its class.
			match cls:
				"move":
					draw_form(ci, "dash", cls, c, r, col, w)
				"self":
					draw_form(ci, "within", cls, c, r, col, w)
				"shell":
					draw_form(ci, "shell", cls, c, r, col, w)
				"mark", "sight":
					draw_form(ci, "mark", cls, c, r, col, w)
				_:
					for i in 8:
						var dir := Vector2.from_angle(i * TAU / 8.0)
						ci.draw_line(c + dir * r * 0.2, c + dir * r * (0.85 if i % 2 == 0 else 0.55), col, w)


## Draws a variation's fitting at `c`, `r` across (pointing down: on the spout).
static func draw_fitting(ci: CanvasItem, vid: String, c: Vector2, r: float, brass: Color, w := 1.6) -> void:
	var dark := brass.darkened(0.45)
	var hi := brass.lightened(0.35)
	# The collar that screws on.
	ci.draw_rect(Rect2(c + Vector2(-r * 0.45, -r * 0.9), Vector2(r * 0.9, r * 0.32)), brass)
	for i in 3:
		ci.draw_line(c + Vector2(-r * 0.45, -r * 0.84 + i * r * 0.1), c + Vector2(r * 0.45, -r * 0.84 + i * r * 0.1), dark, 1.0)
	match vid:
		"wide":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.25, -r * 0.58), c + Vector2(r * 0.25, -r * 0.58), c + Vector2(r * 0.85, r * 0.6), c + Vector2(-r * 0.85, r * 0.6)]), brass)
			ci.draw_line(c + Vector2(-r * 0.85, r * 0.6), c + Vector2(r * 0.85, r * 0.6), hi, w)
		"long":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.18, -r * 0.58), Vector2(r * 0.36, r * 1.5)), brass)
			ci.draw_line(c + Vector2(-r * 0.1, -r * 0.5), c + Vector2(-r * 0.1, r * 0.85), hi, 1.0)
		"quick":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.3, -r * 0.58), Vector2(r * 0.6, r * 0.5)), brass)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.1, -r * 0.1), c + Vector2(-r * 0.25, r * 0.35), c + Vector2(0, r * 0.35), c + Vector2(-r * 0.15, r * 0.85), c + Vector2(r * 0.3, r * 0.2), c + Vector2(r * 0.02, r * 0.2)]), hi)
		"split":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.2, -r * 0.58), Vector2(r * 0.4, r * 0.5)), brass)
			for a in [-0.6, 0.0, 0.6]:
				var dir := Vector2.from_angle(PI * 0.5 + a)
				ci.draw_line(c + Vector2(0, -r * 0.1), c + Vector2(0, -r * 0.1) + dir * r * 0.9, brass, w * 2.2)
				ci.draw_circle(c + Vector2(0, -r * 0.1) + dir * r * 0.9, w * 1.2, hi)
		"lingering":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.18, -r * 0.58), Vector2(r * 0.36, r * 0.6)), brass)
			ci.draw_arc(c + Vector2(0, r * 0.35), r * 0.55, 0.0, PI, 14, brass, w * 2.0, true)
			ci.draw_line(c + Vector2(-r * 0.55, r * 0.35), c + Vector2(r * 0.55, r * 0.35), hi, w)
		"chain":
			for i in 4:
				ci.draw_arc(c + Vector2(0, -r * 0.4 + i * r * 0.33), r * 0.32, 0.0, TAU, 12, brass if i % 2 == 0 else hi, w * 1.3, true)
		"delayed":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.15, -r * 0.58), Vector2(r * 0.3, r * 0.3)), brass)
			ci.draw_circle(c + Vector2(0, r * 0.3), r * 0.55, brass)
			ci.draw_circle(c + Vector2(0, r * 0.3), r * 0.42, Color(0.93, 0.88, 0.76))
			ci.draw_line(c + Vector2(0, r * 0.3), c + Vector2(0, r * 0.02), dark, w)
			ci.draw_line(c + Vector2(0, r * 0.3), c + Vector2(r * 0.22, r * 0.38), dark, w)
		"mirrored":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.2, -r * 0.58), Vector2(r * 0.4, r * 0.7)), brass)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.2, 0), c + Vector2(-r * 0.85, r * 0.4), c + Vector2(-r * 0.2, r * 0.4)]), brass)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.2, 0), c + Vector2(r * 0.85, r * 0.4), c + Vector2(r * 0.2, r * 0.4)]), brass)
		"echo":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.18, -r * 0.58), Vector2(r * 0.36, r * 0.5)), brass)
			ci.draw_arc(c + Vector2(0, r * 0.3), r * 0.28, 0.0, TAU, 14, hi, w, true)
			ci.draw_arc(c + Vector2(0, r * 0.3), r * 0.55, 0.0, TAU, 18, brass, w, true)
		"charged":
			ci.draw_rect(Rect2(c + Vector2(-r * 0.35, -r * 0.58), Vector2(r * 0.7, r * 1.2)), brass)
			for i in 4:
				ci.draw_line(c + Vector2(-r * 0.35, -r * 0.4 + i * r * 0.28), c + Vector2(r * 0.35, -r * 0.28 + i * r * 0.28), dark, w)
			ci.draw_circle(c + Vector2(0, r * 0.75), r * 0.14, hi)
		_:
			ci.draw_rect(Rect2(c + Vector2(-r * 0.2, -r * 0.58), Vector2(r * 0.4, r * 0.9)), brass)


## The brass-bound glass globe (the old essence bench's, made small): the
## form's shape inside, the part's essences poured in (the lead filling most
## of it, the others swirling thinner above), a brass neck and a spout below
## with the variation's fitting. Dark while the part sleeps.
class Globe extends Control:
	const UI := preload("res://scripts/ui.gd")
	const Art := preload("res://scripts/train_art.gd")
	var Tab = load("res://scripts/technique_tab.gd")
	var form := "strike"
	var cls := "hit"
	var kinds: Array = []
	var fitting := ""
	var dark := false
	var t := 0.0
	var _acc := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		t += delta
		_acc += delta
		# (the liquid's swirl: a few times a second, and only while it's on screen)
		if _acc < 1.0 / 10.0 or not is_visible_in_tree():
			return
		_acc = 0.0
		queue_redraw()

	func _draw() -> void:
		var Tech = load("res://scripts/technique.gd")
		var w := size.x
		var h := size.y
		var spout_h := h * 0.18
		var rad := minf(w * 0.42, (h - spout_h - 10.0) * 0.5)
		var c := Vector2(w * 0.5, 8.0 + rad)
		var brass: Color = Art.GILT if not dark else Color(0.3, 0.27, 0.22)
		var b := UI.Draw.Batch.new()
		# The glass ball: a shadow, dark inside, a soft rim.
		b.contact(c + Vector2(0, rad + spout_h * 0.9), rad * 0.7, 0.3)
		b.circle(c, rad + 2.0, Art.OUTLINE)
		b.circle(c, rad, Color(0.07, 0.07, 0.11, 0.94))
		if not kinds.is_empty():
			# The lead fills the bottom; the others float above it, thinner, swirling.
			var level := 0.62 + 0.1 * kinds.size()
			var lead_share := 0.7 if kinds.size() > 1 else 1.0
			var rest_share := (1.0 - lead_share) / maxf(kinds.size() - 1, 1)
			var y0 := c.y + rad
			var total_h := rad * 2.0 * level
			var bands: Array = []
			for i in kinds.size():
				var bh := total_h * (lead_share if i == 0 else rest_share)
				bands.append([String(kinds[i]), y0 - bh, y0])
				y0 -= bh
			for bi in range(bands.size() - 1, -1, -1):
				var bd: Array = bands[bi]
				var pts := _cap(c, rad - 1.0, bd[1], c.y + rad, float(bi))
				if pts.size() >= 3:
					b.polygon(pts, Color(Tech.color(bd[0]).darkened(0.15), 0.92))
			for bd in bands:
				var y: float = bd[1]
				var half := sqrt(maxf(rad * rad - (y - c.y) * (y - c.y), 0.0)) - 2.0
				if half > 2.0:
					var pts := PackedVector2Array()
					for i in 13:
						var f := float(i) / 12.0
						pts.append(Vector2(c.x - half + 2.0 * half * f, y + sin(f * TAU * 1.5 + t * 2.2) * 1.5))
					b.path(pts, Color(Tech.color(bd[0]).lightened(0.45), 0.8), 1.4)
			# Motes rising in the lead.
			var lc: Color = Tech.color(String(kinds[0])).lightened(0.5)
			for i in 4:
				var f := fmod(t * 0.25 + i * 0.25, 1.0)
				b.dot(Vector2(c.x + sin(i * 2.3 + t) * rad * 0.45, c.y + rad - f * total_h * 0.9), 1.3, Color(lc, 0.6 * (1.0 - f)))
		# The brass neck collar and the spout.
		b.box(Rect2(c.x - 8.0, c.y - rad - 5.0, 16.0, 6.0), brass)
		var sp := Vector2(c.x, c.y + rad + 1.0)
		b.box(Rect2(sp.x - 4.5, sp.y, 9.0, spout_h * 0.45), brass.darkened(0.1))
		b.flush(self)
		# The form's shape, inside, over the liquid.
		var ink := Color(1.0, 0.96, 0.85, 0.9) if not dark else Color(0.4, 0.38, 0.36, 0.6)
		Tab.draw_form(self, form, cls, c, rad * 0.55, ink, 2.2)
		# The glass's shine and its brass band.
		draw_arc(c, rad - 4.0, PI * 1.05, PI * 1.45, 12, Color(1, 1, 1, 0.3 if not dark else 0.08), 3.0, true)
		draw_circle(c + Vector2(-rad * 0.42, -rad * 0.45), rad * 0.07, Color(1, 1, 1, 0.35 if not dark else 0.08))
		draw_arc(c, rad + 1.0, 0.0, TAU, 40, Art.OUTLINE, 4.0, true)
		draw_arc(c, rad + 1.0, 0.0, TAU, 40, brass.darkened(0.1), 2.6, true)
		for a in [0.0, PI]:
			draw_circle(c + Vector2.from_angle(a) * (rad + 1.0), 2.6, brass.lightened(0.2))
		if fitting != "":
			Tab.draw_fitting(self, fitting, sp + Vector2(0, spout_h * 0.45 + spout_h * 0.3), spout_h * 0.5, brass)
		elif not kinds.is_empty() and not dark:
			draw_circle(sp + Vector2(0, spout_h * 0.55), 2.0, Tech.color(String(kinds[0])).lightened(0.2))

	## The part of the circle (c, r) between y0 and y1 (a band of liquid), its
	## top edge gently waving.
	func _cap(c: Vector2, r: float, y0: float, y1: float, seed: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		y0 = clampf(y0, c.y - r, c.y + r)
		y1 = clampf(y1, c.y - r, c.y + r)
		if y1 - y0 < 0.5:
			return pts
		var n := 12
		var a0 := asin(clampf((y0 - c.y) / r, -1.0, 1.0))
		var a1 := asin(clampf((y1 - c.y) / r, -1.0, 1.0))
		for i in n + 1:
			var a := lerpf(a0, a1, float(i) / n)
			pts.append(c + Vector2(cos(a) * r, sin(a) * r))
		for i in n + 1:
			var a := lerpf(a1, a0, float(i) / n)
			pts.append(c + Vector2(-cos(a) * r, sin(a) * r))
		var half := cos(a0) * r
		for i in range(1, 12):
			var f := float(i) / 12.0
			pts.append(Vector2(c.x - half + 2.0 * half * f, y0 + sin(f * TAU + t * 2.0 + seed) * 1.3))
		return pts


## The strain dial: a brass dial, 0 to 100, its needle at the strain one
## cast adds, a red arc where a part runs hot (70 and up).
class Gauge extends Control:
	const UI := preload("res://scripts/ui.gd")
	const Art := preload("res://scripts/train_art.gd")
	var strain := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var c := Vector2(w * 0.5, h * 0.46)
		var r := minf(w * 0.42, h * 0.36)
		var b := UI.Draw.Batch.new()
		b.contact(c + Vector2(0, r + 3.0), r * 0.9, 0.3)
		b.circle(c, r + 4.0, Art.OUTLINE)
		b.ball(c, r + 3.0, Art.GILT.darkened(0.15), false)
		b.circle(c, r, Color(0.93, 0.88, 0.76))
		b.arc(c, r * 0.8, PI + PI * 0.7, TAU, 10, Color(0.75, 0.2, 0.15, 0.7), 4.0)
		for i in 11:
			var a := PI + PI * float(i) / 10.0
			var dir := Vector2.from_angle(a)
			b.line(c + dir * r * (0.78 if i % 5 == 0 else 0.86), c + dir * r * 0.95, Color(0.2, 0.14, 0.08), 1.4 if i % 5 == 0 else 1.0)
		var k := clampf(strain / 100.0, 0.0, 1.0)
		b.stroke(c, c + Vector2.from_angle(PI + PI * k) * r * 0.82, Color(0.6, 0.1, 0.08), 2.2)
		b.ball(c, 3.2, Art.GILT)
		b.flush(self)
		UI.draw_label(self, Vector2(0, c.y + r * 0.5), "+%d" % int(round(strain)), 13, Color(0.2, 0.12, 0.06), HORIZONTAL_ALIGNMENT_CENTER, w)
		var Tab = load("res://scripts/technique_tab.gd")
		UI.draw_label(self, Vector2(0, h - 1.0), String(Tab.TEXT["strain"]), 11, Color(UI.GOLD, 0.9), HORIZONTAL_ALIGNMENT_CENTER, w)
