extends RefCounted
## One look for your pack and your stash, wherever they show: the Stash tab,
## the Loadout, your car on the train, the outfitter's Sell counter, the
## workshop bench's pickers and the inventory's Pack view in the tower.
##
## There is one stash (profile.chest, Train.CHEST_SIZE spaces) and one pack,
## so every place shows them through build(): the same heading ("Stash · 12
## of 40", "Pack · 2 of 4"), the same grid (cell(), columns(), GAP), the
## same slots (menu.gd Slot: the rarity's edge, a wear bar, the green or red
## arrow against what you wear, "Pack" on a piece you'll put on as you set
## off) and the same empty spaces. A place short of room shows the first
## rows of that grid (`rows`) and the Open the stash button; a place that
## offers only some pieces (selling, a bench counter, the Loadout's best)
## passes which (`indices`) and leaves out the empty spaces.
##
## Choosing a piece shows the same card everywhere (loadout_page.gd
## piece_card), and pressing a chosen piece again moves it across (menu.gd
## _slot_pressed). The words live in TEXT (the Data editor: "The train and
## store").

const Train := preload("res://scripts/train.gd")
const Gear := preload("res://scripts/gear.gd")
const UI := preload("res://scripts/ui.gd")

static var TEXT := {
	"pack": "Pack  ·  %d of %d",
	"stash": "Stash  ·  %d of %d",
	"open_stash": "Open the stash",
	"open_stash_more": "Open the stash  ·  %d more",
	"tag_pack": "Pack",
	"empty_space": "Empty space",
}

## The gap between slots.
const GAP := 5


## A slot's side: smaller on a short screen (a phone).
static func cell(small: bool) -> float:
	return 46.0 if small else 52.0


## How many slots across (reflow.gd takes columns off where a screen is narrower).
static func columns(small: bool) -> int:
	return 6 if small else 8


## The heading's words: "Stash · 12 of 40".
static func heading(where: String, have: int, room: int) -> String:
	return TEXT["stash" if where == "chest" else "pack"] % [have, room]


## A heading over a grid (a small gilt label, outlined so it reads on the
## train's furniture too).
static func head(parent: Node, text: String, small: bool) -> Label:
	var l := Label.new()
	l.text = text
	UI.style_label(l, "eyebrow", UI.SIZE_EYEBROW + (0 if small else 1), UI.GOLD)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("outline_size", 3)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.set_meta("storage_head", true)
	parent.add_child(l)
	return l


## The stash's pieces in the order the Stash tab shows them (its sort), no filter.
static func stash_order(page) -> Array:
	return Train.sorted_indices(page._prof().chest, page.m.stash_page.SORT)


## Builds the pack or the stash into `parent`: its heading and its grid.
## `page`: the screen building it (it has m, _prof(), _player(), _small()).
## `where`: "pack" or "chest" (the stash). `opts`:
##   "list", "room"   the pieces and how many spaces (the tower's pack: the
##                    player's own; else the profile's)
##   "indices"        which pieces, in order (else the pack in order, the
##                    stash in the Stash tab's order)
##   "empties"        the empty spaces after them (true unless "indices" is given)
##   "rows"           at most this many rows (0: all)
##   "columns"        slots across (else columns())
##   "key"            the slots' keys' start (else `where`: "chest:3")
##   "versus"         a Callable(piece) -> int for the arrow (else against what you'd wear)
##   "decor"          a Callable(slot, i) run on each filled slot (a price on it)
##   "head"           false for no heading; "head_text" for other words
##   "layout"         the grid's name in Arrange mode
## Returns {"keys", "grid", "head", "hidden" (pieces left out by "rows"), "shown"}.
static func build(page, parent: Node, where: String, opts := {}) -> Dictionary:
	var prof = page._prof()
	var small: bool = page._small()
	var stash := where == "chest"
	var list: Array = opts.get("list", prof.chest if stash else prof.pack)
	var room: int = int(opts.get("room", Train.CHEST_SIZE if stash else page._player().pack_size()))
	var given: bool = opts.has("indices")
	var idx: Array = opts["indices"] if given else (Train.sorted_indices(list, page.m.stash_page.SORT) if stash else range(list.size()))
	var empties: bool = opts.get("empties", not given)
	var cols: int = int(opts.get("columns", columns(small)))
	var side := cell(small)
	var out := {"keys": [], "grid": null, "head": null, "hidden": 0, "shown": 0}
	if opts.get("head", true):
		out["head"] = head(parent, opts.get("head_text", heading(where, list.size(), room)), small)
	var grid := GridContainer.new()
	grid.columns = cols
	grid.add_theme_constant_override("h_separation", GAP)
	grid.add_theme_constant_override("v_separation", GAP)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	grid.set_meta("storage", where)
	if opts.has("layout"):
		grid.set_meta("layout", opts["layout"])
	parent.add_child(grid)
	out["grid"] = grid
	# What to show: the pieces, then the empty spaces, up to `rows` rows.
	var cells: Array = idx.duplicate()
	if empties:
		for i in range(list.size(), maxi(room, list.size())):
			cells.append(i)
	var most: int = cells.size()
	var rows := int(opts.get("rows", 0))
	if rows > 0:
		most = mini(most, rows * cols)
	var prefix: String = opts.get("key", where)
	# Pack pieces you'll put on as you set off (nothing else worn there) say so.
	var auto := {}
	if not stash and not opts.has("list"):
		for e in Train.setoff(prof, page._player()).values():
			if e["from"] == "pack":
				auto[int(e.get("i", -1))] = true
	for n in most:
		var i: int = cells[n]
		var g = list[i] if i < list.size() else null
		var s = page.m._slot(grid, "%s:%d" % [prefix, i], side, "")
		s.kind = "gear"
		s.id = Gear.base_id(g) if g != null else ""
		s.rec = g
		s.empty = g == null
		s.tint = Gear.color(g) if g != null else UI.FAINT
		s.wear = Gear.condition(g) if g != null and Gear.wears(g) else -1.0
		if g != null:
			s.better = signi(opts["versus"].call(g) if opts.has("versus") else Train.versus(prof, page._player(), g))
			if auto.has(i):
				s.tag = TEXT["tag_pack"]
			if opts.has("decor"):
				opts["decor"].call(s, i)
			out["shown"] += 1
		out["keys"].append(s.get_meta("slot"))
	out["hidden"] = idx.size() - mini(idx.size(), most)
	return out


## The button to the Stash tab, under a stash that shows only its first rows.
static func open_button(page, parent: Node, hidden: int, action: Callable) -> Button:
	var b: Button = page.m._button(TEXT["open_stash_more"] % hidden if hidden > 0 else TEXT["open_stash"], action, parent)
	b.custom_minimum_size.y = 36.0
	b.set_meta("open_stash", true)
	return b
