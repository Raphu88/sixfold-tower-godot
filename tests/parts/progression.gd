extends RefCounted
## The pace of a mark (profile.gd STEP_XP: the depth each step needs;
## mark_use.gd USE: a mark deepens by use, refilled from what's banked at
## each stair; PROVING_GROWTH, SOAK_RATE; essence_flow.gd SPLIT and TINCTURE
## "mark_boost"), in climbs:
## tests/progression_model.gd runs the game's own bookkeeping over climbs of
## measured essence (no randomness), and the climbs a typical climber needs
## for each step of a first mark, and for a second mark, stay in their bands.
## A mark is a long companion. tests/progression_measure.gd prints the tables.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const Model := preload("res://tests/progression_model.gd")

## Climbs (after the bondless first) for each step, a typical climber: half
## the climbs in the mark's tower, a summit every other climb. [least, most].
## The owner's pace (21 November): one mark at step 12 after about 20 to 25
## climbs (8 to 10 summiting every climb), the same as an Unbound's Node at
## level 12; step 6 a few climbs after step 5.
const TYPICAL := {2: [2, 3], 3: [3, 4], 4: [3, 5], 5: [4, 6], 6: [7, 10], 9: [12, 17], 12: [20, 25]}
## Every climb a summit in the mark's own tower: the fastest honest pace.
const SUMMITS := {2: [1, 2], 3: [2, 3], 4: [2, 3], 5: [3, 4], 6: [3, 5], 12: [8, 10]}
## Step 6 comes this many climbs after step 5, typically: [least, most].
const SIX_AFTER_FIVE := [2, 5]
## The second mark: [least, most] climbs, typical; never before this many summiting.
const SECOND := [6, 12]
const SECOND_FASTEST := 5

var t


func run(smoke) -> void:
	t = smoke
	print("the pace of a mark, in climbs")
	var typ: Dictionary = Model.run("typical", 50)
	var steps: Dictionary = Model.climbs_to_steps(typ["steps"])
	for st in TYPICAL:
		var c := int(steps[st])
		t._check(c >= TYPICAL[st][0] and c <= TYPICAL[st][1], "a typical climber's first mark reaches step %d after %d climbs (%d to %d)" % [st, c, TYPICAL[st][0], TYPICAL[st][1]])
	var gap := int(steps[6]) - int(steps[5])
	t._check(gap >= SIX_AFTER_FIVE[0] and gap <= SIX_AFTER_FIVE[1], "step 6 comes %d climbs after step 5 (%d to %d)" % [gap, SIX_AFTER_FIVE[0], SIX_AFTER_FIVE[1]])
	var fast: Dictionary = Model.climbs_to_steps(Model.run("summits", 50)["steps"])
	for st in SUMMITS:
		var c := int(fast[st])
		t._check(c >= SUMMITS[st][0] and c <= SUMMITS[st][1], "summiting its own tower every climb, step %d after %d climbs (%d to %d)" % [st, c, SUMMITS[st][0], SUMMITS[st][1]])
	var second := int(typ["second"])
	t._check(second >= SECOND[0] and second <= SECOND[1], "a typical climber's second mark comes after %d climbs (%d to %d)" % [second, SECOND[0], SECOND[1]])
	var earned := int(Model.run("typical", 50, true)["second"])
	t._check(earned >= SECOND[0], "the Maker's earned mark doesn't come sooner than %d climbs (%d)" % [SECOND[0], earned])
	var fastest := int(Model.run("summits", 50, true)["second"])
	t._check(fastest >= SECOND_FASTEST, "even summiting every climb, a second mark takes %d climbs or more (%d)" % [SECOND_FASTEST, fastest])
	# Use grows a mark: a climber who never casts takes only the trickle; one
	# who casts ten times as hard grows no faster than the bank pays.
	var none: Array = Model.run("typical", 30, false, Model.BOUGHT_TINCTURES, 0.0)["xp"]
	var typ_xp: Array = typ["xp"]
	t._check(float(none[9]) < float(typ_xp[9]) * 0.5, "a mark that is never cast grows far slower: only the trickle, its tinctures and the Proving's gift (%d against %d after 10 climbs)" % [int(none[9]), int(typ_xp[9])])
	var spam: Array = Model.run("typical", 30, false, Model.BOUGHT_TINCTURES, 10.0)["xp"]
	t._check(float(spam[9]) <= float(typ_xp[9]) * 1.25, "casting ten times as hard adds little beyond what the bank pays (%d against %d after 10 climbs)" % [int(spam[9]), int(typ_xp[9])])
	# A tincture is a noticeable push: a good part of a step early on, never trivial.
	var push: Dictionary = Model.tincture_push()
	t._check(float(push[1]) >= 0.08 and float(push[1]) <= 0.3, "a tincture of its own kind takes a mark %d%% of the way from step 1 to 2" % roundi(float(push[1]) * 100.0))
	t._check(float(push[4]) >= 0.02, "...and still %d%% of the way from step 4 to 5" % roundi(float(push[4]) * 100.0))
	t._check(float(push[11]) >= 0.02 and float(push[11]) <= 0.4, "...and %d%% of the way from step 11 to 12" % roundi(float(push[11]) * 100.0))
	# The Proving's gift is a push too, but no longer a whole step.
	var P = load("res://scripts/profile.gd")
	t._check(P.PROVING_GROWTH > 0.0 and P.PROVING_GROWTH < float(P.STEP_XP[1]), "winning the Proving grows a mark %d, less than a step" % int(P.PROVING_GROWTH))
	t._check(is_equal_approx(P.PROVING_GROWTH, 36.0), "...36 essence, the owner's number (by sixes)")
