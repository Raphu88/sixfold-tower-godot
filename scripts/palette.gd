extends RefCounted
## The game's colours in one place: a cold, dim tower lit by warm torches.

# The room
const VOID := Color(0.035, 0.03, 0.05)
const FLOOR := Color(0.15, 0.145, 0.165)
const FLOOR_LIGHT := Color(0.19, 0.18, 0.2)
const FLOOR_GAP := Color(0.07, 0.065, 0.08)
const MOSS := Color(0.22, 0.3, 0.17)
const WALL_TOP := Color(0.17, 0.155, 0.19)
const WALL_EDGE := Color(0.3, 0.28, 0.32)
const WALL_FACE := Color(0.24, 0.21, 0.24)
const AMBIENT := Color(0.42, 0.43, 0.56)  # how bright unlit areas are
const TORCH := Color(1.0, 0.68, 0.38)

# Characters
const OUTLINE := Color(0.06, 0.05, 0.07)
const CLIMBER_CLOAK := Color(0.28, 0.55, 0.62)
const CLIMBER_SKIN := Color(0.93, 0.8, 0.66)
const STEEL := Color(0.78, 0.8, 0.86)
const WOOD := Color(0.52, 0.35, 0.2)
const SLIME := Color(0.5, 0.88, 0.4)
const ARCHER := Color(0.62, 0.5, 0.3)
const KNIGHT := Color(0.66, 0.7, 0.8)
const PLUME := Color(0.75, 0.2, 0.18)
const DANGER := Color(1.0, 0.3, 0.25)
