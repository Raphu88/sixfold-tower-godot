extends Node2D
## The kids version: a simpler Sixfold Tower for young children who can't read
## yet. Its home screen (kids_home.gd) is the only menu; a climb
## (kids_climb.gd) is three rooms of one tower. Everything is pictures,
## colours and sounds. Its save is its own (kids_save.gd), apart from the
## full game's climbers.
##
## Reached from the full game's title screen (Kids version), or from the web
## link with ?kids on the end. Once picked, the game opens here every time
## until a grown-up holds the gear on the home screen.

const AudioScript := preload("res://scripts/audio.gd")
const Save := preload("res://scripts/kids/kids_save.gd")
const Home := preload("res://scripts/kids/kids_home.gd")
const Climb := preload("res://scripts/kids/kids_climb.gd")

var audio
var save
var screen: Node
var fade := 1.0
var fader: Node2D


func _ready() -> void:
	randomize()
	Engine.time_scale = 1.0
	get_tree().paused = false
	RenderingServer.set_default_clear_color(Color(0.07, 0.06, 0.12))
	audio = AudioScript.new()
	add_child(audio)
	save = Save.load_save()
	save.stay = true
	save.save()
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


## Back to the full game (the grown-ups' gear on the home screen).
func leave_kids() -> void:
	save.stay = false
	save.save()
	sfx("ui_close")
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")


func sfx(sound: String, pitch := 1.0, volume_db := 0.0) -> void:
	if audio != null and audio.has_sound(sound):
		audio.play(sound, pitch, volume_db)
