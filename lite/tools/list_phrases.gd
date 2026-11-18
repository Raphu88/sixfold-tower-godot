extends SceneTree
## Prints every phrase Six Towers LITE can say aloud (Data.spoken()) as one
## JSON line, for tools/make_voice.py. Run from the lite folder:
##     godot --headless -s tools/list_phrases.gd


func _init() -> void:
	var data = load("res://scripts/data.gd")
	print("PHRASES_JSON " + JSON.stringify(data.spoken()))
	quit()
