extends RefCounted
## The Gryphon's and the Kraken's forks (Phase B, job 1): every new spell
## and variation of Stormcaller, Windwalker, Hunter, Tidecaller, Warden and
## Deepcaller can be chosen at its fork, casts, does what it says and costs
## what it says; no placeholders are left; old saves are unaffected.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const BONDS := ["stormcaller", "windwalker", "hunter", "tidecaller", "warden", "deepcaller"]

var t
var TR = load("res://scripts/tree.gd")
var L = load("res://scripts/library.gd")
var B = load("res://scripts/bonds.gd")
var P = load("res://scripts/profile.gd")
var G = load("res://scripts/spells/gryphon.gd")
var K = load("res://scripts/spells/kraken.gd")
var FX = load("res://scripts/spell_fx.gd")
## The way the climber faces in the tests: one with open floor ahead.
var dir := Vector2.RIGHT


func run(smoke) -> void:
	t = smoke
	_written()
	await _old_saves()
	await _stormcaller()
	await _windwalker()
	await _hunter()
	await _tidecaller()
	await _warden()
	await _deepcaller()
	await _cleared()


func _main():
	return t.main


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## A fresh climber with one mark, on the hand, at a step (and no choices
## yet), alone on the floor, facing open floor.
func _marked(bond_id: String, step: int) -> void:
	await t._fresh_main()
	t.paused = false
	var main = _main()
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.profile.regarded = true
	main.first_climb = false
	main.profile.bonds = {"hand": {"id": bond_id, "xp": float(P.STEP_XP[step - 1]), "faint": false, "debt": 0.0}}
	main._give_bonds()
	for e in main.enemies():
		e.queue_free()
	await t._frames(2)
	var p = main.player
	p.iframes = 999.0
	dir = Vector2.RIGHT
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		var open := true
		for k in range(1, 15):
			var at: Vector2 = p.global_position + d * 20.0 * k
			if main.is_solid(at) or not main.room.grow(-20.0).has_point(at):
				open = false
		if open:
			dir = d
			break
	p.aim = dir


## A foe that stands still (its own moves off) where the test puts it.
func _foe(at: Vector2, hp := 300.0):
	var main = _main()
	var e = main.spawn_enemy("slime", at)
	e.set_physics_process(false)
	e.global_position = at
	e.max_hp = hp
	e.hp = hp
	e.aware = true
	return e


## Chooses a side at a fork (it must be ready and offer it), then gives the
## marks again. True if it could be chosen.
func _choose(bond_id: String, step: int, option: String) -> bool:
	var main = _main()
	var node := "mark:%s:%d" % [bond_id, step]
	var ok: bool = option in TR.available(main.profile, node) and TR.choose(main.profile, node, option)
	main._give_bonds()
	return ok


## Puts a spell on the hand's button by id.
func _select(spell_id: String) -> bool:
	var b = _main().player.bonds["hand"]
	var i: int = b.spells().map(func(sp): return sp["id"]).find(spell_id)
	if i >= 0:
		b.select(i)
	return i >= 0


## Casts the hand's spell as a climber does (wind-up, paying, casting);
## returns the essence it cost.
func _cast() -> float:
	var main = _main()
	var p = main.player
	var b = p.bonds["hand"]
	b.essence = b.capacity()
	b.burned = false
	p.attack_cd = 0.0
	p.cast_t = 0.0
	var before: float = b.essence
	p.aim = dir
	p._try_cast("hand")
	await t._wait(b.windup() + 0.12)
	return before - b.essence


## The data's cost of a fork alternative at a step.
func _data_cost(bond_id: String, step: int) -> float:
	var alt: Dictionary = TR.fork_alt(bond_id, step)
	return float(alt["steps"][step]["cost"])


func _lasting_count() -> int:
	var fx = FX.of(_main())
	return fx.get_children().filter(func(c): return c.is_class("Node2D") and not c.is_queued_for_deletion()).size() if fx != null else 0


# --- every fork written -------------------------------------------------------------------

func _written() -> void:
	print("the Gryphon's and the Kraken's forks: written")
	var missing: Array = []
	var types: Array = []
	var words := ""
	for bid in BONDS:
		var f: Dictionary = L.MARK_FORKS.get(bid, {})
		_check(String(f.get("change", {}).get("name", "")) != "", "%s's step-3 change has a name (%s)" % [bid, f.get("change", {}).get("name", "")])
		for s in [2, 3, 4]:
			var alt: Dictionary = TR.fork_alt(bid, s)
			if not L.built(alt) or String(alt.get("id", "")) == "" or String(alt.get("name", "")) == "" or String(alt.get("desc", "")) == "":
				missing.append("%s:%d" % [bid, s])
			words += " " + String(alt.get("name", "")) + " " + String(alt.get("desc", ""))
			if s == 3:
				if not L.VARIATIONS.has(String(alt.get("variation", ""))):
					missing.append("%s:3 variation" % bid)
			else:
				types.append(String(alt.get("type", "")))
				if int(alt.get("learn", 0)) != s or not alt.get("steps", {}).has(s):
					missing.append("%s:%d learn/steps" % [bid, s])
		words += " " + String(f.get("change", {}).get("says", ""))
	for tx in [G.TEXT, K.TEXT]:
		for k in tx:
			words += " " + String(tx[k])
	_check(missing.is_empty(), "no placeholders left: every fork of the six bonds is written, named and described (missing: %s)" % [missing])
	var known: Array = []
	for bid in B.BONDS:
		for sp in B.BONDS[bid]["spells"]:
			known.append(String(sp["type"]))
	_check(types.size() == 12 and types.all(func(ty): return ty != "" and not ty in known and types.count(ty) == 1), "each new spell has its own type, unlike any of today's (%s)" % [types])
	_check(not ["attunement", "spire", "trial", "judgment", "mana"].any(func(w): return words.to_lower().contains(w)), "no borrowed words in their names and lines")
	# Balance: each new spell costs within a few essence of one of today's
	# spells at its step (the one it stands beside, or the bond's first),
	# and winds up about as long.
	var off: Array = []
	for bid in BONDS:
		for s in [2, 4]:
			var today: Dictionary = TR.base_spell(bid, s)
			var first: Dictionary = TR.base_spell(bid, 1)
			var first_cost := 0.0
			for st in range(1, s + 1):
				first_cost = float(first["steps"].get(st, {}).get("cost", first_cost))
			var alt: Dictionary = TR.fork_alt(bid, s)
			var cost := _data_cost(bid, s)
			if minf(absf(cost - float(today["steps"][s]["cost"])), absf(cost - first_cost)) > 3.0 or absf(float(alt["steps"][s]["windup"]) - float(today["steps"][s]["windup"])) > 0.2:
				off.append("%s:%d" % [bid, s])
	_check(off.is_empty(), "each costs and winds up about as today's spells at its step do (off: %s)" % [off])


# --- old saves -------------------------------------------------------------------------------

func _old_saves() -> void:
	print("the Gryphon's and the Kraken's forks: old saves")
	await t._fresh_main()
	var path := "user://smoke_forks_gk.cfg"
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "regarded", true)
	cfg.set_value("profile", "bonds", {
		"hand": {"id": "hunter", "xp": 1800.0, "faint": false, "debt": 0.0},
		"legs": {"id": "windwalker", "xp": 1000.0, "faint": false, "debt": 0.0},
		"heart": {"id": "deepcaller", "xp": 450.0, "faint": false, "debt": 0.0},
		"throat": {"id": "tidecaller", "xp": 1800.0, "faint": false, "debt": 0.0},
		"brow": {"id": "warden", "xp": 150.0, "faint": false, "debt": 0.0},
	})
	cfg.save(path)
	var old = P.new()
	old.saving = false
	old.save_path = path
	old.load_save()
	_check(TR.mark_choice(old, "hunter", 2) == "track" and TR.mark_choice(old, "hunter", 3) == TR.CHANGE and TR.mark_choice(old, "hunter", 4) == "hawks_eye"
		and TR.mark_choice(old, "tidecaller", 4) == "carry" and TR.mark_choice(old, "windwalker", 4) == "downdraft",
		"an old save keeps today's side of every fork its marks passed")
	_check(TR.mark_choice(old, "deepcaller", 3) == TR.CHANGE and TR.mark_choice(old, "deepcaller", 4) == "" and TR.mark_choice(old, "warden", 2) == "absorb" and TR.mark_choice(old, "warden", 3) == "",
		"...and not those still ahead")
	_check(not TR.is_fork_ready(old, "hand") and not TR.is_fork_ready(old, "throat") and not TR.is_fork_ready(old, "brow"), "...so nothing waits to be chosen on them")
	var same := true
	for part in old.bonds:
		var bid := String(old.bonds[part]["id"])
		var step: int = old.step_for_xp(float(old.bonds[part]["xp"]))
		var today: Array = B.BONDS[bid]["spells"].filter(func(sp): return int(sp["learn"]) <= step).map(func(sp): return sp["id"])
		var now: Array = TR.bond_spells(bid, step, TR.mark_choices(old, bid)).map(func(sp): return sp["id"])
		if today != now or not TR.alt_change(bid, TR.mark_choices(old, bid)).is_empty():
			same = false
	_check(same, "...and its marks know exactly today's spells and changes")
	old.bonds["heart"]["xp"] = 1000.0
	_check(TR.ready_forks(old, "heart") == ["mark:deepcaller:4"], "a fork still ahead opens as the mark grows (Deepcaller's step 4: Siphon or Drown)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# A climber who never chooses plays as before, with every fork ready.
	await _marked("warden", 5)
	var main = _main()
	_check(TR.ready_forks(main.profile, "hand") == ["mark:warden:2", "mark:warden:3", "mark:warden:4"], "a step-5 Warden that hasn't chosen has three forks ready")
	var b = main.player.bonds["hand"]
	_check(b.spells().map(func(sp): return sp["id"]) == ["barrier", "absorb", "challenge", "unbreakable"] and b.alt_change().is_empty(), "...and casts today's spells until it chooses")


# --- the Gryphon -------------------------------------------------------------------------------

func _stormcaller() -> void:
	print("Stormcaller: Thunderclap")
	await _marked("stormcaller", 4)
	var main = _main()
	var p = main.player
	_check(_choose("stormcaller", 4, "thunderclap"), "Thunderclap can be chosen at step 4")
	_check(not TR.choose(main.profile, "mark:stormcaller:4", "lightning_rod"), "...for good")
	_check(_select("thunderclap") and not "lightning_rod" in p.bonds["hand"].spells().map(func(sp): return sp["id"]), "...and it takes Lightning Rod's place")
	var charged = _foe(p.global_position + dir * 120.0)
	var plain = _foe(p.global_position + dir * 200.0 + dir.orthogonal() * 40.0)
	charged.charged = 4.0
	var hp0: float = charged.hp
	var paid := await _cast()
	_check(is_equal_approx(paid, _data_cost("stormcaller", 4)) and paid == 10.0, "it costs what it says (%.1f)" % paid)
	_check(charged.stun > 1.0 and charged.charged <= 0.0 and charged.hp < hp0, "a charged foe in reach is stunned and struck, its charge spent (stun %.1f)" % charged.stun)
	_check(plain.stun <= 0.0 and plain.hp == plain.max_hp, "...one that isn't charged is untouched")


func _windwalker() -> void:
	print("Windwalker: Updraft, Echoing, Hurl")
	await _marked("windwalker", 2)
	var main = _main()
	var p = main.player
	_check(_choose("windwalker", 2, "updraft") and _select("updraft"), "Updraft can be chosen at step 2")
	var spot: Vector2 = main.walkable_point(p.global_position, p.global_position + dir * 120.0, 14.0)
	var e = _foe(spot + dir.orthogonal() * 10.0)
	var paid := await _cast()
	_check(paid == _data_cost("windwalker", 2) and paid == 9.0, "it costs what it says (%.1f)" % paid)
	await t._frames(3)
	_check(e.airborne > 0.5 and _lasting_count() >= 1, "a foe standing in the column is thrown into the air (%.1f s)" % e.airborne)
	e.airborne = 0.0
	await t._frames(4)
	_check(e.airborne <= 0.0, "...once: it isn't thrown again while it stands there")

	print("Windwalker: Echoing")
	await _marked("windwalker", 3)
	main = _main()
	p = main.player
	_check(_choose("windwalker", 3, "echoing"), "Echoing can be chosen at step 3")
	var b = p.bonds["hand"]
	b.select(0)
	_check(float(b.stat("arc")) == 35.0 and float(b.stat("lift")) == 1.8, "...Gale Lift keeps its narrow cone (not today's widening) and lifts for 1.8 s")
	e = _foe(p.global_position + dir * 70.0)
	paid = await _cast()
	_check(paid == 10.0, "Gale Lift still costs 10 (%.1f)" % paid)
	_check(e.airborne > 1.0, "the first gust lifts the foe")
	e.airborne = 0.0
	await t._wait(1.1)
	_check(e.airborne > 0.5, "...and a second gust a second later lifts it again (%.1f s)" % e.airborne)

	print("Windwalker: Hurl")
	await _marked("windwalker", 4)
	main = _main()
	p = main.player
	_check(_choose("windwalker", 4, "hurl") and _select("hurl"), "Hurl can be chosen at step 4")
	var flung = _foe(p.global_position + dir * 50.0)
	var struck = _foe(p.global_position + dir * 130.0)
	var calm = _foe(p.global_position - dir * 60.0)
	flung.set_physics_process(true)
	flung.airborne = 1.0
	var from: Vector2 = flung.global_position
	var hp_f: float = flung.hp
	var hp_s: float = struck.hp
	paid = await _cast()
	_check(paid == _data_cost("windwalker", 4) and paid == 10.0, "it costs what it says (%.1f)" % paid)
	await t._wait(1.0)
	_check((flung.global_position - from).dot(dir) > 60.0, "a foe in the air is flung along your aim (%.0f px)" % (flung.global_position - from).dot(dir))
	_check(flung.hp <= hp_f - 11.9 and struck.hp < hp_s, "...lands hard, and strikes the foe in its path (%.0f, %.0f)" % [hp_f - flung.hp, hp_s - struck.hp])
	_check(calm.hp == calm.max_hp, "...a foe on the ground isn't flung")
	calm.free()
	struck.free()
	flung.free()
	await t._frames(1)
	paid = await _cast()
	_check(paid == 10.0, "with nothing in the air it still casts (and says so)")


func _hunter() -> void:
	print("Hunter: Snare")
	await _marked("hunter", 2)
	var main = _main()
	var p = main.player
	_check(_choose("hunter", 2, "snare") and _select("snare"), "Snare can be chosen at step 2")
	var paid := await _cast()
	_check(paid == _data_cost("hunter", 2) and paid == 6.0, "it costs what it says (%.1f)" % paid)
	var spot: Vector2 = main.walkable_point(p.global_position, p.global_position + dir * 110.0, 14.0)
	await t._wait(0.35)
	var e = _foe(spot)
	await t._frames(3)
	_check(e.cripple_t > 2.0 and e.stun > 0.0 and e.hp < e.max_hp, "the first foe to step in it is caught: stunned, struck and slowed for 3 s (%.1f s)" % e.cripple_t)
	e.free()
	await t._frames(1)
	for i in 3:
		await _cast()
	var waiting: Array = G._snares.filter(func(s): return is_instance_valid(s) and not s.is_queued_for_deletion())
	_check(waiting.size() == 2, "no more than 2 snares wait at once (%d)" % waiting.size())

	print("Hunter: Split")
	await _marked("hunter", 3)
	main = _main()
	p = main.player
	_check(_choose("hunter", 3, "split_shot"), "Split can be chosen at step 3")
	var b = p.bonds["hand"]
	b.select(0)
	_check(is_equal_approx(b.windup(), 0.3) and not b.stat("charged"), "...Piercing Shot loses today's charging (wind-up 0.3 s)")
	var arrows := func(): return main.get_children().filter(func(c): return c.get_script() == load("res://scripts/projectile.gd") and c.friendly and c.style == "essence")
	var before: int = arrows.call().size()
	paid = await _cast()
	var now: Array = arrows.call()
	_check(paid == 9.0, "Piercing Shot still costs 9 (%.1f)" % paid)
	_check(now.size() - before == 3 and now.all(func(a): return is_equal_approx(a.dmg, 14.0 * 0.6)), "three arrows fan out, each at 60%% (%d)" % (now.size() - before))

	print("Hunter: Pinning Shot")
	await _marked("hunter", 4)
	main = _main()
	p = main.player
	_check(_choose("hunter", 4, "pinning_shot") and _select("pinning_shot"), "Pinning Shot can be chosen at step 4")
	var first = _foe(p.global_position + dir * 140.0)
	var behind = _foe(p.global_position + dir * 200.0)
	paid = await _cast()
	_check(paid == _data_cost("hunter", 4) and paid == 10.0, "it costs what it says (%.1f)" % paid)
	await t._wait(0.3)
	_check(first.stun > 1.0 and first.hp <= first.max_hp - 11.9 and p.quarry == first, "the first foe it strikes is pinned in place (%.1f s) and struck" % first.stun)
	_check(behind.hp == behind.max_hp and behind.stun <= 0.0, "...and the arrow stops there")


# --- the Kraken -----------------------------------------------------------------------------------

func _tidecaller() -> void:
	print("Tidecaller: Flood")
	await _marked("tidecaller", 2)
	var main = _main()
	var p = main.player
	_check(_choose("tidecaller", 2, "flood") and _select("flood"), "Flood can be chosen at step 2")
	var spot: Vector2 = main.walkable_point(p.global_position, p.global_position + dir * 140.0, 14.0)
	var e = _foe(spot + dir.orthogonal() * 30.0)
	var paid := await _cast()
	_check(paid == _data_cost("tidecaller", 2) and paid == 9.0, "it costs what it says (%.1f)" % paid)
	await t._wait(0.7)
	_check(e.chill_t > 0.0 and e.hp < e.max_hp, "a foe in the flood wades slowly and takes a little damage (%.1f)" % (e.max_hp - e.hp))

	print("Tidecaller: Swelling")
	await _marked("tidecaller", 3)
	main = _main()
	p = main.player
	_check(_choose("tidecaller", 3, "swelling"), "Swelling can be chosen at step 3")
	var b = p.bonds["hand"]
	b.select(0)
	_check(not b.stat("aimed") and is_equal_approx(float(b.stat("radius")), 115.0 * 1.4), "...Tidal Surge stays a burst around you, reaching farther (%.0f)" % float(b.stat("radius")))
	e = _foe(p.global_position + dir * 140.0)
	paid = await _cast()
	_check(paid == 12.0 and e.hp < e.max_hp and e.knock.dot(dir) > 0.0, "a foe beyond today's reach is struck and shoved away")

	print("Tidecaller: Geysers")
	await _marked("tidecaller", 4)
	main = _main()
	p = main.player
	_check(_choose("tidecaller", 4, "geysers") and _select("geysers"), "Geysers can be chosen at step 4")
	var near = _foe(p.global_position + dir * 75.0)
	var far = _foe(p.global_position + dir * 225.0)
	paid = await _cast()
	_check(paid == _data_cost("tidecaller", 4) and paid == 14.0, "it costs what it says (%.1f)" % paid)
	await t._wait(0.8)
	_check(near.hp < near.max_hp and far.hp < far.max_hp and far.stun > 0.0, "geysers burst one after another along your aim, striking and staggering foes")


func _warden() -> void:
	print("Warden: Bulwark")
	await _marked("warden", 2)
	var main = _main()
	var p = main.player
	_check(_choose("warden", 2, "bulwark") and _select("bulwark"), "Bulwark can be chosen at step 2")
	var paid := await _cast()
	_check(paid == _data_cost("warden", 2) and paid == 8.0, "it costs what it says (%.1f)" % paid)
	var shot = main.spawn_projectile(p.global_position + dir * 200.0, -dir * 300.0, 8.0)
	var e = _foe(p.global_position + dir * 70.0)
	await t._wait(0.6)
	_check(not is_instance_valid(shot), "a monster's shot is stopped at the wall")
	_check(e.knock.dot(dir) > 100.0, "...and a foe walking into it is held back")

	print("Warden: Mirrored")
	await _marked("warden", 3)
	main = _main()
	p = main.player
	_check(_choose("warden", 3, "mirrored"), "Mirrored can be chosen at step 3")
	var b = p.bonds["hand"]
	b.select(0)
	paid = await _cast()
	_check(paid == 12.0 and p.barrier_hp > 0.0 and not p.barrier_burst, "Barrier still costs 12 and rises (without today's burst)")
	shot = main.spawn_projectile(p.global_position + dir * 150.0, -dir * 300.0, 8.0)
	await t._wait(0.5)
	_check(is_instance_valid(shot) and shot.friendly and shot.reflected and shot.vel.dot(dir) > 0.0 and is_equal_approx(shot.dmg, 12.0),
		"a shot that reaches the barrier flies back at its shooter, harder")
	p.barrier_hp = 0.0
	await t._frames(3)
	shot = main.spawn_projectile(p.global_position + dir * 100.0, -dir * 300.0, 8.0)
	await t._wait(0.3)
	_check(not is_instance_valid(shot) or not shot.friendly, "...but not once the barrier is gone")

	print("Warden: Tidebreak")
	await _marked("warden", 4)
	main = _main()
	p = main.player
	_check(_choose("warden", 4, "tidebreak") and _select("tidebreak"), "Tidebreak can be chosen at step 4")
	paid = await _cast()
	_check(paid == _data_cost("warden", 4) and paid == 10.0, "it costs what it says (%.1f)" % paid)
	_check(p.barrier_hp > 0.0, "...and raises a thin barrier when none holds")
	var src = _foe(p.global_position + dir * 40.0)
	var waves: int = main.waves.size()
	p._on_parry(src, false)
	await t._frames(2)
	_check(main.waves.size() == waves + 1, "a parry while the barrier holds sends out a wave")
	p.barrier_hp = 0.0
	await t._wait(0.4)
	waves = main.waves.size()
	p._on_parry(src, false)
	await t._frames(2)
	_check(main.waves.size() == waves, "...but not without the barrier")


func _deepcaller() -> void:
	print("Deepcaller: Leech")
	await _marked("deepcaller", 2)
	var main = _main()
	var p = main.player
	_check(_choose("deepcaller", 2, "leech") and _select("leech"), "Leech can be chosen at step 2")
	var e = _foe(p.global_position + dir * 100.0)
	p.hp = 40.0
	var paid := await _cast()
	_check(paid == _data_cost("deepcaller", 2) and paid == 8.0, "it costs what it says (%.1f)" % paid)
	await t._wait(1.2)
	_check(e.hp <= e.max_hp - 2.9 and p.hp > 40.0, "it drinks from the foe every second and gives you half (%.0f, +%.1f)" % [e.max_hp - e.hp, p.hp - 40.0])

	print("Deepcaller: Patient")
	await _marked("deepcaller", 3)
	main = _main()
	p = main.player
	_check(_choose("deepcaller", 3, "patient"), "Patient can be chosen at step 3")
	var b = p.bonds["hand"]
	b.select(0)
	_check(is_equal_approx(b.windup(), 0.7) and int(b.stat("targets")) == 3, "...Undertow winds up twice as long and drains 3 foes (not today's 5)")
	var foes: Array = []
	for i in 4:
		foes.append(_foe(p.global_position + dir * (50.0 + 30.0 * i)))
	paid = await _cast()
	var hurt: Array = foes.filter(func(f): return f.hp < f.max_hp)
	_check(paid == 12.0 and hurt.size() == 3 and hurt.all(func(f): return is_equal_approx(f.max_hp - f.hp, 8.0 * 1.8)), "it drains 3 foes nearly twice as hard (%d)" % hurt.size())

	print("Deepcaller: Drown")
	await _marked("deepcaller", 4)
	main = _main()
	p = main.player
	_check(_choose("deepcaller", 4, "drown") and _select("drown"), "Drown can be chosen at step 4")
	e = _foe(p.global_position + dir * 120.0)
	e.hp = 90.0
	p.hp = 40.0
	paid = await _cast()
	_check(paid == _data_cost("deepcaller", 4) and paid == 10.0, "it costs what it says (%.1f)" % paid)
	_check(is_equal_approx(90.0 - e.hp, 10.0 + 40.0) and e.stun > 0.5 and p.hp > 40.0, "a badly hurt foe is pulled under: harder for its wounds, held, and you drink (%.0f)" % (90.0 - e.hp))
	var whole = _foe(p.global_position + dir * 120.0 + dir.orthogonal() * 10.0)
	e.free()
	await t._frames(1)
	await _cast()
	_check(is_equal_approx(whole.max_hp - whole.hp, 10.0) and whole.stun <= 0.0, "...an unhurt foe takes only its base damage and isn't held")


## A new floor clears what these spells leave behind.
func _cleared() -> void:
	print("the Gryphon's and the Kraken's forks: a new floor")
	await _marked("tidecaller", 2)
	var main = _main()
	_choose("tidecaller", 2, "flood")
	_select("flood")
	await _cast()
	_check(_lasting_count() >= 1, "a flood stands on the floor")
	main._start_floor(main.floor_num)
	await t._frames(3)
	_check(_lasting_count() == 0, "...and a new floor clears it")
