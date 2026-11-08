extends RefCounted
## What falling costs, and finding lost things again.
##
## Fall in the tower (not on the bondless first climb, which ends in the
## Regard) and your pack and your belt are lost, and sometimes the weapon in
## your hand too. Heirlooms are never lost. The lost pieces are remembered
## in your profile (profile.gd `lost`, the last KEEP of them, with the tower
## and floor where they fell). On a later climb of that tower, a floor near
## where they fell may hold a **lost cache**: a fallen pack with a broken
## strap, lit faintly, in an ordinary room. Walk onto it and your things come
## back (into your pack if there's room, else at your feet).
##
## Names, words and numbers live here so they're easy to change.

const Gear := preload("res://scripts/gear.gd")
const Palette := preload("res://scripts/palette.gd")
const Rooms := preload("res://scripts/rooms.gd")
const Themes := preload("res://scripts/themes.gd")

## The chance a fall also takes the weapon in your hand (the melee weapon
## if you held only your fists). The starting sword and bow are never
## counted: every climb starts with them.
const WEAPON_CHANCE := 0.35
## Heirlooms are kept safe: an heirloom in your hand is never lost. Set this
## true to let a fall take an heirloom weapon too (it leaves your heirlooms,
## and may be found again like anything else lost).
const HEIRLOOM_WEAPON := false
## How many lost pieces are remembered (the oldest are forgotten first).
const KEEP := 6
## On each floor of rooms of a tower, the chance of a lost cache, when that
## tower holds lost pieces that fell within NEAR floors of it.
const CACHE_CHANCE := 0.25
const NEAR := 2
## At most this many pieces lie in one cache (those lost nearest first).
const CACHE_MAX := 3
## Walk this close to the cache to take it.
const REACH := 26.0
## Rooms a cache may lie in (their theme's feature): ordinary rooms, never a
## puzzle hall, a wing, a trap room, a chasm room or a good room's feature.
const ROOM_FEATURES := ["", "pillars", "den", "ambush"]
## If none of those has space, these will do.
const FALLBACK_FEATURES := ["start", "stair"]
## Its faint light: [reach, strength, glow].
const LIGHT := [120.0, 0.5, 0.1]
const LIGHT_COLOR := Color(0.72, 0.78, 1.0)

const TEXT := {
	"lost": "Lost on the way down: %s",
	"pack": "your pack (%d %s)",
	"belt": "your belt",
	"weapon": "your %s",
	"join": ", ",
	"may_return": "What you lost may turn up again, on a later climb of this tower.",
	"name": "Your lost things",
	"found": "Found again: %s",
	"at_feet": "No room in your pack: %s left at your feet",
	# The fall screen, after the Regard: [keys, controller, touch] for going now.
	"fell": "YOU FELL ON FLOOR %d",
	"back": "Best: floor %d.  Back to the train in %d",
	"now": ["Press Enter or R to go now", "Press {a} or {back} to go now", "Tap to go now"],
}


## A fall: what it takes. `p` is the climber, `profile` the profile.
## Records the lost pieces in profile.lost (capped at KEEP) and returns
## {"pack": count, "belt": bool, "weapon": record or {}, "lines": [...]}.
## The climber's own lists are left as they are (the climb is over).
## `weapon_roll` is the chance the weapon in hand goes too.
static func fall(profile, p, tower: String, floor_num: int, weapon_roll := WEAPON_CHANCE) -> Dictionary:
	var out := {"pack": 0, "belt": false, "weapon": {}, "lines": []}
	if p == null:
		return out
	var pieces: Array = []
	for g in p.pack:
		var r := Gear.rec(g)
		if not r.is_empty():
			pieces.append(r)
	out["pack"] = pieces.size()
	out["belt"] = not p.carried().is_empty()
	var w := hand_weapon(p)
	if not w.is_empty() and randf() < weapon_roll:
		var hs := Gear.heirloom_slot(w)
		var is_heir := Gear.heirloom_pieces(profile.heirlooms, hs).any(func(h): return Gear.same(h, w))
		if is_heir and HEIRLOOM_WEAPON:
			profile.heirlooms.erase(hs)
		if not is_heir or HEIRLOOM_WEAPON:
			out["weapon"] = w
			pieces.append(Gear.heirloom_copy(w) if is_heir else w)
	remember(profile, pieces, tower, floor_num)
	var said: Array = []
	if out["pack"] > 0:
		said.append(TEXT["pack"] % [out["pack"], "piece" if out["pack"] == 1 else "pieces"])
	if out["belt"]:
		said.append(TEXT["belt"])
	if not out["weapon"].is_empty():
		said.append(TEXT["weapon"] % Gear.display(out["weapon"]))
	if not said.is_empty():
		out["lines"].append(TEXT["lost"] % String(TEXT["join"]).join(said))
	if not pieces.is_empty():
		out["lines"].append(TEXT["may_return"])
	return out


## The weapon a fall may take: the one in hand, or the melee weapon if your
## fists are out. {} for none, or for the starting sword or bow.
static func hand_weapon(p) -> Dictionary:
	var slot := ""
	for s in ["melee", "ranged"]:
		if p.weapon != "fists" and p.gear_id(s) == p.weapon:
			slot = s
	if slot == "" and p.weapon == "fists":
		slot = "melee"
	if slot == "":
		return {}
	var r := Gear.rec(p.gear.get(slot, {}))
	if r.is_empty():
		return {}
	for start in [Gear.Weapons.START_MELEE, Gear.Weapons.START_RANGED]:
		if Gear.same(r, Gear.make(start)):
			return {}
	return r


## Remembers lost pieces (the newest last; only the last KEEP are kept).
static func remember(profile, pieces: Array, tower: String, floor_num: int) -> void:
	for r in pieces:
		profile.lost.append({"rec": Gear.rec(r), "tower": tower, "floor": floor_num})
	if profile.lost.size() > KEEP:
		profile.lost = profile.lost.slice(profile.lost.size() - KEEP)


## The lost pieces a cache on this floor of this tower would hold (those
## lost nearest this floor first, at most CACHE_MAX), or [] for none.
static func for_floor(profile, tower: String, floor_num: int) -> Array:
	var near: Array = profile.lost.filter(func(e): return String(e["tower"]) == tower and absi(int(e["floor"]) - floor_num) <= NEAR)
	near.sort_custom(func(a, b): return absi(int(a["floor"]) - floor_num) < absi(int(b["floor"]) - floor_num))
	return near.slice(0, CACHE_MAX)


## Forgets lost pieces once found (each entry the first that matches).
static func forget(profile, entries: Array) -> void:
	for e in entries:
		for i in profile.lost.size():
			var l: Dictionary = profile.lost[i]
			if String(l["tower"]) == String(e["tower"]) and int(l["floor"]) == int(e["floor"]) and Gear.same(l["rec"], e["rec"]):
				profile.lost.remove_at(i)
				break


## Lost entries from a save (broken ones are dropped; old saves have none).
static func load_list(raw) -> Array:
	var out: Array = []
	if raw is Array:
		for e in raw:
			if e is Dictionary:
				var r := Gear.rec(e.get("rec", {}))
				if not r.is_empty():
					out.append({"rec": r, "tower": String(e.get("tower", "")), "floor": int(e.get("floor", 1))})
	return out.slice(maxi(0, out.size() - KEEP))


## Where a cache can lie on a floor of rooms (floors.gd plan): the middle of
## a clear 3x3 patch of floor in an ordinary room, clear of doorways, keys
## and levers. Vector2.INF if there's nowhere.
static func spot(plan: Dictionary) -> Vector2:
	var infos: Array = plan.get("room_info", [])
	var themes: Array = plan.get("themes", [])
	if infos.is_empty():
		return Vector2.INF
	var cell := 40.0
	var keep_clear: Array = []
	for d in plan.get("doorways", []):
		keep_clear.append(d.get_center())
	for l in plan.get("locks", []):
		if l.has("pos"):
			keep_clear.append(l["pos"])
	keep_clear.append(plan.get("stair", Vector2.INF))
	keep_clear.append(plan.get("start", Vector2.INF))
	for feats in [ROOM_FEATURES, FALLBACK_FEATURES]:
		var spots: Array = []
		for i in infos.size():
			var info: Dictionary = infos[i]
			var theme: String = themes[i] if i < themes.size() else String(info.get("theme", ""))
			if info.get("role", "") == "gallery" or not (String(Themes.get_theme(theme)["feature"]) in feats):
				continue
			var rows: Array = info["rows"]
			var h := rows.size()
			var w := String(rows[0]).length()
			for y in range(1, h - 3):
				for x in range(1, w - 3):
					var ok := true
					for dy in 3:
						for dx in 3:
							ok = ok and String(rows[y + dy])[x + dx] == "."
					if not ok:
						continue
					var pos: Vector2 = info["rect"].position + (Vector2(x, y) + Vector2(1.5, 1.5)) * cell
					if keep_clear.all(func(k): return k == Vector2.INF or pos.distance_to(k) > cell * 2.0):
						spots.append(pos)
		if not spots.is_empty():
			return spots[randi() % spots.size()]
	return Vector2.INF


## Draws a lost cache: a fallen pack with a broken strap and a blade poking
## out, under a faint pale glimmer (dark and empty once taken).
static func draw(c: CanvasItem, pos: Vector2, t: float, taken: bool) -> void:
	var leather := Color(0.40, 0.27, 0.17) if not taken else Color(0.24, 0.18, 0.14)
	var strap := leather.darkened(0.3)
	# Its shadow.
	c.draw_set_transform(pos + Vector2(2, 10), 0.0, Vector2(1.0, 0.42))
	c.draw_circle(Vector2.ZERO, 24.0, Color(0, 0, 0, 0.4))
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if not taken:
		var pulse := 0.5 + 0.5 * sin(t * 1.6)
		c.draw_circle(pos, 30.0 + pulse * 4.0, Color(LIGHT_COLOR, 0.06 + 0.05 * pulse))
		c.draw_circle(pos, 18.0, Color(LIGHT_COLOR, 0.06 + 0.04 * pulse))
	# The broken strap: one end still on the pack, the torn end lying apart.
	var s0 := pos + Vector2(10, 4)
	c.draw_polyline(PackedVector2Array([s0, s0 + Vector2(8, 6), s0 + Vector2(15, 7)]), Palette.OUTLINE, 5.0)
	c.draw_polyline(PackedVector2Array([s0, s0 + Vector2(8, 6), s0 + Vector2(15, 7)]), strap, 3.0)
	var s1 := pos + Vector2(-26, 12)
	c.draw_polyline(PackedVector2Array([s1, s1 + Vector2(7, -3), s1 + Vector2(14, -1)]), Palette.OUTLINE, 5.0)
	c.draw_polyline(PackedVector2Array([s1, s1 + Vector2(7, -3), s1 + Vector2(14, -1)]), strap, 3.0)
	for k in 3:  # frayed ends
		var e0 := s0 + Vector2(15, 7)
		c.draw_line(e0, e0 + Vector2(3, -2 + k * 2), strap.lightened(0.15), 1.0)
		var e1 := s1 + Vector2(14, -1)
		c.draw_line(e1, e1 + Vector2(3, -2 + k * 2), strap.lightened(0.15), 1.0)
	# A blade poking out from under the flap.
	if not taken:
		var a := pos + Vector2(-4, -6)
		var b := pos + Vector2(-20, -18)
		c.draw_line(a, b, Palette.OUTLINE, 5.0)
		c.draw_line(a, b, Palette.STEEL.darkened(0.25), 3.0)
		c.draw_line(a.lerp(b, 0.15), b, Color(1, 1, 1, 0.35), 1.0)
	# The pack, fallen on its side.
	var body := PackedVector2Array()
	var squash := 1.0 if not taken else 0.6
	for i in 16:
		var ang := TAU * i / 16.0
		var v := Vector2(cos(ang) * 15.0, sin(ang) * 11.0 * squash)
		v.x += signf(v.x) * 2.0  # (squarer than an egg)
		body.append(pos + v.rotated(-0.3))
	var rim := PackedVector2Array()
	for v in body:
		rim.append(pos + (v - pos) * 1.12)
	c.draw_colored_polygon(rim, Palette.OUTLINE)
	c.draw_colored_polygon(body, leather)
	c.draw_circle(pos + Vector2(-5, -3).rotated(-0.3), 6.0, Color(leather.lightened(0.12), 0.8))
	# Its flap, hanging open, and a dull buckle.
	var flap := PackedVector2Array([pos + Vector2(-12, -4), pos + Vector2(4, -10), pos + Vector2(8, 0), pos + Vector2(-8, 4)])
	for i in flap.size():
		flap[i] = pos + (flap[i] - pos).rotated(-0.3)
	c.draw_colored_polygon(flap, leather.darkened(0.18))
	c.draw_polyline(PackedVector2Array([flap[0], flap[1], flap[2], flap[3], flap[0]]), Palette.OUTLINE, 1.2)
	var buckle := pos + Vector2(4, 2).rotated(-0.3)
	c.draw_rect(Rect2(buckle - Vector2(2.5, 2.5), Vector2(5, 5)), Color(0.62, 0.52, 0.3) if not taken else Color(0.32, 0.28, 0.22), false, 1.5)
	if taken:
		return
	# A few motes drifting up, slowly.
	for i in 3:
		var k := fmod(t * 0.35 + i / 3.0, 1.0)
		c.draw_circle(pos + Vector2(sin(t * 1.4 + i * 2.1) * 8.0 - 4.0 + i * 4.0, -8.0 - k * 26.0), 1.8 * (1.0 - k) + 0.4, Color(LIGHT_COLOR, 0.7 * (1.0 - k)))
