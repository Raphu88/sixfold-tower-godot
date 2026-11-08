extends RefCounted
## The train: a steampunk train that waits outside the towers. You reach it
## after every climb (survived, fallen or recalled) and leave it for the
## next tower, but only once the Regard has found you: the first climb is
## bondless, and the train appears with the Regard.
##
## You walk along it from the inside (menu.gd's "train" page: train_view.gd
## draws the cars, train_page.gd puts their things in them). Its cars, front
## to back:
##   engine    the cab: choose the next tower on its board, pull the lever
##   personal  your own car: your heirlooms, your pack and a storage chest
##   store     the store car, kept by the outfitter: supplies, an outfit,
##             today's piece, and selling what you brought down
##   workshop  the workshop car: the bench (bench.gd): brewing for anyone,
##             enchanting for a Rune Artist, and breaking things down
##
## Essence crystals are the only currency (profile.gd keeps them as
## {kind, amount}). Every price is in one kind of essence. Names, words,
## prices and numbers live here so they're easy to change.

const Gear := preload("res://scripts/gear.gd")
const Items := preload("res://scripts/items.gd")
const Essence := preload("res://scripts/essence.gd")

## The cars, front to back: [id, name]. The train opens on HOME.
const CARS := [["engine", "Engine"], ["personal", "Your car"], ["store", "Store car"], ["workshop", "Workshop"]]
const HOME := "personal"

## Your storage chest (in your car): pieces kept safe between climbs.
const CHEST_SIZE := 8
## Selling (or breaking down at the bench, bench.gd) gives back this share of
## a thing's price, as a crystal of its kind. A worn Common piece fetches
## less, down to WORN_SELL of that.
const SELL_SHARE := 0.4
const WORN_SELL := 0.25
## How many Common pieces hang on the outfitter's rack each visit.
const RACK_SIZE := 8
## Today's piece: one Fine or Rare piece, new after every climb.
const TODAY_ODDS := {"fine": 75, "rare": 25}

## What a Common piece costs at the store (its price for selling, too).
## Finer pieces cost more (RARITY_PRICE). Rings, amulets and the Climber's
## Pack are never Common: their number here is what a plain one would cost.
const BASE_PRICE := {
	"dagger": 10, "sword": 12, "axe": 12, "mace": 12, "spear": 12, "greatsword": 15, "war_hammer": 15,
	"shortbow": 12, "longbow": 14, "crossbow": 15,
	"padded": 8, "leather": 12, "chain": 16, "plate": 20,
	"cloth_hood": 8, "leather_cap": 10, "iron_helm": 14, "grip_wraps": 10, "leather_gloves": 10, "gauntlets": 14,
	"padded_trousers": 8, "leather_leggings": 10, "chain_leggings": 14, "soft_boots": 10, "climbing_boots": 10, "hobnail_boots": 12,
	"travel_cloak": 8, "dusk_cloak": 12, "satchel": 12, "belt_pouch": 15,
	"bone_charm": 12, "ember_charm": 12, "iron_band": 12, "garnet_ring": 12, "tide_locket": 12, "pearl_ring": 12,
	"overdrawn_ring": 12, "climbers_pack": 12,
}
const DEFAULT_PRICE := 10
const RARITY_PRICE := {"common": 1.0, "fine": 2.0, "rare": 4.0, "storied": 8.0, "regarded": 10.0}
## The essence a piece is priced in and sells for, when it has no trait (or
## name) to say: by its slot.
const SLOT_KIND := {
	"armor": "stone", "helm": "stone", "gloves": "blade", "melee": "blade", "legs": "iron", "ranged": "iron",
	"boots": "air", "cloak": "air", "amulet": "fire", "ring": "water", "backpack": "iron",
}

## The words of the train's pages.
const TEXT := {
	"title": "THE TRAIN",
	"sub": "Brass, steam and the smell of oil. The towers wait past the windows.",
	"menu": "Menu",
	"purse": "Your crystals",
	"home": "Your pack comes down with you: %d %s",
	"money": "The outfitter prices everything in one kind of essence. He takes your smallest crystals of that kind first; if they hold more than the price, the rest comes back to you as one new crystal.",
	"needs": "needs %d more %s",
	"price": "%d %s",
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
	"sell_ask": "Tap again to sell for %d %s",
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
}

## The outfitter who keeps the store car: a retired climber who buys what
## climbers bring down and sells it to the next ones up. No name yet: change
## "name" and "tag" to give him one. One line is picked for each moment.
const OUTFITTER := {
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
	return int(round(float(BASE_PRICE.get(r["base"], DEFAULT_PRICE)) * float(RARITY_PRICE.get(r["rarity"], 1.0))))


## What a piece sells for: SELL_SHARE of its price (less for a worn Common
## piece), at least 1.
static func gear_sell(g) -> int:
	var r := Gear.rec(g)
	if r.is_empty():
		return 0
	var k := maxf(Gear.condition(r), WORN_SELL)
	return maxi(1, int(round(float(gear_price(r)) * SELL_SHARE * k)))


## A consumable's price: [kind, amount] (its worth in items.gd).
static func item_price(id: String) -> Array:
	var d: Dictionary = Items.ITEMS.get(id, {})
	var v: Dictionary = d.get("value", {})
	if v.is_empty():
		return ["", 0]
	var kind := String(d.get("kind", v.keys()[0]))
	return [kind, int(v.get(kind, 0))]


## The consumables the store sells (not the recall scroll: vaults only).
static func supplies() -> Array:
	return Items.ORDER.filter(func(id): return id != "scroll" and not Items.ITEMS[id].get("value", {}).is_empty())


## Why a price can't be paid, in words ("needs 12 more Fire"), or "" if it can.
static func short_of(profile, kind: String, amount: int) -> String:
	var have := int(profile.crystal_total(kind))
	if have >= amount:
		return ""
	return TEXT["needs"] % [amount - have, Essence.display(kind)]


static func price_text(kind: String, amount: int) -> String:
	return TEXT["price"] % [amount, Essence.display(kind)]


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
	profile.spend(price[0], price[1])
	pack_supply(profile, id, {price[0]: price[1]})
	profile.save()
	return ""


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
		var price := item_price(id)
		paid = {price[0]: price[1]}
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
	for id in profile.supplies.keys():
		for k in int(profile.supplies[id]):
			if not player.add_item(id):
				var paid: Array = profile.supply_paid.get(id, [])
				var back: Dictionary = paid.pop_back() if not paid.is_empty() else {item_price(id)[0]: item_price(id)[1]}
				for kind in back:
					profile.add_crystal(kind, float(back[kind]))  # (no room after all: what it cost back)
	profile.supplies = {}
	profile.supply_paid = {}
	profile.store = {}
	profile.save()
