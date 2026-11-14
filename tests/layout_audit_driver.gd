extends RefCounted
## The layout audit: opens the game's screens and looks at every piece of
## text on them for trouble a player would see.
##
## What counts as text: Labels, RichTextLabels, Buttons with words, and text
## drawn in code through ui.gd draw_text / draw_text_lines (a slot's tag, a
## card's lines, the rail), which note where they drew while the audit
## watches (ui.gd text_notes).
##
## What it flags (scan()):
##   over     two pieces of text on top of each other (neither inside the
##            other, and not marked as stacked on purpose: the meta
##            "layout_stack" on either, or on something they sit in)
##   cut      text cut short by its own control (a button or label too
##            narrow: the words end in "..."; a label with lines hidden),
##            or squeezed into a sliver (wrapped a word or less to a line)
##   clipped  text cut off by something it sits in that doesn't scroll
##   off      text partly off the screen, with nothing to scroll it back
##   under    text under the rail, or under a touch button
##   press    two buttons on top of each other
##
## Screens are opened by sweep(): every menu page and tab, every train car
## and store and bench view, every station stop; `light` keeps a
## representative few. Used by tests/parts/layout_audit.gd (light, in the
## parts run) and tests/layout_sweep.gd (everything, on its own).

const UI := preload("res://scripts/ui.gd")
const Gear := preload("res://scripts/gear.gd")
const Train := preload("res://scripts/train.gd")
const Bench := preload("res://scripts/bench.gd")
const Stations := preload("res://scripts/stations.gd")
const Appearance := preload("res://scripts/appearance.gd")
const EssenceBench := preload("res://scripts/essence_bench.gd")
const Unbound := preload("res://scripts/unbound.gd")

## Text may share this much of its line box with a neighbour (the gothic
## face's lines are taller than its letters: headings sit close on purpose).
const LINE_INSET := 0.2
## Wrapped text narrower than this many times its letters' size, on four
## lines or more, is squeezed: a word or less to a line.
const SLIVER := 4.5
## Two pieces of text overlap when they share more than this (view px) both ways.
const OVER_MIN := 2.0
## Screen sizes: a computer, and three phones (touch on).
const DESKTOP := Vector2i(1280, 720)
const PHONES := [Vector2i(915, 412), Vector2i(800, 400), Vector2i(740, 360)]


# --- looking at one screen -----------------------------------------------------------

## Every problem with the text under `tops` (controls), as lines of words.
## `view`: the screen. `opts`: "rail" (the rail's control: nothing else may
## sit under it), "keep_out" (rects text mustn't be under: touch buttons),
## "notes" (ui.gd text_notes taken while these were drawn).
static func scan(where: String, tops: Array, view: Rect2, opts := {}) -> Array:
	var out: Array = []
	var seen := {}
	var hs: Array = holders(tops, opts.get("notes", []))
	var rail: Control = opts.get("rail")
	var rail_rect := Rect2()
	if rail != null and is_instance_valid(rail) and rail.is_visible_in_tree():
		rail_rect = _global(rail, Rect2(Vector2.ZERO, rail.size))
	for h in hs:
		for p in h["problems"]:
			_add(out, seen, "%s: cut: %s %s" % [where, h["what"], p])
		if h.get("nowhere", false):
			continue
		var ink: Rect2 = h["ink"]
		# What it sits in: anything that clips, with or without a scroll.
		var vis := ink
		var free_x := true  # nothing scrolls it across / up and down
		var free_y := true
		var n: Node = h["node"] if h["drawn"] else h["node"].get_parent()
		while n != null and n is CanvasItem:
			if n is Control and (n.clip_contents or n is ScrollContainer):
				var cr: Rect2 = _global(n, Rect2(Vector2.ZERO, n.size))
				var sx: bool = n is ScrollContainer and n.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
				var sy: bool = n is ScrollContainer and n.vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED
				if n is RichTextLabel:
					sy = n.scroll_active
				if not sx and (vis.position.x < cr.position.x - 1.0 or vis.end.x > cr.end.x + 1.0) and vis.intersects(cr):
					_add(out, seen, "%s: clipped: %s runs past the side of %s (%.0f-%.0f in %.0f-%.0f)" % [where, h["what"], _name(n), vis.position.x, vis.end.x, cr.position.x, cr.end.x])
				if not sy and (vis.position.y < cr.position.y - 1.0 or vis.end.y > cr.end.y + 1.0) and vis.intersects(cr):
					_add(out, seen, "%s: clipped: %s runs past the top or bottom of %s (%.0f-%.0f in %.0f-%.0f)" % [where, h["what"], _name(n), vis.position.y, vis.end.y, cr.position.y, cr.end.y])
				free_x = free_x and not sx
				free_y = free_y and not sy
				vis = vis.intersection(cr)
			n = n.get_parent()
		h["vis"] = vis
		if vis.size.x < 1.0 or vis.size.y < 1.0:
			continue
		if (free_x and (ink.position.x < view.position.x - 1.0 or ink.end.x > view.end.x + 1.0)) or (free_y and (ink.position.y < view.position.y - 1.0 or ink.end.y > view.end.y + 1.0)):
			_add(out, seen, "%s: off: %s is partly off the screen (%s on %s)" % [where, h["what"], _r(ink), _r(view)])
		if rail_rect.size.x > 0.0 and not _inside(h["node"], rail) and _shared(vis, rail_rect):
			_add(out, seen, "%s: under: %s is under the rail (%s)" % [where, h["what"], _r(vis)])
		for k in opts.get("keep_out", []):
			if _shared(vis, k):
				_add(out, seen, "%s: under: %s is under a touch button (%s)" % [where, h["what"], _r(vis)])
	# Text on text.
	var live: Array = hs.filter(func(h): return h.has("vis") and h["vis"].size.x >= 1.0 and h["vis"].size.y >= 1.0)
	live.sort_custom(func(a, b): return a["vis"].position.x < b["vis"].position.x)
	for i in live.size():
		var a: Dictionary = live[i]
		for j in range(i + 1, live.size()):
			var b: Dictionary = live[j]
			if b["vis"].position.x > a["vis"].end.x:
				break
			if not _shared(a["vis"], b["vis"]):
				continue
			var an: Node = a["node"]
			var bn: Node = b["node"]
			if an == bn and (not a["drawn"] or not b["drawn"] or a["text"] == b["text"]):
				continue  # (the same control; or the same words drawn twice: a shadow)
			if an != bn and (an.is_ancestor_of(bn) or bn.is_ancestor_of(an)) and not (a["drawn"] or b["drawn"]):
				continue
			if _stacked(an) or _stacked(bn):
				continue
			_add(out, seen, "%s: over: %s and %s are on top of each other (%s, %s)" % [where, a["what"], b["what"], _r(a["vis"]), _r(b["vis"])])
	# Buttons on buttons.
	var press: Array = []
	for top in tops:
		for c in _controls(top):
			if (c is BaseButton or c is LineEdit or c is Slider) and _showing(c):
				var r := _clip(c, _global(c, Rect2(Vector2.ZERO, c.size)))
				if r.size.x > 1.0 and r.size.y > 1.0:
					press.append([c, r])
	for i in press.size():
		for j in range(i + 1, press.size()):
			var a: Control = press[i][0]
			var b: Control = press[j][0]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a) or _stacked(a) or _stacked(b):
				continue
			if _shared(press[i][1], press[j][1]):
				_add(out, seen, "%s: press: %s and %s are on top of each other" % [where, _what(a), _what(b)])
	return out


static func _add(out: Array, seen: Dictionary, line: String) -> void:
	if not seen.has(line):
		seen[line] = true
		out.append(line)


## Every piece of text showing under `tops`: {"node", "what", "text", "ink"
## (where the words are, on the canvas), "drawn" (drawn in code), "problems"}.
static func holders(tops: Array, notes: Array) -> Array:
	var out: Array = []
	for top in tops:
		for c in _controls(top):
			if not _showing(c):
				continue
			var h := {}
			if c is Label:
				h = _label(c)
			elif c is RichTextLabel:
				h = _rich(c)
			elif c is Button:
				h = _button(c)
			if h.is_empty():
				continue
			h["node"] = c
			h["drawn"] = false
			h["what"] = _what(c)
			out.append(h)
	for nt in notes:
		var ci = nt["ci"]
		if not is_instance_valid(ci) or not (ci is CanvasItem) or not ci.is_visible_in_tree() or _alpha(ci) < 0.05:
			continue
		if not tops.any(func(t): return t == ci or t.is_ancestor_of(ci)):
			continue
		var problems: Array = []
		if float(nt["room"]) >= 0.0 and float(nt["need"]) > float(nt["room"]) + 1.0:
			problems.append("is drawn into %.0f px but needs %.0f" % [nt["room"], nt["need"]])
		if int(nt["cut"]) > 0:
			problems.append("loses %d line(s)" % nt["cut"])
		var r: Rect2 = nt["rect"]
		if r.size == Vector2.ZERO:
			# (shortened by hand before drawing: only that is known)
			for p in problems:
				out.append({"node": ci, "drawn": true, "text": String(nt["text"]), "what": "drawn '%s' (%s)" % [String(nt["text"]).left(28), _name(ci)],
					"ink": Rect2(), "problems": [p], "nowhere": true})
			continue
		out.append({"node": ci, "drawn": true, "text": String(nt["text"]), "what": "drawn '%s' (%s)" % [String(nt["text"]).left(28), _name(ci)],
			"ink": _global(ci, _inset(r, r.size.y)), "problems": problems})
	return out


static func _label(l: Label) -> Dictionary:
	var text: String = l.text.to_upper() if l.uppercase else l.text
	if text.strip_edges() == "":
		return {}
	var f: Font = l.get_theme_font("font")
	var fs: int = l.get_theme_font_size("font_size")
	if l.label_settings != null:
		f = l.label_settings.font if l.label_settings.font != null else f
		fs = l.label_settings.font_size
	var wrap: bool = l.autowrap_mode != TextServer.AUTOWRAP_OFF
	var need: float = f.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var lines: int = l.get_line_count()
	var shown: int = l.get_visible_line_count()
	var lh: float = float(l.get_line_height()) + l.get_theme_constant("line_spacing")
	var problems: Array = []
	var cuts: bool = l.clip_text or l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING
	if not wrap and need > l.size.x + 1.0 and cuts:
		problems.append("is cut short (%.0f px of words in %.0f)" % [need, l.size.x])
	if shown < lines:
		problems.append("shows %d of its %d lines" % [shown, lines])
	if wrap and lines >= 4 and l.size.x < fs * SLIVER:
		problems.append("is squeezed into %.0f px across (%d lines)" % [l.size.x, lines])
	var w: float = minf(need, l.size.x) if (wrap or cuts) else need
	var h: float = lh * maxi(shown, 1)
	var x := 0.0
	match l.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			x = (l.size.x - w) * 0.5
		HORIZONTAL_ALIGNMENT_RIGHT:
			x = l.size.x - w
	var y := 0.0
	match l.vertical_alignment:
		VERTICAL_ALIGNMENT_CENTER:
			y = (l.size.y - h) * 0.5
		VERTICAL_ALIGNMENT_BOTTOM:
			y = l.size.y - h
	return {"text": text, "ink": _global(l, _inset(Rect2(x, y, w, h), lh)), "problems": problems}


static func _button(b: Button) -> Dictionary:
	if b.text.strip_edges() == "" or b.get_theme_color("font_color").a < 0.05:
		return {}  # (no words, or words it draws itself: the rail's items)
	var f: Font = b.get_theme_font("font")
	var fs: int = b.get_theme_font_size("font_size")
	var sb: StyleBox = b.get_theme_stylebox("normal")
	var pad: Vector2 = sb.get_minimum_size() if sb != null else Vector2.ZERO
	var extra := 0.0
	if b.icon != null:
		extra += b.icon.get_width() + b.get_theme_constant("h_separation")
	if b is CheckButton or b is CheckBox:
		var ic: Texture2D = b.get_theme_icon("checked")
		extra += (ic.get_width() if ic != null else 0.0) + b.get_theme_constant("h_separation")
	var room: float = b.size.x - pad.x - extra
	var wrap: bool = b.autowrap_mode != TextServer.AUTOWRAP_OFF
	var need: float = f.get_multiline_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var size: Vector2 = Vector2(need, f.get_multiline_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).y)
	var problems: Array = []
	if wrap:
		size = f.get_multiline_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, maxf(room, 1.0), fs)
		if size.y > b.size.y - pad.y + 2.0:
			problems.append("wraps to %.0f px tall in %.0f" % [size.y, b.size.y - pad.y])
		if room < fs * SLIVER and size.y > f.get_height(fs) * 3.5:
			problems.append("is squeezed into %.0f px across" % room)
		size.x = minf(size.x, room)
	elif need > room + 1.0:
		problems.append("is cut short (%.0f px of words in %.0f)" % [need, room])
		size.x = maxf(room, 1.0)
	var left: float = sb.get_margin(SIDE_LEFT) if sb != null else 0.0
	var x: float = left + extra * (0.0 if b is CheckButton or b is CheckBox else 1.0)
	match b.alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			x = left + extra * 0.5 + (room - size.x) * 0.5 + (extra * 0.5 if b.icon != null else 0.0)
		HORIZONTAL_ALIGNMENT_RIGHT:
			x = b.size.x - (pad.x - left) - size.x
	var r := Rect2(x, (b.size.y - size.y) * 0.5, size.x, size.y)
	return {"text": b.text, "ink": _global(b, _inset(r, f.get_height(fs))), "problems": problems}


static func _rich(r: RichTextLabel) -> Dictionary:
	if r.get_parsed_text().strip_edges() == "":
		return {}
	var ch: float = r.get_content_height()
	var cw: float = r.get_content_width()
	var problems: Array = []
	if ch > r.size.y + 2.0 and not r.scroll_active:
		problems.append("is %.0f px tall in %.0f" % [ch, r.size.y])
	var f: Font = r.get_theme_font("normal_font")
	var fs: int = r.get_theme_font_size("normal_font_size")
	return {"text": r.get_parsed_text(), "ink": _global(r, _inset(Rect2(0, 0, minf(cw, r.size.x), minf(ch, r.size.y)), f.get_height(fs))), "problems": problems}


## A text's box drawn in a little: its lines' height holds more than letters.
static func _inset(r: Rect2, line_h: float) -> Rect2:
	var dy := minf(line_h * LINE_INSET, r.size.y * 0.4)
	return Rect2(r.position.x + 0.5, r.position.y + dy, maxf(r.size.x - 1.0, 0.0), maxf(r.size.y - dy * 2.0, 0.0))


static func _global(ci: CanvasItem, r: Rect2) -> Rect2:
	return ci.get_global_transform() * r


## `r` (on the canvas) cut down to what the things `c` sits in let through.
static func _clip(c: Node, r: Rect2) -> Rect2:
	var n := c.get_parent()
	while n != null and n is CanvasItem:
		if n is Control and (n.clip_contents or n is ScrollContainer):
			r = r.intersection(_global(n, Rect2(Vector2.ZERO, n.size)))
		n = n.get_parent()
	return r


static func _shared(a: Rect2, b: Rect2) -> bool:
	var o := a.intersection(b)
	return o.size.x > OVER_MIN and o.size.y > OVER_MIN


static func _controls(top: Node) -> Array:
	var out: Array = []
	if top is Control:
		out.append(top)
	out.append_array(top.find_children("*", "Control", true, false))
	return out


static func _showing(c: Control) -> bool:
	return c.is_visible_in_tree() and not c.is_queued_for_deletion() and c.size.x >= 1.0 and c.size.y >= 1.0 and _alpha(c) >= 0.05


static func _alpha(ci: CanvasItem) -> float:
	var a := 1.0
	var n: Node = ci
	while n != null and n is CanvasItem:
		a *= n.modulate.a * (n.self_modulate.a if n == ci else 1.0)
		n = n.get_parent()
	return a


static func _inside(n: Node, of: Node) -> bool:
	return of != null and (n == of or of.is_ancestor_of(n))


## Stacked on purpose (a badge on a slot, a number on a bar): the meta
## "layout_stack" on it or on something it sits in.
static func _stacked(n: Node) -> bool:
	while n != null:
		if n.has_meta("layout_stack"):
			return true
		n = n.get_parent()
	return false


static func _what(c: Control) -> String:
	if (c is Button or c is Label) and c.text != "":
		return "%s '%s'" % ["button" if c is Button else "label", c.text.left(28).replace("\n", " ")]
	if c is RichTextLabel:
		return "text '%s'" % c.get_parsed_text().left(28).replace("\n", " ")
	return _name(c)


static func _name(n: Node) -> String:
	var s = n.get_script()
	var cls := n.get_class()
	if s != null and s is GDScript:
		var path: String = s.resource_path.get_file().get_basename()
		cls = "%s %s" % [path if path != "" else "inner", cls]
	return "%s '%s'" % [cls, String(n.name).left(20)]


static func _r(r: Rect2) -> String:
	return "%.0f,%.0f %.0fx%.0f" % [r.position.x, r.position.y, r.size.x, r.size.y]


# --- the HUD and the card screens (reported, not failed) ---------------------------

## The HUD in play and the card screens (choosing a tower, a camp's cards, a
## vault's, the heirloom, the path): their boxes on screen, apart from each
## other and from the touch buttons. The HUD draws through its own layout
## (layout.gd), so this looks at its boxes rather than each word; it is
## listed for whoever works on the HUD, and never fails the audit.
static func hud_problems(main, where: String) -> Array:
	var out: Array = []
	var L = load("res://scripts/layout.gd")
	var hud = main.hud
	var view: Vector2 = hud.get_viewport_rect().size
	var hs: float = hud.hud_scale
	var screen := Rect2(Vector2.ZERO, view).grow(0.5)
	var boxes := {}
	for id in ["hud.bars", "hud.gem", "hud.weapon", "hud.item", "hud.marks", "hud.essence"]:
		var b: Rect2 = L.box(id, view / hs)
		boxes[id] = Rect2(b.position * hs, b.size * hs)
	# What the game tells you in play (notices.gd, guide.gd), where it sits on
	# this screen: the top-middle lane (it fits itself between the corner and
	# the top-right buttons; on the tightest screens it goes under the corner,
	# and the feed then follows it), the left feed and the Entity's sphere.
	boxes["the top lane"] = hud.lane_box()
	boxes["the status lines"] = hud.chips_box()
	if not main.notices.left_mode:
		boxes["the feed"] = hud.feed_box()
	if main.entity != null:
		var c: Vector2 = main.entity.orb_spot()
		boxes["the Entity's sphere"] = Rect2(c - Vector2.ONE * main.entity.ORB_R, Vector2.ONE * main.entity.ORB_R * 2.0)
	for id in boxes:
		if not screen.encloses(boxes[id]):
			out.append("%s: hud: %s is partly off the screen (%s on %.0fx%.0f)" % [where, id, _r(boxes[id]), view.x, view.y])
	var ids: Array = boxes.keys()
	for i in ids.size():
		for j in range(i + 1, ids.size()):
			if _shared(boxes[ids[i]], boxes[ids[j]]):
				out.append("%s: hud: %s and %s are on top of each other (%s, %s)" % [where, ids[i], ids[j], _r(boxes[ids[i]]), _r(boxes[ids[j]])])
	if main.touch_active:
		main.touch._layout()
		for b in main.touch.buttons:
			var r := Rect2(b["c"] - Vector2.ONE * b["r"], Vector2.ONE * b["r"] * 2.0)
			if not screen.encloses(r):
				out.append("%s: hud: touch button %s is partly off the screen" % [where, b["id"]])
			for id in ids:
				if _shared(boxes[id], r.grow(-1.0)):
					out.append("%s: hud: touch button %s is over %s" % [where, b["id"], id])
	# The card screens.
	var keep: Dictionary = main.camp
	var sets := {"tower choice": []}
	for i in main.Towers.ORDER.size():
		sets["tower choice"].append(hud.tower_card_rect(i, view))
	for kind in [["camp", 4], ["vault", 3], ["heirloom", 6], ["path", 2]]:
		main.camp = {"choices": range(kind[1]).map(func(i): return "x%d" % i), "stage": kind[0]}
		var cards: Array = []
		for i in kind[1]:
			cards.append(hud.path_card_rect(i, view) if kind[0] == "path" else hud.camp_card_rect(i, view))
		sets[kind[0]] = cards
	main.camp = keep
	for name in sets:
		var cards: Array = sets[name]
		for i in cards.size():
			if not screen.encloses(cards[i]):
				out.append("%s: hud: %s card %d is partly off the screen (%s on %.0fx%.0f)" % [where, name, i + 1, _r(cards[i]), view.x, view.y])
			for j in range(i + 1, cards.size()):
				if _shared(cards[i], cards[j]):
					out.append("%s: hud: %s cards %d and %d are on top of each other" % [where, name, i + 1, j + 1])
	return out


# --- opening the screens ---------------------------------------------------------

## A climber with enough of everything that every screen has something to show:
## marks, crystals, a pack and a stash with long-named pieces, things worn,
## supplies, an heirloom, renown.
static func dress(main) -> void:
	var prof = main.profile
	main.grant_test_bonds()
	prof.add_bond("brow", "rune_artist", false)
	for k in ["stone", "blade", "fire", "iron", "water", "air"]:
		prof.add_crystal(k, 240)
	prof.pack = [Gear.make("axe"), Gear.make("leather_gloves", "rare", ["edges", "vigor"])]
	prof.chest = []
	var bases := ["plate", "leather_cap", "garnet_ring", "longbow", "chain_leggings", "travel_cloak", "climbing_boots"]
	for i in 17:
		prof.chest.append(Gear.make(bases[i % bases.size()], ["common", "fine", "rare"][i % 3], ["riposte"] if i % 3 > 0 else []))
	prof.wear = {"armor": Gear.make("plate"), "backpack": Gear.make("climbers_pack"), "helm": Gear.make("iron_helm", "fine", ["vigor"])}
	prof.supplies = {"draught": 2, "flare": 1, "tonic": 1}
	prof.climbs = maxi(prof.climbs, 6)
	# The Bestiary: some met, at every tier (bestiary.gd), the rest unmet.
	prof.bestiary = {"slime": {"seen": true, "fought": true, "slain": 20, "fell": 1, "tower": "kraken", "floor": 1},
		"archer": {"seen": true, "fought": true, "slain": 6, "fell": 0, "tower": "gryphon", "floor": 3},
		"knight": {"seen": true, "fought": true, "slain": 1, "fell": 2, "tower": "wyvern", "floor": 4},
		"lurker": {"seen": true, "fought": true, "slain": 0, "fell": 0, "tower": "kraken", "floor": 2},
		"bat": {"seen": true, "fought": false, "slain": 0, "fell": 0, "tower": "gryphon", "floor": 1},
		"gryphon": {"seen": true, "fought": true, "slain": 3, "fell": 1, "tower": "gryphon", "floor": 12},
		"golem": {"seen": true, "fought": true, "slain": 16, "fell": 0, "tower": "wyvern", "floor": 5}}
	Train.dress(prof, main.player)


## One pass over the screens at the size and Interface size now set. Calls
## `found` (a Callable taking the screen's name and its list of problems)
## for each. `light`: a representative few. `shoot`: a Callable(name) called
## once a screen is up (the sweep's screenshots), or an empty Callable.
static func sweep(tree: SceneTree, main, tag: String, found: Callable, light := false, shoot := Callable(), only := "") -> void:
	var menu = main.menu
	var s := Sweep.new()
	s.tree = tree
	s.main = main
	s.menu = menu
	s.tag = tag
	s.found = found
	s.shoot = shoot
	s.only = only
	s.light = light
	await s.run()


class Sweep:
	const A := preload("res://tests/layout_audit_driver.gd")
	var tree: SceneTree
	var main
	var menu
	var tag := ""
	var found: Callable
	var shoot: Callable
	var only := ""
	var light := false

	func frames(n: int) -> void:
		for i in n:
			await tree.process_frame

	func view() -> Rect2:
		return tree.root.get_visible_rect()

	func wants(name: String) -> bool:
		return only == "" or Array(only.split(",")).any(func(o): return name.contains(o))

	## Looks at what's showing: lets it lay out and draw (noting drawn
	## text), then scans.
	func look(name: String, tops: Array, opts := {}) -> void:
		if menu.fade != null and menu.fade.is_valid():
			menu.fade.custom_step(10.0)
		menu.panel.scale = Vector2.ONE
		await frames(3)
		tops = tops.filter(func(t): return t != null and is_instance_valid(t) and t.is_visible_in_tree())
		A.UI.text_notes = []
		for top in tops:
			top.queue_redraw()
			for c in top.find_children("*", "CanvasItem", true, false):
				c.queue_redraw()
		await frames(2)
		var notes: Array = A.UI.text_notes
		A.UI.text_notes = null
		opts["notes"] = notes
		if menu.rail.visible and not opts.has("rail"):
			opts["rail"] = menu.rail
		if shoot.is_valid():
			await shoot.call(name)
		found.call(name, A.scan("%s %s" % [tag, name], tops, view(), opts))

	func page_tops() -> Array:
		return [menu.panel, menu.rail] if menu.rail.visible else [menu.panel]

	func run() -> void:
		main.on_train = false
		main.choosing_tower = false
		if menu.is_open():
			menu.close()
		await frames(2)
		if wants("hud") and not light:
			found.call("hud (reported only)", A.hud_problems(main, tag + " hud"))
		await pages()
		await train()
		await stations()
		if menu.is_open():
			menu.close()
		main.on_train = false
		await frames(2)

	# The menu's pages, opened in play (the pause menu's rail beside them).
	func pages() -> void:
		var list: Array = [["pause", ""], ["settings", "settings"], ["settings", "controls"], ["controls", ""], ["padsetup", ""],
			["climber", "abilities"], ["climber", "tree"], ["climber", "marks"], ["climber", "essence"], ["climber", "record"],
			["mark", "hand"], ["mark", "legs"], ["mark", "brow"], ["mark", "heart"], ["mark", "throat"], ["mark", "back"],
			["library", ""], ["library", "bestiary"], ["inventory", "worn"], ["inventory", "pack"], ["inventory", "heirlooms"],
			["dev", ""], ["data", ""], ["confirm_new", ""], ["climbers", ""], ["techniques", ""]]
		for t in Appearance.TABS:
			list.append(["appearance", t[0]])
		if light:
			list = [["pause", ""], ["settings", "settings"], ["climber", "abilities"], ["climber", "marks"], ["climber", "record"], ["mark", "hand"],
				["inventory", "worn"], ["library", ""], ["library", "bestiary"], ["appearance", Appearance.TABS[0][0]]]
		for pg in list:
			var name := ("%s %s" % [pg[0], pg[1]]).strip_edges()
			if not wants(name):
				continue
			match pg[0]:
				"climber":
					menu.climber_tab = pg[1]
				"inventory":
					menu.inv_view = pg[1]
					menu.inv_sel = ""
				"settings":
					menu.settings_tab = pg[1]
				"appearance":
					menu.look_page.tab = pg[1]
				"library":
					menu.library_tab = "bestiary" if pg[1] == "bestiary" else "archive"
					menu.bestiary_open = "slime"  # (an entry open, at its last tier: bestiary.gd)
			if pg[0] == "mark":
				menu.open_mark(pg[1])
			elif pg[0] == "appearance":
				menu.open_appearance("climber")
			else:
				menu.open(pg[0])
			await look(name, page_tops())
		if not light:
			# The inventory's other cards: an item, a crystal, an heirloom, the fists.
			for sel in ["item:draught", "crystal:air", "gear:fists", "gear:armor", "gear:offhand"]:
				var nm := "inventory card %s" % sel
				if not wants(nm):
					continue
				menu.inv_view = "worn"
				menu.inv_sel = sel
				menu.open("inventory")
				await look(nm, page_tops())
			# The Library with a subject open.
			if wants("library open"):
				var Guide = load("res://scripts/guide.gd")
				var told: Dictionary = Guide.state.get("told", {})
				for id in ["gear", "train", "chest"]:
					told[id] = true  # (heard, so the Archive has them to open)
				Guide.state["told"] = told
				menu.archive_open = "chest"
				menu.library_tab = "archive"
				menu.open("library")
				await look("library open", page_tops())
				menu.archive_open = ""
			# The Bestiary with a beast's entry open, and one only seen.
			for k in ["gryphon", "bat"]:
				var nm := "library bestiary %s" % k
				if not wants(nm):
					continue
				menu.library_tab = "bestiary"
				menu.bestiary_open = k
				menu.open("library")
				await look(nm, page_tops())
			menu.library_tab = "archive"
			menu.bestiary_open = ""
			# The Data editor: each of its tabs, and a section open.
			var dp = menu.data_page
			for g in load("res://scripts/data_registry.gd").GROUPS:
				var nm := "data %s" % g[0]
				if not wants(nm):
					continue
				dp.tab = g[0]
				dp.section = ""
				menu.open("data")
				await look(nm, page_tops())
			dp.tab = "words"
		if menu.is_open():
			menu.close()
		await frames(1)
		if not light:
			# From the title: the title itself, a new climber's look, the painter.
			for pg in ["title", "create", "painter"]:
				if not wants(pg):
					continue
				menu.open("title")
				await frames(1)
				if pg != "title":
					menu.open(pg)
				await look(pg, [menu.painter] if pg == "painter" and menu.get("painter") != null else [menu.panel, menu.backdrop])
			menu.close()
			await frames(1)

	# The train: every car, the store's and the bench's views, the Loadout and stash.
	func train() -> void:
		main.await_tower()
		main.open_train()
		await frames(3)
		var views: Array = [["engine", "towers"], ["engine", "stations"], ["store", "shop"], ["store", "sell"], ["personal", ""], ["library", ""], ["library", "bestiary"], ["settings", "settings"], ["settings", "controls"]]
		for c in Bench.COUNTERS:
			views.append(["workshop", c[0]])
		views.append(["workshop", EssenceBench.COUNTER])
		if light:
			views = [["engine", "towers"], ["store", "shop"], ["store", "sell"], ["personal", ""], ["workshop", "brew"], ["workshop", "temper"], ["settings", "settings"], ["library", "bestiary"]]
		var tp = menu.train_page
		for v in views:
			var name := ("train %s %s" % [v[0], v[1]]).strip_edges()
			if not wants(name):
				continue
			var car: String = v[0]
			menu.train_car = car
			match car:
				"engine":
					menu.train_board = v[1]
				"store":
					menu.train_store = v[1]
					menu.train_sel["store"] = "pack:1" if v[1] == "sell" else "outfit:0"
					menu.inv_sel = menu.train_sel["store"]
				"personal":
					menu.train_sel["personal"] = "chest:1"
					menu.inv_sel = "chest:1"
				"workshop":
					menu.train_bench = v[1]
					menu.train_sel["workshop"] = ""
					menu.inv_sel = ""
				"settings":
					menu.settings_tab = v[1]
				"library":
					menu.library_shelf = v[1]
					menu.bestiary_open = "slime" if v[1] == "bestiary" else ""
			menu.open("train")
			await frames(2)
			tp.go_to(tp._index(car))
			await settle()
			var room: Control = menu.train_view.rooms[car]
			await look(name, [room, menu.train_view.chrome, menu.rail])
		if not light:
			# The store's other cards (a supply, today's piece, his upgrades) and
			# your car's (what you wear, a pack piece, an empty space).
			for v in [["store", "supply:draught"], ["store", "today"], ["store", "upgrades"], ["personal", "worn:armor"], ["personal", "pack:1"], ["personal", "chest:39"]]:
				var nm := "train %s card %s" % [v[0], v[1]]
				if not wants(nm):
					continue
				menu.train_car = v[0]
				menu.train_store = "shop"
				menu.train_sel[v[0]] = v[1]
				menu.inv_sel = v[1]
				menu.open("train")
				await frames(2)
				tp.go_to(tp._index(v[0]))
				await settle()
				await look(nm, [menu.train_view.rooms[v[0]], menu.train_view.chrome, menu.rail])
		menu.train_store = "shop"
		menu.train_bench = "brew"
		menu.train_board = "towers"
		menu.settings_tab = "settings"
		menu.train_car = Train.HOME
		menu.open("train")
		await frames(2)
		for pg in ["loadout", "stash"]:
			for sel in (["chest:1"] if light else ["worn:armor", "pack:1", "chest:1", "chest:39"]):
				if (pg == "stash" and sel.begins_with("worn")) or not wants("%s %s" % [pg, sel]):
					continue
				menu.inv_sel = sel
				menu.open(pg, true)
				await look("%s %s" % [pg, sel], page_tops())
			menu.close()
			await frames(1)

	func settle() -> void:
		var v = menu.train_view
		for i in 240:
			if v.pos == float(v.target):
				break
			await tree.process_frame
		await frames(2)

	# A station: every stop.
	func stations() -> void:
		if not main.on_train:
			main.await_tower()
			main.open_train()
			await frames(2)
		var id := String(Stations.STATIONS[0]["id"])
		var stops: Array = Stations.stops(id)
		if light:
			stops = stops.slice(0, 2)
		for stop in stops:
			var name := "station %s" % stop
			if not wants(name):
				continue
			menu.go_station(id, stop)
			await look(name, page_tops())
		if menu.at_station():
			menu.leave_station()
		await frames(2)
