extends RefCounted
## One bond: a named power marked on one body part.
## The body part decides how it fills; the bond's data (bonds.gd) decides
## its spell and how that spell grows with each step.

const Bonds := preload("res://scripts/bonds.gd")
const PART_NAMES := Bonds.PART_NAMES
const PART_FILLS := Bonds.PART_FILLS
const PART_BURN := Bonds.PART_BURN
const MAX_STEP := 5

var id: String
var part: String
var step := 1
var essence := 0.0
var burned := false


func _init(bond_id: String, body_part: String) -> void:
	id = bond_id
	part = body_part


func data() -> Dictionary:
	return Bonds.BONDS[id]


## A spell value at the current step: the latest step at or below this one
## that sets it wins.
func stat(key: String):
	var steps: Dictionary = data()["steps"]
	var value = null
	for s in range(1, step + 1):
		if steps.has(s) and steps[s].has(key):
			value = steps[s][key]
	return value


func display_name() -> String:
	return data()["name"]


func spell_name() -> String:
	return data()["spell"]


func color() -> Color:
	return data()["color"]


func capacity() -> float:
	return 30.0 + 10.0 * step


func cost() -> float:
	return stat("cost")


func windup() -> float:
	return stat("windup")


## What reaching `new_step` adds, in a few words (empty if nothing to say).
func step_note(new_step: int) -> String:
	return Bonds.STEP_NOTES.get(id, {}).get(new_step, "")


func fill(amount: float) -> void:
	essence = minf(capacity(), essence + amount)


## Pays for a cast. Returns true if the body part was burned by overdrawing.
func pay() -> bool:
	if essence >= cost():
		essence -= cost()
		return false
	essence = 0.0
	burned = true
	return true


func cast(p) -> void:
	match data()["type"]:
		"chain":
			_chain(p)
		"lift":
			_lift(p)


# Lightning leaps from you to the nearest foe, then foe to foe.
func _chain(p) -> void:
	var main = p.main
	var leaps: int = stat("leaps")
	var from: Vector2 = p.global_position
	var reach: float = stat("reach")
	var hit: Array = []
	var points: Array = [from]
	for i in leaps:
		var best = null
		var best_d := reach
		for e in main.enemies():
			if e in hit:
				continue
			var d: float = from.distance_to(e.global_position)
			if d < best_d:
				best_d = d
				best = e
		if best == null:
			break
		hit.append(best)
		points.append(best.global_position)
		from = best.global_position
		reach = stat("hop")
	if hit.is_empty():
		main.fx_text(p.global_position + Vector2(0, -34), "no target", color())
		return
	main.fx_bolt(points, color())
	for pt in points:
		main.light_flash(pt, color(), 1.0, 1.4, 0.3)
	main.sfx("zap")
	main.hitstop(0.07)
	main.shake(5.0)
	var stun: float = stat("stun")
	for e in hit:
		if not is_instance_valid(e) or e.dead:
			continue
		e.charged = 4.0
		if stun > 0.0:
			e.stagger(stun)
		e.take_hit(stat("damage"), Vector2.ZERO)


# A gust in front of you throws foes into the air, helpless.
func _lift(p) -> void:
	var main = p.main
	var half_arc := deg_to_rad(stat("arc"))
	var reach: float = stat("reach")
	var origin: Vector2 = p.global_position
	var aim: Vector2 = p.aim
	main.fx_cone(origin, aim, reach, half_arc, color())
	main.light_flash(origin + aim * reach * 0.5, color(), 1.4, 0.8, 0.35)
	main.sfx("gust", 0.9)
	var lifted := 0
	var dmg: float = stat("damage")
	for e in main.enemies():
		var to: Vector2 = e.global_position - origin
		if to.length() > reach + e.radius:
			continue
		if absf(aim.angle_to(to)) > half_arc:
			continue
		e.lift(stat("lift"))
		e.knock = aim * 120.0
		if dmg > 0.0:
			e.take_hit(dmg, aim, 60.0)
		lifted += 1
	if lifted == 0:
		main.fx_text(origin + Vector2(0, -34), "nothing to lift", color())
