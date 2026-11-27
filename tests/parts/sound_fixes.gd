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
## keeps it.
##
## And the second round: effects with nothing above 10 kHz are built at
## 22.05 kHz (smaller on the phone); a sound from a place in the world
## (monsters, traps, doors, impacts, spells landing) is quieter the farther
## it is (audio.gd DISTANCE), while the menus, the climber's own sounds and
## the big moments stay at full; offers of cards rustle like cards instead of
## the "ready" click; the knight's armour rattle is his alone and "slam" is
## a heavy blow you dodge (fights beginning have "on_guard", scenery in
## stone "stone_thud"); the wind comes in three recorded takes. Run by
## smoke_test.gd (_part_tests).

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
	print("sound fixes: smaller files, sound by distance, cards, sounds of their own, varied wind")
	_small_files()
	await _by_distance()
	_cards()
	_own_users()
	_wind()


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
			if f.ends_with(".gd") and not f in allowed and _glint_re().search(FileAccess.get_file_as_string(d + "/" + f)) != null:
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
		var phys_was: bool = cs.is_physics_processing()
		cs.set_physics_process(false)  # (a stand-in barrier with only its kind: the stair's own tick left out)
		cs.bar = {"kind": "ward"}
		A.last_played.erase("use_ward")
		A.last_played.erase("stone_thud")
		cs._barrier_sound("up")
		var ward_ok: bool = A.last_played.has("use_ward") and not A.last_played.has("stone_thud")
		await t._wait(0.06)
		cs.bar = {"kind": "gate"}
		A.last_played.erase("stone_thud")
		cs._barrier_sound("up")
		_check(ward_ok and A.last_played.has("stone_thud") and A.last_played.has("step_chain"), "the stair's ward hums up like essence; the iron gate thuds down in stone with its chains (no beast's slam)")
		cs.bar = bar_was
		cs.set_physics_process(phys_was)
	# The stair's growth sound counts every mark's step.
	var prof = main.profile
	var before: int = main.growth_count()
	var bonds_was: Dictionary = prof.bonds.duplicate(true)
	prof.bonds["sound_test"] = {"id": "stormcaller", "xp": 1740.0, "faint": false}  # (a stand-in mark, removed again below)
	_check(main.growth_count() > before, "a mark growing a step is counted, so the stair can ring it (%d -> %d)" % [before, main.growth_count()])
	prof.bonds = bonds_was
	A.sound_level = keep


## A call that plays the glint, by distance or not: sfx("glint" or sfx_at(<where>, "glint".
func _glint_re() -> RegEx:
	var re := RegEx.new()
	re.compile("sfx(_at)?\\([^\"\\n]*\"glint\"")
	return re


## The WAV file's own sample rate (its header, bytes 24..27).
func _wav_rate(path: String) -> int:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return 0
	f.seek(24)
	return f.get_32()


## Effects with nothing above 10 kHz are written at 22.05 kHz (about 40% of
## them: thuds, roars, stone, wind), they load at that rate, and on the
## phone they weigh less a second than the ones kept at 32 kHz.
func _small_files() -> void:
	var A = t.main.audio
	var small := {}
	var rates := {}
	for name in Bank.SFX:
		for path in Bank.SFX[name]:
			var r := _wav_rate(String(path))
			rates[r] = int(rates.get(r, 0)) + 1
			if r == 22050:
				small[name] = true
	_check(small.size() >= Bank.SFX.size() * 0.3 and rates.size() <= 2 and rates.has(22050) and rates.has(32000),
		"about 40%% of the effects are built at 22.05 kHz, the rest at 32 (%d of %d sounds; files by rate: %s)" % [small.size(), Bank.SFX.size(), str(rates)])
	var low: Array = ["slam", "stone_thud", "gust", "regard", "gong"]
	_check(low.all(func(n): return small.has(n)), "...the low ones among them: %s" % ", ".join(low.filter(func(n): return small.has(n))))
	_check(not small.has("glint") and not small.has("chime") and not small.has("hit_light"), "...while bright ones (the glint, the chime, a light hit) keep 32 kHz")
	# Loaded, they play at their own rate, and weigh less a second.
	var per_s := {22050: [], 32000: []}
	for name in ["slam", "stone_thud", "gust", "kill_wyvern", "glint", "chime", "hit_light", "parry"]:
		for s in A.streams.get(name, []):
			if s is AudioStreamWAV and s.get_length() > 0.0 and per_s.has(int(s.mix_rate)):
				per_s[int(s.mix_rate)].append(float(s.data.size()) / s.get_length())
	var avg := func(a: Array) -> float: return a.reduce(func(x, y): return x + y, 0.0) / maxf(1.0, a.size())
	_check(not per_s[22050].is_empty() and not per_s[32000].is_empty() and avg.call(per_s[22050]) < avg.call(per_s[32000]) * 0.8,
		"...they load at 22.05 kHz and take about a third less a second (%.0f bytes/s, against %.0f at 32 kHz)" % [avg.call(per_s[22050]), avg.call(per_s[32000])])
	var build := FileAccess.get_file_as_string("res://tools/build_audio.py")
	_check("SR_SMALL = 22050" in build and "HIGH_DB = -40.0" in build and "def shrink_existing" in build, "...and the build tool writes them so by measuring (build_audio.py SR_SMALL, HIGH_DB)")


## A world sound is quieter the farther it is from the climber; the menus,
## the climber's own sounds and the big moments are not.
func _by_distance() -> void:
	var A = t.main.audio
	var keep: float = A.sound_level
	A.sound_level = 1.0
	var ear := Vector2(1000, 1000)
	A.listener = ear
	var at_db := func(dist: float) -> float:
		A.last_played.erase("hit")
		A.play_at("hit", ear + Vector2(dist, 0), 1.0, 0.0, 0.0)
		return float(A.last_db.get("hit", 99.0))
	var near: float = at_db.call(60.0)
	var edge: float = at_db.call(200.0)
	var mid: float = at_db.call(550.0)
	var far: float = at_db.call(900.0)
	var off: float = at_db.call(2500.0)
	_check(absf(near) < 0.01 and absf(edge) < 0.01, "a sound beside the climber, or 200 px off, is at full (%.1f, %.1f dB)" % [near, edge])
	_check(mid < -6.0 and mid > -12.0 and absf(far + 18.0) < 0.01 and absf(off + 18.0) < 0.01,
		"...fading to -18 dB at 900 px (%.1f dB at 550, %.1f at 900) and no lower beyond it: an off-screen tell is still heard (%.1f at 2500)" % [mid, far, off])
	# A monster's glint near you stays clear: enemy.gd's glint plays by distance, at full close by.
	A.last_played.erase("glint")
	A.play_at("glint", ear + Vector2(120, 0), 1.0, 0.0, 0.0)
	_check(absf(float(A.last_db.get("glint", 99.0)) - float(A.TRIM.get("glint", 0.0))) < 0.01, "a monster's glint 120 px away rings at full")
	# Sounds with no place stay at full, wherever the listener is.
	A.last_played.erase("ui")
	A.play("ui_confirm")
	A.last_played.erase("regard")
	A.play("regard", 1.0, 0.0, 0.0)
	_check(absf(float(A.last_db.get("ui_confirm", 99.0)) - float(A.TRIM.get("ui_confirm", 0.0))) < 0.01 and absf(float(A.last_db.get("regard", 99.0))) < 0.01,
		"menu sounds and the big moments (the Regard) are not touched")
	A.listener = Vector2.INF
	A.sound_level = keep
	# The world's callers pass their place; the big moments and the climber's own do not.
	var enemy := FileAccess.get_file_as_string("res://scripts/enemy.gd")
	_check(enemy.count("main.sfx(\"") == enemy.count("main.sfx(\"roar_") and enemy.count("main.sfx_at(global_position, ") >= 60,
		"a monster's tells, blows and cries come from where it is; only a guardian's roar is at full (%d by distance)" % enemy.count("main.sfx_at(global_position, "))
	_check("main.sfx_kind_at(global_position, \"hurt\"" in enemy, "...its cry when struck too")
	var others := {"traps.gd": "main.sfx_at(at, sound", "doors.gd": "main.sfx_at(d[\"rect\"].get_center(), \"door_open\"", "projectile.gd": "main.sfx_at(global_position, \"arrow_hit\"",
		"reactions.gd": "main.sfx_at(at, String(r[\"sound\"])", "main.gd": "sfx_at(e.global_position, kill_sound"}
	for f in others:
		_check(others[f] in FileAccess.get_file_as_string("res://scripts/" + f), "%s plays by distance (%s)" % [f, others[f]])
	var main_text := FileAccess.get_file_as_string("res://scripts/main.gd")
	_check("sfx(\"regard\", 1.0, 0.0, 0.0)" in main_text and "sfx(\"summit_win\", 1.0, 0.0, 0.0)" in main_text and "(a guardian's death: at full)" in main_text,
		"...while the Regard, a summit and a guardian's death stay at full")
	var foes: Array = []
	for d in ["res://scripts/foes", "res://scripts/towers"]:
		for f in DirAccess.get_files_at(d):
			var src := FileAccess.get_file_as_string(d + "/" + f)
			if f.ends_with(".gd") and src.begins_with("extends \"res://scripts/enemy.gd\"") and src.contains("main.sfx(\""):
				foes.append(f)
	_check(foes.is_empty(), "every other monster's sounds come from where it is too (still at full: %s)" % ", ".join(foes))


## Every offer of cards (a camp's, a vault's, the belt's, an heirloom, the
## path, the exit, a secret, the Unbound's choice) rustles like cards; the
## "ready" click is kept for things armed and ready.
func _cards() -> void:
	var A = t.main.audio
	_check(A.has_sound("cards") and A.streams["cards"].size() >= 3, "dealt cards have their own soft rustle, in three takes")
	var missing: Array = []
	var dealt := 0
	for f in ["main.gd", "climb_shape.gd", "unbound_run.gd", "secret_deep.gd"]:
		var lines := FileAccess.get_file_as_string("res://scripts/" + f).split("\n")
		var fn := ""
		var body := ""
		for i in lines.size() + 1:
			var line: String = lines[i] if i < lines.size() else "func _end"
			if line.begins_with("func ") or line.begins_with("static func "):
				if body.contains("camp_choosing = true") and body.contains("sfx("):
					dealt += 1
					if not body.contains("sfx(\"cards\"") or body.contains("sfx(\"ready\""):
						missing.append(f + " " + fn)
				fn = line
				body = ""
			body += line + "\n"
	_check(dealt >= 9 and missing.is_empty(), "every offer of cards plays the card sound, not 'ready' (%d offers; not: %s)" % [dealt, ", ".join(missing)])
	var main_text := FileAccess.get_file_as_string("res://scripts/main.gd")
	_check(main_text.count("sfx(\"cards\"") == 5, "...the camp's, a vault's, the belt's, the heirloom's and the path's cards in main.gd (%d)" % main_text.count("sfx(\"cards\""))


## "warn_knight" is the knight's own tell, and "slam" a heavy blow you
## dodge (a beast's or a brute's), each only from those; a fight beginning
## draws "on_guard", scenery in stone falls with "stone_thud".
func _own_users() -> void:
	var knight: Array = []
	var slam: Array = []
	var re := RegEx.new()
	re.compile("(sfx(_at|_kind)?\\([^\\n]*\"slam\"|\"sound\": \"slam\"|\\[\"slam\", [0-9])")
	var dirs: Array = ["res://scripts"]
	while not dirs.is_empty():
		var d: String = dirs.pop_back()
		for sub in DirAccess.get_directories_at(d):
			dirs.append(d + "/" + sub)
		for f in DirAccess.get_files_at(d):
			if not f.ends_with(".gd") or f == "sound_bank.gd":
				continue
			var fn := ""
			for line in FileAccess.get_file_as_string(d + "/" + f).split("\n"):
				if line.begins_with("func ") or line.begins_with("static func "):
					var head: String = line.get_slice("(", 0)
					fn = head.get_slice(" ", head.get_slice_count(" ") - 1)
				if line.contains("\"warn_knight\""):
					knight.append("%s %s" % [f, fn])
				if re.search(line) != null:
					slam.append("%s %s" % [f, fn])
	var knight_bad: Array = knight.filter(func(s): return s != "enemy.gd _knight")
	_check(knight.size() >= 1 and knight_bad.is_empty(), "the armour rattle is only the knight's own tell (also: %s)" % ", ".join(knight_bad))
	var blows := ["enemy.gd _champion_slam", "enemy.gd _gryphon", "enemy.gd _shellback", "enemy.gd _kraken", "enemy.gd _smith", "enemy.gd _ram_crash",
		"enemy.gd _manticore", "drowned.gd _act", "graftling.gd _act", "forge_golem.gd _act"]
	var slam_bad: Array = slam.filter(func(s): return not s in blows)
	_check(not slam.is_empty() and slam_bad.is_empty(), "'slam' is only a heavy blow you dodge, from a beast or a brute (also: %s)" % ", ".join(slam_bad))
	var A = t.main.audio
	_check(A.has_sound("on_guard") and A.has_sound("stone_thud") and A.streams["stone_thud"].size() >= 2, "a fight beginning has its own sound (a blade drawn over a low boom), scenery in stone its own thud")
	var src := ""
	for f in ["arena.gd", "rivals.gd", "climb_shape.gd", "wings.gd", "proving.gd", "doors.gd", "puzzle.gd", "cracks.gd"]:
		src += FileAccess.get_file_as_string("res://scripts/" + f)
	_check(src.count("\"on_guard\"") >= 9 and src.count("\"stone_thud\"") >= 8,
		"...heard where duels, rounds, hordes and rules begin, and where bars, walls and slabs come down (%d, %d)" % [src.count("\"on_guard\""), src.count("\"stone_thud\"")])


## The wind is three recorded takes, picked at random, its pitch spread wider.
func _wind() -> void:
	var A = t.main.audio
	_check(A.streams.get("gust", []).size() >= 3, "the wind comes in several recorded takes (%d)" % A.streams.get("gust", []).size())
	_check(float(A.VARIANCE.get("gust", 0.0)) >= 0.1, "...with a wider pitch spread, so the fifty-odd callers never sound alike")
	var build := FileAccess.get_file_as_string("res://tools/build_audio.py")
	var gust := build.get_slice("\"gust\": {", 1).get_slice("], \"level\"", 0)
	_check(gust.contains("windy/windy_ambiance.ogg@") and not gust.contains("synth:wind"), "...cut from a real windy day, not the old synthesised gust")
	var short := 99.0
	for s in A.streams.get("gust", []):
		short = minf(short, s.get_length())
	_check(short < 1.0, "...one take short enough for a roll (%.2f s)" % short)
