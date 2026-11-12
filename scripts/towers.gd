extends RefCounted
## The towers you can climb. Each has its own beast (who regards you at the
## top of your first climb), its own essence, its own mix of monsters and its
## own look. Every kill in a tower also yields a little of its essence, so
## the tower you choose steers which bonds you'll form. (Story to come.)

const ORDER := ["gryphon", "kraken", "wyvern", "manticore", "firebird", "chimera"]
const ESSENCE_BONUS := 1.5  # extra essence of the tower's kind per kill

## How tall every tower is: the beast waits on the summit floor. (The first,
## bondless climb stops sooner: profile.gd's FIRST_CLIMB_FLOORS.)
const SUMMIT := 12
## Halfway up, a floor where the tower takes the climber's measure: a fixed
## layout with a gauntlet of the tower's traps, its sentinel and the shadow
## of its beast. scripts/proving.gd holds its words and numbers; each
## tower's gauntlet, sentinel and adds are in TOWERS below.
static var PROVING := {
	"floor": 6,
	"name": "The Proving",
	"line": "The tower's gaze settles on you. Here it takes your measure.",
}

static var TOWERS := {
	"gryphon": {
		"name": "The Gryphon's Tower",
		"short": "Gryphon",
		"beast": "the Gryphon",
		"essence": "air",
		"blurb": "Wind-swept halls of archers, bats and thunderlings. The Gryphon waits at the top.",
		"weights": {"archer": 1.3, "bat": 1.4, "thunderling": 0.8, "slime": 0.3, "knight": 0.3},
		"first": ["archer", "bat", "bat", "archer"],
		"summit": SUMMIT,  # the floor where the beast is fought
		"beast_kind": "gryphon",
		"gauntlet": "windhall", "sentinel": "thunderling", "sentinel_adds": "bat",  # the Proving (floor 6, proving.gd)
		"shapes": ["open", "open", "rect", "round"],  # carved room shapes (rooms.gd); a repeat makes one likelier
		"beast_hint": "Watch for the glint. A landing can't be parried.",
		"stone": Color(0.86, 0.92, 1.0),
		"ambient": Color(0.44, 0.48, 0.64),
		"torch": Color(0.82, 0.9, 1.0),
	},
	"kraken": {
		"name": "The Kraken's Tower",
		"short": "Kraken",
		"beast": "the Kraken",
		"essence": "water",
		"blurb": "Flooded halls of slimes, lurkers and shellbacks. Water slows you. The Kraken waits at the top.",
		"puddles": true,
		"weights": {"slime": 1.3, "lurker": 1.1, "shellback": 0.8, "archer": 0.4, "knight": 0.3},
		"first": ["knight", "slime", "lurker", "slime"],
		"summit": SUMMIT,
		"beast_kind": "kraken",
		"gauntlet": "sluice", "sentinel": "shellback", "sentinel_adds": "lurker",  # the Proving (floor 6, proving.gd)
		"shapes": ["hall", "hall", "rect", "ell"],  # carved room shapes (rooms.gd); a repeat makes one likelier
		"beast_hint": "Watch for the glint. A slam can't be parried: roll.",
		"stone": Color(0.82, 0.96, 0.95),
		"ambient": Color(0.36, 0.47, 0.55),
		"torch": Color(0.7, 1.0, 0.9),
	},
	"wyvern": {
		"name": "The Wyvern's Tower",
		"short": "Wyvern",
		"beast": "the Wyvern",
		"essence": "iron",
		"blurb": "A hot forge-tower of knights, cinders and smiths. The hardest climb. The Wyvern waits at the top.",
		"weights": {"knight": 1.2, "cinder": 1.2, "smith": 1.0, "archer": 0.3, "slime": 0.2},
		"first": ["knight", "cinder", "smith", "cinder"],
		"summit": SUMMIT,
		"beast_kind": "wyvern",
		"gauntlet": "furnace", "sentinel": "smith", "sentinel_adds": "cinder",  # the Proving (floor 6, proving.gd)
		"shapes": ["pillars", "rect", "pillars", "ell"],  # carved room shapes (rooms.gd); a repeat makes one likelier
		"beast_hint": "Watch for the glint. Its fire breath can't be parried: roll or step aside.",
		"stone": Color(1.0, 0.86, 0.8),
		"ambient": Color(0.52, 0.42, 0.42),
		"torch": Color(1.0, 0.58, 0.32),
	},
	"manticore": {
		"name": "The Manticore's Tower",
		"short": "Manticore",
		"beast": "the Manticore",
		"essence": "stone",
		"blurb": "Sun-baked sandstone halls of scorplings and charging rams. Stings poison. The Manticore waits at the top.",
		"weights": {"scorpling": 1.4, "ram": 0.9, "archer": 0.6, "knight": 0.3, "slime": 0.2},
		"first": ["scorpling", "archer", "ram", "scorpling"],
		"summit": SUMMIT,
		"beast_kind": "manticore",
		"gauntlet": "spikes", "sentinel": "ram", "sentinel_adds": "scorpling",  # the Proving (floor 6, proving.gd)
		"shapes": ["ell", "rect", "ell", "cross"],  # carved room shapes (rooms.gd); a repeat makes one likelier
		"beast_hint": "Watch for the glint. Its roar can't be parried: roll through it.",
		"stone": Color(1.0, 0.93, 0.76),
		"ambient": Color(0.56, 0.5, 0.4),
		"torch": Color(1.0, 0.8, 0.48),
	},
	"firebird": {
		"name": "The Firebird's Tower",
		"short": "Firebird",
		"beast": "the Firebird",
		"essence": "fire",
		"blurb": "Islands of rock over the abyss, bridges that burn behind you, updrafts and ember storms. Wisps, bloomcaps and ashwings. The Firebird waits at the top.",
		"chasms": true,
		"weights": {"wisp": 1.4, "bloomcap": 1.0, "ashwing": 0.8, "archer": 0.5, "knight": 0.3, "slime": 0.2},
		"first": ["wisp", "archer", "wisp", "archer"],
		"summit": SUMMIT,
		"beast_kind": "firebird",
		"gauntlet": "emberfall", "sentinel": "wisp", "sentinel_adds": "bloomcap",  # the Proving (floor 6, proving.gd)
		"shapes": ["island", "island", "atoll", "round"],  # carved room shapes (rooms.gd, towers/organic.gd); a repeat makes one likelier
		"beast_hint": "Watch for the glint. Its firestorm can't be parried: get out of the circles. It rises once from its ashes.",
		"stone": Color(1.0, 0.9, 0.82),
		"ambient": Color(0.6, 0.47, 0.42),
		"torch": Color(1.0, 0.66, 0.3),
	},
	"chimera": {
		"name": "The Chimera's Tower",
		"short": "Chimera",
		"beast": "the Chimera",
		"essence": "blade",
		"blurb": "The Thornwild, where beasts are bred: grown caves, living thorns, packs of thornhounds, patchwork mongrels and bushes that grab. The Chimera waits at the top.",
		"weights": {"thornhound": 1.4, "mongrel": 1.0, "briar": 0.7, "archer": 0.4, "knight": 0.4},
		"first": ["thornhound", "archer", "thornhound", "slime"],
		"summit": SUMMIT,
		"beast_kind": "chimera",
		"gauntlet": "bramble", "sentinel": "mongrel", "sentinel_adds": "thornhound",  # the Proving (floor 6, proving.gd)
		"shapes": ["cave", "den", "cave", "round"],  # carved room shapes (rooms.gd, towers/organic.gd); a repeat makes one likelier
		"beast_hint": "Watch for the glint. Its lion's breath can't be parried: roll or step aside.",
		"stone": Color(0.86, 0.95, 0.82),
		"ambient": Color(0.46, 0.53, 0.43),
		"torch": Color(0.88, 1.0, 0.6),
	},
}
