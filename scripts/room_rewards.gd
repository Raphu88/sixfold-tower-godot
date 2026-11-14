extends Node2D
## What rooms give, so no room is a pointless dead end (floors.gd plans
## them, main.gd sets them up each floor):
##   chests      a danger room's spoils (a guard post's strongbox, a den's
##               hoard): shut while the monsters that wait in the room still
##               stand, then open to walk up to (essence, sometimes an item
##               or gear; richer in a dead end)
##   vaults      a strongroom behind a lock: a pedestal with a vault's cards
##   rests       a calm rest room: stand in it and your wounds slowly close
##   traders     a wandering trader: three things for unbanked essence
## Words and numbers are in TEXT and RULES (the Data editor).

const Essence := preload("res://scripts/essence.gd")
const Items := preload("res://scripts/items.gd")
const Gear := preload("res://scripts/gear.gd")
const Palette := preload("res://scripts/palette.gd")

static var TEXT := {
	"chest": "Spoils: +%d essence",
	"chest_shut": "Shut fast while its guards stand",
	"vault_title": "STRONGROOM",
	"vault_sub": "Locked away, and worth the trouble.",
	"trader_title": "WANDERING TRADER",
	"trader_sub": "Unbanked essence for what's in the pack. You hold %d.",
	"trade_name": "%s",
	"trade_desc": "%s  ·  costs %d unbanked essence",
	"trade_short": "You can't pay %d",
	"leave_name": "Walk on",
	"leave_desc": "Keep your essence.",
	"bought": "Bought: %s",
	"rested": "Rested",
}
## chest: essence (base, per floor, a dead end's times); item / gear chance;
## rest: health a second; trader: what an item costs (base, per floor).
static var RULES := {"chest_base": 4.0, "chest_per_floor": 1.5, "chest_rich": 1.6, "item_chance": 0.35, "gear_chance": 0.12, "gear_rich": 0.25,
	"rest_heal": 3.0, "trade_base": 10.0, "trade_per_floor": 2.0, "reach": 28.0, "check": 0.3}

var main
var chests: Array = []  # {pos, room, rich, open, taken}
var vaults: Array = []  # {pos, room, taken}
var rests: Array = []  # {pos, room, rect}
var traders: Array = []  # {pos, room, used}
var bridges: Array = []  # {rect, vertical}: planks across a chasm (floors.gd)
var check_t := 0.0
var redraw_t := 0.0


func _ready() -> void:
	z_index = -2


func setup(plan: Dictionary) -> void:
	clear()
	for c in plan.get("chests", []):
		chests.append({"pos": c["pos"], "room": c["room"], "rich": c.get("rich", false), "open": false, "taken": false})
	for v in plan.get("vaults", []):
		vaults.append({"pos": v["pos"], "room": v["room"], "taken": false})
	for r in plan.get("rests", []):
		rests.append(r.duplicate())
	for t in plan.get("traders", []):
		traders.append({"pos": t["pos"], "room": t["room"], "used": false})
	bridges = plan.get("bridges", []).duplicate()
	check_t = 0.0
	queue_redraw()


func clear() -> void:
	chests.clear()
	vaults.clear()
	rests.clear()
	traders.clear()
	bridges.clear()
	queue_redraw()


func _process(delta: float) -> void:
	if main == null or main.player == null or not main.layout_on:
		return
	var p = main.player
	var pos: Vector2 = p.global_position
	check_t -= delta
	if check_t <= 0.0:
		check_t = float(RULES["check"])
		for c in chests:
			if not c["open"]:
				var r: Rect2 = main.room_info[c["room"]]["rect"] if c["room"] < main.room_info.size() else Rect2()
				var guarded := false
				for e in main.enemies():
					if r.grow(-4.0).has_point(e.global_position):
						guarded = true
						break
				if not guarded:
					c["open"] = true
	if p.dead or main.climbing or main.camp_choosing:
		return
	var reach: float = float(RULES["reach"]) + p.radius
	for c in chests:
		if c["open"] and not c["taken"] and pos.distance_to(c["pos"]) < reach:
			_take_chest(c)
	for v in vaults:
		if not v["taken"] and pos.distance_to(v["pos"]) < reach:
			v["taken"] = true
			main.offer_vault(main.wings.vault_choices(false), TEXT["vault_title"], [TEXT["vault_sub"]])
			main.MakersScript.feed(main, "vault")
	for r in rests:
		if r["rect"].has_point(pos) and p.hp < p.max_health():
			p.hp = minf(p.max_health(), p.hp + float(RULES["rest_heal"]) * delta * p.heal_mult())
	for t in traders:
		if t.get("rearm", false) and pos.distance_to(t["pos"]) > reach + 50.0:
			t["rearm"] = false
			t["used"] = false
		if not t["used"] and not t.get("rearm", false) and pos.distance_to(t["pos"]) < reach + 8.0:
			t["used"] = true
			_offer_trade(t)
	redraw_t -= delta
	if redraw_t <= 0.0:
		redraw_t = 1.0 / 15.0
		queue_redraw()


func _take_chest(c: Dictionary) -> void:
	c["taken"] = true
	var kind: String = main.tower_data().get("essence", "air")
	var amount: float = (float(RULES["chest_base"]) + float(RULES["chest_per_floor"]) * main.floor_num) * (float(RULES["chest_rich"]) if c["rich"] else 1.0)
	main.gather_essence(kind, amount, c["pos"])
	main.notices.feed(TEXT["chest"] % int(amount), Essence.color(kind), "essence")  # (the log has it with the essence)
	if randf() < float(RULES["item_chance"]):
		main.item_drops.append({"pos": c["pos"] + Vector2(18, 10), "id": Items.random_item(not main.player.bonds.is_empty()), "t": 1e9})
	if randf() < float(RULES["gear_rich"] if c["rich"] else RULES["gear_chance"]):
		var g = main.find_gear("", 0)
		if not g.is_empty():
			main.drop_gear(c["pos"] + Vector2(-18, 10), g, true)
	main.fx_ring(c["pos"], Color(1.0, 0.85, 0.5), 50.0, 0.4, 3.0)
	main.sfx("glint", 1.25, -3.0)


## Unbanked essence the climber holds.
func purse() -> float:
	var held := 0.0
	for k in main.run_essence:
		held += float(main.run_essence[k])
	return held


func price() -> int:
	return int(float(RULES["trade_base"]) + float(RULES["trade_per_floor"]) * main.floor_num)


func _offer_trade(_t: Dictionary) -> void:
	var marked: bool = not main.player.bonds.is_empty()
	var choices: Array = []
	var seen: Array = []
	for k in 3:
		var id := Items.random_item(marked, seen)
		seen.append(id)
		choices.append("trade:%s:%d" % [id, price() + k * 2])
	choices.append("trade:leave")
	main.offer_vault(choices, TEXT["trader_title"], [TEXT["trader_sub"] % int(purse())])


## A trader's card (main.gd camp_card).
func card(pick: String) -> Dictionary:
	if pick == "trade:leave":
		return {"name": TEXT["leave_name"], "desc": TEXT["leave_desc"], "color": Color(0.6, 0.58, 0.66), "item": ""}
	var id := pick.get_slice(":", 1)
	var cost := int(pick.get_slice(":", 2))
	var d := Items.info(id)
	var note: String = "" if purse() + 0.001 >= cost else TEXT["trade_short"] % cost
	return {"name": TEXT["trade_name"] % d["name"], "desc": TEXT["trade_desc"] % [d["desc"], cost], "color": d["color"], "item": id, "note": note}


## A trader's card taken (main.gd _take_vault_pick): pay and take it, or walk on.
## Returns what to say.
func take(pick: String) -> String:
	if pick == "trade:leave":
		for t in traders:
			t["rearm"] = true  # (step away and come back to trade again)
		return ""
	var id := pick.get_slice(":", 1)
	var cost := float(pick.get_slice(":", 2))
	var held := purse()
	if held + 0.001 < cost:
		for t in traders:
			t["rearm"] = true  # (come back when you can pay: once you've stepped away)
		return TEXT["trade_short"] % int(cost)
	for k in main.run_essence.keys():
		main.run_essence[k] = maxf(0.0, float(main.run_essence[k]) - cost * float(main.run_essence[k]) / held)
	return main._take_item(id, "Bought")


func _draw() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var pulse := 0.5 + 0.5 * sin(t * 3.0)
	for br in bridges:
		_draw_bridge(br["rect"], br["vertical"])
	for c in chests:
		_draw_chest(c, pulse)
	for v in vaults:
		var at: Vector2 = v["pos"]
		draw_rect(Rect2(at + Vector2(-12, -6), Vector2(24, 18)), Palette.OUTLINE)
		draw_rect(Rect2(at + Vector2(-10, -4), Vector2(20, 14)), Color(0.48, 0.44, 0.4))
		draw_rect(Rect2(at + Vector2(-14, -9), Vector2(28, 5)), Color(0.75, 0.62, 0.38))
		if not v["taken"]:
			draw_circle(at + Vector2(0, -16), 5.0 + pulse * 1.5, Color(1.0, 0.84, 0.45, 0.9))
	for r in rests:
		var at: Vector2 = r["pos"]
		# A bedroll and a low lamp.
		draw_rect(Rect2(at + Vector2(-22, -8), Vector2(44, 16)), Color(0.35, 0.42, 0.55))
		draw_rect(Rect2(at + Vector2(-22, -8), Vector2(12, 16)), Color(0.55, 0.6, 0.7))
		draw_circle(at + Vector2(28, 0), 5.0, Color(0.7, 0.85, 1.0, 0.6 + 0.3 * pulse))
	for tr in traders:
		var at: Vector2 = tr["pos"]
		# A cloaked figure beside a laden pack.
		draw_circle(at + Vector2(0, 12), 13.0, Color(0, 0, 0, 0.3))
		draw_colored_polygon(PackedVector2Array([at + Vector2(-11, 12), at + Vector2(0, -14), at + Vector2(11, 12)]), Color(0.36, 0.3, 0.42))
		draw_circle(at + Vector2(0, -12), 6.0, Color(0.26, 0.22, 0.3))
		draw_circle(at + Vector2(-2, -12), 1.2, Color(1.0, 0.85, 0.5))
		draw_circle(at + Vector2(2, -12), 1.2, Color(1.0, 0.85, 0.5))
		draw_rect(Rect2(at + Vector2(14, -2), Vector2(14, 14)), Color(0.5, 0.38, 0.24))
		draw_rect(Rect2(at + Vector2(14, -2), Vector2(14, 14)), Palette.OUTLINE, false, 1.5)
		if not tr["used"]:
			draw_arc(at, 24.0, 0.0, TAU, 24, Color(1.0, 0.84, 0.45, 0.3 + 0.3 * pulse), 2.0)


## Planks across the chasm, rope along both sides (the band runs north-south
## when `vertical`, so you cross it east-west).
func _draw_bridge(r: Rect2, vertical: bool) -> void:
	draw_rect(r.grow(1.0), Color(0.08, 0.06, 0.05))
	var wood := Color(0.46, 0.33, 0.2)
	var n := 6
	for k in n:
		var f := float(k) / n
		var plank: Rect2
		if vertical:
			plank = Rect2(r.position.x + f * r.size.x + 1.0, r.position.y + 2.0, r.size.x / n - 2.0, r.size.y - 4.0)
		else:
			plank = Rect2(r.position.x + 2.0, r.position.y + f * r.size.y + 1.0, r.size.x - 4.0, r.size.y / n - 2.0)
		draw_rect(plank, wood.lightened(0.06 * (k % 2)))
	var rope := Color(0.7, 0.6, 0.42)
	if vertical:
		draw_line(r.position + Vector2(-4, 3), Vector2(r.end.x + 4, r.position.y + 3), rope, 2.0)
		draw_line(Vector2(r.position.x - 4, r.end.y - 3), r.end + Vector2(4, -3), rope, 2.0)
	else:
		draw_line(r.position + Vector2(3, -4), Vector2(r.position.x + 3, r.end.y + 4), rope, 2.0)
		draw_line(Vector2(r.end.x - 3, r.position.y - 4), r.end + Vector2(-3, 4), rope, 2.0)


func _draw_chest(c: Dictionary, pulse: float) -> void:
	var at: Vector2 = c["pos"]
	draw_rect(Rect2(at + Vector2(-13, -2), Vector2(26, 16)), Palette.OUTLINE)
	var wood := Color(0.45, 0.3, 0.18) if not c["rich"] else Color(0.5, 0.36, 0.2)
	draw_rect(Rect2(at + Vector2(-11, 0), Vector2(22, 12)), wood)
	if c["taken"]:
		draw_rect(Rect2(at + Vector2(-11, -12), Vector2(22, 6)), wood.darkened(0.25))
		return
	draw_rect(Rect2(at + Vector2(-12, -8), Vector2(24, 9)), wood.lightened(0.1))
	draw_line(at + Vector2(-12, 0), at + Vector2(12, 0), Color(0.62, 0.58, 0.52), 2.0)
	var lock_col := Color(1.0, 0.84, 0.45, 0.6 + 0.4 * pulse) if c["open"] else Color(0.75, 0.25, 0.2)
	draw_rect(Rect2(at + Vector2(-2.5, -2), Vector2(5, 6)), lock_col)
	if c["open"]:
		draw_arc(at + Vector2(0, 4), 20.0, 0.0, TAU, 24, Color(1.0, 0.84, 0.45, 0.2 + 0.25 * pulse), 2.0)
