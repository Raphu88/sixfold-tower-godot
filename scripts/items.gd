extends RefCounted
## Items and camps: what the climber can carry, how often monsters drop
## them, and what a camp offers. Names and text live here so they're easy
## to change. The effects are in `use()` at the bottom.

## Each kind of item stacks up to this many.
const MAX_STACK := 3
## The belt holds this many kinds of item (a Belt Pouch or Climber's Pack
## adds one). Picking up another kind with a full belt asks which stack to
## swap out (main.gd offer_belt_swap).
const BELT_KINDS := 4
## Holding the item button this long opens the ring of belt items (time
## slows); a shorter press uses the quick item.
const RING_HOLD := 0.25
## Unused belt items at the end of a survived climb break into essence
## crystals at this share of their worth ("value").
const BREAK_SHARE := 0.5
## What every climb starts with: one of each staple.
const START := {"draught": 1, "stamina": 1}
## The chance that a slain monster (not a beast) leaves an item (most often
## a staple: a Healing Vial, a Stamina Vial or an Essence Vial; the
## other items are rare: DROPS "rare_weight"; a kill that leaves no item may
## leave essence instead: DROPS). Caches and fallen climbers' camps seldom
## hold an item (room_rewards.gd RULES "item_chance", DROPS "fallen_item"):
## a whole climb turns up only a few of the rarer items (the owner: "still
## lots of consumables"), and essence in their place.
const DROP_CHANCE := 0.09
## What drops instead of items, and how a tower steers what's found:
##   essence_chance     the chance a slain monster that left no item leaves
##                      a little more essence of the tower's kind (unbanked,
##                      as every kill's essence)
##   essence_base, essence_per_floor   how much (more higher up)
##   fallen_item        the chance a fallen climber's camp still holds an
##                      item; otherwise their pack holds essence (a cache)
##   handy_weight       a tower's handy items (tower_needs.gd) are this many
##                      times as likely among what's found there
##   rare_weight        a non-staple item's drop_weight counts this much
##                      beside the staples' (a slain monster's item is a
##                      staple nearly every time)
##   tincture_chance    the chance a kill that left neither leaves a tincture
##                      of its essence instead (essence_flow.gd; never on the
##                      bondless first climb)
static var DROPS := {"essence_chance": 0.08, "essence_base": 3.0, "essence_per_floor": 0.4, "fallen_item": 0.2, "handy_weight": 3.0, "rare_weight": 0.3,
	"tincture_chance": 0.012}

## Items lying on the floor fade after this many seconds.
const DROP_LIFE := 40.0

## Steady Hands (Surgeon's Body): healing items heal this much more...
const STEADY_HEAL := 1.3
## ...and take this much less time.
const STEADY_TIME := 0.6

const ORDER := ["draught", "stamina", "tonic", "vial", "smoke", "fire_flask", "edge_oil", "warding_oil", "haste", "stoneskin", "salts", "flare",
	"antidote", "heartroot", "net", "lodestone", "briar_tonic", "lantern_oil", "unmaking_ash", "gale_feather", "seeing_scroll",
	"scroll", "vessel",
	# Tinctures (essence_flow.gd): one of each essence.
	"tincture_air", "tincture_water", "tincture_iron", "tincture_fire", "tincture_stone", "tincture_blade"]

## Each item: name, short name, what it does, colour and its numbers; also
##   kind         its essence (the belt breaks it into this kind of crystal)
##   value        what it's worth in essence, by kind
##   drop_weight  how common it is (0: never found this way)
##   drop         false: never left by slain monsters (camps and vaults only)
##   staple       a cheap everyday item every climber carries (the Healing
##                and Stamina Vials and the Essence Vial): common from
##                monsters and cheap at the store; camps and vaults offer
##                the rarer things instead
##   buff         {key: amount} the item adds to your numbers while it lasts
##                ("duration"): the keys your gear adds up (gear.gd PIECES),
##                plus antivenom (no poison takes hold), guardbreak (blows go
##                through shells and guards) and seek (hidden traps and
##                secret walls this near you glint)
##   thrown       thrown where you aim, like the Fire Flask ("range",
##                "radius", "flight"): it bursts there (burst())
##   secret       the secret essence it draws on (its look and words only)
##   cures        the states on the climber it takes away (reactions.gd
##                CLIMBER); the HUD's state line names these items
##   ward         buff keys that stop a state taking hold while it lasts:
##                antivenom (poisoned), fireward (burning), bleedward
##                (bleeding), grounded (charged): reactions.gd CLIMBER "wards"

static var ITEMS := {
	"draught": {
		"name": "Healing Vial",
		"short": "Healing",
		"desc": "heals 40 health over a second and a half",
		"color": Color(0.9, 0.3, 0.32),
		"heal": 40.0,
		"time": 1.5,
		"drop_weight": 18, "staple": true,
		"kind": "stone", "value": {"stone": 6},
	},
	"stamina": {
		"name": "Stamina Vial",
		"short": "Stamina",
		"desc": "a quick, bitter swallow: shakes off all fatigue (your max stamina is whole again), fills your stamina, and it refills 40% faster for 5 seconds",
		"color": Color(0.95, 0.78, 0.3),
		"regen": 0.4, "duration": 5.0,
		"drop_weight": 14, "staple": true,
		"kind": "iron", "value": {"iron": 6},
	},
	"tonic": {
		"name": "Cleansing Tonic",
		"short": "Tonic",
		"desc": "cures every state on you (poison, burning, bleeding, soaked, charged), heals every burned body part and a little health",
		"color": Color(0.45, 0.85, 0.5),
		"heal": 10.0,
		"time": 0.5,
		"drop_weight": 1, "cures": ["poisoned", "burning", "bleeding", "soaked", "charged", "slowed"],
		"kind": "water", "value": {"water": 14},
	},
	"vial": {
		"name": "Essence Vial",
		"short": "Vial",
		"desc": "fills every mark with essence",
		"color": Color(0.55, 0.75, 1.0),
		"drop_weight": 5, "staple": true,
		"needs_mark": true,
		"kind": "water", "value": {"water": 8},
	},
	"smoke": {
		"name": "Smoke Bomb",
		"short": "Smoke",
		"desc": "a cloud of smoke around you: monsters inside lose track of you (beasts don't)",
		"color": Color(0.68, 0.66, 0.7),
		"radius": 95.0,
		"duration": 5.0,
		"drop_weight": 1,
		"kind": "fire", "value": {"fire": 14},
	},
	"fire_flask": {
		"name": "Fire Flask",
		"short": "Flask",
		"desc": "thrown where you aim: it bursts in flame and leaves the floor burning for 3 seconds (it burns foes, not you)",
		"color": Color(1.0, 0.5, 0.18),
		"dmg": 30.0, "per_floor": 0.1, "radius": 46.0, "range": 160.0, "burn": 3.0, "flight": 0.35,
		"drop_weight": 1,
		"kind": "fire", "value": {"fire": 16},
	},
	"edge_oil": {
		"name": "Edge Oil",
		"short": "Edge Oil",
		"desc": "rubbed on your weapon: for 20 seconds strikes hit 25% harder and land like heavy blows on shells and guards (a shellback's shell cracks, a knight is rocked)",
		"color": Color(0.88, 0.42, 0.45),
		"mult": 1.25, "duration": 20.0, "cracks": ["shellback", "knight"],
		"drop_weight": 1,
		"kind": "blade", "value": {"blade": 18},
	},
	"warding_oil": {
		"name": "Warding Oil",
		"short": "Ward Oil",
		"desc": "a 25-point barrier for 15 seconds; traps can't hurt you while it holds, and it puts out burning and keeps it off you",
		"color": Color(0.72, 0.78, 0.95),
		"shield": 25.0, "duration": 15.0,
		"drop_weight": 1, "cures": ["burning"], "ward": ["fireward"],
		"kind": "iron", "value": {"iron": 18},
	},
	"haste": {
		"name": "Haste Draught",
		"short": "Haste",
		"desc": "for 10 seconds you walk 25% faster and rolls cost 30% less stamina",
		"color": Color(0.75, 0.95, 0.55),
		"walk": 0.25, "roll": 0.3, "duration": 10.0,
		"drop_weight": 1,
		"kind": "air", "value": {"air": 15},
	},
	"stoneskin": {
		"name": "Stoneskin Draught",
		"short": "Stoneskin",
		"desc": "for 12 seconds blows hurt 20% less and can't knock you back (protection still stops at half a blow), and stone grounds you: no charge holds on you",
		"color": Color(0.7, 0.62, 0.5),
		"reduce": 0.2, "duration": 12.0,
		"drop_weight": 1, "cures": ["charged"], "ward": ["grounded"],
		"kind": "stone", "value": {"stone": 16},
	},
	"salts": {
		"name": "Second Wind Salts",
		"short": "Salts",
		"desc": "a sharp breath: your stamina is full at once, and for 8 seconds it never waits after you act and refills 50% faster",
		"color": Color(0.92, 0.95, 0.98),
		"regen": 0.5, "duration": 8.0,
		"drop_weight": 1,
		"kind": "iron", "value": {"iron": 14},
	},
	"flare": {
		"name": "Flare Powder",
		"short": "Flare",
		"desc": "lights the room for 20 seconds; hidden traps and secret walls nearby glint",
		"color": Color(1.0, 0.85, 0.45),
		"duration": 20.0, "radius": 420.0, "reveal": 360.0,
		"drop_weight": 1,
		"kind": "air", "value": {"air": 12},
	},
	"antidote": {
		"name": "Antivenom",
		"short": "Antivenom",
		"desc": "cures poison, and no poison takes hold of you for 30 seconds",
		"color": Color(0.62, 0.86, 0.36),
		"duration": 30.0, "buff": {"antivenom": 1.0},
		"drop_weight": 1, "cures": ["poisoned"], "ward": ["antivenom"],
		"kind": "stone", "value": {"stone": 12},
	},
	"heartroot": {
		"name": "Heartroot",
		"short": "Heartroot",
		"desc": "a living root, chewed: heals 20 health and stops bleeding, and for 30 seconds every kill heals you 4 more",
		"color": Color(0.82, 0.32, 0.4),
		"heal": 20.0, "time": 0.5, "duration": 30.0, "buff": {"kill_heal": 4.0},
		"drop_weight": 1, "drop": false, "secret": "life", "cures": ["bleeding"],
		"kind": "water", "value": {"water": 20},
	},
	"net": {
		"name": "Throwing Net",
		"short": "Net",
		"desc": "thrown where you aim: the foes it lands on are tangled for a moment and slowed for 4 seconds; a flier is brought down and held for 2.5 seconds (a beast only slowed)",
		"color": Color(0.84, 0.76, 0.56),
		"thrown": true, "range": 150.0, "radius": 52.0, "flight": 0.4, "tangle": 1.0, "slow": 4.0, "flier_tangle": 2.5,
		"drop_weight": 1,
		"kind": "water", "value": {"water": 14},
	},
	"lodestone": {
		"name": "Lodestone Bomb",
		"short": "Lodestone",
		"desc": "thrown where you aim: it bursts and drags the foes around it together, with a jolt of 8 (a beast barely moves)",
		"color": Color(0.5, 0.56, 0.78),
		"thrown": true, "range": 170.0, "radius": 95.0, "flight": 0.35, "dmg": 8.0, "pull": 430.0,
		"drop_weight": 1,
		"kind": "iron", "value": {"iron": 16},
	},
	"briar_tonic": {
		"name": "Briar Tonic",
		"short": "Briar",
		"desc": "a bitter green draught: for 25 seconds, foes that strike you up close take 8, and no bleeding takes hold of you (it stops a bleed, too)",
		"color": Color(0.4, 0.66, 0.3),
		"duration": 25.0, "buff": {"thorns": 8.0, "bleedward": 1.0},
		"drop_weight": 1, "cures": ["bleeding"], "ward": ["bleedward"],
		"kind": "blade", "value": {"blade": 14},
	},
	"lantern_oil": {
		"name": "Lantern Oil",
		"short": "Lantern Oil",
		"desc": "a flask of clear oil for your light: it reaches 60% farther for two minutes",
		"color": Color(1.0, 0.78, 0.36),
		"duration": 120.0, "buff": {"light": 0.6},
		"drop_weight": 1,
		"kind": "fire", "value": {"fire": 10},
	},
	"unmaking_ash": {
		"name": "Ash of Unmaking",
		"short": "Ash",
		"desc": "scattered around you: every foe within reach comes partly apart, losing an eighth of its health (a beast, a little)",
		"color": Color(0.66, 0.44, 0.86),
		"radius": 115.0, "share": 0.12, "beast_share": 0.03,
		"drop_weight": 1, "drop": false, "secret": "unmaking",
		"kind": "fire", "value": {"fire": 20},
	},
	"gale_feather": {
		"name": "Gale Feather",
		"short": "Gale",
		"desc": "blown from your palm: a gust hurls the foes around you back (a beast only staggers a step)",
		"color": Color(0.7, 0.88, 0.98),
		"radius": 120.0, "push": 560.0, "dmg": 4.0,
		"drop_weight": 1,
		"kind": "air", "value": {"air": 14},
	},
	"seeing_scroll": {
		"name": "Scroll of Seeing",
		"short": "Seeing",
		"desc": "read aloud: for a minute every hidden trap and secret wall on the floor glints, wherever it is",
		"color": Color(0.62, 0.78, 0.98),
		"duration": 60.0, "buff": {"seek": 6000.0},
		"drop_weight": 1,
		"kind": "air", "value": {"air": 16},
	},
	# From vaults (wings.gd), and always on the train's store shelf, priced
	# in crystals of any kind (train.gd ANY_PRICE): never dropped or offered at a camp.
	"scroll": {
		"name": "Recall Scroll",
		"short": "Scroll",
		"desc": "read it to leave the tower safely, keeping what you wear and your pack: your unbanked essence becomes essence crystals",
		"color": Color(0.95, 0.82, 0.5),
		"drop_weight": 0,
		"max": 1,
		"kind": "air", "value": {"air": 30, "water": 30},
	},
	# The vessel (vessel.gd, where its rules and words live; the name is a
	# placeholder): from a Rune Artist's bench or, very rarely, a vault. Not
	# sold, never stacked, never broken into crystals; using it only says
	# what it holds.
	"vessel": {
		"name": "Vessel",
		"short": "Vessel",
		"desc": "a sealed glass vessel bound in brass: it holds the secret essence that isn't your path instead of letting it pass (30 at most)",
		"color": Color(0.86, 0.64, 0.3),
		"drop_weight": 0, "drop": false,
		"max": 1,
	},
	# --- tinctures (essence_flow.gd: their strength, crafting, drops) ---
	# The only way the marked steer essence: drink one and choose a mark or
	# an unmarked body part (the crystals page, pour_page.gd). Never dropped
	# by the item table or offered at a camp ("drop_weight" 0): vaults, secret
	# rooms and rare monster drops hold them (essence_flow.gd TINCTURE); the
	# outfitter sells one kind a visit at their worth ("value"); the
	# Workshop crafts them from crystals of their kind.
	"tincture_air": {
		"name": "Air Tincture",
		"short": "Air Tinct.",
		"desc": "a stoppered vial of Air essence: drink it and choose where it goes, into one of your marks or an unmarked body part",
		"color": Color(0.78, 0.9, 1.0),
		"drop_weight": 0, "drop": false, "tincture": true,
		"kind": "air", "value": {"air": 60},
	},
	"tincture_water": {
		"name": "Water Tincture",
		"short": "Water Tinct.",
		"desc": "a stoppered vial of Water essence: drink it and choose where it goes, into one of your marks or an unmarked body part",
		"color": Color(0.37, 0.72, 0.85),
		"drop_weight": 0, "drop": false, "tincture": true,
		"kind": "water", "value": {"water": 60},
	},
	"tincture_iron": {
		"name": "Iron Tincture",
		"short": "Iron Tinct.",
		"desc": "a stoppered vial of Iron essence: drink it and choose where it goes, into one of your marks or an unmarked body part",
		"color": Color(0.8, 0.82, 0.88),
		"drop_weight": 0, "drop": false, "tincture": true,
		"kind": "iron", "value": {"iron": 60},
	},
	"tincture_fire": {
		"name": "Fire Tincture",
		"short": "Fire Tinct.",
		"desc": "a stoppered vial of Fire essence: drink it and choose where it goes, into one of your marks or an unmarked body part",
		"color": Color(1.0, 0.55, 0.25),
		"drop_weight": 0, "drop": false, "tincture": true,
		"kind": "fire", "value": {"fire": 60},
	},
	"tincture_stone": {
		"name": "Stone Tincture",
		"short": "Stone Tinct.",
		"desc": "a stoppered vial of Stone essence: drink it and choose where it goes, into one of your marks or an unmarked body part",
		"color": Color(0.82, 0.68, 0.45),
		"drop_weight": 0, "drop": false, "tincture": true,
		"kind": "stone", "value": {"stone": 60},
	},
	"tincture_blade": {
		"name": "Blade Tincture",
		"short": "Blade Tinct.",
		"desc": "a stoppered vial of Blade essence: drink it and choose where it goes, into one of your marks or an unmarked body part",
		"color": Color(0.88, 0.36, 0.4),
		"drop_weight": 0, "drop": false, "tincture": true,
		"kind": "blade", "value": {"blade": 60},
	},
}

## Reading the recall scroll (main.gd read_recall). It asks first: use it
## again within CONFIRM seconds to read it.
static var RECALL := {
	"confirm": 3.0,
	"ask_title": "READ THE RECALL SCROLL?",
	"ask": "Use it again within 3 seconds to leave the tower, keeping what you wear and your pack.",
	"ask_menu": "Press Read again to leave the tower now.",
	"first_climb": "The scroll's words won't come. The beast has not yet regarded you.",
	"title": "YOU LEAVE THE TOWER",
	"sub": "The scroll's words fold the tower away. %s lets you go, for now.",
	"crystals": "Unbanked essence settles into crystals: %s",
	"none": "You carried no unbanked essence.",
}

## Essence crystals (kept in the profile between climbs; crystals of a kind
## combine into one). Eating one pours up to "step" essence into you at a
## time, the natural way (essence_flow.gd: body and marks share it).
static var CRYSTAL := {
	"name": "%s Crystal",
	"desc": "holds %d %s essence outside you; eat it and that essence flows into you the natural way",
	"step": 10,
	"consume": "Eat %d",
	"consumed": "Ate %d %s essence",
	"held": "%d essence  ·  the train's money  ·  kept between climbs",
	"none": "No crystals of this kind yet. Each stair condenses a share of what you bank into crystals, the outfitter pays for every climb, and vaults and secret rooms may hold them.",
}


## The belt's words (the swap card, the break at the end of a climb).
static var BELT := {
	"full_title": "YOUR BELT IS FULL",
	"full_sub": "Swap a stack out for the %s (it stays at your feet), or leave it.",
	"drop_name": "Swap out: %s",
	"drop_desc": "drop your %s here and take the %s",
	"leave_name": "Leave it",
	"leave_desc": "your belt stays as it is; the %s waits on the floor",
	"left": "Belt full: the %s is at your feet",
	"broke": "Your belt breaks into crystals: %s",
}

## Bond notes on items (cheap ones; more with the bench later).
const ASHWALKER_SMOKE := 2.0  # Smoke Bombs last twice as long
const CONTRACTOR_FLASK := 1.5  # Flame Contractor: Fire Flasks burst 50% wider
const FLAMEBLADE_OIL := 2.0  # Flameblade: Edge Oil builds heat twice as fast
const HUNTER_FLARE := 2.0  # Hunter: Flare Powder lasts twice as long


## How many of an item you can carry.
static func max_stack(id: String) -> int:
	return int(ITEMS.get(id, {}).get("max", MAX_STACK))


## What a belt of items breaks into: {kind: essence} at BREAK_SHARE of
## their worth. `items` is {id: count}.
static func break_value(items: Dictionary) -> Dictionary:
	var out := {}
	for id in items:
		var n := float(int(items[id]))
		for k in ITEMS.get(id, {}).get("value", {}):
			out[k] = float(out.get(k, 0.0)) + float(ITEMS[id]["value"][k]) * BREAK_SHARE * n
	return out


## An item's name ("Healing Vial"; `short` for the short one: "Healing").
## Every item comes in one size: an old save's Minor or Greater one is
## simply the item (old_id).
static func item_name(id: String, short := false) -> String:
	var d: Dictionary = info(old_id(id))
	return String(d.get("short" if short else "name", id))


## An old save's sized key ("draught@3", "draught@1") as the plain item id.
static func old_id(id: String) -> String:
	return id.get_slice("@", 0)


## What a net says over the foes it lands on.
static var NET_TEXT := {"tangled": "Tangled", "down": "Brought down"}


# --- what's found -------------------------------------------------------------------

## What a slain monster leaves (main.gd on_enemy_killed): {"item"},
## {"essence": amount} (more of the tower's essence), or {} (nothing more).
static func kill_drop(floor_num: int, marked := true, tower := "", chance := DROP_CHANCE, tincture := -1.0) -> Dictionary:
	var roll := randf()
	if roll < chance:
		return {"item": random_item(marked, [], true, tower)}
	if roll < chance + float(DROPS["essence_chance"]):
		return {"essence": float(DROPS["essence_base"]) + float(DROPS["essence_per_floor"]) * floor_num}
	# Rarely a tincture instead (essence_flow.gd; its kind is the monster's
	# essence: main.gd). `tincture` < 0: DROPS "tincture_chance" (none in tests).
	if tincture < 0.0:
		tincture = 0.0 if Engine.has_meta("sixfold_test") else float(DROPS.get("tincture_chance", 0.0))
	if roll < chance + float(DROPS["essence_chance"]) + tincture:
		return {"tincture": true}
	return {}

# --- camps ---------------------------------------------------------------------

## On climbs of at least CAMP_MIN_FLOORS, taking the stair of each of these
## floors leads to a camp first: a safe room with a fire, a full rest and an
## item to take. (Camps aren't floors: the next floor is still the next one.)
const CAMP_AFTER := [3, 9]
const CAMP_MIN_FLOORS := 5
## How many item cards a camp offers (beside a crystal of the tower's essence,
## a smaller crystal of another kind and a piece of gear: main.gd
## _enter_camp). One: the rarer items are rare.
const CAMP_CHOICES := 1

static var CAMP := {
	"title": "CAMP",
	"choose": "CHOOSE ONE TO TAKE",
	"sub": "The fire is warm. You rest fully.",
	"rune_title": "RUNESMITH",
	"rune_sub": "By the firelight you can inscribe a rune on your gear, or craft something.",
	"leave": "The stair beyond the fire leads on.",
}

## Rune Artist's Runesmith at a camp: a rune on your gear that lasts the rest
## of the climb (the beast included), or one crafted item. The ids match the
## Inscribe spell's gear runes (bond.gd GEAR_RUNES).
static var CAMP_RUNES := {
	"sharpness": {"name": "Rune of Sharpness", "desc": "your strikes hit harder for the rest of the climb", "color": Color(1.0, 0.7, 0.45)},
	"warding": {"name": "Rune of Warding", "desc": "you take less damage for the rest of the climb", "color": Color(0.6, 0.8, 1.0)},
	"swiftness": {"name": "Rune of Swiftness", "desc": "you move faster for the rest of the climb", "color": Color(0.7, 1.0, 0.7)},
}
static var CRAFT := {"name": "Craft: %s", "desc": "craft a %s by the fire, as well as what you took"}


static func info(id: String) -> Dictionary:
	return ITEMS.get(id, {})


static func color(id: String) -> Color:
	return ITEMS.get(id, {}).get("color", Color.WHITE)


## A random item, weighted by how common each one is. Without a mark, an
## essence vial would do nothing, so `marked` false leaves those out;
## `dropped` (a slain monster's) leaves out the items never dropped, and is
## the only way to find a staple: camps, vaults and caches offer the rarer
## things (a camp's rest heals you anyway). In a `tower`, its handy items
## (tower_needs.gd) are DROPS "handy_weight" times as likely, and found
## there even if monsters elsewhere never leave them.
static func random_item(marked := true, exclude: Array = [], dropped := false, tower := "") -> String:
	var handy: Array = load("res://scripts/tower_needs.gd").handy(tower) if tower != "" else []
	var weights := {}
	var total := 0.0
	for id in ORDER:
		if _skip(id, marked, exclude, dropped, id in handy):
			continue
		weights[id] = float(ITEMS[id]["drop_weight"]) * (float(DROPS["handy_weight"]) if id in handy else 1.0) \
			* (1.0 if is_staple(id) else float(DROPS.get("rare_weight", 1.0)))
		total += weights[id]
	if total <= 0.0:
		return "draught"
	var roll := randf() * total
	for id in weights:
		roll -= weights[id]
		if roll < 0.0:
			return id
	return weights.keys()[-1]


static func _skip(id: String, marked: bool, exclude: Array, dropped: bool, handy := false) -> bool:
	return id in exclude or int(ITEMS[id]["drop_weight"]) <= 0 or (not marked and ITEMS[id].get("needs_mark", false)) \
		or (dropped and not handy and not ITEMS[id].get("drop", true)) or (not dropped and ITEMS[id].get("staple", false))


## True for the cheap everyday items (ITEMS "staple": the Healing and
## Stamina Vials and the Essence Vial).
static func is_staple(id: String) -> bool:
	return bool(ITEMS.get(id, {}).get("staple", false))


## Different items for a camp's cards (CAMP_CHOICES of them; in a `tower`,
## its handy items are likelier).
static func camp_choices(marked := true, tower := "") -> Array:
	var out: Array = []
	for i in CAMP_CHOICES:
		out.append(random_item(marked, out, false, tower))
	return out


## The sound of using each item (sound_bank.gd); one not listed plays "ready".
const USE_SOUNDS := {"draught": "drink", "stamina": "drink", "tonic": "drink", "vial": "use_vial", "smoke": "use_smoke", "fire_flask": "throw",
	"edge_oil": "use_oil", "warding_oil": "use_ward", "haste": "use_salts", "stoneskin": "use_stone", "salts": "use_salts", "flare": "ready",
	"antidote": "drink", "heartroot": "drink", "briar_tonic": "drink", "net": "throw", "lodestone": "throw",
	"lantern_oil": "use_oil", "unmaking_ash": "unmake", "gale_feather": "spell_wind", "seeing_scroll": "tip_chime",
	"tincture_air": "drink", "tincture_water": "drink", "tincture_iron": "drink", "tincture_fire": "drink", "tincture_stone": "drink", "tincture_blade": "drink"}


## Uses an item on the climber.
## Returns false (and says why) if it would do nothing, so it isn't wasted.
## Its "cures" take those states off the climber, and its "ward" keeps them
## off while it lasts (reactions.gd CLIMBER).
static func use(id: String, p) -> bool:
	var data := info(id)
	if data.is_empty():
		return false
	var main = p.main
	var col: Color = data["color"]
	var steady: bool = p.has_bond("surgeon")
	var above: Vector2 = p.global_position + Vector2(0, -44)
	if id == "scroll":
		# (main.gd asks first, then reads it: the climb ends there)
		return main.recall_pressed()
	if id == "vessel":
		return load("res://scripts/vessel.gd").use(p)  # (it says what it holds; never used up)
	if bool(data.get("tincture", false)):
		# (a tincture asks where it goes: the crystals page, which drinks it from the belt)
		if main.has_method("open_pour"):
			main.open_pour(id)
		return false
	match id:
		"draught":
			if p.hp >= p.max_health() - 0.5:
				main.fx_text(above, "Already at full health", Color(0.8, 0.78, 0.85))
				return false
			_heal_over_time(p, data, steady)
		"stamina":
			# Its job is fatigue (player.gd spend_sta): usable whenever max
			# stamina is down, even with the bar full.
			var lost: float = p.fatigue
			if lost < 0.5 and p.sta >= p.sta_cap() - 0.5:
				main.fx_text(above, "You're already breathing easy", Color(0.8, 0.78, 0.85))
				return false
			p.rest_fatigue()
			p.sta = p.sta_cap()
			p.sta_delay = 0.0
			p.add_buff(id, float(data["duration"]), {"regen": float(data["regen"])})
			main.fx_text(above, "Fatigue gone: +%d max stamina" % int(round(lost)) if lost >= 0.5 else "Stamina full", col)
		"tonic":
			var burned := false
			for b in p.bonds.values():
				burned = burned or b.burned
			if not burned and not _curable(p, data) and p.hp >= p.max_health() - 0.5:
				main.fx_text(above, "Nothing to cleanse", Color(0.8, 0.78, 0.85))
				return false
			for b in p.bonds.values():
				b.burned = false
			p.poison_t = 0.0
			p.fire_t = 0.0
			_heal_over_time(p, data, steady)
			main.fx_text(above + Vector2(0, -16), "Cleansed", col)
		"vial":
			var room_for := false
			for b in p.bonds.values():
				room_for = room_for or b.essence < b.capacity() - 0.01
			if not room_for:
				main.fx_text(above, "No mark to fill" if p.bonds.is_empty() else "Your marks are full", Color(0.8, 0.78, 0.85))
				return false
			for b in p.bonds.values():
				b.essence = b.capacity()
			main.fx_text(above, "Marks filled", col)
			main.light_flash(p.global_position, col, 1.4, 1.4, 0.35)
		"smoke":
			var last: float = float(data["duration"]) * (ASHWALKER_SMOKE if p.has_bond("ashwalker") else 1.0)
			main.smokes.append({"pos": p.global_position, "r": float(data["radius"]), "t": last})
			main.fx_burst(p.global_position, Vector2.ZERO, col, 18, 160.0)
		"fire_flask", "net", "lodestone":
			main.throw_flask(p, id)
		"edge_oil":
			p.edge_t = float(data["duration"])
			main.fx_text(above, "Edge oiled", col)
			main.sfx("equip_sword", 1.3, -6.0)
		"warding_oil":
			p.raise_barrier(float(data["shield"]), float(data["duration"]), false, col)
			p.ward_oil_t = float(data["duration"])
			p.add_buff(id, float(data["duration"]), _wards(data))
			main.fx_text(above, "Warded", col)
		"haste":
			p.haste_t = float(data["duration"])
			main.fx_text(above, "Haste", col)
			main.sfx("gust", 1.4, -6.0)
		"stoneskin":
			p.stone_t = float(data["duration"])
			p.add_buff(id, float(data["duration"]), _wards(data))
			main.fx_text(above, "Stoneskin", col)
			main.sfx("hit_armor", 0.8, -6.0)
		"salts":
			if p.sta >= p.sta_cap() - 0.5 and p.salts_t > 0.0:
				main.fx_text(above, "You're already breathing easy", Color(0.8, 0.78, 0.85))
				return false
			p.sta = p.sta_cap()  # (fatigue stays: that's the Stamina Vial's)
			p.salts_t = float(data["duration"])
			main.fx_text(above, "Second wind", col)
		"flare":
			var lasts: float = float(data["duration"]) * (HUNTER_FLARE if p.has_bond("hunter") else 1.0)
			main.light_flare(p.global_position, lasts)
			main.fx_burst(p.global_position, Vector2.ZERO, col, 22, 260.0)
		"antidote":
			if p.poison_t <= 0.0 and not _curable(p, data) and p.buff_left(id) > 1.0:
				main.fx_text(above, "Already proof against poison", Color(0.8, 0.78, 0.85))
				return false
			p.poison_t = 0.0
			p.add_buff(id, float(data["duration"]), data["buff"])
			main.fx_text(above, "Proof against poison", col)
		"heartroot":
			_heal_over_time(p, data, steady)
			p.add_buff(id, float(data["duration"]), data["buff"])
			main.fx_burst(p.global_position, Vector2.UP, col, 14, 160.0)
		"briar_tonic", "lantern_oil", "seeing_scroll":
			p.add_buff(id, float(data["duration"]), data["buff"])
			main.fx_text(above, {"briar_tonic": "Briars", "lantern_oil": "Your light grows",
				"seeing_scroll": "The hidden shows itself"}[id], col)
			if id == "lantern_oil":
				main.light_flash(p.global_position, col, 1.6, 2.0, 0.4)
			elif id == "seeing_scroll":
				main.sfx("glint", 0.8, -2.0, 0.0)
		"unmaking_ash":
			var hit := 0
			for e in main.targets():
				if e.dead or e.global_position.distance_to(p.global_position) > float(data["radius"]) + e.radius:
					continue
				var share: float = float(data["beast_share"] if e.is_boss() else data["share"])
				e.take_hit(e.max_hp * share, Vector2.ZERO, 0.0, false, true)
				main.fx_burst(e.global_position, Vector2.UP, col, 10, 180.0)
				hit += 1
			main.fx_ring(p.global_position, col, float(data["radius"]), 0.45, 4.0)
			main.fx_text(above, "Unmade" if hit > 0 else "The ash scatters", col)
		"gale_feather":
			for e in main.targets():
				var to: Vector2 = e.global_position - p.global_position
				if e.dead or to.length() > float(data["radius"]) + e.radius:
					continue
				var dir: Vector2 = to.normalized() if to.length() > 0.1 else p.aim
				e.take_hit(float(data["dmg"]), dir, 0.0)
				e.knock = dir * float(data["push"]) * (0.2 if e.is_boss() else 1.0)
			main.fx_ring(p.global_position, col, float(data["radius"]), 0.35, 5.0)
			main.fx_burst(p.global_position, Vector2.ZERO, col, 20, 360.0)
			main.sfx("gust", 1.0, -3.0)
	if _cure(p, data):
		main.fx_text(above + Vector2(0, -30), String(load("res://scripts/reactions.gd").CLIMBER_TEXT["cured"]), col)
	main.fx_ring(p.global_position, col, 34.0, 0.3, 3.0)
	main.sfx(USE_SOUNDS.get(id, "ready"), 1.0, -3.0)
	return true


## True if the item would take a state off the climber now (its "cures").
static func _curable(p, data: Dictionary) -> bool:
	for st in data.get("cures", []):
		if float(p.states.get(String(st), 0.0)) > 0.0 or (st == "poisoned" and p.poison_t > 0.0):
			return true
	return false


## Takes the item's "cures" off the climber. True if any was there.
static func _cure(p, data: Dictionary) -> bool:
	var any := false
	for st in data.get("cures", []):
		var s := String(st)
		if float(p.states.get(s, 0.0)) > 0.0 or (s == "poisoned" and p.poison_t > 0.0):
			any = true
		p.states.erase(s)
		if s == "poisoned":
			p.poison_t = 0.0
	return any


## The item's wards as a buff ({key: 1}): no such state takes hold while it lasts.
static func _wards(data: Dictionary) -> Dictionary:
	var out := {}
	for w in data.get("ward", []):
		out[String(w)] = 1.0
	return out


## Healing items heal over a short time. Steady Hands heals more, faster.
static func _heal_over_time(p, data: Dictionary, steady: bool) -> void:
	var amount: float = float(data["heal"]) * (STEADY_HEAL if steady else 1.0) * p.heal_mult() * (1.0 + p.gfx("item_heal"))  # Life's flow; a Herb Pouch
	var t: float = float(data["time"]) * (STEADY_TIME if steady else 1.0)
	p.heal_left += amount
	p.heal_rate = maxf(p.heal_rate if p.heal_left > amount else 0.0, amount / t)
	p.main.fx_text(p.global_position + Vector2(0, -44), "+%d" % int(round(amount)), Color(0.6, 1.0, 0.7))


## A thrown item bursts where it lands (main.gd _update_flasks; the Fire
## Flask's burst is main.gd's own): `f` is {to, r, id}.
static func burst(main, f: Dictionary) -> void:
	var id := String(f.get("id", ""))
	var data := info(id)
	var col: Color = data.get("color", Color.WHITE)
	var pos: Vector2 = f["to"]
	match id:
		"net":
			for e in main.targets():
				if e.dead or e.global_position.distance_to(pos) > float(f["r"]) + e.radius:
					continue
				e.chill_t = maxf(e.chill_t, float(data["slow"]) * (0.5 if e.is_boss() else 1.0))
				var flier: bool = e.kind in e.FLIERS
				if not e.is_boss():
					# (a flier is brought down: held longer, the job nets do best: tower_needs.gd)
					e.stagger(float(data["flier_tangle"] if flier else data["tangle"]))
				main.fx_text(e.global_position + Vector2(0, -e.radius - 22.0), String(NET_TEXT["down"] if flier and not e.is_boss() else NET_TEXT["tangled"]), col)
			main.sfx("swing", 0.6, -4.0)
		"lodestone":
			for e in main.targets():
				var to: Vector2 = pos - e.global_position
				if e.dead or to.length() > float(f["r"]) + e.radius:
					continue
				var dir: Vector2 = to.normalized() if to.length() > 1.0 else Vector2.ZERO
				e.take_hit(float(data["dmg"]), -dir, 0.0)
				e.knock = dir * float(data["pull"]) * minf(1.0, to.length() / 60.0) * (0.15 if e.is_boss() else 1.0)
			main.light_flash(pos, col, 1.4, 1.8, 0.35)
			main.sfx("zap", 0.6, -3.0)
	main.fx_ring(pos, col, float(f["r"]), 0.35, 5.0)
	main.fx_burst(pos, Vector2.ZERO, col, 16, 240.0)


# --- drawing -----------------------------------------------------------------------
# Icons follow icon_art.gd's style (slim shapes, smooth shading lit from the
# top-left, a light violet ink outline, shared materials). They use only
# filled shapes, so they also work lying on the floor under torchlight
# (fx.gd), and each is built once per size and copied after that.

const Draw := preload("res://scripts/draw_util.gd")
const Art := preload("res://scripts/icon_art.gd")


## An item's icon, drawn in code, centred on `c` (about 2*s across).
## `alpha` fades it (empty slots, items fading on the floor).
static func draw_icon(ci: CanvasItem, id: String, c: Vector2, s: float, alpha := 1.0) -> void:
	var b := Draw.Batch.new()
	icon_into(b, id, c, s)
	if alpha < 0.999:
		for i in b.cols.size():
			b.cols[i].a *= alpha
	b.flush(ci)


static func icon_into(b, id: String, c: Vector2, s: float) -> void:
	if id == "vessel":
		load("res://scripts/vessel.gd").belt_into(b, c, s)  # (filled as the belt's vessel is)
		return
	s = Art.size_step(s)
	Art.cached(b, "item|%s|%.2f" % [id, s], c, func(nb): _item_art(nb, id, s))


## An item's icon around (0, 0): the art itself.
static func _item_art(b, id: String, s: float) -> void:
	var col := color(id)
	var c := Vector2.ZERO
	var u := Art.unit(s)
	var lod := Art.detail(s)
	Art.ground(b, s, 9.2, 6.4, 0.36)  # (it sits in its slot)
	if bool(ITEMS.get(id, {}).get("tincture", false)):
		_tincture_art(b, col, s)
		return
	match id:
		"draught":
			# A round flask: the red cure two-thirds up, a cork.
			var bc := Vector2(0, 3.0) * u
			var r := 6.4 * u
			Art.glass(b, _flask(bc, r, Rect2(Vector2(-1.7, -6.0) * u, Vector2(3.4, 3.4) * u)), s, col, bc.y - r * 0.2)
			_cork(b, Rect2(Vector2(-2.3, -9.0) * u, Vector2(4.6, 3.2) * u), s)
			Art.shine(b, bc + Vector2(-3.0, -2.3) * u, 0.9 * u, 2.0 * u)
			if lod > 0:
				b.circle(bc + Vector2(2.3, 3.4) * u, 0.6 * u, Color(1, 1, 1, 0.35), 10)
		"stamina":
			# A tall, slim bottle of amber draught, a cork, and a gust on its label.
			var body := Art.rrect(Rect2(Vector2(-3.8, -3.6) * u, Vector2(7.6, 12.8) * u), 2.2 * u)
			body = _with_neck(body, Rect2(Vector2(-1.5, -6.6) * u, Vector2(3.0, 3.8) * u))
			Art.glass(b, body, s, col, -1.4 * u)
			_cork(b, Rect2(Vector2(-2.1, -9.6) * u, Vector2(4.2, 3.2) * u), s)
			var lc := Vector2(0, 3.4) * u
			Art.shape(b, Art.rrect(Rect2(lc - Vector2(2.8, 2.2) * u, Vector2(5.6, 4.4) * u), 0.8 * u, 3), Art.PAPER, s, "", Art.THIN | Art.NO_RIM)
			var k := col.darkened(0.45)
			for row in 2:
				var y := (2.6 + row * 1.7) * u
				b.line(Vector2(-1.9 * u, y), Vector2((1.4 - row * 0.8) * u, y), k, maxf(0.6, 0.45 * u))
			Art.shine(b, Vector2(-2.4, -0.6) * u, 0.5 * u, 2.4 * u, 0.0, 0.5)
		"tonic":
			# A square bottle of green cure with a white cross on its label.
			var body := Art.rrect(Rect2(Vector2(-5.2, -3.0) * u, Vector2(10.4, 12.2) * u), 2.4 * u)
			body = _with_neck(body, Rect2(Vector2(-1.7, -6.2) * u, Vector2(3.4, 3.6) * u))
			Art.glass(b, body, s, col, -0.2 * u)
			_cork(b, Rect2(Vector2(-2.3, -9.2) * u, Vector2(4.6, 3.2) * u), s)
			var lc := Vector2(0, 3.6) * u
			Art.shape(b, Art.oval(lc, Vector2(3.0, 3.0) * u), Art.PAPER, s, "", Art.THIN | Art.NO_RIM)
			var k := col.darkened(0.3)
			b.rect(Rect2(lc - Vector2(0.65, 2.0) * u, Vector2(1.3, 4.0) * u), k)
			b.rect(Rect2(lc - Vector2(2.0, 0.65) * u, Vector2(4.0, 1.3) * u), k)
			Art.shine(b, Vector2(-3.4, -0.2) * u, 0.6 * u, 2.4 * u, 0.0, 0.5)
		"vial":
			# A tall vial of glowing essence with a spark in it.
			var body := Art.rrect(Rect2(Vector2(-2.8, -5.6) * u, Vector2(5.6, 14.8) * u), 2.8 * u)
			Art.soft(b, Vector2(0, 3.0) * u, 8.5 * u, Color(col, 0.4))
			Art.glass(b, body, s, col, -1.2 * u, 1.0)
			_cork(b, Rect2(Vector2(-3.4, -9.2) * u, Vector2(6.8, 3.8) * u), s)
			Art.spark(b, Vector2(0.2, 3.6) * u, 2.6 * u, Color(1, 1, 1, 0.9))
			Art.shine(b, Vector2(-1.5, -2.6) * u, 0.5 * u, 2.2 * u, 0.0, 0.5)
		"smoke":
			# A round iron bomb with a lit fuse.
			var bc := Vector2(-0.8, 2.0) * u
			Art.rod(b, bc + Vector2(3.4, -6.8) * u, Vector2(5.4, -7.0) * u, 0.9 * u, Color(0.84, 0.72, 0.52), s, "cloth")
			var cap := Art.rrect(Rect2(bc + Vector2(-1.4, -8.4) * u, Vector2(2.8, 2.4) * u), 0.6 * u, 3)
			var rot := Transform2D(0.7, bc)
			cap = rot * (Transform2D(0.0, -bc) * cap)
			Art.shape(b, cap, Art.IRON, s, "metal", Art.NO_RIM)
			Art.orb(b, bc, 6.6 * u, Color(0.42, 0.42, 0.54), s, "metal")
			_flame(b, Vector2(6.0, -7.8) * u, 2.8 * u, s, true)
		"fire_flask":
			# A round flask of fire, a burning rag for a stopper.
			var bc := Vector2(0, 3.0) * u
			var r := 6.4 * u
			Art.glass(b, _flask(bc, r, Rect2(Vector2(-1.7, -5.8) * u, Vector2(3.4, 3.4) * u)), s, col, bc.y - r * 0.35, 0.7)
			var rag := Art.smooth(Art.pts(c, u, [Vector2(-3.2, -8.0), Vector2(-0.6, -9.4), Vector2(2.8, -8.4), Vector2(2.4, -5.6), Vector2(4.6, -3.6),
				Vector2(2.6, -3.8), Vector2(0.6, -5.2), Vector2(-2.6, -5.4)]), 3)
			Art.shape(b, rag, Color(0.88, 0.82, 0.66), s, "cloth", Art.NO_RIM)
			_flame(b, Vector2(-0.2, -11.0) * u, 3.0 * u, s, false)
			Art.shine(b, bc + Vector2(-3.0, -2.3) * u, 0.9 * u, 2.0 * u)
		"edge_oil":
			# A slim vial of red oil, a little blade beside it.
			var body := Art.rrect(Rect2(Vector2(-5.4, -4.6) * u, Vector2(4.8, 13.8) * u), 2.4 * u)
			Art.glass(b, body, s, col, -0.4 * u)
			_cork(b, Rect2(Vector2(-5.8, -8.2) * u, Vector2(5.6, 3.6) * u), s)
			Art.shine(b, Vector2(-4.0, -1.4) * u, 0.45 * u, 2.2 * u, 0.0, 0.5)
			var t0 := Vector2(2.8, 8.4) * u
			var t1 := Vector2(8.4, -7.8) * u
			var dir := (t1 - t0).normalized()
			var side := Art.lit_side(t0, t1)
			Art.shape(b, PackedVector2Array([t0 + side * 1.1 * u, t1, t0 - side * 1.1 * u]), Art.STEEL, s, "metal")
			Art.rod(b, t0 - dir * 0.3 * u, t0 - dir * 2.4 * u, 1.5 * u, Art.LEATHER, s, "leather")
		"warding_oil":
			# A pear-shaped oil bottle with a shield on its label.
			var body := PackedVector2Array()
			for i in 25:
				var a := lerpf(-PI * 0.3, PI * 1.3, i / 24.0)
				body.append(Vector2(0, 3.6) * u + Vector2(cos(a) * 6.0, sin(a) * 5.4) * u)
			body = _with_neck(body, Rect2(Vector2(-1.6, -6.4) * u, Vector2(3.2, 6.0) * u))
			Art.glass(b, body, s, col, 0.6 * u)
			_cork(b, Rect2(Vector2(-2.2, -9.4) * u, Vector2(4.4, 3.2) * u), s)
			var lc := Vector2(0, 4.0) * u
			var shield := Art.pts(lc, u, [Vector2(-2.6, -2.6), Vector2(2.6, -2.6), Vector2(2.4, 0.6), Vector2(0, 3.0), Vector2(-2.4, 0.6)])
			Art.shape(b, shield, Art.PAPER, s, "", Art.THIN | Art.NO_RIM)
			b.polygon(Art.pts(lc, u, [Vector2(0, -2.0), Vector2(1.8, -2.0), Vector2(1.7, 0.5), Vector2(0, 2.2)]), col.darkened(0.3))
			Art.shine(b, Vector2(-3.6, 1.8) * u, 0.6 * u, 1.7 * u)
		"haste":
			# A conical flask of bright green with speed lines behind it.
			for k in 3:
				var y := (0.4 + k * 3.0) * u
				var x0 := (-10.2 + k * 0.8) * u
				b.line(Vector2(x0, y), Vector2(x0 + (4.2 - k * 1.0) * u, y), Color(col, 0.85 - k * 0.15), maxf(0.9, 0.8 * u))
			var body := Art.pts(c, u, [Vector2(0.1, -6.4), Vector2(3.1, -6.4), Vector2(3.1, -2.2), Vector2(8.2, 7.2), Vector2(7.4, 9.0),
				Vector2(-4.2, 9.0), Vector2(-5.0, 7.2), Vector2(0.1, -2.2)])
			Art.glass(b, body, s, col, 2.6 * u)
			_cork(b, Rect2(Vector2(-0.6, -9.4) * u, Vector2(4.4, 3.2) * u), s)
			Art.shine(b, Vector2(-0.6, 3.0) * u, 0.5 * u, 2.2 * u, 0.5, 0.5)
		"stoneskin":
			# A six-sided bottle of earthy draught, a stone stopper and a cut stone on it.
			var body := PackedVector2Array()
			for i in 6:
				body.append(Vector2(0, 3.0) * u + Vector2.from_angle(PI / 6.0 + TAU * i / 6.0) * Vector2(6.4, 6.2) * u)
			body = _with_neck(body, Rect2(Vector2(-1.7, -6.0) * u, Vector2(3.4, 3.6) * u))
			Art.glass(b, body, s, col, 0.8 * u)
			Art.shape(b, Art.pts(c, u, [Vector2(-2.6, -6.0), Vector2(-1.9, -9.4), Vector2(1.9, -9.4), Vector2(2.6, -6.0)]), Color(0.6, 0.58, 0.66), s)
			var gc := Vector2(0, 4.2) * u
			var gem := Art.pts(gc, u, [Vector2(0, -2.6), Vector2(2.4, -0.6), Vector2(1.4, 2.2), Vector2(-1.4, 2.2), Vector2(-2.4, -0.6)])
			Art.shape(b, gem, col.lightened(0.15), s, "gem", Art.THIN | Art.NO_RIM)
			b.polygon(PackedVector2Array([gem[0], gem[4], gc]), Color(1, 1, 1, 0.4))
			Art.shine(b, Vector2(-3.4, 1.2) * u, 0.5 * u, 1.9 * u, 0.0, 0.45)
		"salts":
			# A small open tin heaped with white crystals.
			var tc := Vector2(0, 3.4) * u
			var tin := PackedVector2Array([tc + Vector2(-7.6, -1.4) * u])
			for i in 17:
				tin.append(tc + Vector2(-cos(PI * i / 16.0) * 7.6, 1.4 + sin(PI * i / 16.0) * 3.4) * u)
			tin.append(tc + Vector2(7.6, -1.4) * u)
			Art.shape(b, tin, Color(0.6, 0.62, 0.72), s, "metal")
			var mouth := Art.oval(tc + Vector2(0, -1.4) * u, Vector2(7.6, 2.8) * u)
			Art.shape(b, mouth, Art.GOLD, s, "gold", Art.THIN | Art.NO_RIM)
			b.polygon(Art.oval(tc + Vector2(0, -1.4) * u, Vector2(6.4, 2.0) * u), Color(0.15, 0.13, 0.2))
			for v in [Vector2(-3.8, -2.0), Vector2(3.4, -1.8), Vector2(-1.5, -4.3), Vector2(1.7, -4.1), Vector2(0.1, -1.8), Vector2(0.0, -6.4)]:
				_chunk(b, tc + v * u, 2.0 * u, col, s)
			Art.spark(b, Vector2(4.8, -5.6) * u, 2.4 * u, Color(1, 1, 1, 0.9))
		"flare":
			# A paper cartridge of powder, its twist end spitting sparks.
			var body := Rect2(Vector2(-3.2, -3.0) * u, Vector2(6.4, 12.0) * u)
			Art.shape(b, Art.rrect(body, 1.0 * u, 3), Color(0.88, 0.32, 0.26), s, "cloth")
			var band := Rect2(body.position + Vector2(0, 4.0 * u), Vector2(body.size.x, 2.4 * u))
			b.rect(band, Color(0.96, 0.89, 0.72))
			b.rect(Rect2(band.position + Vector2(0, band.size.y - 0.6 * u), Vector2(band.size.x, 0.6 * u)), Color(0.78, 0.62, 0.46))
			var twist := Art.pts(c, u, [Vector2(-3.2, -3.0), Vector2(3.2, -3.0), Vector2(0.9, -5.4), Vector2(1.4, -7.0), Vector2(-1.3, -7.0), Vector2(-0.9, -5.4)])
			Art.shape(b, twist, Color(0.93, 0.86, 0.68), s, "cloth", Art.NO_RIM)
			_flame(b, Vector2(0, -9.6) * u, 3.0 * u, s, true)
			b.circle(Vector2(4.4, -9.2) * u, 0.8 * u, col, 10)
			b.circle(Vector2(-4.0, -10.2) * u, 0.7 * u, col, 10)
			if lod > 0:
				b.circle(Vector2(3.0, -11.8) * u, 0.55 * u, Color(1, 1, 0.85), 10)
		"scroll":
			# A rolled parchment tied with a red cord and sealed, gold letters showing.
			var body := Rect2(Vector2(-5.6, -4.6) * u, Vector2(11.2, 9.2) * u)
			Art.shape(b, Art.rrect(body, 0.4 * u, 2), Art.PAPER, s, "cloth")
			var lines := 3 if lod > 0 else 2
			for k in lines:
				var y := body.position.y + (2.2 + k * (5.6 / lines)) * u
				b.rect(Rect2(Vector2(body.position.x + 1.6 * u, y), Vector2((6.0 - k * 1.5) * u, maxf(0.7, 0.8 * u))), Color(Art.GOLD.darkened(0.3), 0.95))
			for sx in [-1.0, 1.0]:
				var x: float = sx * 6.6 * u
				Art.rod(b, Vector2(x, -5.8 * u), Vector2(x, 5.8 * u), 3.0 * u, Art.PAPER.darkened(0.04), s, "cloth")
				b.circle(Vector2(x, -6.0 * u), 0.8 * u, Art.PAPER.darkened(0.45), 10)
			var cord := Color(0.82, 0.22, 0.2)
			b.rect(Rect2(Vector2(1.7, -4.6) * u, Vector2(1.3, 9.2) * u), cord)
			Art.orb(b, Vector2(2.35, 4.8) * u, 1.7 * u, cord, s, "gem")
		"antidote":
			# A squat green bottle with a leaf on its label, a serpent crossed out.
			var body := Art.rrect(Rect2(Vector2(-5.0, -1.6) * u, Vector2(10.0, 10.6) * u), 3.4 * u)
			body = _with_neck(body, Rect2(Vector2(-1.6, -5.6) * u, Vector2(3.2, 4.6) * u))
			Art.glass(b, body, s, col, 0.4 * u)
			_cork(b, Rect2(Vector2(-2.2, -8.8) * u, Vector2(4.4, 3.2) * u), s)
			var lc := Vector2(0, 4.0) * u
			Art.shape(b, Art.rrect(Rect2(lc - Vector2(3.4, 2.6) * u, Vector2(6.8, 5.2) * u), 0.8 * u, 3), Art.PAPER, s, "", Art.THIN | Art.NO_RIM)
			var leaf := Art.oval(lc, Vector2(2.4, 1.2) * u, -0.6, 12)
			b.polygon(leaf, col.darkened(0.25))
			b.line(lc + Vector2(-1.8, 1.3) * u, lc + Vector2(1.8, -1.3) * u, col.darkened(0.5), maxf(0.4, 0.3 * u))
			Art.shine(b, Vector2(-3.4, 1.2) * u, 0.5 * u, 2.0 * u, 0.0, 0.5)
		"heartroot":
			# A gnarled red root shaped like a heart, rootlets trailing, a green shoot.
			var hc := Vector2(0, 1.6) * u
			var heart := PackedVector2Array()
			for i in 36:
				var t := TAU * i / 36.0
				heart.append(hc + Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))) * u * 0.42)
			for v in [[Vector2(-2.0, 6.8), Vector2(-5.4, 9.6)], [Vector2(0.6, 7.4), Vector2(1.4, 10.0)], [Vector2(2.4, 6.4), Vector2(6.0, 8.6)]]:
				Art.rod(b, v[0] * u, v[1] * u, 0.7 * u, Color(0.62, 0.36, 0.3), s, "wood")
			Art.shape(b, heart, col, s, "wood")
			if lod > 0:
				b.line(hc + Vector2(-3.6, -2.0) * u, hc + Vector2(-1.0, 3.6) * u, Color(col.darkened(0.45), 0.7), maxf(0.45, 0.4 * u))
				b.line(hc + Vector2(3.0, -2.6) * u, hc + Vector2(1.6, 2.2) * u, Color(col.darkened(0.45), 0.7), maxf(0.45, 0.4 * u))
			Art.rod(b, hc + Vector2(0.4, -3.4) * u, hc + Vector2(1.6, -8.2) * u, 0.7 * u, Color(0.42, 0.66, 0.3), s, "")
			Art.shape(b, Art.oval(hc + Vector2(3.4, -8.4) * u, Vector2(2.0, 1.0) * u, -0.3, 10), Color(0.5, 0.78, 0.36), s, "", Art.THIN | Art.NO_RIM)
			Art.soft(b, hc, 7.0 * u, Color(0.78, 1.0, 0.62, 0.22))
		"net":
			# A bundled net of knotted cord, lead weights at its corners.
			var bundle := Art.smooth(Art.pts(c, u, [Vector2(-7.6, -2.0), Vector2(-3.0, -7.6), Vector2(4.6, -6.6), Vector2(8.2, 0.4), Vector2(5.2, 7.4), Vector2(-4.4, 7.8)]), 3)
			Art.shape(b, bundle, col.darkened(0.25), s, "cloth", Art.NO_RIM)
			var cord := col.lightened(0.1)
			var cw := maxf(0.55, 0.5 * u)
			for k in 6:
				var x := -6.0 + k * 2.6
				b.line(Vector2(x - 1.6, -6.4) * u, Vector2(x + 2.4, 7.4) * u, cord, cw)
				b.line(Vector2(x + 2.4, -6.4) * u, Vector2(x - 1.6, 7.4) * u, cord, cw)
			Art.outline(b, bundle, s)
			if lod > 0:
				for k in 5:
					b.circle(Vector2(-4.0 + k * 2.0, -0.4 + (k % 2) * 2.6) * u, 0.5 * u, cord.lightened(0.2), 8)
			for v in [Vector2(-7.6, -2.0), Vector2(8.2, 0.4), Vector2(-4.4, 7.8), Vector2(5.2, 7.4)]:
				Art.orb(b, v * u, 1.3 * u, Art.IRON, s, "metal")
		"lodestone":
			# A dark iron bomb banded with a lodestone, iron filings leaping to it.
			var bc := Vector2(-0.6, 1.6) * u
			Art.orb(b, bc, 6.8 * u, col.darkened(0.3), s, "metal")
			Art.shape(b, Art.rrect(Rect2(bc + Vector2(-6.9, -1.0) * u, Vector2(13.8, 2.2) * u), 0.6 * u, 2), Art.BRASS, s, "gold", Art.THIN | Art.NO_RIM)
			_facets_item(b, bc + Vector2(0, 0.1) * u, 2.6 * u, Color(0.42, 0.46, 0.7), s)
			Art.shape(b, Art.rrect(Rect2(bc + Vector2(-1.6, -8.6) * u, Vector2(3.2, 2.6) * u), 0.6 * u, 3), Art.IRON, s, "metal", Art.NO_RIM)
			for v in [Vector2(7.4, -6.0), Vector2(8.6, -2.4), Vector2(5.8, -8.6), Vector2(-7.8, -6.4)]:
				var at: Vector2 = v * u
				var to := (bc - at).normalized()
				b.line(at, at + to * 1.6 * u, Color(0.78, 0.82, 0.95), maxf(0.5, 0.45 * u))
			Art.spark(b, Vector2(6.4, -4.4) * u, 1.8 * u, Color(0.8, 0.88, 1.0, 0.9))
		"briar_tonic":
			# A tall green bottle wound about with a thorny briar.
			var body := Art.rrect(Rect2(Vector2(-3.6, -3.4) * u, Vector2(7.2, 12.6) * u), 2.4 * u)
			body = _with_neck(body, Rect2(Vector2(-1.4, -6.4) * u, Vector2(2.8, 3.6) * u))
			Art.glass(b, body, s, col, -0.6 * u)
			_cork(b, Rect2(Vector2(-2.0, -9.4) * u, Vector2(4.0, 3.2) * u), s)
			var vine := Color(0.34, 0.52, 0.24)
			var prev := Vector2(-4.4, 8.2) * u
			for k in 9:
				var y := 8.2 - k * 1.6
				var at := Vector2(sin(k * 1.3) * 4.4, y) * u
				b.line(prev, at, Art.INK, 1.0 * u + Art.ol(s))
				b.line(prev, at, vine, 1.0 * u)
				if k % 2 == 0:
					var out := Vector2(signf(at.x) if absf(at.x) > 0.1 else 1.0, -0.4).normalized()
					b.polygon(PackedVector2Array([at + Vector2(0, -0.5) * u, at + out * 1.8 * u, at + Vector2(0, 0.5) * u]), vine.lightened(0.3))
				prev = at
			Art.shine(b, Vector2(-2.4, -0.4) * u, 0.45 * u, 1.8 * u, 0.0, 0.45)
		"lantern_oil":
			# A small tin oil can with a long spout, a drop of clear oil at its tip, the light it feeds.
			var can := Art.rrect(Rect2(Vector2(-6.0, -2.2) * u, Vector2(9.6, 11.0) * u), 1.6 * u, 3)
			Art.shape(b, Art.pts(c, u, [Vector2(2.6, 0.4), Vector2(9.0, -6.4), Vector2(9.8, -5.6), Vector2(3.8, 2.4)]), Art.BRASS, s, "gold", Art.THIN)
			Art.shape(b, can, Color(0.66, 0.68, 0.76), s, "metal")
			Art.shape(b, Art.rrect(Rect2(Vector2(-6.4, -3.4) * u, Vector2(10.4, 2.0) * u), 0.6 * u, 2), Art.BRASS, s, "gold", Art.THIN | Art.NO_RIM)
			Art.rod(b, Vector2(-4.0, -4.4) * u, Vector2(1.6, -4.4) * u, 1.0 * u, Art.BRASS, s, "gold")
			var lc := Vector2(-1.2, 3.6) * u
			Art.shape(b, Art.oval(lc, Vector2(3.0, 3.0) * u), Art.PAPER, s, "", Art.THIN | Art.NO_RIM)
			Art.flame(b, lc + Vector2(0, 0.4) * u, 1.6 * u, s)
			var dc := Vector2(9.8, -3.6) * u
			b.polygon(PackedVector2Array([dc + Vector2(0, -1.2) * u, dc + Vector2(0.9, 0.4) * u, dc + Vector2(0, 1.2) * u, dc + Vector2(-0.9, 0.4) * u]), col)
			Art.soft(b, dc, 3.0 * u, Color(col, 0.5))
		"unmaking_ash":
			# A small violet pouch spilling dark ash, motes of it coming apart in the air.
			var bag := Art.smooth(Art.pts(c, u, [Vector2(-3.0, -4.6), Vector2(2.4, -4.6), Vector2(5.6, 1.0), Vector2(4.2, 6.6), Vector2(-5.6, 6.6), Vector2(-6.4, 1.0)]), 3)
			var heap := Art.smooth(Art.pts(c, u, [Vector2(1.0, 6.0), Vector2(5.0, 3.4), Vector2(9.0, 5.4), Vector2(9.8, 8.6), Vector2(1.6, 8.6)]), 2)
			Art.shape(b, heap, Color(0.24, 0.18, 0.3), s, "", Art.NO_RIM)
			Art.shape(b, bag, col.darkened(0.25), s, "cloth")
			Art.shape(b, Art.rrect(Rect2(Vector2(-3.6, -5.6) * u, Vector2(6.4, 1.8) * u), 0.6 * u, 2), col.darkened(0.45), s, "cloth", Art.THIN | Art.NO_RIM)
			Art.soft(b, Vector2(4.0, -4.0) * u, 7.0 * u, Color(col, 0.35))
			for v in [Vector2(3.6, -6.4), Vector2(6.4, -3.8), Vector2(1.0, -9.0), Vector2(7.8, -8.0), Vector2(5.0, -10.0)]:
				var r := (0.9 if v.y > -7.0 else 0.6) * u
				b.polygon(PackedVector2Array([v * u + Vector2(0, -r), v * u + Vector2(r, 0), v * u + Vector2(0, r), v * u + Vector2(-r, 0)]), Color(0.9, 0.74, 1.0, 0.9))
			if lod > 0:
				Art.spark(b, Vector2(-2.2, 1.4) * u, 1.6 * u, Color(0.92, 0.8, 1.0, 0.8))
		"gale_feather":
			# A long pale feather riding swirls of wind.
			for k in 3:
				var cc := Vector2(-3.0 + k * 3.2, 3.0 - k * 2.4) * u
				b.arc(cc, (2.6 + k * 0.6) * u, PI * 0.2, PI * 1.6, 14, Color(col, 0.75 - k * 0.15), maxf(0.6, 0.6 * u))
			Art.feather(b, Vector2(-7.4, 8.6) * u, Vector2(7.6, -9.0) * u, 3.0 * u, col.lightened(0.15), s)
			Art.rod(b, Vector2(-8.4, 9.8) * u, Vector2(-6.6, 7.6) * u, 0.7 * u, Color(0.9, 0.86, 0.76), s, "")
		"seeing_scroll":
			# A scroll sealed in blue, an open eye drawn on it in silver.
			var body := Rect2(Vector2(-5.6, -4.6) * u, Vector2(11.2, 9.2) * u)
			Art.shape(b, Art.rrect(body, 0.4 * u, 2), Art.PAPER, s, "cloth")
			for sx in [-1.0, 1.0]:
				var x: float = sx * 6.6 * u
				Art.rod(b, Vector2(x, -5.8 * u), Vector2(x, 5.8 * u), 3.0 * u, Art.PAPER.darkened(0.04), s, "cloth")
				b.circle(Vector2(x, -6.0 * u), 0.8 * u, Art.PAPER.darkened(0.45), 10)
			var ec := Vector2(-0.6, -0.4) * u
			var eye := PackedVector2Array()
			for i in 16:
				var a := TAU * i / 16.0
				eye.append(ec + Vector2(cos(a) * 3.8, sin(a) * 2.0 * (1.0 if sin(a) > 0.0 else 1.0)) * u)
			Art.outline(b, eye, s, Art.ol(s) * 0.7)
			b.polygon(eye, Color(0.95, 0.96, 1.0))
			Art.orb(b, ec, 1.5 * u, col.darkened(0.2), s, "gem", false)
			b.circle(ec, 0.6 * u, Color(0.08, 0.06, 0.12), 10)
			Art.soft(b, ec, 5.0 * u, Color(col, 0.3))
			Art.orb(b, Vector2(2.6, 4.6) * u, 1.8 * u, Color(0.3, 0.46, 0.86), s, "gem")
		_:
			Art.orb(b, c, s * 0.5, col, s)


## A tincture: a round-bellied vial of glowing essence, stoppered with a
## little cut crystal of the same kind.
static func _tincture_art(b, col: Color, s: float) -> void:
	var u := Art.unit(s)
	var bc := Vector2(0, 3.2) * u
	var r := 6.0 * u
	Art.soft(b, bc, 8.0 * u, Color(col, 0.35))
	Art.glass(b, _flask(bc, r, Rect2(Vector2(-1.6, -5.4) * u, Vector2(3.2, 3.2) * u)), s, col, bc.y - r * 0.5, 0.9)
	_facets_item(b, Vector2(0, -7.4) * u, 2.6 * u, col.lightened(0.25), s, 6)
	Art.spark(b, bc + Vector2(0.8, 1.0) * u, 2.0 * u, Color(1, 1, 1, 0.85))
	Art.shine(b, bc + Vector2(-2.8, -2.0) * u, 0.8 * u, 1.8 * u)


## A cut stone seen face on, for an item (a lodestone's band).
static func _facets_item(b, c: Vector2, r: float, col: Color, s: float, n := 6) -> void:
	var gem := PackedVector2Array()
	for i in n:
		gem.append(c + Vector2.from_angle(-PI / 2.0 + TAU * i / n) * r)
	Art.outline(b, gem, s, Art.ol(s) * 0.8)
	var l := Art.LIGHT.normalized()
	for i in n:
		var a := gem[i]
		var e := gem[(i + 1) % n]
		var lit := ((a + e) * 0.5 - c).normalized().dot(l)
		b.polygon(PackedVector2Array([c, a, e]), col.lightened(0.38 * lit) if lit > 0.0 else col.darkened(-0.42 * lit))
	b.circle(c + l * r * 0.45, maxf(0.4, r * 0.18), Color(1, 1, 1, 0.8), 8)


## A round flask's outside: a ball of radius `r` at `bc` with a neck.
static func _flask(bc: Vector2, r: float, neck: Rect2) -> PackedVector2Array:
	return _with_neck(Art.oval(bc, Vector2(r, r), 0.0, 32), neck)


## A bottle's outside joined with its neck (the neck reaches down into it).
static func _with_neck(body: PackedVector2Array, neck: Rect2) -> PackedVector2Array:
	var n := PackedVector2Array([neck.position, Vector2(neck.end.x, neck.position.y), neck.end + Vector2(0, neck.size.y), Vector2(neck.position.x, neck.end.y + neck.size.y)])
	var best := body
	var most := 0.0
	for m in Geometry2D.merge_polygons(body, n):
		var a := absf(_area(m))
		if a > most:
			most = a
			best = m
	return best


static func _area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		a += p[i].cross(p[(i + 1) % p.size()])
	return a * 0.5


## A cork in `r`: soft wood, lit on its top.
static func _cork(b, r: Rect2, s: float) -> void:
	Art.shape(b, Art.rrect(r, r.size.y * 0.3, 4), Art.CORK, s, "wood")
	if Art.detail(s) > 0:
		b.circle(r.get_center() + Vector2(r.size.x * 0.2, r.size.y * 0.1), maxf(0.45, r.size.y * 0.09), Color(Art.CORK.darkened(0.4), 0.6), 10)
		# A twist of twine where the cork meets the neck.
		var y := r.end.y + r.size.y * 0.12
		var tw := maxf(0.5, r.size.y * 0.16)
		b.line(Vector2(r.position.x - r.size.x * 0.02, y), Vector2(r.end.x + r.size.x * 0.02, y), Art.INK, tw + Art.ol(s))
		b.line(Vector2(r.position.x - r.size.x * 0.02, y), Vector2(r.end.x + r.size.x * 0.02, y), Color(0.86, 0.76, 0.56), tw)
		b.line(Vector2(r.end.x, y), Vector2(r.end.x + r.size.x * 0.28, y + r.size.y * 0.7), Color(0.86, 0.76, 0.56), tw * 0.8)


## A small flame at `c`, `r` tall: orange round a pale heart. `spark` lights
## it as a fuse's spitting spark instead.
static func _flame(b, c: Vector2, r: float, s: float, spark: bool) -> void:
	if spark:
		Art.soft(b, c, r * 1.6, Color(1.0, 0.6, 0.2, 0.45))
		Art.spark(b, c, r, Color(1.0, 0.68, 0.26))
		Art.spark(b, c, r * 0.55, Color(1.0, 0.97, 0.82))
		return
	var unit := [Vector2(0, -1.0), Vector2(0.3, -0.45), Vector2(0.52, 0.05), Vector2(0.4, 0.5), Vector2(0, 0.66),
		Vector2(-0.4, 0.5), Vector2(-0.52, 0.05), Vector2(-0.18, -0.3)]
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for v in unit:
		outer.append(c + v * r * 1.4)
		inner.append(c + Vector2(0, r * 0.32) + v * r * 0.72)
	outer = Art.smooth(outer, 3)
	inner = Art.smooth(inner, 3)
	Art.soft(b, c + Vector2(0, r * 0.3), r * 1.8, Color(1.0, 0.55, 0.2, 0.4))
	Art.outline(b, outer, s, Art.ol(s) * 0.7)
	Art.grad(b, outer, Color(1.0, 0.72, 0.3), Color(1.0, 0.5, 0.17), Color(0.9, 0.3, 0.12))
	b.polygon(inner, Color(1.0, 0.92, 0.6))


## A crystal chunk (salts): a little faceted lump.
static func _chunk(b, c: Vector2, r: float, col: Color, s: float) -> void:
	var p := Art.pts(c, r / 10.0, [Vector2(-9, 2), Vector2(-5, -8), Vector2(5, -9), Vector2(10, 0), Vector2(5, 8), Vector2(-6, 8)])
	Art.shape(b, p, col, s, "gem", Art.THIN | Art.NO_RIM)
	b.polygon(PackedVector2Array([p[0], p[1], p[2], c]), Color(1, 1, 1, 0.7))


## An essence crystal's icon in the essence's colour, centred on `c` (about
## 2*s across): a tall faceted shard with a glow and a spark.
static func draw_crystal_icon(ci: CanvasItem, col: Color, c: Vector2, s: float, alpha := 1.0) -> void:
	var b := Draw.Batch.new()
	crystal_into(b, col, c, s)
	if alpha < 0.999:
		for i in b.cols.size():
			b.cols[i].a *= alpha
	b.flush(ci)


static func crystal_into(b, col: Color, c: Vector2, s: float) -> void:
	s = Art.size_step(s)
	Art.cached(b, "crystal|%s|%.2f" % [col.to_html(), s], c, func(nb): _crystal_art(nb, col, s))


static func _crystal_art(b, col: Color, s: float) -> void:
	var u := Art.unit(s)
	Art.soft(b, Vector2.ZERO, 10.5 * u, Color(col, 0.32))
	var top := Vector2(0, -9.4) * u
	var bot := Vector2(0, 9.2) * u
	var l := Vector2(-4.8, -1.6) * u
	var r := Vector2(4.8, -1.6) * u
	var ml := Vector2(-3.8, 4.0) * u
	var mr := Vector2(3.8, 4.0) * u
	var mid := Vector2(-0.6, 1.0) * u
	var mid2 := Vector2(0.8, 0.5) * u
	var rr := Art.ramp(col, "gem")
	Art.outline(b, PackedVector2Array([top, r, mr, bot, ml, l]), s)
	Art.grad(b, PackedVector2Array([top, l, ml, mid]), col.lightened(0.35), rr[3], col)
	Art.grad(b, PackedVector2Array([top, mid, mid2, r]), rr[3], col, col.darkened(0.1))
	Art.grad(b, PackedVector2Array([mid2, r, mr, bot]), col, rr[1], rr[0])
	Art.grad(b, PackedVector2Array([mid, ml, bot, mid2]), col, col.darkened(0.12), rr[1])
	b.line(top, mid, Color(col.lightened(0.6), 0.85), maxf(0.6, 0.5 * u))
	b.line(top + Vector2(-0.3, 0.6) * u, l + Vector2(0.5, 0) * u, Color(1, 1, 1, 0.5), maxf(0.5, 0.4 * u))
	Art.spark(b, Vector2(-1.9, -3.6) * u, 2.3 * u, Color(1, 1, 1, 0.88))


## A rune card's mark: a carved stone with a glowing three-stroke sigil.
static func draw_rune_icon(ci: CanvasItem, col: Color, c: Vector2, s: float) -> void:
	var b := Draw.Batch.new()
	s = Art.size_step(s)
	Art.cached(b, "camprune|%s|%.2f" % [col.to_html(), s], c, func(nb): _rune_art(nb, col, s))
	b.flush(ci)


static func _rune_art(b, col: Color, s: float) -> void:
	var u := Art.unit(s)
	var stone := PackedVector2Array()
	for i in 7:
		var a := -PI / 2.0 + TAU * i / 7.0
		stone.append(Vector2.from_angle(a) * (8.6 + (0.8 if i % 2 == 0 else -0.4)) * u)
	Art.shape(b, Art.smooth(stone, 3), Color(0.42, 0.39, 0.5), s)
	Art.soft(b, Vector2.ZERO, 7.5 * u, Color(col, 0.45))
	for i in 3:
		var a := -PI / 2.0 + TAU * i / 3.0
		var p0 := Vector2.from_angle(a) * 1.4 * u
		var p1 := Vector2.from_angle(a + 2.2) * 5.6 * u
		b.line(p0, p1, Color(Art.INK, 0.8), 2.0 * u)
		b.line(p0, p1, col.lightened(0.25), 1.0 * u)
	b.circle(Vector2.ZERO, 1.3 * u, col.lightened(0.5), 12)
