extends RefCounted
## Dev tools -> Edit game data: the Data editor. Change the game's words,
## numbers and colours from inside the game, for good (data_registry.gd
## applies and keeps the changes; this page shows them).
##
## Tabs: Words, Numbers, Colours, Appearance and My changes. Each tab lists
## its sections ("The Entity's words", "Store prices", "Menus and HUD"...);
## a section lists its fields, a page at a time. The search box finds any
## field by its name, its path or what it says.
##
## Each field shows its name, its value and, once changed, its default (and
## a Default button to put it back): words in a text box, numbers on a
## slider with a box to type in, colours as a swatch that opens hue,
## saturation, brightness and opacity sliders and a #hex box, true/false as
## a switch. A change takes effect at once (or where the field says when),
## and is saved a moment later: from the Godot editor to the project's
## data/overrides.json, elsewhere to this device (Copy changes hands them
## on; Paste changes takes them in).
##
## The keys, the controller, the mouse and touch work as on every page
## (nav.gd): text boxes take the keys only once chosen (their Edit button,
## a click or a tap; on a phone's browser a tap opens the browser's own text
## box, as the appearance page's name does), and Esc or B leave them.

const UI := preload("res://scripts/ui.gd")
const Reg := preload("res://scripts/data_registry.gd")
const Nav := preload("res://scripts/nav.gd")
const Entity := preload("res://scripts/entity.gd")

## The page's words.
const TEXT := {
	"title": "Edit game data",
	"eyebrow": "Dev tools",
	"sub_project": "Changes save to data/overrides.json in the project: commit it in GitHub Desktop to keep them for good.",
	"sub_local": "Changes save on this device. Copy changes and send them to Claude (or paste them on the computer) to keep them for good.",
	"button": "Edit game data",  # on the dev tools page
	"button_note": "Change the game's words, numbers and colours, for good.",
	"search": "Search any name, word or number…",
	"clear": "Clear",
	"save": "Save",
	"copy": "Copy changes",
	"paste": "Paste changes",
	"edit": "Edit",
	"default_button": "Default",
	"default": "Default: %s",
	"unchanged": "default",
	"sections": "All sections",
	"more": "Show %d more (%d left)",
	"found": "%d found",
	"found_many": "%d+ found: type more to narrow it",
	"none_found": "Nothing matches. Try fewer letters, or another word.",
	"changes_none": "Nothing is changed yet. Whatever you change shows up here, with a Default button to put it back.",
	"revert_all": "Put all %d back to their defaults",
	"revert_all_ask": "%s to put all %d back",
	"reverted_all": "Everything is back to its default.",
	"count": "%d changed",
	"count_none": "Nothing changed",
	"saved_project": "Saved to data/overrides.json: open GitHub Desktop to commit it.",
	"saved_local": "Saved on this device.",
	"not_saved": "Not saved yet",
	"save_failed": "Couldn't save the file.",
	"copied": "Copied %d changes. Paste them to Claude to make them part of the game.",
	"copy_note": "The changes, ready to copy (select all, then copy):",
	"copy_prompt": "Your changes: press and hold, Select all, then Copy.",
	"paste_note": "Paste changes copied from the game here, then Apply:",
	"paste_prompt": "Paste the changes here:",
	"paste_clip": "Paste from clipboard",
	"apply": "Apply",
	"close": "Close",
	"pasted": "Pasted %d changes.",
	"refused": "Refused: %s",
	"banned": "Note: \"%s\" is a word kept out of the game (see CLAUDE.md). Kept anyway.",
	"search_prompt": "Search",
	"hue": "Hue",
	"saturation": "Colour",
	"value": "Light",
	"alpha": "Opacity",
	"on": "On",
	"off": "Off",
	"help": "?",  # shows the Entity's explanation again
	"help_heading": "HOW THIS WORKS",
}

## Fields shown at once (Show more adds as many again).
const PAGE_ROWS := 20
const SEARCH_ROWS := 30

var m  # the menu (menu.gd)
var tab := "words"
var section := ""  # the section open ("" for the list of sections)
var query := ""
var shown := PAGE_ROWS
var colour_open := ""  # the colour field whose sliders show
var panel := ""  # "copy", "paste" or ""
var ask_all := false  # Put all back was pressed once
var status := ""  # the last thing done (saved, copied, pasted...)
var notes := {}  # path -> a warning or refusal to show under its field
var content: VBoxContainer
var said := ""  # the Entity's tip said on this page (the first time it opens, Save is pressed...)
var help := false  # the ? button: the Entity explains the page again
var said_box: VBoxContainer
var search_edit: LineEdit
var status_label: Label
var copy_edit: TextEdit
var paste_edit: TextEdit
var rows := {}  # path -> {"name", "reset", "default", "note", "set": Callable}
var _save_seq := 0
var _theme_stale := false


func _init(menu) -> void:
	m = menu


# --- the page ---------------------------------------------------------------------

func build() -> void:
	rows.clear()
	var small: bool = m.compact()
	m._header(TEXT["title"], TEXT["sub_project"] if Reg.writes_project() else TEXT["sub_local"], TEXT["eyebrow"])
	if said == "" and m.main != null:
		said = m.main.tip_now("data_editor")  # (the first time: the Entity explains the page)
	said_box = VBoxContainer.new()
	said_box.add_theme_constant_override("separation", 4)
	m.box.add_child(said_box)
	_show_said()
	var tabs: Array = []
	for g in Reg.GROUPS:
		var name: String = g[1]
		if g[0] == "changes" and not Reg.applied.is_empty():
			name = "%s (%d)" % [name, Reg.applied.size()]
		tabs.append([g[0], name])
	m._tabs(tabs, tab if query == "" else "", set_tab)
	if small:
		for b in m.box.get_child(m.box.get_child_count() - 2).get_children():
			if b is Button:
				b.custom_minimum_size.x = 0.0  # (five tabs across a phone)
	# The search box and the file buttons.
	var srow: HBoxContainer = m._row()
	search_edit = _line_edit(query, TEXT["search"])
	search_edit.set_meta("data_search", true)
	search_edit.text_changed.connect(_search_changed)
	search_edit.text_submitted.connect(func(_t): _leave_search())
	srow.add_child(search_edit)
	var clr: Button = m._button(TEXT["clear"], clear_search, srow)
	clr.custom_minimum_size.x = 70.0
	clr.disabled = query == ""
	var arow: HBoxContainer = m._row()
	for b in [m._button(TEXT["save"], save_now, arow), m._button(TEXT["copy"], copy_changes, arow), m._button(TEXT["paste"], open_paste, arow)]:
		b.custom_minimum_size.x = 0.0 if small else 120.0
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL if small else Control.SIZE_FILL
		b.set_meta("data_action", b.text)
	var hb: Button = m._button(TEXT["help"], toggle_help, arow)
	hb.custom_minimum_size = Vector2(40, 38)
	hb.set_meta("data_help", true)
	hb.tooltip_text = TEXT["help_heading"].capitalize()
	if help:
		m._primary(hb)
	status_label = m._label("", 0.0, UI.DIM)
	UI.style_label(status_label, "body", 13 if small else 14, UI.DIM)
	status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.keep_text(status_label)  # (its words whole: smaller, then wrapped, never cut)
	status_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if small:
		m.box.add_child(status_label)
	else:
		arow.add_child(status_label)
	_show_status()
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 6 if small else 8)
	m.box.add_child(content)
	fill()
	m._footer()
	search_edit.focus_neighbor_bottom = search_edit.get_path_to(clr)


## The page's lower part, rebuilt on its own (typing a search keeps the box).
func fill() -> void:
	if content == null or not is_instance_valid(content):
		return
	rows.clear()
	for c in content.get_children():
		content.remove_child(c)
		c.queue_free()
	if panel == "copy":
		_copy_panel()
	elif panel == "paste":
		_paste_panel()
	if query != "":
		_results()
	elif tab == "changes":
		_changes()
	elif section == "":
		_section_list()
	else:
		_section_fields()


func _results() -> void:
	var found: Array = Reg.search(query, shown + 1)
	var more := found.size() > shown
	_note(TEXT["none_found"] if found.is_empty() else (TEXT["found_many"] % shown if more else TEXT["found"] % found.size()))
	for i in mini(found.size(), shown):
		_field_row(content, found[i]["path"], true)
	if more:
		var b: Button = m._button("Show more", _more.bind(SEARCH_ROWS), content)
		b.set_meta("data_more", true)


func _changes() -> void:
	var list: Array = Reg.changes()
	if list.is_empty():
		_note(TEXT["changes_none"])
		return
	var b: Button = m._button(TEXT["revert_all_ask"] % [Nav.again(m.main), list.size()] if ask_all else TEXT["revert_all"] % list.size(), revert_all, content)
	b.set_meta("data_revert_all", true)
	if ask_all:
		b.add_theme_color_override("font_color", UI.BAD)
		b.add_theme_color_override("font_focus_color", UI.BAD)
		b.add_theme_color_override("font_hover_color", UI.BAD)
	for i in mini(list.size(), shown):
		_field_row(content, list[i]["path"], true)
	if list.size() > shown:
		m._button(TEXT["more"] % [mini(PAGE_ROWS, list.size() - shown), list.size() - shown], _more.bind(PAGE_ROWS), content).set_meta("data_more", true)


func _section_list() -> void:
	var grid := GridContainer.new()
	grid.columns = 1 if m.compact() else 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	content.add_child(grid)
	for sec in Reg.sections_in(tab):
		var fs: Array = Reg.fields_in(sec["id"])
		var changed := fs.filter(func(f): return Reg.is_changed(f["path"])).size()
		var text := "%s  ·  %d" % [sec["name"], fs.size()]
		if changed > 0:
			text += "  ·  " + TEXT["count"] % changed
		var b: Button = m._button(text, open_section.bind(sec["id"]), grid)
		b.set_meta("data_section", sec["id"])
		UI.keep_text(b)  # (its words whole: smaller, then wrapped, never cut)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		if changed > 0:
			b.add_theme_color_override("font_color", UI.GOLD)


func _section_fields() -> void:
	var sec := Reg.section(section)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	content.add_child(top)
	var up: Button = m._button("‹  " + TEXT["sections"], open_section.bind(""), top)
	up.set_meta("data_up", true)
	var nl: Label = m._label(sec.get("name", ""), 0.0, UI.GOLD)
	UI.style_label(nl, "display", 18, UI.GOLD)
	nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UI.keep_text(nl)  # (its words whole: smaller, then wrapped, never cut)
	top.add_child(nl)
	var when: String = Reg.WHEN.get(sec.get("when", "live"), "")
	if when != "":
		_note("Changes in this section: " + when + ".")
	var fs: Array = Reg.fields_in(section)
	var table := ""
	for i in mini(fs.size(), shown):
		var single: bool = fs[i]["path"].count("/") == 1  # (a single value: no table heading)
		var t: String = "/".join(fs[i]["path"].split("/").slice(0, 2))
		if t != table and not single:
			m._section(Reg.label(fs[i]["path"]).split(" · ")[0], content)
		table = t
		_field_row(content, fs[i]["path"], false, not single)
	if fs.size() > shown:
		m._button(TEXT["more"] % [mini(PAGE_ROWS, fs.size() - shown), fs.size() - shown], _more.bind(PAGE_ROWS), content).set_meta("data_more", true)


# --- a field ----------------------------------------------------------------------

## One field's row: its name, its value to edit, its default once changed.
func _field_row(parent: Node, path: String, wide_label: bool, under_table := false) -> void:
	var f := Reg.field(path)
	if f.is_empty():
		return
	var small: bool = m.compact()
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", UI.box(Color(1, 1, 1, 0.025), Color(UI.LINE, 0.9), 6, 1, 6.0 if small else 8.0))
	card.set_meta("data_row", path)
	parent.add_child(card)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	card.add_child(col)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	col.add_child(top)
	var label := Reg.label(path)
	if wide_label:
		label = Reg.section(f["section"]).get("name", "") + " · " + label
	elif under_table and label.contains(" · "):
		label = label.substr(label.find(" · ") + 3)  # (the table's name is the heading above)
	var name: Label = m._label(label, 0.0, UI.TEXT)
	UI.style_label(name, "display", 15 if small else 16, UI.TEXT)
	name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UI.keep_text(name)  # (its words whole: smaller, then wrapped, never cut)
	name.tooltip_text = path
	top.add_child(name)
	var when := Reg.when(path)
	if when != "" and not small:
		var wl: Label = m._label(when, 0.0, UI.FAINT)
		UI.style_label(wl, "body", 12, UI.FAINT)
		wl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		top.add_child(wl)
	var reset := ResetButton.new()
	reset.text = TEXT["default_button"]
	reset.custom_minimum_size = Vector2(0, 32 if small else 34)
	reset.add_theme_font_size_override("font_size", 14)
	reset.pressed.connect(revert.bind(path))
	reset.set_meta("data_reset", path)
	top.add_child(reset)
	if not small:
		var pl: Label = m._label(path, 0.0, UI.FAINT)
		UI.style_label(pl, "mono", 11, Color(UI.FAINT, 0.8))
		UI.keep_text(pl)  # (its words whole: smaller, then wrapped, never cut)
		col.add_child(pl)
	var r := {"name": name, "reset": reset}
	match f["kind"]:
		"text":
			_text_editor(col, path, r)
		"number":
			_number_editor(col, path, r)
		"colour":
			_colour_editor(col, path, r)
		"bool":
			_bool_editor(col, path, r)
	var dl: Label = m._label("", 0.0, UI.DIM)
	UI.style_label(dl, "body", 13, UI.DIM)
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dl.custom_minimum_size.x = 200.0
	col.add_child(dl)
	var note: Label = m._label("", 0.0, UI.GOLD)
	UI.style_label(note, "body", 13, UI.GOLD)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size.x = 200.0
	col.add_child(note)
	r["default"] = dl
	r["note"] = note
	rows[path] = r
	_row_state(path)


## A row's look after a change: gilt name and the Default button when it
## differs from the default, the default written under it, any note.
func _row_state(path: String) -> void:
	var r: Dictionary = rows.get(path, {})
	if r.is_empty() or not is_instance_valid(r["name"]):
		return
	var changed := Reg.is_changed(path)
	r["name"].add_theme_color_override("font_color", UI.GOLD if changed else UI.TEXT)
	r["reset"].visible = changed
	r["default"].text = TEXT["default"] % Reg.show(Reg.default_of(path), 140) if changed else ""
	r["default"].visible = changed
	var n: String = notes.get(path, "")
	r["note"].text = n
	r["note"].visible = n != ""
	r["note"].add_theme_color_override("font_color", UI.BAD if n.begins_with(TEXT["refused"].split("%")[0]) else UI.GOLD)


func _text_editor(col: Node, path: String, r: Dictionary) -> void:
	var v: String = Reg.value(path)
	var d: String = Reg.default_of(path)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	col.add_child(line)
	var ctrl: Control
	if d.length() <= 64 and not "\n" in d and v.length() <= 64:
		var le := _line_edit(v, "")
		le.text_submitted.connect(func(_t): _commit_text(path, le, true))
		le.focus_exited.connect(func(): _commit_text(path, le, false))
		ctrl = le
	else:
		var te := TextEdit.new()
		te.text = v
		te.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
		te.scroll_fit_content_height = true
		te.custom_minimum_size = Vector2(0, 58)
		te.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		te.focus_mode = Control.FOCUS_CLICK
		te.add_theme_font_size_override("font_size", 15)
		_field_look(te)
		te.focus_exited.connect(func(): _commit_text(path, te, false))
		ctrl = te
	ctrl.set_meta("data_path", path)
	line.add_child(ctrl)
	var eb: Button = m._button(TEXT["edit"], edit_field.bind(ctrl), line)
	eb.custom_minimum_size = Vector2(64, 36)
	eb.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	eb.set_meta("data_edit", path)
	ctrl.focus_neighbor_bottom = ctrl.get_path_to(eb)  # (Esc leaves the box onto its Edit button)
	r["set"] = func(val):
		if is_instance_valid(ctrl):
			ctrl.text = val


func _number_editor(col: Node, path: String, r: Dictionary) -> void:
	var b := Reg.bounds(path)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	col.add_child(line)
	var s := HSlider.new()
	s.min_value = b[0]
	s.max_value = b[1]
	s.step = b[2]
	s.value = float(Reg.value(path))
	s.scrollable = false  # (the wheel scrolls the page)
	s.custom_minimum_size = Vector2(140, 36)
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.set_meta("data_slider", path)
	s.focus_entered.connect(func(): s.modulate = Color(1.0, 0.85, 0.55))
	s.focus_exited.connect(func(): s.modulate = Color.WHITE)
	line.add_child(s)
	var le := _line_edit(Reg.show(Reg.value(path)), "")
	le.custom_minimum_size = Vector2(86, 36)
	le.size_flags_horizontal = Control.SIZE_SHRINK_END
	le.set_meta("data_path", path)
	line.add_child(le)
	le.focus_neighbor_bottom = le.get_path_to(s)
	var range_l: Label = m._label("%s – %s" % [Reg.show(b[0]), Reg.show(b[1])], 0.0, UI.FAINT)
	UI.style_label(range_l, "mono", 11, UI.FAINT)
	range_l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not m.compact():
		line.add_child(range_l)
	var syncing := [false]
	s.value_changed.connect(func(x):
		if syncing[0]:
			return
		_apply(path, x)
		le.text = Reg.show(Reg.value(path)))
	le.text_submitted.connect(func(_t): _commit_number(path, le, s, syncing))
	le.focus_exited.connect(func(): _commit_number(path, le, s, syncing))
	r["set"] = func(val):
		if is_instance_valid(s):
			syncing[0] = true
			s.value = float(val)
			syncing[0] = false
			le.text = Reg.show(val)


func _colour_editor(col: Node, path: String, r: Dictionary) -> void:
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 8)
	col.add_child(line)
	var sw := Swatch.new()
	sw.colour = Reg.value(path)
	sw.custom_minimum_size = Vector2(88, 36)
	sw.set_meta("data_swatch", path)
	sw.pressed.connect(toggle_colour.bind(path))
	line.add_child(sw)
	var le := _line_edit("#" + (Reg.value(path) as Color).to_html(true), "#rrggbbaa")
	le.custom_minimum_size = Vector2(118, 36)
	le.set_meta("data_path", path)
	line.add_child(le)
	var sliders := VBoxContainer.new()
	sliders.add_theme_constant_override("separation", 2)
	sliders.visible = colour_open == path
	col.add_child(sliders)
	var hsva: Array = []
	var syncing := [false]
	var c: Color = Reg.value(path)
	var parts := [["hue", c.h], ["saturation", c.s], ["value", c.v], ["alpha", c.a]]
	for i in parts.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		sliders.add_child(row)
		var l: Label = m._label(TEXT[parts[i][0]], 72.0, UI.DIM)
		UI.style_label(l, "body", 14, UI.DIM)
		row.add_child(l)
		var s := HSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.005
		s.value = parts[i][1]
		s.scrollable = false
		s.custom_minimum_size = Vector2(160, 34)
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.set_meta("data_hsva", i)
		s.focus_entered.connect(func(): s.modulate = Color(1.0, 0.85, 0.55))
		s.focus_exited.connect(func(): s.modulate = Color.WHITE)
		s.value_changed.connect(func(_x):
			if syncing[0]:
				return
			var nc := Color.from_hsv(hsva[0].value, hsva[1].value, hsva[2].value, hsva[3].value)
			_apply(path, nc)
			sw.colour = Reg.value(path)
			sw.queue_redraw()
			le.text = "#" + (Reg.value(path) as Color).to_html(true))
		row.add_child(s)
		hsva.append(s)
	var set_all := func(val: Color):
		if not is_instance_valid(sw):
			return
		sw.colour = val
		sw.queue_redraw()
		le.text = "#" + val.to_html(true)
		syncing[0] = true
		for i in 4:
			hsva[i].value = [val.h, val.s, val.v, val.a][i]
		syncing[0] = false
	le.text_submitted.connect(func(_t): _commit_colour(path, le, set_all))
	le.focus_exited.connect(func(): _commit_colour(path, le, set_all))
	r["set"] = set_all
	r["sliders"] = sliders


func _bool_editor(col: Node, path: String, r: Dictionary) -> void:
	var b := CheckButton.new()
	b.button_pressed = bool(Reg.value(path))
	b.text = TEXT["on"] if b.button_pressed else TEXT["off"]
	b.custom_minimum_size.y = 36
	b.set_meta("data_toggle", path)
	b.toggled.connect(func(on):
		_apply(path, on)
		b.text = TEXT["on"] if on else TEXT["off"])
	col.add_child(b)
	r["set"] = func(val):
		if is_instance_valid(b):
			b.set_pressed_no_signal(bool(val))
			b.text = TEXT["on"] if val else TEXT["off"]


# --- changing --------------------------------------------------------------------

## Changes a field (every editor comes here). "" if done, else why not.
func _apply(path: String, v) -> String:
	var why := Reg.set_value(path, v)
	notes.erase(path)
	if why != "":
		notes[path] = TEXT["refused"] % why
	elif v is String:
		var bad := Reg.banned_in(v)
		if not bad.is_empty():
			notes[path] = TEXT["banned"] % ", ".join(bad)
	_changed(path)
	return why


func _changed(path: String) -> void:
	_row_state(path)
	var hook: String = Reg.section(Reg.field(path).get("section", "")).get("hook", "")
	if hook == "ui":
		_theme_stale = true
	if Reg.when_id(path) == "restart" and m.main != null:
		var s: String = m.main.tip_now("data_restart")
		if s != "":
			said = s
			_show_said()
	if Reg.field(path).get("section", "") == "looks" and m.main != null and m.main.profile != null:
		m.main.apply_appearance()  # (the climber wears the new colours)
	status = ""
	_show_status()
	_schedule_save()


func _commit_text(path: String, ctrl: Control, leave: bool) -> void:
	if not is_instance_valid(ctrl):
		return
	if ctrl.text != Reg.value(path):
		if _apply(path, ctrl.text) != "":
			ctrl.text = Reg.value(path)  # (refused: back to what it is)
	if leave and rows.has(path) and ctrl.is_inside_tree():
		_focus_edit(path)


func _commit_number(path: String, le: LineEdit, s: HSlider, syncing: Array) -> void:
	if not is_instance_valid(le):
		return
	var t := le.text.strip_edges()
	if t == Reg.show(Reg.value(path)):
		return
	_apply(path, t)
	le.text = Reg.show(Reg.value(path))
	syncing[0] = true
	s.value = float(Reg.value(path))
	syncing[0] = false


func _commit_colour(path: String, le: LineEdit, set_all: Callable) -> void:
	if not is_instance_valid(le):
		return
	var t := le.text.strip_edges()
	if not t.begins_with("#"):
		t = "#" + t
	if Color.html_is_valid(t) and Color.html(t).is_equal_approx(Reg.value(path)):
		return
	_apply(path, t)
	set_all.call(Reg.value(path))


func revert(path: String) -> void:
	Reg.revert(path)
	notes.erase(path)
	if tab == "changes" and query == "":
		m.open("data")  # (the row leaves the list)
		return
	var r: Dictionary = rows.get(path, {})
	if r.has("set"):
		r["set"].call(Reg.value(path))
	_changed(path)
	if r.has("name") and is_instance_valid(r["name"]) and not m.main.touch_active:
		_focus_first_in(path)


## Put all back: a second press does it (the first asks).
func revert_all() -> void:
	if not ask_all:
		ask_all = true
		m.open("data")
		return
	ask_all = false
	Reg.revert_all()
	notes.clear()
	status = TEXT["reverted_all"]
	_theme_stale = true
	if m.main != null and m.main.profile != null:
		m.main.apply_appearance()
	_schedule_save()
	m.open("data")


func toggle_colour(path: String) -> void:
	colour_open = "" if colour_open == path else path
	for p in rows:
		if rows[p].has("sliders") and is_instance_valid(rows[p]["sliders"]):
			rows[p]["sliders"].visible = p == colour_open


# --- the tabs, sections and search -------------------------------------------------

func set_tab(id: String) -> void:
	tab = id
	section = ""
	query = ""
	shown = PAGE_ROWS
	ask_all = false
	m._want_focus = {"meta": "tab", "value": id}
	m.open("data")


## Q / E (LB / RB): the next tab.
func cycle(by: int) -> void:
	var ids: Array = Reg.GROUPS.map(func(g): return g[0])
	var id: String = ids[(ids.find(tab) + by + ids.size()) % ids.size()]
	tab = id
	section = ""
	query = ""
	shown = PAGE_ROWS
	ask_all = false
	if not m.rail.has_focus_inside():
		m._want_focus = {"meta": "tab", "value": id}
	m.open("data")


func open_section(id: String) -> void:
	var was := section
	section = id
	shown = PAGE_ROWS
	m._want_focus = {"meta": "data_up", "value": true} if id != "" else ({"meta": "data_section", "value": was} if was != "" else {})
	m.open("data")


func _more(by: int) -> void:
	var first := shown
	shown += by
	fill()
	# The keys go on from the first new field.
	var list: Array = []
	for p in rows:
		list.append(p)
	if first < list.size() and not m.main.touch_active:
		_focus_first_in(list[first])


func _search_changed(t: String) -> void:
	query = t.strip_edges()
	shown = SEARCH_ROWS
	fill()


func clear_search() -> void:
	query = ""
	shown = PAGE_ROWS
	m.open("data")


func _leave_search() -> void:
	var list: Array = m.focusables()
	if not list.is_empty() and is_instance_valid(search_edit):
		for c in list:
			if content.is_ancestor_of(c):
				c.grab_focus()
				return


## Search from code (tests) or the phone's browser box.
func search(q: String) -> void:
	query = q.strip_edges()
	shown = SEARCH_ROWS
	if is_instance_valid(search_edit):
		search_edit.text = q
	m.open("data")


# --- text boxes ------------------------------------------------------------------------

func _line_edit(text: String, hint: String) -> LineEdit:
	var le := LineEdit.new()
	le.text = text
	le.placeholder_text = hint
	le.custom_minimum_size = Vector2(0, 36)
	le.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	le.focus_mode = Control.FOCUS_CLICK  # (the keys step past it: Edit, a click or a tap goes in)
	le.add_theme_font_size_override("font_size", 15)
	_field_look(le)
	return le


func _field_look(c: Control) -> void:
	c.add_theme_stylebox_override("normal", UI.box(Color(UI.VOID, 0.95), UI.LINE_HI, 6, 1, 8.0))
	var focus := UI.box(Color(0.08, 0.07, 0.11), UI.GILT_HI, 6, 2, 8.0)
	focus.shadow_color = Color(UI.GILT, 0.3)
	focus.shadow_size = 5
	c.add_theme_stylebox_override("focus", focus)
	c.add_theme_stylebox_override("read_only", UI.box(Color(UI.VOID, 0.8), UI.LINE, 6, 1, 8.0))
	c.add_theme_color_override("font_color", UI.TEXT)
	c.add_theme_color_override("font_placeholder_color", UI.FAINT)


## A box's Edit button, a click or a tap: into the box. On a phone's browser
## the browser's own text box opens (its keyboard comes with it).
func edit_field(ctrl: Control) -> void:
	if not is_instance_valid(ctrl):
		return
	if _browser_box():
		var path: String = ctrl.get_meta("data_path", "")
		var v = JavaScriptBridge.eval("window.prompt(%s, %s)" % [JSON.stringify(Reg.label(path)), JSON.stringify(ctrl.text.replace("\n", "\\n"))], true)
		if v != null:
			ctrl.text = str(v).replace("\\n", "\n")
			if ctrl.has_meta("data_path"):
				ctrl.focus_exited.emit()  # (commit it, as leaving the box does)
		return
	ctrl.grab_focus()
	if ctrl is LineEdit:
		ctrl.caret_column = ctrl.text.length()


## The menu's tap landed on a text box (menu.gd _tap).
func tap_field(ctrl: Control) -> void:
	if ctrl.has_meta("data_search"):
		if _browser_box():
			var v = JavaScriptBridge.eval("window.prompt(%s, %s)" % [JSON.stringify(TEXT["search_prompt"]), JSON.stringify(query)], true)
			if v != null:
				search(str(v))
			return
		ctrl.grab_focus()
		return
	if ctrl == copy_edit or ctrl == paste_edit:
		ctrl.grab_focus()
		return
	edit_field(ctrl)


func _browser_box() -> bool:
	return OS.has_feature("web") and m.main != null and m.main.touch_active


func _focus_edit(path: String) -> void:
	for b in m.focusables():
		if b.get_meta("data_edit", "") == path:
			b.grab_focus()
			return


func _focus_first_in(path: String) -> void:
	for b in m.focusables():
		var row := _row_of(b)
		if row != null and row.get_meta("data_row", "") == path and b.is_visible_in_tree():
			b.grab_focus()
			return


func _row_of(c: Node) -> Node:
	var p := c.get_parent()
	while p != null and p != content:
		if p.has_meta("data_row"):
			return p
		p = p.get_parent()
	return null


# --- saving, copying, pasting ---------------------------------------------------------

func _schedule_save() -> void:
	_save_seq += 1
	var seq := _save_seq
	if not m.is_inside_tree():
		return
	m.get_tree().create_timer(0.8, true, false, true).timeout.connect(func():
		if seq == _save_seq:
			_autosave())


func _autosave() -> void:
	if Reg.dirty:
		var where := Reg.save()
		status = "" if where != "" else TEXT["save_failed"]
	_refresh_theme()
	_show_status()


func save_now() -> void:
	var where := Reg.save()
	if where == "":
		status = TEXT["save_failed"]
	else:
		status = TEXT["saved_project"] if where == Reg.project_path and Reg.writes_project() else TEXT["saved_local"]
	_refresh_theme()
	_show_status()
	if m.main != null:
		m.main.sfx("ui_confirm")
		var s: String = m.main.tip_now("data_save")  # (the first time: how to keep changes for good)
		if s != "":
			said = s
			_show_said()


## Copy changes: onto the clipboard, and into a box to copy from by hand
## (on a phone's browser, the browser's own box: press and hold, copy).
func copy_changes() -> void:
	var text := Reg.export_text()
	DisplayServer.clipboard_set(text)
	panel = "copy"
	status = TEXT["copied"] % Reg.applied.size()
	if _browser_box():
		var data = JSON.parse_string(text)
		JavaScriptBridge.eval("window.prompt(%s, %s)" % [JSON.stringify(TEXT["copy_prompt"]), JSON.stringify(JSON.stringify(data))], true)
	_show_status()
	fill()
	if not m.main.touch_active:
		_focus_meta("data_close")


func open_paste() -> void:
	if _browser_box():
		var v = JavaScriptBridge.eval("window.prompt(%s, %s)" % [JSON.stringify(TEXT["paste_prompt"]), JSON.stringify("")], true)
		if v != null:
			paste(str(v))
		return
	panel = "paste"
	fill()
	if not m.main.touch_active and is_instance_valid(paste_edit):
		paste_edit.grab_focus()


## Paste changes: applies a changes file; the page says what was taken.
func paste(text: String) -> Dictionary:
	var r := Reg.import_text(text)
	if r["error"] != "":
		status = r["error"]
	else:
		status = TEXT["pasted"] % r["done"]
		if not r["refused"].is_empty():
			status += "  " + TEXT["refused"] % "; ".join(r["refused"].slice(0, 3)) + ("…" if r["refused"].size() > 3 else "")
		panel = ""
		_theme_stale = true
		if m.main != null and m.main.profile != null:
			m.main.apply_appearance()
		_schedule_save()
	m.open("data")
	return r


func _copy_panel() -> void:
	_note(TEXT["copy_note"])
	copy_edit = TextEdit.new()
	copy_edit.text = Reg.export_text()
	copy_edit.editable = false
	copy_edit.custom_minimum_size = Vector2(0, 120)
	copy_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy_edit.focus_mode = Control.FOCUS_CLICK
	copy_edit.add_theme_font_override("font", UI.font("mono"))
	copy_edit.add_theme_font_size_override("font_size", 13)
	_field_look(copy_edit)
	content.add_child(copy_edit)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	content.add_child(row)
	m._button(TEXT["copy"], copy_changes, row)
	m._button(TEXT["close"], close_panel, row).set_meta("data_close", true)


func _paste_panel() -> void:
	_note(TEXT["paste_note"])
	paste_edit = TextEdit.new()
	paste_edit.custom_minimum_size = Vector2(0, 120)
	paste_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	paste_edit.focus_mode = Control.FOCUS_CLICK
	paste_edit.add_theme_font_override("font", UI.font("mono"))
	paste_edit.add_theme_font_size_override("font_size", 13)
	_field_look(paste_edit)
	content.add_child(paste_edit)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	content.add_child(row)
	var apply: Button = m._button(TEXT["apply"], func(): paste(paste_edit.text), row)
	apply.set_meta("data_apply", true)
	m._primary(apply)
	m._button(TEXT["paste_clip"], func(): paste_edit.text = DisplayServer.clipboard_get(), row)
	m._button(TEXT["close"], close_panel, row).set_meta("data_close", true)
	paste_edit.focus_neighbor_bottom = paste_edit.get_path_to(apply)


func close_panel() -> void:
	panel = ""
	m.open("data")


func _focus_meta(meta: String) -> void:
	for b in m.focusables():
		if b.has_meta(meta):
			b.grab_focus()
			return


func _show_status() -> void:
	if status_label == null or not is_instance_valid(status_label):
		return
	var n := Reg.applied.size()
	var s := TEXT["count"] % n if n > 0 else TEXT["count_none"]
	if Reg.dirty:
		s += "  ·  " + TEXT["not_saved"]
	if status != "":
		s = status + "  ·  " + s
	status_label.text = s
	status_label.tooltip_text = s


## The menus' look, built once (the theme), again after a menu colour changed.
func _refresh_theme() -> void:
	if not _theme_stale:
		return
	_theme_stale = false
	m.theme = UI.theme()


## Leaving the page: anything not yet saved is saved.
func leave() -> void:
	_save_seq += 1
	if Reg.dirty:
		Reg.save()
	_refresh_theme()
	panel = ""
	ask_all = false
	said = ""
	help = false


# --- the Entity ------------------------------------------------------------------------

## The ? button: the Entity explains the page and how to keep changes, again.
func toggle_help() -> void:
	help = not help
	m._want_focus = {"meta": "data_help", "value": true}
	m.open("data")


func _key_mode() -> String:
	if m.main == null:
		return "keys"
	return "touch" if m.main.touch_active else ("pad" if m.main.pad_active else "keys")


## What the Entity says at the top of the page: a tip said just now, or (the
## ? button) its whole account of the editor and of keeping changes.
func _show_said() -> void:
	if said_box == null or not is_instance_valid(said_box):
		return
	for c in said_box.get_children():
		said_box.remove_child(c)
		c.queue_free()
	var ps: bool = m.main != null and m.main.pad_ps
	var face := 30.0 if m.compact() else 38.0
	if help:
		for id in ["data_editor", "data_save", "data_restart"]:
			var e: Dictionary = Entity.TIPS.get(id, {})
			if e.is_empty():
				continue
			var row := Entity.says(Entity.fill_keys(e["tip"], _key_mode(), ps), face, String(e["name"]).to_upper())
			row.set_meta("entity", id)
			said_box.add_child(row)
			var more: Label = m._label(Entity.fill_keys(e["more"], _key_mode(), ps), 0.0, UI.DIM)
			UI.style_label(more, "body", UI.SIZE_BODY, UI.DIM)
			more.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			more.custom_minimum_size.x = 200.0
			more.set_meta("help_more", id)
			said_box.add_child(more)
	elif said != "":
		var row := Entity.says(Entity.fill_keys(said, _key_mode(), ps), face)
		row.set_meta("entity", "data")
		said_box.add_child(row)


func _note(text: String) -> void:
	var l: Label = m._label(text, 0.0, UI.DIM)
	UI.style_label(l, "body", 14, UI.DIM)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 200.0
	content.add_child(l)


# --- drawn parts ---------------------------------------------------------------------

## A colour's swatch: the colour over a checkerboard (to show its opacity).
class Swatch extends Button:
	var colour := Color.WHITE

	func _draw() -> void:
		var r := Rect2(Vector2(6, 6), size - Vector2(12, 12))
		var cell := 6.0
		var y := r.position.y
		var row := 0
		while y < r.end.y:
			var x := r.position.x
			var c := row % 2
			while x < r.end.x:
				var w := minf(cell, r.end.x - x)
				var h := minf(cell, r.end.y - y)
				draw_rect(Rect2(x, y, w, h), Color(0.75, 0.75, 0.78) if c % 2 == 0 else Color(0.45, 0.45, 0.5))
				x += cell
				c += 1
			y += cell
			row += 1
		draw_rect(r, colour)
		draw_rect(r, Color(0, 0, 0, 0.6), false, 1.0)


## The Default button: a drawn turning-back arrow before its word.
class ResetButton extends Button:
	const UI := preload("res://scripts/ui.gd")

	func _ready() -> void:
		add_theme_constant_override("h_separation", 4)
		var s := get_theme_stylebox("normal")
		if s != null:
			var st: StyleBox = s.duplicate()
			st.content_margin_left = 30
			add_theme_stylebox_override("normal", st)
			for k in ["hover", "pressed", "focus", "disabled"]:
				var o := get_theme_stylebox(k)
				if o != null:
					var d: StyleBox = o.duplicate()
					d.content_margin_left = 30
					add_theme_stylebox_override(k, d)

	func _draw() -> void:
		var c := Vector2(17, size.y * 0.5)
		var col := get_theme_color("font_color")
		draw_arc(c, 6.0, deg_to_rad(-60), deg_to_rad(210), 16, col, 1.6, true)
		var tip := c + Vector2(cos(deg_to_rad(-60)), sin(deg_to_rad(-60))) * 6.0
		draw_line(tip, tip + Vector2(-4.5, -0.5), col, 1.6, true)
		draw_line(tip, tip + Vector2(0.5, 4.5), col, 1.6, true)
