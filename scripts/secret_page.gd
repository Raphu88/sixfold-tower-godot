extends RefCounted
## The secret bond on the climber screen (its Core tab, shown only while the
## climber holds one) and in the dev tools. Built with menu.gd's own helpers,
## so mouse, keyboard, controller and touch all work. Mechanical text only.
##
## The Core tab: the bond's name and depth, every tool with what it does and
## its cost, what the next depth needs. For the Developer, also every spell's
## real numbers (on the train; in a climb once Inspect is paid this floor),
## Tune (on the train, depth 2) and changing your path (on the train).

const SB := preload("res://scripts/secret_bonds.gd")
const Secret := preload("res://scripts/secret.gd")
const UI := preload("res://scripts/ui.gd")
const Draw := preload("res://scripts/draw_util.gd")

const TAB := ["core", "Core"]
## A change of path is confirmed by a second press within this long (ms).
const ARM_MS := 4000


## The Core tab's contents, into the menu's page.
static func build(menu) -> void:
	var main = menu.main
	var prof = main.profile
	var bond := SB.bond_of(prof)
	if bond == "":
		menu._note("No secret bond.")
		return
	var col := SB.color(bond)
	var info: Dictionary = SB.BONDS[bond]
	var head: Label = menu._label(SB.TEXT["depth"] % [String(info["name"]).to_upper(), SB.depth_of(prof)], 0.0, col.lightened(0.15))
	head.add_theme_font_size_override("font_size", 18)
	menu.box.add_child(head)
	menu.box.add_child(menu._small_label("The core mark  ·  %s  ·  grows from %s  ·  from %s" % [info["what"], info["grows"], info["maker_name"]], menu.DIM))
	# The tools.
	menu._section("Tools (hold %s for the tool ring)" % _ring_key(main))
	var path: String = prof.path
	for d in range(1, SB.MAX_DEPTH + 1):
		var ids: Array = SB.RING[bond].filter(func(id): return int(SB.TOOLS[id]["depth"]) == d)
		if ids.is_empty() and d > SB.CAP:
			menu.box.add_child(menu._small_label("Depth %d: a deeper tool, to come" % d, menu.FAINT))
			continue
		for id in ids:
			var t: Dictionary = SB.TOOLS[id]
			var have: bool = d <= SB.depth_of(prof)
			var cost := ""
			if t["where"] == "ring":
				cost = SB.cost_text(t["cost"], path) + ("  ·  lasts the floor" if t.get("lasts", "") == "floor" else "")
			elif id == "dev_tune":
				cost = "%d crystal essence a change, on the train" % int(SB.TUNE_COST)
			var bb := "[color=#%s]Depth %d  ·  %s[/color]%s\n%s\n[color=#%s]%s[/color]" % [
				(col if have else menu.FAINT).to_html(false), d, t["name"], "" if have else "  (locked)", t["desc"],
				menu.DIM.to_html(false), cost]
			menu._rich(bb, 13, menu.TEXT if have else menu.FAINT)
	if bond == "developer":
		_developer(menu, col)
		menu.TechniquePage.core_section(menu)  # (an Unbound may be marked again: technique_page.gd)
	# What the next depth needs.
	menu._section("Growth")
	for line in SB.next_lines(prof):
		menu.box.add_child(menu._small_label(String(line), menu.DIM))
	if menu.toast != "":
		menu._text(menu.toast, menu.GOLD, true)


## The Developer's part: real numbers, Tune, a change of path.
static func _developer(menu, col: Color) -> void:
	var main = menu.main
	var prof = main.profile
	var p = main.player
	var train: bool = main.on_train
	var lens: bool = train or (main.secret_tools != null and main.secret_tools.paid.has("dev_inspect"))
	menu._section("Your spells' real numbers")
	if not lens:
		menu._note("Use Inspect from the tool ring to see them here this floor.")
	var tune_on: bool = SB.depth_of(prof) >= int(SB.TOOLS["dev_tune"]["depth"])
	var steady: float = 0.7 if p.has_bond("rune_artist") else 1.0
	for part in main.BondScript.Bonds.PARTS:
		if not p.bonds.has(part):
			continue
		var bd = p.bonds[part]
		for sp in bd.spells():
			var nums: Array = SB.spell_numbers(bd, sp, steady)
			var line := "[color=#%s]%s[/color]  ·  %s" % [bd.color().to_html(false), sp["name"], bd.display_name()]
			if lens:
				line += "\n" + "  ·  ".join(nums.map(func(r): return "%s %s" % [r[0], r[1]]))
				line += "\n[color=#%s]%s[/color]" % [menu.FAINT.to_html(false), "   ".join(SB.step_adds(sp))]
			var lab = menu._rich(line, 12, menu.TEXT)
			lab.set_meta("spell", sp["id"])
			if tune_on:
				var row := HBoxContainer.new()
				row.add_theme_constant_override("separation", 6)
				menu.box.add_child(row)
				var cur := String(bd.tunes.get(sp["id"], ""))
				row.add_child(menu._small_label(SB.TEXT["tune_title"], col))
				for mode in [""] + SB.TUNE_ORDER:
					var name: String = SB.TEXT["tune_none"] if mode == "" else String(SB.TUNE[mode]["name"])
					var b: Button = menu._button(name, _tune.bind(menu, String(sp["id"]), mode), row)
					b.set_meta("tune", [sp["id"], mode])
					b.tooltip_text = "" if mode == "" else String(SB.TUNE[mode]["desc"])
					b.disabled = not train
					if cur == mode:
						menu._primary(b)
	if tune_on:
		if train:
			menu._note(SB.TEXT["tune_cost"] % [int(SB.TUNE_COST), int(SB.crystals_held(prof))])
		else:
			menu._note(SB.TEXT["tune_only_train"])
	# A change of path.
	menu._section(SB.TEXT["path_title"])
	if prof.path == "":
		menu._note(SB.TEXT["path_none"])
	else:
		menu._note(SB.TEXT["path_line"] % [int(prof.flow), int(SB.PATH_CHANGE_COST)])
		var row2: HBoxContainer = menu._row()
		var armed: bool = Time.get_ticks_msec() - int(menu.get_meta("path_armed", -99999)) < ARM_MS
		var b2: Button = menu._button(SB.TEXT["path_confirm"] if armed else "Let your %s go" % Secret.display(prof.path), _path.bind(menu), row2)
		b2.set_meta("path_change", true)
		b2.disabled = not train
		if not train:
			row2.add_child(menu._small_label(SB.TEXT["path_only_train"], menu.FAINT))
	if menu.has_meta("path_drain") and Time.get_ticks_msec() - int(menu.get_meta("path_drain").get("t0", 0)) > 6000:
		menu.remove_meta("path_drain")
	if menu.has_meta("path_drain"):
		var dv := Drain.new()
		dv.info = menu.get_meta("path_drain")
		dv.custom_minimum_size = Vector2(0, 110)
		menu.box.add_child(dv)


static func _ring_key(main) -> String:
	if main.touch_active:
		return "Tools"
	if main.pad_active:
		return "%s + %s" % [main.Controls.pad_name("lb", main.pad_ps), main.Controls.pad_name("lt", main.pad_ps)]
	return "B"


static func _tune(menu, spell_id: String, mode: String) -> void:
	var main = menu.main
	var why := SB.set_tune(main.profile, spell_id, mode)
	menu.toast = why
	menu.toast_t = 3.0
	if why == "":
		main.profile.save()
		main._give_bonds()
		main.sfx("glint", 1.1, -4.0, 0.0)
		var told: String = main.tip_now("tool_tune")
		if told != "":
			menu.toast = told
	menu.open("climber", menu.opened_direct)


## The Developer lets the path go (a second press confirms): all its flow
## flows out of the shadow (drawn on the page), and a new path starts from nothing.
static func _path(menu) -> void:
	var main = menu.main
	var prof = main.profile
	if not main.on_train or prof.path == "" or SB.bond_of(prof) != "developer":
		return
	if Time.get_ticks_msec() - int(menu.get_meta("path_armed", -99999)) >= ARM_MS:
		menu.set_meta("path_armed", Time.get_ticks_msec())
		menu.open("climber", menu.opened_direct)
		return
	menu.remove_meta("path_armed")
	if not SB.spend_crystals(prof, SB.PATH_CHANGE_COST):
		menu.toast = "Needs %d crystal essence (you hold %d)" % [int(SB.PATH_CHANGE_COST), int(SB.crystals_held(prof))]
		menu.toast_t = 3.0
		menu.open("climber", menu.opened_direct)
		return
	var was: String = prof.path
	var step: int = prof.flow_step()
	main.reset_path()
	menu.set_meta("path_drain", {"path": was, "step": step, "t0": Time.get_ticks_msec()})
	menu.toast = SB.TEXT["path_done"] % Secret.display(was)
	var told: String = main.tip_now("tool_path")
	if told != "":
		menu.toast += "  " + told
	menu.toast_t = 4.0
	main.sfx("crit", 0.5, -4.0, 0.0)
	menu.open("climber", menu.opened_direct)


## The dev tools' section: grant each secret bond at depth 1 or 2, or clear it.
static func dev_section(menu) -> void:
	var main = menu.main
	var prof = main.profile
	menu._section("Secret bonds (the core mark)")
	var bond := SB.bond_of(prof)
	var row: HBoxContainer = menu._row()
	row.add_child(menu._label("%s" % (SB.TEXT["depth"] % [SB.display(bond), SB.depth_of(prof)] if bond != "" else "none"), 170.0, menu.GOLD if bond != "" else menu.DIM))
	var grid: GridContainer = menu._grid(3, 6)
	for id in SB.ORDER:
		for d in range(1, SB.CAP + 1):
			var b: Button = menu._button("%s %d" % [SB.display(id), d], _dev_grant.bind(menu, id, d), grid)
			b.disabled = bond == id and SB.depth_of(prof) == d
	var row2: HBoxContainer = menu._row()
	var cb: Button = menu._button("Clear the secret bond", _dev_clear.bind(menu), row2)
	cb.disabled = bond == ""
	menu._button("+60 essence, +10 flow carried", _dev_carry.bind(menu), row2)
	menu._button("+40 crystal essence", _dev_crystals.bind(menu), row2)


static func _dev_grant(menu, id: String, depth: int) -> void:
	var main = menu.main
	SB.grant(main.profile, id, depth)
	main.profile.save()
	main._give_bonds()
	menu.toast = "%s, depth %d" % [SB.display(id), depth]
	menu.toast_t = 2.0
	menu.open("dev")


static func _dev_clear(menu) -> void:
	var main = menu.main
	SB.clear(main.profile)
	main.profile.save()
	main._give_bonds()
	if main.secret_tools != null:
		main.secret_tools._new_floor()
	menu.open("dev")


static func _dev_carry(menu) -> void:
	var main = menu.main
	var kind: String = main.tower_data()["essence"]
	main.run_essence[kind] = float(main.run_essence.get(kind, 0.0)) + 60.0
	if main.profile.path != "":
		main.run_flow += 10.0
	menu.toast = "Carrying more essence"
	menu.toast_t = 2.0
	menu.open("dev")


static func _dev_crystals(menu) -> void:
	var main = menu.main
	main.profile.add_crystal(main.tower_data()["essence"], 40.0)
	main.profile.save()
	menu.toast = "+40 crystal essence"
	menu.toast_t = 2.0
	menu.open("dev")


## The path flowing out: the shadow fades and its essence streams up and away
## (a couple of seconds after the change).
class Drain extends Control:
	var info := {}

	func _process(_d: float) -> void:
		queue_redraw()

	func _draw() -> void:
		var t := (Time.get_ticks_msec() - int(info.get("t0", 0))) / 1000.0
		var k := clampf(1.0 - t / 2.6, 0.0, 1.0)
		var path: String = info.get("path", "life")
		var col := Secret.color(path)
		var c := Vector2(size.x * 0.5, size.y - 22.0)
		var b := Draw.Batch.new()
		if k > 0.0:
			Secret.draw_shadow(b, c, 26.0, path, int(info.get("step", 1)), t, k, 0.35)
		for i in 26:
			var ph := fposmod(t * 0.7 + float(i) * 0.137, 1.0)
			var a := (1.0 - ph) * clampf(1.6 - t / 2.0, 0.0, 1.0)
			if a <= 0.0:
				continue
			var x := c.x + sin(float(i) * 2.3) * 34.0 * (1.0 - ph * 0.4)
			var pos := Vector2(x, c.y - ph * (size.y - 30.0))
			b.dot(pos, 2.2 - ph, Color(col.lightened(0.3), a))
		b.flush(self)
		if t < 4.0:
			draw_string(ThemeDB.fallback_font, Vector2(0, 14), SB.TEXT["path_done"] % Secret.display(path), HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, Color(col, clampf(2.0 - t / 2.0, 0.3, 1.0)))
