extends RefCounted
## The story's scenes (story_scenes.gd, story_view.gd): the three Makers at a
## climber's first Regard (marked, and refused: their own lines; skippable;
## once per climber), the Makers' plea once the third guardian falls (after
## the summit, or at the next stair; each answer recorded and moving the
## Makers' interest and the Entity's next line; "stop" ends nothing), the
## final meeting after the sixth (the Entity seen; Ascend and Fight need a
## second press; Not yet waits), the ending's pages by choice (the marked and
## the Unbound hear different truths; a Sworn climber takes their Maker's
## place), the title and greetings after it, the story music in every scene,
## touch, pronouns, no banned words, and everything fitting 800x400. Run by
## smoke_test.gd (_part_tests); `t` is the smoke test.

const Story := preload("res://scripts/story_scenes.gd")
const Music := preload("res://scripts/music.gd")
const Makers := preload("res://scripts/makers.gd")
const Towers := preload("res://scripts/towers.gd")
const Unbound := preload("res://scripts/unbound.gd")
const Entity := preload("res://scripts/entity.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const Guide := preload("res://scripts/guide.gd")
const Pronouns := preload("res://scripts/pronouns.gd")
const Renown := preload("res://scripts/renown.gd")

const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]
const SMALL := Vector2(800, 400)

var t


func run(smoke) -> void:
	t = smoke
	print("the story's scenes: the Makers at the Regard, their plea, the final meeting and the ending")
	Story.force_on = true
	await _regard(false)
	await _regard(true)
	await _plea()
	await _final("ascend", false, false, true)
	await _final("fight", true, false, false)
	await _final("ascend", true, true, false)
	await _final("fight", false, false, false)
	_pronouns()
	_words()
	Story.force_on = false


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _fresh() -> void:
	await t._fresh_main()
	t.paused = false
	t.main.touch._set_active(false)
	t.main.pad._set_active(false)


func _story() -> bool:
	return Music.place_of(t.main) == "story"


# --- 1. the Makers at the Regard ------------------------------------------------------------

func _regard(refused: bool) -> void:
	await _fresh()
	var main = t.main
	var p = main.player
	main.profile.appearance["pronouns"] = "she"
	for i in 5:
		main.add_soak("legs", 3.0)
	main.gather_essence("air", 30.0, p.global_position)
	if refused:
		main.unbound.broke_rules = true  # (a barrier broken on the first climb: the guardian refuses)
	main.floor_num = 5
	main.run_essence = {}
	main._arrive()
	await t._frames(3)
	var rg: Dictionary = main.regard
	var what := "refused" if refused else "marked"
	_check(not rg.is_empty() and rg.get("refused", false) == refused, "(the first Regard opens, %s)" % what)
	if not refused:
		_check(main.Fracture.active(rg) and rg.has("makers") and not main.regard_done(), "the first Regard: the glimpse of the fracture first, the Makers after it")
		main.Fracture.finish(rg)
	_check(Story.regard_active(rg) and not main.regard_done() and _story(), "the three Makers show themselves at the %s Regard, to the story music (%s)" % [what, Music.place_of(main)])
	main.hud.queue_redraw()
	await t._frames(2)
	var lines: Array = Story.regard_lines(main.profile, refused)
	var other: Array = Story.regard_lines(main.profile, not refused)
	_check(lines.size() == 3 and lines.all(func(l): return String(l).length() > 6 and not String(l).contains("{")) and lines != other,
		"one line each, its own when the guardian refuses (%s)" % [lines])
	_check(String(lines[2]).contains("her"), "...in the climber's pronouns: %s" % lines[2])
	Story.regard_tick(rg, 0.2, true)
	_check(Story.regard_active(rg), "a press in its first moment doesn't skip it")
	Story.regard_tick(rg, 0.3, false)
	var ended := Story.regard_tick(rg, 0.01, true)
	_check(ended and not Story.regard_active(rg), "then a press skips it, as it skips the glimpse")
	var length := float(Story.REGARD["seconds"])
	_check(length >= 3.0 and length <= 6.0, "a few seconds (%.1f)" % length)
	var again := {"t": 0.0}
	_check(not Story.start_regard(again, main.profile) and bool(Story.state(main.profile).get("regard", false)), "once per climber")
	main.regard = {}
	main.player.set_physics_process(true)


# --- 2. the plea ------------------------------------------------------------------------------

func _plea() -> void:
	await _fresh()
	var main = t.main
	var cs = main.climb_shape
	var prof = main.profile
	main.grant_test_bonds()
	main.player.iframes = 9999.0
	prof.record["beasts_by"] = {"wyvern": 1, "kraken": 1}
	main.tower = "gryphon"
	var g = await t._spawn("gryphon", main.player.global_position + Vector2(260, 0))
	if g != null:
		t._slay(g)
		await t._frames(2)
	_check(Story.plea_due(prof), "the third guardian beaten: the Makers' plea is due")
	var st: Dictionary = main.makers.st()
	for m in Makers.ORDER:
		st["interest"][m] = 100.0
	main.show_victory(["The climb is complete"])
	main.victory["t"] = 9.0
	main.end_regard()
	var v = cs.story_view
	_check(v != null and v.kind == "plea" and t.paused and _story(), "after the summit's victory, the Makers meet the climber together, to the story music")
	if v == null:
		return
	await t._frames(2)
	_check(v.beats.size() >= 4 and v.beats.any(func(b): return b["who"] == "all" and String(b["lines"][0]).contains("Stop, or become what we were")), "all three speak: \"Stop, or become what we were\"")
	v.t = 9.0
	v.skip()
	var ids: Array = v.options.map(func(o): return o["id"])
	_check(v.stage == "answer" and ids == ["stop", "go", "ask"], "Skip goes to the cards: I'll stop / I'll go on / Tell me what you were (%s)" % [ids])
	_check(v.options.all(func(o): return String(o.get("help", "")) != "" and String(o.get("desc", "")) != ""), "each card has the Entity's help (hover, focus, or a first tap)")
	var r: Rect2 = v.card_rect(0, SMALL)
	_check(r.size.y >= 84.0 and r.size.x >= 150.0, "the cards are big enough to tap (%s)" % r.size)
	v.t = 9.0
	v.press(2, false)
	_check(bool(Story.state(prof).get("asked", false)) and v.stage == "beat" and v.beats.size() >= 3, "asked, they tell what they were")
	v.skip()
	ids = v.options.map(func(o): return o["id"])
	_check(v.stage == "answer" and ids == ["stop", "go", "silent"], "...and back at the cards, that one is now Say nothing (%s)" % [ids])
	# A tap: the first shows its help, the second chooses.
	v.t = 9.0
	var tap := InputEventScreenTouch.new()
	tap.pressed = false
	tap.index = 0
	tap.position = v.card_rect(0).get_center()
	v._input(tap)
	_check(v.stage == "answer" and v.armed == 0 and not Story.state(prof).has("plea"), "on a touch screen, the first tap on a card shows its help")
	Engine.set_meta("sixfold_tips", true)
	var kept: Dictionary = Guide.state.get("story", {}).duplicate()
	Guide.state["story"] = {}
	v._input(tap)
	_check(String(Story.state(prof).get("plea", "")) == "stop" and not Story.plea_due(prof), "...the second chooses it: I'll stop (kept with the climber)")
	_check(float(st["interest"]["marks"]) > 150.0 and float(st["interest"]["creatures"]) < 120.0, "stopping pleases the Maker of Marks more than the Maker of Creatures (%d / %d)" % [int(st["interest"]["marks"]), int(st["interest"]["creatures"])])
	v.skip()
	await t._frames(1)
	var said: bool = Guide.state.get("story", {}).has("plea_stop")
	Guide.state["story"] = kept
	Engine.remove_meta("sixfold_tips")
	_check(cs.story_view == null and not t.paused and said, "the scene ends, and the Entity's next line follows the answer")
	_check(prof.count("ending") == 0 and prof.regarded and prof.bonds.size() == 2 and not main.player.dead, "\"I'll stop\" ends nothing: the same climber, free to climb")
	main.camp_choosing = false
	main.camp = {}
	main.victory = {}
	_check(not Story.plea_due(prof) and not cs.before_leaving(), "once per climber")
	# A fourth guardian after saying stop: noticed.
	prof.record["beasts_by"]["manticore"] = 1
	Story.on_guardian(main, 4)
	_check(bool(Story.state(prof).get("broken", false)), "a guardian beaten after saying stop is noted")
	# The other answers.
	for id in ["go", "silent"]:
		var s := Story.state(prof)
		s.erase("plea")
		for m in Makers.ORDER:
			st["interest"][m] = 100.0
		var res: Dictionary = Story.answer(main, "plea", id)
		var good: bool = String(s.get("plea", "")) == id and res.get("then", "") == "finish" and String(res.get("after", "")) != ""
		if id == "go":
			good = good and float(st["interest"]["creatures"]) > 100.0 and float(st["interest"]["marks"]) < 100.0
		_check(good, "\"%s\" is kept, with its own reply, moving the Makers' interest (%s)" % [id, st["interest"]])
	# Missed at the summit, the plea comes at the next stair.
	var s2 := Story.state(prof)
	s2.erase("plea")
	s2["plea_due"] = true
	main.regard = {}
	main.in_camp = false
	cs.after_arrive()
	_check(cs.story_view != null and cs.story_view.kind == "plea", "missed at the summit, the plea comes at the next stair")
	cs.end_story("plea", "")
	await t._frames(1)


# --- 3. the final meeting and the ending -----------------------------------------------------------

func _final(choice: String, unbound: bool, sworn: bool, try_not_yet: bool) -> void:
	await _fresh()
	var main = t.main
	var cs = main.climb_shape
	var prof = main.profile
	main.grant_test_bonds()
	main.profile.appearance["pronouns"] = "he"
	if unbound:
		Unbound.become(prof)
		main._give_bonds()
	if sworn:
		Makers.set_core(prof, "designer", 1)  # (Sworn of the Maker of Towers)
	var by := {}
	for tid in Towers.ORDER:
		by[tid] = 1
	prof.record["beasts_by"] = by
	prof.record.erase("ending")
	Story.state(prof)["plea"] = "stop"
	var what := "%s, %s%s" % [choice, "Unbound" if unbound else "marked", ", Sworn" if sworn else ""]
	main.show_victory(["The climb is complete"])
	main.victory["t"] = 9.0
	main.end_regard()
	var v = cs.story_view
	_check(v != null and v.kind == "final" and cs.ending_view == null and _story(), "all six guardians beaten: the final meeting first, to the story music (%s)" % what)
	if v == null:
		return
	await t._frames(2)
	_check(v.beats.any(func(b): return b["who"] == "entity") and v.beats.any(func(b): return String(b["lines"][0]).contains("would stop")), "the Makers see the Entity (and remember \"I'll stop\")")
	_check(v.beats.any(func(b): return b["who"] == "towers" and String(b["lines"][0]).contains("carry my mark")) == sworn, "a Sworn climber's own Maker offers its place (%s)" % what)
	v.t = 9.0
	v.skip()
	await t._frames(2)
	var ids: Array = v.options.map(func(o): return o["id"])
	_check(v.stage == "answer" and ids == ["ascend", "fight", "not_yet"] and v.entity_k > 0.0, "the cards: Ascend / Fight / Not yet, the Entity beside the climber (%s)" % [ids])
	if sworn:
		_check(String(v.options[0]["desc"]).contains("the Maker of Towers"), "Ascend, Sworn: take your Maker's place (%s)" % v.options[0]["desc"])
	if try_not_yet:
		v.t = 9.0
		v.press(2, false)
		v.skip()
		await t._frames(1)
		_check(cs.story_view == null and cs.ending_view == null and Story.choice(prof) == "" and cs.final_deferred and prof.count("ending") == 0, "Not yet: no ending, no choice; it waits")
		_check(not cs.before_leaving() or cs.story_view == null, "...not again at this summit")
		main.camp_choosing = false
		main.camp = {}
		cs.start_story("final")
		v = cs.story_view
		v.t = 9.0
		v.skip()
	var i: int = ids.find(choice)
	v.t = 9.0
	v.press(i, false)
	_check(v.stage == "answer" and v.armed == i and Story.choice(prof) == "", "%s asks for a second press" % choice.capitalize())
	v.press(i, false)
	_check(Story.choice(prof) == choice and v.stage == "beat", "...then it's chosen, and the reply plays")
	v.skip()
	await t._frames(2)
	var ev = cs.ending_view
	_check(cs.story_view == null and ev != null and _story(), "then the ending, to the story music")
	if ev == null:
		return
	var title := Story.title_of(prof)
	var want := "the Breaker" if choice == "fight" else ("the Maker of Towers" if sworn else "the Seventh Maker")
	_check(title == want and Renown.worn_title(prof) == want, "the title: %s (shown when no other is worn: %s)" % [title, Renown.worn_title(prof)])
	var keys: Array = ev.pages.map(func(pg): return pg["key"])
	var truth := "truth_%s_%s" % [choice, "unbound" if unbound else "marked"]
	_check(ev.pages.size() == 3 and keys[1] == truth and keys[0] == ("ascend_sworn" if sworn else choice), "the ending's pages: the choice, the Entity's truth, after (%s)" % [keys])
	var said := " ".join(ev.pages[1]["lines"])
	var told: bool = said.contains("army") if unbound else said.contains("I used you")
	_check(told, "...the Entity's truth for %s: %s" % ["the Unbound (its army)" if unbound else "the marked (it used them)", said])
	if sworn:
		_check(" ".join(ev.pages[0]["lines"]).contains("The Maker of Towers steps back"), "...a Sworn climber takes their Maker's place: %s" % ev.pages[0]["lines"][0])
	var all := ""
	for pg in ev.pages:
		all += " ".join(pg["lines"]) + " "
	_check(not all.contains("{") and not all.contains("%s") and all.contains(want), "...pronouns and names filled, the title in its words")
	for pg in ev.pages.size():
		_check(ev.words_bottom(SMALL, pg) <= SMALL.y - 24.0, "ending page %d fits 800x400 (%d)" % [pg + 1, int(ev.words_bottom(SMALL, pg))])
	await t._frames(2)
	for k in 3:
		ev.t = 99.0
		ev.next()
	await t._frames(2)
	_check(cs.ending_view == null and prof.count("ending") == 1 and not t.paused, "the pages turn, and it's kept as seen")
	_check((Unbound.is_on(prof) if unbound else prof.bonds.size() == 2) and not cs.ending_due(), "the same climber plays on; the ending plays once")
	var greet := Story.greeting(prof, "noble", 1.0)
	var lore: String = load("res://scripts/city_lore.gd").aura_line(prof, "rival", 1.0)
	var pool: Array = Story.GREET[choice]["rival"].map(func(l): return Pronouns.fill_for(String(l), "he"))
	_check(greet != "" and not greet.contains("{") and lore in pool, "Nobles and rivals greet the climber by the choice: %s / %s" % [greet, lore])
	main.camp_choosing = false
	main.camp = {}
	main.victory = {}


# --- words ------------------------------------------------------------------------------------

## Every scene's words in each pronoun, no token left; fits 800x400.
func _pronouns() -> void:
	var main = t.main
	var prof = main.profile
	var keep = prof.appearance.get("pronouns", "they")
	var s := Story.state(prof)
	var ok := true
	var bad := ""
	for pr in ["he", "she", "they"]:
		prof.appearance["pronouns"] = pr
		var texts: Array = Story.regard_lines(prof, false) + Story.regard_lines(prof, true)
		for key in ["plea_beats", "final_beats", "plea_tell"]:
			for b in Story.beats(prof, key):
				texts.append_array(b["lines"])
		for c in ["ascend", "fight"]:
			s["choice"] = c
			for m in ["", "marks"]:
				s["maker"] = m
				for pg in Story.ending_pages(prof):
					texts.append_array(pg["lines"])
		for l in texts:
			if String(l).contains("{") or String(l).contains("}"):
				ok = false
				bad = String(l)
	prof.appearance["pronouns"] = "she"
	var she := String(Story.regard_lines(prof, false)[2])
	prof.appearance["pronouns"] = keep
	s.erase("choice")
	s.erase("maker")
	_check(ok and she == "\"Look at her. Look how she grows.\"", "every line in he, she and they, no token left (%s / %s)" % [she, bad])
	# Fits 800x400: each beat's words above the climber, the last line over the cards on one row.
	var v = load("res://scripts/story_view.gd").new()
	v.main = main
	var fits := true
	var worst := 0.0
	for key in ["plea_beats", "final_beats", "plea_tell"]:
		var bs: Array = Story.beats(prof, key)
		for b in bs:
			worst = maxf(worst, v.words_bottom(b, SMALL))
		var last := String(bs[-1]["lines"][-1])
		fits = fits and Makers.redact_height(minf(SMALL.x - 60.0, 600.0), last, 14.0) <= 14.0 * 1.45 + 0.1
	v.free()
	_check(fits and worst <= SMALL.y - 60.0, "every beat fits 800x400 (lowest words at %d)" % int(worst))
	var rr := Story.regard_spot(0, SMALL, 1.0)
	var words_top := float(rr[0].y) - float(rr[1]) * 1.12 - 22.0 - 13.0 * 2.0
	_check(words_top > SMALL.y * 0.2 + 44.0 + 30.0 and float(rr[0].y) < SMALL.y, "the Makers at the Regard fit 800x400 (their words from %d, under the guardian's caption)" % int(words_top))


func _words() -> void:
	var tips := ["story_regard", "story_plea", "story_final", "story_ascend", "story_fight"]
	var missing: Array = tips.filter(func(id): return not Entity.TIPS.has(id))
	_check(missing.is_empty(), "the Entity has a first-time moment for each scene (missing: %s)" % [missing])
	var how: Array = Talk.DIALOGUE["how"]["choices"]
	_check("how_plea" in how and "how_final" in how and Talk.DIALOGUE.has("how_plea") and Talk.DIALOGUE.has("how_final"), "\"How does it work?\" has the plea and the last choice")
	var ids := ["plea_stop", "plea_go", "plea_silent", "plea_broken", "after_ascend", "after_fight"]
	_check(ids.all(func(id): return Entity.STORY.has(id) and Entity.story_line(id, false) != "" and Entity.story_line(id, true) != ""), "the Entity's lines after the plea and the ending, marked and Unbound")
	var Reg = load("res://scripts/data_registry.gd")
	_check(String(Reg.field("story_scenes/TEXT/regard_caption").get("kind", "")) == "text" and String(Reg.field("story_scenes/TITLES/fight").get("kind", "")) == "text",
		"the scenes' words are in the Data editor")
	var all := JSON.stringify([Story.TEXT, Story.ENDINGS, Story.TITLES, Story.GREET]) + JSON.stringify(tips.map(func(id): return Entity.TIPS.get(id, {})))
	all += JSON.stringify(ids.map(func(id): return Entity.STORY.get(id, {}))) + JSON.stringify([Talk.DIALOGUE["how_plea"], Talk.DIALOGUE["how_final"]])
	var found: Array = BANNED.filter(func(w): return all.to_lower().contains(w))
	_check(found.is_empty(), "no banned words in the story's scenes (%s)" % [found])
	_check(Story.TEXT["plea_answers"].size() == 3 and Story.TEXT["final_answers"].size() == 3, "three cards in each scene (by sixes: 3 is allowed)")
