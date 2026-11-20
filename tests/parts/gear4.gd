extends RefCounted
## Wave 4's gear and records: the off-hand slot (offhand.gd: a second
## one-handed weapon's strike in the chain, a shield's held block, a wand's
## power from its own pool, refilled like a charm; put away while a
## two-handed weapon or a bow is in hand), the Summit Blades (summit_blades.gd:
## hidden on a floor, a lead's glint, carried, bonded at the summit, awakened
## with crystals once between climbs, their powers) and the 36 deeds
## (deeds.gd, deeds_page.gd); the Entity explains each; no banned words.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const G := preload("res://scripts/gear.gd")
const C := preload("res://scripts/charms.gd")
const O := preload("res://scripts/offhand.gd")
const SB := preload("res://scripts/summit_blades.gd")
const DE := preload("res://scripts/deeds.gd")
const DP := preload("res://scripts/deeds_page.gd")
const Train := preload("res://scripts/train.gd")
const Bench := preload("res://scripts/bench.gd")
const D := preload("res://scripts/draw_util.gd")
const Entity := preload("res://scripts/entity.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const Help := preload("res://scripts/entity_help.gd")
const Registry := preload("res://scripts/data_registry.gd")
const Renown := preload("res://scripts/renown.gd")

const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

var t


func run(smoke) -> void:
	t = smoke
	print("gear4: the off-hand, Summit Blades and deeds")
	await t._fresh_main()
	_data()
	await _offhand_strike()
	await _shield()
	await _wand()
	_drawn()
	await _blades()
	_deeds()
	await _pages()
	_words()
	SB.forced = false
	SB.test_leads = {}


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _main():
	return t.main


## A climber in the tower, nothing in the off hand, monsters out of the way.
func _fresh_player():
	var m = _main()
	for e in m.enemies():
		e.queue_free()
	await t._frames(1)
	var p = m.player
	p.gear = G.start_gear()
	p.weapon = "sword"
	p.swing = p.wdata()["combo"][0]
	p.combo = 0
	p.combo_t = 0.0
	p.refresh_gear()
	p.dead = false
	p.hp = p.max_health()
	p.sta = p.max_sta
	p.fatigue = 0.0
	p.attack_cd = 0.0
	p.parry_t = 0.0
	p.parry_cd = 0.0
	p.roll_t = 0.0
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.guard_force = false
	p.off_cd = 0.0
	p.barrier_hp = 0.0
	p.aim = Vector2.RIGHT
	p.set_physics_process(false)
	return p


func _data() -> void:
	var off: Array = G.PIECE_ORDER.filter(func(id): return G.PIECES[id]["slot"] == "offhand")
	var uses := {}
	for id in off:
		var u := O.use_of(id)
		uses[u] = int(uses.get(u, 0)) + 1
	_check(off.size() == 12, "twelve off-hand pieces (%d)" % off.size())
	_check(uses.get("weapon", 0) == 3 and uses.get("shield", 0) == 3 and uses.get("wand", 0) == 6, "three off-hand weapons, three shields and six wands (%s)" % [uses])
	_check(off.all(func(id): return O.USES.has(id) and int(G.PIECES[id].get("drop_weight", 0)) > 0 and Train.BASE_PRICE.has(id)),
		"each says what it does in a fight and is found like other gear")
	var wand_kinds := {}
	for id in off.filter(func(i): return O.use_of(i) == "wand"):
		wand_kinds[G.PIECES[id]["kind"]] = true
	_check(wand_kinds.size() == 6, "a wand in each of the six essences")
	var pools: Array = off.filter(func(id): return O.has_pool(G.make(id)))
	_check(pools.size() == 8 and pools.all(func(id): return G.enchanted(G.make(id))), "every enchanted off-hand piece has its own pool (%d)" % pools.size())
	_check(off.filter(func(id): return not G.enchanted(G.make(id))).size() == 4, "four ordinary ones")
	_check(G.gear_slot_for("offhand") == "offhand" and "offhand" in Train.WEAR_SLOTS and G.heirloom_slot("buckler") == "offhand" and G.slot_of("cinder_wand") == "offhand",
		"a real slot: worn, kept as an heirloom, chosen in the Loadout")
	_check(G.DOLL.any(func(r): return "offhand" in r), "the paper doll has it")
	_check(not G.traits_for("offhand").is_empty() and G.traits_for("offhand").size() >= 4, "off-hand pieces can carry traits")
	var fine := G.make("buckler", "rare", G.roll_traits("buckler", "rare"))
	_check(fine["traits"].size() == 2 and not G.wears(fine) and G.wears(G.make("buckler")), "a Rare buckler: two traits, never wears; a plain one wears")
	_check(O.two_handed("greatsword") and O.two_handed("longbow") and O.two_handed("crossbow") and not O.two_handed("sword") and not O.two_handed("flintlock") and not O.two_handed("fists"),
		"two-handed weapons and bows need both hands; swords, pistols and fists don't")
	var tables: Array = []
	for sec in Registry.SECTIONS:
		tables.append_array(sec.get("tables", []))
	_check(["offhand/USES", "offhand/TEXT", "summit_blades/BLADES", "summit_blades/AWAKEN", "deeds/DEEDS"].all(func(x): return tables.has(x)), "the new tables are in the Data editor")


func _offhand_strike() -> void:
	var m = _main()
	var p = await _fresh_player()
	var plain: int = p.wdata()["combo"].size()
	_check(O.chain(p, p.wdata()["combo"]).size() == plain, "no off-hand weapon: the sword's own chain")
	p.take_gear(G.make("parrying_dagger"))
	var ch: Array = O.chain(p, p.wdata()["combo"])
	_check(ch.size() == plain + 1 and ch[plain - 1].get("offhand", false) and ch[plain].get("heavy", false), "a Parrying Dagger puts its stab in the chain, just before the finisher")
	p.take_gear(G.make("greatsword"))
	p._equip("greatsword")
	_check(O.chain(p, p.wdata()["combo"]).size() == p.wdata()["combo"].size() and not O.usable(p), "a greatsword in hand: the off-hand is put away")
	p.take_gear(G.make("sword"))
	p._equip("sword")
	p.attack_cd = 0.0
	var e = await t._spawn("slime", p.global_position + Vector2(28, 0))
	var hp0: float = e.hp
	var n0: float = DE.counter(m.profile, "off_strikes")
	p.combo = plain - 1
	p.combo_t = 1.0
	p.sta = p.max_sta
	p._melee()
	_check(p.swing.get("offhand", false) and e.hp < hp0, "the off-hand stab lands (%.0f -> %.0f)" % [hp0, e.hp])
	_check(DE.counter(m.profile, "off_strikes") == n0 + 1.0, "...and counts toward its deed")
	# The Ember Dirk spends its pool to set the foe burning.
	p.attack_cd = 0.0
	p.take_gear(G.make("ember_dirk"))
	var full := O.pool(O.piece(p))
	p.combo = plain - 1
	p.combo_t = 1.0
	p._melee()
	_check(O.pool(O.piece(p)) == full - 1, "an Ember Dirk's stab spends a use of its own pool (%d of %d)" % [O.pool(O.piece(p)), full])
	e.queue_free()
	p.attack_cd = 0.0
	await t._frames(1)


func _shield() -> void:
	var m = _main()
	var p = await _fresh_player()
	p.take_gear(G.make("buckler"))
	var e = await t._spawn("slime", p.global_position + Vector2(40, 0))
	var prot: float = p.protection()
	p.guard_force = true
	_check(O.guarding(p) and O.walk_mult(p) < 1.0, "a buckler, parry held: guarding, walking slower")
	var hp0: float = p.hp
	var sta0: float = p.sta
	p.receive_attack(20.0, e)
	var took: float = hp0 - p.hp
	_check(absf(took - 20.0 * (1.0 - 0.45) * (1.0 - prot)) < 0.6 and is_equal_approx(p.sta, sta0 - 8.0), "a blocked blow: 45%% off (took %.1f), 8 stamina" % took)
	_check(DE.counter(m.profile, "blocks") >= 1.0, "...and counts toward Shield Wall")
	# From behind: no block.
	p.hurt_t = 0.0
	p.aim = Vector2.LEFT
	hp0 = p.hp
	p.receive_attack(10.0, e)
	_check(absf((hp0 - p.hp) - 10.0 * (1.0 - prot)) < 0.6, "a blow from behind isn't blocked")
	# Too little stamina: the guard breaks.
	p.hurt_t = 0.0
	p.aim = Vector2.RIGHT
	p.sta = 2.0
	hp0 = p.hp
	p.receive_attack(10.0, e)
	_check(absf((hp0 - p.hp) - 10.0 * (1.0 - prot)) < 0.6 and p.sta == 0.0 and p.attack_cd > 0.0, "with too little stamina the guard breaks: the blow lands whole, and you stagger")
	p.attack_cd = 0.0
	# A parry is still the skilful answer.
	p.hurt_t = 0.0
	p.sta = 20.0
	p.parry_cd = 0.0
	p._try_parry()
	hp0 = p.hp
	p.receive_attack(10.0, e)
	_check(p.hp == hp0 and p.sta > 20.0, "a parry with a shield up: nothing taken, stamina back (hp %.1f -> %.1f, stamina %.0f, parry %.2f)" % [hp0, p.hp, p.sta, p.parry_t])
	# A two-handed weapon in hand puts the shield away.
	p.parry_t = 0.0
	p.take_gear(G.make("war_hammer"))
	p._equip("war_hammer")
	_check(not O.guarding(p), "a war hammer in hand: no guard")
	p.guard_force = false
	e.queue_free()
	await t._frames(1)


func _wand() -> void:
	var m = _main()
	var p = await _fresh_player()
	p.take_gear(G.make("cinder_wand"))
	var g := O.piece(p)
	_check(O.pool(g) == 6 and O.pool_max(g) == 6, "a Cinder Wand: a pool of six uses")
	var shots0: int = m.get_children().filter(func(c): return "friendly" in c and c.friendly).size()
	O.cast(p)
	var shots1: int = m.get_children().filter(func(c): return "friendly" in c and c.friendly).size()
	_check(O.pool(g) == 5 and shots1 == shots0 + 1 and p.off_cd > 0.0, "the off-hand button casts: a bolt, one use spent, a short rest")
	_check(InputMap.has_action("offhand"), "an off-hand button (U, the middle mouse button, the left stick)")
	g["charge"] = 0
	p.off_cd = 0.0
	O.cast(p)
	_check(O.pool(g) == 0, "an empty pool: nothing cast")
	# Fed with essence not yet banked, as a charm is.
	m.run_essence = {"fire": 40.0}
	var why := O.refill_unbanked(m, g)
	_check(why == "" and O.pool(g) == 6 and float(m.run_essence["fire"]) < 40.0, "fed with unbanked essence, its pool fills (%s)" % why)
	# The bench refills one waiting in the Loadout with crystals.
	var prof = m.profile
	var spent := G.make("tide_wand")
	spent["charge"] = 1
	prof.wear["offhand"] = spent
	_check("wear:offhand" in Bench.charm_refs(prof), "the bench's Charms counter refills an off-hand piece's pool too")
	prof.wear.erase("offhand")
	# The iron wand raises a barrier.
	p.take_gear(G.make("iron_wand"))
	p.off_cd = 0.0
	p.barrier_hp = 0.0
	O.cast(p)
	_check(p.barrier_hp > 0.0, "an Iron Wand raises a barrier")
	# A bow in hand puts the wand away.
	p.take_gear(G.make("longbow"))
	p._equip("longbow")
	p.off_cd = 0.0
	var before := O.pool(O.piece(p))
	O.cast(p)
	_check(O.pool(O.piece(p)) == before, "a bow in hand: the wand is put away")
	# The phone's Off-hand button comes only with a wand in a free hand.
	p._equip("fists")
	m.touch._set_active(true)
	m.touch._layout()
	_check(m.touch.buttons.any(func(b): return b["id"] == "offhand"), "a wand in a free hand: the phone shows an Off-hand button")
	p.gear["offhand"] = {}
	p.refresh_gear()
	m.touch._layout()
	_check(not m.touch.buttons.any(func(b): return b["id"] == "offhand"), "...and none without one")
	m.touch._set_active(false)
	await t._frames(1)


func _drawn() -> void:
	var empty: Array = []
	for id in G.PIECE_ORDER.filter(func(i): return G.PIECES[i]["slot"] == "offhand"):
		for s in [10.5, 18.0, 40.0]:
			var b = D.Batch.new()
			G.icon_into(b, G.make(id), Vector2.ZERO, s, G.color(id))
			if b.pts.is_empty():
				empty.append("%s@%s" % [id, s])
		var lk := {"offhand": id, "offhand_col": G.color(id)}
		var fb = D.Batch.new()
		O.front(fb, lk, false)
		O.front(fb, lk, true)
		if fb.pts.is_empty():
			empty.append(id + " (front)")
	_check(empty.is_empty(), "every off-hand piece is drawn in code: its icon and on the climber (%s)" % [empty])
	var look: Dictionary = load("res://scripts/gear_look.gd").dressed(_main().climber_look, {"melee": G.make("sword"), "offhand": G.make("kite_shield")}, "sword")
	_check(look.get("offhand", "") == "kite_shield", "the climber's figure shows the off-hand piece")
	var look2: Dictionary = load("res://scripts/gear_look.gd").dressed(_main().climber_look, {"melee": G.make("greatsword"), "offhand": G.make("kite_shield")}, "greatsword")
	_check(look2.get("offhand", "") == "", "...but not with a greatsword in hand")
	var empty_b: Array = []
	for tw in SB.ORDER:
		var b = D.Batch.new()
		SB.icon_into(b, Vector2.ZERO, 24.0, tw, true, 3)
		SB.floor_into(b, Vector2.ZERO, tw, 1.0, 0.0)
		if b.pts.is_empty():
			empty_b.append(tw)
	_check(empty_b.is_empty() and SB.ORDER.size() == 6, "six Summit Blades, each drawn in code")


func _blades() -> void:
	var m = _main()
	var prof = m.profile
	prof.summit_blades = {}
	SB.forced = true
	var node = m.summit_blades
	# A floor with a quiet spot: the blade lies there.
	var tries := 0
	while node.spot.is_empty() and tries < 24:
		m._start_floor(3 + tries % 6)
		await t._frames(1)
		tries += 1
	_check(not node.spot.is_empty(), "a floor with a quiet corner holds its tower's blade (%d tries)" % tries)
	if node.spot.is_empty():
		return
	var tower := String(node.spot["tower"])
	var p = m.player
	for e in m.enemies():
		e.set_physics_process(false)
	p.global_position = node.spot["pos"] + Vector2(400, 0)
	SB.test_leads = {}
	_check(not node.seen(), "without a lead it can't be seen from afar")
	SB.test_leads = {tower: true}
	_check(node.seen() and node.lead(), "with a lead its glint shows from afar")
	SB.test_leads = {}
	p.global_position = node.spot["pos"] + Vector2(40, 0)
	_check(node.seen(), "up close it can be seen without one")
	var floors_ok := true
	for tw in SB.ORDER:
		var f := SB.blade_floor(prof, tw)
		floors_ok = floors_ok and f >= 3 and f <= 10
	_check(floors_ok, "each tower's blade lies on one floor between 3 and 10")
	# Walk over it: carried.
	p.global_position = node.spot["pos"]
	await t._frames(2)
	_check(node.carrying == tower and node.spot.is_empty() and SB.state(prof)["found"].has(tower), "walking over it takes it up: carried, and found")
	_check(not SB.bonded(prof, tower), "...not bonded yet")
	# A new climb (a fall, a recall): it's back in its hiding place.
	node.new_climb()
	_check(node.carrying == "" and not SB.bonded(prof, tower), "a new climb without the summit: it's lost again")
	# The summit bonds it.
	node.carrying = tower
	var lines: Array = node.on_summit()
	_check(SB.bonded(prof, tower) and SB.worn(prof) == tower and not lines.is_empty(), "the summit bonds it for good, carried at the hip")
	_check(DE.counter(prof, "summits") >= 1.0, "...and the summit counts for its deed")
	# Awakening: crystals of its essence, one step between climbs.
	var kind := String(SB.BLADES[tower]["kind"])
	prof.add_crystal(kind, 200.0)
	_check(SB.awaken_why(prof, tower) != "", "just bonded: it can't awaken until another climb")
	SB.state(prof)["climbs"] = int(SB.state(prof)["climbs"]) + 1
	var have: float = prof.crystal_total(kind)
	_check(SB.awaken(prof, tower) == "" and SB.level(prof, tower) == 1 and prof.crystal_total(kind) < have, "after a climb it awakens a step, for crystals of its tower's essence")
	_check(SB.awaken_why(prof, tower) != "", "...and only once between climbs")
	_check(SB.AWAKEN.size() == 6 and SB.AWAKEN.reduce(func(a, b): return a + b, 0) <= 300, "six steps, slow: %d crystals in all" % SB.AWAKEN.reduce(func(a, b): return a + b, 0))
	# Its power: a perfect parry with Emberwake heals.
	SB.state(prof)["bonded"]["firebird"] = {"level": 2, "woke": 0}
	SB.carry(prof, "firebird")
	p.blade_cd = 0.0
	p.hp = p.max_health() * 0.5
	var hp0: float = p.hp
	SB.on_parry(p, null, true)
	_check(p.hp > hp0 and p.blade_cd > 0.0, "Emberwake: a perfect parry heals (%.0f -> %.0f), then rests" % [hp0, p.hp])
	hp0 = p.hp
	SB.on_parry(p, null, true)
	_check(p.hp == hp0, "...not again while it rests")
	SB.forced = false
	await t._frames(1)


func _deeds() -> void:
	var m = _main()
	var prof = m.profile
	_check(DE.ORDER.size() == 36 and DE.KINDS.size() == 6 and DE.KINDS.all(func(k): return DE.of_kind(k[0]).size() == 6), "36 deeds, six kinds of six")
	_check(DE.ORDER.all(func(id): return int(DE.DEEDS[id]["renown"]) >= 1 and int(DE.DEEDS[id]["renown"]) <= 6), "each pays 1 to 6 renown")
	_check(DE.renown_total() >= 114 and DE.renown_total() <= 126, "about 120 renown for them all (%d)" % DE.renown_total())
	prof.deeds = {}
	prof.record["slain"] = 1.0
	var pts0 := Renown.points(prof)
	var got := DE.check(m)
	_check("first_blood" in got and DE.is_done(prof, "first_blood"), "a monster slain: First Blood done (%s)" % [got])
	_check(Renown.points(prof) >= pts0 + 1, "...and its renown paid")
	_check(DE.check(m).is_empty(), "nothing is paid twice")
	DE.note(m, "clean_floors")
	_check("untouched" in DE.check(m), "a floor climbed without a hit: Untouched")
	_check(DE.progress(prof, "six_score") == [1, 120], "progress is shown (%s)" % [DE.progress(prof, "six_score")])


func _pages() -> void:
	var m = _main()
	var menu = m.menu
	menu.climber_tab = "deeds"
	DP.leaf = "deeds"
	menu.open("climber")
	await t._frames(2)
	var rows: Array = menu.find_children("*", "HBoxContainer", true, false).filter(func(n): return n.has_meta("deed"))
	_check(rows.size() == 36, "the book's Deeds ribbon lists all 36 deeds (%d)" % rows.size())
	var ribbons: Array = t._all_buttons(menu).filter(func(b): return b.get_meta("ribbon", "") == "deeds")
	_check(ribbons.size() == 1 and Help.entry(Help.key_for(ribbons[0])) != "", "a Deeds ribbon, with the Entity's help")
	var leaves: Array = t._all_buttons(menu).filter(func(b): return b.has_meta("deeds_leaf"))
	_check(leaves.size() == 2 and leaves.all(func(b): return not Help.missing(b)), "two leaves, each with the Entity's help")
	# The Summit Blades leaf, on the train: Carry and Awaken.
	m.on_train = true
	DP.leaf = "blades"
	menu.open("climber")
	await t._frames(2)
	var cards: Array = menu.find_children("*", "PanelContainer", true, false).filter(func(n): return n.has_meta("blade"))
	_check(cards.size() == 6, "six Summit Blade cards")
	var acts: Array = t._all_buttons(menu).filter(func(b): return String(b.get_meta("help", "")) in ["deeds_carry", "deeds_awaken"])
	_check(not acts.is_empty() and acts.all(func(b): return not Help.missing(b)), "Carry and Awaken buttons, with help (%d)" % acts.size())
	m.on_train = false
	DP.leaf = "deeds"
	menu.close()
	await t._frames(1)


func _words() -> void:
	for id in ["offhand", "summit_blade", "summit_bond", "summit_awaken", "deeds"]:
		_check(Entity.TIPS.has(id) and String(Entity.TIPS[id].get("tip", "")) != "" and String(Entity.TIPS[id].get("more", "")) != "", "the Entity's first word on %s" % id)
	var how: Array = Talk.DIALOGUE["how"]["choices"]
	_check(["how_offhand", "how_summit", "how_deeds"].all(func(x): return x in how and Talk.DIALOGUE.has(x)), "\"How does it work?\" topics for the off-hand, Summit Blades and deeds")
	_check(["feed_offhand", "tab:deeds", "deeds_carry", "deeds_awaken", "deeds_leaf_deeds", "deeds_leaf_blades"].all(func(k): return Help.HELP.has(k)), "hover help for every new button")
	var words: Array = [JSON.stringify(O.TEXT), JSON.stringify(SB.BLADES), JSON.stringify(SB.TEXT), JSON.stringify(DE.DEEDS), JSON.stringify(DE.TEXT)]
	for id in ["offhand", "summit_blade", "summit_bond", "summit_awaken", "deeds"]:
		words.append(JSON.stringify(Entity.TIPS[id]))
	for id in ["how_offhand", "how_summit", "how_deeds"]:
		words.append(JSON.stringify(Talk.DIALOGUE[id]))
	for id in G.PIECE_ORDER.filter(func(i): return G.PIECES[i]["slot"] == "offhand"):
		words.append(JSON.stringify(G.PIECES[id]))
	var hits: Array = []
	for w in words:
		for b in BANNED:
			if b in String(w).to_lower():
				hits.append(b)
	_check(hits.is_empty(), "no banned words (%s)" % [hits])
