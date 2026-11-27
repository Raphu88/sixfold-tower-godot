extends Node2D
## The station's arena (main.gd owns one: `main.arena`): where the
## Training's lessons and medal drills and the tournament's brackets are
## fought (stations.gd holds what each one is). It works like the practice
## room (practice.gd): the climber steps off the train into an open room of
## the event's tower, and nothing done there is kept (profile.saving is off)
## except the result, which is written to the save as the climber goes back
## (stations.gd apply_result) before the scene starts afresh on the train,
## with the station's page open on the stop it was begun from.
##
##   basics    basic training, ONE SESSION (tutorial.gd runs it): every way
##             to move, attack and parry, step by step in one sitting, each
##             step waiting until it's done; left part way, the place is kept
##   lessons   one lesson, hands on, with the Entity's word as it begins:
##             posts to walk to, rolls, parries on the glint, an item used
##             from the belt, a spell on a dummy, a state cured, a cracked
##             wall broken, the floor's task (braziers) done
##   drills    a goal and a score (parries, kills against the clock, hits
##             taken among archers, posts touched in order, the most
##             dummies one cast hits); foes are kept topped up and hit
##             softly; the score earns a medal
##   brackets  three rounds against other climbers (rival.gd: they fight as
##             climbers do, with marks, and yield instead of dying; one
##             round may be your own reflection), the tournament master's
##             word between rounds; health and marks are made whole between
##   advanced  advanced and mark training (training.gd): lessons too, plus
##             a crowd to fell, creatures to strike with spells, a sparring
##             rival who yields
##   first     a new climber's first tournament (training.gd FIRST): two
##             rounds of the home station's starter monsters, then a human
##             champion with no marks; the Grace comes win or lose
##   (A bracket at a Tournament Manager's location (tournaments.gd) has its
##   layout's pillars, its hazards round the edge and its creatures first.
##   The essence gathered in here, at the usual amounts, goes with the result
##   for training.gd to settle a share of; and what each body part did.)
##   duel      (from the Dining car: dining.gd) one climber, rival.gd's
##             fighter, in the Arena car (arena_car.gd, laid over the room);
##             first to yield loses, nobody dies; the stake and your history
##             are written by dining.gd apply_duel, and you come back to the
##             Dining car
## A fall never ends anything here: the arena spares you (main.gd
## proving_spare) and the event is lost. The pause menu can give up. Words
## and numbers are in stations.gd (TEXT).

const Stations := preload("res://scripts/stations.gd")
const Dummy := preload("res://scripts/dummy.gd")
const Floors := preload("res://scripts/floors.gd")
const Towers := preload("res://scripts/towers.gd")
const UI := preload("res://scripts/ui.gd")
const EnemyScript := preload("res://scripts/enemy.gd")
const Reactions := preload("res://scripts/reactions.gd")
const Bonds := preload("res://scripts/bonds.gd")
const Dining := preload("res://scripts/dining.gd")
const ArenaCar := preload("res://scripts/arena_car.gd")
const Training := preload("res://scripts/training.gd")
const Tournaments := preload("res://scripts/tournaments.gd")
const Gear := preload("res://scripts/gear.gd")
const Essence := preload("res://scripts/essence.gd")
const Weapons := preload("res://scripts/weapons.gd")
const Tutorial := preload("res://scripts/tutorial.gd")

## How long the result shows before going back (real seconds), and the gap
## between rounds.
const RESULT_WAIT := 2.4
const ROUND_GAP := 2.2
## A post is touched within this distance; a cast's hits count for this long.
const POST_REACH := 30.0
const CAST_WINDOW := 1.0
## A drill's fallen foe is replaced after this long.
const REFILL := 0.9
## The cracked wall lesson's room: the grid cell of the crack (the hall's
## top wall), and the open floor below it (cells): a low hall, so the crack
## is in sight from where you start, on a phone too.
const WALL_CELL := Vector2i(14, 5)
const WALL_FLOOR := Rect2i(2, 6, 24, 6)

## Going back: the station's page opens on this once the scene starts
## afresh ({station, stop, pick, lines}).
static var reopen := {}

var main
var on := false
var ev := {}  # the event (stations.gd event)
var t := 0.0  # seconds since it began
var done := false
var done_at := 0  # msec the result began showing
var result := {}  # what's written to the save (stations.gd apply_result)
var parries := 0
var kills := 0
var mirrors := 0
var hits0 := 0
var post := 0
var posts: Array = []
var best_cast := 0
var cast_left := 0.0
var cast_seen := {}
var cast_hits := {}  # dummy -> hits_taken when the window opened
var spells0 := 0
var dummies: Array = []
var refill_t := 0.0
var rolls := 0
var rolling := false
var items0 := 0
var used := 0
# The tournament: the round being fought, its opponent, rounds won.
var round_i := 0
var rounds_won := 0
var opponents: Array = []  # a rival record per round ({} for your reflection)
var opp = null
var opp_name := ""
var round_wait := 0.0
var _was_saving := true
var _view: Control
var duel_body = null  # a duel from the Dining car: the climber you're fighting (rival.gd)
var car_view = null  # ...and the Arena car round the room (arena_car.gd)
# Training and tournaments (training.gd, tournaments.gd): jumps, blows and
# shots landed, perfect parries, creatures struck by spells, a sparring
# rival; a monster round's foes; the essence gathered (the usual amounts:
# training.gd settles its share); the weapon each blow came from, the
# armour worn, and whether any damage was taken (the first tournament).
var jumps := 0
var jumping := false
var struck := 0
var _dummy_hits := 0
var perfects := 0
var foes_hit := 0
var spar_body = null
var round_mobs: Array = []
var gathered := {}
var weapons_used := {}
var armor_base := ""
var hurt := false
var hp_last := 0.0
var _soak0 := {}
var _csoak0 := {}
var _worn0 := {}
var tut = null  # basic training's one session (tutorial.gd), while it runs


## Begins an event (stations.gd event): the fee is paid first (kept even if
## the game is closed), then the climber steps into the arena. "" if begun,
## else why not.
func start(e: Dictionary) -> String:
	if on or main == null or main.player == null or main.profile == null:
		return "?"
	var prof = main.profile
	var type := String(e.get("type", ""))
	var duel := type == "duel"  # (a duel from the Dining car: no fee, nothing to unlock)
	var why := Stations.why_not(prof, type, String(e.get("id", "")), String(e.get("station", ""))) if not duel else ""
	if why != "":
		return why
	var fee := Stations.fee(prof, type, String(e["id"])) if not duel else 0
	if fee > 0:
		var fk := Stations.fee_kind(prof, type, String(e["id"]))
		if fk == "any":
			var paid: Dictionary = prof.spend_any(float(fee))
			if paid.is_empty():
				return Stations.TEXT["needs_fee"] % fee
		elif not prof.spend(fk, float(fee)):  # (training's fee: crystals of the essence that fits it)
			return Training.TEXT["needs_kind"] % [fee, Essence.display(fk)]
		prof.save()
	on = true
	ev = e
	t = 0.0
	done = false
	result = {}
	parries = 0
	kills = 0
	mirrors = 0
	post = 0
	best_cast = 0
	cast_left = 0.0
	cast_seen = {}
	refill_t = 0.0
	rolls = 0
	rolling = false
	used = 0
	round_i = 0
	rounds_won = 0
	opponents = []
	opp = null
	opp_name = ""
	round_wait = 1.0
	jumps = 0
	jumping = false
	struck = 0
	_dummy_hits = 0
	perfects = 0
	foes_hit = 0
	spar_body = null
	round_mobs = []
	gathered = {}
	weapons_used = {}
	hurt = false
	tut = null
	_soak0 = main.run_soak.duplicate()  # (what each body part does in here is the result's: training.gd)
	_csoak0 = main.climb_soak.duplicate()
	main.run_soak = {}
	_worn0 = main.soak_worn.duplicate()
	main.soak_worn = {}  # (fading starts fresh in here: part_soak.gd)
	if not main.on_hit.is_connected(_on_hit):
		main.on_hit.connect(_on_hit)
	_was_saving = prof.saving
	prof.saving = false  # (nothing done in here is kept but the result)
	var m = main.menu
	main.on_train = false
	main.choosing_tower = false
	main.in_camp = false
	if m != null and m.is_open():
		m.close()
	var tw := String(ev.get("tower", main.tower))
	main.tower = tw if Towers.TOWERS.has(tw) else Towers.ORDER[0]
	main._apply_tower_look()
	main._start_floor(1)  # (with this room's plan: plan())
	main.cleared = true  # (no gong between rounds)
	main.ward = true  # (and the stair never opens)
	main.stair_open = false
	main.room_view.stair_open = false
	if type == "tourney" and String(ev.get("hazard", "")) != "" and main.trap_view != null:
		# The Tournament Manager's location lays its hazards round the edge.
		main.traps = Tournaments.hazards(String(ev.get("station", "")), main.OPEN_ROOM, maxi(2, int(ev.get("floor", 2))))
		main.trap_view.reset()
	var p = main.player
	p.dead = false
	p.hp = p.max_health()
	p.rest_fatigue()  # (made whole between rounds: fatigue too)
	p.sta = p.max_sta
	p.poison_t = 0.0
	p.set_physics_process(true)
	_fill_marks(p)
	hp_last = p.hp
	armor_base = Gear.base_id(p.gear.get("armor", {}))
	hits0 = p.hits_taken
	spells0 = p.spells_cast
	if not p.on_parry.is_connected(_on_parry):
		p.on_parry.connect(_on_parry)
	if duel:
		_setup_duel()
		main.banner = {"title": String(Dining.TEXT["arena_banner"]), "lines": [String(Dining.TEXT["arena_line"]) % String(ev.get("rival", {}).get("name", ""))], "t": 3.0}
		main.sfx("warn_knight", 1.1, -2.0, 0.0)
		main.tip("arena_car")
		z_index = 2
		_add_view()
		queue_redraw()
		return ""
	var line := ""
	match type:
		"lesson":
			_setup_lesson()
			line = Stations.lesson_goal(String(ev["id"]))
			main.GuideScript.say_text(String(ev.get("say", "")), true)  # (the Entity says how, as it begins)
		"advanced":
			_setup_lesson()
			line = Training.lesson_goal(String(ev["id"]))
			main.GuideScript.say_text(String(ev.get("say", "")), true)
		"basics":
			tut = Tutorial.new()
			tut.begin(self, int(ev.get("from", 0)))  # (the Entity says each step as it begins)
			line = String(Tutorial.TEXT["line"])
		"drill":
			_setup_drill()
			line = Stations.drill_goal(String(ev["id"]))
		"tourney":
			_setup_tourney()
			line = Tournaments.line("here")
		"first":
			_setup_tourney()
			line = String(Training.TEXT["first_line"])
			main.tip("first_tournament")
	var eyebrow: String = String(Stations.TEXT.get("start_" + type, Training.TEXT.get("start_" + type, "")))
	main.banner = {"title": String(ev.get("name", "")).to_upper(), "lines": [eyebrow + "  ·  " + line], "t": 3.0}
	main.sfx("ready", 0.9, -4.0, 0.0)
	z_index = 2
	_add_view()
	queue_redraw()
	return ""


func _fill_marks(p) -> void:
	for b in p.bonds.values():
		b.essence = b.capacity()
		b.burned = false
		b.paralyzed = false


## The room: open floor, no monsters (they come as the event sends them),
## the stair out of reach. The cracked wall lesson has a wall with a crack
## in it; the ward lesson has braziers to light (objective.gd).
func plan() -> Dictionary:
	var room: Rect2 = main.OPEN_ROOM
	var out := {"monsters": [], "pillars": [], "start": room.get_center() + Vector2(0, 150),
		"stair": Vector2(room.get_center().x, room.position.y - 4000.0), "practice": true}
	if String(ev.get("layout", "")) != "" and String(ev.get("type", "")) in ["tourney", "first"]:
		out["pillars"] = Tournaments.pillars(String(ev["layout"]), room)  # (the location's own arena: tournaments.gd)
	if not String(ev.get("type", "")) in ["lesson", "advanced"]:
		return out
	var c := float(Floors.CELL)
	match String(ev.get("kind", "")):
		"wall":
			out["walk"] = [Rect2(room.position + Vector2(WALL_FLOOR.position) * c, Vector2(WALL_FLOOR.size) * c)]
			out["cracks"] = [{"kind": "alcove", "tiles": [WALL_CELL], "faces": [{"tile": WALL_CELL, "out": Vector2i(0, 1)}],
				"alcove": Rect2(room.position + Vector2(WALL_CELL.x - 1, WALL_CELL.y - 2) * c, Vector2(3, 2) * c), "walk": []}]
			out["start"] = room.position + (Vector2(WALL_CELL) + Vector2(0.5, 4.5)) * c
		"ward":
			var n := clampi(int(ev.get("pieces", 2)), 1, 4)
			var pieces: Array = []
			for i in n:
				var x := room.position.x + room.size.x * (float(i) + 1.0) / float(n + 1)
				pieces.append({"pos": Vector2(x, room.position.y + 150.0), "room": -1})
			out["objective"] = {"kind": "braziers", "name": String(load("res://scripts/objectives.gd").KINDS["braziers"]["name"]), "pieces": pieces}
	return out


func _setup_lesson() -> void:
	var room: Rect2 = main.OPEN_ROOM
	var c := room.get_center()
	var p = main.player
	posts.clear()
	dummies.clear()
	match String(ev.get("kind", "")):
		"run":
			var spots := [Vector2(room.position.x + 220, room.position.y + 140), Vector2(room.end.x - 220, room.position.y + 140), Vector2(c.x, room.position.y + 110)]
			posts = spots.slice(0, clampi(int(ev.get("posts", 3)), 1, spots.size()))
		"cast":
			var n := int(ev.get("dummies", 3))
			for i in n:
				var d = Dummy.new()
				d.setup_dummy(main)
				d.position = c + Vector2(0, -70) + Vector2.from_angle(TAU * i / float(n)) * 46.0
				main.add_child(d)
				dummies.append(d)
		"strike", "shoot":
			# Striking: dummies close by; shooting: far up the room, out of a blade's reach.
			var n := clampi(int(ev.get("dummies", 2)), 1, 4)
			var far: bool = String(ev.get("kind", "")) == "shoot"
			for i in n:
				var d = Dummy.new()
				d.setup_dummy(main)
				var side := (float(i) - float(n - 1) * 0.5)
				d.position = Vector2(c.x + side * (360.0 if far else 90.0), room.position.y + (90.0 if far else 230.0))
				main.add_child(d)
				dummies.append(d)
		"spar":
			_setup_spar()
		"cure":
			Reactions.apply(main, p, String(ev.get("state", "soaked")), float(ev.get("seconds", 25.0)))
	for id in ev.get("give", []):
		if p.has_method("add_item"):
			p.add_item(String(id))
	if float(ev.get("hurt", 0.0)) > 0.0:
		p.hp = p.max_health() * float(ev["hurt"])
		if ev.get("give", []).size() > 0 and "item_sel" in p:
			p.item_sel = String(ev["give"][0])
	items0 = _items_held(p)
	for k in ev.get("foes", []):
		_spawn(String(k), _spot(), true)


func _items_held(p) -> int:
	var n := 0
	if p != null and "items" in p:
		for id in p.items:
			n += int(p.items[id])
	return n


func _setup_drill() -> void:
	var room: Rect2 = main.OPEN_ROOM
	var c := room.get_center()
	posts.clear()
	dummies.clear()
	match String(ev.get("kind", "")):
		"run":
			var spots := [Vector2(room.position.x + 150, room.position.y + 120), Vector2(room.end.x - 150, room.position.y + 120),
				Vector2(room.end.x - 150, room.end.y - 100), c, Vector2(room.position.x + 150, room.end.y - 100), Vector2(c.x, room.position.y + 90)]
			posts = spots.slice(0, clampi(int(ev.get("posts", 6)), 1, spots.size()))
		"cast":
			var n := int(ev.get("dummies", 6))
			for i in n:
				var d = Dummy.new()
				d.setup_dummy(main)
				d.position = c + Vector2(0, -70) + Vector2.from_angle(TAU * i / float(n)) * 46.0
				main.add_child(d)
				dummies.append(d)
		"shoot":
			# Far up the room, out of a blade's reach (as in the shooting lesson).
			var n := clampi(int(ev.get("dummies", 3)), 1, 4)
			for i in n:
				var d = Dummy.new()
				d.setup_dummy(main)
				d.position = Vector2(c.x + (float(i) - float(n - 1) * 0.5) * 300.0, room.position.y + 90.0)
				main.add_child(d)
				dummies.append(d)
	for k in ev.get("foes", []):
		_spawn(String(k), _spot(), true)


## The bracket's opponents, one a round: a climber with marks (rivals.gd's
## record), your reflection ({}), a round of creatures ({"monsters": [...]})
## or the first tournament's champion (a fighter with no marks).
func _setup_tourney() -> void:
	opponents.clear()
	for rd in ev.get("rounds", []):
		if bool(rd.get("mirror", false)):
			opponents.append({})
		elif rd.has("monsters"):
			opponents.append({"monsters": (rd["monsters"] as Array).duplicate()})
		elif bool(rd.get("champion", false)):
			opponents.append(Training.champion_record(main.get("rivals")))
		else:
			opponents.append(_opponent(rd))


## Mark training's sparring partner: a climber with marks of their own
## (as tough as floor 2 for each mark), who yields when beaten.
func _setup_spar() -> void:
	var rec := _opponent({"marks": int(ev.get("marks", 1)), "step": int(ev.get("step", 1))})
	var room: Rect2 = main.OPEN_ROOM
	var body = load("res://scripts/rival.gd").new()
	body.setup_rival(main, main.rivals.body_data(rec) if main.get("rivals") != null else {"name": "?"}, false, self)
	body.position = main.clear_spot(Vector2(room.get_center().x, room.position.y + 150.0), body.radius, [])
	body.face = (main.player.global_position - body.position).normalized()
	main.add_child(body)
	body.aware = true
	body.notice_t = 0.0
	spar_body = body
	opp_name = String(rec.get("name", ""))


func _opponent(rd: Dictionary) -> Dictionary:
	var fl := int(ev.get("floor", 2))
	var rec: Dictionary = main.rivals.new_rival(fl, String(ev.get("tower", ""))) if main.get("rivals") != null else {"name": "?", "bonds": []}
	var n := clampi(int(rd.get("marks", 1)), 1, 3)
	var ids: Array = Bonds.BONDS.keys()
	ids.shuffle()
	var lean := String(ev.get("marks_kind", ""))
	if lean != "":
		# The location's rivals: their first mark leans to its tower's essence.
		var own: Array = ids.filter(func(b): return String(Bonds.BONDS[b].get("affinity", "")) == lean)
		ids = own + ids.filter(func(b): return not own.has(b))
	var parts: Array = Bonds.PARTS.duplicate()
	parts.shuffle()
	var bl: Array = []
	for k in mini(n, mini(ids.size(), parts.size())):
		bl.append([ids[k], parts[k], clampi(int(rd.get("step", 1)) - k, 1, 5)])
	rec["bonds"] = bl
	return rec


# --- each frame ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not on or main == null or main.player == null:
		return
	if done:
		if Time.get_ticks_msec() - done_at >= int(RESULT_WAIT * 1000.0):
			leave()
		return
	var p = main.player
	t += delta
	if p.hp < hp_last - 0.01 or p.hits_taken > hits0:
		hurt = true  # (any damage taken: not flawless)
	hp_last = p.hp
	match String(ev.get("type", "")):
		"lesson", "advanced":
			_lesson(delta, p)
		"basics":
			if tut != null:
				tut.tick(delta, p)
		"drill":
			_drill(delta, p)
		"tourney", "first":
			_tourney(delta, p)
		"duel":
			if t >= float(Dining.RULES["duel_time"]):
				finish({"won": false, "draw": true})
	if _view != null:
		_view.queue_redraw()


func _lesson(delta: float, p) -> void:
	var limit := float(ev.get("time", 60))
	var need := int(ev.get("need", 1))
	var want: Array = ev.get("foes", [])
	if not want.is_empty() and main.enemies().size() < want.size():
		refill_t -= delta
		if refill_t <= 0.0:
			refill_t = REFILL
			_spawn(String(want[main.enemies().size() % want.size()]), _spot(), true)
	var ok := false
	match String(ev.get("kind", "")):
		"run":
			_touch_posts(p)
			ok = post >= posts.size()
		"roll":
			var now: bool = float(p.roll_t) > 0.0
			if now and not rolling:
				rolls += 1
			rolling = now
			ok = rolls >= need
		"jump":
			var up: bool = float(p.jump_t) > 0.0
			if up and not jumping:
				jumps += 1
			jumping = up
			ok = jumps >= need
		"strike", "shoot":
			# Blows on the dummies, by the weapon in hand (a bow's for shooting).
			var total := 0
			for d in dummies:
				if is_instance_valid(d):
					total += int(d.hits_taken)
			if total > _dummy_hits:
				var ranged: bool = String(Weapons.WEAPONS.get(String(p.weapon), {}).get("slot", "")) == "ranged"
				if ranged == (String(ev.get("kind", "")) == "shoot"):
					struck += total - _dummy_hits
				_dummy_hits = total
			ok = struck >= need
		"parry":
			ok = (perfects if bool(ev.get("perfect", false)) else parries) >= need
		"kills":
			ok = kills >= need
		"cast_foes":
			_watch_foe_casts(delta, p)
			ok = (best_cast if bool(ev.get("at_once", false)) else foes_hit) >= need
		"spar":
			ok = false  # (they yield: on_yield)
		"belt":
			used = maxi(used, items0 - _items_held(p))
			ok = used >= need
		"cast":
			_watch_casts(delta, p)
			ok = best_cast >= need
		"cure":
			ok = t > 0.3 and float(p.states.get(String(ev.get("state", "soaked")), 0.0)) <= 0.0
		"wall":
			ok = main.cracks != null and main.cracks.broken_count > 0
		"ward":
			var ob = main.objective
			ok = ob != null and ob.kind != "" and ob.done_count() >= ob.pieces.size() and not ob.pieces.is_empty()
	if ok:
		finish({"done": true})
	elif t >= limit:
		finish({"done": false, "why": Stations.TEXT["result_time"]})


func _touch_posts(p) -> void:
	if post < posts.size() and p.global_position.distance_to(posts[post]) <= POST_REACH:
		main.fx_ring(posts[post], UI.GILT, 40.0, 0.35, 3.0)
		main.sfx("chime", 1.2, -6.0, 0.0)
		post += 1
		queue_redraw()


func _drill(delta: float, p) -> void:
	var limit := float(ev.get("time", 30))
	var kind := String(ev.get("kind", ""))
	# Fallen foes come back after a moment.
	var want: Array = ev.get("foes", [])
	if not want.is_empty() and main.enemies().size() < want.size():
		refill_t -= delta
		if refill_t <= 0.0:
			refill_t = REFILL
			_spawn(String(want[main.enemies().size() % want.size()]), _spot(), true)
	match kind:
		"parry":
			if t >= limit:
				finish({"score": float(perfects if bool(ev.get("perfect", false)) else parries)})
		"shoot":
			# Shots on the far dummies with a bow (a blade's blows don't count).
			var total := 0
			for d in dummies:
				if is_instance_valid(d):
					total += int(d.hits_taken)
			if total > _dummy_hits:
				if String(Weapons.WEAPONS.get(String(p.weapon), {}).get("slot", "")) == "ranged":
					struck += total - _dummy_hits
				_dummy_hits = total
			if struck >= int(ev.get("need", 6)):
				finish({"score": snappedf(t, 0.1)})
			elif t >= limit:
				finish({"score": -1.0, "why": Stations.TEXT["result_time"]})
		"kills":
			if kills >= int(ev.get("need", 5)):
				finish({"score": snappedf(t, 0.1)})
			elif t >= limit:
				finish({"score": -1.0, "why": Stations.TEXT["result_time"]})
		"dodge":
			if t >= limit:
				finish({"score": float(p.hits_taken - hits0)})
		"run":
			_touch_posts(p)
			if post >= posts.size():
				finish({"score": snappedf(t, 0.1)})
			elif t >= limit:
				finish({"score": -1.0, "why": Stations.TEXT["result_time"]})
		"cast":
			_watch_casts(delta, p)
			if best_cast >= dummies.size() or t >= limit:
				finish({"score": float(best_cast)})


## A cast opens a short window; the dummies struck in it count.
func _watch_casts(delta: float, p) -> void:
	if p.spells_cast > spells0:
		spells0 = p.spells_cast
		cast_left = CAST_WINDOW
		cast_seen = {}
		cast_hits = {}
		for d in dummies:
			cast_hits[d] = d.hits_taken
	if cast_left > 0.0:
		cast_left -= delta
		for d in dummies:
			if is_instance_valid(d) and d.hits_taken > int(cast_hits.get(d, d.hits_taken)):
				cast_seen[d] = true
		best_cast = maxi(best_cast, cast_seen.size())


## Mark training with creatures: a cast opens a short window, and every
## creature its spells strike in it counts (in all, and the most at once).
func _watch_foe_casts(delta: float, p) -> void:
	if p.spells_cast > spells0:
		spells0 = p.spells_cast
		cast_left = CAST_WINDOW
		cast_seen = {}
		cast_hits = {}
		for e in main.enemies():
			cast_hits[e] = int(e.get_meta("arena_hits", 0))
	if cast_left > 0.0:
		cast_left -= delta
		for e in main.enemies():
			if is_instance_valid(e) and not cast_seen.has(e) and int(e.get_meta("arena_hits", 0)) > int(cast_hits.get(e, 0)):
				cast_seen[e] = true
				foes_hit += 1
		best_cast = maxi(best_cast, cast_seen.size())


## A bracket: each round's opponent steps up after a pause; when they yield
## (or your reflection falls, or a round's creatures are all down) the round
## is won, health and marks are made whole, and the next one comes; the last
## won wins the bracket.
func _tourney(delta: float, p) -> void:
	var total := opponents.size()
	if opp == null and round_mobs.is_empty():
		round_wait -= delta
		if round_wait <= 0.0 and round_i < total:
			_send_round(p)
		return
	var gone := false
	if not round_mobs.is_empty():
		gone = round_mobs.all(func(e): return not is_instance_valid(e) or bool(e.get("dead"))) or main.enemies().is_empty()
	else:
		gone = not is_instance_valid(opp) or bool(opp.get("dead")) or bool(opp.get("standing")) or main.enemies().is_empty()
	if not gone:
		return
	if round_mobs.is_empty() and not (opponents[round_i] as Dictionary).is_empty():
		_gain(String(Towers.TOWERS.get(main.tower, {}).get("essence", "air")), float(Training.USUAL["round"]))  # (a climber beaten: the round's essence)
	opp = null
	round_mobs = []
	rounds_won += 1
	round_i += 1
	if rounds_won >= total:
		finish({"won": true, "rounds": rounds_won})
		return
	p.hp = p.max_health()
	p.rest_fatigue()  # (made whole between rounds: fatigue too)
	p.sta = p.max_sta
	p.states.clear()
	p.poison_t = 0.0
	_fill_marks(p)
	round_wait = ROUND_GAP
	var key := "final" if round_i == total - 1 else "round"
	main.banner = {"title": Stations.TEXT["result_round"] % rounds_won, "lines": [Stations.master_line(key)], "t": ROUND_GAP}
	main.sfx("clear", 1.2, -6.0, 0.0)


func _send_round(p) -> void:
	var rec: Dictionary = opponents[round_i]
	var room: Rect2 = main.OPEN_ROOM
	var at := Vector2(room.get_center().x, room.position.y + 150.0)
	var tough: Vector2 = Floors.toughness(int(ev.get("floor", 1)))
	var base: Vector2 = Floors.toughness(maxi(1, int(main.floor_num)))
	var rd: Dictionary = ev.get("rounds", [])[round_i]
	var said := Training.round_text(round_i, rd) if String(ev.get("type", "")) == "first" else Tournaments.round_text(rd)
	if rec.has("monsters"):
		# A round of creatures: they step in across the top of the room, as
		# tough as the event's floor; the round is won when all are down.
		var kinds: Array = rec["monsters"]
		for i in kinds.size():
			var x := room.get_center().x + (float(i) - float(kinds.size() - 1) * 0.5) * 150.0
			var e = main.spawn_enemy(String(kinds[i]), Vector2(x, room.position.y + 130.0 + 30.0 * float(i % 2)))
			if e == null:
				continue
			e.max_hp *= tough.x / maxf(base.x, 0.01)
			e.hp = e.max_hp
			e.dmg *= tough.y / maxf(base.y, 0.01)
			e.aware = true
			e.notice_t = 0.0
			main.fx_ring(e.global_position, e.color, 36.0, 0.35, 3.0)
			round_mobs.append(e)
		opp_name = Tournaments.round_text(rd)
		main.banner = {"title": (Stations.TEXT["hud_round"] % [round_i + 1, opponents.size()]).to_upper(), "lines": [said], "t": 2.4}
		main.sfx("warn_knight", 1.1, -6.0, 0.0)
		return
	if rec.is_empty():
		opp = load("res://scripts/mirror.gd").spawn(main, at)
		opp_name = Stations.TEXT["mirror"]
	else:
		opp = load("res://scripts/rival.gd").new()
		opp.setup_rival(main, main.rivals.body_data(rec), false, self)
		opp.position = main.clear_spot(at, opp.radius, [])
		opp.face = (p.global_position - opp.position).normalized()
		main.add_child(opp)
		opp.max_hp *= tough.x / maxf(base.x, 0.01) * float(rd.get("hp", 1.0))
		opp.hp = opp.max_hp
		opp.dmg *= tough.y / maxf(base.y, 0.01)
		opp_name = String(rec.get("name", ""))
	if opp == null:
		return
	opp.aware = true
	opp.notice_t = 0.0
	main.fx_ring(opp.global_position, Color(1.0, 0.8, 0.5), 44.0, 0.4, 3.0)
	main.banner = {"title": (Stations.TEXT["hud_round"] % [round_i + 1, opponents.size()]).to_upper(), "lines": [Stations.TEXT["vs"] % opp_name, said], "t": 2.4}
	main.sfx("warn_knight", 1.1, -6.0, 0.0)


## A duel from the Dining car: the Arena car round the room, and the climber
## you challenged (rival.gd), as tough as the duel's floor, yielding at
## dining.gd RULES "duel_yield".
func _setup_duel() -> void:
	var room: Rect2 = main.OPEN_ROOM
	car_view = ArenaCar.new()
	car_view.main = main
	main.add_child(car_view)
	var rec: Dictionary = ev.get("rival", {})
	var data: Dictionary = main.rivals.body_data(rec) if main.get("rivals") != null else {}
	data["yield"] = float(Dining.RULES["duel_yield"])
	var body = load(Dining.Rivals.BODY).new()
	body.setup_rival(main, data, false, self)
	var tough: Vector2 = Floors.toughness(int(ev.get("floor", 1)))
	var base: Vector2 = Floors.toughness(maxi(1, int(main.floor_num)))
	body.max_hp = body.max_hp / maxf(base.x, 0.01) * tough.x
	body.hp = body.max_hp
	body.dmg = body.dmg / maxf(base.y, 0.01) * tough.y
	body.position = room.get_center() + Vector2(0, -110)
	if main.player != null:
		body.face = (main.player.global_position - body.position).normalized()
	main.add_child(body)
	duel_body = body


## A rival climber yielded (rival.gd: the arena is its host): a bracket's
## round is won (_tourney sees it gone); a duel from the Dining car is won.
func on_yield(body) -> void:
	if on and not done and String(ev.get("type", "")) == "duel" and body == duel_body:
		duel_body = null
		finish({"won": true})
	elif on and not done and spar_body != null and body == spar_body:
		spar_body = null
		finish({"done": true})  # (mark training: the sparring partner yields)


func on_spent(_body) -> void:
	pass


## Somewhere in the upper half of the room, clear of the climber.
func _spot() -> Vector2:
	var room: Rect2 = main.OPEN_ROOM
	var p = main.player
	for i in 10:
		var at := Vector2(randf_range(room.position.x + 140.0, room.end.x - 140.0), randf_range(room.position.y + 80.0, room.get_center().y))
		if p == null or at.distance_to(p.global_position) > 220.0:
			return at
	return Vector2(room.get_center().x, room.position.y + 100.0)


## A foe: "kind", "kind*" (a champion) or "mirror". A lesson's or drill's
## foes hit softly (its "weak").
func _spawn(k: String, at: Vector2, soft: bool):
	var e = null
	if k == "mirror":
		e = load("res://scripts/mirror.gd").spawn(main, at)
	elif k.ends_with("*"):
		e = EnemyScript.new()
		e.setup(k.trim_suffix("*"), main)
		e.make_champion()
		e.position = main.clear_spot(at, e.radius, main.enemies().map(func(o): return o.global_position))
		main.add_child(e)
	else:
		e = main.spawn_enemy(k, at)
	if e == null:
		return null
	if soft:
		e.dmg *= float(ev.get("weak", 1.0))
	e.aware = true
	e.notice_t = 0.0
	main.fx_ring(e.global_position, e.color, 36.0, 0.35, 3.0)
	return e


# --- what happens in it ---------------------------------------------------------------------

func _on_parry(_source, perfect: bool) -> void:
	if on and not done:
		parries += 1
		if perfect:
			perfects += 1


## A blow landed on something in the arena (main.gd's on_hit): striking and
## shooting lessons count blows on their dummies by the weapon in hand; a
## creature struck is noted for mark training; and in a tournament, the
## weapon each blow came from (the first tournament's piece follows it).
func _on_hit(foe, _dmg: float, source: String) -> void:
	if not on or done or source != "blow" or main.player == null or foe == null or not is_instance_valid(foe):
		return
	var p = main.player
	if dummies.has(foe):
		return  # (dummies count their own hits: _lesson)
	foe.set_meta("arena_hits", int(foe.get_meta("arena_hits", 0)) + 1)
	if String(ev.get("type", "")) in ["first", "tourney"] and float(p.get("cast_t")) <= 0.0:
		weapons_used[String(p.weapon)] = int(weapons_used.get(String(p.weapon), 0)) + 1


## Essence gathered in here, at the usual amount (training.gd settles its share).
func _gain(kind: String, amount: float) -> void:
	if amount > 0.0 and Essence.KINDS.has(kind):
		gathered[kind] = float(gathered.get(kind, 0.0)) + amount


## A foe fell (main.gd on_enemy_killed, which leaves the rest to this: no
## drops or record in the arena; its essence, at the usual amount, is the
## result's, and training.gd settles a share of it).
func on_enemy_killed(e) -> void:
	kills += 1
	if e.get("mirror") == true and String(e.get("kind")) != "rival":
		mirrors += 1
	elif Essence.DROPS.has(String(e.kind)):
		var drop: Array = Essence.drop_for(String(e.kind), int(ev.get("floor", 1)))
		_gain(String(drop[0]), float(drop[1]))
		_gain(String(Towers.TOWERS.get(main.tower, {}).get("essence", "")), Towers.ESSENCE_BONUS)
	main.fx_text(e.global_position + Vector2(0, -30), "slain", Color(0.89, 0.71, 0.35))
	main.fx_ring(e.global_position, e.color, 46.0, 0.4, 4.0)
	main.fx_burst(e.global_position, Vector2.ZERO, e.color, 16, 300.0)
	var kill_sound: String = "kill_" + String(e.kind)
	main.sfx(kill_sound if main.audio != null and main.audio.has_sound(kill_sound) else "kill")
	main.hitstop(0.06)
	main.shake(5.0)


## A blow that would fell the climber (main.gd proving_spare): they stay
## standing, and the event is lost (a bracket: you yield).
func spare() -> bool:
	if not on:
		return false
	if String(ev.get("type", "")) == "basics" and main.player != null:
		main.player.hp = main.player.max_health()  # (basic training: a soft blow never ends it)
		return true
	if not done:
		hurt = true
		match String(ev.get("type", "")):
			"lesson", "advanced":
				finish.call_deferred({"done": false, "why": Stations.TEXT["result_fell"]})
			"drill":
				finish.call_deferred({"score": -1.0, "why": Stations.TEXT["result_fell"]})
			_:
				finish.call_deferred({"won": false, "rounds": rounds_won, "why": Stations.TEXT["result_fell"]})
	return true


## The event is over: its result shows for a moment, then back to the station.
func finish(res: Dictionary) -> void:
	if not on or done:
		return
	done = true
	done_at = Time.get_ticks_msec()
	result = res.duplicate()
	result["type"] = ev["type"]
	result["id"] = ev["id"]
	result["mirrors"] = mirrors
	result["station"] = String(ev.get("station", ""))
	var p = main.player
	if String(ev["type"]) in ["lesson", "advanced"] and bool(result.get("done", false)):
		# A lesson done: its essence, of its own kind (training.gd USUAL).
		var lk := String(ev.get("essence", "air"))
		if lk == "mark":
			lk = Training.fee_kind(main.profile, String(ev["id"]))
		_gain(lk, float(Training.USUAL["lesson"]))
	result["essence"] = gathered.duplicate()
	result["soak"] = main.run_soak.duplicate()  # (what each body part did in here)
	if String(ev["type"]) == "basics":
		result["step"] = tut.reached() if tut != null else 0
	if String(ev["type"]) == "first":
		result["flawless"] = not hurt and p != null and p.hits_taken <= hits0
		result["used"] = weapons_used.duplicate()
		result["armor"] = armor_base
	if p != null:
		p.set_physics_process(false)
		p.hp = maxf(p.hp, 1.0)
	for e in main.enemies():
		e.set_physics_process(false)
	var title := ""
	var line := ""
	match String(ev["type"]):
		"lesson", "advanced":
			var ok: bool = result.get("done", false)
			title = (Stations.TEXT["lesson_done"] if ok else Stations.TEXT["lesson_todo"])
			line = String(ev.get("name", "")) if ok else String(result.get("why", ""))
			if ok:
				for tid in ev.get("tips", []):
					main.GuideScript.also_told(String(tid))  # (the lesson taught it: the Entity won't repeat it as a first-time tip)
			main.sfx("clear" if ok else "ui_back", 1.0, -2.0, 0.0)
		"basics":
			title = String(Tutorial.TEXT["done_title"])
			line = String(Tutorial.TEXT["done_line"])
			for tid in Tutorial.TIPS:
				main.GuideScript.also_told(String(tid))  # (it taught them: the Entity won't repeat them as first-time tips)
			main.GuideScript.say_text(String(Tutorial.TEXT["end_say_closed" if Training.closed(main.profile) else "end_say"]), true)
			main.sfx("clear", 1.0, -2.0, 0.0)
		"drill":
			var score := float(result.get("score", -1.0))
			var medal := Stations.medal_for(String(ev["id"]), score)
			title = Stations.medal_name(medal)
			line = Stations.score_text(String(ev["id"]), score) if score >= 0.0 else String(result.get("why", ""))
			main.sfx("clear" if medal > 0 else "ui_back", 1.0, -2.0, 0.0)
		"duel":
			var dwon: bool = result.get("won", false)
			title = String(Dining.TEXT["result_draw" if result.get("draw", false) else ("result_won" if dwon else "result_lost")])
			line = String(ev.get("name", ""))
			main.sfx("clear" if dwon else "ui_back", 1.0, -2.0, 0.0)
			if duel_body != null and is_instance_valid(duel_body) and not dwon:
				duel_body.stand_down()  # (they stand down: nobody dies)
		"first":
			# The first tournament: the Grace comes win or lose.
			var total := opponents.size()
			title = String(Training.TEXT["result_first"]) % [mini(rounds_won, total), total]
			line = String(Training.TEXT["grace_banner"])
			main.sfx("clear", 1.0, -2.0, 0.0)
			if opp != null and is_instance_valid(opp) and opp.has_method("stand_down"):
				opp.stand_down()
		_:
			var won: bool = result.get("won", false)
			title = (Stations.TEXT["result_win"] % String(ev.get("name", ""))) if won else (Stations.TEXT["result_loss"] % [String(ev.get("name", "")), rounds_won + 1])
			line = Stations.master_line("won" if won else "lost")
			main.sfx("clear" if won else "ui_back", 1.0, -2.0, 0.0)
	main.banner = {"title": title.to_upper(), "lines": [line] if line != "" else [], "t": RESULT_WAIT + 0.5, "hold": true, "pri": 2}


## Gives up (the pause menu): lost, back to the station at once.
func give_up() -> void:
	if not on:
		return
	if not done:
		done = true
		result = {"type": ev["type"], "id": ev["id"], "won": false, "done": false, "rounds": rounds_won, "score": -1.0, "why": Stations.TEXT["result_quit"], "mirrors": 0}
		if String(ev["type"]) == "basics":
			# Basic training left part way: the place is kept, and what the
			# steps done gave (their essence, what each body part did).
			result["step"] = tut.reached() if tut != null else int(ev.get("from", 0))
			result["essence"] = gathered.duplicate()
			result["soak"] = main.run_soak.duplicate()
	leave()


## Back to the station: the result is written to the save, then the scene
## starts afresh on the train with the station's page open.
func leave() -> void:
	if not on:
		return
	var prof = main.profile
	prof.saving = _was_saving
	var res := result if not result.is_empty() else {"type": ev["type"], "id": ev["id"], "won": false, "done": false, "rounds": rounds_won, "score": -1.0}
	var stop := String(ev.get("stop", "gym"))
	var pick := "%s:%s" % [ev["type"], ev["id"]]
	match String(ev["type"]):
		"tourney":
			pick = "bracket:%s" % ev["id"]
		"basics":
			pick = "basics:basics"
		"first":
			pick = "manager:here"  # (the first tournament's tile gives way to the Manager's: its card says what you won)
	var station_id := String(ev.get("station", ""))
	if main.get_tree().current_scene == main:
		# The real game: the save as it was before stepping in (nothing in
		# here was kept), with the result added; then the train afresh.
		var fresh = load("res://scripts/profile.gd").new()
		fresh.save_path = prof.save_path
		fresh.load_save()
		if String(ev["type"]) == "duel":
			reopen = {"car": String(ev.get("car", "dining")), "lines": Dining.apply_duel(fresh, res, ev)["lines"]}  # (back to the Dining car: dining.gd)
		else:
			var shown := Stations.apply_result(fresh, res)
			reopen = {"station": station_id, "stop": stop, "pick": pick, "lines": shown["lines"]}
		on = false
		main.get_tree().paused = false
		main.get_tree().reload_current_scene()
		return
	# (Tests run the room outside a scene: the result goes on this profile,
	# then clear up and open the station here.)
	if String(ev["type"]) == "duel":
		reopen = {"car": String(ev.get("car", "dining")), "lines": Dining.apply_duel(prof, res, ev)["lines"]}
	else:
		var shown := Stations.apply_result(prof, res)
		reopen = {"station": station_id, "stop": stop, "pick": pick, "lines": shown["lines"]}
	on = false
	if tut != null:
		tut.restore()  # (what basic training lent: the off-hand, the belt, the essence carried)
	tut = null
	main.run_soak = _soak0  # (what the body did in here went with the result)
	main.climb_soak = _csoak0
	main.soak_worn = _worn0
	main.traps = []
	if main.trap_view != null:
		main.trap_view.reset()
	round_mobs = []
	spar_body = null
	if duel_body != null and is_instance_valid(duel_body):
		duel_body.stand_down()
	duel_body = null
	if car_view != null and is_instance_valid(car_view):
		car_view.queue_free()
	car_view = null
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
		e.remove_from_group("enemies")
	main.foes_changed()
	for d in dummies:
		if is_instance_valid(d):
			d.queue_free()
	dummies.clear()
	posts.clear()
	opp = null
	if main.player != null:
		main.player.states.clear()
	if _view != null and is_instance_valid(_view):
		_view.queue_free()
	_view = null
	queue_redraw()
	if main.player != null:
		main.player.dead = false
		main.player.hp = main.player.max_health()
	if main.menu != null and main.menu.is_open():
		main.menu.close()
	main.banner = {}
	main.await_tower()
	main.open_train()
	after_train(main)


## The train has opened (main.gd): back on the station's page, with the result.
static func after_train(m) -> void:
	if reopen.is_empty() or m == null or m.menu == null:
		return
	var r := reopen
	reopen = {}
	if r.has("car"):
		# Back from the Arena car: the Dining car, with what the duel did.
		m.menu.train_car = String(r["car"])
		m.menu.train_page.dining.lines = r.get("lines", [])
		m.menu.open("train")
		return
	m.menu.go_station(String(r.get("station", "")), String(r.get("stop", "")), String(r.get("pick", "")), r.get("lines", []), false)  # (no whistle: the train never left)


# --- in the room: the posts, and the line at the top -------------------------------------------

## A run's posts: each a striped pole with a flag; the next one lit gold,
## those touched dim.
func _draw() -> void:
	if not on or posts.is_empty():
		return
	var b := UI.Draw.Batch.new()
	for i in posts.size():
		var at: Vector2 = posts[i]
		var next := i == post
		var past := i < post
		var col := UI.GILT if next else (Color(0.5, 0.46, 0.4) if past else Color(0.8, 0.78, 0.72))
		b.circle(at + Vector2(0, 4), 13.0, Color(0, 0, 0, 0.25), 16)
		if next:
			b.circle(at, POST_REACH, Color(UI.GILT, 0.12), 24)
		b.rect(Rect2(at + Vector2(-2.5, -34), Vector2(5, 36)), Color(0.05, 0.04, 0.05))
		b.rect(Rect2(at + Vector2(-1.5, -33), Vector2(3, 34)), Color(0.45, 0.3, 0.17))
		b.polygon(PackedVector2Array([at + Vector2(1.5, -33), at + Vector2(18, -27), at + Vector2(1.5, -21)]), col)
	b.flush(self)
	var font := UI.font("display")
	for i in posts.size():
		draw_string(font, posts[i] + Vector2(-20, 20), str(i + 1), HORIZONTAL_ALIGNMENT_CENTER, 40, 16, Color(1, 1, 1, 0.8 if i >= post else 0.35))


func _add_view() -> void:
	if _view != null and is_instance_valid(_view):
		_view.queue_free()
	if main.hud == null or main.hud.get_parent() == null:
		return
	_view = ArenaLine.new()
	_view.arena = self
	_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var layer: Node = main.hud.get_parent()
	layer.add_child(_view)
	layer.move_child(_view, main.hud.get_index() + 1)  # (over the HUD, under the touch buttons)


## The line at the top: what you're doing, how it's going, the time left.
func hud_text() -> String:
	var T: Dictionary = Stations.TEXT
	if ev.get("type", "") == "duel":
		var dl: String = String(Dining.TEXT["duel_hud"]) % [String(ev.get("rival", {}).get("name", "")), String(ev.get("stake", {}).get("label", ""))]
		return dl + "  ·  " + T["hud_time"] % maxi(0, ceili(float(Dining.RULES["duel_time"]) - t))
	if ev.get("type", "") == "basics" and tut != null:
		return tut.hud_text()  # (basic training: the step and what to do, in your own keys)
	var parts: Array = [String(ev.get("name", ""))]
	var need := int(ev.get("need", 1))
	var TT: Dictionary = Training.TEXT
	match String(ev.get("type", "")):
		"lesson", "advanced":
			match String(ev.get("kind", "")):
				"run":
					parts.append(T["hud_post"] % [mini(post + 1, posts.size()), posts.size()])
				"roll":
					parts.append(T["hud_rolls"] % [mini(rolls, need), need])
				"jump":
					parts.append(TT["hud_jumps"] % [mini(jumps, need), need])
				"strike":
					parts.append(TT["hud_struck"] % [mini(struck, need), need])
				"shoot":
					parts.append(TT["hud_shots"] % [mini(struck, need), need])
				"kills":
					parts.append(T["hud_kills"] % [mini(kills, need), need])
				"cast_foes":
					parts.append(TT["hud_foes"] % [mini(best_cast if bool(ev.get("at_once", false)) else foes_hit, need), need])
				"spar":
					parts.append(TT["hud_spar"])
				"parry":
					if bool(ev.get("perfect", false)):
						parts.append(TT["hud_perfect"] % [mini(perfects, need), need])
					else:
						parts.append(T["hud_parry"] % parries)
				"belt":
					parts.append(T["hud_items"] % [mini(used, need), need])
				"cast":
					parts.append(T["hud_hit"] % [mini(best_cast, need), need])
				"cure":
					parts.append(T["hud_cure"])
				"wall":
					parts.append(T["hud_wall"])
				"ward":
					var ob = main.objective
					parts.append(T["hud_ward"] % [ob.done_count() if ob != null else 0, int(ev.get("pieces", 2))])
		"drill":
			match String(ev.get("kind", "")):
				"parry":
					if bool(ev.get("perfect", false)):
						parts.append(TT["hud_perfect"] % [perfects, int(ev.get("medals", [0, 0, 1])[2])])
					else:
						parts.append(T["hud_parry"] % parries)
				"shoot":
					parts.append(TT["hud_shots"] % [mini(struck, int(ev.get("need", 6))), int(ev.get("need", 6))])
				"kills":
					parts.append(T["hud_kills"] % [mini(kills, int(ev.get("need", 5))), int(ev.get("need", 5))])
				"dodge":
					parts.append(T["hud_hits"] % (main.player.hits_taken - hits0 if main.player != null else 0))
				"run":
					parts.append(T["hud_post"] % [mini(post + 1, posts.size()), posts.size()])
				"cast":
					parts.append(T["hud_cast"] % best_cast)
		_:
			parts.append(T["hud_round"] % [mini(round_i + 1, opponents.size()), opponents.size()])
			if opp_name != "" and opp != null:
				parts.append(opp_name)
	var limit := float(ev.get("time", 0))
	if limit > 0.0:
		parts.append(T["hud_time"] % maxi(0, ceili(limit - t)))
	return "  ·  ".join(parts)


class ArenaLine extends Control:
	const UI := preload("res://scripts/ui.gd")
	var arena

	func _draw() -> void:
		if arena == null or not arena.on or arena.main == null:
			return
		# (Its line, what you're doing and how it's going, is a status chip in
		# the HUD's top lane: hud.gd status_chips.)
		# A run's next post, off the screen: an arrow at the edge toward it.
		if arena.post < arena.posts.size():
			var sp: Vector2 = arena.get_global_transform_with_canvas() * arena.posts[arena.post]
			var edge := Rect2(Vector2(64.0, 120.0), size - Vector2(128.0, 190.0))  # (clear of the HUD's corners and the touch buttons)
			if not edge.has_point(sp):
				var c := edge.get_center()
				var d := (sp - c).normalized()
				var k := INF
				if absf(d.x) > 0.001:
					k = minf(k, (edge.size.x * 0.5) / absf(d.x))
				if absf(d.y) > 0.001:
					k = minf(k, (edge.size.y * 0.5) / absf(d.y))
				var at := c + d * k
				var side := d.orthogonal()
				var ab := UI.Draw.Batch.new()
				UI.glow_into(ab, at, 20.0, UI.GILT, 0.6)
				ab.poly(PackedVector2Array([at + d * 14.0, at - d * 8.0 + side * 10.0, at - d * 3.0, at - d * 8.0 - side * 10.0]), UI.GILT, 1.4)
				ab.flush(self)
				UI.draw_label(self, at - d * 26.0 + Vector2(-6, 6), str(arena.post + 1), 18, UI.GILT_HI, HORIZONTAL_ALIGNMENT_LEFT, -1, 3, Color(0, 0, 0, 0.7))
