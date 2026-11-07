extends RefCounted
## Gear: armor, and how weapons and armor are found and carried. Weapons
## themselves are defined in weapons.gd. Names, text and numbers live here
## so they're easy to change. Everything here is plain, common gear;
## enchanted gear and trinkets can be added later as more entries and slots.
##
## You carry: fists (always), one melee weapon, one ranged weapon and one
## suit of armor. Gear is per climb: every climb starts with a sword, a
## shortbow and no armor, except for slots holding an heirloom (below).

const Weapons := preload("res://scripts/weapons.gd")

## The chance a slain monster (not a beast) leaves a piece of gear.
const DROP_CHANCE := 0.04
## The chance a side room's essence cache also holds a piece of gear.
const CACHE_CHANCE := 0.35
## How close you must stand to gear on the floor to take it.
const REACH := 26.0
## The slots, in the order the HUD and the Body page list them.
const SLOTS := ["melee", "ranged", "armor"]
const SLOT_NAMES := {"fists": "Fists", "melee": "Melee", "ranged": "Ranged", "armor": "Armor"}

## Heirlooms: survive a climb and you may keep one piece you carried. It
## waits for you at the start of every later climb, in its slot, until you
## keep a different piece for that slot (or start a new climber). Each slot
## holds one heirloom. "gear" is the carried slot it fills; slots marked
## "planned" are for gear that doesn't exist yet, and show as such.
const HEIRLOOM_SLOTS := [
	{"id": "melee", "name": "Melee", "gear": "melee"},
	{"id": "ranged", "name": "Ranged", "gear": "ranged"},
	{"id": "chest", "name": "Chest", "gear": "armor"},
	{"id": "helm", "name": "Helm", "planned": true},
	{"id": "gloves", "name": "Gloves", "planned": true},
	{"id": "legs", "name": "Legs", "planned": true},
	{"id": "boots", "name": "Boots", "planned": true},
	{"id": "cloak", "name": "Cloak", "planned": true},
	{"id": "amulet", "name": "Amulet", "planned": true},
	{"id": "rings", "name": "Rings", "planned": true},
	{"id": "backpack", "name": "Backpack", "planned": true},
]
const HEIRLOOM_TEXT := {
	"title": "CHOOSE AN HEIRLOOM",
	"sub": "You survived. Keep one piece you carried: every climb will begin with it.",
	"replaces": "replaces your %s",
	"empty_slot": "new %s heirloom",
	"none_name": "Keep nothing new",
	"none_desc": "your heirlooms stay as they are",
	"kept": "Heirloom kept: %s",
	"planned": "planned",
}

## The words the gear prompt and camp cards use.
const TEXT := {
	"on_floor": "ON THE FLOOR",
	"take_key": "Y  take it",
	"take_tap": "Tap Take",
	"drops": "(drops your %s here)",
	"took": "Took the %s",
	"camp_desc": "%s",
	"carrying": "carrying: %s",
	"none": "no armor",
	"cache": "The cache holds a %s",
}

## Armor. Reduction cuts the damage of attacks that land (not poison or
## burning floor). Heavier armor makes rolls cost more and carry you less
## far, stamina refill slower, and you walk a little slower.
##   reduce     fraction of a landed attack's damage taken off
##   roll_cost  multiplier on a roll's stamina cost
##   roll_dist  multiplier on how far a roll carries you
##   regen      multiplier on how fast stamina refills
##   walk       multiplier on walking (and sprinting) speed
const ARMOR_ORDER := ["", "padded", "leather", "chain", "plate"]
const ARMOR := {
	"": {
		"name": "No armor",
		"short": "None",
		"desc": "nothing but your cloak: light and quick",
		"reduce": 0.0, "roll_cost": 1.0, "roll_dist": 1.0, "regen": 1.0, "walk": 1.0,
		"color": Color(0.28, 0.55, 0.62),
	},
	"padded": {
		"name": "Padded Armor",
		"short": "Padded",
		"desc": "quilted cloth: a little protection for almost no weight",
		"reduce": 0.08, "roll_cost": 1.05, "roll_dist": 0.98, "regen": 0.98, "walk": 1.0,
		"color": Color(0.72, 0.64, 0.5),
		"drop_weight": 4,
	},
	"leather": {
		"name": "Leather Armor",
		"short": "Leather",
		"desc": "hardened leather: fair protection, still nimble",
		"reduce": 0.15, "roll_cost": 1.12, "roll_dist": 0.95, "regen": 0.95, "walk": 0.98,
		"color": Color(0.5, 0.33, 0.2),
		"drop_weight": 4,
	},
	"chain": {
		"name": "Chain Mail",
		"short": "Chain",
		"desc": "rings of steel: good protection; rolls cost more and stamina comes back slower",
		"reduce": 0.25, "roll_cost": 1.3, "roll_dist": 0.88, "regen": 0.87, "walk": 0.95,
		"color": Color(0.62, 0.65, 0.7),
		"drop_weight": 3,
	},
	"plate": {
		"name": "Plate Armor",
		"short": "Plate",
		"desc": "heavy steel: the best protection, but rolls are short and costly, and you tire fast",
		"reduce": 0.35, "roll_cost": 1.55, "roll_dist": 0.76, "regen": 0.75, "walk": 0.9,
		"color": Color(0.8, 0.82, 0.88),
		"drop_weight": 1,
	},
}

## How common each weapon is as a drop (fists are always carried).
const WEAPON_DROP_WEIGHT := {
	"dagger": 4, "sword": 3, "axe": 4, "mace": 3, "spear": 4, "greatsword": 2, "war_hammer": 2,
	"shortbow": 3, "longbow": 2, "crossbow": 2,
}

## Monsters favour gear that suits them: these are four times as likely.
const FAVOUR_MULT := 4
const FAVOUR := {
	"knight": ["chain", "plate", "sword", "mace", "greatsword"],
	"archer": ["shortbow", "longbow", "crossbow", "leather"],
	"smith": ["war_hammer", "mace", "chain", "plate"],
	"shellback": ["mace", "chain"],
	"ram": ["war_hammer", "axe"],
	"thornhound": ["dagger", "leather"],
	"mongrel": ["axe", "spear", "leather"],
	"scorpling": ["dagger", "padded"],
	"thunderling": ["spear", "chain"],
	"lurker": ["spear", "padded"],
	"slime": ["padded", "dagger"],
	"bat": ["dagger", "shortbow"],
	"cinder": ["shortbow", "crossbow"],
	"wisp": ["shortbow", "padded"],
	"bloomcap": ["padded", "leather"],
}


static func is_armor(id: String) -> bool:
	return ARMOR.has(id)


static func is_gear(id: String) -> bool:
	return (Weapons.WEAPONS.has(id) and id != "fists") or (ARMOR.has(id) and id != "")


## Which slot a piece of gear goes in: "melee", "ranged", "armor" (or "fists").
static func slot_of(id: String) -> String:
	if Weapons.WEAPONS.has(id):
		return Weapons.WEAPONS[id]["slot"]
	return "armor"


static func info(id: String) -> Dictionary:
	if Weapons.WEAPONS.has(id):
		return Weapons.WEAPONS[id]
	return ARMOR.get(id, {})


static func display(id: String) -> String:
	return info(id).get("name", "nothing")


static func short(id: String) -> String:
	return info(id).get("short", "-")


static func armor(id: String) -> Dictionary:
	return ARMOR.get(id, ARMOR[""])


## A colour for gear: armor has its own; weapons are steel, bows wood.
static func color(id: String) -> Color:
	if ARMOR.has(id):
		return ARMOR[id]["color"]
	if Weapons.is_ranged(id):
		return Color(0.85, 0.66, 0.42)
	return Color(0.82, 0.85, 0.92)


## Key numbers for comparing: [label, shown text, value, higher is better].
static func stats(id: String) -> Array:
	if Weapons.WEAPONS.has(id):
		return Weapons.stats(id)
	var a := armor(id)
	return [
		["Protection", "%d%%" % int(round(a["reduce"] * 100.0)), a["reduce"], true],
		["Roll cost", "+%d%%" % int(round((a["roll_cost"] - 1.0) * 100.0)), a["roll_cost"], false],
		["Roll reach", "-%d%%" % int(round((1.0 - a["roll_dist"]) * 100.0)), a["roll_dist"], true],
		["Stamina back", "-%d%%" % int(round((1.0 - a["regen"]) * 100.0)), a["regen"], true],
		["Walk", "-%d%%" % int(round((1.0 - a["walk"]) * 100.0)), a["walk"], true],
	]


## One line of key stats, for the Body page and the dev tools.
static func summary(id: String) -> String:
	var parts: Array = []
	for s in stats(id):
		parts.append("%s %s" % [String(s[0]).to_lower(), s[1]])
	return "  ·  ".join(parts)


## A random piece of gear, weighted by how common each is. A monster's kind
## favours gear that suits it; `exclude` leaves out what you already carry.
static func random_gear(kind := "", exclude: Array = []) -> String:
	var pool := {}
	for id in WEAPON_DROP_WEIGHT:
		pool[id] = int(WEAPON_DROP_WEIGHT[id])
	for id in ARMOR:
		if id != "":
			pool[id] = int(ARMOR[id]["drop_weight"])
	for id in FAVOUR.get(kind, []):
		if pool.has(id):
			pool[id] *= FAVOUR_MULT
	var total := 0
	for id in pool:
		if not (id in exclude):
			total += pool[id]
	if total <= 0:
		return "dagger"
	var roll := randi() % total
	for id in pool:
		if id in exclude:
			continue
		roll -= pool[id]
		if roll < 0:
			return id
	return "dagger"


## The heirloom slot a piece of gear fills ("chest" for armor).
static func heirloom_slot(id: String) -> String:
	var gs := slot_of(id)
	for s in HEIRLOOM_SLOTS:
		if s.get("gear", "") == gs:
			return s["id"]
	return ""


## The carried slot an heirloom slot fills ("" for a planned slot).
static func gear_slot_for(heirloom_slot_id: String) -> String:
	for s in HEIRLOOM_SLOTS:
		if s["id"] == heirloom_slot_id:
			return s.get("gear", "")
	return ""


static func heirloom_slot_name(heirloom_slot_id: String) -> String:
	for s in HEIRLOOM_SLOTS:
		if s["id"] == heirloom_slot_id:
			return s["name"]
	return heirloom_slot_id


# --- drawing -----------------------------------------------------------------------

## A piece of gear's icon, drawn in code, centred on `c` (about 2*s across).
## `col` tints it (the HUD dims slots that aren't in hand).
static func draw_icon(ci: CanvasItem, id: String, c: Vector2, s: float, col: Color) -> void:
	var w := maxf(1.0, s * 0.22)
	var u := s / 10.0  # the HUD's icons were drawn at s = 10
	match id:
		"fists":
			ci.draw_circle(c + Vector2(-4, 2) * u, 5.0 * u, col)
			ci.draw_circle(c + Vector2(5, -2) * u, 5.0 * u, col)
		"dagger":
			ci.draw_line(c + Vector2(-6, 6) * u, c + Vector2(6, -6) * u, col, w * 1.2)
			ci.draw_line(c + Vector2(-7, 1) * u, c + Vector2(-1, 7) * u, col, w)
		"sword":
			ci.draw_line(c + Vector2(-9, 9) * u, c + Vector2(9, -9) * u, col, w * 1.4)
			ci.draw_line(c + Vector2(-9, 2) * u, c + Vector2(-2, 9) * u, col, w * 1.1)
		"greatsword":
			ci.draw_line(c + Vector2(-10, 10) * u, c + Vector2(10, -10) * u, col, w * 2.0)
			ci.draw_line(c + Vector2(-11, 3) * u, c + Vector2(-3, 11) * u, col, w * 1.2)
		"axe":
			ci.draw_line(c + Vector2(-8, 9) * u, c + Vector2(6, -7) * u, col, w)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(2, -9) * u, c + Vector2(10, -6) * u, c + Vector2(7, 2) * u, c + Vector2(3, -3) * u]), col)
		"mace":
			ci.draw_line(c + Vector2(-8, 8) * u, c + Vector2(3, -3) * u, col, w)
			ci.draw_circle(c + Vector2(5, -5) * u, 4.5 * u, col)
			for i in 6:
				var a := TAU * i / 6.0
				ci.draw_line(c + Vector2(5, -5) * u, c + Vector2(5, -5) * u + Vector2.from_angle(a) * 6.5 * u, col, w * 0.7)
		"spear":
			ci.draw_line(c + Vector2(-10, 10) * u, c + Vector2(6, -6) * u, col, w * 0.9)
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(11, -11) * u, c + Vector2(4, -6) * u, c + Vector2(6, -4) * u]), col)
		"war_hammer":
			ci.draw_line(c + Vector2(-8, 9) * u, c + Vector2(4, -5) * u, col, w * 1.1)
			var hd := PackedVector2Array([c + Vector2(-1, -9) * u, c + Vector2(4, -12) * u, c + Vector2(11, -2) * u, c + Vector2(6, 1) * u])
			ci.draw_colored_polygon(hd, col)
		"shortbow", "longbow":
			var r := 11.0 if id == "shortbow" else 13.0
			var o := c + Vector2(-4, 0) * u
			ci.draw_arc(o, r * u, -1.1, 1.1, 12, col, w * 1.1)
			ci.draw_line(o + Vector2.from_angle(-1.1) * r * u, o + Vector2.from_angle(1.1) * r * u, col, maxf(1.0, w * 0.4))
			ci.draw_line(c + Vector2(-6, 0) * u, c + Vector2(10, 0) * u, col, w * 0.6)
		"crossbow":
			ci.draw_line(c + Vector2(-9, 0) * u, c + Vector2(9, 0) * u, col, w * 1.1)
			ci.draw_arc(c + Vector2(1, 0) * u, 8.0 * u, -1.25, 1.25, 10, col, w)
			ci.draw_line(c + Vector2(1, 0) * u + Vector2.from_angle(-1.25) * 8.0 * u, c + Vector2(-2, 0) * u, col, maxf(1.0, w * 0.4))
			ci.draw_line(c + Vector2(1, 0) * u + Vector2.from_angle(1.25) * 8.0 * u, c + Vector2(-2, 0) * u, col, maxf(1.0, w * 0.4))
		"", "padded", "leather", "chain", "plate":
			# A breastplate: a torso shape, with the armor's look on it.
			var body := PackedVector2Array([
				c + Vector2(-8, -8) * u, c + Vector2(-3, -10) * u, c + Vector2(0, -7) * u, c + Vector2(3, -10) * u,
				c + Vector2(8, -8) * u, c + Vector2(7, 1) * u, c + Vector2(4, 9) * u, c + Vector2(-4, 9) * u, c + Vector2(-7, 1) * u])
			if id == "":
				var closed := body.duplicate()
				closed.append(body[0])
				ci.draw_polyline(closed, Color(col, col.a * 0.6), maxf(1.0, w * 0.5), true)
				return
			ci.draw_colored_polygon(body, col)
			var mark := Color(0, 0, 0, 0.35 * col.a)
			match id:
				"padded":
					for y in [-3.0, 1.0, 5.0]:
						ci.draw_line(c + Vector2(-6, y) * u, c + Vector2(6, y) * u, mark, maxf(1.0, w * 0.4))
				"leather":
					ci.draw_line(c + Vector2(0, -6) * u, c + Vector2(0, 8) * u, mark, maxf(1.0, w * 0.5))
				"chain":
					for y in [-4.0, 0.0, 4.0]:
						for x in [-4.0, 0.0, 4.0]:
							ci.draw_arc(c + Vector2(x, y) * u, 1.6 * u, 0.0, TAU, 6, mark, maxf(1.0, w * 0.3))
				"plate":
					ci.draw_line(c + Vector2(-7, -1) * u, c + Vector2(7, -1) * u, mark, maxf(1.0, w * 0.5))
					ci.draw_line(c + Vector2(-5, 4) * u, c + Vector2(5, 4) * u, mark, maxf(1.0, w * 0.5))
					ci.draw_circle(c + Vector2(-3, -5) * u, 1.6 * u, Color(1, 1, 1, 0.4 * col.a))
		_:
			ci.draw_circle(c, s * 0.5, col)
