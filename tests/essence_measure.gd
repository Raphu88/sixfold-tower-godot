extends SceneTree
## A measure, not a check: the floor bot (tests/floor_bot_driver.gd) plays
## floors of one tower and this prints the essence it gathered and what each
## body part soaked up on each, to tune the split (essence_flow.gd) and the
## soak rate (profile.gd SOAK_RATE) against real floors. The bot only
## strikes (it never parries or rolls on purpose), so the hand's share of the
## soak is higher than a player's.
##
## Run: godot --headless --fixed-fps 60 -s tests/essence_measure.gd -- tower=gryphon

const TestRun := preload("res://scripts/test_run.gd")
const Sweep := preload("res://tests/floor_bot_sweep.gd")

var main


func _init() -> void:
	TestRun.begin()
	Engine.set_meta("sixfold_test", true)
	_run.call_deferred()


func _run() -> void:
	var tower := "gryphon"
	var floors: Array = [1, 2, 3, 4, 5, 7, 8, 9, 10, 11]
	for a in OS.get_cmdline_user_args():
		if a.begins_with("tower="):
			tower = a.trim_prefix("tower=")
		elif a.begins_with("floors="):
			floors = Array(a.trim_prefix("floors=").split(",")).map(func(x): return int(x))
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	for i in 3:
		await process_frame
	main.profile.regarded = true
	main.first_climb = false
	main.player.mouse_aim = false
	main.tower = tower
	var total := 0.0
	var soak_total := {}
	for fl in floors:
		main.climb_essence = {}
		main.climb_soak = {}
		var r: Dictionary = await Sweep.play(self, main, fl, 1.0)
		var e := 0.0
		for k in main.climb_essence:
			e += float(main.climb_essence[k])
		total += e
		var parts := []
		for pt in main.climb_soak:
			soak_total[pt] = float(soak_total.get(pt, 0.0)) + float(main.climb_soak[pt])
			parts.append("%s %.0f" % [pt, float(main.climb_soak[pt])])
		print("MEASURE floor %2d  %s  essence %4.0f  (%s)  soak: %s" % [fl, "ok  " if r.get("ok", false) else "FAIL", e, main.climb_essence, ", ".join(parts)])
	print("MEASURE total essence %.0f over %d floors; soak %s" % [total, floors.size(), soak_total])
	TestRun.finish()
	quit(0)
