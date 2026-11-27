extends RefCounted
## THE DINING CAR: the climbers you meet, as recurring people. A car on the
## train (train_page.gd builds its things through dining_page.gd; train_view.gd
## draws the room) where other climbers sit at tables between climbs. Each
## visit (a stay on the train between two climbs) seats RULES "seats_min" to
## "seats_max" of them: mostly rivals you've met in the towers (rivals.gd:
## they remember you and your history), plus a new face or two, made with the
## same rival system, so you may meet them in a tower later. Talk to one (tap
## them) and pick a line, as with the Entity:
##   rumor   something true and useful, read from the game's own tables when
##           it's said (RUMORS: each names a fact function, fact_<name>);
##           a monster's weakness also fills that Bestiary line (bestiary.gd
##           "told"); or a line of the children's counting rhyme (RHYME)
##   bet     a wager in crystals on your next climb (BETS: reach a floor, fell
##           the beast, a floor without a Healing Vial, slay so many of a
##           kind); odds by difficulty; paid (or lost) when the climb ends
##           (settle, called from main.gd pay_climb), shown in play as a
##           small line at the top (hud.gd) and in the Entity's log
##   trade   their goods for your crystals, or your piece for theirs, at the
##           outfitter's prices (train.gd); their goods follow their marks
##   duel    a duel for a stake (crystals, a piece of gear, or renown),
##           fought in the Arena car (arena.gd, type "duel"; drawn by
##           arena_car.gd), reachable only this way; nobody dies, as with
##           rivals in the towers; you come back to the Dining car after
## Their attitude follows your history with them (attitude): one you robbed
## is cold (no rumors, bets or trades; they still want a duel), one you
## helped or climbed with is warm (a small gift each visit, better odds, a
## little off), and the title you wear can warm them too (perks: the one
## place title perks are read).
## Kept with the climber: profile.gd `dining` (an old save: none), and the
## people themselves in profile.gd `rivals`, shared with the towers.
## Every word and number is here (the Data editor: "The Dining car").

const Rivals := preload("res://scripts/rivals.gd")
const Renown := preload("res://scripts/renown.gd")
const Towers := preload("res://scripts/towers.gd")
const TowerNeeds := preload("res://scripts/tower_needs.gd")
const Bonds := preload("res://scripts/bonds.gd")
const Essence := preload("res://scripts/essence.gd")
const Items := preload("res://scripts/items.gd")
const Gear := preload("res://scripts/gear.gd")
const Charms := preload("res://scripts/charms.gd")
const Flow := preload("res://scripts/essence_flow.gd")
const Bestiary := preload("res://scripts/bestiary.gd")
const Enemy := preload("res://scripts/enemy.gd")
const TRAIN := "res://scripts/train.gd"  # (loaded when needed)
const WINGS := "res://scripts/wings.gd"

## The numbers.
##   seats_min, seats_max   how many climbers sit in the car each visit
##   new_faces              how many of them are new faces (more while
##                          you've met few: the rest of the seats)
##   max_bets               wagers you can have open at once
##   stake_low/mid/high     the stakes offered for a wager (crystals of any
##                          kind, your biggest first)
##   odds_*                 what a winning wager pays, times the stake:
##                          floor_1..3 (that many floors past your best
##                          there), beast (felled before: beast_again), dry
##                          (a floor without a Healing Vial), slay_low /
##                          slay_high (slay slay_few / slay_many of a kind)
##   warm_odds              a warm climber's odds are this much better
##   title_odds             ...and a title that takes bets (titles.gd) this much
##   warm_off               ...and they take this share off their goods
##   gift                   a warm climber's gift each visit (crystals of
##                          their mark's kind)
##   buy_share              what they pay for a piece of yours, a share of
##                          its price (the outfitter pays train.gd SELL_SHARE)
##   duel_crystals          a duel's stake in crystals
##   duel_renown            a duel's stake in renown
##   duel_win_renown        renown a duel won earns besides the stake
##   duel_floor             a duel's foe is as tough as this floor (or your
##                          best, if higher, up to duel_floor_most)
##   duel_time              after this long (seconds) a duel is a draw
##   duel_yield             they yield at this share of their health
##   duel_left              a lost duel leaves you this share of your health
##   entity_chance          how often a climber you know mentions their own
##                          Entity in passing (LINES "entity")
static var RULES := {
	"seats_min": 3, "seats_max": 5, "new_faces": 1, "max_bets": 2,
	"stake_low": 10, "stake_mid": 20, "stake_high": 40,
	"odds_floor_1": 1.6, "odds_floor_2": 2.2, "odds_floor_3": 3.0, "odds_beast": 3.5, "odds_beast_again": 2.2,
	"odds_dry": 1.8, "odds_slay_low": 1.5, "odds_slay_high": 2.2, "slay_few": 5, "slay_many": 10,
	"warm_odds": 0.25, "warm_off": 0.1, "title_odds": 0.2, "gift": 8, "buy_share": 0.6,
	"duel_crystals": 20, "duel_renown": 6, "duel_win_renown": 4, "duel_floor": 3, "duel_floor_most": 9,
	"duel_time": 120.0, "duel_yield": 0.15, "duel_left": 0.2, "entity_chance": 0.1,
}

## What they say, by your history with them (one is picked; {mark}, {part},
## {step}, {name} filled in). "first" is a new face; the attitude lines go
## after a history line when there's no history worth saying.
static var LINES := {
	"first": ["\"Haven't seen you before. Climbing too?\"", "\"A new face. Sit, if you like.\"", "\"Another one for the towers. Pull up a chair.\""],
	"again": ["\"You again. Still climbing.\"", "\"Back on the train, then.\"", "\"Thought I'd see you here.\""],
	"won": ["\"You beat me once. Not again.\"", "\"I still feel that last duel.\""],
	"lost": ["\"Come for another beating?\"", "\"I'd fight you again. I'd win again.\""],
	"teamed": ["\"We reached a stair together. I remember.\"", "\"Climb with me again sometime.\""],
	"rescued": ["\"You picked me up off that floor. I haven't forgotten.\"", "\"I owe you. Sit down.\""],
	"robbed": ["\"You took my hoard. We're not friends.\"", "\"I know what you did. Keep walking.\""],
	"mark": ["\"My {mark} mark is at step {step}. It's carried me this far.\"", "\"{mark}, on my {part}. You?\""],
	"rumor_none": ["\"Nothing worth telling. Ask me next time.\""],
	"cold_rumor": ["\"Ask someone you haven't robbed.\""],
	"cold_bet": ["\"I don't bet with thieves.\""],
	"cold_trade": ["\"Trade? With you? No.\""],
	"bet_open": ["\"I'll take a wager on your next climb.\"", "\"Care to put crystals on yourself?\""],
	"trade_open": ["\"Here's what I've got.\"", "\"Fair prices. Have a look.\""],
	"duel_open": ["\"A duel? In the Arena car. Name the stake.\"", "\"First to yield. What are we fighting for?\""],
	"gift": ["\"For last time. Take it.\"", "\"Here. I don't forget a kindness.\""],
	"bye": ["\"Climb well.\"", "\"Until next time.\""],
	# Now and then (RULES entity_chance), in passing: their own Entity. Nobody
	# knows if there is one Entity or many.
	"entity": ["\"Mine went quiet just before you sat down.\"", "\"Yours tell you about the Makers too?\"", "\"Mine never stops talking on the stairs. Yours?\"",
		"\"Do you think they're all the same one? The Entities, I mean. Mine won't say.\"", "\"Mine says I climb too fast. Don't tell it I told you.\"", "\"Mine laughed when you walked in. It doesn't laugh much.\""],
}

## The counting rhyme the children chant in the cities, a line at a time:
## heard as a rumor here (RUMORS "rhyme") and from rival climbers in the
## tower (rivals.gd LINES "rhyme"). The owner's approved words.
static var RHYME := [
	"Count six wells, six stones, and six beasts that keep them.",
	"Count six who held the world: two given, three building, one cast out.",
	"Count four sixes for the years between each climber who could break the keeping.",
	"Count six such climbers, and the keeping is done.",
	"The fifth was broken into six blades, to wait for the last.",
	"The last will hold the making and the unmaking: to make anew, or to break again.",
]

## Rumors: each is a fact read from the game when it's said (fact_<fact>
## below returns the blanks, or {} when it has nothing true to say), and
## the words to say it with. A monster's weakness fills that Bestiary line.
static var RUMORS := [
	{"id": "guardians", "fact": "guardians", "lines": ["{rumour}"]},  # (what the guardians learned from each other's deaths: guardian_lessons.gd)
	{"id": "wild", "fact": "wild", "lines": ["{rumour}"]},  # (a tower whose well runs wild: wild_towers.gd RUMOURS "dining")
	{"id": "handy", "fact": "handy", "lines": ["\"Going up {tower}? Carry {item}: {why}.\""]},
	{"id": "weakness", "fact": "weakness", "lines": ["\"{monster}? {weak}. Learned that the hard way.\""]},
	{"id": "beast", "fact": "beast", "lines": ["\"{beast} waits at the top of {tower}. {hint}\""]},
	{"id": "rival_mark", "fact": "rival_mark", "lines": ["\"If you meet {name} up there: {mark} on the {part}, step {step}.\""]},
	{"id": "dark", "fact": "dark", "lines": ["\"In {tower}, from floor {floor} the halls go dark. {item} carries your light.\""]},
	{"id": "wing", "fact": "wing", "lines": ["\"From floor {floor}, a sealed wing may ask this: {rule}\""]},
	{"id": "best_bet", "fact": "best_bet", "lines": ["\"Wagers? The best odds on the train tonight are {odds} for {bet}.\""]},
	{"id": "rhyme", "fact": "rhyme", "lines": ["\"The children at every station chant it: '{rhyme}'\"", "\"You know the counting rhyme? '{rhyme}'\""]},  # (a line of RHYME)
]

## The wagers: what you bet will happen on your next climb (in the tower
## chosen on the Engine's board when you bet). {floor}, {beast}, {count},
## {monster} filled in; the tower is said beside it ("in": TEXT bet_in).
static var BETS := {
	"floor": {"name": "Reach floor {floor}"},
	"beast": {"name": "Fell {beast}"},
	"dry": {"name": "Reach floor {floor}, no Healing Vial"},
	"slay": {"name": "Slay {count} {monster}"},
}

## Words.
static var TEXT := {
	"car": "Dining Car",
	"tables": "Tonight's company",
	"tables_short": "Company",
	"pick": "Tap a climber to talk.",
	"pick_keys": "Choose a climber to talk.",
	"nobody": "The tables are empty tonight.",
	"new_face": "New face",
	"history": "With you: %s",
	"never": "You've never met.",
	"warm": "They're glad to see you.",
	"cold": "They're cold to you.",
	"plain": "",
	"title_warm": "Your title warms them: %s.",
	"title_bets": "Your title, %s: they take your bets, at better odds.",
	"marks": "Marks: %s",
	"ask_rumor": "Heard anything useful?",
	"ask_bet": "Fancy a wager on my next climb?",
	"ask_trade": "Got anything to trade?",
	"ask_duel": "I'll fight you for it.",
	"ask_bye": "Goodbye.",
	"ask_back": "Something else.",
	"bets_open": "Your wagers",
	"bets_none": "No wagers yet. A climber will take one.",
	"bets_full": "You have %d wagers open. They settle when your next climb ends.",
	"bet_line": "%s  ·  %s, pays %s",
	"bet_odds": "%sx",
	"bet_in": "%s (%s)",
	"bet_pick": "%s  ·  %sx",
	"stake": "Stake %d",
	"stake_note": "Crystals of any kind, your biggest first. A win pays the stake times the odds, in %s.",
	"bet_placed": "Wager placed with %s: %s.",
	"bet_short": "needs %d more essence, of any kind",
	"bet_small": "Only small stakes with strangers: %d. A title that takes bets, or a climber you've helped, takes more.",
	"bet_tower": "On your next climb, in %s (the Engine's choice).",
	"bet_won": "Won your wager with %s: %s. +%s",
	"bet_lost": "Lost your wager with %s: %s.",
	"bet_void": "Your wager with %s is off (you climbed elsewhere): %s back.",
	"bet_hud": "Wager: %s",
	"bet_hud_count": "Wager: %s (%d/%d)",
	"bet_log": "Your wager with %s: %s",
	"trade_give": "Their %s for %s",
	"trade_buy": "Your %s for %s",
	"trade_done": "Traded with %s: %s",
	"trade_none": "Nothing to trade tonight.",
	"trade_full": "No room for it",
	"trade_bought": "+ %s",
	"trade_sold": "Sold your %s: + %s",
	"gift_got": "%s gives you %s.",
	"duel_stake": "Stake: %s",
	"duel_crystals": "%d %s crystals",
	"duel_piece": "your %s for their %s",
	"duel_renown": "%d renown",
	"duel_ready": "Into the Arena car: first to yield. Nobody dies.",
	"duel_go": "To the Arena car",
	"duel_short": "You can't stake that",
	"duel_name": "A duel with %s",
	"duel_hud": "Duel with %s  ·  stake: %s",
	"duel_won": "%s yields. You win %s.",
	"duel_lost": "%s wins the duel and %s.",
	"duel_lost_takes": "takes %s",
	"duel_draw": "Time's up: a draw. The stakes stay where they were.",
	"duel_deed": "Won a duel with %s in the Arena car",
	"duel_deed_lost": "Lost a duel with %s (%d renown)",
	"arena_car": "The Arena car",
	"give_up": "Yield, back to the Dining car",
	"pause_note": "Yielding loses the duel and its stake. Nobody dies here.",
	"result_won": "They yield",
	"result_lost": "You yield",
	"result_draw": "A draw",
	"arena_banner": "THE ARENA CAR",
	"arena_line": "A duel with %s: the first to yield loses",
	"heard": "Heard tonight",
}


# --- the climber's record (profile.gd `dining`) ----------------------------------------

## The Dining car's record, every key filled in (an old save: none).
##   trips      climbs begun from the train (each starts a new visit)
##   seat_trip  the visit the seats are for; seats: the ids seated
##   faces      new faces seated this visit (not met yet): id -> record
##   offers     this visit's offers: id -> {"rumor", "bets", "trade"}
##   talked     id -> the visit you last talked (counts a meeting once)
##   gifts      id -> the visit they last gave you a gift
##   bets       open wagers (see place_bet)
##   news       what the last settling said (shown in the car)
##   duels      duels fought in the Arena car
static func state(prof) -> Dictionary:
	if prof == null:
		return {}
	var d = prof.get("dining")
	if not (d is Dictionary):
		prof.set("dining", {})
		d = prof.get("dining")
	if not (d is Dictionary):
		return {}
	var defaults := {"trips": 0, "seat_trip": -1, "seats": [], "faces": {}, "offers": {}, "talked": {}, "gifts": {}, "bets": [], "news": [], "duels": 0}
	for k in defaults:
		if not d.has(k) or typeof(d[k]) != typeof(defaults[k]):
			d[k] = defaults[k].duplicate() if defaults[k] is Dictionary or defaults[k] is Array else defaults[k]
	return d


## A line picked from LINES (or a list) with its blanks filled.
static func say(key: String, fill := {}) -> String:
	var pool: Array = LINES.get(key, [])
	if pool.is_empty():
		return ""
	return fill_in(String(pool[randi() % pool.size()]), fill)


static func fill_in(text: String, fill: Dictionary) -> String:
	for k in fill:
		text = text.replace("{" + String(k) + "}", str(fill[k]))
	return text


# --- title perks: the one place they're read ------------------------------------------

## The worn title's terms with other climbers (titles.gd rival_terms, the
## one hook for rival-climber perks), as the Dining car uses them:
##   warm   ("friendly") plain climbers treat you as warm: better odds, a
##          little off (gifts stay for the ones you helped)
##   off    (1 - "trade_ask") a share off their goods
##   bets   ("bets") every climber takes a full wager: both offers, every
##          stake, and RULES "title_odds" better odds (without it a plain
##          climber offers one wager, at the smallest stake)
##   toll   ("toll") a duel lost costs this share of a crystal or renown stake
##   name   the worn title's name
static func perks(prof) -> Dictionary:
	var out := {"warm": false, "odds": 0.0, "off": 0.0, "bets": false, "toll": 1.0, "name": ""}
	if prof == null:
		return out
	var terms: Dictionary = load("res://scripts/titles.gd").rival_terms(prof)
	out["warm"] = bool(terms.get("friendly", false))
	out["off"] = clampf(1.0 - float(terms.get("trade_ask", 1.0)), 0.0, 0.7)
	out["bets"] = bool(terms.get("bets", false))
	out["odds"] = float(RULES["title_odds"]) if out["bets"] else 0.0
	out["toll"] = clampf(float(terms.get("toll", 1.0)), 0.0, 1.0)
	out["name"] = Renown.worn_title(prof)
	return out


## Whether a climber takes a full wager (both offers, every stake): one you
## helped or climbed with, or anyone while your title has "bets".
static func full_bets(prof, rec: Dictionary) -> bool:
	if bool(perks(prof)["bets"]):
		return true
	return int(rec.get("rescued", 0)) > 0 or int(rec.get("teamed", 0)) > 0 or bool(rec.get("owed", false))


# --- who sits in the car ----------------------------------------------------------------

## The climbers seated this visit (records: met rivals from profile.gd
## `rivals`, new faces from `faces`), seating them if this visit hasn't yet.
static func seated(prof, tower := "") -> Array:
	var st := state(prof)
	if st.is_empty():
		return []
	if int(st["seat_trip"]) != int(st["trips"]) or (st["seats"] as Array).is_empty():
		seat(prof, tower)
	var out: Array = []
	var met := Rivals.state(prof)
	for id in st["seats"]:
		if met.has(id) and met[id] is Dictionary:
			out.append(met[id])
		elif st["faces"].has(id):
			out.append(st["faces"][id])
	return out


## Seats a new visit's climbers: mostly rivals you've met (the one met last
## always, then others of the most recently met), and RULES "new_faces" new
## ones (more while you've met few).
static func seat(prof, tower := "") -> void:
	var st := state(prof)
	var n := randi_range(int(RULES["seats_min"]), maxi(int(RULES["seats_min"]), int(RULES["seats_max"])))
	var met: Array = Rivals.met_list(prof)
	var known: Array = met.slice(1, 8)
	known.shuffle()
	if not met.is_empty():
		known.push_front(met[0])  # (the one you met last always sits down: met on the climb just gone, here they are)
	var fresh := clampi(maxi(int(RULES["new_faces"]), n - known.size()), 0, n)
	var seats: Array = []
	for r in known.slice(0, n - fresh):
		seats.append(String(r["id"]))
	st["faces"] = {}
	var tw := tower if Towers.TOWERS.has(tower) else String(prof.last_tower)
	var used: Array = Rivals.state(prof).values().map(func(r): return String(r.get("name", "")) if r is Dictionary else "")
	for i in fresh:
		var rec := new_face(prof, tw, used)
		used.append(String(rec["name"]))
		st["faces"][rec["id"]] = rec
		seats.append(String(rec["id"]))
	seats.shuffle()
	st["seats"] = seats
	st["seat_trip"] = int(st["trips"])
	st["offers"] = {}


## A new face: a climber made by the rival system (rivals.gd new_rival) for
## a floor near your best in the tower.
static func new_face(prof, tower: String, used: Array) -> Dictionary:
	var fl := clampi(int(prof.record.get("best", {}).get(tower, 2)) if prof != null else 2, 2, 12)
	var maker = Rivals.new()
	var rec: Dictionary = {}
	for i in 6:
		rec = maker.new_rival(fl, tower)
		if not used.has(String(rec["name"])):
			break
	maker.free()
	rec["met"] = 0
	return rec


## Met tonight: a new face joins the climbers you've met (shared with the
## towers, so they may turn up on a climb); a met rival counts one more
## meeting (once a visit). Returns their record as kept.
static func remember(prof, id: String) -> Dictionary:
	var st := state(prof)
	var met := Rivals.state(prof)
	var rec: Dictionary = met.get(id, st["faces"].get(id, {}))
	if rec.is_empty():
		return {}
	if int(st["talked"].get(id, -1)) != int(st["trips"]):
		st["talked"][id] = int(st["trips"])
		rec["met"] = int(rec.get("met", 0)) + 1
		rec["dined"] = int(rec.get("dined", 0)) + 1
		rec["seen"] = int(Time.get_unix_time_from_system()) * 10 + (int(rec["met"]) % 10)
		if not rec.has("climb") or st["faces"].has(id):
			rec["climb"] = -1  # (met on the train: free to turn up on the very next climb)
	if st["faces"].has(id):
		st["faces"].erase(id)
	keep(prof, rec)
	return met.get(id, rec)


## Writes a climber's record into profile.gd `rivals` (oldest forgotten
## past rivals.gd RULES "kept"), and saves.
static func keep(prof, rec: Dictionary) -> void:
	var met := Rivals.state(prof)
	var k := rec.duplicate(true)
	k.erase("returning")
	met[String(rec["id"])] = k
	var seated_now: Array = state(prof)["seats"]
	while met.size() > int(Rivals.RULES["kept"]):
		var oldest := ""
		for id in met:
			if seated_now.has(id):
				continue
			if oldest == "" or int(met[id].get("seen", 0)) < int(met[oldest].get("seen", 0)):
				oldest = id
		if oldest == "":
			break
		met.erase(oldest)
	prof.save()


## A seated climber's record by id ({} if not seated).
static func find(prof, id: String) -> Dictionary:
	for r in seated(prof):
		if String(r.get("id", "")) == id:
			return r
	return {}


# --- attitude -----------------------------------------------------------------------------

## "cold" (you robbed them more than you helped them), "warm" (you helped
## them, climbed with them, or your title warms them), else "plain".
static func attitude(prof, rec: Dictionary) -> String:
	if int(rec.get("robbed", 0)) > int(rec.get("rescued", 0)):
		return "cold"
	if int(rec.get("rescued", 0)) > 0 or bool(rec.get("owed", false)) or int(rec.get("teamed", 0)) > 0:
		return "warm"
	if bool(perks(prof)["warm"]):
		return "warm"
	return "plain"


## What they say first: your history with them, else their marks (on the
## path of Making or Unmaking, often a line for the aura's step in place of
## the plain words; for an Unbound, now and then a word about passing as
## marked: city_lore.gd). `chance` for tests.
static func greeting(prof, rec: Dictionary, chance := -1.0) -> String:
	var Lore = load("res://scripts/city_lore.gd")
	var said := _greeting(prof, rec, Lore.aura_line(prof, "dining", chance))  # (the aura changes how people speak: city_lore.gd AURA)
	var w: String = Lore.passing_word(prof, chance)  # (an Unbound passes as marked; a rumour of one found out: city_lore.gd PASSING)
	return said + " " + w if w != "" else said


## The greeting itself: `aura` (the aura's line, or "") in place of the
## plain words for a new face or an old acquaintance.
static func _greeting(_prof, rec: Dictionary, aura: String) -> String:
	var fill := mark_fill(rec)
	if int(rec.get("met", 0)) <= 0:
		return aura if aura != "" else say("first", fill)
	if int(rec.get("robbed", 0)) > int(rec.get("rescued", 0)):
		return say("robbed", fill)
	if int(rec.get("rescued", 0)) > 0:
		return say("rescued", fill)
	if int(rec.get("teamed", 0)) > 0:
		return say("teamed", fill)
	if int(rec.get("duels_won", 0)) > int(rec.get("duels_lost", 0)):
		return say("won", fill)
	if int(rec.get("duels_lost", 0)) > 0:
		return say("lost", fill)
	var said := (aura if aura != "" else say("again", fill)) + " " + say("mark", fill)
	if randf() < float(RULES.get("entity_chance", 0.0)):
		said += " " + say("entity", fill)  # (rarely, in passing: their own Entity)
	return said


## Their strongest mark, for the words: {mark, part, step, name}.
static func mark_fill(rec: Dictionary) -> Dictionary:
	var bl: Array = rec.get("bonds", [])
	var f := {"name": String(rec.get("name", "")), "mark": "", "part": "", "step": 0}
	if not bl.is_empty():
		var b: Array = bl[0]
		f["mark"] = String(Bonds.BONDS.get(String(b[0]), {}).get("name", String(b[0])))
		f["part"] = String(Bonds.PART_NAMES.get(String(b[1]), String(b[1]))).to_lower()
		f["step"] = int(b[2])
	return f


## The essence of their strongest mark (their goods and gifts are of it).
static func kind_of(rec: Dictionary) -> String:
	var bl: Array = rec.get("bonds", [])
	if not bl.is_empty():
		var k := String(Bonds.BONDS.get(String(bl[0][0]), {}).get("affinity", ""))
		if Essence.KINDS.has(k):
			return k
	return "iron"


## A warm climber's gift, once a visit: crystals of their mark's kind.
## Returns the words ("" if none is due).
static func gift(prof, rec: Dictionary) -> String:
	var st := state(prof)
	var id := String(rec.get("id", ""))
	if attitude(prof, rec) != "warm" or int(rec.get("met", 0)) <= 0 or int(st["gifts"].get(id, -1)) == int(st["trips"]):
		return ""
	if int(rec.get("rescued", 0)) <= 0 and int(rec.get("teamed", 0)) <= 0 and not bool(rec.get("owed", false)):
		return ""  # (a title's warmth brings better odds, not gifts)
	st["gifts"][id] = int(st["trips"])
	var k := kind_of(rec)
	var amt := int(RULES["gift"])
	prof.add_crystal(k, float(amt))
	prof.save()
	return String(TEXT["gift_got"]) % [String(rec.get("name", "")), price_text(k, amt)]


static func price_text(kind: String, amount: int) -> String:
	return load(TRAIN).price_text(kind, amount)


# --- rumors -------------------------------------------------------------------------------

## A climber's rumor this visit: {"id", "text", "fact": {...the blanks}}, or
## {} if they have nothing true to say. Different climbers tell different
## rumors (by their seat); a weakness fills its Bestiary line as it's heard.
static func rumor(prof, rec: Dictionary, tower: String, hear := true) -> Dictionary:
	var st := state(prof)
	var id := String(rec.get("id", ""))
	var offers: Dictionary = _offers(prof, rec, tower)
	if offers.has("rumor_said"):
		return offers["rumor_said"]
	var seats: Array = st["seats"]
	var start := maxi(0, seats.find(id)) + int(st["trips"])
	var out := {}
	for i in RUMORS.size():
		var r: Dictionary = RUMORS[(start + i) % RUMORS.size()]
		var f := fact(prof, String(r["fact"]), tower, id)
		if f.is_empty():
			continue
		var lines: Array = r.get("lines", [])
		out = {"id": String(r["id"]), "fact": f, "text": fill_in(String(lines[randi() % lines.size()]) if not lines.is_empty() else "", f)}
		break
	if hear and not out.is_empty():
		offers["rumor_said"] = out
		if String(out["fact"].get("type", "")) == "weakness":
			tell_weakness(prof, String(out["fact"]["kind"]))
		prof.save()
	return out


## A fact for a rumor, read from the game now: the blanks, plus "type" and
## the ids that make it checkable; {} if there's nothing true to say.
static func fact(prof, name: String, tower: String, who := "") -> Dictionary:
	match name:
		"handy":
			return fact_handy(prof, tower)
		"weakness":
			return fact_weakness(prof, tower)
		"beast":
			return fact_beast(prof, tower)
		"rival_mark":
			return fact_rival_mark(prof, who)
		"dark":
			return fact_dark(prof, tower)
		"wing":
			return fact_wing(prof, tower)
		"best_bet":
			return fact_best_bet(prof, tower)
		"guardians":
			return fact_guardians(prof)
		"rhyme":
			return fact_rhyme()
		"wild":
			return fact_wild(prof, tower)
	return {}


## A line of the counting rhyme (RHYME): always something to say.
static func fact_rhyme() -> Dictionary:
	if RHYME.is_empty():
		return {}
	var i := randi() % RHYME.size()
	return {"type": "rhyme", "line": i, "rhyme": String(RHYME[i])}


## A tower whose well runs wild (wild_towers.gd): {} while none is.
static func fact_wild(prof, tower: String) -> Dictionary:
	var W = load("res://scripts/wild_towers.gd")
	var r: String = W.rumour(prof, "dining", tower)
	return {"type": "wild", "rumour": r, "towers": W.wild_list(prof)} if r != "" else {}


## What the guardians have learned from each other's deaths (guardian_lessons.gd): {} before any has fallen.
static func fact_guardians(prof) -> Dictionary:
	var r: String = load("res://scripts/guardian_lessons.gd").rumour(prof)
	return {"type": "guardians", "rumour": r} if r != "" else {}


static func _tower_or_last(prof, tower: String) -> String:
	return tower if Towers.TOWERS.has(tower) else (String(prof.last_tower) if prof != null and Towers.TOWERS.has(String(prof.last_tower)) else Towers.ORDER[0])


## A handy item in the tower (tower_needs.gd NEEDS) and why.
static func fact_handy(prof, tower: String) -> Dictionary:
	var tw := _tower_or_last(prof, tower)
	var ids: Array = TowerNeeds.handy(tw).filter(func(i): return Items.ITEMS.has(i))
	if ids.is_empty():
		return {}
	var id := String(ids[randi() % ids.size()])
	return {"type": "handy", "tower_id": tw, "tower": String(Towers.TOWERS[tw]["name"]), "item_id": id, "item": String(Items.ITEMS[id]["name"]), "why": TowerNeeds.why(tw, id)}


## A monster of the tower whose weakness you haven't learned (enemy.gd
## WEAKNESS); hearing it fills that Bestiary line.
static func fact_weakness(prof, tower: String) -> Dictionary:
	var tw := _tower_or_last(prof, tower)
	var kinds: Array = (Towers.TOWERS[tw].get("weights", {}) as Dictionary).keys().filter(func(k): return Enemy.WEAKNESS.has(k) and not knows_weakness(prof, String(k)))
	var beast := String(Towers.TOWERS[tw].get("beast_kind", ""))
	if kinds.is_empty() and Enemy.WEAKNESS.has(beast) and not knows_weakness(prof, beast):
		kinds = [beast]
	if kinds.is_empty():
		return {}
	var k := String(kinds[randi() % kinds.size()])
	var weak := String(Enemy.WEAKNESS[k])
	return {"type": "weakness", "kind": k, "tower_id": tw, "tower": String(Towers.TOWERS[tw]["name"]), "monster": Bestiary.name_of(k) + ("s" if not k in Enemy.BOSSES else ""),
		"weak": weak.substr(0, 1).to_upper() + weak.substr(1)}


## The tower's beast and its hint (towers.gd).
static func fact_beast(prof, tower: String) -> Dictionary:
	var tw := _tower_or_last(prof, tower)
	var t: Dictionary = Towers.TOWERS[tw]
	var hint := String(t.get("beast_hint", ""))
	if hint == "":
		return {}
	var beast := String(t.get("beast", ""))
	return {"type": "beast", "tower_id": tw, "tower": String(t["name"]), "beast": beast.substr(0, 1).to_upper() + beast.substr(1), "hint": hint}


## Another climber you've met (not the one telling it): one of their marks.
static func fact_rival_mark(prof, who: String) -> Dictionary:
	var others: Array = Rivals.met_list(prof).filter(func(r): return String(r.get("id", "")) != who and not (r.get("bonds", []) as Array).is_empty())
	if others.is_empty():
		return {}
	var rec: Dictionary = others[randi() % mini(others.size(), 6)]
	var bl: Array = rec["bonds"]
	var b: Array = bl[randi() % bl.size()]
	return {"type": "rival_mark", "rival": String(rec["id"]), "name": String(rec.get("name", "")), "bond": String(b[0]),
		"mark": String(Bonds.BONDS.get(String(b[0]), {}).get("name", String(b[0]))), "part_id": String(b[1]),
		"part": String(Bonds.PART_NAMES.get(String(b[1]), String(b[1]))).to_lower(), "step": int(b[2])}


## A tower whose deep floors are dark (tower_needs.gd DARK), and what helps.
static func fact_dark(prof, tower: String) -> Dictionary:
	var tw := _tower_or_last(prof, tower)
	if not TowerNeeds.DARK.has(tw):
		for t in TowerNeeds.DARK:
			tw = String(t)
			break
	if not TowerNeeds.DARK.has(tw) or not Items.ITEMS.has("lantern_oil"):
		return {}
	return {"type": "dark", "tower_id": tw, "tower": String(Towers.TOWERS[tw]["name"]), "floor": int(TowerNeeds.DARK[tw].get("from", 4)), "item_id": "lantern_oil", "item": String(Items.ITEMS["lantern_oil"]["name"])}


## A sealed wing's rule and the floor it can come from (wings.gd CONDITIONS).
static func fact_wing(_prof, _tower: String) -> Dictionary:
	var C: Dictionary = load(WINGS).CONDITIONS
	var ids: Array = C.keys().filter(func(k): return String(C[k].get("rule", "")) != "" and not String(C[k]["rule"]).contains("%"))
	if ids.is_empty():
		return {}
	var id := String(ids[randi() % ids.size()])
	return {"type": "wing", "condition": id, "floor": int(C[id].get("from", 2)), "rule": String(C[id]["rule"])}


## The best odds on offer from tonight's company (bet_offers).
static func fact_best_bet(prof, tower: String) -> Dictionary:
	var best := {}
	for r in seated(prof, tower):
		if attitude(prof, r) == "cold":
			continue
		for o in bet_offers(prof, r, tower):
			if best.is_empty() or float(o["odds"]) > float(best["odds"]):
				best = o
	if best.is_empty():
		return {}
	return {"type": "best_bet", "odds": String(TEXT["bet_odds"]) % _num(float(best["odds"])), "odds_value": float(best["odds"]), "bet": bet_name(best, true).to_lower(), "kind": String(best["kind"])}


## True if you know a monster's weakness (slain enough, or told by a rumor).
static func knows_weakness(prof, kind: String) -> bool:
	return Bestiary.level(prof, kind) >= 4 or bool(Bestiary.record(prof, kind).get("told", false))


## A rumor told you a monster's weakness: its Bestiary entry shows it (bestiary.gd "told").
static func tell_weakness(prof, kind: String) -> void:
	if prof == null or not ("bestiary" in prof):
		return
	var r = prof.bestiary.get(kind, {})
	if not (r is Dictionary):
		r = {}
	r["told"] = true
	prof.bestiary[kind] = r


static func _num(x: float) -> String:
	var s := "%.1f" % x
	return s.trim_suffix(".0") if s.ends_with(".0") else s


# --- this visit's offers ----------------------------------------------------------------

## A climber's offers this visit (made once, kept while the visit lasts).
static func _offers(prof, rec: Dictionary, _tower: String) -> Dictionary:
	var st := state(prof)
	var id := String(rec.get("id", ""))
	if not st["offers"].has(id):
		st["offers"][id] = {}
	return st["offers"][id]


# --- wagers -------------------------------------------------------------------------------

## The wagers a climber offers (made once a visit, for the tower chosen on
## the Engine's board): two, by difficulty. Each {kind, tower, floor,
## count, monster, odds}.
static func bet_offers(prof, rec: Dictionary, tower: String) -> Array:
	var tw := _tower_or_last(prof, tower)
	var o := _offers(prof, rec, tw)
	if o.has("bets") and String(o.get("bets_tower", "")) == tw:
		return o["bets"]
	var best := int(prof.record.get("best", {}).get(tw, 0)) if prof != null else 0
	var all: Array = []
	var ahead := randi_range(1, 3)
	all.append({"kind": "floor", "tower": tw, "floor": clampi(maxi(best, 1) + ahead, 2, int(Towers.TOWERS[tw].get("summit", Towers.SUMMIT))), "odds": float(RULES["odds_floor_%d" % ahead])})
	var slain_before: bool = prof != null and Bestiary.record(prof, String(Towers.TOWERS[tw].get("beast_kind", ""))).get("slain", 0) > 0
	all.append({"kind": "beast", "tower": tw, "odds": float(RULES["odds_beast_again" if slain_before else "odds_beast"])})
	all.append({"kind": "dry", "tower": tw, "floor": clampi(maxi(best - 1, 2), 2, 8), "odds": float(RULES["odds_dry"])})
	var kinds: Array = (Towers.TOWERS[tw].get("weights", {}) as Dictionary).keys().filter(func(k): return float(Towers.TOWERS[tw]["weights"][k]) >= 0.8)
	if not kinds.is_empty():
		var many := randf() < 0.5
		all.append({"kind": "slay", "tower": tw, "monster": String(kinds[randi() % kinds.size()]), "count": int(RULES["slay_many" if many else "slay_few"]),
			"odds": float(RULES["odds_slay_high" if many else "odds_slay_low"])})
	all.shuffle()
	var out: Array = all.slice(0, 2 if full_bets(prof, rec) else 1)  # (a plain climber: one wager, unless your title takes bets)
	var bonus := (float(RULES["warm_odds"]) if attitude(prof, rec) == "warm" else 0.0) + float(perks(prof)["odds"])
	for b in out:
		b["odds"] = snappedf(float(b["odds"]) + bonus, 0.05)
		b["by"] = String(rec.get("id", ""))
		b["by_name"] = String(rec.get("name", ""))
	o["bets"] = out
	o["bets_tower"] = tw
	return out


## A wager in words: "Reach floor 6"; with `tower`, "Reach floor 6 (Kraken)".
static func bet_name(b: Dictionary, tower := false) -> String:
	var tw := String(b.get("tower", ""))
	var t: Dictionary = Towers.TOWERS.get(tw, {})
	var beast := String(t.get("beast", ""))
	var mon := Bestiary.name_of(String(b.get("monster", ""))) + "s"
	var f := {"floor": int(b.get("floor", 0)), "tower": String(t.get("name", tw)), "beast": beast, "count": int(b.get("count", 0)), "monster": mon.to_lower()}
	var text := fill_in(String(BETS.get(String(b.get("kind", "")), {}).get("name", "")), f)
	text = text.substr(0, 1).to_upper() + text.substr(1)
	if tower and String(b.get("kind", "")) != "beast":
		text = String(TEXT["bet_in"]) % [text, String(t.get("short", tw))]
	return text


## The stakes on offer (all three; a plain climber without a title that
## takes bets: only the smallest).
static func stakes(prof = null, rec := {}) -> Array:
	var all := [int(RULES["stake_low"]), int(RULES["stake_mid"]), int(RULES["stake_high"])]
	if prof != null and not rec.is_empty() and not full_bets(prof, rec):
		return all.slice(0, 1)
	return all


## What a wager pays if it's won (stake times odds, in the tower's essence).
static func payout(b: Dictionary) -> int:
	return int(round(float(b.get("stake", 0)) * float(b.get("odds", 1.0))))


## Why a wager can't be placed now ("" if it can).
static func bet_why_not(prof, rec: Dictionary, stake: int) -> String:
	var st := state(prof)
	if attitude(prof, rec) == "cold":
		return say("cold_bet")
	if (st["bets"] as Array).size() >= int(RULES["max_bets"]):
		return String(TEXT["bets_full"]) % (st["bets"] as Array).size()
	if not stakes(prof, rec).has(stake):
		return String(TEXT["bet_small"]) % int(RULES["stake_low"])
	if prof.crystals_held() < float(stake):
		return String(TEXT["bet_short"]) % int(ceil(float(stake) - prof.crystals_held()))
	return ""


## Places a wager (one of bet_offers) for `stake` crystals of any kind (your
## biggest first: what was paid is kept, to give back if it's called off).
## "" if placed, else why not.
static func place_bet(prof, rec: Dictionary, offer: Dictionary, stake: int) -> String:
	var why := bet_why_not(prof, rec, stake)
	if why != "":
		return why
	var paid: Dictionary = prof.spend_any(float(stake))
	if paid.is_empty():
		return String(TEXT["bet_short"]) % stake
	var b := offer.duplicate(true)
	b["stake"] = stake
	b["paid"] = paid
	b["running"] = false
	b["count_now"] = 0
	b["drank"] = 0
	b["beast_down"] = false
	state(prof)["bets"].append(b)
	# (an offer taken is gone for this visit)
	var o := _offers(prof, rec, String(offer.get("tower", "")))
	var left: Array = o.get("bets", [])
	for i in left.size():
		if left[i] == offer:
			left.remove_at(i)
			break
	prof.save()
	return ""


## The climb begins from the train (main.gd choose_tower): open wagers run
## on it, and the Entity's log notes them. A new visit begins next time.
static func on_depart(main) -> void:
	var prof = main.profile
	var st := state(prof)
	if st.is_empty():
		return
	st["trips"] = int(st["trips"]) + 1
	st["news"] = []
	for b in st["bets"]:
		b["running"] = true
		b["climbed"] = String(main.tower)
		b["count_now"] = 0
		b["drank"] = 0
		b["beast_down"] = false
		if main.has_method("note_event"):
			main.note_event("rival", String(TEXT["bet_log"]) % [String(b.get("by_name", "")), bet_name(b, true)], Color(1.0, 0.85, 0.5))
	prof.save()


## A foe fell in a climb (main.gd on_enemy_killed): wagers on slaying count it.
static func on_kill(main, e) -> void:
	var st := state(main.profile)
	if st.is_empty():
		return
	for b in st["bets"]:
		if not b.get("running", false):
			continue
		if String(b.get("kind", "")) == "slay" and String(e.kind) == String(b.get("monster", "")):
			b["count_now"] = int(b.get("count_now", 0)) + 1
		if e.has_method("is_boss") and e.is_boss() and not bool(e.get("shade")):
			b["beast_down"] = true


## An item used in a climb (player.gd use_item): a Healing Vial breaks a dry wager.
static func on_item(main, id: String) -> void:
	if main == null or main.get("profile") == null:
		return
	if id != "draught":
		return
	for b in state(main.profile).get("bets", []):
		if b.get("running", false):
			b["drank"] = int(b.get("drank", 0)) + 1


## True if a running wager is won by what happened (the floor reached, in
## its tower).
static func bet_won(b: Dictionary, reached: int) -> bool:
	match String(b.get("kind", "")):
		"floor":
			return reached >= int(b.get("floor", 99))
		"beast":
			return bool(b.get("beast_down", false))
		"dry":
			return reached >= int(b.get("floor", 99)) and int(b.get("drank", 0)) == 0
		"slay":
			return int(b.get("count_now", 0)) >= int(b.get("count", 1))
	return false


## The climb is over (main.gd pay_climb, once a climb): running wagers are
## paid (stake times odds, in the tower's essence) or lost; one on another
## tower is called off and its stake given back. Returns the lines (also
## kept as `news` for the car, and sent to the Entity's log).
static func settle(main) -> Array:
	var prof = main.profile
	var st := state(prof)
	var lines: Array = []
	if st.is_empty():
		return lines
	var keep: Array = []
	for b in st["bets"]:
		if not b.get("running", false):
			keep.append(b)
			continue
		var who := String(b.get("by_name", ""))
		var tw := String(b.get("tower", ""))
		if String(main.tower) != tw:
			var paid: Dictionary = b.get("paid", {})
			for k in paid:
				prof.add_crystal(String(k), float(paid[k]))
			lines.append(String(TEXT["bet_void"]) % [who, load(TRAIN).paid_text(paid)])
			continue
		if bet_won(b, int(main.floor_num)):
			var kind := String(Towers.TOWERS.get(tw, {}).get("essence", "air"))
			var amt := payout(b)
			prof.add_crystal(kind, float(amt))
			lines.append(String(TEXT["bet_won"]) % [who, bet_name(b, true), price_text(kind, amt)])
		else:
			lines.append(String(TEXT["bet_lost"]) % [who, bet_name(b, true)])
	st["bets"] = keep
	if not lines.is_empty():
		st["news"] = lines.duplicate()
		for l in lines:
			if main.has_method("note_event"):
				main.note_event("rival", String(l), Color(1.0, 0.85, 0.5))
	prof.save()
	return lines


## The wagers' lines at the top of the screen in a climb (hud.gd status_chips).
static func hud_lines(prof) -> Array:
	var out: Array = []
	for b in state(prof).get("bets", []):
		if not b.get("running", false):
			continue
		if String(b.get("kind", "")) == "slay":
			out.append(String(TEXT["bet_hud_count"]) % [bet_name(b, true), mini(int(b.get("count_now", 0)), int(b.get("count", 0))), int(b.get("count", 0))])
		else:
			out.append(String(TEXT["bet_hud"]) % bet_name(b, true))
	return out


# --- trading ------------------------------------------------------------------------------

## A climber's trades this visit (made once): their goods follow their
## marks (a tincture of their mark's essence, a charm of it, a piece they
## carry), each for your crystals at the outfitter's price (less a warm
## climber's or your title's share); and one piece of your stash they'd
## buy, for crystals at RULES "buy_share" of its price. Each {"type":
## "give"|"buy", "thing": {...}, "kind", "price"}.
static func trade_offers(prof, rec: Dictionary) -> Array:
	var o := _offers(prof, rec, "")
	if o.has("trade"):
		return o["trade"]
	var Train = load(TRAIN)
	var out: Array = []
	var k := kind_of(rec)
	var off := clampf((float(RULES["warm_off"]) if attitude(prof, rec) == "warm" else 0.0) + float(perks(prof)["off"]), 0.0, 0.5)
	var tid := Flow.tincture_id(k)
	if Items.ITEMS.has(tid):
		var pr: Array = Train.item_price(tid)
		out.append({"type": "give", "thing": {"type": "item", "id": tid}, "kind": String(pr[0]), "price": maxi(1, int(round(float(pr[1]) * (1.0 - off))))})
	var charms: Array = Charms.all().filter(func(id): return Charms.kind(Gear.make(id)) == k)
	if not charms.is_empty():
		var c := Gear.make(String(charms[randi() % charms.size()]))
		out.append({"type": "give", "thing": {"type": "gear", "rec": c}, "kind": Train.gear_kind(c), "price": maxi(1, int(round(float(Train.gear_price(c)) * (1.0 - off))))})
	else:
		for code in rec.get("gear", []):
			var g := Gear.rec(code)
			if Gear.is_gear(g) and Train.can_sell(g):  # (never the basic sword or bow: nobody sells what's given away, basic_gift.gd)
				out.append({"type": "give", "thing": {"type": "gear", "rec": g}, "kind": Train.gear_kind(g), "price": maxi(1, int(round(float(Train.gear_price(g)) * (1.0 - off))))})
				break
	# One piece of yours they'd buy: the stash piece of their essence worth the most, else any.
	var pick := -1
	var pick_v := -1
	for i in prof.chest.size():
		var g = prof.chest[i]
		if not Train.can_sell(g):
			continue  # (nor would they buy yours)
		var v: int = Train.gear_price(g) + (1000 if Train.gear_kind(g) == k else 0)
		if v > pick_v:
			pick_v = v
			pick = i
	if pick >= 0:
		var g2: Dictionary = Gear.rec(prof.chest[pick])
		out.append({"type": "buy", "thing": {"type": "gear", "rec": g2}, "kind": Train.gear_kind(g2), "price": maxi(1, int(round(float(Train.gear_price(g2)) * float(RULES["buy_share"]))))})
	o["trade"] = out
	return out


## A thing in words.
static func thing_name(t: Dictionary) -> String:
	match String(t.get("type", "")):
		"item":
			return String(Items.info(String(t["id"])).get("name", String(t["id"])))
		"gear":
			return Gear.display(t["rec"])
	return "?"


## A trade taken: you pay for their goods (or hand over your piece for their
## crystals). What to say, or why not (`ok` false).
static func trade(prof, player, rec: Dictionary, i: int) -> Dictionary:
	var Train = load(TRAIN)
	if attitude(prof, rec) == "cold":
		return {"ok": false, "text": say("cold_trade")}
	var offers := trade_offers(prof, rec)
	if i < 0 or i >= offers.size() or offers[i].get("done", false):
		return {"ok": false, "text": ""}
	var o: Dictionary = offers[i]
	var t: Dictionary = o["thing"]
	var kind := String(o["kind"])
	var price := int(o["price"])
	var who := String(rec.get("name", ""))
	if String(o["type"]) == "give":
		var why: String = Train.short_of(prof, kind, price)
		if why != "":
			return {"ok": false, "text": why}
		if String(t["type"]) == "item":
			if player != null and Train.supply_room(prof, player, String(t["id"])) <= 0:
				return {"ok": false, "text": TEXT["trade_full"]}
			prof.spend(kind, float(price))
			Train.pack_supply(prof, String(t["id"]), {kind: price})
		else:
			if prof.chest.size() >= Train.CHEST_SIZE and player != null and Train.pack_room(prof, player) <= 0:
				return {"ok": false, "text": TEXT["trade_full"]}
			prof.spend(kind, float(price))
			if prof.chest.size() < Train.CHEST_SIZE:
				prof.chest.append(Gear.rec(t["rec"]))
			else:
				prof.pack.append(Gear.rec(t["rec"]))
		o["done"] = true
		_bump(prof, rec, "traded")
		prof.save()
		return {"ok": true, "text": String(TEXT["trade_done"]) % [who, String(TEXT["trade_bought"]) % thing_name(t)]}
	# They buy your piece.
	var at := -1
	for j in prof.chest.size():
		if Gear.same(prof.chest[j], t["rec"]):
			at = j
			break
	if at < 0:
		return {"ok": false, "text": Rivals.TEXT["trade_short"]}
	prof.chest.remove_at(at)
	prof.add_crystal(kind, float(price))
	o["done"] = true
	_bump(prof, rec, "traded")
	prof.save()
	return {"ok": true, "text": String(TEXT["trade_done"]) % [who, String(TEXT["trade_sold"]) % [thing_name(t), price_text(kind, price)]]}


## One more of something in your history with them (traded, duels...).
static func _bump(prof, rec: Dictionary, key: String, by := 1) -> void:
	var id := String(rec.get("id", ""))
	var met := Rivals.state(prof)
	var r: Dictionary = met.get(id, rec)
	r[key] = int(r.get(key, 0)) + by
	rec[key] = r[key]
	keep(prof, r)


# --- duels ----------------------------------------------------------------------------------

## The stakes a duel can be for, with this climber: crystals, a piece of
## gear (your stash piece nearest in worth to one of theirs), or renown.
## Each {"type", "label", and what's staked}; "ok" false if you can't.
static func duel_stakes(prof, rec: Dictionary) -> Array:
	var Train = load(TRAIN)
	var out: Array = []
	var amt := int(RULES["duel_crystals"])
	var top := ""
	for c in prof.crystals:
		if top == "" or float(c["amount"]) > prof.crystal_total(top):
			top = String(c["kind"])
	var k := top if top != "" else kind_of(rec)
	out.append({"type": "crystals", "kind": k, "amount": amt, "label": String(TEXT["duel_crystals"]) % [amt, Essence.display(k)], "ok": prof.crystal_total(k) >= float(amt)})
	var theirs := {}
	for code in rec.get("gear", []):
		var g := Gear.rec(code)
		if Gear.is_gear(g):
			theirs = g
			break
	if not theirs.is_empty():
		var v: int = Train.gear_price(theirs)
		var mine := -1
		var d := 1 << 30
		for i in prof.chest.size():
			if not Gear.is_gear(prof.chest[i]):
				continue
			var dd: int = absi(Train.gear_price(prof.chest[i]) - v)
			if dd < d:
				d = dd
				mine = i
		var my_rec: Dictionary = Gear.rec(prof.chest[mine]) if mine >= 0 else {}
		out.append({"type": "gear", "theirs": theirs, "mine": my_rec, "ok": mine >= 0,
			"label": String(TEXT["duel_piece"]) % [Gear.display(my_rec) if mine >= 0 else "?", Gear.display(theirs)]})
	var rn := int(RULES["duel_renown"])
	out.append({"type": "renown", "amount": rn, "label": String(TEXT["duel_renown"]) % rn, "ok": true})
	return out


## The event the Arena car fights (arena.gd start, type "duel").
static func duel_event(prof, rec: Dictionary, stake: Dictionary) -> Dictionary:
	var tw := String(prof.last_tower) if Towers.TOWERS.has(String(prof.last_tower)) else Towers.ORDER[0]
	var best := 0
	for t in prof.record.get("best", {}):
		best = maxi(best, int(prof.record["best"][t]))
	var fl := clampi(maxi(int(RULES["duel_floor"]), best), 1, int(RULES["duel_floor_most"]))
	return {"type": "duel", "id": String(rec.get("id", "")), "name": String(TEXT["duel_name"]) % String(rec.get("name", "")),
		"rival": rec.duplicate(true), "stake": stake.duplicate(true), "tower": tw, "floor": fl, "car": "dining"}


## A duel's result, written to the save (arena.gd leave): the stake changes
## hands, renown and your history with them update (the Duelist title's
## count among them). Returns {"lines"}.
static func apply_duel(prof, res: Dictionary, ev: Dictionary) -> Dictionary:
	var rec: Dictionary = ev.get("rival", {})
	var who := String(rec.get("name", ""))
	var stake: Dictionary = ev.get("stake", {})
	var lines: Array = []
	var st := state(prof)
	st["duels"] = int(st["duels"]) + 1
	if res.get("draw", false):
		lines.append(TEXT["duel_draw"])
		prof.save()
		return {"lines": lines}
	var met := Rivals.state(prof)
	var r: Dictionary = met.get(String(rec.get("id", "")), rec)
	var won: bool = res.get("won", false)
	match String(stake.get("type", "")):
		"crystals":
			var k := String(stake["kind"])
			var amt := int(stake["amount"])
			if won:
				prof.add_crystal(k, float(amt))
				lines.append(String(TEXT["duel_won"]) % [who, price_text(k, amt)])
			else:
				var took: float = minf(roundf(float(amt) * float(perks(prof)["toll"])), prof.crystal_total(k))  # (a worn title can halve the toll: titles.gd)
				prof.spend(k, took)
				lines.append(String(TEXT["duel_lost"]) % [who, String(TEXT["duel_lost_takes"]) % price_text(k, int(took))])
		"gear":
			var theirs: Dictionary = stake.get("theirs", {})
			var mine: Dictionary = stake.get("mine", {})
			if won:
				prof.chest.append(Gear.rec(theirs))
				var left: Array = r.get("gear", []).filter(func(c): return not Gear.same(Gear.rec(c), theirs))
				r["gear"] = left
				lines.append(String(TEXT["duel_won"]) % [who, Gear.display(theirs)])
			else:
				for j in prof.chest.size():
					if Gear.same(prof.chest[j], mine):
						prof.chest.remove_at(j)
						break
				var g: Array = r.get("gear", [])
				g.append(Gear.code(mine))
				r["gear"] = g
				lines.append(String(TEXT["duel_lost"]) % [who, String(TEXT["duel_lost_takes"]) % ("your " + Gear.display(mine))])
		"renown":
			var n := int(stake.get("amount", 0))
			if won:
				var got: Dictionary = Renown.earn(prof, n, String(TEXT["duel_deed"]) % who)
				lines.append(String(TEXT["duel_won"]) % [who, Renown.TEXT["earned"] % int(got["amount"])])
			else:
				var toll := int(round(float(n) * float(perks(prof)["toll"])))
				var lost: int = Rivals.renown_cost(prof, toll, String(TEXT["duel_deed_lost"]) % [who, toll])
				lines.append(String(TEXT["duel_lost"]) % [who, String(TEXT["duel_lost_takes"]) % (String(TEXT["duel_renown"]) % lost)])
	if won:
		r["duels_won"] = int(r.get("duels_won", 0)) + 1
	else:
		r["duels_lost"] = int(r.get("duels_lost", 0)) + 1
	if not r.has("id"):
		r["id"] = String(rec.get("id", ""))
	keep(prof, r)
	if won:
		var got2: Dictionary = Renown.earn(prof, int(RULES["duel_win_renown"]), String(TEXT["duel_deed"]) % who)
		lines.append(Renown.TEXT["earned"] % int(got2["amount"]))
		for t in got2.get("titles", []):
			lines.append(Renown.TEXT["title_up"] % Renown.title_name(String(t)))
	prof.save()
	return {"lines": lines}
