extends RefCounted
## The Unbound's Nodes (unbound.gd), core essence (core.gd) and the aura
## (secret.gd): six Nodes asleep at size 0, soaking up routed essence until
## they wake at 30; awake, what they hold (up to their size) and their size,
## grown only by use refilled at the stair (no cap a climb: casting more than
## you bank adds nothing); a level every 10 of size (12),
## the primary kept at least half and three kinds at most, the minor ability
## at 3 (waking), a technique at 6, the capstone and a pure Node's
## signature at 12 (Blink); attributes from the Nodes' sizes; moving
## essence at a price (feeding a sleeping Node; never changing a size); core
## essence banked slowly, spread evenly, stopping once the body is
## saturated, core-led Nodes and their core technique; the aura's six steps;
## the pace in climbs (tests/progression_model.gd run_unbound); the Entity's
## words for all of it; and an old profile becomes Nodes without losing growth.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.
const TestRun := preload("res://scripts/test_run.gd")

const U := preload("res://scripts/unbound.gd")
const Core := preload("res://scripts/core.gd")
const Secret := preload("res://scripts/secret.gd")
const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

## The pace of the Nodes, in climbs after the first (tests/progression_model.gd
## run_unbound: a typical climber climbs their own tower half the time and
## summits every other climb; using their awake Nodes as a typical climber
## does). [least, most].
## The main Node (the own tower's kind's): awake after about one climb.
const MAIN_AWAKE := [1, 1]
## Level 12: a typical climber (the owner's target: 20 to 25 attempts), and
## one who summits every climb (8 to 10).
const MAIN_TOP := [19, 26]
const MAIN_TOP_SUMMITS := [8, 11]
## The other Nodes awake: each kind to its own Node; routing to wake them.
const OTHERS_AWAKE := [2, 12]
const OTHERS_AWAKE_ROUTED := [2, 6]
## All six at level 12, routing as they fill (the owner's target: 50 to 60).
const ALL_TOP := [66, 84]  # (the owner's 72, a multiple of six; the one rule makes the last Nodes slower)
## (It was 66 to 78. The routed path's choices, which tower feeds the
## smallest Node, make this jump a few climbs with any small change of
## essence, either way: at the old 20% share it took 76 climbs, 84 with the
## finds at 95%, 78 at 105% and 80 at 110%. With the share at 8% and the
## finds at 87%, what flows in is 99% of what it was, and it takes 79.)
const ROUTED_CLIMBS := 90

var t
var T
var TR


func run(smoke) -> void:
	t = smoke
	T = load("res://scripts/technique.gd")
	TR = load("res://scripts/tree.gd")
	print("the Unbound reworked: cups, core essence, the aura")
	_cups()
	_nodes()
	_moving()
	_core()
	_core_led()
	_pure()
	_aura()
	_pace()
	_words()
	_old_profile()
	await _in_play()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## A fresh Unbound profile (nothing saved).
func _prof():
	var p = load("res://scripts/profile.gd").new()
	p.saving = false
	U.become(p)
	return p


func _cups() -> void:
	var p = _prof()
	_check(U.MAX_LEVEL == 12 and is_equal_approx(Core.CAP, 120.0) and U.LEVELS.size() == 12 and is_equal_approx(U.LEVELS[11], 120.0), "a part holds 120, 12 levels")
	_check(U.MINOR_LEVEL == 1 and U.LEVELS[0] == U.WAKE_SIZE and U.TECH_LEVEL == 3 and U.FULL_TECH_LEVEL == 6 and U.level_for(U.WAKE_SIZE) == 1 and U.level_for(U.WAKE_SIZE - 0.5) == 0, "a Node wakes at level 1 (size 30) with its minor ability, a young technique at 3, the full technique at 6, the capstone at 12 (full)")
	# The first essence leads; another may come in only while the first stays at least half.
	U.put(p, "hand", "fire", 30.0)
	_check(U.primary(p, "hand") == "fire" and is_equal_approx(U.kind_limit(p, "hand", "stone"), 30.0), "the first essence in a Node leads it; another may grow to match it (30)")
	_check(is_equal_approx(U.put(p, "hand", "stone", 50.0), 30.0) and is_equal_approx(U.amount(p, "hand", "stone"), 30.0), "...no further: the lead stays at least half")
	U.set_size(p, "hand", 120.0)
	_check(U.take_limit(p, "hand", "air") == 0.0 and U.why_not(p, "hand", "air").contains("half"), "a third kind needs room for the lead's half (%s)" % U.why_not(p, "hand", "air"))
	U.put(p, "hand", "fire", 30.0)
	_check(U.put(p, "hand", "air", 10.0) > 0.0 and U.mix(p, "hand") == ["fire", "stone", "air"], "with the lead grown, a third comes in: three kinds, the lead first")
	U.put(p, "hand", "fire", 6.0)
	_check(U.take_limit(p, "hand", "water") == 0.0 and U.why_not(p, "hand", "water").contains("three"), "a fourth kind can't come in")
	_check(_rising(U.GROW_COST), "each level of size costs more essence than the last (%s)" % str(U.GROW_COST))
	var r = _prof()
	r.part_density = {"legs": {"air": 120.0}}
	U.state(r)["primary"] = {"legs": "air"}
	var held: float = r.crystal_total("air")
	var poured: Dictionary = r.pour({"air": 100.0}, {}, 0.0)
	var of := float(load("res://scripts/essence_flow.gd").OVERFLOW["crystals"])
	_check(r.crystal_total("air") >= held + floorf(100.0 * of) - 1.0 and r.crystal_total("air") <= held + ceilf(100.0 * of) and float(poured["lost"]) >= 100.0 * (1.0 - of) - 1.0,
		"banked into a full part at a stair, a share condenses into crystals (%d) and the rest goes back to the well" % int(r.crystal_total("air") - held))
	var r2 = _prof()
	r2.part_density = {"legs": {"air": 120.0}}
	U.state(r2)["primary"] = {"legs": "air"}
	r2.pour({"air": 10.0}, {}, 0.0, false)
	_check(r2.crystal_total("air") == 10.0, "...but a crystal eaten into it isn't lost: it stays a crystal")
	# Levels bring their pieces.
	var s = _prof()
	U.put(s, "brow", "fire", 29.0)
	_check(not U.awake(s, "brow") and not U.has_minor(s, "brow") and U.minor_text(s, "brow").contains("1"), "below size 30 a Node sleeps: no minor ability yet")
	U.put(s, "brow", "fire", 1.0)
	_check(U.awake(s, "brow") and U.has_minor(s, "brow") and U.minor_text(s, "brow").contains("parries") and U.minor_text(s, "brow").contains("Fire"), "at size 30 (level 1) it wakes: %s" % U.minor_text(s, "brow"))
	_check(U.sync_techs(s).is_empty() and U.tech_of(s, U.PARTS.find("brow")).is_empty(), "below level 3, no technique")
	U.put(s, "brow", "fire", 16.0)
	var learned: Array = U.sync_techs(s)
	var bt: Dictionary = U.tech_of(s, U.PARTS.find("brow"))
	_check(U.level(s, "brow") == 3 and learned == ["brow"] and T.valid(bt) and bt["shape"] == "mark" and bt["kinds"] == ["fire"], "at level 3 the Node learns its first form by itself (%s)" % T.title(bt))
	_check(U.tech_young(s, "brow") and is_equal_approx(U.power(s, "brow"), U.YOUNG_POWER) and load("res://scripts/tree.gd").owned_forms(s, "brow") == ["mark"], "...a young technique: its first form only, at %d%% strength" % int(U.YOUNG_POWER * 100.0))
	U.put(s, "brow", "water", 10.0)
	U.sync_techs(s)
	_check(U.tech_kinds(s, "brow") == ["fire"] and U.tech_of(s, U.PARTS.find("brow"))["kinds"] == ["fire"], "...and its lead essence alone (the Water waits)")
	U.put(s, "brow", "fire", 14.0)
	U.sync_techs(s)
	_check(U.level(s, "brow") == 6 and not U.tech_young(s, "brow") and U.tech_kinds(s, "brow") == ["fire", "water"] and load("res://scripts/tree.gd").owned_forms(s, "brow") == ["mark", "sight"] and is_equal_approx(U.power(s, "brow"), 1.0), "at level 6 it comes into its own: the Water joins, the other form opens, full strength")
	_check(U.sync_techs(s).is_empty(), "...once")
	U.put(s, "hand", "fire", 70.0)
	U.sync_techs(s)
	_check(T.title(U.tech_of(s, 0)) == "Flame Fist", "its name comes from the form and the essence: Fire and the fists, Flame Fist (%s)" % T.title(U.tech_of(s, 0)))
	_check(is_equal_approx(U.power(s, "hand"), 1.0) and U.has_gift(s, "hand"), "a technique starts at its base strength at level 6 (the gift came at 5)")
	U.put(s, "hand", "fire", 50.0)
	_check(is_equal_approx(U.power(s, "hand"), U.MAX_POWER) and load("res://scripts/spells/unbound_forms.gd").capstone_on(s, "hand"), "full, it hits %dx as hard and its capstone wakes" % int(U.MAX_POWER))
	# A modifier's touch grows with its share.
	var w = _prof()
	U.put(w, "throat", "water", 60.0)
	U.put(w, "throat", "stone", 15.0)
	var small: float = U.tech_weights(w, "throat")["stone"]
	U.put(w, "throat", "stone", 30.0)
	_check(U.tech_weights(w, "throat")["water"] == 1.0 and U.tech_weights(w, "throat")["stone"] > small, "a modifier acts more the bigger its share (%.2f, then %.2f)" % [small, U.tech_weights(w, "throat")["stone"]])


## The Nodes: asleep, soaking, waking; holding up to their size; growing
## only by use (no cap a climb); attributes from their sizes.
func _nodes() -> void:
	var p = _prof()
	_check(U.PARTS.all(func(pt): return not U.awake(p, pt) and U.size(p, pt) == 0.0 and U.fill(p, pt) == 0.0), "a new Unbound's six Nodes all sleep, at size 0, holding nothing")
	_check(U.node_name("hand") == "Hand Node" and U.why_not(p, "hand", "blade").contains("asleep"), "they're called Nodes, and a sleeping one takes nothing in (%s)" % U.why_not(p, "hand", "blade"))
	var left: float = U.settle_into(p, "legs", "air", float(U.GROW_COST[0]))
	_check(left < 0.01 and is_equal_approx(U.size(p, "legs"), U.LEVEL_SIZE) and U.own(p, "legs") == 0.0, "asleep, %d banked essence soak in: size 10, still holding nothing" % int(U.GROW_COST[0]))
	left = U.settle_into(p, "legs", "air", float(U.GROW_COST[1]) + float(U.GROW_COST[2]) + 50.0)
	_check(U.awake(p, "legs") and is_equal_approx(U.size(p, "legs"), U.WAKE_SIZE) and is_equal_approx(U.own(p, "legs"), U.WAKE_SIZE) and is_equal_approx(left, 20.0), "at size 30 it wakes; what's left fills what it holds, up to its size, and the rest is left over (%.1f)" % left)
	left = U.settle_into(p, "legs", "air", 500.0)
	_check(is_equal_approx(U.size(p, "legs"), U.WAKE_SIZE) and is_equal_approx(left, 500.0), "awake but unused, it doesn't grow: banked essence it can't hold is left over (to crystals)")
	U.note_use(p, "legs", 50.0, "cast")
	_check(is_equal_approx(U.used(p, "legs"), 50.0 * float(U.USE["cast"])), "a cast's spent essence counts as use (%.0f)" % U.used(p, "legs"))
	left = U.settle_into(p, "legs", "air", 500.0)
	var want: float = U.WAKE_SIZE + 50.0 * float(U.USE["cast"]) * U.LEVEL_SIZE / float(U.GROW_COST[3])
	_check(is_equal_approx(U.size(p, "legs"), want) and is_equal_approx(left, 500.0 - 50.0 * float(U.USE["cast"]) - (want - U.WAKE_SIZE)), "at the stair the use is refilled from what's banked into it, which stretches it (size %.1f; the refill is used up)" % U.size(p, "legs"))
	_check(is_equal_approx(U.own(p, "legs"), U.size(p, "legs")), "...and it tops up what it holds to its new size")
	U.note_use(p, "legs", 999.0, "cast")
	U.settle_into(p, "legs", "air", 10.0)
	var s1: float = U.size(p, "legs")
	U.end_stair(p)
	U.settle_into(p, "legs", "air", 99999.0)
	_check(is_equal_approx(U.size(p, "legs"), s1), "use not refilled at its stair is gone: casting more than you bank adds nothing")
	_check(not U.USE.has("climb_cap"), "no cap a climb on growth by use: banked essence and strain hold the pace")
	var q = _prof()
	U.set_size(q, "hand", 40.0)
	U.put(q, "hand", "blade", 40.0)
	U.note_use(q, "hand", 99999.0, "cast")
	var bank := 200.0
	U.settle_into(q, "hand", "blade", bank)
	var grew: float = U.size(q, "hand") - 40.0
	_check(grew > 0.0 and grew <= bank * U.LEVEL_SIZE / float(U.GROW_COST[4]) + 0.01, "spamming casts grows a Node only as far as the essence banked into it refills (%.1f size from %d banked)" % [grew, int(bank)])
	U.end_stair(q)
	U.note_use(q, "hand", 99999.0, "cast")
	var s2: float = U.size(q, "hand")
	U.settle_into(q, "hand", "blade", 99999.0)
	_check(U.size(q, "hand") > s2 + 18.0, "...with essence enough, it grows past the old 18 a climb (%.1f to %.1f)" % [s2, U.size(q, "hand")])
	U.note_use(q, "heart", 100.0, "cast")
	_check(U.used(q, "heart") == 0.0, "a sleeping Node isn't used")
	# Attributes from the Nodes' sizes.
	var a = _prof()
	U.put(a, "legs", "air", 60.0)
	U.put(a, "hand", "blade", 40.0)
	U.put(a, "hand", "air", 20.0)
	_check(is_equal_approx(U.attr_size(a, "air"), 60.0 + 20.0) and is_equal_approx(U.attr_size(a, "blade"), 40.0), "attributes count each awake Node's size for the essences it holds, by share (Air %.0f, Blade %.0f)" % [U.attr_size(a, "air"), U.attr_size(a, "blade")])
	_check(a.attribute("air") > a.attribute("blade") and a.attribute("blade") > 0.0 and a.attribute("stone") == 0.0 and a.attribute("air") < a.ATTRIBUTE_CAP, "...and give the Unbound their bonuses (Agility +%.1f%%)" % (a.attribute("air") * 100.0))
	a.density = {"stone": 9999.0}
	_check(a.attribute("stone") == 0.0, "the old banked density no longer counts for the Unbound")
	U.put(a, "brow", "fire", 20.0)
	_check(U.attr_size(a, "fire") == 0.0, "a sleeping Node counts for nothing")


func _rising(a: Array) -> bool:
	for i in range(1, a.size()):
		if float(a[i]) <= float(a[i - 1]):
			return false
	return true


func _moving() -> void:
	var p = _prof()
	U.put(p, "legs", "air", 60.0)
	U.put(p, "hand", "blade", 60.0)
	U.set_size(p, "hand", 120.0)
	var c0: float = p.crystal_total("air")
	var got: Dictionary = U.move(p, "air", "legs", "hand", 12.0)
	_check(got["ok"] and is_equal_approx(U.amount(p, "legs", "air"), 48.0) and is_equal_approx(U.amount(p, "hand", "air"), 9.0), "moving 12 Air from the legs to the hand: 9 arrive, a quarter is the price")
	_check(p.crystal_total("air") >= c0 + 2.0, "...before a path, the price condenses into crystals (%s)" % got["line"])
	_check(is_equal_approx(U.size(p, "legs"), 60.0) and is_equal_approx(U.size(p, "hand"), 120.0), "moving never changes a Node's size")
	var h0: float = U.size(p, "heart")
	var fed: Dictionary = U.move(p, "air", "legs", "heart", 6.0)
	_check(fed["ok"] and U.size(p, "heart") > h0 and U.own(p, "heart") == 0.0 and String(fed["line"]).contains("sleeping"), "moved into a sleeping Node, it soaks in and brings it closer to waking: %s" % fed["line"])
	p.path = "life"
	var f0: float = float(p.flow)
	U.move(p, "air", "legs", "hand", 8.0)
	_check(float(p.flow) > f0 + 1.9, "...on the Making path, it turns into core essence (%.1f)" % float(p.flow))
	p.path = "unmaking"
	var total0: float = U.own(p, "legs") + U.own(p, "hand")
	var f1: float = float(p.flow)
	U.move(p, "air", "legs", "hand", 8.0)
	_check(is_equal_approx(U.own(p, "legs") + U.own(p, "hand"), total0 - 2.0) and is_equal_approx(float(p.flow), f1), "...on the Unmaking path, it is unmade")
	var q = _prof()
	U.put(q, "hand", "fire", 60.0)
	U.put(q, "hand", "stone", 20.0)
	U.put(q, "hand", "air", 20.0)
	U.set_size(q, "hand", 120.0)
	U.put(q, "legs", "water", 30.0)
	var bad: Dictionary = U.move(q, "water", "legs", "hand", 6.0)
	_check(not bad["ok"] and String(bad["line"]).contains("three") and is_equal_approx(U.amount(q, "legs", "water"), 30.0), "a move the target's rules won't take is refused, and nothing moves: %s" % bad["line"])
	var d: Dictionary = U.move(p, "air", "legs", "", 6.0)
	_check(d["ok"] and String(d["line"]).contains("crystals"), "draining sends it to crystals: %s" % d["line"])


func _core() -> void:
	_check(Core.RATE > 0.0 and Core.RATE < 1.0, "core essence settles much more slowly than it's carried (%.0f%%)" % (Core.RATE * 100.0))
	var big: float = 0.0
	for k in Secret.drop("beast", "kraken", 12):
		big = maxf(big, float(Secret.drop("beast", "kraken", 12)[k]) + float(Secret.drop("shadow", "kraken", 6).get(k, 0.0)))
	_check(big * Core.RATE < 20.0, "a summit's beast and shadow settle under 20 core essence (%.1f): it grows slowly" % (big * Core.RATE))
	# A marked climber: spread evenly, up to six full parts.
	var m = load("res://scripts/profile.gd").new()
	m.saving = false
	m.path = "life"
	var res: Dictionary = Core.bank(m, 60.0)
	_check(is_equal_approx(float(m.flow), 60.0 * Core.RATE) and Core.PARTS.all(func(pt): return is_equal_approx(Core.in_part(m, pt), 5.0)), "banked, it settles evenly in all six parts (5 each)")
	_check(String(res["lines"][0]).begins_with("Banked 60 Making"), "...and says so: %s" % res["lines"][0])
	Core.bank(m, 99999.0)
	_check(is_equal_approx(float(m.flow), Core.CAP * 6.0) and Core.saturated(m), "it stops once the body is saturated (%d)" % int(m.flow))
	var more: Dictionary = Core.bank(m, 50.0)
	_check(is_equal_approx(float(m.flow), Core.CAP * 6.0) and String(more["lines"][0]).contains("saturated"), "...past that, nothing more settles: %s" % more["lines"][0])
	# The Unbound: it takes room in each part, and only the room left.
	var p = _prof()
	p.path = "life"
	U.put(p, "hand", "blade", 110.0)
	Core.bank(p, 120.0)
	_check(is_equal_approx(Core.in_part(p, "hand"), 10.0) and Core.PARTS.all(func(pt): return Core.in_part(p, pt) <= Core.CAP - U.own(p, pt) + 0.01), "spread as evenly as each part's room allows (the hand has only 10)")
	_check(is_equal_approx(float(p.flow), 60.0) and Core.PARTS.filter(func(pt): return pt != "hand").all(func(pt): return is_equal_approx(Core.in_part(p, pt), 10.0)), "...the rest spread over the other parts")
	_check(is_equal_approx(U.fill(p, "legs"), 10.0) and U.room(p, "hand") == 0.0 and U.take_limit(p, "hand", "blade") == 0.0, "it fills parts too, and your own essence can't push it out")
	var cap: float = Core.capacity(p)
	Core.bank(p, 99999.0)
	_check(is_equal_approx(float(p.flow), cap) and Core.saturated(p), "an Unbound body saturates sooner: own essence and core share each part")
	p.flow = 0.0
	Core.sync(p)
	_check(Core.PARTS.all(func(pt): return Core.in_part(p, pt) < 0.01), "core per part follows the body's total (dev tools, old saves)")


func _core_led() -> void:
	var p = _prof()
	p.path = "unmaking"
	U.put(p, "legs", "air", 70.0)
	Core.bank(p, 120.0)
	_check(not U.core_led(p, "legs") and U.tech_weights(p, "legs").has("unmaking"), "the core adds its own touch to every technique")
	U.move(p, "air", "legs", "", 60.0)
	_check(U.core_led(p, "legs") and U.lead(p, "legs") == "unmaking", "drained until the core is at least half, it leads the part: core-led")
	Core.add(p, 40.0, "legs")
	_check(U.tech_ready(p, "legs") and U.tech_kinds(p, "legs")[0] == "unmaking", "...its technique is led by the core (%s)" % str(U.tech_kinds(p, "legs")))
	U.sync_techs(p)
	var lt: Dictionary = U.tech_of(p, U.PARTS.find("legs"))
	_check(bool(lt.get("core", false)) and T.title(lt) == String(U.CORE_TECHS["legs"]["unmaking"]), "a core technique, with its own name (%s)" % T.title(lt))
	_check(is_equal_approx(U.core_power(p, "legs"), float(U.CORE_POWER[0])), "half full, a core technique hits %.1fx as hard" % float(U.CORE_POWER[0]))
	var own0: float = U.own(p, "legs")
	var lines: Array = U.absorb(p)
	_check(U.own(p, "legs") < own0 and not lines.is_empty(), "at each stair the core slowly absorbs the part's other essence (%.1f to %.1f)" % [own0, U.own(p, "legs")])
	U.set_size(p, "legs", 120.0)
	Core.add(p, 999.0, "legs")
	_check(U.level(p, "legs") == 12 and is_equal_approx(U.core_power(p, "legs"), float(U.CORE_POWER[1])), "full, %.1fx" % float(U.CORE_POWER[1]))


func _pure() -> void:
	var p = _prof()
	U.put(p, "legs", "air", 119.0)
	_check(not U.pure(p, "legs") and not ("blink" in TR.owned_forms(p, "legs")), "not yet full: no signature")
	U.put(p, "legs", "air", 1.0)
	_check(U.pure(p, "legs") and U.signature(p, "legs").get("name", "") == "Blink" and "blink" in TR.owned_forms(p, "legs"), "pure Air fills the legs: Blink, its signature, opens as a form")
	var q = _prof()
	U.put(q, "legs", "air", 100.0)
	U.put(q, "legs", "stone", 20.0)
	_check(not U.pure(q, "legs") and not ("blink" in TR.owned_forms(q, "legs")), "with a second essence in it, no signature")
	var hand_sig: Dictionary = U.SIGNATURES.get("hand:blade", {})
	_check(not hand_sig.has("form"), "the other signatures are still to come (Coming soon)")
	var nodes: Array = TR.unbound_nodes(p, "legs")
	_check(nodes.map(func(n): return int(n["at"])) == [1, 3, 5, 6, 7, 8, 9, 10, 11, 12], "the tree: the minor ability, the young technique, the gift, the full technique, forks, new forms and the capstone (%s)" % str(nodes.map(func(n): return n["at"])))
	var last: Dictionary = nodes[-1]
	_check(last["options"].size() == 2 and last["options"][1].get("form", "") == "blink" and last["options"][1]["state"] == "owned", "...the last node holds the capstone and, pure, the signature")


func _aura() -> void:
	_check(Secret.STEPS.size() == 6 and _rising(Secret.STEPS), "the aura grows in six steps (%s)" % str(Secret.STEPS))
	var ok := true
	for path in Secret.EFFECTS:
		for k in Secret.EFFECTS[path]:
			ok = ok and Secret.EFFECTS[path][k].size() == 6
		ok = ok and Secret.STEP_TEXT[path].size() == 6
	_check(ok, "each of the aura's bonuses (today's Making and Unmaking steps) is set for all six steps")
	_check(Secret.effect("life", "refuse", 5) == false and Secret.effect("life", "refuse", 6) == true and Secret.effect("unmaking", "pierce", 4) == true, "the strongest bonuses come last")
	_check(Secret.display("life") == "Making" and Secret.display("unmaking") == "Unmaking", "the core essences are Making and Unmaking")


## The pace of the Nodes, in climbs (tests/progression_model.gd run_unbound:
## the game's own bookkeeping over climbs of measured essence).
func _pace() -> void:
	var M = load("res://tests/progression_model.gd")
	var typ: Dictionary = M.run_unbound("typical", 45)
	var main_part := "legs"  # (the own tower's kind, Air, flows to the Legs Node)
	var aw := int(typ["awake"][main_part])
	_check(aw >= MAIN_AWAKE[0] and aw <= MAIN_AWAKE[1], "a typical Unbound's main Node wakes after %d climb (%d to %d)" % [aw, MAIN_AWAKE[0], MAIN_AWAKE[1]])
	var top := int(typ["top"][main_part])
	_check(top >= MAIN_TOP[0] and top <= MAIN_TOP[1], "...and reaches level 12 after %d climbs (%d to %d)" % [top, MAIN_TOP[0], MAIN_TOP[1]])
	var others: Array = U.PARTS.filter(func(pt): return pt != main_part)
	var late: int = others.map(func(pt): return int(typ["awake"][pt])).max()
	var soon: int = others.map(func(pt): return int(typ["awake"][pt])).min()
	_check(soon >= OTHERS_AWAKE[0] and late <= OTHERS_AWAKE[1] and others.all(func(pt): return int(typ["awake"][pt]) > 0), "each other Node wakes after %d to %d climbs, its own kind flowing to it (%d to %d)" % [soon, late, OTHERS_AWAKE[0], OTHERS_AWAKE[1]])
	var spam: Dictionary = M.run_unbound("typical", 45, "spam")
	_check(int(spam["top"][main_part]) >= top - 2, "spamming casts doesn't race ahead: level 12 after %d climbs (typical %d)" % [int(spam["top"][main_part]), top])
	var idle: Dictionary = M.run_unbound("typical", 45, "none")
	_check(float(idle["sizes"][44][main_part]) < float(typ["sizes"][9][main_part]), "never using it, a Node grows only from summits' condensing: size %.0f after 45 climbs (%.0f used, after 10)" % [float(idle["sizes"][44][main_part]), float(typ["sizes"][9][main_part])])
	var fast: Dictionary = M.run_unbound("summits", 30)
	var ft := int(fast["top"][main_part])
	_check(ft >= MAIN_TOP_SUMMITS[0] and ft <= MAIN_TOP_SUMMITS[1], "summiting every climb, level 12 after %d climbs (%d to %d)" % [ft, MAIN_TOP_SUMMITS[0], MAIN_TOP_SUMMITS[1]])
	var routed: Dictionary = M.run_unbound("typical", ROUTED_CLIMBS, "typical", "spread")
	var rl: int = others.map(func(pt): return int(routed["awake"][pt])).max()
	var rs: int = others.map(func(pt): return int(routed["awake"][pt])).min()
	_check(rs >= OTHERS_AWAKE_ROUTED[0] and rl <= OTHERS_AWAKE_ROUTED[1] and rl > 0, "routing essence to them, the others wake after %d to %d climbs (%d to %d)" % [rs, rl, OTHERS_AWAKE_ROUTED[0], OTHERS_AWAKE_ROUTED[1]])
	var all_top: int = U.PARTS.map(func(pt): return int(routed["top"][pt])).max()
	var all_ok: bool = U.PARTS.all(func(pt): return int(routed["top"][pt]) > 0) and all_top >= ALL_TOP[0] and all_top <= ALL_TOP[1]
	_check(all_ok, "all six at level 12 takes %d climbs (%d to %d)" % [all_top, ALL_TOP[0], ALL_TOP[1]])
	# Forcing past full (forcing.gd) never beats playing: force-eating every
	# crystal into the Node it flows to, short of burned, the main Node and
	# all six get to level 12 no sooner than the bands allow.
	var forced: Dictionary = M.run_unbound("typical", 45, "typical", "natural", [], true, "careful")
	var fto := int(forced["top"][main_part])
	_check(fto >= MAIN_TOP[0] and fto <= MAIN_TOP[1] and fto >= top - 1, "a climber who force-eats every crystal: the main Node at level 12 after %d climbs (%d without; %d to %d)" % [fto, top, MAIN_TOP[0], MAIN_TOP[1]])
	var froute: Dictionary = M.run_unbound("typical", ROUTED_CLIMBS, "typical", "spread", [], true, "careful")
	var fall: int = U.PARTS.map(func(pt): return int(froute["top"][pt])).max()
	_check(U.PARTS.all(func(pt): return int(froute["top"][pt]) > 0) and fall >= ALL_TOP[0], "...and all six at level 12 after %d climbs, no sooner than %d (%d without forcing)" % [fall, ALL_TOP[0], all_top])


func _words() -> void:
	var texts: Array = []
	for d in [U.TEXT, Core.TEXT, Secret.TEXT, Secret.STEP_TEXT, U.SIGNATURES, U.CORE_TECHS, U.GIFTS, load("res://scripts/technique_page.gd").TEXT, load("res://scripts/body_move.gd").TEXT]:
		texts.append(str(d).to_lower())
	var E = load("res://scripts/entity.gd")
	for id in ["unbound", "node_asleep", "node_awake", "node_grows", "unbound_essence", "unbound_half", "unbound_full_tech", "unbound_learned", "unbound_full", "unbound_pure", "unbound_core_led", "unbound_body", "unbound_move",
			"aura", "core_essence", "core_saturated", "flow_2", "flow_3", "flow_4", "flow_5", "flow_6"]:
		var e: Dictionary = E.TIPS.get(id, {})
		_check(e.has("tip") and e.has("more") and String(e["tip"]).length() < 140, "the Entity explains '%s' the first time (a short line and an Archive account)" % id)
		texts.append(str(e).to_lower())
	var Talk = load("res://scripts/entity_talk.gd")
	for id in ["how_aura", "how_unbound", "how_nodes", "how_unbound_words"]:
		_check(Talk.DIALOGUE.has(id) and id in Talk.DIALOGUE["how"]["choices"], "'How does it work?' has '%s'" % Talk.DIALOGUE.get(id, {}).get("ask", id))
		texts.append(str(Talk.DIALOGUE.get(id, {})).to_lower())
	var Help = load("res://scripts/entity_help.gd")
	for id in ["ub_part", "ub_part_asleep", "ub_move_from", "ub_move_kind", "ub_move_to", "ub_move", "ub_drain", "ub_body_open", "ub_route"]:
		_check(Help.HELP.has(id), "the move buttons have hover help (%s)" % id)
	var all := " ".join(texts)
	var found: Array = BANNED.filter(func(w): return all.contains(w))
	_check(found.is_empty(), "none of the owner's banned words in the new words (%s)" % ", ".join(found))


## An old profile (an older Unbound, raw density far past a cup, four
## kinds in a part, an old flow) loads without trouble and fits the cups.
func _old_profile() -> void:
	var path := TestRun.path("user://unbound_cup_old.cfg")
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "regarded", true)
	cfg.set_value("profile", "path", "life")
	cfg.set_value("profile", "flow", 400.0)
	cfg.set_value("profile", "part_density", {"hand": {"blade": 780.0, "fire": 50.0, "air": 40.0, "stone": 30.0}, "legs": {"air": 20.0}, "nowhere": 3, "brow": "junk"})
	cfg.set_value("unbound", "state", {"on": true, "techs": [{"name": "", "part": "throat", "shape": "shout", "kinds": ["fire"]}, {}, "junk", {}, {}, {}], "broken": 2})
	cfg.save(path)
	var p = load("res://scripts/profile.gd").new()
	p.saving = false
	p.save_path = path
	p.load_save()
	_check(U.is_on(p) and U.own(p, "hand") <= Core.CAP + 0.01 and U.mix(p, "hand").size() <= U.MAX_KINDS and not p.part_density.has("nowhere"), "an old Unbound's cups are made to fit (the hand: %.0f, %d kinds)" % [U.own(p, "hand"), U.mix(p, "hand").size()])
	_check(float(p.flow) <= Core.capacity(p) + 0.01 and U.level(p, "hand") == 12, "...its old flow fits the body's room (%.0f)" % float(p.flow))
	_check(U.awake(p, "hand") and is_equal_approx(U.size(p, "hand"), 120.0), "...its full hand became a full Hand Node (size 120): no growth lost")
	_check(not U.awake(p, "legs") and is_equal_approx(U.size(p, "legs"), 20.0) and U.own(p, "legs") == 0.0 and p.crystal_total("air") >= 20.0, "...its legs, under 30, sleep, keeping 20 toward waking; the Air they held condenses into crystals")
	var learned: Array = U.sync_techs(p)
	_check(String(U.state(p)["techs"][0].get("part", "")) == "hand" and T.valid(U.tech_of(p, 0)), "...and its slots follow their parts (the hand's slot is the hand's)")
	_check(learned.size() <= 6, "(no crash bringing old slots up to date)")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _in_play() -> void:
	print("the Unbound reworked, in play: the minor ability, Blink, a core technique, the aura")
	await t._ub_fresh()
	var main = t.main
	var p = main.player
	var prof = main.profile
	var run = main.unbound
	p.iframes = 9999.0
	run.waver_chance = 0.0
	_check(p.bonds.size() == 6, "each part half full carries its technique (%d)" % p.bonds.size())
	# The minor ability.
	var slime = await t._spawn("slime", p.global_position + Vector2(40, 0))
	slime.hp = 999.0
	slime.max_hp = 999.0
	run.minor_chance = 1.0
	run.minor_t.clear()
	var hp0: float = slime.hp
	p._part_action("hand", 0.5, 6.0)
	_check(run.minors == 1 and slime.hp < hp0, "the hand's minor ability: a strike carries a touch of its Blade to the foe (%.1f)" % (hp0 - slime.hp))
	p._part_action("hand", 0.5, 6.0)
	_check(run.minors == 1, "...not again until it rests")
	run.minor_chance = 0.0
	# Blink: pure Air legs.
	prof.part_density["legs"] = {"air": 120.0}
	var lt: Dictionary = U.state(prof)["techs"][1]
	lt["shape"] = "blink"
	main._give_bonds()
	var lb = p.bonds["legs"]
	_check(String(lb.tech["shape"]) == "blink", "a pure legs' technique can take Blink's form")
	var from: Vector2 = p.global_position
	p.aim = (main.room.get_center() - from).normalized() if main.room.get_center().distance_to(from) > 1.0 else Vector2.RIGHT
	lb.essence = lb.capacity()
	run.cast(lb, p)
	_check(p.global_position.distance_to(from) > 40.0, "Blink takes you where you aim (%.0f)" % p.global_position.distance_to(from))
	p.global_position = from
	# A core technique (Making leads the heart), and the aura.
	prof.path = "life"
	prof.part_density["heart"] = {}
	U.state(prof)["primary"].erase("heart")
	prof.flow = 0.0
	load("res://scripts/core.gd").add(prof, 60.0, "heart")
	main._give_bonds()
	var hb = p.bonds.get("heart")
	_check(hb != null and bool(hb.tech.get("core", false)) and String(hb.tech["kinds"][0]) == "life", "a core-led heart carries a core technique, led by Making")
	if hb != null:
		hb.essence = hb.capacity()
		run.cast(hb, p)
		_check(run.strain_of("heart") > 0.0, "...and it casts")
	main.dev_add_flow(300.0)
	await t._frames(3)
	_check(p.flow_path == "life" and p.flow_step == 6, "with enough core essence, the aura reaches its last step (%d)" % p.flow_step)
	slime.queue_free()
	await t._frames(1)
