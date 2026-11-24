extends RefCounted
## The pace of crystals (the owner's report: an early Unbound held about 700
## Stone after one Manticore run and a floor). Banked essence at a stair goes
## a fixed share to crystals (essence_flow.gd SPLIT "crystals", no longer a
## setting); what the marks or an Unbound's Nodes can't take (use already
## refilled, a Node full) only partly condenses (OVERFLOW), the rest going
## back to the well. It all condensed once, so a climber who seldom used
## their Nodes turned nearly everything banked into crystals.
## The essence is the progression model's (tests/progression_model.gd:
## measured floors, the game's own bookkeeping, no randomness), so this is
## cheap and steady. It also holds the drop tables and the finds to the
## model: a thorough player's real floor (the owner's way) gives what the
## model counts (the owner's next report: a fresh Unbound, "Ash", still got
## a lot of essence, as the model's floors were a light player's).
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const Model := preload("res://tests/progression_model.gd")
const Flow := preload("res://scripts/essence_flow.gd")
const PS := preload("res://scripts/profile.gd")
const U := preload("res://scripts/unbound.gd")
const PartSoak := preload("res://scripts/part_soak.gd")
const Train := preload("res://scripts/train.gd")
const Essence := preload("res://scripts/essence.gd")
const Items := preload("res://scripts/items.gd")
const Towers := preload("res://scripts/towers.gd")
const Floors := preload("res://scripts/floors.gd")
const RoomRewards := preload("res://scripts/room_rewards.gd")
const Cracks := preload("res://scripts/cracks.gd")
const Objectives := preload("res://scripts/objectives.gd")
const Puzzle := preload("res://scripts/puzzle.gd")
const Mimic := preload("res://scripts/mimic.gd")

## Crystals from the stairs of a fresh climber's first climb in the
## Manticore's tower (floors 1 to 5, then the Regard refused: Unbound), one
## more run (floors 1 to 6 banked, a fall on 7: the Nodes drained) and two
## floors of the next: [least, most]. About 720 essence gathered on those
## thirteen floors; a fifth of it is about 150, and the overflow of a Node
## never used adds at most a fifth of the rest. (It was about 440 before.)
const EARLY_UNBOUND := [100, 200]
## A typical marked climber's crystals after ten climbs (the model's typical
## pattern: half in their own tower, a summit every other climb): about a
## fifth of what they banked. (It was about 2490 at the old 30% split.)
const MARKED_TEN := [1000, 1800]
## A thorough floor (the owner's way: the task, every monster in reach,
## every chest, cache and cracked wall), measured by the floor bot
## (tests/essence_measure.gd "thorough", floors 2 to 7 of the Chimera's, the
## Firebird's and the Manticore's towers): what it holds beside its monsters,
## a floor, counted in plain finds (a chest with no item, a cracked wall's
## alcove, a good room's cache, a solved puzzle, the task's reward at the
## stair, a mimic's spill). Floor 1 holds none. Its kills are the model's
## (Model.KILLS, measured the same way).
const FINDS := {"chest": 3.37, "crack": 0.77, "cache": 0.29, "puzzle": 0.33, "task": 1.0, "mimic": 0.18}
## What the drop tables and the finds give such a floor stays this near the
## model's (Model.ESSENCE): floors 1 to 5 together, and floor 7. (The floor
## bot's measure gives about all of it now; about 1.6 times it before the
## drops and finds were lowered.)
const THOROUGH_BAND := [0.85, 1.15]
## Crystals from the stairs of a path like the owner's Unbound "Ash": a
## first climb in the Chimera's tower to the Regard (floors 1 to 5 banked),
## the mark refused, floor 6 banked and a fall on 7 (the Nodes drained);
## then a short climb (floors 1 and 2 banked, a fall on 3). A thorough
## player's floors (the model's essence): about 70 of some 420 gathered.
## (About 130 of some 640 at the old drops, a thorough floor giving about
## 1.6 times the model's then. The rest of a real climber's crystals come
## from elsewhere: a camp's card, the sentinel, the outfitter's pay, a
## start's crystals, vaults.)
const ASH_PATH := [50, 100]
## A typical floor's actions (tests/parts/part_soak.gd's typical climber).
const TYPICAL_FLOOR := {"strike": 22, "shot": 10, "cleave": 4, "multi_cast": 1, "backstab": 3, "finisher": 6, "hit_taken": 7, "parry": 3, "perfect_parry": 1, "roll_through": 1.5, "roll_clear": 5, "jump_clear": 0.5}

var t


func run(smoke) -> void:
	t = smoke
	print("the pace of crystals: a fixed share, and what can't go in mostly back to the well")
	_check(is_equal_approx(Train.condense_share(), float(Flow.SPLIT["crystals"]) / 100.0) and is_equal_approx(Train.condense_share(), 0.2), "a stair's crystal share is fixed at 20% (no setting)")
	var most: float = Train.condense_share() + float(Flow.OVERFLOW["crystals"]) * (1.0 - Train.condense_share())
	for style in ["idle", "actions"]:
		var r := _early_unbound(style)
		var since: float = float(r["since"])
		var got: float = float(r["crystals"])
		_check(since <= most * float(r["gathered_since"]) + 6.0, "an early Unbound (%s) condenses at most the share and a fifth of the overflow: %d of %d gathered (%d%%, at most %d%%)" % [style, int(since), int(r["gathered_since"]), roundi(100.0 * since / maxf(1.0, float(r["gathered_since"]))), roundi(most * 100.0)])
		_check(got >= EARLY_UNBOUND[0] and got <= EARLY_UNBOUND[1], "...crystals after one Manticore run and two floors: %d (%d to %d; about 440 before)" % [int(got), EARLY_UNBOUND[0], EARLY_UNBOUND[1]])
	_thorough()
	for style in ["idle", "actions"]:
		var ash := _path(style, "chimera", 5, [[6, 6], [1, 2]])
		_check(float(ash["crystals"]) >= ASH_PATH[0] and float(ash["crystals"]) <= ASH_PATH[1],
			"a path like the owner's Unbound (%s: the Chimera's first climb, the mark refused, a fall on 7, then two floors): %d crystals from the stairs, of %d gathered (%d to %d)" % [style, int(ash["crystals"]), int(ash["gathered"]), ASH_PATH[0], ASH_PATH[1]])
	var typ: Dictionary = Model.run("typical", 10)
	var ten := float(typ["crystals"][9])
	_check(ten >= MARKED_TEN[0] and ten <= MARKED_TEN[1], "a typical marked climber's crystals after ten climbs: %d (%d to %d; about 2490 at the old 30%%)" % [int(ten), MARKED_TEN[0], MARKED_TEN[1]])
	var ub: Dictionary = Model.run_unbound("typical", 10)
	var uten := float(ub["crystals"][9])
	_check(uten <= ten * 1.1, "...and a typical Unbound's no more than theirs: %d" % int(uten))
	# Eating a crystal isn't a way around the pace: into a full Node with no
	# use, nothing grows and the essence stays a crystal.
	var prof = PS.new()
	prof.saving = false
	U.become(prof)
	U.set_node(prof, "back", {"stone": 30.0})
	var size0: float = U.size(prof, "back")
	prof.add_crystal("stone", 10.0)
	var amount: float = prof.take_crystal("stone", 10.0)
	prof.pour({"stone": amount}, {}, 0.0, false)
	_check(is_equal_approx(U.size(prof, "back"), size0) and prof.crystal_total("stone") == 10.0, "eating a crystal into a full Node it hasn't used grows nothing, and it stays a crystal")
	# Forcing (forcing.gd) is the only way past full: it spends crystals and
	# never makes any. A typical climber who force-eats every crystal holds
	# fewer after ten climbs; the strain, not the crystals, is the brake.
	var forcer: Dictionary = Model.run("typical", 10, false, Model.BOUGHT_TINCTURES, 1.0, "careful")
	var fc := float(forcer["crystals"][9])
	_check(fc < ten and fc >= ten - float(forcer["forced"]) - ten * 0.05 and fc > 0.0, "a climber who force-eats every crystal holds %d after ten climbs (%d forced; %d without), crystals left over: the strain holds them back" % [int(fc), int(forcer["forced"]), int(ten)])


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## The owner's path, through the game's own bookkeeping: `style` "idle"
## (the Nodes never used) or "actions" (a typical floor's actions, before a
## technique; none cast after).
func _early_unbound(style: String) -> Dictionary:
	var r := _path(style, "manticore", 5, [[1, 6], [1, 2]], [true, false])
	return {"crystals": r["crystals"], "since": float(r["crystals"]) - float(r["first"]), "gathered_since": float(r["gathered"]) - float(r["first_gathered"])}


## A path through `tower`: a bondless first climb banking floors 1 to
## `first` (the Regard after it), the mark refused (Unbound), then `later`:
## climbs (or the rest of the first one), each [first floor, last floor]
## banked, ending in a fall that drains the Nodes (`falls`: false for one
## that doesn't). Returns {"crystals", "gathered", "first" (the crystals
## after the first climb's floors), "first_gathered"}.
func _path(style: String, tower: String, first: int, later: Array, falls: Array = []) -> Dictionary:
	var fill := {}
	for a in TYPICAL_FLOOR:
		var pt := PartSoak.part_of(a)
		fill[pt] = float(fill.get(pt, 0.0)) + PartSoak.fill_of(a, TYPICAL_FLOOR[a])
	var prof = PS.new()
	prof.saving = false
	var share: float = Train.condense_share()
	var gathered := 0.0
	for f in range(1, first + 1):  # (the first climb: bondless, to the Regard on floor 6)
		var e: Dictionary = Model._essence(tower, f)
		gathered += _sum(e)
		prof.pour(e, Model.STYLE, share)
	prof.regarded = true
	U.become(prof)  # (the mark refused)
	var first_c: float = prof.crystals_held()
	var g1 := gathered
	for i in later.size():
		var span: Array = later[i]
		U.new_climb(prof)
		for f in range(int(span[0]), int(span[1]) + 1):
			if style == "actions":
				for part in U.PARTS:
					if not U.tech_ready(prof, part):
						U.note_use(prof, part, float(fill.get(part, 0.0)), "action")
			var e: Dictionary = Model._essence(tower, f)
			gathered += _sum(e)
			prof.pour(e, {}, share)
		if i >= falls.size() or bool(falls[i]):
			U.drain(prof)  # (the fall)
	return {"crystals": prof.crystals_held(), "gathered": gathered, "first": first_c, "first_gathered": g1}


## A thorough floor's essence from the game's own tables (Model.KILLS times
## a kill's essence, over real floor plans of every tower, and FINDS at what
## each pays on the floor) against the model's (Model.ESSENCE).
func _thorough() -> void:
	var game := {}
	var bits := []
	for f in [1, 2, 3, 4, 5, 7]:
		var e: float = float(Model.KILLS[f - 1]) * _per_kill(f) + _finds(f)
		game[f] = e
		bits.append("floor %d: %d of %d" % [f, roundi(e), roundi(float(Model.ESSENCE[f - 1]))])
	var got := 0.0
	var want := 0.0
	for f in range(1, 6):
		got += float(game[f])
		want += float(Model.ESSENCE[f - 1])
	var r1 := got / want
	var r7 := float(game[7]) / float(Model.ESSENCE[6])
	_check(r1 >= THOROUGH_BAND[0] and r1 <= THOROUGH_BAND[1] and r7 >= THOROUGH_BAND[0] and r7 <= THOROUGH_BAND[1],
		"a thorough floor (%s kills a floor on floors 1-7, every chest and cache) gives what the pace model counts: floors 1-5 %d of %d (%d%%), floor 7 %d%% (%d%% to %d%%; about 160%% before the drops were lowered)  [%s]" % [
		str(Model.KILLS.slice(0, 7)), roundi(got), roundi(want), roundi(r1 * 100.0), roundi(r7 * 100.0), roundi(THOROUGH_BAND[0] * 100.0), roundi(THOROUGH_BAND[1] * 100.0), ", ".join(bits)])
	# A summoned add pays nothing, a horde's monster a share (essence.gd ADDS).
	var add := Node.new()
	add.set_meta("add", "summoned")
	var horde := Node.new()
	horde.set_meta("add", "horde")
	var plain := Node.new()
	_check(Essence.add_pay(add) == 0.0 and Essence.add_pay(horde) > 0.0 and Essence.add_pay(horde) < 0.5 and Essence.add_pay(plain) == 1.0,
		"a summoned add pays no essence, a horde's monster a share (%.2f), any other monster in full" % Essence.add_pay(horde))
	add.free()
	horde.free()
	plain.free()


## A kill's essence on floor `f`: its drop, the tower's bonus and the chance
## of a little more (items.gd DROPS), over the monsters of real floor plans
## (every tower, one plan each, a fixed seed).
func _per_kill(f: int) -> float:
	seed(9000 + f)
	var sum := 0.0
	var n := 0
	for tid in Towers.ORDER:
		var plan: Dictionary = Floors.rooms_floor(f, Towers.TOWERS[tid], false)
		for m in plan.get("monsters", []):
			sum += float(Essence.drop_for(String(m[0]), f)[1])
			n += 1
	randomize()
	var extra: float = float(Items.DROPS["essence_chance"]) * (float(Items.DROPS["essence_base"]) + float(Items.DROPS["essence_per_floor"]) * f)
	return sum / maxf(1.0, float(n)) + float(Towers.ESSENCE_BONUS) + extra


## What a thorough floor's finds pay on floor `f` (FINDS at the tables' amounts).
func _finds(f: int) -> float:
	if f <= 1:
		return 0.0
	var rr: Dictionary = RoomRewards.RULES
	var chest_plain: float = float(rr["chest_base"]) + float(rr["chest_per_floor"]) * f
	var pays := {
		"chest": chest_plain * (float(rr["item_chance"]) + (1.0 - float(rr["item_chance"])) * float(rr["no_item"])),
		"crack": float(Cracks.RULES["cache_base"]) + float(Cracks.RULES["cache_per_floor"]) * f,
		"cache": Floors.cache_amount(f),
		"puzzle": Puzzle.REWARD.x + Puzzle.REWARD.y * float(maxi(f - 2, 0)),
		"task": float(Objectives.REWARD["essence"]) + float(Objectives.REWARD["per_floor"]) * f,
		"mimic": chest_plain * float(rr["chest_rich"]) * float(Mimic.RULES["essence"]),
	}
	var out := 0.0
	for k in FINDS:
		out += float(FINDS[k]) * float(pays[k])
	return out


static func _sum(d: Dictionary) -> float:
	var s := 0.0
	for k in d:
		s += float(d[k])
	return s
