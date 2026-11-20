extends RefCounted
## The new monsters of every tower and of the Gryphon's, Kraken's and
## Wyvern's towers (scripts/foes/): the husk, the bellringer, the squall,
## the rookery, the stormstone, the inkling, the drowned, the driftbell, the
## stoker, the slagworm and the riveter. Each is in its tables (health,
## spawns, Bestiary, the Entity's words, essence), turns up only where and
## from the floor it should, warns before it strikes, and its counterplay
## works. No luck: floors' picks are seeded, fights wait for their moment
## with a time limit. Run by smoke_test.gd (_part_tests).

const Floors := preload("res://scripts/floors.gd")
const Towers := preload("res://scripts/towers.gd")
const B := preload("res://scripts/bestiary.gd")
const E := preload("res://scripts/enemy.gd")
const Entity := preload("res://scripts/entity.gd")
const Notes := preload("res://scripts/entity_notes.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const Essence := preload("res://scripts/essence.gd")
const Reg := preload("res://scripts/data_registry.gd")
const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]
const HOME := {"husk": "", "bellringer": "", "squall": "gryphon", "rookery": "gryphon", "stormstone": "gryphon",
	"inkling": "kraken", "drowned": "kraken", "driftbell": "kraken", "stoker": "wyvern", "slagworm": "wyvern", "riveter": "wyvern"}

var t
var main
var p
var stand := Vector2.ZERO


func run(smoke) -> void:
	t = smoke
	_data()
	_spawns()
	await t._fresh_main()
	main = t.main
	main.profile.regarded = true
	main.first_climb = false
	main.dev_no_death = true
	await _husk()
	await _bellringer()
	await _squall()
	await _rookery()
	await _stormstone()
	await _inkling()
	await _drowned()
	await _driftbell()
	await _stoker()
	await _slagworm()
	await _riveter()
	main.dev_no_death = false
	main.tower = "kraken"


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


# --- the tables ---------------------------------------------------------------------

func _data() -> void:
	print("new monsters: their tables")
	var missing: Array = []
	for k in HOME:
		if not (E.TYPES.has(k) and E.SUBKINDS.has(k) and E.WEAKNESS.has(k) and Floors.MONSTERS.has(k) and Essence.DROPS.has(k) and B.BESTIARY.has(k)):
			missing.append(k)
		elif load(String(E.SUBKINDS[k])) == null or not load(String(E.SUBKINDS[k])).can_instantiate():
			missing.append(k + " (script)")
	_check(missing.is_empty(), "every new monster has its numbers, script, weakness, spawn entry, essence and Bestiary entry (%s)" % [missing])
	var bad: Array = []
	for k in HOME:
		var e: Dictionary = B.BESTIARY.get(k, {})
		if String(e.get("lore", "x")) != "" or String(e.get("desc", "")).length() < 60:
			bad.append(k)
		if B.shape(k)["pts"].size() <= 30:
			bad.append(k + " (picture)")
	_check(bad.is_empty(), "...each with a description, a blank lore for the owner and its own picture (%s)" % [bad])
	var groups := {}
	for g in B.groups():
		for k in g[2]:
			groups[k] = g[0]
	var wrong: Array = HOME.keys().filter(func(k): return groups.get(k, "?") != (HOME[k] if HOME[k] != "" else "every"))
	_check(wrong.is_empty(), "the Bestiary shelves them: the husk and the bellringer with every tower's, the rest under their towers (%s)" % [wrong])
	var told: Array = HOME.keys().filter(func(k): return not Entity.TIPS.has(k) or Entity.TIPS[k]["group"] != "tower" or Notes.lines("creature:" + k).is_empty())
	_check(told.is_empty(), "the Entity has a first-time moment and a word in play for each (%s)" % [told])
	_check("how_foes" in Talk.DIALOGUE["how"]["choices"] and Talk.DIALOGUE.has("how_foes"), "\"How do things work here?\" has a topic on monsters that work together")
	var words := var_to_str(B.BESTIARY) + var_to_str(Notes.TIDBITS) + var_to_str(Talk.DIALOGUE["how_foes"])
	for k in HOME:
		words += var_to_str(Entity.TIPS.get(k, {}))
		var sc = load(String(E.SUBKINDS[k]))
		if "TEXT" in sc:
			words += var_to_str(sc.TEXT)
	var re := RegEx.create_from_string("\\b(attunements?|spires?|trials?|judge?ments?|mana)\\b")
	_check(re.search(words.to_lower()) == null, "no banned words in their words")
	var nums: Array = Reg.fields_in("new_foes_numbers").map(func(f): return f["path"])
	var texts: Array = Reg.fields_in("new_foes_words").map(func(f): return f["path"])
	_check("foes.husk/RULES/beat" in nums and "foes.stormstone/RULES/reach" in nums and "foes.riveter/TEXT/down" in texts, "the Data editor lists their numbers and words")
	var slow := HOME.keys().all(func(k): return float(Essence.DROPS[k][1]) <= 5.0)
	_check(slow, "none drops much essence (slow growth)")


## Seeded picks: none comes before its floor, the towers' own only in their
## tower, the shared ones in every tower.
func _spawns() -> void:
	print("new monsters: where and when they come")
	seed(4242)
	var seen := {}  # kind -> {tower: lowest floor}
	for tid in Towers.ORDER:
		var mix: Dictionary = Towers.TOWERS[tid]["weights"]
		for fl in range(1, 12):
			for i in 300:
				var k := Floors._pick(fl, 99.0, 0, mix)
				if not HOME.has(k):
					continue
				if not seen.has(k):
					seen[k] = {}
				seen[k][tid] = mini(int(seen[k].get(tid, 99)), fl)
	var early: Array = []
	var stray: Array = []
	for k in HOME:
		var from := int(Floors.MONSTERS[k]["from"])
		for tid in seen.get(k, {}):
			if int(seen[k][tid]) < from:
				early.append("%s %s %d" % [k, tid, seen[k][tid]])
			if HOME[k] != "" and tid != HOME[k]:
				stray.append("%s in %s" % [k, tid])
	_check(early.is_empty(), "none comes before its first floor (%s)" % [early])
	_check(stray.is_empty(), "a tower's own come only in that tower (%s)" % [stray])
	var homes: Array = HOME.keys().filter(func(k): return not seen.has(k) or (HOME[k] != "" and not seen[k].has(HOME[k])) or (HOME[k] == "" and seen[k].size() < Towers.ORDER.size()))
	_check(homes.is_empty(), "each turns up where it lives (the shared ones in every tower) (%s)" % [homes])
	var gentle := HOME.keys().all(func(k): return int(Floors.MONSTERS[k]["from"]) >= 2)
	_check(gentle, "none on the first floor: early floors stay gentle")


# --- in play --------------------------------------------------------------------------

## A clear open floor, the climber in the middle of it.
func _arena(tower: String) -> void:
	main.tower = tower
	main._start_floor(1)
	await t._ticks(2)
	main.banner = {}
	for e in main.enemies():
		e.queue_free()
	main.puddles.clear()
	await t._ticks(2)
	p = main.player
	stand = main.room.get_center() + Vector2(0, 40)
	_hold()


## Keeps the climber where it stands, unhurt and ready to be hit.
func _hold(heal := true) -> void:
	p.global_position = stand
	p.velocity = Vector2.ZERO
	p.knock = Vector2.ZERO
	p.iframes = 0.0
	p.hurt_t = 0.0
	p.parry_t = 0.0
	if heal:
		p.hp = p.max_health()


func _spawn(kind: String, off: Vector2):
	var e = main.spawn_enemy(kind, stand + off)
	e.aware = true
	e.notice_t = 0.0
	return e


## Ticks until `cond` holds (or `ticks` run out); `each` runs every tick.
func _until(cond: Callable, ticks: int, each := Callable()) -> bool:
	for i in ticks:
		if cond.call():
			return true
		if each.is_valid():
			each.call()
		await t.physics_frame
	return cond.call()


func _clear() -> void:
	for e in main.enemies():
		e.queue_free()
	await t._ticks(2)


func _husk() -> void:
	print("new monsters: the husk")
	await _arena("gryphon")
	var e = _spawn("husk", Vector2(70, 0))
	var states := {}
	var glint_first := [false]
	var hurt := await _until(func(): return p.hp < p.max_health(), 900, func():
		states[e.state] = true
		glint_first[0] = glint_first[0] or e.glinted
		_hold(false))
	_check(hurt and glint_first[0] and (states.has("wind_slash") or states.has("wind_lunge")), "a husk winds up and glints before it strikes (%s)" % [states.keys()])
	# It reads your rhythm: three blows on one beat, then it parries the fourth.
	e.set_physics_process(false)
	e.state = "chase"
	e.stun = 0.0
	var dir := Vector2.RIGHT  # (blows travel from the climber to it)
	e.face = -dir
	for i in 3:
		e._clock = 10.0 + 0.5 * i
		e.take_hit(1.0, dir, 0.0)
	_check(e.state == "guard", "three blows on one beat: it raises its guard (%s)" % e.state)
	var before: float = e.hp
	e._clock = 11.5
	e.take_hit(5.0, dir, 0.0)
	_check(is_equal_approx(e.hp, before) and e.state in ["wind_riposte", "recover"], "...and parries the next blow on that beat, answering with a cut that glints (%s)" % e.state)
	main.release_attack(e)
	e.state = "chase"
	for i in 3:
		e._clock = 20.0 + 0.5 * i
		e.take_hit(1.0, dir, 0.0)
	before = e.hp
	e._clock = 21.0 + 0.95  # (off the beat: a pause)
	e.take_hit(5.0, dir, 0.0)
	_check(e.hp < before and e.state != "guard", "change your timing and the guard breaks: the blow lands (%s)" % e.state)
	e.state = "chase"
	for i in 3:
		e._clock = 30.0 + 0.5 * i
		e.take_hit(1.0, dir, 0.0)
	before = e.hp
	e.face = dir  # (turned away)
	e._clock = 31.5
	e.take_hit(5.0, dir, 0.0)
	_check(e.hp < before, "a blow from behind is never parried")
	# It rolls away from your wind-ups.
	e.set_physics_process(true)
	e.state = "chase"
	e.flinch = 0.0
	e.stun = 0.0
	e._roll_cd = 0.0
	e.global_position = stand + Vector2(70, 0)
	_hold()
	p.set_physics_process(false)  # (a bow held drawn, without a bow in hand)
	p.drawing = true
	var rolled := await _until(func(): return e.state == "roll", 60)
	before = e.hp
	if rolled:
		e.take_hit(5.0, dir, 0.0)
	p.drawing = false
	p.set_physics_process(true)
	_check(rolled and is_equal_approx(e.hp, before), "it rolls away from a drawn bow, and can't be struck mid-roll")
	await _clear()


func _bellringer() -> void:
	print("new monsters: the bellringer")
	await _arena("kraken")
	var bell = _spawn("bellringer", Vector2(220, 0))
	var slime = _spawn("slime", Vector2(260, 60))
	slime.set_physics_process(false)
	bell.ring_t = 0.0
	var states := {}
	var rung := await _until(func(): return slime.haste_t > 0.0, 300, func():
		states[bell.state] = true
		bell.global_position = stand + Vector2(220, 0)
		_hold())
	_check(rung and states.has("lift") and bell._rings == 1 and slime.haste_k > 1.0, "a bellringer lifts its bell (the warning), then rings: monsters near it are quickened (%s)" % [states.keys()])
	# Quickened, a monster gets over its attack sooner.
	slime.state = "rest"
	slime.state_t = 1.0
	slime.set_physics_process(true)
	await t._ticks(15)
	_check(slime.state_t < 1.0 - 15.0 / 60.0 - 0.02 or slime.state != "rest", "...a quickened monster gets over its attack sooner (%.2f)" % slime.state_t)
	slime.set_physics_process(false)
	# Struck with its bell up, the ring is lost.
	bell.state = "lift"
	bell.state_t = 0.8
	bell.take_hit(1.0, Vector2.RIGHT, 0.0)
	await t._ticks(3)
	_check(bell.state == "skulk" and bell._rings == 1, "struck while its bell is up: the ring is lost")
	# It runs from you.
	bell.global_position = stand + Vector2(90, 0)
	bell.state = "skulk"
	bell.ring_t = 99.0
	var fled := await _until(func(): return bell.global_position.distance_to(stand) > 110.0, 120, func(): _hold())
	_check(fled, "it runs from you")
	await _clear()


func _squall() -> void:
	print("new monsters: the squall")
	await _arena("gryphon")
	var e = _spawn("squall", Vector2(150, 0))
	var states := {}
	var parried := [false]
	var hit := await _until(func(): return e._gusts > 0, 900, func():
		states[e.state] = true
		_hold()
		if e.state == "wind_gust" and e.glinted:
			p.aim = (e.global_position - p.global_position).normalized()
			p.parry_t = 1.0  # (a parry held up: a gust goes through it)
			parried[0] = true)
	await t._ticks(1)
	_check(hit and states.has("wind_gust") and p.hp < p.max_health(), "a squall winds up a gust (streaks down a lane) and it lands through a parry (%s)" % [states.keys()])
	_check(parried[0] and p.knock.length() > 150.0, "...and shoves you down its lane (%d)" % int(p.knock.length()))
	# Whirling it turns most of a blow; spinning up again, blows land in full.
	e.set_physics_process(false)
	e.state = "whirl"
	e.open_t = 0.0
	var before: float = e.hp
	e.take_hit(10.0, Vector2.RIGHT, 0.0)
	var whirl_dmg: float = before - e.hp
	e.state = "spinup"
	before = e.hp
	e.take_hit(10.0, Vector2.RIGHT, 0.0)
	_check(whirl_dmg < 5.0 and before - e.hp >= 9.9, "whirling it turns most of a blow (%.1f); spinning up, the blow lands in full (%.1f)" % [whirl_dmg, before - e.hp])
	await _clear()


func _rookery() -> void:
	print("new monsters: the rookery")
	await _arena("gryphon")
	p.iframes = 999.0
	var e = _spawn("rookery", Vector2(0, -160))
	e.hatch_t = 0.0
	var states := {}
	var most := [0]
	var each := func():
		states[e.state] = true
		e.hatch_t = minf(e.hatch_t, 0.0)
		var alive: Array = main.enemies().filter(func(b): return b.kind == "bat")
		most[0] = maxi(most[0], alive.size())
		for b in alive:
			b.set_physics_process(false)
		p.global_position = stand
		p.iframes = 999.0
	var two := await _until(func(): return e.bats.size() >= 2, 900, each)
	_check(two and states.has("hatch"), "a rookery's egg rocks and cracks (a warning ring), then a bat flies out (%s)" % [states.keys()])
	await _until(func(): return false, 200, each)
	_check(most[0] <= int(e.RULES["alive"]) and e.hatched == 2, "...never more than two of its bats at once (%d alive at most, %d hatched)" % [most[0], e.hatched])
	t._slay(e.bats[0])
	var three := await _until(func(): return e.hatched >= 3 and e.state == "empty", 900, each)
	await _until(func(): return false, 200, each)
	_check(three and e.hatched == int(e.RULES["most"]), "one falls and the next egg hatches; three in all, then the nest is empty (%d)" % e.hatched)
	var before := Vector2(e.global_position)
	e.take_hit(5.0, Vector2.RIGHT, 300.0)
	await t._ticks(3)
	_check(e.global_position.distance_to(before) < 1.0, "it never moves, even when struck")
	p.iframes = 0.0
	await _clear()


func _stormstone() -> void:
	print("new monsters: the stormstone")
	await _arena("gryphon")
	var e = _spawn("stormstone", Vector2(-120, 0))
	var slime = _spawn("slime", Vector2(-60, 0))
	slime.set_physics_process(false)
	e.charge = 0.99
	var states := {}
	var hp0: float = slime.hp
	var arced := await _until(func(): return e._arcs > 0, 300, func():
		states[e.state] = true
		_hold())
	_check(arced and states.has("wind_arc") and e._struck == slime and (not is_instance_valid(slime) or slime.hp < hp0) and p.hp >= p.max_health() - 0.1,
		"a stormstone charges, a red line picks the nearest, and lightning arcs to the monster you lured nearer, not you (%s)" % [states.keys()])
	if is_instance_valid(slime):
		slime.queue_free()
	await t._ticks(2)
	e.charge = 0.99
	p.states.erase("charged")
	arced = await _until(func(): return e._arcs > 1, 300, func(): _hold(false))
	_check(arced and e._struck == p and p.hp < p.max_health() and float(p.states.get("charged", 0.0)) > 0.0, "with nothing nearer, it strikes you (no parry), and leaves you charged")
	stand = stand + Vector2(400, 0)
	_hold()
	e.charge = 0.99
	arced = await _until(func(): return e._arcs > 2, 300, func(): _hold())
	_check(arced and e._struck == null and p.hp >= p.max_health() - 0.1, "nobody in reach: the charge goes into the ground")
	await _clear()


func _inkling() -> void:
	print("new monsters: the inkling")
	await _arena("kraken")
	var e = _spawn("inkling", Vector2(150, 0))
	e.spray_cd = 0.0
	var states := {}
	var sprayed := await _until(func(): return e._sprays > 0, 600, func():
		states[e.state] = true
		_hold())
	var clouds: Array = main.get_children().filter(func(c): return "kind" in c and "beads" in c and String(c.kind) == "ink")
	_check(sprayed and states.has("puff") and not clouds.is_empty() and e.in_cloud(p.global_position), "an inkling puffs up (a ring marks the spot), then sprays a cloud of ink round you (%s)" % [states.keys()])
	var glint_first := [false]
	var bit := await _until(func(): return p.hp < p.max_health(), 600, func():
		states[e.state] = true
		glint_first[0] = glint_first[0] or (e.state == "wind_nip" and e.glinted)
		_hold(false))
	_check(bit and states.has("wind_nip") and glint_first[0], "...then nips from inside it, after a glint (%s)" % [states.keys()])
	await _clear()


func _drowned() -> void:
	print("new monsters: the drowned")
	await _arena("kraken")
	var e = _spawn("drowned", Vector2(300, 0))
	await t._ticks(3)
	var before: float = e.hp
	e.take_hit(10.0, Vector2.RIGHT, 0.0)
	_check(e.state == "lying" and e.submerged and is_equal_approx(e.hp, before), "a drowned one lies under a puddle, out of reach")
	e.global_position = stand + Vector2(80, 0)
	var rose := await _until(func(): return e.state == "rise", 60, func(): _hold())
	_check(rose and not e.submerged, "come near and it rises")
	var states := {}
	var glint_first := [false]
	p.states.erase("soaked")
	var hit := await _until(func(): return p.hp < p.max_health(), 900, func():
		states[e.state] = true
		glint_first[0] = glint_first[0] or e.glinted
		_hold(false))
	_check(hit and states.has("wind_slam") and glint_first[0] and float(p.states.get("soaked", 0.0)) > 0.0, "it raises its arms, glints and slams; the blow soaks you (%s)" % [states.keys()])
	p.states.erase("soaked")
	e.global_position = stand + Vector2(40, 0)
	e.take_hit(9999.0, Vector2.RIGHT, 0.0)
	await t._ticks(2)
	var bodies: Array = main.get_children().filter(func(c): return "kind" in c and "beads" in c and String(c.kind) == "burst" and not c.beads.is_empty())
	_check(not is_instance_valid(e) and not bodies.is_empty() and float(p.states.get("soaked", 0.0)) <= 0.0, "slain, it falls at once, but its body swells first (a ring shows its burst)")
	var burst := await _until(func(): return float(p.states.get("soaked", 0.0)) > 0.0, 120, func(): _hold())
	_check(burst and float(p.states.get("soaked", 0.0)) > 0.0, "...then bursts, soaking you")
	await _clear()


func _driftbell() -> void:
	print("new monsters: the driftbell")
	await _arena("kraken")
	main.puddles.append({"pos": stand + Vector2(120, 0), "r": 140.0})
	var e = _spawn("driftbell", Vector2(200, 0))
	_check(e.kind in e.FLIERS, "a driftbell floats (over deep water too)")
	stand = stand + Vector2(-60, 0)
	var wet := await _until(func(): return e.trail != null and is_instance_valid(e.trail) and e.trail.beads.any(func(b): return b.get("wet", false)), 300, func():
		e.global_position.y = stand.y
		_hold())
	_check(wet, "it leaves a crackling trail where it drifts over water")
	if wet:
		e.set_physics_process(false)
		var bead: Dictionary = e.trail.beads.filter(func(b): return b.get("wet", false))[-1]
		bead["t"] = 3.0
		var keep := stand
		stand = bead["pos"]
		p.states.erase("charged")
		var stung := await _until(func(): return p.hp < p.max_health(), 30, func(): _hold(false))
		_check(stung and float(p.states.get("charged", 0.0)) > 0.0, "...touch it and it stings and leaves you charged")
		stand = keep
		e.set_physics_process(true)
	e.global_position = stand + Vector2(40, 0)
	_hold()
	var states := {}
	var glint_first := [false]
	var hit := await _until(func(): return p.hp < p.max_health(), 600, func():
		states[e.state] = true
		glint_first[0] = glint_first[0] or (e.state == "wind_spark" and e.glinted)
		_hold(false))
	_check(hit and glint_first[0], "come close: its tendrils light up, it glints, then sparks all round (%s)" % [states.keys()])
	main.puddles.clear()
	await _clear()


func _stoker() -> void:
	print("new monsters: the stoker")
	await _arena("wyvern")
	var e = _spawn("stoker", Vector2(150, 0))
	e.throw_cd = 0.0
	var states := {}
	var spots := [0]
	var flung := await _until(func(): return e._flings > 0, 600, func():
		states[e.state] = true
		if e.state == "wind_throw":
			spots[0] = maxi(spots[0], e.spots.size())
		_hold())
	var mine: Array = main.flames.filter(func(f): return int(f.get("stoker", 0)) == e.get_instance_id())
	_check(flung and states.has("wind_throw") and spots[0] >= 1 and not mine.is_empty(), "a stoker marks where its coal lands (red circles), then flings it: the floor burns (%s)" % [states.keys()])
	t._slay(e)
	await t._ticks(2)
	_check(mine.all(func(f): return float(f["t"]) <= float(load("res://scripts/foes/stoker.gd").RULES["die_down"]) + 0.01), "slay it and its fires die down")
	main.flames.clear()
	await _clear()


func _slagworm() -> void:
	print("new monsters: the slagworm")
	await _arena("wyvern")
	var e = _spawn("slagworm", Vector2(220, 0))
	stand = stand + Vector2(-120, 0)
	var laid := await _until(func(): return e.slag != null and is_instance_valid(e.slag) and e.slag.beads.size() >= 3, 600, func(): _hold())
	_check(laid, "a slagworm leaves slag behind it as it crawls")
	_check(not e.may_lay(main.stair_pos + Vector2(10, 0)), "...never near the stair")
	if laid:
		e.set_physics_process(false)
		var bead: Dictionary = e.slag.beads[-1]
		bead["t"] = 6.0
		stand = bead["pos"]
		var burnt := await _until(func(): return p.hp < p.max_health(), 60, func(): _hold(false))
		_check(burnt and not main.is_solid(bead["pos"]), "hot slag burns whoever stands on it, but never blocks the way")
		e.set_physics_process(true)
	await _clear()


func _riveter() -> void:
	print("new monsters: the riveter")
	await _arena("wyvern")
	p.iframes = 999.0
	var e = _spawn("riveter", Vector2(200, 0))
	var states := {}
	var shot := await _until(func(): return e._bursts > 0 and e.shots >= 3, 900, func():
		states[e.state] = true
		p.global_position = stand
		p.iframes = 999.0)
	var rivets: Array = main.get_children().filter(func(c): return "last" in c and "shooter" in c and c.shooter == e)
	var hot: Array = rivets.filter(func(r): return r.last)
	_check(shot and states.has("wind_burst") and rivets.size() >= 2 and hot.size() == 1, "a riveter aims (a red line, a glint) and fires a burst of three, the last one hot (%s, %d rivets)" % [states.keys(), rivets.size()])
	if hot.is_empty():
		await _clear()
		return
	var cold: Array = rivets.filter(func(r): return not r.last)
	if not cold.is_empty():
		cold[0].on_parried(false)
		await t._ticks(1)
		_check(not is_instance_valid(cold[0]) or cold[0].is_queued_for_deletion(), "a parried cold rivet only glances off")
	p.aim = (e.global_position - p.global_position).normalized()
	hot[0].on_parried(false)
	var held := [e]
	var down := await _until(func(): return is_instance_valid(held[0]) and held[0].state == "down", 120, func():
		p.global_position = stand)
	_check(down, "parry the hot one and it flies back, knocking the riveter out of the air")
	p.iframes = 0.0
	await _clear()
