extends RefCounted
## THE STORY'S SCENES: the three moments the story turns on, with every word
## in TEXT (the Data editor: "The story's scenes"), so the owner can rewrite
## them. The lore: long ago people drew every essence at once and nearly
## unmade the world. Six held it together: two became Making and Unmaking,
## one became the Entity (cast out, its name taken, walking unseen beside
## every climber), three became the Makers (Marks, Towers, Creatures). They
## built six towers over six wells and set a guardian over each. A beaten
## guardian's well runs wild (wild_towers.gd). The sixth climber is you.
##
## 1. THE MAKERS AT THE REGARD (REGARD): at a climber's first Regard (the
##    floor-6 Regard, a fall's, or the guardian's refusal), after the
##    glimpse of the fracture (fracture.gd), the three Makers show
##    themselves for a few seconds: three vast shapes rising at the edge of
##    sight, each with its sign and colour, one short line each (another
##    line if the guardian is refusing the climber). A press skips it, as
##    it skips the glimpse. Once per climber (the record's "story").
##    main.gd _begin_regard and climb_shape.gd refuse_now start it, main.gd
##    _process runs it, hud.gd _draw_regard draws it (draw_regard below).
## 2. THE PLEA (TEXT "plea_*"): when the third guardian falls (main.gd, where
##    the Entity's "three_guardians" line is said), the plea is due; after
##    the summit's victory (climb_shape.gd before_leaving), or at the next
##    stair if that was missed, all three Makers meet the climber
##    (story_view.gd): "Stop, or become what we were." Three cards: I'll
##    stop / I'll go on / Tell me what you were (told, it becomes Say
##    nothing). Each answer moves the Makers' interest (makers.gd, PLEA) and
##    picks the Entity's next line (entity.gd STORY plea_*). Stopping never
##    ends anything: the climber can still climb; a fourth guardian beaten
##    after it is noted (STORY plea_broken). Once per climber.
## 3. THE FINAL MEETING (TEXT "final_*"): once all six guardians have fallen,
##    after the summit's victory, the Makers meet the climber and, for the
##    first time, see the Entity beside them. Three cards: Ascend (become a
##    Maker: holding Making and Unmaking together; a Sworn climber takes
##    their own Maker's place), Fight (the Entity's war, with the Summit
##    Blades: the wells stay wild), Not yet (they wait for another summit).
##    Then the ending (climb_shape.gd EndingView): the choice, the Entity's
##    truth (the marked: it used them; the Unbound: it was honest, they were
##    its army), and what comes after (ENDINGS).
## AFTER THE ENDING: the choice is kept with the climber; a title shown under
##    their name when no other is worn (TITLES, renown.gd worn_title);
##    Nobles, diners and rivals greet them by it (GREET, city_lore.gd
##    aura_line); the Entity says a word once (STORY after_ascend /
##    after_fight); an Ascended climber wears three small lights over their
##    head, a Breaker sheds sparks of the six essences (draw_on_climber).
##    The same climber plays on.
## In tests the scenes stay off (like the stair's barriers) unless a test
## turns them on (`force_on`). Kept with the climber: profile.record["story"]
## (state()).

const UI := preload("res://scripts/ui.gd")
const Draw := preload("res://scripts/draw_util.gd")
const Makers := preload("res://scripts/makers.gd")
const MakerView := preload("res://scripts/maker_view.gd")
const Pronouns := preload("res://scripts/pronouns.gd")
const Unbound := preload("res://scripts/unbound.gd")
const Towers := preload("res://scripts/towers.gd")
const Essence := preload("res://scripts/essence.gd")

## The Makers at the Regard: how long it plays (seconds), when a press may
## skip it, when each Maker rises (marks, towers, creatures), when each one's
## line shows, and when they start to go.
static var REGARD := {"seconds": 5.0, "skip_after": 0.4, "rise_at": [0.2, 0.6, 1.0], "line_at": [0.7, 1.5, 2.3], "gone_at": 4.2}
## The plea: how each answer moves each Maker's interest (makers.gd: what
## brings a Maker to a meeting and its secret bond). Never below zero.
static var PLEA := {
	"stop": {"marks": 60.0, "towers": 40.0, "creatures": -20.0},
	"go": {"marks": -60.0, "towers": -20.0, "creatures": 60.0},
	"silent": {"towers": 10.0},
	"ask": {"towers": 20.0, "creatures": 20.0},
}
## After the ending: how often a greeting follows the climber's choice.
static var AFTER := {"greet_chance": 0.5}

## Every word. {they}, {them}, {their}, {s}... are the climber's pronouns
## (pronouns.gd). A beat is {who, lines}: who is a Maker ("marks", "towers",
## "creatures"), "all" (the three as one), "entity", or "" (plain words).
## "unbound" lines replace "lines" for an Unbound climber; "if" shows a beat
## only when it holds ("sworn", "unsworn", "stopped": told them they'd stop).
static var TEXT := {
	# 1. The Makers at the Regard: one line each, as they look; "refusing"
	# when the guardian refuses the climber.
	"regard": {
		"marks": {"line": "\"Another one to count.\"", "refusing": "\"Unmarked. Count {them} anyway.\""},
		"towers": {"line": "\"Another climber on my stairs.\"", "refusing": "\"{They} went around my stairs. Of course {they} did.\""},
		"creatures": {"line": "\"Look at {them}. Look how {they} grow{s}.\"", "refusing": "\"No mark. Oh, look at {them}.\""},
	},
	"regard_caption": "Three shapes at the edge of sight, watching.",
	"regard_skip": "to skip",
	# Who speaks, by name.
	"names": {"all": "The Makers", "entity": "The Entity"},
	# 2. The plea, when the third guardian has fallen.
	"plea_beats": [
		{"who": "", "lines": ["The light bends. Three shapes stand around you, too vast for the sky."]},
		{"who": "towers", "lines": ["\"Three wells run wild beneath your feet, climber.\"", "\"Every stone I laid over them is cracking.\""]},
		{"who": "marks", "lines": ["\"We held the world together once, at a price you cannot imagine.\"", "\"You are undoing it, one guardian at a time.\""],
			"unbound": ["\"You refused the mark, and now you drink the wells raw, as we once did.\"", "\"You are undoing the keeping, one guardian at a time.\""]},
		{"who": "creatures", "lines": ["\"My children are falling. I have watched you grow on what spills out of them.\"", "\"I am not sure I want you to stop.\""]},
		{"who": "all", "lines": ["\"Stop, or become what we were.\""]},
	],
	"plea_answers": [
		{"id": "stop", "text": "I'll stop.", "desc": "They will remember you said it.", "help": "They'll be pleased. Nothing locks: you can still climb. They'll just remember you said it."},
		{"id": "go", "text": "I'll go on.", "desc": "They will not stop you. Not yet.", "help": "They won't stop you. Not today. The Maker of Creatures might even smile."},
		{"id": "ask", "text": "Tell me what you were.", "desc": "Hear it from them.", "help": "Ask. They rarely tell it. Listen for what they leave out."},
	],
	"plea_silent": {"id": "silent", "text": "Say nothing.", "desc": "Silence is an answer too.", "help": "Say nothing. They can't hold you to silence."},
	"plea_tell": [
		{"who": "marks", "lines": ["\"We were people once, like you. We drew every essence at once, as much as we could hold.\"", "\"And the world began to come apart.\""]},
		{"who": "towers", "lines": ["\"Six of us held it together. Two became Making and Unmaking themselves.\"", "\"One we cast out. We do not say its name.\""]},
		{"who": "creatures", "lines": ["\"Three of us became this. We built six towers over six wells, and set a beast over each.\"", "\"To hand essence out in small, safe marks. To keep it.\""]},
		{"who": "all", "lines": ["\"Stop, climber. Or become what we were.\""]},
	],
	"plea_replies": {
		"stop": {"who": "marks", "lines": ["\"Good. Order is a kindness, even when it does not feel like one.\""], "after": "The Makers will remember you said it. Nothing stops you climbing."},
		"go": {"who": "creatures", "lines": ["\"Then go on. Show me what you become.\""], "after": "The Makers will remember. The Maker of Creatures most of all."},
		"silent": {"who": "towers", "lines": ["\"Silence. I know that silence. I kept it too, once.\""], "after": "They let you go without an answer."},
	},
	# 3. The final meeting, when all six guardians have fallen.
	"final_beats": [
		{"who": "towers", "lines": ["\"Six guardians fallen. Six wells running wild.\"", "\"My stones are cracking all the way down.\""]},
		{"who": "marks", "lines": ["\"The old count gave six times six times six times six years between climbers who could undo the keeping.\"", "\"Five rose. You are the sixth.\""]},
		{"who": "marks", "if": "stopped", "lines": ["\"You told us you would stop.\""]},
		{"who": "creatures", "lines": ["\"The fifth made themself into six blades. You have carried pieces of Lann.\"", "\"What will you make of yourself?\""]},
		{"who": "", "lines": ["Something steps out from beside you. For the first time, the Makers see it."]},
		{"who": "marks", "lines": ["\"You.\""]},
		{"who": "towers", "lines": ["\"We cast you out. We took your name.\""]},
		{"who": "entity", "lines": ["\"And I walked beside every climber since. Beside this one, all the way up.\""]},
		{"who": "all", "if": "unsworn", "lines": ["\"Ascend. Hold Making and Unmaking together, as we do, and keep the wells.\"", "\"Be the next of us.\""]},
		{"who": "sworn", "if": "sworn", "lines": ["\"You carry my mark, sixth. I am tired.\"", "\"Hold Making and Unmaking together, and take my place.\""]},
		{"who": "entity", "lines": ["\"Or fight. With me, and with the blades Lann left behind.\"", "\"No more keeping. Let the wells run.\""]},
	],
	"final_answers": [
		{"id": "ascend", "text": "Ascend", "desc": "Become a Maker: hold Making and Unmaking, and keep the wells.", "desc_sworn": "Take the place of %s: hold Making and Unmaking.",
			"help": "They'll make you one of them. Ask what it cost them first."},
		{"id": "fight", "text": "Fight", "desc": "The Entity's war, with the Summit Blades. The wells stay wild.", "help": "Come with me. It will break things. Some things should break."},
		{"id": "not_yet", "text": "Not yet.", "desc": "Walk away. They will wait at another summit.", "help": "You can walk away. They'll be there. So will I."},
	],
	"final_replies": {
		"ascend": {"who": "all", "lines": ["\"Then come. It will not hurt for long.\""]},
		"ascend_sworn": {"who": "sworn", "lines": ["\"Then take it. It was always heavier than it looked.\""]},
		"fight": {"who": "entity", "lines": ["\"Then we begin.\""]},
		"not_yet": {"who": "towers", "lines": ["\"Then go. We will be waiting at the next summit.\""], "after": "The choice waits for your next summit."},
	},
	# The cards and the scene's controls.
	"confirm": "again to choose",
	"help_touch": "Tap a card to hear about it. Tap it again to choose.",
	"skip": "Skip",
	"go_on": "to go on",
	"ending_go_on": "to go on",
	"ending_skip": "Skip",
}

## The ending, page by page (climb_shape.gd EndingView): what was chosen,
## what the Entity was (the marked and the Unbound hear different truths),
## and what comes after. "scene" is the picture over the words. %s in the
## Sworn's first page is their Maker's name; {title} the title they now carry.
static var ENDINGS := {
	"ascend": {"title": "Ascension", "scene": "ascend", "lines": [
		"You take Making in one hand and Unmaking in the other, and you hold them.",
		"It is heavier than every mark, every tower, every guardian.",
		"Where there were three, there are four. The wells quiet, one by one."]},
	"ascend_sworn": {"title": "Ascension", "scene": "ascend", "lines": [
		"%s steps back, and is gone.",
		"Its sign settles over you. Making in one hand, Unmaking in the other.",
		"You are %s now. The wells quiet, one by one."]},
	"fight": {"title": "The War", "scene": "fight", "lines": [
		"You turn from the Makers. The Entity stands with you, and the six Summit Blades wake.",
		"The wells stay wild. Cracks run out from every tower.",
		"The keeping is over. What grows next is no one's to decide."]},
	"truth_ascend_marked": {"title": "What the Entity was", "scene": "entity", "lines": [
		"It does not follow you up.",
		"\"I used you,\" it says. \"Every word was to bring you here. You served the order I wanted broken.\"",
		"\"Now you are that order. I'm sorry. I would do it again.\""]},
	"truth_ascend_unbound": {"title": "What the Entity was", "scene": "entity", "lines": [
		"It does not follow you up.",
		"\"I never lied to you,\" it says. \"You were my army: one climber, and enough.\"",
		"\"Now you are one of them. Keep them honest.\""]},
	"truth_fight_marked": {"title": "What the Entity was", "scene": "entity", "lines": [
		"\"I used you,\" it says, \"and you let me.\"",
		"\"Every mark you carried was theirs. You served their order, and broke it with their own gifts.\"",
		"\"You were never mine. That's why it worked.\""]},
	"truth_fight_unbound": {"title": "What the Entity was", "scene": "entity", "lines": [
		"\"I told you the truth,\" it says. \"You were my army. You still are.\"",
		"\"Everything you drew was yours. Nobody gave it, nobody can ask for it back.\"",
		"\"Now let's see what the world is without a leash.\""]},
	"after_ascend": {"title": "After", "scene": "ring", "lines": [
		"The towers still stand. The cities will call you {title}.",
		"Some will bow. Some will be afraid.",
		"You keep climbing, as you are now."]},
	"after_fight": {"title": "After", "scene": "fight_after", "lines": [
		"The world is fracturing, slowly. All six towers stand wild.",
		"The cities will call you {title}.",
		"You keep climbing, as you are now."]},
}

## The title the climber carries after the ending (shown when no other is
## worn: renown.gd worn_title). "ascend_sworn" is the Maker whose place they took.
static var TITLES := {"ascend": "the Seventh Maker", "ascend_sworn": "%s", "fight": "the Breaker"}

## How people greet the climber after the ending, by choice and by who
## speaks (city_lore.gd aura_line: the Noble, the Dining car, rival climbers).
static var GREET := {
	"ascend": {
		"noble": ["\"A Maker, standing in my hall. Sit, please. Anywhere you like.\"", "(bowing low) \"We are honoured. We are also a little afraid.\"", "\"They say you sat with the Makers. They say you stayed.\""],
		"dining": ["\"Is it true? They say you're one of them now.\"", "\"Don't mind the staring. You'd stare too.\"", "(quietly) \"Is it heavy? What you hold?\""],
		"rival": ["\"You're the one who went up and became something.\"", "\"I'll not stand in a Maker's way.\"", "\"Do the towers still feel like towers, to you?\""],
	},
	"fight": {
		"noble": ["\"The ground split outside the city last night. They say it was you.\"", "\"Whatever you've begun, climber, I hope you know how it ends.\"", "\"The wells are wild, all six. My stewards can't keep the lamps steady.\""],
		"dining": ["\"Did you feel it? The whole car shook. A crack opened across the east road.\"", "\"My cousin saw wild essence pour out of the ground, glowing like a wound.\"", "\"They say the Breaker rides this train. Is that you?\""],
		"rival": ["\"The Breaker. I didn't believe it till the floor split under me.\"", "\"Six wild wells. The towers feel hungrier now.\"", "\"Whatever you broke, it's still breaking.\""],
	},
}

const KINDS := ["air", "water", "iron", "fire", "stone", "blade"]

## Tests turn the scenes on (they're off in tests otherwise, like barriers).
static var force_on := false


static func enabled() -> bool:
	return force_on or not Engine.has_meta("sixfold_test")


## The climber's story state (profile.record["story"]): "regard" (the Makers
## seen at the Regard), "plea_due", "plea" (stop / go / silent), "asked",
## "broken" (a guardian beaten after saying stop), "choice" (ascend / fight),
## "maker" (the Maker whose place an Ascended Sworn took).
static func state(prof) -> Dictionary:
	if prof == null:
		return {}
	var s = prof.record.get("story")
	if not (s is Dictionary):
		s = {}
		prof.record["story"] = s
	return s


static func _fill(prof, text: String) -> String:
	return Pronouns.fill_for(text, Pronouns.of_look(prof.get("appearance") if prof != null else null))


# --- 1. the Makers at the Regard ------------------------------------------------------------

## A Regard begins (main.gd _begin_regard, climb_shape.gd refuse_now): the
## first one for this climber has the Makers in it. True if it starts.
static func start_regard(rg: Dictionary, prof) -> bool:
	if not enabled() or prof == null or rg.is_empty():
		return false
	var s := state(prof)
	if bool(s.get("regard", false)):
		return false
	s["regard"] = true
	prof.save()
	rg["makers"] = float(REGARD["seconds"])
	rg["mt"] = 0.0
	return true


static func regard_active(rg: Dictionary) -> bool:
	return rg.has("makers") and float(rg.get("mt", 0.0)) < float(rg["makers"])


## Runs it a frame (main.gd _process, after the glimpse): `skip` (a press)
## ends it once skip_after has passed. True when it ended this frame.
static func regard_tick(rg: Dictionary, dt: float, skip: bool) -> bool:
	if not regard_active(rg):
		return false
	rg["mt"] = float(rg.get("mt", 0.0)) + dt
	if skip and float(rg["mt"]) > float(REGARD["skip_after"]):
		rg["mt"] = float(rg["makers"])
	return not regard_active(rg)


static func regard_finish(rg: Dictionary) -> void:
	if rg.has("makers"):
		rg["mt"] = float(rg["makers"])


## Each Maker's line at the Regard, in Makers.ORDER (the refusing ones if
## the guardian refuses the climber), the climber's pronouns filled.
static func regard_lines(prof, refusing: bool) -> Array:
	var out: Array = []
	for m in Makers.ORDER:
		var d: Dictionary = TEXT["regard"].get(m, {})
		out.append(_fill(prof, String(d.get("refusing" if refusing else "line", ""))))
	return out


## Where each Maker stands at the Regard: [centre, radius], rising behind
## the horizon at the bottom of the screen (their eyes just above it).
static func regard_spot(i: int, size: Vector2, rise: float) -> Array:
	var r := minf(size.x * 0.15, size.y * 0.42)
	var xs := [0.18, 0.5, 0.82]
	var c := Vector2(size.x * float(xs[i]), size.y * 0.88 + r * 0.35 * (1.0 - rise))
	return [c, r]


## Draws the Makers at the Regard (hud.gd _draw_regard): `t` seconds in.
static func draw_regard(c: CanvasItem, size: Vector2, font: Font, t: float, refusing: bool, prompt: String, prof) -> void:
	var total := float(REGARD["seconds"])
	var gone := clampf((t - float(REGARD["gone_at"])) / maxf(total - float(REGARD["gone_at"]), 0.1), 0.0, 1.0)
	c.draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.03, 1.0))
	var b := Draw.Batch.new()
	# Still stars (flat), the same every frame.
	for i in 30:
		var sp := Vector2(fposmod(float(i) * 211.7, size.x), fposmod(float(i) * 83.3 + float(i * i) * 2.7, size.y * 0.6))
		b.circle(sp, 1.0 + float(i % 3) * 0.4, Color(0.8, 0.82, 0.95, (0.2 + 0.12 * float(i % 4)) * (1.0 - gone)), 8)
	# The guardian's eye, half open overhead, looking down at the climber.
	var eye := Vector2(size.x * 0.5, size.y * 0.2)
	var open := clampf(t / 0.8, 0.0, 1.0) * 0.55
	var w := minf(size.x * 0.22, 190.0)
	var h := 44.0 * open
	var lid := PackedVector2Array()
	for i in 25:
		var k := float(i) / 24.0
		lid.append(eye + Vector2(lerpf(-w, w, k), -sin(PI * k) * h))
	for i in range(1, 24):
		var k := float(i) / 24.0
		lid.append(eye + Vector2(lerpf(w, -w, k), sin(PI * k) * h))
	if h > 1.0:
		b.polygon(lid, Color(0.95, 0.85, 0.55, 0.12 * (1.0 - gone * 0.5)))
	lid.append(lid[0])
	b.polyline(lid, Color(1.0, 0.85, 0.5, 0.7 * open + 0.1), 2.0)
	if h > 6.0:
		b.circle(eye + Vector2(0, h * 0.15), h * 0.7, Color(0.95, 0.8, 0.4, 0.5))
		b.circle(eye + Vector2(0, h * 0.15), h * 0.28, Color(0.02, 0.02, 0.03, 0.9))
	b.flush(c)
	# The three Makers, rising at the edge of sight, then gone.
	var rises: Array = REGARD["rise_at"]
	for i in Makers.ORDER.size():
		var m: String = Makers.ORDER[i]
		var rise := clampf((t - float(rises[i])) / 0.7, 0.0, 1.0)
		var a := rise * (1.0 - gone)
		if a <= 0.0:
			continue
		var spot := regard_spot(i, size, rise)
		var col := Makers.color(m)
		MakerView.draw_presence(c, spot[0], spot[1], t + i * 2.0, col, Makers.MAKERS[m]["sign"], a * 0.85)
		# Its sign, clear, over it.
		var sb := Draw.Batch.new()
		var sc: Vector2 = spot[0] - Vector2(0, float(spot[1]) * 1.12)
		sb.soft(sc, Vector2.ONE * 18.0, Color(col, 0.3 * a))
		Makers.draw_sign(sb, sc, 8.0, Makers.MAKERS[m]["sign"], Color(col.lightened(0.35), 0.95 * a), 1.6)
		sb.flush(c)
	# The climber, small, on the tower's top, between them.
	var feet := Vector2(size.x * 0.5, size.y - 8.0)
	c.draw_rect(Rect2(Vector2(0, size.y - 8.0), Vector2(size.x, 8.0)), Color(0.08, 0.07, 0.1, 1.0))
	climber(c, feet, 16.0, 1.0, Color(0.95, 0.85, 0.55))
	# Their words: flat, outlined, one over each.
	var lines := regard_lines(prof, refusing)
	var ats: Array = REGARD["line_at"]
	var fs := 15 if size.y >= 500.0 else 13
	for i in lines.size():
		var la := clampf((t - float(ats[i])) / 0.4, 0.0, 1.0) * (1.0 - gone)
		if la <= 0.0:
			continue
		var spot := regard_spot(i, size, 1.0)
		var tw := size.x * 0.3
		var top: float = float(spot[0].y) - float(spot[1]) * 1.12 - 22.0 - fs * 2.0
		var at := Vector2(float(spot[0].x) - tw * 0.5, top)
		var col := Makers.color(Makers.ORDER[i]).lightened(0.3)
		UI.draw_text_lines(c, font, at + Vector2(1, 1), String(lines[i]), HORIZONTAL_ALIGNMENT_CENTER, tw, fs, 2, Color(0, 0, 0, 0.8 * la))
		UI.draw_text_lines(c, font, at, String(lines[i]), HORIZONTAL_ALIGNMENT_CENTER, tw, fs, 2, Color(col, la))
	var cap_a := clampf((t - 0.3) / 0.5, 0.0, 1.0) * (1.0 - gone)
	var cy := eye.y + 44.0 + 30.0
	c.draw_string_outline(font, Vector2(0, cy), String(TEXT["regard_caption"]), HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, 5, Color(0, 0, 0, 0.8 * cap_a))
	c.draw_string(font, Vector2(0, cy), String(TEXT["regard_caption"]), HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color(UI.TEXT, cap_a))
	if t > float(REGARD["skip_after"]):
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
		c.draw_string(font, Vector2(0, eye.y - 54.0), prompt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(UI.DIM, 0.4 + 0.4 * pulse))


## A small hooded climber seen from behind, for scale (a rim of `rim`).
static func climber(c: CanvasItem, feet: Vector2, h: float, a: float, rim: Color) -> void:
	var b := Draw.Batch.new()
	b.contact(feet, h * 0.5, 0.45 * a)
	var body := PackedVector2Array([feet + Vector2(-h * 0.28, 0), feet + Vector2(-h * 0.2, -h * 0.62), feet + Vector2(-h * 0.14, -h * 0.78),
		feet + Vector2(0, -h * 1.02), feet + Vector2(h * 0.14, -h * 0.78), feet + Vector2(h * 0.2, -h * 0.62), feet + Vector2(h * 0.28, 0)])
	b.poly(body, Color(0.1, 0.08, 0.12, a), 1.2)
	var edge := PackedVector2Array(body)
	b.polyline(edge, Color(rim, 0.5 * a), 1.0)
	b.flush(c)


# --- 2. the plea ------------------------------------------------------------------------------

## A guardian has fallen (main.gd on_enemy_killed): `beaten` towers' guardians
## so far. The third brings the plea; one more after saying "stop" is noted.
static func on_guardian(main, beaten: int) -> void:
	var prof = main.profile
	if prof == null:
		return
	var s := state(prof)
	if beaten >= 3 and not s.has("plea") and prof.count("ending") <= 0:
		s["plea_due"] = true
	elif beaten >= 4 and String(s.get("plea", "")) == "stop" and not bool(s.get("broken", false)):
		s["broken"] = true
		main.story("plea_broken")  # (the Makers noticed: entity.gd STORY)
	prof.save()


## True when the Makers' plea waits to be shown.
static func plea_due(prof) -> bool:
	if prof == null:
		return false
	var s := state(prof)
	return bool(s.get("plea_due", false)) and not s.has("plea")


# --- the scenes' beats and cards (story_view.gd) -------------------------------------------------

## Does a beat's "if" hold for this climber?
static func _holds(prof, cond: String) -> bool:
	var sworn: bool = Makers.core(prof).get("maker", "") != ""
	match cond:
		"sworn":
			return sworn
		"unsworn":
			return not sworn
		"stopped":
			return String(state(prof).get("plea", "")) == "stop"
	return true


## The beats a scene opens with ("plea", "final", or "tell": the Makers'
## story), filtered and filled: [{who, lines}]. "sworn" becomes the Maker
## whose mark the climber carries.
static func beats(prof, list_key: String) -> Array:
	var out: Array = []
	var ub: bool = prof != null and Unbound.is_on(prof)
	for bt in TEXT.get(list_key, []):
		if bt.has("if") and not _holds(prof, String(bt["if"])):
			continue
		out.append(_beat(prof, bt, ub))
	return out


static func _beat(prof, bt: Dictionary, ub: bool) -> Dictionary:
	var who := String(bt.get("who", ""))
	if who == "sworn":
		who = String(Makers.core(prof).get("maker", "marks"))
	var lines: Array = bt.get("unbound", bt["lines"]) if ub else bt["lines"]
	return {"who": who, "lines": lines.map(func(l): return _fill(prof, String(l)))}


## The cards on offer: [{id, text, desc, help}].
static func answers(prof, kind: String) -> Array:
	var out: Array = []
	if kind == "plea":
		for a in TEXT["plea_answers"]:
			if a["id"] == "ask" and bool(state(prof).get("asked", false)):
				out.append(TEXT["plea_silent"].duplicate())
			else:
				out.append(a.duplicate())
		return out
	var mk := String(Makers.core(prof).get("maker", ""))
	for a in TEXT["final_answers"]:
		var d: Dictionary = a.duplicate()
		if d["id"] == "ascend" and mk != "" and d.has("desc_sworn"):
			d["desc"] = String(d["desc_sworn"]) % String(Makers.MAKERS[mk]["name"])
		out.append(d)
	return out


## What a speaker is called on screen.
static func speaker_name(who: String) -> String:
	if Makers.MAKERS.has(who):
		return String(Makers.MAKERS[who]["Name"])
	return String(TEXT["names"].get(who, ""))


## An answer taken in a scene (story_view.gd): what happens, as {beats (the
## reply), after (plain words, "" for none), then ("answer": back to the
## cards; "finish")}. Records the answer with the climber.
static func answer(main, kind: String, id: String) -> Dictionary:
	var prof = main.profile
	var s := state(prof)
	if kind == "plea":
		_interest(main, id)
		if id == "ask":
			s["asked"] = true
			prof.save()
			return {"beats": beats(prof, "plea_tell"), "after": "", "then": "answer"}
		s["plea"] = id
		s.erase("plea_due")
		prof.save()
		var r: Dictionary = TEXT["plea_replies"].get(id, {"who": "", "lines": []})
		return {"beats": [_beat(prof, r, false)], "after": _fill(prof, String(r.get("after", ""))), "then": "finish"}
	# The final meeting.
	var mk := String(Makers.core(prof).get("maker", ""))
	var key := id
	match id:
		"ascend":
			s["choice"] = "ascend"
			s["maker"] = mk
			if mk != "":
				key = "ascend_sworn"
		"fight":
			s["choice"] = "fight"
			s["maker"] = ""
	if id in ["ascend", "fight"]:
		var R = load("res://scripts/renown.gd")
		R.state(prof)["worn"] = ""  # (the new title shows: renown.gd worn_title)
	prof.save()
	var r: Dictionary = TEXT["final_replies"].get(key, {"who": "", "lines": []})
	return {"beats": [_beat(prof, r, false)], "after": _fill(prof, String(r.get("after", ""))), "then": "finish"}


## The plea's answers move the Makers' interest (makers.gd), never below zero.
static func _interest(main, id: String) -> void:
	var mk = main.get("makers")
	if mk == null or not is_instance_valid(mk):
		return
	var st: Dictionary = mk.st()
	if st.is_empty():
		return
	var d: Dictionary = PLEA.get(id, {})
	for m in d:
		st["interest"][m] = maxf(0.0, float(st["interest"].get(m, 0.0)) + float(d[m]))


# --- after the ending ---------------------------------------------------------------------

## The climber's choice at the final meeting ("" before it: "ascend", "fight").
static func choice(prof) -> String:
	if prof == null:
		return ""
	return String(state(prof).get("choice", ""))


## The title the ending gave ("" for none).
static func title_of(prof) -> String:
	match choice(prof):
		"ascend":
			var mk := String(state(prof).get("maker", ""))
			if mk != "" and Makers.MAKERS.has(mk):
				return String(TITLES["ascend_sworn"]) % String(Makers.MAKERS[mk]["name"])
			return String(TITLES["ascend"])
		"fight":
			return String(TITLES["fight"])
	return ""


## The ending's pages for the climber's choice: [{title, lines, scene}]
## ([] before a choice: climb_shape.gd shows its plain ENDING then).
static func ending_pages(prof) -> Array:
	var c := choice(prof)
	if c == "":
		return []
	var ub := Unbound.is_on(prof)
	var mk := String(state(prof).get("maker", ""))
	var keys: Array = ["ascend_sworn" if c == "ascend" and mk != "" else c, "truth_%s_%s" % [c, "unbound" if ub else "marked"], "after_" + c]
	var out: Array = []
	var title := title_of(prof)
	for k in keys:
		var d: Dictionary = ENDINGS.get(k, {})
		var lines: Array = []
		for l in d.get("lines", []):
			var s := String(l)
			if s.contains("%s") and mk != "" and Makers.MAKERS.has(mk):
				s = s % String(Makers.MAKERS[mk]["Name"] if s.begins_with("%s") else Makers.MAKERS[mk]["name"])
			lines.append(_fill(prof, s.replace("{title}", title)))
		out.append({"title": String(d.get("title", "")), "lines": lines, "scene": String(d.get("scene", "ring")), "key": k})
	return out


## What `who` ("noble", "dining", "rival") says to a climber after the
## ending, by their choice ("" before it, or when the roll falls to their
## usual words: AFTER "greet_chance"; `chance` for tests).
static func greeting(prof, who: String, chance := -1.0) -> String:
	var lines: Array = GREET.get(choice(prof), {}).get(who, [])
	if lines.is_empty() or randf() >= (float(AFTER["greet_chance"]) if chance < 0.0 else chance):
		return ""
	return _fill(prof, String(lines[randi() % lines.size()]))


## On the climber in the world (player.gd): the Ascended wear three small
## lights over their head (the Makers' colours, turning); a Breaker sheds
## sparks of the six essences. Nothing before the ending.
static func draw_on_climber(p, prof, t: float) -> void:
	var c := choice(prof)
	if c == "" or p.dead:
		return
	var b := Draw.Batch.new()
	var head := Vector2(0, -30)
	if c == "ascend":
		for i in 3:
			var ang := t * 1.1 + TAU * float(i) / 3.0
			var at := head + Vector2(cos(ang) * 9.0, sin(ang) * 3.0 - 4.0)
			var col := Makers.color(Makers.ORDER[i])
			b.soft(at, Vector2.ONE * 4.5, Color(col, 0.35))
			b.ball(at, 1.6, Color(col.lightened(0.3), 0.95), false)
	else:
		for i in 6:
			var f := fposmod(t * 0.6 + float(i) / 6.0, 1.0)
			var at := Vector2(sin(float(i) * 2.1) * 8.0, -12.0 - f * 22.0)
			var col := Essence.color(KINDS[i])
			b.soft(at, Vector2.ONE * 3.5, Color(col, 0.4 * (1.0 - f)))
	b.flush(p)


# --- the ending's pictures (climb_shape.gd EndingView) --------------------------------------------

## The picture over an ending page: `kind` its "scene", centred on `c` with
## room `rr`; `t` seconds in; `a` fades it.
static func draw_scene(ci: CanvasItem, kind: String, c: Vector2, rr: float, t: float, a: float, prof) -> void:
	match kind:
		"ascend":
			_scene_ascend(ci, c, rr, t, a, prof)
		"fight", "fight_after":
			_scene_fight(ci, c, rr, t, a, kind == "fight")
		"entity":
			_scene_entity(ci, c, rr, t, a)


## Three Makers in a row and the climber becoming the fourth (a Sworn takes
## their own Maker's place: it fades, they rise in its colour).
static func _scene_ascend(ci: CanvasItem, c: Vector2, rr: float, t: float, a: float, prof) -> void:
	var mk := String(state(prof).get("maker", "")) if prof != null else ""
	var r := rr * 0.36
	var rise := clampf((t - 0.6) / 1.4, 0.0, 1.0)
	var xs: Array = [-3.6, -1.2, 1.2, 3.6] if mk == "" else [-2.6, 0.0, 2.6]
	var i := 0
	for m in Makers.ORDER:
		var at := c + Vector2(float(xs[i]) * r, 0)
		var fade := a * (1.0 - rise if m == mk else 1.0)
		if fade > 0.01:
			MakerView.draw_presence(ci, at, r, t + i, Makers.color(m), Makers.MAKERS[m]["sign"], fade * 0.9)
		if m == mk:
			MakerView.draw_presence(ci, at + Vector2(0, (1.0 - rise) * r * 0.8), r * (0.6 + 0.4 * rise), t, Makers.color(m).lerp(UI.GOLD, 0.35), Makers.MAKERS[m]["sign"], a * rise)
		i += 1
	if mk == "":
		var at := c + Vector2(float(xs[3]) * r, (1.0 - rise) * r * 0.8)
		MakerView.draw_presence(ci, at, r * (0.6 + 0.4 * rise), t + 7.0, UI.GOLD, "", a * rise)


## Six towers on the horizon with their wells running wild, cracks running
## out from them across the ground, the six Summit Blades standing before
## them (`blades`).
static func _scene_fight(ci: CanvasItem, c: Vector2, rr: float, t: float, a: float, blades: bool) -> void:
	var b := Draw.Batch.new()
	var w := rr * 4.2
	var ground := c.y + rr * 0.7
	b.rect(Rect2(Vector2(c.x - w * 0.6, ground), Vector2(w * 1.2, rr * 0.5)), Color(0.12, 0.1, 0.14, a))
	var crack := clampf((t - 0.4) / 1.6, 0.0, 1.0)
	var Blades = load("res://scripts/summit_blades.gd")
	for i in 6:
		var x := c.x - w * 0.5 + w * (float(i) + 0.5) / 6.0
		var col := Essence.color(KINDS[i])
		var tw := rr * 0.16
		var th := rr * (0.9 + 0.15 * float(i % 2))
		b.contact(Vector2(x, ground + 1.0), tw * 0.9, 0.3 * a)
		b.box(Rect2(Vector2(x - tw * 0.5, ground - th), Vector2(tw, th)), Color(0.42, 0.38, 0.48, a))
		b.fill(PackedVector2Array([Vector2(x - tw * 0.7, ground - th), Vector2(x, ground - th - tw * 1.3), Vector2(x + tw * 0.7, ground - th)]), Color(0.36, 0.32, 0.44, a))
		# The well running wild over it.
		for s in 3:
			var up := fposmod(t * 0.7 + float(s) * 0.33 + float(i) * 0.17, 1.0)
			b.soft(Vector2(x + sin(t * 2.0 + i + s) * 4.0, ground - th - tw * 1.4 - up * rr * 0.7), Vector2.ONE * (6.0 + 10.0 * up), Color(col, 0.55 * (1.0 - up) * a))
		# A crack running out from its foot.
		var pts := PackedVector2Array()
		var at := Vector2(x, ground + 2.0)
		pts.append(at)
		for k in 4:
			at += Vector2(sin(float(i * 5 + k * 3) * 1.3) * rr * 0.14, rr * 0.11)
			pts.append(at)
		var part := PackedVector2Array()
		var n := maxi(2, int(ceil(pts.size() * crack)))
		for k in mini(n, pts.size()):
			part.append(pts[k])
		if crack > 0.0 and part.size() >= 2:
			b.polyline(part, Color(col, 0.35 * a), 5.0)
			b.polyline(part, Color(col.lightened(0.3), 0.9 * a), 1.6)
		if blades:
			var bx := x + rr * 0.05
			var bcol: Color = Blades.color(Towers.ORDER[i % Towers.ORDER.size()]) if Towers.ORDER.size() > 0 else col
			var up := clampf((t - 0.8 - i * 0.12) / 0.5, 0.0, 1.0)
			if up > 0.0:
				b.bar(Vector2(bx, ground + rr * 0.18), Vector2(bx, ground + rr * 0.18 - rr * 0.55 * up), Color(bcol.lightened(0.2), a), 2.4)
				b.bar(Vector2(bx - 5.0, ground + rr * 0.1), Vector2(bx + 5.0, ground + rr * 0.1), Color(0.5, 0.42, 0.3, a), 2.0)
				b.soft(Vector2(bx, ground - rr * 0.2 * up), Vector2.ONE * 6.0, Color(bcol, 0.4 * up * a))
	b.flush(ci)


## The Entity, seen at last, beside the small climber.
static func _scene_entity(ci: CanvasItem, c: Vector2, rr: float, t: float, a: float) -> void:
	var Entity = load("res://scripts/entity.gd")
	var k := clampf(t / 1.0, 0.0, 1.0)
	Entity.draw_face(ci, c + Vector2(rr * 0.35, -rr * 0.1), rr * 0.55, t, a * k)
	climber(ci, c + Vector2(-rr * 0.5, rr * 0.75), rr * 0.5, a, Color(0.8, 0.85, 1.0))
