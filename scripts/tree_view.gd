extends RefCounted
## THE TREE SECTION of the book (menu.gd's climber page, "tree"): the body
## map. The climber stands on the left, each body part a node on the figure.
## The chosen part's tree grows out of the figure across the page like a
## mark spreading: a branch in the bond's colour leaves the mark, crosses to
## a root bearing its emblem and runs down as a trunk, a node for each step
## (marks) or level (the Unbound), each node's options a bud on a twig (a
## fork's two sides on two twigs). For the Unbound the branch is a vein of
## raw essence in the part's colour that flickers hot with strain. The
## chosen bud's grimoire card (grimoire_card.gd) and what you can do with it
## are below.
##
## Buds show what each piece is to you: yours (it glows), in use until you
## choose (today's side of a ready fork), a ready choice (pulsing gold),
## locked (a lock, and what opens it), passed on (faded, struck through),
## learnable again (the Unbound, violet), and "Coming later" (faint and
## dashed: not written yet, it can't be chosen). Every option comes from
## the tree's data (tree.gd nodes), never a list here, so new content shows
## by itself, each with the glyph its data suggests (grimoire_card.gd glyph_for).
## Choosing is for good, so it takes a second press (the first only arms
## it); the Entity says so the first time a fork is ready (entity.gd TIPS "tree_fork").
##
## Reaching it: a tap on a part, then a bud; the stick or d-pad up and down
## the parts, Right onto the branch, then up and down along it (Left and
## Right between a node's buds), A or Enter to read a bud and again to
## choose; the mouse points and clicks. Every Abilities entry links here
## ("On the body map": open_tree) and every bud's card links back ("In your
## abilities"); a star in Your Car's window opens it on a part with a ready
## fork (train_view.gd SkyStar).
##
## All the drawing is in this file (TreeMap, its Layer of things drawn once
## and its live Layer of what glows, PartNode, Bud) so it can be restyled
## without touching the rules (tree.gd) or the book (book.gd). Only the live
## layer is drawn every frame, and it is a few dozen shapes.

const TreeRules := preload("res://scripts/tree.gd")
const Library := preload("res://scripts/library.gd")
const Unbound := preload("res://scripts/unbound.gd")
const Bonds := preload("res://scripts/bonds.gd")
const UI := preload("res://scripts/ui.gd")
const GrimoireCard := preload("res://scripts/grimoire_card.gd")
const Controls := preload("res://scripts/controls.gd")

static var TEXT := {
	"passive_rank": "%s grows to %s: %s.",
	"head_mark": "%s  ·  %s  ·  step %d of %d",
	"head_faint": "%s  ·  %s  ·  faint",
	"head_unbound": "%s  ·  level %d of 10",
	"head_none": "%s  ·  no mark yet",
	"none": "No mark here yet. This part %s; once it's full, a summit marks it.",
	"first": "Your first climb is bondless. At its top the tower's beast takes notice, and the part you used most takes your first mark. Its tree grows here.",
	"or": "or",
	"steps": "Steps %d–%d",
	"steps_short": "steps %d–%d",
	"effects": "Essences",
	"choose": "Choose %s, for good",
	"choose_again": "%s to choose %s, for good",
	"learn": "Learn %s  ·  %d crystal essence",
	"learn_again": "%s to learn it  ·  %d crystal essence",
	"learn_short": "Needs %d crystal essence",
	"learn_bud": "%d crystal",
	"chosen": "%s chosen. It's yours for good.",
	"learned": "%s learned.",
	"state": {"owned": "yours", "in_use": "in use until you choose", "available": "choose one", "passed": "passed on", "learnable": "you can learn it now",
		"locked": "%s", "placeholder": "Coming later", "later": "Coming later"},
	"in_use_bud": "in use",
	"opens": "opens %s",
	"only_train": "Choices are made on the train.",
	"spell_cost": "costs %d",
	"strain": "+%d strain",
	"press": "press %s",
	"in_abilities": "In your abilities",
	"on_map": "On the body map",
	"dev": "The tree",
	"dev_head": "%d pieces owned  ·  %d choices ready",
	"dev_forget": "Forget every choice",
	"dev_open": "Open the Tree",
}
## How long an armed choice waits for its second press (ms).
const ARM_MS := 4000
## The body map's layout, [computer, phone]: the figure's size beside the
## tree, a line of buds, a bud's height, and the narrowest room that still
## takes the figure and the tree side by side (narrower: the tree goes under it).
const FIG_SIZE := [Vector2(300, 300), Vector2(272, 240)]
const LINE_H := [32.0, 34.0]
const BUD_H := [27.0, 30.0]
const SIDE_BY_SIDE := [600.0, 560.0]
## How long a bud reached by a link glows (ms).
const FLASH_MS := 2200


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
	var sel := _selected(menu, nodes)
	var map := TreeMap.new()
	map.menu = menu
	map.part = part
	map.nodes = nodes
	map.fx = TreeRules.effect_rows(prof, part) if Unbound.is_on(prof) else []
	map.sel = sel
	map.small = small
	map.head_text = _head(prof, part)
	if nodes.is_empty():
		map.note_text = TEXT["first"] if prof.bonds.is_empty() and not Unbound.is_on(prof) else TEXT["none"] % String(Bonds.PART_FILLS[part])
	# A bud reached by a link ("On the body map"): it glows a moment.
	if menu.has_meta("tree_flash"):
		map.flash = String(menu.get_meta("tree_flash"))
		map.flash_at = Time.get_ticks_msec()
		menu.remove_meta("tree_flash")
	menu.box.add_child(map)
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


## The first part with a ready fork ("" if none).
static func ready_part(prof) -> String:
	for pt in Bonds.PARTS:
		if TreeRules.is_fork_ready(prof, pt):
			return pt
	return ""


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


# --- the links: Abilities <-> the Tree, and the window's star ------------------------------

## Turns the book to the Tree on a part, a bud chosen (`key`: "node|option",
## or "" for the part's own first) and glowing a moment. (Abilities' "On the
## body map", the window's star, the dev page.)
static func open_tree(menu, part: String, key := "") -> void:
	menu.set_meta("tree_part", part)
	if menu.has_meta("tree_arm"):
		menu.remove_meta("tree_arm")
	if key != "":
		menu.set_meta("tree_sel", key)
		menu.set_meta("tree_flash", key)
		menu._want_focus = {"meta": "bud", "value": key}
	else:
		if menu.has_meta("tree_sel"):
			menu.remove_meta("tree_sel")
		menu._want_focus = {"meta": "part", "value": part}
	if menu.page == "climber" and menu.climber_tab != "tree":
		menu._set_climber_tab("tree")  # (the page turns)
		return
	menu.climber_tab = "tree"
	menu.open("climber", menu.opened_direct if menu.page == "climber" else true)


## Where an Abilities entry sits on the tree: [part, bud key] ([] if nowhere).
## A spell is the bud of its own id; a technique the bud of its form on its
## part's tree; a mark its part.
static func node_of(main, e: Dictionary) -> Array:
	var prof = main.profile
	var part := String(e.get("part", ""))
	var want := String(e.get("id", ""))
	var kind := String(e.get("kind", ""))
	if kind == "empty" or not part in Bonds.PARTS:
		return []
	if kind == "mark":
		return [part, ""]
	if kind == "technique" and e.get("tech") is Dictionary:
		part = String(e["tech"].get("part", part))
		want = String(e["tech"].get("shape", ""))
	for n in TreeRules.nodes(prof, part):
		for o in n["options"]:
			if String(o["id"]) == want or String(o.get("form", "")) == want:
				return [part, "%s|%s" % [n["id"], o["id"]]]
	return [part, ""] if kind == "technique" or not TreeRules.nodes(prof, part).is_empty() else []


## The Abilities entry a tree option is part of ("" if none): a spell is its
## own entry (a step-3 variation is the first spell it changes); for the
## Unbound, the technique made of that form, variation or effect on that part.
static func ability_of(main, part: String, node: Dictionary, opt: Dictionary) -> String:
	var st := String(opt.get("state", ""))
	if not st in ["owned", "in_use", "locked"]:
		return ""
	var list: Array = load("res://scripts/abilities.gd").entries(main)
	var id := String(opt.get("id", ""))
	if node.get("path", "") == "mark":
		if String(opt.get("kind", "")) == "variation":
			if st == "locked":
				return ""
			id = String(TreeRules.base_spell(String(node.get("bond", "")), 1).get("id", ""))
		for e in list:
			if e.get("kind", "") == "spell" and String(e["id"]) == id:
				return id
		return ""
	if st == "locked":
		return ""
	for e in list:
		var t = e.get("tech")
		if not (t is Dictionary) or String(t.get("part", "")) != part:
			continue
		match String(opt.get("kind", "")):
			"form":
				if String(t.get("shape", "")) == String(opt.get("form", id)):
					return String(e["id"])
			"variation":
				if id in t.get("vars", []):
					return String(e["id"])
	return ""


## Turns the book to Abilities with an entry picked out (it glows, and the
## page scrolls to it).
static func open_abilities(menu, id: String) -> void:
	menu.set_meta("abilities_focus", id)
	menu._want_focus = {"meta": "ability", "value": id}
	menu._set_climber_tab("abilities")


# --- the card under the map -------------------------------------------------------------

## The chosen bud's grimoire card and, if it can be chosen or learned, the
## button; and "In your abilities" when it's something you can cast.
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
					"tag": TEXT["state"].get(e["state"], "") if e["state"] != "locked" else TEXT["opens"] % e["needs"], "tag_color": UI.FAINT, "state": e["state"],
					"glyph": GrimoireCard.effect_glyph(String(e["id"])), "affinity": String(e.get("kind", "")) if e["state"] == "owned" else ""}
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
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.set_meta("tree_actions", true)
	menu.box.add_child(row)
	# Choose it (a ready fork), or learn it again (the Unbound's passed side).
	var key := "%s|%s" % [node["id"], opt["id"]]
	var armed := String(menu.get_meta("tree_arm", "")) == key and Time.get_ticks_msec() - int(menu.get_meta("tree_arm_at", 0)) < ARM_MS
	var again := _again(main)
	if node.get("state", "") == "ready" and opt["state"] in ["available", "in_use"] and opt["built"]:
		var b: Button = menu._button(TEXT["choose_again"] % [again, opt["name"]] if armed else TEXT["choose"] % opt["name"], _choose.bind(menu, key), row)
		b.set_meta("tree_act", "choose")
		b.custom_minimum_size.y = 42.0
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if armed:
			menu._primary(b)
	elif opt.get("state", "") == "learnable":
		var cost := int(opt.get("cost", 0))
		var can: bool = prof.crystals_held() >= float(cost)
		var text: String = (TEXT["learn_again"] % [again, cost] if armed else TEXT["learn"] % [opt["name"], cost]) if can else TEXT["learn_short"] % cost
		var b: Button = menu._button(text, _learn.bind(menu, key), row)
		b.set_meta("tree_act", "learn")
		b.disabled = not can
		b.custom_minimum_size.y = 42.0
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if armed:
			menu._primary(b)
	# Back the other way: the entry in Abilities this is part of.
	var ab := ability_of(main, part, node, opt)
	if ab != "":
		if row.get_child_count() == 0:
			row.alignment = BoxContainer.ALIGNMENT_END
		var lb: Button = menu._button(TEXT["in_abilities"], open_abilities.bind(menu, ab), row)
		lb.set_meta("tree_link", ab)
		lb.custom_minimum_size = Vector2(170.0 if not small else 150.0, 42.0)
	if row.get_child_count() == 0:
		row.queue_free()
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
	# A mark's step that grows its passive a rank (bonds.gd PASSIVE_STEPS) says so too.
	if node.get("path", "") == "mark" and int(node.get("at", 0)) in Bonds.PASSIVE_STEPS and opt.get("kind", "") != "later":
		var rank := Bonds.passive_rank(int(node["at"]))
		var line := Bonds.passive_line(String(node["bond"]), rank)
		if line != "":
			does += " " + TEXT["passive_rank"] % [String(Bonds.BONDS[node["bond"]]["passive"]["name"]), Bonds.RANK_NAMES[rank], line]
	var e := {"id": opt["id"], "kind": opt.get("kind", ""), "part": part, "name": opt["name"], "color": opt.get("color", UI.GILT),
		"does": does, "tag": tag, "tag_color": UI.GOLD if st in ["available", "in_use", "learnable"] else (UI.GOOD if st == "owned" else UI.FAINT),
		"state": st, "locked": st == "locked"}
	e["glyph"] = bud_glyph(node, opt)
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
	return e


## The small drawing for a tree option, from its data (grimoire_card.gd
## glyph_for): a form's, a variation's, a spell's, or the node's kind's.
## A step-3 change without a library variation reads its own words.
static func bud_glyph(node: Dictionary, opt: Dictionary) -> String:
	var kind := String(opt.get("kind", ""))
	if kind == "later":
		return ""
	if kind == "form":
		return GrimoireCard.form_glyph(String(opt.get("form", opt.get("id", ""))))
	if kind == "variation":
		var v := String(opt.get("variation", opt.get("id", "")))
		if Library.VARIATIONS.has(v):
			return GrimoireCard.variation_glyph(v)
		var g := GrimoireCard.from_words(String(opt.get("says", "")) + " " + String(opt.get("name", "")))
		return g if g != "" else "spark"
	if kind == "spell":
		var sp: Dictionary = opt.get("spell", {}) if opt.get("spell") is Dictionary else {}
		if not opt.get("built", true) and not sp.has("type"):
			sp = {"desc": opt.get("says", ""), "name": opt.get("name", "")}
		return GrimoireCard.spell_glyph(sp)
	return GrimoireCard.glyph_for({"kind": kind, "id": opt.get("id", "")})


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
		menu.set_meta("tree_flash", key)  # (the bud just taken glows a moment)
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
		menu.set_meta("tree_flash", key)
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

## The body map: the figure (menu.gd BodyView's figure, with the marks or
## veins and the parts' names), a PartNode on each part, and the chosen
## part's tree growing out of it (see the top of this file). Laid out for
## the room it's given: side by side, or the tree under the figure on a
## narrow screen (a phone at a big Interface size). What doesn't move is
## drawn once (still); what glows is drawn each frame (live).
class TreeMap extends Control:
	const UI := preload("res://scripts/ui.gd")
	const Bonds := preload("res://scripts/bonds.gd")
	const Unbound := preload("res://scripts/unbound.gd")
	const Makers := preload("res://scripts/makers.gd")
	const Secret := preload("res://scripts/secret.gd")
	const Essence := preload("res://scripts/essence.gd")
	var View  # (this file: its words, rules and links)
	var menu
	var main
	var BV  # menu.gd BodyView: the figure and where its marks sit
	var part := ""
	var nodes: Array = []
	var fx: Array = []
	var sel := ""
	var small := false
	var head_text := ""
	var note_text := ""
	var flash := ""
	var flash_at := 0
	var unbound := false
	var col := Color.WHITE
	var affinity := ""
	var step := 0
	var faint := false
	var still: Control
	var live: Control
	var head: Label
	var note: Label
	var parts := {}  # part -> PartNode
	var buds := {}  # bud key -> Bud
	var rows: Array = []  # the nodes shown (the steps still to come share one)
	var lay := {}  # where everything goes (_lay_out)
	var lines: Array = []  # the buds in lines, top to bottom (the d-pad walks them)
	var conn := PackedVector2Array()  # the branch from the mark to the root
	var trunk: Array = []  # [points, state] from the root down, a piece per node
	var twigs: Array = []  # [points, option state] from a node to each bud
	var _laid_w := -1.0

	func _ready() -> void:
		main = menu.main
		View = load("res://scripts/tree_view.gd")
		BV = menu.get_script().BodyView
		var prof = main.profile
		unbound = Unbound.is_on(prof)
		col = View._part_color(prof, part)
		if unbound:
			affinity = String(Unbound.PART_KIND.get(part, ""))
		elif prof.bonds.has(part):
			var info: Dictionary = prof.bonds[part]
			affinity = String(Bonds.BONDS[info["id"]]["affinity"])
			step = prof.step_for_xp(float(info.get("xp", 0.0)))
			faint = bool(info.get("faint", false))
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		still = Layer.new()
		still.paint = _paint_still
		add_child(still)
		live = Layer.new()
		live.paint = _paint_live
		live.every_frame = true
		add_child(live)
		head = Label.new()
		head.text = head_text
		UI.style_label(head, "display", 19 if small else 22, col.lightened(0.2))
		head.clip_text = true
		head.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		head.set_meta("tree_head", part)
		add_child(head)
		if note_text != "":
			note = Label.new()
			note.text = note_text
			note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			UI.style_label(note, "body", 15, UI.DIM)
			add_child(note)
		_gather_rows()
		for pt in BV.ORDER:
			var n := PartNode.new()
			n.menu = menu
			n.part = pt
			n.on = pt == part
			n.ready_fork = View.TreeRules.is_fork_ready(prof, pt)
			n.col = View._part_color(prof, pt)
			n.set_meta("part", pt)
			n.set_meta("tree_part", pt)
			n.tooltip_text = String(Bonds.PART_NAMES[pt])
			n.pressed.connect(func(): View.pick_part(menu, pt))
			add_child(n)
			parts[pt] = n
		for r in rows:
			for o in r["options"]:
				var key := "%s|%s" % [r["id"], o["id"]]
				var b := Bud.new()
				b.menu = menu
				b.option = o
				b.ready_fork = r["state"] == "ready"
				b.selected = key == sel
				b.small = small
				b.text = o["name"]
				b.aux = _aux(r, o)
				b.glyph = View.bud_glyph(r, o)
				b.flash_until = flash_at + View.FLASH_MS if key == flash else 0
				b.set_meta("bud", key)
				b.set_meta("bud_state", o.get("state", ""))
				b.pressed.connect(func(): View._select(menu, key))
				add_child(b)
				buds[key] = b
		for e in fx:
			var key := "fx:%s" % e["id"]
			var b := Bud.new()
			b.menu = menu
			b.option = {"id": e["id"], "name": e["name"], "state": e["state"], "built": e["built"], "color": e["color"]}
			b.selected = sel == key
			b.small = small
			b.text = e["name"]
			b.glyph = load("res://scripts/grimoire_card.gd").effect_glyph(String(e["id"]))
			b.flash_until = flash_at + View.FLASH_MS if key == flash else 0
			b.set_meta("bud", key)
			b.set_meta("bud_state", e["state"])
			b.pressed.connect(func(): View._select(menu, key))
			add_child(b)
			buds[key] = b
		resized.connect(_relay)
		# A first guess at the room (the page's width), so its height is
		# right from the start; laid out again once it has its size.
		var guess := 760.0
		if menu.scroll != null and menu.scroll.custom_minimum_size.x > 0.0:
			guess = menu.scroll.custom_minimum_size.x - (32.0 if small else 60.0)
		_lay_out(maxf(guess, 300.0))
		custom_minimum_size = Vector2(300.0, lay["h"])
		_apply.call_deferred()

	## The nodes as shown: the steps still to come, past today's top step, share one.
	func _gather_rows() -> void:
		var later: Array = nodes.filter(func(n): return n["kind"] == "later")
		for n in nodes:
			if n["kind"] == "later":
				if n != later[0]:
					continue
				var m: Dictionary = n.duplicate()
				if later.size() > 1:
					m["title"] = View.TEXT["steps"] % [int(later[0]["at"]), int(later[-1]["at"])]
					m["short"] = View.TEXT["steps_short"] % [int(later[0]["at"]), int(later[-1]["at"])]
					m["span"] = "%d+" % int(later[0]["at"])
				rows.append(m)
			else:
				rows.append(n)

	## The few words at a bud's right: what opens it, what learning it costs, "in use".
	func _aux(r: Dictionary, o: Dictionary) -> String:
		match String(o.get("state", "")):
			"locked":
				return String(r.get("needs", ""))
			"learnable":
				return View.TEXT["learn_bud"] % int(o.get("cost", 0))
			"in_use":
				return View.TEXT["in_use_bud"]
			"placeholder":
				return String(r.get("short", ""))
		return ""

	func _relay() -> void:
		if absf(size.x - _laid_w) > 0.5:
			_apply()

	## Lays everything out for the width it has and places the buttons.
	func _apply() -> void:
		if not is_inside_tree():
			return
		var w := size.x if size.x > 1.0 else custom_minimum_size.x
		_lay_out(w)
		_laid_w = w
		still.size = Vector2(w, lay["h"])
		live.size = still.size
		head.position = lay["head"].position
		head.size = lay["head"].size
		if note != null:
			note.position = lay["note"].position
			note.size = lay["note"].size
		var pr: float = lay["node_r"]
		for pt in parts:
			var n: Control = parts[pt]
			n.size = Vector2(pr, pr) * 2.0
			n.position = lay["spots"][pt] - Vector2(pr, pr)
		for key in buds:
			var r: Rect2 = lay["buds"].get(key, Rect2())
			buds[key].position = r.position
			buds[key].size = r.size
			buds[key].visible = r.size.x > 0.0
		_link_focus()
		if absf(custom_minimum_size.y - lay["h"]) > 0.5:
			custom_minimum_size.y = lay["h"]
		still.queue_redraw()

	## The d-pad and the stick: up and down the parts on the figure, Right
	## onto the branch (the chosen bud); along the branch up and down from
	## line to line, Left and Right between a line's buds, Left off its
	## start back to the part.
	func _link_focus() -> void:
		var order: Array = BV.ORDER
		var into: Control = buds.get(sel, null)
		if into == null and not lines.is_empty():
			into = buds[lines[0][0]]
		for i in order.size():
			var n: Control = parts[order[i]]
			n.focus_neighbor_top = n.get_path_to(parts[order[i - 1]]) if i > 0 else NodePath()
			n.focus_neighbor_bottom = n.get_path_to(parts[order[i + 1]]) if i < order.size() - 1 else NodePath()
			n.focus_neighbor_right = n.get_path_to(into) if into != null else NodePath()
		var back: Control = parts[part]
		for li in lines.size():
			var line: Array = lines[li]
			for j in line.size():
				var b: Control = buds[line[j]]
				b.focus_neighbor_left = b.get_path_to(buds[line[j - 1]] if j > 0 else back)
				b.focus_neighbor_right = b.get_path_to(buds[line[j + 1]]) if j < line.size() - 1 else NodePath()
				b.focus_neighbor_top = b.get_path_to(buds[lines[li - 1][mini(j, lines[li - 1].size() - 1)]]) if li > 0 else NodePath()
				b.focus_neighbor_bottom = b.get_path_to(buds[lines[li + 1][mini(j, lines[li + 1].size() - 1)]]) if li < lines.size() - 1 else NodePath()

	# --- the layout -------------------------------------------------------------------

	func _lay_out(W: float) -> void:
		var i := 1 if small else 0
		var wide: bool = W >= float(View.SIDE_BY_SIDE[i])
		var fs: Vector2 = View.FIG_SIZE[i]
		var fig_w: float = clampf(W * 0.4, 240.0, fs.x) if wide else minf(W, fs.x + 30.0)
		var fig_h: float = fs.y if wide else fs.y * 0.9
		var k := minf(fig_h / 292.0, fig_w / 316.0)
		var fc := Vector2(fig_w * 0.5, fig_h * 0.5 + 4.0 * k)
		if not wide:
			fc.x = W * 0.5
		var spots := {}
		for pt in BV.ORDER:
			spots[pt] = fc + BV.SPOTS[pt] * k
		lay = {"wide": wide, "k": k, "fc": fc, "fig": Rect2(0, 0, fig_w, fig_h), "spots": spots, "node_r": minf(15.5 * k, maxf(13.0 if small else 12.0, 13.0 * k)), "buds": {}, "rows": []}
		var tx: float = (fig_w + (16.0 if small else 26.0)) if wide else 0.0
		var top: float = 4.0 if wide else fig_h + 6.0
		var trunk_x := tx + 14.0
		var head_h := 28.0 if small else 32.0
		lay["root"] = Vector2(trunk_x, top + head_h * 0.5)
		lay["head"] = Rect2(trunk_x + 20.0, top, maxf(W - trunk_x - 20.0, 40.0), head_h)
		var lh: float = View.LINE_H[i]
		var bh: float = View.BUD_H[i]
		var bx := trunk_x + 34.0
		var avail := maxf(W - bx - 2.0, 120.0)
		var y := top + head_h + 6.0
		var font: Font = UI.font("display")
		var fsz := 14 if small else 15
		lines.clear()
		for ri in rows.size():
			var r: Dictionary = rows[ri]
			var opts: Array = r["options"]
			var fork: bool = r["kind"] == "fork" and opts.size() > 1
			var nat: Array = opts.map(func(o): return _bud_w(r, o, font, fsz, bh))
			var widths: Array = []
			var packed: Array = []
			if fork:
				var w := minf(avail, nat.max())
				for j in opts.size():
					widths.append(w)
					packed.append([j])
			else:
				var cur: Array = []
				var used := 0.0
				for j in opts.size():
					var wj := minf(float(nat[j]), avail)
					widths.append(wj)
					if not cur.is_empty() and used + 8.0 + wj > avail:
						packed.append(cur)
						cur = []
						used = 0.0
					cur.append(j)
					used += (8.0 if used > 0.0 else 0.0) + wj
				if not cur.is_empty():
					packed.append(cur)
			var block := maxf(1.0, packed.size()) * lh
			var disc := Vector2(trunk_x + (2.5 if ri % 2 == 0 else -2.5) * (1.6 if unbound else 1.0), y + block * 0.5)
			var rl := {"disc": disc, "fork": fork, "keys": []}
			for li in packed.size():
				var by := y + lh * (li + 0.5)
				var x := bx
				var line: Array = []
				for j in packed[li]:
					var key := "%s|%s" % [r["id"], opts[j]["id"]]
					lay["buds"][key] = Rect2(x, by - bh * 0.5, widths[j], bh)
					rl["keys"].append(key)
					line.append(key)
					x += widths[j] + 8.0
				lines.append(line)
			lay["rows"].append(rl)
			y += block + 4.0
		if not fx.is_empty():
			y += 4.0
			lay["fx_head"] = Vector2(bx, y + 13.0)
			y += 20.0
			var x := bx
			var line: Array = []
			for e in fx:
				var key := "fx:%s" % e["id"]
				var w := minf(font.get_string_size(UI.title_case(String(e["name"])), HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x + bh + 24.0, avail)
				if not line.is_empty() and x + w > bx + avail:
					lines.append(line)
					line = []
					x = bx
					y += lh
				lay["buds"][key] = Rect2(x, y + (lh - bh) * 0.5, w, bh)
				line.append(key)
				x += w + 8.0
			if not line.is_empty():
				lines.append(line)
				y += lh
		lay["note"] = Rect2(tx + 8.0, top + head_h + 2.0, maxf(W - tx - 12.0, 100.0), 90.0)
		if note_text != "":
			y = maxf(y, top + head_h + 96.0)
		lay["h"] = maxf(y + 4.0, fig_h + 4.0 if wide else 0.0)
		_paths()

	## How wide a bud wants to be: its glyph, its name and its few words.
	func _bud_w(r: Dictionary, o: Dictionary, font: Font, fsz: int, bh: float) -> float:
		var w := font.get_string_size(UI.title_case(String(o.get("name", ""))), HORIZONTAL_ALIGNMENT_LEFT, -1, fsz).x + bh + 22.0
		var aux := _aux(r, o)
		if aux != "":
			w += UI.font("body").get_string_size(aux, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 12.0
		return clampf(w, 150.0 if small else 168.0, 300.0)

	## The branch, the trunk and the twigs as smooth curves (worked out once per layout).
	func _paths() -> void:
		conn = PackedVector2Array()
		trunk.clear()
		twigs.clear()
		if rows.is_empty():
			return
		var k: float = lay["k"]
		var s: Vector2 = lay["spots"][part]
		var root: Vector2 = lay["root"]
		if lay["wide"]:
			var end := root - Vector2(13.0, 0.0)
			var dx := end.x - s.x
			conn = _bezier(s, s + Vector2(dx * 0.42, 34.0 * k), end - Vector2(dx * 0.38, 0.0), end, 30, 2.2)
		else:
			var end := root - Vector2(0.0, 13.0)
			conn = _bezier(s, s + Vector2(0.0, 46.0 * k), end - Vector2(0.0, 40.0), end, 30, 2.2)
		if unbound:
			conn = _jag(conn, 2.2)  # (raw essence: a vein, not a vine)
		var prev := root + Vector2(0.0, 11.0)
		for ri in rows.size():
			var d: Vector2 = lay["rows"][ri]["disc"]
			var p1 := d - Vector2(0.0, 8.0)
			var h := (p1.y - prev.y) * 0.5
			trunk.append([_bezier(prev, prev + Vector2(0, h), p1 - Vector2(0, h), p1, 10, 0.0), rows[ri]["state"]])
			prev = d + Vector2(0.0, 8.0)
			for key in lay["rows"][ri]["keys"]:
				var r: Rect2 = lay["buds"][key]
				var a := d + Vector2(8.0, 0.0)
				var z := Vector2(r.position.x - 1.0, r.get_center().y)
				var o: Dictionary = buds[key].option if buds.has(key) else {}
				twigs.append([_bezier(a, a + Vector2((z.x - a.x) * 0.55, 0.0), z - Vector2((z.x - a.x) * 0.45, 0.0), z, 10, 0.0), String(o.get("state", "")), key])

	## A cubic curve as points; `wave` bends it a little, like something grown.
	static func _bezier(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, n: int, wave: float) -> PackedVector2Array:
		var out := PackedVector2Array()
		for i in n + 1:
			var t := float(i) / n
			var u := 1.0 - t
			var p := u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3
			if wave > 0.0 and i > 0 and i < n:
				var tan := (3.0 * u * u * (p1 - p0) + 6.0 * u * t * (p2 - p1) + 3.0 * t * t * (p3 - p2)).normalized()
				p += tan.orthogonal() * sin(t * PI * 3.0) * sin(t * PI) * wave
			out.append(p)
		return out

	## A path made ragged, like a vein (its ends stay put).
	static func _jag(path: PackedVector2Array, amp: float) -> PackedVector2Array:
		var out := path.duplicate()
		for i in range(1, path.size() - 1):
			var tan := (path[i + 1] - path[i - 1]).normalized()
			var f := float(i) / (path.size() - 1)
			out[i] = path[i] + tan.orthogonal() * (sin(f * 41.0) * 0.6 + sin(f * 97.0 + 1.3) * 0.4) * amp * sin(f * PI)
		return out

	## A point a share `f` of the way along a path.
	static func _along(path: PackedVector2Array, f: float) -> Vector2:
		if path.size() < 2:
			return path[0] if path.size() == 1 else Vector2.ZERO
		var x := clampf(f, 0.0, 1.0) * (path.size() - 1)
		var i := mini(int(x), path.size() - 2)
		return path[i].lerp(path[i + 1], x - i)

	static func _grown(state: String) -> bool:
		return state in ["owned", "ready", "in_use", "available"]

	# --- drawn once ---------------------------------------------------------------------

	func _paint_still(ci: CanvasItem) -> void:
		if lay.is_empty():
			return
		var prof = main.profile
		var k: float = lay["k"]
		var fc: Vector2 = lay["fc"]
		# The figure, its marks (or veins), as the Marks page draws them.
		ci.draw_set_transform(fc, 0.0, Vector2(k, k))
		var fb := UI.Draw.Batch.new()
		for i in 5:
			fb.dot(Vector2(0, -12), 150.0 - i * 22.0, Color(col if not rows.is_empty() else Color(0.55, 0.5, 0.7), 0.02))
		if prof.path != "":
			Secret.draw_shadow(fb, Vector2(0, 124), 38.0, prof.path, prof.flow_step(), 0.0, 1.0, 0.24)
		else:
			fb.polygon(UI._oval(Vector2(0, 126), Vector2(74, 12), 24), Color(0, 0, 0, 0.3))
			fb.polygon(UI._oval(Vector2(0, 126), Vector2(48, 7), 24), Color(0, 0, 0, 0.3))
		BV._figure(fb, main.dressed_look())
		for pt in BV.ORDER:
			if unbound:
				_veins_into(fb, pt, View._part_color(prof, pt), pt == part)
			else:
				_mark_into(fb, pt)
		fb.flush(ci)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var b := UI.Draw.Batch.new()
		# The branch from the mark, spreading as a mark does, then the trunk and twigs.
		if not conn.is_empty():
			var s: Vector2 = lay["spots"][part]
			b.path(conn, Color(col, 0.13), 8.0)
			if unbound:
				b.path(conn, Color(col.darkened(0.3), 0.5), 3.0)
			else:
				b.path(conn, Color(UI.OUTLINE, 0.75), 4.6)
				b.path(conn, col.darkened(0.15) if faint else col, 2.6)
				b.path(conn, Color(col.lightened(0.5), 0.35), 0.9)
			_tendrils(b, s, k)
		for seg in trunk:
			_stroke(b, seg[0], String(seg[1]), 3.0, false)
		for tw in twigs:
			_stroke(b, tw[0], String(tw[1]), 2.0, true)
		if not unbound and not conn.is_empty():
			_motifs(b, conn, 0.18, 0.9)
			for seg in trunk:
				if _grown(String(seg[1])):
					_motifs(b, seg[0], 0.0, 1.0)
		# The root: the bond's emblem where the branch reaches the tree (a
		# well of raw essence for the Unbound).
		var root: Vector2 = lay["root"]
		if not rows.is_empty():
			if unbound:
				UI.glow_into(b, root, 16.0, col, 0.8)
				b.dot(root, 11.6, UI.OUTLINE)
				b.dot(root, 10.0, col.darkened(0.72))
				b.arc(root, 7.0, 0.0, TAU, 20, Color(col, 0.8), 1.6)
				b.dot(root, 3.4, col.lightened(0.35))
			else:
				UI.medallion_into(b, root, 11.0 if not small else 10.5, col, affinity, 1.0, 0, 0.3, faint)
		# The nodes on the trunk: filled once grown, gold when ready, dark while locked.
		var dr := 8.0 if not small else 8.5
		for ri in rows.size():
			var d: Vector2 = lay["rows"][ri]["disc"]
			var st := String(rows[ri]["state"])
			match st:
				"owned":
					b.dot(d, dr + 1.6, UI.OUTLINE)
					b.dot(d, dr, col.darkened(0.45))
					b.arc(d, dr - 1.0, 0.0, TAU, 20, col.lightened(0.15), 1.6)
				"ready":
					b.dot(d, dr + 1.6, UI.OUTLINE)
					b.dot(d, dr, UI.GILT_DEEP)
					b.arc(d, dr - 1.0, 0.0, TAU, 20, UI.GILT_HI, 1.8)
				"later":
					b.dot(d, dr, Color(0.07, 0.06, 0.08, 0.7))
					for q in 10:
						var a := q * TAU / 10.0
						b.arc(d, dr - 1.0, a, a + 0.3, 3, Color(UI.FAINT, 0.6), 1.2)
				_:
					b.dot(d, dr + 1.4, UI.OUTLINE)
					b.dot(d, dr, Color(0.11, 0.095, 0.12))
					b.arc(d, dr - 1.0, 0.0, TAU, 20, Color(col, 0.35), 1.2)
		b.flush(ci)
		# The step (or level) in each node, and "or" between a fork's twigs.
		var nf: Font = UI.font("display")
		var bf: Font = UI.font("body")
		for ri in rows.size():
			var d: Vector2 = lay["rows"][ri]["disc"]
			var st := String(rows[ri]["state"])
			var num := String(rows[ri].get("span", str(int(rows[ri].get("at", ri + 1)))))
			var fsz := 11 if num.length() < 2 else 9
			var tc: Color = UI.TEXT if st == "owned" else (UI.GILT_HI if st == "ready" else Color(UI.FAINT, 0.9))
			ci.draw_string(nf, d + Vector2(-dr, fsz * 0.36), num, HORIZONTAL_ALIGNMENT_CENTER, dr * 2.0, fsz, tc)
			if lay["rows"][ri]["fork"]:
				var bx: float = lay["root"].x + 34.0
				ci.draw_string(bf, Vector2(bx - 15.0, d.y + 4.0), View.TEXT["or"], HORIZONTAL_ALIGNMENT_CENTER, 18, 11, Color(UI.FAINT, 0.9))
		if lay.has("fx_head"):
			var at: Vector2 = lay["fx_head"]
			UI.draw_eyebrow(ci, at, View.TEXT["effects"], Color(UI.GOLD, 0.8))
		_labels(ci)

	## A curve in the look of what it leads to: grown in the part's colour
	## (outlined), gold to a choice that waits, faint while locked, dotted
	## where nothing is written yet, grey once passed on.
	func _stroke(b, pts: PackedVector2Array, st: String, w: float, twig: bool) -> void:
		match st:
			"owned", "in_use":
				if unbound:
					b.path(pts, Color(col.darkened(0.3), 0.55), w)  # (the live vein over it)
				else:
					b.path(pts, Color(UI.OUTLINE, 0.7), w + 1.8)
					b.path(pts, col if st == "owned" else col.darkened(0.2), w)
			"ready", "available":
				b.path(pts, Color(UI.OUTLINE, 0.7), w + 1.8)
				b.path(pts, UI.GILT if twig else (col if not unbound else Color(col.darkened(0.3), 0.55)), w)
			"learnable":
				b.path(pts, Color(UI.VIOLET, 0.75), w * 0.8)
			"passed":
				b.path(pts, Color(UI.FAINT, 0.3), w * 0.6)
			"locked":
				b.path(pts, Color(col, 0.26), w * 0.75)
			_:
				# Not written yet (or the steps to come): a dotted line.
				for i in range(0, pts.size(), 2):
					b.dot(pts[i], w * 0.5, Color(UI.FAINT, 0.45))

	## Little veins round the mark, as if it were spreading from there.
	func _tendrils(b, s: Vector2, k: float) -> void:
		var n := 5 + (step if not unbound else 3)
		var tcol := Color(col, 0.42)
		for i in n:
			var a := float(i) * 2.399 + 0.7
			var length := (9.0 + 1.8 * float(i % 4) + (step if not unbound else 4) * 1.2) * k
			var p1 := s + Vector2.from_angle(a) * length * 0.55 + Vector2.from_angle(a + 1.4) * 2.0 * k
			var p2 := s + Vector2.from_angle(a + 0.35) * length
			b.path(PackedVector2Array([s, p1, p2]), tcol, 1.1)

	## The mark's emblem echoed along its branch, a small motif every so often:
	## Air sparks, Water ripples, Fire flicks, Stone chips, Iron rivets, Blade
	## thorns (Life leaves, Unmaking cracks).
	func _motifs(b, pts: PackedVector2Array, from: float, to: float) -> void:
		var length := 0.0
		for i in range(1, pts.size()):
			length += pts[i].distance_to(pts[i - 1])
		var n := int(length * (to - from) / 24.0)
		var mc := Color(col.lightened(0.15), 0.8)
		for q in n:
			var f := from + (to - from) * (float(q) + 0.5) / maxf(n, 1)
			var p := _along(pts, f)
			var tan := (_along(pts, f + 0.02) - _along(pts, f - 0.02)).normalized()
			var nor := tan.orthogonal() * (1.0 if q % 2 == 0 else -1.0)
			match affinity:
				"air":
					b.path(PackedVector2Array([p + nor * 2.0, p + nor * 5.0 + tan * 2.5, p + nor * 4.0 - tan * 1.0, p + nor * 7.5 + tan * 1.5]), mc, 1.0)
				"water":
					b.arc(p + nor * 3.5, 2.6, nor.angle() - 1.6, nor.angle() + 1.6, 6, mc, 1.0)
				"fire":
					b.path(PackedVector2Array([p + nor * 1.5, p + nor * 4.5 + tan * 1.5, p + nor * 7.0 - tan * 0.5]), mc, 1.2)
				"stone":
					b.polygon(PackedVector2Array([p + nor * 2.5, p + nor * 4.5 + tan * 2.0, p + nor * 6.5, p + nor * 4.5 - tan * 2.0]), mc)
				"iron":
					b.dot(p, 2.2, UI.OUTLINE)
					b.dot(p, 1.5, mc)
				"blade":
					b.polygon(PackedVector2Array([p + tan * 2.2, p - tan * 2.2, p + nor * 6.0 + tan * 1.0]), mc)
				"life":
					b.polygon(UI._oval(p + nor * 4.0, Vector2(1.6, 3.2), 8), mc)
				_:
					b.path(PackedVector2Array([p, p + nor * 3.5 + tan * 1.5, p + nor * 5.5 - tan * 1.0]), Color(mc, 0.6), 0.9)

	## A part's mark on the figure (in the figure's frame): its emblem in its
	## colour, the essence settled there as a thin ring; a socket if unmarked.
	func _mark_into(b, pt: String) -> void:
		var prof = main.profile
		var at: Vector2 = BV.SPOTS[pt]
		var info: Dictionary = prof.bonds.get(pt, {})
		if info.is_empty():
			UI.socket_into(b, at, 5.5, 0.0)
		else:
			var data: Dictionary = Bonds.BONDS[info["id"]]
			var c: Color = data["color"]
			b.dot(at, 9.4, Color(UI.OUTLINE, 0.9))
			b.dot(at, 8.0, c.darkened(0.7))
			UI.emblem_into(b, at, 6.4 if not info.get("faint", false) else 5.0, data["affinity"], c.lightened(0.1), 0.0)
		var pd: Dictionary = prof.part_density.get(pt, {})
		var total := 0.0
		for e in pd:
			total += float(pd[e])
		if total > 0.0:
			var a0 := -PI / 2.0
			for e in pd:
				var sweep := TAU * float(pd[e]) / total
				b.arc(at, 12.5, a0 + 0.06, a0 + sweep - 0.06, 10, Essence.color(e), 2.2)
				a0 += sweep

	## The Unbound: veins of raw essence from a part, more with its level (the
	## chosen part's flicker in the live layer).
	func _veins_into(b, pt: String, c: Color, chosen: bool) -> void:
		var prof = main.profile
		var at: Vector2 = BV.SPOTS[pt]
		var lv := Unbound.level(prof, pt)
		var vc := Color(c, 0.4 + 0.05 * lv)
		if not chosen:
			UI.glow_into(b, at, 8.0 + 2.0 * lv, c, 0.25 + 0.08 * lv)
		var n := 3 + lv
		var length := 8.0 + 1.6 * lv
		for i in n:
			var ang := float(i) * 2.399 + float(hash(pt) % 40) * 0.1
			var p1 := at + Vector2.from_angle(ang) * length * 0.5 + Vector2.from_angle(ang + 1.5) * 2.5
			var p2 := at + Vector2.from_angle(ang + 0.3) * length
			var p3 := p1 + Vector2.from_angle(ang - 0.9) * length * 0.35
			b.line(at, p1, Color(vc, vc.a * 1.4), 1.8)
			b.line(p1, p2, vc, 1.3)
			b.line(p1, p3, Color(vc, vc.a * 0.7), 1.0)
		b.dot(at, 3.0 + 0.3 * lv, c.lightened(0.3))

	## The parts' names beside the figure, on leader lines (the chosen one in
	## gilt), over the branch so they always read.
	func _labels(ci: CanvasItem) -> void:
		var prof = main.profile
		var k: float = lay["k"]
		var fc: Vector2 = lay["fc"]
		var font: Font = UI.font("display")
		var body: Font = UI.font("body")
		var t := 0.0
		for pt in BV.ORDER:
			var info: Dictionary = prof.bonds.get(pt, {})
			var side := -1.0 if pt in BV.LEFT else 1.0
			var at: Vector2 = lay["spots"][pt]
			var ly: float = fc.y + float(BV.LABEL_Y[pt]) * k
			var col_x := fc.x + side * 78.0 * k
			var chosen: bool = pt == part
			ci.draw_polyline(PackedVector2Array([at + Vector2(side * 10.0 * k, 0), Vector2(col_x - side * 6.0, ly), Vector2(col_x, ly)]), Color(1, 1, 1, 0.3 if chosen else 0.16), 1.0, true)
			var name: String = Bonds.PART_NAMES[pt]
			var sub := "unmarked"
			var sub_col := UI.FAINT
			if unbound:
				sub = "level %d" % Unbound.level(prof, pt)
				sub_col = View._part_color(prof, pt).lightened(0.15)
			elif not info.is_empty():
				var data: Dictionary = Bonds.BONDS[info["id"]]
				sub = data["name"]
				sub_col = data["color"] if not info.get("faint", false) else Color(data["color"], 0.6)
			if pt == "back":
				name = "Back (behind)"
			var sf: Font = font if not info.is_empty() else body
			var tiny := k < 0.8
			var ns := 15 if tiny else 16
			var ss := 13 if tiny else 14
			var w1 := font.get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, ns).x
			var w2 := sf.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss).x
			var x1 := col_x + 4.0 if side > 0.0 else col_x - 4.0 - w1
			var x2 := col_x + 4.0 if side > 0.0 else col_x - 4.0 - w2
			var nc: Color = UI.GILT_HI if chosen else (UI.TEXT if not info.is_empty() or unbound else UI.DIM)
			ci.draw_string_outline(font, Vector2(x1, ly + 3.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, ns, 4, Color(0, 0, 0, 0.75))
			ci.draw_string(font, Vector2(x1, ly + 3.0), name, HORIZONTAL_ALIGNMENT_LEFT, -1, ns, nc)
			ci.draw_string_outline(sf, Vector2(x2, ly + (15.0 if tiny else 18.0)), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, 4, Color(0, 0, 0, 0.7))
			ci.draw_string(sf, Vector2(x2, ly + (15.0 if tiny else 18.0)), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, ss, sub_col)

	# --- drawn each frame ---------------------------------------------------------------

	func _paint_live(ci: CanvasItem) -> void:
		if lay.is_empty():
			return
		var prof = main.profile
		var t := Time.get_ticks_msec() * 0.001
		var k: float = lay["k"]
		ci.draw_set_transform(lay["fc"], 0.0, Vector2(k, k))
		var fb := UI.Draw.Batch.new()
		Makers.core_figure_into(fb, prof, BV.SPOTS, t)  # (a core mark, beneath the marks)
		if not unbound:
			for pt in BV.ORDER:
				var info: Dictionary = prof.bonds.get(pt, {})
				if info.is_empty():
					continue
				var c: Color = Bonds.BONDS[info["id"]]["color"]
				var f: bool = info.get("faint", false)
				var pulse := 0.75 + 0.25 * sin(t * 2.2 + float(BV.SPOTS[pt].y) * 0.05)
				UI.glow_into(fb, BV.SPOTS[pt], 26.0 * (0.7 if f else 1.0), c, (0.7 if f else 1.3) * pulse)
		fb.flush(ci)
		ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var b := UI.Draw.Batch.new()
		if unbound and not conn.is_empty():
			# The vein: the part's raw essence, hot and flickering with strain.
			var vc: Color = main.unbound.vein_color(prof, part, t) if main.unbound != null else col
			vc.a = 1.0
			var strain: float = main.unbound.strain_of(part) if main.unbound != null else 0.0
			var hot := clampf(strain / 100.0, 0.0, 1.0)
			var flick := 0.75 + 0.25 * sin(t * (3.0 + 14.0 * hot)) * sin(t * 7.3 + 1.0)
			b.path(conn, Color(vc, 0.18 * flick), 7.0 + 3.0 * hot)
			b.path(conn, Color(vc, 0.9 * flick), 2.2)
			for seg in trunk:
				if _grown(String(seg[1])):
					b.path(seg[0], Color(vc, 0.12 * flick), 6.0)
					b.path(seg[0], Color(vc, 0.85 * flick), 2.4)
			for tw in twigs:
				if String(tw[1]) in ["owned", "in_use"]:
					b.path(tw[0], Color(vc, 0.8 * flick), 1.6)
			# Sparks of raw essence along it while it's hot.
			if hot > 0.3:
				for q in 5:
					var f := fposmod(t * (0.5 + 0.13 * q) + q * 0.37, 1.0)
					b.dot(_along(conn, f), 1.4 + 1.6 * hot, Color(1.0, 0.75, 0.45, 0.7 * hot))
			UI.glow_into(b, lay["root"], 18.0, vc, 0.5 + 0.4 * flick * (0.5 + hot))
		elif not conn.is_empty():
			# A glint runs up the branch from the mark, now and then.
			var f := fposmod(t * 0.28, 1.6)
			if f < 1.0:
				UI.glow_into(b, _along(conn, f), 7.0, col.lightened(0.4), 0.9 * sin(f * PI))
				b.dot(_along(conn, f), 1.6, Color(1, 1, 1, 0.7 * sin(f * PI)))
		# A fork that waits pulses gold.
		for ri in rows.size():
			if String(rows[ri]["state"]) != "ready":
				continue
			var d: Vector2 = lay["rows"][ri]["disc"]
			var p := 0.5 + 0.5 * sin(t * 4.0)
			UI.glow_into(b, d, 13.0 + 3.0 * p, UI.GILT, 0.5 + 0.4 * p)
			b.arc(d, 10.5 + 2.5 * p, 0.0, TAU, 24, Color(UI.GILT_HI, 0.35 + 0.35 * p), 1.4)
		b.flush(ci)


## A layer of a TreeMap: draws with its `paint` (once, or `every_frame`).
class Layer extends Control:
	var paint := Callable()
	var every_frame := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_process(every_frame)

	func _process(_delta: float) -> void:
		if every_frame and is_visible_in_tree():
			queue_redraw()

	func _draw() -> void:
		if paint.is_valid():
			paint.call(self)


## A body part's node on the map: a fine ring round its mark (a ready fork
## pulses gold), the chosen part ringed twice in gilt.
class PartNode extends Button:
	const UI := preload("res://scripts/ui.gd")
	var menu
	var part := ""
	var on := false
	var ready_fork := false
	var col := Color.WHITE

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		for s in ["focus_entered", "focus_exited", "mouse_entered", "mouse_exited"]:
			connect(s, queue_redraw)

	func _process(_delta: float) -> void:
		if ready_fork:
			queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 2.5
		var t := Time.get_ticks_msec() * 0.001
		if ready_fork:
			var p := 0.5 + 0.5 * sin(t * 4.0)
			draw_arc(c, r + 1.5 * p, 0.0, TAU, 28, Color(UI.GILT_HI, 0.35 + 0.45 * p), 2.0, true)
		elif not on:
			draw_arc(c, r - 1.0, 0.0, TAU, 28, Color(col, 0.55), 1.2, true)
		if on:
			draw_arc(c, r - 1.0, 0.0, TAU, 28, UI.GILT_HI, 1.8, true)
			draw_arc(c, r + 2.0, 0.0, TAU, 28, Color(UI.GILT, 0.6), 1.0, true)
		if is_hovered() or (has_focus() and not (menu != null and menu.main != null and menu.main.touch_active)):
			draw_arc(c, r + 4.0, 0.0, TAU, 28, Color(UI.GILT, 0.35), 4.0, true)
			draw_arc(c, r + 4.0, 0.0, TAU, 28, UI.GILT_HI, 1.4, true)


## A bud: one option on the tree, a pill with the option's glyph and name,
## in the look of what it is to you (tree.gd option states), and at its
## right a few words when they matter (what opens it, what learning it costs).
class Bud extends Button:
	const UI := preload("res://scripts/ui.gd")
	const Card := preload("res://scripts/grimoire_card.gd")
	var menu
	var option := {}
	var ready_fork := false
	var selected := false
	var small := false
	var glyph := ""
	var aux := ""
	var flash_until := 0  # (reached by a link: it glows till then, ms)

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		clip_text = true
		for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color", "font_disabled_color"]:
			add_theme_color_override(c, Color(0, 0, 0, 0))
		for s in ["focus_entered", "focus_exited", "mouse_entered", "mouse_exited"]:
			connect(s, queue_redraw)

	func _process(_delta: float) -> void:
		if (ready_fork and String(option.get("state", "")) == "available") or flash_until > Time.get_ticks_msec():
			queue_redraw()

	func _touching() -> bool:
		return menu != null and menu.main != null and menu.main.touch_active

	func _draw() -> void:
		var st := String(option.get("state", ""))
		var col: Color = option.get("color", UI.GILT)
		var r := Rect2(Vector2(1, 1), size - Vector2(2, 2))
		var rad := r.size.y * 0.5
		var pill := UI.rounded(r, rad)
		var fill := Color(0.085, 0.072, 0.085, 0.94)
		var edge := Color(UI.FAINT, 0.6)
		var tc := UI.DIM
		var gc := col.lightened(0.45)
		var t := Time.get_ticks_msec() * 0.001
		var fade := 1.0
		var b := UI.Draw.Batch.new()
		match st:
			"owned":
				# Yours: it glows.
				b.polygon(UI.rounded(r.grow(3.0), rad + 3.0), Color(col, 0.13))
				fill = col.darkened(0.6)
				fill.a = 0.96
				edge = col.lightened(0.1)
				tc = UI.TEXT
			"in_use":
				fill = col.darkened(0.66)
				fill.a = 0.96
				edge = Color(UI.GILT, 0.7)
				tc = UI.TEXT
			"available":
				var p := 0.5 + 0.5 * sin(t * 4.0) if ready_fork else 1.0
				b.polygon(UI.rounded(r.grow(2.0 + 2.5 * p), rad + 2.0 + 2.5 * p), Color(UI.GILT, 0.1 + 0.12 * p))
				fill = UI.GILT_DEEP.lerp(Color(0.5, 0.36, 0.13), p * 0.5)
				fill.a = 0.95
				edge = UI.GILT.lerp(UI.GILT_HI, p)
				tc = UI.GILT_HI
				gc = UI.GILT_HI
			"learnable":
				fill = Color(0.12, 0.08, 0.16, 0.95)
				edge = Color(UI.VIOLET, 0.85)
				tc = UI.VIOLET
				gc = UI.VIOLET
			"passed":
				fade = 0.5
				fill = Color(0.07, 0.06, 0.07, 0.8)
				edge = Color(UI.FAINT, 0.4)
				tc = Color(UI.FAINT, 0.9)
				gc = Color(UI.FAINT, 0.9)
			"locked":
				fill = Color(0.075, 0.066, 0.08, 0.94)
				edge = Color(col, 0.3)
				tc = UI.DIM
			"placeholder", "later":
				fade = 0.75
				fill = Color(0.06, 0.055, 0.065, 0.7)
				edge = Color(UI.FAINT, 0.4)
				tc = Color(UI.FAINT, 0.95)
				gc = Color(UI.FAINT, 0.8)
		b.polygon(pill, Color(fill, fill.a * fade))
		# Its glyph, on a disc at its left.
		var gr := r.size.y * 0.5 - 3.0
		var gcen := Vector2(r.position.x + rad, r.get_center().y)
		if st == "locked":
			b.dot(gcen, gr, Color(0.11, 0.1, 0.13))
			UI.lock_into(b, gcen, gr * 0.62, Color(UI.FAINT, 0.95))
		elif st in ["placeholder", "later"]:
			for i in 10:
				var a := float(i) * TAU / 10.0
				b.arc(gcen, gr - 1.0, a, a + 0.3, 3, Color(UI.FAINT, 0.5), 1.2)
		else:
			b.dot(gcen, gr, Color(col.darkened(0.7) if st != "available" else UI.GILT_DEEP.darkened(0.3), fade))
			b.arc(gcen, gr - 0.5, 0.0, TAU, 20, Color(gc, 0.7 * fade), 1.2)
		b.flush(self)
		var loop := pill.duplicate()
		loop.append(loop[0])
		if st in ["placeholder", "later"]:
			for i in range(0, loop.size() - 1, 2):
				draw_line(loop[i], loop[i + 1], edge, 1.2, true)
		else:
			draw_polyline(loop, Color(edge, edge.a * fade), 1.6 if st in ["owned", "available"] else 1.0, true)
		if glyph != "" and st != "locked":
			Card.Drawing.draw_glyph(self, glyph, gcen, gr * 0.6, Color(gc, (0.55 if st in ["placeholder", "later"] else 1.0) * fade))
		var fs := 14 if small else 15
		var tx := gcen.x + gr + 6.0
		var aw := 0.0
		if aux != "":
			var bf: Font = UI.font("body")
			aw = minf(bf.get_string_size(aux, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, r.size.x * 0.45)
			var ac: Color = UI.GILT if st == "in_use" else (UI.VIOLET if st == "learnable" else Color(UI.FAINT, 0.95))
			draw_string(bf, Vector2(r.end.x - rad * 0.6 - aw, r.get_center().y + 4.0), aux, HORIZONTAL_ALIGNMENT_RIGHT, aw, 12, ac)
		UI.draw_label(self, Vector2(tx, r.get_center().y + fs * 0.33), text, fs, Color(tc, tc.a * fade), HORIZONTAL_ALIGNMENT_LEFT, r.end.x - tx - rad * 0.6 - (aw + 8.0 if aw > 0.0 else 0.0))
		if st == "passed":
			draw_line(Vector2(tx - 2.0, r.get_center().y), Vector2(r.end.x - rad * 0.7, r.get_center().y), Color(UI.FAINT, 0.6), 1.0)
		if selected:
			var ring := UI.rounded(r.grow(2.5), rad + 2.5)
			ring.append(ring[0])
			draw_polyline(ring, UI.GILT_HI, 1.4, true)
		var now := Time.get_ticks_msec()
		if flash_until > now:
			# Reached by a link (or just taken): a bright ring that fades.
			var k := clampf(float(flash_until - now) / 2200.0, 0.0, 1.0)
			var ring := UI.rounded(r.grow(4.0 + 3.0 * (1.0 - k)), rad + 4.0 + 3.0 * (1.0 - k))
			ring.append(ring[0])
			draw_polyline(ring, Color(UI.GILT_HI, 0.85 * k * (0.6 + 0.4 * sin(t * 9.0))), 2.0, true)
		if (has_focus() and not _touching()) or is_hovered():
			var ring := UI.rounded(r.grow(3.5), rad + 3.5)
			ring.append(ring[0])
			draw_polyline(ring, Color(UI.GILT, 0.35), 4.0, true)


## "On the body map" (abilities.gd, beside each entry): a narrow tab with a
## sprig on it and its words under, that opens the Tree on that entry's node.
class MapLink extends Button:
	const UI := preload("res://scripts/ui.gd")
	var menu
	var small := false

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		clip_text = true
		custom_minimum_size = Vector2(66.0 if small else 72.0, 58.0)
		size_flags_vertical = Control.SIZE_FILL
		for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())
		for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
			add_theme_color_override(c, Color(0, 0, 0, 0))
		for s in ["focus_entered", "focus_exited", "mouse_entered", "mouse_exited"]:
			connect(s, queue_redraw)

	func _draw() -> void:
		var touching: bool = menu != null and menu.main != null and menu.main.touch_active
		var hot := is_hovered() or (has_focus() and not touching)
		var r := Rect2(Vector2(1, 1), size - Vector2(2, 2))
		var box := UI.rounded(r, 8.0)
		draw_colored_polygon(box, Color(0.11, 0.09, 0.08, 0.85) if not hot else Color(0.2, 0.16, 0.1, 0.95))
		box.append(box[0])
		draw_polyline(box, Color(UI.GILT, 0.75 if hot else 0.35), 1.2, true)
		# A sprig: a stem with a bud either side and one at its tip.
		var c := Vector2(r.get_center().x, r.position.y + minf(18.0, r.size.y * 0.36))
		var gc: Color = UI.GILT_HI if hot else Color(UI.GILT, 0.9)
		draw_line(c + Vector2(0, 9), c + Vector2(0, -6), gc, 1.6, true)
		draw_line(c + Vector2(0, 3), c + Vector2(-6, -2), gc, 1.4, true)
		draw_line(c + Vector2(0, 0), c + Vector2(6, -5), gc, 1.4, true)
		for p in [c + Vector2(0, -7), c + Vector2(-7, -3), c + Vector2(7, -6)]:
			draw_circle(p, 2.3, gc)
		var f: Font = UI.font("body")
		var fs := 11 if small else 12
		var words := String(text).split(" ")
		var cut := maxi(1, words.size() - 2)
		var l1 := " ".join(words.slice(0, cut))
		var l2 := " ".join(words.slice(cut))
		var y := c.y + 12.0 + fs
		draw_string(f, Vector2(r.position.x, y), l1, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, UI.DIM if not hot else UI.TEXT)
		draw_string(f, Vector2(r.position.x, y + fs + 1.0), l2, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, fs, UI.GOLD if hot else Color(UI.GOLD, 0.85))
		if has_focus() and not touching:
			var ring := UI.rounded(r.grow(1.5), 9.5)
			ring.append(ring[0])
			draw_polyline(ring, Color(UI.GILT, 0.3), 4.0, true)
			draw_polyline(ring, UI.GILT_HI, 1.4, true)
