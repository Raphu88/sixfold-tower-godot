extends Node
## Plays the game's sounds and music. The sounds are recorded CC0 effects,
## layered and levelled by tools/build_audio.py; sound_bank.gd lists them.
## Each sound can have several variants; one is picked at random, with a
## little pitch variance, so repeats never sound identical.

const Bank := preload("res://scripts/sound_bank.gd")

const MASTER_DB := 0.0
const MUSIC_DB := -12.0
const AMBIENCE_DB := -17.0
const NO_STACK_MS := 40  # the same sound twice at once only gets louder
const UI_GAP_MS := 70  # menu sounds share one gap, so opening a page doesn't click twice
const VOICES := 24  # sounds that can play at once
const MAX_SAME := 4  # copies of one sound at once; a fifth replaces the oldest

## Per-sound trim in dB, on top of the levels baked in by the build tool.
const TRIM := {}

var streams := {}  # name -> Array of AudioStream
var players: Array = []
var voice_sound: Array = []  # per player: the sound it's playing
var voice_start: Array = []  # per player: when it started (msec)
var voice_fade: Array = []  # per player: a fade-out tween, or null
var last_played := {}
var last_variant := {}
var music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var music_on := true


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
	ambience = _loop_player(Bank.MUSIC.get("ambience", ""), AMBIENCE_DB)
	music = _loop_player(Bank.MUSIC.get("music", ""), MUSIC_DB)


func _loop_player(path: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	add_child(p)
	if path == "":
		return p
	var s = load(path)
	if s == null:
		return p
	if "loop" in s:
		s.loop = true
	p.stream = s
	p.volume_db = db
	p.play()
	return p


var music_level := 1.0  # settings, 0..1
var sound_level := 1.0


func toggle_music() -> bool:
	music_on = not music_on
	_apply_music()
	return music_on


## Volume settings from the menu (0 is silent, 1 is full).
func set_levels(music_frac: float, sound_frac: float) -> void:
	music_level = music_frac
	sound_level = sound_frac
	_apply_music()


func _apply_music() -> void:
	var off := not music_on or music_level <= 0.01
	music.volume_db = -80.0 if off else MUSIC_DB + linear_to_db(music_level)
	ambience.volume_db = -80.0 if off else AMBIENCE_DB + linear_to_db(music_level)


func has_sound(sound: String) -> bool:
	return streams.has(sound) and not streams[sound].is_empty()


## pitch: base playback speed; variance adds a little randomness.
func play(sound: String, pitch := 1.0, volume_db := 0.0, variance := 0.05) -> void:
	if not has_sound(sound) or sound_level <= 0.01:
		return
	var now := Time.get_ticks_msec()
	var key := "ui" if sound.begins_with("ui_") else sound
	if now - int(last_played.get(key, -100000)) < (UI_GAP_MS if key == "ui" else NO_STACK_MS):
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
