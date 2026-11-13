extends RefCounted
## Arrange mode's live elements (step 2): the menus, the left rail and the
## train's furniture, which are built from Godot's own controls (laid out by
## containers) rather than drawn at a fixed place like the HUD (layout.gd).
##
## Arrange mode shows them a level at a time (arrange.gd): parent_of() says
## which block a block sits in, friendly() what it's called (NAMES, or a name
## made from its kind and the first words on it) and offered() whether it's
## worth showing at all.
##
## Nothing here needs each page to know about it. After a page is built
## (menu.gd open), tag_page() walks it and tags what can be arranged, each
## with a stable name made of the page and the element:
##   menu.<page>.panel              the page's panel (shared by its tabs)
##   menu.<page>[.<tab>].title      the heading (menu.gd _header)
##   menu.<page>[.<tab>].row2       a row, grid, column, text... (2nd of its kind)
##   menu.<page>.row1.column2       a column inside a row
##   menu.<page>.row1.column2.card1 a card (a panel or a big drawn piece) inside it
##   rail.box / rail.ident / rail.list / rail.foot   the left rail (rail.gd)
##   train.<car>.<kind><n>          a car's furniture and placards (train_page.gd)
## so every page, a new one too, gets its boxes.
##
## An element's built-in place is wherever its container puts it. Its
## arrangement (in layout.gd's sets, saved with the rest to
## data/layout.json) is {"anchor": "own", "x", "y", "scale"} and, for the
## few that can be resized, "w" / "h": x and y move it from its built-in
## place by that share of the screen's width and height (so a layout made on
## a computer keeps its proportions on a phone), scale grows it about its
## centre, and an arranged element is kept inside its frame (the screen for a
## page's panel, the page for what's on it, the rail, or the car). After its
## container lays it out (sort_children), the arrangement is put on top: its
## position and scale. With no arrangement nothing is touched, so an empty
## data/layout.json is exactly today's look.
##
## The phone's set falls back on the computer's for these (a menu arranged
## on the computer is arranged on the phone too, unless the phone's own
## layout moves it again).

const Layout := preload("res://scripts/layout.gd")
const TrainView := preload("res://scripts/train_view.gd")
const Book := preload("res://scripts/book.gd")
const Train := preload("res://scripts/train.gd")

## Off: nothing is tagged (tests build a page without it to compare).
static var enabled := true

## The pages' names in Arrange mode.
const PAGE_NAMES := {
	"pause": "Pause menu", "settings": "Settings", "controls": "Controls", "climber": "Climber book",
	"inventory": "Inventory", "mark": "Mark page", "library": "Library", "dev": "Dev tools",
	"data": "Edit game data", "appearance": "Appearance", "techniques": "Techniques",
	"climbers": "Climbers", "confirm_new": "Start over", "padsetup": "Controller setup", "train": "Train", "station": "Station",
}
## Pages never arranged (the title has its own picture; the painter and a
## new climber's look have their own screens).
const SKIP_PAGES := ["title", "painter", "create"]
## What each kind of element is called.
const KIND_NAMES := {
	"panel": "Page panel", "title": "Title", "tabs": "Tabs", "ribbons": "Ribbons", "footer": "Back button",
	"row": "Row", "grid": "Grid", "column": "Column", "text": "Text", "card": "Card", "button": "Button",
	"part": "Piece", "foot": "Bottom row",
}
## The train's furniture (train_view.gd Furnish kinds) and pieces.
const FURNISH_NAMES := {
	"rack": "Heirloom wardrobe", "pack": "Pack", "chest": "Stash", "shelf": "Shelves",
	"rail": "Outfit rail", "case": "Glass case", "board": "Tower board", "drawers": "Bench drawers",
	"placard": "Placard", "plain": "Panel", "bookcase": "Bookcase", "lectern": "Lectern",
	"signal": "Signal panel", "brake": "Emergency brake", "book": "Book on its cushion",
	"bench": "The bench", "outfitter": "The outfitter", "speech": "Speech", "sign": "Sign", "piece": "Piece",
}
const RAIL_NAMES := {
	"rail.box": "Left rail", "rail.ident": "Who you are", "rail.list": "List of pages or cars", "rail.foot": "Bottom buttons",
}
## Friendly names for blocks, by id: what Arrange mode's list, labels and
## breadcrumb call them. A key starting with "*" names every block whose id
## ends that way ("*.title": each page's title). A block without one is named
## from its kind and the first words on it (_auto_name), so new pages get
## names too; add a line here to give one a better name.
const NAMES := {
	"*.title": "Title",
	"*.tabs": "Tabs",
	"*.ribbons": "Tab ribbons",
	"menu.inventory.row1.column1": "Left side: what you carry",
	"menu.inventory.row1.column2": "Right side: the details",
	"menu.inventory.row1.column2.card1": "Item details card",
	"menu.pause.grid1": "Main buttons",
	"menu.pause.grid2": "Restart button",
	"menu.appearance.row1.column1": "Left side: the preview",
	"menu.appearance.row1.column1.card1": "Preview of your climber",
	"menu.appearance.row1.column2": "Right side: the choices",
	"menu.controls.grid1": "List of controls",
	"menu.climbers.grid1": "Climber cards",
	"menu.settings.settings.row1": "The Entity's words",
	"menu.climbers.row1": "The Entity's words",
}
## What's special about arranging a block, said under its name when it's chosen.
const HOW := {
	"rail.box": "It stays at the left edge. Pull the blue bar on its right edge to change its width; the wheel (or [ and ]) changes its text size.",
	"rail.list": "Pull the blue bar on its bottom edge to spread the list out or close it up.",
	"*.panel": "Pull a blue bar on its side to make the page wider or narrower.",
}
## A card: a panel or a drawn piece at least this big (px).
const CARD_MIN := Vector2(90, 56)
## At most this many elements on a page.
const MAX_PER_PAGE := 120
## Resizing stays within these factors.
const MIN_FACTOR := 0.5
const MAX_FACTOR := 2.0

static var _index := {}  # id -> WeakRef of the Control
static var _page: Array = []  # ids on the page showing, in order (tag_page)


# --- tagging ---------------------------------------------------------------------

## Tags a control as an arrangeable element. `caps`: "move", "scale" (both
## default true), "x" / "y" (it can be resized across / down), "inside" (its
## scale works inside it: the box keeps its size), "via" (its parent is
## moved instead: the page's panel moves its CenterContainer). `frame`: the
## control it's kept inside (null: the screen).
## `name`: its friendly name (NAMES can give a better one); `kind`: what kind
## of thing it is (KIND_NAMES, FURNISH_NAMES); `where`: the page or car it's
## on, for its full name.
static func tag(c: Control, id: String, name: String, caps := {}, frame: Control = null, group := "", kind := "", where := "") -> void:
	if not enabled or c == null:
		return
	var d := {"id": id, "name": name, "caps": caps, "frame": frame, "group": group, "kind": kind, "where": where}
	var had: bool = c.has_meta("arr") and String(c.get_meta("arr")["id"]) == id
	c.set_meta("arr", d)
	_index[id] = weakref(c)
	if not had or not c.has_meta("arr_base"):
		c.set_meta("arr_base", Rect2(c.position, c.size))
	_hook(c)
	_page.append(id)


static func untag(c: Control) -> void:
	if c != null and c.has_meta("arr"):
		var id := String(c.get_meta("arr")["id"])
		var w = _index.get(id)
		if w != null and w.get_ref() == c:
			_index.erase(id)
		c.remove_meta("arr")


## Listens for the container laying the element out (once per container:
## a wrapped row, reflow.gd, is a new container).
static func _hook(c: Control) -> void:
	var p := c.get_parent()
	if not (p is Container):
		return
	if int(p.get_meta("arr_hooked", 0)) == p.get_instance_id():
		return
	p.set_meta("arr_hooked", p.get_instance_id())
	var cont: Container = p
	cont.sort_children.connect(func(): _sorted(cont))


## A container laid out its children: their built-in places, then the arrangement on top.
static func _sorted(p: Container) -> void:
	for c in p.get_children():
		if c is Control and c.has_meta("arr"):
			c.set_meta("arr_base", Rect2(c.position, c.size))
			var id := String(c.get_meta("arr")["id"])
			var w = _index.get(id)
			if w == null or w.get_ref() != c:
				_index[id] = weakref(c)  # (a row wrapped by reflow.gd: its copy)
			_apply(c)


static func has(id: String) -> bool:
	return node(id) != null


static func node(id: String) -> Control:
	var w = _index.get(id)
	if w == null:
		return null
	var c = w.get_ref()
	if c == null or not is_instance_valid(c) or not c.is_inside_tree() or c.is_queued_for_deletion() or not c.has_meta("arr"):
		return null
	return c


static func info(id: String) -> Dictionary:
	var c := node(id)
	return c.get_meta("arr") if c != null else {}


## The full name: where it is, then what it is ("Inventory: Title").
static func display_name(id: String) -> String:
	var where := String(info(id).get("where", ""))
	return friendly(id) if where == "" else "%s: %s" % [where, friendly(id)]


## The friendly name: NAMES' (by id, or by the id's ending), else the one it
## was tagged with.
static func friendly(id: String) -> String:
	var n := _lookup(NAMES, id)
	return n if n != "" else String(info(id).get("name", id))


## What's special about arranging it (HOW), or "".
static func how(id: String) -> String:
	return _lookup(HOW, id)


static func _lookup(table: Dictionary, id: String) -> String:
	if table.has(id):
		return String(table[id])
	var cut := id.rfind(".")
	if cut > 0 and table.has("*" + id.substr(cut)):
		return String(table["*" + id.substr(cut)])
	return ""


static func kind_of(id: String) -> String:
	return String(info(id).get("kind", ""))


## The block a block sits in: the nearest tagged thing around it (one of
## `among`, if given), or "" if it stands on the screen itself.
static func parent_of(id: String, among := {}) -> String:
	var c := node(id)
	if c == null:
		return ""
	var p := c.get_parent()
	while p != null:
		if p is Control and p.has_meta("arr"):
			var pid := String(p.get_meta("arr")["id"])
			if node(pid) == p and (among.is_empty() or among.has(pid)):
				return pid
		p = p.get_parent()
	return ""


## Worth offering in Arrange mode: big enough to grab and, on a page that
## scrolls, not scrolled out of sight (something already arranged is always
## offered, so it can be put back).
static func offered(id: String) -> bool:
	var c := node(id)
	if c == null:
		return false
	var r := rect(id)
	if r.size.x < 12.0 or r.size.y < 10.0:
		return false
	if override(id) != null:
		return true
	var f = c.get_meta("arr")["frame"]
	if f is ScrollContainer and is_instance_valid(f) and f.is_inside_tree() and f.clip_contents and f.is_ancestor_of(c):
		var seen: Rect2 = r.intersection(f.get_global_rect())
		return seen.get_area() >= r.get_area() * 0.5
	return true


static func cap(id: String, what: String) -> bool:
	var caps: Dictionary = info(id).get("caps", {})
	return bool(caps.get(what, what == "move" or what == "scale"))


# --- the arrangement ----------------------------------------------------------------

## The element's arrangement: the set in use's, or (on the phone) the computer's.
static func override(id: String):
	var ov = Layout.get_override(id)
	if ov == null and Layout.active_set == "touch":
		ov = Layout._over["desktop"].get(id)
	if ov != null and String(ov.get("anchor", "")) != Layout.OWN:
		return null
	return ov


static func factor(id: String, axis: String) -> float:
	var ov = override(id)
	return clampf(float(ov.get(axis, 1.0)), MIN_FACTOR, MAX_FACTOR) if ov != null else 1.0


## The view (the screen in view px) a control is on.
static func _view(c: Control) -> Vector2:
	return c.get_viewport_rect().size if c != null and c.is_inside_tree() else Vector2(1280, 720)


## The built-in box as laid out (with any resizing), on the screen.
static func _laid(c: Control) -> Rect2:
	var base: Rect2 = c.get_meta("arr_base", Rect2(c.position, c.size))
	var d: Dictionary = c.get_meta("arr")
	var p: Transform2D
	if bool(d["caps"].get("via", false)):
		var holder := c.get_parent() as Control
		var home: Vector2 = holder.get_meta("arr_home", holder.position)
		var up := holder.get_parent() as CanvasItem
		p = (up.get_global_transform() if up != null else Transform2D.IDENTITY) * Transform2D(0.0, home)
	elif bool(d["caps"].get("self", false)):
		p = (c.get_parent() as CanvasItem).get_global_transform() if c.get_parent() is CanvasItem else Transform2D.IDENTITY
		base = Rect2(c.position, c.size)
	else:
		p = (c.get_parent() as CanvasItem).get_global_transform() if c.get_parent() is CanvasItem else Transform2D.IDENTITY
	return Rect2(p * base.position, p.get_scale() * base.size)


## The box with nothing arranged (its resizing taken off), on the screen.
static func default_rect(id: String) -> Rect2:
	var c := node(id)
	if c == null:
		return Rect2()
	var r := _laid(c)
	var ex: Rect2 = c.get_meta("arr_extra", Rect2())
	return Rect2(r.position - ex.position, r.size - ex.size)


## The box at scale 1 (resized as arranged), on the screen.
static func base_rect(id: String) -> Rect2:
	var c := node(id)
	return _laid(c) if c != null else Rect2()


## The frame an arranged element stays in (on the screen).
static func frame_rect(id: String) -> Rect2:
	var c := node(id)
	if c == null:
		return Rect2()
	var f = c.get_meta("arr")["frame"]
	var view := Rect2(Vector2.ZERO, _view(c))
	if f is ScrollContainer and is_instance_valid(f) and f.is_inside_tree() and f.has_meta("arr_page"):
		# A menu's page: the screen, or (a page that scrolls, so it clips)
		# across only as far as the page.
		if not f.clip_contents:
			return view
		var g: Rect2 = f.get_global_rect()
		return Rect2(g.position.x, view.position.y, g.size.x, view.size.y)
	if f is Control and is_instance_valid(f) and f.is_inside_tree():
		return f.get_global_rect()
	return view


## Where it is, arranged, on the screen: [rect, scale it's drawn at].
static func _arranged(id: String) -> Array:
	var c := node(id)
	if c == null:
		return [Rect2(), 1.0]
	var laid := _laid(c)
	var ov = override(id)
	if ov == null:
		return [laid, 1.0]
	var inside := cap(id, "inside")
	var s := clampf(float(ov.get("scale", 1.0)), Layout.MIN_SCALE, Layout.MAX_SCALE)
	var k := 1.0 if inside else s
	var fr := frame_rect(id)
	# (it fits its frame: at most as big as the frame, unless it was bigger as built)
	if laid.size.x > 0.0 and laid.size.y > 0.0 and not inside:
		var most := minf(fr.size.x / laid.size.x, fr.size.y / laid.size.y)
		if k > most:
			k = maxf(most, minf(k, 1.0))
	var view := _view(c)
	var size := laid.size * k
	var off := Vector2(float(ov.get("x", 0.0)) * view.x, float(ov.get("y", 0.0)) * view.y) if cap(id, "move") else Vector2.ZERO
	var r := Rect2(laid.get_center() + off - size * 0.5, size)
	r = keep_in(r, fr)
	return [r, k]


## Keeps a box inside a frame (wholly if it fits, else its top left in it).
static func keep_in(r: Rect2, fr: Rect2) -> Rect2:
	if fr.size.x <= 0.0 or fr.size.y <= 0.0:
		return r
	r.position.x = clampf(r.position.x, fr.position.x, maxf(fr.end.x - r.size.x, fr.position.x))
	r.position.y = clampf(r.position.y, fr.position.y, maxf(fr.end.y - r.size.y, fr.position.y))
	return r


## The arranged box on the screen.
static func rect(id: String) -> Rect2:
	return _arranged(id)[0]


static func scale_of(id: String) -> float:
	var ov = override(id)
	return clampf(float(ov.get("scale", 1.0)), Layout.MIN_SCALE, Layout.MAX_SCALE) if ov != null else 1.0


## Puts the arrangement on the control (its position and scale; the page's
## panel: its CenterContainer's).
static func _apply(c: Control) -> void:
	var d: Dictionary = c.get_meta("arr")
	var id := String(d["id"])
	var caps: Dictionary = d["caps"]
	if caps.has("apply"):
		(caps["apply"] as Callable).call(c)
		return
	var ov = override(id)
	var base: Rect2 = c.get_meta("arr_base", Rect2(c.position, c.size))
	if bool(caps.get("via", false)):
		var holder := c.get_parent() as Control
		var home: Vector2 = holder.get_meta("arr_home", holder.position)
		if ov == null:
			holder.scale = Vector2.ONE
			holder.position = home
			return
		var a := _arranged(id)
		var up := holder.get_parent() as CanvasItem
		var inv := up.get_global_transform().affine_inverse() if up != null else Transform2D.IDENTITY
		holder.pivot_offset = Vector2.ZERO
		holder.scale = Vector2(a[1], a[1])
		holder.position = inv * (a[0] as Rect2).position - base.position * float(a[1])
		return
	if ov == null:
		if c.scale != Vector2.ONE or c.position != base.position:
			c.scale = Vector2.ONE
			c.position = base.position
		return
	var a := _arranged(id)
	var pinv := (c.get_parent() as CanvasItem).get_global_transform().affine_inverse() if c.get_parent() is CanvasItem else Transform2D.IDENTITY
	c.pivot_offset = Vector2.ZERO
	c.scale = Vector2(a[1], a[1])
	c.position = pinv * (a[0] as Rect2).position


## Puts every tagged element's arrangement on it again (after an undo, a reset).
static func apply_all() -> void:
	for id in _index.keys():
		var c := node(id)
		if c == null:
			if _index.has(id) and (_index[id].get_ref() == null):
				_index.erase(id)
			continue
		_hook(c)
		_apply(c)


## Lays the menu out again with the arrangement as it is now (Arrange mode,
## after any change: the menu itself is paused): the rail's width and
## spacing, the panel, the train's cars beside the rail, and every element.
static func refresh(m) -> void:
	if m == null or m.page == "":
		return
	var rail = m.rail
	if rail != null and rail.list != null and is_instance_valid(rail.list) and rail.list.has_meta("arr"):
		_list_spacing(rail.list)
	m._layout()
	if m.page == "train" and m.train_view != null:
		var w: float = m.RailScript.width_for(m.compact()) if m.rail_showing() else 0.0
		if m.train_view.inset != w:
			m.train_view.set_inset(w)
			for r in m.train_view.rooms.values():
				r.fit()
	apply_all()


## Arranges an element to fill this box (on the screen) as closely as it
## can: its place, and (if it scales) its scale from the box's width.
static func move_to(id: String, r: Rect2) -> void:
	var c := node(id)
	if c == null:
		return
	var laid := _laid(c)
	var view := _view(c)
	var ov = override(id)
	var out: Dictionary = {"anchor": Layout.OWN, "x": 0.0, "y": 0.0, "scale": 1.0}
	if ov != null:
		out = ov.duplicate()
	var s := scale_of(id)
	if cap(id, "scale"):
		if cap(id, "inside"):
			var now := rect(id)
			if now.size.x > 0.0 and absf(r.size.x - now.size.x) > 0.01:
				s *= r.size.x / now.size.x
		elif laid.size.x > 0.0:
			s = r.size.x / laid.size.x
	s = clampf(s, Layout.MIN_SCALE, Layout.MAX_SCALE)
	out["scale"] = snappedf(s, 0.001)
	if cap(id, "move"):
		var off := r.get_center() - laid.get_center()
		if cap(id, "inside"):
			off = r.position - laid.position
		out["x"] = snappedf(off.x / maxf(view.x, 1.0), 0.0001)
		out["y"] = snappedf(off.y / maxf(view.y, 1.0), 0.0001)
	Layout.set_override(id, out)
	_apply(c)


## Grows or shrinks an element's scale by this much.
static func nudge_scale(id: String, by: float) -> void:
	var s := clampf(snappedf(scale_of(id) + by, 0.05), Layout.MIN_SCALE, Layout.MAX_SCALE)
	_set_field(id, "scale", s)


## Resizes an element across ("w") or down ("h") to this many px.
static func resize_to(id: String, axis: String, px: float) -> void:
	var d := default_rect(id)
	var full := d.size.x if axis == "w" else d.size.y
	if full <= 0.0:
		return
	_set_field(id, axis, clampf(px / full, MIN_FACTOR, MAX_FACTOR))


static func _set_field(id: String, key: String, v: float) -> void:
	var c := node(id)
	if c == null:
		return
	var ov = override(id)
	var out: Dictionary = {"anchor": Layout.OWN, "x": 0.0, "y": 0.0, "scale": 1.0}
	if ov != null:
		out = ov.duplicate()
	out[key] = snappedf(v, 0.001)
	if key in ["w", "h"] and absf(v - 1.0) < 0.001:
		out.erase(key)
	Layout.set_override(id, out)
	var caps: Dictionary = c.get_meta("arr")["caps"]
	if key in ["w", "h"] and caps.has("resize"):
		(caps["resize"] as Callable).call(c)
	_apply(c)


## Notes how much an element's own size was changed by its resizing (so
## its built-in box is known): `r` moves its position and grows its size.
static func note_extra(c: Control, r: Rect2) -> void:
	if c != null:
		c.set_meta("arr_extra", r)


# --- what's on screen -----------------------------------------------------------------

## The elements on the page showing (with the rail, and the train's car you're in).
static func ids_on_screen(m) -> Array:
	var out: Array = []
	var seen := {}
	for id in _page:
		if seen.has(id):
			continue
		seen[id] = true
		var c := node(id)
		if c == null or not c.is_visible_in_tree():
			continue
		var g := String(c.get_meta("arr").get("group", ""))
		if g.begins_with("train.") and m != null and g != "train." + String(m.train_car):
			continue
		var r := rect(id)
		if r.size.x < 2.0 or r.size.y < 2.0 or not r.intersects(Rect2(Vector2.ZERO, _view(c))):
			continue
		out.append(id)
	return out


## The element `id` holds (it moves with it), for snapping.
static func is_inside(id: String, other: String) -> bool:
	var a := node(id)
	var b := node(other)
	return a != null and b != null and a != b and a.is_ancestor_of(b)


# --- the menu ------------------------------------------------------------------------

## The page's key: the page, and its tab where tabs change it.
static func page_key(m) -> String:
	match String(m.page):
		"climber":
			return "climber." + String(m.climber_tab)
		"settings":
			return "settings." + String(m.settings_tab)
		"station":
			return "station." + String(m.station_page.stop)
	return String(m.page)


static func page_name(m) -> String:
	var n: String = PAGE_NAMES.get(String(m.page), String(m.page).capitalize())
	if m.page == "climber":
		n += " (" + String(m.climber_tab).capitalize() + ")"
	return n


## Tags what's arrangeable on the page just built (menu.gd open): its
## panel, what's in it, the rail, and on the train every car's furniture.
static func tag_page(m) -> void:
	_page.clear()
	if not enabled:
		return
	untag(m.panel)
	if m.rail != null:
		_tag_rail(m)
	if m.page in SKIP_PAGES or m.page == "":
		return
	if m.page == "train":
		_tag_train(m)
		after_layout(m)
		return
	var pk := page_key(m)
	var pn := page_name(m)
	var page_n: String = PAGE_NAMES.get(String(m.page), String(m.page).capitalize())
	tag(m.panel, "menu.%s.panel" % m.page, page_n if page_n.ends_with("page") else page_n + " page",
		{"x": true, "via": true, "resize": func(_c): m._layout()}, null, "menu." + pk, "panel")
	# (what's on the page stays on the screen, or across within the page if
	# it scrolls (and clips); a row fills the page's width,
	# so keeping it inside the page would keep it from moving across at all)
	var counts := {}
	m.scroll.set_meta("arr_page", true)
	var heading := ""  # (the section heading just above, to name what follows it)
	for ctl in m.box.get_children():
		_tag_menu_part(m, ctl, "menu." + pk, pn, counts, 0, m.scroll, heading)
		if ctl is Control and ctl.visible and not _spacer(ctl):
			heading = String(ctl.text).strip_edges() if _is_heading(ctl) else ""
	for ctl in m.foot.get_children():
		_tag_menu_part(m, ctl, "menu." + pk, pn, counts, 0, null)
	after_layout(m)


static func _tag_menu_part(m, ctl, prefix: String, pn: String, counts: Dictionary, depth: int, frame: Control, heading := "") -> void:
	if not (ctl is Control) or not ctl.visible or ctl.is_queued_for_deletion() or _page.size() >= MAX_PER_PAGE:
		return
	if _spacer(ctl):
		return
	var kind := _kind(ctl)
	counts[kind] = int(counts.get(kind, 0)) + 1
	var id := "%s.%s%d" % [prefix, kind, counts[kind]]
	if kind in ["title", "tabs", "ribbons"] and counts[kind] == 1:
		id = "%s.%s" % [prefix, kind]
	tag(ctl, id, _auto_name(ctl, kind, int(counts[kind]), heading), {}, frame, prefix, kind, pn)
	# A row of columns: each column too (one level down).
	if depth == 0 and (ctl is HBoxContainer or ctl is HFlowContainer) and not (kind in ["title", "tabs", "ribbons", "footer"]):
		var cols: Array = ctl.get_children().filter(func(k): return k is Control and k.visible and not _spacer(k))
		if cols.size() >= 2 and cols.any(func(k): return k is Container or (k.get_script() != null and not (k is BaseButton))):
			var sub := {}
			for k in cols:
				_tag_menu_part(m, k, id, pn, sub, 1, frame)
			return
	# Cards inside it: panels and big drawn pieces, the outermost ones.
	var cards := {}
	_find_cards(m, ctl, id, pn, cards, frame)


static func _find_cards(m, n: Node, prefix: String, pn: String, counts: Dictionary, frame: Control) -> void:
	for k in n.get_children():
		if not (k is Control) or not k.visible or _page.size() >= MAX_PER_PAGE:
			continue
		if _is_card(k):
			counts["card"] = int(counts.get("card", 0)) + 1
			tag(k, "%s.card%d" % [prefix, counts["card"]], _auto_name(k, "card", int(counts["card"])), {}, frame, prefix, "card", pn)
			continue
		_find_cards(m, k, prefix, pn, counts, frame)


static func _is_card(k: Control) -> bool:
	var sz := k.get_combined_minimum_size().max(k.size)
	if sz.x < CARD_MIN.x or sz.y < CARD_MIN.y:
		return false
	if k is PanelContainer:
		return true
	return k.get_script() != null and not (k is Label) and not (k is ScrollContainer) and not (k is BoxContainer) and not (k is GridContainer)


## A gap or a rule between things (not worth moving on its own).
static func _spacer(c: Control) -> bool:
	return c.get_class() == "Control" and c.get_child_count() == 0 and (c.get_script() == null or c.custom_minimum_size.y <= 14.0)


static func _kind(c: Control) -> String:
	if c.has_meta("arrange"):
		return String(c.get_meta("arrange"))
	if c.has_meta("ribbons"):
		return "ribbons"
	if c is HBoxContainer or c is HFlowContainer:
		return "row"
	if c is GridContainer:
		return "grid"
	if c is VBoxContainer:
		return "column"
	if c is Label or c is RichTextLabel:
		return "text"
	if c is PanelContainer:
		return "card"
	if c is BaseButton:
		return "button"
	return "part"


## A section's heading (menu.gd _section): a short label on one line.
static func _is_heading(c) -> bool:
	return c is Label and c.autowrap_mode == TextServer.AUTOWRAP_OFF and String(c.text).strip_edges().length() in range(1, 41)


## A name for an element nobody named (NAMES): its kind and the first words
## on it ("Row “Music”"), the heading just above it ("Gear and Items: grid"),
## or its kind and number ("Grid 3").
static func _auto_name(c: Control, kind: String, n: int, heading := "") -> String:
	var k: String = KIND_NAMES.get(kind, kind.capitalize())
	if kind in ["title", "tabs", "ribbons", "panel"]:
		return k
	if kind == "text" and _is_heading(c):
		return "Heading “%s”" % String(c.text).strip_edges()
	var words := _first_words(c)
	if not _has_letters(words):
		words = ""
	if heading != "" and (kind in ["grid", "part"] or words == ""):
		return "%s: %s" % [heading, k.to_lower()]
	if words != "":
		return "%s “%s”" % [k, words]
	return "%s %d" % [k, n]


static func _has_letters(t: String) -> bool:
	for i in t.length():
		var ch := t.unicode_at(i)
		if (ch >= 48 and ch <= 57) or (ch >= 65 and ch <= 90) or (ch >= 97 and ch <= 122) or ch > 191:
			return true
	return false


static func _first_words(n: Node) -> String:
	var t := ""
	if n is Label or n is Button:
		t = String(n.text)
	elif n is RichTextLabel:
		t = String(n.get_parsed_text())
	t = t.strip_edges().replace("\n", " ")
	if t != "":
		return t.substr(0, 22) + ("…" if t.length() > 22 else "")
	for k in n.get_children():
		var w := _first_words(k)
		if w != "":
			return w
	return ""


## The page's panel: where _layout put its holder (the CenterContainer),
## then its arrangement (menu.gd _layout calls this last). Also the rail's.
static func after_layout(m) -> void:
	var center: Control = m.center
	center.set_meta("arr_home", center.position)
	if m.panel.has_meta("arr"):
		_hook(m.panel)
		_apply(m.panel)
	elif center.scale != Vector2.ONE:
		center.scale = Vector2.ONE
	if m.rail != null and m.rail.has_meta("arr"):
		_apply(m.rail)
	# Something on the page moved: the page clips only if it scrolls, so what
	# moved past its edge still shows (as built, it clips as it always did).
	var scroll: ScrollContainer = m.scroll
	var clip := true
	if _page.any(func(id): return String(id).begins_with("menu.") and not String(id).ends_with(".panel") and override(id) != null):
		clip = m.box.get_combined_minimum_size().y > scroll.size.y + 1.0
	if scroll.clip_contents != clip:
		scroll.clip_contents = clip


## How wide the page's panel is (menu.gd _layout): `w` its built-in width,
## `most` the most there's room for.
static func panel_width(m, w: float, most: float) -> float:
	var id := "menu.%s.panel" % m.page
	var k := factor(id, "w")
	if not enabled or k == 1.0 or not m.panel.has_meta("arr"):
		note_extra(m.panel, Rect2())
		return w
	var to := clampf(w * k, minf(w, 160.0), maxf(most, w))
	note_extra(m.panel, Rect2(Vector2(-(to - w) * 0.5, 0.0), Vector2(to - w, 0.0)))
	return to


# --- the rail ------------------------------------------------------------------------

## How much wider the rail is arranged (rail.gd width_for).
static func rail_width_k() -> float:
	if not enabled:
		return 1.0
	return factor("rail.box", "w")


static func _tag_rail(m) -> void:
	var rail = m.rail
	if not rail.visible and not m.rail_showing():
		return
	tag(rail, "rail.box", RAIL_NAMES["rail.box"], {"move": false, "x": true, "inside": true, "self": true,
		"apply": _apply_rail, "resize": func(_c): refresh(m)}, null, "rail", "rail")
	var base_w: float = rail.NARROW if rail.narrow else rail.WIDE
	note_extra(rail, Rect2(Vector2.ZERO, Vector2(rail.size.x - base_w, 0.0)) if rail.size.x > 0.0 else Rect2())
	if rail.ident != null and is_instance_valid(rail.ident):
		tag(rail.ident, "rail.ident", RAIL_NAMES["rail.ident"], {}, rail, "rail", "rail", RAIL_NAMES["rail.box"])
	if rail.list != null and is_instance_valid(rail.list):
		if not rail.list.has_meta("arr_sep"):
			rail.list.set_meta("arr_sep", rail.list.get_theme_constant("separation"))
		tag(rail.list, "rail.list", RAIL_NAMES["rail.list"], {"y": true, "resize": _list_spacing}, rail, "rail", "rail", RAIL_NAMES["rail.box"])
		_list_spacing(rail.list)
	if rail.foot_box != null and is_instance_valid(rail.foot_box):
		tag(rail.foot_box, "rail.foot", RAIL_NAMES["rail.foot"], {}, rail, "rail", "rail", RAIL_NAMES["rail.box"])


## The rail: its width is the menu's to lay out (rail.gd width_for), the
## text size its column's scale.
static func _apply_rail(rail: Control) -> void:
	var base_w: float = rail.NARROW if rail.narrow else rail.WIDE
	note_extra(rail, Rect2(Vector2.ZERO, Vector2(rail.size.x - base_w, 0.0)))
	var pane: Control = rail.pane
	if pane == null or not is_instance_valid(pane):
		return
	if not pane.has_meta("arr_offsets"):
		pane.set_meta("arr_offsets", Vector4(pane.offset_left, pane.offset_top, pane.offset_right, pane.offset_bottom))
	var o: Vector4 = pane.get_meta("arr_offsets")
	var s := scale_of("rail.box")
	if int(rail.get_meta("arr_resized", 0)) != rail.get_instance_id():
		rail.set_meta("arr_resized", rail.get_instance_id())
		rail.resized.connect(func(): if rail.has_meta("arr"): _apply_rail(rail))
	if s == 1.0:
		if pane.scale != Vector2.ONE:
			pane.scale = Vector2.ONE
			pane.offset_right = o.z
			pane.offset_bottom = o.w
		return
	var inner := Vector2(rail.size.x - o.x + o.z, rail.size.y - o.y + o.w)
	pane.scale = Vector2(s, s)
	pane.offset_right = inner.x / s + o.x - rail.size.x
	pane.offset_bottom = inner.y / s + o.y - rail.size.y


## The rail's list: its spacing from its arranged height.
static func _list_spacing(list: Control) -> void:
	var base := int(list.get_meta("arr_sep", list.get_theme_constant("separation")))
	var gaps := maxi(list.get_children().filter(func(k): return k is Control and k.visible).size() - 1, 1)
	var h := factor("rail.list", "h")
	var tall: float = list.get_combined_minimum_size().y - float(list.get_theme_constant("separation") - base) * gaps
	var each := maxi(int(round((h - 1.0) * tall / gaps)) + base, 0)
	if list.get_theme_constant("separation") != each:
		list.add_theme_constant_override("separation", each)
	note_extra(list, Rect2(Vector2.ZERO, Vector2(0.0, float(each - base) * gaps)))


# --- the train ------------------------------------------------------------------------

static func _car_name(car: String) -> String:
	for c in Train.CARS:
		if c[0] == car:
			return String(c[1])
	return car.capitalize()


static func _tag_train(m) -> void:
	var tp = m.train_page
	if tp == null:
		return
	for car in tp.roots:
		var root = tp.roots[car]
		if root == null or not is_instance_valid(root):
			continue
		var counts := {}
		_tag_car(root, root, "train." + String(car), _car_name(String(car)), counts)


## A car's furniture: its pieces of furniture and placards (what's in them
## moves with them), the book, the bench, the outfitter, signs and speech.
static func _tag_car(root: Control, n: Node, prefix: String, cn: String, counts: Dictionary) -> void:
	for k in n.get_children():
		if not (k is Control) or not k.visible or _page.size() >= MAX_PER_PAGE * 2:
			continue
		var kind := ""
		var s = k.get_script()
		if s == TrainView.Furnish:
			kind = String(k.kind)
		elif k.has_meta("entity") or k.has_meta("outfitter_line") or (n == root and k is HBoxContainer and not (k.size_flags_vertical & Control.SIZE_EXPAND)):
			kind = "speech"  # (the Entity's words at the top of a car, the outfitter's)
		elif s == Book.ClosedBook:
			kind = "book"
		elif s == TrainView.Bench:
			kind = "bench"
		elif s == TrainView.Outfitter:
			kind = "outfitter"
		elif k is BaseButton and not (n is GridContainer):
			kind = "sign"
		elif s != null and not (n is GridContainer) and k.get_combined_minimum_size().x >= CARD_MIN.x and not (k is BaseButton):
			kind = "piece"
		if kind == "":
			_tag_car(root, k, prefix, cn, counts)
			continue
		counts[kind] = int(counts.get(kind, 0)) + 1
		var id := "%s.%s%s" % [prefix, kind, "" if counts[kind] == 1 else str(counts[kind])]
		var nm: String = FURNISH_NAMES.get(kind, kind.capitalize())
		if kind == "sign":
			var w := _first_words(k)
			if w != "":
				nm += " “" + w + "”"
		tag(k, id, nm, {}, root.get_parent() if root.get_parent() is ScrollContainer else root, prefix, kind, cn)  # (kept in the car, where it shows)
