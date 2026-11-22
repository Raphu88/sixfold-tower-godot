extends RefCounted
## The guardians learn from each other's deaths (guardian_lessons.gd): a
## guardian notes how it's fought and, slain, leaves a lesson in the profile;
## a later guardian resists the killer's essences and favoured Node, braces
## against favoured forms, sidesteps shots (never while staggered), keeps
## its distance or presses in, and varies its wind-ups against a parrier;
## never immune (every blow loses at most the cap), and it adds up across
## kills; mixing up the style beats it; the guardian's own lesson isn't its
## own to apply; rumour lines (the Dining car, rival climbers, the Noble)
## say what the lessons hold; the Entity is vague; it saves and loads; no
## banned words. Run by smoke_test.gd (_part_tests).

const TestRun := preload("res://scripts/test_run.gd")
const GL := preload("res://scripts/guardian_lessons.gd")
const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

var t


func run(smoke) -> void:
	t = smoke
	print("the guardians learn from each other's deaths")
	_lesson_rules()
	_effects()
	_rumours()
	_words()
	await _in_play()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _prof():
	var p = load("res://scripts/profile.gd").new()
	p.saving = false
	return p


## A pure Fire caster's lesson: bolts from the Brow Node, at range, parrying a lot.
func _fire_lesson(beast := "the Gryphon") -> Dictionary:
	return GL.lesson({"dmg": 300.0, "ess": {"fire": 300.0}, "forms": {"shot": 300.0}, "parts": {"brow": 300.0}, "near": 30.0, "rolls": 2.0, "parries": 9.0}, beast)


func _lesson_rules() -> void:
	var l := GL.lesson({"dmg": 200.0, "ess": {"fire": 120.0, "water": 10.0}, "forms": {"shot": 150.0, "weapon": 50.0}, "parts": {"brow": 150.0}, "near": 40.0, "rolls": 3.0, "parries": 1.0}, "the Gryphon")
	_check(is_equal_approx(float(l["ess"]["fire"]), 0.6) and not l["ess"].has("water") and is_equal_approx(float(l["forms"]["shot"]), 0.75) and is_equal_approx(float(l["near"]), 0.2),
		"a lesson keeps how its killer fought, as shares of the damage: Fire 60%%, shots 75%%, 20%% up close; a sliver of Water teaches nothing (%s)" % str(l))
	_check(int(l["rolls"]) == 3 and int(l["parries"]) == 1 and l["parts"].has("brow"), "...the rolls, the parries and the Node leaned on")
	_check(GL.lesson({"dmg": 0.0}).is_empty(), "a guardian that took no blows teaches nothing")


func _effects() -> void:
	var p = _prof()
	_check(GL.effects(p, "kraken")["count"] == 0 and GL.reduction(GL.effects(p, "kraken"), {"kinds": {"fire": 1.0}, "form": "shot", "part": "brow"}) == 0.0, "before any guardian falls, none has learned anything")
	p.guardians["gryphon"] = _fire_lesson()
	var fx := GL.effects(p, "kraken")
	var fire_shot := {"kinds": {"fire": 1.0}, "form": "shot", "part": "brow"}
	var r1 := GL.reduction(fx, fire_shot)
	_check(fx["count"] == 1 and float(fx["resist"]["fire"]) > 0.1 and r1 > 0.0, "the Gryphon fell to Fire: the Kraken resists Fire now (%.0f%% off a Fire bolt from the Brow)" % (r1 * 100.0))
	_check(GL.effects(p, "gryphon")["count"] == 0, "...a guardian doesn't apply its own lesson: it teaches the others")
	_check(float(fx["sidestep"]) > 0.0 and float(fx["press"]) > 0.0 and float(fx["keep"]) == 0.0 and float(fx["timing"]) > 0.0,
		"...sidesteps shots now and then, presses in on a climber who hangs back, and varies its wind-ups against a parrier (%s)" % str(fx))
	var water_strike := {"kinds": {"water": 1.0}, "form": "close", "part": "hand"}
	_check(GL.reduction(fx, water_strike) == 0.0, "mixing up your style beats it: a Water blow up close from another Node loses nothing")
	# It adds up.
	p.guardians["wyvern"] = _fire_lesson("the Wyvern")
	var fx2 := GL.effects(p, "kraken")
	var r2 := GL.reduction(fx2, fire_shot)
	_check(fx2["count"] == 2 and r2 > r1 + 0.05, "each kill makes the rest harder against the same style: %.0f%%, then %.0f%%" % [r1 * 100.0, r2 * 100.0])
	for tw in ["manticore", "firebird", "chimera"]:
		p.guardians[tw] = _fire_lesson("the " + tw.capitalize())
	var fx5 := GL.effects(p, "kraken")
	var r5 := GL.reduction(fx5, fire_shot)
	_check(fx5["count"] == 5 and r5 <= float(GL.LEARN["cap"]) + 0.0001 and r5 > 0.0, "never immune: every lesson together takes at most %d%% off a blow (%.0f%%)" % [int(float(GL.LEARN["cap"]) * 100.0), r5 * 100.0])
	_check(float(fx5["sidestep"]) <= float(GL.LEARN["sidestep_cap"]) + 0.0001 and float(fx5["timing"]) <= float(GL.LEARN["timing_cap"]) + 0.0001 and float(fx5["press"]) <= float(GL.LEARN["steer_cap"]) + 0.0001,
		"...and each of its other habits is capped (sidestep %.0f%%, wind-ups up to %.0f%% longer)" % [float(fx5["sidestep"]) * 100.0, float(fx5["timing"]) * 100.0])
	# A melee killer: it keeps its distance; a blade's swing is braced.
	var q = _prof()
	q.guardians["chimera"] = GL.lesson({"dmg": 300.0, "ess": {}, "forms": {"weapon": 300.0}, "parts": {}, "near": 290.0, "rolls": 15.0, "parries": 0.0}, "the Chimera")
	var fq := GL.effects(q, "gryphon")
	_check(float(fq["keep"]) > 0.0 and float(fq["press"]) == 0.0 and float(fq["guard"].get("weapon", 0.0)) > 0.0, "a killer who fought up close with a blade: the next guardian keeps its distance and braces against the blade (%s)" % str(fq))
	_check(float(fq["timing"]) > 0.0, "...and a heavy roller makes its wind-ups vary a little too")


func _rumours() -> void:
	var p = _prof()
	_check(GL.rumour(p) == "" and GL.rumour_facts(p).is_empty(), "no rumours before any guardian has fallen")
	p.guardians["gryphon"] = _fire_lesson()
	var facts: Array = GL.rumour_facts(p)
	var kinds: Array = facts.map(func(f): return String(f["kind"]))
	_check("essence" in kinds and "shot" in kinds and "press" in kinds and "timing" in kinds and "part" in kinds, "the rumours follow the lesson: its essence, its shots, its range, its parries, its Node (%s)" % str(kinds))
	var all_text: Array = []
	var blanks := false
	for i in 24:
		var r := GL.rumour(p, i)
		all_text.append(r)
		blanks = blanks or r.contains("{") or r == ""
	_check(not blanks, "every rumour is filled in (%s)" % all_text[0])
	_check(all_text.any(func(r): return r.contains("Fire")) and all_text.any(func(r): return r.contains("Gryphon")), "they name the essence the guardians shrug off now, and the guardian that fell (%s)" % all_text.filter(func(r): return r.contains("Fire")).slice(0, 1))
	_check(not all_text.any(func(r): return r.contains("Gryphon shrugs") or r.begins_with("\"They say Gryphon")), "...and it's always another guardian that learned it")
	var D = load("res://scripts/dining.gd")
	var f: Dictionary = D.fact(p, "guardians", "kraken", "")
	_check(not f.is_empty() and String(f["rumour"]).length() > 8, "the Dining car's climbers can tell it: %s" % f.get("rumour", ""))
	var N = load("res://scripts/noble.gd")
	var g: String = N.greet(p, 1.0)
	_check(g.length() > String(N.line("greet")).length() and facts.size() > 0 and g.contains("\""), "so can the Noble: %s" % g)
	_check(N.greet(_prof(), 1.0).length() > 0 and not N.greet(_prof(), 1.0).contains("guardians:"), "...who has nothing of the kind to say before any guardian falls")


func _words() -> void:
	var E = load("res://scripts/entity.gd")
	var Talk = load("res://scripts/entity_talk.gd")
	var tip: Dictionary = E.TIPS.get("guardians_talk", {})
	_check(tip.has("tip") and tip.has("more") and String(tip["tip"]).length() < 140, "the Entity has a first-time moment when the first guardian falls")
	var digits := RegEx.create_from_string("[0-9%]")
	_check(String(tip["tip"]).contains("talk") and digits.search(str(tip)) == null, "...vague: the guardians talk when one falls, no numbers (%s)" % tip.get("tip", ""))
	var topic: Dictionary = Talk.DIALOGUE.get("how_guardians", {})
	_check(not topic.is_empty() and "how_guardians" in Talk.DIALOGUE["how"]["choices"] and digits.search(str(topic.get("lines", []))) == null, "...and a vague 'How does it work?' topic (%s)" % topic.get("ask", ""))
	var texts := (str(GL.TEXT) + str(GL.RUMOURS) + str(tip) + str(topic) + str(load("res://scripts/noble.gd").LINES)).to_lower()
	var found: Array = BANNED.filter(func(w): return texts.contains(w))
	_check(found.is_empty(), "none of the owner's banned words in the guardians' lessons (%s)" % ", ".join(found))


## In play: a guardian notes how it's fought, and slain it leaves its
## lesson; the next one resists that style, sidesteps (never while
## staggered), and still takes every other blow in full.
func _in_play() -> void:
	print("the guardians learn, in play")
	await t._fresh_main()
	var m = t.main
	var p = m.player
	var prof = m.profile
	prof.saving = false
	prof.guardians = {}
	p.iframes = 9999.0
	m.tower = "gryphon"
	var g = await t._spawn("gryphon", p.global_position + Vector2(260, 0))
	if g == null:
		return
	_check(GL.is_guardian(m, g) and GL.of(m, g)["count"] == 0, "the first guardian has learned nothing yet: a focused build fights it with what it has")
	var hp0: float = g.hp
	m.blow_ctx = {"kinds": {"fire": 1.0}, "form": "shot", "part": "brow"}
	g.take_hit(40.0, Vector2.LEFT)
	_check(is_equal_approx(g.hp, hp0 - 40.0), "...it takes the blow in full")
	g.take_hit(40.0, Vector2.LEFT)
	m.blow_ctx = {}
	GL.note_parry(m, g)
	_check(float(g.lesson_tally.get("dmg", 0.0)) >= 80.0 and float(g.lesson_tally["ess"].get("fire", 0.0)) >= 80.0 and float(g.lesson_tally["parries"]) == 1.0, "it watches: the damage, its essence, the parries (%s)" % str(g.lesson_tally))
	Engine.set_meta("sixfold_tips", true)
	m.GuideScript.forget()
	m.blow_ctx = {"kinds": {"fire": 1.0}, "form": "shot", "part": "brow"}
	t._slay(g)
	m.blow_ctx = {}
	await t._frames(2)
	var told: bool = m.GuideScript.queue.any(func(q): return q.get("id", "") == "guardians_talk") or m.GuideScript.told("guardians_talk")
	Engine.remove_meta("sixfold_tips")
	m.GuideScript.forget()
	m.GuideScript.queue.clear()
	var l: Dictionary = prof.guardians.get("gryphon", {})
	_check(not l.is_empty() and float(l["ess"].get("fire", 0.0)) > 0.9 and float(l["forms"].get("shot", 0.0)) > 0.9 and l["parts"].has("brow"), "slain, the Gryphon leaves a lesson in the profile: Fire bolts from the Brow (%s)" % str(l))
	_check(float(l.get("dmg", 0.0)) <= hp0 + 1.0, "...an overkill counts only what it took (%d of %d)" % [int(l.get("dmg", 0)), int(hp0)])
	_check(told, "...and the Entity says, the first time, that the guardians talk when one falls")
	# The next guardian.
	m.tower = "kraken"
	var k = await t._spawn("kraken", p.global_position + Vector2(260, 0))
	if k == null:
		return
	k.submerged = false
	k.max_hp = 5000.0  # (room for every blow below)
	k.hp = 5000.0
	var fx: Dictionary = GL.of(m, k)
	_check(fx["count"] == 1 and float(fx["resist"].get("fire", 0.0)) > 0.0, "the Kraken learned from the Gryphon's death")
	k.stun = 5.0  # (staggered: it can't sidestep)
	var h1: float = k.hp
	m.blow_ctx = {"kinds": {"fire": 1.0}, "form": "shot", "part": "brow"}
	var dodged := 0
	for i in 20:
		var before: float = k.hp
		k.take_hit(10.0, Vector2.LEFT)
		if is_equal_approx(k.hp, before):
			dodged += 1
	var fire_took: float = h1 - k.hp
	_check(dodged == 0 and fire_took < 200.0 - 1.0 and fire_took >= 200.0 * (1.0 - float(GL.LEARN["cap"])) - 0.5, "it resists the Fire bolts that felled the Gryphon (%.0f of 200), never sidestepping while staggered" % fire_took)
	var h2: float = k.hp
	m.blow_ctx = {"kinds": {"water": 1.0}, "form": "close", "part": "hand"}
	for i in 20:
		k.take_hit(10.0, Vector2.LEFT)
	_check(is_equal_approx(h2 - k.hp, 200.0), "a Water blow up close from the Hand lands in full: changing your style beats its lessons (%.0f of 200)" % (h2 - k.hp))
	k.stun = 0.0
	k.open_t = 0.0
	m.blow_ctx = {"kinds": {"fire": 1.0}, "form": "shot", "part": "brow"}
	dodged = 0
	for i in 60:
		var b2: float = k.hp
		k.take_hit(1.0, Vector2.LEFT)
		if is_equal_approx(k.hp, b2):
			dodged += 1
	m.blow_ctx = {}
	_check(dodged > 0 and dodged < 60, "on its feet it sidesteps a Fire bolt now and then, not always (%d of 60)" % dodged)
	var w: float = GL.wind(m, k, 1.0)
	_check(w >= 1.0 and w <= 1.0 + float(GL.LEARN["timing_cap"]) + 0.001, "its wind-ups may run a little longer against a parrier (%.2f s for 1 s); the glint still warns" % w)
	k.velocity = Vector2.ZERO
	k.state = "recover"
	GL.steer(m, k, Vector2.RIGHT, 300.0)
	_check(k.velocity.x > 0.0, "against a killer who hung back, it presses in between its attacks")
	k.queue_free()
	await t._frames(1)
	# Saved and loaded.
	var path := TestRun.path("user://guardian_lessons_test.cfg")
	var sp = load("res://scripts/profile.gd").new()
	sp.save_path = path
	sp.guardians = {"gryphon": _fire_lesson()}
	sp.save()
	var lp = _prof()
	lp.save_path = path
	lp.load_save()
	_check(lp.guardians.has("gryphon") and is_equal_approx(float(lp.guardians["gryphon"]["ess"]["fire"]), 1.0), "the lessons are saved and loaded")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var op = _prof()
	op.save_path = path
	var old := ConfigFile.new()
	old.set_value("profile", "climbs", 4)
	old.save(path)
	op.load_save()
	_check(op.guardians.is_empty(), "an old save: no guardian has learned anything")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	# The Proving's shadow of a beast is no guardian.
	var sh = await t._spawn("wyvern", p.global_position + Vector2(260, 0))
	if sh != null:
		sh.shade = true
		_check(not GL.is_guardian(m, sh), "the Proving's shadow of a beast is no guardian: it neither learns nor teaches")
		sh.queue_free()
	await t._frames(1)
	# A rival climber in the tower passes it on.
	prof.guardians = {"gryphon": _fire_lesson()}
	var keep: float = float(m.rivals.RULES.get("rumour_chance", 0.5))
	m.rivals.RULES["rumour_chance"] = 1.0
	var said: String = m.rivals._line("trade", {})
	m.rivals.RULES["rumour_chance"] = keep
	_check(GL.rumour_facts(prof).size() > 0 and said.count("\"") >= 4, "a rival climber met in the tower passes on a rumour: %s" % said)
	prof.guardians = {}
	p.iframes = 0.0
