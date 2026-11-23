extends RefCounted
## THE SEAL ON A FAINT MARK: a climber who falls before the Regard wakes with
## a faint first mark (climb_shape.gd DEATH_MARK, main.gd _grant_regard), and
## that mark carries a SEAL. While the faint mark is not yet fully grown
## (still faint: its debt of essence not yet paid, profile.gd add_bond), the
## climber can BREAK THE SEAL: the mark comes away and they are Unbound
## (unbound.gd become, the same path as refusing at the Regard or slipping a
## barrier with no mark). It's the third way in. Once the mark is fully grown
## (no longer faint) the seal is gone for good.
##
## On the climber screen's Marks tab, on the train only: a section under the
## marks with what the seal is, a warning (flat, in the warning colour) and
## "Break the seal". The first press only arms it ("Press again to break the
## seal"); the second, within ARM_MS, breaks it. Off the train the section
## only says where it can be done.
## The Entity: a first-time moment when the tab first shows the seal
## (mark_seal) and one on breaking it (mark_seal_broken); "How does it
## work?" has "The seal on a faint mark?"; the button has hover/hold help
## (mark_seal_break).
##
## The mark carries the seal as "seal": true on its record (profile.gd
## bonds). An old save's faint marks have none: nothing changes for them.
## Every word is here (the Data editor: "The cities: lore in what people say").

const Unbound := preload("res://scripts/unbound.gd")
const UI := preload("res://scripts/ui.gd")

static var TEXT := {
	"title": "The seal on your mark",
	"note": "Your faint %s mark still carries the guardian's seal. Until the mark has grown to full strength, you can break the seal: the mark comes away, and you are Unbound.",
	"warn": "Breaking the seal is for good. Your %s mark is gone, and every mark with it; your body takes essence raw, in six Nodes, as the Unbound do. In the cities the Unbound pass as marked, but some are found out.",
	"break": "Break the seal",
	"break_again": "{again} to break the seal",
	"broken": "The seal breaks. The mark fades from your %s. You are Unbound.",
	"off_train": "Your faint %s mark carries a seal. It can be broken only on the train.",
	"not_now": "There is no seal to break.",
	"grown": "Your %s mark has grown to full strength. Its seal is gone.",
}
## How long the first press of Break the seal stays armed (ms).
const ARM_MS := 4000


## Puts the seal on a faint first mark (main.gd _grant_regard, a fall before
## the Regard). A full-strength mark takes none.
static func place(prof, part: String) -> void:
	if prof == null or not prof.bonds.has(part):
		return
	var b: Dictionary = prof.bonds[part]
	if bool(b.get("faint", false)):
		b["seal"] = true


## The body part whose faint mark still carries its seal ("" for none). Once
## the mark is fully grown (no longer faint) the seal is gone; the Unbound
## have none.
static func sealed_part(prof) -> String:
	if prof == null or Unbound.is_on(prof):
		return ""
	for part in prof.bonds:
		var b = prof.bonds[part]
		if b is Dictionary and bool(b.get("seal", false)) and bool(b.get("faint", false)):
			return String(part)
	return ""


## True while the seal can be broken.
static func can_break(prof) -> bool:
	return sealed_part(prof) != ""


## A grown mark's seal taken off its record (the Marks tab calls it as it
## opens: sealed_part already ignores it). True if one was.
static func tidy(prof) -> bool:
	if prof == null:
		return false
	var gone := false
	for part in prof.bonds:
		var b = prof.bonds[part]
		if b is Dictionary and b.has("seal") and not bool(b.get("faint", false)):
			b.erase("seal")
			gone = true
	return gone


## Breaks the seal: the climber becomes Unbound (unbound.gd become). Only on
## the train. {ok, line}.
static func break_seal(prof, on_train: bool) -> Dictionary:
	var part := sealed_part(prof)
	if part == "" or not on_train:
		return {"ok": false, "line": String(TEXT["not_now"])}
	var where: String = String(Unbound.PART_NAMES.get(part, part)).to_lower()
	Unbound.become(prof)
	prof.note("seal_broken")
	return {"ok": true, "line": String(TEXT["broken"]) % where}


static func _mark_name(prof, part: String) -> String:
	var Bonds = load("res://scripts/bonds.gd")
	var id := String(prof.bonds.get(part, {}).get("id", ""))
	return String(Bonds.BONDS[id]["name"]) if Bonds.BONDS.has(id) else "?"


# --- the Marks tab --------------------------------------------------------------------------

## The section, into the Marks tab (menu.gd _climber_marks), for a marked
## climber whose faint mark carries its seal.
static func build(menu) -> void:
	var main = menu.main
	var prof = main.profile
	tidy(prof)
	var part := sealed_part(prof)
	if part == "":
		return
	var mark := _mark_name(prof, part)
	if not bool(main.on_train):
		var ol: Label = _label(menu, TEXT["off_train"] % mark, menu.DIM)
		ol.set_meta("mark_seal_off_train", part)
		return
	menu._section(TEXT["title"])
	var told: String = String(menu.get_meta("mark_seal_told", ""))
	menu.remove_meta("mark_seal_told")
	if told == "":
		told = main.tip_now("mark_seal")  # (the first time the tab shows the seal)
	if told != "":
		menu.box.add_child(menu.Entity.says(told, 30.0 if menu.compact() else 38.0))
	_label(menu, TEXT["note"] % mark, menu.DIM).set_meta("mark_seal_note", part)
	_label(menu, TEXT["warn"] % mark, UI.BAD).set_meta("mark_seal_warn", part)
	var row: HBoxContainer = menu._row()
	var armed := armed(menu)
	var b: Button = menu._button(menu.Nav.fill(TEXT["break_again"], main) if armed else String(TEXT["break"]), _do_break.bind(menu), row)
	b.set_meta("help", "mark_seal_break")
	b.set_meta("mark_seal", part)
	b.set_meta("mark_seal_armed", armed)
	b.custom_minimum_size.x = 240.0 if not menu.compact() else 200.0
	if armed:
		b.add_theme_color_override("font_color", UI.BAD)
	UI.keep_text(b)


static func _label(menu, text: String, col: Color) -> Label:
	var l: Label = menu._small_label(text, col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 280.0 if not menu.compact() else 240.0
	menu.box.add_child(l)
	return l


## True while the first press of Break the seal is armed.
static func armed(menu) -> bool:
	var ms := int(menu.get_meta("mark_seal_armed", -1))
	return ms >= 0 and Time.get_ticks_msec() - ms < ARM_MS


## Break the seal: the first press arms it, the second (within ARM_MS) breaks it.
static func _do_break(menu) -> void:
	var main = menu.main
	var prof = main.profile
	if not armed(menu):
		menu.set_meta("mark_seal_armed", Time.get_ticks_msec())
		main.sfx("ui_confirm", 0.8, -4.0, 0.0)
		load("res://scripts/body_move.gd")._redraw(menu, "mark_seal_break")
		return
	menu.remove_meta("mark_seal_armed")
	var got := break_seal(prof, bool(main.on_train))
	if bool(got["ok"]):
		main.sfx("crit", 0.5, -2.0, 0.0)
		prof.save()
		main._give_bonds()
		menu.set_meta("seal_told", main.tip_now("mark_seal_broken"))  # (said at the top of the Body tab that opens now: node_seal.gd)
	else:
		main.sfx("ui_back", 1.0, -6.0, 0.0)
	menu.toast = String(got["line"])
	menu.toast_t = 4.0
	load("res://scripts/body_move.gd")._redraw(menu, "ub_seal" if bool(got["ok"]) else "mark_seal_break")
