extends RefCounted
## The Firebird's tower (Fire): its bonds' fork alternatives, and the code that runs them.
## The content contract is at the top of library.gd; the worked example
## is scripts/spells/gryphon.gd (Stormcaller). Every alternative here is
## still a placeholder: the tree shows it as "Coming later" and today's
## spell stays. To write one, replace its placeholder with a spell (steps
## 2 and 4) or a variation (step 3) and run its "type" in cast_spell.

static var FORKS := {
	"flame_contractor": {
		"change": {"name": "Charged", "says": "Fireball charges: a longer wind-up and a much bigger explosion"},
		2: {"placeholder": true, "learn": 2},
		3: {"placeholder": true},
		4: {"placeholder": true, "learn": 4},
	},
	"flamewing": {
		"change": {"name": "Growing", "says": "Heat Aura grows hotter the longer it burns"},
		2: {"placeholder": true, "learn": 2},
		3: {"placeholder": true},
		4: {"placeholder": true, "learn": 4},
	},
	"rekindler": {
		"change": {"name": "Spreading", "says": "foes near you burn too while you rekindle"},
		2: {"placeholder": true, "learn": 2},
		3: {"placeholder": true},
		4: {"placeholder": true, "learn": 4},
	},
}


## Runs this file's spells (none written yet).
static func cast_spell(_bond, _sp: Dictionary, _p) -> bool:
	return false
