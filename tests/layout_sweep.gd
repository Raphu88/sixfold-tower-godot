extends SceneTree
## The layout audit's full sweep: every screen (tests/layout_audit_driver.gd)
## at every Interface size, on a computer (1280x720) and three phones
## (915x412, 800x400, 740x360, touch on). Lists every piece of text that
## sits on other text, is cut short, is cut off by what it sits in, runs
## off the screen or sits under the rail, with a count per screen and size.
##
## Run: godot --headless -s tests/layout_sweep.gd
##   -- ui=large            only that Interface size (small, normal, large, larger)
##   -- size=800x400        only that screen (1280x720 is the computer; any other is a phone)
##   -- only=stash          only the screens whose names hold the word
##   -- unbound             as an Unbound climber (the Techniques page, the essence bench)
##   -- shots=/some/folder  save a picture of each screen there (needs a real
##                          renderer: xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s tests/layout_sweep.gd -- shots=...)
## It ends with exit code 1 if anything was found.

const TestRun := preload("res://scripts/test_run.gd")
const Audit := preload("res://tests/layout_audit_driver.gd")
const UI := preload("res://scripts/ui.gd")

var main
var all: Array = []
var per := {}  # "screen" -> {"size ui" -> count}
var shots := ""
var _tag := ""


func _init() -> void:
	TestRun.begin()
	Engine.set_meta("sixfold_test", true)
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _run() -> void:
	var uis: Array = UI.UI_SIZE_ORDER.duplicate()
	var sizes: Array = [Audit.DESKTOP] + Audit.PHONES
	var only := ""
	var unbound := false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("ui="):
			uis = Array(a.trim_prefix("ui=").split(","))
		elif a.begins_with("size="):
			sizes = []
			for sz in a.trim_prefix("size=").split(","):
				sizes.append(Vector2i(int(sz.get_slice("x", 0)), int(sz.get_slice("x", 1))))
		elif a.begins_with("only="):
			only = a.trim_prefix("only=")
		elif a.begins_with("shots="):
			shots = a.trim_prefix("shots=")
		elif a == "unbound":
			unbound = true
	if shots != "":
		DirAccess.make_dir_recursive_absolute(shots)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await _frames(3)
	main.player.mouse_aim = false
	for e in main.enemies():
		e.set_physics_process(false)
	main.pad._set_active(false)
	Audit.dress(main)
	if unbound:
		Audit.Unbound.become(main.profile)
	var menu = main.menu
	for sz in sizes:
		root.size = sz
		var phone: bool = sz != Audit.DESKTOP
		for ui in uis:
			menu._set_setting("ui_size", ui)
			main.touch._set_active(phone)
			main.apply_view_scale()
			await _frames(3)
			_tag = "%dx%d %s" % [sz.x, sz.y, ui]
			await Audit.sweep(self, main, _tag, _found, false, _shoot if shots != "" else Callable(), only)
	print("")
	print("layout sweep: %d problems" % all.size())
	var names: Array = per.keys()
	names.sort()
	for n in names:
		var bits: Array = []
		for k in per[n]:
			bits.append("%s: %d" % [k, per[n][k]])
		print("  %-28s %s" % [n, "  ".join(bits)])
	TestRun.finish()
	quit(0 if all.is_empty() else 1)


func _found(name: String, problems: Array) -> void:
	if problems.is_empty():
		return
	if not per.has(name):
		per[name] = {}
	per[name][_tag] = problems.size()
	for p in problems:
		all.append(p)
		print(p)


func _shoot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s %s.png" % [shots, _tag, name])
