extends Node
## One standard fight for weighing a mark (tests/mark_measure.gd, and the
## quick check tests/parts/mark_balance.gd): a climber with one mark on the
## hand at a step, in the floor's first room, against a standard mix of foes
## (FOES, at floor FLOOR's toughness). The climber walks to the nearest foe and
## strikes with the starting sword, and casts the mark's spells in turn as
## each is affordable and sensible (POLICY). Counts: seconds to clear the
## room, damage dealt (the weapon's blows apart from everything else: the
## mark's spells, their burns and poisons, creatures), damage taken, health
## regained, foes held helpless (stunned, airborne, asleep: seconds, and half
## for slowed or blinded), casts.
##
## Add it under the tree with `begin(main, bond_id, step)`; `done` is set when
## the room is clear, the climber falls, or LIMIT seconds pass; `result` holds
## the counts.

const FLOOR := 8
const LIMIT := 90.0
## Waves of FOES: the next comes when the last is down to WAVE_AT foes.
const WAVES := 2
const WAVE_AT := 2
## The climber's health, times the usual.
const HEALTH := 6.0
## The foes: kind and where, from the room's middle.
const FOES := [["slime", Vector2(150, -60)], ["slime", Vector2(170, 70)], ["archer", Vector2(230, -110)],
	["archer", Vector2(240, 110)], ["knight", Vector2(200, 0)], ["bat", Vector2(120, -120)], ["bat", Vector2(120, 120)]]
## How each kind of spell is cast sensibly ("near": a foe this close first;
## "buff": not again while its last cast lasts; "once": a toggle left on;
## "heat": a Flameblade's heat at least this; "hurt": your health below this
## share; "low": a foe below this share of its health, aimed at).
const POLICY := {
	"kindle": {"buff": true, "near": 140.0}, "searing": {"buff": true, "near": 140.0}, "hawkeye": {"buff": true, "near": 300.0},
	"thunderhead": {"buff": true, "near": 220.0}, "inscribe": {"buff": true, "near": 300.0}, "sigil": {"buff": true, "near": 200.0},
	"vanish": {"buff": true, "near": 160.0}, "ashfall": {"buff": true, "near": 200.0}, "veil": {"buff": true, "near": 160.0},
	"warmth": {"buff": true, "near": 200.0}, "firebirdform": {"buff": true, "near": 200.0}, "rekindle": {"buff": true, "near": 120.0},
	"desperation": {"buff": true, "near": 140.0}, "pyre": {"buff": true, "near": 140.0}, "phoenix": {"buff": true, "near": 140.0, "hurt": 0.6},
	"barrier": {"buff": true, "near": 180.0}, "absorb": {"buff": true, "near": 180.0}, "unbreakable": {"buff": true, "near": 140.0, "hurt": 0.7},
	"challenge": {"buff": true, "near": 160.0}, "bladeward": {"buff": true, "near": 120.0}, "aura": {"once": true, "near": 200.0},
	"track": {"buff": true, "near": 400.0}, "mend": {"hurt": 0.75}, "chimeraform": {"buff": true, "near": 200.0},
	"overheat": {"heat": 70.0, "near": 100.0}, "wingburst": {"near": 110.0, "aura_heat": true},
	"call": {"low": 0.25}, "grandcall": {"buff": true, "near": 300.0}, "command": {"near": 260.0},
	"ward": {"near": 120.0}, "trap": {"near": 220.0}, "neuro": {"buff": true, "near": 140.0}, "drink": {"buff": true, "near": 220.0},
	"siphon": {"near": 220.0}, "exchange": {"near": 300.0}, "transfer": {"near": 200.0}, "sinkhole": {"near": 260.0},
}

var main
var bond_id := ""
var step := 1
var cast_on := true
var done := false
var result := {}
var t := 0.0
var dealt := 0.0
var weapon := 0.0
var taken := 0.0
var healed := 0.0
var cc := 0.0
var casts := 0
var last_hp := 0.0
var turn := 0  # the next spell in turn
var last_cast := {}  # spell id -> seconds when cast
var swing_cd := 0.0
var waves_left := WAVES


## Sets up the climber and the room: one mark on the hand at `step` (today's
## side of every fork), full essence, the foes spawned. `cast`: false fights
## with the weapon alone (the passive and body still work).
func begin(m, id: String, at_step: int, cast := true) -> void:
	main = m
	bond_id = id
	step = at_step
	cast_on = cast
	var P = main.ProfileScript
	main.floor_num = FLOOR
	main.first_climb = false
	main.profile.regarded = true
	main.profile.bonds.clear()
	if id != "":
		main.profile.add_bond("hand", id, false)
		main.profile.bonds["hand"]["xp"] = float(P.STEP_XP[at_step - 1])
	main._give_bonds()
	for e in main.enemies():
		e.queue_free()
	for a in main.allies():
		a.queue_free()
	var p = main.player
	p.mouse_aim = false
	p.touch_aim = false
	p.stick_aim = false
	var c: Vector2 = main.room.get_center()
	p.global_position = c + Vector2(-140, 0)
	p.base_hp *= HEALTH  # (the climber here neither parries nor rolls: a deeper pool lets every fight finish)
	p.refresh_gear()
	p.hp = p.max_health()
	p.sta = p.max_sta
	p.aim = Vector2.RIGHT
	if p.bonds.has("hand"):
		p.bonds["hand"].essence = p.bonds["hand"].capacity()
	main.test_speed = 1.000001  # (no hit-pause: it would freeze the clock this fight is timed by)
	_wave(1.0)
	last_hp = p.hp
	if not main.on_hit.is_connected(_on_hit):
		main.on_hit.connect(_on_hit)


## A wave of FOES around the room's middle (`side`: 1 to the right of the climber, -1 to the left).
func _wave(side: float) -> void:
	waves_left -= 1
	var c: Vector2 = main.room.get_center()
	for f in FOES:
		var off: Vector2 = Vector2(f[1]) * Vector2(0.9 * side, 0.9)
		var e = main.spawn_enemy(String(f[0]), main.walkable_point(c, c + off, 14.0))
		e.aware = true
		e.notice_t = 0.0


func _on_hit(_foe, dmg: float, source: String) -> void:
	if done:
		return
	dealt += dmg
	if main.weapon_blow and source == "blow":
		weapon += dmg


func _physics_process(delta: float) -> void:
	if done or main == null:
		return
	t += delta
	var p = main.player
	# Health lost and regained.
	if p.hp < last_hp:
		taken += last_hp - p.hp
	elif p.hp > last_hp:
		healed += p.hp - last_hp
	last_hp = p.hp
	var foes: Array = main.enemies()
	for e in foes:
		if e.stun > 0.0 or e.airborne > 0.0 or e.has_meta("asleep"):
			cc += delta
		elif e.states.has("slowed") or e.states.has("unseen") or float(e.get("lost_t") if e.get("lost_t") != null else 0.0) > 0.0:
			cc += delta * 0.5
	if foes.size() <= WAVE_AT and waves_left > 0:
		_wave(-1.0 if waves_left % 2 == 0 else 1.0)
		foes = main.enemies()
	if foes.is_empty() or p.dead or t >= LIMIT:
		_finish(foes.is_empty(), p.dead)
		return
	var target = _nearest(foes, p.global_position)
	var to: Vector2 = target.global_position - p.global_position
	var dist := to.length()
	if p.cast_t <= 0.0:
		p.aim = to.normalized()
	# Walk in to sword's reach (a little short of the foe).
	_release_moves()
	if dist > 46.0 + target.radius and p.cast_t <= 0.0:
		_press_move(to.normalized())
	swing_cd -= delta
	if p.cast_t > 0.0 or p.roll_t > 0.0 or p.jump_t > 0.0:
		return
	if cast_on and p.bonds.has("hand") and p.attack_cd <= 0.0 and _try_spell(p, foes, dist):
		return
	if dist < 60.0 + target.radius and swing_cd <= 0.0 and p.attack_cd <= 0.0:
		p._try_action("attack", Vector2.ZERO)
		swing_cd = 0.12


## Casts the spell whose turn it is when it's affordable and sensible; a
## spell that isn't sensible now passes its turn on. True if a cast began.
func _try_spell(p, foes: Array, dist: float) -> bool:
	var b = p.bonds["hand"]
	var known: Array = b.spells()
	for tries in known.size():
		var i := turn % known.size()
		var sp: Dictionary = known[i]
		var why = _sensible(p, b, sp, foes, dist)
		if why == "wait":
			return false  # (its turn: save up for it)
		if why == "skip":
			turn += 1
			continue
		b.select(i)
		if b.essence < b.cost():
			return false
		var aim_at = why
		if aim_at is Vector2:
			p.aim = (aim_at - p.global_position).normalized()
		if p._try_cast("hand"):
			casts += 1
			last_cast[sp["id"]] = t
			turn += 1
			return true
		return false
	return false


## "skip", "wait", "go", or a point to aim at.
func _sensible(p, b, sp: Dictionary, foes: Array, dist: float):
	var pol: Dictionary = POLICY.get(String(sp["type"]), {"near": 260.0})
	var hp_share: float = p.hp / maxf(1.0, p.max_health())
	if pol.has("hurt") and hp_share > float(pol["hurt"]):
		return "skip"
	if pol.has("near") and dist > float(pol["near"]):
		return "skip"
	if bool(pol.get("buff", false)):
		var dur = b.spell_stat(sp, "duration")
		if last_cast.has(sp["id"]) and t - float(last_cast[sp["id"]]) < (float(dur) if dur != null else 4.0):
			return "skip"
	if bool(pol.get("once", false)) and p.aura_part != "":
		return "skip"
	if pol.has("heat") and p.heat < float(pol["heat"]):
		return "skip"
	if bool(pol.get("aura_heat", false)) and (p.aura_part == "" or p.aura_time < 3.0):
		return "skip"
	if pol.has("low"):
		for e in foes:
			if e.hp < e.max_hp * float(pol["low"]):
				return e.global_position
		if dist > 260.0:
			return "skip"
	return "go"


func _nearest(foes: Array, at: Vector2):
	var best = foes[0]
	for e in foes:
		if e.global_position.distance_to(at) < best.global_position.distance_to(at):
			best = e
	return best


func _press_move(d: Vector2) -> void:
	Input.action_press("move_right", maxf(0.0, d.x))
	Input.action_press("move_left", maxf(0.0, -d.x))
	Input.action_press("move_down", maxf(0.0, d.y))
	Input.action_press("move_up", maxf(0.0, -d.y))


func _release_moves() -> void:
	for a in ["move_left", "move_right", "move_up", "move_down"]:
		Input.action_release(a)


func _finish(cleared: bool, died: bool) -> void:
	done = true
	main.test_speed = 1.0
	_release_moves()
	result = {"mark": bond_id, "step": step, "time": t, "cleared": cleared, "died": died, "dealt": dealt, "weapon": weapon,
		"spell": maxf(0.0, dealt - weapon), "taken": taken, "healed": healed, "cc": cc, "casts": casts}
	if main.on_hit.is_connected(_on_hit):
		main.on_hit.disconnect(_on_hit)
