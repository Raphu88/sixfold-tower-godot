extends RefCounted
## THE REGARD'S GLIMPSE: at the Regard on floor 6 (reached, not fallen, and
## not refused), before the guardian's eye opens and the mark takes hold, the
## guardian shows the new climber a flash of the last fracture: the world,
## cracking as wild essence tore out of it, until six towers closed the wells.
## A few seconds (GLIMPSE "seconds"), skippable after GLIMPSE "skip_after"
## (Space, Enter, a click or a tap). Then the Regard plays as before, and its
## words end with the guardian's CHARGE: stop those who oppose the marks and
## endanger the towers (climb_shape.gd regard_lines).
##
## main.gd _begin_regard starts it (regard "glimpse": its length, "gt": time
## so far), main.gd _process runs it, hud.gd _draw_regard draws it through
## draw() below: the world a shaded ball (the shading toolkit, lit from the
## top-left), the cracks bleeding the six essences' colours, the shake, a
## white flash, and six towers standing round it as it fades. The words are
## flat. The Entity says a word once it's over (regard_glimpse).
## Every word and number is here (the Data editor: "The cities: lore in what
## people say").

const Draw := preload("res://scripts/draw_util.gd")
const Shade := preload("res://scripts/shade.gd")
const UI := preload("res://scripts/ui.gd")
const Essence := preload("res://scripts/essence.gd")

## How long it plays, when a press may skip it, and when each caption
## fades in (seconds).
static var GLIMPSE := {"seconds": 4.8, "skip_after": 0.4, "caption_at": [0.3, 1.5, 3.6]}
## Its words: the captions (each fades in at GLIMPSE "caption_at"), the
## prompt, and the guardian's charge after it (two lines under the Regard's
## words; the first names the guardian).
static var TEXT := {
	"captions": ["Once, everyone drew essence raw, as much as they could hold.", "The world cracked.", "Six towers closed the wells."],
	"skip": "to skip",
	"charge": ["%s speaks: \"Guard the towers. Stop those who oppose the marks.\"", "\"Do not let the world crack again.\""],
}

const KINDS := ["air", "water", "iron", "fire", "stone", "blade"]


## Starts the glimpse on a Regard (main.gd _begin_regard).
static func start(rg: Dictionary) -> void:
	rg["glimpse"] = float(GLIMPSE["seconds"])
	rg["gt"] = 0.0


## True while the glimpse is still playing on this Regard.
static func active(rg: Dictionary) -> bool:
	return rg.has("glimpse") and float(rg.get("gt", 0.0)) < float(rg["glimpse"])


## Runs it a frame (main.gd _process): `dt` seconds pass; `skip` (a dismiss
## press) ends it once skip_after has passed. True when it ended this frame.
static func tick(rg: Dictionary, dt: float, skip: bool) -> bool:
	if not active(rg):
		return false
	rg["gt"] = float(rg.get("gt", 0.0)) + dt
	if skip and float(rg["gt"]) > float(GLIMPSE["skip_after"]):
		rg["gt"] = float(rg["glimpse"])
	return not active(rg)


## Ends it at once (main.gd end_regard: a Regard closed some other way).
static func finish(rg: Dictionary) -> void:
	if rg.has("glimpse"):
		rg["gt"] = float(rg["glimpse"])


## The guardian's charge, under the Regard's words: `beast` its name.
static func charge(beast: String) -> Array:
	var out: Array = []
	var lines: Array = TEXT["charge"]
	for i in lines.size():
		out.append(String(lines[i]) % beast if i == 0 and String(lines[i]).contains("%s") else String(lines[i]))
	return out


# --- drawing ------------------------------------------------------------------------------

## A crack from the world's middle: its points (unit-ish, from the centre
## outwards), the same every frame (no random numbers per frame).
static func _crack(i: int, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var a := -PI / 2.0 + TAU * float(i) / 6.0 + 0.35
	var at := Vector2.from_angle(a) * r * 0.08
	pts.append(at)
	for k in 6:
		var wob := sin(float(i * 7 + k * 3) * 1.7) * 0.55
		at += Vector2.from_angle(a + wob) * r * 0.18
		pts.append(at)
	return pts


## The part of a polyline `p` (0..1) of the way along it.
static func _part(pts: PackedVector2Array, p: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	if pts.size() < 2 or p <= 0.0:
		return out
	var n := (pts.size() - 1) * clampf(p, 0.0, 1.0)
	var whole := int(floor(n))
	for k in mini(whole + 1, pts.size()):
		out.append(pts[k])
	if whole < pts.size() - 1:
		out.append(pts[whole].lerp(pts[whole + 1], n - float(whole)))
	return out


## Draws the glimpse over the screen (hud.gd _draw_regard): `t` seconds
## in, `prompt` the words for skipping it ("Press Space ... to skip").
static func draw(c: CanvasItem, size: Vector2, font: Font, t: float, prompt: String) -> void:
	var total := float(GLIMPSE["seconds"])
	var b := Draw.Batch.new()
	b.rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.03, 1.0))
	# A few still stars (flat), placed the same way every frame.
	for i in 36:
		var sp := Vector2(fposmod(float(i) * 173.3, size.x), fposmod(float(i) * 97.7 + float(i * i) * 3.1, size.y * 0.9))
		b.circle(sp, 1.0 + float(i % 3) * 0.5, Color(0.8, 0.82, 0.95, 0.25 + 0.15 * float(i % 4)), 8)
	var r := minf(size.y * 0.24, 150.0)
	var crack_p := clampf((t - 1.0) / 1.6, 0.0, 1.0)
	var shake := Vector2(sin(t * 47.0), cos(t * 39.0)) * 5.0 * crack_p * (1.0 - clampf((t - 3.2) / 0.4, 0.0, 1.0))
	var mid := Vector2(size.x / 2.0, size.y * 0.42) + shake
	var appear := clampf(t / 0.5, 0.0, 1.0)
	# The world: the same one the opening shows (opening.gd _globe: its lit
	# ocean, turning lands, clouds and air), slowly turning; it fades in over
	# the dark (drawn first in its own batch, then the dark laid over it).
	var gb := Draw.Batch.new()
	gb.soft(mid, Vector2.ONE * r * 2.1, Color(0.35, 0.5, 1.0, 0.16 * appear))
	gb.circle(mid, r + 1.6, Color(0.03, 0.025, 0.04), 48)
	load("res://scripts/opening.gd")._globe(gb, mid, r, t * 0.06, 1.0)
	b.flush(c)
	gb.flush(c)
	b = Draw.Batch.new()
	if appear < 1.0:
		b.circle(mid, r * 1.12, Color(0.02, 0.015, 0.03, 1.0 - appear), 48)
	# The cracks: dark rifts, each bleeding one of the six essences' light.
	if crack_p > 0.0:
		for i in 6:
			var kind: String = KINDS[i]
			var col: Color = Essence.color(kind)
			var pts := _part(_crack(i, r), crack_p)
			if pts.size() < 2:
				continue
			for k in pts.size():
				pts[k] += mid
			b.polyline(pts, Color(col, 0.28), 11.0 + 6.0 * crack_p)
			b.polyline(pts, Color(col.lightened(0.3), 0.85), 3.6)
			b.polyline(pts, Color(0.03, 0.02, 0.05, 0.9), 1.4)
			# Wild essence tearing out of the end of each crack.
			var tip: Vector2 = pts[pts.size() - 1]
			var out := Vector2.from_angle(TAU * float(i) / 6.0 - PI / 2.0 + 0.35)
			for s in 3:
				var away := fposmod(t * 0.9 + float(s) * 0.33, 1.0)
				b.soft(tip + out * away * r * 0.7, Vector2.ONE * (10.0 + 14.0 * away), Color(col, 0.55 * (1.0 - away) * crack_p))
	# The flash, then six towers stand round the world as it fades.
	var flash := clampf((t - 2.8) / 0.4, 0.0, 1.0) * (1.0 - clampf((t - 3.3) / 0.9, 0.0, 1.0))
	var towers := clampf((t - 3.4) / 0.8, 0.0, 1.0)
	if towers > 0.0:
		for i in 6:
			var at := mid + Vector2.from_angle(-PI / 2.0 + TAU * float(i) / 6.0 + 0.35) * r * 1.32
			var h := r * 0.55 * towers
			var w := r * 0.12
			b.contact(at + Vector2(0, 2), w * 0.9, 0.35 * towers)
			b.box(Rect2(at - Vector2(w / 2.0, h), Vector2(w, h)), Color(0.5, 0.47, 0.56, towers))
			b.fill(PackedVector2Array([at + Vector2(-w * 0.7, -h), at + Vector2(0, -h - w * 1.2), at + Vector2(w * 0.7, -h)]), Color(0.42, 0.38, 0.5, towers))
			b.soft(at + Vector2(0, -h - w * 1.5), Vector2.ONE * w * 1.4, Color(Essence.color(KINDS[i]), 0.6 * towers))
	if flash > 0.0:
		b.rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.97, 0.9, 0.9 * flash))
	var fade := clampf((t - (total - 0.5)) / 0.5, 0.0, 1.0)
	if fade > 0.0:
		b.rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.03, fade))
	b.flush(c)
	# The words: flat, outlined, under the world.
	var caps: Array = TEXT["captions"]
	var ats: Array = GLIMPSE["caption_at"]
	var y := size.y * 0.42 + r + 64.0
	for i in caps.size():
		var at_t := float(ats[i]) if i < ats.size() else float(i)
		var a := clampf((t - at_t) / 0.4, 0.0, 1.0) * (1.0 - fade)
		if a <= 0.0:
			continue
		c.draw_string_outline(font, Vector2(0, y), String(caps[i]), HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, 5, Color(0, 0, 0, 0.8 * a))
		c.draw_string(font, Vector2(0, y), String(caps[i]), HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color(UI.TEXT, a))
		y += 26.0
	if t > float(GLIMPSE["skip_after"]):
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
		c.draw_string(font, Vector2(0, size.y - 40), prompt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color(UI.DIM, 0.4 + 0.4 * pulse))
