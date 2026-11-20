extends RefCounted
## The Manticore's, the Firebird's and the Chimera's newer monsters
## (scripts/towers/brood.gd and a script each): the carrion, the basilisk,
## the cairn, the kindler, flamemoths, the salamander, the graftling, the
## hydra whelp and the leafmantis. Their tables (spawn rules, the Bestiary,
## the Entity), each one's own trick and its counter, and the floor bot
## finishing floors full of them.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const Floors := preload("res://scripts/floors.gd")
const Towers := preload("res://scripts/towers.gd")
const Objectives := preload("res://scripts/objectives.gd")
const B := preload("res://scripts/bestiary.gd")
const Entity := preload("res://scripts/entity.gd")
const Notes := preload("res://scripts/entity_notes.gd")
const Essence := preload("res://scripts/essence.gd")
const Reg := preload("res://scripts/data_registry.gd")

const HOMES := {"carrion": "manticore", "basilisk": "manticore", "cairn": "manticore",
	"kindler": "firebird", "flamemoth": "firebird", "salamander": "firebird",
	"graftling": "chimera", "hydra": "chimera", "leafmantis": "chimera"}

var t


func run(smoke) -> void:
	t = smoke
	_tables()
	await t._fresh_main()
	var main = t.main
	main.profile.regarded = true
	main.first_climb = false
	await _floor("manticore", 4)
	await _carrion()
	await _basilisk()
	await _cairn()
	await _floor("firebird", 4)
	await _kindler()
	await _flamemoth()
	await _salamander()
	await _floor("chimera", 4)
	await _graftling()
	await _hydra()
	await _leafmantis()
	await _bots()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _floor(tid: String, n: int) -> void:
	var main = t.main
	main.tower = tid
	Objectives.forced = "shards"
	main._start_floor(n)
	Objectives.forced = ""
	await t._ticks(2)
	main.banner = {}
	await _clear()
	main.player.iframes = 999.0


func _clear() -> void:
	for e in t.main.enemies():
		e.queue_free()
	t.main.flames.clear()
	await t._ticks(2)


## One of a kind beside the climber, still (its physics off until the test wants it).
func _spawn(kind: String, off := Vector2(70, 0)):
	var main = t.main
	var e = main.spawn_enemy(kind, main.player.global_position + off)
	e.set_physics_process(false)
	await t._ticks(1)
	e.aware = true
	e.notice_t = 0.0
	return e


func _tables() -> void:
	print("newer monsters (manticore, firebird, chimera): their tables")
	var E = load("res://scripts/enemy.gd")
	var bad: Array = []
	for k in HOMES:
		var tid: String = HOMES[k]
		var m: Dictionary = Floors.MONSTERS.get(k, {})
		if not (E.TYPES.has(k) and E.SUBKINDS.has(k) and E.WEAKNESS.has(k) and E.MATERIAL.has(k) and bool(m.get("only", false)) and int(m.get("from", 1)) >= 3
				and Towers.TOWERS[tid]["weights"].has(k) and B.BESTIARY.has(k) and String(B.BESTIARY[k]["lore"]) == ""
				and Entity.TIPS.has(k) and Notes.TIDBITS.has("creature:" + k) and Essence.DROPS.has(k)):
			bad.append(k)
	_check(bad.is_empty(), "each has its numbers, its own script, a weakness, its tower's mix (from floor 3 or later), a Bestiary entry with blank lore, the Entity's tip and line, and its essence (%s)" % [bad])
	var groups := {}
	for g in B.groups():
		groups[g[0]] = g[2]
	_check(HOMES.keys().all(func(k): return k in groups.get(HOMES[k], [])), "...on its own tower's shelf in the Bestiary")
	_check(B.kinds().size() % 6 == 0 or B.kinds().size() < 48, "the Bestiary's count stays a count by sixes once the new monsters are all in (%d)" % B.kinds().size())
	_check(HOMES.keys().all(func(k): return B.shape(k)["pts"].size() > 30), "each is drawn from its own script (the Bestiary's picture)")
	_check(E.FLIERS.has("carrion") and E.FLIERS.has("flamemoth"), "the carrion and flamemoths fly")
	var words := (var_to_str(B.BESTIARY) + var_to_str(Entity.TIPS) + var_to_str(Notes.TIDBITS)).to_lower()
	var re := RegEx.create_from_string("\\b(attunements?|spires?|trials?|judge?ments?|mana)\\b")
	_check(re.search(words) == null, "no banned words in their words")
	var paths: Array = Reg.fields_in("brood_mfc_numbers").map(func(f): return f["path"])
	_check("towers.carrion/CARRION/hurt_below" in paths and "towers.hydra/HYDRA/max_heads" in paths, "the Data editor lists their numbers")


func _carrion() -> void:
	print("newer monsters: the carrion")
	var main = t.main
	var p = main.player
	var c = await _spawn("carrion", Vector2(60, 0))
	_check(c.state == "high" and c.submerged, "the carrion circles high, out of reach")
	var hp0: float = c.hp
	c.take_hit(10.0, Vector2.RIGHT)
	_check(c.hp == hp0, "...and blows can't touch it there")
	var guard = await _spawn("slime", Vector2(-60, 0))  # (another foe about: it isn't alone)
	p.hp = p.max_hp
	c.set_physics_process(true)
	await t._game_wait(1.0)
	_check(c.state == "high", "while you're healthy (and it isn't alone) it waits")
	p.hp = p.max_hp * 0.2
	await t._until(func(): return c.state == "wind_dive", 3.0)
	_check(c.state == "wind_dive", "badly hurt, you draw its dive: a cry, a ring on the floor")
	await t._until(func(): return c.state == "ground", 3.0)
	_check(c.state == "ground" and not c.submerged, "...it lands, and stands on the floor, open to blows")
	p.hp = p.max_hp
	c.queue_free()
	guard.queue_free()
	await t._ticks(2)


func _basilisk() -> void:
	print("newer monsters: the basilisk")
	var main = t.main
	var p = main.player
	var b = await _spawn("basilisk", Vector2(120, 0))
	var to: Vector2 = (p.global_position - b.global_position).normalized()
	b.state = "glare"
	b.state_t = 1.0
	b.gaze_dir = to
	p.iframes = 0.0
	p.states.erase("slowed")
	p.aim = -to
	b._act(0.016, to, b.global_position.distance_to(p.global_position), p)
	_check(float(p.states.get("slowed", 0.0)) > 0.0, "standing in its glare facing it, you're slowed")
	p.states.erase("slowed")
	p.aim = to
	b._act(0.016, to, b.global_position.distance_to(p.global_position), p)
	_check(float(p.states.get("slowed", 0.0)) <= 0.0, "...facing away, the glare does nothing")
	p.iframes = 999.0
	b.state = "glare"
	b.state_t = 1.0
	b.take_hit(1.0, -to)
	_check(b.state != "glare" and not b.has_meta("look_away"), "a blow breaks its glare off")
	b.queue_free()
	await t._ticks(1)


func _cairn() -> void:
	print("newer monsters: the cairn")
	var c = await _spawn("cairn")
	_check(c.state == "pile", "a cairn lies as a pile of stones")
	c.take_hit(1.0, Vector2.RIGHT)
	_check(c.state == "assemble", "...a blow (or passing near) pulls it together")
	c.take_hit(9999.0, Vector2.RIGHT, 0.0, false)
	_check(not c.dead and c.state == "rubble", "beaten down by light blows, it falls apart into rubble")
	c.take_hit(50.0, Vector2.RIGHT, 0.0, false)
	_check(not c.dead, "...light blows on the rubble only shift the stones")
	c.state_t = 0.0
	c._act(0.016, Vector2.RIGHT, 300.0, t.main.player)
	_check(c.state == "rebuild" and c.hp > 1.0, "...and it rebuilds after a while")
	c.state = "chase"
	c.take_hit(9999.0, Vector2.RIGHT, 0.0, true)
	_check(c.dead, "a heavy blow that fells it scatters the stones for good")
	var d = await _spawn("cairn")
	d.state = "chase"
	d.take_hit(9999.0, Vector2.RIGHT, 0.0, false)
	d.take_hit(1.0, Vector2.RIGHT, 0.0, true)
	_check(d.dead, "...as does a heavy blow on its rubble")


func _kindler() -> void:
	print("newer monsters: the kindler")
	var main = t.main
	var K = load("res://scripts/towers/kindler.gd")
	var k = await _spawn("kindler", Vector2(160, 0))
	var s = await _spawn("slime", Vector2(0, 90))
	var at: Vector2 = s.global_position
	s.take_hit(9999.0, Vector2.RIGHT)
	await t._ticks(1)
	var hn = K.heaps(main)
	_check(hn.list.size() == 1 and Vector2(hn.list[0]["pos"]).distance_to(at) < 2.0, "a monster falling while a kindler lives leaves a heap of ash")
	k.heap = hn.list[0]
	k.state = "channel"
	k.state_t = 1.0
	k.take_hit(1.0, Vector2.RIGHT)
	_check(k.state != "channel" and k.heap == null and hn.list.size() == 1, "struck while it channels, it's interrupted (the ash stays)")
	k.heap = hn.list[0]
	k.state = "channel"
	k.state_t = 0.01
	k.stun = 0.0
	k._act(0.05, Vector2.RIGHT, 160.0, main.player)
	await t._ticks(1)
	var risen: Array = main.enemies().filter(func(e): return e.kind == "slime" and e.has_meta("ashen"))
	_check(hn.list.is_empty() and risen.size() == 1 and risen[0].max_hp < main.EnemyScript.TYPES["slime"]["hp"] * 1.5 * 0.6, "a finished channel raises the fallen as a weak ash-risen copy")
	var stats0: int = int(main.profile.bestiary.get("slime", {}).get("slain", 0))
	risen[0].take_hit(9999.0, Vector2.RIGHT)
	await t._ticks(1)
	_check(hn.list.is_empty() and int(main.profile.bestiary.get("slime", {}).get("slain", 0)) == stats0, "an ash-risen copy crumbles: no ash, no tally, nothing left")
	hn.add(main.player.global_position, "slime", main.floor_num)
	var p = main.player
	await t._game_wait(float(K.KINDLER["stamp"]) + 0.3)
	_check(hn.list.is_empty(), "standing on a heap stamps it out")
	k.queue_free()
	await t._ticks(1)


func _flamemoth() -> void:
	print("newer monsters: flamemoths")
	var main = t.main
	var m = await _spawn("flamemoth")
	var hp0: float = m.max_hp
	main.Reactions.apply(main, m, "burning", 3.0, "fire")
	_check(m.grown == 1 and m.max_hp > hp0 and m.burn_t <= 0.0, "fire makes the swarm grow instead of burning it")
	m.soaked = 2.0
	m._act(0.016, Vector2.RIGHT, 200.0, main.player)
	_check(m.dead or (m.grown == 0 and m.hp < m.max_hp * 0.5), "water disperses it (most of its health gone)")
	var n = await _spawn("flamemoth")
	n.lift(1.0)
	_check(n.dead or n.hp < n.max_hp * 0.5, "...and so does wind")
	main.add_flame(main.player.global_position + Vector2(-150, 0), 30.0, 10.0)
	var o = await _spawn("flamemoth", Vector2(-130, 0))
	_check(o._lure(main.player, 300.0) != Vector2.INF, "burning floor nearer than you draws it")
	await _clear()


func _salamander() -> void:
	print("newer monsters: the salamander")
	var main = t.main
	var at: Vector2 = main.player.global_position + Vector2(120, 0)
	main.add_flame(at, 60.0, 20.0)
	var s = await _spawn("salamander", Vector2(120, 0))
	s.global_position = at
	s.state = "sub"
	s.submerged = true
	var hp0: float = s.hp
	s.take_hit(10.0, Vector2.RIGHT)
	_check(s.hp == hp0, "in the flames the salamander can't be struck")
	s.soaked = 2.0
	s._act(0.016, Vector2.LEFT, 120.0, main.player)
	_check(not s.submerged and main.flames.all(func(f): return float(f["t"]) <= 0.0 or Vector2(f["pos"]).distance_to(at) > 80.0), "soaked, its fire goes out and it's thrown out, exposed")
	s.queue_free()
	await _clear()
	var w = await _spawn("salamander", Vector2(90, 0))
	w.state = "walk"
	w.set_physics_process(true)
	main.player.iframes = 999.0
	await t._until(func(): return not main.flames.is_empty(), 10.0)
	_check(not main.flames.is_empty(), "with no fire near, it kindles a pool of its own")
	await _clear()


func _graftling() -> void:
	print("newer monsters: the graftling")
	var main = t.main
	var g = await _spawn("graftling", Vector2(80, 0))
	var h = await _spawn("thornhound", Vector2(80, 60))
	h.global_position = g.global_position + (main.player.global_position - g.global_position).normalized() * 50.0
	var hp0: float = h.hp
	_check(g._donor() == h, "a monster near it is a donor")
	g._take_part(h)
	_check(g.graft == "leap" and (h.dead or h.hp < hp0), "it tears a part away: the hound's legs (and the hound is hurt)")
	g.state = "chase"
	main.attackers.clear()
	g._try_attack(Vector2.LEFT, 100.0)
	_check(g.state == "wind_leap", "...and now leaps as the hound does, with the hound's telegraph")
	await _clear()


func _hydra() -> void:
	print("newer monsters: the hydra whelp")
	var main = t.main
	var h = await _spawn("hydra")
	var n0: int = h.heads
	h.take_hit(h.max_hp * 0.26, Vector2.RIGHT, 0.0)
	_check(h.heads == n0 - 1 and h.stumps.size() == 1, "enough damage cuts off a head")
	h._tend_stumps(float(h.HYDRA["regrow"]) + 0.1)
	_check(h.heads == n0 + 1 and h.stumps.is_empty(), "...and two grow back from the stump")
	h.burn_t = 2.0
	h.take_hit(h.max_hp * 0.26, Vector2.RIGHT, 0.0)
	h._tend_stumps(float(h.HYDRA["regrow"]) + 0.1)
	_check(h.heads == n0 and h.stumps.size() == 1 and bool(h.stumps[0]["seared"]), "a burned wound is seared and never regrows")
	await _clear()


func _leafmantis() -> void:
	print("newer monsters: the leafmantis")
	var main = t.main
	var m = await _spawn("leafmantis", Vector2(200, 0))
	_check(m.state == "hide" and m.submerged and not main.targets().has(m), "a leafmantis hides among the leaves: it can't be aimed at")
	m.flush()
	_check(m.state != "hide" and not m.submerged and m.burn_t > 0.0, "fire flushes it out, burning")
	var n = await _spawn("leafmantis", Vector2(60, 0))
	n.set_physics_process(true)
	main.attackers.clear()
	await t._until(func(): return n.state == "wind_slash" or n.state in ["lunge", "slash"], 3.0)
	_check(n.state in ["wind_slash", "lunge", "slash"], "come near and it rustles, rears and winds up its double slash")
	await _clear()


func _bots() -> void:
	print("newer monsters: the floor bot finishes floors full of them")
	var Sweep = load("res://tests/floor_bot_sweep.gd")
	var main = t.main
	var saved := {}
	for tid in ["manticore", "firebird", "chimera"]:
		saved[tid] = Towers.TOWERS[tid]["weights"].duplicate()
		var w := {}
		for k in HOMES:
			if HOMES[k] == tid:
				w[k] = 1.0
		w[saved[tid].keys()[0]] = 0.5
		Towers.TOWERS[tid]["weights"] = w
	var ok := 0
	var why: Array = []
	for pick in [["manticore", 5], ["firebird", 5], ["chimera", 5]]:
		main.tower = pick[0]
		Objectives.forced = "shards"
		var r: Dictionary = await Sweep.play(t, main, pick[1], 2.0)
		if not r["ok"]:
			why.append("(first try) %s: %s" % [pick[0], String(r["why"]).left(80)])
			r = await Sweep.play(t, main, pick[1], 2.0)
		Objectives.forced = ""
		if r["ok"]:
			ok += 1
		else:
			why.append("%s: %s" % [pick[0], r["why"]])
	for tid in saved:
		Towers.TOWERS[tid]["weights"] = saved[tid]
	_check(ok >= 2, "the bot finishes floors of the newer monsters (%d of 3) %s" % [ok, why])
