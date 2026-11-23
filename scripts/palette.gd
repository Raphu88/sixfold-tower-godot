extends RefCounted
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
# Holes you fall through (holes.gd): dark pits. The floor far below (faint),
# the depth over it, the shaft's walls falling away to near-black, the cut's lit rim
static var HOLE_FLOOR := Color(0.085, 0.08, 0.095)
static var HOLE_FLOOR_LIGHT := Color(0.105, 0.1, 0.118)
static var HOLE_GAP := Color(0.012, 0.011, 0.016)
static var HOLE_DEPTH := Color(0.0, 0.0, 0.012, 0.56)
static var HOLE_SHAFT := Color(0.17, 0.155, 0.18)
static var HOLE_SHAFT_DEEP := Color(0.018, 0.016, 0.022)
static var HOLE_RIM := Color(0.6, 0.57, 0.6)
## The haze over the floor below, per tower ("other" for the rest).
static var HOLE_HAZE := {
	"firebird": Color(1.0, 0.42, 0.18, 0.1),
	"gryphon": Color(0.55, 0.66, 0.95, 0.06),
	"kraken": Color(0.3, 0.6, 0.75, 0.07),
	"manticore": Color(0.95, 0.75, 0.45, 0.06),
	"wyvern": Color(1.0, 0.45, 0.15, 0.08),
	"chimera": Color(0.45, 0.8, 0.4, 0.06),
	"other": Color(0.45, 0.5, 0.65, 0.04),
}
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
## Each tower's grade in the screen's finishing pass (finish.gd): [the tint
## lifted into its shadows, the warmth or coolness of its light].
static var TOWER_GRADE := {
	"gryphon": [Color(0.008, 0.014, 0.03), Color(0.98, 1.0, 1.03)],
	"kraken": [Color(0.0, 0.025, 0.035), Color(0.95, 1.02, 1.04)],
	"wyvern": [Color(0.04, 0.012, 0.004), Color(1.05, 0.99, 0.94)],
	"manticore": [Color(0.035, 0.022, 0.0), Color(1.05, 1.01, 0.93)],
	"firebird": [Color(0.04, 0.01, 0.02), Color(1.06, 0.98, 0.95)],
	"chimera": [Color(0.004, 0.03, 0.008), Color(0.98, 1.04, 0.96)],
	"other": [Color(0.01, 0.01, 0.025), Color(1.0, 1.0, 1.0)],
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
## A wild tower (wild_towers.gd): wild essence's colour (its storms, the
## map's sign), a strike's bright core, and the tint a wild tower's stone
## takes (WILD_TINT_K of the way toward WILD_TINT).
static var WILD := Color(0.74, 0.48, 1.0)
static var WILD_HOT := Color(0.96, 0.86, 1.0)
static var WILD_TINT := Color(0.8, 0.66, 1.0)
static var WILD_TINT_K := 0.18
