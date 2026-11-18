extends Node2D
## Six Towers LITE: a simpler Sixfold Tower for young children who can't
## read yet. Its home screen (home.gd) is the only menu; a climb (climb.gd)
## is three rooms of one tower. Everything is pictures, colours and sounds.
## This node switches between the two and plays the sounds.

const AudioScript := preload("res://scripts/audio.gd")
const Save := preload("res://scripts/save.gd")
const Home := preload("res://scripts/home.gd")
const Climb := preload("res://scripts/climb.gd")
const Data := preload("res://scripts/data.gd")

var audio
var save
var screen: Node
var fade := 1.0
var fader: Node2D


func _ready() -> void:
	randomize()
	RenderingServer.set_default_clear_color(Color(0.07, 0.06, 0.12))
	audio = AudioScript.new()
	add_child(audio)
	save = Save.load_save()
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


func start_climb(tower: String) -> void:
	var c = Climb.new()
	c.setup(self, tower)
	_show(c)


## Reads words aloud (Data.SPEAK), if the device has a voice: a child hears
## each word while seeing it. A new line cuts off the one before.
func say(text: String) -> void:
	if not Data.SPEAK or text == "" or not DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		return
	var voices := DisplayServer.tts_get_voices_for_language("en")
	if voices.is_empty():
		voices = DisplayServer.tts_get_voices_for_language(OS.get_locale_language())
	if voices.is_empty():
		return
	DisplayServer.tts_stop()
	DisplayServer.tts_speak(text, voices[0], 80, 1.0, 0.85)


func sfx(sound: String, pitch := 1.0, volume_db := 0.0) -> void:
	if audio != null and audio.has_sound(sound):
		audio.play(sound, pitch, volume_db)
