extends RefCounted
## Moving essence on the climber screen's Body tab (body_move.gd): it works
## off the train (in a climb); the default target is a real part that can
## take it (never a drain); pressing To skips the parts that can't; Drain
## into crystals is its own button; the reason shows right under the
## control when a move can't happen; the result line shows there too, and
## the cards show the change; pressing a part's card chooses it; the move is
## refused while a monster is after the climber; on a phone the page stays
## where it was and fits 844x390; the Techniques page only points there now;
## and the Entity explains every button. Run by smoke_test.gd (_part_tests).

const U := preload("res://scripts/unbound.gd")
const BM := preload("res://scripts/body_move.gd")

var t
var main
var menu


func run(smoke) -> void:
	t = smoke
	print("moving essence on the Body tab")
	await t._ub_fresh()
	main = t.main
	menu = main.menu
	var prof = main.profile
	prof.saving = false
	main.on_train = false
	main.in_camp = false
	main.touch._set_active(false)
	# The hand holds Blade 60; the legs are full (they can't take any), so the
	# first part that can take Blade is the heart; the brow holds three kinds.
	prof.part_density["legs"] = {"air": 120.0}
	U.put(prof, "brow", "water", 20.0)
	U.put(prof, "brow", "air", 10.0)
	U.Core.sync(prof)
	for m in ["move_from", "move_kind", "move_to", "move_said"]:
		menu.remove_meta(m)
	menu.climber_tab = "marks"
	menu.open("climber")
	await t._frames(3)
	_check(menu.climber_tabs()[menu.MARKS_TAB_INDEX][1] == "Body", "an Unbound's Marks tab is the Body tab")
	var cards: Array = _with("help", "ub_part")
	_check(cards.size() == 6, "each body part's card is a button (%d)" % cards.size())
	var p := BM.plan(menu)
	_check(p["from"] == "hand" and p["kind"] == "blade" and p["to"] == "heart", "by default: from the hand, its Blade, to the first part that can take it (the heart, not the full legs, never a drain): %s" % [[p["from"], p["kind"], p["to"]]])
	var to_b := _one("ub_move_to")
	var mv := _one("ub_move")
	var dr := _one("ub_drain")
	_check(to_b != null and to_b.text.contains("Heart") and not to_b.text.to_lower().contains("crystal"), "the To button names the heart (%s)" % (to_b.text if to_b != null else "none"))
	_check(mv != null and not mv.disabled and mv.text.contains("6") and mv.text.contains("1.5"), "Move works off the train and shows the amount and the price (%s)" % (mv.text if mv != null else "none"))
	_check(dr != null and dr != mv and not dr.disabled and dr.text.to_lower().contains("crystals"), "Drain into crystals is its own button (%s)" % (dr.text if dr != null else "none"))
	# Move, in a climb.
	var hand0: float = U.amount(prof, "hand", "blade")
	mv.pressed.emit()
	await t._frames(3)
	_check(not main.on_train and is_equal_approx(U.amount(prof, "hand", "blade"), hand0 - U.MOVE_STEP) and is_equal_approx(U.amount(prof, "heart", "blade"), U.MOVE_STEP * (1.0 - U.MOVE_COST)),
		"Move moves 6 Blade from the hand to the heart in a climb (4.5 arrives)")
	var said := _labels("move_said")
	_check(said.size() == 1 and said[0].text.begins_with("Moved"), "the result shows (%s)" % (said[0].text if not said.is_empty() else "none"))
	var grid: Control = _first_meta(menu.box, "body_move")
	var drain_row: Control = _one("ub_drain").get_parent() if _one("ub_drain") != null else null
	_check(not said.is_empty() and grid != null and drain_row != null and said[0].get_index() > grid.get_index() and said[0].get_index() < drain_row.get_index(),
		"...right under the control, not at the foot of the page")
	var hand_card: Array = _with("help", "ub_part").filter(func(b): return b.get_meta("part", "") == "hand")
	_check(hand_card.size() == 1 and hand_card[0].text.contains("Blade %d" % int(round(hand0 - U.MOVE_STEP))), "the hand's card shows the change at once")
	await t._frames(2)
	var fo: Control = main.get_viewport().gui_get_focus_owner()
	_check(fo != null and fo.get_meta("help", "") == "ub_move", "keys and controller: the focus stays on Move")
	# Drain, on its own button.
	var c0: float = prof.crystal_total("blade")
	var h1: float = U.amount(prof, "hand", "blade")
	_one("ub_drain").pressed.emit()
	await t._frames(3)
	_check(is_equal_approx(U.amount(prof, "hand", "blade"), h1 - U.MOVE_STEP) and prof.crystal_total("blade") > c0, "Drain into crystals drains 6 into Blade crystals (%d to %d)" % [int(c0), int(prof.crystal_total("blade"))])
	_check(not _labels("move_said").is_empty() and _labels("move_said")[0].text.begins_with("Drained"), "...and says so under the control")
	# A card chooses the part to move out of.
	var back_card: Array = _with("help", "ub_part").filter(func(b): return b.get_meta("part", "") == "back")
	back_card[0].pressed.emit()
	await t._frames(3)
	p = BM.plan(menu)
	_check(p["from"] == "back" and p["kind"] == "stone" and _with("move_from_card", true).size() == 1 and _with("move_from_card", true)[0].get_meta("part", "") == "back",
		"pressing a part's card chooses it to move out of (marked with a gold edge)")
	# To skips the parts that can't take it (the full legs, the brow with three kinds).
	var seen := {}
	for i in 8:
		_one("ub_move_to").pressed.emit()
		await t._frames(2)
		seen[BM.plan(menu)["to"]] = true
	_check(not seen.has("legs") and not seen.has("brow") and not seen.has("") and not seen.has("back") and seen.size() == 3, "pressing To offers only parts that can take Stone: %s" % str(seen.keys()))
	# A target that can't take it (as when it has just filled): why, right there.
	menu.set_meta("move_to", "brow")
	menu.open("climber", menu.opened_direct)
	await t._frames(3)
	var why := _labels("move_why")
	var back0: float = U.amount(prof, "back", "stone")
	_check(why.size() == 1 and why[0].text == U.why_not(prof, "brow", "stone") and why[0].text.contains("three") and _one("ub_move").disabled,
		"a move that can't happen says why under the control, and Move waits (%s)" % (why[0].text if not why.is_empty() else "none"))
	BM._do_move(menu, false)
	await t._frames(3)
	_check(is_equal_approx(U.amount(prof, "back", "stone"), back0), "...and nothing moves")
	# Hunted: no moving until no monster is after you.
	menu.remove_meta("move_to")
	var e = await t._spawn("slime", main.player.global_position + Vector2(160, 0))
	await t._frames(2)
	e.aware = true
	e.notice_t = 0.0
	e.lost_t = 0.0
	_check(BM.hunted(main), "a monster that has noticed you is hunting you")
	menu.open("climber", menu.opened_direct)
	await t._frames(3)
	mv = _one("ub_move")
	_check(mv != null and mv.disabled and mv.text == BM.TEXT["wait"] and _one("ub_drain").disabled, "while hunted, Move says to wait (%s) and Drain waits too" % (mv.text if mv != null else "none"))
	why = _labels("move_why")
	_check(why.size() == 1 and why[0].text == BM.TEXT["hunted"], "...and the line under it explains")
	BM._do_move(menu, false)
	BM._do_move(menu, true)
	await t._frames(3)
	_check(is_equal_approx(U.amount(prof, "back", "stone"), back0), "...and nothing moves or drains while hunted")
	e.notice_t = 5.0  # (still noticing you: not after you yet)
	_check(not BM.hunted(main), "a monster that hasn't noticed you isn't hunting you")
	e.notice_t = 0.0
	main.in_camp = true
	_check(not BM.hunted(main), "at a camp, never hunted")
	main.in_camp = false
	e.queue_free()
	await t._frames(2)
	_check(not BM.hunted(main), "no monster left: free to move")
	# A phone: the page stays where it was after a press, and fits 844x390.
	var was_size: Vector2i = t.root.size
	t.root.size = Vector2i(844, 390)
	main.touch._set_active(true)
	menu.set_meta("move_from", "hand")
	menu.remove_meta("move_kind")
	menu.open("climber", menu.opened_direct)
	await t._frames(3)
	menu.scroll.scroll_vertical = 100000
	await t._frames(2)
	var sv: int = menu.scroll.scroll_vertical
	var h2: float = U.amount(prof, "hand", "blade")
	_one("ub_move").pressed.emit()
	await t._frames(4)
	_check(U.amount(prof, "hand", "blade") < h2 and sv > 0 and absi(menu.scroll.scroll_vertical - sv) <= 2, "a tap on Move: the page stays where it was (%d, %d)" % [sv, menu.scroll.scroll_vertical])
	var problems: Array = t._fit_problems("body tab 844x390", menu.panel, t.root.get_visible_rect())
	_check(problems.is_empty(), "the Body tab fits a phone (%d problems): %s" % [problems.size(), problems.slice(0, 6)])
	main.touch._set_active(false)
	t.root.size = was_size
	menu.close()
	await t._frames(2)
	# The Techniques tab only points to the Body tab.
	main.on_train = true
	menu.set_meta("tech_slot", 0)
	menu.climber_tab = "techniques"
	menu.open("climber", true)
	await t._frames(3)
	var old_move: Array = t._all_buttons(menu).filter(func(b): return String(b.get_meta("help", "")).begins_with("ub_move") or b.get_meta("help", "") == "ub_drain")
	var go := _one("ub_body_open")
	_check(old_move.is_empty() and go != null, "the Techniques tab has no move controls, only the way to the Body tab")
	if go != null:
		go.pressed.emit()
		await t._frames(3)
	_check(menu.page == "climber" and menu.climber_tab == "marks" and _one("ub_move") != null, "...which opens the climber screen on the Body tab")
	menu.close()
	main.on_train = false
	await t._frames(2)
	# The Entity's words.
	var Help = load("res://scripts/entity_help.gd")
	var E = load("res://scripts/entity.gd")
	for id in ["ub_part", "ub_move_from", "ub_move_kind", "ub_move_to", "ub_move", "ub_drain", "ub_body_open"]:
		_check(Help.HELP.has(id), "hover and hold help for %s" % id)
	_check(E.TIPS.has("unbound_body") and String(E.TIPS["unbound_body"]["tip"]).length() < 140, "the Entity explains the Body tab the first time")
	var words := (str(E.TIPS["unbound_move"]) + str(E.TIPS["unbound"]) + str(load("res://scripts/entity_talk.gd").DIALOGUE["how_unbound"])).to_lower()
	_check(not words.contains("techniques page show") and words.contains("body tab"), "the Entity's words send you to the Body tab, not the Techniques page")


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _with(meta: String, value) -> Array:
	return t._all_buttons(menu).filter(func(b): return b.is_visible_in_tree() and b.has_meta(meta) and b.get_meta(meta) == value)


func _one(help: String) -> Button:
	var bs := _with("help", help)
	return bs[0] if bs.size() == 1 else null


func _labels(meta: String) -> Array:
	return t._all_labels(menu.box).filter(func(l): return l.has_meta(meta) and not l.is_queued_for_deletion())


func _first_meta(n: Node, meta: String) -> Control:
	for c in n.get_children():
		if c.is_queued_for_deletion():
			continue
		if c.has_meta(meta):
			return c
	return null
