extends RefCounted
## How banked essence flows into the climber: the split at a stair, eating
## crystals, tinctures, and the new ways to earn a mark. Every word and number
## of it lives here, in plain data (the Data editor: "Essence flow"); the
## bookkeeping is in profile.gd (pour, drink), the moments in main.gd.
##
## THE SPLIT. At each stair the essence you bank is divided, not copied:
##   body      soaks into your body parts, by what each part did on the
##             floor (unmarked parts fill toward a new mark; every part
##             settles it as density, your attributes)
##   marks     goes to your marks: each kind to the marks of that kind (shared
##             if two are), and a kind no mark is made of spreads thinly over
##             all of them (profile.gd AFFINITY_WEIGHT, OTHER_WEIGHT)
##   crystals  condenses into essence crystals, the train's money
## The crystal share is the "To crystals" setting (train.gd CONDENSE_*); the
## body and the marks share what's left in SPLIT's proportions. With no mark
## to take it (the first climb), the marks' share goes to the body; the
## Unbound pool everything but the crystals raw in their parts.
##
## CRYSTALS can be eaten (the climber's book, the Inventory, Your Car): their
## essence flows the same natural way, minus the crystal share. No steering.
##
## TINCTURES (items.gd, the tincture block) are the only way the marked
## steer essence: drink one and choose a mark (its xp; its own kind counts
## fully, profile.gd AFFINITY_WEIGHT) or an unmarked body part (its soak,
## toward a new mark, and the next mark's kind). Found in vaults, secret
## rooms and, rarely, on a fallen monster; sold at the outfitter (one kind a
## visit); crafted at the Workshop from crystals of their kind.
##
## EARNED MARKS. A fully soaked part can take a new mark before the summit
## only by breaking into a sealed wing early (floor EARNED.last_floor or lower),
## keeping its rule and beating it: the Maker of Marks grants it (makers.gd
## grant_mark). At most one new mark a climb. A fall with a fully soaked part
## has a small chance (FALL_MARK) to leave a faint mark on it.

const Essence := preload("res://scripts/essence.gd")

## The split at a stair, in percent. "crystals" is only the default: the
## setting chooses it, and body and marks keep their proportions of the rest.
static var SPLIT := {"body": 30.0, "marks": 40.0, "crystals": 30.0}

## Tinctures: the essence each holds; how much of it soaks into an unmarked
## part (the body share soaks at profile.gd SOAK_RATE); what crafting one
## costs at the Workshop (crystals of its kind; a Rune Artist pays
## bench.gd RUNE_ARTIST_BREW of it); how many kinds the outfitter stocks each
## visit (the tower you last climbed half the time; more kinds make his
## shelf a row taller); the chance a vault's third card is one, and that a
## hidden crystal cache holds one in place of a crystal. (A slain monster's
## tincture is in the drop table: items.gd DROPS "tincture_chance". The
## outfitter's price is the tincture's worth in items.gd.) "mark_boost": a
## tincture's essence is concentrated: drunk into a mark it grows it this many
## times what the same banked essence would (profile.gd drink).
static var TINCTURE := {"essence": 40.0, "soak_rate": 2.0, "craft": 40, "store_kinds": 1,
	"vault_chance": 0.2, "hidden_chance": 0.3, "mark_boost": 3.2}

## Earned marks: a sealed wing beaten with its rule kept on this floor or
## lower can bring a new mark (the Maker in "maker" grants it). The Entity
## hints at it once a part is "near" full (of what a mark needs).
static var EARNED := {"last_floor": 6, "maker": "marks", "near": 0.75}

## A fall with a fully soaked part: the chance it takes a faint mark.
static var FALL_MARK := {"chance": 0.12}

static var TEXT := {
	# The stair's line: what was banked and where it went.
	"split": "Banked %d: %d to your body, %d to your marks, %d into crystals",
	"split_body": "Banked %d: %d to your body, %d into crystals",
	"split_raw": "Banked %d: %d pools raw in your body, %d into crystals",
	# Eating crystals.
	"ate": "Ate %d %s: %d to your body, %d to your marks",
	"ate_body": "Ate %d %s: it soaks into your body",
	"ate_raw": "Ate %d %s: it pools raw in your %s",
	# Tinctures.
	"drank": "%s: %s",
	"to_mark": "+%d growth for %s",
	"to_soak": "your %s soaks it up (%d%% full)",
	"to_raw": "it pools raw in your %s",
	"faint_paid": "it pays down the faint mark's debt",
	# The page (pour_page.gd).
	"title": "Crystals and tinctures",
	"sub": "Eat a crystal and it flows into you the natural way. Drink a tincture and you choose where it goes.",
	"eyebrow": "Your essence",
	"open": "Crystals and tinctures",
	"crystals_head": "Crystals  ·  eat one: it flows the natural way",
	"tinctures_head": "Tinctures  ·  drink one: you choose where",
	"tinctures_none": "No tinctures. Vaults and secret rooms hold them, the outfitter sells one kind each visit, and the Workshop crafts them from crystals.",
	"tinctures_none_play": "No tinctures on your belt. Vaults and secret rooms hold them, and now and then a monster leaves one.",
	"crystal_card": "%d %s essence in your crystal.",
	"crystal_flow": "Eaten, %d flows the natural way: %d%% to your body, %d%% to your marks. You can't steer it.",
	"crystal_flow_body": "Eaten, %d soaks into your body the natural way. You can't steer it.",
	"crystal_flow_raw": "Eaten, %d pools raw in your %s, as banked essence does.",
	"eat": "Eat %d",
	"tincture_card": "Holds %d %s essence. Drink it and choose where it goes:",
	"tincture_have": "You have %d (%s).",
	"on_belt": "on your belt",
	"packed": "packed for your next climb",
	"target_mark": "%s: %s, step %d",
	"target_mark_own": "%s: %s, step %d  ·  its own kind",
	"target_top": "%s: %s, step 5 (grown as far as it goes)",
	"target_soak": "%s: unmarked, %d%% full",
	"target_full": "%s: full, ready for a mark",
	"target_raw": "%s: level %d",
	"none_crystal": "No %s crystal yet.",
	"drink_from_bench": "Drink one",
	"drink_from_loadout": "Drink it now",
	# The Workshop's tincture counter (bench.gd).
	"craft": "Craft",
	"crafted": "Crafted: %s, packed for your next climb",
	"craft_note": "A tincture holds %d of its kind. Crafted from crystals of that kind.",
	# The Maker's grant (makers.gd grant_mark).
	"granted": "Essence takes hold in your %s: the %s mark",
	# A fall that leaves a faint mark.
	"fall_mark": "As you fall, essence takes hold in your full %s: a faint %s mark",
}


## The split as fractions {body, marks, crystals}, the crystals at `crystal_share`
## (0 to 1): body and marks share the rest in SPLIT's proportions.
static func shares(crystal_share: float) -> Dictionary:
	var c := clampf(crystal_share, 0.0, 1.0)
	var b := maxf(0.0, float(SPLIT.get("body", 30.0)))
	var m := maxf(0.0, float(SPLIT.get("marks", 40.0)))
	var bm := b + m
	if bm <= 0.0:
		b = 1.0
		bm = 1.0
	return {"body": (1.0 - c) * b / bm, "marks": (1.0 - c) * m / bm, "crystals": c}


## The default crystal share (SPLIT's own), 0 to 1.
static func default_crystal_share() -> float:
	return clampf(float(SPLIT.get("crystals", 30.0)) / 100.0, 0.0, 1.0)


## The tincture item of a kind ("tincture_fire"), and back.
static func tincture_id(kind: String) -> String:
	return "tincture_" + kind


static func is_tincture(id: String) -> bool:
	return id.begins_with("tincture_")


static func tincture_kind(id: String) -> String:
	return id.trim_prefix("tincture_") if is_tincture(id) else ""


## Every tincture item id, in the kinds' order.
static func tinctures() -> Array:
	return Essence.KINDS.keys().map(func(k): return tincture_id(String(k)))

