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

## What each monster drops: kind and amount (more on higher floors).
static var DROPS := {
	"slime": ["water", 3.0],
	"archer": ["air", 4.0],
	"knight": ["iron", 7.0],
	"bat": ["air", 2.0],
	"thunderling": ["air", 5.0],
	"gryphon": ["air", 30.0],
	"lurker": ["water", 4.0],
	"shellback": ["iron", 5.0],
	"kraken": ["water", 30.0],
	"cinder": ["fire", 4.0],
	"smith": ["iron", 6.0],
	"wyvern": ["fire", 30.0],
	"scorpling": ["stone", 3.0],
	"ram": ["stone", 6.0],
	"manticore": ["stone", 30.0],
	"wisp": ["fire", 3.0],
	"bloomcap": ["fire", 5.0],
	"firebird": ["fire", 30.0],
	"thornhound": ["blade", 3.0],
	"mongrel": ["blade", 6.0],
	"chimera": ["blade", 30.0],
	"deepfin": ["water", 5.0],  # (the Kraken's tower: scripts/towers/deepfin.gd)
	"harrier": ["air", 4.0],  # (the Gryphon's tower: scripts/towers/harrier.gd)
}


static func drop_for(kind: String, floor_num: int) -> Array:
	var d: Array = DROPS.get(kind, ["air", 2.0])
	return [d[0], d[1] * (1.0 + 0.1 * float(maxi(floor_num - 1, 0)))]


static func color(kind: String) -> Color:
	return KINDS.get(kind, KINDS["air"])["color"]


static func display(kind: String) -> String:
	return KINDS.get(kind, KINDS["air"])["name"]
