extends RefCounted
## The layout audit, in its light form (tests/layout_audit_driver.gd; the
## full sweep is tests/layout_sweep.gd): a representative set of screens at
## the Large Interface size, on a computer (1280x720) and a phone (915x412,
## touch on), must show no text on top of other text, cut short, cut off by
## what it sits in, off the screen or under the rail. It first checks the
## audit itself still sees those things, on a page made wrong on purpose.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const Audit := preload("res://tests/layout_audit_driver.gd")
const UI := preload("res://scripts/ui.gd")

var t
var found: Array = []
var looked := 0


func run(smoke) -> void:
	t = smoke
	print("the layout audit")
	await t._fresh_main()
	var m = t.main
	m.touch._set_active(false)
	m.pad._set_active(false)
	for e in m.enemies():
		e.set_physics_process(false)
	Audit.dress(m)
	await _sees_trouble()
	await _sees_slivers()
	_words_keep_whole()
	var menu = m.menu
	var was_size: Vector2i = t.root.size
	var keep_ui: String = menu.settings["ui_size"]
	for sz in [Audit.DESKTOP, Audit.PHONES[0]]:
		t.root.size = sz
		menu._set_setting("ui_size", "large")
		m.touch._set_active(sz != Audit.DESKTOP)
		m.apply_view_scale()
		await t._frames(3)
		await Audit.sweep(t, m, "%dx%d large" % [sz.x, sz.y], _found, true)
	t._check(looked >= 40, "the audit opened its screens on a computer and a phone at Large (%d)" % looked)
	t._check(found.is_empty(), "no text is on other text, cut short, cut off, off screen or under the rail on them (%d problems): %s" % [found.size(), found.slice(0, 6)])
	for p in found.slice(0, 80):
		print("    ", p)
	await _no_slivers(m)
	t.root.size = was_size
	menu._set_setting("ui_size", keep_ui)
	m.touch._set_active(false)
	m.apply_view_scale()
	if menu.is_open():
		menu.close()
	m.on_train = false
	t.paused = false
	await t._frames(2)


func _found(_name: String, problems: Array) -> void:
	looked += 1
	found.append_array(problems)


## A page made wrong on purpose: the audit must flag each kind of trouble.
func _sees_trouble() -> void:
	var root := Control.new()
	root.size = Vector2(400, 300)
	t.root.add_child(root)
	var a := Label.new()
	a.text = "One line of words"
	a.position = Vector2(20, 20)
	root.add_child(a)
	var b := Label.new()
	b.text = "Another on top of it"
	b.position = Vector2(60, 22)
	root.add_child(b)
	var cut := Button.new()
	cut.text = "A button far too narrow for its words"
	cut.clip_text = true
	cut.position = Vector2(20, 80)
	cut.size = Vector2(70, 30)
	root.add_child(cut)
	var clip := Control.new()
	clip.clip_contents = true
	clip.position = Vector2(20, 140)
	clip.size = Vector2(60, 30)
	root.add_child(clip)
	var inside := Label.new()
	inside.text = "Longer than the box it sits in"
	clip.add_child(inside)
	var off := Label.new()
	off.text = "Half off the side"
	off.position = Vector2(-40, 200)
	root.add_child(off)
	var drawn := Drawn.new()
	drawn.position = Vector2(20, 240)
	drawn.size = Vector2(120, 40)
	root.add_child(drawn)
	await t._frames(2)
	UI.text_notes = []
	drawn.queue_redraw()
	await t._frames(2)
	var notes: Array = UI.text_notes
	UI.text_notes = null
	var out: Array = Audit.scan("made wrong", [root], Rect2(0, 0, 400, 300), {"notes": notes})
	var kinds := {}
	for line in out:
		kinds[String(line).get_slice(": ", 1)] = true
	t._check(kinds.has("over") and kinds.has("cut") and kinds.has("clipped") and kinds.has("off"), "the audit flags text on text, cut short, cut off and off screen on a page made wrong on purpose (%s)" % [kinds.keys()])
	t._check(out.any(func(l): return String(l).contains("drawn 'Drawn words too long") and String(l).contains("cut")), "...and text drawn in code that doesn't fit the width it's drawn into")
	# The same page put right: nothing.
	b.position = Vector2(20, 50)
	cut.size = Vector2(300, 30)
	clip.size = Vector2(300, 90)
	off.position = Vector2(20, 200)
	drawn.room = 300.0
	await t._frames(2)
	UI.text_notes = []
	drawn.queue_redraw()
	await t._frames(2)
	notes = UI.text_notes
	UI.text_notes = null
	out = Audit.scan("put right", [root], Rect2(0, 0, 400, 300), {"notes": notes})
	t._check(out.is_empty(), "...and nothing once it's put right (%s)" % [out.slice(0, 4)])
	root.queue_free()
	await t._frames(1)


## ui.gd keep_text: a button too narrow for its words draws them smaller,
## then wraps them, and never cuts them.
func _words_keep_whole() -> void:
	var f: Font = UI.font("body")
	t._check(UI.fit_floor(f, "A long line of words", 16, 60.0) < 16 and UI.fit_floor(f, "A long line of words", 16, 60.0) >= UI.FIT_FLOOR and UI.fit_floor(f, "Short", 16, 200.0) == 16,
		"a drawn line too long for its width is drawn smaller, no smaller than %d, and one that fits is left alone" % UI.FIT_FLOOR)


## Draws a line into a width (ui.gd draw_text), too narrow at first.
class Drawn extends Control:
	const UI := preload("res://scripts/ui.gd")
	var room := 30.0

	func _draw() -> void:
		UI.draw_text(self, UI.font("body"), Vector2(0, 20), "Drawn words too long for it", HORIZONTAL_ALIGNMENT_LEFT, room, 16, Color.WHITE)


## Buttons squeezed to a sliver (the owner saw them on the Crystals and
## tinctures page: Eat and Force it closed to slivers with no words): the
## audit flags one too narrow for its words, one too short, and a plain one
## showing nothing; and a button whose words keep whole (ui.gd keep_text)
## never closes to a sliver, even in a row that gives it only its smallest
## width (a flow, or a row that doesn't stretch it).
func _sees_slivers() -> void:
	var root := VBoxContainer.new()
	root.position = Vector2(10, 10)
	root.size = Vector2(500, 300)
	t.root.add_child(root)
	var flow := HFlowContainer.new()
	root.add_child(flow)
	var squeezed := Button.new()
	squeezed.text = "Force it: Stormcaller"
	squeezed.clip_text = true  # (no room kept for its words: a sliver)
	flow.add_child(squeezed)
	var holder := Control.new()  # (a container would undo the scale: held in a plain control)
	holder.custom_minimum_size = Vector2(120, 44)
	root.add_child(holder)
	var squash := Control.new()  # (drawn at a third of its height: a button 12 px tall on the screen)
	squash.scale = Vector2(1.0, 0.3)
	holder.add_child(squash)
	var short := Button.new()
	short.text = "Go"
	short.size = Vector2(80, 40)
	squash.add_child(short)
	var blank := Button.new()
	blank.custom_minimum_size = Vector2(60, 30)
	blank.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	root.add_child(blank)
	await t._frames(3)
	var out: Array = Audit.scan("slivers", [root], Rect2(0, 0, 1280, 720))
	var flagged := func(b: Button) -> bool: return out.any(func(l): return String(l).contains("sliver: " + Audit._what(b)))
	t._check(flagged.call(squeezed) and flagged.call(short) and flagged.call(blank), "the audit flags a button squeezed to a sliver: too narrow for its words, too short, or showing nothing (%s)" % [out.filter(func(l): return String(l).contains("sliver"))])
	# Put right: the words kept whole (keep_text), the short one taller, the blank one named.
	var row := HBoxContainer.new()
	root.add_child(row)
	var kept: Array = []
	for text in ["Force it: Stormcaller", "Eat 10"]:
		for parent in [flow, row]:
			var b := Button.new()
			b.text = text
			parent.add_child(b)
			UI.keep_text(b)
			kept.append(b)
	squeezed.queue_free()
	squash.scale = Vector2.ONE
	blank.text = "Close"
	await t._frames(4)
	out = Audit.scan("slivers put right", [root], Rect2(0, 0, 1280, 720)).filter(func(l): return String(l).contains(": sliver: "))
	t._check(out.is_empty() and kept.all(func(b): return b.size.x > 40.0), "...a button whose words keep whole never closes to a sliver, in a flow or a row that doesn't stretch it (%s)" % [out.slice(0, 4)])
	root.queue_free()
	await t._frames(1)


## No button squeezed to a sliver on a phone (800x400, touch on), a computer
## (1280x720) and a big screen (1920x1080), at the Normal Interface size:
## the representative screens, then every climber tab, the Crystals and
## tinctures page, the Exchange's counter, the Data editor's tabs, the
## controls and every station stop.
func _no_slivers(m) -> void:
	var menu = m.menu
	var slivers: Array = []
	var seen := [0]
	var keep := func(_name: String, problems: Array) -> void:
		seen[0] += 1
		slivers.append_array(problems.filter(func(l): return String(l).contains(": sliver: ")))
	for sz in [Audit.PHONES[1], Audit.DESKTOP, Vector2i(1920, 1080)]:
		t.root.size = sz
		menu._set_setting("ui_size", "normal")
		m.touch._set_active(sz.y < 600)
		m.apply_view_scale()
		await t._frames(3)
		var tag := "%dx%d normal" % [sz.x, sz.y]
		await Audit.sweep(t, m, tag, keep, true)
		await Audit.sweep(t, m, tag, keep, false, Callable(), "climber,pour,exchange,data,settings controls,station")
	t._check(seen[0] >= 120, "the sliver check opened its screens at 800x400, 1280x720 and 1920x1080 (%d)" % seen[0])
	t._check(slivers.is_empty(), "no button is squeezed to a sliver on them (%d): %s" % [slivers.size(), slivers.slice(0, 6)])
	for p in slivers.slice(0, 40):
		print("    ", p)
