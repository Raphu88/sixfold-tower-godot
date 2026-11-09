extends RefCounted
## The Unbound: climbers who refuse the tower beasts' marks. Every word and
## number about them is here (techniques in technique.gd, the climb's
## running state in unbound_run.gd, the pages in technique_page.gd).
##
## BECOMING UNBOUND
##   Only on the bondless first climb, at the Regard. Break no barrier and
##   the beast OFFERS the mark: accept it, or refuse it (refused, the mark
##   it just gave is taken back) and become Unbound. Break a barrier with
##   bare fists on that climb (unbound_run.gd) and you have broken the
##   tower's rules: the beast REFUSES to mark you, and you are Unbound (no
##   choice). After the first climb a marked climber can't become Unbound.
##   It's for good, except through the Developer (a secret bond): its holder
##   can let the beasts mark them again (return_to_marks).
## HOW THEY WORK
##   Banked essence pools raw in the six body parts (profile.part_density),
##   each kind in its natural part unless routed elsewhere at the train. The
##   path's essence (Life or Unmaking, profile.flow) flows through every
##   part at once. A part's raw density sets its LEVEL (1 to 10): how strong
##   its techniques are, how many essences it can combine, and a gift at
##   GIFT_LEVEL. The total sets the climber's STAGE.
## Profile state lives in profile.unbound (state() fills in its keys).

const PARTS := ["hand", "legs", "heart", "brow", "throat", "back"]
const PART_NAMES := {"hand": "Hand", "legs": "Legs", "heart": "Heart", "brow": "Brow", "throat": "Throat", "back": "Back"}
## The six kinds and their natural parts.
const NATURAL := {"blade": "hand", "air": "legs", "stone": "back", "water": "throat", "fire": "brow", "iron": "heart"}
## Each part's main colour (its natural essence's), for the veins.
const PART_KIND := {"hand": "blade", "legs": "air", "back": "stone", "throat": "water", "brow": "fire", "heart": "iron"}
## How much of the path's banked flow runs through each part.
const FLOW_SHARE := 1.0
## Raw density a part needs for each level (index = level - 1).
const LEVELS := [0.0, 25.0, 60.0, 110.0, 170.0, 250.0, 350.0, 470.0, 610.0, 780.0]
## How many essences a technique from a part can combine, by the part's
## level: one from level 1, two from KINDS_AT[1], three from KINDS_AT[2].
const KINDS_AT := [1, 4, 8]
## Techniques from a part hit this much harder at level 10 (straight line from 1x at level 1).
const MAX_POWER := 2.0
## Each part's gift at this level.
const GIFT_LEVEL := 5
const GIFTS := {
	"hand": {"name": "Heavy Hands", "desc": "strikes 15% harder", "strength": 0.15},
	"legs": {"name": "Light Feet", "desc": "walk 8% faster", "speed": 0.08},
	"heart": {"name": "Deep Heart", "desc": "15% more health", "health": 0.15},
	"brow": {"name": "Clear Brow", "desc": "techniques cost 25% less", "cost": 0.25},
	"throat": {"name": "Long Breath", "desc": "stamina back 20% faster", "will": 0.2},
	"back": {"name": "Broad Back", "desc": "strain fades twice as fast", "fade": 2.0},
}
## The stages, from total raw density (index = stage - 1).
const STAGES := ["Stir", "Pulse", "Flow", "Surge", "Torrent", "Tide", "Tempest", "Maelstrom", "Cataclysm", "Unbound"]
const STAGE_AT := [0.0, 60.0, 150.0, 300.0, 500.0, 800.0, 1200.0, 1700.0, 2400.0, 3300.0]
## At a summit the Unbound condense the tower's essence into a part of their choice.
const CONDENSE := 60.0
## Going back (the Developer): the densest part takes a mark, its bond
## chosen by what's pooled there, starting with this share of its raw
## density as growth; every other part keeps this share as soak.
const SETTLE := 0.5

const TEXT := {
	"name": "Unbound",
	"refuse_title": "THE BEAST OFFERS A MARK",
	"refuse_lines": ["Take it, and you are marked as every climber is.", "Refuse it, and essence pools raw in your body. There is no road back."],
	"accept_name": "Accept the mark",
	"accept_desc": "Take the %s mark on your %s. Your bonds grow as they always have.",
	"refuse_name": "Refuse it",
	"refuse_desc": "Become Unbound: no tower bond, now or later. Banked essence pools raw in your six body parts, and you build your own techniques from it.",
	"refuse_note": "for good",
	"refuse_again": "Tap again to refuse, for good",
	"refuse_again_keys": "Press again to refuse, for good",
	"refused_title": "REFUSED",
	"refused_lines": ["You broke a barrier on your first climb.", "%s will not mark you.", "You are Unbound.", "Banked essence pools raw in your six body parts."],
	"accepted": "Essence takes hold in your %s: the %s mark",
	"stage": "%s  ·  stage %d of 10",
	"climber_line": "Unbound  ·  %s  ·  %d %s  ·  best floor %d",
	"level": "level %d",
	"condense_title": "CONDENSE",
	"condense_sub": "No mark for the Unbound. Draw the tower's %s essence into one part.",
	"condense_card": "+%d %s",
	"condense_desc": "%s essence pools in your %s: level %d now.",
	"condensed": "%d %s essence condenses in your %s",
	"back_title": "MARKED AGAIN",
	"back": "Raw essence settles back into a bond: the %s mark on your %s.",
	"back_none": "Raw essence settles back into you. Your next marks will come sooner.",
}


## The climber's Unbound state, with every key filled in (old saves have none).
static func state(prof) -> Dictionary:
	var st = prof.get("unbound")
	if not (st is Dictionary):
		st = {}
		prof.set("unbound", st)
	if not st.has("on"):
		st["on"] = false
	if not st.has("found"):
		st["found"] = false  # a barrier struck once (it only shuddered: the warning)
	if not st.has("boost"):
		st["boost"] = true  # casts boost from carried essence (technique.gd BOOST)
	st.erase("broken")  # (old saves counted barriers across climbs: no longer used)
	if not (st.get("routes") is Dictionary):
		st["routes"] = {}  # kind -> part (only the kinds routed away from their natural part)
	if not (st.get("techs") is Array) or st["techs"].size() != PARTS.size():
		st["techs"] = []
		for i in PARTS.size():
			st["techs"].append({})
	return st


static func is_on(prof) -> bool:
	return prof != null and bool(state(prof).get("on", false))


## Where a kind pools when banked (its natural part, or where it's routed).
static func part_for(prof, kind: String) -> String:
	var routes: Dictionary = state(prof)["routes"]
	var to := String(routes.get(kind, ""))
	return to if to in PARTS else String(NATURAL.get(kind, "hand"))


## Routes a kind to a part (its natural part clears the route).
static func route(prof, kind: String, part: String) -> void:
	if not NATURAL.has(kind) or not part in PARTS:
		return
	var routes: Dictionary = state(prof)["routes"]
	if part == NATURAL[kind]:
		routes.erase(kind)
	else:
		routes[kind] = part


## Banked essence of one kind pools raw in its part (profile.gd bank).
static func settle(prof, kind: String, amount: float) -> void:
	if amount <= 0.0:
		return
	var part := part_for(prof, kind)
	var pd: Dictionary = prof.part_density.get(part, {})
	pd[kind] = float(pd.get(kind, 0.0)) + amount
	prof.part_density[part] = pd


## A part's raw density: what's pooled there, plus the path's flow running through it.
static func raw(prof, part: String) -> float:
	var total := 0.0
	var pd: Dictionary = prof.part_density.get(part, {})
	for k in pd:
		total += float(pd[k])
	if prof.path != "":
		total += float(prof.flow) * FLOW_SHARE
	return total


static func level_for(amount: float) -> int:
	var lv := 1
	for i in LEVELS.size():
		if amount >= float(LEVELS[i]):
			lv = i + 1
	return lv


static func level(prof, part: String) -> int:
	return level_for(raw(prof, part))


## Raw density to the next level (0 at the top).
static func next_need(prof, part: String) -> float:
	var lv := level(prof, part)
	if lv >= LEVELS.size():
		return 0.0
	return float(LEVELS[lv]) - raw(prof, part)


## How many essences a technique from this part can combine.
static func max_kinds(prof, part: String) -> int:
	var lv := level(prof, part)
	var n := 1
	for i in KINDS_AT.size():
		if lv >= int(KINDS_AT[i]):
			n = i + 1
	return n


## How much harder this part's techniques hit (1x at level 1, MAX_POWER at 10).
static func power(prof, part: String) -> float:
	return 1.0 + (MAX_POWER - 1.0) * float(level(prof, part) - 1) / float(LEVELS.size() - 1)


static func has_gift(prof, part: String) -> bool:
	return is_on(prof) and level(prof, part) >= GIFT_LEVEL


## A gift's number (0 without it): "strength", "speed", "health", "cost", "will", "fade".
static func gift(prof, key: String) -> float:
	for part in GIFTS:
		if GIFTS[part].has(key) and has_gift(prof, part):
			return float(GIFTS[part][key])
	return 0.0


## Total raw density (the six parts, plus the flow once).
static func total(prof) -> float:
	var t := 0.0
	for part in prof.part_density:
		for k in prof.part_density[part]:
			t += float(prof.part_density[part][k])
	if prof.path != "":
		t += float(prof.flow)
	return t


static func stage(prof) -> int:
	var t := total(prof)
	var st := 1
	for i in STAGE_AT.size():
		if t >= float(STAGE_AT[i]):
			st = i + 1
	return st


static func stage_name(prof) -> String:
	return STAGES[stage(prof) - 1]


## The kinds an Unbound can build with: the six, and their path's essence.
static func kinds_for(prof) -> Array:
	var out: Array = ["fire", "water", "air", "stone", "iron", "blade"]
	if prof.path in ["life", "unmaking"]:
		out.append(prof.path)
	return out


# --- becoming Unbound, and going back ------------------------------------------

## Becomes Unbound: no tower bonds from now on (any carried are given up).
## The ready-made techniques fill any empty slots.
static func become(prof) -> void:
	var st := state(prof)
	st["on"] = true
	st["found"] = true
	prof.bonds = {}
	prof.soak = {}
	prof.tally = {}
	var techs: Array = st["techs"]
	var Tech = load("res://scripts/technique.gd")
	for i in PARTS.size():
		if not (techs[i] is Dictionary) or techs[i].is_empty():
			techs[i] = Tech.recipe(Tech.STARTERS[i])
	prof.note("unbound")


## Only the Developer goes back.
static func can_return(prof) -> bool:
	return is_on(prof) and String(prof.core_mark) == "developer"


## The Developer lets the tower beasts mark them again: the densest part
## takes a mark (its bond chosen by what's pooled there), growing from
## SETTLE of its raw density; the other parts keep SETTLE of theirs as soak.
## Returns {part, id} ("" for none).
static func return_to_marks(prof) -> Dictionary:
	if not can_return(prof):
		return {}
	var st := state(prof)
	st["on"] = false
	prof.bonds = {}
	prof.soak = {}
	prof.tally = {}
	var best := ""
	var most := 0.0
	for part in PARTS:
		var r := raw(prof, part)
		if r > most:
			most = r
			best = part
	var id := ""
	if best != "" and most > 0.0:
		id = prof.choose_bond(prof.part_density.get(best, {}), {})
		if id != "":
			prof.add_bond(best, id, false)
			prof.bonds[best]["xp"] = minf(most * SETTLE, float(prof.STEP_XP[prof.STEP_XP.size() - 1]))
	for part in PARTS:
		if not prof.bonds.has(part):
			var r := minf(raw(prof, part) * SETTLE, float(prof.NEW_MARK_SOAK) * float(prof.MARK_FULL) * 0.9)
			if r > 0.0:
				prof.soak[part] = r
	return {"part": best if id != "" else "", "id": id}
