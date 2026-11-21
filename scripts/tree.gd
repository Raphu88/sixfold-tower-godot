extends RefCounted
## THE TREE: the rules of how a climber grows, for both paths (the book's
## Tree section draws it: tree_view.gd). Every choice is for good.
##
## MARKS: each bond's tree is its steps, 1 to 12. Step 1 and step 5 are its spells. Steps 2 and 4 are
## FORKS: today's spell, or the tower's alternative (library.gd MARK_FORKS,
## from scripts/spells/<tower>.gd). Step 3 is a fork of VARIATIONS of the
## bond's first spell: today's change (named in FORKS "change"), or a
## library variation. A fork is READY once the mark reaches its step and
## both sides are written; until it's chosen, today's side is the one in use
## (so a climber who never chooses plays as before). Once chosen, the other
## side is gone for good. A side not written yet is a "Coming soon" card
## that can't be chosen; while it is, the fork isn't ready.
## Steps 6 to 12 (mark_ascent.gd, the same rhythm as the Unbound's levels):
## 6 the passive's rank IV, 7, 9 and 11 a fork of two upgrades, 8 the great
## spell's Apex+, 10 a second Transformation (a fork of two), 12 the Zenith.
## Those forks have no side in use until chosen: nothing changes until then.
##
## THE UNBOUND: one tree per body part, a node at the part levels that
## bring something (a level is 10 fill, 12 levels: unbound.gd): the minor
## ability at 3, the gift at 5, today's forms at 6 (half full: techniques
## open), a fork of two variations at 7, 9 and 11, a new form at 8 and 10,
## and at 12 (full) the capstone, with the signature of a pure part (the
## layout: library.gd TREE, from unbound_forms.gd).
## Effects open as each essence pools in the body (effect_open). A fork's
## passed side can still be learned once the part is SKIP_AFTER levels past
## it, for crystal essence (skipped_cost): the Unbound can come to own both.
##
## STATE (saved with the climber: profile.tree, state() fills it in):
##   "v"        VERSION (a save from before the tree is migrated: migrate();
##              one from version 1 is offered its step-3 re-pick: REPICK)
##   "marks"    bond id -> {step: option id}  (step 3: "change" is today's)
##   "unbound"  part -> {level: variation id}
##   "learned"  part -> ["level:variation id", ...]  (passed sides learned later)
##   "echoes"   spell ids an Unbound's technique has been found to echo
##   "repick"   bond id -> true: a step-3 choice made before the step-3
##              Transformations, which may be chosen again once, for free
##
## REPICK: the step-3 choice became a choice of two Transformations (version
## 2). Every mark whose save had already recorded a step-3 side keeps it (the
## same ids: today's side is side A, the other side B), and the book's Marks
## tab offers each of them one free re-pick (repick_offers, repick,
## repick_keep), until the climber chooses or keeps what they have.
##
## Functions take the profile; TreeRules.new(prof) gives the same as methods
## (available(node), choose(node, option), learn_skipped(node), owned(),
## is_fork_ready()...). A node id is "mark:<bond>:<step>" or "unbound:<part>:<level>".

const Library := preload("res://scripts/library.gd")
const Bonds := preload("res://scripts/bonds.gd")
const Unbound := preload("res://scripts/unbound.gd")
const Ascent := preload("res://scripts/mark_ascent.gd")

const FORK_STEPS := [2, 3, 4]
## The highest step a mark reaches, and the steps the tree shows.
const MAX_STEP := 12
const SHOWN_STEPS := 12
## Learning an Unbound fork's passed side: the part must be this many levels
## past the node, and it costs SKIP_COST[0] + SKIP_COST[1] x the node's level
## crystal essence (of any kinds, the biggest crystal first).
const SKIP_AFTER := 1
static var SKIP_COST := [20.0, 10.0]
## The option id of today's step-3 change.
const CHANGE := "change"
## The tree's state version: 2 since the step-3 Transformations (REPICK).
const VERSION := 2

static var TEXT := {
	"step": "Step %d",
	"level": "Level %d",
	"later": "Coming soon",
	"later_says": "This step isn't written yet.",
	"needs_step": "at step %d",
	"needs_level": "at level %d",
	"forms": "Your forms",
	"forms_says": "The shapes this part gives: %s.",
	"kinds": "One more essence",
	"kinds_says": "Techniques from this part combine %d essences.",
	"minor": "Minor ability",
	"minor_lead": "Its lead essence decides what it does: %s",
	"signature": "Signature: %s",
	"signature_says": "%s. Only when one essence fills this part all alone (%s).",
	"signature_none": "A pure part's signature",
	"signature_none_says": "When one essence alone fills this part, it brings a signature technique.",
	"gift": "Gift: %s",
	"capstone": "Capstone",
	"effects_need": "%d %s pooled in your body",
	"cost": "%d crystal essence",
	"change_says": "%s, transformed: %s.",
	"passive_also": "%s. At this step %s: %s",
	"repick_head": "Your marks have changed",
	"repick_says": "%s's step 3 is now a choice of two Transformations. You chose before they changed, so you may choose again, once, for free.",
	"repick_now": "yours now",
	"repick_take": "Take %s",
	"repick_keep": "Keep %s",
	"repick_done": "%s: %s is yours.",
}


var prof


func _init(p = null) -> void:
	prof = p


# --- the climber's state -------------------------------------------------------------

static func state(p) -> Dictionary:
	var st = p.get("tree")
	if not (st is Dictionary):
		st = {}
		p.set("tree", st)
	if not st.has("v"):
		st["v"] = VERSION
	for k in ["marks", "unbound", "learned", "repick"]:
		if not (st.get(k) is Dictionary):
			st[k] = {}
	if not (st.get("echoes") is Array):
		st["echoes"] = []
	if int(st["v"]) < 2:
		# (REPICK: every step-3 choice made before the Transformations may be chosen again, once)
		for bond_id in st["marks"]:
			var m = st["marks"][bond_id]
			if m is Dictionary and (m.has(3) or m.has("3")):
				st["repick"][String(bond_id)] = true
		st["v"] = VERSION
	return st


## An old save (from before the tree): every fork a mark has already
## reached is recorded as today's side, chosen.
static func migrate(p) -> void:
	var st := state(p)
	for part in p.bonds:
		var info: Dictionary = p.bonds[part]
		var step: int = p.step_for_xp(float(info.get("xp", 0.0)))
		for s in FORK_STEPS:
			if step >= s and mark_choice(p, String(info["id"]), s) == "":
				_record_mark(p, String(info["id"]), s, default_option(String(info["id"]), s))
	st["v"] = 1  # (a version-1 tree: state() offers its step-3 re-pick, REPICK)


static func _record_mark(p, bond_id: String, step: int, option: String) -> void:
	var marks: Dictionary = state(p)["marks"]
	var m: Dictionary = marks.get(bond_id, {})
	m[step] = option
	marks[bond_id] = m


# --- marks -------------------------------------------------------------------------------

## The side recorded at a bond's fork ("" if not chosen).
static func mark_choice(p, bond_id: String, step: int) -> String:
	var m = state(p)["marks"].get(bond_id, {})
	if m is Dictionary:
		if m.has(step):
			return String(m[step])
		if m.has(str(step)):
			return String(m[str(step)])
	return ""


## Every recorded choice of a bond: {step (int): option id} (bond.gd choices).
static func mark_choices(p, bond_id: String) -> Dictionary:
	var out := {}
	for s in FORK_STEPS + Ascent.FORKS:
		var c := mark_choice(p, bond_id, s)
		if c != "":
			out[s] = c
	return out


## Today's spell learned at a step (or the first spell, for steps 1 and 3).
static func base_spell(bond_id: String, step: int) -> Dictionary:
	if not Bonds.BONDS.has(bond_id):
		return {}
	var want := 1 if step == 3 else step
	for sp in Bonds.BONDS[bond_id]["spells"]:
		if int(sp["learn"]) == want:
			return sp
	return {}


## The tower's other side of a fork ({} if none at all).
static func fork_alt(bond_id: String, step: int) -> Dictionary:
	var f: Dictionary = Library.MARK_FORKS.get(bond_id, {})
	var o = f.get(step, f.get(str(step), {}))
	return o if o is Dictionary else {}


## Today's side of a fork: its spell id, or CHANGE at step 3.
static func default_option(bond_id: String, step: int) -> String:
	if step == 3:
		return CHANGE
	return String(base_spell(bond_id, step).get("id", ""))


## The step-3 variation in force ({} for today's change, or none).
static func alt_change(bond_id: String, choices: Dictionary) -> Dictionary:
	var c := String(choices.get(3, ""))
	if c == "" or c == CHANGE:
		return {}
	var alt := fork_alt(bond_id, 3)
	if Library.built(alt) and String(alt.get("id", "")) == c:
		return alt
	return {}


## The spells a bond knows at a step with these choices, in the order
## learned: a fork's chosen side (or today's, until it's chosen).
static func bond_spells(bond_id: String, step: int, choices: Dictionary) -> Array:
	var out: Array = []
	if not Bonds.BONDS.has(bond_id):
		return out
	for sp in Bonds.BONDS[bond_id]["spells"]:
		var learn := int(sp["learn"])
		if learn > step:
			continue
		if learn in [2, 4]:
			var c := String(choices.get(learn, ""))
			if c != "" and c != String(sp["id"]):
				var alt := fork_alt(bond_id, learn)
				if Library.built(alt) and String(alt.get("id", "")) == c:
					out.append(alt)
					continue
		out.append(sp)
	return out


## A spell's or change's option for a mark's node.
static func _mark_option(bond_id: String, step: int, which: String) -> Dictionary:
	var data: Dictionary = Bonds.BONDS[bond_id]
	if which == "base":
		if step == 3:
			var first := base_spell(bond_id, 1)
			var ch: Dictionary = Library.MARK_FORKS.get(bond_id, {}).get("change", {})
			var says := String(first.get("changes", {}).get(3, ""))
			return {"id": CHANGE, "kind": "variation", "name": String(ch.get("name", "%s, changed" % first.get("name", ""))),
				"says": TEXT["change_says"] % [first.get("name", ""), says] if says != "" else String(ch.get("says", "")),
				"built": true, "default": true, "spell": first, "color": data["color"]}
		var sp := base_spell(bond_id, step)
		return {"id": String(sp.get("id", "")), "kind": "spell", "name": String(sp.get("name", "")), "says": String(sp.get("desc", "")),
			"built": true, "default": true, "spell": sp, "color": data["color"]}
	var alt := fork_alt(bond_id, step)
	var built := Library.built(alt) and String(alt.get("id", "")) != ""
	var name := String(alt.get("name", ""))
	return {"id": String(alt.get("id", "later_%s_%d" % [bond_id, step])), "kind": "variation" if step == 3 else "spell",
		"name": name if name != "" else Library.TEXT["coming"], "says": String(alt.get("desc", alt.get("says", ""))) if built or String(alt.get("desc", "")) != "" else Library.TEXT["coming_says"],
		"built": built, "default": false, "spell": alt if step != 3 else base_spell(bond_id, 1), "variation": String(alt.get("variation", "")),
		"alt": alt, "color": data["color"]}


## At a step where the passive grows a rank (bonds.gd passive_rank), each
## option's words say so too.
static func _passive_says(bond_id: String, step: int, opts: Array) -> void:
	var rank: int = Bonds.passive_rank(step)
	if rank <= Bonds.passive_rank(step - 1) or Bonds.passive_line(bond_id, rank) == "":
		return
	var pname := String(Bonds.passive_at(bond_id, step)["name"])
	for o in opts:
		if bool(o.get("built", false)) and String(o.get("says", "")) != "":
			o["says"] = TEXT["passive_also"] % [String(o["says"]).trim_suffix("."), pname, Bonds.passive_line(bond_id, rank)]


## A marked part's nodes (none for an unmarked part).
static func mark_nodes(p, part: String) -> Array:
	var out: Array = []
	if not p.bonds.has(part):
		return out
	var info: Dictionary = p.bonds[part]
	var bond_id := String(info["id"])
	if not Bonds.BONDS.has(bond_id):
		return out
	var step: int = p.step_for_xp(float(info.get("xp", 0.0)))
	for s in range(1, SHOWN_STEPS + 1):
		var n := {"id": "mark:%s:%d" % [bond_id, s], "path": "mark", "part": part, "bond": bond_id, "at": s, "title": TEXT["step"] % s,
			"needs": TEXT["needs_step"] % s, "chosen": "", "options": []}
		if s >= Ascent.RANK4_STEP:
			_high_node(p, n, bond_id, s, step)
			out.append(n)
			continue
		if s > MAX_STEP:
			n["kind"] = "later"
			n["state"] = "later"
			n["options"] = [{"id": "later_%d" % s, "kind": "later", "name": TEXT["later"], "says": TEXT["later_says"], "built": false, "state": "placeholder", "color": Bonds.BONDS[bond_id]["color"]}]
			out.append(n)
			continue
		if not s in FORK_STEPS:
			n["kind"] = "spell"
			var o := _mark_option(bond_id, s, "base")
			o["state"] = "owned" if step >= s else "locked"
			_passive_says(bond_id, s, [o])
			n["options"] = [o]
			n["state"] = "owned" if step >= s else "locked"
			out.append(n)
			continue
		n["kind"] = "fork"
		var a := _mark_option(bond_id, s, "base")
		var b := _mark_option(bond_id, s, "alt")
		_passive_says(bond_id, s, [a, b])
		var c := mark_choice(p, bond_id, s)
		n["chosen"] = c
		if step < s:
			n["state"] = "locked"
			a["state"] = "locked"
			b["state"] = "locked" if b["built"] else "placeholder"
		elif c != "":
			n["state"] = "owned"
			for o in [a, b]:
				o["state"] = "owned" if String(o["id"]) == c else ("passed" if o["built"] else "placeholder")
		elif b["built"]:
			n["state"] = "ready"
			a["state"] = "in_use"
			b["state"] = "available"
		else:
			n["state"] = "owned"
			a["state"] = "owned"
			b["state"] = "placeholder"
		n["options"] = [a, b]
		out.append(n)
	return out


## A mark's node at steps 6 to 12 (mark_ascent.gd): rank IV, a fork of
## two upgrades (7, 9, 11) or Transformations (10), the Apex+ (8), the
## Zenith (12). Each option carries "help" (its hover help, entity_help.gd).
static func _high_node(p, n: Dictionary, bond_id: String, s: int, step: int) -> void:
	var col: Color = Bonds.BONDS[bond_id]["color"]
	var reached := step >= s
	if s == Ascent.RANK4_STEP:
		var pd: Dictionary = Bonds.BONDS[bond_id]["passive"]
		var r4 := Ascent.rank4(bond_id)
		var built := not r4.is_empty()
		n["kind"] = "passive"
		n["options"] = [{"id": "rank4_" + bond_id, "kind": "passive", "name": Ascent.TEXT["rank4"] % String(pd["name"]), "says": String(r4.get("says", "")) if built else Library.TEXT["coming_says"],
			"built": built, "state": ("owned" if reached else "locked") if built else "placeholder", "color": col, "help": "bud_rank4"}]
		n["state"] = ("owned" if reached else "locked") if built else "later"
		return
	if s in Ascent.FORKS:
		var sides := Ascent.sides(bond_id, s)
		var c := mark_choice(p, bond_id, s)
		n["kind"] = "fork"
		n["chosen"] = c
		var kind := "transform" if s == Ascent.TRANSFORM_STEP else "upgrade"
		var opts: Array = []
		for o in sides:
			var st := "locked"
			if reached:
				st = "available" if c == "" else ("owned" if String(o["id"]) == c else "passed")
			opts.append({"id": String(o["id"]), "kind": kind, "name": String(o["name"]), "says": String(o["says"]), "built": true, "state": st, "color": col,
				"help": "bud_transform" if kind == "transform" else "bud_upgrade"})
		n["options"] = opts
		if opts.size() < 2:
			n["state"] = "later"
		elif not reached:
			n["state"] = "locked"
		else:
			n["state"] = "ready" if c == "" else "owned"
		return
	var one := Ascent.single(bond_id, s)
	var zen := s == Ascent.ZENITH_STEP
	var built := not one.is_empty()
	n["kind"] = "zenith" if zen else "apex"
	n["options"] = [{"id": String(one.get("id", "later_%s_%d" % [bond_id, s])), "kind": "zenith" if zen else "apex", "name": String(one.get("name", Library.TEXT["coming"])),
		"says": String(one.get("says", Library.TEXT["coming_says"])), "built": built, "state": ("owned" if reached else "locked") if built else "placeholder", "color": col,
		"help": "bud_zenith" if zen else "bud_apex"}]
	n["state"] = ("owned" if reached else "locked") if built else "later"


## The marks whose step-3 choice may be chosen again, once, for free
## (REPICK): held on the body, at step 3 or more, with both sides written.
static func repick_offers(p) -> Array:
	var out: Array = []
	if Unbound.is_on(p):
		return out
	var flags: Dictionary = state(p)["repick"]
	for part in Bonds.PARTS:
		if not p.bonds.has(part):
			continue
		var bond_id := String(p.bonds[part]["id"])
		if flags.has(bond_id) and p.step_for_xp(float(p.bonds[part].get("xp", 0.0))) >= 3 and Library.built(fork_alt(bond_id, 3)):
			out.append(bond_id)
	return out


## The two sides of a mark's step-3 choice, as the tree's options ({id,
## name, says, ...}: side A first).
static func repick_sides(bond_id: String) -> Array:
	return [_mark_option(bond_id, 3, "base"), _mark_option(bond_id, 3, "alt")]


## Uses a mark's free re-pick: `option` (CHANGE or the other side's id)
## becomes its step-3 choice, and the offer is gone. False if it can't.
static func repick(p, bond_id: String, option: String) -> bool:
	if not bond_id in repick_offers(p):
		return false
	if not option in repick_sides(bond_id).map(func(o): return String(o["id"])):
		return false
	_record_mark(p, bond_id, 3, option)
	state(p)["repick"].erase(bond_id)
	return true


## Keeps a mark's step-3 choice as it is: the offer is gone.
static func repick_keep(p, bond_id: String) -> void:
	state(p)["repick"].erase(bond_id)


# --- the Unbound ---------------------------------------------------------------------------

static func _layout(part: String) -> Dictionary:
	return Library.TREE.get(part, {})


## The variation recorded at an Unbound fork ("" if not chosen).
static func unbound_choice(p, part: String, level: int) -> String:
	var u = state(p)["unbound"].get(part, {})
	if u is Dictionary:
		if u.has(level):
			return String(u[level])
		if u.has(str(level)):
			return String(u[str(level)])
	return ""


static func _learned(p, part: String) -> Array:
	var l = state(p)["learned"].get(part, [])
	return l if l is Array else []


## A part's nodes for the Unbound.
static func unbound_nodes(p, part: String) -> Array:
	var out: Array = []
	var lv: int = Unbound.level(p, part)
	var lay := _layout(part)
	var col: Color = Library.color(String(Unbound.PART_KIND.get(part, "fire")))
	for L in range(1, Unbound.MAX_LEVEL + 1):
		var n := {"id": "unbound:%s:%d" % [part, L], "path": "unbound", "part": part, "at": L, "title": TEXT["level"] % L,
			"needs": TEXT["needs_level"] % L, "chosen": "", "options": []}
		var reached := lv >= L
		var spec: Dictionary = lay.get(L, lay.get(str(L), {}))
		if L == Unbound.MINOR_LEVEL:
			n["kind"] = "minor"
			n["options"] = [{"id": "minor_" + part, "kind": "kinds", "name": TEXT["minor"], "says": Unbound.minor_text(p, part),
				"built": true, "state": "owned" if reached else "locked", "color": col}]
			n["state"] = "owned" if reached else "locked"
		elif L == Unbound.TECH_LEVEL:
			n["kind"] = "forms"
			for f in Library.BASE_FORMS.get(part, []):
				var fe := Library.form(f)
				n["options"].append({"id": f, "kind": "form", "form": f, "name": fe["name"], "says": fe["says"], "built": true, "state": "owned" if reached else "locked", "color": col})
			n["state"] = "owned" if reached else "locked"
		elif L == Unbound.GIFT_LEVEL:
			n["kind"] = "gift"
			var g: Dictionary = Unbound.GIFTS.get(part, {})
			n["options"] = [{"id": "gift_" + part, "kind": "gift", "name": TEXT["gift"] % g.get("name", ""), "says": String(g.get("desc", "")).left(1).to_upper() + String(g.get("desc", "")).substr(1) + ".",
				"built": true, "state": "owned" if reached else "locked", "color": col}]
			n["state"] = "owned" if reached else "locked"
		elif spec.has("fork"):
			n["kind"] = "fork"
			var c := unbound_choice(p, part, L)
			n["chosen"] = c
			var learned := _learned(p, part)
			var opts: Array = []
			for vid in spec["fork"]:
				var v := Library.variation(String(vid))
				var o := {"id": String(vid), "kind": "variation", "variation": String(vid), "name": String(v.get("name", vid)), "says": String(v.get("says", "")),
					"built": Library.built(v), "color": col, "strain": float(v.get("strain", 0.0))}
				if not o["built"]:
					o["state"] = "placeholder"
				elif not reached:
					o["state"] = "locked"
				elif c == "":
					o["state"] = "available"
				elif String(vid) == c or ("%d:%s" % [L, vid]) in learned:
					o["state"] = "owned"
				elif lv >= L + SKIP_AFTER:
					o["state"] = "learnable"
					o["cost"] = skipped_cost(L)
				else:
					o["state"] = "passed"
				opts.append(o)
			n["options"] = opts
			if not reached:
				n["state"] = "locked"
			elif c == "" and opts.any(func(o): return o["state"] == "available"):
				n["state"] = "ready"
			else:
				n["state"] = "owned"
		elif spec.has("form"):
			n["kind"] = "form"
			var fid := String(spec["form"])
			var fe := Library.form(fid)
			var built := Library.built(fe)
			n["options"] = [{"id": fid, "kind": "form", "form": fid, "name": String(fe.get("name", fid)), "says": String(fe.get("says", "")), "built": built,
				"state": ("placeholder" if not built else ("owned" if reached else "locked")), "color": col}]
			n["state"] = "owned" if reached and built else ("locked" if not reached else "later")
		elif spec.has("capstone") or L == Unbound.MAX_LEVEL:
			n["kind"] = "capstone"
			var cap: Dictionary = spec.get("capstone", {"placeholder": true})
			var built := Library.built(cap)
			var cname := String(cap.get("name", ""))
			n["options"] = [{"id": "cap_" + part, "kind": "capstone", "name": cname if cname != "" else Library.TEXT["coming"],
				"says": String(cap.get("says", "")) if String(cap.get("says", "")) != "" else Library.TEXT["coming_says"], "built": built,
				"state": ("placeholder" if not built else ("owned" if reached else "locked")), "color": col}]
			n["options"].append(_signature_option(p, part, col))
			n["state"] = "later" if not built else ("owned" if reached else "locked")
		else:
			continue  # (levels 1, 2 and 4 bring nothing of their own: the part fills on)
		out.append(n)
	return out


## The signature bud on a part's last node: the signature of the essence
## that leads it (or its natural one), owned while one essence alone fills it.
static func _signature_option(p, part: String, col: Color) -> Dictionary:
	var kind := Unbound.primary(p, part)
	if kind == "":
		kind = String(Unbound.PART_KIND.get(part, ""))
	var sig: Dictionary = Unbound.SIGNATURES.get("%s:%s" % [part, kind], {})
	if sig.is_empty():
		return {"id": "sig_" + part, "kind": "capstone", "name": TEXT["signature_none"], "says": TEXT["signature_none_says"], "built": false, "state": "placeholder", "color": col}
	var fid := String(sig.get("form", ""))
	var built := fid != "" and Library.built(Library.form(fid))
	var mine := not Unbound.signature(p, part).is_empty()
	var o := {"id": "sig_" + part, "kind": "form" if built else "capstone", "name": TEXT["signature"] % String(sig["name"]),
		"says": TEXT["signature_says"] % [String(sig.get("says", "")), _kind_name(kind)] if built else Library.TEXT["coming_says"],
		"built": built, "state": ("placeholder" if not built else ("owned" if mine else "locked")), "color": Library.color(kind)}
	if built:
		o["form"] = fid
	return o


## Pooled essence of a kind in the whole body (the six parts' raw density of it).
static func pooled(p, kind: String) -> float:
	var t := 0.0
	for part in p.part_density:
		t += float(p.part_density[part].get(kind, 0.0))
	if kind == p.path:
		t += float(p.flow)
	return t


## True once an effect is open to the Unbound (enough of its essence pooled).
static func effect_open(p, id: String) -> bool:
	var fx := Library.effect(id)
	if fx.is_empty() or not Library.built(fx):
		return false
	if not Unbound.is_on(p):
		return false
	return pooled(p, String(fx.get("kind", ""))) >= float(fx.get("opens", 0))


## The effects shown on a part's tree: those of the essences that pool there
## naturally (and the path's essence on the heart). Each {id, kind, name,
## says, built, state ("owned", "locked", "placeholder"), needs}.
static func effect_rows(p, part: String) -> Array:
	var kinds: Array = []
	for k in Unbound.NATURAL:
		if Unbound.NATURAL[k] == part:
			kinds.append(k)
	if part == "heart" and p.path in ["life", "unmaking"]:
		kinds.append(p.path)
	var out: Array = []
	for k in kinds:
		for id in Library.effects_of(k):
			var fx := Library.effect(id)
			var built := Library.built(fx)
			out.append({"id": id, "kind": k, "name": String(fx.get("name", id)), "says": String(fx.get("says", "")), "built": built,
				"state": "placeholder" if not built else ("owned" if effect_open(p, id) else "locked"),
				"needs": TEXT["effects_need"] % [int(fx.get("opens", 0)), _kind_name(k)], "color": Library.color(k)})
	return out


static func _kind_name(k: String) -> String:
	var T = load("res://scripts/technique.gd")
	return T.display(k)


## The forms an Unbound owns for a part (today's, and those opened by level).
static func owned_forms(p, part: String) -> Array:
	var out: Array = Library.BASE_FORMS.get(part, []).duplicate()
	if not Unbound.is_on(p):
		return out
	var lv: int = Unbound.level(p, part)
	var lay := _layout(part)
	for L in lay:
		var spec = lay[L]
		if spec is Dictionary and spec.has("form") and lv >= int(L) and Library.built(Library.form(String(spec["form"]))):
			out.append(String(spec["form"]))
	# A pure, full part's signature (unbound.gd SIGNATURES), once it's written.
	var sig := Unbound.signature(p, part)
	if sig.has("form") and Library.built(Library.form(String(sig["form"]))) and not String(sig["form"]) in out:
		out.append(String(sig["form"]))
	return out


## Every variation an Unbound owns (chosen or learned, on any part's tree).
static func owned_variations(p) -> Array:
	var out: Array = []
	if not Unbound.is_on(p):
		return out
	for part in Unbound.PARTS:
		for n in unbound_nodes(p, part):
			if n["kind"] == "fork":
				for o in n["options"]:
					if o["state"] == "owned" and not o["id"] in out:
						out.append(o["id"])
	return out


## What learning a passed fork side at this level costs.
static func skipped_cost(level: int) -> int:
	return int(float(SKIP_COST[0]) + float(SKIP_COST[1]) * float(level))


# --- every node -----------------------------------------------------------------------------

## A part's tree for this climber (marks or the Unbound).
static func nodes(p, part: String) -> Array:
	return unbound_nodes(p, part) if Unbound.is_on(p) else mark_nodes(p, part)


## A node by id ({} if there's none).
static func node(p, node_id: String) -> Dictionary:
	var bits := node_id.split(":")
	if bits.size() != 3:
		return {}
	var part := ""
	if bits[0] == "unbound":
		part = bits[1]
	else:
		for pt in p.bonds:
			if String(p.bonds[pt]["id"]) == bits[1]:
				part = pt
	if part == "":
		return {}
	for n in nodes(p, part):
		if n["id"] == node_id:
			return n
	return {}


## The options of a node that can be chosen now (a ready fork's written sides).
static func available(p, node_id: String) -> Array:
	var n := node(p, node_id)
	if n.is_empty() or n.get("state", "") != "ready":
		return []
	return n["options"].filter(func(o): return o["built"] and o["state"] in ["available", "in_use"]).map(func(o): return o["id"])


## Chooses a side of a ready fork, for good. False if it can't be chosen.
static func choose(p, node_id: String, option_id: String) -> bool:
	if not option_id in available(p, node_id):
		return false
	var n := node(p, node_id)
	if n["path"] == "mark":
		_record_mark(p, String(n["bond"]), int(n["at"]), option_id)
	else:
		var u: Dictionary = state(p)["unbound"]
		var m: Dictionary = u.get(n["part"], {})
		m[int(n["at"])] = option_id
		u[n["part"]] = m
	return true


## True if a passed side can be learned now (the Unbound only).
static func can_learn_skipped(p, node_id: String, option_id: String) -> bool:
	var n := node(p, node_id)
	if n.is_empty() or n["path"] != "unbound":
		return false
	for o in n["options"]:
		if o["id"] == option_id and o["state"] == "learnable":
			return p.crystals_held() >= float(o.get("cost", 0))
	return false


## Learns a passed side (the Unbound only), paying its crystal essence.
## Returns what was paid ({kind: amount}), or {} if it couldn't.
static func learn_skipped(p, node_id: String, option_id: String) -> Dictionary:
	if not can_learn_skipped(p, node_id, option_id):
		return {}
	var n := node(p, node_id)
	var paid: Dictionary = p.spend_any(float(skipped_cost(int(n["at"]))))
	if paid.is_empty():
		return {}
	var learned: Dictionary = state(p)["learned"]
	var l: Array = learned.get(n["part"], [])
	l.append("%d:%s" % [int(n["at"]), option_id])
	learned[n["part"]] = l
	return paid


## Everything chosen or opened: spell ids, variation ids and form ids.
static func owned(p) -> Array:
	var out: Array = []
	for part in Bonds.PARTS:
		for n in nodes(p, part):
			for o in n["options"]:
				if o.get("state", "") in ["owned", "in_use"] and o["built"] and not o["id"] in out:
					out.append(o["id"])
	return out


## True if a fork is ready to choose (on one part, or anywhere).
static func is_fork_ready(p, part := "") -> bool:
	return not ready_forks(p, part).is_empty()


## The ready forks' node ids (on one part, or anywhere).
static func ready_forks(p, part := "") -> Array:
	var out: Array = []
	for pt in Bonds.PARTS:
		if part != "" and pt != part:
			continue
		for n in nodes(p, pt):
			if n["state"] == "ready":
				out.append(n["id"])
	return out


## An echo found (a technique comes close to a bond's spell): remembered.
## True the first time.
static func note_echo(p, t: Dictionary) -> bool:
	var e := Library.echo_of(t)
	if e.is_empty():
		return false
	var list: Array = state(p)["echoes"]
	if e["spell"] in list:
		return false
	list.append(e["spell"])
	return true


# --- the same, as methods on a climber -------------------------------------------------------

func get_nodes(part: String) -> Array:
	return nodes(prof, part)


func get_node(node_id: String) -> Dictionary:
	return node(prof, node_id)


func options_now(node_id: String) -> Array:
	return available(prof, node_id)


func choose_now(node_id: String, option_id: String) -> bool:
	return choose(prof, node_id, option_id)


func learn_now(node_id: String, option_id: String) -> Dictionary:
	return learn_skipped(prof, node_id, option_id)


func owned_now() -> Array:
	return owned(prof)


func fork_ready(part := "") -> bool:
	return is_fork_ready(prof, part)
