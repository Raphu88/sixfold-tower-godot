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
##     [gear: leg armour, boots] → neck, tunic, collar and belt → [gear: body armour, a
##     pack's straps] → arms → [gear: the weapon, gloves, rings] → the
##     mantle → [gear: pauldrons, the amulet] → draw_front_head → [gear: a
##     cap, helm or coif]. (A Poncho comes before the weapon, gloves and
##     rings: the hands come out from under it.) The gear layers are
##     gear_look.gd's, drawn only for a dressed look (GearLook.dress: "gear_on").
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
const Shade := preload("res://scripts/shade.gd")

## The option rows: [key, name]. The editor shows them a tab at a time (TABS).
static var ROWS := [
	["body", "Body"], ["build", "Build"], ["skin", "Skin"],
	["eye_shape", "Eye shape"], ["eyes", "Eye colour"], ["face", "Features"],
	["hair", "Hair"], ["hair_color", "Hair colour"], ["beard", "Facial hair"], ["beard_color", "Beard colour"],
	["clothes", "Clothes"], ["tunic", "Clothes colour"], ["trousers", "Trousers"], ["boots", "Boots"], ["belt", "Belt"],
	["cloak_style", "Cape or cloak"], ["cloak", "Cloak colour"], ["trim", "Trim"], ["pattern", "Texture"], ["hood", "Hood"],
	["accessory", "Accessory"],
]

## The editor's tabs, in order: [id, name, the rows on it].
static var TABS := [
	["body", "Body", ["body", "build", "skin"]],
	["face", "Face", ["eye_shape", "eyes", "face"]],
	["hair", "Hair", ["hair", "hair_color", "beard", "beard_color"]],
	["clothes", "Clothes", ["clothes", "tunic", "trousers", "boots", "belt"]],
	["cloak", "Cloak", ["cloak_style", "cloak", "trim", "pattern", "hood"]],
	["extras", "Extras", ["accessory"]],
]

## Each option: [id, name, colour] (colour options, chosen by swatches) or
## [id, name] (the rest). A belt's fourth entry is how it's worn ("belt",
## "sash" or "rope"). The trim's "none", the trousers' "match" and the
## beard colour's "match" are not colours (no trim; the tunic's colour; the
## hair's colour): their swatch is drawn empty. The first entry is not
## special; DEFAULTS says which one is today's look. Colour rows have six
## presets and a colour wheel (WHEEL): a colour from the wheel is kept as
## "#rrggbb" in place of an id.
static var OPTIONS := {
	"body": [
		["masculine", "Masculine"],
		["feminine", "Feminine"],
		["androgynous", "Androgynous"],
	],
	"build": [
		["slight", "Slight"],
		["lean", "Lean"],
		["wiry", "Wiry"],
		["average", "Average"],
		["athletic", "Athletic"],
		["broad", "Broad"],
		["stocky", "Stocky"],
		["heavy", "Heavy"],
		["tall", "Tall and lean"],
		["short", "Short and sturdy"],
		["lanky", "Lanky"],
		["burly", "Burly"],
	],
	"skin": [
		["porcelain", "Porcelain", Color(0.98, 0.88, 0.8)],
		["fair", "Fair", Palette.CLIMBER_SKIN],
		["olive", "Olive", Color(0.76, 0.61, 0.43)],
		["tan", "Tan", Color(0.66, 0.48, 0.32)],
		["brown", "Brown", Color(0.5, 0.35, 0.23)],
		["deep", "Deep", Color(0.36, 0.25, 0.17)],
	],
	"eye_shape": [
		["round", "Round"],
		["almond", "Almond"],
		["narrow", "Narrow"],
		["wide", "Wide-set"],
		["hooded", "Hooded"],
		["upturned", "Upturned"],
		["downturned", "Downturned"],
		["deep", "Deep-set"],
		["heavy", "Heavy-lidded"],
		["sharp", "Sharp"],
		["monolid", "Monolid"],
		["close", "Close-set"],
	],
	"eyes": [
		["dark", "Dark", Palette.OUTLINE],
		["brown", "Brown", Color(0.45, 0.27, 0.13)],
		["hazel", "Hazel", Color(0.58, 0.47, 0.22)],
		["green", "Green", Color(0.32, 0.62, 0.34)],
		["blue", "Blue", Color(0.33, 0.55, 0.88)],
		["grey", "Grey", Color(0.62, 0.66, 0.7)],
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
		["cropped", "Cropped"],
		["long", "Long"],
		["tied", "Tied up"],
		["braid", "Braid"],
		["curls", "Curls"],
		["tail", "Ponytail"],
		["twin", "Twin braids"],
		["crest", "Crest"],
		["mane", "Wild mane"],
		["bun", "Bun"],
		["swept", "Side-swept"],
		["undercut", "Shaved sides, long top"],
		["locks", "Locks"],
		["afro", "Afro"],
		["bob", "Bob"],
		["pigtails", "Pigtails"],
	],
	"hair_color": [
		["black", "Black", Color(0.11, 0.1, 0.11)],
		["brown", "Brown", Palette.CLIMBER_HAIR],
		["auburn", "Auburn", Color(0.52, 0.22, 0.11)],
		["copper", "Copper", Color(0.74, 0.38, 0.17)],
		["blond", "Blond", Color(0.86, 0.71, 0.42)],
		["white", "White", Color(0.9, 0.89, 0.86)],
	],
	"beard": [
		["none", "None"],
		["stubble", "Stubble"],
		["moustache", "Moustache"],
		["goatee", "Goatee"],
		["short", "Short beard"],
		["full", "Full beard"],
		["braided", "Braided beard"],
		["chops", "Mutton chops"],
		["long", "Long beard"],
		["forked", "Forked beard"],
		["handlebar", "Handlebar moustache"],
		["chinstrap", "Chinstrap"],
	],
	"beard_color": [
		["match", "As the hair", Palette.CLIMBER_HAIR],
		["black", "Black", Color(0.11, 0.1, 0.11)],
		["brown", "Brown", Color(0.36, 0.24, 0.15)],
		["copper", "Copper", Color(0.74, 0.38, 0.17)],
		["blond", "Blond", Color(0.86, 0.71, 0.42)],
		["grey", "Grey", Color(0.66, 0.65, 0.63)],
	],
	"clothes": [
		["tunic", "Tunic"],
		["vest", "Shirt and vest"],
		["jerkin", "Jerkin"],
		["gambeson", "Gambeson"],
		["coat", "Coat"],
		["longcoat", "Long coat"],
		["robe", "Robe"],
		["wrap", "Wrap"],
		["tabard", "Tabard"],
		["sleeveless", "Sleeveless tunic"],
		["doublet", "Doublet"],
		["kilt", "Tunic and kilt"],
	],
	"tunic": [
		["brown", "Brown", Palette.CLIMBER_TUNIC],
		["grey", "Grey", Color(0.42, 0.42, 0.44)],
		["olive", "Olive", Color(0.42, 0.42, 0.27)],
		["oxblood", "Oxblood", Color(0.44, 0.2, 0.2)],
		["navy", "Navy", Color(0.23, 0.27, 0.42)],
		["cream", "Cream", Color(0.78, 0.73, 0.62)],
	],
	"trousers": [
		["match", "As the clothes", Palette.CLIMBER_TUNIC],
		["brown", "Brown", Color(0.4, 0.29, 0.2)],
		["grey", "Grey", Color(0.46, 0.46, 0.48)],
		["black", "Black", Color(0.2, 0.19, 0.21)],
		["navy", "Navy", Color(0.25, 0.3, 0.46)],
		["sand", "Sand", Color(0.68, 0.6, 0.46)],
	],
	"boots": [
		["brown", "Brown", Palette.CLIMBER_BOOT],
		["black", "Black", Color(0.14, 0.13, 0.14)],
		["tan", "Tan", Color(0.56, 0.4, 0.25)],
		["grey", "Grey", Color(0.4, 0.4, 0.42)],
		["oxblood", "Oxblood", Color(0.4, 0.15, 0.14)],
		["pale", "Pale", Color(0.72, 0.66, 0.54)],
	],
	"belt": [
		["leather", "Leather belt", Color(0.3, 0.2, 0.13), "belt"],
		["black", "Black belt", Color(0.13, 0.12, 0.14), "belt"],
		["red", "Red sash", Color(0.68, 0.18, 0.18), "sash"],
		["blue", "Blue sash", Color(0.25, 0.38, 0.68), "sash"],
		["green", "Green sash", Color(0.27, 0.52, 0.3), "sash"],
		["gold", "Gold sash", Color(0.82, 0.64, 0.26), "sash"],
		["rope", "Rope", Color(0.7, 0.6, 0.4), "rope"],
		["studded", "Studded belt", Color(0.26, 0.17, 0.11), "studded"],
		["double", "Double belt", Color(0.34, 0.23, 0.15), "double"],
		["chain", "Chain belt", Color(0.66, 0.68, 0.72), "chain"],
		["purple", "Purple sash", Color(0.5, 0.26, 0.6), "sash"],
		["cord", "Pale cord", Color(0.88, 0.85, 0.76), "rope"],
	],
	"cloak_style": [
		["long", "Long cloak"],
		["short", "Short cloak"],
		["tattered", "Tattered"],
		["mantle", "Mantle"],
		["half", "Half cape"],
		["shawl", "Shawl"],
		["poncho", "Poncho"],
		["wrapped", "Wrapped"],
		["capelet", "Hooded capelet"],
		["cowl", "Cowl"],
		["trailing", "Trailing cloak"],
		["none", "No cloak"],
	],
	"cloak": [
		["teal", "Teal", Palette.CLIMBER_CLOAK],
		["crimson", "Crimson", Color(0.64, 0.2, 0.2)],
		["moss", "Moss", Color(0.38, 0.52, 0.3)],
		["ochre", "Ochre", Color(0.74, 0.58, 0.25)],
		["plum", "Plum", Color(0.46, 0.27, 0.52)],
		["charcoal", "Charcoal", Color(0.22, 0.21, 0.24)],
	],
	"trim": [
		["none", "No trim", Color(0.5, 0.5, 0.5)],
		["gold", "Gold", Color(0.88, 0.7, 0.3)],
		["silver", "Silver", Color(0.8, 0.82, 0.86)],
		["crimson", "Crimson", Color(0.74, 0.17, 0.17)],
		["black", "Black", Color(0.1, 0.09, 0.11)],
		["teal", "Teal", Color(0.26, 0.66, 0.64)],
	],
	"pattern": [
		["plain", "Plain"],
		["banded", "Banded hem"],
		["striped", "Striped"],
		["embroidered", "Embroidered"],
		["patched", "Patched"],
		["checked", "Checked"],
		["fur", "Fur-lined"],
		["quilted", "Quilted"],
		["scaled", "Scaled"],
		["runed", "Runed"],
		["spotted", "Spotted"],
		["halved", "Two-tone"],
	],
	"hood": [
		["up", "Hood up"],
		["low", "Hood pulled low"],
		["down", "Hood down"],
	],
	"accessory": [
		["none", "None"],
		["earrings", "Earrings"],
		["eyepatch", "Eyepatch"],
		["feather", "Feather"],
		["scarf", "Scarf"],
		["pendant", "Pendant"],
		["torc", "Torc"],
		["nosering", "Nose ring"],
		["headband", "Headband"],
		["spectacles", "Spectacles"],
		["circlet", "Circlet"],
		["mask", "Mask"],
	],
}

## Choices kept with the look that don't change the drawing: the pronouns
## (pronouns.gd: chosen on the name step, changed on this page's name row).
static var EXTRA_OPTIONS := {
	"pronouns": [["he", "He / him"], ["she", "She / her"], ["they", "They / them"]],
}

## The colour rows that also offer a colour wheel (a colour of your own).
const WHEEL := ["skin", "eyes", "hair_color", "beard_color", "tunic", "trousers", "boots", "cloak", "trim"]

## Today's look: what every climber had before there was a choice (old
## saves load with it, an option added later with its entry here) and what
## a new climber starts from.
const DEFAULTS := {
	"name": "", "skin": "fair", "hair": "short", "hair_color": "brown", "eyes": "dark",
	"cloak": "teal", "tunic": "brown", "hood": "up",
	"eye_shape": "round", "face": "clear", "beard": "none", "build": "average",
	"trousers": "match", "boots": "brown", "cloak_style": "long", "trim": "none",
	"pattern": "plain", "belt": "leather", "accessory": "none",
	"body": "androgynous", "beard_color": "match", "clothes": "tunic", "pronouns": "they",
}

## Colours of the small things that aren't chosen by swatch: the scarf (when
## the cloak has no trim; with one, the scarf takes the trim's colour),
## metal (earrings, a pendant, a torc, buckles), a pendant's stone, the
## feather and its tip, the eyepatch, the face's freckles, scar, ink and
## paint, a headband, the spectacles' rims, a fur lining and runes.
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
	"band": Color(0.62, 0.22, 0.2),
	"rims": Color(0.3, 0.24, 0.18),
	"fur": Color(0.78, 0.7, 0.58),
	"rune": Color(0.55, 0.85, 1.0),
	"shirt": Color(0.86, 0.82, 0.74),
}

## The body's sizes for each build: in the tower the chest's radius, the
## shoulders' distance from the middle, how much bigger the shoulders are
## and how wide the cloak hangs; on the front figure `wx` widens the chest,
## shoulders and cloak (the hands stay where the marks expect them) and
## `leg_k` lengthens or shortens the legs.
static var BUILDS := {
	"slight": {"torso_r": 7.6, "sh_y": 8.5, "sh_add": -0.5, "width": 0.9, "wx": 0.87, "leg_k": 1.0},
	"lean": {"torso_r": 7.9, "sh_y": 8.9, "sh_add": -0.3, "width": 0.94, "wx": 0.92, "leg_k": 1.02},
	"wiry": {"torso_r": 8.1, "sh_y": 9.0, "sh_add": -0.2, "width": 0.96, "wx": 0.95, "leg_k": 1.0},
	"average": {"torso_r": 8.5, "sh_y": 9.3, "sh_add": 0.0, "width": 1.0, "wx": 1.0, "leg_k": 1.0},
	"athletic": {"torso_r": 8.9, "sh_y": 9.9, "sh_add": 0.4, "width": 1.06, "wx": 1.08, "leg_k": 1.0},
	"broad": {"torso_r": 9.5, "sh_y": 10.3, "sh_add": 0.7, "width": 1.12, "wx": 1.14, "leg_k": 1.0},
	"stocky": {"torso_r": 9.3, "sh_y": 9.6, "sh_add": 0.5, "width": 1.09, "wx": 1.11, "leg_k": 0.94},
	"heavy": {"torso_r": 10.0, "sh_y": 10.0, "sh_add": 0.6, "width": 1.16, "wx": 1.2, "leg_k": 0.98},
	"tall": {"torso_r": 8.0, "sh_y": 9.1, "sh_add": -0.1, "width": 0.92, "wx": 0.9, "leg_k": 1.08},
	"short": {"torso_r": 9.0, "sh_y": 9.4, "sh_add": 0.3, "width": 1.03, "wx": 1.05, "leg_k": 0.9},
	"lanky": {"torso_r": 7.3, "sh_y": 8.7, "sh_add": -0.6, "width": 0.86, "wx": 0.84, "leg_k": 1.1},
	"burly": {"torso_r": 10.4, "sh_y": 10.8, "sh_add": 1.0, "width": 1.2, "wx": 1.24, "leg_k": 0.97},
}

## The body (masculine, feminine, androgynous): added to the build's
## chest and shoulders, and on the front figure the shoulders' width
## (`wx`, a share), the hips and the face's shape.
static var BODIES := {
	"masculine": {"torso_add": 0.35, "sh_add": 0.35, "wx": 1.05},
	"feminine": {"torso_add": -0.35, "sh_add": -0.4, "wx": 0.94},
	"androgynous": {"torso_add": 0.0, "sh_add": 0.0, "wx": 1.0},
}

## Randomise: how often an option that can be plain stays plain (its first
## choice), so a rolled climber isn't always wearing everything at once.
static var RANDOM_PLAIN := {
	"face": 0.45, "beard": 0.5, "trim": 0.35, "pattern": 0.4, "accessory": 0.55,
	"trousers": 0.3, "beard_color": 0.6, "clothes": 0.3,
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
	"pronouns": "Pronouns",
	"turn_left": "<  Turn",
	"turn_right": "Turn  >",
	"randomise": "Randomise",
	"begin": "Begin",
	"next": "Next",
	"done": "Done",
	"button": "Appearance",  # on the climber screen
	"custom": "Your own",
	"wheel_title": "%s: your own colour",
	"wheel_hue": "Colour",
	"wheel_shade": "Brightness",
	"wheel_strength": "Strength",
	"wheel_done": "Done",
}

const BOOT := Palette.CLIMBER_BOOT


## A saved appearance made whole: every key present and every id known
## (anything missing or unknown takes today's look; a colour from the
## wheel, "#rrggbb", is kept on the rows that have one). Safe on old saves.
static func normalized(raw) -> Dictionary:
	var out := DEFAULTS.duplicate()
	if not (raw is Dictionary):
		return out
	for key in OPTIONS:
		var id := str(raw.get(key, out[key]))
		if index_of(key, id) >= 0 or (key in WHEEL and is_custom(id)):
			out[key] = id.to_lower() if is_custom(id) else id
	for key in EXTRA_OPTIONS:
		var id2 := str(raw.get(key, out[key]))
		if index_of(key, id2) >= 0:
			out[key] = id2
	# (an old save's neckpiece is an accessory now, when it has none)
	var neck := str(raw.get("neck", "none"))
	if neck in ["scarf", "pendant", "torc"] and out["accessory"] == "none":
		out["accessory"] = neck
	out["name"] = clean_name(str(raw.get("name", "")))
	return out


## A name as it's kept: trimmed, one line, at most NAME_MAX letters.
static func clean_name(s: String) -> String:
	s = s.replace("\n", " ").replace("\t", " ").strip_edges()
	return s.left(NAME_MAX).strip_edges()


## The options of a row (a drawn one, or one kept with the look: EXTRA_OPTIONS).
static func options_of(key: String) -> Array:
	return OPTIONS.get(key, EXTRA_OPTIONS.get(key, []))


static func index_of(key: String, id: String) -> int:
	var list: Array = options_of(key)
	for i in list.size():
		if list[i][0] == id:
			return i
	return -1


## A colour from the wheel: "#rrggbb".
static func is_custom(id: String) -> bool:
	return id.length() == 7 and id.begins_with("#") and Color.html_is_valid(id)


static func custom_id(c: Color) -> String:
	return "#" + c.to_html(false).to_lower()


## True for the rows that offer a colour wheel.
static func has_wheel(key: String) -> bool:
	return key in WHEEL


## The option `by` steps from the current one (wrapping round; from a
## colour of your own, the first or last preset).
static func step(app: Dictionary, key: String, by: int) -> String:
	var list: Array = options_of(key)
	var cur := str(app.get(key, DEFAULTS[key]))
	if is_custom(cur):
		return list[0 if by > 0 else list.size() - 1][0]
	var i := maxi(0, index_of(key, cur))
	return list[(i + by + list.size() * 4) % list.size()][0]


static func option_name(key: String, id: String) -> String:
	if is_custom(id):
		return TEXT["custom"]
	var i := index_of(key, id)
	return options_of(key)[i][1] if i >= 0 else id


static func color_of(key: String, id: String) -> Color:
	if is_custom(id) and key in WHEEL:
		return Color.html(id)
	var i := index_of(key, id)
	if i < 0:
		i = index_of(key, DEFAULTS[key])
	return OPTIONS[key][i][2]


## True for the rows chosen by swatches (they have colours).
static func has_colors(key: String) -> bool:
	return OPTIONS.has(key) and OPTIONS[key][0].size() > 2


## A swatch that isn't a colour: no trim, or trousers like the tunic, or a beard like the hair.
static func is_blank(key: String, id: String) -> bool:
	return (key == "trim" and id == "none") or ((key == "trousers" or key == "beard_color") and id == "match")


## The tab a row is on.
static func tab_of(key: String) -> String:
	for t in TABS:
		if key in t[2]:
			return t[0]
	return String(TABS[0][0])


## A random look (the name and pronouns are kept).
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
	var hair := color_of("hair_color", a["hair_color"])
	var bi := index_of("belt", a["belt"])
	var acc: String = a["accessory"]
	var cloaked: bool = a["cloak_style"] != "none"
	var lk := {
		"skin": color_of("skin", a["skin"]),
		"hair": hair,
		"beard_col": hair if a["beard_color"] == "match" else color_of("beard_color", a["beard_color"]),
		"eyes": color_of("eyes", a["eyes"]),
		"cloak": color_of("cloak", a["cloak"]),
		"tunic": tunic,
		"boot": color_of("boots", a["boots"]),
		"trousers": tunic if a["trousers"] == "match" else color_of("trousers", a["trousers"]),
		"hair_style": a["hair"],
		"hood_up": a["hood"] != "down" and cloaked,  # (no cloak, no hood)
		"hood_low": a["hood"] == "low" and cloaked,  # (pulled low: the eyes in its shadow)
		"eye_r": 0.75 if a["eyes"] == DEFAULTS["eyes"] else 0.95,  # (a colour needs a little more room)
		"eye_shape": a["eye_shape"],
		"face": a["face"],
		"beard": a["beard"],
		"build": a["build"],
		"body": a["body"],
		"clothes": a["clothes"],
		"cloak_style": a["cloak_style"],
		"trim_on": a["trim"] != "none",
		"trim": color_of("trim", a["trim"]),
		"pattern": a["pattern"],
		"belt": color_of("belt", a["belt"]),
		"belt_kind": String(OPTIONS["belt"][bi][3]) if bi >= 0 and OPTIONS["belt"][bi].size() > 3 else "belt",
		"neck": acc if acc in ["scarf", "pendant", "torc"] else "none",  # (a neckpiece: drawn at the neck)
		"accessory": acc,
	}
	var bd: Dictionary = BUILDS.get(a["build"], BUILDS["average"])
	for k in bd:
		lk[k] = float(bd[k])
	var by: Dictionary = BODIES.get(a["body"], BODIES["androgynous"])
	lk["torso_r"] = float(lk["torso_r"]) + float(by["torso_add"])
	lk["sh_add"] = float(lk["sh_add"]) + float(by["sh_add"])
	lk["wx"] = float(lk["wx"]) * float(by["wx"])
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
	if style == "none":
		return out  # (no cloak at all)
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
			"half":  # one shoulder: the far side pulled in
				if p.y < 0.0:
					p.y *= 0.3
				if p.x < -3.0:
					p.x = -3.0 + (p.x + 3.0) * 0.8
			"shawl":  # round the shoulders, wide, to the waist
				if p.x < -2.0:
					p.x = -2.0 + (p.x + 2.0) * 0.55
				p.y *= 1.22
			"poncho":  # wide all round, over the chest too
				if p.x < -2.0:
					p.x = -2.0 + (p.x + 2.0) * 0.6
				else:
					p.x += 3.5
				p.y *= 1.3
			"wrapped":  # long and drawn in close
				p.y *= 0.78
				if p.x > 0.0:
					p.x += 1.5
			"capelet":  # a small cape to the shoulder blades
				if p.x < -2.0:
					p.x = -2.0 + (p.x + 2.0) * 0.3
				p.y *= 1.05
			"cowl":  # a deep collar round the neck and shoulders, nothing below
				if p.x < -1.0:
					p.x = -1.0 + (p.x + 1.0) * 0.2
				p.y *= 1.28
			"trailing":  # long enough to sweep the floor behind
				if p.x < -4.0:
					p.x = -4.0 + (p.x + 4.0) * 1.4
				p.y *= 1.06
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
	if pts.size() < 5:
		return  # (no cloak)
	var mid := Vector2(-5.0 + d.x * 0.5, d.y * 0.5) if not style in ["mantle", "shawl", "capelet", "poncho", "cowl"] else Vector2(-1.0, d.y * 0.2)
	b.poly(_cloth(pts, f, sd, lx, Vector2.ZERO, 1.0, smooth), cloak.darkened(0.3), 1.2)
	b.polygon(_cloth(pts, f, sd, lx + light * 1.2, mid, 0.86, smooth), cloak)
	b.polygon(_cloth(pts, f, sd, lx + light * 3.0, mid, 0.45, smooth), Color(cloak.lightened(0.3), 0.45))
	var back: float = (pts[pts.size() / 2] as Vector2).x if style == "tattered" else (pts[4] as Vector2).x  # (the hem's furthest point)
	var w: float = lk.get("width", 1.0)
	for sgn in [-1.0, 1.0]:  # folds down the back: a crease, and the ridge beside it in the light
		var fa: Vector2 = lx + _q(f, sd, -3.0, sgn * 4.5 * w)
		var fe: Vector2 = lx + _q(f, sd, lerpf(-3.0, back, 0.82), sgn * 3.0 * w + d.y + sway * 0.8)
		b.line(fa + light * 1.1, fe + light * 1.1, Color(cloak.lightened(0.3), 0.4), 1.1)
		b.line(fa, fe, cloak.darkened(0.38), 1.3)
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
		"checked":  # squares in a grid, every other one
			for i in 4:
				for j in 3:
					if (i + j) % 2 == 0:
						var c2: Vector2 = lx + _q(f, sd, -1.5 + back * 0.2 * (i + 0.5) + d.x * 0.1 * i, (j - 1) * 4.6 * w + d.y * 0.15 * i)
						b.polygon(PackedVector2Array([c2 + _q(f, sd, -1.1, -1.1), c2 + _q(f, sd, 1.1, -1.1), c2 + _q(f, sd, 1.1, 1.1), c2 + _q(f, sd, -1.1, 1.1)]), Color(pc, 0.75))
		"fur":  # a thick pale lining showing round the edge, and the collar
			b.path(_cloth(pts, f, sd, lx + light * 0.2, mid, 0.97, smooth), ACCENTS["fur"].darkened(0.15), 2.6, true)
			b.path(_cloth(pts, f, sd, lx + light * 0.4, mid, 0.97, smooth), ACCENTS["fur"], 1.6, true)
			for sg in [-1.0, 1.0]:
				b.dot(lx + _q(f, sd, 0.5, sg * 8.0 * w), 2.0, ACCENTS["fur"])
		"quilted":  # diamonds stitched across the back
			for k in [-1.0, 0.0, 1.0]:
				b.line(lx + _q(f, sd, -2.5, k * 6.0 * w - 3.0), lx + _q(f, sd, back * 0.85, k * 6.0 * w + 4.0 + d.y * 0.6), Color(pc, 0.6), 0.7)
				b.line(lx + _q(f, sd, -2.5, k * 6.0 * w + 3.0), lx + _q(f, sd, back * 0.85, k * 6.0 * w - 4.0 + d.y * 0.6), Color(pc, 0.6), 0.7)
		"scaled":  # rows of little arcs, like a wyrm's hide
			for i in 3:
				for j in 4:
					var c3: Vector2 = lx + _q(f, sd, -2.5 + back * 0.24 * (i + 0.6), (j - 1.5) * 3.6 * w + d.y * 0.2 * i + (1.8 if i % 2 == 1 else 0.0))
					b.arc(c3, 1.7, f.angle() + PI * 0.5, f.angle() + PI * 1.5, 5, Color(pc, 0.8), 0.7)
		"spotted":  # round spots scattered over the back
			for i in 7:
				var at := Vector2(-2.5 + back * (0.18 + 0.11 * i), ((i * 37) % 5 - 2) * 3.0 * w + d.y * 0.15 * i)
				b.dot(lx + _q(f, sd, at.x, at.y), 1.2, Color(pc, 0.8))
		"halved":  # one half of the cloak in a second colour
			var half: Array = pts.map(func(q): return Vector2(q.x, maxf(q.y, 0.0)))
			b.polygon(_cloth(half, f, sd, lx + light * 1.2, mid, 0.86, false), Color(pc, 0.7))
		"runed":  # glowing glyphs down the back
			var rc: Color = ACCENTS["rune"]
			for i in 3:
				var c4: Vector2 = lx + _q(f, sd, -3.0 + back * 0.25 * (i + 1), (i - 1) * 3.0 * w + d.y * 0.25 * i)
				b.line(c4 + _q(f, sd, -1.4, 0.0), c4 + _q(f, sd, 1.4, 0.0), rc, 0.8)
				b.line(c4 + _q(f, sd, 0.0, -1.0), c4 + _q(f, sd, 1.0, 1.0), rc, 0.8)
				b.dot(c4 + _q(f, sd, -1.0, 1.0), 0.5, rc)


## The chest (body), by build, under the belt (clothes) and a pendant.
## Armour and the shoulders go on after it (the caller's gear layer).
static func draw_torso(b, lx: Vector2, f: Vector2, sd: Vector2, light: Vector2, lk: Dictionary) -> void:
	var r: float = lk.get("torso_r", 8.5)
	var c := lx + f * 2.0
	var tunic: Color = lk.get("tunic", Palette.CLIMBER_TUNIC)
	var clothes: String = lk.get("clothes", "tunic")
	# A robe's or a long coat's skirts spread round the legs, under the chest.
	if clothes == "robe":
		b.ball(c + f * -0.5, r + 3.2, tunic.darkened(0.12), true, light)
	elif clothes == "kilt":
		b.ball(c + f * -0.8, r + 1.8, lk["cloak"].darkened(0.15), true, light)
	elif clothes == "longcoat":
		for sg in [-1.0, 1.0]:
			b.poly(PackedVector2Array([c + _q(f, sd, -2.0, sg * 2.0), c + _q(f, sd, -r - 4.5, sg * 4.5), c + _q(f, sd, -r - 3.0, sg * 0.6)]), tunic.darkened(0.2), 0.8)
	b.ball(c, r, lk.get("torso", tunic), true, light)
	if lk.get("torso", tunic) == tunic:
		_tower_clothes(b, c, f, sd, lk, r)
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
		"studded":
			b.arc(c, r - 1.3, fa - 0.9, fa + 0.9, 8, col, 1.8)
			for k in 5:
				b.dot(c + Vector2.from_angle(fa + (k - 2) * 0.38) * (r - 1.3), 0.55, ACCENTS["metal"])
		"double":
			b.arc(c, r - 0.9, fa - 0.9, fa + 0.9, 8, col, 1.1)
			b.arc(c, r - 2.6, fa - 0.8, fa + 0.8, 8, col.darkened(0.15), 1.1)
		"chain":
			for k in 7:
				b.dot(c + Vector2.from_angle(fa + (k - 3) * 0.27) * (r - 1.3), 0.7, col)
		_:
			b.arc(c, r - 1.3, fa - 0.9, fa + 0.9, 8, col, 1.8)
			var metal: Color = ACCENTS["metal"] if col.get_luminance() > 0.16 else Palette.STEEL
			b.dot(c + f * (r - 1.3), 1.1, metal)
	if String(lk.get("neck", "none")) == "pendant":
		b.dot(c + f * (r - 3.4), 1.3, Palette.OUTLINE)
		b.dot(c + f * (r - 3.4), 0.9, ACCENTS["stone"])


## What the clothes show on the chest from above (not under armour): a
## vest's edges over a shirt, a jerkin's laces, a gambeson's quilting, a
## coat's collar and buttons, a robe's open neck, a wrap's crossing, a
## tabard's panel, bare shoulders without sleeves.
static func _tower_clothes(b, c: Vector2, f: Vector2, sd: Vector2, lk: Dictionary, r: float) -> void:
	var tunic: Color = lk.get("tunic", Palette.CLIMBER_TUNIC)
	var dark := tunic.darkened(0.35)
	var fa := f.angle()
	match String(lk.get("clothes", "tunic")):
		"vest":
			b.polygon(PackedVector2Array([c + _q(f, sd, r - 0.6, -1.6), c + _q(f, sd, r - 0.6, 1.6), c + _q(f, sd, 0.5, 1.2), c + _q(f, sd, 0.5, -1.2)]), ACCENTS["shirt"])
			for sg in [-1.0, 1.0]:
				b.line(c + _q(f, sd, r - 0.8, sg * 1.8), c + _q(f, sd, 0.0, sg * 3.6), dark, 1.0)
		"jerkin":
			for i in 3:
				var at := c + f * (r - 1.6 - i * 2.0)
				b.line(at + sd * 1.0 + f * 0.6, at - sd * 1.0 - f * 0.6, dark, 0.7)
				b.line(at - sd * 1.0 + f * 0.6, at + sd * 1.0 - f * 0.6, dark, 0.7)
		"gambeson":
			for k in [0.45, 0.72]:
				b.arc(c, r * k, fa - 1.4, fa + 1.4, 10, Color(0, 0, 0, 0.28), 0.8)
		"coat":
			for sg in [-1.0, 1.0]:
				b.line(c + _q(f, sd, r - 0.4, sg * 0.8), c + _q(f, sd, r - 3.0, sg * 3.4), dark, 1.2)
			for i in 2:
				b.dot(c + f * (r - 3.8 - i * 2.2), 0.6, ACCENTS["metal"])
		"longcoat":
			for sg in [-1.0, 1.0]:
				b.line(c + _q(f, sd, r - 0.4, sg * 0.6), c + _q(f, sd, r - 3.6, sg * 4.0), dark, 1.4)
			b.line(c + f * (r - 0.5), c + f * 1.0, dark, 0.8)
		"robe":
			b.polygon(PackedVector2Array([c + _q(f, sd, r - 0.3, -2.0), c + _q(f, sd, r - 0.3, 2.0), c + _q(f, sd, r - 3.4, 0.0)]), lk["skin"].darkened(0.1))
			b.arc(c, r - 0.8, fa - 0.6, fa + 0.6, 6, dark, 1.0)
		"wrap":
			b.line(c + _q(f, sd, r - 0.6, -3.0), c + _q(f, sd, 1.0, 4.5), dark, 1.3)
			b.dot(c + _q(f, sd, 1.2, 4.6), 1.0, dark)
		"tabard":
			var pc := lk["cloak"] as Color
			b.polygon(PackedVector2Array([c + _q(f, sd, r - 0.2, -2.2), c + _q(f, sd, r - 0.2, 2.2), c + _q(f, sd, -r + 0.4, 2.2), c + _q(f, sd, -r + 0.4, -2.2)]), pc.darkened(0.1))
			b.dot(c + f * (r - 3.0), 1.0, ACCENTS["metal"])
		"sleeveless":
			for sg in [-1.0, 1.0]:
				b.arc(c, r - 0.6, fa + sg * 1.05 - 0.25, fa + sg * 1.05 + 0.25, 4, lk["skin"], 1.3)
		"doublet":  # bands across the chest, a row of buttons
			for k in [0.35, 0.65]:
				b.line(c + _q(f, sd, r * k + 1.0, -r * 0.8), c + _q(f, sd, r * k + 1.0, r * 0.8), dark, 0.9)
			for i in 3:
				b.dot(c + f * (r - 1.5 - i * 1.8), 0.5, ACCENTS["shirt"])
		"kilt":  # a pleated kilt round the hips
			for i in 6:
				var a := fa + PI + (float(i) - 2.5) * 0.45
				b.line(c + Vector2.from_angle(a) * (r - 1.0), c + Vector2.from_angle(a) * (r + 1.6), dark, 1.0)


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
			"bun":  # a bun pushing the hood out behind
				b.ball(hd + f * (-7.6 + drift.x * 0.2), 3.3, hair.darkened(0.08), true, light)
			"mane":  # wild hair bursting out round the hood
				for i in 5:
					var a := f.angle() + PI + (float(i) - 2.0) * 0.55
					b.dot(hd + Vector2.from_angle(a) * 7.2 + sd * trail * 0.5, 2.1, hair.darkened(0.1) if i % 2 == 0 else hair)
			"afro":  # a great round puff pushing the hood out all round
				for i in 7:
					var a := f.angle() + PI + (float(i) - 3.0) * 0.6
					b.dot(hd + Vector2.from_angle(a) * 6.9, 2.6, hair.darkened(0.08 * (i % 2)))
			"pigtails":  # two tails out of the hood's sides
				for sg in [-1.0, 1.0]:
					b.stroke(hd + f * -1.0 + sd * sg * 5.2, hd + f * (-6.5 + drift.x * 0.3) + sd * (sg * 8.0 + trail), hair, 1.8)
			"locks":  # locks hanging out from under the hood
				for sg in [-1.0, 1.0]:
					for i in 2:
						b.stroke(hd + f * (-1.0 - i * 2.5) + sd * sg * 5.0, hd + f * (-6.0 - i * 2.5 + drift.x * 0.3) + sd * (sg * 6.4 + trail), hair, 1.2)
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
				match style:
					"crest":
						b.dot(hd + f * 2.4, 1.8, fringe)
					"swept":  # the fringe swept over to one side
						b.dot(hd + f * 2.9 + sd * 1.3, 3.3, fringe)
					"undercut":  # a long top falling forward, the sides shaved
						b.dot(hd + f * 3.2, 2.2, fringe)
					_:
						b.dot(hd + f * 2.9, 3.1, fringe)
			b.dot(hd + f * 4.5, 2.8, lk["skin"])
			if style == "swept":
				b.dot(hd + f * 4.2 + sd * 2.3, 1.4, hair)  # (falling over one eye's corner)
			elif style == "bob":  # straight hair to the jaw, either side of the face
				for s2 in [-1.0, 1.0]:
					b.dot(hd + f * 4.3 + sd * (s2 * 3.4), 1.8, hair)
			if head == "hood":
				if style == "long":
					for s in [-1.0, 1.0]:  # locks either side of the face
						b.dot(hd + f * 3.6 + sd * (s * 3.3), 1.5, hair)
				elif style == "curls":
					for s in [-1.0, 1.0]:
						b.dot(hd + f * 3.0 + sd * (s * 3.4), 1.2, hair)
						b.dot(hd + f * 4.4 + sd * (s * 3.6), 0.9, hair.darkened(0.15))
			_tower_face(b, hd, f, sd, lk, false)
			if head == "hood" and lk.get("hood_low", false):
				b.arc(hd + f * 1.2, 5.6, f.angle() - 1.0, f.angle() + 1.0, 10, hood.darkened(0.25), 2.4)
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
	var hair: Color = lk.get("beard_col", lk["hair"])
	# The beard: a crescent of hair at the chin, in front of the eyes.
	match String(lk.get("beard", "none")):
		"goatee":
			b.dot(c + f * 7.4, 1.3, hair)
		"chops":  # down the cheeks, the chin bare
			for sg in [-1.0, 1.0]:
				b.arc(c, 6.9, fa + sg * 0.95 - 0.28, fa + sg * 0.95 + 0.28, 4, hair, 2.0)
		"long":
			b.arc(c, 7.2, fa - 1.0, fa + 1.0, 10, hair, 2.6)
			b.stroke(c + f * 7.6, c + f * 11.5, hair.darkened(0.1), 2.6)
		"forked":
			b.arc(c, 7.2, fa - 1.0, fa + 1.0, 10, hair, 2.4)
			for sg in [-1.0, 1.0]:
				b.stroke(c + f * 7.8 + sd * sg * 0.8, c + f * 10.6 + sd * sg * 2.2, hair, 1.4)
		"handlebar":  # a wide moustache, curled up at the ends
			b.line(c + _q(f, sd, 7.0, 2.6), c + _q(f, sd, 7.0, -2.6), hair, 1.1)
			for sg in [-1.0, 1.0]:
				b.dot(c + _q(f, sd, 6.3, sg * 3.0), 0.7, hair)
		"chinstrap":  # a thin line of beard along the jaw
			b.arc(c, 7.0, fa - 1.25, fa + 1.25, 12, hair, 0.8)
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
	var gap := 1.85 if shape == "wide" else (0.95 if shape == "close" else 1.3)
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
			"hooded":  # a heavy fold over each eye
				b.dot(at, r * 0.85, col)
				b.line(at - f * 0.6 - sd * 0.8, at - f * 0.6 + sd * 0.8, lk["skin"].darkened(0.35), 0.5)
			"upturned":
				b.line(at - sd * s * 0.7 + f * 0.25, at + sd * s * 0.7 - f * 0.25, col, r * 1.1)
			"downturned":
				b.line(at - sd * s * 0.7 - f * 0.25, at + sd * s * 0.7 + f * 0.25, col, r * 1.1)
			"deep":  # set in shadow
				b.dot(at, r + 0.45, Color(Palette.OUTLINE, 0.35))
				b.dot(at, r * 0.7, col)
			"heavy":  # lids half down
				b.dot(at, r, col)
				b.line(at - sd * 0.9 - f * 0.3, at + sd * 0.9 - f * 0.3, lk["skin"].darkened(0.15), 0.8)
			"sharp":
				b.polygon(PackedVector2Array([at - sd * 0.95, at + f * 0.35 + sd * s * 0.3, at + sd * 0.95, at - f * 0.3]), col)
			"monolid":  # a smooth lid, no crease: a flat oval
				b.line(at - sd * 0.75, at + sd * 0.75, col, r * 0.85)
			"close":
				b.dot(at, r * 0.9, col)
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
		"nosering":
			if head != "helm":
				b.dot(hd + f * (6.6 if head == "bare" else 7.0), 0.55, ACCENTS["metal"])
		"headband":
			if head != "helm":
				var rr := 5.9 if head == "bare" else 6.7
				b.arc(hd, rr, f.angle() - 1.3, f.angle() + 1.3, 10, ACCENTS["band"], 1.2)
				if head == "bare":
					b.line(hd + f * -5.6, hd + f * (-8.4 + drift.x * 0.3) + sd * trail, ACCENTS["band"], 0.9)  # (its tails)
		"circlet":
			if head != "helm":
				b.arc(hd, 5.7 if head == "bare" else 6.5, f.angle() - 1.5, f.angle() + 1.5, 12, ACCENTS["metal"], 0.7)
				b.dot(hd + f * (5.6 if head == "bare" else 6.4), 0.8, ACCENTS["stone"])
		"mask":
			if head != "helm":
				var mc := hd + f * (5.4 if head == "bare" else 6.0)
				b.line(mc - sd * 2.6, mc + sd * 2.6, ACCENTS["patch"], 1.6)
		"spectacles":
			if head != "helm":
				var c := hd + f * (5.4 if head == "bare" else 6.0)
				var gap := 1.85 if String(lk.get("eye_shape", "")) == "wide" else 1.3
				for s in [-1.0, 1.0]:
					b.arc(c + sd * s * gap, 1.05, 0.0, TAU, 8, ACCENTS["rims"], 0.4)
				b.line(c + sd * -0.3, c + sd * 0.3, ACCENTS["rims"], 0.4)


## Hood down: the hood bunched behind the neck, the hair (or the bare scalp)
## on show, ears either side, the face in front.
static func _bare_head(b, hd: Vector2, f: Vector2, sd: Vector2, light: Vector2, lk: Dictionary, style: String, sway: float, drift: Vector2) -> void:
	var hair: Color = lk["hair"]
	var skin: Color = lk["skin"]
	var trail := sway * 0.35 + drift.y * 0.35
	# The hood, down, in folds on the shoulders behind the head (none without a cloak).
	if String(lk.get("cloak_style", "long")) != "none":
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
		"mane":  # a great wild mass all round the head
			for i in 9:
				var a := f.angle() + PI + (float(i) - 4.0) * 0.5
				b.dot(hd + Vector2.from_angle(a) * 6.2 + sd * trail * 0.4, 2.6, hair.darkened(0.12) if i % 2 == 0 else hair)
		"afro":  # a big round head of hair
			b.ball(hd + f * -0.8, 8.0, hair.darkened(0.06), true, light)
		"bob":  # straight to the jaw, all round
			b.ball(hd + f * -0.4, 6.9, hair.darkened(0.1), true, light)
		"pigtails":  # a tail at each side, tied
			for sg in [-1.0, 1.0]:
				var from2: Vector2 = hd + f * -1.0 + sd * sg * 5.0
				b.stroke(from2, from2 + f * (-5.0 + drift.x * 0.3) + sd * (sg * 3.5 + trail), hair, 2.0)
				b.dot(from2, 1.1, lk["tunic"].lightened(0.1))
		"locks":  # locks hanging down the back and sides
			for i in 6:
				var a := f.angle() + PI + (float(i) - 2.5) * 0.42
				var from := hd + Vector2.from_angle(a) * 4.5
				b.stroke(from, from + Vector2.from_angle(a) * 5.0 + f * (drift.x * 0.3) + sd * trail, hair.darkened(0.08 * (i % 2)), 1.4)
	if not style in ["long", "mane", "locks", "afro", "bob"]:
		for s in [-1.0, 1.0]:  # ears
			b.dot(hd + f * 1.0 + sd * (s * 5.6), 1.5, Palette.OUTLINE)
			b.dot(hd + f * 1.0 + sd * (s * 5.6), 1.0, skin.darkened(0.1))
	var top := hair
	match style:
		"none", "crest", "undercut":
			top = skin
		"cropped":
			top = hair.lerp(skin, 0.4)
	b.ball(hd, 5.8, top, true, light)
	match style:
		"bun":  # a bun at the crown
			b.ball(hd + f * -2.4, 2.9, hair.darkened(0.1), true, light)
			b.line(hd + f * -2.4 + sd * -3.0, hd + f * -2.4 + sd * 3.0, ACCENTS["metal"].darkened(0.2), 0.6)
		"undercut":  # a wide strip of long hair on top, swept to one side
			b.poly(PackedVector2Array([hd + f * 3.4 + sd * -2.0, hd + f * 3.4 + sd * 2.4, hd + f * -5.0 + sd * 3.4, hd + f * -5.4 + sd * -1.4]), hair, 0.8)
		"swept":
			b.dot(hd + f * 1.0 + sd * 2.2, 3.4, hair.darkened(0.1))
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
	var style: String = lk.get("cloak_style", "long")
	var r := 12.0 * float(ROLLED.get(style, 1.0)) * sqrt(float(lk.get("width", 1.0)))
	if style == "none":  # no cloak: curled up in your clothes
		b.ball(Vector2.ZERO, r, lk.get("tunic", cloak), true, light)
		b.line(fwd * cos(spin) * r * 0.6 + across * r * 0.6, fwd * cos(spin) * r * 0.6 - across * r * 0.6, lk.get("tunic", cloak).darkened(0.3), 1.6)
		return
	b.ball(Vector2.ZERO, r, cloak, true, light)
	var pc := pattern_color(lk)
	var pattern: String = lk.get("pattern", "plain")
	match pattern:
		"checked":
			for i in 4:
				var at := Vector2.from_angle(spin + i * TAU / 4.0) * r * 0.45
				b.polygon(PackedVector2Array([at + Vector2(-1.4, -1.4), at + Vector2(1.4, -1.4), at + Vector2(1.4, 1.4), at + Vector2(-1.4, 1.4)]), pc)
		"fur":
			b.arc(Vector2.ZERO, r - 0.6, 0.0, TAU, 20, ACCENTS["fur"], 2.4)
		"quilted":
			b.line(Vector2.from_angle(spin) * r * 0.8, Vector2.from_angle(spin + PI) * r * 0.8, Color(pc, 0.6), 0.8)
			b.line(Vector2.from_angle(spin + PI * 0.5) * r * 0.8, Vector2.from_angle(spin + PI * 1.5) * r * 0.8, Color(pc, 0.6), 0.8)
		"scaled":
			for i in 6:
				b.arc(Vector2.from_angle(spin + i * TAU / 6.0) * r * 0.55, 1.8, spin, spin + PI, 5, pc, 0.8)
		"spotted":
			for i in 5:
				b.dot(Vector2.from_angle(spin * 1.3 + i * 1.7) * r * (0.3 + 0.1 * i), 1.3, pc)
		"halved":
			var hp := PackedVector2Array()
			for i in 9:
				hp.append(Vector2.from_angle(spin + PI * float(i) / 8.0) * (r - 0.5))
			b.polygon(hp, Color(pc, 0.7))
		"runed":
			for i in 3:
				var at2 := Vector2.from_angle(spin + i * TAU / 3.0) * r * 0.5
				b.line(at2 + Vector2(-1.2, 0), at2 + Vector2(1.2, 0), ACCENTS["rune"], 0.8)
				b.line(at2 + Vector2(0, -1.2), at2 + Vector2(0.8, 1.2), ACCENTS["rune"], 0.8)
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
	if style == "tattered":
		for i in 4:
			var a := spin + i * TAU / 4.0
			b.line(Vector2.from_angle(a) * (r - 0.5), Vector2.from_angle(a) * (r + 2.2), cloak.darkened(0.25), 1.6)


## How big the rolled-up cloak is, by style (a share of a long cloak's).
static var ROLLED := {"long": 1.0, "short": 0.94, "tattered": 1.0, "mantle": 0.88, "half": 0.9, "shawl": 0.92, "poncho": 0.97,
	"wrapped": 0.86, "capelet": 0.84, "cowl": 0.82, "trailing": 1.06, "none": 0.8}


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
	if shape.size() < 3:
		return  # (no cloak: the clothes show, drawn by the caller)
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
		"checked":
			for i in 3:
				for j in 3:
					if (i + j) % 2 == 0:
						var c := _q(f, sd, -4.0 - i * 4.0, (j - 1) * 5.0)
						b.polygon(PackedVector2Array([c + _q(f, sd, -1.3, -1.3), c + _q(f, sd, 1.3, -1.3), c + _q(f, sd, 1.3, 1.3), c + _q(f, sd, -1.3, 1.3)]), Color(pc, 0.75))
		"fur":
			b.path(_cloth(shape, f, sd, light * 0.4, Vector2(-6.0, 0.0), 0.95, smooth), ACCENTS["fur"], 2.2, true)
		"quilted":
			for k in [-1.0, 1.0]:
				b.line(_q(f, sd, -3.0, -8.0 * k), _q(f, sd, -15.0, 8.0 * k), Color(pc, 0.6), 0.8)
		"scaled":
			for i in 3:
				for j in 3:
					b.arc(_q(f, sd, -5.0 - i * 4.0, (j - 1) * 5.0), 1.8, f.angle() + PI * 0.5, f.angle() + PI * 1.5, 5, Color(pc, 0.8), 0.7)
		"spotted":
			for i in 6:
				b.dot(_q(f, sd, -4.0 - (i % 3) * 4.5, (i / 3 - 0.5) * 7.0 + (i % 2) * 1.5), 1.3, Color(pc, 0.8))
		"halved":
			var hs: Array = shape.map(func(q): return Vector2(q.x, maxf(q.y, 0.0)))
			b.polygon(_cloth(hs, f, sd, light * 1.5, Vector2(-6.0, 0.0), 0.8, false), Color(pc, 0.7))
		"runed":
			for i in 3:
				var c2 := _q(f, sd, -5.0 - i * 4.0, (i - 1) * 3.0)
				b.line(c2 + _q(f, sd, -1.4, 0.0), c2 + _q(f, sd, 1.4, 0.0), ACCENTS["rune"], 0.8)
				b.line(c2 + _q(f, sd, 0.0, -1.0), c2 + _q(f, sd, 1.0, 1.0), ACCENTS["rune"], 0.8)
	if lk.get("trim_on", false):
		b.path(_cloth(shape, f, sd, light * 0.6, Vector2(-6.0, 0.0), 0.92, smooth), lk["trim"], 1.3, true)


# --- the climber screen: the figure, seen from the front -------------------------
# The figure's frame is about 290 tall, centred on the waist, lit from the
# top-left (the left side of each piece paler, the right darker). Its marks
# sit at fixed spots (menu.gd BodyView.SPOTS), so the build widens the chest
# and shoulders but leaves the head and hands where they are.

## The whole front figure, in layers (see the top of the file).
static func draw_front(b, lk: Dictionary) -> void:
	b.begin_form(FRONT_FORM, Shade.FORM)  # the whole figure lit from the left (shade.gd)
	_draw_front(b, lk)
	b.end_form()


## The front figure's frame for its overall light (shade.gd FORM).
const FRONT_FORM := Rect2(-72, -150, 144, 290)


static func _draw_front(b, lk: Dictionary) -> void:
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
	# Shade where the arms meet the body (the arms go over the middle of it).
	var wx: float = lk.get("wx", 1.0)
	for sg in [-1.0, 1.0]:
		b.soft(Vector2(sg * 27.0 * wx, -36.0), Vector2(11.0, 30.0), Color(0, 0, 0, 0.3 if sg > 0.0 else 0.2))
	_front_arms(b, lk)  # body: arms in their sleeves, hands
	if String(lk.get("cloak_style", "long")) == "poncho":
		# A poncho over the upper arms, the hands out from under it: what's
		# on the arms goes under it, what's in (or on) the hands over it.
		if gear:
			GearLook.front_sleeves(b, lk)  # gear: armour on the arms, a holster
		_front_mantle(b, lk)  # clothes: the poncho
		if gear:
			GearLook.front_hands(b, lk)  # gear: the weapon in hand, gloves, rings
	else:
		if gear:
			GearLook.front_arms(b, lk)  # gear: the weapon in hand, gloves, rings
		_front_mantle(b, lk)  # clothes: the cloak's mantle over the shoulders
	if gear:
		GearLook.front_shoulders(b, lk)  # gear: pauldrons, the amulet
	b.soft(Vector2(3.0, -74.0), Vector2(30.0, 11.0), Color(0, 0, 0, 0.32))  # the head's shadow on the shoulders
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
		"mantle", "none":
			return PackedVector2Array()
		"half":  # hanging from one shoulder
			return _p([-30, -68, -2, -68, 4, -20, 8, 40, 4, 100, -14, 110, -30, 104, -48, 108, -64, 100, -56, 40, -46, -20])
		"shawl":  # to the waist
			return _p([-30, -68, 30, -68, 46, -20, 50, 6, 30, 13, 0, 9, -30, 13, -50, 6, -46, -20])
		"poncho":  # (all of it in front: _front_mantle; its back hides behind)
			return PackedVector2Array()
		"wrapped":  # long and drawn in close
			return _p([-26, -68, 26, -68, 38, -20, 44, 40, 48, 104, 30, 110, 0, 106, -30, 110, -48, 104, -44, 40, -38, -20])
		"capelet":  # to the shoulder blades
			return _p([-30, -68, 30, -68, 44, -32, 46, -12, 24, -5, 0, -9, -24, -5, -46, -12, -44, -32])
		"cowl":  # all collar: nothing hangs behind
			return PackedVector2Array()
		"trailing":  # long, sweeping the floor behind the feet
			return _p([-30, -68, 30, -68, 48, -20, 60, 40, 72, 108, 82, 128, 42, 133, 0, 129, -42, 133, -82, 128, -72, 108, -60, 40, -48, -20])
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
	var small := style == "shawl" or style == "capelet"  # (too short for folds)
	var folds := [[-40, 0, -46, 38], [-27, 10, -30, 40], [32, 6, 36, 38], [46, 8, 50, 38]] if short else [[-40, 18, -52, 100], [-27, 30, -33, 104], [32, 24, 40, 100], [46, 30, 56, 98]]
	if style == "half":
		folds = [[-40, 18, -52, 100], [-27, 30, -33, 104]]
	if small:
		folds = []
	var fk := wc * (0.78 if style == "wrapped" else 1.0)  # (a wrapped cloak hangs closer: its folds too)
	for fl in folds:  # each fold: its crease, and the ridge beside it catching the light
		b.line(Vector2(fl[0] * fk - 2.6, fl[1] + 2.0), Vector2(fl[2] * fk - 3.0, fl[3] - 2.0), Color(cloak.lightened(0.28), 0.32), 2.2)
		b.line(Vector2(fl[0] * fk, fl[1]), Vector2(fl[2] * fk, fl[3]), Color(cloak.darkened(0.5), 0.75), 1.8)
		b.line(Vector2(fl[0] * fk + 1.8, fl[1] + 2.0), Vector2(fl[2] * fk + 2.2, fl[3] - 2.0), Color(cloak.darkened(0.3), 0.3), 2.0)
	if short:
		b.line(Vector2(-50 * fk, 8), Vector2(-52 * fk, 28), Color(cloak.lightened(0.3), 0.35), 1.4)
	elif not small:
		b.line(Vector2(-58 * fk, 50), Vector2(-62 * fk, 98), Color(cloak.lightened(0.3), 0.35), 1.4)
	_front_pattern(b, lk, out, short or small)
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
		"checked":
			var y := -70.0
			var row := 0
			while y < 120.0:
				var x2 := -72.0 + (10.0 if row % 2 == 1 else 0.0)
				while x2 < 72.0:
					_fill_in(b, out, _p([x2, y, x2 + 10, y, x2 + 10, y + 10, x2, y + 10]), Color(pc, 0.55))
					x2 += 20.0
				y += 10.0
				row += 1
		"fur":
			b.path(out, ACCENTS["fur"].darkened(0.2), 6.0, true)
			b.path(out, ACCENTS["fur"], 3.6, true)
		"spotted":
			for i in 40:
				var at := Vector2(-66.0 + float((i * 29) % 133), -60.0 + float((i * 47) % 185))
				if Geometry2D.is_point_in_polygon(at, out):
					b.dot(at, 3.0 + float(i % 3), Color(pc, 0.7))
		"halved":
			_fill_in(b, out, _p([0, -90, 100, -90, 100, 150, 0, 150]), Color(pc, 0.6))
		"quilted":
			var q := -150.0
			while q <= 150.0:
				_fill_in(b, out, _p([q - 0.9, -80, q + 0.9, -80, q + 0.9 + 110, 130, q - 0.9 + 110, 130]), Color(pc, 0.55))
				_fill_in(b, out, _p([q - 0.9, -80, q + 0.9, -80, q + 0.9 - 110, 130, q - 0.9 - 110, 130]), Color(pc, 0.55))
				q += 16.0
		"scaled":
			var sy := -60.0
			var srow := 0
			while sy < 120.0:
				var sx := -66.0 + (4.0 if srow % 2 == 1 else 0.0)
				while sx < 70.0:
					var arc := PackedVector2Array()
					for i in 7:
						var a := PI * float(i) / 6.0
						arc.append(Vector2(sx + cos(a) * 4.0, sy + sin(a) * 3.6))
					for piece in Geometry2D.intersect_polyline_with_polygon(arc, out):
						b.path(piece, Color(pc, 0.75), 1.0)
					sx += 9.0
				sy += 7.0
				srow += 1
		"runed":
			var hem2 := _hem_line(out, -9.0)
			for i in range(0, hem2.size(), 2):
				var c2 := hem2[i]
				b.line(c2 + Vector2(-2.5, -2.5), c2 + Vector2(2.5, 2.5), ACCENTS["rune"], 1.2)
				b.line(c2 + Vector2(0, -3.5), c2 + Vector2(0, 3.5), ACCENTS["rune"], 1.2)
				b.dot(c2 + Vector2(3.0, -2.5), 0.9, ACCENTS["rune"])
			for x3 in [-50.0, 50.0]:  # and up the sides
				var c3 := Vector2(x3, 10.0 if not short else -10.0)
				b.line(c3 + Vector2(-2.5, 0), c3 + Vector2(2.5, 0), ACCENTS["rune"], 1.2)
				b.line(c3 + Vector2(-1.5, -3), c3 + Vector2(1.5, 3), ACCENTS["rune"], 1.2)


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
	var dy := (float(lk.get("leg_k", 1.0)) - 1.0) * 60.0  # (the build: longer or shorter legs, the feet lower or higher)
	for sg in [-1.0, 1.0]:
		var shade := 0.22 if sg < 0.0 else 0.38
		b.poly(_sx(_p([sg * 3, 10, sg * 17, 10, sg * 16, 96 + dy, sg * 4, 96 + dy]), k), legs.darkened(shade), 1.4)
		b.poly(_shift(_sx(_p([sg * 2.5, 92, sg * 17.5, 92, sg * 18, 110, sg * 22, 124, sg * 1, 124, sg * 2, 110]), k), Vector2(0, dy)), boot if sg < 0.0 else boot.darkened(0.25), 1.4)
		b.rect(Rect2(Vector2(minf(sg * 2.5, sg * 17.5) * k, 92 + dy), Vector2(15 * k, 4)), boot.lightened(0.22))
		b.line(Vector2(sg * 4 * k, 121 + dy), Vector2(sg * 15 * k, 121 + dy), Color(boot.lightened(0.3), 0.5), 1.2)


## How far out a Poncho's sides reach on the front figure: just past the
## elbows (which spread with the build), so it covers the upper arms.
static func poncho_side(wx: float) -> float:
	return 20.0 + 30.0 * wx


## How wide the neck is (half its width) on the front figure: thicker on a
## broad build or a masculine body, slimmer on a slight or feminine one.
static func neck_w(lk: Dictionary) -> float:
	var wx: float = lk.get("wx", 1.0)
	var add := {"masculine": 0.7, "feminine": -0.6}.get(String(lk.get("body", "")), 0.0) as float
	return clampf(6.0 * (1.0 + (wx - 1.0) * 0.7) + add, 4.4, 8.8)


## The neck, from under the chin (`top`) down into the chest (`bottom`),
## flaring into the shoulders; lit on the left, a shadow under the jaw. The
## clothes are drawn over it, so it shows only where the neckline opens.
static func _front_neck(b, lk: Dictionary, top: float, bottom: float) -> void:
	var skin: Color = lk["skin"]
	var nw := neck_w(lk)
	var dim := 0.18 if lk.get("hood_up", false) else 0.0  # (in the hood's shadow)
	var neck := _p([-nw, top, nw, top, nw, -82, nw + 5.0, -73, 13, -60, 13, bottom, -13, bottom, -13, -60, -nw - 5.0, -73, -nw, -82])
	b.poly(neck, skin.darkened(0.22 + dim), 1.2)
	b.polygon(_p([-nw, top, -1.5, top, -1.5, bottom, -13, bottom, -13, -60, -nw - 5.0, -73, -nw, -82]), skin.darkened(0.08 + dim))
	b.polygon(_p([-nw, top, nw, top, nw, -84, 0, -82, -nw, -84]), Color(skin.darkened(0.45), 0.55))  # under the jaw


## The clothes' neckline, left to right, between the shoulders' tops: round
## (a tunic), a laced slit (a jerkin), a V (a robe deep, a coat's showing
## its shirt, a vest's), or a wrap's crossing.
static func _neckline(lk: Dictionary) -> PackedVector2Array:
	var nw := neck_w(lk) + 1.5
	var wx: float = lk.get("wx", 1.0)
	match String(lk.get("clothes", "tunic")):
		"robe":
			return _p([-nw, -77, 0, -47, nw, -77])
		"coat", "longcoat":
			return _p([-nw, -77, 0, -55, nw, -77])
		"vest":
			return _p([-nw, -77, 0, -64, nw, -77])
		"wrap":  # the left side crossing over to the right hip
			var a := Vector2(-nw, -77)
			var t := 22.0 / 85.0
			return PackedVector2Array([a, a.lerp(Vector2(22 * wx, 8), t), Vector2(nw, -77)])
		"jerkin":
			return _p([-nw, -77, -2.6, -72.5, 0, -63, 2.6, -72.5, nw, -77])
	return _p([-nw, -77, -nw * 0.55, -73.5, 0, -72.2, nw * 0.55, -73.5, nw, -77])


## Over the neckline, by the clothes: a round neckband, a standing collar
## (a gambeson's padded one, a doublet's), a coat's shirt and its collar
## points, a vest's shirt collar, a robe's edging.
static func _front_collar(b, lk: Dictionary, nl: PackedVector2Array) -> void:
	var tunic: Color = lk["tunic"]
	var nw := neck_w(lk)
	var clothes: String = lk.get("clothes", "tunic")
	match clothes:
		"gambeson", "doublet":
			var col := _p([-nw - 1.6, -84, nw + 1.6, -84, nw + 3.4, -75, nw * 0.6, -72.6, 0, -72, -nw * 0.6, -72.6, -nw - 3.4, -75])
			b.poly(col, tunic.darkened(0.18), 1.4)
			b.polygon(_p([-nw - 1.6, -84, 0, -84, 0, -72, -nw * 0.6, -72.6, -nw - 3.4, -75]), tunic.darkened(0.02))
			if clothes == "gambeson":  # quilted
				for y in [-80.5, -76.5]:
					b.line(Vector2(-nw - 2.2, y), Vector2(nw + 2.2, y), Color(tunic.darkened(0.45), 0.6), 1.0)
			else:  # a pale edge
				b.line(Vector2(-nw - 1.4, -83.2), Vector2(nw + 1.4, -83.2), Color(ACCENTS["shirt"], 0.8), 1.2)
		"coat", "longcoat":
			var v := PackedVector2Array(nl)
			b.polygon(v, ACCENTS["shirt"].darkened(0.06))
			b.polygon(_p([-nw * 0.95, -80, nw * 0.95, -80, nw * 0.8, -73, 0, -68.5, -nw * 0.8, -73]), lk["skin"].darkened(0.14))  # the throat
			for sg in [-1.0, 1.0]:  # the shirt's collar points
				b.poly(_p([sg * (nw + 1.2), -78, sg * (nw - 0.6), -70.5, sg * 1.0, -68.5, sg * (nw * 0.75), -75]), ACCENTS["shirt"] if sg < 0.0 else ACCENTS["shirt"].darkened(0.12), 1.0)
		"vest":
			for sg in [-1.0, 1.0]:
				b.poly(_p([sg * (nw + 1.4), -78, sg * (nw + 0.2), -71.5, sg * 1.2, -64.5, sg * (nw * 0.6), -74.5]), ACCENTS["shirt"] if sg < 0.0 else ACCENTS["shirt"].darkened(0.12), 1.0)
		"robe", "wrap":
			b.path(nl, tunic.darkened(0.42), 1.6)
		_:
			b.path(nl, Palette.OUTLINE, 4.2)
			b.path(nl, tunic.darkened(0.3) if clothes != "sleeveless" else tunic.darkened(0.22), 2.2)


## The neck, then the tunic over it (shoulders sloping from the neck, its
## neckline open on the neck), a skirt below the belt, its collar, and the
## belt (a leather belt and buckle, a sash knotted at the hip, or a rope).
static func _front_tunic(b, lk: Dictionary) -> void:
	var tunic: Color = lk["tunic"]
	var wx: float = lk.get("wx", 1.0)
	var clothes: String = lk.get("clothes", "tunic")
	var body: String = lk.get("body", "androgynous")
	# The waist and hips by the body: drawn in at the waist and out at the
	# hips (feminine), straighter and squarer (masculine).
	var waist := 21.0 + (-2.5 if body == "feminine" else (1.5 if body == "masculine" else 0.0))
	var hip := 26.0 + (3.0 if body == "feminine" else (-1.0 if body == "masculine" else 0.0))
	# The skirts below the belt: to the knees for a long coat, the ankles for a robe.
	var hem := 38.0
	match clothes:
		"coat", "gambeson":
			hem = 50.0
		"longcoat":
			hem = 80.0
		"robe":
			hem = 112.0
		"tabard":
			hem = 54.0
		"doublet":
			hem = 44.0
		"kilt":
			hem = 62.0
	# The neck first (down into the chest: the neckline shows what it opens on).
	_front_neck(b, lk, -93.0, -40.0)
	var nl := _neckline(lk)
	var nw := neck_w(lk)
	# The chest: shoulders sloping from the neck, the neckline cut at the top.
	var chest := _sx(_p([-24, -24, -29, -64, -25, -72.5, -18, -75.5]), wx)
	chest.append(Vector2(-(nw + 4.0), -77.5))
	chest.append_array(nl)
	chest.append(Vector2(nw + 4.0, -77.5))
	chest.append_array(_sx(_p([18, -75.5, 25, -72.5, 29, -64, 24, -24, waist, 16, -waist, 16]), wx))
	b.poly(chest, tunic.darkened(0.14), 1.6)
	_fill_in(b, chest, _p([-90, -100, 1, -100, 1, 20, -90, 20]), tunic)
	b.line(Vector2(-20 * wx, -73.5), Vector2(-27 * wx, -68), Color(tunic.lightened(0.22), 0.6), 1.6)  # the lit shoulder
	if clothes == "vest":  # a pale shirt, the vest open over it
		var shirt := PackedVector2Array([Vector2(-(nw + 4.0), -77.5)])
		shirt.append_array(nl)
		shirt.append_array(PackedVector2Array([Vector2(nw + 4.0, -77.5), Vector2(10 * wx, -68), Vector2(7 * wx, 16), Vector2(-7 * wx, 16), Vector2(-10 * wx, -68)]))
		b.polygon(shirt, ACCENTS["shirt"])
		for sg in [-1.0, 1.0]:
			b.line(Vector2(sg * (nw + 3.5), -77), Vector2(sg * 6 * wx, 14), tunic.darkened(0.4), 1.4)
	b.poly(_sx(_p([-waist, 14, waist, 14, hip + (hem - 38.0) * 0.18, hem, -hip - (hem - 38.0) * 0.18, hem]), wx), tunic.darkened(0.16), 1.4)
	b.polygon(_sx(_p([-waist, 14, 0, 14, 0, hem, -hip - (hem - 38.0) * 0.18, hem]), wx), tunic.darkened(0.04))
	_front_clothes(b, lk, clothes, wx, hem)
	_front_collar(b, lk, nl)
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
		"studded":
			b.rect(Rect2(-hw - 1.4, 4.6, hw * 2.0 + 2.8, 11.8), UI.OUTLINE)
			b.rect(Rect2(-hw, 6, hw * 2.0, 9), col)
			var x2 := -hw + 3.0
			while x2 < hw - 1.0:
				b.dot(Vector2(x2, 10.5), 1.3, ACCENTS["metal"])
				x2 += 5.0
		"double":
			for y2 in [3.5, 12.0]:
				b.rect(Rect2(-hw - 1.2, y2 - 1.2, hw * 2.0 + 2.4, 7.4), UI.OUTLINE)
				b.rect(Rect2(-hw, y2, hw * 2.0, 5), col if y2 < 5.0 else col.darkened(0.15))
			for y3 in [6.0, 14.5]:
				b.rect(Rect2(-12.0 if y3 < 10.0 else 6.0, y3 - 3.0, 6, 6), ACCENTS["metal"].darkened(0.2))
		"chain":
			var x3 := -hw
			var k3 := 0
			while x3 < hw:
				b.poly(_oval(Vector2(x3 + 2.5, 10.0), Vector2(3.0, 2.0) if k3 % 2 == 0 else Vector2(2.0, 1.4), 8), col if k3 % 2 == 0 else col.darkened(0.2), 1.0)
				x3 += 4.2
				k3 += 1
		_:
			b.rect(Rect2(-hw - 1.4, 4.6, hw * 2.0 + 2.8, 11.8), UI.OUTLINE)
			b.rect(Rect2(-hw, 6, hw * 2.0, 9), col)
			b.rect(Rect2(-hw, 6, hw * 2.0, 2.4), col.lightened(0.2))
			var metal: Color = UI.GOLD.darkened(0.2) if col.get_luminance() > 0.16 else Palette.STEEL
			b.rect(Rect2(-5.4, 3.6, 10.8, 13.8), UI.OUTLINE)
			b.rect(Rect2(-4, 5, 8, 11), metal)
			b.rect(Rect2(-1.6, 7.4, 3.2, 6.2), col)


## What each kind of clothes adds over the tunic's shape (front): laces,
## quilting, lapels and buttons, a robe's open neck, a wrap's crossing, a
## tabard's panel. `hem` is how far down the skirts reach.
static func _front_clothes(b, lk: Dictionary, clothes: String, wx: float, hem: float) -> void:
	var tunic: Color = lk["tunic"]
	var dark := tunic.darkened(0.45)
	match clothes:
		"jerkin":
			for i in 6:
				var y := -60.0 + i * 11.0
				b.line(Vector2(-3, y), Vector2(3, y + 5.5), Color(0.85, 0.75, 0.55), 1.2)
				b.line(Vector2(3, y), Vector2(-3, y + 5.5), Color(0.85, 0.75, 0.55), 1.2)
			for sg in [-1.0, 1.0]:
				b.line(Vector2(sg * 4 * wx, -70), Vector2(sg * 4 * wx, 14), dark, 1.2)
		"gambeson":
			var y2 := -56.0
			while y2 < hem:
				var w2 := (25.0 if y2 < 14.0 else 24.0) * wx
				b.line(Vector2(-w2, y2), Vector2(w2, y2), Color(dark, 0.55), 1.0)
				y2 += 9.0
			b.line(Vector2(-10 * wx, -72), Vector2(-11 * wx, hem), Color(dark, 0.45), 1.0)
			b.line(Vector2(10 * wx, -72), Vector2(11 * wx, hem), Color(dark, 0.45), 1.0)
		"coat", "longcoat":
			var nw := neck_w(lk) + 1.5
			for sg in [-1.0, 1.0]:  # lapels, folded back along the neckline
				b.poly(_p([sg * nw, -77, sg * (nw + 8.0) * wx, -74.5, sg * 11 * wx, -44, sg * 1.5, -38, sg * 0.8, -55]), tunic.lightened(0.08) if sg < 0.0 else tunic.darkened(0.2), 1.2)
			b.line(Vector2(0, 14), Vector2(0, hem), dark, 1.4)  # the skirts open at the front
			for i in 3:
				b.dot(Vector2(-4.5, -30 + i * 12), 1.6, ACCENTS["metal"].darkened(0.15))
			if clothes == "longcoat":
				for sg in [-1.0, 1.0]:
					b.line(Vector2(sg * 14 * wx, 30), Vector2(sg * 18 * wx, hem - 4), Color(dark, 0.6), 1.2)
		"robe":
			b.line(Vector2(-6, 18), Vector2(-9, hem - 2), Color(dark, 0.6), 1.2)
			b.line(Vector2(8, 18), Vector2(12, hem - 2), Color(dark, 0.6), 1.2)
		"wrap":
			var top := Vector2(-(neck_w(lk) + 1.5), -77)
			b.polygon(PackedVector2Array([Vector2(-24 * wx, -70), Vector2(-18 * wx, -75), top, Vector2(22 * wx, 8), Vector2(21 * wx, 16), Vector2(10 * wx, 16)]), tunic.darkened(0.12))
			b.line(top, Vector2(22 * wx, 8), dark, 1.6)
		"tabard":
			var pc: Color = lk["cloak"]
			var tn := neck_w(lk) + 1.5
			b.poly(_p([-13, -75.5, -tn, -77, -tn * 0.55, -73.5, 0, -72.2, tn * 0.55, -73.5, tn, -77, 13, -75.5, 12, hem - 2, 0, hem + 4, -12, hem - 2]), pc.darkened(0.08), 1.4)
			b.polygon(_p([-13, -75.5, -tn, -77, -tn * 0.55, -73.5, 0, -72.2, 0, hem + 4, -12, hem - 2]), pc.lightened(0.06))
			b.ball(Vector2(0, -30), 5.0, ACCENTS["metal"].darkened(0.1))  # its emblem
			b.dot(Vector2(0, -30), 2.2, pc.darkened(0.3))
		"sleeveless":
			for sg in [-1.0, 1.0]:  # the armholes' edges
				b.line(Vector2(sg * 23 * wx, -74), Vector2(sg * 24 * wx, -44), dark, 1.6)
		"doublet":  # puffed shoulders, slashes showing a pale lining, a row of buttons
			for sg in [-1.0, 1.0]:
				b.ball(Vector2(sg * 27 * wx, -62), 8.0, tunic.lightened(0.08) if sg < 0.0 else tunic.darkened(0.15))
				for k in 3:
					b.line(Vector2(sg * (10 + k * 5) * wx, -58), Vector2(sg * (11 + k * 5) * wx, -44), ACCENTS["shirt"], 1.4)
			for i in 6:
				b.dot(Vector2(0, -60 + i * 11), 1.5, ACCENTS["metal"].darkened(0.1))
		"kilt":  # a pleated kilt in the cloak's colour, a stripe of the trim's
			var kc: Color = lk["cloak"]
			b.poly(_sx(_p([-23, 16, 23, 16, 30, hem, -30, hem]), wx), kc.darkened(0.12), 1.4)
			for i in 7:
				var x: float = (-18.0 + i * 6.0) * wx
				b.line(Vector2(x, 18), Vector2(x * 1.25, hem - 1), Color(kc.darkened(0.45), 0.8), 1.2)
			b.line(Vector2(-26 * wx, 40), Vector2(26 * wx, 40), pattern_color(lk), 2.4)


## Arms in their sleeves (bare without), hands out of the cloak (at the hand mark's spot).
static func _front_arms(b, lk: Dictionary) -> void:
	var skin: Color = lk["skin"]
	var bare: bool = String(lk.get("clothes", "tunic")) == "sleeveless"
	var tunic: Color = skin.darkened(0.05) if bare else lk["tunic"]
	var wx: float = lk.get("wx", 1.0)
	var thick := (1.0 + (wx - 1.0) * 0.6) * (0.85 if bare else 1.0)
	for sg in [-1.0, 1.0]:
		var sh := Vector2(sg * 28 * wx, -60)
		var el := Vector2(sg * (40 + (wx - 1.0) * 26.0), -24)
		var wr := Vector2(sg * 48, 1)
		var col := tunic if sg < 0.0 else tunic.darkened(0.2)
		# One limb through the joints, so the shoulder is round and the
		# elbow bends without a seam (draw_util.gd limb).
		b.limb(PackedVector2Array([sh, el, wr]), PackedFloat32Array([13.0 * thick, 11.0 * thick]), col)
		b.line(sh + Vector2(-3.5, 1), el + Vector2(-4, 0), Color(col.lightened(0.25), 0.6), 2.0)
		if not bare:  # the cuff: an edge where it starts, the hand over its end
			var d := (wr - el).normalized()
			b.line(wr - d * 4.2, wr + d * 2.0, Palette.OUTLINE, 12.0 * thick + 2.4)
			b.line(wr - d * 3.0, wr + d * 2.0, col.darkened(0.28), 12.0 * thick)
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
	var style: String = lk.get("cloak_style", "long")
	if style == "none":
		return  # (no cloak: the clothes' shoulders show)
	if style == "half":  # over one shoulder, a strap across the chest
		var hc := _sx(_p([-2, -80, -14, -80, -38, -66, -50, -38, -48, -20, -34, -14, -20, -22, -10, -40, -4, -62]), wx)
		var band := _sx(_p([-6, -81, 12, -81, 25, -75, 31, -67, 21, -67, 11, -73, -4, -73]), wx)  # its collar round the back of the neck, onto the other shoulder
		b.poly(band, cloak.darkened(0.32), 1.4)
		b.poly(hc, cloak.darkened(0.14), 1.6)
		b.polygon(_sx(_p([-14, -78, -36, -65, -46, -40, -40, -34, -26, -60]), wx), cloak.lightened(0.06))
		b.stroke(Vector2(-8 * wx, -66), Vector2(22 * wx, 8), cloak.darkened(0.35), 4.0)
		b.ball(Vector2(-8 * wx, -66), 3.0, UI.GOLD.darkened(0.15))
		edges.append(hc)
		hems.append(_sx(_p([-48, -22, -34, -16, -20, -24, -10, -41]), wx))
	elif style == "shawl":  # draped round the shoulders, crossing low on the chest
		var sw := _sx(_p([-46, -50, -36, -70, -14, -80, 14, -80, 36, -70, 46, -50, 42, -28, 22, -36, 0, -18, -22, -36, -42, -28]), wx)
		b.poly(sw, cloak.darkened(0.12), 1.6)
		b.polygon(_sx(_p([-46, -50, -36, -70, -14, -80, 0, -80, 0, -18, -22, -36, -42, -28]), wx), cloak.lightened(0.05))
		b.line(Vector2(-30 * wx, -52), Vector2(-4, -22), Color(cloak.darkened(0.45), 0.7), 1.4)
		edges.append(sw)
		hems.append(_sx(_p([-42, -28, -22, -36, 0, -18, 22, -36, 42, -28]), wx))
	elif style == "poncho":  # over the shoulders and upper arms, pointed to the hips, a fringe on its hem
		# Its sides fall over the elbows, so the forearms and hands (and
		# what they hold: draw_front) come out from under it.
		var s := poncho_side(wx)
		var half := [Vector2(-14 * wx, -80), Vector2(-(s - 6.0), -62), Vector2(-s, -44), Vector2(-s, -34),
			Vector2(-(s - 9.0), -27), Vector2(-s * 0.6, -2), Vector2(-s * 0.3, 20), Vector2(0, 30)]
		var pn := PackedVector2Array(half)
		for i in range(half.size() - 2, -1, -1):
			pn.append(Vector2(-half[i].x, half[i].y))
		var lit := PackedVector2Array(half)
		lit.append(Vector2(0, -80))
		b.poly(pn, cloak.darkened(0.12), 1.6)
		b.polygon(lit, cloak.lightened(0.04))
		for sg in [-1.0, 1.0]:  # its folds, falling from the shoulders
			b.line(Vector2(sg * (s - 18.0), -60), Vector2(sg * s * 0.5, 4), Color(cloak.darkened(0.45), 0.6), 1.4)
			b.line(Vector2(sg * (s - 8.0), -54), Vector2(sg * (s - 5.0), -34), Color(cloak.darkened(0.45), 0.5), 1.2)
		var hem := PackedVector2Array()
		for i in range(3, pn.size() - 3):
			hem.append(pn[i])
		var fringe := cloak.darkened(0.3)
		for i in hem.size() - 1:  # the fringe, every few pixels along the hem
			var n := int(ceil(hem[i].distance_to(hem[i + 1]) / 6.5))
			for k in n:
				var at := hem[i].lerp(hem[i + 1], float(k) / n)
				b.line(at, at + Vector2(0, 5), fringe, 1.4)
		b.line(hem[hem.size() - 1], hem[hem.size() - 1] + Vector2(0, 5), fringe, 1.4)
		edges.append(pn)
		hems.append(hem)
		if pattern == "striped":
			for y in [-40.0, -20.0, 0.0]:
				_fill_in(b, pn, _p([-70, y - 2, 70, y - 2, 70, y + 2, -70, y + 2]), Color(pc, 0.8))
	elif style == "cowl":  # a deep, soft collar round the neck and over the shoulders
		var cw := _sx(_p([-48, -54, -40, -72, -20, -86, 20, -86, 40, -72, 48, -54, 36, -44, 18, -52, 0, -49, -18, -52, -36, -44]), wx)
		b.poly(cw, cloak.darkened(0.12), 1.6)
		b.polygon(_sx(_p([-48, -54, -40, -72, -20, -86, 0, -86, 0, -49, -18, -52, -36, -44]), wx), cloak.lightened(0.05))
		for k in 3:  # its folds, ring on ring
			var y := -78.0 + k * 9.0
			b.path(_sx(_p([-38 + k * 2, y + 6, -20, y, 0, y - 1, 20, y, 38 - k * 2, y + 6]), wx), Color(cloak.darkened(0.4), 0.7), 1.4)
		edges.append(cw)
		hems.append(_sx(_p([-36, -44, -18, -52, 0, -49, 18, -52, 36, -44]), wx))
	elif style == "mantle":
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
		if style == "capelet":  # a scalloped edge, a little lower
			for i in 7:
				b.ball(Vector2((-36 + i * 12) * wx, -44.0 + absf(i - 3) * 1.5), 4.0, cloak.darkened(0.2 if i >= 3 else 0.08))
		elif style == "wrapped":  # a fold of it wrapped across the body
			var wr := _sx(_p([-30, -66, -16, -70, 26, 6, 24, 16, 12, 16]), wx)
			b.poly(wr, cloak.darkened(0.1), 1.4)
			b.line(Vector2(-22 * wx, -64), Vector2(18 * wx, 10), Color(cloak.lightened(0.25), 0.5), 1.4)
			edges.append(wr)
	if style in ["shawl", "poncho", "half"]:
		match pattern:
			"checked", "quilted", "scaled", "runed", "fur":
				var e0: PackedVector2Array = edges[0]
				var pc2: Color = ACCENTS["fur"] if pattern == "fur" else (ACCENTS["rune"] if pattern == "runed" else pc)
				b.path(_shift(e0, Vector2(0, 0)), Color(pc2, 0.8), 3.0 if pattern == "fur" else 1.2, true)
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
## Hood up: the face in the hood's shadow, the hair peeking out (the hood
## sits snug on the head, its peak just above the crown). Hood down (or no
## cloak): the face lit, the hood in folds round the neck. The face's shape
## follows the body (a squarer jaw, or a softer one with lashes). Then
## what's at the neck.
## A hood worn with no cloak drapes onto the shoulders (a coif too: gear_look.gd).
static var HOOD_DRAPE := _p([-29, -69, -23, -88, 23, -88, 29, -69, 13, -67, 0, -70, -13, -67])


static func draw_front_head(b, lk: Dictionary) -> void:
	var cloak: Color = lk.get("hood_front", lk["cloak"])  # (a worn hood or coif: its own colour)
	var skin: Color = lk["skin"]
	var hair: Color = lk["hair"]
	var style: String = lk.get("hair_style", "short")
	var trim_on: bool = lk.get("trim_on", false)
	var body: String = lk.get("body", "androgynous")
	if lk.get("hood_up", true):
		if style == "tied":  # a knot pushing up the hood behind
			b.ball(Vector2(7, -134), 6.5, cloak.darkened(0.28))
		elif style == "bun":  # a bigger, rounder bun behind the hood
			b.ball(Vector2(-6, -133), 8.0, cloak.darkened(0.3))
		if style == "tail":  # a tail out of the hood, over the shoulder
			b.poly(_p([13, -92, 19, -88, 22, -72, 19, -60, 15, -64, 16, -78]), hair.darkened(0.3), 1.2)
		if style == "pigtails":  # a tail out of each side of the hood
			for sg in [-1.0, 1.0]:
				b.poly(_p([sg * 20, -96, sg * 27, -92, sg * 30, -76, sg * 27, -66, sg * 23, -70, sg * 24, -86]), hair.darkened(0.25 if sg > 0.0 else 0.1), 1.2)
		if style == "mane":  # wild hair spilling out of the hood, over the shoulders
			for sg in [-1.0, 1.0]:
				b.poly(_p([sg * 18, -100, sg * 31, -96, sg * 26, -90, sg * 34, -84, sg * 26, -80, sg * 30, -72, sg * 16, -76]), hair.darkened(0.25 if sg > 0.0 else 0.12), 1.2)
		if String(lk.get("cloak_style", "long")) == "none":  # (a worn hood with no cloak: it drapes onto the shoulders)
			b.poly(HOOD_DRAPE, cloak.darkened(0.3), 1.6)
			b.polygon(_p([-29, -69, -23, -88, 0, -88, 0, -70, -13, -67]), cloak.darkened(0.12))
		b.poly(_p([0, -137, 13, -132, 22, -121, 26, -104, 23, -88, 12, -79, 0, -77, -12, -79, -23, -88, -26, -104, -22, -121, -13, -132]), cloak.darkened(0.18), 1.6)
		b.polygon(_p([0, -137, -13, -132, -22, -121, -26, -104, -23, -88, -12, -79, 0, -77, -5, -110]), cloak.darkened(0.0))
		b.polygon(_p([-18, -124, -9, -132, -3, -132, -13, -121]), Color(cloak.lightened(0.45), 0.5))
		b.polygon(_oval(Vector2(0, -103), Vector2(14.5, 18.0), 24), Color(0.04, 0.03, 0.05))
		if trim_on:
			b.path(_oval(Vector2(0, -103), Vector2(15.6, 19.2), 24), lk["trim"], 2.2, true)
		if style == "long" or style == "locks":
			b.polygon(_p([-13, -110, -10, -86, -5, -84, -8, -106]), hair.darkened(0.35))
			b.polygon(_p([13, -110, 10, -86, 5, -84, 8, -106]), hair.darkened(0.42))
		elif style == "afro":  # a round mass filling the hood round the face
			b.polygon(_oval(Vector2(0, -106), Vector2(14.0, 15.5), 24), hair.darkened(0.38))
		elif style == "bob":  # straight to the jaw
			b.polygon(_p([-13.5, -112, -12, -92, -7, -94, -8, -108]), hair.darkened(0.35))
			b.polygon(_p([13.5, -112, 12, -92, 7, -94, 8, -108]), hair.darkened(0.42))
		var jaw := Vector2(11.5, 13.0) if body == "masculine" else (Vector2(9.8, 12.6) if body == "feminine" else Vector2(10.5, 13.0))
		b.polygon(_oval(Vector2(0, -99), jaw, 24), skin.darkened(0.52))
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
			"swept":  # the fringe swept across, low over one eye
				b.polygon(_p([-12, -110, -6, -117, 6, -117, 13, -108, 12, -100, 6, -106, -4, -110]), hair.darkened(0.3))
			"undercut":  # a long top falling to one side, the sides bare
				b.polygon(_p([-8, -112, -2, -118, 8, -117, 12, -106, 10, -98, 6, -108, -2, -112]), hair.darkened(0.3))
			"locks":
				for i in 4:
					b.line(Vector2(-9 + i * 6, -114), Vector2(-10 + i * 6.6, -104), hair.darkened(0.3), 2.4)
			"bob":  # a straight fringe
				b.polygon(_p([-12, -106, -10, -115, 10, -115, 12, -106]), hair.darkened(0.3))
			"afro":
				for i in 5:
					b.dot(Vector2(-9 + i * 4.5, -112.0 + absf(i - 2) * 1.0), 3.4, hair.darkened(0.3 if i % 2 == 0 else 0.38))
			_:
				b.polygon(_p([-12, -108, -6, -116, 4, -117, 12, -108, 5, -112, -3, -110]), hair.darkened(0.3))
		_front_eyes(b, lk, 4.2, -100.0, 0.28)
		if lk.get("hood_low", false):  # pulled low: the brim over the eyes, in shadow
			var brim := _p([-16, -122, 16, -122, 15, -99, 7, -96.5, 0, -97.5, -7, -96.5, -15, -99])
			_fill_in(b, _oval(Vector2(0, -103), Vector2(14.5, 18.0), 24), brim, Color(cloak.darkened(0.5), 0.92))
			b.path(_p([-13.6, -98.6, -7, -96.5, 0, -97.5, 7, -96.5, 13.6, -98.6]), cloak.darkened(0.1), 2.2)
		if style == "braid" or style == "twin":
			_front_braid(b, hair, Vector2(-15, -82))
		if style == "twin":
			_front_braid(b, hair.darkened(0.12), Vector2(15, -82), -1.0)
		if style == "locks":  # locks down over the chest
			for sg in [-1.0, 1.0]:
				for i in 2:
					var x: float = sg * (12.0 + i * 4.0)
					b.stroke(Vector2(x, -86), Vector2(x + sg * 2.0, -62 + i * 4), hair.darkened(0.15 + 0.1 * i), 3.0)
		_front_head_extras(b, lk, true)
		return
	# Hood down: the hood in folds round the neck and shoulders, behind the head
	# (none without a cloak).
	# (The neck, drawn with the clothes, stays in front of the folds and of
	# hair hanging behind: _behind_neck.)
	if String(lk.get("cloak_style", "long")) != "none":
		var folds := _p([-31, -74, -24, -92, -10, -97, 10, -97, 24, -92, 31, -74, 16, -71, 0, -73, -16, -71])
		_behind_neck(b, lk, folds, cloak.darkened(0.2), 1.6)
		_behind_neck(b, lk, _p([-31, -74, -24, -92, -10, -97, 0, -97, 0, -73, -16, -71]), cloak.darkened(0.04), 0.0)
		b.line(Vector2(-21, -88), Vector2(-11, -79), Color(cloak.darkened(0.45), 0.8), 1.6)
		b.line(Vector2(21, -88), Vector2(11, -79), Color(cloak.darkened(0.5), 0.8), 1.6)
		if trim_on:
			b.path(_p([-31, -74, -24, -92, -10, -97, 10, -97, 24, -92, 31, -74]), lk["trim"], 2.2)
	match style:
		"long":  # hair falling behind the shoulders
			_behind_neck(b, lk, _p([-16, -116, -19, -92, -20, -74, -10, -76, 10, -76, 20, -74, 19, -92, 16, -116]), hair.darkened(0.25), 1.4, false)
		"tied":  # a knot on top
			b.ball(Vector2(1, -126), 6.0, hair.darkened(0.06))
			b.line(Vector2(-4, -121), Vector2(6, -121), lk["tunic"].lightened(0.1), 2.0)
		"bun":  # a round bun at the back of the crown, a pin through it
			b.ball(Vector2(-3, -125), 8.2, hair.darkened(0.12))
			b.line(Vector2(-13, -131), Vector2(8, -121), ACCENTS["metal"], 1.4)
		"tail":  # a tail behind, swung over to one side
			b.poly(_p([8, -120, 17, -114, 22, -98, 23, -80, 19, -68, 15, -72, 16, -90, 12, -108]), hair.darkened(0.2), 1.4)
			b.line(Vector2(13, -113), Vector2(19, -110), lk["tunic"].lightened(0.1), 2.0)
		"afro":  # a big round head of hair
			b.poly(_oval(Vector2(0, -110), Vector2(25.0, 24.0), 32), hair.darkened(0.12), 1.4)
			b.polygon(_oval(Vector2(-4, -114), Vector2(17.0, 15.0), 24), hair.darkened(0.02))
		"bob":  # straight, to the jaw all round
			b.poly(_p([-17, -112, -17, -90, -11, -88, 11, -88, 17, -90, 17, -112]), hair.darkened(0.2), 1.4)
		"pigtails":  # a tail at each side, tied, falling to the shoulders
			for sg in [-1.0, 1.0]:
				b.poly(_p([sg * 14, -108, sg * 21, -104, sg * 25, -88, sg * 24, -74, sg * 19, -76, sg * 18, -92]), hair.darkened(0.12 if sg < 0.0 else 0.25), 1.3)
				b.line(Vector2(sg * 15, -105), Vector2(sg * 21, -102), lk["tunic"].lightened(0.1), 2.0)
		"mane":  # a great wild mass round the head, spiking out, down to the shoulders
			var mane := PackedVector2Array()
			for i in 19:
				var a := PI * 0.62 + float(i) * PI * 1.76 / 18.0
				var r := 27.0 if i % 2 == 0 else 19.0
				mane.append(Vector2(0, -106) + Vector2(cos(a) * r, sin(a) * r * 1.05))
			_behind_neck(b, lk, mane, hair.darkened(0.18), 1.4, false)
			_behind_neck(b, lk, _shift(_sx(_shift(mane, Vector2(0, 106)), 0.8), Vector2(-2, -108)), hair.darkened(0.04), 0.0, false)
		"locks":  # locks hanging to the shoulders
			for i in 7:
				var x := -18.0 + i * 6.0
				if absf(x) < neck_w(lk) + 1.0:
					continue  # (behind the neck: hidden)
				b.stroke(Vector2(x * 0.8, -114), Vector2(x, -78 + absf(i - 3) * 2.0), hair.darkened(0.12 + 0.06 * (i % 2)), 4.0)
	# The head (the neck is the clothes' layer's: _front_neck).
	if not style in ["long", "mane", "afro", "bob"]:
		for s in [-1.0, 1.0]:  # ears
			b.poly(_oval(Vector2(s * 14.0, -101), Vector2(3.0, 4.6), 12), skin.darkened(0.08 if s < 0.0 else 0.2), 1.0)
	if style == "curls":  # curls round the head, behind it
		for i in 11:
			var a := PI + float(i) * PI / 10.0
			b.ball(Vector2(0, -106) + Vector2(cos(a) * 15.5, sin(a) * 17.0), 4.0, hair.darkened(0.1 if i < 5 else 0.24))
	# The face: squarer for a masculine body, softer and narrower at the chin for a feminine one.
	match body:
		"masculine":
			b.poly(_p([-14.5, -108, -13, -118, -6, -120, 6, -120, 13, -118, 14.5, -108, 14, -96, 10, -88, 4, -86, -4, -86, -10, -88, -14, -96]), skin.darkened(0.12), 1.6)
			b.polygon(_p([-14.5, -108, -13, -118, -6, -120, 0, -120, 1, -86, -4, -86, -10, -88, -14, -96]), skin)
		"feminine":
			b.poly(_oval(Vector2(0, -104), Vector2(13.4, 16.6), 28), skin.darkened(0.12), 1.6)
			b.polygon(_p([-13.4, -104, -12, -113, -6, -119, 0, -120.5, 1, -87.5, -5, -89, -10, -94]), skin)
		_:
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
		"undercut":  # shaved sides, a long top swept over to one side
			b.polygon(_p([-13, -104, -12, -114, -6, -119, 6, -119, 12, -114, 13, -104, 9, -112, -9, -112]), Color(hair, 0.22))
			b.poly(_p([-9, -113, -8, -122, -2, -126, 8, -125, 15, -118, 17, -106, 13, -110, 6, -116, -2, -116]), hair, 1.3)
			b.polygon(_p([8, -125, 15, -118, 17, -106, 13, -110, 6, -116]), hair.darkened(0.22))
		"cropped":
			var cr := hair.lerp(skin, 0.4)
			b.poly(_p([-14.5, -104, -14, -112, -10, -118, -4, -121, 4, -121, 10, -118, 14, -112, 14.5, -104, 11, -110, 4, -114, -4, -114, -11, -110]), cr, 1.2)
			b.polygon(_p([4, -121, 10, -118, 14, -112, 14.5, -104, 11, -110, 4, -114]), cr.darkened(0.2))
		"swept":  # the fringe swept across the brow, falling past one eye
			b.poly(_p([-14.5, -101, -15, -111, -11, -119, -4, -122, 4, -122, 11, -119, 15, -111, 15, -96, 12, -100, 8, -106, 0, -110, -8, -110, -12, -106]), hair, 1.4)
			b.polygon(_p([4, -122, 11, -119, 15, -111, 15, -96, 12, -100, 8, -106]), hair.darkened(0.22))
			b.line(Vector2(-10, -114), Vector2(10, -108), Color(hair.lightened(0.35), 0.5), 1.4)
		_:
			# The hair on top, a fringe across the brow.
			b.poly(_p([-14.5, -101, -15, -111, -11, -119, -4, -122, 4, -122, 11, -119, 15, -111, 14.5, -101, 12, -108, 7, -111, 1, -109, -5, -111, -11, -108]), hair, 1.4)
			b.polygon(_p([4, -122, 11, -119, 15, -111, 14.5, -101, 12, -108, 7, -111]), hair.darkened(0.22))
			b.line(Vector2(-9, -117), Vector2(-3, -120), Color(hair.lightened(0.4), 0.55), 1.4)
			if style == "long" or style == "mane":  # locks either side of the face
				b.polygon(_p([-14.5, -104, -16.5, -84, -12, -86, -12, -101]), hair)
				b.polygon(_p([14.5, -104, 16.5, -84, 12, -86, 12, -101]), hair.darkened(0.22))
			elif style == "bob":  # a straight fringe and straight sides
				b.polygon(_p([-14.5, -112, -12, -106, 12, -106, 14.5, -112]), hair)
				b.polygon(_p([-14.5, -104, -15.5, -90, -12, -91, -12, -103]), hair)
				b.polygon(_p([14.5, -104, 15.5, -90, 12, -91, 12, -103]), hair.darkened(0.22))
			elif style == "afro":
				for i in 5:
					b.ball(Vector2(-10 + i * 5.0, -116.0 + absf(i - 2) * 1.6), 4.2, hair.darkened(0.06 if i < 3 else 0.18))
			elif style == "curls":  # curls along the brow
				for i in 4:
					b.dot(Vector2(-7.5 + i * 5.0, -110.5 + (1.0 if i % 2 == 0 else 0.0)), 2.6, hair.darkened(0.08 if i < 2 else 0.2))
	_front_features(b, lk, 0.0)
	_front_beard(b, lk, 0.0)
	_front_eyes(b, lk, 4.6, -101.0, 0.0)
	var brow := (skin if style == "none" else hair).darkened(0.45)
	var bw := 1.8 if body == "masculine" else (1.0 if body == "feminine" else 1.3)
	var arch := -1.0 if body == "feminine" else 0.0
	b.line(Vector2(-7, -105.5), Vector2(-2.5, -106 + arch), Color(brow, 0.8), bw)  # brows
	b.line(Vector2(2.5, -106 + arch), Vector2(7, -105.5), Color(brow, 0.8), bw)
	b.line(Vector2(0.5, -99), Vector2(1.5, -95.5), Color(skin.darkened(0.3), 0.8), 1.2)  # nose
	if String(lk.get("beard", "none")) in ["none", "stubble", "chops", "chinstrap", "handlebar"]:
		var lips := Color(skin.darkened(0.42), 0.9) if body != "feminine" else Color(skin.darkened(0.3).lerp(Color(0.62, 0.3, 0.3), 0.35), 0.95)
		b.line(Vector2(-3.0, -91.5), Vector2(3.0, -91.5), lips, 1.2 if body != "feminine" else 1.7)  # mouth
	if style == "braid" or style == "twin":
		_front_braid(b, hair, Vector2(-12, -90))
	if style == "twin":
		_front_braid(b, hair.darkened(0.12), Vector2(12, -90), -1.0)
	_front_head_extras(b, lk, false)


## Draws an outlined shape that hangs behind the neck (the hood's folds,
## long hair) with the neck cut out of it, so the neck drawn earlier with the
## clothes shows in front.
static func _behind_neck(b, lk: Dictionary, pts: PackedVector2Array, col: Color, outline: float, shoulders := true) -> void:
	var nw := neck_w(lk)
	var neck := _p([-nw, -88, nw, -88, nw, -82, nw + 5.0, -73, 13, -60, -13, -60, -nw - 5.0, -73, -nw, -82])
	if not shoulders:  # (hair: only the neck itself, the hair lies on the shoulders)
		neck = _p([-nw, -88, nw, -88, nw, -60, -nw, -60])
	var pieces := Geometry2D.clip_polygons(pts, neck)
	# (Clipping can hand back a hole, wound the other way from the outer
	# pieces; the biggest piece is always an outer one.)
	var outer_cw := true
	var big := -1.0
	for piece in pieces:
		var r := Rect2(piece[0], Vector2.ZERO)
		for q in piece:
			r = r.expand(q)
		if r.get_area() > big:
			big = r.get_area()
			outer_cw = Geometry2D.is_polygon_clockwise(piece)
	for piece in pieces:
		if Geometry2D.is_polygon_clockwise(piece) != outer_cw:
			continue
		if outline > 0.0:
			b.poly(piece, col, outline)
		else:
			b.polygon(piece, col)


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
	var hair: Color = (lk.get("beard_col", lk["hair"]) as Color).darkened(shade)
	var dy := 1.0 if shade > 0.0 else 0.0
	var jaw := _p([-13, -101, -11, -93, -6, -88, 0, -86.5, 6, -88, 11, -93, 13, -101, 10, -95, 5, -92.5, 0, -93.5, -5, -92.5, -10, -95])
	var tache := _p([-6, -91, -3, -93.6, 0, -93, 3, -93.6, 6, -91, 3, -91.8, 0, -91.2, -3, -91.8])
	var full := _p([-14, -103, -13, -92, -8, -83, 0, -79, 8, -83, 13, -92, 14, -103, 10, -96, 5, -93, 0, -93.5, -5, -93, -10, -96])
	match String(lk.get("beard", "none")):
		"handlebar":  # a wide moustache, its ends curled up
			b.polygon(_shift(_p([-8.5, -94, -6, -91, -3, -93.6, 0, -93, 3, -93.6, 6, -91, 8.5, -94, 9.5, -91, 6, -89.6, 3, -91.6, 0, -91, -3, -91.6, -6, -89.6, -9.5, -91]), Vector2(0, dy)), hair)
		"chinstrap":  # a thin line of beard along the jaw
			b.path(_shift(_p([-13, -104, -12, -95, -8, -88.5, 0, -86.5, 8, -88.5, 12, -95, 13, -104]), Vector2(0, dy)), hair, 1.8)
		"goatee":  # a little beard on the chin, with a moustache
			b.poly(_shift(_p([-4, -90, 4, -90, 3, -84, 0, -81, -3, -84]), Vector2(0, dy)), hair, 0.8)
			b.polygon(_shift(tache, Vector2(0, dy)), hair.darkened(0.1))
		"chops":  # down the cheeks to the jaw, the chin bare
			for sg in [-1.0, 1.0]:
				b.polygon(_shift(_p([sg * 14, -106, sg * 13.5, -95, sg * 10, -89, sg * 7, -91, sg * 10, -97, sg * 11, -106]), Vector2(0, dy)), hair if sg < 0.0 else hair.darkened(0.15))
		"long", "forked":  # a full beard grown long, or split in two
			b.poly(_shift(full, Vector2(0, dy)), hair, 1.0)
			if String(lk.get("beard", "")) == "long":
				b.poly(_shift(_p([-9, -86, 9, -86, 7, -66, 0, -58, -7, -66]), Vector2(0, dy)), hair.darkened(0.06), 1.0)
			else:
				for sg in [-1.0, 1.0]:
					b.poly(_shift(_p([sg * 1, -84, sg * 9, -86, sg * 8, -70, sg * 5, -62, sg * 2, -70]), Vector2(0, dy)), hair.darkened(0.04 if sg < 0.0 else 0.16), 1.0)
			b.polygon(_shift(tache, Vector2(0, dy)), hair.darkened(0.1))
			b.line(Vector2(-2.5, -90 + dy), Vector2(2.5, -90 + dy), Color(lk["skin"].darkened(0.45 + shade), 0.9), 1.1)
		"stubble":
			b.polygon(_shift(jaw, Vector2(0, dy)), Color(hair.lerp(lk["skin"], 0.35), 0.42))
		"moustache":
			b.polygon(_shift(tache, Vector2(0, dy)), hair.darkened(0.08))
		"short":
			b.polygon(_shift(jaw, Vector2(0, dy)), hair)
			b.polygon(_shift(tache, Vector2(0, dy)), hair.darkened(0.12))
			b.line(Vector2(-2.5, -90 + dy), Vector2(2.5, -90 + dy), Color(lk["skin"].darkened(0.45 + shade), 0.9), 1.1)
		"full", "braided":
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
	elif shape == "close":
		x -= 1.2
	var patch := String(lk.get("accessory", "none")) == "eyepatch"
	for s in [-1.0, 1.0]:
		var at: Vector2 = Vector2(s * x, y)
		if patch and s > 0.0:
			continue
		var white := Color(0.92, 0.9, 0.86).darkened(shade + 0.1 + (0.4 if lk.get("hood_low", false) else 0.0))
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
			"upturned", "downturned", "sharp":  # a lens tilted up or down at the outer corner, or pointed
				# (the outer corner is on the side away from the nose: `s`)
				var outer := -1.3 if shape == "upturned" else (1.3 if shape == "downturned" else -0.9)
				var w := 3.7 if shape == "sharp" else 3.2
				var lens2 := _p([at.x - s * w, at.y - outer * 0.3, at.x - s * 0.4, at.y - (2.2 if shape == "sharp" else 1.6), at.x + s * w, at.y + outer, at.x + s * 0.4, at.y + (0.9 if shape == "sharp" else 1.3)])
				if dark:
					b.polygon(_shift(_sx(_shift(lens2, -at), 0.7), at), UI.OUTLINE)
				else:
					b.polygon(lens2, white)
					b.dot(at + Vector2(0.2, 0.0), 1.3, col.darkened(shade))
					b.dot(at + Vector2(0.2, 0.0), 0.55, UI.OUTLINE)
				b.path(_p([lens2[0].x, lens2[0].y, lens2[1].x, lens2[1].y, lens2[2].x, lens2[2].y]), Color(UI.OUTLINE, 0.75), 1.0)
			"monolid":  # a smooth lid with no crease: a flat lens
				var lens3 := _p([at.x - 3.2, at.y + 0.2, at.x - 1.2, at.y - 1.1, at.x + 1.2, at.y - 1.1, at.x + 3.2, at.y + 0.2, at.x + 1.2, at.y + 1.0, at.x - 1.2, at.y + 1.0])
				b.polygon(lens3 if not dark else _shift(_sx(_shift(lens3, -at), 0.6), at), white if not dark else UI.OUTLINE)
				if not dark:
					b.dot(at + Vector2(0.2, 0.0), 1.1, col.darkened(shade))
				b.line(at + Vector2(-3.4, -1.3), at + Vector2(3.4, -1.3), Color(lk["skin"].darkened(0.2 + shade), 0.9), 1.6)
			"hooded", "heavy", "deep":
				if shape == "deep":  # set in shadow under the brow
					b.polygon(_oval(at + Vector2(0, -0.6), Vector2(4.0, 3.0), 12), Color(lk["skin"].darkened(0.3 + shade), 0.8))
				if dark:
					b.dot(at, 1.5, UI.OUTLINE)
				else:
					b.dot(at, 2.3, white)
					b.dot(at + Vector2(0.2, 0.1), 1.6, col.darkened(shade))
					b.dot(at + Vector2(0.2, 0.1), 0.7, UI.OUTLINE)
				if shape == "hooded":  # a fold of skin over the eye
					b.line(at + Vector2(-3.2, -2.2), at + Vector2(3.4, -1.8), Color(lk["skin"].darkened(0.35 + shade), 0.9), 1.4)
				elif shape == "heavy":  # lids half down
					b.polygon(_p([at.x - 2.8, at.y - 0.2, at.x - 2.2, at.y - 2.0, at.x + 2.2, at.y - 2.0, at.x + 2.8, at.y - 0.2]), lk["skin"].darkened(0.12 + shade))
					b.line(at + Vector2(-2.8, -0.2), at + Vector2(2.8, -0.2), Color(UI.OUTLINE, 0.8), 1.0)
			_:
				if dark:
					b.dot(at, 1.5, UI.OUTLINE)
				else:
					b.dot(at, 2.3, white)
					b.dot(at + Vector2(0.2, 0.1), 1.6, col.darkened(shade))
					b.dot(at + Vector2(0.2, 0.1), 0.7, UI.OUTLINE)
		if String(lk.get("body", "")) == "feminine":  # lashes at the outer corner
			b.line(at + Vector2(s * 2.6, -1.2), at + Vector2(s * 4.2, -2.4), Color(UI.OUTLINE, 0.85), 0.9)
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
		"nosering":
			var nr := Vector2(1.2, -94.6 if hood_up else -95.0)
			b.arc(nr, 1.6, 0.2, PI - 0.2, 8, UI.OUTLINE, 1.6)
			b.arc(nr, 1.6, 0.2, PI - 0.2, 8, ACCENTS["metal"].darkened(0.25 if hood_up else 0.0), 0.9)
		"headband":
			var band: Color = ACCENTS["band"].darkened(0.3 if hood_up else 0.0)
			var y := -113.0 if hood_up else -112.0
			var hw := 12.5 if hood_up else 14.8
			b.poly(_p([-hw, y - 1.5, -hw * 0.5, y - 3.2, hw * 0.5, y - 3.2, hw, y - 1.5, hw, y + 1.8, hw * 0.5, y + 0.2, -hw * 0.5, y + 0.2, -hw, y + 1.8]), band, 1.0)
			if not hood_up:  # its knot and tails at the side
				b.ball(Vector2(15, y), 2.4, band)
				b.line(Vector2(16, y + 1), Vector2(20, y + 10), band, 1.6)
		"circlet":  # a thin band of metal round the brow, a stone at the front
			var cy := -112.0 if hood_up else -111.0
			var cw2 := 12.0 if hood_up else 14.6
			b.path(_p([-cw2, cy + 1.5, -cw2 * 0.5, cy - 1.0, 0, cy - 1.8, cw2 * 0.5, cy - 1.0, cw2, cy + 1.5]), ACCENTS["metal"].darkened(0.25 if hood_up else 0.0), 1.6)
			b.poly(_oval(Vector2(0, cy - 1.8), Vector2(1.8, 2.4), 10), ACCENTS["stone"], 0.8)
		"mask":  # a dark half mask over the eyes
			var my := -100.0 if hood_up else -101.0
			b.poly(_p([-12, my - 3, -4, my - 4, 0, my - 2, 4, my - 4, 12, my - 3, 11, my + 2.5, 4, my + 3, 0, my + 1, -4, my + 3, -11, my + 2.5]), ACCENTS["patch"], 1.0)
			var ex2 := 4.2 if hood_up else 4.6
			for sg in [-1.0, 1.0]:
				b.polygon(_oval(Vector2(sg * ex2, my), Vector2(2.2, 1.4), 10), Color(0.92, 0.9, 0.86).darkened(0.3 if hood_up else 0.0))
				b.dot(Vector2(sg * ex2, my), 0.9, lk["eyes"])
		"spectacles":
			var ex := 4.2 if hood_up else 4.6
			if String(lk.get("eye_shape", "")) == "wide":
				ex += 1.4
			var ey := -100.0 if hood_up else -101.0
			var rim: Color = ACCENTS["rims"].lightened(0.1 if hood_up else 0.25)
			for s in [-1.0, 1.0]:  # glass with a glint, the rims (thick enough to read at a small size)
				b.polygon(_oval(Vector2(s * ex, ey), Vector2(3.4, 3.0), 14), Color(0.85, 0.92, 1.0, 0.16))
				b.line(Vector2(s * ex - 1.8, ey - 0.6), Vector2(s * ex - 0.4, ey - 2.0), Color(1, 1, 1, 0.55), 0.9)
				b.path(_oval(Vector2(s * ex, ey), Vector2(3.4, 3.0), 14), rim, 1.5, true)
			b.line(Vector2(-ex + 3.4, ey - 0.5), Vector2(ex - 3.4, ey - 0.5), rim, 1.3)
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
	if neck != "scarf" and String(lk.get("cloak_style", "long")) not in ["none", "half"] and String(lk.get("beard", "none")) not in ["long", "forked"]:
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
