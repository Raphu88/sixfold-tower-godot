extends "res://scripts/enemy.gd"
## THE DRIFTBELL (kind "driftbell"; enemy.gd SUBKINDS spawns it with this
## script): the Kraken's tower's drifting jellyfish. It floats slowly after
## you (over deep water too), bobbing from side to side, and leaves a trail
## of beads behind it (foes/marks.gd "trail"). Where the trail lies on water it
## crackles: touch it and it stings and leaves you charged (on dry stone the
## beads fade at once, harmless). Come close and its tendrils light up (the
## warning ring), it glints, and it sparks all round it: that can't be parried,
## so step back or roll through. After a spark it drifts, open. Light on
## health: a ranged shot or a quick blow between sparks. Words and numbers:
## RULES, TEXT.

const Marks := preload("res://scripts/foes/marks.gd")

static var RULES := {
	"drop": 0.35,  # seconds between beads of its trail
	"trail_t": 3.5,  # how long a bead on water crackles
	"trail_dry": 0.8,  # ...and one on dry stone lasts
	"bead": 16.0,  # a bead's radius
	"zap": 3.0,  # what touching a crackling bead costs
	"zap_cd": 0.6,  # ...at most this often
	"near": 62.0,  # it sparks when you come this near
	"spark": 50.0,  # how far its spark reaches
	"spark_wind": 0.6,
	"recover": 1.2,
}
static var TEXT := {}

const C_BELL := Color(0.62, 0.8, 0.98)
const C_CORE := Color(0.95, 0.95, 0.6)

var drop_t := 0.0
var trail = null  # its marks node (foes/marks.gd)
var _told := false


func setup(k: String, room) -> void:
	super.setup(k, room)
	state = "drift"


func _act(delta: float, dir: Vector2, dist: float, p) -> void:
	if not _told and dist < 360.0:
		_told = true
		main.tip("driftbell")
	_lay_trail(delta)
	match state:
		"wind_spark":
			velocity = Vector2.ZERO
			if _wind(delta):
				var reach := float(RULES["spark"])
				main.fx_ring(global_position, C_CORE, reach, 0.3, 3.0)
				for i in 6:
					main.fx_bolt([global_position, global_position + Vector2.from_angle(TAU * i / 6.0 + randf()) * reach], C_CORE)
				main.sfx("zap", 1.2)
				main.light_flash(global_position, C_BELL, 1.2, 1.4, 0.25)
				if dist < reach + p.radius and p.iframes <= 0.0:
					var before: float = p.hp
					p.receive_attack(dmg, self, true)
					if p.hp < before:
						Reactions.apply(main, p, "charged", Reactions.climber_seconds("charged"), self)
				_end_attack("recover", float(RULES["recover"]))
		"recover", "idle":
			state_t -= delta
			velocity = -dir * speed * 0.4
			if state_t <= 0.0:
				state = "drift"
		_:  # drift: slowly after you, bobbing side to side
			if dist < float(RULES["near"]) and main.request_attack(self):
				_begin_wind("wind_spark", float(RULES["spark_wind"]))
				main.sfx("charge", 1.6, -6.0)
			else:
				var sway := dir.orthogonal() * sin(Time.get_ticks_msec() * 0.0015 + get_instance_id()) * 0.7
				velocity = (dir + sway).normalized() * speed


## Beads behind it as it drifts: crackling on water, faint on stone.
func _lay_trail(delta: float) -> void:
	drop_t -= delta
	if drop_t > 0.0:
		return
	drop_t = float(RULES["drop"])
	if trail == null or not is_instance_valid(trail):
		trail = Marks.make(main, "trail", RULES, self)
	var wet: bool = main.in_water(global_position)
	var life := float(RULES["trail_t"]) if wet else float(RULES["trail_dry"])
	trail.beads.append({"pos": global_position, "t": life, "max": life, "wet": wet})


func _idle_state() -> String:
	return "recover"


# --- drawing ------------------------------------------------------------------------

## A see-through bell seen from above, floating a little off the floor: a
## glowing core, a frilled rim that pulses, and tendrils trailing behind it;
## the tendrils light up as it winds up to spark.
func _draw_own(p, t: float, _f: Vector2) -> void:
	var o := Vector2(0, -10.0 + sin(t * 2.2) * 2.5)
	var pulse := 1.0 + 0.08 * sin(t * 3.0)
	var spark := _ease("spark", _wk(float(RULES["spark_wind"])) if state == "wind_spark" else 0.0, 14.0)
	# Tendrils trailing behind (opposite to where it drifts).
	var back := -velocity.normalized() if velocity.length() > 5.0 else Vector2.DOWN
	for i in 5:
		var off := back.orthogonal() * (float(i) - 2.0) * 3.0
		var pts := PackedVector2Array()
		for j in 4:
			pts.append(o + off + back * (4.0 + j * 5.0) + back.orthogonal() * sin(t * 4.0 + i + j * 0.8) * 2.0 * j * 0.5)
		p.tube(pts, PackedFloat32Array([1.8, 1.5, 1.2, 0.8]), C_BELL.darkened(0.25), true, false)
		if spark > 0.05:
			for q in pts:
				_glow.circle(q, 1.4, Color(C_CORE, 0.9 * spark), 6)
	# The bell: translucent dome and a frilled rim.
	var r := radius * pulse
	p.circle(o, r + 1.6, Color(Palette.OUTLINE, 0.8), 22)
	p.circle(o, r, Color(C_BELL.darkened(0.2), 0.85), 22)
	p.circle(o + Vector2(-r * 0.15, -r * 0.18), r * 0.78, Color(C_BELL, 0.8), 20)
	for i in 10:
		var a := TAU * float(i) / 10.0 + t * 0.4
		p.circle(o + Vector2.from_angle(a) * r * 0.95, 2.0, Color(C_BELL.lightened(0.2), 0.75), 8)
	p.circle(o + Vector2(-r * 0.35, -r * 0.4), r * 0.25, Color(1, 1, 1, 0.45), 10)
	# The core glows (brighter as it winds up).
	_glow.circle(o, r * 0.42, Color(C_CORE, 0.5 + 0.5 * spark), 14)
	_glow.circle(o, r * 0.8, Color(C_BELL, 0.12 + 0.2 * spark), 18)


func _overlay_extra(o) -> void:
	if state == "wind_spark":
		var k := _wk(float(RULES["spark_wind"]))
		var reach := float(RULES["spark"])
		o.circle(Vector2.ZERO, reach, Color(Palette.DANGER, 0.08 + 0.12 * k), 36)
		o.arc(Vector2.ZERO, reach, 0.0, TAU, 2.0, Color(Palette.DANGER, 0.55), 36)
		o.arc(Vector2.ZERO, reach * k, 0.0, TAU, 1.5, Color(Palette.DANGER, 0.75), 30)
