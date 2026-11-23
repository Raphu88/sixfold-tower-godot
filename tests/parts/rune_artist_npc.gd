extends RefCounted
## The Rune Artist at the workshop's bench (bench.gd ARTIST, PREMIUM): every
## climber can have the bench's crafting done (tempering, retraiting,
## joining, a lasting rune, a recall scroll, a vessel, a new charm). A climber
## with the Rune Artist's mark crafts with their own essence and pays the
## materials; anyone else has the Rune Artist craft for them and pays the
## materials plus the premium. The NPC is drawn in the Workshop car, with the
## Entity's help on it and a first-time moment; the cards say who crafts.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const Bench := preload("res://scripts/bench.gd")
const V := preload("res://scripts/vessel.gd")
const G := preload("res://scripts/gear.gd")
const TV := preload("res://scripts/train_view.gd")
const Entity := preload("res://scripts/entity.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const Help := preload("res://scripts/entity_help.gd")

const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

var t


func run(smoke) -> void:
	t = smoke
	await _prices()
	await _in_the_car()
	_words()


func _main():
	return t.main


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## The rules: who crafts, and what it costs each.
func _prices() -> void:
	print("the Rune Artist: materials + premium")
	await t._fresh_main()
	t.paused = false
	var main = _main()
	main.grant_test_bonds()
	var prof = main.profile
	prof.crystals = []
	prof.heirlooms = {"melee": G.make("spear", "fine", ["edges"])}
	prof.pack = []
	prof.chest = []
	_check(String(Bench.ARTIST["name"]) != "" and float(Bench.PREMIUM["share"]) > 0.0 and float(Bench.PREMIUM["share"]) <= 0.5 and int(Bench.PREMIUM["work"]) <= 12,
		"the Rune Artist's name and a modest premium are in data tables (%s)" % [Bench.PREMIUM])
	_check(not Bench.rune_artist(prof) and Bench.artist_crafts(prof), "a climber without the mark: the Rune Artist crafts for them")
	# Tempering: the same materials a Rune Artist pays, plus the premium.
	var mats: Dictionary = Bench.temper_cost(prof.heirlooms["melee"])
	var price: Dictionary = Bench.temper_cost(prof.heirlooms["melee"], prof)
	var fee: Dictionary = Bench.premium(prof, mats)
	_check(mats == {"blade": 20} and fee == {"blade": 10} and price == {"blade": 30}, "tempering to +1: 20 Blade materials + 10 premium = 30 (%s, %s)" % [mats, price])
	prof.add_crystal("blade", 29.0)
	_check(Bench.temper(prof, "heir:melee") != "" and int(prof.heirlooms["melee"]["rank"]) == 0, "...29 Blade isn't enough")
	prof.add_crystal("blade", 1.0)
	_check(Bench.temper(prof, "heir:melee") == "" and int(prof.heirlooms["melee"]["rank"]) == 1 and prof.crystal_total("blade") == 0.0, "...30 pays for it: the Rune Artist tempers it")
	# A lasting rune, a retrait, a join: each its materials + premium.
	prof.add_crystal("iron", 100.0)
	_check(Bench.inscribe_cost(prof) == {"iron": 38} and Bench.inscribe(prof, "heir:melee", "sharpness") == "" and prof.crystal_total("iron") == 62.0, "a lasting rune: 25 Iron + 13 premium")
	prof.chest = [G.make("iron_helm", "rare", ["vigor", "calm"])]
	prof.add_crystal("fire", 45.0)
	_check(Bench.retrait_cost(prof.chest[0], "fire", prof) == {"fire": 45} and Bench.retrait(prof, "chest:0", 0, "fire") == "" and prof.crystal_total("fire") == 0.0, "a retrait on a Rare: 30 Fire + 15 premium")
	prof.pack = [G.make("leather_gloves", "fine", ["edges"]), G.make("grip_wraps", "fine", ["riposte"])]
	prof.add_crystal("blade", 45.0)
	_check(Bench.join(prof, "pack:0", "pack:1") == "" and prof.pack.size() == 1 and prof.crystal_total("blade") == 0.0, "joining two pieces: 30 Blade + 15 premium")
	# A recall scroll and a vessel.
	prof.add_crystal("air", 45.0)
	prof.add_crystal("water", 45.0)
	_check(Bench.brew(prof, main.player, "scroll") == "" and int(prof.supplies.get("scroll", 0)) == 1 and prof.crystal_total("air") == 0.0 and prof.crystal_total("water") == 0.0, "a recall scroll: 30 Air + 30 Water, + 15 of each")
	main.Train.put_back(prof, "scroll")
	_check(prof.crystal_total("air") == 45.0, "...put back, all of it comes back (the premium too)")
	prof.crystals = []
	for k in V.brew_cost(prof):
		prof.add_crystal(k, float(V.brew_cost(prof)[k]))
	_check(V.brew(prof) == "" and prof.vessels.size() == 1 and prof.crystal_total("iron") == 0.0, "a vessel: its materials + premium (%s)" % Bench.cost_text(V.brew_cost(prof)))
	# Working a full vessel into a piece: no crystals of its own, so a small fee.
	prof.heirlooms["melee"]["rank"] = G.MAX_RANK
	prof.vessels = [V.make("life", V.CAPACITY)]
	var wf: Dictionary = V.work_fee(prof, "heir:melee")
	_check(wf == {"blade": int(Bench.PREMIUM["work"])} and V.deep_temper(prof, "heir:melee") != "", "working a full vessel in: a fee of %d Blade, and not without it" % int(Bench.PREMIUM["work"]))
	prof.add_crystal("blade", float(Bench.PREMIUM["work"]))
	_check(V.deep_temper(prof, "heir:melee") == "" and int(prof.heirlooms["melee"]["rank"]) == G.RANK_CAP and prof.crystal_total("blade") == 0.0, "...with it, the Rune Artist tempers past +3")
	# A charm.
	prof.add_crystal("blade", 45.0)
	_check(Bench.craft_cost("wardbreaker", prof) == {"blade": 45} and Bench.craft(prof, "wardbreaker") == "chest" and prof.crystal_total("blade") == 0.0, "a charm: 30 Blade + 15 premium")
	# A Rune Artist pays only the materials.
	prof.add_bond("brow", "rune_artist", false)
	prof.crystals = []
	prof.heirlooms = {"melee": G.make("spear", "fine", ["edges"])}
	_check(not Bench.artist_crafts(prof) and Bench.premium(prof, {"blade": 20}).is_empty(), "a Rune Artist crafts for themselves: no premium")
	prof.add_crystal("blade", 20.0)
	_check(Bench.temper(prof, "heir:melee") == "" and int(prof.heirlooms["melee"]["rank"]) == 1 and prof.crystal_total("blade") == 0.0, "...tempering to +1 costs them 20 Blade, the materials alone")
	_check(Bench.inscribe_cost(prof) == Bench.INSCRIBE and Bench.brew_cost(prof, "scroll") == Bench.BREW["scroll"] and V.brew_cost(prof) == V.BREW and V.work_fee(prof, "heir:melee").is_empty(), "...and every other crafted work its materials alone")
	_check(Bench.crafter_line(prof, {"blade": 20}).begins_with("You craft"), "the card says they craft it")


## In the Workshop car: the Rune Artist drawn at the bench, talking, and a
## counter's card showing materials + premium.
func _in_the_car() -> void:
	print("the Rune Artist in the Workshop car")
	await t._fresh_main()
	t.paused = false
	var main = _main()
	main.grant_test_bonds()
	var prof = main.profile
	prof.crystals = []
	prof.heirlooms = {"melee": G.make("spear", "fine", ["edges"])}
	prof.add_crystal("blade", 100.0)
	main.touch._set_active(false)
	main.await_tower()
	main.open_train()
	await t._frames(3)
	var menu = main.menu
	menu.train_car = "workshop"
	menu.train_bench = "temper"
	menu.inv_sel = "bench:heir:melee"
	menu.open("train")
	await t._frames(3)
	var npc: Array = t._car_buttons("rune_artist", true)
	_check(npc.size() == 1 and npc[0] is TV.RuneArtist and npc[0].get_meta("help", "") == "rune_artist_npc", "the Rune Artist stands at the bench in the Workshop car, drawn in code")
	var bubbles: Array = menu.train_page.roots["workshop"].find_children("*", "PanelContainer", true, false).filter(func(c): return c.has_meta("artist_line"))
	_check(bubbles.size() == 1 and String(bubbles[0].get_meta("artist_line")) == String(Bench.ARTIST["greeting"]), "...and greets you")
	var said := String(Help.explain(menu, npc[0])) if npc.size() == 1 else ""
	_check(said.contains(String(Bench.ARTIST["name"])) and said.contains("premium"), "the Entity explains them on hover or hold (%s)" % said)
	if npc.size() == 1:
		npc[0].pressed.emit()
		await t._frames(3)
	bubbles = menu.train_page.roots["workshop"].find_children("*", "PanelContainer", true, false).filter(func(c): return c.has_meta("artist_line") and not c.is_queued_for_deletion())
	_check(bubbles.size() == 1 and String(bubbles[0].get_meta("artist_line")) in Bench.ARTIST["lines"], "pressed, they say something else")
	var lines: Array = t._all_labels(menu.train_page.roots["workshop"]).filter(func(l): return l.has_meta("crafter_line") and not l.is_queued_for_deletion())
	_check(lines.size() == 1 and lines[0].get_meta("crafter_line") == "artist" and lines[0].text.contains("materials") and lines[0].text.contains("premium"), "a counter's card shows who crafts: materials + premium (%s)" % (lines[0].text if not lines.is_empty() else ""))
	var tabs: Array = t._car_buttons("bench_tab", "temper")
	var tip := String(Help.explain(menu, tabs[0])) if tabs.size() == 1 else ""
	_check(tip.contains("Rune Artist") and tip.contains("premium"), "the counter's hover help says the Rune Artist crafts it for you (%s)" % tip)
	var temper: Array = t._car_buttons("bench_do", "temper")
	_check(temper.size() == 1 and not temper[0].disabled, "...and its button works")
	if temper.size() == 1:
		temper[0].pressed.emit()
		await t._frames(2)
		await t._confirm(true)
		await t._frames(2)
	_check(int(prof.heirlooms["melee"]["rank"]) == 1 and prof.crystal_total("blade") == 70.0, "pressed and confirmed: tempered, 30 Blade paid (20 + 10 premium)")
	# A phone: the Rune Artist and the counters still fit.
	main.touch._set_active(true)
	menu.open("train")
	await t._frames(3)
	var small: Array = t._all_buttons(menu.train_page.roots["workshop"]).filter(func(b): return b.is_visible_in_tree() and b.size.y < 36.0)
	_check(small.is_empty(), "on a phone every Workshop button, the Rune Artist too, is big enough to touch (%s)" % [small.map(func(b): return b.text)])
	main.touch._set_active(false)
	menu.close()
	await t._frames(2)
	main.on_train = false


## The Entity's words: a first-time moment, a topic, and no banned words.
func _words() -> void:
	print("the Rune Artist: the Entity's words")
	var TP = load("res://scripts/train_page.gd")
	_check(Entity.TIPS.has("rune_artist") and "rune_artist" in TP.CAR_TIPS["workshop"], "the Entity explains the Rune Artist the first time you're in the Workshop")
	_check(Talk.DIALOGUE.has("how_workshop") and "how_workshop" in Talk.DIALOGUE["how"]["choices"], "...and answers \"The Workshop and its Rune Artist?\"")
	var line := String(Talk.DIALOGUE["how_workshop"]["lines"][0])
	_check(line.contains("{artist}") and line.contains("{artist_premium}") and Talk._fact_rules().has("artist_premium"), "...with the premium read from its table")
	var words := (str(Bench.ARTIST) + str(Entity.TIPS["rune_artist"]) + str(Entity.TIPS["enchant"]) + line + str(Help.HELP)).to_lower()
	var found: Array = BANNED.filter(func(w): return RegEx.create_from_string("\\b" + w + "\\b").search(words) != null)
	_check(found.is_empty(), "none of the owner's banned words (%s)" % [found])
	_check(not words.contains("only a rune artist can"), "nothing says only a Rune Artist can craft")
