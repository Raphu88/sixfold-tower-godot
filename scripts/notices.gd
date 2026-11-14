extends RefCounted
## What the game tells you during play, in one tidy scheme (main.gd owns one:
## `main.notices`; hud.gd draws it). The owner's rule: nothing stays in the
## middle of the screen. The centre belongs to the climber and the fight.
##
##   TOP MIDDLE   the announcement lane. One compact banner at a time (a
##                title and a short line): a floor, a room's name, a door
##                slamming shut, a task done. Banners queue: a new one waits
##                for the one showing, or takes its place if it matters more.
##                Each fades in, holds a few seconds and fades out. Under it,
##                the status chips: one line each (the task's progress,
##                "doors shut: 3 left", a scenario's clock), stacked.
##   LEFT         the feed, under the health bar and the slots: what you
##                picked up, what was banked at a stair, renown, a pact.
##                Short lines, a few at most, each gone in a few seconds.
##   RIGHT        the Entity (guide.gd): its sphere, its bubble, and, when
##                you open it, its log of what happened this climb.
##
## Every caller still writes `main.banner = {"title": ..., "lines": [...],
## "t": seconds}` as before; main.gd hands it here (announce). Extra fields:
##   pri     0 a room's name or a spell's first cast (waits its turn), 1 the
##           default, 2 a question that can't wait ("RESTART?", "LOCKED")
##   line    the one line the lane shows (default: as many of `lines` as fit
##           on two rows); the other lines go to the feed
##   long    a floor's task: held a little longer
##   note    words to read (a puzzle's rule, a tablet): up to four rows, on a
##           plate, held by their length
##   hold    held for exactly `t` (a question with its own clock)
##   who     "entity": the Entity speaking in the lane (a phone with no room
##           beside its sphere)
##   show    how many leading lines the lane may show (the rest go to the feed)
##   shown   lines that `line` already says (never repeated in the feed)
##   kinds   {line: an event kind} for the lines that go to the feed
##   logged  the caller put those lines in the log itself: the feed only
##
## One event source for the feed and the Entity's log (main.note_event):
## note(kind, text, colour). KINDS says which kinds show in the feed; all of
## them are kept in the log (the last LOG_SHOWN show). Damage is never an
## event. Essence is batched: one line per burst and kind ("+14 Air").
##
## All sizes are HUD units (the HUD size setting scales them, as the corner's
## bars), on top of the Interface size.

const UI := preload("res://scripts/ui.gd")
const Draw := preload("res://scripts/draw_util.gd")
const Layout := preload("res://scripts/layout.gd")
const Essence := preload("res://scripts/essence.gd")

## A banner fades in and out over these (seconds), and holds at most this
## long (a task or a note a little longer; a note by its length).
const BANNER_IN := 0.25
const BANNER_OUT := 0.4
const BANNER_MAX := 3.0
const BANNER_LONG := 4.5
const NOTE_MIN := 3.5
const NOTE_MAX := 8.0
const NOTE_PER_CHAR := 0.05
## With another banner waiting, the one showing gives way once it has shown this long.
const BANNER_HURRY := 1.4
## Banners that may wait. One more and the least important oldest one is dropped.
const QUEUE_MAX := 3
## The lane: its top edge, its widest and narrowest, and the share of the
## screen it may take.
const LANE_TOP := 6.0
const LANE_W := 440.0
const LANE_MIN := 140.0
const LANE_SHARE := 0.36
const NOTE_W := 520.0  # (a note, words to read, may be this wide)
## Type sizes: a banner's title and line, a chip, a feed line.
const TITLE_SIZE := 20
const TITLE_MIN := 15
const LINE_SIZE := 13
const LINE_H := 15.0
const CHIP_SIZE := 14
const CHIP_H := 22.0
const CHIP_GAP := 4.0
const CHIPS_MAX := 3
const FEED_SIZE := 13
const FEED_H := 18.0
## The feed: how long a line stays, how many show, how wide.
const FEED_SHOW := 4.5
const FEED_MAX := 4
const FEED_W := 270.0
## The log: how many lines the Entity shows, and how many are kept.
const LOG_SHOWN := 20
const LOG_KEEP := 60
## Essence gathered within this long (seconds) of the last of its kind, in
## the same room, is one line.
const ESSENCE_BATCH := 4.0

## The kinds of event: its name in the log's key, its colour, the small
## sign drawn before it ("gem", "diamond", "ring", "dot", "square", "up",
## "down", "star"), and whether the left feed shows it (the log keeps all).
static var KINDS := {
	"essence": {"name": "Essence gathered", "color": Color(0.7, 0.85, 1.0), "sign": "gem", "feed": false},
	"banked": {"name": "Banked at a stair", "color": Color(0.95, 0.85, 0.55), "sign": "gem", "feed": true},
	"crystal": {"name": "A crystal", "color": Color(0.75, 0.9, 1.0), "sign": "gem", "feed": true},
	"item": {"name": "An item", "color": Color(0.6, 1.0, 0.7), "sign": "dot", "feed": true},
	"gear": {"name": "Gear", "color": Color(0.9, 0.88, 0.85), "sign": "square", "feed": true},
	"key": {"name": "A key", "color": Color(0.95, 0.8, 0.4), "sign": "diamond", "feed": true},
	"rest": {"name": "Rest", "color": Color(0.6, 1.0, 0.7), "sign": "up", "feed": true},
	"mark": {"name": "A mark grows", "color": Color(0.85, 0.75, 1.0), "sign": "star", "feed": true},
	"renown": {"name": "Renown", "color": Color(0.95, 0.8, 0.5), "sign": "star", "feed": true},
	"pact": {"name": "A pact", "color": Color(0.85, 0.75, 1.0), "sign": "ring", "feed": true},
	"noticed": {"name": "The beast noticed", "color": Color(1.0, 0.85, 0.5), "sign": "ring", "feed": true},
	"camp": {"name": "A camp", "color": Color(0.95, 0.75, 0.45), "sign": "up", "feed": true},
	"room": {"name": "A room", "color": Color(0.8, 0.78, 0.85), "sign": "square", "feed": false},
	"floor": {"name": "A floor", "color": Color(0.91, 0.75, 0.42), "sign": "up", "feed": false},
	"task": {"name": "The floor's task", "color": Color(1.0, 0.88, 0.6), "sign": "diamond", "feed": false},
	"task_done": {"name": "A task done", "color": Color(1.0, 0.88, 0.6), "sign": "diamond", "feed": false},
	"puzzle": {"name": "A puzzle solved", "color": Color(1.0, 0.89, 0.63), "sign": "diamond", "feed": false},
	"puzzle_fail": {"name": "A puzzle failed", "color": Color(0.98, 0.5, 0.42), "sign": "down", "feed": false},
	"scenario": {"name": "A scenario", "color": Color(1.0, 0.85, 0.5), "sign": "ring", "feed": false},
	"doors": {"name": "Doors", "color": Color(0.9, 0.6, 0.5), "sign": "square", "feed": false},
	"lock": {"name": "A lock", "color": Color(0.95, 0.8, 0.4), "sign": "diamond", "feed": false},
	"crack": {"name": "A cracked wall", "color": Color(0.85, 0.8, 0.72), "sign": "dot", "feed": false},
	"secret": {"name": "A secret", "color": Color(0.62, 0.72, 0.79), "sign": "star", "feed": false},
	"reaction": {"name": "A reaction", "color": Color(0.75, 0.9, 1.0), "sign": "ring", "feed": false},
	"fall": {"name": "A fall", "color": Color(0.85, 0.7, 0.6), "sign": "down", "feed": false},
	"news": {"name": "News", "color": Color(0.925, 0.89, 0.81), "sign": "dot", "feed": true},
}

## Words (all of them here, for the Data editor).
static var TEXT := {
	"essence": "+%d %s",  # a burst of essence, batched: amount, its kind
	"again": "%s  x%d",  # the same thing more than once
	"room": "Entered %s",
	"floor": "Reached %s",
	"task": "Task: %s",
	"task_done": "Task done: %s",
	"puzzle": "Solved: %s",
	"puzzle_fail": "Failed: %s",
	"scenario_start": "Began: %s",
	"scenario_done": "%s: %s",  # a scenario's name, its grade
	"scenario_failed": "%s: failed",
	"doors_shut": "The doors shut",
	"doors_open": "The doors opened",
	"lock": "A lock opened",
	"lever": "A lever lifted the bars",
	"crack": "Broke a cracked wall",
	"secret": "Found a secret room",
	"reaction": "Reaction: %s",
	"pact": "Pact formed: %s",
	"noticed": "%s noticed: %s (%s)",  # the beast, the scenario, the grade
	"fall": "Fell to floor %d",
	"camp": "Camp: %s",
	"stair": "The stair is open",
	"stair_left": "The stair is open  ·  %d %s left",
	"foe": "foe",
	"foes": "foes",
	"status": "%s  ·  %s",  # a chip: a title and its line
	"broken": "%s  ·  broken",
	"plaque": "?",  # the small marker a rule's words leave at the puzzle
}

## The climb's log as it was last written (its events, and the tower), kept
## after the climb ends (a fall or a summit starts the scene again): the
## Entity answers "How did my last climb go?" from it on the train
## (entity_talk.gd). Not saved: after the game restarts it has the record only.
static var climb_log := {}

var main
var current := {}  # the banner showing
var queue: Array = []  # banners waiting
var shown := 0  # banners shown (tests)
var feed_lines: Array = []  # {text, color, kind, t, n}
var log: Array = []  # oldest first: {kind, text, color, floor, n}
var fresh := 0  # log lines added since the Entity last looked (its sphere pulses)
## Where things were last drawn, in view px (tests; the Entity keeps its
## bubble clear of the lane's column): the banner, each chip, each feed
## line, and the lane's whole column.
var rects := {"banner": Rect2(), "chips": [], "feed": [], "column": Rect2()}
var lane_w := LANE_W  # the lane's width as last laid out (HUD units)
var chip_right := INF  # the chips keep left of this (HUD units): a phone's Swap or cast button beside them
var left_mode := false  # no room at the top: the lane sits under the corner
var _shift := 0.0  # how far the chips have slid down for a banner (0..1)
var _banner_h := 0.0
var _draw_ms := 0
var _batch := {}  # essence kind -> {entry, t, room, floor}
var _once := {}  # things noted once a floor


# --- banners -----------------------------------------------------------------------

## A banner to show (main.gd's `banner` setter). {} clears the lane.
func announce(b: Dictionary) -> void:
	if b.is_empty():
		current = {}
		queue.clear()
		return
	if not current.is_empty() and _same(current, b):
		# The same words again (a question asked every frame it's held): no
		# second fade-in, nothing fed twice.
		for k in ["_age", "_fed"]:
			if current.has(k):
				b[k] = current[k]
		current = b
		return
	for i in queue.size():
		if _same(queue[i], b):
			queue[i] = b
			return
	if current.is_empty() or pri(b) > pri(current):
		_show(b)
		return
	queue.append(b)
	while queue.size() > QUEUE_MAX:
		# One too many: the least important goes, the oldest of those.
		var drop := 0
		for i in queue.size():
			if pri(queue[i]) < pri(queue[drop]):
				drop = i
		queue.remove_at(drop)


## How much a banner matters (see the top of this file).
static func pri(b: Dictionary) -> int:
	return int(b.get("pri", 0 if b.get("room", false) else 1))


static func _same(a: Dictionary, b: Dictionary) -> bool:
	if String(a.get("door", "")) != "" and a.get("door", "") == b.get("door", ""):
		return true
	return String(a.get("title", "")) != "" and a.get("title", "") == b.get("title", "") and a.get("who", "") == b.get("who", "")


func _show(b: Dictionary) -> void:
	b["_age"] = 0.0
	current = b
	shown += 1


## The longest a banner holds.
static func hold_limit(b: Dictionary) -> float:
	if b.get("hold", false):
		return INF
	if b.get("note", false):
		var n := 0
		for l in b.get("lines", []):
			n += String(l).length()
		return clampf(2.0 + n * NOTE_PER_CHAR, NOTE_MIN, NOTE_MAX)
	return BANNER_LONG if b.get("long", false) else BANNER_MAX


## True while a banner shows or waits.
func busy() -> bool:
	return not current.is_empty() or not queue.is_empty()


## The banner's alpha now (0 with none).
func banner_alpha() -> float:
	if current.is_empty():
		return 0.0
	return clampf(minf(float(current.get("_age", 0.0)) / BANNER_IN, float(current.get("t", 0.0)) / BANNER_OUT), 0.0, 1.0)


func tick(delta: float) -> void:
	if current.is_empty() and not queue.is_empty():
		_show(queue.pop_front())
	if not current.is_empty():
		var b := current
		b["_age"] = float(b.get("_age", 0.0)) + delta
		var t := minf(float(b.get("t", BANNER_MAX)), hold_limit(b))
		# Another waits that matters as much: this one gives way soon.
		if t > BANNER_OUT and float(b["_age"]) >= BANNER_HURRY and not b.get("hold", false) \
				and queue.any(func(q): return pri(q) >= pri(b)):
			t = BANNER_OUT
		b["t"] = t - delta
		_split(b)
		if float(b["t"]) <= 0.0:
			current = {}
			if not queue.is_empty():
				_show(queue.pop_front())
	for f in feed_lines:
		f["t"] -= delta
	feed_lines = feed_lines.filter(func(f): return float(f["t"]) > 0.0)
	for k in _batch.keys():
		_batch[k]["t"] -= delta
		if float(_batch[k]["t"]) <= 0.0:
			_batch.erase(k)


## The line the lane shows for a banner, as wrapped rows; its other lines
## go to the feed (once each).
func _split(b: Dictionary) -> Array:
	var lines: Array = b.get("lines", [])
	var key := [lines.hash(), String(b.get("line", "")), int(lane_w)]
	if b.get("_key") == key:
		return b["_rows"]
	var font: Font = UI.font("inscription") if b.get("inscribed", false) else UI.font("body")
	var fs := LINE_SIZE + (2 if font == UI.font("inscription") else 0)
	var w := lane_w - 28.0
	var max_rows := 2
	var rows: Array = []
	var over: Array = []
	if b.get("note", false):
		# Words to read: every line, each wrapped on its own.
		for l in lines:
			rows.append_array(wrap_text(font, String(l), fs, w))
	elif String(b.get("line", "")) != "":
		rows = wrap_text(font, String(b["line"]), fs, w)
		if rows.size() > max_rows + 1:
			rows = rows.slice(0, max_rows + 1)
		over = lines.filter(func(l): return String(l) != String(b["line"]))
	else:
		var text := ""
		var most := int(b.get("show", lines.size()))  # ("show": only this many leading lines)
		for i in lines.size():
			var l := String(lines[i])
			if l == "":
				continue
			var joined: String = l if text == "" else text + ("  " if text.right(1) in [".", "!", "?", ":"] else "  ·  ") + l
			var r: Array = wrap_text(font, joined, fs, w)
			if i >= most or (text != "" and r.size() > max_rows):
				over = lines.slice(i)
				break
			text = joined
			rows = r
	var fed: Dictionary = b.get("_fed", {})
	var kinds: Dictionary = b.get("kinds", {})
	var shown_lines: Array = b.get("shown", [])
	for l in over:
		if String(l) != "" and not fed.has(l) and not (l in shown_lines):
			fed[l] = true
			var kind := String(kinds.get(l, "news"))
			if b.get("logged", false):  # (its caller logged them: the feed only)
				feed(String(l), KINDS.get(kind, KINDS["news"])["color"], kind)
			else:
				note(kind, String(l), null, true)
	b["_fed"] = fed
	b["_key"] = key
	b["_rows"] = rows
	b["_font"] = font
	b["_fs"] = fs
	return rows


static func wrap_text(font: Font, text: String, size: int, max_w: float) -> Array:
	var out: Array = []
	var line := ""
	for word in text.split(" "):
		var test := word if line == "" else line + " " + word
		if line != "" and font.get_string_size(test, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > max_w:
			out.append(line)
			line = word
		else:
			line = test
	if line != "":
		out.append(line)
	return out


## `text` cut to fit `w`, with dots if it lost its end.
static func clip(font: Font, text: String, size: int, w: float) -> String:
	if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= w:
		return text
	var n := text.length()
	while n > 1 and font.get_string_size(text.left(n).strip_edges() + "...", HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > w:
		n -= 1
	return text.left(n).strip_edges() + "..."


# --- the feed and the log ------------------------------------------------------------

## Something happened worth a line (main.note_event): `kind` is one of KINDS.
## It goes to the left feed if its kind does (or `to_feed` says), and to the
## Entity's log. `once`: a key; the same key is noted once a floor.
func note(kind: String, text: String, color = null, to_feed = null, once := "") -> void:
	if text == "":
		return
	if once != "":
		if _once.has(once):
			return
		_once[once] = true
	var k: Dictionary = KINDS.get(kind, KINDS["news"])
	var col: Color = color if color is Color else k["color"]
	if (to_feed if to_feed is bool else bool(k["feed"])):
		feed(text, col, kind)
	_log(kind, text, col)


## A line in the left feed only.
func feed(text: String, color: Color = UI.TEXT, kind := "news") -> void:
	if text == "":
		return
	for f in feed_lines:
		if f["text"] == text:  # (the same again: once, counted)
			f["n"] += 1
			f["t"] = FEED_SHOW
			return
	feed_lines.append({"text": text, "color": color, "kind": kind, "t": FEED_SHOW, "n": 1})
	while feed_lines.size() > FEED_MAX:
		feed_lines.pop_front()


func _log(kind: String, text: String, col: Color) -> Dictionary:
	var fl: int = main.floor_num if main != null else 0
	if not log.is_empty() and log[-1]["kind"] == kind and log[-1]["text"] == text and log[-1]["floor"] == fl:
		log[-1]["n"] += 1
		return log[-1]
	var e := {"kind": kind, "text": text, "color": col, "floor": fl, "n": 1}
	log.append(e)
	if not is_same(climb_log.get("log"), log):
		climb_log = {"log": log, "tower": String(main.tower) if main != null else ""}
	while log.size() > LOG_KEEP:
		log.pop_front()
	fresh += 1
	return e


## Essence taken in (main.gather_essence, a secret essence rising): batched,
## one log line per burst and kind in a room.
func note_essence(kind: String, amount: float, name := "", color = null) -> void:
	if amount <= 0.0:
		return
	var room: int = main.room_at if main != null else -1
	var fl: int = main.floor_num if main != null else 0
	var said := name if name != "" else Essence.display(kind)
	var b = _batch.get(kind)
	if b != null and b["room"] == room and b["floor"] == fl and log.has(b["entry"]):
		b["amount"] += amount
		b["t"] = ESSENCE_BATCH
		b["entry"]["text"] = String(TEXT["essence"]) % [int(round(b["amount"])), said]
		return
	var col: Color = color if color is Color else Essence.color(kind)
	var e := _log("essence", String(TEXT["essence"]) % [int(round(amount)), said], col)
	_batch[kind] = {"entry": e, "amount": amount, "t": ESSENCE_BATCH, "room": room, "floor": fl}


## The log's last lines, newest first (the Entity's panel).
func recent(n := LOG_SHOWN) -> Array:
	var out: Array = log.slice(maxi(0, log.size() - n))
	out.reverse()
	return out


## A line of the log as the panel writes it.
static func log_text(e: Dictionary) -> String:
	return String(e["text"]) if int(e.get("n", 1)) < 2 else String(TEXT["again"]) % [e["text"], int(e["n"])]


## A new floor: what's noted once a floor may be noted again.
func new_floor() -> void:
	_once.clear()
	_batch.clear()


## A new climb: an empty log and feed.
func new_climb() -> void:
	if is_same(climb_log.get("log"), log):
		climb_log = {"log": log.duplicate(), "tower": climb_log.get("tower", "")}  # (the last climb's, kept)
	log.clear()
	feed_lines.clear()
	fresh = 0
	new_floor()


# --- where things go -------------------------------------------------------------------

## The lane's column on a view of `view` HUD units: between the corner's
## bars (ending at `left`) and whatever holds the top right (starting at
## `right`), centred on the screen where there's room. With no room at all
## it goes under the corner, on the left (`under` is the corner's foot).
func column(view: Vector2, left: float, right: float, under: float) -> Rect2:
	var wide: bool = current.get("note", false)  # (words to read may take all the room there is)
	left_mode = false
	if Layout.moved("hud.lane"):
		var d := Layout.default_box("hud.lane", view)
		lane_w = d.size.x
		return d
	var w := clampf(view.x * LANE_SHARE, LANE_MIN, LANE_W)
	if wide:
		w = NOTE_W
	var room := right - left - 20.0
	if room < LANE_MIN:
		left_mode = true
		lane_w = clampf(view.x * 0.3 - 18.0, 120.0, 240.0)
		return Rect2(16.0, under + 6.0, lane_w, 0.0)
	w = minf(w, room)
	lane_w = w
	return Rect2(clampf(view.x * 0.5 - w * 0.5, left + 10.0, right - 10.0 - w), LANE_TOP, w, 0.0)


## Draws the lane on `ci` (the HUD): the banner, then the chips under it.
## `unit` is the HUD's scale; `col` the lane's column (column()); `chips`
## are {text, color, gauge (0..1, optional), gauge_color, trail, tall}.
## Returns the stack's foot (HUD units).
func draw_lane(ci: CanvasItem, unit: Transform2D, view: Vector2, col: Rect2, chips: Array) -> float:
	var now := Time.get_ticks_msec()
	var dt := clampf((now - _draw_ms) / 1000.0, 0.0, 0.1)
	_draw_ms = now
	rects["banner"] = Rect2()
	rects["chips"] = []
	var bx := unit * Layout.xform("hud.lane", view)
	var sx := unit * Layout.xform("hud.status", view)
	var a := banner_alpha()
	var y := col.position.y
	var cx := col.position.x + col.size.x * 0.5
	var b := current
	if not b.is_empty():
		_banner_h = _banner_height(b)
	_shift = move_toward(_shift, 1.0 if not b.is_empty() else 0.0, dt / 0.18)
	if chips.is_empty():
		_shift = 1.0 if not b.is_empty() else 0.0  # (nothing to slide: no wait)
	if not b.is_empty():
		a = minf(a, _shift)
		var br := Rect2(col.position.x, y, col.size.x, _banner_h)
		ci.draw_set_transform_matrix(bx)
		_draw_banner(ci, b, br, a)
		if a > 0.01:
			rects["banner"] = bx * _banner_box(b, br)
	y += (_banner_h + CHIP_GAP) * _shift
	ci.draw_set_transform_matrix(sx)
	for c in chips.slice(0, CHIPS_MAX):
		var r := _draw_chip(ci, c, cx, y, col)
		rects["chips"].append(sx * r)
		y = r.end.y + CHIP_GAP
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	var colr := Rect2(col.position.x, col.position.y, col.size.x, maxf(y - col.position.y, 0.0))
	rects["column"] = unit * colr
	return y


func _banner_height(b: Dictionary) -> float:
	var rows: Array = _split(b)
	return 27.0 + LINE_H * rows.size() + (4.0 if not rows.is_empty() else 0.0)


## The banner's own box (its words, not the band's faded ends).
func _banner_box(b: Dictionary, br: Rect2) -> Rect2:
	var font: Font = UI.font("display")
	var title := UI.title_case(String(b.get("title", "")))
	var w := font.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, UI.fit_size(font, title, TITLE_SIZE, br.size.x - 24.0)).x
	var lf: Font = b.get("_font", UI.font("body"))
	for row in b.get("_rows", []):
		w = maxf(w, lf.get_string_size(String(row), HORIZONTAL_ALIGNMENT_LEFT, -1, int(b.get("_fs", LINE_SIZE))).x)
	w = minf(w + 28.0, br.size.x)
	if left_mode:
		return Rect2(br.position, Vector2(w, br.size.y))
	return Rect2(br.get_center().x - w * 0.5, br.position.y, w, br.size.y)


func _draw_banner(ci: CanvasItem, b: Dictionary, br: Rect2, a: float) -> void:
	if a <= 0.0:
		return
	var rows: Array = b.get("_rows", [])
	var entity: bool = b.get("who", "") == "entity"
	var rule: Color = UI.PERIWINKLE if entity else UI.GILT
	var box := _banner_box(b, br)
	var batch := Draw.Batch.new()
	if b.get("note", false) or entity or left_mode:
		# Words to read: a plate behind them.
		UI.plate_into(batch, box, a * 0.94, Color(rule, 0.5))
	else:
		UI.band_into(batch, Rect2(box.position.x - 50.0, box.position.y, box.size.x + 100.0, box.size.y), a, rule, 0.66)
	batch.flush(ci)
	var align := HORIZONTAL_ALIGNMENT_LEFT if left_mode else HORIZONTAL_ALIGNMENT_CENTER
	var tx := box.position.x + 12.0
	var tw := box.size.x - 24.0
	var title_col: Color = Color(0.9, 0.86, 1.0) if entity else UI.GOLD
	if b.get("accent") is Color:  # (a spell's first cast: its essence's colour)
		title_col = Color(b["accent"]).lightened(0.3)
	UI.draw_label(ci, Vector2(tx, br.position.y + 19.0), String(b.get("title", "")), TITLE_SIZE, Color(title_col, a), align, tw, 4, Color(0, 0, 0, 0.8 * a))
	var lf: Font = b.get("_font", UI.font("body"))
	var fs := int(b.get("_fs", LINE_SIZE))
	var ly := br.position.y + 22.0 + LINE_H
	for row in rows:
		ci.draw_string_outline(lf, Vector2(tx, ly), String(row), align, tw, fs, 3, Color(0, 0, 0, 0.8 * a))
		ci.draw_string(lf, Vector2(tx, ly), String(row), align, tw, fs, Color(UI.BAD if b.get("tone", "") == "bad" else UI.TEXT, a))
		ly += LINE_H


## A status chip: one line in a small cartouche (a gauge under it for a
## champion's or a beast's health). Returns its box.
func _draw_chip(ci: CanvasItem, c: Dictionary, cx: float, y: float, col: Rect2) -> Rect2:
	var font: Font = UI.font("display")
	var a := float(c.get("alpha", 1.0))
	var tall: bool = c.get("tall", false)
	var fs := CHIP_SIZE + (3 if tall else 0)
	var max_w := col.size.x
	if not left_mode and chip_right < col.end.x:
		# A button reaches down beside the chips: they keep to its left.
		max_w = maxf(chip_right - col.position.x, 90.0)
		cx = col.position.x + max_w * 0.5
	var words := UI.title_case(String(c["text"]))
	fs = UI.fit_floor(font, words, fs, max_w - 34.0, 11)  # (smaller before any of it is lost)
	var text := clip(font, words, fs, max_w - 34.0)
	var tw := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var has_gauge: bool = c.has("gauge")
	var w := minf(maxf(tw + 34.0, 170.0 if has_gauge else 0.0), max_w)
	if tall:
		w = minf(max_w, maxf(w, 300.0))
	var h := CHIP_H + ((12.0 if tall else 8.0) if has_gauge else 0.0)
	var x := col.position.x if left_mode else cx - w * 0.5
	var r := Rect2(x, y, w, h)
	var edge: Color = c.get("edge", UI.GILT)
	var pulse := 0.8 + 0.2 * sin(Time.get_ticks_msec() * 0.004) if c.get("pulse", false) else 1.0
	var batch := Draw.Batch.new()
	if has_gauge:
		UI.plate_into(batch, r, a * 0.9, Color(edge, 0.55))
		var gr := Rect2(r.position.x + 12.0, r.end.y - (13.0 if tall else 9.0), w - 24.0, 8.0 if tall else 5.0)
		UI.gauge_into(batch, gr, clampf(float(c["gauge"]), 0.0, 1.0), c.get("gauge_color", UI.HEALTH), float(c.get("trail", -1.0)), Color(1.0, 0.82, 0.55, 0.9), 4 if tall else 0, a)
	else:
		UI.cartouche_into(batch, r, Color(edge, 0.7 * pulse), a)
	batch.flush(ci)
	var tc: Color = c.get("color", UI.GOLD)
	UI.draw_label(ci, Vector2(r.position.x, r.position.y + CHIP_H * 0.5 + fs * 0.36), text, fs, Color(tc, a), HORIZONTAL_ALIGNMENT_CENTER, w, 3, Color(0, 0, 0, 0.7 * a))
	return r


## Draws the left feed from `top` down (HUD units). Returns its foot.
func draw_feed(ci: CanvasItem, unit: Transform2D, view: Vector2, at: Vector2) -> float:
	rects["feed"] = []
	if feed_lines.is_empty():
		return at.y
	var fx := unit * Layout.xform("hud.feed", view)
	ci.draw_set_transform_matrix(fx)
	var font: Font = UI.font("body")
	var w := minf(FEED_W, view.x * 0.3 - at.x - 6.0)
	var y := at.y
	var batch := Draw.Batch.new()
	var words: Array = []
	for f in feed_lines:
		if y + FEED_H > view.y - 6.0:
			break  # (a short screen with the lane on the left: no farther than its foot)
		var a := clampf(minf(float(f["t"]) / 0.5, (FEED_SHOW - float(f["t"])) / 0.2), 0.0, 1.0)
		var text: String = log_text(f)
		var rows: Array = wrap_text(font, text, FEED_SIZE, w - 22.0)
		if rows.size() > 2:
			rows = [rows[0], clip(font, String(rows[1]) + " " + String(rows[2]), FEED_SIZE, w - 22.0)]
		var tw := 0.0
		for row in rows:
			tw = maxf(tw, font.get_string_size(String(row), HORIZONTAL_ALIGNMENT_LEFT, -1, FEED_SIZE).x)
		var r := Rect2(at.x, y, tw + 26.0, FEED_H * rows.size())
		UI.hgrad_into(batch, Rect2(r.position, Vector2(r.size.x * 0.7, r.size.y - 1.0)), Color(UI.VOID, 0.62 * a), Color(UI.VOID, 0.5 * a))
		UI.hgrad_into(batch, Rect2(r.position + Vector2(r.size.x * 0.7, 0), Vector2(r.size.x * 0.3 + 14.0, r.size.y - 1.0)), Color(UI.VOID, 0.5 * a), Color(UI.VOID, 0.0))
		sign_into(batch, String(KINDS.get(f["kind"], KINDS["news"])["sign"]), r.position + Vector2(8.0, FEED_H * 0.5 - 0.5), 3.6, Color(f["color"], a))
		for i in rows.size():
			words.append([Vector2(r.position.x + 18.0, y + FEED_H * (i + 1) - 5.0), String(rows[i]), Color(Color(f["color"]).lerp(UI.TEXT, 0.35), a), a])
		rects["feed"].append(fx * r)
		y += r.size.y + 1.0
	batch.flush(ci)
	for wd in words:
		ci.draw_string_outline(font, wd[0], wd[1], HORIZONTAL_ALIGNMENT_LEFT, -1, FEED_SIZE, 3, Color(0, 0, 0, 0.75 * wd[3]))
		ci.draw_string(font, wd[0], wd[1], HORIZONTAL_ALIGNMENT_LEFT, -1, FEED_SIZE, wd[2])
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	return y


## An event kind's small sign, `r` across (half), into a batch.
static func sign_into(b, kind: String, c: Vector2, r: float, col: Color) -> void:
	var dark := Color(UI.OUTLINE, col.a)
	match kind:
		"gem":
			UI.diamond_into(b, c, r + 1.2, dark, 1.25)
			UI.diamond_into(b, c, r, col, 1.25)
			UI.diamond_into(b, c + Vector2(-r * 0.2, -r * 0.3), r * 0.4, Color(col.lightened(0.5), col.a), 1.25)
		"diamond":
			UI.diamond_into(b, c, r + 1.2, dark)
			UI.diamond_into(b, c, r, col)
		"ring":
			UI.ring_into(b, c, r + 0.6, 3.2, dark)
			UI.ring_into(b, c, r, 1.6, col)
		"square":
			b.rect(Rect2(c - Vector2(r, r) * 0.95, Vector2(r, r) * 1.9), dark)
			b.rect(Rect2(c - Vector2(r, r) * 0.7, Vector2(r, r) * 1.4), col)
		"up":
			b.polygon(PackedVector2Array([c + Vector2(0, -r - 1.2), c + Vector2(r + 1.4, r), c + Vector2(-r - 1.4, r)]), dark)
			b.polygon(PackedVector2Array([c + Vector2(0, -r + 0.6), c + Vector2(r - 0.4, r - 0.8), c + Vector2(-r + 0.4, r - 0.8)]), col)
		"down":
			b.polygon(PackedVector2Array([c + Vector2(0, r + 1.2), c + Vector2(r + 1.4, -r), c + Vector2(-r - 1.4, -r)]), dark)
			b.polygon(PackedVector2Array([c + Vector2(0, r - 0.6), c + Vector2(r - 0.4, -r + 0.8), c + Vector2(-r + 0.4, -r + 0.8)]), col)
		"star":
			# (a four-pointed star: a tall diamond and a wide one)
			UI.diamond_into(b, c, r + 1.6, dark, 0.5)
			UI.diamond_into(b, c, (r + 1.6) * 0.5, dark, 2.0)
			UI.diamond_into(b, c, r + 0.4, col, 0.4)
			UI.diamond_into(b, c, (r + 0.4) * 0.4, col, 2.5)
		_:
			b.dot(c, r * 0.8 + 1.0, dark)
			b.dot(c, r * 0.8, col)
