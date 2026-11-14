extends RefCounted
## What each tower asks of your belt: one or two items that are clearly
## useful there, and why (its monsters, its floors). Every word and number
## is here, in data (the Data editor: "Towers and rooms" and "Items" sections).
##
## What reads it:
##   items.gd random_item     a tower's handy items are found more often there
##                            (and a handy item that monsters elsewhere never
##                            leave, like Heartroot, is found there too)
##   main.gd _greet           the arrival banner names them ("Handy here: ...")
##   main.gd _start_floor     a dark floor (DARK) dims the light and says so
##   lighting.gd player_reach your light reaches less far on a dark floor
##   train_page.gd            the Outfitter's shelf notes where an item is handy
##   entity_talk.gd           "What's handy in this tower?"
##
## The items' own effects (items.gd ITEMS) are what make them handy: a net
## brings a flier down, Edge Oil cracks shells and rocks guards, Lantern Oil
## carries your light, Antivenom, Warding Oil, Briar Tonic and Stoneskin keep
## a state off you (reactions.gd CLIMBER), and a Cleansing Tonic or Heartroot
## takes one away.

## Per tower: "items" (handy items, by id) and "why" (a short reason each,
## said by the Entity and on the Outfitter's shelf).
static var NEEDS := {
	"gryphon": {"items": ["net", "stoneskin"],
		"why": {"net": "bats and harriers fly; a net brings one down where your blade can reach",
			"stoneskin": "the wind and the harriers shove you toward the drops, and thunderlings leave you charged; stone keeps your feet and grounds the charge"}},
	"kraken": {"items": ["lantern_oil", "edge_oil"],
		"why": {"lantern_oil": "from the fourth floor the flooded halls are dark; Lantern Oil lets your light reach",
			"edge_oil": "shellbacks turn light blows from the front; oiled strikes crack their shells"}},
	"wyvern": {"items": ["warding_oil", "edge_oil"],
		"why": {"warding_oil": "cinders and the Wyvern set you burning; Warding Oil puts it out and keeps it off",
			"edge_oil": "knights shrug off light blows; oiled strikes land like heavy ones and rock them"}},
	"manticore": {"items": ["antidote", "tonic"],
		"why": {"antidote": "scorplings and the Manticore poison you; Antivenom cures it and keeps it off",
			"tonic": "a Cleansing Tonic cures the poison, and anything else on you"}},
	"firebird": {"items": ["net", "tonic"],
		"why": {"net": "wisps and ashwings fly over the abyss; a net brings one down",
			"tonic": "ashwings set you burning and bloomcaps poison you; a Cleansing Tonic takes both off"}},
	"chimera": {"items": ["briar_tonic", "heartroot"],
		"why": {"briar_tonic": "thornhounds and mongrels hunt in packs and leave you bleeding; Briar Tonic keeps it off and bites back",
			"heartroot": "Heartroot stops a bleed, and every kill in a pack heals you"}},
}

## Dark floors: in a tower listed here, from floor "from" on, the light you
## carry reaches only "reach" as far, and unlit places are "fog" dark (the
## darkness's own alpha, 0 to 1). Lantern Oil (and Flare Powder) answer it.
static var DARK := {
	"kraken": {"from": 4, "reach": 0.7, "fog": 0.86},
}

static var TEXT := {
	"arrival": "Handy here: %s",
	"dark": "The deep floors are dark. Lantern Oil carries your light.",
	"shelf": "Handy in %s",
	"shelf_why": "Handy in %s: %s",
	"none": "Nothing in particular. Healing and Stamina Draughts, as everywhere.",
	"talk": "In %s: %s.",
}


## The tower's handy items (ids), [] for none.
static func handy(tower: String) -> Array:
	return Array(NEEDS.get(tower, {}).get("items", []))


## Why an item is handy in a tower ("" if it isn't).
static func why(tower: String, id: String) -> String:
	return String(NEEDS.get(tower, {}).get("why", {}).get(id, ""))


## The towers (ids, in towers.gd order) where an item is handy.
static func towers_for(id: String, order: Array) -> Array:
	return order.filter(func(t): return id in handy(String(t)))


## The arrival banner's line: "Handy here: Throwing Net, Stoneskin Draught" ("" for none).
static func arrival_line(tower: String) -> String:
	var Items = load("res://scripts/items.gd")
	var names: Array = handy(tower).filter(func(id): return Items.ITEMS.has(id)).map(func(id): return String(Items.ITEMS[id]["name"]))
	return String(TEXT["arrival"]) % ", ".join(names) if not names.is_empty() else ""


## How dark this floor is: {} for an ordinary one, else DARK's row.
static func darkness(tower: String, floor_num: int) -> Dictionary:
	var d: Dictionary = DARK.get(tower, {})
	if d.is_empty() or floor_num < int(d.get("from", 999)):
		return {}
	return d


## How far your light reaches on this floor (1 for an ordinary one).
static func reach(tower: String, floor_num: int) -> float:
	var d := darkness(tower, floor_num)
	return float(d.get("reach", 1.0)) if not d.is_empty() else 1.0
