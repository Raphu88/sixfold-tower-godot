extends RefCounted
## Fatigue (the owner: "when you run out and continue to perform actions
## that use stamina, the bar loses max capacity. A stamina vial should
## restore the lost capacity"): acting past empty takes the shortfall off
## max stamina, down to a floor; stamina refills only to the shrunken bar;
## the stair leaves it, a Stamina Vial, a camp's rest and a new climb clear
## it; the HUD and the Entity say so; the Healing and Stamina Vials' names.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const Combat := preload("res://scripts/combat.gd")
const I := preload("res://scripts/items.gd")
const Entity := preload("res://scripts/entity.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const Guide := preload("res://scripts/guide.gd")

var t


func run(smoke) -> void:
	t = smoke
	print("fatigue: acting past empty shrinks max stamina")
	await _fatigue()
	_words()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _fresh():
	await t._fresh_main()
	t.paused = false
	var m = t.main
	m.first_climb = false
	for x in m.enemies():
		x.queue_free()
	await t._frames(2)
	var p = m.player
	p.global_position = m.room.get_center()
	p.aim = Vector2.RIGHT
	p.mouse_aim = false
	return p


## One roll from where the climber stands; what it cost.
func _roll(p) -> bool:
	p.roll_cd = 0.0
	p.attack_cd = 0.0
	p.roll_t = 0.0
	return p._try_roll(Vector2.RIGHT) and p.roll_t > 0.0


func _fatigue() -> void:
	var p = await _fresh()
	var m = t.main
	_check(p.fatigue == 0.0 and is_equal_approx(p.sta_cap(), p.max_sta), "a climb starts with no fatigue: max stamina whole (%.0f)" % p.sta_cap())
	# Today's feel with stamina to spare: a roll costs stamina, nothing more.
	p.sta = p.max_sta
	_check(_roll(p), "a roll with stamina to spare")
	var cost: float = p.max_sta - p.sta
	_check(cost > 5.0 and p.fatigue == 0.0, "...costs stamina (%.0f) and no fatigue" % cost)
	# At zero: the roll still happens, and its cost comes off max stamina.
	Engine.set_meta("sixfold_tips", true)
	Guide.forget()
	p.sta = 0.0
	_check(_roll(p), "a roll with no stamina left still happens")
	_check(absf(p.fatigue - cost) < 0.01 and absf(p.sta_cap() - (p.max_sta - cost)) < 0.01 and p.sta == 0.0,
		"...and its whole cost comes off max stamina as fatigue (%.1f lost, cap %.1f)" % [p.fatigue, p.sta_cap()])
	_check(Guide.queue.any(func(q): return q.get("id", "") == "fatigue") or Guide.told("fatigue") or Guide.known("fatigue"),
		"the first fatigue: the Entity explains it")
	Guide.queue.clear()
	Engine.remove_meta("sixfold_tips")
	# Short, not empty: only the missing part is fatigue.
	p.sta = cost * 0.5
	var f0: float = p.fatigue
	_check(_roll(p) and absf(p.fatigue - f0 - cost * 0.5) < 0.01, "short of a roll: only the missing half comes off (%.1f)" % (p.fatigue - f0))
	# Down to the floor, never past it: then the roll is too winded.
	var floor_cap: float = p.max_sta * float(Combat.CLIMBER["fatigue_floor"])
	var rolls := 0
	for i in 40:
		p.sta = 0.0
		if not _roll(p):
			break
		rolls += 1
	_check(rolls > 0 and rolls < 40 and p.sta_cap() >= floor_cap - 0.01 and p.fatigue_room() < cost,
		"fatigue stops at the floor: max stamina never below %d%% (%.1f of %.0f)" % [int(round(float(Combat.CLIMBER["fatigue_floor"]) * 100.0)), p.sta_cap(), p.max_sta])
	p.sta = 0.0
	var f1: float = p.fatigue
	_check(not _roll(p) and p.fatigue == f1 and p.sta == 0.0, "at the floor and empty, a roll is too winded (nothing spent)")
	p.fatigue = p.max_sta * (1.0 - float(Combat.CLIMBER["fatigue_floor"]))  # (right at the floor)
	f1 = p.fatigue
	# A strike at the floor with a little stamina still goes, as always.
	p.sta = 2.0
	p.attack_cd = 0.0
	p.combo_t = 0.0
	_check(p._try_attack() and p.sta == 0.0 and p.fatigue == f1, "a strike on a sliver of stamina at the floor still goes (the rest let off)")
	p.attack_cd = 0.0
	_check(p._try_attack() and p.attack_cd <= 0.0, "...but with none at all it's too winded")
	# Regen fills only to the shrunken bar.
	p.attack_cd = 0.0
	p.sta = 0.0
	p.sta_delay = 0.0
	p.drawing = false
	for i in 80:
		p._tick_timers(0.1)
	_check(absf(p.sta - p.sta_cap()) < 0.01 and p.sta < p.max_sta - 10.0, "stamina refills only to the shrunken bar (%.1f of %.0f)" % [p.sta, p.max_sta])
	p.sta = p.max_sta  # (anything that fills it past the cap is cut back)
	p._tick_timers(0.05)
	_check(p.sta <= p.sta_cap() + 0.01, "...and nothing fills it past")
	# The HUD: the stamina bar's hover help names fatigue.
	m.hud.core.queue_redraw()
	await t._frames(2)
	var tip_lines: Array = []
	for tp in m.hud.tips:
		if String(tp[1]).begins_with("Health"):
			tip_lines = tp[2]
	_check(tip_lines.any(func(l): return String(l).contains("Fatigue")), "the stamina bar's hover help names fatigue %s" % [tip_lines])
	# The stair's rest: stamina refills, fatigue stays.
	var f2: float = p.fatigue
	m.floor_num = 4
	m._arrive()
	await t._frames(2)
	p = m.player
	_check(absf(p.fatigue - f2) < 0.01 and absf(p.sta - p.sta_cap()) < 0.5, "the stair fills stamina but leaves fatigue (%.1f)" % p.fatigue)
	# A Stamina Vial: usable with the bar full, it gives max stamina back.
	p.items = {"stamina": 2}
	p.item_sel = "stamina"
	p.sta = p.sta_cap()
	_check(p.use_item() and p.fatigue == 0.0 and is_equal_approx(p.sta, p.max_sta) and p.item_count("stamina") == 1,
		"a Stamina Vial, even with the bar full: fatigue gone, max stamina whole and full (%.0f)" % p.sta)
	_check(not p.use_item() and p.item_count("stamina") == 1, "...and not wasted with nothing to restore")
	# A camp's full rest clears it too.
	p.fatigue = 30.0
	m._enter_camp([])
	await t._frames(2)
	_check(m.player.fatigue == 0.0 and is_equal_approx(m.player.sta, m.player.max_sta), "a camp's rest clears fatigue")
	m._leave_camp_now()
	# A new climb starts with full capacity (the climb start, and a fresh climb).
	m.player.fatigue = 30.0
	m._note_climb_start()
	_check(m.player.fatigue == 0.0, "a climb's start clears fatigue")
	m.player.fatigue = 30.0
	p = await _fresh()
	_check(p.fatigue == 0.0 and is_equal_approx(p.sta, p.max_sta) and is_equal_approx(p.sta_cap(), p.max_sta), "a new climb starts with max stamina whole")
	# Gear can't break the floor: a smaller max stamina keeps the cap at its share.
	p.fatigue = p.max_sta
	_check(p.sta_cap() >= p.max_sta * float(Combat.CLIMBER["fatigue_floor"]) - 0.01 and p.fatigue_room() == 0.0, "the cap never drops below the floor, whatever fatigue says")
	p.fatigue = 0.0


func _words() -> void:
	print("fatigue: the words")
	_check(I.item_name("draught") == "Healing Vial" and I.item_name("stamina") == "Stamina Vial" and I.item_name("haste") == "Haste Draught",
		"the staples are the Healing Vial and the Stamina Vial (the Haste Draught stays)")
	_check(String(I.ITEMS["stamina"]["desc"]).contains("fatigue"), "the Stamina Vial's words say it shakes off fatigue")
	_check(Entity.TIPS.has("fatigue") and String(Entity.TIPS["fatigue"]["tip"]).contains("Stamina Vial"), "the Entity has a tip for fatigue")
	_check(Talk.DIALOGUE["how"]["choices"].has("how_stamina") and Talk.line_for(null, "how_stamina").contains("%d%%" % int(round(float(Combat.CLIMBER["fatigue_floor"]) * 100.0))),
		"\"How do things work here?\" answers stamina and fatigue, with the floor from the numbers")
	var banned := ["attunement", "spire", "trial", "judgment", "mana"]
	var said: String = (String(Entity.TIPS["fatigue"]["tip"]) + String(Entity.TIPS["fatigue"]["more"]) + Talk.line_for(null, "how_stamina") + String(Combat.TEXT["hud_fatigue"]) + String(I.ITEMS["stamina"]["desc"])).to_lower()
	_check(banned.all(func(w): return not said.contains(w)), "no banned words in fatigue's words")
	# No old names left in the game's words.
	var left: Array = []
	for f in DirAccess.get_files_at("res://scripts"):
		if f.ends_with(".gd"):
			var src := FileAccess.get_file_as_string("res://scripts/" + f)
			if src.contains("Healing Draught") or src.contains("Stamina Draught"):
				left.append(f)
	_check(left.is_empty(), "no Healing or Stamina Draught left in the scripts %s" % [left])
