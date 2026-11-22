extends RefCounted
## What each body part does to fill toward its next mark: every number of it
## is here, so it's easy to tune (the Data editor shows it under "Mark growth
## and essence").
##
## A part fills (soaks) from what it does, and the soak only spreads the
## body's share of banked essence over the parts (profile.gd pour): what
## matters is each part's share, not the size of the numbers. Two kinds of
## source, so a mark always helps (the owner's rule): some follow how you
## play (strikes, backstabs, rolls), some help with what you struggle with
## (the heart fills from hits you take, so a climber who gets hit a lot
## earns a mark that helps them last).
##
## SOAK: action -> {"part", "soak" (soak for the first one on a floor),
## "fill" (what it fills a mark's bond, or an Unbound's techniques, for
## casting: never faded), "fade" (its group, below)}. The call sites are in
## player.gd (_act), with the action's name.
##
## FADING (diminishing returns): on one floor, each further unit of the same
## group soaks less: the n-th (from 0) is worth 1 / (1 + n / h) of the first,
## h being FADE[group] (FADE["default"] if it has none): after h units a unit
## is worth half, after 2h a third. Every stair starts the count again
## (main.gd soak_worn). So spamming one thing isn't the fastest route to a
## mark: doing a bit of everything is. Strikes come by the dozen, so theirs
## fades soonest. (The bond's fill for casting never fades.)
##
## LEGS_GAP: seconds between two leg soaks, so rolls spammed at nothing (or
## a dodge and a leap at once) count once. A roll or a jump counts when it
## carries you clear of a blow that was coming (player.gd _watch_clear: a
## foe winding up near you, or a shot flying at you, and it misses), when a
## roll goes through an attack untouched, and a jump when it clears a gap,
## burning floor, a trap or a low sweep.
## tests/parts/part_soak.gd measures who fills what first.

static var SOAK := {
	"strike": {"part": "hand", "soak": 2.0, "fill": 6.0, "fade": "hand"},  # a weapon strike lands (each foe struck)
	"shot": {"part": "hand", "soak": 2.0, "fill": 6.0, "fade": "hand"},  # a bow, crossbow or pistol shot lands
	"cleave": {"part": "throat", "soak": 4.0, "fill": 8.0, "fade": "throat"},  # each extra foe one swing catches
	"multi_cast": {"part": "throat", "soak": 4.0, "fill": 8.0, "fade": "throat"},  # each extra foe one spell catches
	"backstab": {"part": "back", "soak": 3.5, "fill": 10.0, "fade": "backstab"},  # a blow on a foe's back
	"finisher": {"part": "back", "soak": 1.5, "fill": 6.0, "fade": "finisher"},  # the blow that fells a foe
	"hit_taken": {"part": "heart", "soak": 3.0, "fill": 8.0, "fade": "heart"},  # a hit you take and survive
	"parry": {"part": "brow", "soak": 4.0, "fill": 12.0, "fade": "parry"},
	"perfect_parry": {"part": "brow", "soak": 6.0, "fill": 18.0, "fade": "parry"},
	"roll_through": {"part": "legs", "soak": 3.0, "fill": 10.0, "fade": "roll"},  # a roll through an attack, untouched
	"roll_clear": {"part": "legs", "soak": 3.0, "fill": 10.0, "fade": "roll"},  # a roll that carries you clear of a coming blow
	"jump_clear": {"part": "legs", "soak": 4.0, "fill": 10.0, "fade": "jump"},  # a jump over a gap, burning floor, a trap or a low sweep
}
## Units of a group on one floor after which a unit is worth half.
static var FADE := {"default": 6.0, "hand": 3.5}
## Seconds between two leg soaks.
static var LEGS_GAP := 0.6


## The soak `units` of `action` give now, faded by what `worn` (group ->
## units so far this floor) already holds; counts them into `worn`.
static func take(worn: Dictionary, action: String, units := 1.0) -> float:
	var row: Dictionary = SOAK.get(action, {})
	if row.is_empty() or units <= 0.0:
		return 0.0
	var group := String(row.get("fade", action))
	var n := float(worn.get(group, 0.0))
	worn[group] = n + units
	return faded(group, n, units) * float(row["soak"])


## How many first units `units` more of `group` are worth, `from` units in.
static func faded(group: String, from: float, units: float) -> float:
	var h := maxf(0.01, float(FADE.get(group, FADE["default"])))
	var n := from
	var total := 0.0
	var left := units
	while left > 0.0:
		var u := minf(1.0, left)
		total += u / (1.0 + n / h)
		n += u
		left -= u
	return total


## The body part an action fills.
static func part_of(action: String) -> String:
	return String(SOAK.get(action, {}).get("part", ""))


## What `units` of an action fill a mark's bond for casting (never faded).
static func fill_of(action: String, units := 1.0) -> float:
	return float(SOAK.get(action, {}).get("fill", 0.0)) * units


## One floor's soak, by part, from `counts` (action -> units done on it):
## the model tests/parts/part_soak.gd uses. Actions sharing a group are
## taken as if mixed through the floor (each gets its share of the faded
## total).
static func floor_soak(counts: Dictionary) -> Dictionary:
	var groups := {}
	for action in counts:
		if not SOAK.has(action) or float(counts[action]) <= 0.0:
			continue
		var g := String(SOAK[action].get("fade", action))
		groups[g] = float(groups.get(g, 0.0)) + float(counts[action])
	var out := {}
	for action in counts:
		if not SOAK.has(action) or float(counts[action]) <= 0.0:
			continue
		var g := String(SOAK[action].get("fade", action))
		var n := float(groups[g])
		var part := part_of(action)
		out[part] = float(out.get(part, 0.0)) + float(SOAK[action]["soak"]) * faded(g, 0.0, n) * float(counts[action]) / n
	return out
