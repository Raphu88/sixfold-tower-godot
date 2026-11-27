extends RefCounted
## The high steps' effects (steps 7 to 12 of a mark: scripts/mark_ascent.gd
## says what each upgrade does; this file runs the "fx" part as a mark's
## spell is cast: library.gd on_cast). The numbers that only change a
## spell's own numbers ("mods") are applied in bond.gd spell_stat instead.
##
## Every effect is drawn with the shading toolkit (draw_util.gd Batch: disc,
## soft, stroke, poly), lit from the top-left like everything else; the
## warning rings (a meteor's, a rune's) stay flat, like every warning.

const Ascent := preload("res://scripts/mark_ascent.gd")
const Library := preload("res://scripts/library.gd")
const SpellFx := preload("res://scripts/spell_fx.gd")
const Reactions := preload("res://scripts/reactions.gd")

## How the effects look (seconds and sizes).
const LOOK := {"streak": 0.2, "ring": 0.35, "crown": 0.9, "warn_width": 2.0, "blade_len": 14.0}


## A mark's spell was just cast: its high steps' effects answer.
static func on_cast(p, cast: Dictionary) -> void:
	if String(cast.get("by", "")) != "bond" or p == null or not is_instance_valid(p) or p.dead:
		return
	var b = cast.get("bond")
	var sp = cast.get("spell")
	if b == null or not (sp is Dictionary) or not ("step" in b) or int(b.step) < 7 or not b.has_method("ascent_ups"):
		return
	var main = p.main
	if main == null or not is_instance_valid(main):
		return
	for up in b.ascent_ups():
		var fxs: Array = up.get("fx", [])
		for i in fxs.size():
			var fx: Dictionary = fxs[i]
			if not Ascent.covers(fx, sp):
				continue
			var key := "%s:%d" % [up["id"], i]
			var now := Time.get_ticks_msec()
			if int(b.fx_ready.get(key, 0)) > now:
				continue
			if fx.has("every"):
				b.fx_ready[key] = now + int(float(fx["every"]) * 1000.0)
			run(p, b, sp, fx)
		if String(up.get("id", "")).begins_with("zenith_") and fxs.any(func(f): return Ascent.covers(f, sp)):
			_crown(main, p, b.color())


## Runs one effect for a cast of `sp` by bond `b`.
static func run(p, b, sp: Dictionary, fx: Dictionary) -> void:
	var main = p.main
	var col: Color = b.color()
	var power: float = float(b.spell_power(sp)) * float(b.flow_power)
	match String(fx.get("kind", "")):
		"echo":
			var sel: int = int(b.selected)
			var pw := float(fx.get("power", 0.6))
			var sid := String(sp.get("id", ""))
			SpellFx.later(main, float(fx.get("delay", 0.5)), func():
				if is_instance_valid(p) and not p.dead and is_instance_valid(main):
					_cast_again(b, p, sel, sid, pw))
		"nova":
			_nova(p, b, fx, p.global_position, power, col)
		"strike":
			_strike(p, b, fx, power, col)
		"aim_burst":
			var at: Vector2 = main.walkable_point(p.global_position, p.global_position + p.aim * float(fx.get("range", 150.0)), 14.0)
			var delay := float(fx.get("delay", 0.6))
			var r := float(fx.get("radius", 60.0))
			_warn(main, at, r, delay, col)
			SpellFx.later(main, delay, func():
				if is_instance_valid(p) and is_instance_valid(main):
					_burst_at(p, b, fx, at, r, power, col))
		"orbit":
			_orbit(p, b, fx, power, col)
		"wave":
			var dmg := float(fx.get("damage", 10.0)) * power
			var extra := {"source": b, "amount": maxf(1.0, dmg * 0.2)}
			if String(fx.get("state", "")) != "":
				extra["states"] = {String(fx["state"]): float(fx.get("seconds", 3.0))}
			main.add_wave(p.global_position + p.aim * (p.radius + 6.0), p.aim, float(fx.get("width", 60.0)), float(fx.get("travel", 220.0)), dmg, 40.0, false, col, extra)
			main.sfx("burn", 1.2, -6.0)
		"field":
			_field(p, b, fx, p.global_position, power, col)
		"surge":
			b.surge_until = Time.get_ticks_msec() + int(float(fx.get("seconds", 6.0)) * 1000.0)
			b.surge_power = float(fx.get("power", 0.25))
			main.fx_text(p.global_position + Vector2(0, -64), Ascent.WORDS["surge"], col.lightened(0.3))
			main.light_flash(p.global_position, col, 1.2, 1.2, 0.3)
		"shield":
			p.raise_barrier(float(fx.get("amount", 10.0)) * power, float(fx.get("seconds", 3.0)), false, col)
			main.fx_ring(p.global_position, col.lightened(0.3), 34.0, 0.3, 2.5)
		"heal":
			if fx.has("below") and p.hp >= p.max_health() * float(fx["below"]):
				return
			var amt := float(fx.get("amount", 0.0)) + float(fx.get("per_graft", 0.0)) * float(_grafts(main))
			if amt > 0.0:
				p.mend_by(amt * p.heal_mult())
		"kin":
			_kin(p, b, fx, col)


## Casts a bond's spell again (an echo): the same spell, the same way the
## mark casts it (a Transformation's own way), at `pw`, unpaid and unheard
## by these effects (no echo of an echo).
static func _cast_again(b, p, sel: int, sid: String, pw: float) -> void:
	var now: int = b.selected
	b.selected = sel
	var sp: Dictionary = b.spell()
	if String(sp.get("id", "")) != sid:
		b.selected = now
		return
	b.var_power = pw
	var kind: String = load("res://scripts/bond.gd").HIT_KINDS.get(b.id, "")
	if kind != "":
		p.main.hit_kind = kind
	var alt: Dictionary = b.alt_change() if b.is_changed_spell(sp) else {}
	if not alt.is_empty():
		Library.cast_mark_variation(b, sp, p, alt)
	elif not (int(b.step) >= 3 and b.is_changed_spell(sp) and Library.cast_mark_change(b, sp, p)):
		b._cast_type(p)
	if kind != "":
		p.main.hit_kind = ""
	b.var_power = 1.0
	b.selected = now
	p.main.fx_ring(p.global_position, b.color().lightened(0.25), 26.0, 0.25, 2.0)


static func _grafts(main) -> int:
	var g = main.get("grafts")
	return g.size() if g is Dictionary or g is Array else 0


## The foes within `r` of a point.
static func _near(main, at: Vector2, r: float) -> Array:
	var out: Array = []
	for e in main.targets():
		if is_instance_valid(e) and not e.dead and e.global_position.distance_to(at) <= r + float(e.radius):
			out.append(e)
	return out


## A state on a foe, as the effect says ("stagger" is a stagger, halved for a beast).
static func _state(main, e, b, fx: Dictionary, state: String) -> void:
	if state == "" or not is_instance_valid(e) or e.dead:
		return
	if state == "drained":
		Reactions.apply(main, e, "drained", 0.0, b)
		return
	Reactions.apply(main, e, state, float(fx.get("seconds", 0.0)), b, float(fx.get("amount", 0.0)))


static func _hit(main, e, b, fx: Dictionary, dmg: float, dir: Vector2, force: float) -> void:
	if not is_instance_valid(e) or e.dead:
		return
	if dmg > 0.0 or force > 0.0:
		e.take_hit(dmg, dir, force)
	if not is_instance_valid(e) or e.dead:
		return
	if float(fx.get("stagger", 0.0)) > 0.0:
		e.stagger(float(fx["stagger"]) * (0.5 if e.is_boss() else 1.0))
	_state(main, e, b, fx, String(fx.get("state", "")))
	if String(fx.get("also", "")) != "" and is_instance_valid(e) and not e.dead:
		_state(main, e, b, fx, String(fx["also"]))


# --- a burst around you ----------------------------------------------------------------------

static func _nova(p, b, fx: Dictionary, at: Vector2, power: float, col: Color) -> void:
	var main = p.main
	var r := float(fx.get("radius", 120.0))
	var base := (float(fx.get("damage", 0.0)) + float(fx.get("per_graft", 0.0)) * float(_grafts(main))) * power
	var caught := 0
	for e in _near(main, at, r):
		var dir: Vector2 = (e.global_position - at).normalized()
		var dmg := base
		if fx.has("rich_at") and int(e.get("venom")) >= int(fx["rich_at"]):
			dmg += float(fx.get("rich_damage", 0.0)) * power
		var force := 0.0
		if float(fx.get("push", 0.0)) > 0.0:
			force = float(fx["push"])
		elif float(fx.get("pull", 0.0)) > 0.0:
			dir = -dir
			force = float(fx["pull"])
		_hit(main, e, b, fx, dmg, dir, force)
		caught += 1
	if float(fx.get("heal_per", 0.0)) > 0.0 and caught > 0:
		p.mend_by(float(fx["heal_per"]) * float(mini(caught, int(fx.get("heal_most", 99)))) * p.heal_mult())
	_ring(main, at, r, col, String(fx.get("look", "")))
	main.sfx("burn" if String(fx.get("state", "")) == "burning" else "gust", 0.9, -6.0)


## A ring rushing out over the ground, with a soft glow (wings: two burning
## wings beat out to your sides).
static func _ring(main, at: Vector2, r: float, col: Color, look: String) -> void:
	main.light_flash(at, col, 1.0 + r / 160.0, 1.2, 0.3)
	var dur: float = LOOK["ring"]
	var paint := func(bt, it):
		var k := clampf(float(it["age"]) / dur, 0.0, 1.0)
		var a := 1.0 - k
		bt.soft(at, Vector2(r, r * 0.8) * (0.4 + 0.6 * k), Color(col, 0.28 * a))
		var n := 14
		for i in n:
			var ang := TAU * float(i) / float(n) + k * 0.6
			var pt := at + Vector2.from_angle(ang) * r * (0.35 + 0.65 * k)
			bt.disc(pt, 3.2 * a + 1.0, Color(col.lightened(0.25), a))
		if look == "wings":
			for s in [-1.0, 1.0]:
				var root := at + Vector2(10.0 * s, -6.0)
				var tip := at + Vector2(r * 0.8 * s, -r * 0.35) * (0.5 + 0.5 * k)
				var low := at + Vector2(r * 0.55 * s, r * 0.15) * (0.5 + 0.5 * k)
				bt.poly(PackedVector2Array([root, tip, low]), Color(col.lightened(0.15), 0.85 * a), 1.2)
	SpellFx.item(main, dur, Callable(), paint, true)


# --- hits on the nearest foes ----------------------------------------------------------------

static func _strike(p, b, fx: Dictionary, power: float, col: Color) -> void:
	var main = p.main
	var from: Vector2 = p.global_position
	var foes := _near(main, from, float(fx.get("range", 300.0)))
	if bool(fx.get("skip_aim", false)) and b.has_method("target_in_aim"):
		var aimed = b.target_in_aim(p, float(fx.get("range", 300.0)))
		foes.erase(aimed)
	foes.sort_custom(func(x, y): return x.global_position.distance_squared_to(from) < y.global_position.distance_squared_to(from))
	if String(fx.get("prefer", "")) == "quarry":
		var q = p.get("quarry")
		if q != null and is_instance_valid(q) and q in foes:
			foes.erase(q)
			foes.push_front(q)
	var dmg := float(fx.get("damage", 0.0)) * power
	var healed := 0.0
	var look := String(fx.get("look", ""))
	for e in foes.slice(0, int(fx.get("count", 1))):
		var at: Vector2 = e.global_position
		if look == "bolt":
			main.fx_bolt([at + Vector2(randf_range(-24.0, 24.0), -220.0), at + Vector2(0, -36.0), at], col)
		else:
			_streak(main, from, at, col, look)
		_hit(main, e, b, fx, dmg, (at - from).normalized(), 40.0 if dmg > 0.0 else 0.0)
		healed += dmg * float(fx.get("drain", 0.0)) + float(fx.get("heal_per", 0.0))
	if healed > 0.0:
		p.mend_by(healed * p.heal_mult())
	if not foes.is_empty():
		main.sfx("thunder" if look == "bolt" else "zap", 1.5, -8.0)


## A quick shaded streak from you to a foe (an arrow, a spit, a cut, a drain).
static func _streak(main, from: Vector2, to: Vector2, col: Color, look: String) -> void:
	var dur: float = LOOK["streak"]
	var back := look == "drain"
	var paint := func(bt, it):
		var k := clampf(float(it["age"]) / dur, 0.0, 1.0)
		var a: Vector2 = to if back else from
		var z: Vector2 = from if back else to
		var head := a.lerp(z, k)
		var tail := a.lerp(z, maxf(0.0, k - 0.35))
		bt.stroke(tail, head, Color(col, 0.9 * (1.0 - k * 0.5)), 3.0 if look != "cut" else 2.0)
		bt.disc(head, 3.6, col.lightened(0.35))
	SpellFx.item(main, dur, Callable(), paint, true)


# --- a burst where you aim, after a warning ---------------------------------------------------

## A flat ring that closes in on the spot (every warning is flat), with a
## shaded ember at its heart.
static func _warn(main, at: Vector2, r: float, delay: float, col: Color) -> void:
	var paint := func(bt, it):
		var k := clampf(float(it["age"]) / maxf(delay, 0.05), 0.0, 1.0)
		bt.arc(at, r, 0.0, TAU, 40, Color(col, 0.35 + 0.5 * k), LOOK["warn_width"])
		bt.arc(at, r * (1.0 - 0.8 * k), 0.0, TAU, 32, Color(col.lightened(0.3), 0.6), 1.5)
		bt.soft(at, Vector2(r, r * 0.8), Color(col, 0.12 + 0.12 * k))
		bt.disc(at + Vector2(0, -60.0 * (1.0 - k)), 5.0 + 3.0 * k, col.lightened(0.2))
	SpellFx.item(main, delay, Callable(), paint, false)


static func _burst_at(p, b, fx: Dictionary, at: Vector2, r: float, power: float, col: Color) -> void:
	var main = p.main
	var dmg := float(fx.get("damage", 10.0)) * power
	for e in _near(main, at, r):
		_hit(main, e, b, fx, dmg, (e.global_position - at).normalized(), 120.0)
	main.fx_ring(at, col, r, 0.35, 4.0)
	main.fx_burst(at, Vector2.ZERO, col, 14, 220.0)
	main.light_flash(at, col, 1.4, 1.6, 0.35)
	main.shake(3.0)
	main.sfx_at(at, "explode" if String(fx.get("state", "")) == "burning" else "hit_heavy", 1.1, -4.0)
	_ring(main, at, r, col, "")


# --- blades circling you -----------------------------------------------------------------------

static func _orbit(p, b, fx: Dictionary, power: float, col: Color) -> void:
	var main = p.main
	var n := int(fx.get("count", 3))
	var r := float(fx.get("radius", 58.0))
	var tick := float(fx.get("tick", 0.5))
	var dmg := float(fx.get("damage", 4.0)) * power
	var st := {"next": 0.0, "spin": 0.0}
	var blades := func(it) -> Array:
		var out: Array = []
		if not is_instance_valid(p):
			return out
		for i in n:
			out.append(p.global_position + Vector2.from_angle(float(st["spin"]) + TAU * float(i) / float(n)) * r)
		return out
	var step := func(it, delta: float):
		if not is_instance_valid(p) or p.dead:
			it["done"] = true
			return
		st["spin"] = float(st["spin"]) + delta * 6.0
		st["next"] = float(st["next"]) - delta
		if float(st["next"]) > 0.0:
			return
		st["next"] = tick
		var pts: Array = blades.call(it)
		for e in main.targets():
			if not is_instance_valid(e) or e.dead:
				continue
			for pt in pts:
				if e.global_position.distance_to(pt) <= float(e.radius) + 14.0:
					_hit(main, e, b, fx, dmg, (e.global_position - p.global_position).normalized(), 50.0)
					break
	var paint := func(bt, it):
		var pts: Array = blades.call(it)
		var L: float = LOOK["blade_len"]
		for i in pts.size():
			var pt: Vector2 = pts[i]
			var along := Vector2.from_angle(float(st["spin"]) + TAU * float(i) / float(n) + PI * 0.5)
			var side := along.orthogonal() * 3.0
			bt.poly(PackedVector2Array([pt - along * L * 0.5 - side, pt + along * L, pt - along * L * 0.5 + side]), col.lightened(0.2), 1.2)
			bt.disc(pt - along * L * 0.5, 2.4, col.darkened(0.2))
	SpellFx.item(main, float(fx.get("seconds", 4.0)), step, paint, true)


# --- a rune circle on the floor ----------------------------------------------------------------

static func _field(p, b, fx: Dictionary, at: Vector2, power: float, col: Color) -> void:
	var main = p.main
	var r := float(fx.get("radius", 70.0))
	var tick := float(fx.get("tick", 0.5))
	var dmg := float(fx.get("damage", 5.0)) * power
	var st := {"next": tick * 0.5}
	var step := func(it, delta: float):
		if not is_instance_valid(main):
			it["done"] = true
			return
		st["next"] = float(st["next"]) - delta
		if float(st["next"]) > 0.0:
			return
		st["next"] = tick
		for e in _near(main, at, r):
			_hit(main, e, b, fx, dmg, Vector2.ZERO, 0.0)
	var paint := func(bt, it):
		var a := clampf(float(it["t"]) / 0.4, 0.0, 1.0) * clampf(float(it["age"]) / 0.2, 0.0, 1.0)
		bt.soft(at, Vector2(r, r * 0.75), Color(col, 0.2 * a))
		bt.arc(at, r, 0.0, TAU, 36, Color(col, 0.7 * a), 2.0)
		for i in 6:
			var ang := TAU * float(i) / 6.0 + float(it["age"]) * 0.8
			bt.disc(at + Vector2.from_angle(ang) * r * 0.78, 3.0, Color(col.lightened(0.3), a))
	SpellFx.item(main, float(fx.get("seconds", 3.0)), step, paint, false)


# --- a spirit creature --------------------------------------------------------------------------

static func _kin(p, b, fx: Dictionary, col: Color) -> void:
	var main = p.main
	var allies: Array = main.allies() if main.has_method("allies") else []
	if allies.size() < int(load("res://scripts/bond.gd").MAX_OUT):
		var stay: float = b._stay() if b.has_method("_stay") else 1.0
		main.spawn_ally(String(fx.get("creature", "familiar")), p.global_position - p.aim * 40.0, b.ally_step(), float(fx.get("seconds", 10.0)) * stay)
		main.fx_text(p.global_position + Vector2(0, -60), Ascent.WORDS["kin"], col.lightened(0.3))
		return
	for a in allies:
		if is_instance_valid(a) and not a.dead:
			a.hp = minf(a.max_hp, a.hp + a.max_hp * float(fx.get("heal", 0.17)))
			main.fx_ring(a.global_position, col, 24.0, 0.3, 2.0)


# --- the Zenith's sign ---------------------------------------------------------------------------

## A small crown of light over the climber as the Zenith answers a cast.
static func _crown(main, p, col: Color) -> void:
	var dur: float = LOOK["crown"]
	var paint := func(bt, it):
		if not is_instance_valid(p):
			return
		var k := clampf(float(it["age"]) / dur, 0.0, 1.0)
		var a := 1.0 - k * k
		var c: Vector2 = p.global_position + Vector2(0, -38.0 - 10.0 * k)
		bt.soft(c, Vector2(16, 12), Color(col, 0.3 * a))
		var pts := PackedVector2Array()
		for i in 10:
			var rr := 9.0 if i % 2 == 0 else 4.0
			pts.append(c + Vector2.from_angle(-PI * 0.5 + TAU * float(i) / 10.0) * rr)
		bt.poly(pts, Color(col.lightened(0.35), a), 1.0)
		bt.disc(c, 2.5, Color(1, 1, 1, 0.8 * a))
	SpellFx.item(main, dur, Callable(), paint, true)
