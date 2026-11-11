extends RefCounted
## The Unbound's new effects: three more for each essence, each opening once
## that much of its essence has pooled in the body ("opens", raw density of
## that kind across the six parts: tree.gd effect_open). The content
## contract is at the top of library.gd.
##
## An effect is chosen for an essence in a technique (the technique's
## "effects": {kind: effect id}); it replaces that essence's base effect on
## a struck foe. Each needs a phrase for each kind of form ("hit", "self",
## "shell", "near"), as the base effects have. Unmaking's keep a small cost
## in health. "placeholder": true until written; hit_effect runs the written ones.
## WORKED EXAMPLE: Spark (Air): the hit leaps to one more foe nearby.

static var EFFECTS := {
	"kindle": {"kind": "fire", "name": "Kindle", "says": "Leaves burning floor", "opens": 100, "strain": 0.0, "levels": {}, "placeholder": true},
	"flare": {"kind": "fire", "name": "Flare", "says": "A second blast a moment later", "opens": 300, "strain": 0.0, "levels": {}, "placeholder": true},
	"smoulder": {"kind": "fire", "name": "Smoulder", "says": "When the foe falls, its burn jumps on", "opens": 600, "strain": 0.0, "levels": {}, "placeholder": true},
	"chill": {"kind": "water", "name": "Chill", "says": "Slows stack into a short freeze", "opens": 100, "strain": 0.0, "levels": {}, "placeholder": true},
	"current": {"kind": "water", "name": "Current", "says": "Carries struck foes along your aim", "opens": 300, "strain": 0.0, "levels": {}, "placeholder": true},
	"mist": {"kind": "water", "name": "Mist", "says": "Foes inside lose sight of you", "opens": 600, "strain": 0.0, "levels": {}, "placeholder": true},
	"spark": {"kind": "air", "name": "Spark", "says": "Leaps to one more foe", "opens": 100, "strain": 0.0, "levels": {},
		"hit": "leaps to one more foe nearby", "self": "your strikes spark to a second foe for a while", "shell": "sparks at foes that strike it", "near": "sparks between the foes near you",
		"damage": 5.0, "hop": 150.0},
	"lift": {"kind": "air", "name": "Lift", "says": "A light foe floats, helpless, for a moment", "opens": 300, "strain": 0.0, "levels": {}, "placeholder": true},
	"gust": {"kind": "air", "name": "Gust", "says": "Throws foes back hard", "opens": 600, "strain": 0.0, "levels": {}, "placeholder": true},
	"rubble": {"kind": "stone", "name": "Rubble", "says": "Leaves rubble that slows", "opens": 100, "strain": 0.0, "levels": {}, "placeholder": true},
	"grit": {"kind": "stone", "name": "Grit", "says": "You take less damage for a few seconds", "opens": 300, "strain": 0.0, "levels": {}, "placeholder": true},
	"tremor": {"kind": "stone", "name": "Tremor", "says": "A small ring where it lands", "opens": 600, "strain": 0.0, "levels": {}, "placeholder": true},
	"shrapnel": {"kind": "iron", "name": "Shrapnel", "says": "Shards fly from the struck foe", "opens": 100, "strain": 0.0, "levels": {}, "placeholder": true},
	"temper": {"kind": "iron", "name": "Temper", "says": "Your next weapon strike hits harder", "opens": 300, "strain": 0.0, "levels": {}, "placeholder": true},
	"lodestone": {"kind": "iron", "name": "Lodestone", "says": "Pulls loose foes together", "opens": 600, "strain": 0.0, "levels": {}, "placeholder": true},
	"rend": {"kind": "blade", "name": "Rend", "says": "Bleeds stack", "opens": 100, "strain": 0.0, "levels": {}, "placeholder": true},
	"shards": {"kind": "blade", "name": "Shards", "says": "Blades left on the floor cut what walks over them", "opens": 300, "strain": 0.0, "levels": {}, "placeholder": true},
	"answer": {"kind": "blade", "name": "Answer", "says": "Your next parry cuts back", "opens": 600, "strain": 0.0, "levels": {}, "placeholder": true},
	"bloom": {"kind": "life", "name": "Bloom", "says": "A flower that heals you when you step on it", "opens": 100, "strain": 0.0, "levels": {}, "placeholder": true},
	"lifeline": {"kind": "life", "name": "Lifeline", "says": "A thread that drinks from a foe", "opens": 300, "strain": 0.0, "levels": {}, "placeholder": true},
	"second_wind": {"kind": "life", "name": "Second Wind", "says": "Stamina back on each hit", "opens": 600, "strain": 0.0, "levels": {}, "placeholder": true},
	"unravel": {"kind": "unmaking", "name": "Unravel", "says": "Armour stays stripped for a while", "opens": 100, "strain": 0.0, "levels": {}, "placeholder": true},
	"hollow": {"kind": "unmaking", "name": "Hollow", "says": "The foe takes more from everything", "opens": 300, "strain": 0.0, "levels": {}, "placeholder": true},
	"fray": {"kind": "unmaking", "name": "Fray", "says": "Erodes faster the longer it lasts", "opens": 600, "strain": 0.0, "levels": {}, "placeholder": true},
}


## Runs this file's written effects on a struck foe (false: not one of ours).
static func hit_effect(id: String, p, e, share: float, power: float, _run) -> bool:
	match id:
		"spark":
			var fx: Dictionary = EFFECTS["spark"]
			var main = p.main
			var best = null
			var best_d := float(fx["hop"])
			for o in main.targets():
				if o == e or o.dead:
					continue
				var d: float = o.global_position.distance_to(e.global_position)
				if d < best_d:
					best_d = d
					best = o
			if best != null:
				best.take_hit(float(fx["damage"]) * share * power, Vector2.ZERO, 60.0)
				main.fx_bolt([e.global_position, best.global_position], Color(0.85, 0.95, 1.0))
			return true
	return false
