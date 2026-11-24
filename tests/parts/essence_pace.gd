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
## a lot of essence, as the model's floors were a light player's). And it
## holds a whole climb's crystals, every source counted (the owner's third
## report: "I seem to walk out of a climb with 150 to 300 crystals", so the
## stair's share went from 20% to 8% with the finds at 87%, what flows into
## you no more than before, and the vaults', the camp's, the pay's, the
## belt's and a rival's crystals were halved).
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const Model := preload("res://tests/progression_model.gd")
const Wings := preload("res://scripts/wings.gd")
const Proving := preload("res://scripts/proving.gd")
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
## floors of the next: [least, most]. About 630 essence gathered on those
## thirteen floors; 8% of it is about 50, and the overflow of a Node never
## used adds at most a tenth of the rest. (It was about 440 at first, then
## 100 to 200 at a 20% share and a fifth of the overflow.)
const EARLY_UNBOUND := [30, 75]
## A typical marked climber's crystals from the stairs after ten climbs (the
## model's typical pattern: half in their own tower, a summit every other
## climb): about 8% of what they banked. (It was about 2490 at the old 30%
## split, about 1400 at 20%.)
const MARKED_TEN := [320, 600]
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
## player's floors (the model's essence): about 20 of some 370 gathered.
## (About 130 of some 640 at the old drops, a thorough floor giving about
## 1.6 times the model's then; about 70 at a 20% share. The rest of a real
## climber's crystals come from elsewhere: a camp's card, the sentinel, the
## outfitter's pay, a start's crystals, vaults: CLIMB counts them.)
const ASH_PATH := [12, 40]
## The model's thorough summit (floors 1 to 12) before a stair's crystal
## share went from OLD_SHARE (20%) to 8% and every find to 87%: what flowed
## into the climber then, (1 - OLD_SHARE) of it, through the game's split
## (a stair rounds its crystals down, kind by kind, so a little more goes in
## than the share says), against what flows in now: INFLOW_BAND of it, never
## more (growth no faster).
const OLD_SUMMIT := 1149.125
const OLD_SHARE := 0.2
const INFLOW_BAND := [0.96, 1.0]
## A whole climb's crystals, every source counted: [least, most]. A summit
## (floors 1 to 12) or a fall on floor 8 (1 to 7 banked); a thorough
## player's floors (the model's) or a light one's (Model.LIGHT). A thorough
## climber takes one camp's crystal card (floor 6's: the others an item or
## gear), a sealed wing's vault crystal (floor 5) and the Proving sentinel's
## crystal, and brings home the staples and a Fire Flask on a survived
## climb; a light one takes floor 3's camp card and the sentinel's crystal,
## and brings home the staples. The stairs' crystals are the model's (the
## game's own bookkeeping, a typical climber's use). (Before: about 340 a
## thorough summit, 105 a thorough fall on 8, 150 a light summit, 50 a
## light fall: the owner found 150 to 300 a climb too many.)
const CLIMB := {"thorough summit": [100, 140], "thorough fall": [40, 75], "light summit": [40, 80], "light fall": [15, 40]}
## A typical floor's actions (tests/parts/part_soak.gd's typical climber).
const TYPICAL_FLOOR := {"strike": 22, "shot": 10, "cleave": 4, "multi_cast": 1, "backstab": 3, "finisher": 6, "hit_taken": 7, "parry": 3, "perfect_parry": 1, "roll_through": 1.5, "roll_clear": 5, "jump_clear": 0.5}

var t


func run(smoke) -> void:
	t = smoke
	print("the pace of crystals: a fixed share, and what can't go in mostly back to the well")
	_check(is_equal_approx(Train.condense_share(), float(Flow.SPLIT["crystals"]) / 100.0) and is_equal_approx(Train.condense_share(), 0.08), "a stair's crystal share is fixed at 8% (no setting; it was 20%)")
	_inflow()
	_climbs()
	var most: float = Train.condense_share() + float(Flow.OVERFLOW["crystals"]) * (1.0 - Train.condense_share())
	for style in ["idle", "actions"]:
		var r := _early_unbound(style)
		var since: float = float(r["since"])
		var got: float = float(r["crystals"])
		_check(since <= most * float(r["gathered_since"]) + 6.0, "an early Unbound (%s) condenses at most the share and a tenth of the overflow: %d of %d gathered (%d%%, at most %d%%)" % [style, int(since), int(r["gathered_since"]), roundi(100.0 * since / maxf(1.0, float(r["gathered_since"]))), roundi(most * 100.0)])
		_check(got >= EARLY_UNBOUND[0] and got <= EARLY_UNBOUND[1], "...crystals after one Manticore run and two floors: %d (%d to %d; 100 to 200 at a 20%% share)" % [int(got), EARLY_UNBOUND[0], EARLY_UNBOUND[1]])
	_thorough()
	for style in ["idle", "actions"]:
		var ash := _path(style, "chimera", 5, [[6, 6], [1, 2]])
		_check(float(ash["crystals"]) >= ASH_PATH[0] and float(ash["crystals"]) <= ASH_PATH[1],
			"a path like the owner's Unbound (%s: the Chimera's first climb, the mark refused, a fall on 7, then two floors): %d crystals from the stairs, of %d gathered (%d to %d)" % [style, int(ash["crystals"]), int(ash["gathered"]), ASH_PATH[0], ASH_PATH[1]])
	var typ: Dictionary = Model.run("typical", 10)
	var ten := float(typ["crystals"][9])
	_check(ten >= MARKED_TEN[0] and ten <= MARKED_TEN[1], "a typical marked climber's crystals from the stairs after ten climbs: %d (%d to %d; about 1400 at a 20%% share)" % [int(ten), MARKED_TEN[0], MARKED_TEN[1]])
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
	# fewer after ten climbs. (With a stair's share at 8% a careful forcer can
	# eat them all before the strain stops them: the crystals are a brake now
	# too; tests/parts/progression.gd holds the forcer's pace.)
	var forcer: Dictionary = Model.run("typical", 10, false, Model.BOUGHT_TINCTURES, 1.0, "careful")
	var fc := float(forcer["crystals"][9])
	_check(fc < ten and float(forcer["forced"]) <= ten + 1.0 and fc >= ten - float(forcer["forced"]) - ten * 0.05, "a climber who force-eats every crystal holds %d after ten climbs (%d forced; %d without): forcing only spends crystals" % [int(fc), int(forcer["forced"]), int(ten)])


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## What flows into the climber (body and marks, before what they can't take)
## from the model's summit (a thorough player's floors and a light one's),
## through the game's own split, against what flowed in before the share
## went to 8%: never more growth.
func _inflow() -> void:
	var banked := 0.0
	for f in range(1, Towers.SUMMIT + 1):
		banked += _sum(Model._essence(Model.OWN_TOWER, f))
	for play in ["thorough", "light"]:
		var amount: float = 1.0 if play == "thorough" else Model.LIGHT
		var inflow := _summit_inflow(amount, Train.condense_share())
		var old := _summit_inflow(amount * OLD_SUMMIT / banked, OLD_SHARE)
		var r := inflow / old
		_check(r >= INFLOW_BAND[0] and r <= INFLOW_BAND[1],
			"what flows into you from a %s summit is about what it was, never more: %d of %d banked (%d before, of %d: %d%%, %d%% to %d%%), so growth is no faster" % [
			play, roundi(inflow), roundi(banked * amount), roundi(old), roundi(OLD_SUMMIT * amount), roundi(r * 100.0), roundi(INFLOW_BAND[0] * 100.0), roundi(INFLOW_BAND[1] * 100.0)])
	var typ: Dictionary = Model.run("summits", 2)
	var ub: Dictionary = Model.run_unbound("summits", 2)
	print("    (a marked climber's summit: %d into body and marks, %d crystals from the stairs; an Unbound's: %d crystals)" % [
		roundi(float(typ["inflow"][1]) - float(typ["inflow"][0])), roundi(float(typ["crystals"][1]) - float(typ["crystals"][0])), roundi(float(ub["crystals"][1]) - float(ub["crystals"][0]))])


## What reaches body and marks (before what they can't take) from the
## model's summit in the first mark's tower, its floors times `amount`,
## through the game's split at crystal share `share`.
func _summit_inflow(amount: float, share: float) -> float:
	var prof = PS.new()
	prof.saving = false
	prof.regarded = true
	prof.add_bond(Model.FIRST_PART, Model.FIRST_BOND, false)
	var inflow := 0.0
	for f in range(1, Towers.SUMMIT + 1):
		var out: Dictionary = prof.pour(Model._essence(Model.OWN_TOWER, f, amount), Model.STYLE, share)
		inflow += _sum(out["keep"])
	return inflow


## A whole climb's crystals by source (CLIMB): marked and Unbound, thorough
## and light, a summit and a fall on 8.
func _climbs() -> void:
	var totals := {}
	for play in ["thorough", "light"]:
		for top in [Towers.SUMMIT, 8]:
			var name: String = play + (" summit" if top >= Towers.SUMMIT else " fall")
			for who in ["marked", "Unbound"]:
				var c := _climb(who, play, top)
				var sum := 0.0
				var bits := []
				for k in c:
					sum += float(c[k])
					bits.append("%s %d" % [k, roundi(float(c[k]))])
				totals[name + " " + who] = sum
				var band: Array = CLIMB[name]
				_check(sum >= float(band[0]) and sum <= float(band[1]), "a %s climber's %s%s: %d crystals in all (%d to %d)  [%s]" % [
					who, play, " summit" if top >= Towers.SUMMIT else " climb that falls on 8", roundi(sum), int(band[0]), int(band[1]), ", ".join(bits)])
	for who in ["marked", "Unbound"]:
		_check(float(totals["light summit " + who]) < float(totals["thorough summit " + who]) and float(totals["light fall " + who]) < float(totals["thorough fall " + who]),
			"...a light %s climber walks out with less than a thorough one" % who)


## One climb's crystals by source: "stairs" (the split's share and what the
## marks or Nodes couldn't take, through the model: its second climb, after
## the first climb's Regard), "camp" (one camp's crystal card), "vault",
## "sentinel", "pay" (the outfitter's, not a new best) and "belt" (a survived
## climb's leftovers).
func _climb(who: String, play: String, top: int) -> Dictionary:
	var thorough := play == "thorough"
	var amount: float = 1.0 if thorough else Model.LIGHT
	var pattern := "summits" if top >= Towers.SUMMIT else "falls"  # (falls: a fall on 5, then one on 8)
	var r: Dictionary
	if who == "marked":
		r = Model.run(pattern, 2, false, Model.BOUGHT_TINCTURES, 1.0, "", amount)
	else:
		r = Model.run_unbound(pattern, 2, "typical", "natural", [], true, "", amount)
	var vault := func(f: int) -> float: return float(Wings.REWARD["crystal_base"]) + float(Wings.REWARD["crystal_per_floor"]) * f
	var out := {"stairs": float(r["crystals"][1]) - float(r["crystals"][0])}
	out["camp"] = float(roundi(float(vault.call(6 if thorough else 3)) * float(Wings.REWARD["camp"])))
	if thorough:
		out["vault"] = float(roundi(float(vault.call(5))))
	out["sentinel"] = roundf(float(vault.call(6)) * float(Proving.TIERS[0]["crystal"]))
	out["pay"] = float(Train.climb_pay(top, top))
	if top >= Towers.SUMMIT:
		var belt: Dictionary = Items.START.duplicate()
		if thorough:
			belt["fire_flask"] = 1
		out["belt"] = _sum(Items.break_value(belt))
	return out


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
