extends RefCounted
## The Wyvern's tower (Iron and Fire): its bonds' fork alternatives, and the code that runs them.
## The content contract is at the top of library.gd; the worked example
## is scripts/spells/gryphon.gd (Stormcaller). Every alternative here is
## still a placeholder: the tree shows it as "Coming later" and today's
## spell stays. To write one, replace its placeholder with a spell (steps
## 2 and 4) or a variation (step 3) and run its "type" in cast_spell.

static var FORKS := {
	"blade_forger": {
		"change": {"name": "Five Blades", "says": "Conjured Blades throws five blades"},
		2: {"placeholder": true, "learn": 2},
		3: {"placeholder": true},
		4: {"placeholder": true, "learn": 4},
	},
	"flameblade": {
		"change": {"name": "Sustained", "says": "Kindle Blade lasts as long as you keep landing strikes"},
		2: {"placeholder": true, "learn": 2},
		3: {"placeholder": true},
		4: {"placeholder": true, "learn": 4},
	},
	"rune_artist": {
		"change": {"name": "Linked", "says": "setting off one rune sets off them all"},
		2: {"placeholder": true, "learn": 2},
		3: {"placeholder": true},
		4: {"placeholder": true, "learn": 4},
	},
}


## Runs this file's spells (none written yet).
static func cast_spell(_bond, _sp: Dictionary, _p) -> bool:
	return false
