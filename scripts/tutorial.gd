extends RefCounted
## BASIC TRAINING, ONE SESSION: the first training a climber does, at the
## gym (stations.gd "gym"; the Noble's Grace needs it: training.gd). One
## sitting in the station's arena (arena.gd, event type "basics") that flows
## step to step without going back to the menu: each step says what to do
## (the Entity, as it begins, and the line at the top of the screen, both in
## the player's own keys, controller buttons or touch buttons: entity.gd
## KEYS), waits until the player does it, and the Entity nudges with a hint
## after a while (HINT_AFTER, then every HINT_AGAIN). Nothing can fell you
## in there (a soft foe's blow that would leaves you standing), and no step
## has a clock.
##
## The steps (STEPS, in order) cover the climber's whole basic moveset:
## walking (posts), jumping (one while moving), rolling (an archer's arrows
## pass through), then the weapons in the owner's order, MELEE -> UNARMED ->
## RANGED -> OFF-HAND: striking and the combo's finisher with the melee
## weapon, swapping to the fists for a blow or two, swapping to the ranged
## weapon (whatever it is: a bow's or sling's full draw, a crossbow's bolt or
## a pistol's shot that lands), the off-hand (a lent wand: tap it, with the
## melee weapon in hand, since bows, crossbows and two-handed weapons leave
## no hand free: offhand.gd two_handed), powering an item (hold the off-hand
## button); then parrying on the glint (a soft knight whose blows glint
## first), blocking (a lent shield, an off-hand piece too: hold parry), and
## the belt (the wheel, then an item used). Every past and loadout can do
## it: a climber with no melee weapon is lent the basic sword, one with no
## ranged weapon the basic bow, and from the off-hand step on a climber whose
## melee weapon needs both hands (a war hammer, a greatsword, a spear) is
## lent the basic sword in its place ("free_hand"). A step's words name the
## climber's own weapons ({melee_w}, {ranged_w}, {two_w}: the lent sword's
## place, {shots}: a pistol's) and can differ by them: "goal_gun",
## "say_crossbow", "hint_lent"... (the ranged step: "sling", "crossbow" or
## "gun", a bow the plain words; the off-hand steps: "lent").
## Each step's "kind" is what it watches for:
##   posts    touch `posts` posts in order (the lit one next)
##   jump     jump `need` times, `moving` of them while moving
##   roll     roll `need` times
##   strike   land `need` blows on the dummies with the melee weapon
##   finisher land `need` finishers (a combo's last, heavy blow) with it
##   fists    land `need` blows with the fists
##   ranged   land `need` shots with the ranged weapon: a bow or sling
##            only at full draw, a crossbow or pistol any shot
##   wand     cast the off-hand wand `need` times with a one-handed weapon
##            (or the fists) in hand
##   power    use a powered item `need` times (hold the off-hand button)
##   parry    parry `need` blows
##   block    block `need` blows with the shield
##   belt     open the belt wheel, and use `need` items from the belt
## and what it sets up: "dummies" ("near" or "far"), "foes" (soft: "weak"
## times their usual blow), "lend" (an off-hand piece lent for the session:
## nothing done in the arena is kept), "free_hand" (a two-handed melee
## weapon swapped for the lent sword), "carry" (essence carried, to power
## with), "hurt" (health set to this share, so a Healing Vial has work),
## "give" (items put on the belt) and "hold" (the weapon slot put in hand if
## it isn't: resuming at a melee step). "essence": the kind its essence is
## (STEP_ESSENCE of the usual amount a step done: training.gd RATES
## "basics", a quarter, into the body).
##
## Leaving part way (the pause menu) keeps the place: the gym's card offers
## Resume from that step, or Start over. Done, the six parts of the old
## basic training (stations.gd LESSONS) are all marked done (old saves that
## did them count as done), its renown is paid once, and the first
## tournament opens. Skippable from the card once the Noble's Grace is yours
## (or for a climber not held to it), or by an experienced player: one who
## has made a climber before on this device (new_start.gd made).
##
## Every word and number is here (and in the Data editor).

## The steps, in order (see above). Goals are short (the line at the top);
## "say" is the Entity's word as the step begins; "hint" its nudge when the
## step takes a while. {move}, {attack}... become the player's keys.
static var STEPS := [
	{"id": "walk", "name": "Walking", "kind": "posts", "posts": 3, "essence": "air",
		"goal": "Walk to the lit post with {move}",
		"say": "One session, every move. First: walk with {move} to each post, the lit one first. There's no sprint, just one steady pace: your stamina is for fighting.",
		"hint": "The lit post is next. When it's off the screen, an arrow at the edge points to it. Walk with {move}."},
	{"id": "jump", "name": "Jumping", "kind": "jump", "need": 2, "moving": 1, "essence": "air",
		"goal": "Jump with {jump}, once while moving",
		"say": "{jump} jumps: a short hop over spikes, snares, gaps and low blows along the floor. Jump while moving to leap forward. Once you're off the ground you can't turn, but you can still parry.",
		"hint": "Press {jump} once standing, then once while moving with {move}."},
	{"id": "roll", "name": "Rolling", "kind": "roll", "need": 2, "foes": ["archer"], "weak": 0.15, "essence": "air",
		"goal": "Roll with {roll}",
		"say": "{roll} rolls you a short way, and nothing touches you while you roll: let the archer's arrows pass through you. A roll costs stamina, the green bar, which comes back when you rest. Roll under a closing gate, too.",
		"hint": "Press {roll}. Move with {move} as you press it to roll that way."},
	{"id": "strike", "name": "Striking", "kind": "strike", "need": 2, "dummies": "near", "hold": "melee", "essence": "blade",
		"goal": "Strike a dummy with your {melee_w}: {attack}",
		"say": "First your melee weapon, your {melee_w}. {attack} strikes with the weapon in your hand, toward where you aim: {aim}. Walk up to a dummy and strike it. A blow from behind hits harder.",
		"hint": "Stand right next to a dummy, face it, and press {attack}. Your {melee_w} must be in your hand: swap to it with {weapon} if it isn't."},
	{"id": "finisher", "name": "Combos and the finisher", "kind": "finisher", "need": 1, "dummies": "near", "hold": "melee", "essence": "blade",
		"goal": "Keep pressing {attack}: land a finisher",
		"say": "Press {attack} again as each blow lands and they chain into a combo. Its last blow, the finisher, hits hardest, knocks foes back and breaks guards and cracked walls. Each blow costs stamina: mashing runs you dry.",
		"hint": "Stand by a dummy with your {melee_w} and press {attack} three times in a steady rhythm: the third blow is the finisher. Not too slow, or the chain starts again."},
	{"id": "fists", "name": "Fighting unarmed", "kind": "fists", "need": 2, "dummies": "near", "essence": "blade",
		"goal": "Swap to your fists with {weapon}, then strike",
		"say": "You carry three weapons: your fists, your {melee_w} and your {ranged_w}. {weapon} swaps between them. Swap to your fists and land two blows: quick, light, and never lost.",
		"hint": "Press {weapon} until your fists are up (the slot at the top left shows what's in your hand), then strike a dummy with {attack}."},
	{"id": "ranged", "name": "Your ranged weapon", "kind": "ranged", "need": 1, "dummies": "far", "essence": "blade",
		"goal": "Swap to your {ranged_w}: hold {attack}, let go at full draw",
		"say": "Now swap to your {ranged_w} with {weapon}. Hold {attack} to draw and let go to loose. Hold until the bow flashes: a full draw flies furthest and hits hardest. Land one on a far dummy.",
		"hint": "Swap with {weapon} until your {ranged_w} is out. Hold {attack} until a ring flashes at the bow, then let go while aiming at a far dummy.",
		"goal_sling": "Swap to your sling: hold {attack}, let go at a full whirl",
		"say_sling": "Now swap to your sling with {weapon}. Hold {attack} to whirl it and let go to throw. Hold until it flashes: a full whirl flies furthest and rocks what it hits. Land one on a far dummy.",
		"hint_sling": "Swap with {weapon} until your sling is out. Hold {attack} until a ring flashes, then let go while aiming at a far dummy.",
		"goal_crossbow": "Swap to your crossbow, then fire it with {attack}",
		"say_crossbow": "Now swap to your crossbow with {weapon}. No drawing: press {attack} and it fires a bolt at once, hard and fast. Then it reloads, and that can't be hurried, though you can walk meanwhile. Land a bolt on a far dummy.",
		"hint_crossbow": "Swap with {weapon} until your crossbow is out, aim at a far dummy and press {attack}. After a shot, wait for the reload.",
		"goal_gun": "Swap to your {ranged_w}, then fire it with {attack}",
		"say_gun": "Now swap to your {ranged_w} with {weapon}. No drawing: press {attack} and it fires at once. It holds {shots}; once it's empty it reloads by itself while you walk slowly, and a roll or a swap starts the reload over. Land a shot on a far dummy.",
		"hint_gun": "Swap with {weapon} until your {ranged_w} is out, aim at a far dummy and press {attack}. Empty, it reloads by itself: wait for it, and don't roll."},
	{"id": "offhand", "name": "The off-hand", "kind": "wand", "need": 1, "dummies": "near", "lend": "cinder_wand", "free_hand": true, "essence": "fire",
		"goal": "Swap to your {melee_w}, then tap {offhand}",
		"say": "Your off-hand holds a second blade, a shield or a wand. I've lent you a wand. Bows, crossbows and two-handed weapons need both hands, so they leave the off-hand put away. Swap to your {melee_w} with {weapon}, then tap {offhand} to cast the wand.",
		"hint": "Two-handed weapons and bows put the off-hand away. Swap with {weapon} until your {melee_w} is out, then tap {offhand}.",
		"say_lent": "Your off-hand holds a second blade, a shield or a wand. I've lent you a wand. Bows, crossbows and two-handed weapons need both hands, and so does your {two_w}: I've lent you a {melee_w} for the rest of this session. Swap to it with {weapon}, then tap {offhand} to cast the wand.",
		"hint_lent": "Your {two_w} needs both hands, so I lent you a {melee_w}. Swap with {weapon} until it's out, then tap {offhand}."},
	{"id": "power", "name": "Powering an item", "kind": "power", "need": 1, "dummies": "near", "lend": "cinder_wand", "carry": 12.0, "hold": "melee", "free_hand": true, "essence": "fire",
		"goal": "Hold {power} to power the wand",
		"say": "Items with essence carry a pool of their own. Hold {power} and the essence you carry powers the next use: the wand casts at once, harder. I've given you a little essence to try it.",
		"hint": "Keep {power} held for half a second, then let go. Your {melee_w} must be in your hand: a bow or a two-handed weapon leaves no hand for the wand."},
	{"id": "parry", "name": "Parrying on the glint", "kind": "parry", "need": 2, "foes": ["knight"], "weak": 0.2, "essence": "iron",
		"goal": "Press {parry} as the blow glints",
		"say": "Every blow glints a moment before it lands. Press {parry} on the glint: no damage, the attacker reels, and you get stamina back. A beat after the flash is a perfect parry. Then strike while it reels: a riposte hits far harder.",
		"hint": "Watch the knight: a white star flashes just before its blow. Press {parry} right then, not before."},
	{"id": "block", "name": "Blocking with a shield", "kind": "block", "need": 1, "foes": ["knight"], "weak": 0.2, "lend": "buckler", "hold": "melee", "free_hand": true, "essence": "iron",
		"goal": "Block a blow by {block}",
		"say": "I've swapped the wand for a shield: a shield is an off-hand piece too, so it needs a free hand. Keep {parry} held after the glint and you block: blows from in front hurt far less, each costing stamina. A parry is still the better answer.",
		"hint": "Face the knight and keep {parry} held down as its blow lands. Hold your {melee_w} or your fists: a bow or a two-handed weapon puts the shield away."},
	{"id": "belt", "name": "The belt and its wheel", "kind": "belt", "need": 1, "hurt": 0.6, "give": ["draught", "stamina"], "lend": "buckler", "essence": "water",
		"goal": "Hold {item} for the wheel, then use an item",
		"say": "Your belt holds vials and the like. Tap {item} to use the one shown. Hold {item} and the wheel opens, time slows: point at another and let go to choose it. Open the wheel, choose the Healing Vial, then drink it.",
		"hint": "Hold {item} until the wheel opens, point at the Healing Vial and let go. Then tap {item} to drink it."},
]
## Seconds on a step before the Entity's hint, and between hints after that.
static var HINT_AFTER := 12.0
static var HINT_AGAIN := 30.0
## The usual essence each step done gives (of its own kind; training.gd
## RATES "basics" settles a quarter of it, into the body). Twelve steps give
## what the six separate lessons did.
static var STEP_ESSENCE := 6.0
## The first-time tips the session covers: marked told once it's done, so
## the Entity doesn't repeat them in a climb.
static var TIPS := ["move", "glint", "offhand", "two_hands", "item_power", "belt", "belt_wheel"]

static var TEXT := {
	"name": "Basic training",
	"line": "One session: every way to move, attack and parry",
	"tile_new": "One session, %d steps",
	"tile_at": "Step %d of %d next: %s",
	"tile_done": "Done",
	"tile_skipped": "Skipped",
	"card_what": "One session in the arena, step by step: %s. Each step waits until you do it; I'll talk you through it.",
	"card_new": "Not started yet",
	"card_at": "You stopped before step %d of %d: %s",
	"card_done": "Done: every move learned. Go through it again any time.",
	"card_skipped": "Skipped. Go through it any time.",
	"card_note": "Nothing in there can fell you, and nothing is kept but what you learn. Leave from the pause menu and your place is kept.",
	"begin": "Begin basic training",
	"resume": "Resume from step %d",
	"restart": "Start over",
	"again": "Go through it again",
	"skip": "Skip it: I know this",
	"skipped": "Basic training skipped",
	"skip_warn": "Skip basic training? You won't be able to earn the Trainee title (it's only for finishing it). The lessons count as done, so the tournaments and the Grace open as usual.",
	"skip_confirm": "Skip it",
	"no_title": "No Trainee title: it's earned by finishing basic training, not skipping it.",
	"hud": "%s  ·  Step %d of %d  ·  %s",
	"count": "%d of %d",
	"step_done": "Step done",
	"leave": "Leave (your place is kept)",
	"pause_note": "Nothing you carry is at risk here. Leaving keeps your place: resume from the gym.",
	"result_done": "Basic training done",
	"result_left": "Basic training: stopped before step %d of %d (%s). Resume it at the gym.",
	"done_title": "Basic training done",
	"done_line": "Every move learned",
	"end_say": "That's every move: walk, jump, roll, strike, finish, fists, your ranged weapon, the off-hand, parry, block and the belt. The rest you'll learn by doing.",
	"shots_one": "one shot",
	"shots_many": "%d shots",
	"end_say_closed": "That's every move. Next, your first tournament at the tournament grounds: the Noble's Grace comes win or lose.",
}


# --- the record (kept in renown.gd's state, which saves with the climber) ---------------------

static func state(profile) -> Dictionary:
	var r: Dictionary = load("res://scripts/renown.gd").state(profile)
	if not (r.get("tutorial") is Dictionary):
		r["tutorial"] = {}
	var s: Dictionary = r["tutorial"]
	var defaults := {"step": 0, "done": false, "skipped": false}
	for k in defaults:
		if not s.has(k) or typeof(s[k]) != typeof(defaults[k]):
			s[k] = defaults[k]
	return s


static func count() -> int:
	return STEPS.size()


static func step_ids() -> Array:
	return STEPS.map(func(s): return String(s["id"]))


## Basic training is behind this climber: the session done (or skipped), or
## (old saves) the six separate lessons it replaced, every one done.
static func passed(profile) -> bool:
	if profile == null:
		return false
	var s := state(profile)
	if bool(s["done"]) or bool(s["skipped"]):
		return true
	var S = load("res://scripts/stations.gd")
	var Tr = load("res://scripts/training.gd")
	for id in S.LESSON_ORDER:
		var st: int = S.lesson_state(profile, id)
		if st == 0 or (st == 2 and Tr.closed(profile)):
			return false
	return true


## Where Resume starts (0: from the start).
static func resume_step(profile) -> int:
	return clampi(int(state(profile)["step"]), 0, count() - 1) if profile != null else 0


## Steps still to do (0 once it's behind the climber).
static func steps_left(profile) -> int:
	return 0 if passed(profile) else count() - resume_step(profile)


## Skipping is allowed once the Grace is yours (or for a climber not held to
## it), and for an experienced player: one who made a climber before on this
## device. A first-time player learns the moves.
static func can_skip(profile) -> bool:
	if profile == null:
		return false
	return load("res://scripts/training.gd").can_skip(profile) or experienced()


## An experienced player: a climber was made on this device before this one
## (new_start.gd counts them as they're made).
static func experienced() -> bool:
	return int(load("res://scripts/new_start.gd").made()) > 1


## Skips it (when allowed): marked as behind the climber, the six old parts
## skipped. Returns the lines to say.
static func skip(profile) -> Array:
	var Tr = load("res://scripts/training.gd")
	if not can_skip(profile):
		return [Tr.TEXT["no_skip"]]
	var S = load("res://scripts/stations.gd")
	state(profile)["skipped"] = true
	var lines: Array = [TEXT["skipped"], TEXT["no_title"]]
	for id in S.LESSON_ORDER:
		if S.lesson_state(profile, id) == 0:
			lines.append_array(S.finish_lesson(profile, id, 2))
	profile.save()
	return lines


## An arena result (stations.gd apply_result): done, every part marked done
## (and the renown, once); left part way, the place is kept. Lines.
static func apply(profile, res: Dictionary) -> Array:
	var s := state(profile)
	var lines: Array = []
	if bool(res.get("done", false)):
		s["done"] = true
		s["step"] = 0
		lines.append(TEXT["result_done"])
		var S = load("res://scripts/stations.gd")
		for id in S.LESSON_ORDER:
			lines.append_array(S.finish_lesson(profile, id, 1))
	else:
		var at := clampi(int(res.get("step", 0)), 0, count() - 1)
		s["step"] = at
		lines.append(String(TEXT["result_left"]) % [at + 1, count(), String(STEPS[at]["name"])])
	return lines


## The gym tile's line.
static func tile_line(profile) -> String:
	if profile == null:
		return String(TEXT["tile_new"]) % count()
	var s := state(profile)
	var at := resume_step(profile)
	if at > 0:
		return String(TEXT["tile_at"]) % [at + 1, count(), String(STEPS[at]["name"])]
	if bool(s["skipped"]) and not bool(s["done"]):
		return TEXT["tile_skipped"]
	if passed(profile):
		return TEXT["tile_done"]
	return String(TEXT["tile_new"]) % count()


# --- the session (one a sitting: arena.gd owns it) ----------------------------------------------

var arena
var main
var i := 0  # the step being done
var t := 0.0  # seconds on it
var next_hint := 0.0
var n := 0  # how many of it done
var moved := 0  # jumps made while moving
var seen := false  # (belt) the wheel opened
var _was := false  # an edge being watched (a jump, a roll, the wand's cooldown)
var _hits := 0  # the dummies' hits seen so far
var _base := 0  # a counter's value as the step began (parries, blocks, powered uses, items)
var _dummies := ""  # what's laid out now
var _foes: Array = []
var _lent := ""
var lent_weapons: Array = []  # the weapon slots lent a basic piece for the session ("melee", "ranged")
var two_w := ""  # the two-handed melee weapon the lent sword stands in for, from the off-hand step on
var _keep := {}  # what's put back afterward (tests run it outside a scene)


## Begins the session at step `from` (Resume), the arena already set up.
func begin(a, from := 0) -> void:
	arena = a
	main = a.main
	var p = main.player
	_keep = {"offhand": p.gear.get("offhand", {}).duplicate(true), "items": p.items.duplicate(), "essence": main.run_essence.duplicate(), "item_sel": p.item_sel,
		"melee": p.gear.get("melee", {}).duplicate(true), "ranged": p.gear.get("ranged", {}).duplicate(true), "weapon": String(p.weapon)}
	# Every past can do every step: an empty weapon slot is lent the basic piece.
	for slot in ["melee", "ranged"]:
		if p.gear_id(slot) == "":
			p.gear[slot] = load("res://scripts/basic_gift.gd").piece(slot)
			lent_weapons.append(slot)
	if not lent_weapons.is_empty():
		p.refresh_gear()
	_enter(clampi(from, 0, count() - 1))


## The step being done ({} once over).
func step() -> Dictionary:
	return STEPS[i] if i >= 0 and i < count() else {}


func _enter(k: int) -> void:
	i = k
	t = 0.0
	n = 0
	moved = 0
	seen = false
	next_hint = HINT_AFTER
	var d := step()
	var p = main.player
	_lay_dummies(String(d.get("dummies", "")))
	_set_foes(d.get("foes", []), float(d.get("weak", 1.0)))
	_lend(String(d.get("lend", "")))
	if bool(d.get("free_hand", false)):
		_free_hand(p)
	arena.posts.clear()
	arena.post = 0
	if String(d.get("kind", "")) == "posts":
		var room: Rect2 = main.OPEN_ROOM
		var c := room.get_center()
		var spots := [Vector2(room.position.x + 220, room.position.y + 140), Vector2(room.end.x - 220, room.position.y + 140), Vector2(c.x, room.position.y + 110)]
		arena.posts = spots.slice(0, clampi(int(d.get("posts", 3)), 1, spots.size()))
	for id in d.get("give", []):
		if p.has_method("add_item"):
			p.add_item(String(id))
	if float(d.get("hurt", 0.0)) > 0.0:
		p.hp = minf(p.hp, p.max_health() * float(d["hurt"]))
	if float(d.get("carry", 0.0)) > 0.0:
		_top_up(p)
	var hold := String(d.get("hold", ""))
	if hold != "" and String(_weapons().WEAPONS.get(String(p.weapon), {}).get("slot", "")) != hold:
		var g = p.gear.get(hold, {})
		if g is Dictionary and not g.is_empty():
			p.pending_weapon = load("res://scripts/gear.gd").base_id(g)  # (it comes to hand once free)
	_was = false
	_hits = _dummy_hits()
	match String(d.get("kind", "")):
		"parry":
			_base = arena.parries
		"block":
			_base = int(p.blocked)
		"power":
			_base = int(p.powered_uses)
		"belt":
			_base = arena._items_held(p)
		"wand":
			_was = float(p.off_cd) > 0.0
	arena.queue_redraw()
	main.GuideScript.say_text(words(d, "say"), true)  # (the Entity says how, as it begins)


## Each frame (arena.gd): watches for the step's action; done, the next.
func tick(delta: float, p) -> void:
	if i >= count():
		return
	t += delta
	var d := step()
	if float(d.get("carry", 0.0)) > 0.0:
		_top_up(p)
	_refill_foes(delta, d)
	if _check(d, p):
		_step_done(p)
		return
	if t >= next_hint:
		next_hint = t + HINT_AGAIN
		main.GuideScript.say_text(words(d, "hint"), true)


func _check(d: Dictionary, p) -> bool:
	var need := int(d.get("need", 1))
	match String(d.get("kind", "")):
		"posts":
			arena._touch_posts(p)
			n = arena.post
			return arena.post >= arena.posts.size()
		"jump":
			var up: bool = float(p.jump_t) > 0.0
			if up and not _was:
				n += 1
				if (p.jump_vel as Vector2).length() > 20.0:
					moved += 1
			_was = up
			return n >= need and moved >= int(d.get("moving", 0))
		"roll":
			var now: bool = float(p.roll_t) > 0.0
			if now and not _was:
				n += 1
			_was = now
			return n >= need
		"strike", "finisher", "fists", "ranged":
			var total := _dummy_hits()
			if total > _hits:
				var slot := _slot(p)
				match String(d["kind"]):
					"strike":
						if slot == "melee":
							n += total - _hits
					"finisher":
						if slot == "melee" and bool(p.swing.get("heavy", false)):
							n += 1
					"fists":
						if slot == "fists":
							n += total - _hits
					"ranged":
						# (a bow or sling at full draw; a crossbow's bolt or a pistol's shot, any that lands)
						if slot == "ranged" and (String(p.wkind()) != "bow" or bool(p.last_draw_full)):
							n += 1
				_hits = total
			return n >= need
		"wand":
			var cd: bool = float(p.off_cd) > 0.0
			if cd and not _was and String(load("res://scripts/offhand.gd").ready_use(p)) == "wand" and _slot(p) != "ranged":
				n += 1
			_was = cd
			return n >= need
		"power":
			n = int(p.powered_uses) - _base
			return n >= need
		"parry":
			n = arena.parries - _base
			return n >= need
		"block":
			n = int(p.blocked) - _base
			return n >= need
		"belt":
			if bool(p.ring_open):
				seen = true
			n = maxi(0, _base - arena._items_held(p))
			return seen and n >= need
	return false


func _step_done(p) -> void:
	var d := step()
	arena._gain(String(d.get("essence", "air")), STEP_ESSENCE)
	main.fx_ring(p.global_position, Color(1.0, 0.86, 0.45), 46.0, 0.4, 4.0)
	main.fx_text(p.global_position + Vector2(0, -44), TEXT["step_done"], Color(1.0, 0.86, 0.45))
	main.sfx("glint", 1.1, -4.0, 0.0)
	if i + 1 >= count():
		i = count()
		_clear_foes()
		arena.finish({"done": true})
		return
	_enter(i + 1)


## The line at the top: where you are and what to do, in your own keys.
func hud_text() -> String:
	var d := step()
	if d.is_empty():
		return String(TEXT["done_title"])
	var goal := words(d, "goal")
	var need := int(d.get("need", 0))
	match String(d.get("kind", "")):
		"posts":
			need = arena.posts.size()
	if need > 1:
		goal += "  ·  " + String(TEXT["count"]) % [mini(n, need), need]
	var line := String(TEXT["hud"]) % [String(TEXT["name"]), i + 1, count(), goal]
	return load("res://scripts/abilities.gd").fill(main, line)


## The step to resume from if the session is left now.
func reached() -> int:
	return clampi(i, 0, count() - 1)


# --- what each step sets up ---------------------------------------------------------------------

func _ranged(p) -> bool:
	return _slot(p) == "ranged"


## Where the weapon in hand is carried: "fists", "melee" or "ranged".
func _slot(p) -> String:
	return String(_weapons().WEAPONS.get(String(p.weapon), {}).get("slot", ""))


# --- the words: the climber's own weapons ----------------------------------------------------

## A step's words (field "goal", "say" or "hint") for this climber: the
## variant for their weapons if the step has one, the weapons named.
func words(d: Dictionary, field: String) -> String:
	var p = main.player if main != null else null
	var melee := String(p.gear_id("melee")) if p != null else ""
	var ranged := String(p.gear_id("ranged")) if p != null else ""
	return fill_words(pick_words(d, field, variant_for(d, ranged, two_w)), melee, ranged, two_w)


## Which words a step uses for these weapons: "sling", "crossbow" or "gun"
## on the ranged step (a bow: ""), "lent" on a free-hand step when a
## two-handed melee weapon was swapped for the lent sword.
static func variant_for(d: Dictionary, ranged: String, two := "") -> String:
	match String(d.get("kind", "")):
		"ranged":
			var w: Dictionary = _weapons().WEAPONS.get(ranged, {})
			if bool(w.get("stone", false)):
				return "sling"
			match String(w.get("kind", "")):
				"crossbow":
					return "crossbow"
				"gun":
					return "gun"
	if bool(d.get("free_hand", false)) and two != "":
		return "lent"
	return ""


## The field's words for a variant (the plain words when it has none).
static func pick_words(d: Dictionary, field: String, variant: String) -> String:
	if variant != "" and d.has(field + "_" + variant):
		return String(d[field + "_" + variant])
	return String(d.get(field, ""))


## Names the weapons in a step's words: {melee_w}, {ranged_w}, {two_w} and a
## pistol's {shots} (keys and pronouns are filled after, by the Entity).
static func fill_words(text: String, melee: String, ranged: String, two := "") -> String:
	var W = _weapons()
	var name_of := func(id: String, fallback: String) -> String:
		return String(W.WEAPONS.get(id, W.WEAPONS[fallback])["name"]).to_lower()
	text = text.replace("{melee_w}", name_of.call(melee, W.START_MELEE))
	text = text.replace("{ranged_w}", name_of.call(ranged, W.START_RANGED))
	text = text.replace("{two_w}", name_of.call(two, "greatsword"))
	var shots := int(W.WEAPONS.get(ranged, {}).get("shots", 1))
	text = text.replace("{shots}", String(TEXT["shots_one"]) if shots <= 1 else String(TEXT["shots_many"]) % shots)
	return text


static func _weapons():
	return load("res://scripts/weapons.gd")


func _dummy_hits() -> int:
	var total := 0
	for dm in arena.dummies:
		if is_instance_valid(dm):
			total += int(dm.hits_taken)
	return total


## The dummies: "near" (close by, for blades and the wand), "far" (up the
## room, out of a blade's reach, for the bow), "" none.
func _lay_dummies(kind: String) -> void:
	if kind == _dummies:
		return
	_dummies = kind
	for dm in arena.dummies:
		if is_instance_valid(dm):
			dm.queue_free()
	arena.dummies.clear()
	if kind == "":
		return
	var Dummy = load("res://scripts/dummy.gd")
	var room: Rect2 = main.OPEN_ROOM
	var c := room.get_center()
	var far := kind == "far"
	for k in 2:
		var dm = Dummy.new()
		dm.setup_dummy(main)
		dm.position = Vector2(c.x + (float(k) - 0.5) * (360.0 if far else 90.0), room.position.y + (90.0 if far else 230.0))
		main.add_child(dm)
		arena.dummies.append(dm)


func _set_foes(kinds: Array, weak: float) -> void:
	if kinds == _foes:
		return
	_clear_foes()
	_foes = kinds.duplicate()
	arena.ev["weak"] = weak  # (arena.gd _spawn: a soft foe)
	arena.ev["foes"] = _foes.duplicate()
	for k in _foes:
		arena._spawn(String(k), arena._spot(), true)


## The foes in the room (the dummies are "enemies" too, and stay).
func foes() -> Array:
	return main.enemies().filter(func(e): return String(e.kind) != "dummy")


func _clear_foes() -> void:
	for e in main.get_tree().get_nodes_in_group("enemies"):
		if String(e.get("kind")) == "dummy":
			continue
		e.queue_free()
		e.remove_from_group("enemies")
	main.foes_changed()
	_foes = []
	arena.ev["foes"] = []


## A foe felled comes back after a moment (they're for practice).
func _refill_foes(delta: float, _d: Dictionary) -> void:
	var have := foes().size()
	if _foes.is_empty() or have >= _foes.size():
		return
	arena.refill_t -= delta
	if arena.refill_t <= 0.0:
		arena.refill_t = arena.REFILL
		arena._spawn(String(_foes[have % _foes.size()]), arena._spot(), true)


## A free hand for the off-hand steps: a melee weapon that needs both hands
## (offhand.gd two_handed) gives way to the basic sword, lent for the rest of
## the session (put back afterward).
func _free_hand(p) -> void:
	var Offhand = load("res://scripts/offhand.gd")
	var id := String(p.gear_id("melee"))
	if id == "" or not Offhand.two_handed(id):
		return
	two_w = id
	p.gear["melee"] = load("res://scripts/basic_gift.gd").piece("melee")
	if not lent_weapons.has("melee"):
		lent_weapons.append("melee")
	if String(p.weapon) == id:
		p.pending_weapon = String(p.gear_id("melee"))  # (the hammer in hand gives way to the sword once free)
	p.refresh_gear()
	main.sfx("equip_sword", 1.0, -6.0, 0.0)


## An off-hand piece lent for the session ("" keeps what's lent).
func _lend(id: String) -> void:
	if id == "" or id == _lent:
		return
	_lent = id
	var p = main.player
	p.gear["offhand"] = load("res://scripts/gear.gd").make(id)
	p.refresh_gear()
	main.sfx("equip_sword", 1.2, -6.0, 0.0)


## The powering step: the wand's pool full and a little essence carried.
func _top_up(p) -> void:
	var g = p.gear.get("offhand", {})
	if g is Dictionary:
		g.erase("charge")  # (none noted is full: item_pool.gd)
	var ItemPool = load("res://scripts/item_pool.gd")
	var k: String = ItemPool.kind(g)
	if k == "":
		k = "fire"
	var want := float(step().get("carry", 0.0))
	if ItemPool.carried(main) < want:
		main.run_essence[k] = float(main.run_essence.get(k, 0.0)) + want - ItemPool.carried(main)


## Put back what the session lent (the real game starts the scene afresh;
## tests run it in place).
func restore() -> void:
	if main == null or main.player == null or _keep.is_empty():
		return
	var p = main.player
	p.gear["offhand"] = _keep["offhand"]
	for slot in ["melee", "ranged"]:
		var g: Dictionary = _keep.get(slot, {})
		if g.is_empty():
			p.gear.erase(slot)
		else:
			p.gear[slot] = g
	var was := String(_keep.get("weapon", "fists"))
	p.weapon = was if p.slots().has(was) else (p.gear_id("melee") if p.gear_id("melee") != "" else "fists")
	p.pending_weapon = ""
	p.drawing = false
	if String(p.wkind()) == "melee":
		p.swing = p.wdata()["combo"][0]
	p.items = _keep["items"]
	p.item_sel = String(_keep["item_sel"])
	main.run_essence = _keep["essence"]
	p.item_power = {}
	p.refresh_gear()
	_keep = {}


## The Trainee title is earned only by finishing basic training, not by
## skipping it (the owner's rule: an experienced player may skip, at the
## cost of the title). Old saves that finished the six lessons count.
static func earned_title(profile) -> bool:
	if profile == null:
		return false
	var s := state(profile)
	if bool(s["done"]):
		return true
	if bool(s["skipped"]):
		return false
	var S = load("res://scripts/stations.gd")
	return S.LESSON_ORDER.all(func(id): return not S.LESSONS.has(id) or S.lesson_state(profile, id) == 1)
