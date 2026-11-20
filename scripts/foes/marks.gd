extends Node2D
## What some of the new monsters leave on the floor, kept apart from the
## monster so it can outlive it (scripts/foes/): a slagworm's slag, a
## driftbell's charged trail, an inkling's cloud of ink. One node of a kind
## holds a list of beads ({"pos", "t", "max"...}), ticks what they do to the
## climber, draws them, and frees itself when they're all gone (or the floor
## changes). `rules` is a copy of the monster's numbers (its RULES), taken
## when the node is made, so nothing here reaches back into its script.
##
##   slag   low slag walls a slagworm leaves: hot, they burn whoever stands
##          on them (as burning floor does: a jump or a roll goes over them
##          free), then cool dark and crumble. They never block anyone.
##   trail  beads a driftbell leaves as it drifts: on water they crackle, and
##          touching one costs a little health and leaves you charged; on dry
##          stone they fade at once, harmless.
##   burst  a fallen drowned one's body, swelling (a ring shows how far it
##          will burst), then bursting: whoever is in the ring is soaked.
##   ink    an inkling's cloud: a dark blot over the floor (and over whoever
##          stands in it) that thins and is gone in a few seconds. Monsters'
##          warnings are drawn over it, so a blow from inside still glints.

const Palette := preload("res://scripts/palette.gd")
const Reactions := preload("res://scripts/reactions.gd")

var main
var kind := "slag"
var rules := {}
var beads: Array = []
var foe = null  # whose beads these are (null once it's gone)
var plan = null  # the floor these belong to
var _zap_t := 0.0
var glow: Node2D  # the bright part (over the darkness)


## A new node of beads for `foe` (call once; add beads to its list).
static func make(main_node, k: String, r: Dictionary, f) -> Node2D:
	var m = load("res://scripts/foes/marks.gd").new()
	m.main = main_node
	m.kind = k
	m.rules = r.duplicate()
	m.foe = f
	m.plan = main_node.floor_plan
	m.z_as_relative = false
	m.z_index = 44 if k == "ink" else -5  # (ink lies over everything but the warnings; slag and trails on the floor)
	main_node.add_child.call_deferred(m)  # (it may be made while a monster leaves the tree)
	if k != "ink":
		m.glow = Node2D.new()
		m.glow.z_as_relative = false
		m.glow.z_index = 41  # (the hot glow and the crackle read in the dark)
		m.glow.draw.connect(m._draw_glow)
		m.add_child(m.glow)
	return m


func _physics_process(delta: float) -> void:
	if main == null or not is_instance_valid(main) or not is_same(main.floor_plan, plan):
		queue_free()
		return
	_zap_t -= delta
	for b in beads:
		b["t"] -= delta
		if kind == "burst" and float(b["t"]) <= 0.0 and not b.get("done", false):
			b["done"] = true
			_burst(b["pos"])
	beads = beads.filter(func(b): return float(b["t"]) > 0.0)
	var p = main.player
	if p != null and not p.dead:
		match kind:
			"slag":
				_tick_slag(p, delta)
			"trail":
				_tick_trail(p)
	var gone: bool = foe == null or not is_instance_valid(foe) or foe.dead
	if beads.is_empty() and gone:
		queue_free()
		return
	queue_redraw()
	if glow != null:
		glow.queue_redraw()


## A drowned one bursts: everyone in the ring is soaked.
func _burst(at: Vector2) -> void:
	var reach := float(rules.get("burst", 80.0))
	var water := Color(0.6, 0.85, 0.95)
	main.fx_ring(at, water, reach, 0.4, 5.0)
	main.fx_burst(at, Vector2.ZERO, water, 26, 320.0)
	main.sfx("wave", 0.9, -2.0)
	var p = main.player
	if p != null and not p.dead and p.global_position.distance_to(at) < reach + p.radius and p.iframes <= 0.0:
		Reactions.apply(main, p, "soaked", float(rules.get("soak", 5.0)), null)
		main.fx_text(p.global_position + Vector2(0, -56), String(rules.get("soaked_text", "Soaked!")), water)
	for e in main.enemies():
		if e.global_position.distance_to(at) < reach + e.radius:
			Reactions.apply(main, e, "soaked", float(Reactions.STATES["soaked"]["seconds"]), "drowned")


## Standing on a hot bead burns like burning floor (a jump or a roll is free).
func _tick_slag(p, delta: float) -> void:
	if p.in_air() or p.roll_t > 0.0:
		return
	var cool := float(rules.get("crumble", 2.0))
	for b in beads:
		if float(b["t"]) > cool and p.global_position.distance_to(b["pos"]) < float(rules.get("bead", 11.0)) + p.radius * 0.5:
			p.stand_in_fire(delta)
			if Reactions.CLIMBER["enabled"] and p.iframes <= 0.0:
				Reactions.apply(main, p, "burning", Reactions.climber_seconds("burning"), foe if is_instance_valid(foe) else null)
			if main.has_method("tip"):
				main.tip("slagworm")
			return


## A crackling bead on water stings whoever touches it and leaves them charged.
func _tick_trail(p) -> void:
	if _zap_t > 0.0 or p.in_air() or p.iframes > 0.0:
		return
	for b in beads:
		if not b.get("wet", false):
			continue
		if p.global_position.distance_to(b["pos"]) < float(rules.get("bead", 16.0)) + p.radius * 0.5:
			_zap_t = float(rules.get("zap_cd", 0.6))
			var before: float = p.hp
			p.receive_attack(float(rules.get("zap", 3.0)), foe if is_instance_valid(foe) else null, true)
			if p.hp < before:
				Reactions.apply(main, p, "charged", Reactions.climber_seconds("charged"), foe if is_instance_valid(foe) else null)
			main.fx_bolt([b["pos"], p.global_position], Color(0.75, 0.9, 1.0))
			main.sfx("zap", 1.4, -8.0)
			return


func _draw() -> void:
	var now := Time.get_ticks_msec() * 0.001
	match kind:
		"slag":
			var cool := float(rules.get("crumble", 2.0))
			var r := float(rules.get("bead", 11.0))
			for b in beads:
				var t := float(b["t"])
				var heat := clampf((t - cool) / 1.5, 0.0, 1.0)
				var crumb := clampf(t / cool, 0.0, 1.0)  # (1 whole .. 0 crumbled away)
				var at: Vector2 = b["pos"]
				var rr := r * (0.55 + 0.45 * crumb)
				draw_circle(at + Vector2(0, 2), rr + 2.0, Color(Palette.OUTLINE, 0.55 * crumb))
				draw_circle(at, rr, Color(0.22, 0.17, 0.15).lerp(Color(0.55, 0.24, 0.12), heat))
				draw_circle(at + Vector2(-rr * 0.25, -rr * 0.3), rr * 0.45, Color(0.38, 0.3, 0.26, 0.8 * crumb).lerp(Color(1.0, 0.6, 0.25), heat))
				if crumb < 1.0:
					for k in 3:  # (cracks as it crumbles)
						var a := float(k) * 2.1 + at.x
						draw_line(at, at + Vector2.from_angle(a) * rr, Color(0.08, 0.06, 0.05, 1.0 - crumb), 1.2)
		"trail":
			var r := float(rules.get("bead", 16.0))
			for b in beads:
				var k := clampf(float(b["t"]) / float(b.get("max", 1.0)), 0.0, 1.0)
				if b.get("wet", false):
					draw_circle(b["pos"], r, Color(0.45, 0.7, 1.0, 0.16 * k))
		"burst":
			for b in beads:
				var k := 1.0 - clampf(float(b["t"]) / float(b.get("max", 1.0)), 0.0, 1.0)
				var at: Vector2 = b["pos"]
				var rr := 11.0 + 7.0 * k
				draw_circle(at, rr + 1.6, Palette.OUTLINE)
				draw_circle(at, rr, Color(0.42, 0.52, 0.48))
				draw_circle(at + Vector2(-rr * 0.3, -rr * 0.35), rr * 0.35, Color(0.75, 0.9, 0.95, 0.6))
		"ink":
			var r := float(rules.get("cloud", 80.0))
			for b in beads:
				var k := clampf(float(b["t"]) / float(b.get("max", 1.0)), 0.0, 1.0)
				var grow := clampf((float(b.get("max", 1.0)) - float(b["t"])) / 0.25, 0.0, 1.0)  # (it billows out)
				var fade := clampf(k / 0.3, 0.0, 1.0)  # (and thins at the end)
				var at: Vector2 = b["pos"]
				var rr := r * (0.4 + 0.6 * grow)
				for i in 5:
					var ring := rr * (1.15 - 0.15 * i)
					draw_circle(at, ring, Color(0.03, 0.02, 0.06, 0.22 * fade))
				for i in 7:  # (curls of ink at the edge)
					var a := now * 0.6 + float(i) * TAU / 7.0
					draw_circle(at + Vector2.from_angle(a) * rr * 0.85, rr * 0.28, Color(0.06, 0.03, 0.1, 0.35 * fade))


func _draw_glow() -> void:
	var now := Time.get_ticks_msec() * 0.001
	match kind:
		"burst":
			var reach := float(rules.get("burst", 80.0))
			for b in beads:
				var k := 1.0 - clampf(float(b["t"]) / float(b.get("max", 1.0)), 0.0, 1.0)
				glow.draw_circle(b["pos"], reach, Color(0.36, 0.66, 0.96, 0.1 + 0.12 * k))
				glow.draw_arc(b["pos"], reach, 0.0, TAU, 40, Color(0.6, 0.85, 1.0, 0.8), 2.0)
				glow.draw_arc(b["pos"], reach * (1.0 - k) + 6.0, 0.0, TAU, 32, Color(Palette.DANGER, 0.7), 1.5)
		"slag":
			var cool := float(rules.get("crumble", 2.0))
			var r := float(rules.get("bead", 11.0))
			for b in beads:
				var heat := clampf((float(b["t"]) - cool) / 1.5, 0.0, 1.0)
				if heat > 0.0:
					glow.draw_circle(b["pos"], r * 0.5, Color(1.0, 0.55, 0.2, 0.45 * heat))
					glow.draw_arc(b["pos"], r * 0.9, 0.0, TAU, 14, Color(1.0, 0.45, 0.15, 0.5 * heat), 1.5)
		"trail":
			var r := float(rules.get("bead", 16.0))
			for i in beads.size():
				var b: Dictionary = beads[i]
				var k := clampf(float(b["t"]) / float(b.get("max", 1.0)), 0.0, 1.0)
				var at: Vector2 = b["pos"]
				if not b.get("wet", false):
					glow.draw_circle(at, 3.0, Color(0.7, 0.85, 1.0, 0.3 * k))
					continue
				glow.draw_arc(at, r * 0.8, 0.0, TAU, 16, Color(0.7, 0.9, 1.0, 0.55 * k), 1.4)
				var prev := at + Vector2.from_angle(now * 7.0 + i) * r * 0.7
				for j in 3:  # (a little crackle across it)
					var nxt := at + Vector2.from_angle(now * 7.0 + i + 1.6 * (j + 1)) * r * (0.35 + 0.35 * float(j % 2))
					glow.draw_line(prev, nxt, Color(0.95, 0.97, 0.6, 0.8 * k), 1.3)
					prev = nxt
