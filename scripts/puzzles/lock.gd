extends "res://scripts/puzzles/base.gd"
## THE ESSENCE LOCK (the web version's lock and lockSpawn): a stone lock
## with no keyhole for a key stands at the head of the room, and a riddle
## on it names one of the six essences (essence.gd). Once the climber is
## well inside, foes appear glowing in different essences, each with its
## essence's sign over it: one in the answer, the rest DECOYS. Slay one and
## it leaves a SPARK of its essence; walk over a spark to carry it (one at a
## time: walking over another swaps them) and bring it to the lock.
##   the right spark   the lock takes it
##   a wrong spark     the lock spits it out: FAILURE (an ambush), then a
##                     new riddle and new glowing foes
## Anyone can solve it by carrying the spark. A bond makes it quicker: a
## spell from a mark of the answer's essence, cast beside the lock, answers
## at once, and so does an item of that essence used there, or a strike from
## a weapon of it (a named piece or a trait of that essence). These never
## fail: a wrong one just doesn't answer.
##   tier 1: one essence; two decoys
##   tier 2: one essence; three decoys
##   tier 3: two or three essences, in order (the riddle says which first);
##           two decoys

const Essence := preload("res://scripts/essence.gd")
const Gear := preload("res://scripts/gear.gd")
const UI := preload("res://scripts/ui.gd")

const NAME := "The Essence Lock"
static var NAMES := {"chimera": "The Hungry Lock"}
static var TEXT := {
	"rule": ["Bring it a spark from a glowing foe, or a spell, item or weapon of that essence."],
	"order": ["First: %s", "Then: %s", "Last: %s"],
	"quiet": "The lock is cold while blood is spilled.",
	"carry": "A spark of %s",
	"swap": "You set down the %s spark",
	"taken": "The lock drinks the %s",
	"wrong": "The lock spits out the spark. Something answers its anger.",
	"not_it": "The lock does not answer",
	"reset": "The lock asks anew",
}
## The riddles, by essence (never naming it). Edit freely.
static var RIDDLES := {
	"air": ["I have no body, yet I bear the hawk aloft. You feel me; you never hold me.",
		"I fill every room and am never seen. Storms are my temper."],
	"water": ["I take the shape of any cup, and wear the mountain down in time.",
		"Rivers are my roads and rain is my falling. Flame flees from me."],
	"iron": ["Dug from the dark and hammered true, I am the shield's bone and the chain's will.",
		"I rust, but I do not yield. Bars and armor are made of me."],
	"fire": ["Feed me and I grow; give me drink and I die.",
		"I dance on the wick and the pyre alike, and leave only ash behind."],
	"stone": ["The mountain's bones. I was here before this tower, and I will be here after.",
		"I am the floor beneath you and the wall beside you, patient and unmoved."],
	"blade": ["I have an edge and no mercy. What I touch, I part.",
		"Thorn, fang and sword are my kin; I am sharpness itself."],
}
const BREAKS := {}
const SEAL_FROM := 2
const MODES := ["quiet"]
## By tier: [essences asked for (least, most), decoys].
const ASKS := {1: [1, 1, 2], 2: [1, 1, 3], 3: [2, 3, 2]}
## How close a spark is picked up, carried to the lock, and how close a
## spell or item must be to answer.
const PICK := 24.0
const INSERT := 44.0
const REACH := 130.0

var lock := Vector2.ZERO
var answers: Array = []  # essence kinds, in order
var decoys: Array = []
var riddles: Array = []  # the riddle text for each answer
var step := 0  # answers given so far
var spawned := false
var glowing: Array = []  # {e, kind, pos}
var sparks: Array = []  # {pos, kind}
var carried := ""
var pick_cd := 0.0  # after picking a spark up, a moment before the next
var note_t := 0.0


static func make(rect: Rect2, _floor_num: int, tier: int, ctx: Dictionary) -> Dictionary:
	var rows: Array = ctx.get("rows", [])
	if rows.is_empty():
		return {}
	var w := String(rows[0]).length()
	var h := rows.size()
	# In the middle of the room, a little north (its riddle hangs above it).
	for shift in [Vector2i(0, 0), Vector2i(-1, 0), Vector2i(1, 0), Vector2i(0, 1)]:
		var at: Vector2i = Vector2i(w / 2, h / 2 - 1) + shift
		var ok := h >= 7
		for y in range(at.y - 1, at.y + 2):
			for x in range(at.x - 1, at.x + 2):
				ok = ok and open_tile(ctx, Vector2i(x, y)) and not reserved(ctx, Vector2i(x, y))
		if not ok:
			continue
		var reserve: Array = []
		for y in range(at.y - 1, at.y + 2):
			for x in range(at.x - 1, at.x + 2):
				reserve.append(Vector2i(x, y))
		var spec := {"lock": tile_center(rect, at), "rewards": [tile_center(rect, at + Vector2i(0, 2))], "reserve": reserve}
		spec.merge(riddle(tier))
		return spec
	return {}


## A riddle for a tier: {answers, decoys, riddles}.
static func riddle(tier: int) -> Dictionary:
	var a: Array = ASKS.get(tier, ASKS[1])
	var kinds: Array = Essence.KINDS.keys()
	kinds.shuffle()
	var n := randi_range(int(a[0]), int(a[1]))
	var answers: Array = kinds.slice(0, n)
	var decoys: Array = kinds.slice(n, n + int(a[2]))
	var lines: Array = []
	for k in answers:
		var pool: Array = RIDDLES[k]
		lines.append(pool[randi() % pool.size()])
	return {"answers": answers, "decoys": decoys, "riddles": lines}


func _build() -> void:
	lock = spec.get("lock", Vector2.ZERO)
	answers = spec.get("answers", [])
	decoys = spec.get("decoys", [])
	riddles = spec.get("riddles", [])
	host.add_round_body(lock, 15.0)


func tick(delta: float) -> void:
	var p = player()
	if p == null or p.dead:
		return
	pick_cd = maxf(0.0, pick_cd - delta)
	if not spawned and room.grow(-CELL * 0.6).has_point(p.global_position):
		_spawn_glowing()
	# A glowing foe that falls leaves a spark of its essence where it fell.
	for g in glowing.duplicate():
		var e = g["e"]
		if is_instance_valid(e) and not e.dead and not e.is_queued_for_deletion():
			g["pos"] = e.global_position
			continue
		glowing.erase(g)
		var at: Vector2 = main.walkable_point(room.get_center(), g["pos"], 14.0) if room.has_point(g["pos"]) else g["pos"]
		sparks.append({"pos": at, "kind": g["kind"]})
		main.fx_ring(at, Essence.color(g["kind"]), 40.0, 0.4, 3.0)
		main.sfx("glint", 1.2, -6.0, 0.0)
	if p.in_air():
		return
	# Walk over a spark to carry it (setting down the one you held).
	for s in sparks:
		if pick_cd <= 0.0 and p.global_position.distance_to(s["pos"]) < PICK:
			pick_cd = 0.8
			var held := carried
			carried = s["kind"]
			sparks.erase(s)
			if held != "":
				sparks.append({"pos": p.global_position + Vector2(0, 26), "kind": held})
				main.fx_text(p.global_position + Vector2(0, -50), TEXT["swap"] % Essence.display(held), Color(0.8, 0.78, 0.85))
			main.fx_text(p.global_position + Vector2(0, -34), TEXT["carry"] % Essence.display(carried), Essence.color(carried))
			main.sfx("pickup", 1.2, -4.0)
			break
	# Bring it to the lock.
	if carried != "" and near_player(lock, INSERT):
		var k := carried
		carried = ""
		if not _take(k):
			host.fail(TEXT["wrong"])


## The glowing foes: one in each essence asked for, and the decoys, in a
## shuffled order around the room.
func _spawn_glowing() -> void:
	spawned = true
	var kinds: Array = answers + decoys
	kinds.shuffle()
	for k in kinds:
		var e = host._spawn_here(2.0)
		if e == null:
			continue
		glowing.append({"e": e, "kind": k, "pos": e.global_position})
		main.fx_burst(e.global_position, Vector2.UP, Essence.color(k), 14, 150.0)


## An essence offered to the lock. True if it was the one it wanted next.
func _take(k: String) -> bool:
	if host.solved or step >= answers.size() or k != answers[step]:
		return false
	step += 1
	main.fx_text(lock + Vector2(0, -40), TEXT["taken"] % Essence.display(k), Essence.color(k))
	main.fx_ring(lock, Essence.color(k), 70.0, 0.5, 3.0)
	main.sfx("glint", 0.8 + 0.2 * step, -2.0, 0.0)
	main.shake(3.0)
	if step >= answers.size():
		host.solve()
	return true


## A bond's spell or an item of essence `k` near the lock: answers it if
## it's the one wanted next (never a failure).
func offer(k: String, pos: Vector2, _how: String) -> bool:
	if pos.distance_to(lock) > REACH:
		return false
	if _take(k):
		return true
	_not_it()
	return false


func _not_it() -> void:
	var now := Time.get_ticks_msec() * 0.001
	if now - note_t > 1.5:
		note_t = now
		main.fx_text(lock + Vector2(0, -36), TEXT["not_it"], Color(0.7, 0.68, 0.75))


## The essences of the weapon in hand: a named piece's own, and its traits'.
func weapon_kinds() -> Array:
	var p = player()
	if p == null:
		return []
	var g = p.weapon_rec()
	var out: Array = []
	var n := Gear.named_id(g)
	if Gear.NAMED.has(n):
		out.append(String(Gear.NAMED[n].get("kind", "")))
	for t in Gear.rec(g).get("traits", []):
		if Gear.TRAITS.has(t):
			out.append(String(Gear.TRAITS[t].get("kind", "")))
	return out


func _weapon_answer() -> void:
	if step < answers.size() and answers[step] in weapon_kinds():
		_take(answers[step])
	else:
		_not_it()
		main.sfx("hit_armor", 0.8, -8.0)


## A strike on the lock: a weapon of the right essence answers.
func strike(from: Vector2, dir: Vector2, reach: float, arc_deg: float) -> int:
	if not in_swing(from, dir, lock, reach, arc_deg):
		return 0
	_weapon_answer()
	return 1


func shot(pos: Vector2) -> bool:
	if pos.distance_to(lock) > 18.0:
		return false
	if host.awake and not host.locked and not host.solved:
		_weapon_answer()
	return true


## After a wrong spark's ambush: a new riddle, and the old glow fades (any
## glowing foe still standing crumbles to dust).
func reset() -> void:
	for g in glowing:
		var e = g["e"]
		if is_instance_valid(e) and not e.dead:
			main.fx_burst(e.global_position, Vector2.UP, Color(0.5, 0.48, 0.52), 12, 120.0)
			e.queue_free()
			e.remove_from_group("enemies")
	main.foes_changed()
	glowing.clear()
	sparks.clear()
	carried = ""
	pick_cd = 0.0
	step = 0
	spawned = false
	var r := riddle(tier)
	answers = r["answers"]
	decoys = r["decoys"]
	riddles = r["riddles"]
	main.fx_text(lock + Vector2(0, -50), TEXT["reset"], Color(0.95, 0.85, 0.6))


func state() -> Array:
	return [step, riddles]


func spot_ok(pos: Vector2) -> bool:
	return pos.distance_to(lock) > 70.0


func aim_points() -> Array:
	return []


func panels() -> Array:
	if not player_in_room(10.0):
		return []
	var lines: Array = []
	if riddles.size() == 1:
		lines.append(riddles[0])
	else:
		for i in riddles.size():
			lines.append(String(TEXT["order"][mini(i, 2)]) % riddles[i])
	lines.append_array(TEXT["rule"])
	return [{"pos": lock + Vector2(0, -30), "title": host.display_name().to_upper(), "lines": lines, "width": 300.0}]


func lights() -> Array:
	var out: Array = []
	var col := Color(1.0, 0.89, 0.63) if host.solved else Color(0.8, 0.6, 1.0)
	out.append([lock, 110.0, col, 0.5, 0.12])
	for g in glowing:
		var e = g["e"]
		if is_instance_valid(e) and e.visible:
			out.append([g["pos"], 80.0, Essence.color(g["kind"]), 0.55, 0.18])
	for s in sparks:
		out.append([s["pos"], 60.0, Essence.color(s["kind"]), 0.6, 0.2])
	if carried != "" and player() != null:
		out.append([player().global_position, 70.0, Essence.color(carried), 0.5, 0.15])
	return out


func draw(ci: CanvasItem) -> void:
	var dark := Color(0.1, 0.09, 0.12)
	var stone := Color(0.4, 0.37, 0.44)
	# The lock: a stele with a ring and no keyhole, sockets beneath for each answer.
	Draw.shadow(ci, lock + Vector2(0, 16), 20.0)
	var body := Rect2(lock + Vector2(-16, -22), Vector2(32, 40))
	ci.draw_rect(body.grow(2.0), dark)
	ci.draw_rect(body, stone)
	ci.draw_rect(Rect2(body.position, Vector2(body.size.x, 5)), stone.lightened(0.2))
	ci.draw_arc(lock + Vector2(0, -6), 9.0, 0.0, TAU, 24, Color(1.0, 0.89, 0.63) if host.solved else Color(0.6, 0.5, 0.75), 2.5)
	ci.draw_circle(lock + Vector2(0, -6), 5.0, dark)
	var n := answers.size()
	for i in n:
		var c := lock + Vector2((i - (n - 1) * 0.5) * 10.0, 10.0)
		ci.draw_circle(c, 4.0, dark)
		if i < step or host.solved:
			ci.draw_circle(c, 3.0, Essence.color(answers[i]) if i < answers.size() else Color.WHITE)


func draw_glow(ci: CanvasItem, t: float) -> void:
	# A halo on the floor under each glowing foe.
	for g in glowing:
		var e = g["e"]
		if not is_instance_valid(e) or not e.visible:
			continue
		var col := Essence.color(g["kind"])
		var r: float = e.radius + 8.0 + 2.0 * sin(t * 4.0)
		ci.draw_circle(g["pos"] + Vector2(0, 4), r, Color(col, 0.25))
		ci.draw_arc(g["pos"] + Vector2(0, 4), r, 0.0, TAU, 28, Color(col, 0.8), 2.0)
	# Sparks: a bright mote with its essence's sign.
	var b := Draw.Batch.new()
	for s in sparks:
		var col := Essence.color(s["kind"])
		var at: Vector2 = s["pos"] + Vector2(0, -4.0 + 3.0 * sin(t * 3.0 + s["pos"].x))
		b.circle(at, 9.0, Color(col, 0.35))
		UI.emblem_into(b, at, 6.5, s["kind"], col, 1.0)
	if carried != "" and player() != null:
		var at: Vector2 = player().global_position + Vector2(0, -38.0 + 2.0 * sin(t * 4.0))
		b.circle(at, 9.0, Color(Essence.color(carried), 0.35))
		UI.emblem_into(b, at, 6.5, carried, Essence.color(carried), 1.0)
	b.flush(ci)
	if not host.solved and host.awake:
		ci.draw_arc(lock + Vector2(0, -6), 13.0 + sin(t * 2.5), 0.0, TAU, 24, Color(0.8, 0.6, 1.0, 0.35), 1.5)


## Over the darkness: each glowing foe's sign floats over it, and the sparks shine.
func draw_over(ci: CanvasItem, t: float) -> void:
	var b := Draw.Batch.new()
	for g in glowing:
		var e = g["e"]
		if not is_instance_valid(e) or not e.visible:
			continue
		var col := Essence.color(g["kind"])
		var at: Vector2 = g["pos"] + Vector2(0, -e.radius - 22.0 + 2.0 * sin(t * 3.0))
		b.circle(at, 10.0, Color(col.r * 0.18, col.g * 0.18, col.b * 0.18))
		UI.emblem_into(b, at, 7.5, g["kind"], Color(col.r * 0.75, col.g * 0.75, col.b * 0.75), 0.0)
	for s in sparks:
		var col := Essence.color(s["kind"])
		b.circle(s["pos"], 6.0, Color(col.r * 0.35, col.g * 0.35, col.b * 0.35))
	b.flush(ci)
