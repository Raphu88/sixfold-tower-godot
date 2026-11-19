extends RefCounted
## The reworked Unbound (unbound.gd), core essence (core.gd) and the aura
## (secret.gd): body parts fill like cups of 120, a level every 10 (12),
## the primary kept at least half and three kinds at most, the minor
## ability at 3, a technique at 6 (half full), the capstone and a pure
## part's signature at 12 (Blink); moving essence at a price; core essence
## banked slowly, spread evenly, stopping once the body is saturated,
## core-led parts and their core technique; the aura's six steps; growth
## kept slow (the pace of a part, in climbs); the Entity's words for all of
## it; and an old profile loads without trouble.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.
const TestRun := preload("res://scripts/test_run.gd")

const U := preload("res://scripts/unbound.gd")
const Core := preload("res://scripts/core.gd")
const Secret := preload("res://scripts/secret.gd")
const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

## Climbs (after the first) before the own tower's natural part reaches a
## level: [least, most]. A typical climber (half the climbs in that tower, a
## summit every other climb), and one who summits that tower every climb.
const TYPICAL := {3: [1, 2], 6: [2, 4], 12: [36, 56]}
const SUMMITS := {6: [1, 2], 12: [12, 22]}

var t
var T
var TR


func run(smoke) -> void:
	t = smoke
	T = load("res://scripts/technique.gd")
	TR = load("res://scripts/tree.gd")
	print("the Unbound reworked: cups, core essence, the aura")
	_cups()
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
	_check(U.MAX_LEVEL == 12 and is_equal_approx(Core.CAP, 120.0) and U.LEVELS.size() == 12 and is_equal_approx(U.LEVELS[11], 120.0), "a part holds 120, a level every 10, 12 levels")
	_check(U.MINOR_LEVEL == 3 and U.TECH_LEVEL == 6 and U.LEVELS[U.TECH_LEVEL - 1] == 60.0, "the minor ability at level 3 (30), techniques at 6 (60, half full), the capstone at 12 (full)")
	# The first essence leads; another may come in only while the first stays at least half.
	U.put(p, "hand", "fire", 30.0)
	_check(U.primary(p, "hand") == "fire" and is_equal_approx(U.take_limit(p, "hand", "stone"), 30.0), "the first essence in a part leads it; another may grow to match it (30)")
	_check(is_equal_approx(U.put(p, "hand", "stone", 50.0), 30.0) and is_equal_approx(U.amount(p, "hand", "stone"), 30.0), "...no further: the lead stays at least half")
	_check(U.take_limit(p, "hand", "air") == 0.0 and U.why_not(p, "hand", "air") != "", "a third kind needs room for the lead's half (%s)" % U.why_not(p, "hand", "air"))
	U.put(p, "hand", "fire", 30.0)
	_check(U.put(p, "hand", "air", 10.0) > 0.0 and U.mix(p, "hand") == ["fire", "stone", "air"], "with the lead grown, a third comes in: three kinds, the lead first")
	U.put(p, "hand", "fire", 6.0)
	_check(U.take_limit(p, "hand", "water") == 0.0 and U.why_not(p, "hand", "water").contains("three"), "a fourth kind can't come in")
	# Slow, slower as it fills; never past full.
	var q = _prof()
	var left: float = U.settle_into(q, "legs", "air", float(U.FILL_COST[0]))
	_check(left < 0.01 and is_equal_approx(U.fill(q, "legs"), U.LEVEL_SIZE), "%d banked essence fill the first 10" % int(U.FILL_COST[0]))
	_check(_rising(U.FILL_COST), "each level costs more banked essence than the last (%s)" % str(U.FILL_COST))
	left = U.settle_into(q, "legs", "air", 999999.0)
	_check(is_equal_approx(U.fill(q, "legs"), Core.CAP) and left > 0.0 and U.level(q, "legs") == 12, "a part never fills past 120: the rest is left over")
	var r = _prof()
	r.part_density = {"legs": {"air": 120.0}}
	U.state(r)["primary"] = {"legs": "air"}
	var held: float = r.crystal_total("air")
	r.pour({"air": 100.0}, {}, 0.0)
	_check(r.crystal_total("air") >= held + 99.0, "banked into a full part, it condenses into crystals instead (essence is never lost)")
	# Levels bring their pieces.
	var s = _prof()
	U.put(s, "brow", "fire", 29.0)
	_check(not U.has_minor(s, "brow") and U.minor_text(s, "brow").contains("3"), "below level 3, no minor ability yet")
	U.put(s, "brow", "fire", 1.0)
	_check(U.has_minor(s, "brow") and U.minor_text(s, "brow").contains("parries") and U.minor_text(s, "brow").contains("Fire"), "at level 3 it wakes: %s" % U.minor_text(s, "brow"))
	_check(U.sync_techs(s).is_empty() and U.tech_of(s, U.PARTS.find("brow")).is_empty(), "below half full, no technique")
	U.put(s, "brow", "fire", 30.0)
	var learned: Array = U.sync_techs(s)
	var bt: Dictionary = U.tech_of(s, U.PARTS.find("brow"))
	_check(learned == ["brow"] and T.valid(bt) and bt["shape"] == "mark" and bt["kinds"] == ["fire"], "half full, the part learns its first form by itself (%s)" % T.title(bt))
	_check(U.sync_techs(s).is_empty(), "...once")
	U.put(s, "hand", "fire", 60.0)
	U.sync_techs(s)
	_check(T.title(U.tech_of(s, 0)) == "Flame Fist", "its name comes from the form and the essence: Fire and the fists, Flame Fist (%s)" % T.title(U.tech_of(s, 0)))
	_check(is_equal_approx(U.power(s, "hand"), 1.0) and U.has_gift(s, "hand"), "a technique starts at its base strength at level 6 (the gift came at 5)")
	U.put(s, "hand", "fire", 60.0)
	_check(is_equal_approx(U.power(s, "hand"), U.MAX_POWER) and load("res://scripts/spells/unbound_forms.gd").capstone_on(s, "hand"), "full, it hits %dx as hard and its capstone wakes" % int(U.MAX_POWER))
	# A modifier's touch grows with its share.
	var w = _prof()
	U.put(w, "throat", "water", 60.0)
	U.put(w, "throat", "stone", 15.0)
	var small: float = U.tech_weights(w, "throat")["stone"]
	U.put(w, "throat", "stone", 30.0)
	_check(U.tech_weights(w, "throat")["water"] == 1.0 and U.tech_weights(w, "throat")["stone"] > small, "a modifier acts more the bigger its share (%.2f, then %.2f)" % [small, U.tech_weights(w, "throat")["stone"]])


func _rising(a: Array) -> bool:
	for i in range(1, a.size()):
		if float(a[i]) <= float(a[i - 1]):
			return false
	return true


func _moving() -> void:
	var p = _prof()
	U.put(p, "legs", "air", 60.0)
	U.put(p, "hand", "blade", 60.0)
	var c0: float = p.crystal_total("air")
	var got: Dictionary = U.move(p, "air", "legs", "hand", 12.0)
	_check(got["ok"] and is_equal_approx(U.amount(p, "legs", "air"), 48.0) and is_equal_approx(U.amount(p, "hand", "air"), 9.0), "moving 12 Air from the legs to the hand: 9 arrive, a quarter is the price")
	_check(p.crystal_total("air") >= c0 + 2.0, "...before a path, the price condenses into crystals (%s)" % got["line"])
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
	U.put(p, "legs", "air", 60.0)
	Core.bank(p, 120.0)
	_check(not U.core_led(p, "legs") and U.tech_weights(p, "legs").has("unmaking"), "the core adds its own touch to every technique")
	U.move(p, "air", "legs", "", 50.0)
	_check(U.core_led(p, "legs") and U.lead(p, "legs") == "unmaking", "drained until the core is at least half, it leads the part: core-led")
	Core.add(p, 40.0, "legs")
	_check(U.awake(p, "legs") and U.tech_kinds(p, "legs")[0] == "unmaking", "...its technique is led by the core (%s)" % str(U.tech_kinds(p, "legs")))
	U.sync_techs(p)
	var lt: Dictionary = U.tech_of(p, U.PARTS.find("legs"))
	_check(bool(lt.get("core", false)) and T.title(lt) == String(U.CORE_TECHS["legs"]["unmaking"]), "a core technique, with its own name (%s)" % T.title(lt))
	_check(is_equal_approx(U.core_power(p, "legs"), float(U.CORE_POWER[0])), "half full, a core technique hits %.1fx as hard" % float(U.CORE_POWER[0]))
	var own0: float = U.own(p, "legs")
	var lines: Array = U.absorb(p)
	_check(U.own(p, "legs") < own0 and not lines.is_empty(), "at each stair the core slowly absorbs the part's other essence (%.1f to %.1f)" % [own0, U.own(p, "legs")])
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
	_check(nodes.map(func(n): return int(n["at"])) == [3, 5, 6, 7, 8, 9, 10, 11, 12], "the tree: the minor ability, the gift, forms, forks, new forms and the capstone (%s)" % str(nodes.map(func(n): return n["at"])))
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


## The pace of an Unbound part, in climbs: the own tower's natural part,
## from the measured essence a climb banks (tests/progression_model.gd).
func _pace() -> void:
	var M = load("res://tests/progression_model.gd")
	var typ := _climbs_to(M, M.PATTERNS["typical"])
	for lv in TYPICAL:
		var c := int(typ.get(lv, 999))
		_check(c >= int(TYPICAL[lv][0]) and c <= int(TYPICAL[lv][1]), "a typical Unbound's main part reaches level %d after %d climbs (%d to %d)" % [lv, c, TYPICAL[lv][0], TYPICAL[lv][1]])
	var fast := _climbs_to(M, M.PATTERNS["summits"])
	for lv in SUMMITS:
		var c := int(fast.get(lv, 999))
		_check(c >= int(SUMMITS[lv][0]) and c <= int(SUMMITS[lv][1]), "summiting that tower every climb, level %d after %d climbs (%d to %d)" % [lv, c, SUMMITS[lv][0], SUMMITS[lv][1]])


func _climbs_to(M, pattern: Array) -> Dictionary:
	var Flow = load("res://scripts/essence_flow.gd")
	var share: float = 1.0 - Flow.default_crystal_share()
	var kind: String = "air"
	var mix: float = float(M.MIX[M.OWN_TOWER].get(kind, 0.0))
	var p = _prof()
	# The bondless first climb (3 floors) came into the body first.
	U.settle_into(p, "legs", kind, (M.ESSENCE[0] + M.ESSENCE[1] + M.ESSENCE[2]) * share * mix)
	var out := {}
	for i in 80:
		var c: Dictionary = pattern[i % pattern.size()]
		var top := int(c["top"])
		var banked := 0.0
		for f in (top if top == 12 else top - 1):
			banked += float(M.ESSENCE[f])
		var own_mix: float = mix if bool(c["own"]) else 0.04
		U.settle_into(p, "legs", kind, banked * share * own_mix)
		var lv := U.level(p, "legs")
		for want in [3, 6, 9, 12]:
			if lv >= want and not out.has(want):
				out[want] = i + 1
	return out


func _words() -> void:
	var texts: Array = []
	for d in [U.TEXT, Core.TEXT, Secret.TEXT, Secret.STEP_TEXT, U.SIGNATURES, U.CORE_TECHS, U.GIFTS]:
		texts.append(str(d).to_lower())
	var E = load("res://scripts/entity.gd")
	for id in ["unbound", "unbound_fill", "unbound_minor", "unbound_half", "unbound_learned", "unbound_full", "unbound_pure", "unbound_core_led", "unbound_move",
			"aura", "core_essence", "core_saturated", "flow_2", "flow_3", "flow_4", "flow_5", "flow_6"]:
		var e: Dictionary = E.TIPS.get(id, {})
		_check(e.has("tip") and e.has("more") and String(e["tip"]).length() < 140, "the Entity explains '%s' the first time (a short line and an Archive account)" % id)
		texts.append(str(e).to_lower())
	var Talk = load("res://scripts/entity_talk.gd")
	for id in ["how_aura", "how_unbound", "how_unbound_words"]:
		_check(Talk.DIALOGUE.has(id) and id in Talk.DIALOGUE["how"]["choices"], "'How does it work?' has '%s'" % Talk.DIALOGUE.get(id, {}).get("ask", id))
		texts.append(str(Talk.DIALOGUE.get(id, {})).to_lower())
	var Help = load("res://scripts/entity_help.gd")
	for id in ["ub_move_from", "ub_move_kind", "ub_move_to", "ub_move", "ub_route"]:
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
