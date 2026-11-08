extends RefCounted
## How the climber looks: the options a new climber chooses from (and can
## change later from the climber screen or their car on the train), their
## names and colours, all as data. The choice is saved with the profile as
## a small dictionary of option ids (profile.gd `appearance`); DEFAULTS is
## the look every climber had before there was a choice, so old saves look
## the same.
##
## Drawing: look(app) turns a saved appearance into the colours and flags the
## drawing code reads (precomputed once when the appearance changes, never per
## frame). player.gd draws the climber in the tower from it (set_appearance),
## and its head with draw_head() below; the climber screen's figure
## (menu.gd BodyView._figure) draws the front view from the same look.
##
## Reusing it (the mirror image, or anything else drawn like the climber):
##   var look := Appearance.look(profile.appearance)   # once, when it changes
##   ...then each frame, in the drawing frame (x forward, y toward the weapon hand):
##   Appearance.draw_head(batch, head_pos, facing, side, light_dir, look, sway, drift)
## look["cloak"], ["tunic"], ["skin"], ["hair"], ["boot"] and ["eyes"] are the
## colours; look["hair_style"] and look["hood_up"] the flags. draw_head also
## reads look["hood"] (the hood's colour; player.gd darkens the cloak for it)
## and look["head"] ("hood", "bare", "coif", "cap" or "helm"; head_kind()
## gives it for a look with no headgear). A whole player.gd node can also be
## drawn as a doll: set_appearance(app) on it (appearance_page.gd does that).

const Palette := preload("res://scripts/palette.gd")
const UI := preload("res://scripts/ui.gd")

## The option rows, in the order the editor shows them: [key, name].
const ROWS := [
	["skin", "Skin"], ["hair", "Hair"], ["hair_color", "Hair colour"], ["eyes", "Eyes"],
	["cloak", "Cloak"], ["tunic", "Tunic"], ["hood", "Hood"],
]

## Each option: [id, name, colour] (colour options) or [id, name] (the rest).
## The first entry is not special; DEFAULTS says which one is today's look.
const OPTIONS := {
	"skin": [
		["porcelain", "Porcelain", Color(0.98, 0.88, 0.8)],
		["fair", "Fair", Palette.CLIMBER_SKIN],
		["warm", "Warm", Color(0.86, 0.69, 0.52)],
		["olive", "Olive", Color(0.76, 0.61, 0.43)],
		["tan", "Tan", Color(0.66, 0.48, 0.32)],
		["brown", "Brown", Color(0.5, 0.35, 0.23)],
		["deep", "Deep", Color(0.36, 0.25, 0.17)],
	],
	"hair": [
		["none", "Shaved"],
		["short", "Short"],
		["long", "Long"],
		["tied", "Tied up"],
		["braid", "Braid"],
	],
	"hair_color": [
		["black", "Black", Color(0.11, 0.1, 0.11)],
		["dark", "Dark brown", Color(0.22, 0.14, 0.09)],
		["brown", "Brown", Palette.CLIMBER_HAIR],
		["auburn", "Auburn", Color(0.52, 0.22, 0.11)],
		["copper", "Copper", Color(0.74, 0.38, 0.17)],
		["blond", "Blond", Color(0.86, 0.71, 0.42)],
		["ash", "Ash", Color(0.62, 0.6, 0.56)],
		["white", "White", Color(0.9, 0.89, 0.86)],
	],
	"eyes": [
		["dark", "Dark", Palette.OUTLINE],
		["brown", "Brown", Color(0.45, 0.27, 0.13)],
		["hazel", "Hazel", Color(0.58, 0.47, 0.22)],
		["green", "Green", Color(0.32, 0.62, 0.34)],
		["blue", "Blue", Color(0.33, 0.55, 0.88)],
		["grey", "Grey", Color(0.62, 0.66, 0.7)],
		["amber", "Amber", Color(0.9, 0.62, 0.2)],
	],
	"cloak": [
		["teal", "Teal", Palette.CLIMBER_CLOAK],
		["moss", "Moss", Color(0.38, 0.52, 0.3)],
		["crimson", "Crimson", Color(0.64, 0.2, 0.2)],
		["rust", "Rust", Color(0.68, 0.38, 0.2)],
		["ochre", "Ochre", Color(0.74, 0.58, 0.25)],
		["plum", "Plum", Color(0.46, 0.27, 0.52)],
		["midnight", "Midnight", Color(0.22, 0.27, 0.48)],
		["slate", "Slate", Color(0.42, 0.45, 0.5)],
		["bone", "Bone", Color(0.78, 0.74, 0.64)],
		["charcoal", "Charcoal", Color(0.22, 0.21, 0.24)],
	],
	"tunic": [
		["brown", "Brown", Palette.CLIMBER_TUNIC],
		["grey", "Grey", Color(0.42, 0.42, 0.44)],
		["olive", "Olive", Color(0.42, 0.42, 0.27)],
		["oxblood", "Oxblood", Color(0.44, 0.2, 0.2)],
		["navy", "Navy", Color(0.23, 0.27, 0.42)],
		["sand", "Sand", Color(0.64, 0.56, 0.43)],
		["black", "Black", Color(0.19, 0.18, 0.2)],
		["cream", "Cream", Color(0.78, 0.73, 0.62)],
	],
	"hood": [
		["up", "Hood up"],
		["down", "Hood down"],
	],
}

## Today's look: what every climber had before there was a choice (old
## saves load with it) and what a new climber starts from.
const DEFAULTS := {
	"name": "", "skin": "fair", "hair": "short", "hair_color": "brown", "eyes": "dark",
	"cloak": "teal", "tunic": "brown", "hood": "up",
}
const NAME_MAX := 14  # letters in a name (it's optional)
## Names the dice offers (it never picks the one you have).
const NAMES := [
	"Ash", "Bryn", "Cass", "Dara", "Edda", "Fen", "Gale", "Hale", "Ines", "Jory",
	"Kestrel", "Lio", "Mara", "Nell", "Oren", "Pell", "Quill", "Rhea", "Sorrel", "Tam",
	"Ulla", "Vale", "Wren", "Yara", "Zeph",
]

## The editor's words.
const TEXT := {
	"new_title": "NEW CLIMBER",
	"new_sub": "Choose how you look. You can change it later.",
	"edit_title": "APPEARANCE",
	"edit_sub": "How you look in the towers and on the climber screen.",
	"name": "Name",
	"name_hint": "optional",
	"name_dice": "Dice",
	"turn_left": "<  Turn",
	"turn_right": "Turn  >",
	"randomise": "Randomise",
	"begin": "Begin",
	"done": "Done",
	"button": "Appearance",  # on the climber screen
}

const BOOT := Palette.CLIMBER_BOOT


## A saved appearance made whole: every key present and every id known
## (anything missing or unknown takes today's look). Safe on old saves.
static func normalized(raw) -> Dictionary:
	var out := DEFAULTS.duplicate()
	if not (raw is Dictionary):
		return out
	for key in OPTIONS:
		var id := str(raw.get(key, out[key]))
		if index_of(key, id) >= 0:
			out[key] = id
	out["name"] = clean_name(str(raw.get("name", "")))
	return out


## A name as it's kept: trimmed, one line, at most NAME_MAX letters.
static func clean_name(s: String) -> String:
	s = s.replace("\n", " ").replace("\t", " ").strip_edges()
	return s.left(NAME_MAX).strip_edges()


static func index_of(key: String, id: String) -> int:
	var list: Array = OPTIONS.get(key, [])
	for i in list.size():
		if list[i][0] == id:
			return i
	return -1


## The option `by` steps from the current one (wrapping round).
static func step(app: Dictionary, key: String, by: int) -> String:
	var list: Array = OPTIONS[key]
	var i := maxi(0, index_of(key, str(app.get(key, DEFAULTS[key]))))
	return list[(i + by + list.size() * 4) % list.size()][0]


static func option_name(key: String, id: String) -> String:
	var i := index_of(key, id)
	return OPTIONS[key][i][1] if i >= 0 else id


static func color_of(key: String, id: String) -> Color:
	var i := index_of(key, id)
	if i < 0:
		i = index_of(key, DEFAULTS[key])
	return OPTIONS[key][i][2]


## True for the rows chosen by swatches (they have colours).
static func has_colors(key: String) -> bool:
	return OPTIONS[key][0].size() > 2


## A random look (the name is kept).
static func random(keep: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	var out := normalized(keep)
	for key in OPTIONS:
		var list: Array = OPTIONS[key]
		var i := rng.randi_range(0, list.size() - 1) if rng != null else randi() % list.size()
		out[key] = list[i][0]
	return out


## A name from NAMES, not the one given.
static func random_name(not_this: String) -> String:
	var pool := NAMES.filter(func(n): return n != not_this)
	return pool[randi() % pool.size()]


## The colours and flags the drawing reads, worked out once per change.
static func look(app) -> Dictionary:
	var a := normalized(app)
	return {
		"skin": color_of("skin", a["skin"]),
		"hair": color_of("hair_color", a["hair_color"]),
		"eyes": color_of("eyes", a["eyes"]),
		"cloak": color_of("cloak", a["cloak"]),
		"tunic": color_of("tunic", a["tunic"]),
		"boot": BOOT,
		"hair_style": a["hair"],
		"hood_up": a["hood"] == "up",
		"eye_r": 0.75 if a["eyes"] == DEFAULTS["eyes"] else 0.95,  # (a colour needs a little more room)
	}


## The head with no helm or other headgear: the hood, or bare when it's down.
static func head_kind(lk: Dictionary) -> String:
	return "hood" if lk.get("hood_up", true) else "bare"


## The colour on top of the head (rolling and fallen, where only that shows).
static func crown(lk: Dictionary) -> Color:
	if String(lk.get("head", "hood")) != "bare":
		return lk["hood"]
	return lk["skin"] if lk.get("hair_style", "short") == "none" else lk["hair"]


# --- the tower: the head, seen from above ----------------------------------------

## The climber's head in the tower, seen from above, facing `f` (`sd` is
## toward the weapon hand, `light` the light's direction, all in the drawing
## frame). `sway` and `drift` move what trails behind (the hood's peak, long
## hair, a braid) with the cloak. Reads look["head"]: "hood" (with hair
## peeking out as the style allows), "bare" (hood down: the hood bunched at
## the neck and the hair on show), "coif" (mail), "cap" or "helm".
static func draw_head(b, hd: Vector2, f: Vector2, sd: Vector2, light: Vector2, lk: Dictionary, sway: float, drift: Vector2) -> void:
	var head: String = lk.get("head", "hood")
	var style: String = lk.get("hair_style", "short")
	var hair: Color = lk["hair"]
	var hood: Color = lk["hood"]
	var trail := sway * 0.3 + drift.y * 0.3  # sideways, for what hangs behind
	if head == "bare":
		_bare_head(b, hd, f, sd, light, lk, style, sway, drift)
		return
	if head == "hood":
		# A tail or braid comes out from under the hood's peak.
		if style == "braid":
			for i in 3:
				var k := float(i)
				b.ball(hd + f * (-9.2 - 2.3 * k + drift.x * 0.3) + sd * (trail * (1.2 + 0.4 * k)), 2.0 - 0.25 * k, hair, true, light)
		elif style == "tied":
			b.ball(hd + f * (-9.0 + drift.x * 0.3) + sd * (trail * 1.2), 2.6, hair, true, light)
	if head == "hood" or head == "coif":
		b.poly(PackedVector2Array([hd + f * -2.0 + sd * 4.2, hd + f * (-8.5 + drift.x * 0.3) + sd * trail, hd + f * -2.0 + sd * -4.2]), hood.darkened(0.15), 1.0)
	if head == "cap":
		hood = hair  # a cap shows the hair round it
		if style == "none":
			hood = lk["skin"].darkened(0.08)
	b.ball(hd, 6.6, hood, true, light)
	match head:
		"helm":
			b.line(hd + f * -5.5, hd + f * 5.5, hood.lightened(0.25), 1.4)  # crest
			b.line(hd + f * 4.6 + sd * -3.8, hd + f * 4.6 + sd * 3.8, Palette.OUTLINE, 1.6)  # visor slit
			b.dot(hd + f * 5.4, 1.0, hood.darkened(0.3))
		"cap":  # Leather Cap: the face, under a crown of leather with a band
			b.dot(hd + f * 4.5, 2.8, lk["skin"])
			_eyes(b, hd, f, sd, lk)
			var cap: Color = lk["cap"]
			b.ball(hd + f * -1.6, 5.4, cap, true, light)
			b.arc(hd + f * -1.6, 5.2, f.angle() - 1.1, f.angle() + 1.1, 8, cap.darkened(0.45), 1.5)
		_:
			b.dot(hd + f * 3.8, 3.9, Color(Palette.OUTLINE, 0.5))  # the hood's shadow
			if style != "none":
				b.dot(hd + f * 2.9, 3.1, hair)
			b.dot(hd + f * 4.5, 2.8, lk["skin"])
			if style == "long" and head == "hood":
				for s in [-1.0, 1.0]:  # locks either side of the face
					b.dot(hd + f * 3.6 + sd * (s * 3.3), 1.5, hair)
			_eyes(b, hd, f, sd, lk)
			if head == "coif":
				for i in 7:
					var a := TAU * (i + 0.5) / 7.0
					b.dot(hd + Vector2.from_angle(a) * 4.8, 0.7, Color(1, 1, 1, 0.3))


static func _eyes(b, hd: Vector2, f: Vector2, sd: Vector2, lk: Dictionary) -> void:
	var r: float = lk.get("eye_r", 0.75)
	var col: Color = lk.get("eyes", Palette.OUTLINE)
	b.dot(hd + f * 6.0 + sd * 1.3, r, col)
	b.dot(hd + f * 6.0 - sd * 1.3, r, col)


## Hood down: the hood bunched behind the neck, the hair (or the bare scalp)
## on show, ears either side, the face in front.
static func _bare_head(b, hd: Vector2, f: Vector2, sd: Vector2, light: Vector2, lk: Dictionary, style: String, sway: float, drift: Vector2) -> void:
	var hair: Color = lk["hair"]
	var skin: Color = lk["skin"]
	var trail := sway * 0.35 + drift.y * 0.35
	# The hood, down, in folds on the shoulders behind the head.
	b.ball(hd + f * -3.6, 5.8, lk["hood"], true, light)
	b.line(hd + f * -4.0 + sd * 4.2, hd + f * -7.8 + sd * 1.2, lk["hood"].darkened(0.3), 1.1)
	b.line(hd + f * -4.0 - sd * 4.2, hd + f * -7.8 - sd * 1.2, lk["hood"].darkened(0.3), 1.1)
	match style:
		"long":  # hair down the back, swaying with the cloak
			var tip := hd + f * (-11.0 + drift.x * 0.4) + sd * trail
			b.poly(PackedVector2Array([hd + f * 0.5 + sd * 5.0, hd + f * -6.5 + sd * (4.6 + trail * 0.5), tip + sd * 1.6, tip - sd * 1.6, hd + f * -6.5 + sd * (-4.6 + trail * 0.5), hd + f * 0.5 + sd * -5.0]), hair.darkened(0.12), 1.0)
		"tied":  # a knot at the back of the head
			b.ball(hd + f * -6.2, 2.9, hair, true, light)
		"braid":
			for i in 4:
				var k := float(i)
				b.ball(hd + f * (-6.0 - 2.4 * k + drift.x * 0.3 * k / 3.0) + sd * (trail * k / 3.0), 2.1 - 0.25 * k, hair, true, light)
	if style != "long":
		for s in [-1.0, 1.0]:  # ears
			b.dot(hd + f * 1.0 + sd * (s * 5.6), 1.5, Palette.OUTLINE)
			b.dot(hd + f * 1.0 + sd * (s * 5.6), 1.0, skin.darkened(0.1))
	var top := skin if style == "none" else hair
	b.ball(hd, 5.8, top, true, light)
	b.dot(hd + f * 3.9, 2.9, skin)
	if style != "none":
		b.dot(hd + f * 2.2, 2.4, hair)  # the hairline
		b.dot(hd + f * 4.3, 2.4, skin)
	_eyes(b, hd + f * -0.6, f, sd, lk)


# --- the climber screen: the head, seen from the front ---------------------------

## The head on the climber screen's figure (menu.gd BodyView), in its frame
## (about 290 tall, centred on the waist; lit from the top-left). Drawn after
## the mantle. Hood up: the face in the hood's shadow, the hair peeking out.
## Hood down: the face lit, the hood in folds round the neck.
static func draw_front_head(b, lk: Dictionary) -> void:
	var cloak: Color = lk["cloak"]
	var skin: Color = lk["skin"]
	var hair: Color = lk["hair"]
	var style: String = lk.get("hair_style", "short")
	if lk.get("hood_up", true):
		b.poly(_p([0, -147, 13, -141, 23, -127, 27, -106, 23, -88, 12, -79, 0, -77, -12, -79, -23, -88, -27, -106, -23, -127, -13, -141]), cloak.darkened(0.18), 1.6)
		b.polygon(_p([0, -147, -13, -141, -23, -127, -27, -106, -23, -88, -12, -79, 0, -77, -5, -112]), cloak.darkened(0.0))
		b.polygon(_p([-19, -131, -9, -141, -3, -140, -13, -127]), Color(cloak.lightened(0.45), 0.5))
		b.polygon(_oval(Vector2(0, -103), Vector2(14.5, 18.0), 24), Color(0.04, 0.03, 0.05))
		if style == "long":
			b.polygon(_p([-13, -110, -10, -86, -5, -84, -8, -106]), hair.darkened(0.35))
			b.polygon(_p([13, -110, 10, -86, 5, -84, 8, -106]), hair.darkened(0.42))
		b.polygon(_oval(Vector2(0, -99), Vector2(10.5, 13.0), 24), skin.darkened(0.52))
		b.polygon(_oval(Vector2(-0.6, -94.5), Vector2(8.6, 8.0), 20), skin.darkened(0.3))
		if style != "none":
			b.polygon(_p([-12, -108, -6, -116, 4, -117, 12, -108, 5, -112, -3, -110]), hair.darkened(0.3))
		_front_eyes(b, lk, 4.2, -100.0, 0.28)
		if style == "braid":
			_front_braid(b, hair, Vector2(-15, -82))
		b.ball(Vector2(0, -77), 3.4, UI.GOLD.darkened(0.15))
		return
	# Hood down: the hood in folds round the neck and shoulders, behind the head.
	b.poly(_p([-30, -78, -24, -92, -10, -97, 10, -97, 24, -92, 30, -78, 16, -72, 0, -74, -16, -72]), cloak.darkened(0.2), 1.6)
	b.polygon(_p([-30, -78, -24, -92, -10, -97, 0, -97, 0, -74, -16, -72]), cloak.darkened(0.04))
	b.line(Vector2(-20, -88), Vector2(-8, -80), Color(cloak.darkened(0.45), 0.8), 1.6)
	b.line(Vector2(20, -88), Vector2(8, -80), Color(cloak.darkened(0.5), 0.8), 1.6)
	if style == "long":  # hair falling behind the shoulders
		b.poly(_p([-16, -116, -19, -92, -20, -74, -10, -76, 10, -76, 20, -74, 19, -92, 16, -116]), hair.darkened(0.25), 1.4)
	if style == "tied":  # a knot on top
		b.ball(Vector2(1, -126), 6.0, hair.darkened(0.06))
		b.line(Vector2(-4, -121), Vector2(6, -121), lk["tunic"].lightened(0.1), 2.0)
	# The neck and head.
	b.poly(_p([-6, -90, 6, -90, 6, -78, -6, -78]), skin.darkened(0.25), 1.2)
	for s in [-1.0, 1.0]:  # ears
		b.poly(_oval(Vector2(s * 14.0, -101), Vector2(3.0, 4.6), 12), skin.darkened(0.08 if s < 0.0 else 0.2), 1.0)
	b.poly(_oval(Vector2(0, -103), Vector2(14.0, 17.0), 28), skin.darkened(0.12), 1.6)
	b.polygon(_p([-14, -103, -12, -113, -6, -119, 0, -120, 1, -86, -6, -88, -11, -94]), skin)
	if style == "none":
		b.polygon(_oval(Vector2(-5, -113), Vector2(4.0, 2.6), 12), Color(skin.lightened(0.35), 0.5))
	else:
		# The hair on top, a fringe across the brow.
		b.poly(_p([-14.5, -101, -15, -111, -11, -119, -4, -122, 4, -122, 11, -119, 15, -111, 14.5, -101, 12, -108, 7, -111, 1, -109, -5, -111, -11, -108]), hair, 1.4)
		b.polygon(_p([4, -122, 11, -119, 15, -111, 14.5, -101, 12, -108, 7, -111]), hair.darkened(0.22))
		b.line(Vector2(-9, -117), Vector2(-3, -120), Color(hair.lightened(0.4), 0.55), 1.4)
		if style == "long":  # locks either side of the face
			b.polygon(_p([-14.5, -104, -16.5, -84, -12, -86, -12, -101]), hair)
			b.polygon(_p([14.5, -104, 16.5, -84, 12, -86, 12, -101]), hair.darkened(0.22))
	_front_eyes(b, lk, 4.6, -101.0, 0.0)
	b.line(Vector2(-7, -105.5), Vector2(-2.5, -106), Color((skin if style == "none" else hair).darkened(0.45), 0.8), 1.3)  # brows
	b.line(Vector2(2.5, -106), Vector2(7, -105.5), Color((skin if style == "none" else hair).darkened(0.45), 0.8), 1.3)
	b.line(Vector2(0.5, -99), Vector2(1.5, -95.5), Color(skin.darkened(0.3), 0.8), 1.2)  # nose
	b.line(Vector2(-3.0, -91.5), Vector2(3.0, -91.5), Color(skin.darkened(0.42), 0.9), 1.2)  # mouth
	if style == "braid":
		_front_braid(b, hair, Vector2(-12, -90))
	b.ball(Vector2(0, -77), 3.4, UI.GOLD.darkened(0.15))


## The eyes on the front figure: dark dots, or a white, an iris and a pupil.
## `shade` dims them in the hood's shadow.
static func _front_eyes(b, lk: Dictionary, x: float, y: float, shade: float) -> void:
	var col: Color = lk["eyes"]
	for s in [-1.0, 1.0]:
		var at := Vector2(s * x, y)
		if is_equal_approx(lk.get("eye_r", 0.75), 0.75):
			b.dot(at, 1.5, UI.OUTLINE)
		else:
			b.dot(at, 2.3, Color(0.92, 0.9, 0.86).darkened(shade + 0.1))
			b.dot(at + Vector2(0.2, 0.1), 1.6, col.darkened(shade))
			b.dot(at + Vector2(0.2, 0.1), 0.7, UI.OUTLINE)


## A braid over the left shoulder, down onto the chest.
static func _front_braid(b, hair: Color, from: Vector2) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		pts.append(from + Vector2(-1.0 * i, 5.2 * i))
	b.path(pts, Palette.OUTLINE, 8.6)
	for i in 8:  # plaits, leaning one way then the other
		var s := 1.0 if i % 2 == 0 else -1.0
		var w := 3.6 - 0.2 * i
		b.polygon(_oval(pts[i] + Vector2(s * 0.8, 0), Vector2(w, 3.4), 10), hair if i % 2 == 0 else hair.darkened(0.15))
		b.line(pts[i] + Vector2(-w * 0.7, -1.6 * s), pts[i] + Vector2(w * 0.7, 1.6 * s), Color(hair.darkened(0.4), 0.7), 1.0)
	var end := from + Vector2(-7.0, 38.0)
	b.line(end + Vector2(-2.5, 0), end + Vector2(2.5, 0), Color(0.3, 0.2, 0.13), 2.0)
	b.polygon(_p([end.x - 2.0, end.y + 1.0, end.x + 2.0, end.y + 1.0, end.x + 1.0, end.y + 6.0, end.x - 1.5, end.y + 6.0]), hair.darkened(0.08))


static func _p(pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in range(0, pts.size(), 2):
		out.append(Vector2(pts[i], pts[i + 1]))
	return out


static func _oval(c: Vector2, rad: Vector2, n := 16) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(c + Vector2(cos(a) * rad.x, sin(a) * rad.y))
	return pts
