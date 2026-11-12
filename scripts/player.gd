extends CharacterBody2D
## The climber. Without bonds it is clumsy, slow and weak.
## Bonds fill through what their body part does, and enhance the body.

const BondScript := preload("res://scripts/bond.gd")
const Bonds := preload("res://scripts/bonds.gd")
const Weapons := preload("res://scripts/weapons.gd")
const Palette := preload("res://scripts/palette.gd")
const Draw := preload("res://scripts/draw_util.gd")
const Items := preload("res://scripts/items.gd")
const Gear := preload("res://scripts/gear.gd")
const Secret := preload("res://scripts/secret.gd")
const Appearance := preload("res://scripts/appearance.gd")
const Makers := preload("res://scripts/makers.gd")
const GearLook := preload("res://scripts/gear_look.gd")
const Reactions := preload("res://scripts/reactions.gd")
const Pacts := preload("res://scripts/pacts.gd")
const Essence := preload("res://scripts/essence.gd")

## The climber's core numbers live in combat.gd CLIMBER (the Data editor's
## "The climber's core numbers"); these read them, so a change shows at once.
const Combat := preload("res://scripts/combat.gd")
## Damage multiplier for striking a foe from behind.
var BACKSTAB_MULT: float:
	get: return float(Combat.CLIMBER["backstab"])
var MAX_HP: float:  # tougher than the first, very clumsy climber
	get: return float(Combat.CLIMBER["health"])
var MAX_STA: float:
	get: return float(Combat.CLIMBER["stamina"])
var STA_REGEN: float:  # per second, once the short wait after acting is over
	get: return float(Combat.CLIMBER["stamina_regen"])
## There is no sprint: one steady pace, so stamina is for fighting.
var WALK: float:
	get: return float(Combat.CLIMBER["walk"])
## A jump: a short hop that clears chasms and burning floor (not attacks).
var JUMP_TIME: float:
	get: return float(Combat.CLIMBER["jump_time"])
var JUMP_COST: float:
	get: return float(Combat.CLIMBER["jump_cost"])
const JUMP_HEIGHT := 16.0
var STRIKE_DAMAGE: float:
	get: return float(Combat.CLIMBER["strike_damage"])
var BUFFER_TIME: float:  # presses this early still count when you recover
	get: return float(Combat.CLIMBER["buffer"])
var COMBO_WINDOW: float:  # time after recovering to continue the chain
	get: return float(Combat.CLIMBER["combo_window"])
## Parry: active this long after pressing; a hit that lands within
## PARRY_PERFECT of the press is a perfect parry. Monsters glint 0.25 s
## before their blow, so pressing on the glint always parries, and pressing
## a beat after it is perfect.
var PARRY_WINDOW: float:
	get: return float(Combat.CLIMBER["parry_window"])
var PARRY_PERFECT: float:
	get: return float(Combat.CLIMBER["perfect_parry"])

var main  # the room (main.gd), set before the player is added
var radius := 14.0
var weight := 1.0  # how hard it is to shove when bodies collide
var max_hp := MAX_HP
var wound := 0.0  # the Proving's lingering wound: max health is cut by this share (proving.gd)
# Essence density (attributes): small passive bonuses, set from the profile.
var attr_speed := 1.0  # Air: Agility
var attr_strength := 1.0  # Blade: Strength
var attr_will := 1.0  # Iron: Will
var max_sta := MAX_STA
var hp := MAX_HP
var sta := MAX_STA
var sta_delay := 0.0
var aim := Vector2.RIGHT
var bonds := {}  # body part -> bond
var dead := false
var mouse_aim := true  # tests turn this off to aim by hand
var touch_aim := false  # on phones: face the nearest foe, or where you move
var stick_aim := false  # a controller: the right stick aims; let go and it aims like touch

var weapon := Weapons.START_MELEE
var pending_weapon := ""
## What you wear this climb (gear.gd): carried slot -> a gear record ({} is
## empty). Fists are always in weapon slot 1; slot 2 holds a melee weapon,
## slot 3 a ranged one; then the chest ("armor"), helm, gloves, legs, boots,
## cloak, amulet, two rings and a backpack. Kept on the player, so a new
## climb (a scene reload) starts afresh.
var gear := Gear.start_gear()
## The station's boons bought (boons.gd fx): added to what the gear adds.
var boon_fx := {}
## Spare pieces carried besides what you wear (gear records), up to
## pack_size(). They come home to the train if you survive.
var pack: Array = []
## What the worn pieces add up to (Gear.total_effects), kept up to date by
## refresh_gear() whenever gear changes.
var gear_fx := {}
## Health before gear (set by the room from your Vitality).
var base_hp := MAX_HP
var reload_t := 0.0  # a crossbow reloading after a shot (can't be skipped), or a pistol reloading (a roll breaks it off)
## A pistol's loaded shots (weapons.gd "shots"), for the piece in your
## ranged slot (ammo_for: its code; another piece there starts loaded).
var ammo := 0
var ammo_for := "-"
var refill_t := 0.0  # an enchanted pistol: toward its next chamber filling itself
var roll_t := 0.0
var roll_cd := 0.0
var roll_dir := Vector2.ZERO
var roll_speed := 0.0
var iframes := 0.0
const ROLL_ALPHA := 0.5  # how see-through a roll makes you
var ghost_t := 0.0
var attack_cd := 0.0
var combo := 0
var combo_t := 0.0
var swing_t := 0.0
var swing := {}
var lunge_t := 0.0
var lunge_speed := 0.0
var drawing := false
var draw_t := 0.0
var draw_release := false
var draw_ready := false
var parry_t := 0.0
var parry_cd := 0.0
var parry_flash := 0.0
var parry_window := PARRY_WINDOW
# Warden
var barrier_hp := 0.0  # Barrier: absorbs damage until spent or it expires
var barrier_t := 0.0
var barrier_stored := 0.0  # what it has absorbed (released as a burst from step 3)
var barrier_burst := false
var barrier_color := Color.WHITE
var barrier_max := 0.0  # how strong it was raised (Steadfast II restores toward it)
var barrier_grow := 0.0  # Bastion: this much of each blow it blocks comes back to it...
var barrier_cap := 0.0  # ...up to this
var barrier_burst_r := 0.0  # Bastion: its burst reaches this far (else 110)
var barrier_front := 1.0  # Moving Wall: blows from the wall's side wear it this fast...
var barrier_wall := 0.0  # ...the wall reaching this many degrees either side of your aim
var absorb_t := 0.0  # Absorb: hits are stored in the barrier instead
var unbreak_t := 0.0  # Unbreakable: no damage, no attacking
var unbreak_strike := 0.0  # its Apex: you may strike, at this much damage...
var unbreak_stored := 0.0  # ...and what it kept from you bursts out at its end (kraken.gd unbreakable)
# Deepcaller
var anchor_target  # Anchor: a tethered foe
var anchor_t := 0.0
var anchor_len := 110.0
var drink_target  # Drink Deep: a channelled drain
var drink_t := 0.0
var drink_age := 0.0
var drink_dmg := 0.0
var drink_tick := 0.0
var drink_jump := 0.0  # its Apex: on a kill the drain jumps to a foe this near (kraken.gd drink_jump)
var drink_at := Vector2.ZERO  # where the foe it drinks from was
## States on the climber (reactions.gd): only while CLIMBER "enabled" (off).
var states := {}
var is_climber := true
var rune_cd := 0.0  # Forge Runes: when the next kindled strike may leave a rune
var cast_t := 0.0
var cast_total := 0.0
var cast_part := ""
var hurt_t := 0.0
var dodge_cd := 0.0
var knock := Vector2.ZERO
var trap_slow := 1.0  # a thorn snare holds you, a sluice's water slows you (traps.gd)
var squash := 0.0
var buffered := ""
var buffer_t := 0.0
var step_t := 0.0
# Hold to pick: holding a mark's key opens a ring of its spells.
const PICK_HOLD := 0.25
var pick_part := ""
var pick_t := 0.0
var pick_open := false
var pick_index := -1
var pick_dir_override := Vector2.ZERO  # touch: finger offset from the button
## A phone: holding a cast button that opens no ring (one spell, or a
## technique) this long shows its card instead (ability_hints.gd), and
## letting go casts nothing.
const PEEK_HOLD := 0.45
var pick_peeked := false
# Bond effects on the climber
var thunderhead_t := 0.0  # Stormcaller's Thunderhead
var thunderhead_bolt := 0.0  # its Apex: a strike you land calls a bolt this strong
var hawk_t := 0.0  # Hunter's Hawk's Eye
var quarry  # Hunter's Quarry: the last foe you struck
var quarry_fresh := false  # (a foe struck the first time isn't your Quarry yet: bond.gd taken_mult)
var overlay: Node2D  # over the darkness: swing trails and rings
# Items (items.gd): what you carry, and healing that is still working.
var items := Items.START.duplicate()  # item id -> count
var vessel := {}  # the vessel on the belt (vessel.gd): {kind, amount}, while items has "vessel"
var hits_taken := 0  # blows that landed on you (not poison or fire), this climb
var item_sel := ""  # the item G uses
var heal_left := 0.0
var heal_rate := 0.0
# Hold to pick an item: holding the item button (or the d-pad down) opens a
# ring of your belt items; a short press uses the quick item (or picks the next).
var item_hold_src := ""  # the action being held: "use_item" or "item_next"
var item_hold_t := 0.0
var ring_open := false
var ring_index := -1
var item_dir_override := Vector2.ZERO  # touch: finger offset from the Item button
# What the newer items are doing (items.gd), in seconds left.
var edge_t := 0.0  # Edge Oil: strikes hit harder
var ward_oil_t := 0.0  # Warding Oil: traps can't hurt you while its barrier holds
var haste_t := 0.0  # Haste Draught: a quicker walk, cheaper rolls
var stone_t := 0.0  # Stoneskin Draught: less damage, no knockback
var salts_t := 0.0  # Second Wind Salts: stamina refills faster
var buffs := {}  # items that add to your numbers for a while (items.gd "buff"): id -> {t, fx}
# Rules of named gear (gear.gd NAMED) and traits.
var dodge_haste_t := 0.0  # Phantom Treads: a dodge quickens your walk
var still_t := 0.0  # Heartstone: toward the next health while unnoticed
var spells_cast := 0  # Spellweave Ring: every third spell is free
var guard_floor := {}  # once-a-floor rules used: rule -> the floor
var triune_n := 0  # Triune Fang: which head strikes next
var rebirth_used := false  # Sunplume Mantle: once a climb
## The flow (secret.gd): the path's essence banked, which lives in your
## shadow. main.gd set_flow gives the path and its step; the numbers below
## follow from them (secret.gd EFFECTS).
var flow_path := ""
var flow_step := 0
var flow_regen := 0.0  # Life: health regrown a second
var flow_mend := 0.0  # Life: health back for a kill
var flow_heal := 1.0  # Life: healing times this
var flow_refuse := false  # Life: once a floor, a killing blow leaves you standing
var flow_damage := 1.0  # Unmaking: strikes (and spells: bond.gd flow_power) times this
var flow_hp := 1.0  # Unmaking: max health times this (refresh_gear)
var flow_erode := 0.0  # Unmaking: damage a second to awake monsters beside you
var flow_pierce := false  # Unmaking: strikes ignore armour
var flow_undo := 0.0  # Unmaking: a slain foe comes apart
var _erode_t := 0.0
var _undoing := false
## Life's leaves trailing behind you (a few, reused): world spots and ages.
var _leaf_at := PackedVector2Array()
var _leaf_age := PackedFloat32Array()
var _leaf_ang := PackedFloat32Array()
var _leaf_next := 0
var _leaf_from := Vector2.ZERO
const LEAVES := 8


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	overlay = Node2D.new()
	overlay.z_as_relative = false
	overlay.z_index = 45  # over the darkness layer (lighting.gd)
	overlay.draw.connect(_draw_overlay)
	add_child(overlay)
	# Bonds are given by the room from your saved marks (none on a first climb).
	swing = wdata()["combo"][0]
	_leaf_at.resize(LEAVES)
	_leaf_age.resize(LEAVES)
	_leaf_ang.resize(LEAVES)
	_leaf_age.fill(99.0)


func wdata() -> Dictionary:
	return Weapons.WEAPONS[weapon]


## "melee", "bow", "crossbow" or "gun": what the weapon in hand does.
func wkind() -> String:
	return wdata()["kind"]


## The armor you wear (gear.gd ARMOR; "no armor" when none).
func armor() -> Dictionary:
	return Gear.armor(gear.get("armor", {}))


## The id of what you wear in a carried slot ("" if it's empty).
func gear_id(slot: String) -> String:
	return Gear.base_id(gear.get(slot, {}))


## The weapon in each of the three slots: fists, melee, ranged ("" if empty).
func slots() -> Array:
	return ["fists", gear_id("melee"), gear_id("ranged")]


## The pistol in your ranged slot: how many shots it holds (0 for no pistol).
func gun_shots() -> int:
	var id := gear_id("ranged")
	return int(Weapons.WEAPONS[id]["shots"]) if Weapons.is_gun(id) else 0


## The essence your ranged slot's pistol fires (gear.gd shot_kind), "" for lead.
func gun_magic() -> String:
	return Gear.shot_kind(gear.get("ranged", {}))


## Shots loaded in your ranged slot's pistol (a newly carried one is loaded).
func ammo_left() -> int:
	var code := Gear.code(gear.get("ranged", {}))
	if code != ammo_for:
		ammo_for = code
		ammo = gun_shots()
		refill_t = 0.0
		if weapon != "fists" and weapon == gear_id("ranged"):
			reload_t = 0.0
	return ammo


## Seconds a pistol's reload takes (faster with of the Quick Draw and the like).
func gun_reload_time() -> float:
	return float(wdata().get("reload", 1.0)) / (1.0 + gfx("draw"))


## Seconds an enchanted pistol's chamber takes to fill itself.
func gun_refill_time() -> float:
	var id := gear_id("ranged")
	if not Weapons.is_gun(id):
		return 1.0
	var t := float(Weapons.WEAPONS[id]["refill"]) * float(Weapons.essence_shot(gun_magic()).get("refill", 1.0))
	return t / (1.0 + gfx("draw"))


## Starts reloading the pistol in hand (an ordinary one, empty).
func _start_reload() -> void:
	reload_t = gun_reload_time()
	var w := wdata()
	main.sfx(String(w["reload_sound"]), float(w.get("reload_pitch", 1.0)), -2.0, 0.03)


## Starts the climb with your heirlooms in their slots (from the profile),
## each in full repair. Rings fill both ring slots.
func use_heirlooms(heirlooms: Dictionary) -> void:
	for hs in heirlooms:
		var gs := Gear.gear_slot_for(String(hs))
		if gs == "":
			continue
		var into: Array = Gear.carry_slots(gs)
		var pieces: Array = Gear.heirloom_pieces(heirlooms, hs).filter(func(r): return Gear.slot_of(r) == gs)
		for i in mini(pieces.size(), into.size()):
			gear[into[i]] = Gear.heirloom_copy(pieces[i])
	weapon = gear_id("melee") if gear_id("melee") != "" else "fists"
	if wkind() == "melee":
		swing = wdata()["combo"][0]
	refresh_gear()


## Wears this gear (carried slot -> record) all at once, with no fuss: the
## train's Loadout (train.gd dress). The melee weapon comes to hand.
func wear_set(g: Dictionary) -> void:
	gear = g
	weapon = gear_id("melee") if gear_id("melee") != "" else "fists"
	if wkind() == "melee":
		swing = wdata()["combo"][0]
	refresh_gear()


## Every piece of gear you carry (not fists), as ids, for leaving out of drops.
func carried_gear() -> Array:
	var out: Array = []
	for s in Gear.SLOTS:
		var id := gear_id(s)
		if id != "":
			out.append(id)
	return out


## The carried slot a new piece of this kind goes in: its own, or for a ring
## the first empty ring slot (else the first ring).
func slot_for(g) -> String:
	var into: Array = Gear.carry_slots(Gear.slot_of(g))
	for s in into:
		if gear_id(s) == "":
			return s
	return into[0]


## Takes a piece of gear (a record or an id) into its slot (`into` picks a
## ring slot). Returns the record that was there before ({} if the slot was
## empty), for the caller to drop on the floor.
func take_gear(g, into := "") -> Dictionary:
	var r := Gear.rec(g)
	if r.is_empty():
		return {}
	var gs := Gear.slot_of(r)
	var slot := into if into in Gear.carry_slots(gs) else slot_for(r)
	var old := Gear.rec(gear.get(slot, {}))
	gear[slot] = r
	if gs == "melee" or gs == "ranged":
		drawing = false
		_equip(r["base"])
	else:
		main.fx_text(global_position + Vector2(0, -30), Gear.display(r), Gear.color(r))
		main.sfx("armor_on", 1.0 if gs == "armor" else 1.2, -2.0 if gs == "armor" else -6.0)
	refresh_gear()
	return old


## Adds up what your worn pieces do (max health and stamina, protection,
## speed and the rest; Gear.total_effects), after any gear changes.
func refresh_gear() -> void:
	gear_fx = Gear.total_effects(gear)
	for k in boon_fx:  # (the station's boons: boons.gd)
		gear_fx[k] = float(gear_fx.get(k, 0.0)) + float(boon_fx[k])
	max_sta = MAX_STA + float(gear_fx.get("stamina", 0.0))
	sta = minf(sta, max_sta)
	var was := max_hp
	max_hp = base_hp + float(gear_fx.get("health", 0.0))
	if flow_hp < 1.0:
		max_hp = roundf(max_hp * flow_hp)  # (Unmaking's flow costs health)
	if max_hp > was:
		hp += max_hp - was
	hp = minf(hp, max_health())
	for b in bonds.values():
		b.gear_power = 1.0 + float(gear_fx.get("spell", 0.0))
	queue_redraw()


## The record of the weapon in hand (its id for fists), for icons that show wear.
func weapon_rec():
	for s in ["melee", "ranged"]:
		if weapon != "fists" and gear_id(s) == weapon:
			return gear[s]
	return weapon


## What you wear, coarsely (ids and which are badly worn), for redrawing
## the HUD only when it changes.
func gear_signature() -> Array:
	var out: Array = []
	for s in Gear.SLOTS:
		var g = gear.get(s, {})
		out.append(Gear.base_id(g) + ("!" if Gear.is_worn(g) else ""))
	return out


## A number your worn pieces add up to (0 when none does), with what any
## item working on you adds (buffs: a Briar Tonic's thorns, Lantern Oil's light).
func gfx(key: String) -> float:
	var v := float(gear_fx.get(key, 0.0))
	for b in buffs.values():
		v += float(b["fx"].get(key, 0.0))
	return v


## An item's effect for `seconds` (items.gd "buff"); using another refreshes it.
func add_buff(id: String, seconds: float, fx: Dictionary) -> void:
	buffs[id] = {"t": seconds, "fx": fx}


## Seconds left on an item's effect (0 if none).
func buff_left(id: String) -> float:
	return float(buffs.get(id, {}).get("t", 0.0))


## Protection from all you wear (the chest plus helm and legs), capped.
func protection() -> float:
	return Gear.protection(gear, gear_fx, float(Items.ITEMS["stoneskin"]["reduce"]) if stone_t > 0.0 else 0.0)


## A rule of the weapon in hand (a named weapon's, gear.gd weapon_rules), 0 if none.
func rule(key: String) -> float:
	if weapon == "fists":
		return 0.0
	return float(Gear.weapon_rules(weapon_rec()).get(key, 0.0))


## Once a floor: true (and spent) the first time a rule asks on this floor.
func once_a_floor(key: String) -> bool:
	if int(guard_floor.get(key, -1)) == main.floor_num:
		return false
	guard_floor[key] = main.floor_num
	return true


## How many kinds of item the belt holds (a Belt Pouch or a Climber's Pack adds one).
func belt_kinds() -> int:
	return Items.BELT_KINDS + int(gfx("belt"))


## How many spare pieces your pack holds (a Climber's Pack holds more).
func pack_size() -> int:
	return Gear.PACK_SIZE + int(gfx("pack"))


## True if your pack has room for another piece.
func pack_room() -> bool:
	return pack.size() < pack_size()


## Why an item can't be taken: "" if it can, "stack" if you carry as many
## as you can, "belt" if it's a new kind and the belt is full.
func item_room(id: String) -> String:
	if not Items.ITEMS.has(id):
		return "stack"
	if item_count(id) >= max_stack(id):
		return "stack"
	if item_count(id) <= 0 and carried().size() >= belt_kinds():
		return "belt"
	return ""


## How many of an item you can carry (a satchel holds one more of each;
## the recall scroll is always one).
func max_stack(id: String) -> int:
	var n := Items.max_stack(id)
	return n if id == "scroll" else n + int(gfx("stack"))


## Wear (Common pieces only): a use takes condition off the pieces it uses
## (Gear.WEAR_BY). At Gear.WORN a piece's bonus halves; at 0 it breaks.
func wear_gear(kind: String, times := 1.0) -> void:
	var amount: float = float(Gear.WEAR.get(kind, 0.0)) * times
	for slot in Gear.WEAR_BY.get(kind, []):
		var g = gear.get(slot, {})
		if not Gear.wears(g):
			continue
		var was_worn := Gear.is_worn(g)
		g["wear"] = maxf(0.0, float(g["wear"]) - amount)
		if g["wear"] <= 0.0:
			_break_gear(slot)
		elif Gear.is_worn(g) and not was_worn:
			refresh_gear()
			main.fx_text(global_position + Vector2(0, -34), "%s: badly worn" % Gear.display(g), Color(0.95, 0.6, 0.4))


## A piece wore out: the slot is empty (a broken weapon leaves you your fists).
func _break_gear(slot: String) -> void:
	var g = gear.get(slot, {})
	gear[slot] = {}
	main.fx_text(global_position + Vector2(0, -38), Gear.TEXT["broke"] % Gear.display(g), Color(1.0, 0.45, 0.35))
	main.sfx("hit_armor", 0.7, -2.0)
	if Gear.base_id(g) == weapon or Gear.base_id(g) == pending_weapon:
		pending_weapon = ""
		drawing = false
		_equip("fists")
	refresh_gear()


## A body part did its thing: it soaks up essence toward a mark, and fills
## the bond on it (if it has one) for casting.
func _part_action(part: String, soak: float, fill: float) -> void:
	main.add_soak(part, soak)
	if main.unbound != null and main.unbound.on:
		main.unbound.part_action(part, fill * (1.0 + gfx("fill")))  # (an Unbound's techniques of that part fill)
		return
	var b = bonds.get(part)
	if b != null:
		b.fill(fill * (1.0 + gfx("fill")))  # of the Well, a Tide Locket


## True if any of your marks has learned a spell of this type.
func _knows(spell_type: String) -> bool:
	for b in bonds.values():
		for sp in b.spells():
			if sp["type"] == spell_type:
				return true
	return false


func _burned(part: String) -> bool:
	var b = bonds.get(part)
	return b != null and b.burned


## A burned heart caps your health lower until the next stair; the
## Proving's wound, for a few floors.
func max_health() -> float:
	return (max_hp + _graft_health()) * (0.75 if _burned("heart") else 1.0) * (1.0 - wound)


## Grafting from rank II: each graft you carry gives a little more health.
func _graft_health() -> float:
	if main == null or not ("grafts" in main) or main.grafts.is_empty() or passive_rank("grafter") < 2:
		return 0.0
	return Bonds.passive_num("grafter", 2, "graft_health", 0.0) * main.grafts.size()


## The path and its flow step (main.gd, from the save): what the flow does.
func set_flow(path: String, step: int) -> void:
	flow_path = path
	flow_step = step if path != "" else 0
	flow_regen = Secret.effect(path, "regen", flow_step)
	flow_mend = Secret.effect(path, "mend", flow_step)
	flow_heal = Secret.effect(path, "heal", flow_step)
	flow_refuse = Secret.effect(path, "refuse", flow_step)
	flow_damage = Secret.effect(path, "damage", flow_step)
	flow_hp = Secret.effect(path, "health", flow_step)
	flow_erode = Secret.effect(path, "erode", flow_step)
	flow_pierce = Secret.effect(path, "pierce", flow_step)
	flow_undo = Secret.effect(path, "undo", flow_step)
	for b in bonds.values():
		b.flow_power = flow_damage


## Healing you receive (draughts, springs, bond heals): Life's flow makes it stronger.
func heal_mult() -> float:
	return flow_heal


## Heals you (for anything that heals but isn't tracked elsewhere). Returns what it healed.
func mend_by(amount: float) -> float:
	var h := minf(maxf(0.0, amount), max_health() - hp)
	if h > 0.0:
		hp += h
	return maxf(h, 0.0)


func has_bond(bond_id: String) -> bool:
	for b in bonds.values():
		if b.id == bond_id:
			return true
	return false




## A mark's passive rank (bonds.gd passive_rank: II from step 3, III at
## step 5), or 0 without the mark.
func passive_rank(bond_id: String) -> int:
	for b in bonds.values():
		if b.id == bond_id:
			return BondScript.Bonds.passive_rank(b.step)
	return 0


## One of your creatures fell (enemy.gd): Covenant's Kinship III heals you
## for a share of its health.
func creature_fell(a) -> void:
	if dead or passive_rank("covenant") < 3:
		return
	var got := mend_by(float(a.max_hp) * Bonds.passive_num("covenant", 3, "fall_heal", 0.25) * heal_mult())
	if got >= 1.0:
		main.fx_text(global_position + Vector2(0, -44), "+%d" % int(round(got)), Color(0.9, 0.5, 0.55))
		main.fx_bolt([a.global_position, global_position], Color(0.9, 0.5, 0.55))


func _physics_process(delta: float) -> void:
	if not states.is_empty():
		Reactions.tick_climber(self, delta)  # (monsters' states on you: off unless reactions.gd CLIMBER "enabled")
	if dead:
		velocity = knock
		knock = knock.move_toward(Vector2.ZERO, 900.0 * delta)
		move_and_slide()
		queue_redraw()
		return
	_tick_timers(delta)
	var mouse := get_global_mouse_position()
	if parry_t > 0.0:
		pass  # a parry keeps facing the threat it turned toward
	elif touch_aim:
		if attack_cd <= 0.0:
			_auto_aim()
	elif stick_aim:
		if attack_cd <= 0.0:
			var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
			if stick != Vector2.ZERO:
				aim = stick.normalized()
			else:
				_auto_aim()
	elif mouse_aim and mouse.distance_to(global_position) > 4.0 and attack_cd <= 0.0:
		aim = (mouse - global_position).normalized()
	_read_buffer()
	_update_pick(delta)
	_update_item_hold(delta)

	if jump_t > 0.0:
		_tick_jump(delta)
		if buffered != "" and buffer_t > 0.0 and buffered == "parry":
			if _try_action(buffered, Vector2.ZERO):
				buffered = ""
	elif cast_t > 0.0:
		# A wind-up can't be cancelled: no moving, no rolling.
		cast_t -= delta
		velocity = Vector2.ZERO
		if has_bond("flame_contractor"):  # Casting Stride: walk while winding up
			velocity = Input.get_vector("move_left", "move_right", "move_up", "move_down") * WALK * 0.75
		if cast_t <= 0.0:
			_release_cast()
	elif roll_t > 0.0:
		roll_t -= delta
		velocity = roll_dir * roll_speed
		# Afterimages show exactly when you are untouchable.
		if iframes > 0.0:
			ghost_t -= delta
			if ghost_t <= 0.0:
				ghost_t = 0.03
				main.fx_ghost(global_position, radius, Color(0.75, 0.9, 1.0) if has_bond("windwalker") else Color(0.88, 0.83, 0.72))
	elif lunge_t > 0.0:
		lunge_t -= delta
		velocity = aim * lunge_speed
	else:
		if pending_weapon != "" and attack_cd <= 0.0 and not drawing:
			_equip(pending_weapon)
		var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		var spd := WALK
		if drawing:
			spd *= wdata()["move_mult"]
			_tick_draw(delta)
		elif attack_cd > 0.0:
			spd *= 0.35  # committed to the swing
		elif reload_t > 0.0 and wkind() in ["crossbow", "gun"]:
			spd *= wdata()["reload_move"]  # you can walk while you reload
		spd *= attr_speed * armor()["walk"] * (1.0 + gfx("walk"))  # heavy armor slows you a little; boots
		if has_rune("swiftness"):
			spd *= 1.15
		if haste_t > 0.0:
			spd *= 1.0 + float(Items.ITEMS["haste"]["walk"])  # Haste Draught
		if dodge_haste_t > 0.0:
			spd *= 1.0 + gfx("dodge_haste")  # Phantom Treads
		if _stubborn():
			spd *= 1.2
		if has_bond("covenant"):  # Pack Stride
			for a in main.allies():
				if a.global_position.distance_to(global_position) < 130.0:
					spd *= 1.15
					break
		velocity = input * spd * main.water_slow(global_position, has_bond("tidecaller") or has_bond("sandshaper") or gear_fx.get("wade", false) or flying()) * trap_slow
		_footsteps(delta, spd if input != Vector2.ZERO else 0.0)
		if buffered != "" and _try_action(buffered, input):
			buffered = ""
	# The Ice Hall's ice (puzzles/ice.gd): on it you slide along the tile
	# grid, whatever you were doing; it sets the velocity and uses up knockback.
	if main.puzzle != null and main.puzzle.steer(self, delta):
		knock = Vector2.ZERO
	velocity += knock
	move_and_slide()
	_check_fall()
	queue_redraw()


## Touch aiming: lock onto the nearest monster in reach (the bow reaches
## further), otherwise face the way you're moving.
func _auto_aim() -> void:
	var reach := 380.0 if wkind() != "melee" else 150.0
	var best = null
	var best_d := reach
	for e in main.targets():
		var d: float = global_position.distance_to(e.global_position)
		if d < best_d:
			best_d = d
			best = e
	var target := aim
	var eye: Vector2 = main.puzzle.aim_point(global_position, reach) if main.puzzle != null else Vector2.INF
	if best != null:
		target = (best.global_position - global_position).normalized()
	elif eye != Vector2.INF:
		target = (eye - global_position).normalized()  # no foe near: aim at the puzzle's eye
	else:
		var move := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if move.length() > 0.2:
			target = move.normalized()
	aim = aim.slerp(target, 0.35).normalized()


## Hold to pick: while a mark's key is held past PICK_HOLD, a ring of its
## spells opens (time stops) and the direction you point picks one; letting
## go casts it. A quick tap just casts the selected spell.
func _update_pick(delta: float) -> void:
	if pick_part == "":
		return
	var b = bonds.get(pick_part)
	if b == null:
		pick_part = ""
		return
	if Input.is_action_pressed("cast_" + pick_part):
		pick_t += delta / maxf(Engine.time_scale, 0.01)
		if not pick_open and pick_t >= PICK_HOLD and b.spells().size() > 1:
			pick_open = true
			pick_index = b.selected
			main.set_slowmo(true)
		elif not pick_open and not pick_peeked and pick_t >= PEEK_HOLD and main.touch_active and main.hints != null:
			pick_peeked = true
			main.hints.show_card(pick_part)
		if pick_open:
			_aim_pick(b)
		return
	if pick_peeked:
		# Let go after the card showed: nothing is cast.
		pick_peeked = false
		main.hints.release_card()
		pick_dir_override = Vector2.ZERO
		pick_part = ""
		return
	# Released: pick (if the ring was open) and cast.
	if pick_open:
		_aim_pick(b)  # read the direction one last time (a quick slide-and-release)
		b.select(pick_index)
		main.set_slowmo(false)
	pick_open = false
	pick_dir_override = Vector2.ZERO
	buffered = "cast_" + pick_part
	buffer_t = BUFFER_TIME
	pick_part = ""


## Hold to pick an item: past Items.RING_HOLD the ring of belt items opens
## (time stops) and the direction you point picks one; letting go uses it.
## A short press uses the quick item (or, from the d-pad down or T, picks
## the next one).
func _update_item_hold(delta: float) -> void:
	if item_hold_src == "":
		return
	if dead:
		_close_ring()
		return
	if Input.is_action_pressed(item_hold_src):
		item_hold_t += delta / maxf(Engine.time_scale, 0.01)
		if not ring_open and item_hold_t >= Items.RING_HOLD and carried().size() >= 2:
			ring_open = true
			ring_index = carried().find(selected_item())
			main.set_slowmo(true)
			main.tip("item_ring")
		if ring_open:
			_aim_ring()
		return
	# Let go: use what the ring points at, or the quick item for a tap.
	if ring_open:
		_aim_ring()
		var have := carried()
		if ring_index >= 0 and ring_index < have.size():
			item_sel = have[ring_index]
		buffered = "item"
		buffer_t = BUFFER_TIME
	elif item_hold_src == "use_item":
		buffered = "item"
		buffer_t = BUFFER_TIME
	else:
		cycle_item()
	_close_ring()


func _close_ring() -> void:
	if ring_open:
		main.set_slowmo(false)
	ring_open = false
	item_hold_src = ""
	item_hold_t = 0.0
	item_dir_override = Vector2.ZERO


## Points into the open item ring: the item in that direction is highlighted.
func _aim_ring() -> void:
	var dir := item_dir_override
	if dir == Vector2.ZERO and stick_aim:
		dir = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		if dir == Vector2.ZERO:
			dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		dir *= 100.0
	elif dir == Vector2.ZERO and not touch_aim:
		dir = get_global_mouse_position() - global_position
	var n := carried().size()
	if dir.length() > 18.0 and n > 0:
		ring_index = posmod(int(round((dir.angle() + PI / 2.0) / (TAU / float(n)))), n)


## Points into the open ring: the spell in that direction is highlighted.
func _aim_pick(b) -> void:
	var dir := pick_dir_override
	if dir == Vector2.ZERO and stick_aim:
		# A controller points with the right stick (or the left one).
		dir = Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
		if dir == Vector2.ZERO:
			dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		dir *= 100.0
	elif dir == Vector2.ZERO and not touch_aim:
		dir = get_global_mouse_position() - global_position
	if dir.length() > 18.0:
		var n: int = b.spells().size()
		var step_a := TAU / float(n)
		pick_index = posmod(int(round((dir.angle() + PI / 2.0) / step_a)), n)


func _footsteps(delta: float, speed: float) -> void:
	if speed <= 1.0:
		step_t = 0.0
		return
	step_t -= delta
	if step_t <= 0.0:
		step_t = 36.0 / speed  # one step every ~36 px travelled
		var vol := -2.0 if speed > WALK * 1.1 else -5.0
		main.sfx("step", 1.0, vol, 0.08)
		var clink: String = armor().get("step", "")  # chain mail and plate jingle
		if clink != "":
			main.sfx(clink, 1.0, vol - 2.0, 0.1)


func _read_buffer() -> void:
	var have := slots()
	for i in have.size():
		if Input.is_action_just_pressed("weapon_%d" % (i + 1)) and have[i] != "":
			pending_weapon = have[i]
	if Input.is_action_just_pressed("weapon_next") or Input.is_action_just_pressed("weapon_prev"):
		var step := 1 if Input.is_action_just_pressed("weapon_next") else -1
		var from := pending_weapon if pending_weapon != "" else weapon
		var idx := have.find(from)
		for n in have.size():
			idx = (idx + step + have.size()) % have.size()
			if have[idx] != "":
				break
		pending_weapon = have[idx]
	# Y (or the phone's Take button): take the gear you stand on.
	if Input.is_action_just_pressed("interact"):
		main.take_gear_here()

	var pressed := ""
	if Input.is_action_just_pressed("roll"):
		pressed = "roll"
	elif Input.is_action_just_pressed("jump"):
		pressed = "jump"
	elif Input.is_action_just_pressed("attack") and not (main.entity != null and main.entity.ate_click()):
		pressed = "attack"  # (not a click that dismissed the Entity's bubble)
	elif Input.is_action_just_pressed("parry"):
		pressed = "parry"
	# The item button and the d-pad down: tap to use (or pick the next),
	# hold to open the ring of belt items (see _update_item_hold).
	for src in ["use_item", "item_next"]:
		if Input.is_action_just_pressed(src) and item_hold_src == "":
			item_hold_src = src
			item_hold_t = 0.0
			ring_open = false
	# A mark's key: tap to cast its selected spell, hold to pick another
	# (see _update_pick). The cast is buffered when the key is released.
	for part in BondScript.Bonds.PARTS:
		if Input.is_action_just_pressed("cast_" + part) and bonds.has(part):
			pick_part = part
			pick_t = 0.0
			pick_open = false
			pick_peeked = false
	if pressed != "":
		buffered = pressed
		buffer_t = BUFFER_TIME
	elif buffer_t <= 0.0:
		buffered = ""


func _equip(id: String) -> void:
	pending_weapon = ""
	if id == weapon:
		return
	if Weapons.is_gun(weapon) or Weapons.is_gun(id):
		reload_t = 0.0  # (putting a pistol away breaks off its reload; drawing one starts afresh)
	weapon = id
	combo = 0
	combo_t = 0.0
	drawing = false
	if wkind() == "melee":
		swing = wdata()["combo"][0]
	main.fx_text(global_position + Vector2(0, -30), wdata()["name"], Color(0.85, 0.82, 0.9))
	main.sfx(wdata().get("equip", "equip_sword"))


## Returns true once the action is spent (done, or refused for a reason
## that waiting won't fix), false if it should stay buffered.
func _try_action(action: String, input: Vector2) -> bool:
	if jump_t > 0.0 and action != "parry":
		return false  # wait for the landing
	match action:
		"jump":
			return _try_jump(input)
		"roll":
			return _try_roll(input)
		"attack":
			return _try_attack()
		"parry":
			return _try_parry()
		"item":
			use_item()
			return true
	if action.begins_with("cast_"):
		return _try_cast(action.substr(5))
	return true


func _tick_timers(delta: float) -> void:
	roll_cd -= delta
	iframes -= delta
	attack_cd -= delta
	combo_t -= delta
	swing_t -= delta
	parry_t -= delta
	parry_cd -= delta
	parry_flash -= delta
	_tick_bond_effects(delta)
	thunderhead_t -= delta
	hawk_t -= delta
	hurt_t -= delta
	dodge_cd -= delta
	buffer_t -= delta
	sta_delay -= delta * (1.0 + gfx("quick_breath"))  # (an Iron Band: stamina starts back sooner)
	if salts_t > 0.0:
		sta_delay = minf(sta_delay, 0.0)  # Second Wind Salts: your stamina never waits
	edge_t -= delta
	ward_oil_t -= delta
	haste_t -= delta
	stone_t -= delta
	salts_t -= delta
	dodge_haste_t -= delta
	for id in buffs.keys():
		buffs[id]["t"] -= delta
		if buffs[id]["t"] <= 0.0:
			buffs.erase(id)
	# Heartstone: a little health back while no monster has noticed you.
	var still := gfx("still_mend")
	if still > 0.0 and hp < max_health() and not dead:
		still_t += delta
		if still_t >= 3.0:
			still_t = 0.0
			if main.enemies().all(func(e): return e.unaware()):
				hp = minf(max_health(), hp + still)
	if reload_t > 0.0:
		var was := reload_t
		reload_t -= delta
		if weapon in Weapons.WEAPONS and wkind() == "crossbow":
			# The windlass ratchets back, then the bolt drops into place.
			var crank: float = float(wdata()["reload"]) * 0.8
			if was > crank and reload_t <= crank:
				main.sfx("crossbow_reload", 1.0, 0.0, 0.03)
		if reload_t <= 0.0 and weapon in Weapons.WEAPONS and wkind() == "crossbow":
			main.sfx("crossbow_load")
			main.fx_ring(global_position + aim * (radius + 8.0), Color(1.0, 0.9, 0.6), 14.0, 0.2, 2.0)
		if reload_t <= 0.0 and wkind() == "gun":
			# Every chamber loaded at once.
			ammo_left()
			ammo = gun_shots()
			var gw := wdata()
			main.sfx(String(gw["load_sound"]), float(gw.get("load_pitch", 1.0)), -2.0, 0.03)
			main.fx_ring(global_position + aim * (radius + 8.0), Color(1.0, 0.9, 0.6), 14.0, 0.2, 2.0)
	_tick_gun(delta)
	squash = move_toward(squash, 0.0, 5.0 * delta)
	knock = knock.move_toward(Vector2.ZERO, 900.0 * delta)
	_tick_healing(delta)
	# Life's flow: health slowly regrows.
	if flow_regen > 0.0 and not dead and hp < max_health():
		hp = minf(max_health(), hp + flow_regen * delta)
	_tick_erode(delta)
	hp = minf(hp, max_health())
	if sta_delay <= 0.0 and not drawing:
		sta = minf(max_sta, sta + STA_REGEN * attr_will * (1.0 + gfx("regen")) * delta * (1.35 if has_bond("deepcaller") else 1.0) * (0.6 if _burned("throat") else 1.0) * (1.3 if _stubborn() else 1.0) * (1.0 + 0.25 * graft("throat")) * armor()["regen"] * (1.0 + (float(Items.ITEMS["salts"]["regen"]) if salts_t > 0.0 else 0.0)))  # Deep Lungs; a burned throat; Stubborn Heart; a throat graft


## Pistols between shots: an enchanted one's chambers fill themselves one
## at a time (in hand or not, and through rolls); an ordinary one in hand
## starts reloading once it's empty (again after a roll that broke it off).
func _tick_gun(delta: float) -> void:
	var shots := gun_shots()
	if shots <= 0 or dead:
		return
	var have := ammo_left()
	if gun_magic() != "":
		if have >= shots:
			refill_t = 0.0
			return
		if attack_cd > 0.0 and weapon == gear_id("ranged"):
			return  # (not while the shot still kicks)
		refill_t += delta
		if refill_t >= gun_refill_time():
			refill_t = 0.0
			ammo = mini(shots, ammo + 1)
			if weapon == gear_id("ranged"):
				main.sfx("crossbow_load", 1.6, -12.0, 0.05)
		return
	if have <= 0 and reload_t <= 0.0 and roll_t <= 0.0 and wkind() == "gun" and weapon == gear_id("ranged"):
		_start_reload()


func _winded() -> void:
	main.fx_text(global_position + Vector2(0, -28), "too winded", Color(0.6, 0.6, 0.65))
	main.sfx("winded")


func _try_jump(input: Vector2) -> bool:
	if roll_t > 0.0 or attack_cd > 0.15 or cast_t > 0.0:
		return false
	if main.puzzle != null and main.puzzle.no_footing(global_position, true):
		return true  # (no leaping over the Ice Hall's rocks)
	var cost := 0.0 if gear_fx.get("free_jump", false) else JUMP_COST  # Climbing Boots
	if sta < cost:
		_winded()
		return true
	sta -= cost
	sta_delay = float(Combat.CLIMBER["jump_wait"])
	jump_vel = input * WALK * (1.0 + gfx("jump"))
	wear_gear("roll")
	jump_t = JUMP_TIME
	jump_total = JUMP_TIME
	glide_left = 0.8 if has_bond("flamewing") else 0.0
	drawing = false
	main.sfx("roll", 1.35, -6.0)
	return true


func _tick_jump(delta: float) -> void:
	# Flamewing's Phoenix Glide: hold jump to hang in the air a while longer.
	if glide_left > 0.0 and Input.is_action_pressed("jump") and jump_t < jump_total * 0.5:
		glide_left -= delta
		if fmod(glide_left, 0.1) < delta:
			main.fx_burst(global_position + Vector2(0, -jump_height()), Vector2.DOWN, Color(1.0, 0.55, 0.25), 2, 60.0)
	else:
		jump_t -= delta
	velocity = jump_vel
	if jump_t <= 0.0:
		jump_t = 0.0
		squash = 0.5
		main.sfx("step", 0.8, -4.0)


## How high off the ground you are, for drawing.
func jump_height() -> float:
	var hover := (FLY_HEIGHT + 2.0 * sin(Time.get_ticks_msec() * 0.006)) if flying() else 0.0  # (Firebird Form's flight)
	if jump_t <= 0.0 or jump_total <= 0.0:
		return hover
	var k := clampf(1.0 - jump_t / jump_total, 0.0, 1.0)
	return maxf(hover, sin(PI * k) * JUMP_HEIGHT + (6.0 if glide_left > 0.0 and Input.is_action_pressed("jump") and jump_t < jump_total * 0.5 else 0.0))


## Off the ground: chasms and burning floor can't touch you (a jump, or flight).
func in_air() -> bool:
	return jump_t > 0.0 or flying()


## Firebird Form's Apex: flying over chasms, burning floor, water and traps
## while the form lasts (anything a jump clears, and pressure plates).
const FLY_HEIGHT := 12.0


func flying() -> bool:
	return firebird_fly and firebird_t > 0.0 and not dead


## Walking (or being knocked) into a chasm: you fall, lose some health,
## and climb back out where you last stood.
func _check_fall() -> void:
	if dead or in_air():
		return
	if not main.in_chasm(global_position):
		last_safe = global_position
		return
	# A chasm doesn't hurt: you fall through it to a lower floor (main.gd).
	knock = Vector2.ZERO
	roll_t = 0.0
	velocity = Vector2.ZERO
	main.fall_through()


func _try_roll(input: Vector2) -> bool:
	if roll_cd > 0.0 or attack_cd > 0.15:
		return false
	if main.puzzle != null and main.puzzle.no_footing(global_position, false):
		return true  # (on the Ice Hall's ice you can only slide)
	# Windwalker's Body: the roll becomes a long wind dash.
	var wind := has_bond("windwalker")
	var cost := float(Combat.CLIMBER["dash_cost" if wind else "roll_cost"]) * (1.0 - 0.25 * minf(graft("legs"), 1.6))
	var dist_mult := 1.0
	# Armor weighs on a roll: heavier suits cost more and carry you less far.
	cost *= armor()["roll_cost"] * (1.0 + Gear.HEAVY_ROLL * gfx("heavy"))  # heavy pieces add a little
	cost *= 1.0 - gfx("roll_cost")  # of Rolling
	if haste_t > 0.0:
		cost *= 1.0 - float(Items.ITEMS["haste"]["roll"])  # Haste Draught
	dist_mult *= armor()["roll_dist"] * (1.0 + gfx("roll_dist"))
	if _burned("legs"):
		cost *= 1.5
		dist_mult = 0.7
	if sta < cost:
		_winded()
		return true
	sta -= cost
	sta_delay = float(Combat.CLIMBER["roll_wait"])
	roll_dir = input.normalized() if input != Vector2.ZERO else aim
	var duration := float(Combat.CLIMBER["dash_time" if wind else "roll_time"])
	roll_speed = float(Combat.CLIMBER["dash_speed" if wind else "roll_speed"]) * dist_mult * (1.0 + 0.15 * graft("legs"))
	roll_t = duration
	iframes = duration * float(Combat.CLIMBER["roll_iframes"]) + gfx("iframe")  # Phantom Treads
	roll_cd = (duration + float(Combat.CLIMBER["roll_cooldown"])) * (0.85 if has_bond("stormcaller") else 1.0)  # Quick Nerves
	attack_cd = 0.0
	combo = 0
	ghost_t = 0.0
	squash = 0.6
	drawing = false  # rolling drops a drawn arrow
	if reload_t > 0.0 and wkind() == "gun":
		reload_t = 0.0  # rolling breaks off a pistol's reload (it starts again after the roll)
		main.fx_text(global_position + Vector2(0, -34), Weapons.GUN_TEXT["broken_off"], Color(0.75, 0.72, 0.8))
	main.sfx("roll")
	if wind:
		main.sfx("gust", 1.3, -6.0)
		if passive_rank("windwalker") >= 3:  # Featherweight III: the roll leaves a gust
			BondScript.gryphon().roll_gust(main, global_position, BondScript.Bonds.passive_num("windwalker", 3, "radius"), BondScript.Bonds.passive_num("windwalker", 3, "lift"),
				BondScript.Bonds.passive_num("windwalker", 3, "weight"), BondScript.Bonds.BONDS["windwalker"]["color"])
	wear_gear("roll")
	return true


func _try_attack() -> bool:
	if attack_cd > 0.0 or drawing:
		return false
	if unbreak_t > 0.0 and unbreak_strike <= 0.0:
		return true  # Unbreakable: you cannot attack (its Apex lets you: unbreak_strike)
	if sta <= 0.0:
		_winded()
		return true
	if wkind() == "crossbow":
		if reload_t > 0.0:
			return false  # still reloading: it can't be skipped
		_fire_bolt()
		return true
	if wkind() == "gun":
		if ammo_left() <= 0 or reload_t > 0.0:
			return false  # empty: wait for the reload (or a chamber to fill itself)
		_fire_gun()
		return true
	if wkind() == "bow":
		drawing = true
		draw_t = 0.0
		draw_release = false
		draw_ready = false
		main.sfx("draw", _bow_pitch(wdata()), 0.0, 0.03)
		return true
	return _melee()


func _melee() -> bool:
	var w := wdata()
	var chain: Array = w["combo"]
	if combo_t <= 0.0 or combo >= chain.size():
		combo = 0
	swing = chain[combo]
	var heavy: bool = swing["heavy"]
	combo = (combo + 1) % chain.size()
	sta = maxf(0.0, sta - swing["sta"] * (1.0 - gfx("chain")))  # Grip Wraps
	sta_delay = float(Combat.CLIMBER["strike_wait"])  # stamina waits a moment after you attack: mashing runs you dry
	var recover: float = swing["recover"]
	if has_bond("flameblade"):
		recover = minf(recover, chain[0]["recover"])  # Hot Blood: chains never slow down
	attack_cd = recover * (0.85 if has_bond("stormcaller") else 1.0)  # Quick Nerves
	if _stubborn():
		attack_cd *= 0.8
	if desperate_t > 0.0:
		attack_cd *= 1.0 - 0.4 * (1.0 - hp / max_hp)
	combo_t = attack_cd + COMBO_WINDOW
	swing_t = w["swing_time"]
	lunge_t = 0.08
	lunge_speed = swing["lunge"]
	var snd: String = w["sound"]
	if heavy and not snd.ends_with("_heavy"):
		snd += "_heavy"
	main.sfx(snd, float(w.get("pitch", 1.0)) * (1.0 + 0.06 * combo))

	var dmg: float = STRIKE_DAMAGE * swing["dmg"] * attr_strength * (1.0 + gfx("strike"))  # gloves and rings
	if heavy:
		dmg *= 1.0 + gfx("finisher")  # Leather Gloves
	if weapon == "fists":
		dmg *= 1.0 + gfx("fist")  # Grip Wraps, Studded Gloves: the body's own blows
	if weapon != "fists" and weapon == gear_id("melee"):
		dmg *= Gear.weapon_power(gear["melee"])  # its rarity; a badly worn weapon hits softer
	if edge_t > 0.0:
		dmg *= float(Items.ITEMS["edge_oil"]["mult"])  # Edge Oil
	var hand = bonds.get("hand")
	if hand != null and hand.burned:
		dmg *= 0.6
	if has_rune("sharpness"):
		dmg *= 1.3
	if has_bond("flameblade"):
		dmg *= 1.0 + heat / 200.0  # Heat: up to half again as hard
	if kindle_t > 0.0:
		dmg += kindle_dmg
	if desperate_t > 0.0:
		dmg *= 1.0 + 1.5 * (1.0 - hp / max_hp)  # Desperation
	BondScript.wyvern().swing_fire(self)  # (Heat II: at full heat your swings throw fire)
	dmg *= 1.0 + 0.2 * graft("hand")
	var reach: float = swing["range"] * (1.25 if has_bond("blade_forger") else 1.0)  # Long Edge
	var hits := 0
	for e in main.targets():
		var to: Vector2 = e.global_position - global_position
		if to.length() > reach + e.radius:
			continue
		if absf(aim.angle_to(to)) > deg_to_rad(swing["arc"]):
			continue
		var blade: bool = swing.get("blade", false)
		_strike(e, dmg, to.normalized(), swing["knock"], heavy, String(w.get("blade_sound", w["hit_sound"])) if blade else w["hit_sound"], w.get("rocks", false), float(w.get("backstab", 0.0)), float(swing.get("stagger", 0.0)))
		_melee_rules(e, heavy)
		if kindle_t > 0.0:
			_kindled_strike(e)
		if blade and rule("draw_venom") > 0.0 and not e.dead:
			e.add_venom(int(rule("draw_venom")))  # Quietsteel: the drawn blade poisons
		hits += 1
	# The floor's puzzle: strikes light eyes and pull levers.
	if main.puzzle != null:
		main.puzzle.strike(global_position, aim, reach, swing["arc"])
	# Sealed wings and secret walls: a hollow knock, a seal that holds.
	if main.wings != null:
		main.wings.strike(global_position, aim, reach, swing["arc"])
	# A lever for a barred door.
	if main.door_view != null:
		main.door_view.strike(global_position, aim, reach, swing["arc"])
	# The floor's task (levers), a scenario's cage, a cracked wall (a
	# finisher breaks it; a lighter blow knocks hollow).
	if main.get("objective") != null:
		main.objective.strike(global_position, aim, reach, swing["arc"])
	if main.get("scenarios") != null:
		main.scenarios.strike(global_position, aim, reach, swing["arc"])
	if main.get("cracks") != null:
		main.cracks.strike(global_position, aim, reach, swing["arc"], heavy)
	# A tower's own things a blow can reach (thorns, heart-roots, spore pods).
	if main.has_method("tower_call"):
		main.tower_call("strike", [global_position, aim, reach, swing["arc"], heavy])
	# The hand fills when your weapon strikes land; the throat when one
	# swing catches several foes.
	if hits > 0:
		_part_action("hand", 0.5 * hits, 6.0 * hits)
	if hits > 1:
		_part_action("throat", 2.0 * (hits - 1), 8.0 * (hits - 1))
	if hits > 0:
		_strikes_landed(hits)
		BondScript.wyvern().strike_landed(self)  # (Weapon Memory III: every 5th throws a blade)
		wear_gear("strike")  # a landed swing wears the weapon and gloves (Commons)
		if heavy and float(w.get("finisher_sta", 0.0)) > 0.0:
			sta = minf(max_sta, sta + float(w["finisher_sta"]))  # the sword: a landed finisher gives breath back
	if swing.get("blade", false):
		main.sfx("equip_sword", 1.25, -6.0)  # the sword-cane's blade comes out
	return true


## What a landed melee strike does besides its damage: of Embers may set
## the foe burning; a Cinder Axe's finisher leaves burning floor.
func _melee_rules(e, heavy: bool) -> void:
	var ember := gfx("embers")
	if ember > 0.0 and not e.dead and randf() < ember:
		e.ignite(Gear.EMBER_BURN["dmg"], Gear.EMBER_BURN["time"])
	if heavy and rule("cinder") > 0.0:
		main.add_flame(e.global_position, 30.0, rule("cinder"), true)


## A kindled weapon sets what it strikes burning; Forge Runes (Flameblade
## and Rune Artist) leaves a small fire rune where it struck.
func _kindled_strike(e) -> void:
	var at: Vector2 = e.global_position
	if not e.dead:
		Reactions.apply(main, e, "burning", float(Reactions.STATES["burning"]["seconds"]), "kindle", maxf(1.0, kindle_dmg * 0.3))
		if kindle_brand > 0.0:
			BondScript.wyvern().brand(self, e)  # (Brand)
	if Pacts.has(self, "forge_runes") and rune_cd <= 0.0:
		var pf: Dictionary = Pacts.PACTS["forge_runes"]
		rune_cd = float(pf["every"])
		var mine: Array = main.runes.filter(func(r): return r.get("forge", false))
		while mine.size() >= int(pf["most"]):
			main.runes.erase(mine.pop_front())
		main.runes.append({"pos": at + aim * 10.0, "r": 18.0, "blast": float(pf["blast"]), "damage": float(pf["damage"]), "linked": false,
			"color": pf["color"], "t": float(pf["life"]), "forge": true, "arm": 0.8, "burn": float(pf["burn"]), "burn_t": float(pf["burn_t"])})
		main.fx_ring(at, pf["color"], 20.0, 0.3, 2.0)


## Flameblade: landed strikes heat the weapon; kindling keeps burning.
func _strikes_landed(hits: int) -> void:
	if kindle_t > 0.0:
		main.fx_burst(global_position + aim * 24.0, aim, kindle_color, 5, 200.0)
		if kindle_sustain:
			kindle_t = maxf(kindle_t, 2.5)
	if not has_bond("flameblade"):
		return
	heat_idle = 0.0
	var before := heat
	heat = minf(heat_cap(), heat + 12.0 * hits * (2.0 if kindle_t > 0.0 else 1.0) * (Items.FLAMEBLADE_OIL if edge_t > 0.0 else 1.0))  # Edge Oil builds heat faster
	if heat >= 100.0 and before < 100.0:
		main.fx_text(global_position + Vector2(0, -44), "White hot", Color(1.0, 0.85, 0.5))
		main.sfx("burn", 1.4, -6.0)


func _tick_draw(delta: float) -> void:
	var w := wdata()
	draw_t += delta * (1.0 + gfx("draw"))  # of the Quick Draw; Archer's Bracers
	if draw_t >= w["draw_time"] and not draw_ready:
		draw_ready = true
		main.sfx("bow_full", 1.0, 0.0, 0.03)
		main.fx_ring(global_position + aim * (radius + 8.0), Color(1.0, 0.9, 0.6), 18.0, 0.2, 2.0)
	if (mouse_aim or touch_aim or stick_aim) and not Input.is_action_pressed("attack"):
		draw_release = true
	# A quick tap still looses a weak shot once the arrow is nocked.
	if draw_release and draw_t >= w["min_draw"]:
		release_draw()


## Bigger bows (slower draws) creak and sing lower: 1.0 for the shortbow.
func _bow_pitch(w: Dictionary) -> float:
	return clampf(sqrt(0.75 / float(w.get("draw_time", 0.75))), 0.8, 1.15)


## Looses the drawn arrow. Power grows with how long you held the draw.
func release_draw() -> void:
	if not drawing:
		return
	var w := wdata()
	var k: float = clampf(draw_t / w["draw_time"], 0.0, 1.0)
	var full := k >= 1.0
	drawing = false
	attack_cd = w["recover"]
	sta = maxf(0.0, sta - w["sta"])
	sta_delay = float(Combat.CLIMBER["strike_wait"])
	var dmg: float = lerpf(w["dmg_min"], w["dmg_max"], k * k) * Gear.weapon_power(gear["ranged"]) * (1.0 + gfx("ranged"))
	wear_gear("shot")
	var hand = bonds.get("hand")
	if hand != null and hand.burned:
		dmg *= 0.6
	var speed: float = lerpf(w["speed_min"], w["speed_max"], k)
	var force: float = lerpf(w["knock_min"], w["knock_max"], k)
	if full and rule("gale") > 0.0:  # Stormtalon: a full draw rides the storm
		speed *= 1.3
		force *= rule("gale")
		dmg *= 1.2
	var arrow = main.spawn_player_arrow(global_position + aim * (radius + 6.0), aim * speed, dmg, force, full)
	arrow.weapon = true
	arrow.life = float(w.get("life", 1.6))
	main.sfx_fade("draw")  # the creak stops when the string goes
	# A harder draw looses a louder, sharper shot.
	main.sfx("bow", _bow_pitch(w) * (0.92 + 0.14 * k), -9.0 + 9.0 * k)
	knock = -aim * (60.0 if full else 20.0)
	if full:
		main.shake(3.0)


## A crossbow: press to fire a fast, strong bolt, then a reload you can't
## skip (you can walk while it reloads).
func _fire_bolt() -> void:
	var w := wdata()
	attack_cd = w["recover"]
	reload_t = float(w["reload"]) / (1.0 + gfx("draw"))
	sta = maxf(0.0, sta - w["sta"])
	sta_delay = float(Combat.CLIMBER["strike_wait"])
	var dmg: float = float(w["dmg"]) * Gear.weapon_power(gear["ranged"]) * (1.0 + gfx("ranged"))
	wear_gear("shot")
	var hand = bonds.get("hand")
	if hand != null and hand.burned:
		dmg *= 0.6
	var bolt = main.spawn_player_arrow(global_position + aim * (radius + 6.0), aim * float(w["speed"]), dmg, float(w["knock"]), bool(w["pierce"]))
	bolt.weapon = true
	bolt.life = float(w["life"])
	bolt.heavy = bool(w.get("heavy", false))
	bolt.style = "bolt"
	# Spinecaster: two barbs fly beside the bolt.
	for i in int(rule("volley")):
		var side := 0.2 * (1.0 + floorf(i / 2.0)) * (1.0 if i % 2 == 0 else -1.0)
		var barb = main.spawn_player_arrow(global_position + aim * (radius + 6.0), aim.rotated(side) * float(w["speed"]), dmg * 0.5, float(w["knock"]) * 0.5, false)
		barb.weapon = true
		barb.life = float(w["life"]) * 0.8
		barb.style = "bolt"
	main.sfx("crossbow")
	knock = -aim * 50.0
	main.shake(2.5)


## A pistol: one shot of lead, or of its enchantment's essence (weapons.gd
## ESSENCE_SHOT). An ordinary pistol starts reloading once it's empty
## (_tick_gun); an enchanted one's chambers fill themselves.
func _fire_gun() -> void:
	var w := wdata()
	var magic := gun_magic()
	var es: Dictionary = Weapons.essence_shot(magic) if magic != "" else {}
	ammo_left()
	ammo -= 1
	refill_t = 0.0
	attack_cd = w["recover"]
	sta = maxf(0.0, sta - w["sta"])
	sta_delay = float(Combat.CLIMBER["strike_wait"])
	var dmg: float = float(w["dmg"]) * Gear.weapon_power(gear["ranged"]) * (1.0 + gfx("ranged"))
	if ammo <= 0 and rule("last_shot") > 0.0:
		dmg *= 1.0 + rule("last_shot")  # Lastbell Revolver: the last shot in the cylinder
	wear_gear("shot")
	var hand = bonds.get("hand")
	if hand != null and hand.burned:
		dmg *= 0.6
	var speed: float = float(w["speed"]) * float(es.get("speed", 1.0))
	var life: float = float(w["life"]) * float(es.get("life", 1.0))
	var muzzle: Vector2 = global_position + aim * (radius + 10.0)
	var tint: Color = Essence.color(magic) if magic != "" else Color(1.0, 0.85, 0.55)
	var shards := int(es.get("shards", 1))
	for i in shards:
		var off := 0.0 if shards <= 1 else lerpf(-1.0, 1.0, float(i) / float(shards - 1)) * float(es.get("fan", 0.15))
		var share := 1.0 if shards <= 1 else float(es.get("share", 0.5))
		var shot = main.spawn_player_arrow(muzzle, aim.rotated(off) * speed, dmg * share, float(w["knock"]) * share, bool(w.get("pierce", false)) or es.has("pierce"))
		shot.weapon = true
		shot.life = life
		shot.heavy = bool(w.get("heavy", false)) or es.has("stagger")
		shot.style = "essence" if magic != "" else "shot"
		shot.tint = tint
		shot.shot = magic
		shot.fills = magic == ""  # an essence shot is the pistol's essence, not your hand's
	# The shot: a flash and a crack, and the kick of it.
	main.sfx(String(w["shot_sound"]), float(w.get("shot_pitch", 1.0)), -3.0, 0.04)
	main.sfx(String(w["crack"]), float(w.get("crack_pitch", 1.0)), -4.0, 0.04)
	main.fx_burst(muzzle, aim, tint, 8, 260.0)
	main.light_flash(muzzle, tint, 0.9, 1.6, 0.12)
	knock = -aim * float(w.get("kick", 40.0))
	main.shake(4.0 if bool(w.get("heavy", false)) else 1.6)


## Called by your arrows when they hit a monster.
## `weapon`: the climber's own bow, crossbow or pistol shot. Those carry the
## weapon's rules, and (`fills`) fill the hand's mark; a spell's shot is just
## a hit, and an enchanted pistol's essence shot doesn't fill the hand.
## `shot`: an essence shot's essence (weapons.gd ESSENCE_SHOT), "" for none.
func ranged_hit(e, dmg: float, dir: Vector2, force: float, heavy: bool, weapon := false, shot := "", fills := true) -> void:
	# Hunter's Hawk's Eye: every arrow strikes a weak point.
	# Ambusher (Hunter and Ashwalker): a shot it never saw coming does too.
	if hawk_t > 0.0:
		dmg *= 2.0
		main.fx_text(e.global_position + Vector2(0, -e.radius - 34.0), "weak point", Color(0.85, 0.63, 0.42))
	elif Pacts.has(self, "ambusher") and Reactions.has(e, "unseen"):
		dmg *= Pacts.num("ambusher", "mult")
		main.fx_text(e.global_position + Vector2(0, -e.radius - 34.0), "weak point", Pacts.PACTS["ambusher"]["color"])
	_strike(e, dmg, dir, force, heavy, "arrow_hit")
	if not weapon:
		return
	if fills:
		_part_action("hand", 0.5, 6.0)
	if shot != "":
		_essence_shot_hit(e, dmg, dir, shot)
	# of Embers on a bow or pistol: a hit may set the foe burning.
	var ember := gfx("embers")
	if ember > 0.0 and not e.dead and randf() < ember:
		e.ignite(Gear.EMBER_BURN["dmg"], Gear.EMBER_BURN["time"])
	# Stormstring: a full draw arcs on to one more foe (Stormtalon: two).
	var arc := rule("arc")
	if heavy and arc > 0.0 and wkind() == "bow":
		var from = e
		var struck: Array = [e]
		for i in maxi(1, int(rule("arcs"))):
			var next = null
			var best := 170.0
			for o in main.targets():
				var d: float = o.global_position.distance_to(from.global_position)
				if not (o in struck) and not o.dead and d < best:
					next = o
					best = d
			if next == null:
				break
			main.fx_bolt([from.global_position, next.global_position], Color(0.78, 0.9, 1.0))
			main.sfx("zap", 1.2, -6.0)
			next.take_hit(dmg * arc, Vector2.ZERO)
			struck.append(next)
			from = next
	# Spinecaster: every barb poisons.
	if rule("venom_shot") > 0.0 and not e.dead:
		e.add_venom(int(rule("venom_shot")))
	# Hollowmoon Bow: a full draw that hits pours essence into the hand's mark.
	if heavy and rule("draw_mark") > 0.0 and wkind() == "bow":
		var hand = bonds.get("hand")
		if hand != null:
			hand.essence = minf(hand.capacity(), hand.essence + rule("draw_mark"))


## What an essence shot does when it strikes (weapons.gd ESSENCE_SHOT):
## stone staggers, water chills, fire bursts over the foes around.
func _essence_shot_hit(e, dmg: float, dir: Vector2, kind: String) -> void:
	var es := Weapons.essence_shot(kind)
	var col := Essence.color(kind)
	if es.has("stagger") and not e.dead:
		e.stagger(float(es["stagger"]) * (0.5 if e.is_boss() else 1.0))
	if es.has("chill") and not e.dead:
		e.chill_t = maxf(e.chill_t, float(es["chill"]))
	if es.has("radius"):
		var r := float(es["radius"])
		main.fx_ring(e.global_position, col, r, 0.3, 4.0)
		main.fx_burst(e.global_position, dir, col, 10, 240.0)
		main.light_flash(e.global_position, col, 1.0, 1.4, 0.2)
		main.sfx("burn", 1.4, -8.0, 0.05)
		for o in main.targets():
			if o != e and not o.dead and o.global_position.distance_to(e.global_position) < r + o.radius:
				o.take_hit(dmg * float(es.get("share", 0.5)), (o.global_position - e.global_position).normalized(), 120.0)


## `rock`: the blow breaks poise like a heavy one (maces, hammers);
## `backstab_bonus` adds to the backstab multiplier (daggers); `stagger`
## staggers the foe for that long (the war hammer's finisher).
func _strike(e, dmg: float, dir: Vector2, force: float, heavy: bool, hit_sound := "hit", rock := false, backstab_bonus := 0.0, stagger := 0.0) -> void:
	quarry_fresh = quarry != e  # (Quarry II: not yet your Quarry, bond.gd taken_mult)
	quarry = e  # Hunter's Quarry remembers it
	var crit := false
	if unbreak_t > 0.0 and unbreak_strike > 0.0:
		dmg *= unbreak_strike  # Unbreakable's Apex: you strike at half damage
	# A staggered foe is open: a riposte deals critical damage.
	if e.stun > 0.0:
		dmg *= 2.5
		force *= 1.4
		crit = true
	# Surgeon's Vivisect: the cut found a weak point; the next hits on it are critical.
	var weak_hit := false
	if not crit and e.has_meta("weak_point"):
		var wp: Dictionary = e.get_meta("weak_point")
		if int(wp.get("n", 0)) > 0 and float(wp.get("until", 0.0)) > Time.get_ticks_msec() * 0.001:
			wp["n"] = int(wp["n"]) - 1
			dmg *= float(wp.get("mult", 2.0))
			force *= 1.4
			crit = true
			weak_hit = true
		if int(wp.get("n", 0)) <= 0 or float(wp.get("until", 0.0)) <= Time.get_ticks_msec() * 0.001:
			e.remove_meta("weak_point")
	# Windwalker passive, Featherweight: airborne foes take extra damage
	# (rank II: your strikes keep them aloft).
	if has_bond("windwalker") and e.airborne > 0.0:
		dmg *= 1.5
		if passive_rank("windwalker") >= 2:
			e.airborne = minf(e.airborne + BondScript.Bonds.passive_num("windwalker", 2, "juggle"), maxf(e.airborne, BondScript.Bonds.passive_num("windwalker", 2, "most")))
	# Ashwalker's Unseen Strike: a foe that hasn't noticed you, or lost you.
	var unseen: bool = has_bond("ashwalker") and e.unaware()
	if unseen:
		dmg *= 3.0
		main.fx_text(e.global_position + Vector2(0, -e.radius - 52.0), "Unseen", Color(0.85, 0.6, 0.5))
	vanish_t = 0.0  # striking ends Vanish
	rekindle_fought = true
	# Rekindler's Bonfire: while you burn, the foes you strike catch fire too, and each grows the payback.
	if rekindle_t > 0.0 and rekindle_per > 0.0 and not e.dead:
		Reactions.apply(main, e, "burning", float(Reactions.STATES["burning"]["seconds"]), "rekindle")
		if not e.get_instance_id() in rekindle_burned and rekindle_burned.size() < rekindle_most:
			rekindle_burned.append(e.get_instance_id())
	if ember_t > 0.0:
		ember_t = 0.0
		main.fx_text(global_position + Vector2(0, -44), "Rekindled", Color(1.0, 0.6, 0.3))
		main.light_flash(global_position, Color(1.0, 0.5, 0.25), 1.6, 1.8, 0.4)
		main.sfx("crit", 0.8)
		# Last Ember III: surviving it erupts in flame around you.
		if passive_rank("rekindler") >= 3:
			var col := Color(1.0, 0.45, 0.22)
			var r := Bonds.passive_num("rekindler", 3, "erupt_radius", 110.0)
			main.explode(global_position, r, Bonds.passive_num("rekindler", 3, "erupt", 30.0), col)
			main.add_flame(global_position, r * 0.45, 3.0, true)
			main.fx_text(global_position + Vector2(0, -60), "Last Ember erupts", col)
			main.sfx("fire_blast", 0.8)
	# Venomist's Neurotoxin: a hit on a poisoned foe paralyzes it.
	if neuro_t > 0.0 and e.venom > 0:
		neuro_t = 0.0
		e.stagger(neuro_paralyze)
		main.fx_text(e.global_position + Vector2(0, -e.radius - 40.0), "Paralyzed", Color(0.55, 0.85, 0.35))
	# Venomist's Venom Glands: weapon strikes add a weak poison.
	if has_bond("venomist"):
		e.add_venom(1)
	# A backstab: striking a foe that faces away (it committed to an attack,
	# or you rolled behind it). The back fills; a burned back loses the bonus.
	var backstab: bool = dir != Vector2.ZERO and e.face.dot(dir) > 0.5
	if backstab:
		if not _burned("back"):
			dmg *= BACKSTAB_MULT + 0.5 * graft("back") + backstab_bonus
		main.fx_text(e.global_position + Vector2(0, -e.radius - 40.0), "Backstab", Color(0.95, 0.6, 0.45))
		_part_action("back", 3.0, 10.0)
	# Stormcaller passive, Static: striking a charged foe arcs to another.
	if has_bond("stormcaller") and e.charged > 0.0:
		for other in main.targets():
			if other == e:
				continue
			if e.global_position.distance_to(other.global_position) < 150.0:
				main.fx_bolt([e.global_position, other.global_position], Color(0.95, 0.89, 0.42))
				main.sfx("zap", 1.25, -6.0)
				main.hit_kind = BondScript.HIT_KINDS["stormcaller"]
				other.take_hit(5.0, Vector2.ZERO)
				main.hit_kind = ""
				Reactions.apply(main, other, "charged", 2.0, "static")  # (the arc charges it)
				break
	# of the Riposte: ripostes and backstabs hit harder.
	if crit or backstab:
		dmg *= 1.0 + gfx("riposte")
	# Watcher's Helm: a foe you parried takes more from you for a while.
	if gfx("watch") > 0.0 and e.has_meta("watched") and float(e.get_meta("watched")) > Time.get_ticks_msec() * 0.001:
		dmg *= 1.0 + gfx("watch")
	dmg *= flow_damage  # Unmaking's flow
	# Triune Fang: the heads take turns (the lion's bite hits harder).
	var head := -1
	if hit_sound != "arrow_hit" and rule("triune") > 0.0:
		head = triune_n % 3
		triune_n += 1
		if head == 0:
			dmg *= 1.0 + rule("triune")
	var contact: Vector2 = e.global_position - dir * e.radius
	if crit:
		main.fx_text(e.global_position + Vector2(0, -e.radius - 26.0), "Weak point!" if weak_hit else "Riposte!", Color(1.0, 0.85, 0.4))
		main.fx_ring(contact, Color(1.0, 0.85, 0.4), 40.0, 0.3, 4.0)
		main.fx_burst(contact, dir, Color(1.0, 0.9, 0.6), 14, 380.0)
		main.sfx("crit")
		main.light_flash(contact, Color(1.0, 0.85, 0.5), 1.0, 1.5, 0.2)
		main.hitstop(0.14)
		main.shake(9.0)
	else:
		main.fx_burst(contact, dir, Color(1.0, 0.95, 0.85), 8 if heavy else 5)
		main.sfx("hit_heavy" if heavy else hit_sound)
		# Every blow lands with a beat of hit-pause and a little shake,
		# whatever the monster is made of (a crit's bigger ones are above).
		main.hitstop(0.085 if heavy else 0.05)
		main.shake(5.0 if heavy else 2.5)
	# The monster's body adds its own note: armour clanks, slime squelches.
	var material: String = e.MATERIAL.get(e.kind, "")
	if material != "":
		main.sfx(material, 1.0, -2.0 if heavy or crit else -4.0)
	var weak_spot: bool = backstab or e.open_t > 0.0  # (Diagnosis II: where it's weak)
	if hit_sound != "arrow_hit" and rule("chill") > 0.0:
		main.hit_kind = "frost"  # (a chilling blow: a drenched foe takes double, bond.gd taken_mult)
	e.take_hit(dmg, dir, force, heavy or crit or rock, flow_pierce or gfx("guardbreak") > 0.0)  # (a Wardbreaker Charm: through shells)
	if unseen:
		BondScript.manticore().unseen_struck(self, e, dmg, dir)  # (Unseen Strike II and III; Ashfall's Apex)
	if main.hit_kind == "frost":
		main.hit_kind = ""
	quarry_fresh = false
	if thunderhead_t > 0.0 and thunderhead_bolt > 0.0 and not e.dead:
		BondScript.gryphon().sky_bolt(main, e, thunderhead_bolt, BondScript.Bonds.BONDS["stormcaller"]["color"])  # Thunderhead's Apex
	# Surgeon's Diagnosis II: striking a foe where it's weak staggers it (now and then).
	if weak_spot and not e.dead and passive_rank("surgeon") >= 2 and float(e.get_meta("diagnosed", -99.0)) + Bonds.passive_num("surgeon", 2, "weak_every", 3.0) <= Time.get_ticks_msec() * 0.001:
		e.set_meta("diagnosed", Time.get_ticks_msec() * 0.001)
		e.stagger(Bonds.passive_num("surgeon", 2, "weak_stagger", 0.5) * (0.5 if e.is_boss() else 1.0))
		main.fx_text(e.global_position + Vector2(0, -e.radius - 52.0), "Weak spot", Color(0.85, 0.9, 0.95))
	# Named weapons: a Coral Trident slows, a Stinger Dagger poisons.
	if hit_sound != "arrow_hit" and not e.dead:
		if rule("chill") > 0.0:
			e.chill_t = maxf(e.chill_t, rule("chill"))
		if rule("venom") > 0.0:
			e.add_venom(int(rule("venom")))
		_beast_rules(e, head, heavy or rock)
	# of Venom, a Viper Ring: now and then a hit poisons.
	if not e.dead and gfx("venom_chance") > 0.0 and randf() < gfx("venom_chance"):
		e.add_venom(1)
	# A finishing blow fills the back too.
	if e.dead:
		_part_action("back", 2.0, 6.0)
		_on_kill()
	elif stagger > 0.0:
		e.stagger(stagger * (0.5 if e.is_boss() else 1.0))
		main.fx_text(e.global_position + Vector2(0, -e.radius - 22.0), "Staggered", Color(1.0, 0.89, 0.63))
		# Thornmaul: a staggering finisher throws thorns at the foes nearby.
		var thorn := rule("thorn_burst")
		if thorn > 0.0:
			for o in main.targets():
				if o != e and o.global_position.distance_to(e.global_position) < 110.0:
					main.fx_burst(o.global_position, (o.global_position - e.global_position).normalized(), Color(0.65, 0.85, 0.4), 6, 260.0)
					o.take_hit(thorn, (o.global_position - e.global_position).normalized(), 120.0)


## The beasts' melee weapons, after a blow lands (not on a kill): the
## Triune Fang's goat staggers and its serpent poisons; a Wyrmspine Mace's
## heavy blow cracks the floor round the foe.
func _beast_rules(e, head: int, heavy: bool) -> void:
	if head == 1 and not e.is_boss():
		e.stagger(0.5)
	elif head == 2:
		e.add_venom(2)
	var quake := rule("quake")
	if quake > 0.0 and heavy:
		main.fx_ring(e.global_position, Color(0.86, 0.8, 0.66), 110.0, 0.35, 5.0)
		main.shake(5.0)
		for o in main.targets():
			if o != e and not o.dead and o.global_position.distance_to(e.global_position) < 110.0 + o.radius:
				o.take_hit(quake, (o.global_position - e.global_position).normalized(), 120.0)
				if not o.is_boss() and not o.dead:
					o.stagger(0.6)


## A foe fell to your weapon: what your gear does then (a Sunsteel Blade's
## and a Reaver's healing, Quickhand Gloves' and a Pearl Ring's essence).
func _on_kill() -> void:
	if gfx("kill_sta") > 0.0:
		sta = minf(max_sta, sta + gfx("kill_sta"))  # a Garnet Ring
	if rule("kill_load") > 0.0 and wkind() == "gun":
		ammo_left()
		ammo = gun_shots()  # Emberlock: a kill fills its chamber
		reload_t = 0.0
	var heal := (rule("kill_heal") + gfx("kill_heal")) * heal_mult()  # (of Mending, a Heartroot)
	if heal > 0.0 and hp < max_health():
		hp = minf(max_health(), hp + heal)
		main.fx_text(global_position + Vector2(0, -44), "+%d" % int(heal), Color(0.6, 1.0, 0.7))
	var hand = bonds.get("hand")
	if hand != null:
		var more: float = rule("kill_mark") + gfx("kill_fill") * hand.capacity()
		if more > 0.0:
			hand.essence = minf(hand.capacity(), hand.essence + more)
	var pearl := gfx("kill_essence")
	if pearl > 0.0 and not bonds.is_empty():
		var emptiest = null
		for b in bonds.values():
			if emptiest == null or b.essence / b.capacity() < emptiest.essence / emptiest.capacity():
				emptiest = b
		emptiest.essence = minf(emptiest.capacity(), emptiest.essence + pearl)


func _try_parry() -> bool:
	if parry_cd > 0.0:
		return false
	# The tail of a swing can be cancelled into a parry, but not its start.
	if attack_cd > 0.0 and swing.get("recover", 0.0) - attack_cd < 0.12:
		return false
	attack_cd = 0.0
	lunge_t = 0.0
	drawing = false
	var cane := float(wdata().get("parry", 0.0)) if wkind() == "melee" else 0.0  # a cane in hand
	parry_window = PARRY_WINDOW * (0.6 if _burned("brow") else 1.0) * (1.0 + 0.25 * graft("brow")) * (1.0 + gfx("parry") + cane)  # gauntlets shorten it
	parry_t = parry_window
	parry_cd = float(Combat.CLIMBER["parry_cooldown"])
	var threat := _nearest_threat()
	if threat != Vector2.ZERO:
		aim = threat
	return true


## The direction of the most pressing danger: a monster mid-attack or an
## incoming arrow (whichever is closest), else the nearest monster.
func _nearest_threat() -> Vector2:
	var best := Vector2.ZERO
	var best_d := 230.0
	for e in main.targets():
		if e.is_attacking():
			var d: float = global_position.distance_to(e.global_position)
			if d < best_d:
				best_d = d
				best = e.global_position
	for c in main.get_children():
		if "friendly" in c and not c.friendly:
			var d2: float = global_position.distance_to(c.global_position)
			if d2 < minf(best_d, 170.0):
				best_d = d2
				best = c.global_position
	if best == Vector2.ZERO:
		best_d = 130.0
		for e in main.targets():
			var d3: float = global_position.distance_to(e.global_position)
			if d3 < best_d:
				best_d = d3
				best = e.global_position
	if best == Vector2.ZERO:
		return Vector2.ZERO
	return (best - global_position).normalized()


func _try_cast(part: String) -> bool:
	var b = bonds.get(part)
	if b == null:
		return true
	if b.has_method("blocked") and b.blocked():  # (an Unbound's part gone dark: unbound_run.gd)
		main.fx_text(global_position + Vector2(0, -40), main.unbound.TEXT["dark"] % BondScript.PART_NAMES[b.tech_part()], Color(0.6, 0.6, 0.65))
		return true
	if attack_cd > 0.0 or drawing:
		return false
	cast_part = part
	cast_total = b.windup() * (0.7 if has_bond("rune_artist") else 1.0)  # Steady Mind
	cast_t = cast_total
	main.sfx("charge", 1.0, 0.0, 0.03)
	return true


func _release_cast() -> void:
	var b = bonds[cast_part]
	# Firebird Form: a spell marked "free_in_form" (Wingburst, Cinder Dive) costs nothing.
	var free: bool = main.in_sigil(global_position) or (firebird_t > 0.0 and bool(b.spell().get("free_in_form", false)))
	# Spellweave Ring: every third spell costs nothing.
	spells_cast += 1
	Makers.feed(main, "cast", 1.0, b.id + ":" + String(b.spell()["name"]))
	var weave := int(gfx("spellweave"))
	if weave > 0 and spells_cast % weave == 0 and not free:
		free = true
		main.fx_text(global_position + Vector2(0, -52), "Spellweave", Color(0.85, 0.55, 0.95))
	if "cost_mult" in b:
		b.cost_mult = 1.0 - BondScript.wyvern().circle_thrift(self)  # (Runesmith III: inside your circles)
	var paid: String = b.pay(free)
	if "cost_mult" in b:
		b.cost_mult = 1.0
	var part_name: String = BondScript.PART_NAMES[cast_part]
	# Ring of the Overdrawn: the first overdraw each floor doesn't burn.
	if paid == "burned" and gfx("overdraw_guard") > 0.0 and once_a_floor("overdraw"):
		b.burned = false
		paid = "guarded"
		main.fx_text(global_position + Vector2(0, -40), "The ring takes the burn", Color(0.95, 0.5, 0.3))
	if paid == "burned":
		# Overdraw: a weaker, desperate cast, and the body part burns.
		main.fx_text(global_position + Vector2(0, -40), "%s burned!" % part_name, Color(1.0, 0.4, 0.3))
		main.fx_burst(global_position, Vector2.ZERO, Color(1.0, 0.4, 0.25), 12, 200.0)
		main.sfx("burn")
		main.light_flash(global_position, Color(1.0, 0.4, 0.2), 1.2, 1.6, 0.4)
		main.shake(5.0)
	elif paid == "torn":
		# Overdrawing a burned mark tears it: the missing essence comes out of you.
		var cost_hp: float = maxf(4.0, b.missing * b.TEAR_HEALTH)
		main.fx_text(global_position + Vector2(0, -40), "%s mark tears! -%d" % [part_name, int(cost_hp)], Color(1.0, 0.25, 0.2))
		main.fx_burst(global_position, Vector2.ZERO, Color(0.9, 0.15, 0.12), 18, 260.0)
		main.sfx("burn", 0.8)
		main.sfx("hurt", 0.9, -4.0)
		main.light_flash(global_position, Color(1.0, 0.2, 0.15), 1.3, 1.8, 0.4)
		main.shake(7.0)
		main.hurt_flash = 0.35
		hp -= cost_hp
		if hp <= 0.0 and _defy_death():
			hp = maxf(hp, 1.0)
		if hp <= 0.0:
			hp = 0.0
			dead = true
			main.sfx("death", 1.0, 0.0, 0.0)
			main.on_player_died()
			return
	# Count the foes the spell hits at once: several fill the throat.
	main.cast_hits = 0
	var sb_cast = main.secret_tools.before_cast(b) if main.secret_tools != null else null  # (the Developer's Splice)
	main.counting_hits = true
	b.cast(self)
	main.counting_hits = false
	if main.hints != null:
		main.hints.cast_done(b)  # (the first cast of each: its name and what it does)
	if sb_cast != null:
		main.secret_tools.after_cast(b, sb_cast)
	if main.puzzle != null:  # (an Essence Lock answers to a spell of its essence)
		main.puzzle.offer(String(b.data().get("affinity", "")), global_position, "bond")
	b.overdraw_mult = 1.0
	if main.cast_hits > 1:
		_part_action("throat", 2.0 * (main.cast_hits - 1), 8.0 * (main.cast_hits - 1))


var fire_t := 0.0  # time spent standing in fire, ticking toward the next burn

# The Wyvern's bonds.
var heat := 0.0  # Flameblade's Heat: 0..100, built by strikes in a row
var heat_idle := 0.0  # time since the last strike landed
var kindle_t := 0.0  # Kindle Blade: the weapon burns
var kindle_dmg := 0.0
var kindle_sustain := false
var kindle_color := Color(1.0, 0.5, 0.24)
var kindle_cap := 100.0  # Forge Heart: how far heat climbs while kindled (it never fades then)
var kindle_brand := 0.0  # Brand: seconds a kindled strike brands a foe (wyvern.gd)
var still_for := 0.0  # Shifting Sands III: how long you've stood still


## How high heat climbs now: 100, or Forge Heart's cap while kindled.
func heat_cap() -> float:
	return maxf(100.0, kindle_cap) if kindle_t > 0.0 else 100.0
var searing_dmg := 0.0  # Searing Parry: a kindled parry explodes for this much
var bladeward_t := 0.0  # Bladeward: blades orbit you
var bladeward_dmg := 0.0
var bladeward_r := 48.0
var bladeward_tick := 0.0
var bladeward_color := Color(0.65, 0.89, 0.71)
var rune_gear := ""  # Inscribe: "sharpness", "warding" or "swiftness" for this floor
var camp_rune := ""  # Runesmith: a rune inscribed at a camp, for the rest of the climb
var camp_rune2 := ""  # Runesmith II: a second camp rune, for the rest of the climb


## A rune on your gear: this floor's (Inscribe, or the camp's) or Runesmith II's second.
func has_rune(r: String) -> bool:
	return rune_gear == r or (camp_rune2 == r and r != "")

# The Manticore's bonds.
var neuro_t := 0.0  # Neurotoxin: the next hit on a poisoned foe paralyzes it
var neuro_paralyze := 2.0
var vanish_t := 0.0  # Vanish: unseen until you strike

# Jumping.
var jump_t := 0.0  # time left in the air
var jump_total := 0.0
var jump_vel := Vector2.ZERO
var glide_left := 0.0  # Flamewing's Phoenix Glide: extra air time while jump is held
var last_safe := Vector2.ZERO  # the last solid ground you stood on

# The Firebird's bonds.
var aura_part := ""  # Heat Aura: the mark it burns from ("" when off)
var aura_time := 0.0
var aura_dmg := 3.0
var aura_r := 62.0
var aura_drain := 2.5
var aura_grows := false
var aura_ramp := 10.0  # a growing aura reaches double heat over this many seconds (Furnace: sooner)
var aura_heat_mult := 1.0  # Furnace: heat builds this many times as fast
var aura_peak := 1.0  # a growing aura's damage rises by this share at its hottest (Furnace: more)
var aura_slow := false  # Furnace: foes in the aura are slowed
var aura_heat := 0.0  # built up while the aura burns foes; Wingburst releases it
var aura_tick := 0.0
var aura_color := Color(1.0, 0.68, 0.28)
var warmth_t := 0.0
var warmth_heal := 2.5
var firebird_t := 0.0  # Firebird Form
var firebird_fly := false  # its Apex: you fly over chasms and hazards while it lasts (flying())
var rekindle_t := 0.0  # Rekindle: burning now, paid back later
var rekindle_total := 5.0
var rekindle_loss := 0.0
var rekindle_lost := 0.0
var rekindle_fought := false
var rekindle_spread := false
var rekindle_tick := 0.0
var rekindle_per := 0.0  # Bonfire: the payback grows this much for each foe you set burning
var rekindle_most := 0  # (counting up to this many)
var rekindle_burned: Array = []  # (those foes, by instance id)
var rekindle_shield := 0.0  # Cauterize: the payback comes as a barrier this many times what you lost
var rekindle_shield_t := 10.0  # (lasting this long)
var desperate_t := 0.0
var pyre_t := 0.0
var pyre_dmg := 30.0
var phoenix_t := 0.0
var phoenix_regain := 0.0  # its Apex: at its end you regain this share of what it held back
var phoenix_held := 0.0  # (the health it kept you from losing)
var ember_t := 0.0  # Last Ember: burning at 1 health; strike to stay standing
var ember_used := false:  # true once Last Ember is spent for the floor (a new floor sets it false)
	set(v):
		ember_used = v
		if not v:
			ember_count = 0
var ember_count := 0  # (Last Ember II works twice a floor: how many times it has this floor)

# The Chimera's bonds.
var call_index := 0  # Covenant: the next creature of the retinue
var chimera_t := 0.0  # Grafter's Chimera Form


var poison_t := 0.0  # poisoned: a little damage every half second
var poison_tick := 0.0


## Grafter's Adaptive Flesh: how strongly a graft on this body part works
## (0 without one; doubled in Chimera Form).
func graft(part: String) -> float:
	if not has_bond("grafter") or not main.grafts.has(part):
		return 0.0
	return 2.0 if chimera_t > 0.0 else 1.0


## Stubborn Heart: below a third of your health you move and recover faster.
func _stubborn() -> bool:
	return has_bond("rekindler") and hp < max_hp / 3.0


## Something would kill you. True if you stay standing instead (the caller
## keeps you at 1 health): the dev tool, Phoenix Heart, Pyre Oath, Last Ember.
func _defy_death() -> bool:
	if main.dev_no_death:
		return true
	if phoenix_t > 0.0:
		main.fx_text(global_position + Vector2(0, -44), "Phoenix Heart", Color(1.0, 0.6, 0.3))
		phoenix_held = minf(phoenix_held + 1.0 - hp, max_health())  # (its Apex gives this back at the end)
		return true
	if pyre_t > 0.0:
		pyre_t = 0.0
		main.explode(global_position, 100.0, pyre_dmg, Color(1.0, 0.4, 0.2))
		main.fx_text(global_position + Vector2(0, -44), "Pyre Oath", Color(1.0, 0.5, 0.25))
		return true
	if has_bond("rekindler") and not ember_used and ember_t <= 0.0:
		ember_count += 1
		# (Last Ember II: twice a floor)
		if ember_count >= (int(Bonds.passive_num("rekindler", 2, "uses", 2.0)) if passive_rank("rekindler") >= 2 else 1):
			ember_used = true
		ember_t = 3.0
		main.fx_text(global_position + Vector2(0, -44), "Last Ember: strike to stay standing!", Color(1.0, 0.5, 0.25))
		if Pacts.has(self, "undying"):  # Undying (Warden and Rekindler): a barrier rises too
			raise_barrier(Pacts.num("undying", "shield"), Pacts.num("undying", "seconds"), false, Pacts.PACTS["undying"]["color"])
		main.sfx("burn", 0.7)
		return true
	if ember_t > 0.0:
		return true  # still burning on your last ember
	if flow_refuse and once_a_floor("life_refuse"):
		_refuse_fall()
		return true
	if gfx("rebirth") > 0.0 and not rebirth_used:
		_rebirth()
		return true
	return main.proving_spare()  # the ordinary Proving casts you down instead


## Sunplume Mantle: once a climb, a killing blow bursts you into flame and
## you rise again with some of your health, burning the foes around you.
func _rebirth() -> void:
	rebirth_used = true
	var col := Color(1.0, 0.55, 0.22)
	hp = maxf(hp, max_health() * gfx("rebirth"))
	iframes = maxf(iframes, 1.5)
	main.add_flame(global_position, 70.0, 3.0, true)
	main.fx_text(global_position + Vector2(0, -52), "Reborn in flame", col)
	main.fx_ring(global_position, col, 90.0, 0.55, 6.0)
	main.fx_burst(global_position, Vector2.UP, Color(1.0, 0.85, 0.5), 30, 300.0)
	main.light_flash(global_position, col, 2.4, 2.2, 0.7)
	main.sfx("burn", 0.7, 0.0, 0.0)


## Life's flow at step 4: once a floor, a killing blow leaves you at low
## health instead, in a green burst that throws back the monsters near you.
func _refuse_fall() -> void:
	var col := Secret.color("life")
	hp = maxf(hp, max_health() * Secret.REFUSE_HEALTH)
	iframes = maxf(iframes, 1.2)
	for e in main.targets():
		var to: Vector2 = e.global_position - global_position
		if to.length() < Secret.REFUSE_PUSH + e.radius and not e.is_boss():
			e.knock = to.normalized() * 380.0
			e.stagger(0.6)
	main.fx_text(global_position + Vector2(0, -52), Secret.TEXT["refuse"], col)
	main.fx_ring(global_position, col, Secret.REFUSE_PUSH, 0.55, 5.0)
	main.fx_burst(global_position, Vector2.UP, Secret.KINDS["life"]["light"], 26, 260.0)
	main.light_flash(global_position, col, 2.2, 2.0, 0.7)
	main.sfx("ready", 0.6, 0.0, 0.0)
	main.shake(6.0)


## A foe fell (main.on_enemy_killed): Life mends you; Unmaking's slain foe
## comes apart and hurts the monsters beside it.
func on_flow_kill(e) -> void:
	if dead or e == null or e.ally:
		return
	if flow_mend > 0.0 and hp < max_health():
		var got := mend_by(flow_mend)
		if got >= 1.0:
			main.fx_text(global_position + Vector2(0, -40), "+%d" % int(round(got)), Secret.KINDS["life"]["light"])
			main.sfx("life_mend", 1.0, 0.0)
	if flow_undo > 0.0 and not _undoing:
		_undoing = true  # (a foe undone by the undoing doesn't undo again)
		var col := Secret.color("unmaking")
		var at: Vector2 = e.global_position
		var dmg := minf(float(e.max_hp) * flow_undo, Secret.UNDO_CAP)
		main.fx_ring(at, col, Secret.UNDO_REACH, 0.4, 4.0)
		main.fx_burst(at, Vector2.ZERO, Secret.KINDS["unmaking"]["light"], 18, 320.0)
		main.sfx("unmake", 1.0, 0.0)
		for o in main.targets():
			if o != e and not o.dead and not o.ally and o.global_position.distance_to(at) < Secret.UNDO_REACH + o.radius:
				main.fx_bolt([at, o.global_position], col)
				o.take_hit(dmg, (o.global_position - at).normalized(), 120.0)
		_undoing = false


## Unmaking's aura (step 2 on): awake monsters beside you erode.
func _tick_erode(delta: float) -> void:
	if flow_erode <= 0.0 or dead:
		return
	_erode_t -= delta
	if _erode_t > 0.0:
		return
	_erode_t = Secret.ERODE_TICK
	var col: Color = Secret.KINDS["unmaking"]["light"]
	for e in main.targets():
		if e.dead or e.ally or not e.aware:
			continue
		if e.global_position.distance_to(global_position) < Secret.ERODE_REACH + e.radius:
			main.fx_burst(e.global_position, (global_position - e.global_position).normalized(), col, 4, 90.0)
			e.take_hit(flow_erode * Secret.ERODE_TICK, Vector2.ZERO, 0.0)


func _tick_fire_bonds(delta: float) -> void:
	chimera_t -= delta
	warmth_t -= delta
	firebird_t -= delta
	desperate_t -= delta
	pyre_t -= delta
	phoenix_t -= delta
	# Phoenix Heart's Apex: at its end, the health it held back comes back to you.
	if phoenix_t <= 0.0 and phoenix_held > 0.0:
		var back := minf(phoenix_held * phoenix_regain, max_health() - hp)
		phoenix_held = 0.0
		if back >= 1.0 and not dead:
			hp += back
			main.fx_text(global_position + Vector2(0, -52), "Phoenix Heart +%d" % int(back), Color(1.0, 0.6, 0.3))
			main.fx_burst(global_position, Vector2.UP, Color(1.0, 0.75, 0.4), 22, 260.0)
			main.light_flash(global_position, Color(1.0, 0.55, 0.25), 2.0, 2.0, 0.5)
			main.sfx("ready", 0.7)
	# Last Ember: burn out unless you land a hit in time.
	if ember_t > 0.0:
		ember_t -= delta
		hp = 1.0
		if ember_t <= 0.0 and not dead and not main.proving_spare():
			hp = 0.0
			dead = true
			main.sfx("death", 1.0, 0.0, 0.0)
			main.on_player_died()
			return
	# Heat Aura: burns foes near you, drains its mark, builds heat.
	if aura_part != "":
		var b = bonds.get(aura_part)
		if b == null or b.essence <= 0.0:
			aura_part = ""
		else:
			b.essence = maxf(0.0, b.essence - aura_drain * delta)
			aura_time += delta
			aura_tick -= delta
			if warmth_t > 0.0:
				hp = minf(max_health(), hp + warmth_heal * heal_mult() * delta)
			if aura_tick <= 0.0:
				aura_tick = 0.5
				var r := aura_r * (2.0 if firebird_t > 0.0 else 1.0)
				var dmg := aura_dmg * (1.0 + minf(aura_time / maxf(aura_ramp, 0.1), 1.0) * aura_peak if aura_grows else 1.0)
				for e in main.targets():
					if e.global_position.distance_to(global_position) < r + e.radius:
						e.take_hit(dmg, Vector2.ZERO, 0.0)
						aura_heat = minf(60.0, aura_heat + dmg * aura_heat_mult)
						if not e.dead:
							Reactions.apply(main, e, "burning", 1.5, "aura", maxf(1.0, dmg * 0.3))
						if aura_slow and not e.dead:  # Furnace: the heat slows them
							Reactions.apply(main, e, "slowed", 0.8, "aura")
	# Rekindle: lose health now, regain twice that later if you kept fighting.
	if rekindle_t > 0.0:
		rekindle_t -= delta
		rekindle_tick -= delta
		if rekindle_tick <= 0.0:
			rekindle_tick = 0.5
			var loss := rekindle_loss * 0.5 / rekindle_total
			if hp - loss > 1.0:
				hp -= loss
				rekindle_lost += loss
			if rekindle_spread:
				for e in main.targets():
					if e.global_position.distance_to(global_position) < 60.0 + e.radius:
						e.take_hit(3.0, Vector2.ZERO, 0.0)
		if rekindle_t <= 0.0:
			# Bonfire: the payback grows with each foe you set burning.
			var back := rekindle_lost * (2.0 + rekindle_per * rekindle_burned.size())
			if rekindle_fought and rekindle_shield > 0.0:
				# Cauterize: the payback comes as a barrier instead.
				var shield := rekindle_lost * rekindle_shield
				raise_barrier(shield, rekindle_shield_t, false, Color(1.0, 0.55, 0.3))
				main.fx_text(global_position + Vector2(0, -44), "Cauterized: shield %d" % int(shield), Color(1.0, 0.6, 0.3))
				main.sfx("ready", 0.8)
			elif rekindle_fought:
				hp = minf(max_health(), hp + back)
				main.fx_text(global_position + Vector2(0, -44), "Rekindled +%d" % int(back), Color(1.0, 0.6, 0.3))
				main.sfx("ready", 0.8)
			else:
				main.fx_text(global_position + Vector2(0, -44), "the fire goes out", Color(0.7, 0.6, 0.55))


## An overdrawn quake knocks you down: a short stagger of your own.
func stagger_self(seconds: float) -> void:
	attack_cd = maxf(attack_cd, seconds)
	cast_t = 0.0
	main.fx_text(global_position + Vector2(0, -40), "Knocked down", Color(0.85, 0.7, 0.42))


## A sting that landed: poisoned for a few seconds (a new sting refreshes it).
func poison(seconds: float) -> void:
	if gfx("antivenom") > 0.0:
		return  # (an Antivenom: proof against poison for a while)
	if poison_t <= 0.0:
		main.fx_text(global_position + Vector2(0, -40), "Poisoned", Color(0.55, 0.85, 0.35))
	poison_t = maxf(poison_t, seconds * (1.0 - gfx("ailment")))  # Travel Cloak


func _tick_poison(delta: float) -> void:
	if poison_t <= 0.0 or dead:
		return
	poison_t -= delta
	poison_tick -= delta
	if poison_tick > 0.0:
		return
	poison_tick = 0.5
	hp -= 2.0
	main.fx_text(global_position + Vector2(0, -24), "-2", Color(0.55, 0.85, 0.35))
	if hp <= 0.0 and _defy_death():
		hp = maxf(hp, 1.0)
	if hp <= 0.0:
		hp = 0.0
		dead = true
		main.sfx("death", 1.0, 0.0, 0.0)
		main.on_player_died()


## Standing on burning floor: a small burn every half second (rolling through is free).
func stand_in_fire(delta: float) -> void:
	if iframes > 0.0 or dead or in_air() or has_bond("flamewing"):  # Fireproof
		return
	_burn_floor(delta)


## Flamewing's Fireproof from rank II: standing in fire (yours or not) heals
## you a little; from rank III, fire that would hurt you feeds the aura too
## (main.gd, every frame you stand in burning floor).
var fire_mend_t := 0.0


func fire_underfoot(delta: float, hostile: bool) -> void:
	var rank := passive_rank("flamewing")
	if rank < 2 or dead or in_air():
		return
	fire_mend_t += delta
	if fire_mend_t < 0.5:
		return
	fire_mend_t = 0.0
	var got := mend_by(Bonds.passive_num("flamewing", 2, "fire_heal", 1.5) * heal_mult())
	if got >= 1.0:
		main.fx_text(global_position + Vector2(0, -24), "+%d" % int(round(got)), Color(1.0, 0.75, 0.4))
	if hostile and rank >= 3:
		feed_aura(1.0)


## Fireproof III: fire that would have hurt you feeds the aura's heat and
## the Flamewing mark's essence instead (`share`: 1 for a half second of
## burning floor; a fire trap's blast gives more).
func feed_aura(share: float) -> void:
	if passive_rank("flamewing") < 3:
		return
	aura_heat = minf(60.0, aura_heat + Bonds.passive_num("flamewing", 3, "feed_heat", 8.0) * share)
	for b in bonds.values():
		if b.id == "flamewing":
			b.essence = minf(b.capacity(), b.essence + Bonds.passive_num("flamewing", 3, "feed_essence", 1.5) * share)
	main.fx_burst(global_position, Vector2.UP, Color(1.0, 0.7, 0.3), 4, 120.0)


func _burn_floor(delta: float) -> void:
	fire_t += delta
	if fire_t < 0.5:
		return
	fire_t = 0.0
	var burn := 4.0 * (1.0 - gfx("ailment")) * (1.0 - gfx("footing"))  # Travel Cloak; of Footing
	hp -= burn
	main.fx_text(global_position + Vector2(0, -24), "-%d" % int(round(burn)), Color(1.0, 0.55, 0.25))
	main.sfx("burn", 1.3, -10.0)
	if hp <= 0.0 and _defy_death():
		hp = maxf(hp, 1.0)
	if hp <= 0.0:
		hp = 0.0
		dead = true
		main.sfx("death", 1.0, 0.0, 0.0)
		main.on_player_died()


## Called by monsters and projectiles when an attack reaches you.
## `unblockable` attacks (a ring of lightning, a diving landing) can't be
## parried or warded: roll through them or get out of the way.
func receive_attack(dmg: float, source, unblockable := false) -> void:
	if dead:
		return
	if iframes > 0.0:
		on_dodge()
		return
	if unblockable:
		source = null  # nothing to parry or turn
	if unbreak_t > 0.0:
		unbreak_stored += dmg  # (its Apex: it bursts out at the end)
		main.fx_text(global_position + Vector2(0, -30), "Unbreakable", barrier_color)
		main.sfx("hit_armor", 1.2, -4.0)
		return
	if absorb_t > 0.0:
		barrier_hp += dmg
		barrier_stored += dmg
		barrier_t = maxf(barrier_t, 2.0)
		main.fx_text(global_position + Vector2(0, -30), "Absorbed %d" % int(dmg), barrier_color)
		main.sfx("parry", 0.6, -6.0)
		return
	if parry_t > 0.0 and source != null:
		var to_source: Vector2 = (source.global_position - global_position).normalized()
		if aim.dot(to_source) > -0.1:  # anything in front of you, roughly
			_on_parry(source, parry_window - parry_t <= PARRY_PERFECT)
			return
	# Warden's Heavy Frame: keep holding parry to block.
	if source != null and has_bond("warden") and parry_t <= 0.0 and Input.is_action_pressed("parry") and attack_cd <= 0.0:
		var to_src: Vector2 = (source.global_position - global_position).normalized()
		if aim.dot(to_src) > 0.0 and sta >= 12.0:
			sta -= 12.0
			sta_delay = 0.8
			dmg *= 0.3
			main.fx_text(global_position + Vector2(0, -30), "Blocked", Color(0.85, 0.71, 0.42))
			main.sfx("hit_armor", 1.0, -2.0)
	if hurt_t > 0.0:
		return
	# Pressure II (Deepcaller): a badly hurt foe near you hits softer.
	if source != null and is_instance_valid(source) and "max_hp" in source and source.hp < source.max_hp * 0.5 \
			and source.global_position.distance_to(global_position) < BondScript.PRESSURE_REACH and passive_rank("deepcaller") >= 2:
		dmg *= 1.0 - BondScript.Bonds.passive_num("deepcaller", 2, "softer")
	# The Warden's barrier soaks damage first (Moving Wall: blows from the
	# wall's side wear it slower; Bastion: it grows back from each blow).
	var steadfast := barrier_hp > 0.0
	if barrier_hp > 0.0:
		var wear := 1.0
		if barrier_front < 1.0 and source != null and is_instance_valid(source) and "global_position" in source \
				and absf(aim.angle_to(source.global_position - global_position)) <= deg_to_rad(barrier_wall) + 0.1:
			wear = barrier_front
		var take := minf(barrier_hp / wear, dmg)
		barrier_hp -= take * wear
		barrier_stored += take
		dmg -= take
		if barrier_grow > 0.0 and barrier_hp > 0.0:
			barrier_hp = minf(maxf(barrier_cap, barrier_hp), barrier_hp + take * barrier_grow)
		main.fx_ring(global_position, barrier_color, radius + 10.0, 0.2, 2.0)
		if barrier_hp <= 0.0:
			_break_barrier(true)
		if dmg <= 0.0:
			main.sfx("hit_armor", 1.3, -4.0)
			return
	if has_rune("warding"):
		dmg *= 0.75
	dmg *= BondScript.manticore().hardened(self)  # (Shifting Sands III: standing still)
	dmg *= 1.0 - 0.15 * graft("heart")
	if gfx("still_guard") > 0.0 and velocity.length() < 12.0 and roll_t <= 0.0:
		dmg *= 1.0 - gfx("still_guard")  # Rootbound Greaves: standing your ground
	# Armor takes the edge off attacks that land (poison and fire tick past it):
	# the chest, helm and legs together, up to Gear.PROTECTION_CAP.
	var raw := dmg
	dmg *= 1.0 - protection()
	hp -= dmg
	_thorns(source)
	Reactions.from_monster(main, self, source)  # (off unless reactions.gd CLIMBER "enabled")
	if gfx("grasp") > 0.0 and source is Node and is_instance_valid(source) and "chill_t" in source \
			and source.global_position.distance_to(global_position) < Gear.THORNS_REACH + float(source.get("radius")):
		source.chill_t = maxf(source.chill_t, gfx("grasp"))  # Deepcoil Coat: gripped
	wear_gear("hit")
	hits_taken += 1  # (a sealed wing's "take no hit" counts these)
	Makers.feed(main, "wound", dmg / maxf(max_health(), 1.0))
	hurt_t = float(Combat.CLIMBER["grace"])  # longer grace after a hit, so a crowd can't chain-hit you
	squash = 1.0
	if source != null and not steadfast:
		var planted: bool = has_bond("sandshaper") or (gear_fx.get("steady", false) and raw < Gear.LIGHT_BLOW) or stone_t > 0.0  # Rooted Stance; Hobnail Boots; Stoneskin
		knock = Vector2.ZERO if planted else (global_position - source.global_position).normalized() * float(Combat.CLIMBER["knockback"])
	# Getting hit interrupts swings, draws and cast wind-ups (not while
	# the Warden's barrier holds: Steadfast).
	if not steadfast:
		cast_t = 0.0
		lunge_t = 0.0
		drawing = false
		combo = 0
	drink_target = null
	drink_t = 0.0  # (a hit breaks a drain: Drink Deep's Apex jumps only on a kill)
	main.fx_text(global_position + Vector2(0, -24), "-%d" % int(dmg), Color(1.0, 0.42, 0.34))
	main.fx_burst(global_position, knock.normalized(), Color(1.0, 0.4, 0.34), 8)
	main.sfx("hurt")
	main.hitstop(0.1)
	main.shake(8.0)
	main.hurt_flash = 0.35
	if hp <= 0.0 and _defy_death():
		hp = maxf(hp, 1.0)
	if hp <= 0.0:
		hp = 0.0
		dead = true
		main.sfx("death", 1.0, 0.0, 0.0)
		main.on_player_died()
	else:
		# The heart fills when you take a hit and survive.
		_part_action("heart", 4.0, 8.0)
		_low_health_rules()


## Thorns (a trait, Barnacle Mail): a foe that strikes you up close takes some back.
func _thorns(source) -> void:
	var t := gfx("thorns")
	if t <= 0.0 or source == null or not is_instance_valid(source) or not source.has_method("take_hit") or not ("dead" in source):
		return
	if source.dead or source.global_position.distance_to(global_position) > Gear.THORNS_REACH + float(source.get("radius") if "radius" in source else 0.0):
		return
	source.take_hit(t, (source.global_position - global_position).normalized(), 60.0)
	main.fx_burst(source.global_position, (source.global_position - global_position).normalized(), Color(0.75, 0.8, 0.6), 5, 200.0)


## Once a floor, low on health: an Emberkin Mantle heals, Bastion Plate
## raises a barrier.
func _low_health_rules() -> void:
	var mend := gfx("ember_mend")
	if mend > 0.0 and hp < max_health() * 0.2 and once_a_floor("ember_mend"):
		heal_left += mend
		heal_rate = maxf(heal_rate, mend / 2.0)
		main.fx_text(global_position + Vector2(0, -48), "The mantle smoulders: +%d" % int(mend), Color(1.0, 0.6, 0.3))
		main.light_flash(global_position, Color(1.0, 0.55, 0.25), 1.2, 1.6, 0.4)
	var ink := gfx("ink")
	if ink > 0.0 and hp < max_health() * 0.5 and once_a_floor("ink"):
		main.smokes.append({"pos": global_position, "r": 110.0, "t": ink})  # Deepcoil Coat: a cloud of ink
		main.fx_burst(global_position, Vector2.ZERO, Color(0.12, 0.16, 0.24), 24, 200.0)
		main.fx_text(global_position + Vector2(0, -48), "Ink", Color(0.5, 0.7, 0.8))
	var bastion := gfx("bastion")
	if bastion > 0.0 and hp < max_health() * 0.3 and once_a_floor("bastion"):
		raise_barrier(bastion, 6.0, false, Color(0.9, 0.85, 0.6))
		main.fx_text(global_position + Vector2(0, -48), "Bastion", Color(0.9, 0.85, 0.6))


## Warden's Turning Ward.
## Warden's Barrier.
func raise_barrier(shield: float, duration: float, burst: bool, col: Color) -> void:
	barrier_hp = maxf(barrier_hp, shield)
	barrier_max = maxf(barrier_max, barrier_hp)
	barrier_t = maxf(barrier_t, duration)
	barrier_burst = burst or barrier_burst
	barrier_color = col


## The barrier is spent or expires: from step 3 it releases what it absorbed.
## `broken`: spent by blows (Steadfast III gives back half the Barrier's cost).
func _break_barrier(broken := false) -> void:
	if broken and passive_rank("warden") >= 3:
		for b in bonds.values():
			if b.id == "warden":
				b.essence = minf(b.capacity(), b.essence + b.spell_cost(b.data()["spells"][0]) * BondScript.Bonds.passive_num("warden", 3, "refund"))
	var reach := barrier_burst_r if barrier_burst_r > 0.0 else 110.0
	if barrier_burst and barrier_stored > 0.0:
		var power := maxf(10.0, barrier_stored)
		main.fx_ring(global_position, barrier_color, reach, 0.4, 6.0)
		main.fx_burst(global_position, Vector2.ZERO, barrier_color, 22, 320.0)
		main.light_flash(global_position, barrier_color, 1.6, 1.6, 0.4)
		main.sfx("crit", 0.8)
		main.shake(6.0)
		for e in main.targets():
			var to: Vector2 = e.global_position - global_position
			if to.length() < reach + e.radius:
				e.take_hit(power, to.normalized(), 260.0, true)
	elif barrier_stored > 0.0 or barrier_hp <= 0.0:
		main.fx_text(global_position + Vector2(0, -36), "Barrier breaks", barrier_color)
	barrier_hp = 0.0
	barrier_t = 0.0
	barrier_stored = 0.0
	barrier_burst = false
	barrier_max = 0.0
	barrier_grow = 0.0
	barrier_cap = 0.0
	barrier_burst_r = 0.0
	barrier_front = 1.0
	barrier_wall = 0.0


## Bond effects that run on a timer: barrier, absorb, anchor, drink.
func _tick_bond_effects(delta: float) -> void:
	_tick_poison(delta)
	_tick_fire_bonds(delta)
	neuro_t -= delta
	vanish_t -= delta
	absorb_t -= delta
	unbreak_t -= delta
	var kindled := kindle_t > 0.0
	kindle_t -= delta
	if kindled and kindle_t <= 0.0 and kindle_brand > 0.0:
		BondScript.wyvern().release_heat(self)  # (Brand: the kindling goes out and your heat is released)
	rune_cd -= delta
	still_for = still_for + delta if velocity.length() < 12.0 and roll_t <= 0.0 else 0.0
	# Heat fades once you stop landing strikes (never while Forge Heart burns).
	heat_idle += delta
	if heat_idle > 1.5 and not (kindle_t > 0.0 and kindle_cap > 100.0):
		heat = move_toward(heat, 0.0, 40.0 * delta)
	if heat > heat_cap():
		heat = move_toward(heat, heat_cap(), 40.0 * delta)
	# Bladeward: orbiting blades cut whatever comes close.
	if bladeward_t > 0.0:
		bladeward_t -= delta
		bladeward_tick -= delta
		if bladeward_tick <= 0.0:
			bladeward_tick = 0.35
			for e in main.targets():
				var to: Vector2 = e.global_position - global_position
				if to.length() < bladeward_r + e.radius:
					e.take_hit(bladeward_dmg, to.normalized(), 90.0)
					main.fx_burst(e.global_position - to.normalized() * e.radius, to.normalized(), bladeward_color, 4, 180.0)
					main.sfx("hit", 1.4, -8.0)
	if barrier_t > 0.0:
		barrier_t -= delta
		if barrier_t <= 0.0:
			_break_barrier()
	# Anchor: a tethered foe can't get farther than the tether's length.
	if anchor_t > 0.0:
		anchor_t -= delta
		if anchor_target == null or not is_instance_valid(anchor_target) or anchor_target.dead:
			anchor_t = 0.0
		else:
			var to: Vector2 = anchor_target.global_position - global_position
			if to.length() > anchor_len:
				anchor_target.knock = -to.normalized() * minf((to.length() - anchor_len) * 8.0, 400.0)
	# Drink Deep: a drain that grows stronger every second it holds.
	if drink_t > 0.0:
		drink_t -= delta
		drink_age += delta
		drink_tick -= delta
		if drink_jump > 0.0 and (drink_target == null or not is_instance_valid(drink_target) or drink_target.dead):
			drink_target = BondScript.kraken().drink_jump(main, drink_at, drink_jump)  # its Apex: on a kill it jumps on
		if drink_target == null or not is_instance_valid(drink_target) or drink_target.dead or drink_target.global_position.distance_to(global_position) > 300.0:
			drink_t = 0.0
		elif drink_tick <= 0.0:
			drink_tick = 0.25
			drink_at = drink_target.global_position
			var d := drink_dmg * (1.0 + drink_age)
			var bled: bool = Reactions.has(drink_target, "bleeding")
			if "hemorrhage" in Reactions.apply(main, drink_target, "drained", 0.0, "drink"):
				d *= Reactions.num("hemorrhage", "mult")  # (Hemorrhage: a bleeding foe drained)
			if is_instance_valid(drink_target) and not drink_target.dead:
				drink_target.take_hit(d, Vector2.ZERO)
			var heal_k := Pacts.num("bloodletter", "heal") if bled and Pacts.has(self, "bloodletter") else 1.0  # Bloodletter
			hp = minf(max_health(), hp + d * 0.5 * heal_mult() * heal_k)


## A parry landed (`source`: what was parried). Spells listen here (e.g.
## Tidebreak: spell_fx.gd listen()).
signal on_parry(source, perfect: bool)


func _on_parry(source, perfect := false) -> void:
	parry_t = 0.0
	parry_cd = 0.0  # a clean parry lets you act again at once
	parry_flash = 0.35 if perfect else 0.25
	# Steadfast II (Warden): a parry while shielded restores the barrier.
	if barrier_hp > 0.0 and passive_rank("warden") >= 2:
		barrier_hp = maxf(barrier_hp, minf(barrier_max, barrier_hp + barrier_max * BondScript.Bonds.passive_num("warden", 2, "restore")))
		main.fx_ring(global_position, barrier_color, radius + 14.0, 0.25, 3.0)
	on_parry.emit(source, perfect)
	BondScript.wyvern().parry_heat(self, perfect)  # (Heat III: parries add heat)
	sta = minf(max_sta, sta + (30.0 if perfect else 12.0) + gfx("parry_sta"))  # (a Duelist's Ring)
	var at: Vector2 = global_position + aim * (radius + 8.0)
	var gold := Color(1.0, 0.92, 0.7)
	if perfect:
		main.fx_text(global_position + Vector2(0, -38), "PERFECT PARRY", Color(1.0, 0.85, 0.35))
		main.fx_ring(at, gold, 95.0, 0.45, 6.0)
		main.fx_ring(at, Color(1, 1, 1), 50.0, 0.3, 3.0)
		main.fx_burst(at, aim, gold, 22, 420.0)
		main.sfx("parry", 1.1)
		main.sfx("crit", 1.3, -6.0)
		main.light_flash(at, gold, 1.8, 2.4, 0.4)
		main.hitstop(0.24)
		main.shake(8.0)
	else:
		main.fx_text(global_position + Vector2(0, -34), "Parried", gold)
		main.fx_ring(at, gold, 70.0, 0.35, 5.0)
		main.fx_burst(at, aim, gold, 14, 340.0)
		main.sfx("parry")
		main.light_flash(at, gold, 1.3, 2.0, 0.3)
		main.hitstop(0.14)
		main.shake(6.0)
	# Searing Parry: a parry while your weapon is kindled explodes.
	if kindle_t > 0.0 and searing_dmg > 0.0 and _knows("searing"):
		main.fx_ring(at, kindle_color, 70.0, 0.35, 5.0)
		main.fx_burst(at, aim, kindle_color, 18, 320.0)
		main.light_flash(at, kindle_color, 1.6, 1.8, 0.3)
		main.sfx("burn", 0.8)
		for e in main.targets():
			if e.global_position.distance_to(at) < 70.0 + e.radius:
				e.take_hit(searing_dmg, (e.global_position - global_position).normalized(), 200.0, true)
	# A Silver Ring: a perfect parry heals a little.
	if perfect and gfx("parry_heal") > 0.0 and hp < max_health():
		hp = minf(max_health(), hp + gfx("parry_heal") * heal_mult())
	# Ashgrove Cane: a perfect parry staggers every foe near you.
	if perfect and rule("quell") > 0.0:
		main.fx_ring(global_position, Color(0.86, 0.8, 0.66), 120.0, 0.4, 5.0)
		for e in main.targets():
			if not e.dead and e.global_position.distance_to(global_position) < 120.0 + e.radius:
				e.stagger(rule("quell") * (0.5 if e.is_boss() else 1.0))
	# Watcher's Helm: the foe you parried takes more from you for a while.
	if gfx("watch") > 0.0 and source is Node and is_instance_valid(source):
		source.set_meta("watched", Time.get_ticks_msec() * 0.001 + 3.0)
	# The brow fills when you parry.
	_part_action("brow", 9.0 if perfect else 6.0, 18.0 if perfect else 12.0)
	if source.has_method("on_parried"):
		source.on_parried(perfect)


## The legs fill when you roll through an attack.
func on_dodge() -> void:
	if dodge_cd > 0.0:
		return
	dodge_cd = 0.3
	_part_action("legs", 4.0, 10.0)
	if gfx("dodge_haste") > 0.0:
		dodge_haste_t = 2.0  # Phantom Treads
	main.fx_text(global_position + Vector2(0, -30), "Dodged", Color(0.75, 0.9, 1.0))
	main.fx_ring(global_position, Color(0.75, 0.9, 1.0), 34.0, 0.25, 2.0)
	main.sfx("dodge")
	main.hitstop(0.04)


# Drawing-only state (never read by gameplay): a walk cycle that eases in
# and out, a cloak that trails your movement, and the drawing frame.
var _walk_phase := 0.0
var _walk_amp := 0.0
var _cloak_drift := Vector2.ZERO
var _f := Vector2.RIGHT  # facing, in the drawing frame
var _sd := Vector2.UP  # toward the weapon hand, in the drawing frame
var _light := Vector2(-0.6, -0.8)  # the light's direction, in the drawing frame


## A point in the drawing frame: x forward, y toward the weapon hand.
func _at(x: float, y: float) -> Vector2:
	return _f * x + _sd * y


## How the climber looks (appearance.gd): the colours and flags worked out
## from the saved appearance, once per change (set_appearance), never per frame.
var appearance_look := Appearance.look(Appearance.DEFAULTS)


## Wear a look (a saved appearance dictionary; appearance.gd OPTIONS). Any
## node running this script can be given one (a doll on the appearance page,
## or something drawn like the climber, such as its mirror image).
func set_appearance(app: Dictionary) -> void:
	appearance_look = Appearance.look(app)
	queue_redraw()


## The look dressed in what you wear (gear_look.gd, via _piece_look and
## _armor_look), worked out again only when the gear, the weapon in hand or
## the appearance changes; a copy, as the drawing tints it (hurt, fallen).
var _dress_key := -1
var _dress_cache := {}
func _dressed_look() -> Dictionary:
	var key := hash([gear, weapon, appearance_look])
	if key != _dress_key or _dress_cache.is_empty():
		_dress_key = key
		_dress_cache = appearance_look.duplicate()
		_piece_look(_dress_cache, true)
		_armor_look(_dress_cache)
		_piece_look(_dress_cache, false)
	return _dress_cache.duplicate()


## The climber, built into one batch (one draw call) in the style of
## draw_util.gd: a hooded head, shoulders and arms over a cloak that sways,
## boots that step, armor and the weapon in hand. Marks glow on top. The
## colours, hair and hood come from appearance_look (appearance.gd draws the head).
func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001
	var dt := get_process_delta_time()
	var look := _dressed_look()
	# A hit flushes the climber red, then fades (no snap back).
	var hurt := clampf((hurt_t - 0.25) / 0.15, 0.0, 1.0) * 0.6
	for k in look:
		if look[k] is Color:
			if dead:
				var g: float = look[k].get_luminance() * 0.75 + 0.08
				look[k] = Color(g, g * 0.97, g * 1.03)
			elif hurt > 0.0 and k != "skin":
				look[k] = look[k].lerp(Color(1.0, 0.35, 0.3), hurt)
	# Vanish fades the climber most; a roll fades it to half (eased, so it
	# doesn't blink). Set only here: two writers used to fight over it.
	var want := 0.35 if vanish_t > 0.0 else (ROLL_ALPHA if roll_t > 0.0 else 1.0)
	modulate.a = move_toward(modulate.a, want, dt * 10.0)
	# The walk cycle and the cloak ease toward how you move.
	var spd := velocity.length() if not dead and roll_t <= 0.0 else 0.0
	_walk_amp = move_toward(_walk_amp, clampf(spd / 120.0, 0.0, 1.0), dt * 6.0)
	_walk_phase = fmod(_walk_phase + spd * dt / 11.0, TAU)
	var lv := Vector2(velocity.dot(aim), velocity.dot(aim.orthogonal())) / WALK
	_cloak_drift = _cloak_drift.lerp(-lv * 4.0 if not dead else Vector2.ZERO, 1.0 - exp(-dt * 8.0))

	_draw_shadow(t, dt)
	var lift := jump_height()
	var side := aim.orthogonal()
	# Squash along the facing: stretched when rolling, flattened when hit.
	var sq_dir := roll_dir if roll_t > 0.0 else aim
	draw_set_transform(Vector2(0, -lift), sq_dir.angle(), Vector2(1.0 + squash * 0.25, 1.0 - squash * 0.2))
	var body := Transform2D(sq_dir.angle(), Vector2.ZERO).affine_inverse()
	_f = body.basis_xform(aim)
	_sd = body.basis_xform(side)
	_light = body.basis_xform(Draw.LIGHT_DIR)
	var b := Draw.Batch.new()
	if dead:
		_draw_fallen(b, look)
	elif roll_t > 0.0:
		_draw_rolling(b, look)
	else:
		_draw_standing(b, look, t)
	b.flush(self)
	draw_set_transform(Vector2(0, -lift), 0.0, Vector2.ONE)
	if main != null:  # (a doll has no marks)
		Makers.draw_core_world(self, main.profile, side, t)  # (a core mark, beneath the marks)
		_draw_marks(side, t)
		if item_count("vessel") > 0:
			load("res://scripts/vessel.gd").draw_on_climber(self, t)  # (at the hip, glowing with what it holds)
	if overlay != null:
		overlay.queue_redraw()


## The shadow under you. With a path it holds the flow (secret.gd): Life's
## living green, beating, with roots, leaves trailing behind you and
## grass-light; Unmaking's cracked violet, flaking into motes, drinking the
## light. One draw call either way (the leaves go into the same batch).
var _shadow_b := Draw.Batch.new()
func _draw_shadow(t: float, dt: float) -> void:
	var feet := Vector2(0, radius * 0.75)
	var r := radius * (1.0 - jump_height() / 40.0)
	if flow_path == "" or dead:
		Draw.shadow(self, feet, r)
		return
	var b := _shadow_b
	if flow_path == "life" and flow_step >= 3:
		# Leaves left behind as you move: one every so often, fading as they settle.
		var here := global_position + feet
		if here.distance_to(_leaf_from) > 22.0:
			_leaf_from = here
			_leaf_at[_leaf_next] = here + Vector2(randf_range(-6.0, 6.0), randf_range(-3.0, 3.0))
			_leaf_age[_leaf_next] = 0.0
			_leaf_ang[_leaf_next] = randf() * TAU
			_leaf_next = (_leaf_next + 1) % LEAVES
		var lc: Color = Secret.KINDS["life"]["light"]
		for i in LEAVES:
			_leaf_age[i] += dt
			var age := _leaf_age[i]
			if age >= Secret.LEAF_LIFE:
				continue
			var k := 1.0 - age / Secret.LEAF_LIFE
			var at := _leaf_at[i] - global_position
			b.line(at + Vector2(-3, 1), at + Vector2(3, -1), Color(Secret.KINDS["life"]["deep"].lightened(0.2), 0.7 * k), 1.2)
			Secret.draw_leaf(b, at, _leaf_ang[i] + 0.4 * age, 4.0 + 1.5 * k, Color(lc.darkened(0.2 * (1.0 - k)), 0.85 * k))
	Secret.draw_shadow(b, feet, r, flow_path, flow_step, t)
	b.flush(self)


## Worn pieces that show, dressed over the look in three steps (gear_look.gd
## dress; mirror.gd calls them in the same order): before the armor (a
## cloak's colour, so the hood follows it), the armor, then after it the
## helm, gloves, boots and the rest (the backpack, amulet, rings, weapons).
func _piece_look(look: Dictionary, before_armor: bool) -> void:
	if before_armor:
		GearLook.before_armor(look, gear)
		return
	GearLook.after_armor(look, gear)
	GearLook.extras(look, gear, weapon)


## Colours and sizes for the armor you wear (none: tunic and cloak).
func _armor_look(look: Dictionary) -> void:
	GearLook.armor_look(look, gear)


func _draw_standing(b, look: Dictionary, t: float) -> void:
	var s := sin(_walk_phase) * _walk_amp  # -1..1 through a stride
	var lean := 0.0
	if hurt_t > 0.45:
		lean = -2.5 * (hurt_t - 0.45) / 0.25  # rocked back by a hit
	var lx := _f * lean
	var d := _cloak_drift
	var sway := sin(t * 1.7) * 0.8 + cos(_walk_phase) * 1.4 * _walk_amp
	# In layers (appearance.gd draws the body, clothes and head from the
	# climber's look; the gear is drawn here): legs and boots stepping out
	# from under the cloak; the cloak, its hem trailing and swaying; the
	# chest and belt; armour and the shoulders; the head (a hood or helm
	# with its peak trailing behind, or bare with the hood down).
	Appearance.draw_legs(b, lx, _f, _sd, _light, look, s)
	Appearance.draw_cloak(b, lx, _f, _sd, _light, look, sway, d)
	GearLook.tower_back(b, lx, _f, _sd, _light, look)  # (a backpack, the other weapon slung)
	Appearance.draw_torso(b, lx, _f, _sd, _light, look)
	_draw_armor_detail(b, lx, look)
	GearLook.tower_chest(b, lx, _f, _sd, _light, look, t)  # (an amulet, a fine chest piece's glow)
	Appearance.draw_head(b, lx + _at(-0.5, 0.0), _f, _sd, _light, look, sway, d)
	GearLook.tower_head(b, lx + _at(-0.5, 0.0), _f, _sd, _light, look, t)  # (a candle, a feather, a fine helm's crest)
	var sh_y: float = look.get("sh_y", 9.3)  # (wider apart on a broad build)
	var sh_w := lx + _at(0.3 + s * 0.8, sh_y)
	var sh_o := lx + _at(0.3 - s * 0.8, -sh_y)
	# Over the head: arms, the weapon, then the hands that hold it.
	_draw_weapon(b, sh_w, sh_o, look, s)


## Armor on the chest, where it shows in front of the head.
func _draw_armor_detail(b, lx: Vector2, look: Dictionary) -> void:
	var c := lx + _at(2.0, 0.0)
	var fa := _f.angle()
	var torso: Color = look["torso"]
	var tk: float = float(look.get("torso_r", 8.5)) / 8.5  # (the build)
	match gear_id("armor"):
		"padded":
			for k in 5:  # quilting
				var a := fa + (k - 2) * 0.38
				b.line(c + Vector2.from_angle(a) * 5.5 * tk, c + Vector2.from_angle(a) * 8.0 * tk, Color(0, 0, 0, 0.3), 1.0)
		"leather":
			b.line(lx + _at(2.0 + 7.5 * tk, -3.5 * tk), lx + _at(3.0, 8.5 * tk), torso.darkened(0.35), 1.8)  # a strap
			b.dot(lx + _at(2.0 + 6.4 * tk, -1.4 * tk), 1.2, Color(0.85, 0.7, 0.45))  # its buckle
		"chain":
			for k in 7:  # rings
				var a := fa + (k - 3) * 0.3
				b.dot(c + Vector2.from_angle(a) * 7.2 * tk, 0.8, Color(1, 1, 1, 0.3))
		"plate":
			b.line(lx + _at(2.0 + 4.6 * tk, 0.0), lx + _at(2.0 + 8.2 * tk, 0.0), torso.lightened(0.35), 1.2)  # the ridge
	var sh_r: float = look["shoulder_r"] + float(look.get("sh_add", 0.0))  # (the build)
	for sgn in [-1.0, 1.0]:
		var at := lx + _at(0.3, sgn * float(look.get("sh_y", 9.3)))
		b.ball(at, sh_r, look["shoulder"], true, _light)
		if gear_id("armor") == "plate":
			b.arc(at, sh_r - 1.6, fa + sgn * 0.3, fa + sgn * 2.4, 6, Color(1, 1, 1, 0.3), 1.0)
		elif gear_id("armor") == "leather":
			b.dot(at + _at(0.0, sgn * 1.5), 0.9, Color(0.85, 0.7, 0.45))


## Curled up in the cloak, tumbling along the roll (head over heels).
func _draw_rolling(b, look: Dictionary) -> void:
	var dur := 0.26 if has_bond("windwalker") else 0.22
	var spin := clampf(1.0 - roll_t / dur, 0.0, 1.0) * TAU
	var fwd := Vector2.RIGHT  # the drawing frame faces the roll
	var across := Vector2.UP
	# The cloak balled round you, its folds sweeping over the back as it
	# turns (its trim and pattern too: appearance.gd).
	Appearance.draw_rolled_cloak(b, look, fwd, across, spin, _light)
	for sgn in [-1.0, 1.0]:  # hands tucked in
		b.ball(fwd * 3.0 + across * sgn * 8.0, 2.6, look["hand"], true, _light)
	var c := cos(spin)
	b.ball(fwd * (5.0 * c), 5.0 + 1.2 * c, Appearance.crown(look), true, _light)


## Fallen: face down, cloak spread, arms flung out, the weapon dropped.
func _draw_fallen(b, look: Dictionary) -> void:
	# The legs out from under the cloak, the cloak spread (appearance.gd).
	Appearance.draw_fallen_body(b, _f, _sd, _light, look)
	# The weapon lies where it fell.
	var w := wdata()
	var grip := _at(8.0, 18.0)
	var along := _f.rotated(-0.5)
	if w["kind"] == "melee" and weapon != "fists":
		if w.get("style", "") == "arc":
			_draw_swung(b, weapon, grip, along, float(w.get("length", 24.0)), 0.0)
		elif weapon == "spear":
			b.stroke(grip - along * 20.0, grip + along * 20.0, Palette.WOOD, 2.6)
		else:
			b.sword(grip, along, float(w.get("length", 14.0)), 0.0)
	elif w["kind"] != "melee":
		b.stroke(grip - along * 10.0, grip + along * 10.0, Palette.WOOD.darkened(0.2), 2.6)
	for sgn in [-1.0, 1.0]:
		var hand := _at(5.0 - sgn * 2.0, sgn * 16.0)
		b.stroke(_at(0.5, sgn * 8.5), hand, look["sleeve"], 3.4)
		b.ball(hand, 2.8, look["hand"], true, _light)
	b.ball(_at(0.0, 0.0), float(look.get("torso_r", 8.5)) - 0.5, look["torso"], true, _light)
	b.ball(_at(8.0, 2.5), 6.0, Appearance.crown(look), true, _light)


## Essence soaking into unmarked parts, and the marks themselves, with their
## steps and stored motes. Their glow is drawn unlit by _draw_overlay.
func _draw_marks(side: Vector2, t: float) -> void:
	if main.unbound != null and main.unbound.on:
		main.unbound.draw_veins(self, self, side, t)  # (the Unbound: veins of raw essence, not marks)
		return
	var b := Draw.Batch.new()
	for part in BondScript.Bonds.PARTS:
		if bonds.has(part):
			continue
		var k: float = main.soak_fraction(part)
		if k <= 0.02:
			continue
		var at := _mark_anchor(part, side)
		var pulse := 0.6 + 0.4 * sin(t * 3.0 + at.x)
		b.dot(at, 1.5 + 3.0 * k, Color(1.0, 0.95, 0.8, 0.25 * k * pulse + 0.1 * k))
	for bd in bonds.values():
		var anchor := _mark_anchor(bd.part, side)
		var col: Color = _mark_color(bd, t)
		b.dot(anchor, 3.4, Palette.OUTLINE)
		b.dot(anchor, 2.5, col)
		b.dot(anchor + Vector2(-0.6, -0.6), 1.0, Color(1, 1, 1, 0.6 * col.a))
		for i in bd.step:
			var spread: float = float(i) - (float(bd.step) - 1.0) / 2.0
			var ang: float = anchor.angle() + PI + spread * 0.5
			b.line(anchor + Vector2.from_angle(ang) * 3.0, anchor + Vector2.from_angle(ang) * 6.5, col, 1.4)
		var motes := int(bd.essence / 8.0)
		for i in mini(motes, 6):
			var ma := t * 2.0 + float(i) * TAU / 6.0
			b.dot(anchor + Vector2.from_angle(ma) * 10.0, 1.2, Color(col, 0.8 * col.a))
	b.flush(self)


## A mark's colour now: faint marks breathe, burned ones pulse red (smoothly).
func _mark_color(bd, t: float) -> Color:
	var col: Color = bd.color()
	if dead:
		col = col.lerp(Color(0.5, 0.5, 0.5), 0.6)
	if bd.faint:
		col.a = 0.45 + 0.25 * sin(t * 4.0)
	if bd.burned:
		col = col.lerp(Color(1.0, 0.35, 0.25), 0.5 + 0.5 * sin(t * 10.0))
	return col


## Where each body part's mark sits on the climber.
func _mark_anchor(part: String, side: Vector2) -> Vector2:
	match part:
		"throat":
			return aim * (radius * 0.25) + side * 2.0
		"back":
			return -aim * (radius * 0.7) + side * 2.0
		"hand":
			return side * radius * 0.95 + aim * 3.0
		"brow":
			return aim * (radius * 0.55)
		"heart":
			return -side * radius * 0.3 - aim * 3.0
	return Vector2(0, radius * 0.55)  # legs


## Swing trails, parry and cast rings: drawn unlit so they read in the dark.
func _draw_overlay() -> void:
	var c := overlay
	if main != null and main.unbound != null and main.unbound.on:
		main.unbound.glow_into(c, self)
	elif not bonds.is_empty():
		# The marks' glow: soft, unlit, so they shine in the dark.
		var glow := Draw.Batch.new()
		var gt := Time.get_ticks_msec() * 0.001
		var lifted := Vector2(0, -jump_height())
		for bd in bonds.values():
			var gc := _mark_color(bd, gt)
			var at := lifted + _mark_anchor(bd.part, aim.orthogonal())
			var pulse := 0.8 + 0.2 * sin(gt * 2.5 + at.x)
			glow.dot(at, 6.5, Color(gc, 0.12 * gc.a * pulse))
			glow.dot(at, 4.0, Color(gc, 0.25 * gc.a * pulse))
		glow.flush(c)
	if aura_part != "":
		var ar := aura_r * (2.0 if firebird_t > 0.0 else 1.0)
		var tt2 := Time.get_ticks_msec() * 0.001
		c.draw_circle(Vector2.ZERO, ar, Color(aura_color, 0.07 + 0.05 * sin(tt2 * 6.0)))
		c.draw_arc(Vector2.ZERO, ar, 0.0, TAU, 40, Color(aura_color, 0.35), 2.0)
		if firebird_t > 0.0:
			for sgn in [-1.0, 1.0]:
				var wing := PackedVector2Array([Vector2(0, -4), Vector2(sgn * 34.0, -18.0 + 4.0 * sin(tt2 * 8.0)), Vector2(sgn * 20.0, 6.0)])
				c.draw_colored_polygon(wing, Color(1.0, 0.6, 0.25, 0.55))
	if rekindle_t > 0.0 or ember_t > 0.0:
		var tt3 := Time.get_ticks_msec() * 0.001
		for i in 4:
			c.draw_circle(Vector2(sin(tt3 * 7.0 + i) * 8.0, -10.0 - fmod(tt3 * 30.0 + i * 6.0, 18.0)), 2.0, Color(1.0, 0.45, 0.25, 0.8))
	var tt := Time.get_ticks_msec() * 0.001
	if bladeward_t > 0.0:
		for i in 4:
			var ba := tt * 5.0 + TAU * i / 4.0
			var bp := Vector2.from_angle(ba) * bladeward_r
			var bd := Vector2.from_angle(ba + PI / 2.0)
			c.draw_colored_polygon(PackedVector2Array([bp + bd * 10.0, bp + bd.orthogonal() * 3.0, bp - bd * 6.0, bp - bd.orthogonal() * 3.0]), Color(bladeward_color, 0.9))
		c.draw_arc(Vector2.ZERO, bladeward_r, 0.0, TAU, 32, Color(bladeward_color, 0.2), 1.5)
	if kindle_t > 0.0:
		var tip := aim * (radius + 18.0)
		for i in 4:
			var fp := tip - aim * (i * 5.0) + Vector2(sin(tt * 13.0 + i) * 2.0, -3.0 - 3.0 * sin(tt * 9.0 + i * 1.7))
			c.draw_circle(fp, 2.6 - i * 0.4, Color(kindle_color, 0.85))
	if heat > 1.0:
		var hc := Color(1.0, 0.45 + 0.4 * heat / 100.0, 0.2, 0.8)
		c.draw_arc(Vector2.ZERO, radius + 9.0, PI * 0.6, PI * 0.6 + PI * 0.8 * heat / 100.0, 16, hc, 2.5)
	if swing_t > 0.0:
		_draw_swing_trail(c)
	if parry_t > 0.0:
		var pa := aim.angle()
		c.draw_arc(Vector2.ZERO, radius + 10.0, pa - 1.0, pa + 1.0, 14, Color(1.0, 0.89, 0.63), 4.0)
		c.draw_arc(Vector2.ZERO, radius + 14.0, pa - 0.8, pa + 0.8, 14, Color(1.0, 0.89, 0.63, 0.4), 2.0)
	if barrier_hp > 0.0:
		# The barrier: a dome of facets that dims as it's spent.
		var tw := Time.get_ticks_msec() * 0.0015
		var pts := PackedVector2Array()
		for i in 7:
			pts.append(Vector2.from_angle(tw + TAU * i / 6.0) * (radius + 10.0))
		c.draw_colored_polygon(pts.slice(0, 6), Color(barrier_color, 0.12))  # (the 7th point closes the outline: not for the fill)
		c.draw_polyline(pts, Color(barrier_color, 0.8), 2.0, true)
	if absorb_t > 0.0:
		c.draw_arc(Vector2.ZERO, radius + 14.0 + 2.0 * sin(Time.get_ticks_msec() * 0.02), 0.0, TAU, 24, Color(barrier_color, 0.8), 2.0)
	if unbreak_t > 0.0:
		c.draw_arc(Vector2.ZERO, radius + 6.0, 0.0, TAU, 24, Color(1.0, 0.85, 0.4, 0.9), 3.0)
	if has_bond("warden") and parry_t <= 0.0 and Input.is_action_pressed("parry"):
		var ga := aim.angle()
		c.draw_arc(Vector2.ZERO, radius + 8.0, ga - 0.9, ga + 0.9, 12, Color(0.85, 0.71, 0.42, 0.9), 4.0)
	if anchor_t > 0.0 and anchor_target != null and is_instance_valid(anchor_target):
		var to_a: Vector2 = anchor_target.global_position - global_position
		var segs := 8
		for i in segs:
			var a0 := to_a * (float(i) / segs) + to_a.orthogonal().normalized() * sin(i * 1.3 + Time.get_ticks_msec() * 0.006) * 3.0
			var a1 := to_a * (float(i + 1) / segs) + to_a.orthogonal().normalized() * sin((i + 1) * 1.3 + Time.get_ticks_msec() * 0.006) * 3.0
			c.draw_line(a0, a1, Color(0.31, 0.5, 0.84, 0.85), 2.0)
	if drink_t > 0.0 and drink_target != null and is_instance_valid(drink_target):
		var to_d: Vector2 = drink_target.global_position - global_position
		c.draw_line(Vector2.ZERO, to_d, Color(0.31, 0.5, 0.84, 0.35), 6.0)
		c.draw_line(Vector2.ZERO, to_d, Color(0.6, 0.85, 1.0, 0.9), 2.0)
	if parry_flash > 0.0:
		c.draw_circle(Vector2.ZERO, radius + 6.0, Color(1.0, 0.95, 0.8, 0.5 * parry_flash / 0.25))
	if cast_t > 0.0:
		var b = bonds[cast_part]
		var k3 := 1.0 - cast_t / maxf(cast_total, 0.001)
		c.draw_arc(Vector2.ZERO, radius + 14.0, -PI / 2.0, -PI / 2.0 + TAU * k3, 32, b.color(), 3.0)
		c.draw_circle(Vector2.ZERO, radius + 14.0 * k3, Color(b.color(), 0.12))
	if drawing:
		var w := wdata()
		var kd: float = clampf(draw_t / w["draw_time"], 0.0, 1.0)
		var grip := aim * (radius + 5.0)
		var col2 := Color(1.0, 0.9, 0.6, 0.8) if kd >= 1.0 else Color(1, 1, 1, 0.15 + 0.3 * kd)
		c.draw_line(grip + aim * 18.0, grip + aim * (60.0 + 160.0 * kd), col2, 1.0 + kd)


## A swing's trail: a crescent for swung weapons, a streak for thrusts and
## stabs, a ring where a fist lands.
func _draw_swing_trail(c: Node2D) -> void:
	var w := wdata()
	if w["kind"] != "melee":
		return
	var k: float = 1.0 - swing_t / w["swing_time"]
	var heavy: bool = swing["heavy"]
	var reach: float = swing["range"]
	var col := Color(1.0, 0.88, 0.55) if heavy else Color(0.95, 0.97, 1.0)
	match String(w["style"]):
		"arc":
			var a := aim.angle()
			var half := deg_to_rad(swing["arc"])
			var sweep: float = swing["side"]
			var from := a - half * sweep
			var to := lerpf(from, a + half * sweep, minf(1.0, k * 1.6))
			var thick: float = (3.5 if heavy else 2.5) * (1.4 if w["class"] == "heavy" else 1.0)
			# A crescent trail: several arcs fading toward the inside.
			for i in 5:
				var rr := reach - i * 3.0
				c.draw_arc(Vector2.ZERO, rr, minf(from, to), maxf(from, to), 20, Color(col, (0.75 - i * 0.14) * (1.0 - k * 0.5)), thick)
		"stab", "thrust":
			var ext := sin(PI * minf(1.0, k * 1.3))
			var tip := aim * reach * (0.6 + 0.4 * ext)
			c.draw_line(aim * radius, tip, Color(col, 0.5 * (1.0 - k * 0.6)), 3.0 if heavy else 2.0)
			c.draw_circle(tip, 3.0 if heavy else 2.0, Color(col, 0.7 * (1.0 - k)))
		"jab":
			if k > 0.3:
				c.draw_arc(aim * reach, 7.0 + 6.0 * k, 0.0, TAU, 14, Color(1, 0.95, 0.85, 0.6 * (1.0 - k)), 2.0)


## Arms from the shoulders to the hands, the weapon in hand, then the hands
## on top of its grip. `s` is the stride (-1..1): a free hand swings with it.
func _draw_weapon(b, sh_w: Vector2, sh_o: Vector2, look: Dictionary, s: float) -> void:
	var dir := _f
	var side := _sd
	var w := wdata()
	var sleeve: Color = look["sleeve"]
	var free := sh_o + _at(5.0 - s * 3.0, -1.2)  # the off hand, at rest
	var hands: Array = []  # [shoulder, hand, size]
	var draw_weapon := Callable()
	match String(w.get("style", w["kind"])):
		"arc":
			# Swung weapons: rest angled forward, follow the swing across its arc.
			var two_hands: bool = w["class"] == "heavy"
			var grip := side * (radius * (0.5 if two_hands else 0.95)) + dir * (7.0 if two_hands else 4.0)
			var along := dir.rotated(0.8 if two_hands else 0.5)
			if swing_t > 0.0:
				var k: float = 1.0 - swing_t / w["swing_time"]
				var half := deg_to_rad(swing["arc"])
				var sweep: float = swing["side"]
				along = dir.rotated(lerpf(-half * sweep, half * sweep, minf(1.0, k * 1.6)))
				grip = along * 10.0
			elif attack_cd > 0.0:
				along = dir.rotated(deg_to_rad(swing["arc"]) * swing["side"])
				grip = along * 10.0
			var length: float = float(w.get("length", 24.0)) + (2.0 if swing.get("heavy", false) else 0.0)
			var glint := 1.0 if swing_t > 0.0 else 0.0
			if weapon in ["cane", "sword_cane"]:
				# A cane; the sword-cane's blade is out for its finisher (and its recovery).
				var bare: bool = swing.get("blade", false) and (swing_t > 0.0 or attack_cd > 0.0)
				var wood := Gear.color(weapon_rec())
				draw_weapon = func(): GearLook.tower_cane(b, weapon, grip, along, length, glint, _light, bare, wood)
				if bare:
					# The empty cane, its sheath, stays in the other hand.
					var sheath_at := free + _at(2.0, 0.0)
					var sheath_dir := dir.rotated(-0.6)
					var draw_blade := draw_weapon
					draw_weapon = func():
						GearLook.tower_cane(b, "cane_sheath", sheath_at, sheath_dir, length - 6.0, 0.0, _light, false, wood)
						draw_blade.call()
					hands.append([sh_w, grip - along * 3.0, 3.0])
					hands.append([sh_o, sheath_at, 2.8])
				else:
					hands.append([sh_w, grip - along * 3.0, 3.0])
					hands.append([sh_o, free, 2.8])
			else:
				draw_weapon = func(): _draw_swung(b, weapon, grip, along, length, glint)
			if not (weapon in ["cane", "sword_cane"]):
				hands.append([sh_w, grip - along * 3.0, 3.0])
				hands.append([sh_o, grip + along * 1.5 if two_hands else free, 2.8])
		"gun":
			# A pistol held out along your aim; it kicks up when it fires. Reloading,
			# it comes back to the chest: a revolver's cylinder swings out, a
			# flintlock tips up for the powder and ball.
			var ggrip := dir * (radius + 3.0) + side * 2.0
			var gdir := dir
			var open := 0.0
			var reloading := reload_t > 0.0
			if reloading:
				var rk := 1.0 - clampf(reload_t / maxf(gun_reload_time(), 0.01), 0.0, 1.0)
				ggrip = dir * (radius * 0.55) + side * (radius * 0.35)
				gdir = dir.rotated(0.9 if weapon == "flintlock" else 0.5).normalized()
				open = sin(PI * clampf(rk * 1.15, 0.0, 1.0))
			elif attack_cd > 0.0:
				var kk := clampf(attack_cd / maxf(float(w["recover"]), 0.01), 0.0, 1.0)
				ggrip -= dir * 4.0 * kk
				gdir = dir.rotated(-0.35 * kk)
			var gcol := Gear.color(weapon_rec())
			draw_weapon = func(): GearLook.tower_gun(b, weapon, ggrip, gdir, _light, open, gcol)
			hands.append([sh_w, ggrip, 3.0])
			hands.append([sh_o, ggrip + gdir * 6.0 + side * 2.0 if reloading else free, 2.8])
		"stab", "thrust":
			# Daggers and spears: held point-first, driven straight out on a thrust.
			var length2: float = float(w.get("length", 14.0))
			var rest := side * (radius * 0.85) + dir * 2.0
			var ext := 0.0
			if swing_t > 0.0:
				var k2: float = 1.0 - swing_t / w["swing_time"]
				ext = sin(PI * minf(1.0, k2 * 1.3))
			elif attack_cd > 0.0:
				ext = 0.25
			var reach: float = float(swing.get("range", 40.0)) - length2 - radius * 0.3
			var grip2 := rest.lerp(dir * maxf(reach, 6.0) + side * 2.0, ext)
			var glint2 := 1.0 if swing_t > 0.0 else 0.0
			if weapon == "spear":
				grip2 -= dir * 10.0  # held back along the shaft
				draw_weapon = func():
					b.stroke(grip2 - dir * 16.0, grip2 + dir * (length2 - 9.0), Palette.WOOD, 2.6)
					var tip := grip2 + dir * length2
					b.poly(PackedVector2Array([tip, tip - dir * 10.0 + side * 3.6, tip - dir * 10.0 - side * 3.6]), Palette.STEEL, 1.0)
					b.line(tip - dir * 9.0 + side * 0.8, tip - dir * 1.5, Color(1, 1, 1, 0.5 + 0.4 * glint2), 1.0)
				hands.append([sh_w, grip2, 3.0])
				hands.append([sh_o, grip2 - dir * 12.0 - side * 1.5, 2.8])
			else:
				draw_weapon = func(): b.sword(grip2, dir, length2, glint2)
				hands.append([sh_w, grip2 - dir * 2.0, 3.0])
				hands.append([sh_o, free, 2.8])
		"jab":
			for sgn in [-1.0, 1.0]:
				var rest2: Vector2 = dir * (radius * 0.7) + side * sgn * radius * 0.75
				var pos: Vector2 = rest2
				var r := 3.8
				if swing_t > 0.0 and sgn == swing["side"]:
					var k3: float = 1.0 - swing_t / w["swing_time"]
					var ext2: float = sin(PI * minf(1.0, k3 * 1.2))
					pos = rest2.lerp(dir * swing["range"], ext2)
					r = 5.2 if swing["heavy"] else 4.4
				else:
					pos += dir * (s * sgn * 1.5)
				hands.append([sh_w if sgn > 0.0 else sh_o, pos, r])
		"bow":
			var kd := 0.0
			if drawing:
				kd = clampf(draw_t / w["draw_time"], 0.0, 1.0)
			var limb: float = float(w.get("limb", 14.0))
			var bgrip := dir * (radius + 5.0)
			var tip_a := bgrip - dir * (5.0 + 2.0 * kd) + side * limb * (1.0 - 0.06 * kd)
			var tip_b := bgrip - dir * (5.0 + 2.0 * kd) - side * limb * (1.0 - 0.06 * kd)
			var nock := bgrip - dir * (5.0 + 12.0 * kd)
			var wood: Color = Palette.WOOD.darkened(0.15) if limb > 16.0 else Palette.WOOD
			draw_weapon = func():
				var bow := PackedVector2Array([tip_a, bgrip + side * limb * 0.5 - dir * kd, bgrip, bgrip - side * limb * 0.5 - dir * kd, tip_b])
				b.path(bow, Color(Palette.OUTLINE, Draw.FEATHER_ALPHA), 7.0)
				b.path(bow, Palette.OUTLINE, 5.5)
				b.path(bow, wood, 3.0)
				b.dot(bgrip, 2.0, Palette.WOOD.darkened(0.35))  # the grip's wrap
				# The string pulls back as you draw.
				b.path(PackedVector2Array([tip_a, nock, tip_b]), Color(0.92, 0.9, 0.82), 1.0)
				if drawing:
					b.stroke(nock, nock + dir * (18.0 + 14.0 * kd), Palette.WOOD.lightened(0.2), 1.6)
					var head := nock + dir * (19.0 + 14.0 * kd)
					b.poly(PackedVector2Array([head + dir * 4.0, head - dir * 1.5 + side * 2.2, head - dir * 1.5 - side * 2.2]), Palette.STEEL, 0.8)
					b.line(nock - side * 1.8, nock + dir * 4.0, Color(0.85, 0.3, 0.25), 1.2)  # fletching
					b.line(nock + side * 1.8, nock + dir * 4.0, Color(0.85, 0.3, 0.25), 1.2)
			hands.append([sh_w, bgrip + side * 0.5, 3.0])
			hands.append([sh_o, nock if drawing else free, 2.8])
		"crossbow":
			# A stock along your aim, limbs across its front; a bolt when loaded.
			var back := dir * 4.0 + side * 3.0
			var front := back + dir * 22.0
			var loaded := 1.0 if reload_t <= 0.0 else 1.0 - clampf(reload_t / float(w["reload"]), 0.0, 1.0)
			var catch_at := front - dir * lerpf(4.0, 14.0, loaded)
			draw_weapon = func():
				b.stroke(back, front, Palette.WOOD, 3.4)
				var la := front - dir * 3.0 + side * 11.0
				var lb := front - dir * 3.0 - side * 11.0
				var limbs := PackedVector2Array([la, front + side * 4.0, front, front - side * 4.0, lb])
				b.path(limbs, Color(Palette.OUTLINE, Draw.FEATHER_ALPHA), 6.6)
				b.path(limbs, Palette.OUTLINE, 5.0)
				b.path(limbs, Palette.STEEL.darkened(0.25), 2.6)
				b.path(PackedVector2Array([la, catch_at, lb]), Color(0.92, 0.9, 0.82), 1.0)
				if reload_t <= 0.0:
					b.stroke(catch_at, front + dir * 5.0, Color(0.6, 0.45, 0.3), 1.6)
			hands.append([sh_w, back + dir * 3.0, 3.0])
			hands.append([sh_o, back + dir * 12.0 - side * 4.0, 2.8])
	for h in hands:
		b.stroke(h[0], h[1], sleeve, 3.4)
	if draw_weapon.is_valid():
		draw_weapon.call()
	for h in hands:
		b.ball(h[1], h[2], look["hand"], true, _light)
	if not hands.is_empty():
		GearLook.ring_glint(b, hands[0][1], look, "ring1")  # (rings glint on the hands)
		if hands.size() > 1:
			GearLook.ring_glint(b, hands[1][1], look, "ring2")


## A swung weapon lying along `along` from the grip: sword, axe, mace,
## greatsword or war hammer.
func _draw_swung(b, id: String, grip: Vector2, along: Vector2, length: float, glint: float) -> void:
	var side := along.orthogonal()
	match id:
		"axe":
			var head := grip + along * (length - 4.0)
			b.stroke(grip - along * 4.0, head + along * 3.0, Palette.WOOD, 2.6)
			b.poly(PackedVector2Array([head - along * 4.0 + side * 1.5, head + along * 5.0 + side * 1.5, head + along * 7.0 + side * 9.0, head - along * 6.0 + side * 9.0]), Palette.STEEL.darkened(0.08), 1.2)
			b.line(head - along * 6.0 + side * 8.6, head + along * 7.0 + side * 8.6, Color(1, 1, 1, 0.5 + 0.5 * glint), 1.0)
		"mace":
			var ball := grip + along * length
			b.stroke(grip - along * 4.0, ball, Palette.WOOD.darkened(0.2), 2.6)
			for i in 6:
				var a := TAU * i / 6.0 + along.angle()
				b.stroke(ball, ball + Vector2.from_angle(a) * 7.5, Palette.STEEL.darkened(0.3), 1.4)
			b.ball(ball, 5.2, Palette.STEEL.darkened(0.15), true, _light)
		"war_hammer":
			var head2 := grip + along * length
			b.stroke(grip - along * 6.0, head2, Palette.WOOD.darkened(0.1), 3.0)
			var pts := PackedVector2Array([head2 - along * 5.0 + side * 9.0, head2 + along * 5.0 + side * 9.0, head2 + along * 5.0 - side * 6.0, head2 - along * 5.0 - side * 6.0])
			b.poly(pts, Palette.STEEL.darkened(0.15), 1.4)
			b.line(pts[0] - side * 0.8, pts[1] - side * 0.8, Color(1, 1, 1, 0.45 + 0.4 * glint), 1.2)
		"greatsword":
			b.sword(grip, along, length, glint)
			# A broader blade: a second edge alongside the first, and a wide guard.
			b.stroke(grip + along * 3.0 + side * 1.6, grip + along * (length - 3.0) + side * 1.6, Palette.STEEL.darkened(0.04), 2.2)
			b.line(grip + along * 4.0 + side * 2.4, grip + along * (length - 4.0) + side * 2.4, Color(1, 1, 1, 0.4 + 0.4 * glint), 1.0)
			b.stroke(grip + side * 7.0, grip - side * 7.0, Palette.STEEL.darkened(0.35), 2.5)
		_:
			b.sword(grip, along, length, glint)


# --- items -------------------------------------------------------------------------

## The items you carry, in their usual order.
func carried() -> Array:
	return Items.ORDER.filter(func(id): return int(items.get(id, 0)) > 0)


func item_count(id: String) -> int:
	return int(items.get(id, 0))


## The item G uses (the first you carry if none is picked).
func selected_item() -> String:
	if item_count(item_sel) > 0:
		return item_sel
	var have := carried()
	return have[0] if not have.is_empty() else ""


## Picks up an item. False if you already carry as many as you can.
func add_item(id: String) -> bool:
	if item_room(id) != "":
		return false
	items[id] = item_count(id) + 1
	if item_count(item_sel) <= 0:
		# (a recall scroll or a vessel never takes the quick item from another item)
		item_sel = selected_item() if id == "scroll" or id == "vessel" else id
	return true


## Switches G to the next item you carry.
func cycle_item() -> void:
	var have := carried()
	if have.is_empty():
		return
	var i := have.find(selected_item())
	item_sel = have[(i + 1) % have.size()]
	main.fx_text(global_position + Vector2(0, -40), Items.ITEMS[item_sel]["name"], Items.color(item_sel))
	main.sfx("step", 1.4, -6.0)


## Uses the selected item. True if it was used up.
func use_item() -> bool:
	if dead:
		return false
	var id := selected_item()
	if id == "":
		main.fx_text(global_position + Vector2(0, -40), "No items", Color(0.7, 0.68, 0.75))
		return false
	if not Items.use(id, self):
		return false
	if main.puzzle != null:  # (an Essence Lock answers to an item of its essence)
		main.puzzle.offer(String(Items.ITEMS.get(id, {}).get("kind", "")), global_position, "item")
	items[id] = item_count(id) - 1
	if item_count(id) <= 0:
		items.erase(id)
		item_sel = selected_item()
	return true


## Healing items heal over a moment, not all at once.
func _tick_healing(delta: float) -> void:
	if heal_left <= 0.0 or dead:
		heal_left = 0.0
		return
	var h := minf(heal_left, heal_rate * delta)
	hp = minf(max_health(), hp + h)
	heal_left -= h
