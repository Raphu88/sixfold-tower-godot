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

## What each monster drops: kind and amount (more on higher floors). (Seven
## eighths of the old amounts since the crystal share was fixed at 20%: what
## flows into you stays the same, crystals come slower: essence_flow.gd SPLIT.)
static var DROPS := {
	"slime": ["water", 2.625],
	"archer": ["air", 3.5],
	"knight": ["iron", 6.125],
	"bat": ["air", 1.75],
	"thunderling": ["air", 4.375],
	"gryphon": ["air", 26.25],
	"lurker": ["water", 3.5],
	"shellback": ["iron", 4.375],
	"kraken": ["water", 26.25],
	"cinder": ["fire", 3.5],
	"smith": ["iron", 5.25],
	"golem": ["iron", 6.125],  # the forge golem (scripts/towers/forge_golem.gd)
	"wyvern": ["fire", 26.25],
	"scorpling": ["stone", 2.625],
	"ram": ["stone", 5.25],
	"burrower": ["stone", 4.375],  # the burrower (scripts/towers/burrower.gd)
	"manticore": ["stone", 26.25],
	"wisp": ["fire", 2.625],
	"bloomcap": ["fire", 4.375],
	"firebird": ["fire", 26.25],
	"thornhound": ["blade", 2.625],
	"mongrel": ["blade", 5.25],
	"chimera": ["blade", 26.25],
	"deepfin": ["water", 4.375],  # (the Kraken's tower: scripts/towers/deepfin.gd)
	"harrier": ["air", 3.5],  # (the Gryphon's tower: scripts/towers/harrier.gd)
	"ashwing": ["fire", 3.9375],  # (the Firebird's tower: scripts/towers/ashwing.gd)
	"briar": ["blade", 4.375],  # (the Chimera's tower: scripts/towers/briar.gd)
	"mimic": ["iron", 1.75],  # (every tower: scripts/mimic.gd spills the rest, in the tower's essence)
	"husk": ["iron", 4.375],  # (every tower: scripts/foes/)
	"bellringer": ["iron", 1.75],
	"squall": ["air", 2.625],  # (the Gryphon's tower)
	"rookery": ["air", 2.625],
	"stormstone": ["air", 3.5],
	"inkling": ["water", 2.625],  # (the Kraken's tower)
	"drowned": ["water", 4.375],
	"driftbell": ["water", 2.625],
	"stoker": ["fire", 3.5],  # (the Wyvern's tower)
	"slagworm": ["fire", 3.5],
	"riveter": ["iron", 2.625],
	# The Manticore's, the Firebird's and the Chimera's newer monsters (scripts/towers/brood.gd).
	"carrion": ["stone", 3.5], "basilisk": ["stone", 4.375], "cairn": ["stone", 5.25],
	"kindler": ["fire", 4.375], "flamemoth": ["fire", 2.625], "salamander": ["fire", 3.9375],
	"graftling": ["blade", 3.9375], "hydra": ["blade", 5.25], "leafmantis": ["blade", 3.5],
}


static func drop_for(kind: String, floor_num: int) -> Array:
	var d: Array = DROPS.get(kind, ["air", 1.75])
	return [d[0], d[1] * (1.0 + 0.1 * float(maxi(floor_num - 1, 0)))]


static func color(kind: String) -> Color:
	return KINDS.get(kind, KINDS["air"])["color"]


static func display(kind: String) -> String:
	return KINDS.get(kind, KINDS["air"])["name"]
