extends RefCounted
## The Unbound: climbers who refuse the tower beasts' marks. Every word and
## number about them is here (techniques in technique.gd, the climb's
## running state in unbound_run.gd, the pages in technique_page.gd, the core
## essence and the aura in core.gd).
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
## NODES. The Unbound's six body parts are called NODES (the Hand Node, the
##   Legs Node...; marked climbers keep "body parts"). A Node has two numbers:
##   what it HOLDS (profile.part_density: part -> {kind: amount}; it powers
##   the Node's techniques and can be moved) and its SIZE, its density
##   (state "size": how much it can hold, 0 to CAP 120). It never holds more
##   than its size: banked essence that doesn't fit condenses into crystals
##   (essence is never lost).
##   ASLEEP: a Node starts asleep, at size 0, holding nothing. Banked essence
##     routed to it (its natural kind: Blade the hand, Air the legs...; or
##     wherever a kind is ROUTED at the train) soaks into it and grows its
##     size, GROW_COST banked essence for 10 more at its level; moving
##     essence into it feeds it the same way. At WAKE_SIZE (30) it AWAKENS.
##     While it sleeps the player sees no numbers for it, only that it sleeps.
##   AWAKE: banked essence tops up what it holds (up to its size). Its size
##     grows by USE: what its techniques spend (and the boosts they pay), or
##     before it has a technique what its own action does (USE weights),
##     asks for that much back at the next stair; the essence banked into the
##     Node that refills it is used up, stretching it (GROW_COST for 10 at
##     its level). There is no cap a climb: banked essence (refills cost it)
##     and strain (pushing techniques builds strain toward an eruption) hold
##     the pace. Use not refilled at a stair is gone, so casting more than you
##     bank adds nothing. Moving essence never changes a size. (note_use,
##     settle_into.)
##   SEALING (the Unbound choose; the marked can't): on the train, on the
##     Body tab (node_seal.gd), an Unbound can SEAL a Node. A sealed Node
##     takes no essence: banked essence that would pool there (its natural
##     kind, or routed there) flows to the open Nodes instead (part_for:
##     the biggest open Node; routing skips sealed Nodes). Sealing gives the
##     Node up: what it holds condenses into crystals, its size is gone, and
##     with it its technique, gift, minor ability and attributes. At least
##     one Node stays open. Each sealed Node makes the open ones stronger:
##     their growth from refilled use (SEAL "growth") and their techniques'
##     power (SEAL "power"). Unsealing is allowed: the Node starts asleep at
##     size 0. (seal, unseal, sealed, growth_mult, seal_power.)
##   A FALL DRAINS THEM (drain): the guardians hunt the Unbound, and a fall
##     (after the first climb) drains DRAIN "share" of what every Node holds
##     back into the well, keeping a trace of each Node's lead; sizes and the
##     core essence are kept, and the next stairs refill them. Now and then
##     one of the Sworn saves them from it (sworn.gd). Drained too often,
##     climbers say, the Unbound are hollowed into Husks (the Bestiary).
##   On the climber screen's Body tab (body_move.gd), whenever no monster is
##   after the climber, essence can be MOVED from one awake Node to another,
##   or fed to a sleeping one; a share of it is the price (MOVE_COST):
##   unmade on the Unmaking path, turned into core essence on the Making
##   path, condensed into crystals before a path is chosen.
##   PRIMARY: the first essence in a Node leads it and must stay at least
##   half of the Node's own essence (an essence that would push it under
##   can't come in). At most MAX_KINDS kinds a Node. The others are
##   MODIFIERS: each adds its touch to every technique of the Node, stronger
##   the bigger its share. The core essence (core.gd) takes room in every
##   Node and adds its own touch, but counts for neither rule; once it's at
##   least half of what a Node holds, the Node is CORE-LED: the core leads
##   it, its technique becomes a core technique (CORE_TECHS, stronger at
##   level 6 and again at 12: CORE_POWER) and the core slowly absorbs the
##   other essences (core.gd ABSORB).
##   LEVELS: a sleeping Node is level 0; it wakes at level 1 (WAKE_SIZE 30)
##   and the levels run to MAX_LEVEL (12) at size 120 (the LEVELS table).
##   Level MINOR_LEVEL (1, waking) brings the Node's MINOR ability (a touch
##   of its lead essence on its own action), TECH_LEVEL (3) a YOUNG technique
##   (limited: its first form only, its lead essence only, YOUNG_POWER
##   strength), GIFT_LEVEL (5) its gift, FULL_TECH_LEVEL (6) the full
##   technique (its other essences join, its other starting forms open, full
##   strength; change its form on the Techniques tab), then the tree's forks
##   and forms, and at MAX_LEVEL its capstone, and its SIGNATURE if one
##   essence fills it all (a pure Node). Growth costs go by size, in bands of
##   COST_BAND (10): GROW_COST.
##   The total size sets the STAGE.
##   ATTRIBUTES (Agility, Strength...: profile.gd attribute) come from the
##   awake Nodes' sizes: each Node's size counts for the essences it holds,
##   in proportion (attr_size); ATTR "half" is where a bonus is half its cap.
## Profile state lives in profile.unbound (state() fills in its keys).

const Core := preload("res://scripts/core.gd")

const PARTS := ["hand", "legs", "heart", "brow", "throat", "back"]
static var PART_NAMES := {"hand": "Hand", "legs": "Legs", "heart": "Heart", "brow": "Brow", "throat": "Throat", "back": "Back"}
## The six kinds and their natural parts.
const NATURAL := {"blade": "hand", "air": "legs", "stone": "back", "water": "throat", "fire": "brow", "iron": "heart"}
## Each part's main colour (its natural essence's), for the veins.
const PART_KIND := {"hand": "blade", "legs": "air", "back": "stone", "throat": "water", "brow": "fire", "heart": "iron"}
## Growth costs go by size, in bands of this much (GROW_COST).
const COST_BAND := 10.0
## (The old name: a band of size.)
const LEVEL_SIZE := COST_BAND
const MAX_LEVEL := 12
## The size each level needs (index = level - 1): level 1 is waking (30),
## level 12 is full (120).
static var LEVELS := [30.0, 38.0, 46.0, 54.0, 62.0, 70.0, 78.0, 86.0, 94.0, 102.0, 111.0, 120.0]
## Essence that ten more size take, in each band of COST_BAND size (index =
## floor(size / 10)): banked essence soaked in while it sleeps (sizes 0-30),
## and refilled use once it's awake. Slow, and slower the bigger the Node.
## (With no cap a climb, banked essence alone holds the pace:
## tests/progression_model.gd run_unbound, held to its bands by
## tests/parts/unbound_cup.gd.)
static var GROW_COST := [60.0, 90.0, 120.0, 143.0, 179.0, 246.0, 355.0, 497.0, 687.0, 950.0, 1330.0, 1871.0]
## Growth by use. Essence a Node's technique spends on a cast counts "cast"
## times as use, a boost's essence "boost" times; before the Node has a
## technique, its own action (what would fill one: player.gd _part_action)
## counts "action" times. No cap a climb: banked essence and strain hold the pace.
## ONE RULE for marks and Nodes (mark_use.gd USE "other" is the same): a
## Node's refill is paid in full by its own kinds (its natural kind, and the
## essence that leads it); any other kind banked into it
## (routed there, or flowing on from a sealed Node) pays only "other" of its
## amount: three of another kind refill what one of its own would, as for
## marks. (A sleeping Node soaks any kind in full: routing wakes Nodes.)
static var USE := {"cast": 2.0, "boost": 2.0, "action": 0.5, "other": 1.0 / 3.0}
## Sealing: each sealed Node makes every open Node's growth from refilled use
## "growth" faster and its techniques "power" stronger (adding up: two
## sealed, twice that). Banked essence that would pool in a sealed Node
## flows on to an open one ("flow" of it), where as another kind it pays
## only USE "other" of a refill (the one rule); what no Node can take
## condenses into crystals. A focused
## Unbound trades breadth for depth, not speed: one open Node reaches level
## 12 a little sooner than a broad climber's main Node, not drastically
## (tests/progression_model.gd run_unbound with `sealed`; held by
## tests/parts/sealing.gd).
static var SEAL := {"growth": 0.04, "power": 0.06, "flow": 1.0}
## A fall drains what the Nodes hold back into the well (drain): "share" of
## each essence in every Node goes (a measured choice: draining all of it
## would push all six Nodes to level 12 past the owner's pace, 79 climbs
## against tests/parts/unbound_cup.gd ALL_TOP's 66 to 78; two thirds keeps
## it at 77), each Node keeping at least a "trace" of its lead essence (its
## shape: lead, technique, minor ability). Sizes and the core essence are
## kept. "husk_talk": after this many drained falls the Entity speaks of the Husks.
static var DRAIN := {"share": 0.67, "trace": 1.0, "husk_talk": 3}
## Attributes from the Nodes' sizes: an attribute's bonus is half its cap
## (profile.gd ATTRIBUTE_CAP) at "half" size counted for its essence.
static var ATTR := {"half": 60.0}
const MINOR_LEVEL := 1
## A young technique: its first form, its lead essence alone, weaker.
const TECH_LEVEL := 3
const GIFT_LEVEL := 5
## The full technique: its other essences join, its other forms open.
const FULL_TECH_LEVEL := 6
## A young technique's strength at TECH_LEVEL, rising to 1x at FULL_TECH_LEVEL.
const YOUNG_POWER := 0.6
## A sleeping Node awakens at this size (level 1, MINOR_LEVEL: its minor ability wakes).
const WAKE_SIZE := 30.0
## Kinds of essence a part holds at most (the core essence not counted).
const MAX_KINDS := 3
## A part's core essence must be at least this much to lead it.
const CORE_LED_MIN := 6.0
## Techniques from a part hit this much harder at level 12 (1x at FULL_TECH_LEVEL).
const MAX_POWER := 2.0
## A modifier essence acts at twice its share of the part's own essence (at
## most 1, at least MOD_MIN); the core at twice its share of all the part
## holds (at most CORE_MOD); in a core-led part the other essences add only
## LED_MOD of theirs.
const MOD_MIN := 0.15
const CORE_MOD := 0.75
const LED_MOD := 0.25
## A core technique hits this much harder: from FULL_TECH_LEVEL, and full.
const CORE_POWER := [1.5, 2.0]
## Each part's gift at GIFT_LEVEL.
const GIFTS := {
	"hand": {"name": "Heavy Hands", "desc": "strikes 15% harder", "strength": 0.15},
	"legs": {"name": "Light Feet", "desc": "walk 8% faster", "speed": 0.08},
	"heart": {"name": "Deep Heart", "desc": "15% more health", "health": 0.15},
	"brow": {"name": "Clear Brow", "desc": "techniques cost 25% less", "cost": 0.25},
	"throat": {"name": "Long Breath", "desc": "stamina back 20% faster", "will": 0.2},
	"back": {"name": "Broad Back", "desc": "strain fades twice as fast", "fade": 2.0},
}
## The minor ability (MINOR_LEVEL): now and then the part's own action (what
## fills it) carries a touch of its lead essence to the nearest foe within
## "reach" ("chance" each time, at most once every "cd" seconds; a small blow
## of "damage" at "share" of the essence's strength).
static var MINOR := {"chance": 0.35, "cd": 1.5, "damage": 4.0, "share": 0.5, "reach": 90.0}
const MINOR_ACTS := {"hand": "your weapon strikes", "legs": "your rolls", "heart": "the blows you survive",
	"brow": "your parries", "throat": "a swing that catches several foes", "back": "your backstabs and finishing blows"}
## The stages, from the body's total fill (index = stage - 1).
const STAGES := ["Stir", "Pulse", "Current", "Surge", "Swell", "Torrent", "Tide", "Tempest", "Deluge", "Maelstrom", "Cataclysm", "Unbound"]
const STAGE_AT := [0.0, 24.0, 60.0, 108.0, 168.0, 240.0, 324.0, 408.0, 492.0, 576.0, 660.0, 720.0]
## At a summit the Unbound condense this much of the tower's essence into a
## Node of their choice: it grows it as that much refilled use would (or
## soaks into a sleeping one), and tops up what it holds.
static var CONDENSE := 60.0
## Moving essence (body_move.gd): this much at a press, and the share it costs.
const MOVE_STEP := 6.0
const MOVE_COST := 0.25
## Going back (the Developer): the densest part takes a mark, its bond
## chosen by what's pooled there, starting with this share of its fill as
## growth; every other part keeps this share as soak.
const SETTLE := 0.5
## A pure part's signature at MAX_LEVEL: "part:kind" -> {name, says, form}.
## Only the ones with a written form can be cast; the others show as
## "Coming soon" (a pure part still shows its name).
static var SIGNATURES := {
	"legs:air": {"name": "Blink", "says": "You vanish and reappear where you aim, a short way off, untouchable for a moment", "form": "blink"},
	"hand:blade": {"name": "Thousand Cuts", "says": "Coming soon"},
	"back:stone": {"name": "Bastion", "says": "Coming soon"},
	"throat:water": {"name": "Maelstrom Call", "says": "Coming soon"},
	"brow:fire": {"name": "Sunstare", "says": "Coming soon"},
	"heart:iron": {"name": "Iron Heart", "says": "Coming soon"},
}
## A core-led part's technique: its name by part and core essence (its form
## is the part's own; the core leads it). Placeholder names for the owner to change.
static var CORE_TECHS := {
	"hand": {"life": "Mending Hands", "unmaking": "Unmaking Hands"},
	"legs": {"life": "Greenstride", "unmaking": "Hollow Step"},
	"heart": {"life": "Making Heart", "unmaking": "Hollow Heart"},
	"brow": {"life": "Making Gaze", "unmaking": "Unmaking Gaze"},
	"throat": {"life": "Making Word", "unmaking": "Unmaking Word"},
	"back": {"life": "Making Mantle", "unmaking": "Unmaking Mantle"},
}

static var TEXT := {
	"name": "Unbound",
	"node": "%s Node",
	"asleep": "asleep",
	"refuse_title": "THE BEAST OFFERS A MARK",
	"refuse_lines": ["Take it, and you are marked as every climber is.", "Refuse it, and essence wakes your body raw. There is no road back."],
	"accept_name": "Accept the mark",
	"accept_desc": "Take the %s mark on your %s. Your bonds grow as they always have.",
	"refuse_name": "Refuse it",
	"refuse_desc": "Become Unbound: no tower bond, now or later. Banked essence wakes six Nodes in your body; each grows as you use it and gives you techniques of your own.",
	"refuse_note": "for good",
	"refuse_again": "Tap again to refuse, for good",
	"refuse_again_keys": "Press again to refuse, for good",
	"refused_title": "REFUSED",
	"refused_lines": ["You broke a barrier on your first climb.", "%s will not mark you.", "You are Unbound.", "Banked essence will wake six Nodes in your body."],
	"accepted": "Essence takes hold in your %s: the %s mark",
	"stage": "%s  ·  stage %d of 12",
	"climber_line": "Unbound  ·  %s  ·  %d %s  ·  best floor %d",
	"level": "level %d",
	"condense_title": "CONDENSE",
	"condense_sub": "No mark for the Unbound. Draw the tower's %s essence into one Node.",
	"condense_card": "%s",
	"condense_desc": "%s essence stretches your %s: size %s of 120, level %d.",
	"condense_sleep": "%s essence soaks into your sleeping %s, bringing it closer to waking.",
	"condense_full": "Your %s is as big as it grows. The %s essence tops up what it holds.",
	"condensed": "%s essence condenses into your %s",
	"back_title": "MARKED AGAIN",
	"back": "Raw essence settles back into a bond: the %s mark on your %s.",
	"back_none": "Raw essence settles back into you. Your next marks will come sooner.",
	# Waking and growing, at the stair.
	"level_up": "Your %s grows to level %d",
	"awake_up": "Your %s awakens: %s",
	"tech_up": "Your %s reaches level %d: it learns %s",
	"full_tech_up": "Your %s reaches level %d: its technique comes into its own (its other essences join, its other forms open, full strength)",
	"young": "Young technique: its first form and its lead essence only, %d%% strength. At level %d its other essences join and its other forms open.",
	"full_up": "Your %s reaches level 12: %s",
	"pure_up": "Pure %s fills your %s: %s",
	"grew": "Your %s grows with use (size %s)",
	"spill": "Your %s can't hold more %s: %d condenses into crystals",
	"core_led": "Your %s is core-led: %s",
	"minor": "Now and then %s carry a touch of %s: %s.",
	"minor_none": "Its minor ability wakes when it awakens (level %d).",
	# Moving essence (body_move.gd).
	"moved": "Moved %s %s from your %s to your %s",
	"fed": "Fed %s %s from your %s to your sleeping %s",
	"drained": "Drained %s %s from your %s: %s crystals",
	"cost_unmade": "%s unmade",
	"cost_core": "%s turned into Making",
	"cost_crystals": "%s condensed into crystals",
	"cant_kinds": "Your %s already holds three kinds",
	"cant_primary": "%s must stay at least half of your %s",
	"cant_full": "Your %s is full: it grows only with use",
	"cant_empty": "No %s in your %s",
	"cant_asleep": "Your %s is asleep: it holds nothing yet",
	"cant_sealed": "Your %s is sealed: it takes no essence",
	"spill_sealed": "%s essence finds its Node sealed: %d condenses into crystals on the way to your open Nodes",
	# Sealing (node_seal.gd has the Body tab's words).
	"sealed": "sealed",
	"seal_unbound": "Only the Unbound can seal a Node",
	"seal_already": "Your %s is already sealed",
	"seal_train": "Sealing and unsealing happen only on the train",
	"seal_last": "At least one Node stays open",
	"sealed_line": "Sealed your %s: what it held condensed into %d crystals",
	"unseal_open": "Your %s isn't sealed",
	"unsealed_line": "Unsealed your %s: it starts again asleep, at size 0",
	# A fall (drain): the fall screen's first line.
	"fall_drained": "Caught and drained: %d essence from your Nodes runs back into the well. Their sizes are kept; the next stairs refill them.",
}


## The climber's Unbound state, with every key filled in (old saves have none).
## ("size" is left out here: _sizes() makes it, converting an old save.)
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
	if not (st.get("primary") is Dictionary):
		st["primary"] = {}  # part -> the kind that leads it
	if not (st.get("core") is Dictionary):
		st["core"] = {}  # part -> core essence there (core.gd)
	if not (st.get("seen") is Dictionary):
		st["seen"] = {}  # part -> the highest level it has shown (the first-time moments)
	if not (st.get("used") is Dictionary):
		st["used"] = {}  # part -> use waiting to be refilled at the next stair (note_use)
	if not (st.get("grown") is Dictionary):
		st["grown"] = {}  # part -> size grown by use this climb (the stair's "grows with use" line)
	if not (st.get("sealed") is Dictionary):
		st["sealed"] = {}  # part -> true: sealed (seal); old saves have none
	return st


static func is_on(prof) -> bool:
	return prof != null and bool(state(prof).get("on", false))


## A Node's name: "Hand Node".
static func node_name(part: String) -> String:
	return TEXT["node"] % PART_NAMES.get(part, part)


## An old save's cups made to fit (an older Unbound's huge raw density):
## each part's own essence at most CAP, at most MAX_KINDS kinds; then its
## Nodes made from them (_sizes: each part's fill becomes its size).
static func tidy(prof) -> void:
	if not is_on(prof):
		return
	for part in prof.part_density.keys():
		var pd = prof.part_density[part]
		if not (pd is Dictionary) or not part in PARTS:
			prof.part_density.erase(part)
			continue
		var kinds: Array = pd.keys().filter(func(k): return float(pd[k]) > 0.0)
		kinds.sort_custom(func(a, b): return float(pd[a]) > float(pd[b]))
		var keep := {}
		for k in kinds.slice(0, MAX_KINDS):
			keep[k] = float(pd[k])
		var t := 0.0
		for k in keep:
			t += float(keep[k])
		if t > Core.CAP:
			for k in keep:
				keep[k] = float(keep[k]) * Core.CAP / t
		prof.part_density[part] = keep
	_sizes(prof)
	Core.sync(prof)


# --- the Nodes' sizes ---------------------------------------------------------------------

## The Nodes' sizes (state "size": part -> size). An Unbound from before the
## Nodes has none yet: each part's fill (its own essence and core) becomes
## its Node's size, so no growth is lost. A Node under WAKE_SIZE stays asleep
## and keeps that size as its progress toward waking; it holds nothing, so
## its own essence condenses into crystals (its core stays).
static func _sizes(prof) -> Dictionary:
	var st := state(prof)
	if st.get("size") is Dictionary:
		return st["size"]
	var sz := {}
	if not bool(st.get("on", false)):
		return sz  # (a marked climber: no Nodes, nothing kept)
	st["size"] = sz
	for part in PARTS:
		var c := float(st["core"].get(part, 0.0))
		var s := minf(Core.CAP, own(prof, part) + c)  # (its old fill: its level is kept)
		sz[part] = s
		if s < WAKE_SIZE - 0.0001:
			var pd = prof.part_density.get(part, {})
			if pd is Dictionary:
				for k in pd:
					var whole := floorf(maxf(0.0, float(pd[k])))
					if whole >= 1.0:
						prof.add_crystal(String(k), whole)
			prof.part_density.erase(part)
			st["primary"].erase(part)
	return sz


## A Node's size: its density, how much of its own essence it can hold (0
## to CAP). It is never less than what it holds (essence put straight in by
## the dev tools or a test stretches it). A sealed Node's is 0.
static func size(prof, part: String) -> float:
	if sealed(prof, part):
		return 0.0
	var sz := _sizes(prof)
	var s := float(sz.get(part, 0.0))
	var held := own(prof, part)
	if held > s + 0.0001 and is_on(prof):
		s = minf(Core.CAP, held)
		sz[part] = s
	return s


## True once a Node has awakened (size WAKE_SIZE). Asleep, it holds nothing,
## shows no numbers, and only soaks up the essence routed to it.
static func awake(prof, part: String) -> bool:
	return is_on(prof) and size(prof, part) >= WAKE_SIZE - 0.0001


## Sets a Node's size outright (the dev tools, tests): what it holds kept within it.
static func set_size(prof, part: String, s: float) -> void:
	_sizes(prof)[part] = clampf(s, 0.0, Core.CAP)
	var pd = prof.part_density.get(part, {})
	var o := own(prof, part)
	if pd is Dictionary and o > s and o > 0.0:
		for kind in pd.keys():
			pd[kind] = float(pd[kind]) * s / o


## Sets what the Nodes hold (part -> {kind: amount}) and makes each Node's
## size exactly that (the dev tools and tests: a quick way to a level).
static func set_nodes(prof, holds: Dictionary) -> void:
	prof.part_density = holds.duplicate(true)
	var sz := _sizes(prof)
	for part in PARTS:
		sz[part] = minf(Core.CAP, own(prof, part))


## The same for one Node.
static func set_node(prof, part: String, holds: Dictionary) -> void:
	prof.part_density[part] = holds.duplicate(true)
	_sizes(prof)[part] = minf(Core.CAP, own(prof, part))


## Grows a Node by `essence` worth (GROW_COST for 10 at each level, divided
## by `rate`: the sealed Nodes' bonus), up to `top` size. Returns the essence used.
static func _grow(prof, part: String, essence: float, top: float, rate := 1.0) -> float:
	var left := essence
	var sz := _sizes(prof)
	top = minf(top, Core.CAP)
	for _i in 64:
		var s := size(prof, part)
		if left <= 0.0001 or s >= top - 0.0001:
			break
		if s >= Core.CAP - 0.0001:
			break
		var b := cost_band(s)
		var cost := float(GROW_COST[b]) / maxf(0.01, rate)
		var to_next := minf(float(b + 1) * COST_BAND - s, top - s)
		if to_next <= 0.0001:
			to_next = minf(COST_BAND, top - s)
		var g := minf(left * COST_BAND / cost, to_next)
		if g <= 0.00001:
			break
		sz[part] = s + g
		left -= g * cost / COST_BAND
	return essence - maxf(0.0, left)


## Use waiting to be refilled at the next stair.
static func used(prof, part: String) -> float:
	return float(state(prof)["used"].get(part, 0.0))


## A Node was used: `essence` spent by its technique ("cast"), on a boost
## ("boost"), or its own action before it has a technique ("action"). It asks
## for that much (times USE[how]) back at the next stair. Asleep, nothing.
static func note_use(prof, part: String, essence: float, how := "cast") -> void:
	if essence <= 0.0 or not part in PARTS or not awake(prof, part):
		return
	var st := state(prof)
	st["used"][part] = used(prof, part) + essence * float(USE.get(how, 1.0))


## A new climb: use left from the last climb is gone (and the count behind
## the stair's "grows with use" line starts again).
static func new_climb(prof) -> void:
	var st := state(prof)
	st["used"] = {}
	st["grown"] = {}


## After a stair: use that wasn't refilled is gone (casting more than you
## bank adds nothing).
static func end_stair(prof) -> void:
	state(prof)["used"] = {}


## An Unbound's fall (main.gd on_player_died): the guardians catch them and
## what their Nodes HOLD is drained back into the well (lost: not crystals):
## DRAIN "share" of every essence in every Node, each Node keeping at least a
## TRACE of its lead essence (DRAIN "trace"), so a Node keeps its shape: its
## lead, its technique and its minor ability. Their SIZES are kept, and so
## is the core essence (the Makers' own, not the well's). The next stairs'
## banked essence tops them up again (settle_into fills what a Node holds
## before it refills use, so growth waits while they refill). Returns
## {"total": essence drained, "parts": {part: amount}} (nothing for the marked).
static func drain(prof) -> Dictionary:
	var out := {"total": 0.0, "parts": {}}
	if not is_on(prof):
		return out
	var st := state(prof)
	var trace := maxf(0.0, float(DRAIN.get("trace", 1.0)))
	var stay := 1.0 - clampf(float(DRAIN.get("share", 1.0)), 0.0, 1.0)
	for part in PARTS:
		var o := own(prof, part)
		if o <= 0.0001:
			continue
		var p := primary(prof, part)
		var left := {}
		for k in mix(prof, part):
			var a := amount(prof, part, k) * stay
			if k == p:
				a = maxf(a, minf(trace, amount(prof, part, k)))
			if a > 0.01:
				left[k] = a
		var keep := 0.0
		for k in left:
			keep += float(left[k])
		var gone := o - keep
		if gone > 0.0001:
			out["parts"][part] = gone
			out["total"] = float(out["total"]) + gone
		if not left.is_empty():
			prof.part_density[part] = left
		else:
			prof.part_density.erase(part)
			st["primary"].erase(part)
	st["used"] = {}
	st["drained"] = int(st.get("drained", 0)) + (1 if float(out["total"]) > 0.0001 else 0)
	Core.sync(prof)
	return out


## How many times the climber has been drained (the Husk lore, the Entity's words).
static func drained_count(prof) -> int:
	return int(state(prof).get("drained", 0))


# --- where essence goes ----------------------------------------------------------------

## Where a kind pools when banked (its natural part, or where it's routed);
## a sealed Node takes none: then the biggest open Node (open_default).
static func part_for(prof, kind: String) -> String:
	var routes: Dictionary = state(prof)["routes"]
	var to := String(routes.get(kind, ""))
	var at := to if to in PARTS else String(NATURAL.get(kind, "hand"))
	return open_default(prof) if sealed(prof, at) else at


## Routes a kind to a part (its natural part clears the route). A sealed
## Node can't be routed to.
static func route(prof, kind: String, part: String) -> void:
	if not NATURAL.has(kind) or not part in PARTS or sealed(prof, part):
		return
	var routes: Dictionary = state(prof)["routes"]
	if part == NATURAL[kind]:
		routes.erase(kind)
	else:
		routes[kind] = part


# --- sealing ----------------------------------------------------------------------------------

## True while a Node is sealed (it takes no essence and gives nothing).
static func sealed(prof, part: String) -> bool:
	if prof == null or not (prof.get("unbound") is Dictionary):
		return false
	var s = prof.unbound.get("sealed")
	return s is Dictionary and bool(s.get(part, false)) and bool(prof.unbound.get("on", false))


static func sealed_count(prof) -> int:
	var n := 0
	for part in PARTS:
		if sealed(prof, part):
			n += 1
	return n


## The Nodes not sealed.
static func open_parts(prof) -> Array:
	return PARTS.filter(func(pt): return not sealed(prof, pt))


## Where a sealed Node's essence goes instead: the biggest open Node (an awake
## one first; on a tie, the first in PARTS).
static func open_default(prof) -> String:
	var best := ""
	var most := -1.0
	for pt in open_parts(prof):
		var s := size(prof, pt)
		if s > most + 0.0001:
			most = s
			best = pt
	return best if best != "" else String(PARTS[0])


## Each sealed Node makes the open Nodes' growth from refilled use faster.
static func growth_mult(prof) -> float:
	return 1.0 + float(SEAL.get("growth", 0.0)) * sealed_count(prof)


## ...and their techniques hit harder.
static func seal_power(prof) -> float:
	return 1.0 + float(SEAL.get("power", 0.0)) * sealed_count(prof)


## Why a Node can't be sealed now ("" if it can): only an Unbound, only on
## the train, and at least one Node stays open.
static func why_not_seal(prof, part: String, on_train: bool) -> String:
	if not is_on(prof) or not part in PARTS:
		return TEXT["seal_unbound"]
	if sealed(prof, part):
		return TEXT["seal_already"] % node_name(part)
	if not on_train:
		return TEXT["seal_train"]
	if open_parts(prof).size() <= 1:
		return TEXT["seal_last"]
	return ""


## Seals a Node: what it holds condenses into crystals (whole crystals; the
## core there moves to the other parts), its size, technique, gift, minor
## ability and attributes are gone, and its routes go back to the open
## Nodes. Returns {"ok", "line", "crystals"}.
static func seal(prof, part: String, on_train := true) -> Dictionary:
	var why := why_not_seal(prof, part, on_train)
	if why != "":
		return {"ok": false, "line": why, "crystals": 0}
	var st := state(prof)
	var made := 0
	var pd = prof.part_density.get(part, {})
	if pd is Dictionary:
		for k in pd:
			var whole := int(floor(maxf(0.0, float(pd[k])) + 0.0001))
			if whole >= 1:
				prof.add_crystal(String(k), float(whole))
				made += whole
	prof.part_density.erase(part)
	_sizes(prof)[part] = 0.0
	st["primary"].erase(part)
	st["used"].erase(part)
	st["grown"].erase(part)
	st["seen"][part] = 0
	var i := PARTS.find(part)
	if i >= 0 and i < st["techs"].size():
		st["techs"][i] = {}
	st["sealed"][part] = true
	for k in st["routes"].keys():
		if String(st["routes"][k]) == part:
			st["routes"].erase(k)
	st["core"][part] = 0.0
	Core.sync(prof)
	return {"ok": true, "line": TEXT["sealed_line"] % [node_name(part), made], "crystals": made}


## Opens a sealed Node again: it starts asleep, at size 0, holding nothing.
## Only on the train. Returns {"ok", "line"}.
static func unseal(prof, part: String, on_train := true) -> Dictionary:
	if not sealed(prof, part):
		return {"ok": false, "line": TEXT["unseal_open"] % node_name(part)}
	if not on_train:
		return {"ok": false, "line": TEXT["seal_train"]}
	var st := state(prof)
	st["sealed"].erase(part)
	_sizes(prof)[part] = 0.0
	prof.part_density.erase(part)
	st["seen"][part] = 0
	Core.sync(prof)
	return {"ok": true, "line": TEXT["unsealed_line"] % node_name(part)}


## A Node's own essence (what it holds, the core not counted).
static func own(prof, part: String) -> float:
	var total := 0.0
	var pd = prof.part_density.get(part, {})
	if pd is Dictionary:
		for k in pd:
			total += maxf(0.0, float(pd[k]))
	return total


static func amount(prof, part: String, kind: String) -> float:
	var pd = prof.part_density.get(part, {})
	return maxf(0.0, float(pd.get(kind, 0.0))) if pd is Dictionary else 0.0


## The kind that leads a part's own essence ("" for an empty part): the
## first that came in, while any of it is left (else the biggest).
static func primary(prof, part: String) -> String:
	var st := state(prof)
	var p := String(st["primary"].get(part, ""))
	if p != "" and amount(prof, part, p) > 0.01:
		return p
	var best := ""
	var most := 0.01
	var pd = prof.part_density.get(part, {})
	if pd is Dictionary:
		for k in pd:
			if float(pd[k]) > most:
				most = float(pd[k])
				best = String(k)
	if best != "":
		st["primary"][part] = best
	else:
		st["primary"].erase(part)
	return best


## A part's own kinds, the primary first, then by how much.
static func mix(prof, part: String) -> Array:
	var pd = prof.part_density.get(part, {})
	var out: Array = []
	if not (pd is Dictionary):
		return out
	for k in pd:
		if float(pd[k]) > 0.01:
			out.append(String(k))
	var p := primary(prof, part)
	out.sort_custom(func(a, b): return float(pd[a]) > float(pd[b]))
	if p in out:
		out.erase(p)
		out.push_front(p)
	return out


## The core essence in a part (core.gd).
static func core(prof, part: String) -> float:
	return Core.in_part(prof, part)


## True once the core is at least half of what a part holds (and enough to lead).
static func core_led(prof, part: String) -> bool:
	if prof.path == "":
		return false
	var c := core(prof, part)
	return c >= CORE_LED_MIN and c >= own(prof, part)


## What leads a part: the core when it's core-led, else its primary.
static func lead(prof, part: String) -> String:
	return String(prof.path) if core_led(prof, part) else primary(prof, part)


## What a body part holds: the Node's own essence and its core (at most CAP).
static func fill(prof, part: String) -> float:
	return minf(Core.CAP, own(prof, part) + core(prof, part))


## (The name older code uses for what a part holds.)
static func raw(prof, part: String) -> float:
	return fill(prof, part)


static func level_for(amt: float) -> int:
	var lv := 0
	for i in LEVELS.size():
		if amt + 0.0001 >= float(LEVELS[i]):
			lv = i + 1
	return lv


## The band of size a Node's growth is priced at (GROW_COST's index).
static func cost_band(s: float) -> int:
	return clampi(int(floor(s / COST_BAND + 0.0001)), 0, GROW_COST.size() - 1)


## A Node's level, from its size.
static func level(prof, part: String) -> int:
	return level_for(size(prof, part))


## Size to the next level (0 at the top).
static func next_need(prof, part: String) -> float:
	var lv := level(prof, part)
	if lv >= MAX_LEVEL:
		return 0.0
	return float(LEVELS[lv]) - size(prof, part)


## Room left in a Node for its own essence: within its size, and within
## its part's CAP beside the core there; none while it sleeps.
static func room(prof, part: String) -> float:
	if not awake(prof, part):
		return 0.0
	var o := own(prof, part)
	return maxf(0.0, minf(size(prof, part) - o, Core.CAP - o - core(prof, part)))


## How much of a kind a Node's rules let in, its room aside: no fourth
## kind, and the primary kept at least half of its own essence.
static func kind_limit(prof, part: String, kind: String) -> float:
	var m := mix(prof, part)
	if m.is_empty():
		return INF
	if not kind in m and m.size() >= MAX_KINDS:
		return 0.0
	var p := primary(prof, part)
	if kind == p:
		return INF
	return maxf(0.0, 2.0 * amount(prof, part, p) - own(prof, part))


## How much of a kind a Node can still hold: its room, within its rules.
static func take_limit(prof, part: String, kind: String) -> float:
	var r := room(prof, part)
	if r <= 0.0:
		return 0.0
	return clampf(kind_limit(prof, part, kind), 0.0, r)


## Why a kind can't go into a Node ("" if it can).
static func why_not(prof, part: String, kind: String) -> String:
	if sealed(prof, part):
		return TEXT["cant_sealed"] % node_name(part)
	if not awake(prof, part):
		return TEXT["cant_asleep"] % node_name(part)
	if room(prof, part) <= 0.0:
		return TEXT["cant_full"] % node_name(part)
	if take_limit(prof, part, kind) > 0.0:
		return ""
	var m := mix(prof, part)
	if not kind in m and m.size() >= MAX_KINDS:
		return TEXT["cant_kinds"] % node_name(part)
	return TEXT["cant_primary"] % [_display(primary(prof, part)), node_name(part)]


## Puts up to `amt` of a kind straight into a Node, within its kind rules
## (the dev tools and tests; the game's own paths keep to take_limit, so a
## Node never holds more than its size). The size stretches to fit. Returns
## what went in.
static func put(prof, part: String, kind: String, amt: float) -> float:
	if amt <= 0.0 or not part in PARTS or sealed(prof, part):
		return 0.0
	var g := minf(amt, kind_limit(prof, part, kind))
	g = minf(g, maxf(0.0, Core.CAP - own(prof, part) - core(prof, part)))
	if g <= 0.0:
		return 0.0
	var was_empty := mix(prof, part).is_empty()
	var pd: Dictionary = prof.part_density.get(part, {})
	pd[kind] = float(pd.get(kind, 0.0)) + g
	prof.part_density[part] = pd
	if was_empty:
		state(prof)["primary"][part] = kind
	size(prof, part)  # (stretched to fit)
	return g


## Takes up to `amt` of a kind out of a part. Returns what came out.
static func take(prof, part: String, kind: String, amt: float) -> float:
	var have := amount(prof, part, kind)
	var g := minf(maxf(0.0, amt), have)
	if g <= 0.0:
		return 0.0
	var pd: Dictionary = prof.part_density[part]
	if have - g <= 0.01:
		pd.erase(kind)
		if String(state(prof)["primary"].get(part, "")) == kind:
			state(prof)["primary"].erase(part)
			primary(prof, part)  # (the biggest left leads now)
	else:
		pd[kind] = have - g
	return g


## Banked essence of one kind goes to its Node (profile.gd pour). Returns
## the banked essence left over (to condense into crystals).
static func settle(prof, kind: String, banked: float) -> float:
	if diverted(prof, kind):
		var on := banked * float(SEAL.get("flow", 1.0))
		return banked - on + settle_into(prof, part_for(prof, kind), kind, on)
	return settle_into(prof, part_for(prof, kind), kind, banked)


## True when a kind would pool in a sealed Node (its natural Node, or where
## it's routed) and flows on to an open one instead (SEAL "flow" of it, paying
## a third there as another kind; the
## rest condenses into crystals on the way).
static func diverted(prof, kind: String) -> bool:
	var to := String(state(prof)["routes"].get(kind, ""))
	var at := to if to in PARTS else String(NATURAL.get(kind, "hand"))
	return sealed(prof, at)


## Essence of a kind into one Node. Asleep, it soaks in and grows the size
## (GROW_COST), all of it used, until the Node awakens; awake, it tops up
## what the Node holds, then refills the Node's use (used up, growing it:
## faster for each sealed Node, growth_mult), then tops up again. A sealed
## Node takes nothing. Returns what's left.
static func settle_into(prof, part: String, kind: String, banked: float) -> float:
	if banked <= 0.0 or not part in PARTS or sealed(prof, part):
		return maxf(0.0, banked)
	var left := banked
	if not awake(prof, part):
		left -= _grow(prof, part, left, WAKE_SIZE)
		if not awake(prof, part):
			Core.sync(prof)
			return 0.0  # (all of it soaked in)
	left -= put(prof, part, kind, minf(left, take_limit(prof, part, kind)))
	var st := state(prof)
	var want := used(prof, part)
	if want > 0.0001 and left > 0.0001:
		var s0 := size(prof, part)
		var r := pay_rate(prof, part, kind)  # (the one rule: another kind pays a third)
		var spent := _grow(prof, part, minf(want, left * r), Core.CAP, growth_mult(prof))
		st["used"][part] = maxf(0.0, want - spent)
		st["grown"][part] = float(st["grown"].get(part, 0.0)) + size(prof, part) - s0
		left -= spent / r
		left -= put(prof, part, kind, minf(left, take_limit(prof, part, kind)))
	Core.sync(prof)
	return maxf(0.0, left)


## How much of a refill one banked essence of `kind` pays in this Node: all
## of it for the Node's own kinds (its natural kind, and the essence that
## leads it), USE "other" for any other kind (the one rule).
static func pay_rate(prof, part: String, kind: String) -> float:
	if kind == String(PART_KIND.get(part, "")) or kind == lead(prof, part):
		return 1.0
	return clampf(float(USE.get("other", 1.0)), 0.01, 1.0)


## Feeds `amt` of a kind to a sleeping Node (moving essence into it): it
## soaks in as banked essence would. Returns what it took.
static func feed(prof, part: String, kind: String, amt: float) -> float:
	if awake(prof, part) or sealed(prof, part):
		return 0.0
	var left := settle_into(prof, part, kind, amt)
	return amt - left


## A summit's condensing (CONDENSE of the tower's essence into one Node):
## a sleeping Node soaks it in; an awake one grows as that much refilled use
## would (outside the climb's cap: it's the summit's gift), then tops up what
## it holds. What can't go in is let go.
static func condense(prof, part: String, kind: String) -> void:
	if not part in PARTS or sealed(prof, part):
		return
	var left := float(CONDENSE)
	if not awake(prof, part):
		left -= _grow(prof, part, left, WAKE_SIZE)
	if awake(prof, part) and left > 0.0001:
		left -= put(prof, part, kind, minf(left, take_limit(prof, part, kind)))
		_grow(prof, part, left, Core.CAP)
		put(prof, part, kind, take_limit(prof, part, kind))  # (the tower's essence fills the room it made)
	Core.sync(prof)


## The size an awake Node would reach from a summit's condensing (its card).
static func condense_size(prof, part: String) -> float:
	var s := size(prof, part)
	var left := float(CONDENSE) - minf(float(CONDENSE), maxf(0.0, s - own(prof, part)))
	while left > 0.0001 and s < Core.CAP - 0.0001:
		var b := cost_band(s)
		var cost := float(GROW_COST[b])
		var g := minf(left * COST_BAND / cost, maxf(0.0001, float(b + 1) * COST_BAND - s))
		s += g
		left -= g * cost / COST_BAND
	return minf(s, Core.CAP)


## How much of a kind a press of Move (or Drain, `to` "") would take out of
## `from` (0 if none can go): at most `amt`, what's there, and what the
## target can take once the price is paid (body_move.gd's buttons show it).
## A sleeping target takes any amount (it soaks in).
static func move_amount(prof, kind: String, from: String, to: String, amt := MOVE_STEP) -> float:
	if not awake(prof, from) or (to != "" and sealed(prof, to)):
		return 0.0
	var have := amount(prof, from, kind)
	if have <= 0.01:
		return 0.0
	var want := minf(amt, have)
	if to != "" and awake(prof, to):
		var lim := take_limit(prof, to, kind)
		if lim <= 0.01:
			return 0.0
		want = minf(want, lim / (1.0 - MOVE_COST))
	return want


## Moves essence of a kind from one Node to another (`to` "" drains it into
## crystals; a sleeping `to` is fed: it soaks in). MOVE_COST of it is the
## price: unmade (Unmaking), turned into core (Making), or crystals (no path
## yet). Moving never changes a size. Returns {"ok", "line", "moved"}.
static func move(prof, kind: String, from: String, to: String, amt := MOVE_STEP) -> Dictionary:
	var have := amount(prof, from, kind)
	if have <= 0.01:
		return {"ok": false, "line": TEXT["cant_empty"] % [_display(kind), node_name(from)], "moved": 0.0}
	var want := move_amount(prof, kind, from, to, amt)
	if want <= 0.0:
		return {"ok": false, "line": why_not(prof, to, kind), "moved": 0.0}
	var out := take(prof, from, kind, want)
	var price := out * MOVE_COST
	var arrive := out - price
	var line := ""
	if to != "" and not awake(prof, to):
		feed(prof, to, kind, arrive)
		line = TEXT["fed"] % [_num(out), _display(kind), node_name(from), node_name(to)]
	elif to != "":
		var g := minf(arrive, take_limit(prof, to, kind))
		put(prof, to, kind, g)
		line = TEXT["moved"] % [_num(out), _display(kind), node_name(from), node_name(to)]
	else:
		var c := int(floor(arrive))
		if c >= 1:
			prof.add_crystal(kind, float(c))
		line = TEXT["drained"] % [_num(out), _display(kind), node_name(from), str(c)]
	match String(prof.path):
		"unmaking":
			line += "  ·  " + TEXT["cost_unmade"] % _num(price)
		"life":
			Core.sync(prof)
			Core.add(prof, price)
			line += "  ·  " + TEXT["cost_core"] % _num(price)
		_:
			var pc := int(floor(price))
			if pc >= 1:
				prof.add_crystal(kind, float(pc))
			line += "  ·  " + TEXT["cost_crystals"] % _num(price)
	Core.sync(prof)
	return {"ok": true, "line": line, "moved": out}


## At a stair: each core-led part turns some of its other essence into core
## (core.gd ABSORB). Returns lines.
static func absorb(prof) -> Array:
	var lines: Array = []
	if not is_on(prof) or prof.path == "":
		return lines
	for part in PARTS:
		if not core_led(prof, part):
			continue
		var o := own(prof, part)
		if o <= 0.01:
			continue
		var x := minf(o, maxf(o * Core.ABSORB, Core.ABSORB_MIN))
		for k in mix(prof, part):
			take(prof, part, k, x * amount(prof, part, k) / o)
		Core.add(prof, x, part)
		lines.append(Core.TEXT["absorbed"] % [node_name(part), int(ceil(x)), "essence"])
	return lines


## True once one essence alone fills a Node at full size (the core taking
## none of it): its signature.
static func pure(prof, part: String) -> bool:
	return mix(prof, part).size() == 1 and size(prof, part) >= Core.CAP - 0.01 and fill(prof, part) >= Core.CAP - 0.01 and not core_led(prof, part)


## The signature a pure, full part brings ({} if none).
static func signature(prof, part: String) -> Dictionary:
	if not is_on(prof) or not pure(prof, part):
		return {}
	return SIGNATURES.get("%s:%s" % [part, primary(prof, part)], {})


## A Node can carry a technique: level TECH_LEVEL, with something to lead it.
static func tech_ready(prof, part: String) -> bool:
	return level(prof, part) >= TECH_LEVEL and lead(prof, part) != ""


## A young technique (TECH_LEVEL to FULL_TECH_LEVEL): limited to its first
## form and its lead essence, and weaker (power).
static func tech_young(prof, part: String) -> bool:
	var lv := level(prof, part)
	return lv >= TECH_LEVEL and lv < FULL_TECH_LEVEL


## How much harder this part's techniques hit: YOUNG_POWER at TECH_LEVEL,
## 1x at FULL_TECH_LEVEL, MAX_POWER at 12; harder still for each sealed
## Node (seal_power).
static func power(prof, part: String) -> float:
	var lv := level(prof, part)
	if lv < FULL_TECH_LEVEL:
		var y := clampf(float(lv - TECH_LEVEL) / float(FULL_TECH_LEVEL - TECH_LEVEL), 0.0, 1.0)
		return (YOUNG_POWER + (1.0 - YOUNG_POWER) * y) * seal_power(prof)
	var k := clampf(float(lv - FULL_TECH_LEVEL) / float(MAX_LEVEL - FULL_TECH_LEVEL), 0.0, 1.0)
	return (1.0 + (MAX_POWER - 1.0) * k) * seal_power(prof)


## A core technique's extra strength (1 when the part isn't core-led).
static func core_power(prof, part: String) -> float:
	if not core_led(prof, part) or tech_young(prof, part):
		return 1.0
	return float(CORE_POWER[1]) if level(prof, part) >= MAX_LEVEL else float(CORE_POWER[0])


static func has_gift(prof, part: String) -> bool:
	return is_on(prof) and level(prof, part) >= GIFT_LEVEL


static func has_minor(prof, part: String) -> bool:
	return is_on(prof) and level(prof, part) >= MINOR_LEVEL and lead(prof, part) != ""


## A gift's number (0 without it): "strength", "speed", "health", "cost", "will", "fade".
static func gift(prof, key: String) -> float:
	for part in GIFTS:
		if GIFTS[part].has(key) and has_gift(prof, part):
			return float(GIFTS[part][key])
	return 0.0


## A part's minor ability, in words.
static func minor_text(prof, part: String) -> String:
	var k := lead(prof, part)
	if k == "" or not awake(prof, part):
		return TEXT["minor_none"] % MINOR_LEVEL
	var T = load("res://scripts/technique.gd")
	return TEXT["minor"] % [MINOR_ACTS[part], T.display(k), String(T.KINDS.get(k, {}).get("hit", ""))]


## The body's total size (the six Nodes).
static func total(prof) -> float:
	var t := 0.0
	for part in PARTS:
		t += size(prof, part)
	return t


## The size counted for an essence's attribute (profile.gd attribute): each
## awake Node's size, shared among the essences it holds in proportion to
## how much of each (all of it to its natural essence while it holds none).
static func attr_size(prof, kind: String) -> float:
	if not is_on(prof):
		return 0.0
	var t := 0.0
	for part in PARTS:
		if not awake(prof, part):
			continue
		var o := own(prof, part)
		if o > 0.01:
			t += size(prof, part) * amount(prof, part, kind) / o
		elif String(PART_KIND[part]) == kind:
			t += size(prof, part)
	return t


## An attribute's share of its cap (0 to 1) from attr_size: half at ATTR "half".
static func attr_share(prof, kind: String) -> float:
	var s := attr_size(prof, kind)
	return s / (s + maxf(1.0, float(ATTR.get("half", 60.0))))


static func stage(prof) -> int:
	var t := total(prof)
	var st := 1
	for i in STAGE_AT.size():
		if t >= float(STAGE_AT[i]):
			st = i + 1
	return st


static func stage_name(prof) -> String:
	return STAGES[stage(prof) - 1]


## The kinds an Unbound can have in a body: the six, and their path's essence.
static func kinds_for(prof) -> Array:
	var out: Array = ["fire", "water", "air", "stone", "iron", "blade"]
	if prof.path in ["life", "unmaking"]:
		out.append(prof.path)
	return out


## (Every kind is in a part's mix now: a technique takes all of them.)
static func max_kinds(_prof, _part: String) -> int:
	return MAX_KINDS


# --- techniques from the parts ------------------------------------------------------------

## A part's technique essences: what leads it, then its modifiers (the core
## isn't one of them: it adds its touch through tech_weights).
static func tech_kinds(prof, part: String) -> Array:
	var m := mix(prof, part)
	var young := tech_young(prof, part)  # (a young technique: its lead alone)
	if core_led(prof, part):
		return [String(prof.path)] if young else [String(prof.path)] + m.slice(0, MAX_KINDS - 1)
	return m.slice(0, 1) if young else m


## The weight each essence acts with in a part's techniques: the lead 1, a
## modifier by its share, the core by its share of the part.
static func tech_weights(prof, part: String) -> Dictionary:
	var out := {}
	var kinds := tech_kinds(prof, part)
	if kinds.is_empty():
		return out
	var o := maxf(own(prof, part), 0.01)
	var led := core_led(prof, part)
	for i in kinds.size():
		var k := String(kinds[i])
		if i == 0:
			out[k] = 1.0
		elif led:
			out[k] = LED_MOD
		else:
			out[k] = clampf(2.0 * amount(prof, part, k) / o, MOD_MIN, 1.0)
	var c := core(prof, part)
	if prof.path != "" and not led and c > 0.01 and not tech_young(prof, part):
		out[String(prof.path)] = clampf(2.0 * c / maxf(fill(prof, part), 0.01), 0.0, CORE_MOD)
	return out


## Brings a slot's technique up to date with its part (its essences and
## their weights, a core technique's name); `t` is changed in place.
static func sync_tech(prof, t: Dictionary, part: String) -> void:
	var Library = load("res://scripts/library.gd")
	var TreeRules = load("res://scripts/tree.gd")
	t["part"] = part
	var forms: Array = TreeRules.owned_forms(prof, part)
	if not String(t.get("shape", "")) in forms:
		t["shape"] = String(Library.BASE_FORMS[part][0])
	t["kinds"] = tech_kinds(prof, part)
	t["w"] = tech_weights(prof, part)
	t["core"] = core_led(prof, part)
	if bool(t["core"]):
		t["core_name"] = String(CORE_TECHS.get(part, {}).get(String(prof.path), ""))
	else:
		t.erase("core_name")


## Every slot brought up to date; a part that has just reached TECH_LEVEL
## learns its first form by itself. Returns the parts that learned one.
static func sync_techs(prof) -> Array:
	var learned: Array = []
	if not is_on(prof):
		return learned
	var Library = load("res://scripts/library.gd")
	var techs: Array = state(prof)["techs"]
	for i in PARTS.size():
		var part: String = PARTS[i]
		var t = techs[i]
		if not (t is Dictionary):
			t = {}
			techs[i] = t
		if not tech_ready(prof, part):
			continue
		if t.is_empty() or String(t.get("part", "")) != part:
			techs[i] = {"name": "", "part": part, "shape": String(Library.BASE_FORMS[part][0])}
			t = techs[i]
			learned.append(part)
		sync_tech(prof, t, part)
	return learned


## The technique a slot carries now ({} while its part sleeps).
static func tech_of(prof, i: int) -> Dictionary:
	var techs: Array = state(prof)["techs"]
	if i < 0 or i >= techs.size() or not tech_ready(prof, PARTS[i]):
		return {}
	var t = techs[i]
	return t if t is Dictionary and not t.is_empty() else {}


# --- becoming Unbound, and going back ------------------------------------------

## Becomes Unbound: no tower bonds from now on (any carried are given up).
## Six Nodes, all asleep at size 0: the essence already in the body soaks
## into each kind's natural Node (the first climb's essence is enough to
## nearly wake one). No techniques yet: a Node learns a young one at TECH_LEVEL.
static func become(prof) -> void:
	var st := state(prof)
	var was_on := bool(st["on"])
	st["on"] = true
	st["found"] = true
	prof.bonds = {}
	prof.soak = {}
	prof.tally = {}
	if not was_on:
		var totals := {}
		for part in prof.part_density:
			var pd = prof.part_density[part]
			if pd is Dictionary:
				for k in pd:
					if NATURAL.has(String(k)):
						totals[k] = float(totals.get(k, 0.0)) + float(pd[k])
		prof.part_density = {}
		st["primary"] = {}
		st["core"] = {}
		st["seen"] = {}
		st["used"] = {}
		st["grown"] = {}
		st["sealed"] = {}
		st["size"] = {}
		for part in PARTS:
			st["size"][part] = 0.0
		st["techs"] = []
		for i in PARTS.size():
			st["techs"].append({})
		var order: Array = totals.keys()
		order.sort_custom(func(a, b): return float(totals[a]) > float(totals[b]))
		for k in order:
			settle(prof, String(k), float(totals[k]))
		Core.sync(prof)
		for part in PARTS:
			st["seen"][part] = level(prof, part)
	prof.note("unbound")


## Only the Developer goes back.
static func can_return(prof) -> bool:
	return is_on(prof) and String(prof.core_mark) == "developer"


## The Developer lets the tower beasts mark them again: the biggest Node
## takes a mark (its bond chosen by what's pooled there), growing from
## SETTLE of its size; the other parts keep SETTLE of theirs as soak.
## Returns {part, id} ("" for none).
static func return_to_marks(prof) -> Dictionary:
	if not can_return(prof):
		return {}
	var fills := {}
	for part in PARTS:
		fills[part] = size(prof, part)
	var st := state(prof)
	st["on"] = false
	st["sealed"] = {}
	prof.bonds = {}
	prof.soak = {}
	prof.tally = {}
	var best := ""
	var most := 0.0
	for part in PARTS:
		if float(fills[part]) > most:
			most = float(fills[part])
			best = part
	var id := ""
	if best != "" and most > 0.0:
		id = prof.choose_bond(prof.part_density.get(best, {}), {})
		if id != "":
			prof.add_bond(best, id, false)
			prof.bonds[best]["xp"] = minf(most * SETTLE, float(prof.STEP_XP[prof.STEP_XP.size() - 1]))
	for part in PARTS:
		if not prof.bonds.has(part):
			var r := minf(float(fills[part]) * SETTLE, float(prof.NEW_MARK_SOAK) * float(prof.MARK_FULL) * 0.9)
			if r > 0.0:
				prof.soak[part] = r
	return {"part": best if id != "" else "", "id": id}


static func _display(kind: String) -> String:
	return load("res://scripts/technique.gd").display(kind)


static func _num(f: float) -> String:
	return str(int(round(f))) if absf(f - round(f)) < 0.05 or f >= 10.0 else "%.1f" % f
