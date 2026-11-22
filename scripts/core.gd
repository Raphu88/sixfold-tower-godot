extends RefCounted
## CORE ESSENCE AND THE AURA. Every word and number about them is here.
##
## The core essences are the two secret essences (secret.gd: Making and
## Unmaking, the Makers' own). A climber lets in one of them, for good (the
## PATH). Carried up a stair, the path's essence settles in the body as CORE
## ESSENCE (profile.flow is the body's total): much slower than other essence
## (RATE of what you carry), spread EVENLY over the six body parts, and it
## STOPS once the body is saturated (every part holds CAP). Core essence
## that would come after that waits for Ascendance, which is "Coming soon".
##
## THE AURA is the core essence made visible: the more the body holds, the
## stronger it shows around the climber and the stronger its bonuses
## (secret.gd STEPS and EFFECTS: six steps, the same for marked climbers and
## the Unbound).
##
## The Unbound's body parts are Nodes (unbound.gd). Each part's CAP is
## shared between the Node's own essence (at most its size) and the core:
## the core takes room in every part, and their own essence can't push it
## out (a Node holds less while core fills its part). So for them the body
## saturates sooner, and a Node whose core is at least half of what it
## holds becomes CORE-LED (unbound.gd). A
## core-led Node slowly ABSORBS its other essences into core (ABSORB of them
## at each stair). Their per-Node core is kept in profile.unbound["core"]
## (part -> amount, always adding up to profile.flow); a marked climber's is
## simply flow / 6.

const PARTS := ["hand", "legs", "heart", "brow", "throat", "back"]
## What one body part holds at most (its own essence and core together).
static var CAP := 120.0
## Of the path's essence carried up a stair, this share settles as core.
static var RATE := 0.5
## A core-led part turns this share of its other essences into core at each
## stair (at least ABSORB_MIN of it, while any is left).
static var ABSORB := 1.0 / 6.0
static var ABSORB_MIN := 1.0

static var TEXT := {
	"name": "core essence",
	"aura": "Aura",
	"banked": "Banked %d %s: %s core essence settles in your body",
	"banked_full": "Banked %d %s: your body is saturated with core essence",
	"saturated": "Your body is saturated with core essence",
	"ascendance": "Ascendance: coming soon",
	"ascendance_says": "Core essence past saturation will one day start to replace your other essence. Coming soon.",
	"per_part": "%d core essence in each body part",
	"total": "%d core essence in your body, of %d it can hold",
	"absorbed": "Your core-led %s absorbs %d %s",
	"aura_step": "Aura step %d of %d",
	"aura_none": "No aura yet: it shows once %d core essence has settled",
}


static func _unbound():
	return load("res://scripts/unbound.gd")


static func is_unbound(prof) -> bool:
	return prof != null and _unbound().is_on(prof)


## A part's own (non-core) essence: the Unbound's cup; 0 for a marked climber.
static func own(prof, part: String) -> float:
	if not is_unbound(prof):
		return 0.0
	return _unbound().own(prof, part)


## What one body part can hold, its own essence and core together (CAP:
## the same for everyone; an Unbound's own essence is also kept within its
## Node's size, unbound.gd room). An Unbound's sealed Node holds no core.
static func cap_of(prof, part: String) -> float:
	if prof != null and _unbound().sealed(prof, part):
		return 0.0
	return CAP


## How much core essence the body can hold now (every part's free room).
static func capacity(prof) -> float:
	var total := 0.0
	for part in PARTS:
		total += maxf(0.0, cap_of(prof, part) - own(prof, part))
	return total


## The core essence in each body part: {part: amount}.
static func parts(prof) -> Dictionary:
	var out := {}
	if prof == null or prof.path == "":
		for part in PARTS:
			out[part] = 0.0
		return out
	if not is_unbound(prof):
		var each := minf(float(prof.flow), CAP * PARTS.size()) / float(PARTS.size())
		for part in PARTS:
			out[part] = each
		return out
	sync(prof)
	var st: Dictionary = _unbound().state(prof)
	for part in PARTS:
		out[part] = float(st["core"].get(part, 0.0))
	return out


static func in_part(prof, part: String) -> float:
	return float(parts(prof).get(part, 0.0))


## The body's total (profile.flow, never past what it can hold).
static func total(prof) -> float:
	if prof == null or prof.path == "":
		return 0.0
	return minf(float(prof.flow), capacity(prof))


static func saturated(prof) -> bool:
	return prof != null and prof.path != "" and float(prof.flow) >= capacity(prof) - 0.01


## Spreads `amount` of core over the parts as evenly as their free room
## allows (`room`: part -> room left). Returns what each part takes.
static func spread(room: Dictionary, amount: float) -> Dictionary:
	var out := {}
	for part in room:
		out[part] = 0.0
	var left := amount
	for _i in PARTS.size() + 1:
		if left <= 0.0001:
			break
		var open: Array = room.keys().filter(func(pt): return float(room[pt]) - float(out[pt]) > 0.0001)
		if open.is_empty():
			break
		var each := left / float(open.size())
		for pt in open:
			var take := minf(each, float(room[pt]) - float(out[pt]))
			out[pt] = float(out[pt]) + take
			left -= take
	return out


## The Unbound's per-part core made to add up to profile.flow (a changed
## flow, an old save): more is spread evenly, less is taken evenly; flow
## never passes what the body can hold.
static func sync(prof) -> void:
	if not is_unbound(prof):
		return
	var U = _unbound()
	var st: Dictionary = U.state(prof)
	var core: Dictionary = st["core"]
	var have := 0.0
	for part in PARTS:
		var c := clampf(float(core.get(part, 0.0)), 0.0, maxf(0.0, cap_of(prof, part) - U.own(prof, part)))
		core[part] = c
		have += c
	if prof.path == "":
		for part in PARTS:
			core[part] = 0.0
		return
	prof.flow = clampf(float(prof.flow), 0.0, capacity(prof))
	var want := float(prof.flow)
	if want > have + 0.001:
		var room := {}
		for part in PARTS:
			room[part] = maxf(0.0, cap_of(prof, part) - U.own(prof, part) - float(core[part]))
		var got := spread(room, want - have)
		for part in PARTS:
			core[part] = float(core[part]) + float(got[part])
	elif want < have - 0.001:
		var k := want / maxf(have, 0.001)
		for part in PARTS:
			core[part] = float(core[part]) * k


## The path's essence carried up a stair settles as core (RATE of it), as
## far as the body has room. Returns {"added", "lines"}.
static func bank(prof, carried: float) -> Dictionary:
	var out := {"added": 0.0, "lines": []}
	if prof == null or prof.path == "" or carried <= 0.0:
		return out
	sync(prof)
	var add := minf(carried * RATE, maxf(0.0, capacity(prof) - float(prof.flow)))
	var Secret = load("res://scripts/secret.gd")
	if add <= 0.0001:
		out["lines"].append(TEXT["banked_full"] % [int(round(carried)), Secret.display(prof.path)])
		return out
	if is_unbound(prof):
		var U = _unbound()
		var st: Dictionary = U.state(prof)
		var room := {}
		for part in PARTS:
			room[part] = maxf(0.0, cap_of(prof, part) - U.own(prof, part) - float(st["core"].get(part, 0.0)))
		var got := spread(room, add)
		for part in PARTS:
			st["core"][part] = float(st["core"].get(part, 0.0)) + float(got[part])
	prof.flow = float(prof.flow) + add
	out["added"] = add
	out["lines"].append(TEXT["banked"] % [int(round(carried)), Secret.display(prof.path), _num(add)])
	if saturated(prof):
		out["lines"].append(TEXT["saturated"])
	return out


## Core added to one part only (a core-led part absorbing its other essence,
## or the Making path turning drained essence into core: spread evenly).
static func add(prof, amount: float, part := "") -> float:
	if prof == null or prof.path == "" or amount <= 0.0:
		return 0.0
	if not is_unbound(prof):
		var a := minf(amount, maxf(0.0, capacity(prof) - float(prof.flow)))
		prof.flow = float(prof.flow) + a
		return a
	sync(prof)
	var U = _unbound()
	var st: Dictionary = U.state(prof)
	var got := {}
	if part != "":
		var room := maxf(0.0, cap_of(prof, part) - U.own(prof, part) - float(st["core"].get(part, 0.0)))
		got[part] = minf(amount, room)
	else:
		var room2 := {}
		for pt in PARTS:
			room2[pt] = maxf(0.0, cap_of(prof, pt) - U.own(prof, pt) - float(st["core"].get(pt, 0.0)))
		got = spread(room2, amount)
	var added := 0.0
	for pt in got:
		st["core"][pt] = float(st["core"].get(pt, 0.0)) + float(got[pt])
		added += float(got[pt])
	prof.flow = float(prof.flow) + added
	return added


static func _num(f: float) -> String:
	return str(int(round(f))) if absf(f - round(f)) < 0.05 or f >= 10.0 else "%.1f" % f
