extends RefCounted
## How each tower builds its floors of rooms: the hook for giving every
## tower its own layouts (floors.gd reads it while it plans). For now every
## tower shares the same rules with only its favourite room shapes changed;
## a tower's own entry overrides any key of "default".
##   shapes        carved room shapes (rooms.gd SHAPES) on top of the tower's own
##                 favourites (`shapes` in towers.gd); a repeat makes one likelier
##   gallery       shapes for a gallery with no puzzle (the floor's big room)
##   loops         [least, most] extra ways between rooms, so a floor isn't a tree
##   oneway        the share of those ways that are doors barred from one side
##                 (opened from the far side: a shortcut back)
##   cracks        [least, most] cracked walls a floor (rooms.gd draws them)
##   crack_kinds   what a cracked wall hides (weights): a loop between two
##                 rooms, a stub corridor ending at the crack and an alcove
##                 behind it, or an alcove straight off a room
##   alcove        what an alcove holds (weights): an essence cache or a vault
##   corridor      how corridors run: "straight" (wall to facing wall)
##   scenario      the chance of a scenario room on a floor (from floor 2)
##   scenario2     the chance of a second one, from floor `scenario2_from`
##   rest          the chance of a calm rest room
##   trader        the chance of a wandering trader, from floor `trader_from`
##   kind_first    the first room after the start is a kind one (no danger)
##   own_shapes    (optional) replaces the tower's favourite shapes (towers.gd)
##                 for every room but the entrance
##   room_grow     (optional) tiles added to (or taken from, below 0) each
##                 carved room's width and height
##   prefab        how often hand-made rooms turn up, as a share of floors.gd
##                 PREFAB_CHANCE (a tower that favours its own shapes: less)
##   corridor      how corridors run: "straight", or the tower's own (its
##                 module's shape_corridors: "winding", "bridges")
##   module        (a tower's own) the script that gives the tower its own
##                 floors, scripts/towers/<tower>_floor.gd, extending
##                 scripts/towers/tower_floor.gd (the hooks and what each is
##                 for are there, and in the README's content contract). It
##                 carves the tower's own room shapes (SHAPE_MODULES below),
##                 shapes the corridors and the finished plan, places and runs
##                 the tower's own task kinds and scenario, and runs on the
##                 live floor as main.tower_floor (its system).

static var STYLES := {
	"default": {
		"shapes": ["ring", "circle", "gallery", "split", "cover"],
		"gallery": ["rect", "round", "ring", "pillars", "split", "gallery", "circle"],
		"loops": [1, 2], "loops_high": [2, 3], "loops_high_from": 7, "oneway": 0.5,
		"cracks": [1, 2], "crack_kinds": {"loop": 3.0, "stub": 2.0, "alcove": 2.0}, "alcove": {"cache": 3.0, "vault": 1.0},
		"corridor": "straight",
		"scenario": 0.75, "scenario2": 0.35, "scenario2_from": 7,
		"rest": 0.25, "trader": 0.3, "trader_from": 3,
		"kind_first": true,
	},
	# Open heights: big halls with ledges and balconies over open voids,
	# corridors that are bridges over the drop (scripts/towers/gryphon_floor.gd).
	"gryphon": {"shapes": ["open", "open", "rect", "round", "split"], "own_shapes": ["open", "open", "rect", "round"],
		"gallery": ["open", "rect", "round"], "room_grow": 0, "prefab": 0.35, "corridor": "bridges", "module": "res://scripts/towers/gryphon_floor.gd"},
	# Flooded: round and oval rooms, winding corridors, pools, and water that
	# rises and drains (scripts/towers/kraken_floor.gd).
	"kraken": {"shapes": ["circle", "circle", "ring", "round"], "own_shapes": ["circle", "circle", "round"],
		"gallery": ["circle", "ring", "circle"], "room_grow": -1, "prefab": 0.3, "corridor": "winding", "module": "res://scripts/towers/kraken_floor.gd"},
	# The Wyvern's forge: long workshop halls in a grid, cut by molten
	# channels (more ways between rooms: a grid, not a tree).
	"wyvern": {"shapes": ["workshop", "hall", "workshop", "forgehall"], "gallery": ["forgehall", "workshop", "hall"],
		"loops": [2, 3], "loops_high": [3, 4], "prefab": 0.35, "module": "res://scripts/towers/wyvern_floor.gd"},
	# The Manticore's sandstone: courtyards open to the sky, colonnades, and
	# low-walled alleys between them.
	"manticore": {"shapes": ["court", "alleys", "colonnade", "court"], "gallery": ["court", "colonnade", "court"],
		"loops": [2, 3], "prefab": 0.35, "module": "res://scripts/towers/manticore_floor.gd"},
	# The Firebird's islands of rock over the abyss, joined by bridges: few
	# ways round, updrafts across gaps, bridges that burn behind you, storms.
	"firebird": {"shapes": ["island", "atoll", "island", "island", "circle"], "own_shapes": ["island", "atoll", "island", "round"],
		"gallery": ["island", "atoll", "island"], "loops": [0, 1], "loops_high": [1, 2], "prefab": 0.25, "module": "res://scripts/towers/firebird_floor.gd"},
	# The Thornwild: grown caves and dens, tangled ways through (more loops,
	# some through thorns), brambles, spore pods.
	"chimera": {"shapes": ["cave", "den", "grotto", "cave", "den"], "own_shapes": ["cave", "den", "cave", "round"],
		"gallery": ["cave", "den", "grotto"], "loops": [2, 3], "loops_high": [2, 4], "cracks": [0, 1], "prefab": 0.25,
		"module": "res://scripts/towers/chimera_floor.gd"},
}

## Carved room shapes that belong to a tower's own script (rooms.gd carve
## hands them over): shape -> the script that carves it.
const SHAPE_MODULES := {
	"workshop": "res://scripts/towers/wyvern_floor.gd", "forgehall": "res://scripts/towers/wyvern_floor.gd",
	"court": "res://scripts/towers/manticore_floor.gd", "alleys": "res://scripts/towers/manticore_floor.gd",
	"colonnade": "res://scripts/towers/manticore_floor.gd",
	"island": "res://scripts/towers/firebird_floor.gd", "atoll": "res://scripts/towers/firebird_floor.gd",
	"cave": "res://scripts/towers/chimera_floor.gd", "den": "res://scripts/towers/chimera_floor.gd", "grotto": "res://scripts/towers/chimera_floor.gd",
}


## The tower's own floor script (its style's "module"), or null.
static func module_for(tid: String) -> Script:
	var path := String(STYLES.get(tid, {}).get("module", ""))
	return load(path) if path != "" else null


## The script that carves a tower's own room shape, or null.
static func shape_module(shape: String) -> Script:
	return load(SHAPE_MODULES[shape]) if SHAPE_MODULES.has(shape) else null


## A tower's style: its own keys over the default's.
static func for_tower(tid: String) -> Dictionary:
	var out: Dictionary = STYLES["default"].duplicate(true)
	var own: Dictionary = STYLES.get(tid, {})
	for k in own:
		out[k] = own[k]
	return out

