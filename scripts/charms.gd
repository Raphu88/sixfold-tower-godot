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
##     that would turn your strike...). Once spent it stays spent: nothing
##     refills on its own. You refill it by FEEDING IT ESSENCE, on the train
##     at the workshop bench with crystals of the charm's kind, or in the
##     tower from the inventory, with essence you haven't banked yet.
## Charms come from a Rune Artist's bench (CRAFT), the outfitter's rail
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
static var CHARGES := {
	"wardbreak": {"name": "Snap the ward", "desc": "the first time a shell or guard would turn your blow, its ward snaps: for 20 seconds your blows and arrows go through shells and guards",
		"max": 1, "refill": 12, "duration": 20.0, "foes": ["shellback", "knight", "mirror"]},
	"mend": {"name": "Mend", "desc": "falling below a third of your health heals you 25 over 2 seconds",
		"max": 2, "refill": 8, "heal": 25.0, "time": 2.0, "below": 0.34},
	"rally": {"name": "Rally", "desc": "a blow that would fell you leaves you standing, at 30% of your health",
		"max": 1, "refill": 30, "health": 0.3},
	"gust": {"name": "Gust", "desc": "a blow that lands on you hurls the foes around you back",
		"max": 3, "refill": 6, "radius": 120.0, "push": 560.0, "dmg": 4.0},
}

## The auras' numbers: the Tide Shell's shield grows back once you've gone
## "tide_wait" seconds without being hit, at "tide_rate" points a second.
static var AURA := {"tide_wait": 6.0, "tide_rate": 6.0}

## A Rune Artist crafts charms at the workshop bench (bench.gd, its Charms
## counter): what each costs, in crystals. A crafted charm goes into your
## stash (your pack if the stash is full).
static var CRAFT := {
	"lucky_knot": {"iron": 10}, "pocket_clasp": {"iron": 12}, "belt_hook": {"iron": 12},
	"ember_charm": {"fire": 30}, "feather_token": {"air": 30}, "iron_brooch": {"iron": 30}, "ward_stone": {"stone": 32},
	"tide_shell": {"water": 34}, "wardbreaker": {"blade": 30}, "mending_bead": {"water": 32},
	"keepers_purse": {"iron": 70}, "ashen_knot": {"fire": 70}, "gale_charm": {"air": 65}, "bulwark_stone": {"stone": 65},
}

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
	"charge_empty": "Spent: feed it essence to refill it, at the workshop bench or from the inventory in a tower. Nothing refills it on its own.",
	"charge_full": "Charged.",
	"never_used": "A charm is never used up. Its passive is always on while you wear it.",
	"refill": "Refill: %s",
	"refill_ask": "{again} to refill: %s",
	"refill_run": "Feed it %d unbanked essence",
	"refill_run_ask": "{again}: feed it %d essence",
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
	"craft_ask": "{again} to craft it",
	"crafted": "Crafted: %s, in your stash",
	"crafted_pack": "Crafted: %s, in your pack",
	"no_room": "your stash and pack are full",
	"needs_rune_artist": "Only a Rune Artist can craft a charm. A Rune Artist could make it here, given the essence.",
	"refill_head": "Your charms",
	"craft_head": "Craft a charm",
	"nothing_spent": "Every charm you own is charged.",
	"note": "Refill a charm's charge with crystals of its kind (anyone). A Rune Artist can also craft new charms here.",
	"old_refund": "%s became a charm: what you paid came back (%s)",
}


# --- what a charm is -------------------------------------------------------------------

static func is_charm(g) -> bool:
	return Gear.is_gear(g) and Gear.slot_of(g) == "charm"


## A charm's charged effect id (CHARGES), or "" for a passive-only charm.
static func charge_id(g) -> String:
	var id := String(Gear.PIECES.get(Gear.base_id(g), {}).get("charge", ""))
	return id if CHARGES.has(id) else ""


## How many charges it holds when full (0 for none).
static func charge_max(g) -> int:
	var id := charge_id(g)
	return int(CHARGES[id]["max"]) if id != "" else 0


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


## What refilling every spent charge costs, in essence.
static func refill_amount(g) -> int:
	var id := charge_id(g)
	return int(CHARGES[id]["refill"]) * missing(g) if id != "" else 0


## The crystal kind a charm is refilled (and priced) with: its own essence;
## an ordinary charm's, the slot's (train.gd SLOT_KIND).
static func kind(g) -> String:
	var k := String(Gear.PIECES.get(Gear.base_id(g), {}).get("kind", ""))
	return k if k != "" else "water"


## The charge's lines for a card: ["Charge · 1 of 2", "Mend: falling below..."].
static func charge_lines(g) -> Array:
	var id := charge_id(g)
	if id == "":
		return []
	var c: Dictionary = CHARGES[id]
	return [TEXT["charge"] % [charges(g), charge_max(g)], TEXT["charge_line"] % [c["name"], c["desc"]],
		TEXT["charge_full"] if missing(g) <= 0 else TEXT["charge_empty"]]


# --- refilling ---------------------------------------------------------------------------

## Refills a charm (a record, in place) with crystals of its kind (the
## bench). "" if done, else why not.
static func refill_crystals(profile, g: Dictionary) -> String:
	var amount := refill_amount(g)
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
	var amount := float(refill_amount(g))
	if amount <= 0.0:
		return TEXT["charge_full"]
	var held := unbanked(main)
	if held + 0.001 < amount:
		return TEXT["short_run"] % [int(amount), int(held)]
	for k in main.run_essence.keys():
		main.run_essence[k] = maxf(0.0, float(main.run_essence[k]) - amount * float(main.run_essence[k]) / held)
	g["charge"] = charge_max(g)
	return ""


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
	if g.is_empty() or charge_id(g) != id or not spend(g):
		return false
	if p.main != null:
		var col := Gear.color(g)
		p.main.fx_text(p.global_position + Vector2(0, -52), TEXT["spent"] % [Gear.display(g), CHARGES[id]["name"]], col)
		p.main.fx_ring(p.global_position, col, 50.0, 0.4, 3.0)
	return true


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
static func shop_stock() -> Array:
	var out: Array = []
	for i in int(SHOP["rack"]):
		var pool := of_rarity("fine" if randi() % 100 < int(SHOP["fine"]) else "common")
		pool = pool.filter(func(id): return not out.any(func(o): return o["base"] == id))
		if not pool.is_empty():
			out.append(Gear.make(pool[randi() % pool.size()]))
	return out


## The charms a Rune Artist can craft, in order.
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
