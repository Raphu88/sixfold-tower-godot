extends Node2D
## Sealed wings, their vaults, and secret rooms: what floors.gd carves into
## the cells it keeps beside the spine (see "sealed wings" there).
##
## A SEALED WING is a room behind a sealed door (doors.gd, the Regard's
## watching eye). Cut into its wall is a 3x3 VAULT ALCOVE behind a one-tile
## vault door drawn as a pulsing gold SEAL with a keyhole, light leaking
## from under it, from the moment you see it: a locked vault, and this
## room's question opens it. The seal's emblem shows the CHALLENGE (never the
## reward). Walk in and the way behind you grinds shut until the question is
## answered:
##   for now every wing is a CHALLENGE ROOM: waves of the tower's monsters
##   with one stated condition (take no hit, be quick, kill only staggered
##   foes). Beat the waves keeping it and the vault opens; break it and
##   either the vault opens with a lesser prize once the waves are beaten,
##   or the tower sends a CHAMPION (enemy.gd) whose fall reopens the exits
##   while the vault stays locked for good. The way out always reopens.
##   PUZZLE HOOK: a puzzle host (puzzle.gd) can claim a wing instead: give
##   it a method wing_puzzle(wing) -> String returning a puzzle type (or ""),
##   and optionally wing_emblem(type) -> String (the seal's emblem). When
##   the climber walks in it gets start_wing_puzzle(wing) and must call
##   main.wings.wing_solved(wing["id"]) or main.wings.wing_failed(wing["id"]).
## The vault holds a PEDESTAL: walk up to it and choose one of its cards
## (main.gd's card screen): an essence crystal of one kind or another, a
## piece of gear, a recall scroll, or an item.
##
## A SECRET ROOM is a POCKET DIMENSION (portals.gd): a room with no way to
## it on foot, reached through a hidden spot in a spine room's wall. Its
## hints: dust drifting down near it now and then when you're close, a
## hollow knock when you strike it, and Hunter's Keen Eyes outline it. Lean
## into it (walk into it) for a moment, or break it with a finishing blow
## or a burst, and it gives way: a portal opens in it, to the pocket. A
## portal inside leads back. The pocket holds a small vault (vaults.gd:
## three chests, some vaults guarded by a Tithe Stone, runes or a Keeper).
##
## Cheap: nothing runs for an idle wing but a point-in-rect check, and the
## drawing is redrawn 30 times a second only while a seal or a pedestal is
## on screen (otherwise only when something changes).

const Palette := preload("res://scripts/palette.gd")
const Draw := preload("res://scripts/draw_util.gd")
const Essence := preload("res://scripts/essence.gd")
const Items := preload("res://scripts/items.gd")
const Gear := preload("res://scripts/gear.gd")
const Makers := preload("res://scripts/makers.gd")
const Charms := preload("res://scripts/charms.gd")
const Vaults := preload("res://scripts/vaults.gd")

## Every line the wings say, in one place.
static var TEXT := {
	"sealed_title": "THE WAY SHUTS",
	"sealed": "The way behind you grinds shut. This room will not let you go until its question is answered.",
	"rule_title": "THE REGARD TESTS YOU",
	"waves": "%d waves of the tower's own.",
	"wave": "Wave %d of %d",
	"broken_title": "THE REGARD SAW",
	"broken_lesser": "Finish the waves: the vault will give you less.",
	"broken_champion": "The tower sends its champion. Fell it and the way opens.",
	"champion": "Champion",
	"won_title": "THE SEAL BREAKS",
	"won": "The vault opens. The way behind you opens too.",
	"lesser_title": "THE SEAL GIVES",
	"lesser": "The vault opens, grudgingly. The way behind you opens.",
	"dark_title": "THE CHAMPION FALLS",
	"dark": "The way opens. The vault's seal goes dark for good.",
	"seal_holds": "The seal holds",
	"seal_dark": "The seal is dead",
	"vault_title": "THE VAULT",
	"vault_sub": "Choose one to take.",
	"vault_lesser_sub": "A lesser prize. Choose one to take.",
	"knock": "A hollow knock",
	"secret_open": "A portal opens",
	"secret_title": "A HIDDEN PORTAL",
	"secret_line": "It leads somewhere outside the floor. Step in.",
	"crystals_title": "HIDDEN CRYSTALS",
	"crystals_sub": "Essence crystals, left here. Choose one to take.",
	"crystal_taken": "+ %s",
	"failsafe": "The room tires of its question.",
}

## A challenge room's conditions: its name, the rule as told, the seal's
## emblem, how often it's picked and from which floor.
const CONDITIONS := {
	"untouched": {"name": "Untouched", "rule": "Take no hit.", "emblem": "shield", "weight": 1.0, "from": 2,
		"broken": "You were struck."},
	"swift": {"name": "Swift", "rule": "Beat every wave within %d seconds.", "emblem": "hourglass", "weight": 1.0, "from": 2,
		"per_wave": 16.0, "base": 8.0, "broken": "Too slow."},
	"staggered": {"name": "Staggered", "rule": "Every foe must fall while staggered: parry it, then strike.", "emblem": "blades", "weight": 0.7, "from": 4,
		"broken": "A foe fell unstaggered."},
}
## What breaking the condition brings: weights.
static var FAIL_MODES := {"lesser": 0.55, "champion": 0.45}
## The waves: how many, the monsters' budget per wave (Floors.MONSTERS
## costs) and its growth per floor, at most this many at once, the pause
## between waves.
static var WAVES := {"count": [2, 3], "budget": 2.6, "per_floor": 0.35, "most": 4, "gap": 1.4, "rule_time": 2.4, "close_time": 2.2}
## How long a challenge may run before the room gives up (never trapped).
const FAILSAFE := 240.0
## Rewards. Crystals hold base + per_floor * floor essence; a lesser prize
## or a hidden one holds that fraction, a camp's crystal card "camp" of it.
## The pedestal opens within reach.
## (Half what they were, 16 and 4, as a climb still left too many crystals:
## the camp's crystal card, the Proving sentinel's crystal, a secret room's
## and a pocket's, and a mirror image's prize are shares of it too.)
static var REWARD := {"crystal_base": 8.0, "crystal_per_floor": 2.0, "camp": 0.6, "lesser": 0.5, "hidden": 0.75, "reach": 30.0,
	"gear": 0.45, "scroll": 0.3, "item": 0.25}
## Secret rooms' hidden spots: lean this long; dust falls every few seconds
## within `dust_near`; Keen Eyes outlines the wall within `keen_near`. (What
## a pocket's vault holds: vaults.gd.)
static var SECRET := {"lean": 0.75, "dust_every": [2.5, 5.0], "dust_near": 230.0, "keen_near": 300.0}
const GOLD := Color(0.95, 0.75, 0.35)
const DUST := Color(0.6, 0.55, 0.48)
## Redraws a second while something animated is on screen.
const ANIM_HZ := 30.0

var main
var wings: Array = []  # the floor's wings (floors.gd's plan, plus their state)
var secrets: Array = []
var active := {}  # the wing whose question is being asked
var knocks := 0  # hollow knocks heard this floor (tests)
var anim_t := 0.0
var dirty := false
var last_tile := Vector2i(-999, -999)
var frozen: Array = []  # monsters held still while a vault's cards show
var _hint_t := 0.0  # (how often to look whether a sealed door is in sight)


## The first time a marked climber sees a sealed door on an early floor, the
## Entity hints that breaking in can bring rewards (entity.gd "wing_watch").
func _hint_seen() -> void:
	if main.first_climb or main.floor_num > int(main.Flow.EARNED["last_floor"]) or main.UnboundRun.Unbound.is_on(main.profile) or main.profile.bonds.is_empty():
		return
	var view := _view_rect()
	for w in wings:
		if w["state"] != "idle" or w["door"].is_empty():
			continue
		var at := _tile_center(w["door"][0])
		if view.has_point(at) and _seen(at):
			main.tip("wing_watch")
			return


func _ready() -> void:
	z_index = -3  # on the floor, over doors, under everyone


## A new floor: forget the old wings and secrets, and set up this one's.
func setup(plan: Dictionary) -> void:
	clear()
	if main == null or not main.layout_on:
		return
	for k in plan.get("wings", []):
		var w: Dictionary = k.duplicate()
		w["state"] = "idle"
		w["vault"] = "sealed"  # sealed, open, lesser (open, a lesser prize), dark (locked for good), taken
		w["broken"] = false
		w["mobs"] = []
		w["t"] = 0.0
		w["clock"] = 0.0
		w["puzzle_slot"] = ""
		_choose_challenge(w)
		var def := {"tiles": w["door"], "horiz": w["horiz"], "out": w["out"], "room": -1, "style": "sealed"}
		for key in ["lock", "lock_id", "lock_pos", "lock_carrier"]:
			if w.has(key):
				def[key] = w[key]  # (a wing's door may be locked too: floors.gd)
		main.door_view.add_door(def)
		w["vault_body"] = _close([w["vault_door"]])
		var vdir: Vector2 = w["vault_dir"]
		w["light"] = main.lighting.add_spot(w["seal_pos"] - vdir * 22.0, -vdir, 130.0, 150.0, GOLD, 0.7, 0.2)  # (spilling out from under the seal)
		wings.append(w)
	for k in plan.get("secrets", []):
		var s: Dictionary = k.duplicate()
		s["open"] = false
		s["lean_t"] = 0.0
		s["dust_t"] = randf_range(SECRET["dust_every"][0], SECRET["dust_every"][1])
		s["taken"] = false
		s["told"] = false
		# Until it opens, the whole passage and room are rock (nothing shows
		# through: walls, fog and paths all see solid stone), and its first
		# tile is a wall with a body of its own.
		main.set_tiles_solid(_secret_tiles(s), true)
		s["body"] = _close([s["mouth"][0]])
		s["portal_out"] = _tile_center(s["mouth"][0])
		Vaults.lay_out(s, main.floor_num, main.first_climb, main.Floors.CELL)  # (its portal back, three chests, its guard)
		secrets.append(s)
	dirty = true
	queue_redraw()


func clear() -> void:
	for w in wings:
		for key in ["vault_body", "gate_body"]:
			if w.get(key) != null and is_instance_valid(w[key]):
				w[key].queue_free()
		for key in ["light", "prize_light"]:
			if w.has(key) and main.lighting != null:
				main.lighting.remove_light(w[key])
	for s in secrets:
		for key in ["body", "vault_body", "tithe_body"]:
			if s.get(key) != null and is_instance_valid(s[key]):
				s[key].queue_free()
		for key in ["light", "niche_light"]:
			if s.has(key) and main.lighting != null:
				main.lighting.remove_light(s[key])
	wings.clear()
	secrets.clear()
	active = {}
	knocks = 0
	_unfreeze()
	queue_redraw()


## The condition (or, when a puzzle host claims the wing, its puzzle) and
## what breaking it brings.
func _choose_challenge(w: Dictionary) -> void:
	var pz = main.puzzle
	if pz != null and pz.has_method("wing_puzzle"):
		w["puzzle_slot"] = String(pz.wing_puzzle(w))
	if w["puzzle_slot"] != "":
		w["emblem"] = String(pz.wing_emblem(w["puzzle_slot"])) if pz.has_method("wing_emblem") else "eye"
		w["fail"] = "champion"
		return
	var table := {}
	for id in CONDITIONS:
		if main.floor_num >= int(CONDITIONS[id]["from"]):
			table[id] = float(CONDITIONS[id]["weight"])
	w["condition"] = main.Floors._weighted(table)
	w["emblem"] = CONDITIONS[w["condition"]]["emblem"]
	w["fail"] = main.Floors._weighted(FAIL_MODES)
	w["waves"] = randi_range(int(WAVES["count"][0]), int(WAVES["count"][1]))
	w["limit"] = float(CONDITIONS["swift"]["base"]) + float(CONDITIONS["swift"]["per_wave"]) * w["waves"]


# --- tiles that open and close -----------------------------------------------------


## Closes tiles: solid for sight and paths, and a body of their own.
func _close(tiles: Array) -> StaticBody2D:
	main.set_tiles_solid(tiles, true)
	var rect := _tile_rect(tiles)
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
	return body


func _open(tiles: Array, body) -> void:
	main.set_tiles_solid(tiles, false)
	if body != null and is_instance_valid(body):
		body.queue_free()
	if main.fog != null:
		main.fog.set("last_tile", Vector2i(-999, -999))  # look again: there's more to see


func _tile_rect(tiles: Array) -> Rect2:
	var c: float = main.Floors.CELL
	var r := Rect2(main.room.position + Vector2(tiles[0]) * c, Vector2(c, c))
	for t in tiles:
		r = r.merge(Rect2(main.room.position + Vector2(t) * c, Vector2(c, c)))
	return r


func _tile_center(t: Vector2i) -> Vector2:
	return main.room.position + (Vector2(t) + Vector2(0.5, 0.5)) * main.Floors.CELL


## Every tile of a secret: its passage, its room, its alcove (if any).
func _secret_tiles(s: Dictionary) -> Array:
	var out: Array = []
	var rects: Array = [s["rect"], s["corridor"]]
	if s.has("alcove"):
		rects.append(s["alcove"])
	for r in rects:
		out.append_array(main._tiles_in(r))
	if s.has("vault_door"):
		out.append(s["vault_door"])
	return out


# --- each frame --------------------------------------------------------------------

func _process(delta: float) -> void:
	if (wings.is_empty() and secrets.is_empty()) or main == null or main.player == null:
		return
	var p = main.player
	var pos: Vector2 = p.global_position
	var t: Vector2i = main._tile_of(pos)
	var moved := t != last_tile
	last_tile = t
	for w in wings:
		if w["state"] == "idle":
			if moved and not p.dead and not main.climbing and w["rect"].grow(-28.0).has_point(pos):
				_try_seal(w)
		elif w["state"] != "done":
			_tick_wing(w, delta, p)
		if w["vault"] in ["open", "lesser"] and not p.dead and pos.distance_to(w["pedestal"]) < float(REWARD["reach"]) + p.radius:
			_offer(w, w["vault"] == "lesser")
		if w.has("drop") and not w["drop"]["taken"] and not p.dead and pos.distance_to(w["drop"]["pos"]) < 26.0 + p.radius:
			_take_drop(w)
	for s in secrets:
		_tick_secret(s, delta, p)
	_hint_t -= delta
	if _hint_t <= 0.0:
		_hint_t = 0.5
		_hint_seen()
	# Animated bits on screen: 30 redraws a second; otherwise only on a change.
	anim_t -= delta
	if dirty or (anim_t <= 0.0 and _anim_on_screen()):
		anim_t = 1.0 / ANIM_HZ
		dirty = false
		queue_redraw()
		_pulse_lights()


func _view_rect() -> Rect2:
	var cam: Camera2D = main.camera
	if cam == null:
		return Rect2(-1e6, -1e6, 2e6, 2e6)
	var size := get_viewport_rect().size / cam.zoom
	return Rect2(cam.get_screen_center_position() - size * 0.5, size).grow(60.0)


func _seen(pos: Vector2) -> bool:
	var fog = main.fog
	if fog == null or not fog.visible or fog.grid == Vector2i.ZERO:
		return true
	var t: Vector2i = main._tile_of(pos)
	if t.x < 0 or t.y < 0 or t.x >= fog.grid.x or t.y >= fog.grid.y:
		return false
	return fog.seen[t.y * fog.grid.x + t.x] == 1


func _anim_on_screen() -> bool:
	var view := _view_rect()
	for w in wings:
		for pos in _anim_points(w):
			if view.has_point(pos) and _seen(pos):
				return true
	for s in secrets:
		if keen_outlined(s) and view.has_point(_tile_center(s["mouth"][0])):
			return true

	return false


## Hunter's Keen Eyes see a secret wall's outline when close.
## A Flare (main.flare_reveals) shows it too, near where it burst.
func keen_outlined(s: Dictionary) -> bool:
	var p = main.player
	if s["open"] or p == null:
		return false
	var at := _tile_center(s["mouth"][0])
	return (p.has_bond("hunter") and p.global_position.distance_to(at) < float(SECRET["keen_near"])) or main.flare_reveals(at)


func _anim_points(w: Dictionary) -> Array:
	var out: Array = []
	if w["vault"] == "sealed":
		out.append(w["seal_pos"])
	if w["vault"] in ["open", "lesser"]:
		out.append(w["pedestal"])
	if w.has("drop") and not w["drop"]["taken"]:
		out.append(w["drop"]["pos"])
	return out


## The light under each seal breathes with it.
func _pulse_lights() -> void:
	var t := Time.get_ticks_msec() * 0.001
	for w in wings:
		if w.has("light") and main.lighting.lights.has(w["light"]):
			var l: Dictionary = main.lighting.lights[w["light"]]
			l["glow"] = 0.16 + 0.08 * sin(t * 2.4)
			l["k"] = 0.62 + 0.1 * sin(t * 2.4)


# --- a wing's question ---------------------------------------------------------------

## Shuts the way behind the climber (once nothing stands in the doorway).
func _try_seal(w: Dictionary) -> void:
	var gate := _tile_rect(w["door"])
	for e in main.enemies():
		if gate.grow(e.radius).has_point(e.global_position):
			last_tile = Vector2i(-999, -999)  # (try again next frame)
			return
	if gate.grow(main.player.radius).has_point(main.player.global_position):
		last_tile = Vector2i(-999, -999)
		return
	var d: Dictionary = main.door_view.door_at(w["door"][0])
	if not d.is_empty() and not d["open"]:
		main.door_view.open_door(d, true)
	w["gate_body"] = _close(w["door"])
	w["state"] = "closing"
	w["t"] = 0.0
	active = w
	for t in w["door"]:
		main.fx_burst(_tile_center(t), w["out"], Color(0.54, 0.51, 0.59), 12, 120.0)
	main.shake(7.0)
	main.sfx("slam", 0.55, 0.0, 0.0)
	main.sfx("step_plate", 0.45, -4.0, 0.0)
	main.banner = {"title": TEXT["sealed_title"], "lines": [TEXT["sealed"]], "t": 3.5}
	main.note_event("doors", main.notices.TEXT["doors_shut"], null, false)
	main.remark("wing")
	main.tip("door_sealed")
	dirty = true


func _tick_wing(w: Dictionary, delta: float, p) -> void:
	w["t"] += delta
	if w["state"] in ["waves", "champion", "puzzle"]:
		w["clock"] += delta
		if w["clock"] > FAILSAFE:
			_finish(w, "lesser", TEXT["failsafe"])
			return
	match String(w["state"]):
		"closing":
			if w["t"] >= float(WAVES["close_time"]):
				_begin(w)
		"rule":
			if w["t"] >= float(WAVES["rule_time"]):
				w["state"] = "waves"
				w["wave"] = 0
				w["hits0"] = p.hits_taken
				w["clock"] = 0.0
				_spawn_wave(w)
		"waves":
			_check_condition(w, p)
			if w["state"] != "waves":
				return
			if _alive(w["mobs"]).is_empty():
				if w.has("gap_t"):
					w["gap_t"] -= delta
					if w["gap_t"] <= 0.0:
						w.erase("gap_t")
						_spawn_wave(w)
				elif int(w["wave"]) < int(w["waves"]):
					w["gap_t"] = float(WAVES["gap"])
				else:
					_finish(w, "lesser" if w["broken"] else "open", "")
		"champion":
			if _alive(w["mobs"]).is_empty() and (w.get("champ") == null or not is_instance_valid(w["champ"]) or w["champ"].dead):
				_finish(w, "dark", "")


## The question itself: a puzzle if a host claimed the wing, else the waves.
func _begin(w: Dictionary) -> void:
	w["t"] = 0.0
	if w["puzzle_slot"] != "" and main.puzzle != null and main.puzzle.has_method("start_wing_puzzle"):
		w["state"] = "puzzle"
		w["clock"] = 0.0
		main.puzzle.start_wing_puzzle(w)
		return
	w["state"] = "rule"
	var c: Dictionary = CONDITIONS[w["condition"]]
	var rule: String = c["rule"] % int(w["limit"]) if w["condition"] == "swift" else String(c["rule"])
	main.banner = {"title": TEXT["rule_title"], "lines": [TEXT["waves"] % int(w["waves"]), rule], "t": 3.2}
	main.sfx("warn_knight", 0.7, -2.0, 0.0)


func _alive(list: Array) -> Array:
	return list.filter(func(e): return is_instance_valid(e) and not e.dead)


func _spawn_wave(w: Dictionary) -> void:
	w["wave"] = int(w["wave"]) + 1
	var budget: float = float(WAVES["budget"]) + float(WAVES["per_floor"]) * main.floor_num
	var kinds: Array = []
	var weights: Dictionary = main.tower_data().get("weights", {})
	while budget >= 0.8 and kinds.size() < int(WAVES["most"]):
		var k: String = main.Floors._pick(main.floor_num, budget, 99, weights)
		if k == "":
			break
		kinds.append(k)
		budget -= float(main.Floors.MONSTERS[k]["cost"])
	if kinds.is_empty():
		kinds = ["slime"]
	var spots: Array = w["spawns"].duplicate()
	spots.shuffle()
	var pp: Vector2 = main.player.global_position
	spots.sort_custom(func(a, b): return a.distance_to(pp) > b.distance_to(pp))
	var mobs: Array = []
	var placed: Array = []
	for k in kinds:
		var at: Vector2 = spots[0] if not spots.is_empty() else w["rect"].get_center()
		for s in spots:
			if placed.all(func(q): return q.distance_to(s) > 60.0) and s.distance_to(pp) > 110.0:
				at = s
				break
		placed.append(at)
		var e = main.spawn_enemy(k, at)
		e.wake()
		mobs.append(e)
		main.fx_burst(at, Vector2.UP, GOLD, 12, 140.0)
		main.fx_ring(at, GOLD, 44.0, 0.4, 3.0)
	w["mobs"] = mobs
	main.sfx("slam", 0.8, -6.0, 0.0)
	main.fx_text(w["rect"].get_center() + Vector2(0, -60), TEXT["wave"] % [int(w["wave"]), int(w["waves"])], GOLD)
	dirty = true


func _check_condition(w: Dictionary, p) -> void:
	if w["broken"]:
		return
	match String(w["condition"]):
		"untouched":
			if p.hits_taken > int(w["hits0"]):
				_break(w)
		"swift":
			if w["clock"] > float(w["limit"]):
				_break(w)


## The condition is broken: a lesser prize waits, or the champion comes.
func _break(w: Dictionary) -> void:
	w["broken"] = true
	var c: Dictionary = CONDITIONS.get(w.get("condition", ""), {})
	var lines: Array = [c.get("broken", "")]
	main.sfx("warn_knight", 0.5, 0.0, 0.0)
	if w["fail"] == "champion":
		lines.append(TEXT["broken_champion"])
		_send_champion(w)
		w["state"] = "champion"
	else:
		lines.append(TEXT["broken_lesser"])
	main.banner = {"title": TEXT["broken_title"], "lines": lines, "t": 3.0}
	dirty = true


func _send_champion(w: Dictionary) -> void:
	var weights: Dictionary = main.tower_data().get("weights", {})
	var kind := ""
	for i in 12:
		var k: String = main.Floors._pick(maxi(main.floor_num, 2), 9.0, 0, weights)
		if k != "" and (kind == "" or float(main.Floors.MONSTERS[k]["cost"]) > float(main.Floors.MONSTERS[kind]["cost"])):
			kind = k
	if kind == "" or kind == "bloomcap":
		kind = "knight"  # (a bloomcap can't walk: no champion of a mushroom)
	var spots: Array = w["spawns"].duplicate()
	var pp: Vector2 = main.player.global_position
	spots.sort_custom(func(a, b): return a.distance_to(pp) > b.distance_to(pp))
	var at: Vector2 = spots[0] if not spots.is_empty() else w["rect"].get_center()
	var e = main.EnemyScript.make(kind)
	e.setup(kind, main)
	e.make_champion()
	var tough: Vector2 = main.Floors.toughness(main.floor_num)
	e.max_hp *= tough.x
	e.hp = e.max_hp
	e.dmg *= tough.y
	e.position = at
	e.state_t = 0.8
	main.add_child(e)
	e.wake()
	w["champ"] = e
	main.fx_burst(at, Vector2.UP, GOLD, 26, 200.0)
	main.fx_ring(at, GOLD, 70.0, 0.5, 4.0)
	main.light_flash(at, GOLD, 1.8, 1.8, 0.5)
	main.fx_text(at + Vector2(0, -50), TEXT["champion"], GOLD)
	main.shake(8.0)


## A monster fell: a staggered-kills wing checks it; a champion leaves a crystal.
func on_enemy_killed(e) -> void:
	if active.is_empty():
		return
	var w := active
	if w["state"] == "waves" and w.get("condition", "") == "staggered" and not w["broken"] and e in w["mobs"] and e.stun <= 0.0:
		_break(w)
	if e == w.get("champ"):
		var drop: Array = Essence.drop_for(e.kind, main.floor_num)
		w["drop"] = {"pos": e.global_position, "kind": drop[0], "amount": round(crystal_amount() * float(REWARD["lesser"])), "taken": false}
		dirty = true


## Ends the question. `vault`: open (full prize), lesser, or dark (locked for good).
func _finish(w: Dictionary, vault: String, why: String) -> void:
	w["state"] = "done"
	_open(w["door"], w.get("gate_body"))
	w["gate_body"] = null
	for t in w["door"]:
		main.fx_burst(_tile_center(t), w["out"], GOLD, 12, 140.0)
	if w.has("light"):
		main.lighting.remove_light(w["light"])
		w.erase("light")
	var title: String = TEXT["won_title"]
	var line: String = TEXT["won"]
	if vault == "dark":
		title = TEXT["dark_title"]
		line = TEXT["dark"]
	else:
		if vault == "lesser":
			title = TEXT["lesser_title"]
			line = TEXT["lesser"]
		_open([w["vault_door"]], w.get("vault_body"))
		w["vault_body"] = null
		Makers.feed(main, "vault")
		w["prize_light"] = main.lighting.add_light(w["pedestal"], 120.0, GOLD, 0.75, 0.25)
		main.fx_burst(w["seal_pos"], w["vault_dir"], GOLD, 24, 220.0)
		main.light_flash(w["seal_pos"], GOLD, 1.8, 1.8, 0.5)
		main.room_view.queue_redraw()  # (the vault's doorway is floor now)
	w["vault"] = vault
	main.banner = {"title": title, "lines": ([why] if why != "" else []) + [line], "t": 3.2}
	main.sfx("clear", 0.9 if vault != "dark" else 0.6, -2.0, 0.0)
	main.shake(6.0)
	if active == w:
		active = {}
	dirty = true
	# Its rule kept on an early floor, with a part full: a Maker may grant
	# the mark (main.gd try_earned_mark, essence_flow.gd EARNED).
	if vault == "open" and not bool(w.get("broken", false)) and main.has_method("try_earned_mark"):
		main.try_earned_mark(w)
	# The Regard's challenge met (not given up on): the floor's portals wake.
	if why != TEXT["failsafe"] and main.get("portals") != null:
		main.portals.wake("wing")


## The puzzle host's answer for a wing it claimed.
func wing_solved(id: String) -> void:
	var w := _wing(id)
	if not w.is_empty() and not w["state"] in ["idle", "done"]:
		_finish(w, "open", "")


## (No puzzle host fails a wing yet: kept for one, README "Sealed wings, vaults and secrets".)
func wing_failed(id: String) -> void:
	var w := _wing(id)
	if w.is_empty() or w["state"] in ["idle", "done"]:
		return
	if w["state"] != "champion":
		w["fail"] = "champion"
		_break(w)


func _wing(id: String) -> Dictionary:
	for w in wings:
		if w["id"] == id:
			return w
	return {}


# --- rewards --------------------------------------------------------------------------

## How much essence a vault's crystal holds on this floor.
func crystal_amount() -> float:
	return float(REWARD["crystal_base"]) + float(REWARD["crystal_per_floor"]) * main.floor_num


## A vault's cards: two kinds of crystal (the tower's own and another, a
## slight steer of the next bond) and gear, a recall scroll or an item; a
## lesser prize is a smaller crystal and an item.
func vault_choices(lesser: bool) -> Array:
	var tk: String = main.tower_data().get("essence", "air")
	var others: Array = Essence.KINDS.keys().filter(func(k): return k != tk)
	others.shuffle()
	var marked: bool = not main.player.bonds.is_empty()
	if lesser:
		var amt := roundi(crystal_amount() * float(REWARD["lesser"]))
		return ["crystal:%s:%d" % [tk if randf() < 0.5 else others[0], amt], Items.random_item(marked)]
	var amt := roundi(crystal_amount())
	var out: Array = ["crystal:%s:%d" % [tk, amt], "crystal:%s:%d" % [others[0], amt]]
	var table := {"gear": float(REWARD["gear"]), "item": float(REWARD["item"])}
	if can_take_scroll():
		table["scroll"] = float(REWARD["scroll"])
	if not main.first_climb:
		table["tincture"] = float(main.Flow.TINCTURE["vault_chance"])
	match main.Floors._weighted(table):
		"gear":
			out.append("gear:" + better_gear())
		"scroll":
			out.append("scroll")
		"tincture":
			out.append(main.Flow.tincture_id(tk if randf() < 0.5 else String(others[1])))
		_:
			out.append(Items.random_item(marked))
	if not main.first_climb and randf() < charm_chance("vault"):
		out[2] = "gear:" + Gear.code(Charms.roll(main.floor_num))  # (now and then a charm instead: charms.gd LOOT)
	load("res://scripts/vessel.gd").vault_card(main, out)  # (very rarely, a vessel instead)
	return out


## A recall scroll is offered only to a marked climber not already carrying one.
func can_take_scroll() -> bool:
	return not main.first_climb and main.player.item_count("scroll") < Items.max_stack("scroll")


## Gear from a vault (as a card code, gear.gd code()): Fine at the least,
## rolled one rarity row higher than the floor's.
func better_gear() -> String:
	return Gear.code(main.find_gear("", 1, "fine"))


## Walking up to a vault's pedestal: its cards.
func _offer(w: Dictionary, lesser: bool) -> void:
	w["vault"] = "taken"
	if w.has("prize_light"):
		main.lighting.remove_light(w["prize_light"])
		w.erase("prize_light")
	main.offer_vault(vault_choices(lesser), TEXT["vault_title"], [TEXT["vault_lesser_sub"] if lesser else TEXT["vault_sub"]])
	dirty = true


func _take_drop(w: Dictionary) -> void:
	var d: Dictionary = w["drop"]
	d["taken"] = true
	main.profile.add_crystal(d["kind"], d["amount"])
	main.profile.save()
	var name: String = Items.CRYSTAL["name"] % Essence.display(d["kind"])
	main.note_event("crystal", TEXT["crystal_taken"] % name, Essence.color(d["kind"]))
	main.sfx("pickup", 0.9, -2.0, 0.0)
	dirty = true


## While a vault's cards show, the monsters wait (and start again after).
func freeze() -> void:
	_unfreeze()
	for e in main.enemies():
		if e.is_physics_processing():
			e.set_physics_process(false)
			frozen.append(e)


func _unfreeze() -> void:
	for e in frozen:
		if is_instance_valid(e):
			e.set_physics_process(true)
	frozen.clear()


func unfreeze() -> void:
	_unfreeze()


# --- secret rooms -------------------------------------------------------------------

func _tick_secret(s: Dictionary, delta: float, p) -> void:
	var pos: Vector2 = p.global_position
	if not s["open"]:
		var c := _tile_center(s["mouth"][0])
		var d := pos.distance_to(c)
		if d > SECRET["dust_near"] + 200.0:
			return
		# Dust drifting down from it now and then.
		if d < float(SECRET["dust_near"]):
			s["dust_t"] -= delta
			if s["dust_t"] <= 0.0:
				s["dust_t"] = randf_range(SECRET["dust_every"][0], SECRET["dust_every"][1])
				dust(s)
		if _leaning(s["mouth"][0], s["into"], p, s, delta):
			_open_secret(s)
		return
	# (open: its portal is portals.gd's, its vault vaults.gd's)


## Dust sifting down from a secret wall.
func dust(s: Dictionary) -> void:
	var c := _tile_center(s["mouth"][0])
	var into: Vector2 = s["into"]
	for i in 3:
		main.fx_burst(c - into * 14.0 + into.orthogonal() * randf_range(-14.0, 14.0), Vector2.DOWN, DUST, 2, 30.0)


## True once the climber has leaned into tile `t` (moving into it, pressed
## against it) for SECRET.lean seconds. `st` keeps the time leaned.
func _leaning(t: Vector2i, into: Vector2, p, st: Dictionary, delta: float) -> bool:
	var r := _tile_rect([t])
	var want := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var pressing: bool = r.grow(p.radius + 8.0).has_point(p.global_position) and want.length() > 0.2 and want.normalized().dot(into) > 0.6 and not p.dead
	if pressing:
		st["lean_t"] = float(st["lean_t"]) + delta
		if randf() < 6.0 * delta:
			main.fx_burst(r.get_center() - into * 18.0, -into, DUST, 2, 50.0)
		return st["lean_t"] >= float(SECRET["lean"])
	st["lean_t"] = maxf(0.0, float(st["lean_t"]) - delta * 2.0)
	return false


## The hidden spot gives way: the wall crumbles into a niche holding a
## portal, and the pocket beyond opens (its room no longer rock). `quiet`
## skips the show (the Designer's rift).
func _open_secret(s: Dictionary, quiet := false) -> void:
	if s["open"]:
		return
	s["open"] = true
	Makers.feed(main, "secret_room")
	var tiles := _secret_tiles(s)
	tiles.erase(s["mouth"][0])
	main.set_tiles_solid(tiles, false)
	if s.has("tithe_tile"):
		s["tithe_body"] = _close([s["tithe_tile"]])  # (the Tithe Stone stands in the pocket)
	_open([s["mouth"][0]], s.get("body"))
	s["body"] = null
	main.room_view.queue_redraw()  # (the niche and the pocket are floor now)
	s["light"] = main.lighting.add_light(s["rect"].get_center(), 170.0, Color(0.62, 0.52, 1.0), 0.55, 0.2)
	s["niche_light"] = main.lighting.add_light(s["portal_out"], 90.0, Color(0.62, 0.52, 1.0), 0.5, 0.25)
	if main.get("portals") != null:
		main.portals.refresh_fog()  # (seen from the floor, the pocket stays dark: it isn't part of it)
	dirty = true
	if quiet:
		return
	var c: Vector2 = s["portal_out"]
	main.fx_burst(c, -Vector2(s["into"]), Color(0.62, 0.72, 0.79), 16, 140.0)
	main.fx_burst(c, Vector2.ZERO, Color(0.62, 0.52, 1.0), 18, 160.0)
	main.fx_ring(c, Color(0.62, 0.52, 1.0), 60.0, 0.5, 3.0)
	main.fx_text(c + Vector2(0, -24), TEXT["secret_open"], Color(0.75, 0.68, 1.0))
	main.sfx("slam", 0.5, -2.0, 0.0)
	main.sfx("rift", 0.9, -4.0, 0.0)
	main.shake(4.0)
	main.banner = {"title": TEXT["secret_title"], "lines": [TEXT["secret_line"]], "t": 2.4}
	main.note_event("secret", main.notices.TEXT["secret"], null, false)
	main.tip("pocket")


## Three kinds of crystal, a little smaller than a vault's.
func hidden_crystals() -> Array:
	var kinds: Array = Essence.KINDS.keys()
	kinds.shuffle()
	var amt := roundi(crystal_amount() * float(REWARD["hidden"]))
	var out: Array = kinds.slice(0, 3).map(func(k): return "crystal:%s:%d" % [k, amt])
	if not main.first_climb and randf() < float(main.Flow.TINCTURE["hidden_chance"]):
		out[2] = main.Flow.tincture_id(String(kinds[2]))  # (now and then a tincture in place of a crystal)
	if not main.first_climb and randf() < charm_chance("secret"):
		out.append("gear:" + Gear.code(Charms.roll(main.floor_num)))  # (now and then a charm too: charms.gd LOOT)
	return out


## How often a vault or a secret room holds a charm (charms.gd LOOT; tests
## set charm_odds to be sure).
var charm_odds := 0.0 if Engine.has_meta("sixfold_test") else -1.0
func charm_chance(where: String) -> float:
	return charm_odds if charm_odds >= 0.0 else float(Charms.LOOT[where])


## Pays a pocket vault's Tithe Stone (vaults.gd pay_tithe).
func pay_tithe(s: Dictionary) -> bool:
	return main.vaults != null and main.vaults.pay_tithe(s)


# --- strikes ---------------------------------------------------------------------------

## A melee swing (player.gd): a secret wall knocks hollow (a finishing
## blow breaks it open: a portal); a seal holds.
func strike(from: Vector2, dir: Vector2, reach: float, arc_deg: float, heavy := false) -> void:
	for s in secrets:
		if s["open"]:
			continue
		if _in_swing(from, dir, _tile_center(s["mouth"][0]), reach, arc_deg):
			if heavy:
				_open_secret(s)
			else:
				knock(s)
	for w in wings:
		if w["vault"] in ["sealed", "dark"] and _in_swing(from, dir, w["seal_pos"], reach, arc_deg):
			main.fx_text(w["seal_pos"] + Vector2(0, -26), TEXT["seal_holds"] if w["vault"] == "sealed" else TEXT["seal_dark"], GOLD if w["vault"] == "sealed" else Color(0.6, 0.58, 0.62))
			main.sfx("hit_armor", 0.8, -6.0, 0.0)


## A burst (bombs, flasks, spells: main.explode) breaks a secret wall open too.
func blast(pos: Vector2, r: float) -> void:
	for s in secrets:
		if not s["open"] and _tile_center(s["mouth"][0]).distance_to(pos) < r + 24.0:
			_open_secret(s)


func _in_swing(from: Vector2, dir: Vector2, at: Vector2, reach: float, arc_deg: float) -> bool:
	var to := at - from
	return to.length() <= reach + 26.0 and absf(dir.angle_to(to)) <= deg_to_rad(arc_deg) + 0.3


## A secret wall struck: a hollow knock (a deep thud and its echo) and dust.
func knock(s: Dictionary) -> void:
	knocks += 1
	var c := _tile_center(s["mouth"][0])
	main.fx_text(c + Vector2(0, -22), TEXT["knock"], Color(0.81, 0.78, 0.72))
	main.sfx("hit_blunt", 0.5, -2.0, 0.0)
	get_tree().create_timer(0.13, false).timeout.connect(main.sfx.bind("hit_blunt", 0.42, -10.0, 0.0))
	dust(s)


# --- the wings' status, for the HUD ------------------------------------------------------

## True while a wing's question is being asked (the HUD shows its status).
func challenge_live() -> bool:
	return not active.is_empty() and active["state"] in ["rule", "waves", "champion"]


## {title, line, ok, champ} for the HUD, or {} when no question is asked.
func status() -> Dictionary:
	if not challenge_live():
		return {}
	var w := active
	var champ = w.get("champ")
	if champ != null and (not is_instance_valid(champ) or champ.dead):
		champ = null
	if w.get("condition", "") == "":
		return {"title": TEXT["champion"], "line": "", "ok": false, "champ": champ}
	var c: Dictionary = CONDITIONS[w["condition"]]
	var line := ""
	if w["state"] == "waves" or w["state"] == "rule":
		line = TEXT["wave"] % [maxi(int(w.get("wave", 0)), 1), int(w["waves"])]
		if w["condition"] == "swift":
			line += "  ·  %ds" % maxi(0, int(ceil(float(w["limit"]) - float(w["clock"]))))
	return {"title": String(c["name"]).to_upper(), "line": line, "ok": not w["broken"], "champ": champ}


# --- drawing ---------------------------------------------------------------------------

func _draw() -> void:
	if wings.is_empty() and secrets.is_empty():
		return
	var t := Time.get_ticks_msec() * 0.001
	var b := Draw.Batch.new()
	for w in wings:
		_draw_alcove_floor(b, w)
		if w["vault"] == "sealed" or w["vault"] == "dark":
			_draw_seal(b, w["seal_pos"], w["vault_dir"], String(w["emblem"]), t, w["vault"] == "dark")
		_draw_pedestal(b, w["pedestal"], w["vault"] in ["open", "lesser"], t)
		if w.get("gate_body") != null:
			_draw_gate(b, w)
		if w.has("drop") and not w["drop"]["taken"]:
			var bob := sin(t * 3.0) * 2.0
			b.dot(w["drop"]["pos"] + Vector2(0, 8), 7.0, Color(0, 0, 0, 0.3))
			Items.crystal_into(b, Essence.color(w["drop"]["kind"]), w["drop"]["pos"] + Vector2(0, bob - 4.0), 9.0)
	for s in secrets:
		if not s["open"]:
			if keen_outlined(s):
				_draw_keen(b, s["mouth"][0], t)
			continue
	b.flush(self)


## Gold lines inlaid in the alcove's floor.
func _draw_alcove_floor(b, w: Dictionary) -> void:
	var r: Rect2 = w["alcove"].grow(-8.0)
	var col := Color(GOLD, 0.22)
	b.line(r.position, Vector2(r.end.x, r.position.y), col, 1.5)
	b.line(Vector2(r.end.x, r.position.y), r.end, col, 1.5)
	b.line(r.end, Vector2(r.position.x, r.end.y), col, 1.5)
	b.line(Vector2(r.position.x, r.end.y), r.position, col, 1.5)
	b.arc(r.get_center(), 22.0, 0.0, TAU, 24, col, 1.5)


## A vault door's seal (the web version's drawSeal): a stone slab in a gold
## frame that pulses, a keyhole, and the challenge's emblem over it.
## `dark`: locked for good, grey and cracked.
func _draw_seal(b, c: Vector2, vdir: Vector2, emblem: String, t: float, dark: bool) -> void:
	var r := Rect2(c - Vector2(20, 20), Vector2(40, 40))
	var pulse := 0.5 + 0.5 * sin(t * 2.4)
	var gold := Color(0.6, 0.57, 0.62, 0.6) if dark else Color(GOLD.lerp(Color(1.0, 0.92, 0.65), pulse * 0.5), 0.7 + 0.3 * pulse)
	b.rect(Rect2(r.position + Vector2(2, 4), r.size), Color(0, 0, 0, 0.3))
	b.rect(r, Palette.OUTLINE)
	b.rect(r.grow(-2.0), Palette.DOOR_STONE.darkened(0.15 if not dark else 0.35))
	b.rect(r.grow(-4.0), Palette.DOOR_STONE.darkened(0.05 if not dark else 0.3))
	# The light leaking out under it, on the room's side.
	if not dark:
		var edge := c - vdir * 20.0
		var along := vdir.orthogonal()
		for i in 4:
			var depth := 3.0 + i * 5.0
			var a := edge - along * 15.0
			var e := edge + along * 15.0 - vdir * depth
			b.rect(Rect2(Vector2(minf(a.x, e.x), minf(a.y, e.y)), (e - a).abs()), Color(GOLD, (0.16 - i * 0.035) * (0.7 + 0.3 * pulse)))
	# The frame.
	var f := r.grow(-6.0)
	var lw := 2.0
	b.rect(Rect2(f.position, Vector2(f.size.x, lw)), gold)
	b.rect(Rect2(Vector2(f.position.x, f.end.y - lw), Vector2(f.size.x, lw)), gold)
	b.rect(Rect2(f.position, Vector2(lw, f.size.y)), gold)
	b.rect(Rect2(Vector2(f.end.x - lw, f.position.y), Vector2(lw, f.size.y)), gold)
	for k in [f.position, Vector2(f.end.x, f.position.y), f.end, Vector2(f.position.x, f.end.y)]:
		b.circle(k, 2.2, gold)
	# The keyhole.
	var kc := c + Vector2(0, 5)
	b.circle(kc, 4.2, gold)
	b.circle(kc, 2.6, Palette.OUTLINE)
	b.polygon(PackedVector2Array([kc + Vector2(-1.4, 1.0), kc + Vector2(1.4, 1.0), kc + Vector2(2.4, 8.0), kc + Vector2(-2.4, 8.0)]), Palette.OUTLINE)
	# The challenge's emblem.
	_emblem(b, c + Vector2(0, -7), 5.5, emblem, gold)
	if dark:
		b.polyline(PackedVector2Array([r.position + Vector2(8, 4), c + Vector2(-2, -3), c + Vector2(3, 4), r.end - Vector2(6, 3)]), Color(0.1, 0.09, 0.11), 1.6)


## The emblem of a challenge (never of the reward): a shield (take no hit),
## an hourglass (be quick), crossed blades (staggered kills), an eye (a puzzle).
func _emblem(b, c: Vector2, s: float, emblem: String, col: Color) -> void:
	match emblem:
		"shield":
			b.polygon(PackedVector2Array([c + Vector2(-s, -s * 0.8), c + Vector2(s, -s * 0.8), c + Vector2(s * 0.85, s * 0.2), c + Vector2(0, s), c + Vector2(-s * 0.85, s * 0.2)]), col)
			b.line(c + Vector2(0, -s * 0.6), c + Vector2(0, s * 0.7), Palette.DOOR_STONE, 1.2)
		"hourglass":
			b.polygon(PackedVector2Array([c + Vector2(-s, -s), c + Vector2(s, -s), c + Vector2(0, 0)]), col)
			b.polygon(PackedVector2Array([c + Vector2(-s, s), c + Vector2(s, s), c + Vector2(0, 0)]), col)
			b.rect(Rect2(c + Vector2(-s, -s - 1.2), Vector2(s * 2.0, 1.2)), col)
			b.rect(Rect2(c + Vector2(-s, s), Vector2(s * 2.0, 1.2)), col)
		"blades":
			b.line(c + Vector2(-s, -s), c + Vector2(s, s), col, 1.8)
			b.line(c + Vector2(s, -s), c + Vector2(-s, s), col, 1.8)
			b.line(c + Vector2(-s * 0.9, s * 0.3), c + Vector2(-s * 0.3, s * 0.9), col, 1.6)
			b.line(c + Vector2(s * 0.9, s * 0.3), c + Vector2(s * 0.3, s * 0.9), col, 1.6)
		"eye":
			var pts := PackedVector2Array()
			for i in 13:
				var a := PI * float(i) / 12.0
				pts.append(c + Vector2(cos(a) * s * 1.3, -sin(a) * s * 0.7))
			b.polyline(pts, col, 1.4)
			var low := PackedVector2Array()
			for i in 13:
				var a := PI * float(i) / 12.0
				low.append(c + Vector2(cos(a) * s * 1.3, sin(a) * s * 0.7))
			b.polyline(low, col, 1.4)
			b.circle(c, s * 0.38, col)
		_:
			b.arc(c, s * 0.8, 0.0, TAU, 14, col, 1.6)


## A stone pedestal; while its prize waits, a gold light floats over it.
func _draw_pedestal(b, c: Vector2, waiting: bool, t: float) -> void:
	b.dot(c + Vector2(0, 12), 13.0, Color(0, 0, 0, 0.3))
	b.rect(Rect2(c + Vector2(-11, 2), Vector2(22, 10)), Palette.OUTLINE)
	b.rect(Rect2(c + Vector2(-10, 3), Vector2(20, 8)), Palette.DOOR_STONE.lightened(0.05))
	b.rect(Rect2(c + Vector2(-7, -6), Vector2(14, 10)), Palette.OUTLINE)
	b.rect(Rect2(c + Vector2(-6, -5), Vector2(12, 9)), Palette.DOOR_STONE.lightened(0.12))
	b.rect(Rect2(c + Vector2(-9, -9), Vector2(18, 4)), Palette.OUTLINE)
	b.rect(Rect2(c + Vector2(-8, -8), Vector2(16, 3)), Palette.DOOR_STONE.lightened(0.2))
	if waiting:
		var bob := sin(t * 2.6) * 2.5
		var oc := c + Vector2(0, -20 + bob)
		for i in 4:
			b.dot(oc, 12.0 - i * 2.5, Color(GOLD, 0.08))
		b.ball(oc, 4.5, Color(1.0, 0.86, 0.5))
		b.dot(oc + Vector2(-1.4, -1.6), 1.4, Color(1, 1, 1, 0.8))


## A shut wing's doorway: a stone slab with the eye of the Regard.
func _draw_gate(b, w: Dictionary) -> void:
	var r := _tile_rect(w["door"])
	b.rect(r, Palette.OUTLINE)
	b.rect(r.grow(-2.0), Palette.DOOR_STONE.darkened(0.2))
	b.rect(r.grow(-5.0), Palette.DOOR_STONE.darkened(0.1))
	var c := r.get_center()
	b.circle(c, 7.0, Color(0.9, 0.22, 0.15, 0.85))
	b.circle(c, 3.0, Color(1.0, 0.85, 0.6))


## Keen Eyes: a faint outline around a secret wall.
func _draw_keen(b, t0: Vector2i, t: float) -> void:
	var r := _tile_rect([t0]).grow(-3.0)
	var col := Color(0.75, 0.9, 1.0, 0.25 + 0.15 * sin(t * 2.0))
	var n := 5
	for side in 4:
		var a: Vector2 = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)][side]
		var e: Vector2 = [Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y), r.position][side]
		for i in n:
			if i % 2 == 0:
				b.line(a.lerp(e, float(i) / n), a.lerp(e, float(i + 1) / n), col, 1.5)
