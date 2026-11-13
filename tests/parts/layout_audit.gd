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
