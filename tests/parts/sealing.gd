extends RefCounted
## Sealing a Node (unbound.gd seal/unseal, node_seal.gd on the Body tab):
## only an Unbound, only on the train, the confirmation pop-up with a
## clear warning; what the Node held condenses into crystals; routing and
## banked essence skip a sealed Node (most of what would pool there
## condenses on the way, a little reaches the open Nodes); each sealed Node
## makes the open ones grow faster and hit harder; at least one stays open;
## unsealing starts the Node asleep at size 0; the Techniques tab, the Tree
## and the figure show it sealed; it saves and loads (old saves: nothing
## sealed); the pace in climbs (a focused Unbound's Node reaches level 12 a
## little sooner, not drastically); the Entity's words; a tap works; and the
## Body tab fits a phone (844x390). Run by smoke_test.gd (_part_tests).

const TestRun := preload("res://scripts/test_run.gd")
const U := preload("res://scripts/unbound.gd")
const Seal := preload("res://scripts/node_seal.gd")
const BM := preload("res://scripts/body_move.gd")
const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]
## The pace (tests/progression_model.gd run_unbound, one Node open: the
## Legs, the own tower's kind's): level 12 in about 15 to 18 typical climb
## attempts (a broad climber's main Node: about 22), never faster for a spammer.
const FOCUS_TOP := [14, 19]

var t
var main
var menu


func run(smoke) -> void:
	t = smoke
	print("sealing a Node")
	_rules()
	_bonus()
	_save_load()
	_pace()
	_words()
	await _in_menu()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _prof():
	var p = load("res://scripts/profile.gd").new()
	p.saving = false
	U.become(p)
	return p


func _rules() -> void:
	var m = load("res://scripts/profile.gd").new()
	m.saving = false
	_check(not U.seal(m, "hand")["ok"] and not U.sealed(m, "hand"), "a marked climber can't seal: it's the Unbound's choice")
	var p = _prof()
	U.put(p, "hand", "blade", 40.0)
	U.put(p, "hand", "fire", 10.0)
	U.set_size(p, "hand", 60.0)
	U.sync_techs(p)
	_check(not U.seal(p, "hand", false)["ok"] and not U.sealed(p, "hand"), "off the train, a Node can't be sealed")
	var c0: float = p.crystal_total("blade") + p.crystal_total("fire")
	var got: Dictionary = U.seal(p, "hand", true)
	_check(got["ok"] and U.sealed(p, "hand") and int(got["crystals"]) == 50 and is_equal_approx(p.crystal_total("blade") + p.crystal_total("fire"), c0 + 50.0), "on the train it seals: what it held condenses into crystals (%s)" % got["line"])
	_check(U.size(p, "hand") == 0.0 and not U.awake(p, "hand") and U.own(p, "hand") == 0.0 and U.tech_of(p, 0).is_empty() and not U.has_gift(p, "hand") and not U.has_minor(p, "hand") and U.attr_size(p, "blade") == 0.0,
		"...and gives the Node up: no size, technique, gift, minor ability or attributes")
	_check(U.put(p, "hand", "blade", 10.0) == 0.0 and U.settle_into(p, "hand", "blade", 30.0) == 30.0 and U.feed(p, "hand", "blade", 10.0) == 0.0, "a sealed Node takes no essence")
	# Routing skips it; its kind flows to the biggest open Node.
	U.put(p, "legs", "air", 50.0)
	_check(U.part_for(p, "blade") == "legs" and U.open_default(p) == "legs", "banked Blade, whose Node is sealed, goes to the biggest open Node (%s)" % U.part_for(p, "blade"))
	U.route(p, "water", "hand")
	_check(U.part_for(p, "water") == "throat", "routing to a sealed Node is refused")
	U.route(p, "water", "legs")
	U.route(p, "fire", "brow")
	_check(U.part_for(p, "water") == "legs", "...routing to an open one still works")
	var cb: float = p.crystal_total("blade")
	var legs0: float = U.size(p, "legs")
	U.note_use(p, "legs", 40.0, "cast")
	var left: float = U.settle(p, "blade", 100.0)
	_check(U.diverted(p, "blade") and U.size(p, "legs") > legs0 and U.pay_rate(p, "legs", "blade") < 1.0, "it flows on to the open Node, where as another kind it pays only a third of a refill (%.0f of 100 left over)" % left)
	U.end_stair(p)
	p.pour({"blade": 60.0}, {}, 0.0)
	_check(p.crystal_total("blade") > cb, "banked at a stair with no use to refill, a sealed Node's kind condenses into crystals instead of pooling there")
	# The figure, the Techniques tab: the move control skips it.
	_check(not U.awake(p, "hand") and not ("hand" in BM.targets(p, "legs", "air")), "moving essence never targets a sealed Node")
	_check(U.why_not(p, "hand", "air").contains("sealed") and U.move(p, "air", "legs", "hand")["ok"] == false, "...and says why: %s" % U.why_not(p, "hand", "air"))
	# At least one stays open.
	for pt in ["heart", "brow", "throat", "back"]:
		U.seal(p, pt)
	_check(U.open_parts(p) == ["legs"] and not U.seal(p, "legs")["ok"] and U.why_not_seal(p, "legs", true) != "", "at least one Node stays open: the last can't be sealed (%s)" % U.why_not_seal(p, "legs", true))
	# Unsealing: asleep, size 0.
	var un: Dictionary = U.unseal(p, "hand", false)
	_check(not un["ok"] and U.sealed(p, "hand"), "unsealing happens only on the train too")
	un = U.unseal(p, "hand", true)
	_check(un["ok"] and not U.sealed(p, "hand") and U.size(p, "hand") == 0.0 and not U.awake(p, "hand") and U.own(p, "hand") == 0.0, "unsealed, it starts again asleep, at size 0 (%s)" % un["line"])
	U.settle_into(p, "hand", "blade", 30.0)
	_check(U.size(p, "hand") > 0.0 and not U.awake(p, "hand"), "...and soaks up essence again like any sleeping Node")
	# Making's core leaves a sealed Node.
	var q = _prof()
	q.path = "life"
	U.Core.bank(q, 120.0)
	var c_in: float = U.Core.in_part(q, "back")
	U.seal(q, "back")
	_check(c_in > 0.0 and U.Core.in_part(q, "back") < 0.01 and is_equal_approx(U.Core.total(q), 60.0), "a sealed Node holds no core essence: it moves to the open ones (%.0f in all)" % U.Core.total(q))


func _bonus() -> void:
	var a = _prof()
	var b = _prof()
	for p in [a, b]:
		U.put(p, "legs", "air", 60.0)
		U.note_use(p, "legs", 60.0, "cast")
	U.seal(b, "hand")
	U.seal(b, "heart")
	var pa: float = U.power(a, "legs")
	var pb: float = U.power(b, "legs")
	_check(is_equal_approx(pb, pa * (1.0 + 2.0 * float(U.SEAL["power"]))), "each sealed Node makes the open ones' techniques hit harder (+%d%% each: %.2f to %.2f)" % [int(float(U.SEAL["power"]) * 100.0), pa, pb])
	_check(is_equal_approx(U.growth_mult(b), 1.0 + 2.0 * float(U.SEAL["growth"])) and is_equal_approx(U.growth_mult(a), 1.0), "...and grow faster from use (+%d%% each)" % int(float(U.SEAL["growth"]) * 100.0))
	U.settle_into(a, "legs", "air", 400.0)
	U.settle_into(b, "legs", "air", 400.0)
	_check(U.size(b, "legs") > U.size(a, "legs") + 0.1, "the same refilled use grows a focused Node more (%.1f against %.1f)" % [U.size(b, "legs"), U.size(a, "legs")])
	_check(float(U.SEAL["growth"]) > 0.0 and float(U.SEAL["power"]) > 0.0 and float(U.USE["other"]) < 1.0, "the sealing numbers live in unbound.gd SEAL (%s), the one rule in USE \"other\"" % str(U.SEAL))


func _save_load() -> void:
	var path := TestRun.path("user://sealing_test.cfg")
	var p = load("res://scripts/profile.gd").new()
	p.save_path = path
	U.become(p)
	U.put(p, "legs", "air", 40.0)
	U.seal(p, "brow")
	p.save()
	var q = load("res://scripts/profile.gd").new()
	q.saving = false
	q.save_path = path
	q.load_save()
	_check(U.sealed(q, "brow") and not U.sealed(q, "legs") and U.sealed_count(q) == 1, "a sealed Node is saved and loaded")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var old := ConfigFile.new()
	old.set_value("profile", "regarded", true)
	old.set_value("unbound", "state", {"on": true, "techs": [{}, {}, {}, {}, {}, {}]})
	old.save(path)
	var r = load("res://scripts/profile.gd").new()
	r.saving = false
	r.save_path = path
	r.load_save()
	_check(U.is_on(r) and U.sealed_count(r) == 0 and U.open_parts(r).size() == 6, "an old save has nothing sealed")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## The pace: one Node open against the broad climber's main Node.
func _pace() -> void:
	var M = load("res://tests/progression_model.gd")
	var focus := ["hand", "heart", "brow", "throat", "back"]
	var broad: int = int(M.run_unbound("typical", 45)["top"]["legs"])
	var one: int = int(M.run_unbound("typical", 45, "typical", "natural", focus)["top"]["legs"])
	var spam: int = int(M.run_unbound("typical", 45, "spam", "natural", focus)["top"]["legs"])
	_check(one > 0 and one < broad and one >= FOCUS_TOP[0] and one <= FOCUS_TOP[1], "one Node open reaches level 12 a little sooner than a broad climber's main Node, not drastically: %d climbs against %d (%d to %d)" % [one, broad, FOCUS_TOP[0], FOCUS_TOP[1]])
	_check(spam >= one - 1, "...and spamming casts doesn't race ahead (%d)" % spam)
	var idle: Dictionary = M.run_unbound("typical", 30, "none", "natural", focus)
	_check(int(idle["top"]["legs"]) == 0, "never using it, a focused Node still grows only by use (no level 12 in 30 climbs)")


func _words() -> void:
	var E = load("res://scripts/entity.gd")
	var Talk = load("res://scripts/entity_talk.gd")
	var Help = load("res://scripts/entity_help.gd")
	var texts: Array = [str(Seal.TEXT), str(U.TEXT), str(U.SEAL)]
	for id in ["node_seal", "node_sealed", "node_unsealed"]:
		var e: Dictionary = E.TIPS.get(id, {})
		_check(e.has("tip") and e.has("more") and String(e["tip"]).length() < 140, "the Entity explains '%s' (a short line and an Archive account)" % id)
		texts.append(str(e))
	_check(Talk.DIALOGUE.has("how_sealing") and String(Talk.DIALOGUE["how_sealing"]["ask"]) == "Sealing a Node?" and "how_sealing" in Talk.DIALOGUE["how"]["choices"] and "how_sealing" in Talk.DIALOGUE["how_unbound"]["choices"], "'How does it work?' has 'Sealing a Node?'")
	texts.append(str(Talk.DIALOGUE.get("how_sealing", {})))
	for id in ["ub_seal", "ub_unseal", "ub_part_sealed"]:
		_check(Help.HELP.has(id), "hover and hold help for %s" % id)
		texts.append(String(Help.HELP.get(id, "")))
	var all := " ".join(texts).to_lower()
	var found: Array = BANNED.filter(func(w): return all.contains(w))
	_check(found.is_empty(), "none of the owner's banned words in sealing's words (%s)" % ", ".join(found))
	_check(not str(E.TIPS["node_grows"]).contains("only so much") and not str(Talk.DIALOGUE["how_unbound"]).contains("only so much"), "the Entity no longer speaks of a cap a climb")


## The Body tab: on the train only, a warning and a second press, the
## figure and cards, the Techniques tab and the Tree; a tap; a phone.
func _in_menu() -> void:
	print("sealing a Node, on the Body tab")
	await t._ub_fresh()
	main = t.main
	menu = main.menu
	var prof = main.profile
	prof.saving = false
	main.touch._set_active(false)
	for m in ["node_pick", "move_from", "move_kind", "move_to", "seal_told"]:
		menu.remove_meta(m)
	# Off the train: no Seal button.
	main.on_train = false
	menu.set_meta("node_pick", "throat")
	menu.climber_tab = "marks"
	menu.open("climber")
	await t._frames(3)
	_check(_one("ub_seal") == null and _one("ub_unseal") == null, "off the train the Body tab offers no sealing")
	menu.close()
	await t._frames(2)
	# On the train: the warning, then the confirmation pop-up.
	main.on_train = true
	menu.open("climber")
	await t._frames(3)
	var sb := _one("ub_seal")
	var warn: Array = _labels("seal_warn")
	_check(sb != null and not sb.disabled and sb.text.contains("Throat"), "on the train the chosen Node can be sealed (%s)" % (sb.text if sb != null else "none"))
	_check(warn.size() == 1 and warn[0].text.contains("crystals") and warn[0].text.contains("size 0") and warn[0].text.contains("technique"), "...under a clear warning of what's lost: %s" % (warn[0].text if not warn.is_empty() else "none"))
	var c0: float = prof.crystal_total("water")
	if sb != null:
		sb.pressed.emit()
	await t._frames(3)
	_check(not U.sealed(prof, "throat") and menu.asking() and menu.pop.text_l.text.contains("crystals") and menu.pop.yes.text.contains("Throat"), "a press only asks: the pop-up, with the warning (%s)" % menu.pop.text_l.text)
	await t._confirm(false)
	await t._frames(2)
	_check(not U.sealed(prof, "throat") and not menu.asking(), "...Cancel seals nothing")
	Engine.set_meta("sixfold_tips", true)  # (the Entity's words, live for this press)
	main.GuideScript.forget()
	sb = _one("ub_seal")
	if sb != null:
		sb.pressed.emit()
	await t._frames(2)
	await t._confirm(true)
	await t._frames(3)
	_check(U.sealed(prof, "throat") and prof.crystal_total("water") > c0, "Confirm seals it; what it held is crystals now")
	var tip_words := String(load("res://scripts/entity.gd").TIPS["node_sealed"]["tip"]).left(24)
	_check(t._all_labels(menu.box).any(func(l): return not l.is_queued_for_deletion() and l.text.contains(tip_words)), "the Entity says what sealing did, there on the page")
	Engine.remove_meta("sixfold_tips")
	main.GuideScript.forget()
	main.GuideScript.queue.clear()
	_check(_one("ub_unseal") != null and not _labels("seal_note").is_empty(), "...and the section offers to unseal it, saying what it means")
	var card: Array = t._all_buttons(menu).filter(func(b): return b.get_meta("part", "") == "throat" and b.has_meta("node_sealed"))
	_check(card.size() == 1 and bool(card[0].get_meta("node_sealed")) and card[0].text.to_lower().contains("sealed") and String(card[0].get_meta("help", "")) == "ub_part_sealed", "its card shows it sealed")
	# The Techniques tab and the Tree treat it as sealed.
	menu.set_meta("tech_slot", U.PARTS.find("throat"))
	menu.climber_tab = "techniques"
	menu.open("climber", true)
	await t._frames(3)
	var slot: Array = t._all_buttons(menu).filter(func(b): return not b.is_queued_for_deletion() and b.has_meta("tech_slot") and int(b.get_meta("tech_slot")) == U.PARTS.find("throat"))
	_check(slot.size() == 1 and slot[0].text.contains("sealed") and slot[0].has_meta("tech_sealed"), "the Techniques tab's slot says sealed (%s)" % (slot[0].text if not slot.is_empty() else "none"))
	_check(not _labels("tech_sealed").is_empty(), "...and its card says it carries no technique")
	var routes: Array = t._all_buttons(menu).filter(func(b): return not b.is_queued_for_deletion() and b.has_meta("route") and b.get_meta("route") == "water")
	_check(routes.size() == 1 and not routes[0].text.contains("Throat"), "Water no longer pools in the sealed Throat Node (%s)" % (routes[0].text if not routes.is_empty() else "none"))
	if not routes.is_empty():
		for i in 8:
			routes[0].pressed.emit()
			await t._frames(1)
			routes = t._all_buttons(menu).filter(func(b): return not b.is_queued_for_deletion() and b.has_meta("route") and b.get_meta("route") == "water")
			_check(routes.size() == 1 and U.part_for(prof, "water") != "throat", "routing skips the sealed Node (press %d: %s)" % [i + 1, U.part_for(prof, "water")])
	_check(load("res://scripts/tree_view.gd")._head(prof, "throat").contains("sealed"), "the Tree names it sealed")
	# Unseal: it asks first too.
	menu.climber_tab = "marks"
	menu.set_meta("node_pick", "throat")
	menu.open("climber", true)
	await t._frames(3)
	var ub := _one("ub_unseal")
	if ub != null:
		ub.pressed.emit()
	await t._frames(2)
	_check(U.sealed(prof, "throat") and menu.asking(), "Unseal asks first")
	await t._confirm(true)
	await t._frames(3)
	_check(not U.sealed(prof, "throat") and U.size(prof, "throat") == 0.0 and not U.awake(prof, "throat"), "Unseal opens it again, asleep at size 0")
	# A tap on a phone, and the page fits 844x390.
	var was_size: Vector2i = t.root.size
	t.root.size = Vector2i(844, 390)
	main.touch._set_active(true)
	menu.set_meta("node_pick", "back")
	menu.open("climber", true)
	await t._frames(3)
	var tb := _one("ub_seal")
	if tb != null:
		menu.scroll.ensure_control_visible(tb)
		await t._frames(2)
		await t._tap_at(tb.get_global_rect().get_center())
		await t._frames(3)
	var view_r: Rect2 = t.root.get_visible_rect()
	_check(menu.asking() and view_r.encloses(menu.pop.card.get_global_rect()) and not U.sealed(prof, "back"), "a tap on Seal opens the pop-up, which fits the phone (%s in %s)" % [menu.pop.card.get_global_rect(), view_r])
	if menu.asking():
		await t._tap_at(menu.pop.no.get_global_rect().get_center())
		await t._frames(2)
	_check(not menu.asking() and not U.sealed(prof, "back"), "...and a tap on Cancel closes it, nothing sealed")
	var problems: Array = t._fit_problems("body tab sealing 844x390", menu.panel, t.root.get_visible_rect())
	_check(problems.is_empty(), "the Body tab with its seal fits a phone (%d problems): %s" % [problems.size(), problems.slice(0, 6)])
	main.touch._set_active(false)
	t.root.size = was_size
	menu.close()
	main.on_train = false
	await t._frames(2)


func _one(help: String) -> Button:
	var bs: Array = t._all_buttons(menu).filter(func(b): return b.is_visible_in_tree() and b.get_meta("help", "") == help)
	return bs[0] if bs.size() == 1 else null


func _labels(meta: String) -> Array:
	return t._all_labels(menu.box).filter(func(l): return l.has_meta(meta) and not l.is_queued_for_deletion())
