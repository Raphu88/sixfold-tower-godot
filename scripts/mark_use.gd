extends RefCounted
## Marks grow by USE, and burns. Every word and number of it is here (the
## bookkeeping of a stair is in profile.gd pour, the casts in player.gd, the
## moments in main.gd), the same way the Unbound's Nodes grow (unbound.gd).
##
## THE POOL. Each mark holds an essence pool. Its DEPTH (profile.bonds
## part -> "xp", kept under its old name) is what carries it up its steps:
## profile.gd STEP_XP is the depth each step needs. A deeper pool also holds
## more in a climb (bond.gd capacity: between its step's and the next
## step's). A marked climber never sees the pool's numbers: the climber
## screen and the HUD show bars and words only (feel, depth_words).
##
## USE. In a climb, the mark's spells draw on its pool. Every cast notes
## what it drew (note_use), and an overdrawn cast also what it pushed past
## the pool (pushing counts too). A forced cast counts as well.
##
## AT EACH STAIR (settle), the marks' share of the banked essence
## (essence_flow.gd SPLIT) goes, for each mark, first to REFILL what it used
## (that much goes back into its pool for the next floor), then to DEEPEN it:
## its depth grows by USE "deepen" (0.6) x what it used, each 1 depth using
## up USE "cost" (1) banked essence. Each unit of use asks for both at once,
## so a stair that can't pay all of it pays the same part of each: casting
## more than you bank adds nothing beyond what the bank can pay, but never
## grows a mark less than casting a little would. Its own kind of essence
## pays fully; any other kind pays only USE "other" of itself. A mark that
## wasn't used takes in only USE "trickle" of its own kind.
## The body's marks slow it (profile.gd BODY_DRAG), and a faint mark pays its
## debt first. Whatever is left condenses into crystals (essence is never
## lost). Use that wasn't paid is gone. No cap a climb: banked essence and
## burns hold the pace.
##
## BURNS stack (bond.gd pay):
##   overdraw            BURNED: its body part is weaker (bonds.gd PART_BURN)
##   overdraw a burned   PARALYZED: the cast tears health from you
##     mark              (bond.gd TEAR_HEALTH) and the mark seizes: it can't
##                       be cast at all. It still weakens its body part.
##   the stair           heals one rung: paralyzed -> burned -> healed
##   a forced cast       holding a paralyzed mark's button (BURN "force_hold"
##                       seconds, with a warning on screen and on its touch
##                       button) casts it anyway and BURNS IT OUT.
##   BURNOUT             the mark goes dark: no casting, its passive and body
##                       off, it takes no banked essence (a tincture still
##                       reaches it), for BURN "dark_climbs"
##                       climbs after this one. It loses BURN "loss" of a
##                       step's worth of depth (never more than one step
##                       back) and is never erased. It counts toward a
##                       Maker's visit the same way a slip past a barrier
##                       does (climb_shape.gd SLIPS: every third). The
##                       guardians frown on it: the mark was their gift.

const Bonds := preload("res://scripts/bonds.gd")

## "deepen": depth a mark grows for each essence its spells drew; "cost":
## banked essence each 1 depth uses up; "trickle": what an unused mark takes
## in, a share of its own kind; "other": how far a kind the mark
## isn't made of goes (a third: its own kind pays fully).
static var USE := {"deepen": 0.6, "cost": 1.0, "trickle": 0.05, "other": 1.0 / 3.0}
## Burns: climbs a burned-out mark stays dark after the climb it burned out
## in; the depth it loses (a share of its step's span; never more than one
## step back); seconds a paralyzed mark's button must be held to force it.
static var BURN := {"dark_climbs": 3, "loss": 0.5, "force_hold": 1.0}

static var TEXT := {
	# The stair's lines.
	"deepened": "Your %s mark deepens with use",
	"step_up": "%s grows to step %d%s",
	"no_longer_faint": "Your %s mark is no longer faint",
	"left": "What your marks couldn't take condensed: %d into crystals",
	"healed_one": "Your %s mark stirs again, still burned",
	# A cast.
	"burned": "%s burned!",
	"paralyzed": "%s mark seizes up! -%d",
	"paralyzed_tap": "%s mark is paralyzed. Hold to force it: it will burn out",
	"dark_tap": "Your %s mark is dark (%s)",
	"forcing": "FORCING YOUR %s MARK",
	"forcing_sub": "Let go now, or it burns out for %d climbs",
	"forcing_touch": "HOLD",
	# The burnout.
	"burnout_title": "MARK BURNED OUT",
	"burnout_lines": ["Your %s mark burns out and goes dark.", "It sleeps for this climb and the next %d. It lost some depth.", "Far above, the guardians frown. The mark was their gift."],
	"burnout_maker": "A Maker has noticed. It will come for you at the next stair.",
	"lit": "Your %s mark wakes from the dark",
	# Feel (never numbers).
	"dark_climbs": "dark for %d more climbs",
	"dark_climb": "dark for 1 more climb",
	"dark_now": "dark for the rest of this climb",
	"top": "as deep as a mark goes",
	"depth": ["shallow yet", "deepening", "deep", "nearly deep enough"],
	"depth_line": "Feels %s for step %d",
	"fill": ["nearly dry", "low", "well filled", "brimming"],
	"use_hint": "Grows as you use it: cast it, and the stair refills and deepens it",
	"paralyzed_state": "paralyzed: hold its button to force a cast (it burns out)",
	"burned_state": "burned: overdraw again and it seizes up",
}


# --- use --------------------------------------------------------------------------------

## A mark drew `essence` from its pool (a cast, or what an overdrawn cast
## pushed past it): the next stair refills and deepens it by that much.
static func note_use(prof, part: String, essence: float) -> void:
	if prof == null or essence <= 0.0 or not prof.bonds.has(part) or dark(prof, part):
		return
	var b: Dictionary = prof.bonds[part]
	b["used"] = float(b.get("used", 0.0)) + essence


## What a mark has drawn since the last stair.
static func used(prof, part: String) -> float:
	return float(prof.bonds.get(part, {}).get("used", 0.0))


## How much of one kind a mark draws (its own kind fully, any other at USE "other").
static func rate(prof, part: String, kind: String) -> float:
	var own := String(Bonds.BONDS.get(String(prof.bonds[part]["id"]), {}).get("affinity", ""))
	return 1.0 if own == kind else float(USE["other"])


## The marks' share of a stair (`to_marks`: kind -> essence) refills and
## deepens each mark by its use; an unused one takes a trickle. `at_stair`:
## use that wasn't paid is gone (eating a crystal keeps it for the stair).
## Returns {"lines", "left" (kind -> essence no mark took), "refilled"
## (part -> essence back in its pool), "deepened" (parts grown by use),
## "grown" (part -> depth added)}.
static func settle(prof, to_marks: Dictionary, at_stair := true) -> Dictionary:
	var out := {"lines": [], "left": {}, "refilled": {}, "deepened": [], "grown": {}}
	var avail := {}
	for k in to_marks:
		if float(to_marks[k]) > 0.0:
			avail[k] = float(to_marks[k])
	var drag: float = prof.body_drag()
	var cost := float(USE["cost"])
	var deepen := float(USE["deepen"])
	var top := float(prof.STEP_XP[prof.STEP_XP.size() - 1])
	var lit: Array = Bonds.PARTS.filter(func(p): return prof.bonds.has(p) and not dark(prof, p))
	# A faint mark's debt is paid first, used or not (its own kind counting
	# profile.gd AFFINITY_WEIGHT, another OTHER_WEIGHT, as a tincture's does).
	var debts := {}
	for part in lit:
		var b: Dictionary = prof.bonds[part]
		if bool(b.get("faint", false)) and float(b.get("debt", 0.0)) > 0.0:
			debts[part] = {"units": float(b["debt"])}
	var paid := _draw(prof, avail, debts, float(prof.AFFINITY_WEIGHT), float(prof.OTHER_WEIGHT))
	for part in debts:
		var b: Dictionary = prof.bonds[part]
		b["debt"] = float(b["debt"]) - float(paid.get(part, 0.0))
		if float(b["debt"]) <= 0.0001:
			b["debt"] = 0.0
			b["faint"] = false
			out["lines"].append(TEXT["no_longer_faint"] % Bonds.BONDS[b["id"]]["name"])
	# What each used mark asks for: its use back, and its deepening.
	var wants := {}
	var room := {}
	for part in lit:
		var u := used(prof, part)
		if u <= 0.0:
			continue
		var b: Dictionary = prof.bonds[part]
		var debt := float(b.get("debt", 0.0)) if bool(b.get("faint", false)) else 0.0
		room[part] = maxf(0.0, top - float(b["xp"])) + debt
		var g := minf(u * deepen * drag, float(room[part]))  # (near its last step: only the depth it has room for)
		wants[part] = {"use": u, "grow": g, "units": u + g * cost}
	var got := _draw(prof, avail, wants)
	var gains := {}
	for part in wants:
		var w: Dictionary = wants[part]
		var f := clampf(float(got.get(part, 0.0)) / maxf(float(w["units"]), 0.0001), 0.0, 1.0)
		out["refilled"][part] = float(w["use"]) * f
		gains[part] = float(w["grow"]) * f
		if float(gains[part]) >= 0.05:
			out["deepened"].append(part)
	# The unused marks: a trickle of what's left of their own kind (shared
	# between marks of that kind as they would be).
	var trickle := {}
	for part in lit:
		if wants.has(part):
			continue
		var own_kind := String(Bonds.BONDS.get(String(prof.bonds[part]["id"]), {}).get("affinity", ""))
		var could := float(avail.get(own_kind, 0.0))
		var b: Dictionary = prof.bonds[part]
		var debt := float(b.get("debt", 0.0)) if bool(b.get("faint", false)) else 0.0
		var g := minf(could * float(USE["trickle"]) * drag, maxf(0.0, top - float(b["xp"])) + debt)
		if g > 0.0:
			trickle[part] = {"use": 0.0, "grow": g, "units": g * cost}
	var got2 := _draw(prof, avail, trickle, 1.0, 0.0)
	for part in trickle:
		gains[part] = float(got2.get(part, 0.0)) / maxf(cost, 0.0001)
	for part in Bonds.PARTS:
		if gains.has(part) and float(gains[part]) > 0.0:
			out["lines"].append_array(deepen_mark(prof, part, float(gains[part])))
			out["grown"][part] = float(gains[part])
	for part in out["deepened"]:
		out["lines"].push_front(TEXT["deepened"] % String(Bonds.PART_NAMES[part]))
	# Use: paid, or gone at a stair.
	for part in lit:
		var b: Dictionary = prof.bonds[part]
		if at_stair:
			b.erase("used")
		elif b.has("used"):
			b["used"] = maxf(0.0, float(b["used"]) - float(out["refilled"].get(part, 0.0)))
	for k in avail:
		if float(avail[k]) > 0.0001:
			out["left"][k] = float(avail[k])
	return out


## Pays each mark's `wants` (part -> {"units"}) from `avail` (kind -> essence,
## taken from it): first its own kind (shared by want between marks of that
## kind; each essence `own_rate` units), then the other kinds (`other_rate`,
## USE "other" unless given). Returns part -> units paid.
static func _draw(prof, avail: Dictionary, wants: Dictionary, own_rate := 1.0, other_rate := -1.0) -> Dictionary:
	if other_rate < 0.0:
		other_rate = float(USE["other"])
	var got := {}
	for part in wants:
		got[part] = 0.0
	for pass_own in [true, false]:
		for k in avail.keys():
			var claim := {}
			var total := 0.0
			for part in wants:
				var own: bool = String(Bonds.BONDS.get(String(prof.bonds[part]["id"]), {}).get("affinity", "")) == String(k)
				if own != pass_own:
					continue
				var need := float(wants[part]["units"]) - float(got[part])
				if need > 0.0001:
					claim[part] = need
					total += need
			if total <= 0.0:
				continue
			var r: float = own_rate if pass_own else other_rate
			if r <= 0.0:
				continue
			var give := minf(float(avail[k]) * r, total)
			if give <= 0.0:
				continue
			for part in claim:
				got[part] = float(got[part]) + give * float(claim[part]) / total
			avail[k] = float(avail[k]) - give / r
	return got


## A mark's depth grows by `gain` (already slowed by the body's marks): a
## faint mark pays its debt first. Returns the stair's lines (a step reached).
static func deepen_mark(prof, part: String, gain: float) -> Array:
	var lines: Array = []
	if not prof.bonds.has(part) or gain <= 0.0:
		return lines
	var b: Dictionary = prof.bonds[part]
	var info: Dictionary = Bonds.BONDS[b["id"]]
	if bool(b.get("faint", false)):
		b["debt"] = float(b["debt"]) - gain
		if float(b["debt"]) > 0.0:
			return lines
		gain = -float(b["debt"])
		b["debt"] = 0.0
		b["faint"] = false
		lines.append(TEXT["no_longer_faint"] % info["name"])
	var top := float(prof.STEP_XP[prof.STEP_XP.size() - 1])
	var before: int = prof.step_for_xp(float(b["xp"]))
	b["xp"] = minf(top, float(b["xp"]) + gain)
	var after: int = prof.step_for_xp(float(b["xp"]))
	if after > before:
		var note: String = Bonds.step_note(b["id"], after)
		lines.append(TEXT["step_up"] % [info["name"], after, (": " + note) if note != "" else ""])
	return lines


# --- burnout and the dark ----------------------------------------------------------------

## True while a mark is dark (burned out).
static func dark(prof, part: String) -> bool:
	return int(prof.bonds.get(part, {}).get("dark", 0)) > 0


## A forced cast burned a mark out: it goes dark (this climb and the next
## BURN "dark_climbs"), loses some depth (at most one step back), and counts
## as a slip toward a Maker's visit. Returns {"lines", "maker": true if this
## brings one, "lost": depth lost}.
static func burn_out(prof, part: String) -> Dictionary:
	var out := {"lines": [], "maker": false, "lost": 0.0}
	if not prof.bonds.has(part):
		return out
	var b: Dictionary = prof.bonds[part]
	var xp := float(b["xp"])
	var steps: Array = prof.STEP_XP
	var st: int = prof.step_for_xp(xp)
	var lo := float(steps[st - 1])
	var hi := float(steps[st]) if st < steps.size() else lo + (lo - float(steps[maxi(st - 2, 0)]))
	var floor_at := float(steps[maxi(st - 2, 0)])  # (never more than one step back)
	var now := maxf(floor_at, xp - float(BURN["loss"]) * maxf(hi - lo, 0.0))
	out["lost"] = xp - now
	b["xp"] = now
	b["dark"] = int(BURN["dark_climbs"]) + 1  # (the climb it burned out in, then the next ones)
	b.erase("used")
	b["burnouts"] = int(b.get("burnouts", 0)) + 1
	prof.note("burnouts")
	prof.note("slips")  # (it counts toward a Maker as a slip does: climb_shape.gd SLIPS)
	var every := int(load("res://scripts/climb_shape.gd").SLIPS["maker_every"])
	if every > 0 and prof.count("slips") % every == 0:
		out["maker"] = true
		prof.record["maker_owed"] = 1.0
	var name := String(Bonds.PART_NAMES[part])
	var said: Array = TEXT["burnout_lines"]
	out["lines"] = [String(said[0]) % name, String(said[1]) % int(BURN["dark_climbs"]), String(said[2])]
	if out["maker"]:
		out["lines"].append(TEXT["burnout_maker"])
	return out


## A new climb: a dark mark is one climb nearer waking. Returns the parts
## that woke (lit again); every mark's use starts again.
static func new_climb(prof) -> Array:
	var woke: Array = []
	for part in prof.bonds:
		var b: Dictionary = prof.bonds[part]
		b.erase("used")
		if int(b.get("dark", 0)) > 0:
			b["dark"] = int(b["dark"]) - 1
			if int(b["dark"]) <= 0:
				b.erase("dark")
				woke.append(part)
	return woke


## Whole climbs a dark mark still sits out after this one (0: lit, or only
## the rest of this climb).
static func dark_left(prof, part: String) -> int:
	return maxi(0, int(prof.bonds.get(part, {}).get("dark", 0)) - 1)


## A dark mark's words: how long it sleeps.
static func dark_words(prof, part: String) -> String:
	var n := dark_left(prof, part)
	if n <= 0:
		return String(TEXT["dark_now"])
	return String(TEXT["dark_climb"]) if n == 1 else String(TEXT["dark_climbs"]) % n


# --- how it feels (never numbers) -------------------------------------------------------

## How far a depth is from its step to the next (0..1; 1 at the last step).
static func step_fraction(steps: Array, xp: float) -> float:
	var st := 1
	for i in steps.size():
		if xp >= float(steps[i]):
			st = i + 1
	if st >= steps.size():
		return 1.0
	var lo := float(steps[st - 1])
	var hi := float(steps[st])
	return clampf((xp - lo) / maxf(hi - lo, 0.0001), 0.0, 1.0)


## How deep a mark feels, in words: "Feels deep for step 4"...
static func depth_words(prof, part: String) -> String:
	var b: Dictionary = prof.bonds.get(part, {})
	if b.is_empty():
		return ""
	if dark(prof, part):
		return dark_words(prof, part)
	var st: int = prof.step_for_xp(float(b["xp"]))
	if st >= prof.STEP_XP.size():
		return String(TEXT["top"])
	var k := step_fraction(prof.STEP_XP, float(b["xp"]))
	var words: Array = TEXT["depth"]
	return String(TEXT["depth_line"]) % [String(words[clampi(int(k * words.size()), 0, words.size() - 1)]), st + 1]


## How full a pool feels in a climb (`k`: essence / what it holds), in a word.
static func fill_words(k: float) -> String:
	var words: Array = TEXT["fill"]
	if k < 0.15:
		return String(words[0])
	if k < 0.5:
		return String(words[1])
	if k < 0.9:
		return String(words[2])
	return String(words[3])


# --- old saves ---------------------------------------------------------------------------

## A mark's progress from an older table (`old`: the depth each step needed
## then) as depth in today's (`now`): the same step, as far through it.
static func convert(xp: float, old: Array, now: Array) -> float:
	if old == now or old.is_empty():
		return xp
	var st := 1
	for i in old.size():
		if xp >= float(old[i]):
			st = i + 1
	var top := mini(st, now.size())
	if st >= old.size() or st >= now.size():
		return float(now[top - 1])
	var k := clampf((xp - float(old[st - 1])) / maxf(float(old[st]) - float(old[st - 1]), 0.0001), 0.0, 1.0)
	return float(now[st - 1]) + k * (float(now[st]) - float(now[st - 1]))
