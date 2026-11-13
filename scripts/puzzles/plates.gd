extends "res://scripts/puzzles/base.gd"
## WEIGHING ROOM: pressure plates that need a WEIGHT (a hand-made room,
## rooms.gd): a stone block pushed onto it, or a monster standing on it (the
## climber is too light). Every plate held down at once solves it. Strike
## the lever to put the blocks back if one gets stuck.
## Monsters are part of the answer here, so it takes no quiet or pressure mode.

const NAME := "Weighing Room"
static var TEXT := {
	"rule": ["The plates want a weight heavier than you: push a block on, or lure a monster.", "Strike the lever to put the blocks back."],
	"reset": "The blocks return",
	"heavy": "Rooted: the plate feels your weight",
	"sent": "Something heavy comes",
}
## More plates than blocks: a monster must hold one. If none that can stands
## in the room for this long while you're there, the beast sends one, so the
## room can never be left without an answer.
const SEND_AFTER := 8.0
## Monsters that keep their distance (or sink): they never stand on a plate.
const KEEP_AWAY := ["archer", "bloomcap", "thunderling", "lurker", "briar"]
var send_t := 0.0
const BREAKS := {"sandshaper": "Rooted Stance: you're heavy enough to hold a plate down yourself."}
const SEAL_FROM := 99
const MODES := []
## How long you lean on a block before it slides.
const PUSH_TIME := 0.3

var plates: Array = []  # {pos, down}
var blocks: Array = []  # {pos, home, body, push_t}
var levers: Array = []  # {pos, t}


static func make(_rect: Rect2, _floor_num: int, _tier: int, ctx: Dictionary) -> Dictionary:
	var f: Dictionary = ctx.get("features", {})
	if f.get("plates", []).is_empty():
		return {}
	return {"plates": f["plates"], "pushers": f.get("pushers", []), "levers": f.get("levers", []),
		"rails": f.get("rails", []), "gates": f.get("gates", []), "rewards": f.get("rewards", [])}


func _build() -> void:
	for p in spec.get("plates", []):
		plates.append({"pos": p, "down": false})
	for p in spec.get("pushers", []):
		var r := Rect2(p - Vector2(19, 19), Vector2(38, 38))
		blocks.append({"pos": p, "home": p, "body": host.add_body(r), "push_t": 0.0})
	for p in spec.get("levers", []):
		levers.append({"pos": p, "t": 0.0})


func tick(delta: float) -> void:
	for l in levers:
		l["t"] = maxf(0.0, l["t"] - delta)
	if plates.size() > blocks.size() and not host.solved and room.has_point(main.player.global_position):
		var walker := false
		for e in main.enemies():
			if not e.is_queued_for_deletion() and not (e.kind in main.EnemyScript.FLIERS) and not (e.kind in KEEP_AWAY) and room.grow(80.0).has_point(e.global_position):
				walker = true
				break
		send_t = 0.0 if walker else send_t + delta
		if send_t >= SEND_AFTER:
			send_t = 0.0
			var at: Vector2 = host._spot()
			if at != Vector2.INF:
				var e = main.spawn_enemy("slime", at)  # (a walker: it can hold a plate down)
				e.wake()
				main.floor_total += 1
				main.foes_changed()
				main.fx_burst(at, Vector2.UP, Color(0.6, 0.5, 0.85), 12, 120.0)
				main.fx_text(at + Vector2(0, -36), TEXT["sent"], Color(0.85, 0.8, 0.7))
	for pl in plates:
		pl["down"] = _weighed(pl["pos"])
	_push(delta)
	if plates.is_empty():
		return
	for pl in plates:
		if not pl["down"]:
			return
	host.solve()


func state() -> Array:
	var st := []
	for pl in plates:
		st.append(pl["down"])
	for b in blocks:
		st.append(b["body"].position if is_instance_valid(b["body"]) else b["pos"])
		st.append(snappedf(b["push_t"], 0.05))
	for l in levers:
		st.append(l["t"] > 0.0)
	return st


## A plate is held down by a block, or by a monster standing on it (or by a
## Sandshaper, Rooted Stance).
func _weighed(pos: Vector2) -> bool:
	for b in blocks:
		if b["pos"].distance_to(pos) < 8.0:
			return true
	for e in main.enemies():
		if e.is_queued_for_deletion() or e.kind in main.EnemyScript.FLIERS:
			continue
		if e.global_position.distance_to(pos) < 22.0:
			return true
	if has_bond("sandshaper") and near_player(pos, 20.0):
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
	var to: Vector2 = b["pos"] + dir * CELL
	if not _free(to, b):
		main.sfx("hit_armor", 0.6, -12.0)
		return false
	host.set_solid(Rect2(b["pos"] - Vector2(19, 19), Vector2(38, 38)), false)
	b["pos"] = to
	host.set_solid(Rect2(to - Vector2(19, 19), Vector2(38, 38)), true)
	var body: StaticBody2D = b["body"]
	if b.get("tween") != null and b["tween"].is_valid():
		b["tween"].kill()
	var tw := body.create_tween()
	tw.tween_property(body, "position", to, 0.14)
	b["tween"] = tw
	main.sfx("stone_slide", 1.0, 0.0)
	main.shake(1.5)
	return true


func _free(pos: Vector2, me: Dictionary) -> bool:
	if main.is_solid(pos) or main.in_chasm(pos):
		return false
	for r in host.rails:
		if r.has_point(pos):
			return false
	for g in host.gates:
		if not g["open"] and g["rect"].has_point(pos):
			return false
	for b in blocks:
		if b != me and b["pos"].distance_to(pos) < 20.0:
			return false
	for pl in main.pillars:
		if pos.distance_to(pl["pos"]) < pl["r"] + 18.0:
			return false
	return true


func strike(from: Vector2, dir: Vector2, reach: float, arc_deg: float) -> int:
	var hits := 0
	for l in levers:
		if in_swing(from, dir, l["pos"], reach, arc_deg):
			_pull(l)
			hits += 1
	return hits


func shot(pos: Vector2) -> bool:
	for l in levers:
		if pos.distance_to(l["pos"]) < 14.0:
			_pull(l)
			return true
	return false


## The lever puts every block back where it started.
func _pull(l: Dictionary) -> void:
	if l["t"] > 0.0:
		return
	l["t"] = 0.6
	main.sfx("lever", 1.0, 0.0)
	if host.solved:
		return
	reset()
	main.fx_text(l["pos"] + Vector2(0, -30), TEXT["reset"], Color(0.85, 0.82, 0.9))


func reset() -> void:
	for b in blocks:
		if b["pos"] == b["home"]:
			continue
		host.set_solid(Rect2(b["pos"] - Vector2(19, 19), Vector2(38, 38)), false)
		if b.get("tween") != null and b["tween"].is_valid():
			b["tween"].kill()  # (a slide still under way)
		b["pos"] = b["home"]
		b["body"].position = b["home"]
		host.set_solid(Rect2(b["home"] - Vector2(19, 19), Vector2(38, 38)), true)


func panels() -> Array:
	if not player_in_room(20.0):
		return []
	return [{"pos": Vector2(room.get_center().x, room.end.y + 6.0), "below": true, "title": host.display_name().to_upper(), "lines": TEXT["rule"]}]


func spot_ok(pos: Vector2) -> bool:
	for b in blocks:
		if b["pos"].distance_to(pos) < 40.0:
			return false
	return true


func draw(ci: CanvasItem) -> void:
	var stone := Color(0.42, 0.4, 0.44)
	var dark := Color(0.16, 0.15, 0.18)
	# Plates: a square that sinks and glows when weighed down.
	for pl in plates:
		var c: Vector2 = pl["pos"]
		var down: bool = pl["down"] or host.solved
		var plate := Rect2(c - Vector2(16, 16), Vector2(32, 32))
		ci.draw_rect(plate.grow(2.0), dark)
		ci.draw_rect(plate, stone.darkened(0.25 if down else 0.0))
		ci.draw_rect(plate.grow(-6.0), Color(1.0, 0.82, 0.45, 0.85) if down else Color(0.3, 0.28, 0.34))
	# Blocks: carved stone cubes, lit from the top-left.
	for b in blocks:
		var c: Vector2 = b["body"].position
		var box := Rect2(c - Vector2(18, 18), Vector2(36, 36))
		ci.draw_rect(box.grow(2.0), Color(0, 0, 0, 0.35))
		ci.draw_rect(box, Color(0.5, 0.47, 0.44))
		ci.draw_rect(Rect2(box.position, Vector2(box.size.x, 7)), Color(0.62, 0.59, 0.55))
		ci.draw_rect(Rect2(box.position + Vector2(0, box.size.y - 6), Vector2(box.size.x, 6)), Color(0.34, 0.31, 0.3))
		ci.draw_rect(box.grow(-9.0), Color(0.44, 0.41, 0.39))
		if b["push_t"] > 0.0:
			ci.draw_rect(box.grow(3.0), Color(1, 1, 1, 0.25 + b["push_t"] / PUSH_TIME * 0.4), false, 2.0)
	# Levers: a post with a handle.
	for l in levers:
		var c: Vector2 = l["pos"]
		ci.draw_circle(c, 10.0, dark)
		ci.draw_circle(c, 8.0, stone)
		var ang := -0.9 if l["t"] <= 0.0 else 0.9
		Draw.line(ci, c, c + Vector2.from_angle(ang - PI / 2.0) * 16.0, Color(0.6, 0.5, 0.35), 4.0)
		ci.draw_circle(c + Vector2.from_angle(ang - PI / 2.0) * 16.0, 4.0, Color(0.75, 0.3, 0.25))
