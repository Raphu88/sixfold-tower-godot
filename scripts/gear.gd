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
## The slots, in the order the HUD and the inventory list them.
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
	"take_pad": "{y}  take it",  # a controller ({y} becomes Y or Triangle)
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
##   walk       multiplier on walking speed
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


## One line of key stats, for the menus and the dev tools.
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
# Icons follow draw_util.gd's style guide: filled shapes with a dark outline,
# lit from the top-left, a pale glint on blades. Each icon is one Batch
# (one draw call) and uses only filled shapes, so it is safe under torchlight
# too (gear lying on the floor, fx.gd).

const Draw := preload("res://scripts/draw_util.gd")
const Palette := preload("res://scripts/palette.gd")
const _LEATHER := Color(0.36, 0.24, 0.16)
const _GOLD := Color(0.9, 0.72, 0.36)


## A piece of gear's icon, drawn in code, centred on `c` (about 2*s across).
## Weapons are drawn in their own steel and wood; armor in `col`. `col`'s
## alpha fades the whole icon, and a near-black `col` draws a flat silhouette
## (a drop shadow).
static func draw_icon(ci: CanvasItem, id: String, c: Vector2, s: float, col: Color) -> void:
	var b := Draw.Batch.new()
	icon_into(b, id, c, s, col)
	if col.v < 0.08:
		for i in b.cols.size():
			b.cols[i] = col
	elif col.a < 0.999:
		for i in b.cols.size():
			b.cols[i].a *= col.a
	b.flush(ci)


static func icon_into(b, id: String, c: Vector2, s: float, col: Color) -> void:
	var u := s / 10.0  # drawn on a grid of about -10..10
	var ol := clampf(u * 1.1, 0.8, 1.6)  # outline width
	var steel := Palette.STEEL
	var wood := Palette.WOOD
	var d := Vector2(1, -1).normalized()  # weapons lie from bottom-left to top-right
	var p := func(x: float, y: float) -> Vector2: return c + Vector2(x, y) * u
	match id:
		"fists":
			for f in [[Vector2(-4.6, 2.2), 1.0], [Vector2(4.2, -1.8), -1.0]]:
				var fc: Vector2 = c + f[0] * u
				var body := _rrect(fc, Vector2(4.4, 3.8) * u, 2.0 * u)
				b.poly(body, Palette.CLIMBER_SKIN.darkened(0.25), ol)
				b.polygon(_rrect(fc + Vector2(-0.5, -0.6) * u, Vector2(3.6, 3.0) * u, 1.6 * u), Palette.CLIMBER_SKIN)
				for k in 3:
					var kx := (-2.2 + k * 2.2) * u
					b.line(fc + Vector2(kx, -3.6 * u), fc + Vector2(kx, -1.0 * u), Palette.CLIMBER_SKIN.darkened(0.35), maxf(0.8, 0.6 * u))
				b.ball(fc + Vector2(f[1] * 4.0, 1.2) * u, 1.6 * u, Palette.CLIMBER_SKIN.darkened(0.08), true)
				# a wrap of cloth round the wrist
				b.rect(Rect2(fc + Vector2(-4.4, 3.0) * u, Vector2(8.8, 1.8) * u), Palette.CLIMBER_TUNIC)
		"dagger", "sword", "greatsword":
			var sz: Array = {"dagger": [-1.5, 7.5, 1.7, 3.4, 3.8], "sword": [-3.0, 9.5, 1.9, 4.6, 4.2], "greatsword": [-4.0, 10.5, 2.7, 6.0, 4.8]}[id]
			var base: Vector2 = c - d * absf(sz[0]) * u * 1.414
			var tip: Vector2 = c + d * sz[1] * u * 1.414
			var grip_end: Vector2 = base - d * sz[4] * u * 1.414
			b.stroke(base, grip_end, _LEATHER, 2.0 * u)
			for k in 3:
				var at := base.lerp(grip_end, 0.25 + k * 0.25)
				b.line(at + d.orthogonal() * 1.0 * u, at - d.orthogonal() * 1.0 * u, _LEATHER.darkened(0.4), maxf(0.7, 0.5 * u))
			_blade(b, base, tip, sz[2] * u, steel, ol)
			var side := d.orthogonal()
			b.stroke(base + side * sz[3] * u, base - side * sz[3] * u, _GOLD.darkened(0.15), (2.2 if id == "greatsword" else 1.7) * u)
			b.ball(grip_end - d * 1.4 * u, (1.6 if id == "dagger" else 2.0) * u, _GOLD, true)
		"axe":
			var h0: Vector2 = p.call(-8.0, 8.0)
			var h1: Vector2 = p.call(6.5, -6.5)
			b.stroke(h0, h1, wood, 2.2 * u)
			b.line(h0.lerp(h1, 0.06), h0.lerp(h1, 0.62), wood.lightened(0.25), maxf(0.7, 0.6 * u))
			# A bearded head: narrow at the haft, flaring to a curved edge.
			var side := Vector2(-1, -1).normalized()
			var m := h0.lerp(h1, 0.78)
			var head := PackedVector2Array([m + d * 1.8 * u, m + d * 1.9 * u + side * 2.6 * u])
			var edge := PackedVector2Array()
			for i in 9:
				var t := float(i) / 8.0
				edge.append(m + side * (6.4 + 1.3 * sin(t * PI)) * u + d * lerpf(4.6, -4.8, t) * u)
			head.append_array(edge)
			head.append_array([m - d * 2.1 * u + side * 2.6 * u, m - d * 1.8 * u])
			b.poly(PackedVector2Array([m + d * 1.6 * u, m - d * 1.6 * u, m - d * 1.4 * u - side * 2.2 * u, m + d * 1.4 * u - side * 2.2 * u]), steel.darkened(0.35), ol)
			b.poly(head, steel.darkened(0.3), ol)
			var lit := PackedVector2Array([m + d * 1.9 * u + side * 2.6 * u])
			for i in 5:
				lit.append(edge[i])
			lit.append(m + side * 4.0 * u)
			b.polygon(lit, steel.darkened(0.04))
			var glint := PackedVector2Array()
			for i in 8:
				glint.append(edge[i] - side * 0.8 * u)
			b.path(glint, Color(1, 1, 1, 0.6), maxf(0.8, 0.7 * u))
		"mace":
			var h0: Vector2 = p.call(-8.0, 8.0)
			var hc: Vector2 = p.call(4.4, -4.4)
			b.stroke(h0, hc, wood, 2.0 * u)
			b.ball(h0, 1.6 * u, _LEATHER, true)
			for i in 6:
				var a := TAU * i / 6.0 + 0.3
				b.poly(PackedVector2Array([hc + Vector2.from_angle(a - 0.42) * 3.2 * u, hc + Vector2.from_angle(a) * 6.6 * u, hc + Vector2.from_angle(a + 0.42) * 3.2 * u]), steel.darkened(0.25), ol)
			b.ball(hc, 4.0 * u, steel, true)
		"spear":
			var h0: Vector2 = p.call(-10.0, 10.0)
			var base: Vector2 = p.call(4.0, -4.0)
			b.stroke(h0, base, wood, 1.6 * u)
			_leaf(b, base, p.call(11.0, -11.0), 2.4 * u, steel, ol)
			b.stroke(base - d * 0.6 * u, base + d * 0.6 * u, _LEATHER, 2.6 * u)
		"war_hammer":
			var h0: Vector2 = p.call(-8.0, 8.0)
			var hc: Vector2 = p.call(4.6, -4.6)
			b.stroke(h0, hc + d * 2.2 * u, wood, 2.0 * u)
			var side := Vector2(1, 1).normalized()
			var blk := PackedVector2Array([hc - side * 1.5 * u - d * 2.8 * u, hc + side * 6.0 * u - d * 2.8 * u,
				hc + side * 6.0 * u + d * 2.8 * u, hc - side * 1.5 * u + d * 2.8 * u])
			var spike := PackedVector2Array([hc - side * 1.5 * u - d * 1.6 * u, hc - side * 6.8 * u, hc - side * 1.5 * u + d * 1.6 * u])
			b.poly(spike, steel.darkened(0.3), ol)
			b.poly(blk, steel.darkened(0.3), ol)
			b.polygon(PackedVector2Array([blk[0], blk[1], (blk[1] + blk[2]) * 0.5, (blk[0] + blk[3]) * 0.5]), steel.darkened(0.05))
			b.line(blk[1].lerp(blk[2], 0.1), blk[1].lerp(blk[2], 0.9), Color(1, 1, 1, 0.5), maxf(0.8, 0.8 * u))
		"shortbow", "longbow":
			var r := (10.5 if id == "shortbow" else 12.5) * u
			var o: Vector2 = p.call(-4.5, 0.0)
			var t0 := o + Vector2.from_angle(-1.15) * r
			var t1 := o + Vector2.from_angle(1.15) * r
			b.line(t0, t1, Color(0.92, 0.88, 0.8), maxf(0.8, 0.5 * u))  # the string
			_arrow(b, p.call(-6.5, 0.0), p.call(10.5, 0.0), u, ol)
			b.arc(o, r, -1.15, 1.15, 14, Palette.OUTLINE, 2.2 * u + ol * 2.0)
			b.arc(o, r, -1.15, 1.15, 14, wood, 2.2 * u)
			b.arc(o, r - 0.5 * u, -1.0, -0.15, 8, wood.lightened(0.3), maxf(0.7, 0.6 * u))
			b.stroke(o + Vector2(r, -1.8 * u), o + Vector2(r, 1.8 * u), _LEATHER, 2.6 * u)  # the grip
		"crossbow":
			var stock := PackedVector2Array([p.call(-10.0, 1.0), p.call(-10.0, -1.6), p.call(-4.0, -1.6), p.call(9.0, -0.8),
				p.call(9.0, 1.2), p.call(-3.0, 1.2), p.call(-6.0, 3.6), p.call(-9.0, 3.6)])
			var pc: Vector2 = p.call(1.5, 0.0)
			b.arc(pc, 8.0 * u, -1.25, 1.25, 12, Palette.OUTLINE, 2.0 * u + ol * 2.0)
			b.arc(pc, 8.0 * u, -1.25, 1.25, 12, steel.darkened(0.15), 2.0 * u)
			b.line(pc + Vector2.from_angle(-1.25) * 8.0 * u, p.call(-2.0, -0.2), Color(0.92, 0.88, 0.8), maxf(0.8, 0.5 * u))
			b.line(pc + Vector2.from_angle(1.25) * 8.0 * u, p.call(-2.0, 0.2), Color(0.92, 0.88, 0.8), maxf(0.8, 0.5 * u))
			b.poly(stock, wood.darkened(0.15), ol)
			b.polygon(PackedVector2Array([p.call(-10.0, -1.6), p.call(-4.0, -1.6), p.call(9.0, -0.8), p.call(9.0, 0.0), p.call(-10.0, 0.0)]), wood.lightened(0.1))
			_arrow(b, p.call(-2.0, -1.8), p.call(9.5, -1.8), u * 0.85, ol)
		"", "padded", "leather", "chain", "plate":
			var shape := [Vector2(-8, -7.5), Vector2(-3.4, -10), Vector2(0, -7), Vector2(3.4, -10), Vector2(8, -7.5),
				Vector2(7.2, 1), Vector2(4.4, 9.5), Vector2(-4.4, 9.5), Vector2(-7.2, 1)]
			var body := PackedVector2Array()
			for v in shape:
				body.append(c + v * u)
			if id == "":
				# No armor: a faint dashed outline where it would be.
				for i in body.size():
					var a := body[i]
					var bb := body[(i + 1) % body.size()]
					b.line(a.lerp(bb, 0.15), a.lerp(bb, 0.6), Color(col, 0.6), maxf(1.0, 0.8 * u))
				return
			b.poly(body, col.darkened(0.3), ol)
			b.polygon(PackedVector2Array([body[0], body[1], body[2], c + Vector2(0, 9.5) * u, body[7], body[8]]), col)
			b.polygon(PackedVector2Array([body[2], body[3], body[4], body[5], body[6], c + Vector2(0, 9.5) * u]), col.darkened(0.12))
			b.polygon(PackedVector2Array([body[1], body[2], c + Vector2(-1.0, -5.0) * u, c + Vector2(-5.5, -5.6) * u]), Color(col.lightened(0.35), 0.6))
			var dark := col.darkened(0.45)
			match id:
				"padded":
					for y in [-3.4, 0.6, 4.6]:
						b.line(c + Vector2(-6.6, y) * u, c + Vector2(6.6, y) * u, dark, maxf(0.8, 0.6 * u))
					for x in [-3.2, 3.2]:
						b.line(c + Vector2(x, -6.0) * u, c + Vector2(x, 8.6) * u, Color(dark, 0.6), maxf(0.7, 0.45 * u))
				"leather":
					b.line(c + Vector2(0, -6.4) * u, c + Vector2(0, 9.0) * u, dark, maxf(0.8, 0.6 * u))
					for y in [-1.0, 4.4]:
						b.rect(Rect2(c + Vector2(-6.8, y) * u, Vector2(13.6, 1.8) * u), Color(0.2, 0.13, 0.08))
						b.rect(Rect2(c + Vector2(-1.2, y - 0.3) * u, Vector2(2.4, 2.4) * u), _GOLD)
				"chain":
					for row in 5:
						for k in 5:
							var x := -5.2 + k * 2.6 + (1.3 if row % 2 == 1 else 0.0)
							var y := -5.2 + row * 2.9
							if absf(x) > 6.4 - maxf(0.0, y - 2.0) * 0.4:
								continue
							b.dot(c + Vector2(x, y) * u, 1.15 * u, dark)
							b.dot(c + Vector2(x - 0.3, y - 0.3) * u, 0.55 * u, col.lightened(0.35))
				"plate":
					for y in [-1.0, 3.8]:
						b.line(c + Vector2(-7.0, y) * u, c + Vector2(7.0, y) * u, dark, maxf(0.9, 0.8 * u))
						b.line(c + Vector2(-6.6, y + 0.9) * u, c + Vector2(6.6, y + 0.9) * u, Color(col.lightened(0.4), 0.6), maxf(0.6, 0.4 * u))
					for x in [-7.2, 7.2]:
						b.ball(c + Vector2(x, -7.4) * u, 2.8 * u, col.lightened(0.05), true)
					for x in [-4.6, 4.6]:
						b.dot(c + Vector2(x, 6.8) * u, 0.8 * u, dark)
		_:
			b.ball(c, s * 0.5, col, true)


## A blade from `base` to `tip`, ridged down the middle: the lit half paler,
## a glint along it.
static func _blade(b, base: Vector2, tip: Vector2, hw: float, metal: Color, ol: float) -> void:
	var dir := (tip - base).normalized()
	var side := dir.orthogonal()
	var len := base.distance_to(tip)
	var shoulder := base + dir * len * 0.8
	var pts := PackedVector2Array([base + side * hw, shoulder + side * hw * 0.92, tip, shoulder - side * hw * 0.92, base - side * hw])
	b.poly(pts, metal.darkened(0.28), ol)
	var lit := side if side.dot(Draw.LIGHT_DIR) > 0.0 else -side
	b.polygon(PackedVector2Array([base, base + lit * hw, shoulder + lit * hw * 0.92, tip]), metal.lightened(0.05))
	b.line(base + dir * len * 0.08 + lit * hw * 0.45, tip - dir * len * 0.12 + lit * hw * 0.2, Color(1, 1, 1, 0.6), maxf(0.7, hw * 0.3))


## A leaf-shaped spearhead.
static func _leaf(b, base: Vector2, tip: Vector2, hw: float, metal: Color, ol: float) -> void:
	var dir := (tip - base).normalized()
	var side := dir.orthogonal()
	var len := base.distance_to(tip)
	var wide := base + dir * len * 0.38
	var pts := PackedVector2Array([base + side * hw * 0.45, wide + side * hw, tip, wide - side * hw, base - side * hw * 0.45])
	b.poly(pts, metal.darkened(0.28), ol)
	var lit := side if side.dot(Draw.LIGHT_DIR) > 0.0 else -side
	b.polygon(PackedVector2Array([base, base + lit * hw * 0.45, wide + lit * hw, tip]), metal.lightened(0.05))


## An arrow lying from `tail` to `head`: fletching, shaft and a steel head.
static func _arrow(b, tail: Vector2, head: Vector2, u: float, ol: float) -> void:
	var dir := (head - tail).normalized()
	var side := dir.orthogonal()
	b.stroke(tail, head - dir * 2.0 * u, Palette.WOOD.lightened(0.15), 0.9 * u)
	b.poly(PackedVector2Array([head + dir * 1.0 * u, head - dir * 2.6 * u + side * 1.8 * u, head - dir * 2.6 * u - side * 1.8 * u]), Palette.STEEL, ol * 0.8)
	for sg in [1.0, -1.0]:
		b.polygon(PackedVector2Array([tail + dir * 3.2 * u, tail + side * sg * 1.9 * u + dir * 0.2 * u, tail - dir * 0.4 * u + side * sg * 1.6 * u, tail + dir * 0.6 * u]), Color(0.85, 0.3, 0.26) if sg > 0.0 else Color(0.92, 0.9, 0.85))


## A rounded rectangle's points (for fists and badges).
static func _rrect(c: Vector2, half: Vector2, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var corners := [Vector2(half.x - r, -half.y + r), Vector2(half.x - r, half.y - r), Vector2(-half.x + r, half.y - r), Vector2(-half.x + r, -half.y + r)]
	for k in 4:
		for i in 5:
			var a := -PI / 2.0 + (k + i / 4.0) * PI / 2.0
			pts.append(c + corners[k] + Vector2.from_angle(a) * r)
	return pts
