extends RefCounted
## Test runs keep their own files. Every user:// path a test touches (save
## slots, the Data editor's overrides, the room painter's rooms, the layout,
## the test's own scratch files) goes through path(), which in a test run
## puts it in a folder of that run's own: user://test_runs/<process id>/.
## So two Godot processes running tests at once never share a file.
##
## tests/smoke_test.gd calls begin() first thing (before anything loads) and
## finish() as it quits, which removes the folder. Outside tests, path()
## gives back what it was given.

const ROOT := "user://test_runs/"
## A folder left by a run that never finished (it crashed or was stopped) is
## cleared by the next run once it's this old (seconds).
const STALE := 6 * 3600


static func on() -> bool:
	return Engine.has_meta("sixfold_test")


## This run's folder ("user://" outside a test run).
static func dir() -> String:
	return String(Engine.get_meta("sixfold_test_dir", "user://"))


## A user:// path, moved into this run's folder in a test run.
static func path(p: String) -> String:
	if not on() or not p.begins_with("user://") or p.begins_with(dir()):
		return p
	return dir() + p.trim_prefix("user://")


## Starts a test run: the test flag and this run's own empty folder.
static func begin() -> void:
	_clear_stale()
	var d := ROOT + "%d/" % OS.get_process_id()
	_remove_tree(d)  # (a folder of an old run with the same process id)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(d))
	var stamp := FileAccess.open(d + "started", FileAccess.WRITE)
	if stamp != null:
		stamp.store_string(Time.get_datetime_string_from_system())
		stamp.close()
	Engine.set_meta("sixfold_test_dir", d)
	Engine.set_meta("sixfold_test", true)


## Ends a test run: its folder goes.
static func finish() -> void:
	if Engine.has_meta("sixfold_test_dir"):
		_remove_tree(dir())


static func _clear_stale() -> void:
	var root := DirAccess.open(ROOT)
	if root == null:
		return
	var now := int(Time.get_unix_time_from_system())
	for sub in root.get_directories():
		var stamp := ROOT + sub + "/started"
		var age := now - int(FileAccess.get_modified_time(stamp)) if FileAccess.file_exists(stamp) else STALE + 1
		if age > STALE:
			_remove_tree(ROOT + sub + "/")


static func _remove_tree(d: String) -> void:
	var da := DirAccess.open(d)
	if da == null:
		return
	for f in da.get_files():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(d.path_join(f)))
	for sub in da.get_directories():
		_remove_tree(d.path_join(sub) + "/")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(d))
