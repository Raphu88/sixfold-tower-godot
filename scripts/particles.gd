extends Node2D
## Particles: the sparks, embers, drips and glints of enchanted weapons and
## spells, in ONE node under the room (like lighting.gd: one draw for
## everything, no node per particle, no GPUParticles2D).
##
## It owns a small pool of particles (position, velocity, life, size, colour,
## gravity, drag, spin, additive or normal blend) and draws them all itself:
## a soft dot, a streak along its flight, a tumbling shard or a bit of grit.
## They are drawn above the darkness (so they shine) but UNDER the foes'
## telegraphs and the spells' own drawing (z 44, those are 45 and 46), they
## are small and short, and they pause with the game and clear on a new floor.
##
## For other code:
##   Particles.burst(main, pos, "preset", count_scale, dir, colour)   a puff, now
##   Particles.emitter(main, follow, "preset", colour, gate, scale)   a stream; returns
##       a handle: handle.stop(). `follow` is a node, or a Callable giving a
##       position (null ends it); `gate` (optional) says when it may emit.
##
## PRESETS are the data (colour, count, speed, life, size, gravity, drag,
## spread, blend...): the Data editor can change every one. EFFECTS (Settings
## -> Effects: Low, Medium, High) scale how many there are and the cap.
## ESSENCE_FX gives each essence its way of looking, BOND_FX and SPELL_FX
## tune a mark or a spell, so all eighteen marks get something.
##
## What glows: an enchanted weapon (Fine and Rare pieces, and relics) shows
## its essence: a soft glow, a small moving light, and particles by essence.
## Spells flash a light at the caster and carry light and particles as they
## fly or last; foes under a state (burning, poisoned...) give off matching
## specks; reactions burst; hits and kills spark.

const Essence := preload("res://scripts/essence.gd")
const Gear := preload("res://scripts/gear.gd")
const Bonds := preload("res://scripts/bonds.gd")

const NONE := Color(0, 0, 0, 0)
const POOL := 640  # the most the arrays hold (the cap below is lower)
const F_ADD := 1
const F_STREAK := 2
const F_SHARD := 4
const F_GRIT := 8
const F_SHRINK := 16

## Settings -> Effects. "count": how many a burst makes (a share of its
## preset); "cap": most particles alive; "rate": how many a stream makes
## (0: no ambient streams, lights and key flashes only); "key": the least
## share an important burst (a crit, a reaction, a cast) keeps; "lights":
## how many small lights the effects may carry at once.
static var EFFECTS := {
	"low": {"name": "Low", "count": 0.15, "cap": 48, "rate": 0.0, "key": 0.5, "lights": 6},
	"medium": {"name": "Medium", "count": 1.0, "cap": 150, "rate": 1.0, "key": 1.0, "lights": 10},
	"high": {"name": "High", "count": 1.6, "cap": 300, "rate": 1.5, "key": 1.0, "lights": 14},
}
const LEVEL_ORDER := ["low", "medium", "high"]
static var level := "medium"

static var TEXT := {
	"wield": "Enchanted: it shows its essence, and lights a little of the dark.",
	"setting": "Effects",
}

## The enchanted weapon's light: how far it reaches, how strong, and the
## halo round it (radius, strength). Small: it helps a little in the dark.
static var WEAPON_LIGHT := {"reach": 64.0, "strength": 0.3, "bloom": [13.0, 0.45], "glow_width": 4.0, "glow_alpha": 0.38}
## A spell's light as it flies or lasts: reach at least, strength.
static var SPELL_LIGHT := {"reach": 78.0, "strength": 0.42, "orb": 2.6, "zone": 1.1, "zone_strength": 0.3}
## The flash at the caster when a spell goes off: size, energy, seconds.
static var CAST_FLASH := {"size": 0.8, "apex": 1.3, "energy": 1.2, "dur": 0.25}
## How often foes' and zones' specks are looked for (seconds), and the view's margin.
static var SCAN := {"every": 0.1, "margin": 56.0}

## Each preset: color; count (a burst); speed (about; each particle 0.5-1.1x);
## life (seconds, 0.7-1.2x); size (pixels); gravity (pixels/s down, negative
## rises); drag (per second); spread (half-angle round the direction; PI is
## every way); blend "add" or "mix"; shape "dot", "streak", "shard" or
## "grit"; rate (a stream's particles a second); jitter (pixels of scatter);
## inward (they start round the spot and fly to it); key (shown even on Low).
static var PRESETS := {
	# --- blows ---
	"hit": {"color": Color(1.0, 0.93, 0.8), "count": 3, "speed": 170.0, "life": 0.2, "size": 1.6, "drag": 6.0, "spread": 0.8, "blend": "add", "shape": "streak"},
	"hit_heavy": {"color": Color(1.0, 0.9, 0.7), "count": 6, "speed": 230.0, "life": 0.26, "size": 2.0, "drag": 6.0, "spread": 1.0, "blend": "add", "shape": "streak"},
	"crit": {"color": Color(1.0, 0.85, 0.45), "count": 12, "speed": 300.0, "life": 0.34, "size": 2.2, "drag": 5.0, "spread": 3.14, "blend": "add", "shape": "streak", "key": true},
	"kill": {"color": Color(1.0, 0.85, 0.6), "count": 8, "speed": 150.0, "life": 0.5, "size": 2.4, "gravity": 60.0, "drag": 3.0, "spread": 3.14, "blend": "add", "shape": "dot"},
	"kill_big": {"color": Color(1.0, 0.85, 0.6), "count": 16, "speed": 210.0, "life": 0.65, "size": 2.8, "gravity": 50.0, "drag": 2.5, "spread": 3.14, "blend": "add", "shape": "dot", "key": true},
	"spark": {"color": Color(0.95, 0.92, 0.85), "count": 6, "speed": 250.0, "life": 0.3, "size": 1.6, "gravity": 220.0, "drag": 3.0, "spread": 1.1, "blend": "add", "shape": "streak"},
	"grit": {"color": Color(0.82, 0.68, 0.45), "count": 6, "speed": 130.0, "life": 0.5, "size": 2.0, "gravity": 300.0, "drag": 2.0, "spread": 1.3, "blend": "mix", "shape": "grit"},
	"mote": {"color": Color(0.9, 0.9, 1.0), "count": 4, "speed": 80.0, "life": 0.6, "size": 2.4, "gravity": -20.0, "drag": 2.0, "spread": 3.14, "blend": "add", "shape": "dot"},
	# --- an enchanted weapon's streams ---
	"ember": {"color": Color(1.0, 0.55, 0.25), "count": 1, "speed": 16.0, "life": 0.9, "size": 2.2, "gravity": -34.0, "drag": 1.2, "spread": 3.14, "blend": "add", "shape": "dot", "rate": 9.0, "jitter": 2.0},
	"drip": {"color": Color(0.45, 0.78, 0.9), "count": 1, "speed": 5.0, "life": 0.65, "size": 1.9, "gravity": 190.0, "drag": 0.4, "spread": 3.14, "blend": "add", "shape": "dot", "rate": 4.0, "jitter": 2.0},
	"wisp": {"color": Color(0.8, 0.92, 1.0), "count": 1, "speed": 20.0, "life": 1.1, "size": 3.0, "gravity": -6.0, "drag": 1.4, "spread": 3.14, "blend": "add", "shape": "dot", "rate": 5.0, "jitter": 3.0},
	"shimmer": {"color": Color(0.9, 0.4, 0.45), "count": 1, "speed": 5.0, "life": 0.3, "size": 1.8, "drag": 2.0, "spread": 3.14, "blend": "add", "shape": "dot", "rate": 70.0, "jitter": 1.0},
	"trail": {"color": Color(0.9, 0.9, 1.0), "count": 1, "speed": 8.0, "life": 0.32, "size": 2.4, "drag": 2.0, "spread": 3.14, "blend": "add", "shape": "dot", "rate": 45.0, "jitter": 1.0},
	# --- spells: what flies off the caster ---
	"flare": {"color": Color(1.0, 0.95, 0.8), "count": 10, "speed": 160.0, "life": 0.4, "size": 2.4, "drag": 3.0, "spread": 3.14, "blend": "add", "shape": "dot", "key": true},
	"spray": {"color": Color(1.0, 0.95, 0.8), "count": 12, "speed": 260.0, "life": 0.35, "size": 1.8, "drag": 3.0, "spread": 0.5, "blend": "add", "shape": "streak", "key": true},
	"crackle": {"color": Color(0.95, 0.89, 0.42), "count": 9, "speed": 130.0, "life": 0.2, "size": 2.0, "drag": 2.0, "spread": 3.14, "blend": "add", "shape": "shard", "key": true},
	"ember_burst": {"color": Color(1.0, 0.55, 0.25), "count": 10, "speed": 150.0, "life": 0.7, "size": 2.4, "gravity": -30.0, "drag": 2.5, "spread": 1.6, "blend": "add", "shape": "dot", "key": true},
	"smoke": {"color": Color(0.3, 0.27, 0.27, 0.55), "count": 5, "speed": 26.0, "life": 1.0, "size": 5.0, "gravity": -20.0, "drag": 1.0, "spread": 3.14, "blend": "mix", "shape": "dot"},
	"drip_burst": {"color": Color(0.45, 0.78, 0.9), "count": 10, "speed": 150.0, "life": 0.6, "size": 2.2, "gravity": 220.0, "drag": 2.0, "spread": 1.4, "blend": "add", "shape": "dot", "key": true},
	"frost": {"color": Color(0.8, 0.95, 1.0), "count": 8, "speed": 50.0, "life": 0.8, "size": 2.2, "gravity": 24.0, "drag": 1.5, "spread": 3.14, "blend": "add", "shape": "shard", "key": true},
	"pull": {"color": Color(0.7, 0.55, 1.0), "count": 14, "speed": 130.0, "life": 0.5, "size": 2.2, "drag": 0.0, "spread": 3.14, "blend": "add", "shape": "dot", "inward": true, "radius": 48.0, "key": true},
	"dust": {"color": Color(0.82, 0.68, 0.45, 0.8), "count": 9, "speed": 100.0, "life": 0.7, "size": 3.2, "gravity": 40.0, "drag": 2.5, "spread": 3.14, "blend": "mix", "shape": "dot", "key": true},
	"wind": {"color": Color(0.85, 0.95, 1.0), "count": 9, "speed": 290.0, "life": 0.3, "size": 1.6, "drag": 3.0, "spread": 0.4, "blend": "add", "shape": "streak", "key": true},
	"venom": {"color": Color(0.55, 0.86, 0.35), "count": 6, "speed": 40.0, "life": 0.9, "size": 3.0, "gravity": -14.0, "drag": 1.2, "spread": 3.14, "blend": "mix", "shape": "dot", "key": true},
	"glint": {"color": Color(0.9, 0.85, 0.9), "count": 10, "speed": 190.0, "life": 0.3, "size": 2.0, "drag": 3.0, "spread": 1.4, "blend": "add", "shape": "shard", "key": true},
	"bloom": {"color": Color(0.5, 0.95, 0.5), "count": 8, "speed": 40.0, "life": 0.9, "size": 2.6, "gravity": -30.0, "drag": 1.2, "spread": 3.14, "blend": "add", "shape": "dot", "key": true},
	"runes": {"color": Color(0.8, 0.82, 0.88), "count": 8, "speed": 70.0, "life": 0.6, "size": 2.2, "drag": 2.0, "spread": 3.14, "blend": "add", "shape": "shard", "key": true},
	"reaction": {"color": Color(1.0, 0.9, 0.6), "count": 14, "speed": 230.0, "life": 0.4, "size": 2.4, "drag": 3.0, "spread": 3.14, "blend": "add", "shape": "streak", "key": true},
	# --- spells that stay: specks in a field, round an orb, along a bolt ---
	"zone": {"color": Color(0.8, 0.9, 1.0), "count": 1, "speed": 14.0, "life": 0.8, "size": 2.2, "gravity": -12.0, "drag": 1.0, "spread": 3.14, "blend": "add", "shape": "dot", "rate": 14.0},
	"zone_swirl": {"color": Color(0.5, 0.8, 1.0), "count": 1, "speed": 70.0, "life": 0.6, "size": 2.0, "drag": 0.5, "spread": 3.14, "blend": "add", "shape": "streak", "rate": 16.0},
	"orb": {"color": Color(1.0, 0.95, 0.7), "count": 1, "speed": 22.0, "life": 0.4, "size": 2.6, "drag": 2.0, "spread": 3.14, "blend": "add", "shape": "dot", "rate": 32.0, "jitter": 4.0},
	"arc": {"color": Color(0.95, 0.89, 0.42), "count": 1, "speed": 60.0, "life": 0.16, "size": 2.0, "drag": 2.0, "spread": 3.14, "blend": "add", "shape": "shard", "key": true},
	# --- states on a foe (or the climber) ---
	"state_burning": {"color": Color(1.0, 0.55, 0.2), "count": 1, "speed": 14.0, "life": 0.7, "size": 2.2, "gravity": -38.0, "drag": 1.0, "spread": 3.14, "blend": "add", "shape": "dot", "rate": 9.0, "jitter": 6.0},
	"state_poisoned": {"color": Color(0.55, 0.86, 0.35), "count": 1, "speed": 8.0, "life": 0.9, "size": 2.8, "gravity": -16.0, "drag": 1.0, "spread": 3.14, "blend": "mix", "shape": "dot", "rate": 4.0, "jitter": 6.0},
	"state_bleeding": {"color": Color(0.86, 0.18, 0.2), "count": 1, "speed": 10.0, "life": 0.55, "size": 2.0, "gravity": 170.0, "drag": 0.5, "spread": 3.14, "blend": "mix", "shape": "dot", "rate": 5.0, "jitter": 6.0},
	"state_soaked": {"color": Color(0.4, 0.7, 0.96), "count": 1, "speed": 6.0, "life": 0.6, "size": 1.9, "gravity": 150.0, "drag": 0.5, "spread": 3.14, "blend": "add", "shape": "dot", "rate": 6.0, "jitter": 7.0},
	"state_charged": {"color": Color(0.95, 0.89, 0.42), "count": 1, "speed": 50.0, "life": 0.14, "size": 2.0, "drag": 2.0, "spread": 3.14, "blend": "add", "shape": "shard", "rate": 8.0, "jitter": 8.0},
	"state_airborne": {"color": Color(0.82, 0.93, 1.0), "count": 1, "speed": 30.0, "life": 0.5, "size": 2.0, "drag": 2.0, "spread": 3.14, "blend": "add", "shape": "streak", "rate": 6.0, "jitter": 8.0},
}

## Each essence's way: "cast" (what flies off a caster), "trail" (what a
## spell's shot or a weapon streams: a PRESETS id), "hit" (an enchanted
## weapon's blow), "swing" (streams only while swinging).
static var ESSENCE_FX := {
	"fire": {"cast": "ember_burst", "trail": "ember", "hit": "ember_burst", "also": "smoke"},
	"water": {"cast": "drip_burst", "trail": "drip", "hit": "drip_burst"},
	"air": {"cast": "wind", "trail": "wisp", "hit": "wind"},
	"iron": {"cast": "spray", "trail": "trail", "hit": "spark"},
	"stone": {"cast": "dust", "trail": "trail", "hit": "grit"},
	"blade": {"cast": "glint", "trail": "shimmer", "hit": "glint", "swing": true},
	"life": {"cast": "bloom", "trail": "wisp", "hit": "bloom"},
	"unmaking": {"cast": "pull", "trail": "trail", "hit": "pull"},
}

## A mark's own flavour (over its essence's): "p" the cast burst, "trail",
## "style" (cone: along your aim; ring: all round; up; pull: inward).
static var BOND_FX := {
	"stormcaller": {"p": "crackle", "trail": "arc"},
	"windwalker": {"p": "wind", "style": "cone"},
	"hunter": {"p": "wind", "trail": "wisp"},
	"tidecaller": {"p": "drip_burst", "trail": "drip"},
	"warden": {"p": "frost", "style": "ring"},
	"deepcaller": {"p": "pull", "style": "pull"},
	"blade_forger": {"p": "glint", "trail": "shimmer"},
	"flameblade": {"p": "ember_burst", "trail": "ember"},
	"rune_artist": {"p": "runes", "style": "ring"},
	"sandshaper": {"p": "dust", "style": "ring"},
	"venomist": {"p": "venom", "trail": "state_poisoned"},
	"ashwalker": {"p": "smoke", "style": "ring"},
	"flame_contractor": {"p": "ember_burst", "trail": "ember"},
	"flamewing": {"p": "ember_burst", "style": "ring", "trail": "ember"},
	"rekindler": {"p": "ember_burst", "style": "up"},
	"covenant": {"p": "glint", "style": "ring"},
	"grafter": {"p": "spray", "trail": "shimmer"},
	"surgeon": {"p": "glint", "trail": "shimmer"},
}

## Spell types given a look of their own (each mark's first spell and its
## step-5 Apex are tuned; the rest follow their mark): "p" preset, "style",
## "flash" (the caster's light flash, a share of CAST_FLASH), "also" a second preset.
static var SPELL_FX := {
	"chain": {"p": "crackle", "style": "cone", "flash": 1.0},
	"thunderhead": {"p": "crackle", "style": "ring", "flash": 1.5, "also": "flare"},
	"lift": {"p": "wind", "style": "up"},
	"cyclone": {"p": "wind", "style": "ring", "flash": 1.4, "also": "frost"},
	"shot": {"p": "wind", "style": "cone"},
	"rain": {"p": "wind", "style": "up", "flash": 1.3},
	"surge": {"p": "drip_burst", "style": "cone"},
	"maelstrom": {"p": "drip_burst", "style": "ring", "flash": 1.4, "also": "pull"},
	"barrier": {"p": "frost", "style": "ring"},
	"unbreakable": {"p": "dust", "style": "ring", "flash": 1.5, "also": "flare"},
	"drain": {"p": "pull", "style": "pull"},
	"drink": {"p": "pull", "style": "pull", "flash": 1.4, "also": "drip_burst"},
	"blades": {"p": "glint", "style": "cone"},
	"edges": {"p": "glint", "style": "ring", "flash": 1.4, "also": "spray"},
	"kindle": {"p": "ember_burst", "style": "cone", "also": "smoke"},
	"overheat": {"p": "ember_burst", "style": "ring", "flash": 1.5, "also": "smoke"},
	"trap": {"p": "runes", "style": "ring"},
	"sigil": {"p": "runes", "style": "ring", "flash": 1.5, "also": "flare"},
	"quake": {"p": "dust", "style": "ring", "also": "grit"},
	"fault": {"p": "dust", "style": "cone", "flash": 1.4, "also": "grit"},
	"spit": {"p": "venom", "style": "cone"},
	"virulence": {"p": "venom", "style": "ring", "flash": 1.4},
	"veil": {"p": "smoke", "style": "ring"},
	"ashfall": {"p": "smoke", "style": "ring", "flash": 1.4, "also": "ember_burst"},
	"fireball": {"p": "ember_burst", "style": "cone", "also": "smoke"},
	"cluster": {"p": "ember_burst", "style": "cone", "also": "smoke"},
	"meteor": {"p": "ember_burst", "style": "ring", "flash": 1.5, "also": "smoke"},
	"aura": {"p": "ember_burst", "style": "ring"},
	"firebirdform": {"p": "ember_burst", "style": "ring", "flash": 1.6, "also": "wind"},
	"rekindle": {"p": "ember_burst", "style": "up"},
	"phoenix": {"p": "ember_burst", "style": "up", "flash": 1.6, "also": "flare"},
	"call": {"p": "glint", "style": "ring"},
	"grandcall": {"p": "glint", "style": "ring", "flash": 1.5, "also": "flare"},
	"graftburst": {"p": "spray", "style": "cone"},
	"chimeraform": {"p": "spray", "style": "ring", "flash": 1.6, "also": "glint"},
	"sever": {"p": "glint", "style": "cone"},
	"amputate": {"p": "glint", "style": "ring", "flash": 1.5, "also": "spray"},
}

## An Unbound's technique shapes, by how they spray.
static var SHAPE_STYLE := {
	"strike": "cone", "bolt": "cone", "dash": "cone", "leap": "ring", "shell": "ring", "push": "cone",
	"shout": "ring", "pull": "pull", "mark": "ring", "sight": "cone", "within": "ring",
}

## What a spell's projectile (by its style) streams, and its light's colour
## ("" keeps its own tint). Arrows, bolts and lead shot only when enchanted.
static var SHOT_FX := {
	"fireball": "ember", "ember": "ember", "venom": "state_poisoned", "blade": "shimmer", "feather": "wisp", "essence": "", "spike": "state_poisoned",
}

## A state's streams, by its id (a PRESETS id), for foes and the climber.
const STATE_FX := {"burning": "state_burning", "poisoned": "state_poisoned", "bleeding": "state_bleeding",
	"soaked": "state_soaked", "charged": "state_charged", "airborne": "state_airborne"}
## What the world's lasting spells (main's lists) give off: list -> [preset, light share].
const ZONE_FX := {"maelstroms": "zone_swirl", "cyclones": "zone_swirl", "clouds": "state_poisoned", "wards": "zone",
	"rains": "wind", "flames": "state_burning", "smokes": "smoke", "meteors": "ember"}

var main
var level_cache := {}
var cost_us := 0  # microseconds the last frame took (updates and drawing), for tests
var cost_avg := 0.0  # ...and a running average
var spawned := 0  # particles made since the floor began (tests)
var glow: Node2D  # the additive layer
var emitters: Array = []  # Emitter handles
var _n := 0
var _px := PackedFloat32Array()
var _py := PackedFloat32Array()
var _vx := PackedFloat32Array()
var _vy := PackedFloat32Array()
var _age := PackedFloat32Array()
var _life := PackedFloat32Array()
var _size := PackedFloat32Array()
var _grav := PackedFloat32Array()
var _drag := PackedFloat32Array()
var _rot := PackedFloat32Array()
var _spin := PackedFloat32Array()
var _col := PackedColorArray()
var _flg := PackedInt32Array()
var _view := Rect2(-1e9, -1e9, 2e9, 2e9)
var _scan_t := 0.0
var _wield := {}  # node instance id -> {kind, light, em, node}
var _carried := {}  # a light id -> true (a spell's shot or zone carries it)
var _zone_lights: Array = []  # [dict, light id]
var _dot: Texture2D
var _was_drawing := false
var _draw_us := 0


## A stream's handle: stop() ends it. It ends by itself when its node is freed.
class Emitter extends RefCounted:
	var preset := ""
	var follow = null  # a Node2D, or a Callable giving a position (null: it ends)
	var color := Color(0, 0, 0, 0)
	var gate := Callable()
	var scale := 1.0
	var acc := 0.0
	var live := true
	var along = null  # a body whose weapon this stream rides (particles.gd works out where)
	var owner_node = null

	func stop() -> void:
		live = false

	func where():
		if along != null:
			if typeof(along) == TYPE_OBJECT and is_instance_valid(along) and along.is_inside_tree() and is_instance_valid(owner_node):
				return owner_node._weapon_point(along, randf())
			return null
		if typeof(follow) == TYPE_CALLABLE:
			return (follow as Callable).call() if (follow as Callable).is_valid() else null
		if typeof(follow) == TYPE_OBJECT and is_instance_valid(follow) and follow.is_inside_tree():
			return follow.global_position
		return null


func _ready() -> void:
	z_as_relative = false
	z_index = 44  # over the darkness (40) and its glow (41), under the foes' and climber's overlays (45) and the spells' own drawing (46)
	process_priority = 90
	for a in [_px, _py, _vx, _vy, _age, _life, _size, _grav, _drag, _rot, _spin]:
		a.resize(POOL)
	_col.resize(POOL)
	_flg.resize(POOL)
	_dot = _make_dot()
	glow = Node2D.new()
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = add
	glow.draw.connect(_draw_add)
	add_child(glow)
	if main != null and main.has_signal("on_hit"):
		main.on_hit.connect(_on_hit)


## A soft round dot (drawn in code): a bright middle in a short falloff.
func _make_dot() -> Texture2D:
	var n := 16
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
			var a := 0.0
			if d < 1.0:
				a = clampf(1.6 * (1.0 - d * d), 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


# --- the settings --------------------------------------------------------------

static func lv() -> Dictionary:
	return EFFECTS.get(level, EFFECTS["medium"])


## Settings -> Effects: "low", "medium" or "high".
static func set_level(l: String) -> void:
	level = l if EFFECTS.has(l) else "medium"


func cap() -> int:
	return mini(int(lv()["cap"]), POOL)


## How many particles are alive.
func count() -> int:
	return _n


# --- for other code ---------------------------------------------------------------

static func of(m):
	if m == null or not is_instance_valid(m) or not ("particles" in m):
		return null
	return m.particles


## A puff of a preset at `pos`, thrown about `dir` (zero: every way), the
## preset's colour or `color` if given. Returns how many it made.
static func burst(m, pos: Vector2, preset: String, count_scale := 1.0, dir := Vector2.ZERO, color := NONE) -> int:
	var pf = of(m)
	return pf.make(pos, preset, count_scale, dir, color) if pf != null else 0


## A stream of a preset from where `follow` is (a node, or a Callable giving a position).
static func emitter(m, follow, preset: String, color := NONE, gate := Callable(), scale := 1.0) -> Emitter:
	var e := Emitter.new()
	e.preset = preset
	e.follow = follow
	e.color = color
	e.gate = gate
	e.scale = scale
	var pf = of(m)
	if pf != null:
		pf.emitters.append(e)
	else:
		e.live = false
	return e


## Everything gone (a new floor).
static func clear(m) -> void:
	var pf = of(m)
	if pf != null:
		pf.reset()


func reset() -> void:
	_n = 0
	spawned = 0
	for e in emitters:
		e.live = false
	emitters.clear()
	for id in _wield.keys():
		_drop_wield(id)
	_wield.clear()
	for id in _carried.keys():
		if main != null and main.lighting != null:
			main.lighting.remove_light(id)
	_carried.clear()
	for z in _zone_lights:
		if main != null and main.lighting != null:
			main.lighting.remove_light(z[1])
	_zone_lights.clear()
	queue_redraw()
	if glow != null:
		glow.queue_redraw()


# --- making particles -----------------------------------------------------------------

## True if `pos` is on screen (a little beyond) and not in the fog.
func visible_at(pos: Vector2) -> bool:
	if not _view.has_point(pos):
		return false
	var lt = main.lighting if main != null else null
	if lt != null and lt.has_method("_fog_at") and lt._fog_at(pos) > 0.7:
		return false
	return true


## How many of `n` to make: the level's share (a little more for the
## important ones), fewer while the screen is busy; a fraction is a chance.
func _scaled(n: float, key: bool) -> int:
	var s: float = lv()["count"]
	if key:
		s = maxf(s, float(lv()["key"]))
	else:
		s *= clampf(1.0 - float(_n) / float(maxi(cap(), 1)), 0.25, 1.0)
	var x := n * s
	var whole := int(floor(x))
	if randf() < x - whole:
		whole += 1
	return whole


func make(pos: Vector2, preset: String, count_scale := 1.0, dir := Vector2.ZERO, color := NONE) -> int:
	var d: Dictionary = PRESETS.get(preset, {})
	if d.is_empty() or not visible_at(pos):
		return 0
	var n := _scaled(float(d.get("count", 6)) * count_scale, bool(d.get("key", false)))
	var made := 0
	for i in n:
		if _emit(d, pos, dir, color):
			made += 1
	return made


func _emit(d: Dictionary, pos: Vector2, dir: Vector2, color: Color) -> bool:
	if _n >= cap():
		return false
	var col: Color = color if color.a > 0.0 else d["color"]
	if color.a > 0.0 and d["color"].a < 1.0:
		col.a = d["color"].a
	var spread := float(d.get("spread", 3.14))
	var ang := randf() * TAU if (dir == Vector2.ZERO or spread >= 3.1) else dir.angle() + randf_range(-spread, spread)
	var sp := float(d.get("speed", 100.0)) * randf_range(0.5, 1.1)
	var at := pos
	var v := Vector2.from_angle(ang) * sp
	var jit := float(d.get("jitter", 0.0))
	if jit > 0.0:
		at += Vector2(randf_range(-jit, jit), randf_range(-jit, jit))
	if bool(d.get("inward", false)):
		var rad := float(d.get("radius", 44.0)) * randf_range(0.7, 1.1)
		at = pos + Vector2.from_angle(ang) * rad
		v = -Vector2.from_angle(ang) * sp
	var life := float(d.get("life", 0.5)) * randf_range(0.7, 1.2)
	if bool(d.get("inward", false)):
		life = minf(life, float(d.get("radius", 44.0)) / maxf(sp, 1.0))
	var f := 0
	if String(d.get("blend", "add")) == "add":
		f |= F_ADD
	match String(d.get("shape", "dot")):
		"streak":
			f |= F_STREAK
		"shard":
			f |= F_SHARD
		"grit":
			f |= F_GRIT
	var i := _n
	_n += 1
	spawned += 1
	_px[i] = at.x
	_py[i] = at.y
	_vx[i] = v.x
	_vy[i] = v.y
	_age[i] = 0.0
	_life[i] = maxf(life, 0.05)
	_size[i] = float(d.get("size", 2.5)) * randf_range(0.75, 1.2)
	_grav[i] = float(d.get("gravity", 0.0))
	_drag[i] = float(d.get("drag", 2.0))
	_rot[i] = randf() * TAU
	_spin[i] = randf_range(-14.0, 14.0)
	_col[i] = col
	_flg[i] = f
	return true


# --- each frame ------------------------------------------------------------------------

func _process(delta: float) -> void:
	if main == null or main.camera == null:
		return
	var t0 := Time.get_ticks_usec()
	var cam: Camera2D = main.camera
	var view: Vector2 = get_viewport_rect().size / cam.zoom
	var center: Vector2 = cam.get_screen_center_position() + cam.offset
	var m: float = SCAN["margin"]
	_view = Rect2(center - view * 0.5 - Vector2(m, m), view + Vector2(m, m) * 2.0)
	_run_emitters(delta)
	_scan_t -= delta
	_sync_player()
	if _scan_t <= 0.0:
		_scan_t = float(SCAN["every"])
		_scan_others()
		_scan_states()
		_scan_zones()
	_step(delta)
	if _n > 0 or _was_drawing:
		_was_drawing = _n > 0
		queue_redraw()
		glow.queue_redraw()
	cost_us = Time.get_ticks_usec() - t0 + _draw_us
	cost_avg = lerpf(cost_avg, float(cost_us), 0.1)


func _step(delta: float) -> void:
	var i := 0
	while i < _n:
		var a := _age[i] + delta
		if a >= _life[i]:
			# Swap the last one in.
			_n -= 1
			var j := _n
			if i != j:
				_px[i] = _px[j]
				_py[i] = _py[j]
				_vx[i] = _vx[j]
				_vy[i] = _vy[j]
				_age[i] = _age[j]
				_life[i] = _life[j]
				_size[i] = _size[j]
				_grav[i] = _grav[j]
				_drag[i] = _drag[j]
				_rot[i] = _rot[j]
				_spin[i] = _spin[j]
				_col[i] = _col[j]
				_flg[i] = _flg[j]
			continue
		_age[i] = a
		var k := maxf(0.0, 1.0 - _drag[i] * delta)
		_vx[i] *= k
		_vy[i] = _vy[i] * k + _grav[i] * delta
		_px[i] += _vx[i] * delta
		_py[i] += _vy[i] * delta
		_rot[i] += _spin[i] * delta
		i += 1


func _draw() -> void:
	var t0 := Time.get_ticks_usec()
	_draw_layer(self, false)
	_draw_us = Time.get_ticks_usec() - t0


func _draw_add() -> void:
	var t0 := Time.get_ticks_usec()
	_draw_layer(glow, true)
	_draw_us += Time.get_ticks_usec() - t0


func _draw_layer(c: Node2D, additive: bool) -> void:
	for i in _n:
		var f := _flg[i]
		if (f & F_ADD != 0) != additive:
			continue
		var k := 1.0 - _age[i] / _life[i]
		var col: Color = _col[i]
		col.a *= minf(1.0, k * 2.2)
		var p := Vector2(_px[i], _py[i])
		var s := _size[i]
		if f & F_STREAK:
			var v := Vector2(_vx[i], _vy[i])
			c.draw_line(p, p - v * 0.05, col, maxf(s * 0.7, 1.0))
		elif f & F_SHARD:
			var u := Vector2.from_angle(_rot[i]) * s * 1.6
			c.draw_line(p - u, p + u, col, 1.2)
		elif f & F_GRIT:
			c.draw_rect(Rect2(p - Vector2(s, s) * 0.5, Vector2(s, s)), col)
		else:
			var r := s * (0.6 + 0.6 * k)
			c.draw_texture_rect(_dot, Rect2(p - Vector2(r, r), Vector2(r, r) * 2.0), false, col)


# --- streams ---------------------------------------------------------------------------

func _run_emitters(delta: float) -> void:
	if emitters.is_empty():
		return
	var rate_k: float = lv()["rate"]
	var crowd := 1.0 / (1.0 + maxf(0.0, float(emitters.size()) - 5.0) * 0.12)  # (many streams: each makes fewer)
	var keep: Array = []
	for e in emitters:
		if not e.live:
			continue
		var pos = e.where()
		if pos == null:
			continue
		keep.append(e)
		if rate_k <= 0.0 or (e.gate.is_valid() and not e.gate.call()):
			continue
		var d: Dictionary = PRESETS.get(e.preset, {})
		if d.is_empty():
			continue
		if not visible_at(pos):
			continue
		e.acc += float(d.get("rate", 6.0)) * rate_k * crowd * e.scale * delta
		while e.acc >= 1.0:
			e.acc -= 1.0
			_emit(d, pos, Vector2.ZERO, e.color)
		e.acc = minf(e.acc, 2.0)
	emitters = keep


# --- enchanted weapons ---------------------------------------------------------------

## The essence of a piece, "" if ordinary.
static func enchant_of(piece) -> String:
	return Gear.enchant_kind(piece)


## The climber's own: light, glow and streams from the weapon in hand.
func _sync_player() -> void:
	var p = main.player
	if p == null or not is_instance_valid(p):
		return
	var kind := ""
	if not p.dead and p.weapon != "fists":
		kind = enchant_of(p.weapon_rec())
	if kind != "" and not _wield.has(p.get_instance_id()):
		main.tip("enchanted_weapon")  # (the Entity says it once)
	_sync_wield(p, kind)


## Rivals and mirror images that carry an enchanted weapon (w_enchant).
func _scan_others() -> void:
	for e in main.enemies():
		if not ("w_enchant" in e):
			continue
		var kind := String(e.w_enchant) if not e.dead else ""
		if kind == "" and not _wield.has(e.get_instance_id()):
			continue
		_sync_wield(e, kind)
	# Gone (freed) bodies: their lights follow the node and leave with it.
	for id in _wield.keys():
		var w: Dictionary = _wield[id]
		if not is_instance_valid(w["node"]) or w["node"].is_queued_for_deletion():
			_drop_wield(id)


func _sync_wield(node, kind: String) -> void:
	var id: int = node.get_instance_id()
	var w = _wield.get(id)
	if kind == "" or not ESSENCE_FX.has(kind):
		if w != null:
			_drop_wield(id)
		return
	if w != null and w["kind"] != kind:
		_drop_wield(id)
		w = null
	var lt = main.lighting
	if w == null:
		var col := Essence.color(kind)
		var lid := -1
		if lt != null:
			lid = lt.add_light(node.global_position, float(WEAPON_LIGHT["reach"]), col, float(WEAPON_LIGHT["strength"]), 0.04, node)
			lt.lights[lid]["noshadow"] = true
			lt.set_bloom(lid, float(WEAPON_LIGHT["bloom"][0]), float(WEAPON_LIGHT["bloom"][1]))
		var fx: Dictionary = ESSENCE_FX[kind]
		var gate := Callable()
		if bool(fx.get("swing", false)):
			gate = func(): return _swinging(node)
		var em := emitter(main, null, String(fx["trail"]), col, gate, 1.0)
		em.along = node
		em.owner_node = self
		if kind in ["iron", "stone"]:
			em.live = false  # (sparks and grit come on blows, not as a stream)
		w = {"kind": kind, "light": lid, "em": em, "node": node}
		_wield[id] = w
	# The light rides the weapon (a fire's flickers).
	var lt2 = main.lighting
	if lt2 != null and lt2.lights.has(w["light"]):
		var l: Dictionary = lt2.lights[w["light"]]
		l["offset"] = _weapon_point(node, 0.8) - node.global_position
		if kind == "fire":
			l["k"] = float(WEAPON_LIGHT["strength"]) * (0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.011 + float(id % 7)))


func _swinging(node) -> bool:
	if "swing_t" in node:
		return node.swing_t > 0.0 or ("drawing" in node and node.drawing) or ("attack_cd" in node and node.attack_cd > 0.3)
	return "state" in node and String(node.state).begins_with("wind") or ("swing_anim" in node and node.swing_anim > 0.0)


func _drop_wield(id: int) -> void:
	var w = _wield.get(id)
	if w == null:
		return
	_wield.erase(id)
	if w["em"] != null:
		w["em"].stop()
	if main != null and main.lighting != null and int(w["light"]) >= 0:
		main.lighting.remove_light(int(w["light"]))


## Where along the weapon (0 the grip, 1 the tip) it is in the world.
func _weapon_point(node, t: float) -> Vector2:
	if node.has_method("weapon_segment"):
		var seg: Array = node.weapon_segment()
		return (seg[0] as Vector2).lerp(seg[1], t)
	var face: Vector2 = node.face if "face" in node else Vector2.RIGHT
	var r: float = node.radius if "radius" in node else 14.0
	return node.global_position + face * (r + 4.0 + 16.0 * t)


## Whether this node's weapon is lit with essence (its kind, "" if not).
func wield_kind(node) -> String:
	var w = _wield.get(node.get_instance_id())
	return String(w["kind"]) if w != null else ""


## The soft glow along the climber's blade, drawn into the overlay `c`
## (over the darkness, so it shines in the dark).
func draw_weapon_glow(node, c: Node2D) -> void:
	var kind := wield_kind(node)
	if kind == "" or not node.has_method("weapon_segment"):
		return
	var col := Essence.color(kind)
	var seg: Array = node.weapon_segment()
	var a: Vector2 = (seg[0] as Vector2) - node.global_position
	var b: Vector2 = (seg[1] as Vector2) - node.global_position
	var pulse := 0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.006)
	var al: float = float(WEAPON_LIGHT["glow_alpha"]) * pulse
	var w: float = float(WEAPON_LIGHT["glow_width"])
	c.draw_line(a, b, Color(col, al * 0.6), w * 1.8)
	c.draw_line(a, b, Color(col.lightened(0.35), al * 1.3), w * 0.5)
	c.draw_circle(b, w * 1.4, Color(col, al * 0.8))


# --- hits and kills ---------------------------------------------------------------------

## A blow lands (the climber's _strike): a bigger burst on crits and heavy
## blows, and an enchanted melee weapon's own (iron sparks, stone grit...).
static func on_strike(m, pos: Vector2, dir: Vector2, crit: bool, heavy: bool, ranged: bool) -> void:
	var pf = of(m)
	if pf == null:
		return
	if crit:
		pf.make(pos, "crit", 1.0, dir)
	else:
		pf.make(pos, "hit_heavy" if heavy else "hit", 1.0, dir)
	var p = m.player
	if p == null:
		return
	var kind: String = pf.wield_kind(p)
	if kind != "" and not ranged:
		var fx: Dictionary = ESSENCE_FX[kind]
		pf.make(pos, String(fx["hit"]), 0.6 if not heavy else 1.0, dir, Essence.color(kind) if kind not in ["iron", "stone"] else NONE)


## A foe lost health (any source): a small speck of the blow's kind.
func _on_hit(foe, _dmg: float, _source: String) -> void:
	if not is_instance_valid(foe) or foe.dead:
		return
	var col := NONE
	if main.hit_kind == "lightning":
		make(foe.global_position, "arc", 2.0, Vector2.ZERO)
		return
	make(foe.global_position, "hit", 0.6, Vector2.ZERO, col)


static func kill(m, pos: Vector2, color: Color, radius: float, big := false) -> void:
	var pf = of(m)
	if pf != null:
		pf.make(pos, "kill_big" if big else "kill", clampf(radius / 14.0, 0.6, 2.0), Vector2.ZERO, color.lightened(0.2))


## A reaction fires (reactions.gd): its own burst, in its colour.
static func reaction(m, pos: Vector2, id: String, color: Color) -> void:
	var pf = of(m)
	if pf == null:
		return
	pf.make(pos, "reaction", 1.0, Vector2.ZERO, color)
	pf.make(pos, "flare", 0.6, Vector2.ZERO, color.lightened(0.3))
	match id:
		"steam":
			pf.make(pos, "smoke", 1.4, Vector2.ZERO, Color(0.92, 0.94, 0.96, 0.5))
		"conduct", "skybolt":
			pf.make(pos, "crackle", 1.0, Vector2.ZERO, color)
		"crater":
			pf.make(pos, "grit", 1.0)
		"fumes", "smoulder":
			pf.make(pos, "ember_burst", 0.8, Vector2.ZERO, color)


## Crackle along an arc (lightning between foes).
static func along(m, points: Array, color: Color) -> void:
	var pf = of(m)
	if pf == null:
		return
	for i in points.size() - 1:
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var steps := clampi(int(a.distance_to(b) / 34.0), 1, 8)
		for k in steps:
			pf.make(a.lerp(b, (k + randf()) / float(steps)), "arc", 1.0, Vector2.ZERO, color)


# --- spells ---------------------------------------------------------------------------------

## A mark's spell goes off (bond.gd cast): a flash at the caster and its particles.
static func on_bond_cast(m, p, bond, sp: Dictionary) -> void:
	var pf = of(m)
	if pf == null or p == null:
		return
	var kind := String(Bonds.BONDS.get(String(bond.id), {}).get("affinity", "air"))
	pf.cast_fx(p.global_position, p.aim, String(bond.id), String(sp.get("type", "")), kind, bond.color(), int(sp.get("learn", 1)) >= 5)


## An Unbound's technique goes off (unbound_run.gd): its lead essence, its shape's style.
static func on_technique_cast(m, p, lead: String, shape: String, color: Color) -> void:
	var pf = of(m)
	if pf == null or p == null:
		return
	var fx: Dictionary = ESSENCE_FX.get(lead, ESSENCE_FX["air"])
	var style := String(SHAPE_STYLE.get(shape, "cone"))
	pf.flash_at(p.global_position, color, 1.0)
	pf.style_burst(p.global_position, p.aim, String(fx["cast"]), style, color, 1.0)
	if fx.has("also"):
		pf.make(p.global_position, String(fx["also"]), 0.6, Vector2.ZERO)


## A rival's or mirror image's spell: its mark's sparks (their own flash is in mirror.gd).
static func on_foe_cast(m, pos: Vector2, dir: Vector2, bond_id: String, color: Color) -> void:
	var pf = of(m)
	if pf == null:
		return
	var kind := String(Bonds.BONDS.get(bond_id, {}).get("affinity", "air"))
	var bf: Dictionary = BOND_FX.get(bond_id, {})
	var ef: Dictionary = ESSENCE_FX.get(kind, ESSENCE_FX["air"])
	pf.style_burst(pos, dir, String(bf.get("p", ef["cast"])), String(bf.get("style", "cone")), color, 0.8)


func flash_at(pos: Vector2, color: Color, k: float) -> void:
	if main != null:
		main.light_flash(pos, color, float(CAST_FLASH["size"]) * k, float(CAST_FLASH["energy"]), float(CAST_FLASH["dur"]))


func cast_fx(pos: Vector2, aim: Vector2, bond_id: String, type: String, kind: String, color: Color, apex: bool) -> void:
	var sf: Dictionary = SPELL_FX.get(type, {})
	var bf: Dictionary = BOND_FX.get(bond_id, {})
	var ef: Dictionary = ESSENCE_FX.get(kind, ESSENCE_FX["air"])
	var preset := String(sf.get("p", bf.get("p", ef["cast"])))
	var style := String(sf.get("style", bf.get("style", "cone")))
	var k := float(sf.get("flash", 1.0)) * (float(CAST_FLASH["apex"]) if apex else 1.0)
	flash_at(pos, color, k)
	style_burst(pos, aim, preset, style, color, 1.5 if apex else 1.0)
	var also := String(sf.get("also", ef.get("also", "")))
	if also != "":
		style_burst(pos, aim, also, style, NONE, 0.6)


## A burst shaped by a style: along the aim (cone), all round (ring), up, or pulled in.
func style_burst(pos: Vector2, aim: Vector2, preset: String, style: String, color: Color, k: float) -> void:
	match style:
		"ring":
			make(pos, preset, k * 1.3, Vector2.ZERO, color)
		"up":
			make(pos, preset, k, Vector2.UP, color)
		"pull":
			make(pos, preset, k, Vector2.ZERO, color)
			if preset != "pull":
				make(pos, "pull", k * 0.5, Vector2.ZERO, color)
		_:
			make(pos + aim * 14.0, preset, k, aim, color)


## Lights and particles for a shot that's just left (projectile.gd calls this once).
## Spells' shots carry light; the climber's bow, crossbow and pistol only if enchanted.
static func carry(m, shot) -> void:
	var pf = of(m)
	if pf == null or not shot.friendly:
		return
	pf.carry_shot(shot)


func carry_shot(shot) -> void:
	var kind := ""
	var preset := ""
	var col: Color = shot.tint
	if shot.weapon:
		kind = String(shot.shot)
		if kind == "" and main.player != null and shot.style in ["arrow", "bolt", "shot"]:
			kind = wield_kind(main.player)
		if kind == "" or not ESSENCE_FX.has(kind):
			return
		col = Essence.color(kind)
		preset = String(ESSENCE_FX[kind]["trail"])
		if kind in ["iron", "stone"]:
			preset = "trail"
	else:
		if not SHOT_FX.has(String(shot.style)):
			return
		preset = String(SHOT_FX[String(shot.style)])
		if preset == "":
			preset = "trail"
		if shot.shot != "" and ESSENCE_FX.has(String(shot.shot)):
			preset = String(ESSENCE_FX[String(shot.shot)]["trail"])
	if shot.tint == Color.WHITE and not shot.weapon:
		col = NONE  # (no tint: the preset's own colour)
	emitter(main, shot, preset, col, Callable(), 1.0)
	_carry_light(shot, col if col.a > 0.0 else PRESETS[preset]["color"], float(SPELL_LIGHT["reach"]) * (0.8 if shot.weapon else 1.0), float(SPELL_LIGHT["strength"]) * (0.8 if shot.weapon else 1.0))


## A small moving light carried by `node` until it ends (never more than the level allows).
func _carry_light(node: Node2D, color: Color, reach: float, strength: float) -> int:
	var lt = main.lighting
	if lt == null:
		return -1
	for id in _carried.keys():
		if not lt.lights.has(id):
			_carried.erase(id)
	if _carried.size() >= int(lv()["lights"]):
		return -1
	var id: int = lt.add_light(node.global_position, reach, color, strength, 0.04, node)
	lt.lights[id]["noshadow"] = true
	_carried[id] = true
	return id


# --- what the spell library leaves in the world ---------------------------------------------

## An orb (spell_fx.gd) each frame: its light and a trail of specks.
static func orb_tick(m, o: Dictionary, delta: float) -> void:
	var pf = of(m)
	if pf == null:
		return
	var lt = m.lighting
	if lt != null:
		if not o.has("fxl"):
			o["fxl"] = -1
			var id := -1
			if pf._carried.size() < int(pf.lv()["lights"]):
				id = lt.add_light(o["pos"], maxf(float(SPELL_LIGHT["reach"]), float(o["radius"]) * float(SPELL_LIGHT["orb"])), o["col"], float(SPELL_LIGHT["strength"]) * 1.2, 0.05)
				lt.lights[id]["noshadow"] = true
				pf._carried[id] = true
			o["fxl"] = id
		elif int(o["fxl"]) >= 0:
			lt.move_light(int(o["fxl"]), o["pos"])
	var d: Dictionary = PRESETS["orb"]
	o["fxa"] = float(o.get("fxa", 0.0)) + float(d["rate"]) * float(pf.lv()["rate"]) * delta
	while float(o["fxa"]) >= 1.0:
		o["fxa"] = float(o["fxa"]) - 1.0
		if pf.visible_at(o["pos"]):
			pf._emit(d, o["pos"], Vector2.ZERO, (o["col"] as Color).lightened(0.3))
	o["fxa"] = minf(float(o["fxa"]), 2.0)


static func orb_end(m, o: Dictionary) -> void:
	var pf = of(m)
	if pf == null or not o.has("fxl"):
		return
	if int(o["fxl"]) >= 0 and m.lighting != null:
		m.lighting.remove_light(int(o["fxl"]))
		pf._carried.erase(int(o["fxl"]))
	o.erase("fxl")
	pf.make(o["pos"], "flare", 0.8, Vector2.ZERO, o["col"])


## A field (spell_fx.gd) each tick: motes rising in it, and a light while it lasts.
static func field_tick(m, f: Dictionary, delta: float) -> void:
	var pf = of(m)
	if pf == null:
		return
	var lt = m.lighting
	if lt != null:
		if not f.has("fxl"):
			if float(f["t"]) <= 0.3:
				return
			f["fxl"] = -1
			if pf._carried.size() < int(pf.lv()["lights"]):
				var id: int = lt.add_light(f["pos"], maxf(60.0, float(f["radius"]) * float(SPELL_LIGHT["zone"])), f["col"], float(SPELL_LIGHT["zone_strength"]), 0.03)
				lt.lights[id]["noshadow"] = true
				pf._carried[id] = true
				f["fxl"] = id
		elif int(f["fxl"]) >= 0 and float(f["t"]) < 0.3:
			lt.remove_light(int(f["fxl"]))
			pf._carried.erase(int(f["fxl"]))
			f["fxl"] = -1
	var d: Dictionary = PRESETS["zone"]
	var rate := float(d["rate"]) * clampf(float(f["radius"]) / 60.0, 0.5, 2.0) * float(pf.lv()["rate"])
	f["fxa"] = float(f.get("fxa", 0.0)) + rate * delta
	while float(f["fxa"]) >= 1.0:
		f["fxa"] = float(f["fxa"]) - 1.0
		var at: Vector2 = f["pos"] + Vector2.from_angle(randf() * TAU) * float(f["radius"]) * sqrt(randf())
		if pf.visible_at(at):
			pf._emit(d, at, Vector2.ZERO, (f["col"] as Color).lightened(0.3))
	f["fxa"] = minf(float(f["fxa"]), 2.0)


# --- foes and zones under a state --------------------------------------------------------------

func _scan_states() -> void:
	var rate_k: float = lv()["rate"]
	if rate_k <= 0.0:
		return
	var every := float(SCAN["every"])
	for e in main.enemies():
		if not _view.has_point(e.global_position) or not ("states" in e):
			continue
		for s in STATE_FX:
			if float(e.states.get(s, 0.0)) <= 0.0:
				continue
			if s == "poisoned" and e.venom <= 0:
				continue
			if s == "burning" and e.submerged:
				continue
			_state_speck(e.global_position, e.radius, s, every, rate_k)
	var p = main.player
	if p != null and not p.dead and _view.has_point(p.global_position):
		for st in STATE_FX:
			var left := float(p.states.get(st, 0.0))
			if st == "poisoned" and "poison_t" in p:
				left = maxf(left, float(p.poison_t))
			if left > 0.0:
				_state_speck(p.global_position, p.radius, st, every, rate_k)


func _state_speck(pos: Vector2, radius: float, state: String, every: float, rate_k: float) -> void:
	var d: Dictionary = PRESETS[STATE_FX[state]]
	if randf() > float(d["rate"]) * every * rate_k * (1.0 - float(_n) / float(maxi(cap(), 1))):
		return
	if not visible_at(pos):
		return
	var at := pos + Vector2(randf_range(-radius, radius) * 0.7, randf_range(-radius * 0.5, radius * 0.3))
	_emit(d, at, Vector2.ZERO, NONE)


## Lasting spells in the room (main's lists): specks and a small light each.
func _scan_zones() -> void:
	var rate_k: float = lv()["rate"]
	var lt = main.lighting
	# Lights for zones that have gone.
	var live: Array = []
	for z in _zone_lights:
		var d: Dictionary = z[0]
		var still := false
		for list in ["maelstroms", "cyclones", "wards"]:
			if main.get(list) is Array and (main.get(list) as Array).has(d):
				still = true
		if still and is_instance_valid(main) and lt != null and lt.lights.has(z[1]):
			lt.move_light(z[1], d["pos"])
			live.append(z)
		else:
			if lt != null:
				lt.remove_light(z[1])
			_carried.erase(z[1])
	_zone_lights = live
	for list in ZONE_FX:
		var arr = main.get(list)
		if not (arr is Array):
			continue
		var preset := String(ZONE_FX[list])
		for z in arr:
			if not (z is Dictionary) or not z.has("pos") or not _view.has_point(z["pos"]):
				continue
			var r := float(z.get("r", 40.0))
			var col: Color = z.get("color", NONE)
			if col.a <= 0.0:
				col = PRESETS[preset]["color"]
			if list in ["maelstroms", "cyclones", "wards"] and lt != null and not z.has("fxl_done") and _carried.size() < int(lv()["lights"]):
				z["fxl_done"] = true
				var id: int = lt.add_light(z["pos"], maxf(70.0, r * 1.2), col, float(SPELL_LIGHT["zone_strength"]), 0.03)
				lt.lights[id]["noshadow"] = true
				_carried[id] = true
				_zone_lights.append([z, id])
			if rate_k <= 0.0:
				continue
			var d2: Dictionary = PRESETS[preset]
			var n := float(d2.get("rate", 8.0)) * clampf(r / 70.0, 0.5, 2.5) * _scan_every() * rate_k * maxf(0.25, 1.0 - float(_n) / float(maxi(cap(), 1)))
			var whole := int(n)
			if randf() < n - whole:
				whole += 1
			for i in whole:
				_emit(d2, z["pos"] + Vector2.from_angle(randf() * TAU) * r * sqrt(randf()), Vector2.ZERO, NONE if list == "flames" else col.lightened(0.2))


func _scan_every() -> float:
	return float(SCAN["every"])


func _on_new_floor() -> void:
	reset()
