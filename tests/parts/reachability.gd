extends RefCounted
## There is always a way out: on every floor the stair can be reached from
## the start (closed doors open as you walk up; a locked door opens once its
## key, lever, carrier or puzzle can be reached without passing it), every
## key, lever and carrier can be reached, and every room (and each sealed
## wing's door) can be reached; secret rooms don't count. scripts/reach.gd
## does the walking. Checked on floor plans (many, every tower, every floor
## of rooms, the Proving), on floors as main.gd really builds them (cover,
## traps, wings, secrets, doors hung), and the safety net (main.gd
## check_stuck) that opens a lock if the stair ever can't be reached.
## The heavier sweep: `godot --headless -s tests/reach_sweep.gd -- 200`.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const Floors := preload("res://scripts/floors.gd")
const Towers := preload("res://scripts/towers.gd")
const Reach := preload("res://scripts/reach.gd")
const Proving := preload("res://scripts/proving.gd")

## Plans per tower and floor number in the normal suite (6 towers x 10
## floors x this), and floors built for real per tower.
const PLANS_EACH := 6
const LIVE_EACH := 10

var t


func run(smoke) -> void:
	t = smoke
	_checker()
	_plans()
	await _live()
	await _safety_net()
	await _never_shut_in()
	await _regard_once()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## The checker itself sees a stair locked behind its own key.
func _checker() -> void:
	print("reachability: the checker")
	var tower: Dictionary = Towers.TOWERS["gryphon"]
	var plan := Floors.rooms_floor(4, tower)
	_check(Reach.plan_check(plan)["ok"], "a fresh floor plan passes the check")
	# Lock the stair room's own door, its key inside the stair room.
	var si := -1
	for i in plan["room_info"].size():
		if plan["room_info"][i]["role"] == "stair":
			si = i
	var door := {}
	for d in plan["doors"]:
		if int(d["room"]) == si:
			door = d
	if door.is_empty():
		# (no door there: hang one in its doorway)
		door = {"tiles": plan["room_info"][si]["gates"][0], "horiz": true, "out": Vector2.UP, "room": si}
		plan["doors"].append(door)
	door["lock"] = "key"
	door["lock_id"] = 9
	door["lock_pos"] = plan["stair"] + Vector2(0, 60)
	plan["locks"].append({"kind": "key", "id": 9, "pos": door["lock_pos"]})
	var r := Reach.plan_check(plan)
	_check(not r["ok"] and not r["stair"] and 9 in r["locks"], "...and fails one whose stair is locked, its key behind the lock (%s)" % ", ".join(r["problems"]))
	door["lock_pos"] = plan["start"]
	_check(Reach.plan_check(plan)["stair"], "...but not when that key lies in the start room")


## Floor plans: every tower, every floor of rooms, and the Proving.
func _plans() -> void:
	print("reachability: floor plans")
	var total := 0
	var counts := {}
	var t0 := Time.get_ticks_msec()
	for tid in Towers.ORDER:
		var tower: Dictionary = Towers.TOWERS[tid]
		for n in range(2, int(tower.get("summit", Towers.SUMMIT))):
			for k in PLANS_EACH:
				var r := Reach.plan_check(Floors.rooms_floor(n, tower, false))
				total += 1
				_count(counts, r)
		var pr := Reach.plan_check(Proving.build_plan(tower))
		total += 1
		_count(counts, pr)
	_report(counts, total, "floor plans", Time.get_ticks_msec() - t0)
	_check(counts.is_empty(), "%d floor plans (every tower, floors 2 to 11, the Proving): the stair, every room, wing door, key, lever and carrier can be reached" % total)


func _count(counts: Dictionary, r: Dictionary) -> void:
	if r["ok"]:
		return
	var seen := {}
	var re := RegEx.new()
	re.compile("\\d+ ")
	for p in r["problems"]:
		var key := re.sub(String(p), "", true)
		if not seen.has(key):
			seen[key] = true
			counts[key] = int(counts.get(key, 0)) + 1


func _report(counts: Dictionary, total: int, what: String, ms: int) -> void:
	print("  %d %s in %d ms" % [total, what, ms])
	for key in counts:
		print("    %d (%.2f%%): %s" % [counts[key], 100.0 * counts[key] / maxf(total, 1), key])


## Floors as main.gd builds them: the cover kept, traps laid, doors hung,
## wings and secret rooms carved, monsters spawned.
func _live() -> void:
	print("reachability: floors as the game builds them")
	await t._fresh_main()
	var main = t.main
	main.profile.regarded = true
	main.first_climb = false
	var total := 0
	var counts := {}
	var t0 := Time.get_ticks_msec()
	for tid in Towers.ORDER:
		main.tower = tid
		for k in LIVE_EACH:
			var n: int = 2 + k % 10  # (floor 6: the Proving)
			main._start_floor(n)
			total += 1
			var r := live_report(main)
			_count(counts, r)
	_report(counts, total, "built floors", Time.get_ticks_msec() - t0)
	_check(counts.is_empty(), "%d floors as the game builds them: the stair, every room, wing door, key, lever and carrier can be reached" % total)
	for e in main.enemies():
		e.queue_free()


## plan_check's report for the floor being played, from its start.
static func live_report(main) -> Dictionary:
	var out := {"ok": true, "problems": []}
	var c := Reach.live_check(main, main.player_start)
	if not c["checked"]:
		if main.layout_on:
			out["problems"].append("the start is walled in")
		out["ok"] = out["problems"].is_empty()
		return out
	if not c["stair"]:
		out["problems"].append("the stair can't be reached")
	var reach: PackedByteArray = c["reach"]
	var size: Vector2i = c["size"]
	for i in main.room_info.size():
		var walked := false
		for r in main.room_info[i]["walk"]:
			walked = walked or Reach.rect_reached(reach, size, r)
		if not walked:
			out["problems"].append("room %d (%s, %s) can't be reached" % [i, main.room_info[i]["role"], main.room_themes[i]])
	for w in main.wings.wings:
		if not Reach.rect_reached(reach, size, w["rect"]):
			out["problems"].append("a wing can't be reached")
	for d in main.door_view.list:
		var kind := String(d["lock"])
		if kind in ["key", "carried", "lever", "puzzle"] and not c["open"].has(int(d["lock_id"])):
			out["problems"].append("a %s lock never opens" % kind)
			if OS.get_environment("REACH_DEBUG") != "":  # (what the lock was waiting for)
				print("    floor %d %s, lock %d: opens %s" % [main.floor_num, main.tower, int(d["lock_id"]), str(c["opens"].get(int(d["lock_id"]), {}))])
	out["ok"] = out["problems"].is_empty()
	return out


## The safety net: if the stair can't be reached and a locked door stands
## in the way whose opener can't be reached, the lock gives way.
func _safety_net() -> void:
	print("reachability: the safety net")
	var main = t.main
	main.tower = "gryphon"
	# The stair landing's door is chained (danger waits there) but not locked:
	# no padlock is drawn on it, and walking up to it opens it.
	var stair_door := await _stair_door(main)
	_check(not stair_door.is_empty() and stair_door["style"] == "chained", "a floor whose stair landing has a chained door")
	if stair_door.is_empty():
		return
	main.player.global_position = stair_door["rect"].get_center() + Vector2(stair_door["out"]) * 34.0
	main.player.velocity = Vector2.ZERO
	await t._frames(4)
	_check(stair_door["open"], "...walking up to it opens it: it isn't locked")
	# Now the same door locked, its key nowhere: the safety net opens it.
	stair_door = await _stair_door(main)
	if stair_door.is_empty():
		return
	stair_door["lock"] = "key"
	stair_door["lock_id"] = 77
	main.door_view.keys.clear()
	var c := Reach.live_check(main, main.player_start)
	_check(c["checked"] and not c["stair"] and 77 in c["blocked"], "with the stair's door locked and no key anywhere, the check sees the stair can't be reached")
	main.banner = {}
	var opened: Array = main.check_stuck()
	_check(77 in opened and String(stair_door["lock"]) == "", "...and the safety net opens that lock")
	_check(not main.banner.is_empty() and main.banner.get("title", "") == main.door_view.LOCK_TEXT["relent_title"], "...with a banner saying so")
	_check(Reach.live_check(main, main.player_start)["stair"], "...and the stair can be reached again")
	# A lock whose key can be reached is left alone.
	main._start_floor(4)
	for e in main.enemies():
		e.queue_free()
	await t._frames(2)
	_check(main.check_stuck().is_empty(), "on an ordinary floor the safety net opens nothing")
	main.banner = {}


## A room whose doors grind shut opens again even if its monsters never
## fall (LOCK_IN["failsafe"]), and every doorway it shut opens.
func _never_shut_in() -> void:
	print("reachability: never shut in")
	var main = t.main
	var li := -1
	for n in 60:
		main._start_floor(3 + n % 6)
		if not main.door_view.lock_rooms.is_empty() and not main.enemies().is_empty():
			li = main.door_view.lock_rooms.keys()[0]
			break
	_check(li >= 0, "a floor with a room that shuts you in")
	if li < 0:
		return
	var dv = main.door_view
	var lr: Dictionary = dv.lock_rooms[li]
	var foe = main.enemies()[0]
	foe.set_physics_process(false)
	dv._shut(lr, [foe])
	var tiles: Array = []
	for g in lr["gates"]:
		tiles.append_array(g)
	_check(lr["state"] == "shut" and tiles.all(func(tt): return main.solid[tt.y * main.grid_size.x + tt.x] == 1), "its doorways shut")
	lr["t"] = float(dv.LOCK_IN["failsafe"]) + 1.0
	dv.lock_check = 0.0
	await t._frames(3)
	_check(lr["state"] == "done" and tiles.all(func(tt): return main.solid[tt.y * main.grid_size.x + tt.x] == 0), "with its monster still standing, the failsafe opens every doorway it shut")
	main.banner = {}


## A fresh floor 4 whose stair room has a closed, unlocked door; its
## monsters gone. {} if none turned up.
func _stair_door(main) -> Dictionary:
	for n in 40:
		main._start_floor(4)
		var si := -1
		for i in main.room_info.size():
			if main.room_info[i]["role"] == "stair":
				si = i
		for d in main.door_view.list:
			if si >= 0 and int(d["room"]) == si and not d["open"] and String(d["lock"]) == "":
				for e in main.enemies():
					e.queue_free()
				await t._frames(2)
				return d
	return {}


## The Regard's offer (accept or refuse the mark) shows once: accept, keep
## an heirloom, and even if the Regard were shown again it isn't offered again.
func _regard_once() -> void:
	print("reachability: the Regard's offer, once")
	await t._fresh_main()
	var main = t.main
	main.first_climb = true
	main.climb_soak["hand"] = 30.0
	main._begin_regard(false)
	_check(not main.regard.is_empty() and main.profile.regarded, "the Regard begins and the mark is granted")
	main.regard["t"] = 9.0
	main.end_regard()
	_check(main.camp_choosing and main.camp.get("stage", "") == "unbind", "dismissing it offers to accept or refuse the mark")
	main.unbound.choose(0)  # accept
	var heir: bool = main.camp_choosing and main.camp.get("stage", "") == "heirloom"
	_check(heir, "accepting moves on to the heirloom choice")
	if heir:
		main.keep_heirloom("")
	_check(not main.camp_choosing and main.regard.is_empty(), "keeping an heirloom ends the Regard (the game reloads into the train: the climber is regarded now)")
	# (Tests run outside a scene, so nothing reloads: show the Regard again
	# the way a harness might, and it must not offer the mark a second time.)
	main._begin_regard(false)
	main.regard["t"] = 9.0
	main.end_regard()
	_check(not (main.camp_choosing and main.camp.get("stage", "") == "unbind"), "a Regard shown again doesn't offer the mark again")
	main.camp_choosing = false
	main.camp = {}
	main.regard = {}
