extends RefCounted
## TITLES' SOCIAL BENEFITS: what the title you wear does for you with the
## people around the towers. Only the worn title counts (renown.gd worn),
## so choosing which to wear is a real choice. The titles themselves (their
## names, ranks and deeds) are renown.gd TITLES; the Noble grants them
## (noble.gd, the station's "noble" stop).
##
## SOCIAL is keyed by title id; each title lists some of four groups, each
## with "text" (what its card says, plainly) and its numbers:
##   rivals     other climbers in the towers (rivals.gd), and later the
##              Dining car's fellow climbers (rival_terms below is the hook):
##                friendly   true: they're friendlier to trade with
##                trade_ask  what they ask in a swap, as a share of the usual
##                team       how much likelier an offer to team up is
##                toll       the toll a climber who beats you in a duel takes, as a share
##                bets       true: they accept bets (the Dining car will read it)
##   gym        a station's Training (stations.gd DRILLS):
##                fee_cut    a share off the medal drills' fee (1 = free)
##                extra      true: the extra drills open
##   tourney    the tournament master (stations.gd BRACKETS):
##                early      brackets open this many ranks sooner
##                prize      a share more on a bracket's prize (renown and crystals)
##                fee_cut    a share off the entry fee
##   outfitter  the Outfitter's Car (train.gd, shop.gd):
##                discount   a share off everything he sells
##                today      true: today's piece comes a rarity higher
##                first_look more Fine-or-better pieces on his rail, kept for you
##              (his upgrade tree, outfitter.gd, is his own: some of its nodes
##              need a title granted; a worn title's discount and the tree's
##              add up to its "discount_cap" at most, never more)
## A title not listed has no benefits. Every word and number is here (and in
## the Data editor: "Titles' benefits").

const Renown := preload("res://scripts/renown.gd")

## The groups, in the order a card lists them: [id, name].
static var GROUPS := [["rivals", "Rival climbers"], ["gym", "Training"], ["tourney", "Tournament masters"], ["outfitter", "The outfitter"]]

static var SOCIAL := {
	"newcomer": {
		"outfitter": {"text": "He takes 3% off everything he sells.", "discount": 0.03},
		"gym": {"text": "Medal drills cost half.", "fee_cut": 0.5},
	},
	"trainee": {
		"gym": {"text": "Medal drills are free, and the extra drills open.", "fee_cut": 1.0, "extra": true},
		"rivals": {"text": "Climbers trade a little kinder: they ask a tenth less.", "friendly": true, "trade_ask": 0.9},
	},
	"contender": {
		"tourney": {"text": "Brackets open a rank sooner, and entry costs half.", "early": 1, "fee_cut": 0.5},
		"rivals": {"text": "Climbers take your bets.", "bets": true},
	},
	"beastfeller": {
		"outfitter": {"text": "Today's piece comes a rarity higher.", "today": true},
		"rivals": {"text": "A climber who beats you in a duel takes half the toll.", "toll": 0.5},
	},
	"shieldmate": {
		"rivals": {"text": "Climbers offer to team up twice as often, and trade kinder.", "team": 2.0, "friendly": true, "trade_ask": 0.9},
		"gym": {"text": "Medal drills cost half.", "fee_cut": 0.5},
	},
	"helping_hand": {
		"rivals": {"text": "Climbers trade kindly: they ask a fifth less.", "friendly": true, "trade_ask": 0.8},
		"outfitter": {"text": "He takes 3% off everything he sells.", "discount": 0.03},
	},
	"stairworn": {
		"outfitter": {"text": "One more Fine piece hangs on his rail for you.", "first_look": 1},
		"gym": {"text": "Medal drills cost half.", "fee_cut": 0.5},
	},
	"surefoot": {
		"gym": {"text": "The extra drills open, and medal drills cost half.", "extra": true, "fee_cut": 0.5},
		"tourney": {"text": "Entry costs half.", "fee_cut": 0.5},
	},
	"duelist": {
		"rivals": {"text": "Climbers take your bets, and one who beats you takes half the toll.", "bets": true, "toll": 0.5},
		"tourney": {"text": "Prizes are a quarter bigger.", "prize": 0.25},
	},
	"trusted": {
		"outfitter": {"text": "He takes 5% off everything he sells.", "discount": 0.05},
		"rivals": {"text": "Climbers trade kinder: they ask a sixth less.", "friendly": true, "trade_ask": 0.85},
	},
	"ironclad": {
		"tourney": {"text": "Brackets open a rank sooner, and prizes are a quarter bigger.", "early": 1, "prize": 0.25},
		"outfitter": {"text": "One more Fine piece hangs on his rail for you.", "first_look": 1},
	},
	"goldhand": {
		"gym": {"text": "Medal drills are free, and the extra drills open.", "fee_cut": 1.0, "extra": true},
		"outfitter": {"text": "He takes 5% off everything he sells.", "discount": 0.05},
	},
	"glassbreaker": {
		"tourney": {"text": "Entry is free, and prizes are 40% bigger.", "fee_cut": 1.0, "prize": 0.4},
		"rivals": {"text": "Climbers take your bets.", "bets": true},
	},
	"champion": {
		"tourney": {"text": "Brackets open a rank sooner, entry is free, and prizes are half again as big.", "early": 1, "fee_cut": 1.0, "prize": 0.5},
		"outfitter": {"text": "He takes 8% off, and today's piece comes a rarity higher.", "discount": 0.08, "today": true},
	},
	"talked_of": {
		"rivals": {"text": "Climbers trade kindly (a quarter less), team up half again as often and take your bets.", "friendly": true, "trade_ask": 0.75, "team": 1.5, "bets": true},
		"outfitter": {"text": "He takes 10% off, and one more Fine piece hangs for you.", "discount": 0.1, "first_look": 1},
	},
	"paragon": {
		"rivals": {"text": "Climbers trade kindly, team up twice as often and take your bets.", "friendly": true, "trade_ask": 0.75, "team": 2.0, "bets": true},
		"gym": {"text": "Medal drills are free, and the extra drills open.", "fee_cut": 1.0, "extra": true},
		"tourney": {"text": "Entry is free, and prizes are half again as big.", "fee_cut": 1.0, "prize": 0.5},
		"outfitter": {"text": "He takes 10% off, today's piece comes a rarity higher, and two more Fine pieces hang for you.", "discount": 0.1, "today": true, "first_look": 2},
	},
}

static var TEXT := {
	"benefits": "What it gives",
	"none": "No benefits: a name and nothing more.",
	"line": "%s: %s",
	"worn_only": "Only the title you wear gives its benefits.",
	"tree": "The outfitter's upgrade tree: once granted (worn or not), it opens %s.",
}


## A title's benefits for one group ({} for none).
static func of(id: String, group: String) -> Dictionary:
	var t = SOCIAL.get(id, {})
	return t.get(group, {}) if t is Dictionary else {}


## The worn title's benefits for one group ({} for none, or no title worn).
static func worn(profile, group: String) -> Dictionary:
	return of(Renown.worn_id(profile), group)


## One number of the worn title's benefits (`def` if it has none).
static func num(profile, group: String, key: String, def := 0.0) -> float:
	return float(worn(profile, group).get(key, def))


## One switch of the worn title's benefits.
static func flag(profile, group: String, key: String) -> bool:
	return bool(worn(profile, group).get(key, false))


## A title's benefits in words, one line per group: ["Rival climbers: ...", ...].
static func lines(id: String) -> Array:
	var out: Array = []
	for g in GROUPS:
		var d := of(id, String(g[0]))
		if not d.is_empty():
			out.append(TEXT["line"] % [g[1], String(d.get("text", ""))])
	# The outfitter's upgrade tree nodes it opens (outfitter.gd: granted is enough).
	var O = load("res://scripts/outfitter.gd")
	var opens: Array = O.ORDER.filter(func(n): return String(O.NODES[n].get("title", "")) == id).map(func(n): return String(O.node_name(n)).left(1).to_lower() + String(O.node_name(n)).substr(1))
	if not opens.is_empty():
		out.append(TEXT["tree"] % ", ".join(opens))
	return out


## THE RIVAL CLIMBERS' HOOK (rivals.gd now; the Dining car later): how other
## climbers treat you, from the title you wear. {friendly, trade_ask, team,
## toll, bets}, each filled in (no title: friendly false, trade_ask 1, team
## 1, toll 1, bets false).
static func rival_terms(profile) -> Dictionary:
	var d := worn(profile, "rivals")
	return {"friendly": bool(d.get("friendly", false)), "trade_ask": clampf(float(d.get("trade_ask", 1.0)), 0.3, 1.0),
		"team": maxf(float(d.get("team", 1.0)), 0.0), "toll": clampf(float(d.get("toll", 1.0)), 0.0, 1.0), "bets": bool(d.get("bets", false))}
