extends RefCounted
## THE ENTITY'S TOURS (menu.gd owns one: menu.tour). At a station it shows
## the gym, the tournament grounds, the Noble's estate and the train; the
## first time the train is chosen, its cars, from the climbers' car to the
## engine and its tower map. The steps and their words are travel.gd TOURS.
##
## Each step goes where it says (a station's stop, a train car) and the
## Entity's sphere (entity_helper.gd) glides beside what it points at, with
## a short line in its bubble; the page shows the tour's bar at its top: the
## step's words, Back, Next (Done on the last) and Skip the tour, ordinary
## buttons, so the mouse, keys, controller and touch all work as anywhere.
##
## A tour starts by itself the first time (with the Entity's tips on; told
## once per climber, guide.gd: "tour_station", "tour_train", which are also
## its Archive entries), and again from the Entity's talk ("Show me around
## again"). Leaving the station ends the station's tour, leaving the train
## the train's (done for good: it can be replayed).

const Travel := preload("res://scripts/travel.gd")
const Entity := preload("res://scripts/entity.gd")
const Guide := preload("res://scripts/guide.gd")
const UI := preload("res://scripts/ui.gd")

var m  # the menu
var which := ""  # "station", "train" or "" (none running)
var step := 0
var shown := 0  # steps shown (tests)


func _init(menu) -> void:
	m = menu


func active() -> bool:
	return which != ""


func steps() -> Array:
	return Travel.TOURS.get(which, [])


func current() -> Dictionary:
	var list := steps()
	return list[step] if step >= 0 and step < list.size() else {}


## Told already (it starts by itself only once per climber).
static func seen(kind: String) -> bool:
	return Guide.told("tour_" + kind)


## Tours start by themselves: always in the game; in tests only when one
## asks (the "sixfold_tours" meta), so other tests' first-time tips show.
static func auto_on() -> bool:
	return Guide.live() and (not Engine.has_meta("sixfold_test") or Engine.has_meta("sixfold_tours"))


## Starts a tour by itself the first time (tips on, not told yet). Only
## sets where it is: the page being built shows it. True if started.
func maybe_start(kind: String) -> bool:
	if active() or not auto_on() or not Guide.tips_on() or seen(kind) or Travel.TOURS.get(kind, []).is_empty():
		return false
	which = kind
	step = 0
	_place()
	return true


## Starts a tour now (the Entity's talk), and goes to its first step.
func start(kind: String) -> void:
	if Travel.TOURS.get(kind, []).is_empty() or m.main == null or not m.main.on_train:
		return
	which = kind
	step = 0
	_go()


## "tour:station" or "tour:train" (a choice in the Entity's talk).
func act(what: String) -> void:
	if what.begins_with("tour:"):
		start(what.get_slice(":", 1))


func next() -> void:
	if not active():
		return
	step += 1
	if step >= steps().size():
		finish()
		m._want_focus = {}
		m.open(m.page if m.page in ["station", "train"] else ("station" if m.at_station() else "train"))
		return
	m._want_focus = {"meta": "tour", "value": "next"}
	_go()


func back() -> void:
	if not active() or step <= 0:
		return
	step -= 1
	m._want_focus = {"meta": "tour", "value": "back" if step > 0 else "next"}
	_go()


func skip() -> void:
	if not active():
		return
	finish()
	if m.main != null:
		m.main.sfx("ui_back")
	m.open("station" if m.at_station() else "train")


## Ends the tour: told for good (it can be replayed from the talk).
func finish() -> void:
	if which != "":
		Guide.also_told("tour_" + which)
	which = ""
	step = 0


## The station's tour on the train, the train's at the station: it's over.
func check() -> void:
	if not active():
		return
	if (which == "station" and not m.at_station() and m.page == "train") or (which == "train" and m.at_station()):
		finish()


## Puts the menu where the step is, without opening anything.
func _place() -> void:
	var s := current()
	if which == "station":
		if s.has("stop") and m.station_page.stop_ids().has(String(s["stop"])):
			m.station_page.stop = String(s["stop"])
	elif s.has("car"):
		m.train_car = String(s["car"])
	shown += 1


## Goes to the step: its stop or car, the page built again.
func _go() -> void:
	var s := current()
	if m.main != null:
		m.main.sfx("tip_chime", 1.15, -8.0, 0.03)
	if which == "station":
		if not m.at_station():
			m.go_station(Travel.current(m.main.profile), String(s.get("stop", "")))
		_place()
		m.open("station")
		return
	if m.at_station():
		m.station_page.station = ""
	_place()
	m.open("train")


# --- what it points at ------------------------------------------------------------------

## The thing the step points at, showing on the screen (null for none):
## a rail entry, or something in the page (the car you're in) tagged so.
func target() -> Control:
	if not active():
		return null
	if (which == "station" and m.page != "station") or (which == "train" and m.page != "train"):
		return null
	var s := current()
	var pt: Array = s.get("point", [])
	if pt.size() < 2:
		return null
	if which == "train" and String(s.get("car", m.train_car)) != String(m.train_car):
		return null
	var tag := String(pt[0])
	var val := String(pt[1])
	if m.rail != null and m.rail.visible:
		for b in m.rail.buttons:
			if is_instance_valid(b) and ((tag == "rail" and String(b.id) == val) or (b.has_meta(tag) and str(b.get_meta(tag)) == val)) and b.is_visible_in_tree():
				return b
	var root: Node = m.box
	if which == "train" and m.train_page != null:
		root = m.train_page.roots.get(m.train_car, null)
	if root == null or not is_instance_valid(root):
		return null
	for c in root.find_children("*", "Control", true, false):
		if c.has_meta(tag) and str(c.get_meta(tag)) == val and c.is_visible_in_tree():
			return c
	return null


## The Entity's words in the bubble beside it.
func point_words() -> String:
	return String(current().get("point_say", ""))


## "Tour · 2 of 9", under the bubble's words.
func count_words() -> String:
	return String(Travel.TEXT["tour_tag"]) % [step + 1, steps().size()]


# --- the bar ------------------------------------------------------------------------------

## The tour's bar at the top of the page: the Entity's face and the step's
## words, then Back, Next (Done) and Skip the tour.
func bar(parent: Node, small: bool) -> Control:
	var s := current()
	var row := Entity.says(String(s.get("say", "")), 30.0 if small else 40.0, count_words(), false)
	row.set_meta("tour_bar", which)
	row.set_meta("arrange", "note")
	var col: Node = row.get_child(1).get_child(0)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 6 if small else 10)
	col.add_child(btns)
	var T: Dictionary = Travel.TEXT
	if step > 0:
		btns.add_child(_btn(String(T["tour_back"]), "back", back, small))
	var last := step >= steps().size() - 1
	btns.add_child(_btn(String(T["tour_done"] if last else T["tour_next"]), "next", next, small))
	btns.add_child(_btn(String(T["tour_skip"]), "skip", skip, small))
	parent.add_child(row)
	return row


func _btn(text: String, id: String, action: Callable, small: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(0, 30 if small else 34)
	b.add_theme_font_size_override("font_size", 14 if small else 16)
	b.set_meta("tour", id)
	b.set_meta("help", "tour:" + id)
	b.pressed.connect(action)
	return b
