extends RefCounted
## What carries over between climbs: your marks (bonds), how much essence has
## soaked into your unmarked body parts, and the essence you've banked since
## your last mark. Saved to user://sixfold.cfg.
##
## The first climb is bondless. It ends in the Regard: the tower's beast
## takes notice and your most-used body part takes its first mark. Fall
## during the first climb and you're still regarded, but the mark is faint:
## it must soak up FAINT_DEBT essence before it can grow.

const Bonds := preload("res://scripts/bonds.gd")
const Gear := preload("res://scripts/gear.gd")
const SAVE_PATH := "user://sixfold.cfg"

const FIRST_CLIMB_FLOORS := 3
const FAINT_DEBT := 80.0
## Banked essence needed to reach each step (index = step - 1).
const STEP_XP := [0.0, 60.0, 160.0, 320.0, 540.0]
## Soak an unmarked body part needs before a later mark takes there,
## multiplied by how many marks you already carry.
const NEW_MARK_SOAK := 140.0

var regarded := false
var bonds := {}  # part -> {"id", "xp", "faint", "debt"}
var soak := {}  # part -> banked soak in unmarked parts
var tally := {}  # essence kind -> banked since the last mark
var climbs := 0
var best_floor := 1
var last_tower := "kraken"
var pacts: Array = []  # Covenant's pact book: monster kinds bound, kept between climbs
## Essence density: everything you've banked, by essence type, and how it
## settled in your body parts (by what each part did). Each type is an
## attribute and gives a small passive bonus (see attribute()).
var density := {}  # kind -> amount
var part_density := {}  # part -> {kind -> amount}
## Heirlooms: gear kept from survived climbs, by heirloom slot (gear.gd
## HEIRLOOM_SLOTS) -> a gear record (Rings: a list of up to two). Every
## climb starts with them. Old saves held plain ids; load_save converts them.
var heirlooms := {}
## Essence crystals: essence held outside you, kept between climbs. A vault
## or a secret room may hold some; reading a recall scroll turns unbanked
## essence into them; consuming one banks its essence into you (main.gd
## consume_crystal). Each is {"kind", "amount"}.
var crystals: Array = []
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
var supplies := {}
var supply_paid := {}
var store := {}
## The Entity's record of you (menu.gd shows it): counters that only go up,
## kept with the climber. "deaths", "slain", "beasts", "floors", "puzzles",
## "falls", "heirlooms", "essence", plus "best" (tower -> best floor) and
## "beasts_by" (tower -> beasts slain there). See note() and note_floor().
var record := {}
## Climbers before this one (New climber): the Entity remembers them.
var former := 0

const ATTRIBUTES := {
	"air": {"name": "Agility", "bonus": "move speed"},
	"blade": {"name": "Strength", "bonus": "strike damage"},
	"stone": {"name": "Vitality", "bonus": "health"},
	"iron": {"name": "Will", "bonus": "stamina recovery"},
	"fire": {"name": "Intellect", "bonus": "spell power"},
	"water": {"name": "Spirit", "bonus": "marks fill faster"},
}
## The bonuses are small: they grow with diminishing returns toward the cap.
const ATTRIBUTE_CAP := 0.12
const ATTRIBUTE_HALF := 600.0  # density at which a bonus is half the cap
var saving := true
## Where the profile is saved (tests point it elsewhere).
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
	density = {}
	part_density = {}
	heirlooms = {}
	crystals = []
	chest = []
	pack = []
	supplies = {}
	supply_paid = {}
	store = {}
	record = {}
	save()


func load_save() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(save_path) != OK:
		return
	best_floor = int(cfg.get_value("climb", "best_floor", 1))
	regarded = bool(cfg.get_value("profile", "regarded", false))
	bonds = cfg.get_value("profile", "bonds", {})
	soak = cfg.get_value("profile", "soak", {})
	tally = cfg.get_value("profile", "tally", {})
	climbs = int(cfg.get_value("profile", "climbs", 0))
	pacts = cfg.get_value("profile", "pacts", [])
	density = cfg.get_value("profile", "density", {})
	part_density = cfg.get_value("profile", "part_density", {})
	last_tower = str(cfg.get_value("profile", "last_tower", "kraken"))
	heirlooms = Gear.load_heirlooms(cfg.get_value("profile", "heirlooms", {}))
	crystals = cfg.get_value("profile", "crystals", [])
	chest = _records(cfg.get_value("train", "chest", []))
	pack = _records(cfg.get_value("train", "pack", []))
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
	record = cfg.get_value("profile", "record", {})
	former = int(cfg.get_value("profile", "former", 0))


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
	cfg.set_value("profile", "density", density)
	cfg.set_value("profile", "part_density", part_density)
	cfg.set_value("profile", "heirlooms", heirlooms)
	cfg.set_value("profile", "crystals", crystals)
	cfg.set_value("profile", "record", record)
	cfg.set_value("profile", "former", former)
	cfg.set_value("train", "chest", chest)
	cfg.set_value("train", "pack", pack)
	cfg.set_value("train", "supplies", supplies)
	cfg.set_value("train", "supply_paid", supply_paid)
	cfg.set_value("train", "store", store)
	cfg.save(save_path)


## Gear records from a save (unknown or broken entries are dropped).
static func _records(raw) -> Array:
	var out: Array = []
	if raw is Array:
		for g in raw:
			var r := Gear.rec(g)
			if not r.is_empty():
				out.append(r)
	return out


# --- essence crystals ------------------------------------------------------------

## Keeps an essence crystal (amounts under 1 make none).
func add_crystal(kind: String, amount: float) -> void:
	if amount < 1.0:
		return
	crystals.append({"kind": kind, "amount": float(round(amount))})


## How many crystals of a kind you hold, and how much essence they hold.
func crystal_count(kind: String) -> int:
	return crystals.filter(func(c): return c["kind"] == kind).size()


func crystal_total(kind: String) -> float:
	var total := 0.0
	for c in crystals:
		if c["kind"] == kind:
			total += float(c["amount"])
	return total


## Takes one crystal of a kind (the first kept); its essence, or 0 if none.
func take_crystal(kind: String) -> float:
	for i in crystals.size():
		if crystals[i]["kind"] == kind:
			var amount := float(crystals[i]["amount"])
			crystals.remove_at(i)
			return amount
	return 0.0


## Pays `amount` essence of a kind in crystals: the smallest crystals of
## that kind first; if they hold more than the price, the rest comes back
## as one new crystal (change). False (and nothing taken) if you hold too
## little.
func spend(kind: String, amount: float) -> bool:
	amount = ceilf(amount)
	if amount <= 0.0:
		return true
	if crystal_total(kind) < amount:
		return false
	var mine: Array = []
	for i in crystals.size():
		if crystals[i]["kind"] == kind:
			mine.append(i)
	mine.sort_custom(func(a, b): return float(crystals[a]["amount"]) < float(crystals[b]["amount"]))
	var paid := 0.0
	var used: Array = []
	for i in mine:
		if paid >= amount:
			break
		paid += float(crystals[i]["amount"])
		used.append(i)
	used.sort()
	used.reverse()
	for i in used:
		crystals.remove_at(i)
	add_crystal(kind, paid - amount)
	return true


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
		if soaked > 0.0:
			for part in run_soak:
				var pd: Dictionary = part_density.get(part, {})
				pd[kind] = float(pd.get(kind, 0.0)) + float(essence[kind]) * float(run_soak[part]) / soaked
				part_density[part] = pd
	for part in run_soak:
		if not bonds.has(part):
			soak[part] = float(soak.get(part, 0.0)) + float(run_soak[part])
	for part in bonds:
		var b: Dictionary = bonds[part]
		var info: Dictionary = Bonds.BONDS[b["id"]]
		# Essence of the bond's own kind counts double.
		var gain := total + float(essence.get(info["affinity"], 0.0))
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
		b["xp"] = float(b["xp"]) + gain
		var after := step_for_xp(float(b["xp"]))
		if after > before:
			var note: String = Bonds.step_note(b["id"], after)
			lines.append("%s grows to step %d%s" % [info["name"], after, (": " + note) if note != "" else ""])
	return lines


## An attribute's small passive bonus (0 to ATTRIBUTE_CAP) from its density.
func attribute(kind: String) -> float:
	var d := float(density.get(kind, 0.0))
	return ATTRIBUTE_CAP * d / (d + ATTRIBUTE_HALF)


## An unmarked body part that has soaked up enough takes a new mark.
## Returns the part, or "" if none is ready.
func ready_for_mark() -> String:
	var need := NEW_MARK_SOAK * float(maxi(1, bonds.size()))
	var best := ""
	var best_soak := need
	for part in soak:
		if bonds.has(part):
			continue
		if float(soak[part]) >= best_soak:
			best_soak = float(soak[part])
			best = part
	return best
