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
const Renown := preload("res://scripts/renown.gd")
const Boons := preload("res://scripts/boons.gd")
const VESSEL := "res://scripts/vessel.gd"  # (loaded when needed: vessel.gd preloads the bench, which preloads this)

## The cars, front to back: [id, name]. The train opens on HOME. (Their short
## names on a phone, and the line under each on a computer, are rail.gd
## TRAIN_CARS.)
const CARS := [["engine", "Engine"], ["store", "Outfitter's Car"], ["personal", "Your Car"], ["workshop", "Workshop"],
	["library", "Library"], ["settings", "Settings & Controls Car"]]
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

## The outfitter's upgrades: your renown rank (renown.gd RANKS) unlocks
## each one, for good. The Outfitter's Car shows them on a placard (the next
## one, and what unlocks it). Their numbers are UPGRADE_FX.
##   wide_rack  more pieces on the outfit rail (rack_extra)
##   scroll     the recall scroll he always stocks costs less (scroll_price)
##   stock      rack pieces may come Fine (rack_fine, in percent) and
##              today's piece rolls on STOCK_ODDS
##   discount   everything he sells costs less (discount; boons.gd adds more)
##   order      a special order: he holds one piece you choose (from the
##              rack or the case) until you buy it, on any later visit
static var UPGRADES := [
	{"id": "wide_rack", "rank": 1, "name": "A wider rack", "desc": "Two more pieces hang on the outfit rail."},
	{"id": "scroll", "rank": 2, "name": "A scroll kept aside", "desc": "The recall scroll he always stocks costs 40 of any kind, not 60."},
	{"id": "stock", "rank": 3, "name": "Better stock", "desc": "Rack pieces may come Fine, and today's piece is likelier Rare, now and then Storied."},
	{"id": "discount", "rank": 4, "name": "A regular's discount", "desc": "Everything he sells costs 10% less."},
	{"id": "order", "rank": 5, "name": "Special order", "desc": "He holds one piece you choose, from the rack or the case, until you come back for it."},
]
static var UPGRADE_FX := {"rack_extra": 2, "scroll_price": 40, "rack_fine": 25, "discount": 0.1}
static var STOCK_ODDS := {"fine": 50, "rare": 45, "storied": 5}

## A piece's base price: what it costs at the store (and sells from) is this
## times its rarity's RARITY_PRICE. Rings, amulets and the Climber's Pack are
## never Common: their number here is what a plain one would cost.
static var BASE_PRICE := {
	"dagger": 10, "sword": 12, "axe": 12, "mace": 12, "spear": 12, "greatsword": 15, "war_hammer": 15, "cane": 8, "sword_cane": 14,
	"shortbow": 12, "longbow": 14, "crossbow": 15, "flintlock": 16, "revolver": 18,
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
## The staples (items.gd "staple": Healing and Stamina Draughts) cost half
## their small worth (items.gd "value") at the store: cheap enough for every
## climber. Everything else is rarer and costs its full worth. (A belt left
## over at the end of a climb still breaks into crystals at half its worth.)
static var SUPPLY_PRICE := {"draught": 3, "stamina": 3}
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
	"home_worn": "You come down wearing what you found: %d %s",
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
	"sell_ask": "{again} to sell for %d %s",
	"sold": "Sold: %s for %s",
	# Store car
	"store_sub": "Kept by the outfitter. He buys what climbers bring down, and sells it to the next ones up.",
	"supplies_note": "Supplies are packed onto your belt for your next climb, beside the Healing and Stamina Draughts every climb starts with.",
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
	"loadout": "Loadout",  # what you'll wear, and your pack (loadout_page.gd)
	"loadout_short": "Loadout",
	"stash": "Stash",  # the stash screen (stash_page.gd)
	"stash_short": "Stash",
	"buy_pack": "Buy: into your pack",
	"buy_chest": "Buy: into your stash",
	"buy_wear": "Buy and wear it",
	"afford": "You can afford it.",
	"show": "Show: %s",
	"sort_by": "Sort: %s",
	"wear_tag": "You'll wear",
	# The outfitter's upgrades (UPGRADES) and the special order
	"upgrades": "Upgrades  ·  %d of %d",
	"upgrades_short": "Upgrades",
	"upgrades_title": "The outfitter's upgrades",
	"upgrades_note": "Your renown unlocks them: %s. Win renown on climbs and at a station.",
	"upgrade_on": "%s: %s",
	"upgrade_off": "%s: at the rank of %s (%d renown)",
	"upgrade_next": "Next: %s, at the rank of %s",
	"upgrade_all": "Every upgrade is yours.",
	"order": "Special order",
	"order_empty": "Nothing held. Choose a piece on the rack or in the case and ask him to hold it.",
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


## The consumables the store sells: always the same shelf, the cheap staples
## first, then the rest in Items.ORDER (the recall scroll among them, always
## there; only the outfit rail and today's piece change between visits).
static func supplies() -> Array:
	var all: Array = Items.ORDER.filter(func(id): return not Items.ITEMS[id].get("value", {}).is_empty())
	return all.filter(func(id): return Items.is_staple(id)) + all.filter(func(id): return not Items.is_staple(id))


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
	profile.store = {"outfit": roll_outfit(profile).map(func(g): return Gear.code(g)), "today": Gear.code(roll_today(profile))}


# --- the outfitter's upgrades (renown) ------------------------------------------------------

## True once your renown rank has unlocked this upgrade (UPGRADES).
static func upgraded(profile, id: String) -> bool:
	if profile == null:
		return false
	for u in UPGRADES:
		if String(u["id"]) == id:
			return Renown.rank(profile) >= int(u["rank"])
	return false


## How many upgrades are unlocked.
static func upgrades_done(profile) -> int:
	return UPGRADES.filter(func(u): return upgraded(profile, String(u["id"]))).size()


## The next upgrade still locked ({} once they're all yours).
static func next_upgrade(profile) -> Dictionary:
	for u in UPGRADES:
		if not upgraded(profile, String(u["id"])):
			return u
	return {}


## How many pieces hang on the outfit rail.
static func rack_size(profile) -> int:
	return RACK_SIZE + (int(UPGRADE_FX["rack_extra"]) if upgraded(profile, "wide_rack") else 0)


## What the outfitter takes off his prices (0 to 1): his upgrade and your boons.
static func discount(profile) -> float:
	if profile == null:
		return 0.0
	var d := float(UPGRADE_FX["discount"]) if upgraded(profile, "discount") else 0.0
	return clampf(d + Boons.discount(profile), 0.0, 0.9)


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
	if id == "scroll" and price[0] == ANY and upgraded(profile, "scroll"):
		amount = mini(amount, int(UPGRADE_FX["scroll_price"]))
	return [price[0], maxi(1, int(round(float(amount) * (1.0 - discount(profile)))))]


## The special order: the piece he holds for you ({} for none).
static func order(profile) -> Dictionary:
	if profile == null:
		return {}
	return Gear.rec(Renown.state(profile)["order"])


## Asks him to hold a piece off the rack (`i`) or today's piece (i = -1):
## it leaves the rack and waits as your special order. "" if done, else why not.
static func hold(profile, i: int) -> String:
	if not upgraded(profile, "order"):
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


## RACK_SIZE different Common pieces (more with the wider rack), in the
## order the inventory lists slots. With better stock some come Fine.
static func roll_outfit(profile = null) -> Array:
	var pool := common_pool()
	pool.shuffle()
	var pick: Array = pool.slice(0, rack_size(profile))
	var slots: Array = ["melee", "ranged", "armor"] + Gear.PIECE_SLOTS
	pick.sort_custom(func(a, b): return slots.find(Gear.slot_of(a)) < slots.find(Gear.slot_of(b)))
	var fine := upgraded(profile, "stock")
	return pick.map(func(id): return Gear.make(id, "fine", Gear.roll_traits(id, "fine")) if fine and randi() % 100 < int(UPGRADE_FX["rack_fine"]) else Gear.make(id))


## Today's piece: Fine or Rare (TODAY_ODDS; STOCK_ODDS with better stock), with its traits.
static func roll_today(profile = null) -> Dictionary:
	var odds: Dictionary = STOCK_ODDS if upgraded(profile, "stock") else TODAY_ODDS
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


## Buys a piece off the rack (`i`) or today's piece (i = -1) into your pack
## (`to` "pack"), your stash ("chest"), or straight onto you ("wear": into
## your pack, then worn, what you wore there going back into the pack).
## "" if bought, else why not.
static func buy_gear(profile, player, i: int, to := "pack") -> String:
	var g: Dictionary = order(profile) if i == -2 else (today(profile) if i < 0 else (outfit(profile)[i] if i < outfit(profile).size() else {}))
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
	if i == -2:
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
		if pack_size_with(profile, after) < profile.pack.size() + (1 if old != null else 0):
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
	if not profile.wear.is_empty():
		dress(profile, player)  # (what you chose to wear goes on first, over the heirloom or starting piece)
	var starts := {"melee": Gear.make(Gear.Weapons.START_MELEE), "ranged": Gear.make(Gear.Weapons.START_RANGED)}
	for g in profile.pack:
		var r := Gear.rec(g)
		if r.is_empty():
			continue
		var slot: String = player.slot_for(r)
		var held = player.gear.get(slot, {})
		var free: bool = not Gear.is_gear(held) or (starts.has(slot) and Gear.same(held, starts[slot]) and not profile.wear.has(slot) \
			and Gear.heirloom_pieces(profile.heirlooms, Gear.heirloom_slot_for_carry(slot)).is_empty())
		if free:
			player.take_gear(r, slot)
		else:
			player.pack.append(r)
	profile.pack = []
	profile.wear = {}  # (it's on you now: worn pieces, like any you find)
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


# --- the loadout: what you'll wear when you set off ---------------------------------
# On the train you choose what to wear from your pack or your stash
# (loadout_page.gd). The chosen pieces (profile.wear: carried slot ->
# record) go on as you depart, over your heirloom or the starting piece in
# that slot (an heirloom you don't wear waits on the train, still yours);
# from then on they're worn pieces like any you find. Pieces left in your
# pack still go on in a slot nothing is worn in (pack_up). The climber on
# the train wears the loadout already (dress), so the climber screen and
# the figure show it.

## The slots you can wear something in (not the off-hand: kept for later).
const WEAR_SLOTS := ["melee", "ranged", "armor", "helm", "gloves", "legs", "boots", "cloak", "amulet", "ring1", "ring2", "backpack"]

## The sorts and filters of the stash screen (stash_page.gd): [id, name].
## A slot filter is "all" or a slot (Gear.slot_of); an essence filter "all"
## or a kind.
static var STASH_SORTS := [["newest", "Newest"], ["rarity", "Rarity"], ["slot", "Slot"], ["kind", "Essence"], ["price", "Price"]]
static var SLOT_FILTERS := [["all", "All slots"], ["melee", "Melee"], ["ranged", "Ranged"], ["armor", "Chest"], ["helm", "Helm"], ["gloves", "Gloves"],
	["legs", "Legs"], ["boots", "Boots"], ["cloak", "Cloak"], ["amulet", "Amulet"], ["ring", "Rings"], ["backpack", "Backpack"]]
## The outfit rail's filter, and where selling shows pieces from: [id, name].
static var RACK_FILTERS := [["all", "Everything"], ["better", "Better than yours"], ["weapons", "Weapons"], ["armour", "Armour"], ["more", "Cloaks and packs"]]
static var SELL_FROM := [["all", "Pack and stash"], ["pack", "Your pack"], ["chest", "Your stash"]]
const RACK_GROUPS := {"weapons": ["melee", "ranged"], "armour": ["armor", "helm", "gloves", "legs", "boots"], "more": ["cloak", "backpack", "amulet", "ring"]}
const SLOT_ORDER := ["melee", "ranged", "armor", "helm", "gloves", "legs", "boots", "cloak", "amulet", "ring", "backpack"]


## What you'd wear with these chosen pieces (`wear`, else profile.wear):
## the starting sword and bow, your heirlooms in their slots, then the chosen
## pieces over them (carried slot -> record).
static func dressed(profile, wear = null) -> Dictionary:
	var chosen: Dictionary = profile.wear if wear == null else wear
	var g := Gear.start_gear()
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
## "from" is "wear" (chosen), "heir" (your heirloom), "start" (the sword or
## bow every climb starts with) or "pack" (a pack piece that goes on because
## nothing else is worn there; its "i" in the pack). Empty slots are left out.
static func setoff(profile, _player = null) -> Dictionary:
	var g := dressed(profile)
	var starts := {"melee": Gear.make(Gear.Weapons.START_MELEE), "ranged": Gear.make(Gear.Weapons.START_RANGED)}
	var out := {}
	for slot in WEAR_SLOTS:
		var r = g.get(slot, {})
		if not Gear.is_gear(r):
			continue
		var from := "wear" if profile.wear.has(slot) else ("start" if starts.has(slot) and Gear.same(r, starts[slot]) else "heir")
		if from == "start" and not Gear.heirloom_pieces(profile.heirlooms, Gear.heirloom_slot_for_carry(slot)).is_empty():
			from = "heir"  # (an heirloom that's the very same as the starting piece)
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
		if held.is_empty() or held["from"] == "start":
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


## How many pieces your pack holds with these chosen pieces worn (a
## Climber's Pack holds more).
static func pack_size_with(profile, wear: Dictionary) -> int:
	return Gear.PACK_SIZE + int(Gear.total_effects(dressed(profile, wear)).get("pack", 0))


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
	if pack_size_with(profile, after) < pack_after:
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
		if profile.pack.size() > cap:
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



## Does the outfit rail show this piece under a filter (RACK_FILTERS)? A
## sold space shows only with "all".
static func rack_shows(profile, player, g, filter: String) -> bool:
	if filter == "all":
		return true
	if not Gear.is_gear(g):
		return false
	if filter == "better":
		return versus(profile, player, g) > 0
	return Gear.slot_of(g) in RACK_GROUPS.get(filter, [])
