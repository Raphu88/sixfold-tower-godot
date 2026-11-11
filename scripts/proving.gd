extends Node2D
## The Proving: floor 6 of every tower (towers.gd PROVING), where the tower
## takes the climber's measure and shows what it is about. It has its own
## fixed layout (not the room planner), one room after another:
##   the ANTECHAMBER, where you start, with two doors north: the Proving,
##     and the Lethal Proving (sealed until you have won the Proving in this
##     tower once; lean on it to go in, knowing that dying there ends the climb);
##   the GAUNTLET, the tower's own trap room (towers.gd "gauntlet"), which
##     shuts behind you; it can always be crossed by timing (traps.gd's
##     protection pass: no tile on the way is never safe);
##   the SENTINEL'S HALL: a champion of the tower's sentinel (towers.gd
##     "sentinel", crowned as enemy.gd's champions are) and its adds; the
##     doors shut until they fall;
##   the BEAST'S SHADOW: a weakened echo of the tower's beast, drawn as a
##     shade; the doors shut until it falls;
##   the RELIQUARY, sealed until the shadow falls: a pedestal offers a choice
##     of three relics (rings and amulets), never shown before you win;
##   and the stair.
## Each stage's door bears a sigil of what waits behind it, never the reward.
##
## LOSING the ordinary Proving isn't death: when the climber's health would
## reach 0, the tower has taken their measure. They are cast down to a fresh
## floor 5, lose part of their unbanked essence and carry a lingering wound
## (less max health) for the next floors, then climb back and face floor 6
## again. Only the Lethal Proving, chosen knowingly, ends the climb.
##
## LATER CLIMBS raise the stakes: every win in a tower (profile.provings)
## raises its Proving's tier (to MAX_TIER): a faster, denser gauntlet, a
## tougher sentinel, a stronger shadow and a better prize. The Lethal Proving
## is LETHAL_STEP tiers above. (Elsewhere difficulty rises only with the floor.)
##
## Every word and number is here (and each tower's picks in towers.gd), so
## it's easy to rename: "the Proving" itself is a placeholder name.

const UI := preload("res://scripts/ui.gd")
const Floors := preload("res://scripts/floors.gd")
const Rooms := preload("res://scripts/rooms.gd")
const Traps := preload("res://scripts/traps.gd")
const Themes := preload("res://scripts/themes.gd")
const Towers := preload("res://scripts/towers.gd")
const Gear := preload("res://scripts/gear.gd")
const Essence := preload("res://scripts/essence.gd")
const Items := preload("res://scripts/items.gd")
const Palette := preload("res://scripts/palette.gd")
const Draw := preload("res://scripts/draw_util.gd")
const EnemyScript := preload("res://scripts/enemy.gd")

## Everything the Proving says.
static var TEXT := {
	"arrive": "Two doors. One forgives, one does not.",
	"arrive_first": "Two doors. The second will open once you have proven yourself here.",
	"harder": "It remembers you. It asks more this time.",
	"door_ordinary": "THE PROVING",
	"door_ordinary_sub": ["Lose, and you are", "cast down to floor %d"],
	"door_lethal": "THE LETHAL PROVING",
	"door_lethal_sub": ["Harder, for a greater prize.", "Die here and the climb ends."],
	"door_sealed_sub": ["Sealed until you have won", "the Proving in this tower"],
	"chose_title": "THE PROVING",
	"chose": "Cross the gauntlet. Best the sentinel. Face the beast's shadow.",
	"chose_safe": "Lose, and the tower only casts you down.",
	"lethal_title": "THE LETHAL PROVING",
	"lethal_ask": "Harder, for a greater prize. Die beyond this door and your climb ends.",
	"lethal_lean": "Lean on the door to go in.",
	"lethal_chose": "There is no mercy past this door.",
	"sealed_title": "SEALED",
	"sealed": "This door opens once you have won the Proving in this tower.",
	"shut_title": "THE OTHER WAY IS SHUT",
	"shut": "You have chosen your door.",
	"prize_sealed_title": "SEALED",
	"prize_sealed": "It opens when the beast's shadow falls.",
	"gauntlet_title": "THE GAUNTLET",
	"gauntlet": "The way behind you shuts. The tower's own traps: time every step.",
	"sentinel_title": "THE SENTINEL",
	"sentinel": "The tower's champion stands in your way.",
	"sentinel_down_title": "THE SENTINEL FALLS",
	"sentinel_down": "The way on opens. Something waits beyond it.",
	"shadow_title": "THE BEAST'S SHADOW",
	"shadow": "An echo of %s. Only an echo.",
	"shadow_bar": "Shadow of %s",
	"won_title": "PROVEN",
	"won": "The tower has seen enough. Claim your prize; the stair is open.",
	"prize_title": "THE PROVING'S PRIZE",
	"prize_sub": "Choose one to take.",
	"crystal": "The sentinel leaves %s",
	"measure_title": "THE TOWER HAS TAKEN YOUR MEASURE",
	"measure": "Not yet. Down you go.",
	"cast_title": "CAST DOWN",
	"cast": "Floor %d. %d%% of your unbanked essence stays behind: you carry %d.",
	"cast_none": "Floor %d. Climb, and face the Proving again.",
	"wound": "A wound lingers: %d%% less health until floor %d.",
	"wound_closes": "Your wound closes",
	"wound_tag": "wounded",
}

## The fixed layout: one room per stage, in order (each joined to the one
## before by a corridor), in tiles on the floor's grid (cells of
## Floors.CELL_TILES). The gauntlet takes the tower's own trap theme.
const LAYOUT := [
	{"stage": "ante", "role": "entrance", "theme": "proving_ante", "cell": Vector2i(0, 2), "pos": Vector2i(1, 30), "size": Vector2i(14, 7), "shape": "rect"},
	{"stage": "gauntlet", "role": "gauntlet", "theme": "", "cell": Vector2i(0, 1), "pos": Vector2i(3, 16), "size": Vector2i(11, 12), "shape": "rect"},
	{"stage": "sentinel", "role": "sentinel", "theme": "proving_sentinel", "cell": Vector2i(0, 0), "pos": Vector2i(1, 2), "size": Vector2i(13, 11), "shape": "pillars"},
	{"stage": "shadow", "role": "shadow", "theme": "proving_shadow", "cell": Vector2i(1, 0), "pos": Vector2i(17, 1), "size": Vector2i(14, 12), "shape": "round"},
	{"stage": "prize", "role": "prize", "theme": "proving_prize", "cell": Vector2i(1, 1), "pos": Vector2i(20, 17), "size": Vector2i(10, 7), "shape": "rect"},
	{"stage": "stair", "role": "stair", "theme": "proving_stair", "cell": Vector2i(1, 2), "pos": Vector2i(18, 30), "size": Vector2i(12, 8), "shape": "rect"},
]
## Where the antechamber's two corridors meet the gauntlet's south wall
## (tiles along it from its west end): the Proving's door, then the Lethal one.
const DOOR_AT := [1, 8]

## The tiers. 0 the first time in a tower; every win there raises it, up to
## MAX_TIER; the Lethal Proving is LETHAL_STEP above.
##   trap_floor   the gauntlet is laid as a trap room of this floor (traps.gd)
##   sentinel_hp  the champion's health, times a champion's own (enemy.gd)
##   adds         how many of the sentinel's adds come with it
##   shadow_hp    the shadow's health, as a share of its beast's on the summit
##   shadow_dmg   its blows, as a share of the beast's on the summit
##   rarity, rank the prize relics' rarity and tempering (gear.gd)
##   storied      how many of the three are Storied pieces (rings and amulets)
##   crystal      the sentinel's crystal, as a share of a vault crystal (wings.gd)
const TIERS := [
	{"trap_floor": 6, "sentinel_hp": 1.0, "adds": 2, "shadow_hp": 0.38, "shadow_dmg": 0.75, "rarity": "rare", "rank": 0, "storied": 0, "crystal": 0.5},
	{"trap_floor": 8, "sentinel_hp": 1.15, "adds": 2, "shadow_hp": 0.45, "shadow_dmg": 0.8, "rarity": "rare", "rank": 1, "storied": 0, "crystal": 0.6},
	{"trap_floor": 10, "sentinel_hp": 1.3, "adds": 3, "shadow_hp": 0.54, "shadow_dmg": 0.85, "rarity": "rare", "rank": 1, "storied": 1, "crystal": 0.7},
	{"trap_floor": 11, "sentinel_hp": 1.45, "adds": 3, "shadow_hp": 0.62, "shadow_dmg": 0.9, "rarity": "rare", "rank": 2, "storied": 1, "crystal": 0.8},
	{"trap_floor": 12, "sentinel_hp": 1.7, "adds": 4, "shadow_hp": 0.75, "shadow_dmg": 1.0, "rarity": "rare", "rank": 3, "storied": 2, "crystal": 1.0},
]
const MAX_TIER := 3
const LETHAL_STEP := 1
## Losing the ordinary Proving: down to this floor, keeping this share of
## the unbanked essence, with this much health; the wound takes this share
## of max health until you have climbed this many stairs (from floor 5:
## until you reach floor 7).
static var CAST_DOWN := {"to": 5, "keep": 0.5, "health": 0.5, "wound": 0.25, "wound_stairs": 2, "pause": 1.6}
## The prize: this many cards; how close you walk to the pedestal.
static var PRIZE := {"choices": 3, "reach": 30.0}
## How long you lean on the Lethal door before it opens (seconds); how
## close you must be inside a room before its stage begins (px in from its edge).
const LEAN := 1.2
const INSIDE := 34.0
const GOLD := Color(1.0, 0.82, 0.4)
const LETHAL_RED := Color(0.95, 0.22, 0.18)
const SHADE := Color(0.62, 0.52, 0.95)

var main
## Off in tests unless a test turns it on (floor 6 is then a planned floor).
var enabled := not Engine.has_meta("sixfold_test")
var on := false  # this floor is the Proving
var plan := {}
var rooms := {}  # stage -> room index
var mode := ""  # "" (not chosen yet), "ordinary" or "lethal"
var tier := 0
var stage := "ante"  # ante, gauntlet, sentinel, shadow, won
var sealed := {}  # stage -> true once its doors have shut
var mobs: Array = []  # the sentinel's fight (champion first)
var sentinel = null
var shadow = null
var prize := {}  # {pos, state: sealed, ready or taken}
var lean_t := 0.0
var lean_frame := -1
var said_t := 0.0  # a door's words aren't repeated until this runs out
var casting := false  # being cast down
var won_climb := false  # won on this climb (the room is new for every climb)
var wound := 0.0  # the lingering wound (a share of max health)
var wound_stairs := 0  # stairs left before it closes
var lights: Array = []
var labels: Node2D  # the doors' words, over the darkness


func _ready() -> void:
	z_index = -3  # on the floor (the pedestal), under everyone
	labels = Node2D.new()
	labels.z_as_relative = false
	labels.z_index = 45
	labels.draw.connect(_draw_labels)
	add_child(labels)


# --- the plan ----------------------------------------------------------------------

## Is floor `n` the Proving on this climb? (Never on the first climb, and
## once won, a fall back to floor 6 finds an ordinary floor there.)
func due(n: int) -> bool:
	return enabled and main != null and not main.first_climb and not won_climb and n == int(Towers.PROVING["floor"])


## The Proving's floor plan for `tower` (towers.gd data), in the form
## Floors.build gives (main.gd builds it the same way), plus "proving" and
## the Proving's own keys. {} if it wouldn't join up (it always does).
static func build_plan(tower: Dictionary) -> Dictionary:
	var C: float = Floors.CELL
	var infos: Array = []
	var themes: Array = []
	for i in LAYOUT.size():
		var L: Dictionary = LAYOUT[i]
		var theme: String = L["theme"] if L["theme"] != "" else String(tower.get("gauntlet", "spikes"))
		var info := {"id": "proving_" + String(L["stage"]), "prefab": false, "rows": Rooms.prepare(Rooms.carve(L["shape"], L["size"])),
			"size": L["size"], "shape": L["shape"], "role": L["role"], "cell": L["cell"], "pos": L["pos"], "parent": i - 1, "theme": theme}
		if i == 1:
			info["link"] = _choice_link(infos[0], info, DOOR_AT[0])
		elif i > 1:
			var link := Floors._link(infos[i - 1], info)
			if link.is_empty():
				return {}
			info["link"] = link
		infos.append(info)
		themes.append(theme)
	# (No chasms here: a fall would be a way out. No puzzle, no wings.)
	var calm := tower.duplicate()
	calm["chasms"] = false
	var p := Floors._build(infos, themes, int(Towers.PROVING["floor"]), calm, {}, [], [])
	# The second corridor from the antechamber: the Lethal Proving's.
	var lethal := _choice_link(infos[0], infos[1], DOOR_AT[1])
	var cr: Rect2i = lethal["corridor"]
	var lr := Rect2(Floors.ORIGIN + Vector2(cr.position) * C, Vector2(cr.size) * C)
	p["walk"].append(lr)
	p["corridors"].append(lr)
	p["posts"] = Floors.doorways(p["rooms"], p["corridors"])
	var ordinary: Dictionary = infos[1]["link"]
	var gates: Array = []  # the gauntlet's end of both corridors
	var doors: Array = []
	for k in 2:
		var link: Dictionary = ordinary if k == 0 else lethal
		var c: Rect2i = link["corridor"]
		var near: Array = [Vector2i(c.position.x, c.end.y - 1), Vector2i(c.position.x + 1, c.end.y - 1)]  # the antechamber's end
		gates.append(link["door"].duplicate())
		doors.append({"tiles": near, "horiz": true, "out": Vector2.DOWN, "room": 1, "style": "proving" if k == 0 else "lethal", "lock": "proving" if k == 0 else "lethal", "lock_id": 0})
		for t in near + link["door"]:
			p["doorways"].append(Rect2(Floors.ORIGIN + Vector2(t) * C, Vector2(C, C)))
	p["room_info"][0]["gates"].append(near_of(lethal))
	p["room_info"][1]["gates"].append(lethal["door"].duplicate())
	# Each stage's door bears its sigil (a sealed reliquary until the shadow falls).
	var styles := {2: "crown", 3: "shade", 4: "plank"}
	for i in styles:
		var link: Dictionary = infos[i]["link"]
		var d := {"tiles": link["door"].duplicate(), "horiz": link["horiz"], "out": link["out"], "room": i, "style": styles[i]}
		if i == 4:
			d["lock"] = "proving_prize"
			d["lock_id"] = 0
		doors.append(d)
	p["doors"] = doors
	p["locks"] = []
	p["monsters"] = []  # (the stages bring their own)
	p["hazard_rooms"] = []  # (the gauntlet's traps are laid when a door is chosen)
	p["safe_rooms"] = []
	p["wet_rooms"] = [p["room_info"][2]["rect"], p["room_info"][3]["rect"]]
	for i in p["room_info"].size():
		if i != 1:
			p["safe_rooms"].append(p["room_info"][i]["rect"])
	p["proving"] = true
	p["gauntlet_gates"] = gates
	p["prize"] = p["room_info"][4]["rect"].get_center()
	p["stages"] = {}
	for i in LAYOUT.size():
		p["stages"][LAYOUT[i]["stage"]] = i
	return p


## A corridor from the antechamber (south) up to the gauntlet's south wall,
## `at` tiles along it, in the form Floors._link gives.
static func _choice_link(ante: Dictionary, g: Dictionary, at: int) -> Dictionary:
	var gp: Vector2i = g["pos"]
	var gs: Vector2i = g["size"]
	var x := gp.x + at
	var y0 := gp.y + gs.y
	var ap: Vector2i = ante["pos"]
	return {"corridor": Rect2i(x, y0, 2, ap.y - y0), "door": [Vector2i(x, y0), Vector2i(x + 1, y0)], "horiz": true,
		"out": Vector2.DOWN, "side_p": 0, "side_c": 1}


## The antechamber's end of a choice corridor (its tiles).
static func near_of(link: Dictionary) -> Array:
	var c: Rect2i = link["corridor"]
	return [Vector2i(c.position.x, c.end.y - 1), Vector2i(c.position.x + 1, c.end.y - 1)]


## main.gd's plan for this floor.
func make_plan() -> Dictionary:
	return build_plan(main.tower_data())


# --- a new floor ------------------------------------------------------------------------

## Every new floor (main._start_floor, after it's built): the Proving sets
## itself up on its own floor and forgets itself elsewhere.
func setup(p: Dictionary) -> void:
	for id in lights:
		main.lighting.remove_light(id)
	lights.clear()
	on = p.get("proving", false)
	plan = p
	mode = ""
	stage = "ante"
	sealed = {}
	mobs = []
	sentinel = null
	shadow = null
	prize = {}
	lean_t = 0.0
	said_t = 0.0
	if not on:
		rooms = {}
		queue_redraw()
		labels.queue_redraw()
		return
	rooms = p["stages"]
	main.ward = true  # the stair opens when the shadow falls
	main.cleared = true  # (no gong: nothing was here to fight)
	var dv = main.door_view
	dv.lock_rooms.clear()  # (the stages shut their own doors)
	if not lethal_open():
		for d in dv.list:
			if d["lock"] == "lethal":
				d["lock"] = "lethal_sealed"
		dv.queue_redraw()
	prize = {"pos": p["prize"], "state": "sealed"}
	# A little light on each door's words, and the shadow's room waits, faintly lit.
	for d in dv.list:
		if d["lock"] in ["proving", "lethal", "lethal_sealed"]:
			var col := GOLD if d["lock"] == "proving" else LETHAL_RED
			lights.append(main.lighting.add_light(d["rect"].get_center() + Vector2(0, 40), 90.0, col, 0.55 if d["lock"] != "lethal_sealed" else 0.3, 0.2))
	lights.append(main.lighting.add_light(main.room_info[rooms["shadow"]]["rect"].get_center(), 160.0, SHADE, 0.35, 0.1))
	queue_redraw()
	labels.queue_redraw()


## The banner on arriving at floor 6 by the stair (main._arrive): `lines`
## are the stair's own (rested, banked...).
func arrival_banner(lines: Array) -> Dictionary:
	var said: Array = ["Floor %d" % main.floor_num, Towers.PROVING["line"]]
	said.append(TEXT["arrive"] if lethal_open() else TEXT["arrive_first"])
	if ordinary_tier() > 0:
		said.append(TEXT["harder"])
	if lethal_open():
		main.tip("proving_lethal")
	return {"title": String(Towers.PROVING["name"]).to_upper(), "lines": said + lines, "t": 4.5}


## Wins in this tower, and what they make of this climb's Proving.
func wins() -> int:
	return main.profile.proving_wins(main.tower)


func lethal_open() -> bool:
	return wins() > 0


func ordinary_tier() -> int:
	return mini(wins(), MAX_TIER)


func tier_data() -> Dictionary:
	return TIERS[clampi(tier, 0, TIERS.size() - 1)]


# --- choosing a door ----------------------------------------------------------------------

## A locked door bumped (doors.gd): the Proving's own. True if it was one.
func bump(d: Dictionary) -> bool:
	if not on:
		return false
	match String(d["lock"]):
		"proving":
			choose("ordinary")
		"lethal":
			var f := Engine.get_process_frames()
			if f - lean_frame > 3:
				lean_t = 0.0
			lean_frame = f
			lean_t += get_process_delta_time()
			_say({"title": TEXT["lethal_title"], "lines": [TEXT["lethal_ask"], TEXT["lethal_lean"]], "t": 2.5}, "lethal")
			if lean_t >= LEAN:
				choose("lethal")
		"lethal_sealed":
			_say({"title": TEXT["sealed_title"], "lines": [TEXT["sealed"]], "t": 2.5}, "sealed")
		"proving_shut":
			_say({"title": TEXT["shut_title"], "lines": [TEXT["shut"]], "t": 2.0}, "shut")
		"proving_prize":
			_say({"title": TEXT["prize_sealed_title"], "lines": [TEXT["prize_sealed"]], "t": 2.0}, "prize")
		_:
			return false
	return true


## A banner for a door, not repeated every frame you lean on it.
func _say(b: Dictionary, key: String) -> void:
	if main.banner.get("door", "") == key:
		return
	b["door"] = key
	main.banner = b
	main.sfx("hit_armor", 0.55, -6.0, 0.0)


## Takes the Proving (`m` "ordinary") or the Lethal Proving ("lethal"):
## the gauntlet's traps are laid for it, its door opens and the other bars.
func choose(m: String) -> void:
	if not on or mode != "":
		return
	if m == "lethal" and not lethal_open():
		return
	mode = m
	tier = ordinary_tier() + (LETHAL_STEP if m == "lethal" else 0)
	lay_gauntlet()
	var dv = main.door_view
	for d in dv.list:
		if d["lock"] in ["proving", "lethal", "lethal_sealed"]:
			var mine: bool = (d["lock"] == "proving") == (m == "ordinary")
			if mine:
				d["lock"] = ""
				dv.open_door(d)
			else:
				d["lock"] = "proving_shut"
	dv.queue_redraw()
	for id in lights:
		main.lighting.remove_light(id)
	lights.clear()
	lights.append(main.lighting.add_light(main.room_info[rooms["shadow"]]["rect"].get_center(), 160.0, SHADE, 0.35, 0.1))
	if m == "lethal":
		main.banner = {"title": TEXT["lethal_title"], "lines": [TEXT["lethal_chose"]], "t": 3.0}
		main.sfx("warn_knight", 0.5, 0.0, 0.0)
		main.shake(5.0)
	else:
		main.banner = {"title": TEXT["chose_title"], "lines": [TEXT["chose"], TEXT["chose_safe"]], "t": 3.2}
		main.sfx("warn_knight", 0.8, -4.0, 0.0)
	main.tip("proving")
	labels.queue_redraw()


## The gauntlet's set piece (the tower's trap room theme), laid as on the
## tier's trap floor, then the protection pass: a way through by timing.
func lay_gauntlet() -> void:
	var ctx: Dictionary = Traps.context(plan)
	var gi: int = rooms["gauntlet"]
	var theme: String = main.room_themes[gi]
	var list: Array = Traps.build_theme(ctx, gi, theme, int(tier_data()["trap_floor"]))
	Traps._rehaz(ctx, list)
	Traps.ensure_passable(ctx, list)
	main.traps = list
	main.trap_view.floor_marks = {"paths": ctx["paths"], "decor": ctx["decor"]}
	main.trap_view.reset()


# --- the stages ---------------------------------------------------------------------------

func _process(delta: float) -> void:
	if not on or main == null or main.player == null:
		return
	var p = main.player
	if p.dead or main.climbing or casting:
		return
	var pos: Vector2 = p.global_position
	if mode != "":
		if not sealed.has("gauntlet") and _inside("gauntlet", pos) and _clear(plan["gauntlet_gates"]):
			_seal_gauntlet()
		if not sealed.has("sentinel") and _inside("sentinel", pos) and _clear(main.room_info[rooms["sentinel"]]["gates"]):
			_begin_sentinel()
		if sealed.has("sentinel") and not sealed.has("sentinel_done") and mobs.all(func(e): return not is_instance_valid(e) or e.dead):
			sealed["sentinel_done"] = true
			_reopen("sentinel", {"title": TEXT["sentinel_down_title"], "lines": [TEXT["sentinel_down"]], "t": 2.6})
		if not sealed.has("shadow") and sealed.has("sentinel_done") and _inside("shadow", pos) and _clear(main.room_info[rooms["shadow"]]["gates"]):
			_begin_shadow()
	if prize.get("state", "") == "ready" and pos.distance_to(prize["pos"]) < float(PRIZE["reach"]) + p.radius:
		prize["state"] = "taken"
		main.offer_vault(prize_choices(), TEXT["prize_title"], [TEXT["prize_sub"]])
		queue_redraw()
	if prize.get("state", "") == "ready" and Engine.get_process_frames() % 2 == 0:
		queue_redraw()  # (the prize glows)


func _inside(st: String, pos: Vector2) -> bool:
	return main.room_info[rooms[st]]["rect"].grow(-INSIDE).has_point(pos)


## No body stands in these doorways (so they can shut).
func _clear(gates: Array) -> bool:
	var C: float = Floors.CELL
	for g in gates:
		for t in g:
			var r := Rect2(Floors.ORIGIN + Vector2(t) * C, Vector2(C, C))
			if r.grow(main.player.radius).has_point(main.player.global_position):
				return false
			for e in main.enemies():
				if r.grow(e.radius).has_point(e.global_position):
					return false
	return true


## Shuts a room's doorways (doors.gd's lock-in bars); `hold` keeps them
## shut whatever happens, else they open when `foes` have fallen.
func _shut(st: String, gates: Array, foes: Array, hold := false) -> void:
	sealed[st] = true
	var lr := {"state": "armed", "gates": gates, "bodies": [], "mobs": [], "t": 0.0, "hold": hold}
	main.door_view.lock_rooms[rooms[st]] = lr
	main.door_view._shut(lr, foes)


## Opens a stage's shut doors (if they're still shut) with its own banner.
func _reopen(st: String, b: Dictionary) -> void:
	var lr: Dictionary = main.door_view.lock_rooms.get(rooms[st], {})
	if lr.get("state", "") == "shut":
		main.door_view._reopen(lr)
	main.banner = b


func _seal_gauntlet() -> void:
	stage = "gauntlet"
	_shut("gauntlet", plan["gauntlet_gates"], [], true)
	main.banner = {"title": TEXT["gauntlet_title"], "lines": [TEXT["gauntlet"]], "t": 3.0}


func _begin_sentinel() -> void:
	stage = "sentinel"
	var t := tier_data()
	var tw: Dictionary = main.tower_data()
	var rect: Rect2 = main.room_info[rooms["sentinel"]]["rect"]
	var pp: Vector2 = main.player.global_position
	var away := (rect.get_center() - pp).normalized()
	if away == Vector2.ZERO:
		away = Vector2.UP
	var at: Vector2 = rect.get_center() + away * minf(rect.size.x, rect.size.y) * 0.22
	var e = EnemyScript.new()
	e.setup(String(tw.get("sentinel", "knight")), main)
	e.make_champion()
	var tough: Vector2 = Floors.toughness(main.floor_num)
	e.max_hp *= tough.x * float(t["sentinel_hp"])
	e.hp = e.max_hp
	e.dmg *= tough.y
	e.position = main.clear_spot(at, e.radius * 1.4)
	e.state_t = 0.8
	main.add_child(e)
	e.wake()
	sentinel = e
	mobs = [e]
	var n := int(t["adds"])
	for k in n:
		var side := away.orthogonal() * (1.0 if k % 2 == 0 else -1.0)
		var spot: Vector2 = at + side * (90.0 + 30.0 * (k / 2)) - away * 30.0 * (k / 2)
		var a = main.spawn_enemy(String(tw.get("sentinel_adds", "slime")), main.walkable_point(at, spot, 16.0))
		a.wake()
		mobs.append(a)
	main.fx_burst(at, Vector2.UP, GOLD, 26, 200.0)
	main.fx_ring(at, GOLD, 70.0, 0.5, 4.0)
	main.light_flash(at, GOLD, 1.8, 1.8, 0.5)
	_shut("sentinel", main.room_info[rooms["sentinel"]]["gates"], mobs)
	main.banner = {"title": TEXT["sentinel_title"], "lines": [TEXT["sentinel"]], "t": 3.0}
	main.shake(8.0)


func _begin_shadow() -> void:
	stage = "shadow"
	var t := tier_data()
	var tw: Dictionary = main.tower_data()
	var rect: Rect2 = main.room_info[rooms["shadow"]]["rect"]
	var pp: Vector2 = main.player.global_position
	var at: Vector2 = rect.get_center() + (rect.get_center() - pp).normalized() * minf(rect.size.x, rect.size.y) * 0.2
	var kind := String(tw.get("beast_kind", "gryphon"))
	shadow = make_shadow(kind, t)
	shadow.position = main.clear_spot(at, shadow.radius)
	main.add_child(shadow)
	shadow.wake()
	lights.append(main.lighting.add_light(at, 120.0, SHADE, 0.5, 0.25, shadow))
	main.fx_burst(at, Vector2.UP, SHADE, 30, 220.0)
	main.fx_ring(at, SHADE, 90.0, 0.6, 4.0)
	main.light_flash(at, SHADE, 2.0, 2.0, 0.6)
	_shut("shadow", main.room_info[rooms["shadow"]]["gates"], [shadow])
	main.banner = {"title": TEXT["shadow_title"], "lines": [TEXT["shadow"] % main.beast_name()], "t": 3.2}
	main.sfx("shadow_rise", 1.0, 0.0, 0.0)
	main.shake(9.0)


## The shadow of beast `kind` for tier data `t` (call before adding it):
## its beast's summit health and blows, scaled down; it calls no help and
## (the Firebird's) doesn't rise again.
func make_shadow(kind: String, t: Dictionary):
	var e = EnemyScript.new()
	e.setup(kind, main)
	e.shade = true
	e.called_flock = true
	e.reborn = true
	var top: Vector2 = Floors.toughness(int(main.tower_data().get("summit", Towers.SUMMIT)))
	e.max_hp *= top.x * float(t["shadow_hp"])
	e.hp = e.max_hp
	e.dmg *= top.y * float(t["shadow_dmg"])
	return e


## A monster fell (main.on_enemy_killed): the sentinel leaves a crystal;
## the shadow's fall wins the Proving.
func on_enemy_killed(e) -> void:
	if not on:
		return
	if e == sentinel:
		var kind: String = main.tower_data()["essence"]
		var amount := roundf(main.wings.crystal_amount() * float(tier_data()["crystal"]))
		main.profile.add_crystal(kind, amount)
		main.profile.save()
		var name: String = Items.CRYSTAL["name"] % Essence.display(kind)
		main.fx_text(e.global_position + Vector2(0, -50), TEXT["crystal"] % name, Essence.color(kind))
	if e == shadow:
		_win()


## The shadow fell: the win is recorded, the reliquary and the stair open.
func _win() -> void:
	stage = "won"
	won_climb = true
	main.profile.note_proving(main.tower)
	main.profile.save()
	var dv = main.door_view
	for d in dv.list:
		if d["lock"] == "proving_prize":
			d["lock"] = ""
			dv.open_door(d)
	main.ward = false
	main.stair_open = true
	main.room_view.stair_open = true
	prize["state"] = "ready"
	lights.append(main.lighting.add_light(prize["pos"], 120.0, GOLD, 0.75, 0.25))
	var won_lines: Array = [TEXT["won"]]
	var raised: String = main.proving_raise()  # (one of your marks grows a step)
	if raised != "":
		won_lines.append(raised)
	_reopen("shadow", {"title": TEXT["won_title"], "lines": won_lines, "t": 3.5})
	main.sfx("clear", 0.8, -2.0, 0.0)
	main.fx_ring(main.stair_pos, GOLD, 80.0, 0.6, 4.0)
	queue_redraw()


## The prize's cards (main.offer_vault): three relics, rings and amulets, of
## the tier's rarity and tempering, some of them Storied pieces.
func prize_choices() -> Array:
	var t := tier_data()
	var rank := int(t["rank"])
	var out: Array = []
	var storied: Array = Gear.NAMED_ORDER.filter(func(n): return Gear.NAMED[n]["rarity"] == "storied" and Gear.slot_of(Gear.NAMED[n]["base"]) in ["ring", "amulet"])
	storied.shuffle()
	for n in storied.slice(0, int(t["storied"])):
		var g := Gear.make_named(n)
		out.append(Gear.make(g["base"], g["rarity"], g["traits"], rank, n))
	var bases: Array = Gear.PIECE_ORDER.filter(func(b): return Gear.slot_of(b) in ["ring", "amulet"] and out.all(func(g): return g["base"] != b))
	bases.shuffle()
	# A ring and an amulet at the least.
	bases.sort_custom(func(a, b): return Gear.slot_of(a) < Gear.slot_of(b))
	var order: Array = []
	var rings: Array = bases.filter(func(b): return Gear.slot_of(b) == "ring")
	var amulets: Array = bases.filter(func(b): return Gear.slot_of(b) == "amulet")
	while not rings.is_empty() or not amulets.is_empty():
		if not amulets.is_empty():
			order.append(amulets.pop_back())
		if not rings.is_empty():
			order.append(rings.pop_back())
	for b in order:
		if out.size() >= int(PRIZE["choices"]):
			break
		var r := String(t["rarity"])
		if Gear.rarity_rank(Gear.natural_rarity(b)) > Gear.rarity_rank(r):
			r = Gear.natural_rarity(b)
		out.append(Gear.make(b, r, Gear.roll_traits(b, r), rank))
	out.shuffle()
	return out.map(func(g): return "gear:" + Gear.code(g))


# --- losing ---------------------------------------------------------------------------

## The climber's health would reach 0 (player.gd, when nothing else saves
## them): in the ordinary Proving the tower casts them down instead. True if
## it did (they stay at 1 health).
func spare() -> bool:
	if not on or mode == "lethal" or main.first_climb:
		return false
	if casting:
		return true  # (already on the way down)
	casting = true
	var p = main.player
	p.hp = maxf(p.hp, 1.0)
	p.iframes = 99.0
	p.set_physics_process(false)
	main.climbing = true
	for e in main.enemies():
		e.set_physics_process(false)
	main.banner = {"title": TEXT["measure_title"], "lines": [TEXT["measure"]], "t": float(CAST_DOWN["pause"]) + 0.8}
	main.sfx("warn_knight", 0.4, 0.0, 0.0)
	main.light_flash(p.global_position, SHADE, 2.0, 2.0, 0.6)
	main.shake(6.0)
	var tw := create_tween()
	tw.tween_interval(float(CAST_DOWN["pause"]))
	tw.tween_property(main, "fade", 1.0, 0.45)
	tw.tween_callback(cast_down)
	tw.tween_interval(0.25)
	tw.tween_property(main, "fade", 0.0, 0.5)
	tw.tween_callback(func(): main.climbing = false)
	return true


## Down to a fresh floor 5: part of the unbanked essence is lost and a wound
## lingers (tests call this straight after spare()).
func cast_down() -> void:
	if not casting:
		return
	var to := int(CAST_DOWN["to"])
	var kept := 0.0
	for k in main.run_essence.keys():
		main.run_essence[k] = float(main.run_essence[k]) * float(CAST_DOWN["keep"])
		kept += float(main.run_essence[k])
	main.run_flow *= float(CAST_DOWN["keep"])  # (the secret essence carried, likewise)
	wound = float(CAST_DOWN["wound"])
	wound_stairs = int(CAST_DOWN["wound_stairs"])
	var p = main.player
	p.wound = wound
	main._start_floor(to)
	casting = false
	p.hp = p.max_health() * float(CAST_DOWN["health"])
	p.iframes = 1.5
	p.poison_t = 0.0
	p.set_physics_process(true)
	main.profile.note("cast_down")
	var lost_pct := int(round((1.0 - float(CAST_DOWN["keep"])) * 100.0))
	var lines: Array = [TEXT["cast"] % [to, lost_pct, int(round(kept))] if kept >= 1.0 else TEXT["cast_none"] % to]
	lines.append(TEXT["wound"] % [int(round(wound * 100.0)), to + wound_stairs])
	main.banner = {"title": TEXT["cast_title"], "lines": lines, "t": 4.0}
	main.tip("proving_wound")
	main.sfx("hurt", 0.6, -4.0, 0.0)


## A stair climbed (main._arrive): the wound heals a stair at a time.
## Returns lines for the stair's banner.
func on_stair() -> Array:
	if wound_stairs <= 0:
		return []
	wound_stairs -= 1
	if wound_stairs > 0:
		return []
	wound = 0.0
	main.player.wound = 0.0
	return [TEXT["wound_closes"]]


## A short word for the HUD and the climber screen while wounded, else "".
func wound_text() -> String:
	if wound <= 0.0:
		return ""
	return "%s: -%d%% health" % [TEXT["wound_tag"], int(round(wound * 100.0))]


# --- drawing ------------------------------------------------------------------------------

func _draw() -> void:
	if not on or prize.is_empty():
		return
	var b := Draw.Batch.new()
	main.wings._draw_pedestal(b, prize["pos"], prize["state"] == "ready", Time.get_ticks_msec() * 0.001)
	b.flush(self)


## The words under the antechamber's two doors (over the darkness, so they
## read from across the room), until a door is chosen.
func _draw_labels() -> void:
	if not on or mode != "" or main.door_view == null:
		return
	var font: Font = UI.font("inscription")  # (the door's words are written there; its name is a label)
	for d in main.door_view.list:
		var lock: String = d["lock"]
		if not lock in ["proving", "lethal", "lethal_sealed"]:
			continue
		var c: Vector2 = d["rect"].get_center() + Vector2(0, 36)
		var title: String = TEXT["door_ordinary"] if lock == "proving" else TEXT["door_lethal"]
		var subs: Array = TEXT["door_ordinary_sub"] if lock == "proving" else (TEXT["door_lethal_sub"] if lock == "lethal" else TEXT["door_sealed_sub"])
		var col := GOLD if lock == "proving" else (LETHAL_RED.lightened(0.25) if lock == "lethal" else Color(0.7, 0.6, 0.62))
		var w := 220.0
		UI.draw_label(labels, c + Vector2(-w / 2.0, 0), title, 14, col, HORIZONTAL_ALIGNMENT_CENTER, w, 4, Color(0, 0, 0, 0.85))
		for i in subs.size():
			var line: String = String(subs[i]) % int(CAST_DOWN["to"]) if "%d" in String(subs[i]) else String(subs[i])
			var at := c + Vector2(-w / 2.0, 15.0 + 13.0 * i)
			labels.draw_string_outline(font, at, line, HORIZONTAL_ALIGNMENT_CENTER, w, 12, 3, Color(0, 0, 0, 0.85))
			labels.draw_string(font, at, line, HORIZONTAL_ALIGNMENT_CENTER, w, 12, Color(0.92, 0.9, 0.86))
