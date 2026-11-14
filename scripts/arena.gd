extends Node2D
## The station's arena (main.gd owns one: `main.arena`): where the training
## gym's drills, the tournament's bouts and the challenges are fought
## (stations.gd holds what each one is). It works like the practice room
## (practice.gd): the climber steps off the train into an open room of the
## event's tower, and nothing done there is kept (profile.saving is off)
## except the result, which is written to the save as the climber goes back
## (stations.gd apply_result) before the scene starts afresh on the train,
## with the station's page open on the stop it was begun from.
##
##   drills       a goal and a score (parries, kills against the clock, hits
##                taken among archers, posts touched in order, the most
##                dummies one cast hits); foes are kept topped up and hit
##                softly; the score earns a medal
##   bouts and    waves of foes (champions, your mirror image, a beast's
##   challenges   shadow), with rules (no healing, stamina halved, fierce
##                foes, one hit fells you, silent marks) and maybe a time
##                limit: fell every wave to win
## A fall never ends anything here: the arena spares you (main.gd
## proving_spare) and the event is lost. The pause menu can give up. Words
## and numbers are in stations.gd (TEXT, RULE_FX).

const Stations := preload("res://scripts/stations.gd")
const Dummy := preload("res://scripts/dummy.gd")
const Floors := preload("res://scripts/floors.gd")
const Towers := preload("res://scripts/towers.gd")
const UI := preload("res://scripts/ui.gd")
const EnemyScript := preload("res://scripts/enemy.gd")

## How long the result shows before going back (real seconds), and the gap
## between waves.
const RESULT_WAIT := 2.4
const WAVE_GAP := 1.2
## A post is touched within this distance; a cast's hits count for this long.
const POST_REACH := 30.0
const CAST_WINDOW := 1.0
## A drill's fallen foe is replaced after this long.
const REFILL := 0.9

## Going back: the station's page opens on this once the scene starts
## afresh ({station, stop, pick, lines}).
static var reopen := {}

var main
var on := false
var ev := {}  # the event (stations.gd event)
var t := 0.0  # seconds since it began
var wave := 0  # waves sent so far
var wave_wait := 0.0
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
var hp_cap := 0.0
var _was_saving := true
var _view: Control


## Begins an event (stations.gd event): the fee is paid first (kept even if
## the game is closed), then the climber steps into the arena. "" if begun,
## else why not.
func start(e: Dictionary) -> String:
	if on or main == null or main.player == null or main.profile == null:
		return "?"
	var prof = main.profile
	var why := Stations.why_not(prof, String(e.get("type", "")), String(e.get("id", "")))
	if why != "":
		return why
	var fee := Stations.fee(String(e["type"]), String(e["id"]))
	if fee > 0:
		var paid: Dictionary = prof.spend_any(float(fee))
		if paid.is_empty():
			return "needs %d more essence, of any kind" % fee
		prof.save()
	on = true
	ev = e
	t = 0.0
	wave = 0
	wave_wait = 0.8
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
	main.cleared = true  # (no gong between waves)
	main.ward = true  # (and the stair never opens)
	main.stair_open = false
	main.room_view.stair_open = false
	var p = main.player
	p.dead = false
	p.hp = p.max_health()
	p.sta = p.max_sta
	p.poison_t = 0.0
	p.set_physics_process(true)
	for b in p.bonds.values():
		b.essence = b.capacity()
		b.burned = false
	hits0 = p.hits_taken
	spells0 = p.spells_cast
	hp_cap = p.hp
	if not p.on_parry.is_connected(_on_parry):
		p.on_parry.connect(_on_parry)
	if ev["type"] == "drill":
		_setup_drill()
	var lines: Array = []
	if ev["type"] == "drill":
		lines.append(Stations.drill_goal(String(ev["id"])))
	else:
		lines.append(String(ev.get("twist", "")) if ev["type"] == "challenge" else ", ".join(Stations.rule_lines(ev)) if not ev.get("rules", []).is_empty() else Stations.TEXT["no_rules"])
	var eyebrow: String = Stations.TEXT["start_" + String(ev["type"])]
	main.banner = {"title": String(ev.get("name", "")).to_upper(), "lines": [eyebrow + "  ·  " + String(lines[0])], "t": 3.0}
	main.sfx("ready", 0.9, -4.0, 0.0)
	z_index = 2
	_add_view()
	queue_redraw()
	return ""


## The room: open floor, no monsters (they come in waves), the stair out of reach.
func plan() -> Dictionary:
	var room: Rect2 = main.OPEN_ROOM
	return {"monsters": [], "pillars": [], "start": room.get_center() + Vector2(0, 150),
		"stair": Vector2(room.get_center().x, room.position.y - 4000.0), "practice": true}


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
	_rules(p)
	if ev["type"] == "drill":
		_drill(delta, p)
	else:
		_waves(delta)
	if _view != null:
		_view.queue_redraw()


## The event's rules, held every frame.
func _rules(p) -> void:
	var rules: Array = ev.get("rules", [])
	if "one_hit" in rules:
		p.hp = minf(p.hp, 1.0)
	if "no_heal" in rules or "one_hit" in rules:
		p.heal_left = 0.0
		if p.hp > hp_cap:
			p.hp = hp_cap
		hp_cap = p.hp
	if "half_stamina" in rules:
		p.sta = minf(p.sta, p.max_sta * float(Stations.RULE_FX["half_stamina"]))
	if "no_marks" in rules:
		for b in p.bonds.values():
			b.essence = 0.0


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
			if post < posts.size() and p.global_position.distance_to(posts[post]) <= POST_REACH:
				main.fx_ring(posts[post], UI.GILT, 40.0, 0.35, 3.0)
				main.sfx("glint", 1.2, -6.0, 0.0)
				post += 1
				queue_redraw()
			if post >= posts.size():
				finish({"score": snappedf(t, 0.1)})
			elif t >= limit:
				finish({"score": -1.0, "why": Stations.TEXT["result_time"]})
		"cast":
			_watch_casts(delta, p)
			if best_cast >= dummies.size() or t >= limit:
				finish({"score": float(best_cast)})


## Through the Pack: a cast opens a short window; the dummies struck in it count.
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


func _waves(delta: float) -> void:
	var waves: Array = ev.get("waves", [])
	var limit := float(ev.get("time", 0))
	if limit > 0.0 and t >= limit:
		finish({"won": false, "why": Stations.TEXT["result_time"]})
		return
	wave_wait -= delta
	if wave_wait > 0.0 or not main.enemies().is_empty():
		return
	if wave >= waves.size():
		finish({"won": true})
		return
	for k in waves[wave]:
		_spawn(String(k), _spot(), false)
	wave += 1
	wave_wait = WAVE_GAP
	if wave > 1:
		main.banner = {"title": Stations.TEXT["hud_wave"] % [wave, waves.size()], "lines": [], "t": 1.4}
		main.sfx("warn_knight", 1.1, -6.0, 0.0)


## Somewhere in the upper half of the room, clear of the climber.
func _spot() -> Vector2:
	var room: Rect2 = main.OPEN_ROOM
	var p = main.player
	for i in 10:
		var at := Vector2(randf_range(room.position.x + 140.0, room.end.x - 140.0), randf_range(room.position.y + 80.0, room.get_center().y))
		if p == null or at.distance_to(p.global_position) > 220.0:
			return at
	return Vector2(room.get_center().x, room.position.y + 100.0)


## A foe: "kind", "kind*" (a champion), "mirror" or "shadow:beast". A drill's
## foes hit softly (its "weak"); a bout's are as tough as its tier's floor,
## and fiercer under "fierce".
func _spawn(k: String, at: Vector2, drill: bool):
	var e = null
	if k == "mirror":
		e = load("res://scripts/mirror.gd").spawn(main, at)
	elif k.begins_with("shadow:"):
		if main.proving == null:
			return null
		e = main.proving.make_shadow(k.substr(7), {"shadow_hp": 0.55, "shadow_dmg": 0.6})
		e.position = main.clear_spot(at, e.radius, main.enemies().map(func(o): return o.global_position))
		main.add_child(e)
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
	if drill:
		e.dmg *= float(ev.get("weak", 1.0))
	else:
		var tough: Vector2 = Floors.toughness(int(ev.get("floor", 1)))
		var fierce: bool = "fierce" in ev.get("rules", [])
		if not k.begins_with("shadow:"):
			e.max_hp *= tough.x * (float(Stations.RULE_FX["fierce_hp"]) if fierce else 1.0)
			e.dmg *= tough.y
		if fierce:
			e.dmg *= float(Stations.RULE_FX["fierce_dmg"])
		e.hp = e.max_hp
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
	if e.get("mirror") == true:
		mirrors += 1
	main.fx_text(e.global_position + Vector2(0, -30), "slain", Color(0.89, 0.71, 0.35))
	main.fx_ring(e.global_position, e.color, 46.0, 0.4, 4.0)
	main.fx_burst(e.global_position, Vector2.ZERO, e.color, 16, 300.0)
	var kill_sound: String = "kill_" + String(e.kind)
	main.sfx(kill_sound if main.audio != null and main.audio.has_sound(kill_sound) else "kill")
	main.hitstop(0.06)
	main.shake(5.0)


## A blow that would fell the climber (main.gd proving_spare): they stay
## standing, and the event is lost.
func spare() -> bool:
	if not on:
		return false
	if not done:
		if ev["type"] == "drill":
			finish.call_deferred({"score": -1.0, "why": Stations.TEXT["result_fell"]})
		else:
			finish.call_deferred({"won": false, "why": Stations.TEXT["result_fell"]})
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
	if ev["type"] == "drill":
		var score := float(result.get("score", -1.0))
		var medal := Stations.medal_for(String(ev["id"]), score)
		title = Stations.medal_name(medal)
		line = Stations.score_text(String(ev["id"]), score) if score >= 0.0 else String(result.get("why", ""))
		main.sfx("clear" if medal > 0 else "ui_back", 1.0, -2.0, 0.0)
	else:
		var won: bool = result.get("won", false)
		title = (Stations.TEXT["result_win"] if won else Stations.TEXT["result_loss"]) % String(ev.get("name", ""))
		line = "" if won else String(result.get("why", ""))
		main.sfx("clear" if won else "ui_back", 1.0, -2.0, 0.0)
	main.banner = {"title": title.to_upper(), "lines": [line] if line != "" else [], "t": RESULT_WAIT + 0.5, "hold": true, "pri": 2}


## Gives up (the pause menu): lost, back to the station at once.
func give_up() -> void:
	if not on:
		return
	if not done:
		done = true
		result = {"type": ev["type"], "id": ev["id"], "won": false, "score": -1.0, "why": Stations.TEXT["result_quit"], "mirrors": 0}
	leave()


## Back to the station: the result is written to the save, then the scene
## starts afresh on the train with the station's page open.
func leave() -> void:
	if not on:
		return
	var prof = main.profile
	prof.saving = _was_saving
	var res := result if not result.is_empty() else {"type": ev["type"], "id": ev["id"], "won": false, "score": -1.0}
	var stop := String(ev.get("stop", "gym"))
	var pick := "%s:%s" % [ev["type"], ev["id"]]
	var station_id := String(ev.get("station", ""))
	if main.get_tree().current_scene == main:
		# The real game: the save as it was before stepping in (nothing in
		# here was kept), with the result added; then the train afresh.
		var fresh = load("res://scripts/profile.gd").new()
		fresh.save_path = prof.save_path
		fresh.load_save()
		var shown := Stations.apply_result(fresh, res)
		reopen = {"station": station_id, "stop": stop, "pick": pick, "lines": shown["lines"]}
		on = false
		main.get_tree().paused = false
		main.get_tree().reload_current_scene()
		return
	# (Tests run the room outside a scene: the result goes on this profile,
	# then clear up and open the station here.)
	var shown := Stations.apply_result(prof, res)
	reopen = {"station": station_id, "stop": stop, "pick": pick, "lines": shown["lines"]}
	on = false
	for e in main.get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
		e.remove_from_group("enemies")
	main.foes_changed()
	for d in dummies:
		if is_instance_valid(d):
			d.queue_free()
	dummies.clear()
	posts.clear()
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
	var parts: Array = [String(ev.get("name", ""))]
	if ev.get("type", "") == "drill":
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
	else:
		parts.append(T["hud_wave"] % [maxi(wave, 1), (ev.get("waves", []) as Array).size()])
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
