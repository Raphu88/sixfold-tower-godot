extends RefCounted
## ITEMS WITH ESSENCE: every essence item carries its OWN POOL (the owner's
## rule: "Items like wands, charms, magical ranged and melee weapons should
## all have their own essence pool. That pool is used first before the
## player's, but the player's essence can be filtered into the item to
## either refill it or power it.").
##
## Which items: every charm that holds a charge, every enchanted off-hand
## piece (the six wands, the Ember Dirk, the Tide Ward) and every ENCHANTED
## WEAPON (a Fine or better melee weapon, bow, crossbow or pistol, and every
## enchanted relic: gear.gd enchanted). Plain pieces have no pool.
##
## THE POOL: a few uses of the item's own essence (its kind: a charm's,
## a wand's, a weapon's enchantment), each use worth "refill" essence. It is
## kept on the item's record ("charge"; a record with none noted is full, so
## every piece from an old save comes with a full pool). Charms and off-hand
## pieces keep their numbers in charms.gd CHARGES; weapons in WEAPON below.
##
## USING IT (draw): a use comes out of the item's own pool first. Only when
## that is empty does it draw on the essence YOU carry (gathered since the
## last stair, not yet banked: its own kind first, then any). With neither,
## its essence effect doesn't fire: a charm's charge stays quiet, a wand
## won't cast, a weapon still strikes and shoots plainly (an enchanted
## pistol fires lead and reloads like any other).
## What spends a use:
##   a charm          its charge firing (charms.gd)
##   a wand           a cast (the off-hand button; offhand.gd)
##   the Ember Dirk   its off-hand stab setting a foe burning
##   the Tide Ward    the wave a blocked blow sends out
##   a melee weapon   a landed finisher: its EDGE (below) on every foe it hits
##   a bow            a full draw: an essence shot (weapons.gd ESSENCE_SHOT)
##   a crossbow       every bolt: an essence shot
##   a pistol         every essence shot (its chambers still fill themselves)
##
## FILTERING your own essence into it, two ways:
##   REFILL  fills its pool again. In the tower from the inventory (the
##           item's card: Filter in, with essence you carry, any kind, each
##           kind in its share), but not while a monster is after you (as
##           the Body tab's moves: body_move.gd hunted; at a camp, always).
##           On the train at the workshop bench's Charms counter, with
##           crystals of its kind. Nothing else refills a pool (an enchanted
##           pistol's chambers still fill themselves, as they always did, but
##           its shots draw on the pool). A new climb doesn't refill it.
##   POWER   pushes extra essence through for one stronger use. Hold the
##           off-hand button (POWER "hold" seconds): the wand in your free
##           off hand casts at once, powered; otherwise the enchanted weapon
##           in your hand (else your Ember Dirk or Tide Ward) is primed and
##           its next use is powered. It costs POWER "essence" of what you
##           carry (its kind first); a powered use hits "mult" times as hard
##           (its essence effect too), and pays for itself if the pool and
##           your carried essence are dry. A tap still casts a wand.
## Slow growth: refills and power cost essence you would otherwise bank, and
## no pool grows; the numbers are small and plain data, easy to change.

const Gear := preload("res://scripts/gear.gd")
const Weapons := preload("res://scripts/weapons.gd")
const Essence := preload("res://scripts/essence.gd")
const Charms := preload("res://scripts/charms.gd")  # (charms.gd loads this one only when needed)
const BODY_MOVE := "res://scripts/body_move.gd"

## An enchanted weapon's pool, by its kind (weapons.gd "kind"):
##   max     how many uses it holds when full
##   refill  the essence one use is worth (to refill it, or drawn from yours)
static var WEAPON := {
	"melee": {"max": 6, "refill": 3},
	"bow": {"max": 6, "refill": 3},
	"crossbow": {"max": 6, "refill": 3},
	"gun": {"max": 12, "refill": 2},
}

## An enchanted melee weapon's EDGE: what a landed finisher does with a use
## of its pool, by the weapon's essence:
##   stagger  seconds the foe staggers (half on a beast)
##   extra    it cuts again for this share of the blow
##   push     it hurls the foe back this hard
##   burn, burn_t  it sets the foe burning: this much every half second, this long
##   chill    seconds the foe is slowed
## An essence it doesn't list cuts as "iron".
static var EDGE := {
	"stone": {"name": "Stone edge", "desc": "a finisher staggers what it hits", "stagger": 0.4},
	"blade": {"name": "Blade edge", "desc": "a finisher cuts again, for a third of the blow", "extra": 0.33},
	"iron": {"name": "Iron edge", "desc": "a finisher bites deeper and drives the foe back", "extra": 0.15, "push": 300.0},
	"air": {"name": "Air edge", "desc": "a finisher's gust hurls the foe back", "extra": 0.1, "push": 520.0},
	"fire": {"name": "Fire edge", "desc": "a finisher sets the foe burning", "burn": 3.0, "burn_t": 3.0},
	"water": {"name": "Water edge", "desc": "a finisher chills the foe for 2 seconds", "chill": 2.0},
}
const EDGE_DEFAULT := "iron"

## Powering an item (holding the off-hand button):
##   hold     seconds to hold it
##   essence  carried essence it takes (its kind first, then any)
##   mult     how much harder the powered use hits
static var POWER := {"hold": 0.5, "essence": 6.0, "mult": 1.5}

## The words (cards, the HUD's help, the inventory, over the climber).
static var TEXT := {
	"pool": "Its own essence  ·  %d of %d uses",
	"pool_full": "Its pool is full.",
	"pool_dry": "Its pool is dry: each use now draws on the essence you carry.",
	"pool_note": "Used first; when it's dry, a use draws on the essence you carry. Filter yours in to refill it: the inventory in the tower (no monster after you), or the workshop bench's Charms counter on the train. Hold the off-hand button to power its next use.",
	"edge": "%s: %s",
	"shot": "%s: %s (a full draw)",
	"bolt": "%s: %s (every bolt)",
	"gun_shot": "%s: %s (every shot)",
	"gun_dry": "Its shots draw on its pool; dry, with no essence of yours, it fires lead and reloads.",
	"emptied": "%s: its own essence is spent",
	"filter": "Filter in %d essence",
	"filter_note": "Essence you carry flows into it, any kind, each kind in its share.",
	"filter_short": "needs %d essence you carry (you have %d)",
	"filter_hunted": "Not while a monster is after you.",
	"filtered": "%s: its pool is full again",
	"power_hint": "Hold to power it: %s",
	"powered": "Powered: %s",
	"power_none": "Nothing in hand to power",
	"power_short": "Too little essence carried to power it",
	"power_again": "Already powered",
	"power_touch": "Power",
	"hud_power": "Powered: its next use hits harder.",
	"hud_hold": "Hold %s to power its next use with essence you carry.",
}


# --- which items have a pool, and how big --------------------------------------------------

static func _charms():
	return Charms


## An enchanted weapon's pool size (WEAPON "max"); 0 for anything else.
static func weapon_max(g) -> int:
	var row := _weapon_row(g)
	return int(row.get("max", 0))


## The essence one use of an enchanted weapon is worth (0 for anything else).
static func weapon_refill(g) -> int:
	return int(_weapon_row(g).get("refill", 0))


static func _weapon_row(g) -> Dictionary:
	var id := Gear.base_id(g)
	if not Weapons.WEAPONS.has(id) or id == "fists":
		return {}
	if Gear.enchant_kind(g) == "":
		return {}
	return WEAPON.get(String(Weapons.WEAPONS[id]["kind"]), {})


## Is this an essence item (a pool of its own)?
static func has_pool(g) -> bool:
	return g != null and Gear.is_gear(g) and cap(g) > 0


## Uses when full.
static func cap(g) -> int:
	return _charms().charge_max(g)


## Uses left (a record with none noted is full).
static func left(g) -> int:
	return _charms().charges(g)


## How full it is, 0 to 1 (1 for an item with no pool).
static func share(g) -> float:
	var most := cap(g)
	return 1.0 if most <= 0 else float(left(g)) / float(most)


## The essence one use is worth.
static func per_use(g) -> int:
	return _charms().refill_per(g)


## The item's own essence (its pool's kind).
static func kind(g) -> String:
	return _charms().kind(g)


# --- the essence you carry (gathered since the last stair, not yet banked) -----------------

static func carried(main) -> float:
	if main == null or not ("run_essence" in main):
		return 0.0
	var held := 0.0
	for k in main.run_essence:
		held += float(main.run_essence[k])
	return held


## Takes `amount` of the essence you carry: of `kind` first, then the rest
## from every other kind in its share. False (and nothing taken) if you
## carry too little.
static func take_carried(main, kind: String, amount: float) -> bool:
	if amount <= 0.0:
		return true
	if carried(main) + 0.001 < amount:
		return false
	var need := amount
	var own := float(main.run_essence.get(kind, 0.0))
	if own > 0.0:
		var t := minf(own, need)
		main.run_essence[kind] = own - t
		need -= t
	if need > 0.0:
		var rest := 0.0
		for k in main.run_essence:
			if k != kind:
				rest += float(main.run_essence[k])
		for k in main.run_essence.keys():
			if k != kind and rest > 0.0:
				main.run_essence[k] = maxf(0.0, float(main.run_essence[k]) - need * float(main.run_essence[k]) / rest)
	for k in main.run_essence.keys():
		if float(main.run_essence[k]) <= 0.001:
			main.run_essence.erase(k)
	return true


# --- using it ---------------------------------------------------------------------------------

## Could it fire its essence now (a use in its pool, or enough carried essence)?
static func can_use(main, g) -> bool:
	if not has_pool(g):
		return false
	return left(g) > 0 or carried(main) + 0.001 >= float(per_use(g))


## Draws one use: from its own pool first, else from the essence you carry.
## "pool", "carried", or "" (neither: its essence effect doesn't fire). A
## pool that runs dry says so once over the climber, and the first time the
## Entity explains. An heirloom's pool follows the climb's (keep_heirloom).
static func draw(main, g: Dictionary) -> String:
	if not has_pool(g):
		return ""
	var was := left(g)
	if was > 0:
		g["charge"] = was - 1
		keep_heirloom(main, g, was)
		if was - 1 <= 0 and main != null and main.get("player") != null:
			var p = main.player
			main.fx_text(p.global_position + Vector2(0, -60), TEXT["emptied"] % Gear.display(g), Color(0.95, 0.55, 0.42))
			main.tip("item_pool_empty")
		return "pool"
	if take_carried(main, kind(g), float(per_use(g))):
		return "carried"
	return ""


## A use with the power (if primed for this item): its multiplier (1.0 for
## a plain use, POWER "mult" powered), or 0.0 when it can't fire its
## essence. A powered use pays for itself if the pool and your carried
## essence are dry.
static func use(main, p, g: Dictionary) -> float:
	var mult := take_power(p, g)
	var how := draw(main, g)
	if how == "" and mult <= 1.0:
		return 0.0
	return mult


## A use of the weapon in a slot ("melee" or "ranged"): as use().
static func use_weapon(p, slot: String) -> float:
	var g = p.gear.get(slot, {})
	if not (g is Dictionary) or weapon_max(g) <= 0:
		return 0.0
	return use(p.main, p, g)


## A piece kept as an heirloom starts every climb as the heirloom is: so
## a use spent (or a pool refilled) on the climb is noted on the heirloom
## too, or it would come back full on its own. `was`: its uses before.
static func keep_heirloom(main, g: Dictionary, was: int) -> void:
	if main == null or main.get("profile") == null:
		return
	var hs := Gear.heirloom_slot(Gear.base_id(g))
	if hs == "":
		return
	var h = main.profile.heirlooms.get(hs, null)
	if not (h is Dictionary) or not Gear.same(h, g) or left(h) != was:
		return
	h["charge"] = left(g)
	main.profile.save()


# --- filtering: refill ---------------------------------------------------------------------

## What refilling its pool costs, in essence (less your renown's cut).
static func refill_cost(g, profile = null) -> int:
	return _charms().refill_amount(g, profile)


## Can you filter essence into an item here? "" if so, else why not: in a
## climb, not while a monster is after you (at a camp, always).
static func filter_why(main) -> String:
	if main == null:
		return ""
	if load(BODY_MOVE).hunted(main):
		return TEXT["filter_hunted"]
	return ""


## Refills a piece's pool from the essence you carry (any kind, each in its
## share). "" if done, else why not.
static func refill_carried(main, g: Dictionary) -> String:
	var amount := float(refill_cost(g, main.profile if main != null else null))
	if amount <= 0.0:
		return TEXT["pool_full"]
	var held := carried(main)
	if held + 0.001 < amount:
		return TEXT["filter_short"] % [int(amount), int(held)]
	for k in main.run_essence.keys():
		main.run_essence[k] = maxf(0.0, float(main.run_essence[k]) - amount * float(main.run_essence[k]) / held)
	var was := left(g)
	g["charge"] = cap(g)
	keep_heirloom(main, g, was)
	return ""


# --- filtering: power ---------------------------------------------------------------------

static func hold_time() -> float:
	return float(POWER["hold"])


## What holding the off-hand button would power: [slot, record] (the wand in
## a free off hand, else the enchanted weapon in hand, else an off-hand
## piece with a pool), or [] for nothing.
static func power_target(p) -> Array:
	if p == null:
		return []
	var Off = load("res://scripts/offhand.gd")
	var off: Dictionary = Off.piece(p)
	if Off.usable(p) and Off.use_of(off) == "wand" and has_pool(off):
		return ["offhand", off]
	for slot in ["melee", "ranged"]:
		var g = p.gear.get(slot, {})
		if g is Dictionary and p.weapon != "fists" and Gear.base_id(g) == String(p.weapon) and has_pool(g):
			return [slot, g]
	if Off.usable(p) and has_pool(off):
		return ["offhand", off]
	return []


## Is this item primed?
static func primed_for(p, g) -> bool:
	if p == null or not ("item_power" in p) or p.item_power.is_empty() or not (g is Dictionary) or g.is_empty():
		return false
	return String(p.item_power.get("code", "")) == Gear.code(g) and String(p.item_power.get("slot", "")) == Gear.slot_of(g)


## Takes the primed power for this item: POWER "mult", or 1.0 if none.
static func take_power(p, g) -> float:
	if not primed_for(p, g):
		return 1.0
	p.item_power = {}
	if "powered_uses" in p:
		p.powered_uses += 1  # (basic training watches for it: tutorial.gd)
	return float(POWER["mult"])


## Holding the off-hand button: primes the power target with essence you
## carry. Returns the slot primed ("" if nothing was: it says why).
static func prime(p) -> String:
	var m = p.main
	var t := power_target(p)
	var at: Vector2 = p.global_position + Vector2(0, -46)
	if t.is_empty():
		m.fx_text(at, TEXT["power_none"], Color(0.7, 0.68, 0.75))
		return ""
	var g: Dictionary = t[1]
	if primed_for(p, g):
		m.fx_text(at, TEXT["power_again"], Color(0.85, 0.8, 0.6))
		return ""
	var k := kind(g)
	if not take_carried(m, k, float(POWER["essence"])):
		m.fx_text(at, TEXT["power_short"], Color(0.95, 0.55, 0.42))
		m.sfx("ui_back", 0.8, -8.0)
		m.tip("item_power")
		return ""
	p.item_power = {"slot": Gear.slot_of(g), "code": Gear.code(g), "kind": k}
	var col := Essence.color(k) if Essence.KINDS.has(k) else Gear.color(g)
	m.fx_text(at, TEXT["powered"] % Gear.display(g), col)
	m.fx_ring(p.global_position, col, 34.0, 0.35, 3.0)
	m.sfx("charge", 1.3, -6.0)
	m.tip("item_power")
	return String(t[0])


# --- what the weapons do with a use ----------------------------------------------------------

static func edge(kind: String) -> Dictionary:
	return EDGE.get(kind, EDGE[EDGE_DEFAULT])


## A powered or plain finisher's edge on a foe it hit (`mult`: use()'s).
static func edge_hit(p, e, kind: String, mult: float, dmg: float, dir: Vector2) -> void:
	if e == null or not is_instance_valid(e) or e.dead:
		return
	var ed := edge(kind)
	var col := Essence.color(kind) if Essence.KINDS.has(kind) else Color.WHITE
	p.main.fx_burst(e.global_position, dir, col, 7, 200.0)
	if ed.has("stagger"):
		e.stagger(float(ed["stagger"]) * mult * (0.5 if e.is_boss() else 1.0))
	if ed.has("chill"):
		e.chill_t = maxf(e.chill_t, float(ed["chill"]) * mult)
	if ed.has("burn"):
		e.ignite(float(ed["burn"]) * mult, float(ed.get("burn_t", 3.0)))
	if ed.has("extra") or ed.has("push"):
		var push := float(ed.get("push", 0.0)) * mult
		e.take_hit(dmg * float(ed.get("extra", 0.0)) * mult, dir, 60.0 if e.is_boss() else push)


## A bow's full draw or a crossbow's bolt carrying its essence: the essence
## shot's rider when it strikes (player.gd _essence_shot_hit), and what it
## does as it flies (pierce, faster, shards: weapons.gd ESSENCE_SHOT).
static func shot_extras(p, shot, kind: String) -> void:
	if shot == null or not is_instance_valid(shot):
		return
	var es := Weapons.essence_shot(kind)
	var col := Essence.color(kind) if Essence.KINDS.has(kind) else Color.WHITE
	shot.shot = kind
	shot.tint = col
	if es.has("pierce"):
		shot.pierce = true
	if es.has("speed"):
		shot.vel *= float(es["speed"])
		shot.life *= float(es.get("life", 1.0))
	var n := int(es.get("shards", 1))
	if n > 1:
		var sh := float(es.get("share", 0.5))
		for i in [-1.0, 1.0]:
			var s = p.main.spawn_player_arrow(shot.position, shot.vel.rotated(i * float(es.get("fan", 0.15))), shot.dmg * sh, shot.force * sh, false)
			s.weapon = true
			s.fills = false  # (the shards are the weapon's essence, not your hand's)
			s.life = shot.life
			s.style = "blade"
			s.tint = col
	p.main.fx_burst(shot.position, shot.vel.normalized(), col, 6, 200.0)


# --- cards and bars ---------------------------------------------------------------------------

## An enchanted weapon's pool for its card: [[text, colour], ...] (charms and
## off-hand pieces have their own lines: charms.gd, offhand.gd).
static func weapon_lines(g) -> Array:
	var out: Array = []
	if weapon_max(g) <= 0:
		return out
	var k := Gear.enchant_kind(g)
	var col := Essence.color(k) if Essence.KINDS.has(k) else Gear.color(g)
	var full := left(g) >= cap(g)
	out.append([TEXT["pool"] % [left(g), cap(g)], Color(1.0, 0.86, 0.36) if full else Color(0.95, 0.55, 0.42)])
	var wk := String(Weapons.WEAPONS[Gear.base_id(g)]["kind"])
	match wk:
		"melee":
			var ed := edge(k)
			out.append([TEXT["edge"] % [ed["name"], ed["desc"]], col.lightened(0.2)])
		"bow", "crossbow":
			var es := Weapons.essence_shot(k)
			out.append([TEXT["shot" if wk == "bow" else "bolt"] % [es["name"], es["desc"]], col.lightened(0.2)])
		"gun":
			out.append([TEXT["gun_dry"], col.lightened(0.2)])
	out.append([TEXT["pool_full"] if full else (TEXT["pool_dry"] if left(g) <= 0 else TEXT["pool_note"]), Color(0.8, 0.78, 0.7)])
	return out


## The bar's colour: the item's essence.
static func bar_color(g) -> Color:
	var k := kind(g)
	return Essence.color(k) if Essence.KINDS.has(k) else Gear.color(g)


## A small flat bar of how full its pool is, into a Draw.Batch (the HUD,
## touch buttons). Flat, as every HUD bar: no shading.
static func bar_into(b, r: Rect2, g) -> void:
	if not has_pool(g):
		return
	b.rect(r.grow(1.0), Color(0, 0, 0, 0.7))
	b.rect(r, Color(0.16, 0.14, 0.2, 0.9))
	b.rect(Rect2(r.position, Vector2(r.size.x * share(g), r.size.y)), bar_color(g))


## The same, straight onto a CanvasItem (the inventory's and stash's slots).
static func draw_bar(c: CanvasItem, r: Rect2, g) -> void:
	if not has_pool(g):
		return
	c.draw_rect(r.grow(1.0), Color(0, 0, 0, 0.7))
	c.draw_rect(r, Color(0.16, 0.14, 0.2, 0.9))
	c.draw_rect(Rect2(r.position, Vector2(r.size.x * share(g), r.size.y)), bar_color(g))
