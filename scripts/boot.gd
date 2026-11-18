extends Node
## The first scene: opens the full game (scenes/main.tscn), or the kids
## version (scenes/kids.tscn) if it was the one picked last, or if the web
## link ends in ?kids. A link ending in ?full always opens the full game.

const KidsSave := preload("res://scripts/kids/kids_save.gd")


func _ready() -> void:
	var link := _link()
	var kids := KidsSave.wants_kids()
	if link.contains("full"):
		if kids:
			KidsSave.set_stay(false)
		kids = false
	elif link.contains("kids"):
		kids = true
	get_tree().change_scene_to_file.call_deferred("res://scenes/kids.tscn" if kids else "res://scenes/main.tscn")


## The web link's ?query ("" off the web).
static func _link() -> String:
	if not OS.has_feature("web"):
		return ""
	var q = JavaScriptBridge.eval("window.location.search", true)
	return String(q).to_lower() if typeof(q) == TYPE_STRING else ""
