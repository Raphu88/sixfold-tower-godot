extends Node2D
## Traps: the beast's tests set into the floors between floor 1 and the
## summit. Each tower has its own kind, and they're laid out as SET PIECES
## at chokepoints (corridors, doorways), not scattered tiles:
##   gust lanes and flame jets fire ACROSS a corridor in a wave,
##   sluice sweeps roll ALONG it, spike fields alternate in a checkerboard,
##   ember mortars land in a row, bramble patches snare and wake the pack.
## Hidden plates (and gas vents) can be anywhere, but every trap warns when
## it's about to go off: a glow, then a GLINT (the same star and "ting" as a
## monster's hit) a moment before it fires. Getting hit is the climber's own
## fault, so traps hurt.
##
## The trap data (names, timings, damage, shapes) lives in KINDS, so it's easy
## to tune or rename. main.gd keeps the floor's traps in `main.traps` and owns
## one of these nodes (`main.trap_view`), which runs and draws them.
##
## A trap is a dictionary:
##   {pos, kind, state, timer, hidden, hit, dmg, dir, len, trigger, dodged, glint}
##   pos:   its tile (for a lane, the nozzle end)
##   dir:   which way a lane points; len: how many tiles it covers
##   state: "idle", "warn" (glowing: get off!), "fire" (hurting), "rest"
##
## Two ways to go off:
##   "timed": idle -> warn -> fire -> idle, on a cycle shared by its set piece
##   "plate": idle until someone steps on it, then warn -> fire -> rest -> idle

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
## Towers that also hide gas vents among their plates.
const GAS_TOWERS := ["manticore", "chimera"]

## The glint: a star and a "ting" this long before a trap fires.
const GLINT_LEAD := 0.25
## How far apart two set pieces must be.
const SET_SPACING := 220.0

## The trap kinds. Times are in seconds, damage in health (the climber has 140).
## shape: "lane" (a strip `len` tiles long from the nozzle along `dir`) or
##        "circle" (everything within `reach` of the tile)
## avoid: what keeps you safe when it fires (besides being out of it)
##   "roll" (the roll's untouchable moment), "jump" (being in the air)
## tick:  hurts again every `tick` seconds while it fires (gas)
const KINDS := {
	"gust": {
		"name": "gust lane", "trigger": "timed", "cycle": 3.2, "warn": 0.8, "fire": 0.3,
		"shape": "lane", "len": 4, "r": 20.0, "reach": 20.0, "damage": 10.0, "push": 620.0,
		"avoid": ["roll"], "hidden_chance": 0.1, "color": Color(0.78, 0.9, 1.0), "text": "Gust!",
	},
	"sluice": {
		"name": "sluice sweep", "trigger": "timed", "cycle": 3.6, "warn": 0.9, "fire": 0.45,
		"shape": "lane", "len": 5, "r": 20.0, "reach": 20.0, "damage": 20.0, "push": 380.0,
		"slow": 0.5, "slow_t": 1.8, "avoid": ["roll"], "hidden_chance": 0.1,
		"color": Color(0.45, 0.85, 0.95), "text": "Drenched",
	},
	"flame": {
		"name": "flame jet", "trigger": "timed", "cycle": 3.0, "warn": 0.9, "fire": 1.0,
		"shape": "lane", "len": 3, "r": 20.0, "reach": 20.0, "damage": 28.0, "push": 0.0,
		"avoid": ["roll"], "hidden_chance": 0.1, "color": Color(1.0, 0.55, 0.22), "text": "Burned",
	},
	"spikes": {
		"name": "spike plate", "trigger": "plate", "cycle": 2.6, "warn": 0.5, "fire": 0.6, "rest": 1.4,
		"shape": "circle", "r": 20.0, "reach": 26.0, "damage": 26.0, "push": 0.0,
		"avoid": ["roll", "jump"], "hidden_chance": 0.6, "color": Color(0.9, 0.82, 0.62), "text": "Spikes!",
	},
	"ember": {
		"name": "ember mortar", "trigger": "timed", "cycle": 3.6, "warn": 1.0, "fire": 0.3,
		"shape": "circle", "r": 20.0, "reach": 44.0, "damage": 24.0, "push": 0.0,
		"burn_r": 40.0, "burn_t": 2.2, "avoid": ["roll", "jump"], "hidden_chance": 0.1,
		"color": Color(1.0, 0.7, 0.3), "text": "Embers",
	},
	"thorns": {
		"name": "bramble snare", "trigger": "plate", "warn": 0.5, "fire": 0.5, "rest": 2.0,
		"shape": "circle", "r": 20.0, "reach": 26.0, "damage": 18.0, "push": 0.0, "root": 1.3,
		"wake": 300.0, "avoid": ["roll", "jump"], "hidden_chance": 0.5,
		"color": Color(0.6, 0.85, 0.4), "text": "Snared",
	},
	"gas": {
		"name": "gas vent", "trigger": "plate", "warn": 0.5, "fire": 6.0, "rest": 4.0,
		"shape": "circle", "r": 20.0, "reach": 84.0, "damage": 10.0, "tick": 0.5, "push": 0.0,
		"avoid": ["roll"], "hidden_chance": 0.75, "color": Color(0.62, 0.8, 0.3), "text": "Choking!",
	},
}

var main
var show_all := false  # dev tool: draw every trap's outline
var root_t := 0.0  # the climber is held by a thorn snare (roll to break free)
var slow_t := 0.0  # the climber is slowed by a sluice's water
var slow_mult := 1.0


# --- placement ---------------------------------------------------------------

## The traps for a floor of rooms (none on floor 1 or the beast's floor):
## one to three set pieces of the tower's trap at corridors and in rooms, plus
## one or two hidden plates. Never on the start, the stair, a chasm, a pillar,
## a monster or a wall. `main` (optional) checks for walls once the layout is built.
static func place(plan: Dictionary, tower: Dictionary, floor_num: int, main = null) -> Array:
	var list: Array = []
	var rooms: Array = plan.get("rooms", [])
	if floor_num <= 1 or rooms.size() < 2 or plan.get("summit", false):
		return list
	var tid := _tower_id(tower)
	var kind: String = BY_TOWER.get(tid, "")
	if kind == "":
		return list
	var walk: Array = plan.get("walk", [])
	var corridors: Array = walk.slice(rooms.size())
	var inner_rooms: Array = rooms.slice(1)
	var sets := 1 + (1 if floor_num >= 3 else 0) + (randi() % 2 if floor_num >= 4 else 0)
	var centres: Array = []
	for s in sets:
		for attempt in 40:
			var pool: Array = corridors if (not corridors.is_empty() and randf() < 0.7) else inner_rooms
			if pool.is_empty():
				pool = inner_rooms
			var area: Rect2 = pool[randi() % pool.size()]
			var group := _set_piece(kind, area, plan, list, main, floor_num)
			if group.is_empty():
				continue
			var c := _centre(group)
			var far := true
			for o in centres:
				far = far and c.distance_to(o) >= SET_SPACING
			if not far:
				continue
			centres.append(c)
			list.append_array(group)
			break
	# A hidden plate or two, anywhere past the first room.
	var singles := 1 + randi() % 2
	var areas: Array = inner_rooms.duplicate()
	areas.append_array(corridors)
	for i in singles:
		var single_kind := kind
		if KINDS[kind]["trigger"] != "plate":
			single_kind = "gas" if tid in GAS_TOWERS else kind
		elif tid in GAS_TOWERS and randf() < 0.4:
			single_kind = "gas"
		for attempt in 60:
			var area: Rect2 = areas[randi() % areas.size()]
			var pos := _tile_in(area.grow(-Floors.CELL * 0.5))
			if pos == Vector2.INF or not spot_ok(pos, plan, list, main):
				continue
			var tr := make(pos, single_kind, single_kind != kind or randf() < float(KINDS[single_kind]["hidden_chance"]) + 0.3, floor_num)
			if KINDS[single_kind]["shape"] == "lane":
				tr["dir"] = _open_dir(pos, int(KINDS[single_kind]["len"]), plan, main)
			list.append(tr)
			break
	return list


## One set piece of `kind` in `area` (a corridor or a room), or [] if it won't fit.
static func _set_piece(kind: String, area: Rect2, plan: Dictionary, others: Array, main, floor_num: int) -> Array:
	var k: Dictionary = KINDS[kind]
	var C := Floors.CELL
	var horiz := area.size.x >= area.size.y
	var along := Vector2.RIGHT if horiz else Vector2.DOWN
	var across := Vector2.DOWN if horiz else Vector2.RIGHT
	var tiles_long := int(floor((area.size.x if horiz else area.size.y) / C))
	var tiles_wide := int(floor((area.size.y if horiz else area.size.x) / C))
	if tiles_long < 4 or tiles_wide < 2:
		return []
	# A band of the area to fill: 3 tiles wide at most (a corridor is 3).
	var band := mini(tiles_wide, 3)
	var start_w := randi() % (tiles_wide - band + 1)
	var span := mini(tiles_long, 7)
	var start_l := randi() % (tiles_long - span + 1)
	var origin := area.position + Vector2.ONE * C * 0.5
	var at := func(l: int, w: int) -> Vector2:
		return origin + along * C * (start_l + l) + across * C * (start_w + w)
	var group: Array = []
	var cycle := float(k.get("cycle", 3.0))
	var step := 0.35  # a wave: each in turn
	match kind:
		"gust", "flame":
			# Nozzles along one side, firing across the band in a wave.
			var flip := randf() < 0.5
			var n := clampi(span / 2, 2, 4)
			for i in n:
				var pos: Vector2 = at.call(1 + i * 2, band - 1 if flip else 0)
				var tr := make(pos, kind, false, floor_num)
				tr["dir"] = -across if flip else across
				tr["len"] = band
				tr["timer"] = 1.0 + i * step
				group.append(tr)
		"sluice":
			# Waves rolling along two of the band's rows, in turn.
			var back := randf() < 0.5
			var rows: Array = range(band)
			rows.shuffle()
			for i in mini(2, band):
				var w: int = rows[i]
				var pos: Vector2 = at.call(span - 1 if back else 0, w)
				var tr := make(pos, kind, false, floor_num)
				tr["dir"] = -along if back else along
				tr["len"] = mini(span, int(k["len"]))
				tr["timer"] = 1.0 + i * cycle * 0.5
				group.append(tr)
		"spikes":
			# A field: plates in a checkerboard that alternates on the beat.
			var len_f := mini(span, 3 + randi() % 2)
			for l in len_f:
				for w in band:
					var tr := make(at.call(l, w), kind, false, floor_num)
					tr["trigger"] = "timed"
					tr["timer"] = 1.0 + (cycle * 0.5 if (l + w) % 2 == 1 else 0.0)
					group.append(tr)
		"ember":
			# Mortar marks down the band's middle, landing in a wave.
			var n := clampi(span / 2, 2, 3)
			for i in n:
				var tr := make(at.call(i * 2, band / 2), kind, false, floor_num)
				tr["timer"] = 1.0 + i * step * 1.4
				group.append(tr)
		"thorns":
			# A bramble patch: some snares, half of them hidden.
			var cells: Array = []
			for l in mini(span, 4):
				for w in band:
					cells.append(Vector2i(l, w))
			cells.shuffle()
			for i in mini(cells.size(), 4 + randi() % 3):
				var c: Vector2i = cells[i]
				group.append(make(at.call(c.x, c.y), kind, randf() < float(k["hidden_chance"]), floor_num))
	# Every tile must be fair floor, and the set piece clear of other traps.
	for tr in group:
		if not spot_ok(tr["pos"], plan, [], main):
			return []
		for o in others:
			if tr["pos"].distance_to(o["pos"]) < Floors.CELL * 2.5:
				return []
		# A lane may not run into a wall.
		if KINDS[kind]["shape"] == "lane" and main != null:
			for i in int(tr["len"]):
				if main.is_solid(tr["pos"] + tr["dir"] * Floors.CELL * i):
					return []
	return group


static func _centre(group: Array) -> Vector2:
	var c := Vector2.ZERO
	for tr in group:
		c += tr["pos"]
	return c / maxf(group.size(), 1)


## A random tile centre inside a rect, or Vector2.INF if it's too small.
static func _tile_in(r: Rect2) -> Vector2:
	if r.size.x <= 0.0 or r.size.y <= 0.0:
		return Vector2.INF
	var pos := r.position + Vector2(randf() * r.size.x, randf() * r.size.y)
	return (pos / Floors.CELL).floor() * Floors.CELL + Vector2.ONE * Floors.CELL * 0.5


## A direction a lone lane can point without running into a wall.
static func _open_dir(pos: Vector2, length: int, plan: Dictionary, main) -> Vector2:
	var dirs := [Vector2.DOWN, Vector2.UP, Vector2.LEFT, Vector2.RIGHT]
	dirs.shuffle()
	for d in dirs:
		var ok := true
		for i in length:
			var at: Vector2 = pos + d * Floors.CELL * i
			if main != null and main.is_solid(at):
				ok = false
		if ok:
			return d
	return Vector2.DOWN


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
	# The tile must be open floor.
	var walk: Array = plan.get("walk", [])
	for off in [Vector2.ZERO, Vector2(-12, -12), Vector2(12, -12), Vector2(-12, 12), Vector2(12, 12)]:
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


## A new trap. `hidden` traps are hard to see until they warn (Keen Eyes sees them).
static func make(pos: Vector2, kind: String, hidden := false, floor_num := 2) -> Dictionary:
	var k: Dictionary = KINDS[kind]
	var tr := {"pos": pos, "kind": kind, "state": "idle", "timer": 0.0, "hidden": hidden,
		"hit": [], "dmg": float(k["damage"]) * (1.0 + 0.06 * maxf(floor_num - 2, 0)),
		"dir": Vector2.DOWN, "len": int(k.get("len", 1)), "trigger": k["trigger"],
		"dodged": false, "glint": false, "tick_t": 0.0}
	if k["trigger"] == "timed":
		tr["timer"] = 1.0
	return tr


static func _tower_id(tower: Dictionary) -> String:
	for id in BY_TOWER:
		if tower.get("beast_kind", "") == id:
			return id
	return ""


# --- shapes ------------------------------------------------------------------

## The far end of a lane (its nozzle is `pos`).
static func lane_end(tr: Dictionary) -> Vector2:
	return tr["pos"] + tr["dir"] * Floors.CELL * maxf(float(tr["len"]) - 1.0, 0.0)


## How far a circle trap reaches right now (a gas cloud spreads as it starts).
func reach_of(tr: Dictionary) -> float:
	var k: Dictionary = KINDS[tr["kind"]]
	var reach: float = k["reach"]
	if tr["kind"] == "gas" and tr["state"] == "fire":
		var age := float(k["fire"]) - float(tr["timer"])
		reach = lerpf(26.0, reach, clampf(age / 0.7, 0.0, 1.0))
	return reach


## Whether a point (with a body of radius `rad`) is inside a trap's reach.
func touches(tr: Dictionary, point: Vector2, rad: float) -> bool:
	if KINDS[tr["kind"]]["shape"] == "lane":
		var a: Vector2 = tr["pos"]
		var b := lane_end(tr)
		var closest := Geometry2D.get_closest_point_to_segment(point, a, b)
		var d := point - closest
		# A lane is a tile wide: measure across it as a square, not a circle.
		return absf(d.x) < Floors.CELL * 0.5 + rad * 0.5 and absf(d.y) < Floors.CELL * 0.5 + rad * 0.5
	return point.distance_to(tr["pos"]) < reach_of(tr) + rad * 0.5


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
	var trigger: String = tr.get("trigger", k["trigger"])
	tr["timer"] -= delta
	match tr["state"]:
		"idle":
			if trigger == "timed":
				if tr["timer"] <= 0.0:
					_set_state(tr, "warn", k["warn"])
			elif _stepped_on(tr):
				_set_state(tr, "warn", k["warn"])
				_warn_sound(tr)
		"warn":
			if trigger == "timed" and fmod(tr["timer"], 0.3) < delta:
				_warn_sound(tr)
			# The glint: a star and a ting just before it fires.
			if not tr.get("glint", false) and tr["timer"] <= GLINT_LEAD:
				tr["glint"] = true
				if _heard(tr) and visibility(tr) >= 1.0:
					main.sfx("glint", 1.25, -10.0, 0.05)
			if tr["timer"] <= 0.0:
				_set_state(tr, "fire", k["fire"])
				tr["hit"] = []
				tr["tick_t"] = float(k.get("tick", 0.0))
				_fire_effects(tr)
		"fire":
			# Gas keeps hurting whoever stays in it.
			if k.has("tick"):
				tr["tick_t"] -= delta
				if tr["tick_t"] <= 0.0:
					tr["tick_t"] = float(k["tick"])
					tr["hit"] = []
			_hurt_inside(tr)
			if tr["timer"] <= 0.0:
				if trigger == "timed":
					_set_state(tr, "idle", float(k["cycle"]) - float(k["warn"]) - float(k["fire"]))
				else:
					_set_state(tr, "rest", k["rest"])
		"rest":
			if tr["timer"] <= 0.0:
				_set_state(tr, "idle", 0.0)


func _set_state(tr: Dictionary, state: String, t: float) -> void:
	tr["state"] = state
	tr["timer"] = t
	if state == "warn":
		tr["glint"] = false


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
		"gas":
			main.sfx("gust", 0.45, -8.0)  # a hiss


## Only traps near the climber make noise.
func _heard(tr: Dictionary) -> bool:
	return main.player != null and main.player.global_position.distance_to(tr["pos"]) < 420.0


func _fire_effects(tr: Dictionary) -> void:
	var k: Dictionary = KINDS[tr["kind"]]
	var col: Color = k["color"]
	var pos: Vector2 = tr["pos"]
	# Ember mortars leave the floor burning around them (jump over it).
	if tr["kind"] == "ember":
		main.add_flame(pos, k["burn_r"], k["burn_t"])
	if not _heard(tr):
		return
	var mid: Vector2 = (pos + lane_end(tr)) * 0.5 if k["shape"] == "lane" else pos
	match tr["kind"]:
		"gust":
			main.sfx("gust", 1.0, -6.0)
		"sluice":
			main.fx_burst(lane_end(tr), tr["dir"] * 120.0, col, 10, 160.0)
			main.sfx("hit_slime", 0.8, -6.0)
		"flame":
			main.light_flash(mid, col, 0.9, 1.4, k["fire"])
			main.sfx("burn", 1.0, -6.0)
		"spikes":
			main.fx_burst(pos, Vector2.ZERO, col, 6, 120.0)
			main.sfx("hit_armor", 1.3, -8.0)
		"ember":
			main.fx_burst(pos, Vector2.ZERO, col, 16, 260.0)
			main.light_flash(pos, col, 1.0, 1.6, 0.3)
			main.sfx("burn", 0.9, -4.0)
		"thorns":
			main.fx_burst(pos, Vector2.ZERO, col, 10, 160.0)
			main.sfx("hit", 0.7, -6.0)
		"gas":
			main.fx_burst(pos, Vector2.ZERO, col, 14, 90.0)
			main.sfx("gust", 0.5, -4.0)


## While a trap fires: everyone in it is caught, once per firing (or per tick, for gas).
func _hurt_inside(tr: Dictionary) -> void:
	var k: Dictionary = KINDS[tr["kind"]]
	var avoid: Array = k["avoid"]
	var p = main.player
	if p != null and not p.dead and not tr["hit"].has(p.get_instance_id()):
		if touches(tr, p.global_position, p.radius):
			var safe: bool = ("roll" in avoid and p.iframes > 0.0) or ("jump" in avoid and p.in_air())
			tr["hit"].append(p.get_instance_id())
			if safe:
				# Dodging a trap feeds the legs, but only once per trap (no farming).
				if p.iframes > 0.0 and not tr.get("dodged", false):
					tr["dodged"] = true
					p.on_dodge()
			else:
				_catch_player(tr, k)
	for e in _foes():
		if tr["hit"].has(e.get_instance_id()):
			continue
		if not touches(tr, e.global_position, e.radius):
			continue
		# Spikes and snares only catch feet; water, fire and gas catch everyone near.
		if tr["kind"] in ["spikes", "thorns", "sluice"] and not _walks(e):
			continue
		if e.submerged:
			continue
		tr["hit"].append(e.get_instance_id())
		_catch_enemy(tr, k, e)


## Which way a trap shoves: along a lane, or away from a circle's middle.
func _push_dir(tr: Dictionary, at: Vector2) -> Vector2:
	if KINDS[tr["kind"]]["shape"] == "lane":
		return tr["dir"]
	var away: Vector2 = at - tr["pos"]
	return away.normalized() if away.length() > 1.0 else Vector2.from_angle(randf() * TAU)


func _catch_player(tr: Dictionary, k: Dictionary) -> void:
	var p = main.player
	var away := _push_dir(tr, p.global_position)
	p.receive_attack(tr["dmg"], null, true)
	main.fx_text(p.global_position + Vector2(0, -44), k["text"], k["color"])
	if float(k["push"]) > 0.0 and not p.has_bond("sandshaper"):  # Rooted Stance
		p.knock = away * float(k["push"])
	if k.has("slow"):
		slow_t = k["slow_t"]
		slow_mult = k["slow"]
	if k.has("root") and not p.dead:
		root_t = k["root"]
	# A snare's rustle wakes the pack nearby: the ambush is lost.
	if k.has("wake"):
		for e in _foes():
			if not e.aware and e.global_position.distance_to(tr["pos"]) < float(k["wake"]):
				e.wake()


func _catch_enemy(tr: Dictionary, k: Dictionary, e) -> void:
	var away := _push_dir(tr, e.global_position)
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


## The strip of floor a lane covers.
func _lane_rect(tr: Dictionary) -> Rect2:
	var a: Vector2 = tr["pos"]
	var b := lane_end(tr)
	var half := Floors.CELL * 0.5
	return Rect2(a.min(b) - Vector2(half, half), (b - a).abs() + Vector2(half, half) * 2.0)


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
		var lane: bool = k["shape"] == "lane"
		var half := Floors.CELL * 0.5 - 3.0
		var tile := Rect2(pos - Vector2(half, half), Vector2(half, half) * 2.0)
		var state: String = tr["state"]
		# The reach, engraved on the floor (visible traps only).
		if a >= 1.0 and state in ["idle", "rest"]:
			if lane:
				var lr := _lane_rect(tr).grow(-4.0)
				draw_rect(lr, Color(col, 0.07))
				draw_rect(lr, Color(col, 0.28), false, 1.0)
				# Chevrons pointing the way it fires.
				for i in range(1, int(tr["len"])):
					var c: Vector2 = pos + tr["dir"] * Floors.CELL * i
					var side: Vector2 = tr["dir"].orthogonal() * 7.0
					var tip: Vector2 = c + tr["dir"] * 5.0
					draw_polyline(PackedVector2Array([c - tr["dir"] * 3.0 + side, tip, c - tr["dir"] * 3.0 - side]), Color(col, 0.35), 1.5)
			elif tr["kind"] != "spikes" and tr["kind"] != "thorns":
				draw_arc(pos, reach_of(tr), 0.0, TAU, 32, Color(col, 0.22), 1.0)
		# The tile itself: a darker plate or nozzle with a rim.
		draw_rect(tile, Color(0.05, 0.045, 0.06, 0.55 * a))
		draw_rect(tile, Color(col.darkened(0.45), 0.7 * a), false, 1.5)
		_draw_face(tr, pos, half, col, a, t)
		# Keen Eyes (or the dev tool) outlines traps that would be hidden.
		if tr["hidden"] and (keen or show_all) and state == "idle":
			var pulse := 0.5 + 0.3 * sin(t * 3.0)
			draw_rect(tile.grow(3.0), Color(0.95, 0.8, 0.5, pulse), false, 1.5)
		if show_all and not lane:
			draw_arc(pos, k["reach"], 0.0, TAU, 32, Color(col, 0.5), 1.0)
		if state == "warn":
			var dur: float = maxf(float(k["warn"]), 0.01)
			var prog := clampf(1.0 - tr["timer"] / dur, 0.0, 1.0)
			# A glow that brightens toward the moment it fires, over all it will hit.
			if lane:
				var lr := _lane_rect(tr).grow(-2.0)
				draw_rect(lr, Color(col, 0.10 + 0.25 * prog))
				draw_rect(lr, Color(col, 0.5 + 0.5 * prog), false, 2.0)
			else:
				var reach := reach_of(tr)
				draw_circle(pos, reach, Color(col, 0.10 + 0.22 * prog))
				draw_arc(pos, reach, 0.0, TAU, 32, Color(col, 0.5 + 0.5 * prog), 2.0)
				draw_arc(pos, reach * (1.0 - prog) + 4.0, 0.0, TAU, 24, Color(1, 1, 1, 0.6), 1.5)
			# The glint: a white star on the tile in the last moment.
			if tr["timer"] <= GLINT_LEAD:
				var g := 1.0 - clampf(tr["timer"] / GLINT_LEAD, 0.0, 1.0)
				var s := 6.0 + 10.0 * g
				var star := Color(1, 1, 1, 0.95)
				draw_line(pos + Vector2(-s, 0), pos + Vector2(s, 0), star, 2.0)
				draw_line(pos + Vector2(0, -s), pos + Vector2(0, s), star, 2.0)
				draw_circle(pos, 3.0, star)
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
		"gust", "sluice", "flame":
			# A nozzle: slats across it, facing the way it fires.
			var d: Vector2 = tr["dir"]
			var side := d.orthogonal()
			for i in 3:
				var off := (i - 1) * (half - 6.0) * 0.8
				draw_line(pos + side * (half - 5.0) + d * off, pos - side * (half - 5.0) + d * off, line, 2.0)
			draw_circle(pos + d * (half - 4.0), 3.0, Color(col, 0.6 * a))
			if tr["kind"] == "gust":
				var sw := t * 2.0
				draw_arc(pos, 8.0, sw, sw + 4.0, 12, Color(col, 0.5 * a), 1.5)
		"ember":
			# A mortar mark: a ring and a cross.
			draw_arc(pos, half - 4.0, 0.0, TAU, 20, line, 2.0)
			draw_line(pos + Vector2(-6, 0), pos + Vector2(6, 0), line, 2.0)
			draw_line(pos + Vector2(0, -6), pos + Vector2(0, 6), line, 2.0)
		"spikes":
			for x in 3:
				for y in 3:
					draw_circle(pos + Vector2(x - 1, y - 1) * 11.0, 2.0, line)
		"thorns":
			for i in 5:
				var ang := TAU * i / 5.0 + 0.4
				draw_line(pos + Vector2.from_angle(ang) * 3.0, pos + Vector2.from_angle(ang + 0.5) * (half - 3.0), line, 1.5)
		"gas":
			for i in 3:
				draw_circle(pos + Vector2.from_angle(TAU * i / 3.0 + 0.5) * 7.0, 3.0, line)


func _draw_firing(tr: Dictionary, pos: Vector2, col: Color, t: float) -> void:
	var k: Dictionary = KINDS[tr["kind"]]
	var reach := reach_of(tr)
	var d: Vector2 = tr["dir"]
	var lane_r := _lane_rect(tr)
	match tr["kind"]:
		"gust":
			draw_rect(lane_r, Color(col, 0.18))
			for i in 6:
				var side: Vector2 = d.orthogonal() * ((i - 2.5) * 5.0)
				var along := fmod(t * 600.0 + i * 37.0, Floors.CELL * float(tr["len"]))
				var a2: Vector2 = pos + side + d * along
				draw_line(a2, a2 + d * 18.0, Color(col, 0.75), 2.0)
		"sluice":
			draw_rect(lane_r, Color(col, 0.35))
			var front := clampf(1.0 - tr["timer"] / float(k["fire"]), 0.0, 1.0)
			var f: Vector2 = pos + d * Floors.CELL * (float(tr["len"]) - 1.0) * front
			draw_circle(f, 16.0, Color(0.85, 0.97, 1.0, 0.8))
		"flame":
			draw_rect(lane_r, Color(col, 0.45))
			for i in int(tr["len"]) * 3:
				var c: Vector2 = pos + d * (i * Floors.CELL / 3.0)
				var flick := 8.0 + 4.0 * sin(t * 18.0 + i)
				draw_circle(c, flick, Color(1.0, 0.8, 0.35, 0.8))
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
		"gas":
			# A drifting cloud: soft overlapping puffs, thinning as it ends.
			var fade := clampf(tr["timer"] / 1.0, 0.0, 1.0)
			draw_circle(pos, reach, Color(col, 0.22 * fade))
			for i in 7:
				var ang := TAU * i / 7.0 + t * 0.4
				var r := reach * (0.45 + 0.15 * sin(t * 1.3 + i))
				draw_circle(pos + Vector2.from_angle(ang) * r, reach * 0.42, Color(col.darkened(0.1), 0.16 * fade))
			draw_arc(pos, reach, 0.0, TAU, 40, Color(col, 0.5 * fade), 1.5)
