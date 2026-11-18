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
## sixth) is the beast's. Each floor's room is a layout (floor_map.gd).
const FLOORS := [4, 5, 6, 7, 8]
## The chance a layout's cracked wall (its secret way to a treasure room) is there.
const SECRET_CHANCE := 0.6
## From this floor (0 = floor 1) one monster of each room is an elite: bigger,
## much tougher, and it leaves more sparkles.
const ELITE_FROM := 3
static var ELITE := {"scale": 1.35, "hp": 2.5, "sparks": 3.0}
## From this floor (0 = floor 1) throwers throw three at once, in a fan.
const SPREAD_FROM := 2
## On the first climb (no mark yet), the beast's Regard comes after this floor.
const REGARD_FLOOR := 3
## A beast's health: BEAST_HP, plus BEAST_HP_STEP for each tower before
## its own (they unlock in order, so later beasts are tougher).
const BEAST_HP := 60
const BEAST_HP_STEP := 14
## At half health a beast gets fiercer: faster, quicker to strike, bigger
## rings of throws, and it calls its monsters.
static var BEAST_FURY := {"speed": 1.3, "windup": 0.75, "ring": 16}
## Its leap: it jumps to where you stood (the spot is marked) and lands hard.
const SLAM_RADIUS := 110.0
## Which of each beast's full-game attack poses (creatures.gd "alt") goes
## with LITE's two beast attacks: the charge and the ring of throws.
static var BEAST_ALTS := {
	"gryphon": {"charge": 0, "ring": 1}, "kraken": {"charge": 1, "ring": 2}, "wyvern": {"charge": 1, "ring": 2},
	"manticore": {"charge": 0, "ring": 2}, "firebird": {"charge": 1, "ring": 0}, "chimera": {"charge": 1, "ring": 3},
}
const BEAST_SPEED := 70.0
## The beast calls this many of its monsters when it drops to half health.
const BEAST_HELPERS := 3

## The climber.
const HEARTS := 5
const SPEED := 230.0
const HURT_SAFE := 1.4  # seconds you can't be hurt again after a hit
const FALL_WAIT := 2.6  # seconds before the climb ends after losing every heart
## Hearts carry from floor to floor; each stair gives back this many.
const HEARTS_AT_STAIR := 2
## How long a swing's trail shows (seconds).
const SWING_TIME := 0.28

## The weapons, swapped with the weapon button (or picked on the climber
## screen), after the full game's (its weapons.gd: their sounds too). Every
## swing aims at the nearest monster by itself. "reach" in px, "arc" in
## radians, "cooldown" seconds between swings, "push" how far a hit knocks a
## monster back, "stun" seconds a hit stuns it. The bow shoots arrows instead.
const WEAPON_ORDER := ["sword", "dagger", "hammer", "bow"]
static var WEAPONS := {
	"sword": {"word": "Sword", "reach": 105.0, "arc": 2.6, "damage": 1, "cooldown": 0.34, "push": 260.0, "stun": 0.0,
		"sound": "swing", "hit_sound": "hit", "equip": "equip_sword"},
	"dagger": {"word": "Dagger", "reach": 82.0, "arc": 1.7, "damage": 1, "cooldown": 0.18, "push": 120.0, "stun": 0.0,
		"sound": "swing_light", "hit_sound": "hit_stab", "equip": "equip_dagger"},
	"hammer": {"word": "Hammer", "reach": 118.0, "arc": 2.9, "damage": 2, "cooldown": 0.75, "push": 460.0, "stun": 0.7,
		"sound": "swing_blunt_heavy", "hit_sound": "hit_blunt", "equip": "equip_blunt"},
	"bow": {"word": "Bow", "ranged": true, "damage": 1, "cooldown": 0.42, "arrow_speed": 720.0, "push": 140.0, "stun": 0.0,
		"sound": "bow", "hit_sound": "arrow_hit", "equip": "equip_bow"},
}

## Roll: a quick dodge you can't be hurt in (the full game's roll, kinder).
const ROLL_TIME := 0.32
const ROLL_SPEED := 560.0
const ROLL_COOLDOWN := 0.45  # after a roll ends, before the next
## Parry: for a moment after the press, a hit is blocked instead. A blocked
## lunge stuns the monster; a blocked throw flies back and hurts them. The
## window is much wider than the full game's (0.32 s) so a child can time it.
const PARRY_WINDOW := 0.5
const PARRY_COOLDOWN := 0.6  # (a block resets it)
const PARRY_STUN := 1.4  # a beast is stunned half as long
const REFLECT_DAMAGE := 2

## Monsters grow harder as you climb: each floor above the first adds this
## share to their health and speed and takes it off their wind-up and rest.
## (Floor 5's monsters: twice the health, a third faster, a quarter quicker
## to strike; never under MIN_WINDUP of warning.)
static var HARDER := {"hp": 0.25, "speed": 0.08, "windup": 0.06, "rest": 0.07, "orb": 0.06}
const MIN_WINDUP := 0.5
const HEART_DROP := 0.12  # chance a monster leaves a heart

## Monsters: how long they flash before a lunge or a throw (long, to be fair).
const WINDUP := 0.85
const ORB_SPEED := 150.0

## Sparkles of essence each monster leaves (the beast leaves many).
const SPARKS := 3
const BEAST_SPARKS := 20
## At a stair, a mark takes all of its own colour and this much of the others
## (shared between your marks).
const OTHER_SHARE := 0.4
## Essence a mark needs for each star (up to STAR_MAX). Each new star brings
## an upgrade to pick (UPGRADES).
const STAR_AT := [0, 90, 240, 480, 800]
const STAR_MAX := 5
## Play style: what each body part does fills it with essence. At each stair
## BODY_SHARE of what's banked goes to the body, split by what each part did
## on that floor (a marked part grows its mark; an empty one soaks it up, and
## the next mark goes on the fullest). Hits with a weapon count for that
## weapon's part, and the favourite weapon (the one used most) counts
## FAVOURITE_BONUS more.
static var DEED_PART := {
	"hit_sword": "hand", "hit_dagger": "back", "hit_hammer": "throat", "hit_bow": "brow",
	"roll": "legs", "parry": "brow", "hurt": "heart", "magic": "heart",
}
const BODY_SHARE := 0.4
const FAVOURITE_BONUS := 0.5

## Mark upgrades: at each new star (2 to 5) pick one of two. "power", "quick"
## and "big" work for every magic; each magic has two specials of its own.
## A pick can come twice ("power" at star 2 and 4): they add up.
static func upgrade_choices(essence: String, star: int) -> Array:
	match star:
		2, 4:
			return ["power", "quick"]
		3:
			return ["big", essence + "_a"]
		_:
			return ["big", essence + "_b"]


## Each upgrade's word (shown and read aloud) and its badge picture.
static var UPGRADE_INFO := {
	"power": {"word": "Stronger!", "badge": "power"},
	"quick": {"word": "Faster!", "badge": "quick"},
	"big": {"word": "Bigger!", "badge": "big"},
	"air_a": {"word": "Zap stuns!", "badge": "special"},
	"air_b": {"word": "Double zap!", "badge": "special"},
	"water_a": {"word": "Wave heals!", "badge": "special"},
	"water_b": {"word": "Freezing wave!", "badge": "special"},
	"iron_a": {"word": "Bounce back!", "badge": "special"},
	"iron_b": {"word": "Spiky shield!", "badge": "special"},
	"stone_a": {"word": "Safe stomp!", "badge": "special"},
	"stone_b": {"word": "Double stomp!", "badge": "special"},
	"fire_a": {"word": "Burning fire!", "badge": "special"},
	"fire_b": {"word": "Triple fire!", "badge": "special"},
	"blade_a": {"word": "Flying blades!", "badge": "special"},
	"blade_b": {"word": "Long blades!", "badge": "special"},
}

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
	"roll": "Roll",
	"parry": "Parry",
	"swap": "Swap",
	"magic": "Magic",
	"marks": "Marks",
	"weapons": "Weapons",
	"look": "Look",
	"climber": "You",
	"back": "Back",
	"home": "Home",
	"play": "Play",
	"ok": "OK",
	"hint_move": "Move with your thumb!",
	"hint_attack": "Tap the sword to hit!",
	"hint_roll": "Roll away!",
	"hint_parry": "Parry to block!",
	"hint_swap": "Tap to swap your weapon!",
	"hint_magic": "Use your magic!",
	"hint_gems": "Pick your magic!",
	"hint_plates": "Step on all the stones!",
	"hint_lever": "Hit the lever!",
	"hint_fires": "Light all the fires!",
	"open": "The door is open!",
	"portal": "A portal!",
	"secret": "A secret!",
	"treasure": "You found a treasure!",
	"lost": "Oh no! Back home.",
	"careful": "Careful! One heart left!",
	"locked": "Beat the %s first!",
	"pick_one": "Pick one!",
	"favorite": "Favorite",
	"next_mark": "Next mark",
	"treasure_tab": "Treasure",
}
## The body parts' words on the climber screen (simple ones for a child).
static var PART_WORDS := {"hand": "Hand", "legs": "Legs", "heart": "Heart", "brow": "Head", "throat": "Neck", "back": "Back"}
## The climber screen's Look tab: a word for each group of choices (look.gd
## TABS) and each choice (look.gd option keys).
static var LOOK_GROUP_WORDS := {"face": "Face", "hair": "Hair", "body": "Body", "cloak": "Cloak", "extras": "More"}
static var LOOK_WORDS := {
	"skin": "Skin", "eyes": "Eyes", "eye_shape": "Eye shape", "face": "Face",
	"hair": "Hair", "hair_color": "Hair color", "beard": "Beard",
	"build": "Body", "tunic": "Shirt", "trousers": "Pants", "boots": "Boots",
	"cloak": "Cloak", "cloak_style": "Cloak shape", "trim": "Trim", "pattern": "Pattern", "hood": "Hood",
	"belt": "Belt", "neck": "Neck", "accessory": "Extra",
}
## Read the words aloud as they show (on devices with a voice), so a child
## hears each word while seeing it.
const SPEAK := true


## Every phrase the game can say aloud (tools/make_voice.py records each one
## with a natural voice into assets/voice: voice.gd). Add new spoken words to
## TEXT (or the lists below) and they're picked up here.
static func spoken() -> Array:
	var out := {}
	for k in TEXT:
		var line: String = TEXT[k]
		if line.contains("%s"):
			if k == "floor":
				for n in FLOORS.size() + 1:
					out[line % str(n + 1)] = true
			else:
				for tw in ORDER:
					out[line % String(TOWERS[tw]["name"])] = true
		else:
			out[line] = true
	for tw in ORDER:
		out[String(TOWERS[tw]["name"])] = true
	for id in WEAPONS:
		out[String(WEAPONS[id]["word"])] = true
	for e in MAGIC:
		out[String(MAGIC[e]["word"])] = true
		out[String(MAGIC[e]["word"]) + "!"] = true
	for d in [PART_WORDS, LOOK_GROUP_WORDS, LOOK_WORDS]:
		for k in d:
			out[String(d[k])] = true
	for k in UPGRADE_INFO:
		out[String(UPGRADE_INFO[k]["word"])] = true
	for k in TREASURES:
		out[String(TREASURES[k]["word"])] = true
	return out.keys()


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


## Treasures to find: things to wear, drawn like the full game's gear
## (gear_look.gd pieces) and weapon finishes (gear_look.gd SKINS). Each beast
## leaves its own the first time it's beaten; the rest are in the chests of
## secret treasure rooms.
## id -> {"word": its name on screen, "kind": "gear" or "skin", "piece": a
## gear_look.gd id or a skin, "from": "secret" (treasure rooms), "beast:<tower>"
## (that beast's, the first time it's beaten) or "chest"}.
static var TREASURES := {
	"leather_cap": {"word": "Cap", "kind": "gear", "piece": "leather_cap", "slot": "head", "from": "secret"},
	"feathered_cap": {"word": "Feather Hat", "kind": "gear", "piece": "feathered_cap", "slot": "head", "from": "secret"},
	"iron_helm": {"word": "Iron Helmet", "kind": "gear", "piece": "iron_helm", "slot": "head", "from": "secret"},
	"miners_helm": {"word": "Lamp Helmet", "kind": "gear", "piece": "miners_helm", "slot": "head", "from": "secret"},
	"watchers_helm": {"word": "Watcher Helmet", "kind": "gear", "piece": "watchers_helm", "slot": "head", "from": "beast:gryphon"},
	"leather_armor": {"word": "Leather Vest", "kind": "gear", "piece": "leather_armor", "slot": "chest", "from": "secret"},
	"chain_mail": {"word": "Chain Shirt", "kind": "gear", "piece": "chain_mail", "slot": "chest", "from": "secret"},
	"plate_armor": {"word": "Shiny Armor", "kind": "gear", "piece": "plate_armor", "slot": "chest", "from": "secret"},
	"barnacle_mail": {"word": "Shell Armor", "kind": "gear", "piece": "barnacle_mail", "slot": "chest", "from": "secret"},
	"wyvern_scaleplate": {"word": "Dragon Armor", "kind": "gear", "piece": "wyvern_scaleplate", "slot": "chest", "from": "beast:wyvern"},
	"deepcoil_coat": {"word": "Sea Coat", "kind": "gear", "piece": "deepcoil_coat", "slot": "chest", "from": "beast:kraken"},
	"leather_pauldrons": {"word": "Shoulder Pads", "kind": "gear", "piece": "leather_pauldrons", "slot": "shoulders", "from": "secret"},
	"mail_pauldrons": {"word": "Chain Shoulders", "kind": "gear", "piece": "mail_pauldrons", "slot": "shoulders", "from": "secret"},
	"plate_pauldrons": {"word": "Big Shoulders", "kind": "gear", "piece": "plate_pauldrons", "slot": "shoulders", "from": "secret"},
	"leather_gloves": {"word": "Gloves", "kind": "gear", "piece": "leather_gloves", "slot": "hands", "from": "secret"},
	"archers_bracers": {"word": "Arm Guards", "kind": "gear", "piece": "archers_bracers", "slot": "hands", "from": "secret"},
	"gauntlets": {"word": "Iron Gloves", "kind": "gear", "piece": "gauntlets", "slot": "hands", "from": "secret"},
	"quickhand_gloves": {"word": "Quick Gloves", "kind": "gear", "piece": "quickhand_gloves", "slot": "hands", "from": "secret"},
	"climbing_boots": {"word": "Boots", "kind": "gear", "piece": "climbing_boots", "slot": "feet", "from": "secret"},
	"hobnail_boots": {"word": "Stomp Boots", "kind": "gear", "piece": "hobnail_boots", "slot": "feet", "from": "secret"},
	"wading_boots": {"word": "Tall Boots", "kind": "gear", "piece": "wading_boots", "slot": "feet", "from": "secret"},
	"phantom_treads": {"word": "Ghost Boots", "kind": "gear", "piece": "phantom_treads", "slot": "feet", "from": "secret"},
	"sunstone_pendant": {"word": "Sun Stone", "kind": "gear", "piece": "sunstone_pendant", "slot": "neck", "from": "beast:manticore"},
	"tide_locket": {"word": "Sea Locket", "kind": "gear", "piece": "tide_locket", "slot": "neck", "from": "secret"},
	"heartstone": {"word": "Heart Stone", "kind": "gear", "piece": "heartstone", "slot": "neck", "from": "secret"},
	"wayfinders_pendant": {"word": "Star Pendant", "kind": "gear", "piece": "wayfinders_pendant", "slot": "neck", "from": "secret"},
	"feather_cape": {"word": "Feather Cape", "kind": "gear", "piece": "feather_cape", "slot": "back", "from": "secret"},
	"climbers_pack": {"word": "Backpack", "kind": "gear", "piece": "climbers_pack", "slot": "back", "from": "secret"},
	"emberkin_mantle": {"word": "Fire Cape", "kind": "gear", "piece": "emberkin_mantle", "slot": "back", "from": "beast:chimera"},
	"sunplume_mantle": {"word": "Sun Cape", "kind": "gear", "piece": "sunplume_mantle", "slot": "back", "from": "beast:firebird"},
	"skin_gold": {"word": "Gold Weapons", "kind": "skin", "piece": "gold", "slot": "skin", "from": "secret"},
	"skin_crystal": {"word": "Ice Weapons", "kind": "skin", "piece": "crystal", "slot": "skin", "from": "secret"},
	"skin_flame": {"word": "Fire Weapons", "kind": "skin", "piece": "flame", "slot": "skin", "from": "secret"},
	"skin_shadow": {"word": "Shadow Weapons", "kind": "skin", "piece": "shadow", "slot": "skin", "from": "secret"},
}


## The treasures that can come from `source` ("secret", "beast:kraken"...).
static func treasure_for(source: String) -> Array:
	var out: Array = []
	for id in TREASURES:
		if String(TREASURES[id]["from"]) == source:
			out.append(id)
	return out
