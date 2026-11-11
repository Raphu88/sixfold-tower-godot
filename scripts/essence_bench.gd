extends RefCounted
## THE ESSENCE BENCH: where the Unbound build their techniques, in the
## Workshop car (train_page.gd _workshop: its own drawer beside the gear
## bench's counters). Everything is drawn in code:
##
##   VIALS     one for each essence you can use, with a brass tap. The liquid
##             is how much of that essence has pooled in your body (ticks on
##             the glass mark where its effects open). Open taps in order:
##             the first leads (its colour fills most of the globe), the
##             second and third swirl in thinner. Tap an open tap to close it.
##   MOULDS    the forms your tree has opened (the hand's Strike and Bolt,
##             Volley at level 3...). Choose one and its shape shows inside
##             the GLOBE, a brass-bound glass globe.
##   LAYERS    under the globe, each essence poured and its effect: tap to
##             change it to another effect that has opened for that essence.
##   FITTINGS  the variations, screwed onto the globe's spout (a three-pronged
##             splitter for Split, a coil for Chain, a little clock for
##             Delayed...): tap to screw one on, again to take it off.
##   GAUGE     the strain one cast adds (out of 100: a tick where a part runs hot).
##   PLAQUE    the technique's name and what it does in one line, and
##             "echoes X" when the mix comes close to a bond's spell.
## Locked vials, moulds and fittings sit dark. Pouring runs a short stream
## of liquid into the globe. "Set in slot" puts what's on the bench into
## the chosen slot (the six along the top, one per mark button).
##
## The bench works on a DRAFT (menu meta "bench_draft"), loaded from the
## chosen slot ("tech_slot", shared with the Techniques page in your car),
## so trying things never spoils a slot until you set it. Marked climbers
## see the bench, dark, with a line saying it's for the Unbound.
##
## Every control is a Button in the car (so the keys, a controller, the
## mouse and a tap all work as on the rest of the train: nav.gd), and it
## reflows at every Interface size like every car (reflow.gd).

const Unbound := preload("res://scripts/unbound.gd")
const Tech := preload("res://scripts/technique.gd")
const Library := preload("res://scripts/library.gd")
const TreeRules := preload("res://scripts/tree.gd")
const UI := preload("res://scripts/ui.gd")
const Art := preload("res://scripts/train_art.gd")
const Secret := preload("res://scripts/secret.gd")

## The Workshop car's counter id for the bench (menu.gd train_bench).
const COUNTER := "essence"
## How long the liquid runs into the globe after a tap opens (seconds).
const POUR_TIME := 0.9
## A vial is full at this much pooled (the last effect opens at 600).
const VIAL_FULL := 700.0

static var TEXT := {
	"drawer": "Essence bench",
	"drawer_short": "Essence",
	"counters": "‹ Counters",
	"title": "The essence bench",
	"for_unbound": "The essence bench is for the Unbound: those who refused the mark pour their own techniques here. Your marks grow on their own.",
	"essences": "Essences",
	"moulds": "Moulds",
	"fittings": "Fittings",
	"slot": "%s  %s",
	"slot_empty": "empty",
	"set": "Set in slot %s",
	"set_short": "Set in slot",
	"in_slot": "In its slot",
	"empty": "Open a tap",
	"empty_line": "Choose a mould, then open a tap: the first essence leads.",
	"lead": "leads",
	"strain": "+%d strain",
	"fill": "full at %d  ·  %s",
	"unsaved": "not set yet",
	"echoes": "Echoes %s: %s",
	"layer": "%s: %s",
	"not_path": "not your path",
	"needs_level": "%s level %d to pour %d",
	"form_locked": "level %d",
	"fitting_locked": "Not yours yet: it grows on a body part's tree.",
	"effect_locked": "%s opens at %d %s pooled",
	"set_done": "%s set on %s",
	"set_echo": "%s set on %s. Found an echo: %s",
	"cant": "Can't: %s",
	"more_kinds": "%s combines %d at most",
	"found": "Echoes found: %d of %d",
	"one_line": "%s: %s",
	"touch": "; a touch of %s",
}
## Each variation's fitting, as it is drawn on the spout.
const FITTING_ORDER := ["wide", "long", "quick", "split", "lingering", "chain", "delayed", "mirrored", "echo", "charged"]


# --- the draft and its rules (no drawing: the tests use these) ----------------------

static func can_use(prof) -> bool:
	return Unbound.is_on(prof)


static func slot(menu) -> int:
	return clampi(int(menu.get_meta("tech_slot", 0)), 0, Unbound.PARTS.size() - 1)


## The technique on the bench (loaded from the chosen slot the first time).
static func draft(menu) -> Dictionary:
	var sel := slot(menu)
	if not menu.has_meta("bench_draft") or int(menu.get_meta("bench_from", -1)) != sel:
		load_slot(menu, sel)
	return menu.get_meta("bench_draft")


## Puts slot `i`'s technique on the bench.
static func load_slot(menu, i: int) -> void:
	var prof = menu.main.profile
	var techs: Array = Unbound.state(prof)["techs"]
	var t = techs[i] if i < techs.size() else {}
	var d: Dictionary = t.duplicate(true) if Tech.valid(t) else {"name": "", "part": Unbound.PARTS[i], "shape": Library.BASE_FORMS[Unbound.PARTS[i]][0], "kinds": []}
	menu.set_meta("tech_slot", i)
	menu.set_meta("bench_draft", d)
	menu.set_meta("bench_from", i)


static func set_draft(menu, d: Dictionary) -> void:
	menu.set_meta("bench_draft", d)
	menu.set_meta("bench_from", slot(menu))


## True if what's on the bench differs from its slot.
static func dirty(menu) -> bool:
	var prof = menu.main.profile
	var t = Unbound.state(prof)["techs"][slot(menu)]
	var d := draft(menu)
	if not Tech.valid(t):
		return Tech.valid(d)
	for k in ["part", "shape", "kinds"]:
		if str(t.get(k)) != str(d.get(k)):
			return true
	return str(Tech.variations(t)) != str(Tech.variations(d)) or str(_fx_of(t)) != str(_fx_of(d))


static func _fx_of(t: Dictionary) -> Dictionary:
	var out := {}
	for k in t.get("kinds", []):
		var id := Tech.effect_of(t, String(k))
		if id != String(Library.BASE.get(String(k), "")):
			out[k] = id
	return out


## The kinds a climber can pour: the six, and their path's essence (the other
## secret essence shows dark once they have a path).
static func vial_kinds(prof) -> Array:
	var out: Array = ["fire", "water", "air", "stone", "iron", "blade"]
	if prof.path in Secret.ORDER:
		out.append_array(Secret.ORDER)
	return out


## Why a vial can't be opened now ("" if it can): not your path, or the
## part can't combine another.
static func vial_lock(prof, d: Dictionary, kind: String) -> String:
	if not can_use(prof):
		return TEXT["for_unbound"]
	if not kind in Unbound.kinds_for(prof):
		return TEXT["not_path"]
	if kind in d.get("kinds", []):
		return ""
	var part := String(d.get("part", "hand"))
	var most := Unbound.max_kinds(prof, part)
	if d.get("kinds", []).size() >= most:
		if most < Unbound.KINDS_AT.size():
			return TEXT["needs_level"] % [Unbound.PART_NAMES[part], int(Unbound.KINDS_AT[most]), most + 1]
		return TEXT["more_kinds"] % [Unbound.PART_NAMES[part], most]
	return ""


## A tap pressed: a closed one opens (its essence joins, after those
## already poured: the first leads); an open one closes (those after it move up).
static func pour(prof, d: Dictionary, kind: String) -> Dictionary:
	var out := d.duplicate(true)
	var kinds: Array = out.get("kinds", [])
	var at := kinds.find(kind)
	if at >= 0:
		kinds.remove_at(at)
		if out.get("effects") is Dictionary:
			out["effects"].erase(kind)
	elif vial_lock(prof, out, kind) == "":
		kinds.append(kind)
	else:
		return out
	out["kinds"] = kinds
	_unname(out)
	return out


## The forms on the moulds' rack: [part, form id, state, level]: "owned"
## (the tree has opened it), "locked" (written, opens at that part level).
## Forms not written yet aren't shown.
static func moulds(prof) -> Array:
	var out: Array = []
	for part in ["hand", "legs", "back", "throat", "brow", "heart"]:
		var owned: Array = TreeRules.owned_forms(prof, part) if can_use(prof) else Library.BASE_FORMS[part]
		for id in Library.forms_of(part):
			var f := Library.form(id)
			if not Library.built(f):
				continue
			out.append([part, id, "owned" if id in owned else "locked", int(f.get("opens", 1))])
	return out


## Choose a mould: its part and form (essences past the part's limit drop off).
static func set_form(prof, d: Dictionary, part: String, form: String) -> Dictionary:
	var out := d.duplicate(true)
	if not form in TreeRules.owned_forms(prof, part):
		return out
	var keep_name := String(out.get("name", "")) != "" and Tech.valid(out) and String(out["name"]) != Tech.auto_name(out)
	out["part"] = part
	out["shape"] = form
	var kinds: Array = out.get("kinds", [])
	var most := Unbound.max_kinds(prof, part)
	while kinds.size() > most:
		var gone = kinds.pop_back()
		if out.get("effects") is Dictionary:
			out["effects"].erase(gone)
	out["kinds"] = kinds
	if not keep_name:
		out["name"] = ""
	_unname(out)
	return out


## The effects open to an essence for this climber: its base, then each
## that has opened (enough pooled: tree.gd effect_open).
static func effects_for(prof, kind: String) -> Array:
	var out: Array = []
	for id in Library.effects_of(kind):
		if id == String(Library.BASE.get(kind, "")) or TreeRules.effect_open(prof, id):
			out.append(id)
	return out


## The next effect open to a poured essence.
static func cycle_effect(prof, d: Dictionary, kind: String) -> Dictionary:
	var out := d.duplicate(true)
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


## A fitting pressed: screwed on (in place of another), or taken off.
static func fit(prof, d: Dictionary, vid: String) -> Dictionary:
	var out := d.duplicate(true)
	if not vid in TreeRules.owned_variations(prof):
		return out
	if vid in Tech.variations(out):
		out.erase("vars")
	else:
		out["vars"] = [vid]
	_unname(out)
	return out


## A ready-made recipe's name goes once it's changed.
static func _unname(t: Dictionary) -> void:
	for id in Tech.RECIPES:
		if String(t.get("name", "")) == String(Tech.RECIPES[id]["name"]):
			t["name"] = ""


## The strain one cast adds (its essences, form, fitting and any echo).
static func strain(d: Dictionary) -> float:
	return Tech.strain(d) if Tech.valid(d) else 0.0


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


## Puts the draft into its slot. Remembers an echo found. True if set.
static func save(menu) -> bool:
	var main = menu.main
	var prof = main.profile
	var d := draft(menu)
	if not can_use(prof) or not Tech.valid(d):
		return false
	var sel := slot(menu)
	var t := d.duplicate(true)
	Unbound.state(prof)["techs"][sel] = t
	var found := TreeRules.note_echo(prof, t)
	prof.save()
	main._give_bonds()
	var key := _key_name(menu, sel)
	var where: String = key if key != "" else Unbound.PART_NAMES[Unbound.PARTS[sel]]
	menu.toast = TEXT["set_echo"] % [Tech.title(t), where, Library.echo_of(t)["name"]] if found else TEXT["set_done"] % [Tech.title(t), where]
	menu.toast_t = 4.0
	load_slot(menu, sel)
	return true


## The key that casts slot `i` ("" on a phone).
static func _key_name(menu, i: int) -> String:
	var main = menu.main
	var part: String = Unbound.PARTS[i]
	if main.touch_active:
		return ""
	if main.pad_active:
		return load("res://scripts/controls.gd").pad_name(load("res://scripts/controls.gd").PART_PAD[part], main.pad_ps, true)
	return String(main.BondScript.Bonds.PART_KEYS[part])


## From the Techniques page: to the Workshop, the bench open on slot `i`.
static func open_for(menu, i: int) -> void:
	load_slot(menu, i)
	menu.train_car = "workshop"
	menu.train_bench = COUNTER
	menu.inv_sel = ""
	menu.opened_direct = false
	menu.open("train")


# --- the car's things --------------------------------------------------------------

## The bench's drawer among the Workshop's counters (train_page.gd _workshop).
static func drawer(tp, parent: Node, size: Vector2, short: bool) -> Button:
	var m = tp.m
	var on: bool = m.train_bench == COUNTER
	var b: Button = m._button(TEXT["drawer_short"] if short else TEXT["drawer"], func(): tp._set_bench(COUNTER), parent)
	b.custom_minimum_size = size
	b.set_meta("bench_drawer", COUNTER)  # (not "bench_tab": the gear bench's counters keep their own list)
	b.add_theme_font_size_override("font_size", 15 if short else 16)
	tp._brass(b, on)
	if not can_use(m.main.profile):
		b.set_meta("greyed", true)
		b.add_theme_color_override("font_color", Color(UI.GOLD, 0.7) if on else UI.FAINT)
		b.add_theme_color_override("font_hover_color", UI.DIM)
	return b


## Builds the bench into the Workshop car's row.
static func build(tp, row: Node) -> void:
	var m = tp.m
	var main = m.main
	var prof = main.profile
	var small: bool = tp._small()
	var can := can_use(prof)
	var d: Dictionary = draft(m) if can else {"name": "", "part": "hand", "shape": "strike", "kinds": []}
	var top := BenchTop.new()
	top.small = small
	top.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(top)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4 if small else 8)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(col)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(head)
	if small:
		# A phone: the bench fills the car, and this goes back to the gear bench's counters.
		var back: Button = m._button(TEXT["counters"], func(): tp._set_bench("brew"), head)
		back.custom_minimum_size = Vector2(0, 32)
		back.add_theme_font_size_override("font_size", 13)
		back.set_meta("bench_drawer", "brew")
		tp._brass(back, false)
	tp._tag(head, TEXT["title"])
	if can:
		var found: int = TreeRules.state(prof)["echoes"].size()
		var fl := Label.new()
		fl.text = TEXT["found"] % [found, Library.ECHOES.size()]
		fl.add_theme_font_size_override("font_size", 12 if small else 13)
		fl.add_theme_color_override("font_color", Color(0.79, 0.65, 1.0, 0.85))
		fl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		head.add_child(fl)
	else:
		var note: Label = tp._note(col, TEXT["for_unbound"], 380.0 if not small else 300.0)
		note.add_theme_color_override("font_color", UI.GOLD)
		note.set_meta("bench_marked", true)
	# The six slots, one per mark button.
	var slots := HBoxContainer.new()
	slots.add_theme_constant_override("separation", 4)
	slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(slots)
	var techs: Array = Unbound.state(prof)["techs"]
	var sel := slot(m)
	for i in Unbound.PARTS.size():
		var t = techs[i] if i < techs.size() else {}
		var key := _key_name(m, i)
		var label: String = Tech.title(t) if Tech.valid(t) else TEXT["slot_empty"]
		var b: Button = m._button(TEXT["slot"] % [key, label] if key != "" else label, _pick_slot.bind(tp, i), slots)
		b.custom_minimum_size = Vector2(64.0 if small else 116.0, 34.0 if small else 36.0)
		b.clip_text = true
		b.add_theme_font_size_override("font_size", 12 if small else 13)
		b.set_meta("bench_slot", i)
		tp._brass(b, can and i == sel)
		if Tech.valid(t) and not (can and i == sel):
			b.add_theme_color_override("font_color", Tech.color(Tech.lead(t)).lightened(0.25))
		b.disabled = not can
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 10 if small else 16)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(body)
	# Left: the vials, then the moulds.
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 3 if small else 5)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(left)
	_label(left, TEXT["essences"], small)
	var kinds := vial_kinds(prof)
	var vg := GridContainer.new()
	vg.columns = 4 if small or kinds.size() > 6 else kinds.size()
	vg.add_theme_constant_override("h_separation", 4)
	vg.add_theme_constant_override("v_separation", 4)
	vg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(vg)
	var first := true
	for k in kinds:
		var v := Vial.new()
		v.kind = k
		v.order = d["kinds"].find(k) + 1
		v.why = vial_lock(prof, d, k)
		v.locked = not can or not k in Unbound.kinds_for(prof)
		v.full = (v.why != "" and v.order == 0) and not v.locked
		v.level = clampf(TreeRules.pooled(prof, k) / VIAL_FULL, 0.12, 1.0) if can else 0.0
		v.ticks = []
		for id in Library.effects_of(k):
			var o := float(Library.effect(id).get("opens", 0))
			if o > 0.0:
				v.ticks.append(clampf(o / VIAL_FULL, 0.0, 1.0))
		v.text = Tech.display(k)
		v.custom_minimum_size = Vector2(38, 74) if small else Vector2(44, 108)
		v.disabled = v.locked
		v.set_meta("bench_vial", k)
		if first:
			v.set_meta("bench_start", true)
			first = false
		v.pressed.connect(_pour.bind(tp, k))
		vg.add_child(v)
	_label(left, TEXT["moulds"], small)
	var mg := GridContainer.new()
	mg.columns = 4 if small else 6
	mg.add_theme_constant_override("h_separation", 4)
	mg.add_theme_constant_override("v_separation", 4)
	mg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.add_child(mg)
	for row_m in moulds(prof):
		var mo := Mould.new()
		mo.part = row_m[0]
		mo.form = row_m[1]
		mo.locked = row_m[2] != "owned" or not can
		mo.on = can and row_m[0] == d["part"] and row_m[1] == d["shape"]
		mo.need = int(row_m[3])
		mo.col = Tech.color(Tech.lead(d)) if can and not d["kinds"].is_empty() else UI.TRAIN_BRASS
		mo.text = String(Library.form(row_m[1]).get("name", row_m[1]))
		mo.tooltip_text = "%s · %s" % [Unbound.PART_NAMES[row_m[0]], mo.text] + ("" if row_m[2] == "owned" else "  (%s)" % (TEXT["form_locked"] % mo.need))
		mo.custom_minimum_size = Vector2(42, 42) if small else Vector2(48, 48)
		mo.disabled = mo.locked
		mo.set_meta("bench_mould", "%s:%s" % [row_m[0], row_m[1]])
		mo.pressed.connect(_set_form.bind(tp, row_m[0], row_m[1]))
		mg.add_child(mo)
	# Middle: the globe, the layers poured, the gauge and the plaque.
	var mid := VBoxContainer.new()
	mid.add_theme_constant_override("separation", 4 if small else 6)
	mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(mid)
	var globe := Globe.new()
	globe.form = String(d["shape"])
	globe.cls = String(Library.form(String(d["shape"])).get("class", "hit"))
	globe.kinds = d["kinds"].duplicate() if can else []
	globe.fitting = Tech.variations(d)[0] if can and not Tech.variations(d).is_empty() else ""
	globe.dark = not can
	var pour_at = m.get_meta("bench_pour", {})
	if pour_at is Dictionary and not pour_at.is_empty():
		globe.pour_kind = String(pour_at.get("kind", ""))
		globe.pour_t = (Time.get_ticks_msec() - int(pour_at.get("t", 0))) * 0.001
	globe.custom_minimum_size = Vector2(150, 132) if small else Vector2(200, 176)
	globe.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	mid.add_child(globe)
	var layers := HBoxContainer.new()
	layers.add_theme_constant_override("separation", 4)
	layers.alignment = BoxContainer.ALIGNMENT_CENTER
	layers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(layers)
	if can:
		for i in d["kinds"].size():
			var k := String(d["kinds"][i])
			var fx := Library.effect(Tech.effect_of(d, k))
			var opts := effects_for(prof, k)
			var lb: Button = m._button(TEXT["layer"] % [Tech.display(k), String(fx.get("name", ""))] + ("  ›" if opts.size() > 1 else ""), _cycle_fx.bind(tp, k), layers)
			lb.custom_minimum_size = Vector2(0, 32 if small else 34)
			lb.add_theme_font_size_override("font_size", 12 if small else 13)
			lb.set_meta("bench_fx", k)
			tp._brass(lb, false)
			lb.add_theme_color_override("font_color", Tech.color(k).lightened(0.3))
			lb.tooltip_text = String(fx.get("says", ""))
	var under := HBoxContainer.new()
	under.add_theme_constant_override("separation", 6)
	under.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mid.add_child(under)
	var gauge := Gauge.new()
	gauge.strain = strain(d) if can else 0.0
	gauge.custom_minimum_size = Vector2(70, 62) if small else Vector2(86, 74)
	gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	under.add_child(gauge)
	var plaque := Plaque.new()
	plaque.small = small
	under.add_child(plaque)
	var pc := VBoxContainer.new()
	pc.add_theme_constant_override("separation", 1)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.add_child(pc)
	var ink := Color(0.17, 0.1, 0.04)
	var nm := Label.new()
	nm.text = (Tech.title(d) if Tech.valid(d) else TEXT["empty"]) if can else TEXT["title"]
	UI.style_label(nm, "display", 16 if small else 19, ink)
	nm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nm.set_meta("bench_name", true)
	pc.add_child(nm)
	var w := 170.0 if small else 230.0
	var line := _plaque_line(pc, one_line(d) if can else TEXT["for_unbound"], ink, w, 12 if small else 13)
	line.set_meta("bench_line", true)
	if can and Tech.valid(d):
		var echo := echo_line(d)
		if echo != "":
			var el := _plaque_line(pc, echo, Color(0.33, 0.14, 0.42), w, 12 if small else 13)
			el.set_meta("bench_echo", true)
		var bits: String = TEXT["fill"] % [int(round(Tech.charge(d, prof))), TEXT["strain"] % int(round(strain(d)))]
		if dirty(m):
			bits += "  ·  " + TEXT["unsaved"]
		_plaque_line(pc, bits, Color(ink, 0.75), w, 11 if small else 12)
	# Right: the fittings, and Set in slot.
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 3 if small else 5)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(right)
	_label(right, TEXT["fittings"], small)
	var fg := GridContainer.new()
	fg.columns = 2 if small else 2
	fg.add_theme_constant_override("h_separation", 4)
	fg.add_theme_constant_override("v_separation", 4)
	fg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(fg)
	var owned: Array = TreeRules.owned_variations(prof)
	for vid in FITTING_ORDER:
		var v := Library.variation(vid)
		if not Library.built(v):
			continue
		var f := Fitting.new()
		f.vid = vid
		f.locked = not can or not vid in owned
		f.on = can and vid in Tech.variations(d)
		f.text = String(v.get("name", vid))
		f.tooltip_text = "%s: %s" % [f.text, String(v.get("says", ""))] + ("" if not f.locked else "\n" + TEXT["fitting_locked"])
		f.custom_minimum_size = Vector2(42, 42) if small else Vector2(50, 50)
		f.disabled = f.locked
		f.set_meta("bench_fitting", vid)
		f.pressed.connect(_fit.bind(tp, vid))
		fg.add_child(f)
	var key := _key_name(m, sel)
	var sb: Button = m._button(TEXT["set"] % key if key != "" and not small else TEXT["set_short"], _save.bind(tp), right)
	sb.custom_minimum_size = Vector2(0, 40)
	sb.set_meta("bench_save", true)
	tp._brass(sb, can and Tech.valid(d) and dirty(m))
	sb.disabled = not can or not Tech.valid(d) or not dirty(m)
	if can and Tech.valid(d) and not dirty(m):
		sb.text = TEXT["in_slot"]
	if m.toast != "":
		var tl: Label = tp._note(col, m.toast, 380.0 if not small else 300.0)
		tl.add_theme_color_override("font_color", UI.GOLD)


static func _label(parent: Node, text: String, small: bool) -> void:
	var l := Label.new()
	l.text = text
	UI.style_label(l, "eyebrow", 12 if small else 13, Color(UI.GOLD, 0.9))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)


static func _plaque_line(parent: Node, text: String, col: Color, w: float, fs: int) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = w
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


## A change on the bench: built again, the focus kept on what was pressed.
static func _redraw(tp, meta: String, value) -> void:
	var m = tp.m
	m._want_focus = {"meta": meta, "value": value}
	m.open("train")


static func _pick_slot(tp, i: int) -> void:
	load_slot(tp.m, i)
	tp.m.toast = ""
	tp.m.main.sfx("ui_confirm", 1.0, -4.0, 0.0)
	_redraw(tp, "bench_slot", i)


static func _pour(tp, kind: String) -> void:
	var m = tp.m
	var prof = m.main.profile
	var d := draft(m)
	var why := vial_lock(prof, d, kind)
	m.toast = ""
	if why != "" and not kind in d["kinds"]:
		m.toast = TEXT["cant"] % why
		m.toast_t = 3.0
		m.main.sfx("ui_back", 1.0, -6.0, 0.0)
		_redraw(tp, "bench_vial", kind)
		return
	var opening: bool = not kind in d["kinds"]
	set_draft(m, pour(prof, d, kind))
	if opening:
		m.set_meta("bench_pour", {"kind": kind, "t": Time.get_ticks_msec()})
		m.main.sfx("pour", 1.0, -2.0, 0.0)
	else:
		m.remove_meta("bench_pour")
		m.main.sfx("ui_move", 0.8, -4.0, 0.0)
	_redraw(tp, "bench_vial", kind)


static func _set_form(tp, part: String, form: String) -> void:
	var m = tp.m
	set_draft(m, set_form(m.main.profile, draft(m), part, form))
	m.toast = ""
	m.remove_meta("bench_pour")
	m.main.sfx("ui_confirm", 0.9, -4.0, 0.0)
	_redraw(tp, "bench_mould", "%s:%s" % [part, form])


static func _cycle_fx(tp, kind: String) -> void:
	var m = tp.m
	var prof = m.main.profile
	var d := draft(m)
	m.toast = ""
	if effects_for(prof, kind).size() < 2:
		# Nothing else open yet: say what opens next.
		for id in Library.effects_of(kind):
			var fx := Library.effect(id)
			if Library.built(fx) and not TreeRules.effect_open(prof, id) and float(fx.get("opens", 0)) > 0.0:
				m.toast = TEXT["effect_locked"] % [String(fx["name"]), int(fx["opens"]), Tech.display(kind)]
				m.toast_t = 3.0
				break
	else:
		set_draft(m, cycle_effect(prof, d, kind))
		m.main.sfx("glint", 1.2, -6.0, 0.0)
	m.remove_meta("bench_pour")
	_redraw(tp, "bench_fx", kind)


static func _fit(tp, vid: String) -> void:
	var m = tp.m
	set_draft(m, fit(m.main.profile, draft(m), vid))
	m.toast = ""
	m.remove_meta("bench_pour")
	m.main.sfx("equip_heavy", 1.3, -6.0, 0.0)
	_redraw(tp, "bench_fitting", vid)


static func _save(tp) -> void:
	var m = tp.m
	if save(m):
		m.main.sfx("craft_rune", 1.0, 0.0, 0.0)
	m.remove_meta("bench_pour")
	_redraw(tp, "bench_save", true)


# --- drawn in code -------------------------------------------------------------------

## Draws a form's shape (the globe's contents, a mould's face) in a circle
## of radius `r` at `c`.
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
				var t := float(i) / 24.0 * TAU
				pts.append(c + Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))) * r / 22.0)
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


## A focus ring on a drawn control (not on a phone, where nothing shows the focus).
static func focus_ring(ci: Control, r: Rect2, rad := 5.0) -> void:
	if not ci.has_focus() or _touching(ci):
		return
	var ring := UI.rounded(r.grow(2.0), rad)
	ring.append(ring[0])
	ci.draw_polyline(ring, Color(UI.GILT, 0.3), 5.0, true)
	ci.draw_polyline(ring, UI.GILT_HI, 1.6, true)


static func _touching(ci: Node) -> bool:
	var n := ci.get_parent()
	while n != null:
		if n.has_method("rail_showing"):
			return n.main != null and n.main.touch_active
		n = n.get_parent()
	return false


## The bench's top: a walnut workbench with a brass rail and a shelf, behind
## everything on it.
class BenchTop extends PanelContainer:
	const UI := preload("res://scripts/ui.gd")
	const Art := preload("res://scripts/train_art.gd")
	var small := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var st := StyleBoxEmpty.new()
		var m := 10.0 if small else 16.0
		st.content_margin_left = m
		st.content_margin_right = m
		st.content_margin_top = m * 0.7
		st.content_margin_bottom = m
		add_theme_stylebox_override("panel", st)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var b := UI.Draw.Batch.new()
		var r := Rect2(Vector2.ZERO, size)
		b.rect(Rect2(r.position + Vector2(4, 6), r.size), Color(0, 0, 0, 0.35))
		b.rect(r, Art.OUTLINE)
		var body := r.grow(-1.5)
		Art.vgrad(b, body, Art.WALNUT.lightened(0.06), Art.WALNUT.darkened(0.35))
		Art.grain(b, body, Art.WALNUT, 31, 1.0, false, false)
		Art.light(b, Vector2(body.get_center().x, body.position.y), Vector2(body.size.x * 0.6, body.size.y * 0.5), Color(Art.LAMP, 0.08))
		# A brass rail round the top, riveted.
		Art.bar(b, Rect2(body.position.x, body.position.y, body.size.x, 3.0))
		Art.bar(b, Rect2(body.position.x, body.end.y - 4.0, body.size.x, 4.0))
		Art.rivets(b, body.position + Vector2(10, 1.5), Vector2(body.end.x - 10, body.position.y + 1.5), 48.0, 1.6)
		b.flush(self)


## A vial of one essence, its liquid showing how much has pooled in you, and
## a brass tap at its foot: turned down (open) with its order on it, or across (shut).
class Vial extends Button:
	const UI := preload("res://scripts/ui.gd")
	const Art := preload("res://scripts/train_art.gd")
	var Bench = load("res://scripts/essence_bench.gd")
	var kind := "fire"
	var order := 0  # 0 shut, 1 leads, 2, 3
	var locked := false  # dark: not yours to pour
	var full := false  # the part can't combine another (pressing says why)
	var why := ""
	var level := 0.5  # how full the glass is (0..1)
	var ticks: Array = []  # where effects open, up the glass (0..1)

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		clip_text = true
		for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
			add_theme_color_override(c, Color(0, 0, 0, 0))
		for s in [focus_entered, focus_exited, mouse_entered, mouse_exited]:
			s.connect(queue_redraw)

	func _draw() -> void:
		var Tech = load("res://scripts/technique.gd")
		var col: Color = Tech.color(kind) if not locked else Color(0.22, 0.2, 0.24)
		var hot := (is_hovered() or has_focus()) and not locked
		var w := size.x
		var h := size.y
		var label_h := 14.0
		var tap_h := 16.0
		var glass := Rect2(w * 0.18, 8.0, w * 0.64, h - label_h - tap_h - 10.0)
		var b := UI.Draw.Batch.new()
		# The cork and its brass cap.
		b.rect(Rect2(glass.position.x + glass.size.x * 0.22, 1.0, glass.size.x * 0.56, 8.0), Art.OUTLINE)
		b.rect(Rect2(glass.position.x + glass.size.x * 0.25, 2.0, glass.size.x * 0.5, 6.0), Art.GILT.darkened(0.2) if not locked else Color(0.3, 0.27, 0.22))
		# The glass, then the liquid (its level), lit from the left.
		b.rect(glass.grow(1.4), Art.OUTLINE)
		b.rect(glass, Color(0.1, 0.1, 0.14, 0.85))
		var lq_h := glass.size.y * level
		var lq := Rect2(glass.position.x, glass.end.y - lq_h, glass.size.x, lq_h)
		if lq_h > 0.5:
			Art.vgrad(b, lq, col.lightened(0.1 if order > 0 else 0.0), col.darkened(0.45))
			b.rect(Rect2(lq.position, Vector2(lq.size.x, 1.5)), Color(col.lightened(0.5), 0.8))
		b.rect(Rect2(glass.position.x + 2.0, glass.position.y + 3.0, 2.0, glass.size.y - 6.0), Color(1, 1, 1, 0.22 if not locked else 0.06))
		# Ticks up the glass where this essence's effects open.
		for t in ticks:
			var ty: float = glass.end.y - glass.size.y * float(t)
			b.rect(Rect2(glass.end.x - 5.0, ty, 5.0, 1.2), Color(Art.GILT, 0.7 if not locked else 0.2))
		# The tap: a brass spout and a handle, across when shut, down when open.
		var tc := Vector2(w * 0.5, glass.end.y + tap_h * 0.5 + 1.0)
		var brass: Color = Art.GILT if not locked else Color(0.32, 0.28, 0.22)
		if hot:
			brass = Art.GILT_HI
		b.rect(Rect2(tc.x - 4.0, glass.end.y, 8.0, tap_h * 0.75), Art.OUTLINE)
		b.rect(Rect2(tc.x - 3.0, glass.end.y, 6.0, tap_h * 0.7), brass.darkened(0.15))
		b.dot(tc, 4.6, Art.OUTLINE)
		b.dot(tc, 3.6, brass)
		var arm := Vector2(0, 7.5) if order > 0 else Vector2(8.5, 0)
		b.stroke(tc - arm * 0.15, tc + arm, brass, 3.0)
		b.dot(tc + arm, 2.4, brass.lightened(0.2))
		if order > 0:
			# A drip, and the order stamped beside the tap.
			b.dot(Vector2(tc.x, glass.end.y + tap_h - 1.0), 1.8, col.lightened(0.2))
		b.flush(self)
		if order > 0:
			var badge := Vector2(w - 9.0, glass.position.y + 9.0)
			draw_circle(badge, 8.0, Art.OUTLINE)
			draw_circle(badge, 7.0, Art.GILT if order == 1 else Art.GILT.darkened(0.3))
			UI.draw_label(self, badge + Vector2(-7.0, 4.0), str(order), 12, Color(0.15, 0.08, 0.03), HORIZONTAL_ALIGNMENT_CENTER, 14.0)
		if locked:
			# A little lock on the dark glass.
			var lc := glass.get_center()
			draw_rect(Rect2(lc + Vector2(-5, -1), Vector2(10, 8)), Color(0.45, 0.42, 0.38))
			draw_arc(lc + Vector2(0, -1), 3.6, PI, TAU, 8, Color(0.45, 0.42, 0.38), 1.6, true)
		var tc2: Color = Tech.color(kind).lightened(0.35) if not locked else UI.FAINT
		if full and order == 0:
			tc2 = Color(tc2, 0.55)
		UI.draw_label(self, Vector2(0, h - 3.0), text, 11 if w < 40.0 else 12, tc2, HORIZONTAL_ALIGNMENT_CENTER, w)
		Bench.focus_ring(self, Rect2(Vector2.ZERO, size), 5.0)


## A mould on the rack: a form's shape pressed into brass. Dark when locked
## (the level that opens it on it).
class Mould extends Button:
	const UI := preload("res://scripts/ui.gd")
	const Art := preload("res://scripts/train_art.gd")
	var Bench = load("res://scripts/essence_bench.gd")
	var part := "hand"
	var form := "strike"
	var locked := false
	var on := false
	var need := 1
	var col := Color.WHITE

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		clip_text = true
		for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
			add_theme_color_override(c, Color(0, 0, 0, 0))
		for s in [focus_entered, focus_exited, mouse_entered, mouse_exited]:
			s.connect(queue_redraw)

	func _draw() -> void:
		var Lib = load("res://scripts/library.gd")
		var r := Rect2(Vector2(1, 1), size - Vector2(2, 2))
		var hot := (is_hovered() or has_focus()) and not locked
		var b := UI.Draw.Batch.new()
		b.rect(r.grow(1.0), Art.OUTLINE)
		var face: Color = Art.GILT.darkened(0.2) if on else (Color(0.3, 0.22, 0.12) if not locked else Color(0.14, 0.12, 0.12))
		if hot and not on:
			face = face.lightened(0.15)
		Art.vgrad(b, r, face.lightened(0.12), face.darkened(0.3))
		b.rect(Rect2(r.position, Vector2(r.size.x, 1.2)), Color(1, 1, 1, 0.18 if not locked else 0.05))
		b.flush(self)
		var ink: Color = (Color(0.2, 0.1, 0.04) if on else Art.GILT.lightened(0.1)) if not locked else Color(0.36, 0.33, 0.3)
		var cls := String(Lib.form(form).get("class", "hit"))
		Bench.draw_form(self, form, cls, r.get_center() + Vector2(0, -4.0), minf(r.size.x, r.size.y) * 0.28, ink, 1.6)
		UI.draw_label(self, Vector2(r.position.x, r.end.y - 3.0), text, 9 if size.x < 46.0 else 10, ink if not locked else Color(0.45, 0.42, 0.4), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		if locked:
			UI.draw_label(self, Vector2(r.position.x, r.position.y + 11.0), "L%d" % need, 9, Color(0.55, 0.5, 0.45), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 3.0)
		Bench.focus_ring(self, r, 4.0)


## A brass fitting on the shelf, for the globe's spout: a variation.
class Fitting extends Button:
	const UI := preload("res://scripts/ui.gd")
	const Art := preload("res://scripts/train_art.gd")
	var Bench = load("res://scripts/essence_bench.gd")
	var vid := "split"
	var locked := false
	var on := false

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		clip_text = true
		for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
			add_theme_color_override(c, Color(0, 0, 0, 0))
		for s in [focus_entered, focus_exited, mouse_entered, mouse_exited]:
			s.connect(queue_redraw)

	func _draw() -> void:
		var r := Rect2(Vector2(1, 1), size - Vector2(2, 2))
		var hot := (is_hovered() or has_focus()) and not locked
		var b := UI.Draw.Batch.new()
		b.rect(r.grow(1.0), Art.OUTLINE)
		Art.vgrad(b, r, Color(0.18, 0.12, 0.08) if not on else Color(0.42, 0.3, 0.14), Color(0.09, 0.06, 0.04))
		if on:
			b.rect(Rect2(r.position, Vector2(r.size.x, 2.0)), Art.GILT_HI)
		b.flush(self)
		var brass: Color = Art.GILT if not locked else Color(0.26, 0.23, 0.2)
		if hot:
			brass = Art.GILT_HI
		Bench.draw_fitting(self, vid, r.get_center() + Vector2(0, -2.0), minf(r.size.x, r.size.y) * 0.3, brass)
		UI.draw_label(self, Vector2(r.position.x, r.end.y - 2.0), text, 9 if size.x < 46.0 else 10, (Color(1.0, 0.92, 0.7) if on else Art.GILT.lightened(0.15)) if not locked else Color(0.42, 0.4, 0.38), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		Bench.focus_ring(self, r, 4.0)


## The brass-bound glass globe: the form's shape inside, the essences poured
## (the lead filling most of it, the others swirling thinner above), a pipe
## from the taps above and a spout below with its fitting. A tap just opened
## runs a stream of liquid down the pipe into it.
class Globe extends Control:
	const UI := preload("res://scripts/ui.gd")
	const Art := preload("res://scripts/train_art.gd")
	var Bench = load("res://scripts/essence_bench.gd")
	var form := "strike"
	var cls := "hit"
	var kinds: Array = []
	var fitting := ""
	var dark := false
	var pour_kind := ""
	var pour_t := 99.0  # seconds since a tap opened
	var t := 0.0
	var _acc := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		t += delta
		pour_t += delta
		_acc += delta
		var pouring: bool = pour_t < float(Bench.POUR_TIME) + 0.2
		if (_acc < 1.0 / 12.0 and not pouring) or not is_visible_in_tree():
			return
		_acc = 0.0
		queue_redraw()

	func _draw() -> void:
		var Tech = load("res://scripts/technique.gd")
		var w := size.x
		var h := size.y
		var spout_h := h * 0.16
		var rad := minf(w * 0.4, (h - spout_h - 14.0) * 0.5)
		var c := Vector2(w * 0.5, 12.0 + rad)
		var b := UI.Draw.Batch.new()
		# The pipe from the taps, down into the globe's neck.
		Art.pipe(b, Vector2(c.x, 0.0), Vector2(c.x, c.y - rad + 4.0), 7.0, Art.GILT.darkened(0.15) if not dark else Color(0.3, 0.27, 0.22))
		# The glass ball: dark inside, a soft rim.
		b.circle(c + Vector2(3, 5), rad + 3.0, Color(0, 0, 0, 0.35))
		b.circle(c, rad + 2.0, Art.OUTLINE)
		b.circle(c, rad, Color(0.07, 0.07, 0.11, 0.94))
		# How full: the pour runs it up to its level over POUR_TIME.
		var full := 0.0
		if not kinds.is_empty():
			full = 0.62 + 0.1 * kinds.size()
		var k := clampf(pour_t / Bench.POUR_TIME, 0.0, 1.0) if pour_kind != "" else 1.0
		var level := full * (0.55 + 0.45 * ease(k, 0.5)) if pour_kind != "" and kinds.size() == 1 else full
		if not kinds.is_empty():
			# The lead fills the bottom; the others float above it, thinner, swirling.
			var bands: Array = []
			var lead_share := 0.7 if kinds.size() > 1 else 1.0
			var rest_share := (1.0 - lead_share) / maxf(kinds.size() - 1, 1)
			var y0 := c.y + rad
			var total_h := rad * 2.0 * level
			for i in kinds.size():
				var share := lead_share if i == 0 else rest_share
				var bh := total_h * share
				if pour_kind == String(kinds[i]) and i > 0:
					bh *= ease(k, 0.6)
				bands.append([String(kinds[i]), y0 - bh, y0])
				y0 -= bh
			for bi in range(bands.size() - 1, -1, -1):
				var bd: Array = bands[bi]
				var col: Color = Tech.color(bd[0]) if not dark else Color(0.2, 0.2, 0.22)
				var pts := _cap(c, rad - 1.0, bd[1], c.y + rad, bi > 0 or true, float(bi))
				if pts.size() >= 3:
					b.polygon(pts, Color(col.darkened(0.15), 0.92))
			# A brighter swirl on the surface of each band.
			for bd in bands:
				var col: Color = Tech.color(bd[0])
				var y: float = bd[1]
				var half := sqrt(maxf(rad * rad - (y - c.y) * (y - c.y), 0.0)) - 2.0
				if half > 2.0:
					var pts := PackedVector2Array()
					for i in 13:
						var f := float(i) / 12.0
						pts.append(Vector2(c.x - half + 2.0 * half * f, y + sin(f * TAU * 1.5 + t * 2.2) * 1.8))
					b.path(pts, Color(col.lightened(0.45), 0.8), 1.6)
			# Motes rising in the lead.
			var lc: Color = Tech.color(String(kinds[0])).lightened(0.5)
			for i in 5:
				var f := fmod(t * 0.25 + i * 0.2, 1.0)
				var my := c.y + rad - f * total_h * 0.9
				var mx := c.x + sin(i * 2.3 + t) * rad * 0.45
				b.dot(Vector2(mx, my), 1.4, Color(lc, 0.6 * (1.0 - f)))
		# The stream from the pipe while a tap runs.
		if pour_kind != "" and pour_t < Bench.POUR_TIME:
			var sc: Color = Tech.color(pour_kind)
			var top_y := c.y - rad + 4.0
			var bot_y := c.y + rad - rad * 2.0 * level * 0.95
			var wob := sin(t * 30.0) * 0.8
			b.rect(Rect2(c.x - 2.0 + wob, top_y, 4.0, maxf(bot_y - top_y, 2.0)), Color(sc.lightened(0.2), 0.9))
			for i in 4:
				var f := fmod(pour_t * 3.0 + i * 0.25, 1.0)
				b.dot(Vector2(c.x + wob, lerpf(top_y, bot_y, f)), 2.2, sc.lightened(0.5))
			b.circle(Vector2(c.x, bot_y), 5.0 + 2.0 * sin(t * 20.0), Color(sc.lightened(0.3), 0.5))
		b.flush(self)
		# The form's shape, inside, over the liquid.
		var ink := Color(1.0, 0.96, 0.85, 0.9) if not dark else Color(0.4, 0.38, 0.36, 0.6)
		if kinds.is_empty() and not dark:
			ink = Color(ink, 0.55)
		Bench.draw_form(self, form, cls, c, rad * 0.55, ink, 2.6)
		# The glass's shine and its brass bands.
		draw_arc(c, rad - 4.0, PI * 1.05, PI * 1.45, 12, Color(1, 1, 1, 0.3 if not dark else 0.08), 3.0, true)
		draw_circle(c + Vector2(-rad * 0.42, -rad * 0.45), rad * 0.07, Color(1, 1, 1, 0.35 if not dark else 0.08))
		var brass: Color = Art.GILT if not dark else Color(0.3, 0.27, 0.22)
		draw_arc(c, rad + 1.0, 0.0, TAU, 48, Art.OUTLINE, 4.5, true)
		draw_arc(c, rad + 1.0, 0.0, TAU, 48, brass.darkened(0.1), 3.0, true)
		draw_line(c + Vector2(-rad - 2.0, 0), c + Vector2(rad + 2.0, 0), Color(brass.darkened(0.2), 0.75), 2.0)
		for a in [0.0, PI]:
			draw_circle(c + Vector2.from_angle(a) * (rad + 1.0), 3.0, brass.lightened(0.2))
		# The neck collar at the top.
		draw_rect(Rect2(c.x - 9.0, c.y - rad - 4.0, 18.0, 6.0), brass)
		# The spout below, with its fitting.
		var sp := Vector2(c.x, c.y + rad + 1.0)
		draw_rect(Rect2(sp.x - 5.0, sp.y, 10.0, spout_h * 0.45), Art.OUTLINE)
		draw_rect(Rect2(sp.x - 4.0, sp.y, 8.0, spout_h * 0.42), brass.darkened(0.1))
		if fitting != "":
			Bench.draw_fitting(self, fitting, sp + Vector2(0, spout_h * 0.45 + spout_h * 0.32), spout_h * 0.5, brass)
		elif not kinds.is_empty() and not dark:
			draw_circle(sp + Vector2(0, spout_h * 0.55), 2.0, Tech.color(String(kinds[0])).lightened(0.2))

	## The part of the circle (c, r) between y0 and y1 (a band of liquid), its
	## top edge gently waving.
	func _cap(c: Vector2, r: float, y0: float, y1: float, wave: bool, seed: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		y0 = clampf(y0, c.y - r, c.y + r)
		y1 = clampf(y1, c.y - r, c.y + r)
		if y1 - y0 < 0.5:
			return pts
		var n := 14
		# Down the right side, along the bottom arc, up the left.
		var a0 := asin(clampf((y0 - c.y) / r, -1.0, 1.0))
		var a1 := asin(clampf((y1 - c.y) / r, -1.0, 1.0))
		for i in n + 1:
			var a := lerpf(a0, a1, float(i) / n)
			pts.append(c + Vector2(cos(a) * r, sin(a) * r))
		for i in n + 1:
			var a := lerpf(a1, a0, float(i) / n)
			pts.append(c + Vector2(-cos(a) * r, sin(a) * r))
		# The top surface, from left to right, waving.
		var half := cos(a0) * r
		for i in range(1, 12):
			var f := float(i) / 12.0
			pts.append(Vector2(c.x - half + 2.0 * half * f, y0 + (sin(f * TAU + t * 2.0 + seed) * 1.5 if wave else 0.0)))
		return pts


## The strain gauge: a brass dial, 0 to 100, its needle at the strain one
## cast adds, a red mark where a part runs hot (70).
class Gauge extends Control:
	const UI := preload("res://scripts/ui.gd")
	const Art := preload("res://scripts/train_art.gd")
	var strain := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var w := size.x
		var h := size.y
		var c := Vector2(w * 0.5, h * 0.66)
		var r := minf(w * 0.44, h * 0.6)
		var b := UI.Draw.Batch.new()
		b.circle(c + Vector2(2, 3), r + 4.0, Color(0, 0, 0, 0.35))
		b.circle(c, r + 4.0, Art.OUTLINE)
		b.circle(c, r + 3.0, Art.GILT.darkened(0.15))
		b.circle(c, r, Color(0.93, 0.88, 0.76))
		b.arc(c, r * 0.8, PI + PI * 0.7, TAU, 10, Color(0.75, 0.2, 0.15, 0.7), 4.0)
		for i in 11:
			var a := PI + PI * float(i) / 10.0
			var dir := Vector2.from_angle(a)
			b.line(c + dir * r * (0.78 if i % 5 == 0 else 0.86), c + dir * r * 0.95, Color(0.2, 0.14, 0.08), 1.4 if i % 5 == 0 else 1.0)
		var k := clampf(strain / 100.0, 0.0, 1.0)
		var a := PI + PI * k
		b.stroke(c, c + Vector2.from_angle(a) * r * 0.82, Color(0.6, 0.1, 0.08), 2.2)
		b.ball(c, 3.4, Art.GILT)
		b.flush(self)
		UI.draw_label(self, Vector2(0, c.y + r * 0.42), "+%d" % int(round(strain)), 13, Color(0.2, 0.12, 0.06), HORIZONTAL_ALIGNMENT_CENTER, w)
		UI.draw_label(self, Vector2(0, h - 1.0), "strain", 10, Color(UI.GOLD, 0.9), HORIZONTAL_ALIGNMENT_CENTER, w)


## The brass plaque: the technique's name engraved, and what it does.
class Plaque extends PanelContainer:
	const UI := preload("res://scripts/ui.gd")
	const Art := preload("res://scripts/train_art.gd")
	var small := false

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var st := StyleBoxEmpty.new()
		st.content_margin_left = 12.0
		st.content_margin_right = 12.0
		st.content_margin_top = 7.0
		st.content_margin_bottom = 7.0
		add_theme_stylebox_override("panel", st)
		resized.connect(queue_redraw)

	func _draw() -> void:
		var b := UI.Draw.Batch.new()
		var r := Rect2(Vector2.ZERO, size)
		b.rect(Rect2(r.position + Vector2(2, 3), r.size), Color(0, 0, 0, 0.35))
		b.rect(r, Art.OUTLINE)
		var plate := r.grow(-1.5)
		Art.vgrad(b, plate, Color(0.9, 0.74, 0.44), Color(0.66, 0.48, 0.22))
		b.rect(Rect2(plate.position, Vector2(plate.size.x, 1.5)), Color(1, 0.95, 0.8, 0.7))
		b.rect(Rect2(plate.position + Vector2(3, 3), plate.size - Vector2(6, 6)), Color(0, 0, 0, 0))
		for p in [plate.position + Vector2(5, 5), Vector2(plate.end.x - 5, plate.position.y + 5), plate.end - Vector2(5, 5), Vector2(plate.position.x + 5, plate.end.y - 5)]:
			Art.rivet(b, p, 1.8, Art.GILT_LO)
		b.flush(self)
		var frame := UI.rounded(plate.grow(-3.0), 2.0)
		frame.append(frame[0])
		draw_polyline(frame, Color(0.45, 0.3, 0.12, 0.6), 1.0, true)
