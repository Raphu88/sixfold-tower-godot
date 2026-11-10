extends RefCounted
## The Unbound's techniques: their own spells, built from a body part and
## one to three essences (the first leads). Every word and number is here.
##
## A technique is {"name", "part", "shape", "kinds"}:
##   the PART gives its shape (SHAPES: the hand strikes or throws a bolt, the
##   legs dash or leap, the back raises a shell or pushes, the throat shouts
##   in a cone or pulls, the brow marks a foe or sees through fog, the heart
##   works on yourself);
##   each KIND adds what it does (KINDS); the first leads (full strength),
##   the others flavour it (FLAVOUR of their strength).
## Fill: a technique fills from its body part's actions, the way a mark's
## bond does (player.gd _part_action: strikes fill the hand, rolls the legs,
## parries the brow...). Full at CHARGE (by how many kinds), it casts without
## spending anything; cast before it's full and the missing share comes out
## as up to EMPTY_STRAIN extra strain.
## Boost: if you carry its essences unbanked (COST by how many kinds, paid in
## those kinds in proportion, the lead counting double; the path's essence
## from your unbanked flow), a cast spends them and hits BOOST harder. It's
## automatic (on unless switched off on the techniques page): nothing to
## hold on a phone.
## Strain: STRAIN by how many kinds (unbound_run.gd adds it, and erupts at
## 100). Strength: the part's level (unbound.gd power).
## A few ready-made recipes (RECIPES) fill an Unbound's six slots at first.

const Unbound := preload("res://scripts/unbound.gd")
const Essence := preload("res://scripts/essence.gd")
const Secret := preload("res://scripts/secret.gd")

## Each part's shapes, in the order the builder cycles them.
const PART_SHAPES := {
	"hand": ["strike", "bolt"], "legs": ["dash", "leap"], "back": ["shell", "push"],
	"throat": ["shout", "pull"], "brow": ["mark", "sight"], "heart": ["within"],
}
## class: "hit" (strikes foes), "move" (moves you, hits on the way or on landing),
## "self" (works on you), "shell" (a barrier on you), "mark" (one foe), "sight".
const SHAPES := {
	"strike": {"name": "Strike", "class": "hit", "says": "A blow of raw essence in front of you", "damage": 16.0, "reach": 50.0, "arc": 60.0},
	"bolt": {"name": "Bolt", "class": "hit", "says": "A bolt thrown where you aim", "damage": 12.0, "speed": 470.0, "range": 340.0},
	"dash": {"name": "Dash", "class": "move", "says": "You dash forward, untouchable, striking what you pass", "damage": 8.0, "dist": 130.0},
	"leap": {"name": "Leap", "class": "move", "says": "You leap where you aim and land hard on what's there", "damage": 14.0, "dist": 130.0, "radius": 56.0},
	"shell": {"name": "Shell", "class": "shell", "says": "A shell around you that takes blows for you", "shield": 30.0, "duration": 5.0},
	"push": {"name": "Push", "class": "hit", "says": "A burst that throws back every foe around you", "damage": 6.0, "radius": 85.0, "force": 380.0},
	"shout": {"name": "Shout", "class": "hit", "says": "A shout in a cone in front of you", "damage": 10.0, "reach": 135.0, "arc": 38.0},
	"pull": {"name": "Pull", "class": "hit", "says": "Drags the foes in a line in front of you to you", "damage": 5.0, "length": 210.0, "width": 54.0},
	"mark": {"name": "Mark", "class": "mark", "says": "Marks the foe you aim at: it takes 50% more damage for a while", "range": 320.0, "duration": 8.0},
	"sight": {"name": "Sight", "class": "sight", "says": "For a while you see every foe through walls and fog", "duration": 8.0, "near": 220.0},
	"within": {"name": "Within", "class": "self", "says": "Works on yourself", "duration": 8.0},
}
## What each kind does, by the shape's class. Numbers at full (lead) strength:
##   burn     damage a second for burn_t seconds
##   slow     seconds a foe walks slower
##   reach    shapes reach (and dashes carry) this much farther; knock harder
##   stagger  seconds a foe is staggered
##   pierce   ignores armour; drag pulls a foe toward you
##   cut      this much more damage; bleed damage a second for 3 s
##   heal     health back for each foe hit
##   erode    this much more damage, ignores armour, erodes this a second for 4 s; costs you health
const KINDS := {
	"fire": {"hit": "burns what it hits", "self": "your strikes burn for a while", "shell": "bursts into flame when it breaks", "near": "burns the foes near you",
		"burn": 4.0, "burn_t": 3.0, "kindle": 5.0},
	"water": {"hit": "slows what it hits", "self": "you heal steadily for a while", "shell": "mends you while it holds", "near": "slows the foes near you",
		"slow": 3.5, "mend": 24.0},
	"air": {"hit": "reaches farther and throws harder", "self": "you move faster and roll for less", "shell": "lasts longer", "near": "lets you see for longer",
		"reach": 0.4, "move": "carries you farther"},
	"stone": {"hit": "staggers what it hits", "self": "you take less damage and can't be knocked back", "shell": "is much stronger", "near": "staggers the foes near you",
		"stagger": 0.7},
	"iron": {"hit": "pierces armour and drags foes toward you", "self": "your stamina comes back faster", "shell": "is stronger", "near": "drags the foes near you closer",
		"drag": 220.0},
	"blade": {"hit": "cuts deeper and leaves foes bleeding", "self": "your strikes hit harder for a while", "shell": "sharpens your strikes while it holds", "near": "cuts the foes near you",
		"cut": 0.35, "bleed": 3.0},
	"life": {"hit": "heals you for each foe it hits", "self": "heals you at once", "shell": "heals you as it rises", "near": "heals you for each foe near you",
		"heal": 3.0, "self_heal": 22.0},
	"unmaking": {"hit": "ignores armour and keeps eroding, at a cost in your health", "self": "your strikes hit harder, at a cost in health", "shell": "is stronger, at a cost in health", "near": "erodes the foes near you, at a cost in health",
		"erode": 3.0, "more": 0.3, "toll": 3.0},
}
## The others flavour the lead at this share of their strength (2nd, 3rd).
const FLAVOUR := [1.0, 0.5, 0.35]
## The fill a technique needs to cast (it's full there), the carried
## essence a boost spends, and the strain a cast adds, by how many kinds (1, 2, 3).
const CHARGE := [20.0, 28.0, 36.0]
const COST := [3.0, 6.0, 8.0]
const STRAIN := [14.0, 22.0, 32.0]
## Cast with an empty gauge: this much more strain (in proportion to what's missing).
const EMPTY_STRAIN := 24.0
## A boosted cast hits this much harder.
const BOOST := 0.5
## Wind-up: base, plus this for each kind past the first.
const WINDUP := [0.18, 0.06]
## The ready-made recipes (an Unbound's six slots at first, and on the builder).
const RECIPES := {
	"ember_bolt": {"name": "Ember Bolt", "part": "hand", "shape": "bolt", "kinds": ["fire"]},
	"gale_dash": {"name": "Gale Dash", "part": "legs", "shape": "dash", "kinds": ["air"]},
	"iron_will": {"name": "Iron Will", "part": "heart", "shape": "within", "kinds": ["iron"]},
	"hunters_mark": {"name": "Hunter's Mark", "part": "brow", "shape": "mark", "kinds": ["blade"]},
	"tidal_shout": {"name": "Tidal Shout", "part": "throat", "shape": "shout", "kinds": ["water"]},
	"stone_shell": {"name": "Stone Shell", "part": "back", "shape": "shell", "kinds": ["stone"]},
	"rending_strike": {"name": "Rending Strike", "part": "hand", "shape": "strike", "kinds": ["blade"]},
	"quake_leap": {"name": "Quake Leap", "part": "legs", "shape": "leap", "kinds": ["stone"]},
	"undertow": {"name": "Undertow", "part": "throat", "shape": "pull", "kinds": ["iron"]},
	"far_sight": {"name": "Far Sight", "part": "brow", "shape": "sight", "kinds": ["air"]},
	"shove": {"name": "Shove", "part": "back", "shape": "push", "kinds": ["air"]},
}
## The six slots' recipes for a new Unbound (slot i is cast with part i's button).
const STARTERS := ["ember_bolt", "gale_dash", "iron_will", "hunters_mark", "tidal_shout", "stone_shell"]
static var TEXT := {
	"empty": "Empty",
	"cost": "Boost: %s carried",
	"strain": "Strain +%d",
	"needs_level": "level %d to combine %d",
	"lead": "leads",
	"wavers": "wavers",
	"dark": "%s is dark",
	"not_full": "not full: more strain",
	"boosted": "boosted",
}
## Adjectives for a technique's default name, by its lead kind.
const NAME_WORD := {"fire": "Burning", "water": "Tidal", "air": "Gale", "stone": "Stone", "iron": "Iron", "blade": "Rending", "life": "Living", "unmaking": "Unmaking"}


static func color(kind: String) -> Color:
	if kind in Secret.ORDER:
		return Secret.color(kind)
	return Essence.color(kind)


static func display(kind: String) -> String:
	if kind in Secret.ORDER:
		return Secret.display(kind)
	return Essence.display(kind)


## A copy of a ready-made recipe.
static func recipe(id: String) -> Dictionary:
	var r: Dictionary = RECIPES.get(id, RECIPES["ember_bolt"])
	return {"name": r["name"], "part": r["part"], "shape": r["shape"], "kinds": r["kinds"].duplicate()}


## A technique record, or {} if it isn't one (broken saves).
static func valid(t) -> bool:
	return t is Dictionary and PART_SHAPES.has(String(t.get("part", ""))) and String(t.get("shape", "")) in PART_SHAPES[t["part"]] \
		and t.get("kinds") is Array and not t["kinds"].is_empty()


static func shape(t: Dictionary) -> Dictionary:
	return SHAPES[t["shape"]]


static func lead(t: Dictionary) -> String:
	return String(t["kinds"][0])


## Its name: the one given, else one made from its lead kind and shape.
static func title(t: Dictionary) -> String:
	var n := String(t.get("name", "")).strip_edges()
	if n != "":
		return n
	return auto_name(t)


static func auto_name(t: Dictionary) -> String:
	return "%s %s" % [NAME_WORD.get(lead(t), "Raw"), SHAPES[t["shape"]]["name"]]


## The fill it needs to cast (the Clear Brow gift's cut applied).
static func charge(t: Dictionary, prof = null) -> float:
	var total: float = float(CHARGE[clampi(t["kinds"].size() - 1, 0, CHARGE.size() - 1)])
	if prof != null:
		total *= 1.0 - Unbound.gift(prof, "cost")
	return total


## A boost's cost: {kind: amount}, the lead counting double (and the Clear Brow gift's cut).
static func cost(t: Dictionary, prof = null) -> Dictionary:
	var n: int = t["kinds"].size()
	var total: float = float(COST[clampi(n - 1, 0, COST.size() - 1)])
	if prof != null:
		total *= 1.0 - Unbound.gift(prof, "cost")
	var weight := float(n + 1)
	var out := {}
	for i in n:
		var k := String(t["kinds"][i])
		out[k] = float(out.get(k, 0.0)) + total * (2.0 if i == 0 else 1.0) / weight
	return out


static func strain(t: Dictionary) -> float:
	return float(STRAIN[clampi(t["kinds"].size() - 1, 0, STRAIN.size() - 1)])


static func windup(t: Dictionary) -> float:
	return float(WINDUP[0]) + float(WINDUP[1]) * float(t["kinds"].size() - 1)


static func cost_text(t: Dictionary, prof = null) -> String:
	var c := cost(t, prof)
	var bits: Array = []
	for k in t["kinds"]:
		if c.has(k):
			bits.append("%s %s" % [_num(c[k]), display(k)])
			c.erase(k)
	return ", ".join(bits)


static func _num(f: float) -> String:
	return str(int(round(f))) if absf(f - round(f)) < 0.05 else "%.1f" % f


## In plain words: what it does (its shape, then what each kind adds).
static func describe(t: Dictionary) -> String:
	var sh: Dictionary = shape(t)
	var cls: String = sh["class"]
	var key := "hit"
	match cls:
		"self":
			key = "self"
		"shell":
			key = "shell"
		"sight":
			key = "near"
	var bits: Array = []
	for i in t["kinds"].size():
		var k := String(t["kinds"][i])
		var phrase: String = KINDS[k][key]
		if cls == "move" and k == "air":
			phrase = KINDS[k]["move"]
		bits.append(phrase if i == 0 else "a little " + phrase if key != "self" else "and a little: " + phrase)
	var what: String = sh["says"]
	match cls:
		"self":
			return "%s: %s%s." % [what, bits[0], ("; " + "; ".join(bits.slice(1))) if bits.size() > 1 else ""]
		"shell":
			return "%s. It %s%s." % [what, bits[0], (", and " + ", and ".join(bits.slice(1))) if bits.size() > 1 else ""]
		"mark":
			return "%s. It also %s%s." % [what, bits[0], (", and " + ", and ".join(bits.slice(1))) if bits.size() > 1 else ""]
		"sight":
			return "%s. It %s%s." % [what, bits[0], (", and " + ", and ".join(bits.slice(1))) if bits.size() > 1 else ""]
	return "%s. It %s%s." % [what, bits[0], (", and " + ", and ".join(bits.slice(1))) if bits.size() > 1 else ""]


## The weights each kind acts with: {kind: share}, the lead at 1.
static func weights(t: Dictionary) -> Dictionary:
	var out := {}
	for i in t["kinds"].size():
		var k := String(t["kinds"][i])
		out[k] = maxf(float(out.get(k, 0.0)), float(FLAVOUR[clampi(i, 0, FLAVOUR.size() - 1)]))
	return out


# --- casting ----------------------------------------------------------------------

## Casts a technique for climber `p` at strength `power` (density, strain, a
## waver all folded in). `run` is unbound_run.gd (bolts, landings, bleeds).
## Returns how many foes it touched.
static func cast(t: Dictionary, p, power: float, run) -> int:
	var main = p.main
	var sh: Dictionary = shape(t)
	var w := weights(t)
	var col := color(lead(t))
	var reach_k := 1.0 + float(KINDS["air"]["reach"]) * float(w.get("air", 0.0))
	var origin: Vector2 = p.global_position
	var aim: Vector2 = p.aim
	var hits := 0
	if w.has("unmaking"):
		_toll(p, float(KINDS["unmaking"]["toll"]) * float(w["unmaking"]))
	match String(t["shape"]):
		"strike":
			var reach: float = float(sh["reach"]) * reach_k
			var half := deg_to_rad(float(sh["arc"]))
			for e in main.targets():
				var to: Vector2 = e.global_position - origin
				if to.length() <= reach + e.radius and absf(aim.angle_to(to)) <= half:
					hit(p, e, float(sh["damage"]) * power, to.normalized(), w, power, run)
					hits += 1
			main.fx_cone(origin, aim, reach, half, col)
			main.sfx("hit_heavy", 0.8, -2.0)
		"bolt":
			run.add_bolt(origin + aim * (p.radius + 6.0), aim * float(sh["speed"]), float(sh["range"]) * reach_k, float(sh["damage"]) * power, w, power, col)
			main.sfx("zap", 1.2, -4.0)
		"dash":
			var dist: float = float(sh["dist"]) * reach_k
			var to_pt: Vector2 = origin + aim * dist
			for e in main.targets():
				var seg := Geometry2D.get_closest_point_to_segment(e.global_position, origin, to_pt)
				if seg.distance_to(e.global_position) <= e.radius + p.radius + 6.0:
					hit(p, e, float(sh["damage"]) * power, aim, w, power, run)
					hits += 1
			p.roll_dir = aim
			p.roll_t = 0.2
			p.roll_speed = dist / 0.2
			p.iframes = maxf(p.iframes, 0.26)
			p.ghost_t = 0.0
			main.sfx("gust", 1.2, -4.0)
		"leap":
			var dist: float = float(sh["dist"]) * reach_k
			p.jump_total = 0.4
			p.jump_t = 0.4
			p.jump_vel = aim * dist / 0.4
			run.add_landing(0.4, float(sh["radius"]), float(sh["damage"]) * power, w, power, col)
			main.sfx("roll", 0.8)
		"push":
			var r: float = float(sh["radius"]) * reach_k
			for e in main.targets():
				var to: Vector2 = e.global_position - origin
				if to.length() <= r + e.radius:
					var dir := to.normalized() if to.length() > 0.1 else Vector2.RIGHT
					e.tide_push(dir * float(sh["force"]) * reach_k)
					hit(p, e, float(sh["damage"]) * power, dir, w, power, run)
					hits += 1
			main.fx_ring(origin, col, r, 0.4, 5.0)
			main.sfx("gust", 0.7, -2.0)
		"shout":
			var reach: float = float(sh["reach"]) * reach_k
			var half := deg_to_rad(float(sh["arc"]))
			for e in main.targets():
				var to: Vector2 = e.global_position - origin
				if to.length() <= reach + e.radius and absf(aim.angle_to(to)) <= half:
					hit(p, e, float(sh["damage"]) * power, to.normalized(), w, power, run)
					hits += 1
			main.fx_cone(origin, aim, reach, half, col)
			main.sfx("warn_knight", 1.3, -6.0)
		"pull":
			var length: float = float(sh["length"]) * reach_k
			for e in main.targets():
				var to: Vector2 = e.global_position - origin
				var along := to.dot(aim)
				if along < 0.0 or along > length or absf(to.dot(aim.orthogonal())) > float(sh["width"]) * 0.5 + e.radius:
					continue
				var pull := -aim * minf(along * 2.4, 520.0)
				e.tide_push(pull)
				hit(p, e, float(sh["damage"]) * power, Vector2.ZERO, w, power, run)
				e.knock = pull
				hits += 1
			main.fx_cone(origin, aim, length, deg_to_rad(6.0), col)
			main.sfx("gust", 0.6, -2.0)
		"mark":
			var best = null
			var best_d := float(sh["range"]) * reach_k
			for e in main.targets():
				var to: Vector2 = e.global_position - origin
				if to.length() < best_d and absf(aim.angle_to(to)) < 0.5:
					best = e
					best_d = to.length()
			if best != null:
				best.challenged_t = maxf(best.challenged_t, float(sh["duration"]))
				hit(p, best, 0.0, Vector2.ZERO, w, power, run)
				main.fx_ring(best.global_position, col, best.radius + 12.0, 0.5, 3.0)
				main.fx_text(best.global_position + Vector2(0, -best.radius - 26.0), "Marked", col)
				hits = 1
			else:
				main.fx_text(origin + Vector2(0, -34), "no one to mark", col)
			main.sfx("glint", 1.1, -4.0)
		"sight":
			main.track_t = maxf(main.track_t, float(sh["duration"]) * reach_k)
			var near: float = float(sh["near"])
			var w2 := {}
			for k in w:
				if k != "air":
					w2[k] = float(w[k]) * 0.5
			for e in main.targets():
				if e.global_position.distance_to(origin) <= near:
					hit(p, e, 0.0, Vector2.ZERO, w2, power, run)
					hits += 1
			main.fx_ring(origin, col, near, 0.6, 2.0)
			main.sfx("glint", 0.8, -4.0)
		"shell":
			var shield: float = float(sh["shield"]) * power * (1.0 + 1.0 * float(w.get("stone", 0.0)) + 0.5 * float(w.get("iron", 0.0)) + 0.5 * float(w.get("unmaking", 0.0)))
			var dur: float = float(sh["duration"]) * (1.0 + 0.6 * float(w.get("air", 0.0)))
			p.raise_barrier(shield, dur, w.has("fire"), col)
			if w.has("water"):
				_mend(p, float(KINDS["water"]["mend"]) * power * float(w["water"]) * 0.5, dur)
			if w.has("blade"):
				p.edge_t = maxf(p.edge_t, dur * float(w["blade"]))
			if w.has("life"):
				_heal(p, float(KINDS["life"]["self_heal"]) * power * float(w["life"]) * 0.6)
			main.fx_ring(origin, col, 40.0, 0.35, 3.0)
			main.sfx("parry", 0.7, -6.0)
		"within":
			var dur: float = float(sh["duration"])
			for k in w:
				var s: float = float(w[k])
				match String(k):
					"fire":
						p.kindle_t = maxf(p.kindle_t, dur * s)
						p.kindle_dmg = maxf(p.kindle_dmg if p.kindle_t > 0.0 else 0.0, float(KINDS["fire"]["kindle"]) * power * s)
					"water":
						_mend(p, float(KINDS["water"]["mend"]) * power * s, dur)
					"air":
						p.haste_t = maxf(p.haste_t, dur * s)
					"stone":
						p.stone_t = maxf(p.stone_t, dur * s)
					"iron":
						p.salts_t = maxf(p.salts_t, dur * s)
					"blade", "unmaking":
						p.edge_t = maxf(p.edge_t, dur * s)
					"life":
						_heal(p, float(KINDS["life"]["self_heal"]) * power * s)
			main.fx_ring(origin, col, 30.0, 0.4, 3.0)
			main.sfx("ready", 1.1, -4.0)
	main.light_flash(origin + aim * 20.0, col, 1.0, 1.0, 0.25)
	return hits


## A foe struck by a technique: its damage, then what each kind adds.
static func hit(p, e, dmg: float, dir: Vector2, w: Dictionary, power: float, run) -> void:
	if e == null or not is_instance_valid(e) or e.dead:
		return
	var pierce := false
	var force := 140.0 * (1.0 + float(w.get("air", 0.0)))
	if w.has("blade"):
		dmg *= 1.0 + float(KINDS["blade"]["cut"]) * float(w["blade"])
	if w.has("unmaking"):
		dmg *= 1.0 + float(KINDS["unmaking"]["more"]) * float(w["unmaking"])
		pierce = true
	if w.has("iron"):
		pierce = true
	dmg *= float(p.flow_damage)  # (Unmaking's flow: spells hit harder)
	if dmg > 0.0:
		e.take_hit(dmg, dir, force, w.has("stone"), pierce)
	if e.dead or not is_instance_valid(e):
		if w.has("life"):
			_heal(p, float(KINDS["life"]["heal"]) * float(w["life"]) * power)
		return
	if w.has("fire"):
		e.ignite(float(KINDS["fire"]["burn"]) * float(w["fire"]) * power, float(KINDS["fire"]["burn_t"]))
	if w.has("water"):
		e.chill_t = maxf(e.chill_t, float(KINDS["water"]["slow"]) * float(w["water"]))
	if w.has("stone"):
		e.stagger(float(KINDS["stone"]["stagger"]) * float(w["stone"]))
	if w.has("iron") and not e.is_boss():
		var to_me: Vector2 = (p.global_position - e.global_position)
		if to_me.length() > p.radius + e.radius + 8.0:
			e.knock = to_me.normalized() * float(KINDS["iron"]["drag"]) * float(w["iron"])
	if w.has("blade"):
		run.add_dot(e, float(KINDS["blade"]["bleed"]) * float(w["blade"]) * power, 3.0, color("blade"))
	if w.has("unmaking"):
		run.add_dot(e, float(KINDS["unmaking"]["erode"]) * float(w["unmaking"]) * power, 4.0, color("unmaking"))
	if w.has("life"):
		_heal(p, float(KINDS["life"]["heal"]) * float(w["life"]) * power)


static func _heal(p, amount: float) -> void:
	var h: float = p.mend_by(amount * p.heal_mult())
	if h >= 1.0:
		p.main.fx_text(p.global_position + Vector2(0, -44), "+%d" % int(h), Color(0.6, 1.0, 0.7))


## Healing over time (as a draught heals).
static func _mend(p, amount: float, over: float) -> void:
	p.heal_left += amount * p.heal_mult()
	p.heal_rate = maxf(p.heal_rate, amount / maxf(over, 0.5))


## Unmaking's toll: a little of your health (never the last of it).
static func _toll(p, amount: float) -> void:
	p.hp = maxf(1.0, p.hp - amount)
