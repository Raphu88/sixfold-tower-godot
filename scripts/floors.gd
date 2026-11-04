extends RefCounted
## Builds each floor of the climb: where the pillars stand and which
## monsters wait there. Floor 1 is a fixed introductory fight (its monsters
## depend on the tower); above that every floor is rolled fresh, weighted by
## the tower's monster mix, and gets harder.

## Monster price per floor budget, how often each is picked, and the floor
## it first appears on.
const MONSTERS := {
	"slime": {"cost": 1.0, "weight": 1.0, "from": 1},
	"archer": {"cost": 1.5, "weight": 0.8, "from": 2},
	"knight": {"cost": 2.5, "weight": 0.6, "from": 2},
	# Tower monsters: only appear where the tower's mix lists them.
	"bat": {"cost": 0.8, "weight": 1.0, "from": 1, "only": true},
	"thunderling": {"cost": 2.0, "weight": 1.0, "from": 2, "only": true},
	"lurker": {"cost": 1.5, "weight": 1.0, "from": 1, "only": true},
	"shellback": {"cost": 2.0, "weight": 1.0, "from": 2, "only": true},
	"cinder": {"cost": 1.2, "weight": 1.0, "from": 1, "only": true},
	"smith": {"cost": 2.5, "weight": 1.0, "from": 2, "only": true},
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


## Floor 1: four monsters in the familiar spots; `kinds` comes from the tower.
static func first_floor(room: Rect2, kinds: Array) -> Dictionary:
	var spots := [Vector2(680, 265), Vector2(740, 145), Vector2(780, 385), Vector2(1000, 265)]
	var monsters: Array = []
	for i in spots.size():
		monsters.append([kinds[i] if i < kinds.size() else "slime", room.position + spots[i]])
	return {"pillars": [], "monsters": monsters}


## `tower` is a tower's data (towers.gd): its monster mix and floor 1.
static func build(floor_num: int, room: Rect2, player_start: Vector2, tower: Dictionary = {}) -> Dictionary:
	if floor_num <= 1:
		return first_floor(room, tower.get("first", ["knight", "slime", "slime", "archer"]))
	# The summit: the tower's beast, alone in an open hall.
	if tower.has("beast_kind") and floor_num == int(tower.get("summit", 0)):
		return {"pillars": [], "monsters": [[tower["beast_kind"], room.get_center() + Vector2(0, -70)]], "summit": true}
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
		var pick := _pick(floor_num, budget, knights, tower.get("weights", {}))
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


## Standing water for wet towers: a few pools, clear of pillars and the start.
static func puddles(room: Rect2, pillars: Array, start: Vector2) -> Array:
	var list: Array = []
	for i in 3 + randi() % 3:
		for attempt in 20:
			var pos := room.position + room.size * Vector2(randf_range(0.1, 0.9), randf_range(0.15, 0.85))
			var r := randf_range(45.0, 85.0)
			var ok := pos.distance_to(start) > r + 60.0
			for p in pillars:
				ok = ok and pos.distance_to(p["pos"]) > p["r"] + r * 0.6
			if ok:
				list.append({"pos": pos, "r": r})
				break
	return list


## How much tougher monsters are on a floor (health, damage).
static func toughness(floor_num: int) -> Vector2:
	var f := float(maxi(floor_num - 1, 0))
	return Vector2(1.0 + 0.08 * f, 1.0 + 0.05 * f)


static func _pick(floor_num: int, budget: float, knights: int, mix: Dictionary = {}) -> String:
	var options: Array = []
	var total := 0.0
	for kind in MONSTERS:
		var m: Dictionary = MONSTERS[kind]
		if m.get("only", false) and not mix.has(kind):
			continue
		if floor_num < m["from"] or m["cost"] > budget:
			continue
		# Knights are capped per floor (a knight-heavy tower allows one more).
		var knight_cap := maxi(1, floor_num / 2) + (1 if float(mix.get("knight", 1.0)) > 1.0 else 0)
		if kind == "knight" and knights >= knight_cap:
			continue
		options.append(kind)
		total += float(m["weight"]) * float(mix.get(kind, 1.0))
	if options.is_empty():
		return ""
	var roll := randf() * total
	for kind in options:
		roll -= float(MONSTERS[kind]["weight"]) * float(mix.get(kind, 1.0))
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
