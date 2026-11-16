extends RefCounted
## Rival climbers (rivals.gd, rival.gd): how often floors hold one (about
## one floor in three, up to two a climb, and sure by floor 3 for a climber
## who never met one), that a second is someone else at another meeting,
## and that they never block the way; the four meetings (a fair trade; a duel won and
## lost without dying; teaming up, which shares essence and finds and lets a
## one-mark climber's spell react with the rival's; helping a wounded
## climber or taking their hoard); the climber's record of them, the Renown
## Board, a met rival coming back stronger; titles and renown; old saves;
## the Entity's first-time line; and no banned words.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const Rv := preload("res://scripts/rivals.gd")
const R := preload("res://scripts/reactions.gd")
const PA := preload("res://scripts/pacts.gd")
const Floors := preload("res://scripts/floors.gd")
const Towers := preload("res://scripts/towers.gd")
const Reach := preload("res://scripts/reach.gd")
const Renown := preload("res://scripts/renown.gd")
const Entity := preload("res://scripts/entity.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const Help := preload("res://scripts/entity_help.gd")
const Stations := preload("res://scripts/stations.gd")
const TestRun := preload("res://scripts/test_run.gd")

const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

var t
var P = load("res://scripts/profile.gd")
var dir := Vector2.RIGHT


func run(smoke) -> void:
	t = smoke
	_placement()
	await _variety()
	await _live_floor()
	await _trade()
	await _duel()
	await _team()
	await _rescue()
	await _remembered()
	await _first_time()
	_saves()
	_words()
	Rv.force = false
	Rv.force_kind = ""
	Rv.force_return = -1


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## A fresh climber with these marks ({part: bond id}) at `step`, alone, in the open.
func _marked(marks: Dictionary, step := 1) -> void:
	await t._fresh_main()
	t.paused = false
	var main = t.main
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.profile.regarded = true
	main.first_climb = false
	var bonds := {}
	for part in marks:
		bonds[part] = {"id": marks[part], "xp": float(P.STEP_XP[step - 1]), "faint": false, "debt": 0.0}
	main.profile.bonds = bonds
	main._give_bonds()
	for e in main.enemies():
		e.queue_free()
	await t._frames(2)
	var p = main.player
	p.iframes = 0.0
	p.hurt_t = 0.0
	p.global_position = main.room.get_center()
	dir = Vector2.RIGHT
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		var open := true
		for k in range(1, 16):
			var at: Vector2 = p.global_position + d * 20.0 * k
			if main.is_solid(at) or not main.room.grow(-20.0).has_point(at):
				open = false
		if open:
			dir = d
			break
	p.aim = dir


func _foe(at: Vector2, hp := 400.0, kind := "slime"):
	var e = t.main.spawn_enemy(kind, at)
	e.set_physics_process(false)
	e.global_position = at
	e.max_hp = hp
	e.hp = hp
	e.aware = true
	e.notice_t = 0.0
	return e


## The card on the open exchange whose pick starts with `prefix` (-1 if none).
func _card(prefix: String) -> int:
	var ch: Array = t.main.camp.get("choices", [])
	for i in ch.size():
		if String(ch[i]).begins_with(prefix):
			return i
	return -1


# --- where they appear ------------------------------------------------------------------

func _placement() -> void:
	print("rivals: how often, and where")
	Rv.climb_ok = true
	Rv.force = false
	Rv.climb_owed = false
	seed(2468)
	var with := 0
	var total := 0
	var bad: Array = []
	var floors := [2, 3, 4, 5, 7, 8, 9, 10, 11]
	for tid in Towers.ORDER:
		for k in 60:
			var n: int = floors[k % floors.size()]
			Rv.climb_met = 0
			var plan := Floors.rooms_floor(n, Towers.TOWERS[tid])
			total += 1
			var rv: Array = plan.get("rivals", [])
			if rv.is_empty():
				continue
			with += 1
			var ri := int(rv[0]["room"])
			var info: Dictionary = plan["room_info"][ri]
			var rect: Rect2 = info["rect"]
			if plan["themes"][ri] != "rival" or info["role"] in ["entrance", "stair", "gallery"]:
				bad.append("%s %d: room %s" % [tid, n, info["role"]])
			if plan["monsters"].any(func(m): return rect.has_point(m[1])):
				bad.append("%s %d: monsters in their room" % [tid, n])
			if plan.get("objective", {}).get("pieces", []).any(func(pc): return int(pc.get("room", -1)) == ri):
				bad.append("%s %d: a piece of the task in their room" % [tid, n])
			if not Reach.plan_check(plan)["ok"]:
				bad.append("%s %d: the floor can't be crossed" % [tid, n])
	var rate := float(with) / float(maxi(total, 1))
	_check(rate > 0.24 and rate < 0.52, "about one floor in three holds another climber (%d of %d plans: %.2f; it was one in five)" % [with, total, rate])
	_check(bad.is_empty(), "...in a calm room of their own (not the start, stair or gallery), with no monsters or task piece there, and every floor can still be crossed (%s)" % [bad])
	# Up to two a climb, never on the bondless first climb or floors 1, 6 and the summit.
	_check(int(Rv.RULES["per_climb"]) == 2 and float(Rv.RULES["chance"]) >= 0.4, "up to two a climb, at a chance of %.2f a floor" % float(Rv.RULES["chance"]))
	Rv.climb_met = 1
	var second := 0
	for k in 60:
		second += Floors.rooms_floor(2 + k % 4, Towers.TOWERS["gryphon"]).get("rivals", []).size()
	Rv.climb_met = 2
	var after := 0
	for k in 60:
		after += Floors.rooms_floor(2 + k % 4, Towers.TOWERS["gryphon"]).get("rivals", []).size()
	_check(second > 5 and after == 0, "after one, a second can come (%d in 60 floors); after two, no more that climb" % second)
	# Whole climbs: most meet two, nearly every one meets at least one.
	var per := {0: 0, 1: 0, 2: 0}
	for c in 36:
		Rv.climb_met = 0
		var ctid: String = Towers.ORDER[c % Towers.ORDER.size()]
		for f in [2, 3, 4, 5, 7, 8, 9, 10, 11]:
			Rv.climb_met += Floors.rooms_floor(f, Towers.TOWERS[ctid]).get("rivals", []).size()
		per[mini(Rv.climb_met, 2)] += 1
	_check(per[0] <= 3 and per[2] >= 18, "a climb meets other climbers as a regular part of it (climbs with 0/1/2: %s)" % [per])
	# Sure by floor 3 for a climber who has never met one.
	Rv.climb_owed = true
	var owed_ok := 0
	for k in 24:
		Rv.climb_met = 0
		owed_ok += mini(1, Floors.rooms_floor(3, Towers.TOWERS[Towers.ORDER[k % Towers.ORDER.size()]]).get("rivals", []).size())
	_check(owed_ok == 24 and Rv.sure(3) and not Rv.sure(2), "a climber who never met one is sure to by floor 3 (%d of 24 floor-3 plans)" % owed_ok)
	Rv.climb_met = 1
	_check(not Rv.sure(4), "...once one is met, the floors roll as usual")
	Rv.climb_met = 0
	Rv.climb_ok = false
	_check(not Rv.sure(3), "...never on the bondless first climb")
	Rv.climb_ok = true
	var fresh = P.new()
	Rv.new_climb(fresh, false)
	_check(Rv.climb_owed and Rv.climb_met == 0, "the first climb after the Regard (no rival met yet) is owed one")
	fresh.rivals = {"aldo_1": {"id": "aldo_1", "name": "Aldo"}}
	Rv.new_climb(fresh, false)
	_check(not Rv.climb_owed, "...and a climber who has met one is not")
	Rv.new_climb(fresh, true)
	_check(not Rv.climb_ok and not Rv.climb_owed, "...nor the bondless first climb")
	Rv.climb_owed = false
	Rv.climb_ok = true
	seed(Time.get_ticks_usec())
	Rv.climb_met = 0
	Rv.climb_ok = false
	var first := 0
	for k in 60:
		first += Floors.rooms_floor(2 + k % 4, Towers.TOWERS["kraken"]).get("rivals", []).size()
	Rv.climb_ok = true
	_check(first == 0, "none on the bondless first climb")
	_check(not Rv.wants_room(1) and not Rv.wants_room(int(Towers.PROVING["floor"])) and not Rv.wants_room(int(Towers.SUMMIT)), "none on floor 1, the Proving or the summit")
	Rv.force = true
	_check(Rv.wants_room(3), "the switch makes the next floor hold one")
	Rv.force = false


## Two in one climb: someone else, at another meeting.
func _variety() -> void:
	print("rivals: a second in a climb is someone else")
	await _marked({"hand": "stormcaller"})
	var main = t.main
	var p = main.player
	main.floor_num = 4
	var diff_name := 0
	var diff_kind := 0
	var kinds := {}
	for k in 24:
		main.profile.climbs += 1  # (a new climb each time)
		Rv.force_return = 1 if k % 2 == 0 else 0
		var a: Dictionary = main.rivals.add(p.global_position + dir * 120.0, -1)
		var b: Dictionary = main.rivals.add(p.global_position + dir * 160.0, -1)
		if String(a["rival"]["name"]) != String(b["rival"]["name"]):
			diff_name += 1
		var forced: bool = b["rival"].get("returning", false) and (int(b["rival"].get("robbed", 0)) > 0 or bool(b["rival"].get("owed", false)))  # (a grudge or a debt picks its own meeting)
		if String(a["kind"]) != String(b["kind"]) or forced:
			diff_kind += 1
		kinds[a["kind"]] = true
		kinds[b["kind"]] = true
		main.rivals._remember(a)
		main.rivals.list.clear()
	Rv.force_return = -1
	_check(diff_name == 24, "the second rival of a climb is never the first one again (%d of 24)" % diff_name)
	_check(diff_kind == 24, "...and meets you another way (%d of 24)" % diff_kind)
	_check(kinds.has("trade") and kinds.has("duel") and kinds.has("team") and kinds.has("rescue"), "all four meetings turn up (%s)" % [kinds.keys()])
	main.rivals.list.clear()


## A floor as the game builds it, a rival forced onto it: they stand there,
## and the stair and every room can still be reached.
func _live_floor() -> void:
	print("rivals: on a floor as the game builds it")
	await _marked({"hand": "stormcaller"})
	var main = t.main
	var Live = load("res://tests/parts/reachability.gd")
	var ok := true
	var placed := 0
	for tid in ["gryphon", "kraken", "chimera"]:
		main.tower = tid
		Rv.force = true
		main._start_floor(4)
		placed += main.rivals.list.size()
		var r: Dictionary = Live.live_report(main)
		ok = ok and r["ok"]
		for enc in main.rivals.list:
			var c := Reach.live_check(main, main.player_start)
			if c["checked"]:
				var at: Vector2 = enc["pos"]
				ok = ok and Reach.rect_reached(c["reach"], c["size"], Rect2(at - Vector2(30, 30), Vector2(60, 60)))
	Rv.force = false
	_check(placed >= 3 and not Rv.force, "a forced rival stands on each built floor (%d), and the switch is spent" % placed)
	_check(ok, "...where you can walk up to them, and the stair and every room can still be reached")
	for e in main.enemies():
		e.queue_free()


# --- a trade -------------------------------------------------------------------------------

func _trade() -> void:
	print("rivals: a trade")
	await _marked({"hand": "stormcaller"})
	var main = t.main
	var p = main.player
	main.floor_num = 4
	p.add_item("draught")
	p.add_item("tonic")
	p.add_item("smoke")
	p.pack.append(main.Gear.make("leather"))
	main.profile.add_crystal("air", 60.0)
	main.run_essence = {"air": 40.0}
	var enc: Dictionary = main.rivals.add(p.global_position + dir * 30.0, -1, "trade")
	p.global_position = enc["pos"] - dir * 10.0
	await t._ticks(3)
	_check(main.camp_choosing and main.camp.get("stage", "") == "rival", "walking up to a climber opens the exchange")
	var offers: Array = enc["offers"]
	_check(offers.size() >= 2 and offers.size() <= 3, "they offer two or three swaps (%d)" % offers.size())
	var fair := true
	for o in offers:
		var give: float = Rv.worth(o["give"])
		var want: float = Rv.worth(o["want"])
		if String(o["want"]["type"]) in ["item", "gear"]:
			fair = fair and want >= give * float(Rv.RULES["fair_low"]) - 0.01 and want <= give * float(Rv.RULES["fair_high"]) + 0.01
		else:
			fair = fair and absf(want - maxf(1.0, roundf(give))) < 0.01
	_check(fair, "...each for something you carry of about the same worth (the store's prices), else that worth in crystals or essence")
	var cards: Array = main.camp["choices"]
	_check(cards[-1] == "rv:walk" and String(main.camp_card(cards.size() - 1)["name"]) == String(Rv.TEXT["walk_name"]), "Walk on is always there")
	var i := -1
	for k in offers.size():
		if main.rivals.can_pay(offers[k]["want"]):
			i = k
			break
	_check(i >= 0, "...and at least one swap can be paid")
	if i >= 0:
		var want: Dictionary = offers[i]["want"]
		var give: Dictionary = offers[i]["give"]
		var before_have := _has(want)
		var before_get := _has(give)
		var c := _card("rv:trade:%d" % i)
		var card: Dictionary = main.camp_card(c)
		_check(String(card["name"]).contains(main.rivals.thing_name(give)) and String(card["desc"]).contains(main.rivals.thing_name(want)), "a swap's card says what they give and what they want")
		main.choose_camp(c)
		await t._frames(2)
		_check(not main.camp_choosing and _has(want) < before_have and _has(give) > before_get, "taking it swaps the two (gave %s, got %s)" % [main.rivals.thing_name(want), main.rivals.thing_name(give)])
		_check(int(Rv.state(main.profile)[enc["rival"]["id"]]["traded"]) == 1, "...and the trade is remembered")
		_check(enc["state"] in ["rearm", "leave"], "...after which you can step away and come back for another")
	main.profile.crystals.clear()


## How much of a thing you hold (to see it change).
func _has(thing: Dictionary) -> float:
	var main = t.main
	var p = main.player
	match String(thing["type"]):
		"item":  # (on the belt, or at your feet when the belt is full)
			return float(p.item_count(String(thing["id"])) + main.item_drops.filter(func(d): return String(d["id"]) == String(thing["id"])).size())
		"gear":
			var n := 0.0
			for r in p.pack:
				if main.Gear.same(r, thing["rec"]) or main.Gear.base_id(r) == main.Gear.base_id(thing["rec"]):
					n += 1.0
			for s in p.gear:
				if main.Gear.is_gear(p.gear[s]) and main.Gear.base_id(p.gear[s]) == main.Gear.base_id(thing["rec"]):
					n += 1.0
			return n
		"crystal":
			return main.profile.crystal_total(String(thing["kind"]))
		"essence":
			return main.rivals.purse()
	return 0.0


# --- a duel ----------------------------------------------------------------------------------

func _duel() -> void:
	print("rivals: a duel won and lost, never a death")
	await _marked({"hand": "stormcaller"})
	var main = t.main
	var p = main.player
	main.floor_num = 4
	var slain0: int = main.profile.count("slain")
	var renown0 := Renown.points(main.profile)
	var cr0: float = main.profile.crystals_held()
	var enc: Dictionary = main.rivals.add(p.global_position + dir * 120.0, -1, "duel")
	main.rivals.open(enc)
	var c := _card("rv:duel")
	_check(c >= 0, "a duel's exchange offers the duel")
	main.ward = true
	main.choose_camp(c)
	await t._frames(2)
	var body = main.rivals.duel
	_check(main.rivals.duel_on() and body in main.enemies() and body.rival_name == enc["rival"]["name"], "accepting it: they fight you (%s)" % enc["rival"]["name"])
	_check(body.spells.size() >= 1 and body.marks.size() == enc["rival"]["bonds"].size(), "...with a spell from their marks, their marks on their body")
	_check(main.hud.status_chips().any(func(ch): return String(ch.get("id", "")) == "rival"), "...and a chip with their health at the top")
	body.set_physics_process(false)
	body.take_hit(999999.0, dir, 0.0, true, true)
	await t._frames(2)
	_check(not is_instance_valid(body) or body.dead, "badly hurt, they yield")
	_check(main.profile.count("slain") == slain0, "...never killed (nothing slain)")
	_check(not main.ward, "winning lifts the stair's ward")
	_check(main.profile.crystals_held() > cr0 and Renown.points(main.profile) > renown0, "...and pays crystals and renown")
	_check("duel_won" in main.rivals.results and int(Rv.state(main.profile)[enc["rival"]["id"]]["duels_won"]) == 1, "...and the win is remembered")
	_check(not main.profile.bestiary.has("rival"), "a rival isn't written in the Bestiary")
	# A loss: knocked down, never killed, and a toll.
	main.run_essence = {"air": 40.0}
	var enc2: Dictionary = main.rivals.add(p.global_position + dir * 120.0, -1, "duel")
	main.rivals.start_duel(enc2)
	var body2 = main.rivals.duel
	body2.set_physics_process(false)
	p.iframes = 0.0
	p.hurt_t = 0.0
	p.parry_t = 0.0
	p.barrier_hp = 0.0
	p.receive_attack(99999.0, body2)
	await t._frames(2)
	_check(not p.dead and p.hp >= 1.0 and p.hp <= p.max_health() * float(Rv.RULES["duel_left"]) + 1.0, "a blow that would fell you in a duel knocks you down instead (health %d)" % int(p.hp))
	_check(main.rivals.purse() < 40.0 - 1.0, "...and they take a toll of your unbanked essence (%d left of 40)" % int(main.rivals.purse()))
	_check("duel_lost" in main.rivals.results and int(Rv.state(main.profile)[enc2["rival"]["id"]]["duels_lost"]) == 1 and not main.rivals.duel_on(), "...the duel is over, and the loss remembered")
	main.run_essence = {}


# --- teaming up ---------------------------------------------------------------------------------

func _team() -> void:
	print("rivals: teaming up")
	await _marked({"hand": "stormcaller"})
	var main = t.main
	var p = main.player
	main.floor_num = 4
	main.run_essence = {}
	main.gather_essence("air", 10.0, p.global_position)
	var alone := float(main.run_essence.get("air", 0.0))
	var enc: Dictionary = main.rivals.add(p.global_position - dir * 60.0, -1, "team")
	enc["rival"]["bonds"] = [["tidecaller", "brow", 2]]
	main.rivals.open(enc)
	var c := _card("rv:team")
	_check(c >= 0, "a climber who wants company offers to team up")
	main.choose_camp(c)
	await t._frames(2)
	var ally = main.rivals.team
	_check(main.rivals.team_on() and ally in main.allies() and not (ally in main.enemies()), "teamed up, they fight beside you (an ally, not a foe)")
	ally.set_physics_process(false)
	main.run_essence = {}
	main.gather_essence("air", 10.0, p.global_position)
	var shared := float(main.run_essence.get("air", 0.0))
	_check(is_equal_approx(alone, 10.0) and is_equal_approx(shared, 10.0 * float(Rv.RULES["team_share"])), "while they're with you, you keep half the essence you gather (%s of 10)" % shared)
	# Finds drop half as often.
	main.gear_drop_chance = 0.0
	main.item_drop_chance = 1.0
	var dummy = _foe(p.global_position + dir * 200.0, 50.0)
	var with_team := 0
	for k in 160:
		var n0: int = main.item_drops.size()
		main.on_enemy_killed(dummy)
		with_team += 1 if main.item_drops.size() > n0 else 0
	_check(with_team > 50 and with_team < 110, "...and finds drop about half as often (%d of 160 with a sure drop)" % with_team)
	main.item_drops.clear()
	# A one-mark climber's spell reacts with theirs: their Tidecaller soaks, your lightning conducts.
	var foe = _foe(p.global_position + dir * 120.0)
	ally.global_position = foe.global_position - dir * 50.0
	ally.lunge_dir = dir
	ally.spell_spot = foe.global_position
	ally.spell_i = 0
	ally._ally_release()
	_check(R.has(foe, "soaked") and R.giver(foe, "soaked") == ally.rival_name, "their spell leaves their mark's state (soaked) on the foe it hits")
	var shared0 := int(R.SHARED_FIRED.get("conduct", 0))
	var fired0 := int(R.FIRED.get("conduct", 0))
	p.global_position = foe.global_position - dir * 120.0
	var b = p.bonds["hand"]
	b.select(b.spells().map(func(sp): return sp["id"]).find("chain_lightning"))
	b.essence = b.capacity()
	b.burned = false
	p.attack_cd = 0.0
	p.cast_t = 0.0
	p.aim = dir
	p._try_cast("hand")
	await t._until(func(): return int(R.FIRED.get("conduct", 0)) > fired0, 2.5)
	_check(int(R.FIRED.get("conduct", 0)) > fired0, "your Stormcaller's lightning on their soaked foe sets off Conduct, though you carry one mark")
	_check(int(R.SHARED_FIRED.get("conduct", 0)) > shared0 and ("shared:conduct" in main.rivals.results), "...told as a reaction shared with them (their name under its word)")
	_check(main.notices.log.any(func(l): return String(l.get("text", "")).contains(ally.rival_name) and String(l.get("text", "")).contains(R.REACTIONS["conduct"]["name"])), "...and in the feed and the Entity's log")
	_check(int(Rv.state(main.profile)[enc["rival"]["id"]]["shared"]) >= 1, "...and remembered with them")
	# Their mark is the pact's other half while they're with you.
	_check(PA.has(p, "tempest") and not PA.own(p, "tempest") and ally.bond_ids().has("tidecaller"), "a pact one of whose marks is theirs holds while they're beside you (Tempest)")
	_check(main.hud.status_chips().any(func(ch): return String(ch.get("id", "")) == "rival"), "...with their health on a chip at the top")
	# Monsters strike them; badly hurt, they fall back (never killed).
	ally.receive_attack(ally.max_hp * 10.0, foe)
	await t._frames(2)
	_check(not main.rivals.team_on() and "team_spent" in main.rivals.results, "badly hurt, they fall back and the team is over")
	_check(not PA.has(p, "tempest") and is_equal_approx(main.rivals.share(), 1.0) and is_equal_approx(main.rivals.drop_mult(), 1.0), "...and the pact, the shared essence and the fewer finds end with it")
	# Reaching a stair together: renown.
	var enc2: Dictionary = main.rivals.add(p.global_position - dir * 60.0, -1, "team")
	main.rivals.start_team(enc2)
	var renown0 := Renown.points(main.profile)
	main._start_floor(5)
	await t._frames(2)
	_check(not main.rivals.team_on() and Renown.points(main.profile) > renown0, "they head on alone at the stair, and climbing to it together earns renown")
	var enc3: Dictionary = main.rivals.add(p.global_position - dir * 60.0, -1, "team")
	main.rivals.start_team(enc3)
	var renown1 := Renown.points(main.profile)
	main._start_floor(1)
	await t._frames(2)
	_check(not main.rivals.team_on() and Renown.points(main.profile) == renown1 and not ("team_stair" in main.rivals.results), "...but a climb begun again (a fall) ends the team with nothing")
	_check(not main.profile.bestiary.has("rival"), "...and they never join the Bestiary")
	main.gear_drop_chance = main.Gear.DROP_CHANCE
	main.item_drop_chance = main.Items.DROP_CHANCE


# --- the wounded climber and the hoard ------------------------------------------------------------

func _rescue() -> void:
	print("rivals: help them, or take the hoard")
	await _marked({"hand": "stormcaller"})
	var main = t.main
	var p = main.player
	main.floor_num = 5
	while p.item_count("draught") < 1:
		p.add_item("draught")
	var draughts: int = p.item_count("draught")
	var renown0 := Renown.points(main.profile)
	var enc: Dictionary = main.rivals.add(p.global_position + dir * 120.0, -1, "rescue")
	main.rivals.open(enc)
	_check(_card("rv:help") >= 0 and _card("rv:greed") >= 0 and _card("rv:walk") >= 0, "a wounded climber: help them, take the hoard, or walk on")
	main.choose_camp(_card("rv:help"))
	await t._frames(2)
	var rec: Dictionary = Rv.state(main.profile)[enc["rival"]["id"]]
	_check(p.item_count("draught") == draughts - 1, "helping them costs a Healing Draught")
	_check(Renown.points(main.profile) > renown0 and int(rec["rescued"]) == 1 and bool(rec["owed"]), "...earns renown, and they owe you")
	# Met again (a later climb): their gift.
	main.profile.climbs += 1
	Rv.force_return = 1
	var again: Dictionary = main.rivals.add(p.global_position + dir * 160.0, -1)
	Rv.force_return = -1
	_check(again["kind"] == "gift" and again["rival"]["id"] == enc["rival"]["id"], "met again, the one you helped brings a gift")
	main.rivals.open(again)
	var cr0: float = main.profile.crystals_held()
	main.choose_camp(_card("rv:gift"))
	await t._frames(2)
	_check(main.profile.crystals_held() > cr0 and not bool(Rv.state(main.profile)[enc["rival"]["id"]]["owed"]), "...crystals and an item, and the debt is paid")
	_check(again["kind"] == "team", "...then they offer to climb with you")
	# Without a draught: some of your health.
	while p.item_count("draught") > 0:
		Rv.take_item(p, "draught")
	p.hp = p.max_health()
	var enc2: Dictionary = main.rivals.add(p.global_position + dir * 120.0, -1, "rescue")
	main.rivals.open(enc2)
	main.choose_camp(_card("rv:help"))
	await t._frames(2)
	_check(p.hp < p.max_health() - 1.0 and p.hp >= 1.0, "with no draught, binding their wounds costs some of your health (%d of %d)" % [int(p.hp), int(p.max_health())])
	# Greed: richer, but renown lost (never a rank) and the Makers notice.
	var r := Renown.state(main.profile)
	r["points"] = Renown.needed(1) + 2
	var rank0 := Renown.rank(main.profile)
	main.run_essence = {}
	var towers0: float = main.makers.interest("towers")
	var gear0: int = main.gear_drops.size()
	var enc3: Dictionary = main.rivals.add(p.global_position + dir * 120.0, -1, "rescue")
	main.rivals.open(enc3)
	main.choose_camp(_card("rv:greed"))
	await t._frames(2)
	_check(main.rivals.purse() >= float(Rv.RULES["greed_essence"]) * 0.99 and main.gear_drops.size() > gear0, "taking the hoard: essence and a finer piece of gear")
	_check(Renown.points(main.profile) < Renown.needed(1) + 2 and Renown.rank(main.profile) == rank0, "...costs renown, never a rank (%d)" % Renown.points(main.profile))
	_check(main.makers.interest("towers") > towers0, "...and the Makers take note")
	_check(int(Rv.state(main.profile)[enc3["rival"]["id"]]["robbed"]) == 1, "...and they remember it")
	main.profile.climbs += 1
	Rv.force_return = 1
	var grudge: Dictionary = {}
	for k in 12:
		grudge = main.rivals.add(p.global_position + dir * 160.0, -1)
		if grudge["rival"]["id"] == enc3["rival"]["id"]:
			break
	Rv.force_return = -1
	_check(grudge["rival"]["id"] == enc3["rival"]["id"] and grudge["kind"] == "duel", "met again, the one you robbed wants a duel")
	main.run_essence = {}


# --- remembered -----------------------------------------------------------------------------------

func _remembered() -> void:
	print("rivals: remembered, on the Renown Board, and back again")
	await _marked({"hand": "stormcaller"})
	var main = t.main
	var p = main.player
	main.floor_num = 3
	var enc: Dictionary = main.rivals.add(p.global_position + dir * 120.0, -1, "trade")
	main.rivals.open(enc)
	main.choose_camp(_card("rv:walk"))
	await t._frames(2)
	var id := String(enc["rival"]["id"])
	var steps0: Array = enc["rival"]["bonds"].map(func(b): return int(b[2]))
	_check(Rv.state(main.profile).has(id) and int(Rv.state(main.profile)[id]["met"]) == 1 and String(Rv.state(main.profile)[id]["tower"]) == String(main.tower), "a climber you meet is kept with you: their name, marks and where you met")
	# Saved and loaded.
	var path := TestRun.path("user://test_rivals_slot.cfg")
	var saving: bool = main.profile.saving
	var was: String = main.profile.save_path
	main.profile.save_path = path
	main.profile.saving = true
	main.profile.save()
	main.profile.saving = saving
	main.profile.save_path = was
	var again = P.new()
	again.save_path = path
	again.load_save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_check(again.rivals.has(id) and String(again.rivals[id]["name"]) == String(enc["rival"]["name"]) and again.rivals[id]["bonds"].size() == enc["rival"]["bonds"].size(), "...saved with the climber, and loaded again")
	# Back on a later climb, stronger.
	main.floor_num = 7
	main.profile.climbs += 1
	Rv.force_return = 1
	var back: Dictionary = main.rivals.add(p.global_position + dir * 160.0, -1, "trade")
	Rv.force_return = -1
	var steps1: Array = back["rival"]["bonds"].map(func(b): return int(b[2]))
	var stronger := true
	for k in steps0.size():
		stronger = stronger and int(steps1[k]) >= mini(5, int(steps0[k]) + 1)
	_check(back["rival"]["id"] == id and back["rival"].get("returning", false) and stronger, "a met rival can come back on a later climb, every mark a step stronger (%s -> %s)" % [steps0, steps1])
	main.rivals.open(back)
	main.choose_camp(_card("rv:walk"))
	await t._frames(2)
	_check(int(Rv.state(main.profile)[id]["met"]) == 2, "...and you've met them twice")
	# On the Renown Board: their marks and your history.
	var rec: Dictionary = Rv.state(main.profile)[id]
	rec["duels_won"] = 2
	rec["teamed"] = 1
	var menu = main.menu
	main.open_train()
	await t._frames(2)
	menu.go_station(String(Stations.STATIONS[0]["id"]), "board")
	await t._frames(3)
	var tiles: Array = t._all_buttons(menu.box).filter(func(b): return b.has_meta("pick") and String(b.get_meta("pick")) == "rival:" + id)
	_check(tiles.size() == 1 and String(tiles[0].head) == String(rec["name"]) and String(tiles[0].line) == Rv.marks_text(rec), "the Renown Board lists the climbers you've met, with their marks")
	if tiles.size() == 1:
		tiles[0].pressed.emit()
		await t._frames(2)
	var words: Array = menu.box.find_children("*", "Label", true, false).map(func(l): return String(l.text))
	_check(words.any(func(w): return w.contains(Rv.history_text(rec))), "...and its card your history with them (%s)" % Rv.history_text(rec))
	var f: Dictionary = Help.facts(menu, tiles[0], "pick:rival") if tiles.size() == 1 else {}
	_check(Help.HELP.has("pick:rival") and String(f.get("name", "")) == String(rec["name"]), "the Entity explains a climber's tile on the board")
	menu.close()
	await t._frames(2)
	# Titles and renown.
	rec["duels_won"] = 3
	rec["rescued"] = 1
	Renown.check_titles(main.profile)
	var got: Array = Renown.titles(main.profile)
	_check(got.has("duelist") and got.has("helping_hand") and got.has("shieldmate"), "deeds with other climbers earn titles (%s)" % [got])


# --- the Entity ------------------------------------------------------------------------------------

func _first_time() -> void:
	print("rivals: the Entity explains")
	await _marked({"hand": "stormcaller"})
	var main = t.main
	var p = main.player
	var Guide = main.GuideScript
	Engine.set_meta("sixfold_tips", true)
	Guide.forget()
	Guide.queue.clear()
	var enc: Dictionary = main.rivals.add(p.global_position + dir * 120.0, -1, "duel")
	main.rivals.open(enc)
	var first: int = Guide.queue.filter(func(q): return String(q.get("id", "")) == "rivals").size()
	main.choose_camp(_card("rv:walk"))
	await t._frames(2)
	Guide.state["told"]["rivals"] = true
	Guide.queue = Guide.queue.filter(func(q): return String(q.get("id", "")) != "rivals")
	main.rivals.open(enc)
	var second: int = Guide.queue.filter(func(q): return String(q.get("id", "")) == "rivals").size()
	main.choose_camp(_card("rv:walk"))
	await t._frames(2)
	_check(first == 1 and second == 0, "the first climber met: the Entity explains, once (%d, then %d)" % [first, second])
	_check(Guide.queue.any(func(q): return String(q.get("id", "")) == "rival_duel"), "...and each meeting the first time it comes (a duel)")
	Engine.remove_meta("sixfold_tips")
	Guide.forget()
	Guide.queue.clear()
	main.entity.current = {}
	for id in ["rivals", "rival_trade", "rival_duel", "rival_team", "rival_rescue", "rival_gift", "rival_reaction"]:
		var e: Dictionary = Entity.TIPS.get(id, {})
		_check(not e.is_empty() and String(e["tip"]).length() <= 170 and String(e["more"]).length() >= 60, "the Entity's tip: %s" % id)
	_check(Entity.ROOM_TIPS.get("rival", "") == "rivals", "...and walking into their room says it too")
	_check("how_rivals" in Talk.DIALOGUE["how"]["choices"] and Talk.shows(main, "how_rivals") and Talk.shows(main, "how_rivals_more"), "\"Who are the other climbers?\" under \"How do things work here?\"")
	var said := Talk.fill(String(Talk.DIALOGUE["how_rivals"]["lines"][0]), Talk.facts(main, Talk.DIALOGUE["how_rivals"]))
	_check(said.contains("%d%%" % int(round(float(Rv.RULES["chance"]) * 100.0))) and said.contains("twice") and not said.contains("{"), "...answered from the game's own numbers (%s)" % said)


func _saves() -> void:
	print("rivals: old saves")
	var path := TestRun.path("user://test_rivals_old.cfg")
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "climbs", 4)
	cfg.set_value("profile", "regarded", true)
	cfg.save(path)
	var prof = P.new()
	prof.save_path = path
	prof.load_save()
	_check(prof.rivals is Dictionary and prof.rivals.is_empty() and Rv.met_list(prof).is_empty() and Rv.count(prof, "duels_won") == 0, "a save from before rivals loads with none met")
	cfg.set_value("rivals", "met", {"old_1": {"name": "Old", "bonds": [["warden", "heart", 2]]}})
	cfg.save(path)
	prof.load_save()
	var rec: Dictionary = prof.rivals.get("old_1", {})
	_check(Rv.history_text(rec) != "" and Rv.marks_text(rec).contains("Warden") and Rv.look_of(rec).has("cloak"), "...and a record missing its counters still reads")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _words() -> void:
	print("rivals: no banned words")
	var texts: Array = []
	for d in [Rv.TEXT, Rv.LINES, load("res://scripts/rival.gd").RIVAL_TEXT, R.SHARED]:
		texts.append(JSON.stringify(d))
	texts.append(" ".join(Rv.NAMES))
	for id in Entity.TIPS:
		if String(id).begins_with("rival"):
			texts.append(String(Entity.TIPS[id]["tip"]) + " " + String(Entity.TIPS[id]["more"]))
	for id in ["how_rivals", "how_rivals_more"]:
		texts.append(JSON.stringify(Talk.DIALOGUE[id]))
	for id in ["duelist", "shieldmate", "helping_hand"]:
		texts.append(JSON.stringify(Renown.TITLES[id]))
	var readme := FileAccess.get_file_as_string("res://README.md")
	var at := readme.find("## Rival climbers")
	_check(at >= 0, "the README has a section on rival climbers")
	if at >= 0:
		var end := readme.find("\n## ", at + 5)
		texts.append(readme.substr(at, (end - at) if end > at else -1))
	var bad: Array = []
	for s in texts:
		for w in BANNED:
			if String(s).to_lower().contains(w):
				bad.append(w)
	_check(bad.is_empty(), "no banned words in their words, the Entity's, the titles or the README (%s)" % [bad])
