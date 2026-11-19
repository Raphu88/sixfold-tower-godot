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
## A BODY PART IS A CUP (profile.part_density: part -> {kind: amount})
##   Each part holds CAP (120). Banked essence flows into its natural part
##   (Blade the hand, Air the legs...), or wherever it's ROUTED at the train,
##   and fills it slowly: FILL_COST is how much banked essence ten more take
##   at each level (the fuller the part, the slower it fills). A full part
##   takes no more: what's left condenses into crystals (essence is never
##   lost). At the train essence can be MOVED from one part to another; a
##   share of it is the price (MOVE_COST): unmade on the Unmaking path,
##   turned into core essence on the Making path, condensed into crystals
##   before a path is chosen.
##   PRIMARY: the first essence in a part leads it and must stay at least
##   half of the part's own essence (an essence that would push it under
##   can't come in). At most MAX_KINDS kinds a part. The others are
##   MODIFIERS: each adds its touch to every technique of the part, stronger
##   the bigger its share. The core essence (core.gd) takes room in every
##   part and adds its own touch, but counts for neither rule; once it's at
##   least half of what a part holds, the part is CORE-LED: the core leads
##   it, its technique becomes a core technique (CORE_TECHS, stronger at
##   half full and again at full: CORE_POWER) and the core slowly absorbs
##   the other essences (core.gd ABSORB).
##   LEVELS: every LEVEL_SIZE (10) of fill is a level, 0 to MAX_LEVEL (12).
##   Level MINOR_LEVEL wakes the part's MINOR ability (a touch of its lead
##   essence on the part's own action), GIFT_LEVEL brings its gift,
##   TECH_LEVEL (half full) opens its techniques (it learns the first by
##   itself: change its form at the essence bench), then the tree's forks
##   and forms, and at MAX_LEVEL (full) its capstone, and its SIGNATURE if
##   one essence fills it all (a pure part). The total sets the STAGE.
## Profile state lives in profile.unbound (state() fills in its keys).

const Core := preload("res://scripts/core.gd")

const PARTS := ["hand", "legs", "heart", "brow", "throat", "back"]
static var PART_NAMES := {"hand": "Hand", "legs": "Legs", "heart": "Heart", "brow": "Brow", "throat": "Throat", "back": "Back"}
## The six kinds and their natural parts.
const NATURAL := {"blade": "hand", "air": "legs", "stone": "back", "water": "throat", "fire": "brow", "iron": "heart"}
## Each part's main colour (its natural essence's), for the veins.
const PART_KIND := {"hand": "blade", "legs": "air", "back": "stone", "throat": "water", "brow": "fire", "heart": "iron"}
## Fill per level, and the levels.
const LEVEL_SIZE := 10.0
const MAX_LEVEL := 12
## The fill each level needs (index = level - 1): 10, 20 ... 120.
static var LEVELS := [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0, 110.0, 120.0]
## Banked essence that ten more fill take, at each level (index = the part's level now).
static var FILL_COST := [60.0, 90.0, 120.0, 180.0, 270.0, 400.0, 600.0, 900.0, 1300.0, 1900.0, 2700.0, 3900.0]
const MINOR_LEVEL := 3
const GIFT_LEVEL := 5
const TECH_LEVEL := 6
## Kinds of essence a part holds at most (the core essence not counted).
const MAX_KINDS := 3
## A part's core essence must be at least this much to lead it.
const CORE_LED_MIN := 6.0
## Techniques from a part hit this much harder at level 12 (1x at TECH_LEVEL).
const MAX_POWER := 2.0
## A modifier essence acts at twice its share of the part's own essence (at
## most 1, at least MOD_MIN); the core at twice its share of all the part
## holds (at most CORE_MOD); in a core-led part the other essences add only
## LED_MOD of theirs.
const MOD_MIN := 0.15
const CORE_MOD := 0.75
const LED_MOD := 0.25
## A core technique hits this much harder: half full, full.
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
## At a summit the Unbound condense the tower's essence into a part of their choice (fill).
const CONDENSE := 6.0
## Moving essence at the train: this much at a press, and the share it costs.
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
	"refuse_title": "THE BEAST OFFERS A MARK",
	"refuse_lines": ["Take it, and you are marked as every climber is.", "Refuse it, and essence fills your body raw. There is no road back."],
	"accept_name": "Accept the mark",
	"accept_desc": "Take the %s mark on your %s. Your bonds grow as they always have.",
	"refuse_name": "Refuse it",
	"refuse_desc": "Become Unbound: no tower bond, now or later. Banked essence fills your six body parts raw, and a part half full gives you a technique of your own.",
	"refuse_note": "for good",
	"refuse_again": "Tap again to refuse, for good",
	"refuse_again_keys": "Press again to refuse, for good",
	"refused_title": "REFUSED",
	"refused_lines": ["You broke a barrier on your first climb.", "%s will not mark you.", "You are Unbound.", "Banked essence fills your six body parts raw."],
	"accepted": "Essence takes hold in your %s: the %s mark",
	"stage": "%s  ·  stage %d of 12",
	"climber_line": "Unbound  ·  %s  ·  %d %s  ·  best floor %d",
	"level": "level %d",
	"condense_title": "CONDENSE",
	"condense_sub": "No mark for the Unbound. Draw the tower's %s essence into one part.",
	"condense_card": "+%d %s",
	"condense_desc": "%s essence fills your %s: level %d now.",
	"condense_full": "Your %s can't take %s now.",
	"condensed": "%d %s essence condenses in your %s",
	"back_title": "MARKED AGAIN",
	"back": "Raw essence settles back into a bond: the %s mark on your %s.",
	"back_none": "Raw essence settles back into you. Your next marks will come sooner.",
	# Filling, at the stair.
	"level_up": "Your %s fills to level %d",
	"minor_up": "Your %s wakes: %s",
	"tech_up": "Your %s is half full: it learns %s",
	"full_up": "Your %s is full: %s",
	"pure_up": "Pure %s fills your %s: %s",
	"spill": "Your %s can't take more %s: %d condenses into crystals",
	"core_led": "Your %s is core-led: %s",
	"minor": "Now and then %s carry a touch of %s: %s.",
	"minor_none": "Its minor ability wakes at level %d.",
	# Moving essence (technique_page.gd).
	"moved": "Moved %s %s from your %s to your %s",
	"drained": "Drained %s %s from your %s: %s crystals",
	"cost_unmade": "%s unmade",
	"cost_core": "%s turned into Making",
	"cost_crystals": "%s condensed into crystals",
	"cant_kinds": "Your %s already holds three kinds",
	"cant_primary": "%s must stay at least half of your %s",
	"cant_full": "Your %s is full",
	"cant_empty": "No %s in your %s",
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
	if not (st.get("primary") is Dictionary):
		st["primary"] = {}  # part -> the kind that leads it
	if not (st.get("core") is Dictionary):
		st["core"] = {}  # part -> core essence there (core.gd)
	if not (st.get("seen") is Dictionary):
		st["seen"] = {}  # part -> the highest level it has shown (the first-time moments)
	return st


static func is_on(prof) -> bool:
	return prof != null and bool(state(prof).get("on", false))


## An old save's cups made to fit (an older Unbound's huge raw density):
## each part's own essence at most CAP, at most MAX_KINDS kinds.
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
	Core.sync(prof)


# --- where essence goes ----------------------------------------------------------------

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


## A part's own essence (its cup, the core not counted).
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


## How full a part is: its own essence and its core (at most CAP).
static func fill(prof, part: String) -> float:
	return minf(Core.CAP, own(prof, part) + core(prof, part))


## (The name older code uses for a part's fill.)
static func raw(prof, part: String) -> float:
	return fill(prof, part)


static func level_for(amt: float) -> int:
	return clampi(int(floor(amt / LEVEL_SIZE + 0.0001)), 0, MAX_LEVEL)


static func level(prof, part: String) -> int:
	return level_for(fill(prof, part))


## Fill to the next level (0 at the top).
static func next_need(prof, part: String) -> float:
	var lv := level(prof, part)
	if lv >= MAX_LEVEL:
		return 0.0
	return float(LEVELS[lv]) - fill(prof, part)


## Room left in a part (for its own essence or core).
static func room(prof, part: String) -> float:
	return maxf(0.0, Core.CAP - own(prof, part) - core(prof, part))


## How much of a kind (fill) a part can still take: its room, no fourth
## kind, and the primary kept at least half of its own essence.
static func take_limit(prof, part: String, kind: String) -> float:
	var r := room(prof, part)
	if r <= 0.0:
		return 0.0
	var m := mix(prof, part)
	if m.is_empty():
		return r
	if not kind in m and m.size() >= MAX_KINDS:
		return 0.0
	var p := primary(prof, part)
	if kind == p:
		return r
	return clampf(2.0 * amount(prof, part, p) - own(prof, part), 0.0, r)


## Why a kind can't go into a part ("" if it can).
static func why_not(prof, part: String, kind: String) -> String:
	if room(prof, part) <= 0.0:
		return TEXT["cant_full"] % PART_NAMES[part].to_lower()
	if take_limit(prof, part, kind) > 0.0:
		return ""
	var m := mix(prof, part)
	if not kind in m and m.size() >= MAX_KINDS:
		return TEXT["cant_kinds"] % PART_NAMES[part].to_lower()
	return TEXT["cant_primary"] % [_display(primary(prof, part)), PART_NAMES[part].to_lower()]


## Puts up to `amt` fill of a kind into a part (within take_limit). Returns what went in.
static func put(prof, part: String, kind: String, amt: float) -> float:
	if amt <= 0.0 or not part in PARTS:
		return 0.0
	var g := minf(amt, take_limit(prof, part, kind))
	if g <= 0.0:
		return 0.0
	var was_empty := mix(prof, part).is_empty()
	var pd: Dictionary = prof.part_density.get(part, {})
	pd[kind] = float(pd.get(kind, 0.0)) + g
	prof.part_density[part] = pd
	if was_empty:
		state(prof)["primary"][part] = kind
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


## Banked essence of one kind fills its part (profile.gd pour), slowly: ten
## fill cost FILL_COST at the part's level. Returns the banked essence left
## over (the part full, or the rules keeping it out).
static func settle(prof, kind: String, banked: float) -> float:
	return settle_into(prof, part_for(prof, kind), kind, banked)


static func settle_into(prof, part: String, kind: String, banked: float) -> float:
	var left := banked
	for _i in 64:
		if left <= 0.0001:
			break
		var lim := take_limit(prof, part, kind)
		if lim <= 0.0001:
			break
		var f := fill(prof, part)
		var lv := level_for(f)
		if lv >= MAX_LEVEL:
			break
		var cost := float(FILL_COST[mini(lv, FILL_COST.size() - 1)])
		var to_next := float(LEVELS[lv]) - f
		if to_next <= 0.0001:
			to_next = LEVEL_SIZE
		var g := minf(left * LEVEL_SIZE / cost, minf(lim, to_next))
		if g <= 0.00001:
			break
		put(prof, part, kind, g)
		left -= g * cost / LEVEL_SIZE
	Core.sync(prof)
	return maxf(0.0, left)


## Moves essence of a kind from one part to another (`to` "" drains it into
## crystals). MOVE_COST of it is the price: unmade (Unmaking), turned into
## core (Making), or crystals (no path yet). Returns {"ok", "line", "moved"}.
static func move(prof, kind: String, from: String, to: String, amt := MOVE_STEP) -> Dictionary:
	var have := amount(prof, from, kind)
	if have <= 0.01:
		return {"ok": false, "line": TEXT["cant_empty"] % [_display(kind), PART_NAMES[from].to_lower()], "moved": 0.0}
	var want := minf(amt, have)
	var keep := 1.0 - MOVE_COST
	if to != "":
		var lim := take_limit(prof, to, kind)
		if lim <= 0.01:
			return {"ok": false, "line": why_not(prof, to, kind), "moved": 0.0}
		want = minf(want, lim / keep)
	var out := take(prof, from, kind, want)
	var price := out * MOVE_COST
	var arrive := out - price
	var line := ""
	if to != "":
		put(prof, to, kind, arrive)
		line = TEXT["moved"] % [_num(out), _display(kind), PART_NAMES[from].to_lower(), PART_NAMES[to].to_lower()]
	else:
		var c := int(floor(arrive))
		if c >= 1:
			prof.add_crystal(kind, float(c))
		line = TEXT["drained"] % [_num(out), _display(kind), PART_NAMES[from].to_lower(), str(c)]
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
		lines.append(Core.TEXT["absorbed"] % [PART_NAMES[part].to_lower(), int(ceil(x)), "essence"])
	return lines


## True once one essence alone fills a part (the core not counted): its signature.
static func pure(prof, part: String) -> bool:
	return mix(prof, part).size() == 1 and fill(prof, part) >= Core.CAP - 0.01 and not core_led(prof, part)


## The signature a pure, full part brings ({} if none).
static func signature(prof, part: String) -> Dictionary:
	if not is_on(prof) or not pure(prof, part):
		return {}
	return SIGNATURES.get("%s:%s" % [part, primary(prof, part)], {})


## A part can carry a technique: half full, with something to lead it.
static func awake(prof, part: String) -> bool:
	return level(prof, part) >= TECH_LEVEL and lead(prof, part) != ""


## How much harder this part's techniques hit (1x at TECH_LEVEL, MAX_POWER at 12).
static func power(prof, part: String) -> float:
	var k := clampf(float(level(prof, part) - TECH_LEVEL) / float(MAX_LEVEL - TECH_LEVEL), 0.0, 1.0)
	return 1.0 + (MAX_POWER - 1.0) * k


## A core technique's extra strength (1 when the part isn't core-led).
static func core_power(prof, part: String) -> float:
	if not core_led(prof, part):
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
	if k == "" or level(prof, part) < MINOR_LEVEL:
		return TEXT["minor_none"] % MINOR_LEVEL
	var T = load("res://scripts/technique.gd")
	return TEXT["minor"] % [MINOR_ACTS[part], T.display(k), String(T.KINDS.get(k, {}).get("hit", ""))]


## The body's total fill (the six parts).
static func total(prof) -> float:
	var t := 0.0
	for part in PARTS:
		t += fill(prof, part)
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
	if core_led(prof, part):
		return [String(prof.path)] + m.slice(0, MAX_KINDS - 1)
	return m


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
	if prof.path != "" and not led and c > 0.01:
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


## Every slot brought up to date; a part that has just woken (half full)
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
		if not awake(prof, part):
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
	if i < 0 or i >= techs.size() or not awake(prof, PARTS[i]):
		return {}
	var t = techs[i]
	return t if t is Dictionary and not t.is_empty() else {}


# --- becoming Unbound, and going back ------------------------------------------

## Becomes Unbound: no tower bonds from now on (any carried are given up).
## No techniques yet: the essence already in the body flows into its
## natural parts, and a part half full will learn one.
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


## The Developer lets the tower beasts mark them again: the densest part
## takes a mark (its bond chosen by what's pooled there), growing from
## SETTLE of its fill; the other parts keep SETTLE of theirs as soak.
## Returns {part, id} ("" for none).
static func return_to_marks(prof) -> Dictionary:
	if not can_return(prof):
		return {}
	var fills := {}
	for part in PARTS:
		fills[part] = fill(prof, part)
	var st := state(prof)
	st["on"] = false
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
