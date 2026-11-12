extends RefCounted
## The marks' growth for the Firebird's and the Chimera's bonds: each step-3
## Transformation does its new thing through real casts, each passive grows
## to rank II at step 3 and rank III at step 5, each step-5 spell's Apex
## works, and an old save's step-3 choice maps to the first side (A) or the
## second (B). Run by smoke_test.gd (_part_tests).

const TOWERS := {
	"flame_contractor": "hand", "flamewing": "heart", "rekindler": "back",
	"covenant": "hand", "grafter": "legs", "surgeon": "brow",
}
const STEP3 := 450.0
const STEP5 := 1800.0

var t
var TR = load("res://scripts/tree.gd")
var B = load("res://scripts/bonds.gd")
var L = load("res://scripts/library.gd")
var R = load("res://scripts/reactions.gd")


func run(smoke) -> void:
	t = smoke
	await _old_saves()
	await _ranks_shown()
	await _sunfire()
	await _seeker_flame()
	await _furnace()
	await _ember_wings()
	await _bonfire()
	await _cauterize()
	await _pack_call()
	await _champion()
	await _hungry_flesh()
	await _flesh_shell()
	await _vivisect()
	await _arterial()
	await _fire_passives()
	await _chimera_passives()
	await _fire_apex()
	await _chimera_apex()
	Engine.time_scale = 1.0


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## A climber whose only mark is `bond_id`, at the step `xp` gives; `side`
## "B" chooses step 3's second side (anything else leaves the first).
func _bonded(bond_id: String, xp: float, side := "") -> void:
	await t._fresh_main()
	t.paused = false
	var main = t.main
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.profile.add_bond(TOWERS[bond_id], bond_id, false)
	main.profile.bonds[TOWERS[bond_id]]["xp"] = xp
	main.profile.regarded = true
	main.first_climb = false
	if side == "B":
		TR.choose(main.profile, "mark:%s:3" % bond_id, String(TR.fork_alt(bond_id, 3)["id"]))
	main._give_bonds()
	main.player.iframes = 999.0
	main.player.aim = Vector2.RIGHT
	for e in main.enemies():
		e.set_physics_process(false)


func _mark(bond_id: String, spell_id: String):
	var b = t.main.player.bonds[TOWERS[bond_id]]
	var i: int = b.spells().map(func(sp): return sp["id"]).find(spell_id)
	if i >= 0:
		b.select(i)
	b.essence = b.capacity()
	return b


func _cast(b) -> float:
	var p = t.main.player
	var before: float = b.essence
	p.cast_part = b.part
	p.attack_cd = 0.0
	p._release_cast()
	return before - b.essence


## Foes with plenty of health at `offsets` from the climber (the rest far away).
func _foes(offsets: Array, hp := 300.0) -> Array:
	var main = t.main
	var p = main.player
	var all: Array = main.enemies().filter(func(e): return e.kind != "lurker" and not e.is_boss())  # (a lurker under the water won't burn)
	for e in main.enemies():
		if not e in all:
			e.global_position = p.global_position + Vector2(-5000.0, -5000.0)
	var out: Array = []
	for i in all.size():
		var e = all[i]
		if i < offsets.size():
			e.hp = hp
			e.max_hp = hp
			e.global_position = p.global_position + offsets[i]
			e.face = Vector2.LEFT  # (facing you: no backstabs)
			out.append(e)
		else:
			e.global_position = p.global_position + Vector2(-4000.0 - 60.0 * i, -4000.0)
	return out


func _step3(bond_id: String) -> Dictionary:
	return B.BONDS[bond_id]["spells"][0]["steps"][3]


func _alt3(bond_id: String) -> Dictionary:
	return TR.fork_alt(bond_id, 3)["steps"][3]


# --- old saves -----------------------------------------------------------------------

func _old_saves() -> void:
	print("marks (Firebird, Chimera): an old save's step-3 choice maps to a Transformation")
	for bond_id in TOWERS:
		var alt: Dictionary = TR.fork_alt(bond_id, 3)
		var ch: Dictionary = L.MARK_FORKS[bond_id]["change"]
		# Today's side, chosen (or never chosen, or a save from before the tree): side A.
		await _bonded(bond_id, STEP5)
		var main = t.main
		TR.migrate(main.profile)
		main._give_bonds()
		var b = main.player.bonds[TOWERS[bond_id]]
		var node: Dictionary = TR.mark_nodes(main.profile, TOWERS[bond_id]).filter(func(n): return int(n["at"]) == 3)[0]
		_check(TR.mark_choice(main.profile, bond_id, 3) == TR.CHANGE and b.alt_change().is_empty() and String(node["options"][0]["name"]) == String(ch["name"]),
			"%s: an old save with today's step-3 side has %s (side A)" % [bond_id, ch["name"]])
		# The other side, chosen: side B, by the same id.
		await _bonded(bond_id, STEP5, "B")
		main = t.main
		b = main.player.bonds[TOWERS[bond_id]]
		_check(TR.mark_choice(main.profile, bond_id, 3) == String(alt["id"]) and String(b.alt_change().get("name", "")) == String(alt["name"]) and bool(alt.get("transform", false)),
			"...and one with the other side (%s) has %s (side B)" % [alt["id"], alt["name"]])


func _ranks_shown() -> void:
	print("marks (Firebird, Chimera): passive ranks are written and shown")
	_check(B.passive_rank(1) == 1 and B.passive_rank(2) == 1 and B.passive_rank(3) == 2 and B.passive_rank(4) == 2 and B.passive_rank(5) == 3, "a passive is rank I, II from step 3, III at step 5")
	for bond_id in TOWERS:
		var name: String = B.BONDS[bond_id]["passive"]["name"]
		var s1: Dictionary = B.passive_shown(bond_id, 1)
		var s3: Dictionary = B.passive_shown(bond_id, 3)
		var s5: Dictionary = B.passive_shown(bond_id, 5)
		_check(B.passive_line(bond_id, 2) != "" and B.passive_line(bond_id, 3) != "", "%s's passive has a line for ranks II and III" % bond_id)
		_check(s1["name"] == name and s3["name"] == name + " II" and s5["name"] == name + " III" and B.passive_line(bond_id, 2) in s3["desc"] and B.passive_line(bond_id, 3) in s5["desc"] and not B.passive_line(bond_id, 3) in s3["desc"],
			"...shown with its rank and its new line (%s)" % s5["name"])
		_check("II" in B.step_note(bond_id, 3) and "III" in B.step_note(bond_id, 5), "...and step 3's and step 5's notes say it grows")
		for sp in B.BONDS[bond_id]["spells"]:
			if int(sp["learn"]) == 5:
				_check(String(sp.get("apex", "")) != "", "...%s has its Apex written" % sp["name"])
	var words := ""
	for bond_id in TOWERS:
		words += JSON.stringify(B.BONDS[bond_id]).to_lower() + JSON.stringify(L.MARK_FORKS[bond_id]).to_lower()
	_check(not ["attunement", "spire", "trial", "judgment", "mana"].any(func(w): return w in words), "no banned words in these marks")
	_check(not "pact book" in words and "kin book" in words, "Covenant's book is the kin book")
	# The book's Marks tab and the cards show the rank.
	await _bonded("flamewing", STEP3)
	var main = t.main
	var entries: Array = load("res://scripts/abilities.gd").entries(main) if load("res://scripts/abilities.gd").has_method("entries") else []
	if not entries.is_empty():
		var mk: Array = entries.filter(func(e): return e.get("kind", "") == "mark")
		_check(not mk.is_empty() and "Fireproof II" in String(mk[0]["does"]), "the mark's card shows Fireproof II")


# --- the Transformations: the Firebird ------------------------------------------------

func _sunfire() -> void:
	print("Transformations: Sunfire")
	await _bonded("flame_contractor", STEP3)
	var main = t.main
	var p = main.player
	_foes([])
	main.flames.clear()
	var b = _mark("flame_contractor", "fireball")
	_check(is_equal_approx(b.windup(), float(_step3("flame_contractor")["windup"])), "Sunfire winds up as written (%.2f s)" % b.windup())
	_cast(b)
	var balls: Array = main.get_children().filter(func(c): return "explode_r" in c and c.style == "fireball")
	_check(balls.size() == 1 and is_equal_approx(balls[0].vel.length(), float(_step3("flame_contractor")["speed"])) and balls[0].scale.x > 1.2,
		"...a slower, larger fireball (%.0f px/s)" % (balls[0].vel.length() if not balls.is_empty() else 0.0))
	await t._wait(0.7)
	var ground: Array = main.flames.filter(func(f): return f.get("friendly", false))
	var far := 0.0
	for f in ground:
		far = maxf(far, f["pos"].x - p.global_position.x)
	_check(ground.size() >= 5 and far > 120.0, "...that leaves burning ground along its path (%d patches, out to %.0f px)" % [ground.size(), far])


func _seeker_flame() -> void:
	print("Transformations: Seeker Flame")
	await _bonded("flame_contractor", STEP3, "B")
	var main = t.main
	var p = main.player
	var foe = _foes([Vector2(170, 75)])[0]
	var b = _mark("flame_contractor", "fireball")
	_cast(b)
	var hit1 := 0.0
	for i in 90:
		await t._frames(1)
		if foe.hp < 300.0:
			hit1 = 300.0 - foe.hp
			break
	_check(hit1 > 0.0, "Seeker Flame curves to a foe off your aim (%.0f)" % hit1)
	await t._wait(float(_alt3("flame_contractor")["delay"]) + 0.25)
	var hit2: float = 300.0 - foe.hp - hit1
	_check(hit2 >= hit1 * float(_alt3("flame_contractor")["again"]) * 0.9, "...and explodes twice (%.0f, then %.0f)" % [hit1, hit2])


func _furnace() -> void:
	print("Transformations: Furnace")
	await _bonded("flamewing", STEP3)
	var main = t.main
	var p = main.player
	var foe = _foes([Vector2(45, 0)])[0]
	var b = _mark("flamewing", "heat_aura")
	_cast(b)
	_check(p.aura_part == "heart" and p.aura_slow and is_equal_approx(p.aura_heat_mult, float(_step3("flamewing")["heat"])), "Furnace: the aura is lit, slowing, its heat building %.0fx" % p.aura_heat_mult)
	await t._wait(1.1)
	_check(R.has(foe, "slowed") and p.aura_heat > 2.0 * p.aura_dmg, "...foes in it are slowed and the heat builds fast (%.1f)" % p.aura_heat)


func _ember_wings() -> void:
	print("Transformations: Ember Wings")
	await _bonded("flamewing", STEP3, "B")
	var main = t.main
	var p = main.player
	var side = _foes([Vector2(0, 115), Vector2(115, 0)])
	var b = _mark("flamewing", "heat_aura")
	_cast(b)
	_check(p.aura_part == "heart" and not p.aura_grows, "Ember Wings: the aura is lit")
	await t._wait(0.6)
	_check(side[0].hp < 300.0 and side[0].knock.length() > 50.0, "...its wings reach foes at your side, burning and knocking them away (%.0f)" % side[0].hp)
	_check(side[1].hp == 300.0, "...not foes ahead past the aura")
	_cast(b)
	await t._frames(3)
	var hp_now: float = side[0].hp
	await t._wait(0.6)
	_check(side[0].hp == hp_now, "...and they fold away when the aura goes out")


func _bonfire() -> void:
	print("Transformations: Bonfire")
	await _bonded("rekindler", STEP3)
	var main = t.main
	var p = main.player
	var foes := _foes([Vector2(30, 0), Vector2(30, 30), Vector2(30, -30)])
	var b = _mark("rekindler", "rekindle")
	p.hp = p.max_hp * 0.5
	_cast(b)
	for e in foes:
		p._strike(e, 1.0, Vector2.RIGHT, 0.0, false)
	_check(foes.all(func(e): return R.has(e, "burning")) and p.rekindle_burned.size() == 3, "Bonfire: foes you strike while you burn catch fire")
	await t._wait(0.6)
	var lost: float = p.rekindle_lost
	var low: float = p.hp
	p.rekindle_t = 0.01
	await t._frames(3)
	var want: float = lost * (2.0 + float(_step3("rekindler")["per_burning"]) * 3)
	_check(lost > 0.0 and absf((p.hp - low) - want) < 1.0, "...and the payback grows with each (%.1f back for %.1f lost)" % [p.hp - low, lost])


func _cauterize() -> void:
	print("Transformations: Cauterize")
	await _bonded("rekindler", STEP3, "B")
	var main = t.main
	var p = main.player
	var foe = _foes([Vector2(30, 0)])[0]
	var b = _mark("rekindler", "rekindle")
	p.hp = p.max_hp * 0.5
	var h0: float = p.hp
	_cast(b)
	_check(absf(p.hp - h0 - p.max_hp * float(_alt3("rekindler")["mend"])) < 1.0, "Cauterize heals you a little at once (+%.0f)" % (p.hp - h0))
	p._strike(foe, 1.0, Vector2.RIGHT, 0.0, false)
	await t._wait(0.6)
	var lost: float = p.rekindle_lost
	var low: float = p.hp
	p.barrier_hp = 0.0
	p.rekindle_t = 0.01
	await t._frames(3)
	_check(lost > 0.0 and p.hp <= low + 0.5 and absf(p.barrier_hp - lost * float(_alt3("rekindler")["shield"])) < 1.0,
		"...and the payback comes as a barrier (%.0f for %.1f lost)" % [p.barrier_hp, lost])


# --- the Transformations: the Chimera -------------------------------------------------

func _pack_call() -> void:
	print("Transformations: Pack Call")
	await _bonded("covenant", STEP3)
	var main = t.main
	var p = main.player
	_foes([])
	main.profile.pacts = []
	var b = _mark("covenant", "bind_and_call")
	_cast(b)
	var out: Array = main.allies()
	var full: float = 30.0 + 15.0 * 3
	var power := float(_step3("covenant")["power"])
	_check(out.size() == 2 and out.all(func(a): return is_equal_approx(a.max_hp, full * power) and a.has_meta("pack")), "Pack Call: two creatures, each a little weaker (%s)" % [out.map(func(a): return int(a.max_hp))])
	if out.size() == 2:
		out[1].global_position = out[0].global_position + Vector2(30, 0)
		var blow: float = out[0].get_meta("ally_strike").call(out[0], null, 10.0)
		_check(is_equal_approx(blow, 10.0 * (1.0 + float(_step3("covenant")["pack"]))), "...that hunt as a pack: a blow lands harder with a packmate near (%.1f)" % blow)
		out[1].global_position = out[0].global_position + Vector2(600, 0)
		blow = out[0].get_meta("ally_strike").call(out[0], null, 10.0)
		_check(is_equal_approx(blow, 10.0), "...and as hard as ever alone")
	b.essence = b.capacity()
	_cast(b)
	_check(main.allies().size() == 3, "...never more than three out at once")


func _champion() -> void:
	print("Transformations: Champion Bond")
	await _bonded("covenant", STEP3, "B")
	var main = t.main
	var p = main.player
	_foes([])
	main.profile.pacts = []
	var b = _mark("covenant", "bind_and_call")
	_cast(b)
	var out: Array = main.allies()
	var full: float = 30.0 + 15.0 * 3
	var might := float(_alt3("covenant")["might"])
	_check(out.size() == 1 and is_equal_approx(out[0].max_hp, full * might), "Champion Bond: one champion, stronger (%.0f health)" % (out[0].max_hp if not out.is_empty() else 0.0))
	if out.is_empty():
		return
	var champ = out[0]
	var dmg0: float = champ.dmg
	var foe = _foes([Vector2(80, 0)], 1.0)[0]
	champ.global_position = foe.global_position + Vector2(-20, 0)
	champ.ally_cd = 0.0
	champ.ally_target = foe
	for i in 120:
		await t._frames(1)
		if not is_instance_valid(foe) or foe.dead:
			break
	await t._frames(2)
	var grow := float(_alt3("covenant")["grow"])
	_check((not is_instance_valid(foe) or foe.dead) and is_equal_approx(champ.dmg, dmg0 * (1.0 + grow)), "...that grows with a kill it makes (%.1f -> %.1f)" % [dmg0, champ.dmg])
	champ._fade_ally()
	await t._frames(2)
	b.essence = b.capacity()
	_cast(b)
	var next: Array = main.allies()
	_check(next.size() == 1 and is_equal_approx(next[0].max_hp, full * might * (1.0 + grow)), "...and a champion called later on the floor starts that big")
	main._start_floor(main.floor_num)
	await t._frames(2)
	for e in main.enemies():
		e.set_physics_process(false)
	b = _mark("covenant", "bind_and_call")
	_foes([])
	_cast(b)
	next = main.allies()
	_check(next.size() == 1 and is_equal_approx(next[0].max_hp, full * might), "...until a new floor")


func _hungry_flesh() -> void:
	print("Transformations: Hungry Flesh")
	await _bonded("grafter", STEP3)
	var main = t.main
	var p = main.player
	main.grafts.clear()
	main.graft_order.clear()
	var foes := _foes([Vector2(50, 0), Vector2(-60, 20)])
	foes[0].hp = 120.0  # below half
	var kind: String = foes[0].kind
	var b = _mark("grafter", "graft_burst")
	_check(bool(b.stat("effects")), "Hungry Flesh keeps each graft's own effect")
	_cast(b)
	var burst: float = 300.0 - foes[1].hp
	_check(main.grafts.values().has(kind) and 120.0 - foes[0].hp >= burst * 1.9, "...and tears a graft from a foe below half health, striking it again (%s, %.0f)" % [kind, 120.0 - foes[0].hp])
	_check(main.grafts.size() == 1, "...one a burst (the healthy foe keeps its flesh)")


func _flesh_shell() -> void:
	print("Transformations: Flesh Shell")
	await _bonded("grafter", STEP3, "B")
	var main = t.main
	var p = main.player
	main.grafts.clear()
	main.graft_order.clear()
	main.add_graft("bat")
	main.add_graft("knight")
	var foe = _foes([Vector2(50, 0)])[0]
	p.barrier_hp = 0.0
	var b = _mark("grafter", "graft_burst")
	_cast(b)
	var want: float = float(_alt3("grafter")["shell"]) + float(_alt3("grafter")["per_shell"]) * 2
	_check(foe.hp < 300.0 and is_equal_approx(p.barrier_hp, want), "Flesh Shell: the burst strikes, and grows a shell, thicker for each graft (%.0f)" % p.barrier_hp)


func _vivisect() -> void:
	print("Transformations: Vivisect")
	await _bonded("surgeon", STEP3)
	var main = t.main
	var p = main.player
	var foe = _foes([Vector2(70, 0)], 900.0)[0]
	var b = _mark("surgeon", "sever")
	_cast(b)
	_check(foe.cripple_t > 0.0 and foe.disarm_t <= 0.0 and foe.has_meta("weak_point"), "Vivisect cuts, cripples and finds a weak point")
	var mult := float(_step3("surgeon")["crit"])
	var hits: Array = []
	for i in int(_step3("surgeon")["crits"]) + 1:
		foe.stun = 0.0
		var h0: float = foe.hp
		p._strike(foe, 10.0, Vector2.RIGHT, 0.0, false)
		hits.append(h0 - foe.hp)
	var n := int(_step3("surgeon")["crits"])
	_check(hits.slice(0, n).all(func(h): return is_equal_approx(h, 10.0 * mult)) and is_equal_approx(hits[n], 10.0), "...your next %d hits on it are critical (%s)" % [n, hits])


func _arterial() -> void:
	print("Transformations: Arterial Cut")
	var lost := {}
	for side in ["A", "B"]:
		await _bonded("surgeon", STEP3, side)
		var main = t.main
		var foe = _foes([Vector2(70, 0)], 900.0)[0]
		foe.set_physics_process(true)  # (a foe bleeds as it moves on)
		var b = _mark("surgeon", "sever")
		_cast(b)
		var h0: float = foe.hp
		await t._wait(2.1)
		lost[side] = h0 - foe.hp
	_check(lost["B"] >= lost["A"] * 3.0 and lost["B"] > 10.0, "Arterial Cut bleeds hard (%.0f in 2 s, against %.0f)" % [lost["B"], lost["A"]])


# --- passive ranks ------------------------------------------------------------------------

func _fire_passives() -> void:
	print("passive ranks: Kindled, Fireproof, Last Ember")
	# Kindled II: your burning ground spreads.
	await _bonded("flame_contractor", 150.0)
	var main = t.main
	var p = main.player
	_foes([])
	main.flames.clear()
	main.add_flame(p.global_position + Vector2(100, 0), 18.0, 3.0, true)
	await t._wait(1.0)
	_check(is_equal_approx(main.flames[0]["r"], 18.0), "Kindled I: your burning ground stays as it was")
	await _bonded("flame_contractor", STEP3)
	main = t.main
	p = main.player
	_foes([])
	main.flames.clear()
	main.add_flame(p.global_position + Vector2(100, 0), 18.0, 3.0, true)
	await t._wait(1.0)
	_check(main.flames[0]["r"] > 20.0, "Kindled II: it slowly spreads (%.1f)" % main.flames[0]["r"])
	# Kindled III: fire kills refund essence.
	var foe = _foes([Vector2(100, 0)], 5.0)[0]
	var b = p.bonds["hand"]
	b.essence = 0.0
	main.explode(foe.global_position, 40.0, 99.0, Color.ORANGE)
	_check(b.essence == 0.0, "...no refund before rank III")
	await _bonded("flame_contractor", STEP5)
	main = t.main
	p = main.player
	foe = _foes([Vector2(100, 0)], 5.0)[0]
	b = p.bonds["hand"]
	b.essence = 0.0
	main.explode(foe.global_position, 40.0, 99.0, Color.ORANGE)
	_check(is_equal_approx(b.essence, B.passive_num("flame_contractor", "refund")), "Kindled III: a foe your fire kills gives the mark back essence (%.1f)" % b.essence)
	# Fireproof II: standing in fire heals you.
	await _bonded("flamewing", STEP3)
	main = t.main
	p = main.player
	_foes([])
	p.hp = 50.0
	main.flames = [{"pos": p.global_position, "r": 40.0, "t": 3.0, "max": 3.0, "friendly": true, "tick": 0.0}]
	await t._wait(1.2)
	_check(p.hp > 50.0, "Fireproof II: standing in fire heals you a little (%.1f)" % p.hp)
	p.aura_heat = 0.0
	main.flames = [{"pos": p.global_position, "r": 40.0, "t": 3.0, "max": 3.0, "tick": 0.0}]
	await t._wait(0.7)
	_check(p.aura_heat == 0.0, "...fire doesn't feed the aura before rank III")
	await _bonded("flamewing", STEP5)
	main = t.main
	p = main.player
	_foes([])
	b = p.bonds["heart"]
	b.essence = 0.0
	p.aura_heat = 0.0
	p.hp = p.max_hp
	main.flames = [{"pos": p.global_position, "r": 40.0, "t": 3.0, "max": 3.0, "tick": 0.0}]
	await t._wait(1.2)
	_check(p.hp == p.max_hp and p.aura_heat > 0.0 and b.essence > 0.0, "Fireproof III: fire that would hurt you feeds the aura (heat %.0f, essence %.1f)" % [p.aura_heat, b.essence])
	main.flames = []
	# Last Ember II: twice a floor.
	await _bonded("rekindler", 150.0)
	main = t.main
	p = main.player
	foe = _foes([Vector2(30, 0)])[0]
	p.iframes = 0.0
	p.hurt_t = 0.0
	p.receive_attack(9999.0, null)
	p._strike(foe, 1.0, Vector2.RIGHT, 0.0, false)
	p.hp = p.max_hp
	p.hurt_t = 0.0
	p.receive_attack(9999.0, null)
	_check(p.dead, "Last Ember I: once a floor")
	await _bonded("rekindler", STEP3)
	main = t.main
	p = main.player
	foe = _foes([Vector2(30, 0)])[0]
	p.iframes = 0.0
	for i in 2:
		p.hp = p.max_hp
		p.hurt_t = 0.0
		p.receive_attack(9999.0, null)
		var held: bool = not p.dead and p.ember_t > 0.0
		p._strike(foe, 1.0, Vector2.RIGHT, 0.0, false)
		_check(held, "Last Ember II: it works twice a floor (%d)" % (i + 1))
	_check(foe.hp > 300.0 - 10.0, "...surviving it doesn't erupt before rank III")
	p.hp = p.max_hp
	p.hurt_t = 0.0
	p.receive_attack(9999.0, null)
	_check(p.dead, "...but not three times")
	await _bonded("rekindler", STEP5)
	main = t.main
	p = main.player
	foe = _foes([Vector2(60, 0)])[0]
	p.iframes = 0.0
	p.hurt_t = 0.0
	p.receive_attack(9999.0, null)
	p._strike(foe, 1.0, Vector2.RIGHT, 0.0, false)
	_check(300.0 - foe.hp >= B.passive_num("rekindler", "erupt") and not p.dead, "Last Ember III: surviving it erupts in flame (%.0f)" % (300.0 - foe.hp))


func _chimera_passives() -> void:
	print("passive ranks: Kinship, Grafting, Diagnosis")
	# Kinship II: creatures stay longer; III: a falling creature heals you.
	await _bonded("covenant", 150.0)
	var main = t.main
	var p = main.player
	_foes([])
	var b = _mark("covenant", "bind_and_call")
	_cast(b)
	var a1: float = main.allies()[0].ally_t
	await _bonded("covenant", STEP3)
	main = t.main
	p = main.player
	_foes([])
	b = _mark("covenant", "bind_and_call")
	_cast(b)
	var a3: float = main.allies()[0].ally_t
	_check(absf(a3 - a1 * B.passive_num("covenant", "stay")) < 0.5, "Kinship II: your creatures stay longer (%.0f s, not %.0f)" % [a3, a1])
	p.hp = 50.0
	main.allies()[0].receive_attack(9999.0, null)
	_check(p.hp == 50.0, "...a falling creature doesn't heal you before rank III")
	await _bonded("covenant", STEP5)
	main = t.main
	p = main.player
	_foes([])
	b = _mark("covenant", "bind_and_call")
	_cast(b)
	p.hp = 50.0
	var c = main.allies()[0]
	var want: float = c.max_hp * B.passive_num("covenant", "fall_heal") * p.heal_mult()
	c.receive_attack(9999.0, null)
	_check(absf(p.hp - 50.0 - want) < 0.5, "Kinship III: a creature that falls heals you (+%.1f)" % (p.hp - 50.0))
	# Grafting II: grafts give health; III: a new graft heals its part's burn.
	await _bonded("grafter", 150.0)
	main = t.main
	p = main.player
	var m0: float = p.max_health()
	main.add_graft("bat")
	_check(p.max_health() == m0, "Grafting I: a graft gives no health")
	await _bonded("grafter", STEP3)
	main = t.main
	p = main.player
	m0 = p.max_health()
	main.add_graft("bat")
	main.add_graft("knight")
	_check(is_equal_approx(p.max_health(), m0 + 2.0 * B.passive_num("grafter", "graft_health")), "Grafting II: each graft gives a little health (%.0f -> %.0f)" % [m0, p.max_health()])
	p.bonds["legs"].burned = true
	main.add_graft(_kind_for(main, "legs"))
	_check(p.bonds["legs"].burned, "...a new graft doesn't heal a burn before rank III")
	await _bonded("grafter", STEP5)
	main = t.main
	p = main.player
	p.bonds["legs"].burned = true
	_check(main.add_graft(_kind_for(main, "legs")) and not p.bonds["legs"].burned, "Grafting III: a new graft heals its body part's burn")
	# Diagnosis II: a strike where it's weak staggers; III: Mend heals more near bleeding foes.
	await _bonded("surgeon", 150.0)
	main = t.main
	p = main.player
	var foe = _foes([Vector2(30, 0)], 900.0)[0]
	foe.face = Vector2.RIGHT  # (its back to you)
	foe.stun = 0.0
	p._strike(foe, 1.0, Vector2.RIGHT, 0.0, false)
	_check(foe.stun <= 0.0, "Diagnosis I: a blow from behind doesn't stagger")
	await _bonded("surgeon", STEP3)
	main = t.main
	p = main.player
	foe = _foes([Vector2(30, 0)], 900.0)[0]
	foe.face = Vector2.RIGHT
	foe.stun = 0.0
	p._strike(foe, 1.0, Vector2.RIGHT, 0.0, false)
	_check(foe.stun > 0.0, "Diagnosis II: striking a foe where it's weak (from behind) staggers it")
	foe.stun = 0.0
	foe.face = Vector2.LEFT
	foe.open_t = 0.0
	p._strike(foe, 1.0, Vector2.RIGHT, 0.0, false)
	_check(foe.stun <= 0.0, "...a plain blow from the front doesn't")
	await _bonded("surgeon", STEP5)
	main = t.main
	p = main.player
	var foes := _foes([Vector2(60, 0), Vector2(60, 40)], 900.0)
	b = _mark("surgeon", "mend")
	p.hp = 20.0
	_cast(b)
	var plain: float = p.hp - 20.0
	for e in foes:
		R.apply(main, e, "bleeding", 6.0, "test")
	b.essence = b.capacity()
	p.hp = 20.0
	_cast(b)
	var more: float = p.hp - 20.0
	_check(absf(more - plain * (1.0 + 2.0 * B.passive_num("surgeon", "mend_per"))) < 0.6, "Diagnosis III: Mend heals more for every bleeding foe near you (%.0f, not %.0f)" % [more, plain])


## A monster kind whose graft goes on `part` (main.gd GRAFT_PART).
func _kind_for(main, part: String) -> String:
	for k in main.GRAFT_PART:
		if main.GRAFT_PART[k] == part:
			return k
	return "slime"


# --- the Apex upgrades -------------------------------------------------------------------

func _fire_apex() -> void:
	print("Apex: Meteor, Firebird Form, Phoenix Heart")
	await _bonded("flame_contractor", STEP5)
	var main = t.main
	var p = main.player
	var foe = _foes([Vector2(160, 0)], 900.0)[0]
	main.flames.clear()
	var b = _mark("flame_contractor", "meteor")
	_check(is_equal_approx(b.windup(), 0.5), "Meteor: half the wind-up (%.2f s)" % b.windup())
	_cast(b)
	await t._wait(0.8)
	var crater: Array = main.flames.filter(func(f): return f.get("friendly", false) and f["pos"].distance_to(foe.global_position) < 130.0)
	_check(foe.hp < 900.0 - 40.0 and crater.size() >= 5, "...and it leaves a burning crater (%d patches)" % crater.size())
	# Firebird Form: you fly over chasms and hazards.
	await _bonded("flamewing", STEP5)
	main = t.main
	p = main.player
	_foes([])
	b = _mark("flamewing", "firebird_form")
	_check(not p.flying(), "you don't fly before Firebird Form")
	_cast(b)
	_check(p.flying() and p.in_air() and p.jump_height() > 4.0, "Firebird Form: you fly while it lasts")
	var at: Vector2 = p.global_position
	var floor0: int = main.floor_num
	main.chasms = [Rect2(at - Vector2(40, 40), Vector2(80, 80))]
	await t._frames(4)
	_check(main.floor_num == floor0 and p.global_position.distance_to(at) < 4.0, "...over a chasm without falling")
	p.hp = p.max_hp
	p.iframes = 0.0
	main.flames = [{"pos": p.global_position, "r": 40.0, "t": 2.0, "max": 2.0, "tick": 0.0}]
	main.puddles = [{"pos": p.global_position, "r": 60.0}]
	_check(main.water_slow(p.global_position, p.flying()) == 1.0, "...and water doesn't slow you")
	main.chasms = []
	main.flames = []
	main.puddles = []
	p.iframes = 999.0
	p.firebird_t = 0.0
	_check(not p.flying(), "...and you land when it ends")
	# Phoenix Heart: at its end you regain what it held back.
	await _bonded("rekindler", STEP5)
	main = t.main
	p = main.player
	_foes([])
	b = _mark("rekindler", "phoenix_heart")
	_cast(b)
	p.iframes = 0.0
	p.hurt_t = 0.0
	p.hp = 20.0
	p.receive_attack(50.0, null)
	_check(p.hp == 1.0 and p.phoenix_held > 20.0, "Phoenix Heart keeps you at 1 health and holds back what it stopped (%.0f)" % p.phoenix_held)
	var held: float = p.phoenix_held
	p.iframes = 999.0
	p.phoenix_t = 0.01
	await t._wait(0.2)
	_check(absf(p.hp - 1.0 - held) < 0.5 and p.phoenix_held == 0.0, "...and gives it back at its end (+%.0f)" % (p.hp - 1.0))


func _chimera_apex() -> void:
	print("Apex: Grand Call, Chimera Form, Amputate")
	await _bonded("covenant", STEP5)
	var main = t.main
	var p = main.player
	_foes([])
	main.profile.pacts = ["slime", "knight"]
	var b = _mark("covenant", "grand_call")
	var paid := _cast(b)
	var out: Array = main.allies()
	var full: float = (30.0 + 15.0 * 5) * float(b.stat("might"))
	_check(out.size() == 2 and out.all(func(a): return is_equal_approx(a.max_hp, full) and a.has_meta("empowered")), "Grand Call: your creatures arrive empowered (%s)" % [out.map(func(a): return int(a.max_hp))])
	_check(is_equal_approx(paid, b.cost()) and b.essence > 0.0, "...and it no longer drains the whole mark (%.0f left)" % b.essence)
	main.profile.pacts = []
	# Chimera Form: grafts fire on their own.
	await _bonded("grafter", STEP5)
	main = t.main
	p = main.player
	main.grafts.clear()
	main.graft_order.clear()
	main.add_graft(_kind_for(main, "throat"))
	var foe = _foes([Vector2(70, 0)], 900.0)[0]
	b = _mark("grafter", "chimera_form")
	_cast(b)
	_check(p.chimera_t > 0.0 and p.graft("throat") == 2.0, "Chimera Form still doubles every graft's power")
	await t._wait(float(b.stat("every")) + 0.5)
	_check(foe.hp < 900.0, "...and your grafts' powers fire on their own (%.0f)" % foe.hp)
	p.chimera_t = 0.0
	# Amputate: up to three quarters health.
	await _bonded("surgeon", STEP5)
	main = t.main
	p = main.player
	foe = _foes([Vector2(70, 0)], 900.0)[0]
	b = _mark("surgeon", "amputate")
	foe.hp = foe.max_hp * 0.8
	_cast(b)
	_check(foe.cripple_t < 1000.0, "Amputate: not on a foe above three quarters health")
	foe.hp = foe.max_hp * 0.7
	b.essence = b.capacity()
	_cast(b)
	_check(foe.cripple_t > 1000.0 and foe.disarm_t > 1000.0, "...but on one at 70% it cripples and disarms for the fight")
