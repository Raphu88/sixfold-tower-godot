extends RefCounted
## RENOWN: how widely the climbers' world has heard of you. It is kept with
## each climber (profile.gd `renown`, the save's "renown" section; an old
## save loads with none) and only ever grows.
##
## Earned from climbs (every floor reached, every floor past your best in a
## tower, a beast felled: main.gd calls on_climb_end and on_beast), from the
## station's training gym, tournament and challenges (stations.gd), and from
## deeds. Anything later can add to it through one hook:
##
##   Renown.earn(profile, amount, reason)
##
## (`reason` is the words the renown board lists among your recent deeds).
##
## Ranks come at thresholds (RANKS). A rank unlocks the outfitter's upgrades
## (train.gd UPGRADES), the boons at the station's shrine (boons.gd), and
## the gym's drills, the tournament's tiers and the challenges (stations.gd).
##
## TITLES are earned by deeds (TITLES: each has a rule and a number) and one
## can be worn: it shows under your name on the rail and in the book.
##
## Every name, number and word is here (and in the Data editor), easy to
## change. The names are placeholders for the owner to replace.

## The ranks: [id, name, renown needed]. The first is where everyone starts.
static var RANKS := [
	["unknown", "Unknown", 0],
	["noticed", "Noticed", 25],
	["known", "Known", 60],
	["respected", "Respected", 120],
	["famed", "Famed", 200],
	["renowned", "Renowned", 320],
	["celebrated", "Celebrated", 480],
]

## What a climb earns: for every floor reached, for every floor past your
## best in that tower, and for a beast felled.
static var CLIMB := {"floor": 1, "best": 2, "beast": 20}

## Titles: earned by deeds, one worn at a time. Each has its name, the deed
## that earns it (words for the board) and a rule with a number:
##   renown      renown earned, at least n
##   visits      stops at a station, at least n
##   floors      floors climbed in all, at least n
##   beasts      beasts felled, at least n
##   drills      drills cleared (any medal), at least n
##   golds       drills with a gold medal: n of them, or every drill (n = 0)
##   tier        the tournament tier n won (its last bout)
##   unfallen    climbs in a row without falling, at least n
##   challenges  challenges won: n of them, or every one (n = 0)
##   mirror      your mirror image beaten in the arena, at least n times
static var TITLES := {
	"newcomer": {"name": "the Newcomer", "deed": "Stop at a station.", "rule": "visits", "n": 1},
	"trainee": {"name": "the Trainee", "deed": "Clear a drill at the training gym.", "rule": "drills", "n": 1},
	"beastfeller": {"name": "Beastfeller", "deed": "Fell a tower's beast.", "rule": "beasts", "n": 1},
	"stairworn": {"name": "the Stairworn", "deed": "Climb 50 floors in all.", "rule": "floors", "n": 50},
	"surefoot": {"name": "Surefoot", "deed": "Finish 3 climbs in a row without falling.", "rule": "unfallen", "n": 3},
	"goldhand": {"name": "Goldhand", "deed": "Win a gold medal in every drill.", "rule": "golds", "n": 0},
	"contender": {"name": "the Contender", "deed": "Win the first tier of the tournament.", "rule": "tier", "n": 1},
	"ironclad": {"name": "Ironclad", "deed": "Win the second tier of the tournament.", "rule": "tier", "n": 2},
	"champion": {"name": "the Champion", "deed": "Win the third tier of the tournament.", "rule": "tier", "n": 3},
	"glassbreaker": {"name": "Glassbreaker", "deed": "Beat your own mirror image in the arena.", "rule": "mirror", "n": 1},
	"daring": {"name": "the Daring", "deed": "Win a challenge.", "rule": "challenges", "n": 1},
	"unbowed": {"name": "the Unbowed", "deed": "Win every challenge.", "rule": "challenges", "n": 0},
	"talked_of": {"name": "the Talked-of", "deed": "Reach the rank of Renowned.", "rule": "renown", "n": 320},
}
## The order titles are listed in on the board.
static var TITLE_ORDER := ["newcomer", "trainee", "beastfeller", "stairworn", "surefoot", "goldhand", "contender", "ironclad", "champion", "glassbreaker", "daring", "unbowed", "talked_of"]

## How many recent deeds the board remembers.
const DEEDS_KEPT := 10

static var TEXT := {
	"renown": "Renown",
	"rank": "Rank",
	"points": "%d renown",
	"next": "%d more for %s",
	"top": "The highest rank",
	"earned": "+%d renown",
	"rank_up": "Rose to the rank of %s",
	"title_up": "Earned a title: %s",
	"floors": "Climbed to floor %d of %s",
	"best": "A new best in %s: floor %d",
	"beast": "Felled %s",
	"no_title": "No title",
}


# --- the climber's renown ------------------------------------------------------------

## The climber's renown, every key filled in (an old save: none of it).
##   points      renown earned in all
##   deeds       the recent deeds: [{"text", "amount"}], the newest last
##   titles      title ids earned
##   worn        the title worn ("" for none)
##   drills      drill id -> best medal (0 none, 1 bronze, 2 silver, 3 gold)
##   best        drill id -> best score
##   bouts       bout id -> wins
##   tiers       tier number -> won (its last bout won at least once)
##   challenges  challenge id -> won
##   boons       boon id -> level bought (boons.gd)
##   order       the outfitter's special order: a gear code ("" for none)
##   streak      climbs in a row without falling; best_streak the most
##   mirrors     mirror images beaten in the arena
##   visits      stops made at a station
static func state(profile) -> Dictionary:
	if not (profile.renown is Dictionary):
		profile.renown = {}
	var r: Dictionary = profile.renown
	var defaults := {"points": 0, "deeds": [], "titles": [], "worn": "", "drills": {}, "best": {}, "bouts": {}, "tiers": {},
		"challenges": {}, "boons": {}, "order": "", "streak": 0, "best_streak": 0, "mirrors": 0, "visits": 0}
	for k in defaults:
		if not r.has(k) or typeof(r[k]) != typeof(defaults[k]):
			r[k] = defaults[k].duplicate() if defaults[k] is Dictionary or defaults[k] is Array else defaults[k]
	return r


static func points(profile) -> int:
	return int(state(profile)["points"])


## THE HOOK: adds `amount` renown for `reason` (the words the board lists).
## A new rank and any titles the deed earns are noted too. Saves. Returns
## what it did: {"amount", "rank_up" (a rank name or ""), "titles" (ids)}.
static func earn(profile, amount: int, reason: String) -> Dictionary:
	var r := state(profile)
	var before := rank(profile)
	amount = maxi(amount, 0)
	r["points"] = int(r["points"]) + amount
	if amount > 0 or reason != "":
		_deed(r, reason, amount)
	var out := {"amount": amount, "rank_up": "", "titles": []}
	var after := rank(profile)
	if after > before:
		out["rank_up"] = String(RANKS[after][1])
		_deed(r, TEXT["rank_up"] % RANKS[after][1], 0)
	out["titles"] = check_titles(profile)
	profile.save()
	return out


static func _deed(r: Dictionary, text: String, amount: int) -> void:
	if text == "":
		return
	var list: Array = r["deeds"]
	list.append({"text": text, "amount": amount})
	while list.size() > DEEDS_KEPT:
		list.pop_front()


## The rank reached (an index into RANKS).
static func rank(profile) -> int:
	return rank_for(points(profile))


static func rank_for(pts: int) -> int:
	var at := 0
	for i in RANKS.size():
		if pts >= int(RANKS[i][2]):
			at = i
	return at


static func rank_name(i: int) -> String:
	return String(RANKS[clampi(i, 0, RANKS.size() - 1)][1])


## Renown needed for a rank (by index).
static func needed(i: int) -> int:
	return int(RANKS[clampi(i, 0, RANKS.size() - 1)][2])


## How far into the current rank: 0 to 1 (1 at the top).
static func progress(profile) -> float:
	var i := rank(profile)
	if i >= RANKS.size() - 1:
		return 1.0
	var lo := needed(i)
	var hi := needed(i + 1)
	return clampf(float(points(profile) - lo) / maxf(1.0, float(hi - lo)), 0.0, 1.0)


## "12 more for Known", or "The highest rank".
static func next_text(profile) -> String:
	var i := rank(profile)
	if i >= RANKS.size() - 1:
		return TEXT["top"]
	return TEXT["next"] % [needed(i + 1) - points(profile), rank_name(i + 1)]


# --- climbs ------------------------------------------------------------------------------

## A climb ended (main.gd pay_climb, once a climb, however it ended): renown
## for the floors reached and for each floor past your best there; a fall
## breaks the run of climbs without one.
static func on_climb_end(profile, tower_name: String, reached: int, best_before: int, fell: bool) -> Dictionary:
	var r := state(profile)
	if fell:
		r["streak"] = 0
	else:
		r["streak"] = int(r["streak"]) + 1
		r["best_streak"] = maxi(int(r["best_streak"]), int(r["streak"]))
	reached = maxi(reached, 0)
	var past := maxi(0, reached - maxi(best_before, 0))
	var amount := int(CLIMB["floor"]) * reached + int(CLIMB["best"]) * past
	var why: String = TEXT["best"] % [tower_name, reached] if past > 0 else TEXT["floors"] % [reached, tower_name]
	return earn(profile, amount, why)


## A tower's beast fell (main.gd on_enemy_killed).
static func on_beast(profile, beast: String) -> Dictionary:
	return earn(profile, int(CLIMB["beast"]), TEXT["beast"] % beast)


# --- titles ------------------------------------------------------------------------------

## The titles earned (ids, in TITLE_ORDER).
static func titles(profile) -> Array:
	var have: Array = state(profile)["titles"]
	return TITLE_ORDER.filter(func(id): return have.has(id))


## Earns any title whose deed is done now; returns the new ones (ids).
static func check_titles(profile) -> Array:
	var r := state(profile)
	var have: Array = r["titles"]
	var fresh: Array = []
	for id in TITLE_ORDER:
		if not TITLES.has(id) or have.has(id):
			continue
		if deed_done(profile, TITLES[id]):
			have.append(id)
			fresh.append(id)
			_deed(r, TEXT["title_up"] % title_name(id), 0)
	return fresh


## True once a title's deed is done.
static func deed_done(profile, t: Dictionary) -> bool:
	var r := state(profile)
	var n := int(t.get("n", 0))
	match String(t.get("rule", "")):
		"renown":
			return int(r["points"]) >= n
		"visits":
			return int(r["visits"]) >= n
		"floors":
			return profile.count("floors") >= n
		"beasts":
			return profile.count("beasts") >= n
		"drills":
			return r["drills"].values().filter(func(v): return int(v) > 0).size() >= n
		"golds":
			var golds: int = r["drills"].values().filter(func(v): return int(v) >= 3).size()
			if n > 0:
				return golds >= n
			var all: int = load("res://scripts/stations.gd").DRILLS.size()
			return all > 0 and golds >= all
		"tier":
			return bool(r["tiers"].get(str(n), false))
		"unfallen":
			return int(r["best_streak"]) >= n
		"challenges":
			var won: int = r["challenges"].values().filter(func(v): return bool(v)).size()
			if n > 0:
				return won >= n
			var every: int = load("res://scripts/stations.gd").CHALLENGES.size()
			return every > 0 and won >= every
		"mirror":
			return int(r["mirrors"]) >= n
	return false


static func title_name(id: String) -> String:
	return String(TITLES.get(id, {}).get("name", ""))


## The title worn, by name ("" for none).
static func worn_title(profile) -> String:
	var r := state(profile)
	var id := String(r["worn"])
	if id == "" or not r["titles"].has(id):
		return ""
	return title_name(id)


## A stop at a station (station_page.gd): counted, and any title it earns.
static func on_visit(profile) -> Array:
	var r := state(profile)
	r["visits"] = int(r["visits"]) + 1
	var fresh := check_titles(profile)
	profile.save()
	return fresh


## Wears a title you've earned ("" takes it off). True if done.
static func wear(profile, id: String) -> bool:
	var r := state(profile)
	if id != "" and not r["titles"].has(id):
		return false
	r["worn"] = id
	profile.save()
	return true
