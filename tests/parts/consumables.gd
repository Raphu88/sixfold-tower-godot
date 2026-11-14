extends RefCounted
## Consumables with a job: fewer of them found (essence instead), monsters'
## states on the climber (shown on the HUD, each cured by its item), what
## each tower asks for (a net brings a flier down, Edge Oil cracks a shell,
## Lantern Oil carries your light on a dark floor...), item sizes (Minor,
## standard, Greater), old saves, the Entity's words and no banned words.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const I := preload("res://scripts/items.gd")
const R := preload("res://scripts/reactions.gd")
const Needs := preload("res://scripts/tower_needs.gd")
const Towers := preload("res://scripts/towers.gd")
const RR := preload("res://scripts/room_rewards.gd")
const P := preload("res://scripts/profile.gd")
const Entity := preload("res://scripts/entity.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const Best := preload("res://scripts/bestiary.gd")
const Draw := preload("res://scripts/draw_util.gd")
const TestRun := preload("res://scripts/test_run.gd")

const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

var t


func run(smoke) -> void:
	t = smoke
	_drops()
	await _states()
	await _towers()
	await _sizes()
	_saves()
	_words()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## A climb with marks, no monsters, the climber in the open (not dodging).
func _fresh(tower := "gryphon"):
	await t._fresh_main()
	t.paused = false
	var m = t.main
	m.touch._set_active(false)
	m.pad._set_active(false)
	m.grant_test_bonds()
	m.first_climb = false
	m.tower = tower
	for x in m.enemies():
		x.queue_free()
	await t._frames(2)
	var p = m.player
	p.global_position = m.room.get_center()
	p.aim = Vector2.RIGHT
	p.iframes = 0.0
	p.hurt_t = 0.0
	p.barrier_hp = 0.0
	p.states.clear()
	p.poison_t = 0.0
	p.buffs.clear()
	m.puddles = []
	return p


func _foe(kind: String, at: Vector2, hp := 400.0):
	var e = t.main.spawn_enemy(kind, at)
	e.set_physics_process(false)
	e.global_position = at
	e.max_hp = hp
	e.hp = hp
	e.aware = true
	return e


## A blow from a monster that lands (no grace, no roll, no parry).
func _hit(p, e, dmg := 1.0) -> void:
	p.iframes = 0.0
	p.hurt_t = 0.0
	p.parry_t = 0.0
	p.barrier_hp = 0.0
	p.receive_attack(dmg, e)


# --- fewer drops ------------------------------------------------------------------------

## The old rules (before this change), for the comparison: a kill's item chance
## 0.1 with Healing 12 and Stamina 10 against every other droppable item at 1,
## a cache's 0.35, a fallen climber's camp always one, three camp item cards.
func _drops() -> void:
	print("consumables: fewer drops, essence instead")
	seed(4242)
	var n := 20000
	var items := 0
	var staples := 0
	var essence := 0
	for i in n:
		var d: Dictionary = I.kill_drop(5, true, "gryphon")
		if d.has("item"):
			items += 1
			if I.is_staple(d["item"]):
				staples += 1
		elif d.has("essence"):
			essence += 1
	var droppable := 0
	for id in I.ORDER:
		if int(I.ITEMS[id]["drop_weight"]) > 0 and not I.is_staple(id) and id != "scroll" and id != "vessel" and not id in ["warding_oil", "stoneskin", "heartroot", "unmaking_ash"]:
			droppable += 1
	var old_rare_per_kill := 0.1 * float(droppable) / float(droppable + 22)
	var old_staple_per_kill := 0.1 * 22.0 / float(droppable + 22)
	var rare_per_kill := float(items - staples) / n
	var staple_per_kill := float(staples) / n
	_check(staple_per_kill > old_staple_per_kill * 0.9, "Healing and Stamina Draughts are as common from kills as before (%.3f a kill; was %.3f)" % [staple_per_kill, old_staple_per_kill])
	_check(rare_per_kill < old_rare_per_kill, "the rarer items come less often from kills (%.3f a kill; was %.3f)" % [rare_per_kill, old_rare_per_kill])
	_check(essence > n * 0.04, "a kill that leaves no item sometimes leaves essence instead (%d of %d)" % [essence, n])
	# A typical climb, by the same model the report used: ~88 kills, ~36 caches, ~5 fallen camps.
	var kills := 88.0
	var caches := 36.0
	var fallen := 5.4
	var before := kills * 0.1 + caches * 0.35 + fallen * 1.0
	var after := kills * float(items) / n + caches * float(RR.RULES["item_chance"]) + fallen * float(I.DROPS["fallen_item"])
	_check(after <= before * 0.65 and after >= before * 0.45, "about 40-50%% fewer consumables a climb (%.1f, was %.1f)" % [after, before])
	_check(float(RR.RULES["no_item"]) > 1.0, "a cache with no item holds more essence instead")
	_check(I.CAMP_CHOICES == 2, "a camp offers two items (and a crystal and gear), not three")
	seed(Time.get_ticks_usec())


# --- states on the climber ------------------------------------------------------------

func _states() -> void:
	print("consumables: monsters' states on the climber, the HUD, cures and wards")
	var p = await _fresh()
	var m = t.main
	_check(bool(R.CLIMBER["enabled"]), "monsters' states on the climber are on")
	# Each state from its monster, on the HUD, cured by its item.
	var cases := [["scorpling", "poisoned", "antidote"], ["cinder", "burning", "warding_oil"], ["thornhound", "bleeding", "heartroot"],
		["lurker", "soaked", "tonic"], ["thunderling", "charged", "stoneskin"]]
	for c in cases:
		p.states.clear()
		p.poison_t = 0.0
		p.buffs.clear()
		p.hp = p.max_health() - 30.0
		var e = _foe(c[0], p.global_position + Vector2(40, 0))
		e.submerged = false
		_hit(p, e)
		var held: bool = R.climber_held(p).any(func(r): return r[0] == c[1])
		_check(held and String(R.CLIMBER["from"].get(c[0], "")) == c[1], "a %s's blow leaves you %s" % [c[0], c[1]])
		var chips: Array = m.hud.state_chips()
		var chip: Dictionary = {}
		for ch in chips:
			if ch["id"] == "state:" + c[1]:
				chip = ch
		_check(not chip.is_empty() and chip.get("glyph", "") == c[1] and chip.has("gauge") and String(chip["text"]).contains(String(I.ITEMS[c[2]]["name"]))
			and String(chip["text"]).contains("s"), "...the HUD shows it with its sign, its seconds and its cure (%s)" % chip.get("text", "none"))
		_check(m.hud.status_chips().any(func(ch): return ch["id"] == "state:" + c[1]), "...among the status chips under the banner")
		p.items = {c[2]: 1}
		p.item_sel = c[2]
		_check(p.use_item() and not R.climber_held(p).any(func(r): return r[0] == c[1]), "...and the %s cures it" % I.ITEMS[c[2]]["name"])
		e.queue_free()
	# A Cleansing Tonic takes any of them off.
	p.buffs.clear()
	p.states = {"burning": 3.0, "bleeding": 3.0, "soaked": 3.0, "charged": 3.0}
	p.poison(3.0)
	p.items = {"tonic": 1}
	p.item_sel = "tonic"
	_check(p.use_item() and R.climber_held(p).is_empty(), "a Cleansing Tonic cures every state at once")
	# Wards: while their item lasts, the state can't take hold.
	var wards := [["antidote", "poisoned"], ["warding_oil", "burning"], ["briar_tonic", "bleeding"], ["stoneskin", "charged"]]
	for w in wards:
		p.buffs.clear()
		p.states.clear()
		p.poison_t = 0.0
		p.items = {w[0]: 1}
		p.item_sel = w[0]
		p.use_item()
		R.apply(m, p, w[1], 3.0, "test")
		_check(not R.climber_held(p).any(func(r): return r[0] == w[1]), "while its %s lasts, no %s takes hold" % [I.ITEMS[w[0]]["name"], w[1]])
	p.buffs.clear()
	# Fair: burning and bleeding never take your last point; soaked and charged only slow.
	p.states = {"burning": 3.0, "bleeding": 3.0}
	p.hp = 2.0
	for i in 40:
		R.tick_climber(p, 0.1)
	_check(p.hp >= 1.0 and not p.dead and p.states.is_empty(), "burning and bleeding wear off and never take your last health (%.1f)" % p.hp)
	p.hp = p.max_health()
	p.states = {"soaked": 2.0, "charged": 2.0}
	_check(R.climber_walk(p) < 1.0 and R.climber_regen(p) < 1.0, "soaked slows your walk and charged your stamina (nothing stuns)")
	_check(R.climber_seconds("poisoned") <= 6.0 and R.climber_seconds("burning") <= 6.0 and R.climber_seconds("bleeding") <= 6.0
		and R.climber_seconds("soaked") <= 6.0 and R.climber_seconds("charged") <= 6.0, "every state on you is short (6 seconds at most)")
	# A new blow refreshes a state, never stacks it longer.
	p.states.clear()
	R.apply(m, p, "burning", 3.0, "test")
	R.apply(m, p, "burning", 3.0, "test")
	_check(float(p.states.get("burning", 0.0)) <= 3.01, "a second blow refreshes a state, never makes it longer")
	# A parried or rolled-through blow leaves nothing.
	p.states.clear()
	var c2 = _foe("cinder", p.global_position + Vector2(40, 0))
	p.iframes = 1.0
	p.receive_attack(1.0, c2)
	_check(p.states.is_empty(), "a blow you roll through leaves nothing")
	p.iframes = 0.0
	c2.queue_free()
	# The stair's rest clears them.
	p.states = {"burning": 3.0}
	p.poison(3.0)
	m._arrive()
	await t._frames(2)
	_check(m.player.states.is_empty() and m.player.poison_t <= 0.0, "the stair's rest clears every state")
	# The Bestiary says what each monster leaves and what cures it.
	var lines: Array = Best.state_lines("scorpling")
	_check(" ".join(lines).contains("poisoned") and " ".join(lines).contains("Antivenom"), "the Bestiary's scorpling says it poisons you, and Antivenom cures it")
	# The Entity: a first-time tip for each state and the talk topic.
	for st in ["state_burning", "state_bleeding", "state_soaked", "state_charged", "climber_states", "poison"]:
		_check(Entity.TIPS.has(st) and String(Entity.TIPS[st]["tip"]) != "", "the Entity explains %s the first time" % st)
	var f: Dictionary = Talk.facts(m, Talk.DIALOGUE["how_states"])
	_check(String(f.get("states", "")).contains("Antivenom") and String(f.get("states", "")).contains("thornhound"), "\"What are states, and how do I cure them?\" names monsters and cures: %s" % String(f.get("states", "")).left(80))
	_check("how_states" in Talk.DIALOGUE["how"]["choices"] and "how_handy" in Talk.DIALOGUE["how"]["choices"], "...both new topics are under \"How do things work here?\"")


# --- what each tower asks for -------------------------------------------------------

func _towers() -> void:
	print("consumables: what each tower asks for")
	for tid in Towers.ORDER:
		var h: Array = Needs.handy(tid)
		_check(h.size() >= 1 and h.size() <= 2 and h.all(func(id): return I.ITEMS.has(id) and Needs.why(tid, id) != ""), "%s asks for %s, each with a reason" % [tid, h])
		_check(Needs.arrival_line(tid) != "", "...and its arrival banner says so")
	# A tower's handy items turn up more there.
	seed(99)
	var here := 0
	var there := 0
	for i in 6000:
		if I.random_item(true, [], true, "manticore") == "antidote":
			here += 1
		if I.random_item(true, [], true, "gryphon") == "antidote":
			there += 1
	_check(here > there * 2, "Antivenom is found more in the Manticore's tower (%d) than elsewhere (%d)" % [here, there])
	var root := false
	var root_else := false
	for i in 6000:
		root = root or I.random_item(true, [], true, "chimera") == "heartroot"
		root_else = root_else or I.random_item(true, [], true, "gryphon") == "heartroot"
	_check(root and not root_else, "Heartroot is left by monsters in the Chimera's tower, and only there")
	seed(Time.get_ticks_usec())
	var p = await _fresh("kraken")
	var m = t.main
	# Lantern Oil on a dark floor.
	var lit: float = m.lighting.player_reach()
	_check(Needs.darkness("kraken", 2).is_empty() and not Needs.darkness("kraken", 5).is_empty(), "the Kraken's deep floors are dark (from floor %d)" % int(Needs.DARK["kraken"]["from"]))
	var dark: Dictionary = Needs.darkness("kraken", 5)
	m.lighting.set_floor_dark(float(dark["reach"]), float(dark["fog"]))
	var dim: float = m.lighting.player_reach()
	p.items = {"lantern_oil": 1}
	p.item_sel = "lantern_oil"
	p.use_item()
	var oiled: float = m.lighting.player_reach()
	_check(dim < lit * 0.8 and oiled > lit, "on a dark floor your light reaches less far (%d, not %d); Lantern Oil carries it farther than ever (%d)" % [int(dim), int(lit), int(oiled)])
	m.lighting.set_floor_dark(1.0, 0.0)
	p.buffs.clear()
	# A net brings a flier down (held longer than a walker).
	var bat = _foe("bat", p.global_position + Vector2(90, 0))
	var slime = _foe("slime", p.global_position + Vector2(-90, 0))
	I.burst(m, {"id": "net", "to": bat.global_position, "r": 40.0})
	I.burst(m, {"id": "net", "to": slime.global_position, "r": 40.0})
	_check(bat.stun >= 2.0 and slime.stun < bat.stun and bat.chill_t > 0.0, "a net brings a bat down for %.1f s (a slime only %.1f s)" % [bat.stun, slime.stun])
	bat.queue_free()
	slime.queue_free()
	# Edge Oil cracks a shellback's shell.
	var sh = _foe("shellback", p.global_position + Vector2(40, 0), 1000.0)
	sh.face = Vector2.LEFT  # (facing the climber: its shell turns the blow)
	sh.stun = 0.0
	p.edge_t = 0.0
	p.quarry = sh  # (both strikes alike for a Hunter's Quarry)
	p._strike(sh, 20.0, Vector2.RIGHT, 0.0, false)
	var plain: float = 1000.0 - sh.hp
	sh.hp = 1000.0
	sh.stun = 0.0
	sh.face = Vector2.LEFT
	p.edge_t = 10.0
	p.quarry = sh
	p._strike(sh, 20.0, Vector2.RIGHT, 0.0, false)
	var cracked: float = 1000.0 - sh.hp
	p.edge_t = 0.0
	_check(cracked > plain * 2.5, "oiled strikes crack a shellback's shell (%.1f through it, not %.1f)" % [cracked, plain])
	sh.queue_free()
	# The Entity's tower topic reads the needs.
	m.tower = "chimera"
	var f: Dictionary = Talk.facts(m, Talk.DIALOGUE["how_handy"])
	_check(String(f.get("handy", "")).contains("Briar Tonic") and String(f.get("handy", "")).contains("Heartroot"), "\"What's handy in this tower?\" reads the tower's needs: %s" % String(f.get("handy", "")).left(80))


# --- sizes ---------------------------------------------------------------------------

func _sizes() -> void:
	print("consumables: Minor, standard and Greater")
	_check(is_equal_approx(float(I.sized("draught", 1)["heal"]), 24.0) and is_equal_approx(float(I.sized("draught", 2)["heal"]), 40.0)
		and is_equal_approx(float(I.sized("draught", 3)["heal"]), 60.0), "a Minor, standard and Greater Healing Draught heal 24, 40 and 60")
	_check(float(I.sized("antidote", 3)["duration"]) > float(I.sized("antidote", 1)["duration"]), "a Greater Antivenom lasts longer than a Minor one")
	_check(not I.is_sized("vial") and I.clamp_size("vial", 3) == I.STANDARD and I.is_sized("stamina") and I.is_sized("net"), "staples and the main items come in sizes; an Essence Vial doesn't")
	_check(I.sized_name("draught", 3) == "Greater Healing Draught" and I.sized_name("draught", 1) == "Minor Healing Draught" and I.sized_name("draught", 2) == "Healing Draught",
		"their names say the size")
	var p = await _fresh()
	var m = t.main
	p.items = {}
	_check(p.add_item("draught", 1) and p.add_item("draught", 3) and p.item_count("draught") == 2 and p.carried().size() == 1, "two sizes share one belt kind")
	var en: Dictionary = p.belt_entry("draught")
	_check(en["size"] == 3 and en["name"] == "Greater Healing Draught" and en["sizes"] == [3, 1], "a stack uses its biggest first, and its entry says so (%s)" % [en])
	p.hp = 10.0
	p.heal_left = 0.0
	p.item_sel = "draught"
	p.use_item()
	var greater: float = p.heal_left
	p.heal_left = 0.0
	p.hp = 10.0
	p.use_item()
	var minor: float = p.heal_left
	_check(greater > minor * 2.0 and p.item_count("draught") == 0, "the Greater one healed more (%.0f) than the Minor (%.0f)" % [greater, minor])
	p.heal_left = 0.0
	p.hp = p.max_health()
	# A sized net holds longer.
	var a = _foe("slime", p.global_position + Vector2(90, 0))
	var b = _foe("slime", p.global_position + Vector2(-90, 0))
	I.burst(m, {"id": "net", "to": a.global_position, "r": 40.0, "size": 3})
	I.burst(m, {"id": "net", "to": b.global_position, "r": 40.0, "size": 1})
	_check(a.stun > b.stun and a.chill_t > b.chill_t, "a Greater net holds longer than a Minor one")
	a.queue_free()
	b.queue_free()
	# A full stack: a bigger one swaps out the smallest (left at your feet).
	p.items = {}
	for i in p.max_stack("antidote"):
		p.add_item("antidote", 1)
	m.item_drops.clear()
	m.item_drops.append({"pos": p.global_position, "id": "antidote", "size": 3, "t": 30.0})
	await t._frames(3)
	_check(p.belt_entry("antidote")["size"] == 3 and p.item_count("antidote") == p.max_stack("antidote")
		and m.item_drops.any(func(d): return d["id"] == "antidote" and int(d.get("size", 0)) == 1), "a Greater one swaps out your smallest from a full stack (it waits at your feet)")
	# Pips: the icon shows the size.
	var plain := Draw.Batch.new()
	I.icon_into(plain, "draught", Vector2.ZERO, 10.0)
	var pipped := Draw.Batch.new()
	I.icon_into(pipped, "draught", Vector2.ZERO, 10.0, 3)
	_check(pipped.size() > plain.size(), "a sized icon carries its pips")
	# Drops roll sizes by depth.
	seed(7)
	var low := {1: 0, 2: 0, 3: 0}
	var high := {1: 0, 2: 0, 3: 0}
	for i in 3000:
		low[I.roll_size("draught", 1)] += 1
		high[I.roll_size("draught", 11)] += 1
	seed(Time.get_ticks_usec())
	_check(low[3] == 0 and high[3] > 600 and high[1] < low[1], "low floors give Minor and standard ones, high floors Greater ones too (%s, %s)" % [low, high])
	# A Greater one is worth more crystals at the end.
	var w1: Dictionary = I.break_value({"draught": 1}, {"draught": [3]})
	var w2: Dictionary = I.break_value({"draught": 1})
	_check(float(w1.get("stone", 0.0)) > float(w2.get("stone", 0.0)), "a Greater one breaks into more crystal")
	_check(Entity.TIPS.has("item_sizes") and Entity.TIPS["belt"]["more"].contains("biggest first"), "the Entity explains sizes, and the belt's explanation mentions them")


# --- old saves -------------------------------------------------------------------------

func _saves() -> void:
	print("consumables: old saves load")
	var path := TestRun.path("user://consumables_test.cfg")
	var cfg := ConfigFile.new()
	cfg.set_value("train", "supplies", {"draught": 2, "antidote": 1, "salts": 1})
	cfg.save(path)
	var prof = P.new()
	prof.save_path = path
	prof.load_save()
	_check(int(prof.supplies.get("draught", 0)) == 2 and int(prof.supplies.get("antidote", 0)) == 1, "an old save's packed supplies load")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	var p = t.main.player
	p.items = {"draught": 2, "antidote": 1}
	_check(p.next_size("draught") == I.STANDARD and p.item_sizes_of("draught") == [2, 2] and p.belt_entry("antidote")["name"] == "Antivenom",
		"items with no size noted (an old belt, the store's supplies) are standard")


# --- words -----------------------------------------------------------------------------

func _words() -> void:
	print("consumables: no banned words")
	var texts: Array = [FileAccess.get_file_as_string("res://scripts/tower_needs.gd")]
	texts.append(JSON.stringify(I.SIZES) + JSON.stringify(I.SIZE_TEXT) + JSON.stringify(I.NET_TEXT) + JSON.stringify(R.CLIMBER_TEXT))
	for id in I.ORDER:
		texts.append(String(I.ITEMS[id].get("desc", "")))
	for k in ["state_burning", "state_bleeding", "state_soaked", "state_charged", "climber_states", "poison", "item_sizes", "tower_handy", "dark_floor", "items", "belt"]:
		texts.append(JSON.stringify(Entity.TIPS.get(k, {})))
	for k in ["how_states", "how_handy", "how_belt"]:
		texts.append(JSON.stringify(Talk.DIALOGUE.get(k, {})))
	var found: Array = []
	var re := RegEx.create_from_string("\\b(" + "|".join(BANNED) + ")\\b")
	for txt in texts:
		for hit in re.search_all(String(txt).to_lower()):
			found.append(hit.get_string(1))
	_check(found.is_empty(), "no banned words in the new words (%s)" % ", ".join(found))
