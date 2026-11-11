extends Node2D
## What the library's spells and variations leave in the world for a while
## (library.gd, scripts/spells/): timed casts (Delayed, Echo), fields that
## work on what stands in them (Lingering, a charged patch), orbs that travel
## (Ball Lightning) and warning rings. One lives under main ("SpellFx"),
## made the first time something needs it; a new floor clears it
## (main.gd _start_floor). It stops while the game is paused, like the fight.
##
## Content files use the static helpers, never the node itself:
##   later(main, seconds, fn)                          call fn after a while
##   field(main, pos, radius, seconds, tick, col, fn)  fn(foes inside) every tick
##   orb(main, pos, vel, seconds, radius, col, fn)     fn(orb, delta) each frame;
##                                                     orb {pos, vel, t, radius, col}; set orb.done to end it
##   mark(main, pos, seconds, col)                     a shrinking ring: something lands here soon

const NAME := "SpellFx"

var timers: Array = []  # {t, fn}
var fields: Array = []  # {pos, radius, t, tick, every, col, fn, age}
var orbs: Array = []  # {pos, vel, t, radius, col, fn, done, age}
var marks: Array = []  # {pos, t, total, col}


func _ready() -> void:
	z_as_relative = false
	z_index = 46  # (over the darkness, like the techniques' bolts)


static func of(main):
	if main == null or not is_instance_valid(main):
		return null
	var n = main.get_node_or_null(NAME)
	if n == null:
		n = load("res://scripts/spell_fx.gd").new()
		n.name = NAME
		main.add_child(n)
	return n


static func later(main, seconds: float, fn: Callable) -> void:
	var n = of(main)
	if n != null:
		n.timers.append({"t": seconds, "fn": fn})


static func field(main, pos: Vector2, radius: float, seconds: float, tick: float, col: Color, fn: Callable) -> void:
	var n = of(main)
	if n != null:
		n.fields.append({"pos": pos, "radius": radius, "t": seconds, "total": seconds, "every": maxf(tick, 0.05), "tick": 0.0, "col": col, "fn": fn, "age": 0.0})


static func orb(main, pos: Vector2, vel: Vector2, seconds: float, radius: float, col: Color, fn: Callable) -> Dictionary:
	var n = of(main)
	var o := {"pos": pos, "vel": vel, "t": seconds, "radius": radius, "col": col, "fn": fn, "done": false, "age": 0.0}
	if n != null:
		n.orbs.append(o)
	return o


static func mark(main, pos: Vector2, seconds: float, col: Color) -> void:
	var n = of(main)
	if n != null:
		n.marks.append({"pos": pos, "t": seconds, "total": maxf(seconds, 0.05), "col": col})


## A new floor: nothing carries over.
static func clear(main) -> void:
	var n = main.get_node_or_null(NAME) if main != null else null
	if n != null:
		n.timers.clear()
		n.fields.clear()
		n.orbs.clear()
		n.marks.clear()
		n.queue_redraw()


func busy() -> bool:
	return not (timers.is_empty() and fields.is_empty() and orbs.is_empty() and marks.is_empty())


func _process(delta: float) -> void:
	if not busy():
		return
	var main = get_parent()
	for tm in timers.duplicate():
		tm["t"] -= delta
		if tm["t"] <= 0.0:
			timers.erase(tm)
			if (tm["fn"] as Callable).is_valid():
				tm["fn"].call()
	for f in fields.duplicate():
		f["t"] -= delta
		f["age"] += delta
		f["tick"] -= delta
		if f["tick"] <= 0.0:
			f["tick"] = f["every"]
			var inside: Array = []
			for e in main.targets():
				if e.global_position.distance_to(f["pos"]) <= float(f["radius"]) + e.radius:
					inside.append(e)
			if (f["fn"] as Callable).is_valid():
				f["fn"].call(inside)
		if f["t"] <= 0.0:
			fields.erase(f)
	for o in orbs.duplicate():
		o["t"] -= delta
		o["age"] += delta
		var next: Vector2 = o["pos"] + o["vel"] * delta
		if main.has_method("is_solid") and main.is_solid(next):
			o["done"] = true
		else:
			o["pos"] = next
		if (o["fn"] as Callable).is_valid() and not o["done"]:
			o["fn"].call(o, delta)
		if o["t"] <= 0.0 or o["done"]:
			orbs.erase(o)
			if main.has_method("fx_burst"):
				main.fx_burst(o["pos"], Vector2.ZERO, o["col"], 10, 160.0)
	for m in marks.duplicate():
		m["t"] -= delta
		if m["t"] <= 0.0:
			marks.erase(m)
	queue_redraw()


func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001
	for f in fields:
		var a := clampf(float(f["t"]) / 0.4, 0.0, 1.0) * clampf(float(f["age"]) / 0.15, 0.0, 1.0)
		var col: Color = f["col"]
		var r: float = f["radius"]
		draw_circle(f["pos"], r, Color(col, 0.12 * a))
		draw_arc(f["pos"], r, 0.0, TAU, 40, Color(col, 0.55 * a), 2.0, true)
		for i in 5:
			var ang := t * 2.2 + float(i) * TAU / 5.0
			draw_circle(f["pos"] + Vector2.from_angle(ang) * r * (0.35 + 0.5 * fmod(t + i * 0.3, 1.0)), 2.0, Color(col.lightened(0.4), 0.8 * a))
	for o in orbs:
		var col: Color = o["col"]
		var r: float = o["radius"]
		draw_circle(o["pos"], r, Color(col, 0.1))
		draw_circle(o["pos"], 11.0 + sin(t * 30.0) * 1.5, Color(col, 0.55))
		draw_circle(o["pos"], 6.0, col.lightened(0.6))
		for i in 3:
			var ang := t * 9.0 + float(i) * TAU / 3.0 + sin(t * 17.0 + i) * 0.6
			var p1: Vector2 = o["pos"] + Vector2.from_angle(ang) * 9.0
			var p2: Vector2 = o["pos"] + Vector2.from_angle(ang + 0.4) * (r * 0.8)
			draw_line(p1, p2, Color(col.lightened(0.5), 0.7), 1.5, true)
	for m in marks:
		var k := 1.0 - float(m["t"]) / float(m["total"])
		draw_arc(m["pos"], lerpf(34.0, 8.0, k), 0.0, TAU, 32, Color(m["col"], 0.4 + 0.5 * k), 2.0, true)
