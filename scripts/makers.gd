extends Node2D
## The Makers: three godlike beings, siblings of the Entity, who made the
## world the climber walks through. The Maker of Marks made the bonds, the
## Maker of Towers the towers, the Maker of Creatures the monsters. They watch
## every climb from outside the towers.
##
## What this file does:
##   FRAGMENTS (their traces): rarely a secret room or a sealed wing's vault
##   holds a pale inscription on its north wall with a Maker's sign, faintly
##   lit. Walking up to it reads it: the room's light shifts in the Maker's
##   colour, the Entity goes quiet for a while, and it's kept on the Maker's
##   shelf in the Archive (menu.gd). Never on the main path, never needed.
##   INTEREST: each Maker keeps a score across every climb, fed by what it
##   cares about (WEIGHTS). Other scripts call Makers.feed(main, "event").
##   GLIMPSES: as interest grows, now and then after a stair: a second
##   shadow, the light bending, or the Entity going quiet.
##   THE MEETING: once you've found REVEAL.fragments fragments, a Maker whose
##   interest has crossed its threshold shows itself in the quiet after a
##   stair (maker_view.gd draws it and asks for an answer). A good answer
##   grants its secret bond: the CORE MARK, drawn over the whole body.
##   One secret bond per climber.
##
## THE MAKERS' WORDS are written (the owner approved the first draft): what
## each says, its fragments and the Entity's line about it. Any line can
## still be REDACTED instead: a string of "▇" and spaces draws as
## blacked-out word-shaped bars (redact_into). Names, colours, signs,
## numbers and the answers (placeholders) are all here, in data.
##
## Saved in the profile (profile.gd `makers`, a dictionary; see state()). The
## secret bond itself is the profile's `core_mark` (a SECRET_BONDS id, or "")
## and `core_depth` (0 to 5): the secret bonds' tools read those.

const UI := preload("res://scripts/ui.gd")
const Draw := preload("res://scripts/draw_util.gd")
const Bonds := preload("res://scripts/bonds.gd")
const ProfileScript := preload("res://scripts/profile.gd")

## The redaction mark: a word is a run of these (its length is the bar's).
const R := "▇"

## The three Makers. Names are placeholders until the owner names them.
## "sign": eye, trowel or paw (draw_sign). "bond": the secret bond it grants.
## "secret": the secret essence it gives when it grants or deepens its bond
## (shares of SECRET_ESSENCE). "good": which answers it takes well
## (placeholders for the owner). Every line is redacted until written:
##   speech      what it says when it shows itself
##   good / bad  its reply to a good or a bad answer
##   already     its reply to a good answer when you carry another's core mark
##   plea_yes / plea_no   its answer to a plea for a change of path
##   interrupt   what it says when it interrupts a sibling's meeting
##   entity      the Entity's line about it (the Archive, once you've met one)
##   fragments   its traces' words, one per fragment found (cycling)
const MAKERS := {
	"marks": {
		"name": "the Maker of Marks", "Name": "The Maker of Marks", "short": "Marks",
		"made": "the bonds", "sign": "eye", "color": Color(0.56, 0.92, 1.0),
		"bond": "developer", "secret": {"life": 0.5, "unmaking": 0.5},
		"good": ["understand", "change"],
		"speech": ["You carry my work, climber. Every mark on you is a line I wrote.", "I have watched you read it. Some of it you have even understood.", "So tell me plainly: what do you want from the marks?"],
		"good_reply": ["Good. Then take a pen of your own, and be careful what you write."],
		"bad_reply": ["No. You want a bigger cage, and you call it a gift."],
		"already": ["You already answer to another of us. I do not write over a sibling's hand."],
		"plea_yes": ["Very well. I will pull up the root and let it fall. Begin again, and choose with care."],
		"plea_no": ["No. What took root in you belongs there. Grow around it."],
		"interrupt": ["Careful. That one is already written in my hand.", "Say nothing to it you would not say to me."],
		"entity": ["The first of my siblings counts everything. It counted me once."],
		"fragments": [
			"A mark is a door left open. What walks through it is up to you.",
			"Essence does not choose a body. It chooses a habit.",
			"Every bond was made to be outgrown. Few climbers try.",
			"The faint ones are not weak. They are only unfinished.",
			"Two marks of one kind will argue. Let them.",
			"Nothing I wrote cannot be rewritten. Only, it costs.",
			"Those who refuse my marks still carry my ink. It runs looser in them.",
			"I measure what you spend, not what you hold.",
		],
	},
	"towers": {
		"name": "the Maker of Towers", "Name": "The Maker of Towers", "short": "Towers",
		"made": "the towers", "sign": "trowel", "color": Color(1.0, 0.7, 0.32),
		"bond": "designer", "secret": {"unmaking": 1.0},
		"good": ["understand", "nothing"],
		"speech": ["You have walked my stairs and leaned on my walls. Some of them leaned back.", "Every course I laid, I laid for climbers. Even the traps. Most of all the traps.", "Now tell me: what do you want from what I built?"],
		"good_reply": ["Then learn the craft. Build with care, and leave each wall better than you found it."],
		"bad_reply": ["You would pull out the stones to see how they stood. No."],
		"already": ["You wear another's mark. My towers will still stand for you. That is all I give."],
		"plea_yes": ["Stone can be recut. Once. Do not ask me twice."],
		"plea_no": ["A foundation does not change because the house dislikes it."],
		"interrupt": ["Mind where you stand. That floor is mine.", "Ask it what you like. It will not answer as well as stone."],
		"entity": ["My builder sibling never stops. It would not stop for me, either."],
		"fragments": [
			"The seals are not locks. They are questions the tower asks.",
			"No floor is the same twice. I am not idle.",
			"A trap no one can cross is a wall. I do not build walls for climbers.",
			"Where the mortar is cracked, I am listening.",
			"The stair is always there. I only ask that you earn it.",
			"Rooms remember who walked them. So do I.",
			"I built the towers to be climbed, not conquered.",
			"Every tower leans a little toward its beast. I let it.",
		],
	},
	"creatures": {
		"name": "the Maker of Creatures", "Name": "The Maker of Creatures", "short": "Creatures",
		"made": "the monsters", "sign": "paw", "color": Color(1.0, 0.44, 0.56),
		"bond": "manipulator", "secret": {"life": 1.0},
		"good": ["understand", "nothing"],
		"speech": ["You have killed many of my children. You have spared a few.", "Both were watched. Both are remembered.", "Tell me, little climber: what do you want from them?"],
		"good_reply": ["Then walk among them, and they will learn your scent."],
		"bad_reply": ["You want them for a weapon. They are not yours to swing."],
		"already": ["Another of us has marked you. My children will still know your face."],
		"plea_yes": ["Very well. Let it bleed out of you, and begin again."],
		"plea_no": ["No. You chose your blood. Live in it."],
		"interrupt": ["Gently. That one has hurt my young.", "Speak with care. My children are listening."],
		"entity": ["My warmest sibling. It loved the monsters before it loved anything else."],
		"fragments": [
			"Every creature here was made for a reason. Most of them know it.",
			"The beasts are not cruel. They are hungry, and they are watching.",
			"A spared thing remembers. So does its brood.",
			"Essence is a life, given back. Do not waste what you take.",
			"The slimes came first. Do not laugh; every beginning is small.",
			"A champion is only a creature that has been afraid for a long time.",
			"When a beast falls, something of it comes to you. Carry it kindly.",
			"My children fight the way you taught them. Look closely.",
		],
	},
}
const ORDER := ["marks", "towers", "creatures"]

## The secret bonds (their tools come in a later step: for now the core mark
## is recorded and shown). Names decided for now by the owner.
const SECRET_BONDS := {
	"developer": {"name": "the Developer", "Name": "Developer", "maker": "marks", "what": "tools for the bonds"},
	"designer": {"name": "the Designer", "Name": "Designer", "maker": "towers", "what": "tools for the tower"},
	"manipulator": {"name": "the Manipulator", "Name": "Manipulator", "maker": "creatures", "what": "tools for the creatures"},
}

## The answers in a meeting. PLACEHOLDERS for the owner: short, neutral
## intents (which ones a Maker takes well is in its "good" list).
const ANSWERS := [
	{"id": "understand", "text": "To understand it.", "placeholder": false},
	{"id": "take", "text": "To take more of it.", "placeholder": false},
	{"id": "change", "text": "To change it.", "placeholder": false},
	{"id": "nothing", "text": "Nothing. Only to climb.", "placeholder": false},
]
## The plea for a change of path (Life or Unmaking): offered once you have a path.
const PLEA := {"id": "plea", "text": "Ask for a change of path", "desc": "It may refuse. If it agrees, your path and all its flow are cleared."}
## The same plea with a full vessel offered (one carried on your belt,
## vessel.gd): likelier to be granted (PLEA_ODDS "vessel").
const VESSEL_PLEA := {"id": "plea_vessel", "text": "Offer the vessel", "desc": "A plea for a change of path: likelier granted. It keeps the vessel."}

## Fragments: on this share of floors (at most one a floor), from this floor
## up, never on the first climb; read within `reach` of the wall. The light:
## its faint glow, and the shift when one is read (seconds, how far the
## darkness tints toward the Maker's colour). The Entity is quiet this long.
const FRAGMENT := {"chance": 0.125, "min_floor": 2, "reach": 34.0, "glow_reach": 95.0, "glow": 0.45,
	"shift_time": 4.5, "shift_tint": 0.55, "quiet": 9.0, "moment": 3.2}
## The reveal: at least this many fragments found in all, then interest over
## the threshold (each time a Maker turns you away its threshold grows by
## `turned_extra` of itself, and its interest drops to `turned_keep` of it).
## At most `per_climb` meetings a climb; `delay` after the stair's fade.
const REVEAL := {"fragments": 6, "threshold": 400.0, "turned_extra": 0.5, "turned_keep": 0.35, "per_climb": 1, "delay": 0.8}
## Glimpses: once interest reaches `from` of the threshold, after a stair, at
## this chance (more as interest grows, up to `most`), at most `per_climb`.
const GLIMPSE := {"from": 0.35, "chance": 0.2, "most": 0.45, "per_climb": 1, "time": 3.0, "quiet": 14.0,
	"kinds": ["shadow", "bend", "quiet"]}
## After you carry a core mark, the Maker whose mark it is may interrupt
## another Maker's meeting: how it plays out (weights).
const INTERRUPT := {"chance": 0.5, "ways": {"cut_short": 1.0, "contradict": 1.0, "listen": 1.0}}
## A plea for a change of path: the chance a Maker agrees (more if its
## interest is high: + `per_ratio` for each threshold's worth past one).
## A full vessel offered with it adds `vessel` (up to `vessel_most`); the
## Maker takes the vessel whether it agrees or not (`vessel_back` true: a
## refusal hands it back).
const PLEA_ODDS := {"agree": 0.4, "per_ratio": 0.15, "most": 0.8, "vessel": 0.35, "vessel_most": 0.95, "vessel_back": false}
## Secret essence a Maker gives when it grants its bond (split by its "secret").
const SECRET_ESSENCE := 24.0

## What each Maker cares about, through its own craft: event -> {maker: weight}.
## Fed by Makers.feed(main, event, amount) from the scripts where things happen.
##   cast: a spell cast (player.gd); new_spell: the first cast of a spell this
##   climb (variety); step: a bond step grown (at the stair); mark: a new mark
##   taken; trap_dodged: rolled or jumped through a firing trap (traps.gd);
##   trap_disarmed: (no hook yet: nothing disarms a trap); secret_room: a
##   secret wall leaned open (wings.gd); door: a locked door opened (doors.gd);
##   vault: a sealed wing's vault opened; puzzle: a floor's puzzle solved;
##   kill, champion, beast: monsters slain (main.gd); spared: (no hook yet:
##   nothing lets a monster go); wound: per whole health bar lost (player.gd);
##   flow_life / flow_unmaking: per 10 of a secret essence banked (read at the
##   stair, if the game has them); fragment: a fragment read (and fragment_own
##   on top for its own Maker).
const WEIGHTS := {
	"cast": {"marks": 0.5},
	"new_spell": {"marks": 4.0},
	"step": {"marks": 10.0, "towers": 1.0, "creatures": 1.0},
	"mark": {"marks": 10.0, "towers": 4.0, "creatures": 4.0},
	"trap_dodged": {"towers": 3.0},
	"trap_disarmed": {"towers": 5.0},
	"secret_room": {"towers": 8.0},
	"door": {"towers": 2.0},
	"vault": {"towers": 6.0},
	"puzzle": {"towers": 6.0},
	"kill": {"creatures": 0.3},
	"champion": {"creatures": 8.0},
	"beast": {"creatures": 12.0, "marks": 3.0, "towers": 3.0},
	"spared": {"creatures": 6.0},
	"wound": {"marks": 2.0, "towers": 2.0, "creatures": 4.0},
	"flow_life": {"creatures": 3.0, "marks": 1.0, "towers": 0.5},
	"flow_unmaking": {"towers": 3.0, "marks": 1.0, "creatures": 0.5},
	"fragment": {"marks": 5.0, "towers": 5.0, "creatures": 5.0},
	"fragment_own": {"marks": 10.0, "towers": 10.0, "creatures": 10.0},
}

## Plain words (mechanical text only).
const TEXT := {
	"fragment_title": "A FRAGMENT",
	"fragment_line": "Fragments found: %d",
	"shelf": "The forbidden shelf",
	"shelf_count": "%d %s",
	"fragment_where": "Fragment %d  ·  %s, floor %d",
	"met": "Met %d %s",
	"turned": "Turned you away %d %s",
	"core": "Core mark: %s, depth %d",
	"core_short": "Core mark: %s",
	"granted": "It grants its bond: %s.",
	"core_line": "A core mark covers your body (depth %d).",
	"turned_away": "It turns away. For now.",
	"one_only": "You already carry a core mark: one secret bond per climber.",
	"plea_yes": "It agrees: your path is cleared.",
	"plea_no": "It refuses.",
	"plea_none": "It agrees, but nothing here can change your path yet.",
	"vessel_taken": "It takes the vessel.",
	"cut_short": "%s cuts the meeting short.",
	"contradict": "%s speaks over it, then falls silent.",
	"listen": "%s stays, and listens.",
	"secret_gain": "+%d %s",
	"placeholder": "placeholder",
	"go_on": "to go on",
	"choose": "Answer",
}

var main
## Who answers the hooks (gain_secret / rise_secret, reset_path, path): main,
## unless a test stands something in.
var hooks
var chance_override := -1.0  # tests and dev: the share of floors with a fragment
var interrupt_chance: float = INTERRUPT["chance"]  # (tests set it, and interrupt_way)
var interrupt_way := ""
var plea_force := -1  # tests: 1 a plea is granted, 0 refused, -1 by chance
var fragment := {}  # this floor's fragment: {maker, src, ref, wall, read_at, room, read, light}
var shift_t := 0.0  # the room's light shifting after a fragment is read
var shift_col := Color.WHITE
var shift_light := -1
var quiet_t := 0.0  # the Entity is quiet while this runs (and during a meeting)
var moment_t := 0.0  # the fragment's words float over it
var glimpse := {}  # {maker, kind, t, pos}
var glimpses_climb := 0
var meetings_climb := 0
var pending := ""  # a Maker waiting to show itself (after the stair's fade)
var pending_t := 0.0
var pending_dev := false
var view  # the meeting (maker_view.gd) while it shows
var seen_spells := {}  # spells cast this climb (variety)
var over: Node2D  # drawn over the darkness: the fragment's words while they show
var redraw_t := 0.0
var _over_on := false  # the words over the fragment are drawn (cleared once they're done)


func _ready() -> void:
	z_index = -3  # on the walls and floor, under everyone
	if hooks == null:
		hooks = main
	over = Node2D.new()
	over.z_index = 45
	over.z_as_relative = false
	over.draw.connect(_draw_over)
	add_child(over)


# --- the saved state ------------------------------------------------------------------

## The Makers' saved state in a profile, with every key present (old saves
## and new climbers start empty):
##   fragments: [{maker, n, tower, floor}], interest: {maker: score},
##   met: {maker: meetings}, turned: {maker: times turned away},
##   glimpses: count,
##   seen: what was last counted of the body {steps, marks, life, unmaking}.
static func state(prof) -> Dictionary:
	if prof == null:
		return {}
	var s = prof.get("makers")
	if not (s is Dictionary):
		s = {}
		prof.set("makers", s)
	if not (s.get("fragments") is Array):
		s["fragments"] = []
	for k in ["interest", "met", "turned", "seen"]:
		if not (s.get(k) is Dictionary):
			s[k] = {}
	for m in ORDER:
		s["interest"][m] = float(s["interest"].get(m, 0.0))
	s["glimpses"] = int(s.get("glimpses", 0))
	return s


func st() -> Dictionary:
	return state(main.profile if main != null else null)


static func fragment_count(prof, maker := "") -> int:
	var s := state(prof)
	if s.is_empty():
		return 0
	if maker == "":
		return s["fragments"].size()
	return s["fragments"].filter(func(f): return f.get("maker", "") == maker).size()


static func has_met(prof, maker := "") -> bool:
	var s := state(prof)
	if s.is_empty():
		return false
	if maker == "":
		return ORDER.any(func(m): return int(s["met"].get(m, 0)) > 0)
	return int(s["met"].get(maker, 0)) > 0


## A Maker's shelf shows in the Archive once its first fragment is found or it has been met.
static func shelf_shown(prof, maker: String) -> bool:
	return fragment_count(prof, maker) > 0 or has_met(prof, maker)


## The climber's core mark as {bond, maker, depth} ({} without one), from the
## profile's core_mark and core_depth.
static func core(prof) -> Dictionary:
	if prof == null:
		return {}
	var bond = prof.get("core_mark")
	if not (bond is String) or not SECRET_BONDS.has(bond):
		return {}
	return {"bond": bond, "maker": SECRET_BONDS[bond]["maker"], "depth": maxi(int(prof.get("core_depth")), 1)}


## Records a core mark (one per climber): the profile's core_mark and core_depth.
static func set_core(prof, bond: String, depth: int) -> void:
	prof.set("core_mark", bond)
	prof.set("core_depth", depth)


## "Core mark: the Developer, depth 1" (or "" without one).
static func core_text(prof) -> String:
	var c := core(prof)
	if c.is_empty() or not SECRET_BONDS.has(c.get("bond", "")):
		return ""
	return TEXT["core"] % [SECRET_BONDS[c["bond"]]["name"], int(c.get("depth", 1))]


static func core_color(prof) -> Color:
	var c := core(prof)
	return MAKERS.get(c.get("maker", ""), {}).get("color", Color.WHITE)


static func color(maker: String) -> Color:
	return MAKERS.get(maker, {}).get("color", Color.WHITE)


## The interest a Maker needs to show itself (more each time it turned you away).
func threshold(maker: String) -> float:
	var turned := int(st()["turned"].get(maker, 0))
	return float(REVEAL["threshold"]) * (1.0 + float(REVEAL["turned_extra"]) * turned)


func interest(maker: String) -> float:
	return float(st()["interest"].get(maker, 0.0))


# --- interest -------------------------------------------------------------------------

## Something a Maker cares about happened (a one-line call from where it
## happens): Makers.feed(main, "kill"). Does nothing without a main or Makers.
static func feed(m, event: String, amount := 1.0, key := "") -> void:
	if m == null or not is_instance_valid(m):
		return
	var mk = m.get("makers")
	if mk != null and is_instance_valid(mk):
		mk.note(event, amount, key)


func note(event: String, amount := 1.0, key := "") -> void:
	if main == null or main.profile == null:
		return
	if event == "cast" and key != "" and not seen_spells.has(key):
		seen_spells[key] = true
		note("new_spell")
	var w: Dictionary = WEIGHTS.get(event, {})
	if w.is_empty():
		return
	var s := st()
	for m in w:
		s["interest"][m] = float(s["interest"].get(m, 0.0)) + float(w[m]) * amount


## The body, counted again (at each stair): bond steps grown and marks taken
## since the last count, and secret essence banked (if the game has it).
## The first count only sets where counting starts.
func sync_body() -> void:
	if main == null or main.profile == null:
		return
	var prof = main.profile
	var s := st()
	var steps := 0
	for part in prof.bonds:
		steps += ProfileScript.step_for_xp(float(prof.bonds[part].get("xp", 0.0)))
	var now := {"steps": steps, "marks": prof.bonds.size()}
	var path := current_path()
	var flow = prof.get("flow")
	if path in ["life", "unmaking"] and (flow is float or flow is int):
		now[path] = float(flow)
	var seen: Dictionary = s["seen"]
	if not seen.is_empty():
		if now["steps"] > int(seen.get("steps", 0)):
			note("step", now["steps"] - int(seen.get("steps", 0)))
		if now["marks"] > int(seen.get("marks", 0)):
			note("mark", now["marks"] - int(seen.get("marks", 0)))
		for k in ["life", "unmaking"]:
			if now.has(k) and now[k] > float(seen.get(k, 0.0)):
				note("flow_" + k, (now[k] - float(seen.get(k, 0.0))) / 10.0)
	for k in ["life", "unmaking"]:
		if not now.has(k) and seen.has(k):
			now[k] = seen[k]
	s["seen"] = now


## The climber's secret-essence path ("life", "unmaking" or ""), if the game has one.
func current_path() -> String:
	for o in [main.profile if main != null else null, hooks]:
		if o == null:
			continue
		var v = o.get("path")
		if v is String and v != "":
			return v
	return ""


# --- fragments ------------------------------------------------------------------------

## A new floor (main.gd _start_floor, after the wings): forget the last
## floor's fragment, and maybe place one in a secret room or a vault.
## `force` (the dev tool): one now, if the floor has a place for it.
func setup_floor(force := false) -> void:
	clear_floor()
	if main == null or not main.layout_on or main.in_camp:
		return
	if not force and (main.first_climb or main.floor_num < int(FRAGMENT["min_floor"])):
		return
	var chance := chance_override if chance_override >= 0.0 else float(FRAGMENT["chance"])
	if not force and randf() >= chance:
		return
	var spots := candidates()
	if spots.is_empty():
		return
	fragment = spots[randi() % spots.size()]
	fragment["maker"] = _pick_maker()
	fragment["read"] = false
	fragment["light"] = -1
	queue_redraw()


func clear_floor() -> void:
	if not fragment.is_empty() and main != null and main.lighting != null and int(fragment.get("light", -1)) >= 0:
		main.lighting.remove_light(fragment["light"])
	fragment = {}
	_end_shift()
	moment_t = 0.0
	glimpse = {}
	queue_redraw()
	if over != null:
		over.queue_redraw()


## Where a fragment may go on this floor: the north wall of each secret
## room and of each sealed wing's vault alcove (never anywhere else).
func candidates() -> Array:
	var out: Array = []
	var W = main.wings
	if W == null:
		return out
	for s in W.secrets:
		var openings: Array = s.get("door", []).duplicate()
		if s.has("vault_door"):
			openings.append(s["vault_door"])
		var spot := _wall_spot(s["rect"], openings)
		if not spot.is_empty():
			spot["src"] = "secret"
			spot["ref"] = s
			out.append(spot)
	for w in W.wings:
		if not w.has("alcove"):
			continue
		var spot := _wall_spot(w["alcove"], [w["vault_door"]])
		if not spot.is_empty():
			spot["src"] = "vault"
			spot["ref"] = w
			out.append(spot)
	return out


## A spot on a room's north wall away from its openings: {wall (the plaque,
## on the wall's face), read_at (in front of it), room, tile}.
func _wall_spot(rect: Rect2, openings: Array) -> Dictionary:
	var tiles: Array = main._tiles_in(rect)
	if tiles.is_empty():
		return {}
	var y0: int = tiles[0].y
	var xs: Array = []
	for t in tiles:
		if t.y == y0:
			xs.append(t.x)
	var open_x: Array = []
	for o in openings:
		if o is Vector2i and o.y == y0 - 1:
			open_x.append(o.x)
	var best := -1
	var best_score := -INF
	var mid := (float(xs.min()) + float(xs.max())) * 0.5
	for x in xs:
		if x in open_x:
			continue
		var gap := 99.0
		for ox in open_x:
			gap = minf(gap, absf(float(x - ox)))
		var score := minf(gap, 3.0) * 2.0 - absf(float(x) - mid)
		if score > best_score:
			best_score = score
			best = x
	if best < 0:
		return {}
	var c: float = main.Floors.CELL
	var top: float = main.room.position.y + y0 * c
	var x_px: float = main.room.position.x + (best + 0.5) * c
	return {"wall": Vector2(x_px, top - 14.0), "read_at": Vector2(x_px, top + 14.0), "room": rect, "tile": Vector2i(best, y0)}


## Which Maker a new fragment belongs to: even odds, leaning toward those
## with fewer fragments found.
func _pick_maker() -> String:
	var table := {}
	for m in ORDER:
		table[m] = 1.0 / (1.0 + fragment_count(main.profile, m))
	var total := 0.0
	for m in table:
		total += table[m]
	var r := randf() * total
	for m in table:
		r -= table[m]
		if r <= 0.0:
			return m
	return ORDER[0]


## The fragment's room is open (a secret leaned open, a vault opened).
func fragment_open() -> bool:
	if fragment.is_empty():
		return false
	var ref: Dictionary = fragment["ref"]
	if fragment["src"] == "secret":
		return bool(ref.get("open", false))
	return String(ref.get("vault", "sealed")) in ["open", "lesser", "taken"]


## Reads this floor's fragment: kept on its Maker's shelf; the light shifts;
## the Entity goes quiet.
func read_fragment() -> void:
	if fragment.is_empty() or fragment["read"]:
		return
	fragment["read"] = true
	var m: String = fragment["maker"]
	var s := st()
	s["fragments"].append({"maker": m, "n": fragment_count(main.profile, m), "tower": main.tower, "floor": main.floor_num})
	note("fragment")
	_feed_own(m)
	var col := color(m)
	shift_col = col
	shift_t = float(FRAGMENT["shift_time"])
	moment_t = float(FRAGMENT["moment"])
	quiet_t = maxf(quiet_t, float(FRAGMENT["quiet"]))
	var room: Rect2 = fragment["room"]
	if main.lighting != null:
		if shift_light >= 0:
			main.lighting.remove_light(shift_light)
		shift_light = main.lighting.add_light(room.get_center(), maxf(room.size.x, room.size.y) * 0.8 + 60.0, col, 0.0, 0.25)
	main.light_flash(fragment["wall"], col, 2.2, 1.8, 0.9)
	main.fx_ring(fragment["wall"], col, 70.0, 0.9, 3.0)
	main.sfx("glint", 0.5, -2.0, 0.0)
	main.sfx("ready", 0.45, -8.0, 0.0)
	main.banner = {"title": TEXT["fragment_title"], "lines": [TEXT["fragment_line"] % fragment_count(main.profile)], "t": 3.0}
	main.profile.save()
	main.tip("fragment")
	queue_redraw()


## (fragment_own goes only to the fragment's own Maker.)
func _feed_own(m: String) -> void:
	var w: Dictionary = WEIGHTS.get("fragment_own", {})
	var s := st()
	s["interest"][m] = float(s["interest"].get(m, 0.0)) + float(w.get(m, 0.0))


func _end_shift() -> void:
	shift_t = 0.0
	if main != null and main.lighting != null:
		if shift_light >= 0:
			main.lighting.remove_light(shift_light)
		main.lighting.mat.set_shader_parameter("dark_color", main.lighting.dark_color)
	shift_light = -1


## How strongly the light is shifted now (0..1): up fast, a hold, then down.
func shift_k() -> float:
	if shift_t <= 0.0:
		return 0.0
	var total := float(FRAGMENT["shift_time"])
	var age := total - shift_t
	return clampf(age / 0.5, 0.0, 1.0) * clampf(shift_t / 1.6, 0.0, 1.0)


# --- each frame -----------------------------------------------------------------------

## The Entity keeps quiet (guide.gd shows no bubble).
func quiet() -> bool:
	return quiet_t > 0.0 or meeting_live()


func meeting_live() -> bool:
	return view != null and is_instance_valid(view)


func _process(delta: float) -> void:
	if main == null or main.player == null:
		return
	quiet_t = maxf(0.0, quiet_t - delta)
	var p = main.player
	if not fragment.is_empty():
		var opened := fragment_open()
		if opened and int(fragment["light"]) < 0 and main.lighting != null:
			fragment["light"] = main.lighting.add_light(fragment["wall"] + Vector2(0, 18), float(FRAGMENT["glow_reach"]), color(fragment["maker"]), float(FRAGMENT["glow"]), 0.3)
			queue_redraw()
		if opened and not fragment["read"] and not p.dead and not main.climbing \
				and p.global_position.distance_to(fragment["read_at"]) < float(FRAGMENT["reach"]) + p.radius:
			read_fragment()
		redraw_t -= delta
		if opened and redraw_t <= 0.0 and _on_screen(fragment["wall"]):
			redraw_t = 1.0 / 15.0
			queue_redraw()
	if shift_t > 0.0:
		shift_t -= delta
		if shift_t <= 0.0:
			_end_shift()
		else:
			var k := shift_k()
			var dark: Color = main.lighting.dark_color
			var tint := Color(shift_col.darkened(0.72), dark.a)
			main.lighting.mat.set_shader_parameter("dark_color", dark.lerp(tint, k * float(FRAGMENT["shift_tint"])))
			if main.lighting.lights.has(shift_light):
				main.lighting.lights[shift_light]["k"] = 0.55 * k
	if moment_t > 0.0 or _over_on:
		moment_t -= delta
		_over_on = moment_t > 0.0
		over.queue_redraw()
	if not glimpse.is_empty():
		glimpse["t"] -= delta
		if glimpse["t"] <= 0.0:
			glimpse = {}
		queue_redraw()
	if pending != "":
		if not _calm():
			return
		pending_t -= delta
		if pending_t <= 0.0:
			var m := pending
			pending = ""
			start_meeting(m)


func _on_screen(pos: Vector2) -> bool:
	var cam: Camera2D = main.camera
	if cam == null:
		return true
	var view_size: Vector2 = get_viewport_rect().size / cam.zoom
	return Rect2(cam.get_screen_center_position() - view_size * 0.5, view_size).grow(80.0).has_point(pos)


## Nothing else is going on: a Maker may show itself now.
func _calm() -> bool:
	return not main.climbing and main.fade < 0.05 and not main.menu_open() and not main.camp_choosing \
		and not main.overlay_showing() and not main.player.dead and not main.on_train and not main.choosing_tower \
		and not main.title_showing() and not meeting_live()


# --- after a stair: glimpses and the reveal ----------------------------------------------

## A stair was climbed and the next floor has begun (main.gd _arrive): count
## the body, then perhaps a Maker shows itself, or a glimpse of one.
func on_arrive() -> void:
	sync_body()
	if main.first_climb or main.proving.on:
		return
	var m := ready_maker()
	if m != "" and meetings_climb < int(REVEAL["per_climb"]):
		pending = m
		pending_t = float(REVEAL["delay"])
		pending_dev = false
		return
	_maybe_glimpse()


## The Maker that would show itself now ("" for none): only once enough
## fragments are found, and only one whose interest has crossed its
## threshold (the most taken first). Not the one whose core mark you carry.
func ready_maker() -> String:
	if fragment_count(main.profile) < int(REVEAL["fragments"]):
		return ""
	var c := core(main.profile)
	var best := ""
	var best_k := 1.0
	for m in ORDER:
		if c.get("maker", "") == m:
			continue
		var k := interest(m) / threshold(m)
		if k >= best_k:
			best_k = k
			best = m
	return best


func _maybe_glimpse(force := "") -> void:
	if glimpses_climb >= int(GLIMPSE["per_climb"]) and force == "":
		return
	var best := ""
	var best_k := float(GLIMPSE["from"])
	for m in ORDER:
		var k := interest(m) / threshold(m)
		if k >= best_k:
			best_k = k
			best = m
	if force != "":
		best = force
	if best == "":
		return
	var odds := minf(float(GLIMPSE["chance"]) * best_k / float(GLIMPSE["from"]) * 0.5 + float(GLIMPSE["chance"]) * 0.5, float(GLIMPSE["most"]))
	if force == "" and randf() >= odds:
		return
	var kinds: Array = GLIMPSE["kinds"]
	start_glimpse(best, kinds[randi() % kinds.size()])


## A glimpse of a Maker: "shadow" (a second shadow beside the climber),
## "bend" (the light bends for a moment) or "quiet" (the Entity falls silent).
func start_glimpse(maker: String, kind: String) -> void:
	glimpses_climb += 1
	st()["glimpses"] = int(st()["glimpses"]) + 1
	var p = main.player
	var col := color(maker)
	glimpse = {"maker": maker, "kind": kind, "t": float(GLIMPSE["time"]), "pos": p.global_position, "dir": Vector2.from_angle(randf_range(-2.6, -0.5))}
	quiet_t = maxf(quiet_t, float(GLIMPSE["quiet"]) if kind == "quiet" else 4.0)
	match kind:
		"bend":
			main.light_flash(p.global_position, col, 3.0, 1.0, 1.4)
			main.fx_ring(p.global_position, Color(col, 0.3), 170.0, 1.6, 1.0)
			shift_col = col
			shift_t = 1.8
			main.sfx("glint", 0.35, -10.0, 0.0)
		"shadow":
			main.sfx("step", 0.5, -14.0, 0.0)
	main.tip("glimpse")
	queue_redraw()


# --- the meeting ----------------------------------------------------------------------

## A Maker shows itself now: the game pauses and maker_view.gd plays the
## scene. If you carry another Maker's core mark, that one may interrupt.
func start_meeting(maker: String) -> void:
	if meeting_live() or not MAKERS.has(maker):
		return
	meetings_climb += 1
	var c := core(main.profile)
	var interrupter := ""
	var way := ""
	if c.get("maker", "") != "" and c["maker"] != maker and randf() < interrupt_chance:
		interrupter = c["maker"]
		way = interrupt_way if interrupt_way != "" else _weighted(INTERRUPT["ways"])
	var layer := CanvasLayer.new()
	layer.layer = 9  # over the HUD and the touch buttons, under the menu (10)
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	main.add_child(layer)
	view = load("res://scripts/maker_view.gd").new()
	view.main = main
	view.makers = self
	view.maker = maker
	view.interrupter = interrupter
	view.way = way
	layer.add_child(view)
	if main.player != null:
		main.player.velocity = Vector2.ZERO
	get_tree().paused = true
	main.sfx("warn_knight", 0.35, -6.0, 0.0)
	main.sfx("glint", 0.3, -4.0, 0.0)


## The answers on offer: the placeholders, and the plea once you have a path.
func answers() -> Array:
	var out: Array = ANSWERS.duplicate()
	if current_path() != "":
		out.append(PLEA)
		if main != null and main.player != null and load("res://scripts/vessel.gd").full_on_belt(main.player):
			out.append(VESSEL_PLEA)
	return out


## The chance a Maker grants a plea now (`vessel`: with a full vessel offered).
func plea_odds(maker: String, vessel := false) -> float:
	var k := interest(maker) / threshold(maker)
	var odds := minf(float(PLEA_ODDS["agree"]) + float(PLEA_ODDS["per_ratio"]) * maxf(k - 1.0, 0.0), float(PLEA_ODDS["most"]))
	if vessel:
		odds = minf(odds + float(PLEA_ODDS["vessel"]), float(PLEA_ODDS["vessel_most"]))
	return odds


## The climber answered (maker_view.gd): what happens, as
## {good, granted, lines (mechanical), reply (redacted), gains}.
func answer(maker: String, id: String) -> Dictionary:
	var s := st()
	var d: Dictionary = MAKERS[maker]
	s["met"][maker] = int(s["met"].get(maker, 0)) + 1
	var out := {"good": false, "granted": "", "lines": [], "reply": "", "gains": {}}
	if id == "plea" or id == "plea_vessel":
		var offered: bool = id == "plea_vessel" and main != null and main.player != null and load("res://scripts/vessel.gd").full_on_belt(main.player)
		var odds := plea_odds(maker, offered)
		var yes: bool = (randf() < odds and plea_force != 0) or plea_force == 1
		if offered and (yes or not bool(PLEA_ODDS["vessel_back"])):
			load("res://scripts/vessel.gd").take(main.player)  # (an offering: the Maker keeps it)
			out["lines"].append(TEXT["vessel_taken"])
		if yes:
			out["reply"] = _line(d["plea_yes"])
			if hooks != null and hooks.has_method("reset_path"):
				hooks.reset_path()
				out["lines"].append(TEXT["plea_yes"])
			else:
				out["lines"].append(TEXT["plea_none"])
			out["good"] = true
		else:
			out["reply"] = _line(d["plea_no"])
			out["lines"].append(TEXT["plea_no"])
		main.profile.save()
		return out
	var good: bool = id in d["good"]
	out["good"] = good
	if not good:
		s["turned"][maker] = int(s["turned"].get(maker, 0)) + 1
		s["interest"][maker] = threshold(maker) * float(REVEAL["turned_keep"])
		out["reply"] = _line(d["bad_reply"])
		out["lines"].append(TEXT["turned_away"])
	elif not core(main.profile).is_empty():
		out["reply"] = _line(d["already"])
		out["lines"].append(TEXT["one_only"])
	else:
		var bond: String = d["bond"]
		set_core(main.profile, bond, 1)
		out["granted"] = bond
		out["reply"] = _line(d["good_reply"])
		out["lines"].append(TEXT["granted"] % SECRET_BONDS[bond]["name"])
		out["lines"].append(TEXT["core_line"] % 1)
		var gains := {}
		for k in d["secret"]:
			gains[k] = roundf(SECRET_ESSENCE * float(d["secret"][k]))
		out["gains"] = gains
	main.profile.save()
	return out


## The meeting is over (maker_view.gd): the game goes on; secret essence
## given now (so nothing it starts happens under the meeting).
func end_meeting(result: Dictionary) -> void:
	if view != null and is_instance_valid(view):
		var layer = view.get_parent()
		view.queue_free()
		if layer != null:
			layer.queue_free()
	view = null
	if not main.menu_open():
		get_tree().paused = false
	quiet_t = maxf(quiet_t, 1.5)
	var gains: Dictionary = result.get("gains", {})
	for k in gains:
		give_secret(k, float(gains[k]))
	main.tip("maker")
	if result.get("granted", "") != "":
		main.tip("core_mark")
		if main.player != null:
			main.player.queue_redraw()
			main.fx_ring(main.player.global_position, core_color(main.profile), 60.0, 0.8, 3.0)
			main.light_flash(main.player.global_position, core_color(main.profile), 2.0, 1.6, 0.6)


## HOOK for the secret essences (Life and Unmaking, built elsewhere): a Maker
## gives some when it grants or deepens its bond. Calls main.gain_secret(kind,
## amount) if the game has it (or main.rise_secret(kind, amount, pos)),
## otherwise does nothing. True if something took it.
func give_secret(kind: String, amount: float) -> bool:
	if hooks == null or amount <= 0.0:
		return false
	if hooks.has_method("gain_secret"):
		hooks.gain_secret(kind, amount)
		return true
	if hooks.has_method("rise_secret") and main.player != null:
		hooks.rise_secret(kind, amount, main.player.global_position + Vector2(0, -60))
		return true
	return false


static func _line(list: Array) -> String:
	return String(list[randi() % list.size()]) if not list.is_empty() else ""


static func _weighted(table: Dictionary) -> String:
	var total := 0.0
	for k in table:
		total += float(table[k])
	var r := randf() * total
	for k in table:
		r -= float(table[k])
		if r <= 0.0:
			return k
	return table.keys()[0]


# --- dev tools (menu.gd) -------------------------------------------------------------

## A fragment found (of each Maker in turn), as if read.
func dev_fragment() -> String:
	var m: String = ORDER[fragment_count(main.profile) % ORDER.size()]
	st()["fragments"].append({"maker": m, "n": fragment_count(main.profile, m), "tower": main.tower, "floor": main.floor_num})
	note("fragment")
	_feed_own(m)
	main.profile.save()
	return m


func dev_interest(maker: String, amount: float) -> void:
	st()["interest"][maker] = interest(maker) + amount
	main.profile.save()


## The Maker that would come for the dev tool's "meet now": the most
## interested one you don't carry the core mark of.
func dev_choice() -> String:
	var c := core(main.profile)
	var best := ""
	var best_k := -1.0
	for m in ORDER:
		if c.get("maker", "") == m:
			continue
		var k := interest(m) / threshold(m)
		if k > best_k:
			best_k = k
			best = m
	return best


## A meeting as soon as the menu closes (whatever the fragments and interest).
func dev_meet() -> String:
	var m := dev_choice()
	if m != "":
		pending = m
		pending_t = 0.3
		pending_dev = true
	return m


func dev_clear() -> void:
	main.profile.set("makers", {})
	set_core(main.profile, "", 0)
	state(main.profile)
	main.profile.save()
	fragment = {}
	glimpse = {}
	queue_redraw()


# --- drawing: the fragment and the glimpse ----------------------------------------------

func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001
	var b := Draw.Batch.new()
	if not fragment.is_empty() and fragment_open():
		plaque_into(b, fragment["wall"], fragment["maker"], t, fragment["read"])
	if not glimpse.is_empty() and glimpse["kind"] == "shadow":
		_shadow_into(b, t)
	b.flush(self)


## A fragment on a wall's face: a pale slab cut with word-shaped lines (its
## words, redacted), its Maker's sign above them, glowing faintly.
static func plaque_into(b, c: Vector2, maker: String, t: float, read: bool) -> void:
	var col := color(maker)
	var pulse := 0.5 + 0.5 * sin(t * 1.7)
	UI.glow_into(b, c, 24.0, col, 0.3 + 0.2 * pulse + (0.2 if read else 0.0))
	# A smoothed patch of the wall, a shade paler than the stone, cut into it.
	var r := Rect2(c - Vector2(15, 12), Vector2(30, 24))
	var stone := Color(0.42, 0.4, 0.42).lerp(col, 0.1)
	b.rect(r, Color(0.1, 0.09, 0.11, 0.8))
	b.rect(r.grow(-1.0), stone)
	b.rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 1.2)), Color(1, 1, 1, 0.12))
	draw_sign(b, c + Vector2(0, -5.5), 3.6, MAKERS[maker]["sign"], Color(col.lightened(0.2), 0.55 + 0.35 * pulse))
	# The words: short cut strokes in three rows (redacted until written).
	var ink := Color(0.12, 0.11, 0.13, 0.85) if not read else Color(col.lightened(0.1), 0.7)
	var rows := [[3, 5, 2], [4, 2, 4], [5, 3]]
	for i in rows.size():
		var x := r.position.x + 4.0
		var y := c.y + 1.5 + i * 3.4
		for wl in rows[i]:
			var w := float(wl) * 1.6
			if x + w > r.end.x - 3.5:
				break
			b.line(Vector2(x, y), Vector2(x + w, y), ink, 1.2)
			x += w + 1.6


## A second shadow beside the climber at the stair: long, thin and wrong,
## edged in its Maker's colour, fading in and out.
func _shadow_into(b, t: float) -> void:
	var total := float(GLIMPSE["time"])
	var k := clampf((total - float(glimpse["t"])) / 0.6, 0.0, 1.0) * clampf(float(glimpse["t"]) / 0.9, 0.0, 1.0)
	var at: Vector2 = glimpse["pos"] + Vector2(0, 9)
	var dir: Vector2 = glimpse["dir"]
	var side := dir.orthogonal()
	var length := 110.0 + 8.0 * sin(t * 1.3)
	# A body's shadow stretched far too long: shoulders, then a head.
	for i in 14:
		var f := float(i) / 13.0
		var w := (9.0 + 5.0 * sin(f * PI * 0.9)) * (1.0 - f * 0.45)
		b.circle(at + dir * length * f * 0.82 + side * sin(f * 3.0 + t * 1.6) * 3.0 * f, w, Color(0.0, 0.0, 0.02, 0.5 * k))
	b.circle(at + dir * length * 0.9, 10.0, Color(0.0, 0.0, 0.02, 0.6 * k))
	b.arc(at + dir * length * 0.9, 11.0, 0.0, TAU, 18, Color(color(glimpse["maker"]), 0.35 * k), 1.2)


## Over the darkness: the fragment's words floating above it for a moment
## after it's read (redacted bars in its Maker's colour).
func _draw_over() -> void:
	if moment_t <= 0.0 or fragment.is_empty():
		return
	var total := float(FRAGMENT["moment"])
	var a := clampf((total - moment_t) / 0.4, 0.0, 1.0) * clampf(moment_t / 0.8, 0.0, 1.0)
	var m: String = fragment["maker"]
	var list: Array = MAKERS[m]["fragments"]
	var n: int = maxi(fragment_count(main.profile, m) - 1, 0)
	var text: String = list[n % list.size()]
	var col := color(m)
	var w := 150.0
	var at: Vector2 = fragment["wall"] + Vector2(-w * 0.5, -34.0 - (total - moment_t) * 3.0)
	redact_into(over, at, w, text, Color(col.lightened(0.3), 0.9 * a), 12.0)


# --- drawing: signs, redaction and the core mark ---------------------------------------

## A Maker's sign: an eye (marks), a trowel (towers) or a paw (creatures).
static func draw_sign(b, c: Vector2, s: float, sign: String, col: Color, width := 1.3) -> void:
	match sign:
		"eye":
			var top := PackedVector2Array()
			var low := PackedVector2Array()
			for i in 13:
				var a := PI * float(i) / 12.0
				top.append(c + Vector2(cos(a) * s * 1.5, -sin(a) * s * 0.8))
				low.append(c + Vector2(cos(a) * s * 1.5, sin(a) * s * 0.8))
			b.polyline(top, col, width)
			b.polyline(low, col, width)
			b.circle(c, s * 0.45, col)
		"trowel":
			# A pointed blade, its neck bending up into a handle.
			b.polygon(PackedVector2Array([c + Vector2(0, s * 1.3), c + Vector2(-s * 0.95, -s * 0.05), c + Vector2(0, -s * 0.35), c + Vector2(s * 0.95, -s * 0.05)]), col)
			b.line(c + Vector2(0, -s * 0.35), c + Vector2(0, -s * 0.85), col, width)
			b.line(c + Vector2(0, -s * 0.85), c + Vector2(s * 0.5, -s * 1.1), col, width)
			b.line(c + Vector2(s * 0.5, -s * 1.1), c + Vector2(s * 1.25, -s * 1.1), col, width * 1.6)
		"paw":
			b.polygon(_oval(c + Vector2(0, s * 0.45), Vector2(s * 0.62, s * 0.5), 12), col)
			for i in 4:
				var a := lerpf(-2.45, -0.69, float(i) / 3.0)
				b.polygon(_oval(c + Vector2(cos(a) * s * 1.05, s * 0.35 + sin(a) * s * 1.05), Vector2(s * 0.24, s * 0.3), 8), col)
		_:
			b.arc(c, s, 0.0, TAU, 16, col, width)


static func _oval(c: Vector2, r: Vector2, n := 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * float(i) / n
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	return pts


## True for a line not written yet: only redaction marks and spaces (or nothing).
static func is_redacted(text: String) -> bool:
	return text.replace(R, "").replace(" ", "").replace(".", "").replace(",", "").replace("?", "").replace("!", "").strip_edges() == ""


## The words' lengths in a redacted line (for drawing its bars).
static func word_lengths(text: String) -> Array:
	var out: Array = []
	for w in text.split(" ", false):
		var n := w.count(R)
		if n > 0:
			out.append(n)
	return out


## Draws a line of text at `at` (top-left), wrapping at `width`: a redacted
## line as blacked-out word bars, anything else as text in the fine italic
## of inscriptions (the Makers' words are written or spoken: ui.gd ROLES).
## `size` is the font size it stands for. Works on a CanvasItem or a Draw.Batch. Returns the
## height used.
static func redact_into(ci, at: Vector2, width: float, text: String, col: Color, size := 13.0, centered := false) -> float:
	var line_h := size * 1.45
	if not is_redacted(text):
		if ci is CanvasItem:
			var font := UI.font("inscription")
			var lines := _text_lines(font, text, width, size)
			ci.draw_multiline_string(font, at + Vector2(0, size), text, HORIZONTAL_ALIGNMENT_CENTER if centered else HORIZONTAL_ALIGNMENT_LEFT, width, int(size), lines, col)
			return line_h * lines
		return 0.0
	var unit := size * 0.52
	var gap := size * 0.45
	var bar_h := size * 0.72
	var rows: Array = [[]]
	var x := 0.0
	for n in word_lengths(text):
		var w := float(n) * unit
		if x > 0.0 and x + w > width:
			rows.append([])
			x = 0.0
		rows[-1].append(w)
		x += w + gap
	var y := at.y + (line_h - bar_h) * 0.5
	var k := 0
	for row in rows:
		var row_w := 0.0
		for w in row:
			row_w += w + gap
		row_w -= gap
		var rx := at.x + ((width - row_w) * 0.5 if centered else 0.0)
		for w in row:
			k += 1
			var jitter := 0.6 * sin(float(k) * 2.3)
			ci.draw_rect(Rect2(Vector2(rx, y + jitter), Vector2(w, bar_h)), col)
			rx += w + gap
		y += line_h
	return line_h * rows.size()


## How many lines written text wraps to at this width.
static func _text_lines(font: Font, text: String, width: float, size: float) -> int:
	var h := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, maxf(width, 1.0), int(size)).y
	return maxi(1, int(round(h / maxf(font.get_height(int(size)), 1.0))))


## How tall a line drawn by redact_into is at this width.
static func redact_height(width: float, text: String, size := 13.0) -> float:
	var line_h := size * 1.45
	if not is_redacted(text):
		return line_h * _text_lines(UI.font("inscription"), text, width, size)
	var unit := size * 0.52
	var gap := size * 0.45
	var rows := 1
	var x := 0.0
	for n in word_lengths(text):
		var w := float(n) * unit
		if x > 0.0 and x + w > width:
			rows += 1
			x = 0.0
		x += w + gap
	return line_h * rows


## The core mark on the climber in the world (player.gd, before its marks):
## a fine pattern over all six body parts at once, in its Maker's colour.
## `p` is the climber (its _mark_anchor places the parts). Cheap: a few lines.
static func draw_core_world(p, prof, side: Vector2, t: float) -> void:
	var c := core(prof)
	if c.is_empty():
		return
	var col := color(c.get("maker", ""))
	if p.dead:
		col = col.lerp(Color(0.5, 0.5, 0.5), 0.6)
	var depth := int(c.get("depth", 1))
	var pulse := 0.6 + 0.25 * sin(t * 1.4)
	var pts := {}
	for part in Bonds.PARTS:
		pts[part] = p._mark_anchor(part, side)
	var loop := ["brow", "throat", "hand", "legs", "heart", "back"]
	var b := Draw.Batch.new()
	var sign: String = MAKERS.get(c.get("maker", ""), {}).get("sign", "eye")
	var chain: Array = loop.map(func(k): return pts[k])
	chain.append(pts["brow"])
	# A dark thread under a lit one, so it reads on any cloak.
	_pattern_into(b, sign, chain, Vector2(0, 0.6), Color(0, 0, 0, 0.45), 1.6, 1)
	_pattern_into(b, sign, chain, Vector2.ZERO, Color(col.lightened(0.25), 0.62 * pulse + 0.08 * depth), 0.9, depth)
	for part in loop:
		b.dot(pts[part], 1.4, Color(col.lightened(0.4), 0.85 * pulse))
	b.flush(p)


## The core mark on the climber screen's figure (menu.gd BodyView, before the
## marks): over the whole body, shoulders to feet, in its Maker's colour.
static func core_figure_into(b, prof, spots: Dictionary, t: float) -> void:
	var c := core(prof)
	if c.is_empty():
		return
	var col := color(c.get("maker", ""))
	var depth := int(c.get("depth", 1))
	var pulse := 0.75 + 0.25 * sin(t * 1.3)
	var chain: Array = [Vector2(0, -140), spots["brow"], spots["throat"], Vector2(-28, -60), spots["hand"], Vector2(-48, 1),
		spots["heart"], Vector2(0, 0), spots["legs"], Vector2(-10, 118), Vector2(10, 118), Vector2(11, 62), Vector2(0, 0),
		spots["back"], Vector2(28, -60), Vector2(48, 1), Vector2(40, -24), spots["throat"]]
	UI.glow_into(b, Vector2(0, -20), 120.0, col, 0.25 * pulse)
	_pattern_into(b, MAKERS.get(c.get("maker", ""), {}).get("sign", "eye"), chain, Vector2.ZERO, Color(col, 0.5 * pulse + 0.08 * depth), 1.3, depth)
	for q in chain:
		b.dot(q, 2.0, Color(col, 0.75 * pulse))


## The pattern itself, by its Maker: fine straight threads joined at the
## parts (marks), stepped right-angled courses like masonry (towers), or
## curving veins (creatures). Each depth adds a finer second pass.
static func _pattern_into(b, sign: String, pts: Array, off: Vector2, col: Color, width: float, depth: int) -> void:
	for pass_i in mini(depth, 5):
		var a := col if pass_i == 0 else Color(col, col.a * 0.6)
		var shift := Vector2(1.5, -1.0) * pass_i * width
		for i in pts.size() - 1:
			var p0: Vector2 = pts[i] + off + shift
			var p1: Vector2 = pts[i + 1] + off + shift
			match sign:
				"trowel":
					var mid := Vector2(p1.x, p0.y)
					b.line(p0, mid, a, width)
					b.line(mid, p1, a, width)
				"paw":
					var n := (p1 - p0).orthogonal().normalized() * (p1 - p0).length() * 0.18 * (1.0 if i % 2 == 0 else -1.0)
					var curve := PackedVector2Array()
					for j in 7:
						var f := float(j) / 6.0
						curve.append(p0.lerp(p1, f) + n * sin(f * PI))
					b.polyline(curve, a, width)
				_:
					b.line(p0, p1, a, width)
					if pts.size() > 3 and i % 2 == 0:
						var q: Vector2 = pts[(i + 3) % pts.size()] + off + shift
						b.line(p0, q, Color(a, a.a * 0.45), width * 0.7)


# --- the Archive's pieces (menu.gd) --------------------------------------------------------

## A Maker's sign as a small control.
class SignIcon extends Control:
	var maker := ""
	var outer: GDScript

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		outer = load("res://scripts/makers.gd")

	func _draw() -> void:
		var col: Color = outer.color(maker)
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_circle(c, r, Color(col, 0.12))
		draw_arc(c, r - 1.0, 0.0, TAU, 28, Color(col, 0.6), 1.2, true)
		var b := UI.Draw.Batch.new()
		outer.draw_sign(b, c, r * 0.42, outer.MAKERS[maker]["sign"], col, 1.6)
		b.flush(self)


## A redacted (or written) line as a control: bars that wrap to its width.
class Redacted extends Control:
	var text := ""
	var color := Color(0.8, 0.8, 0.8)
	var font_size := 13.0
	var centered := false
	var outer: GDScript

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		outer = load("res://scripts/makers.gd")
		size_flags_horizontal = Control.SIZE_EXPAND_FILL

	func _ready() -> void:
		custom_minimum_size.y = font_size * 1.45
		resized.connect(_fit)

	func _fit() -> void:
		var h: float = outer.redact_height(maxf(size.x, 40.0), text, font_size)
		if absf(h - custom_minimum_size.y) > 0.5:
			custom_minimum_size.y = h
		queue_redraw()

	func _draw() -> void:
		outer.redact_into(self, Vector2.ZERO, size.x, text, color, font_size, centered)
