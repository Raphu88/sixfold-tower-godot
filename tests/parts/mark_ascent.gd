extends RefCounted
## A mark's high steps, 6 to 12 (scripts/mark_ascent.gd; tree.gd
## _high_node; bond.gd spell_stat; scripts/spells/ascent.gd): every one of
## the 18 marks has rank IV, three forks of two upgrades, the Apex+, a
## second Transformation of two and its Zenith, all written, every number
## aimed at a spell the mark has; the tree shows them and they're chosen for
## good; upgrades change the spells' numbers only once chosen; rank IV
## raises the passive's numbers; each kind of effect works in a room (an
## echo, a burst around you, strikes on the nearest foes, a meteor after its
## warning ring, circling blades, a rune circle, a wave of fire, a shell, a
## surge, a spirit creature); a step-12 mark holds a little more and its
## creatures don't double; the Entity explains it all; none of the owner's
## banned words. Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const A := preload("res://scripts/mark_ascent.gd")
const B := preload("res://scripts/bonds.gd")
const P := preload("res://scripts/profile.gd")
const TR := preload("res://scripts/tree.gd")
const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

var t
var dir := Vector2.RIGHT


func run(smoke) -> void:
	t = smoke
	print("a mark's high steps: rank IV, upgrades, the Apex+, Transformation II, the Zenith")
	_data()
	_words()
	await _tree()
	await _rank4()
	await _zenith_cast()
	await _effects()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _main():
	return t.main


# --- the data ------------------------------------------------------------------------------------

func _data() -> void:
	var L = load("res://scripts/library.gd")
	var missing: Array = []
	var bad: Array = []
	for id in B.BONDS:
		if not A.ASCENT.has(id) or A.rank4(id).is_empty() or A.zenith(id).is_empty() or A.single(id, A.APEX_STEP).is_empty():
			missing.append(id)
			continue
		for s in A.FORKS:
			if A.sides(id, s).size() != 2:
				missing.append("%s:%d" % [id, s])
		var ids := {}
		for sp in B.BONDS[id]["spells"]:
			ids[String(sp["id"])] = true
		for st in [2, 4]:
			var alt = L.MARK_FORKS.get(id, {}).get(st, {})
			if alt is Dictionary and alt.has("id"):
				ids[String(alt["id"])] = true
		for s in range(7, 13):
			var opts: Array = A.sides(id, s) if s in A.FORKS else [A.single(id, s)]
			for o in opts:
				if String(o.get("name", "")) == "" or String(o.get("says", "")) == "" or (o.get("mods", {}).is_empty() and o.get("fx", []).is_empty()):
					bad.append("%s:%s" % [id, o.get("id", "?")])
				for sid in o.get("mods", {}):
					if sid != "*" and not ids.has(String(sid)):
						bad.append("%s:%s:%s" % [id, o["id"], sid])
	_check(missing.is_empty(), "every mark has rank IV, forks of two at 7, 9, 10 and 11, the Apex+ and a Zenith (%s)" % [missing])
	_check(bad.is_empty(), "...each upgrade named and said, and aimed at the mark's own spells (%s)" % [bad])
	_check(A.FORKS == [7, 9, 10, 11] and A.APEX_STEP == 8 and A.ZENITH_STEP == 12 and B.PASSIVE_RANK_AT.get(4) == 6, "the rhythm: rank IV at 6, forks at 7, 9 and 11, Apex+ at 8, Transformation II at 10, the Zenith at 12")
	_check(TR.MAX_STEP == 12 and P.STEP_XP.size() == 12, "a mark grows to step 12")
	var notes_ok := true
	for id in B.BONDS:
		for s in range(6, 13):
			notes_ok = notes_ok and B.step_note(String(id), s) != ""
	_check(notes_ok, "reaching each step from 6 to 12 says what it brings (the stair's line)")
	# The numbers only change once chosen, and only the spells named.
	var BS = load("res://scripts/bond.gd")
	var b = BS.new("stormcaller", "hand")
	b.step = 12
	var chain: Dictionary = B.BONDS["stormcaller"]["spells"][1]
	var leaps0 := int(b.spell_stat(chain, "leaps"))
	b.choices = {7: "long_arc"}
	_check(int(b.spell_stat(chain, "leaps")) == leaps0 + 2, "Long Arc, once chosen: Chain Lightning leaps to 2 more foes (%d, was %d)" % [int(b.spell_stat(chain, "leaps")), leaps0])
	b.choices = {11: "storm_battery"}
	_check(is_equal_approx(float(b.spell_stat(chain, "cost")), float(chain["steps"][2]["cost"]) * 0.85), "Storm Battery: every spell costs 15% less")
	var thunder: Dictionary = B.BONDS["stormcaller"]["spells"][3]
	_check(is_equal_approx(float(b.spell_stat(thunder, "duration")), 12.0), "the Apex+ comes by itself at step 8: Thunderhead lasts 12 seconds")
	b.step = 7
	_check(is_equal_approx(float(b.spell_stat(thunder, "duration")), 8.0), "...not before")
	b.step = 12
	_check(is_equal_approx(b.capacity(), 115.0), "a step-12 mark holds 115 essence: 10 more a step to 5, then 5 (%.0f)" % b.capacity())
	_check(b.ally_step() == 8, "...and the creatures it calls are made at step 8, not 12 (steps past 5 count half)")
	var R = load("res://scripts/reactions.gd")
	_check(R.RULES.has("per_high_step") and float(R.RULES["per_high_step"]) < float(R.RULES["per_step"]), "reactions grow less with steps past 5")


func _words() -> void:
	var texts: Array = [str(A.ASCENT).to_lower(), str(A.TEXT).to_lower(), str(A.WORDS).to_lower()]
	var E = load("res://scripts/entity.gd")
	for id in ["mark_high", "mark_zenith", "tree_fork"]:
		var e: Dictionary = E.TIPS.get(id, {})
		_check(e.has("tip") and e.has("more") and String(e["tip"]).length() < 140, "the Entity explains '%s' the first time (a short line and an Archive account)" % id)
		texts.append(str(e).to_lower())
	var Talk = load("res://scripts/entity_talk.gd")
	var how := String(Talk.DIALOGUE["how_marks"]["lines"][0])
	_check(how.contains("Zenith") and how.contains("rank IV") and how.contains("step 10"), "'How do marks grow?' tells of steps 6 to 12 and the Zenith")
	texts.append(how.to_lower())
	var Help = load("res://scripts/entity_help.gd")
	for id in ["bud_rank4", "bud_upgrade", "bud_apex", "bud_transform", "bud_zenith"]:
		_check(Help.HELP.has(id), "the tree's high-step buds have hover help (%s)" % id)
		texts.append(String(Help.HELP.get(id, "")).to_lower())
	var all := " ".join(texts)
	var found: Array = BANNED.filter(func(w): return all.contains(w))
	_check(found.is_empty(), "none of the owner's banned words in the high steps (%s)" % ", ".join(found))


# --- the tree --------------------------------------------------------------------------------------

func _tree() -> void:
	await _marked("stormcaller", 12)
	var main = _main()
	var prof = main.profile
	var nodes: Array = TR.nodes(prof, "hand")
	_check(nodes.slice(5).map(func(n): return n["kind"]) == ["passive", "fork", "apex", "fork", "fork", "fork", "zenith"], "steps 6 to 12 on the tree: rank IV, a fork, the Apex+, three forks, the Zenith")
	_check(nodes[5]["state"] == "owned" and nodes[7]["state"] == "owned" and nodes[11]["state"] == "owned", "...rank IV, the Apex+ and the Zenith are yours once reached")
	_check(TR.ready_forks(prof, "hand").has("mark:stormcaller:7") and TR.available(prof, "mark:stormcaller:10").size() == 2, "...the forks at 7 to 11 are ready, both sides to choose")
	_check(TR.choose(prof, "mark:stormcaller:7", "long_arc") and not TR.choose(prof, "mark:stormcaller:7", "high_voltage"), "choosing one is for good: the other can't be chosen after")
	var n7: Dictionary = TR.node(prof, "mark:stormcaller:7")
	_check(n7["options"][0]["state"] == "owned" and n7["options"][1]["state"] == "passed", "...the chosen side is yours, the other passed on")
	main._give_bonds()
	var b = main.player.bonds["hand"]
	_check(b.choices.get(7, "") == "long_arc", "the mark knows its high choices once the climber is given their marks")
	# Below step 6 the high nodes are locked.
	main.profile.bonds["hand"]["xp"] = float(P.STEP_XP[4])
	var low: Array = TR.nodes(prof, "hand")
	_check(low[5]["state"] == "locked" and low[6]["state"] == "locked" and low[11]["state"] == "locked", "at step 5, steps 6 to 12 are locked, each saying what opens it")


# --- rank IV ----------------------------------------------------------------------------------------

func _rank4() -> void:
	await _marked("stormcaller", 5)
	var main = _main()
	_check(int(B.HELD.get("stormcaller", 0)) == 3 and is_equal_approx(B.passive_num("stormcaller", 2, "more"), 0.2), "at step 5, Static is rank III: charged foes take 20% more")
	main.profile.bonds["hand"]["xp"] = float(P.STEP_XP[5])
	main._give_bonds()
	_check(main.player.passive_rank("stormcaller") == 4 and is_equal_approx(B.passive_num("stormcaller", 2, "more"), 0.25), "at step 6, rank IV: 25% more")
	_check(B.passive_at("stormcaller", 6)["name"] == "Static IV", "...its card says Static IV")


# --- a Zenith, cast for real ---------------------------------------------------------------------------

func _zenith_cast() -> void:
	await _marked("stormcaller", 12)
	var main = _main()
	var p = main.player
	var b = p.bonds["hand"]
	var foes: Array = []
	# One ahead, in your aim (Call Lightning strikes it); two close at your sides (the Zenith's bolts find them).
	foes.append(_foe(p.global_position + dir * 150.0))
	for s in [-1.0, 1.0]:
		foes.append(_foe(p.global_position + dir.orthogonal() * 55.0 * s + dir * 10.0))
	await t._frames(2)
	b.select(0)
	b.essence = b.capacity()
	p.attack_cd = 0.0
	p.cast_t = 0.0
	p.aim = dir
	p._try_cast("hand")
	await t._wait(b.windup() + 0.3)
	var hurt := 0
	var charged := 0
	for e in foes:
		if not is_instance_valid(e) or e.dead or e.hp < e.max_hp:
			hurt += 1
		if is_instance_valid(e) and not e.dead and e.charged > 0.0:
			charged += 1
	_check(hurt == 3 and charged >= 2, "Crown of Storms: casting Call Lightning also calls bolts down on the 2 foes nearest you (%d hurt, %d charged)" % [hurt, charged])
	var ready_at: int = int(b.fx_ready.get("zenith_stormcaller:0", 0))
	_check(ready_at > Time.get_ticks_msec(), "...and not again for a moment")


# --- each kind of effect --------------------------------------------------------------------------------

func _effects() -> void:
	var Fx = load("res://scripts/spells/ascent.gd")
	# A shell and a shove (the Warden's Zenith).
	await _marked("warden", 12)
	var main = _main()
	var p = main.player
	var b = p.bonds["hand"]
	var e = _foe(p.global_position + dir * 60.0)
	var sp: Dictionary = b.spells()[0]
	p.barrier_hp = 0.0
	for fx in A.zenith("warden")["fx"]:
		Fx.run(p, b, sp, fx)
	_check(p.barrier_hp >= 17.0, "Aegis Eternal: a shell of 18 (%.0f)" % p.barrier_hp)
	_check(is_instance_valid(e) and e.hp < e.max_hp, "...and its edge strikes the foe beside you")
	# A meteor after its warning ring (the Flame Contractor's Zenith).
	await _marked("flame_contractor", 12)
	main = _main()
	p = main.player
	b = p.bonds["hand"]
	var zfx: Dictionary = A.zenith("flame_contractor")["fx"][0]
	e = _foe(p.global_position + dir * float(zfx["range"]))
	Fx.run(p, b, b.spells()[0], zfx)
	await t._wait(float(zfx["delay"]) * 0.5)
	var mid: float = e.hp if is_instance_valid(e) else 0.0
	await t._wait(float(zfx["delay"]) * 0.5 + 0.25)
	_check(is_equal_approx(mid, e.max_hp if is_instance_valid(e) else -1.0) and (not is_instance_valid(e) or e.hp < e.max_hp), "Heart of the Sun: a ring warns first, then the meteor lands where you aimed")
	# Blades circling you (the Blade Forger's Zenith).
	await _marked("blade_forger", 12)
	main = _main()
	p = main.player
	b = p.bonds["hand"]
	zfx = A.zenith("blade_forger")["fx"][0]
	e = _foe(p.global_position + dir * float(zfx["radius"]))
	Fx.run(p, b, b.spells()[0], zfx)
	await t._wait(1.2)
	_check(not is_instance_valid(e) or e.hp < e.max_hp, "Armory Unbound: the blades circling you cut a foe they pass")
	# A rune circle (the Rune Artist's Zenith).
	await _marked("rune_artist", 12)
	main = _main()
	p = main.player
	b = p.bonds["hand"]
	e = _foe(p.global_position + dir * 30.0)
	Fx.run(p, b, b.spells()[0], A.zenith("rune_artist")["fx"][0])
	await t._wait(0.8)
	_check(not is_instance_valid(e) or e.hp < e.max_hp, "The Living Script: the rune circle sears a foe inside it")
	# A wave of fire (the Flameblade's Zenith).
	await _marked("flameblade", 12)
	main = _main()
	p = main.player
	b = p.bonds["hand"]
	e = _foe(p.global_position + dir * 100.0)
	p.aim = dir
	Fx.run(p, b, b.spells()[0], A.zenith("flameblade")["fx"][0])
	await t._wait(0.8)
	_check(not is_instance_valid(e) or e.hp < e.max_hp, "Sunforged: a wave of fire runs along your aim")
	# A spirit creature (the Covenant's Zenith).
	await _marked("covenant", 12)
	main = _main()
	p = main.player
	b = p.bonds["hand"]
	var before: int = main.allies().size()
	Fx.run(p, b, b.spells()[0], A.zenith("covenant")["fx"][0])
	await t._frames(2)
	_check(main.allies().size() == before + 1, "Kinlord: a spirit comes to fight beside you")
	# A surge (Firestorm, after Meteor) and an echo (Twin Flame).
	await _marked("flame_contractor", 12)
	main = _main()
	p = main.player
	b = p.bonds["hand"]
	var meteor: Dictionary = b.spells()[3]
	var pw0: float = b.spell_power(meteor)
	Fx.run(p, b, meteor, A.sides("flame_contractor", 11)[1]["fx"][0])
	_check(b.spell_power(meteor) > pw0 * 1.2, "Firestorm: after Meteor the mark's spells hit 25% harder for a while")
	b.surge_until = 0
	e = _foe(p.global_position + dir * 120.0)
	p.aim = dir
	b.select(0)
	var timers: int = load("res://scripts/spell_fx.gd").of(main).timers.size()
	Fx.run(p, b, b.spells()[0], A.sides("flame_contractor", 10)[0]["fx"][0])
	_check(load("res://scripts/spell_fx.gd").of(main).timers.size() == timers + 1, "Twin Flame: a second fireball is on its way")
	await t._wait(1.2)
	_check(not is_instance_valid(e) or e.hp < e.max_hp, "...and it lands")
	# A burst around you with a state (the Tidecaller's Zenith: soaked).
	await _marked("tidecaller", 12)
	main = _main()
	p = main.player
	b = p.bonds["hand"]
	e = _foe(p.global_position + dir * 80.0)
	Fx.run(p, b, b.spells()[0], A.zenith("tidecaller")["fx"][0])
	_check(is_instance_valid(e) and load("res://scripts/reactions.gd").has(e, "soaked") and e.hp < e.max_hp, "Leviathan Tide: a ring of water strikes and soaks the foes near you")


# --- helpers ---------------------------------------------------------------------------------------------

## A fresh climber with one mark on the hand at a step, alone, facing open floor.
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
		for k in range(1, 14):
			var at: Vector2 = p.global_position + d * 20.0 * k
			if main.is_solid(at) or not main.room.grow(-20.0).has_point(at):
				open = false
		if open:
			dir = d
			break
	p.aim = dir


## A foe that stands still where the test puts it.
func _foe(at: Vector2, hp := 400.0):
	var e = _main().spawn_enemy("slime", at)
	e.set_physics_process(false)
	e.global_position = at
	e.max_hp = hp
	e.hp = hp
	e.aware = false
	return e
