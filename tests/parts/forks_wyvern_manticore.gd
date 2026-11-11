extends RefCounted
## The forks of the Wyvern's and the Manticore's bonds (scripts/spells/wyvern.gd
## and manticore.gd): each new spell can be chosen at its fork, casts, does
## what it says and costs what it says; each step-3 variation changes the first
## spell as it says; old saves keep today's spells. Run by smoke_test.gd
## (_part_tests); `t` is the smoke test.

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
	await _variations_wyvern()
	await _variations_manticore()


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
				ok = ok and L.VARIATIONS.has(String(o.get("variation", "")))
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


# --- the step-3 variations -----------------------------------------------------------------

## Chooses a step-3 variation and checks its first spell still costs today's.
func _vary(bond_id: String, id: String):
	var hb = _choose(bond_id, 3, id)
	hb.select(0)
	var first: Dictionary = Bonds.BONDS[bond_id]["spells"][0]
	_check(not hb.alt_change().is_empty() and is_equal_approx(hb.cost(), float(first["steps"][1]["cost"])), "...%s still costs %d" % [first["name"], int(first["steps"][1]["cost"])])
	hb.essence = hb.capacity()
	return hb


func _variations_wyvern() -> void:
	print("  the Wyvern's variations")
	# Back to Back: Conjured Blades fans out ahead and behind.
	var main = await _climber("blade_forger", 450.0)
	var p = main.player
	var hb = _vary("blade_forger", "back_to_back")
	var shots := func(): return main.get_children().filter(func(c): return "style" in c and c.style == "blade" and c.friendly)
	hb.cast(p)
	var bl: Array = shots.call()
	_check(int(hb.stat("count")) == 3 and bl.any(func(b): return b.vel.x > 0.0) and bl.any(func(b): return b.vel.x < 0.0), "Back to Back: three blades ahead and three behind (%d blades)" % bl.size())
	# Ring of Embers: Kindle Blade, and the floor around you burns.
	main = await _climber("flameblade", 450.0)
	p = main.player
	hb = _vary("flameblade", "ring_of_embers")
	var f0: int = main.flames.size()
	hb.cast(p)
	_check(p.kindle_t > 0.0 and not p.kindle_sustain and main.flames.size() == f0 + 8, "Ring of Embers: your weapon kindles (not sustained) and eight patches burn around you")
	# Afterglow: a rune that goes off leaves its glyph glowing.
	main = await _climber("rune_artist", 450.0)
	p = main.player
	hb = _vary("rune_artist", "afterglow")
	hb.cast(p)
	_check(main.runes.size() == 1 and not main.runes[0]["linked"], "Afterglow: Rune Trap lays its rune (not linked)")
	var at: Vector2 = main.runes[0]["pos"]
	var e = await _foe(at)
	await t._frames(3)
	var FX = load("res://scripts/spell_fx.gd")
	var fx = FX.of(main)
	_check(main.runes.is_empty() and e.hp < 400.0 and fx.fields.size() == 1 and fx.fields[0]["pos"].distance_to(at) < 1.0, "...and when it goes off its glyph keeps glowing")
	var hp1: float = e.hp
	await t._wait(0.7)
	_check(e.hp < hp1 and e.chill_t > 0.0, "...searing and slowing the foe in it")


func _variations_manticore() -> void:
	print("  the Manticore's variations")
	# Aftershock: a second, weaker quake a second later.
	var main = await _climber("sandshaper", 450.0)
	var p = main.player
	var hb = _vary("sandshaper", "aftershock")
	var e = await _foe(p.global_position + Vector2(50, 0))
	hb.cast(p)
	var hp1: float = e.hp
	_check(hp1 < 400.0 and not bool(hb.stat("ring")), "Aftershock: Quake strikes (without its ring of walls)")
	await t._wait(1.25)
	_check(e.hp < hp1 and hp1 - e.hp < 400.0 - hp1, "...and a weaker second quake follows (%.0f, then %.0f)" % [400.0 - hp1, hp1 - e.hp])
	# Spray: three globs, half the poison each.
	main = await _climber("venomist", 450.0)
	p = main.player
	hb = _vary("venomist", "spray")
	hb.cast(p)
	var globs: Array = main.get_children().filter(func(c): return "style" in c and c.style == "venom" and c.friendly)
	var want := int(ceil(float(hb.stat("stacks")) * 0.5))
	_check(globs.size() == 3 and globs.all(func(g): return g.venom == want and not g.pierce), "Spray: Venom Spit throws three globs of %d stacks (%d)" % [want, globs.size()])
	# Billowing: a much wider cloud that lasts longer.
	main = await _climber("ashwalker", 450.0)
	p = main.player
	hb = _vary("ashwalker", "billowing")
	hb.cast(p)
	var base_r := float(Bonds.BONDS["ashwalker"]["spells"][0]["steps"][1]["radius"])
	_check(main.smokes.size() == 1 and main.smokes[0]["r"] > base_r * 1.3 and is_equal_approx(main.smokes[0]["t"], 8.0), "Billowing: Smoke Veil's cloud is wider (%.0f) and lasts 8 seconds" % main.smokes[0]["r"] if not main.smokes.is_empty() else "Billowing: a cloud")
	hb.cast(p)
	_check(main.smokes.size() == 2, "...and casting again makes another cloud (no igniting)")
