extends RefCounted
## The spell rework: Lightning Rod, Virulence, the Grafter (Graft Burst with
## no grafts, grafts coming sooner, Mimic, Shed and Bud with nothing to work
## with), Carry, and the Unbound's Volley and Vault each do their new thing.
## Every number is read from data. Run by smoke_test.gd (_part_tests); `t`
## is the smoke test.

const TestRun := preload("res://scripts/test_run.gd")

var t
var B = load("res://scripts/bonds.gd")
var P = load("res://scripts/profile.gd")
var F = load("res://scripts/spells/unbound_forms.gd")
## The way the climber faces in the tests: one with open floor ahead.
var dir := Vector2.RIGHT


func run(smoke) -> void:
	t = smoke
	await _lightning_rod()
	await _virulence()
	await _carry()
	await _grafter()
	await _volley()
	await _vault()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## A fresh climber with one mark on the hand at a step, alone, facing open floor.
func _marked(bond_id: String, step: int) -> void:
	await t._fresh_main()
	t.paused = false
	var main = t.main
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.profile.regarded = true
	main.first_climb = false
	main.profile.bonds = {"hand": {"id": bond_id, "xp": float(P.STEP_XP[step - 1]), "faint": false, "debt": 0.0}}
	main._give_bonds()
	for e in main.enemies():
		e.queue_free()
	main.grafts.clear()
	main.graft_order.clear()
	main.graft_drops.clear()
	await t._frames(2)
	var p = main.player
	p.iframes = 999.0
	dir = Vector2.RIGHT
	for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
		var open := true
		for k in range(1, 16):
			var at: Vector2 = p.global_position + d * 20.0 * k
			if main.is_solid(at) or not main.room.grow(-20.0).has_point(at):
				open = false
		if open:
			dir = d
			break
	p.aim = dir


## A foe that stands still where the test puts it.
func _foe(at: Vector2, hp := 400.0, kind := "slime"):
	var e = t.main.spawn_enemy(kind, at)
	e.set_physics_process(false)
	e.global_position = at
	e.max_hp = hp
	e.hp = hp
	e.aware = true
	return e


## The data's value of a hand spell's key at the mark's step.
func _stat(spell_id: String, key: String):
	var b = t.main.player.bonds["hand"]
	for sp in b.spells():
		if sp["id"] == spell_id:
			return b.spell_stat(sp, key)
	return null


## Casts a hand spell by id as a climber does; returns the essence it cost.
func _cast(spell_id: String) -> float:
	var main = t.main
	var p = main.player
	var b = p.bonds["hand"]
	b.select(b.spells().map(func(sp): return sp["id"]).find(spell_id))
	b.essence = b.capacity()
	b.burned = false
	p.attack_cd = 0.0
	p.cast_t = 0.0
	var before: float = b.essence
	p.aim = dir
	p._try_cast("hand")
	await t._wait(b.windup() + 0.12)
	for i in 120:
		if p.cast_t <= 0.0:
			break
		await t._frames(1)
	return before - b.essence


# --- Lightning Rod ---------------------------------------------------------------

func _lightning_rod() -> void:
	print("the rework: Lightning Rod")
	await _marked("stormcaller", 4)
	var main = t.main
	var p = main.player
	var side: Vector2 = dir.orthogonal()
	var range_: float = float(_stat("lightning_rod", "range"))
	var radius: float = float(_stat("lightning_rod", "radius"))
	var near = _foe(p.global_position + dir * range_ + side * (radius * 0.5))
	var paid := await _cast("lightning_rod")
	_check(not main.rod.is_empty() and main.rod["pos"].distance_to(p.global_position + dir * range_) < 30.0 and is_equal_approx(paid, float(_stat("lightning_rod", "cost"))),
		"Lightning Rod plants a rod where you aim (costs %.0f)" % paid)
	await t._wait(float(_stat("lightning_rod", "beat")) + 0.2)
	_check(near.hp < near.max_hp and near.charged > 0.0, "...it strikes and charges a foe near it on its beat (%.0f)" % (near.max_hp - near.hp))
	# A foe out of the chain's reach from you, but in the rod's: the chain leaps through the rod.
	var rod_at: Vector2 = main.rod["pos"]
	var far_at: Vector2 = rod_at + dir * (radius + 40.0)
	var far = _foe(far_at)
	var reach: float = float(_stat("chain_lightning", "reach"))
	await _cast("chain_lightning")
	_check(p.global_position.distance_to(far_at) > reach and far.hp < far.max_hp, "...a chain with no foe in reach leaps to the rod and on to a foe beyond (%.0f)" % (far.max_hp - far.hp))
	# Its end: it draws the charge out of every charged foe near it.
	near.charged = 5.0
	var hp0: float = near.hp
	main.rod["t"] = 0.05
	main.rod["next"] = 9.0
	await t._wait(0.2)
	_check(main.rod.is_empty() and near.charged <= 0.0 and near.hp < hp0, "...and when it ends it draws out a charged foe's charge in a burst (%.0f)" % (hp0 - near.hp))


# --- Virulence -------------------------------------------------------------------

func _virulence() -> void:
	print("the rework: Virulence")
	await _marked("venomist", 5)
	var main = t.main
	var p = main.player
	var side: Vector2 = dir.orthogonal()
	var radius: float = float(_stat("virulence", "radius"))
	var stagger_at: int = int(_stat("virulence", "stagger_at"))
	var heavy = _foe(p.global_position + dir * 90.0)
	var light = _foe(p.global_position + dir * 70.0 + side * 80.0)
	var clean = _foe(p.global_position + dir * 150.0)
	var far = _foe(p.global_position + dir * (radius + 30.0))
	heavy.add_venom(stagger_at + 2)
	light.add_venom(2)
	far.add_venom(3)
	var stacks: int = heavy.venom
	var left: float = heavy.venom_left()
	var per: float = p.bonds["hand"].spell_damage(p.bonds["hand"].spells().filter(func(sp): return sp["id"] == "virulence")[0])
	var paid := await _cast("virulence")
	var hb = p.bonds["hand"]
	var back: float = 2.0 * float(_stat("virulence", "refill")) * hb.spell_cost(hb.data()["spells"][0])  # (its Apex: the two foes it bursts refill the mark)
	_check(is_equal_approx(paid, float(_stat("virulence", "cost")) - back), "Virulence costs %.0f, less what the 2 foes it bursts give back (%.0f)" % [float(_stat("virulence", "cost")), paid])
	var dealt: float = heavy.max_hp - heavy.hp
	_check(heavy.venom == 0 and dealt >= left + per * stacks - 0.5, "...a poisoned foe takes all its poison at once and bursts for more a stack (%.0f of at least %.0f)" % [dealt, left + per * stacks])
	_check(heavy.stun > 0.0 and light.stun <= 0.0, "...a heavily stacked foe is staggered; a lightly poisoned one isn't")
	var spread := int(ceil(float(stacks) * float(_stat("virulence", "spread"))))
	_check(clean.venom == spread, "...the burst poisons a foe beside it that wasn't (%d stacks)" % clean.venom)
	_check(far.venom == 3 and far.hp == far.max_hp, "...and a poisoned foe out of reach is left alone")


# --- Carry -----------------------------------------------------------------------

func _carry() -> void:
	print("the rework: Carry")
	await _marked("tidecaller", 4)
	var main = t.main
	var p = main.player
	var side: Vector2 = dir.orthogonal()
	var dmg: float = float(_stat("carry", "damage"))
	var collide: float = float(_stat("carry", "collide"))
	var a = _foe(p.global_position + dir * 60.0)
	var b = _foe(p.global_position + dir * 95.0 + side * 40.0)
	var start: Vector2 = p.global_position
	var paid := await _cast("carry")
	await t._wait(1.0)
	_check(is_equal_approx(paid, float(_stat("carry", "cost"))), "Carry costs %.0f" % paid)
	var lat := absf((b.global_position - start).dot(side))
	_check((a.global_position - start).dot(dir) > 150.0 and lat < 30.0, "...the wave carries foes along and gathers them together (%.0f off the middle)" % lat)
	_check(a.max_hp - a.hp >= dmg + collide - 0.5 and b.max_hp - b.hp >= dmg + collide - 0.5,
		"...striking each as it's picked up, and again as they crash into each other (%.0f, %.0f)" % [a.max_hp - a.hp, b.max_hp - b.hp])
	# A wall in its way: dashed against it, a bonus on top.
	await _marked("tidecaller", 4)
	main = t.main
	p = main.player
	var c = _foe(p.global_position + dir * 60.0)
	var wall_at: Vector2 = p.global_position + dir * 180.0
	main.add_stone_wall(load("res://scripts/bond.gd")._line_points(wall_at, dir, 120.0, 16.0), 11.0, 5.0)
	await t._frames(2)
	await _cast("carry")
	await t._wait(1.0)
	var crash: float = float(_stat("carry", "crash"))
	_check(c.max_hp - c.hp >= dmg + crash - 0.5 and c.stun > 0.0, "...and a wall in its way dashes them against it for more, stunned (%.0f)" % (c.max_hp - c.hp))


# --- the Grafter -----------------------------------------------------------------

func _grafter() -> void:
	print("the rework: the Grafter")
	await _marked("grafter", 1)
	var main = t.main
	var p = main.player
	var side: Vector2 = dir.orthogonal()
	var dmg: float = float(_stat("graft_burst", "damage"))
	var radius: float = float(_stat("graft_burst", "radius"))
	var a = _foe(p.global_position + dir * 60.0)
	var b = _foe(p.global_position + dir * (radius - 15.0) * 0.8 + side * (radius - 15.0) * 0.5)
	var weak = _foe(p.global_position - dir * 50.0, 400.0, "knight")
	weak.hp = 3.0
	_check(main.grafts.is_empty(), "(no grafts yet)")
	await _cast("graft_burst")
	_check(a.max_hp - a.hp >= dmg - 0.5 and b.max_hp - b.hp >= dmg - 0.5, "Graft Burst with no grafts strikes every foe near you (%.0f, %.0f)" % [a.max_hp - a.hp, b.max_hp - b.hp])
	_check((not is_instance_valid(weak) or weak.dead) and main.graft_drops.size() == 1 and main.graft_drops[0]["kind"] == "knight", "...and a foe it slays always leaves a graft")
	p.global_position = main.graft_drops[0]["pos"]
	await t._wait(0.2)
	_check(main.grafts.size() == 1, "...which binds when you walk over it")
	p.global_position = a.global_position - dir * 60.0
	var hp0: float = a.hp
	await _cast("graft_burst")
	var per: float = float(_stat("graft_burst", "per_graft"))
	_check(hp0 - a.hp >= dmg + per - 0.5, "...and every graft adds to it (%.0f)" % (hp0 - a.hp))
	# Grafts come sooner: likeliest while you have few, never less often than before.
	var M = load("res://scripts/main.gd")
	_check(M.graft_chance(0) > M.graft_chance(3) and M.graft_chance(3) >= 0.3 and M.graft_chance(0) >= 0.5,
		"slain monsters leave grafts more often while you have few (%.2f with none, %.2f with three)" % [M.graft_chance(0), M.graft_chance(3)])
	# Mimic with no graft: the trick of the foe you aim at (a knight's: a heavy blow).
	await _marked("grafter", 2)
	main = t.main
	p = main.player
	var knight = _foe(p.global_position + dir * 50.0, 400.0, "knight")
	await _cast("mimic")
	_check(knight.hp < knight.max_hp, "Mimic with no graft copies the trick of the foe you aim at (%.0f)" % (knight.max_hp - knight.hp))
	# Shed with no graft: a lesser burst, and the mark's burn healed.
	await _marked("grafter", 4)
	main = t.main
	p = main.player
	var s = _foe(p.global_position + dir * 60.0)
	var bond = p.bonds["hand"]
	bond.select(bond.spells().map(func(sp): return sp["id"]).find("shed"))
	bond.essence = 0.0
	bond.burned = false
	p.attack_cd = 0.0
	p.cast_t = 0.0
	p._try_cast("hand")  # (overdrawn: the hand burns, and shedding your skin heals it)
	await t._wait(bond.windup() + 0.2)
	var bare: float = float(_stat("shed", "damage")) * float(_stat("shed", "bare")) * bond.OVERDRAW_POWER
	_check(s.max_hp - s.hp >= bare - 0.5 and not bond.burned, "Shed with no graft sheds a layer of skin: a lesser burst that heals the mark's burn (%.0f)" % (s.max_hp - s.hp))


# --- the Unbound: Volley and Vault -----------------------------------------------

func _ub() -> void:
	await t._ub_fresh()
	var main = t.main
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.player.iframes = 9999.0
	main.player.mouse_aim = false
	main.player.aim = Vector2.RIGHT
	main.unbound.waver_chance = 0.0
	for e in main.enemies():
		e.queue_free()
	await t._frames(2)
	main.player.global_position = main.room.get_center()


func _volley() -> void:
	print("the rework: Volley")
	await _ub()
	var main = t.main
	var p = main.player
	var T = load("res://scripts/technique.gd")
	var v: Dictionary = F.FORMS["volley"]
	var e = _foe(p.global_position + Vector2(90, 0), 2000.0)
	T.cast({"part": "hand", "shape": "volley", "kinds": ["stone"]}, p, 1.0, main.unbound)
	await t._wait(0.8)
	var plain: float = float(v["damage"]) * int(v["count"])
	_check(e.max_hp - e.hp > plain * 1.1, "Volley's bolts on the same foe add up (%.0f, more than %.0f)" % [e.max_hp - e.hp, plain])
	e.queue_free()
	# A foe just outside the fan: the bolts bend toward it.
	var half := deg_to_rad(float(v["spread"])) * (int(v["count"]) - 1) * 0.5
	var off = _foe(p.global_position + Vector2.RIGHT.rotated(half + 0.3) * 110.0, 2000.0)
	await t._frames(2)
	T.cast({"part": "hand", "shape": "volley", "kinds": ["stone"]}, p, 1.0, main.unbound)
	await t._wait(0.8)
	_check(off.hp < off.max_hp, "...and they bend a little toward a foe just outside the fan")


func _vault() -> void:
	print("the rework: Vault")
	await _ub()
	var main = t.main
	var p = main.player
	var T = load("res://scripts/technique.gd")
	var v: Dictionary = F.FORMS["vault"]
	var e = _foe(p.global_position + Vector2(30, 0), 2000.0)
	T.cast({"part": "legs", "shape": "vault", "kinds": ["stone"]}, p, 1.0, main.unbound)
	_check(p.iframes >= float(v["untouchable"]) - 0.01, "Vault leaves you untouchable for %.1f seconds" % float(v["untouchable"]))
	var node = main.get_node_or_null(F.NODE)
	_check(node != null and node.pieces.any(func(pc): return pc["kind"] == "ground"), "...and its burst stays on the ground where you stood")
	await t._frames(2)
	var first: float = e.max_hp - e.hp
	await t._wait(float(v["tick"]) * int(v["pulses"]) + 0.3)
	var more: float = e.max_hp - e.hp - first
	_check(first > 0.0 and more > 0.0, "...bursting again with the technique's effect (%.0f, then %.0f more)" % [first, more])
