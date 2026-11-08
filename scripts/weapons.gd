extends RefCounted
## Weapon definitions. Each weapon is plain data; player.gd reads it, and
## gear.gd knows how weapons are found, carried and compared. Names and text
## live here so they're easy to change. Every weapon here is plain, common
## gear; enchanted weapons can be added later as more entries (an
## "enchant" field read in player.gd is the natural place to start).
##
## Weapon fields:
##   name, short  the full name, and a short one for the HUD's slots
##   desc         a line about what it's like
##   kind         "melee", "bow" (hold to draw) or "crossbow" (fire, then reload)
##   slot         where it's carried: "fists" (always), "melee" or "ranged"
##   class        "light", "medium" or "heavy": how it handles (Weapon Memory
##                and the like read this instead of the weapon's id)
##   style        how it's drawn and swung: jab, stab, arc, thrust
##   swing_time   how long the swing's trail shows
##   sound, pitch the swing's sound (and pitch); hit_sound: what a hit sounds like
##   equip        the sound when you switch to it
##   rocks        every hit counts as heavy against poise (maces and hammers)
##   backstab     extra backstab multiplier on top of the usual 1.5x (daggers)
##
## Swing fields (melee combo chains):
##   dmg      multiplier on the base strike damage (8)
##   range    reach in pixels, arc: half-angle in degrees
##   sta      stamina cost, recover: seconds before you can act again
##   lunge    forward step speed, knock: knockback given to the target
##   heavy    a finisher: bigger hit-pause, heavier sound, breaks poise
##   side     which way the swing sweeps (arcs) or which fist punches (fists)
##   stagger  seconds a hit staggers the foe (war hammer)

## The base strike damage every swing's "dmg" multiplies (player.gd STRIKE_DAMAGE).
const BASE := 8.0

## Every weapon, in the order the dev tools and lists show them.
const ORDER := ["fists", "dagger", "sword", "axe", "mace", "spear", "greatsword", "war_hammer", "shortbow", "longbow", "crossbow"]

## What a new climb starts with in the melee and ranged slots.
const START_MELEE := "sword"
const START_RANGED := "shortbow"

## Weapon Memory (Blade Forger): conjured blades take after the weapon in
## your hand. Melee weapons by class; bows and crossbows all fly as darts.
const MEMORY := {
	"light": {"extra": 2, "speed": 640.0, "mult": 0.7, "life": 1.2},
	"medium": {"extra": 0, "speed": 560.0, "mult": 1.0, "life": 1.5},
	"heavy": {"extra": -1, "speed": 480.0, "mult": 1.5, "life": 1.6},
	"ranged": {"extra": 0, "speed": 840.0, "mult": 1.3, "life": 2.0},
}

const WEAPONS := {
	"fists": {
		"name": "Fists",
		"short": "Fists",
		"desc": "quick, short jabs on a cheap four-hit chain ending in a heavy hook",
		"kind": "melee",
		"slot": "fists",
		"class": "light",
		"style": "jab",
		"swing_time": 0.1,
		"sound": "punch",
		"hit_sound": "hit_light",
		"equip": "equip_fists",
		"combo": [
			{"dmg": 0.55, "range": 30.0, "arc": 40.0, "sta": 8.0, "recover": 0.2, "lunge": 140.0, "knock": 70.0, "heavy": false, "side": 1.0},
			{"dmg": 0.6, "range": 30.0, "arc": 40.0, "sta": 8.0, "recover": 0.22, "lunge": 140.0, "knock": 80.0, "heavy": false, "side": -1.0},
			{"dmg": 0.6, "range": 30.0, "arc": 40.0, "sta": 8.0, "recover": 0.22, "lunge": 140.0, "knock": 80.0, "heavy": false, "side": 1.0},
			{"dmg": 1.3, "range": 36.0, "arc": 55.0, "sta": 18.0, "recover": 0.48, "lunge": 260.0, "knock": 240.0, "heavy": true, "side": -1.0},
		],
	},
	"dagger": {
		"name": "Dagger",
		"short": "Dagger",
		"desc": "fast, short and cheap on stamina; backstabs bite deeper",
		"kind": "melee",
		"slot": "melee",
		"class": "light",
		"style": "stab",
		"swing_time": 0.1,
		"sound": "swing_light",
		"pitch": 1.0,
		"hit_sound": "hit_stab",
		"equip": "equip_dagger",
		"backstab": 0.5,
		"combo": [
			{"dmg": 0.7, "range": 36.0, "arc": 35.0, "sta": 9.0, "recover": 0.24, "lunge": 170.0, "knock": 70.0, "heavy": false, "side": 1.0},
			{"dmg": 0.7, "range": 36.0, "arc": 35.0, "sta": 9.0, "recover": 0.24, "lunge": 170.0, "knock": 70.0, "heavy": false, "side": -1.0},
			{"dmg": 0.8, "range": 36.0, "arc": 35.0, "sta": 9.0, "recover": 0.26, "lunge": 170.0, "knock": 80.0, "heavy": false, "side": 1.0},
			{"dmg": 1.4, "range": 40.0, "arc": 40.0, "sta": 16.0, "recover": 0.5, "lunge": 280.0, "knock": 200.0, "heavy": true, "side": -1.0},
		],
	},
	"sword": {
		"name": "Sword",
		"short": "Sword",
		"desc": "the all-rounder: a three-hit chain ending in a slow, heavy finisher",
		"kind": "melee",
		"slot": "melee",
		"class": "medium",
		"style": "arc",
		"length": 24.0,
		"swing_time": 0.15,
		"sound": "swing",
		"hit_sound": "hit",
		"equip": "equip_sword",
		"combo": [
			{"dmg": 1.0, "range": 46.0, "arc": 55.0, "sta": 16.0, "recover": 0.4, "lunge": 190.0, "knock": 150.0, "heavy": false, "side": 1.0},
			{"dmg": 1.1, "range": 46.0, "arc": 55.0, "sta": 16.0, "recover": 0.42, "lunge": 190.0, "knock": 160.0, "heavy": false, "side": -1.0},
			{"dmg": 1.8, "range": 56.0, "arc": 75.0, "sta": 26.0, "recover": 0.66, "lunge": 300.0, "knock": 300.0, "heavy": true, "side": 1.0},
		],
	},
	"axe": {
		"name": "Axe",
		"short": "Axe",
		"desc": "slower and harder than a sword, with a wide, hacking arc",
		"kind": "melee",
		"slot": "melee",
		"class": "medium",
		"style": "arc",
		"length": 24.0,
		"swing_time": 0.17,
		"sound": "swing",
		"pitch": 0.85,
		"hit_sound": "hit",
		"equip": "equip_heavy",
		"combo": [
			{"dmg": 1.3, "range": 48.0, "arc": 70.0, "sta": 20.0, "recover": 0.52, "lunge": 180.0, "knock": 180.0, "heavy": false, "side": 1.0},
			{"dmg": 1.4, "range": 48.0, "arc": 70.0, "sta": 20.0, "recover": 0.54, "lunge": 180.0, "knock": 190.0, "heavy": false, "side": -1.0},
			{"dmg": 2.2, "range": 56.0, "arc": 90.0, "sta": 30.0, "recover": 0.8, "lunge": 280.0, "knock": 340.0, "heavy": true, "side": 1.0},
		],
	},
	"mace": {
		"name": "Mace",
		"short": "Mace",
		"desc": "heavy blows that rock monsters: every hit breaks poise",
		"kind": "melee",
		"slot": "melee",
		"class": "medium",
		"style": "arc",
		"length": 22.0,
		"swing_time": 0.17,
		"sound": "swing_blunt",
		"pitch": 1.0,
		"hit_sound": "hit_blunt",
		"equip": "equip_blunt",
		"rocks": true,
		"combo": [
			{"dmg": 1.15, "range": 44.0, "arc": 50.0, "sta": 20.0, "recover": 0.5, "lunge": 170.0, "knock": 200.0, "heavy": false, "side": 1.0},
			{"dmg": 1.25, "range": 44.0, "arc": 50.0, "sta": 20.0, "recover": 0.52, "lunge": 170.0, "knock": 210.0, "heavy": false, "side": -1.0},
			{"dmg": 2.0, "range": 50.0, "arc": 65.0, "sta": 30.0, "recover": 0.78, "lunge": 260.0, "knock": 360.0, "heavy": true, "side": 1.0},
		],
	},
	"spear": {
		"name": "Spear",
		"short": "Spear",
		"desc": "long, narrow thrusts: strike from beyond a monster's reach",
		"kind": "melee",
		"slot": "melee",
		"class": "medium",
		"style": "thrust",
		"length": 48.0,
		"swing_time": 0.14,
		"sound": "thrust",
		"pitch": 1.0,
		"hit_sound": "hit",
		"equip": "equip_sword",
		"combo": [
			{"dmg": 0.95, "range": 74.0, "arc": 16.0, "sta": 15.0, "recover": 0.42, "lunge": 200.0, "knock": 150.0, "heavy": false, "side": 1.0},
			{"dmg": 1.0, "range": 74.0, "arc": 16.0, "sta": 15.0, "recover": 0.42, "lunge": 200.0, "knock": 160.0, "heavy": false, "side": -1.0},
			{"dmg": 1.6, "range": 86.0, "arc": 22.0, "sta": 24.0, "recover": 0.66, "lunge": 320.0, "knock": 280.0, "heavy": true, "side": 1.0},
		],
	},
	"greatsword": {
		"name": "Greatsword",
		"short": "Great",
		"desc": "two-handed: slow, big sweeping arcs that catch a crowd, and hungry for stamina",
		"kind": "melee",
		"slot": "melee",
		"class": "heavy",
		"style": "arc",
		"length": 38.0,
		"swing_time": 0.22,
		"sound": "swing_heavy",
		"pitch": 1.1,
		"hit_sound": "hit_heavy",
		"equip": "equip_heavy",
		"combo": [
			{"dmg": 1.6, "range": 60.0, "arc": 95.0, "sta": 28.0, "recover": 0.7, "lunge": 160.0, "knock": 240.0, "heavy": false, "side": 1.0},
			{"dmg": 1.7, "range": 60.0, "arc": 95.0, "sta": 28.0, "recover": 0.72, "lunge": 160.0, "knock": 250.0, "heavy": false, "side": -1.0},
			{"dmg": 2.6, "range": 66.0, "arc": 120.0, "sta": 38.0, "recover": 1.0, "lunge": 260.0, "knock": 420.0, "heavy": true, "side": 1.0},
		],
	},
	"war_hammer": {
		"name": "War Hammer",
		"short": "Hammer",
		"desc": "the slowest and heaviest: every blow rocks, and the finisher staggers",
		"kind": "melee",
		"slot": "melee",
		"class": "heavy",
		"style": "arc",
		"length": 32.0,
		"swing_time": 0.22,
		"sound": "swing_blunt_heavy",
		"pitch": 0.95,
		"hit_sound": "hit_blunt",
		"equip": "equip_blunt",
		"rocks": true,
		"combo": [
			{"dmg": 2.0, "range": 52.0, "arc": 55.0, "sta": 32.0, "recover": 0.9, "lunge": 150.0, "knock": 300.0, "heavy": false, "side": 1.0},
			{"dmg": 3.0, "range": 56.0, "arc": 70.0, "sta": 42.0, "recover": 1.2, "lunge": 240.0, "knock": 460.0, "heavy": true, "side": -1.0, "stagger": 0.6},
		],
	},
	"shortbow": {
		"name": "Shortbow",
		"short": "Short",
		"desc": "hold to draw, release to loose; a full draw pierces through foes",
		"kind": "bow",
		"slot": "ranged",
		"class": "light",
		"equip": "equip_bow",
		# Hold to draw; release to loose. A full draw pierces through foes.
		"draw_time": 0.75,
		"min_draw": 0.12,  # a quick tap still fires a weak shot after this
		"dmg_min": 5.0,
		"dmg_max": 20.0,
		"speed_min": 380.0,
		"speed_max": 760.0,
		"knock_min": 50.0,
		"knock_max": 220.0,
		"sta": 14.0,
		"recover": 0.3,
		"move_mult": 0.45,  # you walk slowly while drawing
		"life": 1.6,  # how long an arrow flies (its range is speed x life)
		"limb": 14.0,  # how long the drawn bow's limbs are
	},
	"longbow": {
		"name": "Longbow",
		"short": "Long",
		"desc": "a slower draw for harder, farther arrows; you barely walk while drawing",
		"kind": "bow",
		"slot": "ranged",
		"class": "heavy",
		"equip": "equip_bow",
		"draw_time": 1.1,
		"min_draw": 0.18,
		"dmg_min": 6.0,
		"dmg_max": 30.0,
		"speed_min": 420.0,
		"speed_max": 940.0,
		"knock_min": 60.0,
		"knock_max": 280.0,
		"sta": 18.0,
		"recover": 0.4,
		"move_mult": 0.28,
		"life": 1.9,
		"limb": 20.0,
	},
	"crossbow": {
		"name": "Crossbow",
		"short": "X-bow",
		"desc": "press to fire a fast, strong bolt; then a reload you can't skip (you can walk)",
		"kind": "crossbow",
		"slot": "ranged",
		"class": "medium",
		"equip": "equip_crossbow",
		"dmg": 24.0,
		"speed": 980.0,
		"knock": 260.0,
		"pierce": false,
		"heavy": true,  # a bolt rocks what it hits
		"sta": 12.0,
		"recover": 0.25,
		"reload": 1.1,
		"reload_move": 0.8,  # walking speed while reloading
		"life": 1.4,
	},
}


static func info(id: String) -> Dictionary:
	return WEAPONS.get(id, {})


static func is_weapon(id: String) -> bool:
	return WEAPONS.has(id)


## True for weapons that shoot (bows and crossbows).
static func is_ranged(id: String) -> bool:
	return WEAPONS.has(id) and WEAPONS[id]["kind"] != "melee"


## Weapon Memory: how conjured blades take after this weapon.
static func memory(id: String) -> Dictionary:
	var w := info(id)
	if w.is_empty():
		return MEMORY["medium"]
	if w["kind"] != "melee":
		return MEMORY["ranged"]
	return MEMORY.get(w["class"], MEMORY["medium"])


## Key numbers for comparing weapons: [label, shown text, value, higher is better].
static func stats(id: String) -> Array:
	var w := info(id)
	if w.is_empty():
		return []
	match String(w["kind"]):
		"melee":
			var chain: Array = w["combo"]
			var lo := 999.0
			var hi := 0.0
			var total := 0.0
			var sta := 0.0
			var rec := 0.0
			var reach := 0.0
			for s in chain:
				var d: float = BASE * float(s["dmg"])
				lo = minf(lo, d)
				hi = maxf(hi, d)
				total += d
				sta += float(s["sta"])
				rec += float(s["recover"])
				reach = maxf(reach, float(s["range"]))
			var avg := total / chain.size()
			return [
				["Damage", "%d-%d" % [int(round(lo)), int(round(hi))], avg, true],
				["Reach", "%d" % int(reach), reach, true],
				["Stamina", "%d a chain" % int(sta), sta / chain.size(), false],
				["Speed", "%.2f s" % (rec / chain.size()), rec / chain.size(), false],
			]
		"bow":
			var rng: float = float(w["speed_max"]) * float(w["life"])
			return [
				["Damage", "%d-%d" % [int(w["dmg_min"]), int(w["dmg_max"])], float(w["dmg_max"]), true],
				["Range", "%d" % int(rng), rng, true],
				["Stamina", "%d a shot" % int(w["sta"]), float(w["sta"]), false],
				["Draw", "%.2f s" % float(w["draw_time"]), float(w["draw_time"]), false],
			]
		"crossbow":
			var rng2: float = float(w["speed"]) * float(w["life"])
			return [
				["Damage", "%d" % int(w["dmg"]), float(w["dmg"]), true],
				["Range", "%d" % int(rng2), rng2, true],
				["Stamina", "%d a shot" % int(w["sta"]), float(w["sta"]), false],
				["Reload", "%.1f s" % float(w["reload"]), float(w["reload"]), false],
			]
	return []
