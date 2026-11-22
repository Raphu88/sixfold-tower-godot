extends RefCounted
## What carries over between climbs: your marks (bonds), how much essence has
## soaked into your unmarked body parts, and the essence you've banked since
## your last mark. Each climber is saved in their own slot's file (slots.gd:
## user://climber_1.cfg to climber_6.cfg); save_path says which.
##
## The first climb starts with no mark. Floor 6 opens with the Regard: the
## tower's beast takes notice and your most-used body part takes its first
## mark (climb_shape.gd). Fall before it and you're still regarded, but the
## mark is faint, as strong as the floor you reached (climb_shape.gd
## DEATH_MARK): it must soak up its debt of essence (FAINT_DEBT for a mark
## at FAINT_POWER, more for a weaker one) before it can grow.

const Bonds := preload("res://scripts/bonds.gd")
const Gear := preload("res://scripts/gear.gd")
const Secret := preload("res://scripts/secret.gd")
const Appearance := preload("res://scripts/appearance.gd")
const Unbound := preload("res://scripts/unbound.gd")
const Flow := preload("res://scripts/essence_flow.gd")
## Slot 1's file (main.gd points save_path at the current slot's: slots.gd).
const SAVE_PATH := "user://climber_1.cfg"

## The floor the first climb's Regard opens (climb_shape.gd REGARD).
const FIRST_CLIMB_FLOORS := 6
static var FAINT_DEBT := 80.0
## A faint mark's usual strength (a fall's chance mark); its debt is
## FAINT_DEBT at this strength, and grows as the strength falls.
const FAINT_POWER := 0.75
## Growth needed to reach each step (index = step - 1). Only the marks' share
## of what you bank grows marks (essence_flow.gd SPLIT): each kind goes to the
## marks of that kind and counts AFFINITY_WEIGHT; a kind no mark is made of
## spreads over every mark and counts OTHER_WEIGHT. Then STEP_RATE, slowed by
## how many marks the body already carries (BODY_DRAG). Winning the Proving
## (floor 6) grows the mark you used most by PROVING_GROWTH, and tinctures
## steer essence into one mark (essence_flow.gd TINCTURE "mark_boost": a
## tincture's essence is concentrated). The pace is measured in climbs by
## tests/progression_measure.gd (a mark is a long companion: step 2 after
## about 3 climbs, step 3 about 9, step 4 about 18, step 5 about 30).
static var STEP_XP := [0.0, 150.0, 450.0, 900.0, 1500.0]
static var AFFINITY_WEIGHT := 2.0
static var OTHER_WEIGHT := 0.25
static var STEP_RATE := 0.075
static var PROVING_GROWTH := 36.0
## Marks after the first: an unmarked body part fills like a battery. The
## body's share of what you bank spreads over the parts by what each did,
## and an unmarked part soaks SOAK_RATE of its portion; the fuller it is the
## slower it fills (gain x (1 - fill)); a body that carries more marks fills
## every part slower still (BODY_DRAG, by marks carried). A part is full
## (ready for a mark) at MARK_FULL of NEW_MARK_SOAK. A full part takes a new
## mark at a summit, or earlier from a Maker for a sealed wing won early
## (essence_flow.gd EARNED); at most one new mark a climb (main.gd).
static var NEW_MARK_SOAK := 250.0
static var SOAK_RATE := 1.2
static var MARK_FULL := 0.9
static var BODY_DRAG := [1.0, 1.0, 0.7, 0.5, 0.35, 0.25, 0.2]

var regarded := false
var bonds := {}  # part -> {"id", "xp", "faint", "debt"}
var soak := {}  # part -> banked soak in unmarked parts
var tally := {}  # essence kind -> banked since the last mark
var climbs := 0
var best_floor := 1
var last_tower := "kraken"
## Stations (travel.gd): the tower your home station is near (set when the
## climber is made), and the station you're at ("" for your home station).
var home := "gryphon"
var station := ""
var pacts: Array = []  # Covenant's kin book: monster kinds bound, kept between climbs
var synergies_formed: Array = []  # named synergies (synergies.gd) formed at least once: announced once, listed in the book ("lent": two marks lent each other traits)
## Essence density: the body's share of everything you've banked, by essence type, and how it
## settled in your body parts (by what each part did). Each type is an
## attribute and gives a small passive bonus (see attribute()).
var density := {}  # kind -> amount
var part_density := {}  # part -> {kind -> amount}
## Heirlooms: gear kept from survived climbs, by heirloom slot (gear.gd
## HEIRLOOM_SLOTS) -> a gear record (Rings: a list of up to two). Every
## climb starts with them. Old saves held plain ids; load_save converts them.
var heirlooms := {}
## Essence crystals: essence held outside you, kept between climbs: the
## train's money. Every stair condenses a share of what you bank into them
## (essence_flow.gd, the setting train.gd CONDENSE_*), the outfitter pays some for every climb
## (CLIMB_PAY), a vault or a secret room may hold some, and reading a recall
## scroll turns unbanked essence into them; consuming one banks its essence
## into you (main.gd consume_crystal). Each is {"kind", "amount"}; crystals
## of a kind combine into one (add_crystal).
var crystals: Array = []
## What the outfitter paid for the last climb ({kind, amount}; {} once you
## depart again): his greeting in the store car mentions it.
var last_pay := {}
## The train (train.gd), between climbs: your storage chest (gear records,
## kept safe), your pack (records: what came down with you, or what you'll
## take up; it joins the climber when you depart), supplies packed for the
## next climb ({item id: count}) and the store's stock for this visit
## ({outfit: [codes], today: code}; empty until the train is opened).
## What each packed supply cost ({item id: [{kind: amount}, ...]}, the last
## one packed at the end), so putting one back returns what was paid for it
## (the store's price, or the bench's cheaper brewing price).
var chest: Array = []
var pack: Array = []
## What you'll wear when you set off (the Loadout in your car, loadout_page.gd):
## carried slot ("armor", "helm", "ring1"...) -> a gear record, chosen from
## your pack or your stash. It goes on over your heirloom or the starting
## piece in that slot as you depart, and is cleared then (old saves: none).
var wear := {}
var supplies := {}
var supply_paid := {}
var store := {}
## Vessels kept in your chest (vessel.gd): each {kind, amount}, one maybe
## "packed" to go up on your next climb.
var vessels: Array = []
## Lost things (lost.gd): pieces lost in a fall, the newest last, each
## {"rec", "tower", "floor"}. A later climb may find them again.
var lost: Array = []
## The Proving (proving.gd): tower -> Provings won there. Each win makes that
## tower's Proving harder (and its prize better) on later climbs.
var provings := {}
## The Entity's record of you (menu.gd shows it): counters that only go up,
## kept with the climber. "deaths", "slain", "beasts", "floors", "puzzles",
## "falls", "heirlooms", "essence", plus "best" (tower -> best floor) and
## "beasts_by" (tower -> beasts slain there). See note() and note_floor().
var record := {}
## Climbers before this one in this slot (Start over): the Entity remembers them.
var former := 0
## The secret essences (secret.gd): the path chosen at the first great foe
## ("" until then, else "life" (Making) or "unmaking"; for good) and the
## flow: the core essence settled in the body (core.gd), which shows as the
## aura and in the climber's shadow.
var path := ""
var flow := 0.0
## How the climber looks (appearance.gd: option ids, and an optional name).
## Old saves load with today's look (Appearance.DEFAULTS).
var appearance := Appearance.DEFAULTS.duplicate()
## False until a new climber has chosen their look on the creation page
## (the very first launch, a new slot, and after Start over): it opens before the first climb.
var created := true
## A new climber's start (new_start.gd): the questionnaire's answers
## {"past", "home", "why"}. (Where they grew up is `home`, above: the starting
## tower and the home station.)
var origin := {}
## The Makers (makers.gd): fragments found, each Maker's interest, meetings,
## the core mark. makers.gd state() fills in its keys.
var makers := {}
## The secret bond (makers.gd): "", "developer", "designer" or "manipulator",
## and its depth (0 without one, 1 to 5). One per climber.
var core_mark := ""
var core_depth := 0
## The secret bond's own: what's been banked toward its next depth since the
## mark (kind -> amount: "essence", "life", "unmaking") and the Developer's Tune
## (spell id -> setting), and its Edit (spell id -> {aspect: points}).
## secret_bonds.gd reads and writes them.
var core_xp := {}
var core_tune := {}
## The Unbound (unbound.gd): whether you are, the barriers you've broken,
## routes and techniques. {} for a marked climber; unbound.gd state() fills it.
var unbound := {}
var core_edit := {}

## The tree (tree.gd): the choices made at each fork, for good, on both
## paths. tree.gd state() fills in its keys; a save from before the tree is
## migrated as it loads (the forks a mark already passed: today's side, chosen).
var tree := {}

## Renown (renown.gd): renown earned, deeds, titles, the station's medals,
## bouts and challenges, boons bought, the outfitter's special order.
## {} for a climber who has none yet (an old save); renown.gd state() fills it.
var renown := {}

## The Bestiary (bestiary.gd): what this climber has met of each monster,
## kind -> {"seen", "fought", "slain", "fell", "tower", "floor"}. Kept with
## the climber, like the record ({} for an old save, and after Start over).
var bestiary := {}

## Other climbers met in the towers (rivals.gd): id -> their record (name,
## look, gear, marks, and your history with them). {} for an old save.
var rivals := {}
## The Dining car (dining.gd): who sits there this visit, your open
## wagers, what's been offered. {} for an old save.
var dining := {}
## Summit Blades (summit_blades.gd): the blades bonded for good, their
## awakening and the one carried. {} for an old save.
var summit_blades := {}
## Deeds (deeds.gd): the deeds done and their counters. {} for an old save.
var deeds := {}
## What the guardians learned from each other's deaths (guardian_lessons.gd):
## tower -> the lesson its guardian taught when it fell. {} for an old save.
var guardians := {}

static var ATTRIBUTES := {
	"air": {"name": "Agility", "bonus": "move speed"},
	"blade": {"name": "Strength", "bonus": "strike damage"},
	"stone": {"name": "Vitality", "bonus": "health"},
	"iron": {"name": "Will", "bonus": "stamina recovery"},
	"fire": {"name": "Intellect", "bonus": "spell power"},
	"water": {"name": "Spirit", "bonus": "marks fill faster"},
}
## The bonuses are small: they grow with diminishing returns toward the cap.
static var ATTRIBUTE_CAP := 0.12
static var ATTRIBUTE_HALF := 400.0  # density at which a bonus is half the cap (density is the body's share of what you bank)
var saving := true
## Where the profile is saved: its own slot's file, kept from when it was
## loaded, so this climber never writes over another (tests point it elsewhere).
var save_path := SAVE_PATH


## Adds to one of the record's counters (saved with the next save).
func note(key: String, amount := 1.0) -> void:
	record[key] = float(record.get(key, 0.0)) + amount


## A record counter, as a whole number.
func count(key: String) -> int:
	return int(record.get(key, 0.0))


## Reached a floor of a tower: one more floor climbed, and its best floor.
func note_floor(tower: String, floor_num: int) -> void:
	note("floors")
	var best: Dictionary = record.get("best", {})
	best[tower] = maxi(int(best.get(tower, 0)), floor_num)
	record["best"] = best


## A tower's beast fell.
func note_beast(tower: String) -> void:
	note("beasts")
	var by: Dictionary = record.get("beasts_by", {})
	by[tower] = int(by.get(tower, 0)) + 1
	record["beasts_by"] = by


## A tower's Proving was won (saved with the next save).
func note_proving(tower: String) -> void:
	provings[tower] = int(provings.get(tower, 0)) + 1
	note("provings")


## Provings won in a tower.
func proving_wins(tower: String) -> int:
	return int(provings.get(tower, 0))


static func step_for_xp(xp: float) -> int:
	var step := 1
	for i in STEP_XP.size():
		if xp >= STEP_XP[i]:
			step = i + 1
	return step


## A new climber: forget every mark, all growth and soak, and the best floor.
func reset() -> void:
	if regarded or climbs > 0:
		former += 1
	regarded = false
	bonds = {}
	soak = {}
	tally = {}
	climbs = 0
	best_floor = 1
	home = "gryphon"
	station = ""
	pacts = []
	synergies_formed = []
	density = {}
	part_density = {}
	heirlooms = {}
	crystals = []
	last_pay = {}
	chest = []
	pack = []
	wear = {}
	supplies = {}
	supply_paid = {}
	store = {}
	vessels = []
	lost = []
	provings = {}
	record = {}
	path = ""
	flow = 0.0
	appearance = Appearance.DEFAULTS.duplicate()
	created = false
	origin = {}
	makers = {}
	core_mark = ""
	core_depth = 0
	core_xp = {}
	core_tune = {}
	unbound = {}
	core_edit = {}
	tree = {}
	renown = {}
	bestiary = {}
	rivals = {}
	dining = {}
	summit_blades = {}
	deeds = {}
	save()


func load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		created = false  # the very first launch: no save yet
		return
	appearance = Appearance.normalized(cfg.get_value("look", "appearance", {}))
	# (a save from before there was a choice has a profile, and keeps its look;
	# a file that holds only settings is still a new climber)
	created = bool(cfg.get_value("look", "created", cfg.has_section("profile")))
	var og = cfg.get_value("start", "origin", {})
	origin = og if og is Dictionary else {}
	best_floor = int(cfg.get_value("climb", "best_floor", 1))
	regarded = bool(cfg.get_value("profile", "regarded", false))
	bonds = cfg.get_value("profile", "bonds", {})
	soak = cfg.get_value("profile", "soak", {})
	tally = cfg.get_value("profile", "tally", {})
	climbs = int(cfg.get_value("profile", "climbs", 0))
	pacts = cfg.get_value("profile", "pacts", [])
	synergies_formed = cfg.get_value("profile", "synergies_formed", [])
	density = cfg.get_value("profile", "density", {})
	part_density = cfg.get_value("profile", "part_density", {})
	last_tower = str(cfg.get_value("profile", "last_tower", "kraken"))
	home = str(cfg.get_value("profile", "home", "gryphon"))
	station = str(cfg.get_value("profile", "station", ""))
	heirlooms = Gear.load_heirlooms(cfg.get_value("profile", "heirlooms", {}))
	crystals = tidy_crystals(cfg.get_value("profile", "crystals", []))
	var lp = cfg.get_value("train", "last_pay", {})
	last_pay = lp if lp is Dictionary and lp.has("kind") and float(lp.get("amount", 0.0)) >= 1.0 else {}
	chest =_records(cfg.get_value("train", "chest", []))
	pack = _records(cfg.get_value("train", "pack", []))
	wear = _worn_set(cfg.get_value("train", "wear", {}))
	supplies = {}
	var sup = cfg.get_value("train", "supplies", {})
	if sup is Dictionary:
		for id in sup:
			if int(sup[id]) > 0:
				var plain := String(id).get_slice("@", 0)  # (an old sized key is the plain item)
				supplies[plain] = int(supplies.get(plain, 0)) + int(sup[id])
	supply_paid = {}
	var paid = cfg.get_value("train", "supply_paid", {})
	if paid is Dictionary:
		for id in paid:
			if supplies.has(String(id)) and paid[id] is Array:
				supply_paid[String(id)] = paid[id].filter(func(c): return c is Dictionary).slice(0, int(supplies[String(id)]))
	load("res://scripts/charms.gd").old_supplies(self)  # (consumables that became charms: what was paid comes back)
	store = cfg.get_value("train", "store", {})
	if not (store is Dictionary):
		store = {}
	store.erase("sizes")  # (an old save's item sizes: every item is one size now, its count kept)
	vessels = load("res://scripts/vessel.gd").load_list(cfg.get_value("train", "vessels", []))
	lost = load("res://scripts/lost.gd").load_list(cfg.get_value("profile", "lost", []))
	provings = {}
	var won = cfg.get_value("profile", "provings", {})
	if won is Dictionary:
		for t in won:
			if int(won[t]) > 0:
				provings[String(t)] = int(won[t])
	record = cfg.get_value("profile", "record", {})
	former = int(cfg.get_value("profile", "former", 0))
	path = str(cfg.get_value("profile", "path", ""))
	if not Secret.is_kind(path):
		path = ""
	flow = maxf(0.0, float(cfg.get_value("profile", "flow", 0.0))) if path != "" else 0.0
	var mk = cfg.get_value("makers", "state", {})
	makers = mk if mk is Dictionary else {}
	core_mark = str(cfg.get_value("profile", "core_mark", ""))
	core_depth = int(cfg.get_value("profile", "core_depth", 0))
	if not core_mark in ["developer", "designer", "manipulator"]:
		core_mark = ""
		core_depth = 0
	var cx = cfg.get_value("profile", "core_xp", {})
	core_xp = cx if cx is Dictionary else {}
	var ct = cfg.get_value("profile", "core_tune", {})
	core_tune = ct if ct is Dictionary else {}
	var ub = cfg.get_value("unbound", "state", {})
	unbound = ub if ub is Dictionary else {}
	Unbound.tidy(self)  # (an older Unbound's cups made to fit: unbound.gd)
	var ce = cfg.get_value("profile", "core_edit", {})
	core_edit = ce if ce is Dictionary else {}
	var rn = cfg.get_value("renown", "state", {})
	renown = rn if rn is Dictionary else {}
	load("res://scripts/outfitter.gd").adopt_old(self)  # (an old save's outfitter upgrades become nodes of his tree)
	load("res://scripts/renown.gd").retire_boons(self)  # (the Boon Shrine is gone: an old save's boons give their crystals back)
	bestiary = load("res://scripts/bestiary.gd").load_records(cfg.get_value("bestiary", "met", {}))
	var rv = cfg.get_value("rivals", "met", {})
	rivals = rv if rv is Dictionary else {}
	var dn = cfg.get_value("dining", "state", {})
	dining = dn if dn is Dictionary else {}
	var sb = cfg.get_value("summit", "blades", {})
	summit_blades = sb if sb is Dictionary else {}
	var dd = cfg.get_value("deeds", "state", {})
	deeds = dd if dd is Dictionary else {}
	var gl = cfg.get_value("guardians", "lessons", {})
	guardians = gl if gl is Dictionary else {}
	var tr = cfg.get_value("tree", "state", {}) if cfg.has_section_key("tree", "state") else null
	if tr is Dictionary:
		tree = tr
	else:
		tree = {}
		load("res://scripts/tree.gd").migrate(self)  # (an old save: the forks already passed keep today's side)


func save() -> void:
	if not saving:
		return
	var cfg := ConfigFile.new()
	cfg.load(save_path)
	cfg.set_value("climb", "best_floor", best_floor)
	cfg.set_value("profile", "regarded", regarded)
	cfg.set_value("profile", "bonds", bonds)
	cfg.set_value("profile", "soak", soak)
	cfg.set_value("profile", "tally", tally)
	cfg.set_value("profile", "climbs", climbs)
	cfg.set_value("profile", "last_tower", last_tower)
	cfg.set_value("profile", "home", home)
	cfg.set_value("profile", "station", station)
	cfg.set_value("profile", "pacts", pacts)
	cfg.set_value("profile", "synergies_formed", synergies_formed)
	cfg.set_value("profile", "density", density)
	cfg.set_value("profile", "part_density", part_density)
	cfg.set_value("profile", "heirlooms", heirlooms)
	cfg.set_value("profile", "crystals", crystals)
	cfg.set_value("profile", "record", record)
	cfg.set_value("profile", "former", former)
	cfg.set_value("train", "chest", chest)
	cfg.set_value("train", "pack", pack)
	cfg.set_value("train", "wear", wear)
	cfg.set_value("train", "supplies", supplies)
	cfg.set_value("train", "supply_paid", supply_paid)
	cfg.set_value("train", "store", store)
	cfg.set_value("train", "vessels", vessels)
	cfg.set_value("train", "last_pay", last_pay)
	cfg.set_value("profile", "lost", lost)
	cfg.set_value("profile", "provings", provings)
	cfg.set_value("profile", "path", path)
	cfg.set_value("profile", "flow", flow)
	cfg.set_value("look", "appearance", appearance)
	cfg.set_value("look", "created", created)
	cfg.set_value("start", "origin", origin)
	cfg.set_value("makers", "state", makers)
	cfg.set_value("profile", "core_mark", core_mark)
	cfg.set_value("profile", "core_depth", core_depth)
	cfg.set_value("profile", "core_xp", core_xp)
	cfg.set_value("profile", "core_tune", core_tune)
	cfg.set_value("unbound", "state", unbound)
	cfg.set_value("profile", "core_edit", core_edit)
	cfg.set_value("tree", "state", tree)
	cfg.set_value("renown", "state", renown)
	cfg.set_value("bestiary", "met", bestiary)
	cfg.set_value("rivals", "met", rivals)
	cfg.set_value("dining", "state", dining)
	cfg.set_value("summit", "blades", summit_blades)
	cfg.set_value("deeds", "state", deeds)
	cfg.set_value("guardians", "lessons", guardians)
	cfg.set_value("slot", "played", int(Time.get_unix_time_from_system()))  # (the climber picker: when last played)
	cfg.save(save_path)


## Gear records from a save (unknown or broken entries are dropped).
## The Loadout's pieces from a save: each in a slot it fits (a ring in
## ring1 or ring2); anything unknown or misplaced goes.
static func _worn_set(raw) -> Dictionary:
	var out := {}
	if raw is Dictionary:
		for slot in raw:
			var r := Gear.rec(raw[slot])
			if not r.is_empty() and String(slot) in Gear.carry_slots(Gear.slot_of(r)):
				out[String(slot)] = r
			elif not r.is_empty() and Gear.slot_of(r) == "charm" and not raw.has("charm"):
				out["charm"] = r  # (a piece that became a charm since: the Ember Charm was an amulet)
	return out


static func _records(raw) -> Array:
	var out: Array = []
	if raw is Array:
		for g in raw:
			var r := Gear.rec(g)
			if not r.is_empty():
				out.append(r)
	return out


# --- essence crystals ------------------------------------------------------------

## Keeps essence in crystals (amounts under 1 make none). Crystals of a kind
## combine: you hold at most one of each kind, and it grows.
func add_crystal(kind: String, amount: float) -> void:
	if amount < 1.0:
		return
	for c in crystals:
		if c["kind"] == kind:
			c["amount"] = float(c["amount"]) + float(round(amount))
			return
	crystals.append({"kind": kind, "amount": float(round(amount))})


## Crystals of the same kind combined into one each (old saves held many).
static func tidy_crystals(raw) -> Array:
	var totals := {}
	var order: Array = []
	if raw is Array:
		for c in raw:
			if not (c is Dictionary) or not c.has("kind"):
				continue
			var k := String(c["kind"])
			if not totals.has(k):
				order.append(k)
			totals[k] = float(totals.get(k, 0.0)) + maxf(0.0, float(c.get("amount", 0.0)))
	var out: Array = []
	for k in order:
		if float(totals[k]) >= 1.0:
			out.append({"kind": k, "amount": float(round(totals[k]))})
	return out


## How many crystals of a kind you hold (0 or 1: they combine), and how much
## essence they hold.
func crystal_count(kind: String) -> int:
	return crystals.filter(func(c): return c["kind"] == kind).size()


func crystal_total(kind: String) -> float:
	var total := 0.0
	for c in crystals:
		if c["kind"] == kind:
			total += float(c["amount"])
	return total


## Takes up to `most` essence from your crystal of a kind (all of it if
## `most` is 0); what was taken, or 0 if you hold none. An emptied crystal is gone.
func take_crystal(kind: String, most := 0.0) -> float:
	for i in crystals.size():
		if crystals[i]["kind"] == kind:
			var amount := float(crystals[i]["amount"])
			var take := amount if most <= 0.0 else minf(amount, ceilf(most))
			if amount - take < 1.0:
				crystals.remove_at(i)
			else:
				crystals[i]["amount"] = amount - take
			return take
	return 0.0


## Pays `amount` essence of a kind from your crystals of that kind. False
## (and nothing taken) if you hold too little.
func spend(kind: String, amount: float) -> bool:
	amount = ceilf(amount)
	if amount <= 0.0:
		return true
	if crystal_total(kind) < amount:
		return false
	var need := amount
	for i in range(crystals.size() - 1, -1, -1):
		if need <= 0.0:
			break
		if crystals[i]["kind"] != kind:
			continue
		var have := float(crystals[i]["amount"])
		var take := minf(have, need)
		need -= take
		if have - take < 1.0:
			crystals.remove_at(i)
		else:
			crystals[i]["amount"] = have - take
	return true


## All the essence you hold in crystals, every kind.
func crystals_held() -> float:
	var t := 0.0
	for c in crystals:
		t += float(c["amount"])
	return t


## Pays `amount` essence from crystals of any kinds, the biggest crystal
## first (train.gd ANY_PRICE). Returns what was taken ({kind: amount}), or
## {} (and nothing taken) if you hold too little.
func spend_any(amount: float) -> Dictionary:
	amount = ceilf(amount)
	if amount <= 0.0 or crystals_held() < amount:
		return {}
	var order: Array = crystals.map(func(c): return String(c["kind"]))
	order.sort_custom(func(a, b): return crystal_total(a) > crystal_total(b))
	var paid := {}
	var need := amount
	for k in order:
		if need <= 0.0:
			break
		var take := minf(need, crystal_total(k))
		if take >= 1.0 and spend(k, take):
			paid[k] = take
			need -= take
	return paid


## Condensing at a stair (train.gd CONDENSE_*): `share` of each kind of
## essence being banked becomes crystals instead (whole essence, rounded
## down; a kind with too little to make one stays banked in full). Adds the
## crystals and returns {"keep": what's left to bank, "made": {kind: amount
## condensed}}.
func condense(essence: Dictionary, share: float) -> Dictionary:
	var keep := {}
	var made := {}
	for kind in essence:
		var amount := float(essence[kind])
		var c := floorf(amount * clampf(share, 0.0, 1.0))
		if c >= 1.0:
			made[kind] = c
			add_crystal(kind, c)
		keep[kind] = amount - float(made.get(kind, 0.0))
	return {"keep": keep, "made": made}


## How much the way you fought tips the choice between bonds, against the
## essence (0..1). Small: the essence decides, play style breaks ties
## between bonds of the same essence.
const STYLE_PULL := 0.15


## Which bond a new mark becomes. Play style already chose the body part
## (the one you used most); the essence you gathered chooses the bond: each
## bond scores its essence's share, plus STYLE_PULL times the share of your
## fighting (soak, by body part) that suits it. Bonds already carried are skipped.
func choose_bond(essence: Dictionary, style: Dictionary = {}) -> String:
	var total := 0.0
	for k in essence:
		total += float(essence[k])
	var style_total := 0.0
	for k in style:
		style_total += float(style[k])
	var held := bonds.values().map(func(b): return b["id"])
	var best := ""
	var best_score := -1.0
	for id in Bonds.BONDS:
		if id in held:
			continue
		var info: Dictionary = Bonds.BONDS[id]
		var score := 0.0
		if total > 0.0:
			score += float(essence.get(info["affinity"], 0.0)) / total
		if style_total > 0.0:
			var suits := 0.0
			for pt in info.get("style", []):
				suits += float(style.get(pt, 0.0))
			score += STYLE_PULL * suits / style_total
		if score > best_score:
			best_score = score
			best = id
	return best


## Marks a body part with a bond. Faint marks owe essence first: FAINT_DEBT
## at FAINT_POWER, scaled by how far short of full `strength` is (a first
## mark from a death: climb_shape.gd DEATH_MARK; -1 for FAINT_POWER).
func add_bond(part: String, id: String, faint: bool, strength := -1.0) -> void:
	var power: float = (strength if strength > 0.0 else FAINT_POWER) if faint else 1.0
	var debt: float = FAINT_DEBT * (1.0 - power) / (1.0 - FAINT_POWER) if faint else 0.0
	bonds[part] = {"id": id, "xp": 0.0, "faint": faint, "debt": debt, "power": power}
	soak.erase(part)
	tally = {}


## Banks essence the natural way, with no crystal share (eating a crystal:
## main.gd consume_crystal): body and marks share it. `run_soak` is what each
## body part did (it spreads the body's share); empty, the way your body has
## always taken it (natural_style). Returns lines (steps gained, faint marks
## strengthened).
func bank(essence: Dictionary, run_soak: Dictionary) -> Array:
	return pour(essence, run_soak, 0.0)["lines"]


## Pours banked essence into you, split three ways (essence_flow.gd): a share
## (`crystal_share`, whole essence only) condenses into crystals, and body and
## marks divide the rest. Returns {"lines", "made" (kind -> crystals), "keep"
## (kind -> what went into you), "body", "marks", "crystals", "total"}.
func pour(essence: Dictionary, run_soak: Dictionary, crystal_share := 0.0) -> Dictionary:
	var sh: Dictionary = Flow.shares(crystal_share)
	var unbound := Unbound.is_on(self)
	var marked := not bonds.is_empty() and not unbound
	var out := {"lines": [], "made": {}, "keep": {}, "body": 0.0, "marks": 0.0, "crystals": 0.0, "total": 0.0}
	var to_body := {}
	var to_marks := {}
	var bm := float(sh["body"]) + float(sh["marks"])
	for kind in essence:
		var amount := float(essence[kind])
		if amount <= 0.0:
			continue
		out["total"] += amount
		var c := floorf(amount * float(sh["crystals"]))
		if c >= 1.0:
			add_crystal(kind, c)
			out["made"][kind] = c
			out["crystals"] += c
		else:
			c = 0.0
		var rest := amount - c
		out["keep"][kind] = rest
		tally[kind] = float(tally.get(kind, 0.0)) + rest
		var m := rest * float(sh["marks"]) / bm if marked and bm > 0.0 else 0.0
		to_marks[kind] = m
		to_body[kind] = rest - m
		out["marks"] += m
		out["body"] += rest - m
	# The body's share: density, settled in the parts that did the work, and
	# the unmarked parts' soak (batteries filling toward a new mark).
	var style := natural_style(run_soak)
	var style_total := 0.0
	for part in style:
		style_total += maxf(0.0, float(style[part]))
	var levels_before := {}
	var grown_before := {}
	if unbound:
		for part in Unbound.PARTS:
			levels_before[part] = Unbound.level(self, part)
			grown_before[part] = float(Unbound.state(self)["grown"].get(part, 0.0))
	for kind in to_body:
		var b := float(to_body[kind])
		if b <= 0.0:
			continue
		density[kind] = float(density.get(kind, 0.0)) + b
		if unbound:
			# (the Unbound: it soaks into a sleeping Node, or tops up an awake
			# one and refills its use, growing it; what can't go in condenses)
			var left := Unbound.settle(self, kind, b)
			var spill := floorf(left)
			if spill >= 1.0:
				add_crystal(kind, spill)
				out["made"][kind] = float(out["made"].get(kind, 0.0)) + spill
				if Unbound.diverted(self, kind):
					out["lines"].append(Unbound.TEXT["spill_sealed"] % [Flow.Essence.display(kind), int(spill)])  # (its Node is sealed: most condenses on the way)
				else:
					out["lines"].append(Unbound.TEXT["spill"] % [Unbound.node_name(Unbound.part_for(self, kind)), Flow.Essence.display(kind), int(spill)])
		elif style_total > 0.0:
			for part in style:
				var pd: Dictionary = part_density.get(part, {})
				pd[kind] = float(pd.get(kind, 0.0)) + b * maxf(0.0, float(style[part])) / style_total
				part_density[part] = pd
	if not unbound and style_total > 0.0 and float(out["body"]) > 0.0:
		for part in style:
			if bonds.has(part) or not part in Bonds.PARTS:
				continue
			var gain := soak_gain(part, float(out["body"]) * maxf(0.0, float(style[part])) / style_total)
			soak[part] = minf(NEW_MARK_SOAK, float(soak.get(part, 0.0)) + gain)
	if marked:
		out["lines"] = feed_marks(to_marks)
	if unbound:
		out["lines"].append_array(Unbound.absorb(self))
		out["lines"].append_array(unbound_levels(levels_before, grown_before))
		Unbound.end_stair(self)  # (use not refilled here is gone)
	return out


## The stair's lines for an Unbound's Nodes (`before`: part -> level
## before; `grown_before`: part -> size grown by use this climb, before): a
## Node awakening, reaching a new level (its technique, level 12, pure), or
## growing with use. A sleeping Node says nothing: it shows no numbers.
func unbound_levels(before: Dictionary, grown_before := {}) -> Array:
	var lines: Array = []
	var Tech = load("res://scripts/technique.gd")
	var st: Dictionary = Unbound.state(self)
	for part in Unbound.PARTS:
		var was := int(before.get(part, 0))
		var lv := Unbound.level(self, part)
		var name := Unbound.node_name(part)
		if lv > was:
			if was < Unbound.MAX_LEVEL and lv >= Unbound.MAX_LEVEL:
				var sig := Unbound.signature(self, part)
				if not sig.is_empty():
					lines.append(Unbound.TEXT["pure_up"] % [Tech.display(Unbound.primary(self, part)), name, String(sig["name"])])
				else:
					lines.append(Unbound.TEXT["full_up"] % [name, "its capstone wakes"])
			elif was < Unbound.TECH_LEVEL and lv >= Unbound.TECH_LEVEL:
				lines.append(Unbound.TEXT["tech_up"] % [name, lv, "a technique"])
			elif was < Unbound.MINOR_LEVEL and lv >= Unbound.MINOR_LEVEL:
				lines.append(Unbound.TEXT["awake_up"] % [name, Unbound.minor_text(self, part)])
			elif lv >= Unbound.MINOR_LEVEL:
				lines.append(Unbound.TEXT["level_up"] % [name, lv])
			continue
		var g := float(st["grown"].get(part, 0.0)) - float(grown_before.get(part, 0.0))
		if g >= 0.05 and lv >= Unbound.MINOR_LEVEL:
			lines.append(Unbound.TEXT["grew"] % [name, Unbound._num(Unbound.size(self, part))])
	return lines


## How a stair spreads the body's share (`style`: what each part did); with
## nothing done, the way your body has always taken it (where essence has
## settled before), or all six parts alike.
func natural_style(style: Dictionary) -> Dictionary:
	var total := 0.0
	for part in style:
		total += maxf(0.0, float(style[part]))
	if total > 0.0:
		return style
	var out := {}
	for part in part_density:
		var t := 0.0
		for k in part_density[part]:
			t += float(part_density[part][k])
		if t > 0.0 and part in Bonds.PARTS:
			out[part] = t
	if out.is_empty():
		for part in Bonds.PARTS:
			out[part] = 1.0
	return out


## What `amount` of the body's essence adds to an unmarked part's soak: a
## battery (the fuller it is, and the more marks the body carries, the
## slower it fills), at SOAK_RATE (`rate` for a tincture).
func soak_gain(part: String, amount: float, rate := -1.0) -> float:
	if bonds.has(part) or amount <= 0.0:
		return 0.0
	var have := float(soak.get(part, 0.0))
	var fill := clampf(have / NEW_MARK_SOAK, 0.0, 1.0)
	return amount * (SOAK_RATE if rate < 0.0 else rate) * (1.0 - fill) * body_drag()


## The marks' share, by kind: each kind goes to the marks of that kind
## (shared between them, counting AFFINITY_WEIGHT), and a kind no mark is made
## of spreads over every mark (counting OTHER_WEIGHT). Returns lines.
func feed_marks(per_kind: Dictionary) -> Array:
	var gains := {}
	for kind in per_kind:
		var amount := float(per_kind[kind])
		if amount <= 0.0 or bonds.is_empty():
			continue
		var own: Array = bonds.keys().filter(func(pt): return String(Bonds.BONDS.get(String(bonds[pt]["id"]), {}).get("affinity", "")) == String(kind))
		if own.is_empty():
			for part in bonds:
				gains[part] = float(gains.get(part, 0.0)) + amount / float(bonds.size()) * OTHER_WEIGHT
		else:
			for part in own:
				gains[part] = float(gains.get(part, 0.0)) + amount / float(own.size()) * AFFINITY_WEIGHT
	var lines: Array = []
	for part in Bonds.PARTS:
		if gains.has(part):
			lines.append_array(grow_mark(part, float(gains[part])))
	return lines


## A mark takes `gain` (essence already weighted by kind): a faint mark pays
## its debt first; the rest grows it (STEP_RATE, slowed by BODY_DRAG). Lines.
func grow_mark(part: String, gain: float) -> Array:
	var lines: Array = []
	if not bonds.has(part) or gain <= 0.0:
		return lines
	var b: Dictionary = bonds[part]
	var info: Dictionary = Bonds.BONDS[b["id"]]
	if b["faint"]:
		b["debt"] = float(b["debt"]) - gain
		if b["debt"] <= 0.0:
			gain = -float(b["debt"])
			b["debt"] = 0.0
			b["faint"] = false
			lines.append("Your %s mark is no longer faint" % info["name"])
		else:
			return lines
	var before := step_for_xp(float(b["xp"]))
	b["xp"] = minf(float(STEP_XP[STEP_XP.size() - 1]), float(b["xp"]) + gain * STEP_RATE * body_drag())
	var after := step_for_xp(float(b["xp"]))
	if after > before:
		var note: String = Bonds.step_note(b["id"], after)
		lines.append("%s grows to step %d%s" % [info["name"], after, (": " + note) if note != "" else ""])
	return lines


## Drinks a tincture (`amount` of `kind`) into one body part, steered: a
## mark's growth (its own kind counts AFFINITY_WEIGHT, any other OTHER_WEIGHT,
## then Flow.TINCTURE "mark_boost": a tincture's essence is concentrated),
## or an unmarked part's soak (Flow.TINCTURE soak_rate), which also counts
## toward the next mark's kind; the Unbound's raw density there. Returns
## {"lines", "said"} (said: what it did, in a few words).
func drink(kind: String, amount: float, part: String) -> Dictionary:
	var lines: Array = []
	var said := ""
	if amount <= 0.0 or not part in Bonds.PARTS:
		return {"lines": lines, "said": said}
	if Unbound.is_on(self):
		# (a tincture's essence is concentrated: it goes into the Node as
		# much more banked essence would: soaking into a sleeping Node, or
		# topping up an awake one and refilling its use; what can't go in
		# condenses into crystals)
		var boost := float(Flow.TINCTURE.get("mark_boost", 1.0))
		var before := {part: Unbound.level(self, part)}
		var grown0 := {part: float(Unbound.state(self)["grown"].get(part, 0.0))}
		var left := Unbound.settle_into(self, part, kind, amount * boost)
		if left / boost >= 1.0:
			add_crystal(kind, floorf(left / boost))
		density[kind] = float(density.get(kind, 0.0)) + amount
		lines = unbound_levels(before, grown0)
		said = String(Flow.TEXT["to_raw"]) % Unbound.node_name(part)
	elif bonds.has(part):
		var info: Dictionary = Bonds.BONDS[bonds[part]["id"]]
		var gain := amount * (AFFINITY_WEIGHT if String(info["affinity"]) == kind else OTHER_WEIGHT) * float(Flow.TINCTURE.get("mark_boost", 1.0))
		var faint := bool(bonds[part]["faint"])
		var xp0 := float(bonds[part]["xp"])
		lines = grow_mark(part, gain)
		var grown := float(bonds[part]["xp"]) - xp0
		said = String(Flow.TEXT["faint_paid"]) if faint and grown <= 0.0 else String(Flow.TEXT["to_mark"]) % [int(round(grown)), info["name"]]
	else:
		var gain := soak_gain(part, amount, float(Flow.TINCTURE["soak_rate"]))
		soak[part] = minf(NEW_MARK_SOAK, float(soak.get(part, 0.0)) + gain)
		tally[kind] = float(tally.get(kind, 0.0)) + amount
		density[kind] = float(density.get(kind, 0.0)) + amount
		var pd: Dictionary = part_density.get(part, {})
		pd[kind] = float(pd.get(kind, 0.0)) + amount
		part_density[part] = pd
		said = String(Flow.TEXT["to_soak"]) % [String(Bonds.PART_NAMES[part]).to_lower(), soak_pct(part)]
	return {"lines": lines, "said": said}


## How full an unmarked part is, in percent of what a mark needs (0 to 100).
func soak_pct(part: String) -> int:
	return clampi(int(floor(float(soak.get(part, 0.0)) / maxf(NEW_MARK_SOAK * MARK_FULL, 1.0) * 100.0)), 0, 100)


## Banks the path's essence carried up a stair into the flow. Returns lines
## for the stair's banner (what was banked, a step reached).
func bank_flow(amount: float) -> Array:
	if path == "" or amount <= 0.0:
		return []
	var before := Secret.step_for(flow)
	var lines: Array = load("res://scripts/core.gd").bank(self, amount)["lines"]  # (it settles as core essence: core.gd)
	var after := Secret.step_for(flow)
	for st in range(before + 1, after + 1):
		lines.append(Secret.TEXT["step_up"] % [Secret.display(path), st, Secret.STEP_TEXT[path][st - 1]])
	return lines


## The flow's step (0 before the first, or with no path).
func flow_step() -> int:
	return Secret.step_for(flow) if path != "" else 0


## An attribute's small passive bonus (0 to ATTRIBUTE_CAP) from its density.
## The Unbound's comes from their Nodes' sizes instead (unbound.gd attr_size).
func attribute(kind: String) -> float:
	if Unbound.is_on(self):
		return ATTRIBUTE_CAP * Unbound.attr_share(self, kind)
	var d := float(density.get(kind, 0.0))
	return ATTRIBUTE_CAP * d / (d + ATTRIBUTE_HALF)


## The density settled in you of a kind (the bench's tempering asks for it):
## for the Unbound, the size their Nodes count for it (unbound.gd attr_size).
func body_density(kind: String) -> float:
	if Unbound.is_on(self):
		return Unbound.attr_size(self, kind)
	return float(density.get(kind, 0.0))


## How much the body's marks slow every part's filling (BODY_DRAG).
func body_drag() -> float:
	return float(BODY_DRAG[clampi(bonds.size(), 0, BODY_DRAG.size() - 1)])


## The Proving's gift: a mark grows PROVING_GROWTH (not past step 5, and
## not slowed by the marks you carry; a faint mark pays its debt first).
## Returns {"grown": growth added, "step": its step after, "up": true if it
## reached a new step}; {} with no such mark or one grown as far as it goes.
func proving_gift(part: String) -> Dictionary:
	if not bonds.has(part):
		return {}
	var b: Dictionary = bonds[part]
	var top := float(STEP_XP[STEP_XP.size() - 1])
	if float(b["xp"]) >= top:
		return {}
	var gain := PROVING_GROWTH
	if b["faint"]:
		b["debt"] = float(b["debt"]) - gain
		if float(b["debt"]) > 0.0:
			return {"grown": 0.0, "step": step_for_xp(float(b["xp"])), "up": false}
		gain = -float(b["debt"])
		b["debt"] = 0.0
		b["faint"] = false
	var before := step_for_xp(float(b["xp"]))
	var xp0 := float(b["xp"])
	b["xp"] = minf(top, xp0 + gain)
	var after := step_for_xp(float(b["xp"]))
	return {"grown": float(b["xp"]) - xp0, "step": after, "up": after > before}


## A mark goes up one step (the dev tools; the Proving grows a mark by
## PROVING_GROWTH instead): returns its new step, or 0.
func raise_step(part: String) -> int:
	if not bonds.has(part):
		return 0
	var b: Dictionary = bonds[part]
	var st := step_for_xp(float(b["xp"]))
	if st >= STEP_XP.size():
		return 0
	b["xp"] = maxf(float(b["xp"]), float(STEP_XP[st]))
	return st + 1


## An unmarked body part that is full (a battery at MARK_FULL) takes a new
## mark, at a summit. Returns the part, or "" if none is ready.
func ready_for_mark() -> String:
	var need := NEW_MARK_SOAK * MARK_FULL
	var best := ""
	var best_soak := need
	for part in soak:
		if bonds.has(part):
			continue
		if float(soak[part]) >= best_soak:
			best_soak = float(soak[part])
			best = part
	return best
