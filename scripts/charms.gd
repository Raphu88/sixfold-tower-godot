extends RefCounted
## Charms: the climber's one charm slot (the owner's design: "charms should
## be different than consumables; perhaps they are a thing that can be
## equipped"). A charm is worn gear, never used up:
##   - a PASSIVE that is always on while you wear it (its numbers in
##     gear.gd PIECES, read like any worn piece's: more stamina, a quicker
##     roll, a shield that grows back, an extra belt kind or pack space, a
##     safe pocket...)
##   - on some, a CHARGE ("charge": an id in CHARGES): an effect that fires
##     by itself when its moment comes (a blow that would fell you, a shell
##     that would turn your strike...). The charge is the charm's OWN
##     ESSENCE POOL (item_pool.gd, the rule every essence item follows): it
##     fires from the charm's pool first, and once that is spent, from the
##     essence you carry (not yet banked). Nothing refills it on its own:
##     you refill it by FILTERING ESSENCE IN, on the train at the workshop
##     bench with crystals of the charm's kind, or in the tower from the
##     inventory, with essence you carry (not while a monster is after you).
## Charms come from the workshop bench (CRAFT), the outfitter's rail
## (SHOP) and, now and then, the towers (LOOT: vaults, secret rooms, a rare
## drop). They come home like other worn gear (a recall or the summit) and
## are lost on a fall like it (but the Keeper's Purse keeps itself and its
## pocket), and can be kept as an heirloom (the Charm heirloom slot).
##
## A charm's charges left are kept on its record ("charge"; none noted is
## full). Names, words and numbers live here and in gear.gd PIECES (the
## Data editor: Words -> Gear, and Numbers -> Charms), so they're easy to
## change.

const Gear := preload("res://scripts/gear.gd")
const Essence := preload("res://scripts/essence.gd")
const TRAIN := "res://scripts/train.gd"  # (loaded when needed: the train preloads this)

## The charged effects (gear.gd PIECES "charge"):
##   name, desc  what the card says it does
##   max         how many charges it holds
##   refill      essence to refill one charge (the bench: crystals of the
##               charm's kind; the tower: unbanked essence of any kind)
## and its own numbers:
##   wardbreak   the first time a shell or guard would turn your blow
##               ("foes"), for "duration" seconds your blows and arrows go
##               through shells and guards
##   mend        falling below "below" of your health heals "heal" over "time"
##   rally       a blow that would fell you leaves you at "health" of yours
##   gust        a blow that lands on you hurls the foes within "radius" back
##   breath      running out of stamina fills "share" of it back at once
##   veil        a blow that lands on you while you're below "below" of your
##               health wraps you in mist "radius" wide for "time" seconds:
##               monsters in it lose track of you (as a Smoke Bomb; beasts don't)
static var CHARGES := {
	"wardbreak": {"name": "Snap the ward", "desc": "the first time a shell or guard would turn your blow, its ward snaps: for 20 seconds your blows and arrows go through shells and guards",
		"max": 1, "refill": 12, "duration": 20.0, "foes": ["shellback", "knight", "mirror"]},
	"mend": {"name": "Mend", "desc": "falling below a third of your health heals you 25 over 2 seconds",
		"max": 2, "refill": 8, "heal": 25.0, "time": 2.0, "below": 0.34},
	"rally": {"name": "Rally", "desc": "a blow that would fell you leaves you standing, at 30% of your health",
		"max": 1, "refill": 30, "health": 0.3},
	"gust": {"name": "Gust", "desc": "a blow that lands on you hurls the foes around you back",
		"max": 3, "refill": 6, "radius": 120.0, "push": 560.0, "dmg": 4.0},
	"breath": {"name": "Second breath", "desc": "running out of stamina fills half of it back at once",
		"max": 2, "refill": 8, "share": 0.5},
	"veil": {"name": "Veil of mist", "desc": "a blow that lands on you below half your health wraps you in mist for 4 seconds: monsters inside lose track of you (beasts don't)",
		"max": 2, "refill": 10, "below": 0.5, "radius": 90.0, "time": 4.0},
	# The off-hand's own essence pools (offhand.gd): an enchanted off-hand
	# piece's power, a use spent each time it fires, refilled as a charge is.
	"ember_strike": {"name": "Ember strike", "desc": "its off-hand stab sets the foe burning (3 every half second for 3 seconds)",
		"max": 6, "refill": 3, "dmg": 3.0, "time": 3.0},
	"tide_block": {"name": "Undertow", "desc": "a blow you block sends a wave out that hurls the foes around you back",
		"max": 3, "refill": 6, "radius": 110.0, "push": 480.0, "dmg": 4.0},
	"wand_stone": {"name": "Hurl stone", "desc": "a stone that hits for 12 and staggers the foe",
		"max": 6, "refill": 3, "dmg": 12.0, "stagger": 0.6, "speed": 520.0},
	"wand_blade": {"name": "Shard fan", "desc": "three spinning shards, 6 each",
		"max": 6, "refill": 3, "dmg": 6.0, "shards": 3, "fan": 0.22, "speed": 640.0},
	"wand_iron": {"name": "Iron ward", "desc": "a 20-point barrier round you for 6 seconds",
		"max": 3, "refill": 6, "shield": 20.0, "time": 6.0},
	"wand_air": {"name": "Gust", "desc": "a gust that hurls the foes in front of you back, for 4",
		"max": 6, "refill": 3, "dmg": 4.0, "reach": 130.0, "half": 40.0, "push": 520.0},
	"wand_fire": {"name": "Cinder bolt", "desc": "a bolt for 8 that sets the foe burning",
		"max": 6, "refill": 3, "dmg": 8.0, "burn": 3.0, "burn_t": 3.0, "speed": 560.0},
	"wand_water": {"name": "Chill bolt", "desc": "a cold bolt for 8 that slows the foe for 2 seconds",
		"max": 6, "refill": 3, "dmg": 8.0, "chill": 2.0, "speed": 560.0},
}

## The auras' numbers: the Tide Shell's shield grows back once you've gone
## "tide_wait" seconds without being hit, at "tide_rate" points a second.
static var AURA := {"tide_wait": 6.0, "tide_rate": 6.0}

## Charms are crafted at the workshop bench (bench.gd, its Charms counter:
## by a Rune Artist, or the workshop's Rune Artist for anyone else, materials
## + premium): what each costs, in crystals. A crafted charm goes into your
## stash (your pack if the stash is full).
static var CRAFT := {
	"lucky_knot": {"iron": 10}, "pocket_clasp": {"iron": 12}, "belt_hook": {"iron": 12},
	"ember_charm": {"fire": 30}, "feather_token": {"air": 30}, "iron_brooch": {"iron": 30}, "ward_stone": {"stone": 32},
	"tide_shell": {"water": 34}, "wardbreaker": {"blade": 30}, "mending_bead": {"water": 32},
	"keepers_purse": {"iron": 70}, "ashen_knot": {"fire": 70}, "gale_charm": {"air": 65}, "bulwark_stone": {"stone": 65},
	"hunters_token": {"air": 10}, "brass_bellows": {"iron": 30}, "duelists_ribbon": {"blade": 65}, "mist_pearl": {"water": 70},
}

## Recipes a climber must LEARN before crafting (the rest are known
## from the start): a renown rank teaches some (renown.gd RANK_OPENS
## "recipe"), and a noble's contract now and then teaches one (contracts.gd).
## Learned ones are kept with the climber (renown.gd state "recipes").
static var LOCKED := ["mending_bead", "keepers_purse", "tide_shell", "bulwark_stone", "gale_charm", "ashen_knot", "duelists_ribbon", "mist_pearl"]

## The outfitter's rail (train.gd roll_outfit): "rack" charms hang on it
## every visit, Common by nature, or a Fine charm "fine" times in 100.
static var SHOP := {"rack": 1, "fine": 30}

## Found in the towers: a vault's third card is a charm this often ("vault"),
## a secret room's crystals this often add a charm ("secret"), and a slain
## monster (not a beast) leaves one this rarely ("monster"). A found charm's
## rarity rolls like other finds (gear.gd RARITY_ODDS), "higher" rows up;
## a Storied roll is a Rare charm.
static var LOOT := {"vault": 0.2, "secret": 0.3, "monster": 0.004, "higher": 1}

## Consumables that became charms: an old save's packed ones give back what
## was paid for them (else "refund"), as crystals.
static var OLD_ITEMS := {"wardbreaker": {"refund": {"blade": 10}}}

## The words charms use (cards, the bench, the tower's inventory).
static var TEXT := {
	"charge": "Charge  ·  %d of %d",
	"charge_line": "%s: %s",
	"charge_empty": "Spent: now its charge draws on the essence you carry. Filter essence in to refill it, at the workshop bench or from the inventory in a tower. Nothing refills it on its own.",
	"charge_full": "Charged.",
	"never_used": "A charm is never used up. Its passive is always on while you wear it.",
	"refill": "Refill: %s",
	"refill_ask": "Refill this charm for %s?",
	"refill_run": "Feed it %d unbanked essence",
	"refill_run_ask": "Feed this charm %d of the essence you carry?",
	"refilled": "%s is charged again",
	"short_run": "needs %d unbanked essence (you carry %d)",
	"run_note": "Essence you haven't banked at a stair feeds it here, any kind.",
	"train_note": "On the train, refill it at the workshop bench with %s crystals.",
	"spent": "%s: %s",
	"safe": "Safe",
	"safe_note": "Safe pocket: the first piece in your pack comes home even if you fall.",
	"kept": "Your %s keeps: %s",
	"kept_purse": "Your %s comes home with you",
	"craft": "Craft it",
	"craft_ask": "Craft this charm? What it costs is spent.",
	"crafted": "Crafted: %s, in your stash",
	"crafted_pack": "Crafted: %s, in your pack",
	"no_room": "your stash and pack are full",
	"refill_head": "Your charms",
	"craft_head": "Craft a charm",
	"nothing_spent": "Every charm you own is charged.",
	"note": "Refill a charm's charge with crystals of its kind. New charms are crafted here too: by you if you carry the Rune Artist's mark, else by the workshop's Rune Artist.",
	"old_refund": "%s became a charm: what you paid came back (%s)",
	"recipe_locked": "A recipe not yet learned. Your renown rank teaches it (%s), or a noble's contract may.",
	"recipe_contract": "A recipe not yet learned. A noble's contract may teach it.",
	"refill_cut": "Your renown makes refills %d%% cheaper.",
}


# --- what a charm is -------------------------------------------------------------------

static func is_charm(g) -> bool:
	return Gear.is_gear(g) and Gear.slot_of(g) == "charm"


## A charm's charged effect id (CHARGES), or "" for a passive-only charm.
static func charge_id(g) -> String:
	var id := String(Gear.PIECES.get(Gear.base_id(g), {}).get("charge", ""))
	return id if CHARGES.has(id) else ""


## How many charges it holds when full (0 for none). An enchanted weapon's
## own essence pool counts the same way (item_pool.gd WEAPON): every essence
## item keeps its pool as "charge" uses, refilled as a charm's charge is.
static func charge_max(g) -> int:
	var id := charge_id(g)
	if id != "":
		return int(CHARGES[id]["max"])
	return _pool().weapon_max(g)


## The essence one charge (one use of its pool) is worth.
static func refill_per(g) -> int:
	var id := charge_id(g)
	if id != "":
		return int(CHARGES[id]["refill"])
	return _pool().weapon_refill(g)


const POOL := "res://scripts/item_pool.gd"  # (loaded when needed: it loads this)


static func _pool():
	return load(POOL)


## How many charges it has left (a record with none noted is full).
static func charges(g) -> int:
	var most := charge_max(g)
	if most <= 0:
		return 0
	if g is Dictionary and g.has("charge"):
		return clampi(int(g["charge"]), 0, most)
	return most


static func missing(g) -> int:
	return charge_max(g) - charges(g)


## A charged effect's number (CHARGES), or `def`.
static func num(id: String, key: String, def := 0.0) -> float:
	return float(CHARGES.get(id, {}).get(key, def))


## Spends one charge from a charm record (in place). True if it had one.
static func spend(g: Dictionary) -> bool:
	if charges(g) <= 0:
		return false
	g["charge"] = charges(g) - 1
	return true


## What refilling every spent charge costs, in essence (less your renown's
## cut, refill_cut, given the climber).
static func refill_amount(g, profile = null) -> int:
	if charge_max(g) <= 0 or missing(g) <= 0:
		return 0
	var full := refill_per(g) * missing(g)
	return maxi(1, int(round(float(full) * (1.0 - refill_cut(profile)))))


## The share your renown rank takes off a charm's refill (RANK_OPENS "refill").
static func refill_cut(profile) -> float:
	if profile == null:
		return 0.0
	var cut := 0.0
	for e in load("res://scripts/renown.gd").opened(profile, "refill"):
		cut = maxf(cut, float(e.get("cut", 0.0)))
	return clampf(cut, 0.0, 0.9)


# --- recipes -------------------------------------------------------------------------------

## Does the climber know how to craft this charm (not LOCKED, learned, or
## taught by their rank)?
static func recipe_known(profile, id: String) -> bool:
	if not LOCKED.has(id):
		return true
	if profile == null:
		return false
	var R = load("res://scripts/renown.gd")
	if R.state(profile)["recipes"].has(id):
		return true
	for e in R.opened(profile, "recipe"):
		if String(e.get("id", "")) == id:
			return true
	return false


## Learns a recipe (a contract's reward). True if it was new.
static func learn(profile, id: String) -> bool:
	if recipe_known(profile, id) or not CRAFT.has(id):
		return false
	load("res://scripts/renown.gd").state(profile)["recipes"].append(id)
	profile.save()
	return true


static func recipe_name(id: String) -> String:
	return String(Gear.PIECES.get(id, {}).get("name", id))


## Why a recipe isn't known yet, in words ("" if it is).
static func recipe_why(profile, id: String) -> String:
	if recipe_known(profile, id):
		return ""
	var R = load("res://scripts/renown.gd")
	var at: int = R.rank_opening("recipe", id)
	return TEXT["recipe_locked"] % R.rank_name(at) if at >= 0 else TEXT["recipe_contract"]


## The crystal kind a charm is refilled (and priced) with: its own essence;
## an ordinary charm's, the slot's (train.gd SLOT_KIND).
static func kind(g) -> String:
	if charge_id(g) == "" and _pool().weapon_max(g) > 0:
		return Gear.enchant_kind(g)  # (an enchanted weapon's pool: its enchantment's essence)
	var k := String(Gear.PIECES.get(Gear.base_id(g), {}).get("kind", ""))
	return k if k != "" else "water"


## The charge's lines for a card: ["Charge · 1 of 2", "Mend: falling below..."].
static func charge_lines(g) -> Array:
	var id := charge_id(g)
	if id == "":
		var wl: Array = _pool().weapon_lines(g)  # (an enchanted weapon's own pool: item_pool.gd)
		return wl.map(func(l): return l[0])
	var c: Dictionary = CHARGES[id]
	return [TEXT["charge"] % [charges(g), charge_max(g)], TEXT["charge_line"] % [c["name"], c["desc"]],
		TEXT["charge_full"] if missing(g) <= 0 else TEXT["charge_empty"]]


# --- refilling ---------------------------------------------------------------------------

## Refills a charm (a record, in place) with crystals of its kind (the
## bench). "" if done, else why not.
static func refill_crystals(profile, g: Dictionary) -> String:
	var amount := refill_amount(g, profile)
	if amount <= 0:
		return TEXT["charge_full"]
	var k := kind(g)
	var why: String = load(TRAIN).short_of(profile, k, amount)
	if why != "":
		return why
	profile.spend(k, float(amount))
	g["charge"] = charge_max(g)
	return ""


## All the essence you carry unbanked (gathered since the last stair).
static func unbanked(main) -> float:
	var held := 0.0
	for k in main.run_essence:
		held += float(main.run_essence[k])
	return held


## Refills the charm you wear in the tower from unbanked essence (each kind
## in its share, as a Tithe Door takes it). "" if done, else why not.
static func refill_unbanked(main, g: Dictionary) -> String:
	var amount := float(refill_amount(g, main.profile if main != null else null))
	if amount <= 0.0:
		return TEXT["charge_full"]
	var held := unbanked(main)
	if held + 0.001 < amount:
		return TEXT["short_run"] % [int(amount), int(held)]
	return _pool().refill_carried(main, g)  # (filtering your essence in: item_pool.gd; an heirloom follows)


# --- worn charms in the tower --------------------------------------------------------

## The charm the climber wears (a record), or {}.
static func worn(p) -> Dictionary:
	if p == null:
		return {}
	var g = p.gear.get("charm", {})
	return g if g is Dictionary and is_charm(g) else {}


## Spends the worn charm's charge for `id` if it has one left: true if it
## fired (and says so over the climber).
static func fire(p, id: String) -> bool:
	var g := worn(p)
	if g.is_empty() or charge_id(g) != id:
		return false
	# Its own pool first, then the essence you carry (item_pool.gd draw; an
	# heirloom's charges follow). With neither, it stays quiet.
	if _pool().draw(p.main, g) == "":
		return false
	if p.main != null:
		var col := Gear.color(g)
		p.main.fx_text(p.global_position + Vector2(0, -52), TEXT["spent"] % [Gear.display(g), CHARGES[id]["name"]], col)
		p.main.fx_ring(p.global_position, col, 50.0, 0.4, 3.0)
	return true


## A charm kept as an heirloom starts every climb as the heirloom is: so a
## charge spent (or refilled) on the climb is noted on the heirloom too,
## or it would come back full on its own. `was`: its charges before.
static func keep_heirloom(main, g: Dictionary, was: int) -> void:
	_pool().keep_heirloom(main, g, was)  # (every essence item's the same way: item_pool.gd)


# --- the safe pocket ----------------------------------------------------------------------

## Does the climber's charm keep a safe pocket (the Keeper's Purse)?
static func safe_pocket(p) -> bool:
	return p != null and float(Gear.effects(worn(p)).get("safe_pocket", 0.0)) > 0.0


## A fall: the safe pocket's piece (the first in your pack) and the purse
## itself come home to the train (unless the purse is your heirloom, which
## is never lost anyway). Takes them off the climber so the fall doesn't
## count them lost. Returns the lines for the fall screen.
static func keep_on_fall(profile, p) -> Array:
	var out: Array = []
	if not safe_pocket(p):
		return out
	var purse := worn(p)
	if not p.pack.is_empty():
		var kept := Gear.rec(p.pack[0])
		p.pack.remove_at(0)
		if not kept.is_empty():
			profile.pack.append(kept)
			out.append(TEXT["kept"] % [Gear.display(purse), Gear.display(kept)])
	var heir := Gear.heirloom_pieces(profile.heirlooms, "charm").any(func(h): return Gear.same(h, purse))
	if not heir:
		profile.wear["charm"] = Gear.rec(purse)
		out.append(TEXT["kept_purse"] % Gear.display(purse))
	return out


# --- where charms come from ---------------------------------------------------------------

## Every charm, in the order gear.gd lists them.
static func all() -> Array:
	return Gear.PIECE_ORDER.filter(func(id): return Gear.PIECES[id].get("slot", "") == "charm")


## The charms of one rarity ("common", "fine" or "rare").
static func of_rarity(r: String) -> Array:
	return all().filter(func(id): return Gear.natural_rarity(id) == r)


## A charm found in a tower on this floor: its rarity rolled like other
## finds, LOOT "higher" rows up (a Storied roll is Rare).
static func roll(floor_num: int, higher := -1) -> Dictionary:
	var r := Gear.roll_rarity(floor_num, int(LOOT["higher"]) if higher < 0 else higher)
	if Gear.rarity_rank(r) > Gear.rarity_rank("rare"):
		r = "rare"
	var pool := of_rarity(r)
	if pool.is_empty():
		pool = all()
	return Gear.make(pool[randi() % pool.size()])


## Charms for the outfitter's rail this visit (SHOP): Common, now and then Fine.
static func shop_stock(count := -1) -> Array:
	var out: Array = []
	for i in (int(SHOP["rack"]) if count < 0 else count):
		var fine: bool = randi() % 100 < int(SHOP["fine"])
		var pool := of_rarity("fine" if fine else "common")
		pool = pool.filter(func(id): return not out.any(func(o): return o["base"] == id))
		if pool.is_empty():  # (every charm of that rarity is out already: one of the other, so the tray holds as many as it should)
			pool = of_rarity("common" if fine else "fine").filter(func(id): return not out.any(func(o): return o["base"] == id))
		if not pool.is_empty():
			out.append(Gear.make(pool[randi() % pool.size()]))
	return out


## The charms the bench can craft, in order.
static func craftable() -> Array:
	return all().filter(func(id): return CRAFT.has(id))


## Old saves: packed consumables that are charms now give back what was paid.
static func old_supplies(profile) -> void:
	for id in OLD_ITEMS:
		var n := int(profile.supplies.get(id, 0))
		if n <= 0:
			profile.supplies.erase(id)
			profile.supply_paid.erase(id)
			continue
		var paid: Array = profile.supply_paid.get(id, [])
		for i in n:
			var back: Dictionary = paid[i] if i < paid.size() and paid[i] is Dictionary else OLD_ITEMS[id]["refund"]
			for k in back:
				profile.add_crystal(String(k), float(back[k]))
		profile.supplies.erase(id)
		profile.supply_paid.erase(id)
