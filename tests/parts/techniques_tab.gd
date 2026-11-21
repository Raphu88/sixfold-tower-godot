extends RefCounted
## The Unbound's effects (three per essence), the echoes, and the
## Techniques tab on the climber screen (technique_tab.gd), where they build
## their techniques. Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const UB := preload("res://scripts/spells/unbound_effects.gd")
const TT := preload("res://scripts/technique_tab.gd")
const TestRun := preload("res://scripts/test_run.gd")

var t


func run(smoke) -> void:
	t = smoke
	await _effects_on_every_form()
	await _effects_do_their_thing()
	await _echoes()
	await _tab_builds()
	await _tab_by_hand()
	await _marked_cant()
	await _tab_fits()


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
	_check(TT.echo_line(undertow).begins_with("Echoes Undertow"), "...and the Techniques tab what the echo adds")
	# Recorded per climber, the first cast that finds it.
	TR.state(main.profile)["echoes"].clear()
	var b = main.player.bonds.values()[0]
	b.tech = undertow.duplicate(true)
	b.essence = 999.0
	main.unbound.cast(b, p)
	_check("undertow" in TR.state(main.profile)["echoes"], "a cast that finds an echo records it for the climber")


## The tab's buttons (visible ones) with a meta of this value.
func _tab_buttons(meta: String, val = null) -> Array:
	return t._all_buttons(_main().menu.box).filter(func(b): return is_instance_valid(b) and b.is_visible_in_tree() and not b.is_queued_for_deletion() and b.has_meta(meta) and (val == null or b.get_meta(meta) == val))


func _tab_labels(meta: String) -> Array:
	return t._all_labels(_main().menu.box).filter(func(l): return is_instance_valid(l) and not l.is_queued_for_deletion() and l.has_meta(meta))


## Presses a tab button (if it's there and on), then lets the page rebuild.
func _press(meta: String, val) -> bool:
	var bs := _tab_buttons(meta, val)
	if bs.size() != 1 or bs[0].disabled:
		return false
	bs[0].pressed.emit()
	await t._frames(3)
	return true


func _open_tab(slot := 0) -> void:
	var menu = _main().menu
	menu.set_meta("tech_slot", slot)
	menu.climber_tab = "techniques"
	menu.open("climber", true)
	await t._frames(3)


## The Techniques tab: only for the Unbound, beside their Body tab; building
## a technique there (each press saved at once and carried), the echo, a part
## not yet half full, saved and loaded; and the essence bench is gone.
func _tab_builds() -> void:
	print("the Techniques tab: building a technique")
	await t._ub_fresh()
	var main = _main()
	var U = load("res://scripts/unbound.gd")
	var T = load("res://scripts/technique.gd")
	var TR = load("res://scripts/tree.gd")
	var prof = main.profile
	# The hand: Blade leads, a touch of Air (level 9); the legs full of Air.
	prof.part_density = {}
	U.state(prof)["primary"] = {}
	U.put(prof, "hand", "blade", 60.0)
	U.put(prof, "hand", "air", 30.0)
	U.put(prof, "legs", "air", 120.0)
	for pt in ["heart", "brow", "throat", "back"]:
		U.put(prof, pt, String(U.PART_KIND[pt]), 60.0)
	TR.choose(prof, "unbound:hand:7", "split")
	main._give_bonds()
	main.await_tower()
	main.open_train()
	await t._frames(3)
	var menu = main.menu
	main.touch._set_active(false)
	var ids: Array = menu.climber_tabs().map(func(x): return x[0])
	_check(ids.find("techniques") == ids.find("marks") + 1 and menu.climber_tabs()[ids.find("marks")][1] == "Body", "the Unbound's climber screen has a Techniques tab, beside Body (%s)" % [ids])
	await _open_tab(0)
	_check(menu.page == "climber" and _tab_buttons("tech_slot").size() == 6, "...six slots along its top, one per body part")
	_check(_tab_labels("tech_locked").is_empty(), "...and on the train nothing is locked")
	# A form: saved at once (no Set button), carried at once.
	_check(await _press("tech_form", "bolt"), "a form: the hand's Bolt")
	var saved: Dictionary = U.state(prof)["techs"][0]
	_check(saved["part"] == "hand" and saved["shape"] == "bolt", "...the slot changes at once")
	_check(main.player.bonds.values().any(func(b): return "tech" in b and b.tech.get("shape", "") == "bolt"), "...and it's carried at once")
	var globes: Array = menu.box.find_children("*", "Control", true, false).filter(func(c): return c is TT.Globe and not c.is_queued_for_deletion())
	_check(globes.size() == 1 and globes[0].form == "bolt" and globes[0].kinds == ["blade", "air"], "the globe draws it: the Bolt, Blade leading and Air swirling in")
	_check(saved["kinds"] == ["blade", "air"] and _tab_buttons("tech_fx").size() == 2 and _tab_buttons("tech_fx", "water").is_empty(), "its essences are the hand's own: an effect button each, none for Water (%s)" % [saved["kinds"]])
	_check(_tab_buttons("tech_form", "volley").size() == 1 and _tab_buttons("tech_form", "mark").is_empty(), "only the hand's forms are offered")
	_check(_tab_buttons("save").is_empty() and _tab_buttons("bench_save").is_empty(), "there's no Set button: nothing to lose")
	# A variation.
	_check(await _press("tech_fitting", "split"), "a variation: Split")
	saved = U.state(prof)["techs"][0]
	_check(T.variations(saved) == ["split"], "...the technique carries it")
	_check(_tab_buttons("tech_fitting", "chain").size() == 1 and _tab_buttons("tech_fitting", "chain")[0].disabled, "a variation not yours sits dark")
	var gauges: Array = menu.box.find_children("*", "Control", true, false).filter(func(c): return c is TT.Gauge and not c.is_queued_for_deletion())
	_check(gauges.size() == 1 and is_equal_approx(gauges[0].strain, T.strain(saved)) and T.strain(saved) == 26.0, "the dial shows the strain one cast adds (%.0f)" % (gauges[0].strain if not gauges.is_empty() else -1.0))
	# An effect for the Air, now Spark has opened (Air in the body).
	_check(await _press("tech_fx", "air"), "an essence's effect can be changed")
	saved = U.state(prof)["techs"][0]
	_check(T.effect_of(saved, "air") == "spark" and saved["shape"] == "bolt" and T.variations(saved) == ["split"], "...to Spark, the form and variation kept")
	var title: Array = _tab_labels("tech_title")
	_check(title.size() == 1 and title[0].text.contains(T.title(saved)), "the card names it (%s)" % (title[0].text if not title.is_empty() else ""))
	_check(_tab_labels("tech_desc").size() == 1 and _tab_labels("tech_desc")[0].text == T.describe(saved), "...and says what it does in plain words")
	# Its name, boost and routing.
	TT._rename(menu, 0, "Wind Needle")
	await t._frames(3)
	_check(String(U.state(prof)["techs"][0]["name"]) == "Wind Needle" and T.title(U.state(prof)["techs"][0]) == "Wind Needle", "it can be named")
	var boost0: bool = bool(U.state(prof).get("boost", true))
	_check(await _press("tech_boost", true) and bool(U.state(prof)["boost"]) != boost0, "Boost switches")
	var to0: String = U.part_for(prof, "blade")
	_check(await _press("route", "blade") and U.part_for(prof, "blade") != to0, "a kind's banked essence can be sent to another part")
	U.route(prof, "blade", "hand")
	# Another slot.
	_check(await _press("tech_slot", 2), "choosing another slot")
	_check(TT.slot(menu) == 2 and menu.box.find_children("*", "PanelContainer", true, false).any(func(c): return c.get_meta("tech_card", "") == "heart" and not c.is_queued_for_deletion()), "...shows its part's technique")
	# An echo found here is remembered (an Air shout with Stone: Gale Lift).
	TR.state(prof)["echoes"].clear()
	prof.part_density["throat"] = {}
	U.state(prof)["primary"].erase("throat")
	U.put(prof, "throat", "air", 60.0)
	U.put(prof, "throat", "stone", 30.0)
	U.state(prof)["techs"][4]["shape"] = "pull"
	main._give_bonds()
	await _press("tech_slot", 4)
	await _press("tech_form", "shout")
	var echo_l: Array = _tab_labels("tech_echo")
	_check(echo_l.size() == 1 and echo_l[0].text.begins_with("Echoes Gale Lift"), "the card says \"Echoes Gale Lift\"")
	var said: Array = _tab_labels("tech_said")
	_check("gale_lift" in TR.state(prof)["echoes"] and said.size() == 1 and said[0].text.contains("Gale Lift"), "the change records the echo for the climber, and says so")
	# What the Abilities tab showed: each Node's minor ability and gift, and the practice room.
	_check(_tab_labels("tech_gift").size() == 6 and _tab_buttons("try_abilities").size() == 1, "the tab also says what each Node gives (minor ability, gift) and offers Try your abilities on the train")
	# A Node below level 6: nothing to change.
	U.set_size(prof, "brow", 40.0)
	main._give_bonds()
	await _press("tech_slot", 3)
	var asleep: Array = _tab_labels("tech_asleep")
	_check(asleep.size() == 1 and asleep[0].text.contains("more size") and _tab_buttons("tech_form").is_empty(), "a Node below level 6 says how far it has to grow, and offers nothing to change")
	# A sleeping Node: no numbers at all.
	U.set_size(prof, "brow", 20.0)
	main._give_bonds()
	menu.open("climber", menu.opened_direct)
	await t._frames(3)
	asleep = _tab_labels("tech_asleep")
	var digits := RegEx.new()
	digits.compile("[0-9]")
	var slot3: Array = _tab_buttons("tech_slot", 3)
	_check(asleep.size() == 1 and asleep[0].text.contains("asleep") and slot3.size() == 1 and slot3[0].text.contains("asleep") and digits.search(slot3[0].text.substr(2)) == null, "a sleeping Node's slot and card say it sleeps (%s)" % (slot3[0].text if not slot3.is_empty() else "none"))
	var gift3: Array = _tab_labels("tech_gift").filter(func(l): return l.get_meta("tech_gift") == "brow")
	_check(gift3.size() == 1 and gift3[0].text.contains("asleep") and digits.search(gift3[0].text) == null, "...and so does its line under What Your Nodes Give")
	U.set_size(prof, "brow", 60.0)
	U.put(prof, "brow", "fire", 60.0)
	main._give_bonds()
	# Saved and loaded.
	var path := TestRun.path("user://techniques_tab_test.cfg")
	prof.save_path = path
	prof.saving = true
	prof.save()
	prof.saving = false
	var again = load("res://scripts/profile.gd").new()
	again.save_path = path
	again.load_save()
	var t0: Dictionary = U.state(again)["techs"][0]
	_check(t0.get("shape", "") == "bolt" and T.variations(t0) == ["split"] and T.effect_of(t0, "air") == "spark" and String(t0.get("name", "")) == "Wind Needle", "the technique built there is saved, and loads again")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	prof.save_path = prof.SAVE_PATH
	# Away from the train: everything shows, nothing changes.
	menu.close()
	await t._frames(2)
	main.on_train = false
	t.paused = false
	await _open_tab(0)
	var techs0: String = str(U.state(prof)["techs"])
	var forms: Array = _tab_buttons("tech_form")
	_check(_tab_labels("tech_locked").size() == 1 and not forms.is_empty() and forms.all(func(b): return b.disabled) and _tab_buttons("tech_fx").all(func(b): return b.disabled), "in a climb the tab shows everything, its buttons off, with a line saying where to change it")
	_check(not TT.apply(menu, 0, TT.fit(prof, U.state(prof)["techs"][0], "")) and str(U.state(prof)["techs"]) == techs0, "...and nothing changes there")
	menu.close()
	await t._frames(2)
	# The essence bench is gone: no file, no drawer in the Workshop, no page in your car.
	main.await_tower()
	main.open_train()
	await t._frames(3)
	menu.train_car = "workshop"
	menu.train_bench = "essence"  # (an old counter: falls back to the counters)
	menu.open("train")
	await t._frames(3)
	_check(not ResourceLoader.exists("res://scripts/essence_bench.gd") and t._car_buttons("bench_drawer", "essence").is_empty() and menu.train_bench == "brew", "the essence bench is gone from the Workshop car")
	menu.train_car = "personal"
	menu.open("train")
	await t._frames(3)
	_check(t._car_buttons("car_page", "techniques").is_empty() and not menu.has_method("_page_techniques"), "...and your car has no Techniques page: the tab holds it all")
	var Help = load("res://scripts/entity_help.gd")
	var E = load("res://scripts/entity.gd")
	var Talk = load("res://scripts/entity_talk.gd")
	for id in ["tech_slot", "tech_form", "tech_fx", "tech_fitting", "tech_name", "tech_boost", "ub_route", "ub_body_open", "tab:techniques"]:
		_check(Help.entry(id) != "", "hover and hold help for %s" % id)
	_check(E.TIPS.has("unbound_techniques") and String(E.TIPS["unbound_techniques"]["tip"]).length() < 160, "the Entity explains the tab the first time")
	_check(Talk.DIALOGUE.has("how_unbound_techniques") and "how_unbound_techniques" in Talk.DIALOGUE["how"]["choices"], "...and answers \"The Techniques tab?\"")
	var words := (str(E.TIPS) + str(Talk.DIALOGUE) + str(Help.HELP)).to_lower()
	_check(not words.contains("essence bench") and not words.contains("techniques page"), "the Entity never sends you to the essence bench or the Techniques page")
	menu.close()
	await t._frames(2)
	main.on_train = false


## The keys, a controller and a tap, on the tab.
func _tab_by_hand() -> void:
	print("the Techniques tab: keys, controller and touch")
	await t._ub_fresh()
	var main = _main()
	var U = load("res://scripts/unbound.gd")
	var prof = main.profile
	main.await_tower()
	main.open_train()
	await t._frames(3)
	var menu = main.menu
	main.touch._set_active(false)
	await _open_tab(0)
	var bolt: Array = _tab_buttons("tech_form", "bolt")
	_check(bolt.size() == 1 and String(U.state(prof)["techs"][0]["shape"]) == "strike", "(the hand's slot holds a Strike)")
	if bolt.size() == 1:
		bolt[0].grab_focus()
	await t._frames(1)
	await t._key_tap(KEY_ENTER)
	await t._frames(4)
	_check(String(U.state(prof)["techs"][0]["shape"]) == "bolt", "Enter on a form chooses it")
	var f: Control = menu.get_viewport().gui_get_focus_owner()
	_check(f != null and f.get_meta("tech_form", "") == "bolt", "...and the focus stays on it")
	var strike: Array = _tab_buttons("tech_form", "strike")
	if strike.size() == 1:
		strike[0].grab_focus()
	await t._frames(1)
	t._pad_button(JOY_BUTTON_A, true)
	await t._frames(2)
	t._pad_button(JOY_BUTTON_A, false)
	await t._frames(4)
	_check(String(U.state(prof)["techs"][0]["shape"]) == "strike", "A on a controller presses it too")
	main.touch._set_active(true)
	await _open_tab(0)
	var b2: Array = _tab_buttons("tech_form", "bolt")
	var rect: Rect2 = b2[0].get_global_rect() if b2.size() == 1 else Rect2()
	if b2.size() == 1 and menu.get_viewport().get_visible_rect().encloses(rect):
		await t._tap_at(rect.get_center())
	elif b2.size() == 1:
		b2[0].pressed.emit()  # (scrolled out of sight on this screen: the press a tap gives)
	await t._frames(4)
	_check(String(U.state(prof)["techs"][0]["shape"]) == "bolt", "a tap on a form chooses it")
	main.touch._set_active(false)
	menu.close()
	await t._frames(2)
	main.on_train = false


## A marked climber has no Techniques tab (a remembered one falls back to Marks).
func _marked_cant() -> void:
	print("the Techniques tab: for the Unbound only")
	await t._fresh_main()
	t.paused = false
	var main = _main()
	main.grant_test_bonds()
	var prof = main.profile
	var menu = main.menu
	var ids: Array = menu.climber_tabs().map(func(x): return x[0])
	_check(not "techniques" in ids and prof.bonds.size() > 0, "a marked climber's climber screen has no Techniques tab (%s)" % [ids])
	menu.climber_tab = "techniques"
	menu.open("climber")
	await t._frames(3)
	_check(_tab_buttons("tech_slot").is_empty() and _tab_buttons("tech_form").is_empty(), "...a remembered one opens their Marks instead")
	_check(not TT.can_edit(main), "...and nothing there could change a technique")
	menu.close()
	await t._frames(2)


func _tab_fits() -> void:
	print("the Techniques tab: fitting a phone")
	await t._ub_fresh()
	var main = _main()
	var U = load("res://scripts/ui.gd")
	var M = load("res://scripts/menu.gd")
	var prof = main.profile
	prof.part_density = {"hand": {"blade": 400.0}, "legs": {"air": 300.0}}
	var TR = load("res://scripts/tree.gd")
	TR.choose(prof, "unbound:hand:7", "split")
	main._give_bonds()
	main.await_tower()
	main.open_train()
	await t._frames(3)
	var menu = main.menu
	var keep: String = M.settings["ui_size"]
	var was_size: Vector2i = t.root.size
	t.root.size = Vector2i(844, 390)
	main.touch._set_active(true)
	var problems: Array = []
	for ui in U.UI_SIZE_ORDER:
		menu._set_setting("ui_size", ui)
		await _open_tab(0)
		problems.append_array(t._fit_problems("techniques %s" % ui, menu.panel, t.root.get_visible_rect()))
		var small: Array = _tab_buttons("tech_form").filter(func(b): return b.size.y < 36.0)
		if not small.is_empty():
			problems.append("techniques %s: a button under 36 tall" % ui)
	_check(problems.is_empty(), "the Techniques tab fits 844x390 at every Interface size, every button big enough to touch (%d problems): %s" % [problems.size(), problems.slice(0, 6)])
	menu.close()
	menu._set_setting("ui_size", keep)
	main.touch._set_active(false)
	t.root.size = was_size
	await t._frames(2)
	main.on_train = false
