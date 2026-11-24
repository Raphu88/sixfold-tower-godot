extends RefCounted
## TRAVEL: the six stations on a loop, and the train between them.
##
## Six stations (stations.gd STATIONS), each in a major city near its tower,
## sit on a loop in tower order (towers.gd ORDER). The climber is always at
## one of them (profile.station; "" means their home station, the one near
## profile.home). Climbing a tower starts from the station near it, so you
## choose a tower by riding there first.
##
##   the map    the engine car's tower selection map (engine_page.gd): all
##              six towers on the loop, the station you're at, the fare to
##              each one, and the lock
##   the fare   FARE crystals of any kind for each stop, going the shorter
##              way round (so 12, 24 or 36 at most); the title you wear may
##              cut it (titles.gd SOCIAL, its "travel" group: fare_cut)
##   the lock   travel to other stations is locked until the climber earns
##              their first mark (a faint one counts), or becomes Unbound
##
## THE ENTITY'S TOURS (TOURS, run by tour.gd): at a station it shows the
## gym, the tournament grounds, the Noble's estate and the train; the first
## time the train is chosen, its cars: the climbers' car (each of its
## things), the outfitter, the workshop, the dining car, the settings and
## controls car and last the engine with its map. Each step names where it
## goes ("stop" at a station, "car" on the train), what the Entity points
## at ("point": [tag, value]: a rail entry, or a thing tagged that way in
## the car) and what it says ("say" in the tour's bar, "point_say" in the
## bubble beside what it points at). Skippable, and replayed from the
## Entity's talk ("Show me around again").
##
## Every word and number is here (and in the Data editor). City and Noble
## names are placeholders in stations.gd, the owner's to write.

const Towers := preload("res://scripts/towers.gd")
const Stations := preload("res://scripts/stations.gd")
const Titles := preload("res://scripts/titles.gd")
const Unbound := preload("res://scripts/unbound.gd")
const OutfitterName := preload("res://scripts/outfitter_name.gd")

## Crystals of any kind for each stop of a ride.
static var FARE := 12

static var TEXT := {
	"map_title": "Choose your tower",
	"map_sub": "Six stations on a loop, one near each tower. You climb from the station you're at.",
	"here": "You're here",
	"home": "Home",
	"home_station": "Your home station",
	"near": "Near %s",
	"stops_one": "1 stop away",
	"stops_many": "%d stops away",
	"shorter": "the shorter way round",
	"locked": "Locked",
	"lock_why": "Travel opens with your first mark, or once you become Unbound.",
	"lock_short": "Opens with your first mark",
	"ride_tag": "A ride on the loop",
	"fare": "Fare",
	"fare_note": "Paid in crystals of any kind, the biggest first. %d a stop.",
	"fare_cut": "Your title takes %d%% off",
	"ride": "Ride",
	"ride_for": "to %s",
	"step_off": "Step off",
	"step_off_long": "Step off at %s",
	"cant_pay": "Needs %d more crystals, of any kind.",
	"rode": "The train pulls into %s. Fare paid: %s.",
	"rode_free": "The train pulls into %s.",
	"climb_from": "You're at %s. Its tower is open to you.",
	"stop_fare": "%d",
	"legend_fare": "a stop",
	"crest_home": "Home station",
	"crest_visit": "Visiting",
	"help_here": "You're here: pull the lever to climb it.",
	"help_locked": "Locked: travel opens with your first mark, or once you become Unbound.",
	"help_ride": "%s away, %s crystals of any kind. Choose it to see the ride.",
	"shared_titles": "Titles are shared by every Noble: one granted here is yours at every station.",
	# The tour's bar (tour.gd).
	"tour_tag": "The Entity's tour · %d of %d",
	"tour_next": "Next",
	"tour_done": "Done",
	"tour_back": "Back",
	"tour_skip": "Skip the tour",
	# The Entity's talk ("How does it work?": stations and travel).
	"talk_cut": "Your title takes %d%% off, so a stop costs %d.",
	"talk_no_cut": "Some titles cut the fare.",
	"talk_locked": "For now travel is locked: it opens with your first mark, or once you're Unbound.",
	"talk_open": "Travel is open to you.",
}

## The tours, in order (see the top).
static var TOURS: Dictionary = OutfitterName.named({
	"station": [
		{"stop": "gym", "point": ["rail", "gym"], "point_say": "The gym: Training.",
			"say": "This is a station. Start at the gym: basic training, one session with me, then medal drills. Nothing here can fell you."},
		{"stop": "arena", "point": ["rail", "arena"], "point_say": "The tournament grounds.",
			"say": "The tournament grounds: brackets against other climbers. Nobody dies; the loser yields. Winning pays renown, crystals and titles."},
		{"stop": "noble", "point": ["rail", "noble"], "point_say": "The Noble's estate.",
			"say": "The Noble's estate. Every station has its own Noble: titles for your renown, and contracts for the towers. Titles are shared by every Noble."},
		{"stop": "noble", "point": ["rail", "leave_station"], "point_say": "The train.",
			"say": "And the train: your car, {outfitter}, the workshop, and the engine that takes you to a tower. Board it when you're ready; I'll show you round."},
	],
	"train": [
		{"car": "personal", "point": ["furnish", "rack"], "point_say": "What you'll wear on your next climb.",
			"say": "The train. First, the climbers' car, your own. The wardrobe holds what you'll wear on your next climb, slot by slot. Choose a slot to change it."},
		{"car": "personal", "point": ["furnish", "pack"], "point_say": "Your pack.",
			"say": "Your pack goes up the tower with you. A fall can lose it."},
		{"car": "personal", "point": ["furnish", "chest"], "point_say": "Your stash.",
			"say": "Your stash stays on the train, safe. Nothing in it is ever at risk."},
		{"car": "personal", "point": ["rail", "climber"], "point_say": "Your climber's book.",
			"say": "Your name and marks, at the top of the rail: your climber's book. Abilities, marks, essence and your record."},
		{"car": "store", "point": ["rail", "store"], "point_say": "The Outfitter's Car.",
			"say": "{outfitter}, the outfitter, buys what climbers bring down and sells to the next ones up. Supplies, gear and charms, for crystals."},
		{"car": "workshop", "point": ["furnish", "drawers"], "point_say": "The bench's drawers.",
			"say": "The workshop: brew supplies, break pieces down into crystals, craft tinctures. Each drawer opens one kind of work."},
		{"car": "dining", "point": ["furnish", "tables"], "point_say": "Climbers at their tables.",
			"say": "The dining car: other climbers between towers. Talk for rumors, wagers, trades and duels."},
		{"car": "settings", "point": ["furnish", "signal"], "point_say": "Settings and controls.",
			"say": "The settings and controls car: sound, screen, sizes, my words, and every key."},
		{"car": "engine", "point": ["travel_map", "map"], "point_say": "The tower map.",
			"say": "And the engine. Its map shows the six towers on a loop, a station near each. You climb the tower by the station you're at: choose it and pull the lever. To climb another, ride there first."},
	],
})


# --- the loop ------------------------------------------------------------------------------

## The stations' ids in loop order (each station's tower, in tower order).
static func loop() -> Array:
	var out: Array = []
	for t in Towers.ORDER:
		var id := station_for(t)
		if id != "" and not out.has(id):
			out.append(id)
	return out


## The station near a tower ("" if none).
static func station_for(tower: String) -> String:
	for s in Stations.STATIONS:
		if String(s.get("tower", s["id"])) == tower:
			return String(s["id"])
	return ""


## The tower a station is near.
static func tower_of(station: String) -> String:
	var t := String(Stations.station(station).get("tower", station))
	return t if Towers.TOWERS.has(t) else Towers.ORDER[0]


## The climber's home station (near profile.home).
static func home(profile) -> String:
	var t := String(profile.get("home")) if profile != null and profile.get("home") != null else ""
	var id := station_for(t)
	return id if id != "" else String(loop()[0])


## The station the climber is at.
static func current(profile) -> String:
	var id := String(profile.get("station")) if profile != null and profile.get("station") != null else ""
	return id if loop().has(id) else home(profile)


## Stops between two stations, the shorter way round (0 for the same one).
static func stops(a: String, b: String) -> int:
	var l := loop()
	var i := l.find(a)
	var j := l.find(b)
	if i < 0 or j < 0:
		return 0
	var d := absi(i - j)
	return mini(d, l.size() - d)


## "Near the Gryphon's Tower".
static func near(tower: String) -> String:
	var name := String(Towers.TOWERS.get(tower, {}).get("name", tower))
	if name.begins_with("The "):
		name = "the " + name.substr(4)
	return String(TEXT["near"]) % name


## The most stops a ride can be (half the loop).
static func max_stops() -> int:
	return loop().size() / 2


# --- the fare ------------------------------------------------------------------------------

## The share the worn title takes off the fare (0 to 1).
static func fare_cut(profile) -> float:
	return clampf(Titles.num(profile, "travel", "fare_cut"), 0.0, 1.0)


## One stop's fare for this climber (the title's cut taken off, whole crystals).
static func stop_fare(profile) -> int:
	return maxi(0, int(round(float(FARE) * (1.0 - fare_cut(profile)))))


## The fare from where the climber is to a station.
static func fare(profile, to: String) -> int:
	return stops(current(profile), to) * stop_fare(profile)


# --- the lock ------------------------------------------------------------------------------

## Travel is open: the first mark earned (a faint one too), or Unbound.
static func unlocked(profile) -> bool:
	if profile == null:
		return false
	return not profile.bonds.is_empty() or Unbound.is_on(profile)


## Why a ride can't be taken ("" if it can).
static func why_not(profile, to: String) -> String:
	if not loop().has(to) or to == current(profile):
		return "?"
	if not unlocked(profile):
		return String(TEXT["lock_why"])
	var f := fare(profile, to)
	if f > 0 and int(profile.crystals_held()) < f:
		return String(TEXT["cant_pay"]) % (f - int(profile.crystals_held()))
	return ""


## Rides the train to a station: pays the fare and moves the climber there.
## Returns {"ok", "fare", "paid" ({kind: amount}), "why", "line"}. Saves.
static func ride(profile, to: String) -> Dictionary:
	var why := why_not(profile, to)
	if why != "":
		return {"ok": false, "why": why, "fare": fare(profile, to), "paid": {}}
	var f := fare(profile, to)
	var paid := {}
	if f > 0:
		paid = profile.spend_any(float(f))
		if paid.is_empty():
			return {"ok": false, "why": String(TEXT["cant_pay"]) % f, "fare": f, "paid": {}}
	profile.station = to
	var name := String(Stations.station(to).get("name", to))
	var line := String(TEXT["rode"]) % [name, str(f)] if f > 0 else String(TEXT["rode_free"]) % name
	profile.save()
	return {"ok": true, "why": "", "fare": f, "paid": paid, "line": line}


# --- the Entity ----------------------------------------------------------------------------

## The engine car's first-time tips (entity.gd TIPS): the map, then the lock
## or the fares.
static func engine_tips(profile) -> Array:
	return ["travel", "fares" if unlocked(profile) else "travel_lock"]


## The facts for the Entity's talk about stations and travel.
static func talk_facts(profile) -> Dictionary:
	var f := {"fare": str(FARE), "max_fare": str(FARE * max_stops()), "stations": str(loop().size())}
	if profile == null:
		return f
	f["station"] = String(Stations.station(current(profile)).get("name", ""))
	f["home"] = String(Stations.station(home(profile)).get("name", ""))
	var cut := fare_cut(profile)
	f["title_cut"] = String(TEXT["talk_cut"]) % [int(round(cut * 100.0)), stop_fare(profile)] if cut > 0.0 else String(TEXT["talk_no_cut"])
	f["lock"] = String(TEXT["talk_open"]) if unlocked(profile) else String(TEXT["talk_locked"])
	return f
