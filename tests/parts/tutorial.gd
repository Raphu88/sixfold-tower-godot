extends RefCounted
## Basic training as ONE SESSION (tutorial.gd, arena.gd "basics",
## station_page.gd's basic tile and card): every step present, in order, and
## covering the whole basic moveset (walking, jumping with one moving jump,
## rolling, striking, the finisher, swapping to the bow, the full draw, the
## off-hand wand, powering it, parrying, blocking with a shield, the belt and
## its wheel), the weapons in the owner's order (melee, unarmed, ranged,
## off-hand); the session run from its first step to its last without
## leaving the arena, each step advancing only on its own action (the wrong
## weapon, a weak shot, a standing jump, an item used without the wheel
## don't count); every past and loadout finishing it (the Soldier, the
## Sailor's pistol, the Hunter, a two-handed war hammer, no ranged weapon,
## no melee weapon with a crossbow...): the ranged step worded for the weapon
## and taking a pistol's shot or a bow's full draw, weapons lent and put
## back; the off-hand put away by a two-handed weapon (the game's rule, the
## HUD's coin and its card, the Entity's tip); done, the six old parts marked done, renown once, the first
## tournament open; left part way, Resume from that step and Start over;
## skipping (refused for a first-timer before the Grace, allowed after);
## the prompts in keys, controller buttons and touch buttons; the Entity's
## words and button help; no banned words. Run by smoke_test.gd
## (_part_tests); `t` is the smoke test.

const Tutorial := preload("res://scripts/tutorial.gd")
const Stations := preload("res://scripts/stations.gd")
const Training := preload("res://scripts/training.gd")
const Travel := preload("res://scripts/travel.gd")
const Renown := preload("res://scripts/renown.gd")
const Entity := preload("res://scripts/entity.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const Help := preload("res://scripts/entity_help.gd")
const Offhand := preload("res://scripts/offhand.gd")
const ItemPool := preload("res://scripts/item_pool.gd")
const Gear := preload("res://scripts/gear.gd")
const Registry := preload("res://scripts/data_registry.gd")

const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]
const Weapons := preload("res://scripts/weapons.gd")
const ORDER := ["walk", "jump", "roll", "strike", "finisher", "fists", "ranged", "offhand", "power", "parry", "block", "belt"]
## The pasts and loadouts that must all finish it: [what, melee, ranged].
const LOADOUTS := [["Soldier", "sword", "shortbow"], ["Sailor", "sword", "flintlock"], ["Hunter", "dagger", "shortbow"],
	["a two-handed war hammer (the Labourer)", "war_hammer", "shortbow"], ["no ranged weapon", "sword", ""], ["no melee weapon, a crossbow", "", "crossbow"],
	["a greatsword and a revolver", "greatsword", "revolver"], ["a spear and a sling", "spear", "sling"]]

var t


func run(smoke) -> void:
	t = smoke
	print("tutorial: basic training as one session")
	await t._fresh_main()
	var main = t.main
	main.touch._set_active(false)
	main.pad._set_active(false)
	for e in main.enemies():
		e.queue_free()
	_steps()
	await _two_hands(main)
	await _whole(main)
	await _loadouts(main)
	await _leave_and_resume(main)
	await _skip(main)
	_prompts(main)
	_words(main)
	main.menu.station_page.station = ""
	main.menu.close()
	t.paused = false
	main.on_train = false
	await t._frames(2)


func _buttons(menu, meta: String, val) -> Array:
	return t._all_buttons(menu.box).filter(func(b): return b.has_meta(meta) and b.get_meta(meta) == val)


func _phys(n := 2) -> void:
	for i in n:
		await t.physics_frame


func _wait_done(main, seconds := 8.0) -> void:
	await t._until(func(): return not main.arena.on, seconds)
	await t._frames(3)


## Back at the gym's card for basic training.
func _to_gym(main) -> void:
	main.menu.go_station(Travel.home(main.profile), "gym")
	await t._frames(3)


# --- the steps -----------------------------------------------------------------------------

func _steps() -> void:
	var ids: Array = Tutorial.step_ids()
	t._check(ids == ORDER, "basic training's steps, in order: %s" % [ids])
	t._check(Tutorial.count() % 6 == 0, "...a count by sixes (%d)" % Tutorial.count())
	var kinds: Array = Tutorial.STEPS.map(func(d): return String(d["kind"]))
	for k in ["posts", "jump", "roll", "strike", "finisher", "fists", "ranged", "wand", "power", "parry", "block", "belt"]:
		t._check(kinds.has(k), "a step watches for: %s" % k)
	var at := func(id): return ORDER.find(id)
	t._check(at.call("strike") < at.call("finisher") and at.call("finisher") < at.call("fists") and at.call("fists") < at.call("ranged") and at.call("ranged") < at.call("offhand") and at.call("offhand") < at.call("power"),
		"the weapons in the owner's order: melee, unarmed, ranged, off-hand")
	for id in ["offhand", "power", "block"]:
		t._check(bool(Tutorial.STEPS[ORDER.find(id)].get("free_hand", false)), "%s: done with a free hand (a two-handed melee weapon gives way to a lent sword)" % id)
	for d in Tutorial.STEPS:
		var ok: bool = String(d.get("name", "")) != "" and String(d.get("goal", "")).contains("{") and String(d.get("say", "")).length() > 40 and String(d.get("hint", "")).contains("{")
		t._check(ok, "%s: a name, a goal and a hint in your keys, and the Entity's word" % d["id"])
	t._check(Tutorial.STEPS.filter(func(d): return String(d.get("lend", "")) != "").size() >= 2, "it lends an off-hand wand and a shield for their steps")


# --- one session, start to end ---------------------------------------------------------------

func _whole(main) -> void:
	var prof = main.profile
	var menu = main.menu
	var arena = main.arena
	prof.home = "kraken"
	prof.station = ""
	Renown.state(prof)["lessons"] = {}
	Renown.state(prof).erase("tutorial")
	Training.require(prof)
	main.await_tower()
	main.open_train()
	menu.go_station(Travel.home(prof))
	await t._frames(3)
	t._check(menu.page == "station" and menu.station_page.stop == "gym" and String(menu.station_page.picks.get("gym", "")) == "basics:basics", "a new climber's station opens on basic training")
	var tiles: Array = t._all_buttons(menu.box).filter(func(b): return b.has_meta("pick") and String(b.get_meta("pick")).begins_with("lesson:"))
	t._check(_buttons(menu, "pick", "basics:basics").size() == 1 and tiles.is_empty(), "the gym has one basic training tile, not separate lessons")
	var want_skip := Tutorial.can_skip(prof)
	t._check(want_skip == (Training.can_skip(prof) or Tutorial.experienced()) and not Training.can_skip(prof), "before the Grace only an experienced player may skip it")
	t._check(_buttons(menu, "station_do", "skip").size() == (1 if want_skip else 0), "...and the card shows Skip only then")
	var begin: Array = _buttons(menu, "station_do", "begin")
	t._check(begin.size() == 1 and not Help.missing(begin[0]), "the card has Begin, which explains itself")
	var renown0 := Renown.points(prof)
	var dens0 := _density(prof)
	if begin.size() == 1:
		begin[0].pressed.emit()
	await t._frames(3)
	var p = main.player
	t._check(arena.on and String(arena.ev.get("type", "")) == "basics" and arena.tut != null and arena.tut.i == 0 and not main.on_train and not menu.is_open(), "Begin: the session starts in the arena at its first step")
	p.iframes = 999.0
	p.mouse_aim = false
	var stayed := true
	for k in ORDER.size():
		var id: String = ORDER[k]
		var tut = arena.tut
		var here: bool = arena.on and tut != null and tut.i == k
		t._check(here, "step %d is %s" % [k + 1, id])
		if not here:
			return
		var chip: Array = main.hud.status_chips().filter(func(c): return String(c.get("id", "")) == "arena")
		t._check(not chip.is_empty() and String(chip[0]["text"]).contains("Step %d of %d" % [k + 1, ORDER.size()]) and not String(chip[0]["text"]).contains("{"), "%s: the line at the top says the step and what to do, in your keys (%s)" % [id, chip[0]["text"] if not chip.is_empty() else ""])
		await _do(main, id)
		await _phys(3)
		if k < ORDER.size() - 1:
			t._check(arena.on and arena.tut != null and arena.tut.i == k + 1, "%s: done, on to the next step at once" % id)
		stayed = stayed and arena.on and not main.on_train and not menu.is_open()
		if not arena.on:
			break
	t._check(stayed, "the whole session ran in one sitting: never back to the menu between steps")
	t._check(arena.done, "the last step done ends the session")
	await _wait_done(main)
	p.iframes = 0.0
	t._check(bool(Tutorial.state(prof)["done"]) and Tutorial.passed(prof) and Training.basic_done(prof), "basic training is done, and remembered")
	t._check(Stations.LESSON_ORDER.all(func(id): return Stations.lesson_state(prof, id) == 1), "...every part of the old basic training marked done")
	t._check(Renown.points(prof) == renown0 + Stations.LESSON_REWARD, "...its renown paid once (%d)" % (Renown.points(prof) - renown0))
	t._check(Stations.why_not(prof, "first", "first", "kraken") == "", "...and the first tournament opens")
	var want := Tutorial.STEP_ESSENCE * Tutorial.count() * float(Training.RATES["basics"]["rate"])
	t._check(absf((_density(prof) - dens0) - want) < 0.5 and prof.bonds.is_empty(), "the steps gave a quarter of the usual essence, into the body (%.1f of %.1f)" % [_density(prof) - dens0, want])
	t._check(menu.page == "station" and menu.station_page.stop == "gym" and not menu.station_page.lines.is_empty(), "back at Training, the result on its card")
	t._check(Offhand.piece(p).is_empty(), "nothing lent is kept")


func _density(prof) -> float:
	var n := 0.0
	for k in prof.density:
		n += float(prof.density[k])
	return n


## Does one step's action (the way the game's own buttons would leave it),
## after checking that the wrong thing doesn't count.
func _do(main, id: String) -> void:
	var arena = main.arena
	var tut = arena.tut
	var p = main.player
	p.sta = p.max_sta
	match id:
		"walk":
			t._check(arena.posts.size() == 3, "walk: three posts to touch")
			for at in arena.posts.duplicate():
				p.global_position = at
				await _phys()
		"jump":
			for i in 2:
				p.jump_vel = Vector2.ZERO
				p.jump_t = 0.3
				await _phys()
				p.jump_t = 0.0
				await _phys()
			t._check(tut.i == 1 and tut.n == 2, "jump: two standing jumps aren't enough; one must move")
			p.jump_vel = Vector2(120, 0)
			p.jump_t = 0.3
			await _phys()
			p.jump_t = 0.0
		"roll":
			t._check(tut.foes().size() == 1 and String(tut.foes()[0].kind) == "archer", "roll: an archer shoots, so the arrows can pass through you")
			for i in 2:
				p.roll_t = 0.3
				await _phys()
				p.roll_t = 0.0
				await _phys()
		"strike":
			t._check(tut.foes().is_empty() and arena.dummies.size() == 2, "strike: the archer gone, two dummies close by")
			p.pending_weapon = ""
			var melee := String(p.gear_id("melee"))
			t._check(melee != "" and String(Weapons.WEAPONS[melee]["slot"]) == "melee", "strike: a melee weapon to strike with (%s)" % melee)
			t._check(tut.words(Tutorial.STEPS[3], "say").contains(String(Weapons.WEAPONS[melee]["name"]).to_lower()), "strike: the Entity names your melee weapon")
			for wrong in [String(p.gear_id("ranged")), "fists"]:
				p.weapon = wrong
				arena.dummies[0].take_hit(1.0, Vector2.ZERO)
				await _phys()
			t._check(tut.n == 0, "strike: a ranged weapon's or the fists' hit doesn't count")
			p.weapon = melee
			p.swing = p.wdata()["combo"][0]
			for i in 2:
				_face(p, arena.dummies[0])
				p.attack_cd = 0.0
				p.combo_t = 0.0
				p._melee()
				await _phys()
		"finisher":
			p.weapon = String(p.gear_id("melee"))
			var chain: Array = Offhand.chain(p, p.wdata()["combo"])
			_face(p, arena.dummies[0])
			p.combo = 0
			p.combo_t = 0.0
			for i in chain.size() - 1:
				p.attack_cd = 0.0
				p._melee()
				_face(p, arena.dummies[0])
				await _phys()
			t._check(tut.i == 4 and tut.n == 0, "finisher: plain blows aren't a finisher")
			p.attack_cd = 0.0
			p._melee()
			await _phys()
		"fists":
			t._check(arena.dummies.size() == 2 and tut.words(Tutorial.STEPS[5], "goal").contains("fists"), "fists: two dummies close by, and the line says to swap to your fists")
			p.weapon = String(p.gear_id("melee"))
			arena.dummies[0].take_hit(1.0, Vector2.ZERO)
			await _phys()
			t._check(tut.n == 0, "fists: a melee weapon's hit doesn't count")
			p.weapon = "fists"
			p.swing = p.wdata()["combo"][0]
			for i in 2:
				_face(p, arena.dummies[0], 22.0)
				p.attack_cd = 0.0
				p.combo_t = 0.0
				p._melee()
				await _phys()
		"ranged":
			t._check(arena.dummies.size() == 2 and arena.dummies[0].position.y < main.OPEN_ROOM.position.y + 120.0, "ranged: two far dummies")
			var rid := String(p.gear_id("ranged"))
			var w: Dictionary = Weapons.WEAPONS.get(rid, {})
			var d: Dictionary = Tutorial.STEPS[6]
			var say: String = tut.words(d, "say")
			var goal: String = tut.words(d, "goal")
			t._check(not say.contains("_w}") and say.contains(String(w.get("name", "?")).to_lower()), "ranged: the Entity names your %s" % rid)
			match String(w.get("kind", "")):
				"gun":
					t._check(goal.contains("fire") and not goal.contains("draw") and say.contains("reload"), "ranged: a pistol is fired, and its reload explained (%s)" % goal)
				"crossbow":
					t._check(goal.contains("fire") and say.contains("reload"), "ranged: a crossbow is fired, and its reload explained")
				_:
					t._check(goal.contains("full"), "ranged: a %s asks for a full draw (%s)" % [rid, goal])
			p.weapon = String(p.gear_id("melee"))
			arena.dummies[0].take_hit(1.0, Vector2.ZERO)
			await _phys()
			t._check(tut.n == 0, "ranged: a melee hit doesn't count")
			p.weapon = rid
			p.global_position = arena.dummies[0].position + Vector2(0, 120)
			p.aim = Vector2.UP
			p.attack_cd = 0.0
			p.reload_t = 0.0
			if String(w.get("kind", "")) == "bow":
				p.last_draw_full = false
				arena.dummies[0].take_hit(1.0, Vector2.ZERO)
				await _phys()
				t._check(tut.n == 0, "ranged: a weak draw doesn't count")
				p.drawing = true
				p.draw_t = 5.0
				p.release_draw()
			elif String(w.get("kind", "")) == "gun":
				p.ammo_left()
				p.ammo = maxi(1, int(p.ammo))
				p._fire_gun()
			else:
				p._fire_bolt()
			await t._until(func(): return tut.i != 6, 3.0)
			t._check(tut.i == 7, "ranged: a %s's %s on a far dummy is the step done" % [rid, "full draw" if String(w.get("kind", "")) == "bow" else "shot"])
		"offhand":
			t._check(Offhand.use_of(Offhand.piece(p)) == "wand", "offhand: a wand is lent")
			t._check(not Offhand.two_handed(String(p.gear_id("melee"))), "offhand: a one-handed melee weapon to hold (%s)" % p.gear_id("melee"))
			p.off_cd = 0.0
			Offhand.cast(p)
			await _phys()
			t._check(tut.i == 7, "offhand: with the ranged weapon still in hand it isn't done")
			p.off_cd = 0.0
			await _phys()
			p.weapon = String(p.gear_id("melee"))
			Offhand.cast(p)
			await _phys()
		"power":
			t._check(ItemPool.carried(main) >= float(Tutorial.STEPS[8]["carry"]) - 0.01, "power: a little essence is carried to power with")
			p.off_cd = 0.0
			t._check(ItemPool.prime(p) == "offhand", "power: holding the off-hand button primes the wand")
			Offhand.cast(p)
			await _phys()
		"parry":
			var foes: Array = tut.foes()
			t._check(foes.size() == 1 and String(foes[0].kind) == "knight" and float(foes[0].dmg) > 0.0, "parry: a soft knight whose blows glint first")
			for i in 2:
				p.on_parry.emit(null, false)
			await _phys()
		"block":
			t._check(Offhand.use_of(Offhand.piece(p)) == "shield", "block: the wand swapped for a shield")
			var foes: Array = tut.foes()
			if foes.is_empty():
				return
			var k = foes[0]
			p.aim = (k.global_position - p.global_position).normalized()
			p.parry_t = 0.0
			p.attack_cd = 0.0
			p.roll_t = 0.0
			p.jump_t = 0.0
			p.cast_t = 0.0
			p.guard_force = true
			var left: float = Offhand.block(p, 10.0, k)
			p.guard_force = false
			t._check(left >= 0.0 and left < 10.0, "block: held parry with a shield cuts the blow (%.1f of 10)" % left)
			await _phys()
		"belt":
			t._check(p.hp < p.max_health() and p.item_count("draught") >= 1 and p.item_count("stamina") >= 1, "belt: hurt a little, with vials on the belt")
			p.item_sel = "stamina"
			p.use_item()
			await _phys()
			t._check(tut.i == 11, "belt: an item used without the wheel isn't enough")
			p.ring_open = true
			await _phys()
			p.ring_open = false
			p.item_sel = "draught"
			p.use_item()
			await _phys()


func _face(p, d, gap := 30.0) -> void:
	p.global_position = d.position + Vector2(0, gap)
	p.aim = Vector2.UP


# --- every past and loadout ---------------------------------------------------------------------

## Each loadout runs the session from its first weapon step to its end:
## the steps adapt to the weapons (lent where one is missing or needs both
## hands), and everything lent goes back afterward.
func _loadouts(main) -> void:
	var prof = main.profile
	var arena = main.arena
	var p = main.player
	var keep: Dictionary = {"melee": p.gear.get("melee", {}).duplicate(true), "ranged": p.gear.get("ranged", {}).duplicate(true), "offhand": p.gear.get("offhand", {}).duplicate(true)}
	for lo in LOADOUTS:
		var what: String = lo[0]
		for k in [["melee", lo[1]], ["ranged", lo[2]]]:
			p.gear[k[0]] = Gear.make(String(k[1])) if String(k[1]) != "" else {}
		p.gear["offhand"] = {}
		p.weapon = String(lo[1]) if String(lo[1]) != "" else "fists"
		p.pending_weapon = ""
		p.drawing = false
		p.refresh_gear()
		Tutorial.state(prof)["done"] = false
		var ev: Dictionary = Stations.event("basics", "basics", "kraken")
		ev["from"] = ORDER.find("strike")
		var why: String = arena.start(ev)
		await t._frames(3)
		var tut = arena.tut
		t._check(why == "" and arena.on and tut != null and tut.i == ORDER.find("strike"), "%s: the session starts at its first weapon step" % what)
		if tut == null:
			continue
		t._check(p.gear_id("melee") != "" and p.gear_id("ranged") != "", "%s: a weapon in every slot (an empty one lent: %s)" % [what, tut.lent_weapons])
		var want_lent: Array = ([] if lo[1] != "" else ["melee"]) + ([] if lo[2] != "" else ["ranged"])
		t._check(tut.lent_weapons == want_lent, "%s: only the missing weapons are lent (%s)" % [what, tut.lent_weapons])
		p.iframes = 999.0
		p.mouse_aim = false
		for k in range(ORDER.find("strike"), ORDER.size()):
			if not arena.on or arena.tut == null or arena.tut.i != k:
				t._check(false, "%s: step %d is %s" % [what, k + 1, ORDER[k]])
				break
			if ORDER[k] == "offhand":
				var two: bool = lo[1] != "" and Offhand.two_handed(String(lo[1]))
				t._check(tut.two_w == (String(lo[1]) if two else ""), "%s: %s" % [what, "the two-handed weapon gives way to a lent sword" if two else "your own melee weapon leaves a hand free"])
				if two:
					var say: String = tut.words(Tutorial.STEPS[k], "say")
					t._check(p.gear_id("melee") == "sword" and say.contains(String(Weapons.WEAPONS[String(lo[1])]["name"]).to_lower()) and say.contains("both hands") and not say.contains("{two_w}"),
						"%s: the Entity says it needs both hands, and lends a sword (%s)" % [what, say.left(120)])
			await _do(main, ORDER[k])
			await _phys(3)
		t._check(arena.done, "%s: the session completes" % what)
		await _wait_done(main)
		p.iframes = 0.0
		t._check(p.gear_id("melee") == String(lo[1]) and p.gear_id("ranged") == String(lo[2]) and Offhand.piece(p).is_empty(), "%s: what was lent goes back (%s, %s)" % [what, p.gear_id("melee"), p.gear_id("ranged")])
	for k in keep:
		p.gear[k] = keep[k]
	p.weapon = p.gear_id("melee") if p.gear_id("melee") != "" else "fists"
	p.refresh_gear()
	Tutorial.state(prof)["done"] = true


# --- two-handed weapons: no off-hand ----------------------------------------------------------------

## The game's rule: while a weapon that needs both hands is in hand (a
## greatsword, war hammer or spear, every bow, crossbow and sling), the
## off-hand is put away: no wand, no block, no off-hand strike. One-handed
## weapons, pistols and the fists leave it free. The HUD's coin dims and its
## card says why; the Entity explains the first time.
func _two_hands(main) -> void:
	var p = main.player
	var keep: Dictionary = {"melee": p.gear.get("melee", {}).duplicate(true), "offhand": p.gear.get("offhand", {}).duplicate(true), "weapon": p.weapon}
	for id in ["greatsword", "war_hammer", "spear", "shortbow", "longbow", "crossbow", "sling"]:
		t._check(Offhand.two_handed(id), "%s needs both hands" % id)
	for id in ["sword", "dagger", "axe", "mace", "rapier", "flail", "cane", "sword_cane", "flintlock", "revolver", "fists"]:
		t._check(not Offhand.two_handed(id), "%s leaves a hand free" % id)
	p.gear["melee"] = Gear.make("war_hammer")
	p.gear["offhand"] = Gear.make("cinder_wand")
	p.weapon = "war_hammer"
	p.refresh_gear()
	p.off_cd = 0.0
	p.sta = p.max_sta
	Offhand.cast(p)
	t._check(p.off_cd <= 0.0 and Offhand.ready_use(p) == "" and not Offhand.usable(p), "a war hammer in hand: the wand can't be cast")
	p.gear["offhand"] = Gear.make("buckler")
	p.guard_force = true
	p.parry_t = 0.0
	p.attack_cd = 0.0
	t._check(not Offhand.guarding(p) and Offhand.block(p, 10.0, main.player) < 0.0, "...nor a shield block")
	p.guard_force = false
	p.gear["offhand"] = Gear.make("parrying_dagger")
	var base: Array = p.wdata()["combo"]
	t._check(Offhand.chain(p, base).size() == base.size(), "...nor an off-hand strike in the chain")
	p.weapon = "sword"
	t._check(Offhand.ready_use(p) == "weapon" and Offhand.chain(p, p.wdata()["combo"]).size() == p.wdata()["combo"].size() + 1, "a one-handed sword: the off-hand strikes again")
	# The HUD: the off-hand's coin at the weapon slot's corner, its card saying why.
	main.on_train = false
	p.weapon = "war_hammer"
	main.hud.core.queue_redraw()
	await t._frames(3)
	var cards: Array = main.hud.tips.filter(func(tp): return String(tp[1]).begins_with(String(Offhand.TEXT["where"])))
	t._check(cards.size() == 1 and " ".join(cards[0][2]).contains("both hands") and " ".join(cards[0][2]).contains("war hammer"), "the HUD shows the off-hand put away, and its card says why: %s" % [cards[0][2] if not cards.is_empty() else "none"])
	p.weapon = "sword"
	await t._frames(3)
	cards = main.hud.tips.filter(func(tp): return String(tp[1]).begins_with(String(Offhand.TEXT["where"])))
	t._check(cards.size() == 1 and not " ".join(cards[0][2]).contains("both hands"), "...and ready with a one-handed weapon")
	t._check(Entity.TIPS.has("two_hands") and String(Entity.TIPS["two_hands"]["tip"]).contains("both hands") and String(Entity.TIPS["two_hands"]["more"]).contains("bow"), "the Entity explains two-handed weapons")
	p.weapon = "war_hammer"
	if p.has_meta("two_told"):
		p.remove_meta("two_told")
	Offhand.tick(p, 0.0)  # (player.gd _tick_timers, each frame in a climb)
	t._check(p.has_meta("two_told"), "...the first time one puts the off-hand away in a climb")
	p.gear["melee"] = keep["melee"]
	p.gear["offhand"] = keep["offhand"]
	p.weapon = String(keep["weapon"])
	p.refresh_gear()


# --- leaving part way, resuming, starting over ---------------------------------------------------

func _leave_and_resume(main) -> void:
	var prof = main.profile
	var menu = main.menu
	var arena = main.arena
	Renown.state(prof).erase("tutorial")
	await _to_gym(main)
	var begin: Array = _buttons(menu, "station_do", "begin")
	t._check(begin.size() == 1 and begin[0].text == Tutorial.TEXT["again"], "done, the card offers to go through it again")
	Tutorial.state(prof)["done"] = false
	if begin.size() == 1:
		begin[0].pressed.emit()
	await t._frames(3)
	var p = main.player
	for at in arena.posts.duplicate():
		p.global_position = at
		await _phys()
	await _phys(2)
	t._check(arena.on and arena.tut.i == 1, "the first step done, on to the second")
	menu.open("pause")
	await t._frames(2)
	var leave: Array = t._all_buttons(menu.box).filter(func(bb): return bb.has_meta("give_up"))
	t._check(leave.size() == 1 and leave[0].text == Tutorial.TEXT["leave"], "the pause menu can leave, keeping the place")
	if leave.size() == 1:
		leave[0].pressed.emit()
	await t._frames(3)
	t._check(not arena.on and menu.page == "station" and Tutorial.resume_step(prof) == 1, "left part way: back at the gym, the place kept (step %d)" % (Tutorial.resume_step(prof) + 1))
	t._check(Tutorial.tile_line(prof).contains("2"), "the tile says which step is next (%s)" % Tutorial.tile_line(prof))
	var resume: Array = _buttons(menu, "station_do", "begin")
	var restart: Array = _buttons(menu, "station_do", "restart")
	t._check(resume.size() == 1 and resume[0].text == String(Tutorial.TEXT["resume"]) % 2 and restart.size() == 1, "the card offers Resume from step 2 and Start over")
	t._check(restart.size() == 1 and not Help.missing(restart[0]), "...Start over explains itself")
	if resume.size() == 1:
		resume[0].pressed.emit()
	await t._frames(3)
	t._check(arena.on and arena.tut != null and arena.tut.i == 1, "Resume: back in at the step it stopped before")
	arena.give_up()
	await t._frames(3)
	restart = _buttons(menu, "station_do", "restart")
	if restart.size() == 1:
		restart[0].pressed.emit()
	await t._frames(3)
	t._check(arena.on and arena.tut != null and arena.tut.i == 0, "Start over: from the first step")
	arena.give_up()
	await t._frames(3)
	Tutorial.state(prof)["done"] = true
	Tutorial.state(prof)["step"] = 0


# --- skipping ------------------------------------------------------------------------------------

func _skip(main) -> void:
	var prof = main.profile
	var menu = main.menu
	# A first-timer before the Grace: refused (unless they've made a climber before).
	Renown.state(prof).erase("tutorial")
	Renown.state(prof)["lessons"] = {}
	if not Tutorial.experienced():
		var said: Array = Tutorial.skip(prof)
		t._check(not Tutorial.passed(prof) and said == [Training.TEXT["no_skip"]], "a first-timer can't skip it before the Grace")
	# After the Grace (or a climber not held to it): Skip on the card.
	Training.state(prof)["grace"] = true
	await _to_gym(main)
	var skip: Array = _buttons(menu, "station_do", "skip")
	t._check(skip.size() == 1 and not Help.missing(skip[0]), "after the Grace the card has Skip, which explains itself")
	var pts := Renown.points(prof)
	if skip.size() == 1:
		skip[0].pressed.emit()
	await t._frames(2)
	t._check(menu.asking() and menu.pop.text_l.text.contains("Trainee") and not Tutorial.passed(prof), "Skip asks first, warning that it forfeits the Trainee title")
	await t._confirm(true)
	await t._frames(2)
	t._check(Tutorial.passed(prof) and bool(Tutorial.state(prof)["skipped"]) and Stations.lessons_done(prof), "skipped: behind the climber, the old parts marked")
	t._check(not Tutorial.earned_title(prof) and not Renown.grantable(prof, "trainee"), "...but no Trainee title: it's earned by finishing, not skipping")
	t._check(Renown.points(prof) == pts + Stations.LESSON_REWARD, "...the set's renown paid (once: it was cleared for this check)")
	t._check(_buttons(menu, "station_do", "begin").size() == 1, "...and it can still be gone through")


# --- prompts: keys, a controller, touch ----------------------------------------------------------

## A step's words for a loadout (its variant, the weapons named).
func _said(d: Dictionary, field: String, ranged: String, two := "") -> String:
	return Tutorial.fill_words(Tutorial.pick_words(d, field, Tutorial.variant_for(d, ranged, two)), "sword", ranged, two)


func _prompts(_main) -> void:
	for d in Tutorial.STEPS:
		for lo in [["shortbow", ""], ["flintlock", ""], ["revolver", ""], ["crossbow", ""], ["sling", "war_hammer"]]:
			var all := _said(d, "say", lo[0], lo[1]) + " " + _said(d, "goal", lo[0], lo[1]) + " " + _said(d, "hint", lo[0], lo[1])
			var keys := Entity.fill_keys(all, "keys")
			var pad := Entity.fill_keys(all, "pad")
			var touch := Entity.fill_keys(all, "touch")
			t._check(not keys.contains("{") and not pad.contains("{") and not touch.contains("{"), "%s (%s): every key and weapon named for keys, a controller and touch" % [d["id"], lo[0]])
			t._check(keys != touch, "%s (%s): touch players get their own buttons" % [d["id"], lo[0]])
	var touch_words := {"roll": "Roll", "jump": "Jump", "parry": "Parry", "fists": "Swap", "ranged": "Swap", "offhand": "Off-hand", "belt": "Item"}
	for id in touch_words:
		var d: Dictionary = Tutorial.STEPS[ORDER.find(id)]
		t._check(Entity.fill_keys(String(d["say"]), "touch").contains(touch_words[id]), "%s: the touch prompt names the %s button" % [id, touch_words[id]])
	# The ranged step, worded for each kind of ranged weapon.
	var rd: Dictionary = Tutorial.STEPS[ORDER.find("ranged")]
	t._check(_said(rd, "goal", "shortbow").contains("full draw") and _said(rd, "say", "longbow").contains("longbow"), "a bow: a full draw (%s)" % _said(rd, "goal", "shortbow"))
	t._check(_said(rd, "goal", "flintlock").contains("flintlock pistol, then fire it"), "a pistol: fire it (%s)" % _said(rd, "goal", "flintlock"))
	t._check(_said(rd, "say", "flintlock").contains("one shot") and _said(rd, "say", "flintlock").contains("reload") and _said(rd, "say", "revolver").contains("6 shots"), "...its shots and reload explained")
	t._check(_said(rd, "goal", "crossbow").contains("fire") and _said(rd, "say", "crossbow").contains("reload"), "a crossbow: fire, then reload")
	t._check(_said(rd, "goal", "sling").contains("whirl"), "a sling: a full whirl")
	var od: Dictionary = Tutorial.STEPS[ORDER.find("offhand")]
	t._check(_said(od, "say", "shortbow").contains("both hands") and _said(od, "say", "shortbow", "war_hammer").contains("war hammer"), "the off-hand step says two-handed weapons leave no hand free")
	var pad_line := Entity.fill_keys(String(Tutorial.STEPS[ORDER.find("roll")]["say"]), "pad")
	t._check(pad_line.contains("B"), "a controller's prompt names its button (%s)" % pad_line.left(40))


# --- the Entity, help, the Data editor, words -----------------------------------------------------

func _words(main) -> void:
	t._check(String(Entity.TIPS["basic_training"]["tip"]).contains("One session") and String(Entity.TIPS["basic_training"]["tip"]).length() <= 170, "the Entity's first word on basic training says it's one session")
	var said := Talk.line_for(main, "how_training")
	t._check(said.contains(str(Tutorial.count())) and said.contains("parry") and not said.contains("{"), "'How does it work?' explains the one session")
	for k in ["pick:basics", "station_do:begin", "station_do:restart", "station_do:skip"]:
		t._check(Help.HELP.has(k), "button help: %s" % k)
	var tables: Array = []
	for s in Registry.SECTIONS:
		tables.append_array(s.get("tables", []))
	t._check(tables.has("tutorial/STEPS") and tables.has("tutorial/TEXT"), "its steps and words are in the Data editor")
	var all := JSON.stringify([Tutorial.STEPS, Tutorial.TEXT, Entity.TIPS["basic_training"], Entity.TIPS["training"], Entity.TIPS["two_hands"], Offhand.TEXT, said]).to_lower()
	var re := RegEx.create_from_string("\\b(" + "|".join(BANNED) + ")\\b")
	t._check(re.search(all) == null, "no banned words in basic training")
	var readme := FileAccess.get_file_as_string("res://README.md")
	t._check(readme.contains("Basic training: one session"), "the README explains the one session")
