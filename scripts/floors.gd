extends RefCounted
## Builds each floor of the climb: where the pillars stand and which
## monsters wait there. Floor 1 is always the same introductory fight;
## above that every floor is rolled fresh and gets harder.

## Monster price per floor budget, how often each is picked, and the floor
## it first appears on.
const MONSTERS := {
	"slime": {"cost": 1.0, "weight": 1.0, "from": 1},
	"archer": {"cost": 1.5, "weight": 0.8, "from": 2},
	"knight": {"cost": 2.5, "weight": 0.6, "from": 2},
}
const MAX_MONSTERS := 9

## Pillar layouts, as fractions of the room (x, y, radius in px).
const LAYOUTS := [
	[[0.3, 0.35, 26.0], [0.7, 0.35, 26.0], [0.3, 0.7, 26.0], [0.7, 0.7, 26.0]],  # four corners
	[[0.5, 0.5, 46.0]],  # one great pillar
	[[0.2, 0.5, 22.0], [0.4, 0.5, 22.0], [0.6, 0.5, 22.0], [0.8, 0.5, 22.0]],  # a row
	[[0.35, 0.3, 24.0], [0.65, 0.3, 24.0], [0.5, 0.62, 34.0]],  # a triangle
	[[0.25, 0.3, 20.0], [0.75, 0.3, 20.0], [0.25, 0.72, 20.0], [0.75, 0.72, 20.0], [0.5, 0.5, 30.0]],  # five
	[],  # open hall
]


## Floor 1: the fight you already know.
static func first_floor(room: Rect2) -> Dictionary:
	return {
		"pillars": [],
		"monsters": [
			["knight", room.position + Vector2(680, 265)],
			["slime", room.position + Vector2(740, 145)],
			["slime", room.position + Vector2(780, 385)],
			["archer", room.position + Vector2(1000, 265)],
		],
	}


static func build(floor_num: int, room: Rect2, player_start: Vector2) -> Dictionary:
	if floor_num <= 1:
		return first_floor(room)
	var pillars: Array = []
	for p in LAYOUTS[randi() % LAYOUTS.size()]:
		pillars.append({"pos": room.position + room.size * Vector2(p[0], p[1]), "r": p[2]})
	# Sometimes a few loose pillars on top.
	for i in randi() % 3:
		var pos := room.position + room.size * Vector2(randf_range(0.12, 0.88), randf_range(0.2, 0.7))
		if _clear_of(pos, 70.0, pillars, []) and pos.distance_to(player_start) > 140.0:
			pillars.append({"pos": pos, "r": randf_range(16.0, 24.0)})

	# Spend the floor's budget on monsters.
	var budget := 4.5 + 1.0 * floor_num
	var kinds: Array = []
	var knights := 0
	while budget >= 1.0 and kinds.size() < MAX_MONSTERS:
		var pick := _pick(floor_num, budget, knights)
		if pick == "":
			break
		kinds.append(pick)
		budget -= MONSTERS[pick]["cost"]
		if pick == "knight":
			knights += 1

	# Place them in the far part of the room, clear of pillars and each other.
	var monsters: Array = []
	var placed: Array = []
	for kind in kinds:
		var pos := Vector2.ZERO
		for attempt in 40:
			pos = room.position + room.size * Vector2(randf_range(0.1, 0.9), randf_range(0.12, 0.62))
			if _clear_of(pos, 60.0, pillars, placed) and pos.distance_to(player_start) > 260.0:
				break
		placed.append(pos)
		monsters.append([kind, pos])
	return {"pillars": pillars, "monsters": monsters}


## How much tougher monsters are on a floor (health, damage).
static func toughness(floor_num: int) -> Vector2:
	var f := float(maxi(floor_num - 1, 0))
	return Vector2(1.0 + 0.08 * f, 1.0 + 0.05 * f)


static func _pick(floor_num: int, budget: float, knights: int) -> String:
	var options: Array = []
	var total := 0.0
	for kind in MONSTERS:
		var m: Dictionary = MONSTERS[kind]
		if floor_num < m["from"] or m["cost"] > budget:
			continue
		if kind == "knight" and knights >= maxi(1, floor_num / 2):
			continue
		options.append(kind)
		total += m["weight"]
	if options.is_empty():
		return ""
	var roll := randf() * total
	for kind in options:
		roll -= MONSTERS[kind]["weight"]
		if roll <= 0.0:
			return kind
	return options[-1]


static func _clear_of(pos: Vector2, gap: float, pillars: Array, others: Array) -> bool:
	for p in pillars:
		if pos.distance_to(p["pos"]) < p["r"] + gap:
			return false
	for o in others:
		if pos.distance_to(o) < gap:
			return false
	return true
