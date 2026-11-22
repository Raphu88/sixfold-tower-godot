extends RefCounted
## What fills each body part toward its next mark (scripts/part_soak.gd).
##
## THE MODEL. A floor of each way of playing (STYLES: what a climber does on
## an average floor) runs through the game's own table and fading
## (PartSoak.floor_soak). Each style fills its own part first; the typical
## climber (strikes and shots by the dozen, some parries and rolls, plenty
## of hits taken, few jumps), varied climber to climber (CLIMBERS of them,
## each leaning their own way, every floor a little different), has any of
## the six parts take the first mark (none above MOST of the time, none
## below LEAST), not mostly the heart, brow or back as it was (OLD). The
## time to the next mark stays where it was: the leading unmarked part's
## share times profile.gd SOAK_RATE, against the old table's at the old rate.
## tests/progression_model.gd's STYLE is this typical floor (out of 100).
##
## IN THE GAME. Fading and the stair; legs soaking only for a roll or jump
## that carries you clear of a coming blow (never at nothing), once per
## LEGS_GAP; the low blows (a knight's leg sweep, a shellback's slam) leapt
## over or landing. Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const PartSoak := preload("res://scripts/part_soak.gd")
const Profile := preload("res://scripts/profile.gd")
const Model := preload("res://tests/progression_model.gd")
const Enemy := preload("res://scripts/enemy.gd")

## A floor of each way of playing: action -> how many.
const STYLES := {
	"typical": {"strike": 22, "shot": 10, "cleave": 4, "multi_cast": 1, "backstab": 3, "finisher": 6, "hit_taken": 7, "parry": 3, "perfect_parry": 1, "roll_through": 1.5, "roll_clear": 5, "jump_clear": 0.5},
	"archer": {"strike": 4, "shot": 36, "cleave": 1, "multi_cast": 1, "backstab": 1, "finisher": 6, "hit_taken": 4, "parry": 1, "roll_through": 1, "roll_clear": 6, "jump_clear": 0.5},
	"dodger": {"strike": 18, "shot": 6, "cleave": 3, "multi_cast": 1, "backstab": 3, "finisher": 6, "hit_taken": 3, "parry": 1, "perfect_parry": 0.5, "roll_through": 4, "roll_clear": 10, "jump_clear": 3},
	"tank": {"strike": 28, "shot": 2, "cleave": 5, "multi_cast": 1, "backstab": 1, "finisher": 6, "hit_taken": 16, "parry": 1.5, "perfect_parry": 0.5, "roll_through": 0.5, "roll_clear": 1.5},
	"backstabber": {"strike": 20, "shot": 2, "cleave": 2, "multi_cast": 0.5, "backstab": 12, "finisher": 6, "hit_taken": 5, "parry": 1, "perfect_parry": 0.5, "roll_through": 2, "roll_clear": 5, "jump_clear": 0.5},
	"parrier": {"strike": 20, "shot": 2, "cleave": 3, "multi_cast": 0.5, "backstab": 3, "finisher": 6, "hit_taken": 4, "parry": 8, "perfect_parry": 5, "roll_through": 0.5, "roll_clear": 2, "jump_clear": 0.2},
	"cleaver": {"strike": 24, "shot": 2, "cleave": 10, "multi_cast": 4, "backstab": 2, "finisher": 6, "hit_taken": 6, "parry": 2, "perfect_parry": 0.5, "roll_through": 1, "roll_clear": 3, "jump_clear": 0.3},
}
## The part each style fills first.
const FIRST := {"archer": "hand", "dodger": "legs", "tank": "heart", "backstabber": "back", "parrier": "brow", "cleaver": "throat"}
## The old amounts (before part_soak.gd), with no fading and no leg soak but
## a roll through, at the old SOAK_RATE.
const OLD := {"strike": ["hand", 0.5], "shot": ["hand", 0.5], "cleave": ["throat", 2.0], "multi_cast": ["throat", 2.0], "backstab": ["back", 3.0], "finisher": ["back", 2.0],
	"hit_taken": ["heart", 4.0], "parry": ["brow", 6.0], "perfect_parry": ["brow", 9.0], "roll_through": ["legs", 4.0], "roll_clear": ["legs", 0.0], "jump_clear": ["legs", 0.0]}
const OLD_RATE := 1.2
const FLOORS := 5  # (the first climb's floors before the Regard)
const CLIMBERS := 600
const LEAN := 0.45  # how far one climber leans from the typical (log-normal)
const WOBBLE := 0.3  # and one floor from the next
## [least, most] of the typical climbers whose first mark lands on a part.
const LEAST := 0.08
const MOST := 0.3
## The next mark's pace (lead share x SOAK_RATE) against the old: [least, most].
const PACE := [0.85, 1.2]

var t


func run(smoke) -> void:
	t = smoke
	print("what fills each body part toward a mark (part_soak.gd)")
	_model()
	await _in_game()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


static func _top(d: Dictionary, skip := "") -> String:
	var best := ""
	for k in d:
		if k != skip and (best == "" or float(d[k]) > float(d[best])):
			best = k
	return best


static func _old_floor(counts: Dictionary) -> Dictionary:
	var out := {}
	for a in counts:
		var row: Array = OLD[a]
		out[row[0]] = float(out.get(row[0], 0.0)) + float(row[1]) * float(counts[a])
	return out


static func _share(d: Dictionary, part: String) -> float:
	var total := 0.0
	for k in d:
		total += float(d[k])
	return float(d.get(part, 0.0)) / maxf(total, 0.001)


func _model() -> void:
	# Every action named in the table has a part, a soak and a fill.
	var bad: Array = []
	for a in PartSoak.SOAK:
		var r: Dictionary = PartSoak.SOAK[a]
		if not String(r.get("part", "")) in ["hand", "legs", "heart", "brow", "throat", "back"] or float(r.get("soak", 0.0)) <= 0.0 or float(r.get("fill", 0.0)) <= 0.0:
			bad.append(a)
	_check(bad.is_empty() and PartSoak.SOAK.size() >= 6, "every action in the table fills a body part (bad: %s)" % [bad])
	var covered := {}
	for a in PartSoak.SOAK:
		covered[PartSoak.part_of(a)] = true
	_check(covered.size() == 6 and PartSoak.SOAK.has("jump_clear") and PartSoak.SOAK.has("roll_clear"), "all six parts have a source, jumping and rolling clear among them")
	# Fading: the n-th unit is worth 1 / (1 + n / h) of the first.
	var worn := {}
	var a1 := PartSoak.take(worn, "parry")
	var a2 := PartSoak.take(worn, "parry")
	var h := float(PartSoak.FADE.get("parry", PartSoak.FADE["default"]))
	_check(is_equal_approx(a1, float(PartSoak.SOAK["parry"]["soak"])) and is_equal_approx(a2, a1 / (1.0 + 1.0 / h)), "the same thing again on one floor soaks less (%.2f, then %.2f)" % [a1, a2])
	var worn2 := {"parry": 1.0}
	_check(is_equal_approx(PartSoak.take(worn2, "hit_taken"), float(PartSoak.SOAK["hit_taken"]["soak"])), "...but something else soaks in full")
	var spam := PartSoak.floor_soak({"strike": 60})
	var mixed := PartSoak.floor_soak({"strike": 20, "parry": 6, "roll_clear": 6, "hit_taken": 6, "backstab": 6, "cleave": 6})
	var spam_t := 0.0
	var mixed_t := 0.0
	for k in spam:
		spam_t += float(spam[k])
	for k in mixed:
		mixed_t += float(mixed[k])
	_check(mixed_t > spam_t * 1.5, "sixty strikes soak less than half as much as sixty mixed actions (%.0f against %.0f)" % [spam_t, mixed_t])
	# Each style fills its own part first.
	for style in FIRST:
		var per: Dictionary = PartSoak.floor_soak(STYLES[style])
		var top := _top(per)
		var lines := []
		for k in per:
			lines.append("%s %.0f" % [k, per[k]])
		_check(top == FIRST[style], "%s: the %s fills first (%s)" % [style, FIRST[style], ", ".join(lines)])
	var typ: Dictionary = PartSoak.floor_soak(STYLES["typical"])
	var tl := []
	for k in typ:
		tl.append("%s %.1f" % [k, typ[k]])
	print("    typical floor: ", ", ".join(tl))
	# The typical climber, varied: who takes the first mark.
	var rng := RandomNumberGenerator.new()
	rng.seed = 6666
	var first := {}
	var first_old := {}
	var lead := 0.0
	var lead_old := 0.0
	for i in CLIMBERS:
		var lean := {}
		for a in STYLES["typical"]:
			lean[a] = exp(rng.randfn(0.0, LEAN))
		var tot := {}
		var tot_old := {}
		for f in FLOORS:
			var c := {}
			for a in STYLES["typical"]:
				c[a] = maxf(0.0, float(STYLES["typical"][a]) * float(lean[a]) * exp(rng.randfn(0.0, WOBBLE)))
			var nf: Dictionary = PartSoak.floor_soak(c)
			for k in nf:
				tot[k] = float(tot.get(k, 0.0)) + float(nf[k])
			var of := _old_floor(c)
			for k in of:
				tot_old[k] = float(tot_old.get(k, 0.0)) + float(of[k])
		var b := _top(tot)
		first[b] = int(first.get(b, 0)) + 1
		lead += _share(tot, _top(tot, b)) / float(CLIMBERS)  # (the next mark: the leading part still unmarked)
		var bo := _top(tot_old)
		first_old[bo] = int(first_old.get(bo, 0)) + 1
		lead_old += _share(tot_old, _top(tot_old, bo)) / float(CLIMBERS)
	var spread := []
	var spread_old := []
	var even := true
	for part in ["hand", "legs", "heart", "brow", "throat", "back"]:
		var k := float(first.get(part, 0)) / float(CLIMBERS)
		spread.append("%s %d%%" % [part, roundi(k * 100.0)])
		spread_old.append("%s %d%%" % [part, roundi(float(first_old.get(part, 0)) / float(CLIMBERS) * 100.0)])
		even = even and k >= LEAST and k <= MOST
	print("    the typical climber's first mark, now: ", ", ".join(spread))
	print("    ...and with the old amounts: ", ", ".join(spread_old))
	_check(even, "a typical climber's first mark lands on any part, each %d%% to %d%% of the time (%s)" % [roundi(LEAST * 100.0), roundi(MOST * 100.0), ", ".join(spread)])
	var hbb := float(int(first.get("heart", 0)) + int(first.get("brow", 0)) + int(first.get("back", 0))) / float(CLIMBERS)
	_check(hbb <= 0.6, "the spammer isn't locked into the heart, brow or back (%d%% of them, was %d%%)" % [roundi(hbb * 100.0), roundi(float(int(first_old.get("heart", 0)) + int(first_old.get("brow", 0)) + int(first_old.get("back", 0))) / float(CLIMBERS) * 100.0)])
	# Slow growth: the next mark comes about as fast as before.
	var pace := (lead * Profile.SOAK_RATE) / maxf(lead_old * OLD_RATE, 0.001)
	_check(pace >= PACE[0] and pace <= PACE[1], "the next mark comes about as fast as before (%.2f times: the leading part's share %.3f x soak rate %.2f, was %.3f x %.2f)" % [pace, lead, Profile.SOAK_RATE, lead_old, OLD_RATE])
	# The next mark forms in one place at a time (profile.gd FORMING_OTHERS).
	var pr = Profile.new()
	pr.add_bond("hand", "stormcaller", false)
	pr.settle_soak({"legs": 300.0, "back": 280.0, "heart": 10.0})
	var cap := Profile.NEW_MARK_SOAK * Profile.FORMING_OTHERS
	_check(is_equal_approx(float(pr.soak["legs"]), Profile.NEW_MARK_SOAK) and is_equal_approx(float(pr.soak["back"]), cap) and is_equal_approx(float(pr.soak["heart"]), 10.0),
		"only the fullest part fills all the way; the others stop at %d%% (%s)" % [roundi(Profile.FORMING_OTHERS * 100.0), pr.soak])
	pr.soak["back"] = cap + 20.0  # (a tincture steered it past)
	pr.settle_soak({"back": 5.0, "heart": 5.0})
	_check(is_equal_approx(float(pr.soak["back"]), cap + 20.0) and pr.soak_leader() == "legs", "...and a part past that keeps what it holds")
	# The marks after the second stay apart (the progression model's typical climber).
	var r: Dictionary = Model.run("typical", 30)
	var at: Array = r["marks_at"]
	var apart := at.size() >= 2
	for i in range(1, at.size()):
		apart = apart and int(at[i]) - int(at[i - 1]) >= 3
	_check(apart and int(r["second"]) >= 6, "new marks come apart, not one a summit (climbs %s)" % [at])
	# The progression model's typical style is this floor.
	var total := 0.0
	for k in typ:
		total += float(typ[k])
	var off := 0.0
	for k in typ:
		off = maxf(off, absf(float(typ[k]) / total * 100.0 - float(Model.STYLE.get(k, 0.0))))
	_check(off <= 1.5, "tests/progression_model.gd's STYLE is the typical floor (off by %.1f at most)" % off)


func _in_game() -> void:
	await t._fresh_main()
	var main = t.main
	var p = main.player
	for e in main.enemies():
		if is_instance_valid(e):
			e.queue_free()
	await t._frames(2)
	p.global_position = main.walkable_point(p.global_position, p.global_position, 14.0)
	# Fading in play, and the stair starts it again.
	main.run_soak = {}
	main.soak_worn = {}
	p._act("strike")
	p._act("strike")
	var h := float(PartSoak.FADE["hand"])
	var want := float(PartSoak.SOAK["strike"]["soak"]) * (1.0 + 1.0 / (1.0 + 1.0 / h))
	_check(absf(float(main.run_soak.get("hand", 0.0)) - want) < 0.001, "a second landed strike on a floor soaks less (hand %.2f, want %.2f)" % [float(main.run_soak.get("hand", 0.0)), want])
	var src := FileAccess.get_file_as_string("res://scripts/main.gd")
	_check(src.count("soak_worn = {}") >= 2, "the stair (and a recall) start the fading again")
	# Legs: a roll at nothing counts for nothing.
	p.legs_cd = 0.0
	p._watch_clear("roll_clear")
	_check(p._clear_watch.is_empty(), "a roll in an empty room watches nothing (it can't fill the legs)")
	_check(p._legs("roll_through") and not p._legs("roll_clear"), "two leg soaks are at least %.1f s apart" % PartSoak.LEGS_GAP)
	# Rolling clear of a knight's slash: the legs fill once the blow is spent.
	var at: Vector2 = p.global_position
	var k = await t._spawn("knight", at + Vector2(50, 0))
	if not is_instance_valid(k):
		_check(false, "a knight to roll away from")
		return
	k.set_physics_process(false)
	k.hp = 999.0
	k.max_hp = 999.0
	main.attackers.clear()
	main.request_attack(k)
	k.lunge_dir = Vector2.LEFT
	k._begin_wind("wind_slash", 0.5)
	p.legs_cd = 0.0
	p.hp = p.max_health()
	p.hurt_t = 0.0
	main.run_soak = {}
	main.soak_worn = {}
	p.roll_cd = 0.0
	p.attack_cd = 0.0
	p.sta = p.sta_cap()
	var rolled: bool = p._try_roll(Vector2.UP)
	_check(rolled and p._clear_watch.size() == 1, "a roll while a knight winds up beside you watches its blow")
	p.roll_t = 0.0
	p.global_position = at + Vector2(0, -160)  # (carried well clear)
	k.set_physics_process(true)
	await t._until(func(): return not is_instance_valid(k) or not k.is_attacking(), 1.5)
	await t._ticks(2)
	_check(float(main.run_soak.get("legs", 0.0)) > 0.0 and p.hp == p.max_health(), "...and when it lands on nothing, the legs fill (%.1f)" % float(main.run_soak.get("legs", 0.0)))
	if not is_instance_valid(k):
		return
	k.set_physics_process(false)
	# A knight's leg sweep: leapt, it fills the legs; on the ground, it lands, parry or not.
	p.global_position = k.global_position + Vector2(-50, 0)
	main.run_soak = {}
	p.legs_cd = 0.0
	p.jump_t = p.JUMP_TIME
	p._leapt = false
	p.hurt_t = 0.0
	var hp0: float = p.hp
	var struck: bool = k._low_blow(p, Enemy.LOW_SWEEP_REACH, 10.0, true)
	_check(not struck and p.hp == hp0 and float(main.run_soak.get("legs", 0.0)) > 0.0, "a low sweep passes under a jump, and leaping it fills the legs")
	p.jump_t = 0.0
	p.iframes = 0.0
	p.hurt_t = 0.0
	p.parry_t = 0.3  # (a parry held up doesn't help)
	p.aim = Vector2.RIGHT
	struck = k._low_blow(p, Enemy.LOW_SWEEP_REACH, 10.0, true)
	_check(struck and p.hp < hp0, "...on the ground it lands, parry or not")
	p.parry_t = 0.0
	# The knight's sweep and the shellback's slam, played through.
	p.hp = p.max_health()
	p.hurt_t = 0.0
	p.iframes = 0.0
	main.attackers.clear()
	main.request_attack(k)
	k._begin_wind("wind_low", 0.1)
	k.set_physics_process(true)
	await t._until(func(): return not is_instance_valid(k) or k.state != "wind_low", 1.0)
	_check(is_instance_valid(k) and k.state == "recover" and p.hp < p.max_health(), "a knight's leg sweep winds up, then strikes all round it")
	if is_instance_valid(k):
		k.queue_free()
	await t._frames(1)
	var sb = await t._spawn("shellback", p.global_position + Vector2(40, 0))
	if not is_instance_valid(sb):
		_check(false, "a shellback to slam")
		return
	sb.set_physics_process(false)
	sb.face = Vector2.LEFT  # (facing away: you stand behind it)
	p.hp = p.max_health()
	p.hurt_t = 0.0
	p.iframes = 0.0
	main.attackers.clear()
	main.request_attack(sb)
	sb._begin_wind("wind_slam", 0.1)
	sb.set_physics_process(true)
	await t._until(func(): return not is_instance_valid(sb) or sb.state != "wind_slam", 1.0)
	_check(is_instance_valid(sb) and sb.state == "recover" and p.hp < p.max_health(), "a shellback's slam rings out behind it too")
	if is_instance_valid(sb):
		sb.queue_free()
	await t._frames(1)
	# The Entity explains the low blows and the legs that leap.
	var E = load("res://scripts/entity.gd")
	var Talk = load("res://scripts/entity_talk.gd")
	_check(E.TIPS.has("low_sweep") and E.TIPS.has("leap") and Talk.DIALOGUE["how"]["choices"].has("how_part_fills") and Talk.DIALOGUE["how"]["choices"].has("how_dodge"), "the Entity explains low blows and what fills each part")
	var fills := String(Talk.DIALOGUE["how_part_fills"]["lines"][0]).to_lower()
	_check(fills.contains("jump") and fills.contains("roll") and fills.contains("parr") and fills.contains("backstab") and fills.contains("hits you take"), "...naming every part's sources, jumping among them")
