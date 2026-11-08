extends Node2D
## The beast's tests: each floor of rooms has one puzzle room, and solving
## its puzzle lifts the WARD on the stair (the stair won't open until then).
## Puzzles only use what every climber has (strikes, arrows, walking), so a
## main puzzle never needs a bond, an item or a piece of gear.
##
## Two kinds so far (rooms.gd draws the rooms):
##   "eyes":   stone eyes behind low rails. Hit every eye (arrows fly over the
##             rails) to solve it. On harder floors each eye only stays lit
##             for EYE_WINDOW seconds, so all of them must be lit together.
##   "plates": pressure plates that need a WEIGHT: a stone block pushed onto
##             it, or a monster standing on it (the climber is too light).
##             Every plate held down at once solves it. Strike the lever to
##             put the blocks back if one gets stuck.
## Solving also opens the room's gate, behind which waits a reward.
##
## The objects:
##   rails  low walls: block walking, but not sight or shots
##   gates  closed until the puzzle is solved
##   blocks stone blocks: walk into one for PUSH_TIME to slide it a tile

const Floors := preload("res://scripts/floors.gd")
const Draw := preload("res://scripts/draw_util.gd")
const Essence := preload("res://scripts/essence.gd")

const TEXT := {
	"warded": "The stair is warded. Solve the beast's test to lift it.",
	"lifted_title": "THE WARD LIFTS",
	"lifted": "The beast takes note.",
	"reward": "The gate opens",
	"reset": "The blocks return",
}
## Harder eye puzzles: an eye stays lit this long after it's hit.
const EYE_WINDOW := 2.5
## How long you lean on a block before it slides.
const PUSH_TIME := 0.3
## How close an eye or lever must be to a strike, beyond the swing's reach.
const STRIKE_SLACK := 18.0
## Essence in the reward behind the gate: this, plus this much per floor.
const REWARD := Vector2(10.0, 4.0)

var main
var kind := ""  # "eyes", "plates" or "" (no puzzle on this floor)
var tier := 1
var solved := false
var eyes: Array = []  # {pos, lit}  lit: seconds left lit (INF once lit, on easy floors)
var plates: Array = []  # {pos, down}
var blocks: Array = []  # {pos, home, body, push_t}
var rails: Array = []  # Rect2 (world)
var gates: Array = []  # {rect, open, body}
var levers: Array = []  # {pos, t}
var rewards: Array = []  # world positions
var bodies: Array = []
var ward_glow := 0.0  # fades out when the ward lifts
var glow: Node2D  # the eyes and the ward, drawn unlit so they show in dark corners


func _ready() -> void:
	z_index = -3  # on the floor, over the traps, under everyone
	glow = Node2D.new()
	var unlit := CanvasItemMaterial.new()
	unlit.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	glow.material = unlit
	glow.draw.connect(_draw_glow)
	add_child(glow)


func queue_redraw_all() -> void:
	queue_redraw()
	if glow != null:
		glow.queue_redraw()


## A new floor: build the puzzle from the floor plan's spec (or none).
func setup(spec: Dictionary) -> void:
	clear()
	if spec.is_empty():
		return
	kind = spec["type"]
	tier = int(spec.get("tier", 1))
	for p in spec.get("eyes", []):
		eyes.append({"pos": p, "lit": 0.0})
	for p in spec.get("plates", []):
		plates.append({"pos": p, "down": false})
	for r in spec.get("rails", []):
		rails.append(r)
		_add_body(r)
		_set_solid(r, true)
	for r in spec.get("gates", []):
		gates.append({"rect": r, "open": false, "body": _add_body(r)})
		_set_solid(r, true)
	for p in spec.get("pushers", []):
		var r := Rect2(p - Vector2(19, 19), Vector2(38, 38))
		blocks.append({"pos": p, "home": p, "body": _add_body(r), "push_t": 0.0})
		_set_solid(r, true)
	for p in spec.get("levers", []):
		levers.append({"pos": p, "t": 0.0})
	rewards = spec.get("rewards", []).duplicate()
	ward_glow = 1.0
	queue_redraw_all()


func clear() -> void:
	for b in bodies:
		if is_instance_valid(b):
			b.queue_free()
	bodies.clear()
	kind = ""
	solved = false
	eyes.clear()
	plates.clear()
	blocks.clear()
	rails.clear()
	gates.clear()
	levers.clear()
	rewards.clear()
	ward_glow = 0.0
	queue_redraw_all()


## True while the stair is still warded.
func active() -> bool:
	return kind != "" and not solved


func _add_body(r: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = r.get_center()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = r.size
	shape.shape = box
	body.add_child(shape)
	main.add_child(body)
	bodies.append(body)
	return body


## Marks tiles as blocked for monsters' paths (not for sight or shots).
func _set_solid(r: Rect2, on: bool) -> void:
	if main.astar == null:
		return
	for t in main._tiles_in(r.grow(-2.0)):
		main.astar.set_point_solid(t, on or main._is_solid_tile(t.x, t.y))


# --- running -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if kind == "" or main == null or main.player == null:
		return
	for l in levers:
		l["t"] = maxf(0.0, l["t"] - delta)
	if solved:
		ward_glow = maxf(0.0, ward_glow - delta * 0.8)
		queue_redraw_all()
		return
	if tier >= 2:
		for e in eyes:
			if e["lit"] > 0.0 and e["lit"] < INF:
				e["lit"] = maxf(0.0, e["lit"] - delta)
	for pl in plates:
		pl["down"] = _weighed(pl["pos"])
	_push(delta)
	_check()
	queue_redraw_all()


## A plate is held down by a block, or by a monster standing on it.
func _weighed(pos: Vector2) -> bool:
	for b in blocks:
		if b["pos"].distance_to(pos) < 8.0:
			return true
	for e in main.enemies():
		if e.is_queued_for_deletion() or e.kind in main.EnemyScript.FLIERS:
			continue
		if e.global_position.distance_to(pos) < 22.0:
			return true
	return false


## Leaning on a block slides it a tile.
func _push(delta: float) -> void:
	var p = main.player
	var want: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	for b in blocks:
		var to: Vector2 = b["pos"] - p.global_position
		var axis := Vector2(signf(to.x), 0.0) if absf(to.x) > absf(to.y) else Vector2(0.0, signf(to.y))
		var leaning: bool = to.length() < p.radius + 30.0 and want.length() > 0.3 and want.normalized().dot(axis) > 0.7
		if not leaning:
			b["push_t"] = 0.0
			continue
		b["push_t"] += delta
		if b["push_t"] >= PUSH_TIME:
			b["push_t"] = 0.0
			slide(b, axis)


## Slides a block one tile, if the tile is free. Returns whether it moved.
func slide(b: Dictionary, dir: Vector2) -> bool:
	var to: Vector2 = b["pos"] + dir * Floors.CELL
	if not _free(to, b):
		main.sfx("hit_armor", 0.6, -12.0)
		return false
	var old := Rect2(b["pos"] - Vector2(19, 19), Vector2(38, 38))
	_set_solid(old, false)
	b["pos"] = to
	_set_solid(Rect2(to - Vector2(19, 19), Vector2(38, 38)), true)
	var body: StaticBody2D = b["body"]
	if b.get("tween") != null and b["tween"].is_valid():
		b["tween"].kill()
	var tw := body.create_tween()
	tw.tween_property(body, "position", to, 0.14)
	b["tween"] = tw
	main.sfx("slam", 0.9, -10.0)
	main.shake(1.5)
	return true


func _free(pos: Vector2, me: Dictionary) -> bool:
	if main.is_solid(pos) or main.in_chasm(pos):
		return false
	for r in rails:
		if r.has_point(pos):
			return false
	for g in gates:
		if not g["open"] and g["rect"].has_point(pos):
			return false
	for b in blocks:
		if b != me and b["pos"].distance_to(pos) < 20.0:
			return false
	for pl in main.pillars:
		if pos.distance_to(pl["pos"]) < pl["r"] + 18.0:
			return false
	return true


func _check() -> void:
	if solved:
		return
	match kind:
		"eyes":
			for e in eyes:
				if e["lit"] <= 0.0:
					return
			_solve()
		"plates":
			for pl in plates:
				if not pl["down"]:
					return
			_solve()


func _solve() -> void:
	solved = true
	for g in gates:
		g["open"] = true
		if is_instance_valid(g["body"]):
			g["body"].queue_free()
		_set_solid(g["rect"], false)
	var amount := REWARD.x + REWARD.y * float(maxi(main.floor_num - 2, 0))
	for r in rewards:
		main.gather_essence(main.tower_data().get("essence", "air"), amount, r)
		main.fx_ring(r, Color(1.0, 0.85, 0.5), 60.0, 0.5, 3.0)
	main.lift_ward()
	queue_redraw_all()


# --- what strikes and arrows hit ------------------------------------------------

## A strike from `from` toward `dir`: lights eyes and pulls levers in reach.
## Returns how many it hit.
func strike(from: Vector2, dir: Vector2, reach: float, arc_deg: float) -> int:
	if kind == "":
		return 0
	var hits := 0
	for e in eyes:
		if _in_swing(from, dir, e["pos"], reach, arc_deg):
			_light(e)
			hits += 1
	for l in levers:
		if _in_swing(from, dir, l["pos"], reach, arc_deg):
			_pull(l)
			hits += 1
	return hits


func _in_swing(from: Vector2, dir: Vector2, at: Vector2, reach: float, arc_deg: float) -> bool:
	var to := at - from
	return to.length() <= reach + STRIKE_SLACK and absf(dir.angle_to(to)) <= deg_to_rad(arc_deg) and main.clear_line(from, at)


## An arrow (or bolt) at `pos`: true if it struck an eye or a lever (it stops there).
func shot(pos: Vector2) -> bool:
	if kind == "":
		return false
	for e in eyes:
		if pos.distance_to(e["pos"]) < 17.0:
			_light(e)
			return true
	for l in levers:
		if pos.distance_to(l["pos"]) < 14.0:
			_pull(l)
			return true
	return false


func _light(e: Dictionary) -> void:
	if solved:
		return
	var was: float = e["lit"]
	e["lit"] = EYE_WINDOW if tier >= 2 else INF
	if was <= 0.0:
		main.sfx("glint", 1.1, -2.0, 0.0)
		main.fx_ring(e["pos"], Color(1.0, 0.85, 0.45), 30.0, 0.3, 2.5)
		main.light_flash(e["pos"], Color(1.0, 0.8, 0.4), 0.8, 1.2, 0.3)


## The lever puts every block back where it started.
func _pull(l: Dictionary) -> void:
	if l["t"] > 0.0:
		return
	l["t"] = 0.6
	main.sfx("trap_click", 0.8, -4.0)
	if solved:
		return
	for b in blocks:
		if b["pos"] == b["home"]:
			continue
		_set_solid(Rect2(b["pos"] - Vector2(19, 19), Vector2(38, 38)), false)
		if b.get("tween") != null and b["tween"].is_valid():
			b["tween"].kill()  # (a slide still under way)
		b["pos"] = b["home"]
		b["body"].position = b["home"]
		_set_solid(Rect2(b["home"] - Vector2(19, 19), Vector2(38, 38)), true)
	main.fx_text(l["pos"] + Vector2(0, -30), TEXT["reset"], Color(0.85, 0.82, 0.9))


## Where auto-aim should point when no monster is near: the nearest unlit eye
## in sight and in reach (or Vector2.INF for none).
func aim_point(from: Vector2, reach: float) -> Vector2:
	if not active():
		return Vector2.INF
	var best := Vector2.INF
	var best_d := reach
	for e in eyes:
		if e["lit"] > 0.0:
			continue
		var d: float = from.distance_to(e["pos"])
		if d < best_d and main.clear_line(from, e["pos"]):
			best_d = d
			best = e["pos"]
	return best


# --- drawing -------------------------------------------------------------------

func _draw() -> void:
	if kind == "" and ward_glow <= 0.0:
		return
	var t := Time.get_ticks_msec() * 0.001
	var stone := Color(0.42, 0.4, 0.44)
	var dark := Color(0.16, 0.15, 0.18)
	# Rails: a low stone balustrade with posts.
	for r in rails:
		var rr: Rect2 = r
		var band := Rect2(rr.position + Vector2(2, rr.size.y * 0.3), Vector2(rr.size.x - 4, rr.size.y * 0.4)) if rr.size.x >= rr.size.y \
			else Rect2(rr.position + Vector2(rr.size.x * 0.3, 2), Vector2(rr.size.x * 0.4, rr.size.y - 4))
		draw_rect(band.grow(1.5), dark)
		draw_rect(band, stone)
		var n := int(maxf(rr.size.x, rr.size.y) / Floors.CELL)
		for i in n:
			var c := rr.position + (Vector2(Floors.CELL * (i + 0.5), rr.size.y * 0.5) if rr.size.x >= rr.size.y else Vector2(rr.size.x * 0.5, Floors.CELL * (i + 0.5)))
			draw_rect(Rect2(c - Vector2(6, 6), Vector2(12, 12)), dark)
			draw_rect(Rect2(c - Vector2(5, 5), Vector2(10, 10)), stone.lightened(0.15))
	# Plates: a square that sinks and glows when weighed down.
	for pl in plates:
		var c: Vector2 = pl["pos"]
		var down: bool = pl["down"] or solved
		var plate := Rect2(c - Vector2(16, 16), Vector2(32, 32))
		draw_rect(plate.grow(2.0), dark)
		draw_rect(plate, stone.darkened(0.25 if down else 0.0))
		draw_rect(plate.grow(-6.0), Color(1.0, 0.82, 0.45, 0.85) if down else Color(0.3, 0.28, 0.34))
	# Gates: iron bars until solved.
	for g in gates:
		var gr: Rect2 = g["rect"]
		if g["open"]:
			draw_rect(gr.grow(-2.0), Color(0.2, 0.18, 0.16, 0.35), false, 1.0)
			continue
		draw_rect(gr.grow(-1.0), Color(0.08, 0.07, 0.09, 0.6))
		var vertical := gr.size.x >= gr.size.y
		for i in 5:
			var f := (i + 0.5) / 5.0
			if vertical:
				var x := gr.position.x + gr.size.x * f
				Draw.line(self, Vector2(x, gr.position.y + 2), Vector2(x, gr.end.y - 2), Color(0.55, 0.55, 0.6), 3.0)
			else:
				var y := gr.position.y + gr.size.y * f
				Draw.line(self, Vector2(gr.position.x + 2, y), Vector2(gr.end.x - 2, y), Color(0.55, 0.55, 0.6), 3.0)
	# Blocks: carved stone cubes, lit from the top-left.
	for b in blocks:
		var c: Vector2 = b["body"].position
		var box := Rect2(c - Vector2(18, 18), Vector2(36, 36))
		draw_rect(box.grow(2.0), Color(0, 0, 0, 0.35))
		draw_rect(box, Color(0.5, 0.47, 0.44))
		draw_rect(Rect2(box.position, Vector2(box.size.x, 7)), Color(0.62, 0.59, 0.55))
		draw_rect(Rect2(box.position + Vector2(0, box.size.y - 6), Vector2(box.size.x, 6)), Color(0.34, 0.31, 0.3))
		draw_rect(box.grow(-9.0), Color(0.44, 0.41, 0.39))
		if b["push_t"] > 0.0:
			draw_rect(box.grow(3.0), Color(1, 1, 1, 0.25 + b["push_t"] / PUSH_TIME * 0.4), false, 2.0)
	# Levers: a post with a handle.
	for l in levers:
		var c: Vector2 = l["pos"]
		draw_circle(c, 10.0, dark)
		draw_circle(c, 8.0, stone)
		var ang := -0.9 if l["t"] <= 0.0 else 0.9
		Draw.line(self, c, c + Vector2.from_angle(ang - PI / 2.0) * 16.0, Color(0.6, 0.5, 0.35), 4.0)
		draw_circle(c + Vector2.from_angle(ang - PI / 2.0) * 16.0, 4.0, Color(0.75, 0.3, 0.25))



## The eyes and the ward (unlit: they glow even in an unlit corner).
func _draw_glow() -> void:
	if kind == "" and ward_glow <= 0.0:
		return
	var t := Time.get_ticks_msec() * 0.001
	var stone := Color(0.5, 0.47, 0.52)
	var dark := Color(0.12, 0.11, 0.14)
	# Eyes: a stone socket; dull while shut, gold while lit.
	for e in eyes:
		var c: Vector2 = e["pos"]
		var lit: bool = e["lit"] > 0.0 or solved
		glow.draw_circle(c, 15.0, dark)
		glow.draw_circle(c, 13.0, stone)
		var pts := PackedVector2Array()
		for i in 16:
			var a := TAU * i / 16.0
			pts.append(c + Vector2(cos(a) * 11.0, sin(a) * (7.0 if lit else 2.5)))
		glow.draw_colored_polygon(pts, Color(1.0, 0.85, 0.45) if lit else Color(0.25, 0.2, 0.3))
		if lit:
			glow.draw_circle(c, 3.5, Color(0.25, 0.1, 0.05))
		elif not solved:
			# A faint pulse so it reads as something to hit.
			var pulse := 0.45 + 0.3 * sin(t * 3.0)
			glow.draw_arc(c, 18.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.5, pulse), 1.5)
		# Harder floors: a ring that runs down while the eye stays lit.
		if tier >= 2 and not solved and e["lit"] > 0.0 and e["lit"] < INF:
			glow.draw_arc(c, 19.0, -PI / 2.0, -PI / 2.0 + TAU * e["lit"] / EYE_WINDOW, 24, Color(1.0, 0.85, 0.45, 0.9), 2.0)
	# The ward on the stair: a ring of runes until it lifts.
	if ward_glow > 0.0 and main.layout_on:
		var c: Vector2 = main.stair_pos
		var col := Color(0.75, 0.55, 1.0, 0.75 * ward_glow)
		glow.draw_arc(c, 34.0, 0.0, TAU, 40, col, 2.5)
		glow.draw_arc(c, 26.0, t * 0.6, t * 0.6 + TAU * 0.8, 32, Color(col, col.a * 0.6), 1.5)
		for i in 6:
			var a := TAU * i / 6.0 - t * 0.4
			var p := c + Vector2.from_angle(a) * 34.0
			glow.draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), col)
