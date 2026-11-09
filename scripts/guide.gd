extends Node2D
## The Entity in play: the guide for every new system. The first time the
## climber meets something (the glint, essence, a ward, a trap, a door...),
## code calls main.tip("id") and the Entity says its line in a bubble in a
## corner (top right, under the menu buttons on a phone, clear of the
## joystick and the action buttons). One bubble at a time; the rest wait in
## a queue. A tip never stops the game: it fades after a few seconds, and a
## tap or click on it, Enter, or a press of the right stick (RS / R3)
## dismisses it at once.
##
## Each tip is said once per climber (each climber slot hears them again);
## what it said is kept in the Archive (the climber screen's Archive tab). With the tips turned off in Settings, the
## Entity stays quiet but the Archive still fills in. "Replay tips" makes it
## say everything again. Short lines for moments (a fall, a beast slain, a
## new mark) use the same bubble. The words are in entity.gd.
##
## Tests: tips are off unless Engine has the "sixfold_tips" meta, so the
## other checks never see a bubble.

const Entity := preload("res://scripts/entity.gd")
const UI := preload("res://scripts/ui.gd")
const Controls := preload("res://scripts/controls.gd")
const Slots := preload("res://scripts/slots.gd")

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
static var state := {"on": true, "known": {}, "told": {}}
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
	var cfg := ConfigFile.new()
	if cfg.load(settings) == OK:
		state["on"] = bool(cfg.get_value("guide", "on", true))
	cfg = ConfigFile.new()
	if cfg.load(climber) == OK:
		var k = cfg.get_value("guide", "known", {})
		var t = cfg.get_value("guide", "told", {})
		state["known"] = k if k is Dictionary else {}
		state["told"] = t if t is Dictionary else {}


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


## The Archive entry for this tip is unlocked.
static func known(id: String) -> bool:
	load_state()
	return state["known"].has(Entity.resolve(id))


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
	queue.clear()
	save_state()


## Tests: forget everything.
static func forget() -> void:
	state = {"on": true, "known": {}, "told": {}}
	queue.clear()


# --- the bubble -----------------------------------------------------------------------

func _ready() -> void:
	load_state()
	z_index = 5
	# Runs while a menu pauses the game too, only to clear the bubble away.
	process_mode = Node.PROCESS_MODE_ALWAYS


## A bubble can show now: in play (or over a camp's cards or the Regard),
## not under a menu, the title or the tower choice, nor between floors, nor
## while a Maker is near (makers.gd quiet).
func can_show() -> bool:
	return main != null and main.player != null and not main.menu_open() and not main.title_showing() \
		and not main.choosing_tower and main.fade < 0.05 \
		and not (main.get("makers") != null and main.makers.quiet())  # (a Maker near: the Entity goes quiet)


## Enter and the right stick dismiss only while no cards or overlay want them.
func _keys_free() -> bool:
	return not (main.camp_choosing or main.choosing_tower or main.overlay_showing())


func showing() -> bool:
	return not current.is_empty()


func _process(delta: float) -> void:
	if get_tree().paused:
		if _drawn:
			queue_redraw()  # (hidden under the menu; it comes back after)
			_drawn = false
		return
	t += delta
	watch_t -= delta
	if watch_t <= 0.0 and live():
		watch_t = 0.3
		_watch()
	if not current.is_empty():
		if can_show():
			shown_t += delta
			if Input.is_action_just_pressed("dismiss_tip") and _keys_free():
				dismiss()
			if leaving > 0.0:
				leaving -= delta
				if leaving <= 0.0:
					current = {}
					gap_t = GAP
			elif shown_t >= life:
				leaving = FADE
	else:
		gap_t -= delta
		if gap_t <= 0.0 and not queue.is_empty() and can_show():
			_show(queue.pop_front())
	var on := not current.is_empty() and can_show()
	if on or _drawn:
		queue_redraw()
	_drawn = on


## Things with no single moment in the code to hang a tip on, looked at a
## few times a second: a burned mark, poison, a chasm close by.
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
	life = clampf(3.0 + text.length() * LIFE_PER_CHAR, LIFE_MIN, LIFE_MAX)
	shown += 1
	main.sfx("ready", 1.6, -16.0, 0.0)


## Lets the bubble go now (a tap, a click, Enter or the right stick).
func dismiss() -> bool:
	if current.is_empty() or leaving > 0.0:
		return false
	leaving = minf(FADE, 0.15)
	main.sfx("ui_back", 1.2, -10.0, 0.0)
	return true


var ate_at := -100000  # when a click or tap on the bubble was taken (msec)


## True just after a click on the bubble, so it doesn't also swing the weapon.
func ate_click() -> bool:
	return Time.get_ticks_msec() - ate_at < 150


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and not event.pressed and event.index == eaten_touch:
		eaten_touch = -1
		get_viewport().set_input_as_handled()
		return
	if current.is_empty() or leaving > 0.0 or not can_show():
		return
	var at := Vector2(-1, -1)
	if event is InputEventScreenTouch and event.pressed:
		at = event.position
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		at = event.position
	if at.x >= 0.0 and rect.grow(6.0).has_point(at):
		if event is InputEventScreenTouch:
			eaten_touch = event.index
		ate_at = Time.get_ticks_msec()
		dismiss()
		get_viewport().set_input_as_handled()


## Where the bubble goes: top right, under the hint bar (or the controls
## list); on a phone under the menu buttons, above the action buttons.
func bubble_rect(text_h: float) -> Rect2:
	var size := get_viewport_rect().size
	var touch: bool = main.touch_active
	var w := minf(WIDTH_TOUCH if touch else WIDTH, size.x - 24.0)
	var top := TOP_TOUCH if touch else TOP
	if not touch and main.hud != null and main.hud.show_help:
		top = 14.0 + 20.0 + Controls.HELP.size() * 17.0 + 10.0
	var h := maxf(66.0, 30.0 + text_h + 16.0)
	var r := Rect2(Vector2(size.x - w - (12.0 if touch else 16.0), top), Vector2(w, h))
	if touch and main.touch != null:
		# A short screen with many marks: slide left, clear of the cast buttons.
		main.touch._layout()
		for b in main.touch.buttons:
			if b["id"] in main.touch.TOP_BAR:
				continue
			var br := Rect2(b["c"] - Vector2(b["r"], b["r"]), Vector2(b["r"], b["r"]) * 2.0).grow(6.0)
			if br.intersects(r):
				r.position.x = minf(r.position.x, br.position.x - r.size.x)
		r.position.x = maxf(r.position.x, size.x * 0.3)
	return r


func _draw() -> void:
	if current.is_empty() or not can_show():
		return
	var font := ThemeDB.fallback_font
	var text: String = current["text"]
	var probe := bubble_rect(0.0)
	var tw := probe.size.x - 64.0
	var text_h := font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, tw, 15).y
	var titled: bool = current["name"] != ""
	var r := bubble_rect(text_h + (20.0 if titled else 0.0))
	# In: slide from the right and fade up. Out: fade.
	var appear := clampf(shown_t / FADE, 0.0, 1.0)
	appear = 1.0 - (1.0 - appear) * (1.0 - appear)
	var a := appear * (clampf(leaving / FADE, 0.0, 1.0) if leaving > 0.0 else 1.0)
	r.position.x += (1.0 - appear) * 26.0
	rect = r
	modulate.a = a
	if _bubble == null:
		_bubble = UI.entity_bubble()
	draw_style_box(_bubble, r)
	# The face, at the left, with a soft halo.
	Entity.draw_face(self, r.position + Vector2(29, 32), 19.0, t)
	var x := r.position.x + 56.0
	# Its tag in small capitals, the subject in the display face, then the line.
	UI.draw_eyebrow(self, Vector2(x, r.position.y + 16.0), Entity.TEXT["tag"], Color(UI.PERIWINKLE, 0.9), 10)
	var ty := r.position.y + 34.0
	if titled:
		UI.draw_title(self, Vector2(x, r.position.y + 35.0), String(current["name"]), 19, Color(0.9, 0.86, 1.0), HORIZONTAL_ALIGNMENT_LEFT, tw, 0.0)
		ty += 20.0
	draw_multiline_string(font, Vector2(x, ty), text, HORIZONTAL_ALIGNMENT_LEFT, tw, 15, -1, Entity.GLOW.lerp(Color.WHITE, 0.62))
	# How to dismiss it, and that it's kept.
	var how := "tap" if main.touch_active else (("R3" if main.pad_ps else "RS") if main.pad_active else "Enter")
	var hint: String = how + ("  ·  " + Entity.TEXT["kept"] if current["kind"] == "tip" else "")
	draw_string(UI.font("mono"), Vector2(r.position.x, r.end.y - 8.0), hint, HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 12.0, 10, UI.FAINT)
	# Time left, a thin line along the bottom.
	var k := clampf(1.0 - shown_t / maxf(life, 0.01), 0.0, 1.0)
	draw_line(Vector2(r.position.x + 10.0, r.end.y - 2.5), Vector2(r.position.x + 10.0 + (r.size.x - 20.0) * k, r.end.y - 2.5), Color(Entity.GLOW, 0.35), 1.5)
