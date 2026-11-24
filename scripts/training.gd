extends RefCounted
## TRAINING: the required start, the Noble's Grace, advanced and mark
## training, and what training's essence does (the stations' gym and the
## first tournament; the travelling Tournament Manager is tournaments.gd).
##
## THE REQUIRED START. A climber made with the new start (start_pages.gd
## Begin: `require`) arrives at their home station, not in a tower. The
## towers stay closed (`closed`: the engine's lever is locked, main.gd
## depart refuses) until the Noble grants them THE GRACE. To earn it:
##   basic training  ONE SESSION at the gym (tutorial.gd): twelve steps in
##                   one sitting, every way to move, attack and parry
##                   (walking, jumping, rolling, striking, the finisher,
##                   swapping, the bow's full draw, the off-hand and its
##                   power, parrying, blocking, the belt). Left part way, it
##                   resumes where you stopped. Skippable only after the Grace,
##                   or by a player who made a climber before on this device.
##   the first       FIRST: one tournament of three rounds at the home
##   tournament      station: low-level monsters (the home station's
##                   "starter" creatures, tournaments.gd LOCATIONS), then a
##                   human champion fighter (no marks). Nobody dies.
## The Grace comes win or lose; each round won adds a reward (REWARDS):
##   0 the Grace only; 1 + a Healing Vial; 2 + a recall scroll; 3 + one Fine
##   (uncommon) weapon or armour piece of the type you fought with most in
##   the tournament (into your stash); flawless (no damage taken all
##   tournament) + one essence tincture of each kind, from the Noble.
##
## TRAINING'S ESSENCE (RATES). Basic training (a share for each step done),
## medal drills and the first
## tournament give a quarter of the usual essence, into the body only (no
## marks, no crystals), and before the first mark what each body part did
## is kept (`state.soak`, at SOAK_SHARE): main.gd seeds the first climb's
## soak with it, so training decides where the first mark appears.
## Advanced and mark training and later tournaments give half, flowing the
## natural way (body and marks).
##
## LATER. Basic training can be gone through again any time. ADVANCED training opens
## in TIERS by the titles the Noble has granted you; MARK training (partners:
## dummies, summoned creatures, human rivals) opens with the first mark (or
## once Unbound). Each lesson costs a small fee of the essence that fits it
## (crystals of that kind; "mark": your strongest mark's own kind), and the
## first time each is done it pays a little renown.
##
## Every name, number and word is here (and in the Data editor).

const Renown := preload("res://scripts/renown.gd")
const Titles := preload("res://scripts/titles.gd")
const Gear := preload("res://scripts/gear.gd")
const Essence := preload("res://scripts/essence.gd")
const Bonds := preload("res://scripts/bonds.gd")
const Unbound := preload("res://scripts/unbound.gd")
const Flow := preload("res://scripts/essence_flow.gd")
const Items := preload("res://scripts/items.gd")

## The Noble's Grace: what lets a climber into the towers.
static var GRACE := {"name": "the Noble's Grace", "short": "The Grace"}

## Essence in training: `rate` of the usual amount; `body` true for the
## body only (else it flows the natural way, body and marks). By the arena's
## event type. "lesson": the usual essence a lesson done gives (of the
## lesson's own kind); "round": the usual essence for a round won against a
## climber (of the arena's tower kind; a monster gives what it would in a
## tower). SOAK_SHARE: of what each body part did, the share kept toward the
## first mark.
static var RATES := {
	"basics": {"rate": 0.25, "body": true},
	"lesson": {"rate": 0.25, "body": true},
	"drill": {"rate": 0.25, "body": true},
	"first": {"rate": 0.25, "body": true},
	"advanced": {"rate": 0.5, "body": false},
	"tourney": {"rate": 0.5, "body": false},
}
static var USUAL := {"lesson": 12.0, "round": 8.0}
static var SOAK_SHARE := 0.25

## THE FIRST TOURNAMENT: three rounds at the home station. A round is
## "starter": n (the home station's starter creatures, tournaments.gd
## LOCATIONS), or "champion" (CHAMPION: a human fighter with no marks,
## "hp" times a climber's health). "floor": how tough it all is.
## "round_renown": renown for each round won.
static var FIRST := {"id": "first", "name": "First Tournament", "floor": 1, "round_renown": 2,
	"rounds": [{"starter": 0}, {"starter": 1}, {"champion": true, "hp": 0.85}]}
## The champion of the first tournament: a placeholder name, their weapon
## and armour (rivals.gd draws them like any climber).
static var CHAMPION := {"name": "(The grounds' champion)", "weapon": "sword", "armor": "chain"}

## The first tournament's rewards, added row by row: rounds won ("won"), or
## "flawless" (no damage taken all tournament). "give": vial (a Healing
## Vial for your belt), scroll (a recall scroll), piece (a Fine weapon or
## armour piece of the type you fought with most), tinctures (one essence
## tincture of each kind, from the Noble).
static var REWARDS := [
	{"won": 1, "give": "vial"},
	{"won": 2, "give": "scroll"},
	{"won": 3, "give": "piece"},
	{"flawless": true, "give": "tinctures"},
]
## The rarity of the piece (Fine is the one above Common: "uncommon").
static var PIECE_RARITY := "fine"
## No weapon used (fists, spells): armour of the kind worn, else this.
static var PIECE_ARMOR := "leather"

## ADVANCED training's tiers: each opens once the Noble has granted you a
## title of at least `title_rank` (renown.gd TITLES "rank"). `fee`: crystals
## of the lesson's essence for each try (a worn title's Training cut
## applies); `renown`: the first time a lesson of the tier is done.
static var TIERS := [
	{"name": "First tier", "title_rank": 0, "fee": 2, "renown": 2},
	{"name": "Second tier", "title_rank": 1, "fee": 4, "renown": 3},
	{"name": "Third tier", "title_rank": 4, "fee": 6, "renown": 4},
]

## Advanced and mark lessons (the arena runs them as lessons: stations.gd's
## kinds, plus "jump", "strike", "shoot", "cast_foes" and "spar"). Each has
## its tier, the essence its fee is paid in ("mark": your strongest mark's
## kind), and for mark training its partner ("dummies", "creatures",
## "rivals"). "perfect": only perfect parries count. "marks": a sparring
## rival's marks (and "step"), who yields when beaten.
static var ADVANCED := {
	"belt": {"name": "The belt wheel", "goal": "Use %d item from your belt.", "kind": "belt", "need": 1, "time": 60, "give": ["draught", "tonic"], "hurt": 0.6,
		"tier": 0, "essence": "water", "tips": ["belt_wheel", "belt"],
		"say": "Tap {item} to use your current item. Hold {item} and the wheel opens, the world slows: point at another and let go to choose it."},
	"cure": {"name": "States and cures", "goal": "You're soaked. Drink the Cleansing Tonic before it wears off.", "kind": "cure", "state": "soaked", "seconds": 25.0, "time": 24, "give": ["tonic"],
		"tier": 0, "essence": "water", "tips": ["climber_states", "state_soaked"],
		"say": "Some blows leave a state on you. The line at the top names it, counts it down and says what cures it. A Cleansing Tonic cures any."},
	"wall": {"name": "Cracked walls", "goal": "Break the cracked wall: the last blow of a combo breaks it.", "kind": "wall", "time": 60,
		"tier": 1, "essence": "stone", "tips": [],
		"say": "Dust falls from a cracked wall. A light blow knocks hollow; the finisher, the last blow of a combo, breaks it. Something waits behind them."},
	"ward": {"name": "The ward and the task", "goal": "Light the %d braziers: stand by each until it catches.", "kind": "ward", "pieces": 2, "time": 75,
		"tier": 1, "essence": "fire", "tips": ["ward", "stair"],
		"say": "On most floors the stair is warded until the floor's task is done. The line at the top names the task and counts it; an arrow points at what's left."},
	"perfect": {"name": "The perfect parry", "goal": "Parry %d blows perfectly: right as the glint flashes.", "kind": "parry", "perfect": true, "need": 2, "time": 60, "foes": ["knight"], "weak": 0.25,
		"tier": 2, "essence": "iron", "tips": [],
		"say": "A parry right on the glint is perfect: the attacker reels longer. Only perfect ones count here. Wait for the flash, then {parry}."},
	"crowd": {"name": "Fighting a crowd", "goal": "Fell %d foes without being knocked down.", "kind": "kills", "need": 6, "time": 90, "foes": ["slime", "archer", "bat"], "weak": 0.5,
		"tier": 2, "essence": "blade", "tips": [],
		"say": "Never stand still in a crowd. Strike, roll out, strike again. Keep the archers in sight."},
}
static var ADVANCED_ORDER := ["belt", "cure", "wall", "ward", "perfect", "crowd"]
static var MARK := {
	"cast": {"name": "Casting a mark", "goal": "Hit a dummy with a spell or technique.", "kind": "cast", "need": 1, "dummies": 3, "time": 60,
		"tier": 0, "essence": "mark", "partner": "dummies", "tips": ["casting", "spell_wheel"],
		"say": "Your marks cast: {cast}. Hold a mark's button to choose a spell from its wheel, tap it to cast. Hit a dummy."},
	"spread": {"name": "Many with one cast", "goal": "Hit %d dummies with a single cast.", "kind": "cast", "need": 3, "dummies": 6, "time": 60,
		"tier": 0, "essence": "mark", "partner": "dummies", "tips": [],
		"say": "Some spells reach more than one. Find the one that does, stand where the dummies bunch, and cast."},
	"creatures": {"name": "Spells on creatures", "goal": "Strike %d creatures with your spells.", "kind": "cast_foes", "need": 3, "time": 75, "foes": ["slime", "slime", "bat"], "weak": 0.4,
		"tier": 1, "essence": "mark", "partner": "creatures", "tips": [],
		"say": "Summoned creatures, and they move. Lead them with your spells: cast where they're going, not where they are."},
	"pack": {"name": "A pack at once", "goal": "Strike %d creatures with one cast.", "kind": "cast_foes", "at_once": true, "need": 2, "time": 75, "foes": ["slime", "slime", "slime"], "weak": 0.4,
		"tier": 1, "essence": "mark", "partner": "creatures", "tips": [],
		"say": "Let them gather, then cast once into the middle of them."},
	"spar": {"name": "Sparring with a rival", "goal": "Spar with a climber of one mark until they yield.", "kind": "spar", "marks": 1, "step": 1, "time": 120,
		"tier": 2, "essence": "mark", "partner": "rivals", "tips": [],
		"say": "A climber with a mark of their own. Watch their glints, answer their spells with yours. They yield when beaten."},
	"spar_two": {"name": "Sparring with two marks", "goal": "Spar with a climber of two marks until they yield.", "kind": "spar", "marks": 2, "step": 2, "time": 150,
		"tier": 2, "essence": "mark", "partner": "rivals", "tips": [],
		"say": "Two marks, two kinds of spell. Learn which glint means which, and when to roll."},
}
static var MARK_ORDER := ["cast", "spread", "creatures", "pack", "spar", "spar_two"]

static var TEXT := {
	"grace": "The Noble's Grace",
	"grace_short": "Grace",
	"grace_have": "Granted: the towers are open to you.",
	"grace_not": "Not yet: the towers are closed to you.",
	"grace_how": "Finish basic training at the gym (one session), then compete in your first tournament. The Grace comes win or lose.",
	"grace_what": "The Noble's leave to enter the towers and take a mark. Every climber needs it.",
	"grace_step_lessons": "Basic training: %d of %d steps",
	"grace_step_first": "Your first tournament",
	"grace_granted": "The Noble grants you the Grace. The towers are open to you.",
	"grace_banner": "The Noble's Grace is yours",
	"closed": "The towers are closed until the Noble grants you the Grace.",
	"closed_short": "Needs the Grace",
	"closed_how": "Finish basic training at the gym (one session), then your first tournament at the tournament grounds.",
	"basic": "Basic training",
	"basic_note": "One session: every way to move, attack and parry. Required for the Noble's Grace.",
	"basic_note_done": "Go through it again any time.",
	"no_skip": "Required for the Grace: it can't be skipped.",
	"start_basics": "Training",
	"advanced": "Advanced training",
	"advanced_note": "Opens in tiers by the titles the Noble has granted you. Each try costs a small fee of the essence that fits it.",
	"mark_training": "Mark training",
	"mark_note": "Train your marks with dummies, summoned creatures and human rivals.",
	"mark_locked": "Opens with your first mark",
	"tier_locked": "Opens with a title of rank %s or higher",
	"tier_locked_any": "Opens with your first title from the Noble",
	"tier_open": "%s: open",
	"partner": "Partner: %s",
	"partners": {"dummies": "training dummies", "creatures": "summoned creatures", "rivals": "a human rival"},
	"fee_kind": "%d %s crystals",
	"needs_kind": "needs %d more %s crystals",
	"adv_pays": "First time: +%d renown. Essence: half the usual, flowing into you.",
	"adv_done": "Done",
	"adv_todo": "Not done yet",
	"deed_adv": "Finished %s (training)",
	"result_adv": "Training done: %s",
	"first": "First Tournament",
	"first_line": "Three rounds for the Noble's Grace",
	"first_sub": "Low-level monsters, then a human champion. Nobody dies. The Grace comes win or lose.",
	"first_locked": "Finish basic training first",
	"first_done": "Done: the Grace is yours",
	"first_enter": "Enter your first tournament",
	"first_rounds": "Rounds",
	"first_round_starter": "Round %d: %s",
	"first_round_champion": "Round %d: %s, a champion fighter",
	"first_rewards": "Rewards (each round won adds one)",
	"first_reward_0": "Win or lose: the Noble's Grace",
	"reward_row": "%s: %s",
	"won_n": "%d won",
	"flawless": "Flawless",
	"give": {"vial": "a Healing Vial", "scroll": "a recall scroll", "piece": "a Fine weapon or armour piece of the type you fight with most", "tinctures": "one essence tincture of each kind, from the Noble"},
	"got_vial": "A Healing Vial, packed for your next climb",
	"got_scroll": "A recall scroll, packed for your next climb",
	"got_piece": "%s, for the way you fought: in your stash",
	"got_piece_pack": "%s, for the way you fought: in your pack",
	"got_tinctures": "Flawless! The Noble adds a tincture of each kind: drink them from your book's Essence page, or carry them",
	"result_first": "First tournament: %d of %d rounds won",
	"deed_grace": "Earned the Noble's Grace",
	"deed_first_rounds": "Won %d rounds of the first tournament",
	"essence_body": "Training's essence: +%d into your body (a quarter of the usual)",
	"essence_flow": "Training's essence: +%d into you (half the usual)",
	"hud_jumps": "Jumps %d of %d",
	"hud_struck": "Strikes %d of %d",
	"hud_shots": "Shots on target %d of %d",
	"hud_perfect": "Perfect parries %d of %d",
	"hud_foes": "Creatures struck %d of %d",
	"hud_spar": "Spar: make them yield",
	"start_advanced": "Training",
	"start_first": "First tournament",
	# The Entity's "What should I do next?" (entity_talk.gd hints).
	"hint_lessons": "The towers are closed until the Noble grants you the Grace. Start at the gym: basic training, one session ({n} steps left).",
	"hint_first": "Basic training is done. Now your first tournament, at the tournament grounds: the Grace comes win or lose.",
	# The Entity's talk ("How does it work?": training_facts).
	"talk_grace_have": "You have it.",
	"talk_grace_not": "You don't have it yet: {left}.",
	"talk_left_lessons": "{n} steps of basic training left",
	"talk_left_first": "your first tournament is next",
}


# --- the state -------------------------------------------------------------------------------

## The climber's training (kept in renown.gd's state, which saves with them).
static func state(profile) -> Dictionary:
	var r := Renown.state(profile)
	if not (r.get("training") is Dictionary):
		r["training"] = {}
	var t: Dictionary = r["training"]
	var defaults := {"required": false, "grace": false, "first": {}, "soak": {}, "done": {}, "prizes": {}}
	for k in defaults:
		if not t.has(k) or typeof(t[k]) != typeof(defaults[k]):
			t[k] = defaults[k].duplicate() if defaults[k] is Dictionary else defaults[k]
	return t


## A climber made with the new start must train first (start_pages.gd Begin).
static func require(profile) -> void:
	state(profile)["required"] = true


static func required(profile) -> bool:
	return profile != null and bool(state(profile)["required"])


static func has_grace(profile) -> bool:
	return profile != null and bool(state(profile)["grace"])


## The towers are closed: a climber who must train hasn't the Grace yet.
static func closed(profile) -> bool:
	return required(profile) and not has_grace(profile)


## Between climbs at a station before the first climb (main.gd await_tower:
## such a climber is on the train, not choosing a tower on the title).
static func lives_on_train(profile) -> bool:
	return required(profile) and not bool(profile.regarded)


## Basic training done: its one session done or skipped (tutorial.gd; old
## saves: the six separate lessons it replaced, every one done).
static func basic_done(profile) -> bool:
	return load("res://scripts/tutorial.gd").passed(profile)


## Steps of basic training still to do.
static func basic_left(profile) -> int:
	return load("res://scripts/tutorial.gd").steps_left(profile)


## Lessons may be skipped: never before the Grace.
static func can_skip(profile) -> bool:
	return not closed(profile)


## The first tournament can be entered: basic training done, not yet held.
static func first_open(profile) -> bool:
	return closed(profile) and basic_done(profile)


static func first_done(profile) -> bool:
	return not state(profile)["first"].is_empty()


## What each body part did in training, kept toward the first mark
## (main.gd seeds the first climb's soak with it).
static func first_soak(profile) -> Dictionary:
	if profile == null or bool(profile.regarded):
		return {}
	return state(profile)["soak"].duplicate()


# --- the first tournament ----------------------------------------------------------------------

## The first tournament's rounds, filled in for a station (its starter
## creatures): [{"monsters": [...]}, ..., {"champion": true, ...}].
static func first_rounds(station: String) -> Array:
	var T = load("res://scripts/tournaments.gd")
	var starter: Array = T.location(station).get("starter", [["slime", "slime"], ["slime", "archer"]])
	var out: Array = []
	for rd in FIRST["rounds"]:
		var one: Dictionary = rd.duplicate(true)
		if rd.has("starter"):
			var i := clampi(int(rd["starter"]), 0, starter.size() - 1)
			one["monsters"] = (starter[i] as Array).duplicate()
			one.erase("starter")
		out.append(one)
	return out


## A round of the first tournament in words.
static func round_text(i: int, rd: Dictionary) -> String:
	if bool(rd.get("champion", false)):
		return String(TEXT["first_round_champion"]) % [i + 1, String(CHAMPION["name"])]
	var names: Array = []
	var counts := {}
	for k in rd.get("monsters", []):
		counts[k] = int(counts.get(k, 0)) + 1
	for k in counts:
		var nm := String(k).capitalize()
		names.append(nm if int(counts[k]) == 1 else "%d %ss" % [counts[k], nm.to_lower()])
	return String(TEXT["first_round_starter"]) % [i + 1, " and ".join(names)]


## The champion as a rival record for the arena (rivals.gd body_data): a
## climber's look, their weapon and armour, no marks.
static func champion_record(rivals) -> Dictionary:
	var rec := {"id": "champion", "name": String(CHAMPION["name"]), "weapon": String(CHAMPION["weapon"]), "bonds": [], "gear": []}
	if rivals != null:
		rec = rivals.new_rival(1, "")
		rec["name"] = String(CHAMPION["name"])
		rec["weapon"] = String(CHAMPION["weapon"])
		rec["bonds"] = []
		var arm := Gear.make(String(CHAMPION["armor"]))
		rec["gear"] = [Gear.code(arm)] if not arm.is_empty() else []
	return rec


## The reward rows a result earns (rounds won, flawless).
static func rewards_for(rounds: int, flawless: bool) -> Array:
	var out: Array = []
	for row in REWARDS:
		if bool(row.get("flawless", false)):
			if flawless:
				out.append(String(row["give"]))
		elif rounds >= int(row.get("won", 99)):
			out.append(String(row["give"]))
	return out


## The piece the first tournament gives: a Fine weapon of the type used
## most (`used`: weapon id -> blows landed), or with no weapon used (fists,
## spells) Fine armour of the kind worn (`armor`), else PIECE_ARMOR.
static func reward_piece(used: Dictionary, armor := "") -> Dictionary:
	var best := ""
	var most := 0
	for w in used:
		if String(w) == "fists" or not Gear.is_gear(String(w)):
			continue
		if int(used[w]) > most:
			most = int(used[w])
			best = String(w)
	if best == "":
		best = armor if Gear.is_gear(armor) else PIECE_ARMOR
	return Gear.make(best, PIECE_RARITY, Gear.roll_traits(best, PIECE_RARITY))


## A gift packed for the next climb (putting it back gives nothing for it).
static func _gift(profile, id: String) -> void:
	load("res://scripts/train.gd").pack_supply(profile, id, {"air": 0})


## The first tournament is over (stations.gd apply_result): the Grace,
## renown for the rounds won and the rewards. `res`: rounds, flawless,
## used (weapon id -> blows), armor. Returns the lines to show.
static func apply_first(profile, res: Dictionary) -> Array:
	var lines: Array = []
	var st := state(profile)
	var total := (FIRST["rounds"] as Array).size()
	var rounds := clampi(int(res.get("rounds", 0)), 0, total)
	var flawless: bool = bool(res.get("flawless", false)) and rounds >= total
	var had := has_grace(profile)
	st["grace"] = true
	lines.append(String(TEXT["result_first"]) % [rounds, total])
	if not had:
		lines.append(String(TEXT["grace_granted"]))
	var gives := rewards_for(rounds, flawless) if st["first"].is_empty() else []
	for g in gives:
		match g:
			"vial":
				_gift(profile, "draught")
				lines.append(String(TEXT["got_vial"]))
			"scroll":
				_gift(profile, "scroll")
				lines.append(String(TEXT["got_scroll"]))
			"piece":
				var pc := reward_piece(res.get("used", {}), String(res.get("armor", "")))
				if not pc.is_empty():
					if profile.chest.size() < int(load("res://scripts/train.gd").CHEST_SIZE):
						profile.chest.append(pc)
						lines.append(String(TEXT["got_piece"]) % Gear.display(pc))
					else:
						profile.pack.append(pc)
						lines.append(String(TEXT["got_piece_pack"]) % Gear.display(pc))
			"tinctures":
				for id in Flow.tinctures():
					_gift(profile, String(id))
				lines.append(String(TEXT["got_tinctures"]))
	if st["first"].is_empty():
		st["first"] = {"rounds": rounds, "flawless": flawless, "rewards": gives}
	var gain := int(FIRST.get("round_renown", 0)) * rounds
	var got := Renown.earn(profile, gain, String(TEXT["deed_grace"]) if not had else String(TEXT["deed_first_rounds"]) % rounds)
	if gain > 0:
		lines.append(Renown.TEXT["earned"] % gain if Renown.TEXT.has("earned") else "+%d renown" % gain)
	if String(got.get("rank_up", "")) != "":
		lines.append(Renown.TEXT["rank_up"] % got["rank_up"])
	return lines


# --- advanced and mark training ------------------------------------------------------------------

## An advanced or mark lesson ({} if none).
static func lesson(id: String) -> Dictionary:
	if ADVANCED.has(id):
		return ADVANCED[id]
	return MARK.get(id, {})


static func is_mark(id: String) -> bool:
	return MARK.has(id)


## The highest title rank granted (-1 with no title).
static func title_rank(profile) -> int:
	var best := -1
	for tid in Renown.titles(profile):
		best = maxi(best, int(Renown.TITLES.get(tid, {}).get("rank", 0)))
	return best


static func tier_open(profile, tier: int) -> bool:
	if tier < 0 or tier >= TIERS.size():
		return false
	return title_rank(profile) >= int(TIERS[tier].get("title_rank", 0))


## Mark training needs a mark (or the techniques of the Unbound).
static func marked(profile) -> bool:
	return profile != null and (not profile.bonds.is_empty() or Unbound.is_on(profile))


## The kind a lesson's fee is paid in ("mark": the strongest mark's kind).
static func fee_kind(profile, id: String) -> String:
	var k := String(lesson(id).get("essence", "air"))
	if k != "mark":
		return k
	var best := ""
	var most := -1.0
	if profile != null:
		for part in profile.bonds:
			var info: Dictionary = profile.bonds[part]
			if float(info.get("xp", 0.0)) > most:
				most = float(info.get("xp", 0.0))
				best = String(Bonds.BONDS.get(String(info.get("id", "")), {}).get("affinity", ""))
	return best if Essence.KINDS.has(best) else "air"


## A lesson's fee: its tier's, less a worn title's Training cut.
static func fee(profile, id: String) -> int:
	var d := lesson(id)
	if d.is_empty():
		return 0
	var base := int(TIERS[clampi(int(d.get("tier", 0)), 0, TIERS.size() - 1)].get("fee", 0))
	var cut := clampf(Titles.num(profile, "gym", "fee_cut"), 0.0, 1.0) if profile != null else 0.0
	return maxi(0, int(round(float(base) * (1.0 - cut))))


## Why a lesson can't be begun ("" if it can).
static func why_not(profile, id: String) -> String:
	var d := lesson(id)
	if d.is_empty():
		return "?"
	if closed(profile):
		return String(TEXT["closed"])
	if is_mark(id) and not marked(profile):
		return String(TEXT["mark_locked"])
	var tier := int(d.get("tier", 0))
	if not tier_open(profile, tier):
		return locked_text(tier)
	var f := fee(profile, id)
	var k := fee_kind(profile, id)
	if f > 0 and profile.crystal_total(k) < float(f):
		return String(TEXT["needs_kind"]) % [f - int(profile.crystal_total(k)), Essence.display(k)]
	return ""


static func locked_text(tier: int) -> String:
	var need := int(TIERS[clampi(tier, 0, TIERS.size() - 1)].get("title_rank", 0))
	return String(TEXT["tier_locked_any"]) if need <= 0 else String(TEXT["tier_locked"]) % Renown.rank_name(need)


static func lesson_goal(id: String) -> String:
	var d := lesson(id)
	var goal := String(d.get("goal", ""))
	if not goal.contains("%"):
		return goal
	match String(d.get("kind", "")):
		"ward":
			return goal % int(d.get("pieces", 2))
	return goal % int(d.get("need", 1))


static func done(profile, id: String) -> bool:
	return int(state(profile)["done"].get(id, 0)) > 0


## An advanced or mark lesson's result (stations.gd apply_result).
static func apply_advanced(profile, res: Dictionary) -> Array:
	var id := String(res.get("id", ""))
	var d := lesson(id)
	var lines: Array = []
	if d.is_empty():
		return lines
	if not bool(res.get("done", false)):
		if res.has("why"):
			lines.append(String(res["why"]))
		lines.append(load("res://scripts/stations.gd").TEXT["result_lesson_not"] % String(d.get("name", id)))
		return lines
	lines.append(String(TEXT["result_adv"]) % String(d.get("name", id)))
	var st := state(profile)
	if not done(profile, id):
		st["done"][id] = 1
		var gain := int(TIERS[clampi(int(d.get("tier", 0)), 0, TIERS.size() - 1)].get("renown", 0))
		var got := Renown.earn(profile, gain, String(TEXT["deed_adv"]) % String(d.get("name", id)))
		if gain > 0:
			lines.append("+%d renown" % gain)
		if String(got.get("rank_up", "")) != "":
			lines.append(Renown.TEXT["rank_up"] % got["rank_up"])
	return lines


# --- training's essence ------------------------------------------------------------------------------

## What an arena result's essence does (stations.gd apply_result): a share
## of the usual amount (RATES), into the body only or the natural way; and
## before the first mark, what each part did is kept toward it. Lines.
static func settle(profile, res: Dictionary) -> Array:
	var lines: Array = []
	var how: Dictionary = RATES.get(String(res.get("type", "")), {})
	if how.is_empty() or profile == null:
		return lines
	var soak: Dictionary = res.get("soak", {})
	if not bool(profile.regarded) and not Unbound.is_on(profile):
		var kept: Dictionary = state(profile)["soak"]
		for part in soak:
			if part in Bonds.PARTS and float(soak[part]) > 0.0:
				kept[part] = float(kept.get(part, 0.0)) + float(soak[part]) * SOAK_SHARE
	var scaled := {}
	var total := 0.0
	for k in res.get("essence", {}):
		var v := float(res["essence"][k]) * float(how.get("rate", 0.0))
		if v > 0.0 and Essence.KINDS.has(String(k)):
			scaled[k] = v
			total += v
	if total <= 0.0:
		return lines
	if bool(how.get("body", true)):
		pour_body(profile, scaled, soak)
		lines.append(String(TEXT["essence_body"]) % maxi(1, int(round(total))))
	else:
		lines.append(String(TEXT["essence_flow"]) % maxi(1, int(round(total))))
		lines.append_array(profile.pour(scaled, soak, 0.0)["lines"])
	return lines


## Essence into the body only: density, settled in the parts that did the
## work, and the unmarked parts' soak (never the marks). An unmarked climber
## (or the Unbound, whose essence is all the body's) pours the natural way,
## which for them is the body alone.
static func pour_body(profile, essence: Dictionary, soak: Dictionary) -> void:
	if profile.bonds.is_empty() or Unbound.is_on(profile):
		profile.pour(essence, soak, 0.0)
		return
	var style: Dictionary = profile.natural_style(soak)
	var style_total := 0.0
	for part in style:
		style_total += maxf(0.0, float(style[part]))
	var body := 0.0
	for kind in essence:
		var b := float(essence[kind])
		if b <= 0.0:
			continue
		body += b
		profile.density[kind] = float(profile.density.get(kind, 0.0)) + b
		profile.tally[kind] = float(profile.tally.get(kind, 0.0)) + b
		if style_total > 0.0:
			for part in style:
				var pd: Dictionary = profile.part_density.get(part, {})
				pd[kind] = float(pd.get(kind, 0.0)) + b * maxf(0.0, float(style[part])) / style_total
				profile.part_density[part] = pd
	if style_total <= 0.0 or body <= 0.0:
		return
	for part in style:
		if profile.bonds.has(part) or not part in Bonds.PARTS:
			continue
		var gain: float = profile.soak_gain(part, body * maxf(0.0, float(style[part])) / style_total)
		profile.soak[part] = minf(profile.NEW_MARK_SOAK, float(profile.soak.get(part, 0.0)) + gain)


# --- the Entity ----------------------------------------------------------------------------------

## "What should I do next?" while the towers are closed ("" otherwise).
static func hint(profile) -> String:
	if not closed(profile):
		return ""
	var left := basic_left(profile)
	if left > 0:
		return String(TEXT["hint_lessons"]).replace("{n}", str(left))
	return String(TEXT["hint_first"])


## The facts for the Entity's talk about training and the Grace.
static func talk_facts(profile) -> Dictionary:
	var T = load("res://scripts/tournaments.gd")
	var S = load("res://scripts/stations.gd")
	var f := {"lessons": str(S.LESSON_ORDER.size()), "steps": str(load("res://scripts/tutorial.gd").count()), "rounds": str((FIRST["rounds"] as Array).size()),
		"quarter": "%d%%" % int(round(float(RATES["first"]["rate"]) * 100.0)), "half": "%d%%" % int(round(float(RATES["tourney"]["rate"]) * 100.0)),
		"tiers": str(TIERS.size()), "manager": String(T.MANAGER["name"]), "grace_line": "", "manager_line": ""}
	if profile == null:
		return f
	if not required(profile) or has_grace(profile):
		f["grace_line"] = String(TEXT["talk_grace_have"])
	else:
		var left := basic_left(profile)
		var what := String(TEXT["talk_left_lessons"]).replace("{n}", str(left)) if left > 0 else String(TEXT["talk_left_first"])
		f["grace_line"] = String(TEXT["talk_grace_not"]).replace("{left}", what)
	f["manager_line"] = T.where_line(profile)
	return f
