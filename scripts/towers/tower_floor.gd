extends Node2D
## A TOWER'S OWN FLOOR: the base every tower's floor script extends
## (scripts/towers/<tower>_floor.gd, named as the tower's "module" in
## floor_styles.gd). Each hook below does nothing here; a tower overrides
## the ones it needs. The README's "content contract" lists them too.
##
## PLANNING (static: floors.gd, rooms.gd, objectives.gd, scenarios.gd call
## them on the script while a floor is planned):
##   carve(shape, size) -> rows           a room shape of the tower's own
##                                        (floor_styles.gd SHAPE_MODULES)
##   shape_corridors(infos, links, corridors, walk) -> Array
##                                        the corridors' walkable rects (one
##                                        straight rect per link comes in);
##                                        may set link["tiles"], ["path"]
##   shape_plan(plan, infos, links, floor_num, tower)
##                                        the tower's ground over the finished
##                                        plan; set plan["ok"] = false to have
##                                        the floor planned again. It writes:
##     plan["tower_floor"] = {"module": <this script's path>, ...}
##                                        (main.gd makes the node from it)
##     plan["impassable"]  [Rect2]        ground nobody walks (reach.gd and the
##                                        traps treat it as rock)
##     plan["gates"]       [{tiles, lock_id, opens: {any|all: [tiles]}}]
##                                        ground shut until what opens it is
##                                        reached (a moat, a gap, a sunken
##                                        room, a raised bridge): reach.gd
##                                        counts each as a locked door
##   place_task(kind, spec, infos, cands, dist, monsters, floor_num, cell)
##                                        the pieces of the tower's own task
##                                        kind (objectives.gd "module"); here:
##                                        spread over `cands` the plain way
##   scenario_plan(kind, info, gates, floor_num, cell) -> {}
##                                        the tower's own scenario's marks
##                                        (scenarios.gd "module"); {} = won't fit
##
## IN PLAY (the node: main.tower_floor, made fresh each floor, `main` set):
##   setup(plan) / clear()                built / taken down
##   blocks_walking(tile) -> bool         main.is_solid also says yes here
##   slow_at(pos) -> float                walking speed share (1 = normal)
##   wet(pos) -> bool                     shallow water (main.in_water)
##   sight_k() -> float                   how far monsters see you, a share
##   is_void(pos) -> bool                 an open drop (the bot keeps off)
##   reach_live(solid, size, doors, opens)
##                                        the live floor's ground and gates
##                                        for reach.gd's safety net
##   open_gates()                         the dev tool's Open all doors
##   strike(from, dir, reach, arc)        every melee swing
##   task_tick(ob, delta, p, hurt) / task_strike(ob, from, dir, reach, arc)
##                                        the tower's own task kind
##   scenario_begin(s, host) / scenario_tick(s, delta, p, host) (calls
##   host._finish) / scenario_title(s) / scenario_status(s) / scenario_goal(s)
##                                        the tower's own scenario
## THE FLOOR BOT (tests/floor_bot_driver.gd):
##   bot_step(bot) -> {}                  a step before anything else (a crank)
##   bot_task(bot) -> {}                  the tower's own task's next step
##   bot_grid(astar, bot)                 costs and walls on the bot's grid
##   bot_avoid() -> [tiles]               tiles never to step on
##   bot_steer(pos, d) -> Vector2         the stick, adjusted (the wind)

const Objectives := preload("res://scripts/objectives.gd")

var main


static func carve(_shape: String, size: Vector2i) -> Array:
	var rows: Array = []
	for y in size.y:
		rows.append(".".repeat(size.x))
	return rows


static func shape_corridors(_infos: Array, _links: Array, corridors: Array, _walk: Array) -> Array:
	return corridors


static func shape_plan(_plan: Dictionary, _infos: Array, _links: Array, _floor_num: int, _tower: Dictionary) -> void:
	pass


static func place_task(kind: String, spec: Dictionary, infos: Array, cands: Array, dist: Array, monsters: Array, floor_num: int, _cell: float) -> Dictionary:
	return Objectives.place_spread(kind, spec, infos, cands, dist, monsters, floor_num)


static func scenario_plan(_kind: String, _info: Dictionary, _gates: Array, _floor_num: int, _cell: float) -> Dictionary:
	return {}


func setup(_plan: Dictionary) -> void:
	pass


func clear() -> void:
	pass


func blocks_walking(_t: Vector2i) -> bool:
	return false


func slow_at(_pos: Vector2) -> float:
	return 1.0


func wet(_pos: Vector2) -> bool:
	return false


func sight_k() -> float:
	return 1.0


func is_void(_pos: Vector2) -> bool:
	return false


func reach_live(_solid: PackedByteArray, _size: Vector2i, _doors: Array, _opens: Dictionary) -> void:
	pass


func open_gates() -> void:
	pass


func strike(_from: Vector2, _dir: Vector2, _reach: float, _arc_deg: float) -> void:
	pass


func task_tick(_ob, _delta: float, _p, _hurt: bool) -> void:
	pass


func task_strike(_ob, _from: Vector2, _dir: Vector2, _reach: float, _arc_deg: float) -> void:
	pass


func scenario_begin(_s: Dictionary, _host) -> void:
	pass


func scenario_tick(s: Dictionary, _delta: float, _p, host) -> void:
	host._finish(s, "none")


func scenario_title(_s: Dictionary) -> String:
	return ""


func scenario_status(_s: Dictionary) -> Dictionary:
	return {}


func scenario_goal(_s: Dictionary) -> Vector2:
	return Vector2.INF


func bot_step(_bot) -> Dictionary:
	return {}


func bot_task(_bot) -> Dictionary:
	return {}


func bot_grid(_astar: AStarGrid2D, _bot) -> void:
	pass


func bot_avoid() -> Array:
	return []


func bot_steer(_pos: Vector2, d: Vector2) -> Vector2:
	return d
