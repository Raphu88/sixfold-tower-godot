extends RefCounted
## STATIONS: six cities, one near each tower, on a loop the train rides
## (travel.gd: the fare, the lock, the climber's home and current station).
## The engine's map (engine_page.gd) has "Step off" for the station you're
## at; a station is a page beside the rail (station_page.gd, drawn by
## station_view.gd in the station's own colours) with these stops:
##   gym     TRAINING: basic training hands on, ONE SESSION that flows step
##           to step through every way to move, attack and parry, with the
##           Entity guiding (tutorial.gd; required for the Noble's Grace:
##           training.gd); advanced and
##           mark training (training.gd); and MEDAL DRILLS (DRILLS: a goal, a
##           medal and a small fee)
##   arena   the TOURNAMENT: a new climber's first tournament (training.gd),
##           then BRACKETS of three rounds run by the travelling Tournament
##           Manager (tournaments.gd: only where they are, the location's
##           creatures first, then climbers: rival.gd's, who yield instead of
##           dying), rising difficulty, a fee, and renown, crystals, items and
##           a title for winning. Nobody dies here.
##   noble   THE NOBLE (noble.gd): grants titles by renown, and gives
##           contracts for the towers (contracts.gd)
##   board   the RENOWN BOARD: your rank, how far to the next and what it
##           opens, every rank and what it opens, your recent deeds and the
##           climbers you've met (rivals.gd)
## Lessons, drills and brackets are fought in a small arena (arena.gd).
##
## Every name, number and word is here (and in the Data editor). The names
## are plain placeholders for the owner to replace; more stations can be
## added to STATIONS (each lists the stops it has).

const Renown := preload("res://scripts/renown.gd")
const Gear := preload("res://scripts/gear.gd")
const Essence := preload("res://scripts/essence.gd")
const Towers := preload("res://scripts/towers.gd")
const Titles := preload("res://scripts/titles.gd")
const Training := preload("res://scripts/training.gd")
const Tutorial := preload("res://scripts/tutorial.gd")

## The stations: six, each in a major city near its tower (travel.gd: they
## sit on a loop in tower order, and the train rides between them). Each has
## the same stops, its own Noble ("noble": a name), and its own colours so
## you can tell them apart: "lamp" (its lamps' light), "banner" (its
## pennants and crest), "trim" (its canopy and columns) and "sky" (the glow
## on its horizon). "tower" is the tower it's near. The city and Noble names
## are the owner's (the lore doc's "Names"), easy to change here.
static var STATIONS := [
	{"id": "gryphon", "tower": "gryphon", "name": "Windhollow", "short": "Windhollow", "noble": "Aster Vale",
		"sub": "A city on the heights near the Gryphon's Tower.",
		"blurb": "Learn the game hands on, fight in the tournament, and see the Noble for titles and contracts.",
		"stops": ["gym", "arena", "noble", "board"], "lamp": Color(0.86, 0.9, 1.0), "banner": Color(0.42, 0.56, 0.86), "trim": Color(0.2, 0.24, 0.32), "sky": Color(0.5, 0.58, 0.82)},
	{"id": "kraken", "tower": "kraken", "name": "Tidemoor", "short": "Tidemoor", "noble": "Maren Ostrow",
		"sub": "A harbour city near the Kraken's Tower.",
		"blurb": "Learn the game hands on, fight in the tournament, and see the Noble for titles and contracts.",
		"stops": ["gym", "arena", "noble", "board"], "lamp": Color(0.66, 1.0, 0.9), "banner": Color(0.16, 0.56, 0.6), "trim": Color(0.12, 0.24, 0.26), "sky": Color(0.3, 0.62, 0.66)},
	{"id": "wyvern", "tower": "wyvern", "name": "Forgehaven", "short": "Forgehaven", "noble": "Brannoc Hale",
		"sub": "A forge city near the Wyvern's Tower.",
		"blurb": "Learn the game hands on, fight in the tournament, and see the Noble for titles and contracts.",
		"stops": ["gym", "arena", "noble", "board"], "lamp": Color(1.0, 0.62, 0.36), "banner": Color(0.62, 0.2, 0.14), "trim": Color(0.24, 0.16, 0.14), "sky": Color(0.86, 0.4, 0.24)},
	{"id": "manticore", "tower": "manticore", "name": "Dunewatch", "short": "Dunewatch", "noble": "Sefa Darrow",
		"sub": "A desert city near the Manticore's Tower.",
		"blurb": "Learn the game hands on, fight in the tournament, and see the Noble for titles and contracts.",
		"stops": ["gym", "arena", "noble", "board"], "lamp": Color(1.0, 0.84, 0.52), "banner": Color(0.76, 0.54, 0.2), "trim": Color(0.28, 0.22, 0.14), "sky": Color(0.92, 0.66, 0.36)},
	{"id": "firebird", "tower": "firebird", "name": "Cinderreach", "short": "Cinderreach", "noble": "Ilse Cindra",
		"sub": "A city on the cliffs near the Firebird's Tower.",
		"blurb": "Learn the game hands on, fight in the tournament, and see the Noble for titles and contracts.",
		"stops": ["gym", "arena", "noble", "board"], "lamp": Color(1.0, 0.7, 0.34), "banner": Color(0.8, 0.3, 0.12), "trim": Color(0.26, 0.14, 0.12), "sky": Color(0.96, 0.46, 0.2)},
	{"id": "chimera", "tower": "chimera", "name": "Thornmere", "short": "Thornmere", "noble": "Corvin Thorne",
		"sub": "A city at the edge of the Thornwild, near the Chimera's Tower.",
		"blurb": "Learn the game hands on, fight in the tournament, and see the Noble for titles and contracts.",
		"stops": ["gym", "arena", "noble", "board"], "lamp": Color(0.9, 1.0, 0.62), "banner": Color(0.34, 0.54, 0.2), "trim": Color(0.16, 0.22, 0.14), "sky": Color(0.54, 0.72, 0.34)},
]

## The stops a station can have: their names (a phone's short name), the
## line under the name on the rail, and the line under the page's title.
static var STOPS := {
	"gym": {"name": "Training", "short": "Training", "line": "Learn the game, hands on", "sub": "Basic, advanced and mark training with the Entity, and medal drills. Nothing here can fell you."},
	"arena": {"name": "Tournament", "short": "Tourney", "line": "Brackets against climbers", "sub": "Your first tournament, then the Tournament Manager's brackets. Nobody dies: the loser yields."},
	"noble": {"name": "The Noble", "short": "Noble", "line": "Titles and contracts", "sub": "Titles granted by renown, and contracts for the towers."},
	"board": {"name": "Renown Board", "short": "Renown", "line": "Rank, next rank, deeds", "sub": "Your rank, what the next one opens, and what the climbers say about you."},
}

## BASIC TRAINING's six parts. Since basic training became ONE SESSION
## (tutorial.gd: the gym's only basic tile, every step in one sitting), these
## are the parts it covers, kept as a record: the session done marks every
## one done (an old save that did them separately counts as done), the
## finished set pays LESSON_REWARD once and readies the Trainee's title. The
## arena can still run one as a "lesson" event. Each:
##   name, goal  its title and what to do (%d: its number)
##   say         the Entity's word as it begins ({move}, {roll}... become
##               your keys or buttons)
##   kind        run     touch `posts` posts in order
##               roll    roll `need` times
##               jump    jump `need` times
##               strike  land `need` blows on the dummies with your weapon
##               shoot   land `need` shots on the far dummies with your bow
##               parry   parry `need` blows (soft `foes` swing at you)
##               (advanced and mark training add belt, cast, cure, wall,
##               ward, kills, cast_foes and spar: training.gd)
##   essence     the kind of essence it gives when done (training.gd USUAL
##               "lesson", at a quarter, into the body)
##   time        seconds before it ends (not done: try again)
##   tips        the Entity's first-time tips it covers (marked told when done)
## Finishing every one (or skipping it, after the Grace) pays LESSON_REWARD once.
static var LESSONS := {
	"move": {"name": "Moving", "goal": "Walk to each of the %d posts in turn. The lit one is next.", "kind": "run", "posts": 3, "time": 60, "essence": "air",
		"say": "Move with {move}. Touch the posts in order: the lit one is next. Take your time.", "tips": ["move"]},
	"roll": {"name": "Rolling", "goal": "Roll %d times. Arrows pass through you while you roll.", "kind": "roll", "need": 3, "time": 45, "foes": ["archer"], "weak": 0.15, "essence": "air",
		"say": "{roll} rolls you a short way, and nothing touches you while you roll. Roll three times; let the archer try.", "tips": []},
	"jump": {"name": "Jumping", "goal": "Jump %d times. A jump carries you over low hazards and gaps.", "kind": "jump", "need": 3, "time": 45, "essence": "air",
		"say": "{jump} jumps. While you're in the air, spikes, snares and narrow gaps pass under you. Jump three times.", "tips": []},
	"strike": {"name": "Striking", "goal": "Land %d blows on the dummies. Keep pressing: the last blow of a combo hits hardest.", "kind": "strike", "need": 4, "dummies": 2, "time": 60, "essence": "blade",
		"say": "{attack} strikes. Press it again as a blow lands and you chain a combo; its last blow, the finisher, hits hardest and breaks guards.", "tips": []},
	"shoot": {"name": "Shooting", "goal": "Land %d shots on the far dummies with your bow.", "kind": "shoot", "need": 2, "dummies": 2, "time": 75, "essence": "blade",
		"say": "Switch to your bow with {weapon}. Hold {attack} to draw, aim, and let go to loose. A full draw flies furthest and hits hardest.", "tips": []},
	"parry": {"name": "Parrying on the glint", "goal": "Parry %d blows: press parry as the blow glints.", "kind": "parry", "need": 2, "time": 60, "foes": ["knight"], "weak": 0.2, "essence": "iron",
		"say": "Every blow glints just before it lands. Press {parry} then: no damage, and the attacker staggers.", "tips": ["glint"]},
}
static var LESSON_ORDER := ["move", "roll", "jump", "strike", "shoot", "parry"]
## Renown for finishing the basics, once.
static var LESSON_REWARD := 10

## Medals, from none to gold: [name, colour].
static var MEDALS := [["No medal", Color(0.45, 0.41, 0.53)], ["Bronze", Color(0.8, 0.52, 0.3)], ["Silver", Color(0.82, 0.84, 0.9)], ["Gold", Color(1.0, 0.82, 0.36)]]

## The medal drills. Each:
##   kind     parry  parry as many blows as you can in `time` seconds
##            kills  fell `need` foes as fast as you can (within `time`)
##            dodge  last `time` seconds among archers, taking few hits
##            run    touch `posts` posts in order, as fast as you can
##            cast   hit as many of `dummies` dummies as you can with one cast
##   foes     the monsters in it (kept topped up as they fall; "mirror" your
##            reflection, "kind*" a champion)
##   medals   [bronze, silver, gold]: the score each needs (`lower`: at most)
##   rank     the renown rank it opens at
##   extra    an extra drill: only a worn title's training benefit opens it
##   fee      crystals of any kind to try it (a worn title may cut it)
##   renown   renown the first bronze, silver and gold each earn
##   tower    whose look the room has
static var DRILLS := {
	"parry": {"name": "Parry the Glints", "goal": "Parry as many blows as you can in %d seconds. Press parry on the glint.", "kind": "parry",
		"time": 40, "foes": ["knight", "knight"], "weak": 0.4, "medals": [4, 7, 10], "lower": false, "rank": 0, "fee": 2, "renown": [6, 4, 8], "tower": "wyvern"},
	"rush": {"name": "Five Down", "goal": "Fell %d foes as fast as you can.", "kind": "kills", "need": 5,
		"time": 40, "foes": ["slime", "slime", "bat"], "weak": 0.6, "medals": [32, 22, 15], "lower": true, "rank": 0, "fee": 2, "renown": [6, 4, 8], "tower": "kraken"},
	"gauntlet": {"name": "Roll Gauntlet", "goal": "Last %d seconds among archers. Roll through their arrows: the fewer hits, the better.", "kind": "dodge",
		"time": 30, "foes": ["archer", "archer", "archer", "bat"], "weak": 0.5, "medals": [6, 3, 1], "lower": true, "rank": 1, "fee": 3, "renown": [8, 5, 10], "tower": "gryphon"},
	"sprint": {"name": "Post to Post", "goal": "Touch the %d posts in order, as fast as you can.", "kind": "run", "posts": 6,
		"time": 45, "foes": [], "medals": [30, 21, 15], "lower": true, "rank": 1, "fee": 3, "renown": [8, 5, 10], "tower": "manticore"},
	"pack": {"name": "Through the Pack", "goal": "Hit as many of the %d dummies as you can with one cast.", "kind": "cast", "dummies": 6,
		"time": 40, "foes": [], "medals": [2, 3, 5], "lower": false, "rank": 2, "fee": 4, "renown": [10, 6, 12], "tower": "firebird"},
	"glass": {"name": "Glass Sparring", "goal": "Parry your own reflection's blows: as many as you can in %d seconds.", "kind": "parry",
		"time": 40, "foes": ["mirror"], "weak": 0.3, "medals": [3, 5, 8], "lower": false, "rank": 0, "extra": true, "fee": 4, "renown": [8, 5, 10], "tower": "gryphon"},
	"pace": {"name": "Champion's Pace", "goal": "Fell %d champions as fast as you can.", "kind": "kills", "need": 2,
		"time": 70, "foes": ["knight*"], "weak": 0.5, "medals": [55, 40, 28], "lower": true, "rank": 0, "extra": true, "fee": 4, "renown": [8, 5, 10], "tower": "chimera"},
	# Opened by the higher ranks, one at each of the five between the old ones
	# (renown.gd RANK_OPENS "drill").
	"bullseye": {"name": "Bullseye", "goal": "Land %d shots on the far dummies with your bow, as fast as you can.", "kind": "shoot", "need": 6, "dummies": 3,
		"time": 50, "foes": [], "medals": [30, 21, 14], "lower": true, "rank": 3, "fee": 3, "renown": [8, 5, 10], "tower": "firebird"},
	"shell": {"name": "Shell Breaker", "goal": "Fell %d shellbacks as fast as you can. Their shells turn blows from the front: get behind them.", "kind": "kills", "need": 3,
		"time": 75, "foes": ["shellback", "shellback"], "weak": 0.5, "medals": [55, 40, 28], "lower": true, "rank": 5, "fee": 4, "renown": [10, 6, 12], "tower": "kraken"},
	"perfect": {"name": "Perfect Timing", "goal": "Make as many perfect parries as you can in %d seconds: a beat after the glint.", "kind": "parry", "perfect": true,
		"time": 45, "foes": ["knight", "knight"], "weak": 0.4, "medals": [2, 4, 6], "lower": false, "rank": 7, "fee": 4, "renown": [10, 6, 12], "tower": "wyvern"},
	"hunted": {"name": "Hunted Run", "goal": "Touch the %d posts in order, as fast as you can, while they hunt you.", "kind": "run", "posts": 6,
		"time": 60, "foes": ["knight", "bat"], "weak": 0.4, "medals": [36, 27, 20], "lower": true, "rank": 9, "fee": 5, "renown": [12, 7, 14], "tower": "manticore"},
	"dance": {"name": "The Long Dance", "goal": "Parry as many blows as you can in %d seconds, from three kinds of foe, each with its own rhythm.", "kind": "parry",
		"time": 60, "foes": ["knight", "smith", "ram"], "weak": 0.35, "medals": [8, 13, 18], "lower": false, "rank": 11, "fee": 6, "renown": [12, 8, 15], "tower": "chimera"},
}
## Twelve drills (by sixes): five for the first ranks and the two extras, then
## the five the higher ranks open.
static var DRILL_ORDER := ["parry", "rush", "gauntlet", "sprint", "pack", "glass", "pace", "bullseye", "shell", "perfect", "hunted", "dance"]
## How a drill's score is written, by its kind.
static var SCORE_TEXT := {"parry": "%d parried", "kills": "%.1f s", "dodge": "%d hits", "run": "%.1f s", "cast": "%d at once", "shoot": "%.1f s"}

## THE TOURNAMENT: brackets of three rounds against other climbers. Each:
##   rank       the renown rank it opens at (a worn title may open it sooner)
##   fee        the entry fee, in crystals of any kind (the biggest first)
##   floor      how tough the climbers are (as on that floor of a tower)
##   tower      whose essence the prize crystals are, and the room's look
##   rounds     each a climber: "marks" (how many), "step" (their best
##              mark's step), "hp" (their health, times); {"mirror": true}
##              is your own reflection
##   round_renown  renown for each round won past your best in it
##   renown, crystals  the prize for winning it (a repeat win: REPEAT)
##   relic      the first win also gives a relic (a named piece)
## Winning bracket n (1 the first) is a title's deed (renown.gd "tier").
static var BRACKETS := [
	{"id": "novice", "name": "Novice Bracket", "rank": 0, "fee": 5, "floor": 2, "tower": "kraken", "round_renown": 2, "renown": 14, "crystals": 18,
		"rounds": [{"marks": 1, "step": 1, "hp": 0.75}, {"marks": 1, "step": 1, "hp": 0.9}, {"marks": 1, "step": 2, "hp": 1.0}]},
	{"id": "open", "name": "Open Bracket", "rank": 2, "fee": 10, "floor": 5, "tower": "wyvern", "round_renown": 3, "renown": 24, "crystals": 30,
		"rounds": [{"marks": 1, "step": 2, "hp": 1.0}, {"marks": 2, "step": 2, "hp": 1.0}, {"marks": 2, "step": 3, "hp": 1.1}]},
	{"id": "veterans", "name": "Veterans' Bracket", "rank": 5, "fee": 12, "floor": 6, "tower": "manticore", "round_renown": 3, "renown": 30, "crystals": 36,
		"rounds": [{"marks": 3, "step": 1, "hp": 1.0}, {"marks": 2, "step": 3, "hp": 1.0}, {"marks": 3, "step": 2, "hp": 1.1}]},
	{"id": "masters", "name": "Masters' Bracket", "rank": 6, "fee": 15, "floor": 8, "tower": "gryphon", "round_renown": 4, "renown": 38, "crystals": 45, "relic": true,
		"rounds": [{"marks": 2, "step": 3, "hp": 1.0}, {"marks": 2, "step": 4, "hp": 1.1}, {"mirror": true}]},
	{"id": "grand", "name": "Grand Bracket", "rank": 9, "fee": 18, "floor": 10, "tower": "firebird", "round_renown": 4, "renown": 46, "crystals": 52, "relic": true,
		"rounds": [{"marks": 3, "step": 3, "hp": 1.0}, {"mirror": true}, {"marks": 3, "step": 4, "hp": 1.15}]},
	{"id": "champions", "name": "Champions' Bracket", "rank": 10, "fee": 20, "floor": 11, "tower": "chimera", "round_renown": 5, "renown": 55, "crystals": 60, "relic": true,
		"rounds": [{"marks": 2, "step": 4, "hp": 1.0}, {"marks": 3, "step": 4, "hp": 1.1}, {"marks": 3, "step": 5, "hp": 1.25}]},
]
static var RELIC_CHANCE := 0.15
## A repeat win pays this share of a bracket's prize.
static var REPEAT := {"renown": 0.25, "crystals": 0.5}

## The tournament master: a name and what they say (one line is picked).
static var MASTER := {"name": "the Tournament Master"}
static var MASTER_LINES := {
	"greet": ["\"Three rounds. First to yield loses. Nobody dies on my sand.\"", "\"Sign the book, pay the fee, and mind the line.\""],
	"round": ["\"Next!\"", "\"Clean. Again.\"", "\"Up you get. Another waits.\""],
	"final": ["\"The final. Make it worth watching.\"", "\"Last round. They've heard of you.\""],
	"won": ["\"The bracket is yours. Take your prize.\"", "\"Well fought. They'll talk about that one.\""],
	"lost": ["\"You yielded. No shame in it. Come back stronger.\"", "\"That's the bracket. Rest, then try again.\""],
}

static var TEXT := {
	"safe": "Nothing you carry is at risk at a station.",
	"leave": "Back to the train",
	"leave_short": "Train",
	"arrive": "The train pulls into %s.",
	"locked": "Opens at the rank of %s",
	"locked_short": "Rank: %s",
	"best": "Your best: %s",
	"never": "Not tried yet",
	"medal_needs": "%s: %s",
	"begin": "Begin the drill",
	"enter": "Enter the bracket",
	"lesson_begin": "Begin the lesson",
	"lesson_again": "Try it again",
	"lesson_skip": "Skip it: I know this",
	"lesson_done": "Done",
	"lesson_skipped": "Skipped",
	"lesson_todo": "Not done yet",
	"lessons": "The basics",
	"lessons_note": "Short lessons with the Entity. Each is remembered once done. Finish them all: +%d renown.",
	"lessons_count": "%d of %d done",
	"lessons_all": "The basics are done. Come back any time.",
	"lessons_paid": "The basics, done: +%d renown",
	"drills": "Medal drills",
	"drills_note": "A goal and a medal. First medals earn renown.",
	"drill_rewards": "Still to earn",
	"extra": "An extra drill: a worn title with a Training benefit opens it",
	"extra_open": "An extra drill, open to your title",
	"fee": "Entry fee",
	"fee_cut": "Your title takes %d%% off",
	"fee_note": "Paid in crystals of any kind, the biggest first. Losing costs nothing more.",
	"free": "No fee",
	"rewards": "A win pays",
	"rewards_repeat": "A repeat win pays",
	"rounds_pay": "Each round past your best: +%d renown",
	"renown": "+%d renown",
	"crystals": "%d %s",
	"relic": "a relic: a named piece",
	"relic_maybe": "sometimes a relic",
	"prize_more": "Your title adds %d%% to the prize",
	"title_for": "and a title from the Noble: %s",
	"rounds": "Rounds",
	"round": "Round %d: %s",
	"climber_one": "a climber with one mark (step %d)",
	"climber_many": "a climber with %d marks (best step %d)",
	"mirror": "your own reflection",
	"master": "Tournament master",
	"best_rounds": "Your best: %d of %d rounds",
	"won_times": "Won %d times",
	"won_once": "Won once",
	"won": "Won",
	"early": "Opened sooner by your title",
	"medals": "Medals",
	"result_medal": "%s  ·  %s",
	"result_none": "No medal  ·  %s",
	"result_win": "You win the %s",
	"result_loss": "Out of the %s in round %d",
	"result_round": "Round %d won",
	"result_fell": "Knocked down: you yield",
	"result_time": "Time is up",
	"result_quit": "You give up",
	"result_lesson": "Lesson done: %s",
	"result_lesson_not": "Not done yet: %s. Try again any time.",
	"relic_won": "A relic for your stash: %s",
	"relic_full": "Your stash is full: the relic becomes %s",
	"paid": "+%s",
	"fee_paid": "Entry fee paid: %s",
	"cant": "Can't: %s",
	"needs_fee": "needs %d more essence, of any kind",
	"rank_now": "Rank: %s",
	"deeds": "Recent deeds",
	"no_deeds": "Nothing yet. Climb, train and fight: the climbers will talk.",
	"ranks": "Ranks and what they open",
	"next_rank": "Next: %s",
	"next_opens": "%s opens:",
	"top_rank": "You hold the highest rank.",
	"rank_reached": "Reached",
	"rank_up_now": "You rose to %s. It opens: %s",
	"deed_drill": "%s at %s",
	"deed_bracket": "Won the %s",
	"deed_rounds": "Reached round %d of the %s",
	"deed_lessons": "Finished the Training basics",
	# In the arena (arena.gd)
	"hud_time": "%d s",
	"hud_round": "Round %d of %d",
	"hud_parry": "Parried %d",
	"hud_kills": "Felled %d of %d",
	"hud_hits": "Hits %d",
	"hud_post": "Post %d of %d",
	"hud_cast": "Best cast %d",
	"hud_rolls": "Rolls %d of %d",
	"hud_items": "Items used %d of %d",
	"hud_hit": "Dummies hit %d of %d",
	"hud_cure": "Cure it",
	"hud_wall": "Break the wall",
	"hud_ward": "Braziers %d of %d",
	"give_up": "Give up, back to the station",
	"paused": "At the station",
	"pause_note": "Nothing you carry is at risk here. Giving up keeps no reward.",
	"go": "Go!",
	"start_drill": "Training",
	"start_lesson": "Training",
	"start_tourney": "Tournament",
	"vs": "%s steps up",
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


# --- lessons ---------------------------------------------------------------------------

## A lesson's state: 0 not done, 1 done, 2 skipped.
static func lesson_state(profile, id: String) -> int:
	return int(Renown.state(profile)["lessons"].get(id, 0))


static func lessons_left(profile) -> Array:
	return LESSON_ORDER.filter(func(id): return LESSONS.has(id) and lesson_state(profile, id) == 0)


static func lessons_done(profile) -> bool:
	return lessons_left(profile).is_empty()


static func lesson_goal(id: String) -> String:
	var d: Dictionary = LESSONS.get(id, {})
	var goal := String(d.get("goal", ""))
	if not goal.contains("%"):
		return goal
	match String(d.get("kind", "")):
		"run":
			return goal % int(d.get("posts", 3))
		"ward":
			return goal % int(d.get("pieces", 2))
	return goal % int(d.get("need", 1))


## Marks a lesson done (1) or skipped (2); the first time the set is done,
## its renown. Returns the lines to say.
static func finish_lesson(profile, id: String, how: int) -> Array:
	var lines: Array = []
	if not LESSONS.has(id):
		return lines
	var r := Renown.state(profile)
	var was := lessons_done(profile)
	if lesson_state(profile, id) != 1:
		r["lessons"][id] = how
	if not was and lessons_done(profile):
		var got := Renown.earn(profile, LESSON_REWARD, TEXT["deed_lessons"])
		lines.append(TEXT["lessons_paid"] % LESSON_REWARD)
		_rank_lines(got, lines)
	profile.save()
	return lines


static func skip_lesson(profile, id: String) -> Array:
	if not Training.can_skip(profile):
		return [Training.TEXT["no_skip"]]  # (basic training is required for the Noble's Grace)
	return finish_lesson(profile, id, 2)


# --- drills ---------------------------------------------------------------------------

static func drill_unlocked(profile, id: String) -> bool:
	if not DRILLS.has(id):
		return false
	if bool(DRILLS[id].get("extra", false)) and not Titles.flag(profile, "gym", "extra"):
		return false
	return Renown.rank(profile) >= int(DRILLS[id].get("rank", 0))


## A drill's goal in words, its numbers filled in.
static func drill_goal(id: String) -> String:
	var d: Dictionary = DRILLS[id]
	var goal := String(d["goal"])
	if not goal.contains("%"):
		return goal
	match String(d["kind"]):
		"kills", "shoot":
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

static func bracket(id: String) -> Dictionary:
	for b in BRACKETS:
		if String(b["id"]) == id:
			return b
	return {}


## Its number (1 the first), for the titles' "tier" deed; 0 if none.
static func bracket_number(id: String) -> int:
	for i in BRACKETS.size():
		if String(BRACKETS[i]["id"]) == id:
			return i + 1
	return 0


## Open: your rank (plus a worn title's "early") has reached it.
static func bracket_open(profile, id: String) -> bool:
	var b := bracket(id)
	if b.is_empty():
		return false
	return Renown.rank(profile) + int(Titles.num(profile, "tourney", "early")) >= int(b.get("rank", 0))


## Opened only by the worn title (your rank alone hasn't reached it).
static func bracket_early(profile, id: String) -> bool:
	return bracket_open(profile, id) and Renown.rank(profile) < int(bracket(id).get("rank", 0))


static func bracket_wins(profile, id: String) -> int:
	return int(Renown.state(profile)["tiers"].get(str(bracket_number(id)) + "_n", 0))


static func bracket_won(profile, id: String) -> bool:
	return bool(Renown.state(profile)["tiers"].get(str(bracket_number(id)), false))


static func best_rounds(profile, id: String) -> int:
	return int(Renown.state(profile)["rounds"].get(id, 0))


## The prize for winning now: {renown, crystals, kind, relic ("yes", "maybe", "")}.
## At a station, the crystals are of its tower's kind (tournaments.gd).
static func prize(profile, id: String, station_id := "") -> Dictionary:
	var b := bracket(id)
	var first := not bracket_won(profile, id)
	var more := 1.0 + Titles.num(profile, "tourney", "prize")
	var tw := String(b.get("tower", "kraken"))
	if station_id != "":
		tw = String(station(station_id).get("tower", tw))
	var kind := String(Towers.TOWERS.get(tw, {}).get("essence", "stone"))
	var rn := float(b.get("renown", 0)) * (1.0 if first else float(REPEAT["renown"])) * more
	var cr := float(b.get("crystals", 0)) * (1.0 if first else float(REPEAT["crystals"])) * more
	var relic := ""
	if bool(b.get("relic", false)):
		relic = "yes" if first else "maybe"
	return {"renown": maxi(1, int(round(rn))), "crystals": maxi(1, int(round(cr))), "kind": kind, "relic": relic, "first": first}


## A round's opponent in words.
static func round_text(rd: Dictionary) -> String:
	if bool(rd.get("mirror", false)):
		return TEXT["mirror"]
	var n := int(rd.get("marks", 1))
	return TEXT["climber_one"] % int(rd.get("step", 1)) if n <= 1 else TEXT["climber_many"] % [n, int(rd.get("step", 1))]


static func master_line(key: String) -> String:
	var pool: Array = MASTER_LINES.get(key, [])
	return String(pool[randi() % pool.size()]) if not pool.is_empty() else ""


# --- fees, events and why not --------------------------------------------------------------

## The entry fee for an event (crystals of any kind; 0 for none), less a
## worn title's cut.
static func fee(profile, type: String, id: String) -> int:
	var base := 0
	var cut := 0.0
	match type:
		"drill":
			base = int(DRILLS.get(id, {}).get("fee", 0))
			cut = Titles.num(profile, "gym", "fee_cut")
		"tourney":
			base = int(bracket(id).get("fee", 0))
			cut = Titles.num(profile, "tourney", "fee_cut")
		"advanced":
			return Training.fee(profile, id)  # (paid in its own kind: fee_kind)
	if base <= 0:
		return 0
	var dear: float = load("res://scripts/city_lore.gd").price_mult(profile)  # (an Unbound found out this visit pays more: city_lore.gd PASSING)
	return maxi(0, int(round(float(base) * (1.0 - clampf(cut, 0.0, 1.0)) * dear)))


## The kind an event's fee is paid in: "any" (crystals of any kind, the
## biggest first), or an essence (advanced and mark training: training.gd).
static func fee_kind(profile, type: String, id: String) -> String:
	return Training.fee_kind(profile, id) if type == "advanced" else "any"


## What an event is, for arena.gd: {"type", "id", "name", "time", "floor",
## "tower", "station", "stop", ...} (a lesson or drill adds its own keys, a
## bracket its rounds).
static func event(type: String, id: String, station_id := "") -> Dictionary:
	var ev := {"type": type, "id": id, "station": station_id, "time": 0, "floor": 1, "tower": "kraken"}
	match type:
		"lesson":
			ev.merge(LESSONS.get(id, {}), true)
			ev["stop"] = "gym"
			ev["tower"] = String(LESSONS.get(id, {}).get("tower", "kraken"))
		"basics":
			# Basic training, one session (tutorial.gd); "from": the step to start at.
			ev["name"] = String(Tutorial.TEXT["name"])
			ev["stop"] = "gym"
			ev["from"] = 0
		"drill":
			ev.merge(DRILLS.get(id, {}), true)
			ev["stop"] = "gym"
		"advanced":
			ev.merge(Training.lesson(id), true)
			ev["stop"] = "gym"
			ev["tower"] = String(ev.get("tower", "kraken"))
		"first":
			ev.merge(Training.FIRST, true)
			ev["rounds"] = Training.first_rounds(station_id)
			ev["tower"] = String(station(station_id).get("tower", "gryphon")) if station_id != "" else "gryphon"
			ev["layout"] = String(load("res://scripts/tournaments.gd").location(station_id).get("layout", ""))
			ev["time"] = 0
			ev["stop"] = "arena"
		"tourney":
			var b := bracket(id)
			ev.merge(b, true)
			ev["time"] = 0
			ev["stop"] = "arena"
			if station_id != "":
				load("res://scripts/tournaments.gd").adapt(ev, station_id)  # (the Manager's location: its layout, hazards, creatures and rivals)
	ev["type"] = type
	ev["id"] = id
	return ev


## Why an event can't be begun ("" if it can): locked, or the fee unpaid.
## `station_id` (where it would be held) checks the Tournament Manager is
## there, and that a climber's first tournament comes first.
static func why_not(profile, type: String, id: String, station_id := "") -> String:
	match type:
		"lesson":
			if not LESSONS.has(id):
				return "?"
		"advanced":
			return Training.why_not(profile, id)
		"first":
			if not Training.closed(profile):
				return Training.TEXT["first_done"]
			if not Training.basic_done(profile):
				return Training.TEXT["first_locked"]
			return ""
		"drill":
			if not DRILLS.has(id):
				return "?"
			if bool(DRILLS[id].get("extra", false)) and not Titles.flag(profile, "gym", "extra"):
				return TEXT["extra"]
			if not drill_unlocked(profile, id):
				return TEXT["locked"] % Renown.rank_name(int(DRILLS[id].get("rank", 0)))
		"tourney":
			var b := bracket(id)
			if b.is_empty():
				return "?"
			if not bracket_open(profile, id):
				return TEXT["locked"] % Renown.rank_name(int(b.get("rank", 0)))
			if Training.closed(profile):
				return load("res://scripts/tournaments.gd").TEXT["why_first"]
			var TM = load("res://scripts/tournaments.gd")
			if station_id != "" and not TM.at(profile, station_id):
				return String(TM.TEXT["why_away"]) % TM.station_name(TM.here(profile))
	var f := fee(profile, type, id)
	if f > 0 and int(profile.crystals_held()) < f:
		return TEXT["needs_fee"] % (f - int(profile.crystals_held()))
	return ""


static func _rank_lines(got: Dictionary, lines: Array) -> void:
	if String(got.get("rank_up", "")) != "":
		lines.append(Renown.TEXT["rank_up"] % got["rank_up"])
	for tid in got.get("titles", []):
		lines.append(Renown.TEXT["title_up"] % Renown.title_name(String(tid)))


## Applies an event's result to the climber: lessons, medals, rounds, wins,
## renown, crystals and relics. `res`: {"type", "id", "done" (a lesson),
## "score" (a drill; -1 not finished), "rounds" and "won" (a bracket),
## "mirrors" (your reflection beaten)}. Returns the lines to show
## ({"lines": [...], "medal", "renown", "won"}). Saves.
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
		"basics":
			lines.append_array(Tutorial.apply(profile, res))
		"lesson":
			var name := String(LESSONS.get(id, {}).get("name", id))
			if bool(res.get("done", false)):
				lines.append(TEXT["result_lesson"] % name)
				lines.append_array(finish_lesson(profile, id, 1))
			else:
				if res.has("why"):
					lines.append(String(res["why"]))
				lines.append(TEXT["result_lesson_not"] % name)
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
		"tourney":
			var b := bracket(id)
			if b.is_empty():
				return out
			var rounds := clampi(int(res.get("rounds", 0)), 0, (b.get("rounds", []) as Array).size())
			var best := best_rounds(profile, id)
			if rounds > best:
				gain += int(b.get("round_renown", 0)) * (rounds - best)
				r["rounds"][id] = rounds
				why = TEXT["deed_rounds"] % [rounds, b["name"]]
			if out["won"]:
				var pz := prize(profile, id, String(res.get("station", "")))
				var num := str(bracket_number(id))
				r["tiers"][num] = true
				r["tiers"][num + "_n"] = int(r["tiers"].get(num + "_n", 0)) + 1
				gain += int(pz["renown"])
				profile.add_crystal(String(pz["kind"]), float(pz["crystals"]))
				lines.append(TEXT["result_win"] % b["name"])
				lines.append(TEXT["paid"] % (TEXT["crystals"] % [int(pz["crystals"]), Essence.display(String(pz["kind"]))]))
				why = TEXT["deed_bracket"] % b["name"]
				if String(pz["relic"]) == "yes" or (String(pz["relic"]) == "maybe" and randf() < RELIC_CHANCE):
					lines.append(give_relic(profile, String(pz["kind"])))
				lines.append_array(load("res://scripts/tournaments.gd").reward(profile, String(res.get("station", "")), id))  # (the shared minor reward, and the location's own prize)
			else:
				lines.append(TEXT["result_loss"] % [b["name"], rounds + 1])
				if res.has("why"):
					lines.append(String(res["why"]))
		"advanced":
			lines.append_array(Training.apply_advanced(profile, res))
		"first":
			lines.append_array(Training.apply_first(profile, res))
	# Training's essence: a share of the usual amount (training.gd RATES).
	lines.append_array(Training.settle(profile, res))
	if gain > 0:
		lines.append(TEXT["renown"] % gain)
	var got := Renown.earn(profile, gain, why)
	out["renown"] = gain
	_rank_lines(got, lines)
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


static func foe_name(k: String) -> String:
	if k == "mirror":
		return TEXT["mirror"]
	if k.ends_with("*"):
		return k.trim_suffix("*").capitalize()
	return k.capitalize()


## "Won once", "Won 3 times".
static func wins_text(n: int) -> String:
	return TEXT["won_once"] if n == 1 else TEXT["won_times"] % n
