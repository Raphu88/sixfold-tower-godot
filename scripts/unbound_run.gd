extends Node2D
## The Unbound in a climb (main.gd owns one: `main.unbound`): strain and
## eruptions, the techniques' bolts, landings and bleeds, punching through
## the tower's barriers, and the choices the beasts offer (the refusal at
## the Regard, condensing at a summit). Words and numbers are
## here and in unbound.gd / technique.gd.
##
## FILL: each technique fills from its body part's actions (part_action, from
##   player.gd _part_action), like a mark's bond; full, it casts without
##   spending anything (technique.gd CHARGE); cast early and the missing
##   share adds strain. BOOST: carried essence of its kinds is spent on a
##   cast for more power (automatic; the techniques page can switch it off).
## STRAIN: each cast strains the technique's body part. Above HOT its
##   techniques hit HOT_POWER harder but may waver (WAVER: half strength,
##   off aim); at ERUPT the part erupts: you lose ERUPT_HURT of your health
##   (it can kill), the part goes dark for DARK_TIME (nothing from it can be
##   cast) and raw essence shows there. Strain fades while you don't cast
##   from the part (STRAIN_REST, then STRAIN_FADE a second), and the stair's
##   rest clears it.
## BARRIERS: a warded stair, a vault's seal, a lock-in room's shut doorway
##   and the Proving's sealed reliquary. Hold a strike against one with bare
##   fists (FISTS hold): each blow drains unbanked essence, hurts your hands
##   and cracks it; BLOWS of them break it, skipping its challenge and
##   forfeiting its reward. The very first blow ever only makes it shudder
##   (the warning). Only on the bondless first climb do bare fists break a
##   barrier, and breaking one breaks the tower's rules: at the Regard the
##   beast refuses to mark you (broke_rules). After the first climb a
##   marked climber's fists only make a barrier shudder. Once Unbound: raw
##   essence from a step away (any melee weapon or fists), costing essence,
##   not health, and cracking it faster.

const Unbound := preload("res://scripts/unbound.gd")
const Tech := preload("res://scripts/technique.gd")
const TechBond := preload("res://scripts/technique_bond.gd")
const TreeRules := preload("res://scripts/tree.gd")
const Library := preload("res://scripts/library.gd")
const Secret := preload("res://scripts/secret.gd")
const Draw := preload("res://scripts/draw_util.gd")
const Palette := preload("res://scripts/palette.gd")
const UI := preload("res://scripts/ui.gd")

const HOT := 70.0
const ERUPT := 100.0
const HOT_POWER := 1.25
const WAVER := 0.35
const WAVER_POWER := 0.5
const STRAIN_REST := 1.5
const STRAIN_FADE := 9.0
const DARK_TIME := 8.0
const ERUPT_HURT := 0.45
const ERUPT_LEFT := 50.0
## Fists: hold the strike this long for a blow; reach from your edge;
## each blow drains this much unbanked essence and costs this much health
## (twice that with almost nothing to drain; never the last of it). Raw
## essence (the Unbound): this reach, this much essence a blow, this many cracks a blow.
const FISTS := {"hold": 0.45, "reach": 26.0, "drain": 4.0, "hurt": 5.0, "raw_reach": 90.0, "raw_cost": 6.0, "raw_blows": 2}
const BLOWS := {"stair": 4, "vault": 4, "gate": 3, "proving": 5}
## Seconds a refusal ignores presses after it opens (it's for good).
const GRACE := 0.8
const RAW := Color(0.92, 0.9, 1.0)

static var TEXT := {
	"shudder": "It shudders",
	"holds": "It shudders, and holds",
	"crack": "Cracks",
	"short": "Needs %d unbanked essence",
	"hurt": "-%d",
	"stair_title": "THE WARD BREAKS",
	"stair": "The stair is open. Nothing is given for a ward broken.",
	"vault_title": "THE SEAL BREAKS",
	"vault": "The vault stands open, and empty. The way out opens.",
	"gate_title": "THE BARS GIVE",
	"gate": "The way out is open.",
	"proving_title": "THE RELIQUARY BREAKS",
	"proving": "The way up is open. Nothing waits for you inside.",
	"erupt": "%s erupts! -%d",
	"dark": "%s is dark",
	"wavers": "wavers",
}

var main
var on := false  # the climber is Unbound (set by give())
var strain := {}  # body part -> 0..100
var idle := {}  # body part -> seconds since a cast from it
var dark := {}  # body part -> seconds it stays dark
var glow := {}  # body part -> seconds raw essence still shows there (an eruption)
var bolts: Array = []
var landings: Array = []
var dots: Array = []
var hits := {}  # barrier id -> cracks this floor
var shudder := {}  # barrier id -> seconds it shakes
var hold_t := 0.0
var punches := 0  # blows landed (tests)
var broke_rules := false  # a barrier broken on the bondless first climb: the Regard refuses you
var waver_chance := WAVER  # (tests set it to 0 or 1)
var fills := {}  # slot -> each technique's fill (kept while the climber's bonds are rebuilt)
var boosts := 0  # boosted casts (tests)
var _floor_key := ""


func _ready() -> void:
	z_as_relative = false
	z_index = 46  # over the darkness (40): cracks and bolts read in the dark


# --- the climber's six -------------------------------------------------------------

## After main.gd rebuilds the climber's bonds: an Unbound carries their six
## techniques in the marks' places, and their parts' gifts.
func give() -> void:
	var prof = main.profile
	on = Unbound.is_on(prof)
	var p = main.player
	if not on or p == null:
		return
	p.bonds.clear()
	var techs: Array = Unbound.state(prof)["techs"]
	for i in Unbound.PARTS.size():
		if i < techs.size() and Tech.valid(techs[i]):
			var b = TechBond.new(techs[i], Unbound.PARTS[i], i, self)
			b.attr_fill = 1.0 + prof.attribute("water")
			b.essence = minf(float(fills.get(i, 0.0)), b.capacity())
			p.bonds[Unbound.PARTS[i]] = b
	p.attr_strength *= 1.0 + Unbound.gift(prof, "strength")
	p.attr_speed *= 1.0 + Unbound.gift(prof, "speed")
	p.attr_will *= 1.0 + Unbound.gift(prof, "will")
	p.base_hp *= 1.0 + Unbound.gift(prof, "health")
	p.refresh_gear()
	_sync()


func strain_of(part: String) -> float:
	return float(strain.get(part, 0.0))


func is_dark(part: String) -> bool:
	return float(dark.get(part, 0.0)) > 0.0


## Adds strain to a part (casting, or the dev tools); erupts at ERUPT.
func add_strain(part: String, amount: float) -> void:
	strain[part] = clampf(strain_of(part) + amount, 0.0, ERUPT)
	idle[part] = 0.0
	if strain_of(part) >= HOT:
		main.tip("unbound_strain")
	if strain_of(part) >= ERUPT:
		erupt(part)


## A body part did its thing (player.gd _part_action): the techniques of
## that part fill, as a mark's bond would.
func part_action(part: String, amount: float) -> void:
	var p = main.player
	if p == null or amount <= 0.0:
		return
	for b in p.bonds.values():
		if "tech" in b and b.tech_part() == part:
			b.fill(amount)
	_sync()


## Casts a carried technique (technique_bond.gd cast): it spends its fill
## (what's missing adds strain), and a boost if you carry its essences.
func cast(b, p) -> void:
	var t: Dictionary = b.tech
	var part: String = t["part"]
	if is_dark(part):
		main.fx_text(p.global_position + Vector2(0, -40), TEXT["dark"] % Unbound.PART_NAMES[part], Color(0.6, 0.6, 0.65))
		return
	var prof = main.profile
	var at: Vector2 = p.global_position
	var power: float = Unbound.power(prof, part) * (1.0 + prof.attribute("fire"))
	var hot := strain_of(part) > HOT
	var need: float = b.capacity()
	var missing := clampf(need - b.essence, 0.0, need)
	b.essence = maxf(0.0, b.essence - need)
	if bool(Unbound.state(prof).get("boost", true)) and boost_pay(t):
		power *= 1.0 + Tech.BOOST
		boosts += 1
		main.fx_text(p.global_position + Vector2(0, -66), Tech.TEXT["boosted"], Tech.color(Tech.lead(t)).lightened(0.3))
		main.fx_ring(p.global_position, Tech.color(Tech.lead(t)), 34.0, 0.3, 2.5)
	if hot:
		power *= HOT_POWER
		if randf() < waver_chance:
			power *= WAVER_POWER
			p.aim = p.aim.rotated(randf_range(-0.5, 0.5))
			main.fx_text(p.global_position + Vector2(0, -52), TEXT["wavers"], Color(1.0, 0.55, 0.4))
	if missing > 0.5:
		main.fx_text(p.global_position + Vector2(0, -60), Tech.TEXT["not_full"], Color(0.85, 0.8, 0.95))
	Tech.cast(t, p, power, self)
	if TreeRules.note_echo(prof, t):
		# The first time a technique comes close to a bond's spell (library.gd ECHOES).
		main.fx_text(p.global_position + Vector2(0, -78), Library.TEXT["echoes"] % Library.echo_of(t)["name"], Color(0.79, 0.65, 1.0))
	add_strain(part, Tech.strain(t) + Tech.EMPTY_STRAIN * missing / maxf(need, 0.01))
	_sync()
	Library.on_cast(p, {"by": "technique", "bond": b, "part": part, "at": at, "tech": t})  # (the capstones answer: unbound_forms.gd)


## True if you carry all of a technique's boost unbanked (the path's essence
## from your unbanked flow).
func can_boost(t: Dictionary) -> bool:
	var c := Tech.cost(t, main.profile)
	for k in c:
		var have: float = (main.run_flow if k == main.profile.path else 0.0) if k in Secret.ORDER else float(main.run_essence.get(k, 0.0))
		if have + 0.001 < float(c[k]):
			return false
	return true


## Spends a technique's boost from what you carry unbanked, if you carry all
## of it (nothing is spent otherwise). True if it was spent.
func boost_pay(t: Dictionary) -> bool:
	if not can_boost(t):
		return false
	var c := Tech.cost(t, main.profile)
	for k in c:
		var need := float(c[k])
		if k in Secret.ORDER:
			main.run_flow = maxf(0.0, main.run_flow - need)
		else:
			main.run_essence[k] = float(main.run_essence.get(k, 0.0)) - need
			if float(main.run_essence[k]) <= 0.001:
				main.run_essence.erase(k)
	return true


## The part erupts: you're hurt badly (it can kill), it goes dark, raw essence shows.
func erupt(part: String) -> void:
	var p = main.player
	dark[part] = DARK_TIME
	glow[part] = DARK_TIME
	strain[part] = ERUPT_LEFT
	idle[part] = 0.0
	main.tip("unbound_erupt")
	if p == null or p.dead:
		return
	var col := part_color(main.profile, part)
	var dmg: float = p.max_health() * ERUPT_HURT
	main.fx_text(p.global_position + Vector2(0, -46), TEXT["erupt"] % [Unbound.PART_NAMES[part], int(dmg)], Color(1.0, 0.4, 0.3))
	main.fx_burst(p.global_position, Vector2.ZERO, col, 30, 320.0)
	main.fx_burst(p.global_position, Vector2.ZERO, RAW, 14, 200.0)
	main.fx_ring(p.global_position, col, 70.0, 0.5, 5.0)
	main.light_flash(p.global_position, col, 2.0, 2.0, 0.5)
	main.shake(9.0)
	main.sfx("burn", 0.7)
	main.sfx("hurt", 0.8, -2.0)
	main.hurt_flash = 0.35
	p.hp -= dmg
	if p.hp <= 0.0 and p._defy_death():
		p.hp = maxf(p.hp, 1.0)
	if p.hp <= 0.0:
		p.hp = 0.0
		p.dead = true
		main.sfx("death", 1.0, 0.0, 0.0)
		main.on_player_died()


## Keeps each carried technique's fill (so rebuilding the climber's bonds keeps it).
func _sync() -> void:
	var p = main.player
	if p == null:
		return
	for b in p.bonds.values():
		if "tech" in b:
			fills[b.slot] = b.essence


# --- each frame ---------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if main == null or main.player == null:
		return
	var key := "%s:%d" % [main.tower, main.floor_num]
	if key != _floor_key:
		_floor_key = key
		_new_floor()
	var p = main.player
	if on:
		var fade := STRAIN_FADE * maxf(1.0, Unbound.gift(main.profile, "fade"))
		for part in strain.keys():
			idle[part] = float(idle.get(part, 0.0)) + delta
			if float(idle[part]) > STRAIN_REST:
				strain[part] = maxf(0.0, strain_of(part) - fade * delta)
		for d in [dark, glow]:
			for part in d.keys():
				d[part] = float(d[part]) - delta
				if float(d[part]) <= 0.0:
					d.erase(part)
		_sync()
	_tick_bolts(delta)
	_tick_landings(delta, p)
	_tick_dots(delta)
	_tick_fists(delta, p)
	for id in shudder.keys():
		shudder[id] = float(shudder[id]) - delta
		if float(shudder[id]) <= 0.0:
			shudder.erase(id)
	if not bolts.is_empty() or not shudder.is_empty() or hold_t > 0.0 or not hits.is_empty() or Engine.get_physics_frames() % 6 == 0:
		queue_redraw()


## A new floor (the stair's rest, or a fresh start): strain clears; the old floor's cracks are gone.
func _new_floor() -> void:
	strain.clear()
	idle.clear()
	dark.clear()
	glow.clear()
	bolts.clear()
	landings.clear()
	dots.clear()
	hits.clear()
	shudder.clear()
	hold_t = 0.0
	_sync()


## `extra` (Volley): "seek" (how fast it turns toward the nearest foe ahead
## within "seek_range", in radians a second), "focus" and "struck" (a
## dictionary the volley's bolts share: each that strikes a foe the volley
## already struck hits `focus` harder for every earlier hit).
func add_bolt(pos: Vector2, vel: Vector2, reach: float, dmg: float, w: Dictionary, power: float, col: Color, extra := {}) -> void:
	var b := {"pos": pos, "vel": vel, "left": reach, "dmg": dmg, "w": w, "power": power, "col": col, "trail": [pos]}
	b.merge(extra)
	bolts.append(b)


func add_landing(after: float, r: float, dmg: float, w: Dictionary, power: float, col: Color) -> void:
	landings.append({"t": after, "r": r, "dmg": dmg, "w": w, "power": power, "col": col})


func add_dot(e, dps: float, seconds: float, col: Color) -> void:
	dots.append({"e": e, "dps": dps, "t": seconds, "tick": 0.5, "col": col})


func _tick_bolts(delta: float) -> void:
	if bolts.is_empty():
		return
	var p = main.player
	var keep: Array = []
	for b in bolts:
		if float(b.get("seek", 0.0)) > 0.0:
			_seek(b, delta)
		var step: Vector2 = b["vel"] * delta
		b["pos"] += step
		b["left"] -= step.length()
		b["trail"].append(b["pos"])
		if b["trail"].size() > 6:
			b["trail"].pop_front()
		var gone: bool = b["left"] <= 0.0 or main.is_solid(b["pos"]) or not main.room.has_point(b["pos"])
		if not gone:
			for e in main.targets():
				if b["pos"].distance_to(e.global_position) < e.radius + 5.0:
					var dmg: float = b["dmg"]
					if b.has("struck"):
						var before: int = int(b["struck"].get(e.get_instance_id(), 0))
						dmg *= 1.0 + float(b.get("focus", 0.0)) * before
						b["struck"][e.get_instance_id()] = before + 1
					Tech.hit(p, e, dmg, b["vel"].normalized(), b["w"], b["power"], self)
					gone = true
					break
		if gone:
			main.fx_burst(b["pos"], -b["vel"].normalized(), b["col"], 8, 160.0)
		else:
			keep.append(b)
	bolts = keep


## A seeking bolt turns a little toward the nearest foe ahead of it.
func _seek(b: Dictionary, delta: float) -> void:
	var v: Vector2 = b["vel"]
	var best = null
	var best_d := float(b.get("seek_range", 150.0))
	for e in main.targets():
		var to: Vector2 = e.global_position - b["pos"]
		var d := to.length()
		if d < best_d and absf(v.angle_to(to)) < 1.2:
			best_d = d
			best = e
	if best == null:
		return
	var want: float = v.angle_to(best.global_position - b["pos"])
	var turn := float(b["seek"]) * delta
	b["vel"] = v.rotated(clampf(want, -turn, turn))


func _tick_landings(delta: float, p) -> void:
	for l in landings.duplicate():
		l["t"] -= delta
		if l["t"] > 0.0:
			continue
		landings.erase(l)
		if p == null or p.dead:
			continue
		var at: Vector2 = p.global_position
		for e in main.targets():
			var to: Vector2 = e.global_position - at
			if to.length() <= l["r"] + e.radius:
				Tech.hit(p, e, l["dmg"], to.normalized() if to.length() > 0.1 else Vector2.RIGHT, l["w"], l["power"], self)
		main.fx_ring(at, l["col"], l["r"], 0.4, 5.0)
		main.fx_burst(at, Vector2.ZERO, l["col"], 16, 220.0)
		main.shake(5.0)
		main.sfx("hit_heavy", 0.6, -2.0)


func _tick_dots(delta: float) -> void:
	for d in dots.duplicate():
		d["t"] -= delta
		d["tick"] -= delta
		if not is_instance_valid(d["e"]) or d["e"].dead or d["t"] <= 0.0:
			dots.erase(d)
			continue
		if d["tick"] <= 0.0:
			d["tick"] = 0.5
			d["e"].take_hit(d["dps"] * 0.5, Vector2.ZERO, 0.0, false, true)
			main.fx_burst(d["e"].global_position, Vector2.UP, d["col"], 3, 80.0)


# --- barriers --------------------------------------------------------------------------

## The barriers on this floor: [{id, kind, rect, ref}].
func barriers() -> Array:
	var out: Array = []
	var pz = main.puzzle
	if main.ward and pz != null and String(pz.kind) != "" and not pz.solved and not (main.proving != null and main.proving.on):
		out.append({"id": "stair", "kind": "stair", "rect": Rect2(main.stair_pos - Vector2(22, 22), Vector2(44, 44)), "ref": pz})
	if main.wings != null:
		for w in main.wings.wings:
			if w["vault"] == "sealed":
				out.append({"id": "vault:%s" % w["id"], "kind": "vault", "rect": Rect2(w["seal_pos"] - Vector2(20, 20), Vector2(40, 40)), "ref": w})
	if main.door_view != null:
		var dv = main.door_view
		for i in dv.lock_rooms:
			var lr: Dictionary = dv.lock_rooms[i]
			if lr["state"] != "shut":
				continue
			for gi in lr["gates"].size():
				out.append({"id": "gate:%s:%d" % [str(i), gi], "kind": "gate", "rect": dv._tiles_rect(lr["gates"][gi]), "ref": lr})
		for d in dv.list:
			if String(d.get("lock", "")) == "proving_prize" and not d["open"]:
				out.append({"id": "proving", "kind": "proving", "rect": d["rect"], "ref": d})
	return out


## The barrier you could strike now ({} if none): within reach, in front of you.
func barrier_in_reach(p) -> Dictionary:
	var reach: float = float(FISTS["raw_reach"] if on else FISTS["reach"]) + p.radius
	var best := {}
	var best_d := reach
	for bar in barriers():
		var r: Rect2 = bar["rect"]
		var pos: Vector2 = p.global_position
		var near := Vector2(clampf(pos.x, r.position.x, r.end.x), clampf(pos.y, r.position.y, r.end.y))
		var d := pos.distance_to(near)
		if d > best_d:
			continue
		if d > 4.0 and p.aim.dot((near - pos).normalized()) < 0.2:
			continue
		best = bar
		best_d = d
	return best


## Your hands can strike it: bare fists, or (once Unbound) raw essence with any melee weapon.
func _can_punch(p) -> bool:
	return p.weapon == "fists" or (on and p.wkind() == "melee")


func _tick_fists(delta: float, p) -> void:
	if p == null or p.dead or main.menu_open() or main.camp_choosing or main.climbing or main.overlay_showing() or not _can_punch(p) \
			or not Input.is_action_pressed("attack"):
		hold_t = 0.0
		return
	var bar := barrier_in_reach(p)
	if bar.is_empty():
		hold_t = 0.0
		return
	hold_t += delta
	if hold_t >= float(FISTS["hold"]):
		hold_t = 0.0
		punch(bar)


## One blow against a barrier: "shudder" (the first ever: the warning),
## "holds" (a marked climber after the first climb: nothing gives), "crack",
## "broke", or "short" (the Unbound without the essence for it).
func punch(bar: Dictionary) -> String:
	var prof = main.profile
	var p = main.player
	var st := Unbound.state(prof)
	var id: String = bar["id"]
	var at: Vector2 = bar["rect"].get_center()
	if not on and not main.first_climb:
		shudder[id] = 0.5
		main.fx_text(at + Vector2(0, -30), TEXT["holds"], Color(0.85, 0.82, 0.9))
		main.shake(2.0)
		main.sfx("hit_armor", 0.5, -6.0)
		main.tip("unbound_fists_marked")
		queue_redraw()
		return "holds"
	if not st["found"]:
		st["found"] = true
		prof.save()
		shudder[id] = 0.8
		hits[id] = 0
		main.fx_text(at + Vector2(0, -30), TEXT["shudder"], Color(0.85, 0.82, 0.9))
		main.shake(3.0)
		main.sfx("hit_armor", 0.5, -4.0)
		main.tip("unbound_fists_found")
		queue_redraw()
		return "shudder"
	var cracks := 1
	if on:
		var need: float = float(FISTS["raw_cost"]) * (1.0 - Unbound.gift(prof, "cost"))
		var have := 0.0
		for k in main.run_essence:
			have += float(main.run_essence[k])
		if have < need:
			main.fx_text(at + Vector2(0, -30), TEXT["short"] % int(ceil(need)), Color(0.85, 0.8, 0.95))
			return "short"
		main.SecretBonds.take_essence(main.run_essence, need)
		cracks = int(FISTS["raw_blows"])
		main.fx_bolt([p.global_position + p.aim * p.radius, at], RAW)
	else:
		var drained: Dictionary = main.SecretBonds.take_essence(main.run_essence, float(FISTS["drain"]))
		var got := 0.0
		for k in drained:
			got += float(drained[k])
		var hurt: float = float(FISTS["hurt"]) * (2.0 if got < float(FISTS["drain"]) * 0.5 else 1.0)
		hurt = minf(hurt, p.hp - 1.0)
		if hurt > 0.0:
			p.hp -= hurt
			main.hurt_flash = 0.2
			main.fx_text(p.global_position + Vector2(0, -36), TEXT["hurt"] % int(ceil(hurt)), Color(1.0, 0.55, 0.45))
		main.tip("unbound_fists")
	punches += 1
	hits[id] = int(hits.get(id, 0)) + cracks
	shudder[id] = 0.35
	main.fx_burst(at, (p.global_position - at).normalized(), barrier_color(bar["kind"]), 10, 180.0)
	main.shake(4.0)
	main.sfx("hit_heavy", 0.7, -2.0)
	queue_redraw()
	if int(hits[id]) >= int(BLOWS[bar["kind"]]):
		_break(bar)
		prof.note("barriers")
		prof.save()
		if main.first_climb and not on:
			broke_rules = true
			main.tip("unbound_rules")
		return "broke"
	main.fx_text(at + Vector2(0, -30), TEXT["crack"], barrier_color(bar["kind"]))
	return "crack"


func barrier_color(kind: String) -> Color:
	match kind:
		"stair":
			return Color(0.75, 0.55, 1.0)
		"vault", "proving":
			return Color(0.95, 0.75, 0.35)
	return Color(0.85, 0.85, 0.9)


## The barrier gives: its challenge is skipped and its reward forfeit.
func _break(bar: Dictionary) -> void:
	var at: Vector2 = bar["rect"].get_center()
	var title := ""
	var line := ""
	match String(bar["kind"]):
		"stair":
			var pz = bar["ref"]
			pz.solved = true
			pz.locked = false
			pz._unseal()
			for g in pz.gates:
				g["open"] = true
				if is_instance_valid(g["body"]):
					g["body"].queue_free()
				pz.set_solid(g["rect"], false)
			pz.queue_redraw_all()
			main.ward = false
			main.stair_open = true
			main.room_view.stair_open = true
			main.door_view.unlock_puzzle()
			title = TEXT["stair_title"]
			line = TEXT["stair"]
		"vault":
			var W = main.wings
			var w: Dictionary = bar["ref"]
			if not w["state"] in ["idle", "done"]:
				w["state"] = "done"
				W._open(w["door"], w.get("gate_body"))
				w["gate_body"] = null
				if W.active == w:
					W.active = {}
			if w.has("light"):
				main.lighting.remove_light(w["light"])
				w.erase("light")
			W._open([w["vault_door"]], w.get("vault_body"))
			w["vault_body"] = null
			w["vault"] = "taken"  # (open, and empty)
			W.dirty = true
			main.room_view.queue_redraw()
			title = TEXT["vault_title"]
			line = TEXT["vault"]
		"gate":
			main.door_view._reopen(bar["ref"])
			title = TEXT["gate_title"]
			line = TEXT["gate"]
		"proving":
			var d: Dictionary = bar["ref"]
			d["lock"] = ""
			main.door_view.open_door(d)
			main.ward = false
			main.stair_open = true
			main.room_view.stair_open = true
			if main.proving != null:
				main.proving.prize["state"] = "empty"
			title = TEXT["proving_title"]
			line = TEXT["proving"]
	main.fx_burst(at, Vector2.ZERO, barrier_color(bar["kind"]), 26, 260.0)
	main.fx_burst(at, Vector2.ZERO, RAW, 12, 200.0)
	main.light_flash(at, barrier_color(bar["kind"]), 1.6, 1.6, 0.4)
	main.shake(7.0)
	main.sfx("slam", 0.7, 0.0, 0.0)
	main.banner = {"title": title, "lines": [line], "t": 3.0}
	hits.erase(bar["id"])


# --- the beasts' offers -------------------------------------------------------------------

## The end of the Regard (main.gd end_regard): the first time, the choice to
## refuse the mark (offered only when no barrier was broken; with one broken
## the beast refused you as the Regard began: main.gd _grant_regard). True
## while it shows.
func ask_at_regard() -> bool:
	var rg: Dictionary = main.regard
	if rg.is_empty() or rg.has("asked") or Unbound.is_on(main.profile) or not main.profile.bonds.has(rg["part"]):
		return false
	rg["asked"] = true
	_offer_refusal(rg["part"], rg["id"], "regard", [])
	return true


## What a summit offers instead of a plain mark: "condense" (the Unbound),
## or "" (the usual).
func summit_choice() -> String:
	return "condense" if Unbound.is_on(main.profile) else ""


## Opens the summit's choice (summit_choice); the victory shows after it, with `lines`.
func offer_summit(kind: String, lines: Array) -> void:
	if kind != "condense":
		return
	var ess := String(main.tower_data().get("essence", "air"))
	main.camp = {"stage": "condense", "choices": Unbound.PARTS.map(func(pt): return "condense:" + pt), "title": Unbound.TEXT["condense_title"],
		"lines": [Unbound.TEXT["condense_sub"] % Tech.display(ess)], "kind": ess, "victory_lines": lines, "t": 0.0}
	main.tip("unbound_condense")
	_open_cards()


func _offer_refusal(part: String, id: String, from: String, lines: Array) -> void:
	main.camp = {"stage": "unbind", "choices": ["unbind:accept", "unbind:refuse"], "title": Unbound.TEXT["refuse_title"],
		"lines": Unbound.TEXT["refuse_lines"], "part": part, "id": id, "from": from, "victory_lines": lines, "t": 0.0, "armed": -1}
	main.tip("unbound_offer")
	_open_cards()


func _open_cards() -> void:
	main.camp_choosing = true
	main.card_focus = 0
	if main.player != null:
		main.player.set_physics_process(false)
	main.sfx("ready", 0.6, -2.0, 0.0)


## A card on the choice (main.gd camp_card).
func card(pick: String) -> Dictionary:
	var c: Dictionary = main.camp
	var Bonds = main.BondScript.Bonds
	if pick.begins_with("condense:"):
		var part := pick.substr(9)
		var kind := String(c.get("kind", "air"))
		var prof = main.profile
		var now := Unbound.level_for(Unbound.raw(prof, part) + Unbound.CONDENSE)
		return {"name": Unbound.TEXT["condense_card"] % [int(Unbound.CONDENSE), Unbound.PART_NAMES[part]], "item": "",
			"desc": Unbound.TEXT["condense_desc"] % [Tech.display(kind), Unbound.PART_NAMES[part].to_lower(), now],
			"color": part_color(prof, part), "note": Unbound.TEXT["level"] % Unbound.level(prof, part)}
	var part2 := String(c.get("part", "hand"))
	var id := String(c.get("id", ""))
	var bname: String = Bonds.BONDS[id]["name"] if Bonds.BONDS.has(id) else "?"
	if pick == "unbind:accept":
		return {"name": Unbound.TEXT["accept_name"], "item": "", "color": Bonds.BONDS[id]["color"] if Bonds.BONDS.has(id) else Color(0.9, 0.8, 0.5),
			"desc": Unbound.TEXT["accept_desc"] % [bname, Bonds.PART_NAMES.get(part2, part2).to_lower()]}
	var armed: bool = int(c.get("armed", -1)) == 1
	var again: String = Unbound.TEXT["refuse_again"] if main.touch_active else Unbound.TEXT["refuse_again_keys"]
	return {"name": again if armed else Unbound.TEXT["refuse_name"], "item": "", "color": RAW,
		"desc": Unbound.TEXT["refuse_desc"], "note": Unbound.TEXT["refuse_note"]}


## A card taken (main.gd choose_camp).
func choose(i: int) -> void:
	var c: Dictionary = main.camp
	var pick: String = c["choices"][i]
	var prof = main.profile
	var lines: Array = c.get("victory_lines", [])
	if pick.begins_with("condense:"):
		var part := pick.substr(9)
		var kind := String(c.get("kind", "air"))
		var pd: Dictionary = prof.part_density.get(part, {})
		pd[kind] = float(pd.get(kind, 0.0)) + Unbound.CONDENSE
		prof.part_density[part] = pd
		prof.save()
		lines.append(Unbound.TEXT["condensed"] % [int(Unbound.CONDENSE), Tech.display(kind), Unbound.PART_NAMES[part].to_lower()])
		_close_cards()
		main.fx_ring(main.player.global_position, part_color(prof, part), 60.0, 0.6, 4.0)
		main.show_victory(lines)
		return
	if pick == "unbind:accept":
		_close_cards()
		if c.get("from", "") == "dev":
			if main.player != null:
				main.player.set_physics_process(true)
		elif c.get("from", "") == "regard":
			main.end_regard()
		return
	# Refusing is for good: a second press, and not in the first moment.
	if float(c.get("t", 0.0)) < GRACE:
		return
	if int(c.get("armed", -1)) != i:
		c["armed"] = i
		main.card_focus = i
		main.sfx("ui_move")
		return
	Unbound.become(prof)
	prof.save()
	_close_cards()
	main._give_bonds()
	main.tip("unbound")
	main.sfx("crit", 0.5, -2.0, 0.0)
	if main.player != null:
		main.light_flash(main.player.global_position, RAW, 2.2, 2.0, 0.7)
		main.fx_ring(main.player.global_position, RAW, 90.0, 0.7, 5.0)
	if c.get("from", "") == "regard":
		main.end_regard()
	elif main.player != null:
		main.player.set_physics_process(true)


func _close_cards() -> void:
	main.camp_choosing = false
	main.camp = {}


# --- how it looks -----------------------------------------------------------------------

## A part's main colour: the kind most pooled there (its natural kind if none).
static func part_color(prof, part: String) -> Color:
	var pd: Dictionary = prof.part_density.get(part, {})
	var best: String = Unbound.PART_KIND[part]
	var most := 0.0
	for k in pd:
		if float(pd[k]) > most:
			most = float(pd[k])
			best = k
	return Tech.color(best)


## Veins of raw essence on the climber in the tower (player.gd draws them in
## place of marks): each part's main colour, more and brighter with its
## level; strain flickers them hot; an eruption leaves raw essence showing.
func draw_veins(c: CanvasItem, p, side: Vector2, t: float) -> void:
	var prof = main.profile
	var b := Draw.Batch.new()
	for part in Unbound.PARTS:
		var lv := Unbound.level(prof, part)
		var at: Vector2 = p._mark_anchor(part, side)
		var col := vein_color(prof, part, t)
		if p.dead:
			col = col.lerp(Color(0.5, 0.5, 0.5), 0.6)
		var n := 2 + int(lv / 3.0)
		var length := 3.0 + 0.4 * float(lv)
		for i in n:
			var ang := float(i) * TAU / float(n) + float(hash(part) % 100) * 0.06
			var mid := at + Vector2.from_angle(ang) * length * 0.5 + Vector2.from_angle(ang + 1.4) * 1.0
			var tip := at + Vector2.from_angle(ang + 0.35) * length
			b.line(at, mid, Color(col, 0.5 + 0.035 * lv), 0.9)
			b.line(mid, tip, Color(col, 0.3 + 0.035 * lv), 0.7)
		b.dot(at, 1.1 + 0.08 * lv, col)
		if glow.has(part):
			for i in 5:
				var ma := t * 3.0 + float(i) * TAU / 5.0
				b.dot(at + Vector2.from_angle(ma) * (6.0 + 2.0 * sin(t * 7.0 + i)), 1.3, Color(RAW, 0.85))
	b.flush(c)


## A vein's colour now: the part's colour, brighter with level; hot as it strains; grey while dark.
func vein_color(prof, part: String, t: float) -> Color:
	var col := part_color(prof, part)
	var lv := Unbound.level(prof, part)
	col = col.lerp(Color.WHITE, 0.03 * lv)
	col.a = 0.45 + 0.055 * lv
	var s := strain_of(part)
	if is_dark(part):
		return Color(0.35, 0.33, 0.4, 0.7)
	if s > 0.0:
		var k := clampf(s / ERUPT, 0.0, 1.0)
		var flick := 0.5 + 0.5 * sin(t * (6.0 + 12.0 * k))
		col = col.lerp(Color(1.0, 0.35, 0.2), k * (0.5 + 0.4 * flick) if s > HOT else k * 0.3)
	return col


## The veins' glow over the darkness (player.gd's overlay).
func glow_into(c: CanvasItem, p) -> void:
	var prof = main.profile
	var t := Time.get_ticks_msec() * 0.001
	var b := Draw.Batch.new()
	var lifted := Vector2(0, -p.jump_height())
	for part in Unbound.PARTS:
		var lv := Unbound.level(prof, part)
		var col := vein_color(prof, part, t)
		var at: Vector2 = lifted + p._mark_anchor(part, p.aim.orthogonal())
		var pulse := 0.8 + 0.2 * sin(t * 2.5 + at.x)
		b.dot(at, 4.0 + 0.2 * lv, Color(col, (0.05 + 0.012 * lv) * pulse))
		b.dot(at, 2.0 + 0.1 * lv, Color(col, (0.1 + 0.02 * lv) * pulse))
		if glow.has(part):
			b.dot(at, 9.0, Color(RAW, 0.2 * pulse))
	b.flush(c)


## The strain bar under a technique's HUD medallion: amber to red, a tick at HOT, grey while dark.
func strain_hud_into(b, c: Vector2, r: float, part: String) -> void:
	var w := r * 2.0
	var at := c + Vector2(-r, r + 6.0)
	# A slim gilt-framed gauge under the medallion, a stud where it runs hot.
	if is_dark(part):
		UI.gauge_into(b, Rect2(at, Vector2(w, 3.0)), float(dark[part]) / DARK_TIME, Color(0.45, 0.42, 0.5), -1.0, Color(), 0)
		return
	var k := clampf(strain_of(part) / ERUPT, 0.0, 1.0)
	var col := Color(0.95, 0.75, 0.35).lerp(Color(1.0, 0.25, 0.15), clampf((strain_of(part) - 40.0) / 60.0, 0.0, 1.0))
	UI.gauge_into(b, Rect2(at, Vector2(w, 3.0)), k, col, -1.0, Color(), 0)
	UI.diamond_into(b, at + Vector2(w * HOT / ERUPT, 1.5), 2.6, UI.OUTLINE)
	UI.diamond_into(b, at + Vector2(w * HOT / ERUPT, 1.5), 1.6, UI.GILT_HI if k * ERUPT < HOT else Color(1.0, 0.5, 0.35))


## Cracks in struck barriers, the fist's charge, bolts in flight: over the darkness.
func _draw() -> void:
	if main == null:
		return
	var t := Time.get_ticks_msec() * 0.001
	var b := Draw.Batch.new()
	var list := barriers() if (not hits.is_empty() or hold_t > 0.0) else []
	for bar in list:
		var id: String = bar["id"]
		if not hits.has(id):
			continue
		var r: Rect2 = bar["rect"]
		var k: float = clampf(float(hits[id]) / float(BLOWS[bar["kind"]]), 0.0, 1.0)
		if int(hits[id]) == 0:
			k = 0.12  # (the first shudder: a faint crack)
		var c := r.get_center()
		if shudder.has(id):
			c += Vector2(sin(t * 70.0), cos(t * 53.0)) * 2.0 * float(shudder[id])
		var col := barrier_color(bar["kind"])
		var n := 3 + int(k * 7.0)
		var reach := minf(r.size.x, r.size.y) * (0.25 + 0.4 * k)
		for i in n:
			var ang := float(i) * 2.399 + float(hash(id) % 50) * 0.1
			var p0 := c
			var p1 := c + Vector2.from_angle(ang) * reach * 0.5 + Vector2.from_angle(ang + 1.6) * 3.0
			var p2 := c + Vector2.from_angle(ang + 0.2) * reach
			b.line(p0, p1, Color(0.05, 0.04, 0.06, 0.8), 2.4)
			b.line(p1, p2, Color(0.05, 0.04, 0.06, 0.8), 1.8)
			b.line(p0, p1, Color(col.lightened(0.3), 0.55 + 0.4 * k), 1.0)
			b.line(p1, p2, Color(col.lightened(0.3), 0.4 + 0.4 * k), 0.8)
		b.dot(c, 2.0 + 4.0 * k, Color(col.lightened(0.4), 0.3 + 0.4 * k))
	var p = main.player
	if hold_t > 0.0 and p != null:
		var bar2 := barrier_in_reach(p)
		if not bar2.is_empty():
			var at: Vector2 = bar2["rect"].get_center()
			var kk := hold_t / float(FISTS["hold"])
			b.arc(at, 16.0, -PI / 2.0, -PI / 2.0 + TAU * kk, 24, Color(RAW if on else barrier_color(bar2["kind"]), 0.9), 2.5)
	for bo in bolts:
		var tr: Array = bo["trail"]
		for i in range(1, tr.size()):
			b.line(tr[i - 1], tr[i], Color(bo["col"], 0.15 + 0.12 * i), 1.0 + 0.6 * i)
		b.dot(bo["pos"], 6.0, Color(bo["col"], 0.35))
		b.dot(bo["pos"], 3.5, bo["col"].lightened(0.3))
		b.dot(bo["pos"], 1.6, Color.WHITE)
	b.flush(self)
