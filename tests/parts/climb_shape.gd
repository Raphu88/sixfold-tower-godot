extends RefCounted
## The climb's shape (climb_shape.gd): the first climb is a normal climb
## (camps, no three-floor end) whose floor 6 opens with the Regard (a full
## mark) and then the Proving, with the guardian's exit (leave with the mark,
## or climb on); a death before it scaled by the floor reached (50% on floor
## 1, 10% more a floor, full on floor 6), through the faint mark's strength
## and debt; falls below floor 6 and no second Proving unless the Lethal one
## is chosen; the stair's barrier (a gate on floors 1 to 6 rolled under in
## its first 30 seconds or broken by weapons, fists and spells; a ward on
## floors 7 to 12 up in 15 and broken only by its tower's own essence), its
## horde (6 or 12, the stair waiting for it), the unmarked made Unbound on
## the spot, a Maker after a marked climber's third slip (counted across
## climbs); three camps of three cards; the ending once all six guardians
## are beaten, then the same climber plays on; guardian glimpses still
## working; the Entity's moments, its "How does it work?" topics and no
## banned words. Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const CS := preload("res://scripts/climb_shape.gd")
const Items := preload("res://scripts/items.gd")
const Towers := preload("res://scripts/towers.gd")
const Unbound := preload("res://scripts/unbound.gd")
const Entity := preload("res://scripts/entity.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const ProfileScript := preload("res://scripts/profile.gd")

const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

var t


func run(smoke) -> void:
	t = smoke
	print("the climb's shape: the first climb, the Regard on floor 6, death marks, barriers, hordes, camps and the ending")
	_scale()
	await _first_climb_camps()
	await _regard_on_six(true)
	await _regard_on_six(false)
	await _death_marks()
	await _lethal_again()
	await _gate()
	await _barrier_on_stair()
	await _ward()
	await _maker_after_three()
	await _ending()
	await _glimpses()
	_words()
	t.main.climb_shape.barriers_on = false


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _fresh() -> void:
	await t._fresh_main()
	t.paused = false
	t.main.touch._set_active(false)
	t.main.pad._set_active(false)


## Slays every monster on the floor (the horde too).
func _clear_foes() -> void:
	for e in t.main.enemies():
		t._slay(e)
	await t._frames(3)


# --- the death mark's scale ---------------------------------------------------------------

func _scale() -> void:
	var ok := true
	for n in range(1, 7):
		ok = ok and is_equal_approx(CS.death_strength(n), 0.5 + 0.1 * float(n - 1))
	_check(ok and is_equal_approx(CS.death_strength(1), 0.5) and is_equal_approx(CS.death_strength(6), 1.0) and is_equal_approx(CS.death_strength(9), 1.0),
		"a death mark: 50% on floor 1, 10% more a floor, full on floor 6 (and no more above)")
	_check(CS.regard_floor() == 6 and ProfileScript.FIRST_CLIMB_FLOORS == 6 and CS.regard_floor() == int(Towers.PROVING["floor"]), "the first Regard opens floor 6, the Proving's floor")
	var prof = ProfileScript.new()
	prof.saving = false
	prof.add_bond("hand", "stormcaller", true, 0.5)
	prof.add_bond("legs", "windwalker", true)
	prof.add_bond("brow", "hunter", false, 1.0)
	_check(is_equal_approx(float(prof.bonds["hand"]["power"]), 0.5) and float(prof.bonds["hand"]["debt"]) > float(prof.bonds["legs"]["debt"]),
		"a weaker faint mark owes more essence (%d at half strength, %d at three quarters)" % [int(prof.bonds["hand"]["debt"]), int(prof.bonds["legs"]["debt"])])
	_check(is_equal_approx(float(prof.bonds["legs"]["debt"]), ProfileScript.FAINT_DEBT) and not prof.bonds["brow"]["faint"] and float(prof.bonds["brow"]["debt"]) == 0.0,
		"the usual faint mark still owes %d; a full one nothing" % int(ProfileScript.FAINT_DEBT))
	_check(Items.CAMP_AFTER == [3, 6, 9] and Items.CAMP_CARDS == 3, "three camps a climb (after floors 3, 6 and 9), three cards each")
	_check(int(CS.BARRIER["gate"]["from"]) == 1 and int(CS.BARRIER["gate"]["to"]) == 6 and is_equal_approx(float(CS.BARRIER["gate"]["window"]), 30.0) and int(CS.BARRIER["gate"]["horde"]) == 6,
		"floors 1 to 6: a gate, rolled under in its first 30 seconds; a horde of 6")
	_check(int(CS.BARRIER["ward"]["from"]) == 7 and int(CS.BARRIER["ward"]["to"]) == 12 and is_equal_approx(float(CS.BARRIER["ward"]["window"]), 15.0) and int(CS.BARRIER["ward"]["horde"]) == 12,
		"floors 7 to 12: a ward, up in 15 seconds; a horde of 12")
	_check(CS.kind_for(1) == "gate" and CS.kind_for(6) == "gate" and CS.kind_for(7) == "ward" and CS.kind_for(12) == "ward", "each floor's barrier by its range")
	_check(int(CS.SLIPS["maker_every"]) == 3, "a Maker after three slips")


# --- the first climb is a normal climb -------------------------------------------------------

func _first_climb_camps() -> void:
	await _fresh()
	var main = t.main
	_check(main.first_climb and main.profile.bonds.is_empty(), "(a first climb, no mark)")
	_check(main._floor_title() == "FLOOR 1", "the first climb's floors are plain floors (no 'of 3')")
	main.floor_num = 3
	_check(main._camp_due(), "the first climb has camps too")
	main.run_essence = {}
	main._arrive()
	await t._frames(2)
	_check(main.regard.is_empty() and main.in_camp and main.camp_choosing, "floor 3's stair leads to a camp, not the Regard: no three-floor first climb")
	_check(main.camp["choices"].size() == Items.CAMP_CARDS, "a camp offers three cards (%d)" % main.camp["choices"].size())
	var kinds := {"item": 0, "crystal": 0, "gear": 0}
	for c in main.camp["choices"]:
		var s := String(c)
		kinds["gear" if s.begins_with("gear:") else ("crystal" if s.begins_with("crystal:") else "item")] += 1
	_check(kinds["item"] == 1 and kinds["crystal"] == 1 and kinds["gear"] == 1, "an item, a crystal of the tower's essence and a piece of gear")
	main.choose_camp(0)
	main.player.global_position = main.stair_pos
	await t._wait(1.0)
	_check(main.floor_num == 4 and main.first_climb and main.regard.is_empty(), "the climb goes on past floor 3, still unmarked")
	main.in_camp = false
	main.floor_num = 6
	main.camps_done.clear()
	_check(main._camp_due(), "a camp after floor 6 too")
	main.floor_num = 9
	_check(main._camp_due(), "...and after floor 9")


# --- the Regard on floor 6, the exit ----------------------------------------------------------

func _regard_on_six(leave: bool) -> void:
	await _fresh()
	var main = t.main
	var p = main.player
	main.proving.enabled = true
	for i in 5:
		main.add_soak("legs", 3.0)
	main.gather_essence("air", 30.0, p.global_position)
	p.items["tonic"] = 1
	var climbs0: int = main.profile.climbs
	main.floor_num = 5
	main.run_essence = {}
	main._arrive()
	await t._frames(3)
	_check(main.floor_num == 6 and not main.regard.is_empty() and not main.regard["fell"] and main.regard.get("exit", false), "reaching floor 6 on the first climb opens with the Regard")
	_check(main.proving.on, "the Proving is laid on the same floor, behind it")
	var legs: Dictionary = main.profile.bonds.get("legs", {})
	_check(legs.get("id", "") == "windwalker" and not legs.get("faint", true) and float(legs.get("power", 0.0)) == 1.0, "the most-used part takes its first mark at full strength")
	_check(main.profile.climbs == climbs0 and not main.belt_broken, "the climb isn't over yet: nothing paid or counted")
	main.regard["t"] = 9.0
	main.end_regard()
	_check(main.camp_choosing and main.camp.get("stage", "") == "unbind", "first, as before: accept the mark or refuse it")
	main.choose_camp(0)
	_check(main.camp_choosing and main.camp.get("stage", "") == "exit" and main.camp["choices"] == ["exit:leave", "exit:climb"], "then the guardian offers the exit: leave with the mark, or climb on")
	var leave_card: Dictionary = main.camp_card(0)
	var climb_card: Dictionary = main.camp_card(1)
	_check(String(leave_card["desc"]).contains("Windwalker") and String(climb_card["desc"]).contains("Proving"), "each card says what it means")
	if leave:
		main.choose_camp(0)
		_check(main.profile.climbs == climbs0 + 1 and main.belt_broken, "leaving: the climb ends survived (counted, the belt into crystals)")
		_check(main.regard.is_empty() or main.camp.get("stage", "") == "heirloom" or not main.camp_choosing, "...and on to the heirloom and the train")
		main.camp_choosing = false
		main.camp = {}
		main.regard = {}
		return
	main.choose_camp(1)
	_check(main.regard.is_empty() and not main.camp_choosing and not main.first_climb and main.profile.regarded, "climbing on: the Regard closes, the climb goes on as a marked one")
	_check(main.proving.on and p.is_physics_processing(), "...into the Proving, on the same floor")
	_check(p.bonds.has("legs"), "...the new mark on its button")
	_check(main.proving.due(6) and not main.belt_broken, "(the Proving still waits, nothing taken home yet)")
	main.proving.enabled = false


# --- a death before the Regard ---------------------------------------------------------------

func _death_marks() -> void:
	for n in [1, 4]:
		await _fresh()
		var main = t.main
		var p = main.player
		for i in 6:
			main.add_soak("brow", 5.0)
		main.gather_essence("water", 12.0, p.global_position)
		if n > 1:
			main._start_floor(n)
			await t._frames(2)
		p.hurt_t = 0.0
		p.iframes = 0.0
		p.parry_t = 0.0
		p.receive_attack(9999.0, null)
		await t._wait(1.9)
		var brow: Dictionary = main.profile.bonds.get("brow", {})
		var want := 0.5 + 0.1 * float(n - 1)
		_check(not main.regard.is_empty() and main.regard["fell"] and brow.get("faint", false) and is_equal_approx(float(brow.get("power", 0.0)), want),
			"a fall on floor %d: still regarded, a faint mark at %d%% strength" % [n, int(round(want * 100.0))])
		main._give_bonds()
		_check(main.player.bonds.has("brow") and is_equal_approx(main.player.bonds["brow"].faint_power, want), "...and its spells hit at that strength")
		_check(not main.regard.get("exit", true), "...and no exit to offer: the climb is over")
		main.regard = {}
	# Fallen from a higher floor after a way down: the highest floor reached counts.
	await _fresh()
	var m2 = t.main
	m2._start_floor(5)
	m2._start_floor(3)
	await t._frames(2)
	_check(m2.climb_shape.reached() == 5, "a way down doesn't lower the death mark: the highest floor reached counts")


# --- falls below 6, and the Lethal Proving ---------------------------------------------------

func _lethal_again() -> void:
	await _fresh()
	var main = t.main
	main.grant_test_bonds()
	var pv = main.proving
	pv.enabled = true
	_check(pv.due(6), "the Proving waits on floor 6")
	pv.won_climb = true
	main.profile.provings[main.tower] = 1
	_check(not pv.due(6), "won on this climb: a fall below floor 6 doesn't face it again")
	main.floor_num = 5
	main.run_essence = {}
	main._arrive()
	await t._frames(2)
	_check(main.floor_num == 6 and not pv.on and main.camp_choosing and main.camp.get("stage", "") == "lethal_again", "back on floor 6: an ordinary floor, and the Lethal Proving offered")
	main.choose_camp(1)
	await t._frames(2)
	_check(pv.on and pv.lethal_only, "choosing it: the Proving's floor again, the Lethal one only")
	var shut := false
	for d in main.door_view.list:
		if String(d.get("lock", "")) == "proving_shut":
			shut = true
	_check(shut, "...its ordinary door shut")
	pv.lethal_only = false
	pv.enabled = false


# --- the gate --------------------------------------------------------------------------------

func _gate() -> void:
	await _fresh()
	var main = t.main
	var cs = main.climb_shape
	var p = main.player
	cs.barriers_on = true
	main.profile.record.erase("slip_warned")
	main._start_floor(2)
	await t._frames(2)
	_check(cs.bar.get("kind", "") == "gate" and cs.bar["state"] == "forming", "arriving on floor 2: the stair's gate is forming")
	_check(cs.arrival_line().contains("30"), "the floor's banner says so: %s" % cs.arrival_line())
	p.iframes = 9999.0
	await t._ticks(30)
	_check(float(cs.bar["t"]) > 0.2, "its timer runs (%.1f s)" % float(cs.bar["t"]))
	# Walking into it: it holds you back.
	p.global_position = main.stair_pos
	await t._ticks(2)
	_check(p.global_position.y > Rect2(cs.bar["rect"]).end.y, "walking into the gate: it holds you back")
	# A roll into it, the very first time: a warning.
	p.global_position = main.stair_pos + Vector2(0, 10)
	p.roll_t = 0.3
	_check(not cs.try_slip() and cs.bar["state"] == "forming" and main.profile.count("slip_warned") == 1, "the first roll ever into a closing gate only throws you back: the warning")
	p.roll_t = 0.3
	p.global_position = main.stair_pos + Vector2(0, 10)
	var unmarked: bool = main.profile.bonds.is_empty()
	_check(unmarked and cs.try_slip() and cs.bar["state"] == "slipped", "the next roll slips you past")
	_check(Unbound.is_on(main.profile) and main.profile.regarded and not main.first_climb, "with no mark, slipping past makes you Unbound on the spot")
	_check(main.regard.get("refused", false) and main.regard.get("mid", false), "...the guardian's refusal shows")
	_check(not cs.lets_climb(), "the stair waits")
	main.regard["t"] = 9.0
	main.end_regard()
	await t._frames(2)
	_check(main.regard.is_empty() and cs.horde.size() == 6 and cs.horde_live() and p.is_physics_processing(), "dismissed, the climb goes on and the horde comes: 6 for a gate")
	_check(not cs.lets_climb() and not main.camp_choosing, "the stair waits for the horde")
	main.stair_open = true
	main.room_view.stair_open = true
	p.global_position = main.stair_pos
	await t._ticks(3)
	_check(main.floor_num == 2 and not main.climbing, "even open, the stair won't take you while the horde stands")
	await _clear_foes()
	await t._ticks(3)
	_check(not cs.horde_live() and main.stair_open and cs.bar["state"] == "open", "the horde down, the stair opens")
	await t._wait(1.0)
	_check(main.floor_num == 3, "...and takes you on")
	await t._until(func(): return not main.climbing, 3.0)
	# The gate shut: broken with blows, a horde again.
	cs.barriers_on = true
	main._start_floor(4)
	await t._frames(2)
	cs.bar["t"] = 31.0
	await t._ticks(2)
	_check(cs.bar["state"] == "up", "after 30 seconds the gate is shut")
	p.global_position = main.stair_pos + Vector2(0, 50)
	p.roll_t = 0.3
	_check(not cs.try_slip(), "a shut gate can't be rolled under")
	p.roll_t = 0.0
	var from: Vector2 = main.stair_pos + Vector2(0, 46)
	cs.strike(from, Vector2.UP, 30.0, 60.0, false, 1)
	_check(float(cs.bar["dmg"]) == 0.0, "a swing that struck a foe doesn't count against the gate")
	cs.strike(from, Vector2.DOWN, 30.0, 60.0, false, 0)
	_check(float(cs.bar["dmg"]) == 0.0, "nor one aimed away from it")
	cs.strike(from, Vector2.UP, 30.0, 60.0, false, 0)
	_check(float(cs.bar["dmg"]) == float(CS.STRIKE["blow"]), "a blow at it cracks it (weapons and bare fists alike)")
	cs.offer("fire", from, Vector2.UP, "bond")
	_check(float(cs.bar["dmg"]) == float(CS.STRIKE["blow"]) + float(CS.STRIKE["spell"]), "a spell at a gate cracks it too, whatever its essence")
	for i in 20:
		if cs.bar["state"] != "up":
			break
		cs.strike(from, Vector2.UP, 30.0, 60.0, true, 0)
	_check(cs.bar["state"] == "broken" and cs.horde.size() == 6, "enough blows break it: a horde of 6 (an Unbound climber isn't refused twice)")
	await _clear_foes()
	await t._ticks(3)
	_check(main.stair_open, "...and the stair opens once it's down")
	cs.barriers_on = false


# --- the ward --------------------------------------------------------------------------------

func _ward() -> void:
	await _fresh()
	var main = t.main
	var cs = main.climb_shape
	main.grant_test_bonds()
	cs.barriers_on = true
	main._start_floor(8)
	await t._frames(2)
	_check(cs.bar.get("kind", "") == "ward" and is_equal_approx(float(cs.bar["window"]), 15.0), "floor 8: a ward forms over the stair, up in 15 seconds")
	cs.bar["t"] = 16.0
	await t._ticks(2)
	_check(cs.bar["state"] == "up", "...and is up")
	var own := String(main.tower_data()["essence"])
	var other := "fire" if own != "fire" else "water"
	var from: Vector2 = main.stair_pos + Vector2(0, 46)
	cs.strike(from, Vector2.UP, 30.0, 60.0, true, 0)
	cs.offer(other, from, Vector2.UP, "bond")
	_check(float(cs.bar["dmg"]) == 0.0, "a plain weapon and a spell of another essence don't touch it")
	cs.offer(own, from, Vector2.UP, "bond")
	_check(float(cs.bar["dmg"]) == float(CS.STRIKE["ward_spell"]), "a spell of the tower's own essence does")
	_check(float(CS.BARRIER["ward"]["hp"]) / float(CS.STRIKE["ward_spell"]) >= 4.0, "and it takes several (not easy)")
	cs.offer(own, from, Vector2.UP, "item")
	_check(float(cs.bar["dmg"]) == float(CS.STRIKE["ward_spell"]) + float(CS.STRIKE["ward_item"]), "an item of its essence too")
	var marked_slips: int = main.profile.count("slips")
	for i in 10:
		if cs.bar["state"] != "up":
			break
		cs.offer(own, from, Vector2.UP, "bond")
	_check(cs.bar["state"] == "broken" and cs.horde.size() == 12, "broken: a horde of 12")
	_check(not Unbound.is_on(main.profile) and main.profile.count("slips") == marked_slips + 1, "a marked climber stays marked; the slip is counted")
	await _clear_foes()
	await t._ticks(3)
	_check(main.stair_open, "the horde down, the stair opens")
	cs.barriers_on = false


# --- a Maker after three slips ---------------------------------------------------------------

func _maker_after_three() -> void:
	await _fresh()
	var main = t.main
	var cs = main.climb_shape
	var p = main.player
	main.grant_test_bonds()
	cs.barriers_on = true
	main.profile.record["slip_warned"] = 1
	main.profile.record["slips"] = 1
	main._start_floor(2)
	await t._frames(2)
	p.iframes = 9999.0
	p.global_position = main.stair_pos + Vector2(0, 10)
	p.roll_t = 0.3
	cs.try_slip()
	_check(cs.bar["state"] == "slipped" and not cs.maker_due and main.profile.count("slips") == 2, "a second slip: a horde, no Maker yet")
	await _clear_foes()
	await t._ticks(3)
	_check(main.makers.view == null, "(no Maker)")
	main._start_floor(3)
	await t._frames(2)
	p.global_position = main.stair_pos + Vector2(0, 10)
	p.roll_t = 0.3
	cs.try_slip()
	_check(cs.maker_due and main.profile.count("slips") == 3, "the third slip, counted across climbs: a Maker is coming")
	_check(main.makers.view == null, "...once the horde has fallen")
	main.run_essence = {"air": 40.0}
	await _clear_foes()
	await t._ticks(3)
	var v = main.makers.view
	_check(v != null and v.confront and v.maker == String(CS.SLIPS["maker"]), "the horde down: the Maker confronts you (the meeting, as a confrontation)")
	if v != null:
		_check(v.options.size() == CS.CONFRONT["answers"].size() and String(v._speech()[0]) == String(CS.CONFRONT["speech"][0]), "its words and answers are the confrontation's")
		v.stage = "answer"
		v.t = 9.0
		main.run_essence = {"air": 40.0}
		v.choose(1)
		_check(float(main.run_essence.get("air", 0.0)) < 40.0 and String(v.result.get("lines", [""])[0]).contains("20"), "defying it costs half the essence you carry")
		v.stage = "verdict"
		v.t = 9.0
		v.advance()
		await t._frames(2)
	_check(main.makers.view == null and not t.paused, "then the climb goes on")
	cs.barriers_on = false


# --- the ending ------------------------------------------------------------------------------

func _ending() -> void:
	await _fresh()
	var main = t.main
	var cs = main.climb_shape
	main.grant_test_bonds()
	var by := {}
	for tid in Towers.ORDER:
		by[tid] = 1
	main.profile.record["beasts_by"] = by
	main.profile.record.erase("ending")
	_check(cs.ending_due(), "every guardian beaten: the ending is due")
	main.show_victory(["The climb is complete"])
	main.victory["t"] = 9.0
	main.end_regard()
	_check(cs.ending_view != null and t.paused, "after the summit's victory, the ending plays")
	await t._frames(2)
	cs.ending_view.t = 99.0
	cs.end_ending()
	await t._frames(2)
	_check(cs.ending_view == null and main.profile.count("ending") == 1 and not t.paused, "dismissed, it's kept as seen")
	_check(main.profile.bonds.size() == 2 and main.profile.regarded, "the same climber plays on, marks and all")
	_check(not cs.ending_due(), "it plays once")
	main.camp_choosing = false
	main.camp = {}
	main.victory = {}
	by.erase("chimera")
	main.profile.record.erase("ending")
	_check(not cs.ending_due(), "with one guardian left, no ending")
	var placeholder := true
	for l in CS.ENDING["lines"]:
		placeholder = placeholder and String(l).begins_with("[Yours to write]")
	_check(placeholder, "its words are placeholders for the owner, in a data table")


# --- glimpses still come ----------------------------------------------------------------------

func _glimpses() -> void:
	await _fresh()
	var main = t.main
	main.grant_test_bonds()
	load("res://scripts/glimpses.gd").forced = "eyes"
	main._start_floor(4)
	await t._frames(2)
	_check(main.glimpses.pending != "" or not main.glimpses.cur.is_empty(), "the guardian is still glimpsed now and then (glimpses.gd)")


# --- the Entity ------------------------------------------------------------------------------

func _words() -> void:
	var tips := ["first_climb", "regard", "death_mark", "regard_exit", "regard_climb_on", "lethal_again", "barrier_gate", "barrier_ward", "barrier_break",
		"barrier_slip_warn", "barrier_horde", "barrier_unbound", "barrier_maker_soon", "barrier_maker", "camp", "ending"]
	var missing: Array = tips.filter(func(id): return not Entity.TIPS.has(id))
	_check(missing.is_empty(), "the Entity has a first-time moment for each new thing (missing: %s)" % [missing])
	var how: Array = Talk.DIALOGUE["how"]["choices"]
	_check("how_climb" in how and "how_barrier" in how and "how_first_mark" in how, "its \"How does it work?\" topics: the climb, the barrier, the first mark")
	var all := JSON.stringify([CS.TEXT, CS.CONFRONT, CS.ENDING, CS.BARRIER]) + JSON.stringify(tips.map(func(id): return Entity.TIPS.get(id, {})))
	for k in ["how_climb", "how_barrier", "how_first_mark"]:
		all += JSON.stringify(Talk.DIALOGUE[k])
	var bad: Array = BANNED.filter(func(w): return all.to_lower().contains(w))
	_check(bad.is_empty(), "no banned words in the climb's words (%s)" % [bad])
	_check(String(Talk.DIALOGUE["how_climb"]["lines"][0]).contains("3, 6 and 9") and String(Entity.TIPS["camp"]["more"]).contains("3, 6 and 9"), "the Entity says camps come after floors 3, 6 and 9")


# --- the barrier sits on the stair -------------------------------------------------------------

## The barrier stands over the real stair on floor 1 (an open room), an
## ordinary floor of rooms and the floor after a camp; and a camp (a rest, no
## task to skip: no barrier, as the README's barrier rules say) shows none,
## nor any picture of the last floor's barrier left where its stair had been.
func _barrier_on_stair() -> void:
	await _fresh()
	var main = t.main
	var cs = main.climb_shape
	main.grant_test_bonds()
	main.player.iframes = 9999.0
	cs.barriers_on = true
	main._start_floor(1)
	await t._frames(3)
	_check(_on_stair(main), "floor 1: the gate stands over the stair (%s, gate %s, drawn %s)" % [main.stair_pos, cs.bar.get("rect", Rect2()), cs.drawn])
	# An ordinary floor of rooms whose stair is well away from the open room's.
	var far := false
	for i in 30:
		seed(5300 + i)
		main._start_floor(3)
		await t._frames(1)
		far = main.layout_on and main.stair_pos.distance_to(main.OPEN_ROOM.get_center()) > 200.0 and main.OPEN_ROOM.has_point(main.stair_pos)
		if far:
			break
	seed(Time.get_ticks_usec())
	await t._frames(2)
	_check(far and _on_stair(main), "floor 3, a floor of rooms: the gate stands over its stair (%s, drawn %s)" % [main.stair_pos, cs.drawn])
	# Its stair opened the ordinary way, then up the stair to the camp.
	await _clear_foes()
	main.stair_open = true
	main.room_view.stair_open = true
	await t._ticks(3)
	_check(cs.bar.get("state", "") == "open", "(the task done, the gate lifts)")
	main.run_essence = {}
	main._arrive()
	await t._frames(3)
	_check(main.in_camp and cs.bar.is_empty(), "a camp: no barrier (it's a rest: no task to skip, no horde)")
	_check(cs.drawn == Rect2(), "...and nothing of floor 3's gate is left on the screen (drawn %s)" % cs.drawn)
	_check(main.room_view.stair_pos == main.stair_pos, "...its stair drawn where it is (%s)" % main.stair_pos)
	main.choose_camp(0)
	await t._frames(2)
	main.player.global_position = main.stair_pos
	await t._wait(1.0)
	await t._until(func(): return not main.climbing, 3.0)
	await t._frames(3)
	_check(main.floor_num == 4 and not main.in_camp and _on_stair(main), "past the camp, floor 4: the gate stands over its stair (%s, drawn %s)" % [main.stair_pos, cs.drawn])
	# A floor with no barrier (the Proving's) leaves none on the screen either.
	main.proving.enabled = true
	main._start_floor(6)
	await t._frames(3)
	_check(cs.bar.is_empty() and cs.drawn == Rect2(), "the Proving's floor: no barrier, and none left drawn")
	main.proving.enabled = false
	cs.barriers_on = false


## The barrier is up on this floor, over the stair's steps, and drawn there.
func _on_stair(main) -> bool:
	var cs = main.climb_shape
	if cs.bar.is_empty():
		return false
	var sp: Vector2 = main.stair_pos
	var steps := Rect2(sp + Vector2(-34.0, -24.0), Vector2(68.0, 40.0))  # (room.gd _draw_stair: five steps, 68 px at the foot)
	var r: Rect2 = cs.bar["rect"]
	return main.room_view.stair_pos == sp and r.grow(1.0).encloses(steps) and cs.drawn == r
