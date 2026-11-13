extends SceneTree
## The layout audit's full sweep: every screen (tests/layout_audit_driver.gd)
## at every Interface size, on a computer (1280x720) and three phones
## (915x412, 800x400, 740x360, touch on). Lists every piece of text that
## sits on other text, is cut short, is cut off by what it sits in, runs
## off the screen or sits under the rail, with a count per screen and size.
## It goes round twice: as a marked climber (every screen), then as an
## Unbound one (the screens that differ: the book, the Techniques page, the
## essence bench, your car).
##
## Run: godot --headless -s tests/layout_sweep.gd
##   -- ui=large            only that Interface size (small, normal, large, larger)
##   -- size=800x400        only that screen (1280x720 is the computer; any other is a phone)
##   -- only=stash          only the screens whose names hold the word (or one of several: only=stash,loadout)
##   -- marked / unbound    only that round
##   -- shots=/some/folder  save a picture of each screen there (needs a real
##                          renderer: xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s tests/layout_sweep.gd -- shots=...)
## The HUD and the card screens are listed too ("hud"), for whoever works on
## them, but don't count. It ends with exit code 1 if anything else was found.

const TestRun := preload("res://scripts/test_run.gd")
const Audit := preload("res://tests/layout_audit_driver.gd")
const UI := preload("res://scripts/ui.gd")
## The screens an Unbound climber sees differently.
const UNBOUND_ONLY := "techniques,climber,train workshop essence,train personal,inventory worn"

var main
var all: Array = []
var reported: Array = []  # the HUD's: listed, not counted
var per := {}  # "screen" -> {"size ui" -> count}
var screens := 0
var shots := ""
var _tag := ""
var _round := ""


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
	var rounds := ["marked", "unbound"]
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
		elif a == "unbound" or a == "marked":
			rounds = [a]
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
	var menu = main.menu
	for r in rounds:
		_round = r
		if r == "unbound":
			Audit.Unbound.become(main.profile)
		for sz in sizes:
			root.size = sz
			var phone: bool = sz != Audit.DESKTOP
			for ui in uis:
				menu._set_setting("ui_size", ui)
				main.touch._set_active(phone)
				main.apply_view_scale()
				await _frames(3)
				_tag = "%dx%d %s" % [sz.x, sz.y, ui]
				var which := only
				if r == "unbound":
					which = UNBOUND_ONLY if only == "" else ",".join(Array(UNBOUND_ONLY.split(",")).filter(func(u): return Array(only.split(",")).any(func(o): return u.contains(o) or o.contains(u))))
					if which == "":
						continue
				await Audit.sweep(self, main, _tag, _found, false, _shoot if shots != "" else Callable(), which)
	print("")
	if not reported.is_empty():
		print("the HUD and the card screens (listed for the HUD's own work; not counted): %d" % reported.size())
		for p in reported:
			print("  ", p)
		print("")
	print("layout sweep: %d screens looked at, %d problems" % [screens, all.size()])
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
	screens += 1
	if name.begins_with("hud"):
		reported.append_array(problems)
		return
	if problems.is_empty():
		return
	var key := name if _round == "marked" else name + " (unbound)"
	if not per.has(key):
		per[key] = {}
	per[key][_tag] = problems.size()
	for p in problems:
		all.append(p)
		print(p)


func _shoot(name: String) -> void:
	await RenderingServer.frame_post_draw
	var img := root.get_viewport().get_texture().get_image()
	img.save_png("%s/%s %s%s.png" % [shots, _tag, name.replace(":", "-"), "" if _round == "marked" else " unbound"])
