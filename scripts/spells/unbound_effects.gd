extends RefCounted
## The Unbound's new effects: three more for each essence, each opening once
## that much of its essence has pooled in the body ("opens", raw density of
## that kind across the six parts: tree.gd effect_open). The content
## contract is at the top of library.gd.
##
## An effect is chosen for an essence in a technique (the technique's
## "effects": {kind: effect id}, chosen at the essence bench); it replaces
## that essence's base effect. Each has a phrase for each kind of form
## ("hit", "self" on yourself, "shell", "near" around you; "move" where a
## move form differs), and its numbers at full (lead) strength: the second
## essence acts at half of them, the third at about a third (technique.gd
## FLAVOUR), and damage grows with the part's level (power).
##   hit_effect(id, p, e, share, power, run)   on a struck foe (hits, moves,
##                                            marks, sight: every form that touches a foe)
##   self_effect(id, p, share, power, run, cls) on yourself (cls "self": Within,
##                                            "shell": a Shell rising)
## Unmaking's keep a small cost in health (technique.gd _toll, every cast).
## What stays a while (burning floor, mist, rubble, a flower, a thread) is
## drawn in code by Runner, a node under the room that a new floor clears.
##
## ECHOES: certain mixes come close to a bond's spell, never the same
## (library.gd echo_of finds them; a card says "echoes Gale Lift"). Recipes
## here add to library.gd's; ECHO_ACTS says, for each spell, the weaker
## touch of it a technique gains (at ECHO_POWER) and the strain it costs.
## Worked example: Spark (Air: the hit leaps to one more foe).

static var EFFECTS := {
	# --- Fire ---------------------------------------------------------------------
	"kindle": {"kind": "fire", "name": "Kindle", "says": "Leaves burning floor", "opens": 100, "strain": 0.0, "levels": {},
		"hit": "leaves the floor burning under what it hits", "self": "sets the floor burning around you", "shell": "leaves the floor burning around you as it rises", "near": "sets the floor burning under the foes near you",
		"radius": 38.0, "seconds": 3.0, "burn": 2.0, "burn_t": 1.5, "around": 70.0},
	"flare": {"kind": "fire", "name": "Flare", "says": "A second blast a moment later", "opens": 300, "strain": 0.0, "levels": {},
		"hit": "flares again a moment later, a blast where it struck", "self": "a blast of fire bursts out around you a moment later", "shell": "bursts into flame a moment after it rises", "near": "flares under the foes near you a moment later",
		"delay": 0.5, "radius": 48.0, "damage": 7.0, "burn": 2.0, "around": 80.0},
	"smoulder": {"kind": "fire", "name": "Smoulder", "says": "When the foe falls, its burn jumps on", "opens": 600, "strain": 0.0, "levels": {},
		"hit": "sets a smoulder that jumps to the next foe when this one falls", "self": "sets a smoulder in every foe near you, jumping on as each falls", "shell": "sets a smoulder in the foes near you as it rises", "near": "sets a smoulder in the foes near you",
		"burn": 3.0, "burn_t": 4.0, "watch": 5.0, "hop": 170.0, "jumps": 3, "around": 160.0},
	# --- Water --------------------------------------------------------------------
	"chill": {"kind": "water", "name": "Chill", "says": "Slows stack into a short freeze", "opens": 100, "strain": 0.0, "levels": {},
		"hit": "chills what it hits, and three chills freeze it", "self": "the air about you freezes: the foes near you are chilled", "shell": "breathes frost on the foes near you while it holds", "near": "chills the foes near you",
		"chill": 1.6, "stacks": 3, "freeze": 1.1, "window": 4.0, "around": 120.0},
	"current": {"kind": "water", "name": "Current", "says": "Carries struck foes along your aim", "opens": 300, "strain": 0.0, "levels": {},
		"hit": "carries what it hits along your aim", "self": "a current carries you a little way along your aim", "shell": "pushes the foes near you away on a current", "near": "carries the foes near you along your aim",
		"push": 420.0, "glide": 90.0, "around": 100.0},
	"mist": {"kind": "water", "name": "Mist", "says": "Foes inside lose sight of you", "opens": 600, "strain": 0.0, "levels": {},
		"hit": "leaves a mist where it hits: foes inside lose sight of you", "self": "wraps you in mist: foes inside lose sight of you", "shell": "rises in a mist that hides you", "near": "wraps the foes near you in mist",
		"radius": 64.0, "seconds": 4.0, "lose": 1.2},
	# --- Air ----------------------------------------------------------------------
	"spark": {"kind": "air", "name": "Spark", "says": "Leaps to one more foe", "opens": 100, "strain": 0.0, "levels": {},
		"hit": "leaps to one more foe nearby", "self": "sparks leap from you to the foes near you", "shell": "sparks at the foes near you as it rises", "near": "sparks between the foes near you",
		"damage": 5.0, "hop": 150.0, "around": 140.0, "most": 3},
	"lift": {"kind": "air", "name": "Lift", "says": "A light foe floats, helpless, for a moment", "opens": 300, "strain": 0.0, "levels": {},
		"hit": "lifts a light foe, helpless, for a moment", "self": "lifts the light foes near you off their feet", "shell": "lifts the light foes near you as it rises", "near": "lifts the light foes near you",
		"lift": 0.9, "weight": 1.6, "around": 90.0},
	"gust": {"kind": "air", "name": "Gust", "says": "Throws foes back hard", "opens": 600, "strain": 0.0, "levels": {},
		"hit": "throws what it hits back hard", "self": "a gust throws the foes near you back hard", "shell": "throws the foes near you back as it rises", "near": "throws the foes near you back",
		"force": 560.0, "around": 110.0},
	# --- Stone --------------------------------------------------------------------
	"rubble": {"kind": "stone", "name": "Rubble", "says": "Leaves rubble that slows", "opens": 100, "strain": 0.0, "levels": {},
		"hit": "leaves rubble where it hits, slowing what walks through", "self": "rubble falls in a ring around you, slowing foes", "shell": "sheds rubble around you as it rises", "near": "drops rubble under the foes near you",
		"radius": 42.0, "seconds": 4.0, "slow": 1.0, "around": 64.0},
	"grit": {"kind": "stone", "name": "Grit", "says": "You take less damage for a few seconds", "opens": 300, "strain": 0.0, "levels": {},
		"hit": "steels you: you take less damage for a few seconds", "self": "steels you a long while, and a skin of stone takes a blow", "shell": "steels you while it holds", "near": "steels you for each foe near you",
		"guard": 3.0, "long": 7.0, "skin": 10.0},
	"tremor": {"kind": "stone", "name": "Tremor", "says": "A small ring where it lands", "opens": 600, "strain": 0.0, "levels": {},
		"hit": "sends a small ring through the floor where it lands", "self": "sends a ring through the floor around you", "shell": "sends a ring through the floor as it rises", "near": "rings the floor under the foes near you",
		"radius": 62.0, "damage": 4.0, "stagger": 0.45, "around": 90.0},
	# --- Iron ---------------------------------------------------------------------
	"shrapnel": {"kind": "iron", "name": "Shrapnel", "says": "Shards fly from the struck foe", "opens": 100, "strain": 0.0, "levels": {},
		"hit": "throws shards from what it hits into the foes around it", "self": "shards fly out from you into the foes near you", "shell": "throws shards out as it rises", "near": "throws shards between the foes near you",
		"count": 3, "hop": 130.0, "damage": 3.0},
	"temper": {"kind": "iron", "name": "Temper", "says": "Your next weapon strikes hit harder", "opens": 300, "strain": 0.0, "levels": {},
		"hit": "tempers your weapon: your strikes hit harder for a moment", "self": "tempers your weapon a long while, and your stamina comes back", "shell": "tempers your weapon while it holds", "near": "tempers your weapon for each foe near you",
		"edge": 3.0, "long": 7.0, "stamina": 30.0},
	"lodestone": {"kind": "iron", "name": "Lodestone", "says": "Pulls loose foes together", "opens": 600, "strain": 0.0, "levels": {},
		"hit": "pulls the loose foes around what it hits together", "self": "pulls the loose foes near you in to you", "shell": "pulls the loose foes near you in as it rises", "near": "pulls the foes near you together",
		"pull": 320.0, "radius": 150.0},
	# --- Blade --------------------------------------------------------------------
	"rend": {"kind": "blade", "name": "Rend", "says": "Bleeds stack", "opens": 100, "strain": 0.0, "levels": {},
		"hit": "opens a bleed that deepens with each hit", "self": "opens a deepening bleed in the foes near you", "shell": "rends the foes near you as it rises", "near": "rends the foes near you",
		"bleed": 2.5, "stacks": 5, "keep": 4.0, "around": 90.0},
	"shards": {"kind": "blade", "name": "Shards", "says": "Blades left on the floor cut what walks over them", "opens": 300, "strain": 0.0, "levels": {},
		"hit": "leaves blades on the floor that cut what walks over them", "self": "scatters blades on the floor around you", "shell": "scatters blades around you as it rises", "near": "scatters blades under the foes near you",
		"radius": 34.0, "seconds": 4.0, "damage": 2.5, "around": 64.0},
	"answer": {"kind": "blade", "name": "Answer", "says": "The next foe to swing at you is cut first", "opens": 600, "strain": 0.0, "levels": {},
		"hit": "readies an answer: the next foe to swing at you is cut first", "self": "readies an answer for a long while: the next foe to swing at you is cut first", "shell": "answers the next foe to swing at you while it holds", "near": "readies an answer for the foes near you",
		"ready": 4.0, "long": 9.0, "damage": 10.0, "bleed": 2.0, "reach": 80.0},
	# --- Life ---------------------------------------------------------------------
	"bloom": {"kind": "life", "name": "Bloom", "says": "A flower that heals you when you step on it", "opens": 100, "strain": 0.0, "levels": {},
		"hit": "leaves a flower where it hits that heals you when you step on it", "self": "three flowers open around you, each healing you when you step on it", "shell": "leaves flowers around you as it rises", "near": "leaves flowers under the foes near you",
		"heal": 10.0, "seconds": 7.0, "most": 4, "around": 60.0},
	"lifeline": {"kind": "life", "name": "Lifeline", "says": "A thread that drinks from a foe", "opens": 300, "strain": 0.0, "levels": {},
		"hit": "ties a thread to what it hits that drinks its life into yours", "self": "ties a thread to the nearest foe that drinks its life into yours", "shell": "ties a thread to the nearest foe while it holds", "near": "ties threads to the foes near you",
		"drain": 2.0, "seconds": 3.0, "reach": 260.0, "share": 0.8},
	"second_wind": {"kind": "life", "name": "Second Wind", "says": "Stamina back on each hit", "opens": 600, "strain": 0.0, "levels": {},
		"hit": "gives you stamina back for each foe it hits", "self": "fills your stamina and mends you a little", "shell": "fills your stamina as it rises", "near": "gives you stamina for each foe near you",
		"stamina": 12.0, "full": 60.0, "mend": 4.0},
	# --- Unmaking -----------------------------------------------------------------
	"unravel": {"kind": "unmaking", "name": "Unravel", "says": "Armour stays stripped for a while", "opens": 100, "strain": 0.0, "levels": {},
		"hit": "strips what it hits of armour for a while, at a cost in your health", "self": "strips the foes near you of armour, at a cost in health", "shell": "strips the foes near you of armour as it rises, at a cost in health", "near": "strips the foes near you of armour, at a cost in health",
		"strip": 3.0, "around": 130.0},
	"hollow": {"kind": "unmaking", "name": "Hollow", "says": "The foe takes more from everything", "opens": 300, "strain": 0.0, "levels": {},
		"hit": "hollows what it hits: it takes more from everything, at a cost in your health", "self": "hollows the foes near you, at a cost in health", "shell": "hollows the foes near you as it rises, at a cost in health", "near": "hollows the foes near you, at a cost in health",
		"more": 0.25, "seconds": 4.0, "around": 130.0},
	"fray": {"kind": "unmaking", "name": "Fray", "says": "Erodes faster the longer it lasts", "opens": 600, "strain": 0.0, "levels": {},
		"hit": "frays what it hits, eroding faster the longer it lasts, at a cost in your health", "self": "frays the foes near you, at a cost in health", "shell": "frays the foes near you as it rises, at a cost in health", "near": "frays the foes near you, at a cost in health",
		"erode": 2.0, "grow": 0.6, "seconds": 4.0, "around": 120.0},
}

## Echoes (more than library.gd's own six): a technique of this form, led by
## this essence, with every one of "with" among its others, comes close to
## the bond's spell. Found by experimenting; remembered per climber (tree.gd note_echo).
static var ECHOES := [
	{"form": "pull", "lead": "water", "with": ["iron"], "spell": "undertow", "bond": "deepcaller"},
	{"form": "leap", "lead": "stone", "with": ["iron"], "spell": "quake", "bond": "sandshaper"},
	{"form": "strike", "lead": "fire", "with": ["blade"], "spell": "kindle_blade", "bond": "flameblade"},
	{"form": "bolt", "lead": "blade", "with": ["iron"], "spell": "conjured_blades", "bond": "blade_forger"},
	{"form": "sight", "lead": "fire", "with": ["air"], "spell": "smoke_veil", "bond": "ashwalker"},
	{"form": "mark", "lead": "iron", "with": ["stone"], "spell": "challenge", "bond": "warden"},
	{"form": "within", "lead": "life", "with": ["fire"], "spell": "rekindle", "bond": "rekindler"},
	{"form": "dash", "lead": "fire", "with": ["air"], "spell": "wingburst", "bond": "flamewing"},
	{"form": "bolt", "lead": "water", "with": ["blade"], "spell": "venom_spit", "bond": "venomist"},
	{"form": "mark", "lead": "blade", "with": ["air"], "spell": "track", "bond": "hunter"},
]
## An echo acts at this share of what the technique's power would give it.
const ECHO_POWER := 0.6
## What each echo adds to a cast (a weaker touch of the spell) and its
## strain: "says" is the plain line the bench and the cards show.
static var ECHO_ACTS := {
	"gale_lift": {"says": "lifts the light foes in front of you for a moment", "strain": 6.0, "lift": 0.7, "reach": 130.0, "arc": 40.0},
	"piercing_shot": {"says": "a thin shot pierces every foe in a line", "strain": 6.0, "damage": 6.0, "length": 300.0},
	"barrier": {"says": "a thin barrier takes a little more", "strain": 6.0, "shield": 12.0, "seconds": 4.0},
	"tidal_surge": {"says": "a wave washes the foes in front of you back, slowed", "strain": 6.0, "push": 300.0, "reach": 150.0, "arc": 45.0, "slow": 1.5},
	"fireball": {"says": "it bursts in a small blast ahead of you", "strain": 6.0, "damage": 6.0, "radius": 50.0, "at": 160.0, "delay": 0.35},
	"chain_lightning": {"says": "lightning leaps on to two more foes", "strain": 6.0, "damage": 4.0, "leaps": 2, "hop": 150.0, "stun": 0.2},
	"undertow": {"says": "drinks a little from the nearest foe in front", "strain": 6.0, "damage": 5.0, "heal": 3.0, "reach": 200.0},
	"quake": {"says": "the landing sends a ring through the floor", "strain": 6.0, "radius": 90.0, "stagger": 0.5, "delay": 0.42},
	"kindle_blade": {"says": "your weapon burns for a while", "strain": 6.0, "seconds": 4.0, "burn": 3.0},
	"conjured_blades": {"says": "three blades fly to the nearest foes", "strain": 6.0, "count": 3, "damage": 4.0, "reach": 220.0},
	"smoke_veil": {"says": "smoke rises around you: foes lose sight of you", "strain": 6.0, "radius": 90.0, "seconds": 3.0},
	"challenge": {"says": "the marked foe comes for you, and you stand firm", "strain": 6.0, "seconds": 3.0},
	"rekindle": {"says": "warmth mends you over a few seconds", "strain": 6.0, "mend": 18.0, "seconds": 4.0},
	"wingburst": {"says": "fire bursts where the dash ends", "strain": 6.0, "damage": 5.0, "radius": 70.0, "delay": 0.2},
	"venom_spit": {"says": "the foes in front of you are poisoned", "strain": 6.0, "stacks": 2, "reach": 150.0, "arc": 30.0},
	"track": {"says": "every foe shows through walls for a while", "strain": 6.0, "seconds": 6.0},
}

## How many times each effect has worked (the tests read it).
static var FIRED := {}
## When an effect last left something on a foe (a field, a blast): so a
## field that strikes every half second doesn't stack them. "id:foe" -> msec.
static var _last := {}
const GAP_MS := 450


static func _lib():
	return load("res://scripts/library.gd")


static func _col(id: String) -> Color:
	return _lib().color(String(EFFECTS[id]["kind"]))


static func _fired(id: String) -> void:
	FIRED[id] = int(FIRED.get(id, 0)) + 1


## True if this effect may leave something on this foe again (GAP_MS since the last).
static func _fresh(id: String, e) -> bool:
	var key := "%s:%d" % [id, e.get_instance_id() if e != null else 0]
	var now := Time.get_ticks_msec()
	if now - int(_last.get(key, -99999)) < GAP_MS:
		return false
	_last[key] = now
	return true


## The foes within `r` of a point, nearest first.
static func _near(main, pos: Vector2, r: float, skip = null) -> Array:
	var out: Array = []
	for o in main.targets():
		if o == skip or o.dead:
			continue
		if o.global_position.distance_to(pos) <= r + o.radius:
			out.append(o)
	out.sort_custom(func(a, b): return a.global_position.distance_squared_to(pos) < b.global_position.distance_squared_to(pos))
	return out


# --- on a struck foe ----------------------------------------------------------------

## Runs this file's effects on a struck foe (false: not one of ours).
static func hit_effect(id: String, p, e, share: float, power: float, run) -> bool:
	if not EFFECTS.has(id) or e == null or not is_instance_valid(e):
		return false
	var fx: Dictionary = EFFECTS[id]
	var main = p.main
	var col := _col(id)
	var at: Vector2 = e.global_position
	match id:
		"kindle":
			if _fresh(id, e):
				_burning_floor(main, at, float(fx["radius"]) * (0.7 + 0.3 * share), float(fx["seconds"]), float(fx["burn"]) * share * power, float(fx["burn_t"]), col)
		"flare":
			if _fresh(id, e):
				_blast_later(p, at, float(fx["delay"]), float(fx["radius"]), float(fx["damage"]) * share * power, float(fx["burn"]) * share * power, col)
		"smoulder":
			_smoulder(p, e, share, power, int(fx["jumps"]))
		"chill":
			_chill(main, e, share)
		"current":
			var push: float = float(fx["push"]) * share * (0.25 if e.is_boss() else 1.0)
			e.tide_push(p.aim * push)
			e.knock = p.aim * push * 0.6
			runner(main).decal("current", at, 0.5, 30.0, col, {"dir": p.aim})
		"mist":
			if _fresh(id, e):
				_mist(p, at, float(fx["radius"]), float(fx["seconds"]) * (0.6 + 0.4 * share), float(fx["lose"]), col)
		"spark":
			var best = null
			var best_d := float(fx["hop"])
			for o in main.targets():
				if o == e or o.dead:
					continue
				var d: float = o.global_position.distance_to(at)
				if d < best_d:
					best_d = d
					best = o
			if best != null:
				best.take_hit(float(fx["damage"]) * share * power, Vector2.ZERO, 60.0)
				main.fx_bolt([at, best.global_position], Color(0.85, 0.95, 1.0))
		"lift":
			_lift(main, e, share)
		"gust":
			_gust(main, e, (at - p.global_position).normalized() if at.distance_to(p.global_position) > 1.0 else p.aim, float(fx["force"]) * share, col)
		"rubble":
			if _fresh(id, e):
				_rubble(main, at, float(fx["radius"]), float(fx["seconds"]), float(fx["slow"]) * (0.5 + 0.5 * share), col)
		"grit":
			_grit(p, float(fx["guard"]) * share + 1.0)
		"tremor":
			if _fresh(id, e):
				_tremor(p, at, float(fx["radius"]) * (0.7 + 0.3 * share), float(fx["damage"]) * share * power, float(fx["stagger"]) * share, col, e)
		"shrapnel":
			_shrapnel(p, at, int(fx["count"]), float(fx["hop"]), float(fx["damage"]) * share * power, col, e)
		"temper":
			_temper(p, float(fx["edge"]) * share + 1.0, 0.0)
		"lodestone":
			_lodestone(main, at, float(fx["radius"]), float(fx["pull"]) * share, col, e)
		"rend":
			_rend(p, e, share, power, run)
		"shards":
			if _fresh(id, e):
				_blades(p, at, float(fx["radius"]), float(fx["seconds"]), float(fx["damage"]) * share * power, col)
		"answer":
			_answer(p, float(fx["ready"]) * share + 1.5, float(fx["damage"]) * share * power, float(fx["bleed"]) * share * power, run)
		"bloom":
			if _fresh(id, e):
				_bloom(p, at, float(fx["heal"]) * share * power, float(fx["seconds"]), col)
		"lifeline":
			_lifeline(p, e, float(fx["drain"]) * share * power, float(fx["seconds"]), col)
		"second_wind":
			_stamina(p, float(fx["stamina"]) * share)
		"unravel":
			_unravel(main, e, float(fx["strip"]) * (0.5 + share), col)
		"hollow":
			_hollow(main, e, float(fx["more"]) * (0.4 + 0.6 * share), float(fx["seconds"]), col)
		"fray":
			_fray(p, e, float(fx["erode"]) * share * power, float(fx["grow"]), float(fx["seconds"]), col)
		_:
			return false
	_fired(id)
	return true


# --- on yourself (Within) or a shell rising ------------------------------------------

## Runs this file's effects on yourself: `cls` "self" (Within) or "shell"
## (a Shell rising: the effect gathers around you). False: not one of ours.
static func self_effect(id: String, p, share: float, power: float, run, cls := "self") -> bool:
	if not EFFECTS.has(id):
		return false
	var fx: Dictionary = EFFECTS[id]
	var main = p.main
	var col := _col(id)
	var at: Vector2 = p.global_position
	var shell := cls == "shell"
	var around := float(fx.get("around", 110.0))
	match id:
		"kindle":
			_burning_floor(main, at, around, float(fx["seconds"]) + 1.0, float(fx["burn"]) * share * power, float(fx["burn_t"]), col)
		"flare":
			_blast_later(p, at, float(fx["delay"]), around, float(fx["damage"]) * share * power, float(fx["burn"]) * share * power, col, true)
		"smoulder":
			for o in _near(main, at, around):
				_smoulder(p, o, share * 0.7, power, int(fx["jumps"]))
			main.fx_ring(at, col, around, 0.4, 2.0)
		"chill":
			if shell:
				_spell_fx().field(main, at, around * 0.8, 4.0, 0.8, col, func(foes: Array):
					for o in foes:
						_chill(main, o, share * 0.6))
				runner(main).decal("frost_ring", at, 4.0, around * 0.8, col)
			for o in _near(main, at, around):
				_chill(main, o, share)
				_chill(main, o, share)
			main.fx_ring(at, col, around, 0.4, 3.0)
		"current":
			if shell:
				for o in _near(main, at, around):
					var dir: Vector2 = (o.global_position - at).normalized() if o.global_position.distance_to(at) > 1.0 else Vector2.RIGHT
					o.tide_push(dir * float(fx["push"]) * share * (0.25 if o.is_boss() else 1.0))
				main.fx_ring(at, col, around, 0.4, 4.0)
			else:
				var dist: float = float(fx["glide"]) * (0.5 + 0.5 * share)
				p.roll_dir = p.aim
				p.roll_t = 0.18
				p.roll_speed = dist / 0.18
				p.iframes = maxf(p.iframes, 0.2)
				runner(main).decal("current", at, 0.5, 30.0, col, {"dir": p.aim})
		"mist":
			_mist(p, at, float(fx["radius"]) * 1.3, float(fx["seconds"]) * (0.6 + 0.4 * share), float(fx["lose"]), col)
		"spark":
			var n := 0
			for o in _near(main, at, around):
				if n >= int(fx["most"]):
					break
				o.take_hit(float(fx["damage"]) * share * power, Vector2.ZERO, 60.0)
				main.fx_bolt([at, o.global_position], Color(0.85, 0.95, 1.0))
				n += 1
			runner(main).decal("spark", at, 0.4, 26.0, col)
		"lift":
			for o in _near(main, at, around):
				_lift(main, o, share)
			main.fx_ring(at, col, around, 0.4, 2.0)
		"gust":
			for o in _near(main, at, around):
				var dir: Vector2 = (o.global_position - at).normalized() if o.global_position.distance_to(at) > 1.0 else p.aim
				_gust(main, o, dir, float(fx["force"]) * share, col)
			runner(main).decal("gust_ring", at, 0.5, around, col)
		"rubble":
			_rubble(main, at, around + 10.0, float(fx["seconds"]), float(fx["slow"]) * (0.5 + 0.5 * share), col)
		"grit":
			_grit(p, (float(fx["long"]) if not shell else 5.0) * share + 1.0)
			if not shell:
				p.raise_barrier(float(fx["skin"]) * share * power, 5.0, false, col)
		"tremor":
			_tremor(p, at, around, float(fx["damage"]) * share * power, float(fx["stagger"]) * share, col, null)
		"shrapnel":
			_shrapnel(p, at, int(fx["count"]) + 3, float(fx["hop"]), float(fx["damage"]) * share * power, col, null)
		"temper":
			_temper(p, (float(fx["long"]) if not shell else 5.0) * share + 1.0, float(fx["stamina"]) * share if not shell else 0.0)
		"lodestone":
			_lodestone(main, at, float(fx["radius"]) + 10.0, float(fx["pull"]) * share, col, null)
		"rend":
			for o in _near(main, at, around):
				_rend(p, o, share, power, run)
			main.fx_ring(at, col, around, 0.35, 2.0)
		"shards":
			_blades(p, at, around, float(fx["seconds"]), float(fx["damage"]) * share * power, col)
		"answer":
			_answer(p, (float(fx["long"]) if not shell else 5.0) * share + 1.5, float(fx["damage"]) * share * power, float(fx["bleed"]) * share * power, run)
		"bloom":
			for i in 3:
				var spot: Vector2 = at + Vector2.from_angle(p.aim.angle() + PI + (float(i) - 1.0) * 0.9) * around
				_bloom(p, spot, float(fx["heal"]) * share * power, float(fx["seconds"]), col)
		"lifeline":
			var near := _near(main, at, float(fx["reach"]))
			if not near.is_empty():
				_lifeline(p, near[0], float(fx["drain"]) * share * power, float(fx["seconds"]) + (2.0 if shell else 0.0), col)
			else:
				main.fx_text(at + Vector2(0, -40), "no one to drink from", col)
		"second_wind":
			_stamina(p, float(fx["full"]) * share)
			if not shell:
				var T = load("res://scripts/technique.gd")
				T._heal(p, float(fx["mend"]) * share * power)
		"unravel":
			for o in _near(main, at, around):
				_unravel(main, o, float(fx["strip"]) * (0.5 + share), col)
			main.fx_ring(at, col, around, 0.4, 2.0)
		"hollow":
			for o in _near(main, at, around):
				_hollow(main, o, float(fx["more"]) * (0.4 + 0.6 * share), float(fx["seconds"]), col)
			main.fx_ring(at, col, around, 0.4, 2.0)
		"fray":
			for o in _near(main, at, around):
				_fray(p, o, float(fx["erode"]) * share * power, float(fx["grow"]), float(fx["seconds"]), col)
			main.fx_ring(at, col, around, 0.4, 2.0)
		_:
			return false
	_fired(id)
	return true


static func _spell_fx():
	return load("res://scripts/spell_fx.gd")


# --- what each effect does ------------------------------------------------------------

## Burning floor: foes standing in it burn.
static func _burning_floor(main, at: Vector2, r: float, seconds: float, burn: float, burn_t: float, col: Color) -> void:
	_spell_fx().field(main, at, r, seconds, 0.5, col, func(foes: Array):
		for o in foes:
			o.ignite(burn, burn_t))
	runner(main).decal("flames", at, seconds, r, col)
	main.sfx("burn", 1.2, -8.0)


## A blast a moment later (and the warning ring meanwhile).
static func _blast_later(p, at: Vector2, delay: float, r: float, dmg: float, burn: float, col: Color, around_you := false) -> void:
	var main = p.main
	_spell_fx().mark(main, at, delay, col)
	_spell_fx().later(main, delay, func():
		var c: Vector2 = p.global_position if around_you and is_instance_valid(p) else at
		for o in _near(main, c, r):
			o.take_hit(dmg, (o.global_position - c).normalized() if o.global_position.distance_to(c) > 1.0 else Vector2.ZERO, 160.0)
			if is_instance_valid(o) and not o.dead:
				o.ignite(burn, 2.0)
		runner(main).decal("blast", c, 0.45, r, col)
		main.light_flash(c, col, 1.2, 1.6, 0.3)
		main.sfx("burn", 0.8, -4.0))


## Smoulder: burns, and when this foe falls while it smoulders, the burn
## jumps to the nearest foe (a few times).
static func _smoulder(p, e, share: float, power: float, jumps: int) -> void:
	var fx: Dictionary = EFFECTS["smoulder"]
	var main = p.main
	var col := _col("smoulder")
	e.ignite(float(fx["burn"]) * share * power, float(fx["burn_t"]))
	var st := {"e": e, "t": float(fx["watch"]), "left": jumps, "pos": e.global_position}
	runner(main).tick(func(dt: float) -> bool:
		st["t"] -= dt
		var o = st["e"]
		if is_instance_valid(o) and not o.dead:
			st["pos"] = o.global_position
			return st["t"] > 0.0
		# It fell: the burn jumps on.
		if int(st["left"]) <= 0:
			return false
		var next := _near(main, st["pos"], float(fx["hop"]))
		if next.is_empty():
			return false
		var n = next[0]
		main.fx_bolt([st["pos"], n.global_position], col)
		runner(main).decal("ember", n.global_position, 0.6, 16.0, col, {"a": n})
		n.ignite(float(fx["burn"]) * share * power, float(fx["burn_t"]))
		st["e"] = n
		st["t"] = float(fx["watch"])
		st["left"] = int(st["left"]) - 1
		return true)
	runner(main).decal("ember", e.global_position, float(fx["watch"]), 14.0, col, {"a": e})


## Chill: slows; three chills within a few seconds freeze it a moment.
static func _chill(main, e, share: float) -> void:
	var fx: Dictionary = EFFECTS["chill"]
	var now := Time.get_ticks_msec() * 0.001
	var stacks: int = int(e.get_meta("chill_n", 0)) if now - float(e.get_meta("chill_at", -99.0)) < float(fx["window"]) else 0
	stacks += 1
	e.chill_t = maxf(e.chill_t, float(fx["chill"]) * (0.5 + share))
	if stacks >= int(fx["stacks"]):
		stacks = 0
		e.stagger(float(fx["freeze"]) * (0.5 + 0.5 * share) * (0.5 if e.is_boss() else 1.0))
		main.fx_text(e.global_position + Vector2(0, -e.radius - 22.0), "Frozen", _col("chill").lightened(0.3))
		runner(main).decal("frost", e.global_position, 1.0, e.radius + 6.0, _col("chill"), {"a": e})
		main.sfx("glint", 0.7, -4.0)
	e.set_meta("chill_n", stacks)
	e.set_meta("chill_at", now)


static func _mist(p, at: Vector2, r: float, seconds: float, lose: float, col: Color) -> void:
	var main = p.main
	_spell_fx().field(main, at, r, seconds, 0.4, col, func(foes: Array):
		for o in foes:
			o.lose_track(lose, null))
	runner(main).decal("mist", at, seconds, r, col.lightened(0.35))
	main.sfx("hiss", 0.8, -8.0)


static func _lift(main, e, share: float) -> void:
	var fx: Dictionary = EFFECTS["lift"]
	if float(e.weight) <= float(fx["weight"]) and not e.is_boss():
		e.lift(float(fx["lift"]) * (0.4 + 0.6 * share))
	else:
		e.stagger(0.3 * share)
	runner(main).decal("lift", e.global_position, 0.6, e.radius + 4.0, _col("lift"), {"a": e})


static func _gust(main, e, dir: Vector2, force: float, col: Color) -> void:
	var k := 0.2 if e.is_boss() else 1.0
	e.tide_push(dir * force * k)
	e.knock = dir * force * k * 0.7
	runner(main).decal("gust", e.global_position, 0.45, 28.0, col, {"dir": dir})
	main.sfx("gust", 1.3, -6.0)


static func _rubble(main, at: Vector2, r: float, seconds: float, slow: float, col: Color) -> void:
	_spell_fx().field(main, at, r, seconds, 0.4, col, func(foes: Array):
		for o in foes:
			o.chill_t = maxf(o.chill_t, slow))
	runner(main).decal("rubble", at, seconds, r, col)
	main.sfx("slam", 1.4, -10.0)


static func _grit(p, seconds: float) -> void:
	p.stone_t = maxf(p.stone_t, seconds)
	runner(p.main).decal("grit", p.global_position, 0.6, p.radius + 8.0, _col("grit"), {"a": p})
	p.main.fx_text(p.global_position + Vector2(0, -44), "Grit", _col("grit").lightened(0.35))


static func _tremor(p, at: Vector2, r: float, dmg: float, stagger: float, col: Color, skip) -> void:
	var main = p.main
	var hold := {"skip": skip}  # (a foe held in a dictionary: it may be gone by then)
	_spell_fx().later(main, 0.15, func():
		var sk = hold["skip"] if is_instance_valid(hold["skip"]) else null
		for o in _near(main, at, r, sk):
			o.take_hit(dmg, (o.global_position - at).normalized() if o.global_position.distance_to(at) > 1.0 else Vector2.ZERO, 120.0, true)
			if is_instance_valid(o) and not o.dead:
				o.stagger(stagger)
		runner(main).decal("tremor", at, 0.55, r, col)
		main.shake(3.0)
		main.sfx("slam", 0.9, -6.0))


static func _shrapnel(p, at: Vector2, count: int, hop: float, dmg: float, col: Color, skip) -> void:
	var main = p.main
	var n := 0
	for o in _near(main, at, hop, skip):
		if n >= count:
			break
		o.take_hit(dmg, (o.global_position - at).normalized(), 90.0, false, true)
		runner(main).decal("shard", at, 0.3, 4.0, col, {"to": o.global_position})
		n += 1
	# The shards that found no one fly out anyway.
	for i in range(n, count):
		var ang := TAU * float(i) / float(count) + randf() * 0.5
		runner(main).decal("shard", at, 0.3, 4.0, col, {"to": at + Vector2.from_angle(ang) * hop * 0.6})
	main.sfx("hit_armor", 1.5, -8.0)


static func _temper(p, seconds: float, stamina: float) -> void:
	p.edge_t = maxf(p.edge_t, seconds)
	if stamina > 0.0:
		_stamina(p, stamina)
	runner(p.main).decal("temper", p.global_position, 0.7, p.radius + 10.0, _col("temper"), {"a": p})
	p.main.fx_text(p.global_position + Vector2(0, -44), "Tempered", _col("temper").lightened(0.4))


static func _lodestone(main, at: Vector2, r: float, pull: float, col: Color, skip) -> void:
	for o in _near(main, at, r, skip):
		if o.is_boss():
			continue
		var to: Vector2 = at - o.global_position
		if to.length() < o.radius + 10.0:
			continue
		o.tide_push(to.normalized() * minf(pull, to.length() * 3.0))
		runner(main).decal("lode", at, 0.45, 4.0, col, {"to": o.global_position})
	main.fx_ring(at, col, 26.0, 0.35, 3.0)
	main.sfx("glint", 0.6, -8.0)


## Rend: each hit deepens the bleed (up to "stacks"), the bleed growing with it.
static func _rend(p, e, share: float, power: float, run) -> void:
	var fx: Dictionary = EFFECTS["rend"]
	var now := Time.get_ticks_msec() * 0.001
	var n: int = int(e.get_meta("rend_n", 0)) if now - float(e.get_meta("rend_at", -99.0)) < float(fx["keep"]) else 0
	n = mini(n + 1, int(fx["stacks"]))
	e.set_meta("rend_n", n)
	e.set_meta("rend_at", now)
	if run != null and run.has_method("add_dot"):
		run.add_dot(e, float(fx["bleed"]) * float(n) * share * power, 3.0, _col("rend"))
	runner(p.main).decal("rend", e.global_position, 0.8, e.radius, _col("rend"), {"a": e, "n": n})


## Blades on the floor: what walks over them is cut.
static func _blades(p, at: Vector2, r: float, seconds: float, dmg: float, col: Color) -> void:
	var main = p.main
	_spell_fx().field(main, at, r, seconds, 0.5, col, func(foes: Array):
		for o in foes:
			if o.velocity.length() > 5.0 or o.is_attacking():
				o.take_hit(dmg, Vector2.ZERO, 0.0, false, true))
	runner(main).decal("blades", at, seconds, r, col)
	main.sfx("glint", 1.4, -8.0)


## Answer: for a while, the first foe to start a swing at you (near enough)
## is cut first.
static func _answer(p, seconds: float, dmg: float, bleed: float, run) -> void:
	var main = p.main
	var fx: Dictionary = EFFECTS["answer"]
	var col := _col("answer")
	var st := {"t": seconds}
	var r := runner(main)
	r.answer_t = maxf(r.answer_t, seconds)
	r.tick(func(dt: float) -> bool:
		st["t"] -= dt
		if not is_instance_valid(p) or p.dead:
			return false
		for o in _near(main, p.global_position, float(fx["reach"])):
			if o.is_attacking():
				o.take_hit(dmg, (o.global_position - p.global_position).normalized(), 200.0, true, true)
				if is_instance_valid(o) and not o.dead and run != null and run.has_method("add_dot"):
					run.add_dot(o, bleed, 3.0, col)
				main.fx_bolt([p.global_position, o.global_position], col.lightened(0.4))
				main.fx_text(o.global_position + Vector2(0, -o.radius - 22.0), "Answered", col.lightened(0.3))
				main.sfx("parry", 1.3, -4.0)
				r.answer_t = 0.0
				return false
		return st["t"] > 0.0)
	main.fx_text(p.global_position + Vector2(0, -44), "Ready", col.lightened(0.3))


## A flower on the floor: step on it and it heals you (a few at most).
static func _bloom(p, at: Vector2, heal: float, seconds: float, col: Color) -> void:
	var main = p.main
	var r := runner(main)
	var fx: Dictionary = EFFECTS["bloom"]
	var mine: Array = r.decals.filter(func(d): return d["kind"] == "flower")
	while mine.size() >= int(fx["most"]):
		r.decals.erase(mine.pop_front())
	var d: Dictionary = r.decal("flower", at, seconds, 12.0, col)
	r.tick(func(_dt: float) -> bool:
		if not r.decals.has(d):
			return false
		if is_instance_valid(p) and not p.dead and p.global_position.distance_to(at) < p.radius + 14.0:
			var T = load("res://scripts/technique.gd")
			T._heal(p, heal)
			main.fx_burst(at, Vector2.UP, col, 8, 90.0)
			main.sfx("pickup", 1.3, -6.0)
			r.decals.erase(d)
			return false
		return true)


## A thread that drinks from a foe into you while it holds (it breaks if
## you get too far apart).
static func _lifeline(p, e, drain: float, seconds: float, col: Color) -> void:
	var main = p.main
	var fx: Dictionary = EFFECTS["lifeline"]
	if e.has_meta("lifeline") and Time.get_ticks_msec() < int(e.get_meta("lifeline")):
		return  # (one thread to a foe)
	e.set_meta("lifeline", Time.get_ticks_msec() + int(seconds * 1000.0))
	var st := {"t": seconds, "tick": 0.5, "e": e}  # (the foe held here, not in the closure: it may fall)
	var r := runner(main)
	var d: Dictionary = r.decal("thread", e.global_position, seconds, 2.0, col, {"a": p, "b": e})
	r.tick(func(dt: float) -> bool:
		st["t"] -= dt
		st["tick"] -= dt
		var e2 = st["e"]
		if not is_instance_valid(p) or p.dead or not is_instance_valid(e2) or e2.dead or p.global_position.distance_to(e2.global_position) > float(fx["reach"]):
			r.decals.erase(d)
			return false
		if st["tick"] <= 0.0:
			st["tick"] = 0.5
			e2.take_hit(drain, Vector2.ZERO, 0.0, false, true)
			var T = load("res://scripts/technique.gd")
			T._heal(p, drain * float(fx["share"]))
		if st["t"] <= 0.0:
			r.decals.erase(d)
			return false
		return true)


static func _stamina(p, amount: float) -> void:
	var was: float = p.sta
	p.sta = minf(p.max_sta, p.sta + amount)
	if p.sta - was >= 1.0:
		runner(p.main).decal("wind", p.global_position, 0.5, p.radius + 6.0, _col("second_wind"), {"a": p})


static func _unravel(main, e, seconds: float, col: Color) -> void:
	e.unravel_t = maxf(e.unravel_t, seconds)
	runner(main).decal("unravel", e.global_position, seconds, e.radius + 4.0, col, {"a": e})


static func _hollow(main, e, more: float, seconds: float, col: Color) -> void:
	e.hollow_k = maxf(e.hollow_k if e.hollow_t > 0.0 else 0.0, more)
	e.hollow_t = maxf(e.hollow_t, seconds)
	runner(main).decal("hollow", e.global_position, seconds, e.radius + 5.0, col, {"a": e})


## Fray: an erosion that grows each second it lasts.
static func _fray(p, e, dps: float, grow: float, seconds: float, col: Color) -> void:
	var main = p.main
	var st := {"t": seconds, "tick": 0.5, "age": 0.0, "e": e}  # (the foe held here: it may fall)
	runner(main).decal("unravel", e.global_position, seconds, e.radius + 2.0, col, {"a": e})
	runner(main).tick(func(dt: float) -> bool:
		st["t"] -= dt
		st["age"] += dt
		st["tick"] -= dt
		var e2 = st["e"]
		if not is_instance_valid(e2) or e2.dead or st["t"] <= 0.0:
			return false
		if st["tick"] <= 0.0:
			st["tick"] = 0.5
			e2.take_hit(dps * 0.5 * (1.0 + grow * float(st["age"])), Vector2.ZERO, 0.0, false, true)
			main.fx_burst(e2.global_position, Vector2.UP, col, 3, 70.0)
		return true)


# --- echoes ------------------------------------------------------------------------

## The recipe a technique matches (as library.gd echo_of finds it), or {}.
static func echo_recipe(t: Dictionary) -> Dictionary:
	if not (t.get("kinds") is Array) or t["kinds"].is_empty():
		return {}
	var lead := String(t["kinds"][0])
	for r in _lib().ECHOES:
		if String(r.get("form", "")) != String(t.get("shape", "")) or String(r.get("lead", "")) != lead:
			continue
		var ok := true
		for k in r.get("with", []):
			if not k in t["kinds"].slice(1):
				ok = false
		if ok:
			return r
	return {}


## What an echo adds, in plain words ("" if it isn't an echo).
static func echo_says(t: Dictionary) -> String:
	var r := echo_recipe(t)
	return String(ECHO_ACTS.get(String(r.get("spell", "")), {}).get("says", "")) if not r.is_empty() else ""


## The strain an echo adds to each cast (0 if it isn't one).
static func echo_strain(t: Dictionary) -> float:
	var r := echo_recipe(t)
	return float(ECHO_ACTS.get(String(r.get("spell", "")), {}).get("strain", 0.0)) if not r.is_empty() else 0.0


## A technique that echoes a bond's spell: after its own cast, a weaker
## touch of that spell (ECHO_ACTS). True if it echoed.
static func cast_echo(t: Dictionary, p, power: float, run) -> bool:
	var r := echo_recipe(t)
	if r.is_empty():
		return false
	var spell := String(r["spell"])
	var a: Dictionary = ECHO_ACTS.get(spell, {})
	if a.is_empty():
		return false
	var main = p.main
	var pw := power * ECHO_POWER
	var at: Vector2 = p.global_position
	var aim: Vector2 = p.aim
	var col: Color = Color(0.79, 0.65, 1.0)  # (an echo's lilac, as its first cast's words)
	match spell:
		"gale_lift":
			for o in _cone(main, at, aim, float(a["reach"]), float(a["arc"])):
				if not o.is_boss():
					o.lift(float(a["lift"]))
		"piercing_shot":
			var to: Vector2 = at + aim * float(a["length"])
			for o in main.targets():
				var seg := Geometry2D.get_closest_point_to_segment(o.global_position, at, to)
				if seg.distance_to(o.global_position) <= o.radius + 6.0:
					o.take_hit(float(a["damage"]) * pw, aim, 120.0, false, true)
			main.fx_bolt([at, to], col)
		"barrier":
			p.raise_barrier(maxf(p.barrier_hp, 0.0) + float(a["shield"]) * pw, float(a["seconds"]), false, col)
		"tidal_surge":
			for o in _cone(main, at, aim, float(a["reach"]), float(a["arc"])):
				var dir: Vector2 = (o.global_position - at).normalized()
				o.tide_push(dir * float(a["push"]) * (0.25 if o.is_boss() else 1.0))
				o.chill_t = maxf(o.chill_t, float(a["slow"]))
			main.fx_cone(at, aim, float(a["reach"]), deg_to_rad(float(a["arc"])), col)
		"fireball":
			var spot: Vector2 = at + aim * float(a["at"])
			_spell_fx().later(main, float(a["delay"]), func():
				for o in _near(main, spot, float(a["radius"])):
					o.take_hit(float(a["damage"]) * pw, (o.global_position - spot).normalized(), 160.0)
					if is_instance_valid(o) and not o.dead:
						o.ignite(2.0 * pw, 2.0)
				runner(main).decal("blast", spot, 0.45, float(a["radius"]), _lib().color("fire")))
		"chain_lightning":
			var from = null
			for o in _cone(main, at, aim, 200.0, 50.0):
				from = o
				break
			if from != null:
				var hit_list: Array = [from]
				var pos: Vector2 = from.global_position
				for i in int(a["leaps"]):
					var next := _near(main, pos, float(a["hop"])).filter(func(o): return not o in hit_list)
					if next.is_empty():
						break
					var n = next[0]
					n.take_hit(float(a["damage"]) * pw, Vector2.ZERO, 60.0)
					n.stagger(float(a["stun"]))
					main.fx_bolt([pos, n.global_position], Color(0.8, 0.9, 1.0))
					hit_list.append(n)
					pos = n.global_position
		"undertow":
			var near := _cone(main, at, aim, float(a["reach"]), 40.0)
			if not near.is_empty():
				near[0].take_hit(float(a["damage"]) * pw, Vector2.ZERO, 0.0, false, true)
				load("res://scripts/technique.gd")._heal(p, float(a["heal"]) * pw)
				main.fx_bolt([near[0].global_position, at], col)
		"quake":
			_spell_fx().later(main, float(a["delay"]), func():
				if is_instance_valid(p):
					for o in _near(main, p.global_position, float(a["radius"])):
						o.stagger(float(a["stagger"]))
					runner(main).decal("tremor", p.global_position, 0.55, float(a["radius"]), _lib().color("stone")))
		"kindle_blade":
			p.kindle_t = maxf(p.kindle_t, float(a["seconds"]))
			p.kindle_dmg = maxf(p.kindle_dmg if p.kindle_t > 0.0 else 0.0, float(a["burn"]) * pw)
		"conjured_blades":
			var n := 0
			for o in _near(main, at, float(a["reach"])):
				if n >= int(a["count"]):
					break
				o.take_hit(float(a["damage"]) * pw, (o.global_position - at).normalized(), 80.0, false, true)
				runner(main).decal("shard", at, 0.3, 4.0, _lib().color("blade"), {"to": o.global_position})
				n += 1
		"smoke_veil":
			_mist(p, at, float(a["radius"]), float(a["seconds"]), 1.0, Color(0.6, 0.58, 0.62))
		"challenge":
			p.stone_t = maxf(p.stone_t, float(a["seconds"]))
			for o in _cone(main, at, aim, 340.0, 30.0):
				o.challenged_t = maxf(o.challenged_t, float(a["seconds"]))
				break
		"rekindle":
			load("res://scripts/technique.gd")._mend(p, float(a["mend"]) * pw, float(a["seconds"]))
		"wingburst":
			_spell_fx().later(main, float(a["delay"]), func():
				if is_instance_valid(p):
					var c: Vector2 = p.global_position
					for o in _near(main, c, float(a["radius"])):
						o.take_hit(float(a["damage"]) * pw, (o.global_position - c).normalized(), 160.0)
						if is_instance_valid(o) and not o.dead:
							o.ignite(2.0 * pw, 2.0)
					runner(main).decal("blast", c, 0.45, float(a["radius"]), _lib().color("fire")))
		"venom_spit":
			for o in _cone(main, at, aim, float(a["reach"]), float(a["arc"])):
				o.add_venom(int(a["stacks"]))
		"track":
			main.track_t = maxf(main.track_t, float(a["seconds"]))
		_:
			return false
	main.fx_ring(at, col, 30.0, 0.35, 2.0)
	return true


## The foes in a cone in front of you, nearest first.
static func _cone(main, at: Vector2, aim: Vector2, reach: float, arc_deg: float) -> Array:
	var half := deg_to_rad(arc_deg)
	return _near(main, at, reach).filter(func(o):
		var to: Vector2 = o.global_position - at
		return to.length() < 1.0 or absf(aim.angle_to(to)) <= half)


# --- what stays a while, drawn in code ---------------------------------------------

## The node under the room that keeps what these effects leave for a while
## (made the first time; a new floor clears it).
static func runner(main) -> Runner:
	var n = main.get_node_or_null(Runner.NAME)
	if n == null:
		n = Runner.new()
		n.name = Runner.NAME
		main.add_child(n)
	return n


## Burning floor, mist, rubble, blades, flowers, threads, blasts, frost and
## the small marks on foes, each drawn in code; and the effects' own timers
## (tick(fn): fn(delta) each frame until it returns false).
class Runner extends Node2D:
	const NAME := "UnboundFx"
	var decals: Array = []  # {kind, pos, t, total, r, col, ...}: "a" / "b" nodes it follows, "to", "dir", "n"
	var ticks: Array = []  # Callables (delta) -> keep
	var floor_at := -1
	var plan_ref = null  # (the room's floor plan: a new one each floor, even the same floor again)
	var answer_t := 0.0  # Answer ready: a glint circles you

	func _ready() -> void:
		z_as_relative = false
		z_index = 45  # (over the floor and the darkness, under the techniques' bolts)

	func decal(kind: String, pos: Vector2, seconds: float, r: float, col: Color, more := {}) -> Dictionary:
		var d := {"kind": kind, "pos": pos, "t": seconds, "total": maxf(seconds, 0.05), "r": r, "col": col, "seed": randf() * 100.0}
		d.merge(more, true)
		decals.append(d)
		queue_redraw()
		return d

	func tick(fn: Callable) -> void:
		ticks.append(fn)

	func _process(delta: float) -> void:
		var main = get_parent()
		if main != null and "floor_num" in main:
			var plan = main.get("floor_plan")
			if (floor_at >= 0 and floor_at != int(main.floor_num)) or (plan_ref != null and not is_same(plan, plan_ref)):
				decals.clear()
				ticks.clear()
				answer_t = 0.0
			floor_at = int(main.floor_num)
			plan_ref = plan
		if decals.is_empty() and ticks.is_empty() and answer_t <= 0.0:
			return
		answer_t = maxf(0.0, answer_t - delta)
		for fn in ticks.duplicate():
			if not (fn as Callable).is_valid() or not bool(fn.call(delta)):
				ticks.erase(fn)
		for d in decals.duplicate():
			d["t"] -= delta
			for key in ["a", "b"]:
				if d.has(key) and is_instance_valid(d[key]):
					if key == "a" or not d.has("a"):
						d["pos"] = d[key].global_position
			if d["t"] <= 0.0 or (d.has("a") and not is_instance_valid(d["a"])):
				decals.erase(d)
		queue_redraw()

	func _draw() -> void:
		var now := Time.get_ticks_msec() * 0.001
		for d in decals:
			var k := clampf(float(d["t"]) / float(d["total"]), 0.0, 1.0)  # 1 new .. 0 gone
			var fade := clampf(float(d["t"]) / 0.35, 0.0, 1.0) * clampf((float(d["total"]) - float(d["t"])) / 0.12 + 0.2, 0.0, 1.0)
			var c: Color = d["col"]
			var pos: Vector2 = d["pos"]
			var r: float = d["r"]
			var s: float = d["seed"]
			match String(d["kind"]):
				"flames":
					# Burning floor: a scorched disc and tongues of flame that flicker.
					draw_circle(pos, r, Color(0.12, 0.04, 0.02, 0.35 * fade))
					draw_circle(pos, r * 0.8, Color(c, 0.14 * fade))
					for i in 9:
						var ang := s + float(i) * TAU / 9.0
						var rr := r * (0.25 + 0.6 * fmod(s * 3.1 + i * 0.37, 1.0))
						var b: Vector2 = pos + Vector2.from_angle(ang) * rr
						var h := 8.0 + 5.0 * sin(now * 9.0 + i * 1.7)
						_flame(b, 4.5, h, c, fade)
				"blast":
					var e := 1.0 - k
					draw_circle(pos, r * (0.4 + 0.6 * e), Color(c.lightened(0.3), 0.35 * k))
					draw_arc(pos, r * (0.5 + 0.5 * e), 0.0, TAU, 40, Color(c, 0.9 * k), 4.0, true)
					for i in 10:
						var ang := s + float(i) * TAU / 10.0
						_flame(pos + Vector2.from_angle(ang) * r * (0.45 + 0.5 * e), 5.0, 10.0 * k + 3.0, c, k)
				"mist":
					for i in 8:
						var ang := s + float(i) * TAU / 8.0 + now * 0.25
						var off := Vector2.from_angle(ang) * r * (0.35 + 0.35 * sin(now * 0.8 + i))
						draw_circle(pos + off, r * 0.45, Color(c, 0.10 * fade))
					draw_circle(pos, r * 0.6, Color(c, 0.12 * fade))
				"rubble":
					draw_circle(pos, r, Color(0.0, 0.0, 0.0, 0.18 * fade))
					for i in 11:
						var ang := s * 2.0 + float(i) * 2.4
						var rr := r * (0.2 + 0.75 * fmod(s + i * 0.29, 1.0))
						var b: Vector2 = pos + Vector2.from_angle(ang) * rr
						var sz := 3.0 + 3.0 * fmod(s * 1.7 + i * 0.41, 1.0)
						var pts := PackedVector2Array()
						for j in 5:
							pts.append(b + Vector2.from_angle(ang + j * TAU / 5.0) * sz * (0.7 + 0.3 * fmod(i * 0.7 + j * 0.3, 1.0)))
						draw_colored_polygon(pts, Color(c.darkened(0.25 + 0.2 * fmod(i * 0.3, 1.0)), fade))
						draw_line(pts[0], pts[1], Color(c.lightened(0.35), 0.8 * fade), 1.0)
				"blades":
					for i in 7:
						var ang := s + float(i) * TAU / 7.0
						var b: Vector2 = pos + Vector2.from_angle(ang) * r * (0.2 + 0.7 * fmod(s * 2.3 + i * 0.31, 1.0))
						var dir := Vector2.from_angle(ang * 1.7 + s)
						var glint := 0.5 + 0.5 * sin(now * 5.0 + i * 1.3)
						draw_line(b - dir * 6.0, b + dir * 6.0, Color(c.lightened(0.3 + 0.3 * glint), fade), 2.2)
						draw_line(b - dir * 6.0, b - dir * 3.0, Color(0.3, 0.2, 0.12, fade), 3.0)
				"flower":
					var sway := sin(now * 2.0 + s) * 0.15
					var bloom := clampf((float(d["total"]) - float(d["t"])) / 0.4, 0.2, 1.0)
					draw_line(pos + Vector2(0, 6), pos, Color(0.35, 0.65, 0.3, fade), 2.0)
					for i in 6:
						var ang := sway + float(i) * TAU / 6.0
						draw_circle(pos + Vector2.from_angle(ang) * 6.0 * bloom, 4.2 * bloom, Color(c.lightened(0.15), 0.9 * fade))
					draw_circle(pos, 3.2 * bloom, Color(1.0, 0.92, 0.55, fade))
					draw_arc(pos, 15.0 + 2.0 * sin(now * 3.0 + s), 0.0, TAU, 24, Color(c, 0.25 * fade), 1.5, true)
				"thread":
					var a = d.get("a")
					var b = d.get("b")
					if is_instance_valid(a) and is_instance_valid(b):
						var p1: Vector2 = a.global_position
						var p2: Vector2 = b.global_position
						var pts := PackedVector2Array()
						for i in 13:
							var f := float(i) / 12.0
							var q: Vector2 = p1.lerp(p2, f) + (p2 - p1).orthogonal().normalized() * sin(f * PI) * 10.0 * sin(now * 4.0 + f * 6.0)
							pts.append(q)
						draw_polyline(pts, Color(c, 0.85 * fade), 2.0, true)
						var bead := fmod(now * 0.9 + s, 1.0)
						draw_circle(p2.lerp(p1, bead), 3.0, Color(c.lightened(0.4), fade))
				"frost":
					for i in 6:
						var ang := float(i) * TAU / 6.0 + s
						var tip: Vector2 = pos + Vector2.from_angle(ang) * r
						draw_line(pos, tip, Color(c.lightened(0.5), 0.85 * fade), 2.0)
						draw_line(tip, tip + Vector2.from_angle(ang + 0.6) * 4.0, Color(c.lightened(0.5), 0.85 * fade), 1.5)
					draw_circle(pos, r * 0.75, Color(c.lightened(0.3), 0.25 * fade))
				"frost_ring":
					draw_arc(pos, r, 0.0, TAU, 40, Color(c.lightened(0.4), 0.45 * fade), 2.0, true)
					for i in 12:
						var ang := float(i) * TAU / 12.0 + now * 0.3
						draw_circle(pos + Vector2.from_angle(ang) * r, 2.0, Color(1, 1, 1, 0.6 * fade))
				"current":
					var dir: Vector2 = d.get("dir", Vector2.RIGHT)
					for i in 3:
						var o: Vector2 = pos + dir.orthogonal() * (float(i) - 1.0) * 9.0
						var pts := PackedVector2Array()
						for j in 7:
							var f := float(j) / 6.0
							pts.append(o + dir * (f * 34.0 * (1.0 - k * 0.4) - 10.0) + dir.orthogonal() * sin(f * TAU + now * 8.0) * 3.0)
						draw_polyline(pts, Color(c.lightened(0.3), 0.8 * k), 2.0, true)
				"gust":
					var dir: Vector2 = d.get("dir", Vector2.RIGHT)
					for i in 4:
						var o: Vector2 = pos + dir.orthogonal() * (float(i) - 1.5) * 8.0 - dir * (1.0 - k) * -20.0
						draw_line(o, o + dir * (14.0 + (8.0 if i % 2 == 0 else 0.0)), Color(c.lightened(0.4), 0.7 * k), 1.6)
				"gust_ring":
					draw_arc(pos, r * (1.0 - 0.5 * k), 0.0, TAU, 40, Color(c.lightened(0.4), 0.7 * k), 3.0, true)
				"spark":
					for i in 6:
						var ang := float(i) * TAU / 6.0 + now * 7.0
						draw_line(pos + Vector2.from_angle(ang) * 8.0, pos + Vector2.from_angle(ang + 0.3) * r, Color(c.lightened(0.5), k), 1.5)
				"lift":
					for i in 3:
						var y := -fmod(now * 40.0 + i * 8.0, 24.0)
						draw_arc(pos + Vector2(0, r * 0.6 + y), r * 0.7, 0.2, PI - 0.2, 12, Color(c.lightened(0.4), 0.6 * k), 1.5, true)
				"tremor":
					var e := 1.0 - k
					draw_arc(pos, r * (0.3 + 0.7 * e), 0.0, TAU, 44, Color(c.lightened(0.2), 0.9 * k), 4.0, true)
					for i in 7:
						var ang := s + float(i) * TAU / 7.0
						var a1: Vector2 = pos + Vector2.from_angle(ang) * r * 0.25
						var a2: Vector2 = pos + Vector2.from_angle(ang + 0.15) * r * (0.5 + 0.5 * e)
						draw_line(a1, a2, Color(0.05, 0.03, 0.02, 0.8 * k), 2.0)
				"shard":
					var to: Vector2 = d.get("to", pos)
					var f := 1.0 - k
					var head: Vector2 = pos.lerp(to, f)
					var dir := (to - pos).normalized() if to.distance_to(pos) > 0.5 else Vector2.RIGHT
					draw_colored_polygon(PackedVector2Array([head + dir * 6.0, head + dir.orthogonal() * 2.5, head - dir * 4.0, head - dir.orthogonal() * 2.5]), Color(c.lightened(0.45), k + 0.2))
				"lode":
					var to: Vector2 = d.get("to", pos)
					for i in 3:
						var f := fmod(now * 2.5 + i / 3.0, 1.0)
						draw_circle(to.lerp(pos, f), 2.2, Color(c.lightened(0.3), 0.8 * k))
					draw_line(to, pos, Color(c, 0.35 * k), 1.2)
				"rend":
					for i in int(d.get("n", 1)):
						var x := (float(i) - (float(d.get("n", 1)) - 1.0) * 0.5) * 5.0
						draw_line(pos + Vector2(x - 3.0, -r - 10.0), pos + Vector2(x + 3.0, -r - 2.0), Color(c.lightened(0.2), k), 2.0)
				"ember":
					for i in 3:
						var y := -fmod(now * 30.0 + i * 7.0, 20.0)
						draw_circle(pos + Vector2(sin(now * 3.0 + i * 2.0) * 6.0, y - 4.0), 1.8, Color(c.lightened(0.3), 0.8 * fade))
				"unravel":
					for i in 5:
						var ang := s + float(i) * TAU / 5.0 + now * 1.5
						var a1: Vector2 = pos + Vector2.from_angle(ang) * r
						var a2: Vector2 = pos + Vector2.from_angle(ang + 0.4) * (r + 7.0 + 3.0 * sin(now * 4.0 + i))
						draw_line(a1, a2, Color(c.lightened(0.3), 0.75 * fade), 1.5)
				"hollow":
					draw_arc(pos, r + 2.0 * sin(now * 3.0 + s), 0.0, TAU, 28, Color(c.darkened(0.2), 0.7 * fade), 2.5, true)
					draw_arc(pos, r - 4.0, 0.0, TAU, 28, Color(0, 0, 0, 0.35 * fade), 2.0, true)
				"grit", "temper", "wind":
					draw_arc(pos, r * (1.2 - 0.3 * k), 0.0, TAU, 28, Color(c.lightened(0.35), 0.8 * k), 2.5, true)
					if String(d["kind"]) == "temper":
						var g: Vector2 = pos + Vector2.from_angle(now * 6.0) * r
						draw_circle(g, 2.5, Color(1, 1, 1, 0.9 * k))
		if answer_t > 0.0:
			var main = get_parent()
			if main != null and "player" in main and main.player != null and is_instance_valid(main.player):
				var pp: Vector2 = main.player.global_position
				var col: Color = load("res://scripts/library.gd").color("blade")
				for i in 2:
					var ang := now * 4.0 + i * PI
					var b: Vector2 = pp + Vector2.from_angle(ang) * 24.0
					var dir := Vector2.from_angle(ang + PI * 0.5)
					draw_line(b - dir * 5.0, b + dir * 5.0, Color(col.lightened(0.4), 0.85), 2.0)

	func _flame(b: Vector2, w: float, h: float, c: Color, a: float) -> void:
		draw_colored_polygon(PackedVector2Array([b + Vector2(-w, 0), b + Vector2(0, -h), b + Vector2(w, 0), b + Vector2(0, w * 0.5)]), Color(c, 0.75 * a))
		draw_colored_polygon(PackedVector2Array([b + Vector2(-w * 0.45, 0), b + Vector2(0, -h * 0.55), b + Vector2(w * 0.45, 0)]), Color(1.0, 0.92, 0.6, 0.85 * a))
