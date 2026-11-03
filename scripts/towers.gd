extends RefCounted
## The towers you can climb. Each has its own beast (who regards you at the
## top of your first climb), its own essence, its own mix of monsters and its
## own look. Every kill in a tower also yields a little of its essence, so
## the tower you choose steers which bonds you'll form. (Story to come.)

const ORDER := ["gryphon", "kraken", "wyvern"]
const ESSENCE_BONUS := 1.5  # extra essence of the tower's kind per kill

const TOWERS := {
	"gryphon": {
		"name": "The Gryphon's Tower",
		"short": "Gryphon",
		"beast": "the Gryphon",
		"essence": "air",
		"blurb": "Wind-swept halls of archers, bats and thunderlings. The Gryphon waits at the top.",
		"weights": {"archer": 1.3, "bat": 1.4, "thunderling": 0.8, "slime": 0.3, "knight": 0.3},
		"first": ["archer", "bat", "bat", "archer"],
		"summit": 5,  # the floor where the beast is fought
		"beast_kind": "gryphon",
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
		"summit": 5,
		"beast_kind": "kraken",
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
		"blurb": "A hot forge-tower held by armoured knights. The hardest climb.",
		"weights": {"knight": 1.5, "archer": 0.6, "slime": 0.5},
		"first": ["knight", "slime", "archer", "knight"],
		"stone": Color(1.0, 0.86, 0.8),
		"ambient": Color(0.52, 0.42, 0.42),
		"torch": Color(1.0, 0.58, 0.32),
	},
}
