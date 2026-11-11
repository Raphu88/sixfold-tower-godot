extends RefCounted
## The Unbound's new forms, their capstones and the shape of their tree (one
## tree per body part, a node at each part level). The content contract is at
## the top of library.gd; the tree's rules are in tree.gd.
##
## TREE: part -> {level: node}. A node is one of:
##   {"fork": [variation id, variation id]}  choose one, for good (the other
##                                          can be learned later: tree.gd learn_skipped)
##   {"form": form id}                       a new form opens at this level
##   {"capstone": entry}                     the part's capstone (level 10)
## Levels 1 (today's forms), 4 and 8 (one more essence to combine) and 5
## (the gift) are filled in by tree.gd from unbound.gd.
##
## FORMS: new forms, as in library.gd FORMS ("part", "class", "says", their
## numbers, "strain" added to a technique's strain, "opens" = the level).
## Numbers are at full (lead) strength, before the part's level; Air
## stretches each form's reach (technique.gd reach_mult); a variation's Wide
## and Long change the keys technique.gd varied_shape knows (radius, arc,
## width; reach, range, dist, length) and _vary() below does the rest.
## A form centred on you (CENTRED) under Split or Mirrored is cast a step
## away along each copy's aim, so its copies fan out (or one goes behind you).
## Every hit goes through technique.gd hit(), so every essence, chosen effect
## and Chain works on it.
##
## CAPSTONES: each part's level-10 node (TREE[part][10]["capstone"]): a name,
## one plain line and its numbers. They're on for an Unbound whose part is at
## level 10 (capstone_on) and play out in the climb through this file's node
## (Fx, under main) and its on_cast (library.gd calls it after every cast).
##
## Things that stay a while (beams, rings, trails, signs, pools, cloaks) live
## in Fx (one under main, "UnboundForms"; a new floor clears it), which also
## draws them, in code, over the darkness.
## WORKED EXAMPLE: Volley (the hand, level 3): three small bolts in a fan.

const PATH := "res://scripts/spells/unbound_forms.gd"
const NODE := "UnboundForms"
## Raw essence's colour (unbound_run.gd RAW): the capstones' own touches.
const RAW := Color(0.92, 0.9, 1.0)
## Forms centred on you (see above), and how far a Split or Mirrored copy is cast.
const CENTRED := ["wake", "hum", "heartbeat", "wellspring"]
const CENTRED_STEP := 64.0

static var TREE := {
	"hand": {2: {"fork": ["split", "quick"]}, 3: {"form": "volley"}, 6: {"fork": ["chain", "long"]}, 7: {"form": "brand"}, 9: {"fork": ["echo", "charged"]},
		10: {"capstone": {"id": "raw_hands", "name": "Raw Hands", "says": "Every hand technique also throws raw bolts at up to three foes near you, five while the hand runs hot",
			"bolts": 3, "hot_bolts": 5, "damage": 7.0, "range": 320.0, "speed": 520.0, "share": 0.5}}},
	"legs": {2: {"fork": ["long", "quick"]}, 3: {"form": "stride"}, 6: {"fork": ["lingering", "mirrored"]}, 7: {"form": "vault"}, 9: {"fork": ["echo", "wide"]},
		10: {"capstone": {"id": "afterimage", "name": "Afterimage", "says": "Every legs technique leaves an afterimage where you stood that bursts a moment later, harder the hotter your legs run",
			"delay": 0.45, "radius": 72.0, "damage": 14.0, "share": 0.6, "hot": 1.0}}},
	"heart": {2: {"fork": ["quick", "lingering"]}, 3: {"form": "heartbeat"}, 6: {"fork": ["echo", "wide"]}, 7: {"form": "wellspring"}, 9: {"fork": ["charged", "delayed"]},
		10: {"capstone": {"id": "second_heart", "name": "Second Heart", "says": "Once a floor, when you fall below a third of your health, a second heart beats: 40% of your health back and every part's strain gone",
			"below": 0.34, "heal": 0.4}}},
	"brow": {2: {"fork": ["chain", "quick"]}, 3: {"form": "glare"}, 6: {"fork": ["long", "delayed"]}, 7: {"form": "omen"}, 9: {"fork": ["split", "charged"]},
		10: {"capstone": {"id": "piercing_gaze", "name": "Piercing Gaze", "says": "Every brow technique also marks every foe near you for 4 seconds (6 while the brow runs hot): they take 50% more damage",
			"range": 300.0, "duration": 4.0, "hot_duration": 6.0}}},
	"throat": {2: {"fork": ["wide", "long"]}, 3: {"form": "hum"}, 6: {"fork": ["chain", "delayed"]}, 7: {"form": "call"}, 9: {"fork": ["echo", "split"]},
		10: {"capstone": {"id": "rallying_cry", "name": "Rallying Cry", "says": "Every throat technique fills your other techniques by a quarter, cools their parts by 10 strain and gives you back your stamina",
			"fill": 0.25, "cool": 10.0}}},
	"back": {2: {"fork": ["wide", "lingering"]}, 3: {"form": "wake"}, 6: {"fork": ["delayed", "charged"]}, 7: {"form": "mantle"}, 9: {"fork": ["echo", "mirrored"]},
		10: {"capstone": {"id": "unbowed", "name": "Unbowed", "says": "Every back technique also raises a light shell, and while any shell holds you, every part's strain fades, even as you cast",
			"shield": 14.0, "duration": 3.0, "fade": 12.0}}},
}

## Level 3 forms add 2 strain, level 7 forms 4 (their price: the owner may change it).
static var FORMS := {
	"volley": {"name": "Volley", "part": "hand", "class": "hit", "says": "Three small bolts thrown in a fan", "damage": 7.0, "speed": 440.0, "range": 300.0,
		"count": 3, "spread": 16.0, "strain": 2.0, "opens": 3, "levels": {}},
	"brand": {"name": "Brand", "part": "hand", "class": "hit", "says": "A touch that sets a burst on a foe a moment later", "touch": 4.0, "damage": 22.0, "reach": 60.0, "arc": 55.0,
		"delay": 0.8, "radius": 60.0, "strain": 4.0, "opens": 7, "levels": {}},
	"stride": {"name": "Stride", "part": "legs", "class": "move", "says": "For a few seconds you leave a trail that carries the effect", "damage": 4.0, "duration": 3.0, "radius": 20.0,
		"life": 1.6, "tick": 0.5, "strain": 2.0, "opens": 3, "levels": {}},
	"vault": {"name": "Vault", "part": "legs", "class": "move", "says": "A hop back away from a foe, with a burst where you stood", "damage": 16.0, "dist": 110.0, "radius": 64.0,
		"strain": 4.0, "opens": 7, "levels": {}},
	"wake": {"name": "Wake", "part": "back", "class": "hit", "says": "A slow ring that rolls outward from you", "damage": 12.0, "radius": 170.0, "speed": 150.0, "force": 200.0,
		"strain": 2.0, "opens": 3, "levels": {}},
	"mantle": {"name": "Mantle", "part": "back", "class": "shell", "says": "A cloak that answers the next blow you take", "shield": 16.0, "duration": 8.0, "damage": 20.0, "radius": 90.0,
		"strain": 4.0, "opens": 7, "levels": {}},
	"hum": {"name": "Hum", "part": "throat", "class": "hit", "says": "A field around you that pulses three times", "damage": 6.0, "radius": 95.0, "pulses": 3, "tick": 0.5,
		"strain": 2.0, "opens": 3, "levels": {}},
	"call": {"name": "Call", "part": "throat", "class": "hit", "says": "A burst at a spot you aim at, far away", "damage": 18.0, "range": 280.0, "radius": 70.0, "travel": 0.22,
		"strain": 4.0, "opens": 7, "levels": {}},
	"glare": {"name": "Glare", "part": "brow", "class": "hit", "says": "A narrow beam you hold for a second", "damage": 3.5, "length": 300.0, "width": 16.0, "duration": 1.0, "tick": 0.2,
		"strain": 2.0, "opens": 3, "levels": {}},
	"omen": {"name": "Omen", "part": "brow", "class": "hit", "says": "A sign on the floor that bursts when a foe steps on it", "damage": 28.0, "range": 90.0, "trigger": 26.0, "radius": 80.0,
		"duration": 10.0, "strain": 4.0, "opens": 7, "levels": {}},
	"heartbeat": {"name": "Heartbeat", "part": "heart", "class": "hit", "says": "The effect beats out around you every second for a while", "damage": 4.5, "radius": 90.0, "beats": 4, "tick": 1.0,
		"strain": 2.0, "opens": 3, "levels": {}},
	"wellspring": {"name": "Wellspring", "part": "heart", "class": "self", "says": "A pool on the floor that works on you while you stand in it", "radius": 56.0, "duration": 7.0, "tick": 0.5,
		"hold": 1.5, "strain": 4.0, "opens": 7, "levels": {}},
}

## Words shown over the climber or a foe.
static var TEXT := {
	"branded": "Branded",
	"answer": "Answered",
	"omen": "Omen",
	"second_heart": "Second Heart",
	"rally": "Rally",
	"gaze": "Marked",
}

static var _hooked := false


## Watches for the climb's Unbound node (unbound_run.gd), so this file's node
## is under every game (the capstones need it even before a form is cast).
static func _static_init() -> void:
	if Engine.is_editor_hint() or _hooked:
		return
	var tree = Engine.get_main_loop()
	if tree is SceneTree:
		_hooked = true
		tree.node_added.connect(func(n): _on_node_added(n))


static func _on_node_added(n: Node) -> void:
	var s = n.get_script()
	if s != null and s.resource_path == "res://scripts/unbound_run.gd":
		var m = n.get_parent()
		if m != null:
			(func(): of(m)).call_deferred()


## This file's node under main (made the first time it's needed).
static func of(main):
	if main == null or not is_instance_valid(main) or not main.is_inside_tree():
		return null
	var n = main.get_node_or_null(NODE)
	if n == null:
		n = Fx.new()
		n.name = NODE
		n.main = main
		n.src = load(PATH)
		main.add_child(n)
	return n


## True once a part's capstone is the climber's: Unbound, the part at level 10.
static func capstone_on(prof, part: String) -> bool:
	var U = load("res://scripts/unbound.gd")
	var L = load("res://scripts/library.gd")
	if prof == null or not U.is_on(prof):
		return false
	return L.built(capstone(part)) and U.level(prof, part) >= U.LEVELS.size()


static func capstone(part: String) -> Dictionary:
	var node = TREE.get(part, {}).get(10, {})
	return node.get("capstone", {}) if node is Dictionary else {}


static func _tech():
	return load("res://scripts/technique.gd")


## The technique's variation ("" for none).
static func _vid(t: Dictionary) -> String:
	var vs: Array = _tech().variations(t)
	return String(vs[0]) if not vs.is_empty() else ""


## Numbers a variation changes that technique.gd varied_shape doesn't know:
## Long stretches a form's time or ring, Wide is already done there.
static func _vary(id: String, t: Dictionary, sh: Dictionary) -> Dictionary:
	var out := sh.duplicate()
	if _vid(t) == "long":
		var k := float(load("res://scripts/library.gd").variation("long").get("reach", 1.4))
		match id:
			"stride", "mantle", "wellspring":
				out["duration"] = float(out["duration"]) * k
			"wake", "hum", "heartbeat":
				out["radius"] = float(out["radius"]) * k
	return out


## Weights without the one-off keys (a Chain stays only where asked).
static func _scaled(w: Dictionary, k: float, keep_chain := false) -> Dictionary:
	var out := {}
	for key in w:
		if String(key).begins_with("_"):
			if key != "_chain" or keep_chain:
				out[key] = w[key]
		else:
			out[key] = float(w[key]) * k
	return out


## Damage without the essences' effects (a held beam's in-between ticks).
static func _graze(p, e, dmg: float, dir: Vector2, w: Dictionary) -> void:
	if e == null or not is_instance_valid(e) or e.dead or dmg <= 0.0:
		return
	var pierce: bool = w.has("iron") or w.has("unmaking")
	e.take_hit(dmg * float(p.flow_damage), dir, 40.0, false, pierce)


static func _foes_near(main, at: Vector2, r: float) -> Array:
	var out: Array = []
	for e in main.targets():
		if not e.dead and e.global_position.distance_to(at) <= r + e.radius:
			out.append(e)
	return out


## Strikes every foe within r of `at` (outward); returns how many.
static func _burst(p, at: Vector2, r: float, dmg: float, w: Dictionary, power: float, run, col: Color) -> int:
	var main = p.main
	var Tech = _tech()
	var n := 0
	for e in _foes_near(main, at, r):
		var to: Vector2 = e.global_position - at
		Tech.hit(p, e, dmg, to.normalized() if to.length() > 0.1 else Vector2.RIGHT, w, power, run)
		n += 1
	main.fx_ring(at, col, r, 0.35, 4.0)
	main.fx_burst(at, Vector2.ZERO, col, 14, 220.0)
	main.light_flash(at, col, 1.2, 1.4, 0.3)
	return n


## The last point before a wall on the way from `a` toward `b`.
static func _clear_to(main, a: Vector2, b: Vector2) -> Vector2:
	var steps := int(ceil(a.distance_to(b) / 10.0))
	var last := a
	for i in range(1, steps + 1):
		var q := a.lerp(b, float(i) / float(steps))
		if main.is_solid(q) or not main.room.has_point(q):
			return last
		last = q
	return last


# --- casting -----------------------------------------------------------------------------

## Runs this file's written forms (-1: not one of ours).
static func cast_form(id: String, t: Dictionary, p, power: float, run, sh: Dictionary, w: Dictionary) -> int:
	if not FORMS.has(id):
		return -1
	var Tech = _tech()
	var main = p.main
	var col: Color = Tech.color(Tech.lead(t))
	var reach_k: float = Tech.reach_mult(w)
	sh = _vary(id, t, sh)
	var origin: Vector2 = p.global_position
	var aim: Vector2 = p.aim
	var off := Vector2.ZERO
	if id in CENTRED and _vid(t) in ["split", "mirrored"]:
		off = aim * CENTRED_STEP  # (each copy a step away along its aim)
	var base := {"t": t, "p": p, "run": run, "w": w, "power": power, "col": col, "age": 0.0}
	match id:
		"volley":
			var n := int(sh.get("count", 3))
			var spread := deg_to_rad(float(sh.get("spread", 16.0)))
			for i in n:
				var dir: Vector2 = aim.rotated(spread * (float(i) - float(n - 1) * 0.5))
				run.add_bolt(origin + dir * (p.radius + 6.0), dir * float(sh["speed"]), float(sh["range"]) * reach_k, float(sh["damage"]) * power, w, power, col)
			main.sfx("form_bolt", 1.0, -3.0)
			return 0
		"brand":
			var reach: float = float(sh["reach"]) * reach_k
			var half := deg_to_rad(float(sh["arc"]))
			var best = null
			var best_d := INF
			for e in main.targets():
				var to: Vector2 = e.global_position - origin
				if not e.dead and to.length() <= reach + e.radius and absf(aim.angle_to(to)) <= half and to.length() < best_d:
					best = e
					best_d = to.length()
			var at: Vector2 = best.global_position if best != null else _clear_to(main, origin, origin + aim * reach)
			if best != null:
				_graze(p, best, float(sh["touch"]) * power, aim, w)
				main.fx_text(at + Vector2(0, -best.radius - 24.0), TEXT["branded"], col)
			_add(main, base.merged({"kind": "brand", "e": best, "pos": at, "left": float(sh["delay"]), "total": float(sh["delay"]),
				"r": float(sh["radius"]), "dmg": float(sh["damage"]) * power}))
			main.fx_ring(at, col, 18.0, 0.25, 2.0)
			main.sfx("glint", 1.3, -4.0)
			return 1 if best != null else 0
		"stride":
			var dur: float = float(sh["duration"]) * reach_k  # (Air carries a move farther: here, longer)
			p.haste_t = maxf(p.haste_t, dur)
			_add(main, base.merged({"kind": "trail", "left": dur, "pts": [{"pos": origin, "t": float(sh["life"])}], "r": float(sh["radius"]),
				"life": float(sh["life"]), "every": float(sh["tick"]), "dmg": float(sh["damage"]) * power, "last": {}}))
			main.sfx("gust", 1.4, -5.0)
			return 0
		"vault":
			var dist: float = float(sh["dist"]) * reach_k
			p.jump_total = 0.32
			p.jump_t = 0.32
			p.jump_vel = -aim * dist / 0.32
			p.iframes = maxf(p.iframes, 0.4)
			main.fx_ghost(origin, p.radius, col)
			var hits := _burst(p, origin, float(sh["radius"]), float(sh["damage"]) * power, w, power, run, col)
			main.shake(4.0)
			main.sfx("roll", 1.1, -3.0)
			main.sfx("hit_heavy", 0.7, -4.0)
			return hits
		"wake":
			_add(main, base.merged({"kind": "wake", "off": off, "c": origin + off, "r": 14.0, "max": float(sh["radius"]) * reach_k, "speed": float(sh["speed"]),
				"force": float(sh["force"]) * reach_k, "dmg": float(sh["damage"]) * power, "hit": {}}))
			main.sfx("gust", 0.55, -3.0)
			return 0
		"mantle":
			var shield: float = float(sh["shield"]) * power * (1.0 + float(w.get("stone", 0.0)) + 0.5 * float(w.get("iron", 0.0)) + 0.5 * float(w.get("unmaking", 0.0)))
			var dur: float = float(sh["duration"]) * (1.0 + 0.6 * float(w.get("air", 0.0)))
			p.raise_barrier(shield, dur, false, col)
			_add(main, base.merged({"kind": "mantle", "left": dur, "total": dur, "r": float(sh["radius"]) * reach_k, "dmg": float(sh["damage"]) * power,
				"stored": float(p.barrier_stored), "taken": int(p.hits_taken), "bhp": float(p.barrier_hp), "bt": float(p.barrier_t)}))
			main.sfx("form_shell", 1.0, -3.0)
			return 0
		"hum":
			var pc := base.merged({"kind": "hum", "off": off, "r": float(sh["radius"]) * reach_k, "left": int(sh["pulses"]), "every": float(sh["tick"]), "next": 0.0,
				"dmg": float(sh["damage"]) * power})
			_add(main, pc)
			return _pulse(pc, origin + off)
		"call":
			var reach: float = float(sh["range"]) * reach_k
			var spot: Vector2 = origin + aim * reach
			var best_d := INF
			for e in main.targets():
				var to: Vector2 = e.global_position - origin
				if not e.dead and to.length() <= reach + e.radius and absf(aim.angle_to(to)) < 0.3 and to.length() < best_d:
					best_d = to.length()
					spot = e.global_position
			if not main.room.has_point(spot):
				spot = _clear_to(main, origin, spot)
			_add(main, base.merged({"kind": "call", "from": origin, "to": spot, "left": float(sh["travel"]), "total": float(sh["travel"]), "r": float(sh["radius"]),
				"dmg": float(sh["damage"]) * power}))
			main.sfx("spell_wind", 0.75, -3.0)
			return 0
		"glare":
			_add(main, base.merged({"kind": "glare", "dir": aim, "rot": null, "left": float(sh["duration"]), "total": float(sh["duration"]), "len": float(sh["length"]) * reach_k,
				"width": float(sh["width"]), "every": float(sh["tick"]), "next": 0.0, "n": 0, "dmg": float(sh["damage"]) * power}))
			main.sfx("form_beam", 1.0, -3.0)
			return 0
		"omen":
			var at := _clear_to(main, origin, origin + aim * float(sh["range"]) * reach_k)
			_add(main, base.merged({"kind": "omen", "pos": at, "left": float(sh["duration"]), "total": float(sh["duration"]), "trig": float(sh["trigger"]),
				"r": float(sh["radius"]), "armed": -1.0, "dmg": float(sh["damage"]) * power}))
			main.fx_ring(at, col, float(sh["trigger"]) + 6.0, 0.3, 2.0)
			main.sfx("glint", 0.7, -3.0)
			return 0
		"heartbeat":
			var pc := base.merged({"kind": "beat", "off": off, "r": float(sh["radius"]) * reach_k, "left": int(sh["beats"]), "every": float(sh["tick"]), "next": 0.0,
				"dmg": float(sh["damage"]) * power})
			_add(main, pc)
			return _pulse(pc, origin + off)
		"wellspring":
			_add(main, base.merged({"kind": "well", "pos": origin + off, "left": float(sh["duration"]), "total": float(sh["duration"]),
				"r": float(sh["radius"]), "every": float(sh["tick"]), "next": 0.0, "hold": float(sh["hold"])}))
			main.sfx("spell_life", 0.9, -3.0)
			return 0
	return -1


static func _add(main, pc: Dictionary) -> void:
	var n = of(main)
	if n != null:
		n.pieces.append(pc)
		n.queue_redraw()


## One of Hum's pulses or a Heartbeat's beats, at `at`; returns the foes struck.
static func _pulse(pc: Dictionary, at: Vector2) -> int:
	pc["left"] = int(pc["left"]) - 1
	pc["next"] = float(pc["every"])
	pc["flash"] = 0.0
	var p = pc["p"]
	var main = p.main
	var Tech = _tech()
	var n := 0
	for e in _foes_near(main, at, float(pc["r"])):
		var to: Vector2 = e.global_position - at
		Tech.hit(p, e, float(pc["dmg"]), to.normalized() if to.length() > 0.1 else Vector2.RIGHT, pc["w"], float(pc["power"]), pc["run"])
		n += 1
	var col: Color = pc["col"]
	if pc["kind"] == "beat":
		main.fx_ring(at, col, float(pc["r"]) * 0.7, 0.18, 4.0)
		main.fx_ring(at, col.lightened(0.3), float(pc["r"]), 0.32, 3.0)
		main.sfx("heartbeat", 1.0, -4.0)
	else:
		main.fx_ring(at, col, float(pc["r"]), 0.4, 3.0)
		main.sfx("form_hum", 1.0, -4.0)
	main.light_flash(at, col, 1.0, 0.9, 0.2)
	return n


# --- each frame (Fx calls these) ------------------------------------------------------------

static func _tick(n, delta: float) -> void:
	var main = n.main
	if main == null or not is_instance_valid(main):
		return
	var key := "%s:%s" % [str(main.get("tower")), str(main.get("floor_num"))]
	if key != n.floor_key:
		n.floor_key = key
		n.pieces.clear()
		n.cap = {}
		n.queue_redraw()
	var p = main.player
	if p == null or not is_instance_valid(p):
		return
	var had: bool = not n.pieces.is_empty()
	if p.dead:
		n.pieces.clear()
	for pc in n.pieces.duplicate():
		pc["age"] = float(pc["age"]) + delta
		if not _tick_piece(pc, p, delta):
			n.pieces.erase(pc)
	_capstones(n, p, delta)
	if had or n.drawn or not n.pieces.is_empty() or not n.gaze.is_empty():
		n.queue_redraw()


## A piece's frame: false once it's done.
static func _tick_piece(pc: Dictionary, p, delta: float) -> bool:
	var main = p.main
	var Tech = _tech()
	var col: Color = pc["col"]
	match String(pc["kind"]):
		"brand", "after":
			var e = pc.get("e")
			if e != null and is_instance_valid(e) and not e.dead:
				pc["pos"] = e.global_position
			pc["left"] = float(pc["left"]) - delta
			if float(pc["left"]) <= 0.0:
				_burst(p, pc["pos"], float(pc["r"]), float(pc["dmg"]), pc["w"], float(pc["power"]), pc["run"], col)
				main.shake(4.0)
				main.sfx("hit_heavy", 0.75 if pc["kind"] == "brand" else 1.0, -3.0)
				return false
		"trail":
			pc["left"] = float(pc["left"]) - delta
			var pts: Array = pc["pts"]
			for q in pts:
				q["t"] = float(q["t"]) - delta
			while not pts.is_empty() and float(pts[0]["t"]) <= 0.0:
				pts.pop_front()
			if float(pc["left"]) > 0.0 and (pts.is_empty() or pts[-1]["pos"].distance_to(p.global_position) > 12.0):
				pts.append({"pos": p.global_position, "t": float(pc["life"])})
			var last: Dictionary = pc["last"]
			for id in last.keys():
				last[id] = float(last[id]) - delta
			for e in main.targets():
				if e.dead or float(last.get(e.get_instance_id(), 0.0)) > 0.0:
					continue
				for q in pts:
					if e.global_position.distance_to(q["pos"]) <= float(pc["r"]) + e.radius:
						last[e.get_instance_id()] = float(pc["every"])
						Tech.hit(p, e, float(pc["dmg"]), Vector2.ZERO, pc["w"], float(pc["power"]), pc["run"])
						break
			return float(pc["left"]) > 0.0 or not pts.is_empty()
		"wake":
			pc["r"] = float(pc["r"]) + float(pc["speed"]) * delta
			var c: Vector2 = pc["c"]
			var hit: Dictionary = pc["hit"]
			for e in main.targets():
				if e.dead or hit.has(e.get_instance_id()):
					continue
				var to: Vector2 = e.global_position - c
				if to.length() <= float(pc["r"]) + e.radius:
					hit[e.get_instance_id()] = true
					var dir := to.normalized() if to.length() > 0.1 else Vector2.RIGHT
					e.tide_push(dir * float(pc["force"]))
					Tech.hit(p, e, float(pc["dmg"]), dir, pc["w"], float(pc["power"]), pc["run"])
			return float(pc["r"]) < float(pc["max"])
		"mantle":
			pc["left"] = float(pc["left"]) - delta
			var blow: bool = int(p.hits_taken) > int(pc["taken"]) or float(p.barrier_stored) > float(pc["stored"]) + 0.01 \
				or (float(p.barrier_hp) < float(pc["bhp"]) - 0.01 and float(pc["bt"]) > 0.1)
			if blow:
				_burst(p, p.global_position, float(pc["r"]), float(pc["dmg"]), pc["w"], float(pc["power"]), pc["run"], col)
				for e in _foes_near(main, p.global_position, float(pc["r"])):
					e.tide_push((e.global_position - p.global_position).normalized() * 260.0)
				main.fx_text(p.global_position + Vector2(0, -50), TEXT["answer"], col.lightened(0.3))
				main.sfx("crit", 0.9, -3.0)
				main.shake(5.0)
				return false
			pc["stored"] = float(p.barrier_stored)
			pc["bhp"] = float(p.barrier_hp)
			pc["bt"] = float(p.barrier_t)
			return float(pc["left"]) > 0.0
		"hum", "beat":
			pc["flash"] = float(pc.get("flash", 0.0)) + delta
			if int(pc["left"]) <= 0:
				return float(pc["flash"]) < 0.4
			pc["next"] = float(pc["next"]) - delta
			if float(pc["next"]) <= 0.0:
				_pulse(pc, p.global_position + pc["off"])
		"call":
			pc["left"] = float(pc["left"]) - delta
			if float(pc["left"]) <= 0.0:
				_burst(p, pc["to"], float(pc["r"]), float(pc["dmg"]), pc["w"], float(pc["power"]), pc["run"], col)
				main.sfx("hit_heavy", 1.2, -4.0)
				return false
		"glare":
			if pc["rot"] == null:
				pc["rot"] = p.aim.angle_to(pc["dir"])  # (a Split or Mirrored copy keeps its angle as you turn)
			pc["dir"] = p.aim.rotated(float(pc["rot"]))
			pc["left"] = float(pc["left"]) - delta
			pc["next"] = float(pc["next"]) - delta
			var a: Vector2 = p.global_position + pc["dir"] * (p.radius + 4.0)
			pc["end"] = _clear_to(main, a, a + pc["dir"] * float(pc["len"]))
			if float(pc["next"]) <= 0.0 and float(pc["left"]) > -0.001:
				pc["next"] = float(pc["every"])
				var full: bool = int(pc["n"]) % 3 == 0  # (the essences' effects every third tick; damage on each)
				pc["n"] = int(pc["n"]) + 1
				var b: Vector2 = pc["end"]
				for e in main.targets():
					if e.dead:
						continue
					var cp := Geometry2D.get_closest_point_to_segment(e.global_position, a, b)
					if cp.distance_to(e.global_position) <= float(pc["width"]) * 0.5 + e.radius:
						if full:
							Tech.hit(p, e, float(pc["dmg"]), pc["dir"], pc["w"], float(pc["power"]), pc["run"])
						else:
							_graze(p, e, float(pc["dmg"]), pc["dir"], pc["w"])
						main.fx_burst(cp, -pc["dir"], col, 2, 120.0)
			return float(pc["left"]) > 0.0
		"omen":
			if float(pc["armed"]) < 0.0:
				pc["left"] = float(pc["left"]) - delta
				if not _foes_near(main, pc["pos"], float(pc["trig"])).is_empty():
					pc["armed"] = 0.15
					main.sfx("trap_click", 1.2, -2.0)
				return float(pc["left"]) > 0.0
			pc["armed"] = float(pc["armed"]) - delta
			if float(pc["armed"]) <= 0.0:
				_burst(p, pc["pos"], float(pc["r"]), float(pc["dmg"]), pc["w"], float(pc["power"]), pc["run"], col)
				main.fx_text(pc["pos"] + Vector2(0, -30), TEXT["omen"], col.lightened(0.3))
				main.shake(5.0)
				main.sfx("burn", 0.9, -2.0)
				return false
		"well":
			pc["left"] = float(pc["left"]) - delta
			pc["next"] = float(pc["next"]) - delta
			pc["inside"] = p.global_position.distance_to(pc["pos"]) <= float(pc["r"]) + p.radius * 0.5
			if pc["inside"] and float(pc["next"]) <= 0.0:
				pc["next"] = float(pc["every"])
				_well_tick(pc, p)
			return float(pc["left"]) > 0.0
		"heart_glow":
			pc["left"] = float(pc["left"]) - delta
			return float(pc["left"]) > 0.0
	return true


## Wellspring works on you as Within does, a tick at a time while you stand in it.
static func _well_tick(pc: Dictionary, p) -> void:
	var Tech = _tech()
	var w: Dictionary = pc["w"]
	var power := float(pc["power"])
	var hold := float(pc["hold"])
	var share := float(pc["every"]) / maxf(float(pc["total"]), 0.5) * 1.5  # (all of it while you stay: half again Within's)
	for k in w:
		if String(k).begins_with("_"):
			continue
		var s := float(w[k])
		match String(k):
			"fire":
				p.kindle_dmg = maxf(p.kindle_dmg if p.kindle_t > 0.0 else 0.0, float(Tech.KINDS["fire"]["kindle"]) * power * s)
				p.kindle_t = maxf(p.kindle_t, hold)
			"water":
				Tech._mend(p, float(Tech.KINDS["water"]["mend"]) * power * s * share, float(pc["every"]))
			"air":
				p.haste_t = maxf(p.haste_t, hold)
			"stone":
				p.stone_t = maxf(p.stone_t, hold)
			"iron":
				p.salts_t = maxf(p.salts_t, hold)
			"blade", "unmaking":
				p.edge_t = maxf(p.edge_t, hold)
			"life":
				p.mend_by(float(Tech.KINDS["life"]["self_heal"]) * power * s * share * p.heal_mult())
	p.main.fx_burst(p.global_position, Vector2.UP, pc["col"], 3, 70.0)


# --- the capstones -----------------------------------------------------------------------------

## Each frame: runs the capstones the climber has that aren't about a cast
## (on_cast below answers casts).
static func _capstones(n, p, delta: float) -> void:
	var main = n.main
	var run = main.get("unbound")
	if run == null or not run.on or p.dead:
		n.cap = {}
		n.gaze.clear()
		return
	var prof = main.profile
	var c: Dictionary = n.cap
	if c.is_empty():
		c["heart"] = false
	var gz: Array = n.gaze
	for g in gz.duplicate():
		g["t"] = float(g["t"]) - delta
		if float(g["t"]) <= 0.0 or not is_instance_valid(g["e"]) or g["e"].dead:
			gz.erase(g)
	# Unbowed: while a shell holds you, every part's strain fades.
	if capstone_on(prof, "back") and float(p.barrier_hp) > 0.0:
		var fade := float(capstone("back")["fade"])
		for part in run.strain.keys():
			run.strain[part] = maxf(0.0, float(run.strain[part]) - fade * delta)
	# Second Heart: once a floor, below a third of your health.
	if capstone_on(prof, "heart") and not bool(c["heart"]) and p.hp > 0.0 and p.hp < p.max_health() * float(capstone("heart")["below"]):
		c["heart"] = true
		var cap: Dictionary = capstone("heart")
		var col: Color = _tech().color("iron")
		p.mend_by(p.max_health() * float(cap["heal"]))
		for part in run.strain.keys():
			run.strain[part] = 0.0
		main.fx_text(p.global_position + Vector2(0, -60), TEXT["second_heart"], RAW)
		main.fx_ring(p.global_position, col.lightened(0.3), 60.0, 0.25, 5.0)
		main.fx_ring(p.global_position, RAW, 110.0, 0.5, 3.0)
		main.fx_burst(p.global_position, Vector2.ZERO, RAW, 18, 200.0)
		main.light_flash(p.global_position, RAW, 2.0, 1.8, 0.5)
		main.sfx("heartbeat", 0.9, 0.0)
		n.pieces.append({"kind": "heart_glow", "left": 1.2, "col": col, "age": 0.0})


## Something was just cast (library.gd on_cast): an Unbound's technique from
## a part whose capstone the climber has sets that capstone off.
static func on_cast(p, cast: Dictionary) -> void:
	if String(cast.get("by", "")) != "technique" or p == null or not is_instance_valid(p) or p.dead:
		return
	var main = p.main
	var run = main.get("unbound") if main != null else null
	var part := String(cast.get("part", ""))
	if run == null or not run.on or not capstone_on(main.profile, part):
		return
	var n = of(main)
	if n != null:
		_on_cast(n, p, part, cast.get("bond"), cast.get("at", p.global_position))


## A technique (`b`) was cast from a part whose capstone the climber has;
## `at` is where the climber stood as it began.
static func _on_cast(n, p, part: String, b, at: Vector2) -> void:
	var main = n.main
	var run = main.unbound
	var prof = main.profile
	var Tech = _tech()
	var U = load("res://scripts/unbound.gd")
	var cap := capstone(part)
	var t: Dictionary = b.tech if b != null else {"part": part, "shape": "strike", "kinds": [String(U.PART_KIND[part])]}
	var w: Dictionary = Tech.cast_weights(t)
	var col: Color = Tech.color(Tech.lead(t))
	var power: float = U.power(prof, part)
	var hot: bool = run.strain_of(part) > run.HOT
	match part:
		"hand":
			var foes: Array = _foes_near(main, p.global_position, float(cap["range"]))
			foes.sort_custom(func(a, z): return a.global_position.distance_squared_to(p.global_position) < z.global_position.distance_squared_to(p.global_position))
			var k := int(cap["hot_bolts"] if hot else cap["bolts"])
			var ws := _scaled(w, float(cap["share"]))
			for e in foes.slice(0, k):
				var dir: Vector2 = (e.global_position - p.global_position).normalized()
				run.add_bolt(p.global_position + dir * (p.radius + 6.0), dir * float(cap["speed"]), float(cap["range"]) + 40.0, float(cap["damage"]) * power, ws, power, RAW)
			if not foes.is_empty():
				main.fx_ring(p.global_position, RAW, 26.0, 0.2, 2.0)
				main.sfx("zap", 1.6, -6.0)
		"legs":
			var heat: float = clampf(run.strain_of(part) / run.ERUPT, 0.0, 1.0)
			main.fx_ghost(at, p.radius, RAW)
			n.pieces.append({"kind": "after", "pos": at, "left": float(cap["delay"]), "total": float(cap["delay"]), "r": float(cap["radius"]),
				"dmg": float(cap["damage"]) * power * (1.0 + float(cap["hot"]) * heat), "w": _scaled(w, float(cap["share"])), "power": power,
				"run": run, "col": col.lerp(RAW, 0.5), "t": t, "p": p, "age": 0.0})
		"back":
			if float(p.barrier_hp) <= 0.0:
				p.raise_barrier(float(cap["shield"]) * power, float(cap["duration"]), false, col.lerp(RAW, 0.4))
				main.fx_ring(p.global_position, RAW, 36.0, 0.3, 2.5)
		"throat":
			for o in p.bonds.values():
				if "tech" in o and o != b and o.tech_part() != part:
					o.essence = minf(o.capacity(), float(o.essence) + o.capacity() * float(cap["fill"]))
			for q in run.strain.keys():
				if q != part:
					run.strain[q] = maxf(0.0, float(run.strain[q]) - float(cap["cool"]))
			p.sta = p.max_sta
			run._sync()
			main.fx_text(p.global_position + Vector2(0, -72), TEXT["rally"], col.lightened(0.3))
			main.fx_ring(p.global_position, RAW, 70.0, 0.4, 3.0)
		"brow":
			var dur := float(cap["hot_duration"] if hot else cap["duration"])
			for e in _foes_near(main, p.global_position, float(cap["range"])):
				e.challenged_t = maxf(float(e.challenged_t), dur)
				n.gaze.append({"e": e, "t": dur, "col": col})
				main.fx_ring(e.global_position, RAW, e.radius + 10.0, 0.4, 2.0)
			main.sfx("glint", 0.6, -6.0)


# --- drawing (in code, over the darkness) ------------------------------------------------------

static func _draw_fx(n) -> void:
	var main = n.main
	if main == null or not is_instance_valid(main):
		return
	var p = main.player
	var clock := Time.get_ticks_msec() * 0.001
	n.drawn = not n.pieces.is_empty() or not n.gaze.is_empty()  # (one more redraw once they're gone)
	for pc in n.pieces:
		var col: Color = pc["col"]
		match String(pc["kind"]):
			"brand", "after":
				var k := 1.0 - clampf(float(pc["left"]) / maxf(float(pc["total"]), 0.01), 0.0, 1.0)
				var c: Vector2 = pc["pos"]
				if pc["kind"] == "after":
					# A faint copy of the climber where you stood.
					n.draw_circle(c, 15.0, Color(RAW, 0.3 * (1.0 - k * 0.5)))
					n.draw_circle(c + Vector2(0, -7), 6.5, Color(col.lightened(0.3), 0.55 * (1.0 - k * 0.5)))
					n.draw_arc(c, 15.0, 0.0, TAU, 24, Color(RAW, 0.8 * (1.0 - k * 0.5)), 1.5, true)
				var rr := lerpf(26.0, 10.0, k)
				for i in 3:
					var a0 := clock * 3.0 + float(i) * TAU / 3.0
					n.draw_arc(c, rr, a0, a0 + 1.4, 10, Color(col.lightened(0.3), 0.55 + 0.4 * k), 2.0, true)
					var tick := c + Vector2.from_angle(a0 + 0.7) * (rr + 5.0)
					n.draw_line(tick, tick + Vector2.from_angle(a0 + 0.7) * 5.0, Color(col, 0.8), 1.5, true)
				n.draw_circle(c, 3.0 + 3.0 * k, Color(col.lightened(0.5), 0.5 + 0.5 * k))
				n.draw_arc(c, float(pc["r"]) * k, 0.0, TAU, 32, Color(col, 0.18 * k), 1.0, true)
			"trail":
				var pts: Array = pc["pts"]
				for i in range(1, pts.size()):
					var a := clampf(float(pts[i]["t"]) / float(pc["life"]), 0.0, 1.0)
					n.draw_line(pts[i - 1]["pos"], pts[i]["pos"], Color(col, 0.22 * a), float(pc["r"]) * 1.6, true)
					n.draw_line(pts[i - 1]["pos"], pts[i]["pos"], Color(col.lightened(0.4), 0.6 * a), 2.5, true)
				for i in range(0, pts.size(), 2):
					var a := clampf(float(pts[i]["t"]) / float(pc["life"]), 0.0, 1.0)
					var wob := Vector2(sin(clock * 6.0 + i), cos(clock * 5.0 + i * 1.3)) * float(pc["r"]) * 0.5
					n.draw_circle(pts[i]["pos"] + wob, 1.8, Color(col.lightened(0.5), 0.8 * a))
			"wake":
				var a := clampf(1.0 - float(pc["r"]) / float(pc["max"]), 0.0, 1.0)
				var c: Vector2 = pc["c"]
				var r := float(pc["r"])
				n.draw_arc(c, r, 0.0, TAU, 56, Color(col, 0.25 * a), 10.0, true)
				n.draw_arc(c, r, 0.0, TAU, 56, Color(col.lightened(0.35), 0.8 * a), 2.5, true)
				n.draw_arc(c, maxf(r - 9.0, 1.0), 0.0, TAU, 48, Color(col, 0.3 * a), 1.0, true)
				for i in 12:
					var ang := float(i) * TAU / 12.0 + sin(clock * 2.0 + i) * 0.1
					n.draw_circle(c + Vector2.from_angle(ang) * (r + 3.0), 2.0, Color(col.lightened(0.5), 0.7 * a))
			"mantle":
				if p == null:
					continue
				var k := clampf(float(pc["left"]) / 0.6, 0.0, 1.0) * clampf(float(pc["age"]) / 0.2, 0.0, 1.0)
				var back: float = (-p.aim).angle()
				var c: Vector2 = p.global_position
				# A cloak over your back: a crescent of light whose hem ripples, with folds.
				var spread0 := 1.35
				var cloak := PackedVector2Array()
				for i in 17:
					var f := float(i) / 16.0
					var ang: float = back - spread0 + 2.0 * spread0 * f
					cloak.append(c + Vector2.from_angle(ang) * (34.0 + sin(clock * 7.0 + f * 9.0) * 3.0 * sin(f * PI)))
				for i in 17:
					var f := 1.0 - float(i) / 16.0
					var ang: float = back - spread0 * 0.8 + 1.6 * spread0 * f
					cloak.append(c + Vector2.from_angle(ang) * 22.0)
				n.draw_colored_polygon(cloak, Color(col, 0.28 * k))
				for layer in 3:
					var rr := 24.0 + float(layer) * 4.5
					var spread := 1.2 - float(layer) * 0.12
					var pts := PackedVector2Array()
					for i in 15:
						var f := float(i) / 14.0
						var ang: float = back - spread + 2.0 * spread * f
						var hem := sin(clock * 7.0 + f * 9.0 + layer) * 2.5 * sin(f * PI)
						pts.append(c + Vector2.from_angle(ang) * (rr + hem))
					n.draw_polyline(pts, Color(col.lightened(0.2 + 0.15 * layer), (0.75 - 0.15 * layer) * k), 2.6 - layer * 0.5, true)
				n.draw_circle(c + Vector2.from_angle(back) * 36.0, 2.0 + sin(clock * 9.0), Color(col.lightened(0.6), 0.8 * k))
			"hum":
				if p == null:
					continue
				var c: Vector2 = p.global_position + pc["off"]
				var r := float(pc["r"])
				var fade := 1.0 if int(pc["left"]) > 0 else clampf(1.0 - float(pc.get("flash", 0.0)) / 0.4, 0.0, 1.0)
				n.draw_circle(c, r, Color(col, 0.06 * fade))
				for ring in 3:
					var rr := r * (0.4 + 0.3 * ring) + sin(clock * 8.0 + ring) * 2.0
					var pts := PackedVector2Array()
					for i in 41:
						var ang := float(i) / 40.0 * TAU
						pts.append(c + Vector2.from_angle(ang) * (rr + sin(ang * 8.0 + clock * 10.0 + ring) * 2.5))
					n.draw_polyline(pts, Color(col.lightened(0.25), (0.35 - 0.08 * ring) * fade), 1.5, true)
				var fk := clampf(float(pc.get("flash", 1.0)) / 0.3, 0.0, 1.0)
				n.draw_arc(c, r * (0.3 + 0.7 * fk), 0.0, TAU, 40, Color(col.lightened(0.4), 0.7 * (1.0 - fk)), 3.0, true)
			"beat":
				if p == null:
					continue
				var c: Vector2 = p.global_position + pc["off"]
				var fk := clampf(float(pc.get("flash", 1.0)) / 0.35, 0.0, 1.0)
				var size := 6.0 + 3.0 * (1.0 - fk)
				_draw_heart(n, c + Vector2(0, -34), size, Color(col.lightened(0.3), 0.75 if int(pc["left"]) > 0 else 0.75 * (1.0 - fk)))
				n.draw_arc(c, float(pc["r"]), 0.0, TAU, 44, Color(col, 0.12 * (1.0 - fk * 0.5)), 1.0, true)
			"call":
				var k := 1.0 - clampf(float(pc["left"]) / maxf(float(pc["total"]), 0.01), 0.0, 1.0)
				var a: Vector2 = pc["from"]
				var b: Vector2 = pc["to"]
				var dir := (b - a).normalized()
				# Sound flying out: chevrons of voice along the way, a ring tightening on the spot.
				for i in 4:
					var f := clampf(k - float(i) * 0.12, 0.0, 1.0)
					if f <= 0.0:
						continue
					var q := a.lerp(b, f)
					var half := 10.0 + 8.0 * f
					n.draw_arc(q, half, dir.angle() - 0.8, dir.angle() + 0.8, 10, Color(col.lightened(0.3), 0.8 - 0.18 * i), 2.0, true)
				n.draw_arc(b, lerpf(float(pc["r"]), 10.0, k), 0.0, TAU, 36, Color(col, 0.4 + 0.5 * k), 2.0, true)
				n.draw_circle(b, 3.0, Color(col.lightened(0.5), 0.8))
			"glare":
				if p == null or not pc.has("end"):
					continue
				var a: Vector2 = p.global_position + pc["dir"] * (p.radius + 4.0)
				var b: Vector2 = pc["end"]
				var k := clampf(float(pc["left"]) / 0.15, 0.0, 1.0) * clampf(float(pc["age"]) / 0.08, 0.0, 1.0)
				var flick := 0.85 + 0.15 * sin(clock * 50.0)
				n.draw_line(a, b, Color(col, 0.22 * k * flick), float(pc["width"]) * 1.4, true)
				n.draw_line(a, b, Color(col.lightened(0.3), 0.55 * k), float(pc["width"]) * 0.5, true)
				n.draw_line(a, b, Color(1, 1, 1, 0.85 * k * flick), 2.0, true)
				n.draw_circle(a, float(pc["width"]) * 0.5, Color(col.lightened(0.5), 0.7 * k))
				n.draw_circle(b, float(pc["width"]) * 0.6, Color(col.lightened(0.2), 0.5 * k * flick))
			"omen":
				var c: Vector2 = pc["pos"]
				var armed := float(pc["armed"]) >= 0.0
				var fade := clampf(float(pc["left"]) / 0.6, 0.0, 1.0) * clampf(float(pc["age"]) / 0.3, 0.0, 1.0)
				var a := (1.0 if armed else 0.55 + 0.2 * sin(clock * 3.0)) * fade
				var r := float(pc["trig"]) + 4.0
				var ccol := col.lightened(0.5) if armed else col
				n.draw_circle(c, r, Color(col, 0.08 * fade))
				n.draw_arc(c, r, 0.0, TAU, 36, Color(ccol, 0.8 * a), 1.8, true)
				n.draw_arc(c, r * 0.62, 0.0, TAU, 28, Color(ccol, 0.5 * a), 1.0, true)
				var tri := PackedVector2Array()
				for i in 4:
					tri.append(c + Vector2.from_angle(clock * 0.6 + float(i % 3) * TAU / 3.0 - PI / 2.0) * r * 0.8)
				n.draw_polyline(tri, Color(ccol, 0.7 * a), 1.5, true)
				for i in 6:
					var ang := float(i) * TAU / 6.0 - clock * 0.4
					n.draw_line(c + Vector2.from_angle(ang) * (r + 2.0), c + Vector2.from_angle(ang) * (r + 6.0), Color(ccol, 0.7 * a), 1.5, true)
				n.draw_circle(c, 2.5, Color(ccol, a))
			"well":
				var c: Vector2 = pc["pos"]
				var r := float(pc["r"])
				var fade := clampf(float(pc["left"]) / 0.6, 0.0, 1.0) * clampf(float(pc["age"]) / 0.3, 0.0, 1.0)
				var lit := 1.4 if pc.get("inside", false) else 1.0
				n.draw_circle(c, r, Color(col.darkened(0.2), 0.2 * fade * lit))
				n.draw_circle(c, r * 0.7, Color(col, 0.12 * fade * lit))
				n.draw_arc(c, r, 0.0, TAU, 40, Color(col.lightened(0.3), 0.6 * fade), 2.0, true)
				for i in 3:
					var f := fmod(clock * 0.6 + float(i) / 3.0, 1.0)
					n.draw_arc(c, r * f, 0.0, TAU, 32, Color(col.lightened(0.5), 0.4 * (1.0 - f) * fade), 1.2, true)
				for i in 6:
					var f := fmod(clock * 0.8 + float(i) * 0.37, 1.0)
					var at := c + Vector2.from_angle(float(i) * 2.4) * r * 0.6 * fmod(float(i) * 0.53, 1.0) + Vector2(0, -16.0 * f)
					n.draw_circle(at, 1.6, Color(col.lightened(0.6), 0.8 * (1.0 - f) * fade))
			"heart_glow":
				if p == null:
					continue
				var k := clampf(float(pc["left"]) / 1.2, 0.0, 1.0)
				_draw_heart(n, p.global_position + Vector2(0, -34), 9.0 + 4.0 * (1.0 - k), Color(RAW, k))
				_draw_heart(n, p.global_position + Vector2(0, -34), 5.0 + 3.0 * (1.0 - k), Color(col.lightened(0.3), k))
	# Piercing Gaze: an eye over each foe it marked.
	for g in n.gaze:
		if not is_instance_valid(g["e"]):
			continue
		var e = g["e"]
		var at: Vector2 = e.global_position + Vector2(0, -e.radius - 14.0)
		var a := clampf(float(g["t"]) / 0.5, 0.0, 1.0)
		var top := PackedVector2Array()
		var bot := PackedVector2Array()
		for i in 9:
			var f := float(i) / 8.0
			top.append(at + Vector2(lerpf(-7.0, 7.0, f), -sin(f * PI) * 4.0))
			bot.append(at + Vector2(lerpf(-7.0, 7.0, f), sin(f * PI) * 4.0))
		n.draw_polyline(top, Color(RAW, 0.85 * a), 1.4, true)
		n.draw_polyline(bot, Color(RAW, 0.85 * a), 1.4, true)
		n.draw_circle(at, 2.2, Color(g["col"].lightened(0.3), a))


## A small heart (two lobes and a point), centred on c.
static func _draw_heart(n, c: Vector2, s: float, col: Color) -> void:
	n.draw_circle(c + Vector2(-s * 0.48, -s * 0.2), s * 0.55, col)
	n.draw_circle(c + Vector2(s * 0.48, -s * 0.2), s * 0.55, col)
	n.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 1.0, 0.0), c + Vector2(s * 1.0, 0.0), c + Vector2(0, s * 1.05)]), col)


## The node that keeps this file's forms and capstones going (one under main).
class Fx extends Node2D:
	var main
	var src: Script
	var pieces: Array = []
	var gaze: Array = []  # Piercing Gaze's marked foes: {e, t, col}
	var cap := {}  # the capstones' state this floor: {heart}
	var floor_key := ""
	var drawn := false  # something was drawn last time

	func _ready() -> void:
		z_as_relative = false
		z_index = 46  # (over the darkness, like the techniques' bolts)

	func _process(delta: float) -> void:
		if src != null:
			src._tick(self, delta)

	func _draw() -> void:
		if src != null:
			src._draw_fx(self)
