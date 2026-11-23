extends RefCounted
## The cities' lore (city_lore.gd, mark_seal.gd, fracture.gd): the seal on a
## faint mark (placed on a fall before the Regard, broken on the train with a
## second press, making the climber Unbound; gone once the mark has grown;
## none on an old save's faint mark), the Regard's glimpse of the last
## fracture (played before the eye, skippable, then the guardian's charge),
## the home Noble's persuasion (by guardians beaten or renown, in order,
## only at home), the aura in how people speak (Nobles, the Dining car and
## rivals, by path and step, with the climber's pronouns), and an Unbound
## passing as marked (the chance per visit, rising with Node level and aura
## step; found out: the Noble's refusal, dearer fees, the warning, a rumour
## that rivals repeat). Then the Entity's words, the Data editor and no banned
## words. Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const Lore := preload("res://scripts/city_lore.gd")
const Seal := preload("res://scripts/mark_seal.gd")
const Fracture := preload("res://scripts/fracture.gd")
const Noble := preload("res://scripts/noble.gd")
const Dining := preload("res://scripts/dining.gd")
const Unbound := preload("res://scripts/unbound.gd")
const Secret := preload("res://scripts/secret.gd")
const Travel := preload("res://scripts/travel.gd")
const Stations := preload("res://scripts/stations.gd")
const Pronouns := preload("res://scripts/pronouns.gd")
const ProfileScript := preload("res://scripts/profile.gd")

const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

var t


func run(smoke) -> void:
	t = smoke
	print("the cities' lore: the seal, the glimpse, the Noble's persuasion, the aura in speech, passing as marked")
	await _seal()
	await _seal_on_tab()
	await _glimpse()
	_persuasion()
	_aura()
	_passing()
	await _passing_at_station()
	_words()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _prof():
	var p = ProfileScript.new()
	p.saving = false
	p.home = "gryphon"
	return p


# --- the seal on a faint mark ------------------------------------------------------------

func _seal() -> void:
	await t._fresh_main()
	var main = t.main
	var prof = main.profile
	prof.saving = false
	main.first_climb = true
	main.climb_soak["brow"] = 30.0
	main.climb_shape.top_floor = 3
	main._grant_regard(true)
	var part := String(main.regard_mark.get("part", ""))
	var b: Dictionary = prof.bonds.get(part, {})
	_check(bool(b.get("faint", false)) and bool(b.get("seal", false)) and Seal.sealed_part(prof) == part, "a fall before the Regard: the faint mark carries a seal (%s, %d%%)" % [part, int(round(float(b.get("power", 0.0)) * 100.0))])
	_check(not Seal.break_seal(prof, false)["ok"] and not Unbound.is_on(prof), "it can't be broken off the train")
	# A mark reached at full strength has no seal; an old save's faint mark neither.
	var full = _prof()
	full.add_bond("hand", "stormcaller", false)
	Seal.place(full, "hand")
	var old = _prof()
	old.add_bond("legs", "windwalker", true, 0.6)
	_check(Seal.sealed_part(full) == "" and Seal.sealed_part(old) == "", "a full mark takes no seal, and an old save's faint mark has none")
	# Grown to full strength, the seal is gone.
	var grown = _prof()
	grown.add_bond("brow", "warden", true, 0.6)
	Seal.place(grown, "brow")
	_check(Seal.can_break(grown), "(a faint mark with its seal)")
	grown.bank({"water": 400.0}, {})
	_check(not bool(grown.bonds["brow"]["faint"]) and Seal.sealed_part(grown) == "" and Seal.tidy(grown) and not grown.bonds["brow"].has("seal"), "once the mark has grown to full strength, its seal is gone")
	# Broken on the train: the third way to be Unbound.
	var got: Dictionary = Seal.break_seal(prof, true)
	_check(bool(got["ok"]) and Unbound.is_on(prof) and prof.bonds.is_empty() and Seal.sealed_part(prof) == "", "broken on the train: the mark comes away and the climber is Unbound (%s)" % got["line"])
	_check(not Seal.break_seal(prof, true)["ok"], "...and there is no seal left to break")


func _seal_on_tab() -> void:
	print("the seal on the Marks tab")
	await t._fresh_main()
	var main = t.main
	var menu = main.menu
	var prof = main.profile
	prof.saving = false
	main.touch._set_active(false)
	prof.add_bond("hand", "stormcaller", true, 0.7)
	Seal.place(prof, "hand")
	prof.regarded = true
	main.first_climb = false
	main.on_train = false
	menu.climber_tab = "marks"
	menu.open("climber")
	await t._frames(3)
	_check(_btn(menu) == null and t._all_labels(menu.box).any(func(l): return l.has_meta("mark_seal_off_train")), "off the train the tab only says where the seal can be broken")
	menu.close()
	await t._frames(2)
	main.on_train = true
	menu.open("climber")
	await t._frames(3)
	var b: Button = _btn(menu)
	var warn: Array = t._all_labels(menu.box).filter(func(l): return l.has_meta("mark_seal_warn"))
	_check(b != null and String(b.get_meta("help", "")) == "mark_seal_break" and warn.size() == 1 and warn[0].text.contains("Unbound"), "on the train: a warning and Break the seal, with hover help")
	if b != null:
		b.pressed.emit()
	await t._frames(3)
	_check(not Unbound.is_on(prof) and menu.asking() and menu.pop.text_l.text.contains("Unbound"), "a press only asks: the confirmation pop-up, with the warning")
	await t._confirm(false)
	await t._frames(2)
	_check(not Unbound.is_on(prof) and not menu.asking() and _btn(menu) != null, "...Cancel changes nothing")
	b = _btn(menu)
	if b != null:
		b.pressed.emit()
	await t._frames(2)
	await t._confirm(true)
	await t._frames(4)
	_check(Unbound.is_on(prof) and _btn(menu) == null and menu.page == "climber", "Confirm breaks it: Unbound, and the tab shows the Body")
	menu.close()
	main.on_train = false
	await t._frames(2)


func _btn(menu) -> Button:
	var found: Array = t._all_buttons(menu).filter(func(x): return x.has_meta("mark_seal") and not x.is_queued_for_deletion())
	return found[0] if not found.is_empty() else null


# --- the Regard's glimpse ----------------------------------------------------------------

func _glimpse() -> void:
	print("the Regard's glimpse")
	await t._fresh_main()
	var main = t.main
	main.profile.saving = false
	main.first_climb = true
	main.climb_soak["hand"] = 30.0
	main._begin_regard(false)
	var rg: Dictionary = main.regard
	_check(Fracture.active(rg) and float(rg["glimpse"]) >= 3.0 and float(rg["glimpse"]) <= 6.0, "reached, the Regard opens with a glimpse of a few seconds")
	rg["t"] = 9.0
	_check(not main.regard_done(), "...and can't be dismissed while it plays")
	rg["gt"] = 1.2
	await t._frames(3)  # (drawn: hud.gd _draw_regard -> fracture.gd draw)
	rg["gt"] = 0.0
	_check(not Fracture.tick(rg, 0.1, true) and Fracture.active(rg), "a press in its first moment doesn't skip it")
	_check(Fracture.tick(rg, 0.4, true) and not Fracture.active(rg) and main.regard_done(), "a press after that skips it; then the Regard can be dismissed")
	var info: Dictionary = main.BondScript.Bonds.BONDS[rg["id"]]
	var lines: Array = main.climb_shape.regard_lines(rg, info, "Hand")
	_check(lines.size() == 6 and String(lines[4]).contains("oppose the marks") and String(lines[4]).contains(main.beast_name().capitalize()), "then the guardian charges the new mark to stop those who oppose the marks: %s" % lines[4])
	# Played out on its own, the Regard goes on.
	main.regard = {}
	main.regard_mark = {}
	main._begin_regard(false)
	main.regard["gt"] = float(main.regard["glimpse"]) - 0.01
	await t._frames(4)
	_check(not Fracture.active(main.regard), "played out, the glimpse ends by itself")
	# On a phone, a tap skips it (touch.gd), and doesn't close the Regard too.
	main.regard = {}
	main.regard_mark = {}
	main._begin_regard(false)
	main.regard["gt"] = 1.0
	var tap := InputEventScreenTouch.new()
	tap.index = 0
	tap.position = Vector2(300, 300)
	tap.pressed = true
	main.touch._input(tap)
	tap.pressed = false
	main.touch._input(tap)
	await t._frames(2)
	_check(not main.regard.is_empty() and not Fracture.active(main.regard), "a tap skips the glimpse; the Regard stays to be read")
	main.touch._set_active(false)
	main.regard = {}
	# Fallen or refused: no glimpse.
	var fell := {"fell": true, "refused": false}
	_check(not Fracture.active(fell), "a fallen Regard has no glimpse")
	await t._fresh_main()


# --- the Noble's persuasion ------------------------------------------------------------------

func _persuasion() -> void:
	var p = _prof()
	var home: String = Travel.home(p)
	var away := ""
	for id in Travel.loop():
		if id != home:
			away = id
			break
	_check(Lore.persuade_step(p) == 0 and Lore.persuade_word(p, home, 1.0) == "", "a climber not yet strong hears no persuasion")
	p.record["beasts_by"] = {"gryphon": 1}
	var steps: Array = Lore.PERSUADE["steps"]
	var first: String = Lore.persuade_word(p, home, 1.0)
	var second: String = Lore.persuade_word(p, home, 1.0)
	_check(Lore.persuade_step(p) == 1 and first == String(steps[0]["lines"][0]) and second == String(steps[0]["lines"][1]), "a guardian beaten: the home Noble starts, in order")
	_check(Lore.persuade_word(p, away, 1.0) == "" and Lore.persuade_word(p, home, 0.0) == "", "only at home, and only now and then")
	_check(Noble.greet(p, 0.0, home).length() > 0, "(the greeting goes on as before)")
	var g: String = Noble.greet(p, 1.0, home)
	_check(g.contains(String(steps[0]["lines"][0]).left(20)) or g.contains(String(steps[0]["lines"][1]).left(20)),"...and the Noble's greeting carries it: %s" % g)
	# Strong by renown alone, a new step's first word always comes.
	var q = _prof()
	load("res://scripts/renown.gd").state(q)["points"] = 600
	_check(Lore.persuade_step(q) == steps.size(), "renown alone counts too (the top rank: every step)")
	q.appearance["pronouns"] = "she"
	var all: Array = [Lore.persuade_word(q, Travel.home(q))]
	_check(String(all[0]) != "", "a new step's first word always comes")
	for i in 7:
		var w: String = Lore.persuade_word(q, Travel.home(q), 1.0)
		if w != "":
			all.append(w)
	_check(all.size() >= 6 and not all.any(func(w): return w.contains("{")), "over time every line is told, filled in (%d)" % all.size())
	_check(all.any(func(w): return w.contains("She may be staying")), "...with the climber's pronouns")
	_check(Lore.state(q)["persuade_step"] == steps.size(), "(remembered with the climber)")


# --- the aura in how people speak ------------------------------------------------------------

func _aura() -> void:
	var p = _prof()
	p.appearance["pronouns"] = "she"
	_check(Lore.aura_step(p) == 0 and Lore.aura_line(p, "noble", 1.0) == "", "no path, no aura: everyone speaks as before")
	var counts := true
	for path in Secret.ORDER:
		for who in ["noble", "dining", "rival"]:
			counts = counts and Lore.AURA[path][who].size() == Secret.STEPS.size()
	_check(counts, "a line for each of the aura's six steps, on each path, for Nobles, the Dining car and rivals")
	p.path = "life"
	p.flow = float(Secret.STEPS[2])
	var n3: String = Lore.aura_line(p, "noble", 1.0)
	_check(Lore.aura_step(p) == 3 and n3.contains("Bring her the good chair. She has earned"), "Making, step 3: the Noble's line, with her pronouns: %s" % n3)
	p.flow = float(Secret.STEPS[0])
	var n1: String = Lore.aura_line(p, "noble", 1.0)
	_check(n1 != n3 and n1 == String(Lore.AURA["life"]["noble"][0]), "...a different line at another step")
	_check(Noble.greet(p, 1.0).begins_with(n1), "the Noble greets with it")
	var d1: String = Dining.greeting(p, {}, 1.0)
	_check(d1 == String(Lore.AURA["life"]["dining"][0]), "so does a new face in the Dining car: %s" % d1)
	p.path = "unmaking"
	p.flow = float(Secret.STEPS[5])
	var r6: String = Lore.aura_line(p, "rival", 1.0)
	var d3_p = _prof()
	d3_p.path = "unmaking"
	d3_p.flow = float(Secret.STEPS[2])
	d3_p.appearance["pronouns"] = "he"
	var d3: String = Lore.aura_line(d3_p, "dining", 1.0)
	_check(r6 == String(Lore.AURA["unmaking"]["rival"][5]) and d3.contains("Not too close to him"), "Unmaking makes them give way, by step and path: %s / %s" % [r6, d3])
	_check(Lore.aura_line(p, "noble", 0.0) == "", "now and then they speak as before")
	# Rivals in the towers.
	var main = t.main
	var keep: float = Lore.AURA_CHANCE
	var prof0 = main.profile
	main.profile = p
	Lore.AURA_CHANCE = 1.0
	var said: String = main.rivals._line("trade", {})
	Lore.AURA_CHANCE = keep
	main.profile = prof0
	_check(said.begins_with(r6), "a rival climber's word starts with it: %s" % said)


# --- passing as marked -----------------------------------------------------------------------

func _passing() -> void:
	var m = _prof()
	var station: String = Travel.home(m)
	_check(Lore.found_chance(m) == 0.0 and not Lore.on_visit(m, station, 0.0) and not Lore.found_out(m, station), "a marked climber is never found out")
	var u = _prof()
	Unbound.become(u)
	var base: float = Lore.found_chance(u)
	_check(is_equal_approx(base, float(Lore.PASSING["start"])), "an Unbound starts at a small chance a visit (%d%%)" % int(round(base * 100.0)))
	u.path = "unmaking"
	u.flow = float(Secret.STEPS[3])
	var with_aura: float = Lore.found_chance(u)
	Unbound.set_size(u, "hand", 60.0)
	var with_node: float = Lore.found_chance(u)
	u.flow = 999999.0
	Unbound.set_size(u, "hand", 120.0)
	_check(with_aura > base and with_node > with_aura and Lore.found_chance(u) <= float(Lore.PASSING["most"]) + 0.0001, "it rises with the aura's step and the biggest Node, to %d%% at most" % int(round(float(Lore.PASSING["most"]) * 100.0)))
	u.flow = 0.0
	u.path = ""
	Unbound.set_size(u, "hand", 0.0)
	# Not found out: treated as marked.
	_check(not Lore.on_visit(u, station, 0.99) and not Lore.found_out(u, station) and is_equal_approx(Lore.price_mult(u, station), 1.0), "most visits nobody looks closer")
	var drill: String = String(Stations.DRILLS.keys()[0])
	var fee0: int = Stations.fee(u, "drill", drill)
	_check(not Lore.on_visit(u, station, 0.0), "a visit rolls once, however often you step off")
	# Found out.
	u.climbs += 1
	_check(Lore.on_visit(u, station, 0.0) and Lore.found_out(u, station) and Lore.found_out(u), "a later visit: found out")
	_check(Stations.fee(u, "drill", drill) > fee0 or fee0 == 0, "the station's fees cost more (%d -> %d)" % [fee0, Stations.fee(u, "drill", drill)])
	var g: String = Noble.greet(u, 1.0, station)
	_check(Lore.TEXT["noble_found"].has(g), "the Noble greets coldly: %s" % g)
	var city: String = Lore.rumour_city(u)
	var w: String = Lore.passing_word(u, 1.0)
	_check(city != "" and w.contains(city), "a rumour spreads, and climbers repeat it: %s" % w)
	u.climbs += int(Lore.PASSING["rumour_climbs"]) + 1
	_check(not Lore.found_out(u, station) and Lore.rumour_city(u) == "" and Lore.TEXT["passing"].has(Lore.passing_word(u, 1.0)), "it passes: after a few climbs they take the climber for marked again")
	_check(Lore.passing_word(m, 1.0) == "" and Lore.passing_word(u, 0.0) == "", "(nothing of it for the marked, and only now and then)")
	_check(int(Lore.state(u)["found_n"]) == 1, "(remembered with the climber)")


func _passing_at_station() -> void:
	print("found out, at the station")
	await t._fresh_main()
	var main = t.main
	var menu = main.menu
	var prof = main.profile
	prof.saving = false
	Unbound.become(prof)
	prof.regarded = true
	main.first_climb = false
	var station: String = Travel.current(prof)
	Lore.state(prof)["key"] = Lore.visit_key(prof, station)
	Lore.state(prof)["found"] = true
	main.open_train()
	await t._frames(2)
	menu.station_page.station = ""
	menu.go_station(station, "noble")
	await t._frames(3)
	var banner: Array = t._all_labels(menu.box).filter(func(l): return l.has_meta("found_out"))
	var line: Array = t._all_labels(menu.box).filter(func(l): return l.has_meta("noble_line"))
	_check(banner.size() == 1 and banner[0].text == Lore.banner(), "found out: a clear warning at the top of the stop")
	_check(line.size() == 1 and Lore.TEXT["noble_found"].has(line[0].text), "...and the Noble's cold word")
	var titles0: Array = load("res://scripts/renown.gd").state(prof)["titles"].duplicate()
	menu.station_page._grant("newcomer")
	await t._frames(2)
	_check(load("res://scripts/renown.gd").state(prof)["titles"] == titles0 and menu.station_page.lines.has(Lore.TEXT["refused"]), "the Noble grants no title this visit")
	menu.station_page.station = ""
	menu.close()
	main.on_train = false
	await t._frames(2)


# --- the Entity, the Data editor, the words ------------------------------------------------

func _words() -> void:
	var E = load("res://scripts/entity.gd")
	var Talk = load("res://scripts/entity_talk.gd")
	var Help = load("res://scripts/entity_help.gd")
	var Reg = load("res://scripts/data_registry.gd")
	var texts: Array = [JSON.stringify(Lore.AURA), JSON.stringify(Lore.PERSUADE), JSON.stringify(Lore.TEXT), JSON.stringify(Seal.TEXT), JSON.stringify(Fracture.TEXT)]
	for id in ["mark_seal", "mark_seal_broken", "regard_glimpse", "unbound_passing", "found_out", "noble_persuades"]:
		var e: Dictionary = E.TIPS.get(id, {})
		_check(e.has("tip") and e.has("more") and String(e["tip"]).length() < 160, "the Entity explains '%s' (a short line and an Archive account)" % id)
		texts.append(JSON.stringify(e))
	for id in ["how_mark_seal", "how_passing"]:
		_check(Talk.DIALOGUE.has(id) and id in Talk.DIALOGUE["how"]["choices"], "'How does it work?' has '%s'" % Talk.DIALOGUE.get(id, {}).get("ask", id))
		texts.append(JSON.stringify(Talk.DIALOGUE.get(id, {})))
	_check("how_mark_seal" in Talk.DIALOGUE["how_first_mark"]["choices"] and String(Talk.DIALOGUE["how_aura"]["lines"][0]).contains("speak to you differently"), "...linked from the first mark, and the aura's answer says people speak differently")
	_check(Help.HELP.has("mark_seal_break"), "hover and hold help for Break the seal")
	texts.append(String(Help.HELP.get("mark_seal_break", "")))
	var tables: Array = []
	for sec in Reg.SECTIONS:
		tables.append_array(sec.get("tables", []))
	_check(["city_lore/AURA", "city_lore/PERSUADE", "city_lore/TEXT", "city_lore/PASSING", "mark_seal/TEXT", "fracture/TEXT", "fracture/GLIMPSE"].all(func(x): return tables.has(x))
		and String(Reg.field("city_lore/PASSING/start").get("kind", "")) == "number" and String(Reg.field("fracture/TEXT/skip").get("kind", "")) == "text"
		and String(Reg.field("city_lore/AURA/life/noble/0").get("kind", "")) == "text" and String(Reg.field("mark_seal/TEXT/break").get("kind", "")) == "text", "every word and number is in the Data editor")
	var all := " ".join(texts).to_lower()
	var bad: Array = BANNED.filter(func(w): return RegEx.create_from_string("\\b" + w + "\\b").search(all) != null)
	_check(bad.is_empty(), "none of the owner's banned words in the cities' words (%s)" % ", ".join(bad))
	# Every line that speaks of the climber fills from the pronouns.
	var left := false
	for path in Lore.AURA:
		for who in Lore.AURA[path]:
			for l in Lore.AURA[path][who]:
				left = left or Pronouns.fill_for(String(l), "she").contains("{")
	_check(not left, "every aura line fills in (no token left)")
