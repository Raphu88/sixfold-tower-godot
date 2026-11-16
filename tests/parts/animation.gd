extends RefCounted
## Motion and life (anim.gd): the climber's and the foes' animation, the tower's
## ambient life, the flourishes and the screen shake. All of it is for the eye:
## a blow lands on the same call, a roll keeps the same untouchable time, an
## ended foe still awards the same essence, the shake setting turns shake off,
## each tower has its own ambient streams and they end with the floor, Low
## stays light, and the cost stays in budget. Run by smoke_test.gd (_part_tests).

const Anim := preload("res://scripts/anim.gd")
const Particles := preload("res://scripts/particles.gd")
const Essence := preload("res://scripts/essence.gd")
const Towers := preload("res://scripts/towers.gd")
const Combat := preload("res://scripts/combat.gd")
const M := preload("res://scripts/menu.gd")

var t
var keep_level := "medium"
var keep_shake := true


func run(smoke) -> void:
	t = smoke
	print("motion and life: animation, ambient life, juice")
	keep_level = Particles.level
	keep_shake = bool(M.settings["shake"])
	Anim.ambient_on = true
	await _fresh()
	await _data()
	await _timing_unchanged()
	await _foes()
	await _shake()
	await _ambient()
	await _beasts()
	await _world()
	await _numbers()
	await _ui()
	await _perf()
	_words()
	Particles.set_level(keep_level)
	M.settings["shake"] = keep_shake
	Anim.force_beat = false
	Engine.time_scale = 1.0
	Anim.ambient_on = false


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _fresh() -> void:
	await t._fresh_main()
	t.paused = false
	Particles.set_level("medium")
	M.settings["shake"] = true
	t.main.touch._set_active(false)
	t.main.pad._set_active(false)
	for e in t.main.enemies():
		e.queue_free()
	await t._frames(3)
	t.main.player.iframes = 0.0


func _pf():
	return t.main.particles


func _data() -> void:
	var Reg = load("res://scripts/data_registry.gd")
	var paths: Array = Reg.fields().map(func(f): return String(f["path"]))
	_check(paths.any(func(p): return p.begins_with("anim/DATA/walk/")) and paths.any(func(p): return p.begins_with("anim/DATA/shake/")) and paths.any(func(p): return p.begins_with("anim/DATA/foe/")), "every amount and duration of the motion is data the Data editor can change")
	_check(Anim.AMBIENT.size() == Towers.ORDER.size() and Towers.ORDER.all(func(k): return Anim.AMBIENT.has(k) and not Anim.AMBIENT[k].is_empty()), "every tower has its own ambient life")
	var all_there := true
	for k in Anim.AMBIENT:
		for entry in Anim.AMBIENT[k]:
			all_there = all_there and Particles.PRESETS.has(entry[0])
	_check(all_there, "...each of them a particle preset")
	_check(Anim.bob(PI * 0.5, 1.0) > 0.5 and is_equal_approx(Anim.bob(0.0, 1.0), 0.0) and is_equal_approx(Anim.bob(PI * 0.5, 0.0), 0.0), "a step lifts the body; standing still doesn't")
	_check(is_equal_approx(Anim.roll_stretch(0.0), 0.0) and Anim.roll_stretch(0.5) > 0.2 and absf(Anim.roll_stretch(1.0)) < 0.001, "a roll stretches you mid-way and settles at its end")
	_check(Anim.crumple(0.0) == 0.0 and Anim.crumple(5.0) == 1.0 and Anim.crumple(0.2) > 0.0, "a fall folds the body over a moment")
	_check(Anim.shiver(0.0, 0.7, 1.0) == Vector2.ZERO and Anim.shiver(0.7, 0.7, 1.0) != Vector2.ZERO, "a hit makes the body shiver, briefly")


## An attack's hit lands in the same call as ever, the swing's and the roll's
## timings are the same whatever the Effects level, and the effects only add particles.
func _timing_unchanged() -> void:
	var main = t.main
	var p = main.player
	var seen := {}
	for lvl in ["low", "high"]:
		Particles.set_level(lvl)
		_pf().reset()
		for e in main.enemies():
			e.queue_free()
		await t._frames(2)
		p.global_position = Vector2(400, 400)
		p.aim = Vector2.RIGHT
		p.attack_cd = 0.0
		p.combo_t = 0.0
		p.combo = 0
		p.sta = p.max_sta
		var foe = main.spawn_enemy("slime", p.global_position + Vector2(26, 0))
		foe.set_physics_process(false)
		foe.hp = 500.0
		foe.max_hp = 500.0
		var hp0: float = foe.hp
		p._melee()
		seen[lvl] = {"hit": foe.hp < hp0, "swing_t": p.swing_t, "attack_cd": p.attack_cd, "lunge_t": p.lunge_t, "sta": p.sta, "combo_t": p.combo_t}
		foe.queue_free()
		await t._frames(2)
	_check(seen["low"]["hit"] and seen["high"]["hit"], "a swing's blow lands in the same call as ever, at Low and High")
	_check(seen["low"] == seen["high"], "...and its timings (swing, recovery, lunge, stamina) don't depend on the Effects level %s" % [seen])
	# A roll: the same untouchable time.
	Particles.set_level("high")
	p.roll_cd = 0.0
	p.attack_cd = 0.0
	p.sta = p.max_sta
	p.iframes = 0.0
	p.roll_t = 0.0
	p.jump_t = 0.0
	var rolled: bool = p._try_roll(Vector2.RIGHT)
	var expect: float = p.roll_t * float(Combat.CLIMBER["roll_iframes"]) + p.gfx("iframe")
	_check(rolled and is_equal_approx(p.iframes, expect), "a roll keeps exactly the untouchable time it always did (%.3f)" % p.iframes)
	_check(_pf().count() > 0, "...and kicks up dust")
	var i0: float = p.iframes
	await t._frames(2)
	p.roll_t = 0.0
	p.iframes = 0.0
	# A jump's landing and a parry add no time or state.
	var ph: float = p.parry_t
	p._on_parry(main.spawn_enemy("slime", p.global_position + Vector2(60, 0)), true)
	_check(p.parry_flash > 0.3 and p.parry_cd == 0.0, "a parry still flashes and frees you at once, now with glints (%.2f)" % i0)
	p.parry_flash = 0.0
	# A drink mends over time; the sparkle doesn't change how much.
	p.hp = 50.0
	p.heal_left = 20.0
	p.heal_rate = 50.0
	var sp0: int = _pf().spawned
	for k in 4:
		p._tick_healing(0.2)
	_check(is_equal_approx(p.hp, 70.0) and _pf().spawned > sp0, "a drink mends exactly as much, and sparkles while it does (+%d)" % (_pf().spawned - sp0))
	p.hp = p.max_hp
	Particles.set_level("medium")
	_pf().reset()
	# The climber draws through all of it (a roll, a hit, a fall) without trouble.
	p.roll_t = 0.1
	p._roll_len = 0.2
	p.hurt_t = float(Combat.CLIMBER["grace"])
	p.queue_redraw()
	await t._frames(2)
	p.roll_t = 0.0
	p.hurt_t = 0.0
	p.dead = true
	p.queue_redraw()
	await t._frames(3)
	_check(p._dead_age > 0.0, "a fallen climber's fold counts up")
	p.dead = false
	p.queue_redraw()
	await t._frames(2)
	_check(p._dead_age == 0.0, "...and starts again next time")


func _foes() -> void:
	var main = t.main
	var p = main.player
	var pf = _pf()
	Particles.set_level("medium")
	pf.reset()
	for e in main.enemies():
		e.queue_free()
	await t._frames(2)
	p.global_position = Vector2(400, 400)
	# A foe's end: it dissolves into motes, and the essence is awarded as ever.
	var foe = main.spawn_enemy("slime", Vector2(460, 400))
	foe.set_physics_process(false)
	await t._frames(2)
	var kind: String = main.tower_data()["essence"]
	var drop: Array = Essence.drop_for(foe.kind, main.floor_num)
	var before := {}
	for k in main.run_essence:
		before[k] = float(main.run_essence[k])
	var spawned0: int = pf.spawned
	t._slay(foe)
	await t._frames(1)
	var gained := {}
	for k in main.run_essence:
		gained[k] = float(main.run_essence[k]) - float(before.get(k, 0.0))
	var want_drop: float = float(drop[1])
	var want_bonus: float = float(Towers.ESSENCE_BONUS)
	var share: float = main.rivals.share() if main.rivals != null else 1.0
	var expect_total: float = (want_drop + want_bonus) * share
	var total := 0.0
	for k in gained:
		total += float(gained[k])
	_check(absf(total - expect_total) < 0.01, "a foe that dissolves awards the same essence as ever (%.2f of %.2f)" % [total, expect_total])
	_check(pf.spawned > spawned0, "...as motes rise from it (+%d)" % (pf.spawned - spawned0))
	# The motes drift toward the climber: some start with a speed toward them.
	pf.reset()
	var f2 = main.spawn_enemy("knight", Vector2(520, 400))
	f2.set_physics_process(false)
	await t._frames(2)
	Anim.dissolve(main, f2)
	var toward := 0
	for i in pf._n:
		if pf._vx[i] < -5.0:
			toward += 1
	_check(toward > 0, "...and they drift toward the climber (%d of %d)" % [toward, pf._n])
	f2.queue_free()
	# A foe breathes, pulls back as it winds up, and flashes white when hit.
	var f3 = main.spawn_enemy("knight", Vector2(470, 400))
	f3.set_physics_process(false)
	f3.hp = 999.0
	f3.max_hp = 999.0
	await t._frames(2)
	var tint_seen := 0.0
	f3.take_hit(5.0, Vector2.RIGHT, 0.0)
	f3.queue_redraw()
	await t._frames(1)
	tint_seen = f3._pen.tint
	_check(tint_seen > 0.6, "a foe flashes white when struck (%.2f)" % tint_seen)
	var wind0: float = f3._wind_age
	f3.state = "wind_slash"
	f3.queue_redraw()
	await t._frames(3)
	_check(f3._wind_age > wind0, "a foe's wind-up pull-back counts while it winds up")
	f3.state = "idle"
	f3.queue_redraw()
	await t._frames(2)
	_check(f3._wind_age == 0.0, "...and relaxes after")
	f3.queue_free()
	await t._frames(2)


func _shake() -> void:
	var main = t.main
	M.settings["shake"] = false
	main.shake_amount = 0.0
	main.shake(9.0)
	_check(main.shake_amount == 0.0, "Settings -> Screen shake off: nothing shakes")
	M.settings["shake"] = true
	main.shake(9.0)
	_check(main.shake_amount > 0.0, "...and on it does")
	var k0: float = Anim.DATA["shake"]["mult"]
	main.shake_amount = 0.0
	Anim.DATA["shake"]["mult"] = 0.5
	main.shake(8.0)
	_check(is_equal_approx(main.shake_amount, 4.0), "the strength is data (a half-strength shake is half)")
	Anim.DATA["shake"]["mult"] = k0
	main.shake_amount = 0.0
	var Help := preload("res://scripts/entity_help.gd")
	_check(Help.HELP.has("setting:shake") and String(Help.HELP["setting:shake"]) != "", "the Entity explains the Screen shake button")


func _ambient() -> void:
	var main = t.main
	var pf = _pf()
	var saved: String = main.tower
	for tw in Towers.ORDER:
		main.tower = tw
		Particles.clear(main)
		_check(Anim.ambient_count(main) == 0, "%s: a new floor clears the last one's ambient streams" % tw)
		var made: int = Anim.start_ambient(main)
		_check(made == Anim.AMBIENT[tw].size() and Anim.ambient_count(main) == made, "%s has its own ambient life (%d streams)" % [tw, made])
		await t._frames(2)
		Particles.set_level("medium")
		pf._run_emitters(1.0)
		_check(pf.count() > 0, "%s: its ambient life shows (%d specks)" % [tw, pf.count()])
		Particles.set_level("low")
		pf.reset()
		Anim.start_ambient(main)
		pf._run_emitters(1.0)
		_check(pf.count() == 0, "%s: Low has no ambient streams, to stay light" % tw)
		Particles.set_level("high")
		pf.reset()
		Anim.start_ambient(main)
		pf._run_emitters(1.0)
		_check(pf.count() <= pf.cap(), "%s: High stays under its cap (%d)" % [tw, pf.count()])
	# The ambient life gives way when the screen is busy.
	Particles.set_level("medium")
	main.tower = "kraken"
	Particles.clear(main)
	Anim.start_ambient(main)
	for i in pf.cap():
		pf._emit(Particles.PRESETS["spark"], Vector2.ZERO, Vector2.ZERO, Particles.NONE)
	var busy: int = pf.count()
	pf._run_emitters(1.0)
	_check(pf.count() == busy, "...and it waits while the screen is busy with fights (%d)" % busy)
	# A real new floor starts the tower's life again, and clears the old.
	main.tower = "wyvern"
	main._start_floor(2)
	await t._frames(3)
	_check(Anim.ambient_count(main) == Anim.AMBIENT["wyvern"].size() and pf.count() < busy, "a new floor starts its tower's ambient life afresh")
	main.tower = saved
	Particles.clear(main)
	Particles.set_level("medium")
	# Torches throw sparks (a stream near each), and a warded stair pulses.
	pf.reset()
	var st := {}
	main.ward = true
	main.stair_open = false
	main.stair_pos = main.player.global_position + Vector2(60, 0)
	var rings0: int = main.fx.rings.size()
	st["ward"] = 0.0
	Anim.tick(pf, 0.1, st)
	_check(main.fx.rings.size() > rings0, "a warded stair pulses")
	main.ward = false
	var n0: int = pf.spawned
	Anim.ward_lift(main)
	_check(pf.spawned > n0, "the stair bursts open when the ward lifts")


func _beasts() -> void:
	var main = t.main
	var pf = _pf()
	Particles.set_level("medium")
	pf.reset()
	for e in main.enemies():
		e.queue_free()
	await t._frames(2)
	var rings0: int = main.fx.rings.size()
	var beast = main.spawn_enemy("kraken", main.player.global_position + Vector2(120, 0))
	beast.set_physics_process(false)
	await t._frames(2)
	_check(main.fx.rings.size() > rings0, "a beast arrives with a ring and a flare")
	beast.max_hp = 1000.0
	beast.hp = 1000.0
	var rings1: int = main.fx.rings.size()
	beast.take_hit(1.0, Vector2.ZERO, 0.0)
	_check(not beast._phased, "...no flourish while it is healthy")
	beast.take_hit(520.0, Vector2.ZERO, 0.0)
	_check(beast._phased and main.fx.rings.size() > rings1, "...and a flourish when it is brought to half")
	# A beast's fall: a short slow beat (never while a test runs the game fast).
	Anim.force_beat = true
	Engine.time_scale = 1.0
	main.hitstop_until = 0
	main.beat_until = 0
	Anim.slow_beat(main)
	_check(main.beat_until > Time.get_ticks_msec(), "a beast's fall starts a slow beat")
	main.hitstop_until = 0
	await t._frames(2)
	_check(is_equal_approx(Engine.time_scale, main.beat_scale), "...time runs slower for it (%.2f)" % Engine.time_scale)
	main.beat_until = Time.get_ticks_msec() - 5
	await t._frames(2)
	_check(Engine.time_scale == 1.0 and main.beat_until == 0, "...and normal speed returns")
	var ts: float = main.test_speed
	main.test_speed = 4.0
	main.beat_until = 0
	Anim.slow_beat(main)
	_check(main.beat_until == 0, "...and a test running the game fast skips it")
	main.test_speed = ts
	Anim.force_beat = false
	beast.queue_free()
	await t._frames(2)


func _world() -> void:
	var main = t.main
	var pf = _pf()
	Particles.set_level("medium")
	pf.reset()
	var at: Vector2 = main.player.global_position + Vector2(40, 0)
	var before: int = pf.spawned
	Anim.door(main, at, Vector2.UP)
	var d: int = pf.spawned - before
	before = pf.spawned
	Anim.wall(main, at)
	var w: int = pf.spawned - before
	before = pf.spawned
	Anim.chest(main, at, Color(1, 0.8, 0.4))
	var c: int = pf.spawned - before
	before = pf.spawned
	Anim.pickup(main, at, Color(0.5, 0.9, 1.0))
	var k: int = pf.spawned - before
	_check(d > 0 and w > 0 and c > 0 and k > 0, "doors, crumbling walls, chests and pickups each throw a few specks (%d, %d, %d, %d)" % [d, w, c, k])
	Particles.set_level("low")
	pf.reset()
	Anim.wall(main, at)
	Anim.chest(main, at, Color(1, 0.8, 0.4))
	_check(pf.count() <= 40, "...and at Low, only a few (%d)" % pf.count())
	Particles.set_level("medium")
	# A fresh floor clears every one.
	Particles.clear(main)
	_check(pf.count() == 0, "...and a new floor clears them")


func _numbers() -> void:
	var main = t.main
	var fx = main.fx
	fx.texts.clear()
	fx.text(Vector2(100, 100), "12", Color.WHITE)
	fx.text(Vector2(100, 100), "Parried", Color.WHITE)
	var num = fx.texts[0]
	var word = fx.texts[1]
	_check(num.has("vel") and not word.has("vel"), "damage numbers pop and arc; other words rise as before")
	var y0: float = num["pos"].y
	fx._process(0.1)
	var up1: float = y0 - num["pos"].y
	fx._process(0.4)
	_check(up1 > 5.0 and num["pos"].y < y0, "...a number rises, then drifts (%.1f px in 0.1 s)" % up1)
	fx.texts.clear()
	fx.crit_until = Time.get_ticks_msec() + 50
	fx.text(Vector2(100, 100), "30", Color.WHITE)
	_check(fx.texts[0].get("crit", false) and fx.texts[0]["color"] == Anim.DATA["text"]["crit_color"], "a critical blow's number is gold and big")
	fx.text(Vector2(100, 100), "5", Color.WHITE)
	_check(not fx.texts[1].get("crit", false), "...and only that one")
	fx.texts.clear()


func _ui() -> void:
	_check(Anim.num("ui", "wheel_from") < 1.0 and Anim.num("ui", "wheel_bloom") > 0.0 and Anim.num("ui", "feed_slide") > 0.0, "the belt and spell wheel bloom open, and notices slide in (tunable)")
	# A mark that has grown a step flares on the body view.
	var main = t.main
	main.grant_test_bonds()
	var prof = main.profile
	var part: String = prof.bonds.keys()[0] if not prof.bonds.is_empty() else ""
	if part == "":
		_check(true, "(no marks to grow in this build of the test)")
		return
	var v = M.BodyView.new()
	v.main = main
	v._note_growth()
	_check(v._grown.is_empty(), "a mark first seen doesn't flare")
	var xp0: float = float(prof.bonds[part]["xp"])
	var step0: int = prof.step_for_xp(xp0)
	prof.bonds[part]["xp"] = float(prof.STEP_XP[mini(step0 + 1, prof.STEP_XP.size() - 1)]) + 1.0
	v._note_growth()
	_check(prof.step_for_xp(float(prof.bonds[part]["xp"])) > step0 and v._grown.has(part), "a mark that grows a step flares on the body view")
	prof.bonds[part]["xp"] = xp0
	v.free()


func _perf() -> void:
	var main = t.main
	var p = main.player
	var pf = _pf()
	await _fresh()
	main = t.main
	p = main.player
	pf = _pf()
	main.tower = "chimera"
	var foes := []
	for i in 6:
		var f = main.spawn_enemy("slime", p.global_position + Vector2(40 + i * 12, -50 + i * 20))
		f.set_physics_process(false)
		f.max_hp = 9999.0
		f.hp = 9999.0
		foes.append(f)
	var cost := {}
	for l in ["low", "medium", "high"]:
		Particles.set_level(l)
		pf.reset()
		Anim.start_ambient(main)
		var sum := 0.0
		var peak := 0
		for i in 60:
			Particles.burst(main, p.global_position + Vector2(randf_range(-80, 80), randf_range(-60, 60)), "crit")
			Anim.swing(main, p.global_position, Vector2.RIGHT, 40.0, 0.8, 1.0, "arc", i % 3 == 0)
			Anim.dissolve(main, foes[i % foes.size()])
			Anim.roll_start(main, p.global_position, Vector2.RIGHT)
			pf._run_emitters(0.016)
			for f in foes:
				f.queue_redraw()
			p.queue_redraw()
			await t._frames(1)
			if i >= 20:
				sum += float(pf.cost_us)
				peak = maxi(peak, pf.count())
		cost[l] = [sum / 40.0, peak]
		print("  performance: Effects %s with motion: %.0f us a frame, %d particles at most (cap %d)" % [l, cost[l][0], peak, pf.cap()])
	_check(cost["medium"][0] < 4000.0, "at Medium the motion's particles cost under 4 ms a frame (%.0f us)" % cost["medium"][0])
	_check(cost["low"][0] < cost["high"][0] + 500.0 and cost["low"][1] <= Particles.EFFECTS["low"]["cap"], "Low stays the lightest (%.0f us, %d)" % [cost["low"][0], cost["low"][1]])
	_check(cost["high"][1] <= Particles.EFFECTS["high"]["cap"], "no level goes over its cap")
	for f in foes:
		f.queue_free()
	pf.reset()
	Particles.set_level("medium")
	await t._frames(3)


func _words() -> void:
	var words: Array = [str(Anim.DATA["beast"].keys()), str(Anim.AMBIENT.keys())]
	for src_path in ["res://scripts/anim.gd"]:
		var src := FileAccess.get_file_as_string(src_path).to_lower()
		var bad := ["attunement", "spire", "trial", "judgment", "mana"].filter(func(w): return RegEx.create_from_string("\\b" + w + "\\b").search(src) != null)
		_check(bad.is_empty(), "no borrowed words in %s %s" % [src_path.get_file(), bad])
	_check(words.size() == 2, "(the words are plain)")
