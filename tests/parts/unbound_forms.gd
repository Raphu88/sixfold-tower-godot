extends RefCounted
## The Unbound's new forms and capstones (scripts/spells/unbound_forms.gd):
## each form opens at its level and casts with one, two and three essences
## and with a variation, hits and strains; each capstone works; nothing is
## left a placeholder; old Unbound saves are unaffected.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.
const TestRun := preload("res://scripts/test_run.gd")  # (every user:// path a test touches: its own run folder)

const F := preload("res://scripts/spells/unbound_forms.gd")

var t
var T
var U
var TR
var L


func run(smoke) -> void:
	t = smoke
	T = load("res://scripts/technique.gd")
	U = load("res://scripts/unbound.gd")
	TR = load("res://scripts/tree.gd")
	L = load("res://scripts/library.gd")
	await _written()
	await _opening()
	await _casting()
	await _capstones()
	await _old_saves()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _fresh() -> void:
	await t._ub_fresh()
	var main = t.main
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.player.iframes = 9999.0
	main.player.mouse_aim = false
	main.player.aim = Vector2.RIGHT
	main.unbound.waver_chance = 0.0


## A tough slime that stands still.
func _foe(at: Vector2):
	var e = await t._spawn("slime", at)
	e.hp = 2000.0
	e.max_hp = 2000.0
	return e


func _clear_foes() -> void:
	for e in t.main.enemies():
		e.queue_free()
	await t._frames(2)


## A spot with room around it (the middle of the room).
func _spot() -> Vector2:
	var main = t.main
	var c: Vector2 = main.room.get_center()
	for i in 40:
		var q := c + Vector2(float(i % 7 - 3) * 40.0, float(i / 7 - 3) * 40.0)
		var ok := true
		for d in [Vector2(-170, 0), Vector2(170, 0), Vector2(0, -170), Vector2(0, 170), Vector2(320, 0), Vector2(-120, -120), Vector2(120, 120)]:
			if main.is_solid(q + d) or not main.room.has_point(q + d):
				ok = false
		if ok:
			return q
	return c


func _written() -> void:
	print("the Unbound's forms: every one written")
	var all_built := true
	var missing: Array = []
	for id in F.FORMS:
		if not L.built(L.form(id)) or not L.FORMS.has(id):
			all_built = false
			missing.append(id)
	_check(all_built and F.FORMS.size() == 12, "all twelve new forms are written and in the library (%s)" % [missing])
	var caps_ok := true
	for part in U.PARTS:
		var cap: Dictionary = F.capstone(part)
		if not L.built(cap) or String(cap.get("name", "")) == "" or String(cap.get("says", "")) == "":
			caps_ok = false
	_check(caps_ok, "all six capstones are written, each with a name and one plain line")
	var tree_ok := true
	for part in U.PARTS:
		for L_ in F.TREE[part]:
			var spec: Dictionary = F.TREE[part][L_]
			if spec.has("form") and (not L.built(L.form(String(spec["form"]))) or int(L.form(String(spec["form"]))["opens"]) != int(L_) or String(L.form(String(spec["form"]))["part"]) != part):
				tree_ok = false
	_check(tree_ok, "every form in the tree opens at its level, on its part")
	var banned := ["attunement", "spire", "trial", "judgment", "mana"]
	var words := JSON.stringify(F.FORMS) + JSON.stringify(F.TREE) + JSON.stringify(F.TEXT)
	_check(not banned.any(func(b): return words.to_lower().contains(b)), "none of the banned words")


func _opening() -> void:
	print("the Unbound's forms: each opens at its level")
	await _fresh()
	var prof = t.main.profile
	var ok := true
	var bad: Array = []
	for id in F.FORMS:
		var fe: Dictionary = F.FORMS[id]
		var part := String(fe["part"])
		var at := int(fe["opens"])
		prof.part_density = {part: {String(U.PART_KIND[part]): float(U.LEVELS[at - 2])}}
		var before: bool = id in TR.owned_forms(prof, part)
		var st_before := String(TR.node(prof, "unbound:%s:%d" % [part, at])["options"][0]["state"])
		prof.part_density = {part: {String(U.PART_KIND[part]): float(U.LEVELS[at - 1])}}
		var after: bool = id in TR.owned_forms(prof, part)
		var st_after := String(TR.node(prof, "unbound:%s:%d" % [part, at])["options"][0]["state"])
		if before or not after or st_before != "locked" or st_after != "owned" or not T.valid({"part": part, "shape": id, "kinds": ["fire"]}):
			ok = false
			bad.append(id)
	_check(ok, "each form is locked a level short and opens at its level (%s)" % [bad])
	# Capstones: locked until level 10, then yours; no Coming later left on an Unbound tree.
	prof.part_density = {}
	var later := 0
	for part in U.PARTS:
		prof.part_density[part] = {String(U.PART_KIND[part]): float(U.LEVELS[8])}
	var locked: bool = U.PARTS.all(func(part): return TR.node(prof, "unbound:%s:10" % part)["state"] == "locked" and not F.capstone_on(prof, part))
	for part in U.PARTS:
		prof.part_density[part] = {String(U.PART_KIND[part]): float(U.LEVELS[9])}
	var owned: bool = U.PARTS.all(func(part): return TR.node(prof, "unbound:%s:10" % part)["state"] == "owned" and F.capstone_on(prof, part))
	for part in U.PARTS:
		for n in TR.unbound_nodes(prof, part):
			if n["kind"] in ["form", "capstone"]:
				for o in n["options"]:
					if o["state"] == "placeholder":
						later += 1
	_check(locked and owned, "each capstone is locked at level 9 and the climber's at level 10")
	_check(later == 0, "no form or capstone on an Unbound tree is Coming later any more (%d)" % later)
	_check(TR.node(prof, "unbound:hand:10")["options"][0]["name"] == "Raw Hands", "...the capstone's name shows on the tree")
	_check("cap_hand" in TR.owned(prof) and "brand" in TR.owned(prof), "...and owned() lists capstones and forms")


## Where a foe should stand to be struck by a form cast from `at`, aiming right.
func _foe_spot(id: String, at: Vector2) -> Vector2:
	match id:
		"call":
			return at + Vector2(200, 0)
		"glare":
			return at + Vector2(110, 0)
		"omen":
			return at + Vector2(90, 0)
		"vault", "stride":
			return at + Vector2(-26, 0)
		"wake", "hum", "heartbeat":
			return at + Vector2(0, 50)
	return at + Vector2(38, 0)


func _casting() -> void:
	print("the Unbound's forms: casting with every mix")
	await _fresh()
	var main = t.main
	var p = main.player
	var run = main.unbound
	var prof = main.profile
	var TB = load("res://scripts/technique_bond.gd")
	var FX = load("res://scripts/spell_fx.gd")
	_check(main.get_node_or_null(F.NODE) != null, "the forms' node is under the game from the start (for the capstones)")
	var mixes := [["fire"], ["water", "stone"], ["iron", "blade", "air"]]
	var vars: Array = L.VARIATION_ORDER.duplicate()
	var vi := 0
	var fails: Array = []
	var strain_fails: Array = []
	for id in F.FORMS:
		var part := String(F.FORMS[id]["part"])
		prof.part_density = {part: {String(U.PART_KIND[part]): float(U.LEVELS[9])}}
		var cases: Array = []
		for m in mixes:
			cases.append({"kinds": m})
		cases.append({"kinds": ["air", "fire"], "vars": [vars[vi % vars.size()]]})
		cases.append({"kinds": ["blade"], "vars": [vars[(vi + 5) % vars.size()]], "effects": {}})
		vi += 1
		for c in cases:
			var tech := {"name": "", "part": part, "shape": id, "kinds": c["kinds"]}
			if c.has("vars"):
				tech["vars"] = c["vars"]
			await _clear_foes()
			F.of(main).pieces.clear()
			FX.clear(main)
			run.bolts.clear()
			var at := _spot()
			p.global_position = at
			p.aim = Vector2.RIGHT
			p.jump_t = 0.0
			p.roll_t = 0.0
			p.hp = p.max_health()
			p.barrier_hp = 0.0
			p.barrier_t = 0.0
			await t._frames(1)
			var e = await _foe(_foe_spot(id, at))
			var hp0: float = e.hp
			var hp_me: float = p.hp
			# Cast through the climb (fill, strain), from a full gauge.
			var b = TB.new(tech, part, 0, run)
			b.essence = b.capacity()
			run.strain.clear()
			run.dark.clear()
			run.cast(b, p)
			var want: float = float(T.STRAIN[tech["kinds"].size() - 1]) + float(F.FORMS[id]["strain"]) + (4.0 if c.has("vars") else 0.0)
			if not is_equal_approx(run.strain_of(part), want) or not is_equal_approx(T.strain(tech), want):
				strain_fails.append("%s %s: %.0f, not %.0f" % [id, tech.get("vars", []), run.strain_of(part), want])
			if id == "mantle":
				await t._frames(3)
				p.iframes = 0.0
				p.hurt_t = 0.0
				p.receive_attack(4.0, e)
				p.iframes = 9999.0
			var hit := false
			var worked := false
			for f in 150:
				await t._frames(1)
				if is_instance_valid(e) and e.hp < hp0:
					hit = true
					break
			if id == "wellspring":
				hit = true  # (it works on you: below)
				worked = p.kindle_t > 0.0 or p.heal_left > 0.0 or p.haste_t > 0.0 or p.stone_t > 0.0 or p.salts_t > 0.0 or p.edge_t > 0.0 or p.hp > hp_me
				if not worked:
					hit = false
			if not hit:
				fails.append("%s %s %s" % [id, tech["kinds"], tech.get("vars", [])])
			p.iframes = 9999.0
	_check(fails.is_empty(), "every new form hits with one, two and three essences and with variations (%s)" % [fails])
	_check(strain_fails.is_empty(), "...and adds its strain: by how many kinds, plus its form's and its variation's (%s)" % [strain_fails])
	# A few specifics.
	await _clear_foes()
	var at := _spot()
	p.global_position = at
	F.of(main).pieces.clear()
	run.bolts.clear()
	T.cast({"part": "hand", "shape": "brand", "kinds": ["fire"]}, p, 1.0, run)
	_check(F.of(main).pieces.size() == 1 and F.of(main).pieces[0]["kind"] == "brand", "Brand sets a burst that waits")
	F.of(main).pieces.clear()
	T.cast({"part": "back", "shape": "wake", "kinds": ["stone"], "vars": ["split"]}, p, 1.0, run)
	var centres: Array = F.of(main).pieces.map(func(pc): return pc["c"])
	_check(centres.size() == 3 and centres.all(func(c): return c.distance_to(at) > 40.0), "a Split Wake fans three rings out in front of you")
	F.of(main).pieces.clear()
	T.cast({"part": "throat", "shape": "hum", "kinds": ["water"], "vars": ["long"]}, p, 1.0, run)
	_check(F.of(main).pieces.size() == 1 and F.of(main).pieces[0]["r"] > float(F.FORMS["hum"]["radius"]) * 1.3, "Long stretches a Hum's ring")
	F.of(main).pieces.clear()
	var d0: String = T.describe({"part": "brow", "shape": "glare", "kinds": ["fire", "air"]})
	_check(d0.begins_with("A narrow beam you hold for a second.") and d0.contains("burns"), "a new form's card says what it does (%s)" % d0)
	# Unmaking's toll still applies to a new form.
	prof.path = "unmaking"
	p.hp = 50.0
	T.cast({"part": "throat", "shape": "call", "kinds": ["unmaking"]}, p, 1.0, run)
	_check(p.hp < 50.0, "Unmaking in a new form costs a little health")
	prof.path = ""
	p.hp = p.max_health()
	F.of(main).pieces.clear()
	# A new floor clears them.
	T.cast({"part": "brow", "shape": "omen", "kinds": ["fire"]}, p, 1.0, run)
	main.floor_num += 1
	await t._frames(2)
	_check(F.of(main).pieces.is_empty(), "a new floor clears what the forms left behind")
	main.floor_num -= 1


## Puts every part at level 10 (or 9) and rebuilds the climber.
func _levels(level: int) -> void:
	var prof = t.main.profile
	prof.part_density = {}
	for part in U.PARTS:
		prof.part_density[part] = {String(U.PART_KIND[part]): float(U.LEVELS[level - 1])}
	t.main._give_bonds()
	t.main.player.iframes = 9999.0
	await t._frames(3)


func _cast_part(part: String) -> void:
	var p = t.main.player
	var b = p.bonds[part]
	b.essence = b.capacity()
	t.main.unbound.cast(b, p)
	await t._frames(3)


func _capstones() -> void:
	print("the Unbound's capstones")
	await _fresh()
	var main = t.main
	var p = main.player
	var run = main.unbound
	var at := _spot()
	# Raw Hands: three foes around you, a bolt for each (not only the one aimed at).
	await _levels(9)
	p.global_position = at
	var foes: Array = []
	for d in [Vector2(0, -90), Vector2(0, 90), Vector2(-90, 0)]:
		foes.append(await _foe(at + d))
	var hp0: Array = foes.map(func(e): return e.hp)
	await _cast_part("hand")
	await t._wait(0.6)
	_check(foes.all(func(e): return e.hp == hp0[foes.find(e)]), "without the capstone, a hand technique only throws its own bolt")
	await _levels(10)
	p.global_position = at
	p.aim = Vector2.RIGHT
	hp0 = foes.map(func(e): return e.hp)
	await _cast_part("hand")
	await t._wait(0.6)
	var struck := 0
	for i in foes.size():
		if foes[i].hp < hp0[i]:
			struck += 1
	_check(struck == 3, "Raw Hands: a hand technique throws raw bolts at three foes near you (%d struck)" % struck)
	await _clear_foes()
	# Afterimage: a foe behind where you stood is struck a moment after a dash.
	p.global_position = at
	p.aim = Vector2.RIGHT
	var behind = await _foe(at + Vector2(-50, 0))
	var hb: float = behind.hp
	await t._frames(1)
	await _cast_part("legs")
	await t._wait(0.8)
	_check(behind.hp < hb, "Afterimage: a legs technique leaves an afterimage that bursts where you stood")
	await _clear_foes()
	# Unbowed: a back technique raises a light shell; strain fades everywhere while it holds.
	p.barrier_hp = 0.0
	p.barrier_t = 0.0
	run.strain["hand"] = 60.0
	run.idle["hand"] = 0.0
	var push := {"name": "", "part": "back", "shape": "push", "kinds": ["air"]}
	var TB = load("res://scripts/technique_bond.gd")
	var pb = TB.new(push, "back", 5, run)
	pb.essence = pb.capacity()
	run.cast(pb, p)
	await t._frames(3)
	_check(p.barrier_hp > 0.0, "Unbowed: a back technique (a Push) raises a light shell")
	run.idle["hand"] = 0.0
	var s0: float = run.strain_of("hand")
	await t._wait(0.4)
	_check(run.strain_of("hand") < s0 - 2.0 and float(run.idle["hand"]) < run.STRAIN_REST, "...and while it holds, the hand's strain fades, though it was just cast (%.1f -> %.1f)" % [s0, run.strain_of("hand")])
	# Rallying Cry: other techniques fill, other parts cool, stamina comes back.
	for b in p.bonds.values():
		b.essence = 0.0
	run.strain["hand"] = 30.0
	p.sta = 0.0
	var sb = p.bonds["throat"]
	sb.essence = sb.capacity()
	run.cast(sb, p)
	await t._frames(3)
	var hand_b = p.bonds["hand"]
	_check(is_equal_approx(hand_b.essence, hand_b.capacity() * float(F.capstone("throat")["fill"])) and is_equal_approx(p.bonds["throat"].essence, 0.0), "Rallying Cry: a throat technique fills the others by a quarter (%.1f), not itself" % hand_b.essence)
	_check(run.strain_of("hand") <= 20.5 and p.sta >= p.max_sta - 0.5, "...cools the other parts by 10 and gives back your stamina")
	# Piercing Gaze: every foe near you is marked, not only the one aimed at.
	p.global_position = at
	var a = await _foe(at + Vector2(60, 0))
	var b2 = await _foe(at + Vector2(0, -120))
	await _cast_part("brow")
	_check(a.challenged_t >= 3.5 and b2.challenged_t >= 3.5, "Piercing Gaze: a brow technique marks every foe near you")
	await _clear_foes()
	# Second Heart: once a floor, below a third of your health.
	run.strain["legs"] = 80.0
	p.hp = p.max_health() * 0.2
	await t._frames(3)
	_check(p.hp >= p.max_health() * 0.55 and run.strain_of("legs") == 0.0, "Second Heart: below a third of your health, 40%% back and every part's strain gone (%.0f)" % p.hp)
	p.hp = p.max_health() * 0.2
	await t._frames(3)
	_check(p.hp < p.max_health() * 0.3, "...once a floor")
	p.hp = p.max_health()
	main.floor_num += 1
	await t._frames(3)
	p.hp = p.max_health() * 0.2
	await t._frames(3)
	_check(p.hp >= p.max_health() * 0.55, "...and again on the next floor")
	main.floor_num -= 1
	p.hp = p.max_health()
	# Marked climbers never have them.
	main.profile.unbound["on"] = false
	_check(not U.PARTS.any(func(part): return F.capstone_on(main.profile, part)), "a marked climber has no capstones")
	main.profile.unbound["on"] = true


func _old_saves() -> void:
	print("the Unbound's forms: old saves")
	await _fresh()
	var P = load("res://scripts/profile.gd")
	var path := TestRun.path("user://smoke_unbound_forms.cfg")
	var techs: Array = []
	for id in T.STARTERS:
		techs.append(T.recipe(id))
	var cfg := ConfigFile.new()
	cfg.set_value("profile", "regarded", true)
	cfg.set_value("profile", "part_density", {"hand": {"blade": 130.0}, "legs": {"air": 20.0}})
	cfg.set_value("unbound", "state", {"on": true, "found": true, "routes": {}, "techs": techs})
	cfg.save(path)
	var old = P.new()
	old.saving = false
	old.save_path = path
	old.load_save()
	var st: Dictionary = U.state(old)
	var same := true
	for i in T.STARTERS.size():
		var r: Dictionary = T.recipe(T.STARTERS[i])
		var s: Dictionary = st["techs"][i]
		if s["shape"] != r["shape"] or s["kinds"] != r["kinds"] or not T.valid(s) or T.strain(s) != float(T.STRAIN[0]) or T.describe(s) != T.describe(r):
			same = false
	_check(U.is_on(old) and same, "an old Unbound save keeps its six techniques as they were (shape, essences, strain, words)")
	_check(TR.owned_forms(old, "hand") == ["strike", "bolt", "volley"] and TR.owned_forms(old, "legs") == ["dash", "leap"], "...and opens only the forms its levels reach")
	_check(not U.PARTS.any(func(part): return F.capstone_on(old, part)), "...and no capstone before level 10")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
