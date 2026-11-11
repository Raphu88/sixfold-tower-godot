extends RefCounted
## Gear and items: no trait twice on a piece (on every path, and old saves
## cleaned), the beasts' Regarded pieces, the new belt items, the new worn
## pieces and named pieces, and their icons. Run by smoke_test.gd
## (_part_tests); `t` is the smoke test.

const G := preload("res://scripts/gear.gd")
const I := preload("res://scripts/items.gd")
const Train := preload("res://scripts/train.gd")
const Bench := preload("res://scripts/bench.gd")
const D := preload("res://scripts/draw_util.gd")

const NEW_ITEMS := ["antidote", "heartroot", "net", "lodestone", "briar_tonic", "wardbreaker", "lantern_oil", "unmaking_ash", "gale_feather", "seeing_scroll"]
const NEW_PIECES := ["feathered_cap", "miners_helm", "archers_bracers", "studded_gloves", "ranger_breeches", "plated_greaves", "wading_boots", "feather_cape",
	"herb_pouch", "wolf_tooth", "sunstone_pendant", "silver_ring", "jade_ring", "viper_ring", "bandolier"]
const NEW_STORIED := ["hollowmoon_bow", "rootbound_greaves", "wayfinders_pendant", "duelists_ring"]
const BEASTS := ["gryphon", "kraken", "wyvern", "manticore", "firebird", "chimera"]

var t


func run(smoke) -> void:
	t = smoke
	_no_trait_twice()
	_regarded_data()
	await _regarded_drops()
	await _new_items()
	await _new_pieces()
	await _beast_rules()
	_icons()


func _main():
	return t.main


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _unique(g) -> bool:
	var tr: Array = G.rec(g).get("traits", [])
	var seen := {}
	for x in tr:
		if seen.has(x):
			return false
		seen[x] = true
	return true


func _no_trait_twice() -> void:
	print("gear: no trait twice")
	var g := G.make("sword", "rare", ["edges", "edges"])
	_check(g["traits"].size() == 2 and _unique(g) and g["traits"][0] == "edges" and G.trait_slot(g) in G.TRAITS[g["traits"][1]]["slots"],
		"a repeated trait is replaced by another that fits: %s" % [g["traits"]])
	_check(G.same(G.make("sword", "rare", ["edges", "edges"]), g), "...the same one every time (an old save cleans the same way on every load)")
	var old := {"base": "iron_helm", "rarity": "rare", "traits": ["vigor", "vigor"], "rank": 1}
	_check(_unique(G.rec(old)) and G.rec(old)["traits"].size() == 2, "an old saved record with a repeat is cleaned as it loads")
	_check(_unique(G.rec("leather_gloves;rare;0;calm,calm")), "...and an old card code")
	var heir := G.load_heirlooms({"helm": old, "rings": [{"base": "garnet_ring", "rarity": "rare", "traits": ["edges", "edges"]}]})
	_check(_unique(heir["helm"]) and _unique(heir["rings"][0]), "...and old heirlooms")
	var prof_list: Array = load("res://scripts/profile.gd")._records([old, "boots;rare;0;wind,wind"])
	_check(prof_list.all(func(r): return _unique(r)), "...and an old pack or chest")
	# A slot with fewer traits than repeats: the extra goes.
	var many := G.make("satchel", "rare", ["vigor", "vigor"])
	_check(_unique(many), "a repeat with nothing left to replace it is dropped")
	# Every way a piece is made.
	var ok := true
	for i in 600:
		var r := G.roll_gear("", [], true, 1 + i % 14, BEASTS[i % 6], i % 3)
		ok = ok and _unique(r)
	_check(ok, "drops, caches, camps and vaults never roll a trait twice")
	var today_ok := true
	for i in 120:
		today_ok = today_ok and _unique(Train.roll_today())
	_check(today_ok, "today's piece never has a trait twice")
	var a := G.make("leather_gloves", "fine", ["edges"])
	var b := G.make("leather_gloves", "fine", ["edges"])
	var j := Bench.joined(a, b)
	_check(j["traits"].size() == 2 and _unique(j), "joining two Fine pieces with the same trait makes a Rare with two different ones: %s" % [j["traits"]])
	var rt := G.make("iron_helm", "rare", ["vigor", "calm"])
	var opts: Dictionary = Bench.retrait_options(rt, 0)
	var any_dup := false
	for k in opts:
		any_dup = any_dup or opts[k].has("calm") or opts[k].has("vigor")
	_check(not any_dup and not opts.is_empty(), "retraiting only offers traits the piece doesn't have")
	var prov = load("res://scripts/proving.gd").new()
	var prize_ok := true
	for i in 12:
		for c in prov.prize_choices():
			prize_ok = prize_ok and _unique(String(c).substr(5))
	prov.free()
	_check(prize_ok, "the Proving's relics never carry a trait twice")
	var slots_ok := true
	for sl in ["melee", "ranged", "armor", "helm", "gloves", "legs", "boots", "cloak", "amulet", "ring"]:
		slots_ok = slots_ok and G.traits_for(sl).size() >= 4
	_check(slots_ok, "every slot but the backpack has at least four traits (so a Regarded piece gets four different ones)")


func _regarded_data() -> void:
	print("gear: Regarded pieces")
	_check(G.RARITIES["regarded"]["traits"] == 4 and G.RARITIES["regarded"]["named_traits"] == 4 and not G.RARITIES["regarded"]["wears"],
		"Regarded: four traits, never wears")
	var seen := {}
	var ok := true
	for tw in BEASTS:
		var n := G.beast_piece(tw)
		if n == "":
			ok = false
			continue
		seen[n] = true
		for i in 20:
			var g := G.make_named(n)
			ok = ok and g["rarity"] == "regarded" and g["traits"].size() == 4 and _unique(g) and not g.has("wear") \
				and g["traits"].all(func(x): return G.trait_slot(g) in G.TRAITS[x]["slots"])
		ok = ok and String(G.NAMED[n]["desc"]) != "" and not G.NAMED[n].get("fx", {}).is_empty()
	_check(ok and seen.size() == 6, "each of the six beasts has its own Regarded piece, with a rule and four different traits that fit (%s)" % [seen.keys()])
	var plain := true
	for i in 1500:
		plain = plain and G.rarity(G.roll_gear("", [], true, 14, "gryphon", 2)) != "regarded"
	_check(plain, "Regarded pieces never drop from monsters, caches, camps or vaults")
	var reg := G.make_named("triune_fang")
	var sto := G.make_named("reavers_greatsword")
	_check(Train.gear_price(reg) > Train.gear_price(sto) and Train.gear_sell(reg) > Train.gear_sell(sto), "a Regarded piece costs and sells for more than a Storied one (%d > %d)" % [Train.gear_sell(reg), Train.gear_sell(sto)])
	_check(G.rarity_color(reg) == G.RARITIES["regarded"]["color"] and G.noticed(reg) and G.display(reg) == "Triune Fang", "its gold colour, name and notice")
	_check(G.describe(reg).any(func(l): return String(l).contains(G.TEXT["beast_piece"])), "its card says its beast left it")
	_check(absf(G.weapon_boost(reg) - 1.15) < 0.001, "a Regarded weapon hits 15% harder")


func _regarded_drops() -> void:
	print("gear: a beast leaves its piece")
	await t._fresh_main()
	var m = _main()
	var p = m.player
	m.tower = "gryphon"
	var beast = await t._spawn("gryphon", p.global_position + Vector2(220, 0))
	m.gear_drops.clear()
	m.profile.record["beasts_by"] = {}
	t._slay(beast)
	await t._frames(2)
	var got: Array = m.gear_drops.filter(func(d): return G.rarity(d["rec"]) == "regarded")
	_check(got.size() == 1 and G.named_id(got[0]["rec"]) == "stormtalon", "the Gryphon, slain the first time, leaves Stormtalon where it falls")
	_check(not m.loot_notice.is_empty() and String(m.loot_notice["text"]).begins_with("REGARDED:"), "...with a gold notice: %s" % m.loot_notice.get("text", ""))
	var lines: Array = m._keep_beast_pieces()
	_check(lines.size() == 1 and p.pack.any(func(g): return G.rarity(g) == "regarded") and m.gear_drops.is_empty(), "left on the floor at the summit stair, it comes down in your pack")
	var keep: float = G.REGARDED_DROP["again"]
	G.REGARDED_DROP["again"] = 0.0
	var b2 = await t._spawn("gryphon", p.global_position + Vector2(220, 0))
	t._slay(b2)
	await t._frames(2)
	_check(m.gear_drops.filter(func(d): return G.rarity(d["rec"]) == "regarded").is_empty(), "after the first time it leaves it only sometimes (REGARDED_DROP)")
	G.REGARDED_DROP["again"] = keep
	var shade = await t._spawn("kraken", p.global_position + Vector2(220, 0))
	shade.shade = true
	m.tower = "kraken"
	m.profile.record["beasts_by"] = {}
	t._slay(shade)
	await t._frames(2)
	_check(m.gear_drops.filter(func(d): return G.rarity(d["rec"]) == "regarded").is_empty(), "the Proving's shadow of a beast leaves nothing")
	m.gear_drops.clear()


func _new_items() -> void:
	print("items: the new belt items")
	await t._fresh_main()
	var m = _main()
	var p = m.player
	m.grant_test_bonds()
	await t._frames(2)
	var data_ok := true
	for id in NEW_ITEMS:
		var d: Dictionary = I.ITEMS.get(id, {})
		data_ok = data_ok and id in I.ORDER and d.has("name") and d.has("desc") and d.has("kind") and not d.get("value", {}).is_empty() \
			and Bench.BREW.has(id) and Train.item_price(id)[1] > 0 and id in Train.supplies()
	_check(data_ok, "ten new items, each with a name, a line, an essence, a worth, a store price and a bench recipe")
	var drop_kinds := {}
	for i in 3000:
		drop_kinds[I.random_item(true, [], true)] = true
	_check(drop_kinds.has("net") and drop_kinds.has("antidote") and not drop_kinds.has("heartroot") and not drop_kinds.has("unmaking_ash"),
		"monsters leave the new items, but not the secret essences' Heartroot and Ash (camps and vaults offer those)")
	var camp_kinds := {}
	for i in 600:
		for c in I.camp_choices(true):
			camp_kinds[c] = true
	_check(camp_kinds.has("heartroot") and camp_kinds.has("unmaking_ash") and camp_kinds.has("seeing_scroll"), "camps offer them")
	m.floor_num = 3
	p.global_position = Vector2(500, 400)
	p.aim = Vector2.RIGHT
	# Antivenom
	p.poison(5.0)
	p.items = {"antidote": 1}
	p.item_sel = "antidote"
	_check(p.use_item() and p.poison_t <= 0.0, "Antivenom cures poison")
	p.poison(5.0)
	_check(p.poison_t <= 0.0, "...and no poison takes hold for a while")
	p.buffs.clear()
	# Heartroot
	p.hp = 40.0
	p.items = {"heartroot": 1}
	p.item_sel = "heartroot"
	_check(p.use_item() and p.heal_left > 0.0 and absf(p.gfx("kill_heal") - 4.0) < 0.01, "Heartroot heals and makes kills heal")
	p.buffs.clear()
	# Briar Tonic, Wardbreaker, Lantern Oil, Scroll of Seeing
	for id in ["briar_tonic", "wardbreaker", "lantern_oil", "seeing_scroll"]:
		p.items = {id: 1}
		p.item_sel = id
		p.use_item()
	_check(absf(p.gfx("thorns") - 8.0) < 0.01, "a Briar Tonic: foes that strike you take 8")
	var brute = await t._spawn("knight", p.global_position + Vector2(40, 0))
	var bhp: float = brute.hp
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.parry_t = 0.0
	p.receive_attack(3.0, brute)
	_check(absf((bhp - brute.hp) - 8.0) < 0.5, "...and they do (%.1f)" % (bhp - brute.hp))
	brute.queue_free()
	var shell = await t._spawn("shellback", p.global_position + Vector2(40, 0))
	shell.face = Vector2.LEFT
	var shp: float = shell.hp
	p._strike(shell, 20.0, Vector2.RIGHT, 0.0, false)
	_check(shp - shell.hp > 15.0, "a Wardbreaker Charm: a shellback's shell no longer turns your blow (%.1f)" % (shp - shell.hp))
	shell.queue_free()
	_check(p.gfx("light") >= 0.6 - 0.001 and m.lighting.player_reach() > m.lighting.PLAYER_REACH * 1.55, "Lantern Oil: your light reaches farther")
	_check(m.flare_reveals(p.global_position + Vector2(2000, 0)), "a Scroll of Seeing: hidden things glint anywhere on the floor")
	p.buffs.clear()
	_check(not m.flare_reveals(p.global_position + Vector2(2000, 0)), "...for a while")
	# Unmaking Ash and the Gale Feather
	var foe = await t._dummy(p.global_position + Vector2(60, 0))
	p.items = {"unmaking_ash": 1}
	p.item_sel = "unmaking_ash"
	p.use_item()
	_check(absf((999.0 - foe.hp) - 999.0 * 0.12) < 2.0, "Ash of Unmaking: a foe in reach loses an eighth of its health (%.0f)" % (999.0 - foe.hp))
	p.items = {"gale_feather": 1}
	p.item_sel = "gale_feather"
	p.use_item()
	_check(foe.knock.x > 300.0, "a Gale Feather hurls the foes around you back")
	foe.queue_free()
	# Thrown: the net and the lodestone bomb
	var near = await t._dummy(p.global_position + Vector2(150, 0))
	p.items = {"net": 1}
	p.item_sel = "net"
	_check(p.use_item() and m.flasks.size() == 1 and m.flasks[0]["id"] == "net", "a Throwing Net is thrown where you aim")
	await t._wait(0.6)
	_check(near.chill_t > 1.0 and near.stun > 0.0, "...and tangles and slows the foe it lands on")
	near.queue_free()
	var f1 = await t._dummy(p.global_position + Vector2(120, -60))
	var f2 = await t._dummy(p.global_position + Vector2(120, 60))
	f1.knock = Vector2.ZERO
	f2.knock = Vector2.ZERO
	p.items = {"lodestone": 1}
	p.item_sel = "lodestone"
	p.aim = Vector2.RIGHT
	_check(p.use_item(), "a Lodestone Bomb is thrown")
	await t._wait(0.5)
	_check(f1.knock.y > 50.0 and f2.knock.y < -50.0, "...and drags the foes around it together (%s, %s)" % [f1.knock, f2.knock])
	f1.queue_free()
	f2.queue_free()
	m.flasks.clear()


func _new_pieces() -> void:
	print("gear: the new worn pieces")
	await t._fresh_main()
	var m = _main()
	var p = m.player
	m.grant_test_bonds()
	await t._frames(2)
	var ok := true
	var bad: Array = []
	for id in NEW_PIECES:
		var d: Dictionary = G.PIECES[id]
		ok = ok and Train.BASE_PRICE.has(id) and String(d.get("desc", "")) != ""
		for s in G.carry_slots(G.slot_of(id)):
			p.gear[s] = {}
		p.take_gear(G.make(id))
		var fx: Dictionary = G.total_effects(p.gear, true)
		for k in d:
			if k in ["slot", "name", "short", "desc", "color", "drop_weight", "look", "rarity"]:
				continue
			if k == "heavy":
				if int(fx.get("heavy", 0)) < 1:
					bad.append(id + ":" + k)
			elif not fx.has(k):
				bad.append(id + ":" + k)
	_check(ok and bad.is_empty(), "every new piece has a price and its numbers apply when worn %s" % [bad])
	var per_slot := {}
	for id in G.PIECE_ORDER:
		per_slot[G.slot_of(id)] = int(per_slot.get(G.slot_of(id), 0)) + 1
	_check(G.PIECE_SLOTS.all(func(s): return int(per_slot.get(s, 0)) >= 3), "every worn slot has at least three pieces to choose from (%s)" % [per_slot])
	var rack_ok := Train.common_pool().has("feathered_cap") and Train.common_pool().has("plated_greaves") and not Train.common_pool().has("viper_ring")
	_check(rack_ok, "the outfitter's rack sells the new Common pieces")
	# Behaviour of the new numbers.
	p.global_position = Vector2(500, 400)
	p.take_gear(G.make("longbow"))
	p._equip("longbow")
	for s in ["gloves"]:
		p.gear[s] = {}
	p.refresh_gear()
	p.draw_t = 0.0
	p._tick_draw(0.1)
	var plain: float = p.draw_t
	p.take_gear(G.make("archers_bracers"))
	p.draw_t = 0.0
	p._tick_draw(0.1)
	_check(absf(p.draw_t / plain - 1.10) < 0.01, "Archer's Bracers: bows draw 10%% faster (%.3f)" % (p.draw_t / plain))
	p.take_gear(G.make("wading_boots"))
	_check(m.water_slow(Vector2.ZERO, p.gear_fx.get("wade", false)) == 1.0, "Wading Boots: water doesn't slow you")
	p.take_gear(G.make("herb_pouch"))
	p.hp = 20.0
	p.heal_left = 0.0
	I._heal_over_time(p, I.ITEMS["draught"], false)
	_check(absf(p.heal_left - I.ITEMS["draught"]["heal"] * 1.25 * p.heal_mult()) < 0.1, "a Herb Pouch: healing items heal 25%% more (%.1f)" % p.heal_left)
	p.take_gear(G.make("viper_ring"))
	p.add_buff("test", 5.0, {"venom_chance": 1.0})
	var vic = await t._dummy(p.global_position + Vector2(40, 0))
	p._strike(vic, 1.0, Vector2.RIGHT, 0.0, false)
	_check(vic.venom > 0, "a Viper Ring (or of Venom): a hit can poison the foe")
	vic.queue_free()
	p.buffs.clear()
	# New Storied pieces.
	var st_ok := true
	for n in NEW_STORIED:
		var g := G.make_named(n)
		st_ok = st_ok and g["rarity"] == "storied" and g["traits"].size() == 1
	_check(st_ok and G.named_pool("storied", "kraken").has("duelists_ring"), "four new Storied pieces, found like the others")
	p.take_gear(G.make_named("duelists_ring"))
	_check(absf(p.gfx("parry_sta") - 15.0) < 0.01, "a Duelist's Ring: a parry gives back more stamina")
	p.sta = 0.0
	var src = await t._dummy(p.global_position + Vector2(40, 0))
	p._on_parry(src, false)
	_check(p.sta >= 12.0 + 15.0 - 0.01, "...and does (%.0f)" % p.sta)
	src.queue_free()
	p.take_gear(G.make_named("wayfinders_pendant"))
	_check(m.flare_reveals(p.global_position + Vector2(150, 0)) and not m.flare_reveals(p.global_position + Vector2(900, 0)), "a Wayfinder's Pendant: hidden things near you glint")
	p.take_gear(G.make_named("rootbound_greaves"))
	p.velocity = Vector2.ZERO
	p.hp = 100.0
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.parry_t = 0.0
	var red: float = p.protection()
	p.receive_attack(20.0, null)
	_check(absf((100.0 - p.hp) - 20.0 * 0.75 * (1.0 - red)) < 0.2, "Rootbound Greaves: standing still, blows hurt 25%% less (%.1f)" % (100.0 - p.hp))
	p.hp = p.max_health()
	p.take_gear(G.make_named("hollowmoon_bow"))
	p._equip("longbow")
	var hand = p.bonds.get("hand")
	if hand != null:
		hand.essence = 0.0
		var tgt = await t._dummy(p.global_position + Vector2(60, 0))
		p.ranged_hit(tgt, 5.0, Vector2.RIGHT, 0.0, true)
		_check(hand.essence >= 3.99, "a Hollowmoon Bow: a full draw that hits fills the hand's mark")
		tgt.queue_free()


func _beast_rules() -> void:
	print("gear: the beasts' own rules")
	await t._fresh_main()
	var m = _main()
	var p = m.player
	for x in m.enemies():
		x.queue_free()
	await t._frames(2)
	p.global_position = Vector2(500, 400)
	p.aim = Vector2.RIGHT
	# Triune Fang: lion, goat, serpent.
	p.take_gear(G.make_named("triune_fang"))
	p._equip("greatsword")
	p.triune_n = 0
	var e = await t._dummy(p.global_position + Vector2(40, 0))
	var h0: float = e.hp
	p._strike(e, 10.0, Vector2.RIGHT, 0.0, false)
	var lion: float = h0 - e.hp
	e.stun = 0.0
	var h1: float = e.hp
	p._strike(e, 10.0, Vector2.RIGHT, 0.0, false)
	var goat_stun: float = e.stun
	e.stun = 0.0
	p._strike(e, 10.0, Vector2.RIGHT, 0.0, false)
	_check(lion > 12.0 and goat_stun > 0.0 and e.venom > 0, "Triune Fang: the lion bites harder (%.1f), the goat staggers, the serpent poisons" % lion)
	e.queue_free()
	# Wyrmspine Mace: a heavy blow cracks the floor.
	p.take_gear(G.make_named("wyrmspine_mace"))
	p._equip("mace")
	var a = await t._dummy(p.global_position + Vector2(40, 0))
	var b = await t._dummy(p.global_position + Vector2(100, 30))
	p._strike(a, 10.0, Vector2.RIGHT, 0.0, true)
	_check(b.hp < 999.0 and b.stun > 0.0, "Wyrmspine Mace: a heavy blow hurts and staggers the foes near the one you hit")
	a.queue_free()
	b.queue_free()
	# Spinecaster: barbs beside the bolt, and they poison.
	p.take_gear(G.make_named("spinecaster"))
	p._equip("crossbow")
	await t._frames(2)
	var before: int = m.get_children().size()
	p.attack_cd = 0.0
	p._fire_bolt()
	_check(m.get_children().size() - before >= 3, "Spinecaster: each bolt looses two barbs beside it")
	var v = await t._dummy(p.global_position + Vector2(300, 200))
	p.ranged_hit(v, 2.0, Vector2.RIGHT, 0.0, false)
	_check(v.venom >= 2, "...and every barb poisons")
	v.queue_free()
	# Stormtalon: arcs on to two more foes.
	p.take_gear(G.make_named("stormtalon"))
	p._equip("longbow")
	var s0 = await t._dummy(p.global_position + Vector2(200, 0))
	var s1 = await t._dummy(p.global_position + Vector2(260, 0))
	var s2 = await t._dummy(p.global_position + Vector2(320, 0))
	p.ranged_hit(s0, 20.0, Vector2.RIGHT, 0.0, true)
	_check(s1.hp < 999.0 and s2.hp < 999.0, "Stormtalon: a full draw arcs on to two more foes")
	for x in [s0, s1, s2]:
		x.queue_free()
	# Deepcoil Coat: grips a foe that strikes you; ink when low.
	p.take_gear(G.make_named("deepcoil_coat"))
	_check(absf(G.armor(p.gear["armor"])["reduce"] - 0.24) < 0.001, "Deepcoil Coat: 24% off a blow")
	var k = await t._spawn("knight", p.global_position + Vector2(40, 0))
	p.hp = p.max_health()
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.parry_t = 0.0
	var smokes0: int = m.smokes.size()
	p.hp = p.max_health() * 0.55
	p.receive_attack(20.0, k)
	_check(k.chill_t > 0.0, "...a foe that strikes you is gripped and slowed")
	_check(m.smokes.size() > smokes0, "...and falling below half health bursts a cloud of ink")
	k.queue_free()
	# Sunplume Mantle: once a climb you rise again.
	p.take_gear(G.make_named("sunplume_mantle"))
	p.rebirth_used = false
	p.hp = 5.0
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.parry_t = 0.0
	p.receive_attack(999.0, null)
	_check(not p.dead and p.hp >= p.max_health() * 0.39, "Sunplume Mantle: a killing blow and you rise with 40%% of your health (%.0f)" % p.hp)
	_check(p.rebirth_used, "...once a climb")


func _icons() -> void:
	print("gear and items: icons")
	var empty: Array = []
	var ids: Array = []
	for id in NEW_ITEMS:
		for s in [10.5, 18.0, 40.0]:
			var b = D.Batch.new()
			I.icon_into(b, id, Vector2.ZERO, s)
			if b.pts.is_empty() or b.pts.size() != b.cols.size():
				empty.append("%s@%s" % [id, s])
	for id in NEW_PIECES:
		for s in [10.5, 18.0, 40.0]:
			var b = D.Batch.new()
			G.icon_into(b, G.make(id), Vector2.ZERO, s, G.color(id))
			if b.pts.is_empty() or b.pts.size() != b.cols.size():
				empty.append("%s@%s" % [id, s])
	for n in G.NAMED_ORDER:
		for s in [10.5, 18.0, 40.0]:
			var b = D.Batch.new()
			var g := G.make_named(n)
			G.icon_into(b, g, Vector2.ZERO, s, G.color(g))
			if b.pts.is_empty() or b.pts.size() != b.cols.size():
				empty.append("%s@%s" % [n, s])
	_check(empty.is_empty(), "every new item, piece and named piece draws at HUD, slot and card size %s" % [empty])
	# A named piece looks like itself, not its base.
	var differ: Array = []
	for n in G.NAMED_ORDER:
		var g := G.make_named(n)
		var plain := G.make(g["base"], g["rarity"], g["traits"])
		var a = D.Batch.new()
		var b = D.Batch.new()
		G.icon_into(a, g, Vector2.ZERO, 18.0, G.color(g))
		G.icon_into(b, plain, Vector2.ZERO, 18.0, G.color(plain))
		if a.pts.size() == b.pts.size() and a.cols == b.cols:
			differ.append(n)
	_check(differ.is_empty(), "every named piece has its own icon, not just its base's %s" % [differ])
	var reg = D.Batch.new()
	var sto = D.Batch.new()
	G.icon_into(reg, G.make("sword", "regarded"), Vector2.ZERO, 18.0, Color.WHITE)
	G.icon_into(sto, G.make("sword", "storied"), Vector2.ZERO, 18.0, Color.WHITE)
	_check(reg.pts.size() > sto.pts.size(), "a Regarded piece's glow carries its own gold rays")
