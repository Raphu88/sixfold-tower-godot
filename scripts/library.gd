extends RefCounted
## THE LIBRARY: the one shared set of pieces every spell in the game is made
## from, in data, so every name, line and number is easy to change (the Data
## editor lists these tables: data_registry.gd "library_*").
##
##   FORMS       the shape a body part gives (hand: Strike, Bolt...). The
##               Unbound's techniques are a form plus one to three essences.
##   EFFECTS     what an essence does (Fire burns, Water slows...). Each
##               essence has a base effect (BASE), and more open as that
##               essence pools in an Unbound body (unbound_effects.gd).
##   VARIATIONS  small alterations shared by both paths (Wide, Long, Quick,
##               Split, Lingering, Chain, Delayed, Mirrored, Echo, Charged).
##               The Unbound fit one to a technique (MAX_VARIATIONS); a
##               marked climber meets them as the step-3 choice of a bond's
##               first spell.
##   ECHOES      "recipes": a technique made a certain way comes close to a
##               bond's spell (never the same). Its card says "echoes Gale Lift".
##
## Every entry has an id (its key), a "name", one plain line ("says"), its
## numbers (at the top level; "levels" may change them at a part level:
## value()), and its "strain" (what it adds to a technique's strain). An
## entry with "placeholder": true isn't built yet: the tree shows it as a
## "Coming later" card that can't be chosen, so the game works at every stage.
##
## ============================ THE CONTENT CONTRACT ============================
## New pieces go in their own files under scripts/spells/, so several people
## can add spells at once without touching each other's files. Library loads
## every file in CONTENT (and any other .gd in that folder) when it starts
## (_static_init) and merges what each declares. A file may declare any of:
##
##   static var FORMS := {id: entry}        new Unbound forms (unbound_forms.gd)
##   static var EFFECTS := {id: entry}      new effects (unbound_effects.gd)
##   static var VARIATIONS := {id: entry}   new variations (rare)
##   static var ECHOES := [recipe, ...]     more echoes
##   static var TREE := {part: {level: ...}} the Unbound's tree layout (unbound_forms.gd only)
##   static var FORKS := {bond_id: {...}}   a tower's marks' fork alternatives
##
## and the code that runs them:
##
##   static func cast_spell(bond, sp: Dictionary, p) -> bool
##       a bond spell of this file ran (sp["type"] is one of yours); true if handled.
##   static func cast_variation(bond, sp: Dictionary, p, alt: Dictionary) -> bool
##       optional: your own way to run a step-3 variation (true if handled;
##       false falls back to the library's generic one, run_mark_variation()).
##   static func cast_form(form_id: String, t: Dictionary, p, power: float, run, sh: Dictionary, w: Dictionary) -> int
##       a new Unbound form: returns how many foes it touched, or -1 if it isn't yours.
##   static func hit_effect(effect_id: String, p, e, share: float, power: float, run) -> bool
##       a new effect on a struck foe (share: 1 lead, 0.5 second, 0.35 third).
##
## FORKS (one file per tower: scripts/spells/<tower>.gd), for each bond:
##   "change": {"name", "says"}           a name for today's step-3 change
##                                         (the step-3 choice's first side).
##   2: a SPELL dictionary, as in bonds.gd (id, name, type, learn: 2, desc,
##      steps), the other side of the step-2 fork.
##   3: a VARIATION choice: {"id", "variation": a VARIATIONS id, "name",
##      "desc", "steps": {3: {key: value}}} — the step-3 values replace
##      today's change's on the bond's first spell.
##   4: a SPELL, the other side of the step-4 fork (learn: 4).
##   Any of them with "placeholder": true (a name and a line, nothing to
##   run) shows as "Coming later" and can't be chosen; today's spell stays.
## A spell's "type" must be unique in the game; your file's cast_spell runs it.
## A bond's spell list, with the choices, comes from tree.gd bond_spells().
## Worked example: scripts/spells/gryphon.gd (Stormcaller: Ball Lightning at
## step 2, Forked or Lingering at step 3). Unbound example: Volley in
## scripts/spells/unbound_forms.gd.
## ==============================================================================

const Essence := preload("res://scripts/essence.gd")
const Secret := preload("res://scripts/secret.gd")

## The content files Library loads (scripts/spells/<name>.gd), in order.
const CONTENT := ["gryphon", "kraken", "wyvern", "manticore", "firebird", "chimera", "unbound_forms", "unbound_effects"]
const SPELLS_DIR := "res://scripts/spells/"
## How many variations one technique can carry.
const MAX_VARIATIONS := 1

## The forms. "class": "hit" (strikes foes), "move" (moves you, hits on the
## way or on landing), "self" (works on you), "shell" (a barrier on you),
## "mark" (one foe), "sight". "part": the body part that gives it. "opens":
## the part level it opens at (today's forms: 1). Numbers are at full (lead)
## strength, before the part's level (unbound.gd power).
static var FORMS := {
	"strike": {"name": "Strike", "part": "hand", "class": "hit", "says": "A blow of raw essence in front of you", "damage": 16.0, "reach": 50.0, "arc": 60.0, "strain": 0.0, "opens": 1, "levels": {}},
	"bolt": {"name": "Bolt", "part": "hand", "class": "hit", "says": "A bolt thrown where you aim", "damage": 12.0, "speed": 470.0, "range": 340.0, "strain": 0.0, "opens": 1, "levels": {}},
	"dash": {"name": "Dash", "part": "legs", "class": "move", "says": "You dash forward, untouchable, striking what you pass", "damage": 8.0, "dist": 130.0, "strain": 0.0, "opens": 1, "levels": {}},
	"leap": {"name": "Leap", "part": "legs", "class": "move", "says": "You leap where you aim and land hard on what's there", "damage": 14.0, "dist": 130.0, "radius": 56.0, "strain": 0.0, "opens": 1, "levels": {}},
	"shell": {"name": "Shell", "part": "back", "class": "shell", "says": "A shell around you that takes blows for you", "shield": 30.0, "duration": 5.0, "strain": 0.0, "opens": 1, "levels": {}},
	"push": {"name": "Push", "part": "back", "class": "hit", "says": "A burst that throws back every foe around you", "damage": 6.0, "radius": 85.0, "force": 380.0, "strain": 0.0, "opens": 1, "levels": {}},
	"shout": {"name": "Shout", "part": "throat", "class": "hit", "says": "A shout in a cone in front of you", "damage": 10.0, "reach": 135.0, "arc": 38.0, "strain": 0.0, "opens": 1, "levels": {}},
	"pull": {"name": "Pull", "part": "throat", "class": "hit", "says": "Drags the foes in a line in front of you to you", "damage": 5.0, "length": 210.0, "width": 54.0, "strain": 0.0, "opens": 1, "levels": {}},
	"mark": {"name": "Mark", "part": "brow", "class": "mark", "says": "Marks the foe you aim at: it takes 50% more damage for a while", "range": 320.0, "duration": 8.0, "strain": 0.0, "opens": 1, "levels": {}},
	"sight": {"name": "Sight", "part": "brow", "class": "sight", "says": "For a while you see every foe through walls and fog", "duration": 8.0, "near": 220.0, "strain": 0.0, "opens": 1, "levels": {}},
	"within": {"name": "Within", "part": "heart", "class": "self", "says": "Works on yourself", "duration": 8.0, "strain": 0.0, "opens": 1, "levels": {}},
}
## Today's forms, by part, in the builder's order (always owned by the Unbound).
const BASE_FORMS := {
	"hand": ["strike", "bolt"], "legs": ["dash", "leap"], "back": ["shell", "push"],
	"throat": ["shout", "pull"], "brow": ["mark", "sight"], "heart": ["within"],
}

## The effects. "kind": the essence. Each has a phrase for each kind of form
## ("hit", "self" on yourself, "shell", "near" around you; "move" for a
## move form where it differs) and its numbers at full (lead) strength:
##   burn     damage a second for burn_t seconds
##   slow     seconds a foe walks slower
##   reach    shapes reach (and dashes carry) this much farther; knock harder
##   stagger  seconds a foe is staggered
##   drag     iron pierces armour and pulls a foe toward you this hard
##   cut      this much more damage; bleed damage a second for 3 s
##   heal     health back for each foe hit
##   erode    this much more damage, ignores armour, erodes this a second for 4 s; costs you health
## "opens": essence of that kind pooled in the body for it to open (0: from the start).
static var EFFECTS := {
	"burn": {"kind": "fire", "name": "Burn", "says": "Burns what it hits", "strain": 0.0, "opens": 0, "levels": {},
		"hit": "burns what it hits", "self": "your strikes burn for a while", "shell": "bursts into flame when it breaks", "near": "burns the foes near you",
		"burn": 4.0, "burn_t": 3.0, "kindle": 5.0},
	"slow": {"kind": "water", "name": "Slow", "says": "Slows what it hits, or mends you", "strain": 0.0, "opens": 0, "levels": {},
		"hit": "slows what it hits", "self": "you heal steadily for a while", "shell": "mends you while it holds", "near": "slows the foes near you",
		"slow": 3.5, "mend": 24.0},
	"reach": {"kind": "air", "name": "Reach", "says": "Reaches farther and throws harder", "strain": 0.0, "opens": 0, "levels": {},
		"hit": "reaches farther and throws harder", "self": "you move faster and roll for less", "shell": "lasts longer", "near": "lets you see for longer",
		"reach": 0.4, "move": "carries you farther"},
	"stagger": {"kind": "stone", "name": "Stagger", "says": "Staggers what it hits", "strain": 0.0, "opens": 0, "levels": {},
		"hit": "staggers what it hits", "self": "you take less damage and can't be knocked back", "shell": "is much stronger", "near": "staggers the foes near you",
		"stagger": 0.7},
	"pierce": {"kind": "iron", "name": "Pierce", "says": "Pierces armour and drags foes to you", "strain": 0.0, "opens": 0, "levels": {},
		"hit": "pierces armour and drags foes toward you", "self": "your stamina comes back faster", "shell": "is stronger", "near": "drags the foes near you closer",
		"drag": 220.0},
	"cut": {"kind": "blade", "name": "Cut", "says": "Cuts deeper and leaves foes bleeding", "strain": 0.0, "opens": 0, "levels": {},
		"hit": "cuts deeper and leaves foes bleeding", "self": "your strikes hit harder for a while", "shell": "sharpens your strikes while it holds", "near": "cuts the foes near you",
		"cut": 0.35, "bleed": 3.0},
	"heal": {"kind": "life", "name": "Heal", "says": "Heals you for what it hits", "strain": 0.0, "opens": 0, "levels": {},
		"hit": "heals you for each foe it hits", "self": "heals you at once", "shell": "heals you as it rises", "near": "heals you for each foe near you",
		"heal": 3.0, "self_heal": 22.0},
	"erode": {"kind": "unmaking", "name": "Erode", "says": "Ignores armour and keeps eroding, at a cost in health", "strain": 0.0, "opens": 0, "levels": {},
		"hit": "ignores armour and keeps eroding, at a cost in your health", "self": "your strikes hit harder, at a cost in health", "shell": "is stronger, at a cost in health", "near": "erodes the foes near you, at a cost in health",
		"erode": 3.0, "more": 0.3, "toll": 3.0},
}
## Each essence's base effect (what it does in a technique today).
const BASE := {"fire": "burn", "water": "slow", "air": "reach", "stone": "stagger", "iron": "pierce", "blade": "cut", "life": "heal", "unmaking": "erode"}

## The variations. Numbers are multipliers unless named otherwise:
##   power   the cast's strength        windup  its wind-up
##   arc / radius / reach               its width and its reach (reach also
##                                      stretches range, distance and length)
##   copies, spread (degrees)           Split's copies and their fan
##   duration, radius, tick, power      Lingering's field
##   hop                                Chain's jump (px)
##   delay (s)                          Delayed and Echo
static var VARIATIONS := {
	"wide": {"name": "Wide", "says": "A wider arc or ring, a little weaker", "strain": 4.0, "arc": 1.5, "radius": 1.4, "power": 0.85, "levels": {}},
	"long": {"name": "Long", "says": "Reaches farther", "strain": 4.0, "reach": 1.4, "power": 1.0, "levels": {}},
	"quick": {"name": "Quick", "says": "Winds up faster, a little weaker", "strain": 4.0, "windup": 0.5, "power": 0.85, "levels": {}},
	"split": {"name": "Split", "says": "Three smaller copies fan out", "strain": 4.0, "copies": 3, "spread": 22.0, "power": 0.45, "levels": {}},
	"lingering": {"name": "Lingering", "says": "Leaves a field for a few seconds", "strain": 4.0, "duration": 3.0, "radius": 52.0, "tick": 0.5, "power": 0.15, "levels": {}},
	"chain": {"name": "Chain", "says": "Jumps to one more foe", "strain": 4.0, "hop": 170.0, "power": 0.6, "levels": {}},
	"delayed": {"name": "Delayed", "says": "Bursts a moment later, harder", "strain": 4.0, "delay": 0.6, "power": 1.45, "levels": {}},
	"mirrored": {"name": "Mirrored", "says": "Also casts behind you", "strain": 4.0, "power": 0.8, "levels": {}},
	"echo": {"name": "Echo", "says": "Casts again, weaker, a second later", "strain": 4.0, "delay": 1.0, "power": 0.6, "levels": {}},
	"charged": {"name": "Charged", "says": "A longer wind-up charges it, much harder", "strain": 4.0, "windup": 2.0, "power": 1.65, "levels": {}},
}
const VARIATION_ORDER := ["wide", "long", "quick", "split", "lingering", "chain", "delayed", "mirrored", "echo", "charged"]

## Echoes: a technique whose form and lead essence (and, if given, every one
## of "with" among its other essences) match comes close to a bond's spell.
static var ECHOES := [
	{"form": "shout", "lead": "air", "with": ["stone"], "spell": "gale_lift", "bond": "windwalker"},
	{"form": "bolt", "lead": "air", "with": ["iron"], "spell": "piercing_shot", "bond": "hunter"},
	{"form": "shell", "lead": "water", "with": ["stone"], "spell": "barrier", "bond": "warden"},
	{"form": "push", "lead": "water", "with": [], "spell": "tidal_surge", "bond": "tidecaller"},
	{"form": "bolt", "lead": "fire", "with": ["air"], "spell": "fireball", "bond": "flame_contractor"},
	{"form": "strike", "lead": "air", "with": ["fire"], "spell": "chain_lightning", "bond": "stormcaller"},
]

static var TEXT := {
	"coming": "Coming later",
	"coming_says": "Not written yet. It will come in a later update.",
	"echoes": "echoes %s",
	"variation": "Variation: %s",
	"no_variation": "No variation",
}

## Tower fork alternatives, merged from the content files: bond id -> FORKS entry.
static var MARK_FORKS := {}
## The Unbound's tree layout (unbound_forms.gd TREE): part -> {level: ...}.
static var TREE := {}
## Which content file runs what (spell type, form id, effect id -> Script).
static var _spell_src := {}
static var _form_src := {}
static var _effect_src := {}
static var _bond_src := {}
static var _sources: Array = []
static var _loaded := false


static func _static_init() -> void:
	register()


## Loads every content file and merges what it declares (safe to call again).
static func register() -> void:
	if _loaded:
		return
	_loaded = true
	var names: Array = CONTENT.duplicate()
	var dir := DirAccess.open(SPELLS_DIR)
	if dir != null:
		for f in dir.get_files():
			var n := f.trim_suffix(".remap").trim_suffix(".gdc").trim_suffix(".gd")
			if (f.ends_with(".gd") or f.ends_with(".gdc") or f.ends_with(".gd.remap")) and not n in names:
				names.append(n)
	for n in names:
		var path: String = SPELLS_DIR + n + ".gd"
		if not ResourceLoader.exists(path):
			continue
		var s: Script = load(path)
		if s == null:
			continue
		_sources.append(s)
		_merge(s)


static func _merge(s: Script) -> void:
	var consts := s.get_script_constant_map()
	for table in ["FORMS", "EFFECTS", "VARIATIONS"]:
		if table in s and not consts.has(table):
			var add: Dictionary = s.get(table)
			var into: Dictionary = {"FORMS": FORMS, "EFFECTS": EFFECTS, "VARIATIONS": VARIATIONS}[table]
			for id in add:
				into[id] = add[id]  # (the same dictionary: an edit to one shows in both)
				if table == "FORMS":
					_form_src[id] = s
				elif table == "EFFECTS":
					_effect_src[id] = s
	if "ECHOES" in s:
		ECHOES.append_array(s.get("ECHOES"))
	if "TREE" in s:
		var tr: Dictionary = s.get("TREE")
		for part in tr:
			TREE[part] = tr[part]
	if "FORKS" in s:
		var fk: Dictionary = s.get("FORKS")
		for bond_id in fk:
			MARK_FORKS[bond_id] = fk[bond_id]
			_bond_src[bond_id] = s
			for st in fk[bond_id]:
				var opt = fk[bond_id][st]
				if opt is Dictionary and opt.has("type"):
					_spell_src[String(opt["type"])] = s


# --- looking things up -------------------------------------------------------------

static func form(id: String) -> Dictionary:
	return FORMS.get(id, {})


static func effect(id: String) -> Dictionary:
	return EFFECTS.get(id, {})


static func variation(id: String) -> Dictionary:
	return VARIATIONS.get(id, {})


## True for a piece that is written and can be used (not a placeholder).
static func built(entry) -> bool:
	return entry is Dictionary and not entry.is_empty() and not bool(entry.get("placeholder", false))


## An entry's number at a part level (its "levels" may change it; the
## highest level at or below `level` that sets it wins).
static func value(entry: Dictionary, key: String, level := 1):
	var v = entry.get(key)
	var lv: Dictionary = entry.get("levels", {})
	var best := 0
	for l in lv:
		if int(l) <= level and int(l) >= best and (lv[l] as Dictionary).has(key):
			best = int(l)
			v = lv[l][key]
	return v


## The base effects, keyed by essence (technique.gd KINDS shares these
## dictionaries, so an edit to one is an edit to both).
static func base_effects() -> Dictionary:
	var out := {}
	for k in BASE:
		out[k] = EFFECTS[BASE[k]]
	return out


## Every form a part gives (today's, then the library's new ones), by "opens".
static func forms_of(part: String) -> Array:
	var out: Array = BASE_FORMS.get(part, []).duplicate()
	var more: Array = []
	for id in FORMS:
		if String(FORMS[id].get("part", "")) == part and not id in out:
			more.append(id)
	more.sort_custom(func(a, b): return int(FORMS[a].get("opens", 1)) < int(FORMS[b].get("opens", 1)))
	out.append_array(more)
	return out


## Every effect of an essence: its base first, then the rest by "opens".
static func effects_of(kind: String) -> Array:
	var out: Array = [BASE[kind]] if BASE.has(kind) else []
	var more: Array = []
	for id in EFFECTS:
		if String(EFFECTS[id].get("kind", "")) == kind and not id in out:
			more.append(id)
	more.sort_custom(func(a, b): return float(EFFECTS[a].get("opens", 0)) < float(EFFECTS[b].get("opens", 0)))
	out.append_array(more)
	return out


static func color(kind: String) -> Color:
	if kind in Secret.ORDER:
		return Secret.color(kind)
	return Essence.color(kind)


## The echo a technique comes close to: {"spell", "bond", "name"}, or {}.
static func echo_of(t: Dictionary) -> Dictionary:
	if not (t.get("kinds") is Array) or t["kinds"].is_empty():
		return {}
	var lead := String(t["kinds"][0])
	for r in ECHOES:
		if String(r.get("form", "")) != String(t.get("shape", "")) or String(r.get("lead", "")) != lead:
			continue
		var ok := true
		for k in r.get("with", []):
			if not k in t["kinds"].slice(1):
				ok = false
		if ok:
			return {"spell": r["spell"], "bond": r.get("bond", ""), "name": spell_name(String(r["spell"]))}
	return {}


## A bond spell's name by id (today's, or a fork alternative's).
static func spell_name(id: String) -> String:
	var B = load("res://scripts/bonds.gd")
	for bid in B.BONDS:
		for sp in B.BONDS[bid]["spells"]:
			if String(sp["id"]) == id:
				return String(sp["name"])
	for bid in MARK_FORKS:
		for st in MARK_FORKS[bid]:
			var o = MARK_FORKS[bid][st]
			if o is Dictionary and String(o.get("id", "")) == id:
				return String(o.get("name", id))
	return id


# --- running content -------------------------------------------------------------------

## A bond spell whose type bond.gd doesn't run: the content file that declared it does.
static func cast_spell(bond, sp: Dictionary, p) -> bool:
	var s = _spell_src.get(String(sp.get("type", "")))
	if s != null and s.has_method("cast_spell"):
		return bool(s.cast_spell(bond, sp, p))
	for src in _sources:
		if src.has_method("cast_spell") and bool(src.cast_spell(bond, sp, p)):
			return true
	return false


## A new Unbound form (-1 if no content file runs it).
static func cast_form(id: String, t: Dictionary, p, power: float, run, sh: Dictionary, w: Dictionary) -> int:
	var s = _form_src.get(id)
	if s != null and s.has_method("cast_form"):
		return int(s.cast_form(id, t, p, power, run, sh, w))
	return -1


## A new effect on a struck foe (false if no content file runs it).
static func hit_effect(id: String, p, e, share: float, power: float, run) -> bool:
	var s = _effect_src.get(id)
	if s != null and s.has_method("hit_effect"):
		return bool(s.hit_effect(id, p, e, share, power, run))
	return false


## A step-3 variation of a bond's first spell: the tower's own way, else the
## library's generic one. `cast_now` runs the spell itself (bond.gd _cast_type).
static func cast_mark_variation(bond, sp: Dictionary, p, alt: Dictionary) -> void:
	var s = _bond_src.get(String(bond.id))
	if s != null and s.has_method("cast_variation") and bool(s.cast_variation(bond, sp, p, alt)):
		return
	run_mark_variation(bond, p, String(alt.get("variation", "")))


## The generic variations on a bond's spell: Split, Mirrored, Echo and
## Delayed cast it again (at their power); the rest change its numbers
## (mark_stat) and cast it once.
static func run_mark_variation(bond, p, vid: String) -> void:
	var v := variation(vid)
	var FX = load("res://scripts/spell_fx.gd")
	match vid:
		"split":
			var spread := deg_to_rad(float(v.get("spread", 22.0)))
			var aim: Vector2 = p.aim
			for i in int(v.get("copies", 3)):
				p.aim = aim.rotated(spread * (i - (int(v.get("copies", 3)) - 1) * 0.5))
				bond.var_power = float(v.get("power", 0.45))
				bond._cast_type(p)
			p.aim = aim
			bond.var_power = 1.0
		"mirrored":
			bond.var_power = float(v.get("power", 0.8))
			bond._cast_type(p)
			var aim: Vector2 = p.aim
			p.aim = -aim
			bond._cast_type(p)
			p.aim = aim
			bond.var_power = 1.0
		"echo":
			bond._cast_type(p)
			var pw := float(v.get("power", 0.5))
			FX.later(p.main, float(v.get("delay", 1.0)), func():
				if is_instance_valid(p) and not p.dead:
					bond.var_power = pw
					bond._cast_type(p)
					bond.var_power = 1.0)
		"delayed":
			var pw := float(v.get("power", 1.35))
			FX.mark(p.main, p.global_position + p.aim * 60.0, float(v.get("delay", 0.6)), bond.color())
			FX.later(p.main, float(v.get("delay", 0.6)), func():
				if is_instance_valid(p) and not p.dead:
					bond.var_power = pw
					bond._cast_type(p)
					bond.var_power = 1.0)
		_:
			bond.var_power = float(v.get("power", 1.0)) if vid in ["wide", "quick", "charged"] else 1.0
			bond._cast_type(p)
			bond.var_power = 1.0


## A bond spell's number under a generic variation (Wide, Long, Quick,
## Charged change numbers; Chain adds one to a count).
static func mark_stat(vid: String, key: String, value):
	if value == null or not (value is float or value is int):
		return value
	var v := variation(vid)
	match vid:
		"wide":
			if key in ["arc", "radius", "width", "spread"]:
				return float(value) * float(v.get("arc" if key == "arc" else "radius", 1.4))
		"long":
			if key in ["reach", "range", "length", "travel", "hop", "speed"]:
				return float(value) * float(v.get("reach", 1.4))
		"quick", "charged":
			if key == "windup":
				return float(value) * float(v.get("windup", 1.0))
		"chain":
			if key in ["leaps", "targets", "count"]:
				return int(value) + 1
	return value
