extends Node2D
## SUMMIT BLADES (the old game's "sacred swords", renamed by the owner): one
## blade hidden in each tower. Find it on its floor, carry it to the summit
## and it is BONDED to you for good; then AWAKEN it, a step at a time,
## with crystals of its tower's essence.
##
## How it plays:
##   HIDDEN  each tower's blade lies on one floor (picked for each climber,
##           RULES "floors"), in a quiet corner of a room, half sunk in the
##           floor. Without a lead it can only be seen up close (RULES
##           "near"), with a faint glint now and then a little farther off
##           ("glint"). With a LEAD (profile.summit_leads[tower], given by
##           the pocket vaults) its glint shows from anywhere you can see,
##           a pale beam stands over it, and arriving on its floor says so.
##   CARRY   walk over it and you take it up, strapped across your back. It
##           isn't gear: it can't be sold, stashed or swapped. Fall, or
##           leave by any way but the summit, and it slips back to its
##           hiding place, to be found again.
##   BOND    reach the summit with it and it's yours for good: kept with
##           the climber, never lost. You carry one bonded blade at a time
##           (the book's Deeds ribbon, Summit Blades), sheathed at your hip.
##   POWER   each blade has its own power (BLADES "power"), fired by a
##           landed finisher or a perfect parry, with a short rest between
##           ("cd"). A blade is distinct from a beast's Regarded piece: that
##           is gear you wield (and lose in a fall); a Summit Blade is never
##           wielded or lost, and its power grows only as it awakens.
##   AWAKEN  on the train, one step between climbs at most, for crystals of
##           its tower's essence (AWAKEN: slow on purpose). Each step makes
##           its power stronger and its rest shorter, to step 6.
##
## Names, words and numbers are plain data here, easy to change; the names
## are placeholders and each blade's "history" is the owner's to write.

const Gear := preload("res://scripts/gear.gd")
const Essence := preload("res://scripts/essence.gd")
const Palette := preload("res://scripts/palette.gd")
const UI := preload("res://scripts/ui.gd")
const Draw := preload("res://scripts/draw_util.gd")
const Grid := preload("res://scripts/towers/water_wind_grid.gd")
const Themes := preload("res://scripts/themes.gd")

## The six blades, by tower. "power" says what fires it (finisher or
## perfect parry) and what it does; its numbers grow with each awakening
## step ("per"). "color" is the steel's glow.
static var BLADES := {
	"gryphon": {"name": "Galebrand", "kind": "air", "trigger": "finisher", "history": "",
		"power": "Storm call: a landed finisher calls a bolt from the blade to up to two foes near the one you struck",
		"dmg": 6.0, "per": 2.0, "reach": 150.0, "color": Color(0.7, 0.86, 1.0)},
	"kraken": {"name": "Tidemourn", "kind": "water", "trigger": "parry", "history": "",
		"power": "Undertow: a perfect parry rolls a wave out from you that hurls foes back and slows them",
		"dmg": 4.0, "per": 1.5, "reach": 100.0, "color": Color(0.45, 0.8, 0.92)},
	"wyvern": {"name": "Anvilsong", "kind": "iron", "trigger": "finisher", "history": "",
		"power": "Echo: a landed finisher rings on, and the blade's echo strikes the foe again and staggers it",
		"dmg": 8.0, "per": 2.5, "reach": 0.0, "color": Color(0.82, 0.84, 0.9)},
	"manticore": {"name": "Duneshard", "kind": "stone", "trigger": "finisher", "history": "",
		"power": "Grit: a landed finisher poisons every foe near the one you struck",
		"dmg": 1.0, "per": 0.5, "reach": 80.0, "color": Color(0.9, 0.74, 0.46)},
	"firebird": {"name": "Emberwake", "kind": "fire", "trigger": "parry", "history": "",
		"power": "Kindle: a perfect parry warms you, healing you a little",
		"dmg": 4.0, "per": 1.0, "reach": 0.0, "color": Color(1.0, 0.6, 0.3)},
	"chimera": {"name": "Thornfang", "kind": "blade", "trigger": "finisher", "history": "",
		"power": "Briar burst: a landed finisher bursts into thorns that cut the foes round the one you struck",
		"dmg": 5.0, "per": 1.5, "reach": 80.0, "color": Color(0.7, 0.9, 0.55)},
}
const ORDER := ["gryphon", "kraken", "wyvern", "manticore", "firebird", "chimera"]

## Awakening: crystals of the blade's essence for each step, 1 to 6. One
## step between climbs at most. Slow growth: about 250 crystals in all.
static var AWAKEN := [12, 24, 36, 48, 60, 72]
## The power's rest: "cd" seconds, less "cd_per" a step.
## floors: the floors a blade may lie on (picked once for each climber).
## near: how close you must be to see it without a lead; glint: how far its
## glint shows now and then (every "glint_every" seconds); take: how close
## to take it up.
static var RULES := {"cd": 5.0, "cd_per": 0.4, "floors": [3, 10], "near": 90.0, "glint": 260.0, "glint_every": 5.0, "take": 26.0}

static var TEXT := {
	"found": "A Summit Blade: %s. Carry it to the summit to bond it.",
	"found_log": "Found the Summit Blade %s",
	"carrying": "Carrying %s: reach the summit to bond it",
	"lost": "%s slipped back to its hiding place",
	"bonded": "%s is bonded to you for good",
	"lead_floor": "Your lead: %s lies somewhere on this floor",
	"lead_climb": "Your lead: %s lies on floor %d of this tower",
	"power_fx": "%s",
	"step": "Awakening %d of %d",
	"woke": "%s awakens: step %d",
	"awaken": "Awaken: step %d",
	"awaken_cost": "%d %s crystals",
	"awaken_wait": "It has awakened once since your last climb. Climb, and it can wake again.",
	"awaken_full": "Fully awake.",
	"carry": "Carry this blade",
	"carried": "At your hip",
	"unknown": "Not found yet",
	"unknown_line": "Hidden somewhere in %s.",
	"lead_line": "You have a lead on it.",
	"not_bonded": "Found, not bonded: carry it to the summit.",
	"page_title": "Summit Blades",
	"page_note": "One blade lies hidden in each tower. Find it, carry it to the summit to bond it for good, then awaken it here between climbs with crystals of its tower's essence. You carry one bonded blade at a time; its power fires by itself in a fight.",
	"on_train_only": "Awaken it on the train, between climbs.",
	"name_line": "%s  ·  %s essence",
	"none_yet": "No Summit Blade bonded yet.",
}

## (tests: the blade lies on every floor that has a spot)
static var forced := false
## (tests: leads given without the vaults: tower -> true)
static var test_leads := {}

var main
## Off in tests (no blade lies in their floors) unless a test sets `forced`.
var on := not Engine.has_meta("sixfold_test")
var spot := {}  # {pos, tower} while the blade lies on this floor
var carrying := ""  # the tower whose blade you carry up, this climb
var t := 0.0
var over: Node2D


# --- the climber's blades -------------------------------------------------------------

## The climber's Summit Blades, every key filled in:
##   bonded  tower -> {"level": awakening step 0..6, "woke": the climb count it last woke at}
##   worn    the bonded blade carried at the hip ("" for none)
##   floors  tower -> the floor its blade lies on (picked once)
##   found   tower -> true once found (bonded or not)
##   climbs  climbs begun (a blade awakens at most once between two)
static func state(profile) -> Dictionary:
	if not (profile.summit_blades is Dictionary):
		profile.summit_blades = {}
	var s: Dictionary = profile.summit_blades
	for k in ["bonded", "floors", "found"]:
		if not (s.get(k) is Dictionary):
			s[k] = {}
	if not (s.get("worn") is String):
		s["worn"] = ""
	if not (s.get("climbs") is int):
		s["climbs"] = int(s.get("climbs", 0)) if (s.get("climbs") is float) else 0
	return s


static func bonded(profile, tower: String) -> bool:
	return state(profile)["bonded"].has(tower)


static func bonded_count(profile) -> int:
	return state(profile)["bonded"].size()


static func level(profile, tower: String) -> int:
	return int(state(profile)["bonded"].get(tower, {}).get("level", 0))


## The blade carried at the hip ("" for none).
static func worn(profile) -> String:
	var w := String(state(profile)["worn"])
	return w if bonded(profile, w) else ""


static func blade_name(tower: String) -> String:
	return String(BLADES.get(tower, {}).get("name", tower))


static func color(tower: String) -> Color:
	return BLADES.get(tower, {}).get("color", Color.WHITE)


## The floor a tower's blade lies on for this climber (picked once, saved).
static func blade_floor(profile, tower: String) -> int:
	var s := state(profile)
	if not s["floors"].has(tower):
		var r: Array = RULES["floors"]
		s["floors"][tower] = int(r[0]) + randi() % (int(r[1]) - int(r[0]) + 1)
	return int(s["floors"][tower])


## A lead on a tower's blade (the pocket vaults' profile.summit_leads, any
## truthy entry; or a test's).
static func has_lead(profile, tower: String) -> bool:
	if test_leads.get(tower, false):
		return true
	var leads = profile.get("summit_leads") if profile != null else null
	if not (leads is Dictionary):
		# (the pocket vaults note a lead in the climber's record: vaults.gd lead_count)
		var rec = profile.get("record") if profile != null else null
		return rec is Dictionary and float(rec.get("summit_leads:" + tower, 0.0)) > 0.0
	var v = leads.get(tower, null)
	if v is bool:
		return v
	if v is int or v is float:
		return v > 0
	if v is Dictionary or v is Array or v is String:
		return not v.is_empty()
	return v != null


## Its power's strength at its awakening step.
static func strength(profile, tower: String) -> float:
	var b: Dictionary = BLADES[tower]
	return float(b["dmg"]) + float(b["per"]) * level(profile, tower)


static func rest(profile, tower: String) -> float:
	return maxf(1.0, float(RULES["cd"]) - float(RULES["cd_per"]) * level(profile, tower))


## What awakening its next step costs ({kind: amount}; {} when fully awake).
static func awaken_cost(profile, tower: String) -> Dictionary:
	var lv := level(profile, tower)
	if lv >= AWAKEN.size():
		return {}
	return {String(BLADES[tower]["kind"]): int(AWAKEN[lv])}


## Why it can't awaken now ("" if it can).
static func awaken_why(profile, tower: String) -> String:
	if not bonded(profile, tower):
		return TEXT["not_bonded"]
	var cost := awaken_cost(profile, tower)
	if cost.is_empty():
		return TEXT["awaken_full"]
	if int(state(profile)["bonded"][tower].get("woke", -1)) >= int(state(profile).get("climbs", 0)):
		return TEXT["awaken_wait"]
	return load("res://scripts/bench.gd").short_of(profile, cost)


## Awakens a bonded blade one step (crystals of its kind). "" if done.
static func awaken(profile, tower: String) -> String:
	var why := awaken_why(profile, tower)
	if why != "":
		return why
	load("res://scripts/bench.gd").pay(profile, awaken_cost(profile, tower))
	var e: Dictionary = state(profile)["bonded"][tower]
	e["level"] = int(e.get("level", 0)) + 1
	e["woke"] = int(state(profile).get("climbs", 0))
	profile.save()
	return ""


static func carry(profile, tower: String) -> void:
	if bonded(profile, tower):
		state(profile)["worn"] = tower
		profile.save()


# --- in a fight ---------------------------------------------------------------------------

## A landed finisher (player.gd _melee): the carried blade's power, if it fires on one.
static func on_finisher(p, e) -> void:
	_fire(p, "finisher", e, false)


## A parry (player.gd _on_parry): a perfect one fires a blade that answers parries.
static func on_parry(p, source, perfect: bool) -> void:
	if perfect:
		_fire(p, "parry", source, true)


static func _fire(p, trigger: String, e, _perfect: bool) -> void:
	var m = p.main
	if m == null or m.get("profile") == null or p.blade_cd > 0.0 or p.dead:
		return
	var tower := worn(m.profile)
	if tower == "" or String(BLADES[tower]["trigger"]) != trigger:
		return
	var b: Dictionary = BLADES[tower]
	var pw := strength(m.profile, tower)
	var col: Color = b["color"]
	p.blade_cd = rest(m.profile, tower)
	p.set_meta("blade_flash", Time.get_ticks_msec() * 0.001)
	var at: Vector2 = e.global_position if e is Node2D and is_instance_valid(e) else p.global_position
	match tower:
		"gryphon":
			var from = e
			var struck: Array = [e]
			for i in 2:
				var next = null
				var best := float(b["reach"])
				for o in m.targets():
					var d: float = o.global_position.distance_to(from.global_position)
					if not (o in struck) and not o.dead and d < best:
						next = o
						best = d
				if next == null:
					break
				m.fx_bolt([from.global_position, next.global_position], col)
				next.take_hit(pw, Vector2.ZERO)
				struck.append(next)
				from = next
			m.sfx("zap", 1.1, -4.0)
		"kraken":
			m.fx_ring(p.global_position, col, float(b["reach"]), 0.4, 5.0)
			for o in m.targets():
				var away: Vector2 = o.global_position - p.global_position
				if not o.dead and away.length() < float(b["reach"]) + o.radius:
					o.take_hit(pw, away.normalized(), 420.0)
					o.chill_t = maxf(o.chill_t, 1.5)
			m.sfx("wave", 1.0, -4.0)
		"wyvern":
			if e is Node and is_instance_valid(e) and not e.dead:
				e.take_hit(pw, (e.global_position - p.global_position).normalized(), 160.0, true)
				e.stagger(0.4 if e.is_boss() else 0.8)
			m.fx_ring(at, col, 30.0, 0.3, 3.0)
			m.sfx("hit_armor", 1.4, -4.0)
		"manticore":
			for o in m.targets():
				if not o.dead and o.global_position.distance_to(at) < float(b["reach"]) + o.radius:
					o.add_venom(maxi(1, int(pw)))
			m.fx_ring(at, col, float(b["reach"]), 0.35, 3.0)
			m.sfx("spell_sand", 1.0, -4.0)
		"firebird":
			p.hp = minf(p.max_health(), p.hp + pw * p.heal_mult())
			m.fx_ring(p.global_position, col, 40.0, 0.4, 3.0)
			m.sfx("life_mend", 1.1, -4.0)
		"chimera":
			for o in m.targets():
				if not o.dead and o != e and o.global_position.distance_to(at) < float(b["reach"]) + o.radius:
					o.take_hit(pw, (o.global_position - at).normalized(), 120.0)
			m.fx_burst(at, Vector2.UP, col, 12, 260.0)
			m.sfx("spell_blade", 1.0, -4.0)
	m.fx_text(p.global_position + Vector2(0, -48), blade_name(tower), col)
	load("res://scripts/deeds.gd").note(m, "blade_powers")


# --- hiding it on a floor (floors.gd) -------------------------------------------------------

## A quiet spot for a blade on this floor, maybe used (setup decides): a
## corner of the room farthest from the start, on plain floor, clear of
## what matters. plan["summit_spot"] = {pos, room}.
static func plan(p: Dictionary, infos: Array, floor_num: int, tower: String) -> void:
	if not BLADES.has(tower) or floor_num < 2 or p.get("summit", false) or not p.has("room_info"):
		return
	var g := Grid.grid(p)
	var prot := Grid.protected(p, infos)
	for c in p.get("chests", []):
		prot[Grid.tile(c["pos"])] = true
	for pl in p.get("pillars", []):
		prot[Grid.tile(pl["pos"])] = true
	if p.has("inscription"):
		var it: Vector2i = Grid.tile(p["inscription"]["pos"])
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				prot[it + Vector2i(dx, dy)] = true
	var start: Vector2 = p.get("start", Vector2.ZERO)
	var order: Array = range(1, infos.size())
	order.sort_custom(func(a, b): return Vector2(infos[a]["rect"].get_center()).distance_to(start) > Vector2(infos[b]["rect"].get_center()).distance_to(start))
	for i in order:
		var info: Dictionary = infos[i]
		var th: Dictionary = Themes.get_theme(String(p["themes"][i]))
		if String(th["kind"]) in ["scenario", "mirror", "proving"] or String(th["feature"]) in ["trap", "puzzle", "scenario", "mirror", "vault"]:
			continue
		var rows: Array = info["rows"]
		var at: Vector2i = info["pos"]
		var w := String(rows[0]).length()
		# The corners first: a blade waits where nobody walks.
		for corner in [Vector2i(1, 1), Vector2i(w - 2, 1), Vector2i(1, rows.size() - 2), Vector2i(w - 2, rows.size() - 2)]:
			for step in 3:
				var l: Vector2i = corner + Vector2i(signi(w / 2 - corner.x) * step, signi(rows.size() / 2 - corner.y) * step)
				var tt := at + l
				if l.y < 0 or l.y >= rows.size() or l.x < 0 or l.x >= String(rows[l.y]).length() or String(rows[l.y])[l.x] != ".":
					continue
				if not Grid.is_open(g, tt) or prot.has(tt):
					continue
				p["summit_spot"] = {"pos": Grid.centre(tt), "room": i}
				return


# --- in play ---------------------------------------------------------------------------------

func _ready() -> void:
	z_index = -2  # (on the floor, under everyone)
	over = Node2D.new()
	over.z_as_relative = false
	over.z_index = 58  # (over the darkness: the glint, and a lead's beam)
	over.draw.connect(_draw_over)
	add_child(over)


## A new climb: nothing carried (and one more climb begun: a blade may awaken again).
func new_climb() -> void:
	carrying = ""
	if main != null and main.get("profile") != null:
		state(main.profile)["climbs"] = int(state(main.profile)["climbs"]) + 1


## A new floor: the blade lies here if this is its floor, and it isn't found or bonded.
func setup(p: Dictionary) -> void:
	spot = {}
	t = 0.0
	if main == null or main.get("profile") == null:
		_redraw()
		return
	var tower := String(main.tower)
	var prof = main.profile
	if not on and not forced:
		_redraw()
		return
	if BLADES.has(tower) and p.has("summit_spot") and carrying != tower and not bonded(prof, tower) \
			and (forced or int(main.floor_num) == blade_floor(prof, tower)):
		spot = {"pos": p["summit_spot"]["pos"], "tower": tower}
		if has_lead(prof, tower):
			main.note_event("news", TEXT["lead_floor"] % blade_name(tower), color(tower), true)
	elif BLADES.has(tower) and int(main.floor_num) == 1 and not bonded(prof, tower) and has_lead(prof, tower) and carrying != tower:
		main.note_event("news", TEXT["lead_climb"] % [blade_name(tower), blade_floor(prof, tower)], color(tower), true)
	_redraw()


## Shows from afar: a lead's glint.
func lead() -> bool:
	return not spot.is_empty() and main != null and has_lead(main.profile, String(spot["tower"]))


## Can the climber see it now (close enough, or a lead's glint)?
func seen() -> bool:
	if spot.is_empty() or main == null or main.player == null:
		return false
	return lead() or main.player.global_position.distance_to(spot["pos"]) < float(RULES["near"])


func _process(delta: float) -> void:
	if spot.is_empty() or main == null or main.player == null:
		return
	t += delta
	var p = main.player
	if not p.dead and p.global_position.distance_to(spot["pos"]) < float(RULES["take"]):
		take()
		return
	_redraw()


## Takes the blade up: carried to the summit, or lost on a fall.
func take() -> void:
	if spot.is_empty():
		return
	var tower := String(spot["tower"])
	carrying = tower
	spot = {}
	var col := color(tower)
	state(main.profile)["found"][tower] = true
	main.profile.save()
	main.fx_text(main.player.global_position + Vector2(0, -44), blade_name(tower), col)
	main.fx_ring(main.player.global_position, col, 70.0, 0.5, 4.0)
	main.light_flash(main.player.global_position, col, 1.6, 2.0, 0.4)
	main.sfx("pedestal", 1.0, -2.0, 0.0)
	main.note_event("news", TEXT["found_log"] % blade_name(tower), col, true)
	main.tip("summit_blade")
	load("res://scripts/deeds.gd").note(main, "blades_found")
	_redraw()


## The summit (main.gd's stair): a carried blade is bonded for good. Returns the stair's lines.
func on_summit() -> Array:
	if main == null:
		return []
	load("res://scripts/deeds.gd").note(main, "summits")
	if carrying == "":
		return []
	var tower := carrying
	carrying = ""
	var s := state(main.profile)
	if not s["bonded"].has(tower):
		s["bonded"][tower] = {"level": 0, "woke": int(s["climbs"])}
	if worn(main.profile) == "":
		s["worn"] = tower
	main.profile.save()
	main.tip("summit_bond")
	load("res://scripts/deeds.gd").note(main, "blades_bonded")
	return [TEXT["bonded"] % blade_name(tower)]


func _redraw() -> void:
	queue_redraw()
	if over != null:
		over.queue_redraw()


func _draw() -> void:
	if spot.is_empty() or not seen():
		return
	var c: Vector2 = spot["pos"]
	var near_k := 1.0
	if main != null and main.player != null and not lead():
		near_k = clampf(1.0 - main.player.global_position.distance_to(c) / float(RULES["near"]), 0.25, 1.0)
	var b := Draw.Batch.new()
	floor_into(b, c, String(spot["tower"]), near_k, t)
	b.flush(self)


## The blade half sunk in the floor, point down, a crack round it.
static func floor_into(b, c: Vector2, tower: String, alpha: float, time: float) -> void:
	var col := color(tower)
	b.circle(c + Vector2(0, 4), 10.0, Color(0, 0, 0, 0.3 * alpha))
	for k in 4:
		var a := 0.6 + k * 1.5
		b.line(c + Vector2(0, 4), c + Vector2(0, 4) + Vector2.from_angle(a) * 9.0, Color(0.05, 0.04, 0.06, 0.6 * alpha), 1.0)
	b.poly(PackedVector2Array([c + Vector2(-2.4, 4), c + Vector2(2.4, 4), c + Vector2(2.0, -12), c + Vector2(0, -15), c + Vector2(-2.0, -12)]),
		Color(Palette.STEEL.lerp(col, 0.35), alpha), 1.2)
	b.line(c + Vector2(0, 2), c + Vector2(0, -12), Color(1, 1, 1, 0.5 * alpha), 0.8)
	b.stroke(c + Vector2(-7, -15), c + Vector2(7, -15), Color(col.darkened(0.3), alpha), 2.6)
	b.stroke(c + Vector2(0, -16), c + Vector2(0, -23), Color(0.3, 0.22, 0.18, alpha), 2.6)
	b.circle(c + Vector2(0, -24.5), 2.4, Color(col, alpha))
	b.circle(c + Vector2(0, -24.5), 5.0 + sin(time * 2.0), Color(col, 0.25 * alpha))


## The glint over the darkness: now and then without a lead; with one,
## always, with a pale beam over it.
func _draw_over() -> void:
	if spot.is_empty() or main == null or main.player == null:
		return
	var c: Vector2 = spot["pos"]
	var col := color(String(spot["tower"]))
	var d: float = main.player.global_position.distance_to(c)
	if lead():
		var pulse := 0.6 + 0.4 * sin(t * 2.4)
		over.draw_rect(Rect2(c + Vector2(-5, -150), Vector2(10, 150)), Color(col, 0.08 + 0.05 * pulse))
		over.draw_rect(Rect2(c + Vector2(-2, -150), Vector2(4, 150)), Color(col, 0.12 + 0.06 * pulse))
		_star(c + Vector2(0, -20), 7.0 + 3.0 * pulse, Color(col.lightened(0.4), 0.9))
		return
	var every := float(RULES["glint_every"])
	var phase := fmod(t, every)
	if d < float(RULES["glint"]) and phase < 0.5:
		var k := sin(phase / 0.5 * PI)
		_star(c + Vector2(0, -20), 6.0 * k, Color(col.lightened(0.5), 0.8 * k))


func _star(at: Vector2, r: float, col: Color) -> void:
	if r <= 0.2:
		return
	over.draw_line(at + Vector2(-r, 0), at + Vector2(r, 0), col, 1.5)
	over.draw_line(at + Vector2(0, -r), at + Vector2(0, r), col, 1.5)
	over.draw_circle(at, r * 0.3, col)


# --- on the climber -----------------------------------------------------------------------------

## The climber's drawing (player.gd _draw): a found blade strapped across
## the back while you carry it up; a bonded one sheathed at the hip.
static func draw_on_climber(p, time: float) -> void:
	if p.dead or p.main == null or p.main.get("profile") == null:
		return
	var a: Vector2 = p.aim if p.aim != Vector2.ZERO else Vector2.RIGHT
	var n := a.orthogonal()
	var node = p.main.get("summit_blades")
	var up := String(node.carrying) if node != null else ""
	var b := Draw.Batch.new()
	if up != "":
		var col := color(up)
		var from := -a * 10.0 + n * 9.0
		var to := -a * 8.0 - n * 13.0
		b.stroke(from, to, Palette.OUTLINE, 3.6)
		b.stroke(from, to, Palette.STEEL.lerp(col, 0.3), 2.0)
		b.circle(from, 2.2, col)
		b.circle(from, 4.5 + sin(time * 3.0), Color(col, 0.25))
	var tower := worn(p.main.profile)
	if tower != "":
		var col2 := color(tower)
		var hip := -a * 3.0 + n * 11.0 + Vector2(0, 2)
		var tip := hip - a * 9.0 + n * 2.0
		b.stroke(hip, tip, Palette.OUTLINE, 3.4)
		b.stroke(hip, tip, Color(0.28, 0.2, 0.16), 2.0)  # (its scabbard)
		b.stroke(hip - n * 2.4, hip + n * 2.4, col2.darkened(0.2), 1.6)
		var flash := Time.get_ticks_msec() * 0.001 - float(p.get_meta("blade_flash", -9.0))
		var glow := 0.25 + (0.6 * (1.0 - flash / 0.5) if flash < 0.5 else 0.0)
		b.circle(hip + a * 2.5, 1.8, col2)
		b.circle(hip + a * 2.5, 4.0, Color(col2, glow))
	if b.size() > 0:
		b.flush(p)


## A blade's picture for the book's page: upright, its glow by its awakening.
static func icon_into(b, c: Vector2, s: float, tower: String, lit: bool, step: int) -> void:
	var col := color(tower)
	var u := s / 24.0
	var steel := Palette.STEEL.lerp(col, 0.3) if lit else Color(0.3, 0.28, 0.32)
	if lit:
		b.circle(c, 16.0 * u, Color(col, 0.08 + 0.04 * step))
	var tip := c + Vector2(0, 20) * u
	b.poly(PackedVector2Array([c + Vector2(-2.6, -8) * u, c + Vector2(2.6, -8) * u, c + Vector2(2.2, 16) * u, tip, c + Vector2(-2.2, 16) * u]), steel, 1.2)
	b.line(c + Vector2(0, -7) * u, c + Vector2(0, 16) * u, Color(1, 1, 1, 0.45 if lit else 0.1), 0.8)
	b.stroke(c + Vector2(-8, -9) * u, c + Vector2(8, -9) * u, col.darkened(0.3) if lit else Color(0.25, 0.23, 0.26), 2.6 * u)
	b.stroke(c + Vector2(0, -10) * u, c + Vector2(0, -18) * u, Color(0.32, 0.24, 0.2) if lit else Color(0.2, 0.18, 0.2), 2.6 * u)
	b.circle(c + Vector2(0, -19.5) * u, 2.4 * u, col if lit else Color(0.3, 0.28, 0.32))
	for i in step:
		b.circle(c + Vector2(-7.5 + i * 3.0, 24) * u, 1.0 * u, UI.GOLD)
