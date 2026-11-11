extends RefCounted
## The Manticore's tower (Stone and Fire): its bonds' fork alternatives, and the code that runs them.
## The content contract is at the top of library.gd; the worked example
## is scripts/spells/gryphon.gd (Stormcaller). Every alternative here is
## still a placeholder: the tree shows it as "Coming later" and today's
## spell stays. To write one, replace its placeholder with a spell (steps
## 2 and 4) or a variation (step 3) and run its "type" in cast_spell.

static var FORKS := {
	"sandshaper": {
		"change": {"name": "Ringed", "says": "Quake also throws up a ring of low walls"},
		2: {"placeholder": true, "learn": 2},
		3: {"placeholder": true},
		4: {"placeholder": true, "learn": 4},
	},
	"venomist": {
		"change": {"name": "Piercing", "says": "Venom Spit pierces"},
		2: {"placeholder": true, "learn": 2},
		3: {"placeholder": true},
		4: {"placeholder": true, "learn": 4},
	},
	"ashwalker": {
		"change": {"name": "Igniting", "says": "cast Smoke Veil again to ignite the cloud"},
		2: {"placeholder": true, "learn": 2},
		3: {"placeholder": true},
		4: {"placeholder": true, "learn": 4},
	},
}


## Runs this file's spells (none written yet).
static func cast_spell(_bond, _sp: Dictionary, _p) -> bool:
	return false
