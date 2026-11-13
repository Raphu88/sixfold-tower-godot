extends Node2D
## The Entity in play: the guide for every new system, on the right side of
## the screen (the only thing there, under the menu buttons).
##
## ITS SPHERE lingers there while you play: small and quiet, bobbing, with a
## pulse when it has something new. On a phone it sits under the Bag,
## Climber and Menu buttons, slid clear of every touch button.
##
## TIPS. The first time the climber meets something (the glint, essence, a
## ward, a trap, a door...), code calls main.tip("id") and the Entity says
## its line in a bubble beside the sphere. One bubble at a time; the rest
## wait in a queue. A tip never stops the game: it fades after a few
## seconds, and a tap or click on it, Enter, or a press of the right stick
## (RS / R3) dismisses it at once.
##
## TIDBITS. When something relevant happens (a floor, a named room, a task,
## a creature's first notice, a reaction, a lock...), code calls
## main.remark("key") and the Entity says ONE short, true line about it
## (entity_notes.gd TIDBITS), gone by itself in a few seconds. Never twice
## in a climb, never crowding (remark below).
##
## THE PANEL. L, the right stick (when no tip wants it), or a click or tap
## on the sphere: it says a quip and its panel opens, with the last tip or
## tidbit in full and the log of this climb (notices.gd: the last twenty
## things that happened, newest first, never damage). The same again, Esc,
## or a tap on the panel closes it. The game goes on meanwhile.
##
## With no room beside the sphere (a phone with many cast buttons), a bubble
## is said in the top-middle lane instead, in the Entity's colours.
##
## Each tip is said once per climber (each climber slot hears them again);
## what it said is kept in the Archive (the climber screen's Archive tab). With the tips turned off in Settings, the
## Entity stays quiet but the Archive still fills in. "Replay tips" makes it
## say everything again. Short lines for moments (a fall, a beast slain, a
## new mark) use the same bubble. The words are in entity.gd.
##
## Tests: tips are off unless Engine has the "sixfold_tips" meta, so the
## other checks never see a bubble.

const Nav := preload("res://scripts/nav.gd")
const Entity := preload("res://scripts/entity.gd")
const UI := preload("res://scripts/ui.gd")
const Controls := preload("res://scripts/controls.gd")
const Slots := preload("res://scripts/slots.gd")
const Layout := preload("res://scripts/layout.gd")  # (the Entity's place: "hud.entity")
const Notes := preload("res://scripts/entity_notes.gd")  # (its tidbits, quips and the panel's words)

## Seconds between one bubble and the next, and to fade in or out.
const GAP := 0.6
const FADE := 0.25
## How long a bubble stays: this long at least, at most, and per letter.
const LIFE_MIN := 6.0
const LIFE_MAX := 12.0
const LIFE_PER_CHAR := 0.055
## The bubble's width (desktop, phone) and its top edge.
const WIDTH := 330.0
const WIDTH_TOUCH := 300.0
const TOP := 46.0
const TOP_TOUCH := 64.0

## What the Entity remembers, saved in the "guide" section: on (tips on, in
## the shared settings file), known (Archive entries unlocked) and told (tips
## said), both in the current climber's slot file (slots.gd).
static var state := {"on": true, "known": {}, "told": {}, "cast": {}}
static var loaded := false
## The climber file known and told were loaded from (and are saved to).
static var loaded_from := ""
## Bubbles waiting their turn: {kind: "tip" or "say", id, text}. Kept across
## a restart (a scene reload), so a tip queued just before isn't lost.
static var queue: Array = []

var main
var current := {}  # the bubble showing: {kind, id, name, text}
var shown_t := 0.0  # how long it has shown
var life := 0.0  # how long it stays
var leaving := 0.0  # fading out: seconds left
var gap_t := 0.0
var rect := Rect2()  # where the bubble is on screen (taps and clicks)
var t := 0.0
var eaten_touch := -1  # a touch that dismissed the bubble (its release is eaten too)
var shown := 0  # bubbles shown (tests)
var _drawn := false
var watch_t := 0.0
var _bubble: StyleBox  # (ui.gd entity_bubble, made once)
var _panel: StyleBox

## The sphere: its radius, and how long it pulses when it has something new.
const ORB_R := 15.0
const PULSE := 1.1
## A tidbit's bubble: its type size and its widest. The panel's width, how
## many rows of the last tip it shows, and its rows' heights.
const BIT_SIZE := 13
const BIT_W := 270.0
const PANEL_W := 300.0
const NOW_ROWS := 5
const ROW_H := {"quip": 16.0, "gap": 5.0, "head": 21.0, "text": 15.0, "log": 15.0}

var top: Node2D  # the sphere and its panel, drawn over the bubble
var open := false  # the panel is open (its log, the last tip in full)
var open_t := 0.0  # 0 shut .. 1 open (it unrolls)
var opened := 0  # times opened (tests)
var quip := ""  # what it said as it opened
var orb_rect := Rect2()  # the sphere's hit box on screen (taps and clicks)
var panel_rect := Rect2()  # the open panel on screen
var log_shown := 0  # log lines the open panel shows (tests)
var pulse := 0.0  # seconds of its pulse left
var said := {}  # tidbit lines said this climb
var key_at := {}  # tidbit key -> when it last spoke (msec)
var bit_at := -1000000  # when the last tidbit showed (msec)
var bits := 0  # tidbits shown (tests)
var last_note := {}  # {name, text}: the last tip or tidbit (the panel shows it in full)
var lane := false  # the bubble showing is said in the top lane (no room beside the sphere)
var _lane_b := {}
var _fresh_seen := 0
var _idle_t := 0.0
var _open_drawn := false


# --- the registry ------------------------------------------------------------------

static func load_state() -> void:
	if Engine.has_meta("sixfold_test"):
		loaded = true  # (tests keep it in memory only)
		return
	var at: String = Slots.current_path()
	if loaded and loaded_from == at:
		return
	loaded = true
	load_from(Slots.settings_path(), at)


## Reads tips on or off from the settings file, and what's been said from a
## climber's file (another climber starts with nothing said).
static func load_from(settings: String, climber: String) -> void:
	if loaded_from != climber:
		queue.clear()  # (another climber: nothing of the last one's waits)
	loaded_from = climber
	state["known"] = {}
	state["told"] = {}
	state["cast"] = {}
	var cfg := ConfigFile.new()
	if cfg.load(settings) == OK:
		state["on"] = bool(cfg.get_value("guide", "on", true))
	cfg = ConfigFile.new()
	if cfg.load(climber) == OK:
		var k = cfg.get_value("guide", "known", {})
		var t = cfg.get_value("guide", "told", {})
		state["known"] = k if k is Dictionary else {}
		state["told"] = t if t is Dictionary else {}
		var c = cfg.get_value("guide", "cast", {})
		state["cast"] = c if c is Dictionary else {}


## What's been said, into the current climber's file.
static func save_state() -> void:
	if Engine.has_meta("sixfold_test") or loaded_from == "":
		return
	save_to(loaded_from)


static func save_to(climber: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(climber)
	cfg.set_value("guide", "known", state["known"])
	cfg.set_value("guide", "told", state["told"])
	cfg.set_value("guide", "cast", state.get("cast", {}))
	cfg.save(climber)


## Tips on or off, into the shared settings file.
static func save_on(settings: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(settings)
	cfg.set_value("guide", "on", state["on"])
	cfg.save(settings)


## Another climber is about to be played (or this one was deleted): read
## everything again next time.
static func unload() -> void:
	loaded = false
	loaded_from = ""
	state["known"] = {}
	state["told"] = {}
	state["cast"] = {}
	queue.clear()


## False in tests (unless they ask for the Entity): it does nothing at all.
static func live() -> bool:
	return not Engine.has_meta("sixfold_test") or Engine.has_meta("sixfold_tips")


## Guide tips are on (the Settings toggle).
static func tips_on() -> bool:
	load_state()
	return bool(state["on"])


static func set_on(on: bool) -> void:
	load_state()
	state["on"] = on
	if not on:
		queue = queue.filter(func(q): return q["kind"] != "tip")
	if not Engine.has_meta("sixfold_test"):
		save_on(Slots.settings_path())


## The Archive entry for this tip is unlocked (an "always" entry, such as
## the creator tools', is readable before it's met).
static func known(id: String) -> bool:
	load_state()
	return state["known"].has(Entity.resolve(id)) or bool(Entity.entry(id).get("always", false))


## The Entity has said this tip.
static func told(id: String) -> bool:
	load_state()
	return state["told"].has(Entity.resolve(id))


## The first time the climber meets something: queue the Entity's tip for
## it (once per climber). Unknown ids fall back (entity.gd's resolve) or do
## nothing. With tips off, the Archive entry still unlocks. True if queued.
static func tip(id: String) -> bool:
	if not live():
		return false
	var r := Entity.resolve(id)
	if r == "":
		return false
	load_state()
	if not bool(state["on"]):
		if not state["known"].has(r):
			state["known"][r] = true
			save_state()
		return false
	if state["told"].has(r) or queue.any(func(q): return q.get("id", "") == r):
		return false
	queue.append({"kind": "tip", "id": r})
	return true


## The first time the climber meets something inside a menu (the train's
## pages, where no bubble can show): the tip's line, said there and then
## (marked said, kept in the Archive). "" if it was said before, with tips
## off (the Archive entry still unlocks), or in tests that keep it quiet.
static func tell(id: String) -> String:
	if not live():
		return ""
	var r := Entity.resolve(id)
	if r == "":
		return ""
	load_state()
	if not bool(state["on"]):
		if not state["known"].has(r):
			state["known"][r] = true
			save_state()
		return ""
	if state["told"].has(r):
		return ""
	queue = queue.filter(func(q): return q.get("id", "") != r)
	state["told"][r] = true
	state["known"][r] = true
	save_state()
	return String(Entity.entry(r)["tip"])


## The first time this climber casts a spell or technique (`key`:
## abilities.gd cast_key): true once, and it's remembered (ability_hints.gd
## shows its name and what it does). False in quiet tests or with tips off.
static func first_cast(key: String) -> bool:
	if not live() or not tips_on():
		return false
	if not state.has("cast"):
		state["cast"] = {}
	if state["cast"].has(key):
		return false
	state["cast"][key] = true
	save_state()
	return true


## A short line for a moment (entity.gd LINES), ahead of any tips waiting.
static func say(key: String, fill := {}) -> void:
	if not live() or not tips_on():
		return
	queue = queue.filter(func(q): return q["kind"] != "say")  # (only the latest moment)
	queue.push_front({"kind": "say", "id": "", "key": key, "text": Entity.line(key, -1, fill)})


## A moment: its tip the first time, a short line after that.
static func moment(tip_id: String, line_key: String, fill := {}) -> void:
	if told(tip_id) or not tips_on():
		say(line_key, fill)
	tip(tip_id)


## Replay tips: the Entity forgets what it has said (the Archive stays).
static func replay() -> void:
	load_state()
	state["told"] = {}
	state["cast"] = {}
	queue.clear()
	save_state()


## Tests: forget everything.
static func forget() -> void:
	state = {"on": true, "known": {}, "told": {}, "cast": {}}
	queue.clear()


# --- tidbits ---------------------------------------------------------------------------

## The Entity may have a word about this (entity_notes.gd TIDBITS, by key:
## "tower:kraken", "creature:ram", "task:levers", "doors"...): one short
## line beside its sphere, gone in a few seconds. A line is said once a
## climb, a key not again for a while, and never with tips off.
func remark(key: String) -> bool:
	if not live() or not tips_on() or main == null or main.player == null:
		return false
	var now := Time.get_ticks_msec()
	if now - int(key_at.get(key, -9999999)) < int(Notes.COOLDOWN * 1000.0):
		return false
	if queue.any(func(q): return q.get("key", "") == key):
		return false
	var lines: Array = Notes.lines(key).filter(func(l): return not said.has(l))
	if lines.is_empty():
		return false
	var text := String(lines[randi() % lines.size()])
	key_at[key] = now
	said[text] = true
	queue.append({"kind": "bit", "id": "", "key": key, "text": text, "at": now})
	return true


## Arriving at a floor: a line of the tower's own story if the owner has
## written any (entity_notes.gd LORE), else something true about the tower
## or one of its own systems.
func remark_arrival() -> void:
	if main == null:
		return
	var tower := String(main.tower)
	var lore: Array = Notes.LORE.get(tower, []).filter(func(l): return String(l) != "" and not said.has(l))
	if not lore.is_empty() and live() and tips_on():
		said[lore[0]] = true
		queue.append({"kind": "bit", "id": "", "key": "lore:" + tower, "text": String(lore[0]), "at": Time.get_ticks_msec()})
		return
	var keys: Array = Notes.arrival_keys(tower)
	keys.shuffle()
	for k in keys:
		if remark(String(k)):
			return


## A new climb: everything may be said again.
func new_climb() -> void:
	said.clear()
	key_at.clear()
	last_note = {}
	queue = queue.filter(func(q): return q["kind"] != "bit")


## The story line of this tower to show in the panel ("" while the owner
## hasn't written any: entity_notes.gd LORE).
func lore_line() -> String:
	var lore: Array = Notes.LORE.get(String(main.tower), []) if main != null else []
	lore = lore.filter(func(l): return String(l) != "")
	return "" if lore.is_empty() else String(lore[posmod(int(main.floor_num) - 1, lore.size())])


# --- the sphere, the bubble and the panel ----------------------------------------------

func _ready() -> void:
	load_state()
	z_index = 5
	# Runs while a menu pauses the game too, only to clear the bubble away.
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The sphere and its panel are drawn on their own node, so the bubble's
	# fade (this node's own) never dims them.
	top = Node2D.new()
	top.name = "EntityOrb"
	top.draw.connect(_draw_top)
	add_child(top)


## A bubble can show now: in play (or over a camp's cards or the Regard),
## not under a menu, the title or the tower choice, nor between floors, nor
## while a Maker is near (makers.gd quiet).
func can_show() -> bool:
	return main != null and main.player != null and not main.menu_open() and not main.title_showing() \
		and not main.choosing_tower and main.fade < 0.05 \
		and not (main.get("makers") != null and main.makers.quiet())  # (a Maker near: the Entity goes quiet)


## The sphere lingers while you play: not over the card screens, the Regard
## or the end of a climb (those are full-screen moments).
func orb_on() -> bool:
	return can_show() and not main.on_train and not main.overlay_showing() and not main.camp_choosing \
		and not (main.player.dead and not main.first_climb)


## Enter and the right stick dismiss only while no cards or overlay want them.
func _keys_free() -> bool:
	return not (main.camp_choosing or main.choosing_tower or main.overlay_showing())


func showing() -> bool:
	return not current.is_empty()


func _process(delta: float) -> void:
	if Engine.time_scale == 0.0:
		delta = Nav.real_delta(delta)  # (a ring stops the game's time: the Entity still speaks)
	if get_tree().paused:
		if _drawn:
			queue_redraw()  # (hidden under the menu; it comes back after)
			top.queue_redraw()
			_drawn = false
		open = false
		return
	t += delta
	watch_t -= delta
	if watch_t <= 0.0 and live():
		watch_t = 0.3
		_watch()
	pulse = maxf(0.0, pulse - delta)
	open_t = move_toward(open_t, 1.0 if open else 0.0, delta / 0.16)
	if main != null and main.get("notices") != null and main.notices.fresh != _fresh_seen:
		if main.notices.fresh > _fresh_seen:
			pulse = PULSE  # (something new in its log)
		_fresh_seen = main.notices.fresh
	# Its panel: L, the right stick (when no tip wants it), a click or tap on
	# the sphere. Esc (or Start) closes it instead of opening the menu.
	if open and (not orb_on() or main.player.dead):
		open = false
	if orb_on() and _keys_free():
		if open and Input.is_action_just_pressed("pause"):
			set_open(false)
			main.overlay_closed_frame = Engine.get_process_frames()  # (so this Esc doesn't open the menu too)
		elif Input.is_action_just_pressed("entity"):
			var tip_takes: bool = not current.is_empty() and current["kind"] != "bit" and leaving <= 0.0 and Input.is_action_just_pressed("dismiss_tip")
			if not tip_takes:
				set_open(not open)
	if not current.is_empty():
		if can_show():
			if not (lane and not _lane_showing()):
				shown_t += delta  # (said in the top lane: its time starts when its turn comes)
			if Input.is_action_just_pressed("dismiss_tip") and _keys_free() and current["kind"] != "bit":
				dismiss()
			if leaving > 0.0:
				leaving -= delta
				if leaving <= 0.0:
					_lane_end()
					current = {}
					lane = false
					gap_t = GAP
			elif shown_t >= life:
				leaving = FADE
	else:
		gap_t -= delta
		if gap_t <= 0.0 and not queue.is_empty() and can_show():
			_next()
	var on := can_show() and (not current.is_empty() or orb_on())
	# The bubble and an opening panel every frame; the idle sphere (a slow
	# bob) twenty times a second, so it costs next to nothing on a phone.
	var busy := not current.is_empty() or pulse > 0.0 or (open_t > 0.0 and open_t < 1.0) or open != _open_drawn
	_idle_t -= delta
	if (on and (busy or _idle_t <= 0.0)) or on != _drawn:
		_idle_t = 0.05
		_open_drawn = open
		queue_redraw()
		top.queue_redraw()
	_drawn = on


## Shows the next thing waiting: a tip or a moment first; a tidbit when
## the last one was a while ago (stale ones are dropped).
func _next() -> void:
	var now := Time.get_ticks_msec()
	for q in queue:
		if q["kind"] == "bit" and now - int(q.get("at", now)) > int(Notes.STALE * 1000.0):
			said.erase(q["text"])  # (never said: it may come up again)
			key_at.erase(q.get("key", ""))
	queue = queue.filter(func(q): return q["kind"] != "bit" or now - int(q.get("at", now)) <= int(Notes.STALE * 1000.0))
	for i in queue.size():
		var q: Dictionary = queue[i]
		if q["kind"] == "bit" and (now - bit_at < int(Notes.GAP * 1000.0) or not orb_on() or open):
			continue
		queue.remove_at(i)
		_show(q)
		return


## Things with no single moment in the code to hang a tip on, looked at a
## few times a second: a burned mark, poison, a chasm close by, low health.
func _watch() -> void:
	var p = main.player if main != null else null
	if p == null or p.dead:
		return
	for b in p.bonds.values():
		if b.burned:
			tip("overdraw")
	if p.poison_t > 0.0:
		tip("poison")
	for r in main.chasms:
		if r.grow(120.0).has_point(p.global_position):
			tip("jump")
			break
	if p.hp < p.max_hp * 0.3 and not main.first_climb:
		remark("low_health")


func _show(q: Dictionary) -> void:
	var text := ""
	var name := ""
	if q["kind"] == "tip":
		var e: Dictionary = Entity.entry(q["id"])
		if e.is_empty():
			return
		state["told"][q["id"]] = true
		state["known"][q["id"]] = true
		save_state()
		text = e["tip"]
		name = e["name"]
	else:
		text = q["text"]
	var mode := "touch" if main.touch_active else ("pad" if main.pad_active else "keys")
	current = {"kind": q["kind"], "id": q.get("id", ""), "name": name, "text": Entity.fill_keys(text, mode, main.pad_ps)}
	shown_t = 0.0
	leaving = 0.0
	lane = false
	_lane_b = {}
	if q["kind"] == "bit":
		# A tidbit: one short line, gone by itself.
		life = Notes.LIFE + text.length() * Notes.LIFE_PER_CHAR
		bit_at = Time.get_ticks_msec()
		bits += 1
		main.sfx("tip_chime", 1.25, -9.0, 0.03)
	else:
		life = clampf(3.0 + text.length() * LIFE_PER_CHAR, LIFE_MIN, LIFE_MAX)
		main.sfx("tip_chime", 1.0, 0.0, 0.03)
	last_note = {"name": name, "text": current["text"]}
	pulse = PULSE
	shown += 1


## Lets the bubble go now (a tap, a click, Enter or the right stick).
func dismiss() -> bool:
	if current.is_empty() or leaving > 0.0:
		return false
	leaving = minf(FADE, 0.15)
	main.sfx("ui_back", 1.2, -10.0, 0.0)
	return true


## Opens or closes the panel: a quip, what it last said in full, and the
## log of this climb (notices.gd). The game goes on under it.
func set_open(on: bool) -> void:
	if on == open:
		return
	open = on
	if on:
		quip = Entity.fill_words(String(Notes.QUIPS[randi() % Notes.QUIPS.size()]), {"floor": main.floor_num, "beast": main.beast_name()})
		opened += 1
		main.sfx("tip_chime", 1.1, -3.0, 0.03)
		if not current.is_empty() and current["kind"] == "bit":
			dismiss()  # (the panel says it in full)
	else:
		main.sfx("ui_back", 1.2, -10.0, 0.0)


var ate_at := -100000  # when a click or tap on the bubble was taken (msec)


## True just after a click on the bubble, so it doesn't also swing the weapon.
func ate_click() -> bool:
	return Time.get_ticks_msec() - ate_at < 150


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not event.pressed and event.index == eaten_touch:
		eaten_touch = -1
		get_viewport().set_input_as_handled()
		return
	if not can_show():
		return
	var at := Vector2(-1, -1)
	if event is InputEventScreenTouch and event.pressed:
		at = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		at = event.position
	if at.x < 0.0:
		return
	var took := false
	if orb_on() and (orb_rect.has_point(at) or (open and panel_rect.has_point(at))):
		# The sphere: its panel opens and closes (a tap on the open panel closes it).
		set_open(not open)
		took = true
	elif not current.is_empty() and leaving <= 0.0 and rect.grow(6.0).has_point(at):
		dismiss()
		took = true
	if took:
		if event is InputEventScreenTouch:
			eaten_touch = event.index
		ate_at = Time.get_ticks_msec()
		get_viewport().set_input_as_handled()


# --- where they sit ----------------------------------------------------------------------

## Half the sphere's hit box: big enough for a finger on a phone.
func _orb_reach() -> float:
	if main.touch_active:
		return maxf(ORB_R + 3.0, 22.0 / maxf(UI.device_px(get_viewport()), 0.01))
	return ORB_R + 4.0


func _buttons() -> Array:
	if not main.touch_active or main.touch == null:
		return []
	if main.touch.buttons.is_empty():
		main.touch._layout()
	return main.touch.buttons


## True if a circle is clear of every touch button.
func _clear(c: Vector2, rad: float) -> bool:
	for b in _buttons():
		if c.distance_to(b["c"]) < float(b["r"]) + rad:
			return false
	return true


func _rect_clear(r: Rect2) -> bool:
	for b in _buttons():
		var c: Vector2 = b["c"]
		var near := Vector2(clampf(c.x, r.position.x, r.end.x), clampf(c.y, r.position.y, r.end.y))
		if near.distance_to(c) < float(b["r"]) + 4.0:
			return false
	return true


## Where the sphere sits: the right side, under the key hints (or the
## controls list); on a phone under the Bag, Climber and Menu buttons, slid
## left until it's clear of every button. Arranged ("hud.entity"), at the
## right end of its box.
func orb_spot() -> Vector2:
	var size := get_viewport_rect().size
	if Layout.moved("hud.entity"):
		var d := Layout.default_box("hud.entity", size)
		return Vector2(d.end.x - ORB_R, d.position.y + ORB_R + 2.0)
	if not main.touch_active:
		var y := TOP
		if main.hud != null and main.hud.show_help:
			y = 14.0 + 20.0 + Controls.HELP.size() * 17.0 + 10.0
		return Vector2(size.x - 16.0 - ORB_R, y + ORB_R + 2.0)
	var foot := 0.0
	for b in _buttons():
		if b["id"] in main.touch.TOP_BAR:
			foot = maxf(foot, float(b["c"].y) + float(b["r"]))
	var reach := _orb_reach() + 2.0
	var y0 := maxf(foot + 4.0 + reach, reach + 4.0)
	for row in 3:
		var y := y0 + row * 12.0
		var x := size.x - 8.0 - reach
		while x > size.x * 0.56:
			if _clear(Vector2(x, y), reach):
				return Vector2(x, y)
			x -= 6.0
	return Vector2(size.x - 8.0 - reach, y0)


## The left edge the Entity keeps to: right of the top-middle lane.
func _lane_edge() -> float:
	var size := get_viewport_rect().size
	var col: Rect2 = main.notices.rects.get("column", Rect2()) if main.get("notices") != null else Rect2()
	if col.size.x > 0.0 and not main.notices.left_mode:
		return col.end.x + 10.0
	return size.x * 0.5 + minf(230.0, size.x * 0.19) + 10.0


## Where a bubble `w` wide (at most) and `h` tall goes beside the sphere:
## to its left, or (a tip, on a computer) under it. An empty rect if there's
## no room clear of the lane and the buttons: then it's said in the lane.
func side_rect(w_most: float, w_least: float, text_h: Callable, under := false) -> Rect2:
	var size := get_viewport_rect().size
	var orb := orb_spot()
	var edge := _lane_edge() if not Layout.moved("hud.entity") else 8.0
	var right := orb.x - ORB_R - 8.0
	var w := minf(w_most, right - edge)
	# (narrower, and so taller, until it's clear of the buttons)
	while w >= w_least:
		var r := Rect2(right - w, orb.y - ORB_R - 2.0, w, float(text_h.call(w)))
		r.position.y = maxf(r.position.y, 4.0)
		if r.end.y <= size.y - 4.0 and _rect_clear(r):
			return r
		if not main.touch_active:
			break
		w -= 14.0
	if under and not main.touch_active:
		w = minf(w_most, size.x - 16.0 - edge)
		if w >= w_least:
			return Rect2(size.x - 16.0 - w, orb.y + ORB_R + 8.0, w, float(text_h.call(w)))
	return Rect2()


## A tidbit's type size (a touch smaller on a phone, where the room beside
## the sphere is a small pocket between the buttons).
func bit_size() -> int:
	return BIT_SIZE - 1 if main.touch_active else BIT_SIZE


## The bubble's rect for what's showing (an empty rect: said in the lane).
func bubble_rect() -> Rect2:
	if current.is_empty():
		return Rect2()
	var font := ThemeDB.fallback_font
	var text: String = current["text"]
	if current["kind"] == "bit":
		var fs := bit_size()
		var widest := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 22.0
		return side_rect(minf(BIT_W, widest), 100.0 if main.touch_active else 118.0,
			func(w): return font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, w - 20.0, fs).y + 12.0)
	var titled: bool = current["name"] != ""
	return side_rect(WIDTH_TOUCH if main.touch_active else WIDTH, 200.0,
		func(w): return maxf(52.0, 26.0 + font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, w - 24.0, 15).y + (24.0 if titled else 3.0) + 16.0), true)


## The panel's box: under the sphere on a computer; on a phone the right
## side, top to bottom (over the buttons while it's open).
func panel_box() -> Rect2:
	var size := get_viewport_rect().size
	if main.touch_active:
		var w := minf(PANEL_W, size.x * 0.36)
		return Rect2(size.x - w - 6.0, 4.0, w, size.y - 8.0)
	var orb := orb_spot()
	var w2 := minf(PANEL_W, size.x * 0.3 - 12.0)
	var top_y := orb.y + ORB_R + 8.0
	return Rect2(size.x - 16.0 - w2, top_y, w2, maxf(120.0, size.y - top_y - 12.0))


# --- said in the lane (a phone with no room beside the sphere) -----------------------------

func _lane_showing() -> bool:
	return main.get("notices") != null and not _lane_b.is_empty() and main.notices.current == _lane_b


func _lane_say() -> void:
	lane = true
	var tip_like: bool = current["kind"] != "bit"
	_lane_b = {"who": "entity", "title": String(current["name"]) if current["name"] != "" else String(Entity.TEXT["tag"]),
		"lines": [String(current["text"])], "t": life, "hold": true, "note": true, "pri": 1 if tip_like else 0}
	main.banner = _lane_b


func _lane_end() -> void:
	if not lane or main.get("notices") == null:
		return
	var N = main.notices
	if N.current == _lane_b:
		_lane_b["t"] = minf(float(_lane_b.get("t", 0.0)), 0.3)
	else:
		N.queue.erase(_lane_b)
	_lane_b = {}


# --- drawing ---------------------------------------------------------------------------

func _draw() -> void:
	rect = Rect2()
	if current.is_empty() or not can_show():
		return
	if open and current["kind"] == "bit":
		return  # (the open panel says it)
	var size := get_viewport_rect().size
	var xf := Layout.xform("hud.entity", size)
	if not lane:
		var r := bubble_rect()
		if r.size.x <= 0.0:
			_lane_say()
		else:
			_draw_bubble(r, xf)
			return
	# Said in the top lane: a tap on it there dismisses it too.
	if _lane_showing():
		rect = main.notices.rects.get("banner", Rect2())
		_lane_b["t"] = maxf(life - shown_t, 0.05) if leaving <= 0.0 else minf(float(_lane_b["t"]), leaving)


func _draw_bubble(r: Rect2, xf: Transform2D) -> void:
	var font := ThemeDB.fallback_font
	var text: String = current["text"]
	var bit: bool = current["kind"] == "bit"
	var titled: bool = current["name"] != ""
	# In: slide from the right and fade up. Out: fade.
	var appear := clampf(shown_t / FADE, 0.0, 1.0)
	appear = 1.0 - (1.0 - appear) * (1.0 - appear)
	var a := appear * (clampf(leaving / FADE, 0.0, 1.0) if leaving > 0.0 else 1.0)
	rect = xf * r
	r.position.x += (1.0 - appear) * 14.0
	draw_set_transform_matrix(xf)
	self_modulate.a = a
	if _bubble == null:
		_bubble = UI.entity_bubble()
		# In play it's framed like the HUD: a periwinkle hairline inside its edge.
		_bubble.inner = Color(UI.PERIWINKLE, 0.18)
	draw_style_box(_bubble, r)
	var x := r.position.x + 13.0
	var tw := r.size.x - 24.0
	if bit:
		draw_multiline_string(font, Vector2(x, r.position.y + 6.0 + bit_size()), text, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 20.0, bit_size(), -1, Entity.GLOW.lerp(Color.WHITE, 0.62))
		return
	# Its name tag (a small gothic label), the subject in the display face,
	# then the line.
	UI.draw_eyebrow(self, Vector2(x, r.position.y + 18.0), Entity.TEXT["tag"], Color(UI.PERIWINKLE, 0.9), 14)
	var ty := r.position.y + 37.0
	if titled:
		UI.draw_title(self, Vector2(x, r.position.y + 39.0), String(current["name"]), 20, Color(0.9, 0.86, 1.0), HORIZONTAL_ALIGNMENT_LEFT, tw, 0.0)
		ty += 21.0
	draw_multiline_string(font, Vector2(x, ty), text, HORIZONTAL_ALIGNMENT_LEFT, tw, 15, -1, Entity.GLOW.lerp(Color.WHITE, 0.62))
	# How to dismiss it, and that it's kept.
	var how := "tap" if main.touch_active else (("R3" if main.pad_ps else "RS") if main.pad_active else "Enter")
	var hint: String = how + ("  ·  " + Entity.TEXT["kept"] if current["kind"] == "tip" else "")
	draw_string(UI.font("mono"), Vector2(r.position.x, r.end.y - 8.0), hint, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 12.0, 11, UI.FAINT)
	# Time left, a thin line along the bottom.
	var k := clampf(1.0 - shown_t / maxf(life, 0.01), 0.0, 1.0)
	draw_line(Vector2(r.position.x + 10.0, r.end.y - 2.5), Vector2(r.position.x + 10.0 + (r.size.x - 20.0) * k, r.end.y - 2.5), Color(Entity.GLOW, 0.35), 1.5)


## The key (or button) that opens the panel, for its prompt ("" on a phone).
func open_key() -> String:
	if main.touch_active:
		return ""
	return ("R3" if main.pad_ps else "RS") if main.pad_active else String(Notes.TEXT["open_key"])


## The sphere, and its panel when open.
func _draw_top() -> void:
	orb_rect = Rect2()
	panel_rect = Rect2()
	if not orb_on():
		return
	var size := get_viewport_rect().size
	var xf := Layout.xform("hud.entity", size)
	top.draw_set_transform_matrix(xf)
	var c := orb_spot()
	var reach := _orb_reach()
	if open_t > 0.01:
		_draw_panel(xf)
		if main.touch_active:
			# On a phone the open panel covers the sphere's place: it sits in
			# the panel's corner instead.
			c = panel_box().position + Vector2(8.0 + ORB_R, 8.0 + ORB_R)
	orb_rect = xf * Rect2(c - Vector2(reach, reach), Vector2(reach, reach) * 2.0)
	# Quiet while idle; a ring spreads from it once when it has something new.
	var k := pulse / PULSE
	var busy := not current.is_empty() or open
	if k > 0.0:
		var grow := 1.0 - k
		top.draw_arc(c, ORB_R * (1.0 + 0.9 * grow), 0.0, TAU, 28, Color(Entity.GLOW, 0.7 * k), 2.0, true)
	top.draw_circle(c, ORB_R * 1.05, Color(0.05, 0.04, 0.09, 0.35))
	Entity.draw_face(top, c, ORB_R, t, 1.0 if busy or k > 0.0 else 0.82)
	# Its key, small, under it (a computer or a controller).
	var key := open_key()
	if key != "" and open_t < 0.5:
		UI.draw_key(top, c + Vector2(-ORB_R - 2.0, ORB_R - 3.0), key, 8, Color(UI.DIM, 0.9))
	top.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_panel(xf: Transform2D) -> void:
	var N = main.notices
	var font := ThemeDB.fallback_font
	var mono := UI.font("mono")
	var box := panel_box()
	var a := open_t
	var touch: bool = main.touch_active
	var pad := 10.0
	var tw := box.size.x - pad * 2.0
	# What it says: the quip, then the last tip or tidbit in full.
	var rows: Array = []  # [kind, text, colour]: "quip", "head", "text", "log", "gap"
	for l in N.wrap_text(font, quip, 13, tw - (ORB_R * 2.0 + 10.0 if touch else 0.0)):
		rows.append(["quip", l, Entity.GLOW.lerp(Color.WHITE, 0.5)])
	rows.append(["gap", "", Color.WHITE])
	rows.append(["head", String(Notes.TEXT["now"]), UI.PERIWINKLE])
	var now_text: String = String(last_note.get("text", "")) if not last_note.is_empty() else String(Notes.TEXT["idle"])
	if String(last_note.get("name", "")) != "":
		now_text = "%s: %s" % [last_note["name"], now_text]
	var now_rows: Array = N.wrap_text(font, now_text, 12, tw)
	if now_rows.size() > NOW_ROWS:
		now_rows = now_rows.slice(0, NOW_ROWS)
		now_rows[-1] = N.clip(font, String(now_rows[-1]) + " ...", 12, tw)
	for l in now_rows:
		rows.append(["text", l, UI.TEXT])
	var lore := lore_line()
	if lore != "":
		rows.append(["head", String(Notes.TEXT["lore"]), UI.PERIWINKLE])
		for l in N.wrap_text(font, lore, 12, tw).slice(0, 3):
			rows.append(["text", l, UI.TEXT])
	rows.append(["head", String(Notes.TEXT["log"]), UI.PERIWINKLE])
	var used := pad
	for r in rows:
		used += ROW_H[r[0]]
	var room := int(floor((box.size.y - used - pad - 14.0) / ROW_H["log"]))
	var list: Array = N.recent(clampi(room, 0, N.LOG_SHOWN))
	log_shown = list.size()
	var h: float = used + maxf(1.0, list.size()) * float(ROW_H["log"]) + pad + 14.0
	if not touch:
		box.size.y = minf(box.size.y, h)
	panel_rect = xf * box
	# Opening: it unrolls from the sphere.
	var shown_box := Rect2(box.position, Vector2(box.size.x, box.size.y * (0.4 + 0.6 * a)))
	if _panel == null:
		_panel = UI.entity_bubble()
		_panel.inner = Color(UI.PERIWINKLE, 0.18)
	top.draw_style_box(_panel, shown_box)
	if a < 0.85:
		return
	var x := box.position.x + pad + 3.0
	var y := box.position.y + pad
	for r in rows:
		var kind: String = r[0]
		y += ROW_H[kind]
		match kind:
			"quip":
				top.draw_string(font, Vector2(x + (ORB_R * 2.0 + 10.0 if touch else 0.0), y - 4.0), r[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, r[2])
			"head":
				UI.draw_eyebrow(top, Vector2(x, y - 3.0), r[1], Color(r[2], 0.9), 12)
				top.draw_line(Vector2(x, y), Vector2(box.end.x - pad, y), Color(UI.PERIWINKLE, 0.22), 1.0)
			"text":
				top.draw_string(font, Vector2(x, y - 3.0), r[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, r[2])
	# The log: newest first, each with its sign and its floor.
	var batch := UI.Draw.Batch.new()
	var words: Array = []
	if list.is_empty():
		words.append([Vector2(x, y + ROW_H["log"] - 3.0), String(Notes.TEXT["log_empty"]), UI.DIM, 12, font])
	for e in list:
		y += ROW_H["log"]
		N.sign_into(batch, String(N.KINDS.get(e["kind"], N.KINDS["news"])["sign"]), Vector2(x + 4.0, y - 6.5), 3.0, e["color"])
		var tag := String(Notes.TEXT["floor"]) % int(e["floor"])
		var tag_w := mono.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
		words.append([Vector2(x + 13.0, y - 3.0), N.clip(font, N.log_text(e), 12, tw - 13.0 - tag_w - 8.0), Color(e["color"]).lerp(UI.TEXT, 0.45), 12, font])
		words.append([Vector2(box.end.x - pad - tag_w, y - 3.5), tag, UI.FAINT, 10, mono])
	batch.flush(top)
	for wd in words:
		top.draw_string(wd[4], wd[0], wd[1], HORIZONTAL_ALIGNMENT_LEFT, -1, wd[3], wd[2])
	var key := open_key()
	var how: String = String(Notes.TEXT["close_tap"]) if key == "" else String(Notes.TEXT["close"]) % key
	top.draw_string(mono, Vector2(box.position.x, box.end.y - 7.0), how, HORIZONTAL_ALIGNMENT_RIGHT, box.size.x - pad, 10, UI.FAINT)
