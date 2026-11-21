extends RefCounted
## The marks stay within a band of each other: every mark, at steps 1, 3,
## 5 and 12 (its high forks' first sides chosen), fights the standard
## fight (tests/mark_fight.gd: one wave here, the game
## run faster); its score (tests/mark_measure.gd score) against the median of
## the marks at that step, averaged over the steps, stays within BAND,
## and every fight is won. A quick check with one fight each: the full
## measure, with eight fights each, both waves and a ranking per step, is
## tests/mark_measure.gd. Run by smoke_test.gd (_part_tests);
## `t` is the smoke test.

const Fight := preload("res://tests/mark_fight.gd")
const Measure := preload("res://tests/mark_measure.gd")
const Bonds := preload("res://scripts/bonds.gd")

## [least, most] times the median score (averaged over the steps).
const BAND := [0.4, 2.5]
const STEPS := [1, 3, 5, 12]
const SPEED := 3.0
const SEED := 4242
## A fight with no mark, about: only for the printed scores (the ratios to
## the median don't depend on it, so it isn't fought here).
const BASE := {"time": 30.0, "taken": 230.0, "healed": 0.0, "died": 0.0}

var t


func run(smoke) -> void:
	t = smoke
	print("the marks within a band of each other (one quick fight each)")
	var base: Dictionary = BASE
	var scores := {}
	var cleared := 0
	for st in STEPS:
		scores[st] = {}
		for id in Bonds.BONDS:
			var r := await _fight(String(id), st)
			scores[st][id] = Measure.score(r, base)
			if bool(r["cleared"]):
				cleared += 1
			else:
				print("    (%s at step %d: not cleared in time; died %s; left %s; climber at %s in %s)" % [id, st, r["died"], r["left"], r["at"], r["room"]])
	var ratios := {}
	for st in STEPS:
		var med: float = Measure.median(scores[st].values())
		var line := []
		for id in scores[st]:
			line.append("%s %.2f" % [id, scores[st][id]])
			ratios[id] = float(ratios.get(id, 0.0)) + scores[st][id] / maxf(med, 0.01) / float(STEPS.size())
		print("    step %d (median %.2f): %s" % [st, med, ", ".join(line)])
	# One quick fight is noisy, so the check is on each mark's ratio to the
	# median averaged over the steps (the full measure ranks each step).
	for id in ratios:
		var k: float = ratios[id]
		t._check(k >= BAND[0] and k <= BAND[1], "%s: %.2f times the median, over steps 1, 3, 5 and 12 (%.2f to %.2f)" % [id, k, BAND[0], BAND[1]])
	t._check(cleared == scores.size() * Bonds.BONDS.size(), "every mark clears the standard room at every step (%d of %d)" % [cleared, scores.size() * Bonds.BONDS.size()])


func _fight(id: String, st: int) -> Dictionary:
	await t._fresh_main()
	t.paused = false
	var main = t.main
	main.touch._set_active(false)
	main.pad._set_active(false)
	seed(SEED)
	var f = Fight.new()
	t.root.add_child(f)
	f.begin(main, id, st, true, 1, SPEED)
	while not f.done:
		await t.physics_frame
	var r: Dictionary = f.result
	f.queue_free()
	return r
