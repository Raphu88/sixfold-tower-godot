extends RefCounted
## The three secret bonds: the Developer, the Designer and the Manipulator.
## Each is a sliver of a Maker's own craft, a set of DEV TOOLS for its theme
## (the bonds, the tower, the creatures). They go much farther than any tower
## bond and share no feature with any other bond, item or essence.
##
## WHO HOLDS WHICH: the profile's `core_mark` ("", "developer", "designer"
## or "manipulator"; one per climber) and `core_depth` (0 to 5). The Makers
## (makers.gd, built alongside) grant it through a meeting and write those
## two fields; everything here only reads them (and the dev tools set them).
## Two more profile fields belong to the secret bonds: `core_xp` (what has
## been banked toward the next depth since the mark was taken) and
## `core_tune` (the Developer's Tune: spell id -> "power", "cost" or "quick").
##
## THE TOOLS: one new tool per depth, from looking (depth 1) to rewriting
## (depth 5). Depths 1 and 2 are built (CAP); 3 to 5 come next: add their
## entries to TOOLS and RING and raise CAP. Every tool costs essence, paid
## like a spell from what the climber carries (see COSTS). They're used from
## the TOOL RING (secret_tools.gd), the same hold gesture as the item ring.
##
## Every word and number is here, so it's easy to rename or retune. Only
## plain mechanical text: nothing that could touch the story.

const Secret := preload("res://scripts/secret.gd")
const Essence := preload("res://scripts/essence.gd")
const Themes := preload("res://scripts/themes.gd")

const ORDER := ["developer", "designer", "manipulator"]
## The deepest depth reachable for now (the next step builds 3 to 5).
const CAP := 2
const MAX_DEPTH := 5

## The bonds. "color" is its Maker's colour (the same as makers.gd).
## "grows": what feeds it (GROWTH has the numbers).
const BONDS := {
	"developer": {"name": "Developer", "the": "the Developer", "maker": "marks", "maker_name": "the Maker of Marks",
		"color": Color(0.56, 0.92, 1.0), "what": "tools for the bonds", "grows": "all essence"},
	"designer": {"name": "Designer", "the": "the Designer", "maker": "towers", "maker_name": "the Maker of Towers",
		"color": Color(1.0, 0.7, 0.32), "what": "tools for the tower", "grows": "Unmaking"},
	"manipulator": {"name": "Manipulator", "the": "the Manipulator", "maker": "creatures", "maker_name": "the Maker of Creatures",
		"color": Color(1.0, 0.44, 0.56), "what": "tools for the creatures", "grows": "Life"},
}

## A tool's cost: `flow` units of secret essence (`flow_kind`: "life",
## "unmaking" or "any" = your path's), paid from the flow you carry (unbanked);
## each unit you don't carry costs SUBSTITUTE ordinary essence instead. Plus
## `essence`: ordinary essence you carry (unbanked), taken from every kind you
## hold in proportion. Looking is cheap, rewriting expensive.
const SUBSTITUTE := 3.0

## The tools, by id. "depth": the depth that unlocks it. "where": "ring" (used
## in a climb from the tool ring) or "train" (between climbs, on the climber
## screen's Core tab). "lasts": "floor" (an Inspect: paid once, it stays for
## the floor; using it again on the same floor is free) or "" (paid each use).
## "reach": how far a targeted tool reaches (px). "tip": the Entity's tip id.
const TOOLS := {
	"dev_inspect": {"bond": "developer", "depth": 1, "name": "Inspect", "where": "ring", "lasts": "floor",
		"cost": {"essence": 6.0, "flow": 1.0, "flow_kind": "any"},
		"short": "Every spell's real numbers",
		"desc": "Shows every spell's real numbers: damage, reach, cost, wind-up, and what each step adds. They show on the spell ring while you aim, and in a panel. Lasts the floor.",
		"tip": "tool_inspect_developer"},
	"dev_tune": {"bond": "developer", "depth": 2, "name": "Tune", "where": "train",
		"short": "Set spells for power, cost or speed",
		"desc": "Between climbs: set each spell you carry for more power, less cost or a quicker wind-up (on the climber screen's Core tab). Each change costs crystal essence.",
		"tip": "tool_tune"},
	"des_inspect": {"bond": "designer", "depth": 1, "name": "Inspect", "where": "ring", "lasts": "floor",
		"cost": {"flow": 2.0, "flow_kind": "unmaking", "essence": 1.0},
		"short": "The floor's whole plan",
		"desc": "Opens the floor's whole plan: rooms, corridors, every trap with its timing, hidden traps and secret walls, and what kind of room lies behind each door (never what it holds). Lasts the floor.",
		"tip": "tool_inspect_designer"},
	"des_switch": {"bond": "designer", "depth": 2, "name": "Switch", "where": "ring", "reach": 380.0,
		"cost": {"flow": 4.0, "flow_kind": "unmaking", "essence": 2.0},
		"short": "A trap off or on, a door open or shut",
		"desc": "At a distance: turns the trap you aim at off (or back on), or opens or shuts an unlocked door. A shut door holds for a while: nobody opens it.",
		"tip": "tool_switch_designer"},
	"man_inspect": {"bond": "manipulator", "depth": 1, "name": "Inspect", "where": "ring", "reach": 360.0,
		"cost": {"flow": 1.0, "flow_kind": "life", "essence": 1.0},
		"short": "A monster's numbers and next attack",
		"desc": "Reads the monster you aim at: its numbers, the essence it carries, and its next attack before it starts. The readout stays over it for the floor.",
		"tip": "tool_inspect_manipulator"},
	"man_calm": {"bond": "manipulator", "depth": 2, "name": "Calm", "where": "ring", "reach": 360.0,
		"cost": {"flow": 3.0, "flow_kind": "life", "essence": 2.0},
		"short": "It ignores you until struck",
		"desc": "Sets the monster you aim at calm: it ignores you until it's struck. Not a great foe.",
		"tip": "tool_calm"},
	"man_feud": {"bond": "manipulator", "depth": 2, "name": "Set against", "where": "ring", "reach": 360.0, "pair": 300.0,
		"cost": {"flow": 5.0, "flow_kind": "life", "essence": 3.0},
		"short": "Two monsters fight each other",
		"desc": "Sets the monster you aim at and the one nearest it against each other: they fight until one falls. Not a great foe.",
		"tip": "tool_feud"},
}

## The tool ring's entries for each bond, in order (only those unlocked show).
## The ring of depth 3 to 5 tools: add their ids here.
const RING := {
	"developer": ["dev_inspect", "dev_tune"],
	"designer": ["des_inspect", "des_switch"],
	"manipulator": ["man_inspect", "man_calm", "man_feud"],
}

## The Developer's Tune: one setting per spell. Multiplies the spell's
## power (everything it does: damage, shields, durations), its cost, or its
## wind-up. Changing a spell's setting costs TUNE_COST crystal essence (of any
## kinds, the largest stocks first); clearing it is free.
const TUNE := {
	"power": {"name": "Power", "desc": "20% more power", "power": 1.2},
	"cost": {"name": "Thrift", "desc": "25% less cost", "cost": 0.75},
	"quick": {"name": "Quick", "desc": "40% quicker wind-up", "windup": 0.6},
}
const TUNE_ORDER := ["power", "cost", "quick"]
const TUNE_COST := 6.0
## The Developer can change the climber's path (Life or Unmaking) at the
## train, from depth 1: all the path's flow resets and flows out of the
## shadow, and a new path starts from nothing. Costs crystal essence.
const PATH_CHANGE_COST := 20.0
const PATH_CHANGE_DEPTH := 1

## Depth growth. "feed": what banked at a stair counts toward it ("essence"
## the six kinds, "life", "unmaking"). "need": banked since the mark for each
## depth (index = depth). The Developer's depths also each ask for ONE of ALSO.
const GROWTH := {
	"developer": {"feed": ["essence", "life", "unmaking"], "need": [0.0, 0.0, 400.0, 900.0, 1600.0, 2600.0], "also": true},
	"designer": {"feed": ["unmaking"], "need": [0.0, 0.0, 60.0, 150.0, 280.0, 450.0], "also": false},
	"manipulator": {"feed": ["life"], "need": [0.0, 0.0, 60.0, 150.0, 280.0, 450.0], "also": false},
}
## The Developer's extra need for each depth, any one of these:
##   mastery    `bonds` of your tower bonds at step `step`
##   knowledge  this many of the Makers' traces (fragments) found (index = depth)
##   favour     a task done for a tower beast (not in the game yet)
##   bribe      an offering the Maker of Marks accepts (not in the game yet)
const ALSO := {
	"mastery": {"bonds": 3, "step": 5},
	"knowledge": [0, 0, 8, 10, 12, 14],
}

## Monsters the Manipulator can't calm or set against another: great foes.
const RESIST := ["beast", "shadow", "mirror", "champion"]
## A Designer's shut door holds this long (seconds) before anyone may open it again.
const DOOR_HOLD := 30.0
## How long a feud lasts at most (seconds), then both go back to you.
const FEUD_TIME := 40.0

## The kind of room behind a door, by the room theme's feature (else its
## kind). Never what it holds: every good room is just "a good room".
const ROOM_KIND := {
	"start": "the way in", "stair": "the stair", "puzzle": "a puzzle", "trap": "traps", "den": "monsters",
	"ambush": "monsters", "pillars": "monsters", "chasm": "a chasm", "spring": "a good room", "cache": "a good room",
	"camp": "a good room", "proving": "the Proving",
}
const ROOM_KIND_BY := {"good": "a good room", "bad": "danger", "calm": "a quiet room", "mixed": "a room", "proving": "the Proving"}

## What each monster does and when: [wind-up state, attack, within (px, 0 =
## any), beyond (px), wind-up (s), damage (x its own), "or" (it may pick the
## next one instead), "odd" (only on its odd turns)]. The Manipulator's
## Inspect reads its next attack from these before it starts (enemy.gd).
const ATTACKS := {
	"slime": [["wind", "Pounce", 110.0, 0.0, 0.6, 1.0]],
	"archer": [["aim", "Arrow", 430.0, 0.0, 0.5, 1.0]],
	"knight": [["wind_slash", "Slash", 75.0, 0.0, 0.6, 1.0], ["wind_lunge", "Lunge", 200.0, 120.0, 0.7, 1.0]],
	"bat": [["wind", "Swoop", 170.0, 0.0, 0.45, 1.0]],
	"thunderling": [["wind_spark", "Spark ring", 75.0, 0.0, 0.9, 1.0]],
	"gryphon": [["wind_rake", "Rake", 95.0, 0.0, 0.55, 1.0], ["wind_dive", "Dive", 0.0, 140.0, 0.75, 1.0, "or"], ["wind_gale", "Gale", 0.0, 0.0, 0.6, 0.5]],
	"lurker": [["wind", "Lunge", 0.0, 70.0, 0.45, 1.0]],
	"shellback": [["wind_bash", "Shell bash", 60.0, 0.0, 0.7, 1.0]],
	"kraken": [["wind_sweep", "Sweep", 200.0, 0.0, 0.7, 1.0, "or"], ["wind_slam", "Slam", 0.0, 0.0, 0.9, 1.0, "or"], ["wind_ink", "Ink", 0.0, 0.0, 0.55, 0.5]],
	"cinder": [["wind_spit", "Ember spit", 210.0, 0.0, 0.6, 1.0]],
	"smith": [["wind_hammer", "Hammer", 75.0, 0.0, 0.85, 1.0]],
	"wyvern": [["wind_tail", "Tail", 105.0, 0.0, 0.6, 1.0], ["wind_breath", "Breath", 210.0, 0.0, 0.8, 1.0, "or"], ["wind_embers", "Embers", 0.0, 0.0, 0.6, 0.5]],
	"scorpling": [["wind_sting", "Sting", 60.0, 0.0, 0.5, 1.0]],
	"ram": [["wind_charge", "Charge", 210.0, 70.0, 0.8, 1.0]],
	"manticore": [["wind_claw", "Claw", 100.0, 0.0, 0.55, 1.0, "or"], ["wind_roar", "Roar", 130.0, 0.0, 0.9, 1.0], ["wind_spikes", "Tail spikes", 0.0, 0.0, 0.6, 0.5]],
	"wisp": [["wind", "Dart", 170.0, 0.0, 0.45, 1.0]],
	"bloomcap": [["wind_lob", "Spores", 340.0, 0.0, 0.9, 1.0]],
	"firebird": [["wind_swoop", "Swoop", 230.0, 0.0, 0.6, 1.0, "or"], ["wind_storm", "Firestorm", 0.0, 0.0, 0.9, 1.0, "or"], ["wind_embers", "Embers", 0.0, 0.0, 0.6, 0.5]],
	"thornhound": [["wind", "Leap", 120.0, 0.0, 0.45, 1.0]],
	"mongrel": [["wind_bite", "Bite", 75.0, 0.0, 0.6, 1.0], ["wind_quills", "Quills", 260.0, 0.0, 0.6, 0.6, "", "odd"]],
	"chimera": [["wind_maul", "Maul", 100.0, 0.0, 0.55, 1.0], ["wind_charge", "Goat charge", 210.0, 0.0, 0.8, 1.0, "or"],
		["wind_breath", "Breath", 210.0, 0.0, 0.8, 1.0, "or"], ["wind_spikes", "Tail spikes", 0.0, 0.0, 0.6, 0.5]],
}
## States that follow a wind-up (the blow itself on its way).
const STRIKING := ["pounce", "lunge", "swoop", "dive", "charge"]

## Every other word.
const TEXT := {
	"ring_title": "TOOLS",
	"train_only": "between climbs",
	"no_tools": "No tools yet",
	"short": "Needs %s",
	"you_carry": "you carry %s",
	"paid": "-%s",
	"no_target": "Nothing to aim at",
	"resists": "A great foe: it won't answer",
	"no_pair": "No other monster near it",
	"calm": "Calm",
	"feud": "Set against each other",
	"off": "Trap off",
	"on": "Trap on",
	"door_open": "Door open",
	"door_shut": "Door shut",
	"door_blocked": "Something stands in the doorway",
	"locked": "Locked: the tool can't open it",
	"inspected": "%s: inspected",
	"panel_close": "%s again to close",
	"plan_title": "THE FLOOR'S PLAN",
	"spells_title": "YOUR SPELLS' REAL NUMBERS",
	"no_spells": "You carry no spells.",
	"secret_wall": "secret wall",
	"hidden": "hidden",
	"wing": "a sealed wing",
	"hidden_room": "a hidden room",
	"trap_timed": "%s  ·  every %ss: warns %ss, fires %ss",
	"trap_plate": "%s  ·  plate: warns %ss, fires %ss, rests %ss",
	"trap_next": "fires in %ss",
	"trap_off": "%s  ·  OFF",
	"door_to": "→ %s",
	"held": "held shut %ds",
	"next": "Next: %s",
	"next_or": "Next: %s or %s",
	"now": "Now: %s  ·  %ss",
	"striking": "Striking: %s",
	"calm_tag": "calm",
	"feud_tag": "fighting",
	"grow_line": "%s deepens to depth %d: %s",
	"depth": "%s  ·  depth %d",
	"need_feed": "%d of %d banked %s since the mark",
	"need_also": "and one of:",
	"capped": "Deeper tools come later",
	"full": "Every depth reached",
	"tune_title": "TUNE",
	"tune_none": "untuned",
	"tune_cost": "Each change costs %d crystal essence (yours: %d).",
	"tune_short": "Needs %d crystal essence (you hold %d)",
	"tune_only_train": "Tune spells between climbs, on the train.",
	"path_title": "CHANGE YOUR PATH",
	"path_line": "Resets your path: all its flow (%d banked) flows out of your shadow, and a new path starts from nothing at the next great foe. Costs %d crystal essence.",
	"path_none": "You have no path yet: the first great foe offers the choice.",
	"path_confirm": "Press again to let it go",
	"path_done": "Your %s flows out of your shadow",
	"path_only_train": "On the train, between climbs.",
}


# --- who holds what (profile fields) ----------------------------------------

## The climber's secret bond ("" for none).
static func bond_of(prof) -> String:
	if prof == null:
		return ""
	var b = prof.get("core_mark")
	return b if b is String and BONDS.has(b) else ""


## Its depth (0 without a bond; at least 1 with one).
static func depth_of(prof) -> int:
	if bond_of(prof) == "":
		return 0
	return clampi(int(prof.get("core_depth")), 1, MAX_DEPTH)


static func has_bond(prof) -> bool:
	return bond_of(prof) != ""


## Gives the climber a secret bond at a depth (the dev tools; the Makers write
## the same two fields). A new bond starts its growth again.
static func grant(prof, bond: String, depth: int) -> void:
	if not BONDS.has(bond):
		return
	if bond_of(prof) != bond:
		prof.set("core_xp", {})
		prof.set("core_tune", {})
	prof.set("core_mark", bond)
	prof.set("core_depth", clampi(depth, 1, MAX_DEPTH))


## Takes the secret bond away (the dev tools).
static func clear(prof) -> void:
	prof.set("core_mark", "")
	prof.set("core_depth", 0)
	prof.set("core_xp", {})
	prof.set("core_tune", {})


static func color(bond: String) -> Color:
	return BONDS.get(bond, BONDS["developer"])["color"]


static func display(bond: String) -> String:
	return BONDS.get(bond, {}).get("name", "")


## The tools unlocked, in ring order (train tools included).
static func tools_for(prof) -> Array:
	var bond := bond_of(prof)
	if bond == "":
		return []
	var d := depth_of(prof)
	return RING[bond].filter(func(id): return int(TOOLS[id]["depth"]) <= d)


## The ring's entries: the unlocked tools (a train tool shows, greyed).
static func ring_tools(prof) -> Array:
	return tools_for(prof)


static func usable_in_climb(id: String) -> bool:
	return TOOLS.get(id, {}).get("where", "") == "ring"


static func has_tool(prof, id: String) -> bool:
	return id in tools_for(prof)


# --- costs ------------------------------------------------------------------

## What a tool will take from what you carry: {ok, flow (from the flow
## carried), essence (ordinary essence, the substitute included), short (what's
## missing, in words, or "")}. `run_essence` kind -> amount, `run_flow` the
## path's flow carried, `path` the climber's path.
static func quote(cost: Dictionary, run_essence: Dictionary, run_flow: float, path: String) -> Dictionary:
	var f_need := float(cost.get("flow", 0.0))
	var kind := String(cost.get("flow_kind", "any"))
	var e_need := float(cost.get("essence", 0.0))
	var flow_ok := path != "" and (kind == "any" or kind == path)
	var from_flow := minf(f_need, run_flow) if flow_ok else 0.0
	var essence := e_need + (f_need - from_flow) * SUBSTITUTE
	var carried := 0.0
	for k in run_essence:
		carried += float(run_essence[k])
	var ok := carried + 0.001 >= essence
	var short := ""
	if not ok:
		short = TEXT["short"] % ("%d more essence" % int(ceil(essence - carried)))
		if f_need > 0.0:
			var fk := Secret.display(path if kind == "any" and path != "" else kind) if kind != "any" or path != "" else "flow"
			short += " (or %d %s)" % [int(ceil(f_need - from_flow)), fk]
	return {"ok": ok, "flow": from_flow, "essence": essence, "short": short}


## Takes a quote's essence from `run_essence` (in proportion to each kind
## held). Returns the essence taken by kind.
static func take_essence(run_essence: Dictionary, amount: float) -> Dictionary:
	var total := 0.0
	for k in run_essence:
		total += float(run_essence[k])
	var taken := {}
	if amount <= 0.0 or total <= 0.0:
		return taken
	var share := minf(1.0, amount / total)
	for k in run_essence.keys():
		var t := float(run_essence[k]) * share
		run_essence[k] = float(run_essence[k]) - t
		taken[k] = t
		if float(run_essence[k]) <= 0.001:
			run_essence.erase(k)
	return taken


## A cost in words: "2 Unmaking + 1 essence" ("any" flow: your path's).
static func cost_text(cost: Dictionary, path: String) -> String:
	var bits: Array = []
	var f := float(cost.get("flow", 0.0))
	if f > 0.0:
		var kind := String(cost.get("flow_kind", "any"))
		var name := Secret.display(kind) if kind != "any" else (Secret.display(path) if path != "" else "flow")
		bits.append("%d %s" % [int(f), name])
	var e := float(cost.get("essence", 0.0))
	if e > 0.0:
		bits.append("%d essence" % int(e))
	var line := " + ".join(bits)
	if f > 0.0:
		line += "  (each %s you don't carry: %d essence)" % ["unit" if String(cost.get("flow_kind", "any")) == "any" else Secret.display(String(cost["flow_kind"])), int(SUBSTITUTE)]
	return line


## The gem colour of a cost's flow part (your path's for "any").
static func flow_color(cost: Dictionary, path: String) -> Color:
	var kind := String(cost.get("flow_kind", "any"))
	if kind == "any":
		kind = path if path != "" else "life"
	return Secret.color(kind)


## Crystal essence held in all (the train's costs are paid from crystals).
static func crystals_held(prof) -> float:
	var t := 0.0
	for c in prof.crystals:
		t += float(c["amount"])
	return t


## Pays `amount` crystal essence from any kinds, the largest stocks first.
## False (nothing taken) if too little is held.
static func spend_crystals(prof, amount: float) -> bool:
	amount = ceilf(amount)
	if crystals_held(prof) + 0.001 < amount:
		return false
	var kinds := {}
	for c in prof.crystals:
		kinds[c["kind"]] = true
	var order: Array = kinds.keys()
	order.sort_custom(func(a, b): return prof.crystal_total(a) > prof.crystal_total(b))
	var need := amount
	for k in order:
		if need <= 0.0:
			break
		var take := minf(need, prof.crystal_total(k))
		if take > 0.0 and prof.spend(k, take):
			need -= ceilf(take)
	return true


# --- growth -----------------------------------------------------------------

## What a stair banks feeds the secret bond (core_xp), and it deepens when
## it has enough (only up to CAP for now). `essence` kind -> amount banked,
## `flow` the path's flow banked, `path` its kind. Returns lines for the banner.
static func on_bank(prof, essence: Dictionary, flow: float, path: String) -> Array:
	var bond := bond_of(prof)
	if bond == "":
		return []
	var xp: Dictionary = _xp(prof)
	var six := 0.0
	for k in essence:
		six += float(essence[k])
	xp["essence"] = float(xp.get("essence", 0.0)) + six
	if path != "" and flow > 0.0:
		xp[path] = float(xp.get(path, 0.0)) + flow
	prof.set("core_xp", xp)
	return grow(prof)


## Deepens the bond while every need of the next depth is met. Lines for a banner.
static func grow(prof) -> Array:
	var lines: Array = []
	var bond := bond_of(prof)
	while bond != "" and depth_of(prof) < CAP and needs_met(prof):
		var d := depth_of(prof) + 1
		prof.set("core_depth", d)
		var names: Array = RING[bond].filter(func(id): return int(TOOLS[id]["depth"]) == d).map(func(id): return TOOLS[id]["name"])
		lines.append(TEXT["grow_line"] % [display(bond), d, ", ".join(names)])
	return lines


static func _xp(prof) -> Dictionary:
	var xp = prof.get("core_xp")
	return xp if xp is Dictionary else {}


## Banked since the mark that counts toward the next depth.
static func fed(prof) -> float:
	var bond := bond_of(prof)
	if bond == "":
		return 0.0
	var xp := _xp(prof)
	var t := 0.0
	for k in GROWTH[bond]["feed"]:
		t += float(xp.get(k, 0.0))
	return t


## The banked amount the next depth needs (-1 at the deepest).
static func next_feed(prof) -> float:
	var bond := bond_of(prof)
	var d := depth_of(prof)
	if bond == "" or d >= MAX_DEPTH:
		return -1.0
	return float(GROWTH[bond]["need"][d + 1])


## The Developer's extra needs: id -> [met, words].
static func also_status(prof) -> Dictionary:
	var d := mini(depth_of(prof) + 1, MAX_DEPTH)
	var m: Dictionary = ALSO["mastery"]
	var full := 0
	for part in prof.bonds:
		if prof.step_for_xp(float(prof.bonds[part]["xp"])) >= int(m["step"]):
			full += 1
	var need_frag: int = ALSO["knowledge"][d]
	var frags := fragments(prof)
	return {
		"mastery": [full >= int(m["bonds"]), "Mastery: %d of your tower bonds at step %d (%d now)" % [int(m["bonds"]), int(m["step"]), full]],
		"knowledge": [frags >= need_frag, "Knowledge: %d of the Makers' traces found (%d now)" % [need_frag, frags]],
		"favour": [false, "A favour: a task done for a tower beast (not in the game yet)"],
		"bribe": [false, "A bribe: an offering the Maker of Marks accepts (not in the game yet)"],
	}


## The Makers' traces found (makers.gd keeps them in profile.makers["fragments"]; 0 without).
static func fragments(prof) -> int:
	var mk = prof.get("makers")
	if mk is Dictionary and mk.get("fragments") is Array:
		return mk["fragments"].size()
	return 0


static func needs_met(prof) -> bool:
	var need := next_feed(prof)
	if need < 0.0 or fed(prof) + 0.001 < need:
		return false
	if GROWTH[bond_of(prof)]["also"]:
		return also_status(prof).values().any(func(v): return v[0])
	return true


## What the next depth needs, in lines (the climber screen).
static func next_lines(prof) -> Array:
	var bond := bond_of(prof)
	if bond == "":
		return []
	var d := depth_of(prof)
	if d >= MAX_DEPTH:
		return [TEXT["full"]]
	var feed_name: String = "essence of every kind" if bond == "developer" else String(BONDS[bond]["grows"])
	var out: Array = ["%s %d needs: %s" % ["Depth" if d < CAP else "Later, depth", d + 1, TEXT["need_feed"] % [int(fed(prof)), int(next_feed(prof)), feed_name]]]
	if GROWTH[bond]["also"]:
		out.append(TEXT["need_also"])
		for k in ["mastery", "knowledge", "favour", "bribe"]:
			var st: Array = also_status(prof)[k]
			out.append(("  [x] " if st[0] else "  [ ] ") + String(st[1]))
	if d >= CAP:
		out.append(TEXT["capped"])
	return out


# --- the Developer: spells' real numbers, and Tune ----------------------------

## A spell's real numbers on a bond (bond.gd), with every multiplier that
## applies (faint, density, gear, flow, Tune): [[label, value text], ...].
## `windup_mult` is the climber's own (Steady Mind).
static func spell_numbers(b, sp: Dictionary, windup_mult := 1.0) -> Array:
	var rows: Array = []
	rows.append(["Cost", "%s essence" % _num(b.spell_cost(sp))])
	rows.append(["Wind-up", "%s s" % _num(b.spell_windup(sp) * windup_mult)])
	var dmg = b.spell_stat(sp, "damage")
	if dmg != null and float(dmg) > 0.0:
		rows.append(["Damage", _num(b.spell_damage(sp))])
	for key in ["reach", "range", "radius", "length", "hop", "leaps", "duration", "shield", "splash", "stun", "lift", "arc"]:
		var v = b.spell_stat(sp, key)
		if v != null and (v is float or v is int) and float(v) > 0.0:
			var val := float(v)
			if key in ["duration", "shield", "splash"]:
				val *= b.spell_power(sp)
			rows.append([key.capitalize(), _num(val) + (" s" if key in ["duration", "stun", "lift"] else ("°" if key == "arc" else ""))])
	return rows


## What each step adds to a spell, from the step that teaches it: ["Step 2: damage 12", ...].
static func step_adds(sp: Dictionary) -> Array:
	var out: Array = []
	var steps: Dictionary = sp["steps"]
	var keys: Array = steps.keys()
	keys.sort()
	for s in keys:
		var bits: Array = []
		for k in steps[s]:
			var v = steps[s][k]
			if v is bool:
				if v:
					bits.append(String(k))
			elif v is float or v is int:
				bits.append("%s %s" % [String(k), _num(float(v))])
		out.append("Step %d: %s" % [int(s), ", ".join(bits)])
	return out


## The Tune multiplier for one of a spell's numbers ("power", "cost", "windup").
static func tune_mult(tunes: Dictionary, spell_id: String, key: String) -> float:
	var mode := String(tunes.get(spell_id, ""))
	if mode == "" or not TUNE.has(mode):
		return 1.0
	return float(TUNE[mode].get(key, 1.0))


## The Tune settings the climber's bonds use ({} unless the Developer at depth 2+).
static func active_tunes(prof) -> Dictionary:
	if bond_of(prof) != "developer" or depth_of(prof) < int(TOOLS["dev_tune"]["depth"]):
		return {}
	var t = prof.get("core_tune")
	return t if t is Dictionary else {}


## Sets a spell's Tune (paid from crystals; "" clears it for free). "" if done, else why not.
static func set_tune(prof, spell_id: String, mode: String) -> String:
	if bond_of(prof) != "developer" or depth_of(prof) < int(TOOLS["dev_tune"]["depth"]):
		return "Tune needs the Developer at depth 2"
	var tunes: Dictionary = active_tunes(prof).duplicate()
	if String(tunes.get(spell_id, "")) == mode:
		return ""
	if mode != "":
		if not TUNE.has(mode):
			return "No such setting"
		if not spend_crystals(prof, TUNE_COST):
			return TEXT["tune_short"] % [int(TUNE_COST), int(crystals_held(prof))]
		tunes[spell_id] = mode
	else:
		tunes.erase(spell_id)
	prof.set("core_tune", tunes)
	return ""


static func _num(f: float) -> String:
	if absf(f - roundf(f)) < 0.001:
		return "%d" % int(roundf(f))
	return ("%.2f" % f).rstrip("0").rstrip(".")


# --- the Designer: the floor's plan -------------------------------------------

## The kind of room a theme makes (never what it holds).
static func room_kind(theme_id: String) -> String:
	var th: Dictionary = Themes.get_theme(theme_id)
	var f := String(th.get("feature", ""))
	if ROOM_KIND.has(f):
		return ROOM_KIND[f]
	return ROOM_KIND_BY.get(String(th.get("kind", "")), "a room")


## A trap's timing as a readout line.
static func trap_line(tr: Dictionary, traps_script) -> String:
	var k: Dictionary = traps_script.KINDS[tr["kind"]]
	var name := String(k["name"]).capitalize()
	if tr.get("off", false):
		return TEXT["trap_off"] % name
	if String(tr.get("trigger", k["trigger"])) == "timed":
		return TEXT["trap_timed"] % [name, _num(traps_script.val(tr, "cycle")), _num(traps_script.val(tr, "warn")), _num(snappedf(traps_script.val(tr, "fire"), 0.01))]
	return TEXT["trap_plate"] % [name, _num(traps_script.val(tr, "warn")), _num(snappedf(traps_script.val(tr, "fire"), 0.01)), _num(traps_script.val(tr, "rest"))]


## Everything the Designer's Inspect shows on a floor, as entries
## {type: "room"/"door"/"trap"/"secret"/"wing"/"stair", pos, text, ...}.
## Never a reward: a good room is "a good room", a hidden one "a hidden room".
static func plan_entries(main) -> Array:
	var out: Array = []
	var infos: Array = main.room_info
	for i in infos.size():
		var th: String = main.room_themes[i] if i < main.room_themes.size() else "quiet"
		out.append({"type": "room", "pos": infos[i]["rect"].get_center(), "rect": infos[i]["rect"], "text": room_kind(th), "index": i})
	if main.door_view != null:
		for d in main.door_view.list:
			var kind := ""
			if String(d.get("fixed", "")) == "sealed":
				kind = TEXT["wing"]
			elif int(d["room"]) >= 0 and int(d["room"]) < main.room_themes.size():
				kind = room_kind(main.room_themes[int(d["room"])])
			else:
				kind = "a room"
			out.append({"type": "door", "pos": d["rect"].get_center(), "rect": d["rect"], "text": TEXT["door_to"] % kind,
				"locked": String(d["lock"]) != "", "open": bool(d["open"]), "door": d})
	for tr in main.traps:
		out.append({"type": "trap", "pos": tr["pos"], "text": trap_line(tr, main.Traps), "hidden": bool(tr.get("hidden", false)), "trap": tr})
	if main.wings != null:
		for s in main.wings.secrets:
			out.append({"type": "secret", "pos": main.wings._tile_center(s["mouth"][0]), "text": TEXT["secret_wall"], "rect": s["rect"],
				"open": bool(s["open"]), "room_text": TEXT["hidden_room"]})
		for w in main.wings.wings:
			out.append({"type": "wing", "pos": w["rect"].get_center(), "rect": w["rect"], "text": TEXT["wing"]})
	if main.layout_on:
		out.append({"type": "stair", "pos": main.stair_pos, "text": "the stair"})
	return out


# --- the Manipulator: monsters --------------------------------------------------

## Which kind of great foe a monster is ("" for an ordinary one).
static func resists(e) -> bool:
	return Secret.great_foe(e) in RESIST


## The monster's next attack: {name, state, wind, now (winding up or striking),
## left (seconds of wind-up left), or (the other it may pick)}.
static func predict(e, dist: float) -> Dictionary:
	var rules: Array = ATTACKS.get(e.kind, [])
	if rules.is_empty():
		return {}
	var st: String = e.state
	for r in rules:
		if r[0] == st:
			return {"name": r[1], "state": r[0], "wind": r[4], "now": true, "left": maxf(0.0, float(e.state_t)), "dmg": float(r[5]) * e.dmg}
	if st in STRIKING:
		return {"name": rules[0][1] if rules.size() == 1 else st.capitalize(), "state": st, "now": true, "striking": true, "left": 0.0, "dmg": e.dmg}
	for i in rules.size():
		var r: Array = rules[i]
		if float(r[2]) > 0.0 and dist >= float(r[2]):
			continue
		if dist <= float(r[3]):
			continue
		if r.size() > 7 and r[7] == "odd" and int(e.turn) % 2 == 0:
			continue
		var out := {"name": r[1], "state": r[0], "wind": r[4], "now": false, "dmg": float(r[5]) * e.dmg}
		if r.size() > 6 and r[6] == "or" and i + 1 < rules.size():
			out["or"] = rules[i + 1][1]
		return out
	var r0: Array = rules[0]
	return {"name": r0[1], "state": r0[0], "wind": r0[4], "now": false, "dmg": float(r0[5]) * e.dmg}


## The readout over an inspected monster: a few short lines.
static func monster_lines(e, dist: float, floor_num: int, tower: String) -> Array:
	var lines: Array = []
	lines.append("%s  %d/%d" % [String(e.kind).capitalize(), int(ceil(e.hp)), int(ceil(e.max_hp))])
	lines.append("dmg %s  ·  speed %d" % [_num(snappedf(e.dmg, 0.1)), int(e.speed)])
	var d: Array = Essence.drop_for(e.kind, floor_num)
	var ess := "%d %s" % [int(round(float(d[1]))), Essence.display(d[0])]
	var sec: Dictionary = Secret.drop(Secret.great_foe(e), tower, floor_num)
	for k in sec:
		ess += ", %d %s" % [int(round(float(sec[k]))), Secret.display(k)]
	lines.append("carries " + ess)
	var nx := predict(e, dist)
	if not nx.is_empty():
		if nx.get("striking", false):
			lines.append(TEXT["striking"] % nx["name"])
		elif nx["now"]:
			lines.append(TEXT["now"] % [nx["name"], _num(snappedf(nx["left"], 0.1))])
		elif nx.has("or"):
			lines.append(TEXT["next_or"] % [nx["name"], nx["or"]])
		else:
			lines.append(TEXT["next"] % nx["name"])
	return lines
