extends RefCounted
## The Chimera's own task, THE HUNGRY GROVE (objectives.gd "heartroots"):
## thorns choke the stair, fed by heart-roots in rooms across the floor
## (3, then 4). One is awake at a time, its heart pulsing red; cut it
## (three blows) and the next wakes. Strike a sleeping one and its thorns
## lash you. When the last is cut the thorns recede from the stair, and
## every thorn wall on the floor withers with them (chimera_floor.gd).
## Placed by `place` (chimera_floor.gd place_task), run by the Chimera's
## floor script (task_tick, task_strike) with the floor's objective node as
## its host. Words and numbers: objectives.gd KINDS["heartroots"] and TEXT.

const Objectives := preload("res://scripts/objectives.gd")
const Palette := preload("res://scripts/palette.gd")

const HEART := Color(0.95, 0.3, 0.3)
const ROOT := Color(0.34, 0.24, 0.15)

var host  # objective.gd
var main
var spec := {}
var step := 0
var lash_t := 0.0
var lashes := 0  # (tests)


## The roots: spread over far rooms, one to a room where it can be; the
## order they wake in is drawn at random. {} if they won't fit.
static func place(spec: Dictionary, infos: Array, cands: Array, dist: Array, monsters: Array, _floor_num: int, n: int, _cell: float) -> Dictionary:
	var spread := Objectives._spread(cands, n, infos, dist)
	if spread.size() < mini(n, 2):
		return {}
	for j in n:
		var ri: int = spread[j % spread.size()]
		var p := Objectives._spot(infos[ri], monsters, 1, false, spec["pieces"].map(func(x): return x["pos"]), 90.0)
		if p == Vector2.INF:
			return {}
		spec["pieces"].append({"pos": p, "room": ri})
	var order: Array = range(n)
	order.shuffle()
	spec["order"] = order
	return spec


func setup(s: Dictionary) -> void:
	spec = s
	for pc in host.pieces:
		pc["hp"] = int(_k()["hp"])


func clear() -> void:
	pass


func _k() -> Dictionary:
	return Objectives.KINDS["heartroots"]


## The root awake now ({} when all are cut).
func awake() -> Dictionary:
	if step >= host.pieces.size():
		return {}
	return host.pieces[int(spec["order"][step])]


func tick(delta: float, _p, _hurt: bool) -> bool:
	lash_t -= delta
	return step >= host.pieces.size() and not host.pieces.is_empty()


func strike(from: Vector2, dir: Vector2, reach: float, arc: float) -> void:
	var now := awake()
	var hit: Array = []
	for pc in host.pieces:
		var to: Vector2 = pc["pos"] - from
		if pc["state"] != "done" and to.length() <= reach + 24.0 and absf(dir.angle_to(to)) <= deg_to_rad(arc + 25.0):
			hit.append(pc)
	if hit.is_empty():
		return
	if now in hit:
		var to: Vector2 = now["pos"] - from
		now["hp"] = int(now["hp"]) - 1
		main.fx_burst(now["pos"], -to.normalized(), HEART, 8, 120.0)
		main.sfx("hit_slime", 0.7, -4.0)
		if int(now["hp"]) <= 0:
			step += 1
			host._piece_done(now)
			main.shake(3.0)
			if step < host.pieces.size():
				main.fx_text(Vector2(now["pos"]) + Vector2(0, -40), Objectives.TEXT["wakes"], HEART)
	elif lash_t <= 0.0:
		var pc: Dictionary = hit[0]
		lash_t = float(_k()["lash_cd"])
		lashes += 1
		main.fx_text(Vector2(pc["pos"]) + Vector2(0, -40), Objectives.TEXT["asleep"], Color(0.75, 0.85, 0.6))
		if main.player != null and main.player.global_position.distance_to(pc["pos"]) < reach + 40.0:
			main.player.receive_attack(float(_k()["lash"]), null, true)
		main.fx_burst(pc["pos"], (pc["pos"] - from).normalized(), Color(0.45, 0.6, 0.3), 8, 140.0)


## The thorns recede: the grove's heart is cut out of the floor.
func on_complete() -> void:
	main.fx_text(main.stair_pos + Vector2(0, -40), Objectives.TEXT["recede"], Color(0.75, 0.95, 0.6))
	main.fx_burst(main.stair_pos, Vector2.UP, Color(0.45, 0.65, 0.3), 24, 200.0)
	var tf = main.get("tower_floor")
	if tf != null and tf.has_method("wither_all"):
		tf.wither_all()
		main.fx_text(main.player.global_position + Vector2(0, -60), tf.TEXT["withered"], Color(0.75, 0.95, 0.6))


func arrow_target(_from: Vector2) -> Array:
	var now := awake()
	return [now["pos"], String(_k()["piece"])] if not now.is_empty() else []


func live_targets() -> Array:
	var out: Array = []
	for pc in host.pieces:
		if pc["state"] != "done":
			out.append(pc["pos"])
	return out


## The floor bot: strike the root that's awake.
func bot_step(_bot, _pos: Vector2) -> Dictionary:
	var now := awake()
	if now.is_empty():
		return {}
	return {"pos": now["pos"], "act": "strike", "why": "the waking heart-root"}


# --- drawing ----------------------------------------------------------------------------

func draw(c: CanvasItem, t: float) -> void:
	var now := awake()
	for pc in host.pieces:
		_root(c, pc, pc == now, t)
	if not host.done:
		_stair_thorns(c, main.stair_pos, t)


func _root(c: CanvasItem, pc: Dictionary, is_awake: bool, t: float) -> void:
	var at: Vector2 = pc["pos"]
	var cut: bool = pc["state"] == "done"
	c.draw_circle(at + Vector2(3, 10), 16.0, Color(0, 0, 0, 0.3))
	# Roots splayed into the floor.
	for i in 6:
		var a := i * TAU / 6.0 + 0.3
		var e := at + Vector2.from_angle(a) * 22.0 + Vector2(0, 4)
		c.draw_line(at, e, Palette.OUTLINE, 6.0)
		c.draw_line(at, e, ROOT if not cut else ROOT.darkened(0.3), 4.0)
	if cut:
		c.draw_circle(at, 9.0, ROOT.darkened(0.2))
		c.draw_circle(at, 5.0, Color(0.55, 0.45, 0.3))
		return
	c.draw_circle(at, 13.0, Palette.OUTLINE)
	c.draw_circle(at, 11.5, ROOT.lightened(0.05))
	var beat := 0.5 + 0.5 * sin(t * (6.0 if is_awake else 1.5))
	if is_awake:
		c.draw_circle(at, 18.0 + beat * 6.0, Color(HEART, 0.12))
		c.draw_circle(at + Vector2(0, -1), 6.0 + beat * 2.0, HEART)
		c.draw_circle(at + Vector2(-2, -3), 2.5, Color(1.0, 0.75, 0.7))
		var k: float = float(pc.get("hp", 3)) / float(_k()["hp"])
		c.draw_arc(at, 20.0, -PI * 0.5, -PI * 0.5 + TAU * k, 24, Color(HEART, 0.7), 2.0)
	else:
		c.draw_circle(at + Vector2(0, -1), 4.0, Color(0.4, 0.15, 0.15))
		# Shut in thorns while it sleeps.
		for i in 6:
			var a := i * TAU / 6.0
			c.draw_line(at + Vector2.from_angle(a) * 6.0, at + Vector2.from_angle(a) * 14.0, Color(0.62, 0.58, 0.42), 2.0)


## A tangle of thorns across the stair until the grove is cut.
func _stair_thorns(c: CanvasItem, at: Vector2, t: float) -> void:
	for i in 9:
		var a := Vector2(-34 + i * 8.0, -16 + 22.0 * fmod(i * 0.37, 1.0))
		var b := a + Vector2(18.0 * (1.0 if i % 2 == 0 else -1.0), 22.0)
		var m := (a + b) * 0.5 + Vector2(sin(t + i) * 3.0, 0)
		c.draw_polyline(PackedVector2Array([at + a, at + m, at + b]), Palette.OUTLINE, 4.5)
		c.draw_polyline(PackedVector2Array([at + a, at + m, at + b]), Color(0.24, 0.36, 0.18), 2.8)
		c.draw_colored_polygon(PackedVector2Array([at + m - Vector2(2, 0), at + m + Vector2(0, -6), at + m + Vector2(2, 0)]), Color(0.62, 0.58, 0.42))
