extends RefCounted
## A station's page (menu.gd's "station" page): the menu's rail down the
## left lists the station's stops (rail.gd, in station mode) and "Back to
## the train"; the stop you're at fills the rest, over the station drawn
## behind it (station_view.gd). Each stop is a list on the left and a card
## on the right (the card goes under the list on a narrow screen):
##   gym         the drills: each one's goal, medals, your best, Begin
##   arena       the tournament's tiers and their bouts: foes, rules, fee,
##               what a win pays, Enter
##   challenges  the challenges: the twist, foes, what the first win pays
##   board       your renown and rank, recent deeds, the ranks, and the
##               titles (choose one to wear)
##   shrine      the boons: what each does, its level and price, Buy
## Focusing a tile (the keys, the mouse) shows its card; pressing it (or a
## tap) does too, and with the keys puts the focus on the card's button.
## Q / E (LB / RB) move between stops. The words are in stations.gd,
## renown.gd and boons.gd.

const Stations := preload("res://scripts/stations.gd")
const Renown := preload("res://scripts/renown.gd")
const Boons := preload("res://scripts/boons.gd")
const StationView := preload("res://scripts/station_view.gd")
const UI := preload("res://scripts/ui.gd")
const Essence := preload("res://scripts/essence.gd")
const Towers := preload("res://scripts/towers.gd")
const TrainPage := preload("res://scripts/train_page.gd")

static var T := Stations.TEXT

var m  # the menu
var station := ""  # the station you're at ("" when not at one)
var stop := "gym"
var picks := {}  # stop -> the key whose card shows ("drill:parry", "bout:copper_1", "title:x"...)
var lines: Array = []  # the last result or answer, shown on its card
var lines_for := ""  # ...the key it belongs to
var card: VBoxContainer
var tiles: Array = []


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
func arrive(id: String, at := "", pick := "", said: Array = []) -> void:
	if station == "" and said.is_empty() and m.main != null and m.main.profile != null:
		Renown.on_visit(m.main.profile)  # (a stop counted: the Newcomer's title)
	station = id if Stations.station_ids().has(id) else String(Stations.STATIONS[0]["id"])
	var ids := stop_ids()
	stop = at if ids.has(at) else (ids[0] if not ids.is_empty() else "gym")
	if pick != "":
		picks[stop] = pick
	lines = said
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
	m._header(Stations.stop_name(stop), String(info.get("sub", "")), String(st.get("name", "")))
	var bar := StationView.RenownBar.new()
	bar.profile = prof
	bar.custom_minimum_size = Vector2(minf(280.0, _avail()), 34 if small else 40)
	bar.set_meta("renown_bar", true)
	m.box.add_child(bar)
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
		"challenges":
			_challenges(left)
		"board":
			_board(left)
		"shrine":
			_shrine(left)
	var keys: Array = tiles.map(func(tl): return String(tl.get_meta("pick")))
	var pk := String(picks.get(stop, ""))
	if not keys.has(pk):
		pk = keys[0] if not keys.is_empty() else ""
		if stop == "board":
			var worn := String(Renown.state(prof)["worn"])
			if worn != "" and keys.has("title:" + worn):
				pk = "title:" + worn
	picks[stop] = pk
	_mark_chosen()
	_card()


## Where the keys start: the chosen tile.
func first_focus(list: Array) -> int:
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


## The card's first button (Begin, Buy, Wear...), or null.
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

func _gym(left: Node) -> void:
	var prof = _prof()
	var r := Renown.state(prof)
	for id in Stations.DRILL_ORDER:
		if not Stations.DRILLS.has(id):
			continue
		var d: Dictionary = Stations.DRILLS[id]
		var open := Stations.drill_unlocked(prof, id)
		var line := ""
		if not open:
			line = T["locked_short"] % Renown.rank_name(int(d.get("rank", 0)))
		elif r["best"].has(id):
			line = T["best"] % Stations.score_text(id, float(r["best"][id]))
		else:
			line = T["never"]
		var tl = _tile(left, "drill:" + id, String(d["name"]), line, "gym")
		tl.locked = not open
		tl.medal = -1 if not open else int(r["drills"].get(id, 0))


func _arena(left: Node) -> void:
	var prof = _prof()
	for t in Stations.TIERS.size():
		var tier: Dictionary = Stations.TIERS[t]
		var open := Stations.tier_unlocked(prof, t)
		var head: String = tier["name"]
		if not open:
			head += "  ·  " + T["locked_short"] % Renown.rank_name(int(tier.get("rank", 0)))
		elif bool(Renown.state(prof)["tiers"].get(str(t + 1), false)):
			head += "  ·  " + T["won"]
		_section(left, head)
		var tw: Dictionary = Towers.TOWERS.get(String(tier.get("tower", "")), {})
		var tint: Color = Color(tw.get("torch", UI.TRAIN_BRASS))
		for bt in tier["bouts"]:
			var id := String(bt["id"])
			var wins := Stations.bout_wins(prof, id)
			var bo := Stations.bout_open(prof, id)
			var line := ""
			if not open:
				line = T["locked_short"] % Renown.rank_name(int(tier.get("rank", 0)))
			elif not bo:
				line = T["ladder_next"]
			elif wins > 0:
				line = Stations.wins_text(wins)
			else:
				var rl := Stations.rule_lines(Stations.event("bout", id))
				line = rl[0] if not rl.is_empty() else T["no_rules"]
			var tl = _tile(left, "bout:" + id, String(bt["name"]), line, "arena", tint)
			tl.locked = not bo
			tl.lit = wins > 0


func _challenges(left: Node) -> void:
	var prof = _prof()
	for id in Stations.CHALLENGE_ORDER:
		if not Stations.CHALLENGES.has(id):
			continue
		var c: Dictionary = Stations.CHALLENGES[id]
		var open := Stations.challenge_unlocked(prof, id)
		var won := Stations.challenge_won(prof, id)
		var line: String = T["won"] if won else (String(c.get("twist", "")) if open else T["locked_short"] % Renown.rank_name(int(c.get("rank", 0))))
		var tl = _tile(left, "challenge:" + id, String(c["name"]), line, "challenges", Color(0.9, 0.42, 0.34))
		tl.locked = not open
		tl.lit = won
		tl.medal = 3 if won else -1


func _board(left: Node) -> void:
	var prof = _prof()
	var r := Renown.state(prof)
	_section(left, T["deeds"])
	var deeds: Array = (r["deeds"] as Array).duplicate()
	deeds.reverse()
	if deeds.is_empty():
		_line(left, T["no_deeds"], UI.DIM)
	for d in deeds.slice(0, 4 if _small() else 6):
		var amount := int(d.get("amount", 0))
		_line(left, String(d.get("text", "")) + (("   " + Renown.TEXT["earned"] % amount) if amount > 0 else ""), UI.TEXT if amount > 0 else UI.GOLD)
	_section(left, T["titles"])
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	left.add_child(grid)
	var have: Array = r["titles"]
	for id in Renown.TITLE_ORDER:
		if not Renown.TITLES.has(id):
			continue
		var earned: bool = have.has(id)
		var tl = _tile(grid, "title:" + id, Renown.title_name(id), T["title_worn"] if String(r["worn"]) == id else (T["earned"] if earned else String(Renown.TITLES[id].get("deed", ""))), "title", UI.GILT if earned else UI.FAINT)
		tl.locked = not earned
		tl.lit = String(r["worn"]) == id
		tl.custom_minimum_size.x = minf(150.0 if _small() else 180.0, _avail() * 0.5 - 4.0)
	_section(left, T["ranks"])
	var rk := Renown.rank(prof)
	var rg := GridContainer.new()
	rg.columns = 2
	rg.add_theme_constant_override("h_separation", 18)
	left.add_child(rg)
	for i in Renown.RANKS.size():
		var col: Color = UI.GILT_HI if i == rk else (UI.TEXT if i < rk else UI.FAINT)
		var l := _line(rg, "%s  ·  %d" % [Renown.rank_name(i), Renown.needed(i)], col)
		l.autowrap_mode = TextServer.AUTOWRAP_OFF  # (a short line, as wide as its words: two to a row, or one where the screen is narrow: reflow.gd)
		l.custom_minimum_size.x = 0.0


func _shrine(left: Node) -> void:
	var prof = _prof()
	for id in Boons.ORDER:
		if not Boons.BOONS.has(id):
			continue
		var b: Dictionary = Boons.BOONS[id]
		var open := Boons.unlocked(prof, id)
		var line: String = String(b.get("desc", "")) if open else Boons.TEXT["locked"] % Renown.rank_name(int(b.get("rank", 0)))
		var tl = _tile(left, "boon:" + id, String(b["name"]), line, "boon", Essence.color(String(b.get("kind", "stone"))))
		tl.locked = not open
		tl.pips = Boons.level(prof, id)
		tl.pips_of = int(b.get("levels", 1))


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
		"drill":
			_drill_card(id)
		"bout":
			_bout_card(id)
		"challenge":
			_challenge_card(id)
		"title":
			_title_card(id)
		"boon":
			_boon_card(id)
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


func _drill_card(id: String) -> void:
	var prof = _prof()
	var d: Dictionary = Stations.DRILLS.get(id, {})
	if d.is_empty():
		return
	var r := Renown.state(prof)
	var medal := int(r["drills"].get(id, 0))
	_head(String(d["name"]), "gym", UI.GILT, Stations.stop_name("gym"))
	_text(Stations.drill_goal(id), UI.TEXT)
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
	var why := Stations.why_not(prof, "drill", id)
	var b := _button(T["begin"], _begin.bind("drill", id), "begin")
	b.disabled = why != ""
	if why != "":
		_text(why, UI.BAD)


func _bout_card(id: String) -> void:
	var prof = _prof()
	var at := Stations.find_bout(id)
	if at[0] < 0:
		return
	var tier: Dictionary = Stations.TIERS[at[0]]
	var ev := Stations.event("bout", id)
	var tw: Dictionary = Towers.TOWERS.get(String(tier.get("tower", "")), {})
	_head(String(ev.get("name", "")), "arena", Color(tw.get("torch", UI.GILT)).lerp(UI.GILT, 0.5), String(tier["name"]))
	_section(card, T["foes"])
	for ln in Stations.wave_lines(ev):
		_text(ln, UI.TEXT)
	_section(card, T["rules"])
	var rl := Stations.rule_lines(ev)
	_text(",  ".join(rl) if not rl.is_empty() else T["no_rules"], UI.TEXT if not rl.is_empty() else UI.DIM)
	var fee := Stations.fee("bout", id)
	_price("any", fee, int(prof.crystals_held()) >= fee, T["fee"])
	if not _small():
		_text(T["fee_note"], UI.FAINT, 13)
	var wins := Stations.bout_wins(prof, id)
	var first := wins == 0
	var kind := String(tw.get("essence", "stone"))
	var renown := maxi(1, int(round(float(ev.get("renown", 0)) * (1.0 if first else float(Stations.REPEAT["renown"])))))
	var cr := maxi(1, int(round(float(tier.get("crystals", 0)) * (1.0 if first else float(Stations.REPEAT["crystals"])))))
	var pays: Array = [Renown.TEXT["earned"] % renown, T["crystals"] % [cr, Essence.display(kind)]]
	if ev.get("last", false):
		pays.append(T["relic"] if not bool(Renown.state(prof)["tiers"].get(str(at[0] + 1), false)) else T["relic_maybe"])
	_text((T["rewards"] if first else T["rewards_repeat"]) + ": " + ",  ".join(pays), UI.GOOD)
	if wins > 0:
		_text(Stations.wins_text(wins), UI.DIM)
	var why := Stations.why_not(prof, "bout", id)
	var b := _button(T["enter"], _begin.bind("bout", id), "begin")
	b.disabled = why != ""
	if why != "":
		_text(why, UI.BAD)


func _challenge_card(id: String) -> void:
	var prof = _prof()
	var c: Dictionary = Stations.CHALLENGES.get(id, {})
	if c.is_empty():
		return
	var ev := Stations.event("challenge", id)
	_head(String(c["name"]), "challenges", Color(0.95, 0.55, 0.45), Stations.stop_name("challenges"))
	_text(String(c.get("twist", "")), UI.TEXT)
	_section(card, T["foes"])
	for ln in Stations.wave_lines(ev):
		_text(ln, UI.TEXT)
	var rl := Stations.rule_lines(ev)
	if not rl.is_empty():
		_section(card, T["rules"])
		_text(",  ".join(rl), UI.TEXT)
	if Stations.challenge_won(prof, id):
		_text(T["won_once"], UI.GILT)
	else:
		var kind := String(Towers.TOWERS.get(String(c.get("tower", "")), {}).get("essence", "stone"))
		var pays: Array = [Renown.TEXT["earned"] % int(c.get("renown", 0)), T["crystals"] % [int(c.get("crystals", 0)), Essence.display(kind)]]
		if c.get("relic", false):
			pays.append(T["relic"])
		_text(T["rewards"] + ": " + ",  ".join(pays), UI.GOOD)
	_text(T["free"], UI.DIM)
	var why := Stations.why_not(prof, "challenge", id)
	var b := _button(T["take"], _begin.bind("challenge", id), "begin")
	b.disabled = why != ""
	if why != "":
		_text(why, UI.BAD)


func _title_card(id: String) -> void:
	var prof = _prof()
	var r := Renown.state(prof)
	var t: Dictionary = Renown.TITLES.get(id, {})
	if t.is_empty():
		return
	var earned: bool = r["titles"].has(id)
	_head(Renown.title_name(id) if earned else Renown.title_name(id), "title", UI.GILT if earned else UI.FAINT, T["titles"])
	_text(String(t.get("deed", "")), UI.TEXT)
	var worn := Renown.worn_title(prof)
	_text(T["worn_now"] % worn if worn != "" else T["unworn_now"], UI.DIM)
	if earned:
		if String(r["worn"]) == id:
			_button(T["unwear"], _wear.bind(""), "wear")
		else:
			_button(T["wear"], _wear.bind(id), "wear")
	else:
		_text(T["title_locked"], UI.FAINT)
	if not _small():
		_text(T["title_shows"], UI.FAINT, 13)


func _boon_card(id: String) -> void:
	var prof = _prof()
	var b: Dictionary = Boons.BOONS.get(id, {})
	if b.is_empty():
		return
	var lv := Boons.level(prof, id)
	var most := int(b.get("levels", 1))
	_head(String(b["name"]), "boon", Essence.color(String(b.get("kind", "stone"))).lerp(UI.TEXT, 0.25), Stations.stop_name("shrine"))
	_text(String(b.get("desc", "")), UI.TEXT)
	_text(Boons.TEXT["level"] % [lv, most] if lv > 0 else Boons.TEXT["none"], UI.GILT if lv > 0 else UI.DIM)
	var why := Boons.why_not(prof, id)
	if lv < most:
		var p := Boons.price(prof, id)
		_price(String(p[0]), int(p[1]), int(prof.crystal_total(p[0])) >= int(p[1]))
		var btn := _button(Boons.TEXT["buy"] % (lv + 1), _buy.bind(id), "buy")
		btn.disabled = why != ""
	if why != "" and why != Boons.TEXT["max"]:
		_text(why, UI.BAD)
	elif lv >= most:
		_text(Boons.TEXT["max"], UI.GILT)
	if not _small():
		_text(T["shrine_note"], UI.FAINT, 13)


# --- actions -----------------------------------------------------------------------------

func _again(key: String, said: Array, sound: String) -> void:
	lines = said
	lines_for = key
	picks[stop] = key
	m._want_focus = {"meta": "station_do", "value": "buy" if key.begins_with("boon:") else ("wear" if key.begins_with("title:") else "begin")}
	if m.main != null:
		m.main.sfx(sound, 1.0, -4.0, 0.0)
	m.open("station")


func _begin(type: String, id: String) -> void:
	var ev := Stations.event(type, id, station)
	var why: String = m.main.arena.start(ev) if m.main != null and m.main.arena != null else "?"
	if why != "":
		_again("%s:%s" % [type, id], [T["cant"] % why], "ui_back")


func _wear(id: String) -> void:
	Renown.wear(_prof(), id)
	if m.rail != null:
		m.rail.queue_redraw()
		if m.rail.ident != null:
			m.rail.ident.queue_redraw()
	_again("title:" + (id if id != "" else String(picks.get(stop, "")).get_slice(":", 1)), [T["worn_now"] % Renown.title_name(id) if id != "" else T["unworn_now"]], "ui_confirm")


func _buy(id: String) -> void:
	var why := Boons.buy(_prof(), id)
	if why == "":
		Boons.apply(_prof(), m.main.player)
		_again("boon:" + id, [Boons.TEXT["bought"] % [Boons.BOONS[id]["name"], Boons.level(_prof(), id)]], "buy")
	else:
		_again("boon:" + id, [T["cant"] % why], "ui_back")
