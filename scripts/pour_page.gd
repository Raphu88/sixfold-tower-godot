extends RefCounted
## Crystals and tinctures (menu.gd's "pour" page): where you eat essence
## crystals and drink tinctures (essence_flow.gd), in a climb or on the train.
##
## On the left your crystals (one of each kind) and your tinctures (on your
## belt in a climb, packed for your next climb on the train); choose one and
## its card shows on the right. A crystal's card says how its essence flows
## when eaten (the natural way: your body and your marks share it, no
## steering) and has Eat. A tincture's card lists your six body parts: each
## mark (its step, and whether the tincture is its own kind) and each
## unmarked part (how full it is); press one to drink the tincture into it.
##
## FORCING (forcing.gd): when a mark or Node is full, "Force it" shows
## beside Eat (and, for the Unbound, beside a full Node on a tincture's
## card). It always asks first (menu.gd ask), saying where the strain would
## leave the part; Cancel does nothing.
##
## It opens from the climber's book (the Essence ribbon), from using a
## tincture on your belt (items.gd use), from a tincture's card in Your
## Car's Loadout and at the Workshop's tincture counter. Back goes where it
## came from. Mouse, keys, controller and touch work as in the inventory
## (menu.gd _slot and its card). Every word is in essence_flow.gd TEXT.

const Flow := preload("res://scripts/essence_flow.gd")
const Items := preload("res://scripts/items.gd")
const Essence := preload("res://scripts/essence.gd")
const Bonds := preload("res://scripts/bonds.gd")
const Train := preload("res://scripts/train.gd")
const UI := preload("res://scripts/ui.gd")
const Entity := preload("res://scripts/entity.gd")
const Guide := preload("res://scripts/guide.gd")
const Unbound := preload("res://scripts/unbound.gd")
const ProfileScript := preload("res://scripts/profile.gd")
const Forcing := preload("res://scripts/forcing.gd")

var m  # the menu (menu.gd)
## Where the page was opened from: "climber" (the book), "loadout", "train"
## (the Workshop), or "play" (a tincture used from the belt). Back returns there.
var from := "climber"
## The Entity's words at the top of the page (a first-time moment), kept
## while the page rebuilds.
var said := ""


func _init(menu) -> void:
	m = menu


func _prof():
	return m.main.profile


func _small() -> bool:
	return m.compact()


func _cell() -> float:
	return 46.0 if _small() else 54.0


## The selection the page starts on: a tincture you hold, else your biggest crystal.
func default_sel() -> String:
	for id in Flow.tinctures():
		if m.main.tincture_count(id) > 0:
			return "tincture:" + id
	var best := ""
	var most := 0.0
	for k in Essence.KINDS:
		var have: float = _prof().crystal_total(k)
		if have > most:
			most = have
			best = k
	return "crystal:" + (best if best != "" else String(Essence.KINDS.keys()[0]))


# --- the page ------------------------------------------------------------------------

func build() -> void:
	var prof = _prof()
	m._header(Flow.TEXT["title"], "" if _small() else Flow.TEXT["sub"], Flow.TEXT["eyebrow"])
	if said != "":
		var e := Entity.says(said, 34.0 if _small() else 42.0)
		e.set_meta("entity", "pour")
		m.box.add_child(e)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12 if _small() else 20)
	m.box.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	row.add_child(left)
	var keys: Array = []
	m._section(Flow.TEXT["crystals_head"], left)
	var cg := GridContainer.new()
	cg.columns = 6 if not _small() else 3
	cg.add_theme_constant_override("h_separation", 6)
	cg.add_theme_constant_override("v_separation", 4)
	left.add_child(cg)
	for kind in Essence.KINDS:
		var s = m._slot(cg, "crystal:" + kind, _cell(), Essence.display(kind))
		s.kind = "crystal"
		s.id = kind
		s.count = int(prof.crystal_total(kind))
		s.empty = prof.crystal_count(kind) <= 0
		s.tint = Essence.color(kind)
		keys.append(s.get_meta("slot"))
	m._section(Flow.TEXT["tinctures_head"], left)
	var held: Array = Flow.tinctures().filter(func(id): return m.main.tincture_count(id) > 0)
	if held.is_empty():
		var l := Label.new()
		l.text = Flow.TEXT["tinctures_none" if m.main.on_train else "tinctures_none_play"]
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 6.0 * (_cell() + 6.0) if not _small() else 3.0 * (_cell() + 6.0)
		l.add_theme_font_size_override("font_size", UI.SIZE_BODY)
		l.add_theme_color_override("font_color", UI.DIM)
		left.add_child(l)
	else:
		var tg := GridContainer.new()
		tg.columns = 6 if not _small() else 3
		tg.add_theme_constant_override("h_separation", 6)
		left.add_child(tg)
		for id in held:
			var s = m._slot(tg, "tincture:" + id, _cell(), Essence.display(Flow.tincture_kind(id)))
			s.kind = "item"
			s.id = id
			s.count = m.main.tincture_count(id)
			keys.append(s.get_meta("slot"))
	# The card, the whole height on the right.
	var dpanel := PanelContainer.new()
	dpanel.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.025), UI.SLOT_EDGE, 8, 1, 12.0 if _small() else 14.0))
	dpanel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dpanel.custom_minimum_size.x = 280.0 if not _small() else 250.0
	row.add_child(dpanel)
	m.details = VBoxContainer.new()
	m.details.add_theme_constant_override("separation", 4 if _small() else 6)
	dpanel.add_child(m.details)
	if not (m.inv_sel in keys):
		m.inv_sel = default_sel()
		if not (m.inv_sel in keys):
			m.inv_sel = keys[0]
	m._show_details(m.inv_sel)
	if said == "" and _shows_force():
		var first := Guide.tell("forcing")  # (the first time Force it shows: the Entity explains)
		if first != "":
			said = first
			var fe := Entity.says(said, 34.0 if _small() else 42.0)
			fe.set_meta("entity", "pour")
			m.box.add_child(fe)
			m.box.move_child(fe, row.get_index())
	m._footer()


## True while the card shows a Force it button.
func _shows_force() -> bool:
	if m.details == null or not is_instance_valid(m.details):
		return false
	return m.details.find_children("*", "Button", true, false).any(func(b): return b.has_meta("force_part"))


## The card for a crystal or a tincture (menu.gd _show_details sends it here).
func details(key: String) -> void:
	var kind := key.get_slice(":", 0)
	var arg := key.get_slice(":", 1)
	match kind:
		"crystal":
			_crystal_card(arg)
		"tincture":
			_tincture_card(arg)
	if m.toast != "":
		m._detail_text(m.toast, UI.GOLD)


func _crystal_card(k: String) -> void:
	var prof = _prof()
	var col: Color = Essence.color(k)
	m._detail_head("crystal", k, Items.CRYSTAL["name"] % Essence.display(k), col)
	var held := int(prof.crystal_total(k))
	if held <= 0:
		m._detail_text(Flow.TEXT["none_crystal"] % Essence.display(k), UI.DIM)
		m._detail_text(Items.CRYSTAL["none"], UI.FAINT)
		return
	m._detail_text(Flow.TEXT["crystal_card"] % [held, Essence.display(k)], UI.TEXT)
	var step := mini(int(Items.CRYSTAL["step"]), held)
	var sh: Dictionary = Flow.shares(0.0)
	if Unbound.is_on(prof):
		m._detail_text(Flow.TEXT["crystal_flow_raw"] % [step, Unbound.node_name(Unbound.part_for(prof, k))], UI.DIM)
	elif prof.bonds.is_empty():
		m._detail_text(Flow.TEXT["crystal_flow_body"] % step, UI.DIM)
	else:
		m._detail_text(Flow.TEXT["crystal_flow"] % [step, int(round(float(sh["body"]) * 100.0)), int(round(float(sh["marks"]) * 100.0))], UI.DIM)
	# Eat, then each Force it under it, each the card's full width: a row
	# that wraps would give each only its smallest width (with keep_text,
	# its padding: an empty sliver), and a mark's name needs the room.
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	m.details.add_child(row)
	var b: Button = m._button(Flow.TEXT["eat"] % step, _eat.bind(k), row)
	b.set_meta("help", "pour:eat")
	UI.keep_text(b)
	m._primary(b)
	# Full: Force it, beside Eat (forcing.gd). It asks first.
	var full: Array = Forcing.targets(prof, k)
	for part in full:
		var fb: Button = m._button(force_text(part), _ask_force.bind("crystal", k, part, float(step)), row)
		fb.set_meta("help", "pour:force")
		fb.set_meta("force_part", part)
		UI.keep_text(fb)
	if not full.is_empty():
		m._detail_text(Forcing.TEXT["force_head"] % int(round(float(Forcing.FORCE["cost"]))), UI.FAINT)


func _tincture_card(id: String) -> void:
	var prof = _prof()
	var kind := Flow.tincture_kind(id)
	if kind == "":
		return
	var col: Color = Items.color(id)
	m._detail_head("item", id, String(Items.ITEMS[id]["name"]), col)
	var n: int = m.main.tincture_count(id)
	m._detail_text(Flow.TEXT["tincture_card"] % [int(Flow.TINCTURE["essence"]), Essence.display(kind)], UI.TEXT)
	m._detail_text(Flow.TEXT["tincture_have"] % [n, Flow.TEXT["packed" if m.main.on_train else "on_belt"]], UI.DIM)
	var grid := GridContainer.new()
	grid.columns = 1
	grid.add_theme_constant_override("v_separation", 2 if _small() else 4)
	m.details.add_child(grid)
	for part in Bonds.PARTS:
		# (a full Node: Force it beside it, forcing.gd; a mark always takes a tincture)
		var forceable: bool = n > 0 and Unbound.is_on(prof) and Forcing.can_force(prof, part, kind)
		var at: Node = grid
		if forceable:
			var hb := HBoxContainer.new()
			hb.add_theme_constant_override("separation", 6)
			hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			grid.add_child(hb)
			at = hb
		var b: Button = m._button(target_text(part, kind), _drink.bind(id, part), at)
		b.set_meta("help", "pour:mark" if prof.bonds.has(part) and not Unbound.is_on(prof) else "pour:part")
		b.set_meta("pour_part", part)
		b.custom_minimum_size.y = 28.0 if _small() else 36.0
		b.disabled = n <= 0
		UI.keep_text(b)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if forceable:
			b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var fb: Button = m._button(force_text(part, true), _ask_force.bind("tincture", id, part, float(Flow.TINCTURE["essence"])), at)
			fb.set_meta("help", "pour:force")
			fb.set_meta("force_part", part)
			fb.custom_minimum_size.y = b.custom_minimum_size.y
			fb.size_flags_horizontal = Control.SIZE_EXPAND_FILL  # (it shares the row with the part's button: not squeezed to a sliver)
			fb.size_flags_stretch_ratio = 0.7
			UI.keep_text(fb)


## A target's words: a mark (its bond, its step, its own kind or not) or an
## unmarked part (how full), or for the Unbound the part's level.
func target_text(part: String, kind: String) -> String:
	var prof = _prof()
	var name := String(Bonds.PART_NAMES[part])
	if Unbound.is_on(prof):
		return Flow.TEXT["target_raw"] % [Unbound.node_name(part), Unbound.level(prof, part)] if Unbound.awake(prof, part) else Flow.TEXT["target_asleep"] % Unbound.node_name(part)
	if prof.bonds.has(part):
		var info: Dictionary = prof.bonds[part]
		var bd: Dictionary = Bonds.BONDS.get(String(info["id"]), {})
		var step := ProfileScript.step_for_xp(float(info["xp"]))
		if step >= ProfileScript.STEP_XP.size():
			return Flow.TEXT["target_top"] % [name, bd.get("name", "")]
		var fmt := "target_mark_own" if String(bd.get("affinity", "")) == kind else "target_mark"
		return Flow.TEXT[fmt] % [name, bd.get("name", ""), step]
	var pct: int = prof.soak_pct(part)
	if pct >= 100:
		return Flow.TEXT["target_full"] % name
	return Flow.TEXT["target_soak"] % [name, pct]


## A Force it button's words: the mark it forces (the marked), and the
## part's step when it isn't steady ("Force it: Stormcaller  ·  strained").
func force_text(part: String, short := false) -> String:
	var prof = _prof()
	var t := String(Forcing.TEXT["tincture_force" if short else "force"])
	if not short and not Unbound.is_on(prof) and prof.bonds.has(part):
		t = String(Forcing.TEXT["force_mark"]) % String(Bonds.BONDS.get(String(prof.bonds[part]["id"]), {}).get("name", Bonds.PART_NAMES[part]))
	var r: int = Forcing.rung(prof, part, m.main)
	if r > Forcing.STEADY:
		t = String(Forcing.TEXT["force_state"]) % [t, Forcing.rung_word(r)]
	return t


# --- actions -------------------------------------------------------------------------

## Force it asks first (the shared pop-up): what it would grow, and where
## the strain would leave the part. Cancel does nothing. `src` "crystal"
## (`arg` its kind) or "tincture" (`arg` its id).
func _ask_force(src: String, arg: String, part: String, amount: float) -> void:
	var prof = _prof()
	var kind := arg if src == "crystal" else Flow.tincture_kind(arg)
	if src == "crystal":
		amount = minf(amount, prof.crystal_total(kind))
	if amount <= 0.0 or not Forcing.can_force(prof, part, kind):
		return
	var pv: Dictionary = Forcing.preview(prof, part, kind, amount, m.main)
	m.ask(Forcing.ask_text(prof, part, kind, amount, m.main), Forcing.TEXT["ask_confirm"], _force.bind(src, arg, part), int(pv["after"]) >= Forcing.BURNED, Forcing.TEXT["ask_title"])


func _force(src: String, arg: String, part: String) -> void:
	var lines: Array = m.main.force_crystal(arg, part) if src == "crystal" else m.main.force_tincture(arg, part)
	var first := Guide.tell("forcing")
	if first != "":
		said = first
	_done(lines)


func _eat(kind: String) -> void:
	var lines: Array = m.main.consume_crystal(kind)
	var first := Guide.tell("crystal_eat")
	if first != "":
		said = first
	_done(lines)


func _drink(id: String, part: String) -> void:
	var lines: Array = m.main.drink_tincture(id, part)
	var first := Guide.tell("tincture")
	if first != "":
		said = first
	_done(lines)


func _done(lines: Array) -> void:
	m.toast = "  ".join(lines) if not lines.is_empty() else ""
	m.toast_t = 4.0
	m._want_focus = {"meta": "slot", "value": m.inv_sel}
	m.open("pour", m.opened_direct)


## Where Back goes from here.
func back() -> void:
	said = ""
	match from:
		"climber":
			m.open("climber", m.opened_direct)
		"loadout":
			m.open("loadout", true)
		"inventory":
			m.open("inventory", m.opened_direct)
		"train":
			m.open("train")
		_:
			m.close()
