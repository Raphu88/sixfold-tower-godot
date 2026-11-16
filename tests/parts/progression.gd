extends RefCounted
## The pace of a mark (profile.gd STEP_XP, STEP_RATE, PROVING_GROWTH,
## SOAK_RATE; essence_flow.gd SPLIT and TINCTURE "mark_boost"), in climbs:
## tests/progression_model.gd runs the game's own bookkeeping over climbs of
## measured essence (no randomness), and the climbs a typical climber needs
## for each step of a first mark, and for a second mark, stay in their bands.
## A mark is a long companion. tests/progression_measure.gd prints the tables.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const Model := preload("res://tests/progression_model.gd")

## Climbs (after the bondless first) for each step, a typical climber: half
## the climbs in the mark's tower, a summit every other climb. [least, most].
const TYPICAL := {2: [3, 4], 3: [7, 10], 4: [15, 21], 5: [30, 45]}
## Every climb a summit in the mark's own tower: the fastest honest pace.
const SUMMITS := {2: [2, 3], 3: [3, 6], 4: [7, 12], 5: [16, 28]}
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
	# A tincture is a noticeable push: a good part of a step early on, never trivial.
	var push: Dictionary = Model.tincture_push()
	t._check(float(push[1]) >= 0.08 and float(push[1]) <= 0.3, "a tincture of its own kind takes a mark %d%% of the way from step 1 to 2" % roundi(float(push[1]) * 100.0))
	t._check(float(push[4]) >= 0.02, "...and still %d%% of the way from step 4 to 5" % roundi(float(push[4]) * 100.0))
	# The Proving's gift is a push too, but no longer a whole step.
	var P = load("res://scripts/profile.gd")
	t._check(P.PROVING_GROWTH > 0.0 and P.PROVING_GROWTH < float(P.STEP_XP[1]), "winning the Proving grows a mark %d, less than a step" % int(P.PROVING_GROWTH))
