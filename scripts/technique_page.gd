extends RefCounted
## The Unbound's pages, built with menu.gd's own helpers (mouse, keyboard,
## controller and touch all work):
##   the TECHNIQUES page (from your car on the train): your six carried
##     techniques along the top (each on a mark button), the chosen one's
##     card below: its part and shape on top (tap to change), up to three
##     essence gems (tap one to cycle it; the first leads), what it will do
##     in plain words, its cost and strain, and an optional name; then the
##     ready-made recipes and where each kind of essence pools (routing);
##   the climber screen's part cards and stage (menu.gd calls climber());
##   the Developer's way back (secret_page.gd calls core_section());
##   the dev tools' section.

const Unbound := preload("res://scripts/unbound.gd")
const Tech := preload("res://scripts/technique.gd")
const Controls := preload("res://scripts/controls.gd")
const UI := preload("res://scripts/ui.gd")

const TEXT := {
	"title": "TECHNIQUES",
	"sub": "Six carried, one on each mark button. A part and up to three essences; the first leads.",
	"slot_empty": "empty",
	"shape": "%s  ·  %s",
	"shape_hint": "tap to change the shape",
	"level": "%s: level %d  ·  combines up to %d %s",
	"level_next": "  (%d at level %d)",
	"gem_empty": "+ essence",
	"gem_locked": "level %d",
	"cost": "Costs %s, from what you carry unbanked  ·  strain +%d of 100",
	"name": "Name (optional)",
	"recipes": "Ready-made",
	"clear": "Clear this slot",
	"routes": "Where banked essence pools",
	"route": "%s  →  %s",
	"route_note": "Tap a kind to send it to another part from now on. Its natural part is marked *.",
	"dev": "The Unbound",
	"back_title": "Let the tower beasts mark you again",
	"back_desc": "The Developer's exception: you stop being Unbound. The densest part takes a mark (its bond chosen by what's pooled there), and the rest of your raw essence makes your next marks come sooner.",
	"back_press": "Mark me again",
	"back_again": "Press again to be marked again",
	"back_train": "Only on the train.",
	"part_card": "%s  ·  level %d",
	"part_raw": "%d raw  ·  %s",
	"part_next": "%d to level %d",
	"part_top": "the top level",
	"gift": "%s: %s",
	"gift_at": "At level %d: %s",
	"climber_note": "Banked essence pools raw in each part (routing at the train changes where); your path's essence runs through all six. A part's level sets how hard its techniques hit, how many essences they combine, and its gift at level 5.",
}
const ARM_MS := 4000


static func _st(menu) -> Dictionary:
	return Unbound.state(menu.main.profile)


static func _slot(menu) -> int:
	return clampi(int(menu.get_meta("tech_slot", 0)), 0, Unbound.PARTS.size() - 1)


static func _key(menu, i: int) -> String:
	var part: String = Unbound.PARTS[i]
	var main = menu.main
	if main.touch_active:
		return ""
	if main.pad_active:
		return Controls.pad_name(Controls.PART_PAD[part], main.pad_ps, true)
	return String(main.BondScript.Bonds.PART_KEYS[part])


## The techniques page.
static func build(menu) -> void:
	var main = menu.main
	var prof = main.profile
	var st := _st(menu)
	menu._header(TEXT["title"], TEXT["sub"])
	var told: String = main.tip_now("unbound_techniques")
	if told != "":
		menu._text(told, menu.GOLD.lightened(0.2), true)
	var techs: Array = st["techs"]
	var sel := _slot(menu)
	# The six slots.
	var grid: GridContainer = menu._grid(3, 6)
	for i in techs.size():
		var t = techs[i]
		var key := _key(menu, i)
		var label: String = (Tech.title(t) if Tech.valid(t) else TEXT["slot_empty"])
		var b: Button = menu._button(("%s  %s" % [key, label]) if key != "" else label, _pick_slot.bind(menu, i), grid)
		b.clip_text = true
		b.custom_minimum_size.x = 0
		b.set_meta("tech_slot", i)
		if Tech.valid(t):
			b.add_theme_color_override("font_color", Tech.color(Tech.lead(t)).lightened(0.15))
		if i == sel:
			b.add_theme_color_override("font_color", menu.GOLD)
			b.add_theme_stylebox_override("normal", _sel_box())
	# The chosen slot's card.
	var t: Dictionary = techs[sel] if Tech.valid(techs[sel]) else {}
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _card_box(Tech.color(Tech.lead(t)) if not t.is_empty() else UI.FAINT))
	menu.box.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	card.add_child(col)
	if t.is_empty():
		menu._button(Tech.TEXT["empty"] + "  ·  " + TEXT["shape_hint"], _cycle_shape.bind(menu, sel), col)
	else:
		var part: String = t["part"]
		var shb: Button = menu._button(TEXT["shape"] % [Unbound.PART_NAMES[part], Tech.SHAPES[t["shape"]]["name"]], _cycle_shape.bind(menu, sel), col)
		shb.add_theme_font_size_override("font_size", 17)
		shb.set_meta("tech_shape", true)
		var most := Unbound.max_kinds(prof, part)
		var lv := Unbound.level(prof, part)
		var line: String = TEXT["level"] % [Unbound.PART_NAMES[part], lv, most, "essence" if most == 1 else "essences"]
		if most < Unbound.KINDS_AT.size():
			line += TEXT["level_next"] % [most + 1, int(Unbound.KINDS_AT[most])]
		col.add_child(menu._small_label(line, menu.DIM))
		var gems := HBoxContainer.new()
		gems.add_theme_constant_override("separation", 6)
		col.add_child(gems)
		for g in Unbound.KINDS_AT.size():
			var text := ""
			var gcol: Color = menu.DIM
			var locked := g >= most
			if g < t["kinds"].size():
				var k := String(t["kinds"][g])
				text = Tech.display(k) + ("  ·  " + Tech.TEXT["lead"] if g == 0 else "")
				gcol = Tech.color(k)
			elif locked:
				text = TEXT["gem_locked"] % int(Unbound.KINDS_AT[g])
				gcol = menu.FAINT
			else:
				text = TEXT["gem_empty"]
			var gb: Button = menu._button(text, _cycle_gem.bind(menu, sel, g), gems)
			gb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			gb.custom_minimum_size = Vector2(0, 44)
			gb.add_theme_color_override("font_color", gcol)
			gb.disabled = locked or g > t["kinds"].size()
			gb.set_meta("tech_gem", g)
		var desc: Label = menu._small_label(Tech.describe(t), menu.TEXT)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size.x = 280.0
		desc.add_theme_font_size_override("font_size", 14)
		col.add_child(desc)
		col.add_child(menu._small_label(TEXT["cost"] % [Tech.cost_text(t, prof), int(Tech.strain(t))], menu.GOLD))
		var name := LineEdit.new()
		name.placeholder_text = "%s: %s" % [TEXT["name"], Tech.auto_name(t)]
		name.text = String(t.get("name", "")) if String(t.get("name", "")) != Tech.auto_name(t) else ""
		name.max_length = 24
		name.custom_minimum_size.y = 36
		name.text_submitted.connect(func(s): _rename(menu, sel, s))
		name.focus_exited.connect(func(): _rename(menu, sel, name.text, false))
		col.add_child(name)
	# Ready-made recipes into this slot.
	menu._section(TEXT["recipes"])
	var rg: GridContainer = menu._grid(2 if menu.compact() else 3, 6)
	for id in Tech.RECIPES:
		var r: Dictionary = Tech.RECIPES[id]
		var rb: Button = menu._button("%s  ·  %s" % [r["name"], Unbound.PART_NAMES[r["part"]]], _use_recipe.bind(menu, sel, id), rg)
		rb.clip_text = true
		rb.add_theme_color_override("font_color", Tech.color(r["kinds"][0]).lightened(0.2))
	if not t.is_empty():
		menu._button(TEXT["clear"], _clear.bind(menu, sel), rg)
	# Routing.
	menu._section(TEXT["routes"])
	var og: GridContainer = menu._grid(2 if menu.compact() else 3, 6)
	for k in Unbound.NATURAL:
		var to := Unbound.part_for(prof, k)
		var ob: Button = menu._button(TEXT["route"] % [Tech.display(k), Unbound.PART_NAMES[to] + ("*" if to == Unbound.NATURAL[k] else "")], _route.bind(menu, k), og)
		ob.add_theme_color_override("font_color", Tech.color(k).lightened(0.2))
		ob.set_meta("route", k)
	if not menu.compact():
		menu._note(TEXT["route_note"])
	if menu.toast != "":
		menu._text(menu.toast, menu.GOLD, true)
	menu._footer()


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
	sb.set_content_margin_all(12)
	return sb


static func _save_and_redraw(menu) -> void:
	menu.main.profile.save()
	menu.main._give_bonds()
	menu.open("techniques", menu.opened_direct)


static func _pick_slot(menu, i: int) -> void:
	menu.set_meta("tech_slot", i)
	menu.open("techniques", menu.opened_direct)


## Every part's shapes in one cycle: Hand · Strike, Hand · Bolt, Legs · Dash, ...
static func shape_order() -> Array:
	var out: Array = []
	for part in ["hand", "legs", "back", "throat", "brow", "heart"]:
		for sh in Tech.PART_SHAPES[part]:
			out.append([part, sh])
	return out


## The next shape (and part); essences past the new part's limit drop off.
static func cycle_shape(prof, t: Dictionary) -> Dictionary:
	var order := shape_order()
	var at := 0
	if Tech.valid(t):
		for i in order.size():
			if order[i][0] == t["part"] and order[i][1] == t["shape"]:
				at = (i + 1) % order.size()
	var out := t.duplicate(true) if Tech.valid(t) else {"name": "", "kinds": ["fire"]}
	var keep_name: bool = Tech.valid(t) and String(t.get("name", "")) != "" and String(t["name"]) != Tech.auto_name(t)
	out["part"] = order[at][0]
	out["shape"] = order[at][1]
	out["kinds"] = out["kinds"].slice(0, Unbound.max_kinds(prof, out["part"]))
	if not keep_name:
		out["name"] = ""
	_unname_recipe(out)
	return out


## A ready-made recipe's name goes once it's changed (it would no longer fit).
static func _unname_recipe(t: Dictionary) -> void:
	for id in Tech.RECIPES:
		if String(t.get("name", "")) == String(Tech.RECIPES[id]["name"]):
			t["name"] = ""


static func _cycle_shape(menu, i: int) -> void:
	var techs: Array = _st(menu)["techs"]
	techs[i] = cycle_shape(menu.main.profile, techs[i] if techs[i] is Dictionary else {})
	_save_and_redraw(menu)


## The next essence in gem `g` (skipping kinds already in it; a gem past the
## first can be emptied, which drops those after it).
static func cycle_gem(prof, t: Dictionary, g: int) -> Dictionary:
	var out := t.duplicate(true)
	var kinds: Array = out["kinds"]
	if g >= Unbound.max_kinds(prof, out["part"]) or g > kinds.size():
		return out
	var options: Array = Unbound.kinds_for(prof)
	if g > 0:
		options.append("")
	var cur: String = String(kinds[g]) if g < kinds.size() else ""
	var at := options.find(cur)
	for n in options.size():
		at = (at + 1) % options.size()
		var k: String = options[at]
		if k == "" or not (k in kinds) or k == cur:
			break
	var pick: String = options[at]
	_unname_recipe(out)
	if pick == "":
		out["kinds"] = kinds.slice(0, g)
	elif g < kinds.size():
		kinds[g] = pick
	else:
		kinds.append(pick)
	return out


static func _cycle_gem(menu, i: int, g: int) -> void:
	var techs: Array = _st(menu)["techs"]
	if not Tech.valid(techs[i]):
		return
	techs[i] = cycle_gem(menu.main.profile, techs[i], g)
	_save_and_redraw(menu)


static func _rename(menu, i: int, s: String, redraw := true) -> void:
	var techs: Array = _st(menu)["techs"]
	if not Tech.valid(techs[i]) or String(techs[i].get("name", "")) == s.strip_edges():
		return
	techs[i]["name"] = s.strip_edges()
	menu.main.profile.save()
	menu.main._give_bonds()
	if redraw:
		menu.open("techniques", menu.opened_direct)


static func _use_recipe(menu, i: int, id: String) -> void:
	_st(menu)["techs"][i] = Tech.recipe(id)
	_save_and_redraw(menu)


static func _clear(menu, i: int) -> void:
	_st(menu)["techs"][i] = {}
	_save_and_redraw(menu)


static func _route(menu, kind: String) -> void:
	var prof = menu.main.profile
	var at := Unbound.PARTS.find(Unbound.part_for(prof, kind))
	Unbound.route(prof, kind, Unbound.PARTS[(at + 1) % Unbound.PARTS.size()])
	menu.main.profile.save()
	menu.open("techniques", menu.opened_direct)


# --- the climber screen ------------------------------------------------------------------

## The climber screen's line for an Unbound.
static func climber_line(prof) -> String:
	return Unbound.TEXT["climber_line"] % [Unbound.TEXT["stage"] % [Unbound.stage_name(prof), Unbound.stage(prof)], prof.climbs, "climb" if prof.climbs == 1 else "climbs", prof.best_floor]


## The part cards beside the figure (menu.gd's Marks tab, for an Unbound).
static func climber(menu, grid: GridContainer) -> void:
	var prof = menu.main.profile
	var small: bool = menu.compact()
	for part in ["brow", "throat", "heart", "back", "hand", "legs"]:
		var lv := Unbound.level(prof, part)
		var col: Color = menu.main.unbound.part_color(prof, part) if menu.main.unbound != null else UI.TEXT
		var bits: Array = []
		var pd: Dictionary = prof.part_density.get(part, {})
		for k in pd:
			if float(pd[k]) >= 1.0:
				bits.append("%s %d" % [Tech.display(k), int(pd[k])])
		var need := Unbound.next_need(prof, part)
		var lines: Array = [TEXT["part_card"] % [Unbound.PART_NAMES[part], lv]]
		lines.append(TEXT["part_raw"] % [int(Unbound.raw(prof, part)), ", ".join(bits) if not bits.is_empty() else "nothing pooled yet"])
		if not small:
			lines.append(TEXT["part_next"] % [int(ceil(need)), lv + 1] if need > 0.0 else TEXT["part_top"])
			var gf: Dictionary = Unbound.GIFTS[part]
			lines.append(TEXT["gift"] % [gf["name"], gf["desc"]] if lv >= Unbound.GIFT_LEVEL else TEXT["gift_at"] % [Unbound.GIFT_LEVEL, gf["desc"]])
		var b := Button.new()
		b.text = "\n".join(lines)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 70.0 if small else 96.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 11 if small else 12)
		b.add_theme_color_override("font_color", col.lightened(0.25))
		b.set_meta("part", part)
		b.clip_text = true
		grid.add_child(b)


# --- the Developer's way back (the Core tab) -------------------------------------------

static func core_section(menu) -> void:
	var main = menu.main
	var prof = main.profile
	if not Unbound.can_return(prof):
		return
	menu._section(TEXT["back_title"])
	menu._note(TEXT["back_desc"])
	var armed: bool = Time.get_ticks_msec() - int(menu.get_meta("unbound_back", -99999)) < ARM_MS
	var b: Button = menu._button(TEXT["back_again"] if armed else TEXT["back_press"], _go_back.bind(menu))
	b.disabled = not main.on_train
	if not main.on_train:
		menu.box.add_child(menu._small_label(TEXT["back_train"], menu.FAINT))


static func _go_back(menu) -> void:
	var main = menu.main
	if Time.get_ticks_msec() - int(menu.get_meta("unbound_back", -99999)) >= ARM_MS:
		menu.set_meta("unbound_back", Time.get_ticks_msec())
		menu.open("climber", menu.opened_direct)
		return
	menu.remove_meta("unbound_back")
	var got: Dictionary = Unbound.return_to_marks(main.profile)
	main.profile.save()
	main._give_bonds()
	var Bonds = main.BondScript.Bonds
	if String(got.get("id", "")) != "":
		menu.toast = Unbound.TEXT["back"] % [Bonds.BONDS[got["id"]]["name"], Bonds.PART_NAMES[got["part"]].to_lower()]
	else:
		menu.toast = Unbound.TEXT["back_none"]
	menu.toast_t = 4.0
	main.sfx("crit", 0.5, -4.0, 0.0)
	menu.open("climber", menu.opened_direct)


# --- dev tools -----------------------------------------------------------------------------

static func dev_section(menu) -> void:
	var main = menu.main
	var prof = main.profile
	var st := Unbound.state(prof)
	menu._section(TEXT["dev"])
	var head := "%s  ·  %s  ·  %d barriers broken%s" % ["Unbound" if st["on"] else "marked", Unbound.TEXT["stage"] % [Unbound.stage_name(prof), Unbound.stage(prof)],
		int(st["broken"]), "" if st["found"] else "  ·  route not found"]
	menu.box.add_child(menu._label(head, 0.0, menu.GOLD if st["on"] else menu.DIM))
	var r1: HBoxContainer = menu._row()
	menu._button("Become Unbound" if not st["on"] else "Back to marks", _dev_toggle.bind(menu), r1)
	menu._button("Show the refusal", _dev_refusal.bind(menu), r1)
	menu._button("-1 barrier", _dev_barriers.bind(menu, -1), r1)
	menu._button("+1 barrier", _dev_barriers.bind(menu, 1), r1)
	var g: GridContainer = menu._grid(6, 4)
	for part in Unbound.PARTS:
		var b: Button = menu._button("%s +60" % Unbound.PART_NAMES[part], _dev_density.bind(menu, part), g)
		b.clip_text = true
	for part in Unbound.PARTS:
		var b2: Button = menu._button("strain +40", _dev_strain.bind(menu, part), g)
		b2.clip_text = true
		b2.disabled = not st["on"]


static func _dev_toggle(menu) -> void:
	var prof = menu.main.profile
	var st := Unbound.state(prof)
	if st["on"]:
		st["on"] = false
	else:
		Unbound.become(prof)
		prof.regarded = true
		menu.main.first_climb = false
	prof.save()
	menu.main._give_bonds()
	menu._say("Unbound" if st["on"] else "Marked again (no marks)")


static func _dev_refusal(menu) -> void:
	var main = menu.main
	menu.close()
	var part := "hand"
	var id: String = main.profile.choose_bond({main.tower_data().get("essence", "air"): 10.0}, {})
	main.unbound._offer_refusal(part, id, "dev", [])


static func _dev_barriers(menu, by: int) -> void:
	var st := Unbound.state(menu.main.profile)
	st["broken"] = maxi(0, int(st["broken"]) + by)
	st["found"] = true
	menu.main.profile.save()
	menu._say("%d barriers broken" % int(st["broken"]))


static func _dev_density(menu, part: String) -> void:
	var prof = menu.main.profile
	var pd: Dictionary = prof.part_density.get(part, {})
	var k: String = Unbound.PART_KIND[part]
	pd[k] = float(pd.get(k, 0.0)) + 60.0
	prof.part_density[part] = pd
	prof.save()
	menu.main._give_bonds()
	menu._say("%s: level %d" % [Unbound.PART_NAMES[part], Unbound.level(prof, part)])


static func _dev_strain(menu, part: String) -> void:
	var run = menu.main.unbound
	if run == null:
		return
	run.add_strain(part, 40.0)
	menu._say("%s strain %d" % [Unbound.PART_NAMES[part], int(run.strain_of(part))])
