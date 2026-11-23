extends RefCounted
## Every essence item's own pool (item_pool.gd): which items carry one and
## how big; a use draws on the item's pool first, then on the essence the
## climber carries, then nothing (a weapon still works plainly); filtering
## essence in to refill it (the inventory, not while a monster is after you;
## the bench with crystals) and to power it (holding the off-hand button);
## heirlooms and a new climb don't refill it; old saves' pieces are full;
## the bars drawn (HUD, slots, touch); the phone's Off-hand button; the
## Entity's words; no banned words. Also the intro's line about boarding.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const G := preload("res://scripts/gear.gd")
const C := preload("res://scripts/charms.gd")
const O := preload("res://scripts/offhand.gd")
const Pool := preload("res://scripts/item_pool.gd")
const W := preload("res://scripts/weapons.gd")
const Bench := preload("res://scripts/bench.gd")
const D := preload("res://scripts/draw_util.gd")
const Entity := preload("res://scripts/entity.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const Help := preload("res://scripts/entity_help.gd")
const Registry := preload("res://scripts/data_registry.gd")
const NewStart := preload("res://scripts/new_start.gd")

const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

var t


func run(smoke) -> void:
	t = smoke
	print("item_pools: every essence item's own pool")
	await t._fresh_main()
	_which()
	await _wand_order()
	await _charm_order()
	await _melee_edge()
	await _ranged()
	await _pistol()
	await _filtering()
	await _power()
	_bench_and_heirloom()
	_old_saves()
	await _bars()
	await _touch()
	_words()
	var m = _main()
	m.run_essence = {}
	Engine.time_scale = 1.0


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _main():
	return t.main


## A climber in the tower, monsters gone, nothing in the off hand, sword in hand.
func _fresh_player():
	var m = _main()
	for e in m.enemies():
		if is_instance_valid(e):
			e.queue_free()
	await t._frames(1)
	var p = m.player
	p.gear = G.start_gear()
	p.weapon = "sword"
	p.swing = p.wdata()["combo"][0]
	p.combo = 0
	p.combo_t = 0.0
	p.refresh_gear()
	p.dead = false
	p.hp = p.max_health()
	p.sta = p.max_sta
	p.fatigue = 0.0
	p.attack_cd = 0.0
	p.reload_t = 0.0
	p.off_cd = 0.0
	p.item_power = {}
	p.off_hold_t = -1.0
	p.hurt_t = 0.0
	p.iframes = 0.0
	p.aim = Vector2.RIGHT
	p.mouse_aim = false
	p.global_position = Vector2(500, 400)
	p.set_physics_process(false)
	m.run_essence = {}
	return p


func _shots() -> Array:
	return _main().get_children().filter(func(c): return c.get_script() != null and c.get_script().resource_path.ends_with("projectile.gd") and c.friendly and is_instance_valid(c))


func _clear_shots() -> void:
	for s in _shots():
		s.queue_free()


func _carried() -> float:
	return Pool.carried(_main())


# --- which items carry a pool ----------------------------------------------------------

func _which() -> void:
	var wands: Array = G.PIECE_ORDER.filter(func(id): return O.use_of(id) == "wand")
	_check(wands.size() == 6 and wands.all(func(id): return Pool.has_pool(G.make(id)) and Pool.cap(G.make(id)) in [3, 6]), "every wand carries its own pool (3 or 6 uses)")
	_check(Pool.cap(G.make("ember_dirk")) == 6 and Pool.cap(G.make("tide_ward")) == 3 and not Pool.has_pool(G.make("buckler")), "the Ember Dirk and Tide Ward too; a plain buckler has none")
	var charged: Array = C.all().filter(func(id): return C.charge_id(G.make(id)) != "")
	_check(not charged.is_empty() and charged.all(func(id): return Pool.has_pool(G.make(id))) and not Pool.has_pool(G.make("lucky_knot")), "every charm with a charge carries its own pool; a passive-only charm has none")
	var sword := G.make("sword", "fine", ["edges"])
	_check(Pool.has_pool(sword) and Pool.cap(sword) == 6 and Pool.per_use(sword) == 3 and Pool.kind(sword) == "blade", "a Fine sword (of Edges) is enchanted: a pool of 6 blade uses, 3 essence each")
	_check(Pool.cap(G.make("longbow", "fine", ["embers"])) == 6 and Pool.cap(G.make("crossbow", "fine", ["embers"])) == 6 and Pool.cap(G.make("revolver", "fine", ["embers"])) == 12,
		"bows and crossbows hold 6 uses, pistols 12 (by sixes)")
	_check(not Pool.has_pool(G.make("sword")) and not Pool.has_pool(G.make("revolver")) and not Pool.has_pool("fists") and not Pool.has_pool(G.make_named("lastbell_revolver")),
		"plain pieces carry none: a Common sword or revolver, fists, a relic that isn't enchanted")
	_check(Pool.WEAPON.values().all(func(r): return int(r["max"]) % 6 == 0 or int(r["max"]) == 3), "every pool size is a multiple of six (or 3)")
	var lines: Array = G.trait_lines(sword).map(func(l): return String(l[0]))
	_check(lines.any(func(l): return l.begins_with("Its own essence")) and lines.any(func(l): return l.begins_with(Pool.EDGE["blade"]["name"])), "its card shows its pool and its edge %s" % [lines])


# --- the order: its pool, then yours, then nothing ----------------------------------------

func _wand_order() -> void:
	var m = _main()
	var p = await _fresh_player()
	p._equip("fists")
	p.take_gear(G.make("cinder_wand"))
	var g := O.piece(p)
	m.run_essence = {"fire": 10.0, "air": 10.0}
	for i in 6:
		p.off_cd = 0.0
		p.sta = p.max_sta
		O.cast(p)
	_check(O.pool(g) == 0 and absf(_carried() - 20.0) < 0.01, "a wand casts from its own pool first: six casts, your essence untouched (%.0f)" % _carried())
	_clear_shots()
	await t._frames(1)
	p.off_cd = 0.0
	p.sta = p.max_sta
	O.cast(p)
	_check(_shots().size() == 1 and absf(float(m.run_essence.get("fire", 0.0)) - 7.0) < 0.01 and absf(float(m.run_essence.get("air", 0.0)) - 10.0) < 0.01,
		"its pool dry, a cast draws on the essence you carry: its own kind first (%s)" % [m.run_essence])
	m.run_essence = {}
	_clear_shots()
	await t._frames(1)
	p.off_cd = 0.0
	p.sta = p.max_sta
	O.cast(p)
	_check(_shots().is_empty() and O.pool(g) == 0, "with neither, it doesn't cast")
	_clear_shots()
	await t._frames(1)


func _charm_order() -> void:
	var m = _main()
	var p = await _fresh_player()
	p.take_gear(G.make("ashen_knot"))
	m.run_essence = {"fire": 40.0}
	_check(C.fire(p, "rally") and C.charges(p.gear["charm"]) == 0 and absf(_carried() - 40.0) < 0.01, "a charm's charge fires from its own pool first")
	_check(C.fire(p, "rally") and absf(_carried() - 10.0) < 0.01, "spent, it draws its charge's worth from the essence you carry (%.0f left)" % _carried())
	_check(not C.fire(p, "rally") and absf(_carried() - 10.0) < 0.01, "with too little carried, it stays quiet")
	m.run_essence = {}
	await t._frames(1)


func _finisher(p, e) -> float:
	var hp0: float = e.hp
	p.attack_cd = 0.0
	p.sta = p.max_sta
	p.combo = p.wdata()["combo"].size() - 1
	p.combo_t = 1.0
	p._melee()
	_main().hitstop_until = 0
	return hp0 - e.hp


func _melee_edge() -> void:
	var m = _main()
	var p = await _fresh_player()
	p.take_gear(G.make("sword", "fine", ["edges"]))
	p._equip("sword")
	var g: Dictionary = p.gear["melee"]
	var e = await t._dummy(p.global_position + Vector2(30, 0))
	m.run_essence = {"blade": 10.0}
	var edged := _finisher(p, e)
	_check(Pool.left(g) == 5 and absf(_carried() - 10.0) < 0.01, "an enchanted sword's landed finisher spends a use of its own pool (5 of 6)")
	p.combo = 0
	p.attack_cd = 0.0
	p.combo_t = 0.0
	p._melee()
	m.hitstop_until = 0
	_check(Pool.left(g) == 5, "...a lighter blow spends nothing")
	g["charge"] = 0
	_finisher(p, e)
	_check(Pool.left(g) == 0 and absf(_carried() - 7.0) < 0.01, "its pool dry, a finisher draws on the essence you carry (%.0f left)" % _carried())
	m.run_essence = {}
	var plain := _finisher(p, e)
	_check(plain > 0.0 and edged > plain * 1.2 and m.run_essence.is_empty(), "with neither, it still strikes plainly: no edge (%.1f with its edge, %.1f without)" % [edged, plain])
	# A fire edge sets the foe burning.
	p.take_gear(G.make("axe", "fine", ["embers"]))
	p._equip("axe")
	e.burn_t = 0.0
	_finisher(p, e)
	_check(e.burn_t > 0.0, "a fire edge sets the foe burning")
	if is_instance_valid(e):
		e.queue_free()
	await t._frames(1)


func _ranged() -> void:
	var m = _main()
	var p = await _fresh_player()
	p.take_gear(G.make("crossbow", "fine", ["riposte"]))
	p._equip("crossbow")
	var g: Dictionary = p.gear["ranged"]
	_clear_shots()
	await t._frames(1)
	p.attack_cd = 0.0
	p.reload_t = 0.0
	p._try_attack()
	var s := _shots()
	_check(Pool.left(g) == 5 and s.size() == 3 and s.any(func(x): return x.shot == "blade"), "an enchanted crossbow's bolt carries its essence: a blade shot splits into shards, a use spent (%d shots)" % s.size())
	g["charge"] = 0
	_clear_shots()
	await t._frames(1)
	p.attack_cd = 0.0
	p.reload_t = 0.0
	p._try_attack()
	s = _shots()
	_check(s.size() == 1 and s[0].shot == "" and Pool.left(g) == 0, "dry, with nothing carried: a plain bolt")
	# A bow: only a full draw spends a use.
	p.take_gear(G.make("longbow", "fine", ["embers"]))
	p._equip("longbow")
	var bow: Dictionary = p.gear["ranged"]
	_clear_shots()
	await t._frames(1)
	p.attack_cd = 0.0
	p.drawing = true
	p.draw_t = 0.05
	p.release_draw()
	_check(Pool.left(bow) == 6, "a bow's weak shot spends nothing")
	_clear_shots()
	await t._frames(1)
	p.attack_cd = 0.0
	p.drawing = true
	p.draw_t = float(p.wdata()["draw_time"])
	p.release_draw()
	s = _shots()
	_check(Pool.left(bow) == 5 and s.size() == 1 and s[0].shot == "fire", "a full draw carries its essence (fire shot), a use spent")
	_clear_shots()
	await t._frames(1)


func _pistol() -> void:
	var m = _main()
	var p = await _fresh_player()
	p.take_gear(G.make("revolver", "fine", ["embers"]))
	p._equip("revolver")
	var g: Dictionary = p.gear["ranged"]
	_clear_shots()
	await t._frames(1)
	p.attack_cd = 0.0
	p._try_attack()
	_check(Pool.left(g) == 11 and _shots().any(func(x): return x.shot == "fire"), "an enchanted pistol's essence shot spends a use of its own pool")
	g["charge"] = 0
	m.run_essence = {"fire": 4.0}
	_check(p.gun_magic() == "fire", "dry, it still fires essence while you carry enough")
	_clear_shots()
	await t._frames(1)
	p.attack_cd = 0.0
	p._try_attack()
	_check(absf(_carried() - 2.0) < 0.01, "...each shot drawing on yours (%.0f left)" % _carried())
	m.run_essence = {}
	_check(p.gun_magic() == "", "with neither, it fires lead")
	_clear_shots()
	await t._frames(1)
	p.attack_cd = 0.0
	p.ammo = 1
	p._try_attack()
	var s := _shots()
	_check(s.size() == 1 and s[0].shot == "" and s[0].style == "shot", "...a plain lead ball")
	p.attack_cd = 0.0
	p._tick_gun(0.016)
	_check(p.reload_t > 0.0, "...and once empty it reloads like any other")
	p.reload_t = 0.0
	_clear_shots()
	await t._frames(1)


# --- filtering: refill ---------------------------------------------------------------------

func _filtering() -> void:
	var m = _main()
	var p = await _fresh_player()
	p.take_gear(G.make("sword", "fine", ["edges"]))
	p._equip("sword")
	var g: Dictionary = p.gear["melee"]
	g["charge"] = 2
	m.run_essence = {"blade": 6.0, "air": 4.0}
	_check(Pool.refill_carried(m, g) != "" and Pool.left(g) == 2, "too little carried: not refilled (it needs 12)")
	m.run_essence = {"blade": 20.0, "air": 10.0}
	_check(Pool.refill_carried(m, g) == "" and Pool.left(g) == 6 and absf(_carried() - 18.0) < 0.01, "filtering 12 essence you carry refills its pool (%.0f left)" % _carried())
	_check(Pool.filter_why(m) == "", "no monster after you: filtering is allowed in a climb")
	var was_train: bool = m.on_train
	m.on_train = true
	var on_train := Pool.filter_why(m)
	m.on_train = was_train
	_check(on_train == "", "...and always on the train (the bench, with crystals)")
	# The inventory's card offers it.
	g["charge"] = 1
	m.menu.inv_sel = "gear:melee"
	m.menu.open("inventory")
	await t._frames(3)
	var feed: Array = m.menu.box.find_children("*", "Button", true, false).filter(func(b): return b.get_meta("help", "") == "feed_item")
	_check(feed.size() == 1 and not feed[0].disabled and String(feed[0].text).begins_with("Filter in"), "the inventory's card for an enchanted weapon: Filter in")
	if feed.size() == 1:
		feed[0].pressed.emit()
		await t._frames(3)
	_check(Pool.left(p.gear["melee"]) == 6, "...and pressing it refills the pool")
	m.menu.close()
	await t._frames(2)
	# A monster after you: it waits.
	var e = await t._spawn("slime", p.global_position + Vector2(60, 0))
	if "aware" in e:
		e.aware = true
	if "notice_t" in e:
		e.notice_t = 0.0
	e.set_physics_process(false)
	_check(Pool.filter_why(m) != "", "a monster after you: filtering waits (as the Body tab's moves)")
	p.gear["melee"]["charge"] = 1
	m.menu.inv_sel = "gear:melee"
	m.menu.open("inventory")
	await t._frames(3)
	feed = m.menu.box.find_children("*", "Button", true, false).filter(func(b): return b.get_meta("help", "") == "feed_item")
	_check(feed.size() == 1 and feed[0].disabled, "...its Filter in button waits too")
	m.menu.close()
	await t._frames(2)
	if is_instance_valid(e):
		e.queue_free()
	m.run_essence = {}
	await t._frames(1)


# --- filtering: power ----------------------------------------------------------------------

func _power() -> void:
	var m = _main()
	var p = await _fresh_player()
	p.take_gear(G.make("sword", "fine", ["edges"]))
	p._equip("sword")
	var g: Dictionary = p.gear["melee"]
	var e = await t._dummy(p.global_position + Vector2(30, 0))
	m.run_essence = {}
	_check(Pool.prime(p) == "" and p.item_power.is_empty(), "nothing carried: nothing to power with")
	m.run_essence = {"blade": 20.0}
	var plain := _finisher(p, e)
	_check(Pool.prime(p) == "melee" and Pool.primed_for(p, g) and absf(_carried() - 14.0) < 0.01, "powering the sword in hand takes 6 essence you carry")
	var powered := _finisher(p, e)
	_check(powered > plain * 1.3 and p.item_power.is_empty(), "its next finisher hits harder (%.1f, not %.1f), and the power is spent" % [powered, plain])
	if is_instance_valid(e):
		e.queue_free()
	# The off-hand button: a tap casts a wand, a hold powers it.
	p._equip("fists")
	p.take_gear(G.make("cinder_wand"))
	var wand := O.piece(p)
	m.run_essence = {"fire": 20.0}
	_clear_shots()
	await t._frames(1)
	p.off_hold_t = 0.0
	p.off_hold_done = false
	p.buffered = ""
	p._update_off_hold(0.016)  # (not held: let go at once, a tap)
	_check(p.buffered == "offhand", "a tap of the off-hand button casts the wand")
	p.buffered = ""
	m.hitstop_until = 0
	Engine.time_scale = 1.0  # (a finisher's hit-pause would speed the hold's clock: it counts real time)
	Input.action_press("offhand")
	p.off_hold_t = 0.0
	p.off_hold_done = false
	p._update_off_hold(0.3)
	_check(p.buffered == "" and p.item_power.is_empty(), "...held a moment, nothing yet")
	p._update_off_hold(0.3)
	_check(p.buffered == "offhand" and Pool.primed_for(p, wand), "...held half a second, the wand is powered and its cast is on its way")
	p.off_cd = 0.0
	p.sta = p.max_sta
	p._try_action("offhand", Vector2.ZERO)
	Input.action_release("offhand")
	p._update_off_hold(0.016)
	var s := _shots()
	var want: float = float(C.CHARGES["wand_fire"]["dmg"]) * 1.5 * (1.0 + float(p.gfx("spell")))
	_check(s.size() == 1 and absf(float(s[0].dmg) - want) < 0.05 and p.item_power.is_empty() and p.off_hold_t < 0.0, "...a powered bolt, half again as hard (%.1f)" % (float(s[0].dmg) if s.size() > 0 else -1.0))
	# Powered with its pool and your essence dry: the power pays for itself.
	wand["charge"] = 0
	m.run_essence = {"fire": 6.0}
	_clear_shots()
	await t._frames(1)
	_check(Pool.prime(p) == "offhand" and _carried() < 0.01, "a dry wand can still be powered with the last 6 you carry")
	p.off_cd = 0.0
	p.sta = p.max_sta
	O.cast(p)
	_check(_shots().size() == 1, "...and the powered cast pays for itself")
	_clear_shots()
	m.run_essence = {}
	p.item_power = {}
	await t._frames(1)


# --- the bench, heirlooms, a new climb, old saves --------------------------------------------

func _bench_and_heirloom() -> void:
	var m = _main()
	var prof = m.profile
	var had_wear: Dictionary = prof.wear.duplicate(true)
	var had_heir: Dictionary = prof.heirlooms.duplicate(true)
	var full := G.make("sword", "fine", ["edges"])
	prof.wear["melee"] = full
	_check(not ("wear:melee" in Bench.charm_refs(prof)), "a full enchanted weapon doesn't crowd the bench's Charms counter")
	var spent := G.make("sword", "fine", ["edges"])
	spent["charge"] = 2
	prof.wear["melee"] = spent
	_check("wear:melee" in Bench.charm_refs(prof) and Bench.refill_cost(spent) == {"blade": 12}, "a spent one is listed there: refilled with 12 blade crystals (%s)" % [Bench.refill_cost(spent)])
	prof.add_crystal("blade", 20.0)
	_check(Bench.refill(prof, "wear:melee") == "" and Pool.left(prof.wear["melee"]) == 6, "...and the bench refills it")
	# An heirloom's pool follows the climb's, and a new climb doesn't refill it.
	prof.heirlooms["melee"] = G.make("sword", "fine", ["edges"])
	var p = m.player
	p.gear["melee"] = G.heirloom_copy(prof.heirlooms["melee"])
	p.weapon = "sword"
	Pool.draw(m, p.gear["melee"])
	_check(Pool.left(prof.heirlooms["melee"]) == 5, "an heirloom's use is kept on the heirloom")
	_check(Pool.left(G.heirloom_copy(prof.heirlooms["melee"])) == 5, "...so the next climb starts with it as it was, not full")
	prof.wear = had_wear
	prof.heirlooms = had_heir
	prof.save()


func _old_saves() -> void:
	var old := G.rec({"base": "sword", "rarity": "fine", "traits": ["edges"], "rank": 0})
	_check(Pool.left(old) == Pool.cap(old) and Pool.cap(old) == 6, "an old save's enchanted weapon (no pool noted) starts full")
	_check(Pool.left(G.rec("revolver;fine;0;embers")) == 12, "...and so does one saved as a code")
	var kept := G.make("sword", "fine", ["edges"])
	kept["charge"] = 2
	_check(int(G.rec(kept).get("charge", -1)) == 2, "a weapon's pool is kept on its record")
	_check(not G.rec(G.make("sword")).has("charge"), "a plain weapon keeps no pool")


# --- bars, touch, words ----------------------------------------------------------------------

func _bars() -> void:
	var m = _main()
	var g := G.make("sword", "fine", ["edges"])
	g["charge"] = 3
	var b = D.Batch.new()
	Pool.bar_into(b, Rect2(0, 0, 30, 3), g)
	_check(not b.pts.is_empty() and Pool.share(g) == 0.5 and Pool.bar_color(g) == G.Essence.color("blade"), "its bar is drawn flat, half full, in its essence's colour")
	var none = D.Batch.new()
	Pool.bar_into(none, Rect2(0, 0, 30, 3), G.make("sword"))
	_check(none.pts.is_empty(), "a plain piece has no bar")
	# The HUD's weapon slot.
	var p = await _fresh_player()
	p.take_gear(g)
	p._equip("sword")
	await t._frames(3)
	var tip: Array = m.hud.tips.filter(func(x): return x[2] is Array and x[2].any(func(l): return String(l).begins_with("Its own essence")))
	_check(tip.size() == 1 and String(tip[0][1]) == G.display(p.weapon), "the HUD's weapon slot shows its pool (and says so on hover)")
	var slot = load("res://scripts/menu.gd").Slot.new()
	slot.kind = "gear"
	slot.rec = g
	slot.set_meta("slot", "pack:0")
	var help: String = Help.explain(m.menu, slot)
	slot.free()  # (only its tags are read: never shown)
	_check(help.contains("Its own essence"), "hover help on a slot with a pool tells of it: %s" % help)


func _touch() -> void:
	var m = _main()
	var p = await _fresh_player()
	m.touch._set_active(true)
	m.touch._layout()
	_check(not m.touch.buttons.any(func(b): return b["id"] == "offhand"), "a plain sword, no wand: no Off-hand button on the phone")
	p.take_gear(G.make("sword", "fine", ["edges"]))
	p._equip("sword")
	m.touch._layout()
	_check(m.touch.buttons.any(func(b): return b["id"] == "offhand") and "offhand" in m.touch.HOLD_TAP, "an enchanted weapon in hand: the Off-hand button shows (hold it to power)")
	m.touch._set_active(false)
	await t._frames(1)


func _words() -> void:
	for id in ["item_pool", "item_pool_empty", "item_power"]:
		_check(Entity.TIPS.has(id) and String(Entity.TIPS[id].get("tip", "")) != "" and String(Entity.TIPS[id].get("more", "")) != "", "the Entity explains it: %s" % id)
	_check(Talk.DIALOGUE.has("how_item_pool") and String(Talk.DIALOGUE["how_item_pool"]["ask"]) == "Items and their essence?" and "how_item_pool" in Talk.DIALOGUE["how"]["choices"],
		"\"Items and their essence?\" under How do things work here?")
	_check(["feed_item", "feed_charm", "feed_offhand"].all(func(k): return Help.HELP.has(k)) and Entity.KEYS.has("power"), "hover help for the filter buttons, and the power's keys")
	var tables: Array = []
	for sec in Registry.SECTIONS:
		tables.append_array(sec.get("tables", []))
	_check(["item_pool/TEXT", "item_pool/EDGE", "item_pool/WEAPON", "item_pool/POWER"].all(func(x): return tables.has(x)), "the pools' tables are in the Data editor")
	var words: Array = []
	words.append_array(Pool.TEXT.values())
	for k in Pool.EDGE:
		words.append_array([Pool.EDGE[k]["name"], Pool.EDGE[k]["desc"]])
	for id in ["item_pool", "item_pool_empty", "item_power"]:
		words.append_array([Entity.TIPS[id]["tip"], Entity.TIPS[id]["more"]])
	words.append_array(Talk.DIALOGUE["how_item_pool"]["lines"])
	words.append_array([Help.HELP["feed_item"], C.TEXT["charge_empty"], O.TEXT["pool_refill"], O.TEXT["no_pool"]])
	var bad: Array = []
	for w in words:
		for b in BANNED:
			if String(w).to_lower().contains(b):
				bad.append(String(w).left(40))
		if String(w).contains("Healing Draught"):
			bad.append(String(w).left(40))
	_check(bad.is_empty(), "no banned words in the pools' words %s" % [bad])
	var intro := String(NewStart.INTRO[0][1])
	_check(intro.contains("you remember boarding") and not intro.contains("whether you remember"), "the intro: the climber remembers boarding")
