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
## cheap and steady.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const Model := preload("res://tests/progression_model.gd")
const Flow := preload("res://scripts/essence_flow.gd")
const PS := preload("res://scripts/profile.gd")
const U := preload("res://scripts/unbound.gd")
const PartSoak := preload("res://scripts/part_soak.gd")
const Train := preload("res://scripts/train.gd")

## Crystals from the stairs of a fresh climber's first climb in the
## Manticore's tower (floors 1 to 5, then the Regard refused: Unbound), one
## more run (floors 1 to 6 banked, a fall on 7: the Nodes drained) and two
## floors of the next: [least, most]. About 770 essence gathered on those
## thirteen floors; a fifth of it is about 150, and the overflow of a Node
## never used adds at most a fifth of the rest. (It was about 440 before.)
const EARLY_UNBOUND := [100, 200]
## A typical marked climber's crystals after ten climbs (the model's typical
## pattern: half in their own tower, a summit every other climb): about a
## fifth of what they banked. (It was about 2490 at the old 30% split.)
const MARKED_TEN := [1000, 1800]
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


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## The owner's path, through the game's own bookkeeping: `style` "idle"
## (the Nodes never used) or "actions" (a typical floor's actions, before a
## technique; none cast after).
func _early_unbound(style: String) -> Dictionary:
	var fill := {}
	for a in TYPICAL_FLOOR:
		var pt := PartSoak.part_of(a)
		fill[pt] = float(fill.get(pt, 0.0)) + PartSoak.fill_of(a, TYPICAL_FLOOR[a])
	var prof = PS.new()
	prof.saving = false
	var share: float = Train.condense_share()
	var gathered := 0.0
	for f in range(1, 6):  # (the first climb: bondless, to the Regard on floor 6)
		var e: Dictionary = Model._essence("manticore", f)
		gathered += _sum(e)
		prof.pour(e, Model.STYLE, share)
	prof.regarded = true
	U.become(prof)  # (the mark refused)
	var first: float = prof.crystals_held()
	var g1 := gathered
	for climb in [6, 2]:
		U.new_climb(prof)
		for f in range(1, climb + 1):
			if style == "actions":
				for part in U.PARTS:
					if not U.tech_ready(prof, part):
						U.note_use(prof, part, float(fill.get(part, 0.0)), "action")
			var e: Dictionary = Model._essence("manticore", f)
			gathered += _sum(e)
			prof.pour(e, {}, share)
		if climb == 6:
			U.drain(prof)  # (the fall on floor 7)
	return {"crystals": prof.crystals_held(), "since": prof.crystals_held() - first, "gathered_since": gathered - g1}


static func _sum(d: Dictionary) -> float:
	var s := 0.0
	for k in d:
		s += float(d[k])
	return s
