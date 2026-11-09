extends RefCounted
## Climber slots: up to six climbers, each a separate climber with their own
## everything. Each slot is its own save file (user://climber_1.cfg ...
## climber_6.cfg) holding that climber's profile (profile.gd: marks, essence,
## crystals, the train, heirlooms, look and name, Record, Makers, path and
## flow, the Unbound, secret bond, lost pieces, Provings, pact book) and what
## the Entity has told them (guide.gd: the tips said and the Archive).
##
## The settings file (user://sixfold.cfg) is shared by every climber: the
## settings (volume, HUD size, lighting, the "To crystals" share...),
## controller setup (pad.gd), tips on or off, and which slot was played last
## ("slots" section).
##
## Every profile keeps the path it was loaded from (profile.gd save_path), so
## a climber only ever writes their own file: one slot's save can never land
## in another's.
##
## Saves from before there were slots (everything in sixfold.cfg) move into
## slot 1 the first time the game starts (migrate()): a copy of the old file
## is kept as it was (BACKUP), the climber's sections are written to slot 1
## and read back, and only then does the settings file drop them.
##
## Tests (Engine "sixfold_test") use their own files, never the real saves.

const MAX := 6
const SETTINGS := "user://sixfold.cfg"
const SLOT := "user://climber_%d.cfg"
const BACKUP := "user://sixfold_before_slots.cfg"
const TEST_SETTINGS := "user://smoke_slots.cfg"
const TEST_SLOT := "user://smoke_slot_%d.cfg"
const TEST_BACKUP := "user://smoke_slots_backup.cfg"
## Sections of the settings file shared by every climber (anything else in an
## old save was the climber's), and the shared keys of the "guide" section.
const SHARED := ["settings", "pad", "slots"]
const SHARED_GUIDE := ["on"]

## The settings file already migrated this run, and the slot played last.
static var _migrated_for := ""
static var _current := 0
static var _current_for := ""


static func testing() -> bool:
	return Engine.has_meta("sixfold_test")


static func settings_path() -> String:
	return TEST_SETTINGS if testing() else SETTINGS


static func backup_path() -> String:
	return TEST_BACKUP if testing() else BACKUP


static func valid(slot: int) -> bool:
	return slot >= 1 and slot <= MAX


## A slot's save file.
static func path(slot: int) -> String:
	return (TEST_SLOT if testing() else SLOT) % clampi(slot, 1, MAX)


## A climber lives in this slot (their file holds a profile or a look).
static func exists(slot: int) -> bool:
	if not valid(slot) or not FileAccess.file_exists(path(slot)):
		return false
	var cfg := ConfigFile.new()
	return cfg.load(path(slot)) == OK and (cfg.has_section("profile") or cfg.has_section("look"))


## The slots with a climber in them, in order.
static func filled() -> Array:
	var out: Array = []
	for i in range(1, MAX + 1):
		if exists(i):
			out.append(i)
	return out


static func any() -> bool:
	return not filled().is_empty()


## The first slot with no climber (0 with all six full: there's no seventh).
static func first_empty() -> int:
	for i in range(1, MAX + 1):
		if not exists(i):
			return i
	return 0


## The slot played last (Continue plays it); 1 for a brand-new player.
static func current() -> int:
	migrate()
	if _current_for != settings_path():
		_current_for = settings_path()
		var cfg := ConfigFile.new()
		cfg.load(settings_path())
		_current = int(cfg.get_value("slots", "current", 1))
		if not valid(_current):
			_current = 1
	return _current


static func set_current(slot: int) -> void:
	if not valid(slot):
		return
	migrate()
	var cfg := ConfigFile.new()
	cfg.load(settings_path())
	cfg.set_value("slots", "current", slot)
	cfg.save(settings_path())
	_current = slot
	_current_for = settings_path()


## The current climber's save file.
static func current_path() -> String:
	return path(current())


## Forgets a climber for good: their file is removed. If they were the
## current climber, the most recently played of the others becomes current
## (or the slot stays current, empty, if there are none).
static func delete(slot: int) -> void:
	if not valid(slot):
		return
	if FileAccess.file_exists(path(slot)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path(slot)))
	if slot == current():
		var next := slot
		var latest := -1
		for i in filled():
			if played(i) > latest:
				latest = played(i)
				next = i
		set_current(next)


## Clears whatever is left in an empty slot (a new climber starts there clean).
static func clear(slot: int) -> void:
	if valid(slot) and not exists(slot) and FileAccess.file_exists(path(slot)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path(slot)))


## When a slot's climber was last saved (unix seconds; 0 if never).
static func played(slot: int) -> int:
	if not FileAccess.file_exists(path(slot)):
		return 0
	var cfg := ConfigFile.new()
	if cfg.load(path(slot)) == OK and cfg.has_section_key("slot", "played"):
		return int(cfg.get_value("slot", "played", 0))
	return int(FileAccess.get_modified_time(path(slot)))  # (a migrated save, not saved since)


## A slot's climber, loaded to look at (it never saves); null if empty.
static func peek(slot: int):
	if not exists(slot):
		return null
	var prof = load("res://scripts/profile.gd").new()
	prof.saving = false
	prof.save_path = path(slot)
	prof.load_save()
	return prof


## Moves a save from before there were slots into slot 1 (or the first free
## slot, if slot 1 is somehow taken). Runs once; safe to call any time.
static func migrate() -> void:
	var sp := settings_path()
	if _migrated_for == sp:
		return
	_migrated_for = sp
	var cfg := ConfigFile.new()
	if cfg.load(sp) != OK or cfg.has_section_key("slots", "version"):
		return  # no save at all (a brand-new player), or done before
	var out := ConfigFile.new()
	for sec in cfg.get_sections():
		if sec in SHARED:
			continue
		for key in cfg.get_section_keys(sec):
			if sec == "guide" and key in SHARED_GUIDE:
				continue
			out.set_value(sec, key, cfg.get_value(sec, key))
	if not out.get_sections().is_empty():
		var to := 1 if not FileAccess.file_exists(path(1)) else first_empty()
		if to == 0:
			return  # (no room: everything stays where it is)
		# A copy of the old file, exactly as it was.
		if not FileAccess.file_exists(backup_path()):
			DirAccess.copy_absolute(ProjectSettings.globalize_path(sp), ProjectSettings.globalize_path(backup_path()))
		if out.save(path(to)) != OK:
			_migrated_for = ""  # (try again next time; nothing was changed)
			return
		var check := ConfigFile.new()
		if check.load(path(to)) != OK or check.get_sections().size() != out.get_sections().size():
			_migrated_for = ""
			return
		# The climber is safe in their slot: the settings file keeps what's shared.
		for sec in cfg.get_sections():
			if sec == "guide":
				for key in cfg.get_section_keys(sec):
					if not key in SHARED_GUIDE:
						cfg.erase_section_key(sec, key)
			elif not sec in SHARED:
				cfg.erase_section(sec)
		cfg.set_value("slots", "current", to)
	cfg.set_value("slots", "version", 1)
	cfg.save(sp)
	_current_for = ""  # (read the current slot again)


## Tests: forget what this run has read (after changing the files by hand).
static func forget() -> void:
	_migrated_for = ""
	_current_for = ""
	_current = 0
