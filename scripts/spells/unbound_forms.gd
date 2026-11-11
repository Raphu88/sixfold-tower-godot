extends RefCounted
## The Unbound's new forms and the shape of their tree (one tree per body
## part, a node at each part level). The content contract is at the top of
## library.gd; the tree's rules are in tree.gd.
##
## TREE: part -> {level: node}. A node is one of:
##   {"fork": [variation id, variation id]}  choose one, for good (the other
##                                          can be learned later: tree.gd learn_skipped)
##   {"form": form id}                       a new form opens at this level
##   {"capstone": entry}                     the part's capstone (level 10)
## Levels 1 (today's forms), 4 and 8 (one more essence to combine) and 5
## (the gift) are filled in by tree.gd from unbound.gd.
##
## FORMS: new forms, as in library.gd FORMS ("part", "class", "says", their
## numbers, "strain" added to a technique's strain, "opens" = the level).
## "placeholder": true until written; cast_form runs the written ones.
## WORKED EXAMPLE: Volley (the hand, level 3): three small bolts in a fan.

static var TREE := {
	"hand": {2: {"fork": ["split", "quick"]}, 3: {"form": "volley"}, 6: {"fork": ["chain", "long"]}, 7: {"form": "brand"}, 9: {"fork": ["echo", "charged"]},
		10: {"capstone": {"name": "", "says": "", "placeholder": true}}},
	"legs": {2: {"fork": ["long", "quick"]}, 3: {"form": "stride"}, 6: {"fork": ["lingering", "mirrored"]}, 7: {"form": "vault"}, 9: {"fork": ["echo", "wide"]},
		10: {"capstone": {"name": "", "says": "", "placeholder": true}}},
	"heart": {2: {"fork": ["quick", "lingering"]}, 3: {"form": "heartbeat"}, 6: {"fork": ["echo", "wide"]}, 7: {"form": "wellspring"}, 9: {"fork": ["charged", "delayed"]},
		10: {"capstone": {"name": "", "says": "", "placeholder": true}}},
	"brow": {2: {"fork": ["chain", "quick"]}, 3: {"form": "glare"}, 6: {"fork": ["long", "delayed"]}, 7: {"form": "omen"}, 9: {"fork": ["split", "charged"]},
		10: {"capstone": {"name": "", "says": "", "placeholder": true}}},
	"throat": {2: {"fork": ["wide", "long"]}, 3: {"form": "hum"}, 6: {"fork": ["chain", "delayed"]}, 7: {"form": "call"}, 9: {"fork": ["echo", "split"]},
		10: {"capstone": {"name": "", "says": "", "placeholder": true}}},
	"back": {2: {"fork": ["wide", "lingering"]}, 3: {"form": "wake"}, 6: {"fork": ["delayed", "charged"]}, 7: {"form": "mantle"}, 9: {"fork": ["echo", "mirrored"]},
		10: {"capstone": {"name": "", "says": "", "placeholder": true}}},
}

static var FORMS := {
	"volley": {"name": "Volley", "part": "hand", "class": "hit", "says": "Three small bolts thrown in a fan", "damage": 6.0, "speed": 440.0, "range": 300.0,
		"count": 3, "spread": 16.0, "strain": 2.0, "opens": 3, "levels": {}},
	"brand": {"name": "Brand", "part": "hand", "class": "hit", "says": "A touch that sets a burst on a foe a moment later", "strain": 2.0, "opens": 7, "levels": {}, "placeholder": true},
	"stride": {"name": "Stride", "part": "legs", "class": "move", "says": "For a few seconds you leave a trail that carries the effect", "strain": 2.0, "opens": 3, "levels": {}, "placeholder": true},
	"vault": {"name": "Vault", "part": "legs", "class": "move", "says": "A hop back away from a foe, with a burst where you stood", "strain": 2.0, "opens": 7, "levels": {}, "placeholder": true},
	"wake": {"name": "Wake", "part": "back", "class": "hit", "says": "A slow ring that rolls outward from you", "strain": 2.0, "opens": 3, "levels": {}, "placeholder": true},
	"mantle": {"name": "Mantle", "part": "back", "class": "shell", "says": "A cloak that answers the next blow you take", "strain": 2.0, "opens": 7, "levels": {}, "placeholder": true},
	"hum": {"name": "Hum", "part": "throat", "class": "hit", "says": "A field around you that pulses three times", "strain": 2.0, "opens": 3, "levels": {}, "placeholder": true},
	"call": {"name": "Call", "part": "throat", "class": "hit", "says": "A burst at a spot you aim at, far away", "strain": 2.0, "opens": 7, "levels": {}, "placeholder": true},
	"glare": {"name": "Glare", "part": "brow", "class": "hit", "says": "A narrow beam you hold for a second", "strain": 2.0, "opens": 3, "levels": {}, "placeholder": true},
	"omen": {"name": "Omen", "part": "brow", "class": "hit", "says": "A sign on the floor that bursts when a foe steps on it", "strain": 2.0, "opens": 7, "levels": {}, "placeholder": true},
	"heartbeat": {"name": "Heartbeat", "part": "heart", "class": "self", "says": "The effect beats out around you every second for a while", "strain": 2.0, "opens": 3, "levels": {}, "placeholder": true},
	"wellspring": {"name": "Wellspring", "part": "heart", "class": "self", "says": "A pool on the floor that works on you while you stand in it", "strain": 2.0, "opens": 7, "levels": {}, "placeholder": true},
}


## Runs this file's written forms (-1: not one of ours).
static func cast_form(id: String, t: Dictionary, p, power: float, run, sh: Dictionary, w: Dictionary) -> int:
	match id:
		"volley":
			var Tech = load("res://scripts/technique.gd")
			var main = p.main
			var col: Color = Tech.color(Tech.lead(t))
			var n := int(sh.get("count", 3))
			var spread := deg_to_rad(float(sh.get("spread", 16.0)))
			var reach_k: float = Tech.reach_mult(w)
			for i in n:
				var dir: Vector2 = p.aim.rotated(spread * (float(i) - float(n - 1) * 0.5))
				run.add_bolt(p.global_position + dir * (p.radius + 6.0), dir * float(sh["speed"]), float(sh["range"]) * reach_k, float(sh["damage"]) * power, w, power, col)
			main.sfx("zap", 1.35, -5.0)
			return 0
	return -1
