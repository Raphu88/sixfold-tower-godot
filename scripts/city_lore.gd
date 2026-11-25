extends RefCounted
## THE CITIES: the world's lore in what people say to the climber. Three
## things, every word and number here (the Data editor: "The cities: lore in
## what people say"):
##
## THE AURA IN HOW PEOPLE SPEAK (AURA): core essence changes who a climber is
##   as it builds (secret.gd STEPS: the aura's six steps). Nobles (noble.gd
##   greet), the Dining car's climbers (dining.gd greeting) and rival
##   climbers in the towers (rivals.gd _line) greet a climber on the path of
##   Making or Unmaking with a line for that path and step (AURA_CHANCE of the
##   time, the rest their usual words): Making draws people near, Unmaking
##   makes them give way. Lines that speak of the climber use their pronouns
##   (pronouns.gd tokens: {they}, {them}...).
##
## THE NOBLE'S PERSUASION (PERSUADE): Nobles are climbers who stopped short
##   of the summits and were persuaded to keep people in order. As the
##   climber grows strong (guardians beaten, or a high renown rank: each step
##   of PERSUADE "steps" needs either), their HOME station's Noble quietly
##   tries to talk them into stopping, the way they were once persuaded: a
##   few lines over time, in order, one now and then in the greeting (always
##   the first time a new step is reached; then PERSUADE "chance"). Never a
##   blocker: nothing changes but the words.
##
## PASSING AS MARKED (PASSING): in the stations an Unbound climber is taken
##   for marked. Each visit (a station, between two climbs: a stay rolls once,
##   however often you step off) has a small chance of finding them out:
##   PASSING "start", plus "per_level" for each level of their biggest Node,
##   plus "per_step" for each aura step, at most "most". Found out, the
##   station reacts for that visit: the Noble grants no titles or contracts
##   (a cold greeting instead), the station's fees cost "price" times as much,
##   and a rumour spreads that rivals and the Dining car's climbers repeat for
##   "rumour_climbs" climbs. A flat warning at the top of every stop says so.
##   Never a game-over. Rival climbers who don't know take the climber for
##   marked (TALK "passing"), "talk_chance" of the time.
## The Entity: first-time moments for passing (unbound_passing), being found
## out (found_out) and the Noble's first word of persuasion (noble_persuades);
## "How does it work?" has "Passing as marked in the cities?".
## Kept with the climber: profile.gd `lore` ({} for an old save; state()
## fills it).

const Secret := preload("res://scripts/secret.gd")
const Unbound := preload("res://scripts/unbound.gd")
const Pronouns := preload("res://scripts/pronouns.gd")

## How often a greeting carries the aura's line (once there is an aura step).
static var AURA_CHANCE := 0.7
## What people say by path ("life" is Making), by who speaks, one line per
## aura step (index = step - 1).
static var AURA := {
	"life": {
		"noble": [
			"\"You look rested, climber. The towers agree with you.\"",
			"\"Sit. Something about you settles a room.\"",
			"(to a steward) \"Bring {them} the good chair. {They} {have} earned a little comfort.\"",
			"\"My healers ask after you. They say things grow where you stand.\"",
			"\"People line the platform when your train comes in. They want to be near you.\"",
			"(quietly) \"There is Making in you now, more than in any climber I have known. Use it gently.\"",
		],
		"dining": [
			"\"You look well. Sit with us.\"",
			"\"Funny. My shoulder stopped aching when you sat down.\"",
			"(to the table) \"Make room. {They} always bring{s} luck.\"",
			"\"The cook saves you the warm bread now. Have you noticed?\"",
			"\"Strangers ask me if I know you. I tell them I do.\"",
			"(softly) \"Some of them call you a healer now. Do you mind?\"",
		],
		"rival": [
			"\"You look steady.\"",
			"\"Strange. I feel better with you about.\"",
			"\"I've heard of you. The one people breathe easier near.\"",
			"\"Even the monsters seem slower round you.\"",
			"\"Whatever you carry, it's Making. I can feel it from here.\"",
			"(lowering a blade) \"I'd rather not cross someone like you.\"",
		],
	},
	"unmaking": {
		"noble": [
			"\"You've a hard look about you today, climber.\"",
			"\"Mind the tapestries. Things fray near you.\"",
			"(to a steward) \"Keep the doors open while {they} {are} here.\"",
			"\"My guards stand straighter when you pass. They don't know why.\"",
			"\"The candles gutter when you come in. Sit, quickly, and say what you need.\"",
			"(quietly) \"There is Unmaking in you now. Everything in this room knows it. So do I.\"",
		],
		"dining": [
			"\"You look like you slept on a blade. Sit, if you want.\"",
			"\"The cups rattle when you sit down. Must be the rails.\"",
			"(to the table) \"Shift over. Not too close to {them}.\"",
			"\"Half the car went quiet when you came in. Not me. Mostly.\"",
			"\"I don't mind you. The others ask how I can bear sitting here.\"",
			"(barely a whisper) \"They say things come apart where you walk. Not in here, please.\"",
		],
		"rival": [
			"\"You look like trouble.\"",
			"\"Keep your distance. Nothing personal.\"",
			"\"I've heard of you. The floors crack where you've been.\"",
			"\"My blade went cold when you walked in. Was that you?\"",
			"\"Unmaking. I can smell it on you, like a storm.\"",
			"(stepping back) \"Easy. I've no quarrel with whatever you're becoming.\"",
		],
	},
}

## The Noble's persuasion: at the home station, once the climber is strong
## enough for a step (its "beasts": guardians beaten, at least that many
## towers; or its "rank": renown rank, renown.gd RANKS index), its lines in
## order, one now and then in the greeting.
static var PERSUADE := {
	"chance": 0.6,
	"steps": [
		{"beasts": 1, "rank": 5, "lines": [
			"\"You climb well. Have you thought about when you'll stop? The best of us do, sooner or later.\"",
			"\"I climbed too, once. Someone sat where I sit now and asked me what the summits would cost. It was a good question.\""]},
		{"beasts": 3, "rank": 8, "lines": [
			"\"This city needs climbers who come home. Strong ones, who stay. Think on it.\"",
			"\"The guardians and the Makers listen to those of us who keep order here. I could ask them for things. So could you, in time.\""]},
		{"beasts": 5, "rank": 10, "lines": [
			"\"Every climber who went all the way changed the world, and not always for the better. Help me keep the next fracture from ever coming.\"",
			"(to the steward, as you sit) \"Ready the east rooms. {They} may be staying with us one day.\" Then, to you: \"Think on it.\""]},
	],
}

## Passing as marked (an Unbound in the stations): the chance of being found
## out each visit, and what it costs then.
##   start, per_level, per_step, most  the chance: start + per_level x the
##                                     biggest Node's level + per_step x the
##                                     aura's step, at most `most`
##   price          a found-out visit's station fees, times this
##   rumour_climbs  how many climbs the rumour lasts
##   talk_chance    how often rivals and the Dining car's climbers mention it
static var PASSING := {"start": 0.04, "per_level": 0.01, "per_step": 0.02, "most": 0.3, "price": 1.25, "rumour_climbs": 3, "talk_chance": 0.25}

## Words: the found-out warning and refusals, the Noble's cold greeting,
## what rivals and the Dining car say ({city} filled in).
static var TEXT := {
	"found_banner": "Found out: word is you're Unbound. This visit the Noble grants no titles or contracts, and fees here cost %d%% more.",
	"refused": "The Noble won't deal with you this visit: you were found out.",
	"noble_found": [
		"\"I know what you are. No guardian ever marked you. Leave my titles and my work alone today.\"",
		"\"Unbound. In my own rooms. You'll get nothing from me this visit. Count yourself lucky that's all.\"",
	],
	"passing": [
		"\"Which mark got you this high?\"",
		"\"Your marks treat you well? Mine burn on the stairs.\"",
		"\"Climbing marked is hard enough. Imagine climbing without.\"",
	],
	"rumour": [
		"\"Heard they found an Unbound in {city}. Walking the platform like anyone.\"",
		"\"Someone in {city} turned out Unbound. The Noble's people looked everywhere after.\"",
		"\"Word from {city}: an Unbound, passing as marked. Could be anyone.\"",
	],
}


## The climber's lore state (profile.gd `lore`): the visit rolled ("key"),
## found out on it ("found"), times found out ("found_n"), the rumour
## ({station, climbs}), the Noble's persuasion told so far ("persuaded")
## and its highest step said ("persuade_step").
static func state(prof) -> Dictionary:
	if prof == null:
		return {}
	var d = prof.get("lore")
	if not (d is Dictionary):
		prof.set("lore", {})
		d = prof.get("lore")
	if not (d is Dictionary):
		return {}
	var defaults := {"key": "", "found": false, "found_n": 0, "rumour": {}, "persuaded": 0, "persuade_step": 0}
	for k in defaults:
		if not d.has(k) or typeof(d[k]) != typeof(defaults[k]):
			d[k] = defaults[k].duplicate() if defaults[k] is Dictionary else defaults[k]
	return d


static func _fill(prof, text: String) -> String:
	return Pronouns.fill_for(text, Pronouns.of_look(prof.get("appearance") if prof != null else null))


static func _pick(pool: Array) -> String:
	return String(pool[randi() % pool.size()]) if not pool.is_empty() else ""


# --- the aura in how people speak --------------------------------------------------------------

## The aura's step (0 before the first, or with no path chosen).
static func aura_step(prof) -> int:
	if prof == null or String(prof.get("path")) == "":
		return 0
	return Secret.step_for(float(prof.get("flow")))


## What `who` ("noble", "dining", "rival") says to the climber for their path
## and aura step ("" with no aura, or when the roll falls to their usual
## words: AURA_CHANCE; `chance` for tests).
static func aura_line(prof, who: String, chance := -1.0) -> String:
	var after: String = load("res://scripts/story_scenes.gd").greeting(prof, who, chance)
	if after != "":
		return after  # (after the ending: greeted by what the climber chose, story_scenes.gd GREET)
	var step := aura_step(prof)
	if step <= 0:
		return ""
	var lines: Array = AURA.get(String(prof.path), {}).get(who, [])
	if lines.is_empty() or randf() >= (AURA_CHANCE if chance < 0.0 else chance):
		return ""
	return _fill(prof, String(lines[mini(step, lines.size()) - 1]))


# --- the Noble's persuasion ----------------------------------------------------------------

## How strong the climber is for the persuasion: the highest PERSUADE step
## reached (0 for none).
static func persuade_step(prof) -> int:
	if prof == null:
		return 0
	var beasts := 0
	var by = prof.record.get("beasts_by", {})
	if by is Dictionary:
		beasts = by.keys().filter(func(k): return int(by[k]) > 0).size()
	var rank: int = load("res://scripts/renown.gd").rank(prof)
	var steps: Array = PERSUADE["steps"]
	var s := 0
	for i in steps.size():
		if beasts >= int(steps[i].get("beasts", 99)) or rank >= int(steps[i].get("rank", 99)):
			s = i + 1
	return s


## The Noble's quiet word of persuasion in the greeting ("" for none): at
## the climber's home station only, once they're strong enough; the lines
## of the steps reached, in order, one at a time (always when a new step is
## reached; else PERSUADE "chance", or `chance` for tests); once every line
## is told, one of the last step's again.
static func persuade_word(prof, station: String, chance := -1.0) -> String:
	if prof == null or station == "" or station != load("res://scripts/travel.gd").home(prof):
		return ""
	var step := persuade_step(prof)
	if step <= 0:
		return ""
	var st := state(prof)
	var fresh := step > int(st["persuade_step"])
	var c: float = (1.0 if fresh else float(PERSUADE["chance"])) if chance < 0.0 else chance
	if randf() >= c:
		return ""
	var steps: Array = PERSUADE["steps"]
	var open: Array = []
	for i in step:
		open.append_array(steps[i].get("lines", []))
	if open.is_empty():
		return ""
	var told := int(st["persuaded"])
	var said := ""
	if told < open.size():
		said = String(open[told])
		st["persuaded"] = told + 1
	else:
		said = _pick(steps[step - 1].get("lines", []))
	st["persuade_step"] = maxi(int(st["persuade_step"]), step)
	return _fill(prof, said)


# --- passing as marked -----------------------------------------------------------------------

## An Unbound's chance of being found out on a station visit (0 for the marked).
static func found_chance(prof) -> float:
	if not Unbound.is_on(prof):
		return 0.0
	var top := 0
	for part in Unbound.PARTS:
		top = maxi(top, Unbound.level(prof, part))
	var c := float(PASSING["start"]) + float(PASSING["per_level"]) * float(top) + float(PASSING["per_step"]) * float(aura_step(prof))
	return clampf(c, 0.0, float(PASSING["most"]))


## A visit's key: the station, between two climbs.
static func visit_key(prof, station: String) -> String:
	return "%s:%d" % [station, int(prof.climbs)]


## Arriving at a station (station_page.gd arrive): an Unbound's visit rolls
## once (`roll` for tests: the number rolled, 0..1). True if they were found
## out just now.
static func on_visit(prof, station: String, roll := -1.0) -> bool:
	if prof == null or station == "":
		return false
	var st := state(prof)
	var key := visit_key(prof, station)
	if String(st["key"]) == key:
		return false
	st["key"] = key
	st["found"] = false
	if not Unbound.is_on(prof):
		return false
	if (randf() if roll < 0.0 else roll) >= found_chance(prof):
		return false
	st["found"] = true
	st["found_n"] = int(st["found_n"]) + 1
	st["rumour"] = {"station": station, "climbs": int(prof.climbs)}
	return true


## True when the climber was found out on this visit to `station` (the
## station they're at when "").
static func found_out(prof, station := "") -> bool:
	if not Unbound.is_on(prof):
		return false
	if station == "":
		station = load("res://scripts/travel.gd").current(prof)
	var st := state(prof)
	return bool(st["found"]) and String(st["key"]) == visit_key(prof, station)


## The station's fees on a found-out visit, times this (1 otherwise).
static func price_mult(prof, station := "") -> float:
	return float(PASSING["price"]) if found_out(prof, station) else 1.0


## The found-out warning at the top of every stop.
static func banner() -> String:
	return String(TEXT["found_banner"]) % int(round((float(PASSING["price"]) - 1.0) * 100.0))


## The Noble's cold greeting on a found-out visit.
static func noble_found() -> String:
	return _pick(TEXT["noble_found"])


## The city the rumour comes from ("" when none is going round: it lasts
## PASSING "rumour_climbs" climbs).
static func rumour_city(prof) -> String:
	if not Unbound.is_on(prof):
		return ""
	var r: Dictionary = state(prof)["rumour"]
	if r.is_empty() or int(prof.climbs) - int(r.get("climbs", -99)) > int(PASSING["rumour_climbs"]):
		return ""
	return String(load("res://scripts/stations.gd").station(String(r.get("station", ""))).get("name", ""))


## What a rival or a Dining car climber says of passing ("" for the marked,
## or when the roll says nothing: PASSING "talk_chance", `chance` for
## tests): the rumour of the climber being found out while it goes round,
## else words that take them for marked.
static func passing_word(prof, chance := -1.0) -> String:
	if not Unbound.is_on(prof) or randf() >= (float(PASSING["talk_chance"]) if chance < 0.0 else chance):
		return ""
	var city := rumour_city(prof)
	if city != "":
		return _fill(prof, _pick(TEXT["rumour"]).replace("{city}", city))
	return _fill(prof, _pick(TEXT["passing"]))
