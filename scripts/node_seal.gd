extends RefCounted
## SEALING A NODE, on the climber screen's Body tab (the Unbound choose; the
## marked can't). Every rule and number is unbound.gd's (seal, unseal,
## SEAL); the words and the section are here.
##
## Under the chosen Node's levels (technique_page.gd node_levels), on the
## train only:
##   an open Node: a warning of what sealing gives up (flat, in the warning
##     colour: what it holds condenses into crystals; its size, technique,
##     gift, minor ability and attributes are gone; unsealed later it starts
##     asleep at size 0), what the open Nodes gain, and "Seal the ... Node".
##     A press opens the confirmation pop-up (menu.gd ask) with the warning;
##     its Confirm seals. The last open Node can't be sealed.
##   a sealed Node: what it means now, and "Unseal the ... Node" (it asks
##     first too: it starts again asleep, at size 0).
## Off the train, a sealed Node says it's sealed and where to change it.
## The Entity: a first-time moment when the tab first offers sealing
## (node_seal), one on sealing (node_sealed) and one on unsealing
## (node_unsealed); "How does it work?" has "Sealing a Node?"; both buttons
## have hover/hold help (ub_seal, ub_unseal).

const Unbound := preload("res://scripts/unbound.gd")
const UI := preload("res://scripts/ui.gd")

static var TEXT := {
	"title": "Seal or open: %s",
	"open_note": "Sealing gives this Node up so the others grow deeper. Each sealed Node makes your open Nodes grow %d%% faster from use and hit %d%% harder. Essence that would pool in a sealed Node flows on to your biggest open Node, where, not being its own kind, it refills only a third as much.",
	"warn": "Sealing your %s gives it up: what it holds (%s) condenses into crystals, and its size (%s), technique, gift, minor ability and attributes are gone. Unsealed later, it starts again asleep, at size 0.",
	"warn_asleep": "Sealing your sleeping %s gives up what has soaked into it. Unsealed later, it starts again asleep, at size 0.",
	"seal": "Seal the %s",
	"seal_title": "Seal the %s?",
	"unseal_title": "Unseal the %s?",
	"unseal": "Unseal the %s",
	"sealed_note": "Your %s is sealed: it takes no essence and gives nothing. Your %d sealed %s make your open Nodes grow %d%% faster from use and hit %d%% harder.",
	"unseal_note": "Unsealed, it starts again asleep, at size 0, and your open Nodes lose its share of the bonus.",
	"off_train": "Your %s is sealed. Seal or unseal Nodes on the train.",
	"last": "Your %s is your last open Node: it can't be sealed.",
	"node": "Node",
	"nodes": "Nodes",
	"card_head": "%s  ·  sealed",
	"card_line": "Takes no essence; your open Nodes grow deeper.",
	"levels": "Your %s is sealed. It has no levels while it stays sealed: unseal it on the train and it starts again asleep, at size 0.",
	"tree": "sealed",
}


## A sealed Node on the figure (the climber screen's and the Tree's), into a
## draw_util Batch: a dark iron seal (lit from the top-left by the shading
## toolkit) crossed by two bands and pinned by a rivet, where the Node's
## veins would be. `s` scales it.
static func draw_seal(b, at: Vector2, s := 1.0) -> void:
	var iron := Color(0.36, 0.35, 0.42)
	var band := Color(0.6, 0.56, 0.5)
	b.disc(at + Vector2(0.8, 1.2) * s, 9.0 * s, Color(0, 0, 0, 0.35))
	b.disc(at, 8.0 * s, iron)
	b.bar(at + Vector2(-7.0, -7.0) * s, at + Vector2(7.0, 7.0) * s, band, 2.6 * s)
	b.bar(at + Vector2(-7.0, 7.0) * s, at + Vector2(7.0, -7.0) * s, band, 2.6 * s)
	b.ball(at, 2.4 * s, band.lightened(0.25))


## The section, into the Body tab (menu.gd _climber_marks), for `part`.
static func build(menu, part: String) -> void:
	var main = menu.main
	var prof = main.profile
	if not Unbound.is_on(prof) or not part in Unbound.PARTS:
		return
	var sealed := Unbound.sealed(prof, part)
	var name := Unbound.node_name(part)
	if not bool(main.on_train):
		if sealed:
			var ol: Label = _label(menu, TEXT["off_train"] % name, menu.DIM)
			ol.set_meta("seal_off_train", part)
		return
	menu._section(TEXT["title"] % name)
	var told: String = String(menu.get_meta("seal_told", ""))
	menu.remove_meta("seal_told")
	if told == "":
		told = main.tip_now("node_seal")  # (the first time the tab offers sealing)
	if told != "":
		menu.box.add_child(menu.Entity.says(told, 30.0 if menu.compact() else 38.0))
	var g_pct := int(round(float(Unbound.SEAL["growth"]) * 100.0))
	var p_pct := int(round(float(Unbound.SEAL["power"]) * 100.0))
	if sealed:
		var n := Unbound.sealed_count(prof)
		_label(menu, TEXT["sealed_note"] % [name, n, TEXT["node"] if n == 1 else TEXT["nodes"], g_pct * n, p_pct * n], menu.DIM).set_meta("seal_note", part)
		if not menu.compact():
			_label(menu, TEXT["unseal_note"], menu.FAINT)
		var row: HBoxContainer = menu._row()
		var ub: Button = menu._button(TEXT["unseal"] % name, _ask_unseal.bind(menu, part), row)
		ub.set_meta("help", "ub_unseal")
		ub.set_meta("seal_part", part)
		ub.set_meta("asks", true)  # (it opens the pop-up)
		ub.custom_minimum_size.x = 240.0 if not menu.compact() else 200.0
		UI.keep_text(ub)
		return
	if not menu.compact():
		_label(menu, TEXT["open_note"] % [g_pct, p_pct], menu.DIM)
	var last := Unbound.open_parts(prof).size() <= 1
	if last:
		_label(menu, TEXT["last"] % name, menu.DIM).set_meta("seal_last", part)
	else:
		var warn: String = TEXT["warn"] % [name, held_text(prof, part), Unbound._num(Unbound.size(prof, part))] if Unbound.awake(prof, part) else TEXT["warn_asleep"] % name
		_label(menu, warn, UI.BAD).set_meta("seal_warn", part)
	var row2: HBoxContainer = menu._row()
	var sb: Button = menu._button(TEXT["seal"] % name, _ask_seal.bind(menu, part), row2)
	sb.set_meta("help", "ub_seal")
	sb.set_meta("seal_part", part)
	sb.set_meta("asks", true)  # (it opens the pop-up)
	sb.disabled = last
	sb.custom_minimum_size.x = 240.0 if not menu.compact() else 200.0
	UI.keep_text(sb)


## What a Node holds, in words ("Air 42, Water 8"; "nothing").
static func held_text(prof, part: String) -> String:
	var bits: Array = []
	for k in Unbound.mix(prof, part):
		bits.append("%s %d" % [Unbound._display(k), int(floor(Unbound.amount(prof, part, k) + 0.0001))])
	return ", ".join(bits) if not bits.is_empty() else load("res://scripts/technique_page.gd").TEXT["body_empty"]


static func _label(menu, text: String, col: Color) -> Label:
	var l: Label = menu._small_label(text, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 280.0 if not menu.compact() else 240.0
	menu.box.add_child(l)
	return l


# --- pressing ------------------------------------------------------------------------------

## Seal: it asks first (the pop-up, with the warning).
static func _ask_seal(menu, part: String) -> void:
	var prof = menu.main.profile
	var name := Unbound.node_name(part)
	var warn: String = TEXT["warn"] % [name, held_text(prof, part), Unbound._num(Unbound.size(prof, part))] if Unbound.awake(prof, part) else TEXT["warn_asleep"] % name
	menu.ask(warn, TEXT["seal"] % name, _do_seal.bind(menu, part), true, TEXT["seal_title"] % name)


## Unseal: it asks first (the pop-up: it starts again asleep, at size 0).
static func _ask_unseal(menu, part: String) -> void:
	var name := Unbound.node_name(part)
	menu.ask(TEXT["unseal_note"], TEXT["unseal"] % name, _do_unseal.bind(menu, part), false, TEXT["unseal_title"] % name)


## Seal (Confirm in the pop-up).
static func _do_seal(menu, part: String) -> void:
	var main = menu.main
	var prof = main.profile
	var got: Dictionary = Unbound.seal(prof, part, bool(main.on_train))
	if bool(got["ok"]):
		main.sfx("craft_rune", 0.7, -2.0, 0.0)
		menu.set_meta("seal_told", main.tip_now("node_sealed"))
		prof.save()
		main._give_bonds()
	else:
		main.sfx("ui_back", 1.0, -6.0, 0.0)
	menu.toast = String(got["line"])
	menu.toast_t = 4.0
	_redraw(menu, "ub_unseal" if bool(got["ok"]) else "ub_seal")


static func _do_unseal(menu, part: String) -> void:
	var main = menu.main
	var prof = main.profile
	var got: Dictionary = Unbound.unseal(prof, part, bool(main.on_train))
	if bool(got["ok"]):
		main.sfx("glint", 0.8, -4.0, 0.0)
		menu.set_meta("seal_told", main.tip_now("node_unsealed"))
		prof.save()
		main._give_bonds()
	else:
		main.sfx("ui_back", 1.0, -6.0, 0.0)
	menu.toast = String(got["line"])
	menu.toast_t = 4.0
	_redraw(menu, "ub_seal" if bool(got["ok"]) else "ub_unseal")


## The tab built again where it was (body_move.gd's way).
static func _redraw(menu, help: String) -> void:
	load("res://scripts/body_move.gd")._redraw(menu, help)
