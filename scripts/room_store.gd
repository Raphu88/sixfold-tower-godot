extends RefCounted
## The room painter's rooms (painter.gd), and how they're kept.
##
## Rooms made in the painter are kept in a file, in this form (the same
## fields as the hand-made rooms in rooms.gd, plus a name, the towers that
## may use it and whether it's switched on for climbs):
##
##   {"format": 1, "rooms": [
##     {"id": "painted_1", "name": "Broken colonnade", "role": "combat",
##      "from": 2, "flip": true, "towers": [], "on": true,
##      "grid": [".............", ".o.o.....o.o.", ...]},
##     ...]}
##
##   role    "start", "combat", "stair" or "puzzle" (its job)
##   from    the first floor it can appear on
##   flip    whether the floor planner may flip it
##   towers  the tower ids that may use it ([] for every tower)
##   on      used in climbs (once it passes the checks, room_check.gd)
##   puzzle, tier   a puzzle room's puzzle ("eyes" or "plates") and tier (1 or 2)
##   grid    its tiles, one string per row (the legend is in rooms.gd)
##
## Two files, read at startup, the second on top of the first (the same
## pattern as the Data editor's and Arrange mode's files):
##   res://data/rooms_custom.json  the project's file: run from the Godot
##       editor, Save writes here, so the change shows in GitHub Desktop to
##       commit. Committed, the rooms are in every copy of the game, the web
##       build included.
##   user://rooms_custom.json  this device's own (the web build, a phone):
##       rooms made or changed here, and project rooms deleted here
##       ("deleted"). Copy rooms hands them on (to Claude, or to Paste rooms
##       on the computer) to make them part of the project.

const Rooms := preload("res://scripts/rooms.gd")
const TestRun := preload("res://scripts/test_run.gd")
const Check := preload("res://scripts/room_check.gd")
const Towers := preload("res://scripts/towers.gd")

const PROJECT_PATH := "res://data/rooms_custom.json"
const LOCAL_PATH := "user://rooms_custom.json"
const FORMAT := 1
## The first floor a new room of each job can appear on (as the built-ins).
const FROM := {"start": 1, "stair": 1, "combat": 2, "puzzle": 2}
const TEXT := {
	"not_rooms": "That isn't a rooms file (it should start with { and list \"rooms\").",
	"no_rooms": "No rooms in it.",
}

## Where the files are (tests point these elsewhere).
static var project_path := PROJECT_PATH
static var local_path := LOCAL_PATH
## -1: write the project file when run from the Godot editor; 0 / 1 to force (tests).
static var project_write := -1

static var project: Array = []  # the project file's rooms
static var rooms: Array = []  # every painter room in force (the project's, then this device's on top)
static var deleted: Array = []  # project rooms deleted on this device (ids)
static var problems: Array = []  # what the files had that couldn't be read
static var dirty := false  # changed since the last save
static var started := false


# --- startup ---------------------------------------------------------------------

## Reads both files and puts the rooms that pass into play (main.gd calls
## this first thing). Safe to call again.
static func startup() -> void:
	if Engine.has_meta("sixfold_test") and local_path == LOCAL_PATH:
		local_path = TestRun.path("user://test_rooms_custom.json")  # (tests never touch the real files)
		project_path = TestRun.path("user://test_rooms_project.json")
	load_files()
	started = true


static func load_files() -> void:
	problems.clear()
	project = _read(project_path).get("rooms", [])
	var mine := _read(local_path)
	deleted = mine.get("deleted", []).filter(func(i): return i is String)
	var local: Array = mine.get("rooms", [])
	rooms = []
	for r in project:
		if not r["id"] in deleted:
			rooms.append(r.duplicate(true))
	for r in local:
		var at := index_of(r["id"])
		if at >= 0:
			rooms[at] = r.duplicate(true)
		else:
			rooms.append(r.duplicate(true))
	dirty = false
	apply()


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(text) if text.strip_edges() != "" else {}
	if not data is Dictionary or not data.get("rooms", []) is Array:
		problems.append("%s isn't a rooms file" % path)
		return {}
	var list: Array = []
	for r in data.get("rooms", []):
		var n := normalize(r)
		if n.is_empty() or n["id"] == "":
			problems.append("%s: a room couldn't be read" % path)
		elif not list.any(func(o): return o["id"] == n["id"]):
			list.append(n)
	data["rooms"] = list
	return data


## Puts the rooms that are switched on and pass their checks into the floor
## planner's pool (rooms.gd custom), each with the towers it passes in.
static func apply() -> void:
	var pool: Array = []
	for r in rooms:
		if not bool(r.get("on", false)):
			continue
		var ok := Check.ok_towers(r)
		if ok.is_empty():
			continue
		var def: Dictionary = r.duplicate(true)
		def["ok"] = ok
		pool.append(def)
	Rooms.custom = pool


# --- the rooms -------------------------------------------------------------------

## A room read from a file or pasted, tidied (missing fields filled in,
## numbers kept in bounds), or {} if it can't be a room.
static func normalize(r) -> Dictionary:
	if not r is Dictionary or not r.get("grid", null) is Array:
		return {}
	var grid: Array = []
	for row in r["grid"]:
		if not row is String:
			return {}
		grid.append(row)
	if grid.is_empty():
		return {}
	var role: String = str(r.get("role", "combat"))
	if not role in Check.ROLES:
		role = "combat"
	var out := {
		"id": str(r.get("id", "")),
		"name": str(r.get("name", "")),
		"role": role,
		"from": clampi(int(r.get("from", FROM[role])), 1, Towers.SUMMIT - 1),
		"flip": bool(r.get("flip", role != "stair")) and role != "stair",
		"towers": [],
		"on": bool(r.get("on", false)),
		"grid": grid,
	}
	var towers = r.get("towers", [])
	if towers is Array:
		for t in towers:
			if t is String and Towers.TOWERS.has(t) and not t in out["towers"]:
				out["towers"].append(t)
	if role == "puzzle":
		out["puzzle"] = str(r.get("puzzle", "eyes")) if str(r.get("puzzle", "eyes")) in Check.PUZZLES else "eyes"
		out["tier"] = clampi(int(r.get("tier", 1)), 1, 2)
	if out["id"] == "" or is_builtin(out["id"]):
		out["id"] = ""
	if out["name"] == "":
		out["name"] = display_name(out) if out["id"] != "" else "New room"
	return out


static func is_builtin(id: String) -> bool:
	return Rooms.ROOMS.any(func(r): return r["id"] == id)


static func index_of(id: String) -> int:
	for i in rooms.size():
		if rooms[i]["id"] == id:
			return i
	return -1


static func find(id: String) -> Dictionary:
	var i := index_of(id)
	return rooms[i] if i >= 0 else {}


## A room's name: its own, or a built-in's id made readable ("pillared_hall" -> "Pillared hall").
static func display_name(r: Dictionary) -> String:
	var n: String = r.get("name", "")
	if n != "":
		return n
	var words := String(r.get("id", "room")).replace("_", " ")
	return words.left(1).to_upper() + words.substr(1)


## An id no room uses yet.
static func new_id() -> String:
	var n := rooms.size() + 1
	while is_builtin("painted_%d" % n) or index_of("painted_%d" % n) >= 0:
		n += 1
	return "painted_%d" % n


## A name no room uses yet, from `base` ("Pillared hall copy", "... copy 2").
static func free_name(base: String) -> String:
	var name := base
	var n := 2
	while rooms.any(func(r): return r["name"] == name):
		name = "%s %d" % [base, n]
		n += 1
	return name


## Adds a room (given an id if it has none). Returns it.
static func add(r: Dictionary) -> Dictionary:
	var room := r.duplicate(true)
	if room.get("id", "") == "" or is_builtin(room["id"]) or index_of(room["id"]) >= 0:
		room["id"] = new_id()
	rooms.append(room)
	changed()
	return room


static func remove(id: String) -> void:
	var i := index_of(id)
	if i < 0:
		return
	rooms.remove_at(i)
	if project.any(func(r): return r["id"] == id) and not id in deleted:
		deleted.append(id)
	changed()


## Something about the rooms changed: they're back in play (or out) at once,
## and wait to be saved.
static func changed() -> void:
	dirty = true
	apply()


# --- saving ---------------------------------------------------------------------------

## Saves go to the project's file when run from the Godot editor, else to this device's.
static func writes_project() -> bool:
	if project_write >= 0:
		return project_write == 1
	return OS.has_feature("editor")


## Writes the rooms. Returns the file written ("" if it failed).
static func save() -> String:
	var ok := false
	var where := ""
	if writes_project():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(project_path.get_base_dir()))
		ok = _write_file(project_path, {"format": FORMAT, "rooms": _clean(rooms)})
		where = project_path
		if ok:
			project = rooms.duplicate(true)
			deleted.clear()
			if FileAccess.file_exists(local_path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(local_path))  # (all in the project's file now)
	else:
		# Only what differs from the project's file, and what was deleted here.
		var mine: Array = []
		for r in rooms:
			var p: Array = project.filter(func(o): return o["id"] == r["id"])
			if p.is_empty() or JSON.stringify(p[0]) != JSON.stringify(r):
				mine.append(r)
		var data := {"format": FORMAT, "rooms": _clean(mine)}
		if not deleted.is_empty():
			data["deleted"] = deleted.duplicate()
		ok = _write_file(local_path, data)
		where = local_path
	if ok:
		dirty = false
	return where if ok else ""


static func _write_file(path: String, data: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t") + "\n")
	f.close()
	return true


## The rooms as kept in the file: only the fields that belong there.
static func _clean(list: Array) -> Array:
	var out: Array = []
	for r in list:
		var c := {}
		for k in ["id", "name", "role", "from", "flip", "towers", "on", "puzzle", "tier", "grid"]:
			if r.has(k):
				c[k] = r[k]
		out.append(c)
	return out


# --- copy and paste ---------------------------------------------------------------------

## Every painter room (or those with these ids), as a rooms file (Copy rooms).
static func export_text(ids: Array = []) -> String:
	var list: Array = rooms.filter(func(r): return ids.is_empty() or r["id"] in ids)
	return JSON.stringify({"format": FORMAT, "rooms": _clean(list)}, "\t")


## Paste rooms: a rooms file, a list of rooms or a single room. A room with
## the id of one you have replaces it; the rest are added. Returns
## {"added": n, "updated": n, "error": "" or why nothing could be read, "ids": [...]}.
static func import_text(text: String) -> Dictionary:
	var json := JSON.new()
	var data = json.data if text.strip_edges() != "" and json.parse(text.strip_edges()) == OK else null
	var list: Array = []
	if data is Dictionary and data.has("rooms") and data["rooms"] is Array:
		list = data["rooms"]
	elif data is Dictionary and data.has("grid"):
		list = [data]
	elif data is Array:
		list = data
	else:
		return {"added": 0, "updated": 0, "error": TEXT["not_rooms"], "ids": []}
	var added := 0
	var updated := 0
	var ids: Array = []
	for r in list:
		var n := normalize(r)
		if n.is_empty():
			continue
		var at := index_of(n["id"]) if n["id"] != "" else -1
		if at >= 0:
			rooms[at] = n
			updated += 1
		else:
			if n["id"] == "":
				n["id"] = new_id()
			rooms.append(n)
			deleted.erase(n["id"])
			added += 1
		ids.append(n["id"])
	if added + updated == 0:
		return {"added": 0, "updated": 0, "error": TEXT["no_rooms"], "ids": []}
	changed()
	return {"added": added, "updated": updated, "error": "", "ids": ids}
