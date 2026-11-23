extends RefCounted
## The Unbound hunted, and the Sworn (unbound.gd drain, sworn.gd,
## guardian_lessons.gd's Summit Blade rule):
##   1. an Unbound's fall drains what their Nodes hold back into the well
##      (DRAIN "share", a trace of each lead kept; sizes, levels and core
##      kept; the marked untouched), the fall screen says so, the Entity
##      explains it and speaks of the Husks after a few;
##   2. now and then one of the Sworn saves a hunted Unbound from a fall
##      (once a climb, never the marked, never the first climb), with a
##      figure and a line;
##   3. a Maker's secret bond makes its Sworn: the climber screen says so
##      (hover help, asks the Entity), errands are sent and paid;
##   4. a Summit Blade's blows teach the guardians only a small share and
##      keep their edge, and a rumour hints at it;
## the Entity's words, the Data editor, old saves, and no banned words.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const U := preload("res://scripts/unbound.gd")
const Sworn := preload("res://scripts/sworn.gd")
const Makers := preload("res://scripts/makers.gd")
const GL := preload("res://scripts/guardian_lessons.gd")
const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

var t


func run(smoke) -> void:
	t = smoke
	print("the Unbound hunted, and the Sworn")
	_drain_rules()
	_status_rules()
	_blade_rules()
	_words()
	await _fall_in_play()
	await _rescue_in_play()
	await _blade_in_play()
	await _sends_in_play()
	await _climber_screen()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _prof():
	var p = load("res://scripts/profile.gd").new()
	p.saving = false
	return p


# --- 1. the drain ---------------------------------------------------------------------------

func _drain_rules() -> void:
	var p = _prof()
	U.become(p)
	U.set_nodes(p, {"legs": {"air": 80.0, "water": 30.0}, "hand": {"blade": 40.0}})
	var s_legs := U.size(p, "legs")
	var s_hand := U.size(p, "hand")
	var lv := U.level(p, "legs")
	var share := float(U.DRAIN["share"])
	var out: Dictionary = U.drain(p)
	var want := (110.0 + 40.0) * share
	_check(absf(float(out["total"]) - want) < 0.5, "a fall drains %d%% of what the Nodes hold back into the well (%.1f of 150)" % [int(round(share * 100.0)), float(out["total"])])
	_check(is_equal_approx(U.size(p, "legs"), s_legs) and is_equal_approx(U.size(p, "hand"), s_hand) and U.level(p, "legs") == lv, "...their sizes and levels are kept")
	_check(U.primary(p, "legs") == "air" and absf(U.amount(p, "legs", "air") - 80.0 * (1.0 - share)) < 0.01 and absf(U.amount(p, "legs", "water") - 30.0 * (1.0 - share)) < 0.01, "...each essence loses the same share, so the lead and the technique stay the same")
	_check(U.tech_ready(p, "legs") and U.awake(p, "legs"), "...a drained Node keeps its technique")
	_check(U.drained_count(p) == 1, "the drained falls are counted (the Husks)")
	_check(U.room(p, "legs") > 50.0, "...and the room is there for the next stairs to refill")
	# A full drain still keeps a trace of the lead.
	var was := float(U.DRAIN["share"])
	U.DRAIN["share"] = 1.0
	var q = _prof()
	U.become(q)
	U.set_nodes(q, {"brow": {"fire": 60.0, "air": 20.0}})
	U.drain(q)
	_check(U.primary(q, "brow") == "fire" and is_equal_approx(U.amount(q, "brow", "fire"), float(U.DRAIN["trace"])) and U.amount(q, "brow", "air") == 0.0 and U.tech_ready(q, "brow"), "drained of everything, a Node keeps a trace of its lead (its shape)")
	U.DRAIN["share"] = was
	# The banked essence refills it at the next stair.
	var before := U.own(p, "legs")
	U.settle(p, "air", 40.0)
	_check(U.own(p, "legs") > before + 30.0, "the next stair's banked essence tops the Node up again")
	# The core essence and the marked are untouched.
	var c = _prof()
	U.become(c)
	c.path = "life"
	c.flow = 60.0
	U.set_nodes(c, {"heart": {"iron": 50.0}})
	load("res://scripts/core.gd").sync(c)
	var core0: float = load("res://scripts/core.gd").total(c)
	U.drain(c)
	_check(core0 > 0.0 and is_equal_approx(load("res://scripts/core.gd").total(c), core0), "the core essence isn't the well's: a drain leaves it (%.0f)" % core0)
	var m = _prof()
	m.part_density = {"hand": {"fire": 20.0}}
	var mo: Dictionary = U.drain(m)
	_check(float(mo["total"]) == 0.0 and float(m.part_density["hand"]["fire"]) == 20.0, "a marked climber has no Nodes to drain")
	_check(String(U.TEXT["fall_drained"]).contains("%d"), "the fall screen's line names how much went")
	# Old saves: no count yet.
	var old = _prof()
	old.unbound = {"on": true}
	_check(U.drained_count(old) == 0, "an old save has drained nothing yet")


# --- 3. status -------------------------------------------------------------------------------

func _status_rules() -> void:
	var p = _prof()
	_check(not Sworn.is_sworn(p) and Sworn.title(p) == "" and Sworn.errand_line(p) == "", "without a secret bond, nobody is Sworn")
	Makers.set_core(p, "designer", 1)
	_check(Sworn.is_sworn(p) and Sworn.maker_of(p) == "towers" and Sworn.title(p).contains("Maker of Towers"), "a Maker's secret bond makes its Sworn: %s" % Sworn.title(p))
	_check(Sworn.errand_line(p) != "" and (Sworn.state(p)["errand"] as Dictionary).is_empty(), "...no errand yet, and the climber screen says one may come")
	_check(String(Makers.TEXT["sworn_line"]).contains("%s"), "the meeting says the climber is one of its Sworn now")
	# Old saves: a Makers state without "sworn".
	var old = _prof()
	old.makers = {"interest": {"marks": 10.0}}
	old.core_mark = "developer"
	old.core_depth = 1
	var st: Dictionary = Sworn.state(old)
	_check(Sworn.is_sworn(old) and st["errand"] is Dictionary and int(st["rescued"]) == 0 and int(st["done"]) == 0, "an old save with a core mark is Sworn, with nothing owed")


# --- 4. Summit Blades -------------------------------------------------------------------------

func _blade_rules() -> void:
	var tally := {"dmg": 0.0, "ess": {}, "forms": {}, "parts": {}, "near": 0.0, "rolls": 0.0, "parries": 0.0}
	# (note_blow reads the tally off the guardian: a stand-in that holds one, far off)
	var fake := _FakeGuardian.new()
	fake.lesson_tally = tally
	fake.global_position = Vector2(99999, 99999)
	GL.note_blow(t.main, fake, 100.0, {"kinds": {"air": 1.0}, "form": "burst", "part": "", "blade": "gryphon"})
	var share := float(GL.LEARN["blade"])
	_check(is_equal_approx(float(tally["dmg"]), 100.0 * share) and is_equal_approx(float(tally.get("blade", 0.0)), 100.0), "a Summit Blade's blow counts for only %d%% of its damage in a lesson" % int(round(share * 100.0)))
	GL.note_blow(t.main, fake, 100.0, {"kinds": {"fire": 1.0}, "form": "shot", "part": "brow"})
	var l := GL.lesson(tally, "the Gryphon")
	_check(float(l["ess"].get("fire", 0.0)) > 0.8 and float(l["ess"].get("air", 0.0)) < float(GL.LEARN["min_share"]) and float(l.get("blade", 0.0)) > 0.4, "...so a climber who fought half with the blade teaches its essence almost nothing (%s)" % str(l))
	var p = _prof()
	p.guardians["gryphon"] = l
	var facts: Array = GL.rumour_facts(p)
	_check(facts.any(func(f): return f["kind"] == "blade") and not GL.RUMOURS["blade"].is_empty(), "a rumour hints that the blades can't be learned")
	var told := ""
	for i in 40:
		var r := GL.rumour(p, i)
		if r.contains("Summit Blade"):
			told = r
			break
	_check(told != "" and not told.contains("{"), "...said in full: %s" % told)
	fake.free()


class _FakeGuardian:
	extends Node2D
	var lesson_tally := {}
	var radius := 20.0


# --- words ---------------------------------------------------------------------------------

func _words() -> void:
	var E = load("res://scripts/entity.gd")
	var Talk = load("res://scripts/entity_talk.gd")
	var Help = load("res://scripts/entity_help.gd")
	var texts: Array = [str(Sworn.TEXT), str(Sworn.RESCUE_LINES), str(Sworn.SEND_LINES), str(U.TEXT["fall_drained"]), str(GL.RUMOURS["blade"]), str(Makers.TEXT["sworn_line"]), str(load("res://scripts/bestiary.gd").BESTIARY["husk"])]
	for id in ["unbound_drained", "unbound_husks", "sworn_rescue", "sworn", "sworn_sent"]:
		var e: Dictionary = E.TIPS.get(id, {})
		_check(e.has("tip") and e.has("more") and String(e["tip"]).length() < 140, "the Entity explains '%s' the first time (a short line and an Archive account)" % id)
		texts.append(str(e))
	_check(String(E.TIPS["unbound_husks"]["tip"]).to_lower().contains("husk") and String(load("res://scripts/bestiary.gd").BESTIARY["husk"]["desc"]).contains("Unbound"), "the Husks: the Entity and the Bestiary say they were Unbound, drained too often")
	for id in ["how_drain", "how_sworn"]:
		_check(Talk.DIALOGUE.has(id) and id in Talk.DIALOGUE["how"]["choices"], "'How does it work?' has '%s'" % String(Talk.DIALOGUE.get(id, {}).get("ask", id)))
		texts.append(str(Talk.DIALOGUE.get(id, {})))
	_check("how_drain" in Talk.DIALOGUE["how_unbound"]["choices"], "...and the Unbound's own topic leads to it")
	var f: Dictionary = Talk.facts(null, {"fact": "rules"})
	var said: String = Talk.fill(String(Talk.DIALOGUE["how_drain"]["lines"][0]), f) + Talk.fill(String(Talk.DIALOGUE["how_sworn"]["lines"][0]), f)
	_check(not said.contains("{") and said.contains("1 in 6") and said.contains("%d%%" % int(round(float(U.DRAIN["share"]) * 100.0))), "...with the game's own numbers (%s)" % said.substr(0, 120))
	_check(Help.HELP.has("sworn"), "the Sworn button has hover and hold help")
	texts.append(str(Help.HELP["sworn"]))
	var Reg = load("res://scripts/data_registry.gd")
	var ids: Array = Reg.SECTIONS.map(func(s): return String(s["id"]))
	var tables: Array = []
	for s in Reg.SECTIONS:
		tables.append_array(s["tables"])
	_check("sworn_words" in ids and "sworn_numbers" in ids and "unbound/DRAIN" in tables, "the words and numbers are in the Data editor")
	var low := " ".join(texts.map(func(s): return String(s))).to_lower()
	for w in BANNED:
		_check(not low.contains(w), "no '%s' in the drain and Sworn words" % w)
	_check(is_equal_approx(float(Sworn.RESCUE["chance"]), 0.167) and float(Sworn.SENDS["reward"]) <= 12.0, "the rescue is now and then (about 1 in 6), an errand pays little (slow growth)")


# --- in play ---------------------------------------------------------------------------------

## An Unbound falls: their Nodes drain, the fall screen says so.
func _fall_in_play() -> void:
	print("the Unbound fall: drained")
	await t._ub_fresh()
	var m = t.main
	var prof = m.profile
	prof.saving = false
	var held := 0.0
	var sizes := {}
	for part in U.PARTS:
		held += U.own(prof, part)
		sizes[part] = U.size(prof, part)
	m.sworn_roll = 1.0  # (nobody comes)
	Engine.set_meta("sixfold_tips", true)
	m.GuideScript.forget()
	m.on_player_died()
	var after := 0.0
	for part in U.PARTS:
		after += U.own(prof, part)
	var kept: bool = U.PARTS.all(func(pt): return is_equal_approx(U.size(prof, pt), float(sizes[pt])))
	_check(held > 0.0 and absf((held - after) - held * float(U.DRAIN["share"])) < 1.0 and kept, "an Unbound's fall drains their Nodes back into the well (%.0f of %.0f), sizes kept" % [held - after, held])
	_check(not m.fall_note.is_empty() and String(m.fall_note[0]).contains("drained") and String(m.fall_note[0]).contains(str(int(round(held - after)))), "...the fall screen's first line says so: %s" % (String(m.fall_note[0]) if not m.fall_note.is_empty() else ""))
	await t._frames(2)
	var told: bool = m.GuideScript.queue.any(func(q): return q.get("id", "") == "unbound_drained") or m.GuideScript.told("unbound_drained")
	_check(told, "...and the Entity explains it the first time")
	U.state(prof)["drained"] = int(U.DRAIN["husk_talk"]) - 1
	m.player.dead = false
	U.set_nodes(prof, {"legs": {"air": 60.0}})
	m.on_player_died()
	await t._frames(2)
	var husk: bool = m.GuideScript.queue.any(func(q): return q.get("id", "") == "unbound_husks") or m.GuideScript.told("unbound_husks")
	_check(husk, "drained again and again, the Entity speaks of the Husks")
	Engine.remove_meta("sixfold_tips")
	m.GuideScript.forget()
	m.GuideScript.queue.clear()


## One of the Sworn steps in: once a climb, only for the Unbound.
func _rescue_in_play() -> void:
	print("one of the Sworn steps in")
	await t._ub_fresh()
	var m = t.main
	var p = m.player
	var prof = m.profile
	prof.saving = false
	_check(not m.proving_spare(), "in a test, nobody comes by chance (a fall stays a fall)")
	m.sworn_roll = 0.0
	var held := 0.0
	for part in U.PARTS:
		held += U.own(prof, part)
	p.iframes = 0.0
	p.hp = 1.0
	p.receive_attack(99999.0, null, true)
	await t._frames(1)
	var figs: Array = m.get_children().filter(func(c): return c.get_script() == Sworn)
	_check(not p.dead and p.hp >= p.max_health() * float(Sworn.RESCUE["health"]) - 0.5 and m.sworn_rescued, "a blow that would fell a hunted Unbound doesn't: one of the Sworn steps in (health %.0f of %.0f)" % [p.hp, p.max_health()])
	_check(p.iframes > 0.5 and String(m.banner.get("title", "")) == Sworn.TEXT["rescue_title"] and m.banner.get("lines", []).size() >= 2, "...a moment untouchable, a banner: who came, and their words (%s)" % str(m.banner.get("lines", [])))
	_check(figs.size() == 1 and is_instance_valid(figs[0]), "...and a cloaked figure beside the climber")
	var after := 0.0
	for part in U.PARTS:
		after += U.own(prof, part)
	_check(is_equal_approx(held, after) and int(Sworn.state(prof)["rescued"]) == 1, "...nothing is drained, and the rescue is remembered")
	var line: String = String(m.banner["lines"][1])
	_check(not line.contains("{"), "...said with the climber's pronouns: %s" % line)
	# Once a climb.
	p.iframes = 0.0
	p.hp = 1.0
	_check(not m.proving_spare(), "at most once a climb")
	m._note_climb_start()
	_check(not m.sworn_rescued, "a new climb, and they may come again")
	# Never the marked, never the first climb.
	m.first_climb = true
	_check(not Sworn.try_rescue(m, 0.0), "never on the first climb")
	m.first_climb = false
	U.state(prof)["on"] = false
	_check(not Sworn.try_rescue(m, 0.0), "only for the Unbound")
	U.state(prof)["on"] = true
	await t._frames(2)
	if not figs.is_empty() and is_instance_valid(figs[0]):
		figs[0].t = 99.0
		await t._frames(2)
		_check(not is_instance_valid(figs[0]) or figs[0].is_queued_for_deletion(), "the figure goes after a few seconds")
	m.sworn_roll = -1.0


## A guardian that learned Fire takes a Summit Blade's Fire blow nearly whole.
func _blade_in_play() -> void:
	print("a Summit Blade keeps its edge")
	await t._fresh_main()
	var m = t.main
	var p = m.player
	var prof = m.profile
	prof.saving = false
	p.iframes = 9999.0
	prof.guardians = {"gryphon": GL.lesson({"dmg": 300.0, "ess": {"fire": 300.0}, "forms": {"burst": 300.0}, "parts": {}, "near": 150.0, "rolls": 0.0, "parries": 0.0}, "the Gryphon")}
	m.tower = "kraken"
	var k = await t._spawn("kraken", p.global_position + Vector2(260, 0))
	if k == null or not is_instance_valid(k):
		return
	k.submerged = false
	k.max_hp = 5000.0
	k.hp = 5000.0
	k.stun = 5.0
	var h0: float = k.hp
	m.blow_ctx = {"kinds": {"fire": 1.0}, "form": "burst", "part": ""}
	k.take_hit(100.0, Vector2.LEFT)
	var plain: float = h0 - k.hp
	var h1: float = k.hp
	m.blow_ctx = {"kinds": {"fire": 1.0}, "form": "burst", "part": "", "blade": "firebird"}
	k.take_hit(100.0, Vector2.LEFT)
	m.blow_ctx = {}
	var bladed: float = h1 - k.hp
	_check(plain > 0.0 and bladed > plain + 1.0, "a guardian that learned Fire resists a Fire blow (%.0f) but a Summit Blade's keeps its edge (%.0f)" % [plain, bladed])
	var tally: Dictionary = k.lesson_tally
	var blade_raw := float(tally.get("blade", 0.0))
	var counted := float(tally.get("dmg", 0.0))
	_check(blade_raw > 0.0 and counted < blade_raw * 1.5, "...and the blade's blow teaches it only a small share (%s)" % str(tally))
	if is_instance_valid(k):
		k.queue_free()
	await t._frames(1)


## A Maker sends its Sworn: an errand at a climb's end, paid when reached.
func _sends_in_play() -> void:
	print("a Maker sends its Sworn")
	await t._fresh_main()
	var m = t.main
	var prof = m.profile
	prof.saving = false
	m.tower = "gryphon"
	_check(Sworn.on_climb_end(m, 0.0) == "", "nobody sends a climber who isn't Sworn")
	Makers.set_core(prof, "manipulator", 1)
	_check(Sworn.on_climb_end(m, 0.99) == "", "not every climb")
	var said := Sworn.on_climb_end(m, 0.0)
	var e: Dictionary = Sworn.state(prof)["errand"]
	_check(said != "" and String(e.get("tower", "")) != "gryphon" and int(e["floor"]) >= int(Sworn.SENDS["floor_min"]) and int(e["floor"]) <= int(Sworn.SENDS["floor_max"]), "now and then the Maker sends its Sworn to another tower: %s" % said)
	_check(Sworn.on_climb_end(m, 0.0) == "", "...one errand at a time")
	m.tower = String(e["tower"])
	m.floor_num = int(e["floor"]) - 1
	_check(Sworn.on_arrive(m) == "", "...not done below its floor")
	var kind := String(load("res://scripts/towers.gd").TOWERS[String(e["tower"])]["essence"])
	var c0: float = prof.crystal_total(kind)
	m.floor_num = int(e["floor"])
	var done := Sworn.on_arrive(m)
	_check(done != "" and is_equal_approx(prof.crystal_total(kind) - c0, float(Sworn.SENDS["reward"])) and (Sworn.state(prof)["errand"] as Dictionary).is_empty() and int(Sworn.state(prof)["done"]) == 1, "reaching it pays %d crystals of that tower's essence: %s" % [int(Sworn.SENDS["reward"]), done])
	Makers.set_core(prof, "", 0)


## The climber screen names the Maker, with hover help; pressing asks the Entity.
func _climber_screen() -> void:
	print("the Sworn on the climber screen")
	await t._fresh_main()
	var m = t.main
	var menu = m.menu
	var prof = m.profile
	prof.saving = false
	Makers.set_core(prof, "developer", 1)
	m.on_train = true
	menu.climber_tab = "marks"
	menu.open("climber")
	await t._frames(3)
	var bs: Array = t._all_buttons(menu).filter(func(b): return b.is_visible_in_tree() and b.get_meta("help", "") == "sworn")
	_check(bs.size() == 1 and String(bs[0].text).contains("Maker of Marks"), "the climber screen says whose Sworn the climber is")
	if bs.size() == 1:
		bs[0].pressed.emit()
		await t._frames(2)
		_check(menu.page == "talk" and menu.talk.node == "how_sworn", "...and pressing it asks the Entity who the Sworn are")
	menu.close()
	await t._frames(2)
	Makers.set_core(prof, "", 0)
