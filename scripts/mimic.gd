extends "res://scripts/enemy.gd"
## THE MIMIC: a chest that bites back (kind "mimic"; enemy.gd SUBKINDS spawns
## it with this script). Found in every tower, from floor RULES "from".
##
## While it waits it is no monster at all but one of the floor's chests
## (room_rewards.gd draws it and keeps it shut while the room's guards stand,
## like any chest), with a tell for sharp eyes: now and then its lid lifts a
## hair, as if breathing, and a pale tooth shows at the seam. Walk up to open
## it and it springs (plan below marks the chest; room_rewards.gd calls
## spring): the lid flies up, all teeth and a lolling tongue, and it hops
## after you. Its attacks keep the rhythm every monster keeps (enemy.gd):
##   bite   up close: it rears back (the wind-up), glints, and snaps shut in
##          a wedge in front of it (parry it)
##   lunge  from a few steps off: a red line shows the way, it glints, then
##          it hurls itself along the line jaws first (parry it, or step aside)
## After each it sits open (the gold ring): strike then. Slain, it spills what
## it swallowed: more essence than a chest (RULES "essence" times a rich
## chest's), often an item, often gear a rarity row up (RULES "item",
## "gear"). Words and numbers: RULES, TEXT (the Data editor).

const Items := preload("res://scripts/items.gd")
const Essence := preload("res://scripts/essence.gd")
const RoomRewards := preload("res://scripts/room_rewards.gd")
const ChestArt := preload("res://scripts/chest_art.gd")

## from: the first floor; chance: how often a floor with a chest has one;
## essence: what it spills, times a rich chest's; item / gear: the chances of
## an item and of a piece of gear (a rarity row up); bite (px) and its half
## angle; lunge: how far it reaches (px) and how fast; hop: how often it hops.
static var RULES := {"from": 3, "chance": 0.22, "essence": 1.5, "item": 0.4, "gear": 0.5,
	"bite": 64.0, "bite_arc": 50.0, "bite_wind": 0.65, "lunge": 190.0, "lunge_speed": 420.0, "lunge_wind": 0.8, "hop": 0.5, "recover": 0.9}
static var TEXT := {
	"spring": "It's a mimic!",
	"spills": "It spills what it swallowed",
}
## (tests: every chest that may be one is one)
static var forced := false

const C_WOOD := Color(0.45, 0.3, 0.18)
const C_BAND := Color(0.62, 0.58, 0.52)
const C_MAW := Color(0.18, 0.04, 0.06)
const C_TOOTH := Color(0.95, 0.92, 0.82)
const C_TONGUE := Color(0.82, 0.32, 0.38)

var looted := false
var hop_t := 0.0
var lunge_cd := 0.0


## Marks one of a floor's chests as a mimic (floors.gd, after the plan is
## built): only a chest alone in its room, so no other chest gives it away.
static func plan(p: Dictionary, floor_num: int) -> void:
	var chests: Array = p.get("chests", [])
	if chests.is_empty() or floor_num < int(RULES["from"]) or p.get("summit", false):
		return
	if randf() > float(RULES["chance"]) and not forced:
		return
	var per_room := {}
	for c in chests:
		per_room[int(c["room"])] = int(per_room.get(int(c["room"]), 0)) + 1
	var cands: Array = chests.filter(func(c): return int(per_room[int(c["room"])]) == 1)
	if cands.is_empty():
		return
	var pick: Dictionary = cands[randi() % cands.size()]
	pick["mimic"] = true


func setup(k: String, room) -> void:
	super.setup(k, room)
	state = "spring"
	state_t = 0.55
	aware = true


func _act(delta: float, dir: Vector2, dist: float, p) -> void:
	lunge_cd -= delta
	match state:
		"spring":
			# The reveal: the lid flies up; it rocks back, then comes for you.
			velocity = Vector2.ZERO
			state_t -= delta
			if state_t <= 0.0:
				state = "chase"
		"wind_bite":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta):
				var reach := float(RULES["bite"])
				main.fx_cone(global_position, lunge_dir, reach, deg_to_rad(float(RULES["bite_arc"])), Color(1.0, 0.85, 0.8))
				main.sfx_at(global_position, "swing_heavy", 0.75)
				var to: Vector2 = p.global_position - global_position
				if to.length() <= reach + p.radius and absf(lunge_dir.angle_to(to)) <= deg_to_rad(float(RULES["bite_arc"])):
					p.receive_attack(dmg, self)
				_end_attack("recover", float(RULES["recover"]))
		"wind_lunge":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = dir
			if _wind(delta, maxf(0.0, dist - (radius + p.radius)) / float(RULES["lunge_speed"])):
				state = "lunge"
				state_t = float(RULES["lunge"]) / float(RULES["lunge_speed"])
				lunge_hit = false
				main.sfx_at(global_position, "slime_hop", 0.6)
		"lunge":
			state_t -= delta
			velocity = lunge_dir * float(RULES["lunge_speed"])
			if not lunge_hit and dist < radius + p.radius + 6.0:
				lunge_hit = true
				p.receive_attack(dmg, self)
			if state_t <= 0.0:
				lunge_cd = 2.5
				_end_attack("recover", float(RULES["recover"]) + 0.2)
		"recover", "idle":
			state_t -= delta
			velocity = Vector2.ZERO
			if state_t <= 0.0:
				state = "chase"
		_:  # chase: hops after you
			if dist < float(RULES["bite"]) + 6.0 and main.request_attack(self):
				_begin_wind("wind_bite", float(RULES["bite_wind"]))
				main.sfx_at(global_position, "door_open", 1.5, -4.0)  # (its lid creaks wide)
				return
			if dist > 110.0 and dist < float(RULES["lunge"]) and lunge_cd <= 0.0 and main.clear_line(global_position, p.global_position) and main.request_attack(self):
				_begin_wind("wind_lunge", float(RULES["lunge_wind"]))
				main.sfx_at(global_position, "door_open", 1.3, -4.0)
				return
			hop_t -= delta
			if hop_t <= 0.0:
				hop_t = float(RULES["hop"])
				main.sfx_at(global_position, "step_chain", 0.7, -10.0, 0.1)
			# A hop: a burst forward, then a moment on the ground.
			var k := clampf(hop_t / float(RULES["hop"]), 0.0, 1.0)
			velocity = dir * speed * (2.2 if k > 0.55 else 0.15)
			if main.layout_on:
				var pd: Vector2 = main.path_dir(global_position, p.global_position)
				if pd != Vector2.ZERO:
					velocity = pd * velocity.length()


## What it swallowed, spilled where it fell (once).
func _exit_tree() -> void:
	if dead and not looted and main != null and is_instance_valid(main) and main.player != null:
		looted = true
		_spill()
	super._exit_tree()


func _spill() -> void:
	var at := global_position
	var R: Dictionary = RoomRewards.RULES
	var kind: String = main.tower_data().get("essence", "air")
	var amount: float = (float(R["chest_base"]) + float(R["chest_per_floor"]) * main.floor_num) * float(R["chest_rich"]) * float(RULES["essence"])
	main.gather_essence(kind, amount, at, "mimic")
	main.notices.feed(TEXT["spills"], Essence.color(kind), "essence")
	if randf() < float(RULES["item"]):
		var id := Items.random_item(not main.player.bonds.is_empty(), [], false, String(main.tower))
		main.item_drops.append({"pos": at + Vector2(18, 10), "id": id, "t": 1e9})
	if randf() < float(RULES["gear"]):
		var g = main.find_gear("", 1)
		if not g.is_empty():
			main.drop_gear(at + Vector2(-18, 10), g, true)
	main.fx_ring(at, Color(1.0, 0.85, 0.5), 60.0, 0.45, 3.0)


func _idle_state() -> String:
	return "recover"


# --- drawing ------------------------------------------------------------------------------

func _draw_own(p, t: float, f: Vector2) -> void:
	var gape := 0.0
	match state:
		"spring":
			gape = 1.0
		"wind_bite":
			gape = 0.6 + 0.4 * _wk(float(RULES["bite_wind"]))
		"wind_lunge":
			gape = 0.9
		"lunge":
			gape = 1.0
		"recover", "idle":
			gape = 0.15
		_:
			gape = 0.35 + 0.35 * clampf(hop_t / float(RULES["hop"]), 0.0, 1.0)
	var open: float = _ease("open", gape, 12.0)
	var hop := -sin(PI * clampf(1.0 - hop_t / float(RULES["hop"]), 0.0, 1.0)) * 3.0 if state == "chase" else 0.0
	var o := Vector2(0, hop)
	# Stubby legs under the box when it hops.
	if state == "chase" or state == "lunge":
		for sx in [-8.0, 8.0]:
			p.limb(o + Vector2(sx, 10), o + Vector2(sx * 1.2, 15), C_WOOD.darkened(0.35), 2.6)
	# The box: dark wood, an iron band, a lighter front.
	p.rect(Rect2(o + Vector2(-14, -3), Vector2(28, 18)), Palette.OUTLINE)
	p.rect(Rect2(o + Vector2(-12, -1), Vector2(24, 14)), C_WOOD)
	p.rect(Rect2(o + Vector2(-12, 7), Vector2(24, 6)), C_WOOD.lightened(0.08))
	p.rect(Rect2(o + Vector2(-12, 3), Vector2(24, 2)), C_BAND)
	# Its maw: dark inside, teeth top and bottom, a tongue lolling your way.
	var lift := 3.0 + open * 13.0
	p.rect(Rect2(o + Vector2(-12, -1 - lift * 0.55), Vector2(24, lift * 0.55 + 1.0)), C_MAW)
	for i in 6:
		var x := -10.0 + i * 4.0
		p.tri(o + Vector2(x, -1), o + Vector2(x + 2.0, -1 - 3.5 * (0.4 + open)), o + Vector2(x + 4.0, -1), C_TOOTH)
	if open > 0.3:
		var tip := o + Vector2(f.x * 10.0, 4.0 + absf(f.y) * 4.0 + sin(t * 9.0) * 1.5) * open
		p.quad(o + Vector2(0, -2), tip, 5.0 * open, C_TONGUE)
		p.circle(tip, 2.6 * open, C_TONGUE.lightened(0.1), 10)
	# The lid, flung up and back: its underside teeth bared, eyes glowing.
	var lid_y := -1.0 - lift
	p.rect(Rect2(o + Vector2(-14, lid_y - 7), Vector2(28, 9)), Palette.OUTLINE)
	p.rect(Rect2(o + Vector2(-12, lid_y - 5), Vector2(24, 6)), C_WOOD.lightened(0.1))
	p.rect(Rect2(o + Vector2(-12, lid_y - 1), Vector2(24, 1.5)), C_BAND)
	for i in 6:
		var x := -10.0 + i * 4.0
		p.tri(o + Vector2(x, lid_y + 1.0), o + Vector2(x + 2.0, lid_y + 1.0 + 3.5 * (0.4 + open)), o + Vector2(x + 4.0, lid_y + 1.0), C_TOOTH)
	_glow.circle(o + Vector2(-5, lid_y - 2.0), 1.6, Color(1.0, 0.35, 0.25, 0.95), 8)
	_glow.circle(o + Vector2(5, lid_y - 2.0), 1.6, Color(1.0, 0.35, 0.25, 0.95), 8)
	# The lock, hanging off it.
	p.rect(Rect2(o + Vector2(-2.5, 3.0), Vector2(5, 6)), Color(0.75, 0.25, 0.2))


## Its telegraphs over the darkness.
func _overlay_extra(o) -> void:
	var danger := Palette.DANGER
	if state == "wind_bite":
		var half := deg_to_rad(float(RULES["bite_arc"]))
		o.wedge(Vector2.ZERO, float(RULES["bite"]), lunge_dir.angle() - half, lunge_dir.angle() + half, Color(danger, 0.12 + 0.15 * _wk(float(RULES["bite_wind"]))), 10)
	elif state == "wind_lunge":
		var k := _wk(float(RULES["lunge_wind"]))
		o.quad(Vector2.ZERO, lunge_dir * float(RULES["lunge"]), radius * 1.6, Color(danger, 0.12))
		o.quad(Vector2.ZERO, lunge_dir * float(RULES["lunge"]) * k, radius * 1.6, Color(danger, 0.35))


## A mimic waiting as a chest, drawn by room_rewards.gd (the same chest,
## with its tell): `c` the chest's record, `t` the time.
## Into Batch `b` (draw_util.gd), with the other chests.
static func draw_waiting(b, c: Dictionary, pulse: float, t: float) -> void:
	var at: Vector2 = c["pos"]
	var phase := fmod(t + at.x * 0.013, 5.2)
	var breath := 0.9 if phase < 0.5 else 0.0  # (now and then the lid lifts a hair)
	ChestArt.draw(b, at, {"ready": c["open"], "lift": breath, "pulse": pulse, "t": t})
	if breath > 0.0:  # the tell: the dark of a maw at the seam, and a pale tooth
		b.rect(Rect2(at + Vector2(-11, 0.5 - breath), Vector2(22, breath + 0.6)), C_MAW)
		b.polygon(PackedVector2Array([at + Vector2(3, 0.2 - breath), at + Vector2(4.2, 2.4), at + Vector2(5.4, 0.2 - breath)]), C_TOOTH)
	if c["open"]:
		b.arc(at + Vector2(0, 4), 20.0, 0.0, TAU, 24, Color(1.0, 0.84, 0.45, 0.2 + 0.25 * pulse), 2.0)
