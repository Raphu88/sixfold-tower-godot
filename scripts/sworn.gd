extends Node2D
## THE SWORN: climbers who accepted a Maker's secret bond (makers.gd: a good
## answer at a meeting grants the core mark). Every rule, number and word
## about them is here; the instance is only the rescuing figure, drawn for a
## few seconds beside the climber.
##
## SWORN STATUS. Carrying a core mark makes the climber one of the Sworn of
## that Maker (is_sworn, maker_of: read from the profile's core_mark, so an
## old save with a core mark is Sworn too). The climber screen says so (menu.gd,
## a button with hover help "sworn" that asks the Entity), and the Entity
## reacts the first time (tip "sworn").
## SENDS. Now and then (SENDS "chance" at the end of a climb, one errand at a
## time) the Maker sends its Sworn: reach a floor of a named tower (never the
## one just climbed). Reaching it (on_arrive, at the stair) pays a few
## crystals of that tower's essence (SENDS "reward": slow growth) and the
## errand is done. Kept in profile.makers["sworn"] (state()).
## THE RESCUE. The Makers admire and fear the Unbound, and send their Sworn
## to stop the guardians' captures: now and then (RESCUE "chance") a blow
## that would fell a hunted Unbound doesn't. One of the Sworn steps in (a
## cloaked figure with its Maker's sign, a line of words), the climber
## stands again at RESCUE "health" of their health, a moment untouchable,
## and the foes near them reel back. At most once a climb, never on the
## first climb, in the Proving, a station's arena or a duel (main.gd
## proving_spare asks those first). Only for the Unbound.
## THE DRAIN (unbound.gd drain) is what the rescue saves them from: a fall
## drains what their Nodes hold back into the well.

const Makers := preload("res://scripts/makers.gd")
const Unbound := preload("res://scripts/unbound.gd")
const Towers := preload("res://scripts/towers.gd")
const Pronouns := preload("res://scripts/pronouns.gd")
const Draw := preload("res://scripts/draw_util.gd")

## The rescue: the chance a killing blow on a hunted Unbound is stopped (at
## most once a climb), the share of health they stand again with, seconds
## untouchable, how far foes reel back (and for how long), and how long the
## figure shows.
static var RESCUE := {"chance": 0.167, "health": 0.35, "iframes": 2.0, "reach": 170.0, "stagger": 1.2, "show": 3.2}
## Sends: the chance a Maker sends its Sworn at the end of a climb (one
## errand at a time), the floors it may name, and the crystals of that
## tower's essence it pays.
static var SENDS := {"chance": 0.34, "floor_min": 4, "floor_max": 9, "reward": 6}

static var TEXT := {
	"sworn": "Sworn of %s",
	"sworn_short": "Sworn",
	"errand": "%s sends you: reach floor %d of %s (%d %s crystals)",
	"no_errand": "No errand yet. Now and then, after a climb, %s sends you somewhere.",
	"sent": "%s sends you: reach floor %d of %s.",
	"done": "Errand done for %s: +%d %s crystals",
	"rescue_title": "ONE OF THE SWORN",
	"rescue_who": "A Sworn of %s steps between you and the blow.",
	"rescue_note": "Saved from the drain by a Sworn of %s",
}
## What a rescuer says, by Maker (one is picked). {they}, {them}: the climber.
static var RESCUE_LINES := {
	"marks": ["\"Not this one. My Maker has not finished reading {them}.\"", "\"Stand up. The well can wait.\""],
	"towers": ["\"Up. These stairs were not built to keep {them}.\"", "\"Not today. Climb.\""],
	"creatures": ["\"Easy. The guardians can hunt someone else tonight.\"", "\"Stand. My Maker wants to see what {they} become{s}.\""],
}
## A Maker's words as it sends its Sworn (one is picked).
static var SEND_LINES := {
	"marks": ["It wants to read how that tower reads you."],
	"towers": ["It wants eyes on its stones there."],
	"creatures": ["It wants news of its children there."],
}

var maker := ""
var t := 0.0
var main_ref


# --- status ---------------------------------------------------------------------------------

## True for a climber who carries a core mark: one of the Sworn of its Maker.
static func is_sworn(prof) -> bool:
	return prof != null and not Makers.core(prof).is_empty()


## The Maker the climber is sworn to ("" for none).
static func maker_of(prof) -> String:
	return String(Makers.core(prof).get("maker", ""))


## "Sworn of the Maker of Towers" ("" for none).
static func title(prof) -> String:
	var m := maker_of(prof)
	if m == "":
		return ""
	return TEXT["sworn"] % String(Makers.MAKERS[m]["name"])


## The Sworn's saved state (profile.makers["sworn"]): {errand: {} or {tower,
## floor, reward}, done: errands done, rescued: times rescued}.
static func state(prof) -> Dictionary:
	var mk := Makers.state(prof)
	if mk.is_empty():
		return {}
	var s = mk.get("sworn")
	if not (s is Dictionary):
		s = {}
		mk["sworn"] = s
	if not (s.get("errand") is Dictionary):
		s["errand"] = {}
	s["done"] = int(s.get("done", 0))
	s["rescued"] = int(s.get("rescued", 0))
	return s


## The climber screen's line under the title: the errand, or that none is set.
static func errand_line(prof) -> String:
	var m := maker_of(prof)
	if m == "":
		return ""
	var e: Dictionary = state(prof)["errand"]
	var who := String(Makers.MAKERS[m]["Name"])
	if e.is_empty() or not Towers.TOWERS.has(String(e.get("tower", ""))):
		return TEXT["no_errand"] % String(Makers.MAKERS[m]["name"])
	var tw: Dictionary = Towers.TOWERS[String(e["tower"])]
	return TEXT["errand"] % [who, int(e["floor"]), _tower_name(String(e["tower"])), int(e["reward"]), load("res://scripts/essence.gd").display(String(tw["essence"]))]


# --- sends ------------------------------------------------------------------------------------

## A tower's name in the middle of a sentence: "the Kraken's Tower".
static func _tower_name(tw: String) -> String:
	var n := String(Towers.TOWERS.get(tw, {}).get("name", tw))
	return "the " + n.substr(4) if n.begins_with("The ") else n


## The end of a climb (main.gd pay_climb): now and then the Maker sends its
## Sworn somewhere new. `roll` stands in for the chance (tests; -1 at random).
## Returns the line said ("" for none).
static func on_climb_end(main, roll := -1.0) -> String:
	if main == null or main.get("profile") == null:
		return ""
	var prof = main.profile
	var m := maker_of(prof)
	if m == "":
		return ""
	var s := state(prof)
	if not (s["errand"] as Dictionary).is_empty():
		return ""
	if roll < 0.0 and Engine.has_meta("sixfold_test"):
		return ""  # (tests: never by chance; they pass a roll)
	if (roll if roll >= 0.0 else randf()) >= float(SENDS["chance"]):
		return ""
	var here := String(main.get("tower"))
	var towers: Array = Towers.ORDER.filter(func(o): return String(o) != here)
	if towers.is_empty():
		return ""
	var tw := String(towers[randi() % towers.size()])
	var fl := randi_range(int(SENDS["floor_min"]), maxi(int(SENDS["floor_min"]), int(SENDS["floor_max"])))
	s["errand"] = {"tower": tw, "floor": fl, "reward": int(SENDS["reward"])}
	prof.save()
	var lines: Array = SEND_LINES.get(m, [])
	var line: String = TEXT["sent"] % [String(Makers.MAKERS[m]["Name"]), fl, _tower_name(tw)]
	if not lines.is_empty():
		line += " " + String(lines[randi() % lines.size()])
	if main.has_method("note_event"):
		main.note_event("news", line, Makers.color(m))
	if main.has_method("tip"):
		main.tip("sworn_sent")
	return line


## Arriving on a floor (main.gd, after the stair): the errand is done once
## its floor of its tower is reached. Returns the line ("" if nothing).
static func on_arrive(main) -> String:
	if main == null or main.get("profile") == null:
		return ""
	var prof = main.profile
	var m := maker_of(prof)
	if m == "":
		return ""
	var s := state(prof)
	var e: Dictionary = s["errand"]
	if e.is_empty() or String(main.get("tower")) != String(e.get("tower", "")) or int(main.get("floor_num")) < int(e.get("floor", 99)):
		return ""
	var kind := String(Towers.TOWERS[String(e["tower"])]["essence"])
	var reward := maxi(0, int(e.get("reward", SENDS["reward"])))
	prof.add_crystal(kind, float(reward))
	s["errand"] = {}
	s["done"] = int(s["done"]) + 1
	prof.save()
	var line: String = TEXT["done"] % [String(Makers.MAKERS[m]["name"]), reward, load("res://scripts/essence.gd").display(kind)]
	if main.has_method("note_event"):
		main.note_event("news", line, Makers.color(m))
	return line


# --- the rescue -------------------------------------------------------------------------------

## A blow would fell the climber (main.gd proving_spare, after the Proving,
## the arena and a duel): one of the Sworn may step in. `roll` stands in for
## the chance (main.sworn_roll in tests; -1 at random). True if they did.
static func try_rescue(main, roll := -1.0) -> bool:
	if main == null or main.get("profile") == null or main.get("player") == null:
		return false
	var prof = main.profile
	if not Unbound.is_on(prof) or bool(main.get("first_climb")) or bool(main.get("on_train")) or bool(main.get("sworn_rescued")):
		return false
	if roll < 0.0 and Engine.has_meta("sixfold_test"):
		return false  # (tests: never by chance, so a test's fall stays a fall; they set main.sworn_roll)
	if (roll if roll >= 0.0 else randf()) >= float(RESCUE["chance"]):
		return false
	main.sworn_rescued = true
	var p = main.player
	var m := rescuer(main)
	if is_instance_valid(p):
		p.hp = maxf(float(p.hp), float(p.max_health()) * float(RESCUE["health"]))
		p.iframes = maxf(float(p.iframes), float(RESCUE["iframes"]))
		for e in main.enemies():
			if is_instance_valid(e) and not e.dead and e.global_position.distance_to(p.global_position) < float(RESCUE["reach"]) + float(e.radius):
				if e.has_method("stagger"):
					var boss: bool = e.has_method("is_boss") and e.is_boss()
					e.stagger(float(RESCUE["stagger"]) * (0.5 if boss else 1.0))
	var s := state(prof)
	s["rescued"] = int(s["rescued"]) + 1
	prof.save()
	var who := String(Makers.MAKERS[m]["name"])
	var said: Array = RESCUE_LINES.get(m, [])
	var lines: Array = [TEXT["rescue_who"] % who]
	if not said.is_empty():
		lines.append(Pronouns.fill(String(said[randi() % said.size()])))
	main.banner = {"title": TEXT["rescue_title"], "lines": lines, "t": 3.8}
	if main.has_method("note_event"):
		main.note_event("news", TEXT["rescue_note"] % who, Makers.color(m))
	if is_instance_valid(p) and main is Node:
		var fig = load("res://scripts/sworn.gd").new()
		fig.maker = m
		fig.main_ref = main
		main.add_child(fig)
		fig.global_position = p.global_position + Vector2(-34.0 if randf() < 0.5 else 34.0, -6.0)
		if main.has_method("light_flash"):
			main.light_flash(p.global_position, Makers.color(m), 1.6, 1.4, 0.5)
		if main.has_method("fx_ring"):
			main.fx_ring(p.global_position, Makers.color(m), float(RESCUE["reach"]), 0.5, 3.0)
		if main.has_method("sfx"):
			main.sfx("chime", 0.7, -2.0, 0.0)
			main.sfx("maker_glimpse", 1.1, -4.0, 0.0)
	if main.has_method("tip"):
		main.tip("sworn_rescue")
	return true


## The Maker whose Sworn steps in: the one most taken with the climber (its
## interest), at random among equals.
static func rescuer(main) -> String:
	var mk := Makers.state(main.profile)
	var best := ""
	var most := -1.0
	for m in Makers.ORDER:
		var v := float(mk.get("interest", {}).get(m, 0.0)) + randf() * 0.001
		if v > most:
			most = v
			best = m
	return best if best != "" else String(Makers.ORDER[0])


# --- the figure -------------------------------------------------------------------------------

func _ready() -> void:
	z_index = 4
	t = 0.0


func _process(delta: float) -> void:
	t += delta
	var span := float(RESCUE["show"])
	if t >= span:
		queue_free()
		return
	# Fades in fast, holds, fades out.
	modulate.a = clampf(t / 0.25, 0.0, 1.0) * clampf((span - t) / 0.6, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	figure_into(self, maker, t)


## A cloaked Sworn, its Maker's sign on its breast and a drawn blade, lit
## from the top-left by the shading toolkit. Its feet at (0, 0).
static func figure_into(c: CanvasItem, mk: String, time: float) -> void:
	var col: Color = Makers.color(mk)
	var cloak := Color(0.2, 0.19, 0.25)
	var b := Draw.Batch.new()
	b.contact(Vector2(0, 2), 13.0)
	var sway := sin(time * 3.0) * 1.5
	b.poly(PackedVector2Array([Vector2(-12, 2), Vector2(-8 + sway, -26), Vector2(0, -34), Vector2(8 + sway, -26), Vector2(12, 2)]), cloak)
	b.ball(Vector2(0, -38), 7.5, cloak.lightened(0.15))  # (the hood)
	b.disc(Vector2(1.5, -37), 3.6, Color(0.05, 0.05, 0.08))  # (its face in shadow)
	b.stroke(Vector2(9, -14), Vector2(26, -32), Color(0.85, 0.86, 0.92), 2.2)  # (a drawn blade)
	b.stroke(Vector2(6, -11), Vector2(12, -17), Color(0.45, 0.38, 0.3), 3.0)
	Makers.draw_sign(b, Vector2(0, -18), 4.0, String(Makers.MAKERS.get(mk, {}).get("sign", "")), col, 1.2)
	b.flush(c)
