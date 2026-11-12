extends RefCounted
## Gear: what you wear and carry, how it's found, compared and worn down.
## Weapons themselves are defined in weapons.gd. Names, text and numbers
## live here so they're easy to change.
##
## A piece of gear is a small RECORD (a Dictionary), not a bare id:
##   base    which piece it is: a weapon id (weapons.gd), an armor id (ARMOR)
##           or a piece id (PIECES)
##   rarity  "common" or better (RARITIES); Commons wear down, the rest don't
##   traits  trait ids (none yet: rarities and traits come later)
##   rank    tempering rank 0 to 3 (the bench, bench.gd): each rank raises
##           its traits by RANK_TRAIT of their base, a weapon's damage by
##           RANK_WEAPON
##   rune    a lasting rune inscribed at the bench by a Rune Artist
##           (LASTING_RUNES), or none
##   wear    condition from 1.0 (new) to 0.0 (broken); Commons only
## make() builds one, rec() turns an old plain id (or a record) into one,
## and every function here takes either a record or a plain id.
##
## You wear: fists (always), a melee weapon, a ranged weapon, a chest piece
## (armor), a helm, gloves, legs, boots, a cloak, an amulet, two rings and a
## backpack. An off-hand slot is kept for later. Gear is per climb: every
## climb starts with a sword, a shortbow and nothing else, except for slots
## holding an heirloom (below).

const Weapons := preload("res://scripts/weapons.gd")
const Essence := preload("res://scripts/essence.gd")

## The chance a slain monster (not a beast) leaves a piece of gear.
const DROP_CHANCE := 0.04
## The chance a cache room's essence cache also holds a piece of gear.
const CACHE_CHANCE := 0.35
## How close you must stand to gear on the floor to take it.
const REACH := 26.0
## Protection from every piece adds up, to at most this much.
const PROTECTION_CAP := 0.5
## Each heavy piece (besides the chest, which has its own weight) makes a
## roll cost this much more stamina.
const HEAVY_ROLL := 0.03
## A blow this light (before protection) can't knock you back in Hobnail Boots.
const LIGHT_BLOW := 14.0
## The pack: spare pieces carried besides what you wear (a Climber's Pack
## holds more: its "pack" number). Survive a climb (or read a recall
## scroll) and the pack comes home to the train, to sell or keep in your
## chest; fall and it's lost.
const PACK_SIZE := 4

## The carried slots, in the order the inventory and the save list them.
## "offhand" is kept for later (always empty for now).
const SLOTS := ["melee", "ranged", "armor", "helm", "gloves", "legs", "boots", "cloak", "amulet", "ring1", "ring2", "backpack", "offhand"]
## The slots added by worn pieces (PIECES), besides weapons and the chest.
const PIECE_SLOTS := ["helm", "gloves", "legs", "boots", "cloak", "amulet", "ring", "backpack"]
static var SLOT_NAMES := {
	"fists": "Fists", "melee": "Melee", "ranged": "Ranged", "armor": "Chest", "helm": "Helm", "gloves": "Gloves",
	"legs": "Legs", "boots": "Boots", "cloak": "Cloak", "amulet": "Amulet", "ring": "Ring", "ring1": "Ring",
	"ring2": "Ring", "backpack": "Backpack", "offhand": "Off-hand",
}
## The inventory's paper doll: what you wear, laid out like a body.
const DOLL := [
	["helm", "amulet", "cloak"],
	["melee", "armor", "ranged"],
	["ring1", "gloves", "ring2"],
	["backpack", "legs", "boots"],
]

## Rarities, from plain to the tower's own notice. Better pieces carry
## traits (TRAITS) and never wear; weapons also hit a little harder.
##   wears   the piece loses condition as you use it, and can break
##   traits  how many traits a piece of this rarity carries (fewer for
##           rings and amulets, which are Fine to begin with: natural_rarity)
##   boost   a weapon of this rarity hits this much harder
##   named_traits  how many traits a named piece of this rarity carries
##           besides its own rule
## "Regarded" pieces are the beasts' own weapons and armour (NAMED "beast"):
## never found as plain pieces, only where a slain beast falls (REGARDED_DROP).
const RARITY_ORDER := ["common", "fine", "rare", "storied", "regarded"]
static var RARITIES := {
	"common": {"name": "Common", "color": Color(0.9, 0.86, 0.76), "wears": true, "traits": 0, "boost": 0.0, "named_traits": 0},
	"fine": {"name": "Fine", "color": Color(0.55, 0.85, 0.5), "wears": false, "traits": 1, "boost": 0.05, "named_traits": 1},
	"rare": {"name": "Rare", "color": Color(0.45, 0.65, 1.0), "wears": false, "traits": 2, "boost": 0.10, "named_traits": 1},
	"storied": {"name": "Storied", "color": Color(0.95, 0.62, 0.24), "wears": false, "traits": 1, "boost": 0.12, "named_traits": 1},
	"regarded": {"name": "Regarded", "color": Color(1.0, 0.86, 0.36), "wears": false, "traits": 4, "boost": 0.15, "named_traits": 4},
}

## How rare a piece is, by floor (slain monsters). Vaults, caches and camps
## roll one row higher (the last row is only reached that way). Storied
## pieces are only found from STORIED_FROM up; below it they count as Rare.
static var RARITY_ODDS := [
	{"to": 3, "odds": {"common": 80, "fine": 20, "rare": 0, "storied": 0}},
	{"to": 6, "odds": {"common": 60, "fine": 32, "rare": 8, "storied": 0}},
	{"to": 9, "odds": {"common": 45, "fine": 38, "rare": 15, "storied": 2}},
	{"to": 12, "odds": {"common": 35, "fine": 40, "rare": 20, "storied": 5}},
	{"to": 99, "odds": {"common": 25, "fine": 40, "rare": 27, "storied": 8}},
]
const STORIED_FROM := 7
## A Rare find in a tower with its own pieces (NAMED "tower") is one of
## them this often.
static var TOWER_PIECE_CHANCE := 0.3
## Finds of this rarity or better fade in a short notice on the HUD.
const NOTICE_FROM := "rare"

## Traits: every one belongs to an essence kind (its colour; later the bench
## tempers it with that kind's crystals) and rolls only on the slots listed.
## A piece never carries the same trait twice (make() replaces a repeat with
## another that fits). Every slot but the backpack has at least four, so a
## Regarded piece always gets four different ones.
## "fine" is its strength on a Fine piece, "rare" on Rare and better. "key"
## is the number it adds to (see PIECES and EFFECT_ROWS); "desc" says it.
const TRAIT_ORDER := ["vigor", "footing", "mending", "venom", "edges", "riposte", "breath", "second_wind", "thorns", "wind", "rolling", "hunt", "quickdraw",
	"shadows", "striding", "kindling", "embers", "lantern", "well", "calm"]
static var TRAITS := {
	"vigor": {"name": "of Vigor", "short": "Vigor", "kind": "stone", "key": "health", "fine": 6.0, "rare": 10.0,
		"slots": ["helm", "armor", "legs", "cloak", "amulet"], "desc": "+%s health"},
	"footing": {"name": "of Footing", "short": "Footing", "kind": "stone", "key": "footing", "fine": 0.15, "rare": 0.25,
		"slots": ["boots", "legs"], "desc": "traps and burning floor hurt %s less"},
	"edges": {"name": "of Edges", "short": "Edges", "kind": "blade", "key": "strike", "fine": 0.05, "rare": 0.08,
		"slots": ["melee", "gloves", "ring"], "desc": "strikes hit %s harder"},
	"riposte": {"name": "of the Riposte", "short": "Riposte", "kind": "blade", "key": "riposte", "fine": 0.08, "rare": 0.12,
		"slots": ["melee", "gloves", "ranged"], "desc": "ripostes and backstabs hit %s harder"},
	"breath": {"name": "of Breath", "short": "Breath", "kind": "iron", "key": "stamina", "fine": 8.0, "rare": 12.0,
		"slots": ["legs", "armor", "cloak"], "desc": "+%s max stamina"},
	"second_wind": {"name": "of Second Wind", "short": "Second Wind", "kind": "iron", "key": "regen", "fine": 0.06, "rare": 0.10,
		"slots": ["ring", "amulet", "armor", "ranged"], "desc": "stamina refills %s faster"},
	"thorns": {"name": "of Thorns", "short": "Thorns", "kind": "iron", "key": "thorns", "fine": 3.0, "rare": 5.0,
		"slots": ["armor", "gloves"], "desc": "foes that strike you up close take %s damage"},
	"wind": {"name": "of the Wind", "short": "Wind", "kind": "air", "key": "walk", "fine": 0.04, "rare": 0.06,
		"slots": ["boots", "cloak", "legs"], "desc": "you walk %s faster"},
	"rolling": {"name": "of Rolling", "short": "Rolling", "kind": "air", "key": "roll_cost", "fine": 0.05, "rare": 0.08,
		"slots": ["boots", "legs"], "desc": "rolls cost %s less stamina"},
	"hunt": {"name": "of the Hunt", "short": "Hunt", "kind": "air", "key": "ranged", "fine": 0.08, "rare": 0.12,
		"slots": ["ranged", "gloves", "helm"], "desc": "bows, crossbows and pistols hit %s harder"},
	"kindling": {"name": "of Kindling", "short": "Kindling", "kind": "fire", "key": "spell", "fine": 0.06, "rare": 0.09,
		"slots": ["amulet", "ring", "helm"], "desc": "spells hit %s harder"},
	"embers": {"name": "of Embers", "short": "Embers", "kind": "fire", "key": "embers", "fine": 0.10, "rare": 0.15,
		"slots": ["melee", "gloves", "ranged"], "desc": "hits have a %s chance to set the foe burning"},
	"well": {"name": "of the Well", "short": "Well", "kind": "water", "key": "fill", "fine": 0.06, "rare": 0.09,
		"slots": ["amulet", "ring", "helm", "ranged"], "desc": "marks fill %s faster"},
	"calm": {"name": "of Calm", "short": "Calm", "kind": "water", "key": "parry", "fine": 0.05, "rare": 0.08,
		"slots": ["gloves", "helm", "ring"], "desc": "the parry window is %s longer"},
	"mending": {"name": "of Mending", "short": "Mending", "kind": "stone", "key": "kill_heal", "fine": 2.0, "rare": 3.0,
		"slots": ["melee", "ranged", "amulet"], "desc": "each kill heals you %s"},
	"venom": {"name": "of Venom", "short": "Venom", "kind": "stone", "key": "venom_chance", "fine": 0.08, "rare": 0.12,
		"slots": ["melee", "ranged"], "desc": "hits have a %s chance to poison the foe"},
	"quickdraw": {"name": "of the Quick Draw", "short": "Quick Draw", "kind": "air", "key": "draw", "fine": 0.08, "rare": 0.12,
		"slots": ["ranged", "gloves"], "desc": "bows draw, and crossbows and pistols reload, %s faster"},
	"shadows": {"name": "of Shadows", "short": "Shadows", "kind": "air", "key": "notice", "fine": 0.10, "rare": 0.15,
		"slots": ["cloak", "boots", "helm", "ranged"], "desc": "monsters notice you %s later"},
	"striding": {"name": "of Striding", "short": "Striding", "kind": "air", "key": "roll_dist", "fine": 0.05, "rare": 0.08,
		"slots": ["boots", "legs", "cloak"], "desc": "rolls carry %s farther"},
	"lantern": {"name": "of the Lantern", "short": "Lantern", "kind": "fire", "key": "light", "fine": 0.10, "rare": 0.15,
		"slots": ["helm", "amulet", "cloak", "armor"], "desc": "your light reaches %s farther"},
}
## Tempering (the bench): each rank adds this share of a trait's base
## strength, and makes a weapon hit this much harder.
const RANK_TRAIT := 0.25
const RANK_WEAPON := 0.04
const MAX_RANK := 3
## The highest rank any piece can hold: a Rune Artist working a full vessel
## into a +3 piece tempers it one past MAX_RANK (vessel.gd).
const RANK_CAP := 4

## Lasting runes: a Rune Artist inscribes one on a piece at the bench, and
## it stays on it. Half the strength of the Inscribe spell's runes (bond.gd
## GEAR_RUNES): "key" is the number it adds to (as a trait does), "value"
## how much. Drawn on the piece's icon as a rune hashed from its id.
## The "deep" runes are the same at the spell's full strength: only a Rune
## Artist working a full vessel inscribes one (vessel.gd), never the
## bench's own Inscribe.
static var LASTING_RUNES := {
	"sharpness": {"name": "Rune of Sharpness", "short": "Sharpness", "key": "strike", "value": 0.10,
		"desc": "strikes hit %s harder", "color": Color(1.0, 0.7, 0.45)},
	"warding": {"name": "Rune of Warding", "short": "Warding", "key": "reduce", "value": 0.08,
		"desc": "%s protection from blows", "color": Color(0.6, 0.8, 1.0)},
	"swiftness": {"name": "Rune of Swiftness", "short": "Swiftness", "key": "walk", "value": 0.05,
		"desc": "you walk %s faster", "color": Color(0.7, 1.0, 0.7)},
	"deep_sharpness": {"name": "Deep Rune of Sharpness", "short": "Deep Sharpness", "key": "strike", "value": 0.20, "deep": true,
		"desc": "strikes hit %s harder", "color": Color(1.0, 0.62, 0.32)},
	"deep_warding": {"name": "Deep Rune of Warding", "short": "Deep Warding", "key": "reduce", "value": 0.16, "deep": true,
		"desc": "%s protection from blows", "color": Color(0.5, 0.74, 1.0)},
	"deep_swiftness": {"name": "Deep Rune of Swiftness", "short": "Deep Swiftness", "key": "walk", "value": 0.10, "deep": true,
		"desc": "you walk %s faster", "color": Color(0.58, 1.0, 0.58)},
}

## Of Embers: a burning foe takes this much every half second, this long.
static var EMBER_BURN := {"dmg": 2.0, "time": 2.0}
## Thorns only answer blows from this close.
const THORNS_REACH := 70.0

## What gear adds up to at most, so stacking pieces can't break fights.
## The inventory shows "(capped)" beside a number that has reached its cap.
static var CAPS := {"strike": 0.25, "health": 40.0, "stamina": 30.0, "walk": 0.12, "spell": 0.20}

## Named pieces keep their own names. Each is a base piece (its look, slot
## and, for weapons and armor, how it fights) with its own rule:
##   tower   only found in that tower (the Rare tower pieces)
##   kind    its essence
##   fx      numbers and rules it adds (worn pieces: instead of the base's own)
##   armor   chest numbers that replace the base armor's
##   color   its icon's colour (else the base's)
##   short   its name under its slot
##   beast   a Regarded piece: that tower's beast's own (REGARDED_DROP)
##   history its story, for the owner to write: shown on its card only once
##           it isn't blank
##   enchanted  false for a relic that isn't enchanted (an old plain piece
##           with its own rule); the rest are enchanted in their "kind"
## The rules (fx keys) are read by player.gd: arc, chill, cinder, venom,
## kill_heal, thorn_burst, thorns, watch, kill_fill, dodge_haste, iframe,
## ember_mend, still_mend, spellweave, kill_mark, bastion, draw_mark,
## still_guard, seek, parry_sta, and the beasts' gale and arcs, grasp and
## ink, quake, volley and venom_shot, rebirth, triune; and the canes' and
## pistols' quell, draw_venom, last_shot and kill_load.
const NAMED_ORDER := ["stormstring", "coral_trident", "cinder_axe", "stinger_dagger", "sunsteel_blade", "thornmaul", "barnacle_mail", "wyvern_scaleplate",
	"watchers_helm", "quickhand_gloves", "phantom_treads", "emberkin_mantle", "heartstone", "spellweave_ring", "reavers_greatsword", "bastion_plate",
	"hollowmoon_bow", "rootbound_greaves", "wayfinders_pendant", "duelists_ring", "ashgrove_cane", "quietsteel", "lastbell_revolver", "emberlock",
	"stormtalon", "deepcoil_coat", "wyrmspine_mace", "spinecaster", "sunplume_mantle", "triune_fang"]
static var NAMED := {
	# Rare tower pieces: only in their own tower.
	"stormstring": {"base": "shortbow", "history": "", "rarity": "rare", "tower": "gryphon", "kind": "air", "name": "Stormstring", "short": "Stormstring",
		"desc": "a shortbow strung with storm-gut: a full draw also arcs to one more foe for half damage", "fx": {"arc": 0.5}},
	"coral_trident": {"base": "spear", "history": "", "rarity": "rare", "tower": "kraken", "kind": "water", "name": "Coral Trident", "short": "Trident",
		"desc": "a three-pronged spear of living coral: its hits slow foes by 25% for 1.5 s", "fx": {"chill": 1.5}},
	"cinder_axe": {"base": "axe", "history": "", "rarity": "rare", "tower": "wyvern", "kind": "fire", "name": "Cinder Axe", "short": "Cinder Axe",
		"desc": "an axe that never cools: its finisher leaves the floor burning for 2 s (it burns foes, not you)", "fx": {"cinder": 2.0}},
	"stinger_dagger": {"base": "dagger", "history": "", "rarity": "rare", "tower": "manticore", "kind": "stone", "name": "Stinger Dagger", "short": "Stinger",
		"desc": "a dagger ground from a stinger: every hit poisons the foe a little more", "fx": {"venom": 1.0}},
	"sunsteel_blade": {"base": "sword", "history": "", "rarity": "rare", "tower": "firebird", "kind": "fire", "name": "Sunsteel Blade", "short": "Sunsteel",
		"desc": "a sword with a warm, bright edge: each kill heals you 4", "fx": {"kill_heal": 4.0}},
	"thornmaul": {"base": "war_hammer", "history": "", "rarity": "rare", "tower": "chimera", "kind": "blade", "name": "Thornmaul", "short": "Thornmaul",
		"desc": "a hammer bound in briars: a staggering finisher throws thorns at foes nearby for 6 each", "fx": {"thorn_burst": 6.0}},
	"barnacle_mail": {"base": "chain", "history": "", "rarity": "rare", "tower": "kraken", "kind": "water", "name": "Barnacle Mail", "short": "Barnacle",
		"desc": "chain mail crusted with shells: foes that strike you up close take 5", "fx": {"thorns": 5.0}, "color": Color(0.5, 0.66, 0.66)},
	"wyvern_scaleplate": {"base": "plate", "history": "", "rarity": "rare", "tower": "wyvern", "kind": "iron", "name": "Wyvern Scaleplate", "short": "Scaleplate",
		"desc": "plate of overlapping scales: 32% off a blow, with only chain mail's weight",
		"armor": {"reduce": 0.32, "roll_cost": 1.3, "roll_dist": 0.88, "regen": 0.87, "walk": 0.95}, "color": Color(0.62, 0.42, 0.36)},
	# Storied pieces: rare finds from floor 7 up, each with its own story.
	"watchers_helm": {"base": "iron_helm", "history": "", "rarity": "storied", "kind": "iron", "name": "Watcher's Helm", "short": "Watcher's",
		"desc": "a helm with a narrow slit: foes you parry take 20% more damage from you for 3 s; +6 health", "fx": {"health": 6.0, "watch": 0.2},
		"color": Color(0.62, 0.66, 0.8)},
	"quickhand_gloves": {"base": "leather_gloves", "history": "", "rarity": "storied", "kind": "blade", "name": "Quickhand Gloves", "short": "Quickhand",
		"desc": "thin gloves stained dark: each kill fills your hand's mark by 5% of its pool; strikes hit 3% harder", "fx": {"strike": 0.03, "kill_fill": 0.05},
		"color": Color(0.42, 0.2, 0.24)},
	"phantom_treads": {"base": "soft_boots", "history": "", "rarity": "storied", "kind": "air", "name": "Phantom Treads", "short": "Phantom",
		"desc": "boots that leave no prints: a dodge quickens your walk by 20% for 2 s, and a roll keeps you untouchable a moment longer",
		"fx": {"dodge_haste": 0.2, "iframe": 0.05}, "color": Color(0.7, 0.78, 0.86)},
	"emberkin_mantle": {"base": "travel_cloak", "history": "", "rarity": "storied", "kind": "fire", "name": "Emberkin Mantle", "short": "Emberkin",
		"desc": "a cloak that smoulders at the hem: once a floor, falling below a fifth of your health heals 25 over 2 s", "fx": {"ember_mend": 25.0},
		"color": Color(0.7, 0.3, 0.18)},
	"heartstone": {"base": "bone_charm", "history": "", "rarity": "storied", "kind": "stone", "name": "Heartstone", "short": "Heartstone",
		"desc": "a stone that beats: +16 health, and you regain 1 health every 3 s while no monster has noticed you", "fx": {"health": 16.0, "still_mend": 1.0},
		"color": Color(0.85, 0.35, 0.35)},
	"spellweave_ring": {"base": "garnet_ring", "history": "", "rarity": "storied", "kind": "fire", "name": "Spellweave Ring", "short": "Spellweave",
		"desc": "a ring of three braided wires: every third spell you cast costs nothing", "fx": {"spellweave": 3.0}, "color": Color(0.85, 0.55, 0.95)},
	"reavers_greatsword": {"base": "greatsword", "history": "", "rarity": "storied", "kind": "blade", "name": "Reaver's Greatsword", "short": "Reaver's",
		"desc": "a notched greatsword: kills restore 4 health and 4 essence to your hand's mark", "fx": {"kill_heal": 4.0, "kill_mark": 4.0}},
	"bastion_plate": {"base": "plate", "history": "", "rarity": "storied", "kind": "iron", "name": "Bastion Plate", "short": "Bastion",
		"desc": "old, dented plate: once a floor, falling below 30% health raises a 30-point barrier for 6 s", "fx": {"bastion": 30.0},
		"color": Color(0.74, 0.7, 0.6)},
	"hollowmoon_bow": {"base": "longbow", "history": "", "rarity": "storied", "kind": "water", "name": "Hollowmoon Bow", "short": "Hollowmoon",
		"desc": "a pale bow bent like a new moon: a full draw that hits pours 4 essence into your hand's mark", "fx": {"draw_mark": 4.0},
		"color": Color(0.78, 0.84, 0.95)},
	"rootbound_greaves": {"base": "plated_greaves", "history": "", "rarity": "storied", "kind": "stone", "name": "Rootbound Greaves", "short": "Rootbound",
		"desc": "greaves grown through with living root: 5% damage taken off and +8 health; while you stand still, blows hurt 25% less",
		"fx": {"reduce": 0.05, "health": 8.0, "still_guard": 0.25}, "color": Color(0.52, 0.44, 0.32)},
	"wayfinders_pendant": {"base": "sunstone_pendant", "history": "", "rarity": "storied", "kind": "air", "name": "Wayfinder's Pendant", "short": "Wayfinder",
		"desc": "a compass whose needle points at what is hidden: secret walls and hidden traps near you glint; your light reaches 15% farther",
		"fx": {"seek": 220.0, "light": 0.15}, "color": Color(0.5, 0.78, 0.95)},
	"duelists_ring": {"base": "silver_ring", "history": "", "rarity": "storied", "kind": "blade", "name": "Duelist's Ring", "short": "Duelist's",
		"desc": "a ring worn smooth by a duelist's thumb: the parry window is 10% longer, and every parry gives back 15 more stamina",
		"fx": {"parry": 0.10, "parry_sta": 15.0}, "color": Color(0.88, 0.3, 0.32)},
	"ashgrove_cane": {"base": "cane", "history": "", "rarity": "storied", "kind": "stone", "name": "Ashgrove Cane", "short": "Ashgrove",
		"desc": "a cane of pale ash, its knob worn bright: a perfect parry with it staggers every foe near you for a moment", "fx": {"quell": 0.8},
		"color": Color(0.86, 0.8, 0.66)},
	"quietsteel": {"base": "sword_cane", "history": "", "rarity": "storied", "kind": "blade", "name": "Quietsteel", "short": "Quietsteel",
		"desc": "a sword-cane whose blade comes out without a whisper: its drawn finisher poisons every foe it cuts", "fx": {"draw_venom": 3.0},
		"color": Color(0.32, 0.3, 0.36)},
	"lastbell_revolver": {"base": "revolver", "history": "", "rarity": "storied", "kind": "iron", "enchanted": false, "name": "Lastbell Revolver", "short": "Lastbell",
		"desc": "an old, plain revolver, not enchanted: it reloads like any other, but the last shot in the cylinder hits twice as hard", "fx": {"last_shot": 1.0},
		"color": Color(0.7, 0.56, 0.32)},
	"emberlock": {"base": "flintlock", "history": "", "rarity": "storied", "kind": "fire", "name": "Emberlock", "short": "Emberlock",
		"desc": "a flintlock whose pan never goes cold: it fires fire shot, and a kill with it fills its chamber at once", "fx": {"kill_load": 1.0},
		"color": Color(0.72, 0.34, 0.2)},
	# Regarded pieces: each tower's beast's own weapon or armour, left where it
	# falls (REGARDED_DROP). Four traits besides its rule; never wears.
	"stormtalon": {"base": "longbow", "history": "", "rarity": "regarded", "beast": "gryphon", "kind": "air", "name": "Stormtalon", "short": "Stormtalon",
		"desc": "the Gryphon's own bow, strung with its storm: a full draw flies faster and hits harder, and arcs on to two more foes for 60%",
		"fx": {"gale": 1.6, "arc": 0.6, "arcs": 2.0}, "color": Color(0.62, 0.8, 1.0)},
	"deepcoil_coat": {"base": "leather", "history": "", "rarity": "regarded", "beast": "kraken", "kind": "water", "name": "Deepcoil Coat", "short": "Deepcoil",
		"desc": "the Kraken's own hide, cured dark: 24% off a blow with leather's lightness; foes that strike you up close are gripped and slowed; once a floor, falling below half health bursts a cloud of ink that hides you",
		"armor": {"reduce": 0.24, "roll_cost": 1.1, "roll_dist": 0.96, "regen": 0.96, "walk": 0.99}, "fx": {"grasp": 2.0, "ink": 5.0},
		"color": Color(0.24, 0.42, 0.5)},
	"wyrmspine_mace": {"base": "mace", "history": "", "rarity": "regarded", "beast": "wyvern", "kind": "iron", "name": "Wyrmspine Mace", "short": "Wyrmspine",
		"desc": "the Wyvern's own spine, set on a haft: a heavy blow cracks the floor, and the foes near the one you hit take 12 and stagger",
		"fx": {"quake": 12.0}, "color": Color(0.86, 0.8, 0.66)},
	"spinecaster": {"base": "crossbow", "history": "", "rarity": "regarded", "beast": "manticore", "kind": "stone", "name": "Spinecaster", "short": "Spinecaster",
		"desc": "the Manticore's own tail, strung as a crossbow: each bolt looses two barbs beside it (half damage), and every barb poisons",
		"fx": {"volley": 2.0, "venom_shot": 2.0}, "color": Color(0.78, 0.5, 0.3)},
	"sunplume_mantle": {"base": "travel_cloak", "history": "", "rarity": "regarded", "beast": "firebird", "kind": "fire", "name": "Sunplume Mantle", "short": "Sunplume",
		"desc": "a cloak of the Firebird's own plumes: once a climb, a blow that would fell you bursts you into flame and you rise with 40% of your health; poison and burning floor hurt 25% less",
		"fx": {"rebirth": 0.4, "ailment": 0.25}, "color": Color(0.95, 0.46, 0.2)},
	"triune_fang": {"base": "greatsword", "history": "", "rarity": "regarded", "beast": "chimera", "kind": "blade", "name": "Triune Fang", "short": "Triune",
		"desc": "the Chimera's own fang, three heads on one hilt: its strikes take turns between them; the lion's hits 30% harder, the goat's staggers, the serpent's poisons",
		"fx": {"triune": 0.3}, "color": Color(0.86, 0.68, 0.4)},
}
## A tower's beast leaves its Regarded piece where it falls: always the
## first time you slay it, and after that this often ("again").
static var REGARDED_DROP := {"first": 1.0, "again": 0.25}

## Wear (Common pieces only): how much condition each use takes off.
##   strike  a melee swing that lands (the melee weapon and gloves)
##   shot    an arrow or bolt loosed (the ranged weapon)
##   hit     a blow that lands on you (chest, helm, legs and cloak)
##   roll    a roll or jump (boots)
## At WORN or less a piece is badly worn: its bonus is halved (a weapon hits
## WORN_WEAPON as hard, a chest piece protects half as much). At 0 it breaks.
## Roughly: a weapon is badly worn after ~940 landed swings, a chest piece
## after ~94 blows, boots after ~500 rolls: about a whole climb of steady use.
static var WEAR := {"strike": 0.0008, "shot": 0.003, "hit": 0.008, "roll": 0.0015}
static var WEAR_BY := {
	"strike": ["melee", "gloves"], "shot": ["ranged"], "hit": ["armor", "helm", "legs", "cloak"], "roll": ["boots"],
}
const WORN := 0.25
const WORN_WEAPON := 0.75

## Heirlooms: survive a climb and you may keep one piece you carried. It
## waits for you at the start of every later climb, in its slot, until you
## keep a different piece for that slot (or start a new climber). Each slot
## holds one heirloom, except Rings, which keeps both rings you wear. "gear"
## is the slot (slot_of) it fills; "planned" slots are kept for later.
const HEIRLOOM_SLOTS := [
	{"id": "melee", "name": "Melee", "gear": "melee"},
	{"id": "ranged", "name": "Ranged", "gear": "ranged"},
	{"id": "chest", "name": "Chest", "gear": "armor"},
	{"id": "helm", "name": "Helm", "gear": "helm"},
	{"id": "gloves", "name": "Gloves", "gear": "gloves"},
	{"id": "legs", "name": "Legs", "gear": "legs"},
	{"id": "boots", "name": "Boots", "gear": "boots"},
	{"id": "cloak", "name": "Cloak", "gear": "cloak"},
	{"id": "amulet", "name": "Amulet", "gear": "amulet"},
	{"id": "rings", "name": "Rings", "gear": "ring"},
	{"id": "backpack", "name": "Backpack", "gear": "backpack"},
	{"id": "offhand", "name": "Off-hand", "planned": true},
]
static var HEIRLOOM_TEXT := {
	"title": "CHOOSE AN HEIRLOOM",
	"sub": "You survived. Keep one piece you carried: every climb will begin with it.",
	"replaces": "replaces your %s",
	"empty_slot": "new %s heirloom",
	"none_name": "Keep nothing new",
	"none_desc": "your heirlooms stay as they are",
	"kept": "Heirloom kept: %s",
	"planned": "planned",
	"rings_name": "Your rings",
	"rings_desc": "both rings you wear: %s",
}

## The words the gear prompt, cards and inventory use.
static var TEXT := {
	"on_floor": "ON THE FLOOR",
	"take_key": "Y  take it",
	"take_pad": "{y}  take it",  # a controller ({y} becomes Y or Triangle)
	"take_tap": "Tap Take",
	"drops": "(drops your %s here)",
	"to_pack": "(your %s goes in your pack)",
	"packed": "Into your pack: %s",
	"pack_full": "Your pack is full",
	"took": "Took the %s",
	"camp_desc": "%s",
	"carrying": "carrying: %s",
	"none": "no armor",
	"empty": "nothing",
	"cache": "The cache holds a %s",
	"worn": "Badly worn: its bonus is halved",
	"worn_weapon": "Badly worn: it hits 25% softer",
	"condition": "Condition %d%%",
	"never_wears": "never wears",
	"broke": "Your %s broke",
	"plays_like": "Compared with yours: %s",
	"plays_same": "plays much like yours",
	"tower_piece": "found only in its tower",
	"capped": "%s (capped)",
	"notice": "%s: %s",  # "RARE: Coral Trident"
	"beast_piece": "left by its beast",
	"beast_kept": "%s comes down with you, in your pack",
	# Ordinary or enchanted (cards): a Common piece is ordinary, with only its
	# own use; Fine and Rare pieces are enchanted (their traits), and so are
	# rings and amulets by nature; Storied and Regarded pieces are relics.
	"ordinary": "ordinary",
	"enchanted": "Enchanted: %s essence",
	"relic": "A relic, enchanted: %s essence",
	"relic_plain": "A relic, not enchanted",
	"history": "%s",
}

## Armor (the chest slot). Reduction cuts the damage of attacks that land
## (not poison or burning floor). Heavier armor makes rolls cost more and
## carry you less far, stamina refill slower, and you walk a little slower.
##   reduce     fraction of a landed attack's damage taken off
##   roll_cost  multiplier on a roll's stamina cost
##   roll_dist  multiplier on how far a roll carries you
##   regen      multiplier on how fast stamina refills
##   walk       multiplier on walking speed
##   step       a sound layered on each footstep (chain mail and plate jingle)
const ARMOR_ORDER := ["", "padded", "leather", "chain", "plate"]
static var ARMOR := {
	"": {
		"name": "No armor",
		"short": "None",
		"desc": "nothing but your cloak: light and quick",
		"reduce": 0.0, "roll_cost": 1.0, "roll_dist": 1.0, "regen": 1.0, "walk": 1.0,
		"color": Color(0.28, 0.55, 0.62),
	},
	"padded": {
		"name": "Padded Armor",
		"short": "Padded",
		"desc": "quilted cloth: a little protection for almost no weight",
		"reduce": 0.08, "roll_cost": 1.05, "roll_dist": 0.98, "regen": 0.98, "walk": 1.0,
		"color": Color(0.72, 0.64, 0.5),
		"drop_weight": 4,
	},
	"leather": {
		"name": "Leather Armor",
		"short": "Leather",
		"desc": "hardened leather: fair protection, still nimble",
		"reduce": 0.15, "roll_cost": 1.12, "roll_dist": 0.95, "regen": 0.95, "walk": 0.98,
		"color": Color(0.5, 0.33, 0.2),
		"drop_weight": 4,
	},
	"chain": {
		"name": "Chain Mail",
		"short": "Chain",
		"desc": "rings of steel: good protection; rolls cost more and stamina comes back slower",
		"reduce": 0.25, "roll_cost": 1.3, "roll_dist": 0.88, "regen": 0.87, "walk": 0.95,
		"step": "step_chain",
		"color": Color(0.62, 0.65, 0.7),
		"drop_weight": 3,
	},
	"plate": {
		"name": "Plate Armor",
		"short": "Plate",
		"desc": "heavy steel: the best protection, but rolls are short and costly, and you tire fast",
		"reduce": 0.35, "roll_cost": 1.55, "roll_dist": 0.76, "regen": 0.75, "walk": 0.9,
		"step": "step_plate",
		"color": Color(0.8, 0.82, 0.88),
		"drop_weight": 1,
	},
}

## Worn pieces for the other slots. Each has a slot, a name, a line of what
## it does and its numbers (all optional; player.gd reads them through
## effects()):
##   health    more max health          stamina   more max stamina
##   reduce    damage taken off (adds to the chest's, up to PROTECTION_CAP)
##   strike    melee strikes hit this much harder
##   chain     strike chains cost this much less stamina
##   parry     the parry window, this much longer (negative: shorter)
##   roll_dist rolls carry this much farther
##   walk      walking speed (negative: slower)
##   light     your own light reaches this much farther
##   regen     stamina refills this much faster
##   spell     spells hit this much harder
##   notice    monsters take this much longer to notice you
##   ailment   poison wears off and burning floor hurts this much less
##   stack     carry this many more of each item (not the recall scroll)
##   belt      more kinds of item on the belt
##   pack      room for this many more spare pieces in your pack (PACK_SIZE)
##   jump      jumps carry this much farther; free_jump: jumps cost no stamina
##   ranged    bows and crossbows hit this much harder
##   draw      bows draw and crossbows reload this much faster
##   thorns    foes that strike you up close take this much
##   footing   traps and burning floor hurt this much less
##   riposte   ripostes and backstabs hit this much harder
##   venom_chance  hits have this chance to poison the foe
##   item_heal healing items heal this much more
##   wade      water doesn't slow you
##   steady    light blows (under LIGHT_BLOW) can't knock you back
##   heavy     adds HEAVY_ROLL to a roll's cost
##   rarity    a piece that is always this rarity (rings and amulets are Fine)
##   kind      the essence of a piece enchanted by nature (rings and amulets);
##             plain pieces have none: they're ordinary
##   finisher  a chain's finisher hits this much harder
##   fist      your bare fists hit this much harder
##   kill_sta  each kill gives back this much stamina
##   quick_breath  stamina starts refilling this much sooner after you act
##   parry_heal    a perfect parry heals you this much
##   drop_weight  how common it is as a drop (0: not found yet)
##   look      how it shows on the climber (player.gd)
## Penalties (heavy, a shorter parry, a slower walk) stay when a piece is
## badly worn; only its bonuses halve.
const PIECE_ORDER := [
	"cloth_hood", "leather_cap", "iron_helm", "grip_wraps", "leather_gloves", "gauntlets",
	"padded_trousers", "leather_leggings", "chain_leggings", "soft_boots", "climbing_boots", "hobnail_boots",
	"travel_cloak", "dusk_cloak", "satchel", "belt_pouch", "bone_charm", "ember_charm", "iron_band", "garnet_ring",
	"tide_locket", "pearl_ring", "overdrawn_ring", "climbers_pack",
	"feathered_cap", "miners_helm", "archers_bracers", "studded_gloves", "ranger_breeches", "plated_greaves", "wading_boots", "feather_cape",
	"herb_pouch", "wolf_tooth", "sunstone_pendant", "silver_ring", "jade_ring", "viper_ring", "bandolier",
]
static var PIECES := {
	"cloth_hood": {"slot": "helm", "name": "Cloth Hood", "short": "Hood", "desc": "a deep hood of plain cloth: your light reaches 10% farther, and it hides your face (monsters notice you 8% later)",
		"light": 0.10, "notice": 0.08, "color": Color(0.46, 0.5, 0.42), "drop_weight": 3, "look": "hood"},
	"leather_cap": {"slot": "helm", "name": "Leather Cap", "short": "Cap", "desc": "a padded leather cap: +8 health",
		"health": 8.0, "color": Color(0.55, 0.38, 0.24), "drop_weight": 3, "look": "cap"},
	"iron_helm": {"slot": "helm", "name": "Iron Helm", "short": "Helm", "desc": "a plain iron helm: 6% damage taken off; heavy",
		"reduce": 0.06, "heavy": true, "color": Color(0.7, 0.72, 0.78), "drop_weight": 2, "look": "helm"},
	"grip_wraps": {"slot": "gloves", "name": "Grip Wraps", "short": "Wraps", "desc": "cloth wound tight round the hands: strike chains cost 6% less stamina, and your bare fists hit 15% harder",
		"chain": 0.06, "fist": 0.15, "color": Color(0.82, 0.76, 0.62), "drop_weight": 3},
	"leather_gloves": {"slot": "gloves", "name": "Leather Gloves", "short": "Gloves", "desc": "stiff leather gloves: strikes hit 4% harder, and a chain's finisher 15% harder",
		"strike": 0.04, "finisher": 0.15, "color": Color(0.5, 0.33, 0.2), "drop_weight": 3},
	"gauntlets": {"slot": "gloves", "name": "Gauntlets", "short": "Gauntlets", "desc": "steel gauntlets: strikes hit 7% harder, but the parry window is 5% shorter; heavy",
		"strike": 0.07, "parry": -0.05, "heavy": true, "color": Color(0.72, 0.74, 0.8), "drop_weight": 2},
	"padded_trousers": {"slot": "legs", "name": "Padded Trousers", "short": "Trousers", "desc": "quilted trousers: +10 max stamina",
		"stamina": 10.0, "color": Color(0.62, 0.55, 0.42), "drop_weight": 3},
	"leather_leggings": {"slot": "legs", "name": "Leather Leggings", "short": "Leggings", "desc": "supple leather leggings: rolls carry 5% farther and cost 5% less stamina",
		"roll_dist": 0.05, "roll_cost": 0.05, "color": Color(0.46, 0.31, 0.2), "drop_weight": 3},
	"chain_leggings": {"slot": "legs", "name": "Chain Leggings", "short": "Chain legs", "desc": "mail leggings: 5% damage taken off; heavy",
		"reduce": 0.05, "heavy": true, "color": Color(0.62, 0.65, 0.7), "drop_weight": 2},
	"soft_boots": {"slot": "boots", "name": "Soft Boots", "short": "Soft", "desc": "light boots of soft hide: you walk 4% faster, and quietly (monsters notice you 10% later)",
		"walk": 0.04, "notice": 0.10, "color": Color(0.5, 0.4, 0.3), "drop_weight": 3, "look": "soft"},
	"climbing_boots": {"slot": "boots", "name": "Climbing Boots", "short": "Climbing", "desc": "laced boots with grippy soles: jumps cost no stamina and carry 10% farther",
		"free_jump": true, "jump": 0.10, "color": Color(0.38, 0.3, 0.24), "drop_weight": 3, "look": "climbing"},
	"hobnail_boots": {"slot": "boots", "name": "Hobnail Boots", "short": "Hobnail", "desc": "iron-studded boots: light blows can't knock you back, but you walk 3% slower; heavy",
		"steady": true, "walk": -0.03, "heavy": true, "color": Color(0.3, 0.27, 0.26), "drop_weight": 2, "look": "hobnail"},
	"travel_cloak": {"slot": "cloak", "name": "Travel Cloak", "short": "Travel", "desc": "a thick, weathered cloak: poison wears off 25% sooner and burning floor hurts 25% less",
		"ailment": 0.25, "color": Color(0.5, 0.42, 0.3), "drop_weight": 3, "look": "travel"},
	"dusk_cloak": {"slot": "cloak", "name": "Dusk Cloak", "short": "Dusk", "desc": "a cloak the colour of dusk: monsters notice you 20% later",
		"notice": 0.2, "color": Color(0.32, 0.27, 0.42), "drop_weight": 2, "look": "dusk"},
	"satchel": {"slot": "backpack", "name": "Satchel", "short": "Satchel", "desc": "a roomy satchel: carry 4 of each item instead of 3",
		"stack": 1, "color": Color(0.56, 0.4, 0.24), "drop_weight": 2},
	"belt_pouch": {"slot": "backpack", "name": "Belt Pouch", "short": "Pouch", "desc": "a pouch on your belt: room for one more kind of item",
		"belt": 1, "color": Color(0.45, 0.33, 0.22), "drop_weight": 2},
	"bone_charm": {"kind": "stone", "slot": "amulet", "name": "Bone Charm", "short": "Bone", "desc": "a carved bone on a cord: +10 health",
		"health": 10.0, "rarity": "fine", "color": Color(0.88, 0.84, 0.72), "drop_weight": 1},
	"ember_charm": {"kind": "fire", "slot": "amulet", "name": "Ember Charm", "short": "Ember", "desc": "a warm red stone on a chain: spells hit 6% harder, and its glow carries your light 10% farther",
		"spell": 0.06, "light": 0.10, "rarity": "fine", "color": Color(0.9, 0.42, 0.25), "drop_weight": 1},
	"iron_band": {"kind": "iron", "slot": "ring", "name": "Iron Band", "short": "Iron", "desc": "a plain iron ring: stamina refills 5% faster, and starts refilling 25% sooner after you act",
		"regen": 0.05, "quick_breath": 0.25, "rarity": "fine", "color": Color(0.66, 0.68, 0.74), "drop_weight": 1},
	"garnet_ring": {"kind": "blade", "slot": "ring", "name": "Garnet Ring", "short": "Garnet", "desc": "a gold ring set with a garnet: strikes hit 4% harder, and each kill gives back 6 stamina",
		"strike": 0.04, "kill_sta": 6.0, "rarity": "fine", "color": Color(0.78, 0.22, 0.28), "drop_weight": 1},
	# Rare by nature: only found as Rare finds (or better).
	"tide_locket": {"kind": "water", "slot": "amulet", "name": "Tide Locket", "short": "Tide", "desc": "a locket full of sea water: marks fill 8% faster; +6 health",
		"fill": 0.08, "health": 6.0, "rarity": "rare", "color": Color(0.37, 0.72, 0.85), "drop_weight": 1},
	"pearl_ring": {"kind": "water", "slot": "ring", "name": "Pearl Ring", "short": "Pearl", "desc": "a ring set with a black pearl: each kill puts 2 essence into your emptiest mark",
		"kill_essence": 2.0, "rarity": "rare", "color": Color(0.86, 0.86, 0.92), "drop_weight": 1},
	"overdrawn_ring": {"kind": "fire", "slot": "ring", "name": "Ring of the Overdrawn", "short": "Overdrawn", "desc": "a scorched ring: your first overdraw each floor doesn't burn the body part",
		"overdraw_guard": 1.0, "rarity": "rare", "color": Color(0.95, 0.5, 0.3), "drop_weight": 1},
	"climbers_pack": {"slot": "backpack", "name": "Climber's Pack", "short": "Pack", "desc": "a well-worn pack with many pockets: one more kind of item on the belt, 4 of each, and room for 2 more spare pieces",
		"belt": 1, "stack": 1, "pack": 2, "rarity": "rare", "color": Color(0.4, 0.46, 0.3), "drop_weight": 1},
	# More choice for every slot.
	"feathered_cap": {"slot": "helm", "name": "Feathered Cap", "short": "Feathered", "desc": "a soft cap with a hawk's feather: bows and crossbows hit 6% harder",
		"ranged": 0.06, "color": Color(0.36, 0.52, 0.36), "drop_weight": 3, "look": "cap"},
	"miners_helm": {"slot": "helm", "name": "Miner's Helm", "short": "Miner's", "desc": "a brass helm with a candle on the brow: your light reaches 25% farther; 3% damage taken off",
		"light": 0.25, "reduce": 0.03, "color": Color(0.8, 0.62, 0.32), "drop_weight": 2, "look": "helm"},
	"archers_bracers": {"slot": "gloves", "name": "Archer's Bracers", "short": "Bracers", "desc": "laced leather bracers: bows draw and crossbows reload 10% faster",
		"draw": 0.10, "color": Color(0.6, 0.42, 0.26), "drop_weight": 3},
	"studded_gloves": {"slot": "gloves", "name": "Studded Gloves", "short": "Studded", "desc": "gloves set with iron studs: your bare fists hit 25% harder, and foes that strike you up close take 4",
		"fist": 0.25, "thorns": 4.0, "color": Color(0.42, 0.32, 0.28), "drop_weight": 2},
	"ranger_breeches": {"slot": "legs", "name": "Ranger's Breeches", "short": "Breeches", "desc": "soft green breeches: you walk 3% faster, and monsters notice you 10% later",
		"walk": 0.03, "notice": 0.10, "color": Color(0.38, 0.48, 0.32), "drop_weight": 3},
	"plated_greaves": {"slot": "legs", "name": "Plated Greaves", "short": "Greaves", "desc": "steel plates strapped over the shins: 7% damage taken off; heavy",
		"reduce": 0.07, "heavy": true, "color": Color(0.74, 0.76, 0.82), "drop_weight": 1},
	"wading_boots": {"slot": "boots", "name": "Wading Boots", "short": "Wading", "desc": "tall oiled boots: water doesn't slow you, and traps and burning floor hurt 10% less",
		"wade": true, "footing": 0.10, "color": Color(0.3, 0.44, 0.46), "drop_weight": 2},
	"feather_cape": {"slot": "cloak", "name": "Feather Cape", "short": "Feather", "desc": "a short cape of grey feathers: jumps carry 15% farther and rolls 4% farther",
		"jump": 0.15, "roll_dist": 0.04, "color": Color(0.64, 0.56, 0.48), "drop_weight": 2},
	"herb_pouch": {"slot": "backpack", "name": "Herb Pouch", "short": "Herbs", "desc": "a pouch of dried healing herbs: healing items heal 25% more",
		"item_heal": 0.25, "color": Color(0.52, 0.58, 0.32), "drop_weight": 2},
	"wolf_tooth": {"kind": "blade", "slot": "amulet", "name": "Wolf-Tooth Necklace", "short": "Wolf-Tooth", "desc": "a wolf's fang on a leather thong: ripostes and backstabs hit 12% harder",
		"riposte": 0.12, "rarity": "fine", "color": Color(0.93, 0.89, 0.78), "drop_weight": 1},
	"sunstone_pendant": {"kind": "fire", "slot": "amulet", "name": "Sunstone Pendant", "short": "Sunstone", "desc": "a stone that keeps the day's light: your light reaches 20% farther; spells hit 3% harder",
		"light": 0.2, "spell": 0.03, "rarity": "fine", "color": Color(1.0, 0.7, 0.28), "drop_weight": 1},
	"silver_ring": {"kind": "water", "slot": "ring", "name": "Silver Ring", "short": "Silver", "desc": "a cool silver band: the parry window is 6% longer, and a perfect parry heals you 3",
		"parry": 0.06, "parry_heal": 3.0, "rarity": "fine", "color": Color(0.84, 0.88, 0.94), "drop_weight": 1},
	"jade_ring": {"kind": "iron", "slot": "ring", "name": "Jade Ring", "short": "Jade", "desc": "a ring carved from green jade: +12 max stamina",
		"stamina": 12.0, "rarity": "fine", "color": Color(0.34, 0.76, 0.52), "drop_weight": 1},
	"viper_ring": {"kind": "stone", "slot": "ring", "name": "Viper Ring", "short": "Viper", "desc": "a coiled serpent with emerald eyes: hits have a 12% chance to poison the foe",
		"venom_chance": 0.12, "rarity": "rare", "color": Color(0.44, 0.72, 0.32), "drop_weight": 1},
	"bandolier": {"slot": "backpack", "name": "Bandolier", "short": "Bandolier", "desc": "a crossed belt of loops and pockets: two more kinds of item on the belt",
		"belt": 2, "rarity": "rare", "color": Color(0.46, 0.3, 0.2), "drop_weight": 1},
}
## The numbers effects() adds up, and how the inventory names them:
## [key, label, as a share (%) or a count, higher is better, (shown as a
## cut: "-15%")].
const EFFECT_ROWS := [
	["health", "Health", false, true], ["stamina", "Stamina", false, true], ["reduce", "Protection", true, true],
	["strike", "Strikes", true, true], ["chain", "Chain cost", true, true], ["parry", "Parry window", true, true],
	["roll_dist", "Roll reach", true, true], ["walk", "Walk", true, true], ["light", "Light", true, true],
	["regen", "Stamina back", true, true], ["spell", "Spells", true, true], ["notice", "Noticed later", true, true],
	["ailment", "Poison and fire", true, true], ["stack", "Items each", false, true], ["belt", "Belt kinds", false, true],
	["jump", "Jump reach", true, true], ["footing", "Trap harm", true, true, true], ["riposte", "Ripostes", true, true],
	["thorns", "Thorns", false, true], ["roll_cost", "Roll stamina", true, true, true], ["ranged", "Bows", true, true],
	["embers", "Burn chance", true, true], ["fill", "Marks fill", true, true], ["kill_essence", "Essence a kill", false, true],
	["pack", "Pack spaces", false, true], ["kill_heal", "Heal a kill", false, true], ["draw", "Draw and reload", true, true],
	["venom_chance", "Poison chance", true, true], ["item_heal", "Item healing", true, true], ["parry_sta", "Stamina a parry", false, true],
	["finisher", "Finishers", true, true], ["fist", "Fists", true, true], ["kill_sta", "Stamina a kill", false, true],
	["quick_breath", "Stamina wait", true, true, true], ["parry_heal", "Heal a perfect parry", false, true],
]
## Only these numbers halve on a badly worn piece (the rest are penalties or switches).
const BONUS_KEYS := ["health", "stamina", "reduce", "strike", "chain", "roll_dist", "light", "regen", "spell", "notice", "ailment", "jump",
	"ranged", "draw", "thorns", "footing", "finisher", "fist", "roll_cost", "kill_sta", "quick_breath", "parry_heal"]

## How common each weapon is as a drop (fists are always carried).
static var WEAPON_DROP_WEIGHT := {
	"dagger": 4, "sword": 3, "axe": 4, "mace": 3, "spear": 4, "greatsword": 2, "war_hammer": 2, "cane": 3, "sword_cane": 2,
	"shortbow": 3, "longbow": 2, "crossbow": 2, "flintlock": 2, "revolver": 2,
}

## Monsters favour gear that suits them: these are four times as likely.
const FAVOUR_MULT := 4
const FAVOUR := {
	"knight": ["chain", "plate", "sword", "mace", "greatsword", "iron_helm", "gauntlets", "plated_greaves"],
	"archer": ["shortbow", "longbow", "crossbow", "flintlock", "leather", "leather_cap", "feathered_cap", "archers_bracers"],
	"smith": ["war_hammer", "mace", "chain", "plate", "gauntlets", "hobnail_boots", "revolver", "flintlock"],
	"shellback": ["mace", "chain", "chain_leggings"],
	"ram": ["war_hammer", "axe", "hobnail_boots"],
	"thornhound": ["dagger", "sword_cane", "leather", "leather_gloves", "studded_gloves"],
	"mongrel": ["axe", "spear", "cane", "leather", "leather_leggings", "wolf_tooth"],
	"scorpling": ["dagger", "padded", "travel_cloak", "viper_ring"],
	"thunderling": ["spear", "chain", "soft_boots"],
	"lurker": ["spear", "padded", "climbing_boots", "wading_boots"],
	"slime": ["padded", "dagger", "padded_trousers"],
	"bat": ["dagger", "shortbow", "dusk_cloak", "feather_cape"],
	"cinder": ["shortbow", "crossbow", "grip_wraps"],
	"wisp": ["shortbow", "padded", "cloth_hood", "miners_helm"],
	"bloomcap": ["padded", "leather", "travel_cloak", "herb_pouch", "ranger_breeches"],
}


# --- records ------------------------------------------------------------------------

## A new piece of gear: `base` is its id. Rings and amulets are Fine (some
## pieces are Rare by nature: natural_rarity); the rest Common unless
## `rarity` says otherwise. `named` makes it a named piece (NAMED). Commons
## without traits start in full repair; nothing else ever wears.
static func make(base: String, rarity := "", traits: Array = [], rank := 0, named := "", rune := "") -> Dictionary:
	if not is_gear(base):
		return {}
	var r := rarity if RARITIES.has(rarity) else natural_rarity(base)
	var keep := unique_traits(base, traits)
	var g := {"base": base, "rarity": r, "traits": keep, "rank": clampi(rank, 0, RANK_CAP)}
	if NAMED.has(named) and String(NAMED[named]["base"]) == base:
		g["named"] = named
	if LASTING_RUNES.has(rune):
		g["rune"] = rune
	if bool(RARITIES[r]["wears"]) and keep.is_empty() and not g.has("named"):
		g["wear"] = 1.0
	return g


## A piece's traits with no trait twice: known traits only, and a repeat
## replaced by another trait that fits the slot and isn't on the piece (the
## same one every time, so an old save's piece cleans the same way on every
## load), or dropped if none is left.
static func unique_traits(base, traits: Array) -> Array:
	var given: Array = traits.map(func(t): return String(t)).filter(func(t): return TRAITS.has(t))
	var out: Array = []
	for t in given:
		if not (t in out):
			out.append(t)
			continue
		var pool: Array = traits_for(trait_slot(base)).filter(func(o): return not (o in out) and not (o in given))
		if not pool.is_empty():
			out.append(pool[posmod(hash(base_id(base) + str(out.size())), pool.size())])
	return out


## A record from anything: a record (filled in where keys are missing), an
## old plain id like "axe" (old saves), or a short code (code()). "" or
## something unknown gives {} (nothing).
static func rec(g) -> Dictionary:
	if g is Dictionary:
		if g.is_empty() or not is_gear(String(g.get("base", ""))):
			return {}
		var out := make(String(g["base"]), String(g.get("rarity", "")), g.get("traits", []), int(g.get("rank", 0)), String(g.get("named", "")), String(g.get("rune", "")))
		if out.has("wear"):
			out["wear"] = clampf(float(g.get("wear", 1.0)), 0.0, 1.0)
		return out
	if g is String or g is StringName:
		var s := String(g)
		if ";" in s:
			var p := s.split(";")
			var traits: Array = []
			if p.size() > 3 and p[3] != "":
				traits = Array(p[3].split(","))
			return make(p[0], p[1] if p.size() > 1 else "", traits, int(p[2]) if p.size() > 2 else 0, p[4] if p.size() > 4 else "", p[5] if p.size() > 5 else "")
		return make(s)
	return {}


## A piece's id ("" for nothing). Takes a record or a plain id.
static func base_id(g) -> String:
	if g is Dictionary:
		return String(g.get("base", ""))
	if g is String or g is StringName:
		var s := String(g)
		return s.get_slice(";", 0)
	return ""


## A named piece's id (NAMED), or "".
static func named_id(g) -> String:
	if g is Dictionary:
		return String(g.get("named", ""))
	if (g is String or g is StringName) and String(g).get_slice_count(";") > 4:
		return String(g).get_slice(";", 4)
	return ""


## The rarity a piece has at the least: Common, Fine for rings and amulets,
## Rare for the pieces that are Rare by nature (the Tide Locket and the like).
static func natural_rarity(base) -> String:
	return String(PIECES.get(base_id(base), {}).get("rarity", "common"))


static func rarity_rank(r: String) -> int:
	return maxi(0, RARITY_ORDER.find(r))


## A short text for a fresh piece, for card choices ("gear:" + code): a plain
## Common is just its id ("axe"); anything more is
## "base;rarity;rank;traits;named;rune".
static func code(g) -> String:
	var r := rec(g)
	if r.is_empty():
		return ""
	if r["rarity"] == natural_rarity(r) and r["rank"] == 0 and r["traits"].is_empty() and not r.has("named") and not r.has("rune"):
		return r["base"]
	var c := "%s;%s;%d;%s" % [r["base"], r["rarity"], r["rank"], ",".join(r["traits"])]
	if r.has("rune"):
		return c + ";" + String(r.get("named", "")) + ";" + String(r["rune"])
	return c + (";" + String(r["named"]) if r.has("named") else "")


## The same piece (ignoring wear).
static func same(a, b) -> bool:
	var ra := rec(a)
	var rb := rec(b)
	if ra.is_empty() or rb.is_empty():
		return ra.is_empty() and rb.is_empty()
	return ra["base"] == rb["base"] and ra["rarity"] == rb["rarity"] and ra["rank"] == rb["rank"] and ra["traits"] == rb["traits"] \
		and String(ra.get("named", "")) == String(rb.get("named", "")) and String(ra.get("rune", "")) == String(rb.get("rune", ""))


# --- rarities and traits ---------------------------------------------------------------

## The odds row for a floor, `higher` rows up (vaults, caches and camps roll one higher).
static func rarity_odds(floor_num: int, higher := 0) -> Dictionary:
	var i := RARITY_ODDS.size() - 1
	for k in RARITY_ODDS.size():
		if floor_num <= int(RARITY_ODDS[k]["to"]):
			i = k
			break
	return RARITY_ODDS[mini(i + higher, RARITY_ODDS.size() - 1)]["odds"]


## A rarity for a find on this floor (at least `at_least`). Storied only
## from STORIED_FROM up (below, it counts as Rare).
static func roll_rarity(floor_num: int, higher := 0, at_least := "common") -> String:
	var odds := rarity_odds(floor_num, higher)
	var total := 0
	for r in odds:
		total += int(odds[r])
	var roll := randi() % maxi(total, 1)
	var got := "common"
	for r in RARITY_ORDER:
		if not odds.has(r):
			continue
		roll -= int(odds[r])
		if roll < 0:
			got = r
			break
	if got == "storied" and floor_num < STORIED_FROM:
		got = "rare"
	if rarity_rank(at_least) > rarity_rank(got):
		got = at_least
	return got


## The slot name traits use for a piece ("ring" for either ring, "armor" for the chest).
static func trait_slot(base) -> String:
	return slot_of(base)


## The traits that can roll on a slot.
static func traits_for(slot: String) -> Array:
	return TRAIT_ORDER.filter(func(t): return slot in TRAITS[t]["slots"])


## How many traits a fresh piece of this rarity carries: its rarity's count,
## less what its natural rarity already gives (a Fine ring has none; a Rare
## one has one). Named pieces carry their rarity's "named_traits" besides
## their own rule (one; four on a Regarded piece).
static func trait_count(base, r: String, named := "") -> int:
	if named != "":
		if not bool(NAMED.get(named, {}).get("enchanted", true)):
			return 0  # (a relic that isn't enchanted carries no traits)
		return mini(int(RARITIES.get(r, {}).get("named_traits", 1)), traits_for(trait_slot(base)).size())
	return maxi(0, int(RARITIES[r]["traits"]) - int(RARITIES[natural_rarity(base)]["traits"]))


## Traits for a fresh piece: different ones, each fitting its slot.
static func roll_traits(base, r: String, named := "") -> Array:
	var pool := traits_for(trait_slot(base))
	var out: Array = []
	for i in mini(trait_count(base, r, named), pool.size()):
		var t: String = pool[randi() % pool.size()]
		pool.erase(t)
		out.append(t)
	return out


## A trait's strength on a piece of this rarity.
static func trait_value(t: String, r: String) -> float:
	var d: Dictionary = TRAITS.get(t, {})
	if d.is_empty():
		return 0.0
	return float(d["fine"] if rarity_rank(r) <= 1 else d["rare"])


## A trait's strength on a piece tempered to `rank` (each rank adds
## RANK_TRAIT of its base).
static func trait_amount(t: String, r: String, rank := 0) -> float:
	return trait_value(t, r) * (1.0 + RANK_TRAIT * clampi(rank, 0, RANK_CAP))


## A number as a card shows it: "5%" for a share, "6" for a count.
static func amount_text(v: float) -> String:
	if v < 1.0:
		var pct := v * 100.0
		return ("%d%%" % int(round(pct))) if absf(pct - round(pct)) < 0.05 or pct >= 10.0 else ("%.1f%%" % pct)
	return "%d" % int(round(v)) if absf(v - round(v)) < 0.05 else "%.1f" % v


## A trait's line for a card: "of Edges: strikes hit 5% harder".
static func trait_text(t: String, r: String, rank := 0) -> String:
	var d: Dictionary = TRAITS[t]
	return "%s: %s" % [d["name"], String(d["desc"]) % amount_text(trait_amount(t, r, rank))]


## A lasting rune's line for a card: "Rune of Sharpness: strikes hit 10% harder".
static func rune_text(rune: String) -> String:
	var d: Dictionary = LASTING_RUNES.get(rune, {})
	if d.is_empty():
		return ""
	return "%s: %s" % [d["name"], String(d["desc"]) % amount_text(float(d["value"]))]


## The named pieces that can be found: Storied ones anywhere (from floor
## STORIED_FROM), tower pieces only in their own tower.
static func named_pool(r: String, tower_id: String, exclude: Array = []) -> Array:
	var skip: Array = exclude.map(func(e): return named_id(e)).filter(func(n): return n != "")
	return NAMED_ORDER.filter(func(n): return NAMED[n]["rarity"] == r and not (n in skip) \
		and (r != "rare" or String(NAMED[n].get("tower", "")) == tower_id))


## The Regarded piece a tower's beast leaves (a NAMED id), or "".
static func beast_piece(tower_id: String) -> String:
	for n in NAMED_ORDER:
		if String(NAMED[n].get("beast", "")) == tower_id:
			return n
	return ""


## Whether a slain beast leaves its piece this time: `slain` is how many
## times it has fallen to you, this time included (REGARDED_DROP).
static func beast_drops(slain: int) -> bool:
	return randf() < float(REGARDED_DROP["first" if slain <= 1 else "again"])


## A named piece as a record (its rarity, and its rolled traits).
static func make_named(n: String) -> Dictionary:
	var d: Dictionary = NAMED[n]
	return make(String(d["base"]), String(d["rarity"]), roll_traits(d["base"], d["rarity"], n), 0, n)


## A fresh find: a whole record with its rarity (by floor) and traits. A
## Storied roll is one of the Storied pieces; a Rare one in a tower with
## its own pieces is sometimes one of those. `higher` rolls rows higher
## (vaults, caches, camps); `at_least` sets a floor on the rarity.
static func roll_gear(kind := "", exclude: Array = [], trinkets := true, floor_num := 1, tower_id := "", higher := 0, at_least := "common") -> Dictionary:
	var r := roll_rarity(floor_num, higher, at_least)
	if r == "storied":
		var pool := named_pool("storied", tower_id, exclude)
		if not pool.is_empty():
			return make_named(pool[randi() % pool.size()])
		r = "rare"
	if r == "rare" and randf() < TOWER_PIECE_CHANCE:
		var tpool := named_pool("rare", tower_id, exclude)
		if not tpool.is_empty():
			return make_named(tpool[randi() % tpool.size()])
	var base := random_gear(kind, exclude, trinkets, r)
	# A slot no trait fits (a backpack) can't be finer than it is by nature:
	# a fine roll picks another piece, a few tries over.
	for i in 8:
		if not traits_for(trait_slot(base)).is_empty() or rarity_rank(natural_rarity(base)) >= rarity_rank(r):
			break
		base = random_gear(kind, exclude, trinkets, r)
	# Rings and amulets are Fine at the least.
	if rarity_rank(natural_rarity(base)) > rarity_rank(r):
		r = natural_rarity(base)
	if traits_for(trait_slot(base)).is_empty():
		r = natural_rarity(base)
	return make(base, r, roll_traits(base, r))


## Is this find rare enough for the HUD's notice?
static func noticed(g) -> bool:
	return rarity_rank(rarity(g)) >= rarity_rank(NOTICE_FROM)


static func is_armor(id) -> bool:
	return ARMOR.has(base_id(id))


static func is_piece(id) -> bool:
	return PIECES.has(base_id(id))


static func is_gear(id) -> bool:
	var b := base_id(id)
	return (Weapons.WEAPONS.has(b) and b != "fists") or (ARMOR.has(b) and b != "") or PIECES.has(b)


## Which slot a piece goes in: "melee", "ranged", "armor", "helm", "gloves",
## "legs", "boots", "cloak", "amulet", "ring" (either ring slot) or
## "backpack" (or "fists").
static func slot_of(id) -> String:
	var b := base_id(id)
	if Weapons.WEAPONS.has(b):
		return Weapons.WEAPONS[b]["slot"]
	if PIECES.has(b):
		return PIECES[b]["slot"]
	return "armor"


## The carried slots a piece can go in (two for a ring).
static func carry_slots(slot: String) -> Array:
	if slot == "ring":
		return ["ring1", "ring2"]
	return [slot]


## Is this one of the new worn slots (not a weapon or the chest)?
static func is_new_slot(id) -> bool:
	return PIECES.has(base_id(id))


static func info(id) -> Dictionary:
	var b := base_id(id)
	if Weapons.WEAPONS.has(b):
		return Weapons.WEAPONS[b]
	if PIECES.has(b):
		return PIECES[b]
	return ARMOR.get(b, {})


## A piece's name: its own for a named piece; else its rarity (unless that's
## its natural one), the base's name and its first trait, kept short for a
## phone: "Fine Leather Gloves of Edges", "Rare Iron Helm of Vigor".
static func display(id) -> String:
	var d := info(id)
	if d.is_empty():
		return "nothing"
	var g = id
	if (g is String or g is StringName) and ";" in String(g):
		g = rec(g)
	if not (g is Dictionary):
		return String(d.get("name", "nothing"))
	var n := named_id(g)
	if NAMED.has(n):
		return String(NAMED[n]["name"]) + rank_tag(g)
	var r := String(g.get("rarity", "common"))
	var name := String(d.get("name", "nothing"))
	if r != "common" and r != natural_rarity(g) and RARITIES.has(r):
		name = String(RARITIES[r]["name"]) + " " + name
	var tr: Array = g.get("traits", [])
	if not tr.is_empty() and TRAITS.has(String(tr[0])):
		name += " " + String(TRAITS[tr[0]]["name"])
	return name + rank_tag(g)


## " +2" for a tempered piece, "" otherwise.
static func rank_tag(g) -> String:
	var k := int(g.get("rank", 0)) if g is Dictionary else 0
	return " +%d" % k if k > 0 else ""


## What a piece does, in words (a named piece's own line, else its base's).
static func desc(id) -> String:
	var n := named_id(id)
	if NAMED.has(n):
		return String(NAMED[n]["desc"])
	return String(info(id).get("desc", ""))


static func short(id) -> String:
	var n := named_id(id)
	if NAMED.has(n) and NAMED[n].has("short"):
		return String(NAMED[n]["short"])  # (a named piece's own short name)
	return info(id).get("short", "-")


## Chest numbers (ARMOR): a named suit's own, else its base's.
static func armor(id) -> Dictionary:
	var a: Dictionary = ARMOR.get(base_id(id), ARMOR[""])
	var n := named_id(id)
	if NAMED.has(n) and NAMED[n].has("armor"):
		a = a.duplicate()
		a.merge(NAMED[n]["armor"], true)
	return a


static func rarity(g) -> String:
	var r := rec(g)
	return String(r.get("rarity", "common"))


static func rarity_name(g) -> String:
	return String(RARITIES[rarity(g)]["name"])


## The rarity's colour (labels, slot edges, cards and glints).
static func rarity_color(g) -> Color:
	return RARITIES.get(rarity(g), RARITIES["common"])["color"]


## A colour for gear: armor and pieces have their own (a named piece may have
## its own too); weapons are steel, bows wood.
static func color(id) -> Color:
	var n := named_id(id)
	if NAMED.has(n) and NAMED[n].has("color"):
		return NAMED[n]["color"]
	var b := base_id(id)
	if ARMOR.has(b):
		return ARMOR[b]["color"]
	if PIECES.has(b):
		return PIECES[b]["color"]
	if Weapons.WEAPONS.has(b) and Weapons.WEAPONS[b].has("color"):
		return Weapons.WEAPONS[b]["color"]  # (canes' and pistols' dark wood)
	if Weapons.is_ranged(b):
		return Color(0.85, 0.66, 0.42)
	return Color(0.82, 0.85, 0.92)


static func is_heavy(id) -> bool:
	if NAMED.has(named_id(id)) and PIECES.has(base_id(id)):
		return false  # (a named piece's own numbers replace its base's)
	return bool(PIECES.get(base_id(id), {}).get("heavy", false))


# --- wear ---------------------------------------------------------------------------

## Does this piece wear down (Common pieces only)?
static func wears(g) -> bool:
	return g is Dictionary and g.has("wear") and bool(RARITIES.get(String(g.get("rarity", "common")), {}).get("wears", false))


## Its condition, 0 to 1 (1 for pieces that never wear).
static func condition(g) -> float:
	return clampf(float(g.get("wear", 1.0)), 0.0, 1.0) if wears(g) else 1.0


static func is_worn(g) -> bool:
	return wears(g) and condition(g) <= WORN


## How much of its bonus a piece gives: half when badly worn.
static func factor(g) -> float:
	return 0.5 if is_worn(g) else 1.0


## A weapon's damage multiplier from wear.
static func weapon_factor(g) -> float:
	return WORN_WEAPON if is_worn(g) else 1.0


## A weapon's damage multiplier: its rarity's boost and its tempering, less any wear.
static func weapon_power(g) -> float:
	return weapon_factor(g) * weapon_boost(g)


## How much harder a weapon hits for its rarity and its rank (1.0: no harder).
static func weapon_boost(g) -> float:
	var k := int(g.get("rank", 0)) if g is Dictionary else 0
	return (1.0 + float(RARITIES.get(rarity(g), RARITIES["common"])["boost"])) * (1.0 + RANK_WEAPON * clampi(k, 0, RANK_CAP))


# --- what a piece does --------------------------------------------------------------

## A piece's numbers (PIECES keys, and its traits'), with a badly worn
## piece's bonuses halved. A named worn piece has its own numbers instead
## of its base's; a named chest piece adds its rule. Weapons give only their
## traits here (their own rules are weapon_rules(): they work while in hand).
static func effects(g) -> Dictionary:
	var b := base_id(g)
	var out := {}
	var n := named_id(g)
	var d: Dictionary = PIECES.get(b, {})
	if NAMED.has(n) and not Weapons.WEAPONS.has(b):
		d = NAMED[n].get("fx", {})
	if not d.is_empty():
		var f := factor(g) if g is Dictionary else 1.0
		for k in d:
			if k in ["slot", "name", "short", "desc", "color", "drop_weight", "look", "rarity", "kind", "history", "enchanted"]:
				continue
			var v = d[k]
			if (v is float or v is int) and k in BONUS_KEYS:
				v = v * f
			out[k] = v
	if g is Dictionary:
		var r := String(g.get("rarity", "common"))
		var k := int(g.get("rank", 0))
		for t in g.get("traits", []):
			if TRAITS.has(String(t)):
				var key := String(TRAITS[t]["key"])
				out[key] = float(out.get(key, 0.0)) + trait_amount(t, r, k)
		# A lasting rune (the bench) adds to its number like a trait.
		var rn: Dictionary = LASTING_RUNES.get(String(g.get("rune", "")), {})
		if not rn.is_empty():
			var key := String(rn["key"])
			out[key] = float(out.get(key, 0.0)) + float(rn["value"])
	return out


## Ordinary or enchanted. A plain Common piece is ordinary: no traits, only
## its own use. Fine and Rare pieces are enchanted (their traits), and so
## are rings and amulets by nature (PIECES "kind"). Named pieces are relics,
## enchanted in their own essence unless NAMED says "enchanted": false.
static func enchanted(g) -> bool:
	var r := rec(g)
	if r.is_empty():
		return false
	var n := named_id(r)
	if NAMED.has(n):
		return bool(NAMED[n].get("enchanted", true))
	if not r.get("traits", []).is_empty():
		return true
	return PIECES.get(base_id(r), {}).has("kind")


## The essence of a piece's enchantment ("" for an ordinary piece): a
## relic's own, else its first trait's, else its nature's (a ring's).
static func enchant_kind(g) -> String:
	if not enchanted(g):
		return ""
	var r := rec(g)
	var n := named_id(r)
	if NAMED.has(n):
		return String(NAMED[n]["kind"])
	for t in r.get("traits", []):
		if TRAITS.has(String(t)):
			return String(TRAITS[t]["kind"])
	return String(PIECES.get(base_id(r), {}).get("kind", ""))


## The essence an enchanted pistol fires (weapons.gd ESSENCE_SHOT), or ""
## for anything else: an ordinary pistol fires lead and reloads.
static func shot_kind(g) -> String:
	if not Weapons.is_gun(base_id(g)):
		return ""
	return enchant_kind(g)


## A relic's history (NAMED "history", for the owner to write; "" while blank).
static func history(g) -> String:
	var n := named_id(g)
	if NAMED.has(n):
		return String(NAMED[n].get("history", "")).strip_edges()
	return ""


## A weapon's own rules (a named weapon's NAMED fx), for while it's in hand.
static func weapon_rules(g) -> Dictionary:
	var n := named_id(g)
	if NAMED.has(n) and Weapons.WEAPONS.has(base_id(g)):
		return NAMED[n].get("fx", {})
	return {}


## Everything you wear, added up: {key: total} (see PIECES), plus "heavy"
## (how many heavy pieces). The chest's protection and weight aren't in it
## (see ARMOR). The numbers in CAPS stop at their caps unless `raw`.
static func total_effects(gear: Dictionary, raw := false) -> Dictionary:
	var t := {}
	for slot in gear:
		var fx := effects(gear[slot])
		for k in fx:
			var v = fx[k]
			if v is bool:
				if k == "heavy":
					t["heavy"] = int(t.get("heavy", 0)) + (1 if v else 0)
				else:
					t[k] = bool(t.get(k, false)) or v
			else:
				t[k] = float(t.get(k, 0.0)) + float(v)
	if not raw:
		for k in CAPS:
			if t.has(k):
				t[k] = minf(float(t[k]), float(CAPS[k]))
	return t


## The numbers (CAPS keys) your gear has pushed to their caps.
static func capped_keys(gear: Dictionary) -> Array:
	var t := total_effects(gear, true)
	return CAPS.keys().filter(func(k): return float(t.get(k, 0.0)) >= float(CAPS[k]) - 0.0001)


## Protection from everything you wear: the chest's (halved if badly worn)
## plus the pieces' and `extra` (a Stoneskin Draught), capped at PROTECTION_CAP.
static func protection(gear: Dictionary, fx := {}, extra := 0.0) -> float:
	var chest = gear.get("armor", "")
	var r := float(armor(chest)["reduce"]) * (factor(chest) if chest is Dictionary else 1.0)
	if fx.is_empty():
		fx = total_effects(gear)
	return minf(PROTECTION_CAP, r + float(fx.get("reduce", 0.0)) + extra)


## A number for the inventory: "+8", "+6%", "-5%".
static func _fmt(v: float, share: bool) -> String:
	if share:
		return "%s%d%%" % ["+" if v >= 0.0 else "-", int(round(absf(v) * 100.0))]
	return "%s%d" % ["+" if v >= 0.0 else "-", int(round(absf(v)))]


## Rows for a piece's numbers (effects()): [label, text, value, higher is
## better, key].
static func _fx_rows(fx: Dictionary) -> Array:
	var rows: Array = []
	for e in EFFECT_ROWS:
		if fx.has(e[0]) and not (fx[e[0]] is bool) and absf(float(fx[e[0]])) > 0.0001:
			var v := float(fx[e[0]])
			rows.append([e[1], _fmt(-v if e.size() > 4 else v, e[2]), v, e[3], e[0]])
	if fx.get("free_jump", false):
		rows.append(["Jumps", "free", 1.0, true, "free_jump"])
	if fx.get("steady", false):
		rows.append(["Knockback", "light blows: none", 1.0, true, "steady"])
	if fx.get("heavy", false):
		rows.append(["Roll cost", "+%d%%" % int(round(HEAVY_ROLL * 100.0)), HEAVY_ROLL, false, "heavy"])
	return rows


## Key numbers for comparing: [label, shown text, value, higher is better,
## key ("" for a weapon's or armor's own numbers)]. A weapon better than
## Common hits harder (RARITIES boost); traits add their rows.
static func stats(id) -> Array:
	var b := base_id(id)
	var rows: Array = []
	if Weapons.WEAPONS.has(b):
		for row in Weapons.stats(b):
			rows.append(row + [""])
		var boost := weapon_boost(id) - 1.0
		if not rows.is_empty() and (boost > 0.0 or (id is Dictionary and is_worn(id))):
			var d: Array = rows[0].duplicate()
			if boost > 0.0:
				d[1] = String(d[1]) + " (+%d%%)" % int(round(boost * 100.0))
				d[2] = float(d[2]) * (1.0 + boost)
			if id is Dictionary and is_worn(id):
				d[1] = String(d[1]) + " (worn)"
				d[2] = float(d[2]) * WORN_WEAPON
			rows[0] = d
		rows.append_array(_fx_rows(effects(id)))
	elif PIECES.has(b):
		rows = _fx_rows(effects(id))
	else:
		var a := armor(id)
		var red := float(a["reduce"]) * (factor(id) if id is Dictionary else 1.0)
		rows = [
			["Protection", "%d%%" % int(round(red * 100.0)), red, true, ""],
			["Roll cost", "+%d%%" % int(round((a["roll_cost"] - 1.0) * 100.0)), a["roll_cost"], false, ""],
			["Roll reach", "-%d%%" % int(round((1.0 - a["roll_dist"]) * 100.0)), a["roll_dist"], true, ""],
			["Stamina back", "-%d%%" % int(round((1.0 - a["regen"]) * 100.0)), a["regen"], true, ""],
			["Walk", "-%d%%" % int(round((1.0 - a["walk"]) * 100.0)), a["walk"], true, ""],
		]
		rows.append_array(_fx_rows(effects(id)))
	if wears(id):
		var c := condition(id)
		rows.append(["Condition", "%d%%" % int(round(c * 100.0)), c, true, ""])
	return rows


## One line of key stats, for the menus and the dev tools.
static func summary(id) -> String:
	var parts: Array = []
	for s in stats(id):
		parts.append("%s %s" % [String(s[0]).to_lower(), s[1]])
	return "  ·  ".join(parts)


## `a` set against `b` (the piece you wear there, or nothing): one row per
## number either has, [label, a's text, b's text, +1 better / -1 worse / 0,
## key], at most `most` rows. Numbers the other lacks count as 0 (or "-").
static func compare(a, b, most := 6) -> Array:
	var ra := stats(a)
	var rb := stats(b) if is_gear(b) or (slot_of(a) == "armor" and base_id(b) == "") else []
	var out: Array = []
	var seen := {}
	for row in ra:
		seen[row[0]] = true
		var other: Array = []
		for o in rb:
			if o[0] == row[0]:
				other = o
		var sign := 0
		var mine := float(row[2])
		var theirs := float(other[2]) if not other.is_empty() else 0.0
		if not other.is_empty() or String(row[4]) != "":
			var diff := mine - theirs
			if absf(diff) > 0.0001:
				sign = 1 if (diff > 0.0) == bool(row[3]) else -1
		out.append([row[0], row[1], String(other[1]) if not other.is_empty() else "-", sign, row[4]])
	for o in rb:
		if seen.has(o[0]):
			continue
		# Something the other piece gives that this one doesn't: a loss.
		var s := -1 if bool(o[3]) == (float(o[2]) > 0.0) else 1
		out.append([o[0], "-", o[1], s, o[4]])
	return out.slice(0, most)


## For weapons, one plain line on how `a` plays against `b`: "faster, hits
## harder, longer reach" (the old game's playsLike), and the traits it adds
## or loses ("adds Embers"). "" for anything else, or the very same piece.
static func plays_like(a, b) -> String:
	var ia := base_id(a)
	var ib := base_id(b)
	if not (Weapons.WEAPONS.has(ia) and Weapons.WEAPONS.has(ib)) or same(a, b):
		return ""
	var sa := stats(a)
	var sb := stats(b)
	var bits: Array = []
	var ka := String(Weapons.WEAPONS[ia]["kind"])
	var kb := String(Weapons.WEAPONS[ib]["kind"])
	if ka != kb:
		bits.append({"bow": "a bow you draw", "crossbow": "fires at once, then reloads", "melee": "a melee weapon", "gun": "a pistol: shoot, then reload"}[ka])
	if shot_kind(a) != shot_kind(b) and shot_kind(a) != "":
		bits.append(String(Weapons.essence_shot(shot_kind(a))["name"]).to_lower())
	var words := {
		"Damage": ["hits harder", "hits softer"], "Reach": ["longer reach", "shorter reach"], "Range": ["flies farther", "shorter range"],
		"Stamina": ["costs less stamina", "costs more stamina"], "Speed": ["faster", "slower"], "Draw": ["draws faster", "draws slower"],
		"Reload": ["reloads faster", "reloads slower"], "Shots": ["more shots", "fewer shots"],
	}
	var near := 0.06 if ia != ib else 0.03  # (the same weapon: a rarity's few percent count)
	for i in mini(sa.size(), sb.size()):
		var label: String = sa[i][0]
		if label != sb[i][0] or not words.has(label):
			continue
		var x := float(sa[i][2])
		var y := float(sb[i][2])
		if absf(x - y) <= maxf(absf(y) * near, 0.001):
			continue
		var better := (x > y) == bool(sa[i][3])
		bits.append(words[label][0 if better else 1])
	var ca := String(Weapons.WEAPONS[ia].get("class", ""))
	var cb := String(Weapons.WEAPONS[ib].get("class", ""))
	if ca != cb and ka == "melee" and kb == "melee":
		bits.append("%s, not %s" % [ca, cb])
	# Traits and named rules: what this one brings, and what yours had.
	var ta: Array = rec(a).get("traits", [])
	var tb: Array = rec(b).get("traits", [])
	if NAMED.has(named_id(a)) and named_id(a) != named_id(b):
		bits.append("its own rule")
	for t in ta:
		if not (t in tb):
			bits.append("adds %s" % TRAITS[t]["short"])
	for t in tb:
		if not (t in ta):
			bits.append("loses %s" % TRAITS[t]["short"])
	if bits.is_empty():
		return TEXT["plays_same"]
	return TEXT["plays_like"] % ", ".join(bits.slice(0, 5))


## Plain lines for a card: what it does, its rarity (and name, for a named
## piece) and its condition, then a warning when it's badly worn. Traits
## come from trait_lines().
static func describe(g) -> Array:
	var lines: Array = []
	var d := info(g)
	if d.is_empty():
		return lines
	var what := desc(g)
	lines.append(what.left(1).to_upper() + what.substr(1) + ".")
	var r := rec(g)
	var tags: Array = [rarity_name(r)]
	if not enchanted(r) and not NAMED.has(named_id(r)):
		tags.append(TEXT["ordinary"])
	if NAMED.has(named_id(r)):
		var nd: Dictionary = NAMED[named_id(r)]
		tags[0] = "%s %s" % [rarity_name(r), d.get("name", "")]
		if nd.has("tower"):
			tags.append(TEXT["tower_piece"])
		elif nd.has("beast"):
			tags.append(TEXT["beast_piece"])
	if wears(r):
		tags.append(TEXT["condition"] % int(round(condition(r) * 100.0)))
	else:
		tags.append(TEXT["never_wears"])
	lines.append("  ·  ".join(tags))
	if is_worn(r):
		lines.append(TEXT["worn_weapon"] if Weapons.WEAPONS.has(base_id(r)) else TEXT["worn"])
	# A relic's history, once the owner has written it (blank: nothing shows).
	if history(r) != "":
		lines.append(TEXT["history"] % history(r))
	return lines


## A piece's enchantment and traits for a card: [[text, colour (its
## essence's)], ...]. An enchanted piece says so first, with its essence
## (a relic says whether it's enchanted); an enchanted pistol then says
## what its essence shot does. Ordinary pieces have none of these lines.
static func trait_lines(g) -> Array:
	var r := rec(g)
	var out: Array = []
	var ek := enchant_kind(r)
	if NAMED.has(named_id(r)):
		if ek != "":
			out.append([TEXT["relic"] % Essence.display(ek), Essence.color(ek)])
		else:
			out.append([TEXT["relic_plain"], RARITIES["common"]["color"]])
	elif ek != "":
		out.append([TEXT["enchanted"] % Essence.display(ek), Essence.color(ek)])
	var sk := shot_kind(r)
	if sk != "":
		var shot := Weapons.essence_shot(sk)
		out.append([Weapons.GUN_TEXT["shot"] % [shot["name"], shot["desc"]], Essence.color(sk)])
		out.append([Weapons.GUN_TEXT["refills"], Essence.color(sk)])
	for t in r.get("traits", []):
		if TRAITS.has(t):
			out.append([trait_text(t, r["rarity"], int(r.get("rank", 0))), Essence.color(TRAITS[t]["kind"])])
	if r.has("rune"):
		out.append([rune_text(r["rune"]), LASTING_RUNES[r["rune"]]["color"]])
	return out


## A random piece of gear (its id), weighted by how common each is. A
## monster's kind favours gear that suits it; `exclude` leaves out ids you
## already carry; `trinkets` false leaves out rings and amulets (the first
## climb); pieces Rare by nature only come with a Rare roll (`top`).
static func random_gear(kind := "", exclude: Array = [], trinkets := true, top := "fine") -> String:
	var pool := {}
	for id in WEAPON_DROP_WEIGHT:
		pool[id] = int(WEAPON_DROP_WEIGHT[id])
	for id in ARMOR:
		if id != "":
			pool[id] = int(ARMOR[id]["drop_weight"])
	for id in PIECES:
		var w := int(PIECES[id].get("drop_weight", 0))
		if w > 0 and (trinkets or not (PIECES[id]["slot"] in ["ring", "amulet"])) \
				and rarity_rank(natural_rarity(id)) <= maxi(1, rarity_rank(top)):
			pool[id] = w
	for id in FAVOUR.get(kind, []):
		if pool.has(id):
			pool[id] *= FAVOUR_MULT
	var skip := exclude.map(func(e): return base_id(e))
	var total := 0
	for id in pool:
		if not (id in skip):
			total += pool[id]
	if total <= 0:
		return "dagger"
	var roll := randi() % total
	for id in pool:
		if id in skip:
			continue
		roll -= pool[id]
		if roll < 0:
			return id
	return "dagger"


## How common a piece is as a drop (lower is rarer; 99 for unknown).
static func drop_weight(id) -> int:
	var b := base_id(id)
	if ARMOR.has(b):
		return int(ARMOR[b].get("drop_weight", 99))
	if PIECES.has(b):
		return int(PIECES[b].get("drop_weight", 99))
	return int(WEAPON_DROP_WEIGHT.get(b, 99))


## What every climb starts with in each carried slot ({} is empty).
static func start_gear() -> Dictionary:
	var g := {}
	for s in SLOTS:
		g[s] = {}
	g["melee"] = make(Weapons.START_MELEE)
	g["ranged"] = make(Weapons.START_RANGED)
	return g


# --- heirlooms ----------------------------------------------------------------------

## The heirloom slot a piece fills ("chest" for armor, "rings" for a ring).
static func heirloom_slot(id) -> String:
	var gs := slot_of(id)
	for s in HEIRLOOM_SLOTS:
		if s.get("gear", "") == gs:
			return s["id"]
	return ""


## The slot (slot_of) an heirloom slot fills ("" for a planned slot).
static func gear_slot_for(heirloom_slot_id: String) -> String:
	for s in HEIRLOOM_SLOTS:
		if s["id"] == heirloom_slot_id:
			return s.get("gear", "")
	return ""


## The heirloom slot for a carried slot ("armor" -> "chest", a ring -> "rings").
static func heirloom_slot_for_carry(carried: String) -> String:
	match carried:
		"armor":
			return "chest"
		"ring1", "ring2":
			return "rings"
	return carried


static func heirloom_slot_name(heirloom_slot_id: String) -> String:
	for s in HEIRLOOM_SLOTS:
		if s["id"] == heirloom_slot_id:
			return s["name"]
	return heirloom_slot_id


static func heirloom_planned(heirloom_slot_id: String) -> bool:
	for s in HEIRLOOM_SLOTS:
		if s["id"] == heirloom_slot_id:
			return bool(s.get("planned", false))
	return true


## The pieces an heirloom slot holds, as records (Rings holds up to two).
static func heirloom_pieces(heirlooms: Dictionary, heirloom_slot_id: String) -> Array:
	var v = heirlooms.get(heirloom_slot_id, null)
	var out: Array = []
	for g in (v if v is Array else [v]):
		var r := rec(g)
		if not r.is_empty():
			out.append(r)
	return out


## Heirlooms from a save, as records. Old saves kept plain ids ("axe"); those
## become fresh records. Rings keep a list. Unknown or misplaced pieces go.
static func load_heirlooms(raw) -> Dictionary:
	var out := {}
	if not (raw is Dictionary):
		return out
	for hs in raw:
		var want := gear_slot_for(String(hs))
		if want == "":
			continue
		var pieces: Array = heirloom_pieces(raw, hs).filter(func(r): return slot_of(r) == want)
		if pieces.is_empty():
			continue
		if hs == "rings":
			out[hs] = pieces.slice(0, 2)
		else:
			out[hs] = pieces[0]
	return out


## An heirloom kept between climbs is always in full repair.
static func heirloom_copy(g) -> Dictionary:
	var r := rec(g)
	if r.has("wear"):
		r["wear"] = 1.0
	return r


# --- drawing -----------------------------------------------------------------------
# Icons follow icon_art.gd's style: slim shapes in clear colours, smooth
# shading lit from the top-left, a light violet ink outline scaled to the
# size, steel with a cool shine and gold with a warm one, and a soft glow
# in its rarity's colour behind anything finer than Common. Each icon is
# built once per look and size and copied after that, and uses only filled
# shapes, so it is safe under torchlight too (gear on the floor, fx.gd).

const Draw := preload("res://scripts/draw_util.gd")
const Art := preload("res://scripts/icon_art.gd")


## A piece of gear's icon, drawn in code, centred on `c` (about 2*s across).
## Weapons are drawn in their own steel and wood; armor in `col`. `col`'s
## alpha fades the whole icon, and a near-black `col` draws a flat silhouette
## (a drop shadow).
static func draw_icon(ci: CanvasItem, id, c: Vector2, s: float, col: Color) -> void:
	var b := Draw.Batch.new()
	icon_into(b, id, c, s, col)
	if col.v < 0.08:
		for i in b.cols.size():
			b.cols[i] = col
	b.flush(ci)


## A piece's icon into a Batch: its rarity's glow behind it, a tempered
## piece's rank (small gilt lozenges down its left side) and a lasting rune
## (its glyph on a dark stone, bottom right) over it. `col`'s alpha fades it.
static func icon_into(b, g, c: Vector2, s: float, col: Color) -> void:
	s = Art.size_step(s)
	var start: int = b.pts.size()
	var shadow := col.v < 0.08
	var key := "gear|%s|%.2f|%s|%s" % [_look_key(g), s, Color(col, 1.0).to_html(false), shadow]
	Art.cached(b, key, c, func(nb): _icon_art(nb, g, s, col, shadow))
	if col.a < 0.999 and not shadow:
		for i in range(start, b.cols.size()):
			b.cols[i].a *= col.a


## What changes how a piece looks: its base, name, rarity, rank, rune and wear.
static func _look_key(g) -> String:
	if g is Dictionary:
		return "%s,%s,%s,%d,%s,%s" % [g.get("base", ""), g.get("named", ""), g.get("rarity", ""), int(g.get("rank", 0)), g.get("rune", ""), is_worn(g)]
	var t := String(g) if (g is String or g is StringName) else ""
	if ";" in t:
		return _look_key(rec(t))
	return t


## The icon around (0, 0).
static func _icon_art(b, g, s: float, col: Color, shadow: bool) -> void:
	var c := Vector2.ZERO
	if not shadow and base_id(g) != "":
		var r := rarity(g)
		if r != "common":
			Art.rarity_glow(b, c, s, r, rarity_color(g))
		Art.ground(b, s, 9.0, 6.6 if slot_of(g) in ["ring", "amulet"] else 7.6, 0.34)
	_icon_body(b, g, c, s, col)
	if not (g is Dictionary) or shadow:
		return
	if rarity(g) == "regarded":
		Art.regarded_glints(b, c, s, rarity_color(g))
	var k := int(g.get("rank", 0))
	var d := maxf(1.7, s * 0.13)
	for i in k:
		var p := c + Vector2(-s * 0.9, -s * 0.08 + s * 0.32 * i)
		var lz := PackedVector2Array([p + Vector2(0, -d), p + Vector2(d * 0.7, 0), p + Vector2(0, d), p + Vector2(-d * 0.7, 0)])
		Art.shape(b, lz, Art.GOLD, s, "gold", Art.THIN | Art.NO_RIM)
	if LASTING_RUNES.has(String(g.get("rune", ""))):
		rune_into(b, String(g["rune"]), c + Vector2(s * 0.7, s * 0.7), s * 0.34, LASTING_RUNES[g["rune"]]["color"])


## A rune drawn in code: a few strokes joining dots of a 3 by 3 grid, picked
## by hashing `id` (the same id always draws the same rune), on a dark stone
## with a faint glow and a gilt hairline.
static func rune_into(b, id: String, c: Vector2, r: float, col: Color, stone := true) -> void:
	if stone:
		var n := clampi(int(r * 2.0) + 14, 16, 32)
		b.circle(c, r * 1.25 + 0.6, Color(Art.INK, Art.FEATHER), n)
		b.circle(c, r * 1.25, Art.INK, n)
		b.circle(c, r * 1.12, Color(0.14, 0.12, 0.19), n)
		Art.soft(b, c, r * 1.1, Color(col, 0.35))
		if r >= 5.0:
			b.arc(c, r * 1.12, 0.0, TAU, n, Color(Art.GOLD, 0.55), maxf(0.6, r * 0.08))
	var w := maxf(0.9, r * 0.22)
	for st in rune_strokes(id):
		var a := c + _rune_dot(st[0]) * r * 0.66
		var e := c + _rune_dot(st[1]) * r * 0.66
		b.line(a, e, col, w)
		b.circle(a, w * 0.5, col, 10)
		b.circle(e, w * 0.5, col, 10)


## A rune's strokes: pairs of dots (0 to 8, row by row on a 3 by 3 grid),
## one connected path of 3 or 4 strokes between neighbouring dots, hashed
## from `id`.
static func rune_strokes(id: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(id)
	var at := rng.randi() % 9
	var out: Array = []
	var seen := {}
	for i in 3 + rng.randi() % 2:
		var opts: Array = []
		for j in 9:
			var key := Vector2i(mini(at, j), maxi(at, j))
			if j != at and _rune_dot(j).distance_to(_rune_dot(at)) < 1.5 and not seen.has(key):
				opts.append(j)
		if opts.is_empty():
			break
		var nx: int = opts[rng.randi() % opts.size()]
		seen[Vector2i(mini(at, nx), maxi(at, nx))] = true
		out.append([at, nx])
		at = nx
	return out


## A rune grid dot's place, -1 to 1 each way.
static func _rune_dot(i: int) -> Vector2:
	return Vector2(posmod(i, 3) - 1, floori(i / 3.0) - 1)


## A colour lifted just enough to read on the dark slots (very dark cloth
## and leather would sink into them).
static func _readable(col: Color) -> Color:
	if col.v >= 0.46:
		return col
	return Color.from_hsv(col.h, col.s * 0.95, lerpf(col.v, 0.46, 0.55), col.a)


static func _icon_body(b, g, c: Vector2, s: float, col: Color) -> void:
	var id := base_id(g)
	if PIECES.has(id):
		_piece_icon(b, id, c, s, named_id(g), NAMED.get(named_id(g), {}).get("color", Color(0, 0, 0, 0)))
		if g is Dictionary and is_worn(g):
			_cracks(b, c, s)
		return
	var u := Art.unit(s)  # drawn on a grid of about -10..10
	var lod := Art.detail(s)
	var nm := named_id(g)
	var steel := Art.STEEL
	var wood := Art.WOOD
	# A named weapon is cast in its own colour (gear.gd NAMED "color"):
	# a sunsteel edge, a stinger's amber, a fang's ivory, a bow's pale wood.
	if NAMED.has(nm) and NAMED[nm].has("color") and Weapons.WEAPONS.has(id):
		if Weapons.is_ranged(id):
			wood = NAMED[nm]["color"]
		else:
			steel = NAMED[nm]["color"]
	if nm == "cinder_axe":
		steel = Color(0.4, 0.36, 0.4)
	elif nm == "reavers_greatsword":
		steel = Color(0.62, 0.62, 0.7)
	var d := Vector2(1, -1).normalized()  # weapons lie from bottom-left to top-right
	var side := d.orthogonal()
	var p := func(x: float, y: float) -> Vector2: return c + Vector2(x, y) * u
	match id:
		"fists":
			for f in [[Vector2(-4.4, 2.4), 1.0], [Vector2(4.0, -1.8), -1.0]]:
				var fc: Vector2 = c + f[0] * u
				Art.rod(b, fc + Vector2(-3.2, 3.6) * u, fc + Vector2(3.2, 3.6) * u, 1.6 * u, Color(0.62, 0.5, 0.4), s, "cloth")
				var body := Art.rrect(Rect2(fc - Vector2(4.0, 3.4) * u, Vector2(8.0, 6.8) * u), 2.2 * u)
				Art.shape(b, body, Art.SKIN, s)
				for k in 3:
					var kx := (-2.0 + k * 2.0) * u
					b.line(fc + Vector2(kx, -3.2 * u), fc + Vector2(kx, -1.2 * u), Art.SKIN.darkened(0.32), maxf(0.6, 0.45 * u))
				Art.orb(b, fc + Vector2(f[1] * 3.6, 1.0) * u, 1.4 * u, Art.SKIN.darkened(0.05), s, "", true)
		"dagger", "sword", "greatsword":
			var sz: Array = {"dagger": [-1.5, 7.2, 1.4, 3.0, 3.8], "sword": [-3.0, 9.2, 1.55, 4.0, 4.2], "greatsword": [-4.0, 10.2, 2.2, 5.2, 4.8]}[id]
			var base: Vector2 = c - d * absf(sz[0]) * u * 1.414
			var tip: Vector2 = c + d * sz[1] * u * 1.414
			var grip_end: Vector2 = base - d * sz[4] * u * 1.414
			Art.rod(b, base, grip_end, 1.6 * u, Art.LEATHER, s, "leather")
			if lod > 0:
				for k in 3:
					var at := base.lerp(grip_end, 0.25 + k * 0.25)
					b.line(at + side * 0.8 * u, at - side * 0.8 * u, Art.LEATHER.darkened(0.4), maxf(0.5, 0.4 * u))
			_blade(b, base, tip, sz[2] * u, steel, s)
			if lod > 0 and id != "dagger":
				# The fuller: a groove down the blade.
				b.line(base + d * 1.2 * u, base.lerp(tip, 0.68), Color(steel.darkened(0.45), 0.7), maxf(0.5, 0.42 * u))
				b.line(base + d * 1.2 * u - side * 0.35 * u, base.lerp(tip, 0.68) - side * 0.35 * u, Color(1, 1, 1, 0.35), maxf(0.4, 0.25 * u))
			var guard_col := Art.GOLD if nm != "reavers_greatsword" else Art.IRON
			Art.rod(b, base + side * sz[3] * u, base - side * sz[3] * u, (1.7 if id == "greatsword" else 1.3) * u, guard_col, s, "gold" if guard_col == Art.GOLD else "metal")
			if lod > 0:
				for sg in [1.0, -1.0]:
					Art.orb(b, base + side * sg * sz[3] * u, 0.75 * u, guard_col.lightened(0.1), s, "gold", false)
			_sword_touch(b, nm, base, tip, grip_end, d, side, sz, u, s, lod)
			if nm != "triune_fang":
				Art.orb(b, grip_end - d * 1.2 * u, (1.3 if id == "dagger" else 1.6) * u, Art.GOLD, s, "gold")
		"axe":
			var h0: Vector2 = p.call(-7.6, 7.6)
			var h1: Vector2 = p.call(6.4, -6.4)
			_haft(b, h0, h1, 1.7 * u, s, lod)
			# A bearded head: narrow at the haft, flaring to a curved edge.
			var away := Vector2(-1, -1).normalized()
			var m := h0.lerp(h1, 0.78)
			var head := PackedVector2Array([m + d * 1.5 * u, m + d * 1.7 * u + away * 2.4 * u])
			var edge := PackedVector2Array()
			for i in 13:
				var t := float(i) / 12.0
				edge.append(m + away * (6.0 + 1.2 * sin(t * PI)) * u + d * lerpf(4.4, -4.6, t) * u)
			head.append_array(edge)
			head.append_array([m - d * 1.9 * u + away * 2.4 * u, m - d * 1.5 * u])
			Art.shape(b, PackedVector2Array([m + d * 1.4 * u, m - d * 1.4 * u, m - d * 1.2 * u - away * 2.0 * u, m + d * 1.2 * u - away * 2.0 * u]), Art.IRON, s, "metal", Art.NO_RIM)
			Art.shape(b, head, steel, s, "metal")
			var glint := PackedVector2Array()
			for i in 11:
				glint.append(edge[i] - away * 0.7 * u)
			var edge_col := Color(1, 1, 1, 0.55) if nm != "cinder_axe" else Color(1.0, 0.56, 0.2, 0.95)
			for i in glint.size() - 1:
				b.line(glint[i], glint[i + 1], edge_col, maxf(0.6, (0.5 if nm != "cinder_axe" else 0.9) * u))
			if lod > 0:
				Art.rivet(b, m + away * 2.2 * u, 0.6 * u, Art.GOLD if nm != "cinder_axe" else Color(1.0, 0.5, 0.2))
			if nm == "cinder_axe":
				Art.soft(b, edge[6] + away * 0.6 * u, 4.6 * u, Color(1.0, 0.5, 0.15, 0.5))
				for v in [Vector2(-8.0, -1.0), Vector2(-5.0, -8.2), Vector2(-9.2, -5.6)]:
					Art.spark(b, c + v * u, 1.1 * u, Color(1.0, 0.72, 0.3, 0.95))
		"mace":
			var h0: Vector2 = p.call(-7.6, 7.6)
			var hc: Vector2 = p.call(4.2, -4.2)
			_haft(b, h0, hc, 1.6 * u, s, lod)
			Art.orb(b, h0, 1.4 * u, Art.LEATHER, s, "leather")
			if nm == "wyrmspine_mace":
				# Vertebrae down the haft, and long curved spines off a skull-round head.
				for k in 3:
					var at := h0.lerp(hc, 0.3 + k * 0.17)
					Art.orb(b, at, 1.25 * u, steel.darkened(0.08), s, "", true)
				for i in 7:
					var a := TAU * i / 7.0 - 0.5
					var bs := hc + Vector2.from_angle(a) * 3.0 * u
					var tip := hc + Vector2.from_angle(a + 0.45) * 7.6 * u
					Art.shape(b, PackedVector2Array([bs + Vector2.from_angle(a - 1.2) * 1.1 * u, tip, bs + Vector2.from_angle(a + 1.6) * 1.1 * u]), steel.lightened(0.05), s, "", Art.NO_RIM | Art.THIN)
				Art.orb(b, hc, 3.9 * u, steel, s, "")
				b.circle(hc + Vector2(-1.2, 0.4) * u, 0.75 * u, Color(0.2, 0.12, 0.1), 10)
				b.circle(hc + Vector2(1.0, -1.0) * u, 0.75 * u, Color(0.2, 0.12, 0.1), 10)
			else:
				for i in 6:
					var a := TAU * i / 6.0 + 0.3
					Art.shape(b, PackedVector2Array([hc + Vector2.from_angle(a - 0.4) * 3.0 * u, hc + Vector2.from_angle(a) * 6.2 * u, hc + Vector2.from_angle(a + 0.4) * 3.0 * u]), Art.IRON, s, "metal", Art.NO_RIM | Art.THIN)
				Art.orb(b, hc, 3.7 * u, steel, s, "metal")
				if lod > 0:
					for i in 3:
						Art.rivet(b, hc + Vector2.from_angle(PI * 0.8 + i * 0.7) * 2.2 * u, 0.45 * u, Art.IRON)
		"spear":
			var h0: Vector2 = p.call(-9.6, 9.6)
			var base: Vector2 = p.call(3.8, -3.8)
			_haft(b, h0, base, 1.3 * u, s, lod)
			if nm == "coral_trident":
				# Three prongs of living coral, the middle one longest.
				var cross := base + d * 1.6 * u
				Art.rod(b, cross + side * 3.4 * u, cross - side * 3.4 * u, 1.5 * u, steel, s, "")
				for k in [-1.0, 0.0, 1.0]:
					var root: Vector2 = cross + side * k * 3.0 * u
					var tip: Vector2 = root + d * (8.6 - absf(k) * 2.4) * u
					Art.rod(b, root, tip - d * 1.4 * u, 1.2 * u, steel, s, "")
					Art.shape(b, PackedVector2Array([tip + d * 0.8 * u, tip - d * 1.8 * u + side * 1.2 * u, tip - d * 1.8 * u - side * 1.2 * u]), steel.lightened(0.15), s, "", Art.THIN | Art.NO_RIM)
				if lod > 0:
					for v in [Vector2(2.2, -6.8), Vector2(6.6, -2.6)]:
						b.circle(c + v * u, 0.55 * u, Color(1, 0.9, 0.86, 0.8), 8)
			else:
				_leaf(b, base, p.call(10.4, -10.4), 2.1 * u, steel, s)
			Art.rod(b, base - d * 0.5 * u, base + d * 0.5 * u, 2.2 * u, Art.LEATHER, s, "leather")
			if lod > 0:
				Art.stitches(b, base - d * 0.4 * u - side * 0.9 * u, base + d * 0.4 * u - side * 0.9 * u, 2, Color(Art.LEATHER.lightened(0.4), 0.8), maxf(0.4, 0.3 * u))
		"war_hammer":
			var h0: Vector2 = p.call(-7.6, 7.6)
			var hc: Vector2 = p.call(4.4, -4.4)
			_haft(b, h0, hc + d * 2.0 * u, 1.6 * u, s, lod)
			var down := Vector2(1, 1).normalized()
			var blk := PackedVector2Array([hc - down * 1.4 * u - d * 2.5 * u, hc + down * 5.6 * u - d * 2.5 * u,
				hc + down * 5.6 * u + d * 2.5 * u, hc - down * 1.4 * u + d * 2.5 * u])
			var spike := PackedVector2Array([hc - down * 1.4 * u - d * 1.4 * u, hc - down * 6.4 * u, hc - down * 1.4 * u + d * 1.4 * u])
			Art.shape(b, spike, steel, s, "metal")
			Art.shape(b, blk, steel, s, "metal")
			b.line(blk[1].lerp(blk[2], 0.12), blk[1].lerp(blk[2], 0.88), Color(Art.INK, 0.35), maxf(0.6, 0.5 * u))
			if lod > 0:
				for k in [0.25, 0.75]:
					Art.rivet(b, blk[0].lerp(blk[3], k) + down * 1.2 * u, 0.5 * u, Art.IRON)
			if nm == "thornmaul":
				# A briar wound round the haft and over the head, thorns out.
				var vine := Color(0.36, 0.6, 0.3)
				var prev := h0.lerp(hc, 0.12)
				for k in 13:
					var tt := 0.12 + k * 0.07
					var at := h0.lerp(hc, tt) + side * sin(tt * 26.0) * 1.6 * u
					b.line(prev, at, Art.INK, 1.3 * u + Art.ol(s))
					b.line(prev, at, vine, 1.1 * u)
					if k % 3 == 1:
						var out := side * (1.0 if sin(tt * 26.0) > 0.0 else -1.0)
						b.polygon(PackedVector2Array([at + d * 0.5 * u, at + out * 1.9 * u, at - d * 0.5 * u]), vine.lightened(0.25))
					prev = at
				for v in [Vector2(4.6, -1.0), Vector2(1.8, -6.4)]:
					var lf := Art.oval(c + v * u, Vector2(1.5, 0.8) * u, -0.8, 10)
					Art.shape(b, lf, vine.lightened(0.15), s, "", Art.THIN | Art.NO_RIM)
		"shortbow", "longbow":
			var r := (10.0 if id == "shortbow" else 12.0) * u
			var o: Vector2 = p.call(-4.6, 0.0)
			var t0 := o + Vector2.from_angle(-1.12) * r
			var t1 := o + Vector2.from_angle(1.12) * r
			var storm := nm in ["stormstring", "stormtalon"]
			b.line(t0, t1, Color(0.95, 0.91, 0.82) if not storm else Color(0.7, 0.88, 1.0), maxf(0.6, 0.4 * u))  # the string
			if storm:
				Art.bolt(b, t0.lerp(t1, 0.08), t1.lerp(t0, 0.08), maxf(0.5, 0.4 * u), Color(0.8, 0.92, 1.0), 6)
			_arrow(b, p.call(-6.4, 0.0), p.call(10.0, 0.0), u, s)
			Art.arc_rod(b, o, r, -1.12, 1.12, 1.9 * u, wood, s, "wood" if nm == "" else "metal", 0.45)
			for tp in [t0, t1]:
				Art.orb(b, tp, 0.85 * u, Art.GOLD if nm == "" else wood.lightened(0.2), s, "gold")  # the nocks
			if nm == "stormtalon":
				for k in [-1.0, 1.0]:
					var tp: Vector2 = t0 if k < 0.0 else t1
					Art.feather(b, tp, tp + Vector2(-3.6, k * 3.2) * u, 1.3 * u, Color(0.86, 0.88, 0.94), s, Art.THIN | Art.NO_RIM)
			Art.rod(b, o + Vector2(r, -1.6 * u), o + Vector2(r, 1.6 * u), 2.1 * u, Art.LEATHER, s, "leather")  # the grip
			if nm == "hollowmoon_bow":
				Art.soft(b, o + Vector2(r, 0), 3.8 * u, Color(0.8, 0.88, 1.0, 0.5))
				Art.orb(b, o + Vector2(r + 0.2 * u, 0), 1.5 * u, Color(0.94, 0.96, 1.0), s, "gem")
				b.circle(o + Vector2(r + 0.9 * u, -0.4 * u), 1.2 * u, Color(0.4, 0.46, 0.62), 12)
		"cane", "sword_cane":
			# A walking cane: a dark shaft, a steel ferrule, and a crook; the
			# sword-cane drawn a little apart, its blade showing between the
			# shaft and the silver-knobbed handle.
			var cw: Color = color(g)
			var foot: Vector2 = p.call(-8.6, 8.6)
			if id == "cane":
				var top: Vector2 = p.call(4.6, -4.6)
				Art.rod(b, foot, top, 1.35 * u, cw, s, "wood")
				Art.arc_rod(b, top + Vector2(2.6, 0.0) * u, 2.6 * u, -PI, 0.55, 1.35 * u, cw.lightened(0.08), s, "wood", 0.2)
				if lod > 0:
					Art.rod(b, top - d * 1.6 * u, top - d * 0.4 * u, 1.6 * u, Art.GOLD, s, "gold")  # a brass band under the crook
			else:
				var mouth: Vector2 = p.call(-0.8, 0.8)
				var hilt: Vector2 = p.call(4.4, -4.4)
				Art.rod(b, foot, mouth, 1.35 * u, cw, s, "wood")
				_blade(b, mouth, hilt + d * 0.6 * u, 0.85 * u, steel, s)
				Art.rod(b, mouth - d * 0.6 * u, mouth + d * 0.5 * u, 1.65 * u, Art.STEEL, s, "metal")  # the collar where the blade parts
				Art.rod(b, hilt, p.call(7.2, -7.2), 1.35 * u, cw, s, "wood")
				Art.orb(b, p.call(8.0, -8.0), 1.7 * u, Art.STEEL.lightened(0.1), s, "metal")
			Art.orb(b, foot, 0.95 * u, Art.IRON, s, "metal")
		"flintlock":
			# A flintlock pistol: a long barrel on a wooden full stock, its
			# hammer cocked, a brass cap on the butt.
			var fw: Color = color(g)
			var stock := Art.pts(c, u, [Vector2(-9.4, 5.2), Vector2(-7.4, 7.8), Vector2(-5.0, 6.6), Vector2(-2.2, 0.8), Vector2(6.8, -0.6),
				Vector2(6.8, -2.4), Vector2(-3.4, -2.4), Vector2(-5.6, -1.0)])
			Art.shape(b, stock, fw, s, "wood")
			Art.rod(b, p.call(-3.2, -3.2), p.call(9.6, -3.2), 1.25 * u, steel, s, "metal")
			Art.orb(b, p.call(9.6, -3.2), 0.85 * u, Art.GOLD, s, "gold")
			if lod > 0:
				b.line(p.call(-1.0, -1.5), p.call(6.2, -1.5), Color(fw.darkened(0.45), 0.8), maxf(0.5, 0.4 * u))  # the ramrod
				Art.shape(b, Art.pts(c, u, [Vector2(-3.2, -2.0), Vector2(-0.6, -2.0), Vector2(-0.8, 0.2), Vector2(-3.0, 0.4)]), Art.IRON, s, "metal", Art.THIN | Art.NO_RIM)  # the lock
			Art.shape(b, Art.pts(c, u, [Vector2(-3.8, -2.6), Vector2(-5.2, -5.8), Vector2(-3.4, -6.2), Vector2(-2.6, -3.0)]), steel.darkened(0.15), s, "metal", Art.THIN)  # the hammer
			b.arc(p.call(-1.4, 1.0), 1.5 * u, 0.2, PI - 0.2, 10, Art.GOLD.darkened(0.2), maxf(0.6, 0.45 * u))  # the trigger guard
			Art.orb(b, p.call(-8.4, 6.6), 1.5 * u, Art.GOLD, s, "gold")  # the butt cap
			if nm == "emberlock":
				# A pan that never goes cold: embers at the lock.
				Art.soft(b, p.call(-2.0, -1.0), 4.0 * u, Color(1.0, 0.5, 0.15, 0.55))
				for v in [Vector2(-1.4, -4.6), Vector2(0.8, -6.0), Vector2(-3.0, -7.4)]:
					Art.spark(b, c + v * u, 1.0 * u, Color(1.0, 0.72, 0.3, 0.95))
		"revolver":
			# A revolver: a curved wooden grip, a steel frame with its fluted
			# cylinder, a short barrel and a hammer spur.
			var rw: Color = color(g)
			var grip := Art.smooth(Art.pts(c, u, [Vector2(-7.8, 6.4), Vector2(-5.0, 7.8), Vector2(-2.8, 1.6), Vector2(-1.2, -0.6),
				Vector2(-4.0, -1.8), Vector2(-6.4, 0.6)]), 2)
			Art.shape(b, grip, rw, s, "wood")
			Art.rod(b, p.call(2.6, -2.8), p.call(10.0, -2.8), 1.2 * u, steel, s, "metal")
			Art.shape(b, Art.rrect(Rect2(c + Vector2(-4.4, -4.0) * u, Vector2(7.8, 4.4) * u), 0.9 * u, 3), steel.darkened(0.1), s, "metal")
			var cyl := Art.rrect(Rect2(c + Vector2(-1.8, -4.8) * u, Vector2(4.8, 5.6) * u), 1.4 * u, 3)
			Art.shape(b, cyl, steel.lightened(0.06), s, "metal")
			if lod > 0:
				for k in [-0.2, 1.4]:
					b.line(c + Vector2(k, -4.0) * u, c + Vector2(k, 0.0) * u, Color(Art.INK, 0.45), maxf(0.5, 0.35 * u))  # the flutes
				Art.orb(b, p.call(9.4, -4.2), 0.55 * u, steel, s, "metal", false)  # the front sight
			Art.shape(b, Art.pts(c, u, [Vector2(-4.0, -3.4), Vector2(-6.2, -5.6), Vector2(-5.0, -6.0), Vector2(-3.0, -4.0)]), steel.darkened(0.2), s, "metal", Art.THIN)  # the hammer spur
			b.arc(p.call(-0.8, 1.4), 1.5 * u, 0.2, PI - 0.2, 10, steel.darkened(0.25), maxf(0.6, 0.45 * u))  # the trigger guard
			if nm == "lastbell_revolver" and lod > 0:
				Art.rod(b, p.call(8.4, -2.8), p.call(9.2, -2.8), 1.6 * u, Art.GOLD, s, "gold")  # a brass band at the muzzle
		"crossbow":
			var pc: Vector2 = p.call(1.6, 0.0)
			var tips := [pc + Vector2.from_angle(-1.22) * 7.6 * u, pc + Vector2.from_angle(1.22) * 7.6 * u]
			if nm == "spinecaster":
				# The bow arms are a segmented tail, each tip a barb.
				for i in 9:
					var a := lerpf(-1.22, 1.22, i / 8.0)
					Art.orb(b, pc + Vector2.from_angle(a) * 7.6 * u, (1.25 - absf(a) * 0.3) * u, wood, s, "")
				for tp in tips:
					var out: Vector2 = (tp - pc).normalized()
					Art.shape(b, PackedVector2Array([tp + out * 2.6 * u, tp + out.orthogonal() * 1.0 * u, tp - out.orthogonal() * 1.0 * u]), Color(0.95, 0.85, 0.6), s, "", Art.THIN | Art.NO_RIM)
			else:
				Art.arc_rod(b, pc, 7.6 * u, -1.22, 1.22, 1.6 * u, steel, s, "metal", 0.35)
			b.line(tips[0], p.call(-2.0, -0.2), Color(0.95, 0.91, 0.82), maxf(0.6, 0.4 * u))
			b.line(tips[1], p.call(-2.0, 0.2), Color(0.95, 0.91, 0.82), maxf(0.6, 0.4 * u))
			var stock := Art.pts(c, u, [Vector2(-9.6, 0.8), Vector2(-9.6, -1.4), Vector2(-4.0, -1.4), Vector2(8.6, -0.7),
				Vector2(8.6, 1.0), Vector2(-3.0, 1.0), Vector2(-5.8, 3.4), Vector2(-8.8, 3.4)])
			Art.shape(b, stock, wood, s, "wood")
			if lod > 1:
				b.line(p.call(-8.6, 0.0), p.call(6.0, 0.0), Color(wood.darkened(0.35), 0.5), 0.5 * u)
			if lod > 0:
				Art.rivet(b, p.call(-6.2, 0.0), 0.55 * u, Art.IRON)
				Art.shape(b, Art.pts(c, u, [Vector2(-4.2, 1.0), Vector2(-2.6, 1.0), Vector2(-3.0, 3.2), Vector2(-3.8, 3.2)]), Art.IRON, s, "metal", Art.THIN | Art.NO_RIM)  # the trigger
			_arrow(b, p.call(-2.0, -1.8), p.call(9.2, -1.8), u * 0.8, s)
			if nm == "spinecaster":
				for k in [-1.0, 1.0]:
					var bt: Vector2 = p.call(-0.6, -1.8 + k * 2.4)
					Art.rod(b, bt, bt + Vector2(7.6, k * 1.4) * u, 0.6 * u, Color(0.92, 0.84, 0.62), s, "")
				b.circle(p.call(9.4, -1.8), 0.9 * u, Color(0.55, 0.85, 0.35, 0.9), 10)
		"", "padded", "leather", "chain", "plate":
			var shape := [Vector2(-7.4, -7.0), Vector2(-3.2, -9.4), Vector2(0, -6.6), Vector2(3.2, -9.4), Vector2(7.4, -7.0),
				Vector2(6.6, 1.0), Vector2(4.0, 9.0), Vector2(-4.0, 9.0), Vector2(-6.6, 1.0)]
			var body := Art.pts(c, u, shape)
			if id == "":
				# No armor: a faint dashed outline where it would be.
				for i in body.size():
					var a := body[i]
					var bb := body[(i + 1) % body.size()]
					b.line(a.lerp(bb, 0.15), a.lerp(bb, 0.6), Color(col, 0.6), maxf(0.9, 0.7 * u))
				return
			var ac := _readable(col)
			var kind: String = {"padded": "cloth", "leather": "leather", "chain": "metal", "plate": "metal"}[id]
			Art.shape(b, body, ac, s, kind)
			var dark := ac.darkened(0.42)
			var thin := maxf(0.55, 0.45 * u)
			match id:
				"padded":
					for y in [-3.2, 0.6, 4.4]:
						b.line(c + Vector2(-6.0, y) * u, c + Vector2(6.0, y) * u, Color(dark, 0.8), thin)
					if lod > 0:
						for x in [-3.0, 3.0]:
							b.line(c + Vector2(x, -5.6) * u, c + Vector2(x, 8.2) * u, Color(dark, 0.5), thin * 0.8)
					b.line(c + Vector2(-3.0, -8.4) * u, c + Vector2(0, -5.6) * u, Color(ac.lightened(0.3), 0.7), thin)
					b.line(c + Vector2(3.0, -8.4) * u, c + Vector2(0, -5.6) * u, Color(dark, 0.7), thin)
				"leather":
					b.line(c + Vector2(0, -6.0) * u, c + Vector2(0, 8.6) * u, Color(dark, 0.9), thin)
					for y in [-1.0, 4.0]:
						Art.shape(b, Art.rrect(Rect2(c + Vector2(-6.4, y) * u, Vector2(12.8, 1.6) * u), 0.3 * u, 2), Color(0.28, 0.18, 0.12), s, "leather", Art.THIN | Art.NO_RIM)
						Art.shape(b, Art.rrect(Rect2(c + Vector2(-1.1, y - 0.3) * u, Vector2(2.2, 2.2) * u), 0.4 * u, 2), Art.GOLD, s, "gold", Art.THIN | Art.NO_RIM)
				"chain":
					var rows := 5 if lod > 0 else 4
					for row in rows:
						for k in 5:
							var x := -4.8 + k * 2.4 + (1.2 if row % 2 == 1 else 0.0)
							var y := -5.0 + row * (14.0 / rows)
							if absf(x) > 6.0 - maxf(0.0, y - 2.0) * 0.4:
								continue
							b.arc(c + Vector2(x, y) * u, 1.0 * u, PI * 0.9, PI * 2.1, 8, Color(dark, 0.9), maxf(0.5, 0.42 * u))
							b.circle(c + Vector2(x - 0.3, y - 0.4) * u, 0.4 * u, Color(ac.lightened(0.45), 0.8), 8)
				"plate":
					if nm == "wyvern_scaleplate":
						for row in 5:
							for k in 5:
								var x := -5.2 + k * 2.6 + (1.3 if row % 2 == 1 else 0.0)
								var y := -4.4 + row * 2.7
								if absf(x) > 6.2 - maxf(0.0, y - 2.0) * 0.45:
									continue
								b.arc(c + Vector2(x, y) * u, 1.35 * u, PI * 0.05, PI * 0.95, 8, Color(dark, 0.95), maxf(0.55, 0.45 * u))
								b.arc(c + Vector2(x, y - 0.3) * u, 1.0 * u, PI * 1.15, PI * 1.6, 5, Color(ac.lightened(0.45), 0.7), maxf(0.45, 0.3 * u))
					else:
						for y in [-1.0, 3.6]:
							b.line(c + Vector2(-6.6, y) * u, c + Vector2(6.6, y) * u, Color(dark, 0.85), maxf(0.6, 0.6 * u))
							b.line(c + Vector2(-6.2, y + 0.8) * u, c + Vector2(6.2, y + 0.8) * u, Color(ac.lightened(0.45), 0.6), maxf(0.5, 0.35 * u))
						# A ridge down the breastplate, lit on one side.
						b.line(c + Vector2(0, -5.6) * u, c + Vector2(0, -1.4) * u, Color(dark, 0.7), maxf(0.5, 0.45 * u))
						b.line(c + Vector2(-0.4, -5.6) * u, c + Vector2(-0.4, -1.4) * u, Color(1, 1, 1, 0.45), maxf(0.4, 0.3 * u))
					for x in [-6.8, 6.8]:
						Art.orb(b, c + Vector2(x, -7.0) * u, 2.5 * u, ac, s, "metal")
					if lod > 0:
						for x in [-4.2, 4.2]:
							Art.rivet(b, c + Vector2(x, 6.4) * u, 0.6 * u, Art.GOLD)
					if nm == "bastion_plate":
						var sh := Art.pts(c, u, [Vector2(-2.6, -4.6), Vector2(2.6, -4.6), Vector2(2.4, -0.6), Vector2(0, 1.8), Vector2(-2.4, -0.6)])
						Art.shape(b, sh, Color(0.62, 0.2, 0.2), s, "cloth", Art.THIN)
						b.line(c + Vector2(0, -4.2) * u, c + Vector2(0, 1.2) * u, Art.GOLD, maxf(0.5, 0.45 * u))
						b.line(c + Vector2(-2.0, -2.6) * u, c + Vector2(2.0, -2.6) * u, Art.GOLD, maxf(0.5, 0.45 * u))
		_:
			Art.orb(b, c, s * 0.5, col, s)
	if ARMOR.has(id):
		_chest_touch(b, nm, c, u, s, lod, _readable(col))
	if g is Dictionary and is_worn(g):
		_cracks(b, c, s)


## The swords' named touches: a Stinger's barb and venom drop, a Sunsteel
## sun at the guard, a Reaver's notches and red grip, the Triune Fang's
## three heads for a pommel.
static func _sword_touch(b, nm: String, base: Vector2, tip: Vector2, grip_end: Vector2, d: Vector2, side: Vector2, sz: Array, u: float, s: float, lod: int) -> void:
	match nm:
		"stinger_dagger":
			var at := base.lerp(tip, 0.72)
			var lit := side if side.dot(Art.LIGHT) > 0.0 else -side
			Art.shape(b, PackedVector2Array([at - lit * 1.2 * u, at - lit * 3.0 * u - d * 1.6 * u, at - lit * 1.0 * u + d * 1.4 * u]), Color(0.86, 0.6, 0.28), s, "", Art.THIN | Art.NO_RIM)
			b.circle(tip + d * 0.4 * u + Vector2(0.6, 1.4) * u, 0.75 * u, Color(0.55, 0.88, 0.35, 0.95), 10)
		"sunsteel_blade":
			Art.soft(b, base, 4.4 * u, Color(1.0, 0.8, 0.4, 0.55))
			for i in 8:
				var a := TAU * i / 8.0
				b.line(base + Vector2.from_angle(a) * 1.6 * u, base + Vector2.from_angle(a) * 2.9 * u, Color(1.0, 0.86, 0.45), maxf(0.5, 0.45 * u))
			Art.orb(b, base, 1.5 * u, Color(1.0, 0.78, 0.36), s, "gold")
		"reavers_greatsword":
			var lit := side if side.dot(Art.LIGHT) > 0.0 else -side
			for k in [0.3, 0.5, 0.66]:
				var at := base.lerp(tip, k) + lit * float(sz[2]) * u
				b.polygon(PackedVector2Array([at + d * 0.7 * u, at - lit * 1.0 * u, at - d * 0.7 * u]), Color(0.16, 0.12, 0.18))
			Art.rod(b, base - d * 0.6 * u, grip_end + d * 0.6 * u, 1.3 * u, Color(0.6, 0.16, 0.18), s, "leather")
		"triune_fang":
			# Three heads for a pommel: the lion's gold, the goat's horn, the serpent's green.
			var pm := grip_end - d * 1.6 * u
			Art.orb(b, pm + side * 1.4 * u, 1.15 * u, Color(0.95, 0.72, 0.3), s, "gold")
			Art.orb(b, pm - side * 1.4 * u, 1.15 * u, Color(0.45, 0.78, 0.36), s, "gem")
			Art.orb(b, pm - d * 1.2 * u, 1.15 * u, Color(0.9, 0.86, 0.76), s, "")
			if lod > 0:
				for k in 3:
					var at := base.lerp(tip, 0.25 + k * 0.17)
					b.circle(at, 0.5 * u, [Color(0.95, 0.72, 0.3), Color(0.9, 0.86, 0.76), Color(0.45, 0.78, 0.36)][k], 8)


## The named chest pieces' touches: Barnacle Mail's shells, the Deepcoil
## Coat's coiled arms and suckers.
static func _chest_touch(b, nm: String, c: Vector2, u: float, s: float, lod: int, col: Color) -> void:
	match nm:
		"barnacle_mail":
			for v in [Vector2(-4.2, -3.0), Vector2(3.2, 0.8), Vector2(-1.6, 4.6), Vector2(4.6, -4.4), Vector2(-5.0, 2.4)]:
				var sc: Vector2 = c + v * u
				Art.shape(b, Art.oval(sc, Vector2(1.5, 1.2) * u, 0.0, 10), Color(0.9, 0.86, 0.76), s, "", Art.THIN | Art.NO_RIM)
				b.circle(sc + Vector2(0.1, -0.1) * u, 0.55 * u, Color(0.25, 0.3, 0.32), 8)
		"deepcoil_coat":
			var arm := Color(0.3, 0.55, 0.62)
			for sg in [-1.0, 1.0]:
				var prev := c + Vector2(sg * 6.0, -6.0) * u
				for k in 9:
					var a := k * 0.55
					var at := c + Vector2(sg * (5.6 - k * 0.5 + cos(a * 2.0) * 0.9), -6.0 + k * 1.7) * u
					b.line(prev, at, Art.INK, (1.5 - k * 0.1) * u + Art.ol(s))
					b.line(prev, at, arm, (1.5 - k * 0.1) * u)
					if lod > 0 and k % 2 == 1:
						b.circle(at - Vector2(sg * 0.5, 0) * u, 0.38 * u, Color(0.85, 0.92, 0.9, 0.85), 8)
					prev = at
			b.line(c + Vector2(0, -6.0) * u, c + Vector2(0, 8.6) * u, Color(col.darkened(0.45), 0.9), maxf(0.55, 0.45 * u))
			for y in [-2.0, 2.4, 6.0]:
				Art.rivet(b, c + Vector2(0, y) * u, 0.6 * u, Color(0.7, 0.86, 0.9))


## A wooden haft from `a` to `e`, with a hint of grain on a big icon.
static func _haft(b, a: Vector2, e: Vector2, w: float, s: float, lod: int) -> void:
	Art.rod(b, a, e, w, Art.WOOD, s, "wood")
	if lod > 1:
		var side := (e - a).normalized().orthogonal() * w * 0.18
		b.line(a.lerp(e, 0.1) - side, a.lerp(e, 0.45) - side, Color(Art.WOOD.darkened(0.4), 0.5), maxf(0.5, w * 0.12))
		b.line(a.lerp(e, 0.55) + side * 0.5, a.lerp(e, 0.9) + side * 0.5, Color(Art.WOOD.darkened(0.4), 0.45), maxf(0.5, w * 0.12))


## A blade from `base` to `tip`, ridged down the middle: the lit half pale,
## the far half in shadow, a glint along it.
static func _blade(b, base: Vector2, tip: Vector2, hw: float, metal: Color, s: float) -> void:
	var dir := (tip - base).normalized()
	var side := dir.orthogonal()
	var len := base.distance_to(tip)
	var shoulder := base + dir * len * 0.8
	var outline := PackedVector2Array([base + side * hw, shoulder + side * hw * 0.92, tip, shoulder - side * hw * 0.92, base - side * hw])
	Art.outline(b, outline, s)
	var r := Art.ramp(metal, "metal")
	var lit := side if side.dot(Art.LIGHT) > 0.0 else -side
	Art.grad(b, PackedVector2Array([base, base - lit * hw, shoulder - lit * hw * 0.92, tip]), metal, r[1], r[0])
	Art.grad(b, PackedVector2Array([base, base + lit * hw, shoulder + lit * hw * 0.92, tip]), r[3].lightened(0.1), r[3], metal)
	b.line(base + dir * len * 0.08 + lit * hw * 0.5, tip - dir * len * 0.14 + lit * hw * 0.22, Color(1, 1, 1, 0.65), maxf(0.55, hw * 0.24))


## A leaf-shaped spearhead.
static func _leaf(b, base: Vector2, tip: Vector2, hw: float, metal: Color, s: float) -> void:
	var dir := (tip - base).normalized()
	var side := dir.orthogonal()
	var len := base.distance_to(tip)
	var wide := base + dir * len * 0.38
	var outline := Art.smooth(PackedVector2Array([base + side * hw * 0.45, wide + side * hw, tip, wide - side * hw, base - side * hw * 0.45]), 3)
	Art.outline(b, outline, s)
	var r := Art.ramp(metal, "metal")
	var lit := side if side.dot(Art.LIGHT) > 0.0 else -side
	Art.grad(b, outline, r[3], metal, r[1])
	b.polygon(PackedVector2Array([base, wide - lit * hw * 0.9, tip]), Color(r[0], 0.35))
	b.line(base + dir * len * 0.1, tip - dir * len * 0.1, Color(1, 1, 1, 0.4), maxf(0.5, hw * 0.16))


## An arrow lying from `tail` to `head`: fletching, shaft and a steel head.
static func _arrow(b, tail: Vector2, head: Vector2, u: float, s: float) -> void:
	var dir := (head - tail).normalized()
	var side := dir.orthogonal()
	Art.rod(b, tail, head - dir * 2.0 * u, 0.75 * u, Art.WOOD.lightened(0.2), s, "wood")
	Art.shape(b, PackedVector2Array([head + dir * 1.0 * u, head - dir * 2.4 * u + side * 1.6 * u, head - dir * 2.4 * u - side * 1.6 * u]), Art.STEEL, s, "metal", Art.THIN | Art.NO_RIM)
	for sg in [1.0, -1.0]:
		b.polygon(PackedVector2Array([tail + dir * 3.0 * u, tail + side * sg * 1.7 * u + dir * 0.2 * u, tail - dir * 0.4 * u + side * sg * 1.4 * u, tail + dir * 0.6 * u]),
			Color(0.9, 0.32, 0.28) if sg > 0.0 else Color(0.94, 0.92, 0.87))


## Cracks across a badly worn piece's icon: a dark split with a warm glint
## along its lit edge.
static func _cracks(b, c: Vector2, s: float) -> void:
	var u := Art.unit(s)
	var w := maxf(0.7, 0.6 * u)
	var crack := Art.pts(c, u, [Vector2(-6.2, -4.8), Vector2(-2.4, -1.4), Vector2(-3.6, 1.8), Vector2(1.4, 5.2)])
	var lit := Vector2(-0.5, -0.6) * w
	for i in crack.size() - 1:
		b.line(crack[i], crack[i + 1], Color(Art.INK, 0.9), w * 1.7)
		b.line(crack[i] + lit, crack[i + 1] + lit, Color(1.0, 0.55, 0.38, 0.7), w * 0.5)
	b.line(crack[1], c + Vector2(1.7, -2.8) * u, Color(Art.INK, 0.9), w)


## The worn pieces (PIECES): a hood, cap or helm, gloves, legs, boots, a
## cloak, a bag, an amulet or a ring, each in its own colour (a named piece
## may have its own `tint`, and a few named pieces their own touch).
static func _piece_icon(b, id: String, c: Vector2, s: float, named := "", tint := Color(0, 0, 0, 0)) -> void:
	var u := Art.unit(s)
	var lod := Art.detail(s)
	var d: Dictionary = PIECES[id]
	var base_col: Color = _readable(d["color"] if tint.a <= 0.0 else tint)
	var dark := base_col.darkened(0.45)
	var lit := base_col.lightened(0.3)
	var thin := maxf(0.55, 0.42 * u)
	var P := func(arr: Array) -> PackedVector2Array: return Art.pts(c, u, arr)
	match String(d["slot"]):
		"helm":
			match id:
				"cloth_hood":
					var hood := Art.smooth(P.call([Vector2(0, -9.4), Vector2(5.6, -7.0), Vector2(7.6, -1.0), Vector2(8.2, 6.0), Vector2(9.4, 9.2),
						Vector2(-9.4, 9.2), Vector2(-8.2, 6.0), Vector2(-7.6, -1.0), Vector2(-5.6, -7.0)]), 3)
					Art.shape(b, hood, base_col, s, "cloth")
					var face := Art.smooth(P.call([Vector2(0, -4.8), Vector2(3.8, -1.8), Vector2(4.2, 3.6), Vector2(0, 6.0), Vector2(-4.2, 3.6), Vector2(-3.8, -1.8)]), 3)
					Art.grad(b, face, Color(0.16, 0.13, 0.2), Color(0.08, 0.065, 0.1), Color(0.05, 0.04, 0.07))
					b.line(c + Vector2(-3.0, -6.6) * u, c + Vector2(-6.0, 1.0) * u, Color(lit, 0.5), thin)
				"leather_cap":
					var dome := PackedVector2Array()
					for i in 17:
						var a := PI + PI * i / 16.0
						dome.append(c + Vector2(cos(a) * 7.8, 2.6 + sin(a) * 8.4) * u)
					Art.shape(b, dome, base_col, s, "leather")
					for x in [-2.8, 2.8]:
						b.line(c + Vector2(x * 0.3, -5.6) * u, c + Vector2(x, 2.6) * u, Color(dark, 0.8), thin)
					Art.shape(b, P.call([Vector2(-8.8, 1.6), Vector2(8.8, 1.6), Vector2(8.4, 4.6), Vector2(-8.4, 4.6)]), base_col.darkened(0.25), s, "leather", Art.THIN)
					if lod > 0:
						for k in 7:
							b.circle(c + Vector2(-6.6 + k * 2.2, 3.1) * u, 0.32 * u, Color(lit, 0.7), 8)
					Art.orb(b, c + Vector2(0, -6.0) * u, 1.0 * u, base_col.darkened(0.2), s, "leather")
				"feathered_cap":
					# A soft brimmed cap, a long hawk's feather swept back from its band.
					Art.feather(b, c + Vector2(2.0, -1.2) * u, c + Vector2(9.4, -9.6) * u, 2.0 * u, Color(0.86, 0.66, 0.4), s)
					var crown := Art.smooth(P.call([Vector2(-6.4, 1.6), Vector2(-5.6, -4.6), Vector2(-1.0, -7.4), Vector2(4.4, -5.8), Vector2(6.4, 1.6)]), 3)
					Art.shape(b, crown, base_col, s, "cloth")
					var brim := Art.smooth(P.call([Vector2(-9.4, 2.6), Vector2(-6.0, 0.8), Vector2(6.0, 0.8), Vector2(9.4, 2.6), Vector2(6.0, 4.8), Vector2(-6.0, 4.8)]), 3)
					Art.shape(b, brim, base_col.darkened(0.12), s, "cloth", Art.THIN)
					Art.shape(b, Art.rrect(Rect2(c + Vector2(-6.2, -0.4) * u, Vector2(12.4, 1.8) * u), 0.4 * u, 2), Color(0.46, 0.28, 0.18), s, "leather", Art.THIN | Art.NO_RIM)
					if lod > 0:
						b.line(c + Vector2(-1.0, -7.0) * u, c + Vector2(-0.4, -0.6) * u, Color(dark, 0.6), thin)
				"miners_helm":
					# A brass dome with a candle in a cup on the brow, lit.
					var dome := PackedVector2Array()
					for i in 17:
						var a := PI + PI * i / 16.0
						dome.append(c + Vector2(cos(a) * 7.8, 4.0 + sin(a) * 9.0) * u)
					Art.shape(b, dome, base_col, s, "gold")
					Art.shape(b, Art.rrect(Rect2(c + Vector2(-9.0, 3.0) * u, Vector2(18.0, 2.4) * u), 0.6 * u, 2), base_col.darkened(0.2), s, "gold", Art.THIN)
					if lod > 0:
						for x in [-5.6, -2.0, 2.0, 5.6]:
							Art.rivet(b, c + Vector2(x, 4.2) * u, 0.45 * u, base_col)
					Art.shape(b, Art.rrect(Rect2(c + Vector2(-1.3, -6.4) * u, Vector2(2.6, 3.8) * u), 0.4 * u, 2), Color(0.97, 0.93, 0.82), s, "", Art.THIN)
					Art.shape(b, Art.pts(c, u, [Vector2(-2.6, -2.8), Vector2(2.6, -2.8), Vector2(1.8, -1.0), Vector2(-1.8, -1.0)]), base_col.darkened(0.15), s, "gold", Art.THIN | Art.NO_RIM)
					Art.soft(b, c + Vector2(0, -8.6) * u, 5.0 * u, Color(1.0, 0.75, 0.3, 0.55))
					Art.flame(b, c + Vector2(0, -8.2) * u, 1.9 * u, s)
				_:
					var dome := PackedVector2Array()
					for i in 17:
						var a := PI + PI * i / 16.0
						dome.append(c + Vector2(cos(a) * 7.8, 3.0 + sin(a) * 9.2) * u)
					dome.append(c + Vector2(7.8, 5.6) * u)
					dome.append(c + Vector2(-7.8, 5.6) * u)
					Art.shape(b, dome, base_col, s, "metal")
					Art.shape(b, Art.rrect(Rect2(c + Vector2(-8.0, 2.2) * u, Vector2(16.0, 2.0) * u), 0.5 * u, 2), base_col.darkened(0.25), s, "metal", Art.THIN | Art.NO_RIM)
					if named == "watchers_helm":
						b.rect(Rect2(c + Vector2(-5.6, -0.8) * u, Vector2(11.2, 1.2) * u), Color(0.06, 0.05, 0.08))
						Art.soft(b, c + Vector2(0, -4.0) * u, 3.0 * u, Color(0.5, 0.75, 1.0, 0.6))
						Art.orb(b, c + Vector2(0, -4.0) * u, 1.3 * u, Color(0.45, 0.7, 1.0), s, "gem")
					Art.shape(b, P.call([Vector2(-1.0, 2.0), Vector2(1.0, 2.0), Vector2(0.9, 9.0), Vector2(-0.9, 9.0)]), base_col, s, "metal", Art.THIN)  # nose guard
					if lod > 0:
						for x in [-6.4, -3.2, 3.2, 6.4]:
							Art.rivet(b, c + Vector2(x, 3.2) * u, 0.42 * u, base_col)
		"gloves":
			if id == "archers_bracers":
				_bracers(b, c, u, s, lod, base_col)
				return
			var palm := Art.smooth(P.call([Vector2(-5.0, -8.0), Vector2(3.6, -8.4), Vector2(4.6, -1.4), Vector2(8.0, -3.2), Vector2(9.0, -1.2),
				Vector2(5.2, 3.8), Vector2(3.8, 9.0), Vector2(-4.6, 9.0), Vector2(-5.8, 2.0)]), 2)
			var gkind := "metal" if id == "gauntlets" else ("cloth" if id == "grip_wraps" else "leather")
			Art.shape(b, palm, base_col, s, gkind)
			for x in [-2.4, 0.2, 2.6]:
				b.line(c + Vector2(x, -8.0) * u, c + Vector2(x * 0.9, -3.2) * u, Color(dark, 0.8), thin)
			match id:
				"grip_wraps":
					for k in 4:
						var y := -5.0 + k * 3.0
						b.line(c + Vector2(-5.4, y + 1.5) * u, c + Vector2(4.6, y - 0.9) * u, Color(dark, 0.55), thin)
						b.line(c + Vector2(-5.4, y + 1.0) * u, c + Vector2(4.6, y - 1.4) * u, Color(lit, 0.6), thin * 0.8)
					# a loose end trailing from the wrist
					Art.shape(b, P.call([Vector2(-4.0, 7.0), Vector2(-1.0, 7.4), Vector2(-4.6, 10.4), Vector2(-7.4, 10.0)]), base_col, s, "cloth", Art.THIN | Art.NO_RIM)
				"studded_gloves":
					var cuff: PackedVector2Array = P.call([Vector2(-5.2, 5.4), Vector2(4.6, 5.4), Vector2(4.2, 9.0), Vector2(-4.6, 9.0)])
					Art.shape(b, cuff, base_col.darkened(0.2), s, "leather", Art.THIN | Art.NO_RIM)
					for v in [Vector2(-2.8, -0.6), Vector2(0.4, -0.8), Vector2(3.0, -0.4), Vector2(-2.0, 2.6), Vector2(1.4, 2.6)]:
						Art.rivet(b, c + v * u, 0.85 * u, Art.STEEL)
				"gauntlets":
					for y in [-3.0, 0.2, 3.4]:
						b.line(c + Vector2(-5.4, y) * u, c + Vector2(4.6, y) * u, Color(dark, 0.85), maxf(0.6, 0.55 * u))
					var cuff: PackedVector2Array = P.call([Vector2(-6.4, 5.0), Vector2(5.6, 5.0), Vector2(6.6, 9.8), Vector2(-7.0, 9.8)])
					Art.shape(b, cuff, base_col, s, "metal", Art.THIN)
					for x in [-3.6, 0.0, 3.6]:
						b.circle(c + Vector2(x, 7.4) * u, 0.55 * u, Art.GOLD, 10)
				_:
					var cuff: PackedVector2Array = P.call([Vector2(-5.2, 5.4), Vector2(4.6, 5.4), Vector2(4.2, 9.0), Vector2(-4.6, 9.0)])
					Art.shape(b, cuff, base_col.darkened(0.2), s, "leather", Art.THIN | Art.NO_RIM)
					if lod > 0:
						for k in 6:
							b.line(c + Vector2(-4.4 + k * 1.6, 6.3) * u, c + Vector2(-3.8 + k * 1.6, 6.3) * u, Color(lit, 0.7), thin * 0.8)
					if named == "quickhand_gloves":
						# A thin knife sheathed at the cuff, a red thread round the fingers.
						Art.rod(b, c + Vector2(-6.6, 3.0) * u, c + Vector2(-6.6, 9.8) * u, 1.3 * u, Color(0.2, 0.14, 0.14), s, "leather")
						Art.rod(b, c + Vector2(-6.6, 1.6) * u, c + Vector2(-6.6, 3.2) * u, 0.9 * u, Art.STEEL, s, "metal")
						Art.orb(b, c + Vector2(-6.6, 1.0) * u, 0.8 * u, Art.GOLD, s, "gold")
						b.line(c + Vector2(-4.8, -4.4) * u, c + Vector2(3.8, -4.8) * u, Color(0.9, 0.3, 0.3, 0.9), thin)
		"legs":
			_legs(b, id, c, u, s, lod, base_col, named)
		"boots":
			_boots(b, id, c, u, s, lod, base_col, named)
		"cloak":
			if id == "feather_cape" or named == "sunplume_mantle":
				_feathered_cloak(b, c, u, s, lod, base_col, named == "sunplume_mantle")
				return
			var cl := Art.smooth(P.call([Vector2(-2.8, -9.2), Vector2(2.8, -9.2), Vector2(5.6, -5.8), Vector2(8.8, 8.6), Vector2(4.0, 9.6),
				Vector2(0, 8.8), Vector2(-4.0, 9.6), Vector2(-8.8, 8.6), Vector2(-5.6, -5.8)]), 3)
			Art.shape(b, cl, base_col, s, "cloth")
			for x in [-4.2, 1.4, 4.8]:
				b.line(c + Vector2(x * 0.4, -5.0) * u, c + Vector2(x, 8.6) * u, Color(dark, 0.6), thin)
			if id == "dusk_cloak":
				for v in [Vector2(-4.6, 3.0), Vector2(3.4, 5.6), Vector2(-1.4, -0.4), Vector2(2.0, 0.8)]:
					Art.spark(b, c + v * u, 1.0 * u, Color(0.88, 0.85, 1.0, 0.9))
			elif id == "travel_cloak":
				Art.shape(b, Art.rrect(Rect2(c + Vector2(2.4, 1.0) * u, Vector2(3.2, 2.8) * u), 0.4 * u, 2), base_col.lightened(0.15), s, "cloth", Art.THIN | Art.NO_RIM)
			if named == "emberkin_mantle":
				for x in [-6.0, -2.0, 2.4, 6.2]:
					b.circle(c + Vector2(x, 9.0) * u, 0.9 * u, Color(1.0, 0.62, 0.25, 0.9), 10)
			Art.orb(b, c + Vector2(0, -7.4) * u, 1.6 * u, Art.GOLD, s, "gold")  # the clasp
		"backpack":
			if id == "herb_pouch":
				_herb_pouch(b, c, u, s, lod, base_col)
			elif id == "bandolier":
				_bandolier(b, c, u, s, lod, base_col)
			else:
				_bag(b, id, c, u, s, lod, base_col)
		"amulet":
			b.arc(c + Vector2(0, -3.0) * u, 6.6 * u, PI * 1.05, TAU - PI * 0.05, 24, Color(Art.INK, 0.8), maxf(1.1, 0.75 * u) + 1.0)
			var cord_col := Color(0.9, 0.8, 0.52) if id != "wolf_tooth" else Color(0.42, 0.28, 0.18)
			b.arc(c + Vector2(0, -3.0) * u, 6.6 * u, PI * 1.05, TAU - PI * 0.05, 24, cord_col, maxf(0.7, 0.6 * u))  # the cord
			if lod > 0 and id != "wolf_tooth":
				for i in 9:  # its links
					var a := PI * 1.1 + i * PI * 0.1
					b.circle(c + Vector2(0, -3.0) * u + Vector2.from_angle(a) * 6.6 * u, maxf(0.35, 0.28 * u), Color(1.0, 0.95, 0.75, 0.6), 6)
			if named == "heartstone":
				var heart := PackedVector2Array()
				for i in 32:
					var t := TAU * i / 32.0
					heart.append(c + Vector2(0, 4.6) * u + Vector2(16.0 * pow(sin(t), 3), -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))) * u * 0.3)
				Art.shape(b, heart, base_col, s, "gem")
				Art.shine(b, c + Vector2(-2.0, 2.6) * u, 0.6 * u, 1.2 * u, -0.6, 0.6)
				Art.orb(b, c + Vector2(0, -0.6) * u, 1.1 * u, Art.GOLD, s, "gold")
			elif named == "wayfinders_pendant":
				# A compass: a brass case, a pale face, a needle that points away from north.
				var cc := c + Vector2(0, 4.6) * u
				Art.orb(b, cc, 5.0 * u, Art.BRASS, s, "gold")
				b.circle(cc, 3.8 * u, Color(0.93, 0.9, 0.8), 20)
				for i in 8:
					var a := TAU * i / 8.0
					b.line(cc + Vector2.from_angle(a) * 3.0 * u, cc + Vector2.from_angle(a) * 3.6 * u, Color(0.3, 0.26, 0.3), maxf(0.4, 0.3 * u))
				var nd := Vector2.from_angle(-0.7)
				b.polygon(PackedVector2Array([cc + nd * 3.2 * u, cc + nd.orthogonal() * 0.8 * u, cc - nd.orthogonal() * 0.8 * u]), Color(0.36, 0.62, 0.9))
				b.polygon(PackedVector2Array([cc - nd * 3.2 * u, cc + nd.orthogonal() * 0.8 * u, cc - nd.orthogonal() * 0.8 * u]), Color(0.86, 0.3, 0.28))
				b.circle(cc, 0.6 * u, Art.GOLD, 10)
				Art.shine(b, cc + Vector2(-1.6, -1.6) * u, 0.6 * u, 1.3 * u, -0.6, 0.45)
				Art.orb(b, c + Vector2(0, -0.6) * u, 1.1 * u, Art.GOLD, s, "gold")
			elif id == "wolf_tooth":
				# A long curved fang on a dark thong, bound with a twist of sinew.
				var fang := Art.smooth(P.call([Vector2(-2.2, 0.6), Vector2(2.4, 0.6), Vector2(2.6, 4.6), Vector2(0.8, 9.0), Vector2(-0.6, 9.8), Vector2(-0.2, 6.2), Vector2(-1.8, 3.4)]), 3)
				Art.shape(b, fang, base_col, s)
				b.line(c + Vector2(1.4, 2.0) * u, c + Vector2(0.6, 7.6) * u, Color(1, 1, 1, 0.55), maxf(0.45, 0.35 * u))
				Art.shape(b, Art.rrect(Rect2(c + Vector2(-2.6, -0.6) * u, Vector2(5.2, 1.8) * u), 0.5 * u, 2), Color(0.42, 0.28, 0.18), s, "leather", Art.THIN | Art.NO_RIM)
			elif id == "sunstone_pendant":
				var gc := c + Vector2(0, 4.6) * u
				Art.soft(b, gc, 8.0 * u, Color(1.0, 0.7, 0.3, 0.5))
				for i in 12:
					var a := TAU * i / 12.0
					b.line(gc + Vector2.from_angle(a) * 4.6 * u, gc + Vector2.from_angle(a) * (6.2 if i % 2 == 0 else 5.4) * u, Color(1.0, 0.82, 0.45, 0.9), maxf(0.5, 0.4 * u))
				Art.orb(b, gc, 4.2 * u, Art.GOLD, s, "gold")
				_facets(b, gc, 3.0 * u, base_col, s, 8)
				Art.orb(b, c + Vector2(0, -0.6) * u, 1.1 * u, Art.GOLD, s, "gold")
			elif id == "bone_charm":
				var tooth := Art.smooth(P.call([Vector2(-2.8, 1.8), Vector2(2.8, 1.8), Vector2(2.0, 5.6), Vector2(0.6, 9.8), Vector2(-1.6, 6.0)]), 3)
				Art.shape(b, tooth, base_col, s)
				Art.orb(b, c + Vector2(0, 1.2) * u, 1.4 * u, Art.GOLD, s, "gold")
			elif id == "tide_locket":
				Art.orb(b, c + Vector2(0, 4.6) * u, 5.0 * u, Art.GOLD, s, "gold")
				var win := Art.oval(c + Vector2(0, 4.6) * u, Vector2(3.6, 3.6) * u)
				Art.glass(b, win, s, base_col, c.y + 3.8 * u)
				Art.shine(b, c + Vector2(-1.4, 2.9) * u, 0.55 * u, 1.1 * u, -0.6, 0.7)
				Art.orb(b, c + Vector2(0, -0.6) * u, 1.1 * u, Art.GOLD, s, "gold")
			else:
				Art.soft(b, c + Vector2(0, 4.6) * u, 7.0 * u, Color(base_col, 0.45))
				Art.orb(b, c + Vector2(0, 4.6) * u, 4.4 * u, Art.GOLD, s, "gold")
				Art.orb(b, c + Vector2(0, 4.6) * u, 3.2 * u, base_col, s, "gem", false)
				Art.orb(b, c + Vector2(0, -0.6) * u, 1.1 * u, Art.GOLD, s, "gold")
		"ring":
			_ring(b, id, c, u, s, lod, base_col, named)
		_:
			Art.orb(b, c, s * 0.5, base_col, s)


## The three leggings, told apart by shape: baggy quilted trousers with
## rolled cuffs, slim laced leather, and straight mail with steel knee cops.
static func _legs(b, id: String, c: Vector2, u: float, s: float, lod: int, col: Color, named := "") -> void:
	var dark := col.darkened(0.45)
	var lit := col.lightened(0.3)
	var thin := maxf(0.55, 0.42 * u)
	match id:
		"ranger_breeches":
			# Loose green breeches tucked at the knee, a patch and a pocket.
			var legs := Art.smooth(Art.pts(c, u, [Vector2(-6.8, -8.6), Vector2(6.8, -8.6), Vector2(8.0, -1.0), Vector2(7.2, 6.4), Vector2(5.4, 9.4), Vector2(1.8, 9.4),
				Vector2(1.2, 4.0), Vector2(0, -0.6), Vector2(-1.2, 4.0), Vector2(-1.8, 9.4), Vector2(-5.4, 9.4), Vector2(-7.2, 6.4), Vector2(-8.0, -1.0)]), 2)
			Art.shape(b, legs, col, s, "cloth")
			for sx in [-1.0, 1.0]:
				Art.shape(b, Art.rrect(Rect2(c + Vector2(sx * 4.0 - 1.8, 1.6) * u, Vector2(3.6, 3.0) * u), 0.8 * u, 2), col.darkened(0.2), s, "cloth", Art.THIN | Art.NO_RIM)
				b.line(c + Vector2(sx * 6.6, 6.0) * u, c + Vector2(sx * 2.0, 6.4) * u, Color(0.42, 0.28, 0.18), maxf(0.7, 0.8 * u))  # the garter
			Art.shape(b, Art.rrect(Rect2(c + Vector2(-6.8, -9.2) * u, Vector2(13.6, 2.0) * u), 0.4 * u, 2), Color(0.42, 0.28, 0.18), s, "leather", Art.THIN | Art.NO_RIM)
			if lod > 0:
				Art.stitches(b, c + Vector2(-6.0, -4.8) * u, c + Vector2(-2.6, -4.8) * u, 3, Color(lit, 0.7), thin * 0.8)
		"plated_greaves":
			if named != "rootbound_greaves":
				var legs := Art.pts(c, u, [Vector2(-6.4, -8.6), Vector2(6.4, -8.6), Vector2(7.0, 9.2), Vector2(1.8, 9.2), Vector2(0.4, -0.8),
					Vector2(-0.4, -0.8), Vector2(-1.8, 9.2), Vector2(-7.0, 9.2)])
				Art.shape(b, legs, Color(0.34, 0.26, 0.22), s, "leather")
			else:
				var legs := Art.smooth(Art.pts(c, u, [Vector2(-6.4, -8.6), Vector2(6.4, -8.6), Vector2(7.0, 9.2), Vector2(1.8, 9.2), Vector2(0.4, -0.8),
					Vector2(-0.4, -0.8), Vector2(-1.8, 9.2), Vector2(-7.0, 9.2)]), 2)
				Art.shape(b, legs, Color(0.44, 0.34, 0.24), s, "wood")
			for sx in [-1.0, 1.0]:
				var shin := Art.smooth(Art.pts(c, u, [Vector2(sx * 1.6, 2.4), Vector2(sx * 6.6, 2.4), Vector2(sx * 6.4, 8.4), Vector2(sx * 4.0, 9.4), Vector2(sx * 1.8, 8.4)]), 2)
				Art.shape(b, shin, col if named == "" else col.lightened(0.1), s, "metal" if named == "" else "wood")
				Art.orb(b, c + Vector2(sx * 4.1, 1.4) * u, 2.2 * u, Art.STEEL if named == "" else Color(0.6, 0.5, 0.36), s, "metal")
				if lod > 0:
					b.line(c + Vector2(sx * 4.1, 3.4) * u, c + Vector2(sx * 4.1, 8.4) * u, Color(1, 1, 1, 0.35), maxf(0.4, 0.3 * u))
			for sx in [-1.0, 1.0]:
				b.line(c + Vector2(sx * 1.4, -3.4) * u, c + Vector2(sx * 6.6, -3.4) * u, Color(0.22, 0.15, 0.1), maxf(0.6, 0.7 * u))  # the straps
			Art.shape(b, Art.rrect(Rect2(c + Vector2(-6.6, -9.2) * u, Vector2(13.2, 2.2) * u), 0.4 * u, 2), Color(0.3, 0.2, 0.14), s, "leather", Art.THIN | Art.NO_RIM)
			if named == "rootbound_greaves":
				var root := Color(0.5, 0.36, 0.22)
				for sx in [-1.0, 1.0]:
					var prev := c + Vector2(sx * 6.2, -7.4) * u
					for k in 8:
						var at := c + Vector2(sx * (4.0 + sin(k * 1.4) * 2.6), -6.0 + k * 2.0) * u
						b.line(prev, at, Art.INK, 1.1 * u + Art.ol(s))
						b.line(prev, at, root, 1.1 * u)
						prev = at
					Art.shape(b, Art.oval(c + Vector2(sx * 6.8, -4.0) * u, Vector2(1.5, 0.8) * u, sx * 0.6, 10), Color(0.45, 0.7, 0.32), s, "", Art.THIN | Art.NO_RIM)
			return
		"padded_trousers":
			var legs := Art.pts(c, u, [Vector2(-7.2, -8.6), Vector2(7.2, -8.6), Vector2(8.4, -2.0), Vector2(9.2, 6.2), Vector2(8.6, 9.2), Vector2(1.6, 9.2),
				Vector2(1.0, 6.0), Vector2(0, -1.0), Vector2(-1.0, 6.0), Vector2(-1.6, 9.2), Vector2(-8.6, 9.2), Vector2(-9.2, 6.2), Vector2(-8.4, -2.0)])
			Art.shape(b, legs, col, s, "cloth")
			for y in [-3.4, 0.6, 4.2]:
				b.line(c + Vector2(-8.4, y) * u, c + Vector2(-1.0, y + 0.3) * u, Color(dark, 0.65), thin)
				b.line(c + Vector2(1.0, y + 0.3) * u, c + Vector2(8.4, y) * u, Color(dark, 0.65), thin)
			for sx in [-1.0, 1.0]:
				var cuff := Art.pts(c, u, [Vector2(sx * 1.4, 6.8), Vector2(sx * 9.2, 6.8), Vector2(sx * 9.0, 9.4), Vector2(sx * 1.6, 9.4)])
				Art.shape(b, cuff, col.lightened(0.12), s, "cloth", Art.THIN | Art.NO_RIM)
			Art.shape(b, Art.rrect(Rect2(c + Vector2(-7.4, -9.2) * u, Vector2(14.8, 2.4) * u), 0.6 * u, 2), col.darkened(0.2), s, "cloth", Art.THIN | Art.NO_RIM)
			b.line(c + Vector2(-0.6, -6.8) * u, c + Vector2(-1.8, -4.4) * u, Color(0.95, 0.9, 0.78), thin)  # the drawstring
			b.line(c + Vector2(0.6, -6.8) * u, c + Vector2(1.6, -4.6) * u, Color(0.95, 0.9, 0.78), thin)
		"leather_leggings":
			var legs := Art.pts(c, u, [Vector2(-6.2, -8.6), Vector2(6.2, -8.6), Vector2(6.8, -2.0), Vector2(5.6, 9.4), Vector2(1.6, 9.4),
				Vector2(0.6, -0.6), Vector2(-0.6, -0.6), Vector2(-1.6, 9.4), Vector2(-5.6, 9.4), Vector2(-6.8, -2.0)])
			Art.shape(b, legs, col, s, "leather")
			for sx in [-1.0, 1.0]:
				b.circle(c + Vector2(sx * 3.6, 3.0) * u, 1.6 * u, Color(dark, 0.45), 14)  # knee patches
				if lod > 0:
					for k in 5:
						var y := -5.0 + k * 3.0
						b.line(c + Vector2(sx * 6.0, y) * u, c + Vector2(sx * 5.8, y + 1.4) * u, Color(lit, 0.6), thin * 0.8)
			Art.shape(b, Art.rrect(Rect2(c + Vector2(-6.4, -9.2) * u, Vector2(12.8, 2.0) * u), 0.4 * u, 2), Color(0.26, 0.17, 0.11), s, "leather", Art.THIN | Art.NO_RIM)
			Art.shape(b, Art.rrect(Rect2(c + Vector2(-1.3, -9.6) * u, Vector2(2.6, 2.8) * u), 0.4 * u, 2), Art.GOLD, s, "gold", Art.THIN | Art.NO_RIM)
			for k in 2:
				var y := -5.4 + k * 2.0
				b.line(c + Vector2(-1.2, y) * u, c + Vector2(1.2, y + 1.4) * u, Color(0.94, 0.88, 0.72), thin)
				b.line(c + Vector2(1.2, y) * u, c + Vector2(-1.2, y + 1.4) * u, Color(0.94, 0.88, 0.72), thin)
		_:
			var legs := Art.pts(c, u, [Vector2(-6.8, -8.6), Vector2(6.8, -8.6), Vector2(7.4, 9.2), Vector2(1.8, 9.2), Vector2(0.4, -0.8),
				Vector2(-0.4, -0.8), Vector2(-1.8, 9.2), Vector2(-7.4, 9.2)])
			Art.shape(b, legs, col, s, "metal")
			var rows := 6 if lod > 0 else 4
			for row in rows:
				for k in 3:
					for sg in [-1.0, 1.0]:
						var x: float = sg * (2.2 + k * 1.9 + (0.9 if row % 2 == 1 else 0.0))
						var y := -5.6 + row * (14.0 / rows)
						if absf(x) > 6.8 + y * 0.03:
							continue
						b.arc(c + Vector2(x, y) * u, 0.8 * u, PI * 0.9, PI * 2.1, 6, Color(dark, 0.85), maxf(0.5, 0.36 * u))
			for sx in [-1.0, 1.0]:
				Art.orb(b, c + Vector2(sx * 4.6, 2.4) * u, 2.3 * u, Art.STEEL, s, "metal")
			Art.shape(b, Art.rrect(Rect2(c + Vector2(-7.0, -9.2) * u, Vector2(14.0, 2.2) * u), 0.4 * u, 2), Color(0.34, 0.24, 0.18), s, "leather", Art.THIN | Art.NO_RIM)


## The three boots, told apart by shape: low slouchy soft boots, laced
## climbing boots on a thick lugged sole, tall iron-shod hobnails.
static func _boots(b, id: String, c: Vector2, u: float, s: float, lod: int, col: Color, named := "") -> void:
	var dark := col.darkened(0.45)
	var lit := col.lightened(0.3)
	var thin := maxf(0.55, 0.42 * u)
	if named == "phantom_treads":
		# Pale wisps trail behind the boot: it leaves no prints.
		for k in 3:
			var y := 1.0 + k * 2.6
			var wisp := Art.smooth(Art.pts(c, u, [Vector2(-6.4, y - 0.7), Vector2(-10.0 + k, y - 0.2), Vector2(-9.0 + k, y + 0.8), Vector2(-6.0, y + 0.6)]), 2)
			b.polygon(wisp, Color(0.82, 0.9, 1.0, 0.55 - k * 0.12))
	match id:
		"wading_boots":
			# Tall oiled boots up to the thigh, a strap at the top, water beading off.
			var boot := Art.smooth(Art.pts(c, u, [Vector2(-5.4, -9.6), Vector2(2.0, -9.6), Vector2(2.6, 0.8), Vector2(7.4, 3.0), Vector2(9.4, 6.0),
				Vector2(9.0, 8.8), Vector2(-6.0, 8.8), Vector2(-6.2, -2.0)]), 2)
			Art.shape(b, boot, col, s, "leather")
			Art.shape(b, Art.rrect(Rect2(c + Vector2(-6.0, -9.8) * u, Vector2(8.6, 2.4) * u), 0.6 * u, 2), col.darkened(0.25), s, "leather", Art.THIN)
			Art.shape(b, Art.rrect(Rect2(c + Vector2(-1.4, -9.6) * u, Vector2(2.2, 2.0) * u), 0.3 * u, 2), Art.STEEL, s, "metal", Art.THIN | Art.NO_RIM)
			b.line(c + Vector2(-5.8, 8.6) * u, c + Vector2(8.8, 8.6) * u, Color(dark, 0.9), maxf(0.7, 0.8 * u))
			b.line(c + Vector2(-4.4, -6.0) * u, c + Vector2(-4.8, 5.0) * u, Color(lit, 0.45), thin * 1.4)  # the oiled shine
			for v in [Vector2(4.8, 1.0), Vector2(-7.4, 2.6), Vector2(7.6, -1.6)]:
				var dc: Vector2 = c + v * u
				var drop := PackedVector2Array([dc + Vector2(0, -1.4) * u, dc + Vector2(0.8, 0.2) * u, dc + Vector2(0, 0.9) * u, dc + Vector2(-0.8, 0.2) * u])
				b.polygon(drop, Color(0.6, 0.85, 1.0, 0.9))
			return
		"soft_boots":
			var boot := Art.smooth(Art.pts(c, u, [Vector2(-5.4, -3.6), Vector2(2.0, -4.2), Vector2(2.6, 1.6), Vector2(7.6, 3.4), Vector2(9.4, 6.4),
				Vector2(8.6, 8.8), Vector2(-6.0, 8.8), Vector2(-6.2, 2.0)]), 3)
			Art.shape(b, boot, col, s, "leather")
			var fold := Art.smooth(Art.pts(c, u, [Vector2(-6.4, -5.6), Vector2(-2.0, -4.8), Vector2(3.0, -6.0), Vector2(2.8, -2.6), Vector2(-2.0, -1.8), Vector2(-6.0, -2.4)]), 3)
			Art.shape(b, fold, col.lightened(0.15), s, "leather", Art.THIN)
			b.line(c + Vector2(-5.6, 8.6) * u, c + Vector2(8.6, 8.6) * u, Color(dark, 0.9), maxf(0.7, 0.8 * u))
			if lod > 0:
				b.line(c + Vector2(-3.0, 1.0) * u, c + Vector2(1.0, 0.4) * u, Color(dark, 0.5), thin)
		"climbing_boots":
			var boot := Art.pts(c, u, [Vector2(-5.8, -8.8), Vector2(1.6, -8.8), Vector2(1.8, 0.6), Vector2(7.2, 2.4), Vector2(9.2, 5.2),
				Vector2(9.2, 6.8), Vector2(-6.4, 6.8)])
			Art.shape(b, boot, col, s, "leather")
			var sole := PackedVector2Array([c + Vector2(-6.8, 6.6) * u, c + Vector2(9.6, 6.6) * u, c + Vector2(9.6, 8.4) * u])
			for k in 9:
				var x := 9.6 - k * 2.05
				sole.append(c + Vector2(x - 1.0, 9.6 if k % 2 == 0 else 8.4) * u)
			sole.append(c + Vector2(-6.8, 8.4) * u)
			Art.shape(b, sole, Color(0.3, 0.26, 0.24), s, "", Art.THIN | Art.NO_RIM)
			for k in 4:
				var y := -6.6 + k * 2.2
				b.line(c + Vector2(-1.2, y) * u, c + Vector2(1.8, y + 1.0) * u, Color(0.95, 0.9, 0.74), thin)
				b.line(c + Vector2(1.8, y) * u, c + Vector2(-1.2, y + 1.0) * u, Color(0.95, 0.9, 0.74), thin)
			Art.shape(b, Art.rrect(Rect2(c + Vector2(-6.0, -9.4) * u, Vector2(8.0, 1.8) * u), 0.5 * u, 2), col.lightened(0.15), s, "leather", Art.THIN | Art.NO_RIM)
		_:
			var boot := Art.pts(c, u, [Vector2(-6.6, -9.4), Vector2(2.6, -9.4), Vector2(2.6, -0.2), Vector2(7.8, 1.2), Vector2(9.4, 3.6),
				Vector2(9.4, 7.8), Vector2(-7.0, 7.8)])
			Art.shape(b, boot, col, s, "leather")
			var cap := Art.pts(c, u, [Vector2(3.6, 1.0), Vector2(7.8, 1.2), Vector2(9.4, 3.6), Vector2(9.4, 7.8), Vector2(4.4, 7.8)])
			Art.shape(b, cap, Art.IRON, s, "metal", Art.THIN)
			Art.shape(b, Art.rrect(Rect2(c + Vector2(-6.8, -4.4) * u, Vector2(9.6, 1.8) * u), 0.3 * u, 2), dark.lightened(0.1), s, "leather", Art.THIN | Art.NO_RIM)
			Art.shape(b, Art.rrect(Rect2(c + Vector2(-1.0, -5.0) * u, Vector2(2.6, 3.0) * u), 0.3 * u, 2), Art.STEEL, s, "metal", Art.THIN | Art.NO_RIM)
			b.rect(Rect2(c + Vector2(-7.0, 7.4) * u, Vector2(16.4, 1.2) * u), Color(0.2, 0.17, 0.18))
			for k in 6:
				Art.orb(b, c + Vector2(-5.4 + k * 2.8, 9.0) * u, 0.85 * u, Art.STEEL, s, "metal")
			b.line(c + Vector2(-5.0, -8.4) * u, c + Vector2(-5.4, 5.6) * u, Color(lit, 0.35), thin)


## A cut stone seen face on: `n` facets round `c`, each lit by how it faces
## the light, outlined, with a glint.
static func _facets(b, c: Vector2, r: float, col: Color, s: float, n := 6) -> void:
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
	b.polygon(Art.oval(c, Vector2(r * 0.42, r * 0.42), 0.0, n), col.lightened(0.12))
	b.circle(c + l * r * 0.45, maxf(0.4, r * 0.18), Color(1, 1, 1, 0.8), 8)


## Archer's Bracers: a laced leather cuff for the forearm and a thumb loop.
static func _bracers(b, c: Vector2, u: float, s: float, lod: int, col: Color) -> void:
	var cuff := Art.smooth(Art.pts(c, u, [Vector2(-6.4, -8.4), Vector2(5.0, -9.2), Vector2(6.2, 1.0), Vector2(5.0, 8.8), Vector2(-4.2, 9.4), Vector2(-6.8, 0.6)]), 2)
	Art.shape(b, cuff, col, s, "leather")
	var guard := Art.smooth(Art.pts(c, u, [Vector2(-3.6, -7.0), Vector2(2.8, -7.4), Vector2(3.4, 6.8), Vector2(-2.6, 7.2)]), 2)
	Art.shape(b, guard, col.darkened(0.22), s, "leather", Art.THIN)
	var lace := Color(0.95, 0.88, 0.7)
	for k in 5:
		var y := -5.6 + k * 2.6
		b.line(c + Vector2(-2.4, y) * u, c + Vector2(2.2, y + 1.3) * u, lace, maxf(0.5, 0.42 * u))
		b.line(c + Vector2(2.2, y) * u, c + Vector2(-2.4, y + 1.3) * u, lace, maxf(0.5, 0.42 * u))
	if lod > 0:
		for sx in [-1.0, 1.0]:
			Art.stitches(b, c + Vector2(sx * 5.4, -7.4) * u, c + Vector2(sx * 5.2, 7.6) * u, 6, Color(col.lightened(0.4), 0.6), maxf(0.4, 0.3 * u))
	Art.rivet(b, c + Vector2(-5.6, 0.8) * u, 0.7 * u, Art.BRASS)
	Art.rivet(b, c + Vector2(5.4, 0.8) * u, 0.7 * u, Art.BRASS)


## A cloak of feathers: rows of overlapping plumes, the Feather Cape's grey,
## or the Firebird's plumes glowing from gold to flame.
static func _feathered_cloak(b, c: Vector2, u: float, s: float, lod: int, col: Color, fire: bool) -> void:
	var cl := Art.smooth(Art.pts(c, u, [Vector2(-2.8, -9.2), Vector2(2.8, -9.2), Vector2(5.8, -5.6), Vector2(8.6, 5.0), Vector2(4.0, 7.0),
		Vector2(0, 6.0), Vector2(-4.0, 7.0), Vector2(-8.6, 5.0), Vector2(-5.8, -5.6)]), 3)
	if fire:
		Art.soft(b, c + Vector2(0, 2.0) * u, 11.0 * u, Color(1.0, 0.55, 0.2, 0.45))
	Art.shape(b, cl, col.darkened(0.2), s, "cloth")
	var rows := [[-4.2, 3, 4.4], [-0.6, 4, 6.2], [3.0, 5, 7.8], [6.4, 5, 8.6]]
	for ri in rows.size():
		var y: float = rows[ri][0]
		var n: int = rows[ri][1]
		var half: float = rows[ri][2]
		for k in n:
			var x := -half + (k + 0.5) * (2.0 * half / n)
			var tip := c + Vector2(x, y + 3.6) * u
			var fc := col.lerp(Color(1.0, 0.85, 0.4), 0.15 * ri) if fire else col.lightened(0.05 * ri + (0.08 if (k + ri) % 2 == 0 else 0.0))
			if fire and ri == rows.size() - 1:
				fc = Color(1.0, 0.82, 0.4)
			var pl := Art.smooth(Art.pts(c, u, [Vector2(x - 1.3, y - 0.4), Vector2(x + 1.3, y - 0.4), Vector2(x + 1.0, y + 2.6), Vector2(x, y + 4.4), Vector2(x - 1.0, y + 2.6)]), 2)
			Art.shape(b, pl, fc, s, "cloth", Art.THIN | Art.NO_RIM)
			b.polygon(PackedVector2Array([c + Vector2(x - 0.7, y + 3.2) * u, c + Vector2(x, y + 4.4) * u, c + Vector2(x + 0.7, y + 3.2) * u]),
				Color(1.0, 0.95, 0.7) if fire else fc.darkened(0.5))  # the barred tip
			if lod > 0:
				b.line(c + Vector2(x, y + 0.3) * u, tip, Color(fc.lightened(0.4), 0.7), maxf(0.4, 0.28 * u))
	if fire:
		for x in [-5.6, -1.6, 2.4, 6.0]:
			Art.spark(b, c + Vector2(x, 10.2) * u, 1.1 * u, Color(1.0, 0.78, 0.3, 0.95))
	var collar := Art.smooth(Art.pts(c, u, [Vector2(-4.6, -9.4), Vector2(4.6, -9.4), Vector2(5.4, -6.6), Vector2(0, -5.6), Vector2(-5.4, -6.6)]), 2)
	Art.shape(b, collar, col.darkened(0.35) if not fire else Color(0.62, 0.2, 0.12), s, "cloth", Art.THIN)
	Art.orb(b, c + Vector2(0, -7.4) * u, 1.6 * u, Art.GOLD if not fire else Color(1.0, 0.6, 0.25), s, "gold")


## A Herb Pouch: a drawstring bag, sprigs of green and a red flower peeking out.
static func _herb_pouch(b, c: Vector2, u: float, s: float, lod: int, col: Color) -> void:
	for v in [[Vector2(-2.4, -3.0), Vector2(-5.2, -9.2)], [Vector2(0.4, -3.0), Vector2(1.0, -9.8)], [Vector2(2.6, -3.0), Vector2(5.8, -8.2)]]:
		b.line(c + v[0] * u, c + v[1] * u, Art.INK, 0.9 * u + Art.ol(s))
		b.line(c + v[0] * u, c + v[1] * u, Color(0.4, 0.62, 0.28), 0.9 * u)
		var lf := Art.oval(c + v[1] * u, Vector2(1.6, 0.9) * u, (v[1] - v[0]).angle(), 10)
		Art.shape(b, lf, Color(0.48, 0.72, 0.34), s, "", Art.THIN | Art.NO_RIM)
	Art.orb(b, c + Vector2(1.0, -9.8) * u, 1.1 * u, Color(0.88, 0.32, 0.36), s, "")
	var bag := Art.smooth(Art.pts(c, u, [Vector2(-4.0, -3.0), Vector2(4.0, -3.0), Vector2(7.2, 3.2), Vector2(6.0, 8.6), Vector2(-6.0, 8.6), Vector2(-7.2, 3.2)]), 3)
	Art.shape(b, bag, col, s, "cloth")
	Art.shape(b, Art.rrect(Rect2(c + Vector2(-4.6, -3.8) * u, Vector2(9.2, 2.0) * u), 0.8 * u, 2), col.darkened(0.2), s, "cloth", Art.THIN | Art.NO_RIM)
	b.line(c + Vector2(3.6, -2.8) * u, c + Vector2(5.6, 0.8) * u, Color(0.92, 0.84, 0.64), maxf(0.5, 0.45 * u))  # the drawstring
	Art.orb(b, c + Vector2(5.8, 1.2) * u, 0.7 * u, Color(0.92, 0.84, 0.64), s, "")
	if lod > 0:
		b.line(c + Vector2(-4.0, 1.0) * u, c + Vector2(-3.4, 7.0) * u, Color(col.darkened(0.4), 0.55), maxf(0.4, 0.35 * u))
		b.line(c + Vector2(0.6, 0.6) * u, c + Vector2(0.4, 7.4) * u, Color(col.darkened(0.4), 0.55), maxf(0.4, 0.35 * u))


## A Bandolier: a crossed belt with a buckle, little pouches and loops for vials.
static func _bandolier(b, c: Vector2, u: float, s: float, lod: int, col: Color) -> void:
	var a := c + Vector2(-8.4, -7.4) * u
	var e := c + Vector2(8.0, 8.0) * u
	var side := (e - a).normalized().orthogonal()
	var strap := PackedVector2Array([a + side * 2.2 * u, e + side * 2.2 * u, e - side * 2.2 * u, a - side * 2.2 * u])
	Art.shape(b, strap, col, s, "leather")
	if lod > 0:
		Art.stitches(b, a + side * 1.5 * u, e + side * 1.5 * u, 9, Color(col.lightened(0.45), 0.6), maxf(0.4, 0.3 * u))
		Art.stitches(b, a - side * 1.5 * u, e - side * 1.5 * u, 9, Color(col.lightened(0.45), 0.6), maxf(0.4, 0.3 * u))
	var vials := [Color(0.9, 0.3, 0.32), Color(0.45, 0.85, 0.5), Color(0.55, 0.75, 1.0)]
	for k in 3:
		var at := a.lerp(e, 0.18 + k * 0.13) + side * 2.2 * u
		var body := Art.rrect(Rect2(at - Vector2(1.0, 3.4) * u, Vector2(2.0, 3.6) * u), 0.9 * u, 3)
		Art.glass(b, body, s, vials[k], at.y - 2.0 * u)
	for k in 2:
		var at := a.lerp(e, 0.66 + k * 0.17)
		var pouch := Art.rrect(Rect2(at - Vector2(2.4, 1.0) * u, Vector2(4.8, 4.2) * u), 0.9 * u, 3)
		Art.shape(b, pouch, col.darkened(0.12), s, "leather", Art.THIN)
		Art.shape(b, Art.rrect(Rect2(at - Vector2(2.6, 1.2) * u, Vector2(5.2, 1.8) * u), 0.6 * u, 2), col.darkened(0.25), s, "leather", Art.THIN | Art.NO_RIM)
		Art.rivet(b, at + Vector2(0, 0.6) * u, 0.5 * u, Art.BRASS)
	var bk := a.lerp(e, 0.5)
	Art.shape(b, Art.rrect(Rect2(bk - Vector2(2.0, 2.0) * u, Vector2(4.0, 4.0) * u), 0.6 * u, 2), Art.BRASS, s, "gold", Art.THIN)
	b.rect(Rect2(bk - Vector2(1.0, 1.0) * u, Vector2(2.0, 2.0) * u), col.darkened(0.3))


## The bags: a satchel on a long strap, a small pouch on a belt, and the
## climber's pack with a bedroll strapped on top.
static func _bag(b, id: String, c: Vector2, u: float, s: float, lod: int, col: Color) -> void:
	var big := id in ["satchel", "climbers_pack"]
	var hw := 7.6 if big else 5.4
	var top := -4.0 if big else -1.6
	if id == "satchel":
		b.arc(c + Vector2(0, top) * u, 6.6 * u, PI, TAU, 20, Art.INK, 1.9 * u + Art.ol(s))
		b.arc(c + Vector2(0, top) * u, 6.6 * u, PI, TAU, 20, col.darkened(0.3), 1.3 * u)  # the long strap
	elif id == "climbers_pack":
		Art.rod(b, c + Vector2(-hw + 0.6, top - 1.8) * u, c + Vector2(hw - 0.6, top - 1.8) * u, 3.0 * u, Color(0.68, 0.32, 0.26), s, "cloth")  # the bedroll
		b.line(c + Vector2(-3.4, top - 3.4) * u, c + Vector2(-3.4, top - 0.2) * u, Color(0.25, 0.18, 0.12), maxf(0.6, 0.6 * u))
		b.line(c + Vector2(3.4, top - 3.4) * u, c + Vector2(3.4, top - 0.2) * u, Color(0.25, 0.18, 0.12), maxf(0.6, 0.6 * u))
	else:
		b.arc(c + Vector2(0, top) * u, 3.8 * u, PI, TAU, 14, Art.INK, 1.6 * u + Art.ol(s))
		b.arc(c + Vector2(0, top) * u, 3.8 * u, PI, TAU, 14, col.darkened(0.3), 1.0 * u)
	var bag := Art.rrect(Rect2(c + Vector2(-hw, top) * u, Vector2(hw * 2.0, 9.0 - top) * u), 1.6 * u, 4)
	Art.shape(b, bag, col, s, "leather")
	if id == "climbers_pack":
		for sx in [-1.0, 1.0]:
			var pk := Art.rrect(Rect2(c + Vector2(sx * hw - (2.2 if sx > 0 else 0.6), 2.6) * u, Vector2(2.8, 5.0) * u), 0.6 * u, 2)
			Art.shape(b, pk, col.darkened(0.12), s, "leather", Art.THIN | Art.NO_RIM)
	var flap := Art.pts(c, u, [Vector2(-hw - 0.2, top - 0.4), Vector2(hw + 0.2, top - 0.4), Vector2(hw, top + 5.0), Vector2(0, top + 6.0), Vector2(-hw, top + 5.0)])
	Art.shape(b, flap, col.darkened(0.18), s, "leather", Art.THIN)
	Art.shape(b, Art.rrect(Rect2(c + Vector2(-1.1, top + 4.4) * u, Vector2(2.2, 2.4) * u), 0.4 * u, 2), Art.GOLD, s, "gold", Art.THIN | Art.NO_RIM)
	if lod > 0:
		var st := PackedVector2Array([c + Vector2(-hw + 1.0, top + 4.0) * u, c + Vector2(0, top + 4.9) * u, c + Vector2(hw - 1.0, top + 4.0) * u])
		for i in 2:
			b.line(st[i], st[i + 1], Color(col.lightened(0.35), 0.5), maxf(0.5, 0.3 * u))
	if id == "belt_pouch":
		Art.shape(b, Art.rrect(Rect2(c + Vector2(-9.4, 2.6) * u, Vector2(18.8, 1.8) * u), 0.4 * u, 2), Color(0.3, 0.2, 0.13), s, "leather", Art.THIN | Art.NO_RIM)
		Art.shape(b, Art.rrect(Rect2(c + Vector2(6.0, 2.2) * u, Vector2(2.6, 2.6) * u), 0.3 * u, 2), Art.GOLD, s, "gold", Art.THIN | Art.NO_RIM)


## The five rings, told apart at a glance: a thick plain iron band, a gold
## band with a cut garnet, a silver band holding a big pearl, a scorched
## copper band with a crown of flame, and three braided wires (the
## Spellweave Ring).
static func _ring(b, id: String, c: Vector2, u: float, s: float, lod: int, col: Color, named: String) -> void:
	var rc := c + Vector2(0, 2.2) * u
	match id:
		"jade_ring":
			# A thick band carved from one piece of jade, with a cloud in the stone.
			_band(b, rc, Vector2(6.6, 5.8) * u, 2.9 * u, col, s, "gem")
			if lod > 0:
				b.arc(rc, 5.2 * u, PI * 1.15, PI * 1.5, 6, Color(0.85, 1.0, 0.9, 0.5), maxf(0.5, 0.5 * u))
				b.circle(rc + Vector2(4.6, 2.4) * u, 0.7 * u, Color(0.2, 0.45, 0.3, 0.6), 8)
		"silver_ring":
			_band(b, rc, Vector2(6.0, 5.2) * u, 1.4 * u, col, s, "metal")
			if named == "duelists_ring":
				# Two tiny crossed blades over a red stone.
				for sg in [-1.0, 1.0]:
					b.line(rc + Vector2(sg * 3.2, -9.6) * u, rc + Vector2(-sg * 2.4, -4.4) * u, Art.INK, 0.9 * u + Art.ol(s))
					b.line(rc + Vector2(sg * 3.2, -9.6) * u, rc + Vector2(-sg * 2.4, -4.4) * u, Art.STEEL, 0.75 * u)
				_facets(b, rc + Vector2(0, -6.8) * u, 2.2 * u, Color(0.86, 0.22, 0.26), s, 6)
			else:
				Art.shape(b, Art.pts(rc, u, [Vector2(-1.8, -4.6), Vector2(1.8, -4.6), Vector2(1.2, -6.2), Vector2(-1.2, -6.2)]), col, s, "metal", Art.THIN | Art.NO_RIM)
				_facets(b, rc + Vector2(0, -7.4) * u, 2.0 * u, Color(0.36, 0.56, 0.95), s, 6)
		"viper_ring":
			# A serpent coiled into a ring, head raised, two emerald eyes.
			_band(b, rc, Vector2(6.0, 5.2) * u, 1.9 * u, col, s, "metal")
			if lod > 0:
				for i in 10:
					var a := TAU * i / 10.0
					b.circle(rc + Vector2(cos(a) * 5.1, sin(a) * 4.3) * u, 0.35 * u, Color(col.darkened(0.45), 0.8), 6)
			var head := Art.smooth(Art.pts(rc, u, [Vector2(-1.2, -4.6), Vector2(-2.2, -7.2), Vector2(0, -9.4), Vector2(2.2, -7.2), Vector2(1.2, -4.6)]), 2)
			Art.shape(b, head, col, s, "metal", Art.THIN)
			for sx in [-1.0, 1.0]:
				b.circle(rc + Vector2(sx * 0.9, -7.6) * u, 0.55 * u, Color(0.3, 1.0, 0.5), 8)
			b.line(rc + Vector2(0, -9.4) * u, rc + Vector2(0.6, -10.8) * u, Color(0.9, 0.3, 0.3), maxf(0.4, 0.3 * u))
		"iron_band":
			_band(b, rc, Vector2(6.4, 5.6) * u, 2.6 * u, Art.IRON.lightened(0.15), s, "metal")
			if lod > 0:
				for a in [PI * 0.25, PI * 0.5, PI * 0.75]:
					b.circle(rc + Vector2(cos(a) * 6.4, sin(a) * 5.6) * u * 0.8, 0.45 * u, Color(Art.INK, 0.6), 8)
		"pearl_ring":
			_band(b, rc, Vector2(6.0, 5.2) * u, 1.3 * u, Art.STEEL, s, "metal")
			Art.shape(b, Art.pts(rc, u, [Vector2(-2.2, -4.6), Vector2(2.2, -4.6), Vector2(1.4, -6.4), Vector2(-1.4, -6.4)]), Art.STEEL, s, "metal", Art.THIN | Art.NO_RIM)
			Art.orb(b, rc + Vector2(0, -8.6) * u, 3.0 * u, col, s, "gem")
			b.circle(rc + Vector2(0.8, -7.6) * u, 1.2 * u, Color(1.0, 0.8, 0.88, 0.35), 12)
		"overdrawn_ring":
			Art.soft(b, rc + Vector2(0, -5.6) * u, 5.0 * u, Color(1.0, 0.55, 0.2, 0.5))
			var crown := PackedVector2Array()
			for i in 9:
				var x := -3.6 + i * 0.9
				crown.append(rc + Vector2(x, -5.0 - (3.8 if i % 2 == 0 else 1.6) * (1.0 - absf(x) / 6.0)) * u)
			crown.append(rc + Vector2(3.6, -4.4) * u)
			crown.append(rc + Vector2(-3.6, -4.4) * u)
			Art.shape(b, crown, Color(1.0, 0.56, 0.22), s, "", Art.THIN | Art.NO_RIM)
			_band(b, rc, Vector2(6.2, 5.4) * u, 1.9 * u, col.darkened(0.15), s, "gold")
			if lod > 0:
				for a in [PI * 0.3, PI * 0.62]:
					b.circle(rc + Vector2(cos(a) * 6.2, sin(a) * 5.4) * u, 0.9 * u, Color(0.12, 0.08, 0.08, 0.6), 10)
		_:
			if named == "spellweave_ring":
				for k in 3:
					var ph := TAU * k / 3.0
					var strand := PackedVector2Array()
					for i in 41:
						var a := TAU * i / 40.0
						var off := sin(a * 6.0 + ph) * 0.9
						strand.append(rc + Vector2(cos(a) * (6.0 + off), sin(a) * (5.2 + off)) * u)
					var wc := col if k != 1 else Art.GOLD
					for i in 40:
						b.line(strand[i], strand[i + 1], Art.INK, 0.9 * u + Art.ol(s) * 1.4)
					for i in 40:
						var f := Vector2.from_angle(TAU * (i + 0.5) / 40.0).dot(-Art.LIGHT.normalized())
						b.line(strand[i], strand[i + 1], wc.lerp(wc.darkened(0.4), clampf(f * 0.5 + 0.5, 0.0, 1.0)), 0.9 * u)
				Art.orb(b, rc + Vector2(0, -5.4) * u, 1.6 * u, col.lightened(0.2), s, "gem")
			else:
				_band(b, rc, Vector2(6.0, 5.2) * u, 1.5 * u, Art.GOLD, s, "gold")
				for sx in [-1.0, 1.0]:
					b.line(rc + Vector2(sx * 1.6, -4.6) * u, rc + Vector2(sx * 2.4, -7.4) * u, Art.INK, 0.8 * u + Art.ol(s))
					b.line(rc + Vector2(sx * 1.6, -4.6) * u, rc + Vector2(sx * 2.4, -7.4) * u, Art.GOLD, 0.8 * u)
				var gem := PackedVector2Array()
				for i in 6:
					gem.append(rc + Vector2(0, -7.6) * u + Vector2.from_angle(-PI / 2.0 + TAU * i / 6.0) * 3.0 * u)
				Art.outline(b, gem, s)
				var l := Art.LIGHT.normalized()
				var gc := rc + Vector2(0, -7.6) * u
				for i in 6:
					var a := gem[i]
					var e := gem[(i + 1) % 6]
					var lit := ((a + e) * 0.5 - gc).normalized().dot(l)
					b.polygon(PackedVector2Array([gc, a, e]), col.lightened(0.35 * lit) if lit > 0.0 else col.darkened(-0.4 * lit))
				b.polygon(PackedVector2Array([gc + Vector2(-1.3, -0.6) * u, gc + Vector2(0, -2.0) * u, gc + Vector2(0.3, -0.5) * u]), Color(1, 1, 1, 0.6))


## A ring's band seen face on: an oval band `w` thick round `c` with outer
## radii `rad`, its metal lit facet by facet from the top-left, outlined
## inside and out.
static func _band(b, c: Vector2, rad: Vector2, w: float, col: Color, s: float, kind: String) -> void:
	var n := 40
	var o := Art.ol(s)
	var r := Art.ramp(col, kind)
	var l := Art.LIGHT.normalized()
	var inner := rad - Vector2(w, w)
	var outer_pts := Art.oval(c, rad, 0.0, n)
	var inner_pts := Art.oval(c, inner, 0.0, n)
	Art._ring(b, outer_pts, Color(Art.INK, Art.FEATHER), o * 2.0 + 1.1)
	Art._ring(b, outer_pts, Art.INK, o * 2.0)
	Art._ring(b, inner_pts, Art.INK, o * 2.0)
	for i in n:
		var j := (i + 1) % n
		var nrm := Vector2.from_angle(TAU * (i + 0.5) / n)
		var f := nrm.dot(l)
		# The outer half of the band faces out (lit at the top-left), the
		# inner half faces in (lit at the lower right).
		var mo := outer_pts[i].lerp(inner_pts[i], 0.5)
		var mo2 := outer_pts[j].lerp(inner_pts[j], 0.5)
		var c_out := col.lerp(r[3], f) if f > 0.0 else col.lerp(r[1], -f)
		var c_in := col.lerp(r[1], f) if f > 0.0 else col.lerp(r[3], -f * 0.6)
		b.pts.append_array([outer_pts[i], outer_pts[j], mo2, outer_pts[i], mo2, mo])
		b.cols.append_array([c_out, c_out, col, c_out, col, col])
		b.pts.append_array([mo, mo2, inner_pts[j], mo, inner_pts[j], inner_pts[i]])
		b.cols.append_array([col, col, c_in, col, c_in, c_in])
	var sh := PackedVector2Array()
	for i in 9:
		var a := lerpf(PI * 1.05, PI * 1.45, i / 8.0)
		sh.append(c + Vector2(cos(a) * (rad.x - w * 0.3), sin(a) * (rad.y - w * 0.3)))
	for i in 8:
		b.line(sh[i], sh[i + 1], r[4], maxf(0.5, w * 0.25))
