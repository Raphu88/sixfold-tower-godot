extends RefCounted
## STATES AND REACTIONS: what spells leave on a foe, and what happens when
## two of them meet. Every name, line, colour and number is here, in data
## (the Data editor's "States and reactions" sections: data_registry.gd).
##
## A STATE is something a foe holds for a while: charged, airborne, soaked,
## burning, poisoned, bleeding, slowed, unseen. One place keeps them: the
## foe's `states` dictionary (enemy.gd), state -> seconds left. The older
## fields (enemy.gd charged, airborne, burn_t, venom_t, chill_t, lost_t) are
## that same dictionary under their old names, so every spell that already
## charged, lifted, burned, poisoned, chilled or blinded a foe now gives it
## the state too. Two STATES entries are moments, not states ("event": true):
## a "slam" (Quake, Downdraft, any heavy blow on a foe in the air) and a
## "drained" (a Deepcaller's drains, a Lifeline).
##
## A REACTION fires once when a state lands on a foe that already holds the
## other of its pair ("states"). It may clear states ("consume"), and waits
## "again" seconds before it can fire on that foe again. Each has a word that
## rises over the foe (its "name"), a look and a sound from the bank.
##
## For content files (scripts/spells/, bond.gd, later mark work):
##   Reactions.apply(main, foe, state, seconds, source, amount := 0.0) -> Array
##       gives the foe a state (or a moment), and returns the ids of the
##       reactions that fired because of it ([] if none). `amount`: burning
##       and bleeding damage a half second, poison stacks (0: STATES' own;
##       -1: only the state, the caller does its own damage).
##   Reactions.has(foe, state) -> bool       does it hold this state now?
##   Reactions.left(foe, state) -> float     seconds of it left
##   Reactions.held(foe) -> Array            every state it holds
##   Reactions.clear(foe, state)             takes a state away
##   Reactions.num(id, key)                  a reaction's number (REACTIONS)
##   main.on_reaction(foe, id, source)       a signal: a reaction fired (any foe;
##                                           enemy.gd on_reaction for one foe)
##   static func on_reaction(p, info) in a content file (library.gd on_reaction):
##       info {"id", "foe", "at", "source", "states"}
## A foe's old fields still work: `e.charged = 4.0` charges it (and may set
## off a reaction), `e.ignite(dmg, s)` burns it, `e.add_venom(n)` poisons it,
## `e.lift(s)` throws it up, `e.lose_track(s, null)` makes you unseen,
## `e.chill_t = s` slows it; e.soak(s) and e.bleed(dps, s) are new.
##
## The climber: whether monsters can give YOU states is the owner's open
## question. It is built (CLIMBER) but off: with "enabled" false, nothing
## lands on the climber at all.

const SpellFx := preload("res://scripts/spell_fx.gd")
const UI := preload("res://scripts/ui.gd")

## The states. "seconds": how long one lasts when a spell doesn't say;
## "dps": burning or bleeding damage each half second; "stacks": poison.
## "event": a moment (it reacts with what the foe holds, and is gone).
static var STATES := {
	"charged": {"name": "Charged", "says": "crackling with lightning", "color": Color(0.95, 0.89, 0.42), "seconds": 4.0},
	"airborne": {"name": "Airborne", "says": "thrown into the air, helpless", "color": Color(0.82, 0.93, 1.0), "seconds": 1.2},
	"soaked": {"name": "Soaked", "says": "dripping wet", "color": Color(0.36, 0.66, 0.96), "seconds": 4.0},
	"burning": {"name": "Burning", "says": "on fire, hurt every half second", "color": Color(1.0, 0.55, 0.2), "seconds": 3.0, "dps": 2.0},
	"poisoned": {"name": "Poisoned", "says": "poison stacks hurt it every half second", "color": Color(0.55, 0.86, 0.35), "stacks": 1},
	"bleeding": {"name": "Bleeding", "says": "bleeding, hurt every half second", "color": Color(0.86, 0.18, 0.2), "seconds": 3.0, "dps": 1.5},
	"slowed": {"name": "Slowed", "says": "walking slower", "color": Color(0.7, 0.9, 0.98), "seconds": 2.0},
	"unseen": {"name": "Unseen", "says": "it has lost sight of you", "color": Color(0.74, 0.7, 0.68), "seconds": 2.0},
	"slam": {"name": "Slam", "says": "slammed down hard", "color": Color(0.85, 0.75, 0.6), "event": true},
	"drained": {"name": "Drained", "says": "its life drawn out", "color": Color(0.5, 0.9, 0.75), "event": true},
}

## The reactions: the two states that meet ("states"), what's cleared
## ("consume"), how long before it can fire on the same foe again ("again",
## seconds), its sound and numbers. Damage grows with your strongest mark's
## step (RULES "per_step").
static var REACTIONS := {
	"conduct": {"name": "Conduct", "says": "Lightning jumps to every soaked foe nearby and stuns it", "states": ["soaked", "charged"], "consume": ["soaked"],
		"color": Color(0.62, 0.86, 1.0), "sound": "zap", "pitch": 0.7, "again": 1.0, "radius": 140.0, "stun": 1.0, "damage": 6.0},
	"steam": {"name": "Steam", "says": "A cloud of steam: foes inside lose track of you", "states": ["soaked", "burning"], "consume": ["soaked", "burning"],
		"color": Color(0.92, 0.94, 0.96), "sound": "hiss", "pitch": 0.9, "again": 1.5, "radius": 75.0, "seconds": 3.5, "lose": 0.8},
	"fumes": {"name": "Fumes", "says": "The poison spreads to its neighbours as burning gas", "states": ["burning", "poisoned"], "consume": [],
		"color": Color(0.8, 0.78, 0.3), "sound": "burn", "pitch": 0.75, "again": 3.0, "radius": 95.0, "share": 0.5, "burn": 2.0, "burn_t": 3.0},
	"crater": {"name": "Crater", "says": "Slammed from the air: a big hit, and its neighbours are knocked down", "states": ["airborne", "slam"], "consume": ["airborne"],
		"color": Color(0.88, 0.76, 0.56), "sound": "slam", "pitch": 0.75, "again": 0.5, "damage": 14.0, "radius": 85.0, "splash": 6.0, "down": 0.8},
	"skybolt": {"name": "Skybolt", "says": "A bolt from above strikes it as it falls", "states": ["airborne", "charged"], "consume": ["airborne", "charged"],
		"color": Color(1.0, 0.95, 0.6), "sound": "thunder", "pitch": 1.1, "again": 1.0, "damage": 16.0, "stun": 0.6},
	"hemorrhage": {"name": "Hemorrhage", "says": "Draining a bleeding foe: the drain is doubled", "states": ["bleeding", "drained"], "consume": [],
		"color": Color(0.9, 0.2, 0.3), "sound": "hit_slime", "pitch": 0.7, "again": 0.0, "mult": 2.0},
	"smoulder": {"name": "Smoulder", "says": "A slowed foe burns twice as long", "states": ["slowed", "burning"], "consume": [],
		"color": Color(0.95, 0.42, 0.18), "sound": "burn", "pitch": 0.6, "again": 6.0, "mult": 2.0},
	"ambush": {"name": "Ambush", "says": "Poisoned while it can't see you: 5 more stacks, and it notices you", "states": ["unseen", "poisoned"], "consume": ["unseen"],
		"color": Color(0.62, 0.9, 0.5), "sound": "crit", "pitch": 1.2, "again": 8.0, "stacks": 5},
}

## How reactions behave: "per_step" more damage for each step of your
## strongest mark past the first; at most "depth" reactions set off by one
## another in a row (a chain through a crowd stops there); "word" the size
## of the word that rises.
static var RULES := {"per_step": 0.15, "depth": 4, "word": 17.0, "word_time": 1.1}

## Monsters giving the climber states (an open question): off unless
## "enabled". "from": which state each monster's blows would leave, for
## "seconds"; a reaction on the climber deals "damage" and "burn"/"bleed"
## hurt each half second.
static var CLIMBER := {
	"enabled": false, "seconds": 3.0, "damage": 6.0, "burn": 1.0, "bleed": 1.0,
	"from": {"thunderling": "charged", "gryphon": "charged", "lurker": "soaked", "kraken": "soaked", "cinder": "burning", "wyvern": "burning",
		"firebird": "burning", "scorpling": "poisoned", "manticore": "poisoned", "bloomcap": "poisoned", "thornhound": "bleeding", "mongrel": "bleeding"},
}

## How many times each reaction has fired (the tests read it).
static var FIRED := {}
## The reactions fired since the outermost apply() began (what it returns).
static var _log: Array = []
static var _sources: Array = []  # the source of each apply() on the stack
static var _depth := 0


# --- the API -----------------------------------------------------------------------

## Gives `foe` a state for `seconds` (or a moment: "slam", "drained"), and
## returns the reactions it set off. `source` is whatever caused it (a bond,
## a technique's id, a string): listeners hear it. `amount`: burning and
## bleeding damage each half second, or poison stacks (0: the state's own;
## below 0: only the state, when the caller does the damage itself).
static func apply(main, foe, state: String, seconds: float, source = null, amount := 0.0) -> Array:
	if foe == null or not is_instance_valid(foe) or main == null or not STATES.has(state):
		return []
	if is_climber(foe):
		return _apply_climber(main, foe, state, seconds, source)
	if not ("states" in foe) or foe.dead or foe.ally:
		return []
	var st: Dictionary = STATES[state]
	var start := _log.size()
	_sources.push_back(source)
	if bool(st.get("event", false)):
		landed(main, foe, state)
	else:
		var secs := seconds if seconds > 0.0 else float(st.get("seconds", 2.0))
		match state:
			"burning":
				foe.ignite(amount if amount > 0.0 else (0.0 if amount < 0.0 else float(st["dps"])), secs)
			"poisoned":
				foe.add_venom(int(amount) if amount >= 1.0 else int(st["stacks"]))
			"bleeding":
				foe.bleed(amount if amount > 0.0 else (0.0 if amount < 0.0 else float(st["dps"])), secs)
			"airborne":
				foe.lift(secs)
			"unseen":
				foe.lose_track(secs, null)
			_:
				foe.hold_state(state, secs)
	_sources.pop_back()
	var out: Array = _log.slice(start)
	if _sources.is_empty():
		_log.clear()
	return out


## True while the foe holds the state. Poison needs a stack; "unseen" is
## any foe that hasn't noticed you, is asleep or has lost you (Ashwalker's
## smoke, Vanish, Ashfall); "slowed" counts a Surgeon's crippling too.
static func has(foe, state: String) -> bool:
	if foe == null or not is_instance_valid(foe) or not ("states" in foe):
		return false
	if is_climber(foe):
		return float(foe.states.get(state, 0.0)) > 0.0
	match state:
		"poisoned":
			return foe.venom > 0 and float(foe.states.get("poisoned", 0.0)) > 0.0
		"unseen":
			return not foe.dead and (foe.unaware() or (not foe.aware and not foe.is_boss()))
		"slowed":
			return float(foe.states.get("slowed", 0.0)) > 0.0 or foe.cripple_t > 0.0
		"burning":
			return float(foe.states.get("burning", 0.0)) > 0.0 and not foe.submerged
	return float(foe.states.get(state, 0.0)) > 0.0


static func left(foe, state: String) -> float:
	if foe == null or not is_instance_valid(foe) or not ("states" in foe):
		return 0.0
	return maxf(0.0, float(foe.states.get(state, 0.0)))


## Every (timed) state the foe holds now, in STATES order.
static func held(foe) -> Array:
	var out: Array = []
	for s in STATES:
		if not bool(STATES[s].get("event", false)) and has(foe, s):
			out.append(s)
	return out


static func clear(foe, state: String) -> void:
	if foe == null or not is_instance_valid(foe):
		return
	if is_climber(foe):
		foe.states.erase(state)
	elif foe.has_method("clear_state"):
		foe.clear_state(state)


static func num(id: String, key: String) -> float:
	return float(REACTIONS.get(id, {}).get(key, 0.0))


static func name_of(id: String) -> String:
	if REACTIONS.has(id):
		return String(REACTIONS[id]["name"])
	return String(STATES.get(id, {}).get("name", id))


static func color_of(id: String) -> Color:
	if REACTIONS.has(id):
		return REACTIONS[id]["color"]
	return STATES.get(id, {}).get("color", Color.WHITE)


static func is_climber(node) -> bool:
	return node != null and "is_climber" in node and bool(node.is_climber)


# --- reactions ---------------------------------------------------------------------

## A state just landed on a foe (enemy.gd calls this when one rises; apply()
## for a moment): every reaction whose other state it holds fires.
static func landed(main, foe, state: String) -> void:
	if main == null or not is_instance_valid(main) or foe == null or not is_instance_valid(foe):
		return
	if foe.dead or foe.ally or _depth >= int(RULES["depth"]):
		return
	for id in REACTIONS:
		var r: Dictionary = REACTIONS[id]
		var pair: Array = r["states"]
		if not state in pair or pair.size() < 2:
			continue
		var other: String = pair[1] if pair[0] == state else pair[0]
		if other == state or not has(foe, other):
			continue
		if _cooling(foe, id, r):
			continue
		_fire(main, foe, id)
		if not is_instance_valid(foe) or foe.dead:
			return


static func _cooling(foe, id: String, r: Dictionary) -> bool:
	var again := float(r.get("again", 0.0))
	if again <= 0.0:
		return false
	var at := int(foe.reacted.get(id, -999999))
	return Time.get_ticks_msec() - at < int(again * 1000.0)


## More damage as your marks grow: per_step for each step of the strongest past the first.
static func scale(main) -> float:
	var best := 1
	if main != null and main.player != null:
		for b in main.player.bonds.values():
			if b != null and "step" in b:
				best = maxi(best, int(b.step))
	return 1.0 + float(RULES["per_step"]) * float(best - 1)


static func _fire(main, foe, id: String) -> void:
	var r: Dictionary = REACTIONS[id]
	foe.reacted[id] = Time.get_ticks_msec()
	var source = _sources.back() if not _sources.is_empty() else null
	var at: Vector2 = foe.global_position
	var col: Color = r["color"]
	var held_before := held(foe)
	_depth += 1
	for s in r.get("consume", []):
		clear(foe, String(s))
	var k := scale(main)
	match id:
		"conduct":
			_conduct(main, foe, r, k)
		"steam":
			_steam(main, at, r)
		"fumes":
			_fumes(main, foe, r, k)
		"crater":
			_crater(main, foe, r, k)
		"skybolt":
			_skybolt(main, foe, r, k)
		"hemorrhage":
			main.fx_burst(at, Vector2.UP, col, 14, 200.0)
		"smoulder":
			if is_instance_valid(foe) and foe.burn_t > 0.0:
				foe.burn_t = foe.burn_t * float(r["mult"])
			main.fx_burst(at, Vector2.UP, col, 10, 120.0)
		"ambush":
			if is_instance_valid(foe) and not foe.dead:
				foe.add_venom(int(r["stacks"]))
			main.fx_burst(at, Vector2.ZERO, col, 14, 180.0)
	# (a reaction firing again and again on one foe, as a channelled drain does,
	# shows its word and sound once in a while)
	var now := Time.get_ticks_msec()
	if now - int(foe.reacted.get("shown:" + id, -999999)) > 700:
		foe.reacted["shown:" + id] = now
		word(main, at + Vector2(0, -float(foe.radius) - 30.0), String(r["name"]), col)
		main.sfx(String(r["sound"]), float(r.get("pitch", 1.0)), -2.0)
		main.light_flash(at, col, 1.2, 1.4, 0.3)
	FIRED[id] = int(FIRED.get(id, 0)) + 1
	if not _sources.is_empty():
		_log.append(id)
	_depth -= 1
	if main.has_method("tip"):
		main.tip("reactions")
	var info := {"id": id, "foe": foe, "at": at, "source": source, "states": held_before}
	if is_instance_valid(foe) and foe.has_signal("on_reaction"):
		foe.on_reaction.emit(foe, id, source)
	if main.has_signal("on_reaction"):
		main.on_reaction.emit(foe, id, source)
	load("res://scripts/library.gd").on_reaction(main.player, info)


static func _alive(e) -> bool:
	return e != null and is_instance_valid(e) and not e.dead


## Conduct: lightning leaps from the foe to every soaked foe within reach
## (and the foe itself): each is struck, stunned, and dries off.
static func _conduct(main, foe, r: Dictionary, k: float) -> void:
	var at: Vector2 = foe.global_position
	var struck: Array = [foe]
	for o in main.targets():
		if o != foe and not o.dead and has(o, "soaked") and o.global_position.distance_to(at) <= float(r["radius"]) + o.radius:
			struck.append(o)
	for o in struck:
		if not _alive(o):
			continue
		if o != foe:
			clear(o, "soaked")
			main.fx_bolt([at, o.global_position], r["color"])
			_arc(main, at, o.global_position, r["color"], 0.4)
		main.fx_ring(o.global_position, r["color"], o.radius + 14.0, 0.3, 2.0)
		o.stagger(float(r["stun"]) * (0.5 if o.is_boss() else 1.0))
		o.take_hit(float(r["damage"]) * k, Vector2.ZERO, 0.0)
	main.fx_ring(at, r["color"], float(r["radius"]), 0.35, 2.0)
	main.hitstop(0.05)


## Steam: a cloud where it stood; foes inside lose track of you while it lasts.
static func _steam(main, at: Vector2, r: Dictionary) -> void:
	var rad := float(r["radius"])
	var secs := float(r["seconds"])
	var lose := float(r["lose"])
	var col: Color = r["color"]
	SpellFx.field(main, at, rad, secs, 0.3, col, func(foes: Array):
		for o in foes:
			if _alive(o):
				o.lose_track(lose, null))
	var seeds: Array = []
	for i in 9:
		seeds.append([Vector2.from_angle(randf() * TAU) * randf() * rad * 0.7, randf_range(0.45, 0.8), randf() * TAU])
	SpellFx.lasting(main, secs, Callable(), func(n):
		var a: float = n.fade(0.8)
		for s in seeds:
			var off: Vector2 = s[0] + Vector2(sin(n.age * 0.7 + s[2]) * 6.0, -n.age * 5.0)
			var pr: float = rad * float(s[1]) * (0.7 + 0.3 * minf(n.age / 0.5, 1.0))
			n.draw_circle(at + off, pr, Color(col, 0.1 * a))
			n.draw_circle(at + off + Vector2(-pr * 0.2, -pr * 0.25), pr * 0.6, Color(1, 1, 1, 0.07 * a))
		n.draw_arc(at, rad, 0.0, TAU, 40, Color(col, 0.25 * a), 1.5, true))
	main.fx_burst(at, Vector2.UP, col, 16, 160.0)


## Fumes: the poison spreads to its neighbours as burning gas: each gets a
## share of its stacks and is set burning.
static func _fumes(main, foe, r: Dictionary, k: float) -> void:
	var at: Vector2 = foe.global_position
	var stacks := maxi(1, int(ceil(float(foe.venom) * float(r["share"]))))
	var col: Color = r["color"]
	var near: Array = []
	for o in main.targets():
		if o != foe and not o.dead and o.global_position.distance_to(at) <= float(r["radius"]) + o.radius:
			near.append(o)
	var seeds: Array = []
	for i in 7:
		seeds.append([Vector2.from_angle(TAU * i / 7.0 + randf() * 0.5), randf_range(0.5, 1.0)])
	var rad := float(r["radius"])
	SpellFx.lasting(main, 1.2, Callable(), func(n):
		var a: float = n.fade(0.6)
		var kk: float = clampf(n.age / 0.6, 0.0, 1.0)
		for s in seeds:
			var p: Vector2 = at + s[0] * rad * kk * float(s[1])
			n.draw_circle(p, 10.0 + 8.0 * kk, Color(0.55, 0.8, 0.3, 0.22 * a))
			n.draw_circle(p + Vector2(0, -4), 5.0 + 4.0 * kk, Color(1.0, 0.6, 0.2, 0.25 * a)))
	for o in near:
		if not _alive(o):
			continue
		main.fx_burst(at, (o.global_position - at).normalized(), col, 6, 220.0)
		o.add_venom(stacks)
		if _alive(o):
			o.ignite(float(r["burn"]) * k, float(r["burn_t"]))


## Crater: slammed down out of the air: a big hit, and the foes around it
## are struck and knocked down.
static func _crater(main, foe, r: Dictionary, k: float) -> void:
	var at: Vector2 = foe.global_position
	var col: Color = r["color"]
	var rad := float(r["radius"])
	for o in main.targets():
		if o == foe or o.dead or o.global_position.distance_to(at) > rad + o.radius:
			continue
		var dir: Vector2 = (o.global_position - at).normalized() if o.global_position.distance_to(at) > 1.0 else Vector2.RIGHT
		o.take_hit(float(r["splash"]) * k, dir, 200.0, true)
		if _alive(o):
			o.stagger(float(r["down"]) * (0.5 if o.is_boss() else 1.0))
	if _alive(foe):
		foe.take_hit(float(r["damage"]) * k, Vector2.ZERO, 0.0, true)
	main.fx_ring(at, col, rad, 0.4, 7.0)
	main.fx_ring(at, Color(1, 1, 1, 0.7), rad * 0.5, 0.3, 3.0)
	main.fx_burst(at, Vector2.ZERO, col, 26, 300.0)
	SpellFx.lasting(main, 1.6, Callable(), func(n):
		var a: float = n.fade(0.8)
		n.draw_circle(at, rad * 0.45, Color(0.12, 0.09, 0.07, 0.45 * a))
		for i in 8:
			var d := Vector2.from_angle(TAU * i / 8.0 + 0.3)
			n.draw_line(at + d * rad * 0.3, at + d * rad * (0.6 + 0.1 * (i % 3)), Color(0.12, 0.09, 0.07, 0.6 * a), 2.0, true), {}, {"z": 11})
	main.shake(8.0)
	main.hitstop(0.08)


## Skybolt: a bolt out of the sky strikes it as it falls.
static func _skybolt(main, foe, r: Dictionary, k: float) -> void:
	var at: Vector2 = foe.global_position
	main.fx_bolt([at + Vector2(randf_range(-30, 30), -280.0), at + Vector2(randf_range(-12, 12), -140.0), at], r["color"])
	_arc(main, at + Vector2(randf_range(-20, 20), -300.0), at, r["color"], 0.45, 4.0)
	main.fx_ring(at, r["color"], 50.0, 0.3, 4.0)
	main.fx_burst(at, Vector2.ZERO, r["color"], 18, 260.0)
	if _alive(foe):
		foe.stagger(float(r["stun"]) * (0.5 if foe.is_boss() else 1.0))
		foe.take_hit(float(r["damage"]) * k, Vector2.ZERO, 0.0, true)
	main.shake(6.0)
	main.hitstop(0.06)


## A jagged arc of lightning from a to b that flickers for `secs` (Conduct, Skybolt).
static func _arc(main, a: Vector2, b: Vector2, col: Color, secs: float, width := 2.5) -> void:
	var pts := PackedVector2Array([a])
	var n := maxi(3, int(a.distance_to(b) / 28.0))
	var side := (b - a).orthogonal().normalized()
	for i in range(1, n):
		pts.append(a.lerp(b, float(i) / n) + side * randf_range(-10.0, 10.0))
	pts.append(b)
	SpellFx.lasting(main, secs, Callable(), func(nd):
		var k: float = nd.fade(secs * 0.6) * (0.6 + 0.4 * absf(sin(nd.age * 40.0)))
		nd.draw_polyline(pts, Color(col, 0.35 * k), width * 3.0, true)
		nd.draw_polyline(pts, Color(col.lightened(0.4), 0.95 * k), width, true)
		nd.draw_circle(b, 6.0 + width, Color(col.lightened(0.5), 0.5 * k)), {}, {"z": 50, "fade_in": false})


## The word that rises over a reaction: large, in its colour, outlined.
static func word(main, at: Vector2, text: String, col: Color) -> void:
	var size := int(RULES["word"])
	SpellFx.lasting(main, float(RULES["word_time"]), Callable(), func(n):
		var a: float = n.fade(0.4)
		var f: Font = UI.font("display")
		var pos: Vector2 = at + Vector2(-80.0, -18.0 * minf(n.age / 0.5, 1.0) - n.age * 6.0)
		var pop: int = size + int(4.0 * maxf(0.0, 1.0 - n.age / 0.15))
		n.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 160.0, pop, 4, Color(0.05, 0.03, 0.03, 0.85 * a))
		n.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_CENTER, 160.0, pop, Color(col.lightened(0.15), a)), {}, {"z": 60})


# --- the climber (off unless CLIMBER "enabled") -----------------------------------

## A monster's blow reaching the climber may leave its state (player.gd receive_attack).
static func from_monster(main, p, source) -> void:
	if not bool(CLIMBER["enabled"]) or source == null or not is_instance_valid(source) or not ("kind" in source):
		return
	var st := String(CLIMBER["from"].get(String(source.kind), ""))
	if st != "":
		apply(main, p, st, float(CLIMBER["seconds"]), source)


static func _apply_climber(main, p, state: String, seconds: float, source) -> Array:
	if not bool(CLIMBER["enabled"]) or p.dead or bool(STATES[state].get("event", false)):
		return []
	var secs := seconds if seconds > 0.0 else float(STATES[state].get("seconds", 2.0))
	var was := float(p.states.get(state, 0.0))
	p.states[state] = maxf(was, secs)
	if state == "poisoned" and p.has_method("poison"):
		p.poison(secs)
	var out: Array = []
	for id in REACTIONS:
		var pair: Array = REACTIONS[id]["states"]
		if not state in pair:
			continue
		var other: String = pair[1] if pair[0] == state else pair[0]
		if other == state or float(p.states.get(other, 0.0)) <= 0.0:
			continue
		for s in REACTIONS[id].get("consume", []):
			p.states.erase(String(s))
		p.hp = maxf(1.0, p.hp - float(CLIMBER["damage"]))
		word(main, p.global_position + Vector2(0, -60), String(REACTIONS[id]["name"]), REACTIONS[id]["color"])
		main.sfx(String(REACTIONS[id]["sound"]), float(REACTIONS[id].get("pitch", 1.0)), -4.0)
		FIRED[id] = int(FIRED.get(id, 0)) + 1
		out.append(id)
	return out


## The climber's states run down; burning and bleeding hurt (only while enabled).
static func tick_climber(p, delta: float) -> void:
	if p.states.is_empty():
		return
	if not bool(CLIMBER["enabled"]):
		p.states.clear()
		return
	var half_before := int(Time.get_ticks_msec() / 500)
	for s in p.states.keys():
		p.states[s] = float(p.states[s]) - delta
		if float(p.states[s]) <= 0.0:
			p.states.erase(s)
	if half_before != int((Time.get_ticks_msec() + int(delta * 1000.0)) / 500):
		if p.states.has("burning"):
			p.hp = maxf(1.0, p.hp - float(CLIMBER["burn"]))
		if p.states.has("bleeding"):
			p.hp = maxf(1.0, p.hp - float(CLIMBER["bleed"]))
