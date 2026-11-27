extends RefCounted
## Sound fixes from the owner's listening: fire's sound ("burn", which
## rang like a slot machine when it played many times a second) is a soft
## crackle in several takes, and it plays at most once a quarter second
## (audio.gd GAP_MS) however many things call for it. (The music, once
## slowed here, was replaced: tests/parts/music.gd.)
##
## And the sound review: every sound in the bank has its files and is played
## somewhere (an unused one only weighs on the web build); the glint (the
## monster's tell before a blow) means danger only, while good things ring
## the chime; refusals have their own dull "denied", not the page's back;
## a new mark (and the body's big turns) has its own sound instead of a
## weapon's crit; doors creak or grind by what they're made of; the stair's
## ward sounds like essence, its gate like iron; levels trimmed in data stay
## small; the gong is compressed like every other effect, and a full rebuild
## keeps it. Run by smoke_test.gd (_part_tests).

const Bank := preload("res://scripts/sound_bank.gd")
const Doors := preload("res://scripts/doors.gd")
const MenuScript := preload("res://scripts/menu.gd")

var t


func run(smoke) -> void:
	t = smoke
	print("sound fixes: a fire crackle kept from rattling; the sound review")
	await _fire()
	_bank_files()
	_bank_used()
	_glint_is_danger()
	_levels()
	await _new_sounds()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _fire() -> void:
	var A = t.main.audio
	var keep: float = A.sound_level
	A.sound_level = 1.0
	_check(A.streams.has("burn") and A.streams["burn"].size() >= 4, "fire's crackle comes in several takes (%d), so repeats don't match" % A.streams.get("burn", []).size())
	# Called every frame for a second (a Flameblade swinging at full heat in a
	# burning room, say): it plays about four times, not sixty.
	A.last_played.erase("burn")
	var plays := 0
	var calls := 0
	var last := -1
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < 1000:
		t.main.sfx("burn", 1.3, -8.0)
		calls += 1
		var at := int(A.last_played.get("burn", -1))
		if at != last:
			plays += 1
			last = at
		await t.process_frame
	_check(calls >= 6 and plays >= 3 and plays <= 5,  # (a busy machine draws fewer frames in the second: the cap is what counts)
		 "called %d times in a second, fire's crackle played %d times (at most once a quarter second)" % [calls, plays])
	# Other sounds aren't held back like that.
	A.last_played.erase("hit")
	t.main.sfx("hit")
	var first := int(A.last_played.get("hit", -1))
	await t._wait(0.08)
	t.main.sfx("hit")
	_check(first >= 0 and int(A.last_played.get("hit", -1)) > first, "...while other sounds still play as often as before")
	A.sound_level = keep


## Every sound and loop in the bank has its files, and they load.
func _bank_files() -> void:
	var missing: Array = []
	for name in Bank.SFX:
		if Bank.SFX[name].is_empty():
			missing.append(name)
		for path in Bank.SFX[name]:
			if not ResourceLoader.exists(path):
				missing.append(path)
	for name in Bank.MUSIC:
		if not ResourceLoader.exists(Bank.MUSIC[name]):
			missing.append(Bank.MUSIC[name])
	_check(missing.is_empty(), "every sound in the bank has its files (%d sounds; missing: %s)" % [Bank.SFX.size(), ", ".join(missing)])
	var A = t.main.audio
	var empty: Array = Bank.SFX.keys().filter(func(n): return not A.has_sound(n))
	_check(empty.is_empty(), "...and every one loads (%s)" % ", ".join(empty))
	# The effects are QOA-compressed on import (a fifth of the size on the
	# phone); the gong, cut by hand, was the one left uncompressed.
	var raw: Array = []
	for name in Bank.SFX:
		for path in Bank.SFX[name]:
			if not "compress/mode=2" in FileAccess.get_file_as_string(String(path) + ".import"):
				raw.append(String(path).get_file())
	_check(raw.is_empty(), "every effect is compressed on import (not: %s)" % ", ".join(raw))
	var build := FileAccess.get_file_as_string("res://tools/build_audio.py")
	_check("HAND_MADE = {\"gong\"" in build, "a full rebuild of the sounds keeps the hand-cut gong (build_audio.py HAND_MADE)")
	var silent: Array = t._silent_sounds()
	_check(silent.is_empty(), "every sound the code plays is in the bank (missing: %s)" % ", ".join(silent))


## The scripts' text, every .gd under scripts/ (the bank itself left out).
func _script_text() -> String:
	var out := PackedStringArray()
	var dirs: Array = ["res://scripts"]
	while not dirs.is_empty():
		var d: String = dirs.pop_back()
		for sub in DirAccess.get_directories_at(d):
			dirs.append(d + "/" + sub)
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".gd") and f != "sound_bank.gd":
				out.append(FileAccess.get_file_as_string(d + "/" + f))
	return "\n".join(out)


## No sound in the bank goes unplayed: each is named in the code, or is a
## creature's own (hurt_/kill_/warn_/roar_ + its kind: main.gd sfx_kind) or
## a weapon's heavy finisher (player.gd adds "_heavy").
func _bank_used() -> void:
	var text := _script_text()
	var kinds: Dictionary = preload("res://scripts/enemy.gd").MATERIAL
	var heavy := {}
	var W := preload("res://scripts/weapons.gd")
	for id in W.WEAPONS:
		if W.WEAPONS[id].has("sound"):
			heavy[String(W.WEAPONS[id]["sound"]) + "_heavy"] = true
	var unused: Array = []
	for name in Bank.SFX:
		var n := String(name)
		if ("\"%s\"" % n) in text or heavy.has(n):
			continue
		var bits := n.split("_", true, 1)
		if bits.size() == 2 and bits[0] in ["hurt", "kill", "warn", "roar"] and kinds.has(bits[1]):
			continue
		unused.append(n)
	_check(unused.is_empty(), "no sound in the bank goes unplayed (unused: %s)" % ", ".join(unused))
	_check(not Bank.SFX.has("spell_unmaking"), "...the old unused spell_unmaking is gone from the bank and the build")


## The glint is the tell before a blow: only a monster's or a trap's wind-up
## (and a bad room's banner) plays it. Good things chime.
func _glint_is_danger() -> void:
	var allowed := ["enemy.gd", "riveter.gd", "traps.gd", "statues.gd", "mirror.gd", "main.gd"]
	var others: Array = []
	var dirs: Array = ["res://scripts"]
	while not dirs.is_empty():
		var d: String = dirs.pop_back()
		for sub in DirAccess.get_directories_at(d):
			dirs.append(d + "/" + sub)
		for f in DirAccess.get_files_at(d):
			if f.ends_with(".gd") and not f in allowed and "sfx(\"glint\"" in FileAccess.get_file_as_string(d + "/" + f):
				others.append(f)
	_check(others.is_empty(), "the glint warns of danger only (also played by: %s)" % ", ".join(others))
	var main_text := FileAccess.get_file_as_string("res://scripts/main.gd")
	_check(main_text.count("sfx(\"glint\"") == 1, "...in main.gd only a bad room's banner glints (%d)" % main_text.count("sfx(\"glint\""))
	_check(String(MenuScript.FEEDBACK["choose"]["sound"]) == "chime" and t.main.audio.has_sound("chime") and t.main.audio.streams["chime"].size() >= 3,
		"a choice in the menus chimes (three takes), not the monster's glint")


## Levels trimmed in data (audio.gd TRIM) stay small and name real sounds;
## menu sounds stay soft and the summit's bells loud.
func _levels() -> void:
	var A = t.main.audio
	var bad: Array = []
	for n in A.TRIM:
		if not A.has_sound(n) or absf(float(A.TRIM[n])) > 6.0:
			bad.append(n)
	_check(bad.is_empty(), "the trims are small and name sounds in the bank (%s)" % ", ".join(bad))
	_check(float(A.TRIM.get("ui_back", 0.0)) < 0.0 and float(A.TRIM.get("ui_open", 0.0)) > 0.0 and float(A.TRIM.get("summit_win", 0.0)) > 0.0,
		"going back a page is softer, opening one no longer 6 dB under closing it, and a summit's bells are lifted")


## The new action sounds fire where they belong.
func _new_sounds() -> void:
	var main = t.main
	var A = main.audio
	var keep: float = A.sound_level
	A.sound_level = 1.0
	# A refusal answers with "denied" (the train's and the Loadout's "can't").
	var t0 := Time.get_ticks_msec()
	A.last_played.erase("denied")
	main.menu.feedback(MenuScript.DONE_KINDS.get("denied", "make"), "denied")
	_check(MenuScript.DONE_KINDS.get("denied", "") == "back" and int(A.last_played.get("denied", -1)) >= t0, "a refusal answers with its own dull sound (and the dim flash)")
	var tp := FileAccess.get_file_as_string("res://scripts/train_page.gd")
	_check(not tp.contains("[\"cant\"] % why, \"\", \"ui_back\")") and tp.contains("\"crystal\")"),
		"...the train's refusals are 'denied' and the Exchange trades crystals with glass, not the anvil")
	# A new mark: its own sound (not a crit), the victory's bells first at a summit.
	await t._wait(0.1)
	A.last_played.erase("mark_form")
	A.last_played.erase("crit")
	main._mark_sound(false)
	await t._frames(3)
	_check(A.last_played.has("mark_form") and not A.last_played.has("crit"), "a mark forming rings its own sound, not a weapon's crit")
	# A sound later, in real time even in hit-pause.
	A.last_played.erase("chime")
	main.sfx_after(0.05, "chime")
	await t._wait(0.3)
	_check(A.last_played.has("chime"), "a sound can follow a moment later (a guardian's body landing after its cry)")
	# Doors: wood creaks, stone grinds.
	_check(Doors._stone({"style": "puzzle"}) and Doors._stone({"style": "sealed"}) and not Doors._stone({"style": "plank"}) and A.has_sound("door_open") and A.has_sound("door_close"),
		"a wooden door creaks open and knocks shut; a stone slab grinds")
	# The stair's barrier: the gate is iron, the ward is the tower's essence.
	var cs = main.climb_shape
	if cs != null and is_instance_valid(cs):
		var bar_was: Dictionary = cs.bar
		cs.bar = {"kind": "ward"}
		A.last_played.erase("use_ward")
		A.last_played.erase("slam")
		cs._barrier_sound("up")
		var ward_ok: bool = A.last_played.has("use_ward") and not A.last_played.has("slam")
		await t._wait(0.06)
		cs.bar = {"kind": "gate"}
		A.last_played.erase("slam")
		cs._barrier_sound("up")
		_check(ward_ok and A.last_played.has("slam") and A.last_played.has("step_chain"), "the stair's ward hums up like essence; the iron gate clangs down with its chains")
		cs.bar = bar_was
	# The stair's growth sound counts every mark's step.
	var prof = main.profile
	var before: int = main.growth_count()
	var bonds_was: Dictionary = prof.bonds.duplicate(true)
	prof.bonds["sound_test"] = {"id": "stormcaller", "xp": 1740.0, "faint": false}  # (a stand-in mark, removed again below)
	_check(main.growth_count() > before, "a mark growing a step is counted, so the stair can ring it (%d -> %d)" % [before, main.growth_count()])
	prof.bonds = bonds_was
	A.sound_level = keep
