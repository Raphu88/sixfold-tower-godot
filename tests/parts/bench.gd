extends RefCounted
## The Unbound's effects (three per essence), the echoes, and the essence
## bench in the Workshop car. Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const UB := preload("res://scripts/spells/unbound_effects.gd")
const EB := preload("res://scripts/essence_bench.gd")

var t


func run(smoke) -> void:
	t = smoke
	await _effects_on_every_form()
	await _effects_do_their_thing()
	await _echoes()
	await _bench_builds()
	await _bench_by_hand()
	await _marked_cant()
	await _bench_fits()


func _main():
	return t.main


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## Three slimes close in front of the climber, tough enough to last.
func _foes(p) -> Array:
	var out: Array = []
	for off in [Vector2(36, 0), Vector2(40, 46), Vector2(80, -30)]:
		var e = await t._spawn("slime", p.global_position + off)
		e.hp = 5000.0
		e.max_hp = 5000.0
		out.append(e)
	return out


func _place(p, foes: Array, at: Vector2) -> void:
	p.global_position = at
	p.aim = Vector2.RIGHT
	p.roll_t = 0.0
	p.jump_t = 0.0
	p.hp = p.max_health()
	var offs := [Vector2(36, 0), Vector2(40, 46), Vector2(80, -30)]
	for i in foes.size():
		var e = foes[i]
		if is_instance_valid(e):
			e.global_position = at + offs[i]
			e.hp = 5000.0
			e.knock = Vector2.ZERO
			e.velocity = Vector2.ZERO


func _effects_on_every_form() -> void:
	print("the Unbound's effects: each on every kind of form, at every strength")
	await t._ub_fresh()
	var main = _main()
	var T = load("res://scripts/technique.gd")
	var L = load("res://scripts/library.gd")
	var p = main.player
	var run = main.unbound
	p.iframes = 999.0
	main.dev_no_death = true
	var foes: Array = await _foes(p)
	var at: Vector2 = p.global_position
	var ids: Array = UB.EFFECTS.keys()
	_check(ids.size() == 24 and ids.all(func(id): return L.built(L.effect(id))), "all 24 new effects are written, three for each of the eight essences (%d)" % ids.size())
	var per_kind := {}
	for id in ids:
		per_kind[String(UB.EFFECTS[id]["kind"])] = int(per_kind.get(String(UB.EFFECTS[id]["kind"]), 0)) + 1
	_check(per_kind.size() == 8 and per_kind.values().all(func(n): return n == 3), "...three each (%s)" % [per_kind])
	_check(ids.all(func(id):
		var fx: Dictionary = UB.EFFECTS[id]
		return ["hit", "self", "shell", "near", "says"].all(func(k): return String(fx.get(k, "")) != "")), "each has a phrase for a hit, on yourself, a shell and around you")
	var others := ["fire", "water", "air", "stone", "iron", "blade", "life", "unmaking"]
	var forms := [["hand", "strike"], ["legs", "dash"], ["back", "shell"], ["heart", "within"]]
	var missed: Array = []
	var described := true
	for id in ids:
		var kind := String(UB.EFFECTS[id]["kind"])
		var fill: Array = others.filter(func(k): return k != kind)
		for f in forms:
			for pos in 3:
				var kinds: Array = fill.slice(0, pos)
				kinds.append(kind)
				var tech := {"part": f[0], "shape": f[1], "kinds": kinds, "effects": {kind: id}}
				_place(p, foes, at)
				UB._last.clear()
				var before := int(UB.FIRED.get(id, 0))
				T.cast(tech, p, 1.0, run)
				if int(UB.FIRED.get(id, 0)) <= before:
					missed.append("%s on %s at %d" % [id, f[1], pos + 1])
				var key: String = {"within": "self", "shell": "shell"}.get(f[1], "hit")
				var phrase := String(UB.EFFECTS[id].get(key, ""))
				if pos == 0 and not T.describe(tech).contains(phrase):
					described = false
		await t._frames(1)
	_check(missed.is_empty(), "every effect works on a hit, a move, a shell and on yourself, leading, second and third (%d missed: %s)" % [missed.size(), missed.slice(0, 6)])
	_check(described, "...and each technique's card says what it does with it")
	await t._wait(0.7)  # (the delayed ones: Flare, Tremor)
	_check(p.hp >= 1.0 and not p.dead, "nothing went wrong while they ran")
	main.dev_no_death = false


func _effects_do_their_thing() -> void:
	print("the Unbound's effects in play")
	await t._ub_fresh()
	var main = _main()
	var T = load("res://scripts/technique.gd")
	var FX = load("res://scripts/spell_fx.gd")
	var p = main.player
	var run = main.unbound
	p.iframes = 999.0
	var foes: Array = await _foes(p)
	var a = foes[0]
	var at: Vector2 = p.global_position
	var strike := func(kind: String, id: String) -> void:
		_place(p, foes, at)
		UB._last.clear()
		T.cast({"part": "hand", "shape": "strike", "kinds": [kind], "effects": {kind: id}}, p, 1.0, run)
	var within := func(kind: String, id: String) -> void:
		_place(p, foes, at)
		UB._last.clear()
		T.cast({"part": "heart", "shape": "within", "kinds": [kind], "effects": {kind: id}}, p, 1.0, run)
	var fields0: int = FX.of(main).fields.size()
	strike.call("fire", "kindle")
	_check(FX.of(main).fields.size() > fields0 and UB.runner(main).decals.any(func(d): return d["kind"] == "flames"), "Kindle leaves burning floor (drawn)")
	for i in 3:
		strike.call("water", "chill")
	_check(a.stun > 0.0, "Chill: three chills freeze a foe")
	a.stun = 0.0
	strike.call("air", "lift")
	_check(a.airborne > 0.0, "Lift: a light foe floats, helpless")
	a.airborne = 0.0
	strike.call("air", "gust")
	_check(a.knock.length() > 200.0, "Gust throws it back hard")
	p.stone_t = 0.0
	strike.call("stone", "grit")
	_check(p.stone_t > 0.0, "Grit: you take less damage for a few seconds")
	p.edge_t = 0.0
	strike.call("iron", "temper")
	_check(p.edge_t > 0.0, "Temper: your weapon strikes hit harder")
	strike.call("unmaking", "unravel")
	_check(a.unravel_t > 0.0, "Unravel strips its armour")
	strike.call("unmaking", "hollow")
	var hp0: float = a.hp
	a.take_hit(10.0, Vector2.ZERO, 0.0)
	_check(a.hollow_t > 0.0 and hp0 - a.hp > 10.5, "Hollow: it takes more from everything (%.1f from a 10)" % (hp0 - a.hp))
	p.sta = 0.0
	strike.call("life", "second_wind")
	_check(p.sta > 0.0, "Second Wind gives stamina back on a hit")
	strike.call("life", "lifeline")
	_check(UB.runner(main).decals.any(func(d): return d["kind"] == "thread"), "Lifeline ties a thread to the foe")
	strike.call("blade", "rend")
	strike.call("blade", "rend")
	_check(int(a.get_meta("rend_n", 0)) == 2, "Rend: bleeds stack")
	# Bloom on yourself: three flowers; stepping on one heals.
	within.call("life", "bloom")
	var flowers: Array = UB.runner(main).decals.filter(func(d): return d["kind"] == "flower")
	_check(flowers.size() >= 3, "Bloom on yourself opens flowers around you")
	if not flowers.is_empty():
		p.hp = 40.0
		p.global_position = flowers[0]["pos"]
		await t._frames(3)
		_check(p.hp > 40.0, "...and stepping on one heals you")
	# Answer: the next foe to swing at you is cut first.
	within.call("blade", "answer")
	a.state = "wind_slash"
	var hp1: float = a.hp
	await t._frames(3)
	_check(a.hp < hp1, "Answer: a foe that starts a swing at you is cut first")
	a.state = "idle"
	# Current on yourself carries you; Mist hides you.
	within.call("water", "current")
	_check(p.roll_t > 0.0, "Current on yourself carries you along your aim")
	within.call("water", "mist")
	await t._wait(0.5)
	_check(a.lost_t > 0.0, "Mist: foes inside lose sight of you")
	# A new floor clears what they leave.
	main._start_floor(main.floor_num)
	await t._frames(3)
	_check(UB.runner(main).decals.is_empty() if is_instance_valid(UB.runner(main)) else true, "a new floor clears what they left behind")


func _echoes() -> void:
	print("echoes: close to a bond's spell, never the same")
	await t._ub_fresh()
	var main = _main()
	var L = load("res://scripts/library.gd")
	var T = load("res://scripts/technique.gd")
	var TR = load("res://scripts/tree.gd")
	var p = main.player
	_check(L.ECHOES.size() >= 12 and L.ECHOES.size() <= 18, "%d echo recipes (12 to 18)" % L.ECHOES.size())
	var named := true
	var acts := true
	var sigs := {}
	var bonds := {}
	for r in L.ECHOES:
		if L.spell_name(String(r["spell"])) == String(r["spell"]):
			named = false
		if not UB.ECHO_ACTS.has(String(r["spell"])):
			acts = false
		sigs["%s|%s|%s" % [r["form"], r["lead"], r.get("with", [])]] = true
		bonds[String(r.get("bond", ""))] = true
	_check(named and acts, "each echoes a real bond spell, and adds a weaker touch of it")
	_check(sigs.size() == L.ECHOES.size() and bonds.size() >= 10, "no two recipes alike, across %d bonds" % bonds.size())
	_check(T.RECIPES.keys().all(func(id): return L.echo_of(T.recipe(id)).is_empty()), "no ready-made technique echoes (they're found by experimenting)")
	var undertow := {"part": "throat", "shape": "pull", "kinds": ["water", "iron"]}
	_check(L.echo_of(undertow).get("name", "") == "Undertow", "a Water pull with Iron echoes Undertow")
	var plain := {"part": "throat", "shape": "pull", "kinds": ["water"]}
	_check(T.strain(undertow) == T.strain({"part": "throat", "shape": "pull", "kinds": ["water", "fire"]}) + 6.0, "an echo costs a little more strain (+6)")
	_check(L.echo_of(plain).is_empty(), "...the same without Iron echoes nothing")
	# Gale Lift's echo lifts the light foes in front.
	p.iframes = 999.0
	var e = await t._spawn("slime", p.global_position + Vector2(60, 0))
	e.hp = 500.0
	e.max_hp = 500.0
	p.aim = Vector2.RIGHT
	T.cast({"part": "throat", "shape": "shout", "kinds": ["air", "stone"]}, p, 1.0, main.unbound)
	_check(e.airborne > 0.0 and e.airborne < 1.0, "an Air shout with Stone lifts the foes in front, briefly (weaker than Gale Lift)")
	# The card says so.
	var A = load("res://scripts/abilities.gd")
	_check(A._echo_text({"part": "throat", "shape": "shout", "kinds": ["air", "stone"]}) == "echoes Gale Lift", "the card says \"echoes Gale Lift\"")
	_check(EB.echo_line(undertow).begins_with("Echoes Undertow"), "...and the bench's plaque what the echo adds")
	# Recorded per climber, the first cast that finds it.
	TR.state(main.profile)["echoes"].clear()
	var b = main.player.bonds.values()[0]
	b.tech = undertow.duplicate(true)
	b.essence = 999.0
	main.unbound.cast(b, p)
	_check("undertow" in TR.state(main.profile)["echoes"], "a cast that finds an echo records it for the climber")


## The bench, through its own rules (the draft, the lead, a fitting, the gauge, a slot).
func _bench_builds() -> void:
	print("the essence bench: building a technique")
	await t._ub_fresh()
	var main = _main()
	var U = load("res://scripts/unbound.gd")
	var T = load("res://scripts/technique.gd")
	var TR = load("res://scripts/tree.gd")
	var prof = main.profile
	prof.part_density = {"hand": {"blade": U.LEVELS[4]}, "legs": {"air": 120.0}}
	TR.choose(prof, "unbound:hand:2", "split")
	main._give_bonds()
	main.await_tower()
	main.open_train()
	await t._frames(3)
	var menu = main.menu
	main.touch._set_active(false)
	# From Your Car's Techniques page: "Build at the bench".
	menu.set_meta("tech_slot", 2)
	menu.open("techniques", true)
	await t._frames(2)
	var go: Array = t._all_buttons(menu).filter(func(b): return b.has_meta("tech_bench"))
	_check(go.size() == 1, "the Techniques page sends you to the bench")
	if go.size() == 1:
		go[0].pressed.emit()
		await t._frames(3)
	_check(menu.page == "train" and menu.train_car == "workshop" and menu.train_bench == EB.COUNTER, "...the Workshop car, the essence bench open")
	_check(EB.slot(menu) == 2, "...on the slot you were looking at")
	var press := func(meta: String, val) -> bool:
		var bs: Array = t._car_buttons(meta, val)
		if bs.size() != 1 or bs[0].disabled:
			return false
		bs[0].pressed.emit()
		await t._frames(2)
		return true
	_check(await press.call("bench_mould", "hand:bolt"), "a mould: the hand's Bolt")
	var d: Dictionary = EB.draft(menu)
	_check(d["part"] == "hand" and d["shape"] == "bolt", "...its shape is on the bench")
	var globes: Array = menu.train_page.roots["workshop"].find_children("*", "Control", true, false).filter(func(c): return c is EB.Globe)
	_check(globes.size() == 1 and globes[0].form == "bolt", "...and in the globe")
	for k in d["kinds"].duplicate():
		await press.call("bench_vial", k)
	_check(EB.draft(menu)["kinds"].is_empty(), "closing every tap empties it")
	await press.call("bench_vial", "air")
	await press.call("bench_vial", "fire")
	d = EB.draft(menu)
	_check(d["kinds"] == ["air", "fire"], "taps opened in order: the first leads (%s)" % [d["kinds"]])
	var vial: Array = t._car_buttons("bench_vial", "air")
	_check(vial.size() == 1 and vial[0].order == 1 and t._car_buttons("bench_vial", "fire")[0].order == 2, "...the vials show their order")
	globes = menu.train_page.roots["workshop"].find_children("*", "Control", true, false).filter(func(c): return c is EB.Globe)
	_check(not globes.is_empty() and globes[0].kinds == ["air", "fire"] and globes[0].pour_kind == "fire", "...the lead fills the globe, the second swirls in, and the liquid runs")
	_check(t._car_buttons("bench_vial", "water")[0].full, "a third waits for a higher level (it says why)")
	await press.call("bench_vial", "water")
	_check(EB.draft(menu)["kinds"].size() == 2 and menu.toast.contains("level"), "...and pressing it says so (%s)" % menu.toast)
	_check(await press.call("bench_fitting", "split"), "a fitting screwed on: Split")
	d = EB.draft(menu)
	_check(T.variations(d) == ["split"], "...the technique carries it")
	_check(t._car_buttons("bench_fitting", "chain")[0].disabled, "a fitting not yours sits dark")
	var gauges: Array = menu.train_page.roots["workshop"].find_children("*", "Control", true, false).filter(func(c): return c is EB.Gauge)
	_check(gauges.size() == 1 and is_equal_approx(gauges[0].strain, T.strain(d)) and T.strain(d) == 26.0, "the gauge shows the strain one cast adds (%.0f)" % (gauges[0].strain if not gauges.is_empty() else -1.0))
	# An effect for the lead, now Spark has opened (120 Air pooled).
	_check(await press.call("bench_fx", "air"), "a layer's effect can be changed")
	_check(T.effect_of(EB.draft(menu), "air") == "spark", "...to Spark (it has opened)")
	_check(t._car_buttons("bench_mould", "hand:volley").size() == 1 and t._car_buttons("bench_mould", "brow:mark").size() == 1, "every opened form has a mould")
	var before: Dictionary = U.state(prof)["techs"][2].duplicate(true)
	_check(EB.dirty(menu) and before.get("shape", "") != "bolt", "the slot is untouched until it's set")
	_check(await press.call("bench_save", true), "Set in slot")
	var saved: Dictionary = U.state(prof)["techs"][2]
	_check(saved["shape"] == "bolt" and saved["kinds"] == ["air", "fire"] and T.variations(saved) == ["split"] and T.effect_of(saved, "air") == "spark", "the technique is saved to the slot: its form, its lead, its fitting and its effect")
	_check(main.player.bonds.values().any(func(b): return "tech" in b and b.tech.get("shape", "") == "bolt"), "...and carried at once")
	var names: Array = menu.train_page.roots["workshop"].find_children("*", "Label", true, false).filter(func(l): return l.has_meta("bench_name"))
	_check(names.size() == 1 and names[0].text == T.title(saved), "the plaque names it (%s)" % (names[0].text if not names.is_empty() else ""))
	# Another slot.
	_check(await press.call("bench_slot", 0), "choosing another slot")
	_check(EB.slot(menu) == 0 and EB.draft(menu)["shape"] == U.state(prof)["techs"][0]["shape"], "...puts its technique on the bench")
	# An echo found at the bench is remembered.
	TR.state(prof)["echoes"].clear()
	prof.part_density["throat"] = {"water": U.LEVELS[4]}
	await press.call("bench_mould", "throat:shout")
	for k in EB.draft(menu)["kinds"].duplicate():
		await press.call("bench_vial", k)
	await press.call("bench_vial", "air")
	await press.call("bench_vial", "stone")
	var echo_l: Array = menu.train_page.roots["workshop"].find_children("*", "Label", true, false).filter(func(l): return l.has_meta("bench_echo"))
	_check(echo_l.size() == 1 and echo_l[0].text.begins_with("Echoes Gale Lift"), "the plaque says \"Echoes Gale Lift\"")
	await press.call("bench_save", true)
	_check("gale_lift" in TR.state(prof)["echoes"] and menu.toast.contains("Gale Lift"), "setting it records the echo for the climber")
	menu.close()
	await t._frames(2)


## The keys, a controller and a tap, at the bench.
func _bench_by_hand() -> void:
	print("the essence bench: keys, controller and touch")
	await t._ub_fresh()
	var main = _main()
	main.await_tower()
	main.open_train()
	await t._frames(3)
	var menu = main.menu
	main.touch._set_active(false)
	menu.train_car = "workshop"
	menu.train_bench = EB.COUNTER
	EB.load_slot(menu, 0)
	menu.open("train")
	await t._frames(3)
	menu.train_page.go_to(menu.train_page._index("workshop"))
	await t._train_settled()
	menu.train_page.enter()
	await t._frames(2)
	var f: Control = menu.get_viewport().gui_get_focus_owner()
	_check(f != null and f.has_meta("bench_start"), "into the car with the keys: the first vial")
	var kinds0: Array = EB.draft(menu)["kinds"].duplicate()
	await t._key_tap(KEY_ENTER)
	await t._frames(2)
	_check(EB.draft(menu)["kinds"] != kinds0, "Enter turns its tap")
	f = menu.get_viewport().gui_get_focus_owner()
	_check(f != null and f.get_meta("bench_vial", "") == "fire", "...and the focus stays on it")
	var kinds1: Array = EB.draft(menu)["kinds"].duplicate()
	t._pad_button(JOY_BUTTON_A, true)
	await t._frames(2)
	t._pad_button(JOY_BUTTON_A, false)
	await t._frames(3)
	_check(EB.draft(menu)["kinds"] != kinds1, "A on a controller turns it back")
	await t._key_tap(KEY_RIGHT)
	await t._frames(2)
	f = menu.get_viewport().gui_get_focus_owner()
	_check(f != null and f.get_meta("bench_vial", "") == "water", "Right moves to the next vial")
	main.touch._set_active(true)
	await t._frames(2)
	var mould: Array = t._car_buttons("bench_mould", "hand:bolt")
	if mould.size() == 1:
		await t._tap_at(mould[0].get_global_rect().get_center())
		await t._frames(2)
	_check(EB.draft(menu)["shape"] == "bolt", "a tap on a mould chooses it")
	main.touch._set_active(false)
	menu.close()
	await t._frames(2)


func _marked_cant() -> void:
	print("the essence bench: for the Unbound only")
	await t._fresh_main()
	t.paused = false
	var main = _main()
	main.grant_test_bonds()
	var prof = main.profile
	main.await_tower()
	main.open_train()
	await t._frames(3)
	var menu = main.menu
	main.touch._set_active(false)
	menu.train_car = "workshop"
	menu.train_bench = "brew"
	menu.open("train")
	await t._frames(3)
	var drawer: Array = t._car_buttons("bench_drawer", EB.COUNTER)
	_check(drawer.size() == 1 and drawer[0].get_meta("greyed", false), "a marked climber sees the essence bench's drawer, greyed")
	if drawer.size() == 1:
		drawer[0].pressed.emit()
		await t._frames(3)
	var notes: Array = menu.train_page.roots["workshop"].find_children("*", "Label", true, false).filter(func(l): return l.has_meta("bench_marked"))
	_check(menu.train_bench == EB.COUNTER and notes.size() == 1 and notes[0].text.contains("Unbound"), "...and the bench, with a line saying it's for the Unbound")
	var vials: Array = menu.train_page.roots["workshop"].find_children("*", "Button", true, false).filter(func(b): return b.has_meta("bench_vial"))
	_check(not vials.is_empty() and vials.all(func(v): return v.disabled and v.locked), "its vials sit dark")
	var techs: Array = load("res://scripts/unbound.gd").state(prof)["techs"].duplicate(true)
	if not vials.is_empty():
		vials[0].pressed.emit()
		await t._frames(2)
	var saves: Array = t._car_buttons("bench_save", true)
	_check(saves.size() == 1 and saves[0].disabled and not EB.save(menu), "...and nothing can be set")
	_check(load("res://scripts/unbound.gd").state(prof)["techs"] == techs and prof.bonds.size() > 0, "a marked climber's marks and slots are untouched")
	menu.close()
	await t._frames(2)


func _bench_fits() -> void:
	print("the essence bench: fitting a phone")
	await t._ub_fresh()
	var main = _main()
	var U = load("res://scripts/ui.gd")
	var M = load("res://scripts/menu.gd")
	var prof = main.profile
	prof.part_density = {"hand": {"blade": 400.0}, "legs": {"air": 300.0}}
	var TR = load("res://scripts/tree.gd")
	TR.choose(prof, "unbound:hand:2", "split")
	main._give_bonds()
	main.await_tower()
	main.open_train()
	await t._frames(3)
	var menu = main.menu
	var keep: String = M.settings["ui_size"]
	var was_size: Vector2i = t.root.size
	t.root.size = Vector2i(800, 400)
	main.touch._set_active(true)
	var problems: Array = []
	for ui in U.UI_SIZE_ORDER:
		menu._set_setting("ui_size", ui)
		await t._frames(2)
		menu.train_car = "workshop"
		menu.train_bench = EB.COUNTER
		EB.load_slot(menu, 0)
		EB.set_draft(menu, EB.pour(prof, EB.pour(prof, EB.draft(menu), "air"), "stone"))
		menu.open("train")
		await t._frames(2)
		menu.train_page.go_to(menu.train_page._index("workshop"))
		await t._train_settled()
		await t._frames(3)
		var vr: Rect2 = menu.train_view.get_global_rect()
		var pane: Control = menu.train_page.car_scrolls["workshop"]
		problems.append_array(t._fit_problems("bench %s" % ui, pane, vr))
		if pane.scale.x < menu.train_view.FIT_MIN - 0.01:
			problems.append("bench %s: shrunk to %.2f" % [ui, pane.scale.x])
		if t._car_buttons("bench_save", true).is_empty():
			problems.append("bench %s: no Set in slot" % ui)
	_check(problems.is_empty(), "the essence bench fits 800x400 at every Interface size (%d problems): %s" % [problems.size(), problems.slice(0, 8)])
	# The Techniques page too.
	var tp_problems: Array = []
	for ui in U.UI_SIZE_ORDER:
		menu._set_setting("ui_size", ui)
		menu.open("techniques", true)
		await t._frames(3)
		tp_problems.append_array(t._fit_problems("techniques %s" % ui, menu.panel, t.root.get_visible_rect()))
	_check(tp_problems.is_empty(), "the Techniques page fits too (%d problems): %s" % [tp_problems.size(), tp_problems.slice(0, 6)])
	menu.close()
	menu._set_setting("ui_size", keep)
	main.touch._set_active(false)
	t.root.size = was_size
	await t._frames(2)
	main.on_train = false
