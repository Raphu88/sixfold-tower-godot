extends RefCounted
## Worn gear on LITE's climber: treasure a child finds, showing on them. A
## copy of the full game's scripts/gear_look.gd (how each piece you wear
## changes the climber's look, and the gear layers drawn over the body), cut
## down to the pieces LITE shows, plus WEAPON SKINS (a special finish for
## the weapon in hand). Drawing and data only: what a piece does is the
## game's business.
##
## The gear is a Dictionary slot -> piece id (an id from catalog()):
##   "head"       a cap or a helm (a helm or cap pushes the hood down)
##   "chest"      body armour: leather, mail or plate (plate brings a helm
##                and mail a coif when nothing is on the head, like the full game)
##   "shoulders"  pauldrons (LITE's own slot: in the full game they come with
##                the chest piece, and still do here when none is worn)
##   "hands"      gloves, gauntlets or bracers
##   "feet"       boots
##   "neck"       an amulet
##   "back"       a cloak (its colour replaces your own) or a backpack
## A skin is one of SKINS (or "" for plain steel and wood).
##
## dress(look, gear, weapon, skin) lays the gear over a look (look.gd
## look()); then the drawing reads the keys it set:
##   In the tower (climber_art.gd, between look.gd's layers):
##     tower_back    after the cloak: the backpack
##     tower_armor   after the torso: the chest piece's detail and the shoulders
##     tower_chest   then: the amulet's glint, a fine chest piece's glow
##     tower_head    after the head: a miner's candle, a cap's feather, a fine helm's crest
##     tower_sword / tower_hammer / bow_color / tower_glow   the weapon in its skin
##   On the front figure (look.gd draw_front, when the look is dressed, "gear_on"):
##     front_behind     a backpack, behind everything
##     front_legs       boots
##     front_chest      body armour by weight, a backpack's straps
##     front_arms       the weapon in hand, mail sleeves or vambraces, gloves
##     front_shoulders  pauldrons, the amulet
##     front_head       a cap, a helm or a mail coif
## Rarity shows like the full game's: an "enchanted" piece has a thin edge
## in its rarity's colour; a "relic" (one of the full game's named pieces)
## its own colour, the edge and a gilt motif, and the beasts' own (Regarded)
## a glowing stone too.

const Palette := preload("res://scripts/palette.gd")

## The slots LITE's climber can wear something in.
const SLOTS := ["head", "chest", "shoulders", "hands", "feet", "neck", "back"]
## The finishes the weapon in hand can have (SKIN_LOOK).
const SKINS := ["gold", "crystal", "flame", "shadow"]

## Colours the full game keeps in its ui.gd: the outline, gilt and gold.
const OUTLINE := Color(0.03, 0.025, 0.04)
const GILT := Color(0.886, 0.71, 0.353)
const GOLD := Color(0.91, 0.75, 0.42)
## The full game's rarities' colours (gear.gd RARITIES): the edges.
const RARITY_COLOR := {
	"fine": Color(0.55, 0.85, 0.5),
	"rare": Color(0.45, 0.65, 1.0),
	"storied": Color(0.95, 0.62, 0.24),
	"regarded": Color(1.0, 0.86, 0.36),
}
## The candle of a miner's helm, a feathered cap's feather.
const CANDLE := Color(1.0, 0.82, 0.4)
const FEATHER := Color(0.86, 0.82, 0.72)

## Every piece LITE can show, from the full game's gear.gd (its name and
## colour). "rarity": "plain", "enchanted" or "relic" (what the game shows);
## "edge": the full game's rarity whose colour edges it ("" none); "named":
## 1 a named piece (a gilt motif), 2 a beast's own (a glowing stone too);
## "base": the full game's piece it's drawn as; "kind": what it is ("cap",
## "helm", "armor", "pauldrons", "gloves", "boots", "amulet", "cloak", "pack");
## "weight" for armour and pauldrons, "look" for gloves, boots and cloaks.
static var PIECES := {
	# Head
	"leather_cap": {"slot": "head", "name": "Leather Cap", "rarity": "plain", "kind": "cap", "base": "leather_cap", "color": Color(0.55, 0.38, 0.24)},
	"feathered_cap": {"slot": "head", "name": "Feathered Cap", "rarity": "plain", "kind": "cap", "base": "feathered_cap", "color": Color(0.36, 0.52, 0.36)},
	"iron_helm": {"slot": "head", "name": "Iron Helm", "rarity": "plain", "kind": "helm", "base": "iron_helm", "color": Color(0.7, 0.72, 0.78)},
	"miners_helm": {"slot": "head", "name": "Miner's Helm", "rarity": "enchanted", "edge": "fine", "kind": "helm", "base": "miners_helm", "color": Color(0.8, 0.62, 0.32)},
	"watchers_helm": {"slot": "head", "name": "Watcher's Helm", "rarity": "relic", "edge": "storied", "named": 1, "kind": "helm", "base": "iron_helm", "color": Color(0.62, 0.66, 0.8)},
	# Chest
	"leather_armor": {"slot": "chest", "name": "Leather Armor", "rarity": "plain", "kind": "armor", "weight": "leather", "color": Color(0.5, 0.33, 0.2)},
	"chain_mail": {"slot": "chest", "name": "Chain Mail", "rarity": "plain", "kind": "armor", "weight": "chain", "color": Color(0.62, 0.65, 0.7)},
	"plate_armor": {"slot": "chest", "name": "Plate Armor", "rarity": "enchanted", "edge": "rare", "kind": "armor", "weight": "plate", "color": Color(0.8, 0.82, 0.88)},
	"barnacle_mail": {"slot": "chest", "name": "Barnacle Mail", "rarity": "relic", "edge": "rare", "named": 1, "kind": "armor", "weight": "chain", "color": Color(0.5, 0.66, 0.66)},
	"wyvern_scaleplate": {"slot": "chest", "name": "Wyvern Scaleplate", "rarity": "relic", "edge": "rare", "named": 1, "kind": "armor", "weight": "plate", "color": Color(0.62, 0.42, 0.36)},
	"deepcoil_coat": {"slot": "chest", "name": "Deepcoil Coat", "rarity": "relic", "edge": "regarded", "named": 2, "kind": "armor", "weight": "leather", "color": Color(0.24, 0.42, 0.5)},
	# Shoulders (the full game's armours' pauldrons, worn on their own)
	"leather_pauldrons": {"slot": "shoulders", "name": "Leather Pauldrons", "rarity": "plain", "kind": "pauldrons", "weight": "leather", "color": Color(0.5, 0.33, 0.2)},
	"mail_pauldrons": {"slot": "shoulders", "name": "Mail Pauldrons", "rarity": "plain", "kind": "pauldrons", "weight": "chain", "color": Color(0.62, 0.65, 0.7)},
	"plate_pauldrons": {"slot": "shoulders", "name": "Plate Pauldrons", "rarity": "enchanted", "edge": "rare", "kind": "pauldrons", "weight": "plate", "color": Color(0.8, 0.82, 0.88)},
	# Hands
	"leather_gloves": {"slot": "hands", "name": "Leather Gloves", "rarity": "plain", "kind": "gloves", "look": "leather", "color": Color(0.5, 0.33, 0.2)},
	"archers_bracers": {"slot": "hands", "name": "Archer's Bracers", "rarity": "plain", "kind": "gloves", "look": "bracers", "color": Color(0.6, 0.42, 0.26)},
	"gauntlets": {"slot": "hands", "name": "Gauntlets", "rarity": "enchanted", "edge": "rare", "kind": "gloves", "look": "plate", "color": Color(0.72, 0.74, 0.8)},
	"quickhand_gloves": {"slot": "hands", "name": "Quickhand Gloves", "rarity": "relic", "edge": "storied", "named": 1, "kind": "gloves", "look": "leather", "color": Color(0.42, 0.2, 0.24)},
	# Feet
	"climbing_boots": {"slot": "feet", "name": "Climbing Boots", "rarity": "plain", "kind": "boots", "look": "laced", "color": Color(0.38, 0.3, 0.24)},
	"hobnail_boots": {"slot": "feet", "name": "Hobnail Boots", "rarity": "plain", "kind": "boots", "look": "hobnail", "color": Color(0.3, 0.27, 0.26)},
	"wading_boots": {"slot": "feet", "name": "Wading Boots", "rarity": "enchanted", "edge": "fine", "kind": "boots", "look": "tall", "color": Color(0.3, 0.44, 0.46)},
	"phantom_treads": {"slot": "feet", "name": "Phantom Treads", "rarity": "relic", "edge": "storied", "named": 1, "kind": "boots", "look": "soft", "color": Color(0.7, 0.78, 0.86)},
	# Neck
	"sunstone_pendant": {"slot": "neck", "name": "Sunstone Pendant", "rarity": "enchanted", "edge": "fine", "kind": "amulet", "color": Color(1.0, 0.7, 0.28)},
	"tide_locket": {"slot": "neck", "name": "Tide Locket", "rarity": "enchanted", "edge": "rare", "kind": "amulet", "color": Color(0.37, 0.72, 0.85)},
	"heartstone": {"slot": "neck", "name": "Heartstone", "rarity": "relic", "edge": "storied", "named": 1, "kind": "amulet", "color": Color(0.85, 0.35, 0.35)},
	"wayfinders_pendant": {"slot": "neck", "name": "Wayfinder's Pendant", "rarity": "relic", "edge": "storied", "named": 1, "kind": "amulet", "color": Color(0.5, 0.78, 0.95)},
	# Back
	"feather_cape": {"slot": "back", "name": "Feather Cape", "rarity": "plain", "kind": "cloak", "look": "short", "color": Color(0.64, 0.56, 0.48)},
	"climbers_pack": {"slot": "back", "name": "Climber's Pack", "rarity": "enchanted", "edge": "rare", "kind": "pack", "color": Color(0.4, 0.46, 0.3)},
	"emberkin_mantle": {"slot": "back", "name": "Emberkin Mantle", "rarity": "relic", "edge": "storied", "named": 1, "kind": "cloak", "color": Color(0.7, 0.3, 0.18)},
	"sunplume_mantle": {"slot": "back", "name": "Sunplume Mantle", "rarity": "relic", "edge": "regarded", "named": 2, "kind": "cloak", "color": Color(0.95, 0.46, 0.2)},
}

## The weapon skins: the blade's (or the hammer's head's, the bow's limbs')
## colour, its bright edge, the hilt and guard, the glow along it and the
## swing's trail. Like the full game's enchanted weapons, a skinned weapon
## glows faintly along its length (particles.gd draw_weapon_glow).
static var SKIN_LOOK := {
	"gold": {"blade": Color(1.0, 0.8, 0.3), "shine": Color(1.0, 0.96, 0.7), "hilt": Color(0.6, 0.4, 0.12), "glow": Color(1.0, 0.86, 0.36), "trail": Color(1.0, 0.88, 0.5)},
	"crystal": {"blade": Color(0.68, 0.9, 1.0), "shine": Color(0.95, 1.0, 1.0), "hilt": Color(0.34, 0.52, 0.74), "glow": Color(0.6, 0.86, 1.0), "trail": Color(0.78, 0.94, 1.0)},
	"flame": {"blade": Color(1.0, 0.48, 0.18), "shine": Color(1.0, 0.88, 0.45), "hilt": Color(0.55, 0.16, 0.08), "glow": Color(1.0, 0.5, 0.16), "trail": Color(1.0, 0.64, 0.28)},
	"shadow": {"blade": Color(0.38, 0.24, 0.54), "shine": Color(0.78, 0.6, 1.0), "hilt": Color(0.17, 0.1, 0.25), "glow": Color(0.66, 0.4, 1.0), "trail": Color(0.66, 0.46, 0.95)},
}
## The skinned weapon's glow (the full game's WEAPON_LIGHT glow_width and glow_alpha).
const GLOW_WIDTH := 4.0
const GLOW_ALPHA := 0.38

## How much bigger the amulet is on the front figure than the full game's.
const AMULET_K := 1.4

## LITE's weapon ids -> the full game's drawing of it on the front figure.
const FRONT_WEAPON := {"sword": "sword", "dagger": "dagger", "hammer": "war_hammer", "bow": "shortbow"}


## Every piece LITE can show: id -> {"slot": slot, "name": the full game's
## name, "rarity": "plain"/"enchanted"/"relic"}.
static func catalog() -> Dictionary:
	var out := {}
	for id in PIECES:
		var p: Dictionary = PIECES[id]
		out[id] = {"slot": p["slot"], "name": p["name"], "rarity": p["rarity"]}
	return out


## A skin's look (SKIN_LOOK), or empty for none or an unknown one.
static func skin_look(skin: String) -> Dictionary:
	return SKIN_LOOK.get(skin, {})


## The swing's trail in a skin's colour (a finisher's brighter); `plain` without a skin.
static func trail_color(skin: String, heavy: bool, plain: Color) -> Color:
	var sk := skin_look(skin)
	if sk.is_empty():
		return plain
	var col: Color = sk["trail"]
	return col.lightened(0.25) if heavy else col


# --- dressing the look --------------------------------------------------------------

## The piece worn in a slot (PIECES), or empty.
static func _piece(gear: Dictionary, slot: String) -> Dictionary:
	var p: Dictionary = PIECES.get(String(gear.get(slot, "")), {})
	return p if String(p.get("slot", "")) == slot else {}


## A dressed copy of `look` (look.gd look()), for the gear worn, the weapon
## in hand (LITE's id: it shows on the front figure) and its skin.
static func dressed(look: Dictionary, gear: Dictionary, weapon := "", skin := "") -> Dictionary:
	var lk := look.duplicate()
	dress(lk, gear, weapon, skin)
	return lk


## Lays the worn gear over a look, in place (see the top of the file).
static func dress(look: Dictionary, gear: Dictionary, weapon := "", skin := "") -> void:
	before_armor(look, gear)
	armor_look(look, gear)
	after_armor(look, gear)
	extras(look, gear, weapon, skin)


## Before the chest piece: the head as the appearance has it (hood up or
## down), the boots' size, and a worn cloak's colour (the hood follows it).
static func before_armor(look: Dictionary, gear: Dictionary) -> void:
	look["head"] = "hood" if look.get("hood_up", true) else "bare"
	look["boot_r"] = 3.0
	look["studs"] = false
	var cl := _piece(gear, "back")
	if String(cl.get("kind", "")) == "cloak":
		look["cloak"] = cl["color"]
		if cl.has("look"):
			look["cloak_style"] = cl["look"]
		if String(cl.get("edge", "")) != "":
			look["trim_on"] = true  # (a fine cloak is edged in its rarity's colour)
			look["trim"] = RARITY_COLOR[cl["edge"]]
		if int(cl.get("named", 0)) > 0:
			look["pattern"] = "embroidered"


## Colours and sizes for the chest piece (none: the tunic and cloak), then
## pauldrons worn on their own over it.
static func armor_look(look: Dictionary, gear: Dictionary) -> void:
	var cloak: Color = look["cloak"]
	look["torso"] = look["tunic"]
	look["shoulder"] = cloak.darkened(0.12)
	look["shoulder_r"] = 4.6
	look["sleeve"] = look["tunic"]
	look["hand"] = look["skin"]
	look["hood"] = cloak.darkened(0.22)
	var a := _piece(gear, "chest")
	if not a.is_empty():
		var col: Color = a["color"]
		match String(a["weight"]):
			"leather":
				look["torso"] = col
				look["shoulder"] = col.darkened(0.18)
				look["shoulder_r"] = 5.2
				look["sleeve"] = col.darkened(0.1)
				look["hand"] = col.darkened(0.3)  # gloves
			"chain":
				look["torso"] = col.darkened(0.12)
				look["shoulder"] = col
				look["shoulder_r"] = 5.4
				look["sleeve"] = col.darkened(0.2)
				look["hood"] = col.darkened(0.3)  # a mail coif
			"plate":
				look["torso"] = col.darkened(0.15)
				look["shoulder"] = col
				look["shoulder_r"] = 6.2  # big pauldrons: broader and heavier
				look["sleeve"] = col.darkened(0.3)
				look["hand"] = col.darkened(0.25)  # gauntlets
				look["hood"] = col.darkened(0.1)  # a steel helm
	var sp := _piece(gear, "shoulders")
	if not sp.is_empty():
		var sc: Color = sp["color"]
		match String(sp["weight"]):
			"leather":
				look["shoulder"] = sc.darkened(0.18)
				look["shoulder_r"] = 5.2
			"chain":
				look["shoulder"] = sc
				look["shoulder_r"] = 5.4
			"plate":
				look["shoulder"] = sc
				look["shoulder_r"] = 6.2


## After the chest piece: the head (plate brings a helm, mail a coif; a head
## piece overrides both), gloves and boots. A helm or cap pushes the hood
## down (the front figure reads "hood_up"), so the hair shows under it.
static func after_armor(look: Dictionary, gear: Dictionary) -> void:
	var a := _piece(gear, "chest")
	match String(a.get("weight", "")):
		"plate":
			look["head"] = "helm"
			look["helm_col"] = a["color"]
		"chain":
			look["head"] = "coif"
			look["coif_col"] = a["color"]
	var hm := _piece(gear, "head")
	if not hm.is_empty():
		var col: Color = hm["color"]
		if String(hm["kind"]) == "cap":
			look["head"] = "cap"
			look["cap"] = col
		else:
			look["head"] = "helm"
			look["hood"] = col.darkened(0.1)
			look["helm_col"] = col
	match String(look["head"]):
		"cap", "helm":
			look["hood_up"] = false
		"coif":
			look["hood_up"] = true
			look["hood_front"] = look.get("coif_col", look["hood"])
	var gl := _piece(gear, "hands")
	if not gl.is_empty():
		look["hand"] = (gl["color"] as Color).darkened(0.15)
	var bt := _piece(gear, "feet")
	if not bt.is_empty():
		look["boot"] = (bt["color"] as Color).darkened(0.1)
		match String(bt["look"]):
			"hobnail":
				look["boot_r"] = 3.4
				look["studs"] = true
			"soft":
				look["boot_r"] = 2.8


## Everything else the drawing reads: what each slot looks like, its
## colours, rarity edges and named motifs, the weapon in hand and its skin.
static func extras(look: Dictionary, gear: Dictionary, weapon := "", skin := "") -> void:
	look["gear_on"] = true
	var a := _piece(gear, "chest")
	look["armor_w"] = String(a.get("weight", ""))
	look["armor_col"] = a.get("color", look["tunic"])
	_mark(look, "armor", a)
	var sp := _piece(gear, "shoulders")
	look["pauldron_w"] = String(sp.get("weight", look["armor_w"]))
	look["pauldron_col"] = sp.get("color", look["armor_col"])
	look["pauldron_slot"] = "shoulders" if not sp.is_empty() else "armor"
	_mark(look, "shoulders", sp)
	var hm := _piece(gear, "head")
	look["helm_id"] = String(hm.get("base", ""))
	_mark(look, "helm", hm)
	var gl := _piece(gear, "hands")
	var glove := String(gl.get("look", ""))
	if glove == "":
		glove = {"plate": "plate", "leather": "leather"}.get(look["armor_w"], "")  # (plate brings gauntlets, leather gloves)
	look["glove"] = glove
	look["glove_col"] = gl.get("color", look["hand"])
	_mark(look, "gloves", gl)
	var bt := _piece(gear, "feet")
	look["boot_look"] = String(bt.get("look", ""))
	_mark(look, "boots", bt)
	var back := _piece(gear, "back")
	var bp := back if String(back.get("kind", "")) == "pack" else {}
	look["pack"] = "pack" if not bp.is_empty() else ""
	look["pack_col"] = bp.get("color", Color.WHITE)
	_mark(look, "backpack", bp)
	_mark(look, "cloak", back if bp.is_empty() else {})
	var am := _piece(gear, "neck")
	look["amulet"] = not am.is_empty()
	look["amulet_col"] = am.get("color", Color.WHITE)
	_mark(look, "amulet", am)
	look["in_hand"] = String(FRONT_WEAPON.get(weapon, ""))
	look["weapon_col"] = Color(0.85, 0.66, 0.42) if weapon == "bow" else Palette.STEEL
	look["weapon_skin"] = skin if SKIN_LOOK.has(skin) else ""


## A slot's rarity edge ("<slot>_edge": its rarity's colour, enchanted and
## relics; a clear colour otherwise) and whether it's a named piece
## ("<slot>_named": 0 none, 1 a named piece, 2 a beast's own).
static func _mark(look: Dictionary, slot: String, p: Dictionary) -> void:
	var e := String(p.get("edge", ""))
	look[slot + "_edge"] = RARITY_COLOR[e] if RARITY_COLOR.has(e) else Color(0, 0, 0, 0)
	look[slot + "_named"] = int(p.get("named", 0))


static func _edge(lk: Dictionary, slot: String) -> Color:
	return lk.get(slot + "_edge", Color(0, 0, 0, 0))


static func _named(lk: Dictionary, slot: String) -> int:
	return int(lk.get(slot + "_named", 0))


## A soft glow (the full game's ui.gd glow_into).
static func glow_into(b, c: Vector2, r: float, col: Color, strength := 1.0) -> void:
	for i in 5:
		var k := 1.0 - i / 5.0
		b.dot(c, r * (0.45 + 0.55 * k), Color(col, 0.07 * strength))


# --- the tower: seen from above --------------------------------------------------
# In the drawing frame: `f` forward, `sd` toward the weapon hand, `light`
# the light's direction; `lx` the body's offset (a lean).

static func _q(f: Vector2, sd: Vector2, x: float, y: float) -> Vector2:
	return f * x + sd * y


## After the cloak: the backpack on your back (a Climber's Pack, its bedroll).
## (A little farther back than the full game's, so LITE's thicker outline
## round the head doesn't hide it.)
static func tower_back(b, lx: Vector2, f: Vector2, sd: Vector2, light: Vector2, lk: Dictionary) -> void:
	if not lk.get("gear_on", false) or String(lk.get("pack", "")) == "":
		return
	var pc: Color = lk.get("pack_col", Palette.WOOD)
	var edge := _edge(lk, "backpack")
	var at := lx + _q(f, sd, -10.0, 0.0)
	b.stroke(lx + _q(f, sd, -13.5, -6.5), lx + _q(f, sd, -13.5, 6.5), pc.lightened(0.15), 2.6)  # the bedroll
	b.ball(at, 5.4, pc, true, light)
	if edge.a > 0.0:
		b.arc(at, 5.6, 0.0, TAU, 12, Color(edge, 0.7), 0.8)


## After the torso: armour on the chest, where it shows in front of the head
## (quilting, a strap, rings, a ridge), then the shoulders (in the cloak, or
## pauldrons). With nothing worn, just the shoulders. (player.gd _draw_armor_detail.)
static func tower_armor(b, lx: Vector2, f: Vector2, sd: Vector2, light: Vector2, lk: Dictionary) -> void:
	var c := lx + f * 2.0
	var fa := f.angle()
	var torso: Color = lk["torso"]
	var tk: float = float(lk.get("torso_r", 8.5)) / 8.5  # (the build)
	match String(lk.get("armor_w", "")):
		"leather":
			b.line(lx + _q(f, sd, 2.0 + 7.5 * tk, -3.5 * tk), lx + _q(f, sd, 3.0, 8.5 * tk), torso.darkened(0.35), 1.8)  # a strap
			b.dot(lx + _q(f, sd, 2.0 + 6.4 * tk, -1.4 * tk), 1.2, Color(0.85, 0.7, 0.45))  # its buckle
		"chain":
			for k in 7:  # rings
				var a := fa + (k - 3) * 0.3
				b.dot(c + Vector2.from_angle(a) * 7.2 * tk, 0.8, Color(1, 1, 1, 0.3))
		"plate":
			b.line(lx + _q(f, sd, 2.0 + 4.6 * tk, 0.0), lx + _q(f, sd, 2.0 + 8.2 * tk, 0.0), torso.lightened(0.35), 1.2)  # the ridge
	var sh_r: float = float(lk.get("shoulder_r", 4.6)) + float(lk.get("sh_add", 0.0))  # (the build)
	var pw := String(lk.get("pauldron_w", ""))
	for sgn in [-1.0, 1.0]:
		var at := lx + _q(f, sd, 0.3, sgn * float(lk.get("sh_y", 9.3)))
		b.ball(at, sh_r, lk["shoulder"], true, light)
		if pw == "plate":
			b.arc(at, sh_r - 1.6, fa + sgn * 0.3, fa + sgn * 2.4, 6, Color(1, 1, 1, 0.3), 1.0)
		elif pw == "leather":
			b.dot(at + _q(f, sd, 0.0, sgn * 1.5), 0.9, Color(0.85, 0.7, 0.45))
		if lk.get("gear_on", false) and String(lk.get("pauldron_slot", "")) == "shoulders":
			var e := _edge(lk, "shoulders")
			if e.a > 0.0:
				b.arc(at, sh_r + 0.3, fa + sgn * 0.2, fa + sgn * 2.6, 8, Color(e, 0.7), 0.9)


## After the armour: a fine chest piece's glow along its edge, a named
## one's gilt line.
static func tower_chest(b, lx: Vector2, f: Vector2, sd: Vector2, light: Vector2, lk: Dictionary, t := 0.0) -> void:
	if not lk.get("gear_on", false):
		return
	var r: float = lk.get("torso_r", 8.5)
	var c := lx + f * 2.0
	var fa := f.angle()
	var edge := _edge(lk, "armor")
	if edge.a > 0.0:
		b.arc(c, r + 0.4, fa - 1.2, fa + 1.2, 10, Color(edge, 0.55 + 0.15 * sin(t * 2.0)), 1.0)
	if _named(lk, "armor") > 0:
		b.arc(c, r - 2.2, fa - 0.7, fa + 0.7, 8, Color(GILT, 0.7), 0.8)


## After the head: the amulet's glint at the chest (LITE draws it after the
## head and a little bigger than the full game, so its thicker outline round
## the head doesn't hide it; an enchanted one glows), a miner's candle, a
## feathered cap's feather, a fine helm's crest in its rarity's colour.
static func tower_head(b, hd: Vector2, f: Vector2, sd: Vector2, light: Vector2, lk: Dictionary, t := 0.0) -> void:
	if not lk.get("gear_on", false):
		return
	if lk.get("amulet", false):
		var ac: Color = lk["amulet_col"]
		var at := hd + f * (2.5 + float(lk.get("torso_r", 8.5)) - 1.9)
		var e := _edge(lk, "amulet")
		if e.a > 0.0:
			b.dot(at, 3.6, Color(e, 0.18 + 0.06 * sin(t * 3.0)))
		b.dot(at, 1.4 + 0.8 * Palette.TOON_LINE, Palette.OUTLINE)
		b.dot(at, 1.4, ac)
		b.dot(at + Vector2(-0.45, -0.45), 0.5, Color(1, 1, 1, 0.5 + 0.4 * sin(t * 3.0)))
	var head: String = lk.get("head", "hood")
	match String(lk.get("helm_id", "")):
		"miners_helm":
			b.dot(hd + f * 6.2, 2.4, Color(CANDLE, 0.25 + 0.1 * sin(t * 9.0)))
			b.dot(hd + f * 6.2, 1.1, CANDLE)
		"feathered_cap":
			b.stroke(hd + _q(f, sd, 1.0, -4.0), hd + _q(f, sd, -9.0, -6.5), FEATHER, 1.4)
	var edge := _edge(lk, "helm")
	if edge.a > 0.0 and head in ["helm", "cap"]:
		b.line(hd + f * -4.5, hd + f * 4.0, Color(edge, 0.75), 1.0)


# --- the weapon in hand, in its skin (the tower) ----------------------------------

## A sword lying along `dir` from the grip, with crossguard and pommel
## (draw_util.gd Batch.sword), in a skin's colours (plain steel without one).
static func tower_sword(b, grip: Vector2, dir: Vector2, length: float, glint: float, skin: String) -> void:
	var sk := skin_look(skin)
	if sk.is_empty():
		b.sword(grip, dir, length, glint)
		return
	var side := dir.orthogonal()
	var tip := grip + dir * length
	var blade: Color = sk["blade"]
	var hilt: Color = sk["hilt"]
	b.stroke(grip - dir * 5.0, grip, hilt, 3.0)  # hilt
	b.stroke(grip + side * 5.0, grip - side * 5.0, hilt.lightened(0.25), 2.5)  # crossguard
	b.stroke(grip + dir * 2.0, tip, blade.darkened(0.06), 3.2)  # blade
	b.line(grip + dir * 3.0 - side * 0.8, tip - dir * 1.0 - side * 0.8, blade.darkened(0.4), 1.0)  # its shaded edge
	b.line(grip + dir * 3.0 + side * 0.7, tip - dir * 2.0 + side * 0.7, Color(sk["shine"], 0.6 + glint * 0.4), 1.0)
	b.dot(grip - dir * 6.0, 2.2, hilt.lightened(0.3))  # pommel


## The war hammer lying along `along` from the grip (player.gd _draw_swung),
## its head in a skin's colour (steel without one).
static func tower_hammer(b, grip: Vector2, along: Vector2, length: float, glint: float, skin: String) -> void:
	var sk := skin_look(skin)
	var side := along.orthogonal()
	var head2 := grip + along * length
	b.stroke(grip - along * 6.0, head2, Palette.WOOD.darkened(0.1) if sk.is_empty() else (sk["hilt"] as Color).lightened(0.1), 3.0)
	var pts := PackedVector2Array([head2 - along * 5.0 + side * 9.0, head2 + along * 5.0 + side * 9.0, head2 + along * 5.0 - side * 6.0, head2 - along * 5.0 - side * 6.0])
	b.poly(pts, Palette.STEEL.darkened(0.15) if sk.is_empty() else (sk["blade"] as Color).darkened(0.08), 1.4)
	var shine: Color = Color(1, 1, 1) if sk.is_empty() else sk["shine"]
	b.line(pts[0] - side * 0.8, pts[1] - side * 0.8, Color(shine, 0.45 + 0.4 * glint), 1.2)


## A bow's limbs: wood, or the skin's colour.
static func bow_color(skin: String, plain: Color) -> Color:
	var sk := skin_look(skin)
	return plain if sk.is_empty() else sk["blade"]


## A skinned weapon's faint glow along it, from `a` to `b2` (the full game's
## enchanted weapon glow: particles.gd draw_weapon_glow). Nothing without a skin.
static func tower_glow(b, a: Vector2, b2: Vector2, skin: String, t := 0.0) -> void:
	var sk := skin_look(skin)
	if sk.is_empty():
		return
	var col: Color = sk["glow"]
	var al := GLOW_ALPHA * (0.8 + 0.2 * sin(t * 6.0))
	b.line(a, b2, Color(col, al * 0.6), GLOW_WIDTH * 1.8)
	b.line(a, b2, Color(col.lightened(0.35), al * 1.3), GLOW_WIDTH * 0.5)
	b.dot(b2, GLOW_WIDTH * 1.4, Color(col, al * 0.8))


## The same glow along a bent path (a bow's limbs).
static func tower_glow_path(b, pts: PackedVector2Array, skin: String, t := 0.0) -> void:
	var sk := skin_look(skin)
	if sk.is_empty():
		return
	var col: Color = sk["glow"]
	var al := GLOW_ALPHA * (0.8 + 0.2 * sin(t * 6.0))
	b.path(pts, Color(col, al * 0.6), GLOW_WIDTH * 1.8)
	b.path(pts, Color(col.lightened(0.35), al * 1.1), GLOW_WIDTH * 0.5)


# --- the front figure ------------------------------------------------------------
# In the climber screen's frame (about 290 tall, centred on the waist, lit
# from the top-left; look.gd draw_front). The figure's right hand (the
# weapon hand) is on the viewer's left, at (-50, 9).

static func _p(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, pts.size(), 2):
		out.append(Vector2(pts[i], pts[i + 1]))
	return out


static func _sx(pts: PackedVector2Array, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p.x * k, p.y))
	return out


static func _oval(c: Vector2, rad: Vector2, n := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rad.x, sin(a) * rad.y))
	return pts


## A rarity edge round an outline, and a named piece's gilt motif inside it
## (a beast's own piece also a glowing stone at `stone`).
static func _trim(b, lk: Dictionary, slot: String, outline: PackedVector2Array, stone := Vector2.INF) -> void:
	var edge := _edge(lk, slot)
	if edge.a > 0.0:
		b.path(outline, Color(edge, 0.85), 1.6, true)
	var n := _named(lk, slot)
	if n > 0:
		var c := Vector2.ZERO
		for p in outline:
			c += p
		c /= maxf(1.0, outline.size())
		var inner := PackedVector2Array()
		for p in outline:
			inner.append(p.lerp(c, 0.18))
		b.path(inner, Color(GILT, 0.65), 1.0, true)
		if n > 1 and stone != Vector2.INF:
			glow_into(b, stone, 9.0, edge if edge.a > 0.0 else GOLD, 0.9)
			b.ball(stone, 2.6, (edge if edge.a > 0.0 else GOLD).lightened(0.2), true)


## Mail: rings in rows across a region.
static func _mail(b, region: PackedVector2Array, col: Color, step := 5.0) -> void:
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p in region:
		lo = lo.min(p)
		hi = hi.max(p)
	var y := lo.y + step * 0.5
	var row := 0
	while y < hi.y:
		var x := lo.x + (step * 0.5 if row % 2 == 0 else step)
		while x < hi.x:
			var p := Vector2(x, y)
			if Geometry2D.is_point_in_polygon(p, region):
				b.dot(p, 1.2, Color(col.lightened(0.35), 0.55))
				b.dot(p + Vector2(0.3, 0.4), 0.6, Color(0, 0, 0, 0.35))
			x += step
		y += step * 0.8
		row += 1


## Behind everything: a backpack's bag over the shoulders, its bedroll on top.
static func front_behind(b, lk: Dictionary) -> void:
	if String(lk.get("pack", "")) != "pack":
		return
	var pc: Color = lk.get("pack_col", Palette.WOOD)
	var bag := _p([-34, -92, 34, -92, 38, -40, -38, -40])
	b.poly(bag, pc.darkened(0.12), 1.6)
	b.polygon(_p([-34, -92, 0, -92, 0, -40, -38, -40]), pc)
	# The bedroll strapped on top.
	b.poly(_p([-40, -104, 40, -104, 42, -92, -42, -92]), pc.lightened(0.2), 1.4)
	for x in [-26.0, 26.0]:
		b.line(Vector2(x, -105), Vector2(x, -91), pc.darkened(0.45), 2.0)
	_trim(b, lk, "backpack", bag)


## Over the legs: the boots (studs, laces, tall wading boots), a fine pair's edge.
static func front_legs(b, lk: Dictionary) -> void:
	var k := 1.0 + (float(lk.get("wx", 1.0)) - 1.0) * 0.6
	var boot: Color = lk["boot"]
	match String(lk.get("boot_look", "")):
		"hobnail":
			for sg in [-1.0, 1.0]:
				for i in 4:
					b.dot(Vector2(sg * (4.0 + i * 4.5) * k, 122.5), 1.2, Palette.STEEL)
		"laced":
			for sg in [-1.0, 1.0]:
				for y in [98.0, 104.0, 110.0]:
					b.line(Vector2(sg * 6 * k, y), Vector2(sg * 14 * k, y + 3.0), Color(0.86, 0.8, 0.66, 0.8), 1.0)
		"tall":
			for sg in [-1.0, 1.0]:
				b.poly(_sx(_p([sg * 2.5, 74, sg * 17.5, 74, sg * 17.5, 96, sg * 2.5, 96]), k), boot if sg < 0.0 else boot.darkened(0.25), 1.4)
				b.rect(Rect2(Vector2(minf(sg * 2.5, sg * 17.5) * k, 74), Vector2(15 * k, 4)), boot.lightened(0.22))
	if String(lk.get("boot_look", "")) != "":
		var e := _edge(lk, "boots")
		var top := 74.0 if String(lk.get("boot_look", "")) == "tall" else 93.0
		for sg in [-1.0, 1.0]:
			if e.a > 0.0:
				b.line(Vector2(sg * 3 * k, top), Vector2(sg * 17 * k, top), Color(e, 0.85), 1.4)


## Over the tunic: the chest piece by its weight (a leather cuirass with its
## strap, a mail hauberk, a steel breastplate with its faulds), and a
## backpack's straps.
static func front_chest(b, lk: Dictionary) -> void:
	var wx: float = lk.get("wx", 1.0)
	var col: Color = lk.get("armor_col", lk["tunic"])
	match String(lk.get("armor_w", "")):
		"leather":
			var cu := _sx(_p([-24, -62, 24, -62, 21, -24, 19, 14, -19, 14, -21, -24]), wx)
			b.poly(cu, col.darkened(0.16), 1.6)
			b.polygon(_sx(_p([-24, -62, 0, -62, 0, 14, -19, 14, -21, -24]), wx), col)
			for i in 3:  # tassets below the belt
				var x0 := (-20.0 + i * 13.5) * wx
				b.poly(_p([x0, 16, x0 + 12 * wx, 16, x0 + 11 * wx, 36, x0 + 1 * wx, 36]), col.darkened(0.1 + 0.08 * i), 1.2)
			b.line(Vector2(-18 * wx, -60), Vector2(16 * wx, -4), col.darkened(0.45), 3.2)  # the strap
			b.rect(Rect2(Vector2(-5, -36), Vector2(6, 5)), Color(0.86, 0.7, 0.44))
			b.line(Vector2(-22 * wx, -40), Vector2(-10 * wx, -44), Color(col.lightened(0.35), 0.5), 1.4)
			_trim(b, lk, "armor", cu, Vector2(0, -30))
		"chain":
			var hb := _sx(_p([-27, -66, 27, -66, 24, -24, 23, 16, 27, 42, -27, 42, -23, 16, -24, -24]), wx)
			b.poly(hb, col.darkened(0.2), 1.6)
			b.polygon(_sx(_p([-27, -66, 0, -66, 0, 42, -27, 42, -23, 16, -24, -24]), wx), col.darkened(0.05))
			_mail(b, hb, col, 5.0)
			_trim(b, lk, "armor", hb, Vector2(0, -30))
		"plate":
			var bp := _sx(_p([-25, -64, 25, -64, 23, -30, 19, 8, 0, 12, -19, 8, -23, -30]), wx)
			b.poly(bp, col.darkened(0.25), 1.8)
			b.polygon(_sx(_p([-25, -64, 0, -64, 0, 12, -19, 8, -23, -30]), wx), col.darkened(0.05))
			b.line(Vector2(0, -60), Vector2(0, 10), Color(col.lightened(0.5), 0.8), 1.6)  # the ridge
			b.polygon(_sx(_p([-20, -58, -12, -60, -16, -30, -21, -34]), wx), Color(1, 1, 1, 0.22))  # its shine
			for i in 3:  # faulds
				var y := 12.0 + i * 8.0
				b.poly(_sx(_p([-22 - i, y, 22 + i, y, 23 + i, y + 8, -23 - i, y + 8]), wx), col.darkened(0.15 + 0.06 * i), 1.2)
			_trim(b, lk, "armor", bp, Vector2(0, -36))
	# A backpack's straps over the chest.
	if String(lk.get("pack", "")) == "pack":
		var pc: Color = lk.get("pack_col", Palette.WOOD)
		for sg in [-1.0, 1.0]:
			b.path(_p([sg * 15 * wx, -70, sg * 17 * wx, -46, sg * 24 * wx, -22]), Palette.OUTLINE, 6.4)
			b.path(_p([sg * 15 * wx, -70, sg * 17 * wx, -46, sg * 24 * wx, -22]), pc.darkened(0.15), 4.0)
			b.rect(Rect2(Vector2(sg * 17 * wx - 3, -50), Vector2(6, 5)), Color(0.86, 0.7, 0.44))


## The arms: mail sleeves or plate vambraces with the chest piece, the
## weapon in hand, then gloves over the hands (leather, gauntlets, bracers).
static func front_arms(b, lk: Dictionary) -> void:
	var wx: float = lk.get("wx", 1.0)
	var thick := 1.0 + (wx - 1.0) * 0.6
	var w: String = lk.get("armor_w", "")
	var col: Color = lk.get("armor_col", lk["tunic"])
	for sg in [-1.0, 1.0]:
		var sh := Vector2(sg * 28 * wx, -60)
		var el := Vector2(sg * (40 + (wx - 1.0) * 26.0), -24)
		var wr := Vector2(sg * 48, 1)
		var shade := 0.0 if sg < 0.0 else 0.2
		match w:
			"chain":
				b.stroke(sh, el, col.darkened(0.12 + shade), 12.0 * thick)
				_mail(b, _p([sh.x - 5, sh.y, sh.x + 5, sh.y, el.x + 5, el.y, el.x - 5, el.y]), col, 4.5)
			"plate":
				b.stroke(el + (wr - el) * 0.15, wr - (wr - el) * 0.1, col.darkened(0.1 + shade), 12.0 * thick)  # vambrace
				b.ball(el, 5.0, col.darkened(shade), true)  # couter
	_front_weapon(b, lk)
	var glove: String = lk.get("glove", "")
	var gc: Color = lk.get("glove_col", lk["hand"])
	for sg in [-1.0, 1.0]:
		var hand := Vector2(sg * 50, 9)
		var wr := Vector2(sg * 48, 1)
		var shade := 0.0 if sg < 0.0 else 0.16
		match glove:
			"leather":
				b.stroke(wr + Vector2(0, -6), wr + Vector2(0, 1), gc.darkened(0.1 + shade), 13.0)  # the cuff
				b.ball(hand, 7.0, gc.darkened(shade), true)
			"plate":
				b.stroke(wr + Vector2(0, -7), wr + Vector2(0, 1), gc.darkened(0.1 + shade), 14.0)
				b.ball(hand, 7.4, gc.darkened(shade), true)
				for i in 3:
					b.line(hand + Vector2(-5, -2 + i * 3.0), hand + Vector2(5, -2 + i * 3.0), Color(0, 0, 0, 0.35), 1.0)
				b.dot(hand + Vector2(-2.5, -3.5), 1.4, Color(1, 1, 1, 0.35))
			"bracers":
				var el := Vector2(sg * (40 + (wx - 1.0) * 26.0), -24)
				b.stroke(el.lerp(wr, 0.3), wr, gc.darkened(shade), 12.0 * thick)
				for i in 3:
					var p := el.lerp(wr, 0.4 + i * 0.18)
					b.line(p + Vector2(-5, 0), p + Vector2(5, 0), Color(0.86, 0.78, 0.6, 0.8), 1.0)
		if glove != "":
			var e := _edge(lk, "gloves")
			if e.a > 0.0:
				b.arc(hand, 7.8, PI * 0.9, PI * 2.1, 10, Color(e, 0.8), 1.2)


## The weapon in the figure's right hand (on the viewer's left), held at
## its side: the full game's front figure's sword, dagger, war hammer or
## shortbow, in its skin (the skin's colour and a glow along it, like a fine
## weapon's in the full game).
static func _front_weapon(b, lk: Dictionary) -> void:
	var id: String = lk.get("in_hand", "")
	if id == "":
		return
	var sk := skin_look(String(lk.get("weapon_skin", "")))
	var col: Color = lk.get("weapon_col", Palette.STEEL)
	var steel: Color = col if id != "shortbow" else Palette.STEEL
	var guard: Color = Palette.STEEL.darkened(0.35)
	var pommel: Color = Palette.STEEL.darkened(0.2)
	var wood := Palette.WOOD.darkened(0.15)
	var shine := Color(1, 1, 1)
	var glow := Color(0, 0, 0, 0)
	if not sk.is_empty():
		steel = sk["blade"]
		col = sk["blade"]
		guard = (sk["hilt"] as Color).lightened(0.2)
		pommel = (sk["hilt"] as Color).lightened(0.35)
		wood = (sk["hilt"] as Color).lightened(0.1)
		shine = sk["shine"]
		glow = sk["glow"]
	var hand := Vector2(-50, 9)
	match id:
		"dagger":
			var tip := hand + Vector2(-8, 38)
			if glow.a > 0.0: b.line(hand + Vector2(-1, 6), tip, Color(glow, 0.35), 8.0)
			b.poly(_p([hand.x - 3.5, hand.y + 6, hand.x + 2.5, hand.y + 6, tip.x, tip.y]), steel, 1.2)
			if glow.a > 0.0: b.line(hand + Vector2(-0.5, 8), tip + Vector2(0.5, -5), Color(shine, 0.6), 1.0)
			b.stroke(hand + Vector2(-7, 5), hand + Vector2(6, 5), guard, 2.4)
		"sword":
			var tip2 := hand + Vector2(-14, 92)
			if glow.a > 0.0: b.line(hand + Vector2(-1, 8), tip2, Color(glow, 0.35), 10.0)
			b.poly(_p([hand.x - 4.5, hand.y + 8, hand.x + 3.5, hand.y + 8, tip2.x + 1.5, tip2.y - 6, tip2.x, tip2.y, tip2.x - 2, tip2.y - 6]), steel, 1.3)
			b.line(hand + Vector2(-0.5, 10), tip2 + Vector2(0.5, -8), Color(shine, 0.45 if glow.a == 0.0 else 0.7), 1.0)
			b.stroke(hand + Vector2(-10, 7), hand + Vector2(9, 6), guard, 3.0)
			b.dot(hand + Vector2(1.5, -9), 3.0, pommel)
		"war_hammer":
			var foot := Vector2(-58, 104)
			b.stroke(hand + Vector2(1, -8), foot, wood, 4.2)
			var hh := _p([foot.x - 14, foot.y - 18, foot.x + 10, foot.y - 18, foot.x + 10, foot.y - 2, foot.x - 14, foot.y - 2])
			if glow.a > 0.0: b.polygon(_oval(foot + Vector2(-2, -10), Vector2(18, 14)), Color(glow, 0.25))
			b.poly(hh, steel, 1.5)
			b.rect(Rect2(Vector2(foot.x - 13, foot.y - 17), Vector2(5, 14)), Color(shine, 0.22 if glow.a == 0.0 else 0.4))
		"shortbow":
			var reach := 70.0
			var pts := PackedVector2Array()
			for i in 13:
				var u := float(i) / 12.0
				pts.append(hand + Vector2(-sin(u * PI) * 14.0 - 2.0, lerpf(-reach, reach * 0.9, u)))
			if glow.a > 0.0: b.path(pts, Color(glow, 0.35), 8.0)
			b.path(pts, Palette.OUTLINE, 6.0)
			b.path(pts, col.darkened(0.05), 3.6)
			b.line(pts[0], pts[12], Color(0.92, 0.9, 0.82, 0.8), 1.0)
	if glow.a > 0.0:  # (the full game's named weapon: a glow at the hilt)
		glow_into(b, hand + Vector2(1, -10), 7.0, glow, 0.6)


## Over the mantle: pauldrons (plate, mail, leather), and the amulet on its chain.
static func front_shoulders(b, lk: Dictionary) -> void:
	var wx: float = lk.get("wx", 1.0)
	var col: Color = lk.get("pauldron_col", lk.get("armor_col", lk["tunic"]))
	var slot := String(lk.get("pauldron_slot", "armor"))
	match String(lk.get("pauldron_w", "")):
		"plate":
			for sg in [-1.0, 1.0]:
				var pa := _sx(_p([sg * 14, -74, sg * 32, -72, sg * 42, -58, sg * 40, -44, sg * 26, -50, sg * 16, -62]), wx)
				b.poly(pa, col.darkened(0.05 if sg < 0.0 else 0.3), 1.6)
				b.line(Vector2(sg * 20 * wx, -68), Vector2(sg * 38 * wx, -56), Color(col.lightened(0.45), 0.7), 1.4)
				_trim(b, lk, slot, pa)
		"chain":
			for sg in [-1.0, 1.0]:
				var pm := _sx(_p([sg * 16, -72, sg * 34, -68, sg * 40, -52, sg * 24, -54]), wx)
				b.poly(pm, col.darkened(0.1 if sg < 0.0 else 0.3), 1.2)
				_mail(b, pm, col, 4.5)
				if slot == "shoulders":
					_trim(b, lk, slot, pm)
		"leather":
			for sg in [-1.0, 1.0]:
				var pl := _sx(_p([sg * 18, -70, sg * 34, -66, sg * 38, -54, sg * 24, -56]), wx)
				b.poly(pl, col.darkened(0.2 if sg < 0.0 else 0.38), 1.2)
				b.dot(Vector2(sg * 30 * wx, -62), 1.4, Color(0.86, 0.7, 0.44))
				if slot == "shoulders":
					_trim(b, lk, slot, pl)
	if lk.get("amulet", false):
		# (A little bigger than the full game's, AMULET_K, so a child sees it.)
		var ac: Color = lk["amulet_col"]
		var k := AMULET_K
		var at := Vector2(0, -56 + 6.0 * k)
		b.path(_p([-10, -76, -5, -62, 0, at.y - 5.2 * k, 5, -62, 10, -76]), Color(GOLD.darkened(0.3), 0.95), 1.2)
		var e := _edge(lk, "amulet")
		if e.a > 0.0:
			glow_into(b, at, 10.0 * k, e, 0.55)
		b.poly(_oval(at, Vector2(4.2, 5.2) * k, 14), ac, 1.0)
		b.polygon(_oval(at + Vector2(-1.0, -1.2) * k, Vector2(1.6, 2.0) * k, 10), Color(ac.lightened(0.5), 0.8))
		if _named(lk, "amulet") > 0:
			b.path(_oval(at, Vector2(6.2, 7.2) * k, 14), Color(GILT, 0.8), 1.0, true)


## Over the head: a cap (a leather crown and band, a feather in it), a helm
## (a dome with cheek guards and a nasal; a miner's candle; a Watcher's with
## a narrow slit), or a mail coif's rings.
static func front_head(b, lk: Dictionary) -> void:
	var head: String = lk.get("head", "hood")
	var id: String = lk.get("helm_id", "")
	match head:
		"cap":
			var cap: Color = lk.get("cap", Palette.WOOD)
			var dome := PackedVector2Array()
			for i in 13:
				var a := PI + PI * float(i) / 12.0
				dome.append(Vector2(0, -106) + Vector2(cos(a) * 16.5, sin(a) * 19.0))
			b.poly(dome, cap, 1.5)
			b.polygon(_p([0, -125, 9, -122, 15, -114, 16.5, -106, 6, -106]), cap.darkened(0.2))
			b.poly(_p([-17, -110, 17, -110, 17.5, -104, -17.5, -104]), cap.darkened(0.3), 1.2)  # the band
			b.line(Vector2(-11, -119), Vector2(-4, -122), Color(cap.lightened(0.4), 0.6), 1.4)
			if id == "feathered_cap":
				var base := Vector2(13, -110)
				var tip := Vector2(30, -142)
				var dir := (tip - base).normalized()
				var n := dir.orthogonal()
				var vane := PackedVector2Array()
				for i in 7:
					var u := float(i) / 6.0
					vane.append(base.lerp(tip, u) + n * sin(u * PI) * 4.5)
				for i in 7:
					var u := 1.0 - float(i) / 6.0
					vane.append(base.lerp(tip, u) - n * sin(u * PI) * 3.6)
				b.poly(vane, Color(0.36, 0.56, 0.36), 1.0)
				b.line(base - dir * 3.0, tip, Color(0.2, 0.32, 0.2, 0.9), 1.0)
			_trim(b, lk, "helm", dome)
		"helm":
			var hc: Color = lk.get("helm_col", Palette.STEEL)
			var shell := _p([-17, -96, -17.5, -110, -14, -121, -7, -127, 0, -128.5, 7, -127, 14, -121, 17.5, -110, 17, -96, 14, -86, 9, -86, 10, -100, 4, -103, -4, -103, -10, -100, -9, -86, -14, -86])
			b.poly(shell, hc.darkened(0.1), 1.7)
			b.polygon(_p([-17, -96, -17.5, -110, -14, -121, -7, -127, 0, -128.5, 0, -103, -4, -103, -10, -100, -9, -86, -14, -86]), hc.lightened(0.05))
			b.polygon(_p([-12, -118, -6, -124, -2, -124, -8, -116]), Color(1, 1, 1, 0.3))  # its shine
			b.line(Vector2(0, -128), Vector2(0, -104), Color(hc.lightened(0.4), 0.7), 1.4)  # the crest
			if _named(lk, "helm") > 0 and id == "iron_helm":
				# A Watcher's Helm: a full face with a narrow slit.
				b.poly(_p([-10, -103, 10, -103, 9, -86, -9, -86]), hc.darkened(0.15), 1.2)
				b.line(Vector2(-8, -98), Vector2(8, -98), Palette.OUTLINE, 2.2)
			else:
				b.poly(_p([-1.8, -104, 1.8, -104, 1.6, -92, -1.6, -92]), hc.darkened(0.2), 1.0)  # the nasal
			for x in [-14.0, 14.0]:
				for y in [-112.0, -100.0]:
					b.dot(Vector2(x, y), 0.9, Color(hc.lightened(0.5), 0.8))  # rivets
			if id == "miners_helm":
				b.poly(_p([-3, -138, 3, -138, 3, -127, -3, -127]), Color(0.95, 0.92, 0.84), 1.0)
				glow_into(b, Vector2(0, -142), 14.0, CANDLE, 0.9)
				b.polygon(_p([0, -149, 2.4, -142, 0, -138, -2.4, -142]), CANDLE)
			_trim(b, lk, "helm", shell, Vector2(0, -122))
		"coif":
			var mc: Color = lk.get("coif_col", Palette.STEEL)
			var hood := _p([0, -147, 13, -141, 23, -127, 27, -106, 23, -88, 12, -79, 0, -77, -12, -79, -23, -88, -27, -106, -23, -127, -13, -141])
			var face := _oval(Vector2(0, -103), Vector2(15.6, 19.2), 24)
			for piece in Geometry2D.clip_polygons(hood, face):
				_mail(b, piece, mc, 4.6)
