extends "res://scripts/puzzles/base.gd"
## THE HALL OF BELLS: bells hang in a ring round a conch shell on a stone.
## When you step in, the bells ring a song by themselves, one at a time,
## each lighting up as it sounds (each bell has its own colour, size and
## note, so the song can be seen as well as heard). Then ring them back in
## the same order: strike them, or shoot them.
##   the right next bell   it rings and stays lit a moment
##   any other             FAILURE: the beast sends hunters; once they're
##                         beaten the song plays again
##   strike the conch      the song plays again (as often as you like)
##   tier 1: 4 bells, a song of 3
##   tier 2: 5 bells, a song of 4
##   tier 3: 6 bells, a song of 5 (a bell may come twice), and the room
##           closes behind you
## While the song plays, the bells don't answer you.

const NAME := "The Hall of Bells"
static var NAMES := {"kraken": "The Drowned Bells"}
static var TEXT := {
	"rule": ["Listen, then ring the bells in the same order.", "Strike the shell to hear the song again."],
	"quiet": "The bells hang still while blood is spilled.",
	"wrong": "A sour note. The water stirs.",
	"listen": "Listen first",
	"again": "The song again",
}
const BREAKS := {}
const SEAL_FROM := 3
const MODES := ["quiet", "pressure"]
## By tier: [bells, notes in the song, repeats allowed].
const COUNT := {1: [4, 3, false], 2: [5, 4, false], 3: [6, 5, true]}
## The song's pace: each note sounds this long, with this gap after it.
const NOTE := 0.62
const NOTE_GAP := 0.26
## The ring's radius in tiles, and a bell's size.
const RING := 3
const BELL_R := 13.0
## A carved hall big enough for the ring.
const ROOM_SIZE := [11, 13, 10, 11]
const ROOM_SHAPES := ["round", "rect"]
## Each bell's colour (its band) and note (a pitch), biggest and lowest first.
const TONES := [[Color(0.35, 0.6, 1.0), 0.7], [Color(0.3, 0.85, 0.7), 0.8], [Color(0.95, 0.85, 0.35), 0.9],
	[Color(1.0, 0.55, 0.3), 1.0], [Color(0.9, 0.45, 0.75), 1.12], [Color(0.75, 0.6, 1.0), 1.25]]

var bells: Array = []  # {pos, tone, lit (seconds left lit), size}
var song: Array = []  # bell indices
var conch := Vector2.ZERO
var heard_n := 0  # notes rung back so far
var playing := false
var play_t := 0.0
var played := false  # the song has been heard once since the last reset
var _sung := -1  # the note sounding now, while playing


static func make(rect: Rect2, _floor_num: int, tier: int, ctx: Dictionary) -> Dictionary:
	var cnt: Array = COUNT.get(tier, COUNT[1])
	var n: int = cnt[0]
	var size := Vector2i(RING * 2 + 1, RING * 2 + 1)
	var o := fit_block(ctx, size, 1)
	if o.x < 0:
		return {}
	var mid := o + Vector2i(RING, RING)
	var spots: Array = []
	var a0 := randf() * TAU
	for k in n:
		var a := a0 + TAU * k / n
		var t := mid + Vector2i(roundi(cos(a) * RING), roundi(sin(a) * RING))
		if spots.any(func(s): return s["t"] == t):
			return {}
		spots.append({"t": t, "pos": tile_center(rect, t), "tone": k})
	var order: Array = []
	for k in int(cnt[1]):
		var pick := randi() % n
		var tries := 0
		while tries < 20 and ((not cnt[2] and pick in order) or (not order.is_empty() and order[-1] == pick)):
			pick = randi() % n
			tries += 1
		order.append(pick)
	return {"bells": spots.map(func(s): return {"pos": s["pos"], "tone": s["tone"]}), "song": order, "conch": tile_center(rect, mid),
		"reserve": block_tiles(o, size, 1), "rewards": [tile_center(rect, mid + Vector2i(0, 1))]}


func _build() -> void:
	var n: int = spec.get("bells", []).size()
	for q in spec.get("bells", []):
		var tone: int = int(q["tone"])
		bells.append({"pos": q["pos"], "tone": tone, "lit": 0.0, "size": lerpf(1.15, 0.85, float(tone) / maxf(1.0, float(n - 1)))})
		host.add_round_body(q["pos"], BELL_R)
	song = spec.get("song", [])
	conch = spec.get("conch", room.get_center())
	host.add_round_body(conch, 12.0)


func color_of(q: Dictionary) -> Color:
	return TONES[int(q["tone"]) % TONES.size()][0]


func _ring(q: Dictionary, k := 1.0) -> void:
	q["lit"] = 0.55
	main.sfx("shop_bell", float(TONES[int(q["tone"]) % TONES.size()][1]), -3.0 * k, 0.0)
	main.fx_ring(q["pos"], color_of(q), 34.0, 0.4, 2.5)
	main.light_flash(q["pos"], color_of(q), 0.8, 1.0, 0.3)


## Plays the song from its start (the bells won't answer until it ends).
func play() -> void:
	playing = true
	play_t = 0.0
	_sung = -1
	heard_n = 0


func tick(delta: float) -> void:
	for q in bells:
		q["lit"] = maxf(0.0, q["lit"] - delta)
	# The song plays by itself the first time you're in the room (and after a reset).
	if not played and not playing and player_in_room(-30.0):
		play()
	if playing:
		play_t += delta
		var step := NOTE + NOTE_GAP
		var k := int(floor((play_t - 0.4) / step))
		if k >= 0 and k < song.size() and k != _sung and fmod(play_t - 0.4, step) < NOTE:
			_sung = k
			_ring(bells[int(song[k])])
		if play_t > 0.4 + step * song.size():
			playing = false
			played = true


func watch(_delta: float) -> void:
	pass


## A bell struck (or shot): the next in the song, or a sour note.
func _answer(q: Dictionary) -> void:
	if host.solved or not host.awake or host.locked:
		return
	if playing:
		main.fx_text(q["pos"] + Vector2(0, -30), TEXT["listen"], Color(0.8, 0.85, 1.0))
		return
	var want := int(song[heard_n]) if heard_n < song.size() else -1
	if bells.find(q) == want:
		_ring(q)
		heard_n += 1
		if heard_n >= song.size():
			host.solve()
		return
	_ring(q, 0.5)
	heard_n = 0
	host.fail(TEXT["wrong"])


func strike(from: Vector2, dir: Vector2, reach: float, arc_deg: float) -> int:
	var all: Array = bells + [{"pos": conch, "conch": true}]
	var q = nearest_in_swing(all, from, dir, reach, arc_deg)
	if q == null:
		return 0
	if q.get("conch", false):
		if not host.solved and host.awake and not playing:
			main.fx_text(conch + Vector2(0, -30), TEXT["again"], Color(0.8, 0.85, 1.0))
			main.sfx("bubble", 0.8, -4.0)
			play()
		return 1
	_answer(q)
	return 1


func shot(pos: Vector2) -> bool:
	for q in bells:
		if pos.distance_to(q["pos"]) < BELL_R + 3.0:
			_answer(q)
			return true
	return false


func reset() -> void:
	heard_n = 0
	playing = false
	played = false  # (the song plays again as you step back in)


func state() -> Array:
	return [heard_n, playing]


## The floor bot: the bell to strike next (-1 while the song plays or before it has).
func next_bell() -> int:
	if playing or not played or heard_n >= song.size():
		return -1
	return int(song[heard_n])


func aim_points() -> Array:
	var b := next_bell()
	return [bells[b]["pos"]] if b >= 0 else []


func spot_ok(pos: Vector2) -> bool:
	if pos.distance_to(conch) < 50.0:
		return false
	for q in bells:
		if q["pos"].distance_to(pos) < 46.0:
			return false
	return true


func panels() -> Array:
	if not player_in_room(10.0) or bells.is_empty():
		return []
	return [{"pos": Vector2(room.get_center().x, room.position.y - 6.0), "title": host.display_name().to_upper(), "lines": TEXT["rule"].duplicate()}]


func lights() -> Array:
	var out: Array = []
	for q in bells:
		if q["lit"] > 0.0 or host.solved:
			out.append([q["pos"], 110.0, color_of(q), 0.7, 0.25])
	out.append([conch, 60.0, Color(0.7, 0.85, 1.0), 0.35, 0.05])
	return out


## A bell: a frame over it, the bell hanging (its band in its colour).
func draw(ci: CanvasItem) -> void:
	# The conch on its stone.
	Draw.shadow(ci, conch + Vector2(0, 10), 14.0)
	ci.draw_circle(conch + Vector2(0, 4), 13.0, Color(0.1, 0.09, 0.11))
	ci.draw_circle(conch + Vector2(0, 4), 11.5, Color(0.4, 0.42, 0.46))
	var shell := PackedVector2Array()
	for i in 14:
		var a := PI * 0.15 + PI * 1.6 * i / 13.0
		shell.append(conch + Vector2(cos(a) * 9.0, sin(a) * 6.0 - 4.0) * (0.6 + 0.4 * i / 13.0))
	shell.append(conch + Vector2(10, -2))
	ci.draw_colored_polygon(shell, Color(0.95, 0.82, 0.74))
	ci.draw_polyline(shell, Color(0.55, 0.4, 0.38), 1.2)
	for q in bells:
		var c: Vector2 = q["pos"]
		var s: float = q["size"]
		Draw.shadow(ci, c + Vector2(0, 12), 13.0 * s)
		# The frame: two posts and a beam.
		ci.draw_line(c + Vector2(-13, 12), c + Vector2(-13, -22) * Vector2(1, s), Color(0.12, 0.1, 0.1), 4.0)
		ci.draw_line(c + Vector2(13, 12), c + Vector2(13, -22) * Vector2(1, s), Color(0.12, 0.1, 0.1), 4.0)
		ci.draw_line(c + Vector2(-15, -22 * s), c + Vector2(15, -22 * s), Color(0.4, 0.3, 0.22), 3.0)


func draw_glow(ci: CanvasItem, t: float) -> void:
	for q in bells:
		var c: Vector2 = q["pos"]
		var s: float = q["size"]
		var lit: bool = q["lit"] > 0.0 or host.solved
		var swing: float = sin(t * 18.0) * 0.18 * clampf(q["lit"] / 0.55, 0.0, 1.0)
		var top := c + Vector2(0, -20 * s)
		var body := PackedVector2Array()
		for p in [Vector2(-5, 0), Vector2(-7, 6), Vector2(-9, 16), Vector2(-12, 22), Vector2(12, 22), Vector2(9, 16), Vector2(7, 6), Vector2(5, 0)]:
			body.append(top + (p * s).rotated(swing))
		var bronze := Color(0.72, 0.55, 0.3) if not lit else Color(1.0, 0.85, 0.5)
		ci.draw_colored_polygon(body, bronze)
		ci.draw_polyline(body + PackedVector2Array([body[0]]), Color(0.18, 0.12, 0.08), 1.6)
		var band_a: Vector2 = top + (Vector2(-10, 17) * s).rotated(swing)
		var band_b: Vector2 = top + (Vector2(10, 17) * s).rotated(swing)
		ci.draw_line(band_a, band_b, color_of(q).lightened(0.2 if lit else 0.0), 3.5)
		ci.draw_circle(top + (Vector2(0, 24) * s).rotated(swing), 2.5 * s, Color(0.2, 0.14, 0.1))
		if lit:
			ci.draw_arc(c, 24.0 * s, 0.0, TAU, 28, Color(color_of(q), 0.6), 2.0)
	# While the song plays, a ripple from the conch; once it's played, a faint
	# pulse on the conch says it can be struck to hear it again.
	if not host.solved and host.awake:
		if playing:
			var k := fmod(t * 1.5, 1.0)
			ci.draw_arc(conch, 14.0 + k * 40.0, 0.0, TAU, 28, Color(0.7, 0.85, 1.0, 0.5 * (1.0 - k)), 2.0)
		else:
			ci.draw_arc(conch, 17.0, 0.0, TAU, 24, Color(0.7, 0.85, 1.0, 0.18 + 0.12 * sin(t * 2.5)), 1.4)
		# How far into the song you are: small lights by the conch.
		for k in song.size():
			var at := conch + Vector2((k - (song.size() - 1) * 0.5) * 9.0, 22.0)
			ci.draw_circle(at, 3.0, Color(1.0, 0.9, 0.6) if k < heard_n else Color(0.3, 0.3, 0.38))
