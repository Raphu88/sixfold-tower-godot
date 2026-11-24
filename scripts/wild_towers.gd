extends Node2D
## WILD TOWERS. When a tower's guardian is beaten (its beast at the summit,
## floor 12), the tower's well runs wild. The tower stays open, but it is a
## WILD TOWER from the next climb on, for good:
##   STORMS     on its floors of rooms (STORM "from" up to the floor under
##              the summit; never the Proving, a camp, the first climb, the
##              arena or the practice room) wild essence gathers into storms:
##              every "gap" seconds (a little sooner for each other wild
##              well, never under "gap_min") "cells" rings light up on the
##              floor, one under the climber, for "warn" seconds (a flat
##              warning, filling as it counts down, and a word over the
##              climber), then strike. A roll's iframes or stepping out of
##              the ring dodges it. A strike hurts the climber ("dmg" plus
##              "per_floor" a floor) and every monster in a ring ("foe_dmg"
##              plus "foe_per_floor"): lure them in.
##   WILD ESSENCE  a strike that catches a MARKED climber burns one of their
##              lit marks a rung on the marks' own ladder (mark_use.gd and
##              bond.gd: not burned -> burned -> paralyzed; the stair heals a
##              rung as ever). It never burns a mark out by itself: only a
##              forced cast does that. An UNBOUND climber is fed instead: the
##              strike hurts "unbound_dmg" as much and leaves FEED "amount"
##              of the tower's essence in what they carry, at most
##              "per_floor" a floor; banked at the stair it flows into their
##              Nodes as any essence does (unbound.gd). A climber with
##              neither (the bondless first climb) is only hurt.
##   EMPOWERED MONSTERS  every monster (the guardian too) has POWER "health"
##              times its health and "damage" times its damage, never more
##              than "cap" (floors.gd toughness, through Floors.wild_tough).
##   RICHER FINDS  modest, capped bumps (REWARD, never past "cap"): a kill's
##              essence, a good room's cache, gear and item drops.
##   STRANGER FLOORS  the stone takes a wild tint (palette.gd WILD_TINT),
##              motes of wild essence drift in the air, and each strike
##              leaves a scar on the floor.
## THE WORLD. Each wild well pushes the world nearer its unmaking: when the
## third runs wild (MAKERS_AT) the summit's lines say the Makers stir (there
## is no meeting of the Makers yet to hang it on: makers.gd). The cities
## talk (RUMOURS): the Noble of a city by a wild tower, the Dining car's
## climbers (dining.gd RUMORS "wild"), climbers met in a wild tower
## (rivals.gd), and the station's crest. After the ending every tower stays
## open, wild ones too.
## TELLING: a sign on the engine's tower map (engine_page.gd, the Entity's
## hover help: entity_help.gd "tower" {wild_line}), the Entity's first-time
## moment on entering one ("wild_tower", or "wild_tower_unbound"), and its
## "Wild towers?" topic (entity_talk.gd how_wild).
## OLD SAVES: a tower is wild when the record says its beast has fallen
## (profile.record "beasts_by"), so an old save's beaten towers are wild.
##
## Every word and number is here (and in the Data editor).

const Towers := preload("res://scripts/towers.gd")
const Floors := preload("res://scripts/floors.gd")
const MarkUse := preload("res://scripts/mark_use.gd")
const Unbound := preload("res://scripts/unbound.gd")
const Bonds := preload("res://scripts/bonds.gd")
const Essence := preload("res://scripts/essence.gd")
const Palette := preload("res://scripts/palette.gd")
const Draw := preload("res://scripts/draw_util.gd")

## Empowered monsters: times their health and damage, never past "cap".
static var POWER := {"health": 1.2, "damage": 1.1, "cap": 1.25}
## Richer finds (times, never past "cap"): a kill's essence, a good room's
## cache, the chance of gear and of an item from a kill.
static var REWARD := {"essence": 1.1, "cache": 1.2, "gear": 1.5, "items": 1.25, "cap": 1.5}
## Storms (seconds and px): "from" the first floor with storms; "first"
## seconds after arriving, then every "gap" (a random time between the
## two), "per_well" sooner for each other wild well, never under
## "gap_min"; "warn" seconds of warning; "cells" rings (one under the
## climber, the others "spread" px away); "radius" each; "dmg" +
## "per_floor" to the climber ("unbound_dmg" times that for the Unbound),
## "foe_dmg" + "foe_per_floor" to a monster; "strike" how long a strike
## shows; "scars" how many scars a floor keeps.
static var STORM := {"from": 2, "first": 12.0, "gap": [30.0, 42.0], "per_well": 2.0, "gap_min": 24.0, "warn": 2.0,
	"cells": 3, "spread": [130.0, 250.0], "radius": 56.0, "dmg": 6.0, "per_floor": 0.75, "unbound_dmg": 0.5,
	"foe_dmg": 12.0, "foe_per_floor": 1.0, "strike": 0.45, "scars": 18}
## Wild essence for the Unbound: what a strike that catches them leaves
## (the tower's essence, in what they carry), at most "per_floor" a floor.
static var FEED := {"amount": 3.0, "per_floor": 6.0}
## The third wild well: the Makers stir.
const MAKERS_AT := 3

static var TEXT := {
	"storm": "Wild storm! Leave the rings",
	"burned": "Wild essence burns your %s mark",
	"paralyzed": "Wild essence seizes your %s mark",
	"fed": "Wild essence feeds you",
	"fed_full": "Your Nodes can drink no more here",
	"well_wild": "%s's well runs wild. The tower stays open, wilder.",
	"makers_stir": "Three wells run wild. Far outside the towers, the Makers stir.",
	"more_wells": "%d wells run wild now.",
	"crest": "its well runs wild",
	"map_sign": "Wild",
	"help_line": "Its well runs wild: storms, tougher monsters, richer finds.",
	"placard": "Its well runs wild: storms gather on its floors, its monsters are tougher, its finds richer.",
	"placard_marked": "Wild essence burns marks.",
	"placard_unbound": "Wild essence feeds the Unbound.",
	"none": "No well runs wild yet.",
	"wells_one": "One well runs wild: %s.",
	"wells_many": "%d wells run wild: %s.",
	"you_marked": "Wild essence burns marks: each strike that catches you burns one of them a rung, burned, then paralyzed. The stair heals a rung, as ever; only forcing a paralyzed mark burns it out.",
	"you_unbound": "Wild essence feeds you: a strike that catches you hurts half as much and leaves {feed} of the tower's essence in what you carry, {feed_cap} at most a floor. The stair banks it into your Nodes.",
	"you_none": "With no mark and no Nodes, a strike only hurts.",
}

## What people say about wild towers. {tower} the tower ("the Gryphon's
## Tower"), {Tower} at the start of a line, {beast} its guardian, {city}
## the city by it.
static var RUMOURS := {
	"dining": [
		"\"Have you seen {tower} since {beast} fell? Its well runs wild. Storms in every hall, and the creatures hit harder.\"",
		"\"The Unbound go up {tower} to drink the storms. The marked come back down with their marks burned.\"",
		"\"There's more to find in {tower} now, they say. More to lose, too.\"",
		"\"{city} hasn't slept well since its well ran wild. You can see the storms from the platform.\"",
	],
	"noble_home": [
		"\"Since {beast} fell, {city} sleeps badly. Storms light the windows of {tower} all night.\"",
		"\"My people won't go near {tower} now. Its well runs wild, and what comes down from it is worse.\"",
	],
	"noble_away": [
		"\"Word from {city}: {tower} runs wild. Storms, and worse things in the halls.\"",
	],
	"rival": [
		"\"Watch the floor. When the rings light up, move.\"",
		"\"This place was quieter before {beast} fell.\"",
		"\"Wild essence everywhere. The Unbound love it. Marks don't.\"",
	],
}

## Tests turn wild towers on for themselves (they're off in tests, like the
## stair's barriers, so other tests' slain beasts change nothing).
static var test_on := false

var main
var on := false  # storms on this floor
var here := false  # this floor is in a wild tower (monsters, finds, the look)
var next_t := 0.0  # seconds until the next storm gathers
var cells: Array = []  # the gathering storm's rings: {pos, r, warn}
var strikes: Array = []  # strikes showing: {pos, r, t}
var scars: Array = []  # where strikes fell this floor: {pos, r, a}
var fed := 0.0  # wild essence fed to an Unbound this floor
var hits := 0  # strikes that caught the climber this floor
var storms := 0  # storms gathered this floor
var news: Array = []  # lines for the summit's victory (a well gone wild)
var over: Node2D  # warnings and strikes, drawn over the darkness
var redraw_t := 0.0


# --- what's wild ---------------------------------------------------------------------------

static func enabled() -> bool:
	return test_on or not Engine.has_meta("sixfold_test")


## True when a tower's guardian has fallen for this climber (its well runs wild).
static func is_wild(prof, tower: String) -> bool:
	if prof == null or not enabled():
		return false
	var by = prof.record.get("beasts_by", {})
	return by is Dictionary and int(by.get(tower, 0)) > 0


## The wild towers, in tower order.
static func wild_list(prof) -> Array:
	return Towers.ORDER.filter(func(tw): return is_wild(prof, String(tw)))


static func wells(prof) -> int:
	return wild_list(prof).size()


## True when the floor the climber is on is in a wild tower (not a camp, the
## arena, the practice room, a painter's try or the bondless first climb).
static func floor_wild(m) -> bool:
	if m == null or m.profile == null or not enabled():
		return false
	if bool(m.get("on_train")) or bool(m.get("in_camp")) or bool(m.get("first_climb")):
		return false
	if m.get("arena") != null and m.arena.on:
		return false
	if m.get("practice") != null and m.practice.on:
		return false
	if m.has_method("trying_room") and m.trying_room():
		return false
	return is_wild(m.profile, String(m.tower))


## Monsters' toughness on this floor (health, damage), within POWER "cap".
static func tough(m) -> Vector2:
	if not floor_wild(m):
		return Vector2.ONE
	var cap := float(POWER["cap"])
	return Vector2(clampf(float(POWER["health"]), 1.0, cap), clampf(float(POWER["damage"]), 1.0, cap))


## A find's bump on this floor ("essence", "cache", "gear", "items"), within REWARD "cap".
static func reward(m, kind: String) -> float:
	if not floor_wild(m):
		return 1.0
	return clampf(float(REWARD.get(kind, 1.0)), 1.0, float(REWARD["cap"]))


# --- the floor -----------------------------------------------------------------------------

func _ready() -> void:
	z_index = -2  # (the scars and motes: on the floor, under everyone)
	over = Node2D.new()
	over.z_as_relative = false
	over.z_index = 44  # (over the darkness, as the Firebird's storms are)
	over.draw.connect(_draw_over)
	add_child(over)


## A new floor (main.gd _start_floor, after the plan is laid): storms on a
## wild tower's floors of rooms.
func setup_floor(plan: Dictionary) -> void:
	cells.clear()
	strikes.clear()
	scars.clear()
	fed = 0.0
	hits = 0
	storms = 0
	here = floor_wild(main)
	var summit := int(main.tower_data().get("summit", Towers.SUMMIT)) if main != null else Towers.SUMMIT
	var n := int(main.floor_num) if main != null else 0
	if n <= 1:
		news.clear()  # (a new climb: last climb's word is old)
	on = here and n >= int(STORM["from"]) and n < summit and not bool(plan.get("proving", false))
	next_t = float(STORM["first"])
	if here and main != null:
		main.tip("wild_tower_unbound" if Unbound.is_on(main.profile) else "wild_tower")
	queue_redraw()
	if over != null:
		over.queue_redraw()


## Seconds until the next storm: a random gap, sooner for each other wild well.
func gap() -> float:
	var g: Array = STORM["gap"]
	var w := wells(main.profile) if main != null else 1
	return maxf(float(STORM["gap_min"]), randf_range(float(g[0]), float(g[1])) - float(STORM["per_well"]) * maxi(w - 1, 0))


func _physics_process(delta: float) -> void:
	if strikes.size() > 0:
		for s in strikes:
			s["t"] = float(s["t"]) + delta
		strikes = strikes.filter(func(s): return float(s["t"]) < float(STORM["strike"]))
	if not on or main == null or main.player == null or not is_instance_valid(main.player):
		return
	var p = main.player
	if not p.dead and not main.climbing:
		if cells.is_empty():
			next_t -= delta
			if next_t <= 0.0:
				gather()
		else:
			for c in cells:
				c["warn"] = float(c["warn"]) - delta
			if float(cells[0]["warn"]) <= 0.0:
				strike_all()
	redraw_t -= delta
	if redraw_t <= 0.0:
		redraw_t = 1.0 / 30.0
		queue_redraw()
		over.queue_redraw()


## A storm gathers: its rings light up, one under the climber, and the warning shows.
func gather() -> void:
	var p = main.player
	cells.clear()
	var r := float(STORM["radius"])
	var at: Vector2 = p.global_position
	cells.append({"pos": at, "r": r, "warn": float(STORM["warn"])})
	var sp: Array = STORM["spread"]
	var turn := randf() * TAU
	var others := maxi(int(STORM["cells"]) - 1, 0)
	for i in others:
		var dir := Vector2.from_angle(turn + TAU * float(i) / maxf(float(others), 1.0))
		var want: Vector2 = at + dir * randf_range(float(sp[0]), float(sp[1]))
		var pos: Vector2 = main.walkable_point(at, want, 16.0) if main.has_method("walkable_point") else want
		cells.append({"pos": pos, "r": r, "warn": float(STORM["warn"])})
	storms += 1
	main.fx_text(at + Vector2(0, -50), String(TEXT["storm"]), Palette.WILD)
	main.sfx("gust", 0.6, -2.0)


## The storm strikes every ring: the climber and the monsters in them.
func strike_all() -> void:
	var list := cells.duplicate()
	cells.clear()
	next_t = gap()
	var first := true
	for c in list:
		_strike(c, first)
		first = false


func _strike(c: Dictionary, sound: bool) -> void:
	var pos: Vector2 = c["pos"]
	var r := float(c["r"])
	strikes.append({"pos": pos, "r": r, "t": 0.0})
	scars.append({"pos": pos, "r": r * randf_range(0.7, 0.95), "a": randf() * TAU})
	if scars.size() > int(STORM["scars"]):
		scars.pop_front()
	main.fx_bolt([pos + Vector2(randf_range(-30.0, 30.0), -240.0), pos + Vector2(randf_range(-8.0, 8.0), -90.0), pos], Palette.WILD_HOT)
	main.fx_burst(pos, Vector2.UP, Palette.WILD, 10, 200.0)
	main.light_flash(pos, Palette.WILD, 1.4, 1.8, 0.3)
	if sound:
		main.sfx("thunder", 1.1, -6.0)
		main.shake(3.0)
	var p = main.player
	if p != null and is_instance_valid(p) and not p.dead and p.global_position.distance_to(pos) <= r + float(p.radius) * 0.5:
		catch(c)
	var foe := float(STORM["foe_dmg"]) + float(STORM["foe_per_floor"]) * int(main.floor_num)
	for e in main.enemies().duplicate():
		if not is_instance_valid(e) or e.dead:
			continue
		if e.global_position.distance_to(pos) <= r + float(e.radius) * 0.5:
			var away: Vector2 = (e.global_position - pos).normalized() if e.global_position != pos else Vector2.UP
			e.take_hit(foe, away, 90.0)


## A strike caught the climber: it hurts, and wild essence burns a mark or
## feeds an Unbound. True if it landed (a roll's iframes, a barrier and the
## like turn it away).
func catch(c: Dictionary) -> bool:
	var p = main.player
	var prof = main.profile
	var ub := Unbound.is_on(prof)
	var dmg := float(STORM["dmg"]) + float(STORM["per_floor"]) * int(main.floor_num)
	if ub:
		dmg *= float(STORM["unbound_dmg"])
	var hp0: float = p.hp
	p.receive_attack(dmg, null, true)
	if not is_instance_valid(p) or float(p.hp) >= hp0 - 0.001:
		return false
	hits += 1
	if p.dead:
		return true
	if ub:
		feed(c.get("pos", p.global_position))
	elif not prof.bonds.is_empty():
		var out := scorch(prof, p)
		if not out.is_empty():
			var name := String(Bonds.PART_NAMES.get(out["part"], out["part"]))
			var key := "paralyzed" if String(out["rung"]) == "paralyzed" else "burned"
			main.fx_text(p.global_position + Vector2(0, -40), String(TEXT[key]) % name, Color(1.0, 0.4, 0.3))
			main.fx_burst(p.global_position, Vector2.ZERO, Palette.WILD, 12, 200.0)
			main.sfx("burn")
			main.hurt_flash = 0.25
			main.tip("mark_paralyzed" if key == "paralyzed" else "wild_tower")
	return true


## Wild essence burns one of a marked climber's lit marks a rung on the
## marks' own ladder (bond.gd: burned, then paralyzed). A paralyzed or dark
## mark is passed over; it never burns a mark out. Returns {part, rung} or {}.
static func scorch(prof, p, pick := -1) -> Dictionary:
	if p == null or prof == null or Unbound.is_on(prof):
		return {}
	var lit: Array = []
	for part in Bonds.PARTS:
		var b = p.bonds.get(part)
		if b == null or b.has_method("tech_part") or MarkUse.dark(prof, part) or bool(b.paralyzed):
			continue
		lit.append(part)
	if lit.is_empty():
		return {}
	var part := String(lit[(pick if pick >= 0 else randi()) % lit.size()])
	var b = p.bonds[part]
	if not bool(b.burned):
		b.burned = true
		return {"part": part, "rung": "burned"}
	b.paralyzed = true
	return {"part": part, "rung": "paralyzed"}


## Wild essence feeds an Unbound: the tower's essence in what they carry
## (banked at the stair into their Nodes), at most FEED "per_floor" a floor.
## Returns what it gave.
func feed(at: Vector2) -> float:
	var amount := minf(float(FEED["amount"]), float(FEED["per_floor"]) - fed)
	if amount <= 0.0:
		main.fx_text(at + Vector2(0, -40), String(TEXT["fed_full"]), Palette.WILD)
		return 0.0
	fed += amount
	main.gather_essence(String(main.tower_data().get("essence", "air")), amount, at, "wild")
	main.fx_text(main.player.global_position + Vector2(0, -40), String(TEXT["fed"]), Palette.WILD_HOT)
	return amount


# --- a guardian falls -----------------------------------------------------------------------

## A tower's guardian fell (main.gd on_enemy_killed, after the record counts
## it): the first time, its well runs wild, and the third well stirs the
## Makers. `was_wild`: it was wild before. Returns the lines (also kept in
## `news` for the summit's victory).
func on_guardian(tower: String, was_wild: bool) -> Array:
	var out: Array = []
	if was_wild or main == null or main.profile == null or not is_wild(main.profile, tower):
		return out
	var prof = main.profile
	var beast := String(Towers.TOWERS.get(tower, {}).get("beast", tower))
	out.append(String(TEXT["well_wild"]) % (beast.substr(0, 1).to_upper() + beast.substr(1)))
	var n := wells(prof)
	if n >= MAKERS_AT and prof.count("wild_makers") <= 0:
		prof.note("wild_makers")
		out.append(String(TEXT["makers_stir"]))
	elif n > 1:
		out.append(String(TEXT["more_wells"]) % n)
	for l in out:
		main.note_event("news", String(l), Palette.WILD)
	news.append_array(out)
	return out


## The summit's lines about wells gone wild (once).
func summit_lines() -> Array:
	var out := news.duplicate()
	news.clear()
	return out


# --- words ---------------------------------------------------------------------------------

static func _tower_words(tower: String) -> Dictionary:
	var t: Dictionary = Towers.TOWERS.get(tower, {})
	var name := String(t.get("name", tower))
	var low := ("the " + name.substr(4)) if name.begins_with("The ") else name
	var city := String(load("res://scripts/stations.gd").station(load("res://scripts/travel.gd").station_for(tower)).get("name", ""))
	return {"tower": low, "Tower": name, "beast": String(t.get("beast", tower)), "city": city}


static func fill(text: String, f: Dictionary) -> String:
	for k in f:
		text = text.replace("{" + String(k) + "}", str(f[k]))
	if text.begins_with("\"") and text.length() > 1:
		text = "\"" + text.substr(1, 1).to_upper() + text.substr(2)
	return text


## A rumour of a wild tower ("" when none is wild): `kind` one of RUMOURS'
## lists; `tower` the one to speak of ("" for any wild one). `pick` steers
## the choice (tests; -1 at random).
static func rumour(prof, kind := "dining", tower := "", pick := -1) -> String:
	var wild := wild_list(prof)
	if wild.is_empty():
		return ""
	if tower == "" or not (tower in wild):
		tower = String(wild[(pick if pick >= 0 else randi()) % wild.size()])
	var pool: Array = RUMOURS.get(kind, [])
	if pool.is_empty():
		return ""
	return fill(String(pool[(pick if pick >= 0 else randi()) % pool.size()]), _tower_words(tower))


## The Noble's word about wild towers: their own city's first (a station by
## a wild tower), else word of another. "" when none is wild.
static func noble_word(prof, station := "", pick := -1) -> String:
	var Travel = load("res://scripts/travel.gd")
	var own: String = Travel.tower_of(station) if station != "" else ""
	if own != "" and is_wild(prof, own):
		return rumour(prof, "noble_home", own, pick)
	return rumour(prof, "noble_away", "", pick)


## The line on a station's crest when its tower runs wild ("" otherwise).
static func crest_word(prof, tower: String) -> String:
	return String(TEXT["crest"]) if is_wild(prof, tower) else ""


## The Entity's hover help about a tower: a line when it's wild, else "".
static func help_line(prof, tower: String) -> String:
	return String(TEXT["help_line"]) if is_wild(prof, tower) else ""


## The blanks for the Entity's "Wild towers?" topic (entity_talk.gd how_wild).
static func talk_facts(prof) -> Dictionary:
	var f := {
		"wild_hp": "%d%% more health" % int(round((clampf(float(POWER["health"]), 1.0, float(POWER["cap"])) - 1.0) * 100.0)),
		"wild_dmg": "%d%% more damage" % int(round((clampf(float(POWER["damage"]), 1.0, float(POWER["cap"])) - 1.0) * 100.0)),
		"storm_gap": "%d" % int(round((float(STORM["gap"][0]) + float(STORM["gap"][1])) * 0.5)),
		"storm_warn": "%d" % int(round(float(STORM["warn"]))),
		"wild_essence": "%d%%" % int(round((clampf(float(REWARD["essence"]), 1.0, float(REWARD["cap"])) - 1.0) * 100.0)),
		"feed": "%d" % int(FEED["amount"]), "feed_cap": "%d" % int(FEED["per_floor"]),
	}
	var you := String(TEXT["you_none"])
	if prof != null and Unbound.is_on(prof):
		you = String(TEXT["you_unbound"])
	elif prof != null and not prof.bonds.is_empty():
		you = String(TEXT["you_marked"])
	f["wild_you"] = fill(you, f)
	var wild := wild_list(prof)
	var names: Array = wild.map(func(tw): return String(Towers.TOWERS[tw].get("short", tw)))
	if wild.is_empty():
		f["wild_count"] = String(TEXT["none"])
	elif wild.size() == 1:
		f["wild_count"] = String(TEXT["wells_one"]) % names[0]
	else:
		f["wild_count"] = String(TEXT["wells_many"]) % [wild.size(), ", ".join(names)]
	return f


# --- drawing --------------------------------------------------------------------------------

## The floor: scars where strikes fell, and wild motes drifting near the
## climber (the shading toolkit: soft glows and small lit balls).
func _draw() -> void:
	if not here or main == null or main.player == null or not is_instance_valid(main.player):
		return
	var b := Draw.Batch.new()
	for s in scars:
		var r := float(s["r"])
		b.soft(s["pos"], Vector2(r, r * 0.62), Color(Palette.WILD.darkened(0.55), 0.32))
		b.soft(s["pos"], Vector2(r * 0.45, r * 0.3), Color(Palette.WILD, 0.14))
	var t := Time.get_ticks_msec() / 1000.0
	var c: Vector2 = main.player.global_position
	for i in 8:
		var k := float(i)
		var at := c + Vector2(sin(t * 0.31 + k * 1.7) * 280.0, cos(t * 0.23 + k * 2.3) * 190.0)
		var glow := 0.35 + 0.25 * sin(t * 1.3 + k)
		b.soft(at, Vector2(9.0, 9.0), Color(Palette.WILD, 0.18 * glow))
		b.ball(at, 2.0, Color(Palette.WILD_HOT, 0.4 + 0.4 * glow), false)
	b.flush(self)


## Over the darkness: a gathering storm's rings (flat: a warning), and the
## strikes (shaded: a lit column and a glowing ball).
func _draw_over() -> void:
	if main == null:
		return
	var warn := float(STORM["warn"])
	for cdict in cells:
		var pos: Vector2 = cdict["pos"]
		var r := float(cdict["r"])
		var k := clampf(1.0 - float(cdict["warn"]) / maxf(warn, 0.01), 0.0, 1.0)
		over.draw_circle(pos, r, Color(Palette.WILD, 0.1 + 0.2 * k))
		over.draw_arc(pos, r, 0.0, TAU, 40, Color(Palette.WILD, 0.85), 2.0)
		over.draw_arc(pos, r - 5.0, -PI * 0.5, -PI * 0.5 + TAU * k, 40, Color(Palette.WILD_HOT, 0.95), 3.0)
		over.draw_arc(pos, maxf(r * (1.0 - k), 2.0), 0.0, TAU, 28, Color(Palette.WILD_HOT, 0.45), 1.5)
	if strikes.is_empty():
		return
	var b := Draw.Batch.new()
	for s in strikes:
		var pos: Vector2 = s["pos"]
		var r := float(s["r"])
		var a := clampf(1.0 - float(s["t"]) / maxf(float(STORM["strike"]), 0.01), 0.0, 1.0)
		b.soft(pos, Vector2(r * 1.2, r * 0.75), Color(Palette.WILD, 0.5 * a))
		b.bar(pos + Vector2(0, -230.0), pos, Color(Palette.WILD_HOT, a), 4.0 + 10.0 * a)
		b.ball(pos, 4.0 + 10.0 * a, Color(Palette.WILD, a), false)
	b.flush(over)
