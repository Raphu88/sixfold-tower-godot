extends Node2D
## A POCKET DIMENSION'S VAULT (a secret room: floors.gd carves it, wings.gd
## hides its way in, portals.gd takes you there). Richer than a chest, and
## still modest (slow growth: the draw is the gear, not piles of essence):
##   three CHESTS: one holds a guaranteed piece of GEAR a rarity row above
##     the floor's usual (Fine at the least, its traits rolled); one holds a
##     choice of a few essence CRYSTALS (now and then a tincture in place of
##     one); the third holds a smaller crystal of the tower's own essence,
##     or, from floor 3, may be a MIMIC (mimic.gd) that springs when opened;
##   rarely a LEAD to the tower's Summit Blade (kept in the profile).
## Some vaults are GUARDED (floors.gd SECRET_CONTENTS: the record's
## "content"); the chests are chained shut until the guard is dealt with:
##   tithe   a LOCK: a pale Tithe Stone with an open hand asks for unbanked
##           essence; lean on it (walk into it from below) to pay
##   puzzle  three RUNES on the floor light up in an order when you arrive;
##           step on them in that order (a wrong one shows the order again)
##   keeper  a vault KEEPER (a crowned champion of the tower's monsters)
##           rises as you arrive; beat it and the chains fall
## Words and numbers: TEXT, RULES (the Data editor).

const Palette := preload("res://scripts/palette.gd")
const Draw := preload("res://scripts/draw_util.gd")
const ChestArt := preload("res://scripts/chest_art.gd")
const Essence := preload("res://scripts/essence.gd")
const Items := preload("res://scripts/items.gd")
const Gear := preload("res://scripts/gear.gd")

static var TEXT := {
	"vault": "A pocket vault: three chests.",
	"chained": "Chained shut",
	"gear": "Hidden away: %s",
	"crystals_title": "A VAULT CHEST",
	"crystals_sub": "Essence crystals, kept here. Choose one to take.",
	"small": "+ %s",
	"lead_title": "A LEAD",
	"lead": "A scrap of a map, marked by hand: a lead to %s's Summit Blade.",
	"tithe_title": "A TITHE STONE",
	"tithe": "It asks for %d essence you have not banked. It does not say what it keeps.",
	"tithe_lean": "Lean on it to pay %d unbanked essence.",
	"tithe_short": "It asks for %d unbanked essence. You carry %d.",
	"tithe_paid": "The tithe is paid. The chains fall.",
	"puzzle_title": "THE RUNES",
	"puzzle": "Watch the runes light, then step on them in that order.",
	"puzzle_wrong": "Wrong rune. Watch again.",
	"puzzle_done": "The runes hold. The chains fall.",
	"keeper_title": "THE VAULT'S KEEPER",
	"keeper": "Something keeps this vault. Beat it and the chains fall.",
	"keeper_name": "Keeper",
	"keeper_done": "The Keeper falls. The chains fall with it.",
	"open": "The chains fall",
}

## reach: how near you walk to open a chest (px); small: the third chest's
## crystal, a share of a vault crystal (wings.gd crystal_amount); mimic: how
## often the third chest is a mimic (from mimic.gd's floor); lead: how often
## a vault holds a lead to the Summit Blade; tithe: what the stone asks
## (base + per floor); show: seconds between runes as they light; keeper_wait:
## seconds before the Keeper rises.
static var RULES := {"reach": 30.0, "small": 0.35, "mimic": 0.25, "lead": 0.05, "tithe_base": 18.0, "tithe_per_floor": 4.0,
	"show": 0.65, "rune_r": 18.0, "keeper_wait": 1.6}

const GOLD := Color(0.95, 0.75, 0.35)
const RUNE := Color(0.62, 0.52, 1.0)
const PALE := Color(0.7, 0.85, 1.0)

var main
var leads := 0  # (tests) leads found this run
var _redraw_t := 0.0


func _ready() -> void:
	z_index = -2


## Lays a pocket's vault out in its room (wings.gd setup, for each secret):
## its portal back, three chests, and its guard. `s` is the wings.secrets
## record: tiles (Rect2i) and rect (world px) are already there.
static func lay_out(s: Dictionary, floor_num: int, first_climb: bool, cell: float) -> void:
	var tr: Rect2i = s["tiles"]
	var o: Vector2 = s["rect"].position
	var w := tr.size.x
	var h := tr.size.y
	for key in ["tithe_tile", "tithe_pos", "cost", "runes", "order", "step", "show_t", "keeper_state", "keeper_t", "keeper"]:
		s.erase(key)  # (laid out again: no guard of before stays)
	var at := func(x, y) -> Vector2:
		return o + (Vector2(x, y) + Vector2(0.5, 0.5)) * cell
	s["portal_in"] = at.call(w / 2, h - 1)
	var kinds: Array = ["gear", "crystals", "small"]
	var M = load("res://scripts/mimic.gd")
	if floor_num >= int(M.RULES["from"]) and (randf() < float(RULES["mimic"]) or M.forced):
		kinds[2] = "mimic"
	kinds.shuffle()
	var chests: Array = []
	for i in 3:
		chests.append({"pos": at.call(w / 2 - 2 + i * 2, 1), "kind": kinds[i], "taken": false})
	s["chests"] = chests
	s["lead"] = not first_climb and randf() < float(RULES["lead"])
	s["vault"] = "sealed" if String(s["content"]) in ["tithe", "puzzle", "keeper"] else "open"
	match String(s["content"]):
		"tithe":
			s["cost"] = float(RULES["tithe_base"]) + float(RULES["tithe_per_floor"]) * floor_num
			s["tithe_tile"] = tr.position + Vector2i(w / 2, h - 3)
			s["tithe_pos"] = at.call(w / 2, h - 3)
			s["lean_t"] = 0.0
		"puzzle":
			var runes: Array = []
			for i in 3:
				runes.append({"pos": at.call(w / 2 - 2 + i * 2, h - 3), "lit": false})
			s["runes"] = runes
			var order: Array = [0, 1, 2]
			order.shuffle()
			s["order"] = order
			s["step"] = 0
			s["show_t"] = -1.0
		"keeper":
			s["keeper_state"] = "waiting"
			s["keeper_t"] = float(RULES["keeper_wait"])


# --- in play -------------------------------------------------------------------------------

## The climber came through the portal into this pocket (portals.gd).
func on_enter(s: Dictionary) -> void:
	if s.get("chests", []).is_empty():
		return
	if s["chests"].any(func(c): return not c["taken"]):
		main.tip("pocket_vault")
	if s["vault"] != "sealed":
		return
	main.tip("vault_guard")
	match String(s["content"]):
		"tithe":
			s["told"] = false
		"puzzle":
			main.banner = {"title": TEXT["puzzle_title"], "lines": [TEXT["puzzle"]], "t": 3.0}
			_show_runes(s)
		"keeper":
			if s["keeper_state"] == "waiting":
				main.banner = {"title": TEXT["keeper_title"], "lines": [TEXT["keeper"]], "t": 2.8}


func _process(delta: float) -> void:
	if main == null or main.player == null or main.portals == null:
		return
	var s: Dictionary = main.portals.pocket
	_redraw_t -= delta
	if _redraw_t <= 0.0:
		_redraw_t = 1.0 / 20.0
		queue_redraw()
	if s.is_empty() or s.get("chests", []).is_empty():
		return
	var p = main.player
	if p.dead or main.camp_choosing or get_tree().paused:
		return
	var pos: Vector2 = p.global_position
	if s["vault"] == "sealed":
		match String(s["content"]):
			"tithe":
				_tick_tithe(s, delta, p)
			"puzzle":
				_tick_puzzle(s, delta, pos)
			"keeper":
				_tick_keeper(s, delta)
		return
	var reach: float = float(RULES["reach"]) + p.radius
	for c in s["chests"]:
		if not c["taken"] and pos.distance_to(c["pos"]) < reach:
			open_chest(s, c)
			return


## Opens a chest (walked up to it, the vault unguarded): what it holds.
func open_chest(s: Dictionary, c: Dictionary) -> void:
	if c["taken"]:
		return
	c["taken"] = true
	if s["chests"].all(func(x): return x["taken"]):
		s["taken"] = true
	var at: Vector2 = c["pos"]
	match String(c["kind"]):
		"mimic":
			c["sprung"] = true
			var e = main.spawn_enemy("mimic", at)
			e.global_position = at
			main.floor_total += 1
			var M = load("res://scripts/mimic.gd")
			main.fx_text(at + Vector2(0, -36), M.TEXT["spring"], Palette.DANGER.lightened(0.25))
			main.fx_burst(at, Vector2.UP, Color(0.62, 0.45, 0.3), 12, 160.0)
			main.sfx_at(at, "on_guard", 1.1, -2.0)
			main.sfx_at(at, "door_open", 1.4, -4.0)  # (the lid creaks up: a mimic)
			main.shake(3.0)
			main.tip("mimic")
			return
		"gear":
			var g = main.find_gear("", 1, "fine")  # (a rarity row above the floor's, Fine at the least, its traits rolled)
			if not g.is_empty():
				main.drop_gear(at + Vector2(0, 26), g, true)
				main.notices.feed(TEXT["gear"] % Gear.display(g), Gear.color(g), "gear")
		"crystals":
			main.offer_vault(main.wings.hidden_crystals(), TEXT["crystals_title"], [TEXT["crystals_sub"]])
		_:
			var kind: String = main.tower_data().get("essence", "air")
			var amt := float(roundi(main.wings.crystal_amount() * float(RULES["small"])))
			main.profile.add_crystal(kind, amt)
			main.profile.save()
			var name: String = Items.CRYSTAL["name"] % Essence.display(kind)
			main.note_event("crystal", TEXT["small"] % ("%s (%d)" % [name, int(amt)]), Essence.color(kind))
	if bool(s.get("lead", false)) and c["kind"] in ["crystals", "small", "gear"] and s["chests"].all(func(x): return x["taken"] or x["kind"] == "mimic"):
		give_lead(s)
	main.fx_ring(at, Color(1.0, 0.85, 0.5), 50.0, 0.4, 3.0)
	main.sfx("chime", 1.25, -3.0)


## A lead to the tower's Summit Blade (another part of the game finds the
## blade): kept in the profile, counted per tower.
func give_lead(s: Dictionary) -> void:
	s["lead"] = false
	leads += 1
	var prof = main.profile
	var tower: String = String(main.tower)
	var have = prof.get("summit_leads")
	if have is Dictionary:
		have[tower] = int(have.get(tower, 0)) + 1
	else:
		prof.note("summit_leads:" + tower)
	prof.save()
	main.banner = {"title": TEXT["lead_title"], "lines": [TEXT["lead"] % main.beast_name()], "t": 3.4}
	main.sfx("pedestal", 1.0, -4.0, 0.0)


## How many leads to this tower's Summit Blade the climber holds.
static func lead_count(prof, tower: String) -> int:
	var have = prof.get("summit_leads")
	if have is Dictionary:
		return int(have.get(tower, 0))
	return int(prof.record.get("summit_leads:" + tower, 0.0))


func _unchain(s: Dictionary, line: String) -> void:
	s["vault"] = "open"
	main.banner = {"title": String(TEXT["open"]).to_upper(), "lines": [line], "t": 2.6}
	main.sfx("lock_turn", 1.0, -2.0, 0.0)
	main.sfx("clear", 1.1, -4.0, 0.0)
	main.shake(3.0)
	for c in s["chests"]:
		main.fx_burst(c["pos"], Vector2.UP, GOLD, 8, 100.0)
	main.MakersScript.feed(main, "vault")


# --- the Tithe Stone ----------------------------------------------------------------------

func _tick_tithe(s: Dictionary, delta: float, p) -> void:
	var at: Vector2 = s["tithe_pos"]
	var near: bool = p.global_position.distance_to(at) < 70.0 + p.radius
	var cost := int(s["cost"])
	var held := _held()
	if near and not s.get("told", false):
		s["told"] = true
		var line: String = TEXT["tithe_lean"] % cost if held >= cost else TEXT["tithe_short"] % [cost, int(held)]
		main.banner = {"title": TEXT["tithe_title"], "lines": [TEXT["tithe"] % cost, line], "t": 3.5, "inscribed": 1}
	elif not near:
		s["told"] = false
	if main.wings._leaning(s["tithe_tile"], Vector2.UP, p, s, delta):
		s["lean_t"] = 0.0
		if held + 0.001 < cost:
			main.fx_text(at + Vector2(0, -30), TEXT["tithe_short"] % [cost, int(held)], Color(0.85, 0.6, 0.55))
			main.sfx("hit_armor", 0.6, -6.0, 0.0)
			return
		pay_tithe(s)


func _held() -> float:
	var held := 0.0
	for k in main.run_essence:
		held += float(main.run_essence[k])
	return held


## Pays the Tithe Stone from unbanked essence (each kind in its share): the stone sinks, the chains fall.
func pay_tithe(s: Dictionary) -> bool:
	if String(s.get("content", "")) != "tithe" or s["vault"] != "sealed":
		return false
	var cost := float(s["cost"])
	var held := _held()
	if held + 0.001 < cost:
		return false
	for k in main.run_essence.keys():
		main.run_essence[k] = maxf(0.0, float(main.run_essence[k]) - cost * float(main.run_essence[k]) / held)
	main.wings._open([s["tithe_tile"]], s.get("tithe_body"))
	s["tithe_body"] = null
	main.room_view.queue_redraw()
	main.fx_burst(s["tithe_pos"], Vector2.UP, PALE, 22, 200.0)
	main.fx_text(s["tithe_pos"] + Vector2(0, -26), TEXT["tithe_paid"], PALE)
	_unchain(s, TEXT["tithe_paid"])
	return true


# --- the runes -----------------------------------------------------------------------------

func _show_runes(s: Dictionary) -> void:
	s["show_t"] = 0.0
	s["step"] = 0
	for r in s["runes"]:
		r["lit"] = false


func _tick_puzzle(s: Dictionary, delta: float, pos: Vector2) -> void:
	if float(s["show_t"]) >= 0.0:
		s["show_t"] = float(s["show_t"]) + delta
		if float(s["show_t"]) > float(RULES["show"]) * 4.0:
			s["show_t"] = -1.0
		return
	var near: float = float(RULES["rune_r"]) + main.player.radius * 0.5
	for i in s["runes"].size():
		var r: Dictionary = s["runes"][i]
		if r["lit"] or pos.distance_to(r["pos"]) > near:
			continue
		step_rune(s, i)
		return


## Steps on rune `i`: the right one lights; a wrong one shows the order again.
func step_rune(s: Dictionary, i: int) -> void:
	var r: Dictionary = s["runes"][i]
	if r["lit"] or s["vault"] != "sealed":
		return
	if int(s["order"][int(s["step"])]) != i:
		main.fx_text(r["pos"] + Vector2(0, -30), TEXT["puzzle_wrong"], Color(0.9, 0.6, 0.55))
		main.sfx("puzzle_fail", 1.0, -4.0, 0.0)
		_show_runes(s)
		return
	r["lit"] = true
	s["step"] = int(s["step"]) + 1
	main.sfx("step_plate", 1.0 + 0.1 * int(s["step"]), -2.0, 0.0)
	main.fx_ring(r["pos"], RUNE, 40.0, 0.35, 3.0)
	if int(s["step"]) >= s["runes"].size():
		main.sfx("puzzle_solve", 1.0, -2.0, 0.0)
		_unchain(s, TEXT["puzzle_done"])


## Which rune lights now while the order is shown (-1 between them).
func shown_rune(s: Dictionary) -> int:
	var t := float(s.get("show_t", -1.0))
	if t < 0.0:
		return -1
	var k := int(t / float(RULES["show"]))
	if k < 1 or k > 3 or fmod(t, float(RULES["show"])) > float(RULES["show"]) * 0.75:
		return -1
	return int(s["order"][k - 1])


# --- the Keeper ----------------------------------------------------------------------------

func _tick_keeper(s: Dictionary, delta: float) -> void:
	match String(s["keeper_state"]):
		"waiting":
			s["keeper_t"] = float(s["keeper_t"]) - delta
			if float(s["keeper_t"]) <= 0.0:
				_raise_keeper(s)
		"fighting":
			var k = s.get("keeper")
			if k == null or not is_instance_valid(k) or k.dead:
				s["keeper_state"] = "done"
				s["keeper"] = null
				_unchain(s, TEXT["keeper_done"])


func _raise_keeper(s: Dictionary) -> void:
	var weights: Dictionary = main.tower_data().get("weights", {})
	var kind := ""
	for i in 12:
		var k: String = main.Floors._pick(maxi(main.floor_num, 2), 9.0, 0, weights)
		if k != "" and (kind == "" or float(main.Floors.MONSTERS[k]["cost"]) > float(main.Floors.MONSTERS[kind]["cost"])):
			kind = k
	if kind == "" or kind in ["bloomcap", "lurker", "deepfin", "harrier"]:
		kind = "knight"  # (one that walks a small room)
	var at: Vector2 = s["rect"].get_center() + Vector2(0, -s["rect"].size.y * 0.2)  # (well away from the portal back)
	var e = main.EnemyScript.make(kind)
	e.setup(kind, main)
	e.make_champion()
	var tough: Vector2 = main.Floors.toughness(main.floor_num)
	e.max_hp *= tough.x
	e.hp = e.max_hp
	e.dmg *= tough.y
	e.position = at
	e.state_t = 0.8
	main.add_child(e)
	e.wake()
	main.floor_total += 1
	s["keeper"] = e
	s["keeper_state"] = "fighting"
	main.fx_burst(at, Vector2.UP, GOLD, 26, 200.0)
	main.fx_ring(at, GOLD, 70.0, 0.5, 4.0)
	main.light_flash(at, GOLD, 1.8, 1.8, 0.5)
	main.fx_text(at + Vector2(0, -50), TEXT["keeper_name"], GOLD)
	main.shake(6.0)


# --- drawing -------------------------------------------------------------------------------

func _draw() -> void:
	if main == null or main.wings == null:
		return
	var t := Time.get_ticks_msec() * 0.001
	var b := Draw.Batch.new()
	var mimics: Array = []  # (drawn by mimic.gd straight onto this node, after the batch)
	for s in main.wings.secrets:
		if not s["open"] or s.get("chests", []).is_empty():
			continue
		_draw_floor(b, s, t)
		var sealed: bool = s["vault"] == "sealed"
		match String(s["content"]):
			"tithe":
				if sealed:
					_draw_tithe(b, s["tithe_pos"], t)
			"puzzle":
				var shown := shown_rune(s)
				for i in s["runes"].size():
					var r: Dictionary = s["runes"][i]
					_draw_rune(b, r["pos"], r["lit"] or not sealed, shown == i, t)
		var pulse := 0.5 + 0.5 * sin(t * 3.0)
		for c in s["chests"]:
			if c.get("sprung", false):
				continue
			if c["kind"] == "mimic" and not c["taken"]:
				mimics.append([{"pos": c["pos"], "open": not sealed}, sealed])
			else:
				_draw_chest(b, c, not sealed, pulse)
				if sealed and not c["taken"]:
					_draw_chains(b, c["pos"])
	b.flush(self)
	var pulse2 := 0.5 + 0.5 * sin(t * 3.0)
	if not mimics.is_empty():
		var cb := Draw.Batch.new()
		for m in mimics:
			load("res://scripts/mimic.gd").draw_waiting(cb, m[0], pulse2, t)
			if m[1]:
				_draw_chains(cb, m[0]["pos"])
		cb.flush(self)
	var font := ThemeDB.fallback_font
	for s in main.wings.secrets:
		if s["open"] and String(s.get("content", "")) == "tithe" and s.get("vault", "") == "sealed":
			draw_string(font, s["tithe_pos"] + Vector2(-30, 36), "%d" % int(s["cost"]), HORIZONTAL_ALIGNMENT_CENTER, 60, 12, Color(PALE, 0.9))


## The pocket's floor: a faint ring of light inlaid in it (a place outside the floor).
func _draw_floor(b, s: Dictionary, t: float) -> void:
	var r: Rect2 = s["rect"]
	var c := r.get_center()
	b.rect(r, Color(0.45, 0.35, 0.9, 0.06))
	var rad := minf(r.size.x, r.size.y) * 0.42
	b.arc(c, rad, 0.0, TAU, 40, Color(RUNE, 0.16), 2.0)
	b.arc(c, rad * 0.8, t * 0.1, t * 0.1 + TAU, 40, Color(RUNE, 0.08), 1.5)
	for i in 6:
		var ang := TAU * i / 6.0 + t * 0.1
		b.dot(c + Vector2.from_angle(ang) * rad, 3.0, Color(RUNE, 0.25))
	# Motes drifting up, slowly (the air of somewhere else).
	for i in 8:
		var f := fmod(t * 0.12 + i * 0.137, 1.0)
		var x := r.position.x + fmod(i * 61.0 + 13.0, r.size.x)
		b.dot(Vector2(x, r.end.y - f * r.size.y), 1.5, Color(0.8, 0.75, 1.0, 0.5 * sin(f * PI)))


## A vault's chest (chest_art.gd): rich, its gear chest in a darker,
## plum-stained wood; chained while the vault is sealed.
func _draw_chest(b, c: Dictionary, unchained: bool, pulse: float) -> void:
	var at: Vector2 = c["pos"]
	var wood := Color(0.5, 0.36, 0.2) if c["kind"] != "gear" else Color(0.42, 0.3, 0.36)
	ChestArt.draw(b, at, {"rich": true, "wood": wood, "ready": unchained, "taken": c["taken"], "pulse": pulse, "t": Time.get_ticks_msec() * 0.001})
	if c["taken"]:
		return
	if unchained:
		b.arc(at + Vector2(0, 4), 20.0, 0.0, TAU, 24, Color(1.0, 0.84, 0.45, 0.2 + 0.25 * pulse), 2.0)


func _draw_chains(b, at: Vector2) -> void:
	var col := Color(0.58, 0.58, 0.62)
	for k in 2:
		var a := at + Vector2(-15, -8 + k * 14)
		var e := at + Vector2(15, 6 - k * 14)
		for i in 6:
			b.arc(a.lerp(e, (i + 0.5) / 6.0), 2.6, 0.0, TAU, 8, col, 1.3)


func _draw_tithe(b, c: Vector2, t: float) -> void:
	var r := Rect2(c - Vector2(20, 20), Vector2(40, 40))
	var col := Color(PALE, 0.65 + 0.2 * sin(t * 2.0))
	b.rect(r, Palette.OUTLINE)
	b.rect(r.grow(-2.0), Color(0.42, 0.44, 0.5))
	b.rect(r.grow(-5.0), Color(0.48, 0.5, 0.56))
	b.rect(Rect2(c + Vector2(-6, -2), Vector2(12, 10)), col)
	for i in 4:
		b.rect(Rect2(c + Vector2(-6 + i * 3.2, -10 + absf(i - 1.5) * 1.5), Vector2(2.4, 8)), col)
	b.rect(Rect2(c + Vector2(6, 0), Vector2(5, 2.5)), col)
	b.rect(Rect2(c + Vector2(-5, 12), Vector2(10, 2)), Palette.OUTLINE)


func _draw_rune(b, c: Vector2, lit: bool, flash: bool, t: float) -> void:
	var on := lit or flash
	var col := RUNE.lightened(0.35) if on else Color(0.35, 0.32, 0.45)
	b.circle(c, 17.0, Palette.OUTLINE)
	b.circle(c, 15.0, Color(0.2, 0.18, 0.26))
	b.arc(c, 11.0, 0.0, TAU, 20, Color(col, 0.9 if on else 0.6), 2.0)
	for i in 3:
		var ang := TAU * i / 3.0 - PI / 2.0
		b.line(c + Vector2.from_angle(ang) * 4.0, c + Vector2.from_angle(ang) * 10.0, Color(col, 0.9 if on else 0.6), 2.0)
	if on:
		b.dot(c, 18.0 + 2.0 * sin(t * 6.0), Color(RUNE, 0.18))
