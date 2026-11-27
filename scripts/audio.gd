extends Node
## Plays the game's sounds and music. The sounds are recorded CC0 effects,
## layered and levelled by tools/build_audio.py; sound_bank.gd lists them.
## The music director (music.gd) says which track plays where, and which
## ambience loop goes under it (none on the title, the opening and in the
## stations); this plays them, crossfading from one to the next. Every loop
## is set from the Music slider the moment it starts (no tweens fight it),
## and the music and ambience carry on where they were across a new floor or
## a return to the train (the scene starts afresh: _note_resume / _resume).
## Each sound can have several variants; one is picked at random, with a
## little pitch variance, so repeats never sound identical.

const Bank := preload("res://scripts/sound_bank.gd")
const Music := preload("res://scripts/music.gd")

const MASTER_DB := 0.0
const AMBIENCE_DB := -17.0
const NO_STACK_MS := 40  # the same sound twice at once only gets louder
const UI_GAP_MS := 70  # menu sounds share one gap, so opening a page doesn't click twice
const VOICES := 24  # sounds that can play at once
const MAX_SAME := 4  # copies of one sound at once; a fifth replaces the oldest
## Sounds that play often from many places, kept to at most one every this
## many msec (the rest are skipped): fire's crackle comes from a Flameblade's
## swings at full heat, standing in fire, burning ground and every fire
## spell, and a crackle on each of them at once turned into a rattle.
const GAP_MS := {"burn": 250}

## Per-sound trim in dB, on top of the levels baked in by the build tool.
const TRIM := {}

var streams := {}  # name -> Array of AudioStream
var players: Array = []
var voice_sound: Array = []  # per player: the sound it's playing
var voice_start: Array = []  # per player: when it started (msec)
var voice_fade: Array = []  # per player: a fade-out tween, or null
var last_played := {}
var last_variant := {}
var music: AudioStreamPlayer  # the track playing now (music.gd's mood picks it)
## Track name -> {player, level (0..1: its share of the crossfade), target,
## rate (level a second), db (its level now), db_to, db_rate}.
var tracks := {}
var mood := ""  # the mood playing (music.gd MOODS)
var director = Music.new()
var director_on := true  # (tests turn it off to set moods themselves)
var _look_t := 0.0
var _music_us := 0
## The ambience heard now (no stream: none), and the one fading out after a
## change (at most one: a third is stopped at once, so loops never pile up).
var ambience: AudioStreamPlayer
var ambience_key := ""  # which loop plays: "" (none), "ambience_<tower>" or "ambience_train"
var amb_level := 1.0  # its share of the crossfade (0..1)
var amb_rate := 1.0
var ambience_old: AudioStreamPlayer = null
var amb_old_level := 0.0
var amb_old_rate := 1.0
var music_on := true
## What was playing when the scene last ended (a new floor, the train): the
## next audio carries on from there if it starts right after.
static var _resume := {}
const RESUME_MS := 4000
## The opening's screens (opening.gd): the story track's toll they're on
## (-1: none yet). Each screen plays one toll, then holds there (story_toll).
var toll_at := -1
## The story track's six tolls: one every this many seconds from its start.
const TOLL_EVERY := 3.0
## Where the story track's pads begin, after its six tolls: every story
## moment, the opening included, plays from here (the gongs are rung on their own).
const STORY_PADS := 18.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
		voice_sound.append("")
		voice_start.append(0)
		voice_fade.append(null)
	for sound in Bank.SFX:
		var list: Array = []
		for path in Bank.SFX[sound]:
			var s = load(path)
			if s != null:
				list.append(s)
		streams[sound] = list
	music_on = not Engine.has_meta("sixfold_music_off")  # (M's choice holds across floors)
	ambience = _loop_player("")
	_music_us = Time.get_ticks_usec()
	if not _resume_playing():
		set_mood("menu", 0.0)  # (the title shows first; the director looks from the next frame)


## Carries on what played before the scene started afresh: the same mood at
## the same moment of its track, the same ambience at full.
func _resume_playing() -> bool:
	var r := _resume
	_resume = {}
	if r.is_empty() or Time.get_ticks_msec() - int(r.get("msec", -100000)) > RESUME_MS or not Music.MOODS.has(String(r.get("mood", ""))):
		return false
	set_mood(String(r["mood"]), 0.0)
	var name := String(Music.MOODS[mood]["track"])
	if tracks.has(name) and r.has("pos"):
		var p: AudioStreamPlayer = tracks[name]["player"]
		p.seek(float(r["pos"]))
	var key := String(r.get("amb", ""))
	if key != "" and Bank.MUSIC.has(key):
		ambience_key = key
		ambience.queue_free()
		ambience = _loop_player(String(Bank.MUSIC[key]), float(r.get("amb_pos", 0.0)))
		amb_level = 1.0
		_apply_ambience()
	return true


## Notes, each frame, what plays (the players have already stopped by the
## time the scene's nodes leave the tree, so it can't wait for that).
func _note_resume() -> void:
	_resume["msec"] = Time.get_ticks_msec()
	_resume["mood"] = mood
	_resume["amb"] = ambience_key if amb_level > 0.5 else ""
	_resume.erase("pos")
	_resume.erase("amb_pos")
	if music != null and is_instance_valid(music) and music.playing and not music.stream_paused:
		_resume["pos"] = music.get_playback_position()
	if ambience != null and is_instance_valid(ambience) and ambience.playing:
		_resume["amb_pos"] = ambience.get_playback_position()


## A looping player for `path` ("": a silent one), started at `from` seconds.
## It starts silent: _apply_ambience sets its level.
func _loop_player(path: String, from := 0.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.volume_db = -80.0
	add_child(p)
	if path == "":
		return p
	var s = load(path)
	if s == null:
		return p
	if "loop" in s:
		s.loop = true
	p.stream = s
	p.play(from)
	return p


var music_level := 1.0  # settings, 0..1
var sound_level := 1.0


func toggle_music() -> bool:
	music_on = not music_on
	if music_on:
		Engine.remove_meta("sixfold_music_off")
	else:
		Engine.set_meta("sixfold_music_off", true)
	_apply_music()
	return music_on


## Volume settings from the menu (0 is silent, 1 is full).
func set_levels(music_frac: float, sound_frac: float) -> void:
	music_level = music_frac
	sound_level = sound_frac
	_apply_music()


func _apply_music() -> void:
	for name in tracks:
		_track_volume(tracks[name])
	_apply_ambience()


func music_muted() -> bool:
	return not music_on or music_level <= 0.01


# --- the music: moods and crossfades (music.gd picks the mood) ---------------

## Plays a mood's track at its level (music.gd MOODS), crossfading from what
## plays now over `fade_time` seconds (-1: music.gd's fade for the change).
## A track faded out pauses where it was and carries on from there when it
## comes back; the story's starts again from its six tolls (music.gd RESTART).
func set_mood(new_mood: String, fade_time := -1.0) -> void:
	if not Music.MOODS.has(new_mood) or new_mood == mood:
		return
	var fade := Music.fade_time(mood, new_mood) if fade_time < 0.0 else fade_time
	mood = new_mood
	toll_at = -1  # (the opening's tolls start again with the story's next start)
	var want: Dictionary = Music.MOODS[new_mood]
	var name := String(want["track"])
	for other in tracks:
		if other != name:
			_fade_track(tracks[other], 0.0, fade)
	var tr: Dictionary = _track(name)
	if tr.is_empty():
		music = null
		return
	var p: AudioStreamPlayer = tr["player"]
	if float(tr["level"]) <= 0.0:
		tr["db"] = float(want["db"])
		if name in Music.RESTART or not (p.playing or p.stream_paused):
			p.stream_paused = false
			if name == "story":
				# (the gong only rings as a scene changes: past the six tolls into
				# the pads, and one gong now, unless the opening rings its own
				# toll for each screen: story_toll takes over in the next frames)
				p.play(STORY_PADS)
				_gong_soon()
			else:
				p.play(0.0)
		else:
			p.stream_paused = false  # (carries on where it was left)
	tr["db_to"] = float(want["db"])
	tr["db_rate"] = absf(float(want["db"]) - float(tr["db"])) / maxf(fade, 0.001)
	_fade_track(tr, 1.0, fade)
	music = p


## A track's player, made the first time it's needed.
func _track(name: String) -> Dictionary:
	if tracks.has(name):
		return tracks[name]
	var path := String(Bank.MUSIC.get(name, ""))
	var s = load(path) if path != "" else null
	if s == null:
		return {}
	if "loop" in s:
		s.loop = true  # (from its loop_offset, set on import: the story's tolls play once)
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = -80.0
	add_child(p)
	tracks[name] = {"player": p, "level": 0.0, "target": 0.0, "rate": 1.0, "db": -12.0, "db_to": -12.0, "db_rate": 0.0}
	return tracks[name]


func _fade_track(tr: Dictionary, target: float, fade: float) -> void:
	tr["target"] = target
	tr["rate"] = 1.0 / maxf(fade, 0.001)
	if fade <= 0.0:
		tr["level"] = target
		tr["db"] = tr["db_to"]
		_settle(tr)
	_track_volume(tr)


## Each frame, in real time (slow motion and the paused game don't drag a
## fade out), and the director's look a few times a second.
func _process(_delta: float) -> void:
	var now := Time.get_ticks_usec()
	var dt := minf((now - _music_us) / 1000000.0, 0.25)
	_music_us = now
	for name in tracks:
		var tr: Dictionary = tracks[name]
		if float(tr["level"]) != float(tr["target"]) or float(tr["db"]) != float(tr["db_to"]):
			tr["level"] = move_toward(float(tr["level"]), float(tr["target"]), float(tr["rate"]) * dt)
			tr["db"] = move_toward(float(tr["db"]), float(tr["db_to"]), float(tr["db_rate"]) * dt)
			_settle(tr)
			_track_volume(tr)
	if amb_level < 1.0 or ambience_old != null:
		amb_level = move_toward(amb_level, 1.0, amb_rate * dt)
		amb_old_level = move_toward(amb_old_level, 0.0, amb_old_rate * dt)
		if ambience_old != null and amb_old_level <= 0.0:
			_drop_old_ambience()
		_apply_ambience()
	if director_on:
		_look_t -= dt
		if _look_t <= 0.0:
			_look_t = float(Music.RULES["check_every"])
			set_mood(director.update(get_parent(), float(Music.RULES["check_every"])))
			update_ambience()
	_note_resume()


## A track that has faded all the way out pauses (it carries on from there).
func _settle(tr: Dictionary) -> void:
	var p: AudioStreamPlayer = tr["player"]
	if float(tr["level"]) <= 0.0 and float(tr["target"]) <= 0.0 and p.playing:
		p.stream_paused = true


## An equal-power crossfade: the two tracks together stay as loud through it.
func _track_volume(tr: Dictionary) -> void:
	var p: AudioStreamPlayer = tr["player"]
	var share := sin(clampf(float(tr["level"]), 0.0, 1.0) * PI * 0.5)
	if music_muted() or share <= 0.001:
		p.volume_db = -80.0
	else:
		p.volume_db = float(tr["db"]) + linear_to_db(share) + linear_to_db(music_level)


## The opening's screen `i` (0..5) is showing (opening.gd calls this each
## frame). The music under the opening is the story track's pads only (its
## own tolls are skipped: set_mood starts it at STORY_PADS); the gong is a
## sound of its own, rung once as each screen comes up, and only then.
func story_toll(i: int) -> void:
	if mood != "story":
		return
	if toll_at != i:
		toll_at = i
		play("gong", 1.0, -2.0, 0.0)


## The track heard now (the one fading in), or "".
func track_playing() -> String:
	for name in tracks:
		var p: AudioStreamPlayer = tracks[name]["player"]
		if float(tracks[name]["target"]) > 0.0 and p.playing and not p.stream_paused:
			return name
	return ""


func _ambience_db() -> float:
	return -80.0 if music_muted() else AMBIENCE_DB + linear_to_db(music_level)


## The ambience players' levels: the Music slider times each one's share of
## the crossfade, set every frame of a fade (nothing else touches them).
func _apply_ambience() -> void:
	if ambience != null and is_instance_valid(ambience):
		ambience.volume_db = _amb_db(amb_level)
	if ambience_old != null and is_instance_valid(ambience_old):
		ambience_old.volume_db = _amb_db(amb_old_level)


func _amb_db(share: float) -> float:
	var base := _ambience_db()
	return -80.0 if base <= -79.0 or share <= 0.001 else maxf(-80.0, base + linear_to_db(share))


func _drop_old_ambience() -> void:
	if ambience_old != null and is_instance_valid(ambience_old):
		ambience_old.stop()
		ambience_old.queue_free()
	ambience_old = null
	amb_old_level = 0.0


## The ambience the director wants here (music.gd ambience_of).
func update_ambience(fade_time := 2.0) -> void:
	set_ambience(Music.ambience_of(get_parent()), fade_time)


## Each place has its own ambience under the music: a tower's id ("kraken"),
## "train", or "" (or anything without a loop) for none. The old loop fades
## out as the new one fades in.
func set_ambience(place: String, fade_time := 2.0) -> void:
	var key := "ambience_" + place
	if place == "" or not Bank.MUSIC.has(key):
		key = ""
	if ambience == null:
		return
	if key == ambience_key:
		if fade_time <= 0.0 and (amb_level < 1.0 or ambience_old != null):
			amb_level = 1.0  # (at once: a fade under way is finished)
			_drop_old_ambience()
			_apply_ambience()
		return
	ambience_key = key
	_drop_old_ambience()  # (one still fading from before: gone at once)
	ambience_old = ambience
	amb_old_level = amb_level
	amb_old_rate = 1.0 / maxf(fade_time, 0.001)
	ambience = _loop_player(String(Bank.MUSIC[key]) if key != "" else "")
	amb_level = 0.0
	amb_rate = 1.0 / maxf(fade_time, 0.001)
	if fade_time <= 0.0:
		amb_level = 1.0
		_drop_old_ambience()
	_apply_ambience()


## How many ambience loops are playing and can be heard (for tests).
func ambience_heard() -> int:
	var n := 0
	for p in [ambience, ambience_old]:
		if p != null and is_instance_valid(p) and p.playing and p.stream != null and p.volume_db > -79.0:
			n += 1
	return n


func has_sound(sound: String) -> bool:
	return streams.has(sound) and not streams[sound].is_empty()


## pitch: base playback speed; variance adds a little randomness.
func play(sound: String, pitch := 1.0, volume_db := 0.0, variance := 0.05) -> void:
	if not has_sound(sound) or sound_level <= 0.01:
		return
	var now := Time.get_ticks_msec()
	var key := "ui" if sound.begins_with("ui_") else sound
	if now - int(last_played.get(key, -100000)) < (UI_GAP_MS if key == "ui" else int(GAP_MS.get(key, NO_STACK_MS))):
		return
	last_played[key] = now
	var list: Array = streams[sound]
	# Pick a variant, avoiding the one we just played.
	var idx := randi() % list.size()
	if list.size() > 1 and idx == last_variant.get(sound, -1):
		idx = (idx + 1) % list.size()
	last_variant[sound] = idx
	var slot := _free_voice(sound)
	if voice_fade[slot] != null:
		voice_fade[slot].kill()
		voice_fade[slot] = null
	voice_sound[slot] = sound
	voice_start[slot] = now
	var p: AudioStreamPlayer = players[slot]
	p.stream = list[idx]
	p.pitch_scale = maxf(0.1, pitch * (1.0 + randf_range(-variance, variance)))
	p.volume_db = volume_db + MASTER_DB + float(TRIM.get(sound, 0.0)) + linear_to_db(sound_level)
	p.play()


## A player for a new sound: an idle one if there is one. In a busy fight,
## a sound already playing MAX_SAME times replaces its own oldest copy, and
## otherwise the oldest sound of all gives way (its tail is the least missed).
func _free_voice(sound: String) -> int:
	var same := 0
	var oldest_same := -1
	var oldest := 0
	var idle := -1
	for i in players.size():
		if not players[i].playing:
			if idle < 0:
				idle = i
			continue
		if voice_sound[i] == sound:
			same += 1
			if oldest_same < 0 or voice_start[i] < voice_start[oldest_same]:
				oldest_same = i
		if voice_start[i] < voice_start[oldest]:
			oldest = i
	if same >= MAX_SAME:
		return oldest_same
	if idle >= 0:
		return idle
	return oldest


## Fades out a sound that's playing (a bow's creak when the arrow is loosed).
func fade(sound: String, time := 0.08) -> void:
	for i in players.size():
		if players[i].playing and voice_sound[i] == sound and voice_fade[i] == null:
			var p: AudioStreamPlayer = players[i]
			var tw := create_tween()
			tw.tween_property(p, "volume_db", -60.0, time)
			tw.tween_callback(p.stop)
			voice_fade[i] = tw


## How many copies of a sound are playing now (for tests).
func playing_count(sound: String) -> int:
	var n := 0
	for i in players.size():
		if players[i].playing and voice_sound[i] == sound:
			n += 1
	return n


## One gong as a story scene begins (not the opening, whose screens each ring
## their own toll: story_toll sets toll_at within a frame or two).
func _gong_soon() -> void:
	if not is_inside_tree():
		return
	await get_tree().create_timer(0.15, true).timeout
	if is_instance_valid(self) and mood == "story" and toll_at < 0:
		play("gong", 1.0, -2.0, 0.0)


## A story scene turning to its next page or scene (the ending's pages): one gong.
func story_gong() -> void:
	if mood == "story" and toll_at < 0:
		play("gong", 1.0, -2.0, 0.0)
