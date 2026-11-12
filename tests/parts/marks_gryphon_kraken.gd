extends RefCounted
## The Gryphon's and the Kraken's marks grown into stronger powers: each
## step-3 Transformation (side A, today's side, and side B) does its new
## thing through real casts; each passive grows to rank II at step 3 and
## rank III at step 5 (and not before); each great spell's Apex works; and
## an old save keeps its step-3 side (A or B) and is offered one free
## re-pick in the book. Run by smoke_test.gd (_part_tests).

const TestRun := preload("res://scripts/test_run.gd")

var t
var TR = load("res://scripts/tree.gd")
var L = load("res://scripts/library.gd")
var B = load("res://scripts/bonds.gd")
var P = load("res://scripts/profile.gd")
var K = load("res://scripts/spells/kraken.gd")
var dir := Vector2.RIGHT


func run(smoke) -> void:
	t = smoke
	_words()
	await _old_saves()
	await _repick_book()
	await _stormcaller()
	await _windwalker()
	await _hunter()
	await _tidecaller()
	await _warden()
	await _deepcaller()


func _main():
	return t.main


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## A fresh climber with one mark on the hand at a step, alone, facing open floor.
func _marked(bond_id: String, step: int) -> void:
	await t._fresh_main()
	t.paused = false
	var main = _main()
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.profile.regarded = true
	main.first_climb = false
	main.profile.bonds = {"hand": {"id": bond_id, "xp": float(P.STEP_XP[step - 1]), "faint": false, "debt": 0.0}}
	main._give_bonds()
	for e in main.enemies():
		e.queue_free()
	await t._frames(2)
	var p = main.player
	p.iframes = 999.0
	dir = Vector2.RIGHT
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		var open := true
		for k in range(1, 16):
			var at: Vector2 = p.global_position + d * 20.0 * k
			if main.is_solid(at) or not main.room.grow(-20.0).has_point(at):
				open = false
		for k in range(1, 6):
			var back: Vector2 = p.global_position - d * 20.0 * k
			if main.is_solid(back) or not main.room.grow(-20.0).has_point(back):
				open = false
		if open:
			dir = d
			break
	p.aim = dir


## A foe that stands still (its own moves off) where the test puts it.
func _foe(at: Vector2, hp := 300.0, moving := false):
	var e = _main().spawn_enemy("slime", at)
	e.set_physics_process(moving)
	e.global_position = at
	e.max_hp = hp
	e.hp = hp
	e.aware = false
	return e


func _choose(bond_id: String, step: int, option: String) -> bool:
	var main = _main()
	var node := "mark:%s:%d" % [bond_id, step]
	var ok: bool = option in TR.available(main.profile, node) and TR.choose(main.profile, node, option)
	main._give_bonds()
	return ok


func _select(spell_id: String) -> bool:
	var b = _main().player.bonds["hand"]
	var i: int = b.spells().map(func(sp): return sp["id"]).find(spell_id)
	if i >= 0:
		b.select(i)
	return i >= 0


## Casts the hand's spell as a climber does; returns the essence it cost.
func _cast() -> float:
	var p = _main().player
	var b = p.bonds["hand"]
	b.essence = b.capacity()
	b.burned = false
	p.attack_cd = 0.0
	p.cast_t = 0.0
	var before: float = b.essence
	p.aim = dir
	p._try_cast("hand")
	await t._wait(b.windup() + 0.12)
	for i in 120:
		if p.cast_t <= 0.0:
			break
		await t._frames(1)
	return before - b.essence


## A number of the first spell's today's step 3 (side A).
func _a(bond_id: String, key: String):
	return B.BONDS[bond_id]["spells"][0]["steps"][3][key]


## A number of side B (FORKS[bond][3]).
func _b(bond_id: String, key: String):
	return TR.fork_alt(bond_id, 3)["steps"][3][key]


func _rank_num(bond_id: String, rank: int, key: String) -> float:
	return B.passive_num(bond_id, rank, key)


## A blow that lands on the climber (no roll's grace, no hurt grace).
func _blow(dmg: float, src) -> void:
	var p = _main().player
	p.iframes = 0.0
	p.hurt_t = 0.0
	p.parry_t = 0.0
	p.receive_attack(dmg, src)
	p.iframes = 999.0


# --- words and data ----------------------------------------------------------------------------

func _words() -> void:
	print("marks (Gryphon, Kraken): words")
	var bonds := ["stormcaller", "windwalker", "hunter", "tidecaller", "warden", "deepcaller"]
	var words := ""
	var ok := true
	for bid in bonds:
		var f: Dictionary = L.MARK_FORKS[bid]
		var alt: Dictionary = TR.fork_alt(bid, 3)
		var first: Dictionary = B.BONDS[bid]["spells"][0]
		var great: Dictionary = B.BONDS[bid]["spells"][3]
		words += " %s %s %s %s %s %s" % [f["change"]["name"], f["change"]["says"], alt["name"], alt["desc"], first["changes"][3], great["desc"]]
		for r in [2, 3]:
			words += " " + B.passive_line(bid, r)
			if B.passive_line(bid, r) == "":
				ok = false
		if String(f["change"]["name"]) == "" or String(alt["name"]) == "" or alt.has("variation"):
			ok = false
	_check(ok, "each of the six marks names both Transformations and two passive ranks, all in data (no library variation left on side B)")
	_check(not ["attunement", "spire", "trial", "judgment", "mana"].any(func(w): return words.to_lower().contains(w)), "no borrowed words")
	_check(TR.fork_alt("stormcaller", 3)["id"] == "lingering" and TR.fork_alt("windwalker", 3)["id"] == "echoing" and TR.fork_alt("hunter", 3)["id"] == "split_shot"
		and TR.fork_alt("tidecaller", 3)["id"] == "swelling" and TR.fork_alt("warden", 3)["id"] == "mirrored" and TR.fork_alt("deepcaller", 3)["id"] == "patient",
		"side B keeps the old choice ids, so old saves map by themselves")
	_check(B.passive_rank(1) == 1 and B.passive_rank(2) == 1 and B.passive_rank(3) == 2 and B.passive_rank(4) == 2 and B.passive_rank(5) == 3, "a passive is rank I, II from step 3, III at step 5")
	var pa: Dictionary = B.passive_at("stormcaller", 3)
	_check(pa["name"] == "Static II" and String(pa["desc"]).contains(B.passive_line("stormcaller", 2)) and pa["ahead"].size() == 1, "its card shows the rank and the new line, and the rank ahead (%s)" % pa["name"])
	_check(B.step_note("warden", 3).contains(B.passive_line("warden", 2)) and B.step_note("warden", 5).contains(B.passive_line("warden", 3)), "the step notes say the passive grows")


# --- old saves and the re-pick -----------------------------------------------------------------

func _old_saves() -> void:
	print("marks (Gryphon, Kraken): old saves")
	await t._fresh_main()
	var path := TestRun.path("user://smoke_marks_gk.cfg")
	var cfg := ConfigFile.new()
	var xp := float(P.STEP_XP[2])
	cfg.set_value("profile", "regarded", true)
	cfg.set_value("profile", "bonds", {
		"hand": {"id": "stormcaller", "xp": xp, "faint": false, "debt": 0.0},
		"legs": {"id": "windwalker", "xp": xp, "faint": false, "debt": 0.0},
		"brow": {"id": "hunter", "xp": xp, "faint": false, "debt": 0.0},
		"throat": {"id": "tidecaller", "xp": xp, "faint": false, "debt": 0.0},
		"heart": {"id": "warden", "xp": xp, "faint": false, "debt": 0.0},
		"back": {"id": "deepcaller", "xp": float(P.STEP_XP[1]), "faint": false, "debt": 0.0},
	})
	# A version-1 tree: three marks took today's side at step 3, two the other.
	cfg.set_value("tree", "state", {"v": 1, "marks": {
		"stormcaller": {2: "overcharge", 3: "change"}, "windwalker": {2: "crosswind", 3: "echoing"}, "hunter": {3: "split_shot"},
		"tidecaller": {3: "change"}, "warden": {3: "change"}}, "unbound": {}, "learned": {}, "echoes": []})
	cfg.save(path)
	var old = P.new()
	old.saving = false
	old.save_path = path
	old.load_save()
	var a_side := ["stormcaller", "tidecaller", "warden"].all(func(b): return TR.mark_choice(old, b, 3) == TR.CHANGE and TR.alt_change(b, TR.mark_choices(old, b)).is_empty())
	_check(a_side, "an old save that chose today's step-3 side now has Transformation A")
	var b_side := ["windwalker", "hunter"].all(func(b): return TR.alt_change(b, TR.mark_choices(old, b)).get("name", "") == TR.fork_alt(b, 3)["name"])
	_check(b_side, "...and one that chose the other side has Transformation B (Tailwind, Rending Shot)")
	var offers: Array = TR.repick_offers(old)
	offers.sort()
	_check(offers == ["hunter", "stormcaller", "tidecaller", "warden", "windwalker"], "each mark with a step-3 choice is offered one free re-pick (%s)" % [offers])
	_check(TR.repick(old, "windwalker", TR.CHANGE) and TR.mark_choice(old, "windwalker", 3) == TR.CHANGE, "a re-pick takes the other side")
	_check(not TR.repick(old, "windwalker", "echoing") and not "windwalker" in TR.repick_offers(old), "...once: the offer is gone")
	TR.repick_keep(old, "hunter")
	_check(TR.mark_choice(old, "hunter", 3) == "split_shot" and not "hunter" in TR.repick_offers(old), "keeping a side ends the offer too")
	_check(not TR.repick(old, "deepcaller", TR.CHANGE), "a mark that hadn't reached step 3 has nothing to re-pick")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# A climber choosing now (a version-2 tree) isn't offered one.
	await _marked("hunter", 3)
	var main = _main()
	_choose("hunter", 3, "split_shot")
	_check(TR.repick_offers(main.profile).is_empty(), "a step-3 choice made now is for good (no re-pick)")


func _repick_book() -> void:
	print("marks (Gryphon, Kraken): the re-pick in the book")
	await _marked("tidecaller", 3)
	var main = _main()
	var st: Dictionary = TR.state(main.profile)
	st["marks"]["tidecaller"] = {3: TR.CHANGE}
	st["repick"]["tidecaller"] = true
	var menu = main.menu
	menu.climber_tab = "marks"
	menu.open("climber", true)
	await t._frames(3)
	var panels: Array = menu.find_children("*", "PanelContainer", true, false).filter(func(c): return c.get_meta("repick", "") == "tidecaller")
	_check(panels.size() == 1, "the book's Marks tab offers the re-pick")
	var take: Array = t._all_buttons(menu).filter(func(b): return b.get_meta("repick_take", "") == "swelling")
	_check(take.size() == 1, "...with a button for the other side (Return Tide)")
	if take.size() == 1:
		take[0].pressed.emit()
		await t._frames(3)
	_check(TR.mark_choice(main.profile, "tidecaller", 3) == "swelling" and main.player.bonds["hand"].alt_change().get("id", "") == "swelling", "taking it changes the mark at once")
	panels = menu.find_children("*", "PanelContainer", true, false).filter(func(c): return c.get_meta("repick", "") == "tidecaller")
	_check(panels.is_empty(), "...and the offer is gone")


# --- the Gryphon ---------------------------------------------------------------------------------

func _stormcaller() -> void:
	print("Stormcaller: Branching Storm")
	await _marked("stormcaller", 3)
	var main = _main()
	var p = main.player
	var side: Vector2 = dir.orthogonal()
	# A V of foes: from the first, the other two are too far from each other for one line.
	var lead = _foe(p.global_position + dir * 120.0)
	var left = _foe(lead.global_position + dir * 70.0 + side * 90.0)
	var right = _foe(lead.global_position + dir * 70.0 - side * 90.0)
	var paid := await _cast()
	var dmg: float = 12.0 * float(_a("stormcaller", "boost"))
	_check(paid == 12.0, "Chain Lightning still costs 12 (%.1f)" % paid)
	_check([lead, left, right].all(func(e): return e.hp < e.max_hp and e.charged > 0.0), "the lightning splits: both branches of a V are struck and charged")
	_check(lead.max_hp - lead.hp >= dmg - 0.01, "...each at %d%% of its damage (%.1f)" % [roundi(float(_a("stormcaller", "boost")) * 100.0), lead.max_hp - lead.hp])
	for e in main.enemies():
		e.queue_free()
	await t._frames(2)
	var many: Array = []
	for i in 10:
		many.append(_foe(p.global_position + dir * (90.0 + 20.0 * (i % 5)) + side * (40.0 * (i / 5) - 20.0)))
	await _cast()
	var struck: int = many.filter(func(e): return e.hp < e.max_hp).size()
	_check(struck == int(_a("stormcaller", "most")), "up to %d foes are struck (%d of 10)" % [int(_a("stormcaller", "most")), struck])
	# Static II at step 3: a charged foe takes more from everything.
	var c = many[0]
	c.charged = 4.0
	var hp0: float = c.hp
	c.take_hit(10.0, Vector2.ZERO, 0.0)
	_check(is_equal_approx(hp0 - c.hp, 10.0 * (1.0 + _rank_num("stormcaller", 2, "more"))), "Static II: a charged foe takes 20%% more (%.1f)" % (hp0 - c.hp))

	print("Stormcaller: Living Bolt")
	await _marked("stormcaller", 3)
	main = _main()
	p = main.player
	_check(_choose("stormcaller", 3, "lingering"), "Living Bolt can be chosen at step 3")
	var foes: Array = []
	for i in 3:
		foes.append(_foe(p.global_position + dir * (100.0 + 60.0 * i)))
	await _cast()
	var after_cast: float = foes.reduce(func(s, e): return s + e.max_hp - e.hp, 0.0)
	await t._wait(1.2)
	var later: float = foes.reduce(func(s, e): return s + e.max_hp - e.hp, 0.0)
	_check(later > after_cast + 5.0, "the chain doesn't end: it keeps leaping between the charged foes (%.0f, then %.0f)" % [after_cast, later])
	await t._wait(float(_b("stormcaller", "live")))
	var done: float = foes.reduce(func(s, e): return s + e.max_hp - e.hp, 0.0)
	await t._wait(0.8)
	_check(is_equal_approx(done, foes.reduce(func(s, e): return s + e.max_hp - e.hp, 0.0)), "...for %d seconds" % int(_b("stormcaller", "live")))

	print("Stormcaller: Static II and III, Thunderhead's Apex")
	await _marked("stormcaller", 2)
	main = _main()
	var plain = _foe(main.player.global_position + dir * 100.0)
	plain.charged = 4.0
	plain.take_hit(10.0, Vector2.ZERO, 0.0)
	_check(is_equal_approx(plain.max_hp - plain.hp, 10.0), "at step 2 Static is rank I: no more damage")
	await _marked("stormcaller", 5)
	main = _main()
	p = main.player
	var b = p.bonds["hand"]
	var doomed = _foe(p.global_position + dir * 100.0, 5.0)
	doomed.charged = 4.0
	doomed.take_hit(50.0, Vector2.ZERO, 0.0)
	await t._frames(1)
	_check(b.refund, "Static III: a charged foe's death refunds the next Chain Lightning")
	var target = _foe(p.global_position + dir * 120.0)
	b.select(0)
	var paid2 := await _cast()
	_check(paid2 == 0.0 and not b.refund, "...which costs nothing, once (%.1f)" % paid2)
	_check(_select("thunderhead"), "Thunderhead is known at step 5")
	await _cast()
	_check(p.thunderhead_t > 0.0 and p.thunderhead_bolt > 0.0, "Thunderhead holds")
	var hp1: float = target.hp
	target.charged = 0.0
	target.stun = 0.0
	p._strike(target, 5.0, dir, 0.0, false)
	_check(hp1 - target.hp > 5.0 * 1.2 + 1.0 and target.charged > 0.0, "Apex: a strike you land calls a bolt from above, which charges the foe (%.1f)" % (hp1 - target.hp))


func _windwalker() -> void:
	print("Windwalker: Skyward")
	await _marked("windwalker", 3)
	var main = _main()
	var p = main.player
	var e = _foe(p.global_position + dir * 90.0, 300.0, true)
	var near = _foe(p.global_position - dir * 100.0)
	var paid := await _cast()
	var lift: float = 1.7 * float(_a("windwalker", "high"))
	_check(paid == 10.0 and e.airborne > lift - 0.5, "foes fly twice as high: aloft for %.1f s (%.1f)" % [lift, e.airborne])
	for i in 120:
		if e.airborne < 0.25:
			break
		await t._wait(0.05)
	near.global_position = e.global_position + dir.orthogonal() * 40.0
	await t._wait(0.5)
	_check(e.airborne <= 0.0 and e.hp < e.max_hp, "...and slam down (%.0f)" % (e.max_hp - e.hp))
	_check(near.hp < near.max_hp, "...hurting a foe where it lands (%.0f)" % (near.max_hp - near.hp))
	# Featherweight II (step 3): your strikes keep airborne foes aloft.
	var up = _foe(p.global_position + dir * 60.0)
	up.airborne = 0.5
	p._strike(up, 1.0, dir, 0.0, false)
	_check(up.airborne > 0.5 + _rank_num("windwalker", 2, "juggle") - 0.05, "Featherweight II: a strike keeps an airborne foe aloft (%.2f s)" % up.airborne)

	print("Windwalker: Tailwind")
	await _marked("windwalker", 3)
	main = _main()
	p = main.player
	_check(_choose("windwalker", 3, "echoing"), "Tailwind can be chosen at step 3")
	var far = _foe(p.global_position + dir * 175.0 + dir.orthogonal() * 20.0)
	var from: Vector2 = p.global_position
	await _cast()
	await t._wait(0.4)
	var rode: float = (p.global_position - from).dot(dir)
	_check(rode > float(_b("windwalker", "ride")) * 0.6, "you ride the gust forward (%.0f px)" % rode)
	_check(far.airborne > 0.5 and far.hp < far.max_hp, "...launching a foe you pass, beyond the gust's reach")

	print("Windwalker: Featherweight ranks, Eye of the Storm's Apex")
	await _marked("windwalker", 2)
	main = _main()
	p = main.player
	var low = _foe(p.global_position + dir * 60.0)
	low.airborne = 0.5
	p._strike(low, 1.0, dir, 0.0, false)
	_check(low.airborne <= 0.5, "at step 2 a strike doesn't keep a foe aloft")
	await _marked("windwalker", 5)
	main = _main()
	p = main.player
	var light = _foe(p.global_position - dir * 30.0)
	p.roll_cd = 0.0
	p.attack_cd = 0.0
	p.sta = p.max_sta
	p._try_roll(dir)
	_check(light.airborne > 0.5, "Featherweight III: a roll leaves a gust that lifts a light foe")
	_check(_select("eye_of_the_storm"), "Eye of the Storm is known at step 5")
	await _cast()
	_check(main.cyclones.size() == 1, "the cyclone stands")
	var at0: Vector2 = main.cyclones[0]["pos"]
	p.aim = dir.orthogonal()
	await t._wait(0.5)
	var moved: float = (main.cyclones[0]["pos"] - at0).dot(dir.orthogonal())
	_check(moved > 30.0, "Apex: you steer the cyclone with your aim (%.0f px)" % moved)
	p.aim = dir


func _hunter() -> void:
	print("Hunter: Seeking Shot")
	await _marked("hunter", 3)
	var main = _main()
	var p = main.player
	var q = _foe(p.global_position + dir * 220.0 + dir.orthogonal() * 70.0)
	p.quarry = q
	var paid := await _cast()
	await t._wait(0.6)
	var one: float = 14.0 * float(_a("hunter", "boost"))
	_check(paid == 9.0, "Piercing Shot still costs 9 (%.1f)" % paid)
	_check(q.max_hp - q.hp >= one * 2.0 - 0.1, "the arrow curves to your Quarry, off your aim, and strikes it twice (%.1f; one strike %.1f)" % [q.max_hp - q.hp, one])
	# Quarry II (step 3): your Quarry takes more from you.
	var hp0: float = q.hp
	p.quarry = q
	q.take_hit(10.0, Vector2.ZERO, 0.0)
	_check(is_equal_approx(hp0 - q.hp, 10.0 * (1.0 + _rank_num("hunter", 2, "more"))), "Quarry II: your Quarry takes 25%% more (%.1f)" % (hp0 - q.hp))

	print("Hunter: Rending Shot")
	await _marked("hunter", 3)
	main = _main()
	p = main.player
	_check(_choose("hunter", 3, "split_shot"), "Rending Shot can be chosen at step 3")
	var line: Array = []
	for i in 3:
		line.append(_foe(p.global_position + dir * (90.0 + 50.0 * i)))
	await _cast()
	await t._wait(0.4)
	_check(line.all(func(e): return e.hp < e.max_hp and load("res://scripts/reactions.gd").has(e, "bleeding")), "every foe along its line is struck and bleeds")

	print("Hunter: Quarry III, Rain of Arrows' Apex")
	await _marked("hunter", 5)
	main = _main()
	p = main.player
	var b = p.bonds["hand"]
	var prey = _foe(p.global_position + dir * 100.0, 5.0)
	var next = _foe(p.global_position + dir * 160.0)
	b.essence = 0.0
	p.quarry = prey
	prey.take_hit(50.0, Vector2.ZERO, 0.0)
	await t._frames(1)
	_check(p.quarry == next and is_equal_approx(b.essence, b.spell_cost(b.data()["spells"][0])), "Quarry III: felling your Quarry marks the nearest foe and refills a shot")
	_check(_select("rain_of_arrows"), "Rain of Arrows is known at step 5")
	next.global_position = p.global_position + dir * 200.0 + dir.orthogonal() * 120.0
	await _cast()
	_check(main.rains.size() == 1, "the rain falls")
	var r0: Vector2 = main.rains[0]["pos"]
	await t._wait(0.6)
	_check(main.rains[0]["pos"].distance_to(next.global_position) < r0.distance_to(next.global_position) - 40.0, "Apex: the rain follows your Quarry")


# --- the Kraken -----------------------------------------------------------------------------------

func _tidecaller() -> void:
	print("Tidecaller: Breaking Wave")
	await _marked("tidecaller", 3)
	var main = _main()
	var p = main.player
	var e = _foe(p.global_position + dir * 100.0)
	var waves: int = main.waves.size()
	var paid := await _cast()
	_check(paid == 12.0 and main.waves.size() == waves + 1, "Tidal Surge still costs 12 and rolls out a wave")
	var first: float = e.max_hp - e.hp
	await t._wait(float(_a("tidecaller", "again")) + 0.3)
	_check(e.max_hp - e.hp > first + 1.0, "...then a second wave hits where the foe landed (%.0f, then %.0f)" % [first, e.max_hp - e.hp])
	# Undercurrent II (step 3): foes knocked into each other are stunned too.
	var a = _foe(p.global_position + dir * 200.0)
	var bb = _foe(a.global_position + dir * 26.0)
	a.tide_push(dir * 200.0)
	a._undercurrent()
	_check(a.stun > 0.3 and bb.stun > 0.3, "Undercurrent II: a shoved foe knocked into another stuns both")

	print("Tidecaller: Return Tide")
	await _marked("tidecaller", 3)
	main = _main()
	p = main.player
	_check(_choose("tidecaller", 3, "swelling"), "Return Tide can be chosen at step 3")
	var side: Vector2 = dir.orthogonal()
	var ring: Array = [_foe(p.global_position + side * 90.0), _foe(p.global_position - side * 90.0), _foe(p.global_position + dir * 100.0)]
	await _cast()
	var hurt0: Array = ring.map(func(f): return f.max_hp - f.hp)
	await t._wait(float(_b("tidecaller", "back")) + 0.15)
	var center: Vector2 = p.global_position + dir * float(_b("tidecaller", "cluster"))
	var drawn := true
	for i in ring.size():
		var f = ring[i]
		if f.max_hp - f.hp <= hurt0[i] + 1.0 or f.stun <= 0.0 or f.knock.dot(center - f.global_position) <= 0.0:
			drawn = false
	_check(drawn and hurt0.all(func(h): return h > 0.0), "foes are hurled out, then dragged back toward one spot, struck and held")

	print("Tidecaller: Undercurrent III, Maelstrom's Apex")
	await _marked("tidecaller", 5)
	main = _main()
	p = main.player
	var s = _foe(p.global_position + dir * 100.0)
	s.tide_push(dir * 100.0)
	_check(load("res://scripts/reactions.gd").has(s, "soaked"), "Undercurrent III: your knockbacks leave foes soaked")
	_check(_select("maelstrom"), "Maelstrom is known at step 5")
	var w = _foe(p.global_position + dir * 160.0)
	await _cast()
	await t._frames(3)
	_check(is_equal_approx(K.drenched(w), float(B.BONDS["tidecaller"]["spells"][3]["steps"][5]["drench"])), "Apex: a foe the whirlpool drags is drenched")
	var hp0: float = w.hp
	main.hit_kind = "lightning"
	w.take_hit(10.0, Vector2.ZERO, 0.0)
	main.hit_kind = ""
	var hp1: float = w.hp
	w.take_hit(10.0, Vector2.ZERO, 0.0)
	_check(is_equal_approx(hp0 - hp1, 20.0) and is_equal_approx(hp1 - w.hp, 10.0), "...it takes double from lightning (%.0f), not from the rest (%.0f)" % [hp0 - hp1, hp1 - w.hp])


func _warden() -> void:
	print("Warden: Bastion")
	await _marked("warden", 3)
	var main = _main()
	var p = main.player
	var src = _foe(p.global_position + dir * 40.0)
	var paid := await _cast()
	_check(paid == 12.0 and is_equal_approx(p.barrier_hp, 30.0) and p.barrier_burst, "Barrier still costs 12 and rises (30), bursting when it breaks")
	_blow(10.0, src)
	_check(is_equal_approx(p.barrier_hp, 30.0 - 10.0 + 10.0 * float(_a("warden", "grow"))), "it grows back from every blow it blocks (%.1f)" % p.barrier_hp)
	for i in 8:
		_blow(10.0, src)
	_check(p.barrier_hp <= 0.0 and src.hp < src.max_hp, "...and bursts outward when it breaks (%.0f)" % (src.max_hp - src.hp))
	# Steadfast II (step 3): a parry while shielded restores the barrier.
	await _cast()
	p.barrier_hp = 5.0
	p._on_parry(src, false)
	_check(p.barrier_hp > 5.0 + 1.0, "Steadfast II: a parry while shielded restores the barrier (%.1f)" % p.barrier_hp)

	print("Warden: Moving Wall")
	await _marked("warden", 3)
	main = _main()
	p = main.player
	_check(_choose("warden", 3, "mirrored"), "Moving Wall can be chosen at step 3")
	var front = _foe(p.global_position + dir * 45.0)
	var back = _foe(p.global_position - dir * 45.0)
	await _cast()
	_check(p.barrier_hp > 0.0 and not p.barrier_burst and p.barrier_front < 1.0, "the barrier rises as a wall where you aim")
	var hp0: float = p.barrier_hp
	_blow(10.0, front)
	_check(is_equal_approx(hp0 - p.barrier_hp, 10.0 * float(_b("warden", "front"))), "a blow from the wall's side wears it half as fast (%.1f)" % (hp0 - p.barrier_hp))
	hp0 = p.barrier_hp
	_blow(10.0, back)
	_check(is_equal_approx(hp0 - p.barrier_hp, 10.0), "...one from behind wears it as usual")
	p.aim = -dir
	var shot = main.spawn_projectile(p.global_position - dir * 200.0, dir * 300.0, 8.0)
	await t._wait(0.6)
	_check(is_instance_valid(shot) and shot.friendly and shot.reflected and shot.vel.dot(-dir) > 0.0, "the wall turns with your aim and turns shots back")
	p.aim = dir

	print("Warden: Steadfast III, Unbreakable's Apex")
	await _marked("warden", 5)
	main = _main()
	p = main.player
	var b = p.bonds["hand"]
	src = _foe(p.global_position + dir * 40.0)
	await _cast()
	b.essence = 0.0
	for i in 12:
		_blow(10.0, src)
		if p.barrier_hp <= 0.0:
			break
	_check(p.barrier_hp <= 0.0 and is_equal_approx(b.essence, 12.0 * _rank_num("warden", 3, "refund")), "Steadfast III: a broken barrier refunds half its cost (%.1f)" % b.essence)
	_check(_select("unbreakable"), "Unbreakable is known at step 5")
	await _cast()
	p.attack_cd = 0.0
	_check(p.unbreak_t > 0.0 and p.unbreak_strike > 0.0, "Unbreakable holds")
	var foe = _foe(p.global_position + dir * 50.0)
	var hp1: float = foe.hp
	p._strike(foe, 10.0, Vector2.ZERO, 0.0, false)
	_check(is_equal_approx(hp1 - foe.hp, 10.0 * float(B.BONDS["warden"]["spells"][3]["steps"][5]["strike"])), "Apex: you may strike, at half damage (%.1f)" % (hp1 - foe.hp))
	var hp_me: float = p.hp
	_blow(25.0, src)
	_check(p.hp == hp_me and p.unbreak_stored >= 25.0, "...you still take no damage, and it is kept")
	hp1 = foe.hp
	await t._wait(p.unbreak_t + 0.3)
	_check(hp1 - foe.hp >= 25.0, "...and what it absorbed bursts out at the end (%.0f)" % (hp1 - foe.hp))


func _deepcaller() -> void:
	print("Deepcaller: Abyssal Draw")
	await _marked("deepcaller", 3)
	var main = _main()
	var p = main.player
	var foes: Array = []
	for i in 5:
		foes.append(_foe(p.global_position + dir * (90.0 + 25.0 * i) + dir.orthogonal() * (30.0 * (i % 2) - 15.0)))
	var paid := await _cast()
	_check(paid == 12.0 and foes.all(func(e): return e.hp < e.max_hp), "Undertow still costs 12 and drains 5 foes")
	_check(foes.all(func(e): return e.knock.dot(p.global_position - e.global_position) > 0.0 and e.stun > 0.0), "...pulling each toward you")

	print("Deepcaller: Cold Current")
	await _marked("deepcaller", 3)
	main = _main()
	p = main.player
	_check(_choose("deepcaller", 3, "patient"), "Cold Current can be chosen at step 3")
	foes = []
	for i in 3:
		foes.append(_foe(p.global_position + dir * (90.0 + 30.0 * i)))
	p.hp = p.max_health()
	await _cast()
	var R = load("res://scripts/reactions.gd")
	_check(foes.all(func(e): return e.hp < e.max_hp and R.has(e, "slowed")), "drained foes are slowed")
	_check(p.barrier_hp > 1.0, "...and the life you drink becomes a shield, even at full health (%.1f)" % p.barrier_hp)

	print("Deepcaller: Pressure II and III, Drink Deep's Apex")
	await _marked("deepcaller", 3)
	main = _main()
	p = main.player
	var hurt = _foe(p.global_position + dir * 40.0)
	hurt.hp = hurt.max_hp * 0.3
	var whole = _foe(p.global_position - dir * 40.0)
	p.hp = p.max_health()
	var hp0: float = p.hp
	_blow(20.0, whole)
	var full_hit: float = hp0 - p.hp
	hp0 = p.hp
	p.hurt_t = 0.0
	_blow(20.0, hurt)
	_check(full_hit > 0.0 and is_equal_approx(hp0 - p.hp, full_hit * (1.0 - _rank_num("deepcaller", 2, "softer"))), "Pressure II: a badly hurt foe near you hits softer (%.1f against %.1f)" % [hp0 - p.hp, full_hit])
	await _marked("deepcaller", 5)
	main = _main()
	p = main.player
	var dying = _foe(p.global_position + dir * 60.0, 3.0)
	p.hp = 20.0
	dying.take_hit(10.0, Vector2.ZERO, 0.0)
	await t._frames(1)
	_check(is_equal_approx(p.hp, 20.0 + _rank_num("deepcaller", 3, "heal") * p.heal_mult()), "Pressure III: a kill near you heals you (%.1f)" % p.hp)
	_check(_select("drink_deep"), "Drink Deep is known at step 5")
	var weak = _foe(p.global_position + dir * 100.0, 10.0)
	var other = _foe(p.global_position + dir * 160.0)
	await _cast()
	_check(p.drink_target == weak, "the drain holds the foe you aim at")
	await t._wait(1.0)
	_check(not is_instance_valid(weak) or weak.dead, "...which dies")
	_check(p.drink_target == other and p.drink_t > 0.0, "Apex: the drain jumps to a new foe without breaking")
	var hp2: float = other.hp
	await t._wait(0.5)
	_check(other.hp < hp2, "...and drinks from it")
