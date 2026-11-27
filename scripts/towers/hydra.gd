extends "res://scripts/towers/brood.gd"
## THE HYDRA WHELP: a young many-headed serpent of the Chimera's tower (kind
## "hydra"; enemy.gd SUBKINDS spawns it with this script). Each head bites in
## turn: the heads rear back together (a wedge in front, the glint), then
## bite one after another (parry the first and the rest stop). Enough damage
## CUTS OFF A HEAD (every HYDRA "head_hp" share of its health), and a few
## seconds later TWO GROW BACK from the stump, unless the wound is BURNED
## soon after the cut (it burns, or is burning when the head falls): a seared
## stump never regrows. More heads, more bites, up to HYDRA "max_heads".

static var HYDRA := {
	"heads": 2,  # heads it starts with
	"max_heads": 5,  # the most it can grow
	"head_hp": 0.25,  # every this share of its health lost cuts a head off
	"regrow": 3.5,  # seconds before two heads grow from a stump
	"sear": 3.0,  # a burn this soon after the cut sears the stump (no regrowth)
	"bite_near": 64.0, "bite_wind": 0.7, "bite_reach": 66.0, "bite_arc": 50.0,
	"bite_gap": 0.3,  # seconds between one head's bite and the next
	"bite_mult": 0.7,
}
static var HYDRA_TEXT := {"cut": "A head falls!", "regrow": "Two grow back!", "seared": "Seared: it won't grow back"}

const C_NECK := Color(0.4, 0.55, 0.36)
const C_SEAR := Color(0.25, 0.14, 0.1)
const C_RAW := Color(0.78, 0.25, 0.25)

var heads := 2
var stumps: Array = []  # {t (seconds since the cut), seared}
var cut_acc := 0.0  # damage since the last cut
var bites_left := 0
var said_t := 0.0


func setup(k: String, room) -> void:
	super.setup(k, room)
	heads = int(HYDRA["heads"])


func _act(delta: float, dir: Vector2, dist: float, p) -> void:
	var h := HYDRA
	_first_look(dist)
	said_t -= delta
	_tend_stumps(delta)
	match state:
		"wind_bite":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta):
				bites_left = heads
				state = "bites"
				state_t = 0.0
		"bites":
			velocity = Vector2.ZERO
			state_t -= delta
			if state_t <= 0.0:
				if bites_left <= 0 or heads <= 0:
					_end_attack("recover", 1.0)
					return
				bites_left -= 1
				state_t = float(h["bite_gap"])
				main.fx_cone(global_position, lunge_dir, float(h["bite_reach"]), deg_to_rad(float(h["bite_arc"])), Color(0.6, 0.85, 0.45))
				main.sfx_at(global_position, "swing_light", 1.1 + 0.08 * bites_left, -3.0)
				_strike_cone(p, lunge_dir, float(h["bite_reach"]), float(h["bite_arc"]), dmg * float(h["bite_mult"]))
		"recover", "idle":
			state_t -= delta
			velocity = dir * speed * 0.4 if dist > 70.0 else Vector2.ZERO
			if state_t <= 0.0:
				state = "chase"
		_:
			if heads > 0 and dist < float(h["bite_near"]) and main.request_attack(self):
				_begin_wind("wind_bite", float(h["bite_wind"]))
				_warn(0.9)
				main.sfx_at(global_position, "hiss", 1.1, -6.0)
			else:
				velocity = dir * speed if dist > 46.0 else Vector2.ZERO


## Stumps sear (a burn soon after the cut) or grow two heads back.
func _tend_stumps(delta: float) -> void:
	var h := HYDRA
	for st in stumps.duplicate():
		if bool(st["seared"]):
			continue
		st["t"] += delta
		if burn_t > 0.0 and float(st["t"]) <= float(h["sear"]):
			st["seared"] = true
			main.fx_text(global_position + Vector2(0, -radius - 30.0), String(HYDRA_TEXT["seared"]), Color(1.0, 0.65, 0.35))
			main.sfx_at(global_position, "burn", 0.8, -4.0)
		elif float(st["t"]) >= float(h["regrow"]):
			stumps.erase(st)
			heads = mini(int(h["max_heads"]), heads + 2)
			main.fx_text(global_position + Vector2(0, -radius - 30.0), String(HYDRA_TEXT["regrow"]), Color(0.75, 0.95, 0.55))
			main.fx_burst(global_position + face * radius, face, C_NECK, 10, 120.0)
			main.sfx_at(global_position, "hit_slime", 0.8, -2.0)


func is_attacking() -> bool:
	return state.begins_with("wind") or state == "bites"


func take_hit(amount: float, dir: Vector2, force := 140.0, heavy := false, pierce := false) -> void:
	if dead:
		return
	var before := hp
	super.take_hit(amount, dir, force, heavy, pierce)
	if dead or main == null:
		return
	cut_acc += maxf(0.0, before - hp)
	var need := max_hp * float(HYDRA["head_hp"])
	while cut_acc >= need and heads > 0:
		cut_acc -= need
		heads -= 1
		stumps.append({"t": 0.0, "seared": burn_t > 0.0})
		main.fx_text(global_position + Vector2(0, -radius - 22.0), String(HYDRA_TEXT["cut"]), Color(1.0, 0.75, 0.6))
		main.fx_burst(global_position + face * radius, face, C_RAW, 12, 160.0)
		if burn_t > 0.0:
			main.fx_text(global_position + Vector2(0, -radius - 34.0), String(HYDRA_TEXT["seared"]), Color(1.0, 0.65, 0.35))


# --- drawing ---------------------------------------------------------------------------

func _draw_own(p, t: float, f: Vector2) -> void:
	var h := HYDRA
	var s := f.orthogonal()
	var rear := _ease("rear", _wk(float(h["bite_wind"])) if state == "wind_bite" else 0.0, 12.0)
	var biting := state == "bites"
	# A squat body, a thick tail, four short legs.
	var tail := PackedVector2Array([-f * radius * 0.5, -f * radius * 1.2 + s * sin(t * 2.0) * 3.0, -f * radius * 1.8 + s * sin(t * 2.0 + 1.0) * 5.0])
	p.tube(tail, PackedFloat32Array([radius * 0.6, radius * 0.35, radius * 0.1]), color.darkened(0.1))
	_legs(p, f, [radius * 0.4, -radius * 0.4], radius * 0.55, 6.0, 3.6, color.darkened(0.35), 1.3)
	p.egg(Vector2.ZERO, Vector2(radius * 0.95, radius * 0.75), f.angle(), color)
	p.egg(Vector2(0, 2.0), Vector2(radius * 0.6, radius * 0.4), f.angle(), Color(0.78, 0.8, 0.55), false)
	# Necks fanned out in front, one head on each; stumps among them.
	var n := heads + stumps.size()
	var biter := heads - bites_left - 1  # (the head biting now)
	var hi := 0
	var si := 0
	for i in n:
		var u := 0.0 if n == 1 else (float(i) / (n - 1) - 0.5)
		var ang := u * 1.5
		var d := f.rotated(ang)
		var root := f * radius * 0.5 + s * u * radius * 0.6
		# (stumps sit between the heads)
		var is_head := hi < heads and (si >= stumps.size() or i % 2 == 0)
		if is_head:
			var lunge := 0.0
			if biting and hi == biter:
				lunge = 1.0
			var sway := sin(t * 2.5 + i * 1.3) * 2.5
			var reach := radius * (1.2 - 0.45 * rear + 0.6 * lunge)
			var head := root + d * reach + d.orthogonal() * sway + Vector2(0, -3.0 * rear)
			p.tube(PackedVector2Array([root, (root + head) * 0.5 + d.orthogonal() * sway * 0.6 + Vector2(0, -2.0), head]), PackedFloat32Array([4.4, 3.6, 3.2]), C_NECK)
			p.egg(head, Vector2(4.8, 3.6), d.angle(), C_NECK.lightened(0.08))
			var open := 1.0 if (rear > 0.5 or lunge > 0.0) else 0.2
			p.tri(head + d * 5.0 + d.orthogonal() * 1.6 * open, head + d * 2.0, head + d * 5.0 - d.orthogonal() * 1.6 * open, Palette.OUTLINE)
			_glow.circle(head + d * 1.0 + d.orthogonal() * 1.8, 0.9, Color(1.0, 0.85, 0.35), 6)
			_glow.circle(head + d * 1.0 - d.orthogonal() * 1.8, 0.9, Color(1.0, 0.85, 0.35), 6)
			hi += 1
		else:
			var seared: bool = si < stumps.size() and bool(stumps[si]["seared"])
			si += 1
			var end := root + d * radius * 0.45
			p.tube(PackedVector2Array([root, end]), PackedFloat32Array([4.4, 4.0]), C_NECK)
			p.circle(end, 2.4, C_SEAR if seared else C_RAW, 10)
			if seared:
				_glow.circle(end, 1.4, Color(1.0, 0.5, 0.2, 0.5 + 0.3 * sin(t * 6.0)), 6)


func _overlay_extra(o) -> void:
	if state == "wind_bite" or state == "bites":
		var k := _wk(float(HYDRA["bite_wind"])) if state == "wind_bite" else 1.0
		_cone(o, float(HYDRA["bite_reach"]), float(HYDRA["bite_arc"]), k, 0.1, 0.75)
