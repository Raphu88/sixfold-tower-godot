extends RefCounted
## The bench in the workshop car (train.gd), between climbs. Its counters:
##   brew      make a consumable, packed onto your belt for your next climb
##             (anyone can; a Rune Artist brews for less)
##   temper    raise a piece's rank, +1 to +3 (Rune Artist)
##   retrait   swap one trait for a new one of the essence you pay (Rune Artist)
##   join      two Fine pieces for the same slot become one Rare (Rune Artist)
##   break     a piece or a packed item becomes a crystal of its kind, as the
##             store's Sell does
##   inscribe  a lasting rune on a piece, at half the Inscribe spell's
##             strength (Rune Artist; gear.gd LASTING_RUNES)
##   recall    bind a recall scroll (Rune Artist; carry 1)
##   vessel    brew a vessel, or work a full one into a piece (Rune Artist;
##             vessel.gd, vessel_page.gd)
## The Rune Artist is the master crafter: given the essence and the skill,
## they can make pretty much anything. Without that bond the enchanting
## counters stay greyed, and say a Rune Artist could do it.
##
## The bench works on your heirlooms and on the pieces in your pack and
## chest. A piece is named by a "ref": "heir:melee", "heir:rings:1",
## "pack:2" or "chest:0".
##
## Essence crystals are the only currency, paid as the store pays
## (profile.gd spend: from your crystal of that kind). Every cost here is
## {kind: amount}. Names, words and
## numbers live here so they're easy to change.

const Gear := preload("res://scripts/gear.gd")
const Items := preload("res://scripts/items.gd")
const Essence := preload("res://scripts/essence.gd")
const Train := preload("res://scripts/train.gd")

## The bond that enchants (bonds.gd).
const RUNE_ARTIST := "rune_artist"
## The counters, in order: [id, name, short name (a phone)].
const COUNTERS := [
	["brew", "Brew", "Brew"], ["temper", "Temper", "Temper"], ["retrait", "Retrait", "Retrait"], ["join", "Join", "Join"],
	["break", "Break down", "Break"], ["inscribe", "Inscribe", "Inscribe"], ["recall", "Recall scroll", "Recall"],
	["vessel", "Vessel", "Vessel"],
]
## Counters only a Rune Artist can use. (The vessel's counter: brewing one,
## and working a full one into a piece; vessel.gd holds its rules.)
const RUNE_ARTIST_ONLY := ["temper", "retrait", "join", "inscribe", "recall", "vessel"]

## Brewing: what each consumable costs at the bench (a little less than the
## store asks: you do the work; the basic supplies follow the store's
## halved prices, train.gd SUPPLY_PRICE). The recall scroll is only for a Rune Artist.
const BREW := {
	"draught": {"stone": 5}, "tonic": {"water": 4}, "vial": {"water": 16}, "smoke": {"fire": 4},
	"fire_flask": {"fire": 10}, "edge_oil": {"blade": 12}, "warding_oil": {"iron": 12}, "haste": {"air": 10},
	"stoneskin": {"stone": 10}, "salts": {"iron": 4}, "flare": {"air": 3},
	"scroll": {"air": 30, "water": 30},
}
## A Rune Artist brews for this share of the cost.
const RUNE_ARTIST_BREW := 0.8

## Tempering to +1, +2, +3: the essence of the piece's kind (its trait's),
## times its rarity's TEMPER_RARITY. +2 and +3 also need that much density
## of the kind settled in you (profile.gd density).
const TEMPER := [20, 45, 80]
const TEMPER_RARITY := {"common": 1.0, "fine": 1.0, "rare": 1.5, "storied": 2.0, "regarded": 2.0}
const TEMPER_DENSITY := [0, 100, 300]
## Retrait: this much of the new trait's kind (times RETRAIT_RARE on Rare and better).
const RETRAIT := 15
const RETRAIT_RARE := 2.0
## Join: this much of the first piece's trait's kind.
const JOIN := 30
## Inscribe: a lasting rune for this.
const INSCRIBE := {"iron": 25}

## The words of the bench.
const TEXT := {
	"title": "The bench",
	"rune_artist": "Rune Artist",
	"needs_rune_artist": "Only a Rune Artist can %s. A Rune Artist could do it here, given the essence.",
	"verbs": {"temper": "temper a piece", "retrait": "swap a trait", "join": "join two pieces", "inscribe": "inscribe a lasting rune", "recall": "bind a recall scroll", "vessel": "brew a vessel or work a full one into a piece"},
	"notes": {
		"brew": "Anyone can brew. What you make is packed onto your belt for your next climb.",
		"temper": "Raise a piece's rank, +1 to +3. Each rank makes its traits 25% stronger (of their base), and a weapon hit 4% harder.",
		"retrait": "Swap one trait. The crystal you pay chooses the essence of the new trait.",
		"join": "Two Fine pieces for the same slot, a trait on each, become one Rare piece with both traits.",
		"break": "A piece from your pack or chest, or a packed item, becomes a crystal of its kind at 40% of its price.",
		"inscribe": "A lasting rune on one piece: it stays on it, at half the strength of the Inscribe spell.",
		"recall": "Bind a recall scroll for your next climb: read it in the tower to leave safely, keeping everything. You carry one.",
		"vessel": "Brew a vessel that catches the secret essence that isn't your path, or work a full one into a piece: one rank past +3, or a deep rune.",
	},
	"heirlooms": "Heirlooms",
	"pack": "Your pack",
	"chest": "Storage chest",
	"packed_items": "Packed for your next climb",
	"where_heir": "Your heirloom: every climb begins with it.",
	"where_pack": "In your pack.",
	"where_chest": "In your storage chest.",
	"nothing": "Nothing here to work on. Bring pieces home in your pack, or keep an heirloom.",
	"nothing_join": "Nothing to join: you need two Fine pieces for the same slot, each with a trait.",
	"nothing_break": "Nothing to break down. Bring finds home in your pack, or pack some supplies.",
	"cost": "Costs",
	"rune_artist_less": "A Rune Artist brews for %d%% less.",
	"brew": "Brew",
	"bind": "Bind a recall scroll",
	"brewed": "Brewed: %s, packed for your next climb",
	"cant": "Can't: %s",
	"packed": "Packed for your next climb: %d  ·  your belt holds %d",
	"put_back": "Put one back (what you paid comes back)",
	"put_back_done": "Put back: %s",
	"belt_full": "your belt can't hold more",
	"rank": "Rank +%d of +%d",
	"rank_top": "Rank +%d: tempered as far as it goes.",
	"no_temper": "Nothing on it to temper: it has no trait, and isn't a weapon.",
	"temper_to": "Temper to +%d",
	"temper_ask": "Tap again to temper to +%d",
	"tempered": "Tempered: %s",
	"weapon_rank": "Hits %s harder (rank +%d)",
	"density": "needs %d %s density (you have %d)",
	"retrait_which": "Replace:",
	"retrait_kind": "%s · %d",
	"retrait_ask": "Tap again: %s · %d",
	"retrait_gives": "%s gives %s",
	"retraited": "Retraited: %s (was %s)",
	"no_retrait": "No trait to swap: only pieces with a trait can be retraited.",
	"no_new_trait": "no other trait of that essence fits this slot",
	"join_with": "Join with %s",
	"join_ask": "Tap again to join with %s",
	"join_makes": "Makes a Rare %s with %s.",
	"joined": "Joined: %s",
	"no_join": "Only a Fine piece with a trait can be joined.",
	"no_partner": "No other Fine piece for this slot with a trait. Find one, or buy today's piece.",
	"break_for": "Break down for %d %s",
	"break_ask": "Tap again to break down for %d %s",
	"broke": "Broken down: %s for %s",
	"break_heir": "Heirlooms aren't broken down here: keep a new piece for the slot to replace it.",
	"rune_on": "Inscribed: %s",
	"inscribe": "%s",
	"inscribe_ask": "Tap again: %s",
	"inscribed": "Inscribed: %s on %s",
	"replaces_rune": "A new rune replaces the one on it.",
	"scroll_carry": "You carry one recall scroll at a time.",
}


# --- who can do what ------------------------------------------------------------------

## Do you carry the Rune Artist's mark?
static func rune_artist(profile) -> bool:
	for part in profile.bonds:
		if String(profile.bonds[part].get("id", "")) == RUNE_ARTIST:
			return true
	return false


## Why a counter can't be used: "" if it can, else a plain line.
static func locked(profile, counter: String) -> String:
	if counter in RUNE_ARTIST_ONLY and not rune_artist(profile):
		return TEXT["needs_rune_artist"] % TEXT["verbs"][counter]
	return ""


# --- costs and paying -------------------------------------------------------------------

## Why a cost can't be paid, in words ("needs 12 more Fire, needs 4 more
## Air"), or "" if it can.
static func short_of(profile, cost: Dictionary) -> String:
	var out: Array = []
	for k in cost:
		var why := Train.short_of(profile, k, int(cost[k]))
		if why != "":
			out.append(why)
	return ", ".join(out)


## Pays a cost (every kind, or nothing). "" if paid, else why not.
static func pay(profile, cost: Dictionary) -> String:
	var why := short_of(profile, cost)
	if why != "":
		return why
	for k in cost:
		profile.spend(k, float(cost[k]))
	return ""


static func cost_text(cost: Dictionary) -> String:
	var out: Array = []
	for k in cost:
		out.append(Train.price_text(k, int(cost[k])))
	return " + ".join(out)


# --- the pieces it works on --------------------------------------------------------------

## Every piece the bench can work on, as refs: heirlooms (in the doll's
## order), then your pack, then your chest.
static func pieces(profile, heirlooms := true) -> Array:
	var out: Array = []
	if heirlooms:
		for hs in Gear.HEIRLOOM_SLOTS:
			var list := Gear.heirloom_pieces(profile.heirlooms, hs["id"])
			for i in list.size():
				out.append("heir:" + hs["id"] + (":%d" % i if hs["id"] == "rings" else ""))
	for i in profile.pack.size():
		out.append("pack:%d" % i)
	for i in profile.chest.size():
		out.append("chest:%d" % i)
	return out


## The piece a ref names (a record), or {}.
static func piece(profile, ref: String) -> Dictionary:
	var where := ref.get_slice(":", 0)
	match where:
		"heir":
			var list := Gear.heirloom_pieces(profile.heirlooms, ref.get_slice(":", 1))
			var i := int(ref.get_slice(":", 2)) if ref.get_slice_count(":") > 2 else 0
			return list[i] if i < list.size() else {}
		"pack", "chest":
			var list: Array = profile.pack if where == "pack" else profile.chest
			var i := int(ref.get_slice(":", 1))
			return Gear.rec(list[i]) if i >= 0 and i < list.size() else {}
	return {}


## Puts a changed piece back where the ref names.
static func put(profile, ref: String, g: Dictionary) -> void:
	var where := ref.get_slice(":", 0)
	if where == "heir":
		var hs := ref.get_slice(":", 1)
		if hs == "rings":
			var list: Array = Gear.heirloom_pieces(profile.heirlooms, hs)
			var i := int(ref.get_slice(":", 2))
			if i < list.size():
				list[i] = g
				profile.heirlooms[hs] = list
		else:
			profile.heirlooms[hs] = g
	elif where == "pack" or where == "chest":
		var list: Array = profile.pack if where == "pack" else profile.chest
		var i := int(ref.get_slice(":", 1))
		if i >= 0 and i < list.size():
			list[i] = g


## Takes a piece away from where the ref names.
static func remove(profile, ref: String) -> void:
	var where := ref.get_slice(":", 0)
	if where == "heir":
		var hs := ref.get_slice(":", 1)
		if hs == "rings":
			var list: Array = Gear.heirloom_pieces(profile.heirlooms, hs)
			var i := int(ref.get_slice(":", 2))
			if i < list.size():
				list.remove_at(i)
			if list.is_empty():
				profile.heirlooms.erase(hs)
			else:
				profile.heirlooms[hs] = list
		else:
			profile.heirlooms.erase(hs)
	elif where == "pack" or where == "chest":
		var list: Array = profile.pack if where == "pack" else profile.chest
		var i := int(ref.get_slice(":", 1))
		if i >= 0 and i < list.size():
			list.remove_at(i)


# --- brewing --------------------------------------------------------------------------------

## What the bench brews for you, in order (the recall scroll is its own counter).
static func brews() -> Array:
	return Items.ORDER.filter(func(id): return BREW.has(id) and id != "scroll")


## What brewing one costs you ({kind: amount}): a Rune Artist pays less
## (but the recall scroll, only theirs to bind, costs what it costs).
static func brew_cost(profile, id: String) -> Dictionary:
	var base: Dictionary = BREW.get(id, {})
	var out := {}
	var k := RUNE_ARTIST_BREW if rune_artist(profile) and id != "scroll" else 1.0
	for kind in base:
		out[kind] = maxi(1, int(round(float(base[kind]) * k)))
	return out


## Brews one consumable, packed for your next climb. "" if brewed, else why not.
static func brew(profile, player, id: String) -> String:
	if not BREW.has(id):
		return TEXT["belt_full"]
	if id == "scroll":
		var lock := locked(profile, "recall")
		if lock != "":
			return lock
	if Train.supply_room(profile, player, id) <= 0:
		return TEXT["belt_full"] if id != "scroll" else TEXT["scroll_carry"].to_lower().trim_suffix(".")
	var cost := brew_cost(profile, id)
	var why := pay(profile, cost)
	if why != "":
		return why
	Train.pack_supply(profile, id, cost)
	profile.save()
	return ""


# --- tempering --------------------------------------------------------------------------------

## Can this piece be tempered at all (a trait to strengthen, or a weapon)?
static func temperable(g) -> bool:
	var r := Gear.rec(g)
	if r.is_empty():
		return false
	return not r["traits"].is_empty() or Gear.slot_of(r) in ["melee", "ranged"]


## What tempering a piece to its next rank costs ({kind: amount}; {} at +3).
static func temper_cost(g) -> Dictionary:
	var r := Gear.rec(g)
	var k := int(r.get("rank", 0))
	if r.is_empty() or k >= Gear.MAX_RANK:
		return {}
	return {Train.gear_kind(r): int(round(float(TEMPER[k]) * float(TEMPER_RARITY.get(r["rarity"], 1.0))))}


## Why the next rank needs more density, in words, or "".
static func density_short(profile, g) -> String:
	var r := Gear.rec(g)
	var k := int(r.get("rank", 0))
	if r.is_empty() or k >= Gear.MAX_RANK:
		return ""
	var need := int(TEMPER_DENSITY[k])
	var kind := Train.gear_kind(r)
	var have := int(profile.density.get(kind, 0.0))
	if have >= need:
		return ""
	return TEXT["density"] % [need, Essence.display(kind), have]


## Why a piece can't be tempered now, or "".
static func temper_why(profile, ref: String) -> String:
	var lock := locked(profile, "temper")
	if lock != "":
		return lock
	var g := piece(profile, ref)
	if not temperable(g):
		return TEXT["no_temper"]
	if int(g["rank"]) >= Gear.MAX_RANK:
		return TEXT["rank_top"] % Gear.MAX_RANK
	var dens := density_short(profile, g)
	if dens != "":
		return dens
	return short_of(profile, temper_cost(g))


## Tempers a piece one rank higher. "" if done, else why not.
static func temper(profile, ref: String) -> String:
	var why := temper_why(profile, ref)
	if why != "":
		return why
	var g := piece(profile, ref)
	pay(profile, temper_cost(g))
	g["rank"] = int(g["rank"]) + 1
	put(profile, ref, g)
	profile.save()
	return ""


# --- retraiting -------------------------------------------------------------------------------

## The traits a piece could get in place of trait number `which`, by kind:
## {kind: [trait ids]} (only traits that fit its slot and aren't on it).
static func retrait_options(g, which: int) -> Dictionary:
	var r := Gear.rec(g)
	var out := {}
	if r.is_empty() or which < 0 or which >= r["traits"].size():
		return out
	for t in Gear.traits_for(Gear.trait_slot(r)):
		if t in r["traits"]:
			continue
		var kind := String(Gear.TRAITS[t]["kind"])
		if not out.has(kind):
			out[kind] = []
		out[kind].append(t)
	return out


static func retrait_cost(g, kind: String) -> Dictionary:
	var r := Gear.rec(g)
	var k := RETRAIT_RARE if Gear.rarity_rank(r.get("rarity", "common")) >= Gear.rarity_rank("rare") else 1.0
	return {kind: int(round(RETRAIT * k))}


## Why a piece's trait can't be swapped for one of `kind` now, or "".
static func retrait_why(profile, ref: String, which: int, kind: String) -> String:
	var lock := locked(profile, "retrait")
	if lock != "":
		return lock
	var g := piece(profile, ref)
	if g.is_empty() or g["traits"].is_empty():
		return TEXT["no_retrait"]
	if not retrait_options(g, which).has(kind):
		return TEXT["no_new_trait"]
	return short_of(profile, retrait_cost(g, kind))


## Swaps trait number `which` for a random trait of `kind` that fits.
## "" if done, else why not.
static func retrait(profile, ref: String, which: int, kind: String) -> String:
	var why := retrait_why(profile, ref, which, kind)
	if why != "":
		return why
	var g := piece(profile, ref)
	var pool: Array = retrait_options(g, which)[kind]
	pay(profile, retrait_cost(g, kind))
	var traits: Array = g["traits"].duplicate()
	traits[which] = pool[randi() % pool.size()]
	g["traits"] = traits
	put(profile, ref, g)
	profile.save()
	return ""


# --- joining ------------------------------------------------------------------------------------

## A piece that can be joined: Fine, one trait, not a named piece.
static func joinable(g) -> bool:
	var r := Gear.rec(g)
	return not r.is_empty() and r["rarity"] == "fine" and r["traits"].size() == 1 and not r.has("named")


## The pieces `ref` could be joined with (refs): joinable, the same slot.
static func partners(profile, ref: String) -> Array:
	var g := piece(profile, ref)
	if not joinable(g):
		return []
	return pieces(profile).filter(func(o): return o != ref and joinable(piece(profile, o)) and Gear.slot_of(piece(profile, o)) == Gear.slot_of(g))


static func join_cost(g) -> Dictionary:
	return {Train.gear_kind(g): JOIN}


## The Rare piece two Fine pieces make: the first's base, a trait from each
## (if both had the same, another that fits), the higher rank, the first's rune.
static func joined(a, b) -> Dictionary:
	var ra := Gear.rec(a)
	var rb := Gear.rec(b)
	var traits: Array = [ra["traits"][0]]
	var tb: String = rb["traits"][0]
	if tb == traits[0]:
		var pool: Array = Gear.traits_for(Gear.trait_slot(ra)).filter(func(t): return t != tb)
		tb = pool[0] if not pool.is_empty() else ""
	if tb != "":
		traits.append(tb)
	var rune := String(ra.get("rune", rb.get("rune", "")))
	return Gear.make(ra["base"], "rare", traits, maxi(int(ra["rank"]), int(rb["rank"])), "", rune)


static func join_why(profile, ref: String, other: String) -> String:
	var lock := locked(profile, "join")
	if lock != "":
		return lock
	var g := piece(profile, ref)
	if not joinable(g):
		return TEXT["no_join"]
	if not (other in partners(profile, ref)):
		return TEXT["no_partner"]
	return short_of(profile, join_cost(g))


## Joins two Fine pieces into one Rare. It takes the place of an heirloom
## if either was one, else the first piece's. "" if done, else why not.
static func join(profile, ref: String, other: String) -> String:
	var why := join_why(profile, ref, other)
	if why != "":
		return why
	var a := piece(profile, ref)
	var b := piece(profile, other)
	pay(profile, join_cost(a))
	var made := joined(a, b)
	var keep := other if _keeps_other(ref, other) else ref
	put(profile, keep, made)
	remove(profile, ref if keep == other else other)
	profile.save()
	return ""


static func _keeps_other(ref: String, other: String) -> bool:
	return other.begins_with("heir:") and not ref.begins_with("heir:")


## Where the joined piece ends up (a ref), once the other piece is gone: an
## heirloom's place if either was one, else the first piece's (a place
## higher in its list if the other was before it in the same list).
static func join_place(ref: String, other: String) -> String:
	var keep := other if _keeps_other(ref, other) else ref
	var drop := ref if keep == other else other
	var last := keep.get_slice_count(":") - 1
	var same_list := keep.substr(0, keep.rfind(":")) == drop.substr(0, drop.rfind(":")) and not (keep.begins_with("heir:") and not keep.begins_with("heir:rings"))
	if same_list and int(drop.get_slice(":", last)) < int(keep.get_slice(":", last)):
		return keep.substr(0, keep.rfind(":") + 1) + str(int(keep.get_slice(":", last)) - 1)
	return keep


# --- breaking down -------------------------------------------------------------------------------

## What breaking a piece or a packed item down gives: [kind, amount] (the
## store's Sell price for a piece; SELL_SHARE of an item's price).
static func break_value(profile, thing: String) -> Array:
	if thing.begins_with("supply:"):
		return Train.item_sell(thing.substr(7))
	var g := piece(profile, thing)
	return [Train.gear_kind(g), Train.gear_sell(g)] if not g.is_empty() else ["", 0]


## Breaks down a piece from your pack or chest ("pack:0") or a packed item
## ("supply:draught"): a crystal of its kind. Returns what it gave ("5
## Blade"), or "" if nothing was there.
static func break_down(profile, thing: String) -> String:
	if thing.begins_with("supply:"):
		var id := thing.substr(7)
		var v := break_value(profile, thing)
		if Train.unpack_supply(profile, id).is_empty():
			return ""
		profile.add_crystal(v[0], v[1])
		profile.save()
		return Train.price_text(v[0], v[1])
	var where := thing.get_slice(":", 0)
	if where != "pack" and where != "chest":
		return ""
	return Train.sell(profile, where, int(thing.get_slice(":", 1)))


# --- inscribing ------------------------------------------------------------------------------------

static func inscribe_why(profile, ref: String, rune: String) -> String:
	var lock := locked(profile, "inscribe")
	if lock != "":
		return lock
	var g := piece(profile, ref)
	if g.is_empty() or not Gear.LASTING_RUNES.has(rune) or Gear.LASTING_RUNES[rune].get("deep", false):  # (a deep rune takes a vessel)
		return TEXT["nothing"]
	return short_of(profile, INSCRIBE)


## Inscribes a lasting rune on a piece (replacing one already there).
## "" if done, else why not.
static func inscribe(profile, ref: String, rune: String) -> String:
	var why := inscribe_why(profile, ref, rune)
	if why != "":
		return why
	var g := piece(profile, ref)
	pay(profile, INSCRIBE)
	g["rune"] = rune
	put(profile, ref, g)
	profile.save()
	return ""
