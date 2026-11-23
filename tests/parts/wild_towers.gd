extends RefCounted
## Wild towers (wild_towers.gd): beating a guardian makes its tower wild
## (from the record, so an old save's beaten towers are wild too); a wild
## tower's floors of rooms have storms that warn before they strike (not
## floor 1, the Proving or the summit); a strike that catches a marked
## climber burns a mark a rung on the marks' own ladder (burned, then
## paralyzed, never burned out), and feeds an Unbound instead (capped a
## floor); monsters are empowered within the caps, finds bumped within the
## caps; the map's sign, the Entity's help, moments and topic; the cities
## talk; the third well stirs the Makers; wild towers stay playable after
## the ending; no banned words. Run by smoke_test.gd (_part_tests).

const W := preload("res://scripts/wild_towers.gd")
const Towers := preload("res://scripts/towers.gd")
const Entity := preload("res://scripts/entity.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const Floors := preload("res://scripts/floors.gd")
const Unbound := preload("res://scripts/unbound.gd")
const TestRun := preload("res://scripts/test_run.gd")
const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

var t


## A stand-in climber for the ladder: only its marks.
class FakeClimber:
	var bonds := {}


func run(smoke) -> void:
	t = smoke
	print("wild towers: a beaten guardian's well runs wild")
	W.test_on = true
	_rules()
	_ladder()
	_words()
	_old_save()
	await _guardian_falls()
	await _storms_marked()
	await _storms_unbound()
	await _after_ending()
	W.test_on = false
	Floors.wild_tough = Vector2.ONE


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _prof():
	var p = load("res://scripts/profile.gd").new()
	p.saving = false
	return p


func _fresh() -> void:
	await t._fresh_main()
	t.paused = false
	t.main.profile.saving = false


func _still() -> void:
	for e in t.main.enemies():
		e.set_physics_process(false)


## Takes the floor's monsters away (so no slain one's essence muddles a count).
func _clear() -> void:
	for e in t.main.enemies():
		e.remove_from_group("enemies")
		e.queue_free()
	t.main.foes_changed()
	await t._frames(1)


# --- the rules --------------------------------------------------------------------------------

func _rules() -> void:
	var p = _prof()
	_check(W.wild_list(p).is_empty() and not W.is_wild(p, "gryphon"), "no tower is wild before its guardian falls")
	p.record["beasts_by"] = {"gryphon": 1}
	_check(W.is_wild(p, "gryphon") and not W.is_wild(p, "kraken") and W.wells(p) == 1, "the Gryphon beaten: its tower is wild, the others aren't")
	var cap := float(W.POWER["cap"])
	_check(float(W.POWER["health"]) > 1.0 and float(W.POWER["health"]) <= cap and float(W.POWER["damage"]) > 1.0 and float(W.POWER["damage"]) <= cap and cap <= 1.25,
		"empowered monsters stay beatable: %d%% more health, %d%% more damage, never past %d%%" % [int(round((float(W.POWER["health"]) - 1.0) * 100.0)), int(round((float(W.POWER["damage"]) - 1.0) * 100.0)), int(round((cap - 1.0) * 100.0))])
	var rc := float(W.REWARD["cap"])
	_check(float(W.REWARD["essence"]) <= 1.15 and float(W.REWARD["cache"]) <= 1.25 and float(W.REWARD["gear"]) <= rc and float(W.REWARD["items"]) <= rc and rc <= 1.5,
		"richer finds stay modest: %d%% more essence from a kill, %d%% more in a cache (slow growth)" % [int(round((float(W.REWARD["essence"]) - 1.0) * 100.0)), int(round((float(W.REWARD["cache"]) - 1.0) * 100.0))])
	var climb_most := float(W.FEED["per_floor"]) * float(Towers.SUMMIT - int(W.STORM["from"]))
	_check(climb_most <= 72.0 and float(W.FEED["amount"]) <= float(W.FEED["per_floor"]), "wild essence for the Unbound is capped: %d a floor, at most %d a climb" % [int(W.FEED["per_floor"]), int(climb_most)])
	_check(int(W.STORM["cells"]) in [3, 6] and int(W.FEED["per_floor"]) % 6 == 0 and W.MAKERS_AT == 3 and int(W.STORM["scars"]) % 6 == 0, "sixes: three rings a storm, six wild essence a floor, the third well stirs the Makers")
	_check(float(W.STORM["warn"]) >= 1.5 and float(W.STORM["gap_min"]) >= 20.0, "storms warn %.1f seconds before they strike, and never come more often than every %d seconds" % [float(W.STORM["warn"]), int(W.STORM["gap_min"])])
	W.test_on = false
	_check(not W.is_wild(p, "gryphon"), "(off in other tests, as the stair's barriers are: their slain beasts change nothing)")
	W.test_on = true


## Wild essence burns a marked climber's marks on their own ladder.
func _ladder() -> void:
	var Bond = load("res://scripts/bond.gd")
	var p = _prof()
	p.add_bond("hand", "stormcaller", false)
	var c := FakeClimber.new()
	c.bonds["hand"] = Bond.new("stormcaller", "hand")
	var one: Dictionary = W.scorch(p, c)
	_check(String(one.get("rung", "")) == "burned" and c.bonds["hand"].burned and not c.bonds["hand"].paralyzed, "a strike burns a lit mark: burned (the marks' own ladder)")
	var two: Dictionary = W.scorch(p, c)
	_check(String(two.get("rung", "")) == "paralyzed" and c.bonds["hand"].paralyzed, "...a second one paralyzes it")
	var three: Dictionary = W.scorch(p, c)
	_check(three.is_empty() and not p.bonds["hand"].has("dark") and int(p.count("burnouts")) == 0, "...and a third passes it by: wild essence never burns a mark out by itself")
	var u = _prof()
	Unbound.become(u)
	_check(W.scorch(u, c).is_empty(), "an Unbound has no marks to burn")


# --- words ------------------------------------------------------------------------------------

func _words() -> void:
	var tm: Dictionary = Entity.TIPS.get("wild_tower", {})
	var tu: Dictionary = Entity.TIPS.get("wild_tower_unbound", {})
	_check(not tm.is_empty() and not tu.is_empty() and String(tm["tip"]).length() <= 170 and String(tu["tip"]).length() <= 170, "the Entity has a first-time moment for entering a wild tower, marked or Unbound")
	_check(String(tm["tip"]).contains("burns marks") and String(tu["tip"]).contains("feeds you"), "...marked: it burns marks, careful; Unbound: it feeds you")
	var how: Array = Talk.DIALOGUE["how"]["choices"]
	_check("how_wild" in how and String(Talk.DIALOGUE["how_wild"]["ask"]) == "Wild towers?", "its \"How does it work?\" topic: Wild towers?")
	var p = _prof()
	p.record["beasts_by"] = {"gryphon": 1, "wyvern": 1}
	var line := Talk.fill(String(Talk.DIALOGUE["how_wild"]["lines"][0]), W.talk_facts(p))
	_check(not line.contains("{") and line.contains("2 wells run wild") and line.contains("Gryphon") and line.contains("no mark"), "...filled from the game: %s" % line.substr(0, 90))
	p.add_bond("hand", "stormcaller", false)
	var marked := Talk.fill(String(Talk.DIALOGUE["how_wild"]["lines"][0]), W.talk_facts(p))
	var u = _prof()
	u.record["beasts_by"] = {"gryphon": 1}
	Unbound.become(u)
	var unb := Talk.fill(String(Talk.DIALOGUE["how_wild"]["lines"][0]), W.talk_facts(u))
	_check(marked.contains("burns marks") and unb.contains("feeds you") and unb.contains("%d at most a floor" % int(W.FEED["per_floor"])), "...in the marked climber's words and in the Unbound's")
	_check(W.help_line(p, "gryphon") != "" and W.help_line(p, "kraken") == "" and String(load("res://scripts/entity_help.gd").HELP["tower"]).contains("{wild_line}"), "the map's hover help says a tower runs wild")
	var all := JSON.stringify([W.TEXT, W.RUMOURS, tm, tu, Talk.DIALOGUE["how_wild"]])
	var bad: Array = BANNED.filter(func(w): return RegEx.create_from_string("\\b" + w + "\\b").search(all.to_lower()) != null)
	_check(bad.is_empty(), "no banned words in the wild towers' words (%s)" % [bad])
	# The cities talk.
	var Noble = load("res://scripts/noble.gd")
	var home: String = Noble.greet(p, 0.0, "gryphon")
	var away: String = Noble.greet(p, 0.0, "kraken")
	var D = load("res://scripts/dining.gd")
	var f: Dictionary = D.fact(p, "wild", "kraken", "")
	_check(home.contains("Gryphon") and not away.contains("Gryphon's Tower"), "the Noble of a city by a wild tower always speaks of it: %s" % home)
	_check(not f.is_empty() and (String(f["rumour"]).contains("Gryphon") or String(f["rumour"]).contains("Wyvern") or String(f["rumour"]).contains("Windhollow") or String(f["rumour"]).contains("Forgehaven")), "...so do the Dining car's climbers: %s" % f.get("rumour", ""))
	_check(W.crest_word(p, "gryphon") != "" and W.crest_word(p, "kraken") == "", "...and the station's crest says its tower runs wild")
	_check(D.fact(_prof(), "wild", "kraken", "").is_empty() and W.rumour(_prof()) == "", "no word of wild towers while none is wild")
	var Reg = load("res://scripts/data_registry.gd")
	_check(not Reg.field("wild_towers/STORM/warn").is_empty() and not Reg.field("wild_towers/POWER/cap").is_empty() and not Reg.fields_in("wild_words").is_empty(), "the wild towers' numbers and words are in the Data editor")


# --- old saves --------------------------------------------------------------------------------

func _old_save() -> void:
	var path := TestRun.path("user://wild_towers_old.cfg")
	var old := ConfigFile.new()
	old.set_value("profile", "climbs", 9)
	old.set_value("profile", "regarded", true)
	old.set_value("profile", "record", {"beasts": 2.0, "beasts_by": {"wyvern": 2, "kraken": 1}})
	old.save(path)
	var p = _prof()
	p.save_path = path
	p.load_save()
	_check(W.is_wild(p, "wyvern") and W.is_wild(p, "kraken") and not W.is_wild(p, "gryphon"), "an old save's beaten guardians: those towers are simply wild")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# --- in play ----------------------------------------------------------------------------------

func _guardian_falls() -> void:
	print("wild towers: a guardian falls")
	await _fresh()
	var m = t.main
	var prof = m.profile
	m.grant_test_bonds()
	prof.record.erase("beasts_by")
	m.player.iframes = 9999.0
	m.tower = "gryphon"
	var g = await t._spawn("gryphon", m.player.global_position + Vector2(260, 0))
	if g != null:
		t._slay(g)
		await t._frames(2)
	_check(W.is_wild(prof, "gryphon") and m.wild.news.any(func(l): return String(l).contains("runs wild")), "beating the Gryphon makes its tower wild, and the summit's lines say so (%s)" % [m.wild.news])
	m.wild.news.clear()
	prof.record["beasts_by"]["kraken"] = 1
	m.tower = "wyvern"
	var w = await t._spawn("wyvern", m.player.global_position + Vector2(260, 0))
	if w != null:
		t._slay(w)
		await t._frames(2)
	_check(W.wells(prof) == 3 and m.wild.news.any(func(l): return String(l).contains("Makers stir")) and prof.count("wild_makers") == 1, "the third well gone wild stirs the Makers (%s)" % [m.wild.news])
	var lines: Array = m.wild.summit_lines()
	_check(lines.size() >= 1 and m.wild.news.is_empty(), "...said once, at the summit")
	m.player.iframes = 0.0


func _storms_marked() -> void:
	print("wild towers: storms, marked")
	await _fresh()
	var m = t.main
	var prof = m.profile
	m.grant_test_bonds()
	prof.record["beasts_by"] = {"gryphon": 1}
	m.tower = "gryphon"
	Engine.set_meta("sixfold_tips", true)
	m.GuideScript.forget()
	m._start_floor(4)
	await t._frames(2)
	_still()
	var told: bool = m.GuideScript.queue.any(func(q): return q.get("id", "") == "wild_tower")
	Engine.remove_meta("sixfold_tips")
	m.GuideScript.forget()
	m.GuideScript.queue.clear()
	var wd = m.wild
	_check(wd.here and wd.on and told, "a wild tower's floor of rooms has storms, and the Entity explains it the first time")
	var tough: Vector2 = W.tough(m)
	_check(is_equal_approx(tough.x, float(W.POWER["health"])) and Floors.wild_tough == tough and tough.x <= float(W.POWER["cap"]) and tough.y <= float(W.POWER["cap"]), "its monsters are empowered, within the cap (%s)" % str(tough))
	var a = m.spawn_enemy("slime", m.player.global_position + Vector2(400, 0))
	Floors.wild_tough = Vector2.ONE
	var b = m.spawn_enemy("slime", m.player.global_position + Vector2(420, 60))
	Floors.wild_tough = tough
	_check(is_instance_valid(a) and is_instance_valid(b) and is_equal_approx(float(a.max_hp) / float(b.max_hp), tough.x), "...a slime there has %d%% more health than the same slime in a plain tower" % int(round((tough.x - 1.0) * 100.0)))
	_check(W.reward(m, "essence") > 1.0 and W.reward(m, "essence") <= float(W.REWARD["cap"]) and W.reward(m, "gear") <= float(W.REWARD["cap"]), "...and its finds are a little richer, within the cap")
	await _clear()
	var p = m.player
	p.iframes = 0.0
	p.hp = p.max_health()
	# A storm gathers: rings, one under the climber, and a warning first.
	wd.gather()
	_check(wd.cells.size() == int(W.STORM["cells"]) and wd.cells[0]["pos"].distance_to(p.global_position) < 1.0 and float(wd.cells[0]["warn"]) >= 1.5, "a storm gathers: %d rings, one under the climber, %.1f seconds of warning" % [wd.cells.size(), float(wd.cells[0]["warn"])])
	var hp0: float = p.hp
	await t._ticks(10)
	_check(is_equal_approx(p.hp, hp0) and not wd.cells.is_empty(), "...nothing strikes while the rings warn")
	var foe = m.spawn_enemy("slime", wd.cells[1]["pos"])
	if is_instance_valid(foe):
		foe.set_physics_process(false)
	var foe_hp: float = foe.hp if is_instance_valid(foe) else 0.0
	var burned_before: int = p.bonds.values().filter(func(x): return x.burned).size()
	wd.strike_all()
	await t._frames(1)
	var burned_after: int = p.bonds.values().filter(func(x): return x.burned).size()
	_check(p.hp < hp0 and wd.hits == 1, "a strike hurts the climber standing in its ring (%d)" % int(hp0 - p.hp))
	_check(burned_after == burned_before + 1, "...and wild essence burns one of their marks a rung")
	_check(not is_instance_valid(foe) or foe.dead or foe.hp < foe_hp, "...it strikes monsters in its rings too: lure them in")
	_check(wd.cells.is_empty() and wd.next_t >= float(W.STORM["gap_min"]) - 0.01, "...then the storm passes for a while (%.0f s)" % wd.next_t)
	# Dodged: a roll's iframes, or out of the ring.
	wd.gather()
	var hp1: float = p.hp
	p.hurt_t = 0.0  # (a hit's own moment of grace has passed)
	p.iframes = 1.0
	wd.strike_all()
	_check(is_equal_approx(p.hp, hp1) and wd.hits == 1, "a roll through the strike dodges it")
	p.iframes = 0.0
	p.hurt_t = 0.0
	wd.gather()
	p.global_position = p.global_position + Vector2(float(W.STORM["radius"]) * 3.0, 0.0)
	wd.cells = wd.cells.slice(0, 1)
	wd.strike_all()
	_check(is_equal_approx(p.hp, hp1) and wd.hits == 1, "...so does stepping out of the ring")
	# Floor 1, the Proving and the summit stay calm.
	m.floor_num = 1
	wd.setup_floor({})
	var calm1: bool = wd.here and not wd.on
	m.floor_num = 6
	wd.setup_floor({"proving": true})
	var calm6: bool = not wd.on
	m.floor_num = int(Towers.SUMMIT)
	wd.setup_floor({})
	var calm12: bool = not wd.on
	_check(calm1 and calm6 and calm12, "no storms on floor 1, the Proving or the summit (the guardian is fought fair)")
	# A plain tower: no storms, no bumps.
	m.tower = "kraken"
	m._start_floor(3)
	await t._frames(2)
	_still()
	_check(not m.wild.here and not m.wild.on and Floors.wild_tough == Vector2.ONE and W.reward(m, "essence") == 1.0, "a tower whose guardian stands: no storms, plain monsters, plain finds")
	m.tower = "gryphon"
	m._start_floor(3)
	await t._frames(2)
	_still()
	var rv = m.rivals
	var keep: float = float(rv.RULES.get("wild_chance", 0.5))
	var keep2: float = float(rv.RULES.get("rumour_chance", 0.5))
	rv.RULES["wild_chance"] = 1.0
	rv.RULES["rumour_chance"] = 0.0
	var said: String = rv._line("trade", {})
	rv.RULES["wild_chance"] = keep
	rv.RULES["rumour_chance"] = keep2
	_check(said.count("\"") >= 4, "a climber met in a wild tower speaks of it: %s" % said)
	m.open_train()
	await t._frames(2)
	_check(Floors.wild_tough == Vector2.ONE, "off the climb, the Bestiary's numbers are plain again")
	if m.menu != null and m.menu.is_open():
		m.menu.close()
	await t._frames(1)


func _storms_unbound() -> void:
	print("wild towers: storms, Unbound")
	await _fresh()
	var m = t.main
	var prof = m.profile
	Unbound.become(prof)
	prof.regarded = true
	m.first_climb = false
	m._give_bonds()
	prof.record["beasts_by"] = {"gryphon": 1}
	m.tower = "gryphon"
	Engine.set_meta("sixfold_tips", true)
	m.GuideScript.forget()
	m._start_floor(3)
	await t._frames(2)
	_still()
	var told: bool = m.GuideScript.queue.any(func(q): return q.get("id", "") == "wild_tower_unbound")
	Engine.remove_meta("sixfold_tips")
	m.GuideScript.forget()
	m.GuideScript.queue.clear()
	_check(m.wild.on and told, "an Unbound in a wild tower: storms, and the Entity's Unbound moment")
	await _clear()
	var p = m.player
	p.iframes = 0.0
	p.hp = p.max_health()
	var kind := String(m.tower_data()["essence"])
	var e0 := float(m.run_essence.get(kind, 0.0))
	var full := float(W.STORM["dmg"]) + float(W.STORM["per_floor"]) * 3.0
	var hp0: float = p.hp
	m.wild.gather()
	m.wild.strike_all()
	var took: float = hp0 - p.hp
	var e1 := float(m.run_essence.get(kind, 0.0))
	_check(took > 0.0 and took <= full * float(W.STORM["unbound_dmg"]) + 0.01, "a strike still stings an Unbound, half as much (%.1f of %.1f)" % [took, full])
	_check(is_equal_approx(e1 - e0, float(W.FEED["amount"])), "...and wild essence feeds them: +%d %s to carry to the stair, for their Nodes" % [int(e1 - e0), kind])
	for i in 4:
		p.hp = p.max_health()
		p.iframes = 0.0
		p.hurt_t = 0.0  # (a hit's own moment of grace has passed)
		m.wild.gather()
		m.wild.strike_all()
	var e2 := float(m.run_essence.get(kind, 0.0))
	_check(is_equal_approx(e2 - e0, float(W.FEED["per_floor"])), "...at most %d a floor however often they're caught (slow growth)" % int(e2 - e0))


func _after_ending() -> void:
	print("wild towers: after the ending")
	await _fresh()
	var m = t.main
	var prof = m.profile
	m.grant_test_bonds()
	var by := {}
	for tid in Towers.ORDER:
		by[tid] = 1
	prof.record["beasts_by"] = by
	prof.record["ending"] = 1.0
	m.tower = "chimera"
	m._start_floor(5)
	await t._frames(2)
	_still()
	_check(m.wild.here and m.wild.on and not m.climb_shape.ending_due() and not m.enemies().is_empty() and m.floor_plan.has("rooms"), "after the ending, every tower is wild and still climbable: a floor of rooms, monsters, storms")
	_check(W.wells(prof) == 6, "six wells run wild")
