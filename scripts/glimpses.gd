extends Node2D
## GUARDIAN GLIMPSES: now and then, as you climb, the tower's beast is
## glimpsed: purely atmosphere, it never touches play. About once every few
## floors (RULES "chance" a floor, and never more than RULES "pity" floors
## without one), never on the bondless first climb, never on the summit,
## and never while you fight (no monster after you near, no blow taken a
## moment ago). Each glimpse is one of three, in its tower's flavour (LOOK):
##   shadow  a vast shadow sweeps across the open hall you stand in, the
##           beast's shape (wings for the fliers, a mass of arms for the
##           Kraken, a maned, tailed body for the Manticore and the Chimera),
##           with its sound far off (wingbeats, a surge, a rumble)
##   eyes    two eyes open in a high window in the hall's north wall, follow
##           you a moment, blink, and are gone
##   roar    after a big moment (the floor's task done, a fight won) the
##           beast roars somewhere far above: the floor shudders and dust
##           sifts down
## Each goes into the Entity's log (the "beast noticed" kind) in a short
## line (TEXT). main.gd makes one node; setup() each floor rolls for one.

const Palette := preload("res://scripts/palette.gd")
const Notices := preload("res://scripts/notices.gd")

## chance: a floor has one; pity: at most this many floors in a row without;
## from: the first floor; wait: seconds on the floor before it may come
## [least, most]; calm: seconds since your last hurt; near: how near a
## monster after you counts as a fight (px); roar_wait: how long a roar
## waits for its big moment before it's eyes instead.
static var RULES := {"chance": 0.3, "pity": 4, "from": 2, "wait": [12.0, 40.0], "calm": 4.0, "near": 560.0, "roar_wait": 80.0,
	"shadow_time": 3.4, "eyes_time": 3.8, "roar_time": 2.4}
## Each tower's beast as it's glimpsed: which glimpses (by weight), its
## shadow's shape and size, its eyes' colour, its sound far off.
static var LOOK := {
	"gryphon": {"kinds": {"shadow": 2.0, "eyes": 1.0, "roar": 1.0}, "shape": "wings", "span": 300.0, "eyes": Color(1.0, 0.86, 0.42), "sound": "wingbeat"},
	"kraken": {"kinds": {"shadow": 1.0, "eyes": 1.0, "roar": 1.0}, "shape": "arms", "span": 320.0, "eyes": Color(0.6, 0.95, 0.9), "sound": "wave"},
	"wyvern": {"kinds": {"shadow": 2.0, "eyes": 1.0, "roar": 1.0}, "shape": "wings", "span": 280.0, "eyes": Color(1.0, 0.55, 0.2), "sound": "wingbeat"},
	"manticore": {"kinds": {"shadow": 1.0, "eyes": 1.0, "roar": 1.5}, "shape": "beast", "span": 260.0, "eyes": Color(1.0, 0.7, 0.3), "sound": "stone_slide"},
	"firebird": {"kinds": {"shadow": 2.0, "eyes": 1.0, "roar": 1.0}, "shape": "wings", "span": 300.0, "eyes": Color(1.0, 0.75, 0.35), "sound": "wingbeat"},
	"chimera": {"kinds": {"shadow": 1.0, "eyes": 1.5, "roar": 1.0}, "shape": "beast", "span": 280.0, "eyes": Color(0.85, 1.0, 0.45), "sound": "stone_slide"},
}
static var TEXT := {
	"shadow": "A vast shadow passes over. %s.",
	"eyes": "Eyes in a high window. %s is watching.",
	"roar": "Far above, %s roars.",
}
## Floors since the last glimpse (a climb's count: a new climb starts it again).
static var since := 0
## (tests: the next floor's glimpse, "shadow", "eyes" or "roar"; and no waiting)
static var forced := ""

var main
var pending := ""  # the glimpse this floor holds ("" none)
var wait_t := 0.0
var roar_t := 0.0
var cur := {}  # the glimpse playing: {kind, t, dur, ...}
var shown := 0  # glimpses shown (tests)
var hurt_t := 99.0
var hp_seen := 0.0
var fought := false  # a fight on this floor, not yet won
var task_was := false
var calm_t := 0.0
var over: Node2D  # the eyes and dust, over the darkness


func _ready() -> void:
	z_index = -1  # (the shadow: on the floor, under everyone)
	over = Node2D.new()
	over.z_as_relative = false
	over.z_index = 45
	over.draw.connect(_draw_over)
	add_child(over)


## A new floor: maybe a glimpse waits on it.
func setup(plan: Dictionary) -> void:
	cur = {}
	pending = ""
	fought = false
	calm_t = 0.0
	hurt_t = 99.0
	task_was = false
	queue_redraw()
	over.queue_redraw()
	var n: int = main.floor_num
	if n <= 1:
		since = 0
	if plan.is_empty() or not main.layout_on or plan.get("summit", false) or main.first_climb or n < int(RULES["from"]) \
			or plan.has("try_room") or plan.get("proving", false) or not LOOK.has(String(main.tower)):
		return
	if forced != "" or randf() < float(RULES["chance"]) or since >= int(RULES["pity"]):
		pending = forced if forced != "" else _pick(LOOK[main.tower]["kinds"])
		wait_t = 0.0 if forced != "" else randf_range(float(RULES["wait"][0]), float(RULES["wait"][1]))
		roar_t = float(RULES["roar_wait"])
		forced = ""
		since = 0
	else:
		since += 1


static func _pick(weights: Dictionary) -> String:
	var total := 0.0
	for k in weights:
		total += float(weights[k])
	var r := randf() * total
	for k in weights:
		r -= float(weights[k])
		if r <= 0.0:
			return k
	return weights.keys()[0]


## No fight: no monster after you near, no blow taken a moment ago.
func calm() -> bool:
	var p = main.player
	if p == null or p.dead or main.climbing or hurt_t < float(RULES["calm"]):
		return false
	for e in main.enemies():
		if e.aware and not e.submerged and e.global_position.distance_to(p.global_position) < float(RULES["near"]):
			return false
	return true


func _process(delta: float) -> void:
	if main == null or main.player == null:
		return
	var p = main.player
	hurt_t = 0.0 if p.hp < hp_seen - 0.5 else hurt_t + delta
	hp_seen = p.hp
	if not cur.is_empty():
		cur["t"] = float(cur["t"]) + delta
		if float(cur["t"]) >= float(cur["dur"]):
			cur = {}
		queue_redraw()
		over.queue_redraw()
		return
	if pending == "":
		return
	var quiet := calm()
	# A big moment, for a roar: the task done, or a fight won.
	var big := false
	var ob = main.objective
	var done: bool = ob != null and ob.done
	if done and not task_was:
		big = true
	task_was = done
	if not quiet:
		fought = true
		calm_t = 0.0
	else:
		calm_t += delta
		if fought and calm_t > 2.0:
			fought = false
			big = true
	wait_t -= delta
	if pending == "roar":
		roar_t -= delta
		if roar_t <= 0.0:
			pending = "eyes"
		elif big and quiet and wait_t <= 0.0:
			_begin("roar")
		return
	if wait_t <= 0.0 and quiet:
		var room := _room_rect()
		if pending == "shadow" and (room == Rect2() or minf(room.size.x, room.size.y) < 240.0):
			return  # (a shadow wants an open hall: wait for one)
		if pending == "eyes" and room == Rect2():
			return
		_begin(pending)


## The hall the climber stands in (Rect2() in a corridor).
func _room_rect() -> Rect2:
	var pos: Vector2 = main.player.global_position
	for info in main.room_info:
		var r: Rect2 = info["rect"]
		if r.grow(-20.0).has_point(pos):
			return r
	return Rect2()


func _begin(kind: String) -> void:
	pending = ""
	shown += 1
	var look: Dictionary = LOOK[main.tower]
	var p = main.player
	var beast: String = main.beast_name()
	var line := ""
	match kind:
		"shadow":
			var room := _room_rect()
			var dir := Vector2.from_angle(randf_range(-0.5, 0.5) + (PI if randf() < 0.5 else 0.0))
			var mid: Vector2 = p.global_position.lerp(room.get_center(), 0.5) if room != Rect2() else p.global_position
			var off := dir.orthogonal() * randf_range(-60.0, 60.0)
			cur = {"kind": kind, "t": 0.0, "dur": float(RULES["shadow_time"]), "from": mid - dir * 620.0 + off, "to": mid + dir * 620.0 + off, "dir": dir}
			main.sfx(String(look["sound"]), 0.55, -12.0, 0.05)
			line = TEXT["shadow"] % beast.capitalize()
		"eyes":
			var room := _room_rect()
			var x := clampf(p.global_position.x, room.position.x + 50.0, room.end.x - 50.0)
			cur = {"kind": kind, "t": 0.0, "dur": float(RULES["eyes_time"]), "at": Vector2(x, room.position.y - 26.0)}
			main.sfx("eye_open", 0.7, -14.0, 0.05)
			line = TEXT["eyes"] % beast.capitalize()
		"roar":
			var dust: Array = []
			var view: Rect2 = main.room_view._view_rect() if main.room_view != null else Rect2(p.global_position - Vector2(640, 360), Vector2(1280, 720))
			for i in 28:
				dust.append(Vector2(randf_range(view.position.x, view.end.x), randf_range(view.position.y, view.end.y - 200.0)))
			cur = {"kind": kind, "t": 0.0, "dur": float(RULES["roar_time"]), "dust": dust}
			main.sfx_kind("roar", String(main.tower_data().get("beast_kind", "")), "", 0.62, -15.0)
			main.shake(2.5)
			line = TEXT["roar"] % beast
	main.note_event("noticed", line, null, false)
	queue_redraw()
	over.queue_redraw()


# --- drawing --------------------------------------------------------------------------------

func _draw() -> void:
	if cur.is_empty() or cur["kind"] != "shadow":
		return
	var k := float(cur["t"]) / float(cur["dur"])
	var at: Vector2 = Vector2(cur["from"]).lerp(cur["to"], k)
	var a := sin(PI * k)  # (it comes and goes softly)
	var look: Dictionary = LOOK[main.tower]
	var s := float(look["span"])
	var ang: float = Vector2(cur["dir"]).angle()
	draw_set_transform(at, ang, Vector2.ONE)
	for pass_ in 2:
		var grow := 1.12 if pass_ == 0 else 1.0
		var col := Color(0.0, 0.0, 0.02, (0.16 if pass_ == 0 else 0.36) * a)
		_shape(String(look["shape"]), s * grow, col, float(cur["t"]))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## A beast's shadow, facing +x, `s` across.
func _shape(shape: String, s: float, col: Color, t: float) -> void:
	match shape:
		"wings":
			var flap := 0.75 + 0.25 * sin(t * 2.2)
			_ellipse(Vector2.ZERO, Vector2(s * 0.22, s * 0.07), col)
			_ellipse(Vector2(s * 0.24, 0), Vector2(s * 0.06, s * 0.045), col)
			for sgn in [-1.0, 1.0]:
				draw_colored_polygon(PackedVector2Array([Vector2(s * 0.08, 0), Vector2(-s * 0.02, sgn * s * 0.5 * flap), Vector2(-s * 0.16, sgn * s * 0.46 * flap),
					Vector2(-s * 0.12, sgn * s * 0.3 * flap), Vector2(-s * 0.2, sgn * s * 0.2 * flap), Vector2(-s * 0.1, 0)]), col)
			draw_colored_polygon(PackedVector2Array([Vector2(-s * 0.2, -s * 0.02), Vector2(-s * 0.42, -s * 0.06), Vector2(-s * 0.4, s * 0.06), Vector2(-s * 0.2, s * 0.02)]), col)
		"arms":
			_ellipse(Vector2.ZERO, Vector2(s * 0.2, s * 0.16), col)
			for i in 8:
				var base := Vector2.from_angle(PI + (i - 3.5) * 0.28) * s * 0.14
				var pts := PackedVector2Array()
				for j in 8:
					var u := float(j) / 7.0
					pts.append(base + Vector2(-s * 0.42 * u, sin(t * 3.0 + i + u * 5.0) * s * 0.03 * u + (i - 3.5) * s * 0.04 * u))
				draw_polyline(pts, col, lerpf(s * 0.05, s * 0.02, 0.5))
		_:
			# A maned, tailed body on four legs (the Manticore, the Chimera).
			_ellipse(Vector2.ZERO, Vector2(s * 0.28, s * 0.11), col)
			_ellipse(Vector2(s * 0.3, 0), Vector2(s * 0.11, s * 0.1), col)
			if main != null and String(main.tower) == "chimera":
				_ellipse(Vector2(s * 0.26, -s * 0.13), Vector2(s * 0.07, s * 0.05), col)
				_ellipse(Vector2(s * 0.26, s * 0.13), Vector2(s * 0.07, s * 0.05), col)
			var step := sin(t * 5.0) * s * 0.04
			for x in [s * 0.18, -s * 0.18]:
				for sgn in [-1.0, 1.0]:
					draw_line(Vector2(x, sgn * s * 0.08), Vector2(x + step * sgn, sgn * s * 0.18), col, s * 0.05)
			var tail := PackedVector2Array()
			for j in 8:
				var u := float(j) / 7.0
				tail.append(Vector2(-s * 0.26 - s * 0.3 * u, sin(u * 3.0 + t * 2.0) * s * 0.08 * u))
			draw_polyline(tail, col, s * 0.035)


func _ellipse(c: Vector2, r: Vector2, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 20:
		var a := i * TAU / 20.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	draw_colored_polygon(pts, col)


## Over the darkness: the eyes in their window, and the dust after a roar.
func _draw_over() -> void:
	if cur.is_empty() or main == null:
		return
	var t := float(cur["t"])
	var dur := float(cur["dur"])
	match String(cur["kind"]):
		"eyes":
			var at: Vector2 = cur["at"]
			var look: Dictionary = LOOK[main.tower]
			var fade := clampf(t / 0.4, 0.0, 1.0) * clampf((dur - t) / 0.5, 0.0, 1.0)
			# The window: a dark arched slot high in the wall.
			var slot := PackedVector2Array()
			for i in 9:
				var a := PI + i * PI / 8.0
				slot.append(at + Vector2(cos(a) * 26.0, -4.0 + sin(a) * 12.0))
			slot.append(at + Vector2(26.0, 10.0))
			slot.append(at + Vector2(-26.0, 10.0))
			over.draw_colored_polygon(slot, Color(0.02, 0.02, 0.04, 0.85 * fade))
			over.draw_polyline(slot + PackedVector2Array([slot[0]]), Color(0.35, 0.33, 0.4, 0.6 * fade), 1.5)
			# Two eyes open, follow you, blink once, and close.
			var open := clampf((t - 0.35) / 0.35, 0.0, 1.0) * clampf((dur - 0.45 - t) / 0.35, 0.0, 1.0)
			if t > dur * 0.55 and t < dur * 0.55 + 0.16:
				open = 0.0  # (the blink)
			var eyes: Color = look["eyes"]
			var look_at: Vector2 = (main.player.global_position - at).normalized() * 1.8
			for sx in [-9.0, 9.0]:
				var e := at + Vector2(sx, 1.0)
				over.draw_set_transform(e, 0.0, Vector2(1.0, maxf(open, 0.05)))
				over.draw_circle(Vector2.ZERO, 7.0, Color(eyes, 0.18 * fade))
				over.draw_circle(Vector2.ZERO, 4.0, Color(eyes, 0.9 * fade))
				over.draw_circle(look_at, 1.6, Color(0.05, 0.02, 0.0, fade))
				over.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"roar":
			var k := t / dur
			for i in cur["dust"].size():
				var d: Vector2 = cur["dust"][i]
				var fall := fmod(k * (90.0 + 40.0 * fmod(i * 0.37, 1.0)) + i * 7.0, 200.0)
				over.draw_circle(d + Vector2(sin(k * 6.0 + i) * 3.0, fall), 1.2, Color(0.75, 0.7, 0.62, 0.55 * sin(PI * k)))
