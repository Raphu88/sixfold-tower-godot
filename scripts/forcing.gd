extends RefCounted
## FORCING essence into a full mark or Node. Every word and number of it is
## here (the moments are in main.gd force_crystal / force_tincture, the
## buttons on the Crystals and tinctures page, pour_page.gd).
##
## Eating a crystal or drinking a tincture only fills what a mark or a Node
## can take (essence_flow.gd): a mark takes what refills its use, a Node
## what it has room for; what can't go in stays a crystal. FORCING pushes
## essence in anyway, past full: it STRETCHES the part (a mark deepens, a
## Node's size grows) at FORCE "cost" times the essence its use would take
## for the same growth (a mark: what a stair spends to deepen it by use,
## its use refilled and the deepening paid, mark_use.gd USE; a Node: what
## its refilled use costs, unbound.gd GROW_COST). Its own kind pays fully,
## any other kind a third (the one rule). Using your power stays the main
## way to grow: forcing helps a neglected part catch up, never beats playing.
##
## STRAIN. Every forced essence adds FORCE "strain" strain to that part
## (any kind alike). No cap a climb: the strain is the brake. It fades
## FORCE "fade_stair" at each stair and FORCE "fade_climb" as a new climb
## starts, so it is gone over a climb or two (an Unbound's Broad Back fades
## it faster, as it does their casting strain). Marks keep it on their
## record (profile.bonds part -> "strain"); the Unbound's Nodes in
## unbound.gd state "strain", where it is the floor under the Node's
## casting strain meter in a climb (unbound_run.gd): one meter, not two.
##
## THE LADDER (the marks' own burn steps, nothing new to learn), by strain:
##   strained   above 0: that part refills a little slower (FORCE "slow":
##              a mark's pool, a Node's technique) until it fades
##   burned     LADDER "burned": a mark is burned, as overdrawing it burns
##              it (its body part weaker; overdraw again and it seizes); a
##              Node's casting strain never falls below it, so its casts
##              push it to erupting sooner
##   paralyzed  LADDER "paralyzed": a mark is paralyzed (it can't be cast;
##              holding its button still forces a cast that burns it out);
##              a Node is dark (nothing from it can be cast)
##   past it    LADDER "break": a mark BURNS OUT (mark_use.gd burn_out: dark
##              for climbs, shallower, counted as a slip toward a Maker; the
##              guardians frown on it), a Node CRACKS (it loses FORCE
##              "crack" of its size, never falling back asleep, and keeps
##              FORCE "crack_strain")
## In a climb a mark already burned or paralyzed by overdrawing starts the
## push from that step. The strain applies at once, mid-fight.
##
## WARN FIRST: forcing is its own button ("Force it", beside Eat, shown only
## when the part is full), and it always asks first (menu.gd ask), saying
## where it would leave the part.

const Bonds := preload("res://scripts/bonds.gd")
const MarkUse := preload("res://scripts/mark_use.gd")
const Unbound := preload("res://scripts/unbound.gd")
const Essence := preload("res://scripts/essence.gd")

## "cost": forced growth costs this many times the essence use-growth would;
## "strain": strain each forced essence adds; "slow": how much slower a
## strained part refills (a share); "fade_stair" / "fade_climb": strain gone
## at each stair / as a climb starts; "crack": size a cracked Node loses;
## "crack_strain": the strain it keeps after cracking.
## (A crystal forced, 10 essence, strains 12: three stay short of burned.
## A climber who force-eats every crystal they get, short of burned
## (tests/progression_model.gd run / run_unbound with `force`), stays in the
## pace bands: a typical first mark still reaches step 12 after 22 climbs
## (summiting every climb, 8 against 9), the main Node level 12 after 23
## (unchanged), and all six Nodes no sooner. Held by
## tests/parts/progression.gd and unbound_cup.gd; the rest by forcing.gd.)
static var FORCE := {"cost": 4.0, "strain": 1.2, "slow": 0.25, "fade_stair": 4.0, "fade_climb": 20.0, "crack": 8.0, "crack_strain": 40.0}
## The ladder's steps, in strain: burned from "burned", paralyzed from
## "paralyzed", and a push that reaches "break" burns a mark out or cracks a Node.
static var LADDER := {"burned": 40.0, "paralyzed": 70.0, "break": 100.0}

const STEADY := 0
const STRAINED := 1
const BURNED := 2
const PARALYZED := 3
const BROKEN := 4

static var TEXT := {
	# The steps, in words.
	"rungs": ["steady", "strained", "burned", "paralyzed"],
	"Rungs": ["Steady", "Strained", "Burned", "Paralyzed"],
	# The page's buttons (pour_page.gd).
	"force": "Force it",
	"force_mark": "Force it: %s",
	"force_state": "%s  ·  %s",
	"force_head": "Full: Force it pushes past full (%dx the essence, and strain)",
	"tincture_force": "Force",
	# The pop-up (menu.gd ask).
	"ask_title": "Force it?",
	"ask_confirm": "Force it",
	"ask_mark": "Force %d %s essence into your %s mark, past full? It deepens it a little, at %d times the essence its use would take.",
	"ask_node": "Force %d %s essence into your %s, past full? It stretches it from size %s to %s, at %d times the essence its use would take.",
	"ask_other": "It isn't its own kind: it does a third as much.",
	"to_strained": "This leaves your %s Strained: it refills a little slower until the strain fades at the stairs.",
	"to_burned": "This pushes your %s to Burned: its body part is weaker, and overdrawing it seizes it.",
	"to_burned_node": "This pushes your %s to Burned: its strain stays high, so its casts erupt sooner.",
	"to_paralyzed": "This pushes your %s to Paralyzed: it can't be cast until the strain fades.",
	"to_paralyzed_node": "This pushes your %s to Paralyzed: it goes dark, and nothing from it can be cast until the strain fades.",
	"stays": "Your %s stays %s, and the strain grows.",
	"to_burnout": "This pushes your %s past Paralyzed: the mark BURNS OUT. Dark for this climb and the next %d, shallower, and it counts as a slip toward a Maker. The guardians frown on a damaged mark.",
	"to_crack": "This pushes your %s past Paralyzed: it CRACKS and loses %s of its size.",
	"fades": "Strain fades a little at each stair, and more as a climb starts.",
	# What forcing did (the toast, the feed).
	"forced_mark": "Forced %d %s essence into your %s mark: it deepens, strained",
	"forced_node": "Forced %d %s essence into your %s: size %s",
	"now": "Your %s is %s",
	"cracked": "Your %s cracks: it loses %s of its size (size %s)",
	"crack_title": "NODE CRACKED",
	# The stairs.
	"eased": "The strain in your %s fades",
	"eased_to": "The strain in your %s eases: %s now",
	"still": "Your %s is still %s from forcing",
}


# --- strain --------------------------------------------------------------------------------

## The strain forcing left in a part (0 when none).
static func strain(prof, part: String) -> float:
	if prof == null:
		return 0.0
	if Unbound.is_on(prof):
		return float(Unbound.state(prof).get("strain", {}).get(part, 0.0))
	return float(prof.bonds.get(part, {}).get("strain", 0.0))


static func set_strain(prof, part: String, s: float) -> void:
	if prof == null:
		return
	s = maxf(0.0, s)
	if Unbound.is_on(prof):
		var st: Dictionary = Unbound.state(prof)
		if not (st.get("strain") is Dictionary):
			st["strain"] = {}
		if s <= 0.0001:
			st["strain"].erase(part)
		else:
			st["strain"][part] = s
	elif prof.bonds.has(part):
		if s <= 0.0001:
			prof.bonds[part].erase("strain")
		else:
			prof.bonds[part]["strain"] = s


## The step a strain stands on (STEADY to PARALYZED; BROKEN at "break").
static func rung_for(s: float) -> int:
	if s >= float(LADDER["break"]) - 0.0001:
		return BROKEN
	if s >= float(LADDER["paralyzed"]) - 0.0001:
		return PARALYZED
	if s >= float(LADDER["burned"]) - 0.0001:
		return BURNED
	if s > 0.0001:
		return STRAINED
	return STEADY


## The least strain on a step (what a mark already burned by overdrawing counts as).
static func rung_floor(r: int) -> float:
	match r:
		PARALYZED:
			return float(LADDER["paralyzed"])
		BURNED:
			return float(LADDER["burned"])
	return 0.0


## A mark's burn step in a climb, from overdrawing (its bond on the climber):
## STEADY on the train, for a Node, or with no such bond.
static func runtime_rung(main, part: String) -> int:
	if main == null or bool(main.get("on_train")):
		return STEADY
	var p = main.get("player")
	if p == null or not is_instance_valid(p) or not p.bonds.has(part):
		return STEADY
	var b = p.bonds[part]
	if "tech" in b:
		return STEADY
	if b.paralyzed:
		return PARALYZED
	if b.burned:
		return BURNED
	return STEADY


## The step a part stands on now: its strain's, or (in a climb) a mark's
## own burn from overdrawing, whichever is higher.
static func rung(prof, part: String, main = null) -> int:
	return maxi(rung_for(strain(prof, part)), runtime_rung(main, part))


## A step's word ("burned"); `cap` for "Burned".
static func rung_word(r: int, cap := false) -> String:
	var words: Array = TEXT["Rungs" if cap else "rungs"]
	return String(words[clampi(r, 0, words.size() - 1)])


## A part's name for the words: "Hand" (a marked part), "Hand Node" (the Unbound).
static func part_name(prof, part: String) -> String:
	if Unbound.is_on(prof):
		return Unbound.node_name(part)
	return String(Bonds.PART_NAMES.get(part, part))


# --- full, and what forcing would do -------------------------------------------------------------

## True when `part` can be forced with `kind`: it's full (eating would
## leave it nothing to take) but not grown as far as it goes. A marked
## climber's lit mark with no use waiting to be refilled, below its last
## step; an Unbound's awake Node with no room for the kind and no use
## waiting, below its biggest size. Never on the bondless first climb.
static func can_force(prof, part: String, kind: String) -> bool:
	if prof == null or not part in Bonds.PARTS or not Essence.KINDS.has(kind):
		return false
	if Unbound.is_on(prof):
		if not Unbound.awake(prof, part) or Unbound.sealed(prof, part):
			return false
		if Unbound.size(prof, part) >= Unbound.Core.CAP - 0.0001:
			return false
		return Unbound.take_limit(prof, part, kind) <= 0.0001 and Unbound.used(prof, part) <= 0.0001
	if not prof.bonds.has(part) or MarkUse.dark(prof, part):
		return false
	var top := float(prof.STEP_XP[prof.STEP_XP.size() - 1])
	return float(prof.bonds[part]["xp"]) < top - 0.0001 and MarkUse.used(prof, part) <= 0.0001


## The parts a crystal of `kind` could be forced into: the Unbound, the
## Node it flows to; the marked, each full mark.
static func targets(prof, kind: String) -> Array:
	if prof == null:
		return []
	if Unbound.is_on(prof):
		var at := Unbound.part_for(prof, kind)
		return [at] if can_force(prof, at, kind) else []
	return Bonds.PARTS.filter(func(p): return can_force(prof, p, kind))


## Banked essence a mark's use spends for each 1 depth it grows (its use
## refilled, and the deepening paid: mark_use.gd USE).
static func mark_use_cost() -> float:
	var d := maxf(0.0001, float(MarkUse.USE["deepen"]))
	return (1.0 + d * float(MarkUse.USE["cost"])) / d


## How far `essence` of `kind` forced into a mark deepens it (before a
## faint mark's debt; not past its last step).
static func mark_growth(prof, part: String, kind: String, essence: float) -> float:
	if not prof.bonds.has(part):
		return 0.0
	var b: Dictionary = prof.bonds[part]
	var top := float(prof.STEP_XP[prof.STEP_XP.size() - 1])
	var debt := float(b.get("debt", 0.0)) if bool(b.get("faint", false)) else 0.0
	var g: float = essence * MarkUse.rate(prof, part, kind) * prof.body_drag() / maxf(0.0001, float(FORCE["cost"]) * mark_use_cost())
	return minf(g, maxf(0.0, top - float(b["xp"])) + debt)


## The size a Node would reach with `essence` of `kind` forced into it.
static func node_size_after(prof, part: String, kind: String, essence: float) -> float:
	var s := Unbound.size(prof, part)
	var left := essence * Unbound.pay_rate(prof, part, kind)
	var k := maxf(0.0001, float(FORCE["cost"]))
	for _i in 64:
		if left <= 0.0001 or s >= Unbound.Core.CAP - 0.0001:
			break
		var band := Unbound.cost_band(s)
		var cost := float(Unbound.GROW_COST[band]) * k
		var to_next := maxf(0.0001, float(band + 1) * Unbound.COST_BAND - s)
		var g := minf(left * Unbound.COST_BAND / cost, to_next)
		s += g
		left -= g * cost / Unbound.COST_BAND
	return minf(s, Unbound.Core.CAP)


## What forcing `essence` of `kind` into `part` would do, without doing it:
## {"before", "after" (steps: STEADY..BROKEN), "strain" (after), "growth"
## (a mark's depth, or a Node's size gained), "size" (a Node's after), "own"
## (its own kind), "node" (true for the Unbound)}.
static func preview(prof, part: String, kind: String, essence: float, main = null) -> Dictionary:
	var before := rung(prof, part, main)
	var s0 := maxf(strain(prof, part), rung_floor(runtime_rung(main, part)))
	var s1 := s0 + maxf(0.0, essence) * float(FORCE["strain"])
	var node := Unbound.is_on(prof)
	var out := {"before": before, "after": maxi(before, rung_for(s1)), "strain": s1, "node": node, "growth": 0.0, "size": 0.0, "own": true}
	if node:
		var after := node_size_after(prof, part, kind, essence)
		out["size"] = after
		out["growth"] = after - Unbound.size(prof, part)
		out["own"] = Unbound.pay_rate(prof, part, kind) >= 0.999
	else:
		out["growth"] = mark_growth(prof, part, kind, essence)
		out["own"] = MarkUse.rate(prof, part, kind) >= 0.999
	return out


## The pop-up's words: what forcing would grow, and where it leaves the part.
static func ask_text(prof, part: String, kind: String, essence: float, main = null) -> String:
	var pv := preview(prof, part, kind, essence, main)
	var name := part_name(prof, part)
	var lines: Array = []
	var k := int(round(float(FORCE["cost"])))
	if bool(pv["node"]):
		lines.append(String(TEXT["ask_node"]) % [int(essence), Essence.display(kind), name, Unbound._num(Unbound.size(prof, part)), Unbound._num(float(pv["size"])), k])
	else:
		var bond := String(Bonds.BONDS.get(String(prof.bonds[part]["id"]), {}).get("name", name))
		lines.append(String(TEXT["ask_mark"]) % [int(essence), Essence.display(kind), bond, k])
	if not bool(pv["own"]):
		lines.append(String(TEXT["ask_other"]))
	lines.append(outcome_text(prof, part, int(pv["before"]), int(pv["after"])))
	if int(pv["after"]) < BROKEN:
		lines.append(String(TEXT["fades"]))
	return " ".join(lines)


## Where a push leaves the part, in a line ("This pushes your Hand to Burned...").
static func outcome_text(prof, part: String, before: int, after: int) -> String:
	var name := part_name(prof, part)
	var node := Unbound.is_on(prof)
	if after >= BROKEN:
		if node:
			return String(TEXT["to_crack"]) % [name, Unbound._num(float(FORCE["crack"]))]
		return String(TEXT["to_burnout"]) % [name, int(MarkUse.BURN["dark_climbs"])]
	if after == before:
		return String(TEXT["stays"]) % [name, rung_word(after)]
	match after:
		PARALYZED:
			return String(TEXT["to_paralyzed_node" if node else "to_paralyzed"]) % name
		BURNED:
			return String(TEXT["to_burned_node" if node else "to_burned"]) % name
	return String(TEXT["to_strained"]) % name


# --- forcing ---------------------------------------------------------------------------------

## Forces `essence` of `kind` into `part` (the crystal or tincture already
## taken): it stretches the part at FORCE "cost" and adds strain; pushed past
## paralyzed, a mark burns out (mark_use.gd burn_out) or a Node cracks.
## Returns {"lines", "growth", "rung" (the step after), "broke" (true if it
## burned out or cracked), "maker" (a burnout that brings a Maker),
## "burnout" (burn_out's lines)}.
static func force(prof, part: String, kind: String, essence: float, main = null) -> Dictionary:
	var out := {"lines": [], "growth": 0.0, "rung": STEADY, "broke": false, "maker": false, "burnout": []}
	if prof == null or essence <= 0.0 or not part in Bonds.PARTS:
		return out
	var pv := preview(prof, part, kind, essence, main)
	var name := part_name(prof, part)
	var shown := Essence.display(kind)
	if Unbound.is_on(prof):
		var s0 := Unbound.size(prof, part)
		Unbound._grow(prof, part, essence * Unbound.pay_rate(prof, part, kind), Unbound.Core.CAP, 1.0 / maxf(0.0001, float(FORCE["cost"])))
		Unbound.Core.sync(prof)
		out["growth"] = Unbound.size(prof, part) - s0
		out["lines"].append(String(TEXT["forced_node"]) % [int(essence), shown, name, Unbound._num(Unbound.size(prof, part))])
	else:
		var g := mark_growth(prof, part, kind, essence)
		var xp0 := float(prof.bonds[part]["xp"])
		var said: Array = MarkUse.deepen_mark(prof, part, g)
		out["growth"] = float(prof.bonds[part]["xp"]) - xp0
		var bond := String(Bonds.BONDS.get(String(prof.bonds[part]["id"]), {}).get("name", name))
		out["lines"].append(String(TEXT["forced_mark"]) % [int(essence), shown, bond])
		out["lines"].append_array(said)
	if int(pv["after"]) >= BROKEN:
		out["broke"] = true
		out["rung"] = BROKEN
		if Unbound.is_on(prof):
			var s := Unbound.size(prof, part)
			var now := maxf(Unbound.WAKE_SIZE, s - float(FORCE["crack"]))
			Unbound.set_size(prof, part, now)
			Unbound.Core.sync(prof)
			set_strain(prof, part, float(FORCE["crack_strain"]))
			out["lines"].append(String(TEXT["cracked"]) % [name, Unbound._num(s - now), Unbound._num(now)])
		else:
			set_strain(prof, part, 0.0)
			var burnt: Dictionary = MarkUse.burn_out(prof, part)
			out["maker"] = bool(burnt["maker"])
			out["burnout"] = burnt["lines"]
			out["lines"].append_array(burnt["lines"])
		return out
	set_strain(prof, part, float(pv["strain"]))
	out["rung"] = int(pv["after"])
	out["lines"].append(String(TEXT["now"]) % [name, rung_word(int(pv["after"]))])
	return out


# --- fading ---------------------------------------------------------------------------------

## How fast strain fades for this climber (an Unbound's Broad Back: faster).
static func _fade_mult(prof) -> float:
	return maxf(1.0, Unbound.gift(prof, "fade")) if Unbound.is_on(prof) else 1.0


## Every strained part fades by `amount`. Returns the lines (eased, faded).
static func fade(prof, amount: float) -> Array:
	var lines: Array = []
	if prof == null or amount <= 0.0:
		return lines
	for part in Bonds.PARTS:
		var s := strain(prof, part)
		if s <= 0.0:
			continue
		var r0 := rung_for(s)
		var s1 := maxf(0.0, s - amount * _fade_mult(prof))
		set_strain(prof, part, s1)
		var r1 := rung_for(s1)
		if r1 == STEADY:
			lines.append(String(TEXT["eased"]) % part_name(prof, part))
		elif r1 < r0:
			lines.append(String(TEXT["eased_to"]) % [part_name(prof, part), rung_word(r1)])
		elif r1 >= BURNED:
			lines.append(String(TEXT["still"]) % [part_name(prof, part), rung_word(r1)])
	return lines


## A stair: strain fades FORCE "fade_stair".
static func stair(prof) -> Array:
	return fade(prof, float(FORCE["fade_stair"]))


## A new climb: strain fades FORCE "fade_climb".
static func new_climb(prof) -> Array:
	return fade(prof, float(FORCE["fade_climb"]))


# --- in a climb -----------------------------------------------------------------------------

## Brings the climber's carried marks and techniques in line with the
## strain (main.gd calls it after bonds are rebuilt, at a stair, a camp and
## a new climb, and after forcing): a strained part refills slower; a mark
## burned or paralyzed by its strain is so (never healed here: overdrawing
## counts too); an Unbound's casting strain never sits below it.
static func apply(main) -> void:
	if main == null or main.get("profile") == null:
		return
	var prof = main.profile
	var p = main.get("player")
	if p != null and is_instance_valid(p):
		for b in p.bonds.values():
			var part: String = b.tech_part() if "tech" in b else String(b.part)
			var r := rung_for(strain(prof, part))
			b.strain_fill = 1.0 - clampf(float(FORCE["slow"]), 0.0, 0.95) if r >= STRAINED else 1.0
			if "tech" in b:
				continue
			if r >= PARALYZED:
				b.burned = true
				b.paralyzed = true
			elif r >= BURNED:
				b.burned = true
	var ub = main.get("unbound")
	if ub != null and is_instance_valid(ub) and Unbound.is_on(prof):
		for part in Unbound.PARTS:
			var s := strain(prof, part)
			if s > ub.strain_of(part):
				ub.strain[part] = minf(s, float(LADDER["break"]))
