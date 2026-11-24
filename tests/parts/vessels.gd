extends RefCounted
## The vessel (vessel.gd, vessel_page.gd): a container that keeps essence
## raw. It catches raw tower essence at the stairs (its share isn't banked)
## or the core essence that isn't your path (core essence never
## crystallizes), comes home whole and is lost on a fall; brewed by a Rune
## Artist or found in a vault. Raw essence makes tinctures at the bench; a
## full vessel of core essence powers a core rune (gear.gd CORE_RUNES), +4 or
## a deep rune; a Noble asks for full vessels for the city (contracts.gd
## ASK); a full vessel of core essence can be offered (a plea, the bribe).
## The outfitter no longer buys them. Old saves, the pace models, the
## Entity's words, hover help, a phone's screen and no banned words.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const V := preload("res://scripts/vessel.gd")
const VP := preload("res://scripts/vessel_page.gd")
const G := preload("res://scripts/gear.gd")
const B := preload("res://scripts/bench.gd")
const Flow := preload("res://scripts/essence_flow.gd")
const Contracts := preload("res://scripts/contracts.gd")
const Renown := preload("res://scripts/renown.gd")
const Stations := preload("res://scripts/stations.gd")
const Train := preload("res://scripts/train.gd")
const Entity := preload("res://scripts/entity.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const Help := preload("res://scripts/entity_help.gd")
const Model := preload("res://tests/progression_model.gd")
const Prog := preload("res://tests/parts/progression.gd")
const Cup := preload("res://tests/parts/unbound_cup.gd")

const TestRun := preload("res://scripts/test_run.gd")

const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

var t


func run(smoke) -> void:
	t = smoke
	print("vessels: raw and core essence, tinctures, the city's ask, core runes")
	await _core_catch()
	await _raw_catch()
	await _store_and_bench()
	await _tinctures()
	await _core_runes()
	await _offerings()
	await _contract()
	_old_saves()
	_pace()
	_words()
	t.paused = false


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _buttons(meta: String, val) -> Array:
	return t._all_buttons(t.main.menu).filter(func(b): return b.is_visible_in_tree() and b.has_meta(meta) and b.get_meta(meta) == val)


func _fresh() -> void:
	await t._fresh_main()
	t.paused = false
	var main = t.main
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.grant_test_bonds()
	for e in main.enemies():
		e.queue_free()
	await t._frames(1)


# --- core essence: caught from great foes, as ever --------------------------------------------

func _core_catch() -> void:
	await _fresh()
	var main = t.main
	var Items = main.Items
	var p = main.player
	var prof = main.profile
	_check(Items.ITEMS.has("vessel") and Items.max_stack("vessel") == 1 and not ("vessel" in Train.supplies()) and not ("vessel" in B.brews()) and Items.random_item(true, [], false) != "vessel",
		"the vessel is an item of its own: one at a time, never sold, brewed with the rest or dropped")
	prof.path = "life"
	var at: Vector2 = p.global_position + Vector2(120, 0)
	var m0: int = main.fx.motes_list.size()
	main.rise_secret("unmaking", 9.0, at)
	_check(main.fx.motes_list.slice(m0).any(func(m): return m.get("through", false)) and V.carried(p).is_empty(), "without a vessel, Unmaking passes through you")
	# An empty vessel given with a path catches core essence.
	_check(V.give(main, {}) and p.item_count("vessel") == 1 and V.carried(p)["amount"] == 0.0 and V.is_core(V.carried(p)), "a vessel goes on the belt, empty; with a path it catches core essence")
	m0 = main.fx.motes_list.size()
	var f0: float = main.run_flow
	main.rise_secret("unmaking", 12.0, at)
	_check(is_equal_approx(V.carried(p)["amount"], 12.0) and V.carried(p)["kind"] == "unmaking" and main.fx.motes_list.size() == m0 and is_equal_approx(main.run_flow, f0),
		"with one, the Unmaking is caught (12), none passes, the flow is untouched")
	main.rise_secret("life", 9.0, at)
	_check(is_equal_approx(main.run_flow, f0 + 9.0) and is_equal_approx(V.carried(p)["amount"], 12.0), "your path's Making still soaks into you, not the vessel")
	m0 = main.fx.motes_list.size()
	main.rise_secret("unmaking", 25.0, at)
	_check(V.full_on_belt(p) and is_equal_approx(V.carried(p)["amount"], V.CAPACITY) and main.fx.motes_list.slice(m0).any(func(m): return m.get("through", false)),
		"it fills to %d; the rest passes through" % int(V.CAPACITY))
	_check(Items.use("vessel", p) == false and p.item_count("vessel") == 1 and V.is_full(V.carried(p)), "using a filled one only says what it holds")
	var full_kind: String = V.carried(p)["kind"]
	prof.path = ""
	_check(is_equal_approx(V.capture(main, "life", 5.0, at), 5.0), "before a path is chosen it catches nothing")
	prof.path = "life"
	# A vessel catching raw essence lets core essence pass.
	var keep: Dictionary = p.vessel
	p.vessel = V.make("", 0.0, "raw")
	_check(is_equal_approx(V.capture(main, "unmaking", 6.0, at), 6.0) and V.fill(p.vessel) == 0.0, "a vessel set for raw essence lets core essence pass through")
	_check(Items.use("vessel", p) == false and V.is_core(p.vessel), "using an empty one from the belt switches it (raw to core)")
	Items.use("vessel", p)
	_check(V.is_raw(p.vessel), "...and back")
	p.vessel = keep
	for k in 3:
		p.add_item(["draught", "tonic", "smoke"][k])
	main.offer_belt_swap({"id": "flare", "pos": p.global_position, "t": 10.0})
	var swap_choices: Array = main.camp.get("choices", [])
	main._take_belt_pick("belt:")
	_check(not ("belt:vessel" in swap_choices) and swap_choices.size() >= 2, "a full belt's swap card never offers the vessel (what it holds would spill)")
	# Home on a survived climb or a recall, never broken into crystals; lost on a fall.
	prof.crystals = []
	prof.vessels = []
	main.belt_broken = false
	var broke: String = main.break_belt()
	_check(p.item_count("vessel") == 1 and broke != "" and prof.crystal_total("stone") > 0.0, "the belt breaks into crystals, the vessel aside")
	var home: String = V.bring_home(main)
	_check(prof.vessels.size() == 1 and V.is_full(prof.vessels[0]) and prof.vessels[0]["kind"] == full_kind and p.item_count("vessel") == 0 and home.contains("comes home"),
		"...it comes home to your stash, full (%s)" % home)
	V.give(main, V.make("fire", 7.0))
	main.belt_broken = false
	main.read_recall()
	_check(prof.vessels.size() == 2 and is_equal_approx(prof.vessels[1]["amount"], 7.0) and V.is_raw(prof.vessels[1]) and main.victory.get("lines", []).any(func(l): return String(l).contains("vessel")),
		"a recall scroll brings it home too, partly filled (raw Fire)")
	main.victory = {}
	p.set_physics_process(true)
	V.give(main, V.make("unmaking", 20.0))
	main.on_player_died()
	_check(p.item_count("vessel") == 0 and prof.vessels.size() == 2 and main.fall_note.any(func(l): return String(l).contains("vessel")), "a fall loses it with the belt, and says so")
	# Packed from the stash, it goes up on the belt.
	p.items = {}
	_check(V.pack(prof, p, 1) == "" and V.packed_index(prof) == 1, "a vessel in the stash can be packed for the next climb")
	_check(Train.supply_room(prof, p, "draught") > 0, "(it leaves room for the rest of the belt)")
	Train.pack_up(prof, p)
	_check(p.item_count("vessel") == 1 and is_equal_approx(V.carried(p)["amount"], 7.0) and V.is_raw(V.carried(p)) and prof.vessels.size() == 1, "...and departing puts it on your belt, still holding 7 raw Fire")
	p.items.erase("vessel")
	p.vessel = {}
	# Brewing: the materials and the Rune Artist's premium; a Rune Artist the materials alone.
	prof.vessels = []
	prof.crystals = []
	for k in V.BREW:
		prof.add_crystal(k, float(V.BREW[k]))
	_check(V.brew(prof) != "" and prof.vessels.is_empty() and int(V.brew_cost(prof)["iron"]) == int(V.BREW["iron"]) + ceili(float(V.BREW["iron"]) * float(B.PREMIUM["share"])), "without the mark, a vessel costs its materials and the Rune Artist's premium (%s)" % B.cost_text(V.brew_cost(prof)))
	prof.add_bond("brow", "rune_artist", false)
	_check(V.brew(prof) == "" and prof.vessels.size() == 1 and V.fill(prof.vessels[0]) == 0.0 and prof.crystal_total("iron") == 0.0 and V.is_core(prof.vessels[0]), "a Rune Artist brews one (%s), empty, catching core essence with a path" % B.cost_text(V.BREW))
	var total := 0
	for k in V.BREW:
		total += int(V.BREW[k])
	_check(total >= 120, "brewing a vessel stays a real cost (%d crystals of materials)" % total)
	# Very rarely, a vault offers one.
	V.vault_force = 1.0
	var cards: Array = main.wings.vault_choices(false)
	_check(cards.size() == 3 and cards[2] == "vessel", "a vault's third card can be a vessel")
	main.offer_vault(cards, "THE VAULT", [""])
	main._take_vault_pick("vessel")
	_check(p.item_count("vessel") == 1 and V.carried(p)["amount"] == 0.0, "...taken onto the belt, empty")
	_check(main.wings.vault_choices(false)[2] != "vessel", "...never while you carry one")
	p.items.erase("vessel")
	p.vessel = {}
	V.vault_force = 0.0
	_check(main.wings.vault_choices(false)[2] != "vessel", "(and only by chance)")
	V.vault_force = -1.0


# --- raw essence at the stairs ------------------------------------------------------------

func _raw_catch() -> void:
	# The rule itself (pure: the game and the pace model share it).
	var v := V.make("", 0.0, "raw")
	var ess := {"air": 50.0, "water": 4.0}
	var took := V.take_raw(v, ess)
	_check(is_equal_approx(took, minf(V.CAPACITY, 50.0 * float(V.RAW["share"]))) and v["kind"] == "air" and is_equal_approx(float(ess["air"]), 50.0 - took) and float(ess["water"]) == 4.0,
		"an empty raw vessel takes %d%% of the kind banked most (%d Air), out of what's banked" % [int(float(V.RAW["share"]) * 100.0), int(took)])
	ess = {"air": 50.0, "fire": 80.0}
	var t2 := V.take_raw(v, ess)
	_check(v["kind"] == "air" and V.is_full(v) and is_equal_approx(t2, V.CAPACITY - took) and float(ess["fire"]) == 80.0, "...then only its own kind, until full (it never mixes)")
	_check(V.take_raw(V.make("", 0.0, "core"), {"air": 50.0}) == 0.0, "a vessel set for core essence takes no raw essence")
	# The stair itself: its share isn't banked.
	await _fresh()
	var main = t.main
	var p = main.player
	var prof = main.profile
	V.give(main, V.make("", 0.0, "raw"))
	main.floor_num = 2
	main.run_essence = {"air": 50.0}
	main.run_soak = {"heart": 4.0}
	var air0: float = prof.crystal_total("air")
	var d0: float = float(prof.density.get("air", 0.0))
	main._arrive()
	await t._frames(2)
	var caught: float = float(V.carried(p).get("amount", 0.0))
	var want := minf(V.CAPACITY, 50.0 * float(V.RAW["share"]))
	var banked := 50.0 - want
	var sh: Dictionary = Flow.shares(Train.condense_share())
	var c := int(floorf(banked * float(sh["crystals"])))
	var m := int(round((banked - c) * float(sh["marks"]) / (float(sh["marks"]) + float(sh["body"]))))
	var line: String = Flow.TEXT["split"] % [int(round(banked)), int(round(banked)) - m - c, m, c]
	var lines: Array = main.banner.get("lines", [])
	_check(is_equal_approx(caught, want) and V.carried(p)["kind"] == "air", "at a stair, a raw vessel on the belt takes its share (%d of 50 Air)" % int(caught))
	_check(lines.has(line), "...and only the rest is banked: \"%s\" (%s)" % [line, lines])
	_check(lines.any(func(l): return String(l).contains("kept raw")), "...the stair says what went into the vessel")
	_check(prof.crystal_total("air") - air0 <= float(c) + banked and float(prof.density.get("air", 0.0)) - d0 <= banked + 0.01, "what the vessel took made no crystals and settled no density")
	p.items.erase("vessel")
	p.vessel = {}


# --- the store and the bench's Vessel counter --------------------------------------------

func _store_and_bench() -> void:
	await _fresh()
	var main = t.main
	var prof = main.profile
	var menu = main.menu
	prof.vessels = [V.make("unmaking", V.CAPACITY), V.make("fire", 10.0)]
	prof.crystals = []
	main.await_tower()
	main.open_train()
	menu.train_car = "store"
	menu.train_store = "sell"
	menu.inv_sel = "vessel:0"
	menu.open("train")
	await t._frames(2)
	var words: Array = t._all_labels(menu).map(func(l): return l.text)
	_check(words.has(String(V.TEXT["no_trade"])) and t._all_buttons(menu).filter(func(b): return b.has_meta("vessel_trade")).is_empty() and prof.vessels.size() == 2,
		"the store lists vessels but doesn't buy them: the cities do (no trade, no crystals)")
	_check(not FileAccess.get_file_as_string("res://scripts/vessel.gd").contains("static var TRADE"), "(the old 120-crystal trade is gone)")
	# The stash card: an empty one switches what it catches.
	prof.vessels.append(V.make("", 0.0, "core"))
	menu.train_car = "personal"
	menu.inv_sel = "vessel:2"
	menu.open("train")
	await t._frames(2)
	var sw: Array = _buttons("help", "vessel_catch")
	_check(sw.size() == 1, "an empty vessel's card offers to switch what it catches")
	if sw.size() == 1:
		sw[0].pressed.emit()
		await t._frames(2)
	_check(V.is_raw(prof.vessels[2]), "...pressed, it catches raw essence")
	menu.inv_sel = "vessel:0"
	menu.open("train")
	await t._frames(2)
	_check(_buttons("help", "vessel_catch").is_empty(), "a filled vessel can't switch (empty it first)")
	# The bench: +4 and a deep rune from a full vessel of core essence (the vessel stays, empty).
	prof.heirlooms["melee"] = G.make("spear", "fine", ["edges"], 3)
	prof.vessels = [V.make("unmaking", V.CAPACITY)]
	prof.add_bond("brow", "rune_artist", false)
	var strike3: float = G.effects(prof.heirlooms["melee"])["strike"]
	menu.train_car = "workshop"
	menu.train_bench = "vessel"
	menu.inv_sel = "bench:heir:melee"
	menu.open("train")
	await t._frames(2)
	var dt: Array = _buttons("bench_do", "vtemper")
	_check(dt.size() == 1 and not dt[0].disabled, "the Vessel counter offers to temper a +3 piece past the limit")
	if dt.size() == 1:
		dt[0].pressed.emit()
		await t._frames(2)
		await t._confirm(true)
		await t._frames(1)
	var spear: Dictionary = prof.heirlooms["melee"]
	_check(int(spear["rank"]) == G.RANK_CAP and prof.vessels.size() == 1 and V.fill(prof.vessels[0]) == 0.0 and is_equal_approx(G.effects(spear)["strike"], strike3 * (1.0 + G.RANK_TRAIT * 4) / (1.0 + G.RANK_TRAIT * 3)),
		"...to +%d, using the core essence: the vessel stays, empty" % G.RANK_CAP)
	_check(V.deep_rune(prof, "heir:melee", "sharpness") != "" and not spear.has("rune"), "a deep rune needs a full vessel of core essence")
	prof.vessels = [V.make("air", V.CAPACITY)]
	_check(V.deep_rune(prof, "heir:melee", "sharpness") != "", "...a full vessel of raw essence won't do")
	prof.vessels = [V.make("life", V.CAPACITY)]
	var strike4: float = G.effects(prof.heirlooms["melee"])["strike"]
	_check(V.deep_rune(prof, "heir:melee", "sharpness") == "" and prof.heirlooms["melee"]["rune"] == "deep_sharpness" and V.fill(prof.vessels[0]) == 0.0
		and is_equal_approx(G.effects(prof.heirlooms["melee"])["strike"], strike4 + 0.2), "...with one, a deep rune at the spell's full strength (+20% strikes)")
	_check(B.inscribe(prof, "heir:melee", "deep_warding") != "", "the bench's own Inscribe can't cut a deep rune")
	main.on_train = false
	menu.close()
	t.paused = false
	await t._frames(1)


# --- tinctures from raw essence ------------------------------------------------------------

func _tinctures() -> void:
	await _fresh()
	var main = t.main
	var prof = main.profile
	var p = main.player
	var menu = main.menu
	var per := int(V.RAW["per_tincture"])
	prof.vessels = [V.make("fire", V.CAPACITY), V.make("air", 8.0)]
	prof.supplies = {}
	p.items = {}
	_check(V.tinctures_in(prof, "fire") == int(V.CAPACITY) / per and V.tinctures_in(prof, "air") == 0, "a full vessel of raw Fire makes %d tinctures (%d raw each); 8 Air makes none" % [int(V.CAPACITY) / per, per])
	_check(per < int(Flow.TINCTURE["craft"]), "...cheaper than from crystals (%d raw against %d crystals): worth more than the same essence banked (%d crystals of it)" % [per, int(Flow.TINCTURE["craft"]), int(floorf(per * Train.condense_share()))])
	main.open_train()
	menu.train_car = "workshop"
	menu.train_bench = "tincture"
	menu.inv_sel = "bench:tincture:tincture_fire"
	menu.open("train")
	await t._frames(2)
	var rb: Array = _buttons("help", "vessel_tincture")
	_check(rb.size() == 1 and not rb[0].disabled, "the Tinctures counter offers to make one from raw essence")
	if rb.size() == 1:
		rb[0].pressed.emit()
		await t._frames(2)
	_check(int(prof.supplies.get("tincture_fire", 0)) == 1 and is_equal_approx(float(prof.vessels[0]["amount"]), V.CAPACITY - per) and prof.vessels.size() == 2, "...made: a Fire tincture packed, %d raw Fire gone from the vessel" % per)
	_check(V.make_tincture(prof, p, "tincture_fire") == "" and int(prof.supplies.get("tincture_fire", 0)) == 2 and V.fill(prof.vessels[0]) == 0.0 and V.is_raw(prof.vessels[0]) and prof.vessels.size() == 2,
		"a second empties it: the vessel stays in your stash, still catching raw essence")
	_check(V.make_tincture(prof, p, "tincture_fire") != "" and V.make_tincture(prof, p, "tincture_air") != "", "with too little raw essence of the kind, none is made")
	var c0: float = prof.crystal_total("fire")
	Train.put_back(prof, "tincture_fire")
	_check(prof.crystal_total("fire") == c0 and int(prof.supplies.get("tincture_fire", 0)) == 1, "putting one back returns no crystals (raw essence can't be turned into crystals that way)")
	_check(Flow.tincture_kind("tincture_fire") == "fire" and main.drink_tincture("tincture_fire", "hand").size() > 0, "it's an ordinary tincture: drunk where you choose")
	main.on_train = false
	menu.close()
	t.paused = false
	await t._frames(1)


# --- core runes ------------------------------------------------------------------------------

func _core_runes() -> void:
	await _fresh()
	var main = t.main
	var prof = main.profile
	var p = main.player
	var menu = main.menu
	_check(G.CORE_RUNES.size() % 6 == 0 and V.core_runes("life").size() == 3 and V.core_runes("unmaking").size() == 3, "six core runes: three of Making, three of Unmaking (by sixes)")
	prof.heirlooms["melee"] = G.make("spear", "fine", ["edges"], 1)
	prof.vessels = [V.make("unmaking", V.CAPACITY), V.make("life", 12.0)]
	_check(V.core_rune_why(prof, "heir:melee", "mending") != "", "a core rune of Making needs a full vessel of Making (12 isn't full)")
	prof.crystals = []
	_check(V.core_rune_why(prof, "heir:melee", "breaking") != "" and not V.work_fee(prof, "heir:melee").is_empty(), "without the mark, the Rune Artist's small fee for the work (%s)" % B.cost_text(V.work_fee(prof, "heir:melee")))
	for k in V.work_fee(prof, "heir:melee"):
		prof.add_crystal(k, float(V.work_fee(prof, "heir:melee")[k]))
	main.open_train()
	menu.train_car = "workshop"
	menu.train_bench = "vessel"
	menu.inv_sel = "bench:heir:melee"
	menu.open("train")
	await t._frames(2)
	var br: Array = _buttons("bench_do", "vcore:breaking")
	_check(br.size() == 1 and not br[0].disabled and Help.key_for(br[0]) == "core_rune", "the Vessel counter offers Unmaking's core runes from a full vessel of it (with hover help)")
	_check(_buttons("bench_do", "vcore:mending").size() == 1 and _buttons("bench_do", "vcore:mending")[0].disabled, "...Making's are there but off without a full vessel of Making")
	# The counter's card fits an 800x400 phone (scrolled to its buttons).
	var was: Vector2i = t.root.size
	t.root.size = Vector2i(800, 400)
	main.touch._set_active(true)
	main.apply_view_scale()
	menu.open("train")
	await t._frames(4)
	menu.train_page.reveal_card()
	await t._frames(2)
	var view: Rect2 = t.root.get_visible_rect()
	var bad: Array = []
	var cbs: Array = t._all_buttons(menu).filter(func(b): return b.is_visible_in_tree() and String(b.get_meta("bench_do", "")).begins_with("v"))
	for b in cbs:
		var r: Rect2 = b.get_global_rect()
		if b.size.y < 34.0 or r.position.x < view.position.x - 1.0 or r.end.x > view.end.x + 1.0:
			bad.append("%s %s" % [b.text, r])
	_check(bad.is_empty() and cbs.size() >= 10, "the Vessel counter's card fits an 800x400 phone: %d buttons, each big enough to touch and on screen across (%s)" % [cbs.size(), bad])
	main.touch._set_active(false)
	t.root.size = was
	main.apply_view_scale()
	menu.open("train")
	await t._frames(2)
	br = _buttons("bench_do", "vcore:breaking")  # (the page was built again: fresh buttons)
	if br.size() == 1 and is_instance_valid(br[0]):
		br[0].pressed.emit()
		await t._frames(2)
		_check(menu.asking(), "a press asks first (the confirmation pop-up)")
		await t._confirm(true)
		await t._frames(1)
	var spear: Dictionary = prof.heirlooms["melee"]
	_check(String(spear.get("core", {}).get("id", "")) == "breaking" and int(spear["core"]["left"]) == int(V.CORE["floors"]) and V.fill(prof.vessels[0]) == 0.0 and prof.vessels.size() == 2,
		"worked in: the Core Rune of Breaking for %d floors; the vessel stays, empty" % int(V.CORE["floors"]))
	_check(G.rec(spear).has("core") and G.same(G.rec(spear), spear) and G.trait_lines(spear).any(func(l): return String(l[0]).contains("Breaking") and String(l[0]).contains(str(int(V.CORE["floors"])))), "it's kept on the piece's record (copied, saved) and its card says it, with its floors left")
	main.on_train = false
	menu.close()
	t.paused = false
	await t._frames(1)
	# Worn, it works: blows go through guards; Mending closes wounds.
	prof.wear = {}
	Train.dress(prof, p)
	p.refresh_gear()
	_check(p.gfx("guardbreak") > 0.0, "worn, the Core Rune of Breaking sends blows through shells and guards")
	p.gear["helm"] = G.make("leather_cap")
	p.gear["helm"]["core"] = {"id": "mending", "left": 2}
	p.refresh_gear()
	p.hp = 10.0
	var hp0: float = p.hp
	p._tick_timers(0.5)
	_check(p.gfx("mend") >= 0.39 and p.hp > hp0 + 0.15, "the Core Rune of Mending closes wounds (%.1f to %.1f in half a second)" % [hp0, p.hp])
	# Each stair counts a floor down; at zero it fades (an heirloom's own record follows).
	var lines: Array = V.wear_core_runes(main)
	_check(int(p.gear["melee"]["core"]["left"]) == int(V.CORE["floors"]) - 1 and int(prof.heirlooms["melee"]["core"]["left"]) == int(V.CORE["floors"]) - 1, "a stair counts it down, on the heirloom too (%d left)" % int(p.gear["melee"]["core"]["left"]))
	lines = V.wear_core_runes(main)
	_check(not p.gear["helm"].has("core") and lines.any(func(l): return String(l).contains("fades")) and p.gfx("mend") == 0.0, "a core rune at its last floor fades, and says so")
	for i in int(V.CORE["floors"]):
		V.wear_core_runes(main)
	_check(not p.gear["melee"].has("core") and not prof.heirlooms["melee"].has("core") and p.gfx("guardbreak") == 0.0, "...and the Breaking rune runs out too: gone from the heirloom")


# --- offerings: a full vessel of core essence ----------------------------------------------

func _offerings() -> void:
	await _fresh()
	var main = t.main
	var prof = main.profile
	var p = main.player
	var mk = main.makers
	var SB = main.SecretBonds
	prof.path = "life"
	_check(not mk.answers().any(func(o): return o["id"] == "plea_vessel"), "no vessel, no offering card")
	V.give(main, V.make("fire", V.CAPACITY))
	_check(not mk.answers().any(func(o): return o["id"] == "plea_vessel"), "a full vessel of raw essence isn't an offering a Maker takes")
	V.take(p)
	V.give(main, V.make("unmaking", V.CAPACITY))
	var ids: Array = mk.answers().map(func(o): return o["id"])
	_check("plea" in ids and "plea_vessel" in ids, "carrying a full vessel of core essence, a meeting offers it with a plea")
	_check(mk.plea_odds("marks", true) > mk.plea_odds("marks", false), "...likelier to be granted")
	mk.plea_force = 0
	var res: Dictionary = mk.answer("marks", "plea_vessel")
	_check(p.item_count("vessel") == 0 and prof.path == "life" and mk.TEXT["vessel_taken"] in res["lines"], "refused, it still keeps the vessel")
	V.give(main, V.make("unmaking", V.CAPACITY))
	mk.plea_force = 1
	res = mk.answer("marks", "plea_vessel")
	_check(p.item_count("vessel") == 0 and prof.path == "" and res["good"], "granted: the path is cleared and the vessel is gone")
	mk.plea_force = -1
	SB.grant(prof, "developer", 2)
	prof.vessels = [V.make("life", 12.0), V.make("unmaking", V.CAPACITY), V.make("air", V.CAPACITY)]
	var offers: Array = SB.bribe_offers(prof, G)
	_check(offers.any(func(o): return o["id"] == "vessel:1" and o["ok"]) and not offers.any(func(o): return o["id"] == "vessel:0" or o["id"] == "vessel:2"), "the bribe offers a full vessel of core essence (not a partly filled one, nor raw essence)")
	SB.bribe_force = 1
	res = SB.offer_bribe(prof, "vessel:1", G)
	_check(res["ok"] and prof.vessels.size() == 2 and int(SB.bribe_state(prof).get("for", 0)) == 3, "...accepted, the vessel is gone")
	SB.bribe_force = -1
	SB.clear(prof)


# --- the city's ask --------------------------------------------------------------------------

func _contract() -> void:
	await _fresh()
	var main = t.main
	var prof = main.profile
	var menu = main.menu
	prof.path = "life"
	var a: Dictionary = Contracts.roll_ask(prof, false)
	_check(not a.is_empty() and V.is_raw_kind(String(a["want"])) and int(a["renown"]) == int(Contracts.ASK["renown"]), "the city can ask for a vessel of raw essence (%s)" % Contracts.ask_name(a))
	var ac: Dictionary = Contracts.roll_ask(prof, true)
	_check(String(ac["want"]) == "unmaking" and int(ac["renown"]) > int(a["renown"]), "...or, with a path, the core essence that isn't it, for more renown")
	var old := float(Contracts.ASK["chance"])
	Contracts.ASK["chance"] = 1.0
	Contracts.data(prof)["ask"] = {}
	Contracts.data(prof)["visit"] = -5
	Contracts.offers(prof)
	_check(not Contracts.ask(prof).is_empty(), "now and then a station visit brings an ask")
	Contracts.ASK["chance"] = old
	Contracts.data(prof)["ask"] = a
	prof.vessels = []
	prof.chest = []
	_check(Contracts.deliver_why(prof) != "" and Contracts.deliver(prof).is_empty(), "with no full vessel of it in your stash, it can't be delivered")
	prof.vessels = [V.make(String(a["want"]), V.CAPACITY)]
	var pts0: int = Renown.points(prof)
	var done0: int = int(Contracts.data(prof)["done"])
	var crystals0: float = prof.crystals_held()
	# At the Noble: its tile, its card, Deliver (asks first).
	main.open_train()
	await t._frames(1)
	menu.go_station(String(Stations.STATIONS[0]["id"]), "noble")
	await t._frames(3)
	var tile: Array = _buttons("pick", "ask:vessel")
	_check(tile.size() == 1, "the Noble's stop shows the city's ask")
	if tile.size() == 1:
		tile[0].pressed.emit()
		await t._frames(2)
	var dl: Array = _buttons("station_do", "deliver")
	_check(dl.size() == 1 and not dl[0].disabled and Help.key_for(dl[0]) == "station_do:deliver" and Help.HELP.has("station_do:deliver"), "its card offers Deliver (with hover help)")
	_check(not _buttons("station_do", "decline").is_empty() and Help.HELP.has("station_do:decline") and Help.HELP.has("pick:ask"), "...and Decline")
	# Fits a phone.
	var was: Vector2i = t.root.size
	t.root.size = Vector2i(800, 400)
	main.touch._set_active(true)
	main.apply_view_scale()
	menu.go_station(String(Stations.STATIONS[0]["id"]), "noble", "ask:vessel")
	await t._frames(4)
	var view: Rect2 = t.root.get_visible_rect()
	var bad: Array = []
	for b in _buttons("station_do", "deliver") + _buttons("station_do", "decline"):
		var r: Rect2 = b.get_global_rect()
		if b.size.y < 34.0 or r.position.x < view.position.x - 1.0 or r.end.x > view.end.x + 1.0:
			bad.append("%s %s" % [b.text, r])
	_check(bad.is_empty() and not _buttons("station_do", "deliver").is_empty(), "the ask's card fits an 800x400 phone, its buttons big enough to touch (%s)" % [bad])
	main.touch._set_active(false)
	t.root.size = was
	main.apply_view_scale()
	menu.go_station(String(Stations.STATIONS[0]["id"]), "noble", "ask:vessel")
	await t._frames(3)
	dl = _buttons("station_do", "deliver")
	if dl.size() == 1:
		dl[0].pressed.emit()
		await t._frames(2)
		_check(menu.asking(), "Deliver asks first (the confirmation pop-up)")
		await t._confirm(true)
		await t._frames(2)
	_check(prof.vessels.is_empty() and Contracts.ask(prof).is_empty() and int(Contracts.data(prof)["done"]) == done0 + 1, "delivered: the vessel is the city's, and it counts as a contract done")
	var gained: int = Renown.points(prof) - pts0
	_check(gained >= int(a["renown"]) and prof.chest.size() == 1 and G.rarity(prof.chest[0]) != "common", "it pays renown (+%d) and a piece from the city's stores (%s)" % [gained, G.display(prof.chest[0]) if not prof.chest.is_empty() else "none"])
	_check(prof.crystals_held() == crystals0, "...never crystals (slow growth)")
	# Declining.
	Contracts.data(prof)["ask"] = Contracts.roll_ask(prof, false)
	Contracts.decline(prof)
	_check(Contracts.ask(prof).is_empty(), "declined, the ask is gone (another may come later)")
	menu.close()
	main.on_train = false
	t.paused = false
	await t._frames(1)


# --- old saves -------------------------------------------------------------------------------

func _old_saves() -> void:
	var old_full := V.norm({"kind": "unmaking", "amount": 30.0, "packed": true})
	_check(V.is_core(old_full) and V.full_core(old_full) and bool(old_full.get("packed", false)), "an old save's full vessel (no \"catch\") is a full vessel of core essence, still packed")
	var old_empty := V.norm({"kind": "", "amount": 0.0})
	_check(V.is_core(old_empty) and V.fill(old_empty) == 0.0, "an old save's empty vessel catches core essence, as it did")
	var raw := V.norm({"kind": "stone", "amount": 12.0, "catch": "core"})
	_check(V.is_raw(raw) and raw["kind"] == "stone", "a vessel holding raw essence catches raw essence whatever its save says")
	_check(V.norm("junk").get("amount", -1.0) == 0.0 and V.load_list([{"kind": "life", "amount": 5.0}, 3]).size() == 1, "broken entries read as empty or are skipped")
	_check(V.decode(V.code(V.make("fire", 7.0))) == V.make("fire", 7.0) and V.decode("life:30") == V.make("life", 30.0), "a slot's code reads back (old two-part codes too)")
	var g := G.rec({"base": "spear", "rarity": "fine", "traits": ["edges"], "rank": 1, "core": {"id": "rending", "left": 5}})
	_check(String(g.get("core", {}).get("id", "")) == "rending" and G.rec({"base": "spear", "core": {"id": "nope", "left": 5}}).get("core") == null and G.rec({"base": "spear"}).get("core") == null,
		"a piece's core rune is kept on its record; an unknown one, or none (old saves), reads as none")
	# Saved with the stash, and an old save with none.
	var path := TestRun.path("user://smoke_vessel_test.cfg")
	var prof = load("res://scripts/profile.gd").new()
	prof.vessels = [V.make("life", V.CAPACITY), {"kind": "unmaking", "amount": 4.5, "packed": true}, {"kind": "nonsense", "amount": 9}, V.make("", 0.0, "raw"), V.make("water", 11.0)]
	prof.chest = [g]
	prof.save_path = path
	prof.saving = true
	prof.save()
	prof.saving = false
	var again = load("res://scripts/profile.gd").new()
	again.save_path = path
	again.load_save()
	_check(again.vessels.size() == 5 and V.full_core(again.vessels[0]) and again.vessels[0]["kind"] == "life" and is_equal_approx(again.vessels[1]["amount"], 4.5)
		and again.vessels[1].get("packed", false) and again.vessels[2]["kind"] == "" and again.vessels[2]["amount"] == 0.0 and V.is_raw(again.vessels[3]) and V.is_raw(again.vessels[4]) and is_equal_approx(again.vessels[4]["amount"], 11.0),
		"vessels are saved and load again, raw or core (a broken one reads as empty)")
	_check(not again.chest.is_empty() and String(G.rec(again.chest[0]).get("core", {}).get("id", "")) == "rending", "a piece's core rune is saved with it")
	var old := ConfigFile.new()
	old.set_value("profile", "regarded", true)
	old.save(path)
	again = load("res://scripts/profile.gd").new()
	again.save_path = path
	again.load_save()
	_check(again.vessels.is_empty(), "an old save loads with no vessels")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


# --- the pace -------------------------------------------------------------------------------

## A climber who keeps a raw vessel going (brewing a new one with their own
## crystals after each fall, as the game asks) and drinks every tincture it
## makes into their first mark, or their Unbound Node, stays in the bands
## and gains at most a climb or two. The free "always" case (a vessel every
## climb for nothing) is printed for reference.
func _pace() -> void:
	var base: Dictionary = Model.climbs_to_steps(Model.run("typical", 50)["steps"])
	var brewed: Dictionary = Model.run("typical", 50, false, Model.BOUGHT_TINCTURES, 1.0, "", "brewed")
	var bs: Dictionary = Model.climbs_to_steps(brewed["steps"])
	var bad: Array = []
	for st in Prog.TYPICAL:
		var c := int(bs[st])
		if c < int(Prog.TYPICAL[st][0]) or c > int(Prog.TYPICAL[st][1]) or c < int(base[st]) - 2:
			bad.append("step %d after %d (%d without)" % [st, c, int(base[st])])
	_check(bad.is_empty() and int(brewed["tinctures"]) > 0, "a typical climber keeping a raw vessel going (%d tinctures in 50 climbs) stays in the mark's bands (%s)" % [int(brewed["tinctures"]), bad])
	_check(int(brewed["second"]) >= int(Prog.SECOND[0]), "...and their second mark comes no sooner than %d climbs (%d)" % [int(Prog.SECOND[0]), int(brewed["second"])])
	var fast: Dictionary = Model.climbs_to_steps(Model.run("summits", 50)["steps"])
	var fb: Dictionary = Model.run("summits", 50, false, Model.BOUGHT_TINCTURES, 1.0, "", "brewed")
	var fs: Dictionary = Model.climbs_to_steps(fb["steps"])
	bad = []
	for st in Prog.SUMMITS:
		var c := int(fs[st])
		if c < int(Prog.SUMMITS[st][0]) or c > int(Prog.SUMMITS[st][1]) or c < int(fast[st]) - 1:
			bad.append("step %d after %d (%d without)" % [st, c, int(fast[st])])
	_check(bad.is_empty(), "summiting every climb with a vessel (%d tinctures), the mark stays in its bands, a climb ahead at most (%s)" % [int(fb["tinctures"]), bad])
	var always: Dictionary = Model.climbs_to_steps(Model.run("typical", 50, false, Model.BOUGHT_TINCTURES, 1.0, "", "always")["steps"])
	print("  (for reference: a free vessel every climb, step 12 after %d climbs; %d without)" % [int(always[12]), int(base[12])])
	var ub: Dictionary = Model.run_unbound("typical", 45)
	var ubv: Dictionary = Model.run_unbound("typical", 45, "typical", "natural", [], true, "", "brewed")
	var top := int(ubv["top"]["legs"])
	_check(top >= int(Cup.MAIN_TOP[0]) and top >= int(ub["top"]["legs"]) - 1, "an Unbound with a raw vessel doesn't race ahead: the main Node at level 12 after %d climbs (%d without; no sooner than %d)" % [top, int(ub["top"]["legs"]), int(Cup.MAIN_TOP[0])])
	var ubf: Dictionary = Model.run_unbound("summits", 30, "typical", "natural", [], true, "", "brewed")
	var ft := int(ubf["top"]["legs"])
	_check(ft >= int(Cup.MAIN_TOP_SUMMITS[0]), "...summiting every climb, after %d (no sooner than %d)" % [ft, int(Cup.MAIN_TOP_SUMMITS[0])])


# --- words ------------------------------------------------------------------------------------

func _words() -> void:
	var ids := ["vessel", "vessel_capture", "vessel_raw", "vessel_full", "vessel_tincture", "vessel_contract", "core_rune"]
	_check(ids.all(func(id): return Entity.TIPS.has(id) and String(Entity.TIPS[id]["tip"]) != "" and String(Entity.TIPS[id]["more"]) != ""), "the Entity has first-time words for the vessel, raw essence kept raw, a tincture from it, the city's ask and a core rune")
	var lore: String = String(Entity.TIPS["vessel"]["tip"]) + String(Entity.TIPS["vessel"]["more"])
	_check(lore.contains("crystallizes") and lore.contains("raw") and lore.contains("never crystallizes"), "...it says essence crystallizes as it leaves the tower, a vessel keeps it raw, and core essence never crystallizes")
	var tinct: String = String(Entity.TIPS["vessel_tincture"]["tip"]) + String(Entity.TIPS["vessel_tincture"]["more"])
	_check(tinct.contains(str(int(V.RAW["per_tincture"])) + " raw") and tinct.contains(str(int(Flow.TINCTURE["craft"]))), "...its numbers match the tables (%d raw, %d crystals)" % [int(V.RAW["per_tincture"]), int(Flow.TINCTURE["craft"])])
	_check(String(Entity.TIPS["core_rune"]["tip"]).contains(str(int(V.CORE["floors"]))) and String(Entity.TIPS["vessel_raw"]["more"]).contains("half") == is_equal_approx(float(V.RAW["share"]), 0.5), "...and the core rune's floors and the share a vessel takes")
	var how: Array = Talk.DIALOGUE["how"]["choices"]
	_check(how.has("how_vessel") and String(Talk.DIALOGUE["how_vessel"]["ask"]) == "What's a vessel for?" and (Talk.DIALOGUE["how_tinctures"]["choices"] as Array).has("how_vessel") and (Talk.DIALOGUE["how_contracts"]["choices"] as Array).has("how_vessel"),
		"'How does it work?' has 'What's a vessel for?' (from tinctures and contracts too)")
	var said: String = Talk.fill(String(Talk.DIALOGUE["how_vessel"]["lines"][0]), Talk._fact_rules())
	_check(not said.contains("{") and said.contains(str(int(V.RAW["per_tincture"]))) and said.contains(str(int(V.CORE["floors"]))), "...its blanks all filled from the tables (%s)" % said.left(100))
	for k in ["vessel_catch", "vessel_tincture", "core_rune", "station_do:deliver", "station_do:decline", "pick:ask", "vessel_pack", "vessel_brew"]:
		_check(Help.HELP.has(k) and String(Help.HELP[k]) != "", "hover help: %s" % k)
	var texts: Array = [str(V.TEXT), str(Contracts.ASK_TEXT), str(G.CORE_RUNES), str(Talk.DIALOGUE["how_vessel"]), str(VP.V)]
	for id in ids:
		texts.append(str(Entity.TIPS[id]))
	for k in ["vessel_catch", "vessel_tincture", "core_rune", "station_do:deliver", "station_do:decline"]:
		texts.append(String(Help.HELP[k]))
	var all := " ".join(texts).to_lower()
	var found: Array = BANNED.filter(func(w): return all.contains(w))
	_check(found.is_empty(), "no banned words in the vessel's words (%s)" % [found])
	_check(not all.contains("120 crystal"), "the old 120-crystal trade is gone from the words")
