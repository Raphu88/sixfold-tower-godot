extends RefCounted
## New marks before the summit (essence_flow.gd EARNED, FALL_MARK; main.gd
## try_earned_mark, fall_mark; makers.gd grant_mark): a sealed wing beaten
## keeping its rule on an early floor with a fully soaked part brings a mark
## from the Maker of Marks (its line, the mark, the sound), but not on a later
## floor, not with the rule broken, not without a full part, not twice a
## climb, not on the first climb or for the Unbound; a fall with a full part
## can leave a faint mark (the roll forced); the Entity hints at it (a sealed
## door seen, a part nearly full) and explains the grant once. Run by
## smoke_test.gd (_part_tests); `t` is the smoke test.

const Flow := preload("res://scripts/essence_flow.gd")
const Guide := preload("res://scripts/guide.gd")
const PS := preload("res://scripts/profile.gd")

var t


func run(smoke) -> void:
	t = smoke
	print("new marks: a Maker's grant for a sealed wing won early, a faint mark in a fall")
	await _granted()
	await _not_granted()
	await _fall()
	await _hints()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## A floor with a sealed wing, the climber marked (hand, legs) and the back
## fully soaked. Returns the wing ({} if none could be made).
func _ready_wing(floor_num := 4) -> Dictionary:
	await t._fresh_main()
	t.paused = false
	var main = t.main
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.grant_test_bonds()
	if not await t._wing_floor():
		return {}
	main.floor_num = floor_num
	var prof = main.profile
	prof.soak = {"back": PS.NEW_MARK_SOAK}
	prof.tally = {"stone": 100.0}
	main.marked_this_climb = false
	main.player.iframes = 9999.0
	return main.wings.wings[0]


## The wing's waves beaten: its rule kept (open) or broken.
func _win(w: Dictionary, broken := false) -> void:
	var W = t.main.wings
	w["state"] = "waves"
	w["broken"] = broken
	W.active = w
	W._finish(w, "lesser" if broken else "open", "")
	await t._frames(2)


func _granted() -> void:
	var w := await _ready_wing(4)
	_check(not w.is_empty(), "a floor with a sealed wing")
	if w.is_empty():
		return
	var main = t.main
	var prof = main.profile
	Engine.set_meta("sixfold_tips", true)
	Guide.forget()
	await _win(w)
	_check(prof.bonds.has("back") and not bool(prof.bonds["back"]["faint"]), "a sealed wing beaten keeping its rule, on floor 4, with the back full: the back takes a mark (%s)" % [prof.bonds.keys()])
	_check(main.player.bonds.has("back"), "the climber carries it at once")
	_check(not main.makers.grant.is_empty() and String(main.makers.grant["maker"]) == String(Flow.EARNED["maker"]), "the Maker of Marks grants it: its sign over the climber")
	var title := String(main.banner.get("title", ""))
	var lines: Array = main.banner.get("lines", [])
	_check(title.contains("MAKER OF MARKS") and lines.size() == 2 and String(lines[0]) == String(main.makers.MAKERS["marks"]["grant"][0]),
		"the Maker's line shows: %s / %s" % [title, lines])
	_check(String(lines[1]).contains(String(main.BondScript.Bonds.BONDS[prof.bonds["back"]["id"]]["name"])), "...and the mark forming: %s" % [lines])
	_check(main.makers.quiet_t > 0.0 and main.makers.shift_t > 0.0, "the light shifts in its colour and the Entity goes quiet")
	_check(Guide.queue.any(func(q): return q.get("id", "") == "maker_mark"), "the Entity explains the grant (once)")
	Guide.queue.clear()
	main.tip("maker_mark")
	Guide.also_told("maker_mark")
	_check(not main.tip("maker_mark"), "...and only once")
	Engine.remove_meta("sixfold_tips")
	Guide.forget()
	# Not twice a climb.
	prof.soak["heart"] = PS.NEW_MARK_SOAK
	await _win(w)
	_check(not prof.bonds.has("heart"), "at most one new mark a climb: a second wing won brings none")
	main.floor_num = int(main.tower_data().get("summit", 12))
	_check(main.summit_mark().is_empty() and not prof.bonds.has("heart"), "...and the summit brings none either")


func _not_granted() -> void:
	# A later floor.
	var w := await _ready_wing(int(Flow.EARNED["last_floor"]) + 1)
	if w.is_empty():
		return
	var prof = t.main.profile
	await _win(w)
	_check(not prof.bonds.has("back"), "on floor %d (past %d): no mark" % [int(Flow.EARNED["last_floor"]) + 1, int(Flow.EARNED["last_floor"])])
	# The rule broken.
	w = await _ready_wing(3)
	prof = t.main.profile
	await _win(w, true)
	_check(not prof.bonds.has("back"), "the rule broken (a lesser prize): no mark")
	w["state"] = "waves"
	w["broken"] = true
	t.main.wings._finish(w, "open", "")
	await t._frames(2)
	_check(not prof.bonds.has("back"), "...even if the vault opens")
	# No full part.
	w = await _ready_wing(3)
	prof = t.main.profile
	prof.soak = {"back": PS.NEW_MARK_SOAK * PS.MARK_FULL * 0.8}
	await _win(w)
	_check(not prof.bonds.has("back"), "a part not yet full: no mark")
	# The first climb, and the Unbound.
	w = await _ready_wing(3)
	prof = t.main.profile
	t.main.first_climb = true
	await _win(w)
	_check(not prof.bonds.has("back"), "not on the first climb (the Regard gives the first mark)")
	t.main.first_climb = false
	t.main.wings.wings[0]["state"] = "idle"
	t.main.unbound.Unbound.become(prof)
	prof.soak = {"back": PS.NEW_MARK_SOAK}
	await _win(w)
	_check(not prof.bonds.has("back"), "not for the Unbound")


func _fall() -> void:
	await t._fresh_main()
	t.paused = false
	var main = t.main
	main.grant_test_bonds()
	var prof = main.profile
	prof.soak = {"throat": PS.NEW_MARK_SOAK}
	prof.tally = {"water": 80.0}
	main.marked_this_climb = false
	main.fall_mark_roll = 0.0  # (the chance forced)
	var p = main.player
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.parry_t = 0.0
	p.receive_attack(99999.0, null)
	await t._frames(3)
	_check(p.dead and prof.bonds.has("throat") and bool(prof.bonds["throat"]["faint"]) and float(prof.bonds["throat"]["debt"]) == PS.FAINT_DEBT,
		"a fall with a full part, the roll in its favour: a faint mark forms on it, owing %d (%s)" % [int(PS.FAINT_DEBT), prof.bonds.get("throat", {})])
	_check(main.fall_note.any(func(l): return String(l).contains("faint")), "the fall screen says so (%s)" % [main.fall_note])
	prof.soak["back"] = PS.NEW_MARK_SOAK
	_check(main.fall_mark(0.0) == "" and not prof.bonds.has("back"), "(never a second new mark that climb)")
	# The roll against it.
	await t._fresh_main()
	t.paused = false
	main = t.main
	main.grant_test_bonds()
	prof = main.profile
	prof.soak = {"throat": PS.NEW_MARK_SOAK}
	main.fall_mark_roll = 0.99
	p = main.player
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.parry_t = 0.0
	p.receive_attack(99999.0, null)
	await t._frames(3)
	_check(p.dead and not prof.bonds.has("throat"), "the roll against it: no mark (a %d%% chance)" % int(round(float(Flow.FALL_MARK["chance"]) * 100.0)))
	main.fall_mark_roll = -1.0


func _hints() -> void:
	var w := await _ready_wing(3)
	if w.is_empty():
		return
	var main = t.main
	Engine.set_meta("sixfold_tips", true)
	Guide.forget()
	main.player.global_position = main.wings._tile_center(w["door"][0]) + Vector2(0, 0)
	await t._frames(6)
	main.camera.reset_smoothing()
	await t._frames(2)
	main.wings._hint_seen()
	_check(Guide.queue.any(func(q): return q.get("id", "") == "wing_watch") or Guide.told("wing_watch"), "a sealed door seen on an early floor: the Entity hints that breaking in can bring rewards")
	var text := String(load("res://scripts/entity.gd").TIPS["wing_watch"]["tip"]).to_lower()
	_check(text.contains("prove yourself") and text.contains("those that watch"), "...in the owner's words: %s" % text)
	Guide.forget()
	# A part nearly full, at a stair.
	var prof = main.profile
	prof.soak = {"back": PS.NEW_MARK_SOAK * PS.MARK_FULL * float(Flow.EARNED["near"]) + 1.0}
	main.floor_num = 2
	main.run_essence = {"stone": 10.0}
	main._arrive()
	await t._frames(2)
	_check(Guide.queue.any(func(q): return q.get("id", "") == "earned_mark"), "a part nearly full: the Entity hints at it at the stair")
	Engine.remove_meta("sixfold_tips")
	Guide.forget()
