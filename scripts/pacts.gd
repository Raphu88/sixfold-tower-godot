extends RefCounted
## NAMED PACTS: two marks that answer each other. A pact holds while the
## climber carries both of its bonds ("bonds"), wherever they sit; the first
## time it forms it is announced and remembered (profile.gd pacts_formed),
## and the climber's book (Marks) and the Library list it. Every name, line
## and number is here (the Data editor's "States and reactions" sections).
##
## What each does is written where it happens (search for its id):
##   tempest          main.gd _update_waves, bond.gd _surge
##   dust_devil       bond.gd _quake, _lift
##   whirling_steel   projectile.gd (a conjured blade striking)
##   forge_runes      player.gd _melee (a kindled strike)
##   wildfire         main.gd _update_flames, player.gd (the aura)
##   undying          player.gd _defy_death (Last Ember)
##   bloodletter      bond.gd _drain, player.gd (Drink)
##   ambusher         player.gd ranged_hit
##   toxic_precision  bond.gd _sever
##   menagerie        enemy.gd _ally_ai (Pacts.ally_strike)
##
## For content files (later mark work):
##   Pacts.has(p, id) -> bool     the climber holds this pact now
##   Pacts.held(p) -> Array       every pact held, in PACTS order
##   Pacts.num(id, key) -> float  a pact's number
##   Pacts.announce(main)         announces pacts formed for the first time
##                                (main.gd _give_bonds calls it)

const Bonds := preload("res://scripts/bonds.gd")
const Reactions := preload("res://scripts/reactions.gd")

static var PACTS := {
	"tempest": {"name": "Tempest", "bonds": ["stormcaller", "tidecaller"], "says": "Your waves leave foes charged as well as soaked",
		"color": Color(0.62, 0.8, 0.98), "charged": 4.0},
	"dust_devil": {"name": "Dust Devil", "bonds": ["windwalker", "sandshaper"], "says": "Quake throws foes up; Gale Lift leaves shards that cut",
		"color": Color(0.85, 0.78, 0.6), "lift": 1.0, "radius": 34.0, "seconds": 4.0, "damage": 3.0, "bleed": 1.5},
	"whirling_steel": {"name": "Whirling Steel", "bonds": ["blade_forger", "windwalker"], "says": "Your conjured blades lift light foes",
		"color": Color(0.78, 0.86, 0.95), "lift": 0.9, "weight": 1.6},
	"forge_runes": {"name": "Forge Runes", "bonds": ["flameblade", "rune_artist"], "says": "Kindled strikes leave small fire runes",
		"color": Color(1.0, 0.62, 0.3), "blast": 42.0, "damage": 6.0, "burn": 2.0, "burn_t": 3.0, "every": 0.6, "most": 4, "life": 12.0},
	"wildfire": {"name": "Wildfire", "bonds": ["flame_contractor", "flamewing"], "says": "Burning ground feeds the aura's heat",
		"color": Color(1.0, 0.48, 0.2), "heat": 3.0},
	"undying": {"name": "Undying", "bonds": ["warden", "rekindler"], "says": "Last Ember also raises a barrier",
		"color": Color(0.95, 0.72, 0.42), "shield": 30.0, "seconds": 4.0},
	"bloodletter": {"name": "Bloodletter", "bonds": ["deepcaller", "surgeon"], "says": "Draining a bleeding foe heals double",
		"color": Color(0.78, 0.25, 0.4), "heal": 2.0},
	"ambusher": {"name": "Ambusher", "bonds": ["hunter", "ashwalker"], "says": "Unseen shots always strike a weak point",
		"color": Color(0.8, 0.62, 0.48), "mult": 2.0},
	"toxic_precision": {"name": "Toxic Precision", "bonds": ["venomist", "surgeon"], "says": "Sever adds 3 poison stacks",
		"color": Color(0.6, 0.86, 0.5), "stacks": 3},
	"menagerie": {"name": "Menagerie", "bonds": ["covenant", "grafter"], "says": "Your creatures carry your newest graft's power",
		"color": Color(0.7, 0.85, 0.6), "hand": 1.4, "legs": 1.35, "heart": 2.0, "brow": 0.5, "throat": 45.0, "back": 2},
}

## Menagerie: what each graft's power gives your creatures, in words (the book).
static var GRAFT_POWER := {
	"hand": "they hit harder", "legs": "they move faster", "heart": "they mend over time",
	"brow": "their blows stagger", "throat": "their blows splash to foes beside", "back": "their blows poison",
}

static var TEXT := {
	"section": "Pacts",
	"none": "No pacts yet. Two marks that answer each other form one.",
	"formed": "Pact: %s",
	"held": "Pacts held: %s",
	"of": "%s and %s",
	"shelf": "Pacts",
	"locked": "???",
	"shelf_note": "A pact forms when you carry both of its marks. Those you have formed are written here.",
}


static func has(p, id: String) -> bool:
	if p == null or not is_instance_valid(p) or not PACTS.has(id) or not p.has_method("has_bond"):
		return false
	for b in PACTS[id]["bonds"]:
		if not p.has_bond(String(b)):
			return false
	return true


static func held(p) -> Array:
	return PACTS.keys().filter(func(id): return has(p, id))


static func num(id: String, key: String) -> float:
	return float(PACTS.get(id, {}).get(key, 0.0))


## "Stormcaller and Tidecaller".
static func pair_text(id: String) -> String:
	var names: Array = []
	for b in PACTS[id]["bonds"]:
		names.append(String(Bonds.BONDS.get(String(b), {}).get("name", String(b))))
	return TEXT["of"] % [names[0], names[1]]


## The pacts this profile has formed (kept between climbs; an old save has none).
static func formed(prof) -> Array:
	if prof == null or not ("pacts_formed" in prof):
		return []
	return prof.pacts_formed


## Pacts held now that never formed before: each is announced once (the
## word over the climber, the Entity's tip) and remembered.
static func announce(main) -> Array:
	if main == null or main.player == null or main.profile == null:
		return []
	var fresh: Array = []
	for id in held(main.player):
		if not id in main.profile.pacts_formed:
			main.profile.pacts_formed.append(id)
			fresh.append(id)
	if fresh.is_empty():
		return fresh
	main.profile.save()
	var at: Vector2 = main.player.global_position
	for i in fresh.size():
		var id: String = fresh[i]
		if main.has_method("note_event"):  # (the left feed and the Entity's log)
			main.note_event("pact", TEXT["formed"] % PACTS[id]["name"], PACTS[id]["color"])
			main.remark("pact")
		else:
			Reactions.word(main, at + Vector2(0, -70.0 - 26.0 * i), TEXT["formed"] % PACTS[id]["name"], PACTS[id]["color"])
		main.fx_ring(at, PACTS[id]["color"], 60.0, 0.5, 3.0)
	main.sfx("heirloom", 1.0, -6.0)
	main.tip("pacts")
	return fresh


# --- Menagerie: a creature's blow carries your newest graft's power -----------------

## The part of the newest graft, or "" (no Menagerie, or no graft).
static func menagerie_part(main) -> String:
	if main == null or main.player == null or not has(main.player, "menagerie") or main.graft_order.is_empty():
		return ""
	return String(main.graft_order[-1])


## A creature strikes a foe (enemy.gd _ally_ai): returns its damage with the
## graft's power, and adds what the power does on top.
static func ally_strike(main, ally, target, dmg: float) -> float:
	var part := menagerie_part(main)
	if part == "":
		return dmg
	var p: Dictionary = PACTS["menagerie"]
	match part:
		"hand":
			return dmg * float(p["hand"])
		"brow":
			target.stagger(float(p["brow"]) * (0.5 if target.is_boss() else 1.0))
		"back":
			target.add_venom(int(p["back"]))
		"throat":
			for o in main.targets():
				if o != target and not o.dead and o.global_position.distance_to(target.global_position) < float(p["throat"]) + o.radius:
					o.take_hit(dmg * 0.5, (o.global_position - target.global_position).normalized(), 80.0)
	return dmg


## A creature's speed and mending (enemy.gd _ally_ai, every frame).
static func ally_tick(main, ally, delta: float) -> float:
	var part := menagerie_part(main)
	if part == "heart":
		ally.hp = minf(ally.max_hp, ally.hp + float(PACTS["menagerie"]["heart"]) * delta)
	return float(PACTS["menagerie"]["legs"]) if part == "legs" else 1.0
