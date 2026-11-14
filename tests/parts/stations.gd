extends RefCounted
## Stations between towers (stations.gd, station_page.gd, station_view.gd,
## arena.gd), renown and titles (renown.gd), boons (boons.gd) and the
## outfitter's upgrades (train.gd): travelling to the station and back, each
## drill's scoring (and each one run in the arena), a tournament bout won
## and lost, renown earned and its ranks, titles earned and worn, boons
## bought and with you on the next climb, the outfitter's upgrades taking
## effect, old saves loading with no renown, and the pages at a phone's size.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const Stations := preload("res://scripts/stations.gd")
const Renown := preload("res://scripts/renown.gd")
const Boons := preload("res://scripts/boons.gd")
const Train := preload("res://scripts/train.gd")
const Gear := preload("res://scripts/gear.gd")
const ProfileScript := preload("res://scripts/profile.gd")
const TestRun := preload("res://scripts/test_run.gd")

var t


func run(smoke) -> void:
	t = smoke
	print("stations: renown, titles, the gym, the tournament, boons and the outfitter")
	await t._fresh_main()
	var main = t.main
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.grant_test_bonds()
	for e in main.enemies():
		e.queue_free()
	_old_saves()
	_renown(main)
	_scoring()
	await _travel(main)
	await _titles(main)
	await _drills(main)
	await _bouts(main)
	await _boons(main)
	await _outfitter(main)
	await _phone(main)
	main.menu.station_page.station = ""
	main.menu.close()
	t.paused = false
	main.on_train = false
	await t._frames(2)


## A save from before renown: it loads with none, and renown saves and loads.
func _old_saves() -> void:
	var path := TestRun.path("user://stations_old.cfg")
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "regarded", true)
	cfg.set_value("profile", "climbs", 4)
	cfg.set_value("climb", "best_floor", 6)
	cfg.save(path)
	var p = ProfileScript.new()
	p.save_path = path
	p.load_save()
	t._check(p.renown.is_empty() and Renown.points(p) == 0 and Renown.rank(p) == 0 and Renown.worn_title(p) == "" and Boons.fx(p).is_empty(),
		"an old save loads with no renown (0, the first rank, no title, no boons)")
	t._check(Train.rack_size(p) == Train.RACK_SIZE and Train.discount(p) == 0.0 and Train.order(p).is_empty(), "...and the outfitter as he was")
	Renown.earn(p, 40, "a test deed")
	var q = ProfileScript.new()
	q.save_path = path
	q.load_save()
	t._check(Renown.points(q) == 40 and String(Renown.state(q)["deeds"][0]["text"]) == "a test deed", "renown and deeds save with the climber and load again")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## Renown.earn, the ranks, and what a climb earns.
func _renown(main) -> void:
	var prof = main.profile
	prof.renown = {}
	var got := Renown.earn(prof, 30, "thirty")
	t._check(Renown.points(prof) == 30 and Renown.rank(prof) == 1 and got["rank_up"] == Renown.rank_name(1), "Renown.earn adds renown, and 25 reaches the second rank (%s)" % Renown.rank_name(Renown.rank(prof)))
	var deeds: Array = Renown.state(prof)["deeds"]
	t._check(deeds.size() == 2 and String(deeds[0]["text"]) == "thirty" and String(deeds[1]["text"]).contains(Renown.rank_name(1)), "the deed and the new rank are remembered for the board")
	t._check(Renown.rank_for(0) == 0 and Renown.rank_for(Renown.needed(Renown.RANKS.size() - 1)) == Renown.RANKS.size() - 1 and Renown.next_text(prof).contains(Renown.rank_name(2)), "ranks come at their thresholds; the board says what's next")
	var before := Renown.points(prof)
	main.climb_paid = false
	main.climb_best0 = 2
	main.floor_num = 5
	main.pay_climb()
	var want := int(Renown.CLIMB["floor"]) * 5 + int(Renown.CLIMB["best"]) * 3
	t._check(Renown.points(prof) == before + want and int(Renown.state(prof)["streak"]) == 1, "a climb's end earns renown for its floors and its new best (+%d)" % want)
	before = Renown.points(prof)
	Renown.on_beast(prof, "the Kraken")
	t._check(Renown.points(prof) == before + int(Renown.CLIMB["beast"]), "a beast felled earns renown")
	Renown.on_climb_end(prof, "test", 1, 5, true)
	t._check(int(Renown.state(prof)["streak"]) == 0, "a fall breaks the run of climbs without one")
	main.floor_num = 1


## Each drill's medals, from its scores.
func _scoring() -> void:
	var ok := true
	var bad: Array = []
	for id in Stations.DRILL_ORDER:
		var d: Dictionary = Stations.DRILLS[id]
		var m: Array = d["medals"]
		var lower: bool = d.get("lower", false)
		var worse := float(m[0]) + (5.0 if lower else -1.0)
		var good: bool = Stations.medal_for(id, float(m[2])) == 3 and Stations.medal_for(id, float(m[1])) == 2 and Stations.medal_for(id, float(m[0])) == 1 \
			and Stations.medal_for(id, worse) == 0 and Stations.medal_for(id, -1.0) == 0
		if not good:
			ok = false
			bad.append(id)
	t._check(ok and Stations.DRILL_ORDER.size() >= 5, "every drill scores bronze, silver and gold at its marks, and nothing below or unfinished (%s)" % [bad])
	t._check(Stations.score_text("rush", 14.0) == "14.0 s" and Stations.score_text("parry", 7.0).begins_with("7"), "scores read as times or counts")


func _station_buttons(menu, meta: String, val) -> Array:
	return t._all_buttons(menu.box).filter(func(b): return b.has_meta(meta) and b.get_meta(meta) == val)


## From the engine to the station, around its stops, and back.
func _travel(main) -> void:
	var menu = main.menu
	main.open_train()
	await t._frames(2)
	menu.train_car = "engine"
	menu.open("train")
	await t._frames(2)
	var flip: Array = t._car_buttons("board", "stations")
	t._check(flip.size() == 1, "the engine's board has a sign for the stations")
	if flip.size() == 1:
		flip[0].pressed.emit()
		await t._frames(2)
	var cards: Array = t._car_buttons("station", String(Stations.STATIONS[0]["id"]))
	var lever: Array = t._car_buttons("go_station", String(Stations.STATIONS[0]["id"]))
	t._check(menu.train_board == "stations" and cards.size() == 1 and lever.size() == 1, "...turned, it lists the stations, with a lever for the chosen one")
	var visits := int(Renown.state(main.profile)["visits"])
	if lever.size() == 1:
		lever[0].pressed.emit()
		await t._frames(3)
	t._check(menu.page == "station" and menu.at_station() and main.on_train and menu.station_view.visible and not menu.train_view.visible, "pulling it stops at the station: its page, drawn behind")
	var ids: Array = menu.rail.buttons.map(func(b): return b.id)
	t._check(Stations.stops(menu.station_page.station).all(func(s): return ids.has(s)) and ids.has("leave_station") and not ids.has("engine"), "the rail lists the station's stops and the way back (%s)" % [ids])
	t._check(int(Renown.state(main.profile)["visits"]) == visits + 1 and Renown.titles(main.profile).has("newcomer"), "the stop is counted (a title for it)")
	menu.rail_pressed("arena")
	await t._frames(2)
	t._check(menu.station_page.stop == "arena" and menu.rail_item() == "arena", "choosing a stop on the rail shows it")
	menu._cycle(1)
	await t._frames(2)
	t._check(menu.station_page.stop == "challenges", "Q / E move to the next stop")
	menu.open("climber")
	await t._frames(2)
	t._check(menu.rail.buttons.any(func(b): return b.id == "gym"), "the climber screen opened at the station keeps the station's rail")
	menu.close()
	await t._frames(2)
	t._check(menu.page == "station", "...and closing it goes back to the station")
	menu.rail_pressed("leave_station")
	await t._frames(2)
	t._check(menu.page == "train" and menu.train_car == "engine" and not menu.at_station() and menu.train_view.visible, "Back to the train: on the train again, in the engine")
	menu.go_station(String(Stations.STATIONS[0]["id"]), "gym")
	await t._frames(2)
	t._check(menu.page == "station" and menu.station_page.stop == "gym", "go_station opens a stop directly")


## Titles: earned by deeds, worn one at a time, shown under the name.
func _titles(main) -> void:
	var prof = main.profile
	var menu = main.menu
	t._check(not Renown.wear(prof, "champion") and Renown.worn_title(prof) == "", "a title not earned can't be worn")
	var r := Renown.state(prof)
	for id in Stations.DRILL_ORDER:
		r["drills"][id] = 3
	var fresh := Renown.check_titles(prof)
	t._check(fresh.has("goldhand") and fresh.has("trainee"), "a gold in every drill earns titles (%s)" % [fresh])
	r["drills"] = {}
	menu.go_station(menu.station_page.station, "board")
	await t._frames(2)
	var tile: Array = _station_buttons(menu, "pick", "title:newcomer")
	t._check(tile.size() == 1, "the renown board lists the titles")
	if tile.size() == 1:
		tile[0].pressed.emit()
		await t._frames(1)
	var wear: Array = _station_buttons(menu, "station_do", "wear")
	t._check(wear.size() == 1, "...an earned one's card can wear it")
	if wear.size() == 1:
		wear[0].pressed.emit()
		await t._frames(3)
	var name := Renown.title_name("newcomer")
	t._check(Renown.worn_title(prof) == name and menu._climber_line().begins_with(name), "worn: it shows under the name in the book (%s)" % menu._climber_line())
	t._check(menu.rail.ident.custom_minimum_size.y > 100.0, "...and the rail makes room for it under the name")


func _wait_done(main, seconds := 6.0) -> void:
	await t._until(func(): return not main.arena.on, seconds)
	await t._frames(3)


## Every drill, run in the arena, earns its medal.
func _drills(main) -> void:
	var prof = main.profile
	var menu = main.menu
	var arena = main.arena
	Renown.earn(prof, 200, "")  # (every drill open)
	var station: String = menu.station_page.station
	for id in Stations.DRILL_ORDER:
		var d: Dictionary = Stations.DRILLS[id]
		var why: String = arena.start(Stations.event("drill", id, station))
		await t._frames(3)
		t._check(why == "" and arena.on and not main.on_train and not menu.is_open() and main.player.is_physics_processing(), "%s: the drill begins in the arena" % id)
		match String(d["kind"]):
			"parry":
				for i in int(d["medals"][2]):
					main.player.on_parry.emit(null, false)
				arena.t = float(d["time"])
			"kills":
				var foes: Array = main.enemies()
				var slain0: int = prof.count("slain")
				var ess0 := float(main.run_essence.get("water", 0.0))
				if not foes.is_empty():
					t._slay(foes[0])
					await t._frames(2)
				t._check(arena.kills == 1 and prof.count("slain") == slain0 and float(main.run_essence.get("water", 0.0)) == ess0, "a foe felled in the arena counts, and drops no essence or record")
				arena.kills = int(d["need"])
			"dodge":
				arena.t = float(d["time"])
			"run":
				for at in arena.posts.duplicate():
					main.player.global_position = at
					await t.physics_frame
					await t.physics_frame
			"cast":
				main.player.spells_cast += 1
				await t.physics_frame
				await t.physics_frame
				for dm in arena.dummies:
					dm.take_hit(1.0, Vector2.ZERO)
				await t.physics_frame
		await _wait_done(main)
		t._check(int(Renown.state(prof)["drills"].get(id, 0)) == 3, "%s: the score earns gold (%s)" % [id, Renown.state(prof)["best"].get(id, "none")])
		t._check(menu.page == "station" and menu.station_page.stop == "gym" and not menu.station_page.lines.is_empty() and main.on_train, "...and it's back at the gym, the result on its card")
	# A fall in a drill ends it with no medal (and no fall).
	Renown.state(prof)["drills"].erase("parry")
	arena.start(Stations.event("drill", "parry", station))
	await t._frames(2)
	var p = main.player
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.parry_t = 0.0
	p.receive_attack(99999.0, null)
	t._check(not p.dead and p.hp >= 1.0, "a blow that would fell you in the arena doesn't")
	await _wait_done(main)
	t._check(int(Renown.state(prof)["drills"].get("parry", 0)) == 0 and menu.page == "station", "...the drill is lost instead")


## Tournament bouts: a win, a loss, champions and your mirror image.
func _bouts(main) -> void:
	var prof = main.profile
	var arena = main.arena
	var menu = main.menu
	var station: String = menu.station_page.station
	prof.add_crystal("fire", 200.0)
	var held: float = prof.crystals_held()
	var water0: float = prof.crystal_total("water")
	var pts := Renown.points(prof)
	var why: String = arena.start(Stations.event("bout", "copper_1", station))
	t._check(why == "" and prof.crystals_held() == held - Stations.fee("bout", "copper_1"), "a bout takes its entry fee")
	for i in 40:
		await t._until(func(): return not main.enemies().is_empty() or arena.done, 3.0)
		if arena.done:
			break
		for e in main.enemies():
			t._slay(e)
		await t._frames(2)
	await _wait_done(main)
	t._check(Stations.bout_wins(prof, "copper_1") == 1 and Renown.points(prof) == pts + int(Stations.bout("copper_1")["renown"]), "felling every wave wins the bout, for renown")
	t._check(prof.crystal_total("water") == water0 + float(Stations.TIERS[0]["crystals"]) and menu.station_page.lines.any(func(l): return String(l).contains(Stations.bout("copper_1")["name"])), "...and crystals of its tower's kind, said on its card")
	t._check(Stations.bout_open(prof, "copper_2") and not Stations.bout_open(prof, "copper_3"), "a win opens the next bout on the ladder")
	# A loss: only the fee.
	held = prof.crystals_held()
	pts = Renown.points(prof)
	arena.start(Stations.event("bout", "copper_2", station))
	await t._until(func(): return not main.enemies().is_empty(), 3.0)
	var p = main.player
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.parry_t = 0.0
	p.receive_attack(99999.0, null)
	await _wait_done(main)
	t._check(Stations.bout_wins(prof, "copper_2") == 0 and Renown.points(prof) == pts and prof.crystals_held() == held - Stations.fee("bout", "copper_2") and not p.dead,
		"falling loses the bout: it costs the entry fee and nothing more")
	# Giving up from the pause menu.
	arena.start(Stations.event("bout", "copper_2", station))
	await t._frames(2)
	menu.open("pause")
	await t._frames(2)
	var give: Array = t._all_buttons(menu.box).filter(func(b): return b.has_meta("give_up"))
	t._check(give.size() == 1, "the pause menu in the arena can give up")
	if give.size() == 1:
		give[0].pressed.emit()
	await t._frames(3)
	t._check(not arena.on and menu.page == "station", "...back to the station")
	# A champion, and the climber's own mirror image.
	Renown.state(prof)["bouts"]["copper_2"] = 1
	arena.start(Stations.event("bout", "copper_3", station))
	await t._until(func(): return not main.enemies().is_empty(), 3.0)
	t._check(main.enemies().any(func(e): return e.champion), "the champion's bout sends a champion")
	arena.give_up()
	await t._frames(3)
	var mirrors0 := int(Renown.state(prof)["mirrors"])
	Renown.state(prof)["bouts"]["iron_1"] = 1
	arena.start(Stations.event("bout", "iron_2", station))
	await t._until(func(): return not main.enemies().is_empty(), 3.0)
	t._check(main.enemies().any(func(e): return e.mirror), "Your Reflection sends your mirror image")
	for e in main.enemies():
		t._slay(e)
	await t._frames(2)
	await t._until(func(): return arena.done or not main.enemies().is_empty(), 4.0)
	for e in main.enemies():
		t._slay(e)
	await _wait_done(main)
	t._check(int(Renown.state(prof)["mirrors"]) > mirrors0 and Renown.titles(prof).has("glassbreaker"), "beating it is a deed: Glassbreaker")
	# Winning a tier's last bout: the tier, and a relic.
	var chest0: int = prof.chest.size()
	var res := Stations.apply_result(prof, {"type": "bout", "id": "copper_3", "won": true})
	t._check(bool(Renown.state(prof)["tiers"].get("1", false)) and prof.chest.size() == chest0 + 1 and Renown.titles(prof).has("contender"), "the tier's last bout wins the tier: a relic in the stash, a title")
	t._check(res["lines"].any(func(l): return String(l).contains(Gear.display(prof.chest.back()))), "...the relic named on the card")
	# A challenge pays once.
	pts = Renown.points(prof)
	Stations.apply_result(prof, {"type": "challenge", "id": "one_hit", "won": true})
	var once := Renown.points(prof)
	Stations.apply_result(prof, {"type": "challenge", "id": "one_hit", "won": true})
	t._check(once == pts + int(Stations.CHALLENGES["one_hit"]["renown"]) and Renown.points(prof) == once and Stations.challenge_won(prof, "one_hit"), "a challenge pays out the first time it's won, and only then")


## Boons: bought at the shrine, with you on the next climb.
func _boons(main) -> void:
	var prof = main.profile
	var menu = main.menu
	var p = main.player
	prof.add_crystal("stone", 300.0)
	prof.add_crystal("water", 300.0)
	var hp0: float = p.max_hp
	menu.go_station(menu.station_page.station, "shrine")
	await t._frames(2)
	var tile: Array = _station_buttons(menu, "pick", "boon:vigor")
	if tile.size() == 1:
		tile[0].pressed.emit()
		await t._frames(1)
	var stone0: float = prof.crystal_total("stone")
	var buy: Array = _station_buttons(menu, "station_do", "buy")
	t._check(tile.size() == 1 and buy.size() == 1, "the shrine lists the boons, with Buy on a boon's card")
	if buy.size() == 1:
		buy[0].pressed.emit()
		await t._frames(2)
	t._check(Boons.level(prof, "vigor") == 1 and prof.crystal_total("stone") == stone0 - float(Boons.BOONS["vigor"]["price"]), "buying a boon takes its price in crystals")
	t._check(p.max_hp == hp0 + float(Boons.BOONS["vigor"]["fx"]["health"]), "...and the climber has it at once (+health)")
	t._check(Boons.price(prof, "vigor")[1] == int(Boons.BOONS["vigor"]["price"]) * 2, "the next level costs more")
	t._check(Boons.buy(prof, "satchel") == "", "Satchel bought")
	var locked := ""
	for id in Boons.ORDER:
		if int(Boons.BOONS[id]["rank"]) > Renown.rank(prof):
			locked = id
	if locked != "":
		t._check(Boons.buy(prof, locked) != "" and Boons.level(prof, locked) == 0, "a boon above your rank can't be bought")
	# The next climb: the boons are with you.
	menu.rail_pressed("leave_station")
	await t._frames(2)
	var draughts: int = p.item_count("draught")
	main.depart("kraken")
	await t._frames(2)
	t._check(not main.on_train and p.max_hp == hp0 + float(Boons.BOONS["vigor"]["fx"]["health"]) and p.item_count("draught") == draughts + 1, "on the next climb: the health, and Satchel's extra draught on the belt")
	t._check(Boons.fx(prof).get("health", 0.0) == float(Boons.BOONS["vigor"]["fx"]["health"]), "...and a new climb's scene puts them on again (main.gd: Boons.fx)")
	main.await_tower()
	main.open_train()
	await t._frames(2)


## The outfitter's upgrades, unlocked by renown.
func _outfitter(main) -> void:
	var prof = main.profile
	var menu = main.menu
	var p = main.player
	var low = ProfileScript.new()
	low.saving = false
	t._check(Train.rack_size(low) == Train.RACK_SIZE and Train.supply_price(low, "scroll")[1] == int(Train.ANY_PRICE["scroll"]), "with no renown: the rack and the scroll as they were")
	Renown.earn(prof, Renown.needed(Renown.RANKS.size() - 1), "")
	Renown.state(prof)["boons"].erase("haggler")
	t._check(Train.upgrades_done(prof) == Train.UPGRADES.size() and Train.next_upgrade(prof).is_empty(), "the top rank unlocks every upgrade")
	prof.store = {}
	Train.stock(prof)
	t._check(Train.outfit(prof).size() == Train.RACK_SIZE + int(Train.UPGRADE_FX["rack_extra"]), "a wider rack: more pieces on it")
	var d := float(Train.UPGRADE_FX["discount"])
	t._check(Train.supply_price(prof, "scroll")[1] == int(round(float(Train.UPGRADE_FX["scroll_price"]) * (1.0 - d))), "the scroll kept aside costs less (with the discount)")
	var g: Dictionary = Train.outfit(prof)[1]
	t._check(Train.buy_price(prof, g) == maxi(1, int(round(Train.gear_price(g) * (1.0 - d)))), "a regular's discount off a piece")
	var fines := 0
	for i in 12:
		var r: Dictionary = Train.roll_today(prof)
		fines += 1 if Gear.rarity_rank(Gear.rarity(r)) >= Gear.rarity_rank("fine") else 0
	t._check(fines == 12, "better stock: today's piece is still Fine or better")
	t._check(Train.hold(prof, 1) == "" and Gear.same(Train.order(prof), g) and Train.outfit(prof)[1].is_empty(), "a special order: he holds the piece, off the rack")
	t._check(Train.hold(prof, 2) != "", "...one at a time")
	var kind := Train.gear_kind(g)
	prof.add_crystal(kind, 100.0)
	var before: float = prof.crystal_total(kind)
	t._check(Train.buy_gear(prof, p, -2, "chest") == "" and Train.order(prof).is_empty() and Gear.same(prof.chest.back(), g) and prof.crystal_total(kind) == before - Train.buy_price(prof, g), "...and sells it to you when you come back for it")
	# In the Outfitter's Car: the upgrades sign and the special order's slot.
	menu.train_car = "store"
	menu.train_store = "shop"
	menu.open("train")
	await t._frames(3)
	var up: Array = t._car_buttons("slot", "upgrades")
	var order: Array = t._car_buttons("slot", "order")
	t._check(up.size() == 1 and order.size() == 1, "the Outfitter's Car shows his upgrades and the special order's slot")
	if up.size() == 1:
		up[0].pressed.emit()
		await t._frames(2)
	t._check(menu.inv_sel == "upgrades" and t._all_labels(menu.details).any(func(l): return l.text.contains(Train.UPGRADES[0]["name"])), "...his upgrades' card lists them")


## The station's pages at a phone's size, and a narrow one: nothing runs off
## the screen across, every stop's tiles and card are there.
func _phone(main) -> void:
	var menu = main.menu
	var was: Vector2i = t.root.size
	var keep_ui: String = menu.settings["ui_size"]
	t.root.size = Vector2i(915, 412)
	main.touch._set_active(true)
	for size in ["normal", "larger"]:
		menu.settings["ui_size"] = size
		main.apply_view_scale()
		await t._frames(2)
		var vw: float = menu.get_viewport_rect().size.x
		var over: Array = []
		for stop in Stations.stops(menu.station_page.station):
			menu.go_station(menu.station_page.station, stop)
			await t._frames(3)
			for b in t._all_buttons(menu.box):
				if not b.is_visible_in_tree():
					continue
				var r: Rect2 = b.get_global_rect()
				if r.position.x < -1.0 or r.end.x > vw + 1.0:
					over.append("%s %s" % [stop, b.get_meta("pick", b.text)])
			for b in menu.rail.buttons:
				if b.get_global_rect().end.x > vw + 1.0:
					over.append("rail " + String(b.id))
			if not menu.panel.get_global_rect().end.x <= vw + 1.0:
				over.append(stop + " panel")
		t._check(over.is_empty(), "on a phone (Interface size %s) every stop fits across the screen (%s)" % [size, over.slice(0, 6)])
	menu.settings["ui_size"] = "normal"
	main.apply_view_scale()
	menu.go_station(menu.station_page.station, "gym")
	await t._frames(3)
	var tile: Array = _station_buttons(menu, "pick", "drill:rush")
	if tile.size() == 1:
		menu.scroll.ensure_control_visible(tile[0])
		await t._frames(2)
		await t._tap_at(tile[0].get_global_rect().get_center())
	t._check(tile.size() == 1 and menu.station_page.picks.get("gym", "") == "drill:rush", "a tap on a drill shows its card")
	main.touch._set_active(false)
	menu.settings["ui_size"] = keep_ui
	main.apply_view_scale()
	t.root.size = was
	await t._frames(2)
