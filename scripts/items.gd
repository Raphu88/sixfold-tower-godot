extends RefCounted
## Items and camps: what the climber can carry, how often monsters drop
## them, and what a camp offers. Names and text live here so they're easy
## to change. The effects are in `use()` at the bottom.

## Each kind of item stacks up to this many.
const MAX_STACK := 3
## The belt holds this many kinds of item (a Belt Pouch or Climber's Pack
## adds one). Picking up another kind with a full belt asks which stack to
## swap out (main.gd offer_belt_swap).
const BELT_KINDS := 4
## Holding the item button this long opens the ring of belt items (time
## slows); a shorter press uses the quick item.
const RING_HOLD := 0.25
## Unused belt items at the end of a survived climb break into essence
## crystals at this share of their worth ("value").
const BREAK_SHARE := 0.5
## What every climb starts with.
const START := {"draught": 1}
## The chance that a slain monster (not a beast) leaves an item.
const DROP_CHANCE := 0.08
## Items lying on the floor fade after this many seconds.
const DROP_LIFE := 40.0

## Steady Hands (Surgeon's Body): healing items heal this much more...
const STEADY_HEAL := 1.3
## ...and take this much less time.
const STEADY_TIME := 0.6

const ORDER := ["draught", "tonic", "vial", "smoke", "fire_flask", "edge_oil", "warding_oil", "haste", "stoneskin", "salts", "flare", "scroll", "vessel"]

## Each item: name, short name, what it does, colour and its numbers; also
##   kind         its essence (the belt breaks it into this kind of crystal)
##   value        what it's worth in essence, by kind
##   drop_weight  how common it is (0: never found this way)
##   drop         false: never left by slain monsters (camps and vaults only)

const ITEMS := {
	"draught": {
		"name": "Healing Draught",
		"short": "Draught",
		"desc": "heals 40 health over a second and a half",
		"color": Color(0.9, 0.3, 0.32),
		"heal": 40.0,
		"time": 1.5,
		"drop_weight": 5,
		"kind": "stone", "value": {"stone": 12},
	},
	"tonic": {
		"name": "Cleansing Tonic",
		"short": "Tonic",
		"desc": "cures poison, heals every burned body part and a little health",
		"color": Color(0.45, 0.85, 0.5),
		"heal": 10.0,
		"time": 0.5,
		"drop_weight": 2,
		"kind": "water", "value": {"water": 10},
	},
	"vial": {
		"name": "Essence Vial",
		"short": "Vial",
		"desc": "fills every mark with essence",
		"color": Color(0.55, 0.75, 1.0),
		"drop_weight": 2,
		"needs_mark": true,
		"kind": "water", "value": {"water": 20},
	},
	"smoke": {
		"name": "Smoke Bomb",
		"short": "Smoke",
		"desc": "a cloud of smoke around you: monsters inside lose track of you (beasts don't)",
		"color": Color(0.68, 0.66, 0.7),
		"radius": 95.0,
		"duration": 5.0,
		"drop_weight": 1,
		"kind": "fire", "value": {"fire": 10},
	},
	"fire_flask": {
		"name": "Fire Flask",
		"short": "Flask",
		"desc": "thrown where you aim: it bursts in flame and leaves the floor burning for 3 seconds (it burns foes, not you)",
		"color": Color(1.0, 0.5, 0.18),
		"dmg": 30.0, "per_floor": 0.1, "radius": 46.0, "range": 160.0, "burn": 3.0, "flight": 0.35,
		"drop_weight": 2,
		"kind": "fire", "value": {"fire": 12},
	},
	"edge_oil": {
		"name": "Edge Oil",
		"short": "Edge Oil",
		"desc": "rubbed on your weapon: strikes hit 25% harder for 20 seconds",
		"color": Color(0.88, 0.42, 0.45),
		"mult": 1.25, "duration": 20.0,
		"drop_weight": 1,
		"kind": "blade", "value": {"blade": 15},
	},
	"warding_oil": {
		"name": "Warding Oil",
		"short": "Ward Oil",
		"desc": "a 25-point barrier for 15 seconds; traps can't hurt you while it holds",
		"color": Color(0.72, 0.78, 0.95),
		"shield": 25.0, "duration": 15.0,
		"drop_weight": 1, "drop": false,
		"kind": "iron", "value": {"iron": 15},
	},
	"haste": {
		"name": "Haste Draught",
		"short": "Haste",
		"desc": "for 10 seconds you walk 25% faster and rolls cost 30% less stamina",
		"color": Color(0.75, 0.95, 0.55),
		"walk": 0.25, "roll": 0.3, "duration": 10.0,
		"drop_weight": 1,
		"kind": "air", "value": {"air": 12},
	},
	"stoneskin": {
		"name": "Stoneskin Draught",
		"short": "Stoneskin",
		"desc": "for 12 seconds blows hurt 20% less and can't knock you back (protection still stops at half a blow)",
		"color": Color(0.7, 0.62, 0.5),
		"reduce": 0.2, "duration": 12.0,
		"drop_weight": 1, "drop": false,
		"kind": "stone", "value": {"stone": 12},
	},
	"salts": {
		"name": "Second Wind Salts",
		"short": "Salts",
		"desc": "a sharp breath: your stamina is full at once, and refills 50% faster for 8 seconds",
		"color": Color(0.92, 0.95, 0.98),
		"regen": 0.5, "duration": 8.0,
		"drop_weight": 1,
		"kind": "iron", "value": {"iron": 10},
	},
	"flare": {
		"name": "Flare Powder",
		"short": "Flare",
		"desc": "lights the room for 20 seconds; hidden traps and secret walls nearby glint",
		"color": Color(1.0, 0.85, 0.45),
		"duration": 20.0, "radius": 420.0, "reveal": 360.0,
		"drop_weight": 1,
		"kind": "air", "value": {"air": 8},
	},
	# From vaults (wings.gd), and always on the train's store shelf, priced
	# in crystals of any kind (train.gd ANY_PRICE): never dropped or offered at a camp.
	"scroll": {
		"name": "Recall Scroll",
		"short": "Scroll",
		"desc": "read it to leave the tower safely, keeping everything: your unbanked essence becomes essence crystals",
		"color": Color(0.95, 0.82, 0.5),
		"drop_weight": 0,
		"max": 1,
		"kind": "air", "value": {"air": 30, "water": 30},
	},
	# The vessel (vessel.gd, where its rules and words live; the name is a
	# placeholder): from a Rune Artist's bench or, very rarely, a vault. Not
	# sold, never stacked, never broken into crystals; using it only says
	# what it holds.
	"vessel": {
		"name": "Vessel",
		"short": "Vessel",
		"desc": "a sealed glass vessel bound in brass: it holds the secret essence that isn't your path instead of letting it pass (30 at most)",
		"color": Color(0.86, 0.64, 0.3),
		"drop_weight": 0, "drop": false,
		"max": 1,
	},
}

## Reading the recall scroll (main.gd read_recall). It asks first: use it
## again within CONFIRM seconds to read it.
const RECALL := {
	"confirm": 3.0,
	"ask_title": "READ THE RECALL SCROLL?",
	"ask": "Use it again within 3 seconds to leave the tower, keeping everything.",
	"ask_menu": "Press Read again to leave the tower now.",
	"first_climb": "The scroll's words won't come. The beast has not yet regarded you.",
	"title": "YOU LEAVE THE TOWER",
	"sub": "The scroll's words fold the tower away. %s lets you go, for now.",
	"crystals": "Unbanked essence settles into crystals: %s",
	"none": "You carried no unbanked essence.",
}

## Essence crystals (kept in the profile between climbs; crystals of a kind
## combine into one). Consuming banks up to "step" essence at a time.
const CRYSTAL := {
	"name": "%s Crystal",
	"desc": "holds %d %s essence outside you; consume it to bank that essence into you",
	"step": 10,
	"consume": "Consume %d",
	"consumed": "Consumed: %d %s essence banked into you",
	"held": "%d essence  ·  the train's money  ·  kept between climbs",
	"none": "No crystals of this kind yet. Each stair condenses a share of what you bank into crystals, the outfitter pays for every climb, and vaults and secret rooms may hold them.",
}


## The belt's words (the swap card, the break at the end of a climb).
const BELT := {
	"full_title": "YOUR BELT IS FULL",
	"full_sub": "Swap a stack out for the %s (it stays at your feet), or leave it.",
	"drop_name": "Swap out: %s",
	"drop_desc": "drop your %s here and take the %s",
	"leave_name": "Leave it",
	"leave_desc": "your belt stays as it is; the %s waits on the floor",
	"left": "Belt full: the %s is at your feet",
	"broke": "Your belt breaks into crystals: %s",
}

## Bond notes on items (cheap ones; more with the bench later).
const ASHWALKER_SMOKE := 2.0  # Smoke Bombs last twice as long
const CONTRACTOR_FLASK := 1.5  # Flame Contractor: Fire Flasks burst 50% wider
const FLAMEBLADE_OIL := 2.0  # Flameblade: Edge Oil builds heat twice as fast
const HUNTER_FLARE := 2.0  # Hunter: Flare Powder lasts twice as long


## How many of an item you can carry.
static func max_stack(id: String) -> int:
	return int(ITEMS.get(id, {}).get("max", MAX_STACK))


## What a belt of items breaks into: {kind: essence} at BREAK_SHARE of
## their worth. `items` is {id: count}.
static func break_value(items: Dictionary) -> Dictionary:
	var out := {}
	for id in items:
		for k in ITEMS.get(id, {}).get("value", {}):
			out[k] = float(out.get(k, 0.0)) + float(ITEMS[id]["value"][k]) * BREAK_SHARE * int(items[id])
	return out

# --- camps ---------------------------------------------------------------------

## On climbs of at least CAMP_MIN_FLOORS, taking the stair of each of these
## floors leads to a camp first: a safe room with a fire, a full rest and an
## item to take. (Camps aren't floors: the next floor is still the next one.)
const CAMP_AFTER := [3, 9]
const CAMP_MIN_FLOORS := 5
## How many item cards a camp offers.
const CAMP_CHOICES := 3

const CAMP := {
	"title": "CAMP",
	"choose": "CHOOSE ONE TO TAKE",
	"sub": "The fire is warm. You rest fully.",
	"rune_title": "RUNESMITH",
	"rune_sub": "By the firelight you can inscribe a rune on your gear, or craft something.",
	"leave": "The stair beyond the fire leads on.",
}

## Rune Artist's Runesmith at a camp: a rune on your gear that lasts the rest
## of the climb (the beast included), or one crafted item. The ids match the
## Inscribe spell's gear runes (bond.gd GEAR_RUNES).
const CAMP_RUNES := {
	"sharpness": {"name": "Rune of Sharpness", "desc": "your strikes hit harder for the rest of the climb", "color": Color(1.0, 0.7, 0.45)},
	"warding": {"name": "Rune of Warding", "desc": "you take less damage for the rest of the climb", "color": Color(0.6, 0.8, 1.0)},
	"swiftness": {"name": "Rune of Swiftness", "desc": "you move faster for the rest of the climb", "color": Color(0.7, 1.0, 0.7)},
}
const CRAFT := {"name": "Craft: %s", "desc": "craft a %s by the fire, as well as what you took"}


static func info(id: String) -> Dictionary:
	return ITEMS.get(id, {})


static func color(id: String) -> Color:
	return ITEMS.get(id, {}).get("color", Color.WHITE)


## A random item, weighted by how common each one is. Without a mark, an
## essence vial would do nothing, so `marked` false leaves those out;
## `dropped` (a slain monster's) leaves out the items never dropped.
static func random_item(marked := true, exclude: Array = [], dropped := false) -> String:
	var total := 0
	for id in ORDER:
		if _skip(id, marked, exclude, dropped):
			continue
		total += int(ITEMS[id]["drop_weight"])
	if total <= 0:
		return "draught"
	var roll := randi() % total
	for id in ORDER:
		if _skip(id, marked, exclude, dropped):
			continue
		roll -= int(ITEMS[id]["drop_weight"])
		if roll < 0:
			return id
	return "draught"


static func _skip(id: String, marked: bool, exclude: Array, dropped: bool) -> bool:
	return id in exclude or int(ITEMS[id]["drop_weight"]) <= 0 or (not marked and ITEMS[id].get("needs_mark", false)) \
		or (dropped and not ITEMS[id].get("drop", true))


## Three different items for a camp's cards.
static func camp_choices(marked := true) -> Array:
	var out: Array = []
	for i in CAMP_CHOICES:
		out.append(random_item(marked, out))
	return out


## Uses an item on the climber. Returns false (and says why) if it would do
## nothing, so it isn't wasted.
static func use(id: String, p) -> bool:
	var data := info(id)
	if data.is_empty():
		return false
	var main = p.main
	var col: Color = data["color"]
	var steady: bool = p.has_bond("surgeon")
	var above: Vector2 = p.global_position + Vector2(0, -44)
	if id == "scroll":
		# (main.gd asks first, then reads it: the climb ends there)
		return main.recall_pressed()
	if id == "vessel":
		return load("res://scripts/vessel.gd").use(p)  # (it says what it holds; never used up)
	match id:
		"draught":
			if p.hp >= p.max_health() - 0.5:
				main.fx_text(above, "Already at full health", Color(0.8, 0.78, 0.85))
				return false
			_heal_over_time(p, data, steady)
		"tonic":
			var burned := false
			for b in p.bonds.values():
				burned = burned or b.burned
			if not burned and p.poison_t <= 0.0 and p.hp >= p.max_health() - 0.5:
				main.fx_text(above, "Nothing to cleanse", Color(0.8, 0.78, 0.85))
				return false
			for b in p.bonds.values():
				b.burned = false
			p.poison_t = 0.0
			p.fire_t = 0.0
			_heal_over_time(p, data, steady)
			main.fx_text(above + Vector2(0, -16), "Cleansed", col)
		"vial":
			var room_for := false
			for b in p.bonds.values():
				room_for = room_for or b.essence < b.capacity() - 0.01
			if not room_for:
				main.fx_text(above, "No mark to fill" if p.bonds.is_empty() else "Your marks are full", Color(0.8, 0.78, 0.85))
				return false
			for b in p.bonds.values():
				b.essence = b.capacity()
			main.fx_text(above, "Marks filled", col)
			main.light_flash(p.global_position, col, 1.4, 1.4, 0.35)
		"smoke":
			var last: float = float(data["duration"]) * (ASHWALKER_SMOKE if p.has_bond("ashwalker") else 1.0)
			main.smokes.append({"pos": p.global_position, "r": float(data["radius"]), "t": last})
			main.fx_burst(p.global_position, Vector2.ZERO, col, 18, 160.0)
		"fire_flask":
			main.throw_flask(p)
		"edge_oil":
			p.edge_t = float(data["duration"])
			main.fx_text(above, "Edge oiled", col)
			main.sfx("equip_sword", 1.3, -6.0)
		"warding_oil":
			p.raise_barrier(float(data["shield"]), float(data["duration"]), false, col)
			p.ward_oil_t = float(data["duration"])
			main.fx_text(above, "Warded", col)
		"haste":
			p.haste_t = float(data["duration"])
			main.fx_text(above, "Haste", col)
			main.sfx("gust", 1.4, -6.0)
		"stoneskin":
			p.stone_t = float(data["duration"])
			main.fx_text(above, "Stoneskin", col)
			main.sfx("hit_armor", 0.8, -6.0)
		"salts":
			if p.sta >= p.max_sta - 0.5 and p.salts_t > 0.0:
				main.fx_text(above, "You're already breathing easy", Color(0.8, 0.78, 0.85))
				return false
			p.sta = p.max_sta
			p.salts_t = float(data["duration"])
			main.fx_text(above, "Second wind", col)
		"flare":
			var lasts: float = float(data["duration"]) * (HUNTER_FLARE if p.has_bond("hunter") else 1.0)
			main.light_flare(p.global_position, lasts)
			main.fx_burst(p.global_position, Vector2.ZERO, col, 22, 260.0)
	main.fx_ring(p.global_position, col, 34.0, 0.3, 3.0)
	main.sfx("ready", 1.0, -3.0)
	return true


## Healing items heal over a short time. Steady Hands heals more, faster.
static func _heal_over_time(p, data: Dictionary, steady: bool) -> void:
	var amount: float = float(data["heal"]) * (STEADY_HEAL if steady else 1.0) * p.heal_mult()  # Life's flow
	var t: float = float(data["time"]) * (STEADY_TIME if steady else 1.0)
	p.heal_left += amount
	p.heal_rate = maxf(p.heal_rate if p.heal_left > amount else 0.0, amount / t)
	p.main.fx_text(p.global_position + Vector2(0, -44), "+%d" % int(round(amount)), Color(0.6, 1.0, 0.7))


# --- drawing -----------------------------------------------------------------------
# Icons follow draw_util.gd's style guide (filled, outlined, lit from the
# top-left, one Batch each, no wide lines), so they also work lying on the
# floor under torchlight (fx.gd).

const Draw := preload("res://scripts/draw_util.gd")
const Palette := preload("res://scripts/palette.gd")
const _CORK := Color(0.6, 0.43, 0.27)
const _GLASS := Color(0.62, 0.66, 0.74)


## An item's icon, drawn in code, centred on `c` (about 2*s across).
## `alpha` fades it (empty slots, items fading on the floor).
static func draw_icon(ci: CanvasItem, id: String, c: Vector2, s: float, alpha := 1.0) -> void:
	var b := Draw.Batch.new()
	icon_into(b, id, c, s)
	if alpha < 0.999:
		for i in b.cols.size():
			b.cols[i].a *= alpha
	b.flush(ci)


static func icon_into(b, id: String, c: Vector2, s: float) -> void:
	var col := color(id)
	var u := s / 10.0
	var ol := clampf(u * 1.1, 0.8, 1.6)
	match id:
		"vessel":
			load("res://scripts/vessel.gd").belt_into(b, c, s)  # (filled as the belt's vessel is)
		"draught":
			# A round flask: glass, the liquid inside with its surface, a cork.
			_neck(b, c + Vector2(0, -6.2) * u, u, ol)
			var bc := c + Vector2(0, 2.6) * u
			var r := 6.6 * u
			b.dot(bc, r + ol + 0.8, Color(Palette.OUTLINE, Draw.FEATHER_ALPHA))
			b.dot(bc, r + ol, Palette.OUTLINE)
			b.dot(bc, r, _GLASS.darkened(0.55))
			var liquid := PackedVector2Array()
			var a0 := asin(-0.2)
			for i in 17:
				liquid.append(bc + Vector2.from_angle(lerpf(a0, PI - a0, i / 16.0)) * (r - 0.6 * u))
			b.polygon(liquid, col.darkened(0.2))
			var inner := PackedVector2Array()
			for i in 17:
				inner.append(bc + Vector2(-0.8, -0.4) * u + Vector2.from_angle(lerpf(a0 + 0.25, PI - a0 - 0.4, i / 16.0)) * (r - 2.2 * u))
			b.polygon(inner, col)
			b.line(liquid[0], liquid[16], col.lightened(0.45), maxf(0.8, 0.8 * u))  # the surface
			b.polygon(UIShape.oval(bc + Vector2(-2.9, -2.6) * u, Vector2(1.1, 2.2) * u, -0.6), Color(1, 1, 1, 0.6))
			b.dot(bc + Vector2(2.6, 3.2) * u, 0.8 * u, Color(1, 1, 1, 0.35))
		"tonic":
			# A squat square bottle with a green cure and a white cross label.
			_neck(b, c + Vector2(0, -6.4) * u, u, ol)
			var body := Rect2(c + Vector2(-5.6, -3.6) * u, Vector2(11.2, 12.6) * u)
			var pts := _round_rect(body, 2.2 * u)
			b.poly(pts, _GLASS.darkened(0.55), ol)
			b.polygon(_round_rect(Rect2(body.position + Vector2(0.7, 3.2) * u, body.size - Vector2(1.4, 3.9) * u), 1.6 * u), col.darkened(0.2))
			b.polygon(_round_rect(Rect2(body.position + Vector2(0.7, 3.2) * u, Vector2(body.size.x * 0.55, body.size.y - 3.9 * u)), 1.6 * u), col)
			b.line(body.position + Vector2(0.9, 3.2) * u, body.position + Vector2(body.size.x - 0.9 * u, 3.2 * u), col.lightened(0.45), maxf(0.8, 0.8 * u))
			var lc := body.get_center() + Vector2(0, 1.4) * u
			b.dot(lc, 3.0 * u, Color(0.95, 0.93, 0.85))
			b.rect(Rect2(lc - Vector2(0.6, 2.0) * u, Vector2(1.2, 4.0) * u), col.darkened(0.3))
			b.rect(Rect2(lc - Vector2(2.0, 0.6) * u, Vector2(4.0, 1.2) * u), col.darkened(0.3))
			b.rect(Rect2(body.position + Vector2(1.2, 1.0) * u, Vector2(1.2, 6.0) * u), Color(1, 1, 1, 0.5))
		"vial":
			# A tall vial with glowing essence and a spark in it.
			var r := Rect2(c + Vector2(-3.0, -5.8) * u, Vector2(6.0, 15.0) * u)
			b.rect(Rect2(c + Vector2(-4.0, -9.4) * u, Vector2(8.0, 3.6) * u).grow(ol), Palette.OUTLINE)
			var pts := _round_rect(r, 2.8 * u)
			b.poly(pts, _GLASS.darkened(0.55), ol)
			b.dot(c + Vector2(0, 3.6) * u, 6.0 * u, Color(col, 0.18))
			b.polygon(_round_rect(Rect2(r.position + Vector2(0.7, 5.0 * u), Vector2(r.size.x - 1.4 * u, r.size.y - 5.7 * u)), 2.2 * u), col.darkened(0.15))
			b.polygon(_round_rect(Rect2(r.position + Vector2(0.7, 5.0 * u), Vector2(r.size.x * 0.5, r.size.y - 5.7 * u)), 2.0 * u), col.lightened(0.15))
			b.line(r.position + Vector2(0.8 * u, 5.0 * u), Vector2(r.end.x - 0.8 * u, r.position.y + 5.0 * u), col.lightened(0.6), maxf(0.8, 0.8 * u))
			_spark(b, c + Vector2(0.3, 3.8) * u, 2.6 * u, Color(1, 1, 1, 0.9))
			b.rect(Rect2(r.position + Vector2(0.9, 0.9) * u, Vector2(1.0, 4.0) * u), Color(1, 1, 1, 0.45))
			b.rect(Rect2(c + Vector2(-4.0, -9.4) * u, Vector2(8.0, 3.6) * u), _CORK)
			b.rect(Rect2(c + Vector2(-4.0, -9.4) * u, Vector2(8.0, 1.2) * u), _CORK.lightened(0.25))
		"smoke":
			# A round bomb with a lit fuse.
			var bc := c + Vector2(-0.8, 1.6) * u
			b.stroke(bc + Vector2(3.0, -5.0) * u, c + Vector2(5.4, -7.6) * u, Color(0.78, 0.66, 0.46), 1.1 * u)
			b.rect(Rect2(bc + Vector2(1.0, -7.4) * u, Vector2(3.6, 2.6) * u).grow(ol), Palette.OUTLINE)
			b.rect(Rect2(bc + Vector2(1.0, -7.4) * u, Vector2(3.6, 2.6) * u), Color(0.45, 0.43, 0.48))
			b.ball(bc, 7.0 * u, col.darkened(0.42), true)
			b.dot(bc + Vector2(-2.8, -2.8) * u, 1.6 * u, Color(1, 1, 1, 0.5))
			_spark(b, c + Vector2(6.0, -8.2) * u, 3.0 * u, Color(1.0, 0.75, 0.3))
			_spark(b, c + Vector2(6.0, -8.2) * u, 1.5 * u, Color(1.0, 0.97, 0.8))
		"scroll":
			# A rolled parchment tied with a red cord, gold letters showing.
			var paper := Color(0.88, 0.8, 0.62)
			var body := Rect2(c + Vector2(-6.4, -5.2) * u, Vector2(12.8, 10.4) * u)
			b.rect(body.grow(ol), Palette.OUTLINE)
			b.rect(body, paper)
			b.rect(Rect2(body.position, Vector2(body.size.x, 1.6 * u)), paper.lightened(0.2))
			for k in 3:
				var y := body.position.y + (2.8 + k * 2.4) * u
				b.rect(Rect2(Vector2(body.position.x + 2.0 * u, y), Vector2((7.0 - k * 1.5) * u, 0.9 * u)), Color(col.darkened(0.25), 0.9))
			for sx in [-1.0, 1.0]:
				var rc: Vector2 = c + Vector2(sx * 7.2, 0) * u
				var roll := Rect2(rc + Vector2(-1.8, -6.6) * u, Vector2(3.6, 13.2) * u)
				b.rect(roll.grow(ol), Palette.OUTLINE)
				b.rect(roll, paper.darkened(0.12))
				b.rect(Rect2(roll.position, Vector2(1.1 * u, roll.size.y)), paper.lightened(0.15))
			b.rect(Rect2(c + Vector2(1.6, -5.6) * u, Vector2(1.6, 11.2) * u), Color(0.75, 0.2, 0.18))
			b.dot(c + Vector2(2.4, 5.8) * u, 1.6 * u, Color(0.75, 0.2, 0.18))
		"fire_flask":
			# A round flask of fire with a burning rag for a stopper.
			_round_flask(b, c, u, ol, col, false)
			var rag := c + Vector2(0, -7.4) * u
			b.rect(Rect2(rag + Vector2(-2.2, -1.4) * u, Vector2(4.4, 3.4) * u).grow(ol), Palette.OUTLINE)
			b.rect(Rect2(rag + Vector2(-2.2, -1.4) * u, Vector2(4.4, 3.4) * u), Color(0.86, 0.8, 0.66))
			_spark(b, rag + Vector2(0.6, -3.4) * u, 3.4 * u, Color(1.0, 0.6, 0.2))
			_spark(b, rag + Vector2(0.6, -3.4) * u, 1.7 * u, Color(1.0, 0.95, 0.75))
		"edge_oil":
			# A slim vial of red oil, a little blade beside it.
			_tall_vial(b, c + Vector2(-2.0, 0), u, ol, col)
			var t0 := c + Vector2(2.8, 8.0) * u
			var t1 := c + Vector2(8.6, -6.0) * u
			b.stroke(t0, t1, Palette.OUTLINE, 2.6 * u)
			b.stroke(t0, t1, Palette.STEEL, 1.4 * u)
			b.line(t0.lerp(t1, 0.2), t1, Color(1, 1, 1, 0.7), maxf(0.6, 0.4 * u))
		"warding_oil":
			# A squat bottle with a shield on its label.
			_square_bottle(b, c, u, ol, col)
			var lc := c + Vector2(0, 2.4) * u
			var shield := PackedVector2Array([lc + Vector2(-2.6, -2.6) * u, lc + Vector2(2.6, -2.6) * u, lc + Vector2(2.4, 0.6) * u, lc + Vector2(0, 3.0) * u, lc + Vector2(-2.4, 0.6) * u])
			b.poly(shield, Color(0.95, 0.93, 0.85), maxf(0.6, ol * 0.7))
			b.rect(Rect2(lc + Vector2(-0.5, -2.0) * u, Vector2(1.0, 4.2) * u), col.darkened(0.35))
		"haste":
			# A round flask of bright green with speed lines behind it.
			for k in 3:
				var y := (-1.0 + k * 3.0) * u
				b.rect(Rect2(c + Vector2(-10.0, y), Vector2((4.0 - k) * u, 0.9 * u)), Color(col, 0.75))
			_round_flask(b, c + Vector2(1.5, 0), u, ol, col, true)
		"stoneskin":
			# A squat bottle of grey-brown with a cut stone on its label.
			_square_bottle(b, c, u, ol, col)
			var gc := c + Vector2(0, 2.4) * u
			var gem := PackedVector2Array([gc + Vector2(0, -3.0) * u, gc + Vector2(2.8, -0.6) * u, gc + Vector2(1.6, 2.6) * u, gc + Vector2(-1.6, 2.6) * u, gc + Vector2(-2.8, -0.6) * u])
			b.poly(gem, col.darkened(0.25), maxf(0.6, ol * 0.7))
			b.polygon(PackedVector2Array([gem[0], gem[4], gc]), col.lightened(0.3))
		"salts":
			# A small round tin, open, heaped with white crystals.
			var tc := c + Vector2(0, 3.0) * u
			b.poly(UIShape.oval(tc, Vector2(8.0, 4.6) * u), Color(0.5, 0.52, 0.56), ol)
			b.polygon(UIShape.oval(tc + Vector2(0, -0.8) * u, Vector2(6.6, 3.4) * u), Color(0.3, 0.3, 0.34))
			for v in [Vector2(-3.0, -1.6), Vector2(0, -3.0), Vector2(2.8, -1.4), Vector2(-1.2, -0.2), Vector2(1.6, 0.2)]:
				b.ball(tc + v * u, 1.7 * u, col, true)
			_spark(b, c + Vector2(4.0, -6.0) * u, 2.4 * u, Color(1, 1, 1, 0.9))
		"flare":
			# A paper cartridge of powder, its twist end spitting sparks.
			var body := Rect2(c + Vector2(-3.4, -4.0) * u, Vector2(6.8, 13.0) * u)
			b.rect(body.grow(ol), Palette.OUTLINE)
			b.rect(body, Color(0.82, 0.3, 0.22))
			b.rect(Rect2(body.position, Vector2(2.0 * u, body.size.y)), Color(0.95, 0.5, 0.4))
			b.rect(Rect2(body.position + Vector2(0, 4.0 * u), Vector2(body.size.x, 2.4 * u)), Color(0.95, 0.88, 0.7))
			b.polygon(PackedVector2Array([body.position, body.position + Vector2(body.size.x, 0), c + Vector2(0, -7.0) * u]), Color(0.9, 0.84, 0.66))
			_spark(b, c + Vector2(0, -8.6) * u, 3.6 * u, col)
			_spark(b, c + Vector2(0, -8.6) * u, 1.8 * u, Color(1, 1, 0.9))
			b.dot(c + Vector2(4.6, -9.6) * u, 0.9 * u, col)
			b.dot(c + Vector2(-4.2, -10.4) * u, 0.8 * u, col)
		_:
			b.ball(c, s * 0.5, col, true)


## A round glass flask of `col` liquid (the draught's shape), with a cork
## unless `cork` is false (the Fire Flask's rag goes there instead).
static func _round_flask(b, c: Vector2, u: float, ol: float, col: Color, cork := true) -> void:
	if cork:
		_neck(b, c + Vector2(0, -6.2) * u, u, ol)
	else:
		var neck := Rect2(c + Vector2(-2.0, -7.8) * u, Vector2(4.0, 4.6) * u)
		b.rect(neck.grow(ol), Palette.OUTLINE)
		b.rect(neck, _GLASS.darkened(0.35))
	var bc := c + Vector2(0, 2.6) * u
	var r := 6.6 * u
	b.dot(bc, r + ol, Palette.OUTLINE)
	b.dot(bc, r, _GLASS.darkened(0.55))
	var liquid := PackedVector2Array()
	var a0 := asin(-0.2)
	for i in 17:
		liquid.append(bc + Vector2.from_angle(lerpf(a0, PI - a0, i / 16.0)) * (r - 0.6 * u))
	b.polygon(liquid, col.darkened(0.2))
	b.line(liquid[0], liquid[16], col.lightened(0.45), maxf(0.8, 0.8 * u))
	b.dot(bc + Vector2(-0.8, 1.6) * u, r * 0.55, col)
	b.polygon(UIShape.oval(bc + Vector2(-2.9, -2.6) * u, Vector2(1.1, 2.2) * u, -0.6), Color(1, 1, 1, 0.6))


## A squat square bottle of `col` (the tonic's shape) with a blank pale label.
static func _square_bottle(b, c: Vector2, u: float, ol: float, col: Color) -> void:
	_neck(b, c + Vector2(0, -6.4) * u, u, ol)
	var body := Rect2(c + Vector2(-5.6, -3.6) * u, Vector2(11.2, 12.6) * u)
	b.poly(_round_rect(body, 2.2 * u), _GLASS.darkened(0.55), ol)
	b.polygon(_round_rect(Rect2(body.position + Vector2(0.7, 3.2) * u, body.size - Vector2(1.4, 3.9) * u), 1.6 * u), col.darkened(0.2))
	b.polygon(_round_rect(Rect2(body.position + Vector2(0.7, 3.2) * u, Vector2(body.size.x * 0.55, body.size.y - 3.9 * u)), 1.6 * u), col)
	b.dot(body.get_center() + Vector2(0, 1.4) * u, 3.6 * u, Color(0.25, 0.22, 0.26, 0.55))
	b.rect(Rect2(body.position + Vector2(1.2, 1.0) * u, Vector2(1.2, 6.0) * u), Color(1, 1, 1, 0.5))


## A slim tall vial of `col` (the essence vial's shape, without its glow).
static func _tall_vial(b, c: Vector2, u: float, ol: float, col: Color) -> void:
	var r := Rect2(c + Vector2(-3.0, -5.8) * u, Vector2(6.0, 15.0) * u)
	b.rect(Rect2(c + Vector2(-4.0, -9.4) * u, Vector2(8.0, 3.6) * u).grow(ol), Palette.OUTLINE)
	b.poly(_round_rect(r, 2.8 * u), _GLASS.darkened(0.55), ol)
	b.polygon(_round_rect(Rect2(r.position + Vector2(0.7, 4.0 * u), Vector2(r.size.x - 1.4 * u, r.size.y - 4.7 * u)), 2.2 * u), col.darkened(0.15))
	b.polygon(_round_rect(Rect2(r.position + Vector2(0.7, 4.0 * u), Vector2(r.size.x * 0.5, r.size.y - 4.7 * u)), 2.0 * u), col.lightened(0.15))
	b.rect(Rect2(r.position + Vector2(0.9, 0.9) * u, Vector2(1.0, 4.0) * u), Color(1, 1, 1, 0.45))
	b.rect(Rect2(c + Vector2(-4.0, -9.4) * u, Vector2(8.0, 3.6) * u), _CORK)
	b.rect(Rect2(c + Vector2(-4.0, -9.4) * u, Vector2(8.0, 1.2) * u), _CORK.lightened(0.25))


## An essence crystal's icon in the essence's colour, centred on `c` (about
## 2*s across): a tall faceted shard with a glow and a spark.
static func draw_crystal_icon(ci: CanvasItem, col: Color, c: Vector2, s: float, alpha := 1.0) -> void:
	var b := Draw.Batch.new()
	crystal_into(b, col, c, s)
	if alpha < 0.999:
		for i in b.cols.size():
			b.cols[i].a *= alpha
	b.flush(ci)


static func crystal_into(b, col: Color, c: Vector2, s: float) -> void:
	var u := s / 10.0
	var ol := clampf(u * 1.1, 0.8, 1.6)
	for i in 4:
		b.dot(c, (9.0 - i * 1.6) * u, Color(col, 0.07))
	var top := c + Vector2(0, -9.5) * u
	var bot := c + Vector2(0, 9.0) * u
	var l := c + Vector2(-5.2, -1.5) * u
	var r := c + Vector2(5.2, -1.5) * u
	var ml := c + Vector2(-4.0, 4.0) * u
	var mr := c + Vector2(4.0, 4.0) * u
	var outline := PackedVector2Array([top, r, mr, bot, ml, l])
	b.poly(outline, col.darkened(0.35), ol)
	b.polygon(PackedVector2Array([top, l, ml, c + Vector2(-0.6, 1.0) * u]), col.lightened(0.25))
	b.polygon(PackedVector2Array([top, c + Vector2(-0.6, 1.0) * u, c + Vector2(0.8, 0.5) * u, r]), col)
	b.polygon(PackedVector2Array([c + Vector2(0.8, 0.5) * u, r, mr, bot]), col.darkened(0.15))
	b.polygon(PackedVector2Array([c + Vector2(-0.6, 1.0) * u, ml, bot, c + Vector2(0.8, 0.5) * u]), col.darkened(0.05))
	b.line(top, c + Vector2(-0.6, 1.0) * u, col.lightened(0.55), maxf(0.7, 0.6 * u))
	_spark(b, c + Vector2(-2.0, -3.6) * u, 2.4 * u, Color(1, 1, 1, 0.85))


## A flask's neck and cork, with its bottom at `at`.
static func _neck(b, at: Vector2, u: float, ol: float) -> void:
	var neck := Rect2(at + Vector2(-2.0, -1.6) * u, Vector2(4.0, 4.6) * u)
	var cork := Rect2(at + Vector2(-2.6, -4.6) * u, Vector2(5.2, 3.2) * u)
	b.rect(neck.grow(ol), Palette.OUTLINE)
	b.rect(cork.grow(ol), Palette.OUTLINE)
	b.rect(neck, _GLASS.darkened(0.35))
	b.rect(Rect2(neck.position, Vector2(1.2 * u, neck.size.y)), Color(1, 1, 1, 0.4))
	b.rect(cork, _CORK)
	b.rect(Rect2(cork.position, Vector2(cork.size.x, 1.1 * u)), _CORK.lightened(0.25))


## A four-pointed sparkle.
static func _spark(b, c: Vector2, r: float, col: Color) -> void:
	b.polygon(PackedVector2Array([c + Vector2(0, -r), c + Vector2(r * 0.25, -r * 0.25), c + Vector2(r, 0), c + Vector2(r * 0.25, r * 0.25),
		c + Vector2(0, r), c + Vector2(-r * 0.25, r * 0.25), c + Vector2(-r, 0), c + Vector2(-r * 0.25, -r * 0.25)]), col)


static func _round_rect(r: Rect2, rad: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	rad = minf(rad, minf(r.size.x, r.size.y) * 0.5)
	var cs := [Vector2(r.end.x - rad, r.position.y + rad), Vector2(r.end.x - rad, r.end.y - rad),
		Vector2(r.position.x + rad, r.end.y - rad), Vector2(r.position.x + rad, r.position.y + rad)]
	for k in 4:
		for i in 4:
			pts.append(cs[k] + Vector2.from_angle(-PI / 2.0 + (k + i / 3.0) * PI / 2.0) * rad)
	return pts


## A rune card's mark: a carved stone with a glowing three-stroke sigil.
static func draw_rune_icon(ci: CanvasItem, col: Color, c: Vector2, s: float) -> void:
	var b := Draw.Batch.new()
	var u := s / 10.0
	var stone := PackedVector2Array()
	for i in 7:
		var a := -PI / 2.0 + TAU * i / 7.0
		stone.append(c + Vector2.from_angle(a) * (8.6 + (0.8 if i % 2 == 0 else -0.4)) * u)
	b.poly(stone, Color(0.3, 0.28, 0.34), clampf(u * 1.1, 0.8, 1.6))
	var lit := PackedVector2Array()
	for p in stone:
		lit.append(c + (p - c) * 0.82 + Draw.LIGHT_DIR * 0.9 * u)
	b.polygon(lit, Color(0.4, 0.38, 0.45))
	for i in 5:
		b.dot(c, (7.0 - i) * u, Color(col, 0.08))
	for i in 3:
		var a := -PI / 2.0 + TAU * i / 3.0
		var p0 := c + Vector2.from_angle(a) * 1.4 * u
		var p1 := c + Vector2.from_angle(a + 2.2) * 5.8 * u
		b.line(p0, p1, Color(col.darkened(0.5), 0.9), 2.2 * u)
		b.line(p0, p1, col.lightened(0.2), 1.2 * u)
	b.dot(c, 1.4 * u, col.lightened(0.5))
	b.flush(ci)


class UIShape:
	## An oval's points, turned by `rot`.
	static func oval(c: Vector2, rad: Vector2, rot := 0.0, n := 12) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in n:
			var a := TAU * i / n
			pts.append(c + Vector2(cos(a) * rad.x, sin(a) * rad.y).rotated(rot))
		return pts
