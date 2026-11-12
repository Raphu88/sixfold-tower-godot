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
##   prefab        (optional) how much likelier (or rarer, below 1) a hand-made room is
##   room_grow     (optional) tiles added to (or taken from, below 0) each
##                 carved room's width and height
##   script        (optional) the tower's own floor script (scripts/towers/):
##                 floors.gd asks it to shape the corridors (shape_corridors)
##                 and to finish the plan (finish_plan); main.gd runs it as a
##                 node on the floor (setup), for the tower's own system

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
		"gallery": ["open", "rect", "round"], "room_grow": 0, "prefab": 0.35, "corridor": "bridges", "script": "res://scripts/towers/gryphon_floor.gd"},
	# Flooded: round and oval rooms, winding corridors, pools, and water that
	# rises and drains (scripts/towers/kraken_floor.gd).
	"kraken": {"shapes": ["circle", "circle", "ring", "round"], "own_shapes": ["circle", "circle", "round"],
		"gallery": ["circle", "ring", "circle"], "room_grow": -1, "prefab": 0.3, "corridor": "winding", "script": "res://scripts/towers/kraken_floor.gd"},
	"wyvern": {"shapes": ["ring", "cover", "ring", "gallery"]},
	"manticore": {"shapes": ["cover", "split", "ring", "cover"]},
	"firebird": {"shapes": ["circle", "ring", "split", "circle"]},
	"chimera": {"shapes": ["cover", "circle", "gallery", "split"]},
}


## A tower's style: its own keys over the default's.
static func for_tower(tid: String) -> Dictionary:
	var out: Dictionary = STYLES["default"].duplicate(true)
	var own: Dictionary = STYLES.get(tid, {})
	for k in own:
		out[k] = own[k]
	return out


## The tower's own floor script (or null): see "script" above.
static func script_for(style: Dictionary) -> Script:
	var path := String(style.get("script", ""))
	return load(path) if path != "" else null
