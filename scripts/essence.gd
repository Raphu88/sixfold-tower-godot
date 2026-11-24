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
## tests/progression_model.gd ESSENCE, held by tests/parts/essence_pace.gd.
## Then every amount went to 87% of that, the guardians' too, as a stair's
## crystal share went from 20% to 8%: what flows into you stays about the same,
## and fewer crystals condense: essence_flow.gd SPLIT.)
static var DROPS := {
	"slime": ["water", 1.1419],
	"archer": ["air", 1.5225],
	"knight": ["iron", 2.6644],
	"bat": ["air", 0.7612],
	"thunderling": ["air", 1.9031],
	"gryphon": ["air", 22.8375],
	"lurker": ["water", 1.5225],
	"shellback": ["iron", 1.9031],
	"kraken": ["water", 22.8375],
	"cinder": ["fire", 1.5225],
	"smith": ["iron", 2.2837],
	"golem": ["iron", 2.6644],  # the forge golem (scripts/towers/forge_golem.gd)
	"wyvern": ["fire", 22.8375],
	"scorpling": ["stone", 1.1419],
	"ram": ["stone", 2.2837],
	"burrower": ["stone", 1.9031],  # the burrower (scripts/towers/burrower.gd)
	"manticore": ["stone", 22.8375],
	"wisp": ["fire", 1.1419],
	"bloomcap": ["fire", 1.9031],
	"firebird": ["fire", 22.8375],
	"thornhound": ["blade", 1.1419],
	"mongrel": ["blade", 2.2837],
	"chimera": ["blade", 22.8375],
	"deepfin": ["water", 1.9031],  # (the Kraken's tower: scripts/towers/deepfin.gd)
	"harrier": ["air", 1.5225],  # (the Gryphon's tower: scripts/towers/harrier.gd)
	"ashwing": ["fire", 1.7128],  # (the Firebird's tower: scripts/towers/ashwing.gd)
	"briar": ["blade", 1.9031],  # (the Chimera's tower: scripts/towers/briar.gd)
	"mimic": ["iron", 0.7612],  # (every tower: scripts/mimic.gd spills the rest, in the tower's essence)
	"husk": ["iron", 1.9031],  # (every tower: scripts/foes/)
	"bellringer": ["iron", 0.7612],
	"squall": ["air", 1.1419],  # (the Gryphon's tower)
	"rookery": ["air", 1.1419],
	"stormstone": ["air", 1.5225],
	"inkling": ["water", 1.1419],  # (the Kraken's tower)
	"drowned": ["water", 1.9031],
	"driftbell": ["water", 1.1419],
	"stoker": ["fire", 1.5225],  # (the Wyvern's tower)
	"slagworm": ["fire", 1.5225],
	"riveter": ["iron", 1.1419],
	# The Manticore's, the Firebird's and the Chimera's newer monsters (scripts/towers/brood.gd).
	"carrion": ["stone", 1.5225], "basilisk": ["stone", 1.9031], "cairn": ["stone", 2.2837],
	"kindler": ["fire", 1.9031], "flamemoth": ["fire", 1.1419], "salamander": ["fire", 1.7128],
	"graftling": ["blade", 1.7128], "hydra": ["blade", 2.2837], "leafmantis": ["blade", 1.5225],
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
	var d: Array = DROPS.get(kind, ["air", 0.7612])
	return [d[0], d[1] * (1.0 + 0.1 * float(maxi(floor_num - 1, 0)))]


static func color(kind: String) -> Color:
	return KINDS.get(kind, KINDS["air"])["color"]


static func display(kind: String) -> String:
	return KINDS.get(kind, KINDS["air"])["name"]
