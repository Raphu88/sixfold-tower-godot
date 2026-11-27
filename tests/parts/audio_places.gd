extends RefCounted
## Where each loop plays, and at what level (the owner heard dripping water
## over the music until the Settings page was opened). The old dripping
## cavern loop is gone, and the Kraken's ambience has no drip in it; the
## saved Music level reaches every loop from the start (a fade-in's tween
## used to finish at full level and override it); each place has its own
## ambience or none (music.gd AMBIENCE: none on the title, the opening, a new
## climber's pages, story moments and in the stations); only one loop is
## heard once a crossfade is done, however often the place changes; the
## music and ambience carry on across a new floor; the whistle only blows
## when a train pulls in. Run by smoke_test.gd (_part_tests).

const Bank := preload("res://scripts/sound_bank.gd")
const Music := preload("res://scripts/music.gd")
const MenuScript := preload("res://scripts/menu.gd")
const StartPages := preload("res://scripts/start_pages.gd")
const Stations := preload("res://scripts/stations.gd")

var t
var main
var A


func run(smoke) -> void:
	t = smoke
	print("audio places: no dripping, saved levels from the start, one ambience per place")
	_no_dripping()
	await _saved_levels()
	main = t.main
	A = main.audio
	A.director_on = false
	await _places()
	await _one_at_a_time()
	await _whistle()
	await _live_director()
	await _carries_on()
	A = t.main.audio
	A.director_on = true


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## The loops playing under the music now (children of audio.gd).
func _ambience_players() -> Array:
	var out: Array = []
	for c in A.get_children():
		if c is AudioStreamPlayer and is_instance_valid(c) and c.playing and c.stream != null and "ambience" in String(c.stream.resource_path).get_file():
			out.append(c)
	return out


func _heard() -> int:
	return _ambience_players().filter(func(p): return p.volume_db > -79.0).size()


func _no_dripping() -> void:
	_check(not Bank.MUSIC.has("ambience") and not FileAccess.file_exists("res://assets/audio/music/ambience.ogg"), "the old default ambience (the dripping cavern loop) is gone from the game")
	var cavern := false
	for k in Bank.MUSIC:
		cavern = cavern or "cavern" in String(Bank.MUSIC[k]) or String(Bank.MUSIC[k]).get_file() == "ambience.ogg"
	_check(not cavern, "...nothing in the sound bank plays it")
	var build := FileAccess.get_file_as_string("res://tools/build_audio.py")
	var fetch := FileAccess.get_file_as_string("res://tools/fetch_audio_sources.sh")
	_check(build != "" and not "dark_cavern" in build and not "drip/" in build and not "atmosbasement" in fetch and not "dark_cavern" in fetch,
		"...and nothing builds or fetches a drip or the cavern (the Kraken's flooded halls lap and bubble instead)")
	for place in Music.AMBIENCE:
		var want := String(Music.AMBIENCE[place])
		_check(want in ["", "tower"] or Bank.MUSIC.has("ambience_" + want), "the %s's ambience is one that exists (%s)" % [place, want if want != "" else "none"])


## The saved Music level is on every loop before Settings is ever opened.
func _saved_levels() -> void:
	var keep: float = float(MenuScript.settings["music"])
	MenuScript.settings["music"] = 0.3
	await t._fresh_main()
	var a = t.main.audio
	_check(absf(a.music_level - 0.3) < 0.01 and t.main.menu.page != "settings", "at launch the saved Music level is applied without opening Settings (%.2f)" % a.music_level)
	var tr: Dictionary = a.tracks.get(String(Music.MOODS[a.mood]["track"]), {})
	var p = tr.get("player")
	var want := float(tr.get("db", 0.0)) + linear_to_db(0.3)
	_check(p != null and absf(p.volume_db - want) < 0.6, "...the music plays at it from the start (%.1f dB, wants %.1f)" % [p.volume_db if p != null else 0.0, want])
	# A loop that fades in while the level changes (the scene starting: the
	# old fade-in's tween ended at full level and overrode the slider).
	a.director_on = false
	a.set_levels(1.0, a.sound_level)
	a.set_ambience("", 0.0)
	a.set_ambience("kraken", 0.3)
	a.set_levels(0.3, a.sound_level)
	await t._wait(0.6)
	var amb_want: float = a.AMBIENCE_DB + linear_to_db(0.3)
	_check(a.ambience_key == "ambience_kraken" and absf(a.ambience.volume_db - amb_want) < 0.3,
		"...and the ambience ends its fade-in at the saved level, not full (%.1f dB, wants %.1f)" % [a.ambience.volume_db, amb_want])
	a.set_levels(0.0, a.sound_level)
	_check(a.ambience.volume_db <= -79.0, "...the slider at zero silences it")
	MenuScript.settings["music"] = keep
	a.set_levels(keep, a.sound_level)
	a.director_on = true


## Each place has its loop, or none.
func _places() -> void:
	var M = main.menu
	M.close()
	await t._frames(1)
	A.update_ambience(0.0)
	_check(Music.ambience_place(main) == "climb" and A.ambience_key == "ambience_" + String(main.tower) and _heard() == 1, "in a tower: its own ambience (%s)" % A.ambience_key)
	M.open("title")
	await t._frames(1)
	A.update_ambience(0.0)
	_check(A.ambience_key == "" and _heard() == 0, "the title: music alone, no ambience (%s)" % A.ambience_key)
	M.open("intro")
	await t._frames(1)
	A.update_ambience(0.0)
	_check(Music.ambience_place(main) == "title" and A.ambience_key == "" and _heard() == 0, "the opening: no ambience")
	StartPages.begin_start(M)
	await t._frames(1)
	A.update_ambience(0.0)
	_check(M.page == "create_name" and A.ambience_key == "" and _heard() == 0, "a new climber's pages: no ambience (%s)" % M.page)
	StartPages.reset()
	M.open("title")
	await t._frames(1)
	M.close()
	await t._frames(1)
	# A story moment: the story track alone.
	var mk = main.makers
	mk.interrupt_chance = 0.0
	mk.start_meeting("marks")
	A.update_ambience(0.0)
	_check(Music.ambience_place(main) == "story" and A.ambience_key == "", "a Maker's meeting: the story track alone")
	mk.end_meeting({})
	await t._frames(1)
	A.update_ambience(0.0)
	_check(A.ambience_key == "ambience_" + String(main.tower), "...and after it, the tower's ambience again")
	# The station's arena (a room of the event's tower) and the practice room.
	var ar = main.arena
	var ar_was: bool = ar.on
	ar.on = true
	_check(Music.ambience_of(main) == String(main.tower), "the station's arena: its tower's ambience")
	var ev_was = ar.ev
	ar.ev = {"car": "dining"}
	_check(Music.ambience_of(main) == "train", "an Arena car duel: the train's")
	ar.ev = ev_was
	ar.on = ar_was
	var pr = main.practice
	var pr_was: bool = pr.on
	pr.on = true
	_check(Music.ambience_of(main) == "", "the practice room: no ambience")
	pr.on = pr_was
	# The train and a station.
	main.open_train()
	await t._frames(2)
	if M.page != "train":
		M.open("train")
		await t._frames(2)
	A.update_ambience(0.0)
	_check(A.ambience_key == "ambience_train" and _heard() == 1, "the train: its own ambience (%s)" % A.ambience_key)
	M.go_station(String(Stations.STATIONS[0]["id"]), "noble", "", [], false)
	await t._frames(2)
	A.update_ambience(0.0)
	_check(M.at_station() and A.ambience_key == "" and _heard() == 0, "a station: no ambience (no city loop yet), not the train's")
	M.station_page.station = ""
	M.open("train")
	await t._frames(1)
	A.update_ambience(0.0)
	_check(A.ambience_key == "ambience_train", "...and back on the train, the train's")


## However often the place changes, one loop is heard once a fade is done,
## and the old ones are stopped and gone.
func _one_at_a_time() -> void:
	A.set_ambience("", 0.0)
	await t._frames(1)
	for place in ["kraken", "train", "gryphon", "", "wyvern", "train", "kraken"]:
		A.set_ambience(place, 0.3)
		_check(_ambience_players().size() <= 2, "switching to %s mid-fade: at most two loops at once (%d)" % [place if place != "" else "none", _ambience_players().size()])
		await t._frames(1)
	await t._wait(0.6)
	await t._frames(2)
	_check(_heard() == 1 and _ambience_players().size() == 1 and A.ambience_key == "ambience_kraken" and A.ambience_heard() == 1,
		"...and after it, only the last one plays (%d playing)" % _ambience_players().size())
	var players := 0
	for c in A.get_children():
		if c is AudioStreamPlayer and not c in A.players:
			players += 1
	_check(players <= A.tracks.size() + 2, "the old loops' players are freed, not left lying silent (%d besides the voices)" % players)
	A.set_ambience("", 0.3)
	await t._wait(0.6)
	await t._frames(2)
	_check(_ambience_players().is_empty(), "leaving for a place with none: nothing lingers")


## The whistle: as the train pulls in, not walking back from the arena or
## for a new climber who never rode it.
func _whistle() -> void:
	var M = main.menu
	var keep: float = A.sound_level
	A.sound_level = 1.0
	M.station_page.station = ""
	A.last_played.erase("train_whistle")
	M.go_station(String(Stations.STATIONS[0]["id"]), "", "", [], false)
	_check(A.playing_count("train_whistle") == 0, "back from the station's arena: no whistle (the train never left)")
	M.station_page.station = ""
	M.go_station(String(Stations.STATIONS[0]["id"]))
	_check(A.playing_count("train_whistle") == 1, "pulling in to a station: the whistle")
	var src := FileAccess.get_file_as_string("res://scripts/arena.gd") + FileAccess.get_file_as_string("res://scripts/start_pages.gd")
	_check(src.count("[], false)") >= 1 and "r.get(\"lines\", []), false)" in src, "the arena's way back and a new climber's first station pass no whistle")
	A.fade("train_whistle", 0.01)
	A.sound_level = keep
	M.station_page.station = ""
	M.open("train")
	await t._frames(1)


## As in play: the director picks the ambience by itself.
func _live_director() -> void:
	var keep: float = float(Music.RULES["check_every"])
	Music.RULES["check_every"] = 0.05
	A.set_ambience("", 0.0)
	A._look_t = 0.0
	A.director_on = true
	await _until(func(): return A.ambience_key == "ambience_train")
	_check(A.ambience_key == "ambience_train" and A.mood == "menu", "the director puts the train's ambience under the train's music (%s, %s)" % [A.ambience_key, A.mood])
	main.menu.open("title")
	await _until(func(): return A.ambience_key == "")
	_check(A.ambience_key == "", "...and none on the title")
	A.director_on = false
	Music.RULES["check_every"] = keep


## Waits until `cond` holds, or a second and a half of real time (audio.gd
## runs on the real clock, which the test's frames can outpace).
func _until(cond: Callable) -> void:
	var end := Time.get_ticks_msec() + 1500
	while not cond.call() and Time.get_ticks_msec() < end:
		await t._frames(1)


## A new floor starts the scene afresh: the music and ambience carry on.
func _carries_on() -> void:
	main.on_train = false
	main.choosing_tower = false
	main.menu.close()
	await t._frames(1)
	A.set_mood("calm", 0.0)
	A.update_ambience(0.0)
	var amb: String = A.ambience_key
	A.tracks["menu"]["player"].seek(50.0)
	await t._fresh_main()
	A = t.main.audio
	var p: AudioStreamPlayer = A.tracks.get("menu", {}).get("player")
	_check(A.mood == "calm" and p != null and p.get_playback_position() >= 49.0, "a new floor: the music carries on where it was (%s at %.0f s), not from the top" % [A.mood, p.get_playback_position() if p != null else -1.0])
	_check(amb != "" and A.ambience_key == amb and _heard() == 1, "...and so does the tower's ambience, at full, with no second loop (%s)" % A.ambience_key)
