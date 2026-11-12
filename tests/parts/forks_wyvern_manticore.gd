extends RefCounted
## The forks of the Wyvern's and the Manticore's bonds (scripts/spells/wyvern.gd
## and manticore.gd): each new spell can be chosen at its fork, casts, does
## what it says and costs what it says; old saves keep today's spells. The
## step-3 Transformations, passive ranks and Apexes are tested in
## tests/parts/marks_wyvern_manticore.gd. Run by smoke_test.gd (_part_tests);
## `t` is the smoke test.

const Bonds := preload("res://scripts/bonds.gd")

const BOND_IDS := ["blade_forger", "flameblade", "rune_artist", "sandshaper", "venomist", "ashwalker"]

var t
var TR = load("res://scripts/tree.gd")
var L = load("res://scripts/library.gd")


func run(smoke) -> void:
	t = smoke
	print("the Wyvern's and the Manticore's forks")
	_written()
	await _old_saves()
	await _tethered_blade()
	await _falling_swords()
	await _flame_wheel()
	await _blazing_lunge()
	await _rune_brand()
	await _binding_circle()
	await _sandblast()
	await _quicksand()
	await _contagion()
	await _enfeeble()
	await _ash_step()
	await _cinder_trail()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## A climber with `bond_id` on the hand at the step `xp` gives, alone in an
## open room with no foes, standing in its middle and aiming right.
func _climber(bond_id: String, xp: float):
	await t._fresh_main()
	t.paused = false
	var main = t.main
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.grant_test_bonds()
	main.profile.add_bond("hand", bond_id, false)
	main.profile.bonds["hand"]["xp"] = xp
	main._give_bonds()
	for e in main.enemies():
		e.queue_free()
	await t._frames(2)
	var p = main.player
	p.global_position = main.room.get_center()
	p.aim = Vector2.RIGHT
	p.iframes = 999.0
	return main


## A frozen foe at `at` that can take a beating.
func _foe(at: Vector2, kind := "slime"):
	var e = await t._spawn(kind, at)
	e.hp = 400.0
	e.max_hp = 400.0
	return e


## Chooses `id` at the bond's fork `step`, puts it on the hand's button and
## checks it's chosen and costs `cost`. Returns the hand's bond.
func _choose(bond_id: String, step: int, id: String):
	var main = t.main
	var ok: bool = TR.choose(main.profile, "mark:%s:%d" % [bond_id, step], id)
	main._give_bonds()
	var hb = main.player.bonds["hand"]
	var ids: Array = hb.spells().map(func(sp): return sp["id"])
	var opt: Dictionary = TR.fork_alt(bond_id, step)
	_check(ok and TR.mark_choice(main.profile, bond_id, step) == id and (id in ids or step == 3), "%s: %s can be chosen at step %d (%s)" % [bond_id, opt.get("name", id), step, ids])
	if step != 3 and id in ids:
		hb.select(ids.find(id))
		var cost := float(opt["steps"][step]["cost"])
		_check(hb.spell()["id"] == id and is_equal_approx(hb.cost(), cost), "...it's on the hand's button and costs %d (%.1f)" % [int(cost), hb.cost()])
	return hb


## Casts the hand's spell with the key, as a player would; checks it took its cost.
func _cast_by_key() -> void:
	var main = t.main
	var p = main.player
	var hb = p.bonds["hand"]
	hb.essence = hb.capacity()
	var before: float = hb.essence
	p.attack_cd = 0.0
	p.cast_t = 0.0
	p._try_cast("hand")
	await t._wait(hb.windup() + 0.12)
	for i in 120:  # (a busy machine runs the fight slower than the clock: wait for the cast itself)
		if p.cast_t <= 0.0:
			break
		await t._frames(1)
	_check(is_equal_approx(before - hb.essence, hb.cost()), "...casting %s takes its %d essence (%.1f)" % [hb.spell_name(), int(hb.cost()), before - hb.essence])


# --- the forks -----------------------------------------------------------------------------

func _written() -> void:
	var ok := true
	var types := {}
	for bid in BOND_IDS:
		var f: Dictionary = L.MARK_FORKS.get(bid, {})
		for st in [2, 3, 4]:
			var o: Dictionary = f.get(st, {})
			if not L.built(o) or String(o.get("name", "")) == "" or String(o.get("desc", "")) == "":
				ok = false
			if st != 3:
				ok = ok and int(o.get("learn", 0)) == st and o.get("steps", {}).has(st) and o["steps"][st].has("cost")
				ok = ok and not types.has(o["type"])
				types[o["type"]] = true
			else:
				ok = ok and o.get("steps", {}).has(3)  # (a Transformation's side B: its numbers)
		ok = ok and String(f.get("change", {}).get("name", "")) != ""
	_check(ok, "every fork of the Wyvern's and the Manticore's six bonds is written: a name, a line, numbers (no placeholder left)")
	var unique := true
	for bid in Bonds.BONDS:
		for sp in Bonds.BONDS[bid]["spells"]:
			if L._spell_src.has(sp["type"]):
				unique = false
	_check(unique, "...and each new spell's type is its own (none is a spell bond.gd already runs)")
	var words := ""
	for bid in BOND_IDS:
		words += JSON.stringify(L.MARK_FORKS[bid]).to_lower()
	var banned := RegEx.new()
	banned.compile("\\b(attunement|spire|trial|judgment|mana)s?\\b")
	_check(banned.search(words) == null, "...in the game's own words")


func _old_saves() -> void:
	print("  old saves keep today's spells")
	var main = await _climber("blade_forger", 0.0)
	var prof = main.profile
	var ok := true
	var ready_ok := true
	for bid in BOND_IDS:
		# A climber from before the tree: no choices recorded, the mark at step 5.
		prof.set("tree", {})
		prof.bonds.clear()
		prof.add_bond("hand", bid, false)
		prof.bonds["hand"]["xp"] = 1800.0
		TR.migrate(prof)
		var ch: Dictionary = TR.mark_choices(prof, bid)
		var want := {2: TR.default_option(bid, 2), 3: TR.CHANGE, 4: TR.default_option(bid, 4)}
		main._give_bonds()
		var hb = main.player.bonds["hand"]
		var today: Array = Bonds.BONDS[bid]["spells"].map(func(sp): return sp["id"])
		if ch != want or hb.spells().map(func(sp): return sp["id"]) != today or TR.is_fork_ready(prof, "hand") or not hb.alt_change().is_empty():
			ok = false
		# A mark that just reached step 2 has a ready fork, and plays as before until it chooses.
		prof.set("tree", {})
		prof.bonds["hand"]["xp"] = 150.0
		main._give_bonds()
		hb = main.player.bonds["hand"]
		if not TR.is_fork_ready(prof, "hand") or hb.spells().map(func(sp): return sp["id"]) != today.slice(0, 2):
			ready_ok = false
	_check(ok, "an old save's six marks keep today's spells and step-3 changes, recorded as chosen")
	_check(ready_ok, "a mark reaching step 2 has a ready fork, and today's spell stays until it chooses")


# --- the Wyvern's spells ------------------------------------------------------------------------

func _tethered_blade() -> void:
	print("  Tethered Blade")
	var main = await _climber("blade_forger", 150.0)
	var p = main.player
	_choose("blade_forger", 2, "tethered_blade")
	var e = await _foe(p.global_position + Vector2(170, 0))
	var d0: float = e.global_position.distance_to(p.global_position)
	await _cast_by_key()
	await t._wait(0.8)
	_check(e.hp < 400.0 and e.global_position.distance_to(p.global_position) < d0 - 60.0,
		"...it skewers the foe and drags it to you (%.0f hp, %.0f -> %.0f px)" % [e.hp, d0, e.global_position.distance_to(p.global_position)])


func _falling_swords() -> void:
	print("  Falling Swords")
	var main = await _climber("blade_forger", 1000.0)
	var p = main.player
	_choose("blade_forger", 4, "falling_swords")
	var e = await _foe(p.global_position + Vector2(150, 0))
	var hb = p.bonds["hand"]
	await _cast_by_key()
	_check(e.hp == 400.0, "...nothing has fallen yet")
	await t._wait(1.2)
	_check(400.0 - e.hp >= hb.damage() * 2.5, "...then three swords fall on the foe (%.0f damage, %.0f each)" % [400.0 - e.hp, hb.damage()])


func _flame_wheel() -> void:
	print("  Flame Wheel")
	var main = await _climber("flameblade", 150.0)
	var p = main.player
	_choose("flameblade", 2, "flame_wheel")
	var a = await _foe(p.global_position + Vector2(45, 0))
	var b = await _foe(p.global_position + Vector2(-40, 15))
	var far = await _foe(p.global_position + Vector2(200, 0))
	p.heat = 0.0
	await _cast_by_key()
	_check(a.hp < 400.0 and b.hp < 400.0 and far.hp == 400.0 and a.burn_t > 0.0 and b.burn_t > 0.0, "...it strikes and burns every foe around you, not one far off")
	_check(p.heat >= 23.0, "...and each one heats your weapon (heat %.0f)" % p.heat)


func _blazing_lunge() -> void:
	print("  Blazing Lunge")
	var main = await _climber("flameblade", 1000.0)
	var p = main.player
	_choose("flameblade", 4, "blazing_lunge")
	var e = await _foe(p.global_position + Vector2(80, 22))
	var x0: float = p.global_position.x
	p.heat = 0.0
	await _cast_by_key()
	await t._wait(0.3)
	_check(e.hp < 400.0 and e.burn_t > 0.0, "...it burns the foe you lunge past")
	_check(p.global_position.x - x0 > 60.0 and p.heat >= 29.0, "...carries you along your aim (%.0f px) and heats your weapon (%.0f)" % [p.global_position.x - x0, p.heat])


func _rune_brand() -> void:
	print("  Rune Brand")
	var main = await _climber("rune_artist", 150.0)
	var p = main.player
	_choose("rune_artist", 2, "rune_brand")
	var e = await _foe(p.global_position + Vector2(120, 0))
	var near = await _foe(p.global_position + Vector2(155, 0))
	var hb = p.bonds["hand"]
	await _cast_by_key()
	await t._frames(3)
	_check(e.hp == 400.0 and near.hp == 400.0, "...the brand waits on the foe")
	e.take_hit(1.0, Vector2.ZERO, 0.0)
	await t._frames(3)
	_check(400.0 - e.hp >= 1.0 + hb.damage() - 0.5 and near.hp < 400.0, "...and bursts the moment it's hurt, catching the foe beside it (%.0f, %.0f)" % [400.0 - e.hp, 400.0 - near.hp])
	_check(Bonds.BONDS.has("rune_artist") and load("res://scripts/bench.gd").rune_artist(main.profile), "...and the Rune Artist still works the bench, whichever side it chose")


func _binding_circle() -> void:
	print("  Binding Circle")
	var main = await _climber("rune_artist", 1000.0)
	var p = main.player
	_choose("rune_artist", 4, "binding_circle")
	var e = await _foe(p.global_position + Vector2(120, 0))
	var hb = p.bonds["hand"]
	await _cast_by_key()
	await t._frames(2)
	var center: Vector2 = p.global_position + Vector2(120, 0)
	e.global_position = center + Vector2(170, 0)  # (it tries to walk out)
	await t._frames(2)
	_check(e.global_position.distance_to(center) <= float(hb.stat("radius")) + 1.0 and e.chill_t > 0.0,
		"...a foe inside can't leave it (%.0f px from its middle)" % e.global_position.distance_to(center))


# --- the Manticore's spells ------------------------------------------------------------------

func _sandblast() -> void:
	print("  Sandblast")
	var main = await _climber("sandshaper", 150.0)
	var p = main.player
	_choose("sandshaper", 2, "sandblast")
	var e = await _foe(p.global_position + Vector2(70, 0))
	var behind = await _foe(p.global_position + Vector2(-70, 0))
	await _cast_by_key()
	_check(e.hp < 400.0 and e.lost_t > 1.0 and behind.hp == 400.0 and behind.lost_t <= 0.0, "...it stings and blinds the foe in front, not the one behind")


func _quicksand() -> void:
	print("  Quicksand")
	var main = await _climber("sandshaper", 1000.0)
	var p = main.player
	_choose("sandshaper", 4, "quicksand")
	var e = await _foe(p.global_position + Vector2(150, 10))
	var hb = p.bonds["hand"]
	var rubble0: int = main.rubble.size()
	await _cast_by_key()
	await t._wait(1.2)
	_check(main.rubble.size() == rubble0 + 1 and main.rubble_slow(e.global_position) < 1.0 and e.chill_t > 0.0, "...a patch at your aim slows the foe in it")
	_check(400.0 - e.hp >= hb.damage() * 2.0, "...and grinds it down (%.0f)" % (400.0 - e.hp))


func _contagion() -> void:
	print("  Contagion")
	var main = await _climber("venomist", 150.0)
	var p = main.player
	_choose("venomist", 2, "contagion")
	var a = await _foe(p.global_position + Vector2(130, 0))
	var b = await _foe(p.global_position + Vector2(175, 0))
	var far = await _foe(p.global_position + Vector2(130, 140))
	await _cast_by_key()
	_check(a.venom >= 2 and b.venom == 0, "...it poisons the foe you aim at (%d stacks)" % a.venom)
	await t._wait(1.1)
	_check(b.venom >= 1 and far.venom == 0, "...and its poison spreads to the foe beside it (%d), not one far off" % b.venom)


func _enfeeble() -> void:
	print("  Enfeeble")
	var main = await _climber("venomist", 1000.0)
	var p = main.player
	_choose("venomist", 4, "enfeeble")
	var e = await _foe(p.global_position + Vector2(80, 0))
	var clean = await _foe(p.global_position + Vector2(-80, 0))
	e.add_venom(2)
	var d0: float = e.dmg
	var c0: float = clean.dmg
	await _cast_by_key()
	_check(is_equal_approx(e.dmg, d0 * 0.6) and clean.dmg == c0 and e.chill_t > 0.0, "...the poisoned foe hits 40%% softer and walks slower (%.1f -> %.1f), the clean one doesn't" % [d0, e.dmg])
	var it = e.get_meta("enfeebled")
	it["t"] = 0.1
	await t._wait(0.3)
	_check(is_equal_approx(e.dmg, d0) and not e.has_meta("enfeebled"), "...and it wears off (%.1f)" % e.dmg)


func _ash_step() -> void:
	print("  Ash Step")
	var main = await _climber("ashwalker", 150.0)
	var p = main.player
	_choose("ashwalker", 2, "ash_step")
	var from: Vector2 = p.global_position
	var e = await _foe(from + Vector2(-50, 0))
	var smokes0: int = main.smokes.size()
	await _cast_by_key()
	_check(p.global_position.x - from.x > 100.0, "...you step out along your aim (%.0f px)" % (p.global_position.x - from.x))
	_check(main.smokes.size() == smokes0 + 1 and main.smokes[-1]["pos"].distance_to(from) < 1.0 and e.lost_t > 0.0, "...leaving smoke where you stood, and the foe there loses you")


func _cinder_trail() -> void:
	print("  Cinder Trail")
	var main = await _climber("ashwalker", 1000.0)
	var p = main.player
	_choose("ashwalker", 4, "cinder_trail")
	var count := func(): return main.flames.filter(func(f): return f.get("friendly", false)).size()
	await _cast_by_key()
	var start: Vector2 = p.global_position
	for i in 5:
		p.global_position = start + Vector2(30.0 * (i + 1), 0)
		await t._frames(2)
	_check(int(count.call()) >= 5, "...your steps leave burning ash behind you (%d patches)" % int(count.call()))
	var e = await _foe(start + Vector2(60, 0))
	await t._wait(0.7)
	_check(e.hp < 400.0, "...that burns a foe in it")
