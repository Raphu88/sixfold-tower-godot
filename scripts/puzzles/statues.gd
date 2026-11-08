extends "res://scripts/puzzles/base.gd"
## THREE STATUES (the web version's genThree): three statues stand before
## three plates, each saying something about where the way lies and about
## each other. One always tells the truth and the other two always lie; a
## rules plaque says so. Statements are drawn at random until EXACTLY ONE
## plate fits every way the roles could be shared out (the solver tries them
## all), so there's always one answer to reason out.
##   tier 1: one statement each
##   tier 2: one statement each, at least one about another statue's honesty
##   tier 3: two statements each, and the third statue ALTERNATES: one of its
##           two statements is true and the other false
## Stand on a plate for STAND seconds to choose it. The right one solves it;
## a wrong one FAILS: an ambush, then the statues speak a new riddle.

const NAME := "Three Statues"
const NAMES := {"manticore": "The Riddling Statues"}
const TEXT := {
	"rule": ["One of us always speaks true. The other two always lie.", "Stand on the plate behind the true way."],
	"rule_alt": ["One of us always speaks true, one always lies, and one speaks once true and once false.", "Stand on the plate behind the true way."],
	"plaque": "The plaque reads:",
	"quiet": "The statues will not speak while blood is spilled.",
	"wrong": "The floor gives a hollow groan. Something wakes.",
	"reset": "The statues speak anew",
	"keen": "Your keen eyes catch it: this one lies",
	"names": ["the left statue", "the middle statue", "the right statue"],
	"Names": ["The left statue", "The middle statue", "The right statue"],
	# The statements, by what they claim ("%s" is another statue's name).
	"self_is": "The way lies behind me.",
	"self_not": "The way does not lie behind me.",
	"other_is": "The way lies behind %s.",
	"other_not": "The way does not lie behind %s.",
	"other_liar": "%s always lies.",
	"other_true": "%s always tells the truth.",
}
const BREAKS := {"hunter": "Keen Eyes: after a few moments near the statues, you see which of them lie."}
const SEAL_FROM := 2
const MODES := ["quiet", "pressure"]
const KINDS := ["self_is", "self_not", "other_is", "other_not", "other_liar", "other_true"]
## How long you stand on a plate to choose it.
const STAND := 1.0
const PLATE_REACH := 16.0
## Keen Eyes: this long near the statues shows the liars.
const KEEN_TIME := 3.0

var statues: Array = []  # world positions (left to right)
var plates: Array = []  # {pos, k, t}
var plaque := Vector2.ZERO
var lines: Array = []  # each statue's statements (text)
var statements: Array = []  # the same, as [kind, other statue, own index] (for the solver)
var answer := 0
var liars: Array = []  # the statues that lie (or alternate) in one consistent reading
var keen_t := 0.0
var keen := false


static func make(rect: Rect2, _floor_num: int, tier: int, ctx: Dictionary) -> Dictionary:
	var rows: Array = ctx.get("rows", [])
	if rows.is_empty():
		return {}
	var w := String(rows[0]).length()
	var h := rows.size()
	var gap := 4 if w >= 13 else 3
	var layouts: Array = []
	for south in [false, true]:
		for shift in [0, -1, 1]:
			layouts.append([south, shift])
	layouts.shuffle()
	for lay in layouts:
		var south: bool = lay[0]
		var cx: int = w / 2 + int(lay[1])
		var py := h - 3 if south else 2
		var sy := h - 5 if south else 4
		var qy := 2 if south else h - 3
		if absi(qy - sy) < 2 or cx - gap < 1 or cx + gap > w - 2:
			continue
		var tiles: Array = []
		for k in 3:
			var x := cx + (k - 1) * gap
			tiles.append(Vector2i(x, py))
			tiles.append(Vector2i(x, sy))
		tiles.append(Vector2i(cx, qy))
		var ok := true
		for t in tiles:
			ok = ok and open_tile(ctx, t) and not reserved(ctx, t)
		if not ok:
			continue
		var riddle := gen_three(tier)
		if riddle.is_empty():
			return {}
		var st: Array = []
		var pl: Array = []
		for k in 3:
			var x := cx + (k - 1) * gap
			pl.append(tile_center(rect, Vector2i(x, py)))
			st.append(tile_center(rect, Vector2i(x, sy)))
		var reserve: Array = []
		for y in range(mini(py, sy) - 1, maxi(py, sy) + 2):
			for x in range(cx - gap - 1, cx + gap + 2):
				reserve.append(Vector2i(x, y))
		reserve.append(Vector2i(cx, qy))
		return {"statues": st, "plates": pl, "plaque": tile_center(rect, Vector2i(cx, qy)), "south": south,
			"lines": riddle["lines"], "statements": riddle["statements"], "answer": riddle["door"], "liars": riddle["liars"],
			"rewards": [tile_center(rect, Vector2i(cx, (py + qy) / 2))], "reserve": reserve}
	return {}


## Whether a statement holds when the way is behind statue `door` and the
## statues' roles are `roles` ("T" truthful, "L" liar, "A" alternates).
static func holds(s: Array, door: int, roles: Array) -> bool:
	var j: int = s[1]
	match String(s[0]):
		"self_is":
			return door == s[2]
		"self_not":
			return door != s[2]
		"other_is":
			return door == j
		"other_not":
			return door != j
		"other_liar":
			return roles[j] == "L"
		"other_true":
			return roles[j] == "T"
	return false


## Whether the statues' statements fit a door and a sharing-out of roles.
static func fits(st: Array, door: int, roles: Array) -> bool:
	for i in 3:
		var n_true := 0
		for s in st[i]:
			if holds(s, door, roles):
				n_true += 1
		match String(roles[i]):
			"T":
				if n_true != st[i].size():
					return false
			"L":
				if n_true != 0:
					return false
			_:
				if n_true != 1:
					return false
	return true


## Every way to share out the roles at this tier.
static func role_sets(tier: int) -> Array:
	if tier < 3:
		return [["T", "L", "L"], ["L", "T", "L"], ["L", "L", "T"]]
	var out: Array = []
	for a in ["T", "L", "A"]:
		for b in ["T", "L", "A"]:
			for c in ["T", "L", "A"]:
				if a != b and b != c and a != c:
					out.append([a, b, c])
	return out


## The doors that fit the statements (the solver): exactly one means a fair riddle.
static func solve_doors(st: Array, tier: int) -> Array:
	var doors: Array = []
	for d in 3:
		for r in role_sets(tier):
			if fits(st, d, r):
				doors.append(d)
				break
	return doors


## Random statements until exactly one door fits (the web version's genThree).
## {lines: [[text]...], door, statements, liars} or {} (never in practice).
static func gen_three(tier: int) -> Dictionary:
	var per := 2 if tier >= 3 else 1
	for tries in 1500:
		var st: Array = []
		var meta := false
		for i in 3:
			var mine: Array = []
			for k in per:
				var others: Array = [0, 1, 2].filter(func(x): return x != i)
				var j: int = others[randi() % 2]
				var kind: String = KINDS[randi() % KINDS.size()]
				meta = meta or kind.begins_with("other_t") or kind.begins_with("other_l")
				mine.append([kind, j, i])
			st.append(mine)
		if tier == 2 and not meta:
			continue
		# (Two of the same statement from one statue says nothing new, and a
		# statement with its own opposite gives the alternating one away.)
		var dup := false
		for i in 3:
			if per == 2 and _same_subject(st[i][0], st[i][1]):
				dup = true
		if dup:
			continue
		var doors := solve_doors(st, tier)
		if doors.size() != 1:
			continue
		var liars: Array = []
		for r in role_sets(tier):
			if fits(st, doors[0], r):
				for i in 3:
					if r[i] != "T":
						liars.append(i)
				break
		return {"lines": words(st), "door": doors[0], "statements": st, "liars": liars}
	return {}


## Whether two statements are about the same thing (the same door, or the
## same statue's honesty): saying both is a repeat or a giveaway.
static func _same_subject(a: Array, b: Array) -> bool:
	var ka := String(a[0])
	var kb := String(b[0])
	var door_a := ka.ends_with("_is") or ka.ends_with("_not")
	var door_b := kb.ends_with("_is") or kb.ends_with("_not")
	if door_a and door_b:
		var ta: int = a[2] if ka.begins_with("self") else a[1]
		var tb: int = b[2] if kb.begins_with("self") else b[1]
		return ta == tb
	if not door_a and not door_b:
		return a[1] == b[1]
	return false


## The statements as the statues say them.
static func words(st: Array) -> Array:
	var out: Array = []
	for i in 3:
		var mine: Array = []
		for s in st[i]:
			var kind: String = s[0]
			var text: String = TEXT[kind]
			if kind.begins_with("other_t") or kind.begins_with("other_l"):
				text = text % TEXT["Names"][s[1]]
			elif kind.begins_with("other"):
				text = text % TEXT["names"][s[1]]
			mine.append(text)
		out.append(mine)
	return out


func _build() -> void:
	statues = spec.get("statues", [])
	plaque = spec.get("plaque", Vector2.ZERO)
	for k in spec.get("plates", []).size():
		plates.append({"pos": spec["plates"][k], "k": k, "t": 0.0})
	lines = spec.get("lines", [])
	statements = spec.get("statements", [])
	answer = int(spec.get("answer", 0))
	liars = spec.get("liars", [])
	for s in statues:
		host.add_round_body(s, 14.0)


func tick(delta: float) -> void:
	for q in plates:
		if near_player(q["pos"], PLATE_REACH) and not player().in_air():
			q["t"] += delta
			if q["t"] >= STAND:
				q["t"] = 0.0
				if q["k"] == answer:
					host.solve()
				else:
					host.fail(TEXT["wrong"])
				return
		else:
			q["t"] = 0.0
	# Hunter's Keen Eyes: a few moments near the statues shows the liars.
	if not keen and has_bond("hunter") and statues.size() == 3 and near_player(statues[1], 260.0):
		keen_t += delta
		if keen_t >= KEEN_TIME:
			keen = true
			for i in liars:
				main.fx_text(statues[i] + Vector2(0, -44), TEXT["keen"], Color(1.0, 0.55, 0.45))
			main.sfx("glint", 0.8, -4.0, 0.0)


func state() -> Array:
	return [keen, lines]


## A new riddle (after a wrong plate's ambush), on the same statues.
func reset() -> void:
	var riddle := gen_three(tier)
	if not riddle.is_empty():
		lines = riddle["lines"]
		statements = riddle["statements"]
		answer = riddle["door"]
		liars = riddle["liars"]
	keen = false
	keen_t = 0.0
	for q in plates:
		q["t"] = 0.0
	main.fx_text(room.get_center() + Vector2(0, -30), TEXT["reset"], Color(0.95, 0.85, 0.6))


## Arrows clatter off the statues.
func shot(pos: Vector2) -> bool:
	for s in statues:
		if pos.distance_to(s) < 15.0:
			return true
	return false


func spot_ok(pos: Vector2) -> bool:
	for q in plates:
		if q["pos"].distance_to(pos) < 50.0:
			return false
	for s in statues:
		if s.distance_to(pos) < 50.0:
			return false
	return true


func panels() -> Array:
	if not player_in_room(10.0):
		return []
	var out: Array = []
	var south: bool = spec.get("south", false)
	# The plaque's rules, on the side away from the statues.
	out.append({"pos": plaque + Vector2(0, 26.0 if not south else -26.0), "below": not south,
		"title": host.display_name().to_upper(), "lines": TEXT["rule_alt"] if tier >= 3 else TEXT["rule"]})
	if not host.awake:
		return out
	# The statue nearest a climber who comes close speaks (over its plate's side).
	var best := -1
	var best_d := 150.0
	for i in mini(statues.size(), lines.size()):
		var d: float = player().global_position.distance_to(statues[i])
		if d < best_d:
			best_d = d
			best = i
	if best >= 0:
		var lie: bool = keen and best in liars
		out.append({"pos": statues[best] + Vector2(0, 22.0 if south else -32.0), "below": south,
			"lines": lines[best], "width": 170.0, "tone": "bad" if lie else ""})
	return out


func draw(ci: CanvasItem) -> void:
	var dark := Color(0.12, 0.1, 0.14)
	# The plates: worn gold squares.
	for q in plates:
		var c: Vector2 = q["pos"]
		var r := Rect2(c - Vector2(15, 15), Vector2(30, 30))
		ci.draw_rect(r.grow(2.0), dark)
		var right: bool = host.solved and q["k"] == answer
		ci.draw_rect(r, Color(1.0, 0.89, 0.63) if right else Color(0.55, 0.45, 0.26))
		ci.draw_rect(r.grow(-6.0), Color(0.42, 0.34, 0.2) if not right else Color(1.0, 0.95, 0.75))
	# The plaque: a stone tablet set in the floor.
	var pr := Rect2(plaque - Vector2(16, 9), Vector2(32, 18))
	ci.draw_rect(pr.grow(2.0), dark)
	ci.draw_rect(pr, Color(0.36, 0.32, 0.38))
	for k in 3:
		ci.draw_line(pr.position + Vector2(5, 5 + k * 4), pr.position + Vector2(27, 5 + k * 4), Color(0.6, 0.55, 0.62), 1.0)
	# The statues: robed figures on plinths, eyes towards the plaque.
	var south: bool = spec.get("south", false)
	for i in statues.size():
		var s: Vector2 = statues[i]
		var lie: bool = keen and i in liars
		Draw.shadow(ci, s + Vector2(0, 12), 15.0)
		ci.draw_rect(Rect2(s + Vector2(-14, 6), Vector2(28, 10)), Color(0.3, 0.27, 0.32))
		var body := PackedVector2Array([s + Vector2(-10, 8), s + Vector2(-7, -14), s + Vector2(7, -14), s + Vector2(10, 8)])
		Draw.poly(ci, body, Color(0.55, 0.52, 0.6))
		Draw.ball(ci, s + Vector2(0, -20), 7.0, Color(0.6, 0.57, 0.65))
		var eye_y := -21.0 if not south else -19.0
		var eye_col := Color(1.0, 0.45, 0.35) if lie else dark
		ci.draw_rect(Rect2(s + Vector2(-4, eye_y), Vector2(2.5, 2.5)), eye_col)
		ci.draw_rect(Rect2(s + Vector2(1.5, eye_y), Vector2(2.5, 2.5)), eye_col)


func draw_glow(ci: CanvasItem, t: float) -> void:
	if host.solved or not host.awake:
		return
	# Standing on a plate: a ring fills as the choice is made.
	for q in plates:
		if q["t"] > 0.0:
			ci.draw_arc(q["pos"], 20.0, -PI / 2.0, -PI / 2.0 + TAU * q["t"] / STAND, 28, Color(1.0, 0.89, 0.63), 2.5)
		else:
			ci.draw_arc(q["pos"], 19.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.5, 0.25 + 0.15 * sin(t * 2.5 + q["k"])), 1.2)


func lights() -> Array:
	var out: Array = []
	if host.solved:
		out.append([plates[answer]["pos"], 120.0, Color(1.0, 0.85, 0.55), 0.7, 0.2])
	return out
