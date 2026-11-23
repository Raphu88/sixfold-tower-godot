extends RefCounted
## The basic sword and bow: the plain Sword and Shortbow a new climber
## starts with (weapons.gd START_MELEE, START_RANGED). They're real pieces:
## worn, kept in the stash or lost like anything else, and nothing puts
## them back by itself. They're never for sale (no shop stocks them, and no
## shop buys them), because they're gifts:
##
## When the climber falls (or a climb ends any way but getting out alive:
## a restart, the game closed mid-climb) and comes back to the train with
## no melee weapon, {outfitter} gives them the basic sword; with no ranged
## weapon, the basic bow. A copy already in the stash (or pack) is put on
## instead of a new one, so they never pile up, and a climber always comes
## back able to fight. A new climber (and Start over) starts with them as
## before, in the slots their past leaves empty (new_start.gd).
##
## A plain Common sword or shortbow found in the tower is the same piece.
## On the train its words show once, at the top of your car (train_page.gd),
## with the Entity's first-time tip (entity.gd TIPS "basic_gift").
##
## Names and words live here so they're easy to change.

const Gear := preload("res://scripts/gear.gd")
const OutfitterName := preload("res://scripts/outfitter_name.gd")

## The slots a gift fills, in order.
const SLOTS := ["melee", "ranged"]

static var TEXT: Dictionary = OutfitterName.named({
	# What he gives, by slot (%s: the piece's name, lower case).
	"gift": "a plain %s",
	"own": "your plain %s",
	"and": " and ",
	# On the fall screen.
	"fall": "On the train, {outfitter} will have %s ready for you.",
	# His words at the top of your car, the first visit after.
	"given": "Back with empty hands? Here: %s. Nobody leaves my train bare-handed. It's a gift, so don't try selling it back to me.",
	"stashed": "Your hands were empty, so I took %s out of your stash and hung it ready.",
	# On a basic piece's card (the Loadout, the stash, the bench).
	"note": "A plain piece. {outfitter} gives one to any climber who falls without one, so it can't be sold.",
})


## The basic piece for a slot ("melee" or "ranged"), fresh; {} for another slot.
static func piece(slot: String) -> Dictionary:
	match slot:
		"melee":
			return Gear.make(Gear.Weapons.START_MELEE)
		"ranged":
			return Gear.make(Gear.Weapons.START_RANGED)
	return {}


## What a new climber starts with on the train: the basic sword and bow
## (carried slot -> record), as the Loadout's chosen pieces.
static func kit() -> Dictionary:
	var out := {}
	for s in SLOTS:
		out[s] = piece(s)
	return out


## Is this the basic sword or bow (a plain Common Sword or Shortbow, however worn)?
static func is_basic(g) -> bool:
	if not Gear.is_gear(g):
		return false
	for s in SLOTS:
		if Gear.same(g, piece(s)):
			return true
	return false


## Is a base id one of them (the shops leave these off their rails)?
static func is_basic_base(id: String) -> bool:
	return id == Gear.Weapons.START_MELEE or id == Gear.Weapons.START_RANGED


## Does the climber wear a weapon in this slot on the train: chosen to wear
## (profile.wear) or an heirloom?
static func covered(profile, slot: String) -> bool:
	var w = profile.wear.get(slot, {})
	if Gear.is_gear(w) and Gear.slot_of(w) == slot:
		return true
	return Gear.heirloom_pieces(profile.heirlooms, slot).any(func(h): return Gear.slot_of(h) == slot)


## The index of a basic piece for this slot in a list (-1 for none).
static func copy_in(list: Array, slot: String) -> int:
	var want := piece(slot)
	for i in list.size():
		if Gear.is_gear(list[i]) and Gear.same(list[i], want):
			return i
	return -1


## Fills what the climber lacks: for each slot nothing is worn in, a basic
## copy from the stash or pack goes on, else a new one is given. Returns
## {"given": [slots], "stash": [slots]}. Doesn't save.
static func give(profile) -> Dictionary:
	var out := {"given": [], "stash": []}
	for s in SLOTS:
		if covered(profile, s):
			continue
		var took := false
		for list in [profile.chest, profile.pack]:
			var i := copy_in(list, s)
			if i >= 0:
				profile.wear[s] = Gear.rec(list[i])
				list.remove_at(i)
				out["stash"].append(s)
				took = true
				break
		if not took:
			profile.wear[s] = piece(s)
			out["given"].append(s)
	return out


## A fall (main.gd on_player_died): what's lacking is given, the words kept
## for the train (profile.gift "said"), and the line for the fall screen
## returned ("" if nothing was needed). Saves.
static func on_fall(profile) -> String:
	profile.gift.erase("out")
	var got := give(profile)
	if got["given"].is_empty() and got["stash"].is_empty():
		profile.save()
		return ""
	profile.gift["said"] = got
	profile.save()
	var names: Array = []
	for s in got["given"]:
		names.append(_name(s, "gift"))
	for s in got["stash"]:
		names.append(_name(s, "own"))
	return TEXT["fall"] % String(TEXT["and"]).join(names)


## Departing for a tower (train.gd pack_up): what you wear is out on the climb.
static func departing(profile) -> void:
	profile.gift["out"] = true


## Getting out alive (main.gd bring_worn_home): what you wore came home.
static func home(profile) -> void:
	profile.gift.erase("out")


## A new climb's scene starting (main.gd _ready): a climb that ended without
## a fall or getting out (a restart, the game closed mid-climb) counts as a
## fall here. True if anything was given.
static func on_arrival(profile) -> bool:
	if not bool(profile.gift.get("out", false)):
		return false
	return on_fall(profile) != ""


## His words for the gift, once (then forgotten): "" if there's none.
static func take_line(profile) -> String:
	var got = profile.gift.get("said", null)
	if not (got is Dictionary):
		return ""
	profile.gift.erase("said")
	profile.save()
	var said: Array = []
	var given: Array = Array(got.get("given", [])).map(func(s): return _name(String(s), "gift"))
	var stash: Array = Array(got.get("stash", [])).map(func(s): return _name(String(s), "own"))
	if not given.is_empty():
		said.append(TEXT["given"] % String(TEXT["and"]).join(given))
	if not stash.is_empty():
		said.append(TEXT["stashed"] % String(TEXT["and"]).join(stash))
	return " ".join(said)


## An old save (from before the gift): it always had the sword and bow, so
## a slot nothing is worn in gets one, unless a copy is kept already.
static func adopt_old(profile) -> void:
	for s in SLOTS:
		if not covered(profile, s) and copy_in(profile.chest, s) < 0 and copy_in(profile.pack, s) < 0:
			profile.wear[s] = piece(s)


static func _name(slot: String, how: String) -> String:
	return String(TEXT[how]) % Gear.display(piece(slot)).to_lower()
