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
# Icons follow icon_art.gd's style (slim shapes, smooth shading lit from the
# top-left, a light violet ink outline, shared materials). They use only
# filled shapes, so they also work lying on the floor under torchlight
# (fx.gd), and each is built once per size and copied after that.

const Draw := preload("res://scripts/draw_util.gd")
const Art := preload("res://scripts/icon_art.gd")


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
	if id == "vessel":
		load("res://scripts/vessel.gd").belt_into(b, c, s)  # (filled as the belt's vessel is)
		return
	s = Art.size_step(s)
	Art.cached(b, "item|%s|%.2f" % [id, s], c, func(nb): _item_art(nb, id, s))


## An item's icon around (0, 0): the art itself.
static func _item_art(b, id: String, s: float) -> void:
	var col := color(id)
	var c := Vector2.ZERO
	var u := Art.unit(s)
	var lod := Art.detail(s)
	match id:
		"draught":
			# A round flask: the red cure two-thirds up, a cork.
			var bc := Vector2(0, 3.0) * u
			var r := 6.4 * u
			Art.glass(b, _flask(bc, r, Rect2(Vector2(-1.7, -6.0) * u, Vector2(3.4, 3.4) * u)), s, col, bc.y - r * 0.2)
			_cork(b, Rect2(Vector2(-2.3, -9.0) * u, Vector2(4.6, 3.2) * u), s)
			Art.shine(b, bc + Vector2(-3.0, -2.3) * u, 0.9 * u, 2.0 * u)
			if lod > 0:
				b.circle(bc + Vector2(2.3, 3.4) * u, 0.6 * u, Color(1, 1, 1, 0.35), 10)
		"tonic":
			# A square bottle of green cure with a white cross on its label.
			var body := Art.rrect(Rect2(Vector2(-5.2, -3.0) * u, Vector2(10.4, 12.2) * u), 2.4 * u)
			body = _with_neck(body, Rect2(Vector2(-1.7, -6.2) * u, Vector2(3.4, 3.6) * u))
			Art.glass(b, body, s, col, -0.2 * u)
			_cork(b, Rect2(Vector2(-2.3, -9.2) * u, Vector2(4.6, 3.2) * u), s)
			var lc := Vector2(0, 3.6) * u
			Art.shape(b, Art.oval(lc, Vector2(3.0, 3.0) * u), Art.PAPER, s, "", Art.THIN | Art.NO_RIM)
			var k := col.darkened(0.3)
			b.rect(Rect2(lc - Vector2(0.65, 2.0) * u, Vector2(1.3, 4.0) * u), k)
			b.rect(Rect2(lc - Vector2(2.0, 0.65) * u, Vector2(4.0, 1.3) * u), k)
			Art.shine(b, Vector2(-3.4, -0.2) * u, 0.6 * u, 2.4 * u, 0.0, 0.5)
		"vial":
			# A tall vial of glowing essence with a spark in it.
			var body := Art.rrect(Rect2(Vector2(-2.8, -5.6) * u, Vector2(5.6, 14.8) * u), 2.8 * u)
			Art.soft(b, Vector2(0, 3.0) * u, 8.5 * u, Color(col, 0.4))
			Art.glass(b, body, s, col, -1.2 * u, 1.0)
			_cork(b, Rect2(Vector2(-3.4, -9.2) * u, Vector2(6.8, 3.8) * u), s)
			Art.spark(b, Vector2(0.2, 3.6) * u, 2.6 * u, Color(1, 1, 1, 0.9))
			Art.shine(b, Vector2(-1.5, -2.6) * u, 0.5 * u, 2.2 * u, 0.0, 0.5)
		"smoke":
			# A round iron bomb with a lit fuse.
			var bc := Vector2(-0.8, 2.0) * u
			Art.rod(b, bc + Vector2(3.4, -6.8) * u, Vector2(5.4, -7.0) * u, 0.9 * u, Color(0.84, 0.72, 0.52), s, "cloth")
			var cap := Art.rrect(Rect2(bc + Vector2(-1.4, -8.4) * u, Vector2(2.8, 2.4) * u), 0.6 * u, 3)
			var rot := Transform2D(0.7, bc)
			cap = rot * (Transform2D(0.0, -bc) * cap)
			Art.shape(b, cap, Art.IRON, s, "metal", Art.NO_RIM)
			Art.orb(b, bc, 6.6 * u, Color(0.42, 0.42, 0.54), s, "metal")
			_flame(b, Vector2(6.0, -7.8) * u, 2.8 * u, s, true)
		"fire_flask":
			# A round flask of fire, a burning rag for a stopper.
			var bc := Vector2(0, 3.0) * u
			var r := 6.4 * u
			Art.glass(b, _flask(bc, r, Rect2(Vector2(-1.7, -5.8) * u, Vector2(3.4, 3.4) * u)), s, col, bc.y - r * 0.35, 0.7)
			var rag := Art.smooth(Art.pts(c, u, [Vector2(-3.2, -8.0), Vector2(-0.6, -9.4), Vector2(2.8, -8.4), Vector2(2.4, -5.6), Vector2(4.6, -3.6),
				Vector2(2.6, -3.8), Vector2(0.6, -5.2), Vector2(-2.6, -5.4)]), 3)
			Art.shape(b, rag, Color(0.88, 0.82, 0.66), s, "cloth", Art.NO_RIM)
			_flame(b, Vector2(-0.2, -11.0) * u, 3.0 * u, s, false)
			Art.shine(b, bc + Vector2(-3.0, -2.3) * u, 0.9 * u, 2.0 * u)
		"edge_oil":
			# A slim vial of red oil, a little blade beside it.
			var body := Art.rrect(Rect2(Vector2(-5.4, -4.6) * u, Vector2(4.8, 13.8) * u), 2.4 * u)
			Art.glass(b, body, s, col, -0.4 * u)
			_cork(b, Rect2(Vector2(-5.8, -8.2) * u, Vector2(5.6, 3.6) * u), s)
			Art.shine(b, Vector2(-4.0, -1.4) * u, 0.45 * u, 2.2 * u, 0.0, 0.5)
			var t0 := Vector2(2.8, 8.4) * u
			var t1 := Vector2(8.4, -7.8) * u
			var dir := (t1 - t0).normalized()
			var side := Art.lit_side(t0, t1)
			Art.shape(b, PackedVector2Array([t0 + side * 1.1 * u, t1, t0 - side * 1.1 * u]), Art.STEEL, s, "metal")
			Art.rod(b, t0 - dir * 0.3 * u, t0 - dir * 2.4 * u, 1.5 * u, Art.LEATHER, s, "leather")
		"warding_oil":
			# A pear-shaped oil bottle with a shield on its label.
			var body := PackedVector2Array()
			for i in 25:
				var a := lerpf(-PI * 0.3, PI * 1.3, i / 24.0)
				body.append(Vector2(0, 3.6) * u + Vector2(cos(a) * 6.0, sin(a) * 5.4) * u)
			body = _with_neck(body, Rect2(Vector2(-1.6, -6.4) * u, Vector2(3.2, 6.0) * u))
			Art.glass(b, body, s, col, 0.6 * u)
			_cork(b, Rect2(Vector2(-2.2, -9.4) * u, Vector2(4.4, 3.2) * u), s)
			var lc := Vector2(0, 4.0) * u
			var shield := Art.pts(lc, u, [Vector2(-2.6, -2.6), Vector2(2.6, -2.6), Vector2(2.4, 0.6), Vector2(0, 3.0), Vector2(-2.4, 0.6)])
			Art.shape(b, shield, Art.PAPER, s, "", Art.THIN | Art.NO_RIM)
			b.polygon(Art.pts(lc, u, [Vector2(0, -2.0), Vector2(1.8, -2.0), Vector2(1.7, 0.5), Vector2(0, 2.2)]), col.darkened(0.3))
			Art.shine(b, Vector2(-3.6, 1.8) * u, 0.6 * u, 1.7 * u)
		"haste":
			# A conical flask of bright green with speed lines behind it.
			for k in 3:
				var y := (0.4 + k * 3.0) * u
				var x0 := (-10.2 + k * 0.8) * u
				b.line(Vector2(x0, y), Vector2(x0 + (4.2 - k * 1.0) * u, y), Color(col, 0.85 - k * 0.15), maxf(0.9, 0.8 * u))
			var body := Art.pts(c, u, [Vector2(0.1, -6.4), Vector2(3.1, -6.4), Vector2(3.1, -2.2), Vector2(8.2, 7.2), Vector2(7.4, 9.0),
				Vector2(-4.2, 9.0), Vector2(-5.0, 7.2), Vector2(0.1, -2.2)])
			Art.glass(b, body, s, col, 2.6 * u)
			_cork(b, Rect2(Vector2(-0.6, -9.4) * u, Vector2(4.4, 3.2) * u), s)
			Art.shine(b, Vector2(-0.6, 3.0) * u, 0.5 * u, 2.2 * u, 0.5, 0.5)
		"stoneskin":
			# A six-sided bottle of earthy draught, a stone stopper and a cut stone on it.
			var body := PackedVector2Array()
			for i in 6:
				body.append(Vector2(0, 3.0) * u + Vector2.from_angle(PI / 6.0 + TAU * i / 6.0) * Vector2(6.4, 6.2) * u)
			body = _with_neck(body, Rect2(Vector2(-1.7, -6.0) * u, Vector2(3.4, 3.6) * u))
			Art.glass(b, body, s, col, 0.8 * u)
			Art.shape(b, Art.pts(c, u, [Vector2(-2.6, -6.0), Vector2(-1.9, -9.4), Vector2(1.9, -9.4), Vector2(2.6, -6.0)]), Color(0.6, 0.58, 0.66), s)
			var gc := Vector2(0, 4.2) * u
			var gem := Art.pts(gc, u, [Vector2(0, -2.6), Vector2(2.4, -0.6), Vector2(1.4, 2.2), Vector2(-1.4, 2.2), Vector2(-2.4, -0.6)])
			Art.shape(b, gem, col.lightened(0.15), s, "gem", Art.THIN | Art.NO_RIM)
			b.polygon(PackedVector2Array([gem[0], gem[4], gc]), Color(1, 1, 1, 0.4))
			Art.shine(b, Vector2(-3.4, 1.2) * u, 0.5 * u, 1.9 * u, 0.0, 0.45)
		"salts":
			# A small open tin heaped with white crystals.
			var tc := Vector2(0, 3.4) * u
			var tin := PackedVector2Array([tc + Vector2(-7.6, -1.4) * u])
			for i in 17:
				tin.append(tc + Vector2(-cos(PI * i / 16.0) * 7.6, 1.4 + sin(PI * i / 16.0) * 3.4) * u)
			tin.append(tc + Vector2(7.6, -1.4) * u)
			Art.shape(b, tin, Color(0.6, 0.62, 0.72), s, "metal")
			var mouth := Art.oval(tc + Vector2(0, -1.4) * u, Vector2(7.6, 2.8) * u)
			Art.shape(b, mouth, Art.GOLD, s, "gold", Art.THIN | Art.NO_RIM)
			b.polygon(Art.oval(tc + Vector2(0, -1.4) * u, Vector2(6.4, 2.0) * u), Color(0.15, 0.13, 0.2))
			for v in [Vector2(-3.8, -2.0), Vector2(3.4, -1.8), Vector2(-1.5, -4.3), Vector2(1.7, -4.1), Vector2(0.1, -1.8), Vector2(0.0, -6.4)]:
				_chunk(b, tc + v * u, 2.0 * u, col, s)
			Art.spark(b, Vector2(4.8, -5.6) * u, 2.4 * u, Color(1, 1, 1, 0.9))
		"flare":
			# A paper cartridge of powder, its twist end spitting sparks.
			var body := Rect2(Vector2(-3.2, -3.0) * u, Vector2(6.4, 12.0) * u)
			Art.shape(b, Art.rrect(body, 1.0 * u, 3), Color(0.88, 0.32, 0.26), s, "cloth")
			var band := Rect2(body.position + Vector2(0, 4.0 * u), Vector2(body.size.x, 2.4 * u))
			b.rect(band, Color(0.96, 0.89, 0.72))
			b.rect(Rect2(band.position + Vector2(0, band.size.y - 0.6 * u), Vector2(band.size.x, 0.6 * u)), Color(0.78, 0.62, 0.46))
			var twist := Art.pts(c, u, [Vector2(-3.2, -3.0), Vector2(3.2, -3.0), Vector2(0.9, -5.4), Vector2(1.4, -7.0), Vector2(-1.3, -7.0), Vector2(-0.9, -5.4)])
			Art.shape(b, twist, Color(0.93, 0.86, 0.68), s, "cloth", Art.NO_RIM)
			_flame(b, Vector2(0, -9.6) * u, 3.0 * u, s, true)
			b.circle(Vector2(4.4, -9.2) * u, 0.8 * u, col, 10)
			b.circle(Vector2(-4.0, -10.2) * u, 0.7 * u, col, 10)
			if lod > 0:
				b.circle(Vector2(3.0, -11.8) * u, 0.55 * u, Color(1, 1, 0.85), 10)
		"scroll":
			# A rolled parchment tied with a red cord and sealed, gold letters showing.
			var body := Rect2(Vector2(-5.6, -4.6) * u, Vector2(11.2, 9.2) * u)
			Art.shape(b, Art.rrect(body, 0.4 * u, 2), Art.PAPER, s, "cloth")
			var lines := 3 if lod > 0 else 2
			for k in lines:
				var y := body.position.y + (2.2 + k * (5.6 / lines)) * u
				b.rect(Rect2(Vector2(body.position.x + 1.6 * u, y), Vector2((6.0 - k * 1.5) * u, maxf(0.7, 0.8 * u))), Color(Art.GOLD.darkened(0.3), 0.95))
			for sx in [-1.0, 1.0]:
				var x: float = sx * 6.6 * u
				Art.rod(b, Vector2(x, -5.8 * u), Vector2(x, 5.8 * u), 3.0 * u, Art.PAPER.darkened(0.04), s, "cloth")
				b.circle(Vector2(x, -6.0 * u), 0.8 * u, Art.PAPER.darkened(0.45), 10)
			var cord := Color(0.82, 0.22, 0.2)
			b.rect(Rect2(Vector2(1.7, -4.6) * u, Vector2(1.3, 9.2) * u), cord)
			Art.orb(b, Vector2(2.35, 4.8) * u, 1.7 * u, cord, s, "gem")
		_:
			Art.orb(b, c, s * 0.5, col, s)


## A round flask's outside: a ball of radius `r` at `bc` with a neck.
static func _flask(bc: Vector2, r: float, neck: Rect2) -> PackedVector2Array:
	return _with_neck(Art.oval(bc, Vector2(r, r), 0.0, 32), neck)


## A bottle's outside joined with its neck (the neck reaches down into it).
static func _with_neck(body: PackedVector2Array, neck: Rect2) -> PackedVector2Array:
	var n := PackedVector2Array([neck.position, Vector2(neck.end.x, neck.position.y), neck.end + Vector2(0, neck.size.y), Vector2(neck.position.x, neck.end.y + neck.size.y)])
	var best := body
	var most := 0.0
	for m in Geometry2D.merge_polygons(body, n):
		var a := absf(_area(m))
		if a > most:
			most = a
			best = m
	return best


static func _area(p: PackedVector2Array) -> float:
	var a := 0.0
	for i in p.size():
		a += p[i].cross(p[(i + 1) % p.size()])
	return a * 0.5


## A cork in `r`: soft wood, lit on its top.
static func _cork(b, r: Rect2, s: float) -> void:
	Art.shape(b, Art.rrect(r, r.size.y * 0.3, 4), Art.CORK, s, "wood")
	if Art.detail(s) > 0:
		b.circle(r.get_center() + Vector2(r.size.x * 0.2, r.size.y * 0.1), maxf(0.45, r.size.y * 0.09), Color(Art.CORK.darkened(0.4), 0.6), 10)


## A small flame at `c`, `r` tall: orange round a pale heart. `spark` lights
## it as a fuse's spitting spark instead.
static func _flame(b, c: Vector2, r: float, s: float, spark: bool) -> void:
	if spark:
		Art.soft(b, c, r * 1.6, Color(1.0, 0.6, 0.2, 0.45))
		Art.spark(b, c, r, Color(1.0, 0.68, 0.26))
		Art.spark(b, c, r * 0.55, Color(1.0, 0.97, 0.82))
		return
	var unit := [Vector2(0, -1.0), Vector2(0.3, -0.45), Vector2(0.52, 0.05), Vector2(0.4, 0.5), Vector2(0, 0.66),
		Vector2(-0.4, 0.5), Vector2(-0.52, 0.05), Vector2(-0.18, -0.3)]
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for v in unit:
		outer.append(c + v * r * 1.4)
		inner.append(c + Vector2(0, r * 0.32) + v * r * 0.72)
	outer = Art.smooth(outer, 3)
	inner = Art.smooth(inner, 3)
	Art.soft(b, c + Vector2(0, r * 0.3), r * 1.8, Color(1.0, 0.55, 0.2, 0.4))
	Art.outline(b, outer, s, Art.ol(s) * 0.7)
	Art.grad(b, outer, Color(1.0, 0.72, 0.3), Color(1.0, 0.5, 0.17), Color(0.9, 0.3, 0.12))
	b.polygon(inner, Color(1.0, 0.92, 0.6))


## A crystal chunk (salts): a little faceted lump.
static func _chunk(b, c: Vector2, r: float, col: Color, s: float) -> void:
	var p := Art.pts(c, r / 10.0, [Vector2(-9, 2), Vector2(-5, -8), Vector2(5, -9), Vector2(10, 0), Vector2(5, 8), Vector2(-6, 8)])
	Art.shape(b, p, col, s, "gem", Art.THIN | Art.NO_RIM)
	b.polygon(PackedVector2Array([p[0], p[1], p[2], c]), Color(1, 1, 1, 0.7))


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
	s = Art.size_step(s)
	Art.cached(b, "crystal|%s|%.2f" % [col.to_html(), s], c, func(nb): _crystal_art(nb, col, s))


static func _crystal_art(b, col: Color, s: float) -> void:
	var u := Art.unit(s)
	Art.soft(b, Vector2.ZERO, 10.5 * u, Color(col, 0.32))
	var top := Vector2(0, -9.4) * u
	var bot := Vector2(0, 9.2) * u
	var l := Vector2(-4.8, -1.6) * u
	var r := Vector2(4.8, -1.6) * u
	var ml := Vector2(-3.8, 4.0) * u
	var mr := Vector2(3.8, 4.0) * u
	var mid := Vector2(-0.6, 1.0) * u
	var mid2 := Vector2(0.8, 0.5) * u
	var rr := Art.ramp(col, "gem")
	Art.outline(b, PackedVector2Array([top, r, mr, bot, ml, l]), s)
	Art.grad(b, PackedVector2Array([top, l, ml, mid]), col.lightened(0.35), rr[3], col)
	Art.grad(b, PackedVector2Array([top, mid, mid2, r]), rr[3], col, col.darkened(0.1))
	Art.grad(b, PackedVector2Array([mid2, r, mr, bot]), col, rr[1], rr[0])
	Art.grad(b, PackedVector2Array([mid, ml, bot, mid2]), col, col.darkened(0.12), rr[1])
	b.line(top, mid, Color(col.lightened(0.6), 0.85), maxf(0.6, 0.5 * u))
	b.line(top + Vector2(-0.3, 0.6) * u, l + Vector2(0.5, 0) * u, Color(1, 1, 1, 0.5), maxf(0.5, 0.4 * u))
	Art.spark(b, Vector2(-1.9, -3.6) * u, 2.3 * u, Color(1, 1, 1, 0.88))


## A rune card's mark: a carved stone with a glowing three-stroke sigil.
static func draw_rune_icon(ci: CanvasItem, col: Color, c: Vector2, s: float) -> void:
	var b := Draw.Batch.new()
	s = Art.size_step(s)
	Art.cached(b, "camprune|%s|%.2f" % [col.to_html(), s], c, func(nb): _rune_art(nb, col, s))
	b.flush(ci)


static func _rune_art(b, col: Color, s: float) -> void:
	var u := Art.unit(s)
	var stone := PackedVector2Array()
	for i in 7:
		var a := -PI / 2.0 + TAU * i / 7.0
		stone.append(Vector2.from_angle(a) * (8.6 + (0.8 if i % 2 == 0 else -0.4)) * u)
	Art.shape(b, Art.smooth(stone, 3), Color(0.42, 0.39, 0.5), s)
	Art.soft(b, Vector2.ZERO, 7.5 * u, Color(col, 0.45))
	for i in 3:
		var a := -PI / 2.0 + TAU * i / 3.0
		var p0 := Vector2.from_angle(a) * 1.4 * u
		var p1 := Vector2.from_angle(a + 2.2) * 5.6 * u
		b.line(p0, p1, Color(Art.INK, 0.8), 2.0 * u)
		b.line(p0, p1, col.lightened(0.25), 1.0 * u)
	b.circle(Vector2.ZERO, 1.3 * u, col.lightened(0.5), 12)
