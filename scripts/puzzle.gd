extends Node2D
## The beast's tests: each floor of rooms has one puzzle, in its GALLERY,
## and solving it lifts the WARD on the stair (the stair won't open until
## then). It's all part of the Regard: the beast watches, and tests.
##
## This is the HOST. Each kind of puzzle is its own script in
## scripts/puzzles/ (base.gd says what they share; catalog.gd which floor
## gets which, and how hard). The host keeps what every kind needs:
##   the WARD     lifted when the puzzle is solved (main.lift_ward)
##   the REWARD   essence where the puzzle says (and a gate, in hand-made rooms)
##   MODES        quiet: the puzzle sleeps until the guards in its room are
##                dead; pressure (higher floors): monsters keep coming while
##                you think
##   the SEAL     some puzzles close the room's doorways behind you until solved
##   FAILURE      a wrong answer brings an AMBUSH; once it's beaten (or after
##                LOCK_MAX seconds) the puzzle resets. A main puzzle never locks
##                you out: it only uses what every climber has (strikes, a bow,
##                rolls, jumps, parries, walking), and it's always solvable.
##   AUTO-AIM     aim_point: what a phone's auto-aim turns to when no foe is near
##   RULE TEXT    framed panels in the world, drawn over the darkness
##
## The host also draws rails and gates (hand-made rooms):
##   rails  low walls: block walking, but not sight or shots
##   gates  closed until the puzzle is solved

const Floors := preload("res://scripts/floors.gd")
const Draw := preload("res://scripts/draw_util.gd")
const Catalog := preload("res://scripts/puzzles/catalog.gd")
const UI := preload("res://scripts/ui.gd")

const TEXT := {
	"warded": "The stair is warded. Solve the beast's test to lift it.",
	"lifted_title": "THE WARD LIFTS",
	"lifted": "The beast takes note.",
	"solved": "%s: solved",
	"sealed": "The way behind you grinds shut. This room will not let you go until its question is answered.",
	"quiet": "The test sleeps while its guards still stand.",
	"wakes": "The test wakes",
	"pressure": "The beast sends more while you think.",
	"ambush": "The beast sends its hunters. Survive, and the test begins again.",
	"locked": "Survive the hunters, and the test begins again.",
	"again": "The test begins again",
	"watch": "The beast is watching.",
	"shortcut": "Your bond: %s",
}
## Essence in the reward: this, plus this much per floor.
const REWARD := Vector2(10.0, 4.0)
## A failure's ambush: this many monsters, plus one per this many floors.
const AMBUSH := Vector2i(2, 4)
## After a failure the puzzle resets once its ambush is dead, or after this long.
const LOCK_MAX := 40.0
## Pressure mode: a monster every this many seconds while you're in the room,
## at most this many at once, and this many a floor in all.
const PRESSURE_EVERY := 9.0
const PRESSURE_ALIVE := 2
const PRESSURE_CAP := 8
## How often the quiet mode looks for living guards.
const GUARD_CHECK := 0.25

var main
var kind := ""  # the puzzle's kind ("" for none on this floor)
var cur  # the running puzzle (a script from scripts/puzzles/)
var spec := {}
var tier := 1
var mode := "quiet"  # "quiet", "pressure" or "" (neither)
var room := Rect2()
var solved := false
var awake := true  # quiet mode: false while guards stand in the room
var locked := false  # failed: the ambush is on
var lock_t := 0.0
var ambushers: Array = []
var sealed := false
var seal_bodies: Array = []
var press_t := 0.0
var press_spawned := 0
var pressers: Array = []
var guard_t := 0.0
var rails: Array = []  # Rect2 (world)
var gates: Array = []  # {rect, open, body}
var rewards: Array = []  # world positions
var bodies: Array = []
var light_ids: Array = []
var ward_glow := 0.0  # fades out when the ward lifts
var redraw_t := 0.0
var glow: Node2D  # what pulses (redrawn 30 times a second while unsolved)
var over: Node2D  # glow drawn over the darkness (the beam's core, lit stones)
var labels: Node2D  # the rule text, over the darkness
var _drawn_state := []
var _labels_on := false


func _ready() -> void:
	z_index = -3  # on the floor, over the traps, under everyone
	glow = Node2D.new()
	glow.draw.connect(_draw_glow)
	add_child(glow)
	over = Node2D.new()
	over.z_as_relative = false
	over.z_index = 45  # just over the darkness (40)
	var add := CanvasItemMaterial.new()
	add.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	over.material = add
	over.draw.connect(_draw_over)
	add_child(over)
	labels = Node2D.new()
	labels.z_as_relative = false
	labels.z_index = 58  # over the darkness, under the floating numbers (60)
	labels.draw.connect(_draw_labels)
	add_child(labels)


func queue_redraw_all() -> void:
	queue_redraw()
	if glow != null:
		glow.queue_redraw()
		over.queue_redraw()
		labels.queue_redraw()


## A new floor: build the puzzle from the floor plan's spec (or none).
func setup(s: Dictionary) -> void:
	clear()
	if s.is_empty() or not Catalog.TYPES.has(String(s.get("type", ""))):
		return
	spec = s
	kind = s["type"]
	tier = int(s.get("tier", 1))
	room = s.get("room", main.room)
	var script = Catalog.TYPES[kind]
	mode = String(s.get("mode", "quiet"))
	if not (mode in script.MODES):
		mode = ""
	cur = script.new()
	cur.host = self
	cur.main = main
	for r in s.get("rails", []):
		rails.append(r)
		add_body(r)
	for r in s.get("gates", []):
		gates.append({"rect": r, "open": false, "body": add_body(r)})
	rewards = s.get("rewards", []).duplicate()
	cur.setup(s)
	awake = mode != "quiet"
	guard_t = 0.0
	press_t = PRESSURE_EVERY * 0.5
	ward_glow = 1.0
	_drawn_state = []
	queue_redraw_all()


func clear() -> void:
	for b in bodies + seal_bodies:
		if is_instance_valid(b):
			b.queue_free()
	bodies.clear()
	seal_bodies.clear()
	if main != null and main.lighting != null:
		for id in light_ids:
			main.lighting.remove_light(id)
	light_ids.clear()
	kind = ""
	cur = null
	spec = {}
	solved = false
	awake = true
	locked = false
	sealed = false
	ambushers.clear()
	pressers.clear()
	press_spawned = 0
	rails.clear()
	gates.clear()
	rewards.clear()
	ward_glow = 0.0
	_labels_on = false
	queue_redraw_all()


## True while the stair is still warded.
func active() -> bool:
	return kind != "" and not solved


## The puzzle's name here (towers name some of theirs differently).
func display_name() -> String:
	return String(spec.get("name", Catalog.display_name(kind, String(spec.get("tower", "")))))


# --- what the puzzles use --------------------------------------------------------

func add_body(r: Rect2) -> StaticBody2D:
	var body := _static_body(r.get_center())
	var box := RectangleShape2D.new()
	box.size = r.size
	body.get_child(0).shape = box
	bodies.append(body)
	set_solid(r, true)
	return body


func add_round_body(pos: Vector2, r: float) -> StaticBody2D:
	var body := _static_body(pos)
	var circle := CircleShape2D.new()
	circle.radius = r
	body.get_child(0).shape = circle
	bodies.append(body)
	return body


func _static_body(pos: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	body.add_child(CollisionShape2D.new())
	main.add_child(body)
	return body


## Marks tiles as blocked for monsters' paths (not for sight or shots).
func set_solid(r: Rect2, on: bool) -> void:
	if main.astar == null:
		return
	for t in main._tiles_in(r.grow(-2.0)):
		main.astar.set_point_solid(t, on or main._is_solid_tile(t.x, t.y))


## A lasting light (lighting.gd's registry), taken away with the puzzle.
func add_light(pos: Vector2, reach: float, color: Color, strength := 0.8, glow_k := 0.0) -> int:
	if main.lighting == null:
		return -1
	var id: int = main.lighting.add_light(pos, reach, color, strength, glow_k)
	light_ids.append(id)
	return id


func remove_light(id: int) -> void:
	if main.lighting != null:
		main.lighting.remove_light(id)
	light_ids.erase(id)


## The puzzle is solved: the ward lifts, the seal opens, the reward appears.
func solve() -> void:
	if solved or kind == "":
		return
	solved = true
	locked = false
	_unseal()
	for g in gates:
		g["open"] = true
		if is_instance_valid(g["body"]):
			g["body"].queue_free()
		set_solid(g["rect"], false)
	var amount := REWARD.x + REWARD.y * float(maxi(main.floor_num - 2, 0))
	for r in rewards:
		main.gather_essence(main.tower_data().get("essence", "air"), amount, r)
		main.fx_ring(r, Color(1.0, 0.85, 0.5), 60.0, 0.5, 3.0)
	main.lift_ward()
	main.fx_text(room.get_center() + Vector2(0, -50), TEXT["solved"] % display_name(), Color(1.0, 0.89, 0.63))
	main.shake(4.0)
	queue_redraw_all()


## A wrong answer: the beast sends hunters. Once they're dead (or after
## LOCK_MAX seconds) the puzzle resets. Never a lock-out.
func fail(msg: String) -> void:
	if solved or locked or kind == "":
		return
	locked = true
	lock_t = 0.0
	_unseal()  # (you may run, or fight)
	main.banner = {"title": display_name().to_upper(), "lines": [msg, TEXT["ambush"]], "t": 3.0}
	main.shake(6.0)
	main.sfx("warn_knight", 0.7, -2.0, 0.0)
	var n: int = AMBUSH.x + main.floor_num / AMBUSH.y
	for k in n:
		var e = _spawn_here(2.0)
		if e != null:
			ambushers.append(e)
	queue_redraw_all()


func _spawn_here(budget: float):
	var pos := _spot()
	if pos == Vector2.INF:
		return null
	var kind_e: String = Floors._pick(main.floor_num, budget, 99, main.tower_data().get("weights", {}))
	if kind_e == "":
		kind_e = "slime"
	var e = main.spawn_enemy(kind_e, pos)
	e.wake()
	main.floor_total += 1
	main.foes_changed()
	main.fx_burst(pos, Vector2.UP, Color(0.6, 0.5, 0.85), 14, 140.0)
	main.fx_ring(pos, Color(0.6, 0.5, 0.85), 50.0, 0.4, 3.0)
	return e


## Open floor in the room, away from the climber and the puzzle's pieces.
func _spot() -> Vector2:
	var p = main.player
	var c := Floors.CELL
	var cols := int(room.size.x / c)
	var rws := int(room.size.y / c)
	for tries in 60:
		var t := Vector2i(randi_range(1, cols - 2), randi_range(1, rws - 2))
		var pos := room.position + (Vector2(t) + Vector2(0.5, 0.5)) * c
		if main.is_solid(pos) or not cur.spot_ok(pos):
			continue
		if p != null and pos.distance_to(p.global_position) < (160.0 if tries < 40 else 90.0):
			continue
		return pos
	return Vector2.INF


func _alive(list: Array) -> Array:
	return list.filter(func(e): return is_instance_valid(e) and not e.dead and not e.is_queued_for_deletion())


# --- running -------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if kind == "" or main == null or main.player == null or cur == null:
		return
	if solved:
		# Solved: only the ward's fading glow still moves, then nothing.
		if ward_glow > 0.0:
			ward_glow = maxf(0.0, ward_glow - delta * 0.8)
			_glow_tick(delta)
			if ward_glow <= 0.0 and glow != null:
				glow.queue_redraw()  # (gone: one last redraw)
		_labels_tick()
		_redraw_if_changed()
		return
	var inside: bool = room.has_point(main.player.global_position)
	cur.watch(delta)
	if locked:
		lock_t += delta
		ambushers = _alive(ambushers)
		if ambushers.is_empty() or lock_t >= LOCK_MAX:
			locked = false
			cur.reset()
			main.fx_text(room.get_center() + Vector2(0, -10), TEXT["again"], Color(0.85, 0.82, 0.9))
			main.sfx("glint", 0.7, -6.0, 0.0)
	else:
		_update_mode(delta, inside)
		_update_seal()
		if awake:
			cur.tick(delta)
	_redraw_if_changed()
	_glow_tick(delta)
	_labels_tick()


## Quiet: asleep while any monster stands in the room. Pressure: while
## you're in the room, more keep coming.
func _update_mode(delta: float, inside: bool) -> void:
	if mode == "quiet" and not awake:
		guard_t -= delta
		if guard_t <= 0.0:
			guard_t = GUARD_CHECK
			var guarded := false
			for e in main.enemies():
				if room.grow(-4.0).has_point(e.global_position):
					guarded = true
					break
			if not guarded:
				awake = true
				if inside:
					main.fx_text(room.get_center() + Vector2(0, -30), TEXT["wakes"], Color(1.0, 0.89, 0.63))
					main.sfx("glint", 0.6, -4.0, 0.0)
	elif mode == "pressure" and inside:
		press_t -= delta
		if press_t <= 0.0:
			press_t = PRESSURE_EVERY
			pressers = _alive(pressers)
			if pressers.size() < PRESSURE_ALIVE and press_spawned < PRESSURE_CAP:
				var e = _spawn_here(2.5)
				if e != null:
					pressers.append(e)
					press_spawned += 1


## Puzzles that close the room do so once you're well inside (never on a
## doorway, never with a monster in one), and open again when it's solved
## or failed.
func _update_seal() -> void:
	if sealed or int(cur.SEAL_FROM) > tier or spec.get("entrances", []).is_empty() or main.player.dead:
		return
	var inner := room.grow(-Floors.CELL * 0.6)
	if not inner.has_point(main.player.global_position):
		return
	for r in spec["entrances"]:
		for e in main.enemies():
			if r.grow(16.0).has_point(e.global_position):
				return
	sealed = true
	for r in spec["entrances"]:
		var body := _static_body(r.get_center())
		var box := RectangleShape2D.new()
		box.size = r.size
		body.get_child(0).shape = box
		seal_bodies.append(body)
		set_solid(r, true)
		main.fx_burst(r.get_center(), Vector2.ZERO, Color(0.55, 0.51, 0.6), 10, 120.0)
	main.shake(6.0)
	main.sfx("slam", 0.6, -2.0, 0.0)
	main.banner = {"title": display_name().to_upper(), "lines": [TEXT["sealed"]], "t": 3.5}
	queue_redraw()


func _unseal() -> void:
	if not sealed:
		return
	sealed = false
	for b in seal_bodies:
		if is_instance_valid(b):
			b.queue_free()
	seal_bodies.clear()
	for r in spec.get("entrances", []):
		set_solid(r, false)
		main.fx_burst(r.get_center(), Vector2.ZERO, Color(1.0, 0.89, 0.63), 10, 140.0)
	queue_redraw()


## The stone parts are drawn again only when something about them changes;
## what pulses is redrawn 30 times a second while the puzzle is unsolved.
func _redraw_if_changed() -> void:
	var st := [solved, awake, locked, sealed]
	for g in gates:
		st.append(g["open"])
	st.append_array(cur.state())
	if st != _drawn_state:
		_drawn_state = st
		queue_redraw()


func _glow_tick(delta: float) -> void:
	redraw_t -= delta
	if redraw_t <= 0.0:
		redraw_t = 1.0 / 30.0
		if glow != null:
			glow.queue_redraw()
			if _near():
				over.queue_redraw()
			if _labels_on:
				labels.queue_redraw()


## The climber is in (or at the edge of) the puzzle's room.
func _near() -> bool:
	return main.player != null and room.grow(Floors.CELL).has_point(main.player.global_position)


## Rule panels show while the climber is in the room (redrawn at 30 Hz so
## they stay on screen as the camera moves), then one redraw to clear them.
func _labels_tick() -> void:
	var on := _near() and not solved
	if on != _labels_on:
		labels.queue_redraw()
		over.queue_redraw()
	_labels_on = on


# --- what strikes and arrows hit ------------------------------------------------

## A strike from `from` toward `dir`. Returns how many puzzle pieces it hit.
func strike(from: Vector2, dir: Vector2, reach: float, arc_deg: float) -> int:
	if cur == null or locked:
		return 0
	return cur.strike(from, dir, reach, arc_deg)


## An arrow (or bolt) at `pos`: true if it struck a piece of the puzzle (it stops there).
func shot(pos: Vector2) -> bool:
	if cur == null:
		return false
	return cur.shot(pos)


## Where auto-aim should point when no monster is near: the nearest piece
## of the puzzle to hit (an unlit eye, a mirror) in sight and in reach, or
## Vector2.INF for none.
func aim_point(from: Vector2, reach: float) -> Vector2:
	if not active() or locked or not awake:
		return Vector2.INF
	var best := Vector2.INF
	var best_d := reach
	for at in cur.aim_points():
		var d: float = from.distance_to(at)
		if d < best_d and main.clear_line(from, at):
			best_d = d
			best = at
	return best


## The climber's movement, if the puzzle takes it over this frame (the Ice
## Hall's slide): player.gd asks every frame; true means velocity is set.
func steer(p, delta: float) -> bool:
	if cur == null:
		return false
	return cur.steer(p, delta)


## Whether the climber can't roll (or, with `leap`, jump) here (the Ice
## Hall); says why when so.
func no_footing(pos: Vector2, leap: bool) -> bool:
	if cur == null or not cur.no_footing(pos, leap):
		return false
	cur.footing_note(pos)
	return true


## An essence offered near the puzzle: a bond's spell ("bond") or an item
## ("item") of essence `essence_kind` (the Essence Lock answers to it).
func offer(essence_kind: String, pos: Vector2, how: String) -> bool:
	if cur == null or solved or locked or not awake:
		return false
	return cur.offer(essence_kind, pos, how)


## The puzzle's lights for this frame (lighting.gd): [[pos, reach, colour, strength, glow]].
func light_list() -> Array:
	if cur == null:
		return []
	return cur.lights()


# --- drawing -------------------------------------------------------------------

func _draw() -> void:
	if kind == "" or cur == null:
		return
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
	cur.draw(self)
	# The seal: a slab of dressed stone across each doorway.
	if sealed:
		for r in spec.get("entrances", []):
			var sr: Rect2 = r
			draw_rect(sr, Color(0.07, 0.06, 0.08))
			draw_rect(sr.grow(-2.0), Color(0.36, 0.33, 0.4))
			draw_rect(sr.grow(-7.0), Color(0.3, 0.27, 0.34))
			draw_circle(sr.get_center(), 5.0, Color(0.95, 0.8, 0.5, 0.8))


## What pulses: the puzzle's glow and the ward on the stair.
func _draw_glow() -> void:
	if kind == "" and ward_glow <= 0.0:
		return
	var t := Time.get_ticks_msec() * 0.001
	if cur != null:
		cur.draw_glow(glow, t)
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


func _draw_over() -> void:
	if cur == null or not _near():
		return
	cur.draw_over(over, Time.get_ticks_msec() * 0.001)


## The rule text: the puzzle's own panels, and the host's word on its state.
func _draw_labels() -> void:
	if cur == null or solved or not _near():
		return
	if not main.banner.is_empty():
		return  # (a banner's big title would sit on top of it: wait till it fades)
	var list: Array = []
	if locked:
		list.append({"pos": room.get_center(), "lines": [TEXT["locked"]], "tone": "bad"})
	else:
		list = cur.panels()
		var foot: Array = []
		if not awake:
			foot.append(String(cur.TEXT.get("quiet", TEXT["quiet"])))
		elif mode == "pressure":
			foot.append(TEXT["pressure"])
		for id in cur.BREAKS:
			if main.player.has_bond(id):
				foot.append(TEXT["shortcut"] % cur.BREAKS[id])
		if not list.is_empty():
			var first: Dictionary = list[0].duplicate()
			first["lines"] = first["lines"] + foot
			first["foot"] = TEXT["watch"]
			list[0] = first
		elif not foot.is_empty():
			list.append({"pos": room.get_center(), "lines": foot})
	for p in list:
		_panel(p)


## A framed panel of words in the world (the web version's puzSay): `pos` is
## its bottom middle (top middle with "below"), kept on screen.
func _panel(p: Dictionary) -> void:
	var font := ThemeDB.fallback_font
	var size := 11
	var max_w: float = p.get("width", 250.0)
	var rows: Array = []  # [text, colour, size]
	if p.get("title", "") != "":
		rows.append([p["title"], UI.GOLD, 10])
	var body_col: Color = UI.BAD if p.get("tone", "") == "bad" else Color(0.93, 0.89, 0.81)
	for line in p.get("lines", []):
		for w in _wrap(font, String(line), size, max_w):
			rows.append([w, body_col, size])
	if p.get("foot", "") != "":
		rows.append([p["foot"], UI.DIM, 10])
	var wide := 0.0
	for r in rows:
		wide = maxf(wide, font.get_string_size(r[0], HORIZONTAL_ALIGNMENT_LEFT, -1, r[2]).x)
	var pad := Vector2(8, 5)
	var line_h := 14.0
	var box_size := Vector2(wide + pad.x * 2.0, rows.size() * line_h + pad.y * 2.0)
	var at: Vector2 = p["pos"]
	var top_left := Vector2(at.x - box_size.x * 0.5, at.y if p.get("below", false) else at.y - box_size.y)
	# Kept on screen.
	var cam = main.camera
	if cam != null:
		var view: Vector2 = get_viewport_rect().size / cam.zoom
		var c: Vector2 = cam.get_screen_center_position()
		var lo: Vector2 = c - view * 0.5 + Vector2(8, 70)
		var hi: Vector2 = c + view * 0.5 - Vector2(8, 90) - box_size
		top_left = top_left.clamp(lo, hi.max(lo))
	var box := Rect2(top_left, box_size)
	labels.draw_rect(box, Color(0.055, 0.043, 0.075, 0.88))
	labels.draw_rect(box, Color(UI.GOLD, 0.5), false, 1.0)
	for i in rows.size():
		var r: Array = rows[i]
		var y := box.position.y + pad.y + line_h * (i + 1) - 3.0
		labels.draw_string(font, Vector2(box.position.x, y), r[0], HORIZONTAL_ALIGNMENT_CENTER, box.size.x, r[2], r[1])


static func _wrap(font: Font, text: String, size: int, max_w: float) -> Array:
	var out: Array = []
	var line := ""
	for word in text.split(" "):
		var test := word if line == "" else line + " " + word
		if line != "" and font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_w:
			out.append(line)
			line = word
		else:
			line = test
	if line != "":
		out.append(line)
	return out
