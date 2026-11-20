extends RefCounted
## The Engine's things (train_page.gd builds every car; this one's are
## here): the TOWER MAP, the six towers on the loop the train rides
## (travel.gd), each with the station near it, the one you're at, the fare
## to each and the lock; and a placard for the tower you chose:
##   the station you're at   its tower: what it's like, what goes with you,
##                           what a fall costs, and the lever that departs
##   another station         the ride: how many stops, the fare (your
##                           title's cut), and the lever that takes you
##                           there; or, before your first mark, the lock
## "Step off" (top right) gets off at the station you're at. The words are
## travel.gd's (the map, the ride) and train.gd's (the climb).

const Travel := preload("res://scripts/travel.gd")
const Stations := preload("res://scripts/stations.gd")
const Towers := preload("res://scripts/towers.gd")
const Train := preload("res://scripts/train.gd")
const TrainView := preload("res://scripts/train_view.gd")
const Gear := preload("res://scripts/gear.gd")
const Essence := preload("res://scripts/essence.gd")
const VesselPage := preload("res://scripts/vessel_page.gd")
const UI := preload("res://scripts/ui.gd")
const Art := preload("res://scripts/train_art.gd")

## A stop's plaque on the map: [computer, phone].
const STOP_SIZE := [Vector2(178, 62), Vector2(118, 48)]

var tp  # train_page.gd
var m  # menu.gd
var said := ""  # the last ride's line (shown once on the placard)
var said_bad := false


func _init(train_page) -> void:
	tp = train_page
	m = train_page.m


func _prof():
	return m.main.profile


func _price_tag() -> Control:
	return load("res://scripts/train_page.gd").PriceTag.new()


## The car's things: the map on its board, and the placard.
func build(root: Node) -> void:
	var prof = _prof()
	var small: bool = tp._small()
	var here := Travel.current(prof)
	if not Towers.TOWERS.has(m.train_tower):
		m.train_tower = Travel.tower_of(here)
	var row: HBoxContainer = tp._main_row(root)
	var board: VBoxContainer = tp._furnish(row, "board")
	# Its name, and Step off for the station you're at.
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	board.add_child(top)
	var h := Label.new()
	h.text = UI.title_case(Travel.TEXT["map_title"])
	h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.style_label(h, "display", 22 if small else 28, UI.GOLD)
	top.add_child(h)
	var off: Button = m._button(Travel.TEXT["step_off"], _step_off, top)
	off.custom_minimum_size = Vector2(96 if small else 120, 30 if small else 36)
	off.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	off.set_meta("go_station", here)
	off.set_meta("board", "stations")
	tp._brass(off, false)
	if not small:
		var sub: Label = tp._note(board, Travel.TEXT["map_sub"], 10.0)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var map := LoopMap.new()
	map.small = small
	map.here = here
	map.open = Travel.unlocked(prof)
	map.set_meta("travel_map", "map")
	map.set_meta("furnish", "map")  # (the Entity explains it under the pointer: entity_help.gd furnish:map)
	board.add_child(map)
	var sz: Vector2 = STOP_SIZE[1 if small else 0]
	for st in Travel.loop():
		var tower := Travel.tower_of(st)
		var b := MapStop.new()
		b.station = st
		b.tower = tower
		b.here = st == here
		b.home = st == Travel.home(prof)
		b.chosen = tower == m.train_tower
		b.locked = not map.open and st != here
		b.fare = Travel.fare(prof, st)
		b.best = int(prof.record.get("best", {}).get(tower, 0))
		b.custom_minimum_size = sz
		b.set_meta("tower", tower)
		var hf := _stop_facts(prof, st)  # (entity_help.gd "tower": its essence and beast, and where it is on the loop)
		hf.erase("tower")
		hf["where"] = String(Travel.TEXT["help_here"] if b.here else (Travel.TEXT["help_locked"] if b.locked else Travel.TEXT["help_ride"] % [hf["count"], hf["price"]]))
		b.set_meta("help_facts", hf)
		b.pressed.connect(_choose.bind(tower))
		map.add_child(b)
	if Travel.station_for(m.train_tower) == here or Travel.station_for(m.train_tower) == "":
		_climb_placard(row)
	else:
		_ride_placard(row, Travel.station_for(m.train_tower))


func _stop_facts(prof, st: String) -> Dictionary:
	var tower := Travel.tower_of(st)
	var n := Travel.stops(Travel.current(prof), st)
	return {"station": String(Stations.station(st).get("name", st)), "tower": String(Towers.TOWERS[tower].get("name", tower)),
		"price": str(Travel.fare(prof, st)), "count": "1 stop" if n == 1 else "%d stops" % n}


func _choose(tower: String) -> void:
	if m.train_tower == tower:
		return
	m.train_tower = tower
	said = ""
	m.main.sfx("ui_confirm", 1.0, -4.0, 0.0)
	m._want_focus = {"meta": "tower", "value": tower}
	m.open("train")


func _step_off() -> void:
	m.main.sfx("ui_confirm", 0.7, 0.0, 0.0)
	m.go_station(Travel.current(_prof()))


func _placard(row: Node) -> VBoxContainer:
	var small: bool = tp._small()
	var plac := TrainView.Furnish.new("placard", small)
	plac.custom_minimum_size.x = 240.0 if small else 330.0
	plac.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(plac)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3 if small else 6)
	plac.add_child(col)
	return col


func _said(col: Node) -> void:
	if said == "":
		return
	var l: Label = tp._note(col, said, 10.0)
	l.add_theme_color_override("font_color", UI.BAD if said_bad else UI.GOLD)


## The tower by the station you're at: the climb, and the lever.
func _climb_placard(row: Node) -> void:
	var prof = _prof()
	var small: bool = tp._small()
	var T: Dictionary = Train.TEXT
	var col := _placard(row)
	_said(col)
	var tw: Dictionary = Towers.TOWERS[m.train_tower]
	tp._tag(col, T["next_climb"])
	var name := Label.new()
	name.text = tw["name"]
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.style_label(name, "display", 22 if small else 25, Color(tw["torch"]).lerp(UI.TEXT, 0.35))
	col.add_child(name)
	var ess := HBoxContainer.new()
	ess.add_theme_constant_override("separation", 10)
	col.add_child(ess)
	var tag = _price_tag()
	tag.kind = tw["essence"]
	tag.text_override = T["essence"] % Essence.display(tw["essence"])
	tag.custom_minimum_size = Vector2(ThemeDB.fallback_font.get_string_size(tag.text_override, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 26.0, 20)
	ess.add_child(tag)
	var best := int(prof.record.get("best", {}).get(m.train_tower, 0))
	var bl := Label.new()
	bl.text = (T["best"] % best) if best > 0 else T["never"]
	bl.add_theme_font_size_override("font_size", 14)
	bl.add_theme_color_override("font_color", UI.DIM)
	ess.add_child(bl)
	if not small:
		tp._note(col, tw.get("blurb", ""), 10.0)
	var going: Array = prof.pack.map(func(g): return Gear.display(g))
	var n := 0
	for id in prof.supplies:
		n += int(prof.supplies[id])
	if n > 0:
		going.append("%d %s" % [n, "supply" if n == 1 else "supplies"])
	var vi: int = VesselPage.Vessel.packed_index(prof)
	if vi >= 0:  # (a vessel packed from the chest)
		going.append(VesselPage.V["going"] % VesselPage.Vessel.state_text(prof.vessels[vi]))
	var gl: Label = tp._note(col, T["depart_pack"] % (", ".join(going) if not going.is_empty() else T["depart_none"]), 10.0)
	gl.add_theme_color_override("font_color", UI.TEXT)
	tp._note(col, T["depart_risk"], 10.0)
	var Training = load("res://scripts/training.gd")
	if Training.closed(prof):
		# The towers are closed until the Noble's Grace (training.gd): a lock
		# where the lever would be, and what to do.
		var cl: Label = tp._note(col, String(Training.TEXT["closed"]) + " " + String(Training.TEXT["closed_how"]), 10.0)
		cl.add_theme_color_override("font_color", UI.BAD)
		var lk := LockPlate.new()
		lk.custom_minimum_size = Vector2(130, 76) if small else Vector2(150, 96)
		lk.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		lk.set_meta("grace_lock", m.train_tower)
		lk.set_meta("furnish", "grace_lock")
		col.add_child(lk)
		return
	var lever := TrainView.Lever.new()
	lever.word = T["lever"]
	lever.sub = T["lever_for"] % tw["short"]
	lever.custom_minimum_size = Vector2(130, 100) if small else Vector2(150, 140)
	lever.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lever.set_meta("depart", m.train_tower)
	lever.pressed.connect(_depart)
	col.add_child(lever)


## Another station: the ride there, or the lock.
func _ride_placard(row: Node, to: String) -> void:
	var prof = _prof()
	var small: bool = tp._small()
	var T: Dictionary = Travel.TEXT
	var col := _placard(row)
	_said(col)
	var st := Stations.station(to)
	var tower := Travel.tower_of(to)
	tp._tag(col, T["ride_tag"])
	var name := Label.new()
	name.text = String(st.get("name", to))
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UI.style_label(name, "display", 22 if small else 25, Color(st.get("lamp", UI.GOLD)).lerp(UI.TEXT, 0.3))
	col.add_child(name)
	var near: Label = tp._note(col, Travel.near(tower), 10.0)
	near.add_theme_color_override("font_color", UI.TEXT)
	var n := Travel.stops(Travel.current(prof), to)
	tp._note(col, "%s, %s" % [(String(T["stops_one"]) if n == 1 else String(T["stops_many"]) % n), T["shorter"]], 10.0)
	var f := Travel.fare(prof, to)
	var fr := HBoxContainer.new()
	fr.add_theme_constant_override("separation", 10)
	col.add_child(fr)
	var fl := Label.new()
	fl.text = String(T["fare"])
	UI.style_label(fl, "display", 17 if small else 19, UI.GOLD)
	fr.add_child(fl)
	var tag = _price_tag()
	tag.kind = "any"
	tag.text_override = "%d" % f
	tag.ok = int(prof.crystals_held()) >= f
	tag.custom_minimum_size = Vector2(64, 22)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	fr.add_child(tag)
	var cut := Travel.fare_cut(prof)
	if cut > 0.0:
		var cl: Label = tp._note(col, String(T["fare_cut"]) % int(round(cut * 100.0)), 10.0)
		cl.add_theme_color_override("font_color", UI.GOOD)
	if not small:
		tp._note(col, String(T["fare_note"]) % Travel.stop_fare(prof), 10.0)
	if not Travel.unlocked(prof):
		var ll: Label = tp._note(col, String(T["lock_why"]), 10.0)
		ll.add_theme_color_override("font_color", UI.BAD)
		var lk := LockPlate.new()
		lk.custom_minimum_size = Vector2(130, 76) if small else Vector2(150, 96)
		lk.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		lk.set_meta("travel_lock", to)
		lk.set_meta("furnish", "lock")
		col.add_child(lk)
		return
	var lever := TrainView.Lever.new()
	lever.word = T["ride"]
	lever.sub = String(T["ride_for"]) % String(st.get("short", st.get("name", to)))
	lever.custom_minimum_size = Vector2(130, 100) if small else Vector2(150, 140)
	lever.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	lever.set_meta("travel", to)
	lever.set_meta("help", "ride")
	lever.set_meta("help_facts", _stop_facts(prof, to))
	lever.pressed.connect(_ride.bind(to))
	col.add_child(lever)


func _depart() -> void:
	m.main.sfx("ui_confirm", 0.7, 0.0, 0.0)
	m.main.depart(m.train_tower)


## Rides the loop to a station: the fare paid, the climber there.
func _ride(to: String) -> void:
	var prof = _prof()
	var res := Travel.ride(prof, to)
	if not bool(res["ok"]):
		said = String(res["why"])
		said_bad = true
		m.main.sfx("ui_back", 0.8, -4.0, 0.0)
		m.open("train")
		return
	said = String(res["line"])
	said_bad = false
	m.train_tower = Travel.tower_of(to)
	m.main.sfx("train_whistle", 1.0, -4.0, 0.0)
	m._want_focus = {"meta": "depart", "value": m.train_tower}
	m.open("train")


# --- the drawn pieces ------------------------------------------------------------------------

## The map: the loop of track behind the six stops (a container: it lays the
## stops round the loop in tower order, starting top left, clockwise), the
## train on it where you are, and in the middle the fare a stop. Before the
## first mark the track past your station is dim and chained.
class LoopMap extends Container:
	const UI := preload("res://scripts/ui.gd")
	const Travel := preload("res://scripts/travel.gd")
	const Art := preload("res://scripts/train_art.gd")
	var small := false
	var here := ""
	var open := true

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	func _stop_size() -> Vector2:
		for c in get_children():
			if c is Control:
				return c.custom_minimum_size
		return Vector2(150, 56)

	func _gap() -> Vector2:
		return Vector2(8, 8) if small else Vector2(16, 12)

	func _get_minimum_size() -> Vector2:
		var s := _stop_size()
		var g := _gap()
		return Vector2(s.x * 3.0 + g.x * 2.0, s.y * 3.0 + g.y * 2.0)

	## Where each of the six stops' centres sit (loop order, clockwise from top left).
	func spots() -> Array:
		var s := _stop_size()
		var w := size.x
		var h := size.y
		var y0 := s.y * 0.5
		var y1 := h * 0.5
		var y2 := h - s.y * 0.5
		var x_in := w * 0.5 - s.x * 0.5 - _gap().x * 0.5
		var x_out := w * 0.5 + s.x * 0.5 + _gap().x * 0.5
		return [Vector2(x_in, y0), Vector2(x_out, y0), Vector2(w - s.x * 0.5, y1), Vector2(x_out, y2), Vector2(x_in, y2), Vector2(s.x * 0.5, y1)]

	func _notification(what: int) -> void:
		if what == NOTIFICATION_SORT_CHILDREN:
			var s := _stop_size()
			var sp := spots()
			var i := 0
			for c in get_children():
				if c is Control and i < sp.size():
					fit_child_in_rect(c, Rect2(sp[i] - s * 0.5, s))
					i += 1
			queue_redraw()

	func _draw() -> void:
		var sp := spots()
		var n := sp.size()
		var loop := Travel.loop()
		var hi := loop.find(here)
		var b := UI.Draw.Batch.new()
		for i in n:
			var a: Vector2 = sp[i]
			var c: Vector2 = sp[(i + 1) % n]
			# A segment is bright if it's open to you (any, once travel opens).
			var lit := open
			var col := Color(UI.TRAIN_BRASS, 0.85) if lit else Color(0.4, 0.38, 0.42, 0.55)
			var d := (c - a).normalized()
			var nrm := Vector2(-d.y, d.x)
			var len := a.distance_to(c)
			# Sleepers, then the two rails.
			var k := int(len / 12.0)
			for j in k:
				var p := a + d * (j + 0.5) * len / k
				b.line(p - nrm * 6.0, p + nrm * 6.0, Color(0.3, 0.2, 0.12, 0.8 if lit else 0.45), 3.0)
			b.line(a - nrm * 3.5, c - nrm * 3.5, col, 2.0)
			b.line(a + nrm * 3.5, c + nrm * 3.5, col, 2.0)
		b.flush(self)
		# The middle: the fare a stop (a gem and its number), or the chain.
		var mid := size * 0.5
		var font := UI.font("display")
		var fs := 15 if small else 18
		if open:
			var gb := UI.Draw.Batch.new()
			UI.gem_into(gb, mid + Vector2(-26 if small else -34, -4), 6.0 if small else 7.0, UI.GOLD)
			gb.flush(self)
			UI.draw_text(self, font, mid + Vector2(-16 if small else -22, 2), str(Travel.FARE), HORIZONTAL_ALIGNMENT_LEFT, 60.0, fs, UI.GILT_HI)
			UI.draw_text(self, UI.font("body"), mid + Vector2(-50, 18 if small else 22), String(Travel.TEXT["legend_fare"]), HORIZONTAL_ALIGNMENT_CENTER, 100.0, 11 if small else 13, UI.DIM)
		else:
			var lb := UI.Draw.Batch.new()
			LockPlate.padlock(lb, mid + Vector2(0, -6), 9.0 if small else 12.0, Color(0.85, 0.75, 0.55))
			lb.flush(self)
			UI.draw_text(self, UI.font("body"), mid + Vector2(-60, 18 if small else 24), String(Travel.TEXT["lock_short"]), HORIZONTAL_ALIGNMENT_CENTER, 120.0, 11 if small else 12, UI.DIM)


## A tower's stop on the map: its torch's colour along the top, its name,
## its station's city, and on the right the fare there, You're here (and a
## small train), or a padlock. The chosen one is lit in gold.
class MapStop extends Button:
	const Towers := preload("res://scripts/towers.gd")
	const Stations := preload("res://scripts/stations.gd")
	const Essence := preload("res://scripts/essence.gd")
	const Travel := preload("res://scripts/travel.gd")
	const UI := preload("res://scripts/ui.gd")
	var station := ""
	var tower := ""
	var here := false
	var home := false
	var chosen := false
	var locked := false
	var fare := 0
	var best := 0

	func _ready() -> void:
		focus_mode = Control.FOCUS_ALL
		for state in ["normal", "hover", "pressed"]:
			var bg := Color(0.09, 0.13, 0.12) if state == "normal" else Color(0.13, 0.18, 0.16)
			if locked:
				bg = Color(0.08, 0.08, 0.1) if state == "normal" else Color(0.11, 0.11, 0.13)
			if chosen:
				bg = Color(0.22, 0.17, 0.08) if state == "normal" else Color(0.28, 0.21, 0.1)
			var edge := Color(UI.GOLD, 0.95) if chosen else (Color(0.7, 0.9, 1.0, 0.8) if here else Color(UI.TRAIN_BRASS, 0.5 if state == "normal" else 0.85))
			add_theme_stylebox_override(state, UI.box(bg, edge, 5, 2 if chosen or here else 1))

	func _draw() -> void:
		var t: Dictionary = Towers.TOWERS[tower]
		var small := size.y < 56.0
		var dim := 0.5 if locked else 1.0
		draw_rect(Rect2(Vector2(4, 4), Vector2(size.x - 8, 4)), Color(t["torch"], 0.8 * dim))
		# A phone: the fare (or train, or padlock) beside the name, and the
		# city under both, the whole width; a computer: those on the right.
		var right := 36.0 if small else 56.0
		var ink := (UI.GILT_HI if chosen else UI.TEXT) if not locked else UI.FAINT
		UI.draw_text_fit(self, UI.font("display"), Vector2(10, 22 if small else 29), String(t["short"]), HORIZONTAL_ALIGNMENT_LEFT, size.x - right - 12.0, 16 if small else 21, ink)
		var city := String(Stations.station(station).get("short", station))
		var b := UI.Draw.Batch.new()
		var gy := 36.0 if small else 46.0
		UI.gem_into(b, Vector2(14, gy), 4.0 if small else 5.0, Color(Essence.color(t["essence"]), dim))
		var c := Vector2(size.x - right * 0.5 - 2.0, 17.0 if small else size.y * 0.5 + 1.0)
		if here:
			_train(b, c, 8.0 if small else 11.0)
		elif locked:
			LockPlate.padlock(b, c, 6.0 if small else 9.0, Color(0.75, 0.68, 0.55))
		else:
			UI.gem_into(b, c + Vector2(-8 if small else -12, 0), 4.0 if small else 5.5, UI.GOLD)
		b.flush(self)
		var cx := 22.0 if small else 25.0
		UI.draw_text_fit(self, UI.font("body"), Vector2(cx, gy + 4.0), city, HORIZONTAL_ALIGNMENT_LEFT, size.x - cx - (6.0 if small else right + 2.0), 11 if small else 12, UI.DIM if not locked else UI.FAINT)
		if not here and not locked:
			UI.draw_text(self, UI.font("display"), c + Vector2(-2 if small else -4, 5 if small else 7), str(fare), HORIZONTAL_ALIGNMENT_LEFT, 40.0, 14 if small else 18, UI.GILT_HI)
		if here and not small:
			UI.draw_text(self, UI.font("body"), Vector2(size.x - right - 4.0, size.y - 7.0), String(Travel.TEXT["here"]), HORIZONTAL_ALIGNMENT_CENTER, right + 2.0, 11, Color(0.7, 0.9, 1.0))
		if home and not small:
			UI.draw_text(self, UI.font("body"), Vector2(size.x - right - 64.0, 18.0), String(Travel.TEXT["home"]), HORIZONTAL_ALIGNMENT_RIGHT, 56.0, 11, Color(UI.GOLD, 0.8))

	## A small locomotive: boiler, cab, stack and wheels.
	func _train(b, c: Vector2, s: float) -> void:
		var body := Color(0.7, 0.9, 1.0)
		b.rect(Rect2(c + Vector2(-s, -s * 0.35), Vector2(s * 1.3, s * 0.7)), body)
		b.rect(Rect2(c + Vector2(s * 0.3, -s * 0.8), Vector2(s * 0.7, s * 1.15)), body.darkened(0.15))
		b.rect(Rect2(c + Vector2(-s * 0.75, -s * 0.85), Vector2(s * 0.3, s * 0.5)), body.darkened(0.25))
		b.circle(c + Vector2(-s * 0.6, s * 0.5), s * 0.28, Color(0.25, 0.3, 0.35), 10)
		b.circle(c + Vector2(s * 0.55, s * 0.5), s * 0.28, Color(0.25, 0.3, 0.35), 10)


## The lock on the placard, before the first mark: an iron plate, a chain
## and a padlock where the lever would be.
class LockPlate extends Control:
	const UI := preload("res://scripts/ui.gd")

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_PASS

	func _draw() -> void:
		var b := UI.Draw.Batch.new()
		var plate := Rect2(4, 4, size.x - 8, size.y - 8)
		b.rect(plate.grow(1.5), UI.OUTLINE)
		b.rect(plate, UI.TRAIN_IRON.darkened(0.1))
		# A chain across it.
		var y := plate.get_center().y
		var n := int(plate.size.x / 14.0)
		for i in n:
			var x := plate.position.x + 7.0 + i * 14.0
			b.arc(Vector2(x, y), 5.0, 0.0, TAU, 10, Color(0.55, 0.52, 0.5), 2.0)
		padlock(b, plate.get_center() + Vector2(0, 4), minf(plate.size.y * 0.22, 16.0), Color(0.86, 0.72, 0.4))
		b.flush(self)

	## A padlock: a shackle over a body with a keyhole.
	static func padlock(b, c: Vector2, s: float, col: Color) -> void:
		UI.lock_into(b, c, s * 2.0, col)
