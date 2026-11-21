extends RefCounted
## The Unbound's other pages, built with menu.gd's own helpers (mouse,
## keyboard, controller and touch all work):
##   the Body tab's Node cards (menu.gd calls climber(); pressing a card
##     chooses that Node: what its levels bring shows under the cards, and
##     it's the Node to move essence out of, or a sleeping one to feed:
##     body_move.gd), the chosen Node's levels (node_levels) and the
##     attributes the Nodes' sizes give (attributes);
##   the Developer's way back (secret_page.gd calls core_section());
##   the dev tools' section.
## (Their techniques have a tab of their own on the climber screen:
## technique_tab.gd.)

const Unbound := preload("res://scripts/unbound.gd")
const Tech := preload("res://scripts/technique.gd")
const UI := preload("res://scripts/ui.gd")
const BodyMove := preload("res://scripts/body_move.gd")

static var TEXT := {
	"body_empty": "holds nothing",
	"body_core": "core %d",
	"node_head": "%s  ·  level %d of 12",
	"node_asleep_head": "%s  ·  asleep",
	"node_asleep": "Asleep. Essence routed here soaks in until it wakes.",
	"node_size": "size %s of %d  ·  holds %s",
	"node_next": "%s more size to level %d: it grows as you use it",
	"node_top": "full size",
	"levels_title": "%s: what its levels bring",
	"levels_asleep": "Your %s is asleep. It holds nothing yet and shows no numbers. Essence routed to it soaks in, and when enough has soaked in it wakes: its minor ability first, then a level for every 10 it grows.",
	"level_row": "Level %d  ·  %s",
	"level_awake": "it awakens: %s",
	"level_gift": "%s: %s",
	"level_tech": "a technique (%s)",
	"level_fork": "a choice on its Tree: %s",
	"level_form": "a new form: %s",
	"level_cap": "its capstone (%s); pure, its signature",
	"or": " or ",
	"attrs_title": "Attributes",
	"attr_row": "%s  ·  %s",
	"attr_bonus": "+%.1f%% %s",
	"attr_from": "from %s size",
	"attrs_note": "Each awake Node's size counts for the essences it holds, by their share. The bonuses are small and grow ever slower, up to %d%%.",
	"dev": "The Unbound",
	"back_title": "Let the tower beasts mark you again",
	"back_desc": "The Developer's exception: you stop being Unbound. The densest part takes a mark (its bond chosen by what's pooled there), and the rest of your raw essence makes your next marks come sooner.",
	"back_press": "Mark me again",
	"back_again": "{again} to be marked again",
	"back_train": "Only on the train.",
	"part_tech": "Technique: %s",
	"part_tech_at": "A technique at level %d",
	"gift": "%s: %s",
	"gift_at": "At level %d: %s",
	"climber_note": "Each Node has a size (its density: how much it can hold, 120 at most) and what it holds. A Node sleeps until banked essence has soaked into it; awake, it grows as you use it: what its techniques spend comes back from the essence you bank into it, and stretches it a little. Every 10 of size is a level: 3 wakes it (a minor ability), 5 a gift, 6 a technique, 12 its capstone.",
}
const ARM_MS := 4000


# --- the climber screen ------------------------------------------------------------------

## The climber screen's line for an Unbound.
static func climber_line(prof) -> String:
	return Unbound.TEXT["climber_line"] % [Unbound.TEXT["stage"] % [Unbound.stage_name(prof), Unbound.stage(prof)], prof.climbs, "climb" if prof.climbs == 1 else "climbs", prof.best_floor]


## The Node cards beside the figure (the Body tab: menu.gd _climber_marks).
## A sleeping Node's card says only that it sleeps: no numbers.
static func climber(menu, grid: GridContainer) -> void:
	var prof = menu.main.profile
	var small: bool = menu.compact()
	for part in ["brow", "throat", "heart", "back", "hand", "legs"]:
		var lv := Unbound.level(prof, part)
		var col: Color = menu.main.unbound.part_color(prof, part) if menu.main.unbound != null else UI.TEXT
		var lines: Array = []
		var asleep := not Unbound.awake(prof, part)
		if asleep:
			lines.append(TEXT["node_asleep_head"] % Unbound.node_name(part))
			lines.append(TEXT["node_asleep"])
			col = col.darkened(0.35)
		else:
			var bits: Array = []
			for k in Unbound.mix(prof, part):
				bits.append("%s %d" % [Tech.display(k), int(round(Unbound.amount(prof, part, k)))])
			if Unbound.core(prof, part) >= 0.5:
				bits.append(TEXT["body_core"] % int(round(Unbound.core(prof, part))))
			var need := Unbound.next_need(prof, part)
			lines.append(TEXT["node_head"] % [Unbound.node_name(part), lv])
			lines.append(TEXT["node_size"] % [Unbound._num(Unbound.size(prof, part)), int(Unbound.Core.CAP), ", ".join(bits) if not bits.is_empty() else TEXT["body_empty"]])
			if not small:
				lines.append(TEXT["node_next"] % [Unbound._num(need), lv + 1] if need > 0.0 else TEXT["node_top"])
				var t := Unbound.tech_of(prof, Unbound.PARTS.find(part))
				lines.append(TEXT["part_tech"] % Tech.title(t) if Tech.valid(t) else TEXT["part_tech_at"] % Unbound.TECH_LEVEL)
		var b := Button.new()
		b.text = "\n".join(lines)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		# (wide enough to read: on a narrow screen the cards go under the figure: reflow.gd)
		b.custom_minimum_size = Vector2(196.0 if small else 230.0, 70.0 if small else 96.0)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_font_size_override("font_size", 13 if small else 14)
		b.add_theme_color_override("font_color", col.lightened(0.25))
		b.set_meta("part", part)
		b.set_meta("node_asleep", asleep)
		BodyMove.card(menu, b, part)  # (pressed: this Node chosen: its levels below, and moving essence)
		UI.keep_text(b)  # (its words whole: smaller, then wrapped, never cut)
		grid.add_child(b)


## The chosen Node's levels, under the cards: what each level brings (its
## Tree's nodes, in plain words), the reached ones bright. A sleeping Node
## says only that it sleeps and how it wakes.
static func node_levels(menu, part: String) -> void:
	var prof = menu.main.profile
	var TreeRules = load("res://scripts/tree.gd")
	menu._section(TEXT["levels_title"] % Unbound.node_name(part))
	if not Unbound.awake(prof, part):
		var l: Label = menu._small_label(TEXT["levels_asleep"] % Unbound.node_name(part), menu.DIM)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 280.0
		l.set_meta("node_levels", part)
		menu.box.add_child(l)
		return
	var g: GridContainer = menu._grid(1 if menu.compact() else 2, 4)
	g.set_meta("node_levels", part)
	var lv := Unbound.level(prof, part)
	for n in TreeRules.unbound_nodes(prof, part):
		var at := int(n["at"])
		var names: Array = n["options"].map(func(o): return String(o.get("name", "")))
		var what := ""
		match String(n.get("kind", "")):
			"minor":
				var mt: String = Unbound.minor_text(prof, part).trim_suffix(".")
				what = TEXT["level_awake"] % (mt.left(1).to_lower() + mt.substr(1))
			"gift":
				var gift: Dictionary = Unbound.GIFTS.get(part, {})
				what = TEXT["level_gift"] % [String(gift.get("name", "")), String(gift.get("desc", ""))]
			"forms":
				what = TEXT["level_tech"] % TEXT["or"].join(names)
			"fork":
				what = TEXT["level_fork"] % TEXT["or"].join(names)
			"form":
				what = TEXT["level_form"] % String(names[0] if not names.is_empty() else "")
			"capstone":
				what = TEXT["level_cap"] % String(names[0] if not names.is_empty() else "")
			_:
				continue
		var row: Label = menu._small_label(TEXT["level_row"] % [at, what], menu.GOLD if lv >= at else menu.DIM)
		row.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.custom_minimum_size.x = 240.0
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.set_meta("node_level", at)
		g.add_child(row)


## The attributes the Nodes' sizes give (profile.gd attribute, unbound.gd
## attr_size): each with its bonus and the size counted for it.
static func attributes(menu) -> void:
	var prof = menu.main.profile
	menu._section(TEXT["attrs_title"])
	var g: GridContainer = menu._grid(2 if menu.compact() else 3, 4)
	g.set_meta("attributes", true)
	for kind in ["air", "blade", "stone", "iron", "fire", "water"]:
		var attr: Dictionary = prof.ATTRIBUTES[kind]
		var bonus: float = prof.attribute(kind)
		var line: String = TEXT["attr_row"] % [String(attr["name"]), TEXT["attr_bonus"] % [bonus * 100.0, String(attr["bonus"])]]
		if Unbound.attr_size(prof, kind) >= 0.5:
			line += "  ·  " + TEXT["attr_from"] % Unbound._num(Unbound.attr_size(prof, kind))
		var l: Label = menu._small_label(line, Tech.color(kind).lightened(0.25) if bonus > 0.0005 else menu.FAINT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 180.0
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.set_meta("attr", kind)
		g.add_child(l)
	if not menu.compact():
		menu._note(TEXT["attrs_note"] % int(round(prof.ATTRIBUTE_CAP * 100.0)))


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
		var b: Button = menu._button("%s +10" % Unbound.PART_NAMES[part], _dev_density.bind(menu, part), g)
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


## Dev: a Node one level bigger (and filled to its new size).
static func _dev_density(menu, part: String) -> void:
	var prof = menu.main.profile
	var k: String = Unbound.primary(prof, part)
	if k == "":
		k = Unbound.PART_KIND[part]
	Unbound.set_size(prof, part, Unbound.size(prof, part) + maxf(Unbound.next_need(prof, part), 0.01))
	if Unbound.awake(prof, part):
		Unbound.put(prof, part, k, Unbound.take_limit(prof, part, k))
	Unbound.Core.sync(prof)
	prof.save()
	menu.main._give_bonds()
	menu._say("%s: size %s, level %d" % [Unbound.node_name(part), Unbound._num(Unbound.size(prof, part)), Unbound.level(prof, part)])


static func _dev_strain(menu, part: String) -> void:
	var run = menu.main.unbound
	if run == null:
		return
	run.add_strain(part, 40.0)
	menu._say("%s strain %d" % [Unbound.PART_NAMES[part], int(run.strain_of(part))])
