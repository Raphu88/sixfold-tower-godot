extends RefCounted
## Getting out alive: a recall scroll (or the top of the tower) brings home
## what you wear and your pack; a fall loses them. Heirlooms and the sword
## and bow every climb starts with don't come home twice.

const Gear := preload("res://scripts/gear.gd")
const Train := preload("res://scripts/train.gd")

var t


func run(smoke) -> void:
	t = smoke
	print("getting out alive: what comes home")
	await t._fresh_main()
	var main = t.main
	var p = main.player
	var prof = main.profile
	prof.regarded = true
	main.first_climb = false
	prof.pack = []
	prof.wear = {}
	prof.heirlooms = {}
	# An heirloom helm; found pieces worn over nothing; a spare in the pack.
	var helm: Dictionary = Gear.make("leather_cap", "fine")
	prof.heirlooms[Gear.heirloom_slot(helm)] = Gear.heirloom_copy(helm)
	p.use_heirlooms(prof.heirlooms)
	var chest: Dictionary = Gear.make("leather", "rare")
	var blade: Dictionary = Gear.make("axe", "fine")
	p.take_gear(chest)
	p.take_gear(blade, "melee")
	p.pack = [Gear.make("soft_boots")]
	var bow_before: Dictionary = Gear.rec(p.gear.get("ranged", {}))
	main.read_recall()
	t._check(main.victory.get("recall", false), "the scroll is read")
	t._check(prof.wear.has("armor") and Gear.same(prof.wear["armor"], chest) and prof.wear.has("melee") and Gear.same(prof.wear["melee"], blade),
		"what you found and wore comes home on you (%s)" % [prof.wear.keys()])
	t._check(not prof.wear.has("helm"), "...your heirloom isn't brought home a second time")
	t._check(not prof.wear.has("ranged") or not Gear.same(prof.wear["ranged"], Gear.make(Gear.Weapons.START_RANGED)), "...nor the bow every climb starts with (%s)" % [bow_before.get("base", "")])
	t._check(prof.pack.size() == 1 and Gear.same(prof.pack[0], Gear.make("soft_boots")), "...and your pack comes down too")
	var lines: Array = main.victory.get("lines", [])
	t._check(lines.any(func(l): return String(l).contains("wearing what you found")), "...and the summary says so")
	# On the train it's what you'll wear; setting off again puts it on.
	var dressed: Dictionary = Train.dressed(prof)
	t._check(Gear.same(dressed.get("armor", {}), chest) and Gear.same(dressed.get("helm", {}), helm), "on the train you still wear it, with your heirloom")
	# Kept as an heirloom, it isn't also a chosen piece.
	main.keep_heirloom(Gear.code(chest))
	t._check(not prof.wear.has("armor") and Gear.same(Gear.heirloom_pieces(prof.heirlooms, Gear.heirloom_slot(chest))[0], chest), "kept as an heirloom, the piece is the heirloom only")
	# A fall brings nothing home.
	await t._fresh_main()
	main = t.main
	p = main.player
	prof = main.profile
	prof.regarded = true
	main.first_climb = false
	prof.wear = {}
	prof.pack = []
	p.take_gear(Gear.make("leather", "rare"))
	p.pack = [Gear.make("soft_boots")]
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.parry_t = 0.0
	p.receive_attack(99999.0, null)
	await t._frames(3)
	t._check(p.dead and prof.wear.is_empty() and prof.pack.is_empty(), "a fall loses what you wore and your pack")
	main.menu.close()
	t.paused = false
