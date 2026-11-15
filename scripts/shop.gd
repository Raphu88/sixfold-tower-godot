extends RefCounted
## SHOP VARIETY: what the Outfitter's Car stocks, and the Pedlar who sets up
## at stations and at camps. Everything here is data (a table, a number or a
## line of words), registered in the Data editor (data_registry.gd), so it's
## easy to change. No story: the owner writes that.
##
## The outfitter's stock grows with your renown rank (RANK_STOCK, one row
## per rank in renown.gd RANKS):
##   rail      more spaces on the outfit rail (on top of his "wide rack"
##             upgrade); a long rail is shown in pages of about ten
##   charms    more charms among the rail's pieces (charms.gd SHOP says the
##             first one)
##   fine, rare, named, relic   the chances (in 100) that a rail piece is
##             Fine or Rare, that one named Rare tower piece hangs on the
##             rail, and that one Storied relic does
##   kinds     how many kinds of supplies the shelf holds this visit (the
##             ones in SHELF_ALWAYS are always there; the rest are picked
##             from what your rank has opened, new every visit)
##   minor, greater   how many Minor / Greater sizes the shelf adds
## SHELF_RANK says which rank opens each supply, WEAPON_RANK which rank a
## weapon starts hanging on the rail (a pistol or a crossbow later than a
## dagger).
##
## A worn TITLE tilts the rail (TITLE_STOCK, keyed by title id: a title not
## listed leaves the stock as it is): "tilt" makes some slots or pieces
## likelier, "item" puts one supply on the shelf for you, "discount" takes
## something off everything he sells. "line" is said on the rail.
##
## THE PEDLAR (MERCHANT) sets up at every station and at each camp once your
## rank reaches MERCHANT["rank"]. Each visit offers a few wares on a theme
## (THEMES, taken in turn), priced in crystals; at a camp, what you lack in
## crystals of that kind can be made up from essence you carry (unbanked).

const Gear := preload("res://scripts/gear.gd")
const Items := preload("res://scripts/items.gd")
const Renown := preload("res://scripts/renown.gd")
const Charms := preload("res://scripts/charms.gd")
const Essence := preload("res://scripts/essence.gd")
const Needs := preload("res://scripts/tower_needs.gd")
const TRAIN := "res://scripts/train.gd"  # (loaded when needed: the train preloads this)

## One row per renown rank, Unknown first.
static var RANK_STOCK := [
	{"rail": 0, "charms": 0, "fine": 0, "rare": 0, "named": 0, "relic": 0, "kinds": 6, "minor": 0, "greater": 0},
	{"rail": 0, "charms": 0, "fine": 0, "rare": 0, "named": 0, "relic": 0, "kinds": 8, "minor": 1, "greater": 0},
	{"rail": 1, "charms": 0, "fine": 10, "rare": 0, "named": 0, "relic": 0, "kinds": 10, "minor": 2, "greater": 0},
	{"rail": 2, "charms": 1, "fine": 25, "rare": 0, "named": 0, "relic": 0, "kinds": 12, "minor": 2, "greater": 0},
	{"rail": 4, "charms": 1, "fine": 30, "rare": 6, "named": 8, "relic": 0, "kinds": 14, "minor": 2, "greater": 2},
	{"rail": 6, "charms": 2, "fine": 35, "rare": 10, "named": 12, "relic": 8, "kinds": 16, "minor": 2, "greater": 3},
	{"rail": 8, "charms": 2, "fine": 40, "rare": 14, "named": 18, "relic": 16, "kinds": 18, "minor": 3, "greater": 4},
]

## The supplies that are always on his shelf.
static var SHELF_ALWAYS := ["draught", "stamina", "tonic", "vial", "scroll"]

## The rank (an index into renown.gd RANKS) that opens each supply for the
## shelf. One not listed here is open from the start; an id the game doesn't
## have (yet) is simply skipped, so new items can be added to this table.
static var SHELF_RANK := {
	"smoke": 0, "fire_flask": 0,
	"edge_oil": 1, "antidote": 1,
	"salts": 2, "flare": 2, "warding_oil": 2, "tincture_water": 2, "tincture_fire": 2, "tincture_air": 2,
	"tincture_stone": 2, "tincture_iron": 2, "tincture_blade": 2,
	"haste": 3, "stoneskin": 3, "heartroot": 3,
	"net": 4, "lodestone": 4, "briar_tonic": 4,
	"lantern_oil": 5, "gale_feather": 5,
	"unmaking_ash": 6, "seeing_scroll": 6,
}

## The rank each size opens on the shelf (Minor, Greater): the table above
## says how many of each a visit holds.
static var SIZE_RANK := {"1": 1, "3": 4}

## The rank a weapon starts to hang on the rail at (not listed: from the start).
static var WEAPON_RANK := {
	"cane": 1, "longbow": 1,
	"flintlock": 2, "crossbow": 2, "sword_cane": 2,
	"greatsword": 3, "war_hammer": 3,
	"revolver": 4,
}

## The slots a title can tilt toward, by group.
static var GROUPS := {
	"blades": ["dagger", "sword", "sword_cane", "greatsword", "axe"],
	"guns": ["flintlock", "revolver"],
	"bows": ["shortbow", "longbow", "crossbow"],
	"heavy": ["mace", "war_hammer", "greatsword", "axe"],
	"trade": ["satchel", "belt_pouch", "bandolier", "pack", "great_pack", "herb_pouch", "climbers_pack"],
}

## Titles that flavour the stock (keyed by title id, renown.gd TITLES):
##   line      said on the rail: what hangs there for you
##   tilt      {"slots": gear slots, "groups": GROUPS ids, "ids": piece ids, "weight": how much likelier}
##   item      a supply (id) that joins the shelf for this title
##   discount  a share off everything he sells (0 to 1)
static var TITLE_STOCK := {
	"trainee": {"line": "For the Trainee: plain weapons, well made.", "tilt": {"slots": ["melee"], "weight": 2.0}, "item": "tonic"},
	"beastfeller": {"line": "For Beastfeller: spears, axes and bows hang first.", "tilt": {"groups": ["heavy", "bows"], "ids": ["spear"], "weight": 3.0}, "item": "fire_flask"},
	"stairworn": {"line": "For the Stairworn: boots, leggings and packs hang first.", "tilt": {"slots": ["boots", "legs", "backpack"], "weight": 3.0}, "item": "stamina"},
	"surefoot": {"line": "For Surefoot: boots and cloaks hang first.", "tilt": {"slots": ["boots", "cloak"], "weight": 3.0}, "item": "gale_feather"},
	"goldhand": {"line": "For Goldhand: rings, pendants and charms hang first.", "tilt": {"slots": ["ring", "amulet", "charm"], "weight": 3.0}, "discount": 0.05},
	"contender": {"line": "For the Contender: blades and pistols hang first.", "tilt": {"groups": ["blades", "guns"], "weight": 3.0}, "item": "edge_oil"},
	"ironclad": {"line": "For Ironclad: armour hangs first.", "tilt": {"slots": ["armor", "helm", "gloves", "legs", "boots"], "weight": 3.0}, "item": "stoneskin"},
	"champion": {"line": "For the Champion: blades and armour hang first, and he takes a little off.", "tilt": {"groups": ["blades"], "slots": ["armor", "helm"], "weight": 3.0}, "discount": 0.05},
	"glassbreaker": {"line": "For Glassbreaker: pistols and crossbows hang first.", "tilt": {"groups": ["guns", "bows"], "weight": 4.0}, "item": "flare"},
	"daring": {"line": "For the Daring: charms hang first.", "tilt": {"slots": ["charm"], "weight": 4.0}, "item": "net"},
	"unbowed": {"line": "For the Unbowed: he takes a little off everything.", "tilt": {"slots": ["armor", "melee"], "weight": 2.0}, "discount": 0.05},
	"talked_of": {"line": "For the Talked-of: trade goods hang first, and he takes a little off.", "tilt": {"groups": ["trade"], "slots": ["charm"], "weight": 3.0}, "discount": 0.05},
}

## The pedlar: his name, the rank that unlocks him, his prices (a share over
## the outfitter's) and his words.
static var MERCHANT := {
	"name": "the Pedlar", "short": "Pedlar", "rank": 3, "markup": 1.25,
	"wares": 4, "camp_wares": 3,
}

## The themes his wares follow, taken in turn from one visit to the next
## (THEME_ORDER). "kind":
##   handy   the tower ahead's handy items (tower_needs.gd), Greater when it can be
##   charms  charms, Fine or Rare
##   arms    weapons from "pool", Fine or Rare
##   tinctures  every tincture (item ids starting "tincture_"), Greater when it can be
##   relics  Storied relics
## "count": how many wares; "rank": the rank it opens at.
static var THEME_ORDER := ["handy", "charms", "arms", "tinctures", "relics"]
static var THEMES := {
	"handy": {"name": "Wares for the climb", "line": "Bigger bottles of what the tower ahead asks for.", "kind": "handy", "count": 4, "rank": 3},
	"charms": {"name": "Charms and trinkets", "line": "Small things that keep a climber safe.", "kind": "charms", "count": 3, "rank": 3},
	"arms": {"name": "The weapon-smith's bench", "line": "Pistols, crossbows and canes, well kept.", "kind": "arms", "count": 3, "rank": 3,
		"pool": ["flintlock", "revolver", "crossbow", "sword_cane", "cane", "longbow"]},
	"tinctures": {"name": "Tinctures", "line": "Essence in a bottle, for drinking.", "kind": "tinctures", "count": 4, "rank": 3},
	"relics": {"name": "Old relics", "line": "Pieces with a past. Ask no more than he knows.", "kind": "relics", "count": 2, "rank": 5},
}

static var TEXT := {
	"rail_title": "Rail",
	"page": "Page %d of %d",
	"locked": "He sets up at stations and at camps once you are %s.",
	"locked_card": "The Pedlar travels between the towers. Once you are %s, he sets up a stall at every station and at each camp, with a few wares on a theme that changes every visit.",
	"closed_tile": "Not yet set up",
	"theme": "Today: %s",
	"sold": "Sold",
	"bought": "Bought %s",
	"cant": "Can't buy: %s",
	"paid": "Paid %s",
	"paid_carried": "%d of it from essence you carry",
	"buy": "Buy",
	"buy_camp": "Buy (crystals, then essence you carry)",
	"belt_full": "Your belt has no room for it.",
	"pack_full": "Your pack is full, and so is your stash.",
	"went_stash": "Your pack was full, so it went into your stash.",
	"camp_card": "The Pedlar's stall",
	"camp_desc": "He has set up by the fire. Wares for crystals, or for essence you carry.",
	"camp_back": "Back to the fire",
	"camp_back_desc": "Come back to the camp's choices.",
	"camp_note": "Paid from your crystals of that kind first, then from essence you carry.",
	"camp_empty": "He has nothing left to sell.",
	"station_note": "Wares are paid for with your crystals. Items go on your belt for the next climb, pieces into your pack.",
	"empty": "Nothing left on his stall. He has more at the next stop.",
	"title_line": "For %s",
	"shelf_title": "For %s: %s",
	"minor": "Minor", "greater": "Greater",
	"theme_none": "He has nothing to show today.",
}

## What he says when he sets up: a station, or a camp ("lines" are picked in turn by the visit).
static var LINES := {
	"station": ["Come and look. It won't be here next time.", "Take your time. The train isn't going anywhere.", "Something for the road?"],
	"camp": ["Saw your fire from the stair.", "A warm spot. Mind if I set out my things?", "I only stay while the fire does."],
	"bought": ["Good choice.", "That one is going somewhere useful.", "Pleasure."],
	"poor": ["Not enough in the purse for that one.", "Come back with more essence."],
}


# --- rank and title ------------------------------------------------------------------

## The stock row for a rank (a climber with no profile: the first).
static func row(profile) -> Dictionary:
	var r := clampi(Renown.rank(profile), 0, RANK_STOCK.size() - 1) if profile != null else 0
	return RANK_STOCK[r]


## The worn title's flavour ({} for none, or a title not listed).
static func flavour(profile) -> Dictionary:
	if profile == null:
		return {}
	var id := String(Renown.state(profile).get("worn", ""))
	return TITLE_STOCK.get(id, {}) if Renown.TITLES.has(id) else {}


## The title's name ("the Contender") when it flavours the stock, else "".
static func flavour_title(profile) -> String:
	if flavour(profile).is_empty():
		return ""
	return Renown.title_name(String(Renown.state(profile).get("worn", "")))


## The line said on the rail for the worn title ("" when it has none).
static func title_line(profile) -> String:
	return String(flavour(profile).get("line", ""))


## What the worn title takes off his prices (0 to 1).
static func title_discount(profile) -> float:
	return clampf(float(flavour(profile).get("discount", 0.0)), 0.0, 0.5)


## How many more spaces the rail has at your rank.
static func rail_extra(profile) -> int:
	return int(row(profile)["rail"])


## How many charms hang on the rail (charms.gd SHOP says the first).
static func charm_count(profile) -> int:
	return int(Charms.SHOP["rack"]) + int(row(profile)["charms"])


# --- the rail ----------------------------------------------------------------------------

## Can this weapon or piece hang on the rail at your rank?
static func piece_open(profile, id: String) -> bool:
	var r := Renown.rank(profile) if profile != null else 0
	return r >= int(WEAPON_RANK.get(id, 0))


## How likely a piece is on the rail (1 for an ordinary one): the worn title's tilt.
static func weight(profile, id: String) -> float:
	var t: Dictionary = flavour(profile).get("tilt", {})
	if t.is_empty():
		return 1.0
	var hit: bool = id in Array(t.get("ids", [])) or Gear.slot_of(id) in Array(t.get("slots", []))
	if not hit:
		for gname in Array(t.get("groups", [])):
			if id in Array(GROUPS.get(gname, [])):
				hit = true
				break
	return maxf(1.0, float(t.get("weight", 1.0))) if hit else 1.0


## `n` different ids from `pool`, the tilted ones likelier.
static func pick(profile, pool: Array, n: int) -> Array:
	var left: Array = pool.duplicate()
	var out: Array = []
	while out.size() < n and not left.is_empty():
		var total := 0.0
		for id in left:
			total += weight(profile, String(id))
		var roll := randf() * total
		var at := left.size() - 1
		for i in left.size():
			roll -= weight(profile, String(left[i]))
			if roll < 0.0:
				at = i
				break
		out.append(left[at])
		left.remove_at(at)
	return out


## A rail piece at your rank: Common, or Fine or Rare by the rank's chances.
## `fine` is the share the outfitter's own upgrade already gives.
static func make_piece(profile, id: String, fine_floor := 0) -> Dictionary:
	var r := row(profile)
	var can: bool = not Gear.traits_for(Gear.trait_slot(id)).is_empty()
	if can:
		var roll := randi() % 100
		var rare := int(r["rare"])
		if roll < rare:
			return Gear.make(id, "rare", Gear.roll_traits(id, "rare"))
		if roll < rare + maxi(int(r["fine"]), fine_floor):
			return Gear.make(id, "fine", Gear.roll_traits(id, "fine"))
	return Gear.make(id)


## The extras that hang on the rail now and then at high ranks: a named Rare
## tower piece, a Storied relic. Records.
static func extras(profile) -> Array:
	var r := row(profile)
	var out: Array = []
	if randi() % 100 < int(r["named"]):
		var pool: Array = Gear.NAMED_ORDER.filter(func(n): return String(Gear.NAMED[n]["rarity"]) == "rare")
		if not pool.is_empty():
			out.append(Gear.make_named(pool[randi() % pool.size()]))
	if randi() % 100 < int(r["relic"]):
		var pool2: Array = Gear.NAMED_ORDER.filter(func(n): return String(Gear.NAMED[n]["rarity"]) == "storied")
		if not pool2.is_empty():
			out.append(Gear.make_named(pool2[randi() % pool2.size()]))
	return out


## A long list is shown in pages: how many, and how many to a page (split
## evenly, `limit` or fewer to a page). The rail's limit is 10, the shelf's
## SHELF_PAGE.
static func pages(total: int, limit := 10) -> int:
	return maxi(1, int(ceil(float(total) / float(maxi(limit, 1)))))


static func page_size(total: int, limit := 10) -> int:
	return int(ceil(float(total) / float(pages(total, limit))))


## How many supplies show on a shelf page.
const SHELF_PAGE := 12


# --- the shelf -----------------------------------------------------------------------------

## A shelf key: "draught" (standard), "draught@1" (Minor), "draught@3" (Greater).
static func key_id(key: String) -> String:
	return key.get_slice("@", 0)


static func key_size(key: String) -> int:
	return int(key.get_slice("@", 1)) if key.contains("@") else Items.STANDARD


static func make_key(id: String, size: int) -> String:
	return id if size == Items.STANDARD else "%s@%d" % [id, size]


## Supplies the shelf may hold at your rank, in the order the game lists items.
static func shelf_pool(profile) -> Array:
	var rank := Renown.rank(profile) if profile != null else 0
	var out: Array = []
	for id in Items.ORDER:
		if Items.ITEMS.has(id) and not Items.ITEMS[id].get("value", {}).is_empty() and int(SHELF_RANK.get(id, 0)) <= rank:
			out.append(id)
	for id in SHELF_RANK:  # (items not in Items.ORDER yet, e.g. tinctures, once they exist)
		if Items.ITEMS.has(id) and not out.has(id) and int(SHELF_RANK[id]) <= rank and not Items.ITEMS[id].get("value", {}).is_empty():
			out.append(id)
	return out


## The shelf for a visit: the always-there supplies, the title's own, then
## rotating ones up to the rank's number of kinds, then Minor and Greater
## sizes of some of them. Keys (make_key), in the order the shelf shows.
static func roll_shelf(profile) -> Array:
	var r := row(profile)
	var pool := shelf_pool(profile)
	var kinds: Array = SHELF_ALWAYS.filter(func(id): return pool.has(id) or id == "scroll")
	var title_item := String(flavour(profile).get("item", ""))
	if title_item != "" and Items.ITEMS.has(title_item) and not kinds.has(title_item):
		kinds.append(title_item)
	var rest: Array = pool.filter(func(id): return not kinds.has(id))
	rest.shuffle()
	var more := maxi(0, int(r["kinds"]) - kinds.size())
	kinds.append_array(rest.slice(0, more))
	kinds.sort_custom(func(a, b): return _order(a) < _order(b))
	var keys: Array = kinds.duplicate()
	var rank := Renown.rank(profile) if profile != null else 0
	for size in [1, 3]:
		var n := int(r["minor" if size == 1 else "greater"])
		if n <= 0 or rank < int(SIZE_RANK[str(size)]):
			continue
		var sized: Array = kinds.filter(func(id): return Items.is_sized(id) and id != "scroll")
		sized.shuffle()
		for id in sized.slice(0, n):
			keys.append(make_key(id, size))
	return keys


static func _order(id: String) -> int:
	var i := Items.ORDER.find(id)
	return i if i >= 0 else 999


## A size's price: the item's price times its size's worth (a Minor one is
## cheaper, a Greater one dearer).
static func sized_amount(amount: int, size: int) -> int:
	if size == Items.STANDARD or amount <= 0:
		return amount
	return maxi(1, int(round(float(amount) * Items.size_worth(size))))


# --- the pedlar --------------------------------------------------------------------------------

## Has the pedlar set up for you (your rank has reached his)?
static func merchant_open(profile) -> bool:
	return profile != null and Renown.rank(profile) >= int(MERCHANT["rank"])


## The rank that opens him, by name.
static func merchant_rank_name() -> String:
	return Renown.rank_name(int(MERCHANT["rank"]))


## The themes open at your rank that have something to sell.
static func themes_open(profile) -> Array:
	var rank := Renown.rank(profile) if profile != null else 0
	return THEME_ORDER.filter(func(t): return THEMES.has(t) and rank >= int(THEMES[t].get("rank", 0)) and not _empty_theme(t))


static func _empty_theme(t: String) -> bool:
	return String(THEMES[t].get("kind", "")) == "tinctures" and _tinctures().is_empty()


static func _tinctures() -> Array:
	return Items.ITEMS.keys().filter(func(id): return String(id).begins_with("tincture_") and not Items.ITEMS[id].get("value", {}).is_empty())


## A wares list for one visit. `where` is "station" or "camp"; `n` the visit
## (the theme is taken in turn by it); `tower` the tower ahead ("" for none).
## Returns {theme, name, line, wares: [ware...], where, n}; a ware is
## {kind: "item" (id, size) or "gear" (code), price: [kind, amount], sold}.
static func roll_merchant(profile, where: String, n: int, tower := "", floor_num := 1) -> Dictionary:
	var open := themes_open(profile)
	if open.is_empty():
		return {"theme": "", "name": "", "line": "", "wares": [], "where": where, "n": n}
	var theme: String = open[posmod(n, open.size())]
	var d: Dictionary = THEMES[theme]
	var count := int(MERCHANT["wares" if where == "station" else "camp_wares"])
	count = mini(int(d.get("count", count)), count)
	var wares: Array = []
	match String(d.get("kind", "")):
		"handy":
			var ids: Array = Needs.handy(tower) if tower != "" else []
			ids = ids.filter(func(id): return Items.ITEMS.has(id) and item_price_of(id)[1] > 0)
			var extra: Array = shelf_pool(profile).filter(func(id): return not ids.has(id) and Items.is_sized(id) and item_price_of(id)[0] != "any")
			extra.shuffle()
			ids.shuffle()
			for id in (ids + extra).slice(0, count):
				wares.append(item_ware(profile, id, 3 if Items.is_sized(id) else Items.STANDARD))
		"tinctures":
			var tl := _tinctures()
			tl.shuffle()
			for id in tl.slice(0, count):
				wares.append(item_ware(profile, id, 3 if Items.is_sized(id) and randi() % 3 == 0 else Items.STANDARD))
		"charms":
			var cs: Array = Charms.all()
			cs.shuffle()
			for id in cs.slice(0, count):
				var rar := "rare" if randi() % 100 < 20 else ("fine" if randi() % 100 < 60 else "common")
				if Gear.natural_rarity(id) != "common":
					rar = Gear.natural_rarity(id)
				wares.append(gear_ware(profile, Gear.make(id, rar, Gear.roll_traits(id, rar) if rar != "common" and not Gear.traits_for(Gear.trait_slot(id)).is_empty() else [])))
		"arms":
			var pool: Array = Array(d.get("pool", []))
			pool.shuffle()
			for id in pool.slice(0, count):
				var rar2 := "rare" if randi() % 100 < 25 else "fine"
				wares.append(gear_ware(profile, Gear.make(id, rar2, Gear.roll_traits(id, rar2))))
		"relics":
			var rp: Array = Gear.NAMED_ORDER.filter(func(nm): return String(Gear.NAMED[nm]["rarity"]) == "storied")
			rp.shuffle()
			for nm in rp.slice(0, count):
				wares.append(gear_ware(profile, Gear.make_named(nm)))
	var line_list: Array = LINES["station" if where == "station" else "camp"]
	return {"theme": theme, "name": String(d["name"]), "line": String(d.get("line", "")), "wares": wares, "where": where, "n": n,
		"said": String(line_list[posmod(n, line_list.size())])}


## The name of the theme the pedlar has on a visit (a card's note).
static func theme_name(profile, _where: String, n: int) -> String:
	var open := themes_open(profile)
	if open.is_empty():
		return ""
	return String(THEMES[open[posmod(n, open.size())]]["name"])


## An item for sale: its price at its size, over the outfitter's by the markup.
static func item_ware(_profile, id: String, size: int) -> Dictionary:
	var p := item_price_of(id)
	var amount := maxi(1, int(round(float(sized_amount(int(p[1]), size)) * float(MERCHANT["markup"]))))
	return {"kind": "item", "id": id, "size": size, "price": [String(p[0]), amount], "sold": false}


static func gear_ware(profile, g: Dictionary) -> Dictionary:
	var T = load(TRAIN)
	var amount := maxi(1, int(round(float(T.gear_price(g)) * float(MERCHANT["markup"]))))
	return {"kind": "gear", "code": Gear.code(g), "price": [String(T.gear_kind(g)), amount], "sold": false}


static func item_price_of(id: String) -> Array:
	return load(TRAIN).item_price(id)


## A ware's price for you ([kind, amount]): his markup, less the outfitter's discount.
static func ware_price(profile, ware: Dictionary) -> Array:
	var p: Array = ware["price"]
	var cut: float = float(load(TRAIN).discount(profile))
	return [String(p[0]), maxi(1, int(round(float(p[1]) * (1.0 - cut))))]


static func ware_gear(ware: Dictionary) -> Dictionary:
	return Gear.rec(ware.get("code", "")) if String(ware.get("kind", "")) == "gear" else {}


static func ware_name(ware: Dictionary) -> String:
	if String(ware.get("kind", "")) == "gear":
		return Gear.display(ware_gear(ware))
	return Items.sized_name(String(ware.get("id", "")), int(ware.get("size", Items.STANDARD)))


## Pays a price in crystals of its kind; at a camp (`carried`: the climb's
## unbanked essence, {kind: amount}) what the crystals lack comes from it.
## Returns {paid: {kind: amount}, carried: amount}, or {} if it can't be paid.
static func pay(profile, kind: String, amount: int, carried: Dictionary = {}) -> Dictionary:
	var have := int(profile.crystal_total(kind))
	var from_run := 0
	if have < amount:
		var extra := int(float(carried.get(kind, 0.0)))
		if have + extra < amount:
			return {}
		from_run = amount - have
		amount = have
	if amount > 0 and not profile.spend(kind, float(amount)):
		return {}
	if from_run > 0:
		carried[kind] = maxf(0.0, float(carried.get(kind, 0.0)) - float(from_run))
	return {"paid": {kind: amount}, "carried": from_run}


## Why a ware can't be paid for ("" if it can), `carried` as for pay.
static func short_of(profile, ware: Dictionary, carried: Dictionary = {}) -> String:
	var p := ware_price(profile, ware)
	var have := int(profile.crystal_total(p[0])) + int(float(carried.get(p[0], 0.0)))
	if have >= int(p[1]):
		return ""
	var T = load(TRAIN)
	return T.TEXT["needs"] % [int(p[1]) - have, Essence.display(String(p[0]))]


## Buys a ware at a station: an item goes onto your belt for the next climb,
## a piece into your pack (your stash if the pack is full). "" if bought,
## else why not. `market` is the stall ({wares: [...]}).
static func buy_station(profile, player, market: Dictionary, i: int) -> String:
	var wares: Array = market.get("wares", [])
	if i < 0 or i >= wares.size() or bool(wares[i].get("sold", false)):
		return String(TEXT["empty"])
	var w: Dictionary = wares[i]
	var T = load(TRAIN)
	var why := short_of(profile, w)
	if why != "":
		return why
	if String(w["kind"]) == "item":
		var id := String(w["id"])
		if T.supply_room(profile, player, id) <= 0:
			return String(TEXT["belt_full"])
		var p := ware_price(profile, w)
		var got := pay(profile, p[0], int(p[1]))
		if got.is_empty():
			return short_of(profile, w)
		T.pack_supply(profile, id, got["paid"], int(w.get("size", Items.STANDARD)))
	else:
		var g := ware_gear(w)
		if T.pack_room(profile, player) <= 0 and profile.chest.size() >= T.CHEST_SIZE:
			return String(TEXT["pack_full"])
		var p2 := ware_price(profile, w)
		var got2 := pay(profile, p2[0], int(p2[1]))
		if got2.is_empty():
			return short_of(profile, w)
		if T.pack_room(profile, player) > 0:
			profile.pack.append(g)
		else:
			profile.chest.append(g)
	w["sold"] = true
	profile.save()
	return ""


## The stall at the station, kept with the climber for the visit (a new one
## every time you arrive: Renown's visits count it), as {theme, wares...}.
static func station_market(profile, tower := "") -> Dictionary:
	var r := Renown.state(profile)
	var visit := int(r.get("visits", 0))
	var m: Dictionary = r.get("market", {}) if r.get("market", {}) is Dictionary else {}
	if m.is_empty() or int(m.get("n", -1)) != visit or String(m.get("where", "")) != "station":
		m = roll_merchant(profile, "station", visit, tower)
		r["market"] = m
		profile.save()
	return m
