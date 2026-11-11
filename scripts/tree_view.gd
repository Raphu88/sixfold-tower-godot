extends RefCounted
## THE TREE SECTION of the book (menu.gd's climber page, "tree"): the body
## map. The climber stands on the left, each body part a node on the figure;
## the chosen part's tree grows on the right, a node per step (marks) or per
## level (the Unbound), each a row of buds on a stem; the chosen bud's
## grimoire card (grimoire_card.gd) and what you can do with it are below.
##
## Buds show what each piece is to you: yours (owned), in use until you
## choose (today's side of a ready fork), a ready choice (pulsing gold),
## locked (and what opens it), passed on (faded), learnable again (the
## Unbound), and "Coming later" (not written yet: it can't be chosen).
## Choosing is for good, so it takes a second press (the first only arms
## it); the Entity says so the first time a fork is ready (entity.gd TIPS "tree_fork").
##
## All the drawing is in this file (BodyMap, PartNode, Stem, Bud) so a later
## pass can restyle it without touching the rules (tree.gd) or the book (book.gd).

const TreeRules := preload("res://scripts/tree.gd")
const Library := preload("res://scripts/library.gd")
const Unbound := preload("res://scripts/unbound.gd")
const Bonds := preload("res://scripts/bonds.gd")
const UI := preload("res://scripts/ui.gd")
const GrimoireCard := preload("res://scripts/grimoire_card.gd")
const Controls := preload("res://scripts/controls.gd")

static var TEXT := {
	"head_mark": "%s  ·  %s  ·  step %d of %d",
	"head_faint": "%s  ·  %s  ·  faint",
	"head_unbound": "%s  ·  level %d of 10",
	"head_none": "%s  ·  no mark yet",
	"none": "No mark here yet. This part %s; once it's full, a summit marks it.",
	"first": "Your first climb is bondless. At its top the tower's beast takes notice, and the part you used most takes your first mark. Its tree grows here.",
	"or": "or",
	"steps": "Steps %d–%d",
	"effects": "Essences",
	"choose": "Choose %s, for good",
	"choose_again": "%s to choose %s, for good",
	"learn": "Learn %s  ·  %d crystal essence",
	"learn_again": "%s to learn it  ·  %d crystal essence",
	"learn_short": "Needs %d crystal essence",
	"chosen": "%s chosen. It's yours for good.",
	"learned": "%s learned.",
	"state": {"owned": "yours", "in_use": "in use until you choose", "available": "choose one", "passed": "passed on", "learnable": "you can learn it now",
		"locked": "%s", "placeholder": "Coming later", "later": "Coming later"},
	"opens": "opens %s",
	"only_train": "Choices are made on the train.",
	"spell_cost": "costs %d",
	"strain": "+%d strain",
	"press": "press %s",
	"dev": "The tree",
	"dev_head": "%d pieces owned  ·  %d choices ready",
	"dev_forget": "Forget every choice",
	"dev_open": "Open the Tree",
}
## How long an armed choice waits for its second press (ms).
const ARM_MS := 4000


# --- the section --------------------------------------------------------------------------

static func build(menu) -> void:
	var main = menu.main
	var prof = main.profile
	var small: bool = menu.compact()
	var part := current_part(menu)
	var nodes: Array = TreeRules.nodes(prof, part)
	# The Entity, the first time a fork is ready: choices are for good.
	if TreeRules.is_fork_ready(prof):
		var told: String = main.tip_now("tree_fork")
		if told != "":
			menu._text(told, menu.GOLD.lightened(0.2), true)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10 if small else 16)
	menu.box.add_child(row)
	var map := BodyMap.new()
	map.menu = menu
	map.part = part
	map.custom_minimum_size = Vector2(272, 236) if small else Vector2(300, 300)
	map.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(map)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.custom_minimum_size.x = 290.0 if small else 380.0
	row.add_child(col)
	var head := Label.new()
	head.text = _head(prof, part)
	UI.style_label(head, "display", 19 if small else 22, _part_color(prof, part).lightened(0.2))
	head.set_meta("tree_head", part)
	col.add_child(head)
	var sel := _selected(menu, nodes)
	if nodes.is_empty():
		var note := Label.new()
		note.text = TEXT["first"] if prof.bonds.is_empty() and not Unbound.is_on(prof) else TEXT["none"] % String(Bonds.PART_FILLS[part])
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		UI.style_label(note, "body", 15, UI.DIM)
		col.add_child(note)
	# (the steps still to come, past today's top step, share one row)
	var later: Array = nodes.filter(func(n): return n["kind"] == "later")
	for n in nodes:
		if n["kind"] == "later":
			if n == later[0]:
				var m: Dictionary = n.duplicate()
				m["title"] = TEXT["steps"] % [int(later[0]["at"]), int(later[-1]["at"])] if later.size() > 1 else n["title"]
				col.add_child(_node_row(menu, m, sel, small, true))
			continue
		col.add_child(_node_row(menu, n, sel, small, n == nodes[-1]))
	if Unbound.is_on(prof):
		var fx: Array = TreeRules.effect_rows(prof, part)
		if not fx.is_empty():
			var el := Label.new()
			el.text = TEXT["effects"]
			UI.style_label(el, "eyebrow", UI.SIZE_EYEBROW, Color(UI.GOLD, 0.8))
			col.add_child(el)
			var fl := HFlowContainer.new()
			fl.add_theme_constant_override("h_separation", 6)
			fl.add_theme_constant_override("v_separation", 4)
			col.add_child(fl)
			for e in fx:
				var key := "fx:%s" % e["id"]
				var b := Bud.new()
				b.option = {"id": e["id"], "name": e["name"], "state": e["state"], "built": e["built"], "color": e["color"]}
				b.selected = sel == key
				b.text = e["name"]
				b.set_meta("bud", key)
				b.pressed.connect(_select.bind(menu, key))
				fl.add_child(b)
	# The chosen bud's card, and what can be done with it.
	_card(menu, prof, part, nodes, sel, small)


## The part whose tree shows: the one chosen, else a part with a ready fork,
## else the first marked part (the hand for the Unbound and the bondless).
static func current_part(menu) -> String:
	var prof = menu.main.profile
	var p := String(menu.get_meta("tree_part", ""))
	if p in Bonds.PARTS:
		return p
	for pt in Bonds.PARTS:
		if TreeRules.is_fork_ready(prof, pt):
			return pt
	for pt in Bonds.PARTS:
		if prof.bonds.has(pt):
			return pt
	return "hand"


static func _head(prof, part: String) -> String:
	var name: String = Bonds.PART_NAMES[part]
	if Unbound.is_on(prof):
		return TEXT["head_unbound"] % [name, Unbound.level(prof, part)]
	if prof.bonds.has(part):
		var info: Dictionary = prof.bonds[part]
		var bname: String = Bonds.BONDS[info["id"]]["name"]
		if info.get("faint", false):
			return TEXT["head_faint"] % [name, bname]
		return TEXT["head_mark"] % [name, bname, prof.step_for_xp(float(info["xp"])), TreeRules.MAX_STEP]
	return TEXT["head_none"] % name


static func _part_color(prof, part: String) -> Color:
	if Unbound.is_on(prof):
		return Library.color(String(Unbound.PART_KIND.get(part, "fire")))
	if prof.bonds.has(part):
		return Bonds.BONDS[prof.bonds[part]["id"]]["color"]
	return UI.DIM


## The bud chosen ("node id|option id", or "fx:effect"): the one picked, else
## a ready fork's first choosable side, else the first node's first.
static func _selected(menu, nodes: Array) -> String:
	var s := String(menu.get_meta("tree_sel", ""))
	if s.begins_with("fx:"):
		return s
	for n in nodes:
		for o in n["options"]:
			if "%s|%s" % [n["id"], o["id"]] == s:
				return s
	for n in nodes:
		if n["state"] == "ready":
			for o in n["options"]:
				if o["state"] == "available":
					return "%s|%s" % [n["id"], o["id"]]
	return "%s|%s" % [nodes[0]["id"], nodes[0]["options"][0]["id"]] if not nodes.is_empty() and not nodes[0]["options"].is_empty() else ""


## One node: its stem, its step or level, and a bud for each option ("or" between a fork's).
static func _node_row(menu, n: Dictionary, sel: String, small: bool, last: bool) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	r.set_meta("tree_node", n["id"])
	var stem := Stem.new()
	stem.state = n["state"]
	stem.fork = n["kind"] == "fork"
	stem.last = last
	stem.col = n["options"][0].get("color", UI.GILT) if not n["options"].is_empty() else UI.GILT
	stem.custom_minimum_size = Vector2(16, 34 if small else 38)
	r.add_child(stem)
	var lab := Label.new()
	lab.text = n["title"]
	lab.custom_minimum_size.x = 54.0 if small else 62.0
	UI.style_label(lab, "body", 13, UI.GOLD if n["state"] == "ready" else (UI.DIM if n["state"] in ["owned"] else UI.FAINT))
	lab.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(lab)
	var opts: Array = n["options"]
	for i in opts.size():
		if i > 0:
			var orl := Label.new()
			orl.text = TEXT["or"]
			UI.style_label(orl, "body", 12, UI.FAINT)
			orl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			r.add_child(orl)
		var o: Dictionary = opts[i]
		var key := "%s|%s" % [n["id"], o["id"]]
		var b := Bud.new()
		b.option = o
		b.ready_fork = n["state"] == "ready"
		b.selected = key == sel
		b.text = o["name"]
		b.small = small
		b.set_meta("bud", key)
		b.set_meta("bud_state", o.get("state", ""))
		b.pressed.connect(_select.bind(menu, key))
		r.add_child(b)
	return r


static func _select(menu, key: String) -> void:
	menu.set_meta("tree_sel", key)
	if menu.has_meta("tree_arm"):
		menu.remove_meta("tree_arm")
	menu._want_focus = {"meta": "bud", "value": key}
	menu.open("climber", menu.opened_direct)


static func pick_part(menu, part: String) -> void:
	menu.set_meta("tree_part", part)
	if menu.has_meta("tree_sel"):
		menu.remove_meta("tree_sel")
	menu._want_focus = {"meta": "part", "value": part}
	menu.open("climber", menu.opened_direct)


## The chosen bud's grimoire card and, if it can be chosen or learned, the button.
static func _card(menu, prof, part: String, nodes: Array, sel: String, small: bool) -> void:
	var main = menu.main
	if sel == "":
		return
	var entry := {}
	var node := {}
	var opt := {}
	if sel.begins_with("fx:"):
		for e in TreeRules.effect_rows(prof, part):
			if "fx:%s" % e["id"] == sel:
				entry = {"id": e["id"], "kind": "effect", "name": e["name"], "color": e["color"], "does": e["says"] + ("." if not String(e["says"]).ends_with(".") else ""),
					"tag": TEXT["state"].get(e["state"], "") if e["state"] != "locked" else TEXT["opens"] % e["needs"], "tag_color": UI.FAINT, "state": e["state"], "glyph": "pool"}
	else:
		for n in nodes:
			for o in n["options"]:
				if "%s|%s" % [n["id"], o["id"]] == sel:
					node = n
					opt = o
		if opt.is_empty():
			return
		entry = card_entry(main, prof, part, node, opt)
	if entry.is_empty():
		return
	var card := GrimoireCard.new()
	card.entry = entry
	card.small = small
	card.press_only = true
	card.focus_mode = Control.FOCUS_NONE
	card.set_meta("tree_card", entry.get("id", ""))
	menu.box.add_child(card)
	if opt.is_empty():
		return
	# Choose it (a ready fork), or learn it again (the Unbound's passed side).
	var key := "%s|%s" % [node["id"], opt["id"]]
	var armed := String(menu.get_meta("tree_arm", "")) == key and Time.get_ticks_msec() - int(menu.get_meta("tree_arm_at", 0)) < ARM_MS
	var again := _again(main)
	if node.get("state", "") == "ready" and opt["state"] in ["available", "in_use"] and opt["built"]:
		var b: Button = menu._button(TEXT["choose_again"] % [again, opt["name"]] if armed else TEXT["choose"] % opt["name"], _choose.bind(menu, key), null)
		b.set_meta("tree_act", "choose")
		b.custom_minimum_size.y = 42.0
		if armed:
			menu._primary(b)
	elif opt.get("state", "") == "learnable":
		var cost := int(opt.get("cost", 0))
		var can: bool = prof.crystals_held() >= float(cost)
		var text: String = (TEXT["learn_again"] % [again, cost] if armed else TEXT["learn"] % [opt["name"], cost]) if can else TEXT["learn_short"] % cost
		var b: Button = menu._button(text, _learn.bind(menu, key), null)
		b.set_meta("tree_act", "learn")
		b.disabled = not can
		b.custom_minimum_size.y = 42.0
		if armed:
			menu._primary(b)
	if menu.toast != "":
		menu._text(menu.toast, menu.GOLD, true)


static func _again(main) -> String:
	return "Tap again" if main.touch_active else "Press again"


## A tree option as a grimoire card's entry.
static func card_entry(main, prof, part: String, node: Dictionary, opt: Dictionary) -> Dictionary:
	var st := String(opt.get("state", ""))
	var tag := String(TEXT["state"].get(st, ""))
	if st == "locked":
		tag = node.get("needs", "")
	elif st == "learnable":
		tag = TEXT["learn_short"] % int(opt.get("cost", 0))
	var does := String(opt.get("says", ""))
	if does != "" and not does.ends_with("."):
		does = does.left(1).to_upper() + does.substr(1) + "."
	elif does != "":
		does = does.left(1).to_upper() + does.substr(1)
	var e := {"id": opt["id"], "kind": opt.get("kind", ""), "part": part, "name": opt["name"], "color": opt.get("color", UI.GILT),
		"does": does, "tag": tag, "tag_color": UI.GOLD if st in ["available", "in_use", "learnable"] else (UI.GOOD if st == "owned" else UI.FAINT),
		"state": st, "locked": st == "locked"}
	if opt.has("form"):
		e["form"] = opt["form"]
		var f := Library.form(String(opt["form"]))
		e["numbers"] = _form_numbers(f)
		if float(f.get("strain", 0.0)) > 0.0:
			e["cost"] = TEXT["strain"] % int(f["strain"])
	if opt.get("kind", "") == "variation" and node.get("path", "") == "unbound":
		e["variation"] = opt["id"]
		e["cost"] = TEXT["strain"] % int(opt.get("strain", 0.0))
	var sp: Dictionary = opt.get("spell", {}) if opt.get("spell") is Dictionary else {}
	if node.get("path", "") == "mark" and not sp.is_empty() and opt.get("kind", "") == "spell" and opt.get("built", false):
		e["affinity"] = Bonds.BONDS[node["bond"]]["affinity"]
		var at := maxi(int(node["at"]), prof.step_for_xp(float(prof.bonds[part]["xp"])))
		e["numbers"] = main.menu._spell_stats(sp, at) if main.menu != null else ""
		var vals: Dictionary = main.menu._spell_values(sp, at) if main.menu != null else {}
		if vals.has("cost"):
			e["cost"] = TEXT["spell_cost"] % int(round(float(vals["cost"])))
		if main.menu != null and not main.touch_active:
			e["press"] = load("res://scripts/abilities.gd").press(main, part)
	elif node.get("path", "") == "mark" and opt.get("kind", "") == "variation":
		e["affinity"] = Bonds.BONDS[node["bond"]]["affinity"] if opt.get("built", false) else ""
		e["glyph"] = GrimoireCard.GLYPHS.get(String(opt.get("variation", "")), "")
	return e


static func _form_numbers(f: Dictionary) -> String:
	var W: Dictionary = load("res://scripts/abilities.gd").SHAPE_WORDS
	var bits: Array = []
	for k in W:
		if f.has(k):
			bits.append(W[k] % _num(float(f[k])))
	return "  ·  ".join(bits)


static func _num(f: float) -> String:
	return str(int(round(f))) if absf(f - round(f)) < 0.05 else "%.1f" % f


## Choose: the first press arms it; a second within ARM_MS chooses, for good.
static func _choose(menu, key: String) -> void:
	var main = menu.main
	if String(menu.get_meta("tree_arm", "")) != key or Time.get_ticks_msec() - int(menu.get_meta("tree_arm_at", 0)) >= ARM_MS:
		menu.set_meta("tree_arm", key)
		menu.set_meta("tree_arm_at", Time.get_ticks_msec())
		menu._want_focus = {"meta": "tree_act", "value": "choose"}
		menu.open("climber", menu.opened_direct)
		return
	menu.remove_meta("tree_arm")
	var bits := key.split("|")
	var n := TreeRules.node(main.profile, bits[0])
	if TreeRules.choose(main.profile, bits[0], bits[1]):
		var name := ""
		for o in n.get("options", []):
			if o["id"] == bits[1]:
				name = o["name"]
		main.profile.save()
		main._give_bonds()
		main.sfx("ready", 0.9)
		menu.toast = TEXT["chosen"] % name
		menu.toast_t = 3.0
	menu._want_focus = {"meta": "bud", "value": key}
	menu.open("climber", menu.opened_direct)


## Learn a passed side again (the Unbound): two presses, then it's paid for.
static func _learn(menu, key: String) -> void:
	var main = menu.main
	if String(menu.get_meta("tree_arm", "")) != key or Time.get_ticks_msec() - int(menu.get_meta("tree_arm_at", 0)) >= ARM_MS:
		menu.set_meta("tree_arm", key)
		menu.set_meta("tree_arm_at", Time.get_ticks_msec())
		menu._want_focus = {"meta": "tree_act", "value": "learn"}
		menu.open("climber", menu.opened_direct)
		return
	menu.remove_meta("tree_arm")
	var bits := key.split("|")
	var paid: Dictionary = TreeRules.learn_skipped(main.profile, bits[0], bits[1])
	if not paid.is_empty():
		main.profile.save()
		main._give_bonds()
		main.sfx("ready", 1.1)
		menu.toast = TEXT["learned"] % Library.variation(bits[1]).get("name", bits[1])
		menu.toast_t = 3.0
	menu._want_focus = {"meta": "bud", "value": key}
	menu.open("climber", menu.opened_direct)


# --- the dev tools ----------------------------------------------------------------------

## The dev page's "The tree": forget every choice (to try the forks again),
## and open the book on the Tree.
static func dev_section(menu) -> void:
	var main = menu.main
	var prof = main.profile
	menu._section(TEXT["dev"])
	var ready: Array = TreeRules.ready_forks(prof)
	menu.box.add_child(menu._label(TEXT["dev_head"] % [TreeRules.owned(prof).size(), ready.size()], 0.0, menu.GOLD if not ready.is_empty() else menu.DIM))
	var r: HBoxContainer = menu._row()
	var b: Button = menu._button(TEXT["dev_forget"], func():
		prof.tree = {}
		TreeRules.state(prof)
		prof.save()
		main._give_bonds()
		menu.open("dev"), r)
	b.set_meta("tree_forget", true)
	menu._button(TEXT["dev_open"], func():
		menu.climber_tab = "tree"
		menu.open("climber"), r)


# --- the drawing ---------------------------------------------------------------------------

## The body map: the climber's figure (menu.gd BodyView: the figure, its
## marks or veins and the parts' names) with a node on each body part. A
## part with a ready fork pulses gold; the chosen part is ringed in gilt.
class BodyMap extends Control:
	var menu
	var part := ""
	var nodes := {}  # part -> PartNode

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var view = menu.get_script().BodyView.new()
		view.main = menu.main
		view.set_anchors_preset(Control.PRESET_FULL_RECT)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(view)
		var TR = load("res://scripts/tree.gd")
		for pt in view.ORDER:
			var n := PartNode.new()
			n.part = pt
			n.on = pt == part
			n.ready_fork = TR.is_fork_ready(menu.main.profile, pt)
			n.col = load("res://scripts/tree_view.gd")._part_color(menu.main.profile, pt)
			n.set_meta("part", pt)
			n.set_meta("tree_part", pt)
			n.tooltip_text = String(load("res://scripts/bonds.gd").PART_NAMES[pt])
			n.pressed.connect(func(): load("res://scripts/tree_view.gd").pick_part(menu, pt))
			add_child(n)
			nodes[pt] = n
		resized.connect(_place)
		_place.call_deferred()

	## The nodes sit on the figure's parts (as BodyView places the marks).
	func _place() -> void:
		var BV = menu.get_script().BodyView
		var k := minf(size.y / 292.0, size.x / 316.0)
		var c := Vector2(size.x * 0.5, size.y * 0.5 + 4.0 * k)
		var r := maxf(10.0, 12.0 * k)
		for pt in nodes:
			var n: Control = nodes[pt]
			n.size = Vector2(r, r) * 2.0
			n.position = c + BV.SPOTS[pt] * k - Vector2(r, r)


## A body part's node on the map: a ring in its mark's colour (a ready fork
## pulses gold), the chosen part filled.
class PartNode extends Button:
	const UI := preload("res://scripts/ui.gd")
	var part := ""
	var on := false
	var ready_fork := false
	var col := Color.WHITE

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())

	func _process(_delta: float) -> void:
		if ready_fork or has_focus() or is_hovered():
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.0
		var t := Time.get_ticks_msec() * 0.001
		if ready_fork:
			var p := 0.5 + 0.5 * sin(t * 4.0)
			draw_circle(c, r + 4.0 * p, Color(UI.GILT, 0.18 + 0.2 * p))
		draw_circle(c, r, Color(0.05, 0.04, 0.05, 0.55 if not on else 0.8))
		draw_arc(c, r, 0.0, TAU, 28, col if not ready_fork else UI.GILT_HI, 2.4 if on else 1.6, true)
		if on:
			draw_arc(c, r + 3.0, 0.0, TAU, 28, UI.GILT_HI, 1.4, true)
			draw_circle(c, r * 0.45, col)
		if is_hovered() or (has_focus() and not _touching()):
			draw_arc(c, r + 5.0, 0.0, TAU, 28, Color(UI.GILT, 0.6), 2.0, true)

	func _touching() -> bool:
		var n := get_parent()
		while n != null:
			if n.has_method("rail_showing"):
				return n.main != null and n.main.touch_active
			n = n.get_parent()
		return false


## The stem beside a node: the trunk running down through the tree and a dot
## for the node (gold for a ready fork, filled once it's yours); a fork's
## stem splits.
class Stem extends Control:
	const UI := preload("res://scripts/ui.gd")
	var state := ""
	var fork := false
	var last := false
	var col := Color.WHITE

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var x := size.x * 0.5
		var y := size.y * 0.5
		var line := Color(col, 0.55) if state == "owned" else Color(UI.FAINT, 0.5)
		draw_line(Vector2(x, 0), Vector2(x, y if last else size.y), line, 2.0)
		if fork:
			draw_line(Vector2(x, y), Vector2(size.x, y - 6.0), line, 1.5, true)
			draw_line(Vector2(x, y), Vector2(size.x, y + 6.0), line, 1.5, true)
		var dot := col if state == "owned" else (UI.GILT_HI if state == "ready" else Color(0.18, 0.16, 0.2))
		draw_circle(Vector2(x, y), 5.0, UI.OUTLINE)
		draw_circle(Vector2(x, y), 4.0, dot)
		if state in ["later", "locked"]:
			draw_arc(Vector2(x, y), 4.0, 0.0, TAU, 12, Color(UI.FAINT, 0.8), 1.0, true)


## A bud: one option on the tree, a pill with its name, coloured by what it
## is to you (tree.gd option states).
class Bud extends Button:
	const UI := preload("res://scripts/ui.gd")
	var option := {}
	var ready_fork := false
	var selected := false
	var small := false

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		clip_text = true
		custom_minimum_size = Vector2(0, 30 if small else 32)
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
			add_theme_color_override(c, Color(0, 0, 0, 0))
		var f: Font = UI.font("display")
		custom_minimum_size.x = minf(f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 40.0, 200.0)

	func _process(_delta: float) -> void:
		if (ready_fork and String(option.get("state", "")) == "available") or has_focus() or is_hovered():
			queue_redraw()

	func _draw() -> void:
		var st := String(option.get("state", ""))
		var col: Color = option.get("color", UI.GILT)
		var r := Rect2(Vector2(1, 2), size - Vector2(2, 4))
		var pill := UI.rounded(r, r.size.y * 0.5)
		var fill := Color(0.08, 0.07, 0.08, 0.85)
		var edge := Color(UI.FAINT, 0.6)
		var tc := UI.DIM
		var t := Time.get_ticks_msec() * 0.001
		match st:
			"owned":
				fill = col.darkened(0.55)
				edge = col.lightened(0.1)
				tc = UI.TEXT
			"in_use":
				fill = col.darkened(0.62)
				edge = Color(UI.GILT, 0.7)
				tc = UI.TEXT
			"available":
				var p := 0.5 + 0.5 * sin(t * 4.0) if ready_fork else 1.0
				fill = Color(UI.GILT_DEEP, 0.5 + 0.3 * p)
				edge = UI.GILT.lerp(UI.GILT_HI, p)
				tc = UI.GILT_HI
			"learnable":
				fill = Color(UI.VIOLET, 0.12)
				edge = Color(UI.VIOLET, 0.8)
				tc = UI.VIOLET
			"passed":
				fill = Color(0.07, 0.06, 0.07, 0.5)
				edge = Color(UI.FAINT, 0.35)
				tc = Color(UI.FAINT, 0.7)
			"placeholder", "later":
				fill = Color(0.06, 0.055, 0.065, 0.5)
				edge = Color(UI.FAINT, 0.35)
				tc = Color(UI.FAINT, 0.85)
		draw_colored_polygon(pill, fill)
		var loop := pill.duplicate()
		loop.append(loop[0])
		if st in ["placeholder", "later"]:
			for i in range(0, loop.size() - 1, 2):
				draw_line(loop[i], loop[i + 1], edge, 1.2, true)
		else:
			draw_polyline(loop, edge, 1.6 if st in ["owned", "available"] else 1.0, true)
		# Its dot: what it is to you.
		var dc := Vector2(r.position.x + r.size.y * 0.5 + 2.0, r.get_center().y)
		if st == "locked":
			UI.draw_lock(self, dc, 5.0, UI.FAINT)
		else:
			draw_circle(dc, 4.0, col if st in ["owned", "in_use"] else (UI.GILT_HI if st == "available" else Color(UI.FAINT, 0.6)))
		var fs := 14 if small else 15
		UI.draw_label(self, Vector2(dc.x + 9.0, r.get_center().y + fs * 0.33), text, fs, tc, HORIZONTAL_ALIGNMENT_LEFT, r.end.x - dc.x - 16.0)
		if st == "passed":
			draw_line(Vector2(dc.x + 8.0, r.get_center().y), Vector2(r.end.x - 10.0, r.get_center().y), Color(UI.FAINT, 0.5), 1.0)
		if selected:
			var ring := UI.rounded(r.grow(2.5), r.size.y * 0.5 + 2.5)
			ring.append(ring[0])
			draw_polyline(ring, UI.GILT_HI, 1.4, true)
		if (has_focus() and not _touching()) or is_hovered():
			var ring := UI.rounded(r.grow(3.5), r.size.y * 0.5 + 3.5)
			ring.append(ring[0])
			draw_polyline(ring, Color(UI.GILT, 0.35), 4.0, true)

	func _touching() -> bool:
		var n := get_parent()
		while n != null:
			if n.has_method("rail_showing"):
				return n.main != null and n.main.touch_active
			n = n.get_parent()
		return false
