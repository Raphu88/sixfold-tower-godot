extends RefCounted
## Stations between towers, reworked (stations.gd, station_page.gd,
## station_view.gd, arena.gd), renown you can see (renown.gd), titles with
## social benefits (titles.gd), the Noble and contracts (noble.gd,
## contracts.gd), charm rewards for rank (charms.gd), and the outfitter's
## upgrade tree opening with rank (outfitter.gd; tests/parts/outfitter.gd
## has the rest): travelling to the station and back; every Training
## lesson run, remembered and skippable, with its set reward; a medal drill
## with its fee; a tournament bracket won and lost without dying; the Noble
## granting a title when renown allows and showing its benefits; titles'
## benefits applying (the outfitter's discount, rival climbers' terms,
## Training's fee and extra drills, tournament masters' brackets); contracts
## taken, tracked in play and done (retrieve, reach a floor, slay X) and
## never blocking a floor; every renown gain saying what for, and the next
## rank's preview; rank-ups as a moment; the Boon Shrine gone and old saves
## with boons refunded; the Pedlar gone; no banned words; the pages at a
## phone's size. (This replaces the old checks of the Boon Shrine, the
## tournament's tiers of bouts and the challenges, which are gone.)
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const Stations := preload("res://scripts/stations.gd")
const Renown := preload("res://scripts/renown.gd")
const Titles := preload("res://scripts/titles.gd")
const Noble := preload("res://scripts/noble.gd")
const Contracts := preload("res://scripts/contracts.gd")
const Charms := preload("res://scripts/charms.gd")
const Bench := preload("res://scripts/bench.gd")
const Train := preload("res://scripts/train.gd")
const Gear := preload("res://scripts/gear.gd")
const Reach := preload("res://scripts/reach.gd")
const Entity := preload("res://scripts/entity.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const Help := preload("res://scripts/entity_help.gd")
const Registry := preload("res://scripts/data_registry.gd")
const ProfileScript := preload("res://scripts/profile.gd")
const TestRun := preload("res://scripts/test_run.gd")

const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

var t


func run(smoke) -> void:
	t = smoke
	print("stations: training, tournaments, the Noble, titles, contracts and renown you can see")
	await t._fresh_main()
	var main = t.main
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.grant_test_bonds()
	for e in main.enemies():
		e.queue_free()
	_old_saves()
	_gone()
	_words()
	await _renown(main)
	_scoring()
	await _travel(main)
	await _lessons(main)
	await _drills(main)
	await _tourney(main)
	await _noble(main)
	_benefits(main)
	_charm_rewards(main)
	await _contracts(main)
	await _outfitter(main)
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


# --- saves ------------------------------------------------------------------------------

## A save from before renown loads with none; one from the boons' days gets
## its crystals back and is told so; the old ladders' keys load harmlessly.
func _old_saves() -> void:
	var path := TestRun.path("user://stations_old.cfg")
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "regarded", true)
	cfg.set_value("profile", "climbs", 4)
	cfg.save(path)
	var p = ProfileScript.new()
	p.save_path = path
	p.load_save()
	t._check(p.renown.is_empty() and Renown.points(p) == 0 and Renown.rank(p) == 0 and Renown.worn_title(p) == "" and Contracts.active(p).is_empty(),
		"an old save loads with no renown (0, the first rank, no title, no contracts)")
	t._check(Train.rack_size(p) == Train.RACK_SIZE and Train.discount(p) == 0.0 and Train.order(p).is_empty(), "...and the outfitter as he was")
	Renown.earn(p, 40, "a test deed")
	var q = ProfileScript.new()
	q.save_path = path
	q.load_save()
	t._check(Renown.points(q) == 40 and String(Renown.state(q)["deeds"][0]["text"]) == "a test deed", "renown and deeds save with the climber and load again")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# Boons bought before the shrine closed: their crystals come back.
	cfg = ConfigFile.new()
	cfg.set_value("profile", "regarded", true)
	cfg.set_value("profile", "crystals", [{"kind": "stone", "amount": 5.0}])
	cfg.set_value("renown", "state", {"points": 130, "boons": {"vigor": 2, "satchel": 1, "keen_eye": 0}, "market": {"n": 3, "wares": []},
		"bouts": {"copper_1": 2}, "challenges": {"one_hit": true}, "tiers": {"1": true}, "titles": ["contender", "daring"], "worn": "daring"})
	cfg.save(path)
	var b = ProfileScript.new()
	b.save_path = path
	b.load_save()
	var r := Renown.state(b)
	var stone := 5.0 + 40.0 * 3.0  # (Vigor: 40 + 80)
	t._check(b.crystal_total("stone") == stone and b.crystal_total("water") == 60.0, "an old save's boons give back every crystal paid (%s stone, %s water)" % [b.crystal_total("stone"), b.crystal_total("water")])
	t._check(not b.renown.has("boons") and not b.renown.has("market") and String(r.get("refund", "")).contains("120") and r["deeds"].any(func(d): return String(d["text"]).contains("Boon Shrine")),
		"...the shrine's closing is noted, with what came back, for the board and the Entity to say")
	t._check(Renown.titles(b) == ["contender"] and Renown.worn_title(b) == "" and Stations.bracket_won(b, "novice") and int(r["rank_seen"]) == Renown.rank(b),
		"the old ladders' keys load: a won first tier is the Novice Bracket won, a retired title is dropped, no rank-up replays")
	b.save()
	var c = ProfileScript.new()
	c.save_path = path
	c.load_save()
	t._check(c.crystal_total("stone") == stone, "...and the refund happens once")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


## The Boon Shrine and the Pedlar are gone, and the challenges with the old ladders.
func _gone() -> void:
	t._check(not FileAccess.file_exists("res://scripts/boons.gd") and not ResourceLoader.exists("res://scripts/boons.gd"), "the Boon Shrine's script is gone")
	var stops: Array = Stations.stops(String(Stations.STATIONS[0]["id"]))
	t._check(stops == ["gym", "arena", "noble", "board"], "a station's stops: Training, Tournament, the Noble, the Renown Board (%s)" % [stops])
	for k in ["shrine", "market", "challenges"]:
		t._check(not Stations.STOPS.has(k), "no %s stop" % k)
	t._check(not Entity.TIPS.has("merchant") and not Help.HELP.has("rail:shrine") and not Help.HELP.has("rail:market") and not Help.HELP.has("pick:boon"), "no tip or help for the boons or the Pedlar")
	var hint_words := JSON.stringify(Talk.HINTS).to_lower() + JSON.stringify(Talk.DIALOGUE).to_lower()
	t._check(not hint_words.contains("boon") and not hint_words.contains("pedlar"), "the Entity's talk no longer mentions boons or the Pedlar")


## Every new word is in data, in the Data editor, with no banned words.
func _words() -> void:
	var ids: Array = Registry.SECTIONS.map(func(s): return String(s["id"]))
	t._check(ids.has("stations_words") and ids.has("noble_words") and ids.has("stations_numbers") and ids.has("contracts_numbers"), "stations, titles, the Noble and contracts are in the Data editor")
	var tables: Array = []
	for s in Registry.SECTIONS:
		tables.append_array(s.get("tables", []))
	for tb in ["stations/LESSONS", "stations/BRACKETS", "stations/MASTER_LINES", "titles/SOCIAL", "renown/RANK_OPENS", "noble/LINES", "contracts/KINDS", "contracts/ITEMS"]:
		t._check(tables.has(tb), "%s is registered" % tb)
	var all := JSON.stringify([Stations.STATIONS, Stations.STOPS, Stations.LESSONS, Stations.DRILLS, Stations.BRACKETS, Stations.MASTER, Stations.MASTER_LINES, Stations.TEXT,
		Renown.RANKS, Renown.TITLES, Renown.TEXT, Titles.SOCIAL, Titles.GROUPS, Titles.TEXT, Noble.NOBLE, Noble.LINES, Noble.TEXT, Contracts.KINDS, Contracts.ITEMS, Contracts.TEXT,
		Charms.TEXT, Train.Outfitter.NODES]).to_lower()
	for id in ["station", "training", "tournament", "noble", "titles_social", "contracts", "contract_done", "rank_up", "renown_board"]:
		all += JSON.stringify(Entity.TIPS.get(id, {})).to_lower()
	for id in ["how_renown", "how_titles", "how_contracts", "how_tourney"]:
		all += JSON.stringify(Talk.DIALOGUE.get(id, {})).to_lower()
	var re := RegEx.create_from_string("\\b(" + "|".join(BANNED) + ")\\b")
	t._check(re.search(all) == null, "no banned words in the stations' words (%s)" % (re.search(all).get_string() if re.search(all) != null else ""))
	var readme := FileAccess.get_file_as_string("res://README.md")
	var at := readme.find("## Stations, renown, titles")
	t._check(at >= 0 and readme.substr(at, 6000).contains("Noble") and readme.substr(at, 6000).contains("Training") and not readme.contains("Boon Shrine:"), "the README explains stations, the Noble and Training (and no longer the Boon Shrine)")
	t._check(Entity.TIPS.has("noble") and Entity.TIPS.has("contracts") and Entity.TIPS.has("tournament") and Entity.TIPS.has("titles_social") and Entity.TIPS.has("rank_up") and Entity.TIPS.has("training"),
		"the Entity has first-time words for the Noble, contracts, tournaments, titles' benefits, rank-ups and Training")
	var how: Array = Talk.DIALOGUE["how"]["choices"]
	t._check(how.has("how_titles") and how.has("how_contracts") and how.has("how_tourney"), "...and 'How do titles work?', 'What are contracts?', 'How do tournaments work?' to ask")
	var ok := true
	for k in ["rail:gym", "rail:arena", "rail:noble", "rail:board", "pick:lesson", "pick:drill", "pick:bracket", "pick:title", "pick:contract", "pick:rank",
			"station_do:begin", "station_do:skip", "station_do:grant", "station_do:wear", "station_do:take", "station_do:drop"]:
		ok = ok and Help.HELP.has(k)
	t._check(ok, "every new button has the Entity's help")


# --- renown you can see ------------------------------------------------------------------

## Renown.earn, the ranks, what each gain says, the next rank's preview, a rank-up's moment.
func _renown(main) -> void:
	var prof = main.profile
	prof.renown = {}
	main.on_train = false
	main.banner = {}
	var got := Renown.earn(prof, 30, "Won a duel with Bryn")
	t._check(Renown.points(prof) == 30 and Renown.rank(prof) == 1 and got["rank_up"] == Renown.rank_name(1), "Renown.earn adds renown, and 25 reaches the second rank (%s)" % Renown.rank_name(Renown.rank(prof)))
	t._check(String(got["line"]) == "+30 renown: won a duel with Bryn", "every gain says what for (%s)" % got["line"])
	var log: Array = main.notices.log
	t._check(log.any(func(e): return String(e.get("text", "")) == "+30 renown: won a duel with Bryn" and String(e.get("kind", "")) == "renown"), "...in the feed and the Entity's log")
	t._check(String(main.banner.get("title", "")) == String(Renown.rank_words(1)[0]) and String(main.banner.get("lines", [""])[0]).contains(Renown.opens(1)[0]), "a rank-up in play is a moment: a banner saying what it opens (%s)" % main.banner.get("lines", []))
	t._check(Renown.unseen_rank(prof) < 0, "...shown once")
	t._check(Renown.next_text(prof).contains(Renown.rank_name(2)) and Renown.opens(2).size() == Renown.RANK_OPENS[2].size() and Renown.opens(2).any(func(s): return String(s).contains(String(Stations.bracket("open")["name"]))),
		"the next rank's preview: what it opens, from RANK_OPENS (%s)" % [Renown.opens(2)])
	for i in Renown.RANK_OPENS.size():
		t._check(not Renown.opens(i).is_empty(), "rank %s opens something to do" % Renown.rank_name(i))
	t._check(Renown.rank_opening("bracket", "masters") == int(Stations.bracket("masters")["rank"]) and Renown.rank_opening("bracket", "open") == int(Stations.bracket("open")["rank"]),
		"the ranks that open brackets match the brackets' own ranks")
	# On the train a rank-up waits for the page.
	main.on_train = true
	Renown.earn(prof, Renown.needed(2) - Renown.points(prof), "")
	t._check(Renown.unseen_rank(prof) == 2, "a rank reached on the train waits to be said")
	main.on_train = false
	# What a climb earns.
	var before := Renown.points(prof)
	main.climb_paid = false
	main.climb_best0 = 2
	main.floor_num = 5
	main.pay_climb()
	var want := int(Renown.CLIMB["floor"]) * 5 + int(Renown.CLIMB["best"]) * 3
	t._check(Renown.points(prof) == before + want and int(Renown.state(prof)["streak"]) == 1, "a climb's end earns renown for its floors and its new best (+%d)" % want)
	Renown.state(prof)["points"] = Renown.needed(2)  # (so the beast below stays short of the next rank: that moment would be said in the climb, not in the car)
	before = Renown.points(prof)
	Renown.on_beast(prof, "the Kraken")
	t._check(Renown.points(prof) == before + int(Renown.CLIMB["beast"]), "a beast felled earns renown")
	Renown.on_climb_end(prof, "test", 1, 5, true)
	t._check(int(Renown.state(prof)["streak"]) == 0, "a fall breaks the run of climbs without one")
	main.floor_num = 1
	await t._frames(1)


## Each medal drill's medals, from its scores.
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


# --- the station ---------------------------------------------------------------------------

## From the engine to the station, around its stops, and back.
func _travel(main) -> void:
	var menu = main.menu
	main.open_train()
	await t._frames(2)
	menu.train_car = "engine"
	menu.open("train")
	await t._frames(2)
	var lever: Array = t._car_buttons("go_station", String(Stations.STATIONS[0]["id"]))
	t._check(lever.size() == 1, "the engine has Step off for the station you're at (travel.gd: the home station at first)")
	var visits := int(Renown.state(main.profile)["visits"])
	if lever.size() == 1:
		lever[0].pressed.emit()
		await t._frames(3)
	t._check(menu.page == "station" and menu.at_station() and main.on_train and menu.station_view.visible and not menu.train_view.visible, "stepping off opens the station: its page, drawn behind")
	var ids: Array = menu.rail.buttons.map(func(b): return b.id)
	t._check(Stations.stops(menu.station_page.station).all(func(s): return ids.has(s)) and ids.has("leave_station") and not ids.has("engine"), "the rail lists the station's stops and the way back (%s)" % [ids])
	t._check(int(Renown.state(main.profile)["visits"]) == visits + 1 and Renown.on_offer(main.profile).has("newcomer"), "the stop is counted (the Newcomer's title is ready at the Noble)")
	t._check(menu.station_page.stop == "gym" and String(menu.station_page.picks.get("gym", "")) == "lesson:" + String(Stations.LESSON_ORDER[0]), "it opens on Training, on the first lesson not yet done")
	t._check(String(menu.train_page.tips.get(Train.HOME, "")).contains(Renown.opens(Renown.rank(main.profile))[0]) and Renown.unseen_rank(main.profile) < 0, "the rank reached on the climb is said at the top of your car, with what it opens")
	menu.rail_pressed("arena")
	await t._frames(2)
	t._check(menu.station_page.stop == "arena" and menu.rail_item() == "arena", "choosing a stop on the rail shows it")
	menu._cycle(1)
	await t._frames(2)
	t._check(menu.station_page.stop == "noble", "Q / E move to the next stop")
	menu.open("climber")
	await t._frames(2)
	t._check(menu.rail.buttons.any(func(b): return b.id == "gym"), "the climber screen opened at the station keeps the station's rail")
	menu.close()
	await t._frames(2)
	t._check(menu.page == "station", "...and closing it goes back to the station")
	var next_rk := Renown.rank(main.profile) + 1
	Renown.earn(main.profile, Renown.needed(next_rk) - Renown.points(main.profile), "")
	menu.go_station(menu.station_page.station, "board")
	await t._frames(2)
	var rank_row: bool = t._all_labels(menu.box).any(func(l): return l.text.contains(Renown.opens(next_rk)[0]))
	t._check(rank_row and Renown.unseen_rank(main.profile) < 0, "a rank reached at the station is said at the top of its page, with what it opens")
	var rk := Renown.rank(main.profile)
	t._check(String(menu.station_page.picks.get("board", "")) == "rank:%d" % (rk + 1) and t._all_labels(menu.box).any(func(l): return l.text.contains(Renown.opens(rk + 1)[0])),
		"the Renown Board opens on the next rank and says what it opens")
	menu.rail_pressed("leave_station")
	await t._frames(2)
	t._check(menu.page == "train" and menu.train_car == "engine" and not menu.at_station() and menu.train_view.visible, "Back to the train: on the train again, in the engine")
	menu.go_station(String(Stations.STATIONS[0]["id"]), "gym")
	await t._frames(2)
	t._check(menu.page == "station" and menu.station_page.stop == "gym", "go_station opens a stop directly")


## Every lesson, run in the arena, is done and remembered; one skipped; the set pays once.
func _lessons(main) -> void:
	var prof = main.profile
	var menu = main.menu
	var arena = main.arena
	var station: String = menu.station_page.station
	Renown.state(prof)["lessons"] = {}
	var pts0 := Renown.points(prof)
	var order: Array = Stations.LESSON_ORDER.duplicate()
	var skipped: String = order.pop_back()
	for id in order:
		var d: Dictionary = Stations.LESSONS[id]
		var why: String = arena.start(Stations.event("lesson", id, station))
		await t._frames(3)
		var p = main.player
		t._check(why == "" and arena.on and not main.on_train and not menu.is_open() and p.is_physics_processing(), "%s: the lesson begins in the arena" % id)
		t._check(main.hud.status_chips().any(func(c): return String(c.get("id", "")) == "arena" and String(c.get("text", "")).begins_with(String(d["name"]))), "%s: the line at the top says what to do" % id)
		match String(d["kind"]):
			"run":
				for at in arena.posts.duplicate():
					p.global_position = at
					await t.physics_frame
					await t.physics_frame
			"roll":
				for i in int(d["need"]):
					p.roll_t = 0.3
					await t.physics_frame
					await t.physics_frame
					p.roll_t = 0.0
					await t.physics_frame
					await t.physics_frame
			"jump":
				for i in int(d["need"]):
					p.jump_t = 0.3
					await t.physics_frame
					await t.physics_frame
					p.jump_t = 0.0
					await t.physics_frame
					await t.physics_frame
			"strike", "shoot":
				t._check(arena.dummies.size() == int(d.get("dummies", 2)), "%s: its dummies stand ready" % id)
				var was: String = p.weapon
				p.weapon = "shortbow" if String(d["kind"]) == "shoot" else "sword"
				for i in int(d["need"]):
					arena.dummies[i % arena.dummies.size()].take_hit(1.0, Vector2.ZERO)
				await t.physics_frame
				await t.physics_frame
				await t.physics_frame
				p.weapon = was
			"parry":
				for i in int(d["need"]):
					p.on_parry.emit(null, false)
			"belt":
				t._check(p.item_count("tonic") >= 1, "belt: its items are put on the belt")
				p.item_sel = "draught" if p.item_count("draught") > 0 else "tonic"
				p.use_item()
			"cast":
				p.spells_cast += 1
				await t.physics_frame
				await t.physics_frame
				arena.dummies[0].take_hit(1.0, Vector2.ZERO)
			"cure":
				t._check(float(p.states.get(String(d["state"]), 0.0)) > 0.0, "cure: the state is on you")
				p.item_sel = "tonic"
				p.use_item()
			"wall":
				var cr = main.cracks
				t._check(cr.list.size() == 1 and main.is_solid(cr._centre(arena.WALL_CELL)), "wall: a cracked wall, solid until broken")
				cr.crumble(cr.list[0])
			"ward":
				var ob = main.objective
				t._check(ob.kind == "braziers" and ob.pieces.size() == int(d["pieces"]) and main.hud.goal_line() != "", "ward: the floor's task, with its line at the top (%s)" % main.hud.goal_line())
				for pc in ob.pieces:
					ob._piece_done(pc)
		await _wait_done(main)
		t._check(Stations.lesson_state(prof, id) == 1, "%s: done, and remembered" % id)
		t._check(menu.page == "station" and menu.station_page.stop == "gym" and not menu.station_page.lines.is_empty() and main.on_train, "...and it's back at Training, the result on its card")
	t._check(Renown.points(prof) == pts0, "no renown until the whole set is done")
	# A lesson can be skipped from its card; the set then pays.
	menu.go_station(station, "gym")
	await t._frames(2)
	var tile: Array = _station_buttons(menu, "pick", "lesson:" + skipped)
	if tile.size() == 1:
		tile[0].pressed.emit()
		await t._frames(1)
	var skip: Array = _station_buttons(menu, "station_do", "skip")
	t._check(skip.size() == 1, "a lesson not done has Skip on its card")
	if skip.size() == 1:
		skip[0].pressed.emit()
		await t._frames(2)
	t._check(Stations.lesson_state(prof, skipped) == 2 and Stations.lessons_done(prof) and Renown.points(prof) == pts0 + Stations.LESSON_REWARD, "skipped is remembered too, and the finished set pays %d renown once" % Stations.LESSON_REWARD)
	Stations.finish_lesson(prof, skipped, 1)
	t._check(Renown.points(prof) == pts0 + Stations.LESSON_REWARD, "...only once")
	t._check(Renown.on_offer(prof).has("trainee"), "the Trainee's title is ready at the Noble")
	# A lesson lost: time runs out, nothing is marked.
	Renown.state(prof)["lessons"].erase("move")
	arena.start(Stations.event("lesson", "move", station))
	await t._frames(2)
	arena.t = float(Stations.LESSONS["move"]["time"])
	await _wait_done(main)
	t._check(Stations.lesson_state(prof, "move") == 0 and menu.page == "station", "a lesson not finished in time isn't marked done")
	Stations.finish_lesson(prof, "move", 1)


## A medal drill: its fee, its medal; an extra drill only for a title with Training's benefit.
func _drills(main) -> void:
	var prof = main.profile
	var menu = main.menu
	var arena = main.arena
	var station: String = menu.station_page.station
	prof.add_crystal("fire", 200.0)
	Renown.state(prof)["worn"] = ""
	var held: float = prof.crystals_held()
	var why: String = arena.start(Stations.event("drill", "parry", station))
	t._check(why == "" and prof.crystals_held() == held - Stations.fee(prof, "drill", "parry") and Stations.fee(prof, "drill", "parry") > 0, "a medal drill takes its small fee")
	await t._frames(2)
	for i in int(Stations.DRILLS["parry"]["medals"][2]):
		main.player.on_parry.emit(null, false)
	arena.t = float(Stations.DRILLS["parry"]["time"])
	await _wait_done(main)
	t._check(int(Renown.state(prof)["drills"].get("parry", 0)) == 3, "...and the score earns its medal")
	t._check(not Stations.drill_unlocked(prof, "glass") and Stations.why_not(prof, "drill", "glass") == Stations.TEXT["extra"], "an extra drill is closed without a title for it")
	# A fall in a drill ends it with no medal (and no fall).
	Renown.state(prof)["drills"].erase("rush")
	arena.start(Stations.event("drill", "rush", station))
	await t._frames(2)
	var p = main.player
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.parry_t = 0.0
	p.receive_attack(99999.0, null)
	t._check(not p.dead and p.hp >= 1.0, "a blow that would fell you in the arena doesn't")
	await _wait_done(main)
	t._check(int(Renown.state(prof)["drills"].get("rush", 0)) == 0 and menu.page == "station", "...the drill is lost instead")


## A bracket: entered, its climbers yielding round by round, won; then lost
## by being knocked down (never killed); then given up from the pause menu.
func _tourney(main) -> void:
	var prof = main.profile
	var arena = main.arena
	var menu = main.menu
	prof.climbs = 0  # (the travelling Tournament Manager is where this station is: tournaments.gd ROTATION)
	var station: String = load("res://scripts/tournaments.gd").here(prof)
	menu.go_station(station, "arena")
	await t._frames(2)
	prof.add_crystal("fire", 200.0)
	var r := Renown.state(prof)
	r["tiers"] = {}
	r["rounds"] = {}
	var held: float = prof.crystals_held()
	var pts := Renown.points(prof)
	var b: Dictionary = Stations.bracket("novice")
	var pz := Stations.prize(prof, "novice", station)
	var why: String = arena.start(Stations.event("tourney", "novice", station))
	t._check(why == "" and prof.crystals_held() == held - Stations.fee(prof, "tourney", "novice"), "a bracket takes its entry fee")
	var k0: float = prof.crystal_total(String(pz["kind"]))
	var rounds: Array = arena.ev["rounds"]
	var climbers := 0
	var creatures := 0
	for i in rounds.size():
		await t._until(func(): return arena.opp != null or not arena.round_mobs.is_empty() or arena.done, 5.0)
		if not arena.round_mobs.is_empty():
			creatures += 1  # (the location's creatures: the first round, tournaments.gd)
			for e in arena.round_mobs.duplicate():
				if is_instance_valid(e):
					e.take_hit(999999.0, Vector2.ZERO)
			await t._frames(3)
			continue
		if arena.opp == null:
			break
		var o = arena.opp
		if o.get("bonds_held") != null and (o.bonds_held as Array).size() == int(rounds[i]["marks"]) and o.kind == "rival":
			climbers += 1
		o.take_hit(999999.0, Vector2.ZERO)
		await t._frames(3)
	t._check(creatures == 1 and climbers == rounds.size() - 1, "the first round is the location's creatures, each other round another climber with marks (%d, %d of %d)" % [creatures, climbers, rounds.size()])
	await _wait_done(main)
	t._check(Stations.bracket_won(prof, "novice") and Stations.best_rounds(prof, "novice") == rounds.size(), "beating all three wins the bracket")
	var gain := int(b["round_renown"]) * rounds.size() + int(pz["renown"])
	t._check(Renown.points(prof) == pts + gain and prof.crystal_total(String(pz["kind"])) >= k0 + float(pz["crystals"]), "...for renown (+%d) and crystals (+%d, and what the marks couldn't take of the essence gathered condenses too): got +%d renown, +%.1f crystals" % [gain, int(pz["crystals"]), Renown.points(prof) - pts, prof.crystal_total(String(pz["kind"])) - k0])
	t._check(menu.station_page.lines.any(func(l): return String(l).contains(String(b["name"]))) and Renown.on_offer(prof).has("contender"), "the win is said on its card, and the Noble has a title for it")
	# Knocked down: you yield, never die, and the bracket ends.
	pts = Renown.points(prof)
	arena.start(Stations.event("tourney", "novice", station))
	await t._until(func(): return arena.opp != null or not arena.round_mobs.is_empty(), 5.0)
	var p = main.player
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.parry_t = 0.0
	p.receive_attack(99999.0, null)
	t._check(not p.dead and p.hp >= 1.0, "a blow that would fell you in the tournament doesn't: you yield")
	await _wait_done(main)
	t._check(Stations.bracket_wins(prof, "novice") == 1 and Renown.points(prof) == pts and menu.page == "station" and menu.station_page.lines.any(func(l): return String(l).contains("round 1")), "...losing pays nothing more, and says the round")
	# Giving up from the pause menu.
	arena.start(Stations.event("tourney", "novice", station))
	await t._frames(2)
	menu.open("pause")
	await t._frames(2)
	var give: Array = t._all_buttons(menu.box).filter(func(bb): return bb.has_meta("give_up"))
	t._check(give.size() == 1, "the pause menu in the arena can give up")
	if give.size() == 1:
		give[0].pressed.emit()
	await t._frames(3)
	t._check(not arena.on and menu.page == "station", "...back to the station")
	t._check(not Stations.bracket_open(prof, "champions") and Stations.why_not(prof, "tourney", "champions").contains(Renown.rank_name(int(Stations.bracket("champions")["rank"]))), "a higher bracket waits for its rank")
	# The Masters' last round is your own reflection.
	var ev := Stations.event("tourney", "masters", station)
	t._check(bool(ev["rounds"][-1].get("mirror", false)), "the Masters' Bracket ends with your reflection")


# --- the Noble -----------------------------------------------------------------------------

## The Noble grants a title when renown allows, shows what it gives, and it can be worn.
func _noble(main) -> void:
	var prof = main.profile
	var menu = main.menu
	var r := Renown.state(prof)
	r["titles"] = []
	r["worn"] = ""
	t._check(not Renown.grant(prof, "champion") and Renown.worn_title(prof) == "", "a title whose rank and deed aren't done can't be granted")
	menu.go_station(menu.station_page.station, "noble")
	await t._frames(2)
	t._check(t._all_labels(menu.box).any(func(l): return l.text.contains(Noble.TEXT["titles"])) and not _station_buttons(menu, "pick", "title:newcomer").is_empty(), "the Noble's stop lists the titles")
	var tile: Array = _station_buttons(menu, "pick", "title:newcomer")
	if tile.size() == 1:
		tile[0].pressed.emit()
		await t._frames(1)
	var words: Array = t._all_labels(menu.station_page.card).map(func(l): return l.text)
	var gives: Array = Titles.lines("newcomer")
	t._check(not gives.is_empty() and gives.all(func(g): return words.has(g)), "a title's card shows what it gives (%s)" % [gives])
	t._check(words.any(func(w): return w.contains(Renown.rank_name(0))) and words.any(func(w): return w.contains(String(Renown.TITLES["newcomer"]["deed"]))), "...and what it needs: a rank and a deed")
	var grant: Array = _station_buttons(menu, "station_do", "grant")
	t._check(grant.size() == 1, "...and, once renown allows, Be named")
	if grant.size() == 1:
		grant[0].pressed.emit()
		await t._frames(3)
	var name := Renown.title_name("newcomer")
	t._check(Renown.has_title(prof, "newcomer") and Renown.worn_title(prof) == name and menu._climber_line().begins_with(name), "granted and worn: it shows under the name in the book (%s)" % menu._climber_line())
	t._check(menu.rail.ident.custom_minimum_size.y > 100.0, "...and the rail makes room for it under the name")
	# A title the rank hasn't reached: no grant button, and the card says why.
	menu.go_station(menu.station_page.station, "noble")
	await t._frames(2)
	tile = _station_buttons(menu, "pick", "title:paragon")
	if tile.size() == 1:
		tile[0].pressed.emit()
		await t._frames(1)
	t._check(_station_buttons(menu, "station_do", "grant").is_empty() and t._all_labels(menu.station_page.card).any(func(l): return l.text.contains(Renown.rank_name(int(Renown.TITLES["paragon"]["rank"])))), "a title out of reach shows its rank and no grant")
	t._check(Renown.TITLE_ORDER.all(func(id): return Renown.TITLES.has(id) and Renown.TITLES[id].has("rank") and not Titles.lines(id).is_empty()), "every title has a rank and benefits")


## Titles' benefits apply: the outfitter, rival climbers, Training, tournament masters.
func _benefits(main) -> void:
	var prof = main.profile
	var r := Renown.state(prof)
	r["titles"] = Renown.TITLE_ORDER.duplicate()
	var none_d := Train.discount(prof) if Renown.wear(prof, "") else 0.0
	t._check(Titles.rival_terms(prof) == {"friendly": false, "trade_ask": 1.0, "team": 1.0, "toll": 1.0, "bets": false}, "no title: climbers treat you plainly")
	Renown.wear(prof, "helping_hand")
	var terms := Titles.rival_terms(prof)
	t._check(terms["friendly"] and terms["trade_ask"] < 1.0, "the Helping Hand: climbers are friendlier to trade with (the Dining car's hook: titles.gd rival_terms)")
	t._check(is_equal_approx(Train.discount(prof) - none_d, float(Titles.SOCIAL["helping_hand"]["outfitter"]["discount"])), "...and the outfitter takes a little off")
	t._check(main.rivals.terms()["friendly"] and main.rivals._weight("trade") == float(main.rivals.MEETINGS["trade"]["weight"]), "rival climbers read the worn title's terms")
	Renown.wear(prof, "shieldmate")
	t._check(main.rivals._weight("team") > float(main.rivals.MEETINGS["team"]["weight"]), "Shieldmate: offers to team up come more often")
	var fee0 := Stations.fee(prof, "drill", "pack")
	Renown.wear(prof, "trainee")
	t._check(Stations.fee(prof, "drill", "pack") == 0 and fee0 > 0 and Stations.drill_unlocked(prof, "glass"), "the Trainee: medal drills are free and the extra drills open")
	var keep := int(r["points"])
	r["points"] = Renown.needed(1)
	Renown.wear(prof, "")
	var closed := not Stations.bracket_open(prof, "open")
	Renown.wear(prof, "contender")
	t._check(closed and Stations.bracket_open(prof, "open") and Stations.bracket_early(prof, "open") and Stations.fee(prof, "tourney", "novice") < int(Stations.bracket("novice")["fee"]),
		"the Contender: tournament masters open the Open Bracket sooner, and entry costs less")
	Renown.wear(prof, "duelist")
	var plain := Stations.prize(prof, "open")
	t._check(int(plain["renown"]) > int(Stations.bracket("open")["renown"]), "the Duelist: bigger prizes")
	Renown.wear(prof, "beastfeller")
	var rare := 0
	for i in 20:
		rare += 1 if Gear.rarity_rank(Gear.rarity(Train.roll_today(prof))) >= Gear.rarity_rank("rare") else 0
	t._check(rare == 20, "Beastfeller: today's piece comes a rarity higher (%d of 20 Rare or better)" % rare)
	Renown.wear(prof, "stairworn")
	var fine := 0
	for g in Train.roll_outfit(prof):
		fine += 1 if Gear.rarity_rank(Gear.rarity(g)) >= Gear.rarity_rank("fine") else 0
	t._check(fine >= 1, "the Stairworn: a Fine piece kept on the rail")
	r["points"] = keep
	Renown.wear(prof, "")
	r["titles"] = ["newcomer", "trainee", "contender"]


## Charm rewards for rank: recipes a rank teaches, cheaper refills.
func _charm_rewards(main) -> void:
	var prof = main.profile
	var r := Renown.state(prof)
	var keep := int(r["points"])
	r["points"] = 0
	r["recipes"] = []
	t._check(not Charms.recipe_known(prof, "keepers_purse") and Charms.recipe_known(prof, "lucky_knot"), "a locked recipe isn't known at the first rank; an ordinary one is")
	t._check(Bench.craft_why(prof, "keepers_purse") != "" , "...and the bench won't craft it (%s)" % Bench.craft_why(prof, "keepers_purse"))
	var g := Gear.make("mending_bead")
	g["charge"] = 0
	var full_cost := Charms.refill_amount(g)
	t._check(Charms.refill_amount(g, prof) == full_cost, "no cut on refills at the first rank")
	r["points"] = Renown.needed(Renown.rank_opening("recipe", "keepers_purse"))
	t._check(Charms.recipe_known(prof, "keepers_purse"), "its rank teaches it")
	r["points"] = Renown.needed(2)
	t._check(Charms.refill_amount(g, prof) < full_cost and Bench.refill_cost(g, prof).values()[0] == Charms.refill_amount(g, prof), "from Known, charm refills cost less (%d, not %d)" % [Charms.refill_amount(g, prof), full_cost])
	t._check(Charms.learn(prof, "gale_charm") and Charms.recipe_known(prof, "gale_charm") and not Charms.learn(prof, "gale_charm"), "a contract's recipe is learned once")
	r["points"] = keep


# --- contracts -------------------------------------------------------------------------------

## Contracts: offered, taken, tracked in play (the line at the top, the log),
## done and paid: a thing retrieved, a floor reached, monsters slain. The
## thing to retrieve is always where you can walk, and the stair stays open.
func _contracts(main) -> void:
	var prof = main.profile
	var menu = main.menu
	var c := Contracts.data(prof)
	c["active"] = []
	c["visit"] = -1
	c["done"] = 0
	Renown.state(prof)["points"] = Renown.needed(1)
	var offers: Array = Contracts.offers(prof)
	t._check(offers.size() == int(Contracts.RULES["offers"]) and offers.all(func(o): return Contracts.kinds_open(prof).has(String(o["kind"]))), "the Noble offers contracts of the kinds your rank opens (%s)" % [offers.map(func(o): return o["kind"])])
	menu.go_station(menu.station_page.station, "noble")
	await t._frames(2)
	var tile: Array = _station_buttons(menu, "pick", "contract:" + String(offers[0]["id"]))
	if tile.size() == 1:
		tile[0].pressed.emit()
		await t._frames(1)
	var take: Array = _station_buttons(menu, "station_do", "take")
	t._check(tile.size() == 1 and take.size() == 1 and t._all_labels(menu.station_page.card).any(func(l): return l.text == Contracts.goal_of(offers[0])), "a contract's card says what to do, what it pays, and Take")
	if take.size() == 1:
		take[0].pressed.emit()
		await t._frames(2)
	t._check(Contracts.active(prof).size() == 1 and Contracts.take(prof, String(Contracts.offers(prof)[0]["id"])) != "", "taken; one at a time at this rank")
	var drop: Array = _station_buttons(menu, "station_do", "drop")
	t._check(drop.size() == 1, "a held contract can be given up")
	if drop.size() == 1:
		drop[0].pressed.emit()
		await t._frames(2)
	t._check(Contracts.active(prof).is_empty(), "...given up")
	menu.rail_pressed("leave_station")
	await t._frames(2)
	# In play: a retrieve, a reach and a slay, all at once (as if at Respected).
	Renown.state(prof)["points"] = Renown.needed(3)
	main.depart("kraken")
	await t._frames(2)
	for e in main.enemies():
		e.queue_free()
	main.first_climb = false
	var tid: String = main.tower
	var ret := Contracts.roll(prof, "retrieve")
	ret["tower"] = tid
	ret["floor"] = 2
	var rch := Contracts.roll(prof, "reach")
	rch["tower"] = tid
	rch["floor"] = 3
	c["active"] = [ret, rch]
	main._start_floor(2)
	await t._frames(2)
	var it: Dictionary = main.contracts.item
	t._check(not it.is_empty() and String(it["id"]) == String(ret["id"]), "the thing to retrieve waits on its floor")
	var chips: Array = main.hud.status_chips()
	t._check(chips.filter(func(ch): return String(ch.get("id", "")).begins_with("contract:")).size() == 2 and chips.any(func(ch): return String(ch.get("text", "")) == Contracts.status_of(ret)), "each contract held has its line at the top of the screen")
	var live := Reach.live_check(main, main.player_start)
	t._check(not live.get("checked", false) or (live["stair"] and Reach.near_reached(live["reach"], live["size"], it["pos"])), "...somewhere you can walk to, and the stair is still in reach")
	var renown0 := Renown.points(prof)
	main.camp_choosing = false
	main.rivals.list.clear()  # (nobody to talk to on the way)
	main.player.global_position = it["pos"]
	await t._until(func(): return main.contracts.item.is_empty(), 1.0)
	t._check(bool(Contracts.find(prof, String(ret["id"])).get("carried", false)) and main.notices.log.any(func(e): return String(e.get("kind", "")) == "contract"), "walking onto it picks it up, said in the log")
	main._start_floor(3)
	await t._frames(2)
	t._check(Contracts.active(prof).is_empty() and int(c["done"]) == 2, "taking the stair with it finishes the retrieve; arriving on floor 3 finishes the reach")
	t._check(Renown.points(prof) == renown0 + int(ret["renown"]) + int(rch["renown"]), "...each paid renown (+%d)" % (int(ret["renown"]) + int(rch["renown"])))
	t._check(main.notices.log.any(func(e): return String(e.get("text", "")).begins_with("+%d renown: contract" % int(ret["renown"]))), "...and every gain says what for")
	# Slay: monsters of one kind, wherever.
	var sl := Contracts.roll(prof, "slay")
	sl["monster"] = "slime"
	sl["need"] = 2
	c["active"] = [sl]
	for i in 2:
		var e = main.spawn_enemy("slime", main.player.global_position + Vector2(80, 0))
		await t._frames(1)
		t._slay(e)
		await t._frames(2)
	t._check(Contracts.active(prof).is_empty() and int(c["done"]) == 3, "slaying enough of its kind finishes a slay contract")
	t._check(Renown.deed_done(prof, Renown.TITLES["trusted"]), "three done: the Trusted's deed")
	# A fall drops the thing carried; it waits on its floor again.
	var ret2 := Contracts.roll(prof, "retrieve")
	ret2["carried"] = true
	c["active"] = [ret2]
	main.contracts.on_climb_end(true)
	t._check(not bool(ret2["carried"]) and Contracts.active(prof).size() == 1, "a fall drops a thing carried: it waits on its floor again")
	# Never blocks: across floors and towers the thing lies in reach, the stair too.
	var bad: Array = []
	for tw in ["kraken", "gryphon", "chimera", "wyvern"]:
		main.tower = tw
		main._apply_tower_look()
		for n in [2, 3, 4, 5]:
			var o := Contracts.roll(prof, "retrieve")
			o["tower"] = tw
			o["floor"] = n
			c["active"] = [o]
			main._start_floor(n)
			await t._frames(1)
			var item: Dictionary = main.contracts.item
			var lc := Reach.live_check(main, main.player_start)
			if item.is_empty():
				bad.append("%s %d: no item" % [tw, n])
			elif main.in_chasm(item["pos"]) or main.traps.any(func(tr): return Vector2(tr.get("pos", Vector2.INF)).distance_to(item["pos"]) < 30.0):
				bad.append("%s %d: on a chasm or a trap" % [tw, n])
			elif lc.get("checked", false) and not (lc["stair"] and Reach.near_reached(lc["reach"], lc["size"], item["pos"])):
				bad.append("%s %d" % [tw, n])
			for e in main.enemies():
				e.queue_free()
	t._check(bad.is_empty(), "the thing to retrieve is always in reach and never blocks the stair (%s)" % [bad])
	c["active"] = []
	main.contracts.on_floor(1)
	main.await_tower()
	main.open_train()
	await t._frames(2)


## The outfitter's upgrade tree opens with renown (outfitter.gd: its nodes
## are bought; tests/parts/outfitter.gd has the rest).
func _outfitter(main) -> void:
	var prof = main.profile
	var O = Train.Outfitter
	var low = ProfileScript.new()
	low.saving = false
	t._check(Train.rack_size(low) == Train.RACK_SIZE and Train.supply_price(low, "scroll")[1] == int(Train.ANY_PRICE["scroll"]), "with no renown: the rack and the scroll as they were")
	t._check(O.ORDER.all(func(id): return O.status(low, id) == "locked"), "with no renown, every node of his tree is locked")
	Renown.state(prof)["worn"] = ""
	Renown.earn(prof, Renown.needed(Renown.RANKS.size() - 1), "")
	t._check(O.ORDER.filter(func(id): return O.status(prof, id) == "open").size() == O.BRANCHES.size(), "the top rank opens each branch's first node (the rest follow in turn)")
	await t._frames(1)


## The station's pages at a phone's size, and a narrow one: nothing runs off
## the screen across, every stop's tiles and card are there.
func _phone(main) -> void:
	var menu = main.menu
	var was: Vector2i = t.root.size
	var keep_ui: String = menu.settings["ui_size"]
	t.root.size = Vector2i(915, 412)
	main.touch._set_active(true)
	if not menu.at_station():
		menu.go_station(String(Stations.STATIONS[0]["id"]), "gym")
		await t._frames(2)
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
	menu.go_station(menu.station_page.station, "arena")
	await t._frames(3)
	var tile: Array = _station_buttons(menu, "pick", "bracket:open")
	if tile.size() == 1:
		menu.scroll.ensure_control_visible(tile[0])
		await t._frames(2)
		await t._tap_at(tile[0].get_global_rect().get_center())
	t._check(tile.size() == 1 and menu.station_page.picks.get("arena", "") == "bracket:open", "a tap on a bracket shows its card")
	main.touch._set_active(false)
	menu.settings["ui_size"] = keep_ui
	main.apply_view_scale()
	t.root.size = was
	await t._frames(2)
