extends RefCounted
## The Rekindler, made to play well (bonds.gd "rekindler", bond.gd and
## player.gd), and the Surgeon's Transfer: every spell does something you
## can see in a fight. Rekindle's flames burn the foes near you and count as
## fighting; Desperation is felt at full health and more as health runs
## out; Pyre Oath makes the foes you slay burst; Phoenix Heart rises in a
## burst of flame; Last Ember lets you rise again with a share of your
## health; Transfer always hits and heals. Run by smoke_test.gd (_part_tests).

const B := preload("res://scripts/bonds.gd")
const P := preload("res://scripts/profile.gd")

var t


func run(smoke) -> void:
	t = smoke
	print("the Rekindler plays well; the Surgeon's Transfer")
	await _rekindle()
	await _desperation()
	await _pyre()
	await _phoenix()
	await _last_ember()
	await _transfer()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## A climber with `bond_id` alone on the back at `step`; foes frozen.
func _bonded(bond_id: String, step: int) -> void:
	await t._fresh_main()
	t.paused = false
	var main = t.main
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.profile.add_bond("back", bond_id, false)
	main.profile.bonds["back"]["xp"] = float(P.STEP_XP[step - 1])
	main.profile.regarded = true
	main.first_climb = false
	main._give_bonds()
	main.player.aim = Vector2.RIGHT
	for e in main.enemies():
		e.set_physics_process(false)


## Casts `spell_id` (paid from a full mark) at once.
func _cast(spell_id: String) -> void:
	var p = t.main.player
	var b = p.bonds["back"]
	b.select(b.spells().map(func(sp): return sp["id"]).find(spell_id))
	b.essence = b.capacity()
	p.cast_part = "back"
	p.attack_cd = 0.0
	p._release_cast()


## Foes with `hp` at `offsets` from the climber; the rest sent far away.
func _foes(offsets: Array, hp := 300.0) -> Array:
	var main = t.main
	var p = main.player
	var all: Array = main.enemies().filter(func(e): return e.kind != "lurker" and not e.is_boss())
	for e in main.enemies():
		if not e in all:
			e.global_position = p.global_position + Vector2(-5000.0, -5000.0)
	var out: Array = []
	for i in all.size():
		var e = all[i]
		if i < offsets.size():
			e.hp = hp
			e.max_hp = hp
			e.global_position = p.global_position + offsets[i]
			out.append(e)
		else:
			e.global_position = p.global_position + Vector2(-4000.0 - 60.0 * i, -4000.0)
	return out


func _sp(bond_id: String, spell_id: String) -> Dictionary:
	for sp in B.BONDS[bond_id]["spells"]:
		if sp["id"] == spell_id:
			return sp
	return {}


func _rekindle() -> void:
	await _bonded("rekindler", 1)
	var p = t.main.player
	var foes := _foes([Vector2(40, 0), Vector2(400, 0)])
	p.iframes = 999.0
	p.hp = p.max_hp * 0.5  # (room for the payback)
	var h0: float = p.hp
	_cast("rekindle")
	await t._game_wait(1.2)
	_check(foes[0].hp < 300.0 and foes[1].hp == 300.0, "Rekindle: flames around you burn the foe beside you (%.0f), not one far off" % (300.0 - foes[0].hp))
	_check(p.hp < h0 and p.rekindle_fought, "...you lose a little health while you burn, and the flames count as fighting")
	var lost: float = p.rekindle_lost
	p.rekindle_t = 0.01
	await t._game_wait(0.1)
	_check(p.hp > h0 - lost + lost * 1.5, "...and the payback comes without a single strike (+%.0f)" % (p.hp - (h0 - lost)))
	_check(bool(B.BONDS["rekindler"]["spells"][0]["steps"][1]["spread"]), "its flames are there from step 1")


func _desperation() -> void:
	await _bonded("rekindler", 2)
	var p = t.main.player
	_cast("desperation")
	_check(p.desperate_t > 0.0 and p.desperate_power > 0.0 and p.desperate_power_low > p.desperate_power, "Desperation: some power at full health (%.2f), more as health runs out (%.2f)" % [p.desperate_power, p.desperate_power_low])
	var foe = _foes([Vector2(30, 0)])[0]
	p.hp = p.max_hp
	p.attack_cd = 0.0
	p.aim = Vector2.RIGHT
	var before: float = foe.hp
	p._melee()
	var full: float = before - foe.hp
	await t._game_wait(0.6)
	p.desperate_t = 0.0
	p.attack_cd = 0.0
	p.combo = 0
	before = foe.hp
	p._melee()
	var plain: float = before - foe.hp
	_check(full > plain * 1.15, "...at full health a struck foe takes more than without it (%.1f vs %.1f)" % [full, plain])


func _pyre() -> void:
	await _bonded("rekindler", 4)
	var p = t.main.player
	var foes := _foes([Vector2(200, 0), Vector2(240, 0)], 300.0)
	_cast("pyre_oath")
	foes[0].take_hit(9999.0, Vector2.ZERO, 0.0)
	_check(foes[1].hp < 300.0, "Pyre Oath: a foe slain while it lasts bursts into flame and burns the one beside it (%.0f)" % (300.0 - foes[1].hp))
	p.pyre_t = 0.0


func _phoenix() -> void:
	await _bonded("rekindler", 5)
	var foes := _foes([Vector2(60, 0), Vector2(600, 0)])
	_cast("phoenix_heart")
	_check(foes[0].hp < 300.0 and foes[1].hp == 300.0, "Phoenix Heart: you rise in a burst of flame that burns the foes near you (%.0f)" % (300.0 - foes[0].hp))
	_check(t.main.player.phoenix_t > 0.0, "...and the death-defying part still holds")


func _last_ember() -> void:
	await _bonded("rekindler", 1)
	var p = t.main.player
	var foe = _foes([Vector2(30, 0)])[0]
	p.iframes = 0.0
	p.hurt_t = 0.0
	p.receive_attack(9999.0, null)
	_check(not p.dead and p.ember_t > 0.0 and p.hp <= 1.0, "Last Ember: a killing blow leaves you burning at 1 health")
	p._strike(foe, 1.0, Vector2.RIGHT, 0.0, false)
	var want: float = p.max_health() * float(B.BONDS["rekindler"]["passive"]["rise"])
	_check(p.ember_t <= 0.0 and absf(p.hp - want) < 1.0, "...land a hit and you rise again with a share of your health (%.0f of %.0f)" % [p.hp, want])


func _transfer() -> void:
	await _bonded("surgeon", 4)
	var p = t.main.player
	var foe = _foes([Vector2(80, 0)])[0]
	p.aim = Vector2.RIGHT
	p.hp = p.max_health() * 0.5
	var h0: float = p.hp
	_cast("transfer")
	var dealt: float = 300.0 - foe.hp
	var sp := _sp("surgeon", "transfer")
	var want: float = float(sp["steps"][4]["damage"]) + minf(p.max_health() * 0.5 * float(sp["steps"][4]["share"]), float(sp["steps"][4]["most"]))
	_check(absf(dealt - want) < 1.5, "Transfer: the foe takes your wounds even with no poison or burns (%.0f, want %.0f)" % [dealt, want])
	_check(p.hp > h0 + dealt * 0.4, "...and you heal half of what it takes (+%.0f)" % (p.hp - h0))
