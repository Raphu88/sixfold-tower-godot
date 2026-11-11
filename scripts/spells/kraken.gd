extends RefCounted
## The Kraken's tower (Water): its bonds' fork alternatives, and the code that runs them.
## The content contract is at the top of library.gd; the worked example
## is scripts/spells/gryphon.gd (Stormcaller). Every alternative here is
## still a placeholder: the tree shows it as "Coming later" and today's
## spell stays. To write one, replace its placeholder with a spell (steps
## 2 and 4) or a variation (step 3) and run its "type" in cast_spell.

static var FORKS := {
	"tidecaller": {
		"change": {"name": "Aimed", "says": "Tidal Surge becomes an aimed wave that travels forward"},
		2: {"placeholder": true, "learn": 2},
		3: {"placeholder": true},
		4: {"placeholder": true, "learn": 4},
	},
	"warden": {
		"change": {"name": "Bursting", "says": "Barrier bursts with what it absorbed when it breaks"},
		2: {"placeholder": true, "name": "Bulwark", "desc": "a curved wall of water in front of you stops shots for 4 seconds", "learn": 2},
		3: {"placeholder": true, "name": "Mirrored", "desc": "shots that hit the barrier fly back", "variation": "mirrored"},
		4: {"placeholder": true, "name": "Tidebreak", "desc": "a parry while the barrier holds sends out a wave", "learn": 4},
	},
	"deepcaller": {
		"change": {"name": "Deeper", "says": "Undertow drains 5 foes"},
		2: {"placeholder": true, "learn": 2},
		3: {"placeholder": true},
		4: {"placeholder": true, "learn": 4},
	},
}


## Runs this file's spells (none written yet).
static func cast_spell(_bond, _sp: Dictionary, _p) -> bool:
	return false
