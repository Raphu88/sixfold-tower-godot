extends Node2D
## THE ARENA CAR: a small arena inside a train car, where duels challenged
## in the Dining car are fought (dining.gd, arena.gd type "duel"). It's
## never on the rail: the only way in is a duel. arena.gd lays it over the
## room while the duel lasts, seen from above like a tower's floor: plank
## floorboards along the car, a ring of sawdust roped off on brass posts,
## tiered benches of onlookers along both sides, the car's end doors, and
## hanging lamps down its middle (their light is real: lighting.gd).
## Drawn in code; the colours are LOOK.

const UI := preload("res://scripts/ui.gd")
const Art := preload("res://scripts/train_art.gd")

## Its colours.
static var LOOK := {
	"boards": Color(0.36, 0.23, 0.13), "seam": Color(0.12, 0.07, 0.04), "sawdust": Color(0.62, 0.5, 0.33),
	"rope": Color(0.78, 0.66, 0.42), "bench": Color(0.3, 0.17, 0.09), "wall": Color(0.24, 0.05, 0.07),
	"lamp": Color(1.0, 0.8, 0.5),
}
## How big the ring is (its radius), how far the benches reach in from each
## side, and how many hanging lamps.
static var SIZE := {"ring": 205.0, "bench": 58.0, "lamps": 4}

var main
var rect := Rect2()
var lights: Array = []
var crowd: Array = []  # [pos, colour, hat]


func _ready() -> void:
	z_index = -9  # (over the room's floor, under the doors, traps and everyone)
	if main != null:
		rect = main.OPEN_ROOM
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for side in [0, 1]:
		for tier in 2:
			var y: float = rect.position.y + 14.0 + tier * 22.0 if side == 0 else rect.end.y - 14.0 - tier * 22.0
			var x := rect.position.x + 70.0 + rng.randf() * 20.0
			while x < rect.end.x - 70.0:
				if absf(x - rect.get_center().x) > 30.0 or tier == 1:
					crowd.append([Vector2(x, y), Color.from_hsv(rng.randf(), 0.35 + rng.randf() * 0.3, 0.35 + rng.randf() * 0.35), rng.randf() < 0.3])
				x += 30.0 + rng.randf() * 24.0
	if main != null and main.lighting != null:
		var n := int(SIZE["lamps"])
		for i in n:
			var at := Vector2(lerpf(rect.position.x, rect.end.x, (i + 0.5) / n), rect.get_center().y)
			lights.append(main.lighting.add_light(at, 260.0, LOOK["lamp"], 0.55, 0.1))
	queue_redraw()


func _exit_tree() -> void:
	if main != null and is_instance_valid(main) and main.lighting != null:
		for id in lights:
			main.lighting.remove_light(id)
	lights.clear()


func lamp_spots() -> Array:
	var out: Array = []
	var n := int(SIZE["lamps"])
	for i in n:
		out.append(Vector2(lerpf(rect.position.x, rect.end.x, (i + 0.5) / n), rect.get_center().y))
	return out


func _draw() -> void:
	if rect.size.x <= 0.0:
		return
	var b := UI.Draw.Batch.new()
	var r := rect
	# The floorboards, along the car, their joints staggered.
	Art.vgrad(b, r, LOOK["boards"].lightened(0.05), LOOK["boards"].darkened(0.15))
	var y := r.position.y
	var row := 0
	while y < r.end.y:
		var h := 26.0
		Art.vgrad(b, Rect2(r.position.x, y, r.size.x, h), LOOK["boards"].lightened(0.04 * (row % 3)), LOOK["boards"].darkened(0.08 + 0.04 * (row % 2)))
		for g in 3:
			var gy := y + 6.0 + g * 7.0 + Art.rnd(row * 7 + g) * 3.0
			b.rect(Rect2(r.position.x, gy, r.size.x, 1.0), Color(LOOK["seam"], 0.12))
		b.rect(Rect2(r.position.x, y, r.size.x, 1.6), Color(LOOK["seam"], 0.75))
		var x := r.position.x + Art.rnd(row) * 300.0
		while x < r.end.x:
			b.rect(Rect2(x, y, 1.6, h), Color(LOOK["seam"], 0.55))
			b.circle(Vector2(x + 5.0, y + 5.0), 1.2, Color(0.08, 0.06, 0.05), 6)
			b.circle(Vector2(x + 5.0, y + h - 5.0), 1.2, Color(0.08, 0.06, 0.05), 6)
			x += 320.0 + Art.rnd(row * 3 + int(x)) * 140.0
		y += h
		row += 1
	# The sawdust ring, and its rope on brass posts.
	var c := r.get_center()
	var ring: float = float(SIZE["ring"])
	b.polygon(Art.oval(c, Vector2(ring + 8.0, ring * 0.72 + 6.0), 48), Color(0, 0, 0, 0.18))
	b.polygon(Art.oval(c, Vector2(ring, ring * 0.72), 48), LOOK["sawdust"].darkened(0.1))
	b.polygon(Art.oval(c, Vector2(ring * 0.8, ring * 0.58), 40), Color(LOOK["sawdust"], 0.6))
	for k in 60:
		var p := c + Vector2((Art.rnd(k * 5) - 0.5) * ring * 1.6, (Art.rnd(k * 5 + 1) - 0.5) * ring * 1.1)
		if ((p - c) / Vector2(ring, ring * 0.72)).length() < 0.95:
			b.circle(p, 1.2 + Art.rnd(k) * 1.4, Color(0.85, 0.72, 0.5, 0.35), 6)
	var posts: Array = []
	for k in 8:
		posts.append(c + Vector2.from_angle(TAU * k / 8.0 + PI / 8.0) * Vector2(ring + 14.0, (ring + 14.0) * 0.72))
	for k in 8:
		var a: Vector2 = posts[k]
		var e: Vector2 = posts[(k + 1) % 8]
		var pts := PackedVector2Array()
		for i in 9:
			var t := i / 8.0
			pts.append(a.lerp(e, t) + Vector2(0, sin(t * PI) * 6.0))
		b.path(pts, Color(0, 0, 0, 0.4), 4.0)
		b.path(pts, LOOK["rope"], 2.4)
	for p in posts:
		b.circle(p + Vector2(2, 3), 7.0, Color(0, 0, 0, 0.3), 12)
		b.circle(p, 6.0, Art.OUTLINE, 12)
		b.circle(p, 5.0, Art.GILT.darkened(0.15), 12)
		b.circle(p - Vector2(1.5, 1.5), 2.0, Art.GILT_HI, 8)
	# The benches along both sides, onlookers on them.
	var bench: float = float(SIZE["bench"])
	for side in [0, 1]:
		var br := Rect2(r.position.x, r.position.y, r.size.x, bench) if side == 0 else Rect2(r.position.x, r.end.y - bench, r.size.x, bench)
		Art.vgrad(b, br, LOOK["wall"].darkened(0.2) if side == 0 else LOOK["bench"], LOOK["bench"] if side == 0 else LOOK["wall"].darkened(0.2))
		for tier in 2:
			var ty: float = br.position.y + 10.0 + tier * 22.0 if side == 0 else br.end.y - 18.0 - tier * 22.0
			var plank := Rect2(br.position.x, ty, br.size.x, 9.0)
			b.rect(plank.grow(1.0), Art.OUTLINE)
			Art.vgrad(b, plank, LOOK["bench"].lightened(0.2), LOOK["bench"].darkened(0.2))
		var lip := Rect2(br.position.x, br.end.y - 3.0, br.size.x, 3.0) if side == 0 else Rect2(br.position.x, br.position.y, br.size.x, 3.0)
		Art.bar(b, lip)
	for p in crowd:
		var at: Vector2 = p[0]
		var col: Color = p[1]
		b.polygon(Art.oval(at + Vector2(0, 5), Vector2(10.0, 6.0), 12), Art.OUTLINE)
		b.polygon(Art.oval(at + Vector2(0, 5), Vector2(9.0, 5.0), 12), col)
		b.circle(at, 5.5, Art.OUTLINE, 12)
		b.circle(at, 4.6, Color(0.8, 0.62, 0.48), 12)
		if p[2]:
			b.circle(at, 5.2, col.darkened(0.5), 12)
	# The car's end doors, brass-framed.
	for side in [0, 1]:
		var dx := r.position.x + 2.0 if side == 0 else r.end.x - 20.0
		var door := Rect2(dx, c.y - 34.0, 18.0, 68.0)
		b.rect(door.grow(2.0), Art.OUTLINE)
		b.rect(door.grow(1.0), Art.GILT.darkened(0.3))
		Art.vgrad(b, door, Art.MAHOGANY.lightened(0.05), Art.MAHOGANY.darkened(0.3))
		b.circle(Vector2(door.get_center().x, c.y), 2.2, Art.GILT, 8)
	# The hanging lamps (seen from above: a shade round a glowing bulb).
	for at in lamp_spots():
		Art.light(b, at, Vector2(40.0, 30.0), Color(LOOK["lamp"], 0.08))
		b.circle(at, 9.0, Art.OUTLINE, 14)
		b.circle(at, 8.0, Art.GILT.darkened(0.25), 14)
		b.circle(at, 4.0, LOOK["lamp"], 10)
	b.flush(self)
