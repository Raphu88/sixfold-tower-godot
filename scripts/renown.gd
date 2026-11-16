extends RefCounted
## RENOWN: how widely the climbers' world has heard of you. It is kept with
## each climber (profile.gd `renown`, the save's "renown" section; an old
## save loads with none) and only ever grows.
##
## Earned from climbs (every floor reached, every floor past your best in a
## tower, a beast felled: main.gd calls on_climb_end and on_beast), from the
## station's training, tournaments and the Noble's contracts (stations.gd,
## contracts.gd), and from deeds with other climbers. Anything later can add
## to it through one hook:
##
##   Renown.earn(profile, amount, reason)
##
## (`reason` is the words the renown board lists among your recent deeds,
## and the line said in play: "+6 renown: won a duel with Bryn"). Every gain
## is SAID: main.gd sets `heard`, a Callable told of each gain, which puts
## the line in the feed and the Entity's log, and makes a rank-up a moment
## (a banner, and the Entity's remark).
##
## Ranks come at thresholds (RANKS), and each rank OPENS THINGS TO DO
## (RANK_OPENS): a higher tournament bracket, more of the Noble's contracts,
## a new tier of titles, a charm recipe, cheaper charm refills. The Renown
## Board shows what the next rank opens. The outfitter's stock grows with
## rank too (shop.gd, train.gd UPGRADES), but that comes second.
##
## TITLES: each has a rank (its tier: the Noble grants it no sooner) and a
## deed. Once both are done, the Noble at a station offers it (noble.gd);
## granted, it can be worn, one at a time: it shows under your name on the
## rail and in the book, and its SOCIAL BENEFITS apply (titles.gd: rival
## climbers, training, tournaments, the outfitter).
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

## What each rank opens, one list per rank (RANKS order). Each entry:
##   kind  lessons   the Training basics (stations.gd LESSONS)
##         bracket   a tournament bracket (stations.gd BRACKETS, by "id")
##         titles    a new tier of titles from the Noble
##         contracts the Noble's contracts: "n" at once, "kinds" offered
##         recipe    a charm recipe for a Rune Artist's bench (charms.gd, "id")
##         refill    charm refills cost "cut" less (a share)
## The words are made from the kind (TEXT "open_*") unless "text" says them.
static var RANK_OPENS := [
	[{"kind": "lessons"}, {"kind": "bracket", "id": "novice"}, {"kind": "contracts", "n": 1, "kinds": ["reach", "retrieve"]}, {"kind": "titles"}],
	[{"kind": "titles"}, {"kind": "contracts", "n": 1, "kinds": ["slay"]}, {"kind": "recipe", "id": "mending_bead"}],
	[{"kind": "bracket", "id": "open"}, {"kind": "refill", "cut": 0.25}, {"kind": "titles"}],
	[{"kind": "contracts", "n": 2, "kinds": []}, {"kind": "recipe", "id": "keepers_purse"}, {"kind": "titles"}],
	[{"kind": "bracket", "id": "masters"}, {"kind": "refill", "cut": 0.5}, {"kind": "titles"}, {"kind": "recipe", "id": "tide_shell"}],
	[{"kind": "recipe", "id": "bulwark_stone"}, {"kind": "titles"}, {"kind": "refill", "cut": 0.6}],
	[{"kind": "bracket", "id": "champions"}, {"kind": "recipe", "id": "gale_charm"}, {"kind": "titles"}],
]

## What a climb earns: for every floor reached, for every floor past your
## best in that tower, and for a beast felled.
static var CLIMB := {"floor": 1, "best": 2, "beast": 20}

## Titles. Each has its name, its rank (the tier: the Noble grants it no
## sooner than this rank, an index into RANKS), the deed that earns it
## (words for the Noble's card) and a rule with a number:
##   none        no deed: the rank is enough
##   renown      renown earned, at least n
##   visits      stops at a station, at least n
##   floors      floors climbed in all, at least n
##   beasts      beasts felled, at least n
##   lessons     the Training basics all done (stations.gd LESSONS)
##   drills      medal drills cleared (any medal), at least n
##   golds       medal drills with a gold: n of them, or every one (n = 0)
##   tier        the tournament bracket n won (stations.gd BRACKETS, 1 first)
##   unfallen    climbs in a row without falling, at least n
##   contracts   the Noble's contracts finished, at least n (contracts.gd)
##   mirror      your own reflection beaten in a tournament, at least n times
##   rivals      deeds with other climbers (rivals.gd), at least n: "of" says
##               which ("duels_won", "teamed", "rescued", "traded"...)
## What a worn title does is in titles.gd SOCIAL.
static var TITLES := {
	"newcomer": {"name": "the Newcomer", "rank": 0, "deed": "Stop at a station.", "rule": "visits", "n": 1},
	"trainee": {"name": "the Trainee", "rank": 0, "deed": "Finish the Training basics at a station.", "rule": "lessons", "n": 0},
	"contender": {"name": "the Contender", "rank": 1, "deed": "Win the Novice Bracket of a tournament.", "rule": "tier", "n": 1},
	"beastfeller": {"name": "Beastfeller", "rank": 1, "deed": "Fell a tower's beast.", "rule": "beasts", "n": 1},
	"shieldmate": {"name": "Shieldmate", "rank": 1, "deed": "Team up with another climber.", "rule": "rivals", "of": "teamed", "n": 1},
	"helping_hand": {"name": "the Helping Hand", "rank": 1, "deed": "Help a wounded climber back to their feet.", "rule": "rivals", "of": "rescued", "n": 1},
	"stairworn": {"name": "the Stairworn", "rank": 2, "deed": "Climb 50 floors in all.", "rule": "floors", "n": 50},
	"surefoot": {"name": "Surefoot", "rank": 2, "deed": "Finish 3 climbs in a row without falling.", "rule": "unfallen", "n": 3},
	"duelist": {"name": "the Duelist", "rank": 2, "deed": "Win 3 duels with other climbers.", "rule": "rivals", "of": "duels_won", "n": 3},
	"trusted": {"name": "the Trusted", "rank": 2, "deed": "Finish 3 of the Noble's contracts.", "rule": "contracts", "n": 3},
	"ironclad": {"name": "Ironclad", "rank": 3, "deed": "Win the Open Bracket of a tournament.", "rule": "tier", "n": 2},
	"goldhand": {"name": "Goldhand", "rank": 3, "deed": "Win a gold medal in every medal drill.", "rule": "golds", "n": 0},
	"glassbreaker": {"name": "Glassbreaker", "rank": 3, "deed": "Beat your own reflection in a tournament.", "rule": "mirror", "n": 1},
	"champion": {"name": "the Champion", "rank": 4, "deed": "Win the Masters' Bracket of a tournament.", "rule": "tier", "n": 3},
	"talked_of": {"name": "the Talked-of", "rank": 5, "deed": "Reach the rank of Renowned.", "rule": "none", "n": 0},
	"paragon": {"name": "the Paragon", "rank": 6, "deed": "Win the Champions' Bracket of a tournament.", "rule": "tier", "n": 4},
}
## The order titles are listed in (by tier).
static var TITLE_ORDER := ["newcomer", "trainee", "contender", "beastfeller", "shieldmate", "helping_hand", "stairworn", "surefoot", "duelist", "trusted",
	"ironclad", "goldhand", "glassbreaker", "champion", "talked_of", "paragon"]

## How many recent deeds the board remembers.
const DEEDS_KEPT := 10

static var TEXT := {
	"renown": "Renown",
	"rank": "Rank",
	"points": "%d renown",
	"next": "%d more for %s",
	"top": "The highest rank",
	"earned": "+%d renown",
	"gain": "+%d renown: %s",
	"rank_up": "Rose to the rank of %s",
	"rank_title": "RENOWN: %s",
	"rank_opens": "Opens: %s",
	"title_up": "A title awaits you at the Noble: %s",
	"granted": "Granted the title %s",
	"floors": "Climbed to floor %d of %s",
	"best": "A new best in %s: floor %d",
	"beast": "Felled %s",
	"no_title": "No title",
	"refund": "The Boon Shrine has closed. What you paid for your boons came back as crystals: %s",
	# What a rank opens (RANK_OPENS), in words.
	"open_lessons": "Training at the stations: the basics, hands on",
	"open_bracket": "the %s at the tournament",
	"open_titles": "new titles from the Noble",
	"open_contracts": "the Noble's contracts",
	"open_contracts_n": "%d of the Noble's contracts at once",
	"open_contracts_kind": "%s contracts",
	"open_recipe": "a charm recipe: %s",
	"open_refill": "charm refills %d%% cheaper",
	"open_nothing": "nothing new",
	"and": ", ",
}


# --- the climber's renown ------------------------------------------------------------

## The climber's renown, every key filled in (an old save: none of it).
##   points      renown earned in all
##   deeds       the recent deeds: [{"text", "amount"}], the newest last
##   titles      title ids granted (by the Noble, or earned before the Noble)
##   ready       title ids whose deed and rank are done, announced once
##   worn        the title worn ("" for none)
##   rank_seen   the highest rank whose moment was shown (a banner, the Entity)
##   lessons     lesson id -> 1 done, 2 skipped (stations.gd LESSONS)
##   drills      drill id -> best medal (0 none, 1 bronze, 2 silver, 3 gold)
##   best        drill id -> best score
##   tiers       bracket number -> won (stations.gd BRACKETS, 1 first)
##   rounds      bracket id -> the most rounds won in one go
##   recipes     charm recipes learned from contracts (charms.gd LOCKED)
##   contracts   the Noble's contracts taken (contracts.gd), offers and done
##   order       the outfitter's special order: a gear code ("" for none)
##   streak      climbs in a row without falling; best_streak the most
##   mirrors     your reflection beaten in a tournament
##   visits      stops made at a station
## (An old save's "bouts" and "challenges", from the old ladders, are left
## as they are and read by nothing.)
static func state(profile) -> Dictionary:
	if not (profile.renown is Dictionary):
		profile.renown = {}
	var r: Dictionary = profile.renown
	var defaults := {"points": 0, "deeds": [], "titles": [], "ready": [], "worn": "", "rank_seen": -1, "lessons": {}, "drills": {}, "best": {},
		"tiers": {}, "rounds": {}, "recipes": [], "contracts": {}, "order": "", "streak": 0, "best_streak": 0, "mirrors": 0, "visits": 0}
	for k in defaults:
		if not r.has(k) or typeof(r[k]) != typeof(defaults[k]):
			r[k] = defaults[k].duplicate() if defaults[k] is Dictionary or defaults[k] is Array else defaults[k]
	if int(r["rank_seen"]) < 0:
		r["rank_seen"] = rank_for(int(r["points"]))  # (an old save: its rank was already reached)
	return r


static func points(profile) -> int:
	return int(state(profile)["points"])


## Told of every gain (main.gd sets it): func(profile, out) where out is
## what earn returns, with "reason".
static var heard := Callable()


## THE HOOK: adds `amount` renown for `reason` (the words the board lists).
## A new rank and any titles the deed makes ready are noted too. Saves.
## Returns what it did: {"amount", "reason", "line" ("+6 renown: ..."),
## "rank_up" (a rank name or ""), "rank" (the new rank's index, or -1),
## "titles" (ids now ready at the Noble)}.
static func earn(profile, amount: int, reason: String) -> Dictionary:
	var r := state(profile)
	var before := rank(profile)
	amount = maxi(amount, 0)
	r["points"] = int(r["points"]) + amount
	if amount > 0 or reason != "":
		_deed(r, reason, amount)
	var out := {"amount": amount, "reason": reason, "line": gain_line(amount, reason), "rank_up": "", "rank": -1, "titles": []}
	var after := rank(profile)
	if after > before:
		out["rank_up"] = String(RANKS[after][1])
		out["rank"] = after
		_deed(r, TEXT["rank_up"] % RANKS[after][1], 0)
	out["titles"] = check_titles(profile)
	profile.save()
	if heard.is_valid() and (amount > 0 or out["rank_up"] != "" or not out["titles"].is_empty()):
		heard.call(profile, out)
	return out


## "+6 renown: won a duel with Bryn" ("" for nothing earned).
static func gain_line(amount: int, reason: String) -> String:
	if amount <= 0:
		return ""
	if reason == "":
		return TEXT["earned"] % amount
	return TEXT["gain"] % [amount, reason.left(1).to_lower() + reason.substr(1)]


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


# --- what ranks open ----------------------------------------------------------------------

## What rank `i` opens (RANK_OPENS), one line each: "the Open Bracket at
## the tournament", "a charm recipe: Keeper's Purse"...
static func opens(i: int) -> Array:
	var out: Array = []
	if i < 0 or i >= RANK_OPENS.size():
		return out
	for e in RANK_OPENS[i]:
		out.append(open_text(e))
	return out.filter(func(s): return String(s) != "")


## One RANK_OPENS entry in words.
static func open_text(e: Dictionary) -> String:
	if e.has("text"):
		return String(e["text"])
	match String(e.get("kind", "")):
		"lessons":
			return TEXT["open_lessons"]
		"bracket":
			var b: Dictionary = load("res://scripts/stations.gd").bracket(String(e.get("id", "")))
			return TEXT["open_bracket"] % String(b.get("name", e.get("id", "")))
		"titles":
			return TEXT["open_titles"]
		"contracts":
			var C = load("res://scripts/contracts.gd")
			var bits: Array = []
			for k in e.get("kinds", []):
				bits.append(TEXT["open_contracts_kind"] % String(C.KINDS.get(String(k), {}).get("label", k)))
			if int(e.get("n", 1)) > 1:
				bits.append(TEXT["open_contracts_n"] % int(e["n"]))
			return TEXT["and"].join(bits) if not bits.is_empty() else TEXT["open_contracts"]
		"recipe":
			var G = load("res://scripts/gear.gd")
			return TEXT["open_recipe"] % String(G.PIECES.get(String(e.get("id", "")), {}).get("name", e.get("id", "")))
		"refill":
			return TEXT["open_refill"] % int(round(float(e.get("cut", 0.0)) * 100.0))
	return ""


## Every RANK_OPENS entry the climber's rank has reached, of one kind.
static func opened(profile, kind: String) -> Array:
	var out: Array = []
	var at := rank(profile) if profile != null else 0
	for i in mini(at + 1, RANK_OPENS.size()):
		for e in RANK_OPENS[i]:
			if String(e.get("kind", "")) == kind:
				out.append(e)
	return out


## The rank that opens an entry of `kind` (with `id`, if given), or -1.
static func rank_opening(kind: String, id := "") -> int:
	for i in RANK_OPENS.size():
		for e in RANK_OPENS[i]:
			if String(e.get("kind", "")) == kind and (id == "" or String(e.get("id", "")) == id):
				return i
	return -1


## A rank reached that hasn't had its moment yet (a banner, the Entity's
## word): its index, or -1. `seen` marks it shown.
static func unseen_rank(profile, seen := false) -> int:
	var r := state(profile)
	var at := rank(profile)
	if at <= int(r["rank_seen"]):
		return -1
	if seen:
		r["rank_seen"] = at
		profile.save()
	return at


## The rank-up moment's words: [title, line] ("RENOWN: KNOWN", "Opens: ...").
static func rank_words(i: int) -> Array:
	var bits := opens(i)
	return [TEXT["rank_title"] % rank_name(i).to_upper(), TEXT["rank_opens"] % (", ".join(bits) if not bits.is_empty() else TEXT["open_nothing"])]


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

## The titles granted (ids, in TITLE_ORDER).
static func titles(profile) -> Array:
	var have: Array = state(profile)["titles"]
	return TITLE_ORDER.filter(func(id): return have.has(id))


## Is a title granted?
static func has_title(profile, id: String) -> bool:
	return state(profile)["titles"].has(id)


## Can the Noble grant it now: not yet granted, its rank reached and its deed done.
static func grantable(profile, id: String) -> bool:
	if not TITLES.has(id) or has_title(profile, id):
		return false
	return rank(profile) >= int(TITLES[id].get("rank", 0)) and deed_done(profile, TITLES[id])


## Titles the Noble can grant now (ids, in TITLE_ORDER).
static func on_offer(profile) -> Array:
	return TITLE_ORDER.filter(func(id): return grantable(profile, id))


## Notes titles newly ready at the Noble (their deed and rank done): each
## said once (a deed, and the returned ids for the line in play).
static func check_titles(profile) -> Array:
	var r := state(profile)
	var ready: Array = r["ready"]
	var fresh: Array = []
	for id in TITLE_ORDER:
		if ready.has(id) or not grantable(profile, id):
			continue
		ready.append(id)
		fresh.append(id)
		_deed(r, TEXT["title_up"] % title_name(id), 0)
	return fresh


## The Noble grants a title (noble.gd): it's yours, and worn at once if
## `and_wear`. True if granted.
static func grant(profile, id: String, and_wear := true) -> bool:
	if not grantable(profile, id):
		return false
	var r := state(profile)
	r["titles"].append(id)
	_deed(r, TEXT["granted"] % title_name(id), 0)
	if and_wear:
		r["worn"] = id
	profile.save()
	return true


## True once a title's deed is done.
static func deed_done(profile, t: Dictionary) -> bool:
	var r := state(profile)
	var n := int(t.get("n", 0))
	match String(t.get("rule", "")):
		"none", "":
			return true
		"renown":
			return int(r["points"]) >= n
		"visits":
			return int(r["visits"]) >= n
		"floors":
			return profile.count("floors") >= n
		"beasts":
			return profile.count("beasts") >= n
		"lessons":
			return load("res://scripts/stations.gd").lessons_done(profile)
		"drills":
			return r["drills"].values().filter(func(v): return int(v) > 0).size() >= n
		"golds":
			var golds: int = r["drills"].values().filter(func(v): return int(v) >= 3).size()
			if n > 0:
				return golds >= n
			var all: int = load("res://scripts/stations.gd").DRILL_ORDER.size()
			return all > 0 and golds >= all
		"tier":
			return bool(r["tiers"].get(str(n), false))
		"unfallen":
			return int(r["best_streak"]) >= n
		"contracts":
			return int(r["contracts"].get("done", 0)) >= n
		"mirror":
			return int(r["mirrors"]) >= n
		"rivals":
			return load("res://scripts/rivals.gd").count(profile, String(t.get("of", "met"))) >= maxi(n, 1)
	return false


static func title_name(id: String) -> String:
	return String(TITLES.get(id, {}).get("name", ""))


## The title worn, by name ("" for none).
static func worn_title(profile) -> String:
	var id := worn_id(profile)
	return title_name(id) if id != "" else ""


## The title worn, by id ("" for none, or one no longer in TITLES).
static func worn_id(profile) -> String:
	if profile == null:
		return ""
	var r := state(profile)
	var id := String(r["worn"])
	if id == "" or not r["titles"].has(id) or not TITLES.has(id):
		return ""
	return id


# --- old saves --------------------------------------------------------------------------

## The Boon Shrine's old prices: [crystal kind, price of the first level]
## (each level cost that times its number). The shrine is gone (its lasting
## upgrades became charm rewards for your rank: RANK_OPENS); an old save's
## boons give back every crystal paid for them.
static var OLD_BOONS := {
	"vigor": ["stone", 40], "deep_breath": ["iron", 45], "satchel": ["water", 60], "fleetfoot": ["air", 50],
	"whetstone": ["blade", 55], "haggler": ["fire", 70], "wide_belt": ["iron", 90], "keen_eye": ["air", 80],
}


## An old save's boons (renown "boons": id -> level): the crystals paid for
## them come back, a deed says so, and "refund" keeps the words for the
## Renown Board and the Entity to say once. Called as the save loads
## (profile.gd); nothing to do for a save without boons.
static func retire_boons(profile) -> void:
	if not (profile.renown is Dictionary):
		return
	profile.renown.erase("market")  # (the Pedlar's stall is gone too)
	if not profile.renown.has("boons"):
		return
	var boons = profile.renown["boons"]
	profile.renown.erase("boons")
	if not (boons is Dictionary):
		return
	var back := {}
	for id in boons:
		var lv := int(boons[id])
		if lv <= 0 or not OLD_BOONS.has(String(id)):
			continue
		var kind := String(OLD_BOONS[id][0])
		back[kind] = int(back.get(kind, 0)) + int(OLD_BOONS[id][1]) * lv * (lv + 1) / 2
	if back.is_empty():
		return
	var parts: Array = []
	for kind in back:
		profile.add_crystal(String(kind), float(back[kind]))
		parts.append("%d %s" % [int(back[kind]), load("res://scripts/essence.gd").display(String(kind))])
	var r := state(profile)
	var words: String = TEXT["refund"] % ", ".join(parts)
	_deed(r, words, 0)
	r["refund"] = words


## A stop at a station (station_page.gd): counted, and any title it readies.
static func on_visit(profile) -> Array:
	var r := state(profile)
	r["visits"] = int(r["visits"]) + 1
	var fresh := check_titles(profile)
	profile.save()
	return fresh


## Wears a title you've been granted ("" takes it off). True if done.
static func wear(profile, id: String) -> bool:
	var r := state(profile)
	if id != "" and not r["titles"].has(id):
		return false
	r["worn"] = id
	profile.save()
	return true
