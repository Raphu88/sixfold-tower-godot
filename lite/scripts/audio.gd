extends Node
## Plays the sounds and music (a slim copy of the full game's audio.gd).
## sounds.gd lists the files. Each sound can have several variants; one is
## picked at random, with a little pitch variance, so repeats never sound
## identical. Under the music, each place has its own ambience.

const Sounds := preload("res://scripts/sounds.gd")

const MUSIC_DB := -12.0
const AMBIENCE_DB := -17.0
const NO_STACK_MS := 40  # the same sound twice at once only gets louder
const UI_GAP_MS := 70  # menu sounds share one gap
const VOICES := 16  # sounds that can play at once

var streams := {}  # name -> Array of AudioStream
var players: Array = []
var last_played := {}
var last_variant := {}
var music: AudioStreamPlayer
var ambience: AudioStreamPlayer
var ambience_key := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	for sound in Sounds.SFX:
		var list: Array = []
		for path in Sounds.SFX[sound]:
			var s = load(path)
			if s != null:
				list.append(s)
		streams[sound] = list
	music = _loop_player(Sounds.MUSIC.get("music", ""), MUSIC_DB)


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


## A place's ambience: a tower's id ("kraken") or "train" (home). The old
## loop fades out as the new one fades in.
func set_ambience(place: String, fade_time := 2.0) -> void:
	var key := "ambience_" + place
	if key == ambience_key or not Sounds.MUSIC.has(key):
		return
	ambience_key = key
	var old := ambience
	ambience = _loop_player(Sounds.MUSIC[key], -60.0)
	create_tween().tween_property(ambience, "volume_db", AMBIENCE_DB, fade_time)
	if old != null:
		var out := create_tween()
		out.tween_property(old, "volume_db", -60.0, fade_time)
		out.tween_callback(old.queue_free)


func has_sound(sound: String) -> bool:
	return streams.has(sound) and not streams[sound].is_empty()


## pitch: base playback speed; variance adds a little randomness.
func play(sound: String, pitch := 1.0, volume_db := 0.0, variance := 0.05) -> void:
	if not has_sound(sound):
		return
	var now := Time.get_ticks_msec()
	var key := "ui" if sound.begins_with("ui_") else sound
	if now - int(last_played.get(key, -100000)) < (UI_GAP_MS if key == "ui" else NO_STACK_MS):
		return
	last_played[key] = now
	var list: Array = streams[sound]
	var idx := randi() % list.size()
	if list.size() > 1 and idx == last_variant.get(sound, -1):
		idx = (idx + 1) % list.size()
	last_variant[sound] = idx
	var p: AudioStreamPlayer = _free_player()
	p.stream = list[idx]
	p.pitch_scale = maxf(0.1, pitch * (1.0 + randf_range(-variance, variance)))
	p.volume_db = volume_db
	p.play()


## An idle player, or the one that started longest ago.
func _free_player() -> AudioStreamPlayer:
	var best: AudioStreamPlayer = players[0]
	var best_pos := -1.0
	for p in players:
		if not p.playing:
			return p
		if p.get_playback_position() > best_pos:
			best_pos = p.get_playback_position()
			best = p
	return best
