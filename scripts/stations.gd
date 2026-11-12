extends RefCounted
## STATIONS: where the train stops between towers. From the engine's
## destination board (train_page.gd) the climber can depart for a tower or
## stop at a station instead; a station is a page beside the rail
## (station_page.gd, drawn by station_view.gd) with these stops:
##   gym         the training gym: DRILLS, each with a goal and a medal
##               (bronze, silver, gold), run in a small arena (arena.gd)
##   arena       the tournament arena: TIERS of bouts, waves of tower
##               monsters, champions and your own mirror image, with RULES;
##               an entry fee in crystals, renown and crystals for a win and
##               sometimes a relic
##   challenges  one-off events with a twist (CHALLENGES): bigger rewards,
##               paid out the first time you win each
##   board       the renown board: your renown, rank, recent deeds and the
##               titles you've earned (one can be worn: renown.gd)
##   shrine      the boon shrine: boons bought with crystals (boons.gd)
## Drills, tiers and challenges unlock as your renown rank grows.
##
## Every name, number and word is here (and in the Data editor). The names
## are plain placeholders for the owner to replace; more stations can be
## added to STATIONS (each lists the stops it has).

const Renown := preload("res://scripts/renown.gd")
const Boons := preload("res://scripts/boons.gd")
const Gear := preload("res://scripts/gear.gd")
const Essence := preload("res://scripts/essence.gd")
const Towers := preload("res://scripts/towers.gd")

## The stations, in the order the engine's board lists them.
static var STATIONS := [
	{"id": "first", "name": "First Station", "short": "Station",
		"sub": "A platform between the towers, with a gym, an arena and a shrine.",
		"blurb": "Train, fight in the tournament, take on challenges and spend your renown.",
		"stops": ["gym", "arena", "challenges", "board", "shrine"], "lamp": Color(1.0, 0.78, 0.45)},
]

## The stops a station can have: their names (a phone's short name), the
## line under the name on the rail, and the line under the page's title.
static var STOPS := {
	"gym": {"name": "Training Gym", "short": "Gym", "line": "Drills and medals", "sub": "Drills with a goal and a medal. First clears and golds earn renown."},
	"arena": {"name": "Tournament Arena", "short": "Arena", "line": "Bouts for renown", "sub": "Win bouts for renown and crystals. Losing costs only the entry fee."},
	"challenges": {"name": "Challenges", "short": "Challenge", "line": "Harder, with a twist", "sub": "One-off events with a twist. Each pays out the first time you win it."},
	"board": {"name": "Renown Board", "short": "Renown", "line": "Rank, deeds, titles", "sub": "What the climbers say about you, and the titles you can wear."},
	"shrine": {"name": "Boon Shrine", "short": "Shrine", "line": "Lasting boons", "sub": "Boons bought here go with you on every climb."},
}

## Medals, from none to gold: [name, colour].
static var MEDALS := [["No medal", Color(0.45, 0.41, 0.53)], ["Bronze", Color(0.8, 0.52, 0.3)], ["Silver", Color(0.82, 0.84, 0.9)], ["Gold", Color(1.0, 0.82, 0.36)]]

## The training gym's drills. Each:
##   kind     parry  parry as many blows as you can in `time` seconds
##            kills  fell `need` foes as fast as you can (within `time`)
##            dodge  last `time` seconds among archers, taking few hits
##            run    touch `posts` posts in order, as fast as you can
##            cast   hit as many of `dummies` dummies as you can with one cast
##   foes     the monsters in it (kept topped up as they fall)
##   medals   [bronze, silver, gold]: the score each needs (`lower`: at most)
##   rank     the renown rank it unlocks at
##   renown   renown the first bronze, silver and gold each earn
##   tower    whose look the room has
static var DRILLS := {
	"parry": {"name": "Parry the Glints", "goal": "Parry as many blows as you can in %d seconds. Press parry on the glint.", "kind": "parry",
		"time": 40, "foes": ["knight", "knight"], "weak": 0.4, "medals": [4, 7, 10], "lower": false, "rank": 0, "renown": [6, 4, 8], "tower": "wyvern"},
	"rush": {"name": "Five Down", "goal": "Fell %d foes as fast as you can.", "kind": "kills", "need": 5,
		"time": 40, "foes": ["slime", "slime", "bat"], "weak": 0.6, "medals": [32, 22, 15], "lower": true, "rank": 0, "renown": [6, 4, 8], "tower": "kraken"},
	"gauntlet": {"name": "Roll Gauntlet", "goal": "Last %d seconds among archers. Roll through their arrows: the fewer hits, the better.", "kind": "dodge",
		"time": 30, "foes": ["archer", "archer", "archer", "bat"], "weak": 0.5, "medals": [6, 3, 1], "lower": true, "rank": 1, "renown": [8, 5, 10], "tower": "gryphon"},
	"sprint": {"name": "Post to Post", "goal": "Touch the %d posts in order, as fast as you can.", "kind": "run", "posts": 6,
		"time": 45, "foes": [], "medals": [30, 21, 15], "lower": true, "rank": 1, "renown": [8, 5, 10], "tower": "manticore"},
	"pack": {"name": "Through the Pack", "goal": "Hit as many of the %d dummies as you can with one cast.", "kind": "cast", "dummies": 6,
		"time": 40, "foes": [], "medals": [2, 3, 5], "lower": false, "rank": 2, "renown": [10, 6, 12], "tower": "firebird"},
}
static var DRILL_ORDER := ["parry", "rush", "gauntlet", "sprint", "pack"]
## How a drill's score is written, by its kind.
static var SCORE_TEXT := {"parry": "%d parried", "kills": "%.1f s", "dodge": "%d hits", "run": "%.1f s", "cast": "%d at once"}

## The tournament: tiers of bouts, each tier a ladder (win a bout to open the
## next). A bout is waves of foes ("kind", "kind*" a champion, "mirror" your
## mirror image, "shadow:beast" a beast's shadow), with rules. Each tier:
##   rank      the renown rank it unlocks at
##   fee       the entry fee for each bout, in crystals of any kind
##   floor     how tough its foes are (as on that floor of a tower)
##   crystals  crystals of the tower's kind a win pays (a repeat win, half)
##   tower     whose monsters' look and essence it has
## Each bout: its id, name, waves, rules and the renown a first win earns (a
## repeat win, a fifth of it). The last bout of a tier wins the tier: its
## first win gives a relic (a named piece, into your stash); later wins
## sometimes (RELIC_CHANCE).
static var TIERS := [
	{"name": "Copper Ladder", "rank": 0, "fee": 5, "floor": 2, "crystals": 12, "tower": "kraken", "bouts": [
		{"id": "copper_1", "name": "Opening Bout", "waves": [["slime", "slime", "bat"], ["slime", "archer", "slime"]], "rules": [], "renown": 5},
		{"id": "copper_2", "name": "Dry Throat", "waves": [["archer", "archer", "knight"], ["slime", "slime", "slime", "lurker"]], "rules": ["no_heal"], "renown": 6},
		{"id": "copper_3", "name": "The Copper Champion", "waves": [["knight*"], ["slime", "slime", "archer"]], "rules": [], "renown": 8},
	]},
	{"name": "Iron Ladder", "rank": 2, "fee": 10, "floor": 5, "crystals": 22, "tower": "wyvern", "bouts": [
		{"id": "iron_1", "name": "Short of Breath", "waves": [["cinder", "cinder", "knight"], ["smith", "cinder", "cinder"]], "rules": ["half_stamina"], "renown": 8},
		{"id": "iron_2", "name": "Your Reflection", "waves": [["mirror"]], "rules": [], "renown": 10},
		{"id": "iron_3", "name": "Two Champions", "waves": [["smith*"], ["knight*", "cinder"]], "rules": ["no_heal"], "renown": 12},
	]},
	{"name": "Gilt Ladder", "rank": 4, "fee": 15, "floor": 8, "crystals": 35, "tower": "chimera", "bouts": [
		{"id": "gilt_1", "name": "The Fierce Pack", "waves": [["thornhound", "thornhound", "mongrel"], ["mongrel", "thornhound", "thornhound", "familiar"]], "rules": ["fierce"], "renown": 12},
		{"id": "gilt_2", "name": "Glass and Steel", "waves": [["mirror", "knight*"]], "rules": ["half_stamina"], "renown": 14},
		{"id": "gilt_3", "name": "The Beast's Shadow", "waves": [["shadow:chimera"]], "rules": ["no_heal", "fierce"], "renown": 18},
	]},
]
static var RELIC_CHANCE := 0.15
## A repeat win pays this share of a bout's renown and crystals.
static var REPEAT := {"renown": 0.2, "crystals": 0.5}

## Challenges: harder one-off events with a twist. Each: name, twist (what's
## different), waves and rules, an optional time limit, the rank it unlocks
## at, how tough its foes are, and what the first win pays (renown, crystals
## of its tower's kind, and a relic if `relic`).
static var CHALLENGES := {
	"one_hit": {"name": "One Hit", "twist": "Any hit fells you. Clear both waves.", "waves": [["slime", "slime", "archer"], ["bat", "bat", "slime", "archer"]],
		"rules": ["one_hit"], "rank": 1, "floor": 2, "renown": 25, "crystals": 30, "tower": "gryphon"},
	"silence": {"name": "Silenced", "twist": "Your marks are silent: no spells, no techniques. Weapons only.", "waves": [["knight", "archer", "slime"], ["knight", "knight", "bat"]],
		"rules": ["no_marks"], "rank": 2, "floor": 4, "renown": 30, "crystals": 35, "tower": "kraken"},
	"twins": {"name": "Two Reflections", "twist": "Two mirror images of you at once.", "waves": [["mirror", "mirror"]],
		"rules": [], "rank": 3, "floor": 5, "renown": 35, "crystals": 40, "tower": "gryphon"},
	"clock": {"name": "Against the Clock", "twist": "Three waves in 60 seconds, or you lose.", "waves": [["scorpling", "scorpling", "ram"], ["scorpling", "ram", "scorpling"], ["ram", "ram"]],
		"rules": [], "time": 60, "rank": 4, "floor": 6, "renown": 40, "crystals": 45, "tower": "manticore"},
	"shadow": {"name": "The Beast's Shadow", "twist": "A beast's shadow, no healing, and it hits harder.", "waves": [["shadow:manticore"]],
		"rules": ["no_heal", "fierce"], "rank": 5, "floor": 8, "renown": 50, "crystals": 60, "relic": true, "tower": "manticore"},
}
static var CHALLENGE_ORDER := ["one_hit", "silence", "twins", "clock", "shadow"]

## The rules a bout or challenge can have, in words, and their numbers.
static var RULES := {
	"no_heal": "No healing: nothing mends you",
	"half_stamina": "Stamina halved",
	"fierce": "Fierce foes: they hit harder and last longer",
	"one_hit": "One hit fells you",
	"no_marks": "Your marks are silent",
}
static var RULE_FX := {"half_stamina": 0.5, "fierce_dmg": 1.5, "fierce_hp": 1.3}

static var TEXT := {
	"depart_title": "STATIONS",
	"depart_sub": "Stop between towers: train, fight and spend your renown.",
	"to_towers": "Towers",
	"to_stations": "Stations",
	"lever_for": "for the %s",
	"station_tag": "A stop between towers",
	"safe": "Nothing you carry is at risk at a station.",
	"leave": "Back to the train",
	"leave_short": "Train",
	"arrive": "The train pulls into %s.",
	"locked": "Unlocks at the rank of %s",
	"locked_short": "Rank: %s",
	"best": "Your best: %s",
	"never": "Not tried yet",
	"medal_needs": "%s: %s",
	"begin": "Begin the drill",
	"enter": "Enter the bout",
	"take": "Take the challenge",
	"fee": "Entry fee",
	"fee_note": "Paid in crystals of any kind, the biggest first. Losing costs nothing more.",
	"free": "No fee",
	"rewards": "A win pays",
	"rewards_repeat": "A repeat win pays",
	"renown": "+%d renown",
	"crystals": "%d %s",
	"relic": "a relic: a named piece",
	"relic_maybe": "sometimes a relic",
	"rules": "Rules",
	"no_rules": "No special rules",
	"foes": "Foes",
	"wave": "Wave %d: %s",
	"mirror": "your mirror image",
	"champion": "%s champion",
	"shadow": "the shadow of %s",
	"time": "%d seconds",
	"wins": "Won %d times",
	"wins_once": "Won once",
	"earned": "Earned",
	"drill_rewards": "Still to earn",
	"won": "Won",
	"won_once": "Won: its reward is paid. You can try it again for nothing.",
	"ladder_next": "Win the bout before it to open this one.",
	"medals": "Medals",
	"result_medal": "%s  ·  %s",
	"result_none": "No medal  ·  %s",
	"result_win": "You win %s",
	"result_loss": "You lose %s",
	"result_fell": "You fall: the bout is lost",
	"result_time": "Time is up",
	"result_quit": "You give up",
	"relic_won": "A relic for your stash: %s",
	"relic_full": "Your stash is full: the relic becomes %s",
	"paid": "+%s",
	"fee_paid": "Entry fee paid: %s",
	"cant": "Can't: %s",
	"rank_now": "Rank: %s",
	"deeds": "Recent deeds",
	"no_deeds": "Nothing yet. Climb, train and fight: the climbers will talk.",
	"titles": "Titles",
	"title_worn": "Worn",
	"wear": "Wear this title",
	"unwear": "Take it off",
	"worn_now": "Now wearing: %s",
	"unworn_now": "No title worn",
	"title_locked": "Not earned yet",
	"title_shows": "A worn title shows under your name on the rail and in your book.",
	"ranks": "Ranks",
	"deed_drill": "%s at %s",
	"deed_bout": "Won %s",
	"deed_tier": "Won the %s",
	"deed_challenge": "Won the challenge %s",
	"shrine_note": "Boons are bought with crystals and go with you on every climb from now on.",
	# In the arena (arena.gd)
	"hud_time": "%d s",
	"hud_wave": "Wave %d of %d",
	"hud_parry": "Parried %d",
	"hud_kills": "Felled %d of %d",
	"hud_hits": "Hits %d",
	"hud_post": "Post %d of %d",
	"hud_cast": "Best cast %d",
	"give_up": "Give up, back to the station",
	"paused": "At the station",
	"pause_note": "Nothing you carry is at risk here. Giving up keeps no reward.",
	"go": "Go!",
	"start_drill": "Training Gym",
	"start_bout": "Tournament",
	"start_challenge": "Challenge",
}


# --- stations and stops -------------------------------------------------------------

static func station(id: String) -> Dictionary:
	for s in STATIONS:
		if String(s["id"]) == id:
			return s
	return STATIONS[0] if not STATIONS.is_empty() else {}


static func station_ids() -> Array:
	return STATIONS.map(func(s): return String(s["id"]))


static func stops(id: String) -> Array:
	return station(id).get("stops", [])


static func stop_name(stop: String, short := false) -> String:
	var s: Dictionary = STOPS.get(stop, {})
	return String(s.get("short" if short else "name", stop.capitalize()))


# --- drills ---------------------------------------------------------------------------

static func drill_unlocked(profile, id: String) -> bool:
	return DRILLS.has(id) and Renown.rank(profile) >= int(DRILLS[id].get("rank", 0))


## A drill's goal in words, its numbers filled in.
static func drill_goal(id: String) -> String:
	var d: Dictionary = DRILLS[id]
	var goal := String(d["goal"])
	if not goal.contains("%"):
		return goal
	match String(d["kind"]):
		"kills":
			return goal % int(d.get("need", 5))
		"run":
			return goal % int(d.get("posts", 6))
		"cast":
			return goal % int(d.get("dummies", 6))
	return goal % int(d.get("time", 30))


## The medal a score earns in a drill: 0 none, 1 bronze, 2 silver, 3 gold.
## A score of -1 is a drill not finished (a fall, time up before the goal).
static func medal_for(id: String, score: float) -> int:
	if not DRILLS.has(id) or score < 0.0:
		return 0
	var d: Dictionary = DRILLS[id]
	var lower: bool = d.get("lower", false)
	var m := 0
	var marks: Array = d["medals"]
	for i in marks.size():
		if (score <= float(marks[i]) + 0.0001) if lower else (score >= float(marks[i]) - 0.0001):
			m = i + 1
	return m


static func score_text(id: String, score: float) -> String:
	var kind := String(DRILLS.get(id, {}).get("kind", "parry"))
	var fmt := String(SCORE_TEXT.get(kind, "%d"))
	return fmt % (int(score) if fmt.contains("%d") else score)


static func medal_name(m: int) -> String:
	return String(MEDALS[clampi(m, 0, MEDALS.size() - 1)][0])


static func medal_color(m: int) -> Color:
	return MEDALS[clampi(m, 0, MEDALS.size() - 1)][1]


## Is score `a` better than score `b` in this drill?
static func better(id: String, a: float, b: float) -> bool:
	return a < b if DRILLS[id].get("lower", false) else a > b


# --- the tournament ---------------------------------------------------------------------

static func tier_unlocked(profile, t: int) -> bool:
	return t >= 0 and t < TIERS.size() and Renown.rank(profile) >= int(TIERS[t].get("rank", 0))


## [tier index, bout index] of a bout id, or [-1, -1].
static func find_bout(id: String) -> Array:
	for t in TIERS.size():
		var bouts: Array = TIERS[t]["bouts"]
		for b in bouts.size():
			if String(bouts[b]["id"]) == id:
				return [t, b]
	return [-1, -1]


static func bout(id: String) -> Dictionary:
	var at := find_bout(id)
	return {} if at[0] < 0 else TIERS[at[0]]["bouts"][at[1]]


static func bout_wins(profile, id: String) -> int:
	return int(Renown.state(profile)["bouts"].get(id, 0))


## Open: its tier is unlocked and the bout before it (in the ladder) won.
static func bout_open(profile, id: String) -> bool:
	var at := find_bout(id)
	if at[0] < 0 or not tier_unlocked(profile, at[0]):
		return false
	if at[1] == 0:
		return true
	return bout_wins(profile, String(TIERS[at[0]]["bouts"][at[1] - 1]["id"])) > 0


# --- challenges -------------------------------------------------------------------------

static func challenge_unlocked(profile, id: String) -> bool:
	return CHALLENGES.has(id) and Renown.rank(profile) >= int(CHALLENGES[id].get("rank", 0))


static func challenge_won(profile, id: String) -> bool:
	return bool(Renown.state(profile)["challenges"].get(id, false))


# --- an event: what's fought, and its result -----------------------------------------------

## What an event is, for arena.gd: {"type", "id", "name", "waves", "rules",
## "time", "floor", "tower", "station", "stop"} (a drill adds its own keys).
static func event(type: String, id: String, station_id := "") -> Dictionary:
	var ev := {"type": type, "id": id, "station": station_id, "rules": [], "waves": [], "time": 0, "floor": 1}
	match type:
		"drill":
			var d: Dictionary = DRILLS.get(id, {})
			ev.merge(d, true)
			ev["type"] = "drill"
			ev["stop"] = "gym"
		"bout":
			var at := find_bout(id)
			if at[0] >= 0:
				var t: Dictionary = TIERS[at[0]]
				var b: Dictionary = t["bouts"][at[1]]
				ev.merge(b, true)
				ev["floor"] = int(t.get("floor", 1))
				ev["tower"] = String(t.get("tower", "kraken"))
				ev["tier"] = at[0]
				ev["last"] = at[1] == (t["bouts"] as Array).size() - 1
			ev["stop"] = "arena"
		"challenge":
			ev.merge(CHALLENGES.get(id, {}), true)
			ev["stop"] = "challenges"
	ev["type"] = type
	ev["id"] = id
	return ev


## The entry fee for an event (crystals of any kind; 0 for none).
static func fee(type: String, id: String) -> int:
	if type != "bout":
		return 0
	var at := find_bout(id)
	return 0 if at[0] < 0 else int(TIERS[at[0]].get("fee", 0))


## Why an event can't be begun ("" if it can): locked, or the fee unpaid.
static func why_not(profile, type: String, id: String) -> String:
	match type:
		"drill":
			if not drill_unlocked(profile, id):
				return TEXT["locked"] % Renown.rank_name(int(DRILLS.get(id, {}).get("rank", 0)))
		"bout":
			var at := find_bout(id)
			if at[0] < 0:
				return "?"
			if not tier_unlocked(profile, at[0]):
				return TEXT["locked"] % Renown.rank_name(int(TIERS[at[0]]["rank"]))
			if not bout_open(profile, id):
				return TEXT["ladder_next"]
			var f := fee(type, id)
			if f > 0 and int(profile.crystals_held()) < f:
				return "needs %d more essence, of any kind" % (f - int(profile.crystals_held()))
		"challenge":
			if not challenge_unlocked(profile, id):
				return TEXT["locked"] % Renown.rank_name(int(CHALLENGES.get(id, {}).get("rank", 0)))
	return ""


## Applies an event's result to the climber: medals, wins, renown, crystals
## and relics. `res`: {"type", "id", "won" (bout or challenge), "score"
## (drill; -1 not finished), "mirrors" (mirror images beaten)}. Returns the
## lines to show ({"lines": [...], "medal", "renown"}). Saves.
static func apply_result(profile, res: Dictionary) -> Dictionary:
	var r := Renown.state(profile)
	var type := String(res.get("type", ""))
	var id := String(res.get("id", ""))
	var out := {"lines": [], "medal": 0, "renown": 0, "won": bool(res.get("won", false))}
	var lines: Array = out["lines"]
	r["mirrors"] = int(r["mirrors"]) + int(res.get("mirrors", 0))
	var gain := 0
	var why := ""
	match type:
		"drill":
			var d: Dictionary = DRILLS.get(id, {})
			var score := float(res.get("score", -1.0))
			var m := medal_for(id, score)
			out["medal"] = m
			var was := int(r["drills"].get(id, 0))
			if score >= 0.0 and (not r["best"].has(id) or better(id, score, float(r["best"][id]))):
				r["best"][id] = score
			if m > was:
				var rn: Array = d.get("renown", [0, 0, 0])
				for i in range(was, m):
					gain += int(rn[i]) if i < rn.size() else 0
				r["drills"][id] = m
			lines.append(TEXT["result_medal"] % [medal_name(m), score_text(id, score)] if m > 0 else TEXT["result_none"] % (score_text(id, score) if score >= 0.0 else String(res.get("why", TEXT["result_time"]))))
			why = TEXT["deed_drill"] % [medal_name(m), d.get("name", id)] if m > was else ""
		"bout":
			var at := find_bout(id)
			if at[0] < 0:
				return out
			var t: Dictionary = TIERS[at[0]]
			var b: Dictionary = t["bouts"][at[1]]
			if not out["won"]:
				lines.append(String(res.get("why", TEXT["result_loss"] % b["name"])))
			else:
				var first := bout_wins(profile, id) == 0
				r["bouts"][id] = bout_wins(profile, id) + 1
				var k := 1.0 if first else float(REPEAT["renown"])
				gain = maxi(1, int(round(float(b.get("renown", 0)) * k)))
				var kind := String(Towers.TOWERS.get(String(t.get("tower", "kraken")), {}).get("essence", "stone"))
				var cr := maxi(1, int(round(float(t.get("crystals", 0)) * (1.0 if first else float(REPEAT["crystals"])))))
				profile.add_crystal(kind, float(cr))
				lines.append(TEXT["result_win"] % b["name"])
				lines.append(TEXT["paid"] % (TEXT["crystals"] % [cr, Essence.display(kind)]))
				why = TEXT["deed_bout"] % b["name"]
				if at[1] == (t["bouts"] as Array).size() - 1:
					var tier_first := not bool(r["tiers"].get(str(at[0] + 1), false))
					r["tiers"][str(at[0] + 1)] = true
					if tier_first:
						why = TEXT["deed_tier"] % t["name"]
					if tier_first or randf() < RELIC_CHANCE:
						lines.append(give_relic(profile, kind))
		"challenge":
			var c: Dictionary = CHALLENGES.get(id, {})
			if not out["won"]:
				lines.append(String(res.get("why", TEXT["result_loss"] % c.get("name", id))))
			else:
				lines.append(TEXT["result_win"] % c.get("name", id))
				if not challenge_won(profile, id):
					r["challenges"][id] = true
					gain = int(c.get("renown", 0))
					var kind := String(Towers.TOWERS.get(String(c.get("tower", "kraken")), {}).get("essence", "stone"))
					var cr := int(c.get("crystals", 0))
					if cr > 0:
						profile.add_crystal(kind, float(cr))
						lines.append(TEXT["paid"] % (TEXT["crystals"] % [cr, Essence.display(kind)]))
					if c.get("relic", false):
						lines.append(give_relic(profile, kind))
					why = TEXT["deed_challenge"] % c.get("name", id)
	if gain > 0:
		lines.append(TEXT["renown"] % gain)
	var got := Renown.earn(profile, gain, why)
	out["renown"] = gain
	if got["rank_up"] != "":
		lines.append(Renown.TEXT["rank_up"] % got["rank_up"])
	for tid in got["titles"]:
		lines.append(Renown.TEXT["title_up"] % Renown.title_name(tid))
	profile.save()
	return out


## A relic for the stash: a named piece you don't have yet (any, once you
## have them all). A full stash turns it into crystals. Returns the line.
static func give_relic(profile, kind: String) -> String:
	var have := {}
	for g in profile.chest + profile.pack:
		have[Gear.named_id(Gear.rec(g))] = true
	var pool: Array = Gear.NAMED.keys().filter(func(n): return not have.has(n))
	if pool.is_empty():
		pool = Gear.NAMED.keys()
	if pool.is_empty():
		return ""
	var rec: Dictionary = Gear.make_named(String(pool[randi() % pool.size()]))
	if profile.chest.size() >= int(load("res://scripts/train.gd").CHEST_SIZE):
		var worth := 40
		profile.add_crystal(kind, float(worth))
		return TEXT["relic_full"] % (TEXT["crystals"] % [worth, Essence.display(kind)])
	profile.chest.append(rec)
	return TEXT["relic_won"] % Gear.display(rec)


## A bout's or challenge's foes, wave by wave, in words.
static func wave_lines(ev: Dictionary) -> Array:
	var out: Array = []
	var waves: Array = ev.get("waves", [])
	for i in waves.size():
		var names: Array = []
		for k in waves[i]:
			names.append(foe_name(String(k)))
		out.append(TEXT["wave"] % [i + 1, ", ".join(names)])
	return out


static func foe_name(k: String) -> String:
	if k == "mirror":
		return TEXT["mirror"]
	if k.begins_with("shadow:"):
		var beast := k.substr(7)
		return TEXT["shadow"] % String(Towers.TOWERS.get(beast, {}).get("beast", beast))
	if k.ends_with("*"):
		return TEXT["champion"] % k.trim_suffix("*").capitalize()
	return k.capitalize()


## "Won once", "Won 3 times".
static func wins_text(n: int) -> String:
	return TEXT["wins_once"] if n == 1 else TEXT["wins"] % n


static func rule_lines(ev: Dictionary) -> Array:
	var out: Array = []
	for rl in ev.get("rules", []):
		out.append(String(RULES.get(String(rl), String(rl))))
	if int(ev.get("time", 0)) > 0 and ev.get("type", "") == "challenge":
		out.append(TEXT["time"] % int(ev["time"]))
	return out
