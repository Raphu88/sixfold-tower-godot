extends RefCounted
## THE TRAVELLING TOURNAMENT MANAGER: after a climber's first tournament
## (training.gd FIRST, always at home), the tournament's brackets (stations.gd
## BRACKETS) are run by the Tournament Manager, who moves between the six
## stations. Where they are follows ROTATION, by the climber's number of
## climbs: ROTATION "order"[(climbs / every) % 6]. At the other stations the
## tournament grounds say where the Manager is and when they move on.
##
## Each LOCATION (by station) changes the tournament there:
##   layout    the arena's pillars (LAYOUTS: fractions of the open room)
##   hazard    a trap kind laid round the edge (traps.gd KINDS), a few of it
##   creatures the monsters of a bracket's first round (BRACKET_CREATURES
##             of them) and, for the first tournament at home, its
##             "starter" rounds (low-level monsters)
##   marks     the essence the rivals' first mark leans to (their tower's)
##   prize     the ADVANCED reward, unique to each location: a named piece
##             of its tower (gear.gd NAMED), the first time you win a bracket
##             from ADVANCED_FROM up there
## The MINOR reward is shared by every location: MINOR on every bracket won.
## Tournaments after the first cost an entry fee (stations.gd BRACKETS
## "fee") and pay essence (training.gd RATES "tourney": half the usual,
## flowing into you), crystals, renown, the minor reward and the advanced.
##
## Every name, number and word is here (and in the Data editor). The
## Manager's name is a placeholder.

const Travel := preload("res://scripts/travel.gd")
const Stations := preload("res://scripts/stations.gd")
const Towers := preload("res://scripts/towers.gd")
const Gear := preload("res://scripts/gear.gd")
const Traps := preload("res://scripts/traps.gd")
const Essence := preload("res://scripts/essence.gd")
const Items := preload("res://scripts/items.gd")

## The Manager: a placeholder name, and what they say (one line is picked).
static var MANAGER := {"name": "the Tournament Manager"}
static var LINES := {
	"here": ["\"My grounds, my rules: first to yield loses. Pay at the table.\"", "\"Pick a bracket. The sand here is not like the last.\""],
	"away": ["A notice on the gate: the Tournament Manager has moved on.", "The grounds are quiet. The Manager is elsewhere on the loop."],
}

## Where the Manager is: "order" of stations, moving on every `every` climbs.
static var ROTATION := {"every": 1, "order": ["gryphon", "kraken", "wyvern", "manticore", "firebird", "chimera"]}

## How many of the location's creatures fight a bracket's first round.
static var BRACKET_CREATURES := {"novice": 2, "open": 3, "veterans": 3, "masters": 3, "grand": 4, "champions": 4}
## The location's unique prize comes with a bracket from this one up (1 the first).
static var ADVANCED_FROM := 2
## The shared, minor reward for every bracket won: an item packed for the next climb.
static var MINOR := {"item": "draught"}
## How many hazards a location lays, and how far in from the walls (px).
static var HAZARD := {"count": 4, "inset": 70.0}

static var LOCATIONS := {
	"gryphon": {"layout": "ring", "hazard": "gust", "creatures": ["bat", "harrier", "thunderling"], "starter": [["bat", "bat"], ["bat", "archer"]], "prize": "stormstring",
		"line": "Wind across open sand, pillars in a ring, and gusts along the edge."},
	"kraken": {"layout": "lanes", "hazard": "sluice", "creatures": ["slime", "lurker", "deepfin"], "starter": [["slime", "slime"], ["slime", "lurker"]], "prize": "coral_trident",
		"line": "Two rows of pillars and sluices that sweep the sides."},
	"wyvern": {"layout": "corners", "hazard": "flame", "creatures": ["cinder", "smith", "knight"], "starter": [["cinder", "cinder"], ["cinder", "knight"]], "prize": "cinder_axe",
		"line": "A forge yard: pillars at the corners, flame vents in the walls."},
	"manticore": {"layout": "scatter", "hazard": "spikes", "creatures": ["scorpling", "ram", "burrower"], "starter": [["scorpling", "scorpling"], ["scorpling", "archer"]], "prize": "stinger_dagger",
		"line": "Sun-baked stones scattered about, and spike plates in the sand."},
	"firebird": {"layout": "cross", "hazard": "ember", "creatures": ["wisp", "bloomcap", "ashwing"], "starter": [["wisp", "wisp"], ["wisp", "archer"]], "prize": "sunsteel_blade",
		"line": "Pillars in a cross, and embers that fall on marked ground."},
	"chimera": {"layout": "grove", "hazard": "thorns", "creatures": ["thornhound", "mongrel", "briar"], "starter": [["thornhound", "slime"], ["thornhound", "archer"]], "prize": "thornmaul",
		"line": "A grove of trunks, and bramble snares hidden in the grass."},
}

## The layouts: each pillar [x, y, radius] with x, y as fractions of the
## open room (0 left / top, 1 right / bottom). The middle and the bottom
## middle (where you start) stay clear.
static var LAYOUTS := {
	"ring": [[0.3, 0.3, 18], [0.7, 0.3, 18], [0.18, 0.55, 18], [0.82, 0.55, 18], [0.32, 0.8, 18], [0.68, 0.8, 18]],
	"lanes": [[0.25, 0.3, 16], [0.25, 0.55, 16], [0.25, 0.8, 16], [0.75, 0.3, 16], [0.75, 0.55, 16], [0.75, 0.8, 16]],
	"corners": [[0.12, 0.2, 24], [0.88, 0.2, 24], [0.12, 0.82, 24], [0.88, 0.82, 24]],
	"scatter": [[0.2, 0.25, 14], [0.42, 0.18, 12], [0.8, 0.3, 16], [0.16, 0.7, 16], [0.84, 0.72, 12], [0.62, 0.62, 12]],
	"cross": [[0.5, 0.18, 16], [0.3, 0.5, 16], [0.7, 0.5, 16], [0.2, 0.5, 12], [0.8, 0.5, 12]],
	"grove": [[0.15, 0.3, 20], [0.3, 0.2, 14], [0.85, 0.28, 20], [0.7, 0.18, 14], [0.12, 0.75, 16], [0.88, 0.76, 16]],
}

static var TEXT := {
	"manager": "The Tournament Manager",
	"here": "The Tournament Manager is here",
	"here_line": "Running the brackets at %s until your next climb.",
	"away": "The Tournament Manager is at %s",
	"away_line": "They move on after each climb: next at %s.",
	"away_short": "At %s",
	"why_away": "The Tournament Manager is at %s",
	"why_first": "Your first tournament comes first",
	"location": "This location",
	"hazard": "Hazards: %s",
	"creatures": "Creatures: %s",
	"minor": "Every bracket won: %s",
	"prize": "First win here from the %s up: %s",
	"prize_have": "This location's prize is yours: %s",
	"minor_won": "%s, packed for your next climb",
	"prize_won": "This location's prize: %s, in your stash",
	"prize_full": "This location's prize: %s, in your pack (your stash is full)",
	"next_line": "Next stop: %s",
	"talk_here": "The Tournament Manager is here, at {station}.",
	"talk_away": "The Tournament Manager is at {station}; next, {next}.",
}


# --- where the Manager is -------------------------------------------------------------------

## The station the Manager is at for this climber now.
static func here(profile) -> String:
	var order: Array = ROTATION.get("order", [])
	if order.is_empty():
		return ""
	var climbs := int(profile.climbs) if profile != null else 0
	var every := maxi(1, int(ROTATION.get("every", 1)))
	return String(order[(climbs / every) % order.size()])


## The station they go to next (after the next climb, or after `every`).
static func next(profile) -> String:
	var order: Array = ROTATION.get("order", [])
	if order.is_empty():
		return ""
	var climbs := int(profile.climbs) if profile != null else 0
	var every := maxi(1, int(ROTATION.get("every", 1)))
	return String(order[(climbs / every + 1) % order.size()])


static func at(profile, station: String) -> bool:
	return station != "" and here(profile) == station


static func location(station: String) -> Dictionary:
	return LOCATIONS.get(station, LOCATIONS.get(String(ROTATION["order"][0]), {}))


static func station_name(station: String) -> String:
	return String(Stations.station(station).get("name", station))


## "The Tournament Manager is at Tidemoor; next, Forgehaven."
static func where_line(profile) -> String:
	var h := here(profile)
	if h == Travel.current(profile):
		return String(TEXT["talk_here"]).replace("{station}", station_name(h))
	return String(TEXT["talk_away"]).replace("{station}", station_name(h)).replace("{next}", station_name(next(profile)))


static func line(key: String) -> String:
	var pool: Array = LINES.get(key, [])
	return String(pool[randi() % pool.size()]) if not pool.is_empty() else ""


# --- a location's arena --------------------------------------------------------------------------

## A layout's pillars in the room: [{"pos", "r"}].
static func pillars(layout: String, room: Rect2) -> Array:
	var out: Array = []
	for p in LAYOUTS.get(layout, []):
		out.append({"pos": room.position + Vector2(float(p[0]) * room.size.x, float(p[1]) * room.size.y), "r": float(p[2])})
	return out


## A location's hazards: a few of its trap kind round the edge of the room,
## clear of where you start and where opponents step in.
static func hazards(station: String, room: Rect2, floor_num := 2) -> Array:
	var kind := String(location(station).get("hazard", ""))
	if not Traps.KINDS.has(kind):
		return []
	var inset := float(HAZARD["inset"])
	var spots := [
		Vector2(room.position.x + inset, room.position.y + room.size.y * 0.35), Vector2(room.end.x - inset, room.position.y + room.size.y * 0.35),
		Vector2(room.position.x + inset, room.position.y + room.size.y * 0.72), Vector2(room.end.x - inset, room.position.y + room.size.y * 0.72),
		Vector2(room.position.x + room.size.x * 0.35, room.position.y + inset), Vector2(room.end.x - room.size.x * 0.35, room.position.y + inset)]
	var out: Array = []
	for i in mini(int(HAZARD["count"]), spots.size()):
		var at_pos: Vector2 = spots[i]
		var tr: Dictionary = Traps.make(at_pos, kind, false, floor_num)
		if String(Traps.KINDS[kind].get("shape", "")) == "lane":
			tr["dir"] = Vector2.RIGHT if at_pos.x < room.get_center().x else Vector2.LEFT
			tr["len"] = mini(int(tr["len"]), 3)
			Traps.fit(tr)
		if String(tr.get("trigger", "")) == "timed":
			tr["timer"] = 1.5 + 0.6 * float(i)
		out.append(tr)
	return out


## A bracket's event at a station (stations.gd event): the location's tower
## (its look, its crystals), layout and hazard, its creatures as the first
## round, and the rivals' marks leaning to its tower's essence.
static func adapt(ev: Dictionary, station: String) -> Dictionary:
	var loc := location(station)
	var tower := Travel.tower_of(station) if station != "" else String(ev.get("tower", "kraken"))
	ev["tower"] = tower
	ev["layout"] = String(loc.get("layout", ""))
	ev["hazard"] = String(loc.get("hazard", ""))
	ev["marks_kind"] = String(Towers.TOWERS.get(tower, {}).get("essence", ""))
	var rounds: Array = (ev.get("rounds", []) as Array).duplicate(true)
	var n := int(BRACKET_CREATURES.get(String(ev.get("id", "")), 0))
	var kinds: Array = loc.get("creatures", [])
	if n > 0 and not kinds.is_empty() and not rounds.is_empty():
		var mons: Array = []
		for i in n:
			mons.append(String(kinds[i % kinds.size()]))
		rounds[0] = {"monsters": mons}
	ev["rounds"] = rounds
	return ev


## A round of a bracket in words (a creature round, else stations.gd's).
static func round_text(rd: Dictionary) -> String:
	if rd.has("monsters"):
		var counts := {}
		for k in rd["monsters"]:
			counts[k] = int(counts.get(k, 0)) + 1
		var names: Array = []
		for k in counts:
			names.append(String(k).capitalize() if int(counts[k]) == 1 else "%d %ss" % [counts[k], String(k).capitalize().to_lower()])
		return ", ".join(names)
	return Stations.round_text(rd)


# --- rewards ---------------------------------------------------------------------------------------

## The location's prize piece (a named piece of its tower), or {}.
static func prize_piece(station: String) -> Dictionary:
	var id := String(location(station).get("prize", ""))
	return Gear.make_named(id) if Gear.NAMED.has(id) else {}


static func prize_won(profile, station: String) -> bool:
	return bool(load("res://scripts/training.gd").state(profile)["prizes"].get(station, false))


## What a bracket won here gives besides renown and crystals: the minor
## reward, and the location's prize the first time (from ADVANCED_FROM).
## Returns the lines.
static func reward(profile, station: String, bracket_id: String) -> Array:
	var lines: Array = []
	var item := String(MINOR.get("item", ""))
	if Items.ITEMS.has(item):
		load("res://scripts/train.gd").pack_supply(profile, item, {"air": 0})
		lines.append(String(TEXT["minor_won"]) % String(Items.ITEMS[item].get("name", item)))
	if Stations.bracket_number(bracket_id) >= ADVANCED_FROM and station != "" and not prize_won(profile, station):
		var pc := prize_piece(station)
		if not pc.is_empty():
			load("res://scripts/training.gd").state(profile)["prizes"][station] = true
			if profile.chest.size() < int(load("res://scripts/train.gd").CHEST_SIZE):
				profile.chest.append(pc)
				lines.append(String(TEXT["prize_won"]) % Gear.display(pc))
			else:
				profile.pack.append(pc)
				lines.append(String(TEXT["prize_full"]) % Gear.display(pc))
	return lines

