extends "res://scripts/enemy.gd"
## THE SLAGWORM (kind "slagworm"; enemy.gd SUBKINDS spawns it with this
## script): the Wyvern's molten slug. It crawls after you, slowly, and the
## slag it leaves hardens behind it into a low, glowing wall (foes/marks.gd
## "slag"). Standing on hot slag burns, as burning floor does; a jump carries
## you over and a roll through is free. The slag cools dark and crumbles away
## after a while, and it never blocks anyone: it's only low and hot. It lays
## none near the stair or in a narrow way. Up close it rears and bites (a
## wedge, a glint: parry it); a bite that lands sets you burning. Words and
## numbers: RULES, TEXT.

const Marks := preload("res://scripts/foes/marks.gd")

static var RULES := {
	"drop": 18.0,  # px it crawls between beads of slag
	"bead": 11.0,  # a bead's radius
	"hot": 6.0,  # seconds a bead stays hot
	"crumble": 2.0,  # ...then it cools and crumbles over this long
	"most": 30.0,  # beads of its slag at once, at most
	"clear": 80.0,  # no slag this near the stair
	"narrow": 30.0,  # nor where walls stand this near on both sides
	"bite": 52.0,
	"bite_arc": 55.0,
	"bite_wind": 0.6,
	"recover": 1.0,
}
static var TEXT := {}

const C_CRUST := Color(0.3, 0.22, 0.2)
const C_MOLTEN := Color(1.0, 0.55, 0.2)

var slag = null  # its marks node
var _crawled := 0.0
var _last_pos := Vector2.INF
var _told := false


func setup(k: String, room) -> void:
	super.setup(k, room)
	state = "recover"


func _act(delta: float, dir: Vector2, dist: float, p) -> void:
	if not _told and dist < 360.0:
		_told = true
		main.tip("slagworm")
	_lay_slag()
	match state:
		"wind_bite":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta):
				var reach := float(RULES["bite"])
				var arc := deg_to_rad(float(RULES["bite_arc"]))
				main.fx_cone(global_position, lunge_dir, reach + 6.0, arc, C_MOLTEN)
				main.sfx_at(global_position, "hit_slime", 0.6)
				var to: Vector2 = p.global_position - global_position
				if to.length() <= reach + p.radius and absf(lunge_dir.angle_to(to)) <= arc:
					p.receive_attack(dmg, self)
				_end_attack("recover", float(RULES["recover"]))
		"recover", "idle":
			state_t -= delta
			velocity = Vector2.ZERO
			if state_t <= 0.0:
				state = "crawl"
		_:
			if dist < float(RULES["bite"]) + 6.0 and main.request_attack(self):
				lunge_dir = dir
				_begin_wind("wind_bite", float(RULES["bite_wind"]))
				main.sfx_at(global_position, "hiss", 0.7, -4.0)
			else:
				velocity = dir * speed


## A bead of slag every RULES "drop" px it crawls, where it may lie.
func _lay_slag() -> void:
	if _last_pos == Vector2.INF:
		_last_pos = global_position
	_crawled += global_position.distance_to(_last_pos)
	_last_pos = global_position
	if _crawled < float(RULES["drop"]):
		return
	_crawled = 0.0
	if not may_lay(global_position):
		return
	if slag == null or not is_instance_valid(slag):
		slag = Marks.make(main, "slag", RULES, self)
	if slag.beads.size() >= int(RULES["most"]):
		slag.beads.pop_front()
	var life := float(RULES["hot"]) + float(RULES["crumble"])
	slag.beads.append({"pos": global_position - face * radius * 0.6, "t": life, "max": life})


## Slag never lies near the stair, nor in a narrow way (a corridor, a doorway).
func may_lay(pos: Vector2) -> bool:
	if main.stair_pos != Vector2.ZERO and pos.distance_to(main.stair_pos) < float(RULES["clear"]):
		return false
	if main.layout_on:
		var n := float(RULES["narrow"])
		for pair in [[Vector2(n, 0), Vector2(-n, 0)], [Vector2(0, n), Vector2(0, -n)]]:
			if main.is_solid(pos + pair[0]) and main.is_solid(pos + pair[1]):
				return false
	return true


func _idle_state() -> String:
	return "recover"


# --- drawing ------------------------------------------------------------------------

## A fat slug of half-cooled slag seen from above: a dark crust cracked over a
## molten body that glows through, a blunt head with two stalk eyes, drips of
## slag falling behind it; it rears, its maw glowing, before it bites.
func _draw_own(p, t: float, f: Vector2) -> void:
	var s := f.orthogonal()
	var rear := _ease("rear", _wk(float(RULES["bite_wind"])) if state == "wind_bite" else 0.0, 12.0)
	var crawl := sin(_stride * 1.5) * _move
	# Segments from the tail up to the head.
	var segs := 4
	for i in segs:
		var k := float(i) / float(segs - 1)
		var at: Vector2 = -f * (12.0 - k * 14.0) + s * sin(_stride * 1.5 + i) * 1.5 * _move
		var r := radius * (0.55 + 0.35 * sin(k * PI * 0.9 + 0.3)) * (1.0 + 0.06 * crawl * (1.0 if i % 2 == 0 else -1.0))
		p.ball(at, r, C_CRUST)
		# Molten cracks across the crust.
		_glow.quad(at - s * r * 0.6, at + s * r * 0.5 + f * 1.5, 1.2, Color(C_MOLTEN, 0.8))
		_glow.circle(at + Vector2(-r * 0.2, -r * 0.2), r * 0.35, Color(C_MOLTEN, 0.35), 10)
	var head: Vector2 = f * (4.0 + 4.0 * rear)
	p.ball(head, radius * 0.6, C_CRUST.lightened(0.08))
	# Stalk eyes.
	for sgn in [-1.0, 1.0]:
		var tip: Vector2 = head + f * 5.0 + s * sgn * 4.5
		p.limb(head + s * sgn * 2.5, tip, C_CRUST, 1.6)
		p.circle(tip, 1.6, Color(1.0, 0.85, 0.5), 8)
	# Its maw glows as it rears to bite.
	_glow.circle(head + f * radius * 0.45, 2.0 + 2.5 * rear, Color(1.0, 0.7, 0.3, 0.5 + 0.5 * rear), 10)
	# Drips of slag behind it.
	for i in 2:
		var ph := fmod(t * 0.9 + i * 0.5, 1.0)
		_glow.circle(-f * (14.0 + ph * 6.0) + s * (float(i) - 0.5) * 4.0, 1.5 * (1.0 - ph), Color(C_MOLTEN, 0.7 * (1.0 - ph)), 6)


func _overlay_extra(o) -> void:
	if state == "wind_bite":
		var half := deg_to_rad(float(RULES["bite_arc"]))
		o.wedge(Vector2.ZERO, float(RULES["bite"]), lunge_dir.angle() - half, lunge_dir.angle() + half, Color(Palette.DANGER, 0.12 + 0.15 * _wk(float(RULES["bite_wind"]))), 12)
