extends RefCounted
## A new climber's start (new_start.gd, start_pages.gd, pronouns.gd): the
## one-time clearing of old climbers with its notice; the title showing
## Continue above New Climber; New Climber going straight to the name (the
## opening plays before the title: tests/parts/opening.gd), the opening's
## Skip; the name and pronouns; the questionnaire's
## results for every answer (gear kept as heirlooms, the home tower, crystals,
## titles, the Noble's contract, worn gear, renown a quarter faster until a
## first title); Begin starting the first climb in the home tower; pronouns
## used wherever a line speaks of the climber; the colour wheel; the pages
## at a phone's size. Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const NewStart := preload("res://scripts/new_start.gd")
const StartPages := preload("res://scripts/start_pages.gd")
const Pronouns := preload("res://scripts/pronouns.gd")
const Slots := preload("res://scripts/slots.gd")
const Appearance := preload("res://scripts/appearance.gd")
const Renown := preload("res://scripts/renown.gd")
const Contracts := preload("res://scripts/contracts.gd")
const Gear := preload("res://scripts/gear.gd")
const Towers := preload("res://scripts/towers.gd")
const Entity := preload("res://scripts/entity.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const Help := preload("res://scripts/entity_help.gd")
const ClimbersPage := preload("res://scripts/climbers_page.gd")
const ProfileScript := preload("res://scripts/profile.gd")

const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

var t


func run(smoke) -> void:
	t = smoke
	_pronouns()
	_clearing()
	_results()
	await _flow()
	await _wheel()
	await _phone()
	_words()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _fresh_profile():
	var p = ProfileScript.new()
	p.saving = false
	return p


# --- pronouns ---------------------------------------------------------------------------

func _pronouns() -> void:
	print("new start: pronouns")
	var line := "{They} {are} climbing; I saw {them} on {their} stair. The mark is {theirs}. {They} climb{s} alone, and reach{es} the top by {themself}. {They're} sure."
	_check(Pronouns.fill_for(line, "he") == "He is climbing; I saw him on his stair. The mark is his. He climbs alone, and reaches the top by himself. He's sure.", "he: %s" % Pronouns.fill_for(line, "he"))
	_check(Pronouns.fill_for(line, "she") == "She is climbing; I saw her on her stair. The mark is hers. She climbs alone, and reaches the top by herself. She's sure.", "she: %s" % Pronouns.fill_for(line, "she"))
	_check(Pronouns.fill_for(line, "they") == "They are climbing; I saw them on their stair. The mark is theirs. They climb alone, and reach the top by themself. They're sure.", "they (verbs agree): %s" % Pronouns.fill_for(line, "they"))
	_check(Pronouns.of_look({"pronouns": "she"}) == "she" and Pronouns.of_look({}) == "they" and Pronouns.of_look({"pronouns": "x"}) == "they", "pronouns are kept with the look, they by default")
	# Everywhere text is shown: tips, the Entity's words and bubbles, pages, notices.
	var keep := Pronouns.current
	Pronouns.current = "she"
	var ok := Entity.fill_keys("{they} {are} here", "keys") == "She is here" and Entity.fill_words("{They} {have} {count}", {"count": 3}) == "She has 3"
	ok = ok and Talk.fill("{They} {were} brave.", {}) == "She was brave."
	ok = ok and Help.tidy(Entity.fill_words(String(Help.HELP["rail:exit"]), {})).contains("as she is")
	_check(ok, "the Entity's tips, its talk and its button help use the climber's pronouns")
	_check(Pronouns.fill(String(ClimbersPage.TEXT["over_text"]) % "Mira").contains("Her marks and growth"), "Start over speaks of the climber with their pronouns")
	Pronouns.current = keep


# --- the one-time clearing, made climbers -----------------------------------------------

func _clearing() -> void:
	print("new start: old climbers cleared once, the intro skippable after one")
	# A climber from before the new start, and a settings file with no marker.
	var old := ConfigFile.new()
	old.set_value("profile", "regarded", true)
	old.set_value("look", "appearance", {"name": "Old"})
	old.save(Slots.path(2))
	var set := ConfigFile.new()
	set.set_value("settings", "volume", 0.5)
	set.set_value("slots", "version", 1)
	set.set_value("slots", "current", 2)
	set.save(Slots.settings_path())
	Slots.forget()
	var cleared := NewStart.clear_old_once()
	var copy := Slots.path(2).get_basename() + "_before_new_start.cfg"
	_check(cleared and not Slots.exists(2) and FileAccess.file_exists(copy) and NewStart.notice_pending() and Slots.current() == 1, "a climber from before the new start is cleared (a copy kept), and the title will say why")
	var s := ConfigFile.new()
	s.load(Slots.settings_path())
	_check(is_equal_approx(float(s.get_value("settings", "volume", 0.0)), 0.5), "...the settings are kept")
	old.save(Slots.path(2))
	_check(not NewStart.clear_old_once() and Slots.exists(2), "...only once: a climber made after it stays")
	NewStart.dismiss_notice()
	_check(not NewStart.notice_pending(), "...and the notice goes once read")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Slots.path(2)))
	DirAccess.remove_absolute(ProjectSettings.globalize_path(copy))
	Slots.forget()
	var was := NewStart.made()
	_check(not NewStart.can_skip_intro() or was > 0, "no climber counted as made before any is")
	NewStart.note_made()
	_check(NewStart.made() == was + 1 and NewStart.can_skip_intro(), "each climber made on this device is counted")


# --- the questionnaire's results ---------------------------------------------------------

func _results() -> void:
	print("new start: the questionnaire's results")
	_check(NewStart.QUESTIONS.size() == 3 and NewStart.INTRO.size() == 6, "three questions, six screens of the opening")
	_check(NewStart.answers(NewStart.QUESTIONS[1]).size() == Towers.ORDER.size(), "Where did you grow up? offers each of the six towers")
	var want := {
		"soldier": {"melee": "sword", "armor": "chain", "ranged": ""},
		"hunter": {"melee": "dagger", "armor": "leather", "ranged": "shortbow"},
		"labourer": {"melee": "war_hammer", "armor": "padded", "ranged": ""},
		"beggar": {"melee": "dagger", "armor": "", "ranged": ""},
		"scholar": {"melee": "sword_cane", "armor": "padded", "ranged": ""},
		"sailor": {"melee": "", "armor": "leather", "ranged": "flintlock"},
	}
	_check(NewStart.answers(NewStart.QUESTIONS[0]).size() == 6 and want.keys().all(func(k): return NewStart.PAST.has(k)), "six past jobs, each with its gear")
	# Counts by sixes: every list a new climber chooses from holds a multiple of six, or exactly three.
	var lists := {"intro": NewStart.INTRO.size(), "tabs": Appearance.TABS.size(), "pronouns": Pronouns.CHOICES.size(), "questions": NewStart.QUESTIONS.size()}
	for q in NewStart.QUESTIONS:
		lists["answers:" + String(q["id"])] = NewStart.answers(q).size()
	for key in Appearance.OPTIONS:
		lists["look:" + key] = Appearance.OPTIONS[key].size()
	for key in Appearance.EXTRA_OPTIONS:
		lists["look:" + key] = Appearance.EXTRA_OPTIONS[key].size()
	var off: Array = []
	for k in lists:
		if int(lists[k]) != 3 and int(lists[k]) % 6 != 0:
			off.append("%s=%d" % [k, lists[k]])
	_check(off.is_empty(), "every creation list counts by sixes, or is exactly three (%s)" % [off])
	var gear_ok := true
	for past in want:
		var p = _fresh_profile()
		NewStart.apply(p, {"past": past, "home": "wyvern", "why": "hired"})
		var w: Dictionary = want[past]
		gear_ok = gear_ok and Gear.base_id(p.heirlooms.get("melee", {})) == w["melee"]
		gear_ok = gear_ok and Gear.base_id(p.heirlooms.get("chest", {})) == w["armor"]
		gear_ok = gear_ok and Gear.base_id(p.heirlooms.get("ranged", {})) == w["ranged"]
	_check(gear_ok, "Soldier: sword and chain; Hunter: shortbow, dagger and leather; Labourer: war hammer and padding; Beggar: a dagger, no armour (kept as heirlooms)")
	# Born into it.
	var b = _fresh_profile()
	NewStart.apply(b, {"past": "soldier", "home": "firebird", "why": "born"})
	_check(b.home == "firebird" and b.last_tower == "firebird" and b.origin.get("why", "") == "born", "the home tower is kept (profile.home) and is the first tower")
	_check(Gear.rarity(b.heirlooms["melee"]) == "fine" and int(b.crystal_total("fire")) == 30 and Renown.worn_id(b) == "family", "Born into it: fine gear, 30 crystals of the home's kind, the family title worn")
	# Hired by someone.
	var h = _fresh_profile()
	NewStart.apply(h, {"past": "hunter", "home": "kraken", "why": "hired"})
	var held: Array = Contracts.active(h)
	_check(Gear.rarity(h.heirlooms["melee"]) == "common" and int(h.crystal_total("water")) == 15 and Renown.worn_id(h) == "hired" and held.size() == 1 and String(held[0]["tower"]) == "kraken", "Hired by someone: common gear, 15 crystals, the hired title and a contract for the home tower in hand")
	# Self made.
	var s = _fresh_profile()
	NewStart.apply(s, {"past": "labourer", "home": "chimera", "why": "self"})
	_check(s.crystals.is_empty() and Renown.worn_id(s) == "" and Contracts.active(s).is_empty(), "Self made: no crystals, no title, no contract")
	var before := Renown.points(s)
	for i in 4:
		Renown.earn(s, 1, "")
	var gained := Renown.points(s) - before
	_check(gained == 5, "...renown comes a quarter faster, slowly (4 gains of 1 make 5: %d)" % gained)
	Renown.state(s)["titles"].append("newcomer")
	before = Renown.points(s)
	for i in 4:
		Renown.earn(s, 1, "")
	_check(Renown.points(s) - before == 4, "...until the first title")
	var p2 = _fresh_profile()
	NewStart.apply(p2, {"past": "hunter", "home": "kraken", "why": "born"})
	_check(not Renown.grantable(s, "family") and not Renown.grantable(p2, "hired"), "a start's title can't be earned by anyone else")
	_check(Renown.TITLE_ORDER.size() % 6 == 0, "titles count by sixes (%d)" % Renown.TITLE_ORDER.size())
	_check(NewStart.summary({"past": "beggar", "home": "gryphon", "why": "self"}).size() >= 4, "the summary says what you'll begin with")


# --- the pages, in order ---------------------------------------------------------------------

func _buttons(menu) -> Array:
	return menu.box.find_children("*", "Button", true, false).filter(func(b): return b.is_visible_in_tree())


func _button_with(menu, meta: String) -> Button:
	for b in _buttons(menu):
		if b.has_meta(meta):
			return b
	return null


func _flow() -> void:
	print("new start: from New Climber to the first climb")
	await t._fresh_main()
	var main = t.main
	var menu = main.menu
	main.touch._set_active(false)
	main.pad._set_active(false)
	# The title: Continue above New Climber once a climber exists.
	main.profile.created = true
	menu.open("title")
	await t._frames(2)
	var words: Array = _buttons(menu).map(func(b): return b.text)
	var ci := words.find(NewStart.TEXT["continue"])
	var ni := words.find(NewStart.TEXT["new_climber"])
	_check(ci >= 0 and ni > ci, "the title shows Continue above New Climber (%s)" % [words])
	main.profile.created = false
	menu.open("title")
	await t._frames(2)
	words = _buttons(menu).map(func(b): return b.text)
	_check(not words.has(NewStart.TEXT["continue"]) and words.has(NewStart.TEXT["new_climber"]), "...and only New Climber for an empty slot")
	# New Climber: straight to the name (the opening plays before the title,
	# on a device's first launch: tests/parts/opening.gd).
	var cfg := ConfigFile.new()
	cfg.load(Slots.settings_path())
	cfg.set_value("start", "made", 0)
	cfg.save(Slots.settings_path())
	StartPages.begin_start(menu)
	await t._frames(2)
	_check(menu.page == "create_name" and not menu.opening.visible, "New Climber goes straight to the name: the opening isn't shown again")
	# The name and pronouns.
	var she: Button = null
	for b in _buttons(menu):
		if b.get_meta("pronoun", "") == "she":
			she = b
	she.pressed.emit()
	await t._frames(1)
	StartPages.name_edit.text = "Wren"
	StartPages.name_edit.text_changed.emit("Wren")
	_check(main.profile.appearance["pronouns"] == "she" and main.profile.appearance["name"] == "Wren" and Pronouns.current == "she", "the name and pronouns are kept, and used at once")
	_button_with(menu, "name_next").pressed.emit()
	await t._frames(2)
	_check(menu.page == "create" and menu.look_page.finish.text == Appearance.TEXT["next"] and not menu.look_page.name_edit.get_parent().visible, "then the look (no name row: it was the step before), ending in Next")
	menu.look_page.finish.pressed.emit()
	await t._frames(2)
	_check(menu.page == "quiz", "Next goes on to the questions")
	# The questions, Back once, then the summary.
	var picks := ["hunter", "manticore", "born"]
	for i in 3:
		for b in _buttons(menu):
			if b.get_meta("answer", "") == picks[i]:
				b.pressed.emit()
				break
		await t._frames(1)
	_check(menu.page == "quiz" and StartPages.q == 3 and _button_with(menu, "begin") != null, "three answers, then a summary with Begin")
	menu.go_back()
	await t._frames(1)
	_check(StartPages.q == 2, "Back goes back a question")
	for b in _buttons(menu):
		if b.get_meta("answer", "") == "born":
			b.pressed.emit()
	await t._frames(1)
	main.await_tower()  # (the first climb's tower choice is waiting, as in play)
	_button_with(menu, "begin").pressed.emit()
	await t._frames(3)
	var prof = main.profile
	var Tr = load("res://scripts/training.gd")
	_check(prof.created and prof.home == "manticore" and main.tower == "manticore" and main.on_train and menu.page == "station" and menu.station_page.station == "manticore" and Tr.closed(prof),
		"Begin makes the climber and takes them to their home station, the towers closed until the Noble's Grace (training.gd)")
	_check(main.player.gear_id("melee") == "dagger" and main.player.gear_id("ranged") == "shortbow" and main.player.gear_id("armor") == "leather" and Gear.rarity(main.player.gear["armor"]) == "fine", "...dressed as a hunter born into it")
	_check(NewStart.can_skip_intro(), "...and counted as made on this device")
	menu.station_page.station = ""  # (the rest of this part is the start's pages again)
	main.on_train = false
	menu.close()
	await t._frames(1)
	StartPages.play_opening(menu)
	await t._frames(2)
	_check(menu.page == "intro" and _buttons(menu).any(func(b): return b.text == NewStart.TEXT["intro_skip"]), "the opening offers Skip")
	for b in _buttons(menu):
		if b.text == NewStart.TEXT["intro_skip"]:
			b.pressed.emit()
	await t._frames(1)
	_check(menu.page == "title", "...which goes to the title")
	# Every new button explains itself.
	var lacking: Array = []
	for pg in ["intro", "create_name", "quiz"]:
		menu.open(pg)
		await t._frames(1)
		for b in _buttons(menu):
			if Help.missing(b):
				lacking.append("%s: %s" % [pg, b.text])
	menu.open("title")
	await t._frames(1)
	for b in _buttons(menu):
		if b.text in [NewStart.TEXT["continue"], NewStart.TEXT["new_climber"], NewStart.TEXT["opening"]] and Help.missing(b):
			lacking.append("title: " + b.text)
	_check(lacking.is_empty(), "the Entity explains every new button (missing: %s)" % [lacking])
	# The Entity: tips and a topic.
	for id in ["slots", "intro", "create_name", "questionnaire"]:
		_check(Entity.TIPS.has(id), "the Entity has a first-time tip: %s" % id)
	_check(Talk.DIALOGUE.has("how_start") and Talk.DIALOGUE["how"]["choices"].has("how_start") and Talk.line_for(main, "how_start").length() > 100, "How does it work?: how the start works")
	menu.close()
	await t._frames(2)


# --- the colour wheel ---------------------------------------------------------------------------

func _wheel() -> void:
	print("new start: the colour wheel")
	var main = t.main
	var menu = main.menu
	main.touch._set_active(false)
	menu.open_appearance("climber")
	await t._frames(3)
	var page = menu.look_page
	page.show_tab("body", false)
	await t._frames(1)
	var row = page.rows["skin"]
	var mid: Rect2 = row._middle()
	var cells: int = row._cells()
	_check(cells == Appearance.OPTIONS["skin"].size() + 1 and Appearance.OPTIONS["skin"].size() == 6, "a colour row: six swatches and the colour wheel")
	row._hit(Vector2(mid.position.x + mid.size.x / cells * (cells - 0.5), row.size.y * 0.5))
	await t._frames(1)
	_check(page.wheel_key == "skin" and Appearance.is_custom(main.profile.appearance["skin"]), "its last cell opens the wheel, and the colour is your own")
	var before: String = main.profile.appearance["skin"]
	page.wheel_pad.change(4)
	page.wheel_rows[0].change(-3)
	await t._frames(1)
	var now: String = main.profile.appearance["skin"]
	_check(now != before and Appearance.is_custom(now) and main.climber_look["skin"].is_equal_approx(Color.html(now)), "turning the wheel and its brightness changes the skin, worn at once (%s -> %s)" % [before, now])
	page.wheel_rows[2].pressed.emit()
	await t._frames(1)
	_check(page.wheel_key == "" and page.rows.has("skin") and page.rows["skin"].value == now, "Done goes back to the rows, the colour kept")
	_check(Appearance.normalized({"skin": now})["skin"] == now and Appearance.normalized({"build": "#123456"})["build"] == Appearance.DEFAULTS["build"], "a colour of your own is kept on colour rows only")
	menu.close()
	await t._frames(2)


# --- a phone ---------------------------------------------------------------------------------

func _phone() -> void:
	print("new start: the pages at a phone's size")
	var main = t.main
	var menu = main.menu
	var was: Vector2i = t.root.size
	main.touch._set_active(true)
	var problems: Array = []
	for sz in [Vector2i(844, 390), Vector2i(800, 400)]:
		t.root.size = sz
		for pg in ["title", "intro", "create_name", "create", "quiz"]:
			if pg == "intro":
				StartPages.line = 5
			menu.open(pg)
			await t._frames(3)
			problems.append_array(t._fit_problems("%s %dx%d" % [pg, sz.x, sz.y], menu.panel, t.root.get_visible_rect()))
	_check(problems.is_empty(), "the start's pages fit a phone (%d problems): %s" % [problems.size(), problems.slice(0, 6)])
	StartPages.reset()
	menu.close()
	main.touch._set_active(false)
	t.root.size = was
	await t._frames(2)


func _words() -> void:
	var text := JSON.stringify(NewStart.INTRO) + JSON.stringify(NewStart.QUESTIONS) + JSON.stringify(NewStart.TEXT)
	var found: Array = BANNED.filter(func(w): return text.to_lower().contains(w))
	_check(found.is_empty(), "no banned words in the start's text (%s)" % [found])
