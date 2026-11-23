extends RefCounted
## How fast a mark grows, as climbs: a model of a typical climber that runs
## the game's own bookkeeping (profile.gd pour, drink, the Proving's gift,
## ready_for_mark; mark_use.gd note_use and settle: a mark deepens by use,
## refilled from what's banked at each stair) over climbs of measured essence. No randomness: the same
## numbers give the same answer, so tests/parts/progression.gd can hold the
## pace to its bands, and tests/progression_measure.gd prints the tables.
##
## The essence per floor and its kinds were measured from real floor plans
## (tests/progression_measure.gd "plans": every planned monster's drop, the
## kills' extra essence and the caches, the Proving's sentinel, adds and
## shadow on floor 6, the beast on 12). Measure again after changing drops
## and copy the printed tables here. (ESSENCE is the table measured before
## the drops went to seven eighths with the fixed 20% crystal share, times
## 7/8: what flows into you stays as it was. A fresh "plans" measure then
## gave about 8% less, the floor plans having changed since; real play by
## the floor bot gave more than either, as the plans leave out the floor's
## task, puzzles and caches.)
##
## A climb counts after the bondless first climb (which ends in the Regard):
## "climb 3" is the third climb with a mark.

const Profile := preload("res://scripts/profile.gd")
const Flow := preload("res://scripts/essence_flow.gd")
const Towers := preload("res://scripts/towers.gd")
const Bonds := preload("res://scripts/bonds.gd")

## Essence banked at each floor's stair, floors 1 to 12 (12: the beast).
const ESSENCE := [45.5, 54.25, 56.875, 69.125, 77.875, 62.125, 109.375, 119.875, 137.375, 168.875, 189.875, 56.875]
## Monsters slain per floor (each may leave a tincture: items.gd DROPS).
const KILLS := [6.3, 7.2, 6.2, 6.2, 6.8, 4.0, 8.1, 8.7, 9.8, 9.8, 10.2, 1.0]
## Each tower's essence by kind (its monsters are not all of its kind).
const MIX := {
	"gryphon": {"air": 0.91, "water": 0.05, "iron": 0.04},
	"kraken": {"water": 0.75, "iron": 0.20, "air": 0.05},
	"wyvern": {"iron": 0.52, "fire": 0.41, "water": 0.04, "air": 0.03},
	"manticore": {"stone": 0.85, "water": 0.04, "air": 0.07, "iron": 0.04},
	"firebird": {"fire": 0.88, "water": 0.03, "air": 0.05, "iron": 0.04},
	"chimera": {"blade": 0.80, "water": 0.12, "iron": 0.04, "air": 0.04},
}
## What a typical climber's body parts do (scripts/part_soak.gd: a floor of
## tests/parts/part_soak.gd's typical climber, out of 100; that test keeps
## the two alike): it spreads the body's share. Nearly even, with fading.
## The first mark takes the hand.
const STYLE := {"hand": 18.0, "legs": 17.0, "back": 17.0, "throat": 16.5, "heart": 16.0, "brow": 15.5}
const FIRST_PART := "hand"
const FIRST_BOND := "stormcaller"
const OWN_TOWER := "gryphon"

## Ways of climbing, repeated in turn: "top" is the floor you fell on (the
## floors below it are banked) or 12 for a summit; "own" climbs the first
## mark's tower (else the other towers in turn). The Proving (floor 6) is won
## on any climb that gets past it.
const PATTERNS := {
	"typical": [{"top": 5, "own": true}, {"top": 12, "own": true}, {"top": 8, "own": false}, {"top": 12, "own": false}],
	"summits": [{"top": 12, "own": true}],
	"falls": [{"top": 5, "own": true}, {"top": 8, "own": true}],
}
## Tinctures: the ones slain monsters leave are drunk into the first mark
## (the share a typical climber gathers); "bought" more of its kind a climb
## (the outfitter, vaults, the Workshop).
const BOUGHT_TINCTURES := 0.0
## What a typical climber's marks draw on a floor (mark_use.gd note_use):
## the first mark about four casts of a dozen essence; a later mark less.
## (Above what the stair can pay, more use adds nothing: the bank decides.)
const MARK_USE := 48.0
const OTHER_MARK_USE := 24.0
const MarkUse := preload("res://scripts/mark_use.gd")
const Forcing := preload("res://scripts/forcing.gd")
## Forcing past full (forcing.gd): a climber who force-eats every crystal
## they get, after each stair, as long as the strain stays below the step
## they'd avoid: "careful" stops short of burned, "reckless" short of a
## burnout or a crack. "" never forces.
const FORCE_LIMIT := {"careful": Forcing.BURNED, "reckless": Forcing.BROKEN}


## Runs `climbs` climbs of `pattern` (PATTERNS key). `earned`: a full part
## takes its mark early from the Maker (a sealed wing won by floor 6) instead
## of waiting for a summit. `use`: how hard the marks are used (times
## MARK_USE: 0 never cast, 10 a spammer). Returns {"steps": [first mark's step after each
## climb], "second": the climb the second mark came on (0: none),
## "marks_at": [the climb each new mark came on], "xp": [first mark's growth
## after each climb], "per_climb": growth a climb, "forced": essence forced
## past full (`force`: FORCE_LIMIT key, or "" never)}.
static func run(pattern: String, climbs: int, earned := false, bought := BOUGHT_TINCTURES, use := 1.0, force := "") -> Dictionary:
	var prof = Profile.new()
	var cs: float = Flow.default_crystal_share()
	# The first climb: bondless, three floors of the mark's tower, then the Regard.
	for f in range(1, Profile.FIRST_CLIMB_FLOORS + 1):
		prof.pour(_essence(OWN_TOWER, f), STYLE, cs)
	prof.regarded = true
	prof.add_bond(FIRST_PART, FIRST_BOND, false)
	var steps: Array = []
	var xps: Array = []
	var crystals: Array = []  # (the crystals held after each climb: the split's share and what the marks couldn't take)
	var second := 0
	var marks_at: Array = []
	var others: Array = Towers.ORDER.filter(func(t): return t != OWN_TOWER)
	var oi := 0
	var list: Array = PATTERNS[pattern]
	var forced := 0.0
	for c in climbs:
		var how: Dictionary = list[c % list.size()]
		var tower: String = OWN_TOWER
		if not bool(how["own"]):
			tower = others[oi % others.size()]
			oi += 1
		Forcing.new_climb(prof)
		var top := int(how["top"])
		var last := top if top >= Towers.SUMMIT else top - 1
		var marked := false
		var tinctures := {}
		for f in range(1, last + 1):
			for part in prof.bonds:
				MarkUse.note_use(prof, part, (MARK_USE if part == FIRST_PART else OTHER_MARK_USE) * use)
			prof.pour(_essence(tower, f), STYLE, cs)
			Forcing.stair(prof)
			if force != "":
				forced += force_marks(prof, force)
			for k in MIX[tower]:
				tinctures[k] = float(tinctures.get(k, 0.0)) + KILLS[f - 1] * float(MIX[tower][k]) * float(Profile_drops_tincture())
			if f == 6:
				gift(prof)  # (the Proving won)
			# The Maker's earned mark: a sealed wing won on the next floor, by floor 6.
			if earned and not marked and f + 1 <= int(Flow.EARNED["last_floor"]) and f + 1 <= last and prof.ready_for_mark() != "":
				_new_mark(prof)
				marked = true
				marks_at.append(c + 1)
				if second == 0:
					second = c + 1
		if top >= Towers.SUMMIT and not marked and prof.ready_for_mark() != "":
			_new_mark(prof)
			marks_at.append(c + 1)
			if second == 0:
				second = c + 1
		# The tinctures found on banked floors (and bought ones) go into the first mark.
		for k in tinctures:
			prof.drink(k, float(Flow.TINCTURE["essence"]) * float(tinctures[k]), FIRST_PART)
		if bought > 0.0:
			prof.drink(String(Towers.TOWERS[OWN_TOWER]["essence"]), float(Flow.TINCTURE["essence"]) * bought, FIRST_PART)
		xps.append(float(prof.bonds[FIRST_PART]["xp"]))
		crystals.append(prof.crystals_held())
		steps.append(Profile.step_for_xp(float(prof.bonds[FIRST_PART]["xp"])))
	return {"steps": steps, "second": second, "marks_at": marks_at, "xp": xps, "crystals": crystals, "forced": forced}


## Force-eats crystals into the first mark (its own kind first), a crystal
## at a time, while it is full and the strain stays below `how`'s step
## (FORCE_LIMIT). Returns the essence forced.
static func force_marks(prof, how: String) -> float:
	if not prof.bonds.has(FIRST_PART):
		return 0.0
	var lim := int(FORCE_LIMIT.get(how, Forcing.BURNED))
	var own := String(Bonds.BONDS[String(prof.bonds[FIRST_PART]["id"])]["affinity"])
	var kinds: Array = [own]
	for k in load("res://scripts/essence.gd").KINDS:
		if String(k) != own:
			kinds.append(String(k))
	var done := 0.0
	var step := float(load("res://scripts/items.gd").CRYSTAL["step"])
	for kind in kinds:
		for _i in 400:
			var amt := minf(step, prof.crystal_total(kind))
			if amt < 1.0 or not Forcing.can_force(prof, FIRST_PART, kind):
				break
			if int(Forcing.preview(prof, FIRST_PART, kind, amt)["after"]) >= lim:
				return done
			amt = prof.take_crystal(kind, step)
			Forcing.force(prof, FIRST_PART, kind, amt)
			done += amt
	return done


## The chance a slain monster leaves a tincture (items.gd DROPS).
static func Profile_drops_tincture() -> float:
	return float(load("res://scripts/items.gd").DROPS.get("tincture_chance", 0.0))


## The Proving's gift to the most-used mark (the first: it is on the hand).
static func gift(prof) -> void:
	if prof.has_method("proving_gift"):
		prof.proving_gift(FIRST_PART)
	else:
		prof.raise_step(FIRST_PART)


static func _new_mark(prof) -> void:
	var part: String = prof.ready_for_mark()
	var id: String = prof.choose_bond(prof.tally, STYLE)
	if id == "":
		id = "warden"
	prof.add_bond(part, id, false)


## A floor's essence in a tower, by kind.
static func _essence(tower: String, f: int) -> Dictionary:
	var out := {}
	for k in MIX[tower]:
		out[k] = ESSENCE[f - 1] * float(MIX[tower][k])
	return out


## The first climb (1-based) the first mark reached each step from 2 to the
## last (0: not within the climbs).
static func climbs_to_steps(steps: Array) -> Dictionary:
	var out := {}
	for st in range(2, Profile.STEP_XP.size() + 1):
		out[st] = 0
		for i in steps.size():
			if int(steps[i]) >= st:
				out[st] = i + 1
				break
	return out


## How much one tincture of the mark's own kind grows it, against the span of
## each step (as a fraction): {step: fraction of the way from it to the next}.
static func tincture_push() -> Dictionary:
	var gain: float = float(Flow.TINCTURE["essence"]) * Profile.AFFINITY_WEIGHT * float(Flow.TINCTURE.get("mark_boost", 1.0)) * Profile.STEP_RATE * float(Profile.BODY_DRAG[1])
	var out := {}
	for st in range(1, Profile.STEP_XP.size()):
		out[st] = gain / (float(Profile.STEP_XP[st]) - float(Profile.STEP_XP[st - 1]))
	return out


# --- the Unbound's Nodes ----------------------------------------------------------------

## A typical Unbound's use of each awake Node a floor: its technique cast
## this many times (each spending a one-kind technique's charge, and a
## boost's essence), or before it has a technique, this much of its own
## action (what would fill one: strikes, rolls, parries...).
const UB_CASTS := 3.0
const UB_ACTION := 150.0
## A caster who spams: this many times the typical use.
const UB_SPAM := 10.0


## Runs `climbs` climbs of `pattern` (PATTERNS key) for an Unbound who
## refused the mark on their first climb (floors 1-5 banked, then the
## Regard). `use`: "typical", "spam" or "none" (how hard they use their
## awake Nodes); `routing`: "natural" (each kind to its own Node) or
## "spread" (the climb's own kind, once its Node is awake, wakes the next
## sleeping Node; a kind whose Node is at level 12 goes to the smallest Node
## that isn't). Each summit condenses into the biggest awake Node that isn't
## full. `sealed`: the Nodes sealed on the train after the first climb
## (unbound.gd seal: a focused Unbound; their essence flows to the open
## Nodes). `drain`: a climb that ends below the summit is a fall, and a fall
## drains what the Nodes hold back into the well (unbound.gd drain; sizes
## kept), as in the game; false shows the pace without it. Returns {"sizes": [after each climb, part -> size], "awake": part
## -> the climb it woke (0: never), "top": part -> the climb it reached level
## 12 (0: never), "crystals": the crystals held after each climb}.
static func run_unbound(pattern: String, climbs: int, use := "typical", routing := "natural", sealed := [], drain := true, force := "") -> Dictionary:
	var U = load("res://scripts/unbound.gd")
	var Tech = load("res://scripts/technique.gd")
	var prof = Profile.new()
	prof.saving = false
	var cs: float = Flow.default_crystal_share()
	for f in range(1, Profile.FIRST_CLIMB_FLOORS):
		prof.pour(_essence(OWN_TOWER, f), STYLE, cs)
	prof.regarded = true
	U.become(prof)
	for part in sealed:
		U.seal(prof, String(part))
	var woke := {}
	var top := {}
	var sizes: Array = []
	var crystals: Array = []
	var others: Array = Towers.ORDER.filter(func(t): return t != OWN_TOWER)
	var oi := 0
	var list: Array = PATTERNS[pattern]
	var k: float = float({"typical": 1.0, "spam": UB_SPAM, "none": 0.0}.get(use, 1.0))
	var charge := float(Tech.CHARGE[0])
	var boost := float(Tech.COST[0])
	for c in climbs:
		var how: Dictionary = list[c % list.size()]
		var tower: String = OWN_TOWER
		if not bool(how["own"]):
			tower = others[oi % others.size()]
			oi += 1
			if routing == "spread":
				tower = _ub_journey(prof, U, tower)  # (growing them all: climb the tower that feeds the smallest Node)
		var last := int(how["top"]) if int(how["top"]) >= Towers.SUMMIT else int(how["top"]) - 1
		U.new_climb(prof)
		Forcing.new_climb(prof)
		if routing == "spread":
			_ub_spread(prof, U, String(Towers.TOWERS[tower]["essence"]))
		for f in range(1, last + 1):
			if k > 0.0:
				for part in U.PARTS:
					if U.tech_ready(prof, part):
						U.note_use(prof, part, UB_CASTS * charge * k, "cast")
						U.note_use(prof, part, UB_CASTS * boost * k, "boost")
					else:
						U.note_use(prof, part, UB_ACTION * k, "action")
			prof.pour(_essence(tower, f), {}, cs)
			Forcing.stair(prof)
			if force != "":
				force_nodes(prof, force)
		if last >= Towers.SUMMIT:
			var best := ""
			for part in U.PARTS:
				if U.awake(prof, part) and U.size(prof, part) < 119.99 and (best == "" or U.size(prof, part) > U.size(prof, best)):
					best = part
			if best != "":
				U.condense(prof, best, String(Towers.TOWERS[tower]["essence"]))
		elif drain:
			U.drain(prof)  # (a fall: what the Nodes hold goes back to the well; sizes kept)
		var now := {}
		for part in U.PARTS:
			now[part] = U.size(prof, part)
			if not woke.has(part) and U.awake(prof, part):
				woke[part] = c + 1
			if not top.has(part) and U.level(prof, part) >= U.MAX_LEVEL:
				top[part] = c + 1
		sizes.append(now)
		crystals.append(prof.crystals_held())
	for part in U.PARTS:
		if not woke.has(part):
			woke[part] = 0
		if not top.has(part):
			top[part] = 0
	return {"sizes": sizes, "awake": woke, "top": top, "crystals": crystals}


## Force-eats crystals, each kind into the Node it flows to, a crystal at a
## time, while that Node is full and its strain stays below `how`'s step
## (FORCE_LIMIT). Returns the essence forced.
static func force_nodes(prof, how: String) -> float:
	var U = load("res://scripts/unbound.gd")
	var lim := int(FORCE_LIMIT.get(how, Forcing.BURNED))
	var step := float(load("res://scripts/items.gd").CRYSTAL["step"])
	var done := 0.0
	for k in load("res://scripts/essence.gd").KINDS:
		var kind := String(k)
		var part: String = U.part_for(prof, kind)
		for _i in 400:
			var amt := minf(step, prof.crystal_total(kind))
			if amt < 1.0 or not Forcing.can_force(prof, part, kind):
				break
			if int(Forcing.preview(prof, part, kind, amt)["after"]) >= lim:
				break
			amt = prof.take_crystal(kind, step)
			Forcing.force(prof, part, kind, amt)
			done += amt
	return done


## A climber growing all six Nodes travels: away from their own tower they
## climb the one whose essence is the natural kind of their smallest Node
## not yet full (the one rule: a Node refills best from its own kinds).
static func _ub_journey(prof, U, fallback: String) -> String:
	var small := ""
	for part in U.PARTS:
		if U.size(prof, part) < 119.99 and (small == "" or U.size(prof, part) < U.size(prof, small)):
			small = part
	if small == "":
		return fallback
	var want := String(U.PART_KIND.get(small, ""))
	for t in Towers.ORDER:
		if String(Towers.TOWERS[t]["essence"]) == want:
			return t
	return fallback


## "spread" routing, before a climb in a tower of `climb_kind`.
static func _ub_spread(prof, U, climb_kind: String) -> void:
	var small := ""
	var sleeper := ""
	for part in U.PARTS:
		if U.size(prof, part) < 119.99 and (small == "" or U.size(prof, part) < U.size(prof, small)):
			small = part
		if not U.awake(prof, part) and (sleeper == "" or U.size(prof, part) > U.size(prof, sleeper)):
			sleeper = part
	for kind in U.NATURAL:
		var home: String = U.NATURAL[kind]
		var send := home
		if U.level(prof, home) >= U.MAX_LEVEL and small != "":
			send = small
		elif kind == climb_kind and U.awake(prof, home) and sleeper != "":
			send = sleeper  # (wake the next one)
		U.route(prof, kind, send)


## The climbs until a part reached a size (or 0), from run_unbound's sizes.
static func climbs_to_size(sizes: Array, part: String, want: float) -> int:
	for i in sizes.size():
		if float(sizes[i].get(part, 0.0)) >= want - 0.0001:
			return i + 1
	return 0
