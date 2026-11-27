extends RefCounted
## SYNERGIES: marks carried together answer each other. Two kinds:
##
## LENT TRAITS (every pair): each mark lends one trait to whatever mark it's
## paired with (TRAITS, by the lending mark). Carry any two marks and each
## one's spells pick up a touch of the other's trait, about a quarter as
## strong as the real thing: Stormcaller lends Charge (hits leave foes
## charged), Tidecaller Soak, Warden Guard (casting raises a thin barrier)...
## That covers all 153 pairs of the 18 marks with 18 entries. A teammate's
## marks lend theirs too, while they fight beside you (rivals.gd).
##
## NAMED SYNERGIES (SYNERGIES, 12): stronger, hand-made answers for a pair,
## which take the place of that pair's lent traits. One holds while the
## climber carries both of its bonds ("bonds"), wherever they sit; the first
## time it forms it is announced and remembered (profile.gd
## synergies_formed), and the climber's book (Marks) and the Library list
## it. Every name, line and number is here (the Data editor's "States,
## reactions and synergies" sections).
##
## What each named synergy does is written where it happens (search its id):
##   tempest          main.gd _update_waves, bond.gd _surge
##   dust_devil       bond.gd _quake, _lift
##   whirling_steel   projectile.gd (a conjured blade striking)
##   forge_runes      player.gd _melee (a kindled strike)
##   wildfire         main.gd _update_flames, player.gd (the aura)
##   undying          player.gd _defy_death (Last Ember)
##   bloodletter      bond.gd _drain, player.gd (Drink)
##   ambusher         player.gd ranged_hit
##   toxic_precision  bond.gd _sever
##   menagerie        enemy.gd _ally_ai (Synergies.ally_strike)
##   scald            main.gd _update_flames (Synergies.scald)
##   lightning_steel  projectile.gd (Synergies.conduct)
## The lent traits all live here (cast, _once, _hit), run around every cast
## of a mark's spell (player.gd _release_cast calls Synergies.cast).
##
## For content files (later mark work):
##   Synergies.has(p, id) -> bool     the climber holds this named synergy now
##   Synergies.held(p) -> Array       every named synergy held, in SYNERGIES order
##   Synergies.num(id, key) -> float  a named synergy's number
##   Synergies.lent(p, bond_id)       the marks lending a trait to that mark's spells
##   Synergies.announce(main)         announces synergies formed for the first time
##                                    (main.gd _give_bonds calls it)

const Bonds := preload("res://scripts/bonds.gd")
const Reactions := preload("res://scripts/reactions.gd")

static var SYNERGIES := {
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
	# Burning ground of yours (Fire Wall, Kindled, a crater...) under a soaked
	# foe bursts into steam: every foe within `radius` loses track of you for
	# `blind` seconds and is scalded for `damage`; the foe dries off. Again on
	# the same foe only after `again` seconds.
	"scald": {"name": "Scald", "bonds": ["tidecaller", "flame_contractor"], "says": "Burning ground under soaked foes bursts into steam that blinds them",
		"color": Color(0.88, 0.9, 0.86), "radius": 70.0, "blind": 3.0, "damage": 4.0, "again": 2.0},
	# A conjured blade that strikes leaves its foe charged (`charged` seconds)
	# and lightning leaps from it to the nearest other blade of yours in
	# flight (within `hop`), striking every foe within `width` of the bolt
	# for `damage`; with no other blade near, it leaps to the nearest foe.
	"lightning_steel": {"name": "Lightning Steel", "bonds": ["stormcaller", "blade_forger"], "says": "Your conjured blades conduct: lightning leaps between them",
		"color": Color(0.86, 0.9, 1.0), "hop": 180.0, "width": 26.0, "damage": 3.0, "charged": 2.0},
}

## What each mark lends whatever mark it's paired with (about a quarter as
## strong as the real thing; every number can be tuned in the Data editor).
## A hit is a foe the spell strikes as it's cast, or that one of its shots
## strikes; a kill is such a hit that slays. Casting traits come once a cast.
static var TRAITS := {
	"stormcaller": {"name": "Charge", "says": "hits leave foes charged", "seconds": 1.0},
	"windwalker": {"name": "Lift", "says": "hits shove light foes up and back", "lift": 0.4, "push": 110.0, "weight": 1.5},
	"hunter": {"name": "Precision", "says": "hits on a weak point strike harder", "more": 0.25},
	"tidecaller": {"name": "Soak", "says": "hits leave foes soaked", "seconds": 1.0},
	"warden": {"name": "Guard", "says": "casting raises a thin barrier", "shield": 8.0, "seconds": 3.0},
	"deepcaller": {"name": "Drain", "says": "a little of the damage heals you", "share": 0.08},
	"blade_forger": {"name": "Shards", "says": "hits throw a small conjured blade", "damage": 2.0, "reach": 200.0, "speed": 520.0},
	"flameblade": {"name": "Heat", "says": "your weapon heats up a little with each cast", "heat": 10.0},
	"rune_artist": {"name": "Rune", "says": "spells sometimes leave a small rune trap", "chance": 0.25, "damage": 5.0, "blast": 40.0, "life": 12.0},
	"sandshaper": {"name": "Rubble", "says": "hits slow foes briefly", "seconds": 0.75},
	"venomist": {"name": "Venom", "says": "hits add a stack of poison", "stacks": 1},
	"ashwalker": {"name": "Smoke", "says": "a kill may hide you for a moment", "chance": 0.25, "seconds": 1.5, "radius": 220.0},
	"flame_contractor": {"name": "Kindling", "says": "kills leave a patch of burning ground", "radius": 24.0, "seconds": 3.0},
	"flamewing": {"name": "Embers", "says": "hits set foes burning a little", "seconds": 1.0, "dps": 1.0},
	"rekindler": {"name": "Ember heart", "says": "kills heal you a little", "heal": 2.0},
	"covenant": {"name": "Kin", "says": "your creatures hit harder (or a spirit helps you briefly with none out)", "more": 0.25, "seconds": 4.0, "spirit": 3.0, "reach": 220.0},
	"grafter": {"name": "Graft", "says": "a foe slain by a spell is likelier to leave a graft", "chance": 0.25},
	"surgeon": {"name": "Bleed", "says": "hits open a small bleed", "dps": 1.0, "seconds": 3.0},
}

## Menagerie: what each graft's power gives your creatures, in words (the book).
static var GRAFT_POWER := {
	"hand": "they hit harder", "legs": "they move faster", "heart": "they mend over time",
	"brow": "their blows stagger", "throat": "their blows splash to foes beside", "back": "their blows poison",
}

static var TEXT := {
	"section": "Synergies",
	"none": "No synergies yet. Carry two marks and each lends the other a trait.",
	"formed": "Synergy: %s",
	"held": "Synergies: %s",
	"of": "%s and %s",
	"shelf": "Synergies",
	"locked": "???",
	"shelf_note": "A named synergy forms when you carry both of its marks. Those you have formed are written here.",
	"lent": "%s's spells take %s from %s: %s",
	"lent_short": "Lent: %s",
	"lent_formed": "Synergy: your marks lend each other traits",
	"steam": "Scald",
	"spirit": "Kin",
}


## True while the climber holds the named synergy: both its marks, or one
## of them while a rival climber beside you carries the other (rivals.gd: a
## shared synergy, for as long as they fight with you).
static func has(p, id: String) -> bool:
	if own(p, id):
		return true
	return shared(p, id)


## Both marks the climber's own.
static func own(p, id: String) -> bool:
	if p == null or not is_instance_valid(p) or not SYNERGIES.has(id) or not p.has_method("has_bond"):
		return false
	for b in SYNERGIES[id]["bonds"]:
		if not p.has_bond(String(b)):
			return false
	return true


## The bonds of the rival fighting beside you ([] for none: rivals.gd ally_bonds).
static func _ally_bonds(p) -> Array:
	var m = p.get("main")
	if m == null or not is_instance_valid(m):
		return []
	var rv = m.get("rivals")
	if rv == null or not rv.has_method("ally_bonds"):
		return []
	return rv.ally_bonds()


## One mark yours, the other the rival's beside you (rivals.gd ally_bonds).
static func shared(p, id: String) -> bool:
	if p == null or not is_instance_valid(p) or not SYNERGIES.has(id) or not p.has_method("has_bond"):
		return false
	var theirs: Array = _ally_bonds(p)
	if theirs.is_empty():
		return false
	var mine := 0
	for b in SYNERGIES[id]["bonds"]:
		if p.has_bond(String(b)):
			mine += 1
		elif not String(b) in theirs:
			return false
	return mine >= 1


static func held(p) -> Array:
	return SYNERGIES.keys().filter(func(id): return has(p, id))


static func num(id: String, key: String) -> float:
	return float(SYNERGIES.get(id, {}).get(key, 0.0))


## "Stormcaller and Tidecaller".
static func pair_text(id: String) -> String:
	var names: Array = []
	for b in SYNERGIES[id]["bonds"]:
		names.append(bond_name(String(b)))
	return TEXT["of"] % [names[0], names[1]]


static func bond_name(bond_id: String) -> String:
	return String(Bonds.BONDS.get(bond_id, {}).get("name", bond_id))


## The named synergy two marks make together, or "".
static func named_for(a: String, b: String) -> String:
	if a == b:
		return ""
	for id in SYNERGIES:
		var pair: Array = SYNERGIES[id]["bonds"]
		if a in pair and b in pair:
			return id
	return ""


## The named synergies this profile has formed (kept between climbs; an old save has none).
static func formed(prof) -> Array:
	if prof == null or not ("synergies_formed" in prof):
		return []
	return prof.synergies_formed.filter(func(id): return SYNERGIES.has(id))


# --- lent traits ----------------------------------------------------------------------

## The marks lending their trait to `bond_id`'s spells: every other mark the
## climber carries, and the rival's beside you, except a mark that makes a
## named synergy with it (that takes the lent traits' place).
static func lent(p, bond_id: String, with_ally := true) -> Array:
	if p == null or not is_instance_valid(p) or not Bonds.BONDS.has(bond_id) or not ("bonds" in p):
		return []
	var out: Array = []
	var ids: Array = []
	for b in p.bonds.values():
		ids.append(String(b.id))
	if with_ally:
		ids.append_array(_ally_bonds(p))
	for id in ids:
		if id != bond_id and TRAITS.has(id) and not id in out and named_for(bond_id, id) == "":
			out.append(id)
	return out


## Every lending between the climber's own marks, as [mark, lender] pairs
## (the book's Marks section lists them).
static func lent_pairs(p) -> Array:
	var out: Array = []
	if p == null or not is_instance_valid(p) or not ("bonds" in p):
		return out
	for b in p.bonds.values():
		for from in lent(p, String(b.id), false):
			out.append([String(b.id), from])
	return out


## "Stormcaller's spells take Soak from Tidecaller: hits leave foes soaked".
static func lent_text(to: String, from: String) -> String:
	var t: Dictionary = TRAITS.get(from, {})
	return TEXT["lent"] % [bond_name(to), String(t.get("name", from)), bond_name(from), String(t.get("says", ""))]


static func _num(id: String, key: String, fallback := 0.0) -> float:
	return float(TRAITS.get(id, {}).get(key, fallback))


static func _color(id: String) -> Color:
	return Color(Bonds.BONDS.get(id, {}).get("color", Color.WHITE))


static func _live(e) -> bool:
	return e != null and is_instance_valid(e) and not e.dead and not bool(e.get("ally"))


## A mark's spell is cast (player.gd _release_cast): it runs, then every
## trait its partners lend goes to the foes it struck as it was cast, and
## to whatever its shots strike later; the casting traits come once.
static func cast(main, p, b) -> void:
	var from: Array = lent(p, String(b.id)) if main != null else []
	if from.is_empty() or not main.has_signal("on_hit"):
		b.cast(p)
		return
	var rec := {"struck": [], "amount": {}, "shards": false}
	var n0: int = main.get_child_count()
	var listen := func(foe, dmg: float, source: String) -> void:
		if source != "blow" or foe == null or not is_instance_valid(foe):
			return
		var k: int = foe.get_instance_id()
		if not rec["amount"].has(k):
			rec["struck"].append(foe)
		rec["amount"][k] = float(rec["amount"].get(k, 0.0)) + dmg
	main.on_hit.connect(listen)
	b.cast(p)
	if main.on_hit.is_connected(listen):
		main.on_hit.disconnect(listen)
	_once(main, p, b, from, rec)
	for e in rec["struck"]:
		if is_instance_valid(e):
			_hit(main, p, b, from, e, float(rec["amount"].get(e.get_instance_id(), 0.0)), rec)
	var kids: Array = main.get_children()
	for i in range(n0, kids.size()):
		var k = kids[i]
		if "on_strike" in k and "friendly" in k and k.friendly:
			k.on_strike.append(func(shot, e): _hit(main, p, b, from, e, float(shot.dmg), rec))


## The casting traits: Guard, Heat, Rune and Kin.
static func _once(main, p, _b, from: Array, rec: Dictionary) -> void:
	var first = null
	for e in rec["struck"]:
		if _live(e):
			first = e
			break
	for id in from:
		match id:
			"warden":  # Guard: a thin barrier
				if float(p.get("barrier_hp")) < _num(id, "shield"):
					p.raise_barrier(_num(id, "shield"), _num(id, "seconds"), false, _color(id))
					main.fx_ring(p.global_position, _color(id), p.radius + 12.0, 0.25, 2.0)
			"flameblade":  # Heat: the weapon warms a little
				p.heat = minf(p.heat_cap(), p.heat + _num(id, "heat"))
				p.heat_idle = 0.0
			"rune_artist":  # Rune: sometimes a small rune trap
				if randf() < _num(id, "chance"):
					var at: Vector2 = first.global_position if first != null else p.global_position + p.aim * 50.0
					main.runes.append({"pos": at, "r": 16.0, "blast": _num(id, "blast"), "damage": _num(id, "damage"), "linked": false,
						"color": _color(id), "t": _num(id, "life"), "arm": 0.8, "lent": true})
					main.fx_ring(at, _color(id), 18.0, 0.3, 2.0)
			"covenant":  # Kin: your creatures hit harder; with none out, a spirit strikes
				var kin: Array = main.allies() if main.has_method("allies") else []
				if not kin.is_empty():
					for a in kin:
						if is_instance_valid(a):
							a.set_meta("kin_t", _num(id, "seconds"))
							main.fx_ring(a.global_position, _color(id), 22.0, 0.25, 2.0)
				else:
					var t = first
					if t == null:
						var best := _num(id, "reach")
						for e in main.targets():
							var d: float = e.global_position.distance_to(p.global_position)
							if _live(e) and d < best:
								best = d
								t = e
					if t != null:
						main.fx_bolt([p.global_position + Vector2(0, -20), t.global_position], _color(id).lightened(0.3))
						main.fx_text(t.global_position + Vector2(0, -t.radius - 30.0), TEXT["spirit"], _color(id))
						t.take_hit(_num(id, "spirit"), Vector2.ZERO, 0.0)


## A foe struck by the spell (as it was cast, or by one of its shots).
static func _hit(main, p, b, from: Array, e, amount: float, rec: Dictionary) -> void:
	if p == null or not is_instance_valid(p) or p.dead or e == null or not is_instance_valid(e) or bool(e.get("ally")):
		return
	var killed: bool = e.dead
	var at: Vector2 = e.global_position
	for id in from:
		if not killed and not _live(e):
			return  # (a reaction set off above finished it)
		match id:
			"stormcaller":
				if not killed:
					Reactions.apply(main, e, "charged", _num(id, "seconds"), b)
			"windwalker":
				if not killed and e.has_method("lift") and not e.is_boss() and float(e.get("weight") if e.get("weight") != null else 1.0) <= _num(id, "weight"):
					e.lift(_num(id, "lift"))
					var dir: Vector2 = (at - p.global_position).normalized()
					e.knock = dir * _num(id, "push")
			"hunter":
				if not killed and _weak(p, e):
					e.take_hit(maxf(1.0, amount * _num(id, "more")), Vector2.ZERO, 0.0)
			"tidecaller":
				if not killed:
					Reactions.apply(main, e, "soaked", _num(id, "seconds"), b)
			"deepcaller":
				var got: float = p.mend_by(amount * _num(id, "share") * (p.heal_mult() if p.has_method("heal_mult") else 1.0))
				if got >= 1.0:
					main.fx_text(p.global_position + Vector2(0, -26), "+%d" % int(round(got)), _color(id))
			"blade_forger":
				if not rec["shards"]:
					rec["shards"] = true
					_shard(main, p, e, at, id)
			"sandshaper":
				if not killed:
					Reactions.apply(main, e, "slowed", _num(id, "seconds"), b)
			"venomist":
				if not killed and e.has_method("add_venom"):
					e.add_venom(int(_num(id, "stacks", 1.0)))
			"ashwalker":
				if killed and randf() < _num(id, "chance"):
					for o in main.targets():
						if _live(o) and o.global_position.distance_to(p.global_position) < _num(id, "radius") and o.has_method("lose_track"):
							o.lose_track(_num(id, "seconds"), null)
					main.fx_burst(p.global_position, Vector2.UP, _color(id), 10, 120.0)
			"flame_contractor":
				if killed:
					main.add_flame(at, _num(id, "radius"), _num(id, "seconds"), true)
			"flamewing":
				if not killed:
					Reactions.apply(main, e, "burning", _num(id, "seconds"), b, _num(id, "dps"))
			"rekindler":
				if killed:
					var got2: float = p.mend_by(_num(id, "heal") * (p.heal_mult() if p.has_method("heal_mult") else 1.0))
					if got2 >= 1.0:
						main.fx_text(p.global_position + Vector2(0, -26), "+%d" % int(round(got2)), _color(id))
			"grafter":
				if killed and "graft_drops" in main and randf() < _num(id, "chance"):
					load("res://scripts/bond.gd").graft_drop(main, at, String(e.get("kind")))
			"surgeon":
				if not killed and e.has_method("bleed"):
					e.bleed(_num(id, "dps"), _num(id, "seconds"))


## Where a foe is weak: struck from behind, in the opening after its
## attack, or while stunned (Precision).
static func _weak(p, e) -> bool:
	if float(e.get("open_t") if e.get("open_t") != null else 0.0) > 0.0 or float(e.get("stun") if e.get("stun") != null else 0.0) > 0.0:
		return true
	var face = e.get("face")
	if face is Vector2 and face != Vector2.ZERO:
		return face.dot((p.global_position - e.global_position).normalized()) < -0.2
	return false


## Shards: a small conjured blade flies from the struck foe to the nearest other.
static func _shard(main, _p, e, at: Vector2, id: String) -> void:
	var best = null
	var best_d := _num(id, "reach")
	for o in main.targets():
		if o == e or not _live(o):
			continue
		var d: float = o.global_position.distance_to(at)
		if d < best_d:
			best_d = d
			best = o
	if best == null or not main.has_method("spawn_player_arrow"):
		return
	var dir: Vector2 = (best.global_position - at).normalized()
	var shot = main.spawn_player_arrow(at + dir * (float(e.get("radius")) + 6.0 if is_instance_valid(e) else 6.0), dir * _num(id, "speed"), _num(id, "damage"), 60.0, false)
	shot.style = "blade"
	shot.tint = _color(id)
	shot.life = best_d / maxf(1.0, _num(id, "speed")) + 0.3
	shot.set_meta("shard", true)


## Lent traits now between the climber's own marks (the first time: the Entity).
static func lending(p) -> bool:
	return not lent_pairs(p).is_empty()


## Synergies held now that never formed before: each named one is announced
## once (the word over the climber, the Entity's tip) and remembered; so is
## the first time two marks lend each other traits.
static func announce(main) -> Array:
	if main == null or main.player == null or main.profile == null:
		return []
	var fresh: Array = []
	for id in held(main.player):
		if not own(main.player, id):
			continue  # (a synergy shared with a rival is said when you team up: rivals.gd)
		if not id in main.profile.synergies_formed:
			main.profile.synergies_formed.append(id)
			fresh.append(id)
	var first_lent := false
	if lending(main.player) and not "lent" in main.profile.synergies_formed:
		main.profile.synergies_formed.append("lent")
		first_lent = true
	if fresh.is_empty() and not first_lent:
		return fresh
	main.profile.save()
	var at: Vector2 = main.player.global_position
	if first_lent and main.has_method("note_event"):
		main.note_event("synergy", TEXT["lent_formed"], Color(0.85, 0.75, 1.0))
	for i in fresh.size():
		var id: String = fresh[i]
		if main.has_method("note_event"):  # (the left feed and the Entity's log)
			main.note_event("synergy", TEXT["formed"] % SYNERGIES[id]["name"], SYNERGIES[id]["color"])
			main.remark("synergy")
		else:
			Reactions.word(main, at + Vector2(0, -70.0 - 26.0 * i), TEXT["formed"] % SYNERGIES[id]["name"], SYNERGIES[id]["color"])
		main.fx_ring(at, SYNERGIES[id]["color"], 60.0, 0.5, 3.0)
	main.sfx("heirloom", 1.0, -6.0)
	main.tip("synergies")
	return fresh


# --- Scald: burning ground under a soaked foe bursts into steam ----------------------

## A foe stands in burning ground of yours (main.gd _update_flames, before
## the ground burns it): if it's soaked and you hold Scald, steam bursts
## out, blinding the foes around it (they lose track of you) and scalding them.
static func scald(main, e) -> bool:
	if main == null or main.player == null or not _live(e) or not has(main.player, "scald") or not Reactions.has(e, "soaked"):
		return false
	var sd: Dictionary = SYNERGIES["scald"]
	var now := Time.get_ticks_msec() / 1000.0
	if now < float(e.get_meta("scald_t", -100.0)):
		return false
	e.set_meta("scald_t", now + float(sd["again"]))
	Reactions.clear(e, "soaked")
	var at: Vector2 = e.global_position
	var col: Color = sd["color"]
	main.fx_ring(at, col, float(sd["radius"]), 0.45, 3.0)
	main.fx_burst(at, Vector2.UP, col, 16, 160.0)
	main.fx_text(at + Vector2(0, -e.radius - 30.0), TEXT["steam"], col)
	main.sfx("burn", 1.4, -6.0)
	for o in main.targets().duplicate():
		if _live(o) and o.global_position.distance_to(at) < float(sd["radius"]) + o.radius:
			Reactions.apply(main, o, "unseen", float(sd["blind"]), "scald")
			if _live(o):
				o.take_hit(float(sd["damage"]), Vector2.ZERO, 0.0)
	return true


# --- Lightning Steel: conjured blades conduct ------------------------------------------

## A conjured blade struck a foe (projectile.gd): with Lightning Steel the
## foe is charged and lightning leaps on to your nearest other blade in
## flight (or, with none, the nearest foe), striking the foes along the bolt.
static func conduct(main, shot, e) -> int:
	if main == null or main.player == null or not has(main.player, "lightning_steel"):
		return 0
	var d: Dictionary = SYNERGIES["lightning_steel"]
	var col: Color = d["color"]
	if _live(e):
		Reactions.apply(main, e, "charged", float(d["charged"]), "lightning_steel")
	var from: Vector2 = shot.global_position
	var hop := float(d["hop"])
	var to = null
	var best_d := hop
	for k in main.get_children():
		if k == shot or not ("style" in k) or String(k.style) != "blade" or not bool(k.get("friendly")) or k.is_queued_for_deletion():
			continue
		var dd: float = from.distance_to(k.global_position)
		if dd < best_d:
			best_d = dd
			to = k.global_position
	if to == null:
		for o in main.targets():
			if o == e or not _live(o):
				continue
			var dd2: float = from.distance_to(o.global_position)
			if dd2 < best_d:
				best_d = dd2
				to = o.global_position
	if to == null:
		return 0
	main.fx_bolt([from, to], col)
	main.sfx("zap", 1.4, -8.0)
	var struck := 0
	var was: String = main.hit_kind
	main.hit_kind = "lightning"
	for o in main.targets().duplicate():
		if o == e or not _live(o):
			continue
		var near: Vector2 = Geometry2D.get_closest_point_to_segment(o.global_position, from, to)
		if near.distance_to(o.global_position) <= float(d["width"]) + o.radius:
			Reactions.apply(main, o, "charged", float(d["charged"]), "lightning_steel")
			if _live(o):
				o.take_hit(float(d["damage"]), Vector2.ZERO, 0.0)
			struck += 1
	main.hit_kind = was
	return struck


# --- Menagerie: a creature's blow carries your newest graft's power -----------------

## The part of the newest graft, or "" (no Menagerie, or no graft).
static func menagerie_part(main) -> String:
	if main == null or main.player == null or not has(main.player, "menagerie") or main.graft_order.is_empty():
		return ""
	return String(main.graft_order[-1])


## A creature strikes a foe (enemy.gd _ally_ai): returns its damage with the
## graft's power (and Kin's, lent by Covenant), and adds what the power does on top.
static func ally_strike(main, ally, target, dmg: float) -> float:
	if ally != null and is_instance_valid(ally) and float(ally.get_meta("kin_t", 0.0)) > 0.0:
		dmg *= 1.0 + _num("covenant", "more")  # (Kin: a cast lent Covenant's trait)
	var part := menagerie_part(main)
	if part == "":
		return dmg
	var p: Dictionary = SYNERGIES["menagerie"]
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


## A creature's speed and mending (enemy.gd _ally_ai, every frame); Kin runs out.
static func ally_tick(main, ally, delta: float) -> float:
	if ally != null and ally.has_meta("kin_t"):
		var k: float = float(ally.get_meta("kin_t")) - delta
		if k <= 0.0:
			ally.remove_meta("kin_t")
		else:
			ally.set_meta("kin_t", k)
	var part := menagerie_part(main)
	if part == "heart":
		ally.hp = minf(ally.max_hp, ally.hp + float(SYNERGIES["menagerie"]["heart"]) * delta)
	return float(SYNERGIES["menagerie"]["legs"]) if part == "legs" else 1.0
