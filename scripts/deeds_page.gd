extends RefCounted
## The book's Deeds ribbon (menu.gd climber page): two leaves, chosen with
## the buttons at its top.
##   Deeds          the 36 deeds (deeds.gd) in their six kinds, each with a
##                  medal (bright once done), what it asks, how far along it
##                  is and the renown it pays.
##   Summit Blades  the six blades (summit_blades.gd): hidden, found or
##                  bonded, each bonded one's power and awakening; on the
##                  train, Carry and Awaken.
## Built with menu.gd's own helpers, so mouse, keys, controller and touch
## all work; every button has the Entity's help (entity_help.gd "deeds_*").

const Deeds := preload("res://scripts/deeds.gd")
const SummitBlades := preload("res://scripts/summit_blades.gd")
const Essence := preload("res://scripts/essence.gd")
const Towers := preload("res://scripts/towers.gd")
const UI := preload("res://scripts/ui.gd")
const Draw := preload("res://scripts/draw_util.gd")

## The leaf shown ("deeds" or "blades"), kept while the game runs.
static var leaf := "deeds"
## The last thing said after a button (a toast under the leaf's buttons).
static var said := ""


static func build(m) -> void:
	var prof = m.main.profile
	m._entity_says("deeds" if leaf == "deeds" else "blades", Deeds.TEXT["page_title"].to_upper() if leaf == "deeds" else SummitBlades.TEXT["page_title"].to_upper())
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	m.box.add_child(row)
	for t in [["deeds", Deeds.TEXT["tab_deeds"]], ["blades", Deeds.TEXT["tab_blades"]]]:
		var b: Button = m._button(t[1], _set_leaf.bind(m, t[0]), row)
		b.custom_minimum_size = Vector2(150.0 if m.compact() else 170.0, 34.0)
		b.set_meta("help", "deeds_leaf_" + t[0])
		b.set_meta("deeds_leaf", t[0])
		m._tab_look(b, leaf == t[0])
	if said != "":
		var l: Label = m._label(said, 0.0, UI.GOLD)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		m.box.add_child(l)
		said = ""
	if leaf == "blades":
		_blades(m, prof)
	else:
		_deeds(m, prof)


static func _set_leaf(m, id: String) -> void:
	leaf = id
	m.open("climber", m.opened_direct)


# --- the deeds -----------------------------------------------------------------------------------

static func _deeds(m, prof) -> void:
	var head: Label = m._label(Deeds.TEXT["page_sub"] % [Deeds.done_count(prof), Deeds.ORDER.size(), Deeds.renown_earned(prof), Deeds.renown_total()], 0.0, UI.DIM)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	m.box.add_child(head)
	var grid := GridContainer.new()
	grid.columns = 1 if m.compact() else 2
	grid.add_theme_constant_override("h_separation", 26)
	grid.add_theme_constant_override("v_separation", 6)
	m.box.add_child(grid)
	var width: float = maxf(260.0, (m._page_width() - 90.0) / float(grid.columns))
	for k in Deeds.KINDS:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(col)
		var kc: Color = k[2]
		var done := Deeds.of_kind(k[0]).filter(func(id): return Deeds.is_done(prof, id)).size()
		m._section("%s  ·  %d / %d" % [String(k[1]).to_upper(), done, Deeds.of_kind(k[0]).size()], col)
		for id in Deeds.of_kind(k[0]):
			col.add_child(_deed_row(m, prof, id, kc, width))


static func _deed_row(m, prof, id: String, kc: Color, width: float) -> Control:
	var d: Dictionary = Deeds.DEEDS[id]
	var done := Deeds.is_done(prof, id)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.set_meta("deed", id)
	var medal := Medal.new()
	medal.col = kc
	medal.done = done
	medal.custom_minimum_size = Vector2(26, 26)
	medal.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(medal)
	var words := VBoxContainer.new()
	words.add_theme_constant_override("separation", -3)
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	var name: Label = m._label(String(d["name"]), 0.0, kc.lightened(0.25) if done else UI.TEXT)
	UI.style_label(name, "display", 16 if m.compact() else 17, kc.lightened(0.25) if done else UI.TEXT)
	words.add_child(name)
	var pr := Deeds.progress(prof, id)
	var line := String(d["desc"])
	if done:
		line += "  ·  " + Deeds.TEXT["done"]
	elif int(pr[1]) > 1:
		line += "  ·  " + Deeds.TEXT["progress"] % [mini(int(pr[0]), int(pr[1])), int(pr[1])]
	var desc: Label = m._label(line, 0.0, UI.DIM if not done else Color(UI.DIM, 0.8))
	desc.add_theme_font_size_override("font_size", 13 if m.compact() else 14)
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size.x = maxf(150.0, width - 120.0)
	words.add_child(desc)
	var rn: Label = m._label(Deeds.TEXT["renown"] % int(d["renown"]), 34.0, UI.GOLD if done else UI.FAINT)
	rn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(rn)
	return row


# --- the Summit Blades -------------------------------------------------------------------------

static func _blades(m, prof) -> void:
	m._note(SummitBlades.TEXT["page_note"])
	var grid := GridContainer.new()
	grid.columns = 2 if m.compact() else 3
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	m.box.add_child(grid)
	var on_train: bool = m.main.on_train
	var card_w: float = maxf(220.0, (m._page_width() - 90.0) / float(grid.columns))
	for tower in SummitBlades.ORDER:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.03), UI.SLOT_EDGE, 6, 1, 8.0))
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.set_meta("blade", tower)
		grid.add_child(card)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		card.add_child(row)
		var bonded := SummitBlades.bonded(prof, tower)
		var found: bool = SummitBlades.state(prof)["found"].has(tower)
		var step := SummitBlades.level(prof, tower)
		var icon := BladeIcon.new()
		icon.tower = tower
		icon.lit = bonded
		icon.step = step
		icon.custom_minimum_size = Vector2(46, 72)
		icon.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		row.add_child(icon)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		var b: Dictionary = SummitBlades.BLADES[tower]
		var tname := String(Towers.TOWERS.get(tower, {}).get("name", tower))
		var title: Label = m._label(SummitBlades.blade_name(tower) if found or bonded else SummitBlades.TEXT["unknown"], 0.0, SummitBlades.color(tower) if bonded else UI.TEXT)
		UI.style_label(title, "display", 17, SummitBlades.color(tower) if bonded else (UI.TEXT if found else UI.DIM))
		col.add_child(title)
		var lines: Array = []
		if bonded:
			lines.append([SummitBlades.TEXT["name_line"] % [tname, Essence.display(String(b["kind"]))], Essence.color(String(b["kind"]))])
			lines.append([String(b["power"]) + " (%s)." % _num(SummitBlades.strength(prof, tower)), UI.TEXT])
			lines.append([SummitBlades.TEXT["step"] % [step, SummitBlades.AWAKEN.size()], UI.GOLD])
		elif found:
			lines.append([SummitBlades.TEXT["not_bonded"], UI.DIM])
			lines.append([String(b["power"]) + ".", UI.FAINT])
		else:
			lines.append([SummitBlades.TEXT["unknown_line"] % tname, UI.DIM])
			if SummitBlades.has_lead(prof, tower):
				lines.append([SummitBlades.TEXT["lead_line"], UI.GOLD])
		if String(b.get("history", "")).strip_edges() != "" and bonded:
			lines.append([String(b["history"]), UI.FAINT])
		for ln in lines:
			var l: Label = m._label(String(ln[0]), 0.0, ln[1])
			l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			l.custom_minimum_size.x = maxf(140.0, card_w - 80.0)
			l.add_theme_font_size_override("font_size", 13 if m.compact() else 14)
			col.add_child(l)
		if not bonded:
			continue
		if SummitBlades.worn(prof) == tower:
			col.add_child(m._label(SummitBlades.TEXT["carried"], 0.0, SummitBlades.color(tower)))
		elif on_train:
			var cb: Button = m._button(SummitBlades.TEXT["carry"], _carry.bind(m, tower), col)
			cb.set_meta("help", "deeds_carry")
		if on_train:
			var cost := SummitBlades.awaken_cost(prof, tower)
			if cost.is_empty():
				col.add_child(m._label(SummitBlades.TEXT["awaken_full"], 0.0, UI.GOLD))
			else:
				var kind: String = cost.keys()[0]
				var ab: Button = m._button(SummitBlades.TEXT["awaken"] % (step + 1) + "  ·  " + SummitBlades.TEXT["awaken_cost"] % [int(cost[kind]), Essence.display(kind)], _awaken.bind(m, tower), col)
				ab.set_meta("help", "deeds_awaken")
				UI.keep_text(ab)
				var why := SummitBlades.awaken_why(prof, tower)
				if why != "":
					ab.disabled = true
					var wl: Label = m._label(why, 0.0, UI.FAINT)
					wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
					wl.custom_minimum_size.x = maxf(140.0, card_w - 80.0)
					wl.add_theme_font_size_override("font_size", 13)
					col.add_child(wl)
		elif step < SummitBlades.AWAKEN.size():
			col.add_child(m._label(SummitBlades.TEXT["on_train_only"], 0.0, UI.FAINT))


static func _num(v: float) -> String:
	return "%d" % int(round(v)) if absf(v - round(v)) < 0.05 else "%.1f" % v


static func _carry(m, tower: String) -> void:
	SummitBlades.carry(m.main.profile, tower)
	m.feedback("choose", "equip_sword")  # (its sound, and a flash on the button)
	said = SummitBlades.TEXT["carried"] + ": " + SummitBlades.blade_name(tower)
	m.open("climber", m.opened_direct)


static func _awaken(m, tower: String) -> void:
	var why := SummitBlades.awaken(m.main.profile, tower)
	if why == "":
		m.feedback("make", "craft_rune")
		said = SummitBlades.TEXT["woke"] % [SummitBlades.blade_name(tower), SummitBlades.level(m.main.profile, tower)]
		m.main.tip_now("summit_awaken", false)
	else:
		said = why
	m.open("climber", m.opened_direct)


## A deed's medal: a disc on a short ribbon, bright in its kind's colour once done.
class Medal extends Control:
	var col := Color.WHITE
	var done := false

	func _draw() -> void:
		var c := size * 0.5 + Vector2(0, 2)
		var r := minf(size.x, size.y) * 0.34
		var ribbon := col.darkened(0.3) if done else Color(0.3, 0.28, 0.3)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-r * 0.8, -r * 2.2), c + Vector2(-r * 0.1, -r * 2.2), c + Vector2(r * 0.4, -r * 0.6), c + Vector2(-r * 0.3, -r * 0.6)]), ribbon)
		draw_colored_polygon(PackedVector2Array([c + Vector2(r * 0.8, -r * 2.2), c + Vector2(r * 0.1, -r * 2.2), c + Vector2(-r * 0.4, -r * 0.6), c + Vector2(r * 0.3, -r * 0.6)]), ribbon.darkened(0.15))
		draw_circle(c, r + 1.5, Color(0.06, 0.05, 0.07))
		draw_circle(c, r, col if done else Color(0.22, 0.2, 0.23))
		draw_arc(c, r * 0.7, 0.0, TAU, 20, Color(1, 1, 1, 0.35) if done else Color(1, 1, 1, 0.08), 1.0)
		if done:
			# A six-pointed star struck in it.
			var pts := PackedVector2Array()
			for i in 12:
				pts.append(c + Vector2.from_angle(-PI * 0.5 + i * PI / 6.0) * (r * (0.55 if i % 2 == 0 else 0.26)))
			draw_colored_polygon(pts, col.lightened(0.5))


## A Summit Blade on the book's page (summit_blades.gd icon_into).
class BladeIcon extends Control:
	var tower := ""
	var lit := false
	var step := 0

	func _draw() -> void:
		var b := Draw.Batch.new()
		SummitBlades.icon_into(b, size * 0.5 + Vector2(0, -4), minf(size.x, size.y * 0.6) * 0.9, tower, lit, step)
		b.flush(self)
