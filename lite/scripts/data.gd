extends RefCounted
## Six Towers LITE's data: towers, monsters, magic and every number, in one
## place so they're easy to change. Nothing here needs reading in the game:
## the names are only for the people who change it. The words the game does
## show are in TEXT: short and simple, to help a child learning to read.
##
## Based on the full Sixfold Tower (its towers, bonds and essence), much simpler:
## - Six towers, each with its beast and its essence (colour).
## - A climb is six floors, the beast at the top. The first climb starts with
##   no magic: on floor 3 the tower's beast takes notice and marks your body
##   (the Regard). Each mark is one magic power; beating a beast gives its
##   mark too (or grows it).
## - Monsters leave sparkles of essence. You carry them up and, at each stair,
##   they pour into your marks (a mark's own colour counts most). Marks grow
##   from 1 to 3 stars across climbs.

## Each essence's colour (the full game's essence.gd).
static var ESSENCE := {
	"air": Color(0.78, 0.9, 1.0),
	"water": Color(0.37, 0.72, 0.85),
	"iron": Color(0.8, 0.82, 0.88),
	"fire": Color(1.0, 0.55, 0.25),
	"stone": Color(0.82, 0.68, 0.45),
	"blade": Color(0.88, 0.36, 0.4),
}

## The towers, in the order they sit on the home screen.
const ORDER := ["gryphon", "kraken", "wyvern", "manticore", "firebird", "chimera"]

## Each tower: its essence, its stone colour (floor), its two monsters and
## where the beast's mark goes on the body.
static var TOWERS := {
	"gryphon": {"name": "Gryphon", "essence": "air", "floor": Color(0.36, 0.42, 0.58), "monsters": ["harrier", "archer"], "part": "legs"},
	"kraken": {"name": "Kraken", "essence": "water", "floor": Color(0.25, 0.43, 0.5), "monsters": ["slime", "deepfin"], "part": "heart"},
	"wyvern": {"name": "Wyvern", "essence": "iron", "floor": Color(0.5, 0.33, 0.3), "monsters": ["knight", "cinder"], "part": "back"},
	"manticore": {"name": "Manticore", "essence": "stone", "floor": Color(0.58, 0.47, 0.32), "monsters": ["ram", "scorpling"], "part": "throat"},
	"firebird": {"name": "Firebird", "essence": "fire", "floor": Color(0.55, 0.36, 0.32), "monsters": ["ashwing", "wisp"], "part": "brow"},
	"chimera": {"name": "Chimera", "essence": "blade", "floor": Color(0.3, 0.45, 0.3), "monsters": ["thornhound", "briar"], "part": "hand"},
}

## The six body parts, as on the full game's climber.
const PARTS := ["hand", "legs", "heart", "brow", "throat", "back"]

## Monsters. "walker" walks up, flashes, then lunges; "shooter" keeps away and
## throws slow orbs. "look" picks the drawing (art.gd); "color" (if
## given) is its own colour, else it takes its tower's. Sounds are the
## full game's: hurt_<id>, kill_<id>.
static var MONSTERS := {
	"harrier": {"kind": "walker", "look": "winged", "hp": 2, "speed": 85.0},
	"archer": {"kind": "shooter", "look": "hooded", "hp": 2, "speed": 60.0},
	"slime": {"kind": "walker", "look": "blob", "hp": 3, "speed": 60.0},
	"deepfin": {"kind": "shooter", "look": "finned", "hp": 2, "speed": 60.0},
	"knight": {"kind": "walker", "look": "armored", "hp": 4, "speed": 55.0},
	"cinder": {"kind": "shooter", "look": "flame", "hp": 2, "speed": 65.0, "color": Color(1.0, 0.55, 0.25)},
	"ram": {"kind": "walker", "look": "armored", "hp": 3, "speed": 75.0},
	"scorpling": {"kind": "shooter", "look": "spiky", "hp": 2, "speed": 60.0},
	"ashwing": {"kind": "walker", "look": "winged", "hp": 2, "speed": 85.0},
	"wisp": {"kind": "shooter", "look": "flame", "hp": 2, "speed": 70.0},
	"thornhound": {"kind": "walker", "look": "spiky", "hp": 3, "speed": 75.0},
	"briar": {"kind": "shooter", "look": "hooded", "hp": 3, "speed": 45.0},
}

## Each floor of a climb: how many monsters. The floor after these (the
## sixth) is the beast's.
const FLOORS := [3, 4, 4, 5, 5]
## On the first climb (no mark yet), the beast's Regard comes after this floor.
const REGARD_FLOOR := 3
const BEAST_HP := 26
const BEAST_SPEED := 70.0
## The beast calls this many of its monsters when it drops to half health.
const BEAST_HELPERS := 2

## The climber.
const HEARTS := 5
const SPEED := 230.0
const HURT_SAFE := 1.4  # seconds you can't be hurt again after a hit
const FALL_WAIT := 2.0  # seconds before you pop back after losing every heart
## The sword: auto-aims at the nearest monster in reach.
const SWING_REACH := 105.0
const SWING_ARC := 2.6  # radians (wide)
const SWING_TIME := 0.28
const SWING_DAMAGE := 1
const HEART_DROP := 0.25  # chance a monster leaves a heart

## Monsters: how long they flash before a lunge or a throw (long, to be fair).
const WINDUP := 0.85
const ORB_SPEED := 150.0

## Sparkles of essence each monster leaves (the beast leaves many).
const SPARKS := 3
const BEAST_SPARKS := 20
## At a stair, a mark takes all of its own colour and this much of the others
## (shared between your marks).
const OTHER_SHARE := 0.4
## Essence a mark needs for 2 stars and for 3 stars.
const STAR_AT := [0, 60, 180]
## Beating a beast whose mark you already have grows that mark by this much.
const BEAST_GROWTH := 30

## The magic: one for each essence, each based on a bond of the full game
## (its bonds.gd). "word" is the easy name the game shows on the magic button;
## "recharge" in seconds; the numbers grow with the mark's stars.
static var MAGIC := {
	"air": {"word": "Zap", "name": "Chain Lightning", "bond": "Stormcaller", "sound": "spell_lightning", "recharge": 5.0, "damage": [2, 3, 4], "targets": [3, 4, 6]},
	"water": {"word": "Wave", "name": "Tidal Surge", "bond": "Tidecaller", "sound": "spell_water", "recharge": 5.0, "damage": [2, 3, 4], "radius": [170.0, 210.0, 260.0]},
	"iron": {"word": "Shield", "name": "Barrier", "bond": "Warden", "sound": "spell_iron", "recharge": 8.0, "time": [4.0, 5.5, 7.0]},
	"stone": {"word": "Stomp", "name": "Quake", "bond": "Sandshaper", "sound": "spell_stone", "recharge": 6.0, "damage": [2, 3, 4], "radius": [190.0, 230.0, 280.0], "stun": [2.0, 2.5, 3.0]},
	"fire": {"word": "Fire", "name": "Fireball", "bond": "Flamewing", "sound": "spell_fire", "recharge": 4.0, "damage": [4, 6, 8], "radius": [90.0, 110.0, 140.0]},
	"blade": {"word": "Blades", "name": "Conjured Blades", "bond": "Blade Forger", "sound": "spell_blade", "recharge": 7.0, "damage": [1, 1, 2], "blades": [3, 4, 6], "time": [4.0, 5.0, 6.0]},
}


## The words on screen: short and simple, for a child learning to read. %s
## is a beast's name (TOWERS "name") or a floor's number.
static var TEXT := {
	"pick": "Pick a tower!",
	"hooray": "Hooray!",
	"floor": "Floor %s",
	"beast": "The %s!",
	"go_up": "Go up!",
	"oops": "Oops! Try again!",
	"grows": "Your magic grows!",
	"sees_you": "The %s sees you!",
	"you_beat": "You beat the %s!",
	"new_mark": "You got a mark!",
	"hit": "Hit",
	"home": "Home",
	"play": "Play",
	"ok": "OK",
}
## Read the words aloud as they show (on devices with a voice), so a child
## hears each word while seeing it.
const SPEAK := true


static func color(essence: String) -> Color:
	return ESSENCE.get(essence, Color.WHITE)


static func tower_color(tower: String) -> Color:
	return color(TOWERS[tower]["essence"])


## A monster's colour: its own if it has one ("color"), else its tower's.
static func monster_color(id: String, tower: String) -> Color:
	return MONSTERS.get(id, {}).get("color", tower_color(tower).darkened(0.05))


## Stars (1 to 3) for essence grown into a mark.
static func stars(grown: float) -> int:
	var s := 1
	for i in STAR_AT.size():
		if grown >= float(STAR_AT[i]):
			s = i + 1
	return s


## How far a mark is toward its next star (0 to 1; 1 at 3 stars).
static func star_progress(grown: float) -> float:
	var s := stars(grown)
	if s >= STAR_AT.size():
		return 1.0
	var lo := float(STAR_AT[s - 1])
	var hi := float(STAR_AT[s])
	return clampf((grown - lo) / (hi - lo), 0.0, 1.0)


## A magic's number at a mark's stars (the list's last if it's short).
static func magic_value(essence: String, key: String, star: int):
	var list: Array = MAGIC[essence][key]
	return list[clampi(star - 1, 0, list.size() - 1)]
