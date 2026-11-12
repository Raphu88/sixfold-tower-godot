extends RefCounted
## Weapons, ordinary and enchanted pieces, and the staples: the canes, the
## flintlock and the revolver (firing, reloading, a roll breaking a reload
## off, how they're drawn), enchanted pistols' essence shot, the new
## relics, Common pieces being ordinary but useful, Fine and Rare pieces
## enchanted (and saying so), relics' blank histories, and the cheap
## Healing and Stamina Draughts. Run by smoke_test.gd (_part_tests); `t` is
## the smoke test.

const G := preload("res://scripts/gear.gd")
const W := preload("res://scripts/weapons.gd")
const I := preload("res://scripts/items.gd")
const Train := preload("res://scripts/train.gd")
const Bench := preload("res://scripts/bench.gd")
const D := preload("res://scripts/draw_util.gd")
const GL := preload("res://scripts/gear_look.gd")
const Reg := preload("res://scripts/data_registry.gd")
const TestRun := preload("res://scripts/test_run.gd")  # (every user:// path a test touches: its own run folder)

const NEW_WEAPONS := ["cane", "sword_cane", "flintlock", "revolver"]
const NEW_RELICS := ["ashgrove_cane", "quietsteel", "lastbell_revolver", "emberlock"]

var t


func run(smoke) -> void:
	t = smoke
	await _canes()
	await _flintlock()
	await _revolver()
	await _essence_shot()
	await _relics()
	_ordinary_and_enchanted()
	_history()
	_staples()
	await _stamina_draught()
	await _drawing()
	_saves()


func _main():
	return t.main


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## A fresh climb with marks (the hand's, to see what fills it), no monsters,
## and the climber standing in the open.
func _fresh():
	await t._fresh_main()
	var m = _main()
	m.grant_test_bonds()
	for x in m.enemies():
		x.queue_free()
	await t._frames(2)
	var p = m.player
	p.global_position = Vector2(500, 400)
	p.aim = Vector2.RIGHT
	p.mouse_aim = false
	return p


## Your shots in flight (the projectiles that are yours).
func _shots() -> Array:
	return _main().get_children().filter(func(c): return c.get_script() != null and c.get_script().resource_path.ends_with("projectile.gd") and c.friendly)


func _clear_shots() -> void:
	for s in _shots():
		s.queue_free()


## A training dummy, with no shot of yours still in flight to strike it in
## the frame it appears (before it's a dummy).
func _dummy(pos: Vector2):
	_clear_shots()
	await t._frames(1)
	return await t._dummy(pos)


# --- canes ----------------------------------------------------------------------

func _canes() -> void:
	print("weapons: canes")
	var p = await _fresh()
	var m = _main()
	_check(NEW_WEAPONS.all(func(id): return id in W.ORDER and W.WEAPONS.has(id) and G.is_gear(id)), "the walking cane, sword-cane, flintlock and revolver are weapons you can find and carry")
	_check(W.WEAPONS["cane"]["kind"] == "melee" and W.WEAPONS["sword_cane"]["kind"] == "melee" and G.slot_of("cane") == "melee", "the canes are melee weapons")
	# The cane is quick and light.
	_check(float(W.WEAPONS["cane"]["combo"][0]["recover"]) < float(W.WEAPONS["sword"]["combo"][0]["recover"])
		and float(W.WEAPONS["cane"]["combo"][0]["sta"]) < float(W.WEAPONS["sword"]["combo"][0]["sta"]), "the walking cane is quicker and cheaper than a sword")
	# The parry bonus while it's in hand.
	p.take_gear("cane")
	p._equip("sword")
	p.parry_cd = 0.0
	p.attack_cd = 0.0
	p._try_parry()
	var w_sword: float = p.parry_window
	p.parry_t = 0.0
	p._equip("cane")
	p.parry_cd = 0.0
	p.attack_cd = 0.0
	p._try_parry()
	var w_cane: float = p.parry_window
	p.parry_t = 0.0
	_check(absf(w_cane / w_sword - 1.2) < 0.01, "with a cane in hand the parry window is 20%% longer (%.3f vs %.3f)" % [w_cane, w_sword])
	# Its finisher staggers.
	var d = await _dummy(p.global_position + Vector2(30, 0))
	p.sta = p.max_sta
	t._swing()
	t._swing(true)
	_check(d.stun <= 0.0, "...its first blows don't stagger")
	t._swing(true)
	_check(d.stun > 0.0 and d.hp < 999.0, "...but the hooked finisher does (%.2f s)" % d.stun)
	d.queue_free()
	# The sword-cane: two cane blows, then the blade comes out for the finisher.
	p.take_gear("sword_cane")
	p._equip("sword_cane")
	var chain: Array = W.WEAPONS["sword_cane"]["combo"]
	_check(not chain[0].get("blade", false) and not chain[1].get("blade", false) and chain[2].get("blade", false)
		and float(chain[2]["dmg"]) > 2.5 * float(chain[0]["dmg"]) and float(chain[2]["range"]) > float(chain[0]["range"]),
		"the sword-cane's finisher draws the blade: a longer, much harder blow")
	var d2 = await _dummy(p.global_position + Vector2(30, 0))
	p.sta = p.max_sta
	t._swing()
	var first: float = 999.0 - d2.hp
	d2.stun = 0.0
	t._swing(true)
	d2.stun = 0.0
	var before: float = d2.hp
	t._swing(true)
	var drawn: float = before - d2.hp
	_check(drawn > first * 2.5 and p.swing.get("blade", false), "...and it lands (%.1f against %.1f)" % [drawn, first])
	await t._frames(2)  # (drawn with the blade out, the empty cane in the other hand)
	d2.queue_free()
	m.hitstop_until = 0
	Engine.time_scale = 1.0


# --- pistols ----------------------------------------------------------------------

func _flintlock() -> void:
	print("weapons: the flintlock pistol")
	var p = await _fresh()
	var m = _main()
	p.take_gear("flintlock")
	p._equip("flintlock")
	_check(p.wkind() == "gun" and G.slot_of("flintlock") == "ranged" and p.gun_shots() == 1 and p.ammo_left() == 1, "a flintlock goes in the ranged slot, loaded with one shot")
	_clear_shots()
	await t._frames(1)
	p.attack_cd = 0.0
	p.knock = Vector2.ZERO
	_check(p._try_attack(), "it fires")
	var shots := _shots()
	p._tick_gun(0.016)
	_check(shots.size() == 1 and shots[0].style == "shot" and shots[0].weapon and shots[0].fills and shots[0].heavy, "...one heavy shot of lead (it rocks what it hits, and fills your hand's mark as arrows do)")
	_check(shots.size() == 1 and absf(shots[0].force - float(W.WEAPONS["flintlock"]["knock"])) < 0.1 and shots[0].force > float(W.WEAPONS["crossbow"]["knock"]),
		"...that throws a foe back harder than a crossbow bolt")
	_check(p.knock.dot(Vector2.RIGHT) < -50.0, "...and kicks you back")
	_check(p.ammo_left() == 0, "...leaving it empty")
	_check(p.reload_t > 1.5, "an empty flintlock starts its long reload (%.2f s)" % p.reload_t)
	p.attack_cd = 0.0
	_check(not p._try_attack(), "...and can't fire until it's done")
	# A roll breaks the reload off; it starts again after the roll.
	p.sta = p.max_sta
	p.roll_cd = 0.0
	p.attack_cd = 0.0
	p._try_roll(Vector2.DOWN)
	_check(p.reload_t <= 0.0 and p.ammo_left() == 0, "a roll breaks the reload off")
	p._tick_gun(0.016)
	_check(p.reload_t <= 0.0, "...it doesn't start again mid-roll")
	p.roll_t = 0.0
	p.iframes = 0.0
	p._tick_gun(0.016)
	_check(p.reload_t > float(W.WEAPONS["flintlock"]["reload"]) * 0.9, "...but from the start once the roll is over (%.2f s)" % p.reload_t)
	# Done reloading: loaded again.
	p.reload_t = 0.03
	await t._until(func(): return p.reload_t <= 0.0, 2.0)
	_check(p.reload_t <= 0.0 and p.ammo_left() == 1, "the reload done, it's loaded again")
	# A lead shot that hits fills the hand's mark.
	var hand = p.bonds.get("hand")
	var tgt = await _dummy(p.global_position + Vector2(80, 0))
	hand.essence = 0.0
	p.ranged_hit(tgt, 10.0, Vector2.RIGHT, 0.0, true, true, "", true)
	_check(hand.essence > 0.0, "a lead shot that lands fills the hand's mark")
	tgt.queue_free()
	_clear_shots()
	m.hitstop_until = 0
	Engine.time_scale = 1.0


func _revolver() -> void:
	print("weapons: the revolver")
	var p = await _fresh()
	var m = _main()
	p.take_gear("revolver")
	p._equip("revolver")
	_check(p.gun_shots() == 6 and p.ammo_left() == 6, "a revolver holds six shots")
	_check(float(W.WEAPONS["revolver"]["recover"]) < float(W.WEAPONS["flintlock"]["recover"]) and float(W.WEAPONS["revolver"]["dmg"]) < float(W.WEAPONS["flintlock"]["dmg"]),
		"...quicker and lighter than the flintlock's one heavy shot")
	_clear_shots()
	await t._frames(1)
	var fired := 0
	for i in 6:
		p.attack_cd = 0.0
		p.sta = p.max_sta
		if p._try_attack():
			fired += 1
	_check(fired == 6 and p.ammo_left() == 0, "six shots, one after another (%d)" % fired)
	p.attack_cd = 0.0
	_check(not p._try_attack(), "...then a seventh won't fire")
	p._tick_gun(0.016)
	_check(p.reload_t > 1.5, "...and it reloads all six (%.2f s)" % p.reload_t)
	var walk0: float = p.WALK
	_check(float(W.WEAPONS["revolver"]["reload_move"]) < 1.0 and walk0 > 0.0, "you can walk while it reloads, a little slower")
	# Putting it away breaks the reload off too; drawing it again starts afresh.
	p._equip("fists")
	_check(p.reload_t <= 0.0, "putting it away breaks off the reload")
	p._equip("revolver")
	p._tick_gun(0.016)
	_check(p.reload_t > 1.5 and p.ammo_left() == 0, "...and drawing it again starts the reload afresh")
	p.reload_t = 0.03
	await t._until(func(): return p.reload_t <= 0.0, 2.0)
	_check(p.ammo_left() == 6, "reloaded: six again")
	# A roll mid-reload.
	for i in 6:
		p.attack_cd = 0.0
		p._try_attack()
	p._tick_gun(0.016)
	p.sta = p.max_sta
	p.roll_cd = 0.0
	p.attack_cd = 0.0
	p._try_roll(Vector2.UP)
	_check(p.reload_t <= 0.0 and p.ammo_left() == 0, "a roll breaks off the revolver's reload as well")
	p.roll_t = 0.0
	p.iframes = 0.0
	# The HUD's slot and the phone's button show the shots left.
	_check(m.hud._core_signature().has(p.ammo_left()), "the HUD redraws when the shots left change")
	_clear_shots()
	m.hitstop_until = 0
	Engine.time_scale = 1.0


# --- enchanted pistols: essence shot ---------------------------------------------------

func _essence_shot() -> void:
	print("weapons: enchanted pistols fire essence shot")
	var p = await _fresh()
	var m = _main()
	_check(G.shot_kind(G.make("revolver")) == "" and G.shot_kind(G.make("flintlock")) == "", "ordinary pistols fire lead")
	var cases := {"embers": "fire", "second_wind": "iron", "mending": "stone", "well": "water", "riposte": "blade", "hunt": "air"}
	var kinds_ok := true
	for tr in cases:
		var g := G.make("revolver", "fine", [tr])
		kinds_ok = kinds_ok and G.shot_kind(g) == cases[tr] and G.enchanted(g)
	_check(kinds_ok, "a Fine pistol is enchanted: its shot follows its trait's essence (fire, iron, stone, water, blade, air)")
	_check(cases.values().all(func(k): return W.ESSENCE_SHOT.has(k)), "...and every one of those essences has its own shot")
	# Fire: an essence shot that doesn't fill the hand, and never reloads.
	p.take_gear(G.make("revolver", "fine", ["embers"]))
	p._equip("revolver")
	_clear_shots()
	await t._frames(1)
	p.attack_cd = 0.0
	p._try_attack()
	var s := _shots()
	_check(s.size() == 1 and s[0].style == "essence" and s[0].shot == "fire" and s[0].weapon and not s[0].fills, "a fire-enchanted revolver fires fire shot, which doesn't fill your hand's mark")
	var hand = p.bonds.get("hand")
	var a = await _dummy(p.global_position + Vector2(120, 0))
	var b = await _dummy(p.global_position + Vector2(150, 20))
	hand.essence = 0.0
	p.ranged_hit(a, 10.0, Vector2.RIGHT, 0.0, false, true, "fire", false)
	_check(hand.essence <= 0.0, "...an essence shot that lands leaves the hand's mark as it was")
	_check(b.hp < 999.0, "...and fire shot bursts over the foes around (%.1f)" % (999.0 - b.hp))
	for i in 6:
		p.attack_cd = 0.0
		p._try_attack()
	p._tick_gun(0.016)
	_check(p.ammo_left() == 0 and p.reload_t <= 0.0, "emptied, it doesn't stop to reload")
	p.attack_cd = 0.0
	p._tick_gun(p.gun_refill_time() + 0.01)
	_check(p.ammo_left() == 1, "...its chambers fill themselves, one at a time")
	p.sta = p.max_sta
	p.roll_cd = 0.0
	p._try_roll(Vector2.DOWN)
	p._tick_gun(p.gun_refill_time() + 0.01)
	_check(p.ammo_left() == 2, "...even through a roll")
	p.roll_t = 0.0
	p.iframes = 0.0
	# Stone staggers, water chills.
	a.stun = 0.0
	p.ranged_hit(a, 5.0, Vector2.RIGHT, 0.0, false, true, "stone", false)
	_check(a.stun > 0.0, "stone shot staggers what it hits")
	a.chill_t = 0.0
	p.ranged_hit(a, 5.0, Vector2.RIGHT, 0.0, false, true, "water", false)
	_check(a.chill_t > 1.5, "water shot chills it")
	a.queue_free()
	b.queue_free()
	# Iron pierces, blade splits, air flies faster.
	var looks := {}
	for tr in ["second_wind", "riposte", "hunt"]:
		p.take_gear(G.make("revolver", "rare", [tr, "venom"]))
		p._equip("fists")
		p._equip("revolver")
		_clear_shots()
		await t._frames(1)
		p.attack_cd = 0.0
		p._try_attack()
		looks[tr] = _shots().map(func(x): return {"pierce": x.pierce, "speed": x.vel.length()})
	_check(looks["second_wind"].size() == 1 and looks["second_wind"][0]["pierce"], "iron shot pierces through foes")
	_check(looks["riposte"].size() == 3, "blade shot splits into three shards (%d)" % looks["riposte"].size())
	_check(looks["hunt"].size() == 1 and looks["hunt"][0]["speed"] > float(W.WEAPONS["revolver"]["speed"]) * 1.5, "air shot flies faster")
	# An enchanted flintlock: no long reload either.
	p.take_gear(G.make("flintlock", "fine", ["mending"]))
	p._equip("flintlock")
	p.attack_cd = 0.0
	p._try_attack()
	p._tick_gun(0.016)
	_check(p.reload_t <= 0.0 and p.gun_refill_time() < float(W.WEAPONS["flintlock"]["reload"]), "an enchanted flintlock's chamber fills itself sooner than a reload")
	# Its card says what it fires.
	var lines: Array = G.trait_lines(G.make("revolver", "fine", ["embers"]))
	_check(lines.size() >= 3 and String(lines[0][0]).begins_with("Enchanted") and String(lines[1][0]).begins_with(W.ESSENCE_SHOT["fire"]["name"]),
		"its card: Enchanted, then what its fire shot does %s" % [lines.map(func(l): return l[0])])
	_clear_shots()
	m.hitstop_until = 0
	Engine.time_scale = 1.0


# --- relics -----------------------------------------------------------------------

func _relics() -> void:
	print("weapons: the new relics")
	var p = await _fresh()
	var m = _main()
	print("  R3")
	_check(NEW_RELICS.all(func(n): return n in G.NAMED_ORDER and G.NAMED[n]["rarity"] == "storied" and G.NAMED.has(n)), "four new Storied relics: a cane, a sword-cane and two pistols")
	print("  R4")
	# Lastbell: not enchanted, it reloads; its last shot hits twice as hard.
	var lb := G.make_named("lastbell_revolver")
	print("  R6")
	_check(not G.enchanted(lb) and G.shot_kind(lb) == "" and lb["traits"].is_empty() and String(G.trait_lines(lb)[0][0]) == G.TEXT["relic_plain"], "the Lastbell Revolver is a relic that isn't enchanted: no traits, lead and a reload")
	print("  R7")
	p.take_gear(lb)
	print("  R8")
	p._equip("revolver")
	print("  R9")
	_clear_shots()
	print("  R10")
	await t._frames(1)
	print("  R11")
	var dmg: Array = []
	print("  R12")
	for i in 6:
		p.attack_cd = 0.0
		p._try_attack()
		var s := _shots()
		dmg.append(s[s.size() - 1].dmg)
	_check(absf(dmg[5] / dmg[0] - 2.0) < 0.01, "...its last shot hits twice as hard (%.1f against %.1f)" % [dmg[5], dmg[0]])
	print("  R18")
	p._tick_gun(0.016)
	print("  R19")
	_check(p.reload_t > 1.0, "...then it reloads like any revolver")
	print("  R20")
	# Emberlock: fire shot, and a kill fills its chamber.
	var el := G.make_named("emberlock")
	print("  R22")
	_check(G.shot_kind(el) == "fire", "the Emberlock fires fire shot")
	print("  R23")
	p.take_gear(el)
	print("  R24")
	p._equip("flintlock")
	print("  R25")
	p.attack_cd = 0.0
	print("  R26")
	p._try_attack()
	print("  R27")
	_check(p.ammo_left() == 0, "...emptied by one shot")
	print("  R28")
	_clear_shots()
	await t._frames(1)
	var victim = await t._spawn("slime", p.global_position + Vector2(80, 0))
	print("  R29")
	victim.hp = 1.0
	print("  R30")
	p.ranged_hit(victim, 50.0, Vector2.RIGHT, 0.0, true, true, "fire", false)
	print("  R31")
	_check(p.ammo_left() == 1, "...a kill fills its chamber at once")
	print("  R32")
	# Ashgrove Cane: a perfect parry staggers the foes near you.
	p.take_gear(G.make_named("ashgrove_cane"))
	print("  R34")
	p._equip("cane")
	print("  R35")
	var n1 = await _dummy(p.global_position + Vector2(60, 0))
	print("  R36")
	var n2 = await _dummy(p.global_position + Vector2(-50, 40))
	print("  R37")
	n1.stun = 0.0
	print("  R38")
	n2.stun = 0.0
	print("  R39")
	p._on_parry(n1, true)
	print("  R40")
	_check(n1.stun > 0.0 and n2.stun > 0.0, "the Ashgrove Cane: a perfect parry staggers every foe near you")
	print("  R41")
	n1.queue_free()
	print("  R42")
	n2.queue_free()
	print("  R43")
	# Quietsteel: the drawn finisher poisons.
	p.take_gear(G.make("sword_cane", "storied", ["riposte"], 0, "quietsteel"))  # (a trait that never poisons)
	print("  R45")
	p._equip("sword_cane")
	print("  R46")
	var q = await _dummy(p.global_position + Vector2(30, 0))
	p.gear_fx.erase("venom_chance")  # (worn pieces left by earlier tests may poison now and then)
	p.buffs.clear()
	q.venom = 0
	print("  R47")
	p.sta = p.max_sta
	print("  R48")
	t._swing()
	print("  R49")
	t._swing(true)
	print("  R50")
	_check(q.venom == 0, "Quietsteel: its cane blows don't poison")
	print("  R51")
	q.stun = 0.0
	print("  R52")
	t._swing(true)
	print("  R53")
	_check(q.venom > 0, "...its drawn finisher does (%d)" % q.venom)
	print("  R54")
	q.queue_free()
	print("  R55")
	_clear_shots()
	print("  R56")
	m.hitstop_until = 0
	print("  R57")
	Engine.time_scale = 1.0
	print("  R58")


# --- ordinary and enchanted ------------------------------------------------------------

func _ordinary_and_enchanted() -> void:
	print("gear: Common pieces are ordinary, Fine and Rare enchanted")
	# Every Common piece: no traits, not enchanted, and something of its own.
	var bases: Array = []
	for id in W.ORDER:
		if id != "fists":
			bases.append(id)
	for id in G.ARMOR_ORDER:
		if id != "":
			bases.append(id)
	for id in G.PIECE_ORDER:
		if G.natural_rarity(id) == "common":
			bases.append(id)
	var plain_ok := true
	var blank: Array = []
	var seen := {}
	var twins: Array = []
	for id in bases:
		var g := G.make(id)
		if not g["traits"].is_empty() or G.enchanted(g) or g["rarity"] != "common" or not G.describe(g)[1].contains(G.TEXT["ordinary"]) or not G.trait_lines(g).is_empty():
			plain_ok = false
		var what := ""
		if W.WEAPONS.has(id):
			what = String(W.WEAPONS[id]["desc"])
		elif G.ARMOR.has(id):
			what = "%s" % G.ARMOR[id]["reduce"]
			if float(G.ARMOR[id]["reduce"]) <= 0.0:
				blank.append(id)
		else:
			var fx := G.effects(g)
			if fx.is_empty():
				blank.append(id)
			var keys: Array = fx.keys()
			keys.sort()
			what = str(keys.map(func(k): return [k, fx[k]]))
		if seen.has(what):
			twins.append([seen[what], id])
		seen[what] = id
	_check(plain_ok, "every Common piece is ordinary: no traits, not enchanted, and its card says so")
	_check(blank.is_empty(), "...but every one has its own use %s" % [blank])
	_check(twins.is_empty(), "...and no two do the same thing %s" % [twins])
	# The small behaviours that make the plain pieces worth a look.
	_check(G.effects(G.make("leather_gloves")).has("finisher") and G.effects(G.make("studded_gloves")).has("fist") and G.effects(G.make("garnet_ring")).has("kill_sta")
		and G.effects(G.make("iron_band")).has("quick_breath") and G.effects(G.make("silver_ring")).has("parry_heal"),
		"gloves and rings have small behaviours of their own (finishers, fists, a kill's breath, a quicker breath, a parry that heals)")
	# Fine and Rare finds are enchanted: traits, and a card that says so in its essence.
	var ench_ok := true
	var bad: Array = []
	for i in 400:
		var g := G.roll_gear("", [], true, 1 + i % 12, "", 2, "fine")
		var r := String(g["rarity"])
		if not (r in ["fine", "rare"]) or G.NAMED.has(G.named_id(g)) or G.traits_for(G.trait_slot(g)).is_empty():
			continue
		if G.natural_rarity(g) == r and G.trait_count(g, r) == 0:
			continue  # (a ring Fine by nature: enchanted by nature, below)
		var lines: Array = G.trait_lines(g)
		var kind := G.enchant_kind(g)
		var ok: bool = not g["traits"].is_empty() and G.enchanted(g) and kind == String(G.TRAITS[g["traits"][0]]["kind"]) \
			and not lines.is_empty() and String(lines[0][0]) == G.TEXT["enchanted"] % G.Essence.display(kind)
		if not ok:
			ench_ok = false
			bad.append(G.code(g))
	_check(ench_ok, "every Fine and Rare find is enchanted: traits, and its card says \"Enchanted\" with its essence %s" % [bad.slice(0, 4)])
	var ring := G.make("garnet_ring")
	_check(G.enchanted(ring) and String(G.trait_lines(ring)[0][0]).begins_with("Enchanted"), "rings and amulets are enchanted by nature (Fine), and say so")
	var pack := G.make("climbers_pack")
	_check(not G.enchanted(pack) and G.describe(pack)[1].contains(G.TEXT["ordinary"]), "a Climber's Pack is a fine piece of work, but ordinary")
	var relic := G.make_named("watchers_helm")
	_check(String(G.trait_lines(relic)[0][0]) == G.TEXT["relic"] % G.Essence.display("iron"), "Storied and Regarded pieces are relics, enchanted in their own essence")
	# Gear with a dull flat bonus got a noticeable one.
	_check(G.trait_value("edges", "fine") >= 0.05 and G.trait_value("wind", "fine") >= 0.04 and G.trait_value("mending", "fine") >= 2.0, "the faint traits are stronger now (Edges %s, Wind %s)" % [G.trait_value("edges", "fine"), G.trait_value("wind", "fine")])
	_check(["embers", "well", "second_wind", "riposte"].all(func(x): return "ranged" in G.TRAITS[x]["slots"]), "bows and pistols can carry fire, water, iron and blade traits too")


func _history() -> void:
	print("gear: relics' histories (blank, for the owner)")
	var all_blank := true
	var shown := false
	for n in G.NAMED_ORDER:
		all_blank = all_blank and G.NAMED[n].has("history") and String(G.NAMED[n]["history"]) == ""
		var g := G.make_named(n)
		shown = shown or G.history(g) != "" or G.describe(g).any(func(l): return String(l).strip_edges() == "")
	_check(all_blank, "every relic (tower, Storied and Regarded) has a history, blank for now")
	_check(not shown, "...and a blank history shows nothing on its card")
	var keep := String(G.NAMED["ashgrove_cane"]["history"])
	G.NAMED["ashgrove_cane"]["history"] = "Written by the owner."
	var lines: Array = G.describe(G.make_named("ashgrove_cane"))
	G.NAMED["ashgrove_cane"]["history"] = keep
	_check(lines.has("Written by the owner."), "once written, the card shows it")
	_check(not Reg.field("gear/NAMED/ashgrove_cane/history").is_empty() and not Reg.field("gear/NAMED/stormtalon/history").is_empty(),
		"the Data editor offers every relic's history to write")
	_check(not Reg.field("weapons/WEAPONS/revolver/name").is_empty() and not Reg.field("weapons/WEAPONS/revolver/reload").is_empty()
		and not Reg.field("weapons/ESSENCE_SHOT/fire/desc").is_empty() and not Reg.field("weapons/ESSENCE_SHOT/fire/radius").is_empty()
		and Reg.field("weapons/WEAPONS/revolver/shot_sound").is_empty() and not Reg.field("items/ITEMS/stamina/desc").is_empty(),
		"the new weapons, essence shots and the Stamina Draught are in the Data editor (their sounds aren't: ids)")


# --- consumables -------------------------------------------------------------------

func _staples() -> void:
	print("items: the staples are cheap and common")
	_check(I.ITEMS.has("stamina") and I.is_staple("draught") and I.is_staple("stamina") and Bench.BREW.has("stamina"), "a Stamina Draught joins the Healing Draught as a staple (and the bench brews it)")
	_check(int(I.START.get("draught", 0)) >= 1 and int(I.START.get("stamina", 0)) >= 1, "every climb starts with a Healing and a Stamina Draught")
	var dear := 9999
	var cheapest_other := ""
	for id in Train.supplies():
		if I.is_staple(id):
			continue
		var pr: Array = Train.item_price(id)
		if pr[1] < dear:
			dear = pr[1]
			cheapest_other = id
	var dp: int = Train.item_price("draught")[1]
	var sp: int = Train.item_price("stamina")[1]
	_check(dp <= 3 and sp <= 3 and dp * 3 <= dear, "the staples cost %d and %d; the cheapest other thing (%s) costs %d" % [dp, sp, cheapest_other, dear])
	_check(Train.supplies().slice(0, 2) == ["draught", "stamina"], "the staples come first on the store's shelf")
	var counts := {}
	var n := 4000
	for i in n:
		var id := I.random_item(true, [], true)
		counts[id] = int(counts.get(id, 0)) + 1
	var staples: float = float(int(counts.get("draught", 0)) + int(counts.get("stamina", 0))) / n
	var most_other := 0
	for id in counts:
		if not I.is_staple(id):
			most_other = maxi(most_other, int(counts[id]))
	_check(staples > 0.4 and int(counts.get("draught", 0)) > most_other * 3 and int(counts.get("stamina", 0)) > most_other * 3,
		"slain monsters mostly leave staples (%d%%); anything else is far rarer" % int(staples * 100.0))
	var camp_staple := false
	for i in 300:
		for c in I.camp_choices(true):
			camp_staple = camp_staple or I.is_staple(c)
	_check(not camp_staple, "camps and vaults offer the rarer things, never a staple")


func _stamina_draught() -> void:
	print("items: the Stamina Draught")
	var p = await _fresh()
	p.items = {"stamina": 2}
	p.item_sel = "stamina"
	p.sta = 10.0
	p.buffs.clear()
	var regen0: float = p.gfx("regen")
	_check(p.use_item() and absf(p.sta - 60.0) < 0.5, "a Stamina Draught gives 50 stamina back at once (%.0f)" % p.sta)
	_check(p.gfx("regen") > regen0 + 0.3 and p.buff_left("stamina") > 4.0, "...and stamina refills faster for a few seconds")
	p.sta = p.max_sta
	_check(not p.use_item() and p.item_count("stamina") == 1, "...not wasted when you're already breathing easy")
	p.buffs.clear()


# --- drawing ------------------------------------------------------------------------

func _drawing() -> void:
	print("weapons: how they're drawn")
	var empty: Array = []
	for id in NEW_WEAPONS:
		for s in [10.5, 18.0, 40.0]:
			var b = D.Batch.new()
			G.icon_into(b, G.make(id), Vector2.ZERO, s, G.color(id))
			if b.pts.is_empty() or b.pts.size() != b.cols.size():
				empty.append("%s@%s" % [id, s])
	for id in ["stamina"]:
		for s in [10.5, 18.0, 40.0]:
			var b = D.Batch.new()
			I.icon_into(b, id, Vector2.ZERO, s)
			if b.pts.is_empty():
				empty.append("%s@%s" % [id, s])
	_check(empty.is_empty(), "each new weapon and the Stamina Draught has an icon at every size %s" % [empty])
	var sizes := {}
	for id in NEW_WEAPONS:
		var b = D.Batch.new()
		G.icon_into(b, G.make(id), Vector2.ZERO, 18.0, G.color(id))
		sizes[b.pts.size()] = true
	_check(sizes.size() == NEW_WEAPONS.size(), "...each its own")
	# On the climber: in hand in the tower, slung, and on the front figure.
	var ok := true
	for id in NEW_WEAPONS:
		var b = D.Batch.new()
		if W.is_gun(id):
			GL.tower_gun(b, id, Vector2(10, 0), Vector2.RIGHT, Vector2(-0.6, -0.8), 0.5)
		else:
			GL.tower_cane(b, id, Vector2(10, 0), Vector2.RIGHT, 26.0, 0.0, Vector2(-0.6, -0.8), id == "sword_cane")
		var gear := G.start_gear()
		gear["melee" if G.slot_of(id) == "melee" else "ranged"] = G.make(id)
		var lk := GL.dressed(t.main.climber_look, gear, id)
		var fb = D.Batch.new()
		GL._front_weapon(fb, lk)
		var back = D.Batch.new()
		var lk2 := GL.dressed(t.main.climber_look, gear, "fists")
		lk2["gear_on"] = true
		lk2["slung"] = id
		GL.tower_back(back, Vector2.ZERO, Vector2.RIGHT, Vector2.UP, Vector2(-0.6, -0.8), lk2)
		var front_back = D.Batch.new()
		if W.is_gun(id):
			GL._front_holster(front_back, lk2)  # (a pistol holstered at the hip)
		else:
			GL.front_behind(front_back, lk2)  # (a cane across the back)
		if b.pts.is_empty() or fb.pts.is_empty() or back.pts.is_empty() or front_back.pts.is_empty():
			ok = false
			print("    %s: hand %d, front %d, slung %d, front slung %d" % [id, b.pts.size(), fb.pts.size(), back.pts.size(), front_back.pts.size()])
	_check(ok, "each is drawn in the climber's hand, slung on the back, and on the front figure")
	# The climber holding each, firing and reloading, for a few frames (no errors).
	var p = await _fresh()
	var m = _main()
	for id in NEW_WEAPONS:
		p.take_gear(id)
		p._equip(id)
		p.attack_cd = 0.0
		p._try_attack()
		p.queue_redraw()
		await t._frames(3)
	p.reload_t = 0.5
	p.queue_redraw()
	await t._frames(2)
	_check(not p.dead and p.weapon == "revolver", "the climber holds, fires and reloads each of them")
	m.hitstop_until = 0
	Engine.time_scale = 1.0


func _saves() -> void:
	print("weapons: kept in a save")
	var path := TestRun.path("user://weapons_items_test.cfg")
	var prof = load("res://scripts/profile.gd").new()
	prof.save_path = path
	prof.saving = true
	prof.pack = [G.make("revolver", "rare", ["embers", "hunt"]), G.make_named("lastbell_revolver"), G.make("sword_cane")]
	prof.save()
	var back = load("res://scripts/profile.gd").new()
	back.save_path = path
	back.load_save()
	_check(back.pack.size() == 3 and G.same(back.pack[0], prof.pack[0]) and G.named_id(back.pack[1]) == "lastbell_revolver" and G.base_id(back.pack[2]) == "sword_cane"
		and G.shot_kind(back.pack[0]) == "fire", "an enchanted revolver, a relic and a sword-cane save and load as they were")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
