extends Node2D
## Doors in the doorways of a floor of rooms (floors.gd decides where). A
## closed door is a solid tile: it blocks movement (its own collision body),
## sight (fog.gd reads main.solid) and paths (main.astar). It opens when the
## climber walks up to it, or when an awake monster does, with a thud and a
## puff of dust, and opening it reveals the room behind.
##
## A door's look hints at what waits inside (the room theme's "door" in
## themes.gd), never at the reward:
##   plank    plain planks and two iron bands: an ordinary room
##   den      dark wood, heavy bands, claw marks, bones at the threshold
##   hazard   an iron plate engraved with the hazard's sigil
##   puzzle   a stone door bearing the puzzle's emblem
##   warm     warm light spilling out under it: a good room
##   chained  chains across it and a red glow under it: danger
##   sealed   a stone slab carved with a watching eye, red light under it: a
##            sealed wing (wings.gd), where the Regard tests you
## The Proving's doors (floor 6, proving.gd):
##   proving  a stone slab bearing a gold six-pointed star, gold light under it
##   lethal   the same slab, blackened, its star red and cracked, red light under it
##   crown    an iron-banded door bearing a crown: the sentinel waits
##   shade    a dark slab with a pale beast's eye, violet light under it: the shadow
##
## Drawn once and only redrawn while a door swings open, so it costs nothing
## per frame. main.gd owns one of these (`main.door_view`).

const Palette := preload("res://scripts/palette.gd")
const Draw := preload("res://scripts/draw_util.gd")
const Themes := preload("res://scripts/themes.gd")

## A door opens when a body's edge comes this close to it (px).
const REACH := 24.0
const OPEN_TIME := 0.3
## How often awake monsters are checked against the doors (seconds).
const MONSTER_CHECK := 0.1
## The colours of the hazard sigils (the tower's trap) and the glows under doors.
const SIGIL_COLORS := {
	"wind": Color(0.78, 0.9, 1.0), "wave": Color(0.45, 0.85, 0.95), "flame": Color(1.0, 0.55, 0.22),
	"spike": Color(0.9, 0.82, 0.62), "ember": Color(1.0, 0.7, 0.3), "thorn": Color(0.6, 0.85, 0.4),
	"chasm": Color(0.62, 0.5, 0.85), "dart": Color(0.95, 0.3, 0.25), "gas": Color(0.66, 0.78, 0.32),
}
const WARM := Color(1.0, 0.74, 0.4)
const RED := Color(0.95, 0.22, 0.15)
const EMBLEM := Color(0.75, 0.55, 1.0)
const PROVING_GOLD := Color(1.0, 0.82, 0.4)  # the Proving's doors (proving.gd)
const SHADE_GLOW := Color(0.62, 0.52, 0.95)

## LOCKED DOORS (floors.gd decides which, always off the main route): a
## locked door won't open for anyone until its lock is undone; bump it and
## it says so, and how it opens. Drawn over its usual look (so it still
## hints at the room), never hinting at the reward:
##   key / carried   a padlock: a key lies in another room, or a monster carries one
##   lever           iron bars across it: strike a lever elsewhere
##   puzzle          a violet ward: solve the floor's puzzle
## LOCK-IN ROOMS: some rooms (LOCK_IN) shut their doorways behind you as
## you step in (iron bars drop with a slam and a banner), and open again
## once the monsters that were inside are dead. A room with none never shuts,
## and LOCK_IN["failsafe"] seconds open it whatever happens.
const LOCK_TEXT := {
	"hint_key": "Locked. Its key lies somewhere on this floor.",
	"hint_carried": "Locked. One of this floor's monsters carries its key.",
	"hint_lever": "Barred. A lever somewhere on this floor lifts the bars.",
	"hint_puzzle": "Warded. Solving this floor's puzzle opens it.",
	"locked": "Locked",
	"key_found": "+ A key",
	"key_turns": "The key turns",
	"lever_pulled": "Somewhere, bars lift",
	"lever_title": "A LEVER",
	"lever_line": "Somewhere on this floor, a barred door opens.",
	"puzzle_line": "A warded door opens somewhere.",
	"shut_title": "THE DOORS GRIND SHUT",
	"shut": "Nothing leaves until what's here has fallen.",
	"open_title": "THE DOORS GRIND OPEN",
	"status": "THE DOORS ARE SHUT",
	"left": "%d left",
}
## Which rooms lock you in (by theme, or by role), and how often; the stair
## landing only from a higher floor. Checked a few times a second.
const LOCK_IN := {"den": 0.75, "crypt": 0.9, "guard": 0.3, "landing": 0.6, "landing_from": 6, "failsafe": 150.0, "check": 0.25}
const KEY_GOLD := Color(1.0, 0.82, 0.38)
const WARD := Color(0.75, 0.55, 1.0)

var main
var list: Array = []  # {tiles, rect, horiz, out, room, style, sigil, emblem, open, t, body, lock, lock_id}
var glow: Node2D  # light under warm and chained doors, unshaded so it reads in the dark
var monster_t := 0.0
var animating := false
var keys: Array = []  # keys lying on the floor: {pos, lock_id, taken, light}
var levers: Array = []  # {pos, lock_id, pulled, light}
var held: Array = []  # lock ids whose key the climber carries
var bump_t := 0.0  # until a locked door says so again
var bumps := 0  # times a locked door was bumped (tests)
var lock_rooms := {}  # room index -> {state: armed, pending, shut, done; gates, bodies, mobs, t}
var lock_check := 0.0


func _ready() -> void:
	z_index = -4  # on the floor, under everyone
	glow = Node2D.new()
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	glow.material = unlit
	glow.draw.connect(_draw_glow)
	add_child(glow)


## A new floor: takes away the old doors (their tiles go with the old grid).
func clear() -> void:
	for d in list:
		if is_instance_valid(d["body"]):
			d["body"].queue_free()
		_drop_light(d)
	list.clear()
	for k in keys + levers:
		if k.has("light") and main != null and main.lighting != null:
			main.lighting.remove_light(k["light"])
	keys.clear()
	levers.clear()
	held.clear()
	for i in lock_rooms:
		for b in lock_rooms[i].get("bodies", []):
			if is_instance_valid(b):
				b.queue_free()
	lock_rooms.clear()
	animating = false
	_redraw()


## Hangs the floor's doors: `defs` from the plan ({tiles, horiz, out, room,
## and lock, lock_id, lock_pos, lock_carrier if locked}), `themes` the theme
## id of each room. Call once the layout is built. Also picks the rooms that
## will lock you in.
func build(defs: Array, themes: Array) -> void:
	clear()
	if main == null or not main.layout_on:
		return
	for def in defs:
		_hang(def, themes)
	var info: Array = main.room_info
	for i in info.size():
		if _locks_in(info[i], themes[i] if i < themes.size() else "") and not info[i].get("gates", []).is_empty():
			lock_rooms[i] = {"state": "armed", "gates": info[i]["gates"], "bodies": [], "mobs": [], "t": 0.0}
	_redraw()


func _locks_in(info: Dictionary, theme: String) -> bool:
	var role: String = info["role"]
	if role in ["entrance", "gallery"]:
		return false
	var chance := 0.0
	if LOCK_IN.has(theme) and theme != "landing":
		chance = float(LOCK_IN[theme])
	elif role == "stair":
		chance = float(LOCK_IN["landing"]) if main.floor_num >= int(LOCK_IN["landing_from"]) else 0.0
	elif role == "guard":
		chance = float(LOCK_IN["guard"])
	return randf() < chance


## Hangs one more door after build(): `def` as in build(), with its look
## given as "style" whatever room it leads to (a sealed wing's, wings.gd).
func add_door(def: Dictionary) -> Dictionary:
	if main == null or not main.layout_on:
		return {}
	var d := _hang(def, [])
	_redraw()
	return d


func _hang(def: Dictionary, themes: Array) -> Dictionary:
	var c: float = main.Floors.CELL
	var tiles: Array = def["tiles"]
	var a: Vector2i = tiles[0]
	var b: Vector2i = tiles[-1]
	var lo := Vector2i(mini(a.x, b.x), mini(a.y, b.y))
	var hi := Vector2i(maxi(a.x, b.x), maxi(a.y, b.y))
	var rect := Rect2(main.room.position + Vector2(lo) * c, Vector2(hi - lo + Vector2i.ONE) * c)
	var d := {"tiles": tiles, "rect": rect, "horiz": def["horiz"], "out": def["out"], "room": def["room"],
		"open": false, "t": 0.0, "body": null, "fixed": def.get("style", ""),
		"lock": String(def.get("lock", "")), "lock_id": int(def.get("lock_id", 0))}
	_style(d, themes)
	if d["lock"] in ["key", "lever"] and def.has("lock_pos"):
		var item := {"pos": def["lock_pos"], "lock_id": d["lock_id"], "taken": false, "pulled": false}
		if d["lock"] == "key":
			item["light"] = main.lighting.add_light(item["pos"], 70.0, KEY_GOLD, 0.5, 0.18)
			keys.append(item)
		else:
			item["light"] = main.lighting.add_light(item["pos"], 70.0, Color(0.8, 0.85, 1.0), 0.4, 0.1)
			levers.append(item)
	for t in tiles:
		_set_tile(t, true)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = rect.get_center()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	body.add_child(shape)
	main.add_child(body)
	d["body"] = body
	list.append(d)
	_add_light(d)
	return d


## Warm and chained doors cast a little light from under them (through the
## darkness layer, so it shows from across the room).
func _add_light(d: Dictionary) -> void:
	_drop_light(d)
	if main == null or main.lighting == null:
		return
	var col: Color = _glow_color(String(d.get("style", "")))
	if col.a <= 0.0:
		return
	var edge := _edge(d["rect"], d["out"])
	var at: Vector2 = (edge[0] + edge[1]) * 0.5 + Vector2(d["out"]) * 16.0
	d["light"] = main.lighting.add_light(at, 80.0, col, 0.55, 0.35)


## The light under a door of this style (none: alpha 0).
func _glow_color(style: String) -> Color:
	match style:
		"warm":
			return WARM
		"chained", "sealed", "lethal":
			return RED
		"shade":
			return SHADE_GLOW
		"proving":
			return PROVING_GOLD
	return Color(0, 0, 0, 0)


func _drop_light(d: Dictionary) -> void:
	if d.has("light") and main != null and main.lighting != null:
		main.lighting.remove_light(d["light"])
	d.erase("light")


## Updates each door's look after the rooms' themes changed.
func restyle(themes: Array) -> void:
	for d in list:
		_style(d, themes)
		_add_light(d)
	_redraw()


func _style(d: Dictionary, themes: Array) -> void:
	if d.get("fixed", "") != "":
		d["theme"] = ""
		d["style"] = d["fixed"]
		d["sigil"] = ""
		d["emblem"] = ""
		return
	var id: String = themes[d["room"]] if d["room"] >= 0 and d["room"] < themes.size() else "quiet"
	var th: Dictionary = Themes.get_theme(id)
	d["theme"] = id
	d["style"] = th.get("door", "plank")
	d["sigil"] = th.get("sigil", "")
	d["emblem"] = th.get("emblem", "")


func _set_tile(t: Vector2i, closed: bool) -> void:
	var gs: Vector2i = main.grid_size
	if t.x < 0 or t.y < 0 or t.x >= gs.x or t.y >= gs.y:
		return
	main.solid[t.y * gs.x + t.x] = 1 if closed else 0
	if main.astar != null:
		main.astar.set_point_solid(t, closed)


func closed_count() -> int:
	return list.filter(func(d): return not d["open"]).size()


## The door on a grid tile, or {}.
func door_at(t: Vector2i) -> Dictionary:
	for d in list:
		if t in d["tiles"]:
			return d
	return {}


## Opens every door, locked ones too (the dev tool, and tests).
func open_all() -> void:
	for d in list:
		d["lock"] = ""
		if not d["open"]:
			open_door(d, true)


## Undoes a lock (its key turned, its lever struck, its puzzle solved).
func unlock(lock_id: int) -> void:
	for d in list:
		if d["lock"] != "" and int(d["lock_id"]) == lock_id:
			d["lock"] = ""
			main.fx_burst(d["rect"].get_center(), d["out"], KEY_GOLD, 10, 90.0)
	_redraw()


## The floor's puzzle is solved: warded doors open their wards (main.lift_ward).
func unlock_puzzle() -> bool:
	var any := false
	for d in list:
		if d["lock"] == "puzzle":
			unlock(int(d["lock_id"]))
			any = true
	return any


func locked_count() -> int:
	return list.filter(func(d): return d["lock"] != "").size()


## The climber bumps a locked door: it says it's locked, and how it opens;
## with its key in hand, the key turns and it opens.
func _bump(d: Dictionary) -> void:
	if main.proving != null and main.proving.bump(d):
		return  # (one of the Proving's doors: it answers for itself)
	if d["lock_id"] in held and d["lock"] in ["key", "carried"]:
		held.erase(d["lock_id"])
		unlock(int(d["lock_id"]))
		main.fx_text(d["rect"].get_center() + Vector2(0, -30), LOCK_TEXT["key_turns"], KEY_GOLD)
		main.sfx("crossbow_load", 0.8, -4.0, 0.0)
		open_door(d)
		return
	if bump_t > 0.0:
		return
	bump_t = 1.6
	bumps += 1
	main.fx_text(d["rect"].get_center() + Vector2(0, -30), LOCK_TEXT["locked"], Color(0.9, 0.75, 0.55))
	main.banner = {"title": String(LOCK_TEXT["locked"]).to_upper(), "lines": [LOCK_TEXT["hint_" + String(d["lock"])]], "t": 2.2}
	main.tip("door_locked")
	main.sfx("hit_armor", 0.55, -4.0, 0.0)
	main.sfx("step_chain", 0.7, -8.0, 0.0)


## A melee swing (player.gd): a lever in reach is pulled.
func strike(from: Vector2, dir: Vector2, reach: float, arc_deg: float) -> void:
	for l in levers:
		if l["pulled"]:
			continue
		var to: Vector2 = l["pos"] - from
		if to.length() <= reach + 22.0 and absf(dir.angle_to(to)) <= deg_to_rad(arc_deg) + 0.3:
			pull(l)


func pull(l: Dictionary) -> void:
	l["pulled"] = true
	if l.has("light"):
		main.lighting.remove_light(l["light"])
		l.erase("light")
	unlock(int(l["lock_id"]))
	main.fx_text(l["pos"] + Vector2(0, -30), LOCK_TEXT["lever_pulled"], Color(0.8, 0.85, 1.0))
	main.banner = {"title": LOCK_TEXT["lever_title"], "lines": [LOCK_TEXT["lever_line"]], "t": 2.5}
	main.sfx("crossbow_reload", 0.6, -2.0, 0.0)
	main.sfx("slam", 1.4, -10.0, 0.0)
	main.shake(4.0)
	_redraw()


## Picks up a key lying where the climber walks.
func _take_key(k: Dictionary) -> void:
	k["taken"] = true
	held.append(k["lock_id"])
	if k.has("light"):
		main.lighting.remove_light(k["light"])
		k.erase("light")
	main.fx_text(main.player.global_position + Vector2(0, -44), LOCK_TEXT["key_found"], KEY_GOLD)
	main.sfx("pickup", 1.1, -2.0, 0.0)
	_redraw()


## The monsters main.gd spawned, in the plan's order: the key carriers get their key.
func tag_carriers(defs: Array, spawned: Array) -> void:
	for def in defs:
		var c := int(def.get("lock_carrier", -1))
		if def.get("lock", "") == "carried" and c >= 0 and c < spawned.size():
			spawned[c].set_meta("key", int(def["lock_id"]))


## A monster fell: if it carried a key, it drops it.
func on_enemy_killed(e) -> void:
	if e.has_meta("key"):
		var k := {"pos": e.global_position, "lock_id": int(e.get_meta("key")), "taken": false}
		k["light"] = main.lighting.add_light(k["pos"], 70.0, KEY_GOLD, 0.5, 0.18)
		keys.append(k)
		e.remove_meta("key")
		main.fx_text(e.global_position + Vector2(0, -48), "It dropped a key", KEY_GOLD)
		_redraw()


# --- lock-in rooms -----------------------------------------------------------------

## The climber walked into room `i` (main.gd, the first time): a lock-in room
## waits for them to be well inside.
func room_entered(i: int) -> void:
	if lock_rooms.has(i) and lock_rooms[i]["state"] == "armed":
		lock_rooms[i]["state"] = "pending"


func _gate_tiles(lr: Dictionary) -> Array:
	var out: Array = []
	for g in lr["gates"]:
		out.append_array(g)
	return out


func _tick_lock_rooms(delta: float) -> void:
	lock_check -= delta
	var p = main.player
	for i in lock_rooms:
		var lr: Dictionary = lock_rooms[i]
		match String(lr["state"]):
			"pending":
				var rect: Rect2 = main.room_info[i]["rect"]
				if p.dead or not rect.grow(-30.0).has_point(p.global_position):
					continue
				var mobs: Array = main.enemies().filter(func(e): return rect.grow(-2.0).has_point(e.global_position))
				if mobs.is_empty():
					lr["state"] = "done"  # (nothing here to fight: it never shuts)
					continue
				var blocked := false
				for g in lr["gates"]:
					var gr := _tiles_rect(g)
					for e in main.enemies():
						blocked = blocked or gr.grow(e.radius).has_point(e.global_position)
					blocked = blocked or gr.grow(p.radius).has_point(p.global_position)
				if not blocked:
					_shut(lr, mobs)
			"shut":
				lr["t"] += delta
				if lock_check <= 0.0 and not lr.get("hold", false):  # (held shut: the Proving's gauntlet)
					var alive: Array = lr["mobs"].filter(func(e): return is_instance_valid(e) and not e.dead)
					if alive.is_empty() or lr["t"] > float(LOCK_IN["failsafe"]):
						_reopen(lr)
	if lock_check <= 0.0:
		lock_check = float(LOCK_IN["check"])


func _tiles_rect(tiles: Array) -> Rect2:
	var c: float = main.Floors.CELL
	var r := Rect2(main.room.position + Vector2(tiles[0]) * c, Vector2(c, c))
	for t in tiles:
		r = r.merge(Rect2(main.room.position + Vector2(t) * c, Vector2(c, c)))
	return r


func _shut(lr: Dictionary, mobs: Array) -> void:
	lr["state"] = "shut"
	lr["mobs"] = mobs
	lr["t"] = 0.0
	for g in lr["gates"]:
		var dd := door_at(g[0])
		if not dd.is_empty() and not dd["open"]:
			open_door(dd, true)
		for t in g:
			_set_tile(t, true)
		var rect := _tiles_rect(g)
		var body := StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		body.position = rect.get_center()
		var shape := CollisionShape2D.new()
		var box := RectangleShape2D.new()
		box.size = rect.size
		shape.shape = box
		body.add_child(shape)
		main.add_child(body)
		lr["bodies"].append(body)
		main.fx_burst(rect.get_center(), Vector2.ZERO, Color(0.54, 0.51, 0.59), 10, 110.0)
	main.shake(7.0)
	main.sfx("slam", 0.6, 0.0, 0.0)
	main.sfx("step_chain", 0.5, -4.0, 0.0)
	main.banner = {"title": LOCK_TEXT["shut_title"], "lines": [LOCK_TEXT["shut"]], "t": 2.6}
	_redraw()


func _reopen(lr: Dictionary) -> void:
	lr["state"] = "done"
	for b in lr["bodies"]:
		if is_instance_valid(b):
			b.queue_free()
	lr["bodies"] = []
	for g in lr["gates"]:
		for t in g:
			_set_tile(t, false)
		main.fx_burst(_tiles_rect(g).get_center(), Vector2.ZERO, KEY_GOLD, 8, 90.0)
	if main.fog != null:
		main.fog.set("last_tile", Vector2i(-999, -999))
	main.sfx("slam", 0.9, -6.0, 0.0)
	main.banner = {"title": LOCK_TEXT["open_title"], "lines": [], "t": 1.8}
	_redraw()


## {left} while the climber is shut in a room (the HUD shows it), else {}.
func lock_status() -> Dictionary:
	for i in lock_rooms:
		var lr: Dictionary = lock_rooms[i]
		if lr["state"] == "shut" and not lr.get("hold", false):
			return {"left": lr["mobs"].filter(func(e): return is_instance_valid(e) and not e.dead).size()}
	return {}


func open_door(d: Dictionary, quiet := false) -> void:
	if d["open"]:
		return
	d["open"] = true
	d["t"] = 0.0
	_drop_light(d)
	for t in d["tiles"]:
		_set_tile(t, false)
	if is_instance_valid(d["body"]):
		d["body"].queue_free()
	d["body"] = null
	# What's behind is in sight now (fog.gd looks again on its next frame).
	if main.fog != null:
		main.fog.set("last_tile", Vector2i(-999, -999))
	if quiet:
		d["t"] = 1.0
		_redraw()
		return
	animating = true
	var dust := Color(0.55, 0.45, 0.33)
	main.fx_burst(d["rect"].get_center(), d["out"], dust, 10, 90.0)
	main.fx_burst(d["rect"].get_center(), -d["out"], dust, 8, 70.0)
	main.sfx("slam", 1.7, -10.0, 0.08)
	main.sfx("step_plate", 0.6, -6.0, 0.05)
	main.tip("doors")  # the Entity, the first time
	_redraw()


func _process(delta: float) -> void:
	if main == null or main.player == null:
		return
	if not lock_rooms.is_empty():
		_tick_lock_rooms(delta)
	if list.is_empty():
		return
	bump_t -= delta
	var pp: Vector2 = main.player.global_position
	for k in keys:
		if not k["taken"] and not main.player.dead and pp.distance_to(k["pos"]) < 24.0 + main.player.radius:
			_take_key(k)
	if animating:
		var still := false
		for d in list:
			if d["open"] and d["t"] < 1.0:
				d["t"] = minf(1.0, d["t"] + delta / OPEN_TIME)
				still = still or d["t"] < 1.0
		animating = still
		_redraw()
	var p = main.player
	if not p.dead:
		for d in list:
			if not d["open"] and _touches(d, p.global_position, p.radius):
				if d["lock"] != "":
					_bump(d)
				else:
					open_door(d)
	monster_t -= delta
	if monster_t <= 0.0:
		monster_t = MONSTER_CHECK
		var shut: Array = list.filter(func(d): return not d["open"] and d["lock"] == "")
		if shut.is_empty():
			return
		for e in main.enemies():
			if not e.aware:
				continue
			for d in shut:
				if not d["open"] and _touches(d, e.global_position, e.radius):
					open_door(d)


func _touches(d: Dictionary, pos: Vector2, r: float) -> bool:
	var rect: Rect2 = d["rect"]
	return rect.grow(r + REACH).has_point(pos)


func _redraw() -> void:
	queue_redraw()
	if glow != null:
		glow.queue_redraw()


# --- drawing -----------------------------------------------------------------

func _draw() -> void:
	if list.is_empty() and lock_rooms.is_empty():
		return
	var b := Draw.Batch.new()
	for d in list:
		if d["open"]:
			_draw_open(b, d)
		else:
			_draw_closed(b, d)
			if d["lock"] != "":
				_draw_lock(b, d)
	for k in keys:
		if not k["taken"]:
			_draw_key(b, k["pos"])
	for l in levers:
		_draw_lever(b, l["pos"], l["pulled"])
	for i in lock_rooms:
		if lock_rooms[i]["state"] == "shut":
			for g in lock_rooms[i]["gates"]:
				_draw_bars(b, _tiles_rect(g), Color(0.42, 0.4, 0.46))
	b.flush(self)


## A locked door's lock, over its usual look: a padlock (a key opens it),
## iron bars (a lever), or a violet ward (the floor's puzzle).
func _draw_lock(b, d: Dictionary) -> void:
	var r: Rect2 = d["rect"]
	var c := r.get_center()
	match String(d["lock"]):
		"proving", "lethal":
			pass  # (the Proving's doors: they open when chosen)
		"lever", "proving_shut":
			_draw_bars(b, r, Palette.DOOR_IRON.lightened(0.15))
		"puzzle":
			b.circle(c, 11.0, Palette.OUTLINE)
			b.circle(c, 9.5, Color(WARD, 0.85))
			b.circle(c, 6.5, Palette.DOOR_STONE)
			for k in 4:
				var a := PI * 0.25 + k * PI * 0.5
				b.line(c + Vector2.from_angle(a) * 3.0, c + Vector2.from_angle(a) * 8.0, Color(WARD, 0.9), 1.5)
			b.circle(c, 2.2, WARD.lightened(0.3))
		_:
			b.arc(c + Vector2(0, -4), 5.5, PI, TAU, 10, Palette.OUTLINE, 3.6)
			b.arc(c + Vector2(0, -4), 5.5, PI, TAU, 10, Color(0.62, 0.6, 0.64), 2.0)
			b.rect(Rect2(c + Vector2(-8, -4), Vector2(16, 13)), Palette.OUTLINE)
			b.rect(Rect2(c + Vector2(-7, -3), Vector2(14, 11)), KEY_GOLD.darkened(0.3))
			b.rect(Rect2(c + Vector2(-7, -3), Vector2(14, 2)), KEY_GOLD)
			b.circle(c + Vector2(0, 1.5), 1.8, Palette.OUTLINE)
			b.rect(Rect2(c + Vector2(-0.8, 2.0), Vector2(1.6, 4.0)), Palette.OUTLINE)


## Iron bars across a doorway (a barred door, or a lock-in room's shut gate).
func _draw_bars(b, r: Rect2, col: Color) -> void:
	var horiz := r.size.x >= r.size.y
	var n := int(maxf(r.size.x, r.size.y) / 10.0)
	for i in n:
		var k := (i + 0.5) / n
		if horiz:
			var x := r.position.x + r.size.x * k
			b.rect(Rect2(x - 2.0, r.position.y - 2.0, 4.0, r.size.y + 4.0), Palette.OUTLINE)
			b.rect(Rect2(x - 1.2, r.position.y - 1.0, 2.4, r.size.y + 2.0), col)
		else:
			var y := r.position.y + r.size.y * k
			b.rect(Rect2(r.position.x - 2.0, y - 2.0, r.size.x + 4.0, 4.0), Palette.OUTLINE)
			b.rect(Rect2(r.position.x - 1.0, y - 1.2, r.size.x + 2.0, 2.4), col)
	var across := Rect2(r.position.x, r.get_center().y - 2.5, r.size.x, 5.0) if horiz else Rect2(r.get_center().x - 2.5, r.position.y, 5.0, r.size.y)
	b.rect(across.grow(1.0), Palette.OUTLINE)
	b.rect(across, col.darkened(0.2))


## A key lying on the floor.
func _draw_key(b, c: Vector2) -> void:
	b.circle(c + Vector2(0, 7), 8.0, Color(0, 0, 0, 0.28))
	for i in 3:
		b.circle(c, 12.0 - i * 3.0, Color(KEY_GOLD, 0.08))
	b.circle(c + Vector2(-5, 0), 5.0, Palette.OUTLINE)
	b.circle(c + Vector2(-5, 0), 3.8, KEY_GOLD)
	b.circle(c + Vector2(-5, 0), 1.6, Palette.OUTLINE)
	b.rect(Rect2(c + Vector2(-1, -1.8), Vector2(10, 3.6)), Palette.OUTLINE)
	b.rect(Rect2(c + Vector2(-1, -1.0), Vector2(9.5, 2.0)), KEY_GOLD)
	b.rect(Rect2(c + Vector2(5, 1), Vector2(2, 3.5)), KEY_GOLD.darkened(0.2))
	b.rect(Rect2(c + Vector2(8, 1), Vector2(1.6, 2.5)), KEY_GOLD.darkened(0.2))


## A lever on a stone base: up while it waits, down once pulled.
func _draw_lever(b, c: Vector2, pulled: bool) -> void:
	b.circle(c + Vector2(0, 8), 9.0, Color(0, 0, 0, 0.28))
	b.rect(Rect2(c + Vector2(-9, 0), Vector2(18, 8)), Palette.OUTLINE)
	b.rect(Rect2(c + Vector2(-8, 1), Vector2(16, 6)), Palette.DOOR_STONE.lightened(0.1))
	var tip := c + (Vector2(9, -6) if pulled else Vector2(-6, -15))
	b.line(c + Vector2(0, 2), tip, Palette.OUTLINE, 4.0)
	b.line(c + Vector2(0, 2), tip, Palette.DOOR_IRON.lightened(0.3), 2.2)
	b.circle(tip, 3.2, Palette.OUTLINE)
	b.circle(tip, 2.3, Color(0.55, 0.85, 0.55) if pulled else Color(0.85, 0.35, 0.3))


## The light under warm and chained doors, on the side you come from.
func _draw_glow() -> void:
	var b := Draw.Batch.new()
	for d in list:
		if d["open"] and d["t"] >= 1.0:
			continue
		var col: Color = _glow_color(String(d["style"]))
		if col.a <= 0.0:
			continue
		var fade := 1.0 - float(d["t"]) if d["open"] else 1.0
		var r: Rect2 = d["rect"]
		var out: Vector2 = d["out"]
		var edge := _edge(r, out)  # the door's outer edge
		for i in 5:
			var depth := 4.0 + i * 5.0
			var strip := _strip(edge, out, depth)
			b.rect(strip, Color(col, 0.10 * fade * (1.0 - i / 5.0)))
		b.rect(_strip(edge, out, 2.5), Color(col.lightened(0.3), 0.75 * fade))
	b.flush(glow)


## The door's outer edge: [from, to] along the side facing `out`.
func _edge(r: Rect2, out: Vector2) -> Array:
	if out == Vector2.UP:
		return [r.position, Vector2(r.end.x, r.position.y)]
	if out == Vector2.DOWN:
		return [Vector2(r.position.x, r.end.y), r.end]
	if out == Vector2.LEFT:
		return [r.position, Vector2(r.position.x, r.end.y)]
	return [Vector2(r.end.x, r.position.y), r.end]


## A strip `depth` px deep outward from an edge, a little shorter than the door.
func _strip(edge: Array, out: Vector2, depth: float) -> Rect2:
	var a: Vector2 = edge[0]
	var c: Vector2 = edge[1]
	var along := (c - a).normalized()
	a += along * 6.0
	c -= along * 6.0
	var far := c + out * depth
	return Rect2(Vector2(minf(a.x, far.x), minf(a.y, far.y)), (far - a).abs())


func _draw_open(b, d: Dictionary) -> void:
	var r: Rect2 = d["rect"]
	var horiz: bool = d["horiz"]
	var k: float = d["t"]
	var wood := _wood(d)
	# The frame left in the doorway.
	var j := 5.0
	if horiz:
		b.rect(Rect2(r.position.x, r.position.y + 2.0, j, r.size.y - 4.0), wood.darkened(0.35))
		b.rect(Rect2(r.end.x - j, r.position.y + 2.0, j, r.size.y - 4.0), wood.darkened(0.35))
	else:
		b.rect(Rect2(r.position.x + 2.0, r.position.y, r.size.x - 4.0, j), wood.darkened(0.35))
		b.rect(Rect2(r.position.x + 2.0, r.end.y - j, r.size.x - 4.0, j), wood.darkened(0.35))
	# While it swings: the leaf folding away to the side.
	if k < 1.0:
		var leaf := r.grow(-2.0)
		if horiz:
			leaf.size.x *= (1.0 - k)
		else:
			leaf.size.y *= (1.0 - k)
		b.rect(leaf, Color(wood, 1.0 - k * 0.5))


func _wood(d: Dictionary) -> Color:
	match String(d["style"]):
		"den":
			return Palette.DOOR_WOOD.darkened(0.3)
		"puzzle":
			return Palette.DOOR_STONE
		"sealed":
			return Palette.DOOR_STONE.darkened(0.25)
		"hazard":
			return Palette.DOOR_WOOD.darkened(0.15)
		"proving":
			return Palette.DOOR_STONE.lightened(0.04)
		"lethal":
			return Palette.DOOR_STONE.darkened(0.45)
		"shade":
			return Palette.DOOR_STONE.darkened(0.35)
		"crown":
			return Palette.DOOR_WOOD.darkened(0.2)
	return Palette.DOOR_WOOD


## The Proving's doors (see the top): a six-pointed star on a slab, a crown
## for the sentinel, a pale beast's eye for the shadow.
func _draw_proving_door(b, d: Dictionary, inner: Rect2, wood: Color, along: Vector2, side: Vector2, long: float, across: float) -> void:
	var style: String = d["style"]
	var o := inner.position
	var c := inner.get_center()
	var s := across * 0.36
	if style == "crown":
		# Iron bands with studs, a gold crown on a dark plate.
		for i in 2:
			var t := across * (float(i) + 0.75) / 2.5
			b.rect(Rect2(o + side * (t - 2.0), Vector2.ZERO).expand(o + side * (t + 2.0) + along * long), Palette.DOOR_IRON)
		b.circle(c, s * 1.15, Palette.OUTLINE)
		b.circle(c, s * 1.0, Palette.DOOR_IRON.darkened(0.2))
		var g := PROVING_GOLD
		var crown := PackedVector2Array([c + Vector2(-s * 0.75, s * 0.45), c + Vector2(-s * 0.85, -s * 0.45), c + Vector2(-s * 0.4, -s * 0.05),
			c + Vector2(0, -s * 0.7), c + Vector2(s * 0.4, -s * 0.05), c + Vector2(s * 0.85, -s * 0.45), c + Vector2(s * 0.75, s * 0.45)])
		b.polygon(crown, g)
		b.circle(c + Vector2(0, s * 0.12), s * 0.14, Color(0.9, 0.25, 0.2))
		return
	b.rect(inner.grow(-3.0), wood.lightened(0.06))
	for k in [0.1, 0.9]:
		b.circle(o + along * long * k + side * across * 0.5, 2.0, Palette.DOOR_IRON.lightened(0.3))
	if style == "shade":
		# A pale, slit-pupilled eye, and wisps rising from it.
		var col := SHADE_GLOW
		var lid := PackedVector2Array()
		for i in 13:
			var a := PI * float(i) / 12.0
			lid.append(c + Vector2(cos(a) * s * 1.3, -sin(a) * s * 0.7))
		for i in range(1, 12):
			var a := PI * float(i) / 12.0
			lid.append(c + Vector2(-cos(a) * s * 1.3, sin(a) * s * 0.7))
		b.polygon(lid, Color(col.darkened(0.55), 0.95))
		b.polyline(lid + PackedVector2Array([lid[0]]), Color(col, 0.85), 1.4)
		b.polygon(PackedVector2Array([c + Vector2(0, -s * 0.6), c + Vector2(s * 0.16, 0), c + Vector2(0, s * 0.6), c + Vector2(-s * 0.16, 0)]), col.lightened(0.3))
		for k in 3:
			var x := (k - 1) * s * 1.1
			b.line(c + Vector2(x, -s * 0.9), c + Vector2(x + s * 0.2, -s * 1.3), Color(col, 0.5), 1.2)
		return
	# The Proving's star: two triangles; the Lethal one red and cracked.
	var lethal := style == "lethal"
	var star_col := Color(RED.lightened(0.15), 0.95) if lethal else Color(PROVING_GOLD, 0.95)
	for k in 2:
		var tri := PackedVector2Array()
		for i in 3:
			var a := -PI * 0.5 + k * PI + i * TAU / 3.0
			tri.append(c + Vector2.from_angle(a) * s * 1.05)
		b.polygon(tri, star_col)
	b.circle(c, s * 0.38, wood.lightened(0.06))
	b.circle(c, s * 0.18, star_col.lightened(0.3))
	if lethal:
		b.line(c + Vector2(-s * 1.6, -s * 0.8), c + Vector2(-s * 0.4, s * 0.2), Palette.OUTLINE, 1.6)
		b.line(c + Vector2(-s * 0.4, s * 0.2), c + Vector2(s * 0.3, -s * 0.1), Palette.OUTLINE, 1.6)
		b.line(c + Vector2(s * 0.3, -s * 0.1), c + Vector2(s * 1.5, s * 0.9), Palette.OUTLINE, 1.6)


func _draw_closed(b, d: Dictionary) -> void:
	var r: Rect2 = d["rect"]
	var horiz: bool = d["horiz"]
	var style: String = d["style"]
	var wood := _wood(d)
	var inner := r.grow(-2.0)
	# Shadow and outline, then the leaf.
	b.rect(Rect2(r.position + Vector2(3, 5), r.size), Color(0, 0, 0, 0.3))
	b.rect(r, Palette.OUTLINE)
	b.rect(inner, wood)
	var long := inner.size.x if horiz else inner.size.y
	var across := inner.size.y if horiz else inner.size.x
	var along := Vector2.RIGHT if horiz else Vector2.DOWN
	var side := Vector2.DOWN if horiz else Vector2.RIGHT
	var o := inner.position
	if style in ["proving", "lethal", "crown", "shade"]:
		_draw_proving_door(b, d, inner, wood, along, side, long, across)
		return
	if style == "sealed":
		# A dark stone slab with iron studs at its ends and a watching eye
		# carved in the middle, its pupil glowing: the Regard tests whoever enters.
		b.rect(inner.grow(-3.0), wood.lightened(0.06))
		for k in [0.12, 0.88]:
			for j in [0.3, 0.7]:
				b.circle(o + along * long * k + side * across * j, 2.2, Palette.DOOR_IRON.lightened(0.3))
		var c := inner.get_center()
		var s := across * 0.34
		var lid := PackedVector2Array()
		for i in 13:
			var a := PI * float(i) / 12.0
			lid.append(c + along * cos(a) * s * 1.7 - side * sin(a) * s * 0.8)
		for i in range(1, 12):
			var a := PI * float(i) / 12.0
			lid.append(c - along * cos(a) * s * 1.7 + side * sin(a) * s * 0.8)
		b.polygon(lid, wood.darkened(0.45))
		b.polyline(lid + PackedVector2Array([lid[0]]), Color(RED.lightened(0.2), 0.75), 1.6)
		b.circle(c, s * 0.5, Color(RED, 0.85))
		b.circle(c, s * 0.22, Color(1.0, 0.85, 0.6))
		return
	if style == "puzzle":
		# A stone slab: a raised border, joints, and the puzzle's emblem.
		b.rect(inner.grow(-3.0), wood.lightened(0.08))
		b.line(o + along * long * 0.5, o + along * long * 0.5 + side * across, wood.darkened(0.3), 1.5)
		var c := inner.get_center()
		var s := across * 0.32
		match String(d["emblem"]):
			"eye":
				var pts := PackedVector2Array()
				for i in 13:
					var a := PI * float(i) / 12.0
					pts.append(c + Vector2(cos(a) * s * 1.5, -sin(a) * s * 0.75))
				for i in range(1, 12):
					var a := PI * float(i) / 12.0
					pts.append(c + Vector2(-cos(a) * s * 1.5, sin(a) * s * 0.75))
				b.polyline(pts + PackedVector2Array([pts[0]]), Color(EMBLEM, 0.8), 1.8)
				b.circle(c, s * 0.42, Color(EMBLEM, 0.85))
				b.circle(c, s * 0.18, wood.darkened(0.4))
			"statue":
				# Three standing figures.
				for k in 3:
					var fc := c + along * (k - 1) * s * 0.9
					b.rect(Rect2(fc + Vector2(-s * 0.2, -s * 0.2), Vector2(s * 0.4, s * 0.9)), Color(EMBLEM, 0.8))
					b.circle(fc + Vector2(0, -s * 0.45), s * 0.22, Color(EMBLEM, 0.85))
			"mirror":
				# A pane turning a ray.
				b.line(c + Vector2(-s, s), c + Vector2(s, -s), Color(EMBLEM, 0.85), 2.2)
				b.line(c + Vector2(-s * 1.4, 0), c, Color(EMBLEM, 0.6), 1.4)
				b.line(c, c + Vector2(0, -s * 1.4), Color(EMBLEM, 0.6), 1.4)
			"ice":
				# A snowflake: three crossed strokes with barbs.
				for k in 3:
					var a := PI * k / 3.0 + PI / 2.0
					var v := Vector2.from_angle(a) * s * 1.1
					b.line(c - v, c + v, Color(EMBLEM, 0.85), 1.8)
					for e in [-1.0, 1.0]:
						var tip: Vector2 = c + v * e * 0.7
						b.line(tip, tip + (v * e).rotated(0.7).normalized() * s * 0.35, Color(EMBLEM, 0.7), 1.3)
						b.line(tip, tip + (v * e).rotated(-0.7).normalized() * s * 0.35, Color(EMBLEM, 0.7), 1.3)
			"lock":
				# A keyhole in a ring.
				b.arc(c, s * 1.05, 0.0, TAU, 20, Color(EMBLEM, 0.8), 1.8)
				b.circle(c + Vector2(0, -s * 0.25), s * 0.32, Color(EMBLEM, 0.85))
				b.polygon(PackedVector2Array([c + Vector2(-s * 0.18, -s * 0.2), c + Vector2(s * 0.18, -s * 0.2), c + Vector2(s * 0.3, s * 0.6), c + Vector2(-s * 0.3, s * 0.6)]), Color(EMBLEM, 0.85))
			"glyph":
				# A tablet with a numeral and a sign: something to remember.
				b.rect(Rect2(c - Vector2(s * 0.9, s * 1.0), Vector2(s * 1.8, s * 2.0)), Color(EMBLEM, 0.3))
				for k in 3:
					b.line(c + Vector2(-s * 0.5 + k * s * 0.3, -s * 0.8), c + Vector2(-s * 0.5 + k * s * 0.3, -s * 0.3), Color(EMBLEM, 0.85), 1.4)
				b.arc(c + Vector2(0, s * 0.35), s * 0.4, 0.0, TAU, 14, Color(EMBLEM, 0.85), 1.6)
			"stones":
				# A grid of stepping stones.
				for gy in 2:
					for gx in 3:
						b.rect(Rect2(c + Vector2((gx - 1.5) * s * 0.75, (gy - 1.0) * s * 0.75), Vector2(s * 0.6, s * 0.6)), Color(EMBLEM, 0.75))
			_:
				b.rect(Rect2(c - Vector2(s, s), Vector2(s, s) * 2.0), Color(EMBLEM, 0.75))
				b.rect(Rect2(c - Vector2(s, s) * 0.7, Vector2(s, s) * 1.4), wood.lightened(0.08))
				b.rect(Rect2(c - Vector2(s, s) * 0.38, Vector2(s, s) * 0.76), Color(EMBLEM, 0.8))
		return
	# Planks: lines across the leaf.
	var planks := 5
	for i in range(1, planks):
		var t := long * float(i) / planks
		b.line(o + along * t, o + along * t + side * across, wood.darkened(0.35), 1.2)
	var iron := Palette.DOOR_IRON
	var bands := 3 if style == "den" else 2
	for i in bands:
		var t := across * (float(i) + 0.75) / (float(bands) + 0.5)
		var bw := 5.0 if style == "den" else 3.5
		b.rect(Rect2(o + side * (t - bw * 0.5), Vector2.ZERO).expand(o + side * (t + bw * 0.5) + along * long), iron)
		if style == "den":
			for k in 4:
				b.circle(o + side * t + along * (long * (0.12 + 0.25 * k)), 1.4, iron.lightened(0.35))
	match style:
		"den":
			# Claw marks gouged across it, and bones at the threshold.
			var c := inner.get_center()
			for k in 3:
				var off := (k - 1) * 6.0
				b.line(c + along * (off - 9.0) + side * -9.0, c + along * (off + 7.0) + side * 9.0, wood.lightened(0.35), 1.6)
			var out: Vector2 = d["out"]
			var sill := r.get_center() + out * (r.size.dot(out.abs()) * 0.5 + 9.0)
			_bone(b, sill + along * -14.0, along.rotated(0.5), 9.0)
			_bone(b, sill + along * 10.0 + out * 4.0, along.rotated(-0.9), 7.0)
		"hazard":
			var c := inner.get_center()
			var rad := across * 0.36
			b.circle(c, rad + 1.5, Palette.OUTLINE)
			b.circle(c, rad, iron.lightened(0.1))
			_sigil(b, c, rad * 0.75, String(d["sigil"]))
		"chained":
			# Two chains across, and a padlock where they cross.
			var a0 := inner.position
			var a1 := inner.end
			var b0 := Vector2(inner.end.x, inner.position.y)
			var b1 := Vector2(inner.position.x, inner.end.y)
			for seg in [[a0, a1], [b0, b1]]:
				var n := 9
				for i in n + 1:
					var p: Vector2 = seg[0].lerp(seg[1], float(i) / n)
					b.circle(p, 3.0, Palette.OUTLINE)
					b.circle(p, 2.0, Color(0.5, 0.48, 0.5))
			var c := inner.get_center()
			b.rect(Rect2(c - Vector2(6, 3), Vector2(12, 10)), Palette.OUTLINE)
			b.rect(Rect2(c - Vector2(5, 2), Vector2(10, 8)), Color(0.55, 0.45, 0.25))
			b.arc(c + Vector2(0, -3), 4.0, PI, TAU, 8, Color(0.5, 0.48, 0.5), 2.0)
			b.rect(Rect2(c + Vector2(-1, 1), Vector2(2, 3)), Palette.OUTLINE)
		"warm":
			# A brass ring to pull.
			var c := inner.get_center() + along * long * 0.28
			b.arc(c, 4.5, 0.0, TAU, 12, Color(0.75, 0.6, 0.3), 1.8)


func _bone(b, c: Vector2, dir: Vector2, len: float) -> void:
	var bone := Color(0.82, 0.78, 0.68)
	var a := c - dir * len * 0.5
	var e := c + dir * len * 0.5
	b.line(a, e, bone, 2.4)
	var n := dir.orthogonal() * 1.6
	for p in [a, e]:
		b.circle(p + n, 1.7, bone)
		b.circle(p - n, 1.7, bone)


## A hazard's sign, engraved in the door's plate.
func _sigil(b, c: Vector2, s: float, sigil: String) -> void:
	var col: Color = SIGIL_COLORS.get(sigil, Color(0.8, 0.8, 0.8))
	match sigil:
		"wind":
			for k in 3:
				var y := (k - 1) * s * 0.55
				var pts := PackedVector2Array()
				for i in 7:
					var x := -s + 2.0 * s * i / 6.0
					pts.append(c + Vector2(x, y + sin(i * 0.9 + k) * s * 0.12))
				b.polyline(pts, col, 1.6)
			b.arc(c + Vector2(s * 0.7, -s * 0.2), s * 0.32, -PI * 0.5, PI * 0.9, 8, col, 1.6)
		"wave":
			for k in 2:
				var pts := PackedVector2Array()
				for i in 9:
					var x := -s + 2.0 * s * i / 8.0
					pts.append(c + Vector2(x, (k - 0.5) * s * 0.8 + sin(i * 1.4) * s * 0.25))
				b.polyline(pts, col, 1.8)
		"flame":
			var pts := PackedVector2Array()
			for i in 14:
				var a := float(i) / 14.0 * TAU
				var p := Vector2(sin(a) * s * 0.6, -cos(a) * s * 0.55)
				if p.y < 0.0:
					p.y *= 1.9
				pts.append(c + p + Vector2(0, s * 0.3))
			b.polygon(pts, col)
			b.circle(c + Vector2(0, s * 0.42), s * 0.25, col.lightened(0.4))
		"spike":
			for k in 3:
				var x := (k - 1) * s * 0.7
				b.polygon(PackedVector2Array([c + Vector2(x - s * 0.3, s * 0.6), c + Vector2(x, -s * 0.75), c + Vector2(x + s * 0.3, s * 0.6)]), col)
		"ember":
			b.circle(c + Vector2(0, -s * 0.15), s * 0.45, col)
			for k in 3:
				b.circle(c + Vector2((k - 1) * s * 0.55, s * 0.55 + (k % 2) * s * 0.2), s * 0.14, col)
		"thorn":
			var pts := PackedVector2Array()
			for i in 6:
				pts.append(c + Vector2(-s + 2.0 * s * i / 5.0, (s * 0.35) * (1.0 if i % 2 == 0 else -1.0)))
			b.polyline(pts, col, 2.0)
			for i in range(1, 5):
				var p: Vector2 = pts[i]
				b.line(p, p + Vector2(0, -s * 0.3 if i % 2 == 0 else s * 0.3), col, 1.4)
		"dart":
			# A dart, point down, between two slots.
			b.line(c + Vector2(0, -s * 0.8), c + Vector2(0, s * 0.4), col, 1.8)
			b.polygon(PackedVector2Array([c + Vector2(-s * 0.25, s * 0.35), c + Vector2(s * 0.25, s * 0.35), c + Vector2(0, s * 0.85)]), col)
			b.line(c + Vector2(-s * 0.3, -s * 0.85), c + Vector2(0, -s * 0.5), col, 1.4)
			b.line(c + Vector2(s * 0.3, -s * 0.85), c + Vector2(0, -s * 0.5), col, 1.4)
			for k in [-1.0, 1.0]:
				b.line(c + Vector2(k * s * 0.8, -s * 0.5), c + Vector2(k * s * 0.8, s * 0.5), col.darkened(0.3), 2.0)
		"gas":
			# Three puffs of cloud.
			b.circle(c + Vector2(-s * 0.4, s * 0.15), s * 0.32, col)
			b.circle(c + Vector2(s * 0.4, s * 0.15), s * 0.32, col)
			b.circle(c + Vector2(0, -s * 0.2), s * 0.4, col)
			b.circle(c + Vector2(0, s * 0.55), s * 0.12, col.darkened(0.3))
		"chasm":
			b.polygon(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.7, 0), c + Vector2(0, s), c + Vector2(-s * 0.7, 0)]), Color(0.05, 0.03, 0.08))
			b.polyline(PackedVector2Array([c + Vector2(0, -s), c + Vector2(s * 0.7, 0), c + Vector2(0, s), c + Vector2(-s * 0.7, 0), c + Vector2(0, -s)]), col, 1.6)
		_:
			b.circle(c, s * 0.4, col)
