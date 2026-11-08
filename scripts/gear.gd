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
const SLOT_NAMES := {
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
## "Regarded" pieces (the beasts' own weapons) come later.
const RARITY_ORDER := ["common", "fine", "rare", "storied", "regarded"]
const RARITIES := {
	"common": {"name": "Common", "color": Color(0.9, 0.86, 0.76), "wears": true, "traits": 0, "boost": 0.0},
	"fine": {"name": "Fine", "color": Color(0.55, 0.85, 0.5), "wears": false, "traits": 1, "boost": 0.05},
	"rare": {"name": "Rare", "color": Color(0.45, 0.65, 1.0), "wears": false, "traits": 2, "boost": 0.10},
	"storied": {"name": "Storied", "color": Color(0.95, 0.7, 0.3), "wears": false, "traits": 1, "boost": 0.12},
	"regarded": {"name": "Regarded", "color": Color(1.0, 0.84, 0.35), "wears": false, "traits": 0, "boost": 0.15},
}

## How rare a piece is, by floor (slain monsters). Vaults, caches and camps
## roll one row higher (the last row is only reached that way). Storied
## pieces are only found from STORIED_FROM up; below it they count as Rare.
const RARITY_ODDS := [
	{"to": 3, "odds": {"common": 80, "fine": 20, "rare": 0, "storied": 0}},
	{"to": 6, "odds": {"common": 60, "fine": 32, "rare": 8, "storied": 0}},
	{"to": 9, "odds": {"common": 45, "fine": 38, "rare": 15, "storied": 2}},
	{"to": 12, "odds": {"common": 35, "fine": 40, "rare": 20, "storied": 5}},
	{"to": 99, "odds": {"common": 25, "fine": 40, "rare": 27, "storied": 8}},
]
const STORIED_FROM := 7
## A Rare find in a tower with its own pieces (NAMED "tower") is one of
## them this often.
const TOWER_PIECE_CHANCE := 0.3
## Finds of this rarity or better fade in a short notice on the HUD.
const NOTICE_FROM := "rare"

## Traits: every one belongs to an essence kind (its colour; later the bench
## tempers it with that kind's crystals) and rolls only on the slots listed.
## "fine" is its strength on a Fine piece, "rare" on Rare and better. "key"
## is the number it adds to (see PIECES and EFFECT_ROWS); "desc" says it.
const TRAIT_ORDER := ["vigor", "footing", "edges", "riposte", "breath", "second_wind", "thorns", "wind", "rolling", "hunt", "kindling", "embers", "well", "calm"]
const TRAITS := {
	"vigor": {"name": "of Vigor", "short": "Vigor", "kind": "stone", "key": "health", "fine": 6.0, "rare": 10.0,
		"slots": ["helm", "armor", "legs", "cloak", "amulet"], "desc": "+%s health"},
	"footing": {"name": "of Footing", "short": "Footing", "kind": "stone", "key": "footing", "fine": 0.15, "rare": 0.25,
		"slots": ["boots", "legs"], "desc": "traps and burning floor hurt %s less"},
	"edges": {"name": "of Edges", "short": "Edges", "kind": "blade", "key": "strike", "fine": 0.03, "rare": 0.05,
		"slots": ["melee", "gloves", "ring"], "desc": "strikes hit %s harder"},
	"riposte": {"name": "of the Riposte", "short": "Riposte", "kind": "blade", "key": "riposte", "fine": 0.08, "rare": 0.12,
		"slots": ["melee", "gloves"], "desc": "ripostes and backstabs hit %s harder"},
	"breath": {"name": "of Breath", "short": "Breath", "kind": "iron", "key": "stamina", "fine": 8.0, "rare": 12.0,
		"slots": ["legs", "armor", "cloak"], "desc": "+%s max stamina"},
	"second_wind": {"name": "of Second Wind", "short": "Second Wind", "kind": "iron", "key": "regen", "fine": 0.04, "rare": 0.06,
		"slots": ["ring", "amulet", "armor"], "desc": "stamina refills %s faster"},
	"thorns": {"name": "of Thorns", "short": "Thorns", "kind": "iron", "key": "thorns", "fine": 3.0, "rare": 5.0,
		"slots": ["armor", "gloves"], "desc": "foes that strike you up close take %s damage"},
	"wind": {"name": "of the Wind", "short": "Wind", "kind": "air", "key": "walk", "fine": 0.02, "rare": 0.03,
		"slots": ["boots", "cloak", "legs"], "desc": "you walk %s faster"},
	"rolling": {"name": "of Rolling", "short": "Rolling", "kind": "air", "key": "roll_cost", "fine": 0.05, "rare": 0.08,
		"slots": ["boots", "legs"], "desc": "rolls cost %s less stamina"},
	"hunt": {"name": "of the Hunt", "short": "Hunt", "kind": "air", "key": "ranged", "fine": 0.05, "rare": 0.08,
		"slots": ["ranged", "gloves", "helm"], "desc": "bows and crossbows hit %s harder"},
	"kindling": {"name": "of Kindling", "short": "Kindling", "kind": "fire", "key": "spell", "fine": 0.04, "rare": 0.06,
		"slots": ["amulet", "ring", "helm"], "desc": "spells hit %s harder"},
	"embers": {"name": "of Embers", "short": "Embers", "kind": "fire", "key": "embers", "fine": 0.10, "rare": 0.15,
		"slots": ["melee", "gloves"], "desc": "strikes have a %s chance to set the foe burning"},
	"well": {"name": "of the Well", "short": "Well", "kind": "water", "key": "fill", "fine": 0.04, "rare": 0.06,
		"slots": ["amulet", "ring", "helm"], "desc": "marks fill %s faster"},
	"calm": {"name": "of Calm", "short": "Calm", "kind": "water", "key": "parry", "fine": 0.05, "rare": 0.08,
		"slots": ["gloves", "helm", "ring"], "desc": "the parry window is %s longer"},
}
## Tempering (the bench): each rank adds this share of a trait's base
## strength, and makes a weapon hit this much harder.
const RANK_TRAIT := 0.25
const RANK_WEAPON := 0.04
const MAX_RANK := 3

## Lasting runes: a Rune Artist inscribes one on a piece at the bench, and
## it stays on it. Half the strength of the Inscribe spell's runes (bond.gd
## GEAR_RUNES): "key" is the number it adds to (as a trait does), "value"
## how much. Drawn on the piece's icon as a rune hashed from its id.
const LASTING_RUNES := {
	"sharpness": {"name": "Rune of Sharpness", "short": "Sharpness", "key": "strike", "value": 0.10,
		"desc": "strikes hit %s harder", "color": Color(1.0, 0.7, 0.45)},
	"warding": {"name": "Rune of Warding", "short": "Warding", "key": "reduce", "value": 0.08,
		"desc": "%s protection from blows", "color": Color(0.6, 0.8, 1.0)},
	"swiftness": {"name": "Rune of Swiftness", "short": "Swiftness", "key": "walk", "value": 0.05,
		"desc": "you walk %s faster", "color": Color(0.7, 1.0, 0.7)},
}

## Of Embers: a burning foe takes this much every half second, this long.
const EMBER_BURN := {"dmg": 2.0, "time": 2.0}
## Thorns only answer blows from this close.
const THORNS_REACH := 70.0

## What gear adds up to at most, so stacking pieces can't break fights.
## The inventory shows "(capped)" beside a number that has reached its cap.
const CAPS := {"strike": 0.25, "health": 40.0, "stamina": 30.0, "walk": 0.12, "spell": 0.20}

## Named pieces keep their own names. Each is a base piece (its look, slot
## and, for weapons and armor, how it fights) with its own rule:
##   tower   only found in that tower (the Rare tower pieces)
##   kind    its essence
##   fx      numbers and rules it adds (worn pieces: instead of the base's own)
##   armor   chest numbers that replace the base armor's
##   color   its icon's colour (else the base's)
## The rules (fx keys) are read by player.gd: arc, chill, cinder, venom,
## kill_heal, thorn_burst, thorns, watch, kill_fill, dodge_haste, iframe,
## ember_mend, still_mend, spellweave, kill_mark, bastion.
const NAMED_ORDER := ["stormstring", "coral_trident", "cinder_axe", "stinger_dagger", "sunsteel_blade", "thornmaul", "barnacle_mail", "wyvern_scaleplate",
	"watchers_helm", "quickhand_gloves", "phantom_treads", "emberkin_mantle", "heartstone", "spellweave_ring", "reavers_greatsword", "bastion_plate"]
const NAMED := {
	# Rare tower pieces: only in their own tower.
	"stormstring": {"base": "shortbow", "rarity": "rare", "tower": "gryphon", "kind": "air", "name": "Stormstring",
		"desc": "a shortbow strung with storm-gut: a full draw also arcs to one more foe for half damage", "fx": {"arc": 0.5}},
	"coral_trident": {"base": "spear", "rarity": "rare", "tower": "kraken", "kind": "water", "name": "Coral Trident",
		"desc": "a three-pronged spear of living coral: its hits slow foes by 25% for 1.5 s", "fx": {"chill": 1.5}},
	"cinder_axe": {"base": "axe", "rarity": "rare", "tower": "wyvern", "kind": "fire", "name": "Cinder Axe",
		"desc": "an axe that never cools: its finisher leaves the floor burning for 2 s (it burns foes, not you)", "fx": {"cinder": 2.0}},
	"stinger_dagger": {"base": "dagger", "rarity": "rare", "tower": "manticore", "kind": "stone", "name": "Stinger Dagger",
		"desc": "a dagger ground from a stinger: every hit poisons the foe a little more", "fx": {"venom": 1.0}},
	"sunsteel_blade": {"base": "sword", "rarity": "rare", "tower": "firebird", "kind": "fire", "name": "Sunsteel Blade",
		"desc": "a sword with a warm, bright edge: each kill heals you 4", "fx": {"kill_heal": 4.0}},
	"thornmaul": {"base": "war_hammer", "rarity": "rare", "tower": "chimera", "kind": "blade", "name": "Thornmaul",
		"desc": "a hammer bound in briars: a staggering finisher throws thorns at foes nearby for 6 each", "fx": {"thorn_burst": 6.0}},
	"barnacle_mail": {"base": "chain", "rarity": "rare", "tower": "kraken", "kind": "water", "name": "Barnacle Mail",
		"desc": "chain mail crusted with shells: foes that strike you up close take 5", "fx": {"thorns": 5.0}, "color": Color(0.5, 0.66, 0.66)},
	"wyvern_scaleplate": {"base": "plate", "rarity": "rare", "tower": "wyvern", "kind": "iron", "name": "Wyvern Scaleplate",
		"desc": "plate of overlapping scales: 32% off a blow, with only chain mail's weight",
		"armor": {"reduce": 0.32, "roll_cost": 1.3, "roll_dist": 0.88, "regen": 0.87, "walk": 0.95}, "color": Color(0.62, 0.42, 0.36)},
	# Storied pieces: rare finds from floor 7 up, each with its own story.
	"watchers_helm": {"base": "iron_helm", "rarity": "storied", "kind": "iron", "name": "Watcher's Helm",
		"desc": "a helm with a narrow slit: foes you parry take 20% more damage from you for 3 s; +6 health", "fx": {"health": 6.0, "watch": 0.2},
		"color": Color(0.62, 0.66, 0.8)},
	"quickhand_gloves": {"base": "leather_gloves", "rarity": "storied", "kind": "blade", "name": "Quickhand Gloves",
		"desc": "thin gloves stained dark: each kill fills your hand's mark by 5% of its pool; strikes hit 3% harder", "fx": {"strike": 0.03, "kill_fill": 0.05},
		"color": Color(0.42, 0.2, 0.24)},
	"phantom_treads": {"base": "soft_boots", "rarity": "storied", "kind": "air", "name": "Phantom Treads",
		"desc": "boots that leave no prints: a dodge quickens your walk by 20% for 2 s, and a roll keeps you untouchable a moment longer",
		"fx": {"dodge_haste": 0.2, "iframe": 0.05}, "color": Color(0.7, 0.78, 0.86)},
	"emberkin_mantle": {"base": "travel_cloak", "rarity": "storied", "kind": "fire", "name": "Emberkin Mantle",
		"desc": "a cloak that smoulders at the hem: once a floor, falling below a fifth of your health heals 25 over 2 s", "fx": {"ember_mend": 25.0},
		"color": Color(0.7, 0.3, 0.18)},
	"heartstone": {"base": "bone_charm", "rarity": "storied", "kind": "stone", "name": "Heartstone",
		"desc": "a stone that beats: +16 health, and you regain 1 health every 3 s while no monster has noticed you", "fx": {"health": 16.0, "still_mend": 1.0},
		"color": Color(0.85, 0.35, 0.35)},
	"spellweave_ring": {"base": "garnet_ring", "rarity": "storied", "kind": "fire", "name": "Spellweave Ring",
		"desc": "a ring of three braided wires: every third spell you cast costs nothing", "fx": {"spellweave": 3.0}, "color": Color(0.85, 0.55, 0.95)},
	"reavers_greatsword": {"base": "greatsword", "rarity": "storied", "kind": "blade", "name": "Reaver's Greatsword",
		"desc": "a notched greatsword: kills restore 4 health and 4 essence to your hand's mark", "fx": {"kill_heal": 4.0, "kill_mark": 4.0}},
	"bastion_plate": {"base": "plate", "rarity": "storied", "kind": "iron", "name": "Bastion Plate",
		"desc": "old, dented plate: once a floor, falling below 30% health raises a 30-point barrier for 6 s", "fx": {"bastion": 30.0},
		"color": Color(0.74, 0.7, 0.6)},
}

## Wear (Common pieces only): how much condition each use takes off.
##   strike  a melee swing that lands (the melee weapon and gloves)
##   shot    an arrow or bolt loosed (the ranged weapon)
##   hit     a blow that lands on you (chest, helm, legs and cloak)
##   roll    a roll or jump (boots)
## At WORN or less a piece is badly worn: its bonus is halved (a weapon hits
## WORN_WEAPON as hard, a chest piece protects half as much). At 0 it breaks.
## Roughly: a weapon is badly worn after ~940 landed swings, a chest piece
## after ~94 blows, boots after ~500 rolls: about a whole climb of steady use.
const WEAR := {"strike": 0.0008, "shot": 0.003, "hit": 0.008, "roll": 0.0015}
const WEAR_BY := {
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
const HEIRLOOM_TEXT := {
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
const TEXT := {
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
const ARMOR := {
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
##   steady    light blows (under LIGHT_BLOW) can't knock you back
##   heavy     adds HEAVY_ROLL to a roll's cost
##   rarity    a piece that is always this rarity (rings and amulets are Fine)
##   drop_weight  how common it is as a drop (0: not found yet)
##   look      how it shows on the climber (player.gd)
## Penalties (heavy, a shorter parry, a slower walk) stay when a piece is
## badly worn; only its bonuses halve.
const PIECE_ORDER := [
	"cloth_hood", "leather_cap", "iron_helm", "grip_wraps", "leather_gloves", "gauntlets",
	"padded_trousers", "leather_leggings", "chain_leggings", "soft_boots", "climbing_boots", "hobnail_boots",
	"travel_cloak", "dusk_cloak", "satchel", "belt_pouch", "bone_charm", "ember_charm", "iron_band", "garnet_ring",
	"tide_locket", "pearl_ring", "overdrawn_ring", "climbers_pack",
]
const PIECES := {
	"cloth_hood": {"slot": "helm", "name": "Cloth Hood", "short": "Hood", "desc": "a deep hood of plain cloth: your light reaches 10% farther",
		"light": 0.10, "color": Color(0.46, 0.5, 0.42), "drop_weight": 3, "look": "hood"},
	"leather_cap": {"slot": "helm", "name": "Leather Cap", "short": "Cap", "desc": "a padded leather cap: +8 health",
		"health": 8.0, "color": Color(0.55, 0.38, 0.24), "drop_weight": 3, "look": "cap"},
	"iron_helm": {"slot": "helm", "name": "Iron Helm", "short": "Helm", "desc": "a plain iron helm: 6% damage taken off; heavy",
		"reduce": 0.06, "heavy": true, "color": Color(0.7, 0.72, 0.78), "drop_weight": 2, "look": "helm"},
	"grip_wraps": {"slot": "gloves", "name": "Grip Wraps", "short": "Wraps", "desc": "cloth wound tight round the hands: strike chains cost 6% less stamina",
		"chain": 0.06, "color": Color(0.82, 0.76, 0.62), "drop_weight": 3},
	"leather_gloves": {"slot": "gloves", "name": "Leather Gloves", "short": "Gloves", "desc": "stiff leather gloves: strikes hit 4% harder",
		"strike": 0.04, "color": Color(0.5, 0.33, 0.2), "drop_weight": 3},
	"gauntlets": {"slot": "gloves", "name": "Gauntlets", "short": "Gauntlets", "desc": "steel gauntlets: strikes hit 7% harder, but the parry window is 5% shorter; heavy",
		"strike": 0.07, "parry": -0.05, "heavy": true, "color": Color(0.72, 0.74, 0.8), "drop_weight": 2},
	"padded_trousers": {"slot": "legs", "name": "Padded Trousers", "short": "Trousers", "desc": "quilted trousers: +10 max stamina",
		"stamina": 10.0, "color": Color(0.62, 0.55, 0.42), "drop_weight": 3},
	"leather_leggings": {"slot": "legs", "name": "Leather Leggings", "short": "Leggings", "desc": "supple leather leggings: rolls carry 5% farther",
		"roll_dist": 0.05, "color": Color(0.46, 0.31, 0.2), "drop_weight": 3},
	"chain_leggings": {"slot": "legs", "name": "Chain Leggings", "short": "Chain legs", "desc": "mail leggings: 5% damage taken off; heavy",
		"reduce": 0.05, "heavy": true, "color": Color(0.62, 0.65, 0.7), "drop_weight": 2},
	"soft_boots": {"slot": "boots", "name": "Soft Boots", "short": "Soft", "desc": "light boots of soft hide: you walk 4% faster",
		"walk": 0.04, "color": Color(0.5, 0.4, 0.3), "drop_weight": 3, "look": "soft"},
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
	"bone_charm": {"slot": "amulet", "name": "Bone Charm", "short": "Bone", "desc": "a carved bone on a cord: +10 health",
		"health": 10.0, "rarity": "fine", "color": Color(0.88, 0.84, 0.72), "drop_weight": 1},
	"ember_charm": {"slot": "amulet", "name": "Ember Charm", "short": "Ember", "desc": "a warm red stone on a chain: spells hit 6% harder",
		"spell": 0.06, "rarity": "fine", "color": Color(0.9, 0.42, 0.25), "drop_weight": 1},
	"iron_band": {"slot": "ring", "name": "Iron Band", "short": "Iron", "desc": "a plain iron ring: stamina refills 5% faster",
		"regen": 0.05, "rarity": "fine", "color": Color(0.66, 0.68, 0.74), "drop_weight": 1},
	"garnet_ring": {"slot": "ring", "name": "Garnet Ring", "short": "Garnet", "desc": "a gold ring set with a garnet: strikes hit 4% harder",
		"strike": 0.04, "rarity": "fine", "color": Color(0.78, 0.22, 0.28), "drop_weight": 1},
	# Rare by nature: only found as Rare finds (or better).
	"tide_locket": {"slot": "amulet", "name": "Tide Locket", "short": "Tide", "desc": "a locket full of sea water: marks fill 8% faster; +6 health",
		"fill": 0.08, "health": 6.0, "rarity": "rare", "color": Color(0.37, 0.72, 0.85), "drop_weight": 1},
	"pearl_ring": {"slot": "ring", "name": "Pearl Ring", "short": "Pearl", "desc": "a ring set with a black pearl: each kill puts 2 essence into your emptiest mark",
		"kill_essence": 2.0, "rarity": "rare", "color": Color(0.86, 0.86, 0.92), "drop_weight": 1},
	"overdrawn_ring": {"slot": "ring", "name": "Ring of the Overdrawn", "short": "Overdrawn", "desc": "a scorched ring: your first overdraw each floor doesn't burn the body part",
		"overdraw_guard": 1.0, "rarity": "rare", "color": Color(0.95, 0.5, 0.3), "drop_weight": 1},
	"climbers_pack": {"slot": "backpack", "name": "Climber's Pack", "short": "Pack", "desc": "a well-worn pack with many pockets: one more kind of item on the belt, 4 of each, and room for 2 more spare pieces",
		"belt": 1, "stack": 1, "pack": 2, "rarity": "rare", "color": Color(0.4, 0.46, 0.3), "drop_weight": 1},
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
	["pack", "Pack spaces", false, true],
]
## Only these numbers halve on a badly worn piece (the rest are penalties or switches).
const BONUS_KEYS := ["health", "stamina", "reduce", "strike", "chain", "roll_dist", "light", "regen", "spell", "notice", "ailment", "jump"]

## How common each weapon is as a drop (fists are always carried).
const WEAPON_DROP_WEIGHT := {
	"dagger": 4, "sword": 3, "axe": 4, "mace": 3, "spear": 4, "greatsword": 2, "war_hammer": 2,
	"shortbow": 3, "longbow": 2, "crossbow": 2,
}

## Monsters favour gear that suits them: these are four times as likely.
const FAVOUR_MULT := 4
const FAVOUR := {
	"knight": ["chain", "plate", "sword", "mace", "greatsword", "iron_helm", "gauntlets"],
	"archer": ["shortbow", "longbow", "crossbow", "leather", "leather_cap"],
	"smith": ["war_hammer", "mace", "chain", "plate", "gauntlets", "hobnail_boots"],
	"shellback": ["mace", "chain", "chain_leggings"],
	"ram": ["war_hammer", "axe", "hobnail_boots"],
	"thornhound": ["dagger", "leather", "leather_gloves"],
	"mongrel": ["axe", "spear", "leather", "leather_leggings"],
	"scorpling": ["dagger", "padded", "travel_cloak"],
	"thunderling": ["spear", "chain", "soft_boots"],
	"lurker": ["spear", "padded", "climbing_boots"],
	"slime": ["padded", "dagger", "padded_trousers"],
	"bat": ["dagger", "shortbow", "dusk_cloak"],
	"cinder": ["shortbow", "crossbow", "grip_wraps"],
	"wisp": ["shortbow", "padded", "cloth_hood"],
	"bloomcap": ["padded", "leather", "travel_cloak"],
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
	var keep: Array = traits.filter(func(t): return TRAITS.has(String(t))).map(func(t): return String(t))
	var g := {"base": base, "rarity": r, "traits": keep, "rank": clampi(rank, 0, MAX_RANK)}
	if NAMED.has(named) and String(NAMED[named]["base"]) == base:
		g["named"] = named
	if LASTING_RUNES.has(rune):
		g["rune"] = rune
	if bool(RARITIES[r]["wears"]) and keep.is_empty() and not g.has("named"):
		g["wear"] = 1.0
	return g


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
## one has one). Named pieces carry one besides their own rule.
static func trait_count(base, r: String, named := "") -> int:
	if named != "":
		return 1 if traits_for(trait_slot(base)).size() > 0 else 0
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
	return trait_value(t, r) * (1.0 + RANK_TRAIT * clampi(rank, 0, MAX_RANK))


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


## A named piece as a record (its rarity, and its one rolled trait).
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
	return (1.0 + float(RARITIES.get(rarity(g), RARITIES["common"])["boost"])) * (1.0 + RANK_WEAPON * clampi(k, 0, MAX_RANK))


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
			if k in ["slot", "name", "short", "desc", "color", "drop_weight", "look", "rarity"]:
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
		bits.append({"bow": "a bow you draw", "crossbow": "fires at once, then reloads", "melee": "a melee weapon"}[ka])
	var words := {
		"Damage": ["hits harder", "hits softer"], "Reach": ["longer reach", "shorter reach"], "Range": ["flies farther", "shorter range"],
		"Stamina": ["costs less stamina", "costs more stamina"], "Speed": ["faster", "slower"], "Draw": ["draws faster", "draws slower"],
		"Reload": ["reloads faster", "reloads slower"],
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
	if NAMED.has(named_id(r)):
		var nd: Dictionary = NAMED[named_id(r)]
		tags[0] = "%s %s" % [rarity_name(r), d.get("name", "")]
		if nd.has("tower"):
			tags.append(TEXT["tower_piece"])
	if wears(r):
		tags.append(TEXT["condition"] % int(round(condition(r) * 100.0)))
	else:
		tags.append(TEXT["never_wears"])
	lines.append("  ·  ".join(tags))
	if is_worn(r):
		lines.append(TEXT["worn_weapon"] if Weapons.WEAPONS.has(base_id(r)) else TEXT["worn"])
	return lines


## A piece's traits for a card: [[text, colour (its essence's)], ...].
static func trait_lines(g) -> Array:
	var r := rec(g)
	var out: Array = []
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
# Icons follow draw_util.gd's style guide: filled shapes with a dark outline,
# lit from the top-left, a pale glint on blades. Each icon is one Batch
# (one draw call) and uses only filled shapes, so it is safe under torchlight
# too (gear lying on the floor, fx.gd).

const Draw := preload("res://scripts/draw_util.gd")
const Palette := preload("res://scripts/palette.gd")
const _LEATHER := Color(0.36, 0.24, 0.16)
const _GOLD := Color(0.9, 0.72, 0.36)


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
	elif col.a < 0.999:
		for i in b.cols.size():
			b.cols[i].a *= col.a
	b.flush(ci)


## A piece's icon into a Batch, with a tempered piece's rank (small gold
## pips down its left side) and a lasting rune (its glyph, bottom right) drawn over it.
static func icon_into(b, g, c: Vector2, s: float, col: Color) -> void:
	_icon_body(b, g, c, s, col)
	if not (g is Dictionary) or col.v < 0.08:
		return
	var k := int(g.get("rank", 0))
	for i in k:
		var p := c + Vector2(-s * 0.98, -s * 0.05 + s * 0.34 * i)
		b.dot(p, maxf(1.6, s * 0.13), Palette.OUTLINE)
		b.dot(p, maxf(1.0, s * 0.09), _GOLD)
	if LASTING_RUNES.has(String(g.get("rune", ""))):
		rune_into(b, String(g["rune"]), c + Vector2(s * 0.72, s * 0.72), s * 0.36, LASTING_RUNES[g["rune"]]["color"])


## A rune drawn in code: a few strokes joining dots of a 3 by 3 grid, picked
## by hashing `id` (the same id always draws the same rune), on a dark stone.
static func rune_into(b, id: String, c: Vector2, r: float, col: Color, stone := true) -> void:
	if stone:
		b.dot(c, r * 1.25, Palette.OUTLINE)
		b.dot(c, r * 1.1, Color(0.13, 0.12, 0.16))
		b.dot(c, r * 1.05, Color(col, 0.18))
	var w := maxf(1.0, r * 0.26)
	for st in rune_strokes(id):
		var a := c + _rune_dot(st[0]) * r * 0.7
		var e := c + _rune_dot(st[1]) * r * 0.7
		b.line(a, e, col, w)
		b.dot(a, w * 0.5, col)
		b.dot(e, w * 0.5, col)


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


static func _icon_body(b, g, c: Vector2, s: float, col: Color) -> void:
	var id := base_id(g)
	if PIECES.has(id):
		_piece_icon(b, id, c, s, col, NAMED.get(named_id(g), {}).get("color", Color(0, 0, 0, 0)))
		if g is Dictionary and is_worn(g):
			_cracks(b, c, s)
		return
	var u := s / 10.0  # drawn on a grid of about -10..10
	var ol := clampf(u * 1.1, 0.8, 1.6)  # outline width
	var steel := Palette.STEEL
	var wood := Palette.WOOD
	var d := Vector2(1, -1).normalized()  # weapons lie from bottom-left to top-right
	var p := func(x: float, y: float) -> Vector2: return c + Vector2(x, y) * u
	match id:
		"fists":
			for f in [[Vector2(-4.6, 2.2), 1.0], [Vector2(4.2, -1.8), -1.0]]:
				var fc: Vector2 = c + f[0] * u
				var body := _rrect(fc, Vector2(4.4, 3.8) * u, 2.0 * u)
				b.poly(body, Palette.CLIMBER_SKIN.darkened(0.25), ol)
				b.polygon(_rrect(fc + Vector2(-0.5, -0.6) * u, Vector2(3.6, 3.0) * u, 1.6 * u), Palette.CLIMBER_SKIN)
				for k in 3:
					var kx := (-2.2 + k * 2.2) * u
					b.line(fc + Vector2(kx, -3.6 * u), fc + Vector2(kx, -1.0 * u), Palette.CLIMBER_SKIN.darkened(0.35), maxf(0.8, 0.6 * u))
				b.ball(fc + Vector2(f[1] * 4.0, 1.2) * u, 1.6 * u, Palette.CLIMBER_SKIN.darkened(0.08), true)
				# a wrap of cloth round the wrist
				b.rect(Rect2(fc + Vector2(-4.4, 3.0) * u, Vector2(8.8, 1.8) * u), Palette.CLIMBER_TUNIC)
		"dagger", "sword", "greatsword":
			var sz: Array = {"dagger": [-1.5, 7.5, 1.7, 3.4, 3.8], "sword": [-3.0, 9.5, 1.9, 4.6, 4.2], "greatsword": [-4.0, 10.5, 2.7, 6.0, 4.8]}[id]
			var base: Vector2 = c - d * absf(sz[0]) * u * 1.414
			var tip: Vector2 = c + d * sz[1] * u * 1.414
			var grip_end: Vector2 = base - d * sz[4] * u * 1.414
			b.stroke(base, grip_end, _LEATHER, 2.0 * u)
			for k in 3:
				var at := base.lerp(grip_end, 0.25 + k * 0.25)
				b.line(at + d.orthogonal() * 1.0 * u, at - d.orthogonal() * 1.0 * u, _LEATHER.darkened(0.4), maxf(0.7, 0.5 * u))
			_blade(b, base, tip, sz[2] * u, steel, ol)
			var side := d.orthogonal()
			b.stroke(base + side * sz[3] * u, base - side * sz[3] * u, _GOLD.darkened(0.15), (2.2 if id == "greatsword" else 1.7) * u)
			b.ball(grip_end - d * 1.4 * u, (1.6 if id == "dagger" else 2.0) * u, _GOLD, true)
		"axe":
			var h0: Vector2 = p.call(-8.0, 8.0)
			var h1: Vector2 = p.call(6.5, -6.5)
			b.stroke(h0, h1, wood, 2.2 * u)
			b.line(h0.lerp(h1, 0.06), h0.lerp(h1, 0.62), wood.lightened(0.25), maxf(0.7, 0.6 * u))
			# A bearded head: narrow at the haft, flaring to a curved edge.
			var side := Vector2(-1, -1).normalized()
			var m := h0.lerp(h1, 0.78)
			var head := PackedVector2Array([m + d * 1.8 * u, m + d * 1.9 * u + side * 2.6 * u])
			var edge := PackedVector2Array()
			for i in 9:
				var t := float(i) / 8.0
				edge.append(m + side * (6.4 + 1.3 * sin(t * PI)) * u + d * lerpf(4.6, -4.8, t) * u)
			head.append_array(edge)
			head.append_array([m - d * 2.1 * u + side * 2.6 * u, m - d * 1.8 * u])
			b.poly(PackedVector2Array([m + d * 1.6 * u, m - d * 1.6 * u, m - d * 1.4 * u - side * 2.2 * u, m + d * 1.4 * u - side * 2.2 * u]), steel.darkened(0.35), ol)
			b.poly(head, steel.darkened(0.3), ol)
			var lit := PackedVector2Array([m + d * 1.9 * u + side * 2.6 * u])
			for i in 5:
				lit.append(edge[i])
			lit.append(m + side * 4.0 * u)
			b.polygon(lit, steel.darkened(0.04))
			var glint := PackedVector2Array()
			for i in 8:
				glint.append(edge[i] - side * 0.8 * u)
			b.path(glint, Color(1, 1, 1, 0.6), maxf(0.8, 0.7 * u))
		"mace":
			var h0: Vector2 = p.call(-8.0, 8.0)
			var hc: Vector2 = p.call(4.4, -4.4)
			b.stroke(h0, hc, wood, 2.0 * u)
			b.ball(h0, 1.6 * u, _LEATHER, true)
			for i in 6:
				var a := TAU * i / 6.0 + 0.3
				b.poly(PackedVector2Array([hc + Vector2.from_angle(a - 0.42) * 3.2 * u, hc + Vector2.from_angle(a) * 6.6 * u, hc + Vector2.from_angle(a + 0.42) * 3.2 * u]), steel.darkened(0.25), ol)
			b.ball(hc, 4.0 * u, steel, true)
		"spear":
			var h0: Vector2 = p.call(-10.0, 10.0)
			var base: Vector2 = p.call(4.0, -4.0)
			b.stroke(h0, base, wood, 1.6 * u)
			_leaf(b, base, p.call(11.0, -11.0), 2.4 * u, steel, ol)
			b.stroke(base - d * 0.6 * u, base + d * 0.6 * u, _LEATHER, 2.6 * u)
		"war_hammer":
			var h0: Vector2 = p.call(-8.0, 8.0)
			var hc: Vector2 = p.call(4.6, -4.6)
			b.stroke(h0, hc + d * 2.2 * u, wood, 2.0 * u)
			var side := Vector2(1, 1).normalized()
			var blk := PackedVector2Array([hc - side * 1.5 * u - d * 2.8 * u, hc + side * 6.0 * u - d * 2.8 * u,
				hc + side * 6.0 * u + d * 2.8 * u, hc - side * 1.5 * u + d * 2.8 * u])
			var spike := PackedVector2Array([hc - side * 1.5 * u - d * 1.6 * u, hc - side * 6.8 * u, hc - side * 1.5 * u + d * 1.6 * u])
			b.poly(spike, steel.darkened(0.3), ol)
			b.poly(blk, steel.darkened(0.3), ol)
			b.polygon(PackedVector2Array([blk[0], blk[1], (blk[1] + blk[2]) * 0.5, (blk[0] + blk[3]) * 0.5]), steel.darkened(0.05))
			b.line(blk[1].lerp(blk[2], 0.1), blk[1].lerp(blk[2], 0.9), Color(1, 1, 1, 0.5), maxf(0.8, 0.8 * u))
		"shortbow", "longbow":
			var r := (10.5 if id == "shortbow" else 12.5) * u
			var o: Vector2 = p.call(-4.5, 0.0)
			var t0 := o + Vector2.from_angle(-1.15) * r
			var t1 := o + Vector2.from_angle(1.15) * r
			b.line(t0, t1, Color(0.92, 0.88, 0.8), maxf(0.8, 0.5 * u))  # the string
			_arrow(b, p.call(-6.5, 0.0), p.call(10.5, 0.0), u, ol)
			b.arc(o, r, -1.15, 1.15, 14, Palette.OUTLINE, 2.2 * u + ol * 2.0)
			b.arc(o, r, -1.15, 1.15, 14, wood, 2.2 * u)
			b.arc(o, r - 0.5 * u, -1.0, -0.15, 8, wood.lightened(0.3), maxf(0.7, 0.6 * u))
			b.stroke(o + Vector2(r, -1.8 * u), o + Vector2(r, 1.8 * u), _LEATHER, 2.6 * u)  # the grip
		"crossbow":
			var stock := PackedVector2Array([p.call(-10.0, 1.0), p.call(-10.0, -1.6), p.call(-4.0, -1.6), p.call(9.0, -0.8),
				p.call(9.0, 1.2), p.call(-3.0, 1.2), p.call(-6.0, 3.6), p.call(-9.0, 3.6)])
			var pc: Vector2 = p.call(1.5, 0.0)
			b.arc(pc, 8.0 * u, -1.25, 1.25, 12, Palette.OUTLINE, 2.0 * u + ol * 2.0)
			b.arc(pc, 8.0 * u, -1.25, 1.25, 12, steel.darkened(0.15), 2.0 * u)
			b.line(pc + Vector2.from_angle(-1.25) * 8.0 * u, p.call(-2.0, -0.2), Color(0.92, 0.88, 0.8), maxf(0.8, 0.5 * u))
			b.line(pc + Vector2.from_angle(1.25) * 8.0 * u, p.call(-2.0, 0.2), Color(0.92, 0.88, 0.8), maxf(0.8, 0.5 * u))
			b.poly(stock, wood.darkened(0.15), ol)
			b.polygon(PackedVector2Array([p.call(-10.0, -1.6), p.call(-4.0, -1.6), p.call(9.0, -0.8), p.call(9.0, 0.0), p.call(-10.0, 0.0)]), wood.lightened(0.1))
			_arrow(b, p.call(-2.0, -1.8), p.call(9.5, -1.8), u * 0.85, ol)
		"", "padded", "leather", "chain", "plate":
			var shape := [Vector2(-8, -7.5), Vector2(-3.4, -10), Vector2(0, -7), Vector2(3.4, -10), Vector2(8, -7.5),
				Vector2(7.2, 1), Vector2(4.4, 9.5), Vector2(-4.4, 9.5), Vector2(-7.2, 1)]
			var body := PackedVector2Array()
			for v in shape:
				body.append(c + v * u)
			if id == "":
				# No armor: a faint dashed outline where it would be.
				for i in body.size():
					var a := body[i]
					var bb := body[(i + 1) % body.size()]
					b.line(a.lerp(bb, 0.15), a.lerp(bb, 0.6), Color(col, 0.6), maxf(1.0, 0.8 * u))
				return
			b.poly(body, col.darkened(0.3), ol)
			b.polygon(PackedVector2Array([body[0], body[1], body[2], c + Vector2(0, 9.5) * u, body[7], body[8]]), col)
			b.polygon(PackedVector2Array([body[2], body[3], body[4], body[5], body[6], c + Vector2(0, 9.5) * u]), col.darkened(0.12))
			b.polygon(PackedVector2Array([body[1], body[2], c + Vector2(-1.0, -5.0) * u, c + Vector2(-5.5, -5.6) * u]), Color(col.lightened(0.35), 0.6))
			var dark := col.darkened(0.45)
			match id:
				"padded":
					for y in [-3.4, 0.6, 4.6]:
						b.line(c + Vector2(-6.6, y) * u, c + Vector2(6.6, y) * u, dark, maxf(0.8, 0.6 * u))
					for x in [-3.2, 3.2]:
						b.line(c + Vector2(x, -6.0) * u, c + Vector2(x, 8.6) * u, Color(dark, 0.6), maxf(0.7, 0.45 * u))
				"leather":
					b.line(c + Vector2(0, -6.4) * u, c + Vector2(0, 9.0) * u, dark, maxf(0.8, 0.6 * u))
					for y in [-1.0, 4.4]:
						b.rect(Rect2(c + Vector2(-6.8, y) * u, Vector2(13.6, 1.8) * u), Color(0.2, 0.13, 0.08))
						b.rect(Rect2(c + Vector2(-1.2, y - 0.3) * u, Vector2(2.4, 2.4) * u), _GOLD)
				"chain":
					for row in 5:
						for k in 5:
							var x := -5.2 + k * 2.6 + (1.3 if row % 2 == 1 else 0.0)
							var y := -5.2 + row * 2.9
							if absf(x) > 6.4 - maxf(0.0, y - 2.0) * 0.4:
								continue
							b.dot(c + Vector2(x, y) * u, 1.15 * u, dark)
							b.dot(c + Vector2(x - 0.3, y - 0.3) * u, 0.55 * u, col.lightened(0.35))
				"plate":
					for y in [-1.0, 3.8]:
						b.line(c + Vector2(-7.0, y) * u, c + Vector2(7.0, y) * u, dark, maxf(0.9, 0.8 * u))
						b.line(c + Vector2(-6.6, y + 0.9) * u, c + Vector2(6.6, y + 0.9) * u, Color(col.lightened(0.4), 0.6), maxf(0.6, 0.4 * u))
					for x in [-7.2, 7.2]:
						b.ball(c + Vector2(x, -7.4) * u, 2.8 * u, col.lightened(0.05), true)
					for x in [-4.6, 4.6]:
						b.dot(c + Vector2(x, 6.8) * u, 0.8 * u, dark)
		_:
			b.ball(c, s * 0.5, col, true)
	if g is Dictionary and is_worn(g):
		_cracks(b, c, s)


## A blade from `base` to `tip`, ridged down the middle: the lit half paler,
## a glint along it.
static func _blade(b, base: Vector2, tip: Vector2, hw: float, metal: Color, ol: float) -> void:
	var dir := (tip - base).normalized()
	var side := dir.orthogonal()
	var len := base.distance_to(tip)
	var shoulder := base + dir * len * 0.8
	var pts := PackedVector2Array([base + side * hw, shoulder + side * hw * 0.92, tip, shoulder - side * hw * 0.92, base - side * hw])
	b.poly(pts, metal.darkened(0.28), ol)
	var lit := side if side.dot(Draw.LIGHT_DIR) > 0.0 else -side
	b.polygon(PackedVector2Array([base, base + lit * hw, shoulder + lit * hw * 0.92, tip]), metal.lightened(0.05))
	b.line(base + dir * len * 0.08 + lit * hw * 0.45, tip - dir * len * 0.12 + lit * hw * 0.2, Color(1, 1, 1, 0.6), maxf(0.7, hw * 0.3))


## A leaf-shaped spearhead.
static func _leaf(b, base: Vector2, tip: Vector2, hw: float, metal: Color, ol: float) -> void:
	var dir := (tip - base).normalized()
	var side := dir.orthogonal()
	var len := base.distance_to(tip)
	var wide := base + dir * len * 0.38
	var pts := PackedVector2Array([base + side * hw * 0.45, wide + side * hw, tip, wide - side * hw, base - side * hw * 0.45])
	b.poly(pts, metal.darkened(0.28), ol)
	var lit := side if side.dot(Draw.LIGHT_DIR) > 0.0 else -side
	b.polygon(PackedVector2Array([base, base + lit * hw * 0.45, wide + lit * hw, tip]), metal.lightened(0.05))


## An arrow lying from `tail` to `head`: fletching, shaft and a steel head.
static func _arrow(b, tail: Vector2, head: Vector2, u: float, ol: float) -> void:
	var dir := (head - tail).normalized()
	var side := dir.orthogonal()
	b.stroke(tail, head - dir * 2.0 * u, Palette.WOOD.lightened(0.15), 0.9 * u)
	b.poly(PackedVector2Array([head + dir * 1.0 * u, head - dir * 2.6 * u + side * 1.8 * u, head - dir * 2.6 * u - side * 1.8 * u]), Palette.STEEL, ol * 0.8)
	for sg in [1.0, -1.0]:
		b.polygon(PackedVector2Array([tail + dir * 3.2 * u, tail + side * sg * 1.9 * u + dir * 0.2 * u, tail - dir * 0.4 * u + side * sg * 1.6 * u, tail + dir * 0.6 * u]), Color(0.85, 0.3, 0.26) if sg > 0.0 else Color(0.92, 0.9, 0.85))


## A rounded rectangle's points (for fists and badges).
static func _rrect(c: Vector2, half: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [Vector2(half.x - r, -half.y + r), Vector2(half.x - r, half.y - r), Vector2(-half.x + r, half.y - r), Vector2(-half.x + r, -half.y + r)]
	for k in 4:
		for i in 5:
			var a := -PI / 2.0 + (k + i / 4.0) * PI / 2.0
			pts.append(c + corners[k] + Vector2.from_angle(a) * r)
	return pts


## Cracks across a badly worn piece's icon.
static func _cracks(b, c: Vector2, s: float) -> void:
	var u := s / 10.0
	var w := maxf(0.8, 0.7 * u)
	var crack := PackedVector2Array([c + Vector2(-6.5, -5.0) * u, c + Vector2(-2.5, -1.5) * u, c + Vector2(-3.8, 1.8) * u, c + Vector2(1.5, 5.5) * u])
	b.path(crack, Color(0.08, 0.05, 0.04, 0.85), w * 1.6)
	b.path(crack, Color(0.95, 0.45, 0.3, 0.75), w * 0.6)
	b.line(c + Vector2(-2.5, -1.5) * u, c + Vector2(1.8, -3.0) * u, Color(0.08, 0.05, 0.04, 0.85), w)


## Points on the icon grid (about -10..10), centred on `c`.
static func _pts(c: Vector2, u: float, arr: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in arr:
		out.append(c + v * u)
	return out


## The worn pieces (PIECES): a hood, cap or helm, gloves, legs, boots, a
## cloak, a bag, an amulet or a ring, each in its own colour.
static func _piece_icon(b, id: String, c: Vector2, s: float, _col: Color, tint := Color(0, 0, 0, 0)) -> void:
	var u := s / 10.0
	var ol := clampf(u * 1.1, 0.8, 1.6)
	var d: Dictionary = PIECES[id]
	var base_col: Color = d["color"] if tint.a <= 0.0 else tint
	var dark := base_col.darkened(0.45)
	var lit := base_col.lightened(0.3)
	var thin := maxf(0.7, 0.5 * u)
	match String(d["slot"]):
		"helm":
			match id:
				"cloth_hood":
					var hood := _pts(c, u, [Vector2(0, -9.5), Vector2(5.5, -7.5), Vector2(8.0, -2.0), Vector2(8.5, 6.0), Vector2(10.0, 9.5),
						Vector2(-10.0, 9.5), Vector2(-8.5, 6.0), Vector2(-8.0, -2.0), Vector2(-5.5, -7.5)])
					b.poly(hood, base_col.darkened(0.15), ol)
					b.polygon(_pts(c, u, [Vector2(0, -9.5), Vector2(-5.5, -7.5), Vector2(-8.0, -2.0), Vector2(-8.5, 6.0), Vector2(-3.0, 5.0), Vector2(-1.0, -6.0)]), base_col)
					# the dark opening of the face
					b.polygon(_pts(c, u, [Vector2(0, -5.0), Vector2(4.0, -2.0), Vector2(4.6, 3.5), Vector2(0, 6.0), Vector2(-4.6, 3.5), Vector2(-4.0, -2.0)]), Color(0.07, 0.06, 0.08))
					b.line(c + Vector2(-3.5, -6.5) * u, c + Vector2(-6.5, 1.0) * u, Color(lit, 0.6), maxf(0.7, 0.6 * u))
				"leather_cap":
					var dome := PackedVector2Array()
					for i in 13:
						var a := PI + PI * i / 12.0
						dome.append(c + Vector2(cos(a) * 8.5, 2.5 + sin(a) * 9.0) * u)
					b.poly(dome, base_col.darkened(0.12), ol)
					var top := PackedVector2Array()
					for i in 7:
						var a := PI + PI * 0.5 * i / 6.0
						top.append(c + Vector2(cos(a) * 7.6, 2.5 + sin(a) * 8.2) * u)
					top.append(c + Vector2(0, 2.5) * u)
					b.polygon(top, base_col)
					for x in [-3.0, 3.0]:
						b.line(c + Vector2(x * 0.3, -6.3) * u, c + Vector2(x, 2.5) * u, dark, thin)
					b.poly(_pts(c, u, [Vector2(-9.5, 1.5), Vector2(9.5, 1.5), Vector2(9.0, 4.8), Vector2(-9.0, 4.8)]), dark, ol)
					b.dot(c + Vector2(0, -6.6) * u, 1.2 * u, dark)
				_:
					var dome := PackedVector2Array()
					for i in 13:
						var a := PI + PI * i / 12.0
						dome.append(c + Vector2(cos(a) * 8.6, 3.0 + sin(a) * 10.0) * u)
					dome.append(c + Vector2(8.6, 6.0) * u)
					dome.append(c + Vector2(-8.6, 6.0) * u)
					b.poly(dome, base_col.darkened(0.25), ol)
					var top := PackedVector2Array()
					for i in 7:
						var a := PI + PI * 0.5 * i / 6.0
						top.append(c + Vector2(cos(a) * 7.6, 3.0 + sin(a) * 9.0) * u)
					top.append(c + Vector2(0, 3.0) * u)
					b.polygon(top, base_col)
					b.rect(Rect2(c + Vector2(-8.6, 2.2) * u, Vector2(17.2, 2.2) * u), base_col.darkened(0.4))
					b.poly(_pts(c, u, [Vector2(-1.2, 2.0), Vector2(1.2, 2.0), Vector2(1.0, 9.5), Vector2(-1.0, 9.5)]), base_col.darkened(0.1), ol * 0.8)  # nose guard
					b.line(c + Vector2(-4.5, -4.5) * u, c + Vector2(-6.5, 0.5) * u, Color(1, 1, 1, 0.55), maxf(0.8, 0.7 * u))
		"gloves":
			var palm := _pts(c, u, [Vector2(-5.5, -8.0), Vector2(4.0, -8.5), Vector2(5.0, -1.0), Vector2(8.6, -3.0), Vector2(9.6, -1.0),
				Vector2(5.6, 4.0), Vector2(4.0, 9.5), Vector2(-5.0, 9.5), Vector2(-6.4, 2.0)])
			b.poly(palm, base_col.darkened(0.2), ol)
			b.polygon(_pts(c, u, [Vector2(-5.5, -8.0), Vector2(-1.0, -8.3), Vector2(-1.0, 9.5), Vector2(-5.0, 9.5), Vector2(-6.4, 2.0)]), base_col)
			for x in [-2.6, 0.2, 2.8]:
				b.line(c + Vector2(x, -8.2) * u, c + Vector2(x * 0.9, -3.0) * u, dark, thin)
			b.rect(Rect2(c + Vector2(-5.2, 5.6) * u, Vector2(9.4, 2.4) * u), dark)  # the cuff
			match id:
				"grip_wraps":
					for k in 4:
						var y := -5.5 + k * 3.2
						b.line(c + Vector2(-6.0, y + 1.6) * u, c + Vector2(5.0, y - 1.0) * u, Color(lit, 0.8), maxf(0.7, 0.6 * u))
				"gauntlets":
					for y in [-3.0, 0.4, 3.6]:
						b.line(c + Vector2(-6.0, y) * u, c + Vector2(5.0, y) * u, dark, maxf(0.8, 0.6 * u))
					b.line(c + Vector2(-4.4, -7.0) * u, c + Vector2(-5.2, 3.0) * u, Color(1, 1, 1, 0.5), maxf(0.8, 0.6 * u))
					b.dot(c + Vector2(-3.0, 6.8) * u, 0.8 * u, _GOLD)
					b.dot(c + Vector2(2.0, 6.8) * u, 0.8 * u, _GOLD)
				_:
					b.line(c + Vector2(-3.5, -1.0) * u, c + Vector2(2.5, -1.0) * u, dark, thin)
		"legs":
			var legs := _pts(c, u, [Vector2(-7.5, -9.0), Vector2(7.5, -9.0), Vector2(8.5, 9.5), Vector2(2.5, 9.5), Vector2(0, -1.5),
				Vector2(-2.5, 9.5), Vector2(-8.5, 9.5)])
			b.poly(legs, base_col.darkened(0.2), ol)
			b.polygon(_pts(c, u, [Vector2(-7.5, -9.0), Vector2(0, -9.0), Vector2(0, -1.5), Vector2(-2.5, 9.5), Vector2(-8.5, 9.5)]), base_col)
			b.rect(Rect2(c + Vector2(-7.6, -9.0) * u, Vector2(15.2, 2.6) * u), dark)  # the waistband
			match id:
				"padded_trousers":
					for y in [-3.0, 1.5, 6.0]:
						b.line(c + Vector2(-8.0, y) * u, c + Vector2(-1.4, y) * u, Color(dark, 0.7), thin)
						b.line(c + Vector2(1.4, y) * u, c + Vector2(8.0, y) * u, Color(dark, 0.7), thin)
				"chain_leggings":
					for row in 5:
						for k in 3:
							for sg in [-1.0, 1.0]:
								var x: float = sg * (2.4 + k * 2.0 + (0.9 if row % 2 == 1 else 0.0))
								b.dot(c + Vector2(x, -4.2 + row * 2.8) * u, 0.9 * u, dark)
				_:
					b.line(c + Vector2(-4.8, -6.0) * u, c + Vector2(-5.6, 9.0) * u, dark, thin)
					b.line(c + Vector2(4.8, -6.0) * u, c + Vector2(5.6, 9.0) * u, dark, thin)
					b.dot(c + Vector2(0, -7.7) * u, 1.0 * u, _GOLD)
		"boots":
			var boot := _pts(c, u, [Vector2(-6.5, -9.5), Vector2(1.5, -9.5), Vector2(1.5, 1.5), Vector2(7.5, 3.5), Vector2(9.5, 6.5),
				Vector2(9.0, 9.5), Vector2(-7.0, 9.5)])
			b.poly(boot, base_col.darkened(0.2), ol)
			b.polygon(_pts(c, u, [Vector2(-6.5, -9.5), Vector2(-2.0, -9.5), Vector2(-2.0, 6.0), Vector2(-7.0, 6.0)]), base_col)
			b.rect(Rect2(c + Vector2(-7.0, 7.4) * u, Vector2(16.0, 2.1) * u), dark)  # the sole
			b.rect(Rect2(c + Vector2(-6.6, -9.5) * u, Vector2(8.1, 2.0) * u), base_col.lightened(0.12))  # the cuff
			match id:
				"climbing_boots":
					for k in 4:
						var y := -5.5 + k * 2.6
						b.line(c + Vector2(-1.0, y) * u, c + Vector2(1.8, y + 1.2) * u, Color(0.9, 0.85, 0.7), thin)
				"hobnail_boots":
					for k in 6:
						b.dot(c + Vector2(-5.5 + k * 2.7, 9.6) * u, 0.9 * u, Palette.STEEL)
					b.line(c + Vector2(-6.4, -2.0) * u, c + Vector2(1.4, -2.0) * u, dark, maxf(0.7, 0.6 * u))
				_:
					b.line(c + Vector2(-4.5, -6.0) * u, c + Vector2(-5.0, 4.0) * u, Color(lit, 0.6), maxf(0.7, 0.6 * u))
		"cloak":
			var cl := _pts(c, u, [Vector2(-3.0, -9.5), Vector2(3.0, -9.5), Vector2(6.0, -6.0), Vector2(9.5, 9.0), Vector2(4.0, 10.0),
				Vector2(0, 9.0), Vector2(-4.0, 10.0), Vector2(-9.5, 9.0), Vector2(-6.0, -6.0)])
			b.poly(cl, base_col.darkened(0.25), ol)
			b.polygon(_pts(c, u, [Vector2(-3.0, -9.5), Vector2(0, -9.5), Vector2(-1.0, 9.0), Vector2(-4.0, 10.0), Vector2(-9.5, 9.0), Vector2(-6.0, -6.0)]), base_col)
			for x in [-4.5, 1.5, 5.0]:
				b.line(c + Vector2(x * 0.4, -5.5) * u, c + Vector2(x, 9.0) * u, Color(dark, 0.7), thin)
			b.ball(c + Vector2(0, -7.6) * u, 1.8 * u, _GOLD, true)  # the clasp
			if id == "dusk_cloak":
				for v in [Vector2(-5.0, 3.0), Vector2(3.5, 6.0), Vector2(-1.5, 0.0)]:
					b.dot(c + v * u, 0.7 * u, Color(0.85, 0.82, 1.0, 0.8))
			elif id == "travel_cloak":
				b.rect(Rect2(c + Vector2(2.6, 1.0) * u, Vector2(3.4, 3.0) * u), base_col.lightened(0.15))  # a patch
				b.line(c + Vector2(2.6, 1.0) * u, c + Vector2(6.0, 1.0) * u, dark, maxf(0.6, 0.4 * u))
		"backpack":
			var big := id in ["satchel", "climbers_pack"]
			var hw := 8.0 if big else 6.0
			var top := -5.0 if big else -2.0
			b.arc(c + Vector2(0, top) * u, 4.4 * u, PI, TAU, 8, Palette.OUTLINE, 2.4 * u)
			b.arc(c + Vector2(0, top) * u, 4.4 * u, PI, TAU, 8, dark, 1.4 * u)  # the strap
			var bag := _pts(c, u, [Vector2(-hw, top), Vector2(hw, top), Vector2(hw + 0.6, 9.0), Vector2(-hw - 0.6, 9.0)])
			b.poly(bag, base_col.darkened(0.15), ol)
			b.polygon(_pts(c, u, [Vector2(-hw, top), Vector2(0, top), Vector2(0, 9.0), Vector2(-hw - 0.6, 9.0)]), base_col)
			b.poly(_pts(c, u, [Vector2(-hw - 0.3, top - 0.5), Vector2(hw + 0.3, top - 0.5), Vector2(hw, top + 5.5), Vector2(-hw, top + 5.5)]), base_col.darkened(0.3), ol * 0.8)  # the flap
			b.rect(Rect2(c + Vector2(-1.2, top + 4.4) * u, Vector2(2.4, 2.6) * u), _GOLD)
			if not big:
				b.rect(Rect2(c + Vector2(-9.5, 3.0) * u, Vector2(19.0, 1.8) * u), Color(0.2, 0.13, 0.08))  # the belt
		"amulet":
			b.arc(c + Vector2(0, -3.0) * u, 7.0 * u, PI * 1.05, TAU - PI * 0.05, 14, Color(0.85, 0.78, 0.55), maxf(0.9, 0.8 * u))  # the cord
			if id == "bone_charm":
				var tooth := _pts(c, u, [Vector2(-3.0, 2.0), Vector2(3.0, 2.0), Vector2(1.8, 6.0), Vector2(0, 10.0), Vector2(-1.8, 6.0)])
				b.poly(tooth, base_col.darkened(0.15), ol)
				b.polygon(_pts(c, u, [Vector2(-3.0, 2.0), Vector2(0, 2.0), Vector2(0, 10.0), Vector2(-1.8, 6.0)]), base_col)
				b.ball(c + Vector2(0, 1.2) * u, 1.5 * u, _GOLD, true)
			else:
				b.ball(c + Vector2(0, 4.6) * u, 4.4 * u, base_col, true)
				b.dot(c + Vector2(-1.4, 3.0) * u, 1.2 * u, Color(1, 0.9, 0.7, 0.8))
				b.ball(c + Vector2(0, -0.6) * u, 1.3 * u, _GOLD, true)
		"ring":
			var rc := c + Vector2(0, 2.0) * u
			b.arc(rc, 6.2 * u, 0.0, TAU, 20, Palette.OUTLINE, 3.6 * u)
			var stone := id in ["garnet_ring", "pearl_ring"]
			var band := _GOLD if stone else base_col
			b.arc(rc, 6.2 * u, 0.0, TAU, 20, band.darkened(0.15), 2.4 * u)
			b.arc(rc, 6.2 * u, PI * 0.95, PI * 1.6, 8, band.lightened(0.3), 1.0 * u)
			if stone:
				b.ball(rc + Vector2(0, -6.6) * u, 3.0 * u, base_col, true)
				b.dot(rc + Vector2(-0.9, -7.6) * u, 0.9 * u, Color(1, 0.85, 0.85, 0.9))
		_:
			b.ball(c, s * 0.5, base_col, true)
