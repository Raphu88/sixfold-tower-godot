extends RefCounted
## The music (scripts/music.gd picks, scripts/audio.gd crossfades): Rising
## Moon on the title, the train and in a climb's calm (softer there); the
## story track (six tolls, then pads that loop) for story moments, and back
## to what played before, where it left off; Great Labyrinth when a climb
## turns dangerous (a den with something alive in it, monsters awake and
## close, a lock-in, a horde, the guardian louder), settling back only once
## the danger has been gone a while. The Music slider and M still apply.
## Every track is a CC0 file that's built and imported. Run by smoke_test.gd
## (_part_tests).

const Bank := preload("res://scripts/sound_bank.gd")
const Music := preload("res://scripts/music.gd")

var t
var main
var A


func run(smoke) -> void:
	t = smoke
	print("music: each place its track, story moments, a climb's calm and danger")
	_files()
	_credits()
	await t._fresh_main()
	main = t.main
	A = main.audio
	A.director_on = false  # (the test looks for itself, with its own clock)
	A.director = Music.new()
	await _menus_and_story()
	await _climb()
	await _levels()
	await _live_director()
	A.director_on = true


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## The director looks once, `dt` seconds after its last look; the change is
## made at once (fade 0) unless `fade` says otherwise.
func _look(dt := 0.5, fade := 0.0) -> String:
	A.set_mood(A.director.update(main, dt), fade)
	return A.mood


func _files() -> void:
	var tracks := {}
	for m in Music.MOODS:
		tracks[String(Music.MOODS[m]["track"])] = true
	_check(tracks.has("menu") and tracks.has("story") and tracks.has("climb_intense"), "three tracks: menu, story and climb_intense (%s)" % ", ".join(tracks.keys()))
	_check(not Bank.MUSIC.has("music") and not FileAccess.file_exists("res://assets/audio/music/music.ogg"), "the old music track is gone")
	for name in tracks:
		var path := String(Bank.MUSIC.get(name, ""))
		var s = load(path) if path != "" else null
		var size := FileAccess.get_file_as_bytes(path).size() if path != "" else 0
		_check(s is AudioStreamOggVorbis and FileAccess.file_exists(path + ".import") and bool(s.loop), "%s is built and imported, and loops (%s)" % [name, path])
		_check(size > 200000 and size < 2600000 and s != null and s.get_length() > 110.0 and s.get_length() < 240.0,
			"...a few minutes at most, small for the web (%.1f MB, %d s)" % [size / 1000000.0, int(s.get_length()) if s != null else 0])
	# The story opens with six tolls, one every 3 s, and loops from the pads after them.
	var story = load(String(Bank.MUSIC.get("story", "")))
	_check(story != null and story.loop_offset > 18.0 and story.loop_offset < 40.0, "the story loops from after its six tolls (from %.1f s), never back to them" % (story.loop_offset if story != null else -1.0))
	var intense = load(String(Bank.MUSIC.get("climb_intense", "")))
	_check(intense != null and is_zero_approx(intense.loop_offset), "the danger track, made to loop, loops whole")
	var Reg = load("res://scripts/data_registry.gd")
	_check(String(Reg.field("music/RULES/leave_after").get("kind", "")) == "number" and String(Reg.field("music/MOODS/calm/db").get("kind", "")) == "number"
		and Reg.field("music/MOODS/calm/track").is_empty(), "the music's levels and rules are in the Data editor (the track names aren't)")


## Every track is credited, CC0, and nothing in the credits is CC-BY.
func _credits() -> void:
	var credits := FileAccess.get_file_as_string("res://CREDITS.md")
	for title in ["Fantasy: Rising Moon", "Frost in the Northern Winter", "Great Labyrinth"]:
		var line := ""
		for l in credits.split("\n"):
			if title in l:
				line = l
		_check(line != "" and "CC0" in line and "opengameart.org/content/" in line, "CREDITS.md credits \"%s\" (CC0, with its page)" % title)
	_check(not ("CC-BY" in credits or "CC BY" in credits), "no CC-BY anywhere in the credits")
	var fetch := FileAccess.get_file_as_string("res://tools/fetch_audio_sources.sh")
	_check("get_file music Rising_Moon_0.mp3" in fetch and "get_file music 01_frost_in_the_northern_winter.flac" in fetch and "get_file music great_labyrinth_bpm160.flac" in fetch,
		"the fetch script downloads all three")


func _menus_and_story() -> void:
	var M = main.menu
	M.open("title")
	await t._frames(1)
	_check(Music.place_of(main) == "menu" and _look() == "menu" and A.track_playing() == "menu", "the title plays Rising Moon (%s, %s)" % [A.mood, A.track_playing()])
	var menu_p: AudioStreamPlayer = A.tracks["menu"]["player"]
	menu_p.seek(40.0)
	# The introduction's screens are a story moment: the six tolls from the top.
	M.open("intro")
	await t._frames(3)
	_check(_look() == "story" and A.track_playing() == "story", "the introduction plays the story track (%s)" % A.track_playing())
	var story_p: AudioStreamPlayer = A.tracks["story"]["player"]
	_check(story_p.playing or story_p.stream_paused, "...(the opening's own toll a screen is checked in opening.gd)")
	_check(menu_p.stream_paused and menu_p.volume_db <= -79.0, "...and Rising Moon waits, paused")
	M.open("title")
	await t._frames(1)
	_check(_look() == "menu" and A.track_playing() == "menu" and not menu_p.stream_paused and menu_p.get_playback_position() >= 39.0,
		"back on the title, Rising Moon carries on where it left off (%.0f s)" % menu_p.get_playback_position())
	story_p.seek(60.0)
	M.close()
	await t._frames(1)
	# In the tower: calm is Rising Moon again, softer.
	_check(Music.place_of(main) == "climb" and _look() == "calm" and A.track_playing() == "menu", "in a tower's calm, Rising Moon plays on (%s)" % A.mood)
	_check(float(A.tracks["menu"]["db"]) < float(Music.MOODS["menu"]["db"]) - 2.0, "...softer than in the menus (%.0f dB against %.0f)" % [float(A.tracks["menu"]["db"]), float(Music.MOODS["menu"]["db"])])
	# The Regard (with its glimpse of the fracture) is a story moment.
	main._begin_regard(false)
	_check(_look() == "story" and A.track_playing() == "story" and story_p.get_playback_position() >= A.STORY_PADS - 0.5 and story_p.get_playback_position() < A.STORY_PADS + 5.0,
		"the Regard plays the story track's pads, not its six tolls: the gong rings only as a scene changes (%.0f s)" % story_p.get_playback_position())
	_check(Bank.SFX.has("gong") and ResourceLoader.exists(String(Bank.SFX["gong"][0])), "...one gong for the scene (a toll cut from the story track)")
	main.regard = {}
	main.player.set_physics_process(true)
	_check(_look() == "calm" and A.track_playing() == "menu", "when it's over, the calm comes back")
	# A Maker's meeting.
	var mk = main.makers
	mk.interrupt_chance = 0.0
	mk.start_meeting("marks")
	_check(mk.meeting_live() and _look() == "story", "a Maker's meeting plays the story track")
	mk.end_meeting({})
	await t._frames(1)
	_check(not mk.meeting_live() and _look() == "calm", "...and after it, the calm")
	# The ending.
	var cs = main.climb_shape
	cs.show_ending()
	_check(_look() == "story", "the ending plays the story track")
	# (closed by hand: its own close goes on to the summit's flow, the heirloom and the train)
	if cs.ending_view != null:
		cs.ending_view.get_parent().queue_free()
		cs.ending_view = null
	main.get_tree().paused = false
	await t._frames(1)
	_check(_look() == "calm", "...and after it, the calm")
	# A real crossfade: both play while it lasts, then the old one pauses.
	A.set_mood("story", 0.3)
	_check(not menu_p.stream_paused and A.tracks["menu"]["target"] == 0.0 and A.track_playing() == "story", "a crossfade: the old track fades while the new one comes in")
	await t._wait(0.6)
	_check(menu_p.stream_paused and is_equal_approx(float(A.tracks["story"]["level"]), 1.0), "...and once it's done the old one pauses (%.2f)" % float(A.tracks["story"]["level"]))
	A.set_mood("calm", 0.0)


func _climb() -> void:
	var p = main.player
	var foes: Array = main.enemies().filter(func(e): return is_instance_valid(e) and not e.is_boss())
	if foes.size() < 2:
		_check(false, "the floor has monsters to test with (%d)" % foes.size())
		return
	var a = foes[0]
	var b = foes[1]
	var keep := {}
	for e in main.enemies():
		keep[e] = [e.global_position, e.state]
		e.state = "idle"
		e.global_position = p.global_position + Vector2(2000, 2000)  # (far away and asleep)
	var room_was: int = main.room_at
	main.room_at = -1
	A.director = Music.new()
	_check(_look() == "calm", "nothing awake near: calm")
	# Monsters awake and close make a fight.
	a.state = "chase"
	b.state = "chase"
	a.global_position = p.global_position + Vector2(120, 0)
	b.global_position = p.global_position + Vector2(-140, 40)
	_check(_look(0.2) == "calm", "a moment of danger isn't enough (no flicker)")
	_check(_look(0.3) == "intense" and A.track_playing() == "climb_intense", "two monsters awake and close: the danger track (%s)" % A.track_playing())
	# Gone, it settles only after a while.
	a.state = "idle"
	b.state = "idle"
	a.global_position = p.global_position + Vector2(2000, 2000)
	b.global_position = p.global_position + Vector2(2000, 2000)
	for i in 3:
		_look(2.0)
	_check(A.mood == "intense", "six seconds after the fight, still tense (it doesn't flicker back)")
	for i in 4:
		_look(2.0)
	_check(A.mood == "calm" and A.track_playing() == "menu", "...then the calm comes back")
	# One awake monster far off isn't a fight.
	a.state = "chase"
	a.global_position = p.global_position + Vector2(900, 0)
	_check(_look(1.0) == "calm", "one monster awake far off: still calm")
	a.state = "idle"
	a.global_position = p.global_position + Vector2(2000, 2000)
	# A dangerous room with something alive in it.
	# (a room of its own, away from the climber, added for the test and taken out after)
	var rect := Rect2(p.global_position + Vector2(600, -150), Vector2(300, 300))
	main.room_info.append({"rect": rect, "role": ""})
	main.room_themes.append("quiet")
	var at: int = main.room_info.size() - 1
	main.room_at = at
	a.global_position = rect.get_center()
	_check(_look(1.0) == "calm" and not Music.danger_room("quiet"), "a quiet hall with a sleeping monster: calm")
	main.room_themes[at] = "den"
	_check(Music.danger_room("den") and Music.danger_room("crypt") and Music.danger_room("post") and not Music.danger_room("spring"), "dens, crypts and guard posts are dangerous rooms (a spring isn't)")
	_check(_look(0.5) == "intense", "a den with something alive in it (asleep, out of reach): the danger track")
	a.global_position = p.global_position + Vector2(2000, 2000)
	for i in 7:
		_look(2.0)
	_check(A.mood == "calm", "the den empty: calm again, after a while")
	main.room_info.pop_back()
	main.room_themes.pop_back()
	main.room_at = -1
	# A lock-in's bars.
	main.door_view.lock_rooms[9999] = {"state": "shut", "hold": true, "gates": [], "mobs": [], "bodies": [], "t": 0.0}
	_check(_look(0.5) == "intense", "shut in a lock-in room: the danger track")
	main.door_view.lock_rooms.erase(9999)
	for i in 7:
		_look(2.0)
	# The barrier's horde.
	main.climb_shape.horde.append(a)
	_check(main.climb_shape.horde_live() and _look(0.5) == "intense", "the barrier's horde: the danger track")
	main.climb_shape.horde.erase(a)
	for i in 7:
		_look(2.0)
	_check(A.mood == "calm", "the horde gone: calm")
	# The guardian: the same track, louder, at once.
	var g = await t._spawn("gryphon", p.global_position + Vector2(220, 0))
	if g != null:
		_check(_look(0.1) == "boss" and A.track_playing() == "climb_intense" and float(Music.MOODS["boss"]["db"]) > float(Music.MOODS["intense"]["db"]), "the guardian close: the danger track, louder, at once")
		g.remove_from_group("enemies")
		g.queue_free()
		main.foes_changed()
		await t._frames(2)
	for i in 7:
		_look(2.0)
	_check(A.mood == "calm", "the guardian gone: calm")
	# The crossfades' lengths: quick into danger, slow back to calm.
	_check(Music.fade_time("calm", "intense") < Music.fade_time("intense", "calm") and Music.fade_time("calm", "intense") >= 1.0 and Music.fade_time("intense", "calm") <= 5.0,
		"into danger in %.0f s, back to calm over %.0f s" % [Music.fade_time("calm", "intense"), Music.fade_time("intense", "calm")])
	for e in keep:
		if is_instance_valid(e):
			e.global_position = keep[e][0]
			e.state = keep[e][1]
	main.room_at = room_was


func _levels() -> void:
	var keep_level: float = A.music_level
	var keep_sound: float = A.sound_level
	A.duck_until = 0  # (no dip left from a story moment's gong: tests/parts/audio_places.gd tests the dips)
	A.duck_depth = 0.0
	A.duck_now = 0.0
	A.set_mood("calm", 0.0)
	var p: AudioStreamPlayer = A.tracks["menu"]["player"]
	A.set_levels(1.0, keep_sound)
	var full: float = p.volume_db
	A.set_levels(0.5, keep_sound)
	_check(absf(p.volume_db - (full + linear_to_db(0.5))) < 0.1, "the Music slider turns the track down (%.1f dB at half)" % (p.volume_db - full))
	A.set_levels(0.0, keep_sound)
	_check(p.volume_db <= -79.0 and A.ambience.volume_db <= -79.0, "...and at zero, silent (the ambience too)")
	A.set_levels(1.0, keep_sound)
	var on: bool = A.toggle_music()
	_check(not on and p.volume_db <= -79.0, "M turns the music off")
	A.set_mood("intense", 0.0)
	_check(A.tracks["climb_intense"]["player"].volume_db <= -79.0, "...and a new track stays silent while it's off")
	on = A.toggle_music()
	_check(on and absf(A.tracks["climb_intense"]["player"].volume_db - float(Music.MOODS["intense"]["db"])) < 0.1, "M again: back on")
	main.menu._set_setting("music", 0.4)
	_check(absf(A.music_level - 0.4) < 0.01, "the Music setting reaches the music (%.2f)" % A.music_level)
	main.menu._set_setting("music", keep_level)
	A.set_levels(keep_level, keep_sound)
	A.set_mood("calm", 0.0)


## The director on its own (as in play): the train is a menu.
func _live_director() -> void:
	var keep: float = float(Music.RULES["check_every"])
	Music.RULES["check_every"] = 0.05
	A.director_on = true
	main.open_train()
	await t._wait(0.5)
	_check(A.mood == "menu" and A.track_playing() == "menu", "the train plays Rising Moon (%s)" % A.mood)
	Music.RULES["check_every"] = keep
