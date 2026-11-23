extends RefCounted
## The owner's story text in the game: the intro's six screens (no
## placeholder left), the 36 inscription stones (six a tower, the sixth
## climber's in the climber's pronouns), the Makers' 18 fragments (six each,
## the last in the climber's pronouns), the Entity's six story moments
## (marked and Unbound, said once per climber), the counting rhyme in the
## Dining car and from rivals, rivals mentioning their Entity, and no banned
## words in any of it. Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const NewStart := preload("res://scripts/new_start.gd")
const Ins := preload("res://scripts/inscriptions.gd")
const Makers := preload("res://scripts/makers.gd")
const Entity := preload("res://scripts/entity.gd")
const Guide := preload("res://scripts/guide.gd")
const Dining := preload("res://scripts/dining.gd")
const Rivals := preload("res://scripts/rivals.gd")
const Pronouns := preload("res://scripts/pronouns.gd")
const Towers := preload("res://scripts/towers.gd")

const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

var t


func run(smoke) -> void:
	t = smoke
	_intro()
	_stones()
	_fragments()
	_moments()
	_rhyme_and_rivals()
	_words()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _intro() -> void:
	print("story text: the intro")
	var lines: Array = NewStart.INTRO
	var placeholder := lines.any(func(l): return String(l[1]).to_lower().contains("placeholder") or String(l[1]).contains("[") or String(l[1]).strip_edges() == "")
	_check(lines.size() == 6 and not placeholder, "the intro has six screens, every one written (no placeholder)")
	_check(String(lines[0][1]).begins_with("The Sixfold was nearly unmade once.") and String(lines[4][1]).contains("your home station") and String(lines[5][1]).contains("People call it the Entity"), "...in the owner's words, screen 5 at your home station (the home isn't chosen before the questions)")


func _stones() -> void:
	print("story text: inscription stones")
	var n := 0
	var ok := true
	for tid in Towers.ORDER:
		var list: Array = Ins.INSCRIPTIONS.get(tid, [])
		n += list.size()
		ok = ok and list.size() == 6 and list.all(func(e): return String(e["text"]).length() > 20 and String(e["text"]) != "(Inscription to come)")
	_check(n == 36 and ok, "36 inscription stones, six for each of the six towers, every one written (%d)" % n)
	_check(String(Ins.INSCRIPTIONS["gryphon"][0]["text"]).contains("the Gryphon rides it") and String(Ins.INSCRIPTIONS["firebird"][5]["text"]).contains("six blades"), "...each tower's stones in its own tower")
	var keep := Pronouns.current
	Pronouns.current = "she"
	var she4 := String(Ins.words("chimera", 3)["text"])
	var she6 := String(Ins.words("chimera", 5)["text"])
	Pronouns.current = "he"
	var he6 := String(Ins.words("chimera", 5)["text"])
	Pronouns.current = "they"
	var they6 := String(Ins.words("chimera", 5)["text"])
	Pronouns.current = keep
	_check(she4 == "The Makers will ask her to stop. The one who was cast out will ask her to go on." and she6.ends_with("she will become, or she will break.") and he6.ends_with("he will become, or he will break.") and they6.ends_with("they will become, or they will break."), "the sixth climber's stones use the climber's pronouns (%s / %s)" % [she4, he6])
	_check(not String(Ins.words("chimera", 5)["text"]).contains("{") and not String(Ins.words("chimera", 3)["text"]).contains("{"), "...no token left showing")


func _fragments() -> void:
	print("story text: the Makers' fragments")
	var n := 0
	var six := true
	for m in Makers.ORDER:
		var list: Array = Makers.MAKERS[m]["fragments"]
		n += list.size()
		six = six and list.size() == 6 and list.all(func(l): return not Makers.is_redacted(l) and String(l).length() > 20)
	_check(n == 18 and six, "18 fragments, six for each Maker (%d)" % n)
	_check(String(Makers.MAKERS["marks"]["fragments"][0]).begins_with("Every mark I make is a promise kept") and String(Makers.MAKERS["towers"]["fragments"][0]).contains("first stone") and String(Makers.MAKERS["creatures"]["fragments"][0]).contains("I made the beasts"), "...each in its own Maker's voice")
	_check(Pronouns.fill_for(String(Makers.MAKERS["creatures"]["fragments"][5]), "he") == "When the sixth comes, I want to see what he becomes." and Pronouns.fill_for(String(Makers.MAKERS["towers"]["fragments"][5]), "they").ends_with("if they are not."), "the fragments about the sixth climber take their pronouns")


func _moments() -> void:
	print("story text: the Entity's six moments")
	var ids := ["train", "before_regard", "after_regard", "first_guardian", "three_guardians", "final"]
	_check(ids.all(func(id): return Entity.STORY.has(id) and Entity.story_line(id, false) != "" and Entity.story_line(id, true) != ""), "the Entity has a line for each of the story's six moments, marked and Unbound")
	_check(Entity.story_line("after_regard", true).begins_with("No mark. Good.") and Entity.story_line("after_regard", false).begins_with("A good mark.") and Entity.story_line("train", true) == Entity.story_line("train", false), "...the Unbound hear their own where there is one, the marked line where not")
	# Said once per climber (the guide is quiet in tests unless asked).
	Engine.set_meta("sixfold_tips", true)
	var kept: Dictionary = Guide.state.get("story", {}).duplicate()
	Guide.state["story"] = {}
	var first: String = Guide.story_now("final", true)
	var again: String = Guide.story_now("final", false)
	Guide.state["story"] = kept
	Engine.remove_meta("sixfold_tips")
	_check(first == Entity.story_line("final", true) and again == "", "a story moment is said once per climber")


func _rhyme_and_rivals() -> void:
	print("story text: the counting rhyme and rivals' Entities")
	_check(Dining.RHYME.size() == 6 and String(Dining.RHYME[0]) == "Count six wells, six stones, and six beasts that keep them.", "the counting rhyme's six lines")
	var f: Dictionary = Dining.fact(null, "rhyme", "kraken")
	var said := Dining.fill_in(String(Dining.RUMORS.filter(func(r): return String(r["fact"]) == "rhyme")[0]["lines"][0]), f)
	_check(String(f.get("rhyme", "")) in Dining.RHYME and said.contains(String(f["rhyme"])) and not said.contains("{"), "the Dining car hears it as a rumor, a line at a time: %s" % said)
	var main = t.main
	if main == null or main.rivals == null:
		return
	var prof = main.profile
	var lessons = prof.guardians
	prof.guardians = {}  # (no guardian rumour to pass on)
	var keep_e: float = float(Rivals.RULES.get("entity_chance", 0.0))
	var keep_r: float = float(Rivals.RULES.get("rhyme_chance", 0.0))
	Rivals.RULES["entity_chance"] = 1.0
	var ent: String = main.rivals._line("trade", {})
	Rivals.RULES["entity_chance"] = 0.0
	Rivals.RULES["rhyme_chance"] = 1.0
	var rhy: String = main.rivals._line("team", {})
	Rivals.RULES["entity_chance"] = keep_e
	Rivals.RULES["rhyme_chance"] = keep_r
	prof.guardians = lessons
	_check(Rivals.LINES["entity"].any(func(l): return ent.contains(String(l))), "a rival climber may mention their own Entity in passing: %s" % ent)
	_check(Dining.RHYME.any(func(l): return rhy.contains(String(l))) and not rhy.contains("{"), "...or a line of the counting rhyme: %s" % rhy)
	_check(keep_e > 0.0 and keep_e <= 0.1 and keep_r <= 0.1, "...rarely")


func _words() -> void:
	var texts: Array = [JSON.stringify(NewStart.INTRO), JSON.stringify(Ins.INSCRIPTIONS), JSON.stringify(Entity.STORY), JSON.stringify(Dining.RHYME),
		JSON.stringify(Dining.LINES["entity"]), JSON.stringify(Rivals.LINES["entity"]), JSON.stringify(Rivals.LINES["rhyme"])]
	for m in Makers.ORDER:
		texts.append(JSON.stringify(Makers.MAKERS[m]["fragments"]))
	var all := " ".join(texts).to_lower()
	var found: Array = BANNED.filter(func(w): return all.contains(w))
	_check(found.is_empty(), "no banned words in the story text (%s)" % [found])
