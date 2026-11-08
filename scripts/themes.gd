extends RefCounted
## Room themes: what each room of a floor IS. Every room gets one when the
## floor is planned (floors.gd calls `assign`), and walking into a themed
## room for the first time shows its name and a one-line rule. The theme
## also tints the room's floor and decides what its door looks like.
##
## Everything here is plain data, meant to be renamed and rewritten freely:
##   name      what the climber is told on walking in
##   kind      "good" (a gift), "bad" (a danger), "mixed" or "calm"
##   sub       the one-line rule shown under the name ("" shows nothing)
##   tint      a colour washed over the room's floor (alpha = how strong)
##   door      the door's look, a hint at what waits inside (never the reward):
##               "plank"   an ordinary room
##               "den"     iron bands and claw marks: monsters
##               "hazard"  an engraved sigil of the hazard inside (see `sigil`)
##               "puzzle"  a stone door bearing the puzzle's emblem
##               "warm"    warm light under the door: a good room
##               "chained" chains and a red glow: danger
##   min_size  the smallest room (tiles) it fits; a room too small takes another theme
##   towers    [] for every tower, else only these towers
##   home      (optional) towers where it's twice as likely, like a tower's own
##   feature   what the floor builds for it (see floors.gd and main.gd):
##               "spring"  a pool that heals you while you stand in it
##               "cache"   an urn of the tower's essence (one per floor)
##               "camp"    a fallen climber's cold camp, with an item left behind
##               "den"     more of the floor's monsters wait here
##               "ambush"  monsters rise when you first walk in
##               "pillars" needs a room with pillars; archers prefer it
##               "trap"    a set piece of traps is laid here (traps.gd);
##                         every floor from 2 up has at least one trap room
##               "chasm"   a band of chasm across the room
##               "stair", "puzzle", "start", or "" for nothing
##   sigil     (hazard doors) the hazard's sign: wind, wave, flame, spike, dart,
##             ember, thorn, gas, chasm
##   decor     marks drawn on its floor: "bones", "scorch", "ripples" (optional)
##   from      the first floor it can appear on (optional, default 1)
##   weight    how likely it is next to the others of its kind (optional, default 1)

const Rooms := preload("res://scripts/rooms.gd")

const THEMES := {
	# --- fixed by the room's job ------------------------------------------------
	"arrival": {"name": "Arrival Hall", "kind": "calm", "sub": "", "tint": Color(0, 0, 0, 0),
		"door": "plank", "min_size": Vector2i(0, 0), "towers": [], "feature": "start"},
	"landing": {"name": "Stair Landing", "kind": "mixed", "sub": "The way up, and those set to guard it.",
		"tint": Color(0.75, 0.55, 1.0, 0.05), "door": "chained", "min_size": Vector2i(0, 0), "towers": [], "feature": "stair"},
	"puzzle_eyes": {"name": "Hall of Eyes", "kind": "mixed", "sub": "Stone eyes sleep in the walls. Wake them all to lift the stair's ward.",
		"tint": Color(0.6, 0.5, 1.0, 0.08), "door": "puzzle", "emblem": "eye", "min_size": Vector2i(0, 0), "towers": [], "feature": "puzzle"},
	"puzzle_plates": {"name": "Weighing Room", "kind": "mixed", "sub": "The plates want a weight heavier than you. Hold them all down to lift the stair's ward.",
		"tint": Color(0.6, 0.5, 1.0, 0.08), "door": "puzzle", "emblem": "plate", "min_size": Vector2i(0, 0), "towers": [], "feature": "puzzle"},
	"quiet": {"name": "Quiet Hall", "kind": "calm", "sub": "Dust and silence. Nothing stirs here.", "tint": Color(0, 0, 0, 0),
		"door": "plank", "min_size": Vector2i(0, 0), "towers": [], "feature": ""},

	# --- good rooms ---------------------------------------------------------------
	"spring": {"name": "Healing Spring", "kind": "good", "sub": "Clear water wells up from the stone. Stand in it to heal.",
		"tint": Color(0.35, 0.8, 0.7, 0.10), "door": "warm", "min_size": Vector2i(6, 5), "towers": [], "feature": "spring"},
	"cache": {"name": "Forgotten Cache", "kind": "good", "sub": "Someone hid essence here long ago, and may have set spikes to guard it. Walk up to the urn to take it.",
		"tint": Color(0.9, 0.75, 0.4, 0.08), "door": "warm", "min_size": Vector2i(5, 5), "towers": [], "feature": "cache"},
	"camp": {"name": "Fallen Climber's Camp", "kind": "good", "sub": "A cold fire and a scattered pack. Their loss, your gain.",
		"tint": Color(1.0, 0.65, 0.35, 0.07), "door": "warm", "min_size": Vector2i(6, 5), "towers": [], "feature": "camp"},
	# Each tower's own good room (twice as likely there).
	"aerie": {"name": "Windswept Aerie", "kind": "good", "sub": "An old nest, lined with whatever the wind brought in. Some of it hums with essence, and spikes may guard it.",
		"tint": Color(0.75, 0.85, 1.0, 0.08), "door": "warm", "min_size": Vector2i(5, 5), "towers": ["gryphon"], "feature": "cache"},
	"tidepool": {"name": "Tidepool", "kind": "good", "sub": "Still, cold water, clearer than the rest. Stand in it to heal.",
		"tint": Color(0.3, 0.75, 0.85, 0.10), "door": "warm", "min_size": Vector2i(6, 5), "towers": ["kraken"], "feature": "spring"},
	"forge": {"name": "Cold Forge", "kind": "good", "sub": "A smith's corner, long abandoned. Something useful was left on the anvil.",
		"tint": Color(1.0, 0.55, 0.3, 0.08), "door": "warm", "min_size": Vector2i(6, 5), "towers": ["wyvern"], "feature": "camp"},
	"oasis": {"name": "Hidden Oasis", "kind": "good", "sub": "Sweet water under the sand. Stand in it to heal.",
		"tint": Color(0.5, 0.85, 0.55, 0.09), "door": "warm", "min_size": Vector2i(6, 5), "towers": ["manticore"], "feature": "spring"},
	"pyre": {"name": "Ember Pyre", "kind": "good", "sub": "Embers that never quite die, and a pack someone left beside them.",
		"tint": Color(1.0, 0.6, 0.3, 0.09), "door": "warm", "min_size": Vector2i(6, 5), "towers": ["firebird"], "feature": "camp"},
	"nest": {"name": "Thornwild Nest", "kind": "good", "sub": "A nest of woven thorns, lined with a hunter's hoard of essence, and spikes may guard it.",
		"tint": Color(0.55, 0.8, 0.4, 0.09), "door": "warm", "min_size": Vector2i(5, 5), "towers": ["chimera"], "feature": "cache"},

	# --- bad rooms ----------------------------------------------------------------
	"den": {"name": "Monster Den", "kind": "bad", "sub": "Bones and claw marks. Something lives here.",
		"tint": Color(0.5, 0.25, 0.15, 0.10), "door": "den", "min_size": Vector2i(5, 5), "towers": [], "feature": "den", "decor": "bones"},
	"crypt": {"name": "Restless Crypt", "kind": "bad", "sub": "The dead do not stay quiet when disturbed.",
		"tint": Color(0.6, 0.5, 0.9, 0.08), "door": "chained", "min_size": Vector2i(6, 5), "towers": [], "feature": "ambush", "decor": "bones", "from": 3, "weight": 0.7},
	"pillars": {"name": "Pillared Hall", "kind": "bad", "sub": "Archers lurk among the pillars. Use them for cover.",
		"tint": Color(0.8, 0.8, 0.9, 0.04), "door": "den", "min_size": Vector2i(7, 6), "towers": [], "feature": "pillars"},
	"chasm": {"name": "The Chasm", "kind": "bad", "sub": "The floor falls away into the dark. Jump it, or fall to the floor below.",
		"tint": Color(0.1, 0.05, 0.15, 0.10), "door": "hazard", "sigil": "chasm", "min_size": Vector2i(6, 5), "towers": [], "feature": "chasm"},
	# Trap rooms: each lays its set piece of traps (traps.gd), built out of the
	# room's own shape. The rule hints at the pattern without spelling it out.
	"spikes": {"name": "Spike Gallery", "kind": "bad", "sub": "The floor is pocked with rows of small holes. Listen for the click, and mind the rhythm.",
		"tint": Color(0.85, 0.82, 0.75, 0.06), "door": "hazard", "sigil": "spike", "min_size": Vector2i(6, 5), "towers": [], "home": ["manticore"], "feature": "trap", "weight": 0.75},
	"darts": {"name": "Dart Hall", "kind": "bad", "sub": "Thin slits line both walls. Whatever waits behind them takes turns.",
		"tint": Color(0.75, 0.6, 0.55, 0.05), "door": "hazard", "sigil": "dart", "min_size": Vector2i(6, 5), "towers": [], "feature": "trap", "weight": 0.75},
	"furnace": {"name": "The Furnace", "kind": "bad", "sub": "Scorched grates at both ends, and the air shimmers. The fire takes turns: one side is always safe.",
		"tint": Color(1.0, 0.35, 0.15, 0.09), "door": "hazard", "sigil": "flame", "min_size": Vector2i(7, 5), "towers": [], "home": ["wyvern"], "feature": "trap", "decor": "scorch", "from": 3, "weight": 0.75},
	"miasma": {"name": "Miasma Hall", "kind": "bad", "sub": "The air tastes foul and the stone is cracked. Some stones are clean. Don't breathe it long.",
		"tint": Color(0.55, 0.65, 0.25, 0.08), "door": "hazard", "sigil": "gas", "min_size": Vector2i(7, 6), "towers": [], "home": ["manticore", "chimera"], "feature": "trap", "from": 4, "weight": 0.75},
	# Each tower's own trap room (twice as likely there).
	"windhall": {"name": "Windhall", "kind": "bad", "sub": "The wind howls toward a wall of spikes.",
		"tint": Color(0.75, 0.88, 1.0, 0.07), "door": "hazard", "sigil": "wind", "min_size": Vector2i(6, 5), "towers": ["gryphon"], "feature": "trap"},
	"sluice": {"name": "Sluice Hall", "kind": "bad", "sub": "Water stains run the length of the hall. The pillars stand dry.",
		"tint": Color(0.3, 0.7, 0.9, 0.09), "door": "hazard", "sigil": "wave", "min_size": Vector2i(7, 4), "towers": ["kraken"], "feature": "trap", "decor": "ripples"},
	"emberfall": {"name": "Emberfall", "kind": "bad", "sub": "Scorch rings dot the floor. Something falls here, and keeps falling.",
		"tint": Color(1.0, 0.5, 0.2, 0.08), "door": "hazard", "sigil": "ember", "min_size": Vector2i(6, 5), "towers": ["firebird"], "feature": "trap", "decor": "scorch"},
	"bramble": {"name": "Bramble Hall", "kind": "bad", "sub": "Brambles choke the room, and something in them snaps. Someone has trodden a path.",
		"tint": Color(0.4, 0.65, 0.25, 0.10), "door": "hazard", "sigil": "thorn", "min_size": Vector2i(6, 5), "towers": ["chimera"], "feature": "trap"},
}

## Rules for the rooms with no fixed job (see `assign`).
const RULES := {
	"good_chance": 0.2,  # after the first two rooms: this often a good room...
	"quiet_chance": 0.2,  # ...this often a quiet one; otherwise a bad one, if the cap allows
	"max_good": 2,  # good rooms on a floor at most
	"max_bad": [[1, 2], [3, 3], [99, 4]],  # [up to floor, bad rooms at most], den included
	"tower_weight": 2.0,  # a tower's own themes are this much likelier there
	"trap_from": 2,  # from this floor every floor has a trap room (see `assign`)
}
## How often a room's doorway gets a door: likelier where danger waits.
const DOOR_CHANCE := {"likely": 0.75, "else": 0.35}
const DOOR_LIKELY := ["den", "landing", "puzzle_eyes", "puzzle_plates", "crypt", "pillars"]


static func get_theme(id: String) -> Dictionary:
	return THEMES.get(id, THEMES["quiet"])


## The theme for the puzzle room, by its puzzle.
static func puzzle_theme(kind: String) -> String:
	return "puzzle_" + kind if THEMES.has("puzzle_" + kind) else "quiet"


## Whether a theme may go in a room. `info`: {size (tiles), rows, ...}.
## `tower` is the tower's data, `tid` its id.
static func fits(id: String, info: Dictionary, tid: String, tower: Dictionary) -> bool:
	var th: Dictionary = THEMES[id]
	var towers: Array = th["towers"]
	if not towers.is_empty() and not (tid in towers):
		return false
	var size: Vector2i = info["size"]
	var need: Vector2i = th["min_size"]
	if mini(size.x, size.y) < mini(need.x, need.y) or maxi(size.x, size.y) < maxi(need.x, need.y):
		return false
	var rows: Array = info["rows"]
	match th["feature"]:
		"spring", "cache", "camp":
			return Rooms.clear_spot(rows, 3) != Vector2i(-1, -1)
		"pillars":
			var n := 0
			for row in rows:
				n += String(row).count("o") + String(row).count("#")
			return n >= 4
		"chasm":
			return tower.get("chasms", false)
	return true



## Gives every room of a floor a theme, the way the web version did:
##   the start room is the Arrival Hall, the stair room the Stair Landing,
##   and the puzzle room takes its puzzle's theme;
##   of the rest (in a random order), the first is always a good room and
##   the second a den; after that a mix, with a cap on bad rooms that grows
##   with height, no bad theme twice a floor, the tower's own themes weighted
##   double, and a theme that doesn't fit its room swapped for one that does.
## `infos`: one dictionary per room with "role" (entrance, guard, gallery,
## stair or branch), "size", "rows" and, for the gallery, "puzzle".
## Writes "theme" into each and returns the ids in order.
static func assign(infos: Array, floor_num: int, tid: String, tower: Dictionary) -> Array:
	var free: Array = []
	for i in infos.size():
		var info: Dictionary = infos[i]
		match String(info["role"]):
			"entrance":
				info["theme"] = "arrival"
			"stair":
				info["theme"] = "landing"
			"gallery":
				info["theme"] = puzzle_theme(String(info.get("puzzle", "")))
			_:
				info["theme"] = ""
				free.append(i)
	free.shuffle()
	var max_bad := 4
	for step in RULES["max_bad"]:
		if floor_num <= int(step[0]):
			max_bad = int(step[1])
			break
	var used := {}  # themes used this floor (only quiet repeats)
	var caches := 0
	var n_bad := 0
	var n_good := 0
	for k in free.size():
		var info: Dictionary = infos[free[k]]
		var want := ""
		if k == 0:
			want = "good"
		elif k == 1:
			want = "den"
		else:
			var roll := randf()
			if roll < float(RULES["good_chance"]):
				want = "good"
			elif roll < float(RULES["good_chance"]) + float(RULES["quiet_chance"]) or n_bad >= max_bad:
				want = "quiet"
			else:
				want = "bad"
		if want == "good" and n_good >= int(RULES["max_good"]):
			want = "bad" if n_bad < max_bad else "quiet"
		var id := ""
		if want == "den":
			id = "den" if fits("den", info, tid, tower) else _pick_kind("bad", info, tid, tower, used, caches, floor_num)
		elif want == "quiet":
			id = "quiet"
		else:
			id = _pick_kind(want, info, tid, tower, used, caches, floor_num)
			if id == "" and want == "good":
				id = _pick_kind("bad", info, tid, tower, used, caches, floor_num) if n_bad < max_bad else ""
		if id == "":
			id = "quiet"
		if THEMES[id]["kind"] == "bad":
			n_bad += 1
		elif THEMES[id]["kind"] == "good":
			n_good += 1
		if THEMES[id]["feature"] == "cache":
			caches += 1
		if id != "quiet":
			used[id] = true
		info["theme"] = id
	# Every floor (from floor 2) has a trap room: a quiet room becomes one if
	# the cap allows, else a bad room that isn't a den or another trap room.
	if floor_num >= int(RULES["trap_from"]) and not free.any(func(i): return THEMES[infos[i]["theme"]]["feature"] == "trap"):
		var order: Array = free.filter(func(i): return infos[i]["theme"] == "quiet" and n_bad < max_bad)
		order.append_array(free.filter(func(i): return THEMES[infos[i]["theme"]]["kind"] == "bad" and not (THEMES[infos[i]["theme"]]["feature"] in ["den", "trap"])))
		for i in order:
			var id := _pick_kind("bad", infos[i], tid, tower, used, caches, floor_num, "trap")
			if id != "":
				infos[i]["theme"] = id
				break
	var out: Array = []
	for info in infos:
		out.append(info["theme"])
	return out


## A theme of `kind` that fits the room and isn't used yet, the tower's own
## themes weighted double; "" if none fits.
static func _pick_kind(kind: String, info: Dictionary, tid: String, tower: Dictionary, used: Dictionary, caches: int, floor_num: int, feature := "") -> String:
	var opts: Array = []
	var weights: Array = []
	var total := 0.0
	for id in THEMES:
		var th: Dictionary = THEMES[id]
		if th["kind"] != kind or used.has(id) or th["feature"] in ["start", "stair", "puzzle"]:
			continue
		if th["feature"] == "cache" and caches > 0:
			continue
		if feature != "" and th["feature"] != feature:
			continue
		if floor_num < int(th.get("from", 1)):
			continue
		if not fits(id, info, tid, tower):
			continue
		var own: bool = not th["towers"].is_empty() or tid in th.get("home", [])
		var w := (float(RULES["tower_weight"]) if own else 1.0) * float(th.get("weight", 1.0))
		opts.append(id)
		weights.append(w)
		total += w
	if opts.is_empty():
		return ""
	var roll := randf() * total
	for i in opts.size():
		roll -= weights[i]
		if roll <= 0.0:
			return opts[i]
	return opts[-1]


## How likely a doorway into a room with this theme is to have a door.
static func door_chance(id: String) -> float:
	return float(DOOR_CHANCE["likely"]) if id in DOOR_LIKELY else float(DOOR_CHANCE["else"])
