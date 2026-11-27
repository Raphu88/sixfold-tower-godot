extends "res://scripts/puzzles/base.gd"
## THE HALL OF PODS: a three-headed idol stands in the middle of the gallery
## (a lion, a goat and a serpent), and seed pods ring it. One of the idol's
## heads glows: that's the sign it wants. The pods open a few at a time,
## each showing a sign, and close again. Strike (or shoot) an open pod that
## shows the glowing head's sign; leave the others alone.
##   the wanted sign   the pod bursts with light: one more
##   any other sign    FAILURE: the beast sends hunters; once they're
##                     beaten, the count starts again
##   a pod that closes before you reach it costs nothing
##   tier 1: 4 to burst, 2 pods open at once, open 3.2 s
##   tier 2: 5 to burst, 3 open, 2.8 s, and the idol turns another head
##           after each burst
##   tier 3: 6 to burst, 3 open, 2.4 s, the idol turns, and the room closes
## There's always a pod with the wanted sign among the open ones.

const NAME := "The Hall of Pods"
static var NAMES := {"chimera": "The Three Heads"}
static var TEXT := {
	"rule": ["Burst the open pods that show the sign the idol's glowing head shows.", "Leave the others closed."],
	"rule_turn": ["Burst the open pods that show the sign the idol's glowing head shows.", "The idol turns another head after each one."],
	"quiet": "The pods stay shut while blood is spilled.",
	"wrong": "The wrong head. The idol snarls.",
	"count": "Pods burst: %d of %d",
	"heads": {"lion": "the Lion", "goat": "the Goat", "serpent": "the Serpent"},
}
const BREAKS := {}
const SEAL_FROM := 3
const MODES := ["quiet", "pressure"]
const HEADS := ["lion", "goat", "serpent"]
## By tier: [to burst, open at once, seconds open, turns after each burst].
const RULES := {1: [4, 2, 3.2, false], 2: [5, 3, 2.8, true], 3: [6, 3, 2.4, true]}
## The pods: how many round the idol, and the ring's radius in tiles.
const PODS := 6
const RING := 3
const POD_R := 13.0
## A pause between one pod closing and the next opening.
const REST := 0.5
const ROOM_SIZE := [11, 13, 10, 11]
const ROOM_SHAPES := ["round", "rect"]
const HEAD_COLORS := {"lion": Color(1.0, 0.75, 0.3), "goat": Color(0.8, 0.85, 0.95), "serpent": Color(0.45, 0.9, 0.5)}

var pods: Array = []  # {pos, head, open (seconds left), rest (seconds before it may open), pop}
var idol := Vector2.ZERO
var want := "lion"
var burst := 0
var need := 4


static func make(rect: Rect2, _floor_num: int, _tier: int, ctx: Dictionary) -> Dictionary:
	var size := Vector2i(RING * 2 + 1, RING * 2 + 1)
	var o := fit_block(ctx, size, 1)
	if o.x < 0:
		return {}
	var mid := o + Vector2i(RING, RING)
	var spots: Array = []
	var a0 := randf() * TAU
	for k in PODS:
		var a := a0 + TAU * k / PODS
		var t := mid + Vector2i(roundi(cos(a) * RING), roundi(sin(a) * RING))
		if spots.any(func(s): return s["t"] == t):
			return {}
		spots.append({"t": t, "pos": tile_center(rect, t)})
	return {"pods": spots.map(func(s): return s["pos"]), "idol": tile_center(rect, mid), "want": HEADS[randi() % HEADS.size()],
		"reserve": block_tiles(o, size, 1), "rewards": [tile_center(rect, mid + Vector2i(0, 1))]}


func _rules() -> Array:
	return RULES.get(tier, RULES[1])


func _build() -> void:
	for p in spec.get("pods", []):
		pods.append({"pos": p, "head": "", "open": 0.0, "rest": randf_range(0.2, 1.0), "pop": 0.0})
		host.add_round_body(p, POD_R)
	idol = spec.get("idol", room.get_center())
	host.add_round_body(idol, 14.0)
	want = String(spec.get("want", "lion"))
	need = int(_rules()[0])


func open_list() -> Array:
	return pods.filter(func(q): return q["open"] > 0.0)


func tick(delta: float) -> void:
	var rl := _rules()
	for q in pods:
		q["pop"] = maxf(0.0, q["pop"] - delta)
		if q["open"] > 0.0:
			q["open"] = maxf(0.0, q["open"] - delta)
			if q["open"] <= 0.0:
				q["rest"] = REST + randf() * 0.6
		else:
			q["rest"] = maxf(0.0, q["rest"] - delta)
	# Keep `open at once` pods open, the wanted sign always among them.
	var open := open_list()
	if open.size() >= int(rl[1]):
		return
	var shut: Array = pods.filter(func(q): return q["open"] <= 0.0 and q["rest"] <= 0.0)
	if shut.is_empty():
		return
	var q: Dictionary = shut[randi() % shut.size()]
	var has_want := open.any(func(o): return o["head"] == want)
	var head: String = want if not has_want else String(HEADS[randi() % HEADS.size()])
	if has_want and open.size() + 1 >= int(rl[1]) and head == want and randf() < 0.6:
		head = HEADS[(HEADS.find(want) + 1 + randi() % 2) % HEADS.size()]  # (mostly others beside it)
	q["head"] = head
	q["open"] = float(rl[2])
	main.sfx("bubble", 1.2 + randf() * 0.3, -10.0, 0.0)


func _hit(q: Dictionary) -> void:
	if host.solved or not host.awake or host.locked or q["open"] <= 0.0:
		return
	if q["head"] == want:
		burst += 1
		q["open"] = 0.0
		q["rest"] = REST
		q["pop"] = 0.4
		main.sfx("chime", 1.0 + 0.08 * burst, -2.0, 0.0)
		main.fx_burst(q["pos"], Vector2.UP, HEAD_COLORS.get(want, Color.WHITE), 12, 140.0)
		main.fx_text(q["pos"] + Vector2(0, -30), TEXT["count"] % [burst, need], HEAD_COLORS.get(want, Color.WHITE))
		if burst >= need:
			host.solve()
			return
		if bool(_rules()[3]):
			var others: Array = HEADS.filter(func(h): return h != want)
			want = others[randi() % others.size()]
			main.sfx("statue_voice", 1.2, -8.0)
		return
	for o in pods:
		o["open"] = 0.0
		o["rest"] = 1.0
	burst = 0
	host.fail(TEXT["wrong"])


func strike(from: Vector2, dir: Vector2, reach: float, arc_deg: float) -> int:
	var q = nearest_in_swing(pods, from, dir, reach, arc_deg, func(x): return x["open"] > 0.0)
	if q == null:
		return 0
	_hit(q)
	return 1


func shot(pos: Vector2) -> bool:
	for q in pods:
		if pos.distance_to(q["pos"]) < POD_R + 3.0:
			_hit(q)
			return true
	return false


func reset() -> void:
	burst = 0
	for q in pods:
		q["open"] = 0.0
		q["rest"] = randf_range(0.4, 1.0)


func state() -> Array:
	return [burst, want]


## The floor bot: the open pod with the wanted sign that's nearest `from`
## (with time enough left to get there), or {}.
func target_for(from: Vector2) -> Dictionary:
	var best := {}
	var best_d := INF
	for q in pods:
		if q["open"] > 0.25 and q["head"] == want:
			var d: float = from.distance_to(q["pos"])
			if d < best_d:
				best_d = d
				best = q
	return best


func aim_points() -> Array:
	var out: Array = []
	for q in pods:
		if q["open"] > 0.0 and q["head"] == want:
			out.append(q["pos"])
	return out


func spot_ok(pos: Vector2) -> bool:
	if pos.distance_to(idol) < 50.0:
		return false
	for q in pods:
		if q["pos"].distance_to(pos) < 46.0:
			return false
	return true


func panels() -> Array:
	if not player_in_room(10.0):
		return []
	var lines: Array = (TEXT["rule_turn"] if bool(_rules()[3]) else TEXT["rule"]).duplicate()
	lines.append(TEXT["count"] % [burst, need])
	return [{"pos": Vector2(room.get_center().x, room.position.y - 6.0), "title": host.display_name().to_upper(), "lines": lines}]


func lights() -> Array:
	var out: Array = [[idol + Vector2(0, -20), 90.0, HEAD_COLORS.get(want, Color.WHITE), 0.5, 0.15]]
	for q in pods:
		if q["open"] > 0.0:
			out.append([q["pos"], 70.0, HEAD_COLORS.get(q["head"], Color.WHITE), 0.45, 0.1])
	return out


## A head's sign, centred on `c`, `s` across: a maned face, horns, a coiled snake.
static func draw_head(ci: CanvasItem, head: String, c: Vector2, s: float, col: Color, wd := 2.0) -> void:
	match head:
		"lion":
			for k in 10:
				var v := Vector2.from_angle(TAU * k / 10.0)
				ci.draw_line(c + v * s * 0.55, c + v * s, col, wd)
			ci.draw_arc(c, s * 0.5, 0.0, TAU, 16, col, wd)
			ci.draw_circle(c + Vector2(-s * 0.18, -s * 0.08), s * 0.08, col)
			ci.draw_circle(c + Vector2(s * 0.18, -s * 0.08), s * 0.08, col)
		"goat":
			ci.draw_arc(c + Vector2(-s * 0.45, -s * 0.2), s * 0.5, PI * 1.0, PI * 1.9, 10, col, wd)
			ci.draw_arc(c + Vector2(s * 0.45, -s * 0.2), s * 0.5, PI * 1.1, PI * 2.0, 10, col, wd)
			var face := PackedVector2Array([c + Vector2(-s * 0.35, -s * 0.2), c + Vector2(s * 0.35, -s * 0.2), c + Vector2(s * 0.15, s * 0.8), c + Vector2(-s * 0.15, s * 0.8), c + Vector2(-s * 0.35, -s * 0.2)])
			ci.draw_polyline(face, col, wd)
		_:
			var pts := PackedVector2Array()
			for i in 13:
				var f := float(i) / 12.0
				pts.append(c + Vector2(lerpf(-s, s, f), sin(f * TAU * 1.25) * s * 0.45))
			ci.draw_polyline(pts, col, wd)
			ci.draw_circle(pts[-1], s * 0.18, col)


func draw(ci: CanvasItem) -> void:
	# The idol: a stone plinth with three heads round its top.
	var c := idol
	Draw.shadow(ci, c + Vector2(0, 12), 16.0)
	ci.draw_rect(Rect2(c + Vector2(-14, -4), Vector2(28, 16)), Color(0.1, 0.09, 0.11))
	ci.draw_rect(Rect2(c + Vector2(-13, -3), Vector2(26, 14)), Color(0.4, 0.38, 0.36))
	ci.draw_rect(Rect2(c + Vector2(-9, -26), Vector2(18, 24)), Color(0.33, 0.31, 0.3))
	# The pods' roots: a vine ring round the idol.
	for q in pods:
		ci.draw_line(q["pos"], c, Color(0.2, 0.3, 0.16, 0.6), 3.0)
	for q in pods:
		Draw.shadow(ci, q["pos"] + Vector2(0, 10), 13.0)


func draw_glow(ci: CanvasItem, t: float) -> void:
	var c := idol
	for k in HEADS.size():
		var h: String = HEADS[k]
		var at := c + Vector2((k - 1) * 13.0, -32.0 + (4.0 if k == 1 else 0.0))
		var lit: bool = h == want and not host.solved
		ci.draw_circle(at, 8.0, Color(0.1, 0.09, 0.1))
		ci.draw_circle(at, 7.0, Color(0.45, 0.42, 0.4) if not lit else HEAD_COLORS[h].darkened(0.35))
		draw_head(ci, h, at, 5.5, HEAD_COLORS[h] if lit else Color(0.2, 0.18, 0.18), 1.4)
		if lit:
			ci.draw_arc(at, 10.0 + sin(t * 4.0), 0.0, TAU, 18, Color(HEAD_COLORS[h], 0.8), 1.6)
	for q in pods:
		var p: Vector2 = q["pos"]
		var open: bool = q["open"] > 0.0
		var k: float = clampf(q["open"] / 0.25, 0.0, 1.0) if open else 0.0
		# A bulb: green and shut, or split open on its sign.
		var shell := Color(0.32, 0.52, 0.24)
		if open:
			ci.draw_circle(p, 13.0, Color(0.12, 0.1, 0.08))
			ci.draw_circle(p, 11.5, Color(0.95, 0.9, 0.75))
			draw_head(ci, String(q["head"]), p, 9.0 * k, HEAD_COLORS.get(q["head"], Color.WHITE).darkened(0.3), 2.0)
			for side in [-1.0, 1.0]:
				var leaf := PackedVector2Array([p + Vector2(side * 9, 10), p + Vector2(side * 18, -2), p + Vector2(side * 12, -14), p + Vector2(side * 6, 2)])
				ci.draw_colored_polygon(leaf, shell)
			# How long it stays open: a ring that runs down.
			ci.draw_arc(p, 16.0, -PI / 2.0, -PI / 2.0 + TAU * q["open"] / float(_rules()[2]), 24, Color(HEAD_COLORS.get(q["head"], Color.WHITE), 0.8), 2.0)
		else:
			var bulb := Draw.blob(p, 12.0, t, 0.06, Vector2(0.9, 1.05), 14)
			ci.draw_colored_polygon(bulb, shell)
			ci.draw_polyline(bulb + PackedVector2Array([bulb[0]]), Color(0.12, 0.2, 0.1), 1.6)
			ci.draw_line(p + Vector2(0, -11), p + Vector2(0, 9), shell.darkened(0.3), 1.5)
		if q["pop"] > 0.0:
			ci.draw_arc(p, 14.0 + (0.4 - q["pop"]) * 50.0, 0.0, TAU, 24, Color(HEAD_COLORS.get(want, Color.WHITE), q["pop"] * 2.0), 2.0)
	# How many burst so far: small lights at the idol's foot.
	for k in need:
		var at := c + Vector2((k - (need - 1) * 0.5) * 8.0, 18.0)
		ci.draw_circle(at, 2.6, Color(1.0, 0.9, 0.6) if k < burst else Color(0.28, 0.28, 0.32))
