extends RefCounted
## (A copy of the full game's scripts/palette.gd, so LITE looks like it.)
## The game's colours in one place: a cold, dim tower lit by warm torches.

# The room
static var VOID := Color(0.035, 0.03, 0.05)
static var FLOOR := Color(0.15, 0.145, 0.165)
static var FLOOR_LIGHT := Color(0.19, 0.18, 0.2)
static var FLOOR_GAP := Color(0.07, 0.065, 0.08)
static var MOSS := Color(0.22, 0.3, 0.17)
static var WALL_TOP := Color(0.17, 0.155, 0.19)
static var WALL_EDGE := Color(0.3, 0.28, 0.32)
static var WALL_FACE := Color(0.24, 0.21, 0.24)
static var TORCH := Color(1.0, 0.68, 0.38)
# Doors (doors.gd)
static var DOOR_WOOD := Color(0.36, 0.24, 0.15)
static var DOOR_IRON := Color(0.32, 0.31, 0.35)
static var DOOR_STONE := Color(0.33, 0.31, 0.35)

# Light and darkness (lighting.gd): each tower's darkness has its own colour;
# alpha is how dark its unlit places are (1 = black, 0 = no darkness).
static var TOWER_FOG := {
	"gryphon": Color(0.031, 0.047, 0.094, 0.74),
	"kraken": Color(0.008, 0.039, 0.071, 0.76),
	"wyvern": Color(0.063, 0.016, 0.008, 0.74),
	"manticore": Color(0.071, 0.047, 0.016, 0.7),
	"firebird": Color(0.071, 0.024, 0.039, 0.72),
	"chimera": Color(0.016, 0.047, 0.016, 0.74),
}
## Each tower's hue on its stone (floor and walls), over the tower's own stone colour.
static var TOWER_TINT := {
	"gryphon": Color(0.7, 0.75, 0.92),
	"kraken": Color(0.62, 0.8, 0.9),
	"wyvern": Color(0.92, 0.72, 0.68),
	"manticore": Color(0.92, 0.8, 0.62),
	"firebird": Color(0.92, 0.7, 0.62),
	"chimera": Color(0.74, 0.88, 0.68),
}
static var FOG_UNSEEN :=Color(0.016, 0.012, 0.031)  # places out of the climber's sight
static var VIGNETTE := 0.45  # how much the screen's corners darken
static var PLAYER_LIGHT := Color(1.0, 0.88, 0.74)  # the climber's own glow
static var STAIR_LIGHT := Color(1.0, 0.85, 0.5)
static var WARD_LIGHT := Color(0.75, 0.55, 1.0)
static var EYE_LIGHT := Color(1.0, 0.82, 0.42)  # a puzzle's eyes
static var FIRE_LIGHT := Color(1.0, 0.55, 0.22)  # burning floor

# Characters
static var OUTLINE := Color(0.06, 0.05, 0.07)
const CLIMBER_CLOAK := Color(0.28, 0.55, 0.62)
const CLIMBER_SKIN := Color(0.93, 0.8, 0.66)
const CLIMBER_TUNIC := Color(0.42, 0.34, 0.27)  # sleeves and tunic under the cloak
const CLIMBER_HAIR := Color(0.36, 0.22, 0.14)
const CLIMBER_BOOT := Color(0.24, 0.17, 0.13)
static var STEEL := Color(0.78, 0.8, 0.86)
static var WOOD := Color(0.52, 0.35, 0.2)
const SLIME := Color(0.5, 0.88, 0.4)
const ARCHER := Color(0.62, 0.5, 0.3)
const KNIGHT := Color(0.66, 0.7, 0.8)
const PLUME := Color(0.75, 0.2, 0.18)
static var DANGER := Color(1.0, 0.3, 0.25)

# --- LITE: a little brighter and more cartoony than the full game ---------------
## Every colour the characters, rooms and buttons are drawn in passes through
## toon() (draw_util.gd Batch, creatures.gd Pen): more saturated and brighter,
## while the dark outlines stay dark. And outlines are drawn TOON_LINE times as
## thick as the full game's. (1.0 everywhere would look just like the full game.)
static var TOON_SAT := 1.25
static var TOON_BRIGHT := 1.14
static var TOON_LIFT := 0.04
static var TOON_LINE := 1.6
static var _toon_cache := {}


static func toon(c: Color) -> Color:
	if _toon_cache.has(c):
		return _toon_cache[c]
	var k := clampf((c.v - 0.08) / 0.12, 0.0, 1.0)  # (outlines and deep shadows stay as they are)
	var out := c
	if k > 0.0:
		out = c.lerp(Color.from_hsv(c.h, minf(1.0, c.s * TOON_SAT), minf(1.0, c.v * TOON_BRIGHT + TOON_LIFT), c.a), k)
	if _toon_cache.size() > 6000:
		_toon_cache.clear()
	_toon_cache[c] = out
	return out
