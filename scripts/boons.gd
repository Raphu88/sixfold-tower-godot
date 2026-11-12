extends RefCounted
## BOONS: lasting gifts bought at the station's shrine (station_page.gd),
## kept with each climber (renown.gd state "boons": id -> level) and with
## them on every climb from then on.
##
## Each boon is unlocked by a renown rank (renown.gd RANKS) and bought with
## crystals of one kind, a level at a time (each level costs `price` times
## the level). What a boon does:
##   fx          numbers added to what your worn gear adds (player.gd
##               boon_fx, read in refresh_gear): "health", "stamina",
##               "walk" (move speed), "strike" (melee damage), "belt" (kinds
##               the belt holds), per level
##   start_item  an item every climb starts with (on departing, main.gd)
##   first_find  on the first floor a piece of gear waits near the start,
##               this many rarity rows higher than usual
##   discount    the outfitter charges this much less (per level; train.gd)
## Every name, number and word is here (and in the Data editor).

const Renown := preload("res://scripts/renown.gd")

static var BOONS := {
	"vigor": {"name": "Vigor", "desc": "+10 health on every climb, each level.", "fx": {"health": 10.0}, "levels": 3, "kind": "stone", "price": 40, "rank": 0},
	"deep_breath": {"name": "Deep Breath", "desc": "+15 stamina on every climb, each level.", "fx": {"stamina": 15.0}, "levels": 2, "kind": "iron", "price": 45, "rank": 1},
	"satchel": {"name": "Satchel", "desc": "Every climb starts with an extra Healing Draught on your belt.", "start_item": "draught", "levels": 1, "kind": "water", "price": 60, "rank": 1},
	"fleetfoot": {"name": "Fleetfoot", "desc": "You move 4% faster, each level.", "fx": {"walk": 0.04}, "levels": 2, "kind": "air", "price": 50, "rank": 2},
	"whetstone": {"name": "Whetstone", "desc": "Your melee strikes deal 6% more, each level.", "fx": {"strike": 0.06}, "levels": 2, "kind": "blade", "price": 55, "rank": 2},
	"haggler": {"name": "Haggler's Charm", "desc": "The outfitter charges 5% less, each level.", "discount": 0.05, "levels": 2, "kind": "fire", "price": 70, "rank": 2},
	"wide_belt": {"name": "Wide Belt", "desc": "Your belt holds one more kind of item.", "fx": {"belt": 1.0}, "levels": 1, "kind": "iron", "price": 90, "rank": 3},
	"keen_eye": {"name": "Keen Eye", "desc": "On every climb's first floor, a finer piece of gear waits near the start.", "first_find": 1, "levels": 1, "kind": "air", "price": 80, "rank": 3},
}
## The order the shrine lists them in.
static var ORDER := ["vigor", "deep_breath", "satchel", "fleetfoot", "whetstone", "haggler", "wide_belt", "keen_eye"]

static var TEXT := {
	"level": "Level %d of %d",
	"none": "Not yet bought",
	"max": "Fully bought",
	"buy": "Buy level %d",
	"bought": "The shrine grants it: %s, level %d",
	"locked": "Unlocks at the rank of %s",
	"needs": "needs %d more %s",
	"keen_eye": "Keen Eye: a piece waits for you",
}


static func level(profile, id: String) -> int:
	return int(Renown.state(profile)["boons"].get(id, 0))


static func unlocked(profile, id: String) -> bool:
	return BOONS.has(id) and Renown.rank(profile) >= int(BOONS[id].get("rank", 0))


## The next level's price: [kind, amount] (amount 0 once fully bought).
static func price(profile, id: String) -> Array:
	var b: Dictionary = BOONS.get(id, {})
	var lv := level(profile, id)
	if b.is_empty() or lv >= int(b.get("levels", 1)):
		return [String(b.get("kind", "stone")), 0]
	return [String(b["kind"]), int(b["price"]) * (lv + 1)]


## Why the next level can't be bought, in words ("" if it can).
static func why_not(profile, id: String) -> String:
	if not BOONS.has(id):
		return "?"
	if not unlocked(profile, id):
		return TEXT["locked"] % Renown.rank_name(int(BOONS[id]["rank"]))
	var p := price(profile, id)
	if int(p[1]) <= 0:
		return TEXT["max"]
	var have := int(profile.crystal_total(p[0]))
	if have < int(p[1]):
		return TEXT["needs"] % [int(p[1]) - have, load("res://scripts/essence.gd").display(p[0])]
	return ""


## Buys the next level of a boon. "" if bought, else why not. Saves.
static func buy(profile, id: String) -> String:
	var why := why_not(profile, id)
	if why != "":
		return why
	var p := price(profile, id)
	profile.spend(p[0], int(p[1]))
	var boons: Dictionary = Renown.state(profile)["boons"]
	boons[id] = level(profile, id) + 1
	profile.save()
	return ""


## Everything the boons bought add to the climber's numbers (player.gd
## boon_fx): {key: amount}.
static func fx(profile) -> Dictionary:
	var out := {}
	for id in BOONS:
		var lv := level(profile, id)
		if lv <= 0:
			continue
		var f: Dictionary = BOONS[id].get("fx", {})
		for k in f:
			out[k] = float(out.get(k, 0.0)) + float(f[k]) * lv
	return out


## The outfitter's discount from boons (0 to 1).
static func discount(profile) -> float:
	var d := 0.0
	for id in BOONS:
		d += float(BOONS[id].get("discount", 0.0)) * level(profile, id)
	return clampf(d, 0.0, 0.9)


## Puts the boons on the climber (their health, stamina and the rest): at
## the start of every climb's scene and whenever one is bought.
static func apply(profile, player) -> void:
	if player == null or not ("boon_fx" in player):
		return
	player.boon_fx = fx(profile)
	player.refresh_gear()


## Leaving the train for a tower (main.gd choose_tower): the items boons
## give go on the belt, and a Keen Eye's piece waits on the first floor.
static func on_depart(main) -> void:
	var profile = main.profile
	var player = main.player
	if profile == null or player == null:
		return
	for id in BOONS:
		var lv := level(profile, id)
		if lv <= 0:
			continue
		var b: Dictionary = BOONS[id]
		var item := String(b.get("start_item", ""))
		if item != "":
			for i in lv:
				player.add_item(item)
		var rows := int(b.get("first_find", 0))
		if rows > 0 and main.has_method("find_gear") and main.has_method("drop_gear"):
			var at: Vector2 = player.global_position + Vector2(46, -30)
			if main.has_method("walkable_point"):
				at = main.walkable_point(player.global_position, at, 14.0)
			main.drop_gear(at, main.find_gear("", rows * lv), true)
			main.fx_text(at + Vector2(0, -30), TEXT["keen_eye"], Color(0.95, 0.85, 0.55))
