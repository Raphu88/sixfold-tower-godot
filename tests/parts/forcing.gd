extends RefCounted
## Forcing essence past full (forcing.gd): a full mark or Node can be forced
## from a crystal (or, for the Unbound, a tincture) at FORCE "cost" times the
## essence use-growth takes; each push strains the part, and the strain
## fades at stairs and as a climb starts; the ladder (strained, burned,
## paralyzed, then a mark burns out or a Node cracks, losing size); the
## pop-up says where it would leave the part and Cancel does nothing; it
## works in a climb (at once, on the climber's marks and the Unbound's
## strain meter) and on the train; normal eating is unchanged (what can't go
## in stays a crystal); the Entity explains it; no banned words. The pace
## with a climber who force-eats everything is held by progression.gd,
## unbound_cup.gd and essence_pace.gd. Run by smoke_test.gd (_part_tests).

const F := preload("res://scripts/forcing.gd")
const PS := preload("res://scripts/profile.gd")
const MU := preload("res://scripts/mark_use.gd")
const U := preload("res://scripts/unbound.gd")
const Items := preload("res://scripts/items.gd")
const Flow := preload("res://scripts/essence_flow.gd")
const Guide := preload("res://scripts/guide.gd")
const Help := preload("res://scripts/entity_help.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

var t


func run(smoke) -> void:
	t = smoke
	print("forcing past full: the cost, the strain, the ladder")
	_data()
	_mark_force()
	_ladder_mark()
	_node_force()
	_ladder_node()
	_not_full()
	await _in_climb()
	await _on_train()
	await _unbound_climb()
	await _entity()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## A marked profile (nothing saved): a Stormcaller (Air) on the hand.
func _marked():
	var p = PS.new()
	p.saving = false
	p.regarded = true
	p.add_bond("hand", "stormcaller", false)
	p.bonds["hand"]["xp"] = 200.0
	return p


func _unbound():
	var p = PS.new()
	p.saving = false
	p.regarded = true
	U.become(p)
	return p


func _data() -> void:
	_check(is_equal_approx(float(F.FORCE["cost"]), 4.0), "forced growth costs %sx the essence use-growth would (about 4x, the owner's design)" % F.FORCE["cost"])
	_check(float(F.LADDER["burned"]) < float(F.LADDER["paralyzed"]) and float(F.LADDER["paralyzed"]) < float(F.LADDER["break"]), "the ladder climbs: burned, then paralyzed, then the break (%s)" % F.LADDER)
	_check(float(F.FORCE["fade_stair"]) > 0.0 and float(F.FORCE["fade_climb"]) > 0.0, "strain fades at stairs and as a climb starts")
	var reg = load("res://scripts/data_registry.gd")
	var tables: Array = []
	for s in reg.SECTIONS:
		tables.append_array(s["tables"])
	_check(tables.has("forcing/FORCE") and tables.has("forcing/LADDER") and tables.has("forcing/TEXT"), "its numbers and words are in the Data editor")


## A full mark grows at the higher cost: a quarter of what the same essence
## does through use.
func _mark_force() -> void:
	var p = _marked()
	_check(F.can_force(p, "hand", "air"), "a mark with no use waiting is full: it can be forced")
	var xp0 := float(p.bonds["hand"]["xp"])
	var res: Dictionary = F.force(p, "hand", "air", 10.0)
	var forced := float(p.bonds["hand"]["xp"]) - xp0
	# Use-growth: the stair pays a use u back and deepens 0.6 u, costing u + 0.6 u.
	var q = _marked()
	MU.note_use(q, "hand", 100.0)
	var y0 := float(q.bonds["hand"]["xp"])
	MU.settle(q, {"air": 160.0})
	var by_use := (float(q.bonds["hand"]["xp"]) - y0) / 160.0
	_check(forced > 0.0 and absf(by_use / (forced / 10.0) - float(F.FORCE["cost"])) < 0.05, "forcing a full mark deepens it at %sx the essence use takes (%.3f a forced essence, %.3f by use)" % [F.FORCE["cost"], forced / 10.0, by_use])
	_check(is_equal_approx(F.strain(p, "hand"), 10.0 * float(F.FORCE["strain"])) and int(res["rung"]) == F.STRAINED, "it adds strain (%.1f): Strained" % F.strain(p, "hand"))
	var other = _marked()
	var x1 := float(other.bonds["hand"]["xp"])
	F.force(other, "hand", "fire", 10.0)
	_check(absf((float(other.bonds["hand"]["xp"]) - x1) * 3.0 - forced) < 0.01 and is_equal_approx(F.strain(other, "hand"), F.strain(p, "hand")), "another kind does a third as much, for the same strain")
	# Fading.
	var lines: Array = F.stair(p)
	_check(is_equal_approx(F.strain(p, "hand"), maxf(0.0, 10.0 * float(F.FORCE["strain"]) - float(F.FORCE["fade_stair"]))), "a stair fades it a little (%.1f)" % F.strain(p, "hand"))
	lines = F.new_climb(p)
	_check(F.strain(p, "hand") == 0.0 and not p.bonds["hand"].has("strain") and lines.size() == 1 and String(lines[0]).contains("fades"), "a new climb fades more: gone (%s)" % [lines])
	F.set_strain(p, "hand", float(F.LADDER["break"]) - 1.0)
	var climbs := 0
	while F.strain(p, "hand") > 0.0 and climbs < 6:
		climbs += 1
		F.new_climb(p)
		for i in 9:
			F.stair(p)
	_check(climbs >= 1 and climbs <= 2, "from just short of the break it fades over a climb or two (%d)" % climbs)


func _ladder_mark() -> void:
	var p = _marked()
	F.set_strain(p, "hand", float(F.LADDER["burned"]) - 5.0)
	var pv: Dictionary = F.preview(p, "hand", "air", 10.0)
	_check(int(pv["before"]) == F.STRAINED and int(pv["after"]) == F.BURNED, "strained, a crystal more pushes it to burned")
	_check(F.ask_text(p, "hand", "air", 10.0).contains("Burned"), "...and the pop-up says so: %s" % F.ask_text(p, "hand", "air", 10.0))
	F.force(p, "hand", "air", 10.0)
	_check(F.rung(p, "hand") == F.BURNED, "forced, it is burned")
	F.set_strain(p, "hand", float(F.LADDER["paralyzed"]) - 5.0)
	F.force(p, "hand", "air", 10.0)
	_check(F.rung(p, "hand") == F.PARALYZED, "...then paralyzed")
	F.set_strain(p, "hand", float(F.LADDER["break"]) - 5.0)
	var text := F.ask_text(p, "hand", "air", 10.0)
	_check(int(F.preview(p, "hand", "air", 10.0)["after"]) == F.BROKEN and text.contains("BURNS OUT") and text.contains("guardians"), "pushed past paralyzed, the pop-up warns it burns out: %s" % text)
	var xp0 := float(p.bonds["hand"]["xp"])
	var slips: int = p.count("slips")
	var res: Dictionary = F.force(p, "hand", "air", 10.0)
	_check(bool(res["broke"]) and MU.dark(p, "hand") and p.count("slips") == slips + 1 and float(p.bonds["hand"]["xp"]) < xp0 + 1.0, "...and it does: dark, a little shallower, a slip toward a Maker")
	_check(F.strain(p, "hand") == 0.0 and not F.can_force(p, "hand", "air"), "a dark mark can't be forced again")


func _node_force() -> void:
	var p = _unbound()
	U.set_node(p, "legs", {"air": 60.0})
	_check(F.can_force(p, "legs", "air") and F.targets(p, "air") == ["legs"], "a full, awake Node can be forced with the kind that flows to it")
	var s0: float = U.size(p, "legs")
	var pv: Dictionary = F.preview(p, "legs", "air", 10.0)
	F.force(p, "legs", "air", 10.0)
	var want := s0 + 10.0 * U.COST_BAND / (float(U.GROW_COST[U.cost_band(s0)]) * float(F.FORCE["cost"]))
	_check(absf(U.size(p, "legs") - want) < 0.001 and absf(float(pv["size"]) - want) < 0.001, "it stretches at %sx its use cost: size %.3f to %.3f" % [F.FORCE["cost"], s0, U.size(p, "legs")])
	_check(is_equal_approx(F.strain(p, "legs"), 10.0 * float(F.FORCE["strain"])) and is_equal_approx(F.strain(p, "hand"), 0.0), "the strain is that Node's own")
	# Normal eating unchanged: into a full Node, what can't go in stays a crystal.
	var q = _unbound()
	U.set_node(q, "legs", {"air": 60.0})
	q.add_crystal("air", 10.0)
	var amount: float = q.take_crystal("air", 10.0)
	q.pour({"air": amount}, {}, 0.0, false)
	_check(is_equal_approx(U.size(q, "legs"), 60.0) and q.crystal_total("air") == 10.0 and F.strain(q, "legs") == 0.0, "eating it the normal way is unchanged: nothing grows, it stays a crystal, no strain")


func _ladder_node() -> void:
	var p = _unbound()
	U.set_node(p, "back", {"stone": 50.0})
	F.set_strain(p, "back", float(F.LADDER["paralyzed"]) - 1.0)
	F.force(p, "back", "stone", 10.0)
	_check(F.rung(p, "back") == F.PARALYZED, "a Node climbs the same ladder: paralyzed")
	var s0: float = U.size(p, "back")
	F.set_strain(p, "back", float(F.LADDER["break"]) - 1.0)
	var text := F.ask_text(p, "back", "stone", 10.0)
	_check(text.contains("CRACKS"), "pushed past paralyzed, the pop-up warns it cracks: %s" % text)
	var res: Dictionary = F.force(p, "back", "stone", 10.0)
	_check(bool(res["broke"]) and U.size(p, "back") < s0 - float(F.FORCE["crack"]) + 1.0 and is_equal_approx(F.strain(p, "back"), float(F.FORCE["crack_strain"])), "...and it cracks, losing %s of its size (%.1f to %.1f)" % [F.FORCE["crack"], s0, U.size(p, "back")])
	U.set_node(p, "brow", {"fire": 32.0})
	F.set_strain(p, "brow", float(F.LADDER["break"]) - 1.0)
	F.force(p, "brow", "fire", 10.0)
	_check(U.awake(p, "brow"), "a crack never puts a Node back to sleep (size %.1f)" % U.size(p, "brow"))


func _not_full() -> void:
	var p = _marked()
	MU.note_use(p, "hand", 10.0)
	_check(not F.can_force(p, "hand", "air") and F.targets(p, "air").is_empty(), "a mark with use waiting isn't full: eating refills it, no Force")
	var q = _unbound()
	U.set_size(q, "legs", 60.0)
	U.put(q, "legs", "air", 20.0)
	_check(not F.can_force(q, "legs", "air"), "a Node with room isn't full: eating fills it, no Force")
	var r = PS.new()
	r.saving = false
	_check(not F.can_force(r, "hand", "air"), "the bondless first climb has nothing to force")


func _fresh_marked() -> void:
	await t._fresh_main()
	t.paused = false
	var main = t.main
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.grant_test_bonds()
	main.profile.crystals = []
	for e in main.enemies():
		e.queue_free()
	await t._frames(2)


## The crystal card's Force it button for a part (null if none).
func _force_button(part: String):
	for b in t.main.menu.focusables():
		if b.has_meta("force_part") and String(b.get_meta("force_part")) == part:
			return b
	return null


func _open_crystal(kind: String) -> void:
	var menu = t.main.menu
	menu.open_pour()
	await t._frames(2)
	menu.inv_sel = "crystal:" + kind
	menu.open("pour", menu.opened_direct)
	await t._frames(2)


func _in_climb() -> void:
	await _fresh_marked()
	var main = t.main
	var prof = main.profile
	var menu = main.menu
	prof.add_crystal("air", 60.0)
	await _open_crystal("air")
	var fb = _force_button("hand")
	var eat = null
	for b in menu.focusables():
		if b.get_meta("help", "") == "pour:eat":
			eat = b
	_check(fb != null and eat != null and fb.get_parent() == eat.get_parent(), "in a climb, a full mark's Force it sits beside Eat")
	var lacking: Array = menu.focusables().filter(func(b): return Help.missing(b)).map(func(b): return Help.words(b))
	_check(lacking.is_empty() and Help.HELP.has("pour:force"), "every button there has the Entity's hover help (lacking: %s)" % [lacking])
	if fb == null:
		menu.close()
		return
	fb.pressed.emit()
	await t._frames(2)
	_check(menu.asking() and menu.pop.text_l.text.contains("Strained") and menu.pop.text_l.text.contains("Hand"), "Force it asks first, saying where it leaves the part: %s" % menu.pop.text_l.text)
	await t._confirm(false)
	await t._frames(2)
	_check(not menu.asking() and prof.crystal_total("air") == 60.0 and F.strain(prof, "hand") == 0.0, "Cancel does nothing")
	var xp0 := float(prof.bonds["hand"]["xp"])
	fb = _force_button("hand")
	fb.pressed.emit()
	await t._frames(2)
	await t._confirm(true)
	await t._frames(2)
	var b = main.player.bonds.get("hand")
	_check(prof.crystal_total("air") == 60.0 - float(Items.CRYSTAL["step"]) and float(prof.bonds["hand"]["xp"]) > xp0 and F.rung(prof, "hand") == F.STRAINED, "Confirm forces a crystal: it deepens, strained")
	_check(b != null and b.strain_fill < 1.0 and menu.toast != "", "...at once: the mark refills slower in this climb (%s)" % menu.toast)
	# Burned mid-fight.
	F.set_strain(prof, "hand", float(F.LADDER["burned"]) - 2.0)
	fb = _force_button("hand")
	fb.pressed.emit()
	await t._frames(2)
	_check(menu.asking() and menu.pop.text_l.text.contains("Burned"), "the pop-up warns of Burned: %s" % menu.pop.text_l.text)
	await t._confirm(true)
	await t._frames(2)
	b = main.player.bonds.get("hand")
	_check(b != null and b.burned and not b.paralyzed, "...and the mark is burned at once")
	# A mark burned by overdrawing starts the push from there.
	b.burned = false
	b.paralyzed = true
	F.set_strain(prof, "hand", 0.0)
	var pv: Dictionary = F.preview(prof, "hand", "air", 10.0, main)
	_check(F.rung(prof, "hand", main) == F.PARALYZED and int(pv["after"]) == F.PARALYZED and float(pv["strain"]) >= float(F.LADDER["paralyzed"]), "a mark paralyzed by overdrawing starts the push from paralyzed (strain %.0f after)" % float(pv["strain"]))
	F.set_strain(prof, "hand", float(F.LADDER["break"]) - 2.0)
	fb = _force_button("hand")
	if fb != null:
		fb.pressed.emit()
		await t._frames(2)
		_check(menu.asking() and menu.pop.text_l.text.contains("BURNS OUT"), "...and the pop-up says so")
		await t._confirm(true)
		await t._frames(2)
	_check(MU.dark(prof, "hand") and not main.player.bonds.has("hand") and String(main.banner.get("title", "")) == String(MU.TEXT["burnout_title"]), "forced past paralyzed in a climb, the mark burns out (the banner shows it)")
	# The stair: a part still burned by its strain stays burned after the rest.
	main.player.bonds["legs"].burned = false
	F.set_strain(prof, "legs", float(F.LADDER["burned"]) + float(F.FORCE["fade_stair"]) + 2.0)
	F.stair(prof)
	F.apply(main)
	_check(main.player.bonds["legs"].burned, "after a stair's fade, a part still strained to burned stays burned")
	menu.close()
	await t._frames(2)


func _on_train() -> void:
	await _fresh_marked()
	var main = t.main
	var prof = main.profile
	var menu = main.menu
	prof.add_crystal("air", 30.0)
	main.open_train()
	await t._frames(3)
	menu.open("climber")
	await t._frames(2)
	await _open_crystal("air")
	var fb = _force_button("legs")
	_check(fb != null, "on the train the crystal card offers Force it too")
	if fb != null:
		fb.pressed.emit()
		await t._frames(2)
		await t._confirm(true)
		await t._frames(2)
	_check(prof.crystal_total("air") == 20.0 and F.rung(prof, "legs") == F.STRAINED, "...and forcing works there")
	menu.close()
	main.on_train = false
	await t._frames(2)


func _unbound_climb() -> void:
	await t._ub_fresh()
	var main = t.main
	var prof = main.profile
	var menu = main.menu
	main.touch._set_active(false)
	main.pad._set_active(false)
	prof.crystals = []
	U.state(prof)["used"] = {}
	_check(F.can_force(prof, "legs", "air"), "an Unbound's full Node can be forced (size %.0f, holding %.0f)" % [U.size(prof, "legs"), U.own(prof, "legs")])
	F.set_strain(prof, "legs", 50.0)
	F.apply(main)
	await t._frames(30)
	_check(main.unbound.strain_of("legs") >= 50.0 - 0.01, "in a climb the forced strain is the floor of the Node's strain meter: it doesn't fade below it (%.1f)" % main.unbound.strain_of("legs"))
	F.set_strain(prof, "legs", float(F.LADDER["paralyzed"]) + 1.0)
	_check(main.unbound.is_dark("legs"), "paralyzed, the Node is dark: nothing from it can be cast")
	F.set_strain(prof, "legs", 0.0)
	# A tincture into a full Node: Force beside it.
	main.player.items["tincture_air"] = 1
	menu.open_pour("tincture_air")
	await t._frames(3)
	var fb = _force_button("legs")
	_check(fb != null and fb.get_parent() is HBoxContainer, "a tincture's card offers Force beside a full Node")
	if fb != null:
		var s0: float = U.size(prof, "legs")
		fb.pressed.emit()
		await t._frames(2)
		_check(menu.asking() and menu.pop.text_l.text.contains("size"), "it asks first, with the Node's size before and after: %s" % menu.pop.text_l.text)
		await t._confirm(true)
		await t._frames(2)
		_check(main.player.item_count("tincture_air") == 0 and U.size(prof, "legs") > s0 and F.strain(prof, "legs") >= float(F.LADDER["burned"]), "...forced: the tincture is used, the Node stretched and strained (%.1f)" % F.strain(prof, "legs"))
	menu.close()
	await t._frames(2)


func _entity() -> void:
	await _fresh_marked()
	var main = t.main
	var E = load("res://scripts/entity.gd")
	var tip: Dictionary = E.TIPS.get("forcing", {})
	_check(tip.has("tip") and tip.has("more") and String(tip["tip"]).length() < 140, "the Entity explains forcing the first time (a short line and an Archive account)")
	_check(String(tip.get("more", "")).contains("guardians") and String(tip.get("more", "")).contains("Husks"), "...warning that guardians frown on damaged marks, and hinting at the Husks")
	var how: Array = Talk.DIALOGUE["how"]["choices"]
	_check(how.has("how_forcing") and String(Talk.DIALOGUE["how_forcing"]["ask"]) == "Forcing a Node or mark?", "'How does it work?' has 'Forcing a Node or mark?'")
	var line: String = Talk.line_for(main, "how_forcing")
	_check(line.contains(str(int(F.LADDER["burned"]))) and line.contains("Husks") and not line.contains("{"), "its answer has the live numbers: %s" % line)
	# The first time Force it shows, the Entity says so on the page.
	Engine.set_meta("sixfold_tips", true)
	Guide.forget()
	main.profile.add_crystal("air", 20.0)
	await _open_crystal("air")
	var said := String(main.menu.pour_page.said)
	_check(said != "" and said == String(tip.get("tip", "")), "the first time Force it shows, the Entity explains it there")
	Engine.remove_meta("sixfold_tips")
	Guide.forget()
	main.menu.close()
	await t._frames(2)
	# No banned words anywhere in it.
	var text := (str(F.TEXT) + " " + str(tip) + " " + str(Talk.DIALOGUE["how_forcing"]) + " " + String(Help.HELP["pour:force"])).to_lower()
	_check(not BANNED.any(func(w): return text.contains(w)), "no banned words in forcing's words")
