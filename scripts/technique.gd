extends RefCounted
## The Unbound's techniques: their own spells, built from a body part and
## one to three essences (the first leads). Every word and number is here.
##
## A technique is {"name", "part", "shape", "kinds"}, and maybe "vars" (a
## variation from the library, library.gd VARIATIONS: at most
## Library.MAX_VARIATIONS) and "effects" ({kind: effect id}: another of that
## essence's library effects in place of its base one):
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
const Library := preload("res://scripts/library.gd")
const SpellFx := preload("res://scripts/spell_fx.gd")
const Essence := preload("res://scripts/essence.gd")
const Secret := preload("res://scripts/secret.gd")
const Reactions := preload("res://scripts/reactions.gd")

## Each part's shapes, in the order the builder cycles them.
const PART_SHAPES := {
	"hand": ["strike", "bolt"], "legs": ["dash", "leap"], "back": ["shell", "push"],
	"throat": ["shout", "pull"], "brow": ["mark", "sight"], "heart": ["within"],
}
## The forms (shapes) and what each kind does live in the shared library
## (library.gd FORMS and EFFECTS, where every name, line and number is);
## these are the very same dictionaries, by the names the code has always used:
##   SHAPES: form id -> its entry ("class", "says", its numbers);
##   KINDS: essence -> its base effect (a phrase for each class of form, numbers).
static var SHAPES: Dictionary = Library.FORMS
static var KINDS: Dictionary = Library.base_effects()
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
	if not (t is Dictionary and PART_SHAPES.has(String(t.get("part", ""))) and t.get("kinds") is Array and not t["kinds"].is_empty()):
		return false
	var sh := String(t.get("shape", ""))
	if sh in PART_SHAPES[t["part"]]:
		return true
	# (a library form of that part, once it's written)
	return Library.built(Library.form(sh)) and String(Library.form(sh).get("part", "")) == String(t["part"])


## Its variations (library ids that exist and are written, at most MAX_VARIATIONS).
static func variations(t: Dictionary) -> Array:
	var out: Array = []
	var vs = t.get("vars", [])
	if vs is Array:
		for v in vs:
			if Library.built(Library.variation(String(v))) and not String(v) in out and out.size() < Library.MAX_VARIATIONS:
				out.append(String(v))
	return out


## The effect an essence brings to it (its chosen library effect, else its base one).
static func effect_of(t: Dictionary, kind: String) -> String:
	var fx = t.get("effects", {})
	if fx is Dictionary and fx.has(kind) and Library.built(Library.effect(String(fx[kind]))) and String(Library.effect(String(fx[kind])).get("kind", "")) == kind:
		return String(fx[kind])
	return String(Library.BASE.get(kind, ""))


## How much farther a technique reaches with Air in it (by its weights).
static func reach_mult(w: Dictionary) -> float:
	return 1.0 + float(KINDS["air"]["reach"]) * float(w.get("air", 0.0))


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


## Strain a cast adds: by how many kinds, plus its form's and its variation's.
static func strain(t: Dictionary) -> float:
	var s := float(STRAIN[clampi(t["kinds"].size() - 1, 0, STRAIN.size() - 1)])
	s += float(Library.form(String(t.get("shape", ""))).get("strain", 0.0))
	for v in variations(t):
		s += float(Library.variation(v).get("strain", 0.0))
	s += float(_effects_file().echo_strain(t))  # (an echo costs a little strain: unbound_effects.gd ECHO_ACTS)
	return s


## The Unbound's effects file (its echoes and its effects on yourself).
static func _effects_file():
	return load("res://scripts/spells/unbound_effects.gd")


static func windup(t: Dictionary) -> float:
	var w := float(WINDUP[0]) + float(WINDUP[1]) * float(t["kinds"].size() - 1)
	for v in variations(t):
		w *= float(Library.variation(v).get("windup", 1.0))
	return w


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
		var fx := effect_of(t, k)
		if fx != String(Library.BASE.get(k, "")):
			var fe := Library.effect(fx)
			phrase = String(fe.get("move", fe.get(key, fe.get("hit", phrase))) if cls == "move" else fe.get(key, fe.get("hit", phrase)))
		bits.append(phrase if i == 0 else "a little " + phrase if key != "self" else "and a little: " + phrase)
	var what: String = sh["says"]
	var vs := variations(t)
	if not vs.is_empty():
		var v := Library.variation(vs[0])
		what = "%s (%s: %s)" % [what, v["name"], String(v["says"]).to_lower()]
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
	var vs := variations(t)
	var w := cast_weights(t)
	var hits := _cast_form(t, p, power, run, shape(t), w) if vs.is_empty() else _cast_varied(t, p, power, run, vs[0], w)
	# A technique that comes close to a bond's spell adds a weaker touch of it
	# (unbound_effects.gd ECHO_ACTS; library.gd ECHOES).
	_effects_file().cast_echo(t, p, power, run)
	return hits


## The weights a cast acts with: weights(), plus "_fx" (the kinds whose
## chosen effect replaces their base one: {kind: effect id}) when there are any.
static func cast_weights(t: Dictionary) -> Dictionary:
	var w := weights(t)
	var fx := {}
	for k in t["kinds"]:
		var id := effect_of(t, String(k))
		if id != String(Library.BASE.get(String(k), "")):
			fx[String(k)] = id
	if not fx.is_empty():
		w["_fx"] = fx
	return w


## A form's numbers under a variation (Wide widens, Long reaches farther).
static func varied_shape(sh: Dictionary, vid: String) -> Dictionary:
	var v := Library.variation(vid)
	var out := sh.duplicate()
	match vid:
		"wide":
			for k in ["arc", "radius", "near", "width"]:
				if out.has(k):
					out[k] = float(out[k]) * float(v.get("arc" if k == "arc" else "radius", 1.4))
		"long":
			for k in ["reach", "range", "dist", "length", "near"]:
				if out.has(k):
					out[k] = float(out[k]) * float(v.get("reach", 1.4))
	return out


## A cast under its variation (library.gd VARIATIONS): its numbers changed,
## cast again (Split, Mirrored, Echo), later (Delayed), jumping on (Chain)
## or leaving a field (Lingering).
static func _cast_varied(t: Dictionary, p, power: float, run, vid: String, w: Dictionary) -> int:
	var v := Library.variation(vid)
	var sh := varied_shape(shape(t), vid)
	var pw := power * float(v.get("power", 1.0))
	var cls := String(sh.get("class", "hit"))
	var aimed: bool = cls in ["hit", "mark"] and String(t["shape"]) != "push"
	var main = p.main
	match vid:
		"split":
			if not aimed:
				return _cast_form(t, p, power, run, sh, w)
			var aim: Vector2 = p.aim
			var n := int(v.get("copies", 3))
			var hits := 0
			for i in n:
				p.aim = aim.rotated(deg_to_rad(float(v.get("spread", 22.0))) * (float(i) - float(n - 1) * 0.5))
				hits += _cast_form(t, p, pw, run, sh, w)
			p.aim = aim
			return hits
		"mirrored":
			if cls in ["move", "self", "shell", "sight"]:
				return _cast_form(t, p, power, run, sh, w)
			var hits := _cast_form(t, p, pw, run, sh, w)
			var aim: Vector2 = p.aim
			p.aim = -aim
			hits += _cast_form(t, p, pw, run, sh, w)
			p.aim = aim
			return hits
		"echo":
			var hits := _cast_form(t, p, power, run, sh, w)
			SpellFx.later(main, float(v.get("delay", 1.0)), func():
				if is_instance_valid(p) and not p.dead:
					_cast_form(t, p, pw, run, sh, w))
			return hits
		"delayed":
			SpellFx.mark(main, p.global_position + (p.aim * 50.0 if aimed else Vector2.ZERO), float(v.get("delay", 0.6)), color(lead(t)))
			SpellFx.later(main, float(v.get("delay", 0.6)), func():
				if is_instance_valid(p) and not p.dead:
					_cast_form(t, p, pw, run, sh, w))
			return 0
		"chain":
			var cw := w.duplicate()
			cw["_chain"] = {"hop": float(v.get("hop", 170.0)), "share": float(v.get("power", 0.6))}
			return _cast_form(t, p, power, run, sh, cw)
		"lingering":
			var hits := _cast_form(t, p, power, run, sh, w)
			var at: Vector2 = p.global_position
			if aimed:
				at += p.aim * minf(float(sh.get("reach", sh.get("range", sh.get("length", 120.0)))) * 0.6, 140.0)
			var fw := {}
			for k in w:
				if not String(k).begins_with("_"):
					fw[k] = float(w[k]) * 0.5
			var dmg := float(sh.get("damage", 6.0)) * power * float(v.get("power", 0.2))
			SpellFx.field(main, at, float(v.get("radius", 52.0)), float(v.get("duration", 3.0)), float(v.get("tick", 0.5)), color(lead(t)), func(foes: Array):
				for e in foes:
					hit(p, e, dmg, Vector2.ZERO, fw, power * 0.5, run))
			return hits
	return _cast_form(t, p, pw, run, sh, w)


## Casts a form with these numbers (`sh`) and weights (`w`). A library form
## this file doesn't run is run by its content file (library.gd cast_form).
static func _cast_form(t: Dictionary, p, power: float, run, sh: Dictionary, w: Dictionary) -> int:
	var main = p.main
	var col := color(lead(t))
	var reach_k := reach_mult(w)
	var origin: Vector2 = p.global_position
	var aim: Vector2 = p.aim
	var hits := 0
	if w.has("unmaking"):
		_toll(p, float(KINDS["unmaking"]["toll"]) * float(w["unmaking"]))
	if not String(t["shape"]) in Library.FORMS or not String(t["shape"]) in ["strike", "bolt", "dash", "leap", "push", "shout", "pull", "mark", "sight", "shell", "within"]:
		hits = Library.cast_form(String(t["shape"]), t, p, power, run, sh, w)
		main.light_flash(origin + aim * 20.0, col, 1.0, 1.0, 0.25)
		return maxi(hits, 0)
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
				if String(k).begins_with("_"):
					w2[k] = w[k]  # (a chosen effect, a Chain)
				elif k != "air":
					w2[k] = float(w[k]) * 0.5
			for e in main.targets():
				if e.global_position.distance_to(origin) <= near:
					hit(p, e, 0.0, Vector2.ZERO, w2, power, run)
					hits += 1
			main.fx_ring(origin, col, near, 0.6, 2.0)
			main.sfx("glint", 0.8, -4.0)
		"shell":
			var chosen: Dictionary = w.get("_fx", {})
			if not chosen.is_empty():
				w = w.duplicate()
				for k in chosen:
					w.erase(k)  # (a chosen effect works instead of its essence's base one: _self_effects)
			var shield: float = float(sh["shield"]) * power * (1.0 + 1.0 * float(w.get("stone", 0.0)) + 0.5 * float(w.get("iron", 0.0)) + 0.5 * float(w.get("unmaking", 0.0)))
			var dur: float = float(sh["duration"]) * (1.0 + 0.6 * float(w.get("air", 0.0)))
			p.raise_barrier(shield, dur, w.has("fire"), col)
			if w.has("water"):
				_mend(p, float(KINDS["water"]["mend"]) * power * float(w["water"]) * 0.5, dur)
			if w.has("blade"):
				p.edge_t = maxf(p.edge_t, dur * float(w["blade"]))
			if w.has("life"):
				_heal(p, float(KINDS["life"]["self_heal"]) * power * float(w["life"]) * 0.6)
			_self_effects(p, chosen, cast_weights(t), power, run, "shell")
			main.fx_ring(origin, col, 40.0, 0.35, 3.0)
			main.sfx("parry", 0.7, -6.0)
		"within":
			var dur: float = float(sh["duration"])
			var chosen: Dictionary = w.get("_fx", {})
			for k in w:
				if String(k).begins_with("_") or chosen.has(k):
					continue  # (a chosen effect works instead: _self_effects)
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
			_self_effects(p, chosen, w, power, run, "self")
			main.fx_ring(origin, col, 30.0, 0.4, 3.0)
			main.sfx("ready", 1.1, -4.0)
	main.light_flash(origin + aim * 20.0, col, 1.0, 1.0, 0.25)
	return hits


## A foe struck by a technique: its damage, then what each kind adds.
static func hit(p, e, dmg: float, dir: Vector2, w_all: Dictionary, power: float, run) -> void:
	if e == null or not is_instance_valid(e) or e.dead:
		return
	# A kind with another chosen effect (its "_fx") works through that
	# effect instead of its base one; Chain ("_chain") jumps on afterwards.
	var w := w_all
	var fx: Dictionary = w_all.get("_fx", {})
	if not fx.is_empty():
		w = {}
		for k in w_all:
			if not String(k).begins_with("_") and not fx.has(k):
				w[k] = w_all[k]
	_hit_base(p, e, dmg, dir, w, power, run)
	if not fx.is_empty() and is_instance_valid(e) and not e.dead:
		for k in fx:
			Library.hit_effect(String(fx[k]), p, e, float(w_all.get(k, 0.0)), power, run)
	var ch: Dictionary = w_all.get("_chain", {})
	if not ch.is_empty() and dmg > 0.0 and p.main != null:
		var best = null
		var best_d := float(ch.get("hop", 170.0))
		for o in p.main.targets():
			if o == e or o.dead:
				continue
			var d: float = o.global_position.distance_to(e.global_position) if is_instance_valid(e) else INF
			if d < best_d:
				best_d = d
				best = o
		if best != null:
			var w2 := w_all.duplicate()
			w2.erase("_chain")  # (one jump, not a chain without end)
			p.main.fx_bolt([e.global_position if is_instance_valid(e) else p.global_position, best.global_position], color(_lead_of(w_all)))
			hit(p, best, dmg * float(ch.get("share", 0.6)), Vector2.ZERO, w2, power, run)


## Chosen effects on yourself (Within) or as a shell rises: each runs
## through the content file that declared it (its self_effect).
static func _self_effects(p, chosen: Dictionary, w: Dictionary, power: float, run, cls: String) -> void:
	for k in chosen:
		var s = Library._effect_src.get(String(chosen[k]))
		if s != null and s.has_method("self_effect"):
			s.self_effect(String(chosen[k]), p, float(w.get(k, 0.0)), power, run, cls)


static func _lead_of(w: Dictionary) -> String:
	for k in w:
		if not String(k).begins_with("_") and float(w[k]) >= 1.0:
			return String(k)
	return "air"


## A struck foe: its damage, then what each kind's base effect adds.
static func _hit_base(p, e, dmg: float, dir: Vector2, w: Dictionary, power: float, run) -> void:
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
		if is_instance_valid(e) and not e.dead:
			e.soak(float(Reactions.STATES["soaked"]["seconds"]) * minf(1.0, 0.5 + 0.5 * float(w["water"])))  # (water soaks: reactions.gd)
	if w.has("stone"):
		e.stagger(float(KINDS["stone"]["stagger"]) * float(w["stone"]))
	if w.has("iron") and not e.is_boss():
		var to_me: Vector2 = (p.global_position - e.global_position)
		if to_me.length() > p.radius + e.radius + 8.0:
			e.knock = to_me.normalized() * float(KINDS["iron"]["drag"]) * float(w["iron"])
	if w.has("blade"):
		run.add_dot(e, float(KINDS["blade"]["bleed"]) * float(w["blade"]) * power, 3.0, color("blade"), "bleeding")
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
