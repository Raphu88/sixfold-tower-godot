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
##   lessons   the basics, hands on, with the Entity's word as each begins:
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


## Begins an event (stations.gd event): the fee is paid first (kept even if
## the game is closed), then the climber steps into the arena. "" if begun,
## else why not.
func start(e: Dictionary) -> String:
	if on or main == null or main.player == null or main.profile == null:
		return "?"
	var prof = main.profile
	var type := String(e.get("type", ""))
	var duel := type == "duel"  # (a duel from the Dining car: no fee, nothing to unlock)
	var why := Stations.why_not(prof, type, String(e.get("id", ""))) if not duel else ""
	if why != "":
		return why
	var fee := Stations.fee(prof, type, String(e["id"])) if not duel else 0
	if fee > 0:
		var paid: Dictionary = prof.spend_any(float(fee))
		if paid.is_empty():
			return Stations.TEXT["needs_fee"] % fee
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
	var p = main.player
	p.dead = false
	p.hp = p.max_health()
	p.sta = p.max_sta
	p.poison_t = 0.0
	p.set_physics_process(true)
	_fill_marks(p)
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
		"drill":
			_setup_drill()
			line = Stations.drill_goal(String(ev["id"]))
		"tourney":
			_setup_tourney()
			line = Stations.master_line("greet")
	var eyebrow: String = Stations.TEXT["start_" + type]
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


## The room: open floor, no monsters (they come as the event sends them),
## the stair out of reach. The cracked wall lesson has a wall with a crack
## in it; the ward lesson has braziers to light (objective.gd).
func plan() -> Dictionary:
	var room: Rect2 = main.OPEN_ROOM
	var out := {"monsters": [], "pillars": [], "start": room.get_center() + Vector2(0, 150),
		"stair": Vector2(room.get_center().x, room.position.y - 4000.0), "practice": true}
	if String(ev.get("type", "")) != "lesson":
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
	for k in ev.get("foes", []):
		_spawn(String(k), _spot(), true)


## The bracket's opponents, one a round: a climber with marks (rivals.gd's
## record), or your reflection.
func _setup_tourney() -> void:
	opponents.clear()
	for rd in ev.get("rounds", []):
		opponents.append({} if bool(rd.get("mirror", false)) else _opponent(rd))


func _opponent(rd: Dictionary) -> Dictionary:
	var fl := int(ev.get("floor", 2))
	var rec: Dictionary = main.rivals.new_rival(fl, String(ev.get("tower", ""))) if main.get("rivals") != null else {"name": "?", "bonds": []}
	var n := clampi(int(rd.get("marks", 1)), 1, 3)
	var ids: Array = Bonds.BONDS.keys()
	ids.shuffle()
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
	match String(ev.get("type", "")):
		"lesson":
			_lesson(delta, p)
		"drill":
			_drill(delta, p)
		"tourney":
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
		"parry":
			ok = parries >= need
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
		main.sfx("glint", 1.2, -6.0, 0.0)
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
				finish({"score": float(parries)})
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


## A bracket: each round's opponent steps up after a pause; when they yield
## (or your reflection falls) the round is won, health and marks are made
## whole, and the next one comes; the last won wins the bracket.
func _tourney(delta: float, p) -> void:
	var total := opponents.size()
	if opp == null:
		round_wait -= delta
		if round_wait <= 0.0 and round_i < total:
			_send_round(p)
		return
	var gone: bool = not is_instance_valid(opp) or bool(opp.get("dead")) or bool(opp.get("standing")) or main.enemies().is_empty()
	if not gone:
		return
	opp = null
	rounds_won += 1
	round_i += 1
	if rounds_won >= total:
		finish({"won": true, "rounds": rounds_won})
		return
	p.hp = p.max_health()
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
	main.banner = {"title": (Stations.TEXT["hud_round"] % [round_i + 1, opponents.size()]).to_upper(), "lines": [Stations.TEXT["vs"] % opp_name, Stations.round_text(rd)], "t": 2.4}
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

func _on_parry(_source, _perfect: bool) -> void:
	if on and not done:
		parries += 1


## A foe fell (main.gd on_enemy_killed, which leaves the rest to this: no
## drops, essence or record in the arena).
func on_enemy_killed(e) -> void:
	kills += 1
	if e.get("mirror") == true and String(e.get("kind")) != "rival":
		mirrors += 1
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
	if not done:
		match String(ev.get("type", "")):
			"lesson":
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
	var p = main.player
	if p != null:
		p.set_physics_process(false)
		p.hp = maxf(p.hp, 1.0)
	for e in main.enemies():
		e.set_physics_process(false)
	var title := ""
	var line := ""
	match String(ev["type"]):
		"lesson":
			var ok: bool = result.get("done", false)
			title = (Stations.TEXT["lesson_done"] if ok else Stations.TEXT["lesson_todo"])
			line = String(ev.get("name", "")) if ok else String(result.get("why", ""))
			if ok:
				for tid in ev.get("tips", []):
					main.GuideScript.also_told(String(tid))  # (the lesson taught it: the Entity won't repeat it as a first-time tip)
			main.sfx("clear" if ok else "ui_back", 1.0, -2.0, 0.0)
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
	m.menu.go_station(String(r.get("station", "")), String(r.get("stop", "")), String(r.get("pick", "")), r.get("lines", []))


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
	var parts: Array = [String(ev.get("name", ""))]
	var need := int(ev.get("need", 1))
	match String(ev.get("type", "")):
		"lesson":
			match String(ev.get("kind", "")):
				"run":
					parts.append(T["hud_post"] % [mini(post + 1, posts.size()), posts.size()])
				"roll":
					parts.append(T["hud_rolls"] % [mini(rolls, need), need])
				"parry":
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
					parts.append(T["hud_parry"] % parries)
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
