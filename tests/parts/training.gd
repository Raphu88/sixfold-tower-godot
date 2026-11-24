extends RefCounted
## Training and tournaments (training.gd, tournaments.gd, stations.gd,
## arena.gd, station_page.gd, engine_page.gd): the required start (a new
## climber arrives at their home station, the towers closed until the Noble's
## Grace: the engine's lever locked, depart refused); basic training as one
## session (every way to move, attack and parry; no skipping before the
## Grace for a first-timer; its steps in detail: tutorial.gd); the first tournament of three rounds (two of the home
## station's starter monsters, then a human champion with no marks), the
## Grace win or lose and every reward row (0 to 3 rounds, flawless); training's
## essence (a quarter of the usual, into the body only, what each part did kept
## toward the first mark; half, flowing naturally, for later training and
## tournaments); advanced training in tiers by title with fees in the essence
## that fits, mark training after the first mark (dummies, creatures, a
## sparring rival); the travelling Tournament Manager (rotation, the brackets
## only where they are, each location's layout, hazards, creatures and rivals,
## the shared minor reward and the location's own prize); the Entity's words
## for all of it (tips, "How does it work?", button help, hints); the pages
## at a phone's size. Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const Training := preload("res://scripts/training.gd")
const Tournaments := preload("res://scripts/tournaments.gd")
const Stations := preload("res://scripts/stations.gd")
const Travel := preload("res://scripts/travel.gd")
const Renown := preload("res://scripts/renown.gd")
const Gear := preload("res://scripts/gear.gd")
const Bonds := preload("res://scripts/bonds.gd")
const Flow := preload("res://scripts/essence_flow.gd")
const Entity := preload("res://scripts/entity.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const Help := preload("res://scripts/entity_help.gd")
const Registry := preload("res://scripts/data_registry.gd")
const ProfileScript := preload("res://scripts/profile.gd")
const Towers := preload("res://scripts/towers.gd")
const Tutorial := preload("res://scripts/tutorial.gd")

const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

var t


func run(smoke) -> void:
	t = smoke
	print("training: the Grace, basic training, the first tournament, advanced and mark training, the Tournament Manager")
	await t._fresh_main()
	var main = t.main
	main.touch._set_active(false)
	main.pad._set_active(false)
	for e in main.enemies():
		e.queue_free()
	await _gate(main)
	await _lessons(main)
	await _first(main)
	_rewards()
	_essence(main)
	await _advanced(main)
	await _manager(main)
	_entity(main)
	await _phone(main)
	main.menu.station_page.station = ""
	main.menu.close()
	t.paused = false
	main.on_train = false
	await t._frames(2)


func _station_buttons(menu, meta: String, val) -> Array:
	return t._all_buttons(menu.box).filter(func(b): return b.has_meta(meta) and b.get_meta(meta) == val)


func _wait_done(main, seconds := 8.0) -> void:
	await t._until(func(): return not main.arena.on, seconds)
	await t._frames(3)


func _fresh_profile():
	var p = ProfileScript.new()
	p.saving = false
	return p


# --- the required start ------------------------------------------------------------------------

## A new climber waits at their home station; the towers are closed until the Grace.
func _gate(main) -> void:
	var prof = main.profile
	var menu = main.menu
	prof.home = "kraken"
	prof.station = ""
	t._check(not Training.closed(prof) and not Training.lives_on_train(prof), "a climber not made with the new start isn't held back (old saves and tests climb as before)")
	Training.require(prof)
	main.await_tower()
	t._check(Training.closed(prof) and main.on_train and main.choosing_tower, "a new climber waits on the train at their station, the towers closed (training.gd)")
	main.open_train()
	menu.go_station(Travel.home(prof))
	await t._frames(3)
	t._check(menu.page == "station" and menu.station_page.station == "kraken" and menu.station_page.stop == "gym", "...at their home station, at the gym")
	var lessons: Array = _station_buttons(menu, "pick", "basics:basics")
	t._check(lessons.size() == 1 and _station_buttons(menu, "pick", "advanced:belt").is_empty(), "the gym shows basic training; the rest opens with the Grace")
	if not Tutorial.experienced():
		t._check(_station_buttons(menu, "station_do", "skip").is_empty() and t._all_labels(menu.box).any(func(l): return l.text == Training.TEXT["no_skip"]), "...and it can't be skipped before the Grace")
		var words: Array = Tutorial.skip(prof)
		t._check(not Training.basic_done(prof) and words == [Training.TEXT["no_skip"]], "...not even by asking (tutorial.gd skip)")
	menu.leave_station()
	await t._frames(2)
	menu.train_car = "engine"
	menu.train_tower = "kraken"
	menu.open("train")
	await t._frames(3)
	var root: Node = menu.train_page.roots.get("engine", menu)
	var lock: Array = root.find_children("*", "Control", true, false).filter(func(c): return c.has_meta("grace_lock"))
	var lever: Array = root.find_children("*", "Control", true, false).filter(func(c): return c.has_meta("depart"))
	t._check(lock.size() == 1 and lever.is_empty(), "the engine's lever is locked until the Grace (%d locks, %d levers)" % [lock.size(), lever.size()])
	t._check(not Help.missing(lock[0]) if not lock.is_empty() else false, "...and the lock explains itself")
	main.depart("kraken")
	await t._frames(2)
	t._check(main.on_train and Training.closed(prof), "depart is refused without the Grace (main.gd)")
	t._check(Stations.why_not(prof, "first", "first") == Training.TEXT["first_locked"], "the first tournament waits for basic training")
	t._check(Stations.why_not(prof, "tourney", "novice") == Tournaments.TEXT["why_first"], "...and the Manager's brackets for the first tournament")


# --- basic training ----------------------------------------------------------------------------

## Basic training, one session (each step is played in tutorial.gd's test):
## run here step after step to the end, it gives a quarter of the usual
## essence into the body and notes the body parts.
func _lessons(main) -> void:
	var prof = main.profile
	var arena = main.arena
	var station := "kraken"
	t._check(Stations.LESSON_ORDER.size() == 6, "basic training's old six parts are kept as a record (%d)" % Stations.LESSON_ORDER.size())
	var dens0 := _density(prof)
	var why: String = arena.start(Stations.event("basics", "basics", station))
	await t._frames(3)
	t._check(why == "" and arena.on and arena.tut != null, "basic training begins: one session in the arena")
	main.player.iframes = 999.0
	main.add_soak("legs", 3.0)  # (what the body did in here goes with the result)
	for k in Tutorial.count():
		if arena.tut != null and arena.on and not arena.done:
			arena.tut._step_done(main.player)
			await t.physics_frame
	await _wait_done(main)
	main.player.iframes = 0.0
	t._check(Stations.LESSON_ORDER.all(func(id): return Stations.lesson_state(prof, id) == 1), "done: every part marked done, and remembered")
	t._check(Training.basic_done(prof) and Stations.why_not(prof, "first", "first", station) == "", "basic training done: the first tournament opens")
	var gained := _density(prof) - dens0
	var want := Tutorial.STEP_ESSENCE * float(Tutorial.count()) * float(Training.RATES["basics"]["rate"])
	t._check(absf(gained - want) < 0.5 and prof.bonds.is_empty(), "its steps gave a quarter of the usual essence, into the body (%.1f of %.1f)" % [gained, want])
	t._check(float(Training.state(prof)["soak"].get("legs", 0.0)) > 0.0 and float(prof.soak.get("legs", 0.0)) > 0.0, "...and what each body part did is kept toward the first mark")
	t._check(Training.closed(prof), "the towers stay closed until the first tournament")


func _density(prof) -> float:
	var n := 0.0
	for k in prof.density:
		n += float(prof.density[k])
	return n


# --- the first tournament ----------------------------------------------------------------------

## Three rounds: the home station's starter monsters twice, then a human
## champion with no marks; the Grace and the rewards for a flawless win.
func _first(main) -> void:
	var prof = main.profile
	var menu = main.menu
	var arena = main.arena
	var station := "kraken"
	menu.go_station(station, "arena")
	await t._frames(3)
	t._check(_station_buttons(menu, "pick", "first:first").size() == 1 and _station_buttons(menu, "station_do", "first").size() == 1, "the tournament grounds show the first tournament, with Enter")
	var chest0: int = prof.chest.size()
	var why: String = arena.start(Stations.event("first", "first", station))
	t._check(why == "" and arena.on and arena.ev["rounds"].size() == 3, "the first tournament begins: three rounds")
	var starter: Array = Tournaments.location(station)["starter"]
	var monsters := 0
	var champion := false
	var p = main.player
	for i in 3:
		p.iframes = 999.0
		await t._until(func(): return (arena.round_i == i and (arena.opp != null or not arena.round_mobs.is_empty())) or arena.done, 6.0)
		if not arena.round_mobs.is_empty():
			var ks: Array = arena.round_mobs.filter(func(e): return is_instance_valid(e)).map(func(e): return String(e.kind))
			if ks == starter[i]:
				monsters += 1
			for e in arena.round_mobs.duplicate():
				if is_instance_valid(e):
					p.weapon = "dagger"
					main.on_hit.emit(e, 1.0, "blow")  # (a blow with a dagger: the piece follows the weapon used most)
					e.submerged = false  # (a lurker under the water can't be struck)
					e.take_hit(999999.0, Vector2.ZERO)
			await t._frames(3)
			continue
		if arena.opp != null:
			var o = arena.opp
			champion = o.kind == "rival" and (o.bonds_held as Array).is_empty() and String(o.rival_name) == String(Training.CHAMPION["name"])
			o.take_hit(999999.0, Vector2.ZERO)
			await t._frames(3)
	t._check(monsters == 2, "the first two rounds are the home station's low-level monsters (%d)" % monsters)
	t._check(champion, "the final round is a human champion fighter, with no marks")
	await _wait_done(main)
	p.iframes = 0.0
	t._check(Training.has_grace(prof) and not Training.closed(prof) and int(Training.state(prof)["first"].get("rounds", 0)) == 3, "the Noble grants the Grace")
	t._check(bool(Training.state(prof)["first"].get("flawless", false)), "...no damage taken: flawless")
	t._check(int(prof.supplies.get("draught", 0)) >= 1 and int(prof.supplies.get("scroll", 0)) >= 1, "...a Healing Vial and a recall scroll, packed for the next climb")
	var piece = prof.chest.back() if prof.chest.size() > chest0 else {}
	t._check(Gear.base_id(piece) == "dagger" and Gear.rarity(piece) == Training.PIECE_RARITY, "...a Fine piece of the weapon used most (%s)" % Gear.display(piece))
	t._check(Flow.tinctures().all(func(id): return int(prof.supplies.get(id, 0)) >= 1), "...and, flawless, a tincture of each kind from the Noble")
	t._check(menu.page == "station" and menu.station_page.stop == "arena" and menu.station_page.lines.any(func(l): return String(l) == Training.TEXT["grace_granted"]), "back at the grounds, the result says the Grace is granted")
	t._check(Train_put_back_gives_nothing(prof), "a gift put back gives no crystals for it")
	menu.leave_station()
	await t._frames(2)
	menu.train_car = "engine"
	menu.train_tower = "kraken"
	menu.open("train")
	await t._frames(3)
	var root: Node = menu.train_page.roots.get("engine", menu)
	t._check(root.find_children("*", "Control", true, false).any(func(c): return c.has_meta("depart")), "with the Grace the engine's lever is there")


func Train_put_back_gives_nothing(prof) -> bool:
	var Train = load("res://scripts/train.gd")
	var held: float = prof.crystals_held()
	Train.pack_supply(prof, "stamina", {"air": 0})
	Train.put_back(prof, "stamina")
	return prof.crystals_held() == held


## Every reward row: 0 rounds the Grace only, 1 a vial, 2 a scroll, 3 a piece, flawless tinctures.
func _rewards() -> void:
	var want := {0: [], 1: ["vial"], 2: ["vial", "scroll"], 3: ["vial", "scroll", "piece"]}
	for n in want:
		var p = _fresh_profile()
		Training.require(p)
		var lines: Array = Training.apply_first(p, {"rounds": n, "flawless": false, "used": {"war_hammer": 4, "sword": 1}, "armor": "chain"})
		var got: Array = Training.state(p)["first"].get("rewards", [])
		var vial := int(p.supplies.get("draught", 0)) == (1 if n >= 1 else 0)
		var scroll := int(p.supplies.get("scroll", 0)) == (1 if n >= 2 else 0)
		var pc: bool = (p.chest.size() == 1 and Gear.base_id(p.chest[0]) == "war_hammer" and Gear.rarity(p.chest[0]) == "fine") if n >= 3 else p.chest.is_empty()
		t._check(Training.has_grace(p) and got == want[n] and vial and scroll and pc and not lines.is_empty(), "%d rounds won: the Grace%s (%s)" % [n, "" if want[n].is_empty() else " + " + ", ".join(want[n]), got])
	var f = _fresh_profile()
	Training.require(f)
	Training.apply_first(f, {"rounds": 3, "flawless": true, "used": {}, "armor": ""})
	t._check(Flow.tinctures().size() == 6 and Flow.tinctures().all(func(id): return int(f.supplies.get(id, 0)) == 1), "flawless: one essence tincture of each kind")
	t._check(Gear.base_id(f.chest[0]) == Training.PIECE_ARMOR, "...and with no weapon used, the piece is armour")
	var nf = _fresh_profile()
	Training.require(nf)
	Training.apply_first(nf, {"rounds": 2, "flawless": true})
	t._check(not Flow.tinctures().any(func(id): return nf.supplies.has(id)), "flawless counts only if every round is won")
	var again: Array = Training.apply_first(f, {"rounds": 3, "flawless": true})
	t._check(f.chest.size() == 1 and int(f.supplies.get("draught", 0)) == 1 and not again.is_empty(), "the rewards are given once")


# --- training's essence -----------------------------------------------------------------------------

## A quarter into the body only (unmarked or marked), half the natural way later.
func _essence(main) -> void:
	var p = _fresh_profile()
	Training.settle(p, {"type": "first", "essence": {"water": 40.0}, "soak": {"hand": 8.0, "legs": 2.0}})
	t._check(is_equal_approx(float(p.density.get("water", 0.0)), 10.0) and p.crystals.is_empty(), "the first tournament's essence: a quarter, into the body, no crystals (%.1f)" % float(p.density.get("water", 0.0)))
	t._check(float(p.soak.get("hand", 0.0)) > float(p.soak.get("legs", 0.0)) and is_equal_approx(float(Training.state(p)["soak"].get("hand", 0.0)), 8.0 * Training.SOAK_SHARE), "...spread by what each part did, and kept toward the first mark")
	t._check(Training.first_soak(p).get("hand", 0.0) > Training.first_soak(p).get("legs", 0.0), "the first climb starts with training's soak (main.gd seeds climb_soak)")
	main.climb_soak = Training.first_soak(p)
	var was_first: bool = main.first_climb
	main.first_climb = true
	var lead: String = main.leading_part()
	main.first_climb = was_first
	main.climb_soak = {}
	t._check(lead == "hand" or main.profile.bonds.has("hand"), "...so the part used most in training is where the first mark would form (%s)" % lead)
	var m = _fresh_profile()
	var bid: String = Bonds.BONDS.keys()[0]
	m.add_bond("brow", bid, false)
	var xp0 := float(m.bonds["brow"]["xp"])
	Training.settle(m, {"type": "lesson", "essence": {"air": 20.0}, "soak": {"hand": 4.0}})
	t._check(float(m.bonds["brow"]["xp"]) == xp0 and float(m.density.get("air", 0.0)) > 0.0, "a marked climber refreshing basic training: the body only, never the marks")
	Training.settle(m, {"type": "tourney", "essence": {"air": 20.0}, "soak": {"hand": 4.0}})
	t._check(float(m.bonds["brow"]["xp"]) > xp0, "later tournaments: half the usual, flowing into the marks too")
	t._check(float(Training.RATES["first"]["rate"]) == 0.25 and float(Training.RATES["lesson"]["rate"]) == 0.25 and float(Training.RATES["tourney"]["rate"]) == 0.5 and float(Training.RATES["advanced"]["rate"]) == 0.5,
		"a quarter for basic training and the first tournament, a half for advanced training and later tournaments")


# --- advanced and mark training ---------------------------------------------------------------------

func _advanced(main) -> void:
	var prof = main.profile
	var arena = main.arena
	var menu = main.menu
	var station := "kraken"
	var r := Renown.state(prof)
	r["titles"] = []
	t._check(Training.ADVANCED_ORDER.size() == 6 and Training.MARK_ORDER.size() == 6 and Training.TIERS.size() == 3, "six advanced lessons, six of mark training, three tiers")
	t._check(Training.why_not(prof, "belt") == Training.locked_text(0), "advanced training waits for a title (%s)" % Training.why_not(prof, "belt"))
	r["titles"] = ["newcomer"]
	t._check(Training.tier_open(prof, 0) and not Training.tier_open(prof, 1) and Training.why_not(prof, "wall") == Training.locked_text(1), "a first title opens the first tier only")
	var kind := Training.fee_kind(prof, "belt")
	t._check(kind == "water" and Stations.fee_kind(prof, "advanced", "belt") == "water" and Stations.fee_kind(prof, "drill", "parry") == "any", "a lesson's fee is paid in the essence that fits it (%s)" % kind)
	while prof.crystal_total("water") > 0.0:
		prof.take_crystal("water", 999.0)
	t._check(Training.why_not(prof, "belt").contains("Water") or Training.why_not(prof, "belt").contains("water"), "...short of it, it says so (%s)" % Training.why_not(prof, "belt"))
	prof.add_crystal("water", 10.0)
	var fee := Training.fee(prof, "belt")
	var pts := Renown.points(prof)
	var why: String = arena.start(Stations.event("advanced", "belt", station))
	t._check(why == "" and prof.crystal_total("water") == 10.0 - float(fee) and fee > 0 and fee <= 6, "it takes its small fee (%d water)" % fee)
	await t._frames(3)
	var p = main.player
	p.item_sel = "draught" if p.item_count("draught") > 0 else "tonic"
	p.use_item()
	await _wait_done(main)
	t._check(Training.done(prof, "belt") and Renown.points(prof) == pts + int(Training.TIERS[0]["renown"]), "done: remembered, and its first time pays a little renown (+%d)" % int(Training.TIERS[0]["renown"]))
	menu.go_station(station, "gym")
	await t._frames(3)
	t._check(_station_buttons(menu, "pick", "advanced:belt").size() == 1 and _station_buttons(menu, "pick", "advanced:cast").size() == 1, "the gym lists advanced and mark training")
	var tile: Array = _station_buttons(menu, "pick", "advanced:wall")
	if tile.size() == 1:
		tile[0].pressed.emit()
		await t._frames(2)
	var btn: Array = _station_buttons(menu, "station_do", "advanced")
	t._check(btn.size() == 1 and btn[0].disabled and not Help.missing(btn[0]), "a locked tier's card says why, its button off (and explained)")
	# Mark training: after the first mark.
	t._check(Training.why_not(prof, "cast") == Training.TEXT["mark_locked"], "mark training opens with the first mark")
	var bid: String = Bonds.BONDS.keys()[0]
	prof.add_bond("hand", bid, false)
	var mk := Training.fee_kind(prof, "cast")
	t._check(mk == String(Bonds.BONDS[bid]["affinity"]), "...its fee in your mark's own essence (%s)" % mk)
	prof.add_crystal(mk, 50.0)
	t._check(Training.why_not(prof, "cast") == "", "...open with a mark and a title")
	r["titles"] = ["newcomer", "ironclad"]
	t._check(Training.tier_open(prof, 2), "a title of a higher rank opens the third tier")
	why =arena.start(Stations.event("advanced", "spar", station))
	await t._frames(3)
	t._check(why == "" and arena.spar_body != null and (arena.spar_body.bonds_held as Array).size() == 1, "sparring: a human rival with a mark of their own")
	if arena.spar_body != null:
		arena.spar_body.take_hit(999999.0, Vector2.ZERO)
	await _wait_done(main)
	t._check(Training.done(prof, "spar"), "...who yields when beaten")
	var partners: Array = Training.MARK_ORDER.map(func(id): return String(Training.MARK[id]["partner"]))
	t._check(partners.has("dummies") and partners.has("creatures") and partners.has("rivals"), "mark training's partners: dummies, summoned creatures, human rivals")


# --- the Tournament Manager -------------------------------------------------------------------------

func _manager(main) -> void:
	var prof = main.profile
	var arena = main.arena
	var menu = main.menu
	prof.climbs = 0
	var order: Array = Tournaments.ROTATION["order"]
	t._check(order.size() == 6 and Tournaments.here(prof) == order[0] and Tournaments.next(prof) == order[1], "the Manager starts at %s, next %s" % [order[0], order[1]])
	prof.climbs = 1
	t._check(Tournaments.here(prof) == order[1], "...and moves on after each climb (rotation by climbs)")
	prof.climbs = 6
	t._check(Tournaments.here(prof) == order[0], "...round the loop")
	prof.climbs = 1
	var here: String = Tournaments.here(prof)
	var away: String = order[3]
	t._check(Stations.why_not(prof, "tourney", "novice", away) == Tournaments.TEXT["why_away"] % Tournaments.station_name(here), "brackets run only where the Manager is")
	var seen_layout := {}
	var seen_hazard := {}
	for st in order:
		var ev := Stations.event("tourney", "open", st)
		var loc := Tournaments.location(st)
		var mons: Array = ev["rounds"][0].get("monsters", [])
		var ok: bool = String(ev["tower"]) == Travel.tower_of(st) and mons.size() == int(Tournaments.BRACKET_CREATURES["open"]) and mons.all(func(k): return (loc["creatures"] as Array).has(k)) \
			and String(ev["marks_kind"]) == String(Towers.TOWERS[Travel.tower_of(st)]["essence"])
		var pil: Array = Tournaments.pillars(String(ev["layout"]), main.OPEN_ROOM)
		var hz: Array = Tournaments.hazards(st, main.OPEN_ROOM, 5)
		ok = ok and not pil.is_empty() and pil.all(func(pl): return main.OPEN_ROOM.has_point(pl["pos"])) and not hz.is_empty() and hz.all(func(h): return main.OPEN_ROOM.has_point(h["pos"]) and String(h["kind"]) == String(loc["hazard"]))
		seen_layout[ev["layout"]] = true
		seen_hazard[loc["hazard"]] = true
		t._check(ok, "%s: its arena (%s, %s), its creatures first, rivals leaning to its tower" % [st, ev["layout"], loc["hazard"]])
	t._check(seen_layout.size() == 6 and seen_hazard.size() == 6, "each location has its own layout and hazard")
	# A bracket where the Manager is: its layout and hazards in the room.
	prof.add_crystal("fire", 200.0)
	menu.go_station(here, "arena")
	await t._frames(3)
	t._check(_station_buttons(menu, "pick", "manager:here").size() == 1, "the grounds say where the Manager is")
	var held: float = prof.crystals_held()
	var why: String = arena.start(Stations.event("tourney", "novice", here))
	await t._frames(3)
	t._check(why == "" and prof.crystals_held() < held, "a later tournament costs an entry fee")
	t._check(main.traps.size() == int(Tournaments.HAZARD["count"]) and main.pillars.size() == (Tournaments.LAYOUTS[Tournaments.location(here)["layout"]] as Array).size(), "...in the location's arena: its pillars and hazards (%d traps, %d pillars)" % [main.traps.size(), main.pillars.size()])
	arena.give_up()
	await t._frames(3)
	t._check(main.traps.is_empty(), "the hazards go when it's over")
	# The rewards: the shared minor one, and the location's own prize once.
	var p = _fresh_profile()
	var lines: Array = Tournaments.reward(p, here, "novice")
	t._check(int(p.supplies.get("draught", 0)) == 1 and p.chest.is_empty() and lines.size() == 1, "a bracket won anywhere: the shared minor reward")
	lines = Tournaments.reward(p, here, "open")
	var named := Gear.named_id(Gear.rec(p.chest[0])) if not p.chest.is_empty() else ""
	t._check(named == String(Tournaments.location(here)["prize"]), "a higher bracket won here: this location's own prize (%s)" % named)
	Tournaments.reward(p, here, "masters")
	t._check(p.chest.size() == 1, "...once")
	var prizes := {}
	for st in order:
		prizes[Tournaments.location(st)["prize"]] = true
	t._check(prizes.size() == 6 and prizes.keys().all(func(k): return Gear.NAMED.has(k)), "every location's prize is its own")
	var pz := Stations.prize(prof, "novice", here)
	t._check(String(pz["kind"]) == String(Towers.TOWERS[Travel.tower_of(here)]["essence"]), "the prize crystals are the location's tower's kind")


# --- the Entity ---------------------------------------------------------------------------------------

func _entity(main) -> void:
	for id in ["grace", "basic_training", "first_tournament", "first_rewards", "advanced_training", "mark_training", "tourney_manager"]:
		t._check(Entity.TIPS.has(id) and String(Entity.TIPS[id]["group"]) == "station" and String(Entity.TIPS[id]["tip"]).length() <= 170, "the Entity has a first-time moment: %s" % id)
	var how: Array = Talk.DIALOGUE["how"]["choices"]
	t._check(how.has("how_grace") and how.has("how_training") and how.has("how_manager"), "...and 'How does it work?' topics for the Grace, training and the Manager")
	var prof = main.profile
	for id in ["how_grace", "how_training", "how_manager"]:
		var said := Talk.line_for(main, id)
		t._check(said.length() > 60 and not said.contains("{"), "%s reads whole" % id)
	var p = _fresh_profile()
	Training.require(p)
	t._check(Training.hint(p).contains(str(Tutorial.count())), "'What should I do next?' points a new climber at basic training (its steps left)")
	for k in ["pick:advanced", "pick:first", "pick:grace", "pick:manager", "station_do:first", "station_do:advanced", "furnish:grace_lock"]:
		t._check(Help.HELP.has(k), "button help: %s" % k)
	var ids: Array = Registry.SECTIONS.map(func(s): return String(s["id"]))
	t._check(ids.has("training_words") and ids.has("training_numbers"), "training and the Manager are in the Data editor")
	var all := JSON.stringify([Training.GRACE, Training.CHAMPION, Training.TIERS, Training.ADVANCED, Training.MARK, Training.TEXT, Tournaments.MANAGER, Tournaments.LINES, Tournaments.LOCATIONS, Tournaments.TEXT]).to_lower()
	var re := RegEx.create_from_string("\\b(" + "|".join(BANNED) + ")\\b")
	t._check(re.search(all) == null, "no banned words in training's and the Manager's words")
	var readme := FileAccess.get_file_as_string("res://README.md")
	t._check(readme.contains("## Training, the Grace and tournaments") and readme.contains("Tournament Manager"), "the README explains training, the Grace and the Manager")


# --- a phone --------------------------------------------------------------------------------------------

func _phone(main) -> void:
	var menu = main.menu
	var was: Vector2i = t.root.size
	t.root.size = Vector2i(844, 390)
	main.touch._set_active(true)
	await t._frames(2)
	var vw: float = menu.get_viewport_rect().size.x
	var over: Array = []
	for stop in ["gym", "arena", "noble"]:
		menu.go_station("kraken", stop)
		await t._frames(3)
		for b in t._all_buttons(menu.box):
			if b.is_visible_in_tree():
				var r: Rect2 = b.get_global_rect()
				if r.position.x < -1.0 or r.end.x > vw + 1.0:
					over.append("%s %s" % [stop, b.get_meta("pick", b.text)])
		if not menu.panel.get_global_rect().end.x <= vw + 1.0:
			over.append(stop + " panel")
	t._check(over.is_empty(), "at 844x390 the gym, the grounds and the Noble fit across the screen (%s)" % [over.slice(0, 6)])
	main.touch._set_active(false)
	t.root.size = was
	await t._frames(2)
