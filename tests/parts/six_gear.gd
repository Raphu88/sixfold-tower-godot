extends RefCounted
## Counts by sixes on the gear side (the owner's rule: every list the player
## collects or chooses from divides by six, or is exactly three): weapons,
## chest pieces, worn pieces, charms, the off-hand, belt items, tinctures,
## traits and rarities. Then the pieces added to round them up each do their
## own thing: the rapier's riposte, the flail through a shell, the sling's
## stone, the Warded Robe and Scale Mail, the Dancer's Slippers and Falcon
## Pendant, four charms (two with new charges), three items, four traits and
## the Masterwork rarity (slow: never below its floor). A long name in the
## store's list keeps every letter. The Entity explains them; no banned words.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const G := preload("res://scripts/gear.gd")
const W := preload("res://scripts/weapons.gd")
const C := preload("res://scripts/charms.gd")
const I := preload("res://scripts/items.gd")
const Flow := preload("res://scripts/essence_flow.gd")
const Train := preload("res://scripts/train.gd")
const Shop := preload("res://scripts/shop.gd")
const Bench := preload("res://scripts/bench.gd")
const Entity := preload("res://scripts/entity.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const UI := preload("res://scripts/ui.gd")
const Menu := preload("res://scripts/menu.gd")
const D := preload("res://scripts/draw_util.gd")

const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]
const NEW_WEAPONS := ["rapier", "flail", "sling"]
const NEW_ARMOR := ["robe", "scale"]
const NEW_PIECES := ["dancers_slippers", "falcon_pendant"]
const NEW_CHARMS := ["hunters_token", "brass_bellows", "duelists_ribbon", "mist_pearl"]
const NEW_ITEMS := ["thunder_jar", "springheel", "stillwater"]
const NEW_TRAITS := ["finishing", "grace", "cleansing", "zeal"]

var t


func run(smoke) -> void:
	t = smoke
	print("six_gear: gear and items count by sixes")
	await t._fresh_main()
	_counts()
	_placed()
	await _weapons()
	_armor_and_pieces()
	_charms()
	await _items()
	_traits()
	_masterwork()
	await _long_names()
	_words()


static func _sixes(n: int) -> bool:
	return n == 3 or (n > 0 and n % 6 == 0)


func _counts() -> void:
	var pieces: Array = G.PIECE_ORDER.filter(func(id): return not (G.PIECES[id]["slot"] in ["charm", "offhand"]))
	var belt: Array = I.ORDER.filter(func(id): return id != "scroll" and id != "vessel" and not Flow.is_tincture(id))
	var counts := {
		"weapons (fists among them)": W.ORDER.size(),
		"chest pieces": G.ARMOR_ORDER.filter(func(a): return a != "").size(),
		"worn pieces": pieces.size(),
		"charms": C.all().size(),
		"off-hand pieces": G.PIECE_ORDER.filter(func(id): return G.PIECES[id]["slot"] == "offhand").size(),
		"belt items": belt.size(),
		"tinctures": Flow.tinctures().size(),
		"traits": G.TRAIT_ORDER.size(),
		"rarities": G.RARITY_ORDER.size(),
		"lasting runes": G.LASTING_RUNES.size(),
	}
	var off: Array = []
	for k in counts:
		if not _sixes(int(counts[k])):
			off.append("%s %d" % [k, counts[k]])
	t._check(off.is_empty(), "every gear and item list counts by sixes, or is exactly three (%s; off: %s)" % [counts, off])
	t._check(W.ORDER.size() == W.WEAPONS.size() and G.TRAIT_ORDER.size() == G.TRAITS.size() and G.RARITY_ORDER.size() == G.RARITIES.size()
		and G.ARMOR_ORDER.size() == G.ARMOR.size() and G.PIECE_ORDER.size() == G.PIECES.size() and I.ORDER.size() == I.ITEMS.size(),
		"...and every list's order names each of its entries once")


## Each new piece is priced, drops or is sold like its peers, and draws.
func _placed() -> void:
	var bad: Array = []
	for id in NEW_WEAPONS + NEW_ARMOR + NEW_PIECES + NEW_CHARMS:
		if not Train.BASE_PRICE.has(id):
			bad.append(id + ": no price")
		var b := D.Batch.new()
		G.icon_into(b, id, Vector2.ZERO, 18.0, G.color(id))
		if b.pts.is_empty():
			bad.append(id + ": no icon")
		if String(G.info(id).get("desc", "")) == "":
			bad.append(id + ": no words")
	for id in NEW_WEAPONS:
		if int(G.WEAPON_DROP_WEIGHT.get(id, 0)) <= 0:
			bad.append(id + ": never dropped")
	for id in NEW_ARMOR + NEW_PIECES:
		if G.drop_weight(id) <= 0 or G.drop_weight(id) == 99:
			bad.append(id + ": never dropped")
	for id in NEW_CHARMS:
		if not C.CRAFT.has(id):
			bad.append(id + ": no recipe")
	for id in NEW_ITEMS:
		var d: Dictionary = I.ITEMS[id]
		if int(d.get("drop_weight", 0)) <= 0 or d.get("value", {}).is_empty() or not Bench.BREW.has(id) or not Shop.SHELF_RANK.has(id) or not I.USE_SOUNDS.has(id):
			bad.append(id + ": not found, sold, brewed or heard like its peers")
		var b := D.Batch.new()
		I.icon_into(b, id, Vector2.ZERO, 18.0)
		if b.pts.is_empty():
			bad.append(id + ": no icon")
	t._check(bad.is_empty(), "every new piece and item is priced, found, sold or crafted like its peers, and drawn (%s)" % [bad])
	t._check(C.of_rarity("common").has("hunters_token") and C.of_rarity("fine").has("brass_bellows") and C.LOCKED.has("duelists_ribbon") and C.LOCKED.has("mist_pearl"),
		"the new charms: a Common one for the rail, a Fine one, two Rare recipes a contract teaches")


func _weapons() -> void:
	var m = t.main
	var p = m.player
	p.global_position = Vector2(500, 400)
	for id in NEW_WEAPONS:
		p.take_gear(G.make(id))
	# The rapier: a riposte (a staggered foe) bites 40% deeper than a sword's.
	var hurt := {}
	for id in ["sword", "rapier"]:
		p.take_gear(G.make(id))
		p._equip(id)
		var d = await t._dummy(p.global_position + Vector2(30, 0))
		d.stun = 1.0
		p._strike(d, 10.0, Vector2.RIGHT, 0.0, false, "hit")
		hurt[id] = 999.0 - d.hp
		d.queue_free()
		await t._frames(1)
	t._check(absf(hurt["rapier"] / maxf(hurt["sword"], 0.01) - 1.4) < 0.02, "a rapier's riposte bites 40%% deeper than a sword's (%s)" % [hurt])
	# The flail: a shellback's shell turns a sword from the front, not a flail.
	var shell := {}
	for id in ["sword", "flail"]:
		p.take_gear(G.make(id))
		p._equip(id)
		var e = await t._spawn("shellback", p.global_position + Vector2(40, 0))
		e.hp = 999.0
		e.max_hp = 999.0
		e.face = Vector2.LEFT
		p._strike(e, 10.0, Vector2.RIGHT, 0.0, false, "hit")
		shell[id] = 999.0 - e.hp
		e.queue_free()
		await t._frames(1)
	t._check(shell["flail"] > shell["sword"] * 3.0, "a flail's blows go through a shellback's shell; a sword's are turned (%s)" % [shell])
	# The sling: a full whirl throws a stone that rocks and never pierces.
	p.take_gear(G.make("sling"))
	p._equip("sling")
	p.sta = p.max_sta
	p.drawing = true
	p.draw_t = float(W.WEAPONS["sling"]["draw_time"])
	var before: Array = m.get_children()
	p.release_draw()
	var stone = null
	for c in m.get_children():
		if not (c in before) and "style" in c and String(c.style) == "stone":
			stone = c
	t._check(stone != null and not stone.pierce and stone.heavy and W.is_ranged("sling") and G.slot_of("sling") == "ranged",
		"a sling's full whirl throws a stone that rocks (heavy) and doesn't pierce")
	if stone != null:
		stone.queue_free()
	t._check(W.WEAPONS["rapier"]["class"] == "light" and not load("res://scripts/offhand.gd").two_handed("rapier") and not load("res://scripts/offhand.gd").two_handed("flail")
		and load("res://scripts/offhand.gd").two_handed("sling"), "the rapier and flail leave the off hand free; the sling needs both hands, like a bow")
	p._equip("sword")


func _armor_and_pieces() -> void:
	var robe := G.effects(G.make("robe"))
	var scale := G.effects(G.make("scale"))
	t._check(is_equal_approx(float(robe.get("spell", 0.0)), 0.06) and bool(scale.get("steady", false)), "the Warded Robe's spells and Scale Mail's steady footing count as worn")
	t._check(G.ARMOR["chain"]["reduce"] < G.ARMOR["scale"]["reduce"] and G.ARMOR["scale"]["reduce"] < G.ARMOR["plate"]["reduce"]
		and G.ARMOR["robe"]["reduce"] < G.ARMOR["padded"]["reduce"], "Scale Mail sits between mail and plate; the robe is the lightest chest piece")
	var tot := G.total_effects({"boots": G.make("dancers_slippers"), "amulet": G.make("falcon_pendant")})
	t._check(float(tot.get("parry", 0.0)) > 0.0 and float(tot.get("roll_recover", 0.0)) > 0.0 and float(tot.get("ranged", 0.0)) > 0.0 and float(tot.get("draw", 0.0)) > 0.0
		and G.natural_rarity("falcon_pendant") == "fine", "the Dancer's Slippers lengthen the parry and quicken the roll; the Falcon Pendant (Fine) helps bows")


func _charms() -> void:
	var p = t.main.player
	p.gear["charm"] = G.make("brass_bellows")
	p.refresh_gear()
	p.sta = 4.0
	p.spend_sta(30.0, true)
	t._check(absf(p.sta - p.sta_cap() * 0.5) < 0.6 and C.charges(p.gear["charm"]) == 1, "Brass Bellows: running dry fills half your stamina back, a charge spent (%.1f)" % p.sta)
	p.gear["charm"] = G.make("mist_pearl")
	p.refresh_gear()
	p.hp = p.max_health()
	var was: int = t.main.smokes.size()
	p._charm_struck()
	var high: int = t.main.smokes.size()
	p.hp = p.max_health() * 0.3
	p._charm_struck()
	t._check(high == was and t.main.smokes.size() == was + 1 and C.charges(p.gear["charm"]) == 1, "Mist Pearl: struck while low, mist wraps you (not while healthy)")
	p.gear["charm"] = G.make("duelists_ribbon")
	p.refresh_gear()
	t._check(p.gfx("riposte") >= 0.15 and p.gfx("parry") >= 0.05, "Duelist's Ribbon: ripostes and the parry")
	p.gear["charm"] = {}
	p.refresh_gear()
	p.hp = p.max_health()


func _items() -> void:
	var m = t.main
	var p = m.player
	I.use("springheel", p)
	t._check(p.gfx("free_jump") > 0.0 and is_equal_approx(p.gfx("jump"), 0.4), "a Springheel Draught: free, longer jumps for a while")
	I.use("stillwater", p)
	t._check(p.gfx("parry") >= 0.4 and p.gfx("parry_heal") >= 4.0, "a Stillwater Draught: a longer parry, and a perfect one heals")
	p.buffs.clear()
	var d = await t._dummy(p.global_position + Vector2(120, 0))
	d.stun = 0.0
	I.burst(m, {"to": d.global_position, "r": 58.0, "id": "thunder_jar", "dmg": 14.0})
	t._check(999.0 - d.hp > 5.0 and d.stun > 0.0, "a Thunder Jar's burst hurts and stuns the foes it catches (%.1f, stun %.2f)" % [999.0 - d.hp, d.stun])
	d.queue_free()
	await t._frames(1)


func _traits() -> void:
	var bad: Array = []
	for tr in NEW_TRAITS:
		var d: Dictionary = G.TRAITS[tr]
		var slot: String = d["slots"][0]
		var base: String = {"melee": "sword", "gloves": "leather_gloves", "cloak": "travel_cloak", "ring": "iron_band"}.get(slot, "sword")
		var fx := G.effects(G.make(base, "rare", [tr]))
		var key := String(d["key"])
		if float(fx.get(key, 0.0)) < float(d["rare"]) - 0.001 and not (base == "travel_cloak"):
			bad.append(tr)
		if base == "travel_cloak" and float(fx.get(key, 0.0)) < 0.25 + float(d["rare"]) - 0.001:
			bad.append(tr)
	t._check(bad.is_empty(), "the four new traits add to their numbers on a piece (%s)" % [bad])
	t._check(["melee", "gloves", "ring", "amulet", "cloak", "armor", "helm", "boots", "legs", "ranged", "offhand"].all(func(s): return G.traits_for(s).size() >= 4),
		"every slot but the backpack still has four traits or more")


func _masterwork() -> void:
	t._check(G.RARITY_ORDER.find("masterwork") == G.RARITY_ORDER.find("rare") + 1 and G.RARITY_ORDER.find("storied") == G.RARITY_ORDER.find("masterwork") + 1,
		"Masterwork sits between Rare and Storied")
	var mw := G.make("sword", "masterwork", G.roll_traits("sword", "masterwork"))
	t._check(mw["traits"].size() == 3 and not G.wears(mw) and G.weapon_boost(mw) > G.weapon_boost(G.make("sword", "rare")), "a Masterwork piece carries three traits, never wears, and hits a little harder than a Rare one")
	var price_ok: bool = Train.RARITY_PRICE["rare"] < Train.RARITY_PRICE["masterwork"] and Train.RARITY_PRICE["masterwork"] < Train.RARITY_PRICE["storied"]
	t._check(price_ok and Bench.TEMPER_RARITY.has("masterwork") and load("res://scripts/icon_art.gd").RARITY_GLOW.has("masterwork"), "...priced, tempered and glowing between Rare and Storied")
	# Slow growth: none below MASTERWORK_FROM (even a vault's higher roll), and seldom above.
	var low := false
	for f in [1, 4, 7, 9]:
		for k in 120:
			low = low or G.roll_rarity(f, 1) == "masterwork"
	var most := 0
	for row in G.RARITY_ODDS:
		var total := 0
		for r in row["odds"]:
			total += int(row["odds"][r])
		most = maxi(most, int(round(100.0 * int(row["odds"].get("masterwork", 0)) / maxf(total, 1.0))))
	t._check(not low and most <= 5 and G.MASTERWORK_FROM >= 10, "Masterwork is never found below floor %d, and at most %d in 100 finds above it" % [G.MASTERWORK_FROM, most])
	t._check(Shop.make_piece(null, "sword")["rarity"] != "masterwork", "the outfitter's rail doesn't hang Masterwork pieces")


## A long name in the store's list (a row) keeps every letter: smaller, then wrapped.
func _long_names() -> void:
	var root := Control.new()
	root.size = Vector2(400, 200)
	t.root.add_child(root)
	var s = Menu.Slot.new()
	s.kind = "gear"
	s.rec = G.make("plated_greaves", "masterwork", ["second_wind", "vigor", "wind"], 3)
	s.id = "plated_greaves"
	s.line = G.display(s.rec)
	s.price = 288
	s.price_kind = "iron"
	s.better = 1
	s.tag = "Best"
	s.position = Vector2(10, 10)
	s.size = Vector2(250, 36)
	root.add_child(s)
	await t._frames(2)
	UI.text_notes = []
	s.queue_redraw()
	await t._frames(2)
	var notes: Array = UI.text_notes
	UI.text_notes = null
	var cut: Array = notes.filter(func(n): return int(n.get("cut", 0)) > 0 or float(n.get("need", 0.0)) > float(n.get("room", 0.0)) + 0.5 and float(n.get("room", -1.0)) >= 0.0)
	var drew: bool = notes.any(func(n): return String(n.get("text", "")) == s.line)
	t._check(drew and cut.is_empty(), "a long name in the store's list (\"%s\") keeps every letter (%s)" % [s.line, cut.map(func(n): return n["text"])])
	root.queue_free()
	await t._frames(1)


func _words() -> void:
	var texts: Array = []
	for id in NEW_WEAPONS:
		texts.append(String(W.WEAPONS[id]["desc"]))
	for id in NEW_ARMOR + NEW_PIECES + NEW_CHARMS:
		texts.append(String(G.info(id)["desc"]))
	for id in NEW_ITEMS:
		texts.append(String(I.ITEMS[id]["desc"]))
	for tr in NEW_TRAITS:
		texts.append(String(G.TRAITS[tr]["desc"]))
	for k in ["breath", "veil"]:
		texts.append(String(C.CHARGES[k]["desc"]))
	var tips_ok := true
	for k in ["masterwork", "rapier", "flail", "sling"]:
		tips_ok = tips_ok and Entity.TIPS.has(k) and String(Entity.TIPS[k].get("tip", "")) != "" and String(Entity.TIPS[k].get("more", "")) != ""
		texts.append(JSON.stringify(Entity.TIPS.get(k, {})))
	texts.append(JSON.stringify(Talk.DIALOGUE.get("how_gear", {})))
	t._check(tips_ok and Talk.DIALOGUE.has("how_gear") and Array(Talk.DIALOGUE["how"]["choices"]).has("how_gear"),
		"the Entity explains Masterwork, the rapier, the flail and the sling (tips), and how weapons and rarities work (a talk topic)")
	var found: Array = []
	var re := RegEx.create_from_string("\\b(" + "|".join(BANNED) + ")\\b")
	for txt in texts:
		for hit in re.search_all(String(txt).to_lower()):
			found.append(hit.get_string(1))
	t._check(found.is_empty(), "no banned words in the new gear's text (%s)" % [found])
