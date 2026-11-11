extends RefCounted
## How the climber looks: the options a new climber chooses from (and can
## change later from the climber screen or their car on the train), their
## names and colours, all as data. The choice is saved with the profile as
## a small dictionary of option ids (profile.gd `appearance`); DEFAULTS is
## the look every climber had before there was a choice, so old saves look
## the same (an option added later loads as its default).
##
## Drawing: look(app) turns a saved appearance into the colours, sizes and
## flags the drawing code reads (precomputed once when the appearance
## changes, never per frame). Everything that draws the climber draws from
## it, in layers, so worn gear can slot in between without touching the rest:
##
##   In the tower (seen from above; player.gd and mirror.gd):
##     draw_legs   body: trousers and boots (they show as you stride)
##     draw_cloak  clothes: the cloak behind, its style, pattern and trim
##     draw_torso  body and clothes: the chest (by build), the belt, a pendant
##     [gear]      the caller's: armour on the chest, the shoulders
##     draw_head   head: a scarf or torc, the hood or hair, the face (eyes,
##                 features, beard), headgear, earrings, an eyepatch, a feather
##     [gear]      the caller's: arms, the weapon, the hands
##   On the climber screen, the book, the climber picker and the preview
##   (seen from the front; menu.gd BodyView._figure calls draw_front):
##     [gear: a backpack, a slung bow] → the cloak behind → legs and boots →
##     [gear: leg armour, boots] → tunic and belt → [gear: body armour, a
##     pack's straps] → arms → [gear: the weapon, gloves, rings] → the
##     mantle → [gear: pauldrons, the amulet] → draw_front_head → [gear: a
##     cap, helm or coif]. The gear layers are gear_look.gd's, drawn only
##     for a dressed look (GearLook.dress: "gear_on").
##
## Reusing it (the mirror image, or anything else drawn like the climber):
##   var look := Appearance.look(profile.appearance)   # once, when it changes
##   ...then each frame, in the drawing frame (x forward, y toward the weapon hand):
##   Appearance.draw_head(batch, head_pos, facing, side, light_dir, look, sway, drift)
## draw_head also reads look["hood"] (the hood's colour; player.gd darkens the
## cloak for it) and look["head"] ("hood", "bare", "coif", "cap" or "helm";
## head_kind() gives it for a look with no headgear). A whole player.gd node
## can also be drawn as a doll: set_appearance(app) on it (appearance_page.gd
## does that).

const Palette := preload("res://scripts/palette.gd")
const UI := preload("res://scripts/ui.gd")
const GearLook := preload("res://scripts/gear_look.gd")

## The option rows: [key, name]. The editor shows them a tab at a time (TABS).
static var ROWS := [
	["skin", "Skin"], ["eyes", "Eyes"], ["eye_shape", "Eye shape"], ["face", "Features"],
	["hair", "Hair"], ["hair_color", "Hair colour"], ["beard", "Beard"],
	["build", "Build"], ["tunic", "Tunic"], ["trousers", "Trousers"], ["boots", "Boots"],
	["cloak", "Cloak"], ["cloak_style", "Cloak style"], ["trim", "Trim"], ["pattern", "Pattern"], ["hood", "Hood"],
	["belt", "Belt"], ["neck", "Neck"], ["accessory", "Accessory"],
]

## The editor's tabs, in order: [id, name, the rows on it].
static var TABS := [
	["face", "Face", ["skin", "eyes", "eye_shape", "face"]],
	["hair", "Hair", ["hair", "hair_color", "beard"]],
	["body", "Body", ["build", "tunic", "trousers", "boots"]],
	["cloak", "Cloak", ["cloak", "cloak_style", "trim", "pattern", "hood"]],
	["extras", "Extras", ["belt", "neck", "accessory"]],
]

## Each option: [id, name, colour] (colour options, chosen by swatches) or
## [id, name] (the rest). A belt's fourth entry is how it's worn ("belt",
## "sash" or "rope"). The trim's "none" and the trousers' "match" are not
## colours (no trim; the tunic's colour): their swatch is drawn empty.
## The first entry is not special; DEFAULTS says which one is today's look.
static var OPTIONS := {
	"skin": [
		["porcelain", "Porcelain", Color(0.98, 0.88, 0.8)],
		["fair", "Fair", Palette.CLIMBER_SKIN],
		["warm", "Warm", Color(0.86, 0.69, 0.52)],
		["olive", "Olive", Color(0.76, 0.61, 0.43)],
		["tan", "Tan", Color(0.66, 0.48, 0.32)],
		["brown", "Brown", Color(0.5, 0.35, 0.23)],
		["deep", "Deep", Color(0.36, 0.25, 0.17)],
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
	"eye_shape": [
		["round", "Round"],
		["almond", "Almond"],
		["narrow", "Narrow"],
		["wide", "Wide-set"],
	],
	"face": [
		["clear", "Clear"],
		["freckles", "Freckles"],
		["scar", "Scar"],
		["ink", "Ink lines"],
		["paint", "War paint"],
		["mole", "Beauty spot"],
	],
	"hair": [
		["none", "Shaved"],
		["short", "Short"],
		["long", "Long"],
		["tied", "Tied up"],
		["braid", "Braid"],
		["cropped", "Cropped"],
		["curls", "Curls"],
		["tail", "Ponytail"],
		["twin", "Twin braids"],
		["crest", "Crest"],
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
	"beard": [
		["none", "Clean-shaven"],
		["stubble", "Stubble"],
		["moustache", "Moustache"],
		["short", "Short beard"],
		["full", "Full beard"],
		["braided", "Braided beard"],
	],
	"build": [
		["slight", "Slight"],
		["average", "Average"],
		["broad", "Broad"],
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
	"trousers": [
		["match", "As the tunic", Palette.CLIMBER_TUNIC],
		["brown", "Brown", Color(0.4, 0.29, 0.2)],
		["grey", "Grey", Color(0.46, 0.46, 0.48)],
		["black", "Black", Color(0.2, 0.19, 0.21)],
		["olive", "Olive", Color(0.44, 0.45, 0.28)],
		["navy", "Navy", Color(0.25, 0.3, 0.46)],
		["sand", "Sand", Color(0.68, 0.6, 0.46)],
		["oxblood", "Oxblood", Color(0.48, 0.22, 0.21)],
	],
	"boots": [
		["brown", "Brown", Palette.CLIMBER_BOOT],
		["black", "Black", Color(0.14, 0.13, 0.14)],
		["tan", "Tan", Color(0.56, 0.4, 0.25)],
		["grey", "Grey", Color(0.4, 0.4, 0.42)],
		["oxblood", "Oxblood", Color(0.4, 0.15, 0.14)],
		["pale", "Pale", Color(0.72, 0.66, 0.54)],
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
	"cloak_style": [
		["long", "Long"],
		["short", "Short"],
		["tattered", "Tattered"],
		["mantle", "Mantle"],
	],
	"trim": [
		["none", "No trim", Color(0.5, 0.5, 0.5)],
		["gold", "Gold", Color(0.88, 0.7, 0.3)],
		["silver", "Silver", Color(0.8, 0.82, 0.86)],
		["bone", "Bone", Color(0.88, 0.84, 0.72)],
		["crimson", "Crimson", Color(0.74, 0.17, 0.17)],
		["black", "Black", Color(0.1, 0.09, 0.11)],
		["teal", "Teal", Color(0.26, 0.66, 0.64)],
		["violet", "Violet", Color(0.58, 0.38, 0.8)],
	],
	"pattern": [
		["plain", "Plain"],
		["banded", "Banded hem"],
		["striped", "Striped"],
		["embroidered", "Embroidered"],
		["patched", "Patched"],
	],
	"hood": [
		["up", "Hood up"],
		["down", "Hood down"],
	],
	"belt": [
		["leather", "Leather belt", Color(0.3, 0.2, 0.13), "belt"],
		["black", "Black belt", Color(0.13, 0.12, 0.14), "belt"],
		["red", "Red sash", Color(0.68, 0.18, 0.18), "sash"],
		["blue", "Blue sash", Color(0.25, 0.38, 0.68), "sash"],
		["green", "Green sash", Color(0.27, 0.52, 0.3), "sash"],
		["gold", "Gold sash", Color(0.82, 0.64, 0.26), "sash"],
		["rope", "Rope", Color(0.7, 0.6, 0.4), "rope"],
	],
	"neck": [
		["none", "Nothing"],
		["scarf", "Scarf"],
		["pendant", "Pendant"],
		["torc", "Torc"],
	],
	"accessory": [
		["none", "None"],
		["earrings", "Earrings"],
		["eyepatch", "Eyepatch"],
		["feather", "Feather"],
	],
}

## Today's look: what every climber had before there was a choice (old
## saves load with it, an option added later with its entry here) and what
## a new climber starts from.
const DEFAULTS := {
	"name": "", "skin": "fair", "hair": "short", "hair_color": "brown", "eyes": "dark",
	"cloak": "teal", "tunic": "brown", "hood": "up",
	"eye_shape": "round", "face": "clear", "beard": "none", "build": "average",
	"trousers": "match", "boots": "brown", "cloak_style": "long", "trim": "none",
	"pattern": "plain", "belt": "leather", "neck": "none", "accessory": "none",
}

## Colours of the small things that aren't chosen by swatch: the scarf (when
## the cloak has no trim; with one, the scarf takes the trim's colour),
## metal (earrings, a pendant, a torc, buckles), a pendant's stone, the
## feather and its tip, the eyepatch, and the face's freckles, scar, ink and paint.
static var ACCENTS := {
	"scarf": Color(0.7, 0.32, 0.2),
	"metal": Color(0.88, 0.72, 0.36),
	"stone": Color(0.36, 0.72, 0.78),
	"feather": Color(0.9, 0.87, 0.78),
	"feather_tip": Color(0.22, 0.27, 0.38),
	"patch": Color(0.13, 0.1, 0.09),
	"freckles": Color(0.56, 0.34, 0.2),
	"scar": Color(0.9, 0.62, 0.58),
	"ink": Color(0.17, 0.25, 0.44),
	"paint": Color(0.66, 0.16, 0.13),
}

## The body's sizes for each build: in the tower the chest's radius, the
## shoulders' distance from the middle, how much bigger the shoulders are
## and how wide the cloak hangs; on the front figure `wx` widens the chest,
## shoulders and cloak (the hands stay where the marks expect them).
static var BUILDS := {
	"slight": {"torso_r": 7.6, "sh_y": 8.5, "sh_add": -0.5, "width": 0.9, "wx": 0.87},
	"average": {"torso_r": 8.5, "sh_y": 9.3, "sh_add": 0.0, "width": 1.0, "wx": 1.0},
	"broad": {"torso_r": 9.5, "sh_y": 10.3, "sh_add": 0.7, "width": 1.12, "wx": 1.14},
}

## Randomise: how often an option that can be plain stays plain (its first
## choice), so a rolled climber isn't always wearing everything at once.
static var RANDOM_PLAIN := {
	"face": 0.45, "beard": 0.5, "trim": 0.35, "pattern": 0.4, "neck": 0.5, "accessory": 0.55,
	"trousers": 0.3,
}

const NAME_MAX := 14  # letters in a name (it's optional)
## Names the dice offers (it never picks the one you have).
static var NAMES := [
	"Ash", "Bryn", "Cass", "Dara", "Edda", "Fen", "Gale", "Hale", "Ines", "Jory",
	"Kestrel", "Lio", "Mara", "Nell", "Oren", "Pell", "Quill", "Rhea", "Sorrel", "Tam",
	"Ulla", "Vale", "Wren", "Yara", "Zeph",
]

## The editor's words.
static var TEXT := {
	"new_title": "New climber",
	"new_sub": "Choose how you look. You can change it later.",
	"edit_title": "Appearance",
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


## A swatch that isn't a colour: no trim, or trousers like the tunic.
static func is_blank(key: String, id: String) -> bool:
	return (key == "trim" and id == "none") or (key == "trousers" and id == "match")


## The tab a row is on.
static func tab_of(key: String) -> String:
	for t in TABS:
		if key in t[2]:
			return t[0]
	return String(TABS[0][0])


## A random look (the name is kept).
static func random(keep: Dictionary, rng: RandomNumberGenerator = null) -> Dictionary:
	var out := normalized(keep)
	for key in OPTIONS:
		var list: Array = OPTIONS[key]
		var plain := float(RANDOM_PLAIN.get(key, 0.0))
		var roll := rng.randf() if rng != null else randf()
		var i := 0
		if roll >= plain:
			i = rng.randi_range(0, list.size() - 1) if rng != null else randi() % list.size()
		out[key] = list[i][0]
	return out


## A name from NAMES, not the one given.
static func random_name(not_this: String) -> String:
	var pool := NAMES.filter(func(n): return n != not_this)
	return pool[randi() % pool.size()]


## The colours, sizes and flags the drawing reads, worked out once per change.
static func look(app) -> Dictionary:
	var a := normalized(app)
	var tunic := color_of("tunic", a["tunic"])
	var bi := index_of("belt", a["belt"])
	var lk := {
		"skin": color_of("skin", a["skin"]),
		"hair": color_of("hair_color", a["hair_color"]),
		"eyes": color_of("eyes", a["eyes"]),
		"cloak": color_of("cloak", a["cloak"]),
		"tunic": tunic,
		"boot": color_of("boots", a["boots"]),
		"trousers": tunic if a["trousers"] == "match" else color_of("trousers", a["trousers"]),
		"hair_style": a["hair"],
		"hood_up": a["hood"] == "up",
		"eye_r": 0.75 if a["eyes"] == DEFAULTS["eyes"] else 0.95,  # (a colour needs a little more room)
		"eye_shape": a["eye_shape"],
		"face": a["face"],
		"beard": a["beard"],
		"build": a["build"],
		"cloak_style": a["cloak_style"],
		"trim_on": a["trim"] != "none",
		"trim": color_of("trim", a["trim"]),
		"pattern": a["pattern"],
		"belt": color_of("belt", a["belt"]),
		"belt_kind": String(OPTIONS["belt"][bi][3]) if bi >= 0 and OPTIONS["belt"][bi].size() > 3 else "belt",
		"neck": a["neck"],
		"accessory": a["accessory"],
	}
	var bd: Dictionary = BUILDS.get(a["build"], BUILDS["average"])
	for k in bd:
		lk[k] = float(bd[k])
	return lk


## The head with no helm or other headgear: the hood, or bare when it's down.
static func head_kind(lk: Dictionary) -> String:
	return "hood" if lk.get("hood_up", true) else "bare"


## The colour on top of the head (rolling and fallen, where only that shows).
static func crown(lk: Dictionary) -> Color:
	if String(lk.get("head", "hood")) != "bare":
		return lk["hood"]
	match String(lk.get("hair_style", "short")):
		"none":
			return lk["skin"]
		"cropped":
			return lk["hair"].lerp(lk["skin"], 0.4)
	return lk["hair"]


## What a pattern on the cloak is drawn in: the trim's colour, or the cloak's own, lighter (darker on a pale cloak).
static func pattern_color(lk: Dictionary) -> Color:
	if lk.get("trim_on", false):
		return lk["trim"]
	var cloak: Color = lk["cloak"]
	return cloak.lightened(0.38) if cloak.get_luminance() < 0.55 else cloak.darkened(0.32)


## The scarf's colour: the trim's, or ACCENTS's.
static func scarf_color(lk: Dictionary) -> Color:
	return lk["trim"] if lk.get("trim_on", false) else ACCENTS["scarf"]


# --- the tower: the body, seen from above ----------------------------------------
# All in the drawing frame: `f` forward, `sd` toward the weapon hand, `light`
# the light's direction; `lx` the body's offset (a lean). See the layers at the top.

static func _q(f: Vector2, sd: Vector2, x: float, y: float) -> Vector2:
	return f * x + sd * y


## Legs and boots (body), under everything: the trouser leg into each boot
## shows as you stride (`s`, -1..1 through a stride).
static func draw_legs(b, lx: Vector2, f: Vector2, sd: Vector2, light: Vector2, lk: Dictionary, s: float) -> void:
	var boot_r: float = lk.get("boot_r", 3.0)
	var apart: float = 5.2 * float(lk.get("sh_y", 9.3)) / 9.3
	var legs: Color = lk.get("trousers", lk.get("tunic", Palette.CLIMBER_TUNIC))
	for sg in [1.0, -1.0]:
		var at: Vector2 = lx + _q(f, sd, 2.0 + sg * s * 4.5, sg * apart)
		b.stroke(lx + _q(f, sd, 0.5, sg * apart * 0.7), at - f * 1.2, legs.darkened(0.25), 3.2)
		if lk.has("greave"):  # worn leg armour: a knee plate (gear_look.gd)
			b.dot(lx + _q(f, sd, 1.4 + sg * s * 2.2, sg * apart * 0.85), 1.5, lk["greave"])
		b.ball(at, boot_r, lk["boot"], true, light)
		if lk.get("studs", false):  # Hobnail Boots
			b.dot(at + f * boot_r * 0.7, 0.7, Palette.STEEL)


## The standing cloak's points in the body frame (x forward, y to the side),
## swaying (`sway`) and trailing as you move (`d`), shaped by its style and the build.
static func cloak_points(lk: Dictionary, d: Vector2, sway: float) -> Array:
	return _styled([
		Vector2(2.0, 11.0), Vector2(-3.0, 13.5), Vector2(-9.0, 12.5) + d * 0.4,
		Vector2(-13.0 + d.x, 6.5 + d.y * 0.8 + sway * 0.6), Vector2(-15.0 + d.x, d.y + sway),
		Vector2(-13.0 + d.x, -6.5 + d.y * 0.8 + sway * 0.6), Vector2(-9.0, -12.5) + d * 0.4,
		Vector2(-3.0, -13.5), Vector2(2.0, -11.0), Vector2(3.0, 0.0),
	], lk)


## The fallen climber's cloak, spread out (the same styles).
static func fallen_cloak_points(lk: Dictionary) -> Array:
	return _styled([
		Vector2(4.0, 12.0), Vector2(-6.0, 16.0), Vector2(-16.0, 11.0), Vector2(-19.0, 2.0),
		Vector2(-16.0, -10.0), Vector2(-5.0, -15.0), Vector2(4.0, -11.0), Vector2(6.0, 0.0),
	], lk)


## A cloak's points by style: long as they are, short to the hips, a mantle
## round the shoulders only, tattered longer with torn notches in the hem.
static func _styled(base: Array, lk: Dictionary) -> Array:
	var style: String = lk.get("cloak_style", "long")
	var w: float = lk.get("width", 1.0)
	var out: Array = []
	for p0 in base:
		var p: Vector2 = p0
		match style:
			"short":
				if p.x < -3.0:
					p.x = -3.0 + (p.x + 3.0) * 0.66
			"mantle":
				if p.x < -2.0:
					p.x = -2.0 + (p.x + 2.0) * 0.4
				p.y *= 1.14
			"tattered":
				if p.x < -6.0:
					p.x = -6.0 + (p.x + 6.0) * 1.12
		p.y *= w
		out.append(p)
	if style != "tattered":
		return out
	var torn: Array = []
	var n := out.size()
	for i in n:
		var p: Vector2 = out[i]
		var q: Vector2 = out[(i + 1) % n]
		torn.append(p)
		if p.x < -6.0 and q.x < -6.0:
			var m := p.lerp(q, 0.5)
			torn.append(m.lerp(Vector2(-5.0, m.y * 0.5), 0.34))
	return torn


## A cloak's points into the drawing frame, shrunk toward `mid` by `k`; smooth
## ones are rounded off (each corner cut once) so the cloth reads soft.
static func _cloth(pts: Array, f: Vector2, sd: Vector2, offset: Vector2, mid: Vector2, k: float, smooth := true) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	for i in n:
		var p: Vector2 = mid + (pts[i] - mid) * k
		if not smooth:
			out.append(offset + _q(f, sd, p.x, p.y))
			continue
		var q: Vector2 = mid + (pts[(i + 1) % n] - mid) * k
		for u in [0.25, 0.75]:
			var r: Vector2 = p.lerp(q, u)
			out.append(offset + _q(f, sd, r.x, r.y))
	return out


## The cloak (clothes): hangs from the shoulders, its hem trails and sways;
## its pattern and trim on top.
static func draw_cloak(b, lx: Vector2, f: Vector2, sd: Vector2, light: Vector2, lk: Dictionary, sway: float, d: Vector2) -> void:
	var cloak: Color = lk["cloak"]
	var style: String = lk.get("cloak_style", "long")
	var smooth := style != "tattered"
	var pts := cloak_points(lk, d, sway)
	var mid := Vector2(-5.0 + d.x * 0.5, d.y * 0.5) if style != "mantle" else Vector2(-1.0, d.y * 0.2)
	b.poly(_cloth(pts, f, sd, lx, Vector2.ZERO, 1.0, smooth), cloak.darkened(0.3), 1.2)
	b.polygon(_cloth(pts, f, sd, lx + light * 1.2, mid, 0.86, smooth), cloak)
	b.polygon(_cloth(pts, f, sd, lx + light * 3.0, mid, 0.45, smooth), Color(cloak.lightened(0.3), 0.45))
	var back: float = (pts[pts.size() / 2] as Vector2).x if style == "tattered" else (pts[4] as Vector2).x  # (the hem's furthest point)
	var w: float = lk.get("width", 1.0)
	for sgn in [-1.0, 1.0]:  # folds down the back
		b.line(lx + _q(f, sd, -3.0, sgn * 4.5 * w), lx + _q(f, sd, lerpf(-3.0, back, 0.82), sgn * 3.0 * w + d.y + sway * 0.8), cloak.darkened(0.38), 1.3)
	_tower_pattern(b, lx, f, sd, light, lk, pts, mid, back, smooth, sway, d)
	if lk.get("trim_on", false):
		b.path(_cloth(pts, f, sd, lx + light * 0.4, mid, 0.93, smooth), lk["trim"], 1.3, true)


static func _tower_pattern(b, lx: Vector2, f: Vector2, sd: Vector2, light: Vector2, lk: Dictionary, pts: Array, mid: Vector2, back: float, smooth: bool, sway: float, d: Vector2) -> void:
	var pc := pattern_color(lk)
	var w: float = lk.get("width", 1.0)
	match String(lk.get("pattern", "plain")):
		"banded":
			b.path(_cloth(pts, f, sd, lx + light * 0.8, mid, 0.74, smooth), pc, 1.7, true)
		"striped":
			for k in [-1.0, 0.0, 1.0]:
				b.line(lx + _q(f, sd, -2.5, k * 6.5 * w), lx + _q(f, sd, back * 0.9 + absf(k) * 2.2, k * 6.0 * w + d.y + sway * 0.7), pc, 1.3)
		"embroidered":
			var ring := _cloth(pts, f, sd, lx + light * 0.8, mid, 0.8, smooth)
			for i in range(0, ring.size(), 2):
				b.dot(ring[i], 0.9, pc)
			b.path(_cloth(pts, f, sd, lx + light * 0.8, mid, 0.7, smooth), Color(pc, 0.55), 0.7, true)
		"patched":
			var patch: Color = lk["cloak"].darkened(0.22) if lk["cloak"].get_luminance() > 0.3 else lk["cloak"].lightened(0.22)
			for at in [Vector2(back * 0.62, 4.5 * w), Vector2(back * 0.45, -6.0 * w)]:
				var c: Vector2 = lx + _q(f, sd, at.x + d.x * 0.4, at.y + d.y * 0.5)
				var sq := PackedVector2Array([c + _q(f, sd, -1.8, -1.6), c + _q(f, sd, 1.6, -1.9), c + _q(f, sd, 1.9, 1.6), c + _q(f, sd, -1.6, 1.8)])
				b.polygon(sq, patch)
				b.path(sq, Color(pc, 0.8), 0.6, true)


## The chest (body), by build, under the belt (clothes) and a pendant.
## Armour and the shoulders go on after it (the caller's gear layer).
static func draw_torso(b, lx: Vector2, f: Vector2, sd: Vector2, light: Vector2, lk: Dictionary) -> void:
	var r: float = lk.get("torso_r", 8.5)
	var c := lx + f * 2.0
	b.ball(c, r, lk.get("torso", lk.get("tunic", Palette.CLIMBER_TUNIC)), true, light)
	# The belt round the waist: its front shows past the head.
	var col: Color = lk.get("belt", Color(0.3, 0.2, 0.13))
	var fa := f.angle()
	match String(lk.get("belt_kind", "belt")):
		"sash":
			b.arc(c, r - 1.4, fa - 0.95, fa + 0.95, 8, col.darkened(0.3), 2.8)
			b.arc(c, r - 1.4, fa - 0.9, fa + 0.9, 8, col, 2.0)
			var knot := c + Vector2.from_angle(fa - 0.8) * (r - 1.2)
			b.dot(knot, 1.5, col)
			b.line(knot, knot + _q(f, sd, -1.5, -3.2), col.darkened(0.15), 1.4)
		"rope":
			b.arc(c, r - 1.3, fa - 0.9, fa + 0.9, 8, col.darkened(0.35), 1.6)
			b.arc(c, r - 1.3, fa - 0.9, fa + 0.9, 8, col, 1.0)
			b.dot(c + Vector2.from_angle(fa + 0.55) * (r - 1.3), 1.1, col)
		_:
			b.arc(c, r - 1.3, fa - 0.9, fa + 0.9, 8, col, 1.8)
			var metal: Color = ACCENTS["metal"] if col.get_luminance() > 0.16 else Palette.STEEL
			b.dot(c + f * (r - 1.3), 1.1, metal)
	if String(lk.get("neck", "none")) == "pendant":
		b.dot(c + f * (r - 3.4), 1.3, Palette.OUTLINE)
		b.dot(c + f * (r - 3.4), 0.9, ACCENTS["stone"])


## The climber's head in the tower, seen from above, facing `f` (`sd` is
## toward the weapon hand, `light` the light's direction, all in the drawing
## frame). `sway` and `drift` move what trails behind (the hood's peak, long
## hair, a braid, a scarf's tail) with the cloak. Reads look["head"]: "hood"
## (with hair peeking out as the style allows), "bare" (hood down: the hood
## bunched at the neck and the hair on show), "coif" (mail), "cap" or "helm".
static func draw_head(b, hd: Vector2, f: Vector2, sd: Vector2, light: Vector2, lk: Dictionary, sway: float, drift: Vector2) -> void:
	var head: String = lk.get("head", "hood")
	var style: String = lk.get("hair_style", "short")
	var hair: Color = lk["hair"]
	var hood: Color = lk["hood"]
	var trail := sway * 0.3 + drift.y * 0.3  # sideways, for what hangs behind
	_tower_neck(b, hd, f, sd, light, lk, trail, drift)
	if head == "bare":
		_bare_head(b, hd, f, sd, light, lk, style, sway, drift)
		_tower_extras(b, hd, f, sd, lk, head, trail, drift)
		return
	if head == "hood":
		# A tail or braid comes out from under the hood's peak.
		match style:
			"braid":
				for i in 3:
					var k := float(i)
					b.ball(hd + f * (-9.2 - 2.3 * k + drift.x * 0.3) + sd * (trail * (1.2 + 0.4 * k)), 2.0 - 0.25 * k, hair, true, light)
			"tied":
				b.ball(hd + f * (-9.0 + drift.x * 0.3) + sd * (trail * 1.2), 2.6, hair, true, light)
			"tail":
				b.stroke(hd - f * 7.5, hd + f * (-13.0 + drift.x * 0.4) + sd * (trail * 1.6), hair, 2.0)
			"twin":
				for sg in [-1.0, 1.0]:
					for i in 2:
						var k := float(i)
						b.ball(hd + f * (-6.4 - 2.2 * k + drift.x * 0.3) + sd * (sg * (3.6 + 0.6 * k) + trail * (0.8 + 0.4 * k)), 1.7 - 0.25 * k, hair, true, light)
	if head == "hood" or head == "coif":
		b.poly(PackedVector2Array([hd + f * -2.0 + sd * 4.2, hd + f * (-8.5 + drift.x * 0.3) + sd * trail, hd + f * -2.0 + sd * -4.2]), hood.darkened(0.15), 1.0)
	if head == "cap":
		hood = hair  # a cap shows the hair round it
		if style == "none" or style == "crest":
			hood = lk["skin"].darkened(0.08)
		elif style == "cropped":
			hood = hair.lerp(lk["skin"], 0.4)
	b.ball(hd, 6.6, hood, true, light)
	match head:
		"helm":
			b.line(hd + f * -5.5, hd + f * 5.5, hood.lightened(0.25), 1.4)  # crest
			b.line(hd + f * 4.6 + sd * -3.8, hd + f * 4.6 + sd * 3.8, Palette.OUTLINE, 1.6)  # visor slit
			b.dot(hd + f * 5.4, 1.0, hood.darkened(0.3))
		"cap":  # Leather Cap: the face, under a crown of leather with a band
			b.dot(hd + f * 4.5, 2.8, lk["skin"])
			_tower_face(b, hd, f, sd, lk, false)
			var cap: Color = lk["cap"]
			b.ball(hd + f * -1.6, 5.4, cap, true, light)
			b.arc(hd + f * -1.6, 5.2, f.angle() - 1.1, f.angle() + 1.1, 8, cap.darkened(0.45), 1.5)
		_:
			if head == "hood" and lk.get("trim_on", false):  # the hood's edge
				b.arc(hd + f * 0.6, 5.9, f.angle() - 1.25, f.angle() + 1.25, 10, lk["trim"], 1.1)
			b.dot(hd + f * 3.8, 3.9, Color(Palette.OUTLINE, 0.5))  # the hood's shadow
			if style != "none":
				var fringe := hair
				if style == "cropped":
					fringe = hair.lerp(lk["skin"], 0.4)
				b.dot(hd + f * (2.9 if style != "crest" else 2.4), 3.1 if style != "crest" else 1.8, fringe)
			b.dot(hd + f * 4.5, 2.8, lk["skin"])
			if head == "hood":
				if style == "long":
					for s in [-1.0, 1.0]:  # locks either side of the face
						b.dot(hd + f * 3.6 + sd * (s * 3.3), 1.5, hair)
				elif style == "curls":
					for s in [-1.0, 1.0]:
						b.dot(hd + f * 3.0 + sd * (s * 3.4), 1.2, hair)
						b.dot(hd + f * 4.4 + sd * (s * 3.6), 0.9, hair.darkened(0.15))
			_tower_face(b, hd, f, sd, lk, false)
			if head == "coif":
				for i in 7:
					var a := TAU * (i + 0.5) / 7.0
					b.dot(hd + Vector2.from_angle(a) * 4.8, 0.7, Color(1, 1, 1, 0.3))
	_tower_extras(b, hd, f, sd, lk, head, trail, drift)


## What's at the neck, under the head: a scarf (round the neck, its tail
## trailing behind) or a torc (a ring of metal in front).
static func _tower_neck(b, hd: Vector2, f: Vector2, sd: Vector2, light: Vector2, lk: Dictionary, trail: float, drift: Vector2) -> void:
	match String(lk.get("neck", "none")):
		"scarf":
			var col := scarf_color(lk)
			b.stroke(hd + f * -4.0 + sd * 3.0, hd + f * (-12.0 + drift.x * 0.4) + sd * (4.5 + trail * 1.5), col.darkened(0.12), 2.4)
			b.ball(hd + f * 0.6, 8.4, col, true, light)
		"torc":
			b.arc(hd + f * 0.6, 8.6, f.angle() - 0.95, f.angle() + 0.95, 10, Palette.OUTLINE, 2.6)
			b.arc(hd + f * 0.6, 8.6, f.angle() - 0.9, f.angle() + 0.9, 10, ACCENTS["metal"], 1.4)


## The face in the tower: the beard at the chin, the features, the eyes (by
## shape) and an eyepatch. `bare`: the hood is down (the face sits further back).
static func _tower_face(b, hd: Vector2, f: Vector2, sd: Vector2, lk: Dictionary, bare: bool) -> void:
	var c := hd + f * (-0.6 if bare else 0.0)
	var fa := f.angle()
	var hair: Color = lk["hair"]
	# The beard: a crescent of hair at the chin, in front of the eyes.
	match String(lk.get("beard", "none")):
		"stubble":
			b.arc(c, 7.0, fa - 0.75, fa + 0.75, 8, Color(hair.lerp(lk["skin"], 0.35), 0.8), 1.4)
		"moustache":
			b.line(c + _q(f, sd, 7.0, 1.9), c + _q(f, sd, 7.0, -1.9), hair, 1.1)
		"short":
			b.arc(c, 7.1, fa - 0.85, fa + 0.85, 8, hair, 2.0)
		"full":
			b.arc(c, 7.2, fa - 1.05, fa + 1.05, 10, hair.darkened(0.15), 3.0)
			b.arc(c, 7.2, fa - 0.95, fa + 0.95, 10, hair, 2.2)
			b.dot(c + f * 8.4, 1.6, hair)
		"braided":
			b.arc(c, 7.1, fa - 0.85, fa + 0.85, 8, hair, 2.0)
			b.dot(c + f * 8.8, 1.2, hair)
			b.dot(c + f * 10.2, 0.9, hair.darkened(0.12))
	# Features.
	match String(lk.get("face", "clear")):
		"freckles":
			for p in [Vector2(5.0, 2.3), Vector2(5.4, -2.4), Vector2(4.4, 3.0), Vector2(4.6, -3.0)]:
				b.dot(c + _q(f, sd, p.x, p.y), 0.35, ACCENTS["freckles"])
		"scar":
			b.line(c + _q(f, sd, 7.0, 2.6), c + _q(f, sd, 4.2, 0.4), ACCENTS["scar"], 0.6)
		"ink":
			for s in [-1.0, 1.0]:
				b.line(c + _q(f, sd, 4.0, s * 2.6), c + _q(f, sd, 6.4, s * 2.8), ACCENTS["ink"], 0.6)
		"paint":
			b.line(c + _q(f, sd, 6.0, 2.9), c + _q(f, sd, 6.0, -2.9), ACCENTS["paint"], 1.5)
		"mole":
			b.dot(c + _q(f, sd, 5.0, -2.4), 0.45, Palette.OUTLINE)
	_eyes(b, c, f, sd, lk)


static func _eyes(b, hd: Vector2, f: Vector2, sd: Vector2, lk: Dictionary) -> void:
	var r: float = lk.get("eye_r", 0.75)
	var col: Color = lk.get("eyes", Palette.OUTLINE)
	var shape: String = lk.get("eye_shape", "round")
	var gap := 1.85 if shape == "wide" else 1.3
	var patch := String(lk.get("accessory", "none")) == "eyepatch"
	for s in [1.0, -1.0]:
		var at: Vector2 = hd + f * 6.0 + sd * (s * gap)
		if patch and s > 0.0:
			b.dot(at, 1.2, ACCENTS["patch"])
			continue
		match shape:
			"narrow":
				b.line(at - sd * 0.8, at + sd * 0.8, col, 0.6)
			"almond":
				b.line(at - sd * 0.6, at + sd * 0.6, col, r * 1.3)
				b.dot(at, r * 0.8, col)
			_:
				b.dot(at, r, col)
	if patch:  # its strap, over the head
		b.line(hd + f * 6.6 - sd * 0.6, hd + f * 1.0 + sd * 6.2, ACCENTS["patch"], 0.6)


## Earrings and a feather, over the head.
static func _tower_extras(b, hd: Vector2, f: Vector2, sd: Vector2, lk: Dictionary, head: String, trail: float, drift: Vector2) -> void:
	match String(lk.get("accessory", "none")):
		"earrings":
			if head == "helm":
				return
			for s in [-1.0, 1.0]:
				var at: Vector2 = hd + (f * 0.6 + sd * (s * 6.1) if head == "bare" else f * 3.6 + sd * (s * 3.7))
				b.dot(at, 0.9, ACCENTS["metal"])
		"feather":
			var from := hd + f * -1.5 + sd * 4.6
			var to := hd + f * (-9.5 + drift.x * 0.3) + sd * (7.2 + trail)
			if head == "bare":
				from = hd + f * 0.6 + sd * 5.6
				to = hd + f * (-7.0 + drift.x * 0.3) + sd * (8.0 + trail)
			elif head == "helm":  # a plume along the crest
				from = hd + f * -4.0
				to = hd + f * (-11.5 + drift.x * 0.3) + sd * trail
			b.stroke(from, to, ACCENTS["feather"], 1.5)
			b.dot(to, 1.1, ACCENTS["feather_tip"])


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
	if lk.get("trim_on", false):
		b.arc(hd + f * -3.6, 6.4, f.angle() + 2.0, f.angle() + TAU - 2.0, 10, lk["trim"], 1.1)
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
		"tail":  # a tail swinging behind
			b.stroke(hd + f * -4.5, hd + f * (-12.5 + drift.x * 0.4) + sd * (trail * 1.4), hair, 2.2)
			b.dot(hd + f * -5.4, 1.3, lk["tunic"].lightened(0.1))
		"twin":
			for sg in [-1.0, 1.0]:
				for i in 3:
					var k := float(i)
					b.ball(hd + f * (-4.0 - 2.3 * k + drift.x * 0.3 * k / 2.0) + sd * (sg * (3.4 + 0.5 * k) + trail * k / 2.0), 1.8 - 0.25 * k, hair, true, light)
	if style != "long":
		for s in [-1.0, 1.0]:  # ears
			b.dot(hd + f * 1.0 + sd * (s * 5.6), 1.5, Palette.OUTLINE)
			b.dot(hd + f * 1.0 + sd * (s * 5.6), 1.0, skin.darkened(0.1))
	var top := hair
	match style:
		"none", "crest":
			top = skin
		"cropped":
			top = hair.lerp(skin, 0.4)
	b.ball(hd, 5.8, top, true, light)
	if style == "curls":
		for i in 8:
			var a := f.angle() + PI + (float(i) - 3.5) * 0.62
			b.dot(hd + Vector2.from_angle(a) * 5.0, 1.6, hair.darkened(0.12) if i % 2 == 0 else hair)
	b.dot(hd + f * 3.9, 2.9, skin)
	match style:
		"none":
			pass
		"crest":  # a strip of hair front to back, the sides shaved
			b.line(hd + f * 3.2, hd + f * -6.0, hair.darkened(0.2), 3.0)
			b.line(hd + f * 3.0, hd + f * -5.6, hair, 1.8)
		_:
			b.dot(hd + f * 2.2, 2.4, top)  # the hairline
			b.dot(hd + f * 4.3, 2.4, skin)
	_tower_face(b, hd, f, sd, lk, true)


## Rolling, curled in the cloak: its trim and pattern show on the ball.
static func draw_rolled_cloak(b, lk: Dictionary, fwd: Vector2, across: Vector2, spin: float, light: Vector2) -> void:
	var cloak: Color = lk["cloak"]
	var r := 12.0 * float({"short": 0.94, "mantle": 0.88}.get(lk.get("cloak_style", "long"), 1.0)) * sqrt(float(lk.get("width", 1.0)))
	b.ball(Vector2.ZERO, r, cloak, true, light)
	var pc := pattern_color(lk)
	var pattern: String = lk.get("pattern", "plain")
	# Folds of cloak sweep over the back as it turns.
	for k in 2:
		var x: float = cos(spin + k * PI) * r * 0.66
		var h := sqrt(maxf(0.0, r * r - x * x)) * 0.8
		var col := cloak.darkened(0.3) if k == 0 else cloak.lightened(0.15)
		if pattern == "striped" or pattern == "banded":
			col = pc
		b.line(fwd * x + across * h, fwd * x - across * h, col, 2.2)
	if pattern == "embroidered" or pattern == "patched":
		for i in 5:
			b.dot(Vector2.from_angle(spin + i * TAU / 5.0) * r * 0.7, 0.9 if pattern == "embroidered" else 1.6, pc)
	if lk.get("trim_on", false):
		b.arc(Vector2.ZERO, r - 1.0, 0.0, TAU, 20, lk["trim"], 1.3)
	if lk.get("cloak_style", "long") == "tattered":
		for i in 4:
			var a := spin + i * TAU / 4.0
			b.line(Vector2.from_angle(a) * (r - 0.5), Vector2.from_angle(a) * (r + 2.2), cloak.darkened(0.25), 1.6)


## Fallen, face down: the legs and boots out from under the cloak (body),
## the cloak spread (its style, pattern and trim).
static func draw_fallen_body(b, f: Vector2, sd: Vector2, light: Vector2, lk: Dictionary) -> void:
	var legs: Color = lk.get("trousers", lk.get("tunic", Palette.CLIMBER_TUNIC))
	for sg in [1.0, -1.0]:
		var foot := _q(f, sd, -19.0 if lk.get("cloak_style", "long") != "tattered" else -21.0, sg * 4.2)
		b.stroke(_q(f, sd, -6.0, sg * 3.6), foot, legs.darkened(0.2), 3.4)
		b.ball(foot, float(lk.get("boot_r", 3.0)), lk["boot"], true, light)
	var cloak: Color = lk["cloak"]
	var smooth: bool = lk.get("cloak_style", "long") != "tattered"
	var shape := fallen_cloak_points(lk)
	b.poly(_cloth(shape, f, sd, Vector2.ZERO, Vector2.ZERO, 1.0, smooth), cloak.darkened(0.25), 1.2)
	b.polygon(_cloth(shape, f, sd, light * 1.5, Vector2(-6.0, 0.0), 0.8, smooth), cloak)
	var pc := pattern_color(lk)
	match String(lk.get("pattern", "plain")):
		"banded":
			b.path(_cloth(shape, f, sd, light * 1.0, Vector2(-6.0, 0.0), 0.66, smooth), pc, 1.7, true)
		"striped":
			for k in [-1.0, 0.0, 1.0]:
				b.line(_q(f, sd, -3.0, k * 7.0), _q(f, sd, -15.0 + absf(k) * 2.0, k * 7.5), pc, 1.3)
		"embroidered":
			var ring := _cloth(shape, f, sd, light * 1.0, Vector2(-6.0, 0.0), 0.72, smooth)
			for i in range(0, ring.size(), 2):
				b.dot(ring[i], 0.9, pc)
		"patched":
			b.dot(_q(f, sd, -12.0, 5.0), 2.0, cloak.darkened(0.22))
			b.dot(_q(f, sd, -9.0, -7.0), 1.7, cloak.lightened(0.15))
	if lk.get("trim_on", false):
		b.path(_cloth(shape, f, sd, light * 0.6, Vector2(-6.0, 0.0), 0.92, smooth), lk["trim"], 1.3, true)


# --- the climber screen: the figure, seen from the front -------------------------
# The figure's frame is about 290 tall, centred on the waist, lit from the
# top-left (the left side of each piece paler, the right darker). Its marks
# sit at fixed spots (menu.gd BodyView.SPOTS), so the build widens the chest
# and shoulders but leaves the head and hands where they are.

## The whole front figure, in layers (see the top of the file).
static func draw_front(b, lk: Dictionary) -> void:
	var gear: bool = lk.get("gear_on", false)  # (dressed in worn gear: gear_look.gd)
	if gear:
		GearLook.front_behind(b, lk)  # gear: a backpack, a slung bow
	_front_cloak(b, lk)  # clothes: the cloak behind
	_front_legs(b, lk)  # body and clothes: legs in their trousers, boots
	if gear:
		GearLook.front_legs(b, lk)  # gear: leg armour, boots
	_front_tunic(b, lk)  # clothes: the tunic, its skirt, the belt
	if gear:
		GearLook.front_chest(b, lk)  # gear: body armour, a pack's straps
	_front_arms(b, lk)  # body: arms in their sleeves, hands
	if gear:
		GearLook.front_arms(b, lk)  # gear: the weapon in hand, gloves, rings
	_front_mantle(b, lk)  # clothes: the cloak's mantle over the shoulders
	if gear:
		GearLook.front_shoulders(b, lk)  # gear: pauldrons, the amulet
	draw_front_head(b, lk)  # head: the hood or hair, the face, what's at the neck
	if gear:
		GearLook.front_head(b, lk)  # gear: a cap, a helm or a mail coif


static func _sx(pts: PackedVector2Array, k: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(Vector2(p.x * k, p.y))
	return out


static func _shift(pts: PackedVector2Array, by: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(p + by)
	return out


## The back cloak's outline by style (none for a mantle: it's all at the shoulders).
static func _front_cloak_outline(style: String) -> PackedVector2Array:
	match style:
		"short":
			return _p([-30, -68, 30, -68, 46, -20, 52, 22, 54, 40, 40, 46, 22, 42, 0, 45, -22, 42, -40, 46, -54, 40, -52, 22, -46, -20])
		"tattered":
			return _p([-30, -68, 30, -68, 46, -20, 56, 40, 66, 96, 59, 106, 52, 93, 44, 112, 35, 98, 25, 114, 14, 100, 4, 115, -6, 100, -16, 113, -26, 98, -36, 111, -44, 94, -53, 108, -60, 94, -67, 101, -56, 40, -46, -20])
		"mantle":
			return PackedVector2Array()
	return _p([-30, -68, 30, -68, 46, -20, 56, 40, 64, 100, 48, 108, 30, 104, 14, 110, 0, 104, -14, 110, -30, 104, -48, 108, -64, 100, -56, 40, -46, -20])


## Fills `region` clipped to `outline`.
static func _fill_in(b, outline: PackedVector2Array, region: PackedVector2Array, col: Color) -> void:
	for piece in Geometry2D.intersect_polygons(outline, region):
		b.polygon(piece, col)


## The cloak behind, from the shoulders down (to below the knees, or the
## hips when short; torn when tattered); its pattern and trim.
static func _front_cloak(b, lk: Dictionary) -> void:
	var style: String = lk.get("cloak_style", "long")
	var out := _front_cloak_outline(style)
	if out.is_empty():
		return
	var cloak: Color = lk["cloak"]
	var wc := 1.0 + (float(lk.get("wx", 1.0)) - 1.0) * 0.7
	out = _sx(out, wc)
	b.poly(out, cloak.darkened(0.22), 1.6)
	_fill_in(b, out, _p([-90, -80, -6, -80, -10, 140, -90, 140]), cloak.darkened(0.04))
	_fill_in(b, out, _sx(_p([38, -36, 90, -36, 90, 140, 46, 140, 44, 40]), wc), cloak.darkened(0.4))
	_fill_in(b, out, _p([-21, 10, 21, 10, 27, 140, -27, 140]), cloak.darkened(0.58))
	var short := style == "short"
	var folds := [[-40, 0, -46, 38], [-27, 10, -30, 40], [32, 6, 36, 38], [46, 8, 50, 38]] if short else [[-40, 18, -52, 100], [-27, 30, -33, 104], [32, 24, 40, 100], [46, 30, 56, 98]]
	for fl in folds:
		b.line(Vector2(fl[0] * wc, fl[1]), Vector2(fl[2] * wc, fl[3]), Color(cloak.darkened(0.5), 0.75), 1.8)
	if short:
		b.line(Vector2(-50 * wc, 8), Vector2(-52 * wc, 34), Color(cloak.lightened(0.3), 0.35), 1.4)
	else:
		b.line(Vector2(-58 * wc, 50), Vector2(-62 * wc, 98), Color(cloak.lightened(0.3), 0.35), 1.4)
	_front_pattern(b, lk, out, short)
	if lk.get("trim_on", false):
		b.path(out, lk["trim"], 2.4, true)


## The cloak's pattern on the back cloak: a band along the hem, stripes,
## embroidery along the hem, or patches.
static func _front_pattern(b, lk: Dictionary, out: PackedVector2Array, short: bool) -> void:
	var pc := pattern_color(lk)
	var cloak: Color = lk["cloak"]
	match String(lk.get("pattern", "plain")):
		"banded":
			for strip in Geometry2D.clip_polygons(out, _shift(out, Vector2(0, -12))):
				_fill_in(b, strip, _shift(out, Vector2(0, -5)), pc)
		"striped":
			var x := -66.0
			while x <= 66.0:
				_fill_in(b, out, _p([x - 2.2, -60, x + 2.2, -60, x + 3.4 + x * 0.12, 130, x - 1.0 + x * 0.12, 130]), Color(pc, 0.85))
				x += 13.0
		"embroidered":
			var hem := _hem_line(out, -8.0)
			b.path(hem, Color(pc, 0.9), 1.6)
			for i in range(0, hem.size()):
				b.dot(hem[i] + Vector2(0, -4.5), 1.6, pc)
		"patched":
			var spots := [[-48, 18 if short else 64], [44, 2 if short else 30]]
			for i in spots.size():
				var c := Vector2(spots[i][0], spots[i][1])
				var sq := _p([c.x - 7, c.y - 6, c.x + 6, c.y - 7, c.x + 7, c.y + 6, c.x - 6, c.y + 7])
				_fill_in(b, out, sq, cloak.darkened(0.2) if i == 0 else cloak.lightened(0.14))
				for k in 4:
					var p0 := sq[k]
					var p1 := sq[(k + 1) % 4]
					for u in [0.2, 0.5, 0.8]:
						var m := p0.lerp(p1, u)
						var n := (p1 - p0).orthogonal().normalized()
						b.line(m - n * 1.4, m + n * 1.4, Color(pc, 0.85), 1.0)


## The hem (the lowest points of an outline, left to right), raised by `up`.
static func _hem_line(out: PackedVector2Array, up: float) -> PackedVector2Array:
	var lowest := -INF
	for p in out:
		lowest = maxf(lowest, p.y)
	var hem: Array = []
	for p in out:
		if p.y > lowest - 20.0:
			hem.append(p + Vector2(0, up))
	hem.sort_custom(func(a, c): return a.x < c.x)
	return PackedVector2Array(hem)


## Legs in their trousers, and boots.
static func _front_legs(b, lk: Dictionary) -> void:
	var legs: Color = lk.get("trousers", lk["tunic"])
	var boot: Color = lk["boot"]
	var k := 1.0 + (float(lk.get("wx", 1.0)) - 1.0) * 0.6
	for sg in [-1.0, 1.0]:
		var shade := 0.22 if sg < 0.0 else 0.38
		b.poly(_sx(_p([sg * 3, 10, sg * 17, 10, sg * 16, 96, sg * 4, 96]), k), legs.darkened(shade), 1.4)
		b.poly(_sx(_p([sg * 2.5, 92, sg * 17.5, 92, sg * 18, 110, sg * 22, 124, sg * 1, 124, sg * 2, 110]), k), boot if sg < 0.0 else boot.darkened(0.25), 1.4)
		b.rect(Rect2(Vector2(minf(sg * 2.5, sg * 17.5) * k, 92), Vector2(15 * k, 4)), boot.lightened(0.22))
		b.line(Vector2(sg * 4 * k, 121), Vector2(sg * 15 * k, 121), Color(boot.lightened(0.3), 0.5), 1.2)


## The tunic, a skirt below the belt, and the belt (a leather belt and
## buckle, a sash knotted at the hip, or a rope).
static func _front_tunic(b, lk: Dictionary) -> void:
	var tunic: Color = lk["tunic"]
	var wx: float = lk.get("wx", 1.0)
	b.poly(_sx(_p([-27, -66, 27, -66, 24, -24, 21, 16, -21, 16, -24, -24]), wx), tunic.darkened(0.14), 1.6)
	b.polygon(_sx(_p([-27, -66, 1, -66, 1, 16, -21, 16, -24, -24]), wx), tunic)
	b.polygon(_p([-7, -66, 7, -66, 0, -40]), tunic.darkened(0.42))
	b.poly(_sx(_p([-21, 14, 21, 14, 26, 38, -26, 38]), wx), tunic.darkened(0.16), 1.4)
	b.polygon(_sx(_p([-21, 14, 0, 14, 0, 38, -26, 38]), wx), tunic.darkened(0.04))
	var col: Color = lk.get("belt", Color(0.3, 0.2, 0.13))
	var hw := 22.0 * wx
	match String(lk.get("belt_kind", "belt")):
		"sash":
			b.poly(_p([-hw - 1, 3, hw + 1, 4, hw + 1, 17, -hw - 1, 16]), col, 1.4)
			b.polygon(_p([-hw - 1, 3, hw + 1, 4, hw + 1, 7, -hw - 1, 6.5]), col.lightened(0.18))
			for i in 3:
				b.line(Vector2(-hw + 6 + i * 13, 6), Vector2(-hw + 12 + i * 13, 15), Color(col.darkened(0.35), 0.6), 1.0)
			b.poly(_p([-hw + 2, 13, -hw + 9, 13, -hw + 7, 40, -hw + 1, 38]), col.darkened(0.12), 1.2)  # its ends, hanging
			b.poly(_p([-hw + 8, 13, -hw + 14, 14, -hw + 15, 34, -hw + 9, 35]), col.darkened(0.25), 1.2)
			b.ball(Vector2(-hw + 8, 11), 4.4, col)  # the knot
		"rope":
			for y in [8.0, 12.5]:
				b.line(Vector2(-hw, y), Vector2(hw, y), UI.OUTLINE, 4.2)
				b.line(Vector2(-hw, y), Vector2(hw, y), col, 2.6)
				var x := -hw + 2.0
				while x < hw:
					b.line(Vector2(x, y - 1.2), Vector2(x + 1.6, y + 1.2), Color(col.darkened(0.4), 0.8), 0.8)
					x += 4.0
			b.ball(Vector2(-9, 10), 3.4, col)  # the knot
			for dx in [-11.0, -7.0]:  # its ends
				b.stroke(Vector2(dx, 12), Vector2(dx - 2.0, 30), col, 2.0)
				b.dot(Vector2(dx - 2.0, 31), 2.0, col.darkened(0.2))
		_:
			b.rect(Rect2(-hw - 1.4, 4.6, hw * 2.0 + 2.8, 11.8), UI.OUTLINE)
			b.rect(Rect2(-hw, 6, hw * 2.0, 9), col)
			b.rect(Rect2(-hw, 6, hw * 2.0, 2.4), col.lightened(0.2))
			var metal: Color = UI.GOLD.darkened(0.2) if col.get_luminance() > 0.16 else Palette.STEEL
			b.rect(Rect2(-5.4, 3.6, 10.8, 13.8), UI.OUTLINE)
			b.rect(Rect2(-4, 5, 8, 11), metal)
			b.rect(Rect2(-1.6, 7.4, 3.2, 6.2), col)


## Arms in their sleeves, hands out of the cloak (at the hand mark's spot).
static func _front_arms(b, lk: Dictionary) -> void:
	var tunic: Color = lk["tunic"]
	var skin: Color = lk["skin"]
	var wx: float = lk.get("wx", 1.0)
	var thick := 1.0 + (wx - 1.0) * 0.6
	for sg in [-1.0, 1.0]:
		var sh := Vector2(sg * 28 * wx, -60)
		var el := Vector2(sg * (40 + (wx - 1.0) * 26.0), -24)
		var wr := Vector2(sg * 48, 1)
		var col := tunic if sg < 0.0 else tunic.darkened(0.2)
		b.stroke(sh, el, col, 13.0 * thick)
		b.stroke(el, wr, col, 11.0 * thick)
		b.line(sh + Vector2(-3.5, 1), el + Vector2(-4, 0), Color(col.lightened(0.25), 0.6), 2.0)
		b.stroke(wr - (wr - el).normalized() * 2.0, wr + (wr - el).normalized() * 1.5, tunic.darkened(0.45), 12.0 * thick)
		b.ball(Vector2(sg * 50, 9), 6.8, skin if sg < 0.0 else skin.darkened(0.14))


## The cloak's mantle over the shoulders; as a Mantle (no cloak behind) a
## short cape, open at the front, over the upper arms. Its pattern and trim.
static func _front_mantle(b, lk: Dictionary) -> void:
	var cloak: Color = lk["cloak"]
	var wx: float = lk.get("wx", 1.0)
	var pc := pattern_color(lk)
	var pattern: String = lk.get("pattern", "plain")
	var edges: Array = []  # outlines, for the trim
	var hems: Array = []  # lower edges, for a band or embroidery
	if lk.get("cloak_style", "long") == "mantle":
		for sg in [-1.0, 1.0]:
			var half := _sx(_p([-2, -80, -14, -80, -38, -66, -50, -38, -48, -20, -34, -14, -20, -22, -10, -40, -4, -62]), sg * wx)
			b.poly(half, cloak.darkened(0.14) if sg < 0.0 else cloak.darkened(0.3), 1.6)
			if sg < 0.0:
				b.polygon(_sx(_p([-14, -78, -36, -65, -46, -40, -40, -34, -26, -60]), wx), cloak.lightened(0.06))
				b.polygon(_sx(_p([-37, -60, -28, -71, -14, -77, -24, -66]), wx), Color(cloak.lightened(0.45), 0.5))
			b.line(Vector2(sg * -30 * wx, -58), Vector2(sg * -40 * wx, -22), Color(cloak.darkened(0.5), 0.7), 1.6)
			edges.append(half)
			hems.append(_sx(_p([-48, -22, -34, -16, -20, -24, -10, -41]), sg * wx))
			if pattern == "striped":
				for x in [-42.0, -30.0, -18.0]:
					_fill_in(b, half, _sx(_p([x - 2, -84, x + 2, -84, x + 2, -10, x - 2, -10]), sg * wx), Color(pc, 0.85))
			elif pattern == "patched" and sg < 0.0:
				var sq := _sx(_p([-40, -50, -30, -52, -29, -42, -39, -40]), wx)
				b.polygon(sq, cloak.darkened(0.22))
				b.path(sq, Color(pc, 0.85), 1.0, true)
	else:
		var m := _sx(_p([-42, -50, -34, -68, -14, -80, 14, -80, 34, -68, 42, -50, 30, -42, 14, -50, 0, -46, -14, -50, -30, -42]), wx)
		b.poly(m, cloak.darkened(0.14), 1.6)
		b.polygon(_sx(_p([-42, -50, -34, -68, -14, -80, 0, -80, 0, -46, -14, -50, -30, -42]), wx), cloak.lightened(0.06))
		b.polygon(_sx(_p([-37, -60, -28, -71, -14, -77, -24, -66]), wx), Color(cloak.lightened(0.45), 0.5))
		edges.append(m)
		hems.append(_sx(_p([-42, -50, -30, -42, -14, -50, 0, -46, 14, -50, 30, -42, 42, -50]), wx))
		if pattern == "striped":
			for x in [-30.0, -18.0, -6.0, 6.0, 18.0, 30.0]:
				_fill_in(b, m, _sx(_p([x - 1.8, -84, x + 1.8, -84, x + 1.8, -40, x - 1.8, -40]), wx), Color(pc, 0.8))
	for hem in hems:
		match pattern:
			"banded":
				b.path(_shift(hem, Vector2(0, -4.5)), pc, 3.2)
			"embroidered":
				for p in _shift(hem, Vector2(0, -4.5)):
					b.dot(p, 1.6, pc)
	if lk.get("trim_on", false):
		for e in edges:
			b.path(e, lk["trim"], 2.2, true)


## The head on the climber screen's figure, in its frame (about 290 tall,
## centred on the waist; lit from the top-left). Drawn after the mantle.
## Hood up: the face in the hood's shadow, the hair peeking out. Hood down:
## the face lit, the hood in folds round the neck. Then what's at the neck.
static func draw_front_head(b, lk: Dictionary) -> void:
	var cloak: Color = lk.get("hood_front", lk["cloak"])  # (a worn hood or coif: its own colour)
	var skin: Color = lk["skin"]
	var hair: Color = lk["hair"]
	var style: String = lk.get("hair_style", "short")
	var trim_on: bool = lk.get("trim_on", false)
	if lk.get("hood_up", true):
		if style == "tied":  # a knot pushing up the hood behind
			b.ball(Vector2(7, -143), 7.0, cloak.darkened(0.28))
		if style == "tail":  # a tail out of the hood, over the shoulder
			b.poly(_p([13, -92, 19, -88, 22, -72, 19, -60, 15, -64, 16, -78]), hair.darkened(0.3), 1.2)
		b.poly(_p([0, -147, 13, -141, 23, -127, 27, -106, 23, -88, 12, -79, 0, -77, -12, -79, -23, -88, -27, -106, -23, -127, -13, -141]), cloak.darkened(0.18), 1.6)
		b.polygon(_p([0, -147, -13, -141, -23, -127, -27, -106, -23, -88, -12, -79, 0, -77, -5, -112]), cloak.darkened(0.0))
		b.polygon(_p([-19, -131, -9, -141, -3, -140, -13, -127]), Color(cloak.lightened(0.45), 0.5))
		b.polygon(_oval(Vector2(0, -103), Vector2(14.5, 18.0), 24), Color(0.04, 0.03, 0.05))
		if trim_on:
			b.path(_oval(Vector2(0, -103), Vector2(15.6, 19.2), 24), lk["trim"], 2.2, true)
		if style == "long":
			b.polygon(_p([-13, -110, -10, -86, -5, -84, -8, -106]), hair.darkened(0.35))
			b.polygon(_p([13, -110, 10, -86, 5, -84, 8, -106]), hair.darkened(0.42))
		b.polygon(_oval(Vector2(0, -99), Vector2(10.5, 13.0), 24), skin.darkened(0.52))
		b.polygon(_oval(Vector2(-0.6, -94.5), Vector2(8.6, 8.0), 20), skin.darkened(0.3))
		_front_features(b, lk, 0.32)
		_front_beard(b, lk, 0.32)
		match style:
			"none":
				pass
			"cropped":
				b.polygon(_p([-11, -109, -5, -114, 4, -115, 11, -109, 4, -111.5, -4, -111]), hair.lerp(skin, 0.4).darkened(0.32))
			"curls":
				for i in 5:
					b.dot(Vector2(-9 + i * 4.5, -110.5 + absf(i - 2) * 1.2), 2.8, hair.darkened(0.3 if i % 2 == 0 else 0.4))
			"crest":
				b.polygon(_p([-3, -109, 0, -117, 3, -109]), hair.darkened(0.3))
			_:
				b.polygon(_p([-12, -108, -6, -116, 4, -117, 12, -108, 5, -112, -3, -110]), hair.darkened(0.3))
		_front_eyes(b, lk, 4.2, -100.0, 0.28)
		if style == "braid" or style == "twin":
			_front_braid(b, hair, Vector2(-15, -82))
		if style == "twin":
			_front_braid(b, hair.darkened(0.12), Vector2(15, -82), -1.0)
		_front_head_extras(b, lk, true)
		return
	# Hood down: the hood in folds round the neck and shoulders, behind the head.
	b.poly(_p([-30, -78, -24, -92, -10, -97, 10, -97, 24, -92, 30, -78, 16, -72, 0, -74, -16, -72]), cloak.darkened(0.2), 1.6)
	b.polygon(_p([-30, -78, -24, -92, -10, -97, 0, -97, 0, -74, -16, -72]), cloak.darkened(0.04))
	b.line(Vector2(-20, -88), Vector2(-8, -80), Color(cloak.darkened(0.45), 0.8), 1.6)
	b.line(Vector2(20, -88), Vector2(8, -80), Color(cloak.darkened(0.5), 0.8), 1.6)
	if trim_on:
		b.path(_p([-30, -78, -24, -92, -10, -97, 10, -97, 24, -92, 30, -78]), lk["trim"], 2.2)
	match style:
		"long":  # hair falling behind the shoulders
			b.poly(_p([-16, -116, -19, -92, -20, -74, -10, -76, 10, -76, 20, -74, 19, -92, 16, -116]), hair.darkened(0.25), 1.4)
		"tied":  # a knot on top
			b.ball(Vector2(1, -126), 6.0, hair.darkened(0.06))
			b.line(Vector2(-4, -121), Vector2(6, -121), lk["tunic"].lightened(0.1), 2.0)
		"tail":  # a tail behind, swung over to one side
			b.poly(_p([8, -120, 17, -114, 22, -98, 23, -80, 19, -68, 15, -72, 16, -90, 12, -108]), hair.darkened(0.2), 1.4)
			b.line(Vector2(13, -113), Vector2(19, -110), lk["tunic"].lightened(0.1), 2.0)
	# The neck and head.
	b.poly(_p([-6, -90, 6, -90, 6, -78, -6, -78]), skin.darkened(0.25), 1.2)
	if style != "long":
		for s in [-1.0, 1.0]:  # ears
			b.poly(_oval(Vector2(s * 14.0, -101), Vector2(3.0, 4.6), 12), skin.darkened(0.08 if s < 0.0 else 0.2), 1.0)
	if style == "curls":  # curls round the head, behind it
		for i in 11:
			var a := PI + float(i) * PI / 10.0
			b.ball(Vector2(0, -106) + Vector2(cos(a) * 15.5, sin(a) * 17.0), 4.0, hair.darkened(0.1 if i < 5 else 0.24))
	b.poly(_oval(Vector2(0, -103), Vector2(14.0, 17.0), 28), skin.darkened(0.12), 1.6)
	b.polygon(_p([-14, -103, -12, -113, -6, -119, 0, -120, 1, -86, -6, -88, -11, -94]), skin)
	match style:
		"none":
			b.polygon(_oval(Vector2(-5, -113), Vector2(4.0, 2.6), 12), Color(skin.lightened(0.35), 0.5))
		"crest":  # shaved sides, a crest of hair front to back
			b.polygon(_oval(Vector2(-7, -112), Vector2(3.0, 2.4), 12), Color(skin.lightened(0.35), 0.45))
			b.polygon(_p([-13, -104, -12, -114, -6, -119, 6, -119, 12, -114, 13, -104, 9, -112, -9, -112]), Color(hair, 0.22))
			b.poly(_p([-4, -112, -5, -122, -3, -131, 3, -131, 5, -122, 4, -112]), hair, 1.3)
			b.polygon(_p([0.5, -131, 3, -131, 5, -122, 4, -112, 0.5, -112]), hair.darkened(0.22))
		"cropped":
			var cr := hair.lerp(skin, 0.4)
			b.poly(_p([-14.5, -104, -14, -112, -10, -118, -4, -121, 4, -121, 10, -118, 14, -112, 14.5, -104, 11, -110, 4, -114, -4, -114, -11, -110]), cr, 1.2)
			b.polygon(_p([4, -121, 10, -118, 14, -112, 14.5, -104, 11, -110, 4, -114]), cr.darkened(0.2))
		_:
			# The hair on top, a fringe across the brow.
			b.poly(_p([-14.5, -101, -15, -111, -11, -119, -4, -122, 4, -122, 11, -119, 15, -111, 14.5, -101, 12, -108, 7, -111, 1, -109, -5, -111, -11, -108]), hair, 1.4)
			b.polygon(_p([4, -122, 11, -119, 15, -111, 14.5, -101, 12, -108, 7, -111]), hair.darkened(0.22))
			b.line(Vector2(-9, -117), Vector2(-3, -120), Color(hair.lightened(0.4), 0.55), 1.4)
			if style == "long":  # locks either side of the face
				b.polygon(_p([-14.5, -104, -16.5, -84, -12, -86, -12, -101]), hair)
				b.polygon(_p([14.5, -104, 16.5, -84, 12, -86, 12, -101]), hair.darkened(0.22))
			elif style == "curls":  # curls along the brow
				for i in 4:
					b.dot(Vector2(-7.5 + i * 5.0, -110.5 + (1.0 if i % 2 == 0 else 0.0)), 2.6, hair.darkened(0.08 if i < 2 else 0.2))
	_front_features(b, lk, 0.0)
	_front_beard(b, lk, 0.0)
	_front_eyes(b, lk, 4.6, -101.0, 0.0)
	var brow := (skin if style == "none" else hair).darkened(0.45)
	b.line(Vector2(-7, -105.5), Vector2(-2.5, -106), Color(brow, 0.8), 1.3)  # brows
	b.line(Vector2(2.5, -106), Vector2(7, -105.5), Color(brow, 0.8), 1.3)
	b.line(Vector2(0.5, -99), Vector2(1.5, -95.5), Color(skin.darkened(0.3), 0.8), 1.2)  # nose
	if String(lk.get("beard", "none")) in ["none", "stubble"]:
		b.line(Vector2(-3.0, -91.5), Vector2(3.0, -91.5), Color(skin.darkened(0.42), 0.9), 1.2)  # mouth
	if style == "braid" or style == "twin":
		_front_braid(b, hair, Vector2(-12, -90))
	if style == "twin":
		_front_braid(b, hair.darkened(0.12), Vector2(12, -90), -1.0)
	_front_head_extras(b, lk, false)


## Freckles, a scar, ink lines, war paint or a beauty spot. `shade` dims
## them in the hood's shadow.
static func _front_features(b, lk: Dictionary, shade: float) -> void:
	var dy := 1.0 if shade > 0.0 else 0.0  # (the hood's face sits a touch lower)
	match String(lk.get("face", "clear")):
		"freckles":
			for p in [[-8, -96], [-6, -94.5], [-9.5, -94], [-7, -97.5], [8, -96], [6, -94.5], [9.5, -94], [7, -97.5], [-1.5, -97], [1.5, -97.5]]:
				b.dot(Vector2(p[0], p[1] + dy), 0.75, Color(ACCENTS["freckles"].darkened(shade), 0.85))
		"scar":
			var sc: Color = ACCENTS["scar"].darkened(shade)
			b.line(Vector2(4, -110 + dy), Vector2(9, -93 + dy), Color(sc.darkened(0.3), 0.9), 2.2)
			b.line(Vector2(4, -110 + dy), Vector2(9, -93 + dy), sc, 1.2)
			for y in [-106.0, -101.0, -96.0]:
				var x: float = 4.0 + (y + 110.0) / 17.0 * 5.0
				b.line(Vector2(x - 1.8, y + dy), Vector2(x + 1.8, y + 0.6 + dy), Color(sc.darkened(0.2), 0.8), 0.8)
		"ink":
			var ic: Color = ACCENTS["ink"].darkened(shade)
			for s in [-1.0, 1.0]:
				b.line(Vector2(s * 6.5, -97 + dy), Vector2(s * 9.5, -89 + dy), ic, 1.2)
				b.line(Vector2(s * 8.5, -98.5 + dy), Vector2(s * 11.5, -91 + dy), ic, 1.2)
			b.line(Vector2(0, -89.5 + dy), Vector2(0, -86 + dy), ic, 1.2)
		"paint":
			b.polygon(_p([-13, -105 + dy, 13, -105 + dy, 12, -99 + dy, 3, -98 + dy, 0, -100 + dy, -3, -98 + dy, -12, -99 + dy]), Color(ACCENTS["paint"].darkened(shade), 0.88))
		"mole":
			b.dot(Vector2(-6.5, -93 + dy), 1.0, Color(0.25, 0.14, 0.1).darkened(shade))


## The beard (front): stubble on the jaw, a moustache, a short or full beard,
## or a full one braided at the chin.
static func _front_beard(b, lk: Dictionary, shade: float) -> void:
	var hair: Color = lk["hair"].darkened(shade)
	var dy := 1.0 if shade > 0.0 else 0.0
	var jaw := _p([-13, -101, -11, -93, -6, -88, 0, -86.5, 6, -88, 11, -93, 13, -101, 10, -95, 5, -92.5, 0, -93.5, -5, -92.5, -10, -95])
	var tache := _p([-6, -91, -3, -93.6, 0, -93, 3, -93.6, 6, -91, 3, -91.8, 0, -91.2, -3, -91.8])
	match String(lk.get("beard", "none")):
		"stubble":
			b.polygon(_shift(jaw, Vector2(0, dy)), Color(hair.lerp(lk["skin"], 0.35), 0.42))
		"moustache":
			b.polygon(_shift(tache, Vector2(0, dy)), hair.darkened(0.08))
		"short":
			b.polygon(_shift(jaw, Vector2(0, dy)), hair)
			b.polygon(_shift(tache, Vector2(0, dy)), hair.darkened(0.12))
			b.line(Vector2(-2.5, -90 + dy), Vector2(2.5, -90 + dy), Color(lk["skin"].darkened(0.45 + shade), 0.9), 1.1)
		"full", "braided":
			var full := _p([-14, -103, -13, -92, -8, -83, 0, -79, 8, -83, 13, -92, 14, -103, 10, -96, 5, -93, 0, -93.5, -5, -93, -10, -96])
			b.poly(_shift(full, Vector2(0, dy)), hair, 1.0)
			b.polygon(_shift(_p([0, -93.5, 5, -93, 10, -96, 14, -103, 13, -92, 8, -83, 0, -79]), Vector2(0, dy)), hair.darkened(0.18))
			b.polygon(_shift(tache, Vector2(0, dy)), hair.darkened(0.1))
			b.line(Vector2(-2.5, -90 + dy), Vector2(2.5, -90 + dy), Color(lk["skin"].darkened(0.45 + shade), 0.9), 1.1)
			if String(lk.get("beard", "")) == "braided":
				for i in 4:
					b.polygon(_oval(Vector2(0, -78 + i * 4.2 + dy), Vector2(3.0 - i * 0.3, 2.6), 10), hair if i % 2 == 0 else hair.darkened(0.16))
				b.ball(Vector2(0, -61 + dy), 2.2, ACCENTS["metal"].darkened(shade))


## The eyes on the front figure by shape: dark dots, or a white, an iris and
## a pupil; almond and narrow ones are lenses and slits, wide-set ones
## further apart. An eyepatch covers the right one. `shade` dims them in the hood's shadow.
static func _front_eyes(b, lk: Dictionary, x: float, y: float, shade: float) -> void:
	var col: Color = lk["eyes"]
	var shape: String = lk.get("eye_shape", "round")
	var dark := is_equal_approx(lk.get("eye_r", 0.75), 0.75)
	if shape == "wide":
		x += 1.4
	var patch := String(lk.get("accessory", "none")) == "eyepatch"
	for s in [-1.0, 1.0]:
		var at: Vector2 = Vector2(s * x, y)
		if patch and s > 0.0:
			continue
		var white := Color(0.92, 0.9, 0.86).darkened(shade + 0.1)
		match shape:
			"almond":
				var lens := _p([at.x - 3.4, at.y, at.x - 1.2, at.y - 1.7, at.x + 1.6, at.y - 1.6, at.x + 3.4, at.y - 0.3, at.x + 1.4, at.y + 1.3, at.x - 1.4, at.y + 1.2])
				if dark:
					b.polygon(_shift(_sx(_shift(lens, -at), 0.7), at), UI.OUTLINE)
				else:
					b.polygon(lens, white)
					b.dot(at + Vector2(0.2, 0.0), 1.4, col.darkened(shade))
					b.dot(at + Vector2(0.2, 0.0), 0.6, UI.OUTLINE)
				b.line(at + Vector2(-3.4, -0.4), at + Vector2(3.4, -1.0), Color(UI.OUTLINE, 0.7), 0.9)
			"narrow":
				b.line(at + Vector2(-3.0, 0.2), at + Vector2(3.0, -0.2), UI.OUTLINE, 1.3)
				if not dark:
					b.dot(at + Vector2(0.3, 0.0), 1.0, col.darkened(shade))
				b.line(at + Vector2(-3.2, -1.4), at + Vector2(3.0, -1.6), Color(lk["skin"].darkened(0.4 + shade), 0.8), 1.0)
			_:
				if dark:
					b.dot(at, 1.5, UI.OUTLINE)
				else:
					b.dot(at, 2.3, white)
					b.dot(at + Vector2(0.2, 0.1), 1.6, col.darkened(shade))
					b.dot(at + Vector2(0.2, 0.1), 0.7, UI.OUTLINE)
	if patch:
		var at := Vector2(x, y)
		var strap := Color(ACCENTS["patch"].lightened(0.1), 0.95)
		b.line(at + Vector2(-2.5, -2.0), Vector2(-13.5, -110.0 if shade == 0.0 else -106.0), strap, 1.4)
		b.line(at + Vector2(2.5, 1.0), Vector2(13.5, -98.0), strap, 1.4)
		b.poly(_oval(at + Vector2(0.3, 0.2), Vector2(3.8, 3.2), 12), ACCENTS["patch"], 0.8)


## Earrings, a feather and what's at the neck (a scarf, a pendant or a torc),
## then the cloak's clasp (hidden by a scarf).
static func _front_head_extras(b, lk: Dictionary, hood_up: bool) -> void:
	match String(lk.get("accessory", "none")):
		"earrings":
			for s in [-1.0, 1.0]:
				var at: Vector2 = Vector2(s * 10.5, -91.0) if hood_up else Vector2(s * 14.2, -95.5)
				b.dot(at, 2.1, UI.OUTLINE)
				b.dot(at, 1.4, ACCENTS["metal"].darkened(0.25 if hood_up else 0.0))
		"feather":
			var base := Vector2(19, -120) if hood_up else Vector2(13, -106)
			var tip := Vector2(31, -150) if hood_up else Vector2(25, -138)
			var dir := (tip - base).normalized()
			var n := dir.orthogonal()
			var vane := PackedVector2Array()
			for i in 7:
				var u := float(i) / 6.0
				vane.append(base.lerp(tip, u) + n * sin(u * PI) * 4.5)
			for i in 7:
				var u := 1.0 - float(i) / 6.0
				vane.append(base.lerp(tip, u) - n * sin(u * PI) * 3.6)
			b.poly(vane, ACCENTS["feather"], 1.0)
			b.polygon(PackedVector2Array([tip, tip.lerp(base, 0.3) + n * 3.6, tip.lerp(base, 0.3) - n * 3.0]), ACCENTS["feather_tip"])
			b.line(base - dir * 3.0, tip, Color(ACCENTS["feather"].darkened(0.35), 0.9), 1.0)
	var neck: String = lk.get("neck", "none")
	match neck:
		"scarf":
			var col := scarf_color(lk)
			b.poly(_p([-15, -86, -6, -82, 6, -82, 15, -86, 17, -78, 8, -72, 0, -71, -8, -72, -17, -78]), col, 1.4)
			b.polygon(_p([0, -82, 6, -82, 15, -86, 17, -78, 8, -72, 0, -71]), col.darkened(0.18))
			b.line(Vector2(-12, -80), Vector2(10, -79), Color(col.darkened(0.35), 0.7), 1.2)
			b.poly(_p([-9, -74, -3, -74, -6, -48, -12, -50]), col.darkened(0.08), 1.2)  # its tail, on the chest
			for x in [-10.5, -8.5, -6.5]:
				b.line(Vector2(x, -49), Vector2(x - 0.5, -45), col.darkened(0.2), 1.0)
		"pendant":
			b.path(_p([-8, -80, -4, -68, 0, -60, 4, -68, 8, -80]), Color(ACCENTS["metal"].darkened(0.3), 0.9), 1.1)
			b.poly(_oval(Vector2(0, -56), Vector2(3.4, 4.4), 12), ACCENTS["metal"], 1.0)
			b.polygon(_oval(Vector2(-0.3, -56.4), Vector2(2.0, 2.8), 10), ACCENTS["stone"])
		"torc":
			b.path(_p([-12, -84, -7, -79, 0, -77.5, 7, -79, 12, -84]), UI.OUTLINE, 5.2)
			b.path(_p([-12, -84, -7, -79, 0, -77.5, 7, -79, 12, -84]), ACCENTS["metal"], 3.2)
			b.line(Vector2(-6, -80.5), Vector2(2, -79.5), Color(ACCENTS["metal"].lightened(0.4), 0.7), 1.0)
			for s in [-1.0, 1.0]:
				b.ball(Vector2(s * 12.5, -84.5), 2.4, ACCENTS["metal"])
	if neck != "scarf":
		b.ball(Vector2(0, -77), 3.4, UI.GOLD.darkened(0.15))


## A braid over the shoulder (the left, or the right with `side` -1), down onto the chest.
static func _front_braid(b, hair: Color, from: Vector2, side := 1.0) -> void:
	var pts := PackedVector2Array()
	for i in 8:
		pts.append(from + Vector2(-1.0 * i * side, 5.2 * i))
	b.path(pts, Palette.OUTLINE, 8.6)
	for i in 8:  # plaits, leaning one way then the other
		var s := 1.0 if i % 2 == 0 else -1.0
		var w := 3.6 - 0.2 * i
		b.polygon(_oval(pts[i] + Vector2(s * 0.8, 0), Vector2(w, 3.4), 10), hair if i % 2 == 0 else hair.darkened(0.15))
		b.line(pts[i] + Vector2(-w * 0.7, -1.6 * s), pts[i] + Vector2(w * 0.7, 1.6 * s), Color(hair.darkened(0.4), 0.7), 1.0)
	var end := from + Vector2(-7.0 * side, 38.0)
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
