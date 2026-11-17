extends RefCounted
## THE OUTFITTER'S UPGRADE TREE: everything that makes the Outfitter's Car
## better for you, in one place, drawn as a tree on the store's page
## (outfit_tree.gd draws it, store_page.gd puts it in the car).
##
## The TRUNK is your renown rank: one node per rank (renown.gd RANKS). It is
## free and automatic: each rank he trusts you with more stock (shop.gd
## RANK_STOCK: rail spaces, kinds of supply, Fine and Rare pieces, which
## weapons hang). Four BRANCHES grow from it; their nodes are bought with
## crystals of any kind (your biggest crystals first, like the recall
## scroll) once they are open. A node is open when you have its rank, the
## node below it in its branch, and (for a few) a title the Noble has
## granted you (renown.gd TITLES; wearing it isn't needed).
##   prices   better buy and sell prices
##   stock    rare and unique pieces, more charms, the special order
##   gifts    something for nothing: a staple each climb, a gift each visit
##            and on each new rank
##   info     what he knows: what the next tower is handy for, the piece
##            that beats yours, a monster's weakness, where a contract lies
## Bought nodes are kept for good (the save's renown "outfitter" section).
##
## Old saves: the five upgrades a rank used to unlock (train.gd UPGRADES,
## gone) are kept as the nodes that do the same (OLD_UPGRADES), granted free
## as the save loads (adopt_old).
##
## Titles: a worn title's own outfitter benefit (titles.gd SOCIAL
## "outfitter") still counts while you wear it. Where it does what a node
## does, they don't double up: discounts add up to at most
## FX "discount_cap", and the special order and the Rare piece are the
## tree's alone.
##
## Every name, number and word is here (and in the Data editor: "The
## outfitter's upgrade tree"). Names and lines are placeholders for the
## owner to change; if you change a number in FX, change the words in that
## node's "desc" too.

const Renown := preload("res://scripts/renown.gd")
const Gear := preload("res://scripts/gear.gd")
const Items := preload("res://scripts/items.gd")
const Essence := preload("res://scripts/essence.gd")
const Towers := preload("res://scripts/towers.gd")
const Shop := preload("res://scripts/shop.gd")
const Needs := preload("res://scripts/tower_needs.gd")

## The branches: [id, name], left to right round the trunk (prices and
## stock on its left, gifts and info on its right).
static var BRANCHES := [["prices", "Prices"], ["stock", "Stock"], ["gifts", "Gifts"], ["info", "Info"]]
## Which column of the tree each branch (and the trunk) stands in.
const COLUMNS := {"prices": 0, "stock": 1, "trunk": 2, "gifts": 3, "info": 4}

## The nodes. Each: branch, rank (renown.gd RANKS index: its row in the
## tree), cost (crystals of any kind), needs (the nodes that must be bought
## first: the one below it), title (a title id the Noble must have granted,
## "" for none), name, desc (what it does, plainly) and say (the outfitter's
## line when you buy it).
static var NODES := {
	# Prices
	"fair_price": {"branch": "prices", "rank": 1, "cost": 20, "needs": [], "title": "",
		"name": "Fair prices", "desc": "He takes 5% off everything he sells.",
		"say": "A familiar face. I can shave a little off for those."},
	"scroll_aside": {"branch": "prices", "rank": 2, "cost": 30, "needs": ["fair_price"], "title": "",
		"name": "A scroll kept aside", "desc": "The recall scroll costs 40 of any kind, not 60.",
		"say": "I'll keep one under the counter for you."},
	"better_share": {"branch": "prices", "rank": 3, "cost": 45, "needs": ["scroll_aside"], "title": "",
		"name": "A better share", "desc": "He pays half a piece's price when you sell it, not 40%.",
		"say": "Your finds sell well. I'll pay you better for them."},
	"regular": {"branch": "prices", "rank": 4, "cost": 60, "needs": ["better_share"], "title": "",
		"name": "A regular's discount", "desc": "He takes 10% off everything he sells (in place of 5%).",
		"say": "You're a regular now. Regulars pay less."},
	"old_friend": {"branch": "prices", "rank": 5, "cost": 90, "needs": ["regular"], "title": "goldhand",
		"name": "An old friend's price", "desc": "He takes 15% off everything he sells, and pays 55% of a piece's price when you sell it.",
		"say": "Goldhand, is it? Then it's an old friend's price."},
	# Stock
	"wide_rack": {"branch": "stock", "rank": 1, "cost": 20, "needs": [], "title": "",
		"name": "A wider rack", "desc": "Two more pieces hang on his rail.",
		"say": "I'll hang a little more out for you."},
	"charm_tray": {"branch": "stock", "rank": 2, "cost": 30, "needs": ["wide_rack"], "title": "",
		"name": "A charm tray", "desc": "One more charm in his tray each visit.",
		"say": "Charms, then. I know a few who make them."},
	"better_stock": {"branch": "stock", "rank": 3, "cost": 45, "needs": ["charm_tray"], "title": "",
		"name": "Better stock", "desc": "Rail pieces come Fine at least a quarter of the time, and today's piece is likelier Rare, now and then Storied.",
		"say": "I'll stop selling you the dented ones."},
	"rare_hook": {"branch": "stock", "rank": 4, "cost": 60, "needs": ["better_stock"], "title": "",
		"name": "A Rare on the hook", "desc": "One Rare piece always hangs on his rail.",
		"say": "There's always one good piece. Now it's yours to look at first."},
	"special_order": {"branch": "stock", "rank": 5, "cost": 90, "needs": ["rare_hook"], "title": "",
		"name": "Special order", "desc": "He holds one piece you choose, from the rail or the case, until you come back for it.",
		"say": "Point at it and I'll keep it back. One at a time."},
	"relic_offer": {"branch": "stock", "rank": 6, "cost": 120, "needs": ["special_order"], "title": "beastfeller",
		"name": "A relic, offered once", "desc": "He brings out a relic, a Storied named piece, just for you. It waits in his case until you buy it. Once only.",
		"say": "A Beastfeller should see this. I don't show it to many."},
	# Gifts
	"staple_gift": {"branch": "gifts", "rank": 1, "cost": 20, "needs": [], "title": "",
		"name": "A draught for the road", "desc": "A free Healing Draught goes on your belt as you leave for each climb (if your belt has room).",
		"say": "Take a draught on me. Every time."},
	"visit_gift": {"branch": "gifts", "rank": 2, "cost": 30, "needs": ["staple_gift"], "title": "",
		"name": "Something for coming by", "desc": "Each visit after a climb he gives you 4 crystals of the tower you came from.",
		"say": "Come back down and there's something waiting."},
	"rank_gift": {"branch": "gifts", "rank": 3, "cost": 45, "needs": ["visit_gift"], "title": "",
		"name": "A gift for each rank", "desc": "Each time you rise a rank he gives you a Fine piece, into your stash (crystals instead if it's full).",
		"say": "When word of you grows, I'll mark it."},
	"kit_gift": {"branch": "gifts", "rank": 4, "cost": 60, "needs": ["rank_gift"], "title": "helping_hand",
		"name": "A climber's kit", "desc": "A Stamina Draught and a Cleansing Tonic go on your belt too, each climb (if there's room).",
		"say": "You help others up. Let me help you."},
	# Info
	"tower_tip": {"branch": "info", "rank": 1, "cost": 15, "needs": [], "title": "",
		"name": "Word on the tower", "desc": "He says what the tower chosen at the Engine is handy for, and marks those supplies on his shelf.",
		"say": "Tell me where you're going. I'll tell you what to pack."},
	"best_buy": {"branch": "info", "rank": 2, "cost": 25, "needs": ["tower_tip"], "title": "",
		"name": "His pick for you", "desc": "He points out the piece on his rail or in his case that beats yours by the most.",
		"say": "I'll tell you which one I'd buy, in your boots."},
	"weak_spot": {"branch": "info", "rank": 3, "cost": 40, "needs": ["best_buy"], "title": "",
		"name": "Climbers' talk", "desc": "Each visit after a climb he tells you a monster's weakness, from the tower you came from, and it goes in your Bestiary.",
		"say": "Climbers talk at my counter. Now I'll pass it on."},
	"contract_hint": {"branch": "info", "rank": 4, "cost": 50, "needs": ["weak_spot"], "title": "trusted",
		"name": "Where it lies", "desc": "When you reach the floor of a contract's thing to retrieve, he has told you which way it lies from where you start.",
		"say": "The Noble's errands? I hear where those things end up."},
}

## The order the nodes are listed in (the tree's own order: by branch, bottom up).
static var ORDER := ["fair_price", "scroll_aside", "better_share", "regular", "old_friend",
	"wide_rack", "charm_tray", "better_stock", "rare_hook", "special_order", "relic_offer",
	"staple_gift", "visit_gift", "rank_gift", "kit_gift",
	"tower_tip", "best_buy", "weak_spot", "contract_hint"]

## The nodes' numbers.
##   discount        what each price node takes off (the best one you own counts)
##   discount_cap    the most taken off, with a worn title's discount added
##   share           what each node pays when you sell (a share of the price; the best counts)
##   scroll_price    the recall scroll's price with a scroll kept aside
##   rack_extra      more rail spaces (a wider rack)
##   charm_extra     more charms in his tray (a charm tray)
##   rack_fine       rail pieces come Fine at least this often, in 100 (better stock)
##   rare_hook       how many Rare pieces always hang (a Rare on the hook)
##   visit_gift      crystals of the tower you came from, each visit
##   rank_gift_fallback   crystals instead of a piece when your stash is full
##   belt            the supplies each gift node puts on your belt as you leave
static var FX := {
	"discount": {"fair_price": 0.05, "regular": 0.1, "old_friend": 0.15},
	"discount_cap": 0.25,
	"share": {"better_share": 0.5, "old_friend": 0.55},
	"scroll_price": 40,
	"rack_extra": 2,
	"charm_extra": 1,
	"rack_fine": 25,
	"rare_hook": 1,
	"visit_gift": 4,
	"rank_gift_fallback": 15,
	"belt": {"staple_gift": ["draught"], "kit_gift": ["stamina", "tonic"]},
}
## Today's piece with better stock: its rarity odds (without: train.gd TODAY_ODDS).
static var STOCK_ODDS := {"fine": 50, "rare": 45, "storied": 5}

## The upgrades a rank used to unlock (train.gd UPGRADES, before the tree):
## old id -> [the node that does the same, the rank that unlocked it].
static var OLD_UPGRADES := {"wide_rack": ["wide_rack", 1], "scroll": ["scroll_aside", 2], "stock": ["better_stock", 3],
	"discount": ["regular", 4], "order": ["special_order", 5]}

static var TEXT := {
	"title": "The outfitter's upgrades",
	"trunk": "Rank",
	"trunk_name": "%s: his stock",
	"trunk_rank": "Rank %d of %d  ·  %d renown",
	"trunk_note": "Free: each rank he stocks more for you. Your renown is %d.",
	"trunk_rail": "%d spaces on his rail",
	"trunk_kinds": "%d kinds of supply on his shelf",
	"trunk_charms": "%d charms in his tray",
	"trunk_fine": "Fine pieces %d in 100",
	"trunk_rare": "Rare pieces %d in 100",
	"trunk_named": "now and then a named Rare piece",
	"trunk_relic": "now and then a relic",
	"trunk_weapons": "new on the rail: %s",
	"trunk_supplies": "new on the shelf: %s",
	"reached": "Yours: you've reached this rank.",
	"to_reach": "Reach the rank of %s (%d renown) for this.",
	"bought": "Bought. It's yours for good.",
	"ready": "Open: you can buy it.",
	"locked": "Not open yet.",
	"needs_rank": "the rank of %s (%d renown)",
	"needs_title": "the title %s (from the Noble)",
	"needs_node": "%s, first",
	"needs": "Needs %s.",
	"needs_have": "Has: %s.",
	"branch": "Branch: %s",
	"buy": "Buy it",
	"bought_toast": "Bought: %s",
	"cant": "Can't buy: %s",
	"price": "Costs %d crystals of any kind, your biggest first.",
	"poor": "needs %d more essence, of any kind",
	"count": "%d of %d bought",
	"cap_note": "With your worn title it all comes to %d%% off (%d%% at most).",
	"title_too": "Your worn title takes off %d%% more.",
	"how": "Renown opens his upgrades: each needs a rank, the one below it, and sometimes a title. Buy one with crystals of any kind; it's yours for good.",
	# Things the nodes say in the store
	"gift_visit": "For coming by: %s.",
	"gift_rank": "For your new rank of %s: %s.",
	"gift_rank_crystals": "For your new rank of %s: %s (your stash is full).",
	"told": "Climbers' talk on %s: %s. It's in your Bestiary.",
	"tower_tip": "For %s he'd pack: %s.",
	"tower_tip_none": "For %s: nothing special to pack.",
	"best": "His pick for you: %s.",
	"belt_gift": "His gift as you leave: %s on your belt.",
	"hint": "The outfitter's hint: %s lies to the %s of where you start.",
	"handy_tag": "Handy",
	"best_tag": "Best",
	"unique": "Offered once",
	"unique_note": "A relic he brought out for you. It waits here until you buy it, and won't come again.",
	"unique_empty": "Nothing waits here.",
	"compass": ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"],
}


# --- state -------------------------------------------------------------------------------

## The climber's tree, every key filled in (kept in renown.gd's state, the
## save's renown section):
##   bought      node ids bought (or kept from an old save)
##   unique      the relic offered once, waiting in his case (a gear code, "" for none)
##   unique_done true once the relic has been offered
##   gift_rank   the rank the last rank gift was for (-1: none yet)
static func state(profile) -> Dictionary:
	var r := Renown.state(profile)
	var o = r.get("outfitter", null)
	if not (o is Dictionary):
		o = {}
		r["outfitter"] = o
	var defaults := {"bought": [], "unique": "", "unique_done": false, "gift_rank": -1}
	for k in defaults:
		if not o.has(k) or typeof(o[k]) != typeof(defaults[k]):
			o[k] = defaults[k].duplicate() if defaults[k] is Array else defaults[k]
	return o


## An old save (loaded with renown but no tree): the upgrades its rank had
## unlocked become the nodes that do the same, free (profile.gd load_save).
static func adopt_old(profile) -> void:
	if not (profile.renown is Dictionary) or profile.renown.is_empty() or profile.renown.has("outfitter"):
		return
	var rank := Renown.rank_for(int(profile.renown.get("points", 0)))
	var o := state(profile)
	for old in OLD_UPGRADES:
		var e: Array = OLD_UPGRADES[old]
		if rank >= int(e[1]) and not o["bought"].has(String(e[0])):
			o["bought"].append(String(e[0]))


## True if this node is bought (a trunk node: its rank is reached).
static func owns(profile, id: String) -> bool:
	if profile == null:
		return false
	if is_trunk(id):
		return Renown.rank(profile) >= trunk_rank(id)
	return state(profile)["bought"].has(id)


static func bought_count(profile) -> int:
	return ORDER.filter(func(id): return owns(profile, id)).size()


# --- the nodes ---------------------------------------------------------------------------

## The trunk's nodes: "rank0" (Unknown) to "rank6" (Celebrated).
static func trunk_ids() -> Array:
	var out: Array = []
	for i in Renown.RANKS.size():
		out.append("rank%d" % i)
	return out


static func is_trunk(id: String) -> bool:
	return id.begins_with("rank") and id.substr(4).is_valid_int()


static func trunk_rank(id: String) -> int:
	return int(id.substr(4))


## Every node of the tree: the trunk, then the branches.
static func all_ids() -> Array:
	return trunk_ids() + ORDER.filter(func(id): return NODES.has(id))


static func exists(id: String) -> bool:
	return NODES.has(id) or (is_trunk(id) and trunk_rank(id) >= 0 and trunk_rank(id) < Renown.RANKS.size())


static func node_rank(id: String) -> int:
	return trunk_rank(id) if is_trunk(id) else int(NODES.get(id, {}).get("rank", 0))


static func branch_of(id: String) -> String:
	return "trunk" if is_trunk(id) else String(NODES.get(id, {}).get("branch", ""))


static func branch_name(b: String) -> String:
	for e in BRANCHES:
		if e[0] == b:
			return String(e[1])
	return String(TEXT["trunk"])


static func node_name(id: String) -> String:
	if is_trunk(id):
		return TEXT["trunk_name"] % Renown.rank_name(trunk_rank(id))
	return String(NODES.get(id, {}).get("name", id))


static func node_desc(id: String) -> String:
	if is_trunk(id):
		return trunk_desc(trunk_rank(id))
	return String(NODES.get(id, {}).get("desc", ""))


static func cost(id: String) -> int:
	return 0 if is_trunk(id) else int(NODES.get(id, {}).get("cost", 0))


## The nodes a node grows from (lines are drawn from them): a branch's first
## node grows from the trunk's first node.
static func parents(id: String) -> Array:
	if is_trunk(id):
		return [] if trunk_rank(id) == 0 else ["rank%d" % (trunk_rank(id) - 1)]
	var n: Array = Array(NODES.get(id, {}).get("needs", []))
	return n if not n.is_empty() else ["rank0"]


## "bought", "open" (you can buy it once you have the crystals) or "locked".
static func status(profile, id: String) -> String:
	if owns(profile, id):
		return "bought"
	if is_trunk(id):
		return "locked"
	return "open" if locks(profile, id).is_empty() else "locked"


## What a node still needs, in words (["the rank of Known (60 renown)", ...]; [] if it's open).
static func locks(profile, id: String) -> Array:
	var out: Array = []
	var n: Dictionary = NODES.get(id, {})
	if n.is_empty():
		return out
	var rk := int(n.get("rank", 0))
	if Renown.rank(profile) < rk:
		out.append(TEXT["needs_rank"] % [Renown.rank_name(rk), Renown.needed(rk)])
	var t := String(n.get("title", ""))
	if t != "" and not Renown.has_title(profile, t):
		out.append(TEXT["needs_title"] % Renown.title_name(t))
	for p in n.get("needs", []):
		if not owns(profile, String(p)):
			out.append(TEXT["needs_node"] % node_name(String(p)))
	return out


## Everything a node needs, met or not, in words (its card lists them).
static func requirements(id: String) -> Array:
	var out: Array = []
	var n: Dictionary = NODES.get(id, {})
	if n.is_empty():
		return out
	out.append(TEXT["needs_rank"] % [Renown.rank_name(int(n["rank"])), Renown.needed(int(n["rank"]))])
	if String(n.get("title", "")) != "":
		out.append(TEXT["needs_title"] % Renown.title_name(String(n["title"])))
	for p in n.get("needs", []):
		out.append(TEXT["needs_node"] % node_name(String(p)))
	return out


## Why a node can't be bought now ("" if it can).
static func why_not(profile, id: String) -> String:
	if not NODES.has(id):
		return TEXT["locked"]
	if owns(profile, id):
		return TEXT["bought"]
	var l := locks(profile, id)
	if not l.is_empty():
		return TEXT["needs"] % ", ".join(l)
	var have := int(profile.crystals_held())
	if have < cost(id):
		return TEXT["poor"] % (cost(id) - have)
	return ""


## Buys a node: its crystals (any kind, the biggest first) for good. "" if bought, else why not.
static func buy(profile, id: String) -> String:
	var why := why_not(profile, id)
	if why != "":
		return why
	if cost(id) > 0 and profile.spend_any(cost(id)).is_empty():
		return TEXT["poor"] % cost(id)
	var o := state(profile)
	o["bought"].append(id)
	match id:
		"rank_gift":
			o["gift_rank"] = Renown.rank(profile)  # (gifts for the ranks still to come)
		"relic_offer":
			_offer_relic(profile)
	profile.save()
	return ""


static func line(id: String) -> String:
	return String(NODES.get(id, {}).get("say", ""))


## What his stock is at a rank (the trunk's card): a list of short phrases.
static func trunk_desc(rank: int) -> String:
	var row: Dictionary = Shop.RANK_STOCK[clampi(rank, 0, Shop.RANK_STOCK.size() - 1)]
	var bits: Array = []
	var Train = load("res://scripts/train.gd")
	bits.append(TEXT["trunk_rail"] % (int(Train.RACK_SIZE) + int(row["rail"])))
	bits.append(TEXT["trunk_kinds"] % int(row["kinds"]))
	var charms := int(load("res://scripts/charms.gd").SHOP["rack"]) + int(row["charms"])
	bits.append(TEXT["trunk_charms"] % charms)
	if int(row["fine"]) > 0:
		bits.append(TEXT["trunk_fine"] % int(row["fine"]))
	if int(row["rare"]) > 0:
		bits.append(TEXT["trunk_rare"] % int(row["rare"]))
	if int(row["named"]) > 0:
		bits.append(TEXT["trunk_named"])
	if int(row["relic"]) > 0:
		bits.append(TEXT["trunk_relic"])
	var weapons: Array = []
	for w in Shop.WEAPON_RANK:
		if int(Shop.WEAPON_RANK[w]) == rank and Gear.Weapons.WEAPONS.has(w):
			weapons.append(Gear.display(String(w)))
	if not weapons.is_empty():
		bits.append(TEXT["trunk_weapons"] % ", ".join(weapons))
	var supplies: Array = []
	for s in Shop.SHELF_RANK:
		if int(Shop.SHELF_RANK[s]) == rank and Items.ITEMS.has(s) and not String(s).begins_with("tincture_"):
			supplies.append(Items.item_name(s))
	if not supplies.is_empty():
		bits.append(TEXT["trunk_supplies"] % ", ".join(supplies))
	var s := "; ".join(bits)
	return s.left(1).to_upper() + s.substr(1) + "."


# --- what the nodes do --------------------------------------------------------------------

## What his prices take off (0 to 1): the best price node you own, and your
## worn title's discount (titles.gd), together no more than discount_cap.
static func discount(profile) -> float:
	if profile == null:
		return 0.0
	return clampf(tree_discount(profile) + Shop.title_discount(profile), 0.0, float(FX["discount_cap"]))


static func tree_discount(profile) -> float:
	var d := 0.0
	var table: Dictionary = FX["discount"]
	for id in table:
		if owns(profile, String(id)):
			d = maxf(d, float(table[id]))
	return d


## The share of a piece's price he pays when you sell it (train.gd SELL_SHARE, or better).
static func sell_share(profile) -> float:
	var Train = load("res://scripts/train.gd")
	var s := float(Train.SELL_SHARE)
	if profile == null:
		return s
	var table: Dictionary = FX["share"]
	for id in table:
		if owns(profile, String(id)):
			s = maxf(s, float(table[id]))
	return s


## The recall scroll's price with a scroll kept aside (-1 without).
static func scroll_price(profile) -> int:
	return int(FX["scroll_price"]) if owns(profile, "scroll_aside") else -1


static func rack_extra(profile) -> int:
	return int(FX["rack_extra"]) if owns(profile, "wide_rack") else 0


static func charm_extra(profile) -> int:
	return int(FX["charm_extra"]) if owns(profile, "charm_tray") else 0


static func fine_floor(profile) -> int:
	return int(FX["rack_fine"]) if owns(profile, "better_stock") else 0


static func rare_count(profile) -> int:
	return int(FX["rare_hook"]) if owns(profile, "rare_hook") else 0


## Today's piece's rarity odds: STOCK_ODDS with better stock, else `plain`.
static func today_odds(profile, plain: Dictionary) -> Dictionary:
	return STOCK_ODDS if owns(profile, "better_stock") else plain


## The relic offered once, waiting in his case ({} for none).
static func unique(profile) -> Dictionary:
	if profile == null:
		return {}
	return Gear.rec(state(profile)["unique"])


static func _offer_relic(profile) -> void:
	var o := state(profile)
	if bool(o["unique_done"]):
		return
	var pool: Array = Gear.NAMED_ORDER.filter(func(n): return String(Gear.NAMED[n]["rarity"]) == "storied")
	if pool.is_empty():
		return
	o["unique"] = Gear.code(Gear.make_named(pool[randi() % pool.size()]))
	o["unique_done"] = true


## The supplies his gift nodes put on your belt as you leave (item ids).
static func belt_gifts(profile) -> Array:
	var out: Array = []
	var table: Dictionary = FX["belt"]
	for id in table:
		if owns(profile, String(id)):
			for it in table[id]:
				if Items.ITEMS.has(String(it)):
					out.append(String(it))
	return out


## A visit after a climb (train.gd stock, once per visit): the gifts and the
## word his nodes bring. Returns what he says about them (lines).
static func on_visit(profile) -> Array:
	var out: Array = []
	if profile == null:
		return out
	var o := state(profile)
	var home := String(Towers.TOWERS.get(String(profile.last_tower), {}).get("essence", ""))
	if owns(profile, "visit_gift") and Essence.KINDS.has(home) and int(profile.climbs) > 0:
		var n := int(FX["visit_gift"])
		profile.add_crystal(home, float(n))
		out.append(TEXT["gift_visit"] % _price(home, n))
	if owns(profile, "rank_gift"):
		var rk := Renown.rank(profile)
		while int(o["gift_rank"]) < rk:
			o["gift_rank"] = int(o["gift_rank"]) + 1
			if int(o["gift_rank"]) <= 0:
				continue
			out.append(_rank_gift(profile, int(o["gift_rank"])))
	if owns(profile, "weak_spot") and int(profile.climbs) > 0:
		var D = load("res://scripts/dining.gd")
		var f: Dictionary = D.fact_weakness(profile, String(profile.last_tower))
		if not f.is_empty():
			D.tell_weakness(profile, String(f["kind"]))
			out.append(TEXT["told"] % [String(f["monster"]), String(f["weak"])])
	return out


static func _rank_gift(profile, rank: int) -> String:
	var Train = load("res://scripts/train.gd")
	if profile.chest.size() < int(Train.CHEST_SIZE):
		var base: String = Gear.random_gear("", [], true, "fine")
		for i in 12:
			if not Gear.traits_for(Gear.trait_slot(base)).is_empty():
				break
			base = Gear.random_gear("", [], true, "fine")
		var g := Gear.make(base, "fine", Gear.roll_traits(base, "fine"))
		profile.chest.append(g)
		return TEXT["gift_rank"] % [Renown.rank_name(rank), Gear.display(g)]
	var home := String(Towers.TOWERS.get(String(profile.last_tower), {}).get("essence", "stone"))
	if not Essence.KINDS.has(home):
		home = "stone"
	profile.add_crystal(home, float(FX["rank_gift_fallback"]))
	return TEXT["gift_rank_crystals"] % [Renown.rank_name(rank), _price(home, int(FX["rank_gift_fallback"]))]


static func _price(kind: String, n: int) -> String:
	return "%d %s" % [n, Essence.display(kind)]


## Word on the tower: what he'd pack for `tower` (item ids on this shelf, or every handy one).
static func handy(tower: String, shelf: Array = []) -> Array:
	var h: Array = Needs.handy(tower)
	return h if shelf.is_empty() else h.filter(func(id): return shelf.has(id))


static func tower_line(tower: String, shelf: Array) -> String:
	if not Towers.TOWERS.has(tower):
		return ""
	var tn := String(Towers.TOWERS[tower]["name"])
	var h := handy(tower, shelf)
	if h.is_empty():
		h = handy(tower)
	if h.is_empty():
		return TEXT["tower_tip_none"] % tn
	return TEXT["tower_tip"] % [tn, ", ".join(h.map(func(id): return Items.item_name(String(id))))]


## Where it lies: the hint said on a contract's floor (contracts.gd): which
## way `to` lies from `from` ("north-east": up the screen is north).
static func hint_line(thing: String, from: Vector2, to: Vector2) -> String:
	var d := to - from
	var names: Array = TEXT["compass"]
	var i := posmod(int(round(d.angle() / (TAU / 8.0))), 8)
	return TEXT["hint"] % [thing, String(names[i])]
