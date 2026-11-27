extends RefCounted
## The Dining car's things (train_page.gd builds every car; this one's are
## here): the tables, where tonight's climbers sit (dining.gd seats them),
## each a button drawn as the climber behind a laid table (Diner); and a
## placard where you talk with the one you chose, picking a line as with
## the Entity: a rumor, a wager, a trade, a duel, goodbye. With no one
## chosen the placard shows your open wagers and what the last climb paid.
## The rules and words are dining.gd's.

const Dining := preload("res://scripts/dining.gd")
const Rivals := preload("res://scripts/rivals.gd")
const TrainView := preload("res://scripts/train_view.gd")
const UI := preload("res://scripts/ui.gd")
const Entity := preload("res://scripts/entity.gd")
const Gear := preload("res://scripts/gear.gd")
const Essence := preload("res://scripts/essence.gd")
const Appearance := preload("res://scripts/appearance.gd")
const Art := preload("res://scripts/train_art.gd")
const Bonds := preload("res://scripts/bonds.gd")
const Towers := preload("res://scripts/towers.gd")

## A seated climber's size (a computer, a phone) at its smallest: the
## tables draw them as big as the car has room for (seats()), up to
## DINER_MAX times this, and shrink them to fit when many sit down.
const DINER := [Vector2(104, 122), Vector2(80, 94)]
const DINER_MAX := 2.3
## A single row (or fewer rows) is kept while it's at least this share of
## the biggest size more rows would allow (three sit side by side, not two over one).
const ROW_KEEP := 0.8
const PLACARD_W := [300.0, 390.0]  # the placard's widest (a phone, a computer)
const SEAT_GAP := [6.0, 10.0]

var tp  # train_page.gd
var m  # menu.gd
var who := ""  # the climber you're talking with ("" for none)
var node := ""  # where the talk is: talk, rumor, bets, trade, duel
var pick := -1  # a wager chosen (bets), a stake chosen (duel)
var said := ""  # what they said last
var got := ""  # a gift or a result, in gold
var tip_line := ""  # the Entity's first-time line, while this part of the talk lasts
var lines: Array = []  # what came back from the Arena car (arena.gd), shown once


func _init(train_page) -> void:
	tp = train_page
	m = train_page.m


func _prof():
	return m.main.profile


func _tower() -> String:
	return String(m.train_tower)


## The car's things: the tables and the placard.
func build(root: Node) -> void:
	var small: bool = tp._small()
	var prof = _prof()
	var people: Array = Dining.seated(prof, _tower())
	if who != "" and not people.any(func(r): return String(r.get("id", "")) == who):
		_reset()
	var row: HBoxContainer = tp._main_row(root)
	var tables: VBoxContainer = tp._furnish(row, "tables")
	tp._tag(tables, Dining.TEXT["tables_short"] if small else Dining.TEXT["tables"])
	var fit := seats(people.size())
	var cols: int = fit["cols"]
	var grid: GridContainer = tp._grid(tables, cols)
	grid.add_theme_constant_override("h_separation", int(SEAT_GAP[0 if small else 1]))
	grid.add_theme_constant_override("v_separation", int(SEAT_GAP[0 if small else 1]))
	var sz: Vector2 = fit["size"]
	for r in people:
		var d := Diner.new()
		d.setup(r, Dining.attitude(prof, r))
		d.on = String(r.get("id", "")) == who
		d.custom_minimum_size = sz
		d.set_meta("diner", String(r.get("id", "")))
		d.set_meta("help", "dine:diner")
		d.tooltip_text = ""
		d.pressed.connect(_talk_to.bind(String(r.get("id", ""))))
		grid.add_child(d)
	if people.is_empty():
		tp._note(tables, Dining.TEXT["nobody"], 3.0 * DINER[1 if small else 0].x)
	# The placard: the talk.
	var plac := TrainView.Furnish.new("placard", small)
	plac.custom_minimum_size.x = _placard_w()
	plac.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(plac)
	var sc: ScrollContainer = tp._card_scroll(plac)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4 if small else 6)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(col)
	# (fitted to what it says by the view's fit frames after each build, not on
	# every change of its size: its wrapped lines would feed back into it)
	var rec: Dictionary = {}
	for r in people:
		if String(r.get("id", "")) == who:
			rec = r
	if rec.is_empty():
		_lobby(col)
	else:
		_talk(col, rec)
	if small:
		for b in col.find_children("*", "BaseButton", true, false):
			b.custom_minimum_size.y = maxf(b.custom_minimum_size.y, 36.0)
	m.details = null


## The car's area for its things (the room inside its margins).
func _area() -> Vector2:
	var r = tp.view.rooms.get("dining") if tp.view != null else null
	return r.area.size if r != null and r.area.size.x > 0.0 else Vector2(1000, 600)


func _placard_w() -> float:
	var small: bool = tp._small()
	return clampf(_area().x * 0.32, 220.0, PLACARD_W[0 if small else 1])


## How the `n` climbers sit: {"cols", "rows", "size"}, as big as the room
## beside the placard allows (the Entity's tip over the car taken off its
## height), at most DINER_MAX times their smallest size and never smaller;
## a single row kept while it's nearly as big (ROW_KEEP). More climbers,
## smaller each, so they never run under the placard or off the car.
func seats(n: int) -> Dictionary:
	var small: bool = tp._small()
	var base: Vector2 = DINER[0]
	var least: Vector2 = DINER[1 if small else 0]
	var area := _area()
	var f := 0.75 if small else 1.0
	var gap: float = SEAT_GAP[0 if small else 1]
	var row_gap := 14.0 if small else 26.0
	var w := area.x - _placard_w() - row_gap - 28.0 * f - 24.0
	var h := area.y - (70.0 if String(tp.tips.get("dining", "")) != "" else 0.0) - 26.0 * f - 24.0 - 16.0
	var best := {"cols": mini(3, maxi(1, n)), "rows": 1, "k": 0.0}
	var options: Array = []
	for cols in range(1, maxi(1, n) + 1):
		var rows := int(ceil(float(maxi(1, n)) / cols))
		var k := minf((w - gap * (cols - 1)) / cols / base.x, (h - gap * (rows - 1)) / rows / base.y)
		options.append({"cols": cols, "rows": rows, "k": minf(k, DINER_MAX)})
	for o in options:
		if o["k"] > best["k"]:
			best = o
	for o in options:
		if o["rows"] < best["rows"] and o["k"] >= best["k"] * ROW_KEEP:
			best = o
	var size: Vector2 = (base * float(best["k"])).floor()
	if size.x < least.x:
		size = least
	return {"cols": best["cols"], "rows": best["rows"], "size": size}


func _reset() -> void:
	who = ""
	node = ""
	pick = -1
	said = ""
	got = ""
	tip_line = ""


# --- the placard -------------------------------------------------------------------------

func _label(parent: Node, text: String, col: Color, size := 15, font := "body") -> Label:
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 160.0
	UI.style_label(l, font, size, col)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l


func _choice(parent: Node, text: String, help: String, action: Callable, on := true) -> Button:
	var b: Button = m._button(text, action, parent)
	b.set_meta("help", help)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.disabled = not on
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UI.keep_text(b)
	return b


func _small_size() -> int:
	return 14 if tp._small() else 15


## No one chosen: who to talk to, your open wagers, what the last climb paid,
## and what came back from the Arena car.
func _lobby(col: VBoxContainer) -> void:
	var prof = _prof()
	var st := Dining.state(prof)
	_label(col, Dining.TEXT["car"], UI.GOLD, 22 if tp._small() else 24, "display")
	for l in lines:
		_label(col, String(l), UI.GOLD, _small_size())
	var touch: bool = m.main.touch_active
	_label(col, Dining.TEXT["pick"] if touch else Dining.TEXT["pick_keys"], UI.DIM, _small_size())
	for l in st["news"]:
		_label(col, String(l), UI.TEXT, _small_size())
	_label(col, Dining.TEXT["bets_open"], UI.GOLD, 16, "eyebrow")
	var bets: Array = st["bets"]
	if bets.is_empty():
		_label(col, Dining.TEXT["bets_none"], UI.DIM, _small_size())
	for b in bets:
		_label(col, String(Dining.TEXT["bet_line"]) % [String(b.get("by_name", "")), Dining.bet_name(b, true), Dining.price_text(String(Towers.TOWERS.get(String(b.get("tower", "")), {}).get("essence", "air")), Dining.payout(b))], UI.TEXT, _small_size())


## Talking with a climber: who they are, your history, what they say, and
## your lines to pick from.
func _talk(col: VBoxContainer, rec: Dictionary) -> void:
	var prof = _prof()
	var att := Dining.attitude(prof, rec)
	var name_l := _label(col, String(rec.get("name", "")), Rivals.color_of(rec).lerp(UI.TEXT, 0.35), 22 if tp._small() else 24, "display")
	name_l.set_meta("diner_name", true)
	var marks := Rivals.marks_text(rec)
	_label(col, String(Dining.TEXT["marks"]) % marks, UI.DIM, _small_size())
	if int(rec.get("met", 0)) <= 0:
		_label(col, Dining.TEXT["never"], UI.DIM, _small_size())
	else:
		_label(col, String(Dining.TEXT["history"]) % Rivals.history_text(rec), UI.DIM, _small_size())
	var how := String(Dining.TEXT.get(att, ""))
	var pk := Dining.perks(prof)
	if att == "warm" and bool(pk["warm"]) and int(rec.get("rescued", 0)) <= 0 and int(rec.get("teamed", 0)) <= 0 and not bool(rec.get("owed", false)):
		how = String(Dining.TEXT["title_warm"]) % String(pk["name"])
	if how != "":
		_label(col, how, UI.GOOD if att == "warm" else UI.BAD, _small_size())
	if tip_line != "":
		var mode := "touch" if m.main.touch_active else ("pad" if m.main.pad_active else "keys")
		col.add_child(Entity.says(Entity.fill_keys(tip_line, mode, m.main.pad_ps), 28.0 if tp._small() else 34.0))
	if said != "":
		var q := _label(col, said, Color(0.98, 0.9, 0.76), 16 if tp._small() else 17, "italic")
		q.set_meta("dine_said", true)
	if got != "":
		_label(col, got, UI.GOLD, _small_size())
	match node:
		"rumor":
			_choice(col, Dining.TEXT["ask_back"], "dine:back", _go.bind("talk"))
		"bets":
			_bets(col, rec)
		"trade":
			_trades(col, rec)
		"duel":
			_duel(col, rec)
		_:
			_choice(col, Dining.TEXT["ask_rumor"], "dine:ask_rumor", _go.bind("rumor"))
			_choice(col, Dining.TEXT["ask_bet"], "dine:ask_bet", _go.bind("bets"))
			_choice(col, Dining.TEXT["ask_trade"], "dine:ask_trade", _go.bind("trade"))
			_choice(col, Dining.TEXT["ask_duel"], "dine:ask_duel", _go.bind("duel"))
	if node != "" and node != "talk" and node != "rumor":
		_choice(col, Dining.TEXT["ask_back"], "dine:back", _go.bind("talk"))
	_choice(col, Dining.TEXT["ask_bye"], "dine:bye", _bye)


func _bets(col: VBoxContainer, rec: Dictionary) -> void:
	var prof = _prof()
	if Dining.attitude(prof, rec) == "cold":
		return
	var offers: Array = Dining.bet_offers(prof, rec, _tower())
	var tw: String = String(Towers.TOWERS.get(Dining._tower_or_last(prof, _tower()), {}).get("name", ""))
	_label(col, String(Dining.TEXT["bet_tower"]) % tw, UI.DIM, _small_size())
	if not Dining.full_bets(prof, rec):
		_label(col, String(Dining.TEXT["bet_small"]) % int(Dining.RULES["stake_low"]), UI.DIM, _small_size())
	elif bool(Dining.perks(prof)["bets"]):
		_label(col, String(Dining.TEXT["title_bets"]) % String(Dining.perks(prof)["name"]), UI.GOOD, _small_size())
	for i in offers.size():
		var b: Button = _choice(col, String(Dining.TEXT["bet_pick"]) % [Dining.bet_name(offers[i]), Dining._num(float(offers[i]["odds"]))], "dine:bet", _pick.bind(i))
		if i == pick:
			tp._brass(b, true)
	if pick >= 0 and pick < offers.size():
		var kind := String(Towers.TOWERS.get(String(offers[pick].get("tower", "")), {}).get("essence", "air"))
		_label(col, String(Dining.TEXT["stake_note"]) % Essence.display(kind), UI.DIM, _small_size())
		var stakes := HBoxContainer.new()
		stakes.add_theme_constant_override("separation", 6)
		col.add_child(stakes)
		for s in Dining.stakes(prof, rec):
			var sb: Button = m._button(String(Dining.TEXT["stake"]) % int(s), _place.bind(int(s)), stakes)
			sb.set_meta("help", "dine:stake")
			sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sb.clip_text = true
			UI.keep_text(sb)
			sb.disabled = Dining.bet_why_not(prof, rec, int(s)) != ""


func _trades(col: VBoxContainer, rec: Dictionary) -> void:
	var prof = _prof()
	if Dining.attitude(prof, rec) == "cold":
		return
	var offers: Array = Dining.trade_offers(prof, rec)
	var any := false
	for i in offers.size():
		var o: Dictionary = offers[i]
		if o.get("done", false):
			continue
		any = true
		var price := Dining.price_text(String(o["kind"]), int(o["price"]))
		var give := String(o["type"]) == "give"
		var text: String = String(Dining.TEXT["trade_give" if give else "trade_buy"]) % [Dining.thing_name(o["thing"]), price]
		var short := ""
		if give:
			short = load(Dining.TRAIN).short_of(prof, String(o["kind"]), int(o["price"]))
		var b: Button = _choice(col, text + ("  ·  " + short if short != "" else ""), "dine:trade_give" if give else "dine:trade_buy", _trade.bind(i), short == "")
		b.set_meta("dine_trade", i)
	if not any:
		_label(col, Dining.TEXT["trade_none"], UI.DIM, _small_size())


func _duel(col: VBoxContainer, rec: Dictionary) -> void:
	var prof = _prof()
	var stakes: Array = Dining.duel_stakes(prof, rec)
	for i in stakes.size():
		var s: Dictionary = stakes[i]
		var b: Button = _choice(col, String(Dining.TEXT["duel_stake"]) % String(s["label"]) + ("" if s["ok"] else "  ·  " + String(Dining.TEXT["duel_short"])), "dine:duel_stake", _pick.bind(i), bool(s["ok"]))
		if i == pick:
			tp._brass(b, true)
	if pick >= 0 and pick < stakes.size() and bool(stakes[pick]["ok"]):
		_label(col, Dining.TEXT["duel_ready"], UI.DIM, _small_size())
		var go: Button = _choice(col, Dining.TEXT["duel_go"], "dine:duel_go", _begin_duel.bind(pick))
		m._danger(go)


# --- choices -------------------------------------------------------------------------------

func _talk_to(id: String) -> void:
	var prof = _prof()
	lines.clear()
	if who == id:
		return
	_reset()
	who = id
	node = "talk"
	var rec := Dining.remember(prof, id)
	if rec.is_empty():
		rec = Dining.find(prof, id)
	said = Dining.greeting(prof, rec) if not rec.is_empty() else ""
	got = Dining.gift(prof, rec) if not rec.is_empty() else ""
	if got != "":
		said = Dining.say("gift")
	tip_line = m.main.tip_now("dining_talk")
	m.main.sfx("ui_confirm")
	m.open("train")


func _rec() -> Dictionary:
	return Dining.find(_prof(), who)


func _go(where: String) -> void:
	var prof = _prof()
	var rec := _rec()
	if rec.is_empty():
		return
	node = where
	pick = -1
	got = ""
	tip_line = ""
	var cold := Dining.attitude(prof, rec) == "cold"
	match where:
		"talk":
			said = Dining.greeting(prof, rec)
		"rumor":
			if cold:
				said = Dining.say("cold_rumor")
			else:
				var r := Dining.rumor(prof, rec, _tower())
				said = String(r.get("text", "")) if not r.is_empty() else Dining.say("rumor_none")
				tip_line = m.main.tip_now("dining_rumor")
		"bets":
			said = Dining.say("cold_bet") if cold else Dining.say("bet_open")
			if not cold:
				tip_line = m.main.tip_now("dining_bet")
		"trade":
			said = Dining.say("cold_trade") if cold else Dining.say("trade_open")
		"duel":
			said = Dining.say("duel_open")
			tip_line = m.main.tip_now("dining_duel")
	m.main.sfx("ui_confirm")
	m.open("train")


func _pick(i: int) -> void:
	pick = i
	m.main.sfx("ui_confirm")
	m.open("train")


func _place(stake: int) -> void:
	var prof = _prof()
	var rec := _rec()
	var offers: Array = Dining.bet_offers(prof, rec, _tower())
	if pick < 0 or pick >= offers.size():
		return
	var offer: Dictionary = offers[pick]
	var why := Dining.place_bet(prof, rec, offer, stake)
	if why == "":
		got = String(Dining.TEXT["bet_placed"]) % [String(rec.get("name", "")), Dining.bet_name(offer, true)]
		pick = -1
		m.feedback("buy", "pickup")  # (its sound, and a flash on the button)
	else:
		got = why
	m.open("train")


func _trade(i: int) -> void:
	var prof = _prof()
	var res := Dining.trade(prof, m.main.player, _rec(), i)
	got = String(res.get("text", ""))
	if res.get("ok", false):
		m.feedback("buy", "pickup")
	m.open("train")


func _begin_duel(i: int) -> void:
	var prof = _prof()
	var rec := _rec()
	var stakes: Array = Dining.duel_stakes(prof, rec)
	if i < 0 or i >= stakes.size() or not bool(stakes[i]["ok"]):
		return
	var ev := Dining.duel_event(prof, rec, stakes[i])
	_reset()
	var why: String = m.main.arena.start(ev) if m.main.get("arena") != null else "?"
	if why != "":
		got = why
		m.open("train")


func _bye() -> void:
	var rec := _rec()
	_reset()
	if not rec.is_empty():
		lines = [String(rec.get("name", "")) + ": " + Dining.say("bye")]
	m.main.sfx("ui_back")
	m.open("train")


## A seated climber: drawn behind a laid table in their own look and gear
## (rivals.gd look_of, appearance.gd draw_front), a lamp on the cloth, a
## plate and a glass, their name on a brass plate (no marks or glow drawn on
## them: the owner's choice; the placard still names their marks). Drawn to the size the tables give it (bigger when few sit down).
## Gilt-edged when you're talking with them; a cold one sits in a cooler light.
class Diner extends Button:
	const UI := preload("res://scripts/ui.gd")
	const Art := preload("res://scripts/train_art.gd")
	const Appearance := preload("res://scripts/appearance.gd")
	const Rivals := preload("res://scripts/rivals.gd")
	const Bonds := preload("res://scripts/bonds.gd")
	## Where each mark sits on the front figure (as the climber screen's: menu.gd SPOTS).
	const SPOTS := {"brow": Vector2(0, -110), "throat": Vector2(0, -77), "heart": Vector2(-11, -47),
		"back": Vector2(24, -36), "hand": Vector2(-50, 9), "legs": Vector2(-11, 62)}
	var rec := {}
	var marks: Array = []  # [part, colour, step]
	var look := {}
	var mood := "plain"
	var on := false
	var cols: Array = []

	func setup(r: Dictionary, att: String) -> void:
		rec = r
		mood = att
		look = Rivals.look_of(r)
		cols = (r.get("bonds", []) as Array).map(func(b): return Rivals.bond_color(String(b[0])))
		marks = (r.get("bonds", []) as Array).map(func(b): return [String(b[1]), Rivals.bond_color(String(b[0])), int(b[2])])
		text = ""
		flat = true
		clip_contents = true
		focus_mode = Control.FOCUS_ALL
		for st in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
			add_theme_stylebox_override(st, StyleBoxEmpty.new())

	func _ready() -> void:
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
		resized.connect(queue_redraw)

	## How big the figure is drawn (pixels a unit of its frame; for the tests).
	func figure_scale() -> float:
		return (size.y * 0.6 - 4.0) / 150.0

	func _draw() -> void:
		var s := size
		var z := s.x / 104.0  # (its parts scale with it: 1 at its smallest on a computer)
		var lit: bool = on or has_focus() or is_hovered()
		var b := UI.Draw.Batch.new()
		var plate_h := clampf(s.y * 0.15, 14.0, 26.0)
		var table_y := s.y * 0.6
		var lamp := Vector2(s.x * 0.8, table_y - 2.0 * z)
		# The lamp's warm light on the wall behind.
		var warm := Color(1.0, 0.78, 0.45) if mood != "cold" else Color(0.65, 0.75, 0.95)
		Art.light(b, lamp + Vector2(0, -12.0 * z), Vector2(s.x * 0.6, s.y * 0.45), Color(warm, 0.16 if lit else 0.1))
		b.flush(self)
		# The climber, from the waist up, behind the table (no marks drawn on them: the owner's choice).
		var k := figure_scale()
		draw_set_transform(Vector2(s.x * 0.42, table_y + 6.0 * k), 0.0, Vector2(k, k))
		var fb := UI.Draw.Batch.new()
		fb.contact(Vector2(0, -2.0), 54.0, 0.3, 0.3)
		Appearance.draw_front(fb, look)
		fb.flush(self)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		var t := UI.Draw.Batch.new()
		# The table: a white cloth falling over its edge, a plate and a glass.
		var cloth := Rect2(2.0, table_y, s.x - 4.0, s.y - table_y - plate_h - 4.0)
		t.rect(cloth.grow(1.0), Art.OUTLINE)
		Art.vgrad(t, cloth, Color(0.93, 0.9, 0.84), Color(0.7, 0.66, 0.6))
		t.rect(Rect2(cloth.position, Vector2(cloth.size.x, 3.0)), Color(1, 1, 1, 0.5))
		var fx := cloth.position.x + 8.0 * z
		while fx < cloth.end.x - 4.0 * z:
			t.rect(Rect2(fx, cloth.position.y + 4.0 * z, maxf(1.0, z), cloth.size.y - 4.0 * z), Color(0, 0, 0, 0.08))
			fx += 9.0 * z
		var plate := Vector2(s.x * 0.36, table_y + 5.0 * z)
		t.polygon(UI._oval(plate, Vector2(12.0, 3.4) * z, 16), Color(0.55, 0.52, 0.5))
		t.polygon(UI._oval(plate, Vector2(10.0, 2.6) * z, 16), Color(0.98, 0.97, 0.94))
		var glass := Vector2(s.x * 0.58, table_y + 3.0 * z)
		t.polygon(PackedVector2Array([glass + Vector2(-3, -10) * z, glass + Vector2(3, -10) * z, glass + Vector2(2, -3) * z, glass + Vector2(-2, -3) * z]), Color(0.7, 0.2, 0.25, 0.75))
		t.rect(Rect2(glass + Vector2(-0.6, -3) * z, Vector2(1.2, 3) * z), Color(0.85, 0.85, 0.9, 0.8))
		t.rect(Rect2(glass + Vector2(-1.6, -9.4) * z, Vector2(0.9, 5.0) * z), Color(1, 1, 1, 0.35))
		# The lamp: a brass foot, a fringed shade, the bulb's glow.
		t.rect(Rect2(lamp + Vector2(-1.2, -12) * z, Vector2(2.4, 12) * z), Art.GILT.darkened(0.2))
		t.polygon(UI._oval(lamp, Vector2(5.0, 1.6) * z, 10), Art.GILT.darkened(0.3))
		var sh := lamp + Vector2(0, -16) * z
		t.polygon(PackedVector2Array([sh + Vector2(-5, -4) * z, sh + Vector2(5, -4) * z, sh + Vector2(8, 4) * z, sh + Vector2(-8, 4) * z]), Color(0.75, 0.32, 0.25) if mood != "cold" else Color(0.35, 0.45, 0.6))
		t.rect(Rect2(sh + Vector2(-8, 4) * z, Vector2(16, 1.2) * z), Art.GILT)
		Art.light(t, sh + Vector2(0, 6) * z, Vector2(14, 8) * z, Color(warm, 0.35))
		# The brass name plate.
		var pr := Rect2(4.0, s.y - plate_h - 2.0, s.x - 8.0, plate_h)
		t.rect(pr.grow(1.0), Art.OUTLINE)
		Art.vgrad(t, pr, Art.GILT.darkened(0.15) if lit else Art.GILT.darkened(0.45), Art.GILT.darkened(0.6))
		if lit:
			var edge := Rect2(Vector2.ZERO, s).grow(-1.0)
			t.path(PackedVector2Array([edge.position, Vector2(edge.end.x, edge.position.y), edge.end, Vector2(edge.position.x, edge.end.y)]), Color(UI.GILT, 0.9 if on else 0.55), 1.6, true)
		t.flush(self)
		var f := UI.font("display")
		var room := pr.size.x - 10.0
		UI.draw_text(self, f, Vector2(pr.position.x + 5.0, pr.end.y - plate_h * 0.25), String(rec.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, room, int(plate_h * 0.8), Color(0.12, 0.08, 0.05) if lit else Color(0.98, 0.9, 0.7))
