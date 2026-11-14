extends RefCounted
## Bags (gear.gd BAG, the backpack slot): the pack holds 2 with no bag and
## follows the bag you wear (Satchel 4, Pack 6, Great Pack 8, a charm's
## extra space); a big bag slows you only when it's nearly full, and the
## pack's heading and the HUD say so; an old save holding more than its bag
## loses nothing; a first bag is easy to get. Run by smoke_test.gd
## (_part_tests); `t` is the smoke test.

const G := preload("res://scripts/gear.gd")
const Train := preload("res://scripts/train.gd")
const Storage := preload("res://scripts/storage_view.gd")
const TestRun := preload("res://scripts/test_run.gd")

var t


func run(smoke) -> void:
	t = smoke
	print("bags")
	await t._fresh_main()
	_sizes()
	await _slowing()
	await _heading_and_hud()
	_old_saves()
	_first_bag()


func _main():
	return t.main


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _bare():
	var p = _main().player
	p.gear = G.start_gear()
	p.pack = []
	p.refresh_gear()
	return p


func _sizes() -> void:
	var p = _bare()
	_check(p.pack_size() == 2, "no bag: the pack holds 2 (%d)" % p.pack_size())
	var want := {"satchel": 4, "pack": 6, "great_pack": 8, "climbers_pack": 6, "belt_pouch": 3, "herb_pouch": 3, "bandolier": 3}
	var got := {}
	for id in want:
		p.take_gear(G.make(id))
		got[id] = p.pack_size()
	_check(got == want, "the pack's size follows the bag you wear (%s)" % [got])
	p.take_gear(G.make("pack"))
	p.take_gear(G.make("pocket_clasp"))
	_check(p.pack_size() == 7, "...and a Pocket Clasp charm adds a space (%d)" % p.pack_size())
	# The train's Loadout counts the same way.
	var prof = _main().profile
	prof.heirlooms = {}
	_check(Train.pack_size_with(prof, {}) == 2, "on the train, no bag chosen: 2")
	_check(Train.pack_size_with(prof, {"backpack": G.make("great_pack")}) == 8, "...a Great Pack chosen: 8")


func _slowing() -> void:
	var p = _bare()
	var C = load("res://scripts/combat.gd")
	# Small bags never slow you, however full.
	p.take_gear(G.make("satchel"))
	for i in 4:
		p.pack.append(G.make("dagger"))
	_check(p.bag_slow() == 0.0, "a full Satchel never slows you")
	# A Pack: only once it's nearly full (5 of 6).
	p.take_gear(G.make("pack"))
	p.pack.resize(4)
	_check(p.bag_slow() == 0.0, "a Pack with 4 of 6: not slowed")
	p.pack.append(G.make("dagger"))
	_check(p.bag_slow() > 0.0 and p.bag_slow() <= 0.06, "...with 5 of 6 it's heavy: a little slower (%.2f)" % p.bag_slow())
	var light_slow: float = p.bag_slow()
	# The roll carries less far while heavy.
	p.sta = p.max_sta
	p.roll_cd = 0.0
	p.attack_cd = 0.0
	p._try_roll(Vector2.RIGHT)
	var heavy_roll: float = p.roll_speed
	p.roll_t = 0.0
	p.pack.resize(3)
	p.sta = p.max_sta
	p.roll_cd = 0.0
	p._try_roll(Vector2.RIGHT)
	_check(heavy_roll < p.roll_speed * 0.97, "...and rolls carry less far (%.0f, light %.0f)" % [heavy_roll, p.roll_speed])
	p.roll_t = 0.0
	# A Great Pack slows you more, from 6 of 8.
	p.take_gear(G.make("great_pack"))
	p.pack.resize(5)
	for i in 5:
		p.pack[i] = G.make("dagger")
	_check(p.bag_slow() == 0.0, "a Great Pack with 5 of 8: not slowed")
	p.pack.append(G.make("dagger"))
	_check(p.bag_slow() > light_slow, "...with 6 of 8 it's heavy, and slows you more than a Pack (%.2f)" % p.bag_slow())
	# Walking: slower while heavy.
	var m = _main()
	p.set_physics_process(true)
	p.velocity = Vector2.ZERO
	Input.action_press("move_right")
	await t._frames(4)
	var heavy_v: float = p.velocity.length()
	p.pack.resize(2)
	await t._frames(4)
	var light_v: float = p.velocity.length()
	Input.action_release("move_right")
	_check(heavy_v > 0.0 and heavy_v < light_v * 0.95, "...you walk slower while it's heavy (%.0f, light %.0f)" % [heavy_v, light_v])
	await t._frames(2)
	p.pack = []
	m.player.gear["backpack"] = {}
	p.refresh_gear()


func _heading_and_hud() -> void:
	var m = _main()
	var p = _bare()
	_check(Storage.heading("pack", 5, 6, true) == "Pack  ·  5 of 6  ·  heavy" and Storage.heading("pack", 4, 6) == "Pack  ·  4 of 6", "the pack's heading: 'Pack · 5 of 6 · heavy' when heavy")
	p.take_gear(G.make("pack"))
	for i in 5:
		p.pack.append(G.make("dagger"))
	_check(Storage.pack_heavy(p, p.pack.size(), p.pack_size()), "...worked out from the bag you wear")
	var chips: Array = m.hud.status_chips().filter(func(c): return c["id"] == "heavy")
	_check(chips.size() == 1, "a small HUD cue while you're slowed (%s)" % [chips.map(func(c): return c["text"])])
	m.menu.inv_view = "pack"
	m.menu.open("inventory")
	await t._frames(3)
	var heads: Array = t._all_labels(m.menu.box).filter(func(l): return l.is_visible_in_tree() and l.has_meta("storage_head")).map(func(l): return l.text)
	_check(heads.any(func(h): return String(h).to_lower() == Storage.heading("pack", 5, 6, true).to_lower()), "the inventory's Pack view says it's heavy (%s)" % [heads])
	m.menu.close()
	m.menu.inv_view = "worn"
	await t._frames(2)
	p.pack.resize(4)
	chips = m.hud.status_chips().filter(func(c): return c["id"] == "heavy")
	_check(chips.is_empty(), "...and the cue goes once it's lighter")
	p.pack = []
	p.gear["backpack"] = {}
	p.refresh_gear()


func _old_saves() -> void:
	var path := TestRun.path("user://bags_test.cfg")
	var old := ConfigFile.new()
	old.set_value("profile", "regarded", true)
	var four: Array = []
	for i in 4:
		four.append(G.code(G.make(["axe", "leather_cap", "soft_boots", "plate"][i])))
	old.set_value("train", "pack", four)
	old.set_value("train", "chest", [G.code(G.make("dagger"))])
	old.save(path)
	var prof = load("res://scripts/profile.gd").new()
	prof.save_path = path
	prof.load_save()
	prof.saving = false
	var p = _bare()
	_check(prof.pack.size() == 4 and Train.pack_size_with(prof, prof.wear) == 2, "an old save with 4 pack pieces and no bag loads all 4 (the pack holds 2 now)")
	_check(Train.move(prof, p, "chest", 0) == Train.TEXT["pack_full"] and prof.pack.size() == 4, "...nothing more goes in until it's under")
	_check(Train.equip(prof, p, "pack", 3) == "" and prof.pack.size() == 3 and prof.wear.has("armor"), "...but you can still wear a piece from it")
	_check(Train.move(prof, p, "pack", 0) == "" and prof.pack.size() == 2, "...or move one to the stash; nothing is ever thrown away")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	_main().player.refresh_gear()


func _first_bag() -> void:
	var prof = _main().profile
	prof.wear = {}
	prof.heirlooms = {}
	prof.pack = []
	prof.chest = []
	var rack: Array = Train.roll_outfit(prof)
	_check(rack.any(func(g): return G.base_id(g) == Train.FIRST_BAG), "a climber with no bag always finds a Satchel on the outfitter's rail")
	_check(Train.buy_price(prof, G.make("satchel")) <= 8, "...and it's cheap (%d)" % Train.buy_price(prof, G.make("satchel")))
	prof.chest = [G.make("pack")]
	rack = Train.roll_outfit(prof)
	_check(Train.has_bag(prof), "a bag in the stash counts as having one")
	prof.chest = []
