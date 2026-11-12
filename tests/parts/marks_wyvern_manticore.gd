extends RefCounted
## How the Wyvern's and the Manticore's marks grow (scripts/spells/wyvern.gd
## and manticore.gd, their bonds in bonds.gd): each step-3 Transformation
## does its new thing through real casts; the passives' ranks II and III
## come at steps 3 and 5 and do what they say; each Apex works; the rank and
## its line show on the cards and the tree; and an old save's step-3 choice
## maps to side A or side B. Run by smoke_test.gd (_part_tests); `t` is the
## smoke test.

const Bonds := preload("res://scripts/bonds.gd")
const Reactions := preload("res://scripts/reactions.gd")

const BOND_IDS := ["blade_forger", "flameblade", "rune_artist", "sandshaper", "venomist", "ashwalker"]
## Side B's choice id for each bond (the old other side's id, kept for old saves).
const SIDE_B := {"blade_forger": "back_to_back", "flameblade": "ring_of_embers", "rune_artist": "afterglow",
	"sandshaper": "aftershock", "venomist": "spray", "ashwalker": "billowing"}
## A number of the first spell that only side A sets, and one only side B sets.
const ONLY_A := {"blade_forger": "embed", "flameblade": "heat_cap", "rune_artist": "linked", "sandshaper": "shards", "venomist": "corrode", "ashwalker": "embers"}
const ONLY_B := {"blade_forger": "echo", "flameblade": "brand", "rune_artist": "creep", "sandshaper": "upheaval", "venomist": "bloom", "ashwalker": "follow"}
## Steps by banked essence (profile.gd STEP_XP).
const STEP2 := 150.0
const STEP3 := 450.0
const STEP5 := 1800.0

var t
var TR = load("res://scripts/tree.gd")
var L = load("res://scripts/library.gd")
var G = load("res://scripts/gear.gd")


func run(smoke) -> void:
	t = smoke
	print("how the Wyvern's and the Manticore's marks grow")
	await _old_saves()
	await _cards()
	await _blade_forger()
	await _flameblade()
	await _rune_artist()
	await _sandshaper()
	await _venomist()
	await _ashwalker()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## A climber with `bond_id` alone on the hand at the step `xp` gives, in an
## open room with no foes, standing in its middle and aiming right.
func _climber(bond_id: String, xp: float):
	await t._fresh_main()
	t.paused = false
	var main = t.main
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.grant_test_bonds()
	main.profile.bonds.clear()
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
	p.bonds["hand"].select(0)
	return main


## A frozen foe at `at` that can take a beating.
func _foe(at: Vector2, kind := "slime"):
	var e = await t._spawn(kind, at)
	e.hp = 400.0
	e.max_hp = 400.0
	return e


## Chooses side B at the bond's step 3 and gives it to the hand.
func _side_b(bond_id: String):
	var main = t.main
	var ok: bool = TR.choose(main.profile, "mark:%s:3" % bond_id, SIDE_B[bond_id])
	main._give_bonds()
	var hb = main.player.bonds["hand"]
	hb.select(0)
	_check(ok and not hb.alt_change().is_empty(), "%s: side B (%s) can be chosen at step 3" % [bond_id, TR.fork_alt(bond_id, 3).get("name", "")])
	return hb


## Casts the hand's spell with the key, as a player would.
func _cast_by_key() -> void:
	var main = t.main
	var p = main.player
	var hb = p.bonds["hand"]
	hb.essence = hb.capacity()
	p.attack_cd = 0.0
	p.cast_t = 0.0
	p._try_cast("hand")
	await t._wait(hb.windup() + 0.1)
	for i in 120:  # (a busy machine runs the fight slower than the clock: wait for the cast itself)
		if p.cast_t <= 0.0:
			break
		await t._frames(1)


## Waits until `cond` holds, or `seconds` pass.
func _until(cond: Callable, seconds: float) -> void:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not cond.call() and Time.get_ticks_msec() < end:
		await t._frames(1)


## A number of the hand's first spell at its step, or 0 (heat_cap: how far past 100).
func _first(hb, key: String) -> float:
	var v = hb.spell_stat(hb.data()["spells"][0], key)
	if v is bool:
		return 1.0 if v else 0.0
	if key == "heat_cap" and v != null:
		return float(v) - 100.0
	return float(v) if v != null else 0.0


func _blades(main) -> Array:
	return main.get_children().filter(func(c): return "style" in c and c.style == "blade" and c.friendly and not c.is_queued_for_deletion())


func _clear_blades(main) -> void:
	for c in _blades(main):
		c.queue_free()


# --- old saves and what the book shows --------------------------------------------------

func _old_saves() -> void:
	print("  old saves: the step-3 choice maps to side A or B")
	var main = await _climber("blade_forger", STEP5)
	var prof = main.profile
	var a_ok := true
	var b_ok := true
	var mig_ok := true
	for bid in BOND_IDS:
		prof.bonds.clear()
		prof.add_bond("hand", bid, false)
		prof.bonds["hand"]["xp"] = STEP5
		# A save that chose today's change (as JSON keeps it: the step as a word).
		prof.set("tree", {"v": 1, "marks": {bid: {"2": TR.default_option(bid, 2), "3": TR.CHANGE, "4": TR.default_option(bid, 4)}}})
		main._give_bonds()
		var hb = main.player.bonds["hand"]
		if _first(hb, ONLY_A[bid]) <= 0.0 or _first(hb, ONLY_B[bid]) > 0.0 or not hb.alt_change().is_empty():
			a_ok = false
		# A save that chose the other side.
		prof.set("tree", {"v": 1, "marks": {bid: {"2": TR.default_option(bid, 2), "3": SIDE_B[bid], "4": TR.default_option(bid, 4)}}})
		main._give_bonds()
		hb = main.player.bonds["hand"]
		if _first(hb, ONLY_B[bid]) <= 0.0 or _first(hb, ONLY_A[bid]) > 0.0 or hb.alt_change().is_empty():
			b_ok = false
		# A save from before the tree: migrated, it holds today's side, now side A.
		prof.set("tree", {})
		TR.migrate(prof)
		main._give_bonds()
		hb = main.player.bonds["hand"]
		if TR.mark_choice(prof, bid, 3) != TR.CHANGE or _first(hb, ONLY_A[bid]) <= 0.0:
			mig_ok = false
	_check(a_ok, "an old save that chose today's step-3 change has side A (Embedded Steel, Forge Heart, Linked Runes, Shatter, Corrosive, Ember Smoke)")
	_check(b_ok, "...one that chose the other side has side B (Weapon Echo, Brand, Creeping Runes, Upheaval, Bloom, Shroud Walk)")
	_check(mig_ok, "...and a save from before the tree is migrated to side A")
	var named := true
	for bid in BOND_IDS:
		var f: Dictionary = L.MARK_FORKS[bid]
		named = named and String(f["change"]["name"]) != "" and String(f[3]["name"]) != "" and String(f[3]["desc"]) != "" and String(Bonds.BONDS[bid]["spells"][0]["changes"][3]).begins_with(String(f["change"]["name"]))
		named = named and String(f[3]["id"]) == SIDE_B[bid] and not f[3].has("variation")
	_check(named, "each Transformation has a name and a line, in data (side B keeps its old id and is no library variation)")


func _cards() -> void:
	print("  the passive's rank and the Apex on the cards and the tree")
	var main = await _climber("venomist", STEP2)
	var ranks_ok := true
	for bid in BOND_IDS:
		ranks_ok = ranks_ok and Bonds.passive_rank(2) == 1 and Bonds.passive_rank(3) == 2 and Bonds.passive_rank(5) == 3
		ranks_ok = ranks_ok and Bonds.passive_line(bid, 2) != "" and Bonds.passive_line(bid, 3) != ""
		ranks_ok = ranks_ok and Bonds.apex_note(Bonds.BONDS[bid]["spells"][3]) != ""
	_check(ranks_ok, "a passive is rank I, II from step 3 and III at step 5; each of the six has a line for II and III, and each great spell an Apex")
	var A = load("res://scripts/abilities.gd")
	var shown := {}
	for xp in [STEP2, STEP3, STEP5]:
		main.profile.bonds["hand"]["xp"] = xp
		main._give_bonds()
		var mark: Array = A.entries(main).filter(func(e): return e.get("kind", "") == "mark")
		shown[xp] = String(mark[0]["does"]) if not mark.is_empty() else ""
	var l2 := Bonds.passive_line("venomist", 2)
	var l3 := Bonds.passive_line("venomist", 3)
	_check(not shown[STEP2].contains(l2) and shown[STEP3].contains("Toxin Build II") and shown[STEP3].contains(l2) and not shown[STEP3].contains(l3) \
		and shown[STEP5].contains("Toxin Build III") and shown[STEP5].contains(l3), "the mark's card shows its passive's rank and each new line as it grows (%s)" % shown[STEP5])
	var vir: Array = A.entries(main).filter(func(e): return String(e.get("id", "")) == "virulence")
	_check(not vir.is_empty() and String(vir[0]["does"]).contains("Apex"), "...and the great spell's card its Apex")
	var nodes: Array = TR.mark_nodes(main.profile, "hand")
	var n3: Dictionary = nodes[2]
	var n5: Dictionary = nodes[4]
	_check(n3["options"].all(func(o): return String(o["says"]).contains(l2)) and String(n5["options"][0]["says"]).contains("Apex") and String(n5["options"][0]["says"]).contains(l3),
		"the tree's step 3 shows rank II with either Transformation, and step 5 the Apex and rank III")
	_check(Bonds.step_note("venomist", 3).contains("rank II") and Bonds.step_note("venomist", 5).contains("rank III") and not Bonds.step_note("venomist", 4).contains("rank"),
		"the stair's banner says when the passive grows a rank")
	# The mark's page in the book.
	main.menu.mark_part = "hand"
	var P = Bonds.passive_at("venomist", 5)
	_check(String(P["name"]) == "Toxin Build III" and String(P["desc"]).contains(l2) and String(P["desc"]).contains(l3), "the mark's page names it Toxin Build III with both new lines")


# --- the Wyvern ----------------------------------------------------------------------------

func _blade_forger() -> void:
	print("  Blade Forger")
	# Embedded Steel (side A, today's): a blade that hits stays in and bursts again.
	var main = await _climber("blade_forger", STEP3)
	var p = main.player
	p._equip("sword")
	var hb = p.bonds["hand"]
	var e = await _foe(p.global_position + Vector2(90, 0))
	await _cast_by_key()
	await _until(func(): return e.hp < 400.0, 1.0)
	var hp1: float = e.hp
	var near = await _foe(e.global_position + Vector2(0, 24))  # (it comes after the blades: only the burst reaches it)
	await t._wait(_first(hb, "embed") + 0.35)
	_check(hp1 < 400.0 and e.hp < hp1 - 1.0 and near.hp < 400.0, "Embedded Steel: a blade stays in the foe and bursts again a moment later (%.0f, then %.0f), catching the foe beside it (%.0f)" % [400.0 - hp1, hp1 - e.hp, 400.0 - near.hp])
	_check(int(hb.stat("count")) == int(Bonds.BONDS["blade_forger"]["spells"][0]["steps"][1]["count"]), "...it throws as many blades as before step 3")
	# Weapon Echo (side B): the blades carry the weapon's finisher.
	main = await _climber("blade_forger", STEP3)
	p = main.player
	hb = _side_b("blade_forger")
	var echo: Dictionary = L.MARK_FORKS["blade_forger"][3]["echo"]
	_check(int(hb.stat("count")) == int(L.MARK_FORKS["blade_forger"][3]["steps"][3]["count"]) and _first(hb, "embed") <= 0.0, "Weapon Echo: Conjured Blades throws %d blades (no blade stays in)" % int(hb.stat("count")))
	p._equip("dagger")
	var d = await _foe(p.global_position + Vector2(90, 0))
	await _cast_by_key()
	await _until(func(): return d.venom > 0, 1.0)
	_check(d.venom >= int(echo["dagger"]["poisoned"]), "...with a dagger each blade poisons (%d stacks)" % d.venom)
	d.queue_free()
	_clear_blades(main)
	p._equip("war_hammer")
	var h = await _foe(p.global_position + Vector2(90, 0), "knight")
	h.hp = 400.0
	await _cast_by_key()
	await _until(func(): return h.hp < 400.0, 1.0)
	_check(h.stun > 0.0, "...with a war hammer each blade staggers")
	h.queue_free()
	_clear_blades(main)
	p._equip("sword")
	var s = await _foe(p.global_position + Vector2(90, 0))
	await _cast_by_key()
	await _until(func(): return s.hp < 400.0, 1.0)
	_check(Reactions.has(s, "bleeding"), "...with a sword each blade leaves it bleeding")
	# Weapon Memory II: blades carry the weapon's quality and traits; not before step 3.
	var looks := {}
	for xp in [STEP2, STEP3]:
		main = await _climber("blade_forger", xp)
		p = main.player
		p.gear["melee"] = G.make_named("stinger_dagger")
		p.weapon = G.base_id(p.gear["melee"])
		var f = await _foe(p.global_position + Vector2(90, 0))
		hb = p.bonds["hand"]
		await _cast_by_key()
		var bl: Array = _blades(main)
		var want: float = hb.damage() * float(p.Weapons.memory(p.weapon)["mult"])
		await _until(func(): return f.hp < 400.0, 1.0)
		await t._frames(2)
		looks[xp] = {"ratio": float(bl[0].dmg) / want if not bl.is_empty() else 0.0, "venom": f.venom}
	var q: float = G.weapon_power(G.make_named("stinger_dagger"))
	_check(is_equal_approx(looks[STEP2]["ratio"], 1.0) and looks[STEP2]["venom"] == 0, "Weapon Memory I: blades don't carry the weapon's quality or traits (%.2f, %d)" % [looks[STEP2]["ratio"], looks[STEP2]["venom"]])
	_check(q > 1.0 and absf(looks[STEP3]["ratio"] - q) < 0.01 and looks[STEP3]["venom"] > 0, "Weapon Memory II (step 3): a Stinger Dagger's blades hit %.2fx as its strikes do and poison (%.2f, %d)" % [q, looks[STEP3]["ratio"], looks[STEP3]["venom"]])
	# Weapon Memory III: every 5th strike that lands throws a free blade.
	var every := int(Bonds.BONDS["blade_forger"]["passive"]["every"])
	var free := {}
	for xp in [STEP3, STEP5]:
		main = await _climber("blade_forger", xp)
		p = main.player
		p._equip("sword")
		var dummy = await _foe(p.global_position + Vector2(30, 0), "knight")
		dummy.hp = 9999.0
		var n := 0
		for i in every:
			p.attack_cd = 0.0
			p.combo_t = 0.0
			p._melee()
			if i < every - 1:
				n = maxi(n, _blades(main).size())
		free[xp] = [n, _blades(main).size()]
	_check(free[STEP3] == [0, 0], "Weapon Memory II: strikes throw no blades")
	_check(free[STEP5][0] == 0 and free[STEP5][1] >= 1, "Weapon Memory III (step 5): the %dth strike that lands throws a free blade (%s)" % [every, free[STEP5]])
	# Thousand Edges' Apex: edges on the floor cut foes crossing them.
	main = await _climber("blade_forger", STEP5)
	p = main.player
	p._equip("sword")
	hb = p.bonds["hand"]
	hb.select(hb.spells().map(func(sp): return sp["id"]).find("thousand_edges"))
	var FX = load("res://scripts/spell_fx.gd")
	var before: int = FX.of(main).lastings.size()
	await _cast_by_key()
	_check(FX.of(main).lastings.size() > before, "Thousand Edges' Apex: the blades leave edges on the floor")
	_clear_blades(main)
	await t._frames(2)
	var spots: Array = []
	for n in FX.of(main).lastings:
		if is_instance_valid(n) and n.data.has("edges"):
			spots = n.data["edges"]
	var walker = await _foe(spots[0] if not spots.is_empty() else p.global_position)
	var t_end := Time.get_ticks_msec() + 3000
	var i := 0
	while (walker.hp >= 400.0 or i < 10) and Time.get_ticks_msec() < t_end:  # (it walks to and fro across the blades' path)
		walker.global_position += Vector2(0, 1.2) if i % 2 == 0 else Vector2(0, -1.2)
		i += 1
		await t._frames(1)
	_check(walker.hp < 400.0 and Reactions.has(walker, "bleeding"), "...that cut a foe crossing them, and leave it bleeding (%.0f)" % (400.0 - walker.hp))


func _flameblade() -> void:
	print("  Flameblade")
	# Forge Heart (side A): while kindled, heat never fades and climbs past 100.
	var main = await _climber("flameblade", STEP3)
	var p = main.player
	var hb = p.bonds["hand"]
	await _cast_by_key()
	_check(p.kindle_t > 6.5 and is_equal_approx(p.heat_cap(), 100.0 + _first(hb, "heat_cap")) and p.heat_cap() > 100.0, "Forge Heart: Kindle Blade burns longer (%.1f s) and heat can climb to %d" % [p.kindle_t, int(p.heat_cap())])
	p.heat = 95.0
	p._strikes_landed(3)
	var hot: float = p.heat
	p.heat_idle = 5.0
	p._tick_bond_effects(0.5)
	_check(hot > 100.0 and is_equal_approx(p.heat, hot), "...strikes heat it past full (%.0f) and, while kindled, it never fades" % hot)
	p.kindle_t = 0.0
	p._tick_bond_effects(0.5)
	_check(p.heat < hot, "...once the kindling is out, the heat falls back")
	# Brand (side B): kindled strikes brand foes; releasing your heat ignites them.
	main = await _climber("flameblade", STEP3)
	p = main.player
	hb = _side_b("flameblade")
	p._equip("sword")
	var e = await _foe(p.global_position + Vector2(30, 0))
	await _cast_by_key()
	_check(p.kindle_brand > 0.0 and is_equal_approx(p.heat_cap(), 100.0), "Brand: Kindle Blade brands (and heat stops at 100)")
	p.attack_cd = 0.0
	p.combo_t = 0.0
	p._melee()
	_check(e.has_meta("brand"), "...a kindled strike brands the foe")
	p.heat = 50.0
	var hp0: float = e.hp
	var want: float = (_first(hb, "brand_damage") + 50.0 * _first(hb, "brand_heat")) * hb.spell_power(hb.data()["spells"][0])
	await _cast_by_key()
	_check(hp0 - e.hp >= want - 0.5 and not e.has_meta("brand") and p.heat == 0.0 and p.kindle_t > 0.0, "...casting Kindle Blade again releases the heat: the branded foe ignites (%.0f of %.0f) and the blade is lit again" % [hp0 - e.hp, want])
	p.attack_cd = 0.0
	p.combo_t = 0.0
	p._melee()
	p.heat = 30.0
	hp0 = e.hp
	p.kindle_t = 0.05
	await t._wait(0.2)
	_check(e.hp < hp0 and not e.has_meta("brand") and p.heat == 0.0, "...and so does the kindling going out (%.0f)" % (hp0 - e.hp))
	# Heat II: at full heat swings throw fire (not before step 3).
	var waves := {}
	for xp in [STEP2, STEP3]:
		main = await _climber("flameblade", xp)
		p = main.player
		p._equip("sword")
		p.heat = 100.0
		var w0: int = main.waves.size()
		p.attack_cd = 0.0
		p._melee()
		waves[xp] = main.waves.size() - w0
	_check(waves[STEP2] == 0 and waves[STEP3] == 1, "Heat II (step 3): at full heat a swing throws a wave of fire (%s)" % waves)
	# Heat III: parries add heat (not before step 5).
	var heats := {}
	for xp in [STEP3, STEP5]:
		main = await _climber("flameblade", xp)
		p = main.player
		var foe = await _foe(p.global_position + Vector2(40, 0), "knight")
		p.heat = 0.0
		p._on_parry(foe, false)
		heats[xp] = p.heat
	_check(heats[STEP3] == 0.0 and is_equal_approx(heats[STEP5], float(Bonds.BONDS["flameblade"]["passive"]["parry_heat"])), "Heat III (step 5): a parry adds heat (%s)" % heats)
	# Overheat's Apex: at full heat it erupts in a ring and lights Kindle Blade again.
	main = await _climber("flameblade", STEP5)
	p = main.player
	hb = p.bonds["hand"]
	hb.select(hb.spells().map(func(sp): return sp["id"]).find("overheat"))
	var behind = await _foe(p.global_position + Vector2(-60, 0))  # (out of Overheat's cone, in the ring)
	p.heat = 100.0
	p.kindle_t = 0.0
	await _cast_by_key()
	_check(behind.hp < 400.0 and p.kindle_t > 0.0 and p.heat == 0.0, "Overheat's Apex: at full heat it erupts in a ring (%.0f behind you) and lights Kindle Blade again" % (400.0 - behind.hp))
	p.kindle_t = 0.0
	p.heat = 60.0
	var hp_b: float = behind.hp
	await _cast_by_key()
	_check(is_equal_approx(behind.hp, hp_b) and p.kindle_t <= 0.0, "...short of full heat, neither")


func _rune_artist() -> void:
	print("  Rune Artist")
	# Linked Runes (side A): one goes off, all go off, and fire runs between them.
	var main = await _climber("rune_artist", STEP3)
	var p = main.player
	var c: Vector2 = p.global_position
	p.global_position = c + Vector2(-100, 0)
	await _cast_by_key()
	p.global_position = c + Vector2(100, 0)
	await _cast_by_key()
	_check(main.runes.size() == 2 and main.runes.all(func(r): return r["linked"] and float(r.get("link", 0.0)) > 0.0), "Linked Runes: the runes are linked")
	var mid: Vector2 = (main.runes[0]["pos"] + main.runes[1]["pos"]) * 0.5
	var between = await _foe(mid)  # (out of either rune's blast)
	_check(between.global_position.distance_to(main.runes[0]["pos"]) > float(main.runes[0]["blast"]) + between.radius, "...(a foe between them, out of both blasts)")
	var walker = await _foe(main.runes[0]["pos"] + Vector2(0, 160))
	walker.global_position = main.runes[0]["pos"]
	main._update_runes(0.016)
	_check(main.runes.is_empty() and between.hp < 400.0 and Reactions.has(between, "burning"), "...one going off sets off both, and the fire between them strikes and burns the foe on the line (%.0f)" % (400.0 - between.hp))
	# Creeping Runes (side B): a rune crawls toward the nearest foe.
	main = await _climber("rune_artist", STEP3)
	p = main.player
	_side_b("rune_artist")
	await _cast_by_key()
	var r0: Vector2 = main.runes[0]["pos"]
	var prey = await _foe(r0 + Vector2(160, 0))
	await t._wait(0.6)
	_check(not main.runes.is_empty() and main.runes[0]["pos"].x > r0.x + 15.0 and not main.runes[0]["linked"], "Creeping Runes: the rune crawls toward the nearest foe (%.0f px)" % (main.runes[0]["pos"].x - r0.x if not main.runes.is_empty() else 0.0))
	await _until(func(): return main.runes.is_empty(), 3.0)
	_check(main.runes.is_empty() and prey.hp < 400.0, "...and goes off when it reaches it")
	# Runesmith II: a camp's rune comes with a second (not before step 3).
	var picks := {}
	for xp in [STEP2, STEP3]:
		main = await _climber("rune_artist", xp)
		p = main.player
		main.camp_choosing = true
		main.camp = {"stage": "rune", "choices": ["rune:sharpness", "rune:warding", "rune:swiftness"], "taken": []}
		main.choose_camp(0)
		var second: bool = main.camp_choosing and main.camp.get("second", false) and not "rune:sharpness" in main.camp["choices"]
		if second:
			main.choose_camp(0)
		picks[xp] = [p.camp_rune, p.camp_rune2, second, p.has_rune("warding")]
		main.camp_choosing = false
	_check(picks[STEP2] == ["sharpness", "", false, false], "Runesmith I: a camp gives one rune (%s)" % [picks[STEP2]])
	_check(picks[STEP3] == ["sharpness", "warding", true, true], "Runesmith II (step 3): it offers a second, different rune, and both hold (%s)" % [picks[STEP3]])
	# Runesmith III: spells cast inside your circles cost less (not before step 5).
	var paid := {}
	for xp in [STEP3, STEP5]:
		main = await _climber("rune_artist", xp)
		p = main.player
		main.wards.append({"pos": p.global_position, "r": 75.0, "t": 5.0, "color": Color.WHITE})
		var hb = p.bonds["hand"]
		hb.essence = hb.capacity()
		var e0: float = hb.essence
		await _cast_by_key()
		paid[xp] = e0 - hb.essence
		main.wards.clear()
	var thrift := float(Bonds.BONDS["rune_artist"]["passive"]["thrift"])
	var full := float(Bonds.BONDS["rune_artist"]["spells"][0]["steps"][1]["cost"])
	_check(is_equal_approx(paid[STEP3], full) and is_equal_approx(paid[STEP5], full * (1.0 - thrift)), "Runesmith III (step 5): a spell cast inside your Ward Circle costs %d%% less (%s)" % [int(thrift * 100.0), paid])
	# Grand Sigil's Apex: it moves with you for half its time.
	main = await _climber("rune_artist", STEP5)
	p = main.player
	var hb5 = p.bonds["hand"]
	hb5.select(hb5.spells().map(func(sp): return sp["id"]).find("grand_sigil"))
	await _cast_by_key()
	var sig: Dictionary = main.sigils[0]
	p.global_position += Vector2(90, 0)
	await t._frames(3)
	var moved: bool = sig["pos"].distance_to(p.global_position) < 2.0
	var still_t: float = float(hb5.stat("duration")) * (1.0 - float(hb5.stat("follow"))) - 0.2
	await _until(func(): return float(sig["t"]) < still_t, 10.0)  # (the fight's own time: a busy machine runs it slower)
	p.global_position += Vector2(-120, 0)
	await t._frames(3)
	_check(moved and sig["pos"].distance_to(p.global_position) > 100.0 and main.in_sigil(sig["pos"]), "Grand Sigil's Apex: it moves with you for half its time, then stays")


# --- the Manticore -------------------------------------------------------------------------

func _sandshaper() -> void:
	print("  Sandshaper")
	# Shatter (side A): shards cut foes walking over them.
	var main = await _climber("sandshaper", STEP3)
	var p = main.player
	await _cast_by_key()
	var mover = await _foe(p.global_position + Vector2(40, 0))  # (both come after the quake)
	var still = await _foe(p.global_position + Vector2(-40, 0))
	for i in 60:
		mover.global_position += Vector2(0, 1.0)
		await t._frames(1)
	await t._frames(20)
	_check(mover.hp < 400.0 and is_equal_approx(still.hp, 400.0) and main.stone_walls.is_empty(), "Shatter: shards cut a foe walking over them (%.0f), not one standing still (and no ring of walls)" % (400.0 - mover.hp))
	# Upheaval (side B): the quake throws foes into the air.
	main = await _climber("sandshaper", STEP3)
	p = main.player
	_side_b("sandshaper")
	var e = await _foe(p.global_position + Vector2(50, 0))
	await _cast_by_key()
	_check(e.hp < 400.0 and e.airborne > 0.0, "Upheaval: the quake throws the foe it strikes into the air (%.1f s)" % e.airborne)
	# Shifting Sands II: slowed foes can't block (not before step 3).
	var taken := {}
	for xp in [STEP2, STEP3]:
		main = await _climber("sandshaper", xp)
		p = main.player
		var sh = await _foe(p.global_position + Vector2(200, 0), "shellback")
		sh.face = Vector2.LEFT
		sh.chill_t = 3.0
		var h0: float = sh.hp
		sh.take_hit(20.0, Vector2.RIGHT, 0.0)
		taken[xp] = h0 - sh.hp
	_check(taken[STEP2] < 10.0 and is_equal_approx(taken[STEP3], 20.0), "Shifting Sands II (step 3): a slowed shellback's shell doesn't turn your blow (%s)" % taken)
	# Shifting Sands III: standing still hardens your skin (not before step 5).
	var hurt := {}
	for xp in [STEP3, STEP5]:
		main = await _climber("sandshaper", xp)
		p = main.player
		p.iframes = 0.0
		p.velocity = Vector2.ZERO
		p.still_for = 2.0
		p.hp = p.max_health()
		p.hurt_t = 0.0
		p.parry_t = 0.0
		p.receive_attack(20.0, null)
		hurt[xp] = p.max_health() - p.hp
	var harden := float(Bonds.BONDS["sandshaper"]["passive"]["harden"])
	_check(hurt[STEP3] > 0.0 and absf(hurt[STEP5] - hurt[STEP3] * (1.0 - harden)) < 0.01, "Shifting Sands III (step 5): standing still you take %d%% less (%s)" % [int(harden * 100.0), hurt])
	# Fault Line's Apex: foes on the line are buried and crushed.
	main = await _climber("sandshaper", STEP5)
	p = main.player
	var hb = p.bonds["hand"]
	hb.select(hb.spells().map(func(sp): return sp["id"]).find("fault_line"))
	var on = await _foe(p.global_position + Vector2(90, 30))
	var off = await _foe(p.global_position + Vector2(200, 30))
	await _cast_by_key()
	_check(on.hp < 400.0 and on.stun > 1.0 and is_equal_approx(off.hp, 400.0), "Fault Line's Apex: a foe on the line is buried (stunned %.1f s) and crushed (%.0f)" % [on.stun, 400.0 - on.hp])


func _venomist() -> void:
	print("  Venomist")
	# Corrosive (side A): poison strips shells, and poisoned foes take more.
	var main = await _climber("venomist", STEP3)
	var p = main.player
	var sh = await _foe(p.global_position + Vector2(120, 0), "shellback")
	sh.face = Vector2.LEFT
	var h0: float = sh.hp
	sh.take_hit(20.0, Vector2.RIGHT, 0.0)
	var blocked: float = h0 - sh.hp
	await _cast_by_key()
	await _until(func(): return sh.venom > 0, 1.0)
	h0 = sh.hp
	sh.take_hit(20.0, Vector2.RIGHT, 0.0)
	var k := _first(p.bonds["hand"], "corrode")
	_check(blocked < 10.0 and sh.venom > 0 and absf((h0 - sh.hp) - 20.0 * (1.0 + k)) < 0.01, "Corrosive: once Venom Spit poisons it, a shellback's shell no longer turns blows and it takes %d%% more (%.0f, then %.0f)" % [int(k * 100.0), blocked, h0 - sh.hp])
	# Bloom (side B): the spit bursts into a cloud where it lands.
	main = await _climber("venomist", STEP3)
	p = main.player
	_side_b("venomist")
	var e = await _foe(p.global_position + Vector2(120, 0))
	await _cast_by_key()
	await _until(func(): return not main.clouds.is_empty(), 1.0)
	_check(main.clouds.size() == 1 and main.clouds[0]["pos"].distance_to(e.global_position) < 30.0 and e.venom > 0, "Bloom: Venom Spit bursts into a poison cloud where it lands")
	# Toxin Build II: a poisoned foe that dies passes its poison on (not before step 3).
	var passed := {}
	for xp in [STEP2, STEP3]:
		main = await _climber("venomist", xp)
		p = main.player
		var dying = await _foe(p.global_position + Vector2(100, 0))
		var by = await _foe(p.global_position + Vector2(140, 0))
		dying.venom = 6
		dying.venom_t = 6.0
		dying.take_hit(9999.0, Vector2.ZERO, 0.0)
		passed[xp] = by.venom
	_check(passed[STEP2] == 0 and passed[STEP3] == int(ceil(6.0 * float(Bonds.BONDS["venomist"]["passive"]["pass"]))), "Toxin Build II (step 3): a poisoned foe that dies passes half its stacks to the foe beside it (%s)" % passed)
	# Toxin Build III: a foe at 8 stacks is staggered (not before step 5).
	var stun := {}
	for xp in [STEP3, STEP5]:
		main = await _climber("venomist", xp)
		p = main.player
		var f = await _foe(p.global_position + Vector2(100, 0))
		f.add_venom(4)
		var early: float = f.stun
		f.add_venom(4)
		stun[xp] = [early, f.stun]
	_check(stun[STEP3][1] <= 0.0 and stun[STEP5][0] <= 0.0 and stun[STEP5][1] > 0.0, "Toxin Build III (step 5): a foe reaching 8 stacks is staggered (%s)" % stun)
	# Virulence's Apex: each foe it bursts refills the mark.
	main = await _climber("venomist", STEP5)
	p = main.player
	var hb = p.bonds["hand"]
	hb.select(hb.spells().map(func(sp): return sp["id"]).find("virulence"))
	var foes: Array = []
	for i in 3:
		var v = await _foe(p.global_position + Vector2(60 + 30 * i, -40 + 40 * i))
		v.venom = 4
		v.venom_t = 6.0
		foes.append(v)
	hb.essence = hb.capacity() * 0.5
	var e0: float = hb.essence
	var spit_cost: float = hb.spell_cost(hb.data()["spells"][0])
	p.attack_cd = 0.0
	p.cast_t = 0.0
	p._try_cast("hand")
	await t._wait(hb.windup() + 0.1)
	await _until(func(): return p.cast_t <= 0.0, 2.0)
	var want: float = e0 - hb.cost() + 3.0 * spit_cost * float(hb.stat("refill"))
	_check(absf(hb.essence - want) < 0.01 and foes.all(func(x): return not is_instance_valid(x) or x.venom == 0), "Virulence's Apex: each of the 3 foes it bursts gives back a Venom Spit's essence (%.0f, from %.0f)" % [hb.essence, e0])


func _ashwalker() -> void:
	print("  Ashwalker")
	# Ember Smoke (side A): the smoke burns the foes inside it.
	var main = await _climber("ashwalker", STEP3)
	var p = main.player
	var hb = p.bonds["hand"]
	var e = await _foe(p.global_position + Vector2(40, 0))
	await _cast_by_key()
	await t._wait(0.7)
	_check(Reactions.has(e, "burning") and is_equal_approx(e.burn_dmg, hb.damage()) and e.is_lost(40.0), "Ember Smoke: the smoke burns the foe inside it (%.1f every half second) as it hides you" % e.burn_dmg)
	# Shroud Walk (side B): the veil moves with you for a while.
	main = await _climber("ashwalker", STEP3)
	p = main.player
	hb = _side_b("ashwalker")
	await _cast_by_key()
	var sm: Dictionary = main.smokes[0]
	p.global_position += Vector2(120, 0)
	await t._frames(3)
	var followed: bool = sm["pos"].distance_to(p.global_position) < 2.0
	var left_t: float = float(hb.stat("duration")) - float(hb.stat("follow")) - 0.2
	await _until(func(): return float(sm["t"]) < left_t, 10.0)  # (the fight's own time)
	p.global_position += Vector2(-120, 0)
	await t._frames(3)
	_check(followed and sm["pos"].distance_to(p.global_position) > 100.0 and not main.smokes.is_empty(), "Shroud Walk: the smoke moves with you for %d seconds, then stays" % int(hb.stat("follow")))
	# Unseen Strike II: unseen strikes stagger (not before step 3).
	var st := {}
	for xp in [STEP2, STEP3]:
		main = await _climber("ashwalker", xp)
		p = main.player
		var a = await _foe(p.global_position + Vector2(30, 0), "knight")
		a.hp = 9999.0
		a.notice_t = 1.0
		p._strike(a, 5.0, Vector2.RIGHT, 0.0, false)
		st[xp] = [a.flinch, a.stun]
	_check(st[STEP2][0] <= 0.0 and st[STEP3][0] > 0.0 and st[STEP3][1] <= 0.0, "Unseen Strike II (step 3): an unseen strike knocks the foe off balance (not open to a riposte) (%s)" % st)
	# Unseen Strike III: a kill while unseen hides you again (not before step 5).
	var hid := {}
	for xp in [STEP3, STEP5]:
		main = await _climber("ashwalker", xp)
		p = main.player
		var a = await _foe(p.global_position + Vector2(30, 0))
		a.hp = 5.0
		a.notice_t = 1.0
		p._strike(a, 5.0, Vector2.RIGHT, 0.0, false)
		hid[xp] = p.vanish_t
	_check(hid[STEP3] <= 0.0 and hid[STEP5] > 0.0, "Unseen Strike III (step 5): a kill while unseen hides you again for a moment (%s)" % hid)
	# Ashfall's Apex: an unseen strike while it falls leaps to a second foe.
	main = await _climber("ashwalker", STEP5)
	p = main.player
	hb = p.bonds["hand"]
	hb.select(hb.spells().map(func(sp): return sp["id"]).find("ashfall"))
	var first = await _foe(p.global_position + Vector2(30, 0), "knight")
	var second = await _foe(p.global_position + Vector2(110, 0), "knight")
	first.hp = 9999.0
	second.hp = 400.0
	first.notice_t = 1.0
	p._strike(first, 5.0, Vector2.RIGHT, 0.0, false)
	_check(is_equal_approx(second.hp, 400.0), "...(before Ashfall, an unseen strike stays on its foe)")
	await _cast_by_key()
	first.notice_t = 1.0
	p._strike(first, 5.0, Vector2.RIGHT, 0.0, false)
	_check(second.hp < 400.0, "Ashfall's Apex: while it falls, an unseen strike leaps to a second foe (%.0f)" % (400.0 - second.hp))
	main.ashfall_t = 0.0
