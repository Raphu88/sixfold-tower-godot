extends RefCounted
## Items and camps: what the climber can carry, how often monsters drop
## them, and what a camp offers. Names and text live here so they're easy
## to change. The effects are in `use()` at the bottom.

## Each kind of item stacks up to this many.
const MAX_STACK := 3
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

const ORDER := ["draught", "tonic", "vial", "smoke"]

const ITEMS := {
	"draught": {
		"name": "Healing Draught",
		"short": "Draught",
		"desc": "heals 40 health over a second and a half",
		"color": Color(0.9, 0.3, 0.32),
		"heal": 40.0,
		"time": 1.5,
		"drop_weight": 5,
	},
	"tonic": {
		"name": "Cleansing Tonic",
		"short": "Tonic",
		"desc": "cures poison, heals every burned body part and a little health",
		"color": Color(0.45, 0.85, 0.5),
		"heal": 10.0,
		"time": 0.5,
		"drop_weight": 2,
	},
	"vial": {
		"name": "Essence Vial",
		"short": "Vial",
		"desc": "fills every mark with essence",
		"color": Color(0.55, 0.75, 1.0),
		"drop_weight": 2,
		"needs_mark": true,
	},
	"smoke": {
		"name": "Smoke Bomb",
		"short": "Smoke",
		"desc": "a cloud of smoke around you: monsters inside lose track of you (beasts don't)",
		"color": Color(0.68, 0.66, 0.7),
		"radius": 95.0,
		"duration": 5.0,
		"drop_weight": 1,
	},
}

# --- camps ---------------------------------------------------------------------

## On climbs of at least CAMP_MIN_FLOORS, taking this floor's stair leads to
## a camp first: a safe room with a fire, a full rest and an item to take.
const CAMP_AFTER := 3
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
## essence vial would do nothing, so `marked` false leaves those out.
static func random_item(marked := true, exclude: Array = []) -> String:
	var total := 0
	for id in ORDER:
		if id in exclude or (not marked and ITEMS[id].get("needs_mark", false)):
			continue
		total += int(ITEMS[id]["drop_weight"])
	if total <= 0:
		return "draught"
	var roll := randi() % total
	for id in ORDER:
		if id in exclude or (not marked and ITEMS[id].get("needs_mark", false)):
			continue
		roll -= int(ITEMS[id]["drop_weight"])
		if roll < 0:
			return id
	return "draught"


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
			main.smokes.append({"pos": p.global_position, "r": float(data["radius"]), "t": float(data["duration"])})
			main.fx_burst(p.global_position, Vector2.ZERO, col, 18, 160.0)
	main.fx_ring(p.global_position, col, 34.0, 0.3, 3.0)
	main.sfx("ready", 1.0, -3.0)
	return true


## Healing items heal over a short time. Steady Hands heals more, faster.
static func _heal_over_time(p, data: Dictionary, steady: bool) -> void:
	var amount: float = float(data["heal"]) * (STEADY_HEAL if steady else 1.0)
	var t: float = float(data["time"]) * (STEADY_TIME if steady else 1.0)
	p.heal_left += amount
	p.heal_rate = maxf(p.heal_rate if p.heal_left > amount else 0.0, amount / t)
	p.main.fx_text(p.global_position + Vector2(0, -44), "+%d" % int(round(amount)), Color(0.6, 1.0, 0.7))


# --- drawing -----------------------------------------------------------------------

## An item's icon, drawn in code, centred on `c` (about 2*s across).
static func draw_icon(ci: CanvasItem, id: String, c: Vector2, s: float, alpha := 1.0) -> void:
	var col := Color(color(id), alpha)
	var dark := Color(0.04, 0.03, 0.05, 0.9 * alpha)
	var glass := Color(0.85, 0.85, 0.9, 0.8 * alpha)
	match id:
		"draught", "tonic":
			# A round flask with a neck and cork.
			var body := c + Vector2(0, s * 0.25)
			ci.draw_circle(body, s * 0.62, dark)
			ci.draw_circle(body, s * 0.55, col)
			ci.draw_circle(body + Vector2(-s * 0.2, -s * 0.2), s * 0.14, Color(1, 1, 1, 0.5 * alpha))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.16, -s * 0.75), Vector2(s * 0.32, s * 0.5)), glass)
			ci.draw_rect(Rect2(c + Vector2(-s * 0.2, -s * 0.92), Vector2(s * 0.4, s * 0.2)), Color(0.6, 0.45, 0.3, alpha))
			if id == "tonic":
				ci.draw_line(body + Vector2(-s * 0.25, 0), body + Vector2(s * 0.25, 0), Color(1, 1, 1, 0.7 * alpha), maxf(1.0, s * 0.1))
				ci.draw_line(body + Vector2(0, -s * 0.25), body + Vector2(0, s * 0.25), Color(1, 1, 1, 0.7 * alpha), maxf(1.0, s * 0.1))
		"vial":
			# A tall thin vial with a glowing core.
			var r := Rect2(c + Vector2(-s * 0.28, -s * 0.6), Vector2(s * 0.56, s * 1.4))
			ci.draw_rect(r.grow(s * 0.08), dark)
			ci.draw_rect(r, glass)
			ci.draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.35), Vector2(r.size.x, r.size.y * 0.65)), col)
			ci.draw_circle(c + Vector2(0, s * 0.35), s * 0.18, Color(1, 1, 1, 0.75 * alpha))
			ci.draw_rect(Rect2(c + Vector2(-s * 0.34, -s * 0.85), Vector2(s * 0.68, s * 0.22)), Color(0.6, 0.45, 0.3, alpha))
		"smoke":
			# A round bomb with a lit fuse.
			ci.draw_circle(c + Vector2(0, s * 0.15), s * 0.68, dark)
			ci.draw_circle(c + Vector2(0, s * 0.15), s * 0.6, col.darkened(0.35))
			ci.draw_circle(c + Vector2(-s * 0.2, -s * 0.05), s * 0.15, Color(1, 1, 1, 0.35 * alpha))
			ci.draw_line(c + Vector2(s * 0.25, -s * 0.4), c + Vector2(s * 0.5, -s * 0.8), Color(0.75, 0.6, 0.4, alpha), maxf(1.0, s * 0.12))
			ci.draw_circle(c + Vector2(s * 0.52, -s * 0.85), s * 0.14, Color(1.0, 0.7, 0.3, alpha))
		_:
			ci.draw_circle(c, s * 0.5, col)


## A rune card's mark: a small glowing sigil.
static func draw_rune_icon(ci: CanvasItem, col: Color, c: Vector2, s: float) -> void:
	ci.draw_arc(c, s * 0.7, 0.0, TAU, 28, col, maxf(1.5, s * 0.1))
	for i in 3:
		var a := -PI / 2.0 + TAU * i / 3.0
		ci.draw_line(c + Vector2.from_angle(a) * s * 0.15, c + Vector2.from_angle(a + 2.2) * s * 0.6, col, maxf(1.5, s * 0.1))
	ci.draw_circle(c, s * 0.12, col)
