extends Node2D
## Six Towers LITE: a simpler Sixfold Tower for young children who can't
## read yet. Its home screen (home.gd) is the only menu; a climb (climb.gd)
## is three rooms of one tower. Everything is pictures, colours and sounds.
## This node switches between the two and plays the sounds.

const AudioScript := preload("res://scripts/audio.gd")
const Save := preload("res://scripts/save.gd")
const Home := preload("res://scripts/home.gd")
const Climb := preload("res://scripts/climb.gd")
const ClimberScreen := preload("res://scripts/climber_screen.gd")
const UpgradePick := preload("res://scripts/upgrade_pick.gd")
## The natural voice's clips (tools/make_voice.py), if they've been made.
const VOICE_PATH := "res://scripts/voice.gd"
const Data := preload("res://scripts/data.gd")

var audio
var save
var screen: Node
var fade := 1.0
var fader: Node2D
var upgrades: Node  # the upgrade pick, while it's showing (upgrade_pick.gd)
var voice_clips := {}  # text -> clip path (voice.gd)
var voice_player: AudioStreamPlayer
var voice_queue: Array = []


func _ready() -> void:
	randomize()
	RenderingServer.set_default_clear_color(Color(0.07, 0.06, 0.12))
	audio = AudioScript.new()
	add_child(audio)
	save = Save.load_save()
	if ResourceLoader.exists(VOICE_PATH):
		voice_clips = load(VOICE_PATH).CLIPS
	voice_player = AudioStreamPlayer.new()
	voice_player.volume_db = 2.0
	add_child(voice_player)
	voice_player.finished.connect(_voice_next)
	fader = Node2D.new()
	fader.z_index = 100
	add_child(fader)
	fader.draw.connect(func(): fader.draw_rect(Rect2(Vector2.ZERO, get_viewport_rect().size), Color(0, 0, 0, fade)))
	go_home()


func _process(delta: float) -> void:
	if fade > 0.0:
		fade = maxf(0.0, fade - delta * 2.5)
		fader.queue_redraw()


func _show(node: Node) -> void:
	if screen != null:
		screen.queue_free()
	screen = node
	add_child(node)
	move_child(node, 0)
	fade = 1.0


## The home screen; `celebrate` is a tower whose beast was just beaten.
func go_home(celebrate := "") -> void:
	save.save()
	var h = Home.new()
	h.setup(self, celebrate)
	_show(h)


## What the climber wears, for the drawings: slot -> gear_look.gd piece.
func worn_gear() -> Dictionary:
	var out := {}
	for slot in save.worn:
		var tr: Dictionary = Data.TREASURES.get(save.worn[slot], {})
		if slot != "skin" and tr.get("kind", "") == "gear":
			out[slot] = tr["piece"]
	return out


## The weapons' finish worn (gear_look.gd SKINS), or "".
func worn_skin() -> String:
	var tr: Dictionary = Data.TREASURES.get(save.worn.get("skin", ""), {})
	return String(tr.get("piece", ""))


## Shows the upgrade pick over the screen while marks wait for one.
func show_upgrades() -> void:
	if upgrades != null or save.pending_ups.is_empty():
		return
	upgrades = UpgradePick.new()
	upgrades.setup(self)
	add_child(upgrades)


func close_upgrades() -> void:
	if upgrades != null:
		upgrades.queue_free()
	upgrades = null


## The climber screen (marks, weapons, look).
func open_climber(tab := "marks") -> void:
	save.save()
	var s = ClimberScreen.new()
	s.setup(self, tab)
	_show(s)


func start_climb(tower: String) -> void:
	var c = Climb.new()
	c.setup(self, tower)
	_show(c)


## Reads words aloud (Data.SPEAK): a child hears each word while seeing it.
## The natural voice's clip if there is one (voice.gd), else the device's own
## voice. A new line cuts off the one before.
func say(text: String) -> void:
	voice_queue.clear()
	_say_one(text, true)


## Reads several lines one after another.
func say_list(lines: Array) -> void:
	voice_queue = lines.duplicate()
	if not voice_queue.is_empty():
		_say_one(String(voice_queue.pop_front()), true)


func _voice_next() -> void:
	if not voice_queue.is_empty():
		_say_one(String(voice_queue.pop_front()), false)


func _say_one(text: String, interrupt: bool) -> void:
	if not Data.SPEAK or text == "":
		return
	if voice_clips.has(text) and ResourceLoader.exists(voice_clips[text]):
		DisplayServer.tts_stop() if DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH) and OS.get_name() != "Linux" else null
		voice_player.stream = load(voice_clips[text])
		voice_player.play()
		return
	if not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return
	if OS.get_name() == "Linux":
		return  # (a Linux desktop often has no voice, and asking for one only logs errors)
	var voices := DisplayServer.tts_get_voices_for_language("en")
	if voices.is_empty():
		voices = DisplayServer.tts_get_voices_for_language(OS.get_locale_language())
	if voices.is_empty():
		return
	if interrupt:
		DisplayServer.tts_stop()
	voice_player.stop()
	DisplayServer.tts_speak(text, voices[0], 80, 1.0, 0.85)
	if not voice_queue.is_empty():
		_voice_next()  # (the device queues its own lines)


func sfx(sound: String, pitch := 1.0, volume_db := 0.0) -> void:
	if audio != null and audio.has_sound(sound):
		audio.play(sound, pitch, volume_db)
