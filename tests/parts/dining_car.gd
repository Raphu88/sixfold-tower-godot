extends RefCounted
## The Dining car (dining.gd, dining_page.gd) and the Arena car (arena.gd
## type "duel", arena_car.gd): the car seats met rivals and new faces;
## talking works by touch at phone size; every rumor is true (each fact
## function checked against the game's own tables) and a weakness fills its
## Bestiary line; a wager is placed, tracked in play (the line at the top,
## the Entity's log) and settled when the climb ends, won, lost and called
## off; trades are at fair prices and follow your history (a robbed climber
## refuses); a duel takes you to the Arena car, can be won and lost without
## dying, pays the stake and updates the records (the Duelist title too);
## the Arena car is never on the rail; climbers recur between the car and
## the towers; the Entity explains it all; old saves load; no banned words.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const D := preload("res://scripts/dining.gd")
const Rv := preload("res://scripts/rivals.gd")
const Train := preload("res://scripts/train.gd")
const TowerNeeds := preload("res://scripts/tower_needs.gd")
const Towers := preload("res://scripts/towers.gd")
const Bonds := preload("res://scripts/bonds.gd")
const Enemy := preload("res://scripts/enemy.gd")
const Bestiary := preload("res://scripts/bestiary.gd")
const Renown := preload("res://scripts/renown.gd")
const Entity := preload("res://scripts/entity.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const Help := preload("res://scripts/entity_help.gd")
const Gear := preload("res://scripts/gear.gd")
const Items := preload("res://scripts/items.gd")
const Essence := preload("res://scripts/essence.gd")
const ArenaCar := preload("res://scripts/arena_car.gd")
const Registry := preload("res://scripts/data_registry.gd")

const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

var t
var P = load("res://scripts/profile.gd")
var keep_rules := {}


## A monster's stand-in for a wager's count (dining.gd on_kill reads these).
class FakeFoe extends RefCounted:
	var kind := ""
	var shade := false
	var boss := false

	func is_boss() -> bool:
		return boss


func run(smoke) -> void:
	t = smoke
	print("the Dining car and the Arena car")
	keep_rules = D.RULES.duplicate(true)
	await _begin()
	_seats()
	await _talk_by_touch()
	_rumors()
	await _bets()
	_trades()
	await _duels()
	await _recurring()
	await _rail()
	await _entity()
	_saves()
	_words()
	await _end()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _main():
	return t.main


func _menu():
	return t.main.menu


func _tp():
	return t.main.menu.train_page


## A met climber's record, as the towers keep them.
func _rival(fl: int, extra: Dictionary) -> Dictionary:
	var maker = Rv.new()
	var rec: Dictionary = maker.new_rival(fl, "kraken")
	maker.free()
	rec["met"] = 2
	rec["seen"] = 100 + randi() % 100
	rec["climb"] = 0
	rec.merge(extra, true)
	return rec


func _begin() -> void:
	await t._fresh_main()
	t.paused = false
	var main = _main()
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.grant_test_bonds()
	var prof = main.profile
	for k in Essence.KINDS:
		prof.add_crystal(k, 300)
	prof.chest = [Gear.make("iron_helm"), Gear.make("travel_cloak", "fine", ["riposte"]), Gear.make("leather_gloves")]
	prof.pack = []
	prof.supplies = {}
	prof.dining = {}
	var plain := _rival(4, {"name": "Plainone"})
	var robbed := _rival(4, {"name": "Robbedone", "robbed": 1})
	var helped := _rival(4, {"name": "Helpedone", "rescued": 1, "owed": true})
	prof.rivals = {plain["id"]: plain, robbed["id"]: robbed, helped["id"]: helped}
	main.await_tower()
	main.open_train()
	await t._frames(3)
	_menu().train_tower = "kraken"


func _end() -> void:
	D.RULES = keep_rules
	Rv.force_return = -1
	var main = _main()
	var menu = _menu()
	if main.arena.on:
		main.arena.give_up()
		await t._frames(4)
	if menu.is_open():
		menu.close()
	t.root.size = Vector2i(1280, 720)
	main.touch._set_active(false)
	main.apply_view_scale()
	main.on_train = false
	t.paused = false
	await t._frames(2)


func _settled() -> void:
	var v = _menu().train_view
	for i in 240:
		if v.pos == float(v.target):
			break
		await t.process_frame
	await t._frames(2)


func _car(car: String) -> void:
	var menu = _menu()
	menu.train_car = car
	menu.open("train")
	await t._frames(2)
	_tp().go_to(_tp()._index(car))
	await _settled()


func _dining_buttons() -> Array:
	var root = _tp().roots.get("dining")
	if root == null or not is_instance_valid(root):
		return []
	return root.find_children("*", "BaseButton", true, false).filter(func(b): return b.is_visible_in_tree())


func _button(help: String) -> BaseButton:
	for b in _dining_buttons():
		if String(b.get_meta("help", "")) == help:
			return b
	return null


## A seated climber who'll talk (not cold), one you've met if there is one.
func _seated_talker() -> Dictionary:
	var prof = _main().profile
	var best := {}
	for r in D.seated(prof, "kraken"):
		if D.attitude(prof, r) == "cold":
			continue
		if best.is_empty() or (int(r.get("met", 0)) > 0 and int(best.get("met", 0)) <= 0):
			best = r
	if Rv.state(prof).has(String(best.get("id", ""))):
		return Rv.state(prof)[best["id"]]
	D.remember(prof, String(best.get("id", "")))
	return Rv.state(prof).get(String(best.get("id", "")), best)


func _by_name(name: String) -> Dictionary:
	for r in Rv.state(_main().profile).values():
		if r is Dictionary and String(r.get("name", "")) == name:
			return r
	return {}


# --- who sits in the car -------------------------------------------------------------------

func _seats() -> void:
	var prof = _main().profile
	var people: Array = D.seated(prof, "kraken")
	var met: Array = people.filter(func(r): return Rv.state(prof).has(String(r["id"])))
	var fresh: Array = people.filter(func(r): return not Rv.state(prof).has(String(r["id"])))
	_check(people.size() >= int(D.RULES["seats_min"]) and people.size() <= int(D.RULES["seats_max"]), "the Dining car seats %d to %d climbers (%d)" % [int(D.RULES["seats_min"]), int(D.RULES["seats_max"]), people.size()])
	_check(met.size() >= 2 and fresh.size() >= 1, "...mostly climbers you've met (%d), and a new face (%d)" % [met.size(), fresh.size()])
	_check(fresh.all(func(r): return r.has("name") and not (r.get("bonds", []) as Array).is_empty() and r.has("app") and int(r.get("met", 0)) == 0), "...new faces made by the rival system: a name, a look and marks")
	var again: Array = D.seated(prof, "kraken").map(func(r): return String(r["id"]))
	_check(again == people.map(func(r): return String(r["id"])), "...the same company while the visit lasts")
	var st := D.state(prof)
	var keep: Array = st["seats"].duplicate()
	var keep_faces: Dictionary = st["faces"].duplicate(true)
	st["trips"] = int(st["trips"]) + 1
	var next: Array = D.seated(prof, "kraken")
	_check(int(st["seat_trip"]) == int(st["trips"]) and next.size() >= int(D.RULES["seats_min"]), "...and a new company next visit")
	st["trips"] = int(st["trips"]) - 1
	st["seat_trip"] = int(st["trips"])
	st["seats"] = keep
	st["faces"] = keep_faces
	st["offers"] = {}


# --- talking, by touch at phone size ---------------------------------------------------------

func _talk_by_touch() -> void:
	var main = _main()
	var menu = _menu()
	t.root.size = Vector2i(915, 412)
	main.touch._set_active(true)
	main.apply_view_scale()
	await t._frames(3)
	await _car("dining")
	var diners: Array = _dining_buttons().filter(func(b): return b.has_meta("diner"))
	_check(diners.size() == D.seated(main.profile, "kraken").size(), "the car shows each seated climber at a table (%d)" % diners.size())
	var view := Rect2(Vector2.ZERO, Vector2(t.root.size))
	var small: Array = _dining_buttons().filter(func(b): return not view.encloses(b.get_global_rect()) and _tp()._scroll_of(b) == null)
	_check(small.is_empty(), "...every one on the screen at 915 x 412")
	var face: Dictionary = {}
	for r in D.seated(main.profile, "kraken"):
		if not Rv.state(main.profile).has(String(r["id"])):
			face = r
	var target: BaseButton = null
	for d in diners:
		if String(d.get_meta("diner")) == String(face.get("id", "")):
			target = d
	_check(target != null and target.get_global_rect().size.y >= 60.0, "a new face's table is big enough to tap")
	if target == null:
		return
	await t._tap_at(target.get_global_rect().get_center())
	await t._frames(3)
	var dp = _tp().dining
	_check(dp.who == String(face["id"]) and dp.node == "talk" and dp.said != "", "tapping a climber starts a talk: they speak first (%s)" % dp.said)
	_check(Rv.state(main.profile).has(String(face["id"])) and int(Rv.state(main.profile)[face["id"]].get("met", 0)) == 1, "...and a new face joins the climbers you've met")
	var asks: Array = ["dine:ask_rumor", "dine:ask_bet", "dine:ask_trade", "dine:ask_duel", "dine:bye"]
	_check(asks.all(func(h): return _button(h) != null), "...with your lines to pick: a rumor, a wager, a trade, a duel, goodbye")
	var rb := _button("dine:ask_rumor")
	var sc = _tp()._scroll_of(rb)
	if sc != null:
		sc.ensure_control_visible(rb)
		await t._frames(2)
	await t._tap_at(rb.get_global_rect().get_center())
	await t._frames(3)
	_check(dp.node == "rumor" and dp.said != "" and not dp.said.contains("{"), "a tapped line answers: a rumor (%s)" % dp.said)
	var bye := _button("dine:bye")
	sc = _tp()._scroll_of(bye)
	if sc != null:
		sc.ensure_control_visible(bye)
		await t._frames(2)
	await t._tap_at(bye.get_global_rect().get_center())
	await t._frames(3)
	_check(dp.who == "" and _button("dine:bye") == null, "Goodbye ends the talk")
	t.root.size = Vector2i(1280, 720)
	main.touch._set_active(false)
	main.apply_view_scale()
	await t._frames(3)


# --- rumors: true, and useful ------------------------------------------------------------------

func _rumors() -> void:
	var prof = _main().profile
	var tw := "kraken"
	var bad: Array = []
	var seen := {}
	for r in D.RUMORS:
		for i in 6:
			var f := D.fact(prof, String(r["fact"]), tw, "")
			if f.is_empty():
				continue
			seen[String(r["fact"])] = true
			if not _fact_true(prof, f):
				bad.append("%s %s" % [r["fact"], f])
			var text := D.fill_in(String(r["lines"][0]), f)
			if text.contains("{"):
				bad.append("%s left a blank: %s" % [r["fact"], text])
	_check(bad.is_empty(), "every rumor's fact is true by the game's own tables (%s)" % [bad.slice(0, 3)])
	_check(seen.size() >= D.RUMORS.size() - 1, "...and nearly every kind of rumor has something to say (%s)" % [seen.keys()])
	# A weakness heard fills that Bestiary line.
	var keep: Array = D.RUMORS
	D.RUMORS = keep.filter(func(r): return String(r["fact"]) == "weakness")
	var rec: Dictionary = _by_name("Plainone")
	var offers: Dictionary = D.state(prof)["offers"].get(String(rec["id"]), {})
	offers.erase("rumor_said")
	var heard := D.rumor(prof, rec, tw)
	D.RUMORS = keep
	var kind := String(heard.get("fact", {}).get("kind", ""))
	var lines: Array = Bestiary.lines(prof, kind)
	_check(kind != "" and lines.any(func(l): return l[0] == "weak" and String(l[1]).contains(String(Enemy.WEAKNESS[kind]))), "a weakness heard in the Dining car shows in the Bestiary (%s)" % kind)
	_check(D.knows_weakness(prof, kind) and D.fact(prof, "weakness", tw).get("kind", "") != kind, "...and the next rumor tells something else")
	# A cold climber shares nothing.
	var cold: Dictionary = _by_name("Robbedone")
	_check(D.attitude(prof, cold) == "cold" and D.attitude(prof, _by_name("Helpedone")) == "warm" and D.attitude(prof, rec) == "plain", "attitude follows history: robbed is cold, helped is warm")


## A rumor's fact against the game's tables.
func _fact_true(prof, f: Dictionary) -> bool:
	match String(f.get("type", "")):
		"handy":
			var tw := String(f["tower_id"])
			return String(f["item_id"]) in TowerNeeds.handy(tw) and String(f["item"]) == String(Items.ITEMS[f["item_id"]]["name"]) and String(f["why"]) == TowerNeeds.why(tw, String(f["item_id"]))
		"weakness":
			var k := String(f["kind"])
			var tw2: Dictionary = Towers.TOWERS[f["tower_id"]]
			return Enemy.WEAKNESS.has(k) and String(f["weak"]).to_lower() == String(Enemy.WEAKNESS[k]).to_lower() and ((tw2.get("weights", {}) as Dictionary).has(k) or String(tw2.get("beast_kind", "")) == k)
		"beast":
			var tw3: Dictionary = Towers.TOWERS[f["tower_id"]]
			return String(f["beast"]).to_lower() == String(tw3["beast"]).to_lower() and String(f["hint"]) == String(tw3["beast_hint"])
		"rival_mark":
			var r: Dictionary = Rv.state(prof).get(String(f["rival"]), {})
			return (r.get("bonds", []) as Array).any(func(b): return String(b[0]) == String(f["bond"]) and String(b[1]) == String(f["part_id"]) and int(b[2]) == int(f["step"])) and String(f["name"]) == String(r.get("name", ""))
		"dark":
			return TowerNeeds.DARK.has(String(f["tower_id"])) and int(TowerNeeds.DARK[f["tower_id"]]["from"]) == int(f["floor"])
		"wing":
			var C: Dictionary = load("res://scripts/wings.gd").CONDITIONS
			return C.has(String(f["condition"])) and int(C[f["condition"]]["from"]) == int(f["floor"]) and String(C[f["condition"]]["rule"]) == String(f["rule"])
		"best_bet":
			var best := 0.0
			for r2 in D.seated(prof, "kraken"):
				if D.attitude(prof, r2) != "cold":
					for o in D.bet_offers(prof, r2, "kraken"):
						best = maxf(best, float(o["odds"]))
			return absf(best - float(f["odds_value"])) < 0.001
	return false


# --- wagers --------------------------------------------------------------------------------------

func _bets() -> void:
	var main = _main()
	var prof = main.profile
	var plain: Dictionary = _by_name("Plainone")
	var helped: Dictionary = _by_name("Helpedone")
	var offers: Array = D.bet_offers(prof, plain, "kraken")
	_check(offers.size() == 2 and offers.all(func(o): return float(o["odds"]) > 1.0 and String(o["tower"]) == "kraken"), "a climber offers two wagers on your next climb, with odds")
	var warm_odds: Array = D.bet_offers(prof, helped, "kraken")
	_check(warm_odds.all(func(o): return D.BETS.has(String(o["kind"]))), "...from the table of wagers")
	# Odds by difficulty: a floor further past your best pays more.
	var by: Array = [float(D.RULES["odds_floor_1"]), float(D.RULES["odds_floor_2"]), float(D.RULES["odds_floor_3"])]
	_check(by[0] < by[1] and by[1] < by[2] and float(D.RULES["odds_beast"]) > float(D.RULES["odds_beast_again"]), "...harder wagers pay better")
	# Place a floor wager and a dry one (fixed, for the test).
	D.state(prof)["bets"] = []
	var held0: float = prof.crystals_held()
	var floor_bet := {"kind": "floor", "tower": "kraken", "floor": 3, "odds": 2.0, "by": plain["id"], "by_name": plain["name"]}
	var dry_bet := {"kind": "dry", "tower": "kraken", "floor": 2, "odds": 1.8, "by": plain["id"], "by_name": plain["name"]}
	var why1 := D.place_bet(prof, plain, floor_bet, 10)
	var why2 := D.place_bet(prof, plain, dry_bet, 20)
	_check(why1 == "" and why2 == "" and D.state(prof)["bets"].size() == 2 and absf(prof.crystals_held() - (held0 - 30.0)) < 0.5, "two wagers placed, the stakes paid in crystals (%s, %s)" % [why1, why2])
	var why3 := D.place_bet(prof, plain, {"kind": "beast", "tower": "kraken", "odds": 3.0}, 10)
	_check(why3 != "" and D.state(prof)["bets"].size() == 2, "...two at most (%s)" % why3)
	_check(D.place_bet(prof, _by_name("Robbedone"), {"kind": "beast", "tower": "kraken", "odds": 3.0}, 10) != "", "a cold climber won't take a wager")
	# The climb: the wagers run, show at the top and in the Entity's log.
	var water0: float = prof.crystal_total("water")
	main.depart("kraken")
	await t._frames(3)
	var running: bool = D.state(prof)["bets"].all(func(b): return b.get("running", false))
	var chips: Array = main.hud.status_chips().filter(func(c): return String(c.get("id", "")) == "wager")
	_check(running and chips.size() == 2, "in the climb the wagers run, each a line at the top (%d)" % chips.size())
	_check(main.notices.log.any(func(l): return String(l.get("text", "")).contains(D.bet_name(floor_bet, true))), "...and the Entity's log notes them")
	# Reach floor 3, but drink a Healing Draught: one won, one lost.
	main.floor_num = 3
	D.on_item(main, "draught")
	main.pay_climb()
	var lines: Array = D.state(prof)["news"]
	var paid := D.payout({"stake": 10, "odds": 2.0})
	_check(absf(prof.crystal_total("water") - (water0 + float(paid))) < 1.5 + float(Train.climb_pay(3, 0)) and prof.crystal_total("water") >= water0 + float(paid), "when the climb ends a won wager pays the stake times the odds in the tower's essence (+%d)" % paid)
	_check(lines.size() == 2 and String(lines[0]).contains("Won") and String(lines[1]).contains("Lost") and D.state(prof)["bets"].is_empty(), "...a lost one keeps your stake, and both are settled (%s)" % [lines])
	# Back on the train, the car says so.
	main.await_tower()
	main.open_train()
	await t._frames(2)
	_tp().dining._reset()
	await _car("dining")
	var labels: Array = _tp().roots["dining"].find_children("*", "Label", true, false).map(func(l): return l.text)
	_check(labels.any(func(s): return String(s) == String(lines[0])), "...and the Dining car shows how they went")
	# A wager on another tower is called off: the stake comes back.
	var pick := D.state(prof)
	pick["bets"] = []
	var air0: float = prof.crystals_held()
	D.place_bet(prof, plain, {"kind": "floor", "tower": "gryphon", "floor": 2, "odds": 1.6, "by": plain["id"], "by_name": plain["name"]}, 10)
	main.depart("kraken")
	await t._frames(2)
	main.floor_num = 2
	main.pay_climb()
	_check(D.state(prof)["bets"].is_empty() and prof.crystals_held() >= air0 - 0.5, "a wager on a tower you didn't climb is called off, its stake back")
	# Slaying: counted by kind.
	var slay := {"kind": "slay", "tower": "kraken", "monster": "lurker", "count": 2, "odds": 1.5, "running": true}
	var foe := FakeFoe.new()
	foe.kind = "lurker"
	D.state(prof)["bets"] = [slay]
	D.on_kill(main, foe)
	D.on_kill(main, foe)
	_check(int(slay["count_now"]) == 2 and D.bet_won(slay, 1), "a wager on slaying counts each one of its kind")
	D.state(prof)["bets"] = []
	main.await_tower()
	main.open_train()
	await t._frames(2)


# --- trades ----------------------------------------------------------------------------------------

func _trades() -> void:
	var main = _main()
	var prof = main.profile
	var plain: Dictionary = _by_name("Plainone")
	var helped: Dictionary = _by_name("Helpedone")
	var offers: Array = D.trade_offers(prof, plain)
	var fair := true
	for o in offers:
		var thing: Dictionary = o["thing"]
		var base := float(Train.gear_price(thing["rec"])) if String(thing["type"]) == "gear" else float(Train.item_price(String(thing["id"]))[1])
		var want := base * (float(D.RULES["buy_share"]) if String(o["type"]) == "buy" else 1.0)
		if absi(int(o["price"]) - int(round(want))) > 1:
			fair = false
	_check(not offers.is_empty() and fair, "a climber's trades are at the outfitter's prices (%d offers)" % offers.size())
	var k := D.kind_of(plain)
	_check(offers.any(func(o): return String(o["type"]) == "give" and String(o["kind"]) == k), "...and their goods follow their marks (%s)" % k)
	var warm: Array = D.trade_offers(prof, helped)
	var wk := D.kind_of(helped)
	var tinct: Array = warm.filter(func(o): return String(o["thing"].get("id", "")) == load("res://scripts/essence_flow.gd").tincture_id(wk))
	if not tinct.is_empty():
		var full := int(Train.item_price(String(tinct[0]["thing"]["id"]))[1])
		_check(int(tinct[0]["price"]) < full, "a climber you helped takes a little off (%d, not %d)" % [int(tinct[0]["price"]), full])
	# Take one of theirs, and sell one of yours.
	var gi := -1
	var bi := -1
	for i in offers.size():
		if String(offers[i]["type"]) == "give" and gi < 0:
			gi = i
		if String(offers[i]["type"]) == "buy":
			bi = i
	var traded0 := int(Rv.state(prof)[plain["id"]].get("traded", 0))
	if gi >= 0:
		var o: Dictionary = offers[gi]
		var before: float = prof.crystal_total(String(o["kind"]))
		var chest0: int = prof.chest.size()
		var sup0: int = int(prof.supplies.get(String(o["thing"].get("id", "")), 0))
		var res := D.trade(prof, main.player, plain, gi)
		var got: bool = prof.chest.size() == chest0 + 1 if String(o["thing"]["type"]) == "gear" else int(prof.supplies.get(String(o["thing"]["id"]), 0)) == sup0 + 1
		_check(res["ok"] and absf(prof.crystal_total(String(o["kind"])) - (before - float(o["price"]))) < 0.5 and got, "buying from them: their price paid, the thing is yours (%s)" % res["text"])
	if bi >= 0:
		var o2: Dictionary = offers[bi]
		var before2: float = prof.crystal_total(String(o2["kind"]))
		var res2 := D.trade(prof, main.player, plain, bi)
		_check(res2["ok"] and not prof.chest.any(func(g): return Gear.same(g, o2["thing"]["rec"])) and absf(prof.crystal_total(String(o2["kind"])) - (before2 + float(o2["price"]))) < 0.5, "selling to them: your piece goes, their crystals come")
	_check(int(Rv.state(prof)[plain["id"]].get("traded", 0)) > traded0, "...and the trade is remembered")
	# A climber you robbed refuses.
	var cold: Dictionary = _by_name("Robbedone")
	var held: float = prof.crystals_held()
	var chest1: int = prof.chest.size()
	var refused := D.trade(prof, main.player, cold, 0)
	_check(not refused["ok"] and String(refused["text"]) != "" and prof.crystals_held() == held and prof.chest.size() == chest1, "a climber you robbed won't trade (%s)" % refused["text"])


# --- duels in the Arena car ---------------------------------------------------------------------------

func _duels() -> void:
	var main = _main()
	var prof = main.profile
	var menu = _menu()
	var plain: Dictionary = _seated_talker()
	for r in Rv.state(prof).values():
		r["duels_won"] = 0
	Rv.state(prof)[plain["id"]]["duels_won"] = 2
	var dp = _tp().dining
	dp._reset()
	await _car("dining")
	dp._talk_to(String(plain["id"]))
	await t._frames(2)
	dp._go("duel")
	await t._frames(2)
	var stakes: Array = D.duel_stakes(prof, Rv.state(prof)[plain["id"]])
	_check(stakes.size() >= 2 and stakes.any(func(s): return String(s["type"]) == "crystals") and stakes.any(func(s): return String(s["type"]) == "renown"), "a duel's stakes: crystals, a piece of gear, or renown (%s)" % [stakes.map(func(s): return s["type"])])
	dp._pick(0)
	await t._frames(2)
	var go := _button("dine:duel_go")
	_check(go != null, "...choose one and the way to the Arena car opens")
	var stake: Dictionary = stakes[0]
	var kind := String(stake["kind"])
	var have: float = prof.crystal_total(kind)
	var renown0 := Renown.points(prof)
	go.pressed.emit()
	await t._frames(3)
	var arena = main.arena
	_check(arena.on and String(arena.ev.get("type", "")) == "duel" and not menu.is_open(), "the duel takes you into the Arena car")
	_check(arena.car_view != null and arena.car_view is ArenaCar and is_instance_valid(arena.duel_body) and arena.duel_body in main.enemies(), "...a small arena drawn round you, and the climber to fight (%s)" % plain["name"])
	_check(main.hud.status_chips().any(func(c): return String(c.get("id", "")) == "arena" and String(c.get("text", "")).contains(String(plain["name"]))), "...with a line at the top: who, the stake, the time left")
	_check(menu.rail.place_text(main) == String(D.TEXT["arena_car"]), "...and where you are says the Arena car")
	var body = arena.duel_body
	body.set_physics_process(false)
	body.take_hit(999999.0, Vector2.RIGHT, 0.0, true, true)
	await t._frames(2)
	_check(arena.done and arena.result.get("won", false), "badly hurt, they yield: you win")
	await t._wait(float(arena.RESULT_WAIT) + 0.5)
	await t._frames(3)
	_check(not arena.on and menu.page == "train" and menu.train_car == "dining", "afterwards you're back in the Dining car")
	_check(absf(prof.crystal_total(kind) - (have + float(stake["amount"]))) < 0.5, "...the stake is yours (+%d %s)" % [int(stake["amount"]), kind])
	var rec: Dictionary = Rv.state(prof)[plain["id"]]
	_check(int(rec.get("duels_won", 0)) == 3 and Renown.points(prof) > renown0, "...the win is remembered, with renown")
	_check("duelist" in Renown.titles(prof), "...and counts for the Duelist title")
	_check(not dp.lines.is_empty() and _tp().roots["dining"].find_children("*", "Label", true, false).any(func(l): return String(l.text) == String(dp.lines[0])), "...and the car says what the duel did (%s)" % [dp.lines])
	# A loss, for a piece of gear: you yield, never die, and they take it.
	var helped: Dictionary = _by_name("Helpedone")
	if (helped.get("gear", []) as Array).is_empty():
		helped["gear"] = [Gear.code(Gear.make("leather_cap"))]
	prof.chest.append(Gear.make("leather_cap"))
	var gstakes: Array = D.duel_stakes(prof, helped).filter(func(s): return String(s["type"]) == "gear")
	_check(not gstakes.is_empty() and gstakes[0]["ok"], "a piece of gear can be staked: yours against theirs")
	if gstakes.is_empty():
		return
	var mine: Dictionary = gstakes[0]["mine"]
	var count_mine: int = prof.chest.filter(func(g): return Gear.same(g, mine)).size()
	var lost0 := int(helped.get("duels_lost", 0))
	var why: String = arena.start(D.duel_event(prof, helped, gstakes[0]))
	await t._frames(3)
	_check(why == "" and arena.on, "a second duel begins")
	var p = main.player
	var body2 = arena.duel_body
	body2.set_physics_process(false)
	p.iframes = 0.0
	p.hurt_t = 0.0
	p.parry_t = 0.0
	p.barrier_hp = 0.0
	p.receive_attack(99999.0, body2)
	await t._frames(2)
	_check(not p.dead and p.hp >= 1.0 and arena.done and not arena.result.get("won", true), "a blow that would fell you: you yield, never die")
	await t._wait(float(arena.RESULT_WAIT) + 0.5)
	await t._frames(3)
	var rec2: Dictionary = Rv.state(prof)[helped["id"]]
	_check(not arena.on and menu.train_car == "dining" and prof.chest.filter(func(g): return Gear.same(g, mine)).size() == count_mine - 1, "...they take your staked piece, and you're back in the Dining car")
	_check(int(rec2.get("duels_lost", 0)) == lost0 + 1 and (rec2.get("gear", []) as Array).any(func(c): return Gear.same(Gear.rec(c), mine)), "...the loss is remembered, and they carry your piece now")
	# A renown stake lost never costs a rank.
	var r := Renown.state(prof)
	var pts: int = int(r["points"])
	var lines: Array = D.apply_duel(prof, {"won": false}, D.duel_event(prof, plain, {"type": "renown", "amount": 6, "label": "6 renown"}))["lines"]
	_check(Renown.points(prof) >= Renown.needed(Renown.rank_for(pts)) and Renown.points(prof) <= pts and not lines.is_empty(), "a renown stake lost takes renown, never a rank")
	var drawn: Array = D.apply_duel(prof, {"won": false, "draw": true}, D.duel_event(prof, plain, stake))["lines"]
	_check(drawn.size() == 1 and String(drawn[0]) == String(D.TEXT["duel_draw"]), "a duel that runs out of time is a draw: nothing changes hands")


# --- climbers recur ----------------------------------------------------------------------------------

func _recurring() -> void:
	var main = _main()
	var prof = main.profile
	# A climber met in a tower sits in the Dining car on a later visit.
	main.depart("kraken")
	await t._frames(2)
	main.floor_num = 4
	Rv.force_return = 0
	var enc: Dictionary = main.rivals.add(main.player.global_position + Vector2(200, 0), -1, "trade")
	main.rivals.open(enc)
	main.rivals._close()
	var tower_id := String(enc["rival"]["id"])
	_check(Rv.state(prof).has(tower_id), "a climber met in a tower is kept")
	main.pay_climb()
	main.await_tower()
	main.open_train()
	await t._frames(2)
	var ids: Array = D.seated(prof, "kraken").map(func(r): return String(r["id"]))
	_check(tower_id in ids, "...and sits in the Dining car on the next visit (the one met last always does)")
	# A Dining-car acquaintance turns up in a tower, and their record grows there.
	var st := D.state(prof)
	var face_id := ""
	for id in st["seats"]:
		if st["faces"].has(id):
			face_id = String(id)
	if face_id == "":
		st["trips"] = int(st["trips"]) + 1
		D.seated(prof, "kraken")
		for id in st["seats"]:
			if st["faces"].has(id):
				face_id = String(id)
	D.remember(prof, face_id)
	_check(Rv.state(prof).has(face_id) and int(Rv.state(prof)[face_id].get("climb", 0)) == -1, "a new face met in the Dining car joins the climbers you've met")
	main.depart("kraken")
	await t._frames(2)
	main.floor_num = 4
	Rv.force_return = 1
	var got := false
	for i in 80:
		var r: Dictionary = main.rivals._choose_rival()
		if String(r.get("id", "")) == face_id:
			got = true
			var enc2: Dictionary = main.rivals.add(main.player.global_position + Vector2(200, 0), -1, "trade")
			enc2["rival"] = r
			var met0 := int(Rv.state(prof)[face_id].get("met", 0))
			main.rivals.open(enc2)
			main.rivals._close()
			_check(int(Rv.state(prof)[face_id].get("met", 0)) == met0 + 1, "...and meeting them in a tower adds to the same record")
			break
	_check(got, "a climber met in the Dining car can turn up in a tower")
	Rv.force_return = -1
	main.pay_climb()
	main.await_tower()
	main.open_train()
	await t._frames(2)


# --- the rail: no Arena car ------------------------------------------------------------------------

func _rail() -> void:
	var menu = _menu()
	await _car("dining")
	_check(Train.CARS.any(func(c): return c[0] == "dining") and menu.rail.button("dining") != null, "the Dining car is on the rail")
	_check(not Train.CARS.any(func(c): return c[0] == Train.ARENA_CAR) and menu.rail.button(Train.ARENA_CAR) == null and _tp()._index(Train.ARENA_CAR) < 0, "the Arena car is not: only a duel reaches it")
	var at: String = menu.train_car
	_tp().go_to(_tp()._ids().size())
	await t._frames(2)
	_check(menu.train_car != Train.ARENA_CAR and _tp()._ids().find(menu.train_car) >= 0, "...and moving along the train never stops there (%s, from %s)" % [menu.train_car, at])


# --- the Entity explains ----------------------------------------------------------------------------

func _entity() -> void:
	var main = _main()
	var menu = _menu()
	for id in ["dining", "dining_talk", "dining_rumor", "dining_bet", "dining_duel", "arena_car"]:
		var e: Dictionary = Entity.TIPS.get(id, {})
		_check(not e.is_empty() and String(e["tip"]).length() <= 170 and String(e["more"]).length() >= 60, "the Entity's first-time line: %s" % id)
	_check(_tp().CAR_TIPS.get("dining", []).has("dining"), "...the first visit to the Dining car says it")
	for id in ["how_dining", "how_bets", "how_duels"]:
		var n: Dictionary = Talk.DIALOGUE.get(id, {})
		var said := Talk.fill(String(n.get("lines", [""])[0]), Talk.facts(main, n)) if not n.is_empty() else ""
		_check(id in Talk.DIALOGUE["how"]["choices"] and Talk.shows(main, id) and said != "" and not said.contains("{"), "\"%s\" under How do things work here? (%s)" % [n.get("ask", id), said.left(60)])
	# The first rumor, wager and duel: the Entity's line in the talk.
	var Guide = main.GuideScript
	Engine.set_meta("sixfold_tips", true)
	Guide.forget()
	var dp = _tp().dining
	dp._reset()
	await _car("dining")
	var rec: Dictionary = _seated_talker()
	dp._talk_to(String(rec["id"]))
	await t._frames(2)
	dp._go("rumor")
	var first_rumor: String = dp.tip_line
	dp._go("bets")
	var first_bet: String = dp.tip_line
	dp._go("duel")
	var first_duel: String = dp.tip_line
	dp._go("rumor")
	var again: String = dp.tip_line
	Engine.remove_meta("sixfold_tips")
	Guide.forget()
	_check(first_rumor == String(Entity.TIPS["dining_rumor"]["tip"]) and first_bet == String(Entity.TIPS["dining_bet"]["tip"]) and first_duel == String(Entity.TIPS["dining_duel"]["tip"]), "the first rumor, wager and duel: the Entity explains each")
	_check(again == "", "...once")
	# Every button in the car has the Entity's own words.
	var lacking := {}
	var seen := 0
	var views: Array = [["", -1], ["talk", -1], ["rumor", -1], ["bets", 0], ["trade", -1], ["duel", 0]]
	for v in views:
		dp._reset()
		if v[0] != "":
			dp.who = String(rec["id"])
			dp.node = v[0]
			dp.pick = v[1]
		await _car("dining")
		for b in _dining_buttons():
			seen += 1
			if Help.missing(b):
				lacking["%s: %s" % [v[0], Help.words(b)]] = true
	dp._reset()
	_check(seen >= 20 and lacking.is_empty(), "every Dining car button (%d) has the Entity's words; lacking: %s" % [seen, lacking.keys()])
	_check(Help.entry("rail:dining") != "", "...the rail's entry too")


# --- saves and words ---------------------------------------------------------------------------------

func _saves() -> void:
	var path := "user://test_dining_old.cfg"
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "climbs", 4)
	cfg.save(path)
	var prof = P.new()
	prof.save_path = path
	prof.load_save()
	_check(prof.dining is Dictionary and prof.dining.is_empty() and D.state(prof)["bets"].is_empty() and D.seated(prof, "kraken").size() >= int(D.RULES["seats_min"]), "an old save (no Dining car) loads with none, and the car seats new faces")
	prof.saving = true
	D.state(prof)["bets"] = [{"kind": "floor", "tower": "kraken", "floor": 3, "odds": 2.0, "stake": 10}]
	prof.save()
	var again = P.new()
	again.save_path = path
	again.load_save()
	_check(D.state(again)["bets"].size() == 1 and (D.state(again)["seats"] as Array).size() >= int(D.RULES["seats_min"]), "...and the car's state is kept with the climber")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _words() -> void:
	var tables: Array = [D.TEXT, D.LINES, D.RUMORS, D.BETS, Entity.TIPS.get("dining", {}), Entity.TIPS.get("dining_bet", {}), Entity.TIPS.get("dining_duel", {}),
		Entity.TIPS.get("arena_car", {}), Talk.DIALOGUE.get("how_dining", {}), Talk.DIALOGUE.get("how_bets", {}), Talk.DIALOGUE.get("how_duels", {})]
	var bad: Array = []
	for tb in tables:
		var s := str(tb).to_lower()
		for w in BANNED:
			if s.contains(w):
				bad.append(w)
	for k in Help.HELP:
		if String(k).begins_with("dine:"):
			for w in BANNED:
				if String(Help.HELP[k]).to_lower().contains(w):
					bad.append(k)
	_check(bad.is_empty(), "no banned words in the Dining car's words (%s)" % [bad])
	var ids: Array = Registry.SECTIONS.map(func(s): return String(s["id"]))
	_check("dining_words" in ids and "dining_numbers" in ids, "its words and numbers are in the Data editor")
