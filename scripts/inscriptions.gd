extends Node2D
## INSCRIPTION STONES: on some floors a standing stone stands near a room's
## north wall, old words cut into it, its letters glowing faintly. Stand
## beside it and the words show over it (walk away and they fade); the
## first reading on a floor goes into the Entity's log of the climb. Nothing
## to press: walking up reads it, so it plays the same with keys, a
## controller or touch.
##
## The words are the owner's to write: INSCRIPTIONS holds six for each tower
## (a stone shows its tower's, by floor: floor 1 and 7 the first, floor 2
## and 8 the second...), every one a blank placeholder for now. Write over
## them here or in the Data editor ("Inscription stones").
##
## Planning: floors.gd calls plan() once the floor (and the tower's own
## ground) is laid: plan["inscription"] = {pos, tower, index}. In play this
## node (main.gd makes one) draws the stone and shows the words.

const Grid := preload("res://scripts/towers/water_wind_grid.gd")
const Palette := preload("res://scripts/palette.gd")
const UI := preload("res://scripts/ui.gd")
const Themes := preload("res://scripts/themes.gd")
const CELL := 40.0

## Each tower's six stones: a title over the words, and the words.
static var INSCRIPTIONS := {
	"gryphon": [
		{"title": "Inscription", "text": "(Inscription to come)"},
		{"title": "Inscription", "text": "(Inscription to come)"},
		{"title": "Inscription", "text": "(Inscription to come)"},
		{"title": "Inscription", "text": "(Inscription to come)"},
		{"title": "Inscription", "text": "(Inscription to come)"},
		{"title": "Inscription", "text": "(Inscription to come)"},
	],
	"kraken": [
		{"title": "Inscription", "text": "(Inscription to come)"},
		{"title": "Inscription", "text": "(Inscription to come)"},
		{"title": "Inscription", "text": "(Inscription to come)"},
		{"title": "Inscription", "text": "(Inscription to come)"},
		{"title": "Inscription", "text": "(Inscription to come)"},
		{"title": "Inscription", "text": "(Inscription to come)"},
	],
	"wyvern": [
		{"title": "Inscription", "text": "(Inscription to come)"},
		{"title": "Inscription", "text": "(Inscription to come)"},
		{"title": "Inscription", "text": "(Inscription to come)"},
		{"title": "Inscription", "text": "(Inscription to come)"},
		{"title": "Inscription", "text": "(Inscription to come)"},
		{"title": "Inscription", "text": "(Inscription to come)"},
	],
	"manticore": [
		{"title": "Inscription", "text": "(Inscription to come)"},
		{"title": "Inscription", "text": "(Inscription to come)"},
		{"title": "Inscription", "text": "(Inscription to come)"},
		{"title": "Inscription", "text": "(Inscription to come)"},
		{"title": "Inscription", "text": "(Inscription to come)"},
		{"title": "Inscription", "text": "(Inscription to come)"},
	],
	"firebird": [
		{"title": "Inscription", "text": "(Inscription to come)"},
		{"title": "Inscription", "text": "(Inscription to come)"},
		{"title": "Inscription", "text": "(Inscription to come)"},
		{"title": "Inscription", "text": "(Inscription to come)"},
		{"title": "Inscription", "text": "(Inscription to come)"},
		{"title": "Inscription", "text": "(Inscription to come)"},
	],
	"chimera": [
		{"title": "Inscription", "text": "(Inscription to come)"},
		{"title": "Inscription", "text": "(Inscription to come)"},
		{"title": "Inscription", "text": "(Inscription to come)"},
		{"title": "Inscription", "text": "(Inscription to come)"},
		{"title": "Inscription", "text": "(Inscription to come)"},
		{"title": "Inscription", "text": "(Inscription to come)"},
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


## The words of a stone ({title, text}).
static func words(tower: String, index: int) -> Dictionary:
	var list: Array = INSCRIPTIONS.get(tower, [])
	if list.is_empty():
		return {"title": "Inscription", "text": "(Inscription to come)"}
	return list[posmod(index, list.size())]


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
