extends RefCounted
## A station's page (menu.gd's "station" page): the menu's rail down the
## left lists the station's stops (rail.gd, in station mode) and "Back to
## the train"; the stop you're at fills the rest, over the station drawn
## behind it (station_view.gd). Each stop is a list on the left and a card
## on the right (the card goes under the list on a narrow screen):
##   gym     Training: the basics (lessons with the Entity: Begin, Skip) and
##           the medal drills (goal, medals, fee, Begin)
##   arena   the Tournament: its master's word and the brackets (rounds,
##           fee, prize, Enter)
##   noble   the Noble: titles (what each needs, what it gives; Be named,
##           Wear) and contracts (held and on offer; Take, Give it up)
##   board   the Renown Board: what the next rank opens, every rank (a tile
##           each; its card says what it opens), recent deeds, the climbers
##           you've met (rivals.gd)
## Every stop starts with a gauge of your renown and rank; a rank newly
## reached is said at the top once, with what it opens. Focusing a tile
## (the keys, the mouse) shows its card; pressing it (or a tap) does too,
## and with the keys puts the focus on the card's button. Q / E (LB / RB)
## move between stops. The words are in stations.gd, renown.gd, titles.gd,
## noble.gd and contracts.gd.

const Stations := preload("res://scripts/stations.gd")
const Renown := preload("res://scripts/renown.gd")
const Titles := preload("res://scripts/titles.gd")
const Noble := preload("res://scripts/noble.gd")
const Contracts := preload("res://scripts/contracts.gd")
const Entity := preload("res://scripts/entity.gd")
const StationView := preload("res://scripts/station_view.gd")
const UI := preload("res://scripts/ui.gd")
const Essence := preload("res://scripts/essence.gd")
const Towers := preload("res://scripts/towers.gd")
const TrainPage := preload("res://scripts/train_page.gd")
const Rivals := preload("res://scripts/rivals.gd")
const Travel := preload("res://scripts/travel.gd")
const Training := preload("res://scripts/training.gd")
const Tournaments := preload("res://scripts/tournaments.gd")

static var T := Stations.TEXT
static var TT := Training.TEXT
static var TM := Tournaments.TEXT
static var N := Noble.TEXT

var m  # the menu
var station := ""  # the station you're at ("" when not at one)
var stop := "gym"
var picks := {}  # stop -> the key whose card shows ("lesson:move", "bracket:novice", "title:x"...)
var lines: Array = []  # the last result or answer, shown on its card
var lines_for := ""  # ...the key it belongs to
var card: VBoxContainer
var tiles: Array = []
var said := {}  # stop -> the Entity's (or the Noble's) word at its top this visit
var rank_said := ""  # a rank newly reached, said at the top this visit


func _init(menu) -> void:
	m = menu


func _prof():
	return m.main.profile


func _small() -> bool:
	return m.compact()


## How wide the page can be on this screen (the rail and the panel's margins
## taken off): columns and lines are never wider than this.
func _avail() -> float:
	var vw: float = m.get_viewport_rect().size.x if m.is_inside_tree() else 1280.0
	var rw: float = m.RailScript.width_for(_small()) if m.rail_showing() else 0.0
	return maxf(160.0, vw - rw - (12.0 if _small() else 32.0) - (24.0 if _small() else 44.0) - 30.0)


## The stops of the station you're at.
func stop_ids() -> Array:
	return Stations.stops(station)


## Arriving (from the engine's lever, or back from the arena).
func arrive(id: String, at := "", pick := "", words: Array = []) -> void:
	var arriving := station == ""
	if arriving and words.is_empty() and m.main != null and m.main.profile != null:
		Renown.on_visit(m.main.profile)  # (a stop counted: the Newcomer's title, the Noble's new offers)
	if arriving:
		said = {}
		rank_said = ""
	station = id if Stations.station_ids().has(id) else String(Stations.STATIONS[0]["id"])
	var ids := stop_ids()
	stop = at if ids.has(at) else (ids[0] if not ids.is_empty() else "gym")
	if arriving and words.is_empty() and m.get("tour") != null:
		m.tour.maybe_start("station")  # (the first time at a station: the Entity shows you round)
	if pick != "":
		picks[stop] = pick
	lines = words
	lines_for = pick if pick != "" else ""


## Q / E: the next stop.
func cycle(by: int) -> bool:
	var ids := stop_ids()
	if ids.is_empty():
		return false
	go_stop(ids[(ids.find(stop) + by + ids.size()) % ids.size()], true)
	return true


func go_stop(id: String, keep_rail := false) -> void:
	if not stop_ids().has(id):
		return
	stop = id
	if keep_rail or (m.rail != null and m.rail.has_focus_inside()):
		m._rail_focus = true
	m.open("station")


# --- the page -------------------------------------------------------------------------

func build() -> void:
	var prof = _prof()
	var st := Stations.station(station)
	var small := _small()
	var info: Dictionary = Stations.STOPS.get(stop, {})
	if m.get("tour") != null:
		m.tour.check()
	m._header(Stations.stop_name(stop), String(info.get("sub", "")), String(st.get("name", "")))
	var crest := StationView.Crest.new()
	crest.station = st
	crest.home = station == Travel.home(prof)
	crest.custom_minimum_size = Vector2(minf(420.0, _avail()), 26 if small else 30)
	crest.set_meta("station_crest", station)
	m.box.add_child(crest)
	var bar := StationView.RenownBar.new()
	bar.profile = prof
	bar.custom_minimum_size = Vector2(minf(280.0, _avail()), 34 if small else 40)
	bar.set_meta("renown_bar", true)
	m.box.add_child(bar)
	_top_words(prof)
	m._gap(2 if small else 6)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12 if small else 18)
	row.set_meta("station_row", true)
	m.box.add_child(row)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 5 if small else 7)
	left.custom_minimum_size.x = minf(300.0 if small else 380.0, _avail())
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	var plac := PanelContainer.new()
	plac.add_theme_stylebox_override("panel", TrainPage.brass_box(10.0 if small else 14.0, 8.0))
	plac.custom_minimum_size.x = minf(290.0 if small else 360.0, _avail())
	plac.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	plac.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	plac.set_meta("station_card", true)
	row.add_child(plac)
	card = VBoxContainer.new()
	card.add_theme_constant_override("separation", 5 if small else 7)
	plac.add_child(card)
	tiles.clear()
	match stop:
		"gym":
			_gym(left)
		"arena":
			_arena(left)
		"noble":
			_noble(left)
		"board":
			_board(left)
	var keys: Array = tiles.map(func(tl): return String(tl.get_meta("pick")))
	var pk := String(picks.get(stop, ""))
	if not keys.has(pk):
		pk = _default_pick(keys)
	picks[stop] = pk
	_mark_chosen()
	_card()


## The tile a stop opens on: the next lesson, the first open bracket, a
## title ready to grant (else the one worn), the next rank.
func _default_pick(keys: Array) -> String:
	var prof = _prof()
	var want := ""
	match stop:
		"gym":
			var left := Stations.lessons_left(prof)
			want = "lesson:" + String(left[0]) if not left.is_empty() else ""
		"arena":
			if Training.closed(prof) or (Training.required(prof) and not Training.first_done(prof)):
				want = "first:first"
		"noble":
			if Training.closed(prof):
				want = "grace:grace"
				return want if keys.has(want) else (keys[0] if not keys.is_empty() else "")
			var offer := Renown.on_offer(prof)
			if not offer.is_empty():
				want = "title:" + String(offer[0])
			elif Renown.worn_id(prof) != "":
				want = "title:" + Renown.worn_id(prof)
		"board":
			want = "rank:%d" % mini(Renown.rank(prof) + 1, Renown.RANKS.size() - 1)
	if keys.has(want):
		return want
	return keys[0] if not keys.is_empty() else ""


## What's said at the top of a stop: a rank newly reached (once, with what
## it opens), the Entity's first-time word for the stop, the refund of an
## old save's boons.
func _top_words(prof) -> void:
	var main = m.main
	if main == null:
		return
	var ru := Renown.unseen_rank(prof, true)
	if ru >= 0:
		var words := Renown.rank_words(ru)
		rank_said = "%s %s" % [Entity.line("rank_up", -1, {"rank": Renown.rank_name(ru)}), String(words[1])]
		main.GuideScript.also_told("rank_up")
		main.sfx("clear", 1.25, -4.0, 0.0)
	if rank_said != "":
		var r1 := Entity.says(rank_said, 28.0 if _small() else 34.0, String(Renown.rank_words(Renown.rank(prof))[0]))
		r1.set_meta("entity", "rank")
		r1.set_meta("arrange", "note")  # (Arrange mode: a note, so the list's row keeps its name)
		m.box.add_child(r1)
	if m.get("tour") != null and m.tour.active() and m.tour.which == "station":
		m.tour.bar(m.box, _small())  # (the Entity's tour: its words, Next and Skip; the stop's own tips wait)
		return
	if not said.has(stop):
		var bits: Array = []
		var refund := String(Renown.state(prof).get("refund", ""))
		if refund != "":
			bits.append(refund)
			Renown.state(prof).erase("refund")
			prof.save()
		for id in stop_tips(prof):
			var one: String = main.tip_now(id)
			if one != "":
				bits.append(one)
		said[stop] = "\n".join(bits)
	if String(said[stop]) != "":
		var mode := "touch" if main.touch_active else ("pad" if main.pad_active else "keys")
		var row := Entity.says(Entity.fill_keys(String(said[stop]), mode, main.pad_ps), 28.0 if _small() else 34.0)
		row.set_meta("entity", stop)
		row.set_meta("arrange", "note")
		m.box.add_child(row)


## The Entity's first-time tips for each stop (entity.gd TIPS).
const STOP_TIPS := {"gym": ["station", "training"], "arena": ["tournament"], "noble": ["noble", "titles_social", "contracts"], "board": ["renown_board"]}


## The tips for the stop you're at now: before the Grace, the Grace and
## basic training (training.gd); then what has opened since (advanced and
## mark training, the first rewards, the Tournament Manager).
func stop_tips(prof) -> Array:
	var ids: Array = STOP_TIPS.get(stop, []).duplicate()
	var closed := Training.closed(prof)
	match stop:
		"gym":
			if closed:
				ids = ["grace", "basic_training"]
			else:
				if Training.title_rank(prof) >= 0:
					ids.append("advanced_training")
				if Training.marked(prof):
					ids.append("mark_training")
		"arena":
			if closed:
				ids = ["first_tournament"] if Training.basic_done(prof) else ["grace"]
			else:
				if Training.first_done(prof):
					ids.push_front("first_rewards")
				ids.append("tourney_manager")
		"noble":
			if closed:
				ids.push_front("grace")
	return ids


## Where the keys start: the chosen tile.
func first_focus(list: Array) -> int:
	for j in list.size():
		if list[j].has_meta("tour") and String(list[j].get_meta("tour")) == "next":
			return j  # (the Entity's tour: on to its next step)
	var pk := String(picks.get(stop, ""))
	var i: int = list.map(func(b): return String(b.get_meta("pick", ""))).find(pk)
	return maxi(i, 0)


func _tile(parent: Node, key: String, head: String, line: String, icon: String, tint := Color(0.86, 0.64, 0.3)):
	var tl = StationView.Tile.new()
	tl.head = head
	tl.line = line
	tl.icon_id = icon
	tl.tint = tint
	tl.touch = m.main != null and m.main.touch_active
	tl.custom_minimum_size = Vector2(0, 46 if _small() else 54)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tl.set_meta("pick", key)
	tl.focus_entered.connect(_focused.bind(key))
	tl.pressed.connect(_pressed.bind(key))
	parent.add_child(tl)
	tiles.append(tl)
	return tl


func _section(parent: Node, text: String) -> Label:
	var l := Label.new()
	l.text = text
	UI.style_label(l, "eyebrow", UI.SIZE_EYEBROW, Color(UI.GOLD, 0.85))
	parent.add_child(l)
	return l


func _focused(key: String) -> void:
	if m.main != null and m.main.touch_active:
		return  # (a tap presses)
	if key != String(picks.get(stop, "")):
		_select(key)


func _pressed(key: String) -> void:
	_select(key)
	if m.nav_keys and not (m.main != null and m.main.touch_active):
		var first := _card_first()
		if first != null:
			first.grab_focus()
	elif _small():
		m.scroll.ensure_control_visible.call_deferred(card)


func _select(key: String) -> void:
	if key == String(picks.get(stop, "")) and card != null and card.get_child_count() > 0:
		return
	picks[stop] = key
	if key != lines_for:
		lines = []
	_mark_chosen()
	_card()


func _mark_chosen() -> void:
	var pk := String(picks.get(stop, ""))
	for tl in tiles:
		if is_instance_valid(tl):
			tl.chosen = String(tl.get_meta("pick")) == pk
			tl.restyle()


## The card's first button (Begin, Be named, Take...), or null.
func _card_first() -> Button:
	if card == null:
		return null
	for b in card.find_children("*", "Button", true, false):
		if b.is_visible_in_tree() and not b.disabled:
			return b
	return null


func back() -> void:
	var f: Control = m.get_viewport().gui_get_focus_owner()
	if f != null and card != null and is_instance_valid(card) and card.is_ancestor_of(f):
		for tl in tiles:
			if is_instance_valid(tl) and tl.chosen:
				m.main.sfx("ui_back")
				tl.grab_focus()
				return
	if f != null and not m.rail.buttons.has(f) and m.nav_keys and not (m.main != null and m.main.touch_active):
		m.main.sfx("ui_back")
		m.rail.focus_current()
		return
	m.leave_station()


# --- the stops -------------------------------------------------------------------------

## Training: the basics, then the medal drills.
func _gym(left: Node) -> void:
	var prof = _prof()
	var r := Renown.state(prof)
	var done_n := Stations.LESSON_ORDER.size() - Stations.lessons_left(prof).size()
	_section(left, "%s  ·  %s" % [TT["basic"], T["lessons_count"] % [done_n, Stations.LESSON_ORDER.size()]])
	if Training.closed(prof):
		_line(left, TT["basic_note"], UI.GILT_HI)  # (required for the Noble's Grace: training.gd)
	elif not _small():
		_line(left, TT["basic_note_done"] if Stations.lessons_done(prof) else T["lessons_note"] % Stations.LESSON_REWARD, UI.DIM)
	for id in Stations.LESSON_ORDER:
		if not Stations.LESSONS.has(id):
			continue
		var st := Stations.lesson_state(prof, id)
		var line: String = T["lesson_done"] if st == 1 else (T["lesson_skipped"] if st == 2 else Stations.lesson_goal(id))
		var tl = _tile(left, "lesson:" + id, String(Stations.LESSONS[id]["name"]), line, "lesson", UI.GILT if st > 0 else Color(0.62, 0.78, 1.0))
		tl.lit = st == 1
		tl.medal = 3 if st == 1 else -1
	if Training.closed(prof):
		return  # (the rest opens with the Grace)
	_training_list(left, TT["advanced"], TT["advanced_note"], Training.ADVANCED_ORDER, false)
	_training_list(left, TT["mark_training"], TT["mark_note"], Training.MARK_ORDER, true)
	_section(left, T["drills"])
	for id in Stations.DRILL_ORDER:
		if not Stations.DRILLS.has(id):
			continue
		var d: Dictionary = Stations.DRILLS[id]
		var open := Stations.drill_unlocked(prof, id)
		var line := ""
		if bool(d.get("extra", false)) and not open:
			line = T["extra"]
		elif not open:
			line = T["locked_short"] % Renown.rank_name(int(d.get("rank", 0)))
		elif r["best"].has(id):
			line = T["best"] % Stations.score_text(id, float(r["best"][id]))
		else:
			line = T["never"]
		var tl = _tile(left, "drill:" + id, String(d["name"]), line, "gym")
		tl.locked = not open
		tl.medal = -1 if not open else int(r["drills"].get(id, 0))


## Advanced or mark training: its tiers, each lesson a tile (locked until
## its tier's title, or for mark training the first mark).
func _training_list(left: Node, head: String, note: String, order: Array, mark: bool) -> void:
	var prof = _prof()
	_section(left, head)
	if not _small():
		_line(left, note, UI.DIM)
	if mark and not Training.marked(prof):
		_line(left, TT["mark_locked"], UI.FAINT)
	for id in order:
		var d := Training.lesson(String(id))
		if d.is_empty():
			continue
		var tier := int(d.get("tier", 0))
		var locked := not Training.tier_open(prof, tier) or (mark and not Training.marked(prof))
		var line := ""
		if locked:
			line = TT["mark_locked"] if mark and not Training.marked(prof) else Training.locked_text(tier)
		elif Training.done(prof, String(id)):
			line = TT["adv_done"]
		else:
			line = "%s  ·  %s" % [String(Training.TIERS[tier]["name"]), TT["fee_kind"] % [Training.fee(prof, String(id)), Essence.display(Training.fee_kind(prof, String(id)))]]
		var tl = _tile(left, "advanced:" + String(id), String(d["name"]), line, "lesson" if not mark else "gym", Color(0.86, 0.7, 1.0) if mark else Color(0.62, 0.9, 0.8))
		tl.locked = locked
		tl.lit = Training.done(prof, String(id))
		tl.medal = 3 if Training.done(prof, String(id)) else -1


## The tournament: before the Grace, your first tournament; after it, the
## travelling Tournament Manager (tournaments.gd), where they are, and the
## brackets they run.
func _arena(left: Node) -> void:
	var prof = _prof()
	if Training.required(prof) and not Training.first_done(prof):
		_section(left, TT["first"])
		_line(left, TT["first_sub"], UI.GOLD)
		var open := Training.first_open(prof)
		var tl = _tile(left, "first:first", String(TT["first"]), TT["first_line"] if open else TT["first_locked"], "arena", UI.GILT_HI)
		tl.locked = not open
		return
	var here := Tournaments.at(prof, station)
	_section(left, TM["manager"])
	if not said.has("master"):
		said["master"] = Tournaments.line("here" if here else "away")
	_line(left, String(said["master"]), UI.GOLD)
	var mt = _tile(left, "manager:here", TM["here"] if here else TM["away"] % Tournaments.station_name(Tournaments.here(prof)),
		String(Tournaments.location(station).get("line", "")) if here else TM["away_line"] % Tournaments.station_name(Tournaments.next(prof)), "arena", UI.GILT if here else UI.FAINT)
	mt.lit = here
	for b in Stations.BRACKETS:
		var id := String(b["id"])
		var open := Stations.bracket_open(prof, id)
		var line := ""
		if not here:
			line = TM["away_short"] % Tournaments.station_name(Tournaments.here(prof))
			open = false
		elif not open:
			line = T["locked_short"] % Renown.rank_name(int(b.get("rank", 0)))
		elif Stations.bracket_won(prof, id):
			line = T["won"] + "  ·  " + Stations.wins_text(Stations.bracket_wins(prof, id))
		elif Stations.best_rounds(prof, id) > 0:
			line = T["best_rounds"] % [Stations.best_rounds(prof, id), (b["rounds"] as Array).size()]
		else:
			line = T["never"]
		var tw: Dictionary = Towers.TOWERS.get(String(b.get("tower", "")), {})
		var tl = _tile(left, "bracket:" + id, String(b["name"]), line, "arena", Color(tw.get("torch", UI.TRAIN_BRASS)))
		tl.locked = not open
		tl.lit = Stations.bracket_won(prof, id)
		tl.medal = 3 if Stations.bracket_won(prof, id) else -1


## The Noble: a word, the titles, the contracts.
func _noble(left: Node) -> void:
	var prof = _prof()
	_section(left, Noble.name_of(station))
	if not said.has("noble_line"):
		said["noble_line"] = Noble.greet(prof)  # (now and then a rumour of the guardians: guardian_lessons.gd)
	_line(left, String(said["noble_line"]), UI.GOLD)
	if Training.required(prof):
		# The Noble's Grace (training.gd): what lets a climber into the towers.
		var gt = _tile(left, "grace:grace", String(TT["grace"]), TT["grace_have"] if Training.has_grace(prof) else TT["grace_not"], "title", UI.GILT if Training.has_grace(prof) else UI.GILT_HI)
		gt.lit = Training.has_grace(prof)
		gt.medal = 3 if Training.has_grace(prof) else -1
	_section(left, N["contracts"])
	if not _small():
		_line(left, N["contracts_note"] % Contracts.most(prof), UI.DIM)
	var held: Array = Contracts.active(prof)
	if not held.is_empty():
		_line(left, N["held"], UI.GILT)
	for o in held:
		var tl = _tile(left, "contract:" + String(o["id"]), Contracts.name_of(o), Contracts.progress_of(o), "contract", Contracts.KINDS_COLOR)
		tl.lit = true
	var offers: Array = Contracts.offers(prof)
	_line(left, N["on_offer"] if not offers.is_empty() else N["none_offered"], UI.GILT if not offers.is_empty() else UI.DIM)
	for o in offers:
		_tile(left, "contract:" + String(o["id"]), Contracts.name_of(o), Contracts.reward_text(o), "contract", Color(0.78, 0.7, 0.86))
	_section(left, N["titles"])
	if not _small():
		_line(left, N["titles_note"], UI.DIM)
	_line(left, Travel.TEXT["shared_titles"], UI.DIM)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	left.add_child(grid)
	for id in Renown.TITLE_ORDER:
		if not Renown.TITLES.has(id):
			continue
		var tl = _tile(grid, "title:" + id, Renown.title_name(id), _title_line(prof, id), "title", _title_tint(prof, id))
		tl.locked = not Renown.has_title(prof, id) and not Renown.grantable(prof, id)
		tl.lit = Renown.worn_id(prof) == id or Renown.grantable(prof, id)
		tl.custom_minimum_size.x = minf(150.0 if _small() else 180.0, _avail() * 0.5 - 4.0)


func _title_line(prof, id: String) -> String:
	if Renown.worn_id(prof) == id:
		return N["tile_worn"]
	if Renown.has_title(prof, id):
		return N["tile_have"]
	if Renown.grantable(prof, id):
		return N["tile_ready"]
	var need := int(Renown.TITLES[id].get("rank", 0))
	if Renown.rank(prof) < need:
		return N["tile_needs"] % Renown.rank_name(need)
	return String(Renown.TITLES[id].get("deed", ""))


func _title_tint(prof, id: String) -> Color:
	if Renown.has_title(prof, id) or Renown.grantable(prof, id):
		return UI.GILT
	return UI.FAINT


## The Renown Board: what the next rank opens, every rank, deeds, climbers met.
func _board(left: Node) -> void:
	var prof = _prof()
	var r := Renown.state(prof)
	var rk := Renown.rank(prof)
	if rk < Renown.RANKS.size() - 1:
		_section(left, T["next_rank"] % Renown.next_text(prof))
		_line(left, T["next_opens"] % Renown.rank_name(rk + 1) + " " + ", ".join(Renown.opens(rk + 1)), UI.TEXT)
	else:
		_section(left, T["top_rank"])
	_section(left, T["ranks"])
	for i in Renown.RANKS.size():
		var reached := i <= rk
		var line := "%d  ·  %s" % [Renown.needed(i), ", ".join(Renown.opens(i))]
		var tl = _tile(left, "rank:%d" % i, Renown.rank_name(i), line, "board", UI.GILT if reached else (UI.GILT_HI if i == rk + 1 else UI.FAINT))
		tl.lit = i == rk
		tl.medal = 3 if reached else -1
	_section(left, T["deeds"])
	var deeds: Array = (r["deeds"] as Array).duplicate()
	deeds.reverse()
	if deeds.is_empty():
		_line(left, T["no_deeds"], UI.DIM)
	for d in deeds.slice(0, 4 if _small() else 6):
		var amount := int(d.get("amount", 0))
		_line(left, String(d.get("text", "")) + (("   " + Renown.TEXT["earned"] % amount) if amount > 0 else ""), UI.TEXT if amount > 0 else UI.GOLD)
	# The climbers you've met in the towers (rivals.gd), the most recent first.
	_section(left, Rivals.TEXT["board"])
	var met: Array = Rivals.met_list(prof)
	if met.is_empty():
		_line(left, Rivals.TEXT["board_none"], UI.DIM)
	for rec in met.slice(0, 6 if _small() else 8):
		_tile(left, "rival:" + String(rec.get("id", "")), String(rec.get("name", "")), Rivals.marks_text(rec), "arena", Rivals.color_of(rec))


func _line(parent: Node, text: String, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = minf(220.0, _avail() - 40.0)
	l.add_theme_font_size_override("font_size", 14 if _small() else 15)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


# --- the card ----------------------------------------------------------------------------

func _card() -> void:
	if card == null or not is_instance_valid(card):
		return
	for c in card.get_children():
		card.remove_child(c)
		c.queue_free()
	var key := String(picks.get(stop, ""))
	var kind := key.get_slice(":", 0)
	var id := key.get_slice(":", 1)
	match kind:
		"lesson":
			_lesson_card(id)
		"drill":
			_drill_card(id)
		"bracket":
			_bracket_card(id)
		"title":
			_title_card(id)
		"contract":
			_contract_card(id)
		"rank":
			_rank_card(int(id))
		"rival":
			_rival_card(id)
		"advanced":
			_advanced_card(id)
		"first":
			_first_card()
		"grace":
			_grace_card()
		"manager":
			_manager_card()
	if _small():
		# A short screen: the card's button (and why it's off) right under its
		# name, where it shows without scrolling.
		var at := 0
		for c in card.get_children():
			at += 1
			if c is HBoxContainer and c.get_child_count() > 0 and c.get_child(0) is StationView.StopIcon:
				break
		for c in card.get_children():
			if c.has_meta("station_do"):
				var i := c.get_index()
				card.move_child(c, at)
				var nxt: Node = card.get_child(i + 1) if i + 1 < card.get_child_count() else null
				if nxt is Label and nxt.get_theme_color("font_color") == UI.BAD:
					card.move_child(nxt, at + 1)
				break


func _head(title: String, icon: String, col: Color, eyebrow := "") -> void:
	if eyebrow != "":
		_section(card, eyebrow)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	card.add_child(row)
	var ic = StationView.StopIcon.new()
	ic.id = icon
	ic.tint = col
	ic.custom_minimum_size = Vector2(34, 34) if _small() else Vector2(40, 40)
	row.add_child(ic)
	var l := Label.new()
	l.text = title
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	UI.style_label(l, "display", 22 if _small() else 25, col.lightened(0.15))
	row.add_child(l)
	if not lines.is_empty() and lines_for == String(picks.get(stop, "")):
		for ln in lines:
			_text(String(ln), UI.GOLD)


func _text(text: String, col: Color, size := 0) -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = minf(220.0, _avail() - 40.0)
	l.add_theme_font_size_override("font_size", size if size > 0 else (14 if _small() else 15))
	l.add_theme_color_override("font_color", col)
	card.add_child(l)
	return l


func _button(text: String, action: Callable, meta: String) -> Button:
	var b: Button = m._button(text, action, card)
	b.custom_minimum_size.y = 40
	b.set_meta("station_do", meta)
	UI.keep_text(b)  # (its words whole: smaller, then wrapped, never cut)
	m.train_page._brass(b, true)
	return b


func _price(kind: String, amount: int, ok: bool, label := "") -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	card.add_child(row)
	if label != "":
		var l := Label.new()
		l.text = label
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", UI.DIM)
		row.add_child(l)
	var tag = TrainPage.PriceTag.new()
	tag.kind = kind
	tag.amount = amount
	tag.ok = ok
	tag.custom_minimum_size = Vector2(minf(150.0, _avail() - 90.0), 22)
	if kind == "any":
		tag.text_override = "%d of any kind" % amount
	row.add_child(tag)


## A fee's price line (or "No fee"), and the worn title's cut.
func _fee(type: String, id: String, base: int, cut: float) -> void:
	var prof = _prof()
	var f := Stations.fee(prof, type, id)
	if f > 0:
		_price("any", f, int(prof.crystals_held()) >= f, T["fee"])
	else:
		_text(T["free"], UI.DIM)
	if base > 0 and cut > 0.0:
		_text(T["fee_cut"] % int(round(minf(cut, 1.0) * 100.0)), UI.GOOD)


func _lesson_card(id: String) -> void:
	var prof = _prof()
	var d: Dictionary = Stations.LESSONS.get(id, {})
	if d.is_empty():
		return
	var st := Stations.lesson_state(prof, id)
	_head(String(d["name"]), "lesson", Color(0.62, 0.78, 1.0) if st == 0 else UI.GILT, TT["basic"])
	_text(Stations.lesson_goal(id), UI.TEXT)
	var mode := "touch" if m.main.touch_active else ("pad" if m.main.pad_active else "keys")
	_text(Entity.fill_keys(String(d.get("say", "")), mode, m.main.pad_ps), Color(0.78, 0.82, 1.0))
	_text(T["lesson_done"] if st == 1 else (T["lesson_skipped"] if st == 2 else T["lesson_todo"]), UI.GILT if st == 1 else UI.DIM)
	_button(T["lesson_again"] if st == 1 else T["lesson_begin"], _begin.bind("lesson", id), "begin")
	if st == 0 and Training.can_skip(prof):
		_button(T["lesson_skip"], _skip.bind(id), "skip")
	elif st == 0:
		_text(TT["no_skip"], UI.DIM, 13)  # (basic training is required for the Noble's Grace)
	if not _small():
		_text(T["lessons_note"] % Stations.LESSON_REWARD, UI.FAINT, 13)


## Advanced or mark training: its goal, the Entity's word, its tier and
## partner, the fee in its essence, Begin.
func _advanced_card(id: String) -> void:
	var prof = _prof()
	var d := Training.lesson(id)
	if d.is_empty():
		return
	var mark := Training.is_mark(id)
	_head(String(d["name"]), "lesson" if not mark else "gym", Color(0.86, 0.7, 1.0) if mark else Color(0.62, 0.9, 0.8), TT["mark_training"] if mark else TT["advanced"])
	_text(Training.lesson_goal(id), UI.TEXT)
	var mode := "touch" if m.main.touch_active else ("pad" if m.main.pad_active else "keys")
	_text(Entity.fill_keys(String(d.get("say", "")), mode, m.main.pad_ps), Color(0.78, 0.82, 1.0))
	var tier := int(d.get("tier", 0))
	_text(String(Training.TIERS[tier]["name"]) + "  ·  " + (TT["tier_open"] % String(Training.TIERS[tier]["name"]) if Training.tier_open(prof, tier) else Training.locked_text(tier)), UI.GILT if Training.tier_open(prof, tier) else UI.DIM)
	if d.has("partner"):
		_text(TT["partner"] % String(TT["partners"].get(String(d["partner"]), d["partner"])), UI.DIM)
	var f := Training.fee(prof, id)
	var k := Training.fee_kind(prof, id)
	_price(k, f, prof.crystal_total(k) >= float(f), T["fee"])
	_text(TT["adv_done"] if Training.done(prof, id) else TT["adv_todo"], UI.GILT if Training.done(prof, id) else UI.DIM)
	_text(TT["adv_pays"] % int(Training.TIERS[tier].get("renown", 0)), UI.GOOD)
	var why := Training.why_not(prof, id)
	var b := _button(T["lesson_again"] if Training.done(prof, id) else T["lesson_begin"], _begin.bind("advanced", id), "advanced")
	b.disabled = why != ""
	if why != "":
		_text(why, UI.BAD)


## The first tournament: its rounds, its rewards row by row, the Grace.
func _first_card() -> void:
	var prof = _prof()
	_head(String(TT["first"]), "arena", UI.GILT_HI, Stations.stop_name("arena"))
	_text(TT["first_sub"], UI.TEXT)
	_section(card, TT["first_rounds"])
	var rounds := Training.first_rounds(station)
	for i in rounds.size():
		_text(Training.round_text(i, rounds[i]), UI.TEXT)
	_section(card, TT["first_rewards"])
	_text(TT["first_reward_0"], UI.GILT_HI)
	for row in Training.REWARDS:
		var when: String = TT["flawless"] if bool(row.get("flawless", false)) else TT["won_n"] % int(row.get("won", 0))
		_text(TT["reward_row"] % [when, String(TT["give"].get(String(row["give"]), row["give"]))], UI.GOOD)
	_text(T["free"], UI.DIM)
	var why := Stations.why_not(prof, "first", "first", station)
	var b := _button(TT["first_enter"], _begin.bind("first", "first"), "first")
	b.disabled = why != ""
	if why != "":
		_text(why, UI.BAD)


## The Noble's Grace: what it is, whether you have it, and the steps to it.
func _grace_card() -> void:
	var prof = _prof()
	var have := Training.has_grace(prof)
	_head(String(TT["grace"]), "title", UI.GILT if have else UI.GILT_HI, Noble.name_of(station))
	_text(TT["grace_what"], UI.TEXT)
	_text(TT["grace_have"] if have else TT["grace_not"], UI.GOOD if have else UI.BAD)
	if not have:
		_text(TT["grace_how"], UI.DIM)
		var left := Training.basic_left(prof)
		var n := Stations.LESSON_ORDER.size()
		_text("%s  ·  %s" % [TT["grace_step_lessons"] % [n - left, n], N["done"] if left == 0 else N["not_done"]], UI.GOOD if left == 0 else UI.DIM)
		_text("%s  ·  %s" % [TT["grace_step_first"], N["not_done"]], UI.DIM)


## The Tournament Manager: where they are, where they go next, and what
## this location's arena is like (its hazards, creatures and prize).
func _manager_card() -> void:
	var prof = _prof()
	var here := Tournaments.at(prof, station)
	var loc := Tournaments.location(station)
	_head(String(TM["manager"]), "arena", UI.GILT if here else UI.FAINT, String(Tournaments.MANAGER["name"]).capitalize())
	if here:
		_text(TM["here_line"] % Tournaments.station_name(station), UI.GOOD)
	else:
		_text(TM["away"] % Tournaments.station_name(Tournaments.here(prof)), UI.BAD)
	_text(TM["next_line"] % Tournaments.station_name(Tournaments.next(prof)), UI.DIM)
	_section(card, TM["location"])
	_text(String(loc.get("line", "")), UI.TEXT)
	var hz := String(load("res://scripts/traps.gd").KINDS.get(String(loc.get("hazard", "")), {}).get("name", ""))
	if hz != "":
		_text(TM["hazard"] % hz, UI.DIM)
	_text(TM["creatures"] % ", ".join((loc.get("creatures", []) as Array).map(func(k): return String(k).capitalize())), UI.DIM)
	_text(TM["minor"] % String(load("res://scripts/items.gd").ITEMS.get(String(Tournaments.MINOR.get("item", "")), {}).get("name", "")), UI.GOOD)
	var pc := Tournaments.prize_piece(station)
	if not pc.is_empty():
		if Tournaments.prize_won(prof, station):
			_text(TM["prize_have"] % load("res://scripts/gear.gd").display(pc), UI.GILT)
		else:
			_text(TM["prize"] % [String(Stations.BRACKETS[clampi(Tournaments.ADVANCED_FROM - 1, 0, Stations.BRACKETS.size() - 1)]["name"]), load("res://scripts/gear.gd").display(pc)], UI.GILT_HI)


func _drill_card(id: String) -> void:
	var prof = _prof()
	var d: Dictionary = Stations.DRILLS.get(id, {})
	if d.is_empty():
		return
	var r := Renown.state(prof)
	var medal := int(r["drills"].get(id, 0))
	_head(String(d["name"]), "gym", UI.GILT, T["drills"])
	_text(Stations.drill_goal(id), UI.TEXT)
	if bool(d.get("extra", false)):
		_text(T["extra_open"] if Stations.drill_unlocked(prof, id) else T["extra"], UI.GILT_HI)
	_section(card, T["medals"])
	var marks: Array = d["medals"]
	var lower: bool = d.get("lower", false)
	for i in marks.size():
		var need := Stations.score_text(id, float(marks[i]))
		_text(T["medal_needs"] % [Stations.medal_name(i + 1), ("%s or less" if lower else "%s or more") % need], Stations.medal_color(i + 1) if medal >= i + 1 else Color(Stations.medal_color(i + 1), 0.6))
	_text(T["best"] % (Stations.score_text(id, float(r["best"][id])) + "  ·  " + Stations.medal_name(medal)) if r["best"].has(id) else T["never"], UI.DIM)
	var rn: Array = d.get("renown", [])
	var still: Array = []
	for i in range(medal, mini(3, rn.size())):
		still.append("%s %s" % [Stations.medal_name(i + 1), Renown.TEXT["earned"] % int(rn[i])])
	if not still.is_empty():
		_text(T["drill_rewards"] + ": " + ",  ".join(still), UI.GOOD)
	_fee("drill", id, int(d.get("fee", 0)), Titles.num(prof, "gym", "fee_cut"))
	var why := Stations.why_not(prof, "drill", id)
	var b := _button(T["begin"], _begin.bind("drill", id), "begin")
	b.disabled = why != ""
	if why != "":
		_text(why, UI.BAD)


func _bracket_card(id: String) -> void:
	var prof = _prof()
	var b := Stations.bracket(id)
	if b.is_empty():
		return
	var tw: Dictionary = Towers.TOWERS.get(String(b.get("tower", "")), {})
	_head(String(b["name"]), "arena", Color(tw.get("torch", UI.GILT)).lerp(UI.GILT, 0.5), Stations.stop_name("arena"))
	if Stations.bracket_early(prof, id):
		_text(T["early"], UI.GOOD)
	_section(card, T["rounds"])
	var rounds: Array = Stations.event("tourney", id, station).get("rounds", [])  # (this location's: its creatures first)
	for i in rounds.size():
		_text(T["round"] % [i + 1, Tournaments.round_text(rounds[i])], UI.TEXT)
	_fee("tourney", id, int(b.get("fee", 0)), Titles.num(prof, "tourney", "fee_cut"))
	var pz := Stations.prize(prof, id, station)
	var pays: Array = [Renown.TEXT["earned"] % int(pz["renown"]), T["crystals"] % [int(pz["crystals"]), Essence.display(String(pz["kind"]))]]
	if String(pz["relic"]) == "yes":
		pays.append(T["relic"])
	elif String(pz["relic"]) == "maybe":
		pays.append(T["relic_maybe"])
	_text((T["rewards"] if pz["first"] else T["rewards_repeat"]) + ": " + ",  ".join(pays), UI.GOOD)
	var num := Stations.bracket_number(id)
	for tid in Renown.TITLE_ORDER:
		var t: Dictionary = Renown.TITLES[tid]
		if String(t.get("rule", "")) == "tier" and int(t.get("n", 0)) == num and not Renown.has_title(prof, tid):
			_text(T["title_for"] % Renown.title_name(tid), UI.GILT_HI)
	var more := Titles.num(prof, "tourney", "prize")
	if more > 0.0:
		_text(T["prize_more"] % int(round(more * 100.0)), UI.GOOD)
	_text(T["rounds_pay"] % int(b.get("round_renown", 0)), UI.DIM)
	if Stations.best_rounds(prof, id) > 0:
		_text(T["best_rounds"] % [Stations.best_rounds(prof, id), rounds.size()], UI.DIM)
	_text(TM["minor"] % String(load("res://scripts/items.gd").ITEMS.get(String(Tournaments.MINOR.get("item", "")), {}).get("name", "")), UI.GOOD)
	var lp := Tournaments.prize_piece(station)
	if Stations.bracket_number(id) >= Tournaments.ADVANCED_FROM and not lp.is_empty() and not Tournaments.prize_won(prof, station):
		_text(TM["prize"] % [String(Stations.BRACKETS[clampi(Tournaments.ADVANCED_FROM - 1, 0, Stations.BRACKETS.size() - 1)]["name"]), load("res://scripts/gear.gd").display(lp)], UI.GILT_HI)
	var why := Stations.why_not(prof, "tourney", id, station)
	var btn := _button(T["enter"], _begin.bind("tourney", id), "begin")
	btn.disabled = why != ""
	if why != "":
		_text(why, UI.BAD)
	if not _small():
		_text(T["fee_note"], UI.FAINT, 13)


func _title_card(id: String) -> void:
	var prof = _prof()
	var t: Dictionary = Renown.TITLES.get(id, {})
	if t.is_empty():
		return
	var have := Renown.has_title(prof, id)
	var ready := Renown.grantable(prof, id)
	_head(Renown.title_name(id), "title", UI.GILT if have or ready else UI.FAINT, N["titles"])
	# What it needs: its rank and its deed, each done or not.
	_section(card, N["requires"])
	var need := int(t.get("rank", 0))
	var rank_ok := Renown.rank(prof) >= need
	_text("%s  ·  %s" % [N["req_rank"] % Renown.rank_name(need), N["done"] if rank_ok or have else N["not_done"]], UI.GOOD if rank_ok or have else UI.DIM)
	if String(t.get("rule", "")) != "none":
		var deed_ok: bool = have or Renown.deed_done(prof, t)
		_text("%s  ·  %s" % [N["req_deed"] % String(t.get("deed", "")), N["done"] if deed_ok else N["not_done"]], UI.GOOD if deed_ok else UI.DIM)
	# What it gives: its social benefits.
	_section(card, Titles.TEXT["benefits"])
	var gives := Titles.lines(id)
	if gives.is_empty():
		_text(Titles.TEXT["none"], UI.DIM)
	for ln in gives:
		_text(String(ln), UI.TEXT)
	var worn := Renown.worn_title(prof)
	_text(N["worn_now"] % worn if worn != "" else N["unworn_now"], UI.DIM)
	if ready:
		_button(N["grant"] % Renown.title_name(id), _grant.bind(id), "grant")
	elif have:
		if Renown.worn_id(prof) == id:
			_button(N["unwear"], _wear.bind(""), "wear")
		else:
			_button(N["wear"], _wear.bind(id), "wear")
	if not _small():
		_text(Titles.TEXT["worn_only"] + " " + N["title_shows"], UI.FAINT, 13)


func _contract_card(id: String) -> void:
	var prof = _prof()
	var o := Contracts.find(prof, id)
	if o.is_empty():
		return
	var held := Contracts.is_held(prof, id)
	_head(Contracts.name_of(o), "contract", Contracts.KINDS_COLOR, N["held"] if held else N["on_offer"])
	_text(Contracts.goal_of(o), UI.TEXT)
	if held:
		_text(N["progress"] % Contracts.progress_of(o), UI.GILT)
	_text(Contracts.reward_text(o), UI.GOOD)
	if held:
		_button(N["drop"], _drop.bind(id), "drop")
	else:
		var full := Contracts.active(prof).size() >= Contracts.most(prof)
		var b := _button(N["take"], _take.bind(id), "take")
		b.disabled = full
		if full:
			_text(Contracts.TEXT["full"] % Contracts.most(prof), UI.BAD)
	if not _small():
		_text(N["contracts_note"] % Contracts.most(prof), UI.FAINT, 13)


func _rank_card(i: int) -> void:
	var prof = _prof()
	if i < 0 or i >= Renown.RANKS.size():
		return
	var rk := Renown.rank(prof)
	_head(Renown.rank_name(i), "board", UI.GILT if i <= rk else UI.FAINT, T["ranks"])
	_text(Renown.TEXT["points"] % Renown.needed(i), UI.DIM)
	if i <= rk:
		_text(T["rank_reached"], UI.GOOD)
	elif i == rk + 1:
		_text(Renown.next_text(prof), UI.GILT_HI)
	_section(card, T["next_opens"] % Renown.rank_name(i))
	for ln in Renown.opens(i):
		_text(String(ln).left(1).to_upper() + String(ln).substr(1), UI.TEXT)


## A climber you've met: their marks, one to a line in its colour, and your
## history with them.
func _rival_card(id: String) -> void:
	var rec: Dictionary = Rivals.state(_prof()).get(id, {})
	if rec.is_empty():
		return
	_head(String(rec.get("name", "")), "arena", Rivals.color_of(rec), Rivals.TEXT["board"])
	for b in rec.get("bonds", []):
		var one := {"bonds": [b]}
		_text(Rivals.marks_text(one), Rivals.bond_color(String(b[0])).lerp(UI.TEXT, 0.25))
	_text(Rivals.history_text(rec), UI.TEXT)
	var tw: Dictionary = Towers.TOWERS.get(String(rec.get("tower", "")), {})
	if not tw.is_empty():
		_text(Rivals.TEXT["last"] % [String(tw.get("name", "")), int(rec.get("floor", 1))], UI.DIM)
	if bool(rec.get("owed", false)):
		_text(Rivals.TEXT["owed"], UI.GOOD)
	elif int(rec.get("robbed", 0)) > 0:
		_text(Rivals.TEXT["grudge"], UI.BAD)


# --- actions -----------------------------------------------------------------------------

func _again(key: String, words: Array, sound: String, focus := "") -> void:
	lines = words
	lines_for = key
	picks[stop] = key
	if focus != "":
		m._want_focus = {"meta": "station_do", "value": focus}
	if m.main != null:
		m.main.sfx(sound, 1.0, -4.0, 0.0)
	m.open("station")


func _begin(type: String, id: String) -> void:
	var ev := Stations.event(type, id, station)
	var why: String = m.main.arena.start(ev) if m.main != null and m.main.arena != null else "?"
	if why != "":
		_again("%s:%s" % ["bracket" if type == "tourney" else type, id], [T["cant"] % why], "ui_back", type if type in ["advanced", "first"] else "begin")


func _skip(id: String) -> void:
	var words: Array = [T["lesson_skipped"] + ": " + String(Stations.LESSONS.get(id, {}).get("name", id))]
	words.append_array(Stations.skip_lesson(_prof(), id))
	var left := Stations.lessons_left(_prof())
	_again("lesson:" + (String(left[0]) if not left.is_empty() else id), words, "ui_confirm", "begin")


func _redraw_rail() -> void:
	if m.rail != null:
		m.rail.queue_redraw()
		if m.rail.ident != null:
			m.rail.ident.queue_redraw()


func _grant(id: String) -> void:
	if not Renown.grant(_prof(), id):
		return
	_redraw_rail()
	if m.main != null:
		m.main.tip("titles_social")
	_again("title:" + id, [N["granted_now"] % Renown.title_name(id), Noble.line("granted")], "clear", "wear")


func _wear(id: String) -> void:
	Renown.wear(_prof(), id)
	_redraw_rail()
	_again("title:" + (id if id != "" else String(picks.get(stop, "")).get_slice(":", 1)), [N["worn_now"] % Renown.title_name(id) if id != "" else N["unworn_now"]], "ui_confirm", "wear")


func _take(id: String) -> void:
	var o := Contracts.find(_prof(), id)
	var why := Contracts.take(_prof(), id)
	if why == "":
		_again("contract:" + id, [N["taken_now"] % Contracts.name_of(o), Noble.line("taken")], "ui_confirm", "drop")
	else:
		_again("contract:" + id, [T["cant"] % why], "ui_back", "take")


func _drop(id: String) -> void:
	var o := Contracts.find(_prof(), id)
	Contracts.drop(_prof(), id)
	var offers: Array = Contracts.offers(_prof())
	_again("contract:" + (String(offers[0]["id"]) if not offers.is_empty() else ""), [N["dropped_now"] % Contracts.name_of(o), Noble.line("dropped")], "ui_back", "take")
