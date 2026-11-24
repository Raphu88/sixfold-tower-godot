extends RefCounted
## Essence: what monsters leave behind when they fall. It flies into you,
## soaks into your body, and is banked at the next stair (dying first loses
## whatever you hadn't banked). Banked essence strengthens your bonds, and
## the kind you gather decides which bond forms when a body part takes a mark.

static var KINDS := {
	"air": {"name": "Air", "color": Color(0.78, 0.9, 1.0)},
	"water": {"name": "Water", "color": Color(0.37, 0.72, 0.85)},
	"iron": {"name": "Iron", "color": Color(0.8, 0.82, 0.88)},
	"fire": {"name": "Fire", "color": Color(1.0, 0.55, 0.25)},
	"stone": {"name": "Stone", "color": Color(0.82, 0.68, 0.45)},
	"blade": {"name": "Blade", "color": Color(0.88, 0.36, 0.4)},
}

## What each monster drops: kind and amount (more on higher floors). (Half of
## what they were, the guardians' excepted: measured in real, thorough play
## (tests/essence_measure.gd "thorough": every monster, chest and cache on
## the floor) a floor gave far more than the pace model holds; with the
## finds at three quarters a thorough floor now gives what the model counts:
## tests/progression_model.gd ESSENCE, held by tests/parts/essence_pace.gd.)
static var DROPS := {
	"slime": ["water", 1.3125],
	"archer": ["air", 1.75],
	"knight": ["iron", 3.0625],
	"bat": ["air", 0.875],
	"thunderling": ["air", 2.1875],
	"gryphon": ["air", 26.25],
	"lurker": ["water", 1.75],
	"shellback": ["iron", 2.1875],
	"kraken": ["water", 26.25],
	"cinder": ["fire", 1.75],
	"smith": ["iron", 2.625],
	"golem": ["iron", 3.0625],  # the forge golem (scripts/towers/forge_golem.gd)
	"wyvern": ["fire", 26.25],
	"scorpling": ["stone", 1.3125],
	"ram": ["stone", 2.625],
	"burrower": ["stone", 2.1875],  # the burrower (scripts/towers/burrower.gd)
	"manticore": ["stone", 26.25],
	"wisp": ["fire", 1.3125],
	"bloomcap": ["fire", 2.1875],
	"firebird": ["fire", 26.25],
	"thornhound": ["blade", 1.3125],
	"mongrel": ["blade", 2.625],
	"chimera": ["blade", 26.25],
	"deepfin": ["water", 2.1875],  # (the Kraken's tower: scripts/towers/deepfin.gd)
	"harrier": ["air", 1.75],  # (the Gryphon's tower: scripts/towers/harrier.gd)
	"ashwing": ["fire", 1.96875],  # (the Firebird's tower: scripts/towers/ashwing.gd)
	"briar": ["blade", 2.1875],  # (the Chimera's tower: scripts/towers/briar.gd)
	"mimic": ["iron", 0.875],  # (every tower: scripts/mimic.gd spills the rest, in the tower's essence)
	"husk": ["iron", 2.1875],  # (every tower: scripts/foes/)
	"bellringer": ["iron", 0.875],
	"squall": ["air", 1.3125],  # (the Gryphon's tower)
	"rookery": ["air", 1.3125],
	"stormstone": ["air", 1.75],
	"inkling": ["water", 1.3125],  # (the Kraken's tower)
	"drowned": ["water", 2.1875],
	"driftbell": ["water", 1.3125],
	"stoker": ["fire", 1.75],  # (the Wyvern's tower)
	"slagworm": ["fire", 1.75],
	"riveter": ["iron", 1.3125],
	# The Manticore's, the Firebird's and the Chimera's newer monsters (scripts/towers/brood.gd).
	"carrion": ["stone", 1.75], "basilisk": ["stone", 2.1875], "cairn": ["stone", 2.625],
	"kindler": ["fire", 2.1875], "flamemoth": ["fire", 1.3125], "salamander": ["fire", 1.96875],
	"graftling": ["blade", 1.96875], "hydra": ["blade", 2.625], "leafmantis": ["blade", 1.75],
}


## Monsters spawned as adds pay this share of a kill's essence (main.gd
## on_enemy_killed: the drop, the tower's bonus and any extra), by the "add"
## mark their spawner gives them: "summoned" (a nest's hatchlings, a beast's
## called help, the slimes a plate room sends, a wardstone's waves),
## "punished" (the guards a wrong answer or a failed puzzle sends) and
## "horde" (the tower's answer to a slipped or broken barrier:
## climb_shape.gd). Any other monster pays in full. (They paid in full once:
## a nest, a plate room or a slipped barrier could be farmed.) "proving": the
## Proving's sentinel and its adds (proving.gd), a set piece met once a
## climb, pay twice a kill: what they paid before the drops were halved.
static var ADDS := {"summoned": 0.0, "punished": 0.0, "horde": 0.25, "proving": 2.0}


## The share of a kill's essence monster `e` pays (ADDS; 1 for any other).
static func add_pay(e) -> float:
	if e == null or not e.has_meta("add"):
		return 1.0
	return clampf(float(ADDS.get(String(e.get_meta("add")), 1.0)), 0.0, 4.0)


static func drop_for(kind: String, floor_num: int) -> Array:
	var d: Array = DROPS.get(kind, ["air", 0.875])
	return [d[0], d[1] * (1.0 + 0.1 * float(maxi(floor_num - 1, 0)))]


static func color(kind: String) -> Color:
	return KINDS.get(kind, KINDS["air"])["color"]


static func display(kind: String) -> String:
	return KINDS.get(kind, KINDS["air"])["name"]
