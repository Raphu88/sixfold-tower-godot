extends RefCounted
## The basic sword and bow (basic_gift.gd): never for sale (no rail or
## climber offers them, nobody buys them, the bench won't break them down);
## nothing restores them by itself (the train's dressing, setting off, a
## survived climb); a fall that leaves the climber without a melee or ranged
## weapon gives them, once (a copy in the stash goes on instead, so they
## never pile up), and the outfitter's words show on the fall screen and in
## your car, with the Entity's first-time tip; a climb abandoned mid-way
## counts as a fall; a new climber (and Start over) starts as before; old
## saves are handed them once; no banned words. Run by smoke_test.gd (_part_tests).

const Gift := preload("res://scripts/basic_gift.gd")
const Gear := preload("res://scripts/gear.gd")
const Train := preload("res://scripts/train.gd")
const Bench := preload("res://scripts/bench.gd")
const Lost := preload("res://scripts/lost.gd")
const NewStart := preload("res://scripts/new_start.gd")
const Entity := preload("res://scripts/entity.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const Guide := preload("res://scripts/guide.gd")
const OutfitterName := preload("res://scripts/outfitter_name.gd")
const Dining := preload("res://scripts/dining.gd")
const Rivals := preload("res://scripts/rivals.gd")
const TestRun := preload("res://scripts/test_run.gd")

const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

var t


func run(smoke) -> void:
	t = smoke
	print("the basic sword and bow: never for sale, never restored, gifted after a fall")
	await t._fresh_main()
	var main = t.main
	main.touch._set_active(false)
	main.pad._set_active(false)
	for e in main.enemies():
		e.queue_free()
	_never_for_sale(main)
	_no_restore(main)
	_gift_on_fall(main)
	await _gift_shown(main)
	_new_climber()
	_old_save()
	_words(main)
	if is_instance_valid(main) and is_instance_valid(main.menu) and main.menu.is_open():
		main.menu.close()
	t.paused = false
	if is_instance_valid(main):
		main.on_train = false
	await t._frames(2)


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## A climber on the train with nothing kept: no heirlooms, nothing worn, empty pack and stash.
func _bare(main) -> void:
	var prof = main.profile
	prof.regarded = true
	main.first_climb = false
	prof.heirlooms = {}
	prof.wear = {}
	prof.pack = []
	prof.chest = []
	prof.gift = {}
	main.fall_note = []
	main.gift_line = ""


## How many basic copies of a slot's piece the climber holds (worn, pack, stash, heirlooms).
func _copies(prof, slot: String) -> int:
	var n := 0
	for g in prof.wear.values() + prof.pack + prof.chest + Gear.heirloom_pieces(prof.heirlooms, slot):
		if Gear.is_gear(g) and Gear.same(g, Gift.piece(slot)):
			n += 1
	return n


func _never_for_sale(main) -> void:
	var prof = main.profile
	_check(Gift.is_basic(Gear.make("sword")) and Gift.is_basic(Gear.make("shortbow")) and not Gift.is_basic(Gear.make("sword", "fine", ["edges"])) and not Gift.is_basic(Gear.make("dagger")),
		"the basic pieces are the plain Common sword and shortbow (a Fine sword is another piece)")
	_check(not Train.common_pool(prof).any(func(id): return Gift.is_basic_base(String(id))) and not Train.common_pool(null).any(func(id): return Gift.is_basic_base(String(id))),
		"the outfitter's pool of Common pieces holds no sword or shortbow")
	var seen := false
	for i in 40:
		for g in Train.roll_outfit(prof if i % 2 == 0 else null):
			seen = seen or Gift.is_basic(g)
		seen = seen or Gift.is_basic(Train.roll_today(prof))
	prof.store = {}
	Train.stock(prof)
	for g in Train.outfit(prof) + [Train.today(prof)]:
		seen = seen or Gift.is_basic(g)
	_check(not seen, "the basic sword and bow never hang on his rail, in his case or in the store's stock (40 visits)")
	# A Dining-car climber neither sells one nor buys yours.
	var maker = Rivals.new()
	var rec: Dictionary = maker.new_rival(4, "kraken")
	maker.free()
	rec["gear"] = [Gear.code(Gift.piece("melee")), Gear.code(Gift.piece("ranged"))]
	prof.chest = [Gift.piece("melee")]
	var offers: Array = Dining.trade_offers(prof, rec)
	_check(not offers.any(func(o): return String(o["thing"].get("type", "")) == "gear" and Gift.is_basic(o["thing"]["rec"])),
		"a Dining-car climber offers no basic sword or bow, and won't buy yours (%d offers)" % offers.size())
	# Selling: nothing for it, and it stays.
	var stone: float = prof.crystal_total("iron") + prof.crystal_total("blade")
	_check(not Train.can_sell(Gift.piece("melee")) and Train.gear_sell(Gift.piece("melee"), prof) == 0 and Train.gear_sell(Gift.piece("ranged")) == 0,
		"the basic sword and bow can't be sold: they're worth nothing to a buyer")
	_check(Train.sell(prof, "chest", 0) == "" and prof.chest.size() == 1, "Sell does nothing for the basic sword: it stays in your stash")
	_check(Bench.break_down(prof, "chest:0") == "" and prof.chest.size() == 1 and is_equal_approx(prof.crystal_total("iron") + prof.crystal_total("blade"), stone),
		"...nor does the bench break it into crystals")
	prof.chest = []


func _no_restore(main) -> void:
	var prof = main.profile
	var p = main.player
	_bare(main)
	var g: Dictionary = Train.dressed(prof)
	_check(not Gear.is_gear(g.get("melee", {})) and not Gear.is_gear(g.get("ranged", {})), "nothing worn and no heirloom: the train dresses you with no sword or bow (nothing restores them)")
	Train.dress(prof, p)
	_check(p.gear_id("melee") == "" and p.gear_id("ranged") == "" and p.weapon == "fists", "...the climber on the train has fists, no basic pieces conjured")
	_check(not Train.setoff(prof).has("melee") and not Train.setoff(prof).has("ranged"), "...and the Loadout shows those slots empty")
	p.items = main.Items.START.duplicate()
	Train.pack_up(prof, p)
	_check(p.gear_id("melee") == "" and p.gear_id("ranged") == "" and bool(prof.gift.get("out", false)), "setting off with nothing: still nothing (and what you wear is out on the climb)")
	# Out alive with an axe: the axe comes home; no bow appears.
	p.take_gear(Gear.make("axe"), "melee")
	main.bring_worn_home()
	_check(not prof.gift.has("out") and Gear.base_id(prof.wear.get("melee", {})) == "axe" and not prof.wear.has("ranged"), "out alive: the axe comes home on you, and no bow appears")
	_check(not Gift.on_arrival(prof) and not prof.wear.has("ranged"), "...and the next climb's start gives nothing (that was no fall)")
	p.gear = Gear.start_gear()
	p.refresh_gear()


func _gift_on_fall(main) -> void:
	var prof = main.profile
	# Nothing at all: both are given.
	_bare(main)
	main.climb_paid = true  # (no pay: this part is about the gift)
	main.on_player_died()
	_check(Gift.is_basic(prof.wear.get("melee", {})) and Gift.is_basic(prof.wear.get("ranged", {})), "a fall with no weapon kept: the basic sword and bow are given, worn on the train")
	_check(_copies(prof, "melee") == 1 and _copies(prof, "ranged") == 1, "...one of each")
	var fall_line: String = String(Gift.TEXT["fall"]).get_slice("%s", 0)
	_check(main.fall_note.any(func(l): return String(l).begins_with(fall_line) and String(l).contains("plain sword") and String(l).contains("plain shortbow")),
		"...and the fall screen says so: %s" % [main.fall_note])
	_check(prof.gift.has("said"), "...his words wait for the train")
	# Falling again while wearing them: nothing more.
	main.fall_note = []
	main.on_player_died()
	_check(_copies(prof, "melee") == 1 and _copies(prof, "ranged") == 1 and not main.fall_note.any(func(l): return String(l).begins_with(fall_line)), "a fall while they're still yours gives nothing more")
	# One in the stash: it goes on, no new copy.
	_bare(main)
	prof.chest = [Gear.make("plate"), Gift.piece("melee")]
	main.on_player_died()
	_check(_copies(prof, "melee") == 1 and Gift.is_basic(prof.wear.get("melee", {})) and prof.chest.size() == 1 and Gear.base_id(prof.chest[0]) == "plate",
		"a basic sword in the stash: it's put on, not a second one given (no duplicates)")
	_check(Gift.is_basic(prof.wear.get("ranged", {})) and _copies(prof, "ranged") == 1, "...and the missing bow is given")
	var said: Dictionary = prof.gift.get("said", {})
	_check(Array(said.get("stash", [])) == ["melee"] and Array(said.get("given", [])) == ["ranged"], "...and he says which: %s" % [said])
	# An heirloom weapon: only what's lacking.
	_bare(main)
	prof.heirlooms["melee"] = Gear.make("spear", "fine", ["edges"])
	prof.chest = [Gear.make("crossbow")]
	main.on_player_died()
	_check(not prof.wear.has("melee") and Gift.is_basic(prof.wear.get("ranged", {})), "an heirloom spear: no sword given, only the bow (a crossbow lying in the stash isn't worn, so the bow comes)")
	# Both covered: nothing.
	_bare(main)
	prof.heirlooms["melee"] = Gear.make("spear", "fine", ["edges"])
	prof.heirlooms["ranged"] = Gear.make("longbow", "fine", Gear.roll_traits("longbow", "fine"))
	main.on_player_died()
	_check(prof.wear.is_empty() and not prof.gift.has("said") and not main.fall_note.any(func(l): return String(l).begins_with(fall_line)), "heirloom weapons in both slots: nothing given, nothing said")
	# Every fall leaves the climber able to fight.
	var able := true
	for setup in [[], ["melee"], ["ranged"], ["melee", "ranged"]]:
		_bare(main)
		for s in setup:
			prof.chest.append(Gift.piece(s))
		main.on_player_died()
		able = able and Gift.covered(prof, "melee") and Gift.covered(prof, "ranged")
	_check(able, "after any fall the climber wears a melee and a ranged weapon on the train")
	# The lost cache never remembers them.
	_bare(main)
	var p = main.player
	prof.lost = []
	p.pack = [Gift.piece("melee"), Gear.make("dagger", "fine", ["edges"])]
	var loss: Dictionary = Lost.fall(prof, p, "kraken", 3, 0.0)
	_check(prof.lost.size() == 1 and Gear.base_id(prof.lost[0]["rec"]) == "dagger" and int(loss["pack"]) == 2, "a basic sword lost in the pack isn't remembered for a cache (one would come back twice)")
	p.take_gear(Gift.piece("melee"), "melee")
	_check(p.weapon == "sword" and Lost.hand_weapon(p).is_empty(), "...and the weapon in hand a fall may take is never the basic sword")
	p.pack = []
	# A climb abandoned mid-way (a restart, the game closed) counts as a fall.
	_bare(main)
	Gift.departing(prof)
	_check(Gift.on_arrival(prof) and Gift.is_basic(prof.wear.get("melee", {})) and Gift.is_basic(prof.wear.get("ranged", {})) and not prof.gift.has("out"),
		"a climb left without a fall or getting out: the next start gives the sword and bow as after a fall")
	_check(not Gift.on_arrival(prof) and _copies(prof, "melee") == 1, "...once")
	prof.gift = {}


func _gift_shown(main) -> void:
	var prof = main.profile
	var menu = main.menu
	var keep_guide: Dictionary = Guide.state.duplicate(true)
	Engine.set_meta("sixfold_tips", true)
	Guide.forget()
	_bare(main)
	main.on_player_died()
	main.open_train()
	await t._frames(3)
	var name: String = OutfitterName.NAME
	_check(main.gift_line != "" and main.gift_line.contains("plain sword") and main.gift_line.contains("gift") and not prof.gift.has("said"),
		"on the train, %s's words about the gift: \"%s\" (said once)" % [name, main.gift_line])
	var root: Node = menu.train_page.roots.get("personal", null)
	var said: Array = []
	if root != null:
		for n in root.find_children("*", "", true, false):
			if n.has_meta("outfitter_line"):
				said.append(String(n.get_meta("outfitter_line")))
	_check(said.has(main.gift_line), "...in his bubble at the top of your car")
	var tip: String = String(menu.train_page.tips.get("personal", ""))
	var first: String = String(Entity.TIPS["basic_gift"]["tip"])
	_check(tip.contains(first.left(24)), "...with the Entity's first-time word on it: %s" % first)
	menu.close()
	main.gift_line = ""
	main.on_train = false
	Engine.remove_meta("sixfold_tips")
	Guide.state = keep_guide
	Guide.queue.clear()
	Guide.held.clear()
	Entity.gone.clear()
	t.paused = false
	await t._frames(1)
	# The card of a basic piece: no Sell, and why.
	_bare(main)
	prof.chest = [Gift.piece("melee")]
	menu.train_car = "personal"
	menu.inv_sel = "chest:0"
	menu.open("train")
	await t._frames(3)
	var labels: Array = t._all_labels(menu).map(func(l): return l.text)
	_check(t._car_buttons("sell", "chest:0").is_empty() and t._car_buttons("equip", "chest:0").size() == 1 and labels.has(Gift.TEXT["note"]),
		"its card in your car: wear it, but no Sell button, and a line saying why")
	menu.close()
	t.paused = false
	main.on_train = false
	prof.chest = []
	await t._frames(1)


func _new_climber() -> void:
	var P = load("res://scripts/profile.gd")
	var fresh = P.new()
	fresh.saving = false
	_check(fresh.wear.size() == 2 and Gift.is_basic(fresh.wear["melee"]) and Gift.is_basic(fresh.wear["ranged"]), "a new climber's Loadout holds the basic sword and bow")
	fresh.wear = {}
	fresh.regarded = true
	fresh.reset()
	_check(fresh.wear.size() == 2 and Gift.is_basic(fresh.wear["melee"]) and Gift.is_basic(fresh.wear["ranged"]) and fresh.gift.is_empty(), "...and Start over starts with them again")
	# Each past dresses as it always did: its own pieces, the basic sword and bow in the slots it leaves empty.
	var want := {"soldier": ["sword", "shortbow"], "hunter": ["dagger", "shortbow"], "labourer": ["war_hammer", "shortbow"], "beggar": ["dagger", "shortbow"],
		"scholar": ["sword_cane", "shortbow"], "sailor": ["sword", "flintlock"]}
	var off: Array = []
	for past in want:
		var p = P.new()
		p.saving = false
		p.reset()
		NewStart.apply(p, {"past": past, "home": "wyvern", "why": "hired"})
		var g: Dictionary = Train.dressed(p)
		if Gear.base_id(g.get("melee", {})) != want[past][0] or Gear.base_id(g.get("ranged", {})) != want[past][1]:
			off.append("%s: %s, %s" % [past, Gear.base_id(g.get("melee", {})), Gear.base_id(g.get("ranged", {}))])
		var given: Dictionary = NewStart.PAST[past]
		for s in ["melee", "ranged"]:
			if String(given.get(s, "")) != "" and p.wear.has(s):
				off.append("%s still wears a basic %s over its own" % [past, s])
	_check(off.is_empty(), "every past starts with its own pieces and the basic sword or bow where it gave none, as before %s" % [off])


func _old_save() -> void:
	var path := TestRun.path("user://basic_gift_test.cfg")
	var old := ConfigFile.new()
	old.set_value("profile", "regarded", true)
	old.set_value("profile", "heirlooms", {"melee": Gear.code(Gear.make("spear", "fine", ["edges"]))})
	old.set_value("train", "chest", [Gear.code(Gift.piece("ranged"))])
	old.save(path)
	var a = load("res://scripts/profile.gd").new()
	a.save_path = path
	a.load_save()
	_check(not a.wear.has("melee") and not a.wear.has("ranged") and a.chest.size() == 1, "an old save keeping a spear and a bow in its stash: nothing new handed over")
	old.set_value("train", "chest", [])
	old.save(path)
	var b = load("res://scripts/profile.gd").new()
	b.save_path = path
	b.load_save()
	_check(not b.wear.has("melee") and Gift.is_basic(b.wear.get("ranged", {})), "an old save with no bow: the bow it always had is handed over, once")
	b.saving = true
	b.save()
	var c = load("res://scripts/profile.gd").new()
	c.save_path = path
	c.load_save()
	c.wear.erase("ranged")
	c.saving = true
	c.save()
	var d = load("res://scripts/profile.gd").new()
	d.save_path = path
	d.load_save()
	_check(not d.wear.has("ranged"), "...and a save from now on is never handed it again on load")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))


func _words(main) -> void:
	var texts: Array = Gift.TEXT.values().map(func(v): return String(v))
	texts.append(String(Entity.TIPS["basic_gift"]["tip"]))
	texts.append(String(Entity.TIPS["basic_gift"]["more"]))
	var talk: String = Talk.line_for(main, "how_gift")
	var all: String = " ".join(texts)
	_check(Entity.TIPS.has("basic_gift") and "how_gift" in Talk.DIALOGUE["how_fall"]["choices"] and "how_gift" in Talk.DIALOGUE["how_shop"]["choices"],
		"the Entity explains it: a first-time tip, and \"The plain sword and bow?\" under How does it work, after the falls topic and the shop topic")
	_check(not all.contains("{outfitter}") and not talk.contains("{outfitter}") and String(Gift.TEXT["note"]).contains(OutfitterName.NAME) and talk.contains(OutfitterName.NAME),
		"%s's name fills the words: %s" % [OutfitterName.NAME, talk])
	all += " " + talk
	var low := all.to_lower()
	_check(BANNED.all(func(w): return not low.contains(w)), "no banned words in the gift's words")
