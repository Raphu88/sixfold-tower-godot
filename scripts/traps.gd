extends Node2D
## Traps: one kind per tower, set into the floors of rooms and corridors
## between floor 1 and the beast. Every trap warns before it hurts (a glow,
## a click or a rustle) and can be avoided by moving, rolling or, for some,
## jumping. Monsters that wander into them are caught too.
##
## The trap data (names, timings, damage, how they're avoided) lives in KINDS,
## so it's easy to tune or rename. main.gd keeps the floor's traps in
## `main.traps` and owns one of these nodes (`main.trap_view`), which runs
## and draws them.
##
## A trap is a dictionary: {pos, kind, state, timer, hidden, hit}
##   state: "idle" (waiting), "warn" (glowing, clicked or rustling: get off!),
##          "fire" (hurting), "rest" (spent for a moment)
##
## Two ways to go off:
##   "timed": idle -> warn -> fire -> idle, over and over, on a cycle
##   "plate": idle until someone steps on it, then warn -> fire -> rest -> idle
## Some traps are hidden: hard to see until they warn, unless the climber has
## the Hunter's Keen Eyes.

const Floors := preload("res://scripts/floors.gd")
const EnemyScript := preload("res://scripts/enemy.gd")

## Which trap each tower uses.
const BY_TOWER := {
	"gryphon": "gust",
	"kraken": "sluice",
	"wyvern": "flame",
	"manticore": "spikes",
	"firebird": "ember",
	"chimera": "thorns",
}

## The trap kinds. Times are in seconds, damage in health.
## avoid: what keeps you safe when it fires (besides being off it)
##   "roll" (the roll's untouchable moment), "jump" (being in the air)
const KINDS := {
	"gust": {
		"name": "gust vent", "trigger": "timed", "cycle": 3.2, "warn": 0.8, "fire": 0.25,
		"r": 20.0, "reach": 58.0, "damage": 4.0, "push": 560.0, "avoid": ["roll"],
		"hidden_chance": 0.3, "color": Color(0.78, 0.9, 1.0), "text": "Gust!",
	},
	"sluice": {
		"name": "sluice grate", "trigger": "timed", "cycle": 3.6, "warn": 0.9, "fire": 0.45,
		"r": 20.0, "reach": 34.0, "damage": 7.0, "push": 300.0, "slow": 0.5, "slow_t": 1.8,
		"avoid": ["roll"], "hidden_chance": 0.3, "color": Color(0.45, 0.85, 0.95), "text": "Drenched",
	},
	"flame": {
		"name": "flame vent", "trigger": "timed", "cycle": 3.0, "warn": 0.9, "fire": 1.1,
		"r": 20.0, "reach": 30.0, "damage": 10.0, "push": 0.0, "avoid": ["roll"],
		"hidden_chance": 0.2, "color": Color(1.0, 0.55, 0.22), "text": "Burned",
	},
	"spikes": {
		"name": "spike plate", "trigger": "plate", "warn": 0.4, "fire": 0.6, "rest": 1.4,
		"r": 20.0, "reach": 26.0, "damage": 12.0, "push": 0.0, "avoid": ["roll", "jump"],
		"hidden_chance": 0.6, "color": Color(0.9, 0.82, 0.62), "text": "Spikes!",
	},
	"ember": {
		"name": "ember vent", "trigger": "timed", "cycle": 3.6, "warn": 1.0, "fire": 0.3,
		"r": 20.0, "reach": 44.0, "damage": 8.0, "push": 0.0, "burn_r": 40.0, "burn_t": 2.2,
		"avoid": ["roll", "jump"], "hidden_chance": 0.3, "color": Color(1.0, 0.7, 0.3), "text": "Embers",
	},
	"thorns": {
		"name": "thorn snare", "trigger": "plate", "warn": 0.35, "fire": 0.5, "rest": 2.0,
		"r": 20.0, "reach": 26.0, "damage": 5.0, "push": 0.0, "root": 1.3,
		"avoid": ["roll", "jump"], "hidden_chance": 0.6, "color": Color(0.6, 0.85, 0.4), "text": "Snared",
	},
}

var main
var show_all := false  # dev tool: draw every trap's outline
var root_t := 0.0  # the climber is held by a thorn snare (roll to break free)
var slow_t := 0.0  # the climber is slowed by a sluice's water
var slow_mult := 1.0


# --- placement ---------------------------------------------------------------

## 1-3 traps of the tower's kind for a floor of rooms (none on floor 1 or the
## beast's floor). Traps go in the rooms beyond the first and in corridors,
## never on the start, the stair, a chasm, a pillar, a monster or a wall.
## `main` (optional) is used to check for walls once the layout is built.
static func place(plan: Dictionary, tower: Dictionary, floor_num: int, main = null) -> Array:
	var list: Array = []
	var rooms: Array = plan.get("rooms", [])
	if floor_num <= 1 or rooms.size() < 2 or plan.get("summit", false):
		return list
	var kind: String = BY_TOWER.get(_tower_id(tower), "")
	if kind == "":
		return list
	var walk: Array = plan.get("walk", [])
	var areas: Array = rooms.slice(1)
	areas.append_array(walk.slice(rooms.size()))  # the corridors
	var start: Vector2 = plan.get("start", Vector2.ZERO)
	var stair: Vector2 = plan.get("stair", Vector2.ZERO)
	var want := 1 + randi() % 3
	for i in want:
		# The first trap tries harder: every floor of rooms gets at least one.
		for attempt in (200 if list.is_empty() else 40):
			var area: Rect2 = areas[randi() % areas.size()]
			var inner := area.grow(-Floors.CELL * 0.5)
			if inner.size.x <= 0.0 or inner.size.y <= 0.0:
				continue
			# On the tile grid: a trap is one tile of the floor.
			var pos := inner.position + Vector2(randf() * inner.size.x, randf() * inner.size.y)
			pos = (pos / Floors.CELL).floor() * Floors.CELL + Vector2.ONE * Floors.CELL * 0.5
			if spot_ok(pos, plan, list, main):
				list.append(make(pos, kind, randf() < float(KINDS[kind]["hidden_chance"]), floor_num))
				break
	return list


## Whether a trap may sit here.
static func spot_ok(pos: Vector2, plan: Dictionary, others: Array, main = null) -> bool:
	var rooms: Array = plan.get("rooms", [])
	if not rooms.is_empty() and rooms[0].grow(30.0).has_point(pos):
		return false  # never in the first room (or the corridor's mouth into it)
	if pos.distance_to(plan.get("start", Vector2(-9999, -9999))) < 120.0:
		return false
	if pos.distance_to(plan.get("stair", Vector2(-9999, -9999))) < 90.0:
		return false
	for c in plan.get("chasms", []):
		if c.grow(40.0).has_point(pos):
			return false
	for p in plan.get("pillars", []):
		if pos.distance_to(p["pos"]) < p["r"] + 36.0:
			return false
	for m in plan.get("monsters", []):
		if pos.distance_to(m[1]) < 50.0:
			return false
	for o in others:
		if pos.distance_to(o["pos"]) < 140.0:
			return false
	# The whole tile and a step around it must be open floor.
	var walk: Array = plan.get("walk", [])
	for off in [Vector2.ZERO, Vector2(-30, -30), Vector2(30, -30), Vector2(-30, 30), Vector2(30, 30)]:
		var at: Vector2 = pos + off
		if main != null and main.is_solid(at):
			return false
		if not walk.is_empty():
			var inside := false
			for w in walk:
				inside = inside or w.has_point(at)
			if not inside:
				return false
	return true


## A new trap. `hidden` traps are hard to see (Keen Eyes sees them).
static func make(pos: Vector2, kind: String, hidden := false, floor_num := 2) -> Dictionary:
	var k: Dictionary = KINDS[kind]
	var tr := {"pos": pos, "kind": kind, "state": "idle", "timer": 0.0, "hidden": hidden,
		"hit": [], "dmg": float(k["damage"]) * (1.0 + 0.06 * maxf(floor_num - 2, 0))}
	if k["trigger"] == "timed":
		tr["timer"] = randf_range(0.6, float(k["cycle"]))  # out of step with each other
	return tr


static func _tower_id(tower: Dictionary) -> String:
	for id in BY_TOWER:
		if tower.get("beast_kind", "") == id:
			return id
	return ""


# --- running -----------------------------------------------------------------

## Called every physics frame by main.gd.
func tick(delta: float) -> void:
	if main == null:
		return
	var p = main.player
	for tr in main.traps:
		_tick_trap(tr, delta)
	# The climber's own state: a snare holds you (a roll breaks free), water slows.
	if p != null:
		if p.roll_t > 0.0 and root_t > 0.0:
			root_t = 0.0
			main.fx_text(p.global_position + Vector2(0, -36), "Broke free", Color(0.6, 0.85, 0.4))
		root_t -= delta
		slow_t -= delta
		var mult := 1.0
		if slow_t > 0.0 and not p.has_bond("sandshaper") and not p.has_bond("tidecaller"):
			mult = slow_mult
		if root_t > 0.0:
			mult = 0.0
		p.trap_slow = mult
	queue_redraw()


## Clears the climber's snare and slow (a new floor).
func reset() -> void:
	root_t = 0.0
	slow_t = 0.0
	if main != null and main.player != null:
		main.player.trap_slow = 1.0


func _tick_trap(tr: Dictionary, delta: float) -> void:
	var k: Dictionary = KINDS[tr["kind"]]
	tr["timer"] -= delta
	match tr["state"]:
		"idle":
			if k["trigger"] == "timed":
				if tr["timer"] <= 0.0:
					_set_state(tr, "warn", k["warn"])
			elif _stepped_on(tr):
				_set_state(tr, "warn", k["warn"])
				_warn_sound(tr)
		"warn":
			if k["trigger"] == "timed" and fmod(tr["timer"], 0.3) < delta:
				_warn_sound(tr)
			if tr["timer"] <= 0.0:
				_set_state(tr, "fire", k["fire"])
				tr["hit"] = []
				_fire_effects(tr)
		"fire":
			_hurt_inside(tr)
			if tr["timer"] <= 0.0:
				if k["trigger"] == "timed":
					_set_state(tr, "idle", float(k["cycle"]) - float(k["warn"]) - float(k["fire"]))
				else:
					_set_state(tr, "rest", k["rest"])
		"rest":
			if tr["timer"] <= 0.0:
				_set_state(tr, "idle", 0.0)


func _set_state(tr: Dictionary, state: String, t: float) -> void:
	tr["state"] = state
	tr["timer"] = t


## A pressure plate is set off by the climber's feet (not in the air) or a
## walking monster's.
func _stepped_on(tr: Dictionary) -> bool:
	var reach: float = KINDS[tr["kind"]]["r"]
	var p = main.player
	if p != null and not p.dead and not p.in_air() and p.global_position.distance_to(tr["pos"]) < reach + p.radius * 0.4:
		return true
	for e in _foes():
		if _walks(e) and e.global_position.distance_to(tr["pos"]) < reach + e.radius * 0.4:
			return true
	return false


## Monsters still in the fight (not ones already on their way out).
func _foes() -> Array:
	return main.enemies().filter(func(e): return not e.is_queued_for_deletion())


## Walking monsters (not fliers, nor one under the water or lifted).
func _walks(e) -> bool:
	return not e.kind in EnemyScript.FLIERS and not e.submerged and e.airborne <= 0.0


func _warn_sound(tr: Dictionary) -> void:
	if not _heard(tr):
		return
	match tr["kind"]:
		"spikes":
			main.sfx("glint", 0.6, -4.0, 0.0)  # the click
		"thorns":
			main.sfx("roll", 0.7, -8.0)  # a rustle
		"flame", "ember":
			main.sfx("burn", 0.8, -14.0)
		"sluice":
			main.sfx("hit_slime", 0.6, -14.0)
		"gust":
			main.sfx("gust", 0.7, -14.0)


## Only traps near the climber make noise.
func _heard(tr: Dictionary) -> bool:
	return main.player != null and main.player.global_position.distance_to(tr["pos"]) < 420.0


func _fire_effects(tr: Dictionary) -> void:
	var k: Dictionary = KINDS[tr["kind"]]
	var col: Color = k["color"]
	var pos: Vector2 = tr["pos"]
	if not _heard(tr):
		return
	match tr["kind"]:
		"gust":
			main.fx_ring(pos, col, k["reach"], 0.3, 4.0)
			main.sfx("gust", 1.0, -6.0)
		"sluice":
			main.fx_burst(pos, Vector2.ZERO, col, 14, 220.0)
			main.fx_ring(pos, col, k["reach"], 0.3, 3.0)
			main.sfx("hit_slime", 0.8, -6.0)
		"flame":
			main.light_flash(pos, col, 0.9, 1.4, k["fire"])
			main.sfx("burn", 1.0, -6.0)
		"spikes":
			main.fx_burst(pos, Vector2.ZERO, col, 8, 140.0)
			main.sfx("hit_armor", 1.3, -6.0)
		"ember":
			main.fx_burst(pos, Vector2.ZERO, col, 16, 260.0)
			main.light_flash(pos, col, 1.0, 1.6, 0.3)
			main.sfx("burn", 0.9, -4.0)
		"thorns":
			main.fx_burst(pos, Vector2.ZERO, col, 10, 160.0)
			main.sfx("hit", 0.7, -6.0)
	# Ember vents leave the floor burning around them (jump over it).
	if tr["kind"] == "ember":
		main.add_flame(pos, k["burn_r"], k["burn_t"])


## While a trap fires: everyone on it is caught, once per firing.
func _hurt_inside(tr: Dictionary) -> void:
	var k: Dictionary = KINDS[tr["kind"]]
	var reach: float = k["reach"]
	var avoid: Array = k["avoid"]
	var p = main.player
	if p != null and not p.dead and not tr["hit"].has(p.get_instance_id()):
		if p.global_position.distance_to(tr["pos"]) < reach + p.radius * 0.5:
			var safe: bool = ("roll" in avoid and p.iframes > 0.0) or ("jump" in avoid and p.in_air())
			if safe:
				if p.iframes > 0.0:
					p.on_dodge()
				tr["hit"].append(p.get_instance_id())  # dodged this firing
			else:
				tr["hit"].append(p.get_instance_id())
				_catch_player(tr, k)
	for e in _foes():
		if tr["hit"].has(e.get_instance_id()):
			continue
		if e.global_position.distance_to(tr["pos"]) >= reach + e.radius * 0.5:
			continue
		# Spikes and snares only catch feet; water and fire catch everyone near.
		if tr["kind"] in ["spikes", "thorns", "sluice"] and not _walks(e):
			continue
		if e.submerged:
			continue
		tr["hit"].append(e.get_instance_id())
		_catch_enemy(tr, k, e)


func _catch_player(tr: Dictionary, k: Dictionary) -> void:
	var p = main.player
	var away: Vector2 = p.global_position - tr["pos"]
	away = away.normalized() if away.length() > 1.0 else Vector2.from_angle(randf() * TAU)
	p.receive_attack(tr["dmg"], null, true)
	main.fx_text(p.global_position + Vector2(0, -44), k["text"], k["color"])
	if float(k["push"]) > 0.0 and not p.has_bond("sandshaper"):  # Rooted Stance
		p.knock = away * float(k["push"])
	if k.has("slow"):
		slow_t = k["slow_t"]
		slow_mult = k["slow"]
	if k.has("root") and not p.dead:
		root_t = k["root"]


func _catch_enemy(tr: Dictionary, k: Dictionary, e) -> void:
	var away: Vector2 = e.global_position - tr["pos"]
	away = away.normalized() if away.length() > 1.0 else Vector2.from_angle(randf() * TAU)
	var force: float = k["push"]
	e.take_hit(tr["dmg"], away if force > 0.0 else Vector2.ZERO, force)
	if e.dead:
		return
	if k.has("slow"):
		e.cripple_t = maxf(e.cripple_t, float(k["slow_t"]))
	if k.has("root"):
		e.stun = maxf(e.stun, float(k["root"]))


# --- what the climber can see -------------------------------------------------

## How visible a trap is while it waits: hidden ones are faint unless the
## climber has Keen Eyes (the Hunter's Body) or the dev tool shows them all.
func visibility(tr: Dictionary) -> float:
	if tr["state"] != "idle" and tr["state"] != "rest":
		return 1.0  # a warning always shows
	if not tr["hidden"] or show_all:
		return 1.0
	if main != null and main.player != null and main.player.has_bond("hunter"):
		return 1.0
	return 0.14


## Whether the climber can see this trap clearly right now.
func seen(tr: Dictionary) -> bool:
	return visibility(tr) >= 1.0


# --- drawing -------------------------------------------------------------------

func _ready() -> void:
	z_index = -5  # on the floor: over the room, under everyone
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = unlit


func _draw() -> void:
	if main == null:
		return
	var t := Time.get_ticks_msec() * 0.001
	var keen: bool = main.player != null and main.player.has_bond("hunter")
	for tr in main.traps:
		var k: Dictionary = KINDS[tr["kind"]]
		var pos: Vector2 = tr["pos"]
		var col: Color = k["color"]
		var a := visibility(tr)
		var half := Floors.CELL * 0.5 - 3.0
		var tile := Rect2(pos - Vector2(half, half), Vector2(half, half) * 2.0)
		# The plate itself: a darker tile with a rim.
		draw_rect(tile, Color(0.05, 0.045, 0.06, 0.55 * a))
		draw_rect(tile, Color(col.darkened(0.45), 0.7 * a), false, 1.5)
		_draw_face(tr, pos, half, col, a, t)
		# Keen Eyes (or the dev tool) outlines traps that would be hidden.
		if tr["hidden"] and (keen or show_all) and tr["state"] == "idle":
			var pulse := 0.5 + 0.3 * sin(t * 3.0)
			draw_rect(tile.grow(3.0), Color(0.95, 0.8, 0.5, pulse), false, 1.5)
		if show_all:
			draw_arc(pos, k["reach"], 0.0, TAU, 32, Color(col, 0.5), 1.0)
		var state: String = tr["state"]
		if state == "warn":
			var dur: float = maxf(float(k["warn"]), 0.01)
			var prog := clampf(1.0 - tr["timer"] / dur, 0.0, 1.0)
			# A glow that brightens toward the moment it fires, and the reach it will hit.
			draw_circle(pos, k["reach"], Color(col, 0.10 + 0.22 * prog))
			draw_arc(pos, k["reach"], 0.0, TAU, 32, Color(col, 0.5 + 0.5 * prog), 2.0)
			draw_arc(pos, k["reach"] * (1.0 - prog) + 4.0, 0.0, TAU, 24, Color(1, 1, 1, 0.6), 1.5)
		elif state == "fire":
			_draw_firing(tr, pos, col, t)
	# A climber caught in a snare: vines around the feet.
	if root_t > 0.0 and main.player != null:
		var pp: Vector2 = main.player.global_position
		draw_arc(pp + Vector2(0, 6), 14.0, 0.0, TAU, 16, Color(0.45, 0.7, 0.3, 0.9), 3.0)


## The tile's markings, by kind.
func _draw_face(tr: Dictionary, pos: Vector2, half: float, col: Color, a: float, t: float) -> void:
	var line := Color(col.darkened(0.25), 0.75 * a)
	match tr["kind"]:
		"gust", "sluice", "flame", "ember":
			# A grate: slats across the tile.
			for i in 4:
				var y := -half + 6.0 + i * (half * 2.0 - 12.0) / 3.0
				draw_line(pos + Vector2(-half + 5.0, y), pos + Vector2(half - 5.0, y), line, 2.0)
			if tr["kind"] == "gust":
				var sw := t * 2.0
				draw_arc(pos, 8.0, sw, sw + 4.0, 12, Color(col, 0.5 * a), 1.5)
		"spikes":
			for x in 3:
				for y in 3:
					draw_circle(pos + Vector2(x - 1, y - 1) * 11.0, 2.0, line)
		"thorns":
			for i in 5:
				var ang := TAU * i / 5.0 + 0.4
				draw_line(pos + Vector2.from_angle(ang) * 3.0, pos + Vector2.from_angle(ang + 0.5) * (half - 3.0), line, 1.5)


func _draw_firing(tr: Dictionary, pos: Vector2, col: Color, t: float) -> void:
	var k: Dictionary = KINDS[tr["kind"]]
	var reach: float = k["reach"]
	match tr["kind"]:
		"gust":
			for i in 8:
				var ang := TAU * i / 8.0 + t * 6.0
				draw_line(pos + Vector2.from_angle(ang) * 12.0, pos + Vector2.from_angle(ang + 0.3) * reach, Color(col, 0.7), 2.0)
		"sluice":
			draw_circle(pos, reach, Color(col, 0.35))
			for i in 7:
				var ang := TAU * i / 7.0 + t * 3.0
				draw_circle(pos + Vector2.from_angle(ang) * reach * 0.6, 5.0, Color(0.85, 0.97, 1.0, 0.8))
		"flame":
			draw_circle(pos, reach, Color(col, 0.4))
			for i in 6:
				var ang := TAU * i / 6.0 + t * 5.0
				var h := 18.0 + 10.0 * sin(t * 20.0 + i)
				draw_line(pos + Vector2.from_angle(ang) * 6.0, pos + Vector2.from_angle(ang) * 6.0 + Vector2(0, -h), Color(1.0, 0.8, 0.35, 0.85), 4.0)
			draw_circle(pos, 10.0, Color(1.0, 0.92, 0.6, 0.9))
		"spikes":
			for x in 3:
				for y in 3:
					var b: Vector2 = pos + Vector2(x - 1, y - 1) * 11.0
					draw_colored_polygon(PackedVector2Array([b + Vector2(-4, 3), b + Vector2(4, 3), b + Vector2(0, -12)]), Color(0.86, 0.86, 0.9))
		"ember":
			draw_circle(pos, reach, Color(col, 0.3))
			draw_arc(pos, reach, 0.0, TAU, 32, Color(1.0, 0.85, 0.5, 0.9), 3.0)
		"thorns":
			for i in 7:
				var ang := TAU * i / 7.0
				draw_line(pos + Vector2.from_angle(ang) * 4.0, pos + Vector2.from_angle(ang + 0.35) * reach, Color(0.45, 0.7, 0.3, 0.95), 3.0)
