extends "res://scripts/towers/brood.gd"
## THE KINDLER: a hooded torch-bearer of the Firebird's tower (kind "kindler";
## enemy.gd SUBKINDS spawns it with this script). While a kindler lives, a
## monster that falls nearby leaves a heap of smouldering ASH. The kindler
## keeps its distance, walks to a heap, raises its torch and CHANNELS a beam
## of fire into it (a crackle, a line of embers from torch to ash, the heap
## glowing brighter): when the channel ends the fallen rises again as a weak
## ASH-RISEN copy (grey, a share of its health and bite; it leaves nothing
## when it crumbles). Strike the kindler while it channels and it's
## interrupted (staggered). SOAK the ash (water, a soaked foe beside it) or
## STAMP it out (stand on it a moment) and nothing rises from it, or kill
## the kindler first. Close in and it swipes its torch (parryable; it burns).
## The heaps are drawn by a node of their own (Heaps, under main).

static var KINDLER := {
	"keep": 170.0,  # how far it keeps from you (px)
	"heap_reach": 420.0,  # it goes for a heap this near
	"beam": 110.0,  # it channels from this near a heap
	"channel": 2.2,  # seconds the rekindling takes
	"cooldown": 5.0,  # seconds before it channels again
	"copies": 2,  # ash-risen copies it keeps at once, at most
	"copy_hp": 0.4,  # a copy's share of the health...
	"copy_dmg": 0.6,  # ...and of the blows
	"stagger": 0.9,  # seconds an interrupted kindler reels
	"heap_life": 16.0,  # seconds a heap of ash smoulders
	"heap_r": 16.0,  # its size (px)
	"stamp": 0.6,  # seconds standing on a heap to stamp it out
	"swipe_near": 58.0, "swipe_wind": 0.55, "swipe_reach": 64.0, "swipe_arc": 55.0,
}
static var KINDLER_TEXT := {
	"kindle": "It rekindles the ash!",
	"interrupt": "Interrupted!",
	"risen": "Ash-risen!",
	"soaked": "The ash is soaked",
	"stamped": "Stamped out",
	"crumble": "crumbles to ash",
}
## Kinds that leave no ash (they're ash already, or not flesh).
const NO_ASH := ["kindler", "mimic", "familiar", "flamemoth", "cairn"]

const C_ROBE := Color(0.36, 0.32, 0.32)
const C_HOOD := Color(0.26, 0.22, 0.23)
const C_TORCH := Color(1.0, 0.72, 0.3)

var heap = null  # the heap it's going for or channelling into
var channel_cd := 0.0
var copies: Array = []


func setup(k: String, room) -> void:
	super.setup(k, room)
	channel_cd = 2.0


## The torch's tip, from its middle (the beam and the flamemoths' lure start here).
func torch_tip() -> Vector2:
	var f := face
	return f * radius * 0.9 + f.orthogonal() * radius * 0.7 + Vector2(0, -radius * (1.6 if state == "channel" else 0.9))


func _act(delta: float, dir: Vector2, dist: float, p) -> void:
	var c := KINDLER
	_first_look(dist)
	channel_cd -= delta
	copies = copies.filter(func(x): return is_instance_valid(x) and not x.dead)
	if heap != null and not heaps(main).has_heap(heap):
		heap = null
		if state == "channel":
			state = "recover"
			state_t = 0.5
	match state:
		"channel":
			velocity = Vector2.ZERO
			face = face.slerp((Vector2(heap["pos"]) - global_position).normalized(), minf(1.0, 8.0 * delta)).normalized()
			state_t -= delta
			heap["k"] = 1.0 - clampf(state_t / float(c["channel"]), 0.0, 1.0)
			if state_t <= 0.0:
				_rekindle(heap)
				heap = null
				channel_cd = float(c["cooldown"])
				state = "recover"
				state_t = 0.8
		"wind_swipe":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta):
				main.fx_cone(global_position, lunge_dir, float(c["swipe_reach"]), deg_to_rad(float(c["swipe_arc"])), Color(1.0, 0.6, 0.3))
				main.sfx_at(global_position, "swing", 0.8, -2.0)
				_strike_cone(p, lunge_dir, float(c["swipe_reach"]), float(c["swipe_arc"]), dmg)
				_end_attack("recover", 1.0)
		"recover", "idle":
			state_t -= delta
			_circle(dir, dist, float(c["keep"]), speed * 0.6)
			if state_t <= 0.0:
				state = "chase"
		_:
			if dist < float(c["swipe_near"]) and main.request_attack(self):
				_begin_wind("wind_swipe", float(c["swipe_wind"]))
				_warn(0.8)
				return
			if heap == null and channel_cd <= 0.0 and copies.size() < int(c["copies"]):
				heap = heaps(main).nearest(global_position, float(c["heap_reach"]))
			if heap != null:
				var to: Vector2 = Vector2(heap["pos"]) - global_position
				if to.length() <= float(c["beam"]) and main.clear_line(global_position, heap["pos"]):
					state = "channel"
					state_t = float(c["channel"])
					heap["k"] = 0.0
					main.fx_text(global_position + Vector2(0, -radius - 24.0), String(KINDLER_TEXT["kindle"]), C_TORCH)
					main.sfx_at(global_position, "flare", 0.8, -2.0)
				else:
					velocity = main.path_dir(global_position, heap["pos"]) * speed
				return
			_circle(dir, dist, float(c["keep"]), speed)


## The ash takes the beam: the fallen rises, ash-grey and weak.
func _rekindle(h: Dictionary) -> void:
	var c := KINDLER
	var at: Vector2 = h["pos"]
	heaps(main).remove(h)
	var e = main.spawn_enemy(String(h["kind"]), at)
	if e == null:
		return
	e.set_meta("ashen", true)
	e.max_hp *= float(c["copy_hp"])
	e.hp = e.max_hp
	e.dmg *= float(c["copy_dmg"])
	e.notice_t = 0.0
	e.aware = true
	copies.append(e)
	main.fx_text(at + Vector2(0, -34), String(KINDLER_TEXT["risen"]), Color(0.85, 0.8, 0.75))
	main.fx_burst(at, Vector2.UP, C_TORCH, 18, 200.0)
	main.fx_ring(at, C_TORCH, 40.0, 0.35, 3.0)
	main.light_flash(at, C_TORCH, 1.2, 1.5, 0.3)
	main.sfx_at(global_position, "burn", 0.9, -2.0)


func take_hit(amount: float, dir: Vector2, force := 140.0, heavy := false, pierce := false) -> void:
	if dead:
		return
	var was := state == "channel"
	super.take_hit(amount, dir, force, heavy, pierce)
	if was and not dead and state == "channel":
		if heap != null:
			heap["k"] = 0.0
		heap = null
		channel_cd = 1.5
		state = "recover"
		state_t = 0.6
		stun = maxf(stun, float(KINDLER["stagger"]))
		main.fx_text(global_position + Vector2(0, -radius - 28.0), String(KINDLER_TEXT["interrupt"]), Color(1.0, 0.89, 0.63))


func is_attacking() -> bool:
	return state.begins_with("wind")


# --- the ash heaps (any floor a kindler walks) -----------------------------------------

## main.gd on_enemy_killed: a monster fell. While a kindler lives on the
## floor it leaves a heap of ash. True if it was an ash-risen copy (it
## crumbles: main.gd gives nothing for it).
static func fallen(main, e) -> bool:
	if e.has_meta("ashen"):
		main.fx_text(e.global_position + Vector2(0, -30), String(KINDLER_TEXT["crumble"]), Color(0.75, 0.72, 0.7))
		main.fx_burst(e.global_position, Vector2.UP, Color(0.45, 0.42, 0.42), 16, 140.0)
		main.sfx_at(e.global_position, "burn", 0.6, -6.0)
		return true
	if e.is_boss() or e.ally or e.shade or e.mirror or e.kind in NO_ASH:
		return false
	if not main.enemies().any(func(o): return o.kind == "kindler" and o != e and not o.dead):
		return false
	heaps(main).add(e.global_position, String(e.kind), main.floor_num)
	return false


## The node that keeps and draws the floor's heaps of ash (made when first needed).
static func heaps(main) -> Node2D:
	var n = main.get_node_or_null("AshHeaps")
	if n == null:
		n = Heaps.new()
		n.name = "AshHeaps"
		n.main = main
		n.K = load("res://scripts/towers/kindler.gd")
		main.add_child(n)
	return n


class Heaps extends Node2D:
	var main
	var K  # (towers/kindler.gd: its KINDLER numbers and words)
	var list: Array = []  # {pos, kind, t, floor, stamp, k}

	func add(pos: Vector2, kind: String, fl: int) -> void:
		list.append({"pos": pos, "kind": kind, "t": float(K.KINDLER["heap_life"]), "floor": fl, "stamp": 0.0, "k": 0.0})
		queue_redraw()

	func has_heap(h) -> bool:
		return list.has(h)

	func remove(h) -> void:
		list.erase(h)
		queue_redraw()

	func nearest(from: Vector2, reach: float):
		var best = null
		var bd := reach
		for h in list:
			var d: float = from.distance_to(h["pos"])
			if d < bd:
				bd = d
				best = h
		return best

	func _process(delta: float) -> void:
		if list.is_empty() or main == null:
			return
		var p = main.player
		for h in list.duplicate():
			h["t"] -= delta
			var gone := ""
			if int(h["floor"]) != int(main.floor_num) or main.climbing:
				gone = "-"
			elif main.in_water(h["pos"]) or main.enemies().any(func(o): return o.soaked > 0.0 and o.global_position.distance_to(h["pos"]) < float(K.KINDLER["heap_r"]) + o.radius + 20.0):
				gone = "soaked"
			elif p != null and not p.dead and p.global_position.distance_to(h["pos"]) < float(K.KINDLER["heap_r"]) + p.radius:
				h["stamp"] += delta
				if h["stamp"] >= float(K.KINDLER["stamp"]):
					gone = "stamped"
			else:
				h["stamp"] = 0.0
			if gone == "" and float(h["t"]) <= 0.0:
				gone = "-"
			if gone != "":
				list.erase(h)
				if gone != "-":
					main.fx_text(Vector2(h["pos"]) + Vector2(0, -24), String(K.KINDLER_TEXT[gone]), Color(0.7, 0.82, 0.92) if gone == "soaked" else Color(0.85, 0.8, 0.72))
					main.fx_burst(h["pos"], Vector2.UP, Color(0.5, 0.48, 0.48), 10, 90.0)
					main.sfx_at(global_position, "hiss" if gone == "soaked" else "step", 1.0, -4.0)
		queue_redraw()

	func _draw() -> void:
		var t := Time.get_ticks_msec() * 0.001
		var r := float(K.KINDLER["heap_r"])
		for h in list:
			var at: Vector2 = h["pos"]
			var k: float = h["k"]
			var fade := clampf(float(h["t"]) / 2.0, 0.0, 1.0)
			draw_set_transform(at, 0.0, Vector2.ONE)
			draw_circle(Vector2(0, 3), r * 1.15, Color(0.0, 0.0, 0.0, 0.25 * fade))
			draw_circle(Vector2(0, 2), r, Color(0.22, 0.2, 0.2, 0.95 * fade))
			draw_circle(Vector2(-2, 0), r * 0.7, Color(0.33, 0.3, 0.3, fade))
			draw_circle(Vector2(1, -2), r * 0.38, Color(0.42, 0.39, 0.38, fade))
			for i in 6:
				var e := Vector2(cos(i * 2.1) * r * 0.7, 2.0 + sin(i * 1.7) * r * 0.35)
				var glow := (0.4 + 0.3 * sin(t * 5.0 + i * 1.3)) * fade + k * 0.6
				draw_circle(e, 1.2 + 1.8 * k, Color(1.0, 0.5 + 0.3 * k, 0.2, clampf(glow, 0.0, 1.0)))
			if k > 0.0:
				# The fallen's shape stirring in the ash.
				draw_circle(Vector2(0, -r * 0.5 * k), r * 0.7 * k, Color(1.0, 0.65, 0.3, 0.25 * k))
				draw_arc(Vector2.ZERO, r + 4.0 + 6.0 * (1.0 - k), 0.0, TAU, 24, Color(1.0, 0.6, 0.3, 0.6 * k), 2.0)
			if float(h["stamp"]) > 0.0:
				draw_arc(Vector2.ZERO, r + 3.0, -PI / 2.0, -PI / 2.0 + TAU * float(h["stamp"]) / float(K.KINDLER["stamp"]), 20, Color(0.9, 0.85, 0.75, 0.9), 2.0)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- drawing ---------------------------------------------------------------------------

func _draw_own(p, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	var swing := _ease("swing", _wk(float(KINDLER["swipe_wind"])) if state == "wind_swipe" else 0.0, 12.0)
	var raise := _ease("raise", 1.0 if state == "channel" else 0.0, 8.0)
	var step := sin(_stride * 1.4) * 2.0 * _move
	for sgn in [-1.0, 1.0]:  # feet under the robe's hem
		p.ball(s * sgn * 4.0 + f * step * sgn + Vector2(0, radius * 0.55), 2.6, C_HOOD.darkened(0.2))
	# A long robe, hunched, its hem ragged and singed.
	var hem := PackedVector2Array()
	for i in 9:
		var a := PI * 0.1 + PI * 0.8 * i / 8.0
		hem.append(Vector2(cos(a) * radius * 0.95, radius * 0.25 + sin(a) * radius * 0.45 + (1.5 if i % 2 == 0 else -0.5)))
	hem.append(Vector2(-radius * 0.5, -radius * 0.8))
	hem.append(Vector2(radius * 0.5, -radius * 0.8))
	p.poly(hem, C_ROBE, 1.6)
	p.egg(Vector2(0, -radius * 0.55), Vector2(radius * 0.62, radius * 0.7), 0.0, C_ROBE.lightened(0.05))
	# The torch arm, then the torch.
	var shoulder := s * radius * 0.5 + Vector2(0, -radius * 0.8)
	var grip := shoulder + f * radius * (0.5 - 0.6 * swing) + s * radius * 0.25 + Vector2(0, -radius * (0.2 + 0.9 * raise) + 6.0 * swing)
	p.limb(shoulder, grip, C_ROBE.darkened(0.1), 3.4)
	var tip := torch_tip()
	p.limb(grip - (tip - grip).normalized() * 3.0, tip, Palette.WOOD.darkened(0.2), 2.6)
	var fl := _flame(tip + Vector2(0, -2), 4.5 + 2.0 * raise, t, 1.4)
	p.poly(fl, C_TORCH, 0.0)
	_glow.circle(tip + Vector2(0, -3), 3.0 + 1.5 * sin(t * 9.0), Color(1.0, 0.9, 0.55, 0.9), 10)
	_glow.circle(tip + Vector2(0, -2), 12.0 + 6.0 * raise, Color(1.0, 0.6, 0.25, 0.15 + 0.1 * raise), 16)
	# The hood, deep, two embers for eyes.
	var head := Vector2(0, -radius * 1.25) + f * 2.0
	p.ball(head, radius * 0.48, C_HOOD)
	p.oval(head + f * radius * 0.18 + Vector2(0, 1), Vector2(radius * 0.28, radius * 0.24), f.angle(), Palette.OUTLINE, 12)
	_glow.circle(head + f * radius * 0.25 + s * 2.2 + Vector2(0, 1), 1.1, Color(1.0, 0.6, 0.25), 6)
	_glow.circle(head + f * radius * 0.25 - s * 2.2 + Vector2(0, 1), 1.1, Color(1.0, 0.6, 0.25), 6)


func _overlay_extra(o) -> void:
	if state == "wind_swipe":
		_cone(o, float(KINDLER["swipe_reach"]), float(KINDLER["swipe_arc"]), _wk(float(KINDLER["swipe_wind"])), 0.1, 0.75)
	elif state == "channel" and heap != null:
		# The beam: a wavering line of embers from the torch to the ash.
		var a := torch_tip()
		var b: Vector2 = Vector2(heap["pos"]) - global_position
		var k := clampf(float(heap["k"]), 0.0, 1.0)
		var now := Time.get_ticks_msec() * 0.001
		var n := 10
		var prev := a
		for i in range(1, n + 1):
			var u := float(i) / n
			var side := (b - a).normalized().orthogonal() * sin(now * 14.0 + u * 9.0) * 3.0 * (1.0 - absf(u - 0.5) * 2.0)
			var at := a.lerp(b, u) + side
			o.quad(prev, at, 2.0 + 2.0 * k, Color(1.0, 0.6 + 0.3 * k, 0.25, 0.5 + 0.4 * k))
			prev = at
		o.arc(b, 22.0 * (1.0 - k) + 8.0, 0.0, TAU, 2.0, Color(1.0, 0.7, 0.3, 0.8), 24)
