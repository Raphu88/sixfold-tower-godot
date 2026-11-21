extends RefCounted
## The Unbound's other pages, built with menu.gd's own helpers (mouse,
## keyboard, controller and touch all work):
##   the climber screen's part cards and stage (menu.gd calls climber();
##     pressing a card chooses it to move essence out of: body_move.gd);
##   the Developer's way back (secret_page.gd calls core_section());
##   the dev tools' section.
## (Their techniques have a tab of their own on the climber screen:
## technique_tab.gd.)

const Unbound := preload("res://scripts/unbound.gd")
const Tech := preload("res://scripts/technique.gd")
const UI := preload("res://scripts/ui.gd")
const BodyMove := preload("res://scripts/body_move.gd")

static var TEXT := {
	"body_empty": "empty",
	"body_core": "core %d",
	"dev": "The Unbound",
	"back_title": "Let the tower beasts mark you again",
	"back_desc": "The Developer's exception: you stop being Unbound. The densest part takes a mark (its bond chosen by what's pooled there), and the rest of your raw essence makes your next marks come sooner.",
	"back_press": "Mark me again",
	"back_again": "{again} to be marked again",
	"back_train": "Only on the train.",
	"part_card": "%s  ·  level %d of 12",
	"part_raw": "%d/%d  ·  %s",
	"part_next": "%d to level %d",
	"part_top": "full",
	"part_tech": "Technique: %s",
	"part_tech_at": "A technique at level %d",
	"gift": "%s: %s",
	"gift_at": "At level %d: %s",
	"climber_note": "Banked essence fills each part like a cup (120 at most). The first essence in a part leads it; up to two more add their touch. Level 3 wakes a minor ability, level 5 a gift, level 6 (half full) a technique (the Techniques tab), level 12 (full) the capstone.",
}
const ARM_MS := 4000


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
		for k in Unbound.mix(prof, part):
			bits.append("%s %d" % [Tech.display(k), int(round(Unbound.amount(prof, part, k)))])
		if Unbound.core(prof, part) >= 0.5:
			bits.append(TEXT["body_core"] % int(round(Unbound.core(prof, part))))
		var need := Unbound.next_need(prof, part)
		var lines: Array = [TEXT["part_card"] % [Unbound.PART_NAMES[part], lv]]
		lines.append(TEXT["part_raw"] % [int(Unbound.fill(prof, part)), int(Unbound.Core.CAP), ", ".join(bits) if not bits.is_empty() else TEXT["body_empty"]])
		if not small:
			lines.append(TEXT["part_next"] % [int(ceil(need)), lv + 1] if need > 0.0 else TEXT["part_top"])
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
		BodyMove.card(menu, b, part)  # (pressed: move essence out of this part)
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


static func _dev_density(menu, part: String) -> void:
	var prof = menu.main.profile
	var k: String = Unbound.primary(prof, part)
	if k == "":
		k = Unbound.PART_KIND[part]
	Unbound.put(prof, part, k, Unbound.LEVEL_SIZE)
	Unbound.Core.sync(prof)
	prof.save()
	menu.main._give_bonds()
	menu._say("%s: level %d" % [Unbound.PART_NAMES[part], Unbound.level(prof, part)])


static func _dev_strain(menu, part: String) -> void:
	var run = menu.main.unbound
	if run == null:
		return
	run.add_strain(part, 40.0)
	menu._say("%s strain %d" % [Unbound.PART_NAMES[part], int(run.strain_of(part))])
