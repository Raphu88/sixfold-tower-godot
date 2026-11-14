extends RefCounted
## What carries over between climbs: your marks (bonds), how much essence has
## soaked into your unmarked body parts, and the essence you've banked since
## your last mark. Each climber is saved in their own slot's file (slots.gd:
## user://climber_1.cfg to climber_6.cfg); save_path says which.
##
## The first climb is bondless. It ends in the Regard: the tower's beast
## takes notice and your most-used body part takes its first mark. Fall
## during the first climb and you're still regarded, but the mark is faint:
## it must soak up FAINT_DEBT essence before it can grow.

const Bonds := preload("res://scripts/bonds.gd")
const Gear := preload("res://scripts/gear.gd")
const Secret := preload("res://scripts/secret.gd")
const Appearance := preload("res://scripts/appearance.gd")
const Unbound := preload("res://scripts/unbound.gd")
## Slot 1's file (main.gd points save_path at the current slot's: slots.gd).
const SAVE_PATH := "user://climber_1.cfg"

const FIRST_CLIMB_FLOORS := 3
static var FAINT_DEBT := 80.0
## Banked essence needed to reach each step (index = step - 1). A bond grows
## from its own essence (AFFINITY_WEIGHT) and a little from the rest
## (OTHER_WEIGHT), slowed by STEP_RATE and by how many marks the body already
## carries (BODY_DRAG). The Proving (floor 6) can raise a mark a step too.
static var STEP_XP := [0.0, 150.0, 450.0, 1000.0, 1800.0]
static var AFFINITY_WEIGHT := 2.0
static var OTHER_WEIGHT := 0.25
static var STEP_RATE := 0.25
## Marks after the first: an unmarked body part fills like a battery. It
## soaks up only SOAK_RATE of what it does, and the fuller it is the slower it
## fills (gain x (1 - fill)); a body that carries more marks fills every part
## slower still (BODY_DRAG, by marks carried). A part is full (ready for a
## mark) at MARK_FULL of NEW_MARK_SOAK. New marks come only at a summit, at
## most one a climb (main.gd). Numbers are first guesses: aim, 20+ climbs
## for all six marks.
static var NEW_MARK_SOAK := 250.0
static var SOAK_RATE := 0.4
static var MARK_FULL := 0.9
static var BODY_DRAG := [1.0, 1.0, 0.7, 0.5, 0.35, 0.25, 0.2]

var regarded := false
var bonds := {}  # part -> {"id", "xp", "faint", "debt"}
var soak := {}  # part -> banked soak in unmarked parts
var tally := {}  # essence kind -> banked since the last mark
var climbs := 0
var best_floor := 1
var last_tower := "kraken"
var pacts: Array = []  # Covenant's kin book: monster kinds bound, kept between climbs
var pacts_formed: Array = []  # named pacts (pacts.gd) formed at least once: announced once, listed in the book
## Essence density: everything you've banked, by essence type, and how it
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
## (train.gd CONDENSE_*), the outfitter pays some for every climb
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
## ("" until then, else "life" or "unmaking"; for good) and the flow banked
## (the path's essence, which lives in the climber's shadow).
var path := ""
var flow := 0.0
## How the climber looks (appearance.gd: option ids, and an optional name).
## Old saves load with today's look (Appearance.DEFAULTS).
var appearance := Appearance.DEFAULTS.duplicate()
## False until a new climber has chosen their look on the creation page
## (the very first launch, a new slot, and after Start over): it opens before the first climb.
var created := true
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
static var ATTRIBUTE_HALF := 600.0  # density at which a bonus is half the cap
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
	pacts = []
	pacts_formed = []
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
	best_floor = int(cfg.get_value("climb", "best_floor", 1))
	regarded = bool(cfg.get_value("profile", "regarded", false))
	bonds = cfg.get_value("profile", "bonds", {})
	soak = cfg.get_value("profile", "soak", {})
	tally = cfg.get_value("profile", "tally", {})
	climbs = int(cfg.get_value("profile", "climbs", 0))
	pacts = cfg.get_value("profile", "pacts", [])
	pacts_formed = cfg.get_value("profile", "pacts_formed", [])
	density = cfg.get_value("profile", "density", {})
	part_density = cfg.get_value("profile", "part_density", {})
	last_tower = str(cfg.get_value("profile", "last_tower", "kraken"))
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
				supplies[String(id)] = int(sup[id])
	supply_paid = {}
	var paid = cfg.get_value("train", "supply_paid", {})
	if paid is Dictionary:
		for id in paid:
			if supplies.has(String(id)) and paid[id] is Array:
				supply_paid[String(id)] = paid[id].filter(func(c): return c is Dictionary).slice(0, int(supplies[String(id)]))
	store = cfg.get_value("train", "store", {})
	if not (store is Dictionary):
		store = {}
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
	var ce = cfg.get_value("profile", "core_edit", {})
	core_edit = ce if ce is Dictionary else {}
	var rn = cfg.get_value("renown", "state", {})
	renown = rn if rn is Dictionary else {}
	bestiary = load("res://scripts/bestiary.gd").load_records(cfg.get_value("bestiary", "met", {}))
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
	cfg.set_value("profile", "pacts", pacts)
	cfg.set_value("profile", "pacts_formed", pacts_formed)
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


## Marks a body part with a bond. Faint marks owe FAINT_DEBT essence first.
func add_bond(part: String, id: String, faint: bool) -> void:
	bonds[part] = {"id": id, "xp": 0.0, "faint": faint, "debt": FAINT_DEBT if faint else 0.0}
	soak.erase(part)
	tally = {}


## Banks a stair's worth of essence and soak. Returns lines describing what
## changed (steps gained, faint marks strengthened).
func bank(essence: Dictionary, run_soak: Dictionary) -> Array:
	var lines: Array = []
	var total := 0.0
	var soaked := 0.0
	for part in run_soak:
		soaked += float(run_soak[part])
	for kind in essence:
		total += float(essence[kind])
		tally[kind] = float(tally.get(kind, 0.0)) + float(essence[kind])
		# Density: the essence settles in your body, by type and by part.
		density[kind] = float(density.get(kind, 0.0)) + float(essence[kind])
		if Unbound.is_on(self):
			Unbound.settle(self, kind, float(essence[kind]))  # (the Unbound: raw, in its part)
		elif soaked > 0.0:
			for part in run_soak:
				var pd: Dictionary = part_density.get(part, {})
				pd[kind] = float(pd.get(kind, 0.0)) + float(essence[kind]) * float(run_soak[part]) / soaked
				part_density[part] = pd
	for part in run_soak:
		if not bonds.has(part) and not Unbound.is_on(self):
			# A battery: the fuller the part (and the more marks the body carries), the slower it fills.
			var have := float(soak.get(part, 0.0))
			var fill := clampf(have / NEW_MARK_SOAK, 0.0, 1.0)
			var gain_soak: float = float(run_soak[part]) * SOAK_RATE * (1.0 - fill) * body_drag()
			soak[part] = minf(NEW_MARK_SOAK, have + gain_soak)
	for part in bonds:
		var b: Dictionary = bonds[part]
		var info: Dictionary = Bonds.BONDS[b["id"]]
		# Its own kind counts most; the rest a little.
		var own := float(essence.get(info["affinity"], 0.0))
		var gain := own * AFFINITY_WEIGHT + (total - own) * OTHER_WEIGHT
		if gain <= 0.0:
			continue
		if b["faint"]:
			b["debt"] = float(b["debt"]) - gain
			if b["debt"] <= 0.0:
				gain = -float(b["debt"])
				b["debt"] = 0.0
				b["faint"] = false
				lines.append("Your %s mark is no longer faint" % info["name"])
			else:
				continue
		var before := step_for_xp(float(b["xp"]))
		b["xp"] = minf(float(STEP_XP[STEP_XP.size() - 1]), float(b["xp"]) + gain * STEP_RATE * body_drag())
		var after := step_for_xp(float(b["xp"]))
		if after > before:
			var note: String = Bonds.step_note(b["id"], after)
			lines.append("%s grows to step %d%s" % [info["name"], after, (": " + note) if note != "" else ""])
	return lines


## Banks the path's essence carried up a stair into the flow. Returns lines
## for the stair's banner (what was banked, a step reached).
func bank_flow(amount: float) -> Array:
	if path == "" or amount <= 0.0:
		return []
	var before := Secret.step_for(flow)
	flow += amount
	var after := Secret.step_for(flow)
	var lines: Array = [Secret.TEXT["banked"] % [int(round(amount)), Secret.display(path)]]
	for st in range(before + 1, after + 1):
		lines.append(Secret.TEXT["step_up"] % [Secret.display(path), st, Secret.STEP_TEXT[path][st - 1]])
	return lines


## The flow's step (0 before the first, or with no path).
func flow_step() -> int:
	return Secret.step_for(flow) if path != "" else 0


## An attribute's small passive bonus (0 to ATTRIBUTE_CAP) from its density.
func attribute(kind: String) -> float:
	var d := float(density.get(kind, 0.0))
	return ATTRIBUTE_CAP * d / (d + ATTRIBUTE_HALF)


## How much the body's marks slow every part's filling (BODY_DRAG).
func body_drag() -> float:
	return float(BODY_DRAG[clampi(bonds.size(), 0, BODY_DRAG.size() - 1)])


## A mark goes up one step (the Proving's gift): returns its new step, or 0.
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
