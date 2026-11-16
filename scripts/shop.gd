extends RefCounted
## SHOP VARIETY: what the Outfitter's Car stocks. Everything here is data (a table, a number or a
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
## likelier, "item" puts one supply on the shelf for you. "line" is said on
## the rail. What a title takes off his prices, and his better pieces for
## it, are the title's outfitter benefits (titles.gd SOCIAL "outfitter").
## (The Pedlar who once set up at stations and camps is gone: the Noble
## took his place at the station, noble.gd.)

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
## (What a title takes off his prices is its outfitter benefit: titles.gd SOCIAL.)
static var TITLE_STOCK := {
	"newcomer": {"line": "For the Newcomer: plain pieces, fairly priced.", "tilt": {"slots": ["melee", "armor"], "weight": 1.5}},
	"trainee": {"line": "For the Trainee: plain weapons, well made.", "tilt": {"slots": ["melee"], "weight": 2.0}, "item": "tonic"},
	"contender": {"line": "For the Contender: blades and pistols hang first.", "tilt": {"groups": ["blades", "guns"], "weight": 3.0}, "item": "edge_oil"},
	"beastfeller": {"line": "For Beastfeller: spears, axes and bows hang first.", "tilt": {"groups": ["heavy", "bows"], "ids": ["spear"], "weight": 3.0}, "item": "fire_flask"},
	"shieldmate": {"line": "For Shieldmate: armour and packs hang first.", "tilt": {"slots": ["armor", "backpack"], "weight": 2.5}},
	"helping_hand": {"line": "For the Helping Hand: draughts and pouches first.", "tilt": {"groups": ["trade"], "weight": 2.5}, "item": "draught"},
	"stairworn": {"line": "For the Stairworn: boots, leggings and packs hang first.", "tilt": {"slots": ["boots", "legs", "backpack"], "weight": 3.0}, "item": "stamina"},
	"surefoot": {"line": "For Surefoot: boots and cloaks hang first.", "tilt": {"slots": ["boots", "cloak"], "weight": 3.0}, "item": "gale_feather"},
	"duelist": {"line": "For the Duelist: blades hang first.", "tilt": {"groups": ["blades"], "weight": 3.0}, "item": "edge_oil"},
	"trusted": {"line": "For the Trusted: charms and rings hang first.", "tilt": {"slots": ["charm", "ring"], "weight": 3.0}},
	"ironclad": {"line": "For Ironclad: armour hangs first.", "tilt": {"slots": ["armor", "helm", "gloves", "legs", "boots"], "weight": 3.0}, "item": "stoneskin"},
	"goldhand": {"line": "For Goldhand: rings, pendants and charms hang first.", "tilt": {"slots": ["ring", "amulet", "charm"], "weight": 3.0}},
	"glassbreaker": {"line": "For Glassbreaker: pistols and crossbows hang first.", "tilt": {"groups": ["guns", "bows"], "weight": 4.0}, "item": "flare"},
	"champion": {"line": "For the Champion: blades and armour hang first, and he takes a little off.", "tilt": {"groups": ["blades"], "slots": ["armor", "helm"], "weight": 3.0}},
	"talked_of": {"line": "For the Talked-of: trade goods hang first, and he takes a little off.", "tilt": {"groups": ["trade"], "slots": ["charm"], "weight": 3.0}},
	"paragon": {"line": "For the Paragon: his finest pieces hang first, and he takes a little off.", "tilt": {"slots": ["charm", "amulet", "ring", "armor"], "weight": 3.0}},
}

static var TEXT := {
	"rail_title": "Rail",
	"page": "Page %d of %d",
	"title_line": "For %s",
	"shelf_title": "For %s: %s",
	"minor": "Minor", "greater": "Greater",
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
	return clampf(load("res://scripts/titles.gd").num(profile, "outfitter", "discount"), 0.0, 0.5)


## More Fine-or-better pieces kept on the rail for the worn title (its
## outfitter benefit "first_look").
static func title_first_look(profile) -> int:
	return clampi(int(load("res://scripts/titles.gd").num(profile, "outfitter", "first_look")), 0, 4)


## Does the worn title bring today's piece a rarity higher (its outfitter benefit "today")?
static func title_today(profile) -> bool:
	return load("res://scripts/titles.gd").flag(profile, "outfitter", "today")


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
