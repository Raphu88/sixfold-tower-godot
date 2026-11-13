extends RefCounted
## The Unbound's pages, built with menu.gd's own helpers (mouse, keyboard,
## controller and touch all work):
##   the TECHNIQUES page (from your car on the train): your six carried
##     techniques along the top (each on a mark button), the chosen one's
##     card below: its part and form, "Build at the bench" (the essence
##     bench in the Workshop car, essence_bench.gd, is where techniques are
##     built: the form, the essences in order and their effects, a fitting),
##     its essence gems (a quick swap: tap one to cycle it; the first
##     leads), what it will do in plain words (and "echoes X"), how it
##     fills, its strain and boost, and an optional name (and whether casts
##     boost from carried essence); then the ready-made recipes and where
##     each kind of essence pools (routing);
##   the climber screen's part cards and stage (menu.gd calls climber());
##   the Developer's way back (secret_page.gd calls core_section());
##   the dev tools' section.

const Unbound := preload("res://scripts/unbound.gd")
const Tech := preload("res://scripts/technique.gd")
const Controls := preload("res://scripts/controls.gd")
const UI := preload("res://scripts/ui.gd")
const Library := preload("res://scripts/library.gd")
const TreeRules := preload("res://scripts/tree.gd")
const EssenceBench := preload("res://scripts/essence_bench.gd")

static var TEXT := {
	"title": "Techniques",
	"sub": "Six carried, one on each mark button. A part and up to three essences; the first leads.",
	"slot_empty": "empty",
	"shape": "%s  ·  %s",
	"shape_hint": "build one at the bench",
	"bench": "Build at the bench",
	"bench_note": "In the Workshop car: choose its form, pour its essences in order, pick their effects and fit a variation.",
	"level": "%s: level %d  ·  combines up to %d %s",
	"level_next": "  (%d at level %d)",
	"gem_empty": "open",
	"gem_locked": "level %d",
	"fill": "%s: full at %d, then it casts for nothing  ·  strain +%d of 100",
	"boost": "Boost: spends %s you carry unbanked for +%d%% power",
	"boost_on": "Boost casts with carried essence: on",
	"boost_off": "Boost casts with carried essence: off",
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
	"back_again": "{again} to be marked again",
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
		UI.keep_text(b)  # (its words whole: smaller, then wrapped, never cut)
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
	# Building is at the essence bench, in the Workshop car (essence_bench.gd).
	var bench_b: Button = menu._button(TEXT["bench"], EssenceBench.open_for.bind(menu, sel), col)
	bench_b.set_meta("tech_bench", true)
	menu._primary(bench_b)
	bench_b.disabled = not main.on_train
	if t.is_empty():
		col.add_child(menu._small_label(Tech.TEXT["empty"] + "  ·  " + TEXT["shape_hint"], menu.DIM))
	else:
		var part: String = t["part"]
		var shl: Label = menu._small_label(TEXT["shape"] % [Unbound.PART_NAMES[part], Tech.SHAPES[t["shape"]]["name"]], Tech.color(Tech.lead(t)).lightened(0.25))
		shl.add_theme_font_size_override("font_size", 20)
		shl.set_meta("tech_shape", true)
		col.add_child(shl)
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
			# (Read only: the essence bench builds and changes techniques.)
			var gl: Label = menu._small_label(text, gcol)
			gl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			gl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			gl.custom_minimum_size = Vector2(0, 30)
			gl.set_meta("tech_gem_label", g)
			gems.add_child(gl)
		var desc: Label = menu._small_label(Tech.describe(t), menu.TEXT)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size.x = 280.0
		desc.add_theme_font_size_override("font_size", 16)
		col.add_child(desc)
		# "Echoes Gale Lift": the mix comes close to a bond's spell (library.gd ECHOES).
		var echo := EssenceBench.echo_line(t)
		if echo != "":
			var el: Label = menu._small_label(echo, Color(0.79, 0.65, 1.0))
			el.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			el.custom_minimum_size.x = 280.0
			el.set_meta("tech_echo", true)
			col.add_child(el)
		var fills: String = String(main.BondScript.Bonds.PART_FILLS[part])
		fills = fills.substr(0, 1).to_upper() + fills.substr(1)  # ("Fills when you parry")
		var fl: Label = menu._small_label(TEXT["fill"] % [fills, int(round(Tech.charge(t, prof))), int(Tech.strain(t))], menu.GOLD)
		fl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		fl.custom_minimum_size.x = 280.0
		col.add_child(fl)
		var on: bool = bool(st.get("boost", true))
		var bl: Label = menu._small_label(TEXT["boost"] % [Tech.cost_text(t, prof), int(Tech.BOOST * 100.0)], menu.GOLD if on else menu.DIM)
		bl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bl.custom_minimum_size.x = 280.0
		col.add_child(bl)
		var tb: Button = menu._button(TEXT["boost_on"] if on else TEXT["boost_off"], _toggle_boost.bind(menu), col)
		tb.set_meta("tech_boost", true)
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
		UI.keep_text(rb)  # (its words whole: smaller, then wrapped, never cut)
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
	# All six as the Abilities page shows them (and the practice room from there).
	menu._gap(2)
	var ab: Button = menu._button(menu.Abilities.TEXT["all"], menu.open.bind("abilities"))
	ab.set_meta("all_abilities", true)
	menu._primary(ab)
	if menu.toast != "":
		menu._text(menu.toast, menu.GOLD, true)
	menu._footer()


## Casts boost from carried essence (on), or never spend it (off).
static func _toggle_boost(menu) -> void:
	var st := _st(menu)
	st["boost"] = not bool(st.get("boost", true))
	_save_and_redraw(menu)


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
## With a climber, the forms their tree has opened follow each part's own
## (tree.gd owned_forms: Volley after Strike and Bolt, once the hand is level 3).
static func shape_order(prof = null) -> Array:
	var out: Array = []
	for part in ["hand", "legs", "back", "throat", "brow", "heart"]:
		var forms: Array = Tech.PART_SHAPES[part] if prof == null else TreeRules.owned_forms(prof, part)
		for sh in forms:
			out.append([part, sh])
	return out


## The next variation a technique can carry: none, then each one the
## climber owns (tree.gd owned_variations), in the library's order.
static func cycle_variation(prof, t: Dictionary) -> Dictionary:
	var owned: Array = TreeRules.owned_variations(prof)
	var order: Array = [""]
	for v in Library.VARIATION_ORDER:
		if v in owned:
			order.append(v)
	var now: String = Tech.variations(t)[0] if not Tech.variations(t).is_empty() else ""
	var next: String = order[(order.find(now) + 1) % order.size()]
	var out := t.duplicate(true)
	if next == "":
		out.erase("vars")
	else:
		out["vars"] = [next]
	_unname_recipe(out)
	return out


## The next shape (and part); essences past the new part's limit drop off.
static func cycle_shape(prof, t: Dictionary) -> Dictionary:
	var order := shape_order(prof)
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
		# (wide enough to read: on a narrow screen the cards go under the figure: reflow.gd)
		b.custom_minimum_size = Vector2(196.0 if small else 230.0, 70.0 if small else 96.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 13 if small else 14)
		b.add_theme_color_override("font_color", col.lightened(0.25))
		b.set_meta("part", part)
		UI.keep_text(b)  # (its words whole: smaller, then wrapped, never cut)
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
	var b: Button = menu._button(menu.Nav.fill(TEXT["back_again"], menu.main) if armed else TEXT["back_press"], _go_back.bind(menu))
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
	var broke: bool = main.unbound != null and main.unbound.broke_rules
	var head := "%s  ·  %s  ·  %s" % ["Unbound" if st["on"] else "marked", Unbound.TEXT["stage"] % [Unbound.stage_name(prof), Unbound.stage(prof)],
		("first climb: a barrier broken (refused at the Regard)" if broke else "first climb: no barrier broken") if main.first_climb else "not a first climb"]
	menu.box.add_child(menu._label(head, 0.0, menu.GOLD if st["on"] else menu.DIM))
	var r1: HBoxContainer = menu._row()
	menu._button("Become Unbound" if not st["on"] else "Back to marks", _dev_toggle.bind(menu), r1)
	menu._button("Show the refusal", _dev_refusal.bind(menu), r1)
	var bb: Button = menu._button("Unbreak the barrier" if broke else "Break a barrier", _dev_barriers.bind(menu), r1)
	bb.disabled = not main.first_climb
	var g: GridContainer = menu._grid(6, 4)
	for part in Unbound.PARTS:
		var b: Button = menu._button("%s +60" % Unbound.PART_NAMES[part], _dev_density.bind(menu, part), g)
		UI.keep_text(b)  # (its words whole: smaller, then wrapped, never cut)
	for part in Unbound.PARTS:
		var b2: Button = menu._button("strain +40", _dev_strain.bind(menu, part), g)
		UI.keep_text(b2)  # (its words whole: smaller, then wrapped, never cut)
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


## On the first climb: as if a barrier had been broken (or not): the Regard refuses you (or offers).
static func _dev_barriers(menu) -> void:
	var run = menu.main.unbound
	if run == null or not menu.main.first_climb:
		return
	run.broke_rules = not run.broke_rules
	Unbound.state(menu.main.profile)["found"] = true
	menu.main.profile.save()
	menu._say("A barrier broken: the Regard will refuse you" if run.broke_rules else "No barrier broken: the Regard will offer the mark")


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
