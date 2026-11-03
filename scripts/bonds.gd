extends RefCounted
## Bond definitions. Each bond is data; bond.gd reads it.
##
## "steps" lists what changes at each step. A step only needs the values
## that change: anything it leaves out carries over from the step below.
## Bonds grow across climbs from essence you bank at stairs (see profile.gd),
## up to step 5.
##
## "affinity" is the essence that forms the bond (and grows it fastest).
## "home" is the body part it prefers when its essence takes hold.
##
## Spell types (the code that runs them lives in bond.gd):
##   chain   - lightning leaps between nearby foes
##   lift    - a gust in a cone throws foes into the air
##   surge   - a wave bursts out around you, hurling foes away
##   blades  - a fan of conjured blades that pierce through foes

const PARTS := ["hand", "legs", "heart", "brow"]
const PART_NAMES := {"hand": "Hand", "legs": "Legs", "heart": "Heart", "brow": "Brow"}
const PART_FILLS := {
	"hand": "fills when you land weapon strikes",
	"legs": "fills when you roll through an attack",
	"heart": "fills when you take a hit and survive",
	"brow": "fills when you parry",
}
const PART_BURN := {
	"hand": "burned: your strikes deal less damage",
	"legs": "burned: rolls cost more and travel less",
	"heart": "burned: your health is capped lower",
	"brow": "burned: your parry window is shorter",
}
## The cast key for each body part.
const PART_KEYS := {"hand": "Q", "legs": "E", "heart": "F", "brow": "C"}

const BONDS := {
	"stormcaller": {
		"name": "Stormcaller",
		"color": Color(0.95, 0.89, 0.42),
		"spell": "Chain Lightning",
		"type": "chain",
		"affinity": "air",
		"home": "hand",  # preferred when Air essence takes a body part
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
		"affinity": "air",
		"home": "legs",
		"steps": {
			1: {"cost": 10.0, "windup": 0.3, "arc": 35.0, "reach": 140.0, "lift": 1.5, "damage": 0.0},
			2: {"arc": 40.0, "reach": 155.0, "lift": 1.7},
			3: {"arc": 70.0, "reach": 175.0, "lift": 1.8},  # the big step: a much wider gust
			4: {"arc": 75.0, "reach": 190.0, "lift": 2.0, "damage": 6.0},
			5: {"arc": 90.0, "reach": 210.0, "lift": 2.2, "damage": 10.0, "cost": 8.0},
		},
	},
	"tidecaller": {
		"name": "Tidecaller",
		"color": Color(0.37, 0.72, 0.79),
		"spell": "Tidal Surge",
		"type": "surge",
		"affinity": "water",
		"home": "heart",
		"steps": {
			1: {"cost": 12.0, "windup": 0.4, "radius": 110.0, "damage": 6.0, "push": 280.0},
			2: {"radius": 125.0, "damage": 8.0},
			3: {"radius": 150.0, "push": 380.0, "damage": 10.0},  # the big step: a far wider wave
			4: {"damage": 13.0, "cost": 10.0},
			5: {"radius": 175.0, "damage": 16.0, "push": 440.0},
		},
	},
	"blade_forger": {
		"name": "Blade Forger",
		"color": Color(0.65, 0.89, 0.71),
		"spell": "Conjured Blades",
		"type": "blades",
		"affinity": "iron",
		"home": "hand",
		"steps": {
			1: {"cost": 10.0, "windup": 0.35, "count": 3, "damage": 7.0, "spread": 18.0},
			2: {"damage": 9.0},
			3: {"count": 5, "spread": 14.0},  # the big step: five blades
			4: {"damage": 11.0, "cost": 8.0},
			5: {"count": 7, "damage": 13.0},
		},
	},
}

## What a step adds, in words, for the "bond grows" message.
const STEP_NOTES := {
	"stormcaller": {2: "harder strikes", 3: "more leaps, and it stuns", 4: "cheaper, harder", 5: "eight leaps"},
	"windwalker": {2: "a stronger gust", 3: "a much wider gust", 4: "the gust now hurts", 5: "a vast, cheap gust"},
	"tidecaller": {2: "a harder wave", 3: "a far wider wave", 4: "cheaper, harder", 5: "a crushing tide"},
	"blade_forger": {2: "sharper blades", 3: "five blades", 4: "cheaper, sharper", 5: "seven blades"},
}
