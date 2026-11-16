extends Node2D
## CONTRACTS: tasks for the towers that the Noble gives at a station
## (noble.gd, the station's "noble" stop). One or two can be held at once
## (more as your rank grows: renown.gd RANK_OPENS "contracts"); each is
## tracked in play (a small line at the top of the screen: hud.gd
## status_chips asks chips(), and the Entity's climb log, main.note_event)
## and pays when done: renown, crystals of its tower's kind and, now and
## then, a charm recipe (charms.gd LOCKED) a Rune Artist can then craft.
##
## The kinds (KINDS):
##   reach     reach floor X of a named tower (any climb: it's done the
##             moment you arrive on that floor or higher)
##   slay      slay X of a kind of monster (wherever you meet them)
##   retrieve  a named thing waits on floor X of a named tower: pick it up
##             (walk onto it) and take the stair with it. A fall drops it:
##             it waits on its floor again next time.
## A contract never blocks anything: the retrieved thing lies where you can
## walk to it (reach.gd live_check from the floor's start), off the stair's
## way, and nothing about a floor waits on it.
##
## main.gd owns one node (`main.contracts`): it hears each floor (on_floor),
## each monster slain (on_kill) and each climb's end (on_climb_end), draws
## the thing to retrieve and notices you picking it up. What you hold is
## kept with the climber (renown.gd state "contracts": {"active": [...],
## "offers": [...], "visit", "done", "next_id"}); an old save has none.
## Every word and number is here (and in the Data editor: "Contracts").

const Renown := preload("res://scripts/renown.gd")
const Towers := preload("res://scripts/towers.gd")
const Essence := preload("res://scripts/essence.gd")
const Reach := preload("res://scripts/reach.gd")
const UI := preload("res://scripts/ui.gd")

## The kinds: "label" (a short word for lists), "name" (the contract's
## title: blanks filled in), "goal" (what to do), "status" (the line at the
## top in play), "renown" and "per" (renown: a base, plus this much per floor
## for reach and retrieve, or per two slain for slay), "crystals" and
## "crystals_per" likewise.
static var KINDS := {
	"reach": {"label": "Reach", "name": "Reach floor %d of %s", "goal": "Climb to floor %d of %s, on any climb.",
		"status": "Contract: reach floor %d of %s", "renown": 4, "per": 1, "crystals": 6, "crystals_per": 2},
	"slay": {"label": "Slay", "name": "Slay %d %s", "goal": "Slay %d %s, in any tower. %s has many.",
		"status": "Contract: %s slain %d of %d", "renown": 5, "per": 1, "crystals": 8, "crystals_per": 1},
	"retrieve": {"label": "Retrieve", "name": "Retrieve %s", "goal": "%s lies somewhere on floor %d of %s. Pick it up and take the stair with it.",
		"status": "Contract: find %s on floor %d", "status_held": "Contract: take %s to the stair", "renown": 6, "per": 2, "crystals": 10, "crystals_per": 2},
}

## The numbers: offers at a time; how far past your best a reach contract
## asks (floors), the floors a thing to retrieve waits on, how many a slay
## asks; the chance a contract also teaches a charm recipe; how near you
## walk to pick a thing up; the farthest from the start it may wait.
static var RULES := {
	"offers": 3, "reach_ahead": [1, 2], "reach_lowest": 3, "retrieve_floors": [2, 5], "slay": [5, 10],
	"recipe_chance": 0.3, "reach": 28.0, "near_start": 220.0, "slay_weight": 0.8,
}

## The things to retrieve (placeholder names, the owner's to change).
static var ITEMS := ["the Brass Compass", "a Sealed Letter", "the Silver Locket", "an Old Map Case", "the Climber's Journal", "a Lacquered Box"]

static var TEXT := {
	"taken": "Contract taken: %s",
	"dropped": "Contract given up: %s",
	"done_title": "CONTRACT DONE",
	"done": "%s",
	"deed": "Contract: %s",
	"paid": "+%d %s crystal",
	"recipe": "A charm recipe learned: %s",
	"picked": "Found %s. Take the stair with it.",
	"lost": "%s fell with you. It waits on its floor again.",
	"secured": "%s, safe at the stair",
	"progress": "%s: %d of %d",
	"reward": "Pays: %s",
	"reward_renown": "+%d renown",
	"reward_crystals": "%d %s",
	"reward_recipe": "maybe a charm recipe",
	"full": "You hold as many contracts as you can (%d).",
	"none": "No contracts held. The Noble at a station gives them.",
	"held": "Held",
	"offer": "On offer",
	"locked_kind": "The Noble offers these from the rank of %s",
	"thing": "Contract",
}

var main
var item := {}  # the thing to retrieve on this floor: {"pos", "id", "name", "taken"}
var glow := -1
var t := 0.0


# --- the climber's contracts (renown.gd state "contracts") ----------------------------

static func data(profile) -> Dictionary:
	var c: Dictionary = Renown.state(profile)["contracts"]
	var defaults := {"active": [], "offers": [], "visit": -1, "done": 0, "next_id": 1}
	for k in defaults:
		if not c.has(k) or typeof(c[k]) != typeof(defaults[k]):
			c[k] = defaults[k].duplicate() if defaults[k] is Array else defaults[k]
	return c


static func active(profile) -> Array:
	return data(profile)["active"] if profile != null else []


## How many contracts can be held at once (your rank: RANK_OPENS "contracts" "n").
static func most(profile) -> int:
	var n := 1
	for e in Renown.opened(profile, "contracts"):
		n = maxi(n, int(e.get("n", 1)))
	return n


## The kinds the Noble offers at your rank.
static func kinds_open(profile) -> Array:
	var out: Array = []
	for e in Renown.opened(profile, "contracts"):
		for k in e.get("kinds", []):
			if KINDS.has(String(k)) and not out.has(String(k)):
				out.append(String(k))
	return out


## The Noble's offers this station visit (rolled again each visit).
static func offers(profile) -> Array:
	var c := data(profile)
	var visit := int(Renown.state(profile)["visits"])
	if int(c["visit"]) != visit:
		c["visit"] = visit
		var list: Array = []
		var kinds := kinds_open(profile)
		for i in int(RULES["offers"]):
			if kinds.is_empty():
				break
			var k: String = kinds[i % kinds.size()] if i < kinds.size() else kinds[randi() % kinds.size()]
			var o := roll(profile, k)
			if not o.is_empty():
				list.append(o)
		c["offers"] = list
		profile.save()
	return c["offers"]


## A new contract of a kind (not yet taken).
static func roll(profile, kind: String) -> Dictionary:
	var c := data(profile)
	var tid: String = Towers.ORDER[randi() % Towers.ORDER.size()]
	var best := int(profile.record.get("best", {}).get(tid, 0)) if profile != null else 0
	var k: Dictionary = KINDS.get(kind, {})
	var o := {"id": "c%d" % int(c["next_id"]), "kind": kind, "tower": tid, "floor": 0, "need": 1, "have": 0, "monster": "", "item": "", "carried": false}
	c["next_id"] = int(c["next_id"]) + 1
	var size := 0
	match kind:
		"reach":
			var ahead: Array = RULES["reach_ahead"]
			o["floor"] = clampi(best + randi_range(int(ahead[0]), int(ahead[1])), int(RULES["reach_lowest"]), Towers.SUMMIT)
			size = int(o["floor"])
		"retrieve":
			var fl: Array = RULES["retrieve_floors"]
			var hi := clampi(maxi(best, int(fl[0])), int(fl[0]), int(fl[1]))
			o["floor"] = randi_range(int(fl[0]), hi)
			if o["floor"] == int(Towers.PROVING["floor"]):
				o["floor"] = int(fl[0])
			o["item"] = String(ITEMS[randi() % ITEMS.size()])
			size = int(o["floor"])
		"slay":
			var w: Dictionary = Towers.TOWERS[tid].get("weights", {})
			var pool: Array = w.keys().filter(func(m): return float(w[m]) >= float(RULES["slay_weight"]))
			if pool.is_empty():
				pool = w.keys()
			if pool.is_empty():
				return {}
			o["monster"] = String(pool[randi() % pool.size()])
			var sl: Array = RULES["slay"]
			o["need"] = randi_range(int(sl[0]), int(sl[1]))
			size = int(o["need"]) / 2
	o["renown"] = int(k.get("renown", 4)) + int(k.get("per", 1)) * size
	o["crystals"] = int(k.get("crystals", 6)) + int(k.get("crystals_per", 1)) * size
	o["essence"] = String(Towers.TOWERS[tid].get("essence", "stone"))
	var Charms = load("res://scripts/charms.gd")
	var left: Array = Charms.LOCKED.filter(func(id): return not Charms.recipe_known(profile, String(id)))
	o["recipe"] = String(left[randi() % left.size()]) if not left.is_empty() and randf() < float(RULES["recipe_chance"]) else ""
	return o


## Takes an offer (by id): "" if done, else why not. Saves.
static func take(profile, id: String) -> String:
	var c := data(profile)
	if (c["active"] as Array).size() >= most(profile):
		return TEXT["full"] % most(profile)
	for i in (c["offers"] as Array).size():
		if String(c["offers"][i].get("id", "")) == id:
			var o: Dictionary = c["offers"][i]
			c["offers"].remove_at(i)
			c["active"].append(o)
			Renown._deed(Renown.state(profile), TEXT["taken"] % name_of(o), 0)
			profile.save()
			return ""
	return "?"


## Gives up a contract held (by id). True if it was held.
static func drop(profile, id: String) -> bool:
	var c := data(profile)
	for i in (c["active"] as Array).size():
		if String(c["active"][i].get("id", "")) == id:
			var o: Dictionary = c["active"][i]
			c["active"].remove_at(i)
			Renown._deed(Renown.state(profile), TEXT["dropped"] % name_of(o), 0)
			profile.save()
			return true
	return false


## A contract by id, held or on offer ({} if neither).
static func find(profile, id: String) -> Dictionary:
	var c := data(profile)
	for o in c["active"] + c["offers"]:
		if String(o.get("id", "")) == id:
			return o
	return {}


static func is_held(profile, id: String) -> bool:
	return active(profile).any(func(o): return String(o.get("id", "")) == id)


# --- words -------------------------------------------------------------------------------

static func tower_name(o: Dictionary) -> String:
	return String(Towers.TOWERS.get(String(o.get("tower", "")), {}).get("name", o.get("tower", "")))


static func monster_name(o: Dictionary, plural := true) -> String:
	var n: String = load("res://scripts/bestiary.gd").name_of(String(o.get("monster", "")))
	return (n.to_lower() + ("s" if not n.ends_with("s") else "")) if plural else n


static func name_of(o: Dictionary) -> String:
	var k: Dictionary = KINDS.get(String(o.get("kind", "")), {})
	match String(o.get("kind", "")):
		"reach":
			return String(k["name"]) % [int(o["floor"]), tower_name(o)]
		"slay":
			return String(k["name"]) % [int(o["need"]), monster_name(o)]
		"retrieve":
			return String(k["name"]) % String(o["item"])
	return "?"


static func goal_of(o: Dictionary) -> String:
	var k: Dictionary = KINDS.get(String(o.get("kind", "")), {})
	match String(o.get("kind", "")):
		"reach":
			return String(k["goal"]) % [int(o["floor"]), tower_name(o)]
		"slay":
			return String(k["goal"]) % [int(o["need"]), monster_name(o), tower_name(o)]
		"retrieve":
			var it := String(o["item"])
			return String(k["goal"]) % [it.left(1).to_upper() + it.substr(1), int(o["floor"]), tower_name(o)]
	return ""


## The line in play (and on its tile): how it's going.
static func status_of(o: Dictionary) -> String:
	var k: Dictionary = KINDS.get(String(o.get("kind", "")), {})
	match String(o.get("kind", "")):
		"reach":
			return String(k["status"]) % [int(o["floor"]), String(Towers.TOWERS.get(String(o["tower"]), {}).get("short", o["tower"]))]
		"slay":
			return String(k["status"]) % [monster_name(o).capitalize(), mini(int(o["have"]), int(o["need"])), int(o["need"])]
		"retrieve":
			if bool(o.get("carried", false)):
				return String(k["status_held"]) % String(o["item"])
			return String(k["status"]) % [String(o["item"]), int(o["floor"])]
	return ""


## What it pays, in words: "+8 renown, 12 Air, maybe a charm recipe".
static func reward_text(o: Dictionary) -> String:
	var bits: Array = [TEXT["reward_renown"] % int(o.get("renown", 0)), TEXT["reward_crystals"] % [int(o.get("crystals", 0)), Essence.display(String(o.get("essence", "stone")))]]
	if String(o.get("recipe", "")) != "":
		bits.append(TEXT["reward_recipe"])
	return TEXT["reward"] % ", ".join(bits)


# --- done --------------------------------------------------------------------------------

## A contract is done: off the list, paid (renown, crystals, maybe a
## recipe), and said. Returns the lines said.
static func complete(profile, o: Dictionary, m = null) -> Array:
	var c := data(profile)
	c["active"] = (c["active"] as Array).filter(func(x): return String(x.get("id", "")) != String(o.get("id", "")))
	c["done"] = int(c["done"]) + 1
	var lines: Array = [TEXT["done"] % name_of(o)]
	var kind := String(o.get("essence", "stone"))
	var cr := int(o.get("crystals", 0))
	if cr > 0:
		profile.add_crystal(kind, float(cr))
		lines.append(TEXT["paid"] % [cr, Essence.display(kind)])
	var rec := String(o.get("recipe", ""))
	if rec != "":
		var Charms = load("res://scripts/charms.gd")
		if Charms.learn(profile, rec):
			lines.append(TEXT["recipe"] % Charms.recipe_name(rec))
	var got := Renown.earn(profile, int(o.get("renown", 0)), TEXT["deed"] % name_of(o))  # (said in play by main.gd's Renown.heard)
	profile.save()
	if m != null and is_instance_valid(m):
		m.banner = {"title": TEXT["done_title"], "lines": lines + ([String(got["line"])] if String(got["line"]) != "" else []), "t": 3.2, "logged": true}
		m.note_event("contract", lines[0], KINDS_COLOR)
		for ln in lines.slice(1):
			m.note_event("contract", String(ln), KINDS_COLOR, false)
		m.sfx("clear", 1.15, -3.0, 0.0)
		m.tip("contract_done")
	return lines


const KINDS_COLOR := Color(0.92, 0.8, 0.98)


# --- in play (main.gd) ------------------------------------------------------------------

func _ready() -> void:
	z_index = -1


func _live() -> bool:
	if main == null or main.profile == null or main.on_train or main.in_camp:
		return false
	if main.get("arena") != null and main.arena.on:
		return false
	if main.get("practice") != null and main.practice.on:
		return false
	return not main.first_climb


## A new floor (main.gd _start_floor, after the floor is built): a reach
## contract may be done; a thing carried up the stair is safe; the thing to
## retrieve may wait here.
func on_floor(n: int) -> void:
	_clear_item()
	if not _live():
		return
	var prof = main.profile
	for o in active(prof).duplicate():
		if n <= 1 and bool(o.get("carried", false)):
			o["carried"] = false  # (a new climb: a thing carried when the game closed waits on its floor again)
		match String(o["kind"]):
			"reach":
				if String(main.tower) == String(o["tower"]) and n >= int(o["floor"]):
					complete(prof, o, main)
			"retrieve":
				if bool(o.get("carried", false)):
					main.note_event("contract", TEXT["secured"] % String(o["item"]).capitalize(), KINDS_COLOR)
					complete(prof, o, main)
				elif String(main.tower) == String(o["tower"]) and n == int(o["floor"]) and item.is_empty():
					_place(o)


## Puts the thing to retrieve somewhere you can walk to, away from the start.
func _place(o: Dictionary) -> void:
	var start: Vector2 = main.player_start
	var spots: Array = []
	var info: Array = main.room_info if main.get("room_info") != null else []
	for ri in info:
		var r: Rect2 = ri.get("rect", Rect2())
		if r.size.x > 0.0:
			spots.append(r.get_center())
	if spots.is_empty():
		var room: Rect2 = main.room
		spots = [room.get_center() + Vector2(-260, -120), room.get_center() + Vector2(260, -120), room.get_center() + Vector2(0, -160)]
	var reach: Dictionary = Reach.live_check(main, start) if main.layout_on else {}
	var best := Vector2.INF
	var far := -1.0
	for s in spots:
		var at: Vector2 = main.clear_spot(s, 14.0)
		if main.layout_on and main.is_solid(at):
			continue
		if not reach.is_empty() and reach.get("checked", false) and not Reach.near_reached(reach["reach"], reach["size"], at):
			continue
		if at.distance_to(main.stair_pos) < 60.0:
			continue
		var d := at.distance_to(start)
		if d < float(RULES["near_start"]) and best != Vector2.INF:
			continue
		if d > far:
			far = d
			best = at
	if best == Vector2.INF:
		best = main.walkable_point(start, start + Vector2(0, -160))
	item = {"pos": best, "id": String(o["id"]), "name": String(o["item"]), "taken": false}
	if main.lighting != null:
		glow = main.lighting.add_light(best, 90.0, KINDS_COLOR, 0.5, 0.2)
	main.note_event("contract", status_of(o), KINDS_COLOR, false)
	queue_redraw()


func _clear_item() -> void:
	if glow >= 0 and main != null and main.lighting != null:
		main.lighting.remove_light(glow)
	glow = -1
	item = {}
	queue_redraw()


## A monster slain (main.gd on_enemy_killed, not in the station's arena).
func on_kill(kind: String) -> void:
	if not _live():
		return
	var prof = main.profile
	for o in active(prof).duplicate():
		if String(o["kind"]) == "slay" and String(o["monster"]) == kind:
			o["have"] = int(o["have"]) + 1
			if int(o["have"]) >= int(o["need"]):
				complete(prof, o, main)
			else:
				prof.save()


## The climb ended (main.gd pay_climb): a thing carried is safe if you got
## out alive (a recall, the summit); a fall drops it.
func on_climb_end(fell: bool) -> void:
	if main == null or main.profile == null:
		return
	var prof = main.profile
	for o in active(prof).duplicate():
		if String(o["kind"]) == "retrieve" and bool(o.get("carried", false)):
			if fell:
				o["carried"] = false
				main.note_event("contract", TEXT["lost"] % String(o["item"]).capitalize(), KINDS_COLOR)
				prof.save()
			else:
				complete(prof, o, main)


func _process(delta: float) -> void:
	if item.is_empty() or bool(item.get("taken", false)) or main == null or main.player == null:
		return
	t += delta
	if Engine.get_process_frames() % 4 == 0:
		queue_redraw()
	var p = main.player
	if p.dead or main.climbing or main.camp_choosing:
		return
	if p.global_position.distance_to(item["pos"]) < float(RULES["reach"]) + float(p.radius):
		pick_up()


## Walks onto the thing to retrieve: it's carried (take the stair with it).
func pick_up() -> void:
	if item.is_empty() or bool(item.get("taken", false)):
		return
	item["taken"] = true
	var o := find(main.profile, String(item["id"]))
	if not o.is_empty():
		o["carried"] = true
		main.profile.save()
	var said: String = TEXT["picked"] % String(item["name"])
	main.fx_text(item["pos"] + Vector2(0, -30), String(item["name"]).capitalize(), KINDS_COLOR)
	main.fx_ring(item["pos"], KINDS_COLOR, 50.0, 0.4, 3.0)
	main.sfx("glint", 1.2, -3.0)
	main.note_event("contract", said, KINDS_COLOR)
	main.banner = {"title": TEXT["thing"].to_upper(), "lines": [said], "t": 2.6, "note": true}
	_clear_item()


## The status chips (hud.gd status_chips): one line per contract held.
func chips() -> Array:
	var out: Array = []
	if not _live():
		return out
	for o in active(main.profile):
		out.append({"id": "contract:" + String(o.get("id", "")), "text": status_of(o), "color": Color(0.95, 0.88, 1.0), "edge": KINDS_COLOR, "alpha": 0.9})
	return out


## The thing to retrieve: a small wrapped bundle with a wax seal, glowing.
func _draw() -> void:
	if item.is_empty() or bool(item.get("taken", false)):
		return
	var at: Vector2 = item["pos"]
	var bob := sin(t * 3.0) * 2.0
	var b := UI.Draw.Batch.new()
	b.circle(at + Vector2(0, 6), 11.0, Color(0, 0, 0, 0.3), 16)
	b.circle(at, 18.0 + sin(t * 2.0) * 2.0, Color(KINDS_COLOR, 0.14), 20)
	var c := at + Vector2(0, -4 + bob)
	b.rect(Rect2(c + Vector2(-9, -6), Vector2(18, 12)), Color(0.05, 0.04, 0.06))
	b.rect(Rect2(c + Vector2(-8, -5), Vector2(16, 10)), Color(0.62, 0.48, 0.3))
	b.rect(Rect2(c + Vector2(-1, -5), Vector2(2, 10)), Color(0.85, 0.75, 0.5))
	b.circle(c, 3.0, Color(0.72, 0.18, 0.2), 10)
	b.flush(self)
