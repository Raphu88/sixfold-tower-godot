extends Node2D
## INSCRIPTION STONES: on some floors a standing stone stands near a room's
## north wall, old words cut into it, its letters glowing faintly. Stand
## beside it and the words show over it (walk away and they fade); the
## first reading on a floor goes into the Entity's log of the climb. Nothing
## to press: walking up reads it, so it plays the same with keys, a
## controller or touch.
##
## The words are the owner's: INSCRIPTIONS holds six for each tower (a
## stone shows its tower's, by floor: floor 1 and 7 the first, floor 2 and
## 8 the second...). Change them here or in the Data editor ("Inscription
## stones").
##
## Planning: floors.gd calls plan() once the floor (and the tower's own
## ground) is laid: plan["inscription"] = {pos, tower, index}. In play this
## node (main.gd makes one) draws the stone and shows the words.

const Grid := preload("res://scripts/towers/water_wind_grid.gd")
const Palette := preload("res://scripts/palette.gd")
const UI := preload("res://scripts/ui.gd")
const Themes := preload("res://scripts/themes.gd")
const Pronouns := preload("res://scripts/pronouns.gd")
const CELL := 40.0

## Each tower's six stones: a title over the words, and the words (the
## owner's approved text). Stones 1-2: the tower's own well and guardian;
## 3-5: a chapter of the shared history; 6: the tower's line of the
## prophecy. The Chimera's speak of the sixth climber, the one playing: its
## {they} / {them} tokens become the climber's pronouns as it shows
## (pronouns.gd; words() fills them).
static var INSCRIPTIONS := {
	"gryphon": [
		{"title": "The Gryphon's Tower", "text": "Here the air runs up from the deep well, and the Gryphon rides it. What it lets through is breath. What it holds back is storm."},
		{"title": "The Gryphon's Tower", "text": "The Gryphon watches from every height. It sees who climbs and why, and it does not forget a face."},
		{"title": "The Gryphon's Tower", "text": "There were always wells. Before the towers they lay open, and anyone could drink."},
		{"title": "The Gryphon's Tower", "text": "Now each well is capped with stone and kept by a beast, and essence comes out only as much as one climber can hold."},
		{"title": "The Gryphon's Tower", "text": "A mark is a share of the well, given and measured. The one who takes it takes the keeping with it."},
		{"title": "The Gryphon's Tower", "text": "Six wells beneath six stones, and six beasts to keep them."},
	],
	"kraken": [
		{"title": "The Kraken's Tower", "text": "Beneath this tower the well rises and falls like a tide. The Kraken keeps the tide."},
		{"title": "The Kraken's Tower", "text": "Nothing that sinks here is lost to the Kraken. It knows the weight of every climber."},
		{"title": "The Kraken's Tower", "text": "Once, people drew every essence at once, raw and unmeasured, and called it freedom."},
		{"title": "The Kraken's Tower", "text": "The sky split. The sea stood up. The ground forgot how to hold. The world began to come undone."},
		{"title": "The Kraken's Tower", "text": "Six people stood in the breaking and held it shut with their own wild essence, and did not let go."},
		{"title": "The Kraken's Tower", "text": "Six held the breaking world: two gave themselves, three built the keeping, and one was cast away."},
	],
	"wyvern": [
		{"title": "The Wyvern's Tower", "text": "Iron essence pours from the well below into the Wyvern's forge. Nothing leaves it unshaped."},
		{"title": "The Wyvern's Tower", "text": "The Wyvern tests every blade and every climber the same way: by striking them."},
		{"title": "The Wyvern's Tower", "text": "Two of the six gave all of themselves. One became Making, one became Unmaking, and together they hold up everything beneath."},
		{"title": "The Wyvern's Tower", "text": "Three built with Making and Unmaking together: one the marks, one the towers, one the beasts. They are the Makers now, and no longer only people."},
		{"title": "The Wyvern's Tower", "text": "They bound four sixes into the keeping, one for each of the four who still walked after: three Makers, and one more."},
		{"title": "The Wyvern's Tower", "text": "Six by six by six by six the years are counted, and at each count one climber rises who could undo the keeping."},
	],
	"manticore": [
		{"title": "The Manticore's Tower", "text": "The well under the sand is slow and heavy, and the Manticore lies across it like a stone across a grave."},
		{"title": "The Manticore's Tower", "text": "It hunts by waiting. Those who draw from its well without leave find the ground has been listening."},
		{"title": "The Manticore's Tower", "text": "The last of the six would not agree to the keeping. For that, the three cast them out."},
		{"title": "The Manticore's Tower", "text": "Their name was taken, and their body with it. They may walk only where they are not seen, beside those who climb."},
		{"title": "The Manticore's Tower", "text": "Four climbers have risen since the keeping, one at each count. Each could have broken it. None did, and none are remembered."},
		{"title": "The Manticore's Tower", "text": "Six times the count comes round, and then the keeping ends."},
	],
	"firebird": [
		{"title": "The Firebird's Tower", "text": "The well beneath this tower burns and does not burn out. The Firebird rises from it and returns to it."},
		{"title": "The Firebird's Tower", "text": "It burns the bridges behind every climber, so that no one climbs here without meaning to."},
		{"title": "The Firebird's Tower", "text": "The fifth climber reached every summit and could not finish the beasts."},
		{"title": "The Firebird's Tower", "text": "Knowing they would fall, they made a pact with the one who was cast out, and at each well's mouth they poured themself into a blade."},
		{"title": "The Firebird's Tower", "text": "Six cities remember six heroes. They are one climber, and the blades are all that is left of them."},
		{"title": "The Firebird's Tower", "text": "Five have risen. The fifth became six blades, and waits in the stone."},
	],
	"chimera": [
		{"title": "The Chimera's Tower", "text": "The well beneath the Thornwild cuts whatever drinks from it. The Chimera grows from it, many beasts in one."},
		{"title": "The Chimera's Tower", "text": "It has worn the shape of every beast the Makers made, and it remembers how each of them died."},
		{"title": "The Chimera's Tower", "text": "The sixth count is ending. The one who climbs now is the last the keeping was made to hold."},
		{"title": "The Chimera's Tower", "text": "The Makers will ask {them} to stop. The one who was cast out will ask {them} to go on."},
		{"title": "The Chimera's Tower", "text": "Whoever holds Making and Unmaking at once will make the world again, or break it again."},
		{"title": "The Chimera's Tower", "text": "The sixth will not come down the same: {they} will become, or {they} will break."},
	],
}
## from: the first floor; chance: how often a floor has a stone; read: how
## near you must stand (px); fade: seconds for the words to show or go.
static var RULES := {"from": 2, "chance": 0.4, "read": 54.0, "fade": 0.25}
static var TEXT := {
	"log": "An inscription: %s",
	"stone": "Inscription stone",
}
## How it looks: the stone, its carving's glow.
static var LOOK := {"stone": Color(0.46, 0.45, 0.48), "glow": Color(0.72, 0.86, 1.0), "plate": Color(0.07, 0.065, 0.09, 0.9), "words": Color(0.93, 0.9, 0.82)}
## (tests: every floor gets one)
static var forced := false

var main
var stone := {}  # {pos, tower, index}
var show_k := 0.0  # the words, faded in (0..1)
var read := false  # read on this floor (logged)
var t := 0.0
var over: Node2D  # the words and the glow, over the darkness


## The words of a stone ({title, text}), any pronoun tokens filled with the
## climber's own (the sixth climber's stones: pronouns.gd).
static func words(tower: String, index: int) -> Dictionary:
	var list: Array = INSCRIPTIONS.get(tower, [])
	if list.is_empty():
		return {"title": "Inscription", "text": ""}
	var w: Dictionary = list[posmod(index, list.size())]
	return {"title": Pronouns.fill(String(w["title"])), "text": Pronouns.fill(String(w["text"]))}


## A stone for the floor, maybe: near a room's north wall, on plain floor
## with plain floor all round, never on what matters.
static func plan(p: Dictionary, infos: Array, floor_num: int, tower: String) -> void:
	if not INSCRIPTIONS.has(tower) or floor_num < int(RULES["from"]) or p.get("summit", false) or not p.has("room_info"):
		return
	if randf() > float(RULES["chance"]) and not forced:
		return
	var g := Grid.grid(p)
	var prot := Grid.protected(p, infos)
	for w in p.get("ways_down", []):
		for tt in w["tiles"]:
			for dy in range(-2, 3):
				for dx in range(-2, 3):
					prot[tt + Vector2i(dx, dy)] = true
	for c in p.get("chests", []):
		prot[Grid.tile(c["pos"])] = true
	for pl in p.get("pillars", []):
		prot[Grid.tile(pl["pos"])] = true
	var order: Array = range(1, infos.size())
	order.shuffle()
	for i in order:
		var info: Dictionary = infos[i]
		if String(info["role"]) == "gallery" and String(info.get("puzzle", "")) != "":
			continue
		var th: Dictionary = Themes.get_theme(String(p["themes"][i]))
		if String(th["kind"]) in ["scenario", "mirror", "proving"] or String(th["feature"]) in ["trap", "puzzle", "scenario", "mirror", "vault"]:
			continue
		var rows: Array = info["rows"]
		var at: Vector2i = info["pos"]
		var best := Vector2i(-1, -1)
		var best_d := INF
		for y in range(1, mini(3, rows.size() - 1)):
			for x in range(1, String(rows[0]).length() - 1):
				var tt := at + Vector2i(x, y)
				var ok := true
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var l := Vector2i(x + dx, y + dy)
						var n := tt + Vector2i(dx, dy)
						if l.y < 0 or l.y >= rows.size() or l.x < 0 or l.x >= String(rows[l.y]).length() or String(rows[l.y])[l.x] != "." or not Grid.is_open(g, n) or prot.has(n):
							ok = false
				if not ok:
					continue
				var d := absf(float(x) - String(rows[0]).length() * 0.5) + y * 2.0
				if d < best_d:
					best_d = d
					best = tt
		if best.x >= 0:
			p["inscription"] = {"pos": Grid.centre(best), "tower": tower, "index": floor_num - 1, "room": i}
			p["safe_rooms"] = p.get("safe_rooms", []) + [Rect2(Grid.centre(best) - Vector2(CELL, CELL), Vector2(CELL, CELL) * 2.0)]  # (no trap at its foot)
			return


func _ready() -> void:
	z_index = -2  # (on the floor, under everyone)
	over = Node2D.new()
	over.z_as_relative = false
	over.z_index = 58  # (over the darkness, under the floating numbers)
	over.draw.connect(_draw_over)
	add_child(over)


func setup(p: Dictionary) -> void:
	stone = p.get("inscription", {})
	show_k = 0.0
	read = false
	queue_redraw()
	over.queue_redraw()


## The stone's words, as shown.
func current() -> Dictionary:
	return {} if stone.is_empty() else words(String(stone["tower"]), int(stone["index"]))


func reading() -> bool:
	return show_k > 0.5


func _process(delta: float) -> void:
	if stone.is_empty() or main == null or main.player == null:
		return
	t += delta
	var p = main.player
	var near: bool = not p.dead and p.global_position.distance_to(stone["pos"]) < float(RULES["read"])
	show_k = move_toward(show_k, 1.0 if near else 0.0, delta / float(RULES["fade"]))
	if near and not read:
		read = true
		var w := current()
		main.tip("inscription")
		main.note_event("news", TEXT["log"] % String(w["text"]), LOOK["glow"], true)
		main.sfx("statue_voice", 1.2, -12.0, 0.05)
	queue_redraw()
	over.queue_redraw()


func _seen() -> bool:
	return main.fog == null or not main.layout_on or main.fog.sees(stone["pos"])


func _draw() -> void:
	if stone.is_empty():
		return
	var c: Vector2 = stone["pos"]
	var col: Color = LOOK["stone"]
	# A standing stone: a shadow at its foot, a rounded top, its face carved.
	draw_set_transform(c + Vector2(0, 12), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 14.0, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var body := PackedVector2Array()
	for i in 9:
		var a := PI + i * PI / 8.0
		body.append(c + Vector2(cos(a) * 11.0, -14.0 + sin(a) * 9.0))
	body.append(c + Vector2(12.0, 12.0))
	body.append(c + Vector2(-12.0, 12.0))
	var outline := body + PackedVector2Array([body[0]])
	draw_colored_polygon(body, col)
	draw_polyline(outline, Palette.OUTLINE, 2.0)
	draw_rect(Rect2(c + Vector2(4.0, -16.0), Vector2(7.0, 28.0)), Color(0, 0, 0, 0.18))  # (its shaded side)
	draw_line(c + Vector2(-9.0, -18.0), c + Vector2(-4.0, -21.5), Color(col.lightened(0.35), 0.8), 1.5)  # (lit top)
	# Its base, sunk in the floor.
	draw_rect(Rect2(c + Vector2(-14.0, 10.0), Vector2(28.0, 4.0)), col.darkened(0.3))
	# Carved rows of letters.
	for row in 4:
		var y := -10.0 + row * 5.5
		var x := -7.0
		var k := 0
		while x < 7.0:
			var wdt := 1.5 + 2.5 * fmod(float(row * 7 + k * 3) * 0.37, 1.0)
			draw_line(c + Vector2(x, y), c + Vector2(minf(x + wdt, 7.0), y), Color(0.15, 0.14, 0.17, 0.9), 1.2)
			x += wdt + 1.5
			k += 1


## The carving's faint glow (so it reads in the dark), and the words over it
## while you stand beside it.
func _draw_over() -> void:
	if stone.is_empty() or main == null or not _seen():
		return
	var c: Vector2 = stone["pos"]
	var glow: Color = LOOK["glow"]
	var pulse := 0.55 + 0.45 * sin(t * 1.8)
	for row in 4:
		var y := -10.0 + row * 5.5
		over.draw_line(c + Vector2(-7.0, y), c + Vector2(7.0, y), Color(glow, (0.1 + 0.12 * pulse) * (1.0 - show_k * 0.4)), 1.0)
	if show_k <= 0.01:
		return
	var w := current()
	var f: Font = UI.font("body")
	var tf: Font = UI.font("display")
	var width := 220.0
	var lines: PackedStringArray = _wrap(f, String(w["text"]), 15, width - 20.0)
	var h := 30.0 + lines.size() * 18.0
	var top := c + Vector2(-width * 0.5, -40.0 - h)
	var a := show_k
	over.draw_rect(Rect2(top, Vector2(width, h)), Color(LOOK["plate"], LOOK["plate"].a * a))
	over.draw_rect(Rect2(top, Vector2(width, h)), Color(glow, 0.5 * a), false, 1.5)
	over.draw_string(tf, top + Vector2(0, 20.0), String(w["title"]), HORIZONTAL_ALIGNMENT_CENTER, width, 15, Color(glow, a))
	for i in lines.size():
		over.draw_string(f, top + Vector2(10.0, 40.0 + i * 18.0), lines[i], HORIZONTAL_ALIGNMENT_CENTER, width - 20.0, 15, Color(LOOK["words"], a))
	over.draw_colored_polygon(PackedVector2Array([top + Vector2(width * 0.5 - 6.0, h), top + Vector2(width * 0.5 + 6.0, h), top + Vector2(width * 0.5, h + 7.0)]), Color(glow, 0.5 * a))


static func _wrap(f: Font, text: String, size: int, width: float) -> PackedStringArray:
	var out := PackedStringArray()
	var line := ""
	for word in text.split(" "):
		var next := word if line == "" else line + " " + word
		if line != "" and f.get_string_size(next, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			out.append(line)
			line = word
		else:
			line = next
	if line != "":
		out.append(line)
	return out
