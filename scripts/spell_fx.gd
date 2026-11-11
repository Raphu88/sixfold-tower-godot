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
##   lasting(main, seconds, tick, paint, data, opts)   something that stays a while, drawn in
##                                                     code (a Lasting node: see below)
##   item(main, seconds, tick, paint, high)            the same, kept as a dictionary
##                                                     {t, age, done}, painted into a Batch
##   listen(node, signal, fn)                          fn on a signal while `node` lasts (a
##                                                     foe's or main's on_hit, the climber's on_parry)

const NAME := "SpellFx"
const DrawUtil := preload("res://scripts/draw_util.gd")

var timers: Array = []  # {t, fn}
var fields: Array = []  # {pos, radius, t, tick, every, col, fn, age}
var orbs: Array = []  # {pos, vel, t, radius, col, fn, done, age}
var marks: Array = []  # {pos, t, total, col}
var lastings: Array = []  # Lasting nodes (children of this one)


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
		for l in n.lastings:
			if is_instance_valid(l):
				l.queue_free()
		n.lastings.clear()
		n.queue_redraw()


func busy() -> bool:
	return not (timers.is_empty() and fields.is_empty() and orbs.is_empty() and marks.is_empty() and lastings.is_empty())


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


# --- something that lasts: a small node with its own tick and drawing -------------------

## Something a spell leaves in the world for `seconds`: a Lasting node under
## this one, so it pauses with the fight and a new floor (clear) ends it.
## tick(node, delta) runs each frame (returning false ends it early);
## paint(node) draws with the node's draw_* calls. node.data holds the
## spell's own state; node.t counts down, node.age up, node.total is the
## whole; node.finish() ends it. opts: "z" (its draw layer: 46, the default,
## is over the darkness; 11 is on the floor), "fade_in" (fade() eases in
## too; default true) and "fade_edge" (fade()'s default edge, 0.3).
static func lasting(main, seconds: float, tick: Callable, paint: Callable, data := {}, opts := {}) -> Node2D:
	var fx = of(main)
	if fx == null:
		return null
	var n := Lasting.new()
	n.main = main
	n.t = seconds
	n.total = maxf(seconds, 0.01)
	n.tick = tick
	n.paint = paint
	n.data = data
	n.z_index = int(opts.get("z", 46))
	n.fade_in = bool(opts.get("fade_in", true))
	n.fade_edge = float(opts.get("fade_edge", 0.3))
	fx.lastings.append(n)
	fx.add_child(n)
	return n


## A lasting thing kept as a dictionary {t, age, done, node}: tick(item, delta)
## each frame (set item.done to end it; changing item.t lengthens it) and
## paint(batch, item) into a draw_util.gd Batch. `high` draws it over the
## darkness; otherwise it lies on the floor.
static func item(main, seconds: float, tick: Callable, paint: Callable, high := false) -> Dictionary:
	var it := {"t": seconds, "age": 0.0, "done": false}
	var step := func(_n, delta: float) -> bool:
		it["t"] -= delta
		it["age"] += delta
		if tick.is_valid() and not it["done"]:
			tick.call(it, delta)
		return float(it["t"]) > 0.0 and not it["done"]
	var draw := func(n):
		if paint.is_valid():
			var b = DrawUtil.Batch.new()
			paint.call(b, it)
			b.flush(n)
	it["node"] = lasting(main, INF, step, draw, {}, {"z": 46 if high else 11})
	return it


## Calls fn on `sig` until `node` leaves the tree (its Lasting ends, or a new floor).
static func listen(node: Node, sig: Signal, fn: Callable) -> void:
	if node == null or sig.is_null():
		return
	sig.connect(fn)
	node.tree_exiting.connect(func():
		if is_instance_valid(sig.get_object()) and sig.is_connected(fn):
			sig.disconnect(fn))


class Lasting extends Node2D:
	var main
	var t := 1.0
	var total := 1.0
	var age := 0.0
	var tick: Callable  # tick(node, delta); returning false ends it
	var paint: Callable  # paint(node): draws with the node's draw_* calls
	var data := {}
	var fade_in := true
	var fade_edge := 0.3

	func _ready() -> void:
		z_as_relative = false

	func _process(delta: float) -> void:
		if is_queued_for_deletion():
			return
		var fx = get_parent()
		if main == null or not is_instance_valid(main) or fx == null or not ("lastings" in fx) or not fx.lastings.has(self):
			queue_free()
			return
		age += delta
		t -= delta
		if tick.is_valid():
			var keep = tick.call(self, delta)
			if keep is bool and not keep:
				finish()
				return
		if t <= 0.0:
			finish()
			return
		queue_redraw()

	func finish() -> void:
		var fx = get_parent()
		if fx != null and "lastings" in fx:
			fx.lastings.erase(self)
		queue_free()

	## 1 while it lasts, easing to 0 over its last `edge` seconds (and in
	## over its first 0.12, unless fade_in is off).
	func fade(edge := -1.0) -> float:
		var e := fade_edge if edge < 0.0 else edge
		return (clampf(age / 0.12, 0.0, 1.0) if fade_in else 1.0) * clampf(t / e, 0.0, 1.0)

	func _draw() -> void:
		if paint.is_valid():
			paint.call(self)
