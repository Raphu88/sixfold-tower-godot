extends RefCounted
## One bond: a named power marked on one body part.
## The body part decides how it fills; the bond decides its spells.

const INFO := {
	"stormcaller": {
		"name": "Stormcaller",
		"color": Color(0.95, 0.89, 0.42),
		"spell": "Chain Lightning",
		"cost": 12.0,
		"windup": 0.45,
	},
	"windwalker": {
		"name": "Windwalker",
		"color": Color(0.75, 0.9, 1.0),
		"spell": "Gale Lift",
		"cost": 10.0,
		"windup": 0.3,
	},
}

const PART_NAMES := {"hand": "Hand", "legs": "Legs"}
const PART_FILLS := {
	"hand": "fills when you land weapon strikes",
	"legs": "fills when you roll through an attack",
}
const PART_BURN := {
	"hand": "burned: your strikes deal less damage",
	"legs": "burned: rolls cost more and travel less",
}

var id: String
var part: String
var step := 1
var essence := 0.0
var burned := false


func _init(bond_id: String, body_part: String) -> void:
	id = bond_id
	part = body_part


func display_name() -> String:
	return INFO[id]["name"]


func spell_name() -> String:
	return INFO[id]["spell"]


func color() -> Color:
	return INFO[id]["color"]


func capacity() -> float:
	return 30.0 + 10.0 * step


func cost() -> float:
	return INFO[id]["cost"]


func windup() -> float:
	return INFO[id]["windup"]


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
	match id:
		"stormcaller":
			_chain_lightning(p)
		"windwalker":
			_gale_lift(p)


# Stormcaller, step 1: lightning leaps between up to 4 foes.
# Step 3: leaps 2 more times and stuns what it hits.
func _chain_lightning(p) -> void:
	var main = p.main
	var leaps := 4 + (2 if step >= 3 else 0)
	var from: Vector2 = p.global_position
	var reach := 280.0
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
		reach = 170.0
	if hit.is_empty():
		main.fx_text(p.global_position + Vector2(0, -34), "no target", color())
		return
	main.fx_bolt(points, color())
	for pt in points:
		main.light_flash(pt, color(), 1.0, 1.4, 0.3)
	main.sfx("zap")
	main.hitstop(0.07)
	main.shake(5.0)
	for e in hit:
		if not is_instance_valid(e) or e.dead:
			continue
		e.charged = 4.0
		if step >= 3:
			e.stagger(0.4)
		e.take_hit(10.0, Vector2.ZERO)


# Windwalker, step 1: a gust lifts foes in front of you, helpless for 1.5 s.
# Step 3: the cone is much wider.
func _gale_lift(p) -> void:
	var main = p.main
	var half_arc := deg_to_rad(35.0 if step < 3 else 70.0)
	var reach := 140.0 if step < 3 else 175.0
	var origin: Vector2 = p.global_position
	var aim: Vector2 = p.aim
	main.fx_cone(origin, aim, reach, half_arc, color())
	main.light_flash(origin + aim * reach * 0.5, color(), 1.4, 0.8, 0.35)
	main.sfx("gust", 0.9)
	var lifted := 0
	for e in main.enemies():
		var to: Vector2 = e.global_position - origin
		if to.length() > reach + e.radius:
			continue
		if absf(aim.angle_to(to)) > half_arc:
			continue
		e.lift(1.5)
		e.knock = aim * 120.0
		lifted += 1
	if lifted == 0:
		main.fx_text(origin + Vector2(0, -34), "nothing to lift", color())
