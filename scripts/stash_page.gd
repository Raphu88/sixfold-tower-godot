extends "res://scripts/loadout_page.gd"
## The stash screen (menu.gd's "stash" page; the Loadout's second tab): your
## stash, the chest in your car that never leaves the train, as a grid you
## can sort (newest, rarity, slot, essence, price) and filter (by slot, by
## essence), with your pack beside it. Choose a piece for its card: wear it,
## move it across (or press it again: one press), or sell it. Vessels kept
## in the stash are here too, to pack for the climb or leave.
##
## The stash holds Train.CHEST_SIZE pieces (40; it held 8 before this
## screen, so old saves load as they were). The sort and filters are
## remembered while the game runs (SORT, SLOT, KIND). The words live in
## loadout_page.gd TEXT and STASH_TEXT below.

static var STASH_TEXT := {
	"title": "Stash",
	"sub": "Kept safe on the train. Nothing here goes up the tower: move what you want to take into your pack, or wear it.",
	"sort": "Sort: %s",
	"slot": "%s",
	"kind": "Essence: %s",
	"any_kind": "any",
	"shown": "Showing %d of %d",
	"none_match": "Nothing in your stash matches. Change the filter to see the rest.",
	"vessels": "Vessels in your stash",
}

## The stash screen's sort and filters (Train.STASH_SORTS, SLOT_FILTERS; an
## essence kind or "all").
static var SORT := "newest"
static var SLOT := "all"
static var KIND := "all"


func default_sel() -> String:
	return ""


func build() -> void:
	var prof = _prof()
	m._header(STASH_TEXT["title"], STASH_TEXT["sub"], TEXT["eyebrow"])
	tabs("stash")
	var keys: Array = []
	# Sort and filters: each an option row (Left / Right, a click or tap on
	# either half, or press it for the next).
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	bar.set_meta("layout", "stash.bar")
	m.box.add_child(bar)
	var sorts: Array = Train.STASH_SORTS
	var kinds: Array = [["all", STASH_TEXT["any_kind"]]]
	for k in Essence.KINDS:
		kinds.append([k, Essence.display(k)])
	_cycler(bar, "sort", sorts, SORT, STASH_TEXT["sort"])
	_cycler(bar, "slot", Train.SLOT_FILTERS, SLOT, STASH_TEXT["slot"])
	_cycler(bar, "kind", kinds, KIND, STASH_TEXT["kind"])
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12 if _small() else 20)
	row.set_meta("layout", "stash.row")
	m.box.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 4)
	row.add_child(left)
	_head_label(left, TEXT["stash_head"] % [prof.chest.size(), Train.CHEST_SIZE])
	var idx := Train.sorted_indices(prof.chest, SORT, SLOT, KIND)
	var filtered: bool = SLOT != "all" or KIND != "all"
	if filtered:
		var l: Label = m._label(STASH_TEXT["shown"] % [idx.size(), prof.chest.size()] if not idx.is_empty() else STASH_TEXT["none_match"], 0.0, UI.DIM)
		l.add_theme_font_size_override("font_size", 14)
		left.add_child(l)
	var grid := GridContainer.new()
	grid.columns = 6 if _small() else 8
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	grid.set_meta("layout", "stash.grid")
	left.add_child(grid)
	var cell := 46.0 if _small() else 52.0
	for i in idx:
		keys.append(piece_cell(grid, "chest", i, cell).get_meta("slot"))
	if not filtered:
		# The empty spaces after the pieces (how much room is left).
		for i in range(prof.chest.size(), Train.CHEST_SIZE):
			keys.append(piece_cell(grid, "chest", i, cell).get_meta("slot"))
	if not prof.vessels.is_empty():
		_head_label(left, STASH_TEXT["vessels"])
		var vg := GridContainer.new()
		vg.columns = grid.columns
		left.add_child(vg)
		for i in prof.vessels.size():
			keys.append(VesselPage.slot(self, vg, "vessel:%d" % i, prof.vessels[i], cell).get_meta("slot"))
	keys.append_array(pack_strip(left))
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(right)
	card_panel(right)
	finish(keys)


## An option row for the sort or a filter: [id, name] choices, the current
## one in `fmt`.
func _cycler(parent: Node, which: String, choices: Array, current: String, fmt: String) -> void:
	var c := Cycler.new()
	c.choices = choices
	c.value = current
	c.fmt = fmt
	c.changed = _set_filter.bind(which)
	c.custom_minimum_size = Vector2(150.0 if _small() else 190.0, 34.0)
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c.set_meta("cycler", which)
	c.add_theme_font_size_override("font_size", 14 if _small() else 15)
	m._tab_look(c, current != choices[0][0])
	parent.add_child(c)


func _set_filter(value: String, which: String) -> void:
	match which:
		"sort":
			SORT = value
		"slot":
			SLOT = value
		"kind":
			KIND = value
	m.inv_sel = ""
	m._want_focus = {"meta": "cycler", "value": which}  # (the focus stays on the row: nav.gd)
	m.main.sfx("ui_move")
	m.open("stash", m.opened_direct)


# --- drawn parts ----------------------------------------------------------------

## An option row as one button: its text ("Sort: Rarity") between two small
## arrows. Left and Right (the d-pad or stick) change it; a click or tap on
## its left half goes back, on its right half forward; Enter or A goes forward.
class Cycler extends Button:
	const UI := preload("res://scripts/ui.gd")
	var choices: Array = []
	var value := ""
	var fmt := "%s"
	var changed: Callable  # (value)

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		text = "<   " + fmt % _name() + "   >"
		clip_text = true
		pressed.connect(func(): change(1))

	func _name() -> String:
		for c in choices:
			if c[0] == value:
				return String(c[1])
		return String(choices[0][1]) if not choices.is_empty() else ""

	func change(by: int) -> void:
		if choices.is_empty():
			return
		var ids: Array = choices.map(func(c): return c[0])
		value = ids[(maxi(0, ids.find(value)) + by + ids.size()) % ids.size()]
		if changed.is_valid():
			changed.call(value)

	## A click or tap at a point on screen (menu.gd sends taps here).
	func tap_at(pos: Vector2) -> void:
		var p := get_global_transform().affine_inverse() * pos
		change(-1 if p.x < size.x * 0.3 else 1)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			change(-1 if event.position.x < size.x * 0.3 else 1)
			accept_event()
