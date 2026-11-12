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
##   prefab        how likely hand-made rooms are, as a share of the usual
##                 (a tower whose rooms are grown or broken, not built, has
##                 fewer; its stair landing is then always a built one)
##   builder       a script that lays the tower's own floor features last
##                 (after_build: the Firebird's updrafts and burning bridges,
##                 the Thornwild's thorns, brambles and spore pods)
## Shapes may also be towers/organic.gd's: island, atoll (the Firebird's
## rooms of rock over the abyss), cave, den, grotto (the Thornwild's).

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
	"gryphon": {"shapes": ["circle", "gallery", "split", "ring"]},
	"kraken": {"shapes": ["gallery", "split", "cover", "gallery"]},
	"wyvern": {"shapes": ["ring", "cover", "ring", "gallery"]},
	"manticore": {"shapes": ["cover", "split", "ring", "cover"]},
	# Islands of rock over the abyss, joined by bridges: fewer ways round,
	# updrafts across the gaps, bridges that burn behind you, ember storms.
	"firebird": {"shapes": ["island", "atoll", "island", "island", "circle"], "gallery": ["island", "atoll", "island"],
		"loops": [0, 1], "loops_high": [1, 2], "prefab": 0.25, "builder": "res://scripts/towers/firebird_floor.gd"},
	# The Thornwild: grown caves and dens, tangled ways through (more loops,
	# some through thorns), brambles, spore pods.
	"chimera": {"shapes": ["cave", "den", "grotto", "cave", "den"], "gallery": ["cave", "den", "grotto"],
		"loops": [2, 3], "loops_high": [2, 4], "cracks": [0, 1], "prefab": 0.25, "builder": "res://scripts/towers/chimera_floor.gd"},
}


## A tower's style: its own keys over the default's.
static func for_tower(tid: String) -> Dictionary:
	var out: Dictionary = STYLES["default"].duplicate(true)
	var own: Dictionary = STYLES.get(tid, {})
	for k in own:
		out[k] = own[k]
	return out
