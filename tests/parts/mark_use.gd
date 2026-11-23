extends RefCounted
## Marks grow by use, and burns (scripts/mark_use.gd; profile.gd pour;
## bond.gd pay; player.gd the forced cast; main.gd the stair and the
## burnout): at a stair the marks' share first refills what each mark's
## spells drew, then deepens it by 0.6 x that use (using up banked essence);
## an unused mark takes only a trickle; what's left condenses into crystals;
## casting more than you bank adds nothing, and there's no cap a climb. Burns
## stack: burned, then paralyzed (no casting), healing one rung a stair; a
## forced cast (held, on a key or a touch button) burns a paralyzed mark out:
## dark for this climb and the next three, at most a step of depth lost,
## never erased, counted as a slip toward a Maker. Old saves keep their step.
## The Entity explains it all, with none of the owner's banned words. Run by
## smoke_test.gd (_part_tests); `t` is the smoke test.

const MU := preload("res://scripts/mark_use.gd")
const PS := preload("res://scripts/profile.gd")
const Bonds := preload("res://scripts/bonds.gd")
const Entity := preload("res://scripts/entity.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const Help := preload("res://scripts/entity_help.gd")
const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

var t


func run(smoke) -> void:
	t = smoke
	print("marks grow by use, and burns")
	_numbers()
	_refill_and_deepen()
	_bank_decides()
	_trickle_and_kinds()
	_eating()
	_old_saves()
	await _burn_ladder()
	await _forced_cast()
	_dark_and_maker()
	_words()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## A climber with one mark (Stormcaller, Air, on the hand) at `xp`.
func _prof(xp := 0.0):
	var prof = PS.new()
	prof.saving = false
	prof.regarded = true
	prof.add_bond("hand", "stormcaller", false)
	prof.bonds["hand"]["xp"] = xp
	return prof


func _numbers() -> void:
	_check(is_equal_approx(float(MU.USE["deepen"]), 0.6) and is_equal_approx(float(MU.USE["cost"]), 1.0), "a mark deepens 0.6 for each essence it used, each depth using 1 banked essence")
	_check(float(MU.USE["trickle"]) > 0.0 and float(MU.USE["trickle"]) <= 0.1, "an unused mark takes in only a trickle (%d%% of its own kind)" % int(round(float(MU.USE["trickle"]) * 100.0)))
	_check(int(MU.BURN["dark_climbs"]) == 3 and float(MU.BURN["loss"]) > 0.0 and float(MU.BURN["loss"]) <= 1.0 and float(MU.BURN["force_hold"]) >= 0.5, "a burnout: dark three climbs, some depth lost, a deliberate hold to force it")
	var rising := true
	for i in range(1, PS.STEP_XP.size()):
		rising = rising and float(PS.STEP_XP[i]) > float(PS.STEP_XP[i - 1])
	_check(PS.STEP_XP.size() == 12 and rising, "twelve steps of depth, each deeper than the last")


func _refill_and_deepen() -> void:
	var prof = _prof(10.0)
	MU.note_use(prof, "hand", 30.0)
	_check(is_equal_approx(MU.used(prof, "hand"), 30.0), "a cast notes what the mark drew")
	var out: Dictionary = prof.pour({"air": 200.0}, {}, 0.0)
	var marks := 200.0 * 4.0 / 7.0
	_check(is_equal_approx(float(out["refilled"].get("hand", 0.0)), 30.0), "the stair first refills what the mark used (%.1f)" % float(out["refilled"].get("hand", 0.0)))
	_check(is_equal_approx(float(prof.bonds["hand"]["xp"]), 10.0 + 18.0), "...then deepens it by 0.6 x that use (%.1f deep)" % float(prof.bonds["hand"]["xp"]))
	var left := marks - 30.0 - 18.0
	var cond := floorf(left * float(load("res://scripts/essence_flow.gd").OVERFLOW["crystals"]))
	_check(prof.crystal_total("air") == cond and float(out["mark_left"]) == cond and is_equal_approx(float(out["over"]), left) and is_equal_approx(float(out["lost"]), left - cond), "...and of what's left of the marks' share, a share condenses into crystals (%d of %d), the rest goes back to the well" % [int(prof.crystal_total("air")), int(left)])
	_check(MU.used(prof, "hand") == 0.0 and out["deepened"].has("hand") and out["lines"].any(func(l): return String(l) == MU.TEXT["deepened"] % "Hand"), "its use is spent, and the stair says it deepened with use (no numbers)")
	# No cap a climb: every stair of a long climb deepens it again.
	prof = _prof(0.0)
	for i in 8:
		MU.note_use(prof, "hand", 50.0)
		prof.pour({"air": 600.0}, {}, 0.0)
	_check(is_equal_approx(float(prof.bonds["hand"]["xp"]), 8.0 * 30.0), "no cap a climb: eight stairs of use deepen it eight times (%.0f)" % float(prof.bonds["hand"]["xp"]))


func _bank_decides() -> void:
	var a = _prof(0.0)
	MU.note_use(a, "hand", 150.0)
	var out: Dictionary = a.pour({"air": 70.0}, {}, 0.0)
	var marks := 70.0 * 4.0 / 7.0
	var grown := float(a.bonds["hand"]["xp"])
	_check(is_equal_approx(grown, marks * 0.6 / 1.6) and is_equal_approx(float(out["refilled"]["hand"]), marks / 1.6) and a.crystal_total("air") == 0.0, "a stair that can't pay it all pays part of each: refilled %.1f, deepened %.1f, nothing left" % [float(out["refilled"]["hand"]), grown])
	var b = _prof(0.0)
	MU.note_use(b, "hand", 1500.0)
	b.pour({"air": 70.0}, {}, 0.0)
	_check(is_equal_approx(float(b.bonds["hand"]["xp"]), grown), "casting ten times more than you bank adds nothing (%.1f, %.1f)" % [float(b.bonds["hand"]["xp"]), grown])
	var c = _prof(0.0)
	MU.note_use(c, "hand", 10.0)
	c.pour({"air": 70.0}, {}, 0.0)
	_check(float(c.bonds["hand"]["xp"]) < grown, "...and never grows a mark more than casting less would take from the bank")


func _trickle_and_kinds() -> void:
	var prof = _prof(0.0)
	prof.pour({"air": 200.0}, {}, 0.0)
	var marks := 200.0 * 4.0 / 7.0
	var want := marks * float(MU.USE["trickle"])
	var of := float(load("res://scripts/essence_flow.gd").OVERFLOW["crystals"])
	_check(is_equal_approx(float(prof.bonds["hand"]["xp"]), want) and prof.crystal_total("air") == floorf((marks - want) * of), "a mark that wasn't used takes in a trickle (%.1f); a share of the rest condenses (%d), the rest goes back to the well" % [float(prof.bonds["hand"]["xp"]), int(prof.crystal_total("air"))])
	var used = _prof(0.0)
	MU.note_use(used, "hand", 30.0)
	used.pour({"air": 200.0}, {}, 0.0)
	_check(float(used.bonds["hand"]["xp"]) > float(prof.bonds["hand"]["xp"]) * 3.0, "using a mark is what grows it (%.1f used, %.1f unused)" % [float(used.bonds["hand"]["xp"]), float(prof.bonds["hand"]["xp"])])
	# Another kind pays only a third.
	var f = _prof(0.0)
	MU.note_use(f, "hand", 30.0)
	f.pour({"fire": 300.0}, {}, 0.0)
	var fire := 300.0 * 4.0 / 7.0
	_check(is_equal_approx(float(f.bonds["hand"]["xp"]), 18.0) and f.crystal_total("fire") == floorf((fire - 48.0 / float(MU.USE["other"])) * of), "another kind pays a third: Fire into an Air mark (%d Fire left)" % int(f.crystal_total("fire")))
	# The body's marks slow it.
	var two = _prof(0.0)
	two.add_bond("legs", "tidecaller", false)
	MU.note_use(two, "hand", 30.0)
	two.pour({"air": 200.0}, {}, 0.0)
	_check(is_equal_approx(float(two.bonds["hand"]["xp"]), 18.0 * two.body_drag()), "a body that carries more marks deepens each slower (%.1f)" % float(two.bonds["hand"]["xp"]))
	# A faint mark pays its debt first, then deepens.
	var faint = PS.new()
	faint.saving = false
	faint.add_bond("hand", "stormcaller", false, 0.75)
	faint.bonds["hand"]["faint"] = true
	faint.bonds["hand"]["debt"] = 40.0
	MU.note_use(faint, "hand", 10.0)
	faint.pour({"air": 140.0}, {}, 0.0)
	_check(not bool(faint.bonds["hand"]["faint"]) and float(faint.bonds["hand"]["xp"]) > 0.0, "a faint mark pays its debt from the marks' share first, then deepens")


func _eating() -> void:
	var prof = _prof(0.0)
	MU.note_use(prof, "hand", 100.0)
	prof.density = {}
	prof.bank({"air": 70.0}, {})
	var marks := 70.0 * 4.0 / 7.0
	_check(prof.crystals.is_empty() and is_equal_approx(float(prof.density.get("air", 0.0)), 70.0 - marks), "eating a crystal: what the marks take refills and deepens them, none condenses again")
	_check(is_equal_approx(MU.used(prof, "hand"), 100.0 - marks / 1.6), "...and the use it didn't pay waits for the stair (%.1f)" % MU.used(prof, "hand"))


func _old_saves() -> void:
	var path := "user://test_mark_use_old.cfg"
	var old := ConfigFile.new()
	old.set_value("profile", "regarded", true)
	old.set_value("profile", "bonds", {"hand": {"id": "stormcaller", "xp": 480.0, "faint": false, "debt": 0.0}, "legs": {"id": "windwalker", "xp": 950.0, "faint": false, "debt": 0.0},
		"heart": {"id": "warden", "xp": 130.0, "faint": false, "debt": 0.0}})
	old.save(path)
	var prof = PS.new()
	prof.save_path = path
	prof.load_save()
	var steps_ok := true
	for part in ["hand", "legs", "heart"]:
		var was: int = {"hand": 6, "legs": 12, "heart": 2}[part]
		steps_ok = steps_ok and PS.step_for_xp(float(prof.bonds[part]["xp"])) == was
	_check(steps_ok and is_equal_approx(float(prof.bonds["hand"]["xp"]), float(PS.STEP_XP[5])) and is_equal_approx(float(prof.bonds["legs"]["xp"]), float(PS.STEP_XP[11])), "an old save's marks become depth: nobody loses a step (%s)" % [prof.bonds])
	var heart := float(prof.bonds["heart"]["xp"])
	_check(is_equal_approx(heart, float(PS.STEP_XP[1]) + 0.5 * (float(PS.STEP_XP[2]) - float(PS.STEP_XP[1]))), "...and as far through it (%.0f)" % heart)
	prof.save()
	var again = PS.new()
	again.save_path = path
	again.load_save()
	_check(is_equal_approx(float(again.bonds["heart"]["xp"]), heart), "a converted save isn't converted twice")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _fresh() -> void:
	await t._fresh_main()
	t.paused = false
	var main = t.main
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.grant_test_bonds()
	for e in main.enemies():
		e.queue_free()
	await t._frames(2)


func _burn_ladder() -> void:
	await _fresh()
	var main = t.main
	var p = main.player
	var hb = p.bonds["hand"]
	hb.essence = 0.0
	_check(hb.pay() == "burned" and hb.burned and not hb.paralyzed, "an overdraw burns the mark")
	hb.essence = 0.0
	_check(hb.pay() == "paralyzed" and hb.paralyzed and hb.missing > 0.0, "overdrawing a burned mark paralyzes it")
	_check(p._burned("hand"), "...and a paralyzed mark still weakens its body part")
	p.attack_cd = 0.0
	p.cast_t = 0.0
	hb.essence = hb.capacity()
	p._try_cast("hand")
	_check(p.cast_t <= 0.0 and is_equal_approx(hb.essence, hb.capacity()), "a paralyzed mark can't be cast normally, even full")
	# The stair heals one rung: paralyzed -> burned -> healed.
	main.floor_num = 2
	main.run_essence = {}
	main._arrive()
	await t._frames(2)
	hb = p.bonds["hand"]
	_check(not hb.paralyzed and hb.burned, "a stair heals a paralyzed mark one rung: it's burned")
	main._arrive()
	await t._frames(2)
	hb = p.bonds["hand"]
	_check(not hb.paralyzed and not hb.burned, "...and the next stair heals the burn")
	# The stair refills what a mark used into its pool.
	hb.essence = 0.0
	main.MarkUse.note_use(main.profile, "hand", 20.0)
	main.run_essence = {"air": 200.0}
	main._arrive()
	await t._frames(2)
	_check(float(p.bonds["hand"].essence) >= 20.0 - 0.01, "the stair puts what a mark used back into its pool (%.0f)" % float(p.bonds["hand"].essence))
	# A deeper pool holds more, between its step and the next.
	var info: Dictionary = main.profile.bonds["hand"]
	info["xp"] = float(PS.STEP_XP[1]) + 0.5 * (float(PS.STEP_XP[2]) - float(PS.STEP_XP[1]))
	main._give_bonds()
	var cap: float = p.bonds["hand"].capacity()
	_check(cap > p.bonds["hand"]._cap_at(2) and cap < p.bonds["hand"]._cap_at(3), "a deeper pool holds more (%.1f, between step 2's and step 3's)" % cap)


func _forced_cast() -> void:
	await _fresh()
	var main = t.main
	var p = main.player
	var prof = main.profile
	p.set_physics_process(false)
	prof.bonds["hand"]["xp"] = float(PS.STEP_XP[3]) + 5.0  # (just past step 4)
	main._give_bonds()
	var hb = p.bonds["hand"]
	hb.burned = true
	hb.paralyzed = true
	# A tap on a paralyzed mark's key says how to force it, and casts nothing.
	p.buffered = ""
	p.pick_part = "hand"
	p._update_pick(0.1)
	_check(p.buffered == "" and p.forced_part == "", "a tap on a paralyzed mark casts nothing")
	# Holding it fills the warning; held long enough, the forced cast comes.
	p.pick_part = "hand"
	Input.action_press("cast_hand")
	p._update_pick(float(MU.BURN["force_hold"]) * 0.5)
	var warned: bool = p.force_part == "hand" and p.force_t > 0.0
	p._update_pick(float(MU.BURN["force_hold"]) * 0.6)
	Input.action_release("cast_hand")
	_check(warned, "holding it shows the warning (the HUD and its touch button fill as it comes)")
	_check(p.forced_part == "hand" and p.buffered == "cast_hand" and p.force_part == "", "...and held long enough, it forces a cast")
	p._reset_pick()
	# On a phone the button holds the same key down.
	main.touch._set_active(true)
	main.touch._layout()
	var btn := {}
	for b in main.touch.buttons:
		if b["id"] == "cast_hand":
			btn = b
	if not btn.is_empty():
		main.touch._touch_down(7, btn["c"])
		var held: bool = Input.is_action_pressed("cast_hand")
		main.touch._touch_up(7)
		_check(held and not Input.is_action_pressed("cast_hand"), "a paralyzed mark's touch button holds its key while the finger stays (the forced cast works on a phone)")
	else:
		_check(false, "the hand's touch button is there")
	main.touch._set_active(false)
	# The forced cast: it fires, and the mark burns out.
	var before := float(prof.bonds["hand"]["xp"])
	var slips: int = prof.count("slips")
	p.buffered = ""
	p.set_physics_process(true)
	p.attack_cd = 0.0
	p.forced_part = "hand"
	p._try_cast("hand")
	await t._wait(0.9)
	var info: Dictionary = prof.bonds.get("hand", {})
	_check(not info.is_empty(), "a burned-out mark is never erased")
	_check(MU.dark(prof, "hand") and not p.bonds.has("hand"), "a forced cast burns it out: it goes dark (no casting, no passive)")
	var after := float(info.get("xp", 0.0))
	_check(after < before and PS.step_for_xp(after) >= 3, "...it loses some depth, never more than one step back (step %d)" % PS.step_for_xp(after))
	_check(prof.count("slips") == slips + 1, "...and counts as a slip toward a Maker")
	var lines: Array = main.banner.get("lines", [])
	_check(String(main.banner.get("title", "")) == MU.TEXT["burnout_title"] and lines.any(func(l): return String(l).contains("guardians frown")), "the burnout moment: the guardians frown on a damaged mark (%s)" % [lines])
	# A dark mark's key says it's dark.
	p._try_cast("hand")
	_check(not p.bonds.has("hand"), "a dark mark's key casts nothing")
	# Mid-step, it loses half a step's span.
	var q = _prof(float(PS.STEP_XP[5]) + 100.0)
	var lost: float = float(MU.burn_out(q, "hand")["lost"])
	_check(is_equal_approx(lost, float(MU.BURN["loss"]) * (float(PS.STEP_XP[6]) - float(PS.STEP_XP[5]))), "a burnout mid-step loses %d%% of a step (%.0f)" % [int(float(MU.BURN["loss"]) * 100.0), lost])


func _dark_and_maker() -> void:
	var prof = _prof(float(PS.STEP_XP[2]))
	prof.record["slips"] = 2.0
	var out: Dictionary = MU.burn_out(prof, "hand")
	_check(out["maker"] and prof.count("maker_owed") > 0 and out["lines"].has(MU.TEXT["burnout_maker"]), "a burnout that is the third slip brings a Maker, as a slip past a barrier does")
	var dark_in: Array = []
	for i in 4:
		var woke: Array = MU.new_climb(prof)
		dark_in.append(MU.dark(prof, "hand"))
		if i == 3:
			_check(woke.has("hand"), "...on the climb after, it wakes")
	_check(dark_in == [true, true, true, false], "a burned-out mark stays dark for the next three climbs (%s)" % [dark_in])
	# Dark, it takes nothing at a stair, and its use isn't noted.
	var d = _prof(100.0)
	MU.burn_out(d, "hand")
	var xp := float(d.bonds["hand"]["xp"])
	MU.note_use(d, "hand", 50.0)
	d.pour({"air": 200.0}, {}, 0.0)
	_check(is_equal_approx(float(d.bonds["hand"]["xp"]), xp) and MU.used(d, "hand") == 0.0, "a dark mark takes in nothing at a stair")
	_check(MU.dark_words(d, "hand") != "" and not MU.dark_words(d, "hand").is_valid_float(), "the climber screen says how long it sleeps, in words")


func _words() -> void:
	var texts: Array = [str(MU.TEXT).to_lower()]
	for id in ["mark_deepen", "mark_paralyzed", "mark_force", "mark_burnout", "overdraw"]:
		var e: Dictionary = Entity.TIPS.get(id, {})
		_check(e.has("tip") and e.has("more") and String(e["tip"]).length() < 140, "the Entity explains '%s' the first time (a short line and an Archive account)" % id)
		texts.append((String(e.get("tip", "")) + " " + String(e.get("more", ""))).to_lower())
	var how := String(Talk.DIALOGUE["how_marks"]["lines"][0])
	_check(how.contains("use") and how.contains("refill") and how.contains("Zenith"), "'How do marks grow?' says they grow by use, refilled from the stair")
	texts.append(how.to_lower())
	_check(Talk.DIALOGUE.has("how_burns") and Talk.DIALOGUE["how"]["choices"].has("how_burns") and String(Talk.DIALOGUE["how_burns"]["lines"][0]).contains("paralyzed"), "'How do things work here?' answers what overdrawing does: burns, paralyzed, burnout")
	texts.append(String(Talk.DIALOGUE.get("how_burns", {}).get("lines", [""])[0]).to_lower())
	texts.append(String(Talk.DIALOGUE["marks_grow"]["lines"][0]).to_lower())
	for id in ["mark_depth", "mark_depth_bar"]:
		_check(Help.HELP.has(id), "the depth bar has hover and hold help (%s)" % id)
		texts.append(String(Help.HELP.get(id, "")).to_lower())
	var feel := MU.depth_words(_prof(float(PS.STEP_XP[1]) + 20.0), "hand")
	_check(feel != "" and not RegEx.create_from_string("\\d{2,}").search(feel), "how deep a mark feels is said in words, not numbers (\"%s\")" % feel)
	var all := " ".join(texts)
	var found: Array = BANNED.filter(func(w): return RegEx.create_from_string("\\b" + w + "\\b").search(all) != null)
	_check(found.is_empty(), "none of the owner's banned words in marks' growth and burns (%s)" % ", ".join(found))
