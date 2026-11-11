extends RefCounted
## The layout registry: everything on screen that Arrange mode (arrange.gd)
## can move and scale, where each one sits by default, and the arrangement
## laid over those defaults.
##
## Each element has a name ("hud.bars", "touch.attack") and a default box: an
## anchor on the screen (a corner, an edge's middle or the centre), an offset
## from it and a size. An arrangement (an "override") replaces the anchor and
## offset and adds a scale; the drawing code then asks
##
##     Layout.box("hud.bars", screen)     the arranged box
##     Layout.xform("hud.bars", screen)   default box -> arranged box
##
## and draws what it always drew under that transform, so with no overrides
## nothing moves at all. Answers are cached (per element, for the screen size
## and the arrangement's version), so asking every frame costs a lookup.
##
## Two layout sets: "desktop" (a computer) and "touch" (a phone, drawn
## bigger: ui.gd UI_SIZES), each with its own overrides; the touch buttons
## only exist in "touch".
##
## Where arrangements live (both in the same format, see to_json):
##   res://data/layout.json  the shared defaults, committed to the repository
##   user://layout.cfg       this player's own arrangement (what differs)
## Save writes user://; run from the Godot editor it also writes
## res://data/layout.json, so the owner's arrangement can be committed and
## become everyone's default (README: "Arranging the layout").
##
## Spaces: a "hud" element is measured in HUD units (the screen divided by
## the HUD size setting, as hud.gd draws its corner), a "screen" element in
## the game view's own pixels.
##
## Step 2 (menus, the rail, the train): those are built from containers,
## so they aren't registered here; arrange_ui.gd tags them as they're built
## and keeps their arrangements in these same sets, with the anchor OWN
## ("own": moved from wherever the container puts it, see arrange_ui.gd).
## Elements drawn at a fixed place can still register("id", {...}) with the
## fields ELEMENTS uses, then draw under xform() or read box().

## Anchor names, as fractions of the screen (an override's element is pinned
## by the same point of itself).
const ANCHORS := {
	"tl": Vector2(0.0, 0.0), "t": Vector2(0.5, 0.0), "tr": Vector2(1.0, 0.0),
	"l": Vector2(0.0, 0.5), "c": Vector2(0.5, 0.5), "r": Vector2(1.0, 0.5),
	"bl": Vector2(0.0, 1.0), "b": Vector2(0.5, 1.0), "br": Vector2(1.0, 1.0),
}
const ANCHOR_NAMES := {
	"tl": "top left", "t": "top", "tr": "top right", "l": "left", "c": "centre", "r": "right",
	"bl": "bottom left", "b": "bottom", "br": "bottom right", "own": "its own place",
}
## The anchor of a menu's, the rail's or the train's element (arrange_ui.gd):
## x and y are shares of the screen it moved from its built-in place.
const OWN := "own"
const SETS := ["desktop", "touch"]
const SET_NAMES := {"desktop": "computer", "touch": "phone"}
const FORMAT := 1

## Touch buttons stay tappable: at least 44 px across on the phone, which
## draws everything at least 1.5x (the Interface size Small: ui.gd UI_SIZES).
## (In the buttons' own units: see TOUCH_FIT_H.)
const MIN_TOUCH := 44.0 / 1.5
## The touch buttons were laid out for a phone view this tall (in view px)
## or taller. A bigger Interface size makes the view shorter in view px; the
## buttons and their arrangement then shrink with it to fit (touch_fit), so
## at Large and Larger they stay the size they are at Normal on the phone.
const TOUCH_FIT_H := 384.0
## Scales an arrangement may use.
const MIN_SCALE := 0.4
const MAX_SCALE := 3.0
## An arranged element keeps at least this much of itself on screen (touch
## buttons stay wholly on screen).
const KEEP_ON := 24.0

## The elements. Fields:
##   name    what Arrange mode calls it
##   space   "hud" (HUD units) or "screen" (view pixels)
##   anchor  an ANCHORS name, or a Vector2 fraction of the screen
##   pivot   the point of the box pinned there (a fraction of it; default: the anchor)
##   pos     the offset from the anchor
##   size    the box's size (plus fill * the screen, if fill is given)
##   sets    which layout sets have it (default both)
##   touch   fields that differ in the touch set
##   button  a touch button: kept on screen and at least MIN_TOUCH across
const ELEMENTS := {
	"hud.bars": {"name": "Health and stamina", "space": "hud", "anchor": "tl", "pos": Vector2(12, 10), "size": Vector2(218, 32)},
	"hud.gem": {"name": "Path gem and vessel", "space": "hud", "anchor": "tl", "pos": Vector2(234, 6), "size": Vector2(58, 36)},
	"hud.weapon": {"name": "Weapon", "space": "hud", "anchor": "tl", "pos": Vector2(16, 44), "size": Vector2(34, 34)},
	"hud.item": {"name": "Quick item", "space": "hud", "anchor": "tl", "pos": Vector2(56, 44), "size": Vector2(34, 34)},
	"hud.marks": {"name": "Marks", "space": "hud", "anchor": "tl", "pos": Vector2(96, 44), "size": Vector2(204, 34)},
	"hud.essence": {"name": "Unbanked essence", "space": "hud", "anchor": "tl", "pos": Vector2(16, 86), "size": Vector2(300, 22)},
	"hud.hints": {"name": "Key hints", "space": "hud", "anchor": "tr", "pos": Vector2(-16, 12), "size": Vector2(330, 26), "sets": ["desktop"]},
	"hud.floor": {"name": "Floor title", "space": "screen", "anchor": "t", "pos": Vector2(0, 4), "size": Vector2(420, 72)},
	"hud.banner": {"name": "New floor banner", "space": "screen", "anchor": Vector2(0.5, 0.3), "pivot": Vector2(0.5, 0.0), "pos": Vector2(0, -46), "size": Vector2(640, 128)},
	"hud.beast": {"name": "Beast's health", "space": "screen", "anchor": "t", "pos": Vector2(0, 52), "size": Vector2(600, 60)},
	"hud.plates": {"name": "Shut door and challenge", "space": "screen", "anchor": "t", "pos": Vector2(0, 67), "size": Vector2(400, 90)},
	"hud.stair": {"name": "Stair arrow's ring", "space": "screen", "anchor": "c", "pos": Vector2(0, 32), "size": Vector2(-80, -144), "fill": Vector2(1, 1)},
	"hud.entity": {"name": "The Entity's bubble", "space": "screen", "anchor": "tr", "pos": Vector2(-16, 46), "size": Vector2(330, 66),
		"touch": {"pos": Vector2(-12, 64), "size": Vector2(300, 66)}},
	"touch.stick": {"name": "Joystick zone", "space": "screen", "anchor": "tl", "pos": Vector2.ZERO, "size": Vector2.ZERO, "fill": Vector2(0.5, 1.0), "sets": ["touch"]},
}

## The touch buttons (touch.gd), laid out for the phone view: [id, name,
## anchor, centre from the anchor, radius], all times TOUCH_K. Each becomes
## the element "touch.<id>".
const TOUCH_K := 0.75
const TOUCH := [
	["attack", "Attack", "br", Vector2(-130, -130), 62.0],
	["roll", "Roll", "br", Vector2(-268, -86), 44.0],
	["jump", "Jump", "br", Vector2(-36, -36), 30.0],
	["parry", "Parry", "br", Vector2(-150, -278), 42.0],
	["weapon", "Swap", "br", Vector2(-290, -330), 28.0],
	["fullscreen", "Fullscreen", "tr", Vector2(-40, 40), 24.0],
	["menu", "Menu", "tr", Vector2(-104, 40), 28.0],
	["climber", "Climber", "tr", Vector2(-172, 40), 26.0],
	["inventory", "Bag", "tr", Vector2(-236, 40), 26.0],
	["item", "Item", "br", Vector2(-395, -48), 34.0],
	["item_next", "Next item", "br", Vector2(-478, -48), 22.0],
	["take", "Take", "br", Vector2(-400, -372), 34.0],
	["tools", "Tools", "br", Vector2(-505, -235), 28.0],
	# One cast button per mark you carry, in these spots, in body order.
	["mark_1", "Mark button 1", "br", Vector2(-282, -222), 34.0],
	["mark_2", "Mark button 2", "br", Vector2(-52, -262), 34.0],
	["mark_3", "Mark button 3", "br", Vector2(-48, -368), 34.0],
	["mark_4", "Mark button 4", "br", Vector2(-405, -150), 34.0],
	["mark_5", "Mark button 5", "br", Vector2(-160, -400), 34.0],
	["mark_6", "Mark button 6", "br", Vector2(-395, -265), 34.0],
]

const TestRun := preload("res://scripts/test_run.gd")
## Where the arrangements are kept (tests point these elsewhere).
const PROJECT_PATH := "res://data/layout.json"
const USER_PATH := "user://layout.cfg"
static var project_path := PROJECT_PATH
static var user_path := USER_PATH
## Save also writes the shared defaults (true when run from the editor).
static var write_project := false

## Bumped on every change: what draws from the layout redraws when it moves.
static var version := 0
## The set in use ("desktop" or "touch"; touch.gd switches it).
static var active_set := "desktop"

static var _defs := {}  # id -> normalised definition
static var _order: Array = []  # ids, in registration order
static var _over := {"desktop": {}, "touch": {}}  # the arrangement in use
static var _shared := {"desktop": {}, "touch": {}}  # res://data/layout.json
static var _saved := {"desktop": {}, "touch": {}}  # as last saved or loaded
static var _cache := {}  # id -> [version, set, screen, default box, box, xform]
static var _loaded := false


# --- the registry ---------------------------------------------------------------

static func _ensure_defs() -> void:
	if not _defs.is_empty():
		return
	for id in ELEMENTS:
		_add(id, ELEMENTS[id])
	for row in TOUCH:
		var c: Vector2 = row[3] * TOUCH_K
		var r: float = row[4] * TOUCH_K
		var a: Vector2 = ANCHORS[row[2]]
		# (the box around the button's circle, pinned by its anchor's corner)
		_add("touch." + row[0], {"name": row[1], "space": "screen", "anchor": row[2], "pos": c - Vector2(r, r) + 2.0 * r * a,
			"size": Vector2(r, r) * 2.0, "sets": ["touch"], "button": true})


static func _add(id: String, d: Dictionary) -> void:
	var n := {
		"id": id, "name": String(d.get("name", id)), "space": String(d.get("space", "screen")),
		"sets": d.get("sets", SETS), "button": bool(d.get("button", false)),
	}
	for s in SETS:
		var src: Dictionary = d.duplicate()
		if s == "touch" and d.has("touch"):
			src.merge(d["touch"], true)
		var anchor = src.get("anchor", "tl")
		var av: Vector2 = ANCHORS.get(anchor, Vector2.ZERO) if anchor is String else anchor
		n[s] = {"anchor": av, "pivot": src.get("pivot", av), "pos": src.get("pos", Vector2.ZERO),
			"size": src.get("size", Vector2.ZERO), "fill": src.get("fill", Vector2.ZERO)}
	if not _defs.has(id):
		_order.append(id)
	_defs[id] = n


## Adds (or replaces) an element at run time, with the fields ELEMENTS uses
## (step 2: the menus, the rail and the train register theirs).
static func register(id: String, d: Dictionary) -> void:
	_ensure_defs()
	_add(id, d)
	version += 1


static func has(id: String) -> bool:
	_ensure_defs()
	return _defs.has(id)


static func def(id: String) -> Dictionary:
	_ensure_defs()
	return _defs.get(id, {})


static func display_name(id: String) -> String:
	return String(def(id).get("name", id))


## The elements a set has, in order.
static func ids(set_name := "") -> Array:
	_ensure_defs()
	var s := set_name if set_name != "" else active_set
	return _order.filter(func(id): return s in _defs[id]["sets"])


static func is_button(id: String) -> bool:
	return bool(def(id).get("button", false))


static func space(id: String) -> String:
	return String(def(id).get("space", "screen"))


## How big an element's units are on the view (the HUD size setting for HUD elements).
static func space_scale(id: String, hud_scale: float) -> float:
	return hud_scale if space(id) == "hud" else 1.0


## The screen measured in an element's units.
static func space_size(id: String, view: Vector2, hud_scale: float) -> Vector2:
	return view / space_scale(id, hud_scale)


static func use_set(set_name: String) -> void:
	if set_name != active_set and set_name in SETS:
		active_set = set_name
		version += 1


# --- asking where things are -------------------------------------------------------

## The arranged box (in the element's units) on a screen of this size.
static func box(id: String, screen: Vector2) -> Rect2:
	return _entry(id, screen)[4]


## The box with no arrangement (today's layout).
static func default_box(id: String, screen: Vector2) -> Rect2:
	return _entry(id, screen)[3]


## Maps the default box onto the arranged box: draw under it, or put a
## default-layout rect or point through it.
static func xform(id: String, screen: Vector2) -> Transform2D:
	return _entry(id, screen)[5]


## True if the element has an arrangement in the set in use.
static func moved(id: String) -> bool:
	return _over[active_set].has(id)


## How much a touch button's layout shrinks to fit a short view (see
## TOUCH_FIT_H): its default box, its arrangement and its smallest size are
## all measured on the view divided by this, then scaled by it.
static func touch_fit(id: String, screen: Vector2) -> float:
	if active_set != "touch" or not is_button(id) or screen.y <= 0.0:
		return 1.0
	return minf(1.0, screen.y / TOUCH_FIT_H)


static func _entry(id: String, screen: Vector2) -> Array:
	var e = _cache.get(id)
	if e != null and e[0] == version and e[2] == screen and e[1] == active_set:
		return e
	_ensure_defs()
	if e == null:
		e = [0, "", Vector2.ZERO, Rect2(), Rect2(), Transform2D.IDENTITY]
		_cache[id] = e
	e[0] = version
	e[1] = active_set
	e[2] = screen
	var d: Dictionary = _defs.get(id, {})
	if d.is_empty():
		e[3] = Rect2()
		e[4] = Rect2()
		e[5] = Transform2D.IDENTITY
		return e
	var dd: Dictionary = d[active_set]
	# (a touch button on a short view: laid out on the view / k, then scaled by k)
	var k := touch_fit(id, screen)
	var sc := screen / k
	var base: Vector2 = dd["size"] + sc * dd["fill"]
	var def_box := Rect2(sc * dd["anchor"] + dd["pos"] - base * dd["pivot"], base)
	e[3] = Rect2(def_box.position * k, def_box.size * k)
	var ov = _over[active_set].get(id)
	if ov == null:
		e[4] = e[3]
		e[5] = Transform2D.IDENTITY
		return e
	var a: Vector2 = ANCHORS.get(String(ov.get("anchor", "tl")), Vector2.ZERO)
	var s := clampf(float(ov.get("scale", 1.0)), min_scale(id, screen), MAX_SCALE)
	var size := base * s
	var r := Rect2(sc * a + Vector2(float(ov.get("x", 0.0)), float(ov.get("y", 0.0))) - size * a, size)
	r = _keep_on(r, sc, bool(d["button"]))
	r = Rect2(r.position * k, r.size * k)
	e[4] = r
	e[5] = Transform2D(0.0, Vector2(s, s), 0.0, r.position - e[3].position * s)
	return e


## The smallest scale an element may take (a touch button stays tappable).
static func min_scale(id: String, screen: Vector2) -> float:
	var d := def(id)
	if d.is_empty():
		return MIN_SCALE
	var dd: Dictionary = d[active_set]
	var base: Vector2 = dd["size"] + screen / touch_fit(id, screen) * dd["fill"]
	var lo := MIN_SCALE
	if bool(d["button"]) and base.x > 0.0:
		lo = maxf(lo, MIN_TOUCH / base.x)
	return lo


## Keeps an arranged box on screen: at least KEEP_ON of it, or all of a button.
static func _keep_on(r: Rect2, screen: Vector2, whole: bool) -> Rect2:
	var keep := r.size if whole else Vector2(minf(KEEP_ON, r.size.x), minf(KEEP_ON, r.size.y))
	keep = keep.min(screen)
	r.position.x = clampf(r.position.x, keep.x - r.size.x, screen.x - keep.x)
	r.position.y = clampf(r.position.y, keep.y - r.size.y, screen.y - keep.y)
	return r


# --- arranging -------------------------------------------------------------------

## Puts an element at this box (its units, on this screen): pinned by the
## anchor nearest its centre, so it keeps its place on other screen sizes.
static func move_to(id: String, r: Rect2, screen: Vector2) -> void:
	var d := def(id)
	if d.is_empty():
		return
	var dd: Dictionary = d[active_set]
	# (a touch button on a short view: back into its own units, see touch_fit)
	var k := touch_fit(id, screen)
	r = Rect2(r.position / k, r.size / k)
	screen = screen / k
	var base: Vector2 = dd["size"] + screen * dd["fill"]
	var s := r.size.x / base.x if base.x > 0.0 else (r.size.y / base.y if base.y > 0.0 else 1.0)
	s = clampf(s, min_scale(id, screen), MAX_SCALE)
	var size := base * s
	var c := r.get_center()
	var col := "l" if c.x < screen.x / 3.0 else ("r" if c.x > screen.x * 2.0 / 3.0 else "")
	var row := "t" if c.y < screen.y / 3.0 else ("b" if c.y > screen.y * 2.0 / 3.0 else "")
	var name := row + col if row + col != "" else "c"
	var a: Vector2 = ANCHORS[name]
	# (scaled about the box's centre if the size was clamped)
	var at := c - size * 0.5
	var p := at + size * a - screen * a
	set_override(id, {"anchor": name, "x": snappedf(p.x, 0.1), "y": snappedf(p.y, 0.1), "scale": snappedf(s, 0.001)})


static func set_override(id: String, ov: Dictionary) -> void:
	_over[active_set][id] = ov.duplicate()
	version += 1


static func get_override(id: String):
	return _over[active_set].get(id)


## Back to the default for one element (the shared default, if it has one).
static func reset(id: String) -> void:
	var to = _reset_target().get(active_set, {}).get(id)
	if to == null:
		_over[active_set].erase(id)
	else:
		_over[active_set][id] = to.duplicate()
	version += 1


## Back to the defaults for every element of the set in use.
static func reset_all() -> void:
	_over[active_set] = _reset_target().get(active_set, {}).duplicate(true)
	version += 1


## What Reset goes back to: the shared defaults; run from the editor (where
## Save writes those defaults) the built-in layout.
static func _reset_target() -> Dictionary:
	return {} if write_project else _shared


## The whole arrangement (both sets), for Undo.
static func snapshot() -> Dictionary:
	return _over.duplicate(true)


static func restore(snap: Dictionary) -> void:
	_over = {"desktop": snap.get("desktop", {}).duplicate(true), "touch": snap.get("touch", {}).duplicate(true)}
	version += 1


## True if the arrangement differs from what was last saved (or loaded).
static func dirty() -> bool:
	return _over != _saved


## Forgets changes since the last save.
static func revert() -> void:
	restore(_saved)


# --- the file format --------------------------------------------------------------

## The arrangement as JSON, the format of res://data/layout.json:
##   {"format": 1, "desktop": {"hud.bars": {"anchor": "tl", "x": 12, "y": 10, "scale": 1}}, "touch": {...}}
## x and y are the offset of the element's anchor point from the screen's
## (in the element's units: HUD units for "hud." elements, view pixels
## otherwise); scale multiplies its size. A menu's, the rail's or the
## train's element (anchor "own", arrange_ui.gd) has x and y as shares of the
## screen it moved from its built-in place, and maybe "w" / "h" (resized).
static func to_json(over = null) -> String:
	var src: Dictionary = _over if over == null else over
	var out := {"format": FORMAT}
	for s in SETS:
		var set_d := {}
		var keys: Array = src.get(s, {}).keys()
		keys.sort()
		for id in keys:
			set_d[id] = _clean(src[s][id])
		out[s] = set_d
	return JSON.stringify(out, "\t", true)


## Reads the JSON format; the parsed arrangement, or null if it isn't one.
static func parse(text: String):
	var j := JSON.new()
	if j.parse(text) != OK:
		return null
	var data = j.data
	if not (data is Dictionary):
		return null
	var out := {"desktop": {}, "touch": {}}
	for s in SETS:
		var set_d = data.get(s, {})
		if not (set_d is Dictionary):
			return null
		for id in set_d:
			var ov = set_d[id]
			if not (ov is Dictionary):
				return null
			if bool(ov.get("reset", false)):
				out[s][id] = {"reset": true}
				continue
			if not _anchor_ok(ov):
				return null
			out[s][id] = _clean(ov)
	return out


## Uses an arrangement given as JSON (as Copy layout gives it). False if it isn't one.
static func load_json(text: String) -> bool:
	var o = parse(text)
	if o == null:
		return false
	for s in SETS:
		for id in o[s].keys():
			if bool(o[s][id].get("reset", false)):
				o[s].erase(id)
	restore(o)
	return true


static func _anchor_ok(ov: Dictionary) -> bool:
	var a := String(ov.get("anchor", ""))
	return ANCHORS.has(a) or a == OWN


static func _clean(ov: Dictionary) -> Dictionary:
	if bool(ov.get("reset", false)):
		return {"reset": true}
	if String(ov.get("anchor", "")) == OWN:
		# (a menu's, the rail's or the train's element: shares of the screen,
		# and a resized one's width or height as a share of its own)
		var o := {"anchor": OWN, "x": snappedf(float(ov.get("x", 0.0)), 0.0001), "y": snappedf(float(ov.get("y", 0.0)), 0.0001),
			"scale": snappedf(float(ov.get("scale", 1.0)), 0.001)}
		for k in ["w", "h"]:
			if ov.has(k) and absf(float(ov[k]) - 1.0) > 0.0005:
				o[k] = snappedf(float(ov[k]), 0.001)
		return o
	return {"anchor": String(ov.get("anchor", "tl")), "x": snappedf(float(ov.get("x", 0.0)), 0.1),
		"y": snappedf(float(ov.get("y", 0.0)), 0.1), "scale": snappedf(float(ov.get("scale", 1.0)), 0.001)}


# --- loading and saving ------------------------------------------------------------

## Loads the shared defaults and this player's arrangement (once; main.gd).
## Tests load only the shared defaults.
static func ensure_loaded(tests := false) -> void:
	if _loaded:
		return
	_loaded = true
	write_project = OS.has_feature("editor") and not tests
	if tests and user_path == USER_PATH:
		user_path = TestRun.path("user://smoke_layout.cfg")  # (tests never touch the real one)
	load_all(not tests)


static func load_all(with_user := true) -> void:
	_shared = {"desktop": {}, "touch": {}}
	if FileAccess.file_exists(project_path):
		var o = parse(FileAccess.get_file_as_string(project_path))
		if o != null:
			_shared = o
	var over: Dictionary = _shared.duplicate(true)
	if with_user:
		var cfg := ConfigFile.new()
		if cfg.load(user_path) == OK:
			for s in SETS:
				var mine = cfg.get_value("layout", s, {})
				if not (mine is Dictionary):
					continue
				for id in mine:
					var ov = mine[id]
					if not (ov is Dictionary):
						continue
					if bool(ov.get("reset", false)):
						over[s].erase(id)
					elif _anchor_ok(ov):
						over[s][id] = _clean(ov)
	for s in SETS:  # ("reset" marks only mean something over the shared defaults)
		for id in over[s].keys():
			if bool(over[s][id].get("reset", false)):
				over[s].erase(id)
	_over = over
	_saved = _over.duplicate(true)
	version += 1


## Saves the arrangement: this player's to user://, and (run from the
## editor) the shared defaults to res://data/layout.json as well.
## Returns {"user": ok, "project": ok, or null when it isn't written}.
static func save() -> Dictionary:
	var out := {"user": false, "project": null}
	if write_project:
		var f := FileAccess.open(project_path, FileAccess.WRITE)
		out["project"] = f != null
		if f != null:
			f.store_string(to_json() + "\n")
			f.close()
			_shared = _over.duplicate(true)
	var cfg := ConfigFile.new()
	cfg.set_value("layout", "format", FORMAT)
	for s in SETS:
		cfg.set_value("layout", s, _mine(s))
	out["user"] = cfg.save(user_path) == OK
	_saved = _over.duplicate(true)
	return out


## What this player's arrangement changes from the shared defaults.
static func _mine(s: String) -> Dictionary:
	var out := {}
	for id in _over[s]:
		if _shared[s].get(id) != _over[s][id]:
			out[id] = _clean(_over[s][id])
	for id in _shared[s]:
		if not _over[s].has(id):
			out[id] = {"reset": true}
	return out


## Everything back to the built-in layout and nothing saved (tests).
static func clear_state() -> void:
	_over = {"desktop": {}, "touch": {}}
	_shared = {"desktop": {}, "touch": {}}
	_saved = {"desktop": {}, "touch": {}}
	version += 1
