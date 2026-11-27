extends RefCounted
## THE OFF-HAND: the slot beside your weapons (the owner's call, from the
## old game: "a second one-handed weapon, a shield or a wand; enchanted
## off-hand items have their own essence pools for their powers").
##
## Three kinds of off-hand piece (USES "use"), each fitting the combat
## that's already there:
##   weapon  a second one-handed blade: it adds an OFF-HAND STRIKE to your
##           strike chains (just before the finisher), with its own numbers
##           ("strike", like a weapons.gd swing). Works with any one-handed
##           melee weapon and with your fists.
##   shield  HOLD PARRY TO BLOCK: once the parry window has passed, keep
##           holding parry and blows from in front are cut by "guard",
##           each one costing "guard_sta" stamina (too little and the guard
##           breaks: the blow lands whole and you stagger). You walk at
##           "guard_walk" while guarding. A parry is still the skilful
##           answer: it takes nothing and gives stamina back.
##   wand    THE OFF-HAND BUTTON (U or the middle mouse button, the left
##           stick pressed in on a controller, the Off-hand button on a
##           phone) casts its small essence power from the wand's own pool.
## Two-handed weapons (TWO_HANDS: the greatsword, war hammer and spear) and
## bows and crossbows (the sling too, a bow by kind) need both hands: while
## one is in hand the off-hand is put away (its traits still count, like any
## worn piece's): no off-hand strike, no block, no wand (ready_use is ""),
## and it isn't drawn in the hand. One-handed weapons, pistols and the fists
## leave it free. The HUD shows it as a coin at the weapon slot's corner,
## dimmed and struck through while it's put away, its card saying why; the
## first time it happens in a climb the Entity explains (tip "two_hands").
##
## ENCHANTED off-hand pieces (the Ember Dirk, the Tide Ward and every wand)
## have their OWN ESSENCE POOL for their power: a few uses (gear.gd PIECES
## "charge", whose numbers live in charms.gd CHARGES with the charms'),
## spent as the power fires (the pool first, then the essence you carry:
## item_pool.gd, the rule every essence item follows) and refilled exactly
## as a charm's charge is: in the tower from the inventory, with essence you
## carry; on the train at the workshop bench's Charms counter, with crystals
## of its kind; dry, with none carried, the tower seeps a use back, slowly
## (item_pool.gd REGEN). Holding the off-hand button
## powers the next use (a wand casts at once, powered: item_pool.gd POWER).
##
## The pieces themselves (names, slots, colours, how common) are gear.gd
## PIECES (slot "offhand"); what each does in a fight is here. Names, words
## and numbers are plain data, easy to change.

const Gear := preload("res://scripts/gear.gd")
const Weapons := preload("res://scripts/weapons.gd")
const Charms := preload("res://scripts/charms.gd")
const Essence := preload("res://scripts/essence.gd")
const Art := preload("res://scripts/icon_art.gd")
const Palette := preload("res://scripts/palette.gd")
const ItemPool := preload("res://scripts/item_pool.gd")
const OutfitterName := preload("res://scripts/outfitter_name.gd")

## Weapons that need both hands (and every bow and crossbow, by kind).
static var TWO_HANDS := ["greatsword", "war_hammer", "spear"]

## What each off-hand piece does (gear.gd PIECES has its name and look):
##   use        "weapon", "shield" or "wand"
##   strike     an off-hand weapon's strike (as a weapons.gd swing: dmg on
##              the base strike, range, arc, sta, recover, lunge, knock, and
##              "style": "stab" or "arc")
##   guard      a shield: the share of a blow from in front it takes off
##   guard_sta  ...the stamina each blocked blow costs
##   guard_walk ...how fast you walk while guarding
##   sta, cd    a wand: the stamina a cast costs, the seconds before the next
static var USES := {
	"parrying_dagger": {"use": "weapon", "strike": {"dmg": 0.55, "range": 36.0, "arc": 35.0, "sta": 6.0, "recover": 0.2, "lunge": 150.0, "knock": 60.0, "style": "stab"}},
	"hand_axe": {"use": "weapon", "strike": {"dmg": 0.85, "range": 40.0, "arc": 50.0, "sta": 9.0, "recover": 0.28, "lunge": 160.0, "knock": 120.0, "style": "arc"}},
	"ember_dirk": {"use": "weapon", "strike": {"dmg": 0.6, "range": 36.0, "arc": 35.0, "sta": 6.0, "recover": 0.2, "lunge": 150.0, "knock": 70.0, "style": "stab"}},
	"buckler": {"use": "shield", "guard": 0.45, "guard_sta": 8.0, "guard_walk": 0.75},
	"kite_shield": {"use": "shield", "guard": 0.75, "guard_sta": 12.0, "guard_walk": 0.55},
	"tide_ward": {"use": "shield", "guard": 0.55, "guard_sta": 9.0, "guard_walk": 0.7},
	"cairn_wand": {"use": "wand", "sta": 6.0, "cd": 0.8},
	"edge_wand": {"use": "wand", "sta": 6.0, "cd": 0.8},
	"iron_wand": {"use": "wand", "sta": 6.0, "cd": 1.2},
	"gale_wand": {"use": "wand", "sta": 6.0, "cd": 0.8},
	"cinder_wand": {"use": "wand", "sta": 6.0, "cd": 0.8},
	"tide_wand": {"use": "wand", "sta": 6.0, "cd": 0.8},
}
## How guarding works: a blow counts as "in front" when it comes from
## within this dot of your aim; a broken guard staggers you this long;
## stamina waits this long after a block.
static var RULES := {"front": 0.0, "break_stagger": 0.5, "sta_wait": 0.6, "wear_strike": 0.0008, "wear_block": 0.008}

## The words: the cards, the floating lines, the inventory.
static var TEXT: Dictionary = OutfitterName.named({
	"uses": {"weapon": "Off-hand weapon", "shield": "Shield", "wand": "Wand"},
	"use_weapon": "Off-hand strike: adds a %s to your strike chains, just before the finisher (one-handed weapons and fists)",
	"use_shield": "Hold parry to block: blows from in front hurt %s less, %d stamina each; you walk slower while guarding",
	"use_wand": "%s (the off-hand button): %s",
	"stab": "quick stab",
	"arc": "short chop",
	"two_hands": "Put away while a two-handed weapon or a bow is in hand",
	"pool": "Essence pool · %d of %d uses",
	"pool_line": "%s: %s",
	"pool_refill": "Used first; dry, a use draws on the essence you carry. Spent uses come back when you filter essence in (%d a use): the inventory in the tower, or the workshop bench's Charms counter. Carry none, and the tower seeps a use back, slowly.",
	"pool_full": "Its pool is full.",
	"blocked": "Blocked",
	"guard_broken": "Guard broken",
	"no_pool": "%s: its pool is dry, and you carry too little essence",
	"put_away": "Off-hand put away: both hands are busy",
	"hud_away": "Put away: your %s needs both hands. Swap to a one-handed weapon or your fists to use it.",
	"hud_ready": "Ready: the weapon in your hand leaves this hand free.",
	"no_wand": "No wand in your off-hand",
	"stat_strike": "Off-hand strike", "stat_guard": "Block", "stat_guard_sta": "Block stamina", "stat_uses": "Pool uses",
	"empty": "Your off-hand: a second one-handed weapon (an extra strike in your chains), a shield (hold parry to block) or a wand (a small power from its own pool). Slain monsters, vaults and {outfitter} have them.",
	"where": "Off-hand",
	"button": "Off-hand",
})


# --- what's in the off-hand -------------------------------------------------------------

## The off-hand piece a climber wears (a record), or {}.
static func piece(p) -> Dictionary:
	if p == null or not ("gear" in p):
		return {}
	var g = p.gear.get("offhand", {})
	return g if g is Dictionary and Gear.is_gear(g) and Gear.slot_of(g) == "offhand" else {}


## "weapon", "shield" or "wand" ("" for nothing or something unknown).
static func use_of(g) -> String:
	return String(USES.get(Gear.base_id(g), {}).get("use", ""))


static func data(g) -> Dictionary:
	return USES.get(Gear.base_id(g), {})


## Does this weapon need both hands (or is it a bow or crossbow)?
static func two_handed(id: String) -> bool:
	if id in TWO_HANDS:
		return true
	var w: Dictionary = Weapons.WEAPONS.get(id, {})
	return String(w.get("kind", "")) in ["bow", "crossbow"]


## The off-hand piece can be used now (worn, and the weapon in hand leaves the hand free).
static func usable(p) -> bool:
	return not piece(p).is_empty() and not two_handed(String(p.weapon)) and not p.dead


## The off-hand's use, if it can be used now ("" if not).
static func ready_use(p) -> String:
	return use_of(piece(p)) if usable(p) else ""


# --- the pool (an enchanted piece's own essence) --------------------------------------------

static func has_pool(g) -> bool:
	return Charms.charge_max(g) > 0


static func pool(g) -> int:
	return Charms.charges(g)


static func pool_max(g) -> int:
	return Charms.charge_max(g)


## The power's numbers (charms.gd CHARGES).
static func power(g) -> Dictionary:
	return Charms.CHARGES.get(Charms.charge_id(g), {})


## Spends one use of the worn piece: its own pool first, then the essence
## you carry (item_pool.gd draw; kept on an heirloom too). True if it fired.
static func spend(p) -> bool:
	var g := piece(p)
	if g.is_empty():
		return false
	return ItemPool.draw(p.main, g) != ""


## A use of the worn piece with the power if it's primed (item_pool.gd use):
## its multiplier, or 0.0 when it can't fire.
static func _use(p) -> float:
	var g := piece(p)
	if g.is_empty():
		return 0.0
	return ItemPool.use(p.main, p, g)


## Refills the worn off-hand's pool in the tower from the essence you carry (as a charm). "" if done.
static func refill_unbanked(main, g: Dictionary) -> String:
	return Charms.refill_unbanked(main, g)  # (an heirloom follows: item_pool.gd keep_heirloom)


# --- the card ---------------------------------------------------------------------------

## What the off-hand piece does, for a card's plain lines (gear.gd describe).
static func use_lines(g) -> Array:
	var out: Array = []
	var d := data(g)
	match String(d.get("use", "")):
		"weapon":
			out.append(TEXT["use_weapon"] % TEXT[String(d["strike"].get("style", "stab"))] + ".")
		"shield":
			out.append(TEXT["use_shield"] % [Gear.amount_text(float(d["guard"])), int(d["guard_sta"])] + ".")
		"wand":
			var pw := power(g)
			out.append(TEXT["use_wand"] % [pw.get("name", ""), pw.get("desc", "")] + ".")
	out.append(TEXT["two_hands"] + ".")
	return out


## An enchanted off-hand piece's own pool, for its card's enchantment lines
## (gear.gd trait_lines): [[text, colour], ...]; none for an ordinary piece.
static func card_lines(g) -> Array:
	var out: Array = []
	if not has_pool(g):
		return out
	var d := data(g)
	var col := Gear.color(g).lightened(0.25)
	var full := Charms.missing(g) <= 0
	var pw := power(g)
	out.append([TEXT["pool"] % [pool(g), pool_max(g)], Color(1.0, 0.86, 0.36) if full else Color(0.95, 0.55, 0.42)])
	if String(d.get("use", "")) != "wand":
		out.append([TEXT["pool_line"] % [pw.get("name", ""), pw.get("desc", "")], col])
	out.append([TEXT["pool_full"] if full else TEXT["pool_refill"] % int(pw.get("refill", 0)), Color(0.8, 0.78, 0.7)])
	out.append([ItemPool.regen_line(g), Color(0.72, 0.7, 0.66)])
	return out


## Rows for the card's numbers and for comparing (gear.gd stats).
static func stat_rows(id) -> Array:
	var d := data(id)
	var rows: Array = []
	match String(d.get("use", "")):
		"weapon":
			var dm := float(d["strike"]["dmg"]) * Weapons.BASE * Gear.weapon_boost(id)
			rows.append([TEXT["stat_strike"], "%d" % int(round(dm)), dm, true, ""])
		"shield":
			rows.append([TEXT["stat_guard"], Gear.amount_text(float(d["guard"])), float(d["guard"]), true, ""])
			rows.append([TEXT["stat_guard_sta"], "%d" % int(d["guard_sta"]), float(d["guard_sta"]), false, ""])
	if has_pool(id):
		rows.append([TEXT["stat_uses"], "%d" % pool_max(id), float(pool_max(id)), true, ""])
	return rows


# --- the off-hand strike ----------------------------------------------------------------

## The chain the climber strikes with: the weapon's own, with the off-hand
## weapon's strike put in just before the finisher.
static func chain(p, base: Array) -> Array:
	if ready_use(p) != "weapon" or base.size() < 2 or String(p.wkind()) != "melee":
		return base
	var s: Dictionary = data(piece(p))["strike"].duplicate()
	s["offhand"] = true
	s["heavy"] = false
	var last: Dictionary = base[base.size() - 1]
	s["side"] = -float(last.get("side", 1.0))
	var out: Array = base.slice(0, base.size() - 1)
	out.append(s)
	out.append(last)
	return out


## The off-hand strike's damage multiplier: the piece's rarity and rank, less its wear.
static func strike_power(p) -> float:
	return Gear.weapon_power(piece(p))


## An off-hand strike landed on a foe: the Ember Dirk's pool sets it burning.
static func struck(p, e) -> void:
	var g := piece(p)
	var mult := _use(p) if Charms.charge_id(g) == "ember_strike" and not e.dead else 0.0
	if mult > 0.0:
		var pw := power(g)
		e.ignite(float(pw.get("dmg", 3.0)) * mult, float(pw.get("time", 3.0)))
		p.main.fx_burst(e.global_position, Vector2.UP, Color(1.0, 0.55, 0.25), 6, 160.0)
	_wear(p, float(RULES["wear_strike"]))
	load("res://scripts/deeds.gd").note(p.main, "off_strikes")


## A Common off-hand piece wears as it's used.
static func _wear(p, amount: float) -> void:
	var g := piece(p)
	if not Gear.wears(g):
		return
	g["wear"] = maxf(0.0, float(g["wear"]) - amount)
	if float(g["wear"]) <= 0.0:
		p._break_gear("offhand")


# --- the shield --------------------------------------------------------------------------

## Is parry held (or a test holding it for you)?
static func guard_held(p) -> bool:
	return bool(p.get("guard_force")) or Input.is_action_pressed("parry")


## Guarding now: a shield in a free hand, parry held past its window,
## and nothing else under way.
static func guarding(p) -> bool:
	return ready_use(p) == "shield" and guard_held(p) and p.parry_t <= 0.0 and p.roll_t <= 0.0 and p.attack_cd <= 0.0 \
		and p.cast_t <= 0.0 and p.jump_t <= 0.0


## A blow on a guarding climber: what's left of it (-1.0 when not blocked).
static func block(p, dmg: float, source) -> float:
	if not guarding(p) or source == null or not is_instance_valid(source) or not ("global_position" in source):
		return -1.0
	var to: Vector2 = (source.global_position - p.global_position).normalized()
	if p.aim.dot(to) < float(RULES["front"]):
		return -1.0
	var g := piece(p)
	var d := data(g)
	var cost := float(d["guard_sta"])
	var m = p.main
	if p.sta < cost:
		# Too little stamina: the guard breaks, the blow lands whole.
		p.sta = 0.0
		p.sta_delay = float(RULES["sta_wait"]) * 2.0
		p.attack_cd = maxf(p.attack_cd, float(RULES["break_stagger"]))  # (staggered: no strike, no parry for a moment)
		m.fx_text(p.global_position + Vector2(0, -34), TEXT["guard_broken"], Color(1.0, 0.55, 0.4))
		m.sfx("hit_armor", 0.7, -2.0)
		return dmg
	p.sta -= cost
	p.sta_delay = float(RULES["sta_wait"])
	var left := dmg * (1.0 - float(d["guard"]))
	m.fx_text(p.global_position + Vector2(0, -30), TEXT["blocked"], Color(0.85, 0.78, 0.6))
	m.fx_ring(p.global_position + p.aim * 14.0, Gear.color(g), 22.0, 0.2, 3.0)
	m.sfx("hit_armor", 1.0, -2.0)
	p.off_flash = 0.2
	_wear(p, float(RULES["wear_block"]))
	load("res://scripts/deeds.gd").note(m, "blocks")
	if "blocked" in p:
		p.blocked += 1  # (basic training watches for it: tutorial.gd)
	# The Tide Ward: a blocked blow sends a wave out, from its pool.
	var mult := _use(p) if Charms.charge_id(g) == "tide_block" else 0.0
	if mult > 0.0:
		var pw := _scaled(power(g), mult)
		var r := float(pw.get("radius", 110.0))
		m.fx_ring(p.global_position, Color(0.45, 0.78, 0.95), r, 0.4, 5.0)
		for e in m.targets():
			var away: Vector2 = e.global_position - p.global_position
			if not e.dead and away.length() < r + e.radius:
				e.take_hit(float(pw.get("dmg", 4.0)), away.normalized(), float(pw.get("push", 480.0)))
	return left


## Walking speed while guarding.
static func walk_mult(p) -> float:
	if not guarding(p):
		return 1.0
	return float(data(piece(p)).get("guard_walk", 1.0))


# --- the wand ----------------------------------------------------------------------------

## The off-hand button: a wand casts its power from its pool. Always "spent"
## (true): a refusal says why over the climber.
static func cast(p) -> bool:
	var m = p.main
	var g := piece(p)
	if use_of(g) != "wand":
		var t := ItemPool.power_target(p)
		if not t.is_empty():
			# (an essence item to power: a tap only says how)
			m.fx_text(p.global_position + Vector2(0, -40), ItemPool.TEXT["power_hint"] % Gear.display(t[1]), Color(0.85, 0.8, 0.6))
			m.tip("item_power")
			return true
		if not g.is_empty() and use_of(g) == "shield":
			return true  # (a shield blocks with parry held: nothing to cast)
		m.fx_text(p.global_position + Vector2(0, -40), TEXT["no_wand"], Color(0.7, 0.68, 0.75))
		return true
	if not usable(p):
		m.fx_text(p.global_position + Vector2(0, -40), TEXT["put_away"], Color(0.7, 0.68, 0.75))
		return true
	if p.off_cd > 0.0:
		return false  # (soon: it stays buffered a moment)
	# Its own pool first, then the essence you carry (item_pool.gd); powered,
	# the essence filtered in pays for itself.
	if not ItemPool.can_use(m, g) and not ItemPool.primed_for(p, g):
		m.fx_text(p.global_position + Vector2(0, -40), TEXT["no_pool"] % Gear.display(g), Color(0.95, 0.55, 0.42))
		m.sfx("denied", 0.8, -8.0)
		return true
	if not p.spend_sta(float(data(g).get("sta", 6.0))):
		p._winded()
		return true
	var mult := _use(p)
	if mult <= 0.0:
		return true
	p.off_cd = float(data(g).get("cd", 0.8))
	p.off_flash = 0.3
	_power(p, Charms.charge_id(g), _scaled(power(g), mult))
	load("res://scripts/deeds.gd").note(m, "wand_casts")
	return true


## A power's numbers, `mult` times as strong (a powered use: item_pool.gd POWER).
static func _scaled(pw: Dictionary, mult: float) -> Dictionary:
	if mult == 1.0:
		return pw
	var out := pw.duplicate()
	for k in ["dmg", "shield", "push", "burn", "chill", "stagger"]:
		if out.has(k):
			out[k] = float(out[k]) * mult
	return out


## What each wand does.
static func _power(p, id: String, pw: Dictionary) -> void:
	var m = p.main
	var spell := 1.0 + float(p.gfx("spell"))  # (of Kindling, an Ember Charm: spells hit harder)
	var at: Vector2 = p.global_position + p.aim * (p.radius + 8.0)
	var kind := String(id).trim_prefix("wand_")
	var col := Essence.color(kind) if Essence.KINDS.has(kind) else Color.WHITE
	m.fx_burst(at, p.aim, col, 8, 220.0)
	m.light_flash(at, col, 0.9, 1.4, 0.15)
	match id:
		"wand_stone", "wand_fire", "wand_water":
			var shot = m.spawn_player_arrow(at, p.aim * float(pw.get("speed", 540.0)), float(pw.get("dmg", 8.0)) * spell, 160.0, false)
			shot.style = "essence"
			shot.tint = col
			shot.life = 1.2
			shot.heavy = id == "wand_stone"
			shot.on_strike.append(_wand_hit.bind(id, pw))
			m.sfx({"wand_stone": "spell_stone", "wand_fire": "spell_fire", "wand_water": "spell_frost"}[id], 1.1, -4.0)
		"wand_blade":
			var n := int(pw.get("shards", 3))
			for i in n:
				var off := lerpf(-1.0, 1.0, float(i) / float(maxi(1, n - 1))) * float(pw.get("fan", 0.22))
				var shard = m.spawn_player_arrow(at, p.aim.rotated(off) * float(pw.get("speed", 640.0)), float(pw.get("dmg", 6.0)) * spell, 90.0, false)
				shard.style = "blade"
				shard.tint = col
				shard.life = 0.8
			m.sfx("spell_blade", 1.2, -4.0)
		"wand_iron":
			p.raise_barrier(float(pw.get("shield", 20.0)), float(pw.get("time", 6.0)), false, col)
			m.sfx("spell_iron", 1.1, -4.0)
		"wand_air":
			var reach := float(pw.get("reach", 130.0))
			m.fx_cone(p.global_position, p.aim, reach, deg_to_rad(float(pw.get("half", 40.0))), col)
			for e in m.targets():
				var to: Vector2 = e.global_position - p.global_position
				if not e.dead and to.length() < reach + e.radius and absf(p.aim.angle_to(to)) < deg_to_rad(float(pw.get("half", 40.0))):
					e.take_hit(float(pw.get("dmg", 4.0)) * spell, to.normalized(), float(pw.get("push", 520.0)))
			m.sfx("spell_wind", 1.0, -2.0)


## A wand's bolt landed.
static func _wand_hit(_shot, e, id: String, pw: Dictionary) -> void:
	if e == null or not is_instance_valid(e) or e.dead:
		return
	match id:
		"wand_stone":
			e.stagger(float(pw.get("stagger", 0.6)) * (0.5 if e.is_boss() else 1.0))
		"wand_fire":
			e.ignite(float(pw.get("burn", 3.0)), float(pw.get("burn_t", 3.0)))
		"wand_water":
			e.chill_t = maxf(e.chill_t, float(pw.get("chill", 2.0)))


## Timers (player.gd _tick_timers).
static func tick(p, delta: float) -> void:
	p.off_cd = maxf(0.0, p.off_cd - delta)
	p.off_flash = maxf(0.0, p.off_flash - delta)
	# The first time a two-handed weapon puts a worn off-hand away: the Entity says why.
	if not p.has_meta("two_told") and not piece(p).is_empty() and two_handed(String(p.weapon)) and p.main != null and p.main.get("player") == p and not bool(p.main.get("on_train")):
		p.set_meta("two_told", true)
		p.main.tip("two_hands")
	# The first time an off-hand piece is worn in a climb: the Entity explains it.
	if not p.has_meta("off_told") and not piece(p).is_empty() and p.main != null and p.main.get("player") == p and not bool(p.main.get("on_train")):
		p.set_meta("off_told", true)
		p.main.tip("offhand")


# --- drawn on the climber ------------------------------------------------------------------

## In the tower (player.gd _draw_weapon): moves the off hand for a guard or
## an off-hand strike, and returns how to draw the piece in it (an empty
## Callable when there's nothing to draw).
static func tower_hand(p, b, hands: Array, sh_o: Vector2, free: Vector2, dir: Vector2, side: Vector2) -> Callable:
	var g := piece(p)
	if g.is_empty() or two_handed(String(p.weapon)):
		return Callable()
	var i := -1
	for k in hands.size():
		if (hands[k][0] as Vector2).is_equal_approx(sh_o):
			i = k
	if i < 0:
		return Callable()
	var jab := String(p.wdata().get("style", "")) == "jab"
	if not jab and not (hands[i][1] as Vector2).is_equal_approx(free):
		return Callable()  # (the hand is busy: a sheath, a reload)
	var use := use_of(g)
	var col := Gear.color(g)
	var hand: Vector2 = hands[i][1]
	match use:
		"weapon":
			var ext := 0.0
			if p.swing_t > 0.0 and p.swing.get("offhand", false):
				var k2: float = 1.0 - p.swing_t / float(p.wdata()["swing_time"])
				ext = sin(PI * minf(1.0, k2 * 1.3))
			hand = hand.lerp(dir * float(p.swing.get("range", 36.0)) * 0.6 - side * 3.0, ext)
			hands[i][1] = hand
			var id := Gear.base_id(g)
			var along := dir.rotated(-0.25 * (1.0 - ext))
			return func():
				if id == "hand_axe":
					var head := hand + along * 11.0
					b.stroke(hand - along * 2.0, head + along * 2.0, Palette.WOOD, 2.2)
					b.poly(PackedVector2Array([head - along * 3.0 - along.orthogonal() * 1.0, head + along * 3.0 - along.orthogonal() * 1.0,
						head + along * 4.0 - along.orthogonal() * 6.0, head - along * 4.0 - along.orthogonal() * 6.0]), Palette.STEEL.darkened(0.1), 1.0)
				else:
					b.sword(hand, along, 11.0, 1.0 if ext > 0.0 else 0.0)
					if id == "ember_dirk":
						b.circle(hand + along * 9.0, 2.6, Color(1.0, 0.5, 0.2, 0.45))
		"shield":
			var up := guarding(p)
			if up:
				hand = dir * (p.radius * 0.95) - side * 3.0
				hands[i][1] = hand
			var flash: float = p.off_flash
			var id2 := Gear.base_id(g)
			return func():
				var c: Vector2 = hand + (dir * 3.0 if up else -side * 2.0)
				var n := dir.orthogonal()
				var rx := 3.0
				var ry := 7.5 if id2 != "kite_shield" else 9.5
				var pts := PackedVector2Array()
				for a in 16:
					var t := TAU * a / 16.0
					pts.append(c + dir * cos(t) * rx + n * sin(t) * ry)
				b.poly(pts, col, 1.4)
				b.line(c + n * ry * 0.8, c - n * ry * 0.8, Color(col.lightened(0.35), 0.8), 1.0)
				b.circle(c + dir * 1.2, 1.8, Palette.STEEL.lightened(0.1))
				if flash > 0.0:
					b.circle(c + dir * 2.0, ry + 2.0, Color(1, 1, 0.85, flash * 1.5))
		"wand":
			var flash2: float = p.off_flash
			var kind := Gear.enchant_kind(g)
			var glow := Essence.color(kind) if kind != "" else Color.WHITE
			var along2 := dir.rotated(-0.3)
			return func():
				var tip := hand + along2 * 12.0
				b.stroke(hand - along2 * 2.0, tip, Palette.OUTLINE, 3.4)
				b.stroke(hand - along2 * 2.0, tip, col.lightened(0.15), 1.8)
				b.circle(tip, 4.5 + flash2 * 8.0, Color(glow, 0.3))
				b.circle(tip, 2.6 + flash2 * 3.0, Palette.OUTLINE)
				b.circle(tip, 2.0 + flash2 * 3.0, glow)
	return Callable()


## On the front figure (gear_look.gd front_arms): the off-hand piece in the
## figure's left hand (on the viewer's right). `after_glove`: a blade's
## grip goes under the glove, a shield over it.
static func front(b, lk: Dictionary, after_glove: bool) -> void:
	var id := String(lk.get("offhand", ""))
	if id == "":
		return
	var use := String(USES.get(id, {}).get("use", ""))
	var col: Color = lk.get("offhand_col", Palette.STEEL)
	var edge: Color = lk.get("offhand_edge", Color(0, 0, 0, 0))
	var hand := Vector2(50, 9)
	if use == "shield":
		if not after_glove:
			return
		var c := hand + Vector2(6, 6)
		var pts := PackedVector2Array()
		if id == "kite_shield":
			for v in [Vector2(-16, -22), Vector2(16, -22), Vector2(18, -6), Vector2(0, 34), Vector2(-18, -6)]:
				pts.append(c + v)
		else:
			var r := 20.0 if id == "buckler" else 24.0
			for a in 24:
				pts.append(c + Vector2.from_angle(TAU * a / 24.0) * r)
		if edge.a > 0.0:
			b.polygon(pts, Color(edge, 0.3))
		b.poly(pts, col, 2.0)
		var inner := PackedVector2Array()
		for q in pts:
			inner.append(c + (q - c) * 0.78)
		b.path(inner, Color(col.lightened(0.3), 0.7), 1.4, true)
		b.ball(c, 4.5, Palette.STEEL.lightened(0.1), true)
		if id == "tide_ward":
			for k in 3:
				var y := -8.0 + k * 8.0
				b.path(PackedVector2Array([c + Vector2(-12, y), c + Vector2(-6, y - 3), c + Vector2(0, y), c + Vector2(6, y - 3), c + Vector2(12, y)]), Color(0.75, 0.95, 1.0, 0.8), 1.4)
		return
	if after_glove:
		return
	match use:
		"weapon":
			var tip := hand + Vector2(8, 38 if id != "hand_axe" else 30)
			if edge.a > 0.0:
				b.line(hand + Vector2(1, 6), tip, Color(edge, 0.35), 8.0)
			if id == "hand_axe":
				b.stroke(hand + Vector2(-1, -6), tip, Palette.WOOD.darkened(0.15), 3.6)
				b.poly(PackedVector2Array([tip + Vector2(-2, -14), tip + Vector2(14, -20), tip + Vector2(16, -2), tip + Vector2(-2, -4)]), Palette.STEEL, 1.3)
			else:
				b.poly(PackedVector2Array([hand + Vector2(-2.5, 6), hand + Vector2(3.5, 6), tip]), col if id == "ember_dirk" else Palette.STEEL, 1.2)
				b.stroke(hand + Vector2(-8, 5), hand + Vector2(8, 5), Palette.STEEL.darkened(0.35), 2.6)
				if id == "ember_dirk":
					b.circle(tip + Vector2(-2, -8), 6.0, Color(1.0, 0.5, 0.2, 0.3))
		"wand":
			var kind := String(Gear.PIECES.get(id, {}).get("kind", ""))
			var glow := Essence.color(kind) if kind != "" else Color.WHITE
			var top := hand + Vector2(10, -34)
			b.stroke(hand + Vector2(-2, 10), top, Palette.OUTLINE, 5.0)
			b.stroke(hand + Vector2(-2, 10), top, col.darkened(0.1), 3.2)
			b.circle(top, 7.0, Color(glow, 0.3))
			b.ball(top, 3.2, glow, true)


# --- the icon -------------------------------------------------------------------------------

## The piece's icon (gear.gd _piece_icon): a dagger, a hand axe, a dirk, a
## round buckler, a kite shield, a round ward with waves, and six wands
## told apart by their tips.
static func icon_into(b, id: String, c: Vector2, s: float, col: Color) -> void:
	var u := Art.unit(s)
	var P := func(arr: Array) -> PackedVector2Array: return Art.pts(c, u, arr)
	match id:
		"parrying_dagger", "ember_dirk":
			var blade: PackedVector2Array
			blade = P.call([Vector2(0, -9.6), Vector2(1.8, -7.0), Vector2(1.6, 2.0), Vector2(-1.6, 2.0), Vector2(-1.8, -7.0)])
			Art.shape(b, blade, Art.STEEL if id == "parrying_dagger" else col, s, "metal")
			Art.rod(b, c + Vector2(-5.2, 2.8) * u, c + Vector2(5.2, 2.8) * u, 1.2 * u, Art.GOLD if id == "ember_dirk" else Art.STEEL.darkened(0.2), s, "metal")
			if id == "parrying_dagger":
				Art.arc_rod(b, c + Vector2(0, 4.4) * u, 3.6 * u, PI * 0.1, PI * 0.9, 0.8 * u, Art.STEEL.darkened(0.1), s, "metal")
			Art.rod(b, c + Vector2(0, 3.6) * u, c + Vector2(0, 8.4) * u, 1.3 * u, Color(0.42, 0.28, 0.2), s, "leather")
			Art.orb(b, c + Vector2(0, 9.0) * u, 1.3 * u, Art.STEEL, s, "metal")
			if id == "ember_dirk":
				Art.soft(b, c + Vector2(0, -4.0) * u, 6.0 * u, Color(1.0, 0.5, 0.2, 0.35))
		"hand_axe":
			Art.rod(b, c + Vector2(-3.4, 8.6) * u, c + Vector2(2.4, -7.6) * u, 1.3 * u, Color(0.5, 0.34, 0.22), s, "wood")
			var head: PackedVector2Array = P.call([Vector2(1.0, -8.4), Vector2(7.8, -9.6), Vector2(8.6, -2.6), Vector2(1.4, -3.6)])
			Art.shape(b, head, col, s, "metal")
		"buckler", "tide_ward":
			var r := 8.0 if id == "buckler" else 8.8
			Art.orb(b, c, r * u, col, s, "metal" if id == "buckler" else "gem")
			b.arc(c, r * 0.72 * u, 0.0, TAU, 20, Color(col.lightened(0.3), 0.8), maxf(0.6, 0.6 * u))
			Art.orb(b, c, 2.2 * u, Art.STEEL, s, "metal")
			if id == "tide_ward":
				for k in 2:
					var y := -3.6 + k * 6.6
					b.polyline(P.call([Vector2(-5.4, y), Vector2(-2.6, y - 1.4), Vector2(0, y), Vector2(2.6, y - 1.4), Vector2(5.4, y)]), Color(0.8, 0.96, 1.0, 0.85), maxf(0.6, 0.55 * u))
		"kite_shield":
			var kite: PackedVector2Array = P.call([Vector2(-7.0, -8.6), Vector2(7.0, -8.6), Vector2(7.8, -2.4), Vector2(0, 9.6), Vector2(-7.8, -2.4)])
			Art.shape(b, kite, col, s, "metal")
			b.line(c + Vector2(0, -7.6) * u, c + Vector2(0, 7.6) * u, Color(col.lightened(0.35), 0.8), maxf(0.6, 0.6 * u))
			b.line(c + Vector2(-6.4, -3.0) * u, c + Vector2(6.4, -3.0) * u, Color(col.lightened(0.35), 0.8), maxf(0.6, 0.6 * u))
			Art.rivet(b, c + Vector2(0, -3.0) * u, 1.1 * u, Art.STEEL)
		_:
			# A wand: a slim rod, its tip in its essence.
			var kind := String(Gear.PIECES.get(id, {}).get("kind", ""))
			var glow := Essence.color(kind) if kind != "" else col
			Art.rod(b, c + Vector2(-5.4, 8.4) * u, c + Vector2(4.2, -6.0) * u, 1.2 * u, col, s, "wood")
			Art.rod(b, c + Vector2(-5.0, 7.6) * u, c + Vector2(-3.4, 5.2) * u, 1.5 * u, Art.GOLD, s, "gold")
			var tip := c + Vector2(4.8, -7.0) * u
			Art.soft(b, tip, 5.0 * u, Color(glow, 0.45))
			match kind:
				"stone":
					Art.shape(b, P.call([Vector2(3.0, -9.6), Vector2(6.8, -8.0), Vector2(6.6, -4.6), Vector2(3.4, -4.0), Vector2(2.4, -6.6)]), glow, s, "stone")
				"blade":
					Art.shape(b, P.call([Vector2(4.8, -11.0), Vector2(6.6, -7.0), Vector2(4.8, -3.6), Vector2(3.0, -7.0)]), glow, s, "metal")
				"iron":
					Art.orb(b, tip, 2.6 * u, glow, s, "metal")
					for k in 4:
						Art.rivet(b, tip + Vector2.from_angle(TAU * k / 4.0) * 3.2 * u, 0.6 * u, Art.STEEL)
				"air":
					Art.feather(b, tip + Vector2(-1.0, 2.0) * u, tip + Vector2(3.0, -4.4) * u, 2.2 * u, glow, s)
				"fire":
					Art.flame(b, tip, 3.0 * u, s)
				_:
					Art.orb(b, tip, 2.4 * u, glow, s, "gem")
					Art.shine(b, tip + Vector2(-0.6, -0.8) * u, 0.5 * u, 0.9 * u, -0.6, 0.7)
