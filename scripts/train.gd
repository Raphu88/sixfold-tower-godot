extends RefCounted
## The train: a steampunk train that waits outside the towers. You reach it
## after every climb (survived, fallen or recalled) and leave it for the
## next tower, but only once the Regard has found you: the first climb is
## bondless, and the train appears with the Regard.
##
## You walk along it from the inside (menu.gd's "train" page: train_view.gd
## draws the cars, train_page.gd puts their things in them). Its cars, front
## to back (the owner's order):
##   engine    the cab: choose the next tower on its board, pull the lever
##   store     the Outfitter's Car: supplies, an outfit, today's piece, and
##             selling what you brought down
##   personal  your own car: your heirlooms, your pack and a storage chest
##   workshop  the workshop car: the bench (bench.gd): brewing for anyone,
##             enchanting for a Rune Artist, and breaking things down
##   library   the Library: the Entity's Archive on its shelves, read at a
##             lectern (and the Makers' forbidden shelf)
##   settings  the Settings & Controls Car: a signal room whose panel holds
##             the settings and the controls list, and Start over
##
## Essence crystals are the only currency (profile.gd keeps them as
## {kind, amount}, one crystal of each kind). Every price is in one kind of
## essence. Crystals come from condensing at every stair (CONDENSE_*), the
## outfitter's pay for every climb (CLIMB_PAY), selling, and prizes. Names, words,
## prices and numbers live here so they're easy to change.

const Gear := preload("res://scripts/gear.gd")
const Items := preload("res://scripts/items.gd")
const Essence := preload("res://scripts/essence.gd")
const VESSEL := "res://scripts/vessel.gd"  # (loaded when needed: vessel.gd preloads the bench, which preloads this)

## The cars, front to back: [id, name]. The train opens on HOME. (Their short
## names on a phone, and the line under each on a computer, are rail.gd
## TRAIN_CARS.)
const CARS := [["engine", "Engine"], ["store", "Outfitter's Car"], ["personal", "Your Car"], ["workshop", "Workshop"],
	["library", "Library"], ["settings", "Settings & Controls Car"]]
const HOME := "personal"

## Your storage chest (in your car): pieces kept safe between climbs.
const CHEST_SIZE := 8
## Selling (or breaking down at the bench, bench.gd) gives back this share of
## a thing's price, as a crystal of its kind. A worn Common piece fetches
## less, down to WORN_SELL of that.
static var SELL_SHARE := 0.4
static var WORN_SELL := 0.25
## How many Common pieces hang on the outfitter's rack each visit.
const RACK_SIZE := 8
## Today's piece: one Fine or Rare piece, new after every climb.
static var TODAY_ODDS := {"fine": 75, "rare": 25}

## A piece's base price: what it costs at the store (and sells from) is this
## times its rarity's RARITY_PRICE. Rings, amulets and the Climber's Pack are
## never Common: their number here is what a plain one would cost.
static var BASE_PRICE := {
	"dagger": 10, "sword": 12, "axe": 12, "mace": 12, "spear": 12, "greatsword": 15, "war_hammer": 15,
	"shortbow": 12, "longbow": 14, "crossbow": 15,
	"padded": 8, "leather": 12, "chain": 16, "plate": 20,
	"cloth_hood": 8, "leather_cap": 10, "iron_helm": 14, "grip_wraps": 10, "leather_gloves": 10, "gauntlets": 14,
	"padded_trousers": 8, "leather_leggings": 10, "chain_leggings": 14, "soft_boots": 10, "climbing_boots": 10, "hobnail_boots": 12,
	"travel_cloak": 8, "dusk_cloak": 12, "satchel": 12, "belt_pouch": 15,
	"bone_charm": 12, "ember_charm": 12, "iron_band": 12, "garnet_ring": 12, "tide_locket": 12, "pearl_ring": 12,
	"overdrawn_ring": 12, "climbers_pack": 12,
	"feathered_cap": 10, "miners_helm": 12, "archers_bracers": 10, "studded_gloves": 12, "ranger_breeches": 10, "plated_greaves": 15,
	"wading_boots": 11, "feather_cape": 11, "herb_pouch": 12, "wolf_tooth": 12, "sunstone_pendant": 12, "silver_ring": 12, "jade_ring": 12,
	"viper_ring": 12, "bandolier": 14,
}
static var DEFAULT_PRICE := 10
## Commons are the everyday buy, at half their base price (the owner's call:
## "I can never afford anything"); Fine and up kept their prices, so a Fine
## piece costs 4x its Common and finds still sell well. A beast's Regarded
## piece is the dearest of all (it sells for the most).
static var RARITY_PRICE := {"common": 0.5, "fine": 2.0, "rare": 4.0, "storied": 8.0, "regarded": 14.0}
## Basic supplies cost half their worth (items.gd "value") at the store;
## everything else costs its worth. (A belt left over at the end of a climb
## still breaks into crystals at half its worth.)
static var SUPPLY_PRICE := {"draught": 6, "tonic": 5, "smoke": 5, "salts": 5, "flare": 4}
## Supplies priced in crystal essence of ANY kind (the owner's call: "recall
## scrolls should take any kind of essence and always be available"). The
## recall scroll is always on the shelf, and buying one never empties it
## (you carry one at most). Paid from your biggest crystals first
## (profile.gd spend_any).
const ANY := "any"
static var ANY_PRICE := {"scroll": 60}

## Condensing (at every stair, the first climb's too): this share of the
## essence you bank becomes essence crystals instead of soaking into you,
## per kind and in proportion (whole essence only: a kind with too little
## for one whole essence is banked in full). Crystals are the train's money.
## Settings changes the share (CONDENSE_CHOICES, in percent); it's kept with
## the settings (menu.gd), so a new climber keeps it.
const CONDENSE_DEFAULT := "20"
const CONDENSE_CHOICES := [["0", "0%"], ["10", "10%"], ["20", "20%"], ["35", "35%"], ["50", "50%"]]
## The outfitter's pay for a climb, however it ends (a fall too): crystals of
## the tower's kind, PER_FLOOR for every floor reached and PER_BEST more for
## every floor past your best in that tower before the climb.
static var CLIMB_PAY := {"per_floor": 2, "per_best": 3}
## The essence a piece is priced in and sells for, when it has no trait (or
## name) to say: by its slot.
const SLOT_KIND := {
	"armor": "stone", "helm": "stone", "gloves": "blade", "melee": "blade", "legs": "iron", "ranged": "iron",
	"boots": "air", "cloak": "air", "amulet": "fire", "ring": "water", "backpack": "iron",
}

## The words of the train's pages.
static var TEXT := {
	"title": "THE TRAIN",
	"sub": "Brass, steam and the smell of oil. The towers wait past the windows.",
	"purse": "Your crystals",
	"home": "Your pack comes down with you: %d %s",
	"money": "The outfitter prices everything in one kind of essence, and takes it from your crystal of that kind.",
	"needs": "needs %d more %s",
	"price": "%d %s",
	"price_any": "%d of any kind",
	"needs_any": "needs %d more essence, of any kind",
	"any_note": "Paid from your crystals of any kind, the biggest first.",
	"paid_with": "paid %s",
	"buy": "Buy",
	"bought": "Bought: %s",
	"cant": "Can't buy: %s",
	# Your car
	"personal_sub": "Your heirlooms, and a chest for what you want to keep.",
	"chest": "Storage chest  ·  %d of %d",
	"pack": "Your pack  ·  %d of %d",
	"heirlooms": "Heirlooms",
	"view_chest": "Chest",
	"view_heirlooms": "Heirlooms",
	"chest_empty": "An empty space in your chest. Pieces kept here are safe between climbs, and never wear.",
	"pack_empty": "An empty space in your pack. Your pack goes up the tower with you: fall, and what's in it is lost.",
	"in_chest": "In your storage chest: safe between climbs.",
	"in_pack": "In your pack: it goes up the tower with you, and you put it on as you enter if its slot is free (or holds only the starting sword or bow).",
	"to_chest": "Into the chest",
	"to_pack": "Into your pack",
	"moved_chest": "Into the chest: %s",
	"moved_pack": "Into your pack: %s",
	"chest_full": "your chest is full",
	"pack_full": "your pack is full",
	"sell_for": "Sell for %d %s",
	"sell_ask": "{again} to sell for %d %s",
	"sold": "Sold: %s for %s",
	# Store car
	"store_sub": "Kept by the outfitter. He buys what climbers bring down, and sells it to the next ones up.",
	"supplies_note": "Supplies are packed onto your belt for your next climb, beside the draught every climb starts with.",
	"packed": "Packed for your next climb: %d  ·  your belt holds %d",
	"belt_full": "your belt can't hold more",
	"put_back": "Put one back (what you paid comes back)",
	"put_back_done": "Put back: %s",
	"outfit_note": "Common pieces for your next climb. What you buy goes in your pack, and you wear it as you enter if its slot is free.",
	"today_note": "One finer piece, new after every climb.",
	"today_sold": "Sold. Another piece comes after your next climb.",
	"sell_note": "What you brought down in your pack, and what's in your chest. Each sells for a crystal of its kind, at %d%% of its price.",
	"nothing_to_sell": "Nothing to sell. Bring finds home in your pack: survive a climb, or read a recall scroll.",
	"against": "Against what you'd start with",
	"shelves": "Supplies",
	"rail": "Outfit",
	"case": "Today's piece",
	"sell_sign": "Sell to the outfitter",
	"sell_short": "Sell",
	"sell_title": "What you brought down",
	"back_to_shelves": "Back to the shelves",
	"back_short": "The shelves",
	# Your car: the mirror (the climber screen) and the travelling trunk (the inventory)
	"mirror": "Climber",
	"mirror_short": "Climber",
	"trunk": "Inventory",
	"trunk_short": "Inventory",
	"looks": "Appearance",  # how you look (appearance_page.gd)
	"looks_short": "Looks",
	"techniques": "Techniques",  # the Unbound's (technique_page.gd)
	# The engine: where you choose the next tower
	"depart_title": "CHOOSE A TOWER",
	"depart_sub": "Each tower's monsters and essence shape the marks you'll form.",
	"lever": "DEPART",
	"lever_for": "for the %s",
	"next_climb": "Your next climb",
	"best": "Your best: floor %d",
	"never": "Not climbed yet",
	"essence": "%s essence",
	"pull": "Pull the lever to depart.",
	"depart_pack": "Going with you: %s.",
	"depart_none": "nothing in your pack",
	"depart_risk": "Fall, and your pack and belt are lost; your chest, heirlooms and crystals are safe.",
	"last": "last climbed",
	# Condensing at the stair (main.gd _arrive), its setting, and the outfitter's pay for a climb
	"banked": "Banked %d essence",
	"condensed": "%d condensed into crystals",
	"condense_setting": "To crystals",
	"condense_note": "At each stair this share of the essence you bank condenses into crystals (the train's money) instead of growing your marks.",
	"pay": "The outfitter pays for your climb: +%s",
	# The Library: the Entity's Archive on its shelves, read at the lectern
	"bookcase": "The Entity's Archive  ·  %s",
	"bookcase_short": "Archive  ·  %s",
	"lectern": "The lectern",
	"lectern_empty": "Choose a shelf, then a subject to read it here.",
	"shelf_heard": "%d of %d heard",
	"forbidden": "Forbidden shelf",
	# The Settings & Controls Car: the signal panel and the emergency brake
	"panel_settings": "Settings",
	"panel_controls": "Controls",
	"brake": "Emergency brake",
	"over": "Start over this climber",
	"over_short": "Start over",
	"over_note": "Wipes this climber's slot and begins a new one (the other climbers are kept). It asks first.",
}

## The outfitter who keeps the store car: a retired climber who buys what
## climbers bring down and sells it to the next ones up. No name yet: change
## "name" and "tag" to give him one. One line is picked for each moment.
static var OUTFITTER := {
	"name": "the outfitter",
	"tag": "THE OUTFITTER",
	"greet": [
		"Back down in one piece. Mostly.",
		"Everything on this rack came down a tower on someone's back.",
		"I climbed once. Kept the boots. Sold the rest.",
		"Look all you like. Looking's free. The rest isn't.",
		"Essence spends the same, whichever tower it came out of.",
	],
	"bought": [
		"A fair trade. Don't tell anyone.",
		"Wear it well. Bring it back if you don't.",
		"That one's been up a tower before. It knows the way.",
	],
	"sold": [
		"I'll find it a new climber.",
		"Into the crate it goes.",
		"Someone will want that. Someone always does.",
	],
	"poor": [
		"Come back with more essence. I'll keep it on the rack. For a while.",
		"Essence first, then we talk.",
	],
	"put_back": ["Changed your mind? Your essence back, then."],
	# His greeting while a climb's pay is fresh (%s is what he paid: "14 Water").
	"paid": [
		"Your pay for the climb: %s. A floor's a floor, even on the way down.",
		"%s for your climb. I pay by the floor, not by how it ended.",
	],
}


static func line(key: String, seed := -1) -> String:
	var list: Array = OUTFITTER.get(key, [""])
	return list[randi() % list.size() if seed < 0 else posmod(seed, list.size())]


# --- prices -------------------------------------------------------------------------

## The essence a piece is priced in: a named piece's own, else its first
## trait's, else its slot's (SLOT_KIND).
static func gear_kind(g) -> String:
	var r := Gear.rec(g)
	var n := Gear.named_id(r)
	if Gear.NAMED.has(n):
		return String(Gear.NAMED[n]["kind"])
	for t in r.get("traits", []):
		if Gear.TRAITS.has(String(t)):
			return String(Gear.TRAITS[t]["kind"])
	return String(SLOT_KIND.get(Gear.slot_of(r), "iron"))


## What a piece costs at the store: its base price times its rarity's.
static func gear_price(g) -> int:
	var r := Gear.rec(g)
	if r.is_empty():
		return 0
	return maxi(1, int(round(float(BASE_PRICE.get(r["base"], DEFAULT_PRICE)) * float(RARITY_PRICE.get(r["rarity"], 1.0)))))


## What a piece sells for: SELL_SHARE of its price (less for a worn Common
## piece), at least 1.
static func gear_sell(g) -> int:
	var r := Gear.rec(g)
	if r.is_empty():
		return 0
	var k := maxf(Gear.condition(r), WORN_SELL)
	return maxi(1, int(round(float(gear_price(r)) * SELL_SHARE * k)))


## A consumable's price: [kind, amount] (its worth in items.gd, or a basic
## supply's SUPPLY_PRICE).
static func item_price(id: String) -> Array:
	var d: Dictionary = Items.ITEMS.get(id, {})
	var v: Dictionary = d.get("value", {})
	if v.is_empty():
		return ["", 0]
	if ANY_PRICE.has(id):
		return [ANY, int(ANY_PRICE[id])]
	var kind := String(d.get("kind", v.keys()[0]))
	return [kind, int(SUPPLY_PRICE.get(id, v.get(kind, 0)))]


## What a packed consumable gives back when there's no note of what was paid
## ({kind: amount}): its price, or for one priced in any kind (which can't be
## a crystal), its worth in its own kind.
static func item_refund(id: String) -> Dictionary:
	var price := item_price(id)
	if price[0] != ANY:
		return {price[0]: price[1]}
	var v: Dictionary = Items.ITEMS.get(id, {}).get("value", {})
	return {String(Items.ITEMS[id].get("kind", v.keys()[0])): price[1]} if not v.is_empty() else {}


## What a packed consumable breaks down into at the bench: [kind, amount]
## (SELL_SHARE of its price, in its own kind).
static func item_sell(id: String) -> Array:
	var back := item_refund(id)
	if back.is_empty():
		return ["", 0]
	var kind: String = back.keys()[0]
	return [kind, maxi(1, int(round(float(back[kind]) * SELL_SHARE)))]


# --- condensing and the outfitter's pay ------------------------------------------------

## The share of banked essence that condenses into crystals at a stair (0 to
## 1), from the settings (menu.gd: "condense", in percent).
static func condense_share(settings: Dictionary) -> float:
	var pct := str(settings.get("condense", CONDENSE_DEFAULT))
	if not CONDENSE_CHOICES.any(func(c): return c[0] == pct):
		pct = CONDENSE_DEFAULT
	return clampf(float(pct) / 100.0, 0.0, 1.0)


## What the outfitter pays for a climb that reached `reached` in a tower whose
## best floor before the climb was `best_before` (essence of the tower's kind).
static func climb_pay(reached: int, best_before: int) -> int:
	reached = maxi(reached, 0)
	return int(CLIMB_PAY["per_floor"]) * reached + int(CLIMB_PAY["per_best"]) * maxi(0, reached - maxi(best_before, 0))


## The consumables the store sells: always the same shelf, in Items.ORDER
## (the recall scroll among them, always there; only the outfit rail and
## today's piece change between visits).
static func supplies() -> Array:
	return Items.ORDER.filter(func(id): return not Items.ITEMS[id].get("value", {}).is_empty())


## Why a price can't be paid, in words ("needs 12 more Fire"), or "" if it
## can. A price in ANY counts every crystal you hold.
static func short_of(profile, kind: String, amount: int) -> String:
	var have := int(profile.crystals_held()) if kind == ANY else int(profile.crystal_total(kind))
	if have >= amount:
		return ""
	if kind == ANY:
		return TEXT["needs_any"] % (amount - have)
	return TEXT["needs"] % [amount - have, Essence.display(kind)]


static func price_text(kind: String, amount: int) -> String:
	if kind == ANY:
		return TEXT["price_any"] % amount
	return TEXT["price"] % [amount, Essence.display(kind)]


## What was paid ({kind: amount}) in words: "40 Water, 20 Fire".
static func paid_text(paid: Dictionary) -> String:
	var parts: Array = []
	for k in paid:
		parts.append(price_text(k, int(paid[k])))
	return ", ".join(parts)


# --- the store's stock -------------------------------------------------------------

## The store's stock after a climb (once per visit): the outfitter's rack
## of Common pieces and today's piece. Departing clears it, so the next
## visit has new stock.
static func stock(profile) -> void:
	if not profile.store.is_empty():
		return
	profile.store = {"outfit": roll_outfit().map(func(g): return Gear.code(g)), "today": Gear.code(roll_today())}


## The Common pieces anyone can buy: weapons, armor and worn pieces that
## are Common by nature.
static func common_pool() -> Array:
	var out: Array = Gear.WEAPON_DROP_WEIGHT.keys()
	for id in Gear.ARMOR_ORDER:
		if id != "":
			out.append(id)
	for id in Gear.PIECE_ORDER:
		if Gear.natural_rarity(id) == "common" and int(Gear.PIECES[id].get("drop_weight", 0)) > 0:
			out.append(id)
	return out


## RACK_SIZE different Common pieces, in the order the inventory lists slots.
static func roll_outfit() -> Array:
	var pool := common_pool()
	pool.shuffle()
	var pick: Array = pool.slice(0, RACK_SIZE)
	var order: Array = ["melee", "ranged", "armor"] + Gear.PIECE_SLOTS
	pick.sort_custom(func(a, b): return order.find(Gear.slot_of(a)) < order.find(Gear.slot_of(b)))
	return pick.map(func(id): return Gear.make(id))


## Today's piece: Fine or Rare (TODAY_ODDS), with its traits.
static func roll_today() -> Dictionary:
	var total := 0
	for r in TODAY_ODDS:
		total += int(TODAY_ODDS[r])
	var roll := randi() % maxi(total, 1)
	var rar := "fine"
	for r in TODAY_ODDS:
		roll -= int(TODAY_ODDS[r])
		if roll < 0:
			rar = r
			break
	var base := Gear.random_gear("", [], true, rar)
	for i in 12:
		if not Gear.traits_for(Gear.trait_slot(base)).is_empty():
			break
		base = Gear.random_gear("", [], true, rar)
	if Gear.rarity_rank(Gear.natural_rarity(base)) > Gear.rarity_rank(rar):
		rar = Gear.natural_rarity(base)
	return Gear.make(base, rar, Gear.roll_traits(base, rar))


## The rack's pieces still for sale (records; a sold one is {}).
static func outfit(profile) -> Array:
	return profile.store.get("outfit", []).map(func(c): return Gear.rec(c))


static func today(profile) -> Dictionary:
	return Gear.rec(profile.store.get("today", ""))


# --- buying and selling ---------------------------------------------------------------

## How many more of an item can be packed for the next climb: what the belt
## holds (its kinds and its stacks, with your heirloom backpack), less what
## every climb starts with and what's already packed.
static func supply_room(profile, player, id: String) -> int:
	var have: int = player.item_count(id) + int(profile.supplies.get(id, 0))
	var room: int = player.max_stack(id) - have
	if have <= 0:
		var kinds := {}
		for k in player.carried():
			kinds[k] = true
		for k in profile.supplies:
			if int(profile.supplies[k]) > 0:
				kinds[k] = true
		if load(VESSEL).packed_index(profile) >= 0:
			kinds[load(VESSEL).ID] = true  # (a vessel packed for the climb takes a kind too)
		if kinds.size() >= player.belt_kinds():
			return 0
	return maxi(0, room)


## Buys one of a consumable, packed for the next climb. "" if bought, else why not.
static func buy_supply(profile, player, id: String) -> String:
	var price := item_price(id)
	if price[1] <= 0:
		return TEXT["belt_full"]
	if supply_room(profile, player, id) <= 0:
		return TEXT["belt_full"]
	var why := short_of(profile, price[0], price[1])
	if why != "":
		return why
	var paid := {price[0]: price[1]}
	if price[0] == ANY:
		paid = profile.spend_any(price[1])  # (from any kinds, the biggest first: noted, for putting it back)
	else:
		profile.spend(price[0], price[1])
	pack_supply(profile, id, paid)
	profile.save()
	return ""


## What the last one of a packed consumable cost ({kind: amount}), or {}.
static func last_paid(profile, id: String) -> Dictionary:
	var list: Array = profile.supply_paid.get(id, [])
	return list.back() if not list.is_empty() else {}


## Packs one of a consumable for the next climb, noting what it cost
## ({kind: amount}) so putting it back returns that.
static func pack_supply(profile, id: String, paid: Dictionary) -> void:
	profile.supplies[id] = int(profile.supplies.get(id, 0)) + 1
	var list: Array = profile.supply_paid.get(id, [])
	list.append(paid)
	profile.supply_paid[id] = list


## Takes one packed consumable out again; what was paid for it ({kind:
## amount}: the last one packed; the store's price if nothing was noted),
## or {} if none is packed.
static func unpack_supply(profile, id: String) -> Dictionary:
	if int(profile.supplies.get(id, 0)) <= 0:
		return {}
	profile.supplies[id] = int(profile.supplies[id]) - 1
	var list: Array = profile.supply_paid.get(id, [])
	var paid: Dictionary = list.pop_back() if not list.is_empty() else {}
	if int(profile.supplies[id]) <= 0:
		profile.supplies.erase(id)
		profile.supply_paid.erase(id)
	if paid.is_empty():
		paid = item_refund(id)
	return paid


## Puts a packed consumable back: what was paid for it comes back.
static func put_back(profile, id: String) -> bool:
	var paid := unpack_supply(profile, id)
	if paid.is_empty():
		return false
	for k in paid:
		profile.add_crystal(k, float(paid[k]))
	profile.save()
	return true


## Room in your pack on the train (with your heirloom backpack).
static func pack_room(profile, player) -> int:
	return maxi(0, int(player.pack_size()) - profile.pack.size())


## Buys a piece off the rack (`i`) or today's piece (i = -1) into your pack.
## "" if bought, else why not.
static func buy_gear(profile, player, i: int) -> String:
	var g: Dictionary = today(profile) if i < 0 else (outfit(profile)[i] if i < outfit(profile).size() else {})
	if g.is_empty():
		return TEXT["today_sold"]
	if pack_room(profile, player) <= 0:
		return TEXT["pack_full"]
	var kind := gear_kind(g)
	var cost := gear_price(g)
	var why := short_of(profile, kind, cost)
	if why != "":
		return why
	profile.spend(kind, cost)
	profile.pack.append(g)
	if i < 0:
		profile.store["today"] = ""
	else:
		var rack: Array = profile.store["outfit"]
		rack[i] = ""
	profile.save()
	return ""


## The list a piece is in ("pack" or "chest").
static func _list(profile, where: String) -> Array:
	return profile.chest if where == "chest" else profile.pack


## Moves a piece between your pack and your chest. "" if moved, else why not.
static func move(profile, player, where: String, i: int) -> String:
	var from := _list(profile, where)
	if i < 0 or i >= from.size():
		return ""
	if where == "pack":
		if profile.chest.size() >= CHEST_SIZE:
			return TEXT["chest_full"]
		profile.chest.append(from[i])
	else:
		if pack_room(profile, player) <= 0:
			return TEXT["pack_full"]
		profile.pack.append(from[i])
	from.remove_at(i)
	profile.save()
	return ""


## Sells a piece from your pack or chest: it becomes a crystal of its kind.
## Returns what it fetched ("5 Blade"), or "" if there was nothing there.
static func sell(profile, where: String, i: int) -> String:
	var from := _list(profile, where)
	if i < 0 or i >= from.size():
		return ""
	var g = from[i]
	var kind := gear_kind(g)
	var got := gear_sell(g)
	from.remove_at(i)
	profile.add_crystal(kind, got)
	profile.save()
	return price_text(kind, got)


## Leaving the train for a tower: pieces in your pack go on in any slot
## that's empty (or holds only the starting sword or bow, not an
## heirloom); the rest go up the tower in your pack. Packed supplies go
## onto your belt. The store's stock clears, for new stock next visit.
static func pack_up(profile, player) -> void:
	var starts := {"melee": Gear.make(Gear.Weapons.START_MELEE), "ranged": Gear.make(Gear.Weapons.START_RANGED)}
	for g in profile.pack:
		var r := Gear.rec(g)
		if r.is_empty():
			continue
		var slot: String = player.slot_for(r)
		var held = player.gear.get(slot, {})
		var free: bool = not Gear.is_gear(held) or (starts.has(slot) and Gear.same(held, starts[slot]) \
			and Gear.heirloom_pieces(profile.heirlooms, Gear.heirloom_slot_for_carry(slot)).is_empty())
		if free:
			player.take_gear(r, slot)
		else:
			player.pack.append(r)
	profile.pack = []
	load(VESSEL).pack_up(profile, player)  # (a vessel packed from the chest goes on the belt)
	for id in profile.supplies.keys():
		for k in int(profile.supplies[id]):
			if not player.add_item(id):
				var paid: Array = profile.supply_paid.get(id, [])
				var back: Dictionary = paid.pop_back() if not paid.is_empty() else item_refund(id)
				for kind in back:
					profile.add_crystal(kind, float(back[kind]))  # (no room after all: what it cost back)
	profile.supplies = {}
	profile.supply_paid = {}
	profile.store = {}
	profile.last_pay = {}  # (the outfitter's greeting about the last climb's pay is said)
	profile.save()
