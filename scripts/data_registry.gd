extends RefCounted
## The Data editor's engine: which of the game's tables can be changed from
## inside the game (Dev tools -> Edit game data, data_page.gd), and how the
## changes are kept.
##
## The game's words, numbers and colours live in the scripts' tables
## (entity.gd TIPS, items.gd ITEMS, train.gd BASE_PRICE, ui.gd GOLD...).
## Those tables are `static var`s, so a change can be written straight into
## them while the game runs. Every change is named by its path: the script's
## file name, the table, then the keys down to the value, joined by "/":
##
##   items/ITEMS/draught/heal          the healing draught's heal (a number)
##   entity/TIPS/stair/tip             the Entity's tip about stairs (words)
##   ui/GOLD                           the menus' gold (a colour, "#rrggbbaa")
##   puzzles.lock/TEXT/quiet           (a script in a folder: "." for "/")
##
## The changes are kept in a file, in this form (a list of paths and values;
## anything not listed stays as the scripts have it):
##
##   {"format": 1, "changes": {"items/ITEMS/draught/heal": 45, ...}}
##
## Two files, read at startup, the second on top of the first:
##   res://data/overrides.json  the project's file: run from the Godot editor,
##       Save writes here, so the change shows in GitHub Desktop to commit.
##       Committed, it's in every copy of the game, the web build included.
##   user://overrides.json  this device's own (the web build, a phone):
##       changes tried here; Copy changes hands them on (to Claude, or to
##       Paste changes on the computer) to make them part of the project.
##       It can also put a project change back to its default here ("reset").
##
## Never let an edit break the game: a value of the wrong kind is refused,
## numbers are kept within bounds, and words keep their %d / %s blanks.

const TestRun := preload("res://scripts/test_run.gd")
const PROJECT_PATH := "res://data/overrides.json"
const LOCAL_PATH := "user://overrides.json"
const FORMAT := 1

## The editor's tabs: [id, name]. "changes" is the list of what you changed.
const GROUPS := [["words", "Words"], ["numbers", "Numbers"], ["colours", "Colours"], ["looks", "Appearance"], ["changes", "My changes"]]

## When a change shows, by section ("when"): at once; when a page or screen
## is next opened; on the next floor; or only after the game restarts.
const WHEN := {
	"live": "",
	"page": "shows when a page is next opened",
	"floor": "shows on the next floor",
	"restart": "applies after a restart",
}

## The sections: what each one lets you change. "tables" are "file/TABLE"
## (a table, or a single value). "kinds" are what can be edited there:
## "text", "number", "colour", "bool". "skip": keys never offered (ids the
## code looks up, layout numbers). "names": friendlier names for tables.
## "hook": what to refresh after a change ("ui": the menus' look, "icons":
## the cached item pictures).
const SECTIONS := [
	# --- words ---
	{"id": "entity", "group": "words", "name": "The Entity's words", "when": "live",
		"tables": ["entity/TEXT", "entity/LINES", "entity/TIPS", "entity/ROOM_TIPS"], "kinds": ["text"],
		"names": {"TEXT": "Its name and labels", "LINES": "Lines", "TIPS": "Tips", "ROOM_TIPS": "Room tips"}},
	{"id": "makers", "group": "words", "name": "The Makers", "when": "live",
		"tables": ["makers/MAKERS", "makers/TEXT", "makers/ANSWERS", "makers/PLEA", "makers/VESSEL_PLEA", "makers/SECRET_BONDS"], "kinds": ["text"],
		"names": {"MAKERS": "The Makers", "TEXT": "Words", "PLEA": "The plea", "VESSEL_PLEA": "The vessel plea"}},
	{"id": "items_words", "group": "words", "name": "Items and camps", "when": "live",
		"tables": ["items/ITEMS", "items/RECALL", "items/CRYSTAL", "items/BELT", "items/CAMP", "items/CAMP_RUNES", "items/CRAFT"], "kinds": ["text"]},
	{"id": "gear_words", "group": "words", "name": "Gear", "when": "live",
		"tables": ["gear/RARITIES", "gear/TRAITS", "gear/NAMED", "gear/ARMOR", "gear/PIECES", "gear/SLOT_NAMES", "gear/TEXT", "gear/HEIRLOOM_TEXT", "gear/LASTING_RUNES"], "kinds": ["text"],
		"names": {"NAMED": "Named pieces", "PIECES": "Worn pieces", "TEXT": "Words", "HEIRLOOM_TEXT": "Heirlooms"}},
	{"id": "weapons_words", "group": "words", "name": "Weapons", "when": "live",
		"tables": ["weapons/WEAPONS", "weapons/ESSENCE_SHOT", "weapons/GUN_TEXT"], "kinds": ["text"],
		"names": {"ESSENCE_SHOT": "Essence shot (enchanted pistols)", "GUN_TEXT": "Pistols' words"}},
	{"id": "bonds_words", "group": "words", "name": "Bonds and marks", "when": "live",
		"tables": ["bonds/BONDS", "bonds/PART_NAMES", "bonds/PASSIVE_TEXT", "bonds/RANK_NAMES"], "kinds": ["text"], "names": {"PART_NAMES": "Body parts", "PASSIVE_TEXT": "A passive's ranks", "RANK_NAMES": "Rank numerals"}},
	{"id": "towers_words", "group": "words", "name": "Towers and rooms", "when": "live",
		"tables": ["towers/TOWERS", "towers/PROVING", "themes/THEMES"], "kinds": ["text"], "names": {"THEMES": "Rooms"}},
	{"id": "train_words", "group": "words", "name": "The train and store", "when": "page",
		"tables": ["train/TEXT", "train/OUTFITTER", "bench/TEXT", "vessel/TEXT", "loadout_page/TEXT", "stash_page/STASH_TEXT"], "kinds": ["text"],
		"names": {"TEXT": "Words", "STASH_TEXT": "The stash screen"}},
	{"id": "climb_words", "group": "words", "name": "The climb: wings, finds, mirrors", "when": "live",
		"tables": ["wings/TEXT", "lost/TEXT", "mirror/TEXT", "proving/TEXT", "doors/LOCK_TEXT", "puzzle/TEXT", "traps/KINDS", "traps/FIRE_FED", "main/FALL_TEXT"], "kinds": ["text"],
		"names": {"KINDS": "Traps"}},
	{"id": "puzzle_words", "group": "words", "name": "Puzzles", "when": "live",
		"tables": ["puzzles.eyes/TEXT", "puzzles.plates/TEXT", "puzzles.statues/TEXT", "puzzles.statues/NAMES", "puzzles.mirrors/TEXT", "puzzles.mirrors/NAMES",
			"puzzles.crumble/TEXT", "puzzles.crumble/NAMES", "puzzles.ice/TEXT", "puzzles.ice/NAMES", "puzzles.lock/TEXT", "puzzles.lock/NAMES", "puzzles.lock/RIDDLES",
			"puzzles.memory/TEXT", "puzzles.memory/NAMES"], "kinds": ["text"]},
	{"id": "secret_words", "group": "words", "name": "Secret essences and bonds", "when": "live",
		"tables": ["secret/KINDS", "secret/TEXT", "secret/STEP_TEXT", "secret_bonds/BONDS", "secret_bonds/TOOLS", "secret_bonds/TEXT"], "kinds": ["text"]},
	{"id": "unbound_words", "group": "words", "name": "The Unbound", "when": "live",
		"tables": ["unbound/TEXT", "unbound/PART_NAMES", "technique/TEXT", "technique_page/TEXT", "unbound_run/TEXT"], "kinds": ["text"]},
	{"id": "library_words", "group": "words", "name": "The library, the tree and the book", "when": "page",
		"tables": ["library/FORMS", "library/EFFECTS", "library/VARIATIONS", "library/TEXT", "spells.gryphon/FORKS", "spells.kraken/FORKS", "spells.wyvern/FORKS",
			"spells.manticore/FORKS", "spells.firebird/FORKS", "spells.chimera/FORKS", "tree/TEXT", "tree_view/TEXT", "book/TEXT", "bonds/FORK_NOTE",
			"spells.unbound_forms/TREE", "spells.unbound_effects/ECHO_ACTS", "spells.gryphon/TEXT", "spells.kraken/TEXT", "spells.wyvern/TEXT",
			"spells.manticore/TEXT", "spells.firebird/TEXT", "spells.chimera/TEXT", "spells.unbound_forms/TEXT", "essence_bench/TEXT"], "kinds": ["text"],
		"skip": ["type", "variation", "class", "form", "fork", "bare_kind"],
		"names": {"FORMS": "Forms", "EFFECTS": "Effects", "VARIATIONS": "Variations", "FORKS": "Forks (a tower's marks)", "TEXT": "Words", "FORK_NOTE": "A fork's step note",
			"TREE": "The Unbound's capstones", "ECHO_ACTS": "Echoes: what each does"}},
	{"id": "reactions_words", "group": "words", "name": "States, reactions and pacts", "when": "live",
		"tables": ["reactions/STATES", "reactions/REACTIONS", "pacts/PACTS", "pacts/GRAFT_POWER", "pacts/TEXT"], "kinds": ["text"],
		"skip": ["states", "consume", "bonds", "from", "event", "lands"],
		"names": {"STATES": "States (what a foe holds)", "REACTIONS": "Reactions (two states meet)", "PACTS": "Named pacts (two marks)",
			"GRAFT_POWER": "Menagerie: what each graft gives your creatures", "TEXT": "Words"}},
	{"id": "menu_words", "group": "words", "name": "Title, climbers and appearance", "when": "page",
		"tables": ["title/TEXT", "climbers_page/TEXT", "appearance/TEXT", "appearance/NAMES", "essence/KINDS"], "kinds": ["text"],
		"names": {"NAMES": "Names the dice offers", "KINDS": "Essences"}},
	{"id": "stations_words", "group": "words", "name": "Stations, renown, titles and boons", "when": "page",
		"tables": ["stations/STATIONS", "stations/STOPS", "stations/DRILLS", "stations/TIERS", "stations/CHALLENGES", "stations/RULES", "stations/MEDALS", "stations/TEXT",
			"renown/RANKS", "renown/TITLES", "renown/TEXT", "boons/BOONS", "boons/TEXT", "train/UPGRADES"], "kinds": ["text"],
		"skip": ["rule", "tower", "stops", "waves", "rules", "foes", "start_item"],
		"names": {"STATIONS": "Stations", "STOPS": "A station's stops", "DRILLS": "The gym's drills", "TIERS": "The tournament's tiers and bouts", "CHALLENGES": "Challenges",
			"RULES": "Bout rules", "MEDALS": "Medals", "RANKS": "Renown ranks", "TITLES": "Titles", "BOONS": "Boons", "UPGRADES": "The outfitter's upgrades"}},
	# --- numbers ---
	{"id": "prices", "group": "numbers", "name": "Store prices", "when": "live",
		"tables": ["train/BASE_PRICE", "train/RARITY_PRICE", "train/SUPPLY_PRICE", "train/ANY_PRICE", "train/DEFAULT_PRICE", "train/SELL_SHARE", "train/WORN_SELL", "train/TODAY_ODDS"], "kinds": ["number"],
		"names": {"BASE_PRICE": "Base prices", "RARITY_PRICE": "Times by rarity", "SUPPLY_PRICE": "Supplies", "ANY_PRICE": "Paid in any essence",
			"DEFAULT_PRICE": "Price of anything else", "SELL_SHARE": "Share paid when selling", "WORN_SELL": "Share paid for worn gear", "TODAY_ODDS": "Today's special: rarity odds"}},
	{"id": "climb_pay", "group": "numbers", "name": "Climb pay", "when": "live",
		"tables": ["train/CLIMB_PAY"], "kinds": ["number"], "names": {"CLIMB_PAY": "Crystals a climb pays"}},
	{"id": "stash_room", "group": "numbers", "name": "The stash", "when": "page",
		"tables": ["train/CHEST_SIZE"], "kinds": ["number"], "names": {"CHEST_SIZE": "Pieces the stash holds"}},
	{"id": "growth", "group": "numbers", "name": "Mark growth and essence", "when": "live",
		"tables": ["profile/STEP_XP", "profile/AFFINITY_WEIGHT", "profile/OTHER_WEIGHT", "profile/STEP_RATE", "profile/NEW_MARK_SOAK", "profile/SOAK_RATE", "profile/MARK_FULL",
			"profile/BODY_DRAG", "profile/FAINT_DEBT", "profile/ATTRIBUTE_CAP", "profile/ATTRIBUTE_HALF", "profile/ATTRIBUTES", "essence/DROPS"], "kinds": ["number"],
		"names": {"STEP_XP": "Essence for each step", "AFFINITY_WEIGHT": "Own-kind essence counts", "OTHER_WEIGHT": "Other essence counts", "STEP_RATE": "Step growth rate",
			"NEW_MARK_SOAK": "Soaked to take a new mark", "SOAK_RATE": "Soak rate", "MARK_FULL": "A mark is full at", "BODY_DRAG": "Slower growth as marks spread",
			"FAINT_DEBT": "A faint mark's extra essence", "ATTRIBUTE_CAP": "Attribute bonus at most", "ATTRIBUTE_HALF": "Density for half the bonus", "DROPS": "Essence monsters drop"}},
	{"id": "climber_numbers", "group": "numbers", "name": "The climber's core numbers", "when": "live",
		"tables": ["combat/CLIMBER", "combat/FOES"], "kinds": ["number"],
		"names": {"CLIMBER": "The climber: health, stamina, parry, roll", "FOES": "Every monster's attack"}},
	{"id": "bonds_numbers", "group": "numbers", "name": "Marks' spells (costs, damage, reach...)", "when": "live",
		"tables": ["bonds/BONDS"], "kinds": ["number"], "skip": ["learn"], "names": {"BONDS": "Each bond's spells, step by step"}},
	{"id": "monsters", "group": "numbers", "name": "Monsters", "when": "floor",
		"tables": ["enemy/TYPES", "enemy/CHAMPION", "floors/MONSTERS", "floors/CURVE"], "kinds": ["number"], "skip": ["radius", "size", "from"],
		"names": {"TYPES": "Health, speed, damage", "CHAMPION": "Champions (times)", "MONSTERS": "How often they come", "CURVE": "Harder with height (per floor)"}},
	{"id": "items_numbers", "group": "numbers", "name": "Items and camps", "when": "live",
		"tables": ["items/ITEMS", "items/BELT", "items/CAMP", "items/CRYSTAL", "items/RECALL", "lost/WEAPON_CHANCE", "lost/CACHE_CHANCE", "vessel/CAPACITY", "vessel/VAULT_CHANCE"], "kinds": ["number"]},
	{"id": "gear_numbers", "group": "numbers", "name": "Gear and drops", "when": "live",
		"tables": ["gear/RARITIES", "gear/RARITY_ODDS", "gear/TOWER_PIECE_CHANCE", "gear/TRAITS", "gear/CAPS", "gear/WEAR", "gear/WEAR_BY", "gear/EMBER_BURN",
			"gear/WEAPON_DROP_WEIGHT", "gear/ARMOR", "gear/PIECES", "gear/NAMED", "gear/REGARDED_DROP"], "kinds": ["number"],
		"names": {"REGARDED_DROP": "A beast leaves its Regarded piece (chance)", "RARITY_ODDS": "Rarity odds by floor", "CAPS": "Bonus caps", "WEAR": "Wear", "WEAPON_DROP_WEIGHT": "Weapon drop weights", "PIECES": "Worn pieces", "NAMED": "Named pieces"}},
	{"id": "weapons_numbers", "group": "numbers", "name": "Weapons", "when": "live",
		"tables": ["weapons/WEAPONS", "weapons/MEMORY", "weapons/ESSENCE_SHOT"], "kinds": ["number"],
		"names": {"ESSENCE_SHOT": "Essence shot (enchanted pistols)"}},
	{"id": "bench_numbers", "group": "numbers", "name": "Workshop and vessel", "when": "live",
		"tables": ["bench/BREW", "bench/TEMPER", "bench/TEMPER_RARITY", "bench/TEMPER_DENSITY", "bench/INSCRIBE", "vessel/BREW", "vessel/TRADE"], "kinds": ["number"],
		"names": {"BREW": "Brewing costs", "TEMPER": "Tempering costs", "TRADE": "Vessel trade"}},
	{"id": "rewards", "group": "numbers", "name": "Wings, rewards and the Proving", "when": "floor",
		"tables": ["wings/REWARD", "wings/WAVES", "wings/SECRET", "wings/FAIL_MODES", "proving/PRIZE", "proving/CAST_DOWN", "mirror/ROOM", "mirror/PRIZE"], "kinds": ["number"],
		"names": {"ROOM": "Mirror rooms", "PRIZE": "Prizes"}},
	{"id": "traps", "group": "numbers", "name": "Traps", "when": "floor",
		"tables": ["traps/RULES", "traps/KINDS"], "kinds": ["number"], "skip": ["len"]},
	{"id": "makers_numbers", "group": "numbers", "name": "The Makers", "when": "live",
		"tables": ["makers/FRAGMENT", "makers/REVEAL", "makers/GLIMPSE", "makers/INTERRUPT", "makers/PLEA_ODDS", "secret_bonds/BRIBE"], "kinds": ["number", "bool"]},
	{"id": "library_numbers", "group": "numbers", "name": "The library: forms, effects, variations, forks", "when": "live",
		"tables": ["library/FORMS", "library/EFFECTS", "library/VARIATIONS", "spells.gryphon/FORKS", "spells.kraken/FORKS", "spells.wyvern/FORKS",
			"spells.manticore/FORKS", "spells.firebird/FORKS", "spells.chimera/FORKS", "tree/SKIP_COST",
			"spells.unbound_forms/TREE", "spells.unbound_effects/ECHO_ACTS", "main/GRAFT_DROP", "spells.firebird/CRATER", "spells.chimera/AWAKE"], "kinds": ["number"], "skip": ["learn", "fork"],
		"names": {"FORMS": "Forms", "EFFECTS": "Effects", "VARIATIONS": "Variations", "FORKS": "Forks (a tower's marks)", "SKIP_COST": "Learning a passed side (crystal essence: base, per level)",
			"GRAFT_DROP": "Grafts slain monsters leave (Grafter: chance by grafts carried; seconds on the floor)", "CRATER": "Meteor's crater (its Apex)", "AWAKE": "Chimera Form's grafts that fire by themselves (its Apex)",
			"TREE": "The Unbound's capstones", "ECHO_ACTS": "Echoes: what each does"}},
	{"id": "reactions_numbers", "group": "numbers", "name": "States, reactions and pacts", "when": "live",
		"tables": ["reactions/STATES", "reactions/REACTIONS", "reactions/RULES", "reactions/CLIMBER", "pacts/PACTS"], "kinds": ["number", "bool"],
		"skip": ["states", "consume", "bonds", "from", "event"],
		"names": {"STATES": "States: how long, how much", "REACTIONS": "Reactions: reach, damage, how soon again", "RULES": "Reactions: growth and chains",
			"CLIMBER": "Monsters giving the climber states (off unless enabled)", "PACTS": "Named pacts"}},
	{"id": "secret_numbers", "group": "numbers", "name": "Secret essences", "when": "live",
		"tables": ["secret/STEPS", "secret/GROWTH", "secret/REFUSE_HEALTH", "secret/UNDO_CAP"], "kinds": ["number"]},
	{"id": "stations_numbers", "group": "numbers", "name": "Stations, renown and boons", "when": "page",
		"tables": ["stations/DRILLS", "stations/TIERS", "stations/CHALLENGES", "stations/RULE_FX", "stations/RELIC_CHANCE", "stations/REPEAT",
			"renown/RANKS", "renown/CLIMB", "renown/TITLES", "boons/BOONS", "train/UPGRADES", "train/UPGRADE_FX", "train/STOCK_ODDS"], "kinds": ["number"],
		"skip": ["waves", "rules", "foes", "stops"],
		"names": {"DRILLS": "Drills: time, medals, renown", "TIERS": "Tiers: fee, crystals, renown", "CHALLENGES": "Challenges: rewards", "RULE_FX": "Bout rules' numbers",
			"RELIC_CHANCE": "A repeat tier win gives a relic (chance)", "REPEAT": "A repeat win pays (share)", "RANKS": "Renown for each rank", "CLIMB": "Renown a climb earns",
			"TITLES": "Titles: deeds' numbers", "BOONS": "Boons: prices, levels, ranks", "UPGRADES": "The outfitter's upgrades: ranks", "UPGRADE_FX": "The outfitter's upgrades: numbers",
			"STOCK_ODDS": "Better stock: today's piece odds"}},
	# --- colours ---
	{"id": "essence_colours", "group": "colours", "name": "Essences", "when": "live", "hook": "icons",
		"tables": ["essence/KINDS", "secret/KINDS"], "kinds": ["colour"]},
	{"id": "rarity_colours", "group": "colours", "name": "Rarities and items", "when": "live", "hook": "icons",
		"tables": ["gear/RARITIES", "items/ITEMS"], "kinds": ["colour"]},
	{"id": "menu_colours", "group": "colours", "name": "Menus and HUD", "when": "page", "hook": "ui",
		"tables": ["ui/GOLD", "ui/TEXT", "ui/DIM", "ui/FAINT", "ui/GILT", "ui/GILT_HI", "ui/GILT_DEEP", "ui/PERIWINKLE", "ui/VIOLET", "ui/BLOOD",
			"ui/VOID", "ui/STONE", "ui/STONE_2", "ui/STONE_3", "ui/LINE", "ui/LINE_HI", "ui/PANEL", "ui/PANEL_EDGE", "ui/MENU_PANEL",
			"ui/SLOT", "ui/SLOT_EDGE", "ui/SLOT_ON", "ui/BUTTON", "ui/BUTTON_HOVER", "ui/BUTTON_DOWN", "ui/SHADE",
			"ui/GOOD", "ui/BAD", "ui/HEALTH", "ui/STAMINA", "ui/ENTITY_BG", "ui/ENTITY_EDGE"], "kinds": ["colour"],
		"names": {"TEXT": "Text (parchment ink)", "DIM": "Dim text", "FAINT": "Faint text", "GOLD": "Gold (lettering)", "GILT": "Gilt (ornament)",
			"VOID": "Void (behind everything)", "SHADE": "Shade behind menus", "PANEL": "HUD panels", "MENU_PANEL": "Menu panels"}},
	{"id": "book_colours", "group": "colours", "name": "The climber's book", "when": "page",
		"tables": ["book/RIBBONS", "book/LEATHER", "book/PAGE", "book/PAGE_EDGE"], "kinds": ["colour"],
		"names": {"RIBBONS": "Its ribbons", "LEATHER": "Leather", "PAGE": "Pages", "PAGE_EDGE": "Page edges"}},
	{"id": "world_colours", "group": "colours", "name": "The world", "when": "floor",
		"tables": ["palette/VOID", "palette/FLOOR", "palette/FLOOR_LIGHT", "palette/FLOOR_GAP", "palette/MOSS", "palette/WALL_TOP", "palette/WALL_EDGE", "palette/WALL_FACE",
			"palette/TORCH", "palette/DOOR_WOOD", "palette/DOOR_IRON", "palette/DOOR_STONE", "palette/FOG_UNSEEN", "palette/PLAYER_LIGHT", "palette/STAIR_LIGHT",
			"palette/WARD_LIGHT", "palette/EYE_LIGHT", "palette/FIRE_LIGHT", "palette/OUTLINE", "palette/STEEL", "palette/WOOD", "palette/DANGER", "palette/VIGNETTE"],
		"kinds": ["colour", "number"], "names": {"VIGNETTE": "Darkened corners"}},
	{"id": "tower_colours", "group": "colours", "name": "Tower tints", "when": "floor",
		"tables": ["palette/TOWER_FOG", "palette/TOWER_TINT", "towers/TOWERS", "themes/THEMES"], "kinds": ["colour"],
		"names": {"TOWER_FOG": "Darkness", "TOWER_TINT": "Stone tint", "TOWERS": "Stone, ambient and torch", "THEMES": "Room tints"}},
	{"id": "monster_colours", "group": "colours", "name": "Monsters and traps", "when": "live",
		"tables": ["enemy/TYPES", "enemy/CHAMPION", "enemy/SHADE", "traps/KINDS"], "kinds": ["colour"], "names": {"KINDS": "Traps"}},
	{"id": "reactions_colours", "group": "colours", "name": "States, reactions and pacts", "when": "live",
		"tables": ["reactions/STATES", "reactions/REACTIONS", "pacts/PACTS"], "kinds": ["colour"],
		"names": {"STATES": "States (the badges over a foe)", "REACTIONS": "Reactions (their word and light)", "PACTS": "Named pacts"}},
	{"id": "station_colours", "group": "colours", "name": "Stations and medals", "when": "page",
		"tables": ["stations/STATIONS", "stations/MEDALS"], "kinds": ["colour"], "names": {"STATIONS": "Stations' lamps", "MEDALS": "Medals"}},
	# --- appearance ---
	{"id": "looks", "group": "looks", "name": "Appearance options", "when": "page",
		"tables": ["appearance/OPTIONS", "appearance/ROWS", "appearance/TABS", "appearance/ACCENTS"], "kinds": ["text", "colour"], "names": {"OPTIONS": "Options", "ROWS": "Row names", "TABS": "Tabs", "ACCENTS": "Small things (scarf, metal, feather, face)"}},
]

## Keys never offered anywhere: ids and names the code looks things up by.
const SKIP_KEYS := ["id", "group", "kind", "key", "sound", "hit_sound", "equip", "step", "icon", "slot", "part", "theme", "beast_kind",
	"summit", "floor", "feature", "door", "emblem", "trigger", "shape", "base", "rarity", "role", "flip",
	"shot_sound", "crack", "reload_sound", "load_sound", "blade_sound"]

## Friendlier names for common keys (the rest are written out from the key).
const KEY_NAMES := {"desc": "description", "dmg": "damage", "hp": "health", "more": "Archive text", "tip": "tip",
	"short": "short name", "color": "colour", "blurb": "description", "sub": "subtitle", "drop_weight": "drop weight"}

## Number bounds where the ten-times rule doesn't fit: by key name (whole
## key or its end): [lowest, highest, step].
const NUMBER_HINTS := {
	"chance": [0.0, 1.0, 0.01], "odds": [0.0, 100.0, 1.0], "share": [0.0, 1.0, 0.01], "keep": [0.0, 1.0, 0.01],
	"SELL_SHARE": [0.0, 1.0, 0.01], "WORN_SELL": [0.0, 1.0, 0.01], "MARK_FULL": [0.1, 1.0, 0.01], "VIGNETTE": [0.0, 1.0, 0.01],
	"ATTRIBUTE_CAP": [0.0, 1.0, 0.01], "roll_iframes": [0.0, 1.0, 0.01], "CHEST_SIZE": [8.0, 200.0, 1.0],
}

## Words the owner never wants in the game (CLAUDE.md): a warning, not a block.
const BANNED := ["attunement", "attunements", "spire", "spires", "trial", "trials", "judgment", "judgments", "judgement", "judgements", "mana"]

## Where the files are (tests point these elsewhere).
static var project_path := PROJECT_PATH
static var local_path := LOCAL_PATH
## -1: write the project file when run from the Godot editor; 0 / 1 to force (tests).
static var project_write := -1

## The changes from each file, and what's applied now.
static var project := {}  # res://data/overrides.json: path -> value (as kept in the file)
static var local := {}  # user://overrides.json
static var local_reset := []  # project changes put back to their default on this device
static var applied := {}  # path -> the value applied now
static var defaults := {}  # path -> the scripts' own value (kept the first time a path changes)
static var problems := []  # entries the files had that couldn't be applied (and why)
static var dirty := false  # changed since the last save
static var started := false
static var _scripts := {}  # file id -> Script
static var _index := []  # every editable field (built once): see fields()
static var _sections := {}  # id -> section


# --- startup ---------------------------------------------------------------------

## Reads both files and applies them (main.gd calls this first thing). Safe
## to call again: it starts from the scripts' own values each time.
static func startup() -> bool:
	if Engine.has_meta("sixfold_test") and local_path == LOCAL_PATH:
		local_path = TestRun.path("user://test_overrides.json")  # (tests never touch the real one)
	load_files()
	apply_effective()
	started = true
	dirty = false
	return true


static func load_files() -> void:
	problems.clear()
	project = _read(project_path).get("changes", {})
	var mine := _read(local_path)
	local = mine.get("changes", {})
	local_reset = mine.get("reset", [])


static func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var text := FileAccess.get_file_as_string(path)
	var data = JSON.parse_string(text) if text.strip_edges() != "" else {}
	if not data is Dictionary:
		problems.append("%s isn't a changes file" % path)
		return {}
	if data.has("changes") and not data["changes"] is Dictionary:
		problems.append("%s: its changes aren't a list of paths" % path)
		return {}
	if data.has("reset") and not data["reset"] is Array:
		data["reset"] = []
	return data


## The changes in force: the project's, less those reset here, plus this device's.
static func effective() -> Dictionary:
	var out := {}
	for p in project:
		if not p in local_reset:
			out[p] = project[p]
	for p in local:
		out[p] = local[p]
	return out


## Puts every table back as the scripts have it, then applies the changes in force.
static func apply_effective() -> void:
	var eff := effective()
	for p in applied.keys():
		if not eff.has(p):
			_write(p, defaults[p])
	applied.clear()
	for p in eff:
		var r := _check(p, eff[p])
		if r["error"] != "":
			problems.append("%s: %s" % [p, r["error"]])
			continue
		_remember_default(p)
		_write(p, r["value"])
		applied[p] = r["value"]


# --- finding values ----------------------------------------------------------------

static func script_for(file: String) -> Script:
	if not _scripts.has(file):
		var path := "res://scripts/%s.gd" % file.replace(".", "/")
		_scripts[file] = load(path) if ResourceLoader.exists(path) else null
	return _scripts[file]


## [container, key] for a path, or [] if it leads nowhere. A single value
## (a path of two parts) gives [script, name].
static func _locate(path: String) -> Array:
	var segs := path.split("/")
	if segs.size() < 2:
		return []
	var s := script_for(segs[0])
	if s == null or not _has_static(s, segs[1]):
		return []
	if segs.size() == 2:
		return [s, segs[1]]
	var c = s.get(segs[1])
	for i in range(2, segs.size()):
		var k = _key_in(c, segs[i])
		if k == null:
			return []
		if i == segs.size() - 1:
			return [c, k]
		c = c[k]
	return []


## A static var (not a const, which can't be changed) of that name.
static func _has_static(s: Script, name: String) -> bool:
	var k := "%s:%s" % [s.resource_path, name]
	if not _static_ok.has(k):
		_static_ok[k] = name in s and not s.get_script_constant_map().has(name)
	return _static_ok[k]


static var _static_ok := {}


## The key a path's part names in a table, or null.
static func _key_in(c, seg: String):
	if c is Array:
		if seg.is_valid_int() and int(seg) >= 0 and int(seg) < c.size():
			return int(seg)
		return null
	if c is Dictionary:
		if c.has(seg):
			return seg
		if seg.is_valid_int() and c.has(int(seg)):
			return int(seg)
	return null


## The value at a path now (null if there's none).
static func value(path: String):
	var at := _locate(path)
	if at.is_empty():
		return null
	if at[0] is Script:
		return at[0].get(at[1])
	return at[0][at[1]]


static func _write(path: String, v) -> void:
	var at := _locate(path)
	if at.is_empty():
		return
	if at[0] is Script:
		at[0].set(at[1], v)
	else:
		at[0][at[1]] = v


static func _remember_default(path: String) -> void:
	if not defaults.has(path):
		defaults[path] = value(path)


## The scripts' own value for a path.
static func default_of(path: String):
	return defaults[path] if defaults.has(path) else value(path)


static func is_changed(path: String) -> bool:
	return applied.has(path)


# --- checking a value ------------------------------------------------------------------

## The kind of an editable value: "text", "number", "colour", "bool", or ""
## (not editable: ids, lists, positions...).
static func kind_of(v) -> String:
	match typeof(v):
		TYPE_STRING:
			return "text" if is_words(v) else ""
		TYPE_INT, TYPE_FLOAT:
			return "number"
		TYPE_COLOR:
			return "colour"
		TYPE_BOOL:
			return "bool"
	return ""


## Words a player reads, not an id the code looks up ("draught", "fire_flask").
static func is_words(s: String) -> bool:
	if s.begins_with("res://") or s.strip_edges() == "":
		return false
	if _id_re == null:
		_id_re = RegEx.create_from_string("^[a-z0-9_]+$")
	return _id_re.search(s) == null


static var _id_re: RegEx


## Checks a new value for a path: {"value": the value to use, "error": ""}
## or {"error": why it's refused}. Numbers come back as the default's type
## (whole numbers stay whole) and within bounds; colours may be "#rrggbbaa".
static func _check(path: String, v) -> Dictionary:
	var f := field(path)
	if f.is_empty():
		return {"error": "not a field the editor knows"}
	var d = default_of(path)
	match f["kind"]:
		"text":
			if not v is String:
				return {"error": "needs words"}
			var want := placeholders(String(d))
			if placeholders(v) != want:
				return {"error": "keep the blanks %s as they are" % " ".join(want)}
			return {"value": v, "error": ""}
		"number":
			if not (v is int or v is float):
				if v is String and v.strip_edges().is_valid_float():
					v = float(v)
				else:
					return {"error": "needs a number"}
			if is_nan(float(v)) or is_inf(float(v)):
				return {"error": "needs a number"}
			var b := bounds(path)
			var x := clampf(float(v), b[0], b[1])
			if d is int:
				return {"value": int(round(x)), "error": ""}
			return {"value": x, "error": ""}
		"colour":
			if v is Color:
				return {"value": v, "error": ""}
			if v is String and Color.html_is_valid(v):
				return {"value": Color.html(v), "error": ""}
			return {"error": "needs a colour (#rrggbb)"}
		"bool":
			if v is bool:
				return {"value": v, "error": ""}
			return {"error": "needs on or off"}
	return {"error": "can't be edited"}


## The blanks code fills in a line of words (%d, %s, %.1f, %%...), in order.
static func placeholders(s: String) -> Array:
	var out: Array = []
	var re := RegEx.new()
	re.compile("%[-+ 0#]*[0-9]*(\\.[0-9]+)?[a-zA-Z%]")
	for m in re.search_all(s):
		out.append(m.get_string())
	return out


## A number's [lowest, highest, step].
static func bounds(path: String) -> Array:
	var segs := path.split("/")
	var key: String = segs[segs.size() - 1]
	var d = default_of(path)
	var df := float(d) if (d is int or d is float) else 0.0
	for k in NUMBER_HINTS:
		if key == k or key.ends_with("_" + k) or (key.ends_with(k) and key.length() > k.length() and k.length() > 4):
			var h: Array = NUMBER_HINTS[k]
			if df >= h[0] and df <= h[1]:
				return [h[0], h[1], 1.0 if d is int else h[2]]
	var lo := 0.0
	var hi := 0.0
	if df > 0.0:
		hi = df * 10.0
	elif df < 0.0:
		lo = df * 10.0
	else:
		hi = 10.0 if d is int else 1.0
	if d is int:
		hi = maxf(hi, 10.0)
		return [lo, hi, 1.0]
	var mag := maxf(absf(df), 0.0001)
	var step := 0.001 if mag < 0.1 else (0.01 if mag < 2.0 else (0.1 if mag < 20.0 else 1.0))
	return [lo, hi, step]


## Banned words found in a line (CLAUDE.md): the editor warns.
static func banned_in(s: String) -> Array:
	var found: Array = []
	var re := RegEx.new()
	re.compile("[A-Za-z]+")
	for m in re.search_all(s):
		var w := m.get_string().to_lower()
		if w in BANNED and not w in found:
			found.append(w)
	return found


# --- changing values ---------------------------------------------------------------------

## Changes a value (the editor's rows call this). "" if it's done, else why
## it was refused. Runs the section's refresh.
static func set_value(path: String, v) -> String:
	var r := _check(path, v)
	if r["error"] != "":
		return r["error"]
	var f := field(path)
	_remember_default(path)
	var nv = r["value"]
	var same := _same(nv, defaults[path])
	if writes_project():
		if same:
			project.erase(path)
		else:
			project[path] = to_json(nv)
		local.erase(path)
		local_reset.erase(path)
	else:
		if same:
			local.erase(path)
			if project.has(path) and not path in local_reset:
				local_reset.append(path)
		else:
			local[path] = to_json(nv)
			local_reset.erase(path)
	_write(path, nv)
	if f["kind"] == "text":
		_labels.clear()  # (a name may be in other fields' labels)
	if same:
		applied.erase(path)
	else:
		applied[path] = nv
	dirty = true
	refresh(f.get("section", ""))
	return ""


static func revert(path: String) -> void:
	if is_changed(path):
		set_value(path, default_of(path))


static func revert_all() -> void:
	for p in applied.keys():
		set_value(p, default_of(p))


static func _same(a, b) -> bool:
	if a is Color and b is Color:
		return a.is_equal_approx(b)
	if (a is float or a is int) and (b is float or b is int):
		return is_equal_approx(float(a), float(b))
	return typeof(a) == typeof(b) and a == b


## How a value is kept in the file.
static func to_json(v):
	if v is Color:
		return "#" + v.to_html(true)
	return v


## After a change: refresh what was drawn once from the old value.
static func refresh(section_id: String) -> void:
	var sec: Dictionary = _sections.get(section_id, {})
	match sec.get("hook", ""):
		"icons":
			load("res://scripts/icon_art.gd").clear_cache()
		"ui":
			load("res://scripts/icon_art.gd").clear_cache()
			script_for("ui").set("_key_style", null)


# --- saving ---------------------------------------------------------------------------------

## Saves go to the project's file when run from the Godot editor, else to this device's.
static func writes_project() -> bool:
	if project_write >= 0:
		return project_write == 1
	return OS.has_feature("editor")


## Writes the changes. Returns the file written ("" if it failed).
static func save() -> String:
	var ok := false
	var where := ""
	if writes_project():
		# Every change in force goes into the project's file (this device's
		# too: changes pasted or tried here become the project's).
		project = {}
		for p in applied:
			project[p] = to_json(applied[p])
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(project_path.get_base_dir()))
		ok = _write_file(project_path, {"format": FORMAT, "changes": _sorted(project)})
		where = project_path
		if ok:
			local.clear()
			local_reset.clear()
			if FileAccess.file_exists(local_path):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(local_path))  # (all in the project's file now)
	else:
		var data := {"format": FORMAT, "changes": _sorted(local)}
		if not local_reset.is_empty():
			data["reset"] = local_reset.duplicate()
		ok = _write_file(local_path, data)
		where = local_path
	if ok:
		dirty = false
	return where if ok else ""


static func _write_file(path: String, data: Dictionary) -> bool:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return false
	f.store_string(JSON.stringify(data, "\t", false) + "\n")
	f.close()
	return true


static func _sorted(d: Dictionary) -> Dictionary:
	var keys := d.keys()
	keys.sort()
	var out := {}
	for k in keys:
		out[k] = d[k]
	return out


## Every change in force, as a changes file (Copy changes).
static func export_text() -> String:
	var out := {}
	for p in applied:
		out[p] = to_json(applied[p])
	return JSON.stringify({"format": FORMAT, "changes": _sorted(out)}, "\t", false)


## Paste changes: applies a changes file (or a bare list of paths and values).
## Returns {"done": n, "refused": ["path: why", ...], "error": "" or why
## nothing could be read}.
static func import_text(text: String) -> Dictionary:
	var data = JSON.parse_string(text.strip_edges()) if text.strip_edges() != "" else null
	if not data is Dictionary:
		return {"done": 0, "refused": [], "error": "That isn't a changes file (it should start with { )."}
	var changes = data.get("changes", data)
	if not changes is Dictionary:
		return {"done": 0, "refused": [], "error": "Its changes aren't a list of paths."}
	var done := 0
	var refused: Array = []
	for p in changes:
		if not p is String or p == "format":
			continue
		var why := set_value(p, changes[p])
		if why == "":
			done += 1
		else:
			refused.append("%s: %s" % [p, why])
	return {"done": done, "refused": refused, "error": ""}


# --- the fields ---------------------------------------------------------------------------

static func section(id: String) -> Dictionary:
	_build()
	return _sections.get(id, {})


static func sections_in(group: String) -> Array:
	return SECTIONS.filter(func(s): return s["group"] == group)


## Every editable field: {"path", "section", "table", "kind", "label"}.
static func fields() -> Array:
	_build()
	return _index


static func fields_in(section_id: String) -> Array:
	return fields().filter(func(f): return f["section"] == section_id)


## One field by path ({} if the editor doesn't offer it). A path that's in
## several sections (an item's name and its heal) is in the one for its kind.
static func field(path: String) -> Dictionary:
	_build()
	return _by_path.get(path, {})


static var _by_path := {}


static func _build() -> void:
	if not _index.is_empty():
		return
	for sec in SECTIONS:
		_sections[sec["id"]] = sec
		for t in sec["tables"]:
			var parts: PackedStringArray = t.split("/")
			var s := script_for(parts[0])
			if s == null or not _has_static(s, parts[1]):
				push_warning("data_registry: %s isn't a static var" % t)
				continue
			_walk(sec, t, s.get(parts[1]), SKIP_KEYS + sec.get("skip", []))


static func _walk(sec: Dictionary, path: String, v, skip: Array) -> void:
	if v is Dictionary:
		for k in v:
			if (k is String and (k in skip or "/" in k)) or not (k is String or k is int):
				continue
			_walk(sec, path + "/" + str(k), v[k], skip)
		return
	if v is Array:
		for i in v.size():
			_walk(sec, path + "/" + str(i), v[i], skip)
		return
	var kind := kind_of(v)
	if v is String and path.ends_with("/history"):
		kind = "text"  # (a relic's history starts blank, for the owner to write)
	if kind == "" or not kind in sec["kinds"] or _by_path.has(path):
		return
	var f := {"path": path, "section": sec["id"], "kind": kind}
	_index.append(f)
	_by_path[path] = f


## A field's name, made from its table and keys: "Tips · Stairs · tip".
## (Kept until a name changes: names are in the labels.)
static func label(path: String) -> String:
	if _labels.has(path):
		return _labels[path]
	var segs := path.split("/")
	var f := field(path)
	var sec: Dictionary = _sections.get(f.get("section", ""), {})
	var names: Dictionary = sec.get("names", {})
	var out: Array = [names.get(segs[1], TABLE_NAMES.get(segs[1], _words(segs[1])))]
	var s := script_for(segs[0])
	var c = s.get(segs[1]) if s != null else null
	for i in range(2, segs.size()):
		var k = _key_in(c, segs[i])
		if k == null:
			break
		var child = c[k]
		var last := i == segs.size() - 1
		if not last and child is Dictionary and child.get("name") is String and is_words(child["name"]):
			out.append(child["name"])
		elif not last and child is Array and _array_name(child) != "":
			out.append(_array_name(child))
		elif last and c is Array and _array_name(c) != "":
			out.append(_slot_word(child))
		elif k is int:
			out.append("line %d" % (k + 1) if child is String else "#%d" % (k + 1))
		elif last:
			out.append(KEY_NAMES.get(k, _words(str(k)).to_lower()))
		else:
			out.append(KEY_NAMES.get(k, _words(str(k))))
		c = child
	var l := " · ".join(out)
	_labels[path] = l
	return l


static var _labels := {}

## Default names for tables (a section's "names" go first).
const TABLE_NAMES := {"TEXT": "Words", "NAMES": "Names", "TYPES": "Monsters", "KINDS": "Kinds"}


## A short list read as one thing ([id, "Name", colour]): its name. A list
## of lines isn't one (only one of its parts may be words).
static func _array_name(a: Array) -> String:
	if a.size() < 2 or a.size() > 4:
		return ""
	var name := ""
	for x in a:
		if x is String and is_words(x):
			if name != "":
				return ""
			name = x
		elif x is Array or x is Dictionary:
			return ""
	return name


static func _slot_word(v) -> String:
	match typeof(v):
		TYPE_COLOR:
			return "colour"
		TYPE_INT, TYPE_FLOAT:
			return "amount"
	return "name"


static func _words(key: String) -> String:
	var w := key.replace("_", " ").to_lower()
	return w.substr(0, 1).to_upper() + w.substr(1)


## When a field's change shows ("" at once).
static func when(path: String) -> String:
	return WHEN.get(when_id(path), "")


## "live", "page", "floor" or "restart": the field's own (WHEN_FIELDS), else its section's.
static func when_id(path: String) -> String:
	if WHEN_FIELDS.has(path):
		return WHEN_FIELDS[path]
	var sec: Dictionary = _sections.get(field(path).get("section", ""), {})
	return sec.get("when", "live")


## Fields read only once, as the game starts (main.gd sets the colour
## behind everything when it starts).
const WHEN_FIELDS := {"palette/VOID": "restart"}


## Fields whose path, name or value has all of the words searched for.
static func search(q: String, limit := 60) -> Array:
	var words := q.to_lower().split(" ", false)
	if words.is_empty():
		return []
	var out: Array = []
	for f in fields():
		var v = value(f["path"])
		var hay := ("%s %s %s" % [f["path"], label(f["path"]), str(v) if not v is Color else "#" + v.to_html(false)]).to_lower()
		var all := true
		for w in words:
			if hay.find(w) < 0:
				all = false
				break
		if all:
			out.append(f)
			if out.size() >= limit:
				break
	return out


## Every change in force: [{"path", "value", "default"}], in path order.
static func changes() -> Array:
	var keys := applied.keys()
	keys.sort()
	return keys.map(func(p): return {"path": p, "value": applied[p], "default": default_of(p)})


## A value as words, for lists and defaults.
static func show(v, most := 90) -> String:
	var s := ""
	if v is Color:
		s = "#" + v.to_html(v.a < 1.0)
	elif v is float:
		s = str(snappedf(v, 0.001))
	elif v is bool:
		s = "on" if v else "off"
	else:
		s = str(v)
	s = s.replace("\n", " ")
	return s if s.length() <= most else s.substr(0, most - 1) + "…"
