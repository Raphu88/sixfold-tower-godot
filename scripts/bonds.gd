extends RefCounted
## Bond definitions. Each bond is data; bond.gd reads it.
##
## "steps" lists what changes at each step. A step only needs the values
## that change: anything it leaves out carries over from the step below.
## Bonds grow a step every two floors you climb (up to step 5).
##
## Spell types (the code that runs them lives in bond.gd):
##   chain  - lightning leaps between nearby foes
##   lift   - a gust in a cone throws foes into the air

const PART_NAMES := {"hand": "Hand", "legs": "Legs"}
const PART_FILLS := {
	"hand": "fills when you land weapon strikes",
	"legs": "fills when you roll through an attack",
}
const PART_BURN := {
	"hand": "burned: your strikes deal less damage",
	"legs": "burned: rolls cost more and travel less",
}

const BONDS := {
	"stormcaller": {
		"name": "Stormcaller",
		"color": Color(0.95, 0.89, 0.42),
		"spell": "Chain Lightning",
		"type": "chain",
		"steps": {
			1: {"cost": 12.0, "windup": 0.45, "leaps": 4, "damage": 10.0, "stun": 0.0, "reach": 280.0, "hop": 170.0},
			2: {"damage": 13.0},
			3: {"leaps": 6, "stun": 0.4},  # the big step: more leaps, and it stuns
			4: {"damage": 16.0, "cost": 10.0, "stun": 0.5},
			5: {"leaps": 8, "damage": 20.0, "cost": 9.0, "stun": 0.6, "hop": 200.0},
		},
	},
	"windwalker": {
		"name": "Windwalker",
		"color": Color(0.75, 0.9, 1.0),
		"spell": "Gale Lift",
		"type": "lift",
		"steps": {
			1: {"cost": 10.0, "windup": 0.3, "arc": 35.0, "reach": 140.0, "lift": 1.5, "damage": 0.0},
			2: {"arc": 40.0, "reach": 155.0, "lift": 1.7},
			3: {"arc": 70.0, "reach": 175.0, "lift": 1.8},  # the big step: a much wider gust
			4: {"arc": 75.0, "reach": 190.0, "lift": 2.0, "damage": 6.0},
			5: {"arc": 90.0, "reach": 210.0, "lift": 2.2, "damage": 10.0, "cost": 8.0},
		},
	},
}

## What a step adds, in words, for the "bond grows" message.
const STEP_NOTES := {
	"stormcaller": {2: "harder strikes", 3: "more leaps, and it stuns", 4: "cheaper, harder", 5: "eight leaps"},
	"windwalker": {2: "a stronger gust", 3: "a much wider gust", 4: "the gust now hurts", 5: "a vast, cheap gust"},
}
