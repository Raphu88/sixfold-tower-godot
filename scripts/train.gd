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
##   personal  your own car: what you'll wear (the Loadout, loadout_page.gd),
##             your pack and your stash (the storage chest, stash_page.gd)
##   workshop  the workshop car: the bench (bench.gd) and its Rune Artist: brewing for anyone,
##             enchanting for a Rune Artist, and breaking things down
##   dining    the Dining car: other climbers at its tables (dining.gd,
##             dining_page.gd): rumors, wagers, trades, and duels fought
##             in the Arena car (reached only through a duel: arena_car.gd)
##   library   the Library: the Entity's Archive on its shelves, read at a
##             lectern (and the Makers' forbidden shelf)
##   settings  the Settings & Controls Car: a signal room whose panel holds
##             the settings and the controls list, and Start over
##
## Essence crystals are the only currency (profile.gd keeps them as
## {kind, amount}, one crystal of each kind). Every price is in one kind of
## essence. Crystals come from condensing at every stair (condense_share), the
## outfitter's pay for every climb (CLIMB_PAY), selling, and prizes. Names, words,
## prices and numbers live here so they're easy to change.

const Gear := preload("res://scripts/gear.gd")
const Items := preload("res://scripts/items.gd")
const Essence := preload("res://scripts/essence.gd")
const Renown := preload("res://scripts/renown.gd")
const Flow := preload("res://scripts/essence_flow.gd")
const Towers := preload("res://scripts/towers.gd")
const Charms := preload("res://scripts/charms.gd")
const Shop := preload("res://scripts/shop.gd")
const Outfitter := preload("res://scripts/outfitter.gd")
const OutfitterName := preload("res://scripts/outfitter_name.gd")
const RuneArtistName := preload("res://scripts/rune_artist_name.gd")
const BasicGift := preload("res://scripts/basic_gift.gd")
const VESSEL := "res://scripts/vessel.gd"  # (loaded when needed: vessel.gd preloads the bench, which preloads this)

## The cars, front to back: [id, name]. The train opens on HOME. (Their short
## names on a phone, and the line under each on a computer, are rail.gd
## TRAIN_CARS.)
const CARS := [["engine", "Engine"], ["store", "Outfitter's Car"], ["personal", "Your Car"], ["workshop", "Workshop"],
	["dining", "Dining Car"], ["library", "Library"], ["settings", "Settings & Controls Car"]]
## The Arena car: coupled behind the Dining car but reached only through a
## duel there (dining.gd, arena.gd type "duel"), so it's never on the rail.
const ARENA_CAR := "arena_car"
const HOME := "personal"

## Your stash (the one stash, kept in your car: profile.chest): pieces kept
## safe between climbs. (It held 8 before the stash screen; old saves load as
## they are.) Every screen shows it through storage_view.gd.
static var CHEST_SIZE := 40
## Selling (or breaking down at the bench, bench.gd) gives back this share of
## a thing's price, as a crystal of its kind. A worn Common piece fetches
## less, down to WORN_SELL of that.
static var SELL_SHARE := 0.4
static var WORN_SELL := 0.25
## How many Common pieces hang on the outfitter's rack each visit.
const RACK_SIZE := 8
## Today's piece: one Fine or Rare piece, new after every climb.
static var TODAY_ODDS := {"fine": 75, "rare": 25}

## The outfitter's upgrades are his upgrade tree now (outfitter.gd): its
## trunk is your rank (shop.gd RANK_STOCK), its branches are bought with
## crystals. (The five upgrades a rank used to unlock, UPGRADES, are its
## nodes: outfitter.gd OLD_UPGRADES.)

## A piece's base price: what it costs at the store (and sells from) is this
## times its rarity's RARITY_PRICE. Rings, amulets and the Climber's Pack are
## never Common: their number here is what a plain one would cost.
static var BASE_PRICE := {
	"dagger": 10, "sword": 12, "axe": 12, "mace": 12, "spear": 12, "greatsword": 15, "war_hammer": 15, "cane": 8, "sword_cane": 14,
	"shortbow": 12, "longbow": 14, "crossbow": 15, "flintlock": 16, "revolver": 18, "rapier": 13, "flail": 13, "sling": 8,
	"padded": 8, "leather": 12, "chain": 16, "plate": 20, "robe": 10, "scale": 18,
	"cloth_hood": 8, "leather_cap": 10, "iron_helm": 14, "grip_wraps": 10, "leather_gloves": 10, "gauntlets": 14,
	"padded_trousers": 8, "leather_leggings": 10, "chain_leggings": 14, "soft_boots": 10, "climbing_boots": 10, "hobnail_boots": 12,
	"travel_cloak": 8, "dusk_cloak": 12, "satchel": 12, "belt_pouch": 15,
	"bone_charm": 12, "ember_charm": 12, "iron_band": 12, "garnet_ring": 12, "tide_locket": 12, "pearl_ring": 12,
	"overdrawn_ring": 12, "climbers_pack": 12,
	"feathered_cap": 10, "miners_helm": 12, "archers_bracers": 10, "studded_gloves": 12, "ranger_breeches": 10, "plated_greaves": 15,
	"wading_boots": 11, "feather_cape": 11, "herb_pouch": 12, "wolf_tooth": 12, "sunstone_pendant": 12, "silver_ring": 12, "jade_ring": 12,
	"viper_ring": 12, "bandolier": 14, "pack": 14, "great_pack": 20,
	# Charms (charms.gd): Commons cost half this, Fine twice it, Rare four times.
	"lucky_knot": 12, "pocket_clasp": 14, "belt_hook": 14, "feather_token": 14, "iron_brooch": 14, "ward_stone": 15, "tide_shell": 16,
	"wardbreaker": 14, "mending_bead": 15, "keepers_purse": 18, "ashen_knot": 18, "gale_charm": 16, "bulwark_stone": 16,
	"hunters_token": 12, "brass_bellows": 14, "duelists_ribbon": 17, "mist_pearl": 17,
	"dancers_slippers": 11, "falcon_pendant": 12,
	# The off-hand (offhand.gd): blades, shields and wands (wands are Fine by nature).
	"parrying_dagger": 10, "hand_axe": 11, "ember_dirk": 12, "buckler": 10, "kite_shield": 14, "tide_ward": 13,
	"cairn_wand": 12, "edge_wand": 12, "iron_wand": 12, "gale_wand": 12, "cinder_wand": 12, "tide_wand": 12,
}
static var DEFAULT_PRICE := 10
## Commons are the everyday buy, at half their base price (the owner's call:
## "I can never afford anything"); Fine and up kept their prices, so a Fine
## piece costs 4x its Common and finds still sell well. A beast's Regarded
## piece is the dearest of all (it sells for the most).
static var RARITY_PRICE := {"common": 0.5, "fine": 2.0, "rare": 4.0, "masterwork": 6.0, "storied": 8.0, "regarded": 14.0}
## The staples (items.gd "staple": the Healing and Stamina Vials and the
## Essence Vial) cost half their small worth (items.gd "value") at the
## store: cheap enough for every climber. Everything else is rarer and costs its full worth. (A belt left
## over at the end of a climb still breaks into crystals at half its worth.)
static var SUPPLY_PRICE := {"draught": 3, "stamina": 3, "vial": 4}
## Supplies priced in crystal essence of ANY kind (the owner's call: "recall
## scrolls should take any kind of essence and always be available"). The
## recall scroll is always on the shelf, and buying one never empties it
## (you carry one at most). Paid from your biggest crystals first
## (profile.gd spend_any). ANY_PRICE sets the price of one paid this way
## that has no worth of its own to go by.
const ANY := "any"
static var ANY_PRICE := {"scroll": 60}
## EVERYDAY GOODS take any kind of essence (the owner's call: crystals of a
## kind you don't climb for had nothing to buy). With "supplies" on (1),
## every consumable on his shelf (the Healing and Stamina Vials, tonics,
## bombs, scrolls, belt items) is priced in any essence, at its usual
## amount, paid from the kinds you hold most of first (profile.gd
## spend_any) and noted, so putting it back returns exactly what it took.
## Tinctures always keep their own kind (they ARE that essence: buying one
## with another kind would be a free exchange), as do the ids in OWN_KIND.
## Gear, charms, the bench's crafting and brewing keep their own kinds; the
## Workshop's Exchange (bench.gd EXCHANGE) trades one kind for another, at
## a loss. (There are no repairs or bag upkeep to pay for: the wandering
## trader in a tower already takes unbanked essence of every kind.)
static var ANY_GOODS := {"supplies": 1}
static var OWN_KIND := ["vessel"]

## Condensing (at every stair, the first climb's too): the crystals' part of
## the split, a fixed share in data (essence_flow.gd SPLIT "crystals", in the
## Data editor): that share of the essence you bank becomes essence crystals,
## per kind and in proportion (whole essence only: a kind with too little for
## one whole essence goes to your body and marks in full), and your body and
## your marks share the rest. Crystals are the train's money. (It was once a
## setting, "To crystals": the owner fixed it, and an old saved value is
## ignored: condense_share.)
## The outfitter's pay for a climb, however it ends (a fall too): crystals of
## the tower's kind, PER_FLOOR for every floor reached and PER_BEST more for
## every floor past your best in that tower before the climb. (PER_FLOOR was
## 2, until a climb still left too many crystals: slow growth. PER_BEST, paid
## once a floor, stays 3, so a first fall on floor 3 still buys something.)
static var CLIMB_PAY := {"per_floor": 1, "per_best": 3}
## The essence a piece is priced in and sells for, when it has no trait (or
## name) to say: by its slot.
const SLOT_KIND := {
	"armor": "stone", "helm": "stone", "gloves": "blade", "melee": "blade", "legs": "iron", "ranged": "iron",
	"boots": "air", "cloak": "air", "amulet": "fire", "ring": "water", "backpack": "iron", "charm": "water", "offhand": "blade",
}

## The words of the train's pages.
static var TEXT: Dictionary = OutfitterName.named({
	"title": "THE TRAIN",
	"sub": "Brass, steam and the smell of oil. The towers wait past the windows.",
	"purse": "Your crystals",
	"home": "Your pack comes down with you: %d %s",
	"home_worn": "You come down wearing what you found: %d %s",
	"money": "{outfitter} prices gear in one kind of essence, and takes it from your crystal of that kind. Everyday goods on his shelf take any kind.",
	"needs": "needs %d more %s",
	"price": "%d %s",
	"price_any": "%d of any kind",
	"needs_any": "needs %d more essence, of any kind",
	"any_note": "An everyday good: paid from your crystals of any kind, the kinds you hold most of first.",
	"paid_with": "paid %s",
	"buy": "Buy",
	"bought": "Bought: %s",
	"cant": "Can't buy: %s",
	# Your car
	"personal_sub": "Your heirlooms, your pack, and your stash for what you want to keep.",
	"heirlooms": "Heirlooms",
	"view_heirlooms": "Heirlooms",
	"to_chest": "Into the stash",
	"to_pack": "Into your pack",
	"moved_chest": "Into the stash: %s",
	"moved_pack": "Into your pack: %s",
	"chest_full": "your stash is full",
	"pack_full": "your pack is full",
	"pack_shrinks": "your pack would hold too little: move a piece out of it first",
	"no_room": "your pack and stash are both full",
	"sell_for": "Sell for %d %s",
	"sell_ask": "Sell it to {outfitter} for %d %s? It's his once sold.",
	"sold": "Sold: %s for %s",
	# Store car
	"store_sub": "Kept by {outfitter}. He buys what climbers bring down, and sells it to the next ones up.",
	"supplies_note": "Supplies are packed onto your belt for your next climb, beside the Healing and Stamina Vials every climb starts with.",
	"packed": "Packed for your next climb: %d  ·  your belt holds %d",
	"belt_full": "your belt can't hold more",
	"put_back": "Put one back (what you paid comes back)",
	"put_back_done": "Put back: %s",
	"outfit_note": "Common pieces for your next climb. Buy into your pack (it goes up the tower) or your stash (it stays on the train), or buy and wear it.",
	"today_note": "One finer piece, new after every climb.",
	"today_sold": "Sold. Another piece comes after your next climb.",
	"sell_note": "What you brought down in your pack, and what's in your stash. Each sells for a crystal of its kind, at %d%% of its price.",
	"nothing_to_sell": "Nothing to sell. Bring finds home in your pack: survive a climb, or read a recall scroll.",
	"against": "Against what you'd start with",
	"case": "Today's piece",
	# Your car: the mirror (the climber screen) and the travelling trunk (the inventory)
	"mirror": "Climber",
	"mirror_short": "Climber",
	"trunk": "Inventory",
	"trunk_short": "Inventory",
	"looks": "Appearance",  # how you look (appearance_page.gd)
	"looks_short": "Looks",
	"loadout": "Loadout",  # what you'll wear, and your pack (loadout_page.gd)
	"loadout_short": "Loadout",
	"stash": "Stash",  # the stash screen (stash_page.gd)
	"stash_short": "Stash",
	"buy_pack": "Buy: into your pack",
	"buy_chest": "Buy: into your stash",
	"buy_wear": "Buy and wear it",
	"afford": "You can afford it.",
	"sort_by": "Sort: %s",
	"wear_tag": "You'll wear",
	# The store's sections, the upgrade tree's sign, and the special order
	"consumables": "Consumables",
	"weapons": "Weapons & armour",
	"charms": "Charms",
	"sell": "Sell",
	"sell_how": "Choose a piece, then Sell on its card: he pays %d%% of its price, as a crystal of its kind.",
	"tree_sign": "Upgrade tree",
	"tree_short": "Upgrades",
	# The upgrade tree's sign beside the goods on a wide screen: it opens and folds the tree (store_page.gd).
	"upgrades_fold": "Upgrades",
	"upgrades_count": "%d of %d",
	"goods_sign": "Back to the goods",
	"goods_short": "Goods",
	"order": "Special order",
	"order_empty": "Nothing held. Choose a piece on the rail or in the case and ask him to hold it.",
	"order_note": "Held for you until you buy it.",
	"hold": "Hold it for me (special order)",
	"held": "Held for you: %s",
	"hold_full": "he already holds a piece for you",
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
	"depart_risk": "Fall, and your pack and belt are lost; your stash, heirlooms and crystals are safe.",
	"last": "last climbed",
	# Condensing at the stair (main.gd _arrive), and the outfitter's pay for a climb
	"banked": "Banked %d essence",
	"condensed": "%d condensed into crystals",
	"pay": "{outfitter} pays for your climb: +%s",
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
})

## The outfitter who keeps the store car: a retired climber who buys what
## climbers bring down and sells it to the next ones up. No name yet: change
## "name" and "tag" to give him one. One line is picked for each moment.
static var OUTFITTER: Dictionary = RuneArtistName.named(OutfitterName.named({
	"name": "{outfitter}",
	"tag": "{outfitter}, the Outfitter",
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
	# After an everyday good is bought (train.gd ANY_GOODS: any kind of essence pays for it).
	"any": [
		"Any kind spends on my shelf. A vial's a vial, whatever tower paid for it.",
		"Took it from your fullest crystals. Gear's another matter: that wants its own kind.",
		"Crystals you can't use? Spend them on my shelf, or see {rune_artist}'s Exchange in the Workshop.",
	],
	# His greeting while a climb's pay is fresh (%s is what he paid: "14 Water").
	"paid": [
		"Your pay for the climb: %s. A floor's a floor, even on the way down.",
		"%s for your climb. I pay by the floor, not by how it ended.",
	],
}))


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
	if Gear.slot_of(r) == "charm" and String(Gear.PIECES.get(r.get("base", ""), {}).get("kind", "")) != "":
		return String(Gear.PIECES[r["base"]]["kind"])  # (an enchanted charm: its own essence, charms.gd kind)
	return String(SLOT_KIND.get(Gear.slot_of(r), "iron"))


## What a piece costs at the store: its base price times its rarity's.
static func gear_price(g) -> int:
	var r := Gear.rec(g)
	if r.is_empty():
		return 0
	return maxi(1, int(round(float(BASE_PRICE.get(r["base"], DEFAULT_PRICE)) * float(RARITY_PRICE.get(r["rarity"], 1.0)))))


## What a piece sells for: SELL_SHARE of its price (with a `profile`, his
## tree's better share: outfitter.gd sell_share; less for a worn Common
## piece), at least 1. The basic sword and bow sell for nothing: nobody buys
## what's given away (basic_gift.gd).
static func gear_sell(g, profile = null) -> int:
	var r := Gear.rec(g)
	if r.is_empty() or BasicGift.is_basic(r):
		return 0
	var k := maxf(Gear.condition(r), WORN_SELL)
	var share := Outfitter.sell_share(profile) if profile != null else SELL_SHARE
	return maxi(1, int(round(float(gear_price(r)) * share * k)))


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
	var amount := int(SUPPLY_PRICE.get(id, v.get(kind, 0)))
	return [ANY if everyday(id) else kind, amount]


## Is this consumable an everyday good, priced in essence of any kind
## (ANY_GOODS)? Never a tincture (it keeps its own kind) nor one in OWN_KIND.
static func everyday(id: String) -> bool:
	if ANY_PRICE.has(id):
		return true
	if int(ANY_GOODS.get("supplies", 0)) <= 0 or id in OWN_KIND or Flow.is_tincture(id):
		return false
	return not Items.ITEMS.get(id, {}).get("value", {}).is_empty()


## The kind an item is worth in: its own essence (what the belt breaks a found one into).
static func home_kind(id: String) -> String:
	var d: Dictionary = Items.ITEMS.get(id, {})
	var v: Dictionary = d.get("value", {})
	return String(d.get("kind", v.keys()[0] if not v.is_empty() else ""))


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
## (SELL_SHARE of its price, in its own kind). Given the `profile`, one
## bought or brewed breaks down for SELL_SHARE of what was actually paid for
## it (the note of the last one packed, rounded down), in the kind most of
## it was paid in: so an everyday good bought with any kind never comes
## back as more, nor as another kind at better than the Exchange's rate.
static func item_sell(id: String, profile = null) -> Array:
	if profile != null:
		var paid := last_paid(profile, id)
		var total := 0.0
		var most := ""
		for k in paid:
			total += float(paid[k])
			if most == "" or float(paid[k]) > float(paid[most]):
				most = String(k)
		if total >= 1.0 and most != "":
			return [most, maxi(1, int(floor(total * SELL_SHARE)))]
	var back := item_refund(id)
	if back.is_empty():
		return ["", 0]
	var kind: String = back.keys()[0]
	return [kind, maxi(1, int(round(float(back[kind]) * SELL_SHARE)))]


# --- condensing and the outfitter's pay ------------------------------------------------

## The share of banked essence that condenses into crystals at a stair (0 to
## 1): fixed, essence_flow.gd SPLIT "crystals" (no longer a setting).
static func condense_share() -> float:
	return load("res://scripts/essence_flow.gd").default_crystal_share()


## What the outfitter pays for a climb that reached `reached` in a tower whose
## best floor before the climb was `best_before` (essence of the tower's kind).
static func climb_pay(reached: int, best_before: int) -> int:
	reached = maxi(reached, 0)
	return int(CLIMB_PAY["per_floor"]) * reached + int(CLIMB_PAY["per_best"]) * maxi(0, reached - maxi(best_before, 0))


## The consumables the store sells: always the same shelf, the cheap staples
## first, then the rest in Items.ORDER (the recall scroll among them, always
## there; only the outfit rail and today's piece change between visits).
## The shelf this visit: item ids, kept with the visit's stock (an old
## save's store has none: the whole shelf of what your rank has opened; an
## old save's sized keys, "draught@3", are simply the item, once).
static func shelf(profile) -> Array:
	var keys: Array = profile.store.get("shelf", []) if profile != null else []
	if keys.is_empty():
		keys = Shop.shelf_pool(profile) if profile != null else supplies()
		if not keys.has("scroll") and Items.ITEMS.has("scroll"):
			keys = keys + ["scroll"]
	var plain: Array = []
	for k in keys:
		var id := Items.old_id(String(k))
		if Items.ITEMS.has(id) and not plain.has(id):
			plain.append(id)
	keys = plain
	if profile != null:  # (the tinctures he stocks this visit: essence_flow.gd, store_tinctures)
		for k in store_tinctures(profile):
			var tid := Flow.tincture_id(String(k))
			if Items.ITEMS.has(tid) and not keys.has(tid):
				keys = keys + [tid]
	return keys


## Tinctures (essence_flow.gd) aren't on the fixed shelf: with a `profile`,
## the kinds he stocks this visit come last (store_tinctures).
static func supplies(profile = null) -> Array:
	var all: Array = Items.ORDER.filter(func(id): return not Items.ITEMS[id].get("value", {}).is_empty() and not Flow.is_tincture(id))
	var out: Array = all.filter(func(id): return Items.is_staple(id)) + all.filter(func(id): return not Items.is_staple(id))
	if profile != null:
		out.append_array(store_tinctures(profile).map(func(k): return Flow.tincture_id(String(k))))
	return out


## The tinctures the outfitter stocks this visit: Flow.TINCTURE "store_kinds"
## kinds, the first the tower you last climbed half the time (else any other),
## the rest by chance (kept with the visit's stock; a store stocked before
## tinctures rolls them now).
static func store_tinctures(profile) -> Array:
	if profile == null:
		return []
	var have = profile.store.get("tinctures", null) if profile.store is Dictionary else null
	if have is Array and not have.is_empty():
		return have.filter(func(k): return Essence.KINDS.has(String(k)))
	var home := String(Towers.TOWERS.get(String(profile.last_tower), {}).get("essence", "air"))
	var rest: Array = Essence.KINDS.keys().filter(func(k): return k != home)
	rest.shuffle()
	var order: Array = ([home] + rest) if randf() < 0.5 else (rest + [home])
	var kinds: Array = order.slice(0, maxi(0, int(Flow.TINCTURE.get("store_kinds", 1))))
	if not profile.store.is_empty():
		profile.store["tinctures"] = kinds
	return kinds


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
	if profile.store.has("outfit"):
		return
	var rolled := roll_outfit(profile)
	profile.store["outfit"] = rolled.map(func(g): return Gear.code(g))
	profile.store["kinds"] = rolled.map(func(g): return "charm" if Gear.is_gear(g) and Gear.slot_of(g) == "charm" else "gear")  # (which section each shows in, sold or not: store_page.gd)
	profile.store["today"] = Gear.code(roll_today(profile))
	profile.store["shelf"] = Shop.roll_shelf(profile)  # (shop.gd: the supplies for this visit, by your rank)
	profile.store["title"] = String(Renown.state(profile).get("worn", ""))
	profile.store.erase("tinctures")
	store_tinctures(profile)  # (the tinctures he stocks this visit)
	profile.store["word"] = Outfitter.on_visit(profile)  # (his tree's gifts and word, once a visit)


# --- the outfitter's upgrade tree (outfitter.gd) -------------------------------------------

## True once you own this node of his tree (an old upgrade's id, UPGRADES
## before the tree, names the node that does the same).
static func upgraded(profile, id: String) -> bool:
	if Outfitter.OLD_UPGRADES.has(id):
		id = String(Outfitter.OLD_UPGRADES[id][0])
	return Outfitter.owns(profile, id)


## How many pieces hang on the outfit rail: the rack, your rank's spaces and a wider rack.
static func rack_size(profile) -> int:
	return RACK_SIZE + Outfitter.rack_extra(profile) + Shop.rail_extra(profile)


## What the outfitter takes off his prices (0 to 1): his tree's price nodes
## and your worn title, together no more than outfitter.gd FX "discount_cap".
static func discount(profile) -> float:
	return Outfitter.discount(profile)


## What a piece costs you at the store (gear_price, less his discount).
static func buy_price(profile, g) -> int:
	var p := gear_price(g)
	if p <= 0:
		return 0
	return maxi(1, int(round(float(p) * (1.0 - discount(profile)))))


## What a consumable costs you at the store: [kind, amount] (item_price, the
## scroll kept aside, less his discount).
static func supply_price(profile, id: String) -> Array:
	var price := item_price(id)
	if int(price[1]) <= 0:
		return price
	var amount := int(price[1])
	if id == "scroll" and price[0] == ANY and Outfitter.scroll_price(profile) > 0:
		amount = mini(amount, Outfitter.scroll_price(profile))
	return [price[0], maxi(1, int(round(float(amount) * (1.0 - discount(profile)))))]


## The special order: the piece he holds for you ({} for none).
static func order(profile) -> Dictionary:
	if profile == null:
		return {}
	return Gear.rec(Renown.state(profile)["order"])


## Asks him to hold a piece off the rack (`i`) or today's piece (i = -1):
## it leaves the rack and waits as your special order. "" if done, else why not.
static func hold(profile, i: int) -> String:
	if not Outfitter.owns(profile, "special_order"):
		return "?"
	if not order(profile).is_empty():
		return TEXT["hold_full"]
	var g: Dictionary = today(profile) if i < 0 else (outfit(profile)[i] if i < outfit(profile).size() else {})
	if g.is_empty():
		return TEXT["today_sold"]
	Renown.state(profile)["order"] = Gear.code(g)
	if i < 0:
		profile.store["today"] = ""
	else:
		var rack: Array = profile.store["outfit"]
		rack[i] = ""
	profile.save()
	return ""


## The Common pieces anyone can buy: weapons, armor and worn pieces that
## are Common by nature. Never the basic sword or bow: the outfitter gives
## those away (basic_gift.gd).
static func common_pool(profile = null) -> Array:
	var out: Array = Gear.WEAPON_DROP_WEIGHT.keys().filter(func(id): return (profile == null or Shop.piece_open(profile, id)) and not BasicGift.is_basic_base(String(id)))  # (pistols and crossbows hang later: shop.gd WEAPON_RANK)
	for id in Gear.ARMOR_ORDER:
		if id != "":
			out.append(id)
	for id in Gear.PIECE_ORDER:
		if Gear.natural_rarity(id) == "common" and int(Gear.PIECES[id].get("drop_weight", 0)) > 0:
			out.append(id)
	return out


## The rail's pieces: different Common pieces for the spaces (more with the
## wider rack and with rank), in the order the inventory lists slots. Rank
## and the worn title shape them (shop.gd): some come Fine or Rare, the
## title's kind of piece is likelier, and at high ranks a named piece or a
## relic hangs among them; charms fill the last spaces.
static func roll_outfit(profile = null) -> Array:
	var pool := common_pool(profile)
	var charms := Shop.charm_count(profile) if profile != null else int(Charms.SHOP["rack"])
	var extras: Array = Shop.extras(profile) if profile != null else []
	if profile != null:
		for i in Shop.title_first_look(profile):  # (the worn title's first look: a Fine-or-better piece kept for you, titles.gd)
			for attempt in 24:  # (some pieces take no traits, e.g. a bag: draw again so the promised piece always comes)
				var fid: String = Gear.random_gear("", [], true, "fine")
				if not Gear.traits_for(Gear.trait_slot(fid)).is_empty():
					extras.append(Gear.make(fid, "fine", Gear.roll_traits(fid, "fine")))
					break
	var spaces := maxi(1, rack_size(profile) - charms - extras.size())
	var pick: Array = Shop.pick(profile, pool, spaces)
	var slots: Array = ["melee", "ranged", "armor"] + Gear.PIECE_SLOTS
	pick.sort_custom(func(a, b): return slots.find(Gear.slot_of(a)) < slots.find(Gear.slot_of(b)))
	# A climber with no bag at all always finds a Satchel on the rail (a
	# first bag should be easy to get: gear.gd BAG).
	if profile != null and not has_bag(profile) and not pick.has(FIRST_BAG):
		pick[pick.size() - 1] = FIRST_BAG
		pick.sort_custom(func(a, b): return slots.find(Gear.slot_of(a)) < slots.find(Gear.slot_of(b)))
	var floor_fine := Outfitter.fine_floor(profile)
	var out: Array = pick.map(func(id): return Shop.make_piece(profile, id, floor_fine) if profile != null else Gear.make(id))
	# A Rare on the hook (his tree): the first plain piece that can be Rare is.
	var rares := Outfitter.rare_count(profile) - out.filter(func(g): return Gear.rarity(g) == "rare").size()
	for i in out.size():
		if rares <= 0:
			break
		var base := Gear.base_id(out[i])
		if Gear.rarity(out[i]) != "rare" and not Gear.traits_for(Gear.trait_slot(base)).is_empty():
			out[i] = Gear.make(base, "rare", Gear.roll_traits(base, "rare"))
			rares -= 1
	out.append_array(extras)  # (a named piece or a relic, now and then at high ranks)
	out.append_array(Charms.shop_stock(charms))  # (charms in the rail's last spaces: charms.gd SHOP)
	return out


## The bag a climber with none always finds on the rail.
const FIRST_BAG := "satchel"


## Does the climber own a bag anywhere (worn, kept, in the pack or stash)?
static func has_bag(profile) -> bool:
	for g in [profile.wear.get("backpack", {})] + Gear.heirloom_pieces(profile.heirlooms, "backpack") + profile.pack + profile.chest:
		if Gear.is_gear(g) and Gear.slot_of(g) == "backpack":
			return true
	return false


## Today's piece: Fine or Rare (TODAY_ODDS; outfitter.gd STOCK_ODDS with better stock), with its traits.
static func roll_today(profile = null) -> Dictionary:
	var odds: Dictionary = Outfitter.today_odds(profile, TODAY_ODDS)
	var total := 0
	for r in odds:
		total += int(odds[r])
	var roll := randi() % maxi(total, 1)
	var rar := "fine"
	for r in odds:
		roll -= int(odds[r])
		if roll < 0:
			rar = r
			break
	if profile != null and Shop.title_today(profile):  # (the worn title: a rarity higher, titles.gd)
		rar = "rare" if rar == "fine" else ("masterwork" if rar == "rare" else rar)  # (a plain piece: the next plain rarity up)
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
	var price := supply_price(profile, id)
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


## A piece he offers: on the rail (`i`), today's piece (-1), the special
## order (-2) or the relic offered once (-3); {} if sold or none.
static func offer(profile, i: int) -> Dictionary:
	match i:
		-3:
			return Outfitter.unique(profile)
		-2:
			return order(profile)
		-1:
			return today(profile)
	return outfit(profile)[i] if i >= 0 and i < outfit(profile).size() else {}


## Buys a piece off the rack (`i`) or today's piece (i = -1) into your pack
## (`to` "pack"), your stash ("chest"), or straight onto you ("wear": into
## your pack, then worn, what you wore there going back into the pack).
## "" if bought, else why not.
static func buy_gear(profile, player, i: int, to := "pack") -> String:
	var g: Dictionary = offer(profile, i)
	if g.is_empty():
		return TEXT["today_sold"]
	var why := buy_room(profile, player, g, to)
	if why != "":
		return why
	var kind := gear_kind(g)
	var cost := buy_price(profile, g)
	why = short_of(profile, kind, cost)
	if why != "":
		return why
	profile.spend(kind, cost)
	if to == "chest":
		profile.chest.append(g)
	else:
		profile.pack.append(g)
	if i == -3:
		Outfitter.state(profile)["unique"] = ""  # (the relic offered once, bought)
	elif i == -2:
		Renown.state(profile)["order"] = ""  # (the special order, collected)
	elif i < 0:
		profile.store["today"] = ""
	else:
		var rack: Array = profile.store["outfit"]
		rack[i] = ""
	if to == "wear":
		equip(profile, player, "pack", profile.pack.size() - 1)
	profile.save()
	return ""


## Why a piece can't be bought into `to` ("pack", "chest" or "wear"), or "".
static func buy_room(profile, player, g, to := "pack") -> String:
	if to == "chest":
		return TEXT["chest_full"] if profile.chest.size() >= CHEST_SIZE else ""
	if pack_room(profile, player) <= 0:
		return TEXT["pack_full"]
	if to == "wear":
		var slot := wear_slot_for(profile, player, g)
		var after: Dictionary = profile.wear.duplicate()
		after[slot] = Gear.rec(g)
		var old = profile.wear.get(slot, null)
		if pack_too_small(profile, after, profile.pack.size() + (1 if old != null else 0)):
			return TEXT["pack_shrinks"]
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
## Returns what it fetched ("5 Blade"), or "" if there was nothing there
## (or it can't be sold: the basic sword and bow, basic_gift.gd).
static func sell(profile, where: String, i: int) -> String:
	var from := _list(profile, where)
	if i < 0 or i >= from.size():
		return ""
	var g = from[i]
	if not can_sell(g):
		return ""
	var kind := gear_kind(g)
	var got := gear_sell(g, profile)
	from.remove_at(i)
	profile.add_crystal(kind, got)
	profile.save()
	return price_text(kind, got)


## Can this piece be sold (to the store or a climber, or broken down at
## the bench)? Not the basic sword or bow: they're given away (basic_gift.gd).
static func can_sell(g) -> bool:
	return Gear.is_gear(g) and not BasicGift.is_basic(g)


## Does the basic sword or bow worn in `slot` (`held`) give way to a pack
## piece as you set off? Only if it isn't your heirloom and your stash has
## room for it (it waits there, safe on the train).
static func basic_yields(profile, slot: String, held) -> bool:
	return BasicGift.is_basic(held) and profile.chest.size() < CHEST_SIZE \
		and Gear.heirloom_pieces(profile.heirlooms, Gear.heirloom_slot_for_carry(slot)).is_empty()


## Leaving the train for a tower: pieces in your pack go on in any slot
## that's empty, or that holds only the basic sword or bow (which then
## waits in your stash: basic_yields); the rest go up the tower in your
## pack. Packed supplies go onto your belt. The store's stock clears, for
## new stock next visit.
static func pack_up(profile, player) -> void:
	if not profile.wear.is_empty():
		dress(profile, player)  # (what you chose to wear goes on first, over the heirloom)
	for g in profile.pack:
		var r := Gear.rec(g)
		if r.is_empty():
			continue
		var slot: String = player.slot_for(r)
		var held = player.gear.get(slot, {})
		var yields := basic_yields(profile, slot, held)
		if not Gear.is_gear(held) or yields:
			if yields:
				profile.chest.append(Gear.rec(held))  # (the basic piece waits in your stash)
			player.take_gear(r, slot)
		else:
			player.pack.append(r)
	profile.pack = []
	profile.wear = {}  # (it's on you now: worn pieces, like any you find)
	BasicGift.departing(profile)  # (what you wear is out on the climb: fall, and the sword and bow come back as gifts)
	load(VESSEL).pack_up(profile, player)  # (a vessel packed from the chest goes on the belt)
	profile.belt_paid = {}
	for id in profile.supplies.keys():
		var paid: Array = profile.supply_paid.get(id, []).duplicate()
		var went := 0
		for k in int(profile.supplies[id]):
			if player.add_item(id):
				went += 1
			else:
				var back: Dictionary = paid.pop_back() if not paid.is_empty() else item_refund(id)
				for kind in back:
					profile.add_crystal(kind, float(back[kind]))  # (no room after all: what it cost back)
		if went > 0 and not Flow.is_tincture(id) and not paid.is_empty():
			profile.belt_paid[id] = paid.slice(maxi(0, paid.size() - went))  # (what the bought ones cost: belt_worth)
	profile.supplies = {}
	profile.supply_paid = {}
	for id in Outfitter.belt_gifts(profile):
		player.add_item(id)  # (his tree's gifts for the road, if the belt has room)
	profile.store = {}
	profile.last_pay = {}  # (the outfitter's greeting about the last climb's pay is said)
	profile.save()


## What a belt left at the end of a survived climb breaks into ({kind:
## essence}; `carried` is {id: count}). Found items break at Items
## BREAK_SHARE of their worth, as ever; those bought or brewed on the train
## (profile.belt_paid, noted as they were packed: the leftovers count as
## bought first) break at BREAK_SHARE of what they cost, in the kinds that
## paid for them. So a vial bought with any kind of essence never comes home
## as more essence, nor as a kind it wasn't bought with.
static func belt_worth(profile, carried: Dictionary) -> Dictionary:
	var out := {}
	var notes = profile.get("belt_paid") if profile != null else null
	if not (notes is Dictionary):
		notes = {}
	for id in carried:
		var n := int(carried[id])
		var list: Array = notes.get(id, [])
		var bought := mini(n, list.size())
		for j in bought:
			var note = list[list.size() - 1 - j]
			if note is Dictionary:
				for k in note:
					out[k] = float(out.get(k, 0.0)) + float(note[k]) * Items.BREAK_SHARE
		if n - bought > 0:
			var found: Dictionary = Items.break_value({id: n - bought})
			for k in found:
				out[k] = float(out.get(k, 0.0)) + float(found[k])
	return out


# --- the loadout: what you'll wear when you set off ---------------------------------
# On the train you choose what to wear from your pack or your stash
# (loadout_page.gd). The chosen pieces (profile.wear: carried slot ->
# record) go on as you depart, over your heirloom in that slot (an
# heirloom you don't wear waits on the train, still yours); from then on
# they're worn pieces like any you find. Pieces left in your pack still go
# on in a slot nothing is worn in, or that holds only the basic sword or
# bow (pack_up). A new climber's basic sword and bow are chosen pieces
# like any other (basic_gift.gd): nothing puts them back by itself. The climber on
# the train wears the loadout already (dress), so the climber screen and
# the figure show it.

## The slots you can wear something in.
const WEAR_SLOTS := ["melee", "ranged", "armor", "helm", "gloves", "legs", "boots", "cloak", "amulet", "ring1", "ring2", "backpack", "charm", "offhand"]

## The sorts and filters of the stash screen (stash_page.gd): [id, name].
## A slot filter is "all" or a slot (Gear.slot_of); an essence filter "all"
## or a kind.
static var STASH_SORTS := [["newest", "Newest"], ["rarity", "Rarity"], ["slot", "Slot"], ["kind", "Essence"], ["price", "Price"]]
static var SLOT_FILTERS := [["all", "All slots"], ["melee", "Melee"], ["ranged", "Ranged"], ["armor", "Chest"], ["helm", "Helm"], ["gloves", "Gloves"],
	["legs", "Legs"], ["boots", "Boots"], ["cloak", "Cloak"], ["amulet", "Amulet"], ["ring", "Rings"], ["backpack", "Backpack"], ["charm", "Charms"], ["offhand", "Off-hand"]]
## The outfit rail's filter, and where selling shows pieces from: [id, name].
const SLOT_ORDER := ["melee", "ranged", "armor", "helm", "gloves", "legs", "boots", "cloak", "amulet", "ring", "backpack", "charm", "offhand"]


## What you'd wear with these chosen pieces (`wear`, else profile.wear):
## your heirlooms in their slots, then the chosen pieces over them (carried
## slot -> record). Nothing else: the basic sword and bow are chosen pieces.
static func dressed(profile, wear = null) -> Dictionary:
	var chosen: Dictionary = profile.wear if wear == null else wear
	var g := {}
	for s in Gear.SLOTS:
		g[s] = {}
	for hs in profile.heirlooms:
		var gs := Gear.gear_slot_for(String(hs))
		if gs == "":
			continue
		var into: Array = Gear.carry_slots(gs)
		var pieces: Array = Gear.heirloom_pieces(profile.heirlooms, hs).filter(func(r): return Gear.slot_of(r) == gs)
		for i in mini(pieces.size(), into.size()):
			g[into[i]] = Gear.heirloom_copy(pieces[i])
	for slot in chosen:
		if g.has(slot):
			g[slot] = Gear.rec(chosen[slot])
	return g


## Puts the loadout on the climber on the train (their gear, weapon and the
## numbers it adds up to).
static func dress(profile, player) -> void:
	if player != null and player.has_method("wear_set"):
		player.wear_set(dressed(profile))


## What you'll set off in, slot by slot: {slot: {"rec", "from"}} where
## "from" is "wear" (chosen), "basic" (the basic sword or bow, chosen:
## basic_gift.gd), "heir" (your heirloom) or "pack" (a pack piece that goes
## on because nothing else is worn there, or only the basic piece; its "i"
## in the pack). Empty slots are left out.
static func setoff(profile, _player = null) -> Dictionary:
	var g := dressed(profile)
	var out := {}
	for slot in WEAR_SLOTS:
		var r = g.get(slot, {})
		if not Gear.is_gear(r):
			continue
		var from := "heir"
		if profile.wear.has(slot):
			from = "basic" if BasicGift.is_basic(r) else "wear"
		out[slot] = {"rec": r, "from": from}
	for i in profile.pack.size():
		var p := Gear.rec(profile.pack[i])
		if p.is_empty():
			continue
		var into: Array = Gear.carry_slots(Gear.slot_of(p))
		var slot: String = into[0]
		for sl in into:
			if not out.has(sl):
				slot = sl
				break
		var held: Dictionary = out.get(slot, {})
		if held.is_empty() or (held["from"] == "basic" and basic_yields(profile, slot, held["rec"])):
			out[slot] = {"rec": p, "from": "pack", "i": i}
	return out


## The gear you'll set off in (carried slot -> record), for drawing and numbers.
static func setoff_gear(profile, player = null) -> Dictionary:
	var g := {}
	for s in Gear.SLOTS:
		g[s] = {}
	var so := setoff(profile, player)
	for slot in so:
		g[slot] = so[slot]["rec"]
	return g


## How many pieces your pack holds with these chosen pieces worn (your
## bag's size, and a charm's extra space: gear.gd pack_capacity).
static func pack_size_with(profile, wear: Dictionary) -> int:
	return Gear.pack_capacity(Gear.total_effects(dressed(profile, wear)))


## True if wearing `after` would leave the pack holding more than it can
## (`pack_after` pieces): only a change that makes the pack smaller is
## refused, so an old save whose pack holds more than its bag (packs held
## 4 before bags had sizes) can still change what it wears; nothing is
## ever thrown away, you just can't add until it's under.
static func pack_too_small(profile, after: Dictionary, pack_after: int) -> bool:
	var cap := pack_size_with(profile, after)
	return cap < pack_after and cap < pack_size_with(profile, profile.wear)


## The slot a piece goes in when you choose to wear it: its own; for a ring
## the first ring slot with nothing in it, else the first one you haven't
## chosen a ring for, else the first.
static func wear_slot_for(profile, _player, g) -> String:
	var into: Array = Gear.carry_slots(Gear.slot_of(g))
	if into.size() > 1:
		var dg := dressed(profile)
		for sl in into:
			if not Gear.is_gear(dg.get(sl, {})):
				return sl
		for sl in into:
			if not profile.wear.has(sl):
				return sl
	return into[0]


## Wears a piece from your pack or stash (`where` "pack" or "chest", index
## `i`; `into` picks a ring slot). A piece you chose to wear there before
## goes back where this one came from; an heirloom stays yours and waits on
## the train this climb. "" if done, else why not.
static func equip(profile, player, where: String, i: int, into := "") -> String:
	var from := _list(profile, where)
	if i < 0 or i >= from.size():
		return ""
	var g := Gear.rec(from[i])
	if g.is_empty():
		return ""
	var slots: Array = Gear.carry_slots(Gear.slot_of(g))
	var slot: String = into if into in slots else wear_slot_for(profile, player, g)
	var old = profile.wear.get(slot, null)
	var after: Dictionary = profile.wear.duplicate()
	after[slot] = g
	var pack_after: int = profile.pack.size() - (1 if where == "pack" else 0) + (1 if old != null and where == "pack" else 0)
	if pack_too_small(profile, after, pack_after):
		return TEXT["pack_shrinks"]
	from.remove_at(i)
	if old != null:
		from.insert(i, old)
	profile.wear = after
	dress(profile, player)
	profile.save()
	return ""


## Takes off a piece you chose to wear, into your pack (`to` "pack") or
## stash ("chest"); "" picks the pack if it has room, else the stash. "" if
## done, else why not.
static func unequip(profile, player, slot: String, to := "") -> String:
	if not profile.wear.has(slot):
		return ""
	var after: Dictionary = profile.wear.duplicate()
	after.erase(slot)
	var cap := pack_size_with(profile, after)
	if to == "":
		to = "pack" if profile.pack.size() < cap else ("chest" if profile.chest.size() < CHEST_SIZE else "")
		if to == "":
			return TEXT["no_room"]
	if to == "chest":
		if profile.chest.size() >= CHEST_SIZE:
			return TEXT["chest_full"]
		if pack_too_small(profile, after, profile.pack.size()):
			return TEXT["pack_shrinks"]
		profile.chest.append(profile.wear[slot])
	else:
		if profile.pack.size() + 1 > cap:
			return TEXT["pack_full"] if profile.pack.size() < pack_size_with(profile, profile.wear) else TEXT["pack_shrinks"]
		profile.pack.append(profile.wear[slot])
	profile.wear = after
	dress(profile, player)
	profile.save()
	return ""


## What a piece is set against: what you'd wear in its slot (for a ring,
## the first ring slot; "" for no armour; null for nothing there).
static func worn_against(profile, player, g):
	var r := Gear.rec(g)
	var so := setoff_gear(profile, player)
	for sl in Gear.carry_slots(Gear.slot_of(r)):
		var held = so.get(sl, {})
		if not Gear.is_gear(held):
			return "" if sl == "armor" else null
	return so.get(Gear.carry_slots(Gear.slot_of(r))[0], null)


## A piece set against what you'd wear in its slot: its better numbers
## (+1 each) less its worse ones (Gear.compare), so > 0 is better on the
## whole, < 0 worse, 0 about the same (or the very piece you wear). Anything
## beats an empty slot.
static func versus(profile, player, g) -> int:
	var r := Gear.rec(g)
	if r.is_empty():
		return 0
	var so := setoff_gear(profile, player)
	for sl in Gear.carry_slots(Gear.slot_of(r)):
		if Gear.same(so.get(sl, {}), r):
			return 0
	var other = worn_against(profile, player, r)
	var n := 0
	for row in Gear.compare(r, other, 12):
		n += int(row[3])
	if other == null:
		n = maxi(n, 1)
	return n


## The indices of a list (your stash or pack) to show, filtered by slot
## (`slot`: "all" or a slot) and essence (`kind`: "all" or a kind), and
## sorted (`sort`, STASH_SORTS).
static func sorted_indices(list: Array, sort := "newest", slot := "all", kind := "all") -> Array:
	var idx: Array = []
	for i in list.size():
		var r := Gear.rec(list[i])
		if r.is_empty():
			continue
		if slot != "all" and Gear.slot_of(r) != slot:
			continue
		if kind != "all" and gear_kind(r) != kind:
			continue
		idx.append(i)
	match sort:
		"newest":
			idx.reverse()
		"rarity":
			idx.sort_custom(func(a, b): return _key_rarity(list[a], a) > _key_rarity(list[b], b))
		"slot":
			idx.sort_custom(func(a, b): return _key_slot(list[a], a) < _key_slot(list[b], b))
		"kind":
			idx.sort_custom(func(a, b): return _key_kind(list[a], a) < _key_kind(list[b], b))
		"price":
			idx.sort_custom(func(a, b): return _key_price(list[a], a) > _key_price(list[b], b))
	return idx


static func _key_rarity(g, i: int) -> float:
	return Gear.rarity_rank(Gear.rarity(g)) * 10000.0 + gear_price(g) + i * 0.0001


static func _key_slot(g, i: int) -> float:
	return SLOT_ORDER.find(Gear.slot_of(g)) * 100000.0 - Gear.rarity_rank(Gear.rarity(g)) * 1000.0 + i * 0.01


static func _key_kind(g, i: int) -> float:
	return Essence.KINDS.keys().find(gear_kind(g)) * 100000.0 - gear_price(g) * 10.0 + i * 0.01


static func _key_price(g, i: int) -> float:
	return gear_sell(g) * 1000.0 + Gear.rarity_rank(Gear.rarity(g)) + i * 0.0001
