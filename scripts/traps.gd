extends Node2D
## Traps: the beast's tests set into the floors between floor 1 and the
## summit. They're laid out ON PURPOSE, never scattered:
##   * each TRAP ROOM (a room whose theme in themes.gd has feature "trap")
##     gets its theme's set piece, built out of the room's own shape: rows
##     across its short side, slots in its two long walls, vents at its two
##     ends, and so on (see "set pieces" below and the README's table);
##   * spikes GUARD things that matter: a ring around the cache's urn;
##   * one or two spike patches sit in corridors (no more);
##   * a few hidden plates can be anywhere but on a door itself.
## Traps MAY block the way: a set piece can span a corridor or a doorway so
## you must cross it, and from floor 4 monsters wait among them. The
## PROTECTION PASS keeps the start, the stair, the doors themselves, the
## puzzle room and the good rooms clear, and makes sure the stair, the
## puzzle room and the springs can always be reached by a climber who times
## it, rolls or jumps: never truly shut (see `ensure_passable`).
##
## Traps are hard to spot, and their warnings are subtle (the owner's call):
## at rest a trap shows only a faint tell on its tile (small holes, a grate,
## cracks, a slit in the wall), drawn under the darkness so it's only seen
## where light falls; hidden ones show nothing until you're right on top of
## them (Keen Eyes shows them all). Just before it fires a trap gives a short
## tell (a click or a hiss, spikes peeking, a slot's eye reddening) and some
## kinds a small glint at the last moment; a hidden plate gives you even less
## time. They hurt. All the traps of a set piece keep one shared beat, so the
## pattern can still be learned, and beats overlap higher up.
##
## The trap data (names, timings, damage, shapes) lives in KINDS, and the
## placement rules in RULES, so they're easy to tune or rename. main.gd keeps
## the floor's traps in `main.traps` and owns one of these nodes
## (`main.trap_view`), which runs and draws them.
##
## A trap is a dictionary:
##   {pos, kind, state, timer, hidden, hit, dmg, dir, len, trigger, dodged, glint}
##   pos:   its tile's centre (for a lane, the nozzle end; a dart's slot is
##          in the wall just behind it)
##   dir:   which way a lane points; len: how many tiles it covers
##   state: "idle", "warn" (its tell: get off!), "fire" (hurting), "rest"
##   and optionally its own "cycle", "warn", "fire", "reach" (else KINDS'),
##   "room" (the room it belongs to), "guard" (rings the cache), "patch"
##   (a corridor patch)
##
## Two ways to go off:
##   "timed": idle -> warn -> fire -> idle, on a cycle shared by its set piece
##   "plate": idle until someone steps on it, then warn -> fire -> rest -> idle
##
## Drawing is cheap: a trap at rest never changes, so every resting trap is
## drawn ONCE into a few squares of the floor (only redrawn when the list
## changes); each frame only the traps warning or firing on screen are drawn,
## all in one batch, 30 times a second.

const Floors := preload("res://scripts/floors.gd")
const Rooms := preload("res://scripts/rooms.gd")
const Themes := preload("res://scripts/themes.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const Draw := preload("res://scripts/draw_util.gd")

## Hidden plates by tower (the first kind is the commonest).
const PLATES := {
	"gryphon": ["spikes"],
	"kraken": ["spikes"],
	"wyvern": ["spikes"],
	"manticore": ["spikes", "gas"],
	"firebird": ["spikes"],
	"chimera": ["thorns", "gas"],
}

## The glint: a star and a "ting" this long before a trap fires.
const GLINT_LEAD := 0.25

## Placement rules (see the top of this file).
const RULES := {
	"lead": 1.0,  # a set piece's first warning comes this long after the floor starts
	"pace_min": 0.72,  # the beat quickens to this share of its length by the top floor
	"patches": [[6, 1], [99, 2]],  # corridor spike patches a floor: [up to floor, how many]
	"plates": [[6, 1, 2], [99, 2, 3]],  # hidden plates a floor: [up to floor, fewest, most]
	"plate_hidden": 0.8,  # how often a loose plate is hidden
	"ring_from": 3,  # the cache's urn is ringed by spikes from this floor
	"min_traps": 2,  # every floor of rooms has at least this many traps
	"hidden_warn": 0.3,  # how long a hidden plate warns once stepped on (a visible one: its kind's)
	"room_guards": [[3, 0], [7, 1], [99, 2]],
	"notice": 64.0,  # how close you must be to make out a hidden trap's tell (px)  # monsters added to each trap room: [up to floor, how many]
}

## The trap kinds. Times are in seconds, damage in health (the climber has 140).
## shape: "lane" (a strip `len` tiles long from the nozzle along `dir`) or
##        "circle" (everything within `reach` of the tile)
## speed: (lanes) the trap is a FRONT that travels down the lane at this many
##        px a second, hurting only where it is (`front` px long): darts and
##        sluice waves; a lane without it hurts all along while it fires
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
		"name": "sluice sweep", "trigger": "timed", "cycle": 3.6, "warn": 0.9, "fire": 0.55,
		"shape": "lane", "len": 5, "r": 20.0, "reach": 20.0, "damage": 20.0, "push": 380.0,
		"speed": 480.0, "front": 60.0,
		"slow": 0.5, "slow_t": 1.8, "avoid": ["roll"], "hidden_chance": 0.1,
		"color": Color(0.45, 0.85, 0.95), "text": "Drenched",
	},
	"flame": {
		"name": "flame vent", "trigger": "timed", "cycle": 3.0, "warn": 0.9, "fire": 1.0,
		"shape": "lane", "len": 3, "r": 20.0, "reach": 20.0, "damage": 28.0, "push": 0.0,
		"avoid": ["roll"], "hidden_chance": 0.1, "color": Color(1.0, 0.55, 0.22), "text": "Burned",
	},
	"dart": {
		"name": "dart slot", "trigger": "timed", "cycle": 2.6, "warn": 0.4, "fire": 0.35,
		"shape": "lane", "len": 6, "r": 20.0, "reach": 20.0, "damage": 18.0, "push": 0.0,
		"speed": 700.0, "front": 20.0,
		"avoid": ["roll"], "hidden_chance": 0.0, "color": Color(0.95, 0.3, 0.25), "text": "Dart!",
	},
	"spikes": {
		"name": "spike plate", "glint": false, "trigger": "plate", "cycle": 2.8, "warn": 0.5, "fire": 0.6, "rest": 1.4,
		"shape": "circle", "r": 20.0, "reach": 26.0, "damage": 26.0, "push": 0.0,
		"avoid": ["roll", "jump"], "hidden_chance": 0.6, "color": Color(0.9, 0.82, 0.62), "text": "Spikes!",
	},
	"ember": {
		"name": "ember mark", "trigger": "timed", "cycle": 3.6, "warn": 1.0, "fire": 0.3,
		"shape": "circle", "r": 20.0, "reach": 44.0, "damage": 24.0, "push": 0.0,
		"burn_r": 40.0, "burn_t": 2.2, "avoid": ["roll", "jump"], "hidden_chance": 0.1,
		"color": Color(1.0, 0.7, 0.3), "text": "Embers",
	},
	"thorns": {
		"name": "bramble snare", "glint": false, "trigger": "plate", "warn": 0.5, "fire": 0.5, "rest": 2.0,
		"shape": "circle", "r": 20.0, "reach": 26.0, "damage": 18.0, "push": 0.0, "root": 1.3,
		"wake": 300.0, "avoid": ["roll", "jump"], "hidden_chance": 0.5,
		"color": Color(0.6, 0.85, 0.4), "text": "Snared",
	},
	"gas": {
		"name": "gas vent", "glint": false, "trigger": "plate", "warn": 0.5, "fire": 6.0, "rest": 4.0,
		"shape": "circle", "r": 20.0, "reach": 84.0, "damage": 10.0, "tick": 0.5, "push": 0.0,
		"avoid": ["roll"], "hidden_chance": 0.75, "color": Color(0.62, 0.8, 0.3), "text": "Choking!",
	},
	"miasma": {
		"name": "miasma vent", "glint": false, "trigger": "timed", "cycle": 6.4, "warn": 0.8, "fire": 3.0,
		"shape": "circle", "r": 20.0, "reach": 64.0, "damage": 10.0, "tick": 0.5, "push": 0.0,
		"avoid": ["roll"], "hidden_chance": 0.0, "color": Color(0.66, 0.78, 0.32), "text": "Choking!",
	},
}

## What each trap room's set piece is made of (for the README and tests):
## theme id -> the trap kinds it lays.
const THEME_KINDS := {
	"spikes": ["spikes"],
	"darts": ["dart"],
	"furnace": ["flame"],
	"windhall": ["gust", "spikes"],
	"sluice": ["sluice"],
	"emberfall": ["ember"],
	"bramble": ["thorns"],
	"miasma": ["miasma"],
}

const C := Floors.CELL
const BODY := 7.0  # half the climber's width: how far past its reach a trap catches you
const DIRS4 := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var main
var show_all := false  # dev tool: draw every trap's outline
var root_t := 0.0  # the climber is held by a thorn snare (roll to break free)
var slow_t := 0.0  # the climber is slowed by a sluice's water
var slow_mult := 1.0
var redraw_t := 0.0
var floor_marks: Dictionary = {}  # the floor's paths and decor (plan["trap_floor"])
var floor_layer: Node2D  # resting traps, drawn once (see the top)
var _static_items: Array = []
var _drawn_list = null
var _drawn_n := -1
var _drawn_keen := false
var _drawn_show := false
var _drawn_marks = null
var _last_sound := {}


# --- placement ---------------------------------------------------------------

## The traps for a floor of rooms (none on floor 1 or the beast's floor). See
## the top of the file. `main` (optional) gives the built layout's walls.
## Also moves monsters off trap tiles and clears chasms from under things
## that matter (both in `plan`), and stores the floor's paths and decor in
## plan["trap_floor"].
static func place(plan: Dictionary, tower: Dictionary, floor_num: int, main = null) -> Array:
	var list: Array = []
	var rooms: Array = plan.get("rooms", [])
	if floor_num <= 1 or rooms.size() < 2 or plan.get("summit", false):
		return list
	clear_pits(plan)
	var ctx := context(plan, main)
	var tid: String = tower.get("beast_kind", "")
	# The trap rooms' set pieces.
	var infos: Array = plan.get("room_info", [])
	for i in infos.size():
		var theme: String = infos[i]["theme"]
		if THEME_KINDS.has(theme):
			list.append_array(build_theme(ctx, i, theme, floor_num))
			_rehaz(ctx, list)
	# Monsters wait among the traps (from floor 4): fight them in the pattern.
	_room_guards(ctx, list, tower, floor_num)
	# Spikes ring the cache's urn.
	if floor_num >= int(RULES["ring_from"]) and plan.has("cache"):
		list.append_array(_guard_ring(ctx, plan["cache"]["pos"], floor_num))
		_rehaz(ctx, list)
	# A spike patch or two in the corridors.
	list.append_array(_patches(ctx, floor_num))
	_rehaz(ctx, list)
	# Hidden plates.
	list.append_array(_plates(ctx, tid, floor_num, list.size()))
	# The protection pass: a way to everything that matters, never shut for good.
	ensure_passable(ctx, list)
	_move_monsters(ctx)
	plan["trap_floor"] = {"paths": ctx["paths"], "decor": ctx["decor"]}
	return list


## The set piece of trap theme `theme` in room `i` of the plan (see the
## README's table). [] if it won't fit there.
static func build_theme(ctx: Dictionary, i: int, theme: String, floor_num: int) -> Array:
	var R := _room(ctx, i)
	if R.is_empty():
		return []
	var group: Array = []
	match theme:
		"spikes":
			group = _b_spikes(ctx, R, floor_num)
		"darts":
			group = _b_darts(ctx, R, floor_num)
		"furnace":
			group = _b_furnace(ctx, R, floor_num)
		"windhall":
			group = _b_windhall(ctx, R, floor_num)
		"sluice":
			group = _b_sluice(ctx, R, floor_num)
		"emberfall":
			group = _b_emberfall(ctx, R, floor_num)
		"bramble":
			group = _b_bramble(ctx, R, floor_num)
		"miasma":
			group = _b_miasma(ctx, R, floor_num)
	for tr in group:
		tr["room"] = i
	return group


## How hard a floor's traps are, 0 on floor 2 to 1 on floor 11.
static func difficulty(floor_num: int) -> float:
	return clampf((floor_num - 2) / 9.0, 0.0, 1.0)


## How long the beat is on a floor, as a share of its length on floor 2.
static func pace(floor_num: int) -> float:
	return lerpf(1.0, float(RULES["pace_min"]), difficulty(floor_num))


## A new trap. `hidden` traps are hard to see until they warn (Keen Eyes sees them).
static func make(pos: Vector2, kind: String, hidden := false, floor_num := 2) -> Dictionary:
	var k: Dictionary = KINDS[kind]
	var tr := {"pos": pos, "kind": kind, "state": "idle", "timer": 0.0, "hidden": hidden,
		"hit": [], "dmg": float(k["damage"]) * (1.0 + 0.06 * maxf(floor_num - 2, 0)),
		"dir": Vector2.DOWN, "len": int(k.get("len", 1)), "trigger": k["trigger"],
		"dodged": false, "glint": false, "tick_t": 0.0}
	if k["trigger"] == "timed":
		tr["timer"] = 1.0
	elif hidden:
		tr["warn"] = float(RULES["hidden_warn"])  # a hidden plate gives you less time
	if k.has("speed"):
		fit(tr)
	return tr


## A front's firing lasts as long as it takes to cross its lane (call after
## changing a dart's or a sluice's `len`).
static func fit(tr: Dictionary) -> void:
	var k: Dictionary = KINDS[tr["kind"]]
	if k.has("speed"):
		tr["fire"] = maxf(float(tr["len"]) * C / float(k["speed"]), 0.12) + 0.05


## A trap's own value for `key` ("cycle", "warn", "fire", "rest", "reach"), else its kind's.
static func val(tr: Dictionary, key: String) -> float:
	if tr.has(key):
		return float(tr[key])
	return float(KINDS[tr["kind"]].get(key, 0.0))


## Puts a trap on its set piece's beat: it first warns `off` seconds after
## the set piece's lead-in, then every `cycle` seconds.
static func _beat(tr: Dictionary, cycle: float, warn: float, fire: float, off: float) -> void:
	tr["trigger"] = "timed"
	tr["cycle"] = cycle
	tr["warn"] = warn
	if not KINDS[tr["kind"]].has("speed"):
		tr["fire"] = fire
	tr["timer"] = float(RULES["lead"]) + fposmod(off, cycle)
	tr["start"] = tr["timer"]


# --- the floor's grid ----------------------------------------------------------

## The floor's tile grid as the traps see it:
##   solid  1 for walls (closed doors count as open: they open), pillars too
##   chasm  1 for chasm tiles
##   prot   kept clear: 2 = never a trap (start, stair, door tiles, the
##          puzzle room, the cache's urn, springs, camps, chasm edges, paths);
##          1 = good rooms (only the guard ring around the urn goes there)
##   haz    how many traps reach each tile (see `cover`)
static func context(plan: Dictionary, main = null) -> Dictionary:
	var arena: Rect2 = plan.get("arena", Floors.ARENA)
	var gs := Vector2i(int(round(arena.size.x / C)), int(round(arena.size.y / C)))
	var n := gs.x * gs.y
	var solid := PackedByteArray()
	if main != null and main.layout_on and main.grid_size == gs and main.solid.size() == n:
		solid = main.solid.duplicate()
	else:
		solid.resize(n)
		solid.fill(1)
		for r in plan.get("walk", []):
			for t in _tiles(r, gs):
				solid[t.y * gs.x + t.x] = 0
		for r in plan.get("blocks", []):
			for t in _tiles(r, gs):
				solid[t.y * gs.x + t.x] = 1
	for d in plan.get("doors", []):
		for t in d["tiles"]:
			if _inside(t, gs):
				solid[t.y * gs.x + t.x] = 0
	for p in plan.get("pillars", []):
		var t := tile_of(p["pos"])
		if _inside(t, gs):
			solid[t.y * gs.x + t.x] = 1
	var chasm := PackedByteArray()
	chasm.resize(n)
	for r in plan.get("chasms", []):
		for t in _tiles(r, gs):
			chasm[t.y * gs.x + t.x] = 1
	var prot := PackedByteArray()
	prot.resize(n)
	var haz := PackedByteArray()
	haz.resize(n)
	var ctx := {"gs": gs, "solid": solid, "chasm": chasm, "prot": prot, "haz": haz, "plan": plan,
		"paths": [], "decor": []}
	_protect(ctx)
	return ctx


## protect(): what must stay clear (see `context`).
static func _protect(ctx: Dictionary) -> void:
	var plan: Dictionary = ctx["plan"]
	_mark_box(ctx, tile_of(plan.get("start", Vector2(-1e6, -1e6))), 3, 2)
	_mark_box(ctx, tile_of(plan.get("stair", Vector2(-1e6, -1e6))), 2, 2)
	# A door itself stays clear (it swings open); the ground in front of it
	# and the corridor behind it may hold traps: a set piece can span the way.
	for d in plan.get("doors", []):
		for t in d["tiles"]:
			_mark_box(ctx, t, 0, 2)
	var pz: Dictionary = plan.get("puzzle", {})
	if not pz.is_empty():
		_mark_rect(ctx, pz["room"], 2)
	for r in plan.get("safe_rooms", []):
		_mark_rect(ctx, r, 1)
	if plan.has("cache"):
		_mark_box(ctx, tile_of(plan["cache"]["pos"]), 1, 2)
	for sp in plan.get("springs", []):
		_mark_box(ctx, tile_of(sp["pos"]), 2, 2)
	for cp in plan.get("camps", []):
		_mark_box(ctx, tile_of(cp["pos"]), 1, 2)
		_mark_box(ctx, tile_of(cp["item"]), 1, 2)
	# Nothing at a chasm's edge (a jump needs a clear take-off and landing).
	var gs: Vector2i = ctx["gs"]
	var chasm: PackedByteArray = ctx["chasm"]
	for k in chasm.size():
		if chasm[k] == 1:
			_mark_box(ctx, Vector2i(k % gs.x, k / gs.x), 1, 2)


static func _mark_box(ctx: Dictionary, t: Vector2i, r: int, level: int) -> void:
	var gs: Vector2i = ctx["gs"]
	var prot: PackedByteArray = ctx["prot"]
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			var u := t + Vector2i(dx, dy)
			if _inside(u, gs):
				prot[u.y * gs.x + u.x] = maxi(prot[u.y * gs.x + u.x], level)
	ctx["prot"] = prot


static func _mark_rect(ctx: Dictionary, r: Rect2, level: int) -> void:
	var gs: Vector2i = ctx["gs"]
	var prot: PackedByteArray = ctx["prot"]
	for t in _tiles(r, gs):
		prot[t.y * gs.x + t.x] = maxi(prot[t.y * gs.x + t.x], level)
	ctx["prot"] = prot


## The grid tile a world point is on (the grid starts at Floors.ORIGIN).
static func tile_of(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor((pos.x - Floors.ORIGIN.x) / C)), int(floor((pos.y - Floors.ORIGIN.y) / C)))


## A grid tile's centre (world px).
static func centre(t: Vector2i) -> Vector2:
	return Floors.ORIGIN + (Vector2(t) + Vector2(0.5, 0.5)) * C


static func _inside(t: Vector2i, gs: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < gs.x and t.y < gs.y


## The grid tiles a world rect covers (inside the grid).
static func _tiles(r: Rect2, gs: Vector2i) -> Array:
	var tr := Floors.tile_rect(r)
	var out: Array = []
	for y in range(maxi(tr.position.y, 0), mini(tr.end.y, gs.y)):
		for x in range(maxi(tr.position.x, 0), mini(tr.end.x, gs.x)):
			out.append(Vector2i(x, y))
	return out


## Open floor (not wall, not chasm).
static func _open(ctx: Dictionary, t: Vector2i) -> bool:
	var gs: Vector2i = ctx["gs"]
	if not _inside(t, gs):
		return false
	var k := t.y * gs.x + t.x
	return ctx["solid"][k] == 0 and ctx["chasm"][k] == 0


## Open floor a trap may take: not kept clear, no trap there yet.
static func _free(ctx: Dictionary, t: Vector2i, prot_ok := 0) -> bool:
	if not _open(ctx, t):
		return false
	var k: int = t.y * ctx["gs"].x + t.x
	return ctx["prot"][k] <= prot_ok and ctx["haz"][k] == 0


## The tiles a trap can hurt you on (grid tiles): a lane's tiles, or every
## tile whose middle is within a circle's reach (plus half a body).
static func cover(tr: Dictionary) -> Array:
	var t0 := tile_of(tr["pos"])
	var out: Array = []
	if KINDS[tr["kind"]]["shape"] == "lane":
		var d := Vector2i(roundi(tr["dir"].x), roundi(tr["dir"].y))
		for i in int(tr["len"]):
			out.append(t0 + d * i)
		return out
	var r := val(tr, "reach") + BODY
	var n := int(ceil(r / C))
	for dy in range(-n, n + 1):
		for dx in range(-n, n + 1):
			if Vector2(dx, dy).length() * C < r:
				out.append(t0 + Vector2i(dx, dy))
	return out


## Recounts which tiles the traps reach.
static func _rehaz(ctx: Dictionary, list: Array) -> void:
	var gs: Vector2i = ctx["gs"]
	var haz: PackedByteArray = ctx["haz"]
	haz.fill(0)
	for tr in list:
		for t in cover(tr):
			if _inside(t, gs):
				var k: int = t.y * gs.x + t.x
				haz[k] = mini(haz[k] + 1, 255)
	ctx["haz"] = haz


## Adds a trap to `out` if every tile it reaches may hold one: a lane's tiles
## must all be free; a circle's own tile must be free and its reach must not
## spill onto ground kept clear. `prot_ok` lets the guard ring into a good room.
static func _add(ctx: Dictionary, out: Array, tr: Dictionary, prot_ok := 0) -> bool:
	var gs: Vector2i = ctx["gs"]
	var tiles := cover(tr)
	if KINDS[tr["kind"]]["shape"] == "lane":
		for t in tiles:
			if not _free(ctx, t, prot_ok):
				return false
	else:
		if not _free(ctx, tile_of(tr["pos"]), prot_ok):
			return false
		for t in tiles:
			if _inside(t, gs) and ctx["prot"][t.y * gs.x + t.x] > prot_ok:
				return false
	_count(ctx, tiles, 1)
	out.append(tr)
	return true


## Adds `by` to the trap count of each tile.
static func _count(ctx: Dictionary, tiles: Array, by: int) -> void:
	var gs: Vector2i = ctx["gs"]
	var haz: PackedByteArray = ctx["haz"]
	for t in tiles:
		if _inside(t, gs):
			var k: int = t.y * gs.x + t.x
			haz[k] = clampi(haz[k] + by, 0, 255)
	ctx["haz"] = haz


# --- a room, seen along its long side -------------------------------------------

## A room of the plan as the set pieces see it: its tiles counted ALONG its
## long side (a: 0..L-1) and ACROSS its short side (b: 0..S-1), and its
## doorways. {} for a room that isn't on the grid.
static func _room(ctx: Dictionary, i: int) -> Dictionary:
	var infos: Array = ctx["plan"].get("room_info", [])
	if i < 0 or i >= infos.size():
		return {}
	var info: Dictionary = infos[i]
	var rect: Rect2 = info["rect"]
	var t0 := tile_of(rect.position + Vector2(1, 1))
	var w := int(round(rect.size.x / C))
	var h := int(round(rect.size.y / C))
	var horiz := w >= h
	var R := {"i": i, "rect": rect, "t0": t0, "w": w, "h": h, "rows": info["rows"], "horiz": horiz,
		"L": w if horiz else h, "S": h if horiz else w,
		"A": Vector2i(1, 0) if horiz else Vector2i(0, 1), "B": Vector2i(0, 1) if horiz else Vector2i(1, 0)}
	# Doorways: the room's edge tiles with open floor (a corridor) just outside.
	var doors: Array = []
	for y in h:
		for x in w:
			if x != 0 and y != 0 and x != w - 1 and y != h - 1:
				continue
			for d in DIRS4:
				var o: Vector2i = Vector2i(x, y) + d
				if o.x >= 0 and o.y >= 0 and o.x < w and o.y < h:
					continue
				if _open(ctx, t0 + o):
					doors.append(Vector2i(x, y))
					break
	R["doors"] = doors
	return R


## The grid tile at (a along, b across) of a room.
static func _at(R: Dictionary, a: int, b: int) -> Vector2i:
	return R["t0"] + (Vector2i(a, b) if R["horiz"] else Vector2i(b, a))


## Whether (a, b) is open floor of the room itself (not its outline's rock,
## a wall, a pillar or water's edge).
static func _in(ctx: Dictionary, R: Dictionary, a: int, b: int) -> bool:
	if a < 0 or b < 0 or a >= R["L"] or b >= R["S"]:
		return false
	var l: Vector2i = Vector2i(a, b) if R["horiz"] else Vector2i(b, a)
	return Rooms.open_at(R["rows"], l.x, l.y) and _open(ctx, R["t0"] + l)


## The lines along a room that hold a row of the set piece, sparser low in
## the tower: every other line (floors 2-3), then two lines in three (4-6),
## then every line.
static func _lines(from: int, to: int, floor_num: int) -> Array:
	var out: Array = []
	for a in range(from, to):
		var use := true
		if floor_num <= 3:
			use = (a - from) % 2 == 0
		elif floor_num <= 6:
			use = (a - from) % 3 != 2
		if use:
			out.append(a)
	return out


## A lane from (a, b) of room R stepping (da, db) while the tiles are the
## room's and free: how many tiles (at most `most`).
static func _run(ctx: Dictionary, R: Dictionary, a: int, b: int, da: int, db: int, most := 99) -> int:
	var n := 0
	while n < most and _in(ctx, R, a + da * n, b + db * n) and _free(ctx, _at(R, a + da * n, b + db * n)):
		n += 1
	return n


## Which end along the room (0 = the low end) has fewer doorways, so a set
## piece can face away from where you come in.
static func _quiet_end(R: Dictionary, across := false) -> int:
	var lo := 0
	var hi := 0
	for d in R["doors"]:
		var v: int = (d.x if R["horiz"] else d.y) if not across else (d.y if R["horiz"] else d.x)
		var n: int = (R["L"] if not across else R["S"])
		if v <= n / 2:
			lo += 1
		else:
			hi += 1
	if lo == hi:
		return randi() % 2
	return 0 if lo < hi else 1


# --- set pieces --------------------------------------------------------------------

## Spike Gallery: rows of spikes across the room's short side, each row a
## beat behind the last: a wave rolling down the room. Ride in behind it.
## Higher up the rows close up and stay up longer.
static func _b_spikes(ctx: Dictionary, R: Dictionary, f: int) -> Array:
	var p := pace(f)
	var cycle := 2.8 * p
	var step := 0.45 * p
	var warn := 0.5
	var fire := 0.6 + 0.3 * difficulty(f)
	var lines := _lines(1, R["L"] - 1, f)
	if _quiet_end(R) == 0:
		lines.reverse()  # (the wave rolls away from the busier end)
	var out: Array = []
	var rows := 0
	for k in lines.size():
		var a: int = lines[k]
		var made := false
		for b in R["S"]:
			if not _in(ctx, R, a, b) or not _free(ctx, _at(R, a, b)):
				continue
			var tr := make(centre(_at(R, a, b)), "spikes", randf() < lerpf(0.15, 0.45, difficulty(f)), f)
			# (from floor 7 a second wave rolls between the rows of the first)
			_beat(tr, cycle, warn, fire, k * step + (cycle * 0.5 if f >= 7 and k % 2 == 1 else 0.0))
			made = _add(ctx, out, tr) or made
		if made:
			rows += 1
	return out if rows >= 2 else []


## Dart Hall: slots in the two long walls fire darts across the room, the
## lines from one wall and the other half a cycle apart. A slot's eye glows
## red 0.4 s before it fires. Higher up every line has a slot.
static func _b_darts(ctx: Dictionary, R: Dictionary, f: int) -> Array:
	var cycle := maxf(2.6 * pace(f), 1.7)
	var S: int = R["S"]
	var lines: Array = []
	for a in R["L"]:
		if f >= 3 or a % 2 == 1:
			lines.append(a)
	var out: Array = []
	var sides := [0, 0]
	var k := 0
	for a in lines:
		var low := k % 2 == 0
		var db := 1 if low else -1
		var b := 0 if low else S - 1
		while b >= 0 and b < S and not _in(ctx, R, a, b):
			b += db
		if b < 0 or b >= S:
			continue
		var g := _at(R, a, b)
		var dirv: Vector2i = R["B"] * db
		if _open(ctx, g - dirv):
			continue  # (a slot needs a wall behind it, not a doorway)
		var n := _run(ctx, R, a, b, 0, db)
		if n < 3:
			continue
		k += 1
		var tr := make(centre(g), "dart", false, f)
		tr["dir"] = Vector2(dirv)
		tr["len"] = n
		fit(tr)
		_beat(tr, cycle, 0.4, 0.0, 0.0 if low else cycle * 0.5)
		if _add(ctx, out, tr):
			sides[0 if low else 1] += 1
	return out if sides[0] >= 1 and sides[1] >= 1 and out.size() >= 3 else []


## The Furnace: flame vents at both ends of the room breathe fire toward the
## middle in turns, one half of the room, then the other: one side is always
## safe, and a line across the middle is never burned. Higher up the beat
## quickens and the fire lasts longer (never so long that both sides burn).
static func _b_furnace(ctx: Dictionary, R: Dictionary, f: int) -> Array:
	var d := difficulty(f)
	var cycle := maxf(3.4 * pace(f), 2.5)
	var fire := minf(1.0 + 0.3 * d, cycle * 0.5 - 0.15)
	var L: int = R["L"]
	var m0 := L / 2
	var m1 := m0 + 1  # the safe line across the middle: [m0, m1)
	if L % 2 == 0 and d < 0.5:
		m0 = L / 2 - 1
		m1 = L / 2 + 1
	var out: Array = []
	var sides := [0, 0]
	for b in R["S"]:
		# The near half: from the low end toward the middle.
		var a := 0
		while a < m0 and not (_in(ctx, R, a, b) and _free(ctx, _at(R, a, b))):
			a += 1
		var n := _run(ctx, R, a, b, 1, 0, m0 - a) if a < m0 else 0
		if n >= 2:
			var tr := make(centre(_at(R, a, b)), "flame", false, f)
			tr["dir"] = Vector2(R["A"])
			tr["len"] = n
			_beat(tr, cycle, 0.6, fire, 0.0)
			if _add(ctx, out, tr):
				sides[0] += 1
		# The far half: from the high end toward the middle.
		a = L - 1
		while a >= m1 and not (_in(ctx, R, a, b) and _free(ctx, _at(R, a, b))):
			a -= 1
		n = _run(ctx, R, a, b, -1, 0, a - m1 + 1) if a >= m1 else 0
		if n >= 2:
			var tr := make(centre(_at(R, a, b)), "flame", false, f)
			tr["dir"] = -Vector2(R["A"])
			tr["len"] = n
			_beat(tr, cycle, 0.6, fire, cycle * 0.5)
			if _add(ctx, out, tr):
				sides[1] += 1
	return out if sides[0] >= 2 and sides[1] >= 2 else []


## Windhall (the Gryphon's): gusts blow across the room toward a long wall
## lined with spikes, one lane after another down the room. The spikes rise
## just as the gust lands you on them. Cross between the gusts, or roll.
static func _b_windhall(ctx: Dictionary, R: Dictionary, f: int) -> Array:
	# The spiked wall: the long side with fewer doorways, else the other.
	var first := _quiet_end(R, true) == 1
	for spike_high in [first, not first]:
		var got := _windhall_side(ctx, R, f, spike_high)
		if not got.is_empty():
			return got
	return []


static func _windhall_side(ctx: Dictionary, R: Dictionary, f: int, spike_high: bool) -> Array:
	var p := pace(f)
	var cycle := 3.2 * p
	var step := 0.4 * p
	var gwarn := 0.8
	var swarn := 0.5
	var S: int = R["S"]
	var db := 1 if spike_high else -1  # the way the wind blows (across)
	# Each line's spike tile: the room's last tile before the spiked wall.
	var spike_at := {}
	for a in R["L"]:
		var b := S - 1 if spike_high else 0
		while b >= 0 and b < S and not _in(ctx, R, a, b):
			b -= db
		if b >= 0 and b < S:
			spike_at[a] = b
	var out: Array = []
	var gust_off := {}
	var lines := _lines(0, R["L"], f)
	var k := 0
	for a in lines:
		if not spike_at.has(a):
			continue
		var b := 0 if spike_high else S - 1
		while b != spike_at[a] and not (_in(ctx, R, a, b) and _free(ctx, _at(R, a, b))):
			b += db
		var n := _run(ctx, R, a, b, 0, db, absi(spike_at[a] - b))
		# (only a gust that blows all the way onto its spike)
		if n < 2 or n != absi(spike_at[a] - b) or not _free(ctx, _at(R, a, spike_at[a])):
			continue
		var tr := make(centre(_at(R, a, b)), "gust", false, f)
		tr["dir"] = Vector2(R["B"] * db)
		tr["len"] = n
		var off := k * step + (cycle * 0.5 if f >= 7 and k % 2 == 1 else 0.0)
		_beat(tr, cycle, gwarn, 0.3, off)
		if _add(ctx, out, tr):
			gust_off[a] = off
			k += 1
	if gust_off.size() < 2:
		_drop(ctx, out)
		return []
	# The spiked wall: each spike rises just after the nearest gust lands.
	var spikes := 0
	for a in spike_at:
		var g := _at(R, a, spike_at[a])
		if not _free(ctx, g):
			continue
		var near := -1
		for ga in gust_off:
			if near < 0 or absi(ga - a) < absi(near - a):
				near = ga
		var tr := make(centre(g), "spikes", false, f)
		_beat(tr, cycle, swarn, 0.6 + 0.2 * difficulty(f), float(gust_off[near]) + gwarn + 0.1 - swarn)
		if _add(ctx, out, tr):
			spikes += 1
	if spikes < 3:
		_drop(ctx, out)
		return []
	return out


## Takes back traps a set piece laid before it found it didn't fit.
static func _drop(ctx: Dictionary, group: Array) -> void:
	for tr in group:
		_count(ctx, cover(tr), -1)
	group.clear()


## Sluice Hall (the Kraken's): water sweeps down the hall from one end, the
## rows taking turns, so the row beside you is dry while yours floods. A
## pillar or two stand in the flood: behind one, the sweep can't reach you.
static func _b_sluice(ctx: Dictionary, R: Dictionary, f: int) -> Array:
	var cycle := 3.6 * pace(f)
	var L: int = R["L"]
	var S: int = R["S"]
	var plan: Dictionary = ctx["plan"]
	var gate_low := _quiet_end(R) == 0  # the water comes from the quieter end
	var da := 1 if gate_low else -1
	# Shelter: pillars in the flood (never against a wall, so nothing is cut off).
	var want := 1 + int(difficulty(f) * 2.0) if L >= 7 else 0
	var spots: Array = []
	for a in range(int(L * 0.3), int(ceil(L * 0.75))):
		for b in range(1, S - 1):
			spots.append(Vector2i(a, b))
	spots.shuffle()
	var shelters: Array = []
	for s in spots:
		if shelters.size() >= want:
			break
		var g := _at(R, s.x, s.y)
		if not _free(ctx, g):
			continue
		var clear := true
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var u := g + Vector2i(dx, dy)
				clear = clear and _open(ctx, u) and ctx["prot"][u.y * ctx["gs"].x + u.x] < 2
		for o in shelters:
			clear = clear and maxi(absi(o.x - g.x), absi(o.y - g.y)) > 2
		if not clear:
			continue
		shelters.append(g)
	var out: Array = []
	for b in S:
		var a := 0 if gate_low else L - 1
		while a >= 0 and a < L and not (_in(ctx, R, a, b) and _free(ctx, _at(R, a, b))):
			a += da
		if a < 0 or a >= L:
			continue
		# (a shelter stops the sweep where it stands)
		var n := 0
		while _in(ctx, R, a + da * n, b) and _free(ctx, _at(R, a + da * n, b)) and not (_at(R, a + da * n, b) in shelters):
			n += 1
		if n < 3:
			continue
		var tr := make(centre(_at(R, a, b)), "sluice", false, f)
		tr["dir"] = Vector2(R["A"] * da)
		tr["len"] = n
		fit(tr)
		_beat(tr, cycle, 0.9, 0.0, cycle * 0.5 if b % 2 == 1 else 0.0)
		_add(ctx, out, tr)
	if out.size() < 2:
		return []
	var solid: PackedByteArray = ctx["solid"]
	for g in shelters:
		plan["pillars"].append({"pos": centre(g), "r": 17.0})
		solid[g.y * ctx["gs"].x + g.x] = 1
	ctx["solid"] = solid
	return out


## Emberfall (the Firebird's): marks glow on the floor and embers fall on
## them a column at a time, a wave sweeping down the room; where they land
## the floor burns a while. Higher up the marks close up into walls of fire
## you must time, and the floor burns longer.
static func _b_emberfall(ctx: Dictionary, R: Dictionary, f: int) -> Array:
	var p := pace(f)
	var d := difficulty(f)
	var cycle := 3.6 * p
	var step := 0.55 * p
	var gap_b := 3 if f < 6 else 2
	var cols: Array = range(1, R["L"] - 1, 3)
	if _quiet_end(R) == 0:
		cols.reverse()
	var out: Array = []
	var used := {}
	for i in cols.size():
		var a: int = cols[i]
		for b in range(1 + (i % 2 if gap_b == 3 else 0), R["S"] - 1, gap_b):
			if not _in(ctx, R, a, b):
				continue
			var tr := make(centre(_at(R, a, b)), "ember", false, f)
			tr["burn_t"] = 2.2 + 0.8 * d
			_beat(tr, cycle, 1.0, 0.3, i * step)
			if _add(ctx, out, tr):
				used[a] = true
	# From floor 9 more marks fall between the columns, half a beat apart.
	if f >= 9:
		for i in cols.size():
			var a: int = cols[i] + 2
			for b in range(1, R["S"] - 1, 2):
				if _in(ctx, R, a, b):
					var tr := make(centre(_at(R, a, b)), "ember", false, f)
					tr["burn_t"] = 2.2 + 0.8 * d
					_beat(tr, cycle, 1.0, 0.3, i * step + cycle * 0.5)
					_add(ctx, out, tr)
	return out if out.size() >= 3 and used.size() >= 2 else []


## Bramble Hall (the Chimera's): brambles fill the room, with snares hidden
## among them; a trodden path winds clear through from doorway to doorway.
## A snare's snap wakes the pack. Higher up the brambles are thicker and
## more of the snares are hidden.
static func _b_bramble(ctx: Dictionary, R: Dictionary, f: int) -> Array:
	var d := difficulty(f)
	var path := _winding_path(ctx, R)
	if path.is_empty():
		return []
	var out: Array = []
	var decor: Array = []
	for a in R["L"]:
		for b in R["S"]:
			if not _in(ctx, R, a, b):
				continue
			var g := _at(R, a, b)
			if not _free(ctx, g):
				continue
			decor.append(g)
			if randf() < lerpf(0.5, 0.8, d):
				_add(ctx, out, make(centre(g), "thorns", randf() < lerpf(0.3, 0.6, d), f))
	if out.size() < 6:
		_unpath(ctx, path)
		return []
	_keep_path(ctx, path, "trodden")
	for g in decor:
		ctx["decor"].append(["bramble", Rect2(centre(g) - Vector2(C, C) * 0.5, Vector2(C, C))])
	return out


## Miasma: vents in the floor breathe choking gas one after another down
## the room; a path of clean stones winds through where the gas never
## reaches. Linger in a cloud and it will kill you.
static func _b_miasma(ctx: Dictionary, R: Dictionary, f: int) -> Array:
	var p := pace(f)
	var d := difficulty(f)
	var cycle := 6.4 * p
	var step := lerpf(0.6, 0.4, d) * p
	var path := _winding_path(ctx, R)
	if path.is_empty():
		return []
	var spots: Array = []
	for a in R["L"]:
		for b in R["S"]:
			if _in(ctx, R, a, b) and _free(ctx, _at(R, a, b)):
				spots.append(Vector2i(a, b))
	spots.shuffle()
	var out: Array = []
	var vents: Array = []
	for s in spots:
		var g := _at(R, s.x, s.y)
		var far := true
		for v in vents:
			far = far and maxi(absi(v.x - s.x), absi(v.y - s.y)) >= 2
		if not far:
			continue
		var tr := make(centre(g), "miasma", false, f)
		if _add(ctx, out, tr):
			vents.append(s)
	if out.size() < 2:
		_unpath(ctx, path)
		return []
	# One after another down the room.
	var order: Array = range(out.size())
	order.sort_custom(func(x, y): return vents[x].x < vents[y].x)
	for k in order.size():
		_beat(out[order[k]], cycle, 0.8, 3.0 + 1.4 * d, k * step)
	_keep_path(ctx, path, "clean")
	for a in R["L"]:
		for b in R["S"]:
			var g := _at(R, a, b)
			if _in(ctx, R, a, b) and not (g in path):
				ctx["decor"].append(["stain", Rect2(centre(g) - Vector2(C, C) * 0.5, Vector2(C, C))])
	return out


## A winding path through a room, one tile wide, from doorway to doorway
## (or, in a room with one way in, to the far side): the cheapest way across
## when every tile costs a random amount, so it bends. Its tiles are kept
## clear until `_unpath` (a set piece that didn't fit). Grid tiles.
static func _winding_path(ctx: Dictionary, R: Dictionary) -> Array:
	var doors: Array = R["doors"]
	if doors.is_empty():
		return []
	var gs: Vector2i = ctx["gs"]
	# The room's own tiles, each with a random cost.
	var cost := {}
	for a in R["L"]:
		for b in R["S"]:
			if _in(ctx, R, a, b):
				cost[_at(R, a, b)] = 1.0 + randf() * 4.0
	var ends: Array = []
	for d in doors:
		var g: Vector2i = R["t0"] + d
		if cost.has(g):
			ends.append(g)
	if ends.is_empty():
		return []
	# The two doorway tiles farthest apart (or the tile farthest from the only one).
	var a0: Vector2i = ends[0]
	var b0: Vector2i = ends[0]
	var best := -1.0
	for x in ends:
		for y in ends:
			var dd := Vector2(x - y).length()
			if dd > best:
				best = dd
				a0 = x
				b0 = y
	if best < 3.0:
		for t in cost:
			var dd := Vector2(t - a0).length()
			if dd > best:
				best = dd
				b0 = t
	var path := _cheapest(cost, a0, [b0])
	if path.is_empty():
		return []
	# Every other doorway joins the path.
	var on := {}
	for t in path:
		on[t] = true
	for e in ends:
		if on.has(e):
			continue
		var spur := _cheapest(cost, e, path)
		for t in spur:
			if not on.has(t):
				on[t] = true
				path.append(t)
	for t in path:
		_mark_box(ctx, t, 0, 2)
	return path


## The cheapest way from `from` to any of `to` over the tiles in `cost`.
static func _cheapest(cost: Dictionary, from: Vector2i, to: Array) -> Array:
	var dist := {from: 0.0}
	var prev := {}
	var done := {}
	var goal := Vector2i(-1, -1)
	var goals := {}
	for t in to:
		goals[t] = true
	while true:
		var cur := Vector2i(-1, -1)
		var cd := INF
		for t in dist:
			if not done.has(t) and dist[t] < cd:
				cd = dist[t]
				cur = t
		if cur == Vector2i(-1, -1):
			break
		if goals.has(cur):
			goal = cur
			break
		done[cur] = true
		for d in DIRS4:
			var n: Vector2i = cur + d
			if not cost.has(n) or done.has(n):
				continue
			var nd: float = cd + float(cost[n])
			if nd < float(dist.get(n, INF)):
				dist[n] = nd
				prev[n] = cur
	if goal == Vector2i(-1, -1):
		return []
	var out: Array = [goal]
	while out[-1] != from:
		out.append(prev[out[-1]])
	out.reverse()
	return out


## A set piece's path is part of the floor: kept clear for good, and drawn.
static func _keep_path(ctx: Dictionary, path: Array, look: String) -> void:
	for t in path:
		ctx["paths"].append([look, Rect2(centre(t) - Vector2(C, C) * 0.5, Vector2(C, C))])


## A path that wasn't used: its tiles may hold traps again (unless something
## else keeps them clear: they're simply marked again then).
static func _unpath(ctx: Dictionary, path: Array) -> void:
	var gs: Vector2i = ctx["gs"]
	var prot: PackedByteArray = ctx["prot"]
	for t in path:
		prot[t.y * gs.x + t.x] = 0
	ctx["prot"] = prot
	_protect(ctx)
	for p in ctx["paths"]:
		_mark_box(ctx, tile_of(p[1].get_center()), 0, 2)


# --- guards, patches, plates ---------------------------------------------------------

## Monsters added to each trap room, on its clear tiles: from floor 4 the
## set piece is fought through, not just walked through.
static func _room_guards(ctx: Dictionary, list: Array, tower: Dictionary, f: int) -> void:
	var want := 0
	for s in RULES["room_guards"]:
		if f <= int(s[0]):
			want = int(s[1])
			break
	if want <= 0:
		return
	var plan: Dictionary = ctx["plan"]
	var gs: Vector2i = ctx["gs"]
	var rooms := {}
	for tr in list:
		if tr.has("room"):
			rooms[int(tr["room"])] = true
	for i in rooms:
		var R := _room(ctx, i)
		var spots: Array = []
		for a in R["L"]:
			for b in R["S"]:
				var g := _at(R, a, b)
				if _in(ctx, R, a, b) and ctx["haz"][g.y * gs.x + g.x] == 0 and ctx["prot"][g.y * gs.x + g.x] == 0:
					spots.append(g)
		spots.shuffle()
		for k in mini(want, spots.size()):
			var kind := Floors._pick(f, 3.0, 99, tower.get("weights", {}))
			plan["monsters"].append([kind if kind != "" else "slime", centre(spots[k])])

## Spikes around the cache's urn, two tiles out, rising one after another
## around the ring: step through where they're down.
static func _guard_ring(ctx: Dictionary, at: Vector2, f: int) -> Array:
	var p := pace(f)
	var cycle := 2.8 * p
	var g0 := tile_of(at)
	var out: Array = []
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			if maxi(absi(dx), absi(dy)) != 2:
				continue
			var g := g0 + Vector2i(dx, dy)
			var tr := make(centre(g), "spikes", false, f)
			var ang := fposmod(Vector2(dx, dy).angle(), TAU)
			_beat(tr, cycle, 0.5, 0.6 + 0.2 * difficulty(f), ang / TAU * cycle)
			tr["guard"] = true
			_add(ctx, out, tr, 1)
	return out if out.size() >= 6 else []


## A spike patch or two in the corridors (three tiles across the whole
## corridor, all on one beat, some hidden), on the way to the stair first:
## you must cross it.
static func _patches(ctx: Dictionary, f: int) -> Array:
	var plan: Dictionary = ctx["plan"]
	var want := 1
	for s in RULES["patches"]:
		if f <= int(s[0]):
			want = int(s[1])
			break
	var route := _route(ctx, tile_of(plan["start"]), tile_of(plan["stair"]))
	var corridors: Array = plan.get("corridors", []).duplicate()
	corridors.shuffle()
	corridors.sort_custom(func(x, y): return int(_crosses(x, route)) > int(_crosses(y, route)))
	var p := pace(f)
	var out: Array = []
	var made := 0
	for c in corridors:
		if made >= want:
			break
		var tr := Floors.tile_rect(c)
		var horiz := tr.size.x >= tr.size.y
		var long := tr.size.x if horiz else tr.size.y
		if long < 5:
			continue
		var mid := long / 2
		var group: Array = []
		var ok := true
		var cycle := 2.8 * p
		var off := randf() * cycle
		for l in range(mid - 1, mid + 2):
			for w in mini(tr.size.y if horiz else tr.size.x, 3):
				var g := tr.position + (Vector2i(l, w) if horiz else Vector2i(w, l))
				var sp := make(centre(g), "spikes", randf() < 0.4, f)
				_beat(sp, cycle, 0.5, 0.6 + 0.2 * difficulty(f), off)
				sp["patch"] = true
				ok = ok and _add(ctx, group, sp)
		if ok and not group.is_empty():
			out.append_array(group)
			made += 1
		else:
			for sp in group:
				_count(ctx, cover(sp), -1)
	return out


static func _crosses(r: Rect2, route: Dictionary) -> bool:
	for t in _tiles(r, Vector2i(9999, 9999)):
		if route.has(t):
			return true
	return false


## A few loose plates, mostly hidden, anywhere but the rooms kept clear,
## a doorway or right beside another trap.
static func _plates(ctx: Dictionary, tid: String, f: int, have: int) -> Array:
	var plan: Dictionary = ctx["plan"]
	var lo := 1
	var hi := 2
	for s in RULES["plates"]:
		if f <= int(s[0]):
			lo = int(s[1])
			hi = int(s[2])
			break
	var want := maxi(randi_range(lo, hi), int(RULES["min_traps"]) - have)
	var kinds: Array = PLATES.get(tid, ["spikes"])
	var areas: Array = plan.get("rooms", []).slice(1)
	areas.append_array(plan.get("corridors", []))
	var taken: Array = []
	for m in plan.get("monsters", []):
		taken.append(tile_of(m[1]))
	var out: Array = []
	var gs: Vector2i = ctx["gs"]
	for attempt in 400:
		if out.size() >= want or areas.is_empty():
			break
		var tiles := _tiles(areas[randi() % areas.size()], gs)
		if tiles.is_empty():
			continue
		var g: Vector2i = tiles[randi() % tiles.size()]
		if not _free(ctx, g) or g in taken:
			continue
		# Not right beside another trap.
		var lonely := true
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var u := g + Vector2i(dx, dy)
				if _inside(u, gs) and ctx["haz"][u.y * gs.x + u.x] > 0:
					lonely = false
		if not lonely:
			continue
		var kind: String = kinds[0] if (kinds.size() == 1 or randf() < 0.6) else kinds[1]
		var tr := make(centre(g), kind, randf() < float(RULES["plate_hidden"]), f)
		_add(ctx, out, tr)
	return out


# --- the protection pass -----------------------------------------------------------

## The passable-route rule (the owner's: traps MAY block the way, but never
## for good). Searches the grid from the start, treating as walls only the
## tiles that are NEVER safe (traps whose beats overlap so that something
## always fires there, see `hard_tiles`); every other trap tile can be crossed
## by a climber who times it, rolls or jumps. While the stair, the puzzle
## room or a good room's spring or camp can't be reached that way, opens one
## never-safe tile on the way to it (the first on the route crossing the
## fewest), and searches again. Opening a tile cuts a lane short there (or
## takes away a trap that only covers its own patch). Chasms are jumped.
static func ensure_passable(ctx: Dictionary, list: Array) -> void:
	var plan: Dictionary = ctx["plan"]
	var gs: Vector2i = ctx["gs"]
	var start := tile_of(plan["start"])
	if not _inside(start, gs):
		return
	var goals: Array = []
	goals.append([tile_of(plan["stair"])])
	var pz: Dictionary = plan.get("puzzle", {})
	if not pz.is_empty():
		goals.append(_tiles(pz["room"], gs))
	for sp in plan.get("springs", []):
		goals.append([tile_of(sp["pos"])])
	for cp in plan.get("camps", []):
		goals.append([tile_of(cp["pos"])])
	var walls := ctx.duplicate()
	for it in 240:
		var hard := PackedByteArray()
		hard.resize(gs.x * gs.y)
		for t in hard_tiles(list):
			if _inside(t, gs):
				hard[t.y * gs.x + t.x] = 1
		walls["haz"] = hard
		var res := _search(walls, start)
		var dist: PackedInt32Array = res[0]
		var prev: PackedInt32Array = res[1]
		var cut := -1
		for g in goals:
			var best := -1
			for t in g:
				if not _inside(t, gs):
					continue
				var k: int = t.y * gs.x + t.x
				if dist[k] < (1 << 29) and (best < 0 or dist[k] < dist[best]):
					best = k
			if best < 0 or dist[best] == 0:
				continue
			# Walk back to the start; the never-safe tile nearest the start is opened.
			var k := best
			while k >= 0:
				if hard[k] > 0:
					cut = k
				k = prev[k]
			break
		if cut < 0:
			break
		_open_tile(list, Vector2i(cut % gs.x, cut / gs.x))
	_rehaz(ctx, list)


## The tiles where something is always firing: timed traps whose beats
## overlap so there's never a safe moment to cross (plates never count: a
## plate only fires when stepped on, and can be jumped).
static func hard_tiles(list: Array) -> Dictionary:
	var by_tile := {}
	for tr in list:
		if tr["trigger"] != "timed":
			continue
		for t in cover(tr):
			if not by_tile.has(t):
				by_tile[t] = []
			by_tile[t].append(tr)
	var out := {}
	for t in by_tile:
		var trs: Array = by_tile[t]
		if trs.size() == 1 and val(trs[0], "fire") < val(trs[0], "cycle") - 0.05:
			continue
		var span := 0.0
		for tr in trs:
			span = maxf(span, val(tr, "cycle"))
		var safe := false
		var tt := 0.0
		while tt < span * 2.0 and not safe:
			safe = not trs.any(func(tr): return firing_at(tr, tt))
			tt += 0.04
		if not safe:
			out[t] = true
	return out


## Whether a timed trap is firing `t` seconds after the floor began.
static func firing_at(tr: Dictionary, t: float) -> bool:
	var ph := fposmod(t - float(tr.get("start", 1.0)) - val(tr, "warn"), val(tr, "cycle"))
	return ph < val(tr, "fire")


## Takes the traps off one tile: a lane is cut short there, anything else goes.
static func _open_tile(list: Array, t: Vector2i) -> void:
	for tr in list.duplicate():
		var tiles := cover(tr)
		var i := tiles.find(t)
		if i < 0:
			continue
		if KINDS[tr["kind"]]["shape"] == "lane" and i > 0:
			tr["len"] = i
			fit(tr)
		else:
			list.erase(tr)


## A search from `start` counting the trap tiles crossed (walls block):
## [fewest trap tiles to each tile, the tile before it on that way].
static func _search(ctx: Dictionary, start: Vector2i) -> Array:
	var gs: Vector2i = ctx["gs"]
	var solid: PackedByteArray = ctx["solid"]
	var haz: PackedByteArray = ctx["haz"]
	var n := gs.x * gs.y
	var dist := PackedInt32Array()
	dist.resize(n)
	dist.fill(1 << 30)
	var prev := PackedInt32Array()
	prev.resize(n)
	prev.fill(-1)
	var s := start.y * gs.x + start.x
	dist[s] = 0
	var cur := PackedInt32Array([s])
	var level := 0
	while not cur.is_empty():
		var nxt := PackedInt32Array()
		var i := 0
		while i < cur.size():
			var k: int = cur[i]
			i += 1
			if dist[k] != level:
				continue
			var x := k % gs.x
			var y := k / gs.x
			for d in 4:
				var nx := x + (1 if d == 0 else (-1 if d == 1 else 0))
				var ny := y + (1 if d == 2 else (-1 if d == 3 else 0))
				if nx < 0 or ny < 0 or nx >= gs.x or ny >= gs.y:
					continue
				var nk := ny * gs.x + nx
				if solid[nk] == 1:
					continue
				var c := 1 if haz[nk] > 0 else 0
				if level + c < dist[nk]:
					dist[nk] = level + c
					prev[nk] = k
					if c == 0:
						cur.append(nk)
					else:
						nxt.append(nk)
		cur = nxt
		level += 1
	return [dist, prev]


## The tiles of one shortest walk from `a` to `b` (traps ignored).
static func _route(ctx: Dictionary, a: Vector2i, b: Vector2i) -> Dictionary:
	var gs: Vector2i = ctx["gs"]
	var out := {}
	if not _inside(a, gs) or not _inside(b, gs):
		return out
	var saved: PackedByteArray = ctx["haz"]
	var none := PackedByteArray()
	none.resize(saved.size())
	ctx["haz"] = none
	var res := _search(ctx, a)
	ctx["haz"] = saved
	var prev: PackedInt32Array = res[1]
	var k := b.y * gs.x + b.x
	while k >= 0:
		out[Vector2i(k % gs.x, k / gs.x)] = true
		k = prev[k]
	return out


## Monsters never wait on a trap tile (a timed trap would kill them asleep):
## each moves to the nearest clear floor.
static func _move_monsters(ctx: Dictionary) -> void:
	var gs: Vector2i = ctx["gs"]
	for m in ctx["plan"].get("monsters", []):
		var t0 := tile_of(m[1])
		if _clear(ctx, t0):
			continue
		var seen := {t0: true}
		var q: Array = [t0]
		var qi := 0
		while qi < q.size() and qi < 400:
			var t: Vector2i = q[qi]
			qi += 1
			if _clear(ctx, t):
				m[1] = centre(t)
				break
			for d in DIRS4:
				var u: Vector2i = t + d
				if _inside(u, gs) and not seen.has(u) and ctx["solid"][u.y * gs.x + u.x] == 0:
					seen[u] = true
					q.append(u)


static func _clear(ctx: Dictionary, t: Vector2i) -> bool:
	var gs: Vector2i = ctx["gs"]
	if not _open(ctx, t):
		return false
	return ctx["haz"][t.y * gs.x + t.x] == 0


## clearPitsUnder: nothing that matters sits in a chasm (the start, the
## stair, doorways, the cache, springs, camps, monsters, the puzzle's pieces).
static func clear_pits(plan: Dictionary) -> void:
	var chasms: Array = plan.get("chasms", [])
	if chasms.is_empty():
		return
	var keep := {}
	var guard := func(pos: Vector2, r: int) -> void:
		var t := tile_of(pos)
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				keep[t + Vector2i(dx, dy)] = true
	guard.call(plan.get("start", Vector2(-1e6, -1e6)), 2)
	guard.call(plan.get("stair", Vector2(-1e6, -1e6)), 1)
	if plan.has("cache"):
		guard.call(plan["cache"]["pos"], 1)
	for sp in plan.get("springs", []):
		guard.call(sp["pos"], 1)
	for cp in plan.get("camps", []):
		guard.call(cp["pos"], 1)
		guard.call(cp["item"], 1)
	for d in plan.get("doors", []):
		for t in d["tiles"]:
			guard.call(centre(t), 1)
	for m in plan.get("monsters", []):
		guard.call(m[1], 0)
	var pz: Dictionary = plan.get("puzzle", {})
	for key in pz:
		if pz[key] is Array:
			for v in pz[key]:
				if v is Vector2:
					guard.call(v, 1)
				elif v is Rect2:
					guard.call(v.get_center(), 1)
	var tiles: Array = []
	var changed := false
	for r in chasms:
		for t in _tiles(r, Vector2i(9999, 9999)):
			if keep.has(t):
				changed = true
			else:
				tiles.append(t)
	if not changed:
		return
	tiles.sort_custom(func(x, y): return x.y < y.y or (x.y == y.y and x.x < y.x))
	var rects: Array = []
	for t in tiles:
		rects.append(Rect2(Floors.ORIGIN + Vector2(t) * C, Vector2(C, C)))
	plan["chasms"] = Rooms.merge_rows(rects)


# --- shapes ------------------------------------------------------------------

## The far end of a lane (its nozzle is `pos`).
static func lane_end(tr: Dictionary) -> Vector2:
	return tr["pos"] + tr["dir"] * C * maxf(float(tr["len"]) - 1.0, 0.0)


## Where a front (a dart, a sluice's wave) is in its lane right now.
static func front_of(tr: Dictionary) -> Vector2:
	var fire := maxf(val(tr, "fire"), 0.01)
	var prog := clampf(1.0 - float(tr["timer"]) / fire, 0.0, 1.0) if tr["state"] == "fire" else 0.0
	return tr["pos"] - tr["dir"] * C * 0.5 + tr["dir"] * C * float(tr["len"]) * prog


## A dart slot's eye, in the wall behind its lane.
static func slot_of(tr: Dictionary) -> Vector2:
	return tr["pos"] - tr["dir"] * C * 0.62


## How far a circle trap reaches right now (a gas cloud spreads as it starts).
func reach_of(tr: Dictionary) -> float:
	var reach := val(tr, "reach")
	if KINDS[tr["kind"]].has("tick") and tr["state"] == "fire":
		var age := val(tr, "fire") - float(tr["timer"])
		reach = lerpf(26.0, reach, clampf(age / 0.7, 0.0, 1.0))
	return reach


## Whether a point (with a body of radius `rad`) is inside a trap's reach.
func touches(tr: Dictionary, point: Vector2, rad: float) -> bool:
	var k: Dictionary = KINDS[tr["kind"]]
	if k["shape"] == "lane":
		var a: Vector2 = tr["pos"]
		var b := lane_end(tr)
		if k.has("speed") and tr["state"] == "fire":
			# A front only hurts where it is.
			var head := front_of(tr)
			var start: Vector2 = tr["pos"] - tr["dir"] * C * 0.5
			var tail: Vector2 = head - tr["dir"] * float(k["front"])
			if (tail - start).dot(tr["dir"]) < 0.0:
				tail = start
			a = tail
			b = head
			var cl := Geometry2D.get_closest_point_to_segment(point, a, b)
			var dd := point - cl
			var across: Vector2 = tr["dir"].orthogonal()
			return absf(dd.dot(across)) < C * 0.5 + rad * 0.5 and absf(dd.dot(tr["dir"])) < rad
		var closest := Geometry2D.get_closest_point_to_segment(point, a, b)
		var d := point - closest
		# A lane is a tile wide: measure across it as a square, not a circle.
		return absf(d.x) < C * 0.5 + rad * 0.5 and absf(d.y) < C * 0.5 + rad * 0.5
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
	# The resting traps are drawn once; draw them again only when they change.
	_check_floor_layer()
	# Redraw 30 times a second (plenty for the glows), not every tick.
	redraw_t -= delta
	if redraw_t <= 0.0:
		redraw_t = 1.0 / 30.0
		queue_redraw()


## Clears the climber's snare and slow (a new floor).
func reset() -> void:
	root_t = 0.0
	slow_t = 0.0
	if main != null and main.player != null:
		main.player.trap_slow = 1.0


func _tick_trap(tr: Dictionary, delta: float) -> void:
	if tr.get("off", false):
		return  # switched off (the Designer's Switch, secret_tools.gd): it rests until switched on
	var k: Dictionary = KINDS[tr["kind"]]
	var trigger: String = tr.get("trigger", k["trigger"])
	tr["timer"] -= delta
	match tr["state"]:
		"idle":
			if trigger == "timed":
				if tr["timer"] <= 0.0:
					_set_state(tr, "warn", val(tr, "warn") + tr["timer"])
					_warn_sound(tr)
			elif _stepped_on(tr):
				_set_state(tr, "warn", val(tr, "warn"))
				_warn_sound(tr)
		"warn":
			# The glint: a star and a ting just before it fires.
			if not tr.get("glint", false) and tr["timer"] <= GLINT_LEAD:
				tr["glint"] = true
				if _heard(tr) and bool(k.get("glint", true)):
					_trap_sfx("glint", 1.25, -10.0, 0.05)
			if tr["timer"] <= 0.0:
				_set_state(tr, "fire", val(tr, "fire") + tr["timer"])
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
					_set_state(tr, "idle", val(tr, "cycle") - val(tr, "warn") - val(tr, "fire") + tr["timer"])
				else:
					_set_state(tr, "rest", val(tr, "rest"))
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
	main.tip("hidden_trap" if tr["hidden"] else ("gas" if tr["kind"] == "gas" else "traps"))  # the Entity, the first time
	match tr["kind"]:
		"spikes":
			_trap_sfx("trap_click", 1.0, -2.0 if tr["trigger"] == "plate" else -16.0)  # the plate clicks
		"thorns":
			_trap_sfx("roll", 0.7, -8.0)  # a rustle
		"flame", "ember":
			_trap_sfx("burn", 0.8, -14.0)
		"sluice":
			_trap_sfx("hit_slime", 0.6, -14.0)
		"gust":
			_trap_sfx("gust", 0.7, -14.0)
		"dart":
			_trap_sfx("trap_click", 1.6, -12.0)  # the slot cocks
		"gas", "miasma":
			_trap_sfx("hiss", 1.0, -6.0 if tr["trigger"] == "plate" else -14.0)  # a hiss


## A trap's sound, but only once at a time: a whole row firing together
## makes one sound, not ten.
func _trap_sfx(sound: String, pitch: float, db: float, variance := 0.06) -> void:
	var now := Time.get_ticks_msec()
	if now - int(_last_sound.get(sound, -100000)) < 70:
		return
	_last_sound[sound] = now
	main.sfx(sound, pitch, db, variance)


## Only traps near the climber make noise.
func _heard(tr: Dictionary) -> bool:
	return main.player != null and main.player.global_position.distance_to(tr["pos"]) < 420.0


func _fire_effects(tr: Dictionary) -> void:
	var k: Dictionary = KINDS[tr["kind"]]
	var col: Color = k["color"]
	var pos: Vector2 = tr["pos"]
	# Embers leave the floor burning around them (jump over it).
	if tr["kind"] == "ember":
		main.add_flame(pos, k["burn_r"], val(tr, "burn_t"))
	if not _heard(tr):
		return
	match tr["kind"]:
		"gust":
			_trap_sfx("gust", 1.0, -6.0)
		"sluice":
			main.fx_burst(pos, tr["dir"] * 120.0, col, 6, 160.0)
			_trap_sfx("hit_slime", 0.8, -8.0)
		"flame":
			_trap_sfx("burn", 1.0, -8.0)
		"dart":
			_trap_sfx("bow", 1.5, -10.0)
		"spikes":
			main.fx_burst(pos, Vector2.ZERO, col, 4, 120.0)
			_trap_sfx("trap_spikes", 1.0, -8.0 if tr["trigger"] == "plate" else -16.0)  # (quieter: a row fires many at once)
		"ember":
			main.fx_burst(pos, Vector2.ZERO, col, 12, 260.0)
			_trap_sfx("burn", 0.9, -6.0)
		"thorns":
			main.fx_burst(pos, Vector2.ZERO, col, 10, 160.0)
			_trap_sfx("hit", 0.7, -6.0)
		"gas", "miasma":
			main.fx_burst(pos, Vector2.ZERO, col, 10, 90.0)
			_trap_sfx("hiss", 0.8, -2.0 if tr["trigger"] == "plate" else -10.0)


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
		# Spikes and snares only catch feet; water, fire, darts and gas catch everyone near.
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
	# Warding Oil: while its barrier holds, traps can't hurt you.
	if p.ward_oil_t > 0.0 and p.barrier_hp > 0.0:
		main.fx_text(p.global_position + Vector2(0, -44), "Warded", Color(0.72, 0.78, 0.95))
		main.fx_ring(p.global_position, Color(0.72, 0.78, 0.95), p.radius + 12.0, 0.25, 2.0)
		return
	p.receive_attack(tr["dmg"] * (1.0 - p.gfx("footing")), null, true)  # of Footing
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
	return _rest_look(tr)


## How plainly a resting trap's tell shows (drawn under the darkness, so
## even a plain one is only seen where light falls): hidden traps show
## nothing at all until you're close (see `_draw`), unless Keen Eyes.
func _rest_look(tr: Dictionary) -> float:
	if not tr["hidden"] or show_all or _keen():
		return 1.0
	return 0.0


## How strongly a trap shows its warning right now (0 to 1): a faint tell
## while it warns (spikes peeking, a slot's eye reddening, a wisp), never a
## flash.
func tell(tr: Dictionary) -> float:
	if tr["state"] != "warn":
		return 0.0
	var prog := clampf(1.0 - float(tr["timer"]) / maxf(val(tr, "warn"), 0.01), 0.0, 1.0)
	return 0.25 + 0.2 * prog


func _keen() -> bool:
	return main != null and main.player != null and main.player.has_bond("hunter")


## Whether the climber can see this trap clearly right now.
func seen(tr: Dictionary) -> bool:
	return visibility(tr) >= 1.0


## The lights of the traps for the darkness layer (lighting.gd): [pos,
## reach, colour, strength, glow] each. Only what really gives off light
## does: fire jets, falling embers, and a dart slot's eye in the moment
## before it fires; the rest stay in the dark, so a trap is only seen where
## the climber's light or a torch falls (one light per patch of floor).
func glow_list() -> Array:
	var out: Array = []
	if main == null:
		return out
	var used := {}
	for tr in main.traps:
		var st: String = tr["state"]
		var kind: String = tr["kind"]
		var pos: Vector2
		var reach: float
		var k := 0.6
		if st == "fire" and kind == "flame":
			pos = (tr["pos"] + lane_end(tr)) * 0.5
			reach = float(tr["len"]) * C * 0.5 + 40.0
		elif st == "fire" and kind == "ember":
			pos = tr["pos"]
			reach = reach_of(tr) + 50.0
		elif st == "warn" and kind == "dart" and float(tr["timer"]) <= GLINT_LEAD:
			pos = slot_of(tr)
			reach = 46.0
			k = 0.35
		else:
			continue
		var key := Vector2i(int(floor(pos.x / 110.0)), int(floor(pos.y / 110.0)))
		if used.has(key):
			continue
		used[key] = true
		out.append([pos, reach, KINDS[kind]["color"], k, 0.12])
		if out.size() >= 16:
			break
	return out


# --- drawing -------------------------------------------------------------------

func _ready() -> void:
	z_index = -5  # on the floor: over the room, under everyone
	floor_layer = Node2D.new()
	floor_layer.show_behind_parent = true
	add_child(floor_layer)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_free_floor_layer()


func _free_floor_layer() -> void:
	for ci in _static_items:
		RenderingServer.free_rid(ci)
	_static_items.clear()


## Redraws the resting traps if the list (or what the climber can see) changed.
func _check_floor_layer() -> void:
	if main == null or floor_layer == null:
		return
	var keen := _keen()
	if is_same(_drawn_list, main.traps) and _drawn_n == main.traps.size() and _drawn_keen == keen and _drawn_show == show_all and is_same(_drawn_marks, floor_marks):
		return
	_drawn_list = main.traps
	_drawn_n = main.traps.size()
	_drawn_keen = keen
	_drawn_show = show_all
	_drawn_marks = floor_marks
	_free_floor_layer()
	var parts := {}  # a square of the floor -> its Batch
	var batch_at := func(pos: Vector2) -> Draw.Batch:
		var key := Vector2i(int(floor(pos.x / 400.0)), int(floor(pos.y / 400.0)))
		if not parts.has(key):
			parts[key] = Draw.Batch.new()
		return parts[key]
	for m in floor_marks.get("decor", []):
		_draw_decor(batch_at.call(m[1].get_center()), String(m[0]), m[1])
	for m in floor_marks.get("paths", []):
		_draw_path(batch_at.call(m[1].get_center()), String(m[0]), m[1])
	for tr in main.traps:
		_draw_rest(batch_at.call(tr["pos"]), tr, _rest_look(tr))
	var parent := floor_layer.get_canvas_item()
	for key in parts:
		var b: Draw.Batch = parts[key]
		if b.size() == 0:
			continue
		var ci := RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(ci, parent)
		RenderingServer.canvas_item_add_triangle_array(ci, PackedInt32Array(), b.pts, b.cols)
		_static_items.append(ci)


## The world on screen, with room for a lane's length.
func _view_rect() -> Rect2:
	var cam := get_viewport().get_camera_2d()
	if cam == null:
		return Rect2(-1e6, -1e6, 2e6, 2e6)
	var size := get_viewport_rect().size / cam.zoom
	return Rect2(cam.get_screen_center_position() - size * 0.5, size).grow(80.0)


## The strip of floor a lane covers.
static func lane_rect(tr: Dictionary) -> Rect2:
	var a: Vector2 = tr["pos"]
	var b := lane_end(tr)
	var half := C * 0.5
	return Rect2(a.min(b) - Vector2(half, half), (b - a).abs() + Vector2(half, half) * 2.0)


## A rect's outline as four thin rects.
static func _outline(b: Draw.Batch, r: Rect2, col: Color, w: float) -> void:
	b.rect(Rect2(r.position.x, r.position.y, r.size.x, w), col)
	b.rect(Rect2(r.position.x, r.end.y - w, r.size.x, w), col)
	b.rect(Rect2(r.position.x, r.position.y + w, w, r.size.y - w * 2.0), col)
	b.rect(Rect2(r.end.x - w, r.position.y + w, w, r.size.y - w * 2.0), col)


## Only the traps warning or firing (and Keen Eyes' outlines) are drawn each
## frame, in one batch; the resting look is in floor_layer.
func _draw() -> void:
	if main == null:
		return
	var t := Time.get_ticks_msec() * 0.001
	var keen := _keen()
	var view := _view_rect()
	var b := Draw.Batch.new()
	var pp: Vector2 = main.player.global_position if main.player != null else Vector2(-1e6, -1e6)
	for tr in main.traps:
		var state: String = tr["state"]
		var hint: bool = tr["hidden"] and (keen or show_all or main.flare_reveals(tr["pos"])) and state == "idle"
		# A hidden trap at rest shows its tell only right under your nose.
		var near: float = 0.0
		if tr["hidden"] and not keen and not show_all and (state == "idle" or state == "rest"):
			near = clampf(1.0 - tr["pos"].distance_to(pp) / float(RULES["notice"]), 0.0, 1.0)
		if state != "warn" and state != "fire" and not hint and not show_all and near <= 0.0:
			continue
		var k: Dictionary = KINDS[tr["kind"]]
		var lane: bool = k["shape"] == "lane"
		if not (view.has_point(tr["pos"]) or (lane and view.intersects(lane_rect(tr)))):
			continue  # (off screen: not drawn)
		var pos: Vector2 = tr["pos"]
		var col: Color = k["color"]
		var half := C * 0.5 - 3.0
		if near > 0.0:
			_draw_rest(b, tr, near * 0.8)
		if hint:
			var pulse := 0.5 + 0.3 * sin(t * 3.0)
			_outline(b, Rect2(pos - Vector2(half + 3.0, half + 3.0), Vector2(half + 3.0, half + 3.0) * 2.0), Color(0.95, 0.8, 0.5, pulse), 1.5)
		if show_all and not lane:
			b.arc(pos, val(tr, "reach"), 0.0, TAU, 28, Color(col, 0.5), 1.0)
		if state == "warn":
			_draw_warn(b, tr, t)
		elif state == "fire":
			_draw_firing(b, tr, t)
	# A climber caught in a snare: vines around the feet.
	if root_t > 0.0 and main.player != null:
		var feet: Vector2 = main.player.global_position
		b.arc(feet + Vector2(0, 6), 14.0, 0.0, TAU, 16, Color(0.45, 0.7, 0.3, 0.9), 3.0)
	b.flush(self)


## A trap at rest: only a faint tell on its tile (`a` = how plainly), never
## its reach: a few small holes, a grate, a scorch ring, cracks, a slit in
## the wall. Drawn under the darkness, so it's only seen in the light.
func _draw_rest(b: Draw.Batch, tr: Dictionary, a: float) -> void:
	if a <= 0.0:
		return
	var pos: Vector2 = tr["pos"]
	var half := C * 0.5 - 3.0
	var kind: String = tr["kind"]
	var dark := Color(0.04, 0.035, 0.045, 0.5 * a)
	match kind:
		"dart":
			# A slit in the wall; its eye is dark until it's about to fire.
			var d: Vector2 = tr["dir"]
			var s := slot_of(tr)
			var side := d.orthogonal()
			b.polygon(PackedVector2Array([s + side * 8.0 - d * 3.0, s + side * 8.0 + d * 3.0, s - side * 8.0 + d * 3.0, s - side * 8.0 - d * 3.0]), Color(0.04, 0.03, 0.04, 0.75 * a))
		"gust", "sluice", "flame":
			# A grate in the floor, slats across the way it fires.
			var d: Vector2 = tr["dir"]
			var side := d.orthogonal()
			for i in 3:
				var off := (i - 1) * (half - 6.0) * 0.7
				b.line(pos + side * (half - 7.0) + d * off, pos - side * (half - 7.0) + d * off, dark, 2.0)
			if kind == "flame":
				b.circle(pos, half - 4.0, Color(0.1, 0.05, 0.03, 0.18 * a), 16)  # scorched
		"ember":
			b.arc(pos, half - 5.0, 0.0, TAU, 14, Color(0.12, 0.06, 0.03, 0.4 * a), 2.0)  # a scorch ring
		"spikes":
			for x in 3:
				for y in 3:
					b.circle(pos + Vector2(x - 1, y - 1) * 11.0, 1.6, dark, 6)
		"thorns":
			b.arc(pos, 9.0, 0.0, TAU, 10, Color(0.35, 0.5, 0.22, 0.5 * a), 1.4)  # a loop of vine
		"gas", "miasma":
			# Cracks in the stone.
			b.line(pos + Vector2(-9, -3), pos + Vector2(0, 1), dark, 1.4)
			b.line(pos + Vector2(0, 1), pos + Vector2(7, -6), dark, 1.4)
			b.line(pos + Vector2(0, 1), pos + Vector2(3, 9), dark, 1.4)


## A set piece's path, laid into the floor: trodden earth through brambles,
## clean pale stones through a miasma.
func _draw_path(b: Draw.Batch, look: String, r: Rect2) -> void:
	var col := Color(0.55, 0.45, 0.3, 0.22) if look == "trodden" else Color(0.85, 0.9, 0.8, 0.16)
	b.rect(r.grow(-5.0), col)
	_outline(b, r.grow(-5.0), Color(col.lightened(0.3), col.a * 1.4), 1.0)


## Decor across a set piece's room: bramble tufts, a gas stain.
func _draw_decor(b: Draw.Batch, look: String, r: Rect2) -> void:
	var c := r.get_center()
	var h := absi(int(c.x * 7.0 + c.y * 13.0)) % 97
	if look == "bramble":
		var col := Color(0.32, 0.5, 0.2, 0.75)
		for i in 4:
			var ang := TAU * (i / 4.0) + h * 0.1
			var p := c + Vector2.from_angle(ang) * (6.0 + (h + i * 5) % 7)
			b.line(p, p + Vector2.from_angle(ang + 1.2) * 9.0, col, 1.6)
			b.line(p, p + Vector2.from_angle(ang - 1.0) * 7.0, col.darkened(0.2), 1.3)
	else:
		b.rect(r, Color(0.45, 0.55, 0.2, 0.08 + 0.03 * (h % 3)))


## A trap about to go off: a faint tell only (see `tell`): spikes peek out
## of their holes, a grate shimmers, a slot's eye reddens, a wisp curls up,
## a vine twitches, a mark warms. Some kinds glint in the last moment (the
## ones with a nozzle, a slot or a mark); spikes, snares and gas don't.
func _draw_warn(b: Draw.Batch, tr: Dictionary, t: float) -> void:
	var k: Dictionary = KINDS[tr["kind"]]
	var pos: Vector2 = tr["pos"]
	var col: Color = k["color"]
	var a := tell(tr)
	var prog := clampf(1.0 - float(tr["timer"]) / maxf(val(tr, "warn"), 0.01), 0.0, 1.0)
	var star_at := pos
	match tr["kind"]:
		"dart":
			var s := slot_of(tr)
			b.circle(s, 2.0 + 1.5 * prog, Color(0.9, 0.25, 0.2, a + 0.3 * prog), 10)
			star_at = s
		"gust", "sluice", "flame":
			var d: Vector2 = tr["dir"]
			b.circle(pos + d * 6.0, 7.0 + 3.0 * sin(t * 20.0), Color(col, a * 0.5), 12)
		"spikes":
			var lift := 1.0 + 3.0 * prog
			for x in 3:
				for y in 3:
					var c: Vector2 = pos + Vector2(x - 1, y - 1) * 11.0
					b.polygon(PackedVector2Array([c + Vector2(-2, 1.5), c + Vector2(2, 1.5), c + Vector2(0, -lift)]), Color(0.75, 0.75, 0.8, a + 0.2))
		"ember":
			b.circle(pos, reach_of(tr) * (0.4 + 0.6 * prog), Color(col, 0.05 + 0.07 * prog), 24)
		"thorns":
			b.arc(pos, 9.0 + 2.0 * sin(t * 30.0), 0.0, TAU, 10, Color(0.5, 0.75, 0.3, a + 0.2), 1.6)
		"gas", "miasma":
			for i in 2:
				var w := pos + Vector2(sin(t * 3.0 + i * 2.0) * 5.0, -6.0 - 10.0 * fmod(prog + i * 0.5, 1.0))
				b.circle(w, 4.0 + 3.0 * prog, Color(col, a * 0.6), 10)
	# The glint: a small star in the last moment, for the kinds that have one.
	if bool(k.get("glint", true)) and float(tr["timer"]) <= GLINT_LEAD:
		var g := 1.0 - clampf(float(tr["timer"]) / GLINT_LEAD, 0.0, 1.0)
		var s := 4.0 + 5.0 * g
		var star := Color(1, 1, 1, 0.85)
		b.line(star_at + Vector2(-s, 0), star_at + Vector2(s, 0), star, 1.5)
		b.line(star_at + Vector2(0, -s), star_at + Vector2(0, s), star, 1.5)


func _draw_firing(b: Draw.Batch, tr: Dictionary, t: float) -> void:
	var k: Dictionary = KINDS[tr["kind"]]
	var pos: Vector2 = tr["pos"]
	var col: Color = k["color"]
	var reach := reach_of(tr)
	var d: Vector2 = tr["dir"]
	var lane_r := lane_rect(tr)
	match tr["kind"]:
		"gust":
			b.rect(lane_r, Color(col, 0.18))
			for i in 6:
				var side: Vector2 = d.orthogonal() * ((i - 2.5) * 5.0)
				var along := fmod(t * 600.0 + i * 37.0, C * float(tr["len"]))
				var a2: Vector2 = pos - d * C * 0.5 + side + d * along
				b.line(a2, a2 + d * 18.0, Color(col, 0.75), 2.0)
		"sluice":
			var head := front_of(tr)
			var start: Vector2 = pos - d * C * 0.5
			var wet := Rect2(start.min(head), (head - start).abs()).grow_individual(
				0.0 if d.x != 0.0 else C * 0.5, 0.0 if d.y != 0.0 else C * 0.5, 0.0 if d.x != 0.0 else C * 0.5, 0.0 if d.y != 0.0 else C * 0.5)
			b.rect(wet, Color(col, 0.35))
			b.circle(head, 16.0, Color(0.85, 0.97, 1.0, 0.8), 20)
			b.circle(head - d * 14.0, 11.0, Color(0.7, 0.92, 1.0, 0.6), 16)
		"flame":
			b.rect(lane_r, Color(col, 0.45))
			for i in int(tr["len"]) * 3:
				var c: Vector2 = pos + d * (i * C / 3.0)
				var flick := 8.0 + 4.0 * sin(t * 18.0 + i)
				b.circle(c, flick, Color(1.0, 0.8, 0.35, 0.8), 14)
			b.circle(pos, 10.0, Color(1.0, 0.92, 0.6, 0.9), 14)
		"dart":
			var head := front_of(tr)
			b.line(head - d * 16.0, head, Color(0.9, 0.85, 0.75), 2.0)
			b.polygon(PackedVector2Array([head + d * 5.0, head + d.orthogonal() * 3.0, head - d.orthogonal() * 3.0]), Color(0.95, 0.95, 1.0))
			b.line(head - d * 16.0 + d.orthogonal() * 3.0, head - d * 12.0, Color(col, 0.9), 1.5)
			b.line(head - d * 16.0 - d.orthogonal() * 3.0, head - d * 12.0, Color(col, 0.9), 1.5)
			b.circle(slot_of(tr), 2.5, Color(0.9, 0.3, 0.25, 0.6), 10)
		"spikes":
			for x in 3:
				for y in 3:
					var c: Vector2 = pos + Vector2(x - 1, y - 1) * 11.0
					b.polygon(PackedVector2Array([c + Vector2(-4, 3), c + Vector2(4, 3), c + Vector2(0, -12)]), Color(0.86, 0.86, 0.9))
		"ember":
			b.circle(pos, reach, Color(col, 0.3), 32)
			b.arc(pos, reach, 0.0, TAU, 28, Color(1.0, 0.85, 0.5, 0.9), 3.0)
		"thorns":
			for i in 7:
				var ang := TAU * i / 7.0
				b.line(pos + Vector2.from_angle(ang) * 4.0, pos + Vector2.from_angle(ang + 0.35) * reach, Color(0.45, 0.7, 0.3, 0.95), 3.0)
		"gas", "miasma":
			# A drifting cloud: soft overlapping puffs, thinning as it ends.
			var fade := clampf(float(tr["timer"]) / 1.0, 0.0, 1.0)
			b.circle(pos, reach, Color(col, 0.22 * fade), 32)
			for i in 6:
				var ang := TAU * i / 6.0 + t * 0.4
				var r := reach * (0.45 + 0.15 * sin(t * 1.3 + i))
				b.circle(pos + Vector2.from_angle(ang) * r, reach * 0.42, Color(col.darkened(0.1), 0.16 * fade), 20)
			b.arc(pos, reach, 0.0, TAU, 28, Color(col, 0.5 * fade), 1.5)
