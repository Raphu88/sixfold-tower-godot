extends RefCounted
## Worn gear on the climber: how each piece you wear changes the climber's
## look, and the gear layers drawn over the body (everything in code, in
## the game's style: outlined, shaded from the top-left).
##
## dress(look, gear, in_hand) takes a look (appearance.gd look(), the
## colours and flags worked out from the saved appearance) and lays the
## worn gear over it: the chest piece's colours and weight (cloth, leather,
## mail or plate), the helm (a hood, a cap or a helm: a helm or cap pushes
## your hood down, so your hair shows under it), gloves, boots, the legs,
## the cloak (a worn cloak's colour replaces your own; a Fine or better one
## edges it in its rarity's colour), the backpack, the amulet and rings,
## and the weapons. player.gd, mirror.gd and the menus' front figure all
## dress the climber this way, so the same pieces show everywhere.
##
## Then the drawing reads the keys dress() set:
##   In the tower (seen from above; player.gd and mirror.gd, between
##   appearance.gd's layers):
##     tower_back   after the cloak: the backpack, the weapon not in hand
##                  slung across your back
##     tower_chest  after the armour: the amulet's glint, a glow along a fine
##                  chest piece
##     tower_head   after the head: a miner's candle, a cap's feather, a
##                  fine helm's crest
##     ring_glint   on the hand (player.gd)
##     (the legs: appearance.gd draw_legs reads "greave")
##   On the front figure (appearance.gd draw_front calls these in order when
##   the look is dressed, "gear_on"):
##     front_behind     a backpack and a slung bow, behind everything
##     front_legs       leg armour, boots
##     front_chest      body armour by weight, a backpack's straps
##     front_arms       the weapon in hand, gloves, rings
##     front_shoulders  pauldrons, the amulet
##     front_head       a cap, a helm or a mail coif
## Rarity shows as a thin edge in the rarity's colour (Fine and up), and a
## named piece (Rare tower pieces, Storied, Regarded) in its own colour with
## a gilt motif; Regarded pieces also carry a glowing stone.

const Gear := preload("res://scripts/gear.gd")
const Weapons := preload("res://scripts/weapons.gd")
const Palette := preload("res://scripts/palette.gd")
const UI := preload("res://scripts/ui.gd")

## The looks of the chest by weight, and of the other worn slots, by piece.
## (Pieces not listed look like their slot's plain kind.)
const ARMOR_WEIGHT := {"padded": "cloth", "leather": "leather", "chain": "mail", "plate": "plate"}
const LEGS_LOOK := {"padded_trousers": "cloth", "leather_leggings": "leather", "ranger_breeches": "leather", "chain_leggings": "mail", "plated_greaves": "plate"}
const GLOVES_LOOK := {"grip_wraps": "wraps", "leather_gloves": "leather", "gauntlets": "plate", "archers_bracers": "bracers", "studded_gloves": "studded"}
const BOOTS_LOOK := {"soft_boots": "soft", "climbing_boots": "laced", "hobnail_boots": "hobnail", "wading_boots": "tall"}
const PACK_LOOK := {"satchel": "satchel", "belt_pouch": "pouch", "climbers_pack": "pack", "herb_pouch": "herbs", "bandolier": "bandolier"}
const CLOAK_LOOK := {"feather_cape": "short"}
## The candle of a miner's helm, a feathered cap's feather.
const CANDLE := Color(1.0, 0.82, 0.4)
const FEATHER := Color(0.86, 0.82, 0.72)


# --- dressing the look --------------------------------------------------------------

## A dressed copy of `look` (the appearance's), for the gear you wear.
static func dressed(look: Dictionary, gear: Dictionary, in_hand := "") -> Dictionary:
	var lk := look.duplicate()
	dress(lk, gear, in_hand)
	return lk


## Lays the worn gear over a look, in place (see the top of the file).
static func dress(look: Dictionary, gear: Dictionary, in_hand := "") -> void:
	before_armor(look, gear)
	armor_look(look, gear)
	after_armor(look, gear)
	extras(look, gear, in_hand)


## Before the chest piece: the head as the appearance has it (hood up or
## down), the boots' size, and a worn cloak's colour (the hood follows it).
static func before_armor(look: Dictionary, gear: Dictionary) -> void:
	look["head"] = "hood" if look.get("hood_up", true) else "bare"
	look["boot_r"] = 3.0
	look["studs"] = false
	var cl = gear.get("cloak", {})
	if Gear.is_gear(cl):
		look["cloak"] = Gear.color(cl)
		var style: String = CLOAK_LOOK.get(Gear.base_id(cl), "")
		if style != "":
			look["cloak_style"] = style
		if Gear.rarity(cl) != "common":
			look["trim_on"] = true  # (a fine cloak is edged in its rarity's colour)
			look["trim"] = Gear.rarity_color(cl)
		if Gear.NAMED.has(Gear.named_id(cl)):
			look["pattern"] = "embroidered"


## Colours and sizes for the chest piece (none: the tunic and cloak).
static func armor_look(look: Dictionary, gear: Dictionary) -> void:
	var cloak: Color = look["cloak"]
	look["torso"] = look["tunic"]
	look["shoulder"] = cloak.darkened(0.12)
	look["shoulder_r"] = 4.6
	look["sleeve"] = look["tunic"]
	look["hand"] = look["skin"]
	look["hood"] = cloak.darkened(0.22)
	var a = gear.get("armor", {})
	var id := Gear.base_id(a)
	if id == "":
		return
	var col: Color = Gear.color(a)
	match id:
		"padded":
			look["torso"] = col
			look["shoulder"] = col.darkened(0.08)
			look["shoulder_r"] = 5.0
			look["sleeve"] = col.darkened(0.15)
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


## After the chest piece: the head (plate brings a helm, mail a coif; a helm
## piece overrides both), gloves and boots. A helm or cap pushes the hood
## down (the front figure reads "hood_up"), so the hair shows under it.
static func after_armor(look: Dictionary, gear: Dictionary) -> void:
	var arm := Gear.base_id(gear.get("armor", {}))
	match arm:
		"plate":
			look["head"] = "helm"
			look["helm_col"] = Gear.color(gear["armor"])
		"chain":
			look["head"] = "coif"
			look["coif_col"] = Gear.color(gear["armor"])
	var hm = gear.get("helm", {})
	if Gear.is_gear(hm):
		var col := Gear.color(hm)
		match String(Gear.info(hm).get("look", "hood")):
			"cap":
				look["head"] = "cap"
				look["cap"] = col
			"helm":
				look["head"] = "helm"
				look["hood"] = col.darkened(0.1)
				look["helm_col"] = col
			_:
				look["head"] = "hood"
				look["hood"] = col
	match String(look["head"]):
		"hood":
			if Gear.is_gear(hm):
				look["hood_up"] = true
				look["hood_front"] = look["hood"]
		"cap", "helm":
			look["hood_up"] = false
		"coif":
			look["hood_up"] = true
			look["hood_front"] = look.get("coif_col", look["hood"])
	var gl = gear.get("gloves", {})
	if Gear.is_gear(gl):
		look["hand"] = Gear.color(gl).darkened(0.15)
	var bt = gear.get("boots", {})
	if Gear.is_gear(bt):
		look["boot"] = Gear.color(bt).darkened(0.1)
		match String(Gear.info(bt).get("look", "")):
			"hobnail":
				look["boot_r"] = 3.4
				look["studs"] = true
			"soft":
				look["boot_r"] = 2.8


## Everything else the drawing reads: what each slot looks like, its
## colours, rarity edges and named motifs, and the weapons ("in_hand" is the
## weapon id in hand, else the melee weapon, else the ranged one).
static func extras(look: Dictionary, gear: Dictionary, in_hand := "") -> void:
	look["gear_on"] = true
	var arm = gear.get("armor", {})
	look["armor_w"] = ARMOR_WEIGHT.get(Gear.base_id(arm), "")
	look["armor_col"] = Gear.color(arm) if Gear.is_gear(arm) else look["tunic"]
	_mark(look, "armor", arm)
	var hm = gear.get("helm", {})
	look["helm_id"] = Gear.base_id(hm)
	_mark(look, "helm", hm)
	var lg = gear.get("legs", {})
	look["legs_w"] = LEGS_LOOK.get(Gear.base_id(lg), "cloth" if Gear.is_gear(lg) else "")
	if Gear.is_gear(lg):
		var lc := Gear.color(lg)
		look["legs_col"] = lc
		if look["legs_w"] in ["cloth", "leather"]:
			look["trousers"] = lc  # (the legs themselves, in the tower too)
		elif look["legs_w"] == "mail":
			look["greave"] = lc.lightened(0.15)
		else:
			look["greave"] = lc.lightened(0.3)
	_mark(look, "legs", lg)
	var gl = gear.get("gloves", {})
	var glove := String(GLOVES_LOOK.get(Gear.base_id(gl), "leather" if Gear.is_gear(gl) else ""))
	if glove == "":
		glove = {"plate": "plate", "leather": "leather"}.get(Gear.base_id(arm), "")  # (plate brings gauntlets, leather gloves)
	look["glove"] = glove
	look["glove_col"] = Gear.color(gl) if Gear.is_gear(gl) else look["hand"]
	_mark(look, "gloves", gl)
	var bt = gear.get("boots", {})
	look["boot_look"] = BOOTS_LOOK.get(Gear.base_id(bt), "plain" if Gear.is_gear(bt) else "")
	_mark(look, "boots", bt)
	var bp = gear.get("backpack", {})
	look["pack"] = PACK_LOOK.get(Gear.base_id(bp), "pack" if Gear.is_gear(bp) else "")
	look["pack_col"] = Gear.color(bp) if Gear.is_gear(bp) else Color.WHITE
	_mark(look, "backpack", bp)
	var am = gear.get("amulet", {})
	look["amulet"] = Gear.is_gear(am)
	look["amulet_col"] = Gear.color(am) if Gear.is_gear(am) else Color.WHITE
	_mark(look, "amulet", am)
	for rs in ["ring1", "ring2"]:
		var rg = gear.get(rs, {})
		look[rs] = Gear.is_gear(rg)
		look[rs + "_col"] = Gear.color(rg) if Gear.is_gear(rg) else Color.WHITE
		_mark(look, rs, rg)
	var cl = gear.get("cloak", {})
	_mark(look, "cloak", cl)
	# The weapons: the one in hand, and the other slung on your back.
	var melee := Gear.base_id(gear.get("melee", {}))
	var ranged := Gear.base_id(gear.get("ranged", {}))
	var hand := in_hand
	if hand == "" or not (hand == "fists" or hand == melee or hand == ranged):
		hand = melee if melee != "" else ranged
	look["in_hand"] = hand
	var slot := "melee" if hand == melee and melee != "" else ("ranged" if hand == ranged and ranged != "" else "")
	look["weapon_slot"] = slot
	look["weapon_col"] = Gear.color(gear.get(slot, {})) if slot != "" else Palette.STEEL
	_mark(look, "weapon", gear.get(slot, {}) if slot != "" else {})
	look["slung"] = ranged if slot != "ranged" else melee
	look["slung_col"] = Gear.color(gear.get("ranged" if slot != "ranged" else "melee", {}))
	look["named_weapon"] = Gear.named_id(gear.get(slot, {})) if slot != "" else ""


## A slot's rarity edge ("<slot>_edge": its rarity's colour, Fine and up; a
## clear colour otherwise) and whether it's a named piece ("<slot>_named":
## 0 none, 1 a named piece, 2 Regarded).
static func _mark(look: Dictionary, slot: String, g) -> void:
	var on := Gear.is_gear(g) and Gear.rarity(g) != "common"
	look[slot + "_edge"] = Gear.rarity_color(g) if on else Color(0, 0, 0, 0)
	var n := 0
	if Gear.is_gear(g) and Gear.NAMED.has(Gear.named_id(g)):
		n = 2 if Gear.rarity(g) == "regarded" else 1
	look[slot + "_named"] = n


static func _edge(lk: Dictionary, slot: String) -> Color:
	return lk.get(slot + "_edge", Color(0, 0, 0, 0))


static func _named(lk: Dictionary, slot: String) -> int:
	return int(lk.get(slot + "_named", 0))


# --- the tower: seen from above --------------------------------------------------
# In the drawing frame: `f` forward, `sd` toward the weapon hand, `light`
# the light's direction; `lx` the body's offset (a lean).

static func _q(f: Vector2, sd: Vector2, x: float, y: float) -> Vector2:
	return f * x + sd * y


## After the cloak: the backpack on your back, and the weapon not in your
## hand slung across it.
static func tower_back(b, lx: Vector2, f: Vector2, sd: Vector2, light: Vector2, lk: Dictionary) -> void:
	if not lk.get("gear_on", false):
		return
	var slung: String = lk.get("slung", "")
	if slung != "" and Weapons.WEAPONS.has(slung):
		var kind := String(Weapons.WEAPONS[slung]["kind"])
		var col: Color = lk.get("slung_col", Palette.WOOD)
		if kind == "bow":
			var c := lx + _q(f, sd, -5.0, 0.0)
			b.arc(c, 9.5, (-f).angle() - 1.15, (-f).angle() + 1.15, 10, Palette.OUTLINE, 2.6)
			b.arc(c, 9.5, (-f).angle() - 1.1, (-f).angle() + 1.1, 10, col.darkened(0.15), 1.4)
			b.line(c + Vector2.from_angle((-f).angle() - 1.1) * 9.5, c + Vector2.from_angle((-f).angle() + 1.1) * 9.5, Color(0.9, 0.88, 0.8, 0.6), 0.6)
		elif kind == "crossbow":
			b.stroke(lx + _q(f, sd, -9.0, -5.0), lx + _q(f, sd, -6.0, 6.0), col.darkened(0.2), 1.6)
		elif kind == "gun":
			# A pistol in its holster at the hip: dark leather, the grip showing.
			var hip := lx + _q(f, sd, -1.0, -8.5)
			b.stroke(hip + _q(f, sd, 2.5, 0.0), hip + _q(f, sd, -3.0, 0.0), Color(0.3, 0.2, 0.14), 2.6)
			b.stroke(hip + _q(f, sd, -3.0, 0.0), hip + _q(f, sd, -4.5, 2.2), col.darkened(0.15), 1.6)
		elif slung in ["cane", "sword_cane"]:
			# A cane across the back, its knob over the shoulder.
			b.stroke(lx + _q(f, sd, -9.5, 7.0), lx + _q(f, sd, -2.5, -7.0), Palette.WOOD.darkened(0.25), 1.4)
			b.dot(lx + _q(f, sd, -2.5, -7.0), 1.5, Palette.STEEL if slung == "sword_cane" else Palette.WOOD.lightened(0.15))
		else:
			# A melee weapon on your back: its hilt over the shoulder.
			b.stroke(lx + _q(f, sd, -9.5, 6.5), lx + _q(f, sd, -2.0, -6.0), col.darkened(0.25), 1.4)
			b.dot(lx + _q(f, sd, -2.0, -6.0), 1.2, Palette.STEEL)
	var pk: String = lk.get("pack", "")
	if pk == "":
		return
	var pc: Color = lk.get("pack_col", Palette.WOOD)
	var edge := _edge(lk, "backpack")
	match pk:
		"pack":
			var at := lx + _q(f, sd, -8.0, 0.0)
			b.ball(at, 5.4, pc, true, light)
			b.stroke(lx + _q(f, sd, -12.0, -6.5), lx + _q(f, sd, -12.0, 6.5), pc.lightened(0.15), 2.6)  # the bedroll
			if edge.a > 0.0:
				b.arc(at, 5.6, 0.0, TAU, 12, Color(edge, 0.7), 0.8)
		"satchel", "herbs":
			var at2 := lx + _q(f, sd, -3.0, -8.5)
			b.ball(at2, 3.2, pc, true, light)
			if pk == "herbs":
				b.dot(at2 + _q(f, sd, 0.5, 0.5), 1.2, Color(0.5, 0.75, 0.35))
			b.line(lx + _q(f, sd, 3.0, 7.0), at2, pc.darkened(0.3), 1.0)
		"pouch":
			b.ball(lx + _q(f, sd, 3.5, -7.5), 2.2, pc, true, light)
		"bandolier":
			b.line(lx + _q(f, sd, 6.0, 7.0), lx + _q(f, sd, -7.0, -7.0), pc.darkened(0.2), 2.0)
			for i in 3:
				b.dot(lx + _q(f, sd, 3.0 - 4.0 * i, 3.5 - 4.2 * i), 1.0, pc.lightened(0.25))
		_:
			b.ball(lx + _q(f, sd, -7.5, 0.0), 4.4, pc, true, light)


## After the armour: the amulet's glint at the chest, a fine chest piece's
## glow along its edge, a named one's gilt line.
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
		b.arc(c, r - 2.2, fa - 0.7, fa + 0.7, 8, Color(UI.GILT, 0.7), 0.8)
	if lk.get("amulet", false):
		var ac: Color = lk["amulet_col"]
		var at := c + f * (r - 2.6)
		b.dot(at, 1.5, Palette.OUTLINE)
		b.dot(at, 1.0, ac)
		b.dot(at + Vector2(-0.4, -0.4), 0.4, Color(1, 1, 1, 0.5 + 0.4 * sin(t * 3.0)))


## After the head: a miner's candle, a feathered cap's feather, a fine
## helm's crest in its rarity's colour.
static func tower_head(b, hd: Vector2, f: Vector2, sd: Vector2, light: Vector2, lk: Dictionary, t := 0.0) -> void:
	if not lk.get("gear_on", false):
		return
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
	elif edge.a > 0.0 and head == "hood":
		b.arc(hd + f * 0.6, 6.0, f.angle() - 1.2, f.angle() + 1.2, 10, Color(edge, 0.7), 0.9)


## Rings: a glint on the hand that wears them.
static func ring_glint(b, hand: Vector2, lk: Dictionary, which := "ring1") -> void:
	if lk.get(which, false):
		b.dot(hand + Vector2(0.6, -0.6), 0.9, Color(lk[which + "_col"].lightened(0.3), 0.95))


# --- the front figure ------------------------------------------------------------
# In the climber screen's frame (about 290 tall, centred on the waist, lit
# from the top-left; appearance.gd draw_front). The figure's right hand (the
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
## (a Regarded piece also a glowing stone at `stone`).
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
		b.path(inner, Color(UI.GILT, 0.65), 1.0, true)
		if n > 1 and stone != Vector2.INF:
			UI.glow_into(b, stone, 9.0, edge if edge.a > 0.0 else UI.GOLD, 0.9)
			b.ball(stone, 2.6, (edge if edge.a > 0.0 else UI.GOLD).lightened(0.2), true)


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


## Behind everything: a backpack's bag over the shoulders (a bedroll on a
## Climber's Pack), and a bow or crossbow slung across your back (a quiver too).
static func front_behind(b, lk: Dictionary) -> void:
	var slung: String = lk.get("slung", "")
	var hand: String = lk.get("in_hand", "")
	if slung != "" and Weapons.WEAPONS.has(slung) and String(Weapons.WEAPONS[slung]["kind"]) != "melee":
		var col: Color = lk.get("slung_col", Palette.WOOD)
		if String(Weapons.WEAPONS[slung]["kind"]) == "gun":
			pass  # (a holstered pistol is worn at the hip, in front: front_arms)
		elif String(Weapons.WEAPONS[slung]["kind"]) == "bow":
			var pts := PackedVector2Array()
			for i in 11:
				var u := float(i) / 10.0
				pts.append(Vector2(lerpf(46.0, -40.0, u), lerpf(-112.0, 40.0, u)) + Vector2(-0.6, -0.8) * sin(u * PI) * 10.0)
			b.path(pts, Palette.OUTLINE, 6.0)
			b.path(pts, col.darkened(0.1), 3.6)
			b.line(pts[0], pts[10], Color(0.92, 0.9, 0.82, 0.7), 1.0)
			# The quiver over the other shoulder, its fletchings showing.
			b.poly(_p([-30, -104, -22, -108, -6, -60, -14, -56]), Color(0.42, 0.28, 0.16), 1.4)
			for k in 3:
				var tip := Vector2(-30 + k * 3.5, -110 - k * 2.0)
				b.line(tip, tip + Vector2(4, 9), Color(0.9, 0.86, 0.78), 2.2)
		else:
			b.poly(_p([22, -112, 30, -108, 0, -40, -8, -44]), col.darkened(0.2), 1.4)
			b.poly(_p([10, -112, 44, -98, 42, -92, 8, -106]), Palette.STEEL.darkened(0.25), 1.2)  # its prod over the shoulder
	elif slung in ["cane", "sword_cane"] and hand != slung:
		# A cane across your back, its handle over the right shoulder.
		b.stroke(Vector2(30, -118), Vector2(-20, 10), lk.get("slung_col", Palette.WOOD).darkened(0.1), 3.4)
		b.dot(Vector2(30, -120), 3.4, Palette.STEEL if slung == "sword_cane" else lk.get("slung_col", Palette.WOOD))
	elif slung != "" and Weapons.WEAPONS.has(slung) and hand != slung:
		# A melee weapon on your back: its hilt over the right shoulder.
		b.stroke(Vector2(30, -118), Vector2(-20, 10), Palette.STEEL.darkened(0.1), 4.0)
		b.stroke(Vector2(24, -102), Vector2(38, -108), Palette.STEEL.darkened(0.35), 2.6)
		b.dot(Vector2(32, -122), 3.0, Palette.WOOD.darkened(0.2))
	var pk: String = lk.get("pack", "")
	if pk in ["pack"]:
		var pc: Color = lk.get("pack_col", Palette.WOOD)
		var bag := _p([-34, -92, 34, -92, 38, -40, -38, -40])
		b.poly(bag, pc.darkened(0.12), 1.6)
		b.polygon(_p([-34, -92, 0, -92, 0, -40, -38, -40]), pc)
		# The bedroll strapped on top.
		b.poly(_p([-40, -104, 40, -104, 42, -92, -42, -92]), pc.lightened(0.2), 1.4)
		for x in [-26.0, 26.0]:
			b.line(Vector2(x, -105), Vector2(x, -91), pc.darkened(0.45), 2.0)
		_trim(b, lk, "backpack", bag)


## Over the legs: leg armour (quilted, leather, mail or plated greaves), and
## the boots (studs, laces, tall wading boots).
static func front_legs(b, lk: Dictionary) -> void:
	var k := 1.0 + (float(lk.get("wx", 1.0)) - 1.0) * 0.6
	var lw: String = lk.get("legs_w", "")
	var lc: Color = lk.get("legs_col", lk.get("trousers", Color.GRAY))
	for sg in [-1.0, 1.0]:
		var leg := _sx(_p([sg * 3, 12, sg * 17, 12, sg * 16, 94, sg * 4, 94]), k)
		var shade := 0.0 if sg < 0.0 else 0.18
		match lw:
			"cloth":
				for y in [26.0, 42.0, 58.0, 74.0]:
					b.line(Vector2(sg * 4 * k, y), Vector2(sg * 16 * k, y + 1.0), Color(0, 0, 0, 0.28), 1.0)
			"leather":
				b.poly(_sx(_p([sg * 5, 48, sg * 15, 48, sg * 15, 64, sg * 5, 64]), k), lc.darkened(0.25 + shade), 1.0)  # a knee panel
			"mail":
				b.polygon(leg, lc.darkened(0.15 + shade))
				_mail(b, leg, lc, 4.5)
			"plate":
				b.poly(_sx(_p([sg * 4, 58, sg * 16, 58, sg * 15, 92, sg * 5, 92]), k), lc.darkened(shade), 1.2)
				b.line(Vector2(sg * 7 * k, 62), Vector2(sg * 7 * k, 90), Color(lc.lightened(0.4), 0.7), 1.2)
				b.ball(Vector2(sg * 10 * k, 54), 5.2, lc.darkened(0.05 + shade), true)
		if lw != "":
			_trim(b, lk, "legs", leg)
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
		for sg in [-1.0, 1.0]:
			var e := _edge(lk, "boots")
			if e.a > 0.0:
				b.line(Vector2(sg * 3 * k, 93), Vector2(sg * 17 * k, 93), Color(e, 0.85), 1.4)


## Over the tunic: the chest piece by its weight (a quilted gambeson, a
## leather cuirass with its strap, a mail hauberk, a steel breastplate with
## its faulds), and a backpack's straps (a satchel's strap across you, a
## pouch at the belt, a bandolier's loops).
static func front_chest(b, lk: Dictionary) -> void:
	var wx: float = lk.get("wx", 1.0)
	var col: Color = lk.get("armor_col", lk["tunic"])
	var w: String = lk.get("armor_w", "")
	match w:
		"cloth":
			var vest := _sx(_p([-26, -64, 26, -64, 23, -24, 22, 28, -22, 28, -23, -24]), wx)
			b.poly(vest, col.darkened(0.14), 1.4)
			b.polygon(_sx(_p([-26, -64, 0, -64, 0, 28, -22, 28, -23, -24]), wx), col)
			for y in [-50.0, -36.0, -22.0, -8.0, 6.0, 20.0]:
				b.line(Vector2(-22 * wx, y), Vector2(22 * wx, y), Color(0, 0, 0, 0.22), 1.0)
			b.line(Vector2(0, -62), Vector2(0, 26), Color(0, 0, 0, 0.25), 1.0)
			_trim(b, lk, "armor", vest, Vector2(0, -30))
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
		"mail":
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
	# The backpack's straps and pouches, over the chest.
	var pk: String = lk.get("pack", "")
	var pc: Color = lk.get("pack_col", Palette.WOOD)
	match pk:
		"pack":
			for sg in [-1.0, 1.0]:
				b.path(_p([sg * 15 * wx, -70, sg * 17 * wx, -46, sg * 24 * wx, -22]), Palette.OUTLINE, 6.4)
				b.path(_p([sg * 15 * wx, -70, sg * 17 * wx, -46, sg * 24 * wx, -22]), pc.darkened(0.15), 4.0)
				b.rect(Rect2(Vector2(sg * 17 * wx - 3, -50), Vector2(6, 5)), Color(0.86, 0.7, 0.44))
		"satchel", "herbs":
			b.path(_p([-20 * wx, -68, 0, -32, 26 * wx, 10]), Palette.OUTLINE, 5.8)
			b.path(_p([-20 * wx, -68, 0, -32, 26 * wx, 10]), pc.darkened(0.2), 3.6)
			var bag := _p([20 * wx, 8, 42 * wx, 8, 44 * wx, 34, 18 * wx, 34])
			b.poly(bag, pc, 1.4)
			b.polygon(_p([20 * wx, 8, 42 * wx, 8, 42 * wx, 18, 20 * wx, 18]), pc.darkened(0.2))  # its flap
			if pk == "herbs":
				for i in 3:
					b.line(Vector2((26 + i * 5) * wx, 8), Vector2((24 + i * 6) * wx, -2), Color(0.45, 0.72, 0.3), 1.6)
			_trim(b, lk, "backpack", bag)
		"pouch":
			var pouch := _p([-24 * wx, 12, -12 * wx, 12, -11 * wx, 30, -25 * wx, 30])
			b.poly(pouch, pc, 1.3)
			b.polygon(_p([-24 * wx, 12, -12 * wx, 12, -12 * wx, 18, -24 * wx, 18]), pc.darkened(0.25))
			_trim(b, lk, "backpack", pouch)
		"bandolier":
			for d in [1.0, -1.0]:
				b.path(_p([d * -22 * wx, -66, d * 22 * wx, 12]), Palette.OUTLINE, 6.6)
				b.path(_p([d * -22 * wx, -66, d * 22 * wx, 12]), pc.darkened(0.1), 4.4)
			for i in 5:
				var u := float(i + 1) / 6.0
				var p := Vector2(-22 * wx, -66).lerp(Vector2(22 * wx, 12), u)
				b.rect(Rect2(p - Vector2(2.5, 3), Vector2(5, 6)), pc.lightened(0.2))


## The arms: the weapon in hand (held at your side, a greatsword's point to
## the floor, a spear upright, a bow in your fist), then gloves over the
## hands (wraps, leather, gauntlets, bracers, studs), vambraces on plate,
## mail sleeves, and rings.
static func front_arms(b, lk: Dictionary) -> void:
	_front_holster(b, lk)
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
			"mail":
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
			"wraps":
				b.ball(hand, 6.8, gc.darkened(shade), true)
				for i in 3:
					b.line(hand + Vector2(-6, -3 + i * 3.5), hand + Vector2(6, -5 + i * 3.5), Color(gc.darkened(0.35), 0.8), 1.0)
			"leather", "studded":
				b.stroke(wr + Vector2(0, -6), wr + Vector2(0, 1), gc.darkened(0.1 + shade), 13.0)  # the cuff
				b.ball(hand, 7.0, gc.darkened(shade), true)
				if glove == "studded":
					for p in [Vector2(-3, -2), Vector2(2, -3), Vector2(-1, 3), Vector2(3, 2)]:
						b.dot(hand + p, 1.1, Palette.STEEL)
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
	# Rings: a band and a stone on each hand that wears one.
	for pair in [["ring1", -1.0], ["ring2", 1.0]]:
		if lk.get(pair[0], false):
			var rc: Color = lk[pair[0] + "_col"]
			var at := Vector2(pair[1] * 50 + pair[1] * -3.0, 12)
			b.line(at + Vector2(-3, 0), at + Vector2(3, 0), UI.GOLD.darkened(0.15), 1.6)
			b.dot(at + Vector2(0, -0.5), 1.8, Palette.OUTLINE)
			b.dot(at + Vector2(0, -0.5), 1.3, rc)
			b.dot(at + Vector2(-0.5, -1.0), 0.5, Color(1, 1, 1, 0.8))
			var re := _edge(lk, pair[0])
			if re.a > 0.0:
				UI.glow_into(b, at, 6.0, re, 0.5)


## The weapon in the figure's right hand (on the viewer's left), drawn
## before the glove so the hand closes over its grip.
static func _front_weapon(b, lk: Dictionary) -> void:
	var id: String = lk.get("in_hand", "")
	if id == "" or id == "fists" or not Weapons.WEAPONS.has(id):
		return
	var w: Dictionary = Weapons.WEAPONS[id]
	var col: Color = lk.get("weapon_col", Palette.STEEL)
	var steel: Color = col if Weapons.WEAPONS[id]["kind"] == "melee" else Palette.STEEL
	var edge := _edge(lk, "weapon")
	var named := _named(lk, "weapon")
	var hand := Vector2(-50, 9)
	var wood := Palette.WOOD.darkened(0.15)
	var glow := edge if edge.a > 0.0 else Color(0, 0, 0, 0)
	match id:
		"dagger":
			var tip := hand + Vector2(-8, 38)
			if glow.a > 0.0: b.line(hand + Vector2(-1, 6), tip, Color(glow, 0.35), 8.0)
			b.poly(_p([hand.x - 3.5, hand.y + 6, hand.x + 2.5, hand.y + 6, tip.x, tip.y]), steel, 1.2)
			b.stroke(hand + Vector2(-7, 5), hand + Vector2(6, 5), Palette.STEEL.darkened(0.35), 2.4)
		"sword":
			var tip2 := hand + Vector2(-14, 92)
			if glow.a > 0.0: b.line(hand + Vector2(-1, 8), tip2, Color(glow, 0.35), 10.0)
			b.poly(_p([hand.x - 4.5, hand.y + 8, hand.x + 3.5, hand.y + 8, tip2.x + 1.5, tip2.y - 6, tip2.x, tip2.y, tip2.x - 2, tip2.y - 6]), steel, 1.3)
			b.line(hand + Vector2(-0.5, 10), tip2 + Vector2(0.5, -8), Color(1, 1, 1, 0.45), 1.0)
			b.stroke(hand + Vector2(-10, 7), hand + Vector2(9, 6), Palette.STEEL.darkened(0.35), 3.0)
			b.dot(hand + Vector2(1.5, -9), 3.0, Palette.STEEL.darkened(0.2))
		"greatsword":
			var tip3 := Vector2(-64, 128)
			if glow.a > 0.0: b.line(hand + Vector2(-1, 10), tip3, Color(glow, 0.35), 13.0)
			b.poly(_p([hand.x - 6, hand.y + 10, hand.x + 5, hand.y + 10, tip3.x + 3, tip3.y - 8, tip3.x, tip3.y, tip3.x - 3, tip3.y - 8]), steel, 1.4)
			b.line(hand + Vector2(-0.5, 12), tip3 + Vector2(0, -10), Color(1, 1, 1, 0.4), 1.2)
			b.stroke(hand + Vector2(-14, 9), hand + Vector2(13, 8), Palette.STEEL.darkened(0.35), 3.6)
			b.stroke(hand + Vector2(1, -2), hand + Vector2(2.5, -16), wood, 4.0)
			b.dot(hand + Vector2(2.8, -18), 3.4, Palette.STEEL.darkened(0.2))
		"axe", "mace", "war_hammer":
			var foot := Vector2(-58, 104 if id != "mace" else 86)
			b.stroke(hand + Vector2(1, -8), foot, wood, 4.2)
			match id:
				"axe":
					var head := _p([foot.x + 2, foot.y - 18, foot.x - 18, foot.y - 26, foot.x - 22, foot.y - 6, foot.x + 2, foot.y - 6])
					if glow.a > 0.0: b.polygon(_oval(foot + Vector2(-10, -14), Vector2(16, 14)), Color(glow, 0.25))
					b.poly(head, steel, 1.4)
					b.line(Vector2(foot.x - 21, foot.y - 24), Vector2(foot.x - 21, foot.y - 8), Color(1, 1, 1, 0.5), 1.2)
				"mace":
					if glow.a > 0.0: b.dot(foot, 14.0, Color(glow, 0.25))
					b.ball(foot, 8.0, steel, true)
					for a in 6:
						var d := Vector2.from_angle(a * TAU / 6.0)
						b.poly(_p([foot.x + d.x * 7, foot.y + d.y * 7, foot.x + d.x * 12 + d.y * 2, foot.y + d.y * 12 - d.x * 2, foot.x + d.x * 12 - d.y * 2, foot.y + d.y * 12 + d.x * 2]), steel.darkened(0.15), 0.8)
				"war_hammer":
					var hh := _p([foot.x - 14, foot.y - 18, foot.x + 10, foot.y - 18, foot.x + 10, foot.y - 2, foot.x - 14, foot.y - 2])
					if glow.a > 0.0: b.polygon(_oval(foot + Vector2(-2, -10), Vector2(18, 14)), Color(glow, 0.25))
					b.poly(hh, steel, 1.5)
					b.rect(Rect2(Vector2(foot.x - 13, foot.y - 17), Vector2(5, 14)), Color(1, 1, 1, 0.22))
		"spear":
			var bottom := Vector2(-56, 116)
			var top := Vector2(-44, -128)
			b.stroke(bottom, top, wood if named == 0 else col.darkened(0.2), 3.6)
			var dir := (top - bottom).normalized()
			var n := dir.orthogonal()
			if glow.a > 0.0: b.dot(top + dir * 6.0, 12.0, Color(glow, 0.25))
			if Gear.NAMED.has(String(lk.get("named_weapon", ""))) and String(lk["named_weapon"]) == "coral_trident":
				for k in [-1.0, 0.0, 1.0]:
					var base: Vector2 = top + n * k * 6.0
					b.stroke(base, base + dir * (14.0 if k == 0.0 else 10.0) + n * k * 1.5, col, 2.4)
				b.stroke(top + n * -6.5, top + n * 6.5, col.darkened(0.15), 2.6)
			else:
				b.poly(PackedVector2Array([top - n * 4.0, top + dir * 18.0, top + n * 4.0, top - dir * 2.0]), steel, 1.2)
		"shortbow", "longbow":
			var reach := 70.0 if id == "shortbow" else 92.0
			var pts := PackedVector2Array()
			for i in 13:
				var u := float(i) / 12.0
				pts.append(hand + Vector2(-sin(u * PI) * 14.0 - 2.0, lerpf(-reach, reach * 0.9, u)))
			if glow.a > 0.0: b.path(pts, Color(glow, 0.35), 8.0)
			b.path(pts, Palette.OUTLINE, 6.0)
			b.path(pts, col.darkened(0.05), 3.6)
			b.line(pts[0], pts[12], Color(0.92, 0.9, 0.82, 0.8), 1.0)
		"cane", "sword_cane":
			_front_cane(b, id, hand, col, glow)
		"flintlock", "revolver":
			_front_gun(b, id, hand, col, glow)
		"crossbow":
			var stock := _p([hand.x - 4, hand.y - 4, hand.x + 4, hand.y - 4, hand.x + 3, hand.y + 40, hand.x - 3, hand.y + 40])
			b.poly(stock, col.darkened(0.15), 1.3)
			b.path(_p([hand.x - 24, hand.y + 30, hand.x, hand.y + 36, hand.x + 24, hand.y + 30]), Palette.OUTLINE, 5.0)
			b.path(_p([hand.x - 24, hand.y + 30, hand.x, hand.y + 36, hand.x + 24, hand.y + 30]), Palette.STEEL.darkened(0.2), 3.0)
			b.line(Vector2(hand.x - 23, hand.y + 30), Vector2(hand.x + 23, hand.y + 30), Color(0.92, 0.9, 0.82, 0.8), 1.0)
	if named > 0:
		UI.glow_into(b, hand + Vector2(1, -10), 7.0, edge if edge.a > 0.0 else UI.GOLD, 0.6 + 0.3 * named)


## A cane in the tower, seen from above, lying along `along` from the grip:
## a dark wooden shaft with a steel tip and a hooked handle (a sword-cane's
## round silver knob and collar). `bare`: the sword-cane's blade is out,
## drawn as a slim blade from the knob. `col` tints a named one's wood.
static func tower_cane(b, id: String, grip: Vector2, along: Vector2, length: float, glint: float, light: Vector2, bare := false, col := Color(0, 0, 0, 0)) -> void:
	var side := along.orthogonal()
	var wood: Color = col if col.a > 0.0 else Palette.WOOD.darkened(0.25)
	if bare:
		# The drawn blade: thin and bright, no crossguard, the knob for a pommel.
		var tip := grip + along * (length + 2.0)
		b.line(grip + along * 1.5, tip, Palette.OUTLINE, 3.6)
		b.line(grip + along * 1.5, tip, Palette.STEEL.lightened(0.1), 1.8)
		b.line(grip + along * 3.0 + side * 0.4, tip - along * 2.0, Color(1, 1, 1, 0.45 + 0.45 * glint), 0.8)
		b.ball(grip - along * 2.5, 2.2, Palette.STEEL.lightened(0.15), true, light)
		return
	b.stroke(grip - along * 2.0, grip + along * length, wood, 2.2)
	b.dot(grip + along * length, 1.5, Palette.STEEL.darkened(0.15))  # the ferrule
	if id == "cane_sheath":
		b.stroke(grip - along * 2.0, grip - along * 0.4, Palette.STEEL, 2.6)  # the empty cane: its silver mouth
		return
	if id == "sword_cane":
		b.stroke(grip + along * 1.0, grip + along * 2.6, Palette.STEEL, 2.6)  # the collar where the blade parts
		b.ball(grip - along * 3.0, 2.4, Palette.STEEL.lightened(0.15), true, light)
	else:
		# The crook: a short hook behind the hand.
		var hook := PackedVector2Array([grip - along * 2.0, grip - along * 4.6 + side * 0.8, grip - along * 5.4 + side * 3.2, grip - along * 4.2 + side * 5.0])
		b.path(hook, Palette.OUTLINE, 4.6)
		b.path(hook, wood.lightened(0.1), 2.2)


## A pistol in the tower, seen from above, held at `grip` pointing along
## `dir`: a wooden grip, the lock, and the barrel (a flintlock's long
## barrel on a full stock with its hammer; a revolver's cylinder). `open`
## (0 to 1) swings a revolver's cylinder out to load it. `col` tints a
## named one's wood.
static func tower_gun(b, id: String, grip: Vector2, dir: Vector2, light: Vector2, open := 0.0, col := Color(0, 0, 0, 0)) -> void:
	var side := dir.orthogonal()
	var wood: Color = col if col.a > 0.0 else Palette.WOOD.darkened(0.1)
	var steel: Color = Palette.STEEL.darkened(0.2)
	if id == "flintlock":
		var muzzle := grip + dir * 16.0
		b.stroke(grip - dir * 3.5 - side * 1.6, grip + dir * 11.0, wood, 3.0)  # the stock, its butt curving down
		b.stroke(grip + dir * 1.0, muzzle, steel, 1.8)  # the barrel
		b.dot(muzzle, 1.4, Palette.OUTLINE)
		b.stroke(grip + dir * 0.5 + side * 1.4, grip - dir * 1.2 + side * 3.0, steel.darkened(0.2), 1.0)  # the hammer
		b.dot(grip - dir * 4.0 - side * 1.6, 1.4, UI.GOLD.darkened(0.2))  # the butt cap
	else:
		var muzzle2 := grip + dir * 12.0
		b.stroke(grip - dir * 2.5 - side * 1.8, grip + dir * 1.0, wood, 3.0)  # the grip
		b.stroke(grip + dir * 2.0, muzzle2, steel, 1.8)  # the barrel
		b.dot(muzzle2, 1.3, Palette.OUTLINE)
		var cyl := grip + dir * 3.2 + side * (3.6 * open)
		b.ball(cyl, 2.4, Palette.STEEL.darkened(0.05), true, light)  # the cylinder
		if open > 0.0:
			b.dot(cyl, 1.0, Palette.OUTLINE)  # its empty chambers


## A pistol in the front figure's hand, pointing down: a flintlock's long
## barrel on its wooden stock, or a revolver's cylinder and short barrel.
static func _front_gun(b, id: String, hand: Vector2, col: Color, glow: Color) -> void:
	var wood: Color = col
	var steel: Color = Palette.STEEL.darkened(0.15)
	if id == "flintlock":
		var muzzle := hand + Vector2(-4, 58)
		if glow.a > 0.0: b.line(hand + Vector2(0, 6), muzzle, Color(glow, 0.35), 10.0)
		b.poly(_p([hand.x - 4, hand.y - 12, hand.x + 6, hand.y - 6, hand.x + 4, hand.y + 40, hand.x - 3, hand.y + 40]), wood, 1.3)  # the stock
		b.poly(_p([hand.x - 2.5, hand.y + 4, hand.x + 2.5, hand.y + 4, muzzle.x + 2.2, muzzle.y, muzzle.x - 2.2, muzzle.y]), steel, 1.2)  # the barrel
		b.line(hand + Vector2(-1, 8), muzzle + Vector2(-0.6, -4), Color(1, 1, 1, 0.4), 1.0)
		b.poly(_p([hand.x + 3, hand.y - 2, hand.x + 10, hand.y - 8, hand.x + 11, hand.y - 4, hand.x + 5, hand.y + 3]), steel.darkened(0.2), 1.0)  # the hammer
		b.dot(hand + Vector2(-1, -12), 3.2, UI.GOLD.darkened(0.2))  # the butt cap
	else:
		var muzzle2 := hand + Vector2(-3, 44)
		if glow.a > 0.0: b.line(hand + Vector2(0, 6), muzzle2, Color(glow, 0.35), 10.0)
		b.poly(_p([hand.x - 4, hand.y - 12, hand.x + 5, hand.y - 10, hand.x + 4, hand.y + 6, hand.x - 3, hand.y + 6]), wood, 1.3)  # the grip
		b.poly(_p([hand.x - 2, hand.y + 18, hand.x + 2, hand.y + 18, muzzle2.x + 2, muzzle2.y, muzzle2.x - 2, muzzle2.y]), steel, 1.2)  # the barrel
		b.poly(_p([hand.x - 5.5, hand.y + 6, hand.x + 5.5, hand.y + 6, hand.x + 5, hand.y + 19, hand.x - 5, hand.y + 19]), Palette.STEEL.darkened(0.05), 1.2)  # the cylinder
		for k in [-2.5, 0.0, 2.5]:
			b.line(Vector2(hand.x + k, hand.y + 8), Vector2(hand.x + k, hand.y + 17), Color(0, 0, 0, 0.35), 0.8)
		b.line(hand + Vector2(-0.5, 20), muzzle2 + Vector2(-0.5, -3), Color(1, 1, 1, 0.4), 1.0)


## A pistol not in hand, in its holster at the hip (over the armour, under
## the arms), the grip out.
static func _front_holster(b, lk: Dictionary) -> void:
	var slung: String = lk.get("slung", "")
	if not Weapons.is_gun(slung) or lk.get("in_hand", "") == slung:
		return
	var col: Color = lk.get("slung_col", Palette.WOOD)
	b.poly(_p([26, 2, 38, 0, 40, 38, 30, 40]), Color(0.3, 0.2, 0.14), 1.4)
	b.poly(_p([28, 2, 36, 0, 42, -16, 34, -18]), col.darkened(0.05), 1.2)
	b.line(Vector2(27, 8), Vector2(39, 6), Color(0.86, 0.7, 0.44, 0.8), 1.2)  # its strap


## A cane in the front figure's hand, its tip to the ground: a dark shaft,
## a hooked handle (a sword-cane's silver knob and collar).
static func _front_cane(b, id: String, hand: Vector2, col: Color, glow: Color) -> void:
	var wood: Color = col
	var foot := Vector2(-60, 132)
	if glow.a > 0.0: b.line(hand + Vector2(0, 6), foot, Color(glow, 0.3), 9.0)
	b.stroke(hand + Vector2(0, -6), foot, wood, 4.0)
	b.dot(foot, 2.6, Palette.STEEL.darkened(0.15))
	if id == "sword_cane":
		b.stroke(hand + Vector2(-0.4, 8), hand + Vector2(-0.6, 13), Palette.STEEL, 5.0)
		b.ball(hand + Vector2(0.5, -12), 5.0, Palette.STEEL.lightened(0.1), true)
	else:
		var hook := _p([hand.x, hand.y - 6, hand.x + 2, hand.y - 13, hand.x + 8, hand.y - 16, hand.x + 13, hand.y - 12, hand.x + 13, hand.y - 6])
		b.path(hook, Palette.OUTLINE, 7.4)
		b.path(hook, wood.lightened(0.1), 4.4)


## Over the mantle: pauldrons (plate, mail, leather), and the amulet on its chain.
static func front_shoulders(b, lk: Dictionary) -> void:
	var wx: float = lk.get("wx", 1.0)
	var col: Color = lk.get("armor_col", lk["tunic"])
	match String(lk.get("armor_w", "")):
		"plate":
			for sg in [-1.0, 1.0]:
				var pa := _sx(_p([sg * 14, -74, sg * 32, -72, sg * 42, -58, sg * 40, -44, sg * 26, -50, sg * 16, -62]), wx)
				b.poly(pa, col.darkened(0.05 if sg < 0.0 else 0.3), 1.6)
				b.line(Vector2(sg * 20 * wx, -68), Vector2(sg * 38 * wx, -56), Color(col.lightened(0.45), 0.7), 1.4)
				_trim(b, lk, "armor", pa)
		"mail":
			for sg in [-1.0, 1.0]:
				var pm := _sx(_p([sg * 16, -72, sg * 34, -68, sg * 40, -52, sg * 24, -54]), wx)
				b.poly(pm, col.darkened(0.1 if sg < 0.0 else 0.3), 1.2)
				_mail(b, pm, col, 4.5)
		"leather":
			for sg in [-1.0, 1.0]:
				b.poly(_sx(_p([sg * 18, -70, sg * 34, -66, sg * 38, -54, sg * 24, -56]), wx), col.darkened(0.2 if sg < 0.0 else 0.38), 1.2)
				b.dot(Vector2(sg * 30 * wx, -62), 1.4, Color(0.86, 0.7, 0.44))
	if lk.get("amulet", false):
		var ac: Color = lk["amulet_col"]
		b.path(_p([-10, -76, -5, -62, 0, -54, 5, -62, 10, -76]), Color(UI.GOLD.darkened(0.3), 0.95), 1.2)
		var at := Vector2(0, -50)
		var e := _edge(lk, "amulet")
		if e.a > 0.0:
			UI.glow_into(b, at, 10.0, e, 0.55)
		b.poly(_oval(at, Vector2(4.2, 5.2), 14), ac, 1.0)
		b.polygon(_oval(at + Vector2(-1.0, -1.2), Vector2(1.6, 2.0), 10), Color(ac.lightened(0.5), 0.8))
		if _named(lk, "amulet") > 0:
			b.path(_oval(at, Vector2(6.2, 7.2), 14), Color(UI.GILT, 0.8), 1.0, true)


## Over the head: a cap (a leather crown and band, a feather in it), a helm
## (a dome with cheek guards and a nasal; a miner's candle; a named helm in
## its own colour, a Watcher's with a narrow slit), or a mail coif's rings.
## (A cloth hood is the appearance's own hood, in the hood's colour.)
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
			if lk.get("helm_named", 0) > 0 and String(lk.get("helm_id", "")) == "iron_helm":
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
				UI.glow_into(b, Vector2(0, -142), 14.0, CANDLE, 0.9)
				b.polygon(_p([0, -149, 2.4, -142, 0, -138, -2.4, -142]), CANDLE)
			_trim(b, lk, "helm", shell, Vector2(0, -122))
		"coif":
			var mc: Color = lk.get("coif_col", Palette.STEEL)
			var hood := _p([0, -147, 13, -141, 23, -127, 27, -106, 23, -88, 12, -79, 0, -77, -12, -79, -23, -88, -27, -106, -23, -127, -13, -141])
			var face := _oval(Vector2(0, -103), Vector2(15.6, 19.2), 24)
			var ring := Geometry2D.clip_polygons(hood, face)
			for piece in ring:
				_mail(b, piece, mc, 4.6)
	if head == "hood" and lk.get("helm_id", "") != "":
		var hood2 := _p([0, -147, 13, -141, 23, -127, 27, -106, 23, -88, 12, -79, 0, -77, -12, -79, -23, -88, -27, -106, -23, -127, -13, -141])
		_trim(b, lk, "helm", hood2)
