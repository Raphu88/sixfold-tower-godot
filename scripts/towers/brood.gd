extends "res://scripts/enemy.gd"
## THE NEWER BROOD of the Manticore's, the Firebird's and the Chimera's towers:
## what their nine newer monsters share. Each kind has its own script that
## extends this one (enemy.gd SUBKINDS):
##   the Manticore's  carrion.gd (circles high, dives on the badly hurt),
##                    basilisk.gd (its glare slows you if you face it),
##                    cairn.gd (stones that pull together, and back again);
##   the Firebird's   kindler.gd (rekindles the fallen from their ash),
##                    flamemoth.gd (a swarm drawn to light, fed by fire),
##                    salamander.gd (swims through burning floor);
##   the Chimera's    graftling.gd (steals a part, and its attack),
##                    hydra.gd (cut a head and two grow back, unless burned),
##                    leafmantis.gd (unseen among leaves, then two fast slashes).
## Here: the voices each borrows from the sound bank (VOICES, CC0 sounds the
## game already has), the Entity's first word on each (its tip, entity.gd
## TIPS, the first time one is close by), and small helpers they all use.
## Every kind's numbers and words are in its own script's tables (the Data
## editor's "The Manticore's, the Firebird's and the Chimera's newer monsters").

## [hurt, kill, warn]: the sounds each kind borrows (sound_bank.gd; its
## hurt_<kind> and kill_<kind> entries hold the same borrowed clips, and
## main.gd plays the kill one as it falls).
static var VOICES := {
	"carrion": ["hurt_bat", "kill_bat", "warn_gryphon"],
	"basilisk": ["hurt_scorpling", "kill_scorpling", "warn_scorpling"],
	"cairn": ["hurt_shellback", "kill_shellback", "warn_shellback"],
	"kindler": ["hurt_archer", "kill_archer", "warn_cinder"],
	"flamemoth": ["hurt_wisp", "kill_wisp", "warn_wisp"],
	"salamander": ["hurt_lurker", "kill_lurker", "warn_lurker"],
	"graftling": ["hurt_mongrel", "kill_mongrel", "warn_mongrel"],
	"hydra": ["hurt_thornhound", "kill_thornhound", "warn_thornhound"],
	"leafmantis": ["hurt_bloomcap", "kill_bloomcap", "warn_thornhound"],
}
## How near (px) one must come, in sight, before the Entity says its first word on it.
const TIP_NEAR := 420.0

var looked := false  # the Entity has had its first word (or it never will this floor)


func _voice(i: int) -> String:
	var v: Array = VOICES.get(kind, ["", "", ""])
	return String(v[i])


## Its warning cry as a blow winds up.
func _warn(pitch := 1.0, db := -2.0) -> void:
	if main != null:
		main.sfx(_voice(2), pitch, db)


func _hurt_voice() -> void:
	var now := Time.get_ticks_msec()
	if now < voice_at or main == null:
		return
	voice_at = now + int(randf_range(450.0, 900.0))
	main.sfx(_voice(0), 1.0, -2.0)


## The first time one is near and in sight, the Entity explains it (its tip,
## once ever: entity.gd TIPS under its kind's name).
func _first_look(dist: float) -> void:
	if looked or main == null or dist > TIP_NEAR or not aware:
		return
	looked = true
	if main.has_method("tip"):
		main.tip(kind)


## True if `p` stands inside the cone in front of it (reach px, half-angle in degrees).
func _in_cone(p, dir: Vector2, reach: float, half_deg: float) -> bool:
	var to: Vector2 = p.global_position - global_position
	return to.length() <= reach + p.radius and absf(dir.angle_to(to)) <= deg_to_rad(half_deg)


## The climber (or whoever it fights) in its blow's cone takes `amount`.
func _strike_cone(p, dir: Vector2, reach: float, half_deg: float, amount: float, unblockable := false) -> bool:
	if p == null or p.dead or not _in_cone(p, dir, reach, half_deg):
		return false
	p.receive_attack(amount, self, unblockable)
	return true


## The tower's own floor, if it has the hook (else null).
func _tf(method: String):
	if main == null:
		return null
	var tf = main.get("tower_floor")
	if tf != null and is_instance_valid(tf) and tf.has_method(method):
		return tf
	return null


## A burning patch of floor under `pos` (main.flames), or {}.
func _flame_at(pos: Vector2, margin := 4.0) -> Dictionary:
	if main == null:
		return {}
	for f in main.flames:
		if float(f["t"]) > 0.05 and pos.distance_to(f["pos"]) < float(f["r"]) - margin:
			return f
	return {}


## Its collision circle follows its size (the flamemoth grows).
func _resize(r: float) -> void:
	radius = r
	for c in get_children():
		if c is CollisionShape2D and c.shape is CircleShape2D:
			c.shape.radius = r
