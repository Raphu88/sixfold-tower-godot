extends Node2D
## The secret bonds' depth 3 to 5 tools in play: edit, reroll, build (and the
## Developer's splice and write). The data and rules are in secret_bonds.gd;
## the tool ring, costs and the depth 1 and 2 tools in secret_tools.gd (this
## node's parent, `tools`), which hands these tools over through `open`.
##
## A tool here offers a CHOICE on the camp's card screen (main.gd's camp
## cards, stage "secret"): keys, a controller, a click or a tap take a card,
## and the last card always leaves without paying. The monsters hold still
## while the cards show. A card that does something is paid for as it's
## taken (secret_tools.pay); a tool with two steps (Splice, Write, Reroll) is
## paid at its last step.
##
##   Developer   Splice (4): a spell of yours takes another mark's behaviour
##               for the floor (SPLICE_FROM); Write (5): once a floor, cast a
##               spell of a bond you don't hold. Edit (3) and moving marks are
##               on the train (secret_page.gd).
##   Designer    Edit (3): re-time a trap room, move a trap, raise or sink a
##               wall for a while; Reroll (4): the next floor's puzzle and how
##               its rooms lean; Build (5): your own trap, wall or gate, and
##               once a climb a passage to the stair (a pair of gates: it
##               changes no wall, so it can't break a floor).
##   Manipulator Edit (3): tune a monster or turn it into a weaker kind;
##               Reroll (4): a sleeping room's pack, from two; Build (5): a
##               monster rewritten into your own, with a second kind's attack.
##
## Safety: the Designer never shuts the stair away (a wall is refused if it
## would), never leaves a trap room uncrossable by timing (Traps.hard_tiles
## is checked before and after: a change that adds a tile with no safe moment
## is undone), and never opens the floor's outer wall, a sealed wing, a secret
## room, a vault, the puzzle's sealed room or the Proving. The Manipulator
## leaves great foes, key carriers and the monsters bound to a floor's test alone.
##
## This node draws on the floor (z -4: walls, gates and the passage); the
## wireframes and readouts are drawn by secret_tools.gd over the darkness
## (draw_world).

const SB := preload("res://scripts/secret_bonds.gd")
const Secret := preload("res://scripts/secret.gd")
const Traps := preload("res://scripts/traps.gd")
const Floors := preload("res://scripts/floors.gd")
const Themes := preload("res://scripts/themes.gd")
const Catalog := preload("res://scripts/puzzles/catalog.gd")
const Essence := preload("res://scripts/essence.gd")
const Draw := preload("res://scripts/draw_util.gd")
const Palette := preload("res://scripts/palette.gd")

const C := Floors.CELL
const LEAVE := {"id": "leave"}

var tools  # secret_tools.gd
var main
# The cards showing (the camp's card screen).
var cards_tool := ""
var cards: Array = []
var cards_ctx := {}
var _frozen: Array = []
var _prev_camp := {}
# This floor.
var once := {}  # tools used once this floor (id -> true)
var splice := {}  # the Developer's Splice: {part, spell, name, from, effect, color}
var _rec = null  # a spliced cast as it's cast: {struck, n, dmg}
var splices := 0  # (tests) behaviours a splice has given
var walls: Array = []  # {tiles, body, t, kind ("raise", "sink", "build"), runs}
var gates: Array = []  # {tiles, body}
var portal := {}  # {a, b, inside}
var builds := 0  # the Designer's builds this floor (the passage aside)
var retimed := {}  # trap rooms re-timed (room index -> true)
var trails: Array = []  # traps moved: {from, to, t}
var built = null  # the Manipulator's rewritten monster
var built_second := ""
var _built_t := 0.0
var _built_hit := {}  # its last second attack, drawn a moment: {from, to, t}
var rerolled := {}  # rooms rerolled (room index -> true)
var edited := 0  # monsters edited this floor (their tags are drawn)
# This climb.
var reroll_next := {}  # the Designer's Reroll, waiting for the next floor of rooms: {puzzle, lean, from}
var lean_used := {}  # (tests) the last floor planned with a reroll: {puzzle, lean, floor}
var passage_used := false
var _saved_forced := ""
var _lean_on := false
var _anim := 0.0


func _ready() -> void:
	z_as_relative = false
	z_index = -4  # on the floor: over the room (-10) and the traps (-5), under everyone


func new_floor() -> void:
	if cards_tool != "":
		_close_cards()
	once = {}
	splice = {}
	_rec = null
	for w in walls:  # (a sunk wall's pieces went with the floor's layout; a raised one's body goes now)
		if w["body"] != null and is_instance_valid(w["body"]):
			w["body"].queue_free()
	walls = []
	for g in gates:
		if is_instance_valid(g["body"]):
			g["body"].queue_free()
	gates = []
	portal = {}
	builds = 0
	retimed = {}
	trails = []
	built = null
	built_second = ""
	_built_hit = {}
	rerolled = {}
	edited = 0
	queue_redraw()


## Anything to draw or tick.
func active() -> bool:
	return cards_tool != "" or not walls.is_empty() or not gates.is_empty() or not portal.is_empty() or built != null \
		or not trails.is_empty() or edited > 0 or not splice.is_empty()


## Why a tool can't be used again ("" if it can): used once this floor.
func used_up(id: String) -> String:
	if SB.TOOLS.get(id, {}).get("once", "") == "floor" and once.has(id):
		return SB.TEXT["once_floor"]
	return ""


func _no(why: String) -> bool:
	tools.message = why
	return false


func _physics_process(delta: float) -> void:
	if main == null or main.player == null:
		return
	if cards_tool != "":
		main.player.iframes = maxf(main.player.iframes, 0.2)  # (nothing hurts you while you choose)
		return
	_anim += delta
	if not walls.is_empty():
		_tick_walls(delta)
	if not portal.is_empty():
		_tick_portal()
	if built != null:
		_tick_built(delta)
	if not trails.is_empty():
		for tr in trails:
			tr["t"] -= delta
		trails = trails.filter(func(tr): return tr["t"] > 0.0)
	if not _built_hit.is_empty():
		_built_hit["t"] -= delta
		if _built_hit["t"] <= 0.0:
			_built_hit = {}
	if not walls.is_empty() or not gates.is_empty() or not portal.is_empty() or not main.traps.is_empty() and builds > 0:
		queue_redraw()


# --- the cards -------------------------------------------------------------------

## Opens a tool's choice (secret_tools.use). False (tools.message says why) if
## there's nothing to choose.
func open(id: String, target) -> bool:
	if used_up(id) != "":
		return _no(used_up(id))
	match id:
		"dev_splice":
			return _open_splice()
		"dev_write":
			return _open_write()
		"des_edit":
			return _open_des_edit(target)
		"des_reroll":
			return _open_reroll()
		"des_build":
			return _open_build()
		"man_edit":
			return _open_medit(target)
		"man_reroll":
			return _open_mreroll(target)
		"man_build":
			return _open_mbuild(target)
	return _no(SB.TEXT["no_tools"])


func _show_cards(tool: String, title: String, lines: Array, list: Array, ctx := {}) -> bool:
	if cards_tool == "" and _prev_camp.is_empty():
		_prev_camp = main.camp  # (a camp floor's own state, put back after)
	cards_tool = tool
	cards = list.duplicate()
	cards.append(LEAVE)
	cards_ctx = ctx
	var ids: Array = []
	for i in cards.size():
		ids.append("sb:%d" % i)
	main.camp = {"stage": "secret", "choices": ids, "lines": lines, "title": title}
	main.camp_choosing = true
	main.card_focus = 0
	main.banner = {}
	main.player.set_physics_process(false)
	_frozen.clear()
	for e in main.enemies():
		if e.is_physics_processing():
			e.set_physics_process(false)
			_frozen.append(e)
	main.sfx("ready", 1.1, -6.0, 0.0)
	return true


func _close_cards() -> void:
	cards_tool = ""
	cards = []
	cards_ctx = {}
	main.camp_choosing = false
	main.camp = _prev_camp
	_prev_camp = {}
	if main.player != null:
		main.player.set_physics_process(true)
	for e in _frozen:
		if is_instance_valid(e):
			e.set_physics_process(true)
	_frozen.clear()


## A card as main.camp_card gives it: {name, desc, color, item, note}.
func card(pick: String) -> Dictionary:
	var i := int(pick.substr(3))
	if i < 0 or i >= cards.size():
		return {"name": "", "desc": "", "color": Color.WHITE, "item": ""}
	var c: Dictionary = cards[i]
	if c["id"] == "leave":
		return {"name": SB.TEXT["leave"], "desc": SB.TEXT["leave_desc"], "color": Color(0.6, 0.58, 0.66), "item": ""}
	var out := {"name": c["name"], "desc": c["desc"], "color": c.get("color", SB.color(tools.bond())), "item": ""}
	if c.has("cost"):
		var q: Dictionary = SB.quote(c["cost"], main.run_essence, main.run_flow, main.profile.path)
		out["note"] = _cost_short(c["cost"]) if q["ok"] else String(q["short"])
	elif c.has("note"):
		out["note"] = c["note"]
	return out


func _cost_short(cost: Dictionary) -> String:
	var bits: Array = []
	var f := float(cost.get("flow", 0.0))
	if f > 0.0:
		var kind := String(cost.get("flow_kind", "any"))
		bits.append("%d %s" % [int(f), Secret.display(main.profile.path if kind == "any" and main.profile.path != "" else kind) if kind != "any" or main.profile.path != "" else "flow"])
	if float(cost.get("essence", 0.0)) > 0.0:
		bits.append("%d essence" % int(cost["essence"]))
	return " + ".join(bits)


## Takes a card (main.choose_camp): pays for it, then does it (or opens the next step).
func take_card(i: int) -> void:
	if i < 0 or i >= cards.size():
		return
	var c: Dictionary = cards[i]
	if c["id"] == "leave":
		_close_cards()
		main.sfx("ui_move", 0.9, -6.0, 0.0)
		return
	if c.has("cost") and not tools.pay(c["cost"]):
		return  # (the cards stay; what's missing shows over the climber)
	var tool := cards_tool
	var ctx := cards_ctx
	_close_cards()
	if c.has("cost"):
		tools.used[tool] = true
		tools.show_t = tools.SHOW_TIME
	match tool:
		"splice1":
			_open_splice2(String(c["id"]))
		"dev_splice":
			_take_splice(c, ctx)
		"write1":
			_open_write2(String(c["id"]))
		"write2":
			_open_write3(String(c["id"]))
		"dev_write":
			_take_write(c)
		"des_edit":
			_take_des_edit(c, ctx)
		"reroll1":
			_open_reroll2(String(c["id"]))
		"des_reroll":
			_take_reroll(c, ctx)
		"des_build":
			_take_build(c)
		"man_edit":
			_take_medit(c, ctx)
		"man_reroll":
			_take_mreroll(c, ctx)
		"man_build":
			_take_mbuild(c, ctx)
	main.sfx("glint", 0.8, -4.0, 0.0)


func _paid_card(id: String, name: String, desc: String, color: Color, cost: Dictionary, extra := {}) -> Dictionary:
	var c := {"id": id, "name": name, "desc": desc, "color": color, "cost": cost}
	c.merge(extra)
	return c


# --- the Developer: Splice -------------------------------------------------------

func _open_splice() -> bool:
	var p = main.player
	if p.bonds.size() < 2:
		return _no(SB.TEXT["splice_need"])
	var list: Array = []
	for part in main.BondScript.Bonds.PARTS:
		if not p.bonds.has(part):
			continue
		var bd = p.bonds[part]
		var sp: Dictionary = bd.spell()
		var note := ""
		if splice.get("part", "") == part:
			note = SB.TEXT["splice_tag"] % SB.SPLICE_FX[splice["effect"]]["name"]
		list.append({"id": part, "name": sp["name"], "desc": "%s  ·  %s" % [bd.display_name(), main.BondScript.PART_NAMES[part]], "color": bd.color(), "note": note})
	return _show_cards("splice1", SB.TEXT["splice_title"], [SB.TOOLS["dev_splice"]["short"]], list)


func _open_splice2(part: String) -> void:
	var p = main.player
	var target = p.bonds.get(part)
	if target == null:
		return
	var list: Array = []
	for other in main.BondScript.Bonds.PARTS:
		if other == part or not p.bonds.has(other):
			continue
		var bd = p.bonds[other]
		var fx := SB.splice_effect(bd.id)
		list.append(_paid_card(other, "%s: %s" % [bd.display_name(), SB.SPLICE_FX[fx]["name"]], "%s %s." % [target.spell_name(), SB.SPLICE_FX[fx]["desc"]],
			bd.color(), SB.TOOLS["dev_splice"]["cost"]))
	_show_cards("dev_splice", SB.TEXT["splice_title2"], [target.spell_name()], list, {"part": part})


func _take_splice(c: Dictionary, ctx: Dictionary) -> void:
	var p = main.player
	var target = p.bonds.get(ctx.get("part", ""))
	var src = p.bonds.get(String(c["id"]))
	if target == null or src == null:
		return
	splice = {"part": target.part, "spell": target.spell()["id"], "name": target.spell_name(), "from": src.id,
		"effect": SB.splice_effect(src.id), "color": src.color()}
	main.fx_text(p.global_position + Vector2(0, -40), SB.TEXT["splice_done"] % [splice["name"], SB.SPLICE_FX[splice["effect"]]["name"]], SB.color("developer"))
	main.fx_ring(p.global_position, src.color(), 40.0, 0.4, 2.0)
	main.tip("tool_splice")


## A spell is about to be cast: if it's the spliced one, what it strikes is recorded.
func before_cast(b):
	if splice.is_empty() or b.part != splice["part"] or b.spell()["id"] != splice["spell"]:
		return null
	_rec = {"struck": [], "n": main.get_child_count(), "dmg": b.damage()}
	return _rec


func struck(e) -> void:
	if _rec != null and not e in _rec["struck"]:
		_rec["struck"].append(e)


## The spliced spell was cast: its behaviour goes to what it struck, to its
## shot, or (striking nothing at once) to the foes around you.
func after_cast(_b, rec) -> void:
	_rec = null
	if rec == null or splice.is_empty():
		return
	var sp := splice.duplicate()
	sp["dmg"] = float(rec["dmg"]) if float(rec["dmg"]) > 0.0 else 8.0
	var done := false
	for e in rec["struck"]:
		if is_instance_valid(e) and not e.dead:
			splice_hit(e, sp)
			done = true
	var kids: Array = main.get_children()
	for i in range(int(rec["n"]), kids.size()):
		var k = kids[i]
		if "splice" in k and "friendly" in k and k.friendly:
			k.splice = sp
			done = true
	if not done:
		var p = main.player
		main.fx_ring(p.global_position, sp["color"], SB.SPLICE_PULSE, 0.35, 2.0)
		for e in main.targets().duplicate():
			if e.global_position.distance_to(p.global_position) < SB.SPLICE_PULSE + e.radius:
				splice_hit(e, sp)


## One foe takes a splice's behaviour.
func splice_hit(e, sp: Dictionary) -> void:
	if e == null or not is_instance_valid(e) or e.dead:
		return
	var p = main.player
	var fx: Dictionary = SB.SPLICE_FX.get(String(sp.get("effect", "")), {})
	if fx.is_empty():
		return
	var col: Color = sp.get("color", SB.color("developer"))
	var to: Vector2 = e.global_position - p.global_position
	var away: Vector2 = to.normalized() if to.length() > 1.0 else p.aim
	var heavy: float = 0.15 if e.is_boss() else 1.0
	var dmg := float(sp.get("dmg", 8.0))
	match String(sp["effect"]):
		"pull":
			e.knock = -away * float(fx["force"]) * heavy
		"knock":
			e.knock = away * float(fx["force"]) * heavy
		"burn":
			e.ignite(float(fx["dmg"]), float(fx["seconds"]))
		"poison":
			e.add_venom(int(fx["stacks"]))
		"stun":
			e.stagger(float(fx["seconds"]))
		"heal":
			p.mend_by(float(fx["heal"]))
		"expose":
			e.challenged_t = maxf(e.challenged_t, float(fx["seconds"]))
		"cripple":
			e.cripple_t = maxf(e.cripple_t, float(fx["seconds"]))
		"blind":
			e.lose_track(float(fx["seconds"]), null)
		"bolt":
			var best = null
			var best_d := float(fx["reach"])
			for o in main.targets():
				if o == e:
					continue
				var d: float = o.global_position.distance_to(e.global_position)
				if d < best_d:
					best_d = d
					best = o
			if best != null:
				main.fx_bolt([e.global_position, best.global_position], col)
				best.take_hit(dmg * float(fx["share"]), (best.global_position - e.global_position).normalized(), 90.0)
		"burst":
			main.fx_ring(e.global_position, col, float(fx["radius"]), 0.3, 3.0)
			for o in main.targets().duplicate():
				if o != e and o.global_position.distance_to(e.global_position) < float(fx["radius"]) + o.radius:
					o.take_hit(dmg * float(fx["share"]), (o.global_position - e.global_position).normalized(), 120.0)
	splices += 1
	if is_instance_valid(e):
		main.fx_ring(e.global_position, col, e.radius + 10.0, 0.25, 1.5)


# --- the Developer: Write --------------------------------------------------------

## The step your best bond has reached (at least 1).
func best_step() -> int:
	var s := 1
	for bd in main.player.bonds.values():
		s = maxi(s, int(bd.step))
	return s


func _write_choices() -> Dictionary:
	var held: Array = main.player.bonds.values().map(func(bd): return bd.id)
	return SB.write_bonds(held, best_step(), main.BondScript.Bonds.BONDS)


func _open_write() -> bool:
	var by := _write_choices()
	if by.is_empty():
		return _no(SB.TEXT["write_none"])
	var list: Array = []
	for kind in Essence.KINDS:
		if not by.has(kind):
			continue
		var names: Array = by[kind].map(func(id): return main.BondScript.Bonds.BONDS[id]["name"])
		list.append({"id": kind, "name": Essence.display(kind), "desc": ", ".join(names), "color": Essence.color(kind)})
	return _show_cards("write1", SB.TEXT["write_title"], [SB.TEXT["write_sub"] % best_step()], list)


func _open_write2(kind: String) -> void:
	var by := _write_choices()
	var list: Array = []
	for id in by.get(kind, []):
		var d: Dictionary = main.BondScript.Bonds.BONDS[id]
		var names: Array = SB.write_spells(d, best_step()).map(func(sp): return sp["name"])
		list.append({"id": id, "name": d["name"], "desc": ", ".join(names), "color": d["color"]})
	_show_cards("write2", SB.TEXT["write_title2"], [SB.TEXT["write_sub"] % best_step()], list)


func _open_write3(bond_id: String) -> void:
	var d: Dictionary = main.BondScript.Bonds.BONDS[bond_id]
	var list: Array = []
	for sp in SB.write_spells(d, best_step()):
		list.append(_paid_card(String(sp["id"]), sp["name"], String(sp["desc"]), d["color"], SB.TOOLS["dev_write"]["cost"], {"bond": bond_id}))
	_show_cards("dev_write", SB.TEXT["write_title3"], [String(d["name"]) + "  ·  " + SB.TEXT["write_sub"] % best_step()], list)


func _take_write(c: Dictionary) -> void:
	once["dev_write"] = true
	write_cast(String(c["bond"]), String(c["id"]))


## Casts a bond's spell the climber doesn't hold, at their best step (free of
## any mark's essence: the tool paid for it).
func write_cast(bond_id: String, spell_id: String) -> bool:
	var p = main.player
	var B = main.BondScript
	var part := ""
	for pt in B.Bonds.PARTS:
		if not p.bonds.has(pt):
			part = pt
			break
	if part == "":
		part = "hand"
	var b = B.new(bond_id, part)
	b.step = best_step()
	var known: Array = b.spells()
	var idx := -1
	for i in known.size():
		if known[i]["id"] == spell_id:
			idx = i
	if idx < 0:
		return false
	b.select(idx)
	b.essence = b.capacity()
	b.attr_power = 1.0 + main.profile.attribute("fire")
	main.cast_hits = 0
	main.counting_hits = true
	b.cast(p)
	main.counting_hits = false
	main.fx_text(p.global_position + Vector2(0, -46), SB.TEXT["write_done"] % b.spell_name(), SB.color("developer"))
	main.fx_ring(p.global_position, b.color(), 34.0, 0.35, 2.0)
	main.tip("tool_write")
	return true


# --- the Designer: Edit -------------------------------------------------------------

## The four ways round (the main one of an aim).
static func dir4(v: Vector2) -> Vector2i:
	if absf(v.x) >= absf(v.y):
		return Vector2i(1 if v.x >= 0.0 else -1, 0)
	return Vector2i(0, 1 if v.y >= 0.0 else -1)


func _tile_center(t: Vector2i) -> Vector2:
	return main.room.position + (Vector2(t) + Vector2(0.5, 0.5)) * C


func _inside(t: Vector2i) -> bool:
	var gs: Vector2i = main.grid_size
	return t.x >= 0 and t.y >= 0 and t.x < gs.x and t.y < gs.y


func _layout_ok() -> bool:
	return main.layout_on and main.astar != null and not main.floor_plan.get("proving", false)


## The traps' view of the floor (walls, chasms, what's kept clear, what each trap reaches).
func _trap_ctx() -> Dictionary:
	var ctx: Dictionary = Traps.context(main.floor_plan, main)
	Traps._rehaz(ctx, main.traps)
	return ctx


## A tile a wall, a gate or a trap could take: open floor (not a chasm), not
## kept clear (start, stair, doors, the puzzle's room...), no door, no body.
func _buildable(t: Vector2i, ctx: Dictionary, trap_ok := false) -> bool:
	if not _inside(t) or main._is_solid_tile(t.x, t.y):
		return false
	var k: int = t.y * main.grid_size.x + t.x
	if ctx["chasm"][k] != 0 or ctx["prot"][k] >= 2:
		return false
	if not trap_ok and ctx["haz"][k] != 0:
		return false
	if main.door_view != null and not main.door_view.door_at(t).is_empty():
		return false
	if walls.any(func(w): return t in w["tiles"]) or gates.any(func(g): return t in g["tiles"]):
		return false
	var r := Rect2(main.room.position + Vector2(t) * C, Vector2(C, C))
	var bodies: Array = [main.player] + main.enemies() + main.allies()
	for b in bodies:
		if r.grow(b.radius + 2.0).has_point(b.global_position):
			return false
	return true


## The tiles across your aim, `ahead` tiles in front of you (the middle first).
func ahead_tiles(ahead: int, length: int) -> Array:
	var pt: Vector2i = main._tile_of(main.player.global_position)
	var d := dir4(main.player.aim)
	var c: Vector2i = pt + d * ahead
	var perp := Vector2i(-d.y, d.x)
	var out: Array = [c]
	for k in range(1, length):
		out.append(c + perp * (((k + 1) / 2) * (1 if k % 2 == 1 else -1)))
	return out


## The open tiles of a stretch across your aim (the middle one must be open).
func _stretch(ahead: int, length: int, ctx: Dictionary) -> Array:
	var list := ahead_tiles(ahead, length)
	if not _buildable(list[0], ctx):
		return []
	return list.filter(func(t): return _buildable(t, ctx))


## The places that must stay sealed: wings (and their vaults), secret rooms, the puzzle's room.
func _sealed_areas() -> Array:
	var out: Array = []
	if main.wings != null:
		for w in main.wings.wings:
			out.append(w["rect"].grow(C))
		for s in main.wings.secrets:
			out.append(s["rect"].grow(C))
	var pz: Dictionary = main.floor_plan.get("puzzle", {})
	if not pz.is_empty() and main.puzzle != null and main.puzzle.active():
		out.append(pz["room"].grow(C))
	return out


## The thin wall the way you aim that could sink: its tiles (empty for none).
func sink_tiles() -> Array:
	if not _layout_ok():
		return []
	var pt: Vector2i = main._tile_of(main.player.global_position)
	var d := dir4(main.player.aim)
	for k in range(1, SB.SINK_REACH + 1):
		var t: Vector2i = pt + d * k
		if not _inside(t):
			return []
		if not main._is_solid_tile(t.x, t.y):
			continue
		return sinkable(t, d)
	return []


## The tiles of a wall at most SINK_THICK thick, starting at `t` and going
## `d` (open floor on both sides), if it may sink; else empty.
func sinkable(t: Vector2i, d: Vector2i) -> Array:
	var gs: Vector2i = main.grid_size
	var a: Vector2i = t - d
	if main._is_solid_tile(a.x, a.y):
		return []
	var run: Array = []
	var u := t
	while _inside(u) and main._is_solid_tile(u.x, u.y):
		run.append(u)
		if run.size() > SB.SINK_THICK:
			return []
		u += d
	if run.is_empty() or not _inside(u):
		return []
	var areas := _sealed_areas()
	for w in run:
		if w.x < 1 or w.y < 1 or w.x > gs.x - 2 or w.y > gs.y - 2:
			return []  # (never the floor's outer wall)
		if main.door_view != null and not main.door_view.door_at(w).is_empty():
			return []
		if walls.any(func(x): return w in x["tiles"]):
			return []
		if areas.any(func(r): return r.has_point(_tile_center(w))):
			return []
	if areas.any(func(r): return r.has_point(_tile_center(u))):
		return []
	return run


func _open_des_edit(target) -> bool:
	if not _layout_ok():
		return _no(SB.TEXT["proving"] if main.floor_plan.get("proving", false) else SB.TEXT["no_edit"])
	var cost: Dictionary = SB.TOOLS["des_edit"]["cost"]
	var col := SB.color("designer")
	var list: Array = []
	var tr = target["trap"] if target is Dictionary and target.has("trap") else null
	if tr != null:
		var room := int(tr.get("room", -1))
		if String(tr.get("trigger", "")) == "timed" and room >= 0 and not retimed.has(room):
			list.append(_paid_card("retime", SB.DES_EDIT["retime"]["name"], SB.DES_EDIT["retime"]["desc"], col, cost))
		if Traps.KINDS[tr["kind"]]["shape"] != "lane":
			list.append(_paid_card("move", SB.DES_EDIT["move"]["name"], SB.DES_EDIT["move"]["desc"] % SB.MOVE_TILES, col, cost))
	var ctx := _trap_ctx()
	if not _stretch(SB.RAISE_AHEAD, SB.RAISE_LEN, ctx).is_empty():
		list.append(_paid_card("raise", SB.DES_EDIT["raise"]["name"], SB.DES_EDIT["raise"]["desc"] % int(SB.WALL_TIME), col, cost))
	if not sink_tiles().is_empty():
		list.append(_paid_card("sink", SB.DES_EDIT["sink"]["name"], SB.DES_EDIT["sink"]["desc"] % int(SB.WALL_TIME), col, cost))
	if list.is_empty():
		return _no(SB.TEXT["no_edit"])
	var name: String = Traps.KINDS[tr["kind"]]["name"] if tr != null else ""
	return _show_cards("des_edit", SB.TEXT["des_edit_title"], [String(name).capitalize()] if name != "" else [], list, {"trap": tr})


func _take_des_edit(c: Dictionary, ctx: Dictionary) -> void:
	var why := ""
	match String(c["id"]):
		"retime":
			why = retime(ctx["trap"])
		"move":
			why = move_trap(ctx["trap"], dir4(main.player.aim))
		"raise":
			why = raise_wall(SB.WALL_TIME, "raise")
		"sink":
			why = sink_wall(sink_tiles())
	if why != "":
		_refund(SB.TOOLS["des_edit"]["cost"])
		tools._refuse(why)


## Gives back what a card took when it couldn't be done after all.
func _refund(_cost: Dictionary) -> void:
	var paid: Dictionary = tools.last_paid
	for k in paid.get("essence", {}):
		main.run_essence[k] = float(main.run_essence.get(k, 0.0)) + float(paid["essence"][k])
	main.run_flow += float(paid.get("flow", 0.0))
	tools.last_paid = {}


## Re-times a trap room: its beat runs RETIME times slower and goes quiet for
## a moment. Undone if it would leave a tile with no safe moment. "" if done.
func retime(tr) -> String:
	if tr == null:
		return SB.TEXT["retime_none"]
	var room := int(tr.get("room", -1))
	var list: Array = main.traps.filter(func(x): return int(x.get("room", -1)) == room and String(x.get("trigger", "")) == "timed" and not x.get("own", false))
	if room < 0 or list.is_empty():
		return SB.TEXT["retime_none"]
	if retimed.has(room):
		return SB.TEXT["retimed_already"]
	var before: int = Traps.hard_tiles(main.traps).size()
	var saved: Array = list.map(func(x): return [x.get("cycle"), x["timer"], x.get("start")])
	for x in list:
		var cyc := Traps.val(x, "cycle")
		x["cycle"] = cyc * SB.RETIME
		x["start"] = float(x.get("start", 1.0)) * SB.RETIME
		if x["state"] == "idle":
			x["timer"] = float(x["timer"]) * SB.RETIME + cyc * SB.RETIME * SB.RETIME_QUIET
	if Traps.hard_tiles(main.traps).size() > before:
		for i in list.size():
			for j in 3:
				var key: String = ["cycle", "timer", "start"][j]
				if saved[i][j] == null:
					list[i].erase(key)
				else:
					list[i][key] = saved[i][j]
		return SB.TEXT["would_block"]
	retimed[room] = true
	main.fx_text(tr["pos"] + Vector2(0, -30), SB.TEXT["retimed"], SB.color("designer"))
	return ""


## Moves a trap (not a lane) up to MOVE_TILES tiles toward `d`, to the
## farthest open floor a trap may take with no wall between. "" if done.
func move_trap(tr, d: Vector2i) -> String:
	if tr == null:
		return SB.TEXT["no_edit"]
	if Traps.KINDS[tr["kind"]]["shape"] == "lane":
		return SB.TEXT["lane"]
	var others: Array = main.traps.filter(func(x): return not is_same(x, tr))
	var ctx: Dictionary = Traps.context(main.floor_plan, main)
	Traps._rehaz(ctx, others)
	var t0 := Traps.tile_of(tr["pos"])
	var from: Vector2 = tr["pos"]
	var before: int = Traps.hard_tiles(main.traps).size()
	var open: Array = []
	for k in range(1, SB.MOVE_TILES + 1):
		var t: Vector2i = t0 + d * k
		if not Traps._open(ctx, t):
			break
		open.append(t)
	for i in range(open.size() - 1, -1, -1):
		var t: Vector2i = open[i]
		if not Traps._free(ctx, t) or (main.door_view != null and not main.door_view.door_at(t).is_empty()):
			continue
		tr["pos"] = Traps.centre(t)
		if Traps.hard_tiles(main.traps).size() > before:
			tr["pos"] = from
			continue
		tr["hit"] = []
		trails.append({"from": from, "to": tr["pos"], "t": 2.5})
		main.trap_view.set("_drawn_n", -1)  # (draw the resting traps again)
		main.fx_text(tr["pos"] + Vector2(0, -30), SB.TEXT["moved"], SB.color("designer"))
		return ""
	return SB.TEXT["no_move"]


func _set_tiles(tiles: Array, closed: bool) -> void:
	var gs: Vector2i = main.grid_size
	for t in tiles:
		main.solid[t.y * gs.x + t.x] = 1 if closed else 0
		main.astar.set_point_solid(t, closed)
	if main.fog != null:
		main.fog.set("last_tile", Vector2i(-999, -999))  # (look again)


func _body(r: Rect2, layer: int) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = r.get_center()
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = r.size
	shape.shape = box
	body.add_child(shape)
	main.add_child(body)
	return body


func _tiles_rect(tiles: Array) -> Rect2:
	var r := Rect2(main.room.position + Vector2(tiles[0]) * C, Vector2(C, C))
	for t in tiles:
		r = r.merge(Rect2(main.room.position + Vector2(t) * C, Vector2(C, C)))
	return r


## The places that must stay reachable from where you stand: the stair, and
## the puzzle's room (each only if it can be reached now).
func _goals() -> Array:
	var out: Array = [main._tile_of(main.stair_pos)]
	var pz: Dictionary = main.floor_plan.get("puzzle", {})
	if not pz.is_empty():
		out.append(main._tile_of(pz["room"].get_center()))
	return out


func _reachable(goals: Array) -> Array:
	var from: Vector2i = main._tile_of(main.player.global_position)
	return goals.map(func(g): return main._is_solid_tile(g.x, g.y) or not main.astar.get_id_path(from, g).is_empty())


## Raises a stretch of wall across your aim: for `seconds` (INF: the floor).
## Refused if it would shut the stair (or the puzzle) away. "" if done.
func raise_wall(seconds: float, kind: String) -> String:
	if not _layout_ok():
		return SB.TEXT["no_room_wall"]
	var tiles := _stretch(SB.RAISE_AHEAD if kind == "raise" else SB.BUILD_AHEAD, SB.RAISE_LEN, _trap_ctx())
	if tiles.is_empty():
		return SB.TEXT["no_room_wall"]
	var goals := _goals()
	var could := _reachable(goals)
	_set_tiles(tiles, true)
	var can := _reachable(goals)
	for i in goals.size():
		if could[i] and not can[i]:
			_set_tiles(tiles, false)
			return SB.TEXT["would_shut"]
	walls.append({"tiles": tiles, "body": _body(_tiles_rect(tiles), 1), "t": seconds, "kind": kind, "runs": []})
	main.fx_text(_tile_center(tiles[0]) + Vector2(0, -30), SB.TEXT["raised"], SB.color("designer"))
	main.shake(3.0)
	main.sfx("slam", 0.8, -8.0, 0.0)
	queue_redraw()
	return ""


## Sinks a thin wall for a while: its tiles open (sight, paths and bodies);
## the wall's own collision (main.gd's runs of wall, one row each) is cut
## around them and joined again when it rises.
func sink_wall(tiles: Array) -> String:
	if tiles.is_empty() or not _layout_ok():
		return SB.TEXT["no_edit"]
	var runs: Array = []  # [the original run's rect, the pieces made from it]
	for b in main.layout_bodies.duplicate():
		if not is_instance_valid(b) or b.get_child_count() == 0:
			continue
		var sh = b.get_child(0).shape
		if not (sh is RectangleShape2D):
			continue
		var r := Rect2(b.position - sh.size * 0.5, sh.size)
		var cut := Rect2()
		for t in tiles:
			var tile_r := Rect2(main.room.position + Vector2(t) * C, Vector2(C, C))
			if r.has_point(tile_r.get_center()):
				cut = tile_r if cut.size == Vector2.ZERO else cut.merge(tile_r)
		if cut.size == Vector2.ZERO:
			continue
		var pieces: Array = []
		if cut.position.x - r.position.x > 1.0:
			pieces.append(_body(Rect2(r.position, Vector2(cut.position.x - r.position.x, r.size.y)), 1))
		if r.end.x - cut.end.x > 1.0:
			pieces.append(_body(Rect2(Vector2(cut.end.x, r.position.y), Vector2(r.end.x - cut.end.x, r.size.y)), 1))
		main.layout_bodies.erase(b)
		b.queue_free()
		main.layout_bodies.append_array(pieces)
		runs.append([r, pieces])
	_set_tiles(tiles, false)
	walls.append({"tiles": tiles.duplicate(), "body": null, "t": SB.WALL_TIME, "kind": "sink", "runs": runs})
	main.fx_text(_tile_center(tiles[0]) + Vector2(0, -30), SB.TEXT["sunk"], SB.color("designer"))
	main.sfx("slam", 0.6, -8.0, 0.0)
	queue_redraw()
	return ""


func _tick_walls(delta: float) -> void:
	var keep: Array = []
	for w in walls:
		w["t"] -= delta
		if w["t"] > 0.0:
			keep.append(w)
			continue
		if w["kind"] == "sink":
			# It rises again once nobody stands in it.
			var r := _tiles_rect(w["tiles"])
			var bodies: Array = [main.player] + main.enemies() + main.allies()
			if bodies.any(func(b): return r.grow(b.radius).has_point(b.global_position)):
				w["t"] = 0.3
				keep.append(w)
				continue
			_set_tiles(w["tiles"], true)
			for run in w["runs"]:
				for piece in run[1]:
					main.layout_bodies.erase(piece)
					if is_instance_valid(piece):
						piece.queue_free()
				main.layout_bodies.append(_body(run[0], 1))
		else:
			_set_tiles(w["tiles"], false)
			if is_instance_valid(w["body"]):
				w["body"].queue_free()
	walls = keep
	queue_redraw()


# --- the Designer: Reroll ---------------------------------------------------------

## Whether the next floor is one a reroll can choose (not the Proving, not the summit).
func next_rerollable() -> bool:
	var tw: Dictionary = main.Towers.TOWERS[main.tower]
	var n1: int = main.floor_num + 1
	if main.first_climb or not tw.get("rooms", true):
		return false
	if main.proving != null and main.proving.due(n1):
		return false
	return n1 < int(tw.get("summit", 99))


func _open_reroll() -> bool:
	if not next_rerollable():
		return _no(SB.TEXT["reroll_not"])
	if main.player.global_position.distance_to(main.stair_pos) > SB.STAIR_NEAR:
		return _no(SB.TEXT["reroll_far"])
	var tid: String = main.tower
	var list: Array = []
	for kind in SB.two_of(Catalog.TYPES.keys()):
		var th: Dictionary = Themes.get_theme(Themes.puzzle_theme(kind))
		list.append({"id": kind, "name": Catalog.display_name(kind, tid), "desc": th.get("sub", ""), "color": SB.color("designer")})
	return _show_cards("reroll1", SB.TEXT["reroll_title"], ["Floor %d" % (main.floor_num + 1)], list)


func _open_reroll2(puzzle: String) -> void:
	var list: Array = []
	for lean in SB.two_of(SB.LEANS.keys()):
		list.append(_paid_card(lean, SB.LEANS[lean]["name"], SB.LEANS[lean]["desc"], SB.color("designer"), SB.TOOLS["des_reroll"]["cost"]))
	_show_cards("des_reroll", SB.TEXT["reroll_title2"], ["Floor %d  ·  %s" % [main.floor_num + 1, Catalog.display_name(puzzle, main.tower)]], list, {"puzzle": puzzle})


func _take_reroll(c: Dictionary, ctx: Dictionary) -> void:
	once["des_reroll"] = true
	reroll_next = {"puzzle": String(ctx["puzzle"]), "lean": String(c["id"]), "from": main.floor_num + 1}
	main.fx_text(main.player.global_position + Vector2(0, -40), SB.TEXT["reroll_done"] % [Catalog.display_name(reroll_next["puzzle"], main.tower), SB.LEANS[reroll_next["lean"]]["name"]], SB.color("designer"))


## Before a floor is planned (main.gd): a new climb forgets the climb's
## tools; a waiting reroll sets the puzzle and the rooms' lean.
func before_build(n: int) -> void:
	if n <= 1:
		reroll_next = {}
		passage_used = false
	if reroll_next.is_empty() or n < int(reroll_next.get("from", 0)):
		return
	_saved_forced = Catalog.forced
	Catalog.forced = String(reroll_next["puzzle"])
	Themes.lean = SB.LEANS.get(String(reroll_next["lean"]), {})
	_lean_on = true


func after_build(plan: Dictionary) -> void:
	if not _lean_on:
		return
	_lean_on = false
	Catalog.forced = _saved_forced
	Themes.lean = {}
	if not plan.get("puzzle", {}).is_empty():  # (only a floor of rooms takes it)
		lean_used = reroll_next.duplicate()
		lean_used["floor"] = main.floor_num
		lean_used["got"] = String(plan["puzzle"].get("type", ""))
		reroll_next = {}


# --- the Designer: Build ------------------------------------------------------------

func _open_build() -> bool:
	if not _layout_ok():
		return _no(SB.TEXT["proving"] if main.floor_plan.get("proving", false) else SB.TEXT["no_portal"])
	var col := SB.color("designer")
	var list: Array = []
	for id in SB.BUILD_ORDER:
		var info: Dictionary = SB.BUILD[id]
		if id == "passage":
			if passage_used:
				continue
		elif builds >= SB.BUILD_MAX:
			continue
		list.append(_paid_card(id, info["name"], info["desc"], col, info["cost"]))
	if list.is_empty():
		return _no(SB.TEXT["build_max"])
	return _show_cards("des_build", SB.TEXT["build_title"], ["%d of %d built this floor" % [builds, SB.BUILD_MAX]], list)


func _take_build(c: Dictionary) -> void:
	var why := build(String(c["id"]))
	if why != "":
		_refund(SB.BUILD[String(c["id"])]["cost"])  # (nothing was built: what was paid comes back)
		tools._refuse(why)


## Builds one of the palette in front of you. "" if done, else why not.
func build(id: String) -> String:
	if not _layout_ok():
		return SB.TEXT["no_portal"]
	if id != "passage" and builds >= SB.BUILD_MAX:
		return SB.TEXT["build_max"]
	var col := SB.color("designer")
	var why := ""
	match id:
		"trap":
			var ctx := _trap_ctx()
			var t: Vector2i = ahead_tiles(SB.BUILD_AHEAD, 1)[0]
			if not _buildable(t, ctx) or not Traps._free(ctx, t):
				return SB.TEXT["build_here"]
			var kinds: Array = Traps.PLATES.get(main.tower, ["spikes"])
			var tr: Dictionary = Traps.make(Traps.centre(t), String(kinds[0]), false, main.floor_num)
			tr["trigger"] = "plate"
			tr["state"] = "idle"
			tr["timer"] = 0.0
			tr["own"] = true
			tr["room"] = -1
			main.traps.append(tr)
		"wall":
			why = raise_wall(INF, "build")
		"gate":
			var tiles := _stretch(SB.BUILD_AHEAD, SB.RAISE_LEN, _trap_ctx())
			if tiles.is_empty():
				return SB.TEXT["build_here"]
			for t in tiles:
				main.astar.set_point_solid(t, true)  # (monsters go around)
			gates.append({"tiles": tiles, "body": _body(_tiles_rect(tiles), 8)})  # (layer 8: monsters only)
		"passage":
			if passage_used:
				return SB.TEXT["once_climb"]
			var a: Vector2 = main.player.global_position
			var b: Vector2 = main.clear_spot(main.stair_pos + Vector2(0, 80), 16.0)
			if main.is_solid(b):
				b = main.clear_spot(main.stair_pos + Vector2(0, 50), 16.0)
			portal = {"a": a, "b": b, "inside": "a"}
			passage_used = true
	if why != "":
		return why
	if id != "passage":
		builds += 1
	main.fx_text(main.player.global_position + Vector2(0, -40), SB.TEXT["built"] % String(SB.BUILD[id]["name"]).to_lower(), col)
	main.fx_ring(main.player.global_position + main.player.aim * C * SB.BUILD_AHEAD, col, 30.0, 0.35, 2.0)
	main.tip("tool_build_designer")
	queue_redraw()
	return ""


## The passage: stepping into one gate brings you out of the other (step out
## of it before it takes you back).
func _tick_portal() -> void:
	var p = main.player
	if p.dead or main.climbing:
		return
	var pp: Vector2 = p.global_position
	var at := ""
	for k in ["a", "b"]:
		if pp.distance_to(portal[k]) < SB.PORTAL_R:
			at = k
	if at == "":
		portal["inside"] = ""
		return
	if portal["inside"] != "":
		return
	var to := "b" if at == "a" else "a"
	p.global_position = portal[to]
	p.reset_physics_interpolation()
	portal["inside"] = to
	main.fx_ring(portal[at], SB.color("designer"), 30.0, 0.35, 2.0)
	main.fx_ring(portal[to], SB.color("designer"), 30.0, 0.35, 2.0)
	main.sfx("glint", 1.3, -6.0, 0.0)
	if main.fog != null:
		main.fog.set("last_tile", Vector2i(-999, -999))


# --- the Manipulator ---------------------------------------------------------------

## Why a monster won't change kind or side ("" if it will): a key carrier, or
## bound to a floor's test (a wing's waves, the puzzle's ambush, the Proving).
func bound(e) -> String:
	if main.floor_plan.get("proving", false):
		return SB.TEXT["proving"]
	if e.has_meta("key"):
		return SB.TEXT["key"]
	if main.wings != null:
		for w in main.wings.wings:
			if e in w.get("mobs", []):
				return SB.TEXT["bound"]
	if main.puzzle != null and "ambushers" in main.puzzle and e in main.puzzle.ambushers:
		return SB.TEXT["bound"]
	return ""


## The kinds of this tower (floors.gd MONSTERS: the common ones and the tower's own mix).
func tower_kinds() -> Array:
	var mix: Dictionary = main.tower_data().get("weights", {})
	return Floors.MONSTERS.keys().filter(func(k): return not Floors.MONSTERS[k].get("only", false) or mix.has(k))


func _cost_of(kind: String) -> float:
	return float(Floors.MONSTERS.get(kind, {}).get("cost", 1.5))


## Weaker kinds a monster could be turned into (at most TURN_CHOICES).
func weaker_kinds(kind: String) -> Array:
	var mine := _cost_of(kind)
	var list: Array = tower_kinds().filter(func(k): return k != kind and _cost_of(k) < mine)
	list.shuffle()
	return list.slice(0, SB.TURN_CHOICES)


func _medits(e) -> Array:
	return e.get_meta("sb_edits", []) if e.has_meta("sb_edits") else []


func _open_medit(e) -> bool:
	if e == null or not is_instance_valid(e):
		return _no(SB.TEXT["no_target"])
	if SB.resists(e):
		return _no(SB.TEXT["resists"])
	var done := _medits(e)
	if done.size() >= SB.MEDIT_MAX or "turned" in done:
		return _no(SB.TEXT["medit_max"])
	var cost: Dictionary = SB.TOOLS["man_edit"]["cost"]
	var col := SB.color("manipulator")
	var list: Array = []
	for id in SB.MEDIT_ORDER:
		if not id in done:
			list.append(_paid_card(id, SB.MEDIT[id]["name"], SB.MEDIT[id]["desc"], col, cost))
	if bound(e) == "" and done.is_empty():
		for k in weaker_kinds(e.kind):
			list.append(_paid_card("turn:" + k, SB.TEXT["turn"] % String(k).capitalize(), SB.TEXT["turn_desc"], col, cost))
	return _show_cards("man_edit", SB.TEXT["medit_title"] % String(e.kind).to_upper(), ["%d of %d changes" % [done.size(), SB.MEDIT_MAX]], list, {"e": e})


func _take_medit(c: Dictionary, ctx: Dictionary) -> void:
	var e = ctx.get("e")
	if e == null or not is_instance_valid(e) or e.dead:
		return
	var id := String(c["id"])
	if id.begins_with("turn:"):
		turn_into(e, id.substr(5))
	else:
		medit(e, id)


## Tunes a monster (one of MEDIT). False if its budget is spent.
func medit(e, id: String) -> bool:
	var done := _medits(e).duplicate()
	if done.size() >= SB.MEDIT_MAX or "turned" in done or id in done or not SB.MEDIT.has(id):
		return false
	var m: Dictionary = SB.MEDIT[id]
	if m.has("speed"):
		e.speed *= float(m["speed"])
	if m.has("dmg"):
		e.dmg *= float(m["dmg"])
	if m.has("reach"):
		e.reach_k = float(m["reach"])
	if m.has("hp"):
		e.max_hp *= float(m["hp"])
		e.hp = minf(e.hp, e.max_hp)
	done.append(id)
	e.set_meta("sb_edits", done)
	edited += 1
	main.fx_text(e.global_position + Vector2(0, -e.radius - 22.0), String(m["tag"]).capitalize(), SB.color("manipulator"))
	main.fx_ring(e.global_position, SB.color("manipulator"), e.radius + 14.0, 0.35, 2.0)
	return true


## Turns a monster into another kind (in its place, as awake or asleep as it was).
func turn_into(e, kind: String):
	var at: Vector2 = e.global_position
	var n = main.spawn_enemy(kind, at)
	n.aware = e.aware
	n.notice_t = e.notice_t
	n.state_t = maxf(e.state_t, 0.6)
	n.set_meta("sb_edits", ["turned"])  # (its budget is spent)
	if e.has_meta("key"):
		n.set_meta("key", e.get_meta("key"))
	if e in tools.inspected:
		tools.inspected.erase(e)
		tools.inspected.append(n)
	_remove(e)
	edited += 1
	main.fx_burst(at, Vector2.UP, SB.color("manipulator"), 12, 140.0)
	main.fx_text(at + Vector2(0, -34), String(kind).capitalize(), SB.color("manipulator"))
	return n


## Takes a monster off the floor without a kill (it was rewritten).
func _remove(e) -> void:
	main.release_attack(e)
	e.dead = true
	e.remove_from_group("enemies")
	e.queue_free()
	main.foes_changed()


## The room a Reroll aims at: one not entered yet, with sleeping monsters in
## it that could change, within reach (the one nearest your aim).
func room_target(reach: float):
	if not main.layout_on:
		return null
	var p = main.player
	var pp: Vector2 = p.global_position
	var best = null
	var best_s := INF
	var near = null
	var near_d := INF
	for i in main.room_info.size():
		if main.room_entered.has(i) or rerolled.has(i) or room_pack(i).is_empty():
			continue
		var r: Rect2 = main.room_info[i]["rect"]
		var edge := Vector2(clampf(pp.x, r.position.x, r.end.x), clampf(pp.y, r.position.y, r.end.y))
		var dist := pp.distance_to(edge)
		if dist > reach:
			continue
		var ang := absf(p.aim.angle_to(r.get_center() - pp))
		if ang < tools.AIM_CONE * 1.5:
			var s := dist * (1.0 + ang * 2.0)
			if s < best_s:
				best_s = s
				best = i
		if dist < near_d:
			near_d = dist
			near = i
	return best if best != null else near


## The monsters a room holds that a Reroll would change: asleep, ordinary, free.
func room_pack(i: int) -> Array:
	var r: Rect2 = main.room_info[i]["rect"]
	return main.enemies().filter(func(e): return not e.aware and r.has_point(e.global_position) and not SB.resists(e) and bound(e) == "" and not e.ally)


## Two packs of this tower's monsters, each about as strong as `old` (kinds,
## sorted): different from each other and from what's there, when they can be.
func packs(old: Array) -> Array:
	var mix: Dictionary = main.tower_data().get("weights", {})
	var budget := 0.0
	for k in old:
		budget += _cost_of(k)
	var was: Array = old.duplicate()
	was.sort()
	var out: Array = []
	for t in SB.PACK_TRIES:
		var kinds: Array = []
		var left := budget * randf_range(0.85, 1.35)  # (about as strong: a little either way)
		var knights := 0
		while left >= 0.8 and kinds.size() < old.size() + 1:
			var k: String = Floors._pick(main.floor_num, left, knights, mix)
			if k == "":
				break
			kinds.append(k)
			left -= _cost_of(k)
			if k == "knight":
				knights += 1
		if kinds.is_empty():
			continue
		kinds.sort()
		if (kinds == was and t < SB.PACK_TRIES - 2) or out.any(func(o): return o == kinds):
			continue
		out.append(kinds)
		if out.size() == 2:
			break
	return out


static func pack_text(kinds: Array) -> String:
	var count := {}
	for k in kinds:
		count[k] = int(count.get(k, 0)) + 1
	var bits: Array = []
	for k in count:
		bits.append("%d %s%s" % [count[k], k, "s" if count[k] > 1 else ""])
	return ", ".join(bits)


func _open_mreroll(i) -> bool:
	if main.floor_plan.get("proving", false):
		return _no(SB.TEXT["proving"])
	if not (i is int) or i < 0 or i >= main.room_info.size() or rerolled.has(i) or main.room_entered.has(i):
		return _no(SB.TEXT["no_room"])
	var old: Array = room_pack(i).map(func(e): return e.kind)
	if old.is_empty():
		return _no(SB.TEXT["no_room"])
	var two := packs(old)
	if two.is_empty():
		return _no(SB.TEXT["no_room"])
	var list: Array = []
	for n in two.size():
		list.append(_paid_card("pack%d" % n, SB.TEXT["pack"] % ["A", "B"][n], pack_text(two[n]), SB.color("manipulator"), SB.TOOLS["man_reroll"]["cost"], {"kinds": two[n]}))
	var name: String = Themes.get_theme(main.room_themes[i])["name"] if i < main.room_themes.size() else "a room"
	return _show_cards("man_reroll", SB.TEXT["reroll_room_title"] % name.to_upper(), ["Now: " + pack_text(old)], list, {"room": i})


func _take_mreroll(c: Dictionary, ctx: Dictionary) -> void:
	reroll_room(int(ctx["room"]), c["kinds"])


## Swaps a room's sleeping pack for `kinds` (at the same spots; a key goes with them).
func reroll_room(i: int, kinds: Array) -> Array:
	var old := room_pack(i)
	var spots: Array = old.map(func(e): return e.global_position)
	var keys: Array = []
	for e in old:
		if e.has_meta("key"):
			keys.append(e.get_meta("key"))
		_remove(e)
	var r: Rect2 = main.room_info[i]["rect"]
	var made: Array = []
	for n in kinds.size():
		var at: Vector2 = spots[n] if n < spots.size() else r.get_center() + Vector2.from_angle(n * 2.1) * 50.0
		var e = main.spawn_enemy(String(kinds[n]), at)
		e.aware = false
		made.append(e)
	for n in keys.size():
		if n < made.size():
			made[n].set_meta("key", keys[n])
	main.floor_total += made.size() - old.size()
	rerolled[i] = true
	main.fx_text(r.get_center() + Vector2(0, -40), SB.TEXT["rerolled"], SB.color("manipulator"))
	return made


## The second attacks a monster could take (other kinds of its tower).
func second_kinds(kind: String) -> Array:
	var list: Array = tower_kinds().filter(func(k): return k != kind and SB.SECOND.has(k))
	list.shuffle()
	return list.slice(0, SB.SECOND_CHOICES)


func _open_mbuild(e) -> bool:
	if built != null and is_instance_valid(built) and not built.dead:
		return _no(SB.TEXT["mbuild_one"])
	if e == null or not is_instance_valid(e):
		return _no(SB.TEXT["no_target"])
	if SB.resists(e):
		return _no(SB.TEXT["resists"])
	if bound(e) != "":
		return _no(bound(e))
	var list: Array = []
	for k in second_kinds(e.kind):
		var sec: Dictionary = SB.SECOND[k]
		list.append(_paid_card(k, "%s (%s)" % [sec["name"], k], SB.TEXT["mbuild_desc"] % SB.SECOND_FX[sec["kind"]]["desc"], SB.color("manipulator"), SB.TOOLS["man_build"]["cost"]))
	if list.is_empty():
		return _no(SB.TEXT["no_target"])
	return _show_cards("man_build", SB.TEXT["mbuild_title"] % String(e.kind).to_upper(), [SB.TOOLS["man_build"]["short"]], list, {"e": e})


func _take_mbuild(c: Dictionary, ctx: Dictionary) -> void:
	var e = ctx.get("e")
	if e != null and is_instance_valid(e) and not e.dead:
		rewrite(e, String(c["id"]))


## Rewrites a monster into the climber's own for the floor (one at a time).
func rewrite(e, second: String) -> void:
	main.release_attack(e)
	e.remove_from_group("enemies")
	e.add_to_group("allies")
	e.ally = true
	e.ally_t = 1e9
	e.ally_life = 1e9
	e.state = "ally"
	e.calm = false
	e.feud = null
	e.aware = true
	e.notice_t = 0.0
	e.lost_t = 0.0
	e.set_meta("sb_built", second)
	main.foes_changed()
	tools.inspected.erase(e)
	built = e
	built_second = second
	_built_t = 1.0
	main.fx_text(e.global_position + Vector2(0, -e.radius - 26.0), SB.TEXT["mbuilt"], SB.color("manipulator"))
	main.fx_ring(e.global_position, SB.color("manipulator"), e.radius + 18.0, 0.5, 3.0)
	main.tip("tool_build_manipulator")


## Its second attack, every few seconds when a foe is in reach.
func _tick_built(delta: float) -> void:
	if not is_instance_valid(built) or built.dead or built.is_queued_for_deletion():
		built = null
		return
	_built_t -= delta
	if _built_t > 0.0:
		return
	var kind := String(SB.SECOND.get(built_second, {}).get("kind", ""))
	var fx: Dictionary = SB.SECOND_FX.get(kind, {})
	if fx.is_empty():
		return
	var at: Vector2 = built.global_position
	var target = null
	var best_d := float(fx["reach"])
	for e in main.targets():
		var d: float = at.distance_to(e.global_position)
		if d < best_d and main.clear_line(at, e.global_position):
			best_d = d
			target = e
	if target == null:
		_built_t = 0.3
		return
	_built_t = float(fx["every"])
	second_attack(target)


## Its second kind's attack on a foe.
func second_attack(target) -> void:
	var kind := String(SB.SECOND.get(built_second, {}).get("kind", ""))
	var fx: Dictionary = SB.SECOND_FX.get(kind, {})
	if fx.is_empty() or built == null:
		return
	var col := SB.color("manipulator")
	var at: Vector2 = built.global_position
	var to: Vector2 = target.global_position
	var dir: Vector2 = (to - at).normalized() if to.distance_to(at) > 1.0 else Vector2.RIGHT
	var dmg: float = built.dmg * float(fx["dmg"])
	match kind:
		"shot":
			main.fx_bolt([at, to], col)
			target.take_hit(dmg, dir, 80.0)
		"ring":
			main.fx_ring(at, col, float(fx["reach"]), 0.3, 3.0)
			for e in main.targets().duplicate():
				if e.global_position.distance_to(at) < float(fx["reach"]) + e.radius:
					e.take_hit(dmg, (e.global_position - at).normalized(), 140.0)
		"blast":
			main.fx_ring(to, col, float(fx["radius"]), 0.3, 3.0)
			for e in main.targets().duplicate():
				if e.global_position.distance_to(to) < float(fx["radius"]) + e.radius:
					e.take_hit(dmg, (e.global_position - to).normalized(), 140.0)
		"dash":
			var land: Vector2 = main.walkable_point(at, to - dir * (built.radius + target.radius + 4.0), 12.0)
			main.fx_burst(at, dir, col, 8, 220.0)
			built.global_position = land
			target.take_hit(dmg, dir, 160.0)
		"venom":
			target.add_venom(int(fx["stacks"]))
			target.take_hit(dmg, dir, 60.0)
	_built_hit = {"from": at, "to": to, "t": 0.5}


# --- drawing ------------------------------------------------------------------------

## On the floor: the Designer's walls (raised stone), sunk walls (open floor),
## gates (bars) and the passage (two shimmering rings).
func _draw() -> void:
	if main == null or not main.layout_on:
		return
	var col := SB.color("designer")
	var b := Draw.Batch.new()
	for w in walls:
		for t in w["tiles"]:
			var r := Rect2(main.room.position + Vector2(t) * C, Vector2(C, C))
			if w["kind"] == "sink":
				b.rect(r, Palette.FLOOR)
				b.rect(r.grow(-4.0), Palette.FLOOR_LIGHT)
				Traps._outline(b, r.grow(-1.0), Color(col, 0.35), 1.0)
			else:
				b.rect(r, Palette.WALL_FACE)
				b.rect(Rect2(r.position, Vector2(C, C * 0.7)), Palette.WALL_EDGE)
				b.rect(Rect2(r.position + Vector2(3, 3), Vector2(C - 6.0, C * 0.7 - 6.0)), Palette.WALL_TOP)
				Traps._outline(b, r, Color(col, 0.45), 1.0)
	for g in gates:
		for t in g["tiles"]:
			var r := Rect2(main.room.position + Vector2(t) * C, Vector2(C, C))
			for i in 4:
				var x := r.position.x + 6.0 + i * (C - 12.0) / 3.0
				b.rect(Rect2(x - 1.5, r.position.y + 4.0, 3.0, C - 8.0), Color(Palette.DOOR_IRON.lightened(0.2), 0.95))
			b.rect(Rect2(r.position + Vector2(2, 6), Vector2(C - 4.0, 3.0)), Color(col, 0.6))
			b.rect(Rect2(r.position + Vector2(2, C - 9.0), Vector2(C - 4.0, 3.0)), Color(col, 0.6))
	for tr in main.traps:
		if tr.get("own", false):
			b.arc(tr["pos"], 15.0, 0.0, TAU, 16, Color(col, 0.55), 1.5)
	if not portal.is_empty():
		for k in ["a", "b"]:
			var c: Vector2 = portal[k]
			for i in 3:
				var ph := fposmod(_anim * 0.8 + i / 3.0, 1.0)
				b.arc(c, SB.PORTAL_R * (0.4 + ph * 0.8), 0.0, TAU, 24, Color(col.lightened(0.3), 0.7 * (1.0 - ph)), 2.0)
			b.arc(c, SB.PORTAL_R, 0.0, TAU, 28, Color(col, 0.85), 2.0)
	b.flush(self)


## Over the darkness (secret_tools.gd's _draw): the wireframes and readouts.
func draw_world(b, labels: Array, col: Color, wire: bool) -> void:
	var p = main.player
	var pp: Vector2 = p.global_position
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)
	# The Developer: a spliced spell, over the climber.
	if not splice.is_empty() and (wire or p.pick_open):
		var sc: Color = splice.get("color", col)
		b.arc(pp, 26.0, 0.0, TAU, 24, Color(sc, 0.45), 1.2)
		b.arc(pp, 30.0, 0.0, TAU, 24, Color(col, 0.35), 1.0)
		labels.append([pp + Vector2(-110, 40), SB.TEXT["splice_line"] % [splice["name"], SB.SPLICE_FX[splice["effect"]]["name"]], Color(sc.lightened(0.3), 0.9), 9])
	# The cards: what the choice would work on.
	if cards_tool in ["des_edit", "des_build"] and main.layout_on:
		for t in ahead_tiles(SB.RAISE_AHEAD if cards_tool == "des_edit" else SB.BUILD_AHEAD, SB.RAISE_LEN):
			Traps._outline(b, Rect2(main.room.position + Vector2(t) * C, Vector2(C, C)).grow(-2.0), Color(col, 0.5 * pulse), 1.5)
		if cards_tool == "des_edit":
			for st in sink_tiles():
				Traps._outline(b, Rect2(main.room.position + Vector2(st) * C, Vector2(C, C)), Color(col, 0.8 * pulse), 2.0)
	if cards_tool == "man_reroll" and cards_ctx.has("room"):
		Traps._outline(b, main.room_info[int(cards_ctx["room"])]["rect"].grow(-4.0), Color(col, 0.7 * pulse), 2.0)
	if cards_tool in ["man_edit", "man_build"] and cards_ctx.get("e") != null and is_instance_valid(cards_ctx["e"]):
		var e0 = cards_ctx["e"]
		b.arc(e0.global_position, e0.radius + 9.0, 0.0, TAU, 28, Color(col, 0.9 * pulse), 2.0)
	# The Designer: walls with the seconds they have left, gates, the passage, moved traps.
	for w in walls:
		var r := _tiles_rect(w["tiles"])
		Traps._outline(b, r.grow(1.0), Color(col, 0.55 if wire else 0.3), 1.2)
		if w["t"] < 1e8 and r.get_center().distance_to(pp) < 420.0:
			labels.append([r.get_center() + Vector2(-110, -C * 0.5 - 4.0), "%ds" % int(ceil(w["t"])), Color(col.lightened(0.3), 0.85), 9])
		if wire and w["kind"] != "sink":
			for t in w["tiles"]:
				var tr0 := Rect2(main.room.position + Vector2(t) * C, Vector2(C, C))
				b.line(tr0.position, tr0.end, Color(col, 0.3), 1.0)
				b.line(Vector2(tr0.end.x, tr0.position.y), Vector2(tr0.position.x, tr0.end.y), Color(col, 0.3), 1.0)
	for g in gates:
		Traps._outline(b, _tiles_rect(g["tiles"]).grow(1.0), Color(col, 0.5 if wire else 0.28), 1.2)
	if not portal.is_empty():
		b.line(portal["a"], portal["b"], Color(col, 0.18 if not wire else 0.35), 1.0)
		for k in ["a", "b"]:
			if portal[k].distance_to(pp) < 360.0:
				labels.append([portal[k] + Vector2(-110, -SB.PORTAL_R - 6.0), SB.TEXT["portal_tag"], Color(col.lightened(0.3), 0.85), 9])
	for tr in trails:
		var a := clampf(tr["t"] / 2.5, 0.0, 1.0)
		var n := 8
		for i in n:
			if i % 2 == 0:
				b.line(tr["from"].lerp(tr["to"], float(i) / n), tr["from"].lerp(tr["to"], float(i + 1) / n), Color(col, 0.8 * a), 2.0)
		b.arc(tr["from"], 8.0, 0.0, TAU, 12, Color(col, 0.5 * a), 1.0)
	if wire and not retimed.is_empty():
		for tr in main.traps:
			if retimed.has(int(tr.get("room", -1))) and tr["pos"].distance_to(pp) < 420.0:
				b.arc(tr["pos"], 11.0, 0.0, TAU, 14, Color(col, 0.5), 1.0)
	# The Manipulator: tags on edited monsters, its own monster, rerolled rooms.
	if edited > 0:
		for e in main.enemies():
			if not e.visible or not e.has_meta("sb_edits"):
				continue
			var tags: Array = []
			for id in e.get_meta("sb_edits"):
				if SB.MEDIT.has(id):
					tags.append(SB.MEDIT[id]["tag"])
				elif id == "turned":
					tags.append("rewritten")
			if not tags.is_empty():
				labels.append([e.global_position + Vector2(-110, e.radius + 28.0), ", ".join(tags), Color(col.lightened(0.3), 0.8), 8])
			if wire:
				b.arc(e.global_position, e.radius + 5.0, 0.0, TAU, 20, Color(col, 0.35), 1.0)
	if built != null and is_instance_valid(built) and built.visible:
		var bc: Vector2 = built.global_position
		b.arc(bc, built.radius + 7.0, 0.0, TAU, 24, Color(col, 0.75), 1.6)
		for i in 4:
			var d := Vector2.from_angle(TAU * i / 4.0 + _anim)
			b.line(bc + d * (built.radius + 9.0), bc + d * (built.radius + 14.0), Color(col, 0.7), 1.2)
		var sec: Dictionary = SB.SECOND.get(built_second, {})
		labels.append([bc + Vector2(-110, -built.radius - 20.0), "%s  ·  %s" % [SB.TEXT["yours"], String(sec.get("name", "")).to_lower()], Color(col.lightened(0.35), 0.9), 9])
	if not _built_hit.is_empty():
		b.line(_built_hit["from"], _built_hit["to"], Color(col, 0.6 * clampf(_built_hit["t"] / 0.5, 0.0, 1.0)), 1.5)
	if wire:
		for i in rerolled:
			Traps._outline(b, main.room_info[i]["rect"].grow(-4.0), Color(col, 0.35), 1.2)
