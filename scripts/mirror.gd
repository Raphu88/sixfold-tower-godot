extends "res://scripts/enemy.gd"
## THE MIRROR IMAGE: the Regard turns the climber's own likeness on them.
## Now and then a floor holds a MIRROR ROOM (ROOM below; floors.gd asks
## pick_room): an optional branch room off the main route, a hall of
## silvered glass (draw_glass) behind a door bearing a mirror (draw_door).
## Walk in and a mirror image steps out of the glass (enter_room); the
## doors shut behind you (doors.gd LOCK_IN "mirror") until it falls.
##
## It is built from the climber as they are when they walk in (copy_from):
##   the weapon in hand  its swing chain (reach, arcs, the heavy finisher)
##                       or its bow or crossbow, at STATS's damage
##   armor               the climber's protection takes the edge off your blows
##   marks               drawn on its body; up to SPELL["max"] of their bonds
##                       give it a spell (BOND_SHAPE: a volley, a blast, a
##                       cone or a nova, named after the bond's first spell)
##   rolls and guards    like you: now and then it rolls clear of a blow
##                       (ROLL), and after an attack it may raise its guard
##                       (GUARD, a silver arc): light blows from the front are
##                       turned aside; a finisher or a blow from behind isn't
## Every attack keeps the game's rhythm: a wind-up with its telegraph (the
## red cone, line, circle or ring), the glint a quarter second before it
## lands, then a recovery where it is open.
##
## It is a great foe: secret.gd's "mirror" drop (mostly Unmaking) rises
## through main.secret_drop (the path choice, the first time), and it
## leaves PRIZE (like a sealed wing's champion: a crystal, sometimes gear).
## Every word and number is here, to rename or retune freely.

const Weapons := preload("res://scripts/weapons.gd")
const Towers := preload("res://scripts/towers.gd")
const Appearance := preload("res://scripts/appearance.gd")
const GearLook := preload("res://scripts/gear_look.gd")

## Which floors may hold a mirror room: from floor `from`, `chance` of them;
## never the Proving's floor, the summit, floor 1 or the bondless first climb.
static var ROOM := {"from": 4, "chance": 1.0 / 6.0}
## The room's theme id (themes.gd).
const THEME := "mirror"

## Its body. hp and dmg grow with the floor (floors.gd toughness).
##   hp          a mini-boss: a few monsters' worth, below a champion or beast
##   melee       its swings deal the climber's weapon damage times this
##   shot        its arrows deal the bow's full draw times this...
##   shot_speed  ...and fly at this share of the bow's speed (at most shot_max)
##   armor       share of the climber's protection it wears
##   emerge      seconds it takes to step out of the glass
const STATS := {"hp": 140.0, "speed": 118.0, "radius": 14.0, "weight": 2.5, "melee": 1.3, "shot": 0.75,
	"shot_speed": 0.6, "shot_max": 460.0, "armor": 1.0, "emerge": 1.4, "knock": 0.5}
## A swing chain: the first wind-up, each further link's, how many links at
## most, the recovery after (open), and how far inside its reach it starts.
const SWING := {"first": 0.62, "link": 0.42, "links": 3, "recover": 0.95, "inside": 6.0}
## A shot: the shortest draw, when its aim locks (seconds before it looses),
## the recovery after, a crossbow's longer one, and the distance it keeps.
const SHOT := {"draw_min": 0.8, "lock": 0.4, "recover": [1.3, 1.9], "crossbow": 2.3, "keep": [150.0, 260.0]}
## Rolling clear of a blow: the chance a blow from the front misses, how
## often at most, how long the roll lasts and how fast.
const ROLL := {"chance": 0.3, "every": 3.0, "time": 0.26, "speed": 330.0}
## Its guard: the chance it raises it after an attack, and for how long.
const GUARD := {"chance": 0.45, "time": 0.95, "push": 220.0, "open": 0.45}
## Spells: the first after this long, then every so often; at most `max`
## of the climber's bonds; base damage, and more for each step of the bond.
const SPELL := {"first": 3.0, "every": [6.5, 8.5], "max": 2, "dmg": 13.0, "per_step": 0.12, "recover": 1.1}
##   volley  a fan of bolts at you (roll through, or parry them back)
##   blast   a circle where you stand, locked `lock` seconds before it bursts
##   cone    a cone in front of it that throws you back
##   nova    a ring around it that throws you back
const SHAPES := {
	"volley": {"wind": 0.85, "count": 3, "spread": 14.0, "speed": 300.0, "range": 340.0, "dmg": 0.6},
	"blast": {"wind": 1.0, "lock": 0.5, "r": 52.0, "range": 300.0, "dmg": 1.0},
	"cone": {"wind": 0.8, "lock": 0.35, "reach": 125.0, "arc": 38.0, "range": 135.0, "dmg": 0.9, "push": 320.0},
	"nova": {"wind": 0.95, "r": 95.0, "range": 105.0, "dmg": 0.9, "push": 260.0},
}
const BOND_SHAPE := {
	"stormcaller": "blast", "windwalker": "cone", "hunter": "volley",
	"tidecaller": "cone", "warden": "nova", "deepcaller": "blast",
	"blade_forger": "volley", "flameblade": "cone", "rune_artist": "blast",
	"sandshaper": "blast", "venomist": "volley", "ashwalker": "nova",
	"flame_contractor": "blast", "flamewing": "nova", "rekindler": "nova",
	"covenant": "volley", "grafter": "cone", "surgeon": "cone",
}
const POISON := {"venomist": 3.0}  # seconds of poison its bolts give
## What it leaves (besides its secret essence): a crystal of the tower's
## essence worth this share of a vault's (a champion's is half), and
## sometimes a piece of gear a rarity row higher than the floor's.
static var PRIZE := {"crystal": 0.5, "gear": 0.25}
## The glass look: shades from dark to light that every colour of the
## climber is pulled toward (keeping `keep` of its own), its see-through-ness,
## the shimmer that sweeps across it, and the guard's arc.
const LOOK := {"dark": Color(0.1, 0.12, 0.19), "mid": Color(0.45, 0.53, 0.66), "light": Color(0.88, 0.94, 1.0),
	"keep": 0.22, "alpha": 0.92, "ghost": Color(0.55, 0.85, 1.0, 0.22), "shimmer": 0.55, "rim": Color(0.75, 0.88, 1.0),
	"guard": Color(0.85, 0.93, 1.0), "glow": Color(0.62, 0.78, 1.0)}
static var TEXT := {
	"name": "Mirror image",
	"emerge": "It steps out of the glass",
	"dodged": "Dodged",
	"turned": "Turned aside",
	"shatter": "The reflection shatters",
	"crystal": "+ %s (%d)",
	"forced": "The next floor will hold a mirror room",
}

## Dev tools: the next floor that can hold one holds a mirror room (main.gd clears it
## once one is planned). `climb_ok` is false on the bondless first climb
## (main.gd sets it before planning a floor).
static var force := false
static var climb_ok := true

var w_id := "fists"
var wd := {}
var ranged := false
var chain: Array = []  # the weapon's swings (at most SWING["links"])
var link := 0
var wind_dur := 0.6
var armor := 0.0
var look := {}  # the climber's colours and the worn pieces that show
var armor_id := ""
var marks: Array = []  # [part, colour, step]
var spells: Array = []  # {bond, name, shape, color, step}
var spell_i := 0
var spell_t := 0.0
var spell_spot := Vector2.ZERO
var roll_cd := 0.0
var roll_dir := Vector2.ZERO
var swing_anim := 0.0  # a swing playing out (drawing)
var swing_side := 1.0
var swing_heavy := false
var _prized := false
var _light := -1
var _last := Draw.Batch.new()  # its body as last drawn (left behind as it shatters)
var _phase := 0.0  # walk cycle (drawing)


# --- where it appears --------------------------------------------------------------

## Whether a floor gets a mirror room (rolled once a floor; `force_it` skips
## the roll and the lowest floor, never the rest).
static func wants_room(floor_num: int, first_climb: bool, force_it := false) -> bool:
	if floor_num <= 1 or floor_num == int(Towers.PROVING["floor"]) or floor_num >= int(Towers.SUMMIT):
		return false
	if force_it:
		return true
	if first_climb or floor_num < int(ROOM["from"]):
		return false
	return randf() < float(ROOM["chance"])


## floors.gd: the room (index into `infos`) that becomes this floor's mirror
## room, or -1: a branch room (never on the way to the stair), chosen before
## the other rooms' themes are handed out (themes.gd keeps it fixed).
static func pick_room(infos: Array, floor_num: int) -> int:
	if not wants_room(floor_num, not climb_ok, force):
		return -1
	var opts: Array = []
	for i in infos.size():
		if infos[i]["role"] == "branch":
			opts.append(i)
	return opts[randi() % opts.size()] if not opts.is_empty() else -1


## main.gd: the climber walked into a mirror room: its image steps out of
## the glass in the middle of the room (the doors shut once they're inside).
static func enter_room(main, i: int):
	var rect: Rect2 = main.room_info[i]["rect"]
	var e = spawn(main, rect.get_center())
	main.floor_total += 1
	main.tip("mirror")
	return e


## A mirror image of the climber near `pos` (the room, and the dev tool).
static func spawn(main, pos: Vector2):
	var e = load("res://scripts/mirror.gd").new()
	e.setup_mirror(main, main.player)
	# Clear of walls, pillars and the others.
	var at: Vector2 = pos
	for ring in 8:
		var q: Vector2 = pos + Vector2.from_angle(ring * 2.1) * ring * 18.0
		if main.pillars.all(func(pl): return q.distance_to(pl["pos"]) > float(pl["r"]) + e.radius + 4.0) and not main.is_solid(q):
			at = q
			break
	e.position = main.clear_spot(at, e.radius, main.enemies().map(func(o): return o.global_position))
	if main.player != null:
		e.face = (main.player.global_position - e.position).normalized()
	main.add_child(e)
	var col: Color = LOOK["light"]
	main.fx_burst(e.position, Vector2.UP, col, 18, 160.0)
	main.fx_ring(e.position, col, 46.0, 0.45, 3.0)
	main.light_flash(e.position, LOOK["glow"], 1.4, 1.4, 0.5)
	main.fx_text(e.position + Vector2(0, -44), TEXT["emerge"], col)
	main.sfx("glint", 0.7, -2.0, 0.0)
	return e


# --- built from the climber -----------------------------------------------------

## Call before adding it to the room.
func setup_mirror(room, pl) -> void:
	main = room
	kind = "mirror"
	mirror = true
	var tough: Vector2 = main.Floors.toughness(main.floor_num)
	max_hp = float(STATS["hp"]) * tough.x
	hp = max_hp
	radius = float(STATS["radius"])
	speed = float(STATS["speed"])
	weight = float(STATS["weight"])
	color = LOOK["mid"]
	dmg = Weapons.BASE * tough.y
	aware = true
	notice_t = 0.0
	state = "emerge"
	state_t = float(STATS["emerge"])
	spell_t = float(SPELL["first"])
	if pl != null:
		copy_from(pl)


## Takes the climber's weapon in hand, armor, looks and marks.
func copy_from(pl) -> void:
	w_id = String(pl.weapon)
	wd = Weapons.info(w_id)
	if wd.is_empty():
		w_id = "fists"
		wd = Weapons.info("fists")
	ranged = String(wd["kind"]) != "melee"
	chain = [] if ranged else (wd["combo"] as Array).slice(0, int(SWING["links"]))
	armor = clampf(float(pl.protection()) * float(STATS["armor"]), 0.0, 0.8)
	armor_id = String(pl.gear_id("armor"))
	look = climber_look(pl)
	marks.clear()
	spells.clear()
	var bds: Array = pl.bonds.values()
	bds.sort_custom(func(a, b): return a.step > b.step)
	for bd in bds:
		marks.append([String(bd.part), bd.color(), int(bd.step)])
		if spells.size() >= int(SPELL["max"]):
			continue
		var known: Array = bd.spells()
		spells.append({"bond": String(bd.id), "name": String(known[0]["name"]) if not known.is_empty() else String(bd.display_name()),
			"shape": String(BOND_SHAPE.get(bd.id, "blast")), "color": bd.color(), "step": int(bd.step)})


## The climber's look (their appearance, then the worn pieces that show,
## exactly as player.gd dresses them); today's look without a climber.
static func climber_look(pl) -> Dictionary:
	var lk := Appearance.look(Appearance.DEFAULTS)
	lk["hood"] = lk["cloak"].darkened(0.22)
	lk["head"] = Appearance.head_kind(lk)
	# The climber's own looks (appearance.gd), when they've chosen them.
	if pl != null and "appearance_look" in pl and pl.appearance_look is Dictionary:
		lk = pl.appearance_look.duplicate()
	if pl != null and pl.has_method("_piece_look"):
		pl._piece_look(lk, true)
		pl._armor_look(lk)
		pl._piece_look(lk, false)
	return lk


func _ready() -> void:
	super._ready()
	if main != null and main.lighting != null:
		_light = main.lighting.add_light(global_position, 70.0, LOOK["glow"], 0.35, 0.15, self)


func _exit_tree() -> void:
	if _light >= 0 and main != null and is_instance_valid(main) and main.lighting != null:
		main.lighting.remove_light(_light)
		_light = -1
	super._exit_tree()


func _reach(i := 0) -> float:
	if chain.is_empty():
		return 40.0
	return float(chain[clampi(i, 0, chain.size() - 1)]["range"])


func spell_damage(sp: Dictionary) -> float:
	var shape: Dictionary = SHAPES[sp["shape"]]
	var tough: Vector2 = main.Floors.toughness(main.floor_num)
	return float(SPELL["dmg"]) * float(shape["dmg"]) * tough.y * (1.0 + float(SPELL["per_step"]) * float(int(sp["step"]) - 1))


func swing_damage(i: int) -> float:
	return dmg * float(STATS["melee"]) * float(chain[clampi(i, 0, chain.size() - 1)]["dmg"])


func shot_damage() -> float:
	return dmg / Weapons.BASE * float(wd.get("dmg_max", wd.get("dmg", 16.0))) * float(STATS["shot"])


func shot_speed() -> float:
	return minf(float(wd.get("speed_max", wd.get("speed", 600.0))) * float(STATS["shot_speed"]), float(STATS["shot_max"]))


# --- how it fights ----------------------------------------------------------------

## enemy.gd's turn for a kind it doesn't know: the mirror image's.
func _act(delta: float, dir: Vector2, dist: float, p) -> void:
	roll_cd -= delta
	spell_t -= delta
	swing_anim -= delta
	match state:
		"emerge":
			velocity = Vector2.ZERO
			state_t -= delta
			if state_t <= 0.0:
				state = "chase"
		"roll":
			state_t -= delta
			velocity = roll_dir * float(ROLL["speed"])
			if state_t <= 0.0:
				state = "chase"
		"guard":
			# Guarding: edges in slowly, its silver arc toward you.
			state_t -= delta
			velocity = dir * speed * 0.3 if dist > _reach() + p.radius else Vector2.ZERO
			if state_t <= 0.0:
				state = "chase"
		"wind_swing":
			velocity = Vector2.ZERO
			if not glinted:
				lunge_dir = lunge_dir.slerp(dir, minf(1.0, 6.0 * delta)).normalized()
			if _wind(delta):
				_swing_hit(p)
				link += 1
				if link < chain.size() and dist < _reach(link) + p.radius + 40.0:
					wind_dur = float(SWING["link"])
					_begin_wind("wind_swing", wind_dur)
				else:
					link = 0
					_end_attack("recover", float(SWING["recover"]))
		"wind_shot":
			velocity = Vector2.ZERO
			if state_t > float(SHOT["lock"]):
				aim_dir = dir
				lunge_dir = dir
			if _wind(delta, maxf(0.0, dist - p.radius) / shot_speed()):
				_loose()
				var rec: Array = SHOT["recover"]
				_end_attack("recover", float(SHOT["crossbow"]) if String(wd["kind"]) == "crossbow" else randf_range(float(rec[0]), float(rec[1])))
		"wind_spell":
			velocity = Vector2.ZERO
			_aim_spell(delta, dir, dist, p)
			var sp: Dictionary = spells[spell_i]
			var travel := 0.0
			if sp["shape"] == "volley":
				travel = maxf(0.0, dist - p.radius) / float(SHAPES["volley"]["speed"])
			if _wind(delta, travel):
				_release_spell(p)
				_end_attack("recover", float(SPELL["recover"]))
		"recover", "idle":
			velocity = Vector2.ZERO
			state_t -= delta
			if state_t <= 0.0:
				state = "chase"
				if not ranged and randf() < float(GUARD["chance"]):
					state = "guard"
					state_t = float(GUARD["time"])
		_:
			_chase(delta, dir, dist, p)


func _chase(delta: float, dir: Vector2, dist: float, p) -> void:
	state_t -= delta
	# A spell when one is ready and you're in its range.
	if not spells.is_empty() and spell_t <= 0.0:
		var sp: Dictionary = spells[spell_i]
		if dist < float(SHAPES[sp["shape"]]["range"]) and main.request_attack(self):
			_begin_spell(dir, p)
			return
	if ranged:
		# Keeps its distance like you would with a bow, and rolls away when cornered.
		var keep: Array = SHOT["keep"]
		if dist < 80.0 and roll_cd <= 0.0:
			_roll(-dir.rotated(randf_range(-0.6, 0.6)))
			return
		if dist < float(keep[0]):
			velocity = -dir * speed
		elif dist > float(keep[1]):
			velocity = dir * speed
		else:
			velocity = dir.orthogonal() * speed * 0.7 * (1.0 if get_instance_id() % 2 == 0 else -1.0)
		if state_t <= 0.0 and dist < 430.0 and main.request_attack(self):
			wind_dur = maxf(float(SHOT["draw_min"]), float(wd.get("draw_time", 0.6)) + 0.2)
			_begin_wind("wind_shot", wind_dur)
			aim_dir = dir
			lunge_dir = dir
			main.sfx("warn_archer", 1.1)
		return
	if dist < _reach() + p.radius - float(SWING["inside"]) and main.request_attack(self):
		link = 0
		lunge_dir = dir
		wind_dur = float(SWING["first"])
		_begin_wind("wind_swing", wind_dur)
		main.sfx("warn_knight", 1.25, -3.0)
	elif main.holds_attack(self) or main.can_attack():
		velocity = dir * speed
	else:
		_circle(dir, dist, 110.0, speed * 0.7)


func _swing_hit(p) -> void:
	var sw: Dictionary = chain[clampi(link, 0, chain.size() - 1)]
	var reach := float(sw["range"]) + 4.0
	var arc := float(sw["arc"])
	swing_side = float(sw.get("side", 1.0))
	swing_heavy = bool(sw.get("heavy", false))
	swing_anim = float(wd.get("swing_time", 0.15)) * 2.0
	main.fx_cone(global_position, lunge_dir, reach + 8.0, deg_to_rad(arc), LOOK["light"])
	var snd := String(wd.get("sound", "swing"))
	if swing_heavy and not snd.ends_with("_heavy"):
		snd += "_heavy"
	main.sfx(snd, float(wd.get("pitch", 1.0)) * 0.92)
	knock += lunge_dir * float(sw.get("lunge", 150.0)) * 0.5  # a step into the swing, as you lunge
	var to: Vector2 = p.global_position - global_position
	if to.length() <= reach + p.radius and absf(lunge_dir.angle_to(to)) <= deg_to_rad(arc):
		p.receive_attack(swing_damage(link), self)


func _loose() -> void:
	var v := aim_dir * shot_speed()
	var arrow = main.spawn_projectile(global_position + aim_dir * (radius + 4.0), v, shot_damage())
	arrow.heavy = String(wd["kind"]) == "crossbow"
	arrow.life = 1.8
	main.sfx("bow", 0.95, -2.0)


func _roll(d: Vector2) -> void:
	if is_attacking():
		_end_attack("chase", 0.0)
	state = "roll"
	state_t = float(ROLL["time"])
	roll_dir = d.normalized()
	roll_cd = float(ROLL["every"])
	main.sfx("dodge", 1.05, -4.0)
	main.fx_ghost(global_position, radius, LOOK["ghost"])


# --- its spells -------------------------------------------------------------------

func _begin_spell(dir: Vector2, p) -> void:
	var sp: Dictionary = spells[spell_i]
	var shape: Dictionary = SHAPES[sp["shape"]]
	wind_dur = float(shape["wind"])
	_begin_wind("wind_spell", wind_dur)
	lunge_dir = dir
	spell_spot = p.global_position
	var col: Color = sp["color"]
	main.fx_text(global_position + Vector2(0, -radius - 34.0), String(sp["name"]), col)
	main.fx_ring(global_position, col, radius + 16.0, 0.4, 2.0)
	main.sfx("charge", 0.85, -4.0)


## A spell's aim follows the climber until it locks (a blast's circle and a
## cone `lock` seconds before they land; a volley's at its glint).
func _aim_spell(delta: float, dir: Vector2, _dist: float, p) -> void:
	var sp: Dictionary = spells[spell_i]
	var shape: Dictionary = SHAPES[sp["shape"]]
	var locked: bool = glinted or state_t <= float(shape.get("lock", 0.0))
	if locked:
		return
	match String(sp["shape"]):
		"blast":
			spell_spot = spell_spot.move_toward(p.global_position, 260.0 * delta)
		"cone", "volley":
			lunge_dir = lunge_dir.slerp(dir, minf(1.0, 6.0 * delta)).normalized()


func _release_spell(p) -> void:
	var sp: Dictionary = spells[spell_i]
	var shape: Dictionary = SHAPES[sp["shape"]]
	var col: Color = sp["color"]
	var amount := spell_damage(sp)
	spell_i = (spell_i + 1) % spells.size()
	var ev: Array = SPELL["every"]
	spell_t = randf_range(float(ev[0]), float(ev[1]))
	match String(sp["shape"]):
		"volley":
			var n := int(shape["count"])
			for k in n:
				var d := lunge_dir.rotated(deg_to_rad(float(shape["spread"])) * (float(k) - float(n - 1) * 0.5))
				var bolt = main.spawn_projectile(global_position + d * (radius + 4.0), d * float(shape["speed"]), amount)
				bolt.style = "venom"
				bolt.tint = col
				bolt.poison = float(POISON.get(sp["bond"], 0.0))
				bolt.life = float(shape["range"]) / float(shape["speed"]) + 0.3
			main.sfx("swing_light", 1.3, -4.0)
		"blast":
			var r := float(shape["r"])
			main.fx_ring(spell_spot, col, r, 0.4, 4.0)
			main.fx_burst(spell_spot, Vector2.ZERO, col, 16, 220.0)
			main.light_flash(spell_spot, col, 1.5, 1.6, 0.3)
			main.sfx("zap" if sp["bond"] == "stormcaller" else "slam", 0.9, -3.0)
			main.shake(4.0)
			if not p.dead and p.global_position.distance_to(spell_spot) < r + p.radius:
				p.receive_attack(amount, self, true)
		"cone":
			var reach := float(shape["reach"])
			var half := deg_to_rad(float(shape["arc"]))
			main.fx_cone(global_position, lunge_dir, reach, half, col)
			main.sfx("swing_heavy", 0.75, -2.0)
			var to: Vector2 = p.global_position - global_position
			if not p.dead and to.length() < reach + p.radius and absf(lunge_dir.angle_to(to)) <= half:
				_hit_and_push(p, amount, to.normalized() * float(shape["push"]))
		"nova":
			var r2 := float(shape["r"])
			main.fx_ring(global_position, col, r2, 0.4, 5.0)
			main.fx_burst(global_position, Vector2.ZERO, col, 20, 260.0)
			main.light_flash(global_position, col, 1.6, 1.6, 0.3)
			main.sfx("slam", 1.1, -3.0)
			main.shake(4.0)
			var to2: Vector2 = p.global_position - global_position
			if not p.dead and to2.length() < r2 + p.radius:
				_hit_and_push(p, amount, to2.normalized() * float(shape["push"]))


## An area that can't be parried (roll out of it); a blow that lands throws you.
func _hit_and_push(p, amount: float, push: Vector2) -> void:
	var before: float = p.hp
	p.receive_attack(amount, self, true)
	if p.hp < before:
		p.knock = push


# --- taking blows -----------------------------------------------------------------

func take_hit(amount: float, dir: Vector2, force := 140.0, heavy := false, pierce := false) -> void:
	if dead:
		return
	var front: bool = dir != Vector2.ZERO and face.dot(-dir) > 0.3
	if hp > 0.0 and dir != Vector2.ZERO and stun <= 0.0 and airborne <= 0.0:
		if state == "roll":
			main.fx_text(global_position + Vector2(0, -radius - 22.0), TEXT["dodged"], LOOK["light"])
			return
		# Its guard turns light blows from the front, and answers.
		if state == "guard" and front and not heavy:
			_turn_aside(dir)
			return
		# Now and then it rolls clear, as you would.
		if front and not heavy and not is_attacking() and state != "emerge" and roll_cd <= 0.0 and randf() < float(ROLL["chance"]):
			_roll(dir.rotated(randf_range(-0.9, 0.9)))
			main.fx_text(global_position + Vector2(0, -radius - 22.0), TEXT["dodged"], LOOK["light"])
			return
	if not pierce:
		amount *= 1.0 - armor
	super.take_hit(amount, dir, force * float(STATS["knock"]), heavy, pierce)
	if dead and not _prized:
		_prize()


## A light blow into its guard: turned aside, the climber thrown back and
## open for a moment; it answers at once (still with its glint).
func _turn_aside(dir: Vector2) -> void:
	var p = main.player
	var at: Vector2 = global_position - dir * (radius + 6.0)
	main.fx_text(global_position + Vector2(0, -radius - 22.0), TEXT["turned"], LOOK["guard"])
	main.fx_ring(at, LOOK["guard"], 40.0, 0.3, 3.0)
	main.fx_burst(at, -dir, LOOK["guard"], 10, 260.0)
	main.sfx("parry", 0.85, -2.0)
	main.hitstop(0.08)
	if p != null:
		p.knock = dir * float(GUARD["push"])
		p.attack_cd = maxf(p.attack_cd, float(GUARD["open"]))
		p.combo = 0
	if not chain.is_empty() and main.request_attack(self):
		link = 0
		lunge_dir = -dir
		wind_dur = float(SWING["link"]) + 0.1
		_begin_wind("wind_swing", wind_dur)
	else:
		state = "chase"


## Shattered: shards of glass, and its prize.
func _prize() -> void:
	_prized = true
	var at := global_position
	var col: Color = LOOK["light"]
	main.fx_burst(at, Vector2.ZERO, col, 30, 340.0)
	main.fx_ring(at, LOOK["glow"], 70.0, 0.5, 4.0)
	main.light_flash(at, LOOK["glow"], 2.0, 1.8, 0.5)
	main.sfx("parry", 1.6, -2.0, 0.0)
	main.fx_text(at + Vector2(0, -78), TEXT["shatter"], col)
	var ek: String = main.tower_data().get("essence", "air")
	var amt := 10.0
	if main.wings != null:
		amt = roundf(main.wings.crystal_amount() * float(PRIZE["crystal"]))
	if main.profile != null:
		main.profile.add_crystal(ek, amt)
		main.profile.save()
		main.fx_text(at + Vector2(0, -96), TEXT["crystal"] % [main.Items.CRYSTAL["name"] % main.Essence.display(ek), int(amt)], main.Essence.color(ek))
	if randf() < float(PRIZE["gear"]):
		main.drop_gear(at + Vector2(0, 12), main.find_gear("", 1), true)


func _leave_remains() -> void:
	if main == null or _last.pts.is_empty() or not is_inside_tree():
		return
	_spawn_remains(main, position, _last.pts, _last.cols, radius)


# --- drawing ------------------------------------------------------------------------

func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001
	_dt = clampf(get_process_delta_time(), 0.0, 0.05)
	var spd := velocity.length()
	_move = move_toward(_move, clampf(spd / 120.0, 0.0, 1.0), _dt * 6.0)
	_phase = fmod(_phase + spd * _dt / 11.0, TAU)
	var lift := -12.0 if airborne > 0.0 else 0.0
	var f := face
	var sd := -face.orthogonal()  # a mirror image holds its weapon in the other hand
	# Its shadow is a reflection: a pale sheen on the floor.
	var sh := Draw.Batch.new()
	sh.circle(Vector2(0, radius * 0.75), radius * 1.05, Color(LOOK["dark"], 0.3), 24)
	sh.circle(Vector2(0, radius * 0.75), radius * 0.8, Color(LOOK["mid"], 0.12), 20)
	sh.flush(self)
	var b := Draw.Batch.new()
	if state == "roll":
		_draw_rolled(b)
	else:
		draw_climber(b, look, _pose(f, sd, t))
	var emerge := 1.0
	if state == "emerge":
		emerge = clampf(1.0 - state_t / float(STATS["emerge"]), 0.15, 1.0)
	glass(b, 0, t, global_position, clampf(flash / 0.12, 0.0, 1.0) * 0.6, emerge)
	# Its marks: the climber's, mirrored, glowing in their own colours.
	for m in marks:
		var at := _mark_at(String(m[0]), f, sd)
		var mc: Color = m[1]
		b.dot(at, 3.2, Color(Palette.OUTLINE, 0.8 * emerge))
		b.dot(at, 2.3, Color(mc, emerge))
		for i in int(m[2]):
			var a := at.angle() + PI + (float(i) - (float(m[2]) - 1.0) / 2.0) * 0.5
			b.line(at + Vector2.from_angle(a) * 3.0, at + Vector2.from_angle(a) * 6.0, Color(mc, 0.9 * emerge), 1.2)
	# Slightly off: a faint cool copy of it, a pixel or two aside.
	var ghost := b.pts.duplicate()
	var gcols := PackedColorArray()
	gcols.resize(ghost.size())
	var gc: Color = LOOK["ghost"]
	gcols.fill(Color(gc, gc.a * emerge))
	var off := Vector2(1.8 + 0.6 * sin(t * 2.3), -0.8)
	for i in ghost.size():
		ghost[i] += off
	_last.pts = b.pts.duplicate()
	_last.cols = b.cols.duplicate()
	draw_set_transform(Vector2(0, lift))
	RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), PackedInt32Array(), ghost, gcols)
	b.flush(self)
	draw_set_transform(Vector2.ZERO)
	if overlay != null:
		overlay.queue_redraw()


func _pose(f: Vector2, sd: Vector2, t: float) -> Dictionary:
	var pose := {"f": f, "sd": sd, "light": Draw.LIGHT_DIR, "s": sin(_phase) * _move, "t": t, "weapon": w_id, "w": wd,
		"armor": armor_id, "radius": radius, "glint": 1.0 if swing_anim > 0.0 else 0.0}
	if state == "wind_swing" and not chain.is_empty():
		var sw: Dictionary = chain[clampi(link, 0, chain.size() - 1)]
		pose["wind"] = _wk(wind_dur)
		pose["arc"] = float(sw["arc"])
		pose["side"] = float(sw.get("side", 1.0))
	elif swing_anim > 0.0:
		pose["swing"] = 1.0 - swing_anim / (float(wd.get("swing_time", 0.15)) * 2.0)
		pose["arc"] = float(chain[0]["arc"]) if not chain.is_empty() else 50.0
		pose["side"] = swing_side
		pose["heavy"] = swing_heavy
	if state == "wind_shot":
		pose["draw"] = _wk(wind_dur)
	if state == "guard":
		pose["guard"] = true
	return pose


func _mark_at(part: String, f: Vector2, sd: Vector2) -> Vector2:
	match part:
		"throat":
			return f * (radius * 0.25) + sd * 2.0
		"back":
			return -f * (radius * 0.7) + sd * 2.0
		"hand":
			return sd * radius * 0.95 + f * 3.0
		"brow":
			return f * (radius * 0.55)
		"heart":
			return -sd * radius * 0.3 - f * 3.0
	return Vector2(0, radius * 0.55)


## Curled up, tumbling along its roll (as the climber rolls).
func _draw_rolled(b) -> void:
	var k := clampf(1.0 - state_t / float(ROLL["time"]), 0.0, 1.0) * TAU
	var lk: Dictionary = look if look.has("hood") and look.has("head") else climber_look(null).merged(look, true)
	Appearance.draw_rolled_cloak(b, lk, roll_dir, roll_dir.orthogonal(), k, Draw.LIGHT_DIR)
	b.ball(roll_dir * (5.0 * cos(k)), 5.0, Appearance.crown(lk))


## Every colour from index `from` on pulled toward silvered glass, a shimmer
## sweeping across it (by world position, so it slides as it moves), `flash`
## toward white when struck, and `a` its opacity.
static func glass(b, from: int, t: float, world: Vector2, flash := 0.0, a := 1.0) -> void:
	var dark: Color = LOOK["dark"]
	var mid: Color = LOOK["mid"]
	var light: Color = LOOK["light"]
	var keep := float(LOOK["keep"])
	var alpha := float(LOOK["alpha"]) * a
	var band := fmod(t * 34.0, 90.0) - 45.0
	var shim := float(LOOK["shimmer"])
	for i in range(from, b.cols.size()):
		var c: Color = b.cols[i]
		var l := c.get_luminance()
		var g := dark.lerp(mid, clampf(l * 2.4, 0.0, 1.0)) if l < 0.42 else mid.lerp(light, clampf((l - 0.42) * 2.0, 0.0, 1.0))
		var out := c.lerp(g, 1.0 - keep)
		var u: float = (b.pts[i] + world * 0.15).dot(Vector2(0.7, 0.7)) - band
		var s := exp(-u * u / 30.0) * shim
		out = out.lerp(Color(1, 1, 1), s + flash)
		b.cols[i] = Color(out, c.a * alpha)


## THE CLIMBER, drawn into Batch `b` as player.gd draws it (a hooded head,
## shoulders and arms over a swaying cloak, boots, armor and the weapon in
## hand), from `look` (its colours: cloak, skin, tunic, hair, boot, and the
## worn pieces' torso, shoulder, sleeve, hand, hood, head, cap, boot_r,
## studs, shoulder_r) and `pose` (f: facing, sd: toward the weapon hand,
## light, s: stride, t, weapon id, w: its data, armor id, radius, and the
## moment: wind 0..1 with arc and side, swing 0..1 with arc, side, heavy,
## draw 0..1 for a bow, guard, glint).
static func draw_climber(b, lk: Dictionary, pose: Dictionary) -> void:
	var f: Vector2 = pose["f"]
	var sd: Vector2 = pose["sd"]
	var lt: Vector2 = pose.get("light", Draw.LIGHT_DIR)
	var s: float = pose.get("s", 0.0)
	var t: float = pose.get("t", 0.0)
	# The body, clothes and head in the climber's look, in layers, exactly as
	# player.gd draws them (appearance.gd); the armour and arms here.
	if not (lk.has("cloak") and lk.has("hood") and lk.has("head") and lk.has("skin") and lk.has("hair")):
		lk = climber_look(null).merged(lk, true)  # (a partial look: the rest as the climber's defaults)
	var sway := sin(t * 1.7) * 0.8 + s * 1.4
	Appearance.draw_legs(b, Vector2.ZERO, f, sd, lt, lk, s)
	Appearance.draw_cloak(b, Vector2.ZERO, f, sd, lt, lk, sway, Vector2.ZERO)
	GearLook.tower_back(b, Vector2.ZERO, f, sd, lt, lk)  # (gear_look.gd: a backpack, a slung weapon)
	Appearance.draw_torso(b, Vector2.ZERO, f, sd, lt, lk)
	var torso: Color = lk.get("torso", lk.get("tunic", Palette.CLIMBER_TUNIC))
	var tk: float = float(lk.get("torso_r", 8.5)) / 8.5
	var arm: String = pose.get("armor", "")
	var c := _p(f, sd, 2.0, 0.0)
	match arm:
		"padded":
			for k in 5:
				var a := f.angle() + (k - 2) * 0.38
				b.line(c + Vector2.from_angle(a) * 5.5 * tk, c + Vector2.from_angle(a) * 8.0 * tk, Color(0, 0, 0, 0.3), 1.0)
		"leather":
			b.line(_p(f, sd, 2.0 + 7.5 * tk, -3.5 * tk), _p(f, sd, 3.0, 8.5 * tk), torso.darkened(0.35), 1.8)
		"chain":
			for k in 7:
				b.dot(c + Vector2.from_angle(f.angle() + (k - 3) * 0.3) * 7.2 * tk, 0.8, Color(1, 1, 1, 0.3))
		"plate":
			b.line(_p(f, sd, 2.0 + 4.6 * tk, 0.0), _p(f, sd, 2.0 + 8.2 * tk, 0.0), torso.lightened(0.35), 1.2)
	var sh_r: float = float(lk.get("shoulder_r", 4.6)) + float(lk.get("sh_add", 0.0))
	var sh_y: float = lk.get("sh_y", 9.3)
	for sgn in [-1.0, 1.0]:
		b.ball(_p(f, sd, 0.3, sgn * sh_y), sh_r, lk.get("shoulder", lk["cloak"].darkened(0.12)), true, lt)
	GearLook.tower_chest(b, Vector2.ZERO, f, sd, lt, lk, t)  # (an amulet, a fine chest piece's glow)
	Appearance.draw_head(b, _p(f, sd, -0.5, 0.0), f, sd, lt, lk, sway, Vector2.ZERO)
	GearLook.tower_head(b, _p(f, sd, -0.5, 0.0), f, sd, lt, lk, t)
	_draw_arms(b, lk, pose, _p(f, sd, 0.3 + s * 0.8, sh_y), _p(f, sd, 0.3 - s * 0.8, -sh_y))


static func _p(f: Vector2, sd: Vector2, x: float, y: float) -> Vector2:
	return f * x + sd * y


## Arms, the weapon in hand (resting, wound back, mid-swing or drawn), hands on top.
static func _draw_arms(b, lk: Dictionary, pose: Dictionary, sh_w: Vector2, sh_o: Vector2) -> void:
	var f: Vector2 = pose["f"]
	var sd: Vector2 = pose["sd"]
	var lt: Vector2 = pose.get("light", Draw.LIGHT_DIR)
	var s: float = pose.get("s", 0.0)
	var r: float = pose.get("radius", 14.0)
	var w: Dictionary = pose.get("w", {})
	var id: String = pose.get("weapon", "fists")
	var glint: float = pose.get("glint", 0.0)
	var sleeve: Color = lk.get("sleeve", lk.get("tunic", Palette.CLIMBER_TUNIC))
	var hand: Color = lk.get("hand", lk.get("skin", Palette.CLIMBER_SKIN))
	var free := sh_o + _p(f, sd, 5.0 - s * 3.0, -1.2)
	var hands: Array = []
	var style := String(w.get("style", w.get("kind", "jab")))
	var half := deg_to_rad(float(pose.get("arc", 50.0)))
	var side := float(pose.get("side", 1.0))
	# Turns toward the weapon hand's side as player.gd's do (a mirror image's
	# weapon hand is the other one, so its turns are mirrored too).
	var hs := -signf(f.angle_to(sd))
	match style:
		"arc":
			var two: bool = String(w.get("class", "")) == "heavy"
			var grip := sd * (r * (0.5 if two else 0.95)) + f * (7.0 if two else 4.0)
			var along := f.rotated((0.8 if two else 0.5) * hs)
			if pose.has("wind"):
				# Wound back across the body: the swing will come from there.
				var k: float = pose["wind"]
				along = f.rotated(-half * side * (0.6 + 0.6 * k) * hs)
				grip = along * 9.0
			elif pose.has("swing"):
				var k2: float = pose["swing"]
				along = f.rotated(lerpf(-half * side, half * side, minf(1.0, k2 * 1.6)) * hs)
				grip = along * 10.0
			elif pose.get("guard", false):
				along = sd.rotated(-0.6 * hs)
				grip = f * 9.0 + sd * 2.0
			var length := float(w.get("length", 24.0))
			_swung(b, id, grip, along, length, glint, lt)
			hands.append([sh_w, grip - along * 3.0, 3.0])
			hands.append([sh_o, grip + along * 1.5 if two else free, 2.8])
		"stab", "thrust":
			var length2 := float(w.get("length", 14.0))
			var rest := sd * (r * 0.85) + f * 2.0
			var ext := 0.0
			if pose.has("swing"):
				ext = sin(PI * minf(1.0, float(pose["swing"]) * 1.3))
			elif pose.has("wind"):
				ext = -0.4 * float(pose["wind"])
			var grip2 := rest.lerp(f * 26.0 + sd * 2.0, ext) if ext >= 0.0 else rest + f * ext * 10.0
			if id == "spear":
				grip2 -= f * 10.0
				b.stroke(grip2 - f * 16.0, grip2 + f * (length2 - 9.0), Palette.WOOD, 2.6)
				var tip := grip2 + f * length2
				b.poly(PackedVector2Array([tip, tip - f * 10.0 + sd * 3.6, tip - f * 10.0 - sd * 3.6]), Palette.STEEL, 1.0)
				hands.append([sh_w, grip2, 3.0])
				hands.append([sh_o, grip2 - f * 12.0 - sd * 1.5, 2.8])
			else:
				b.sword(grip2, f, length2, glint)
				hands.append([sh_w, grip2 - f * 2.0, 3.0])
				hands.append([sh_o, free, 2.8])
		"bow":
			var kd: float = pose.get("draw", 0.0)
			var limb := float(w.get("limb", 14.0))
			var bgrip := f * (r + 5.0)
			var tip_a := bgrip - f * (5.0 + 2.0 * kd) + sd * limb * (1.0 - 0.06 * kd)
			var tip_b := bgrip - f * (5.0 + 2.0 * kd) - sd * limb * (1.0 - 0.06 * kd)
			var nock := bgrip - f * (5.0 + 12.0 * kd)
			var bow := PackedVector2Array([tip_a, bgrip + sd * limb * 0.5 - f * kd, bgrip, bgrip - sd * limb * 0.5 - f * kd, tip_b])
			b.path(bow, Color(Palette.OUTLINE, Draw.FEATHER_ALPHA), 7.0)
			b.path(bow, Palette.OUTLINE, 5.5)
			b.path(bow, Palette.WOOD, 3.0)
			b.path(PackedVector2Array([tip_a, nock, tip_b]), Color(0.92, 0.9, 0.82), 1.0)
			if pose.has("draw"):
				b.stroke(nock, nock + f * (18.0 + 14.0 * kd), Palette.WOOD.lightened(0.2), 1.6)
			hands.append([sh_w, bgrip + sd * 0.5, 3.0])
			hands.append([sh_o, nock if pose.has("draw") else free, 2.8])
		"crossbow":
			var back := f * 4.0 + sd * 3.0
			var front := back + f * 22.0
			b.stroke(back, front, Palette.WOOD, 3.4)
			var limbs := PackedVector2Array([front - f * 3.0 + sd * 11.0, front + sd * 4.0, front, front - sd * 4.0, front - f * 3.0 - sd * 11.0])
			b.path(limbs, Palette.OUTLINE, 5.0)
			b.path(limbs, Palette.STEEL.darkened(0.25), 2.6)
			hands.append([sh_w, back + f * 3.0, 3.0])
			hands.append([sh_o, back + f * 12.0 - sd * 4.0, 2.8])
		_:  # fists
			for sgn in [-1.0, 1.0]:
				var pos: Vector2 = f * (r * 0.7) + sd * sgn * r * 0.75
				var hr := 3.8
				if pose.has("swing") and sgn == side:
					pos = pos.lerp(f * 30.0, sin(PI * minf(1.0, float(pose["swing"]) * 1.2)))
					hr = 4.6
				elif pose.has("wind") and sgn == side:
					pos -= f * 4.0 * float(pose["wind"])
				hands.append([sh_w if sgn > 0.0 else sh_o, pos, hr])
	for h in hands:
		b.stroke(h[0], h[1], sleeve, 3.4)
	for h in hands:
		b.ball(h[1], h[2], hand, true, lt)


## A swung weapon along `along` from the grip (as player.gd draws each).
static func _swung(b, id: String, grip: Vector2, along: Vector2, length: float, glint: float, lt: Vector2) -> void:
	var side := along.orthogonal()
	match id:
		"axe":
			var head := grip + along * (length - 4.0)
			b.stroke(grip - along * 4.0, head + along * 3.0, Palette.WOOD, 2.6)
			b.poly(PackedVector2Array([head - along * 4.0 + side * 1.5, head + along * 5.0 + side * 1.5, head + along * 7.0 + side * 9.0, head - along * 6.0 + side * 9.0]), Palette.STEEL.darkened(0.08), 1.2)
		"mace":
			var ball := grip + along * length
			b.stroke(grip - along * 4.0, ball, Palette.WOOD.darkened(0.2), 2.6)
			for i in 6:
				b.stroke(ball, ball + Vector2.from_angle(TAU * i / 6.0 + along.angle()) * 7.5, Palette.STEEL.darkened(0.3), 1.4)
			b.ball(ball, 5.2, Palette.STEEL.darkened(0.15), true, lt)
		"war_hammer":
			var h2 := grip + along * length
			b.stroke(grip - along * 6.0, h2, Palette.WOOD.darkened(0.1), 3.0)
			b.poly(PackedVector2Array([h2 - along * 5.0 + side * 9.0, h2 + along * 5.0 + side * 9.0, h2 + along * 5.0 - side * 6.0, h2 - along * 5.0 - side * 6.0]), Palette.STEEL.darkened(0.15), 1.4)
		"greatsword":
			b.sword(grip, along, length, glint)
			b.stroke(grip + along * 3.0 + side * 1.6, grip + along * (length - 3.0) + side * 1.6, Palette.STEEL.darkened(0.04), 2.2)
			b.stroke(grip + side * 7.0, grip - side * 7.0, Palette.STEEL.darkened(0.35), 2.5)
		_:
			b.sword(grip, along, length, glint)


## Telegraphs over the darkness (enemy.gd's overlay asks): the swing's cone,
## the shot's line, each spell's circle, cone, ring or fan; its guard; a
## glassy rim at its feet so it reads in the dark.
func _overlay_extra(o) -> void:
	var now := Time.get_ticks_msec() * 0.001
	var danger := Palette.DANGER
	var rim: Color = LOOK["rim"]
	var br := 0.65 + 0.35 * sin(now * 2.6)
	o.arc(Vector2(0, radius * 0.7), radius + 5.0, 0.0, TAU, 1.4, Color(rim, 0.4 * br), 30)
	for i in 3:
		var a := now * 1.7 + i * TAU / 3.0
		var sp := Vector2.from_angle(a) * (radius + 3.0) + Vector2(0, -2.0)
		var tw := 0.5 + 0.5 * sin(now * 5.0 + i * 2.0)
		o.quad(sp - Vector2(2.5, 0) * tw, sp + Vector2(2.5, 0) * tw, 1.0, Color(rim, 0.7 * tw))
		o.quad(sp - Vector2(0, 2.5) * tw, sp + Vector2(0, 2.5) * tw, 1.0, Color(rim, 0.7 * tw))
	match state:
		"wind_swing":
			if not chain.is_empty():
				var sw: Dictionary = chain[clampi(link, 0, chain.size() - 1)]
				_cone(o, float(sw["range"]) + 4.0, float(sw["arc"]), _wk(wind_dur), 0.1, 0.75)
		"wind_shot":
			var k := _wk(wind_dur)
			var locked := state_t <= float(SHOT["lock"])
			o.quad(aim_dir * 14.0, aim_dir * 420.0, 1.0 + k * (2.0 if locked else 1.0), Color(danger, 0.25 + 0.45 * k))
			o.circle(aim_dir * 14.0, 2.0 + k * 2.0, Color(danger, 0.8), 14)
		"wind_spell":
			var sp2: Dictionary = spells[spell_i]
			var shape: Dictionary = SHAPES[sp2["shape"]]
			var col: Color = sp2["color"]
			var k2 := _wk(wind_dur)
			match String(sp2["shape"]):
				"blast":
					var at := spell_spot - global_position
					_target(o, at, float(shape["r"]), k2, 0.1, 2.5)
					o.arc(at, float(shape["r"]) - 4.0, 0.0, TAU, 1.5, Color(col, 0.75), 36)
				"cone":
					_cone(o, float(shape["reach"]), float(shape["arc"]), k2, 0.1, 0.75)
					o.arc(Vector2.ZERO, float(shape["reach"]) - 4.0, lunge_dir.angle() - deg_to_rad(float(shape["arc"])), lunge_dir.angle() + deg_to_rad(float(shape["arc"])), 1.5, Color(col, 0.75), 16)
				"nova":
					var r := float(shape["r"])
					o.circle(Vector2.ZERO, r, Color(danger, 0.08 + 0.12 * k2), 48)
					o.arc(Vector2.ZERO, r, 0.0, TAU, 2.5, Color(danger, 0.7), 48)
					o.arc(Vector2.ZERO, r * (1.0 - k2) + 6.0, 0.0, TAU, 2.0, Color(col, 0.85), 40)
				"volley":
					_fan(o, int(shape["count"]), float(shape["spread"]), 150.0)
					o.circle(lunge_dir * (radius + 6.0), 3.0 + 2.0 * k2, Color(col, 0.85), 14)
		"guard":
			var g: Color = LOOK["guard"]
			var fa := face.angle()
			o.arc(Vector2.ZERO, radius + 9.0, fa - 1.05, fa + 1.05, 3.0, Color(g, 0.85), 18)
			o.arc(Vector2.ZERO, radius + 13.0, fa - 0.8, fa + 0.8, 1.4, Color(g, 0.45), 14)


# --- the room ----------------------------------------------------------------------

## The mirror room's floor (room.gd decor "glass"): panes of silvered glass
## standing along its walls, and polished panes in the floor with
## reflections across them. `rows` the room's grid (rooms.gd), `at` its
## top-left, `tile` the tile size.
static func draw_glass(b, rows: Array, at: Vector2, tile: float, seed: int) -> void:
	var light: Color = LOOK["light"]
	var mid: Color = LOOK["mid"]
	var h := rows.size()
	for y in h:
		var row: String = rows[y]
		for x in row.length():
			var ch := row[x]
			if not ch in [".", "M", "?", "~"]:
				continue
			var tl := at + Vector2(x, y) * tile
			# Polished panes in the floor, every other tile.
			if (x + y) % 2 == 0:
				b.rect(Rect2(tl + Vector2(3, 3), Vector2(tile - 6, tile - 6)), Color(mid, 0.07))
				if (x * 7 + y * 3 + seed) % 5 == 0:
					b.line(tl + Vector2(8, tile - 10), tl + Vector2(tile - 12, 6), Color(light, 0.12), 2.0)
					b.line(tl + Vector2(14, tile - 8), tl + Vector2(tile - 8, 12), Color(light, 0.07), 1.0)
			# Mirrors along the walls: a frame, a silvered face, a gleam.
			var walls := [
				[y == 0 or not String(rows[y - 1])[x] in [".", "M", "?", "~"], Rect2(tl + Vector2(5, 1), Vector2(tile - 10, 12))],
				[y == h - 1 or not String(rows[y + 1])[x] in [".", "M", "?", "~"], Rect2(tl + Vector2(5, tile - 8), Vector2(tile - 10, 7))],
				[x == 0 or not row[x - 1] in [".", "M", "?", "~"], Rect2(tl + Vector2(1, 5), Vector2(7, tile - 10))],
				[x == row.length() - 1 or not row[x + 1] in [".", "M", "?", "~"], Rect2(tl + Vector2(tile - 8, 5), Vector2(7, tile - 10))],
			]
			for wl in walls:
				if not wl[0] or (x + y + seed) % 2 == 1:
					continue
				var r: Rect2 = wl[1]
				b.rect(r.grow(1.5), Color(Palette.OUTLINE, 0.8))
				b.rect(r, Color(0.32, 0.38, 0.5, 0.95))
				b.rect(r.grow(-1.5), Color(0.62, 0.7, 0.84, 0.9))
				var a := r.position + Vector2(r.size.x * 0.25, r.size.y)
				var e := r.position + Vector2(r.size.x * 0.6, 0)
				b.line(a, e, Color(light, 0.75), 1.5)
				b.line(a + Vector2(r.size.x * 0.2, 0), e + Vector2(r.size.x * 0.2, 0), Color(light, 0.35), 1.0)


## The mirror room's door (doors.gd style "mirror"): a dark frame holding an
## oval of silvered glass with a hooded figure in it, a crack across the
## glass. It hints at the fight, never the prize.
static func draw_door(b, inner: Rect2, along: Vector2, side: Vector2, long: float, across: float) -> void:
	var c := inner.get_center()
	var o := inner.position
	b.rect(inner.grow(-3.0), Color(0.16, 0.17, 0.22))
	for k in [0.12, 0.88]:
		b.circle(o + along * long * k + side * across * 0.5, 2.0, Palette.DOOR_IRON.lightened(0.35))
	var s := across * 0.36
	var oval := PackedVector2Array()
	for i in 20:  # (upright, whichever way the door faces)
		var a := TAU * i / 20.0
		oval.append(c + Vector2(cos(a) * s * 0.85, sin(a) * s * 1.15))
	b.polygon(oval, Palette.OUTLINE)
	var inner_oval := PackedVector2Array()
	for p in oval:
		inner_oval.append(c + (p - c) * 0.82)
	b.polygon(inner_oval, Color(0.6, 0.68, 0.82))
	# The figure in the glass: a hooded head and shoulders.
	b.circle(c + Vector2(0, s * 0.42), s * 0.42, Color(0.26, 0.3, 0.4))
	b.circle(c + Vector2(0, -s * 0.12), s * 0.26, Color(0.26, 0.3, 0.4))
	b.line(c + Vector2(-s * 0.55, -s * 0.55), c + Vector2(-s * 0.05, -s * 0.85), Color(1, 1, 1, 0.7), 1.4)
	b.line(c + Vector2(s * 0.5, -s * 0.2), c + Vector2(-s * 0.1, s * 0.3), Color(Palette.OUTLINE, 0.8), 1.2)
	b.line(c + Vector2(-s * 0.1, s * 0.3), c + Vector2(s * 0.15, s * 0.75), Color(Palette.OUTLINE, 0.8), 1.2)
