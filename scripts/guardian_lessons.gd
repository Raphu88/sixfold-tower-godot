extends RefCounted
## THE GUARDIANS LEARN FROM EACH OTHER'S DEATHS (marked and Unbound alike).
## The guardians are the six towers' beasts fought at the summit (enemy.gd
## BOSSES; not the Proving's shadow of one, a station's arena, a mirror or a
## called creature). Every rule, number and word about their lessons is here.
##
## NO ADAPTING WITHIN A FIGHT. While a guardian fights, it only watches
## (note_blow, note_roll, note_parry: a tally kept on the guardian itself):
## every blow that lands on it, by its damage: the essences in it, its FORM
## GROUP (a weapon's swing, a close blow of essence, a shot, a rush, a burst:
## GROUPS, FORM_GROUP), the Node or mark it came from, and whether it came from
## up close or at range; and every roll through its attacks and every parry
## of them.
## WHEN A GUARDIAN DIES (main.gd on_enemy_killed: learn) it teaches the
## others how its killer fought: a LESSON, kept in the profile
## (profile.guardians: tower -> lesson; the latest kill of each guardian
## replaces its lesson, so there are six at most). See lesson().
## EVERY OTHER GUARDIAN APPLIES EVERY LESSON SO FAR (effects: the lessons of
## the other five towers, adding up, each capped), all of it fair and
## readable, every attack still warned by its glint:
##   resist   it takes less from the killer's favoured essences, and from
##            blows of the Node or mark they leaned on ("resist", "part")
##   guard    it braces against the favoured close forms: a weapon's swing,
##            a close blow, a rush ("guard")
##   sidestep it sidesteps shots now and then, never while staggered or
##            recovering from an attack ("sidestep")
##   distance against a killer who fought up close it backs off between its
##            attacks; against one who fought at range it presses in ("keep",
##            "press"); it still comes within reach to strike
##   timing   against a heavy parrier (and, less, a roller) its wind-ups vary
##            in length; the glint still comes just before the blow ("timing")
##   Everything a blow loses together is at most "cap" (never immune). Mixing
##   up your style (other essences, forms, Nodes or marks, range) beats them.
## SUMMIT BLADES CAN'T BE FULLY LEARNED. A Summit Blade's power (the slivers
## of Lann, the fifth climber: summit_blades.gd) marks its blows (blow_ctx
## "blade"): they count for only LEARN "blade" of their damage in a lesson,
## and the lessons take only LEARN "blade_keep" of their toll off them (never
## sidestepped). A rumour hints at it (RUMOURS "blade").
## NOBODY TELLS THE CLIMBER. Rival climbers in the towers, the Dining car's
## climbers (dining.gd RUMORS "guardians") and the Noble pass on what the
## guardians have learned, as rumours (rumour: RUMOURS); the Entity says
## only that the guardians talk when one falls (entity.gd "guardians_talk",
## entity_talk.gd "how_guardians"), never numbers.

const Towers := preload("res://scripts/towers.gd")

## The form groups a blow can be.
const GROUPS := ["weapon", "close", "shot", "rush", "burst"]
## An Unbound technique's form -> its group (library.gd forms); a mark's
## spell is a "burst" where it strikes, a "shot" when it flies.
const FORM_GROUP := {"strike": "close", "bolt": "shot", "volley": "shot", "dash": "rush", "leap": "rush", "blink": "rush",
	"push": "burst", "shout": "burst", "pull": "burst", "mark": "burst", "sight": "burst", "within": "burst", "shell": "burst"}

## The numbers (tune here; the Data editor shows them too):
##   resist        an essence's resistance per lesson, times the killer's share of it
##   part          the same for blows of the Node or mark they leaned on
##   guard         a form group's guard per lesson, times its share
##   cap           the most a blow can lose to every lesson together (never immune)
##   sidestep      the chance per lesson to sidestep a shot, times shots' share
##   sidestep_cap  ...at most
##   near          a blow from within this (past the guardian's edge) is "up close"
##   keep, press   how hard it backs off (melee killer) or presses in (ranged
##                 killer) per lesson, from "melee_at" / "ranged_at" shares of up close
##   steer_cap     ...at most
##   timing        how much longer a wind-up may run per lesson at a full
##                 parrier ("parries_full" parries; rolls count "roll_weight",
##                 "rolls_full" rolls), at most "timing_cap"
##   min_share     an essence, form or Node under this share teaches nothing
##   blade         a SUMMIT BLADE's blows (its power: summit_blades.gd sets
##                 blow_ctx "blade") count for only this share of their damage
##                 in a lesson: the slivers of Lann, the fifth climber, can't
##                 be fully learned
##   blade_keep    ...and the lessons take only this share of their usual
##                 toll off a blade's blow (and never sidestep it): the
##                 blades keep their edge
static var LEARN := {
	"resist": 0.15, "part": 0.08, "guard": {"weapon": 0.06, "close": 0.06, "rush": 0.08},
	"cap": 0.5, "sidestep": 0.2, "sidestep_cap": 0.4, "near": 110.0,
	"keep": 0.5, "press": 0.35, "melee_at": 0.6, "ranged_at": 0.4, "steer_cap": 1.0,
	"timing": 0.12, "timing_cap": 0.4, "parries_full": 8.0, "rolls_full": 12.0, "roll_weight": 0.5,
	"min_share": 0.15, "blade": 0.17, "blade_keep": 0.5,
}

## What a guardian says on screen when its lessons show (flat, short).
static var TEXT := {
	"sidestep": "Sidestepped",
	"resist": "Resisted",
	"braced": "Braced",
	"group": {"weapon": "a blade", "close": "blows up close", "shot": "bolts and arrows", "rush": "a rush", "burst": "bursts of essence"},
	"lead": ["\"Word from the towers:\"", "\"Heard this on the stair:\"", "\"Climbers are saying:\""],
}

## Rumours of what the guardians have learned, by what a lesson holds:
## {beast} (a guardian that learned it), {teacher} (the one that fell),
## {essence}, {group}, {node}. One is picked; each needs its fact to be true.
static var RUMOURS := {
	"essence": ["\"They say {beast} shrugs off {essence} now.\"", "\"{essence} doesn't bite {beast} like it used to. Not since {teacher} fell.\""],
	"shot": ["\"I hear {beast} sidesteps bolts and arrows now.\"", "\"Shoot at {beast} and it steps aside. It learned that from {teacher}.\""],
	"rush": ["\"They say {beast} braces for a charge now.\""],
	"weapon": ["\"Word is {beast} has learned to turn a blade.\""],
	"close": ["\"{beast} braces for blows up close now, they say.\""],
	"keep": ["\"{beast} keeps its distance now, they say. It knows climbers who fight up close.\""],
	"press": ["\"They say {beast} rushes anyone who hangs back.\""],
	"timing": ["\"Someone told me {beast} holds its blows now, waiting out a parry.\""],
	"part": ["\"They say {beast} watches the {node} now.\""],
	"blade": ["\"{teacher} fell to a Summit Blade, and the others still can't read one. Some say Lann's slivers never teach.\"", "\"The guardians talk, but they can't make out a Summit Blade's blow. Not even {beast}.\""],
	"none": [],
}


# --- watching a fight ---------------------------------------------------------------------

## True for a guardian whose lessons count: a tower's beast at its summit
## (not the Proving's shadow, a mirror, a called creature, or a station's arena).
static func is_guardian(main, e) -> bool:
	if e == null or not is_instance_valid(e) or main == null or main.get("profile") == null:
		return false
	if not e.has_method("is_boss") or not e.is_boss() or bool(e.get("shade")) or bool(e.get("ally")) or bool(e.get("mirror")):
		return false
	var ar = main.get("arena")
	return not (ar != null and is_instance_valid(ar) and bool(ar.get("on")))


## The context of a blow: {"kinds": {kind: weight}, "form": group, "part"}.
## A cast sets main.blow_ctx while it strikes (player.gd _release_cast:
## cast_ctx); its shots and bolts carry it (projectile.gd, unbound_run.gd).
## A weapon's own blow: "weapon" up close, a "shot" from afar.
static func ctx_of(main, e) -> Dictionary:
	var c = main.get("blow_ctx")
	if c is Dictionary and not c.is_empty():
		return c
	var form := "burst"
	if bool(main.get("weapon_blow")):
		form = "weapon" if _gap(main, e) < float(LEARN["near"]) else "shot"
	return {"kinds": {}, "form": form, "part": ""}


## A cast's context (player.gd _release_cast): a technique's essences, its
## form's group and its Node; a mark's essence (its bond's affinity) and its
## body part ("burst" where it strikes; its shots are "shot").
static func cast_ctx(b, part: String) -> Dictionary:
	if b == null:
		return {}
	if "tech" in b and b.tech is Dictionary:
		var t: Dictionary = b.tech
		var w := {}
		var tw = t.get("w", {})
		if tw is Dictionary:
			for k in tw:
				if not String(k).begins_with("_") and float(tw[k]) > 0.0:
					w[String(k)] = float(tw[k])
		if w.is_empty():
			for k in t.get("kinds", []):
				w[String(k)] = 1.0
				break
		return {"kinds": w, "form": String(FORM_GROUP.get(String(t.get("shape", "")), "burst")), "part": String(t.get("part", part))}
	var aff := ""
	if b.has_method("data"):
		aff = String(b.data().get("affinity", ""))
	return {"kinds": {aff: 1.0} if aff != "" else {}, "form": "burst", "part": part}


## A shot's context: the cast's, as a shot.
static func as_shot(c: Dictionary) -> Dictionary:
	var out := c.duplicate(true) if not c.is_empty() else {"kinds": {}, "part": ""}
	out["form"] = "shot"
	return out


static func _gap(main, e) -> float:
	var p = main.get("player")
	if p == null or not is_instance_valid(p):
		return 0.0
	return maxf(0.0, p.global_position.distance_to(e.global_position) - float(e.radius))


static func _tally(e) -> Dictionary:
	var t = e.get("lesson_tally")
	if not (t is Dictionary):
		return {}
	for k in ["ess", "forms", "parts"]:
		if not (t.get(k) is Dictionary):
			t[k] = {}
	for k in ["dmg", "near", "rolls", "parries"]:
		if not t.has(k):
			t[k] = 0.0
	return t


## A blow landed on a guardian (before its lessons take anything off).
static func note_blow(main, e, amount: float, c: Dictionary) -> void:
	if amount <= 0.0:
		return
	var t := _tally(e)
	if t.is_empty():
		return
	if String(c.get("blade", "")) != "":
		# A Summit Blade's blow: it can't be fully learned (LEARN "blade").
		t["blade"] = float(t.get("blade", 0.0)) + amount
		amount *= clampf(float(LEARN.get("blade", 1.0)), 0.0, 1.0)
		if amount <= 0.0:
			return
	t["dmg"] = float(t["dmg"]) + amount
	var kinds: Dictionary = c.get("kinds", {})
	var sum := 0.0
	for k in kinds:
		sum += maxf(0.0, float(kinds[k]))
	if sum > 0.0:
		for k in kinds:
			t["ess"][k] = float(t["ess"].get(k, 0.0)) + amount * maxf(0.0, float(kinds[k])) / sum
	var g := String(c.get("form", ""))
	if g in GROUPS:
		t["forms"][g] = float(t["forms"].get(g, 0.0)) + amount
	var part := String(c.get("part", ""))
	if part != "":
		t["parts"][part] = float(t["parts"].get(part, 0.0)) + amount
	if _gap(main, e) < float(LEARN["near"]):
		t["near"] = float(t["near"]) + amount


## The climber rolled through an attack (player.gd on_dodge): every guardian
## fighting now notes it.
static func note_roll(main) -> void:
	if main == null:
		return
	for e in main.enemies():
		if is_guardian(main, e) and not e.dead:
			var t := _tally(e)
			if not t.is_empty():
				t["rolls"] = float(t["rolls"]) + 1.0


## The climber parried `source` (player.gd).
static func note_parry(main, source) -> void:
	if source is Node and is_guardian(main, source):
		var t := _tally(source)
		if not t.is_empty():
			t["parries"] = float(t["parries"]) + 1.0


# --- the lesson ---------------------------------------------------------------------------

## A guardian's tally made a lesson: {"beast", "ess": {kind: share}, "forms":
## {group: share}, "parts": {part: share}, "near": share up close, "rolls",
## "parries", "dmg"}. Shares are of all the damage done to it; the small ones
## (under "min_share") teach nothing. {} if it took no blows.
static func lesson(tally: Dictionary, beast := "") -> Dictionary:
	var dmg := float(tally.get("dmg", 0.0))
	if dmg <= 0.0:
		return {}
	var out := {"beast": beast, "ess": {}, "forms": {}, "parts": {}, "near": snappedf(clampf(float(tally.get("near", 0.0)) / dmg, 0.0, 1.0), 0.01),
		"rolls": int(tally.get("rolls", 0)), "parries": int(tally.get("parries", 0)), "dmg": int(round(dmg))}
	var blade := float(tally.get("blade", 0.0))
	if blade > 0.0:
		# (the share of the real damage a Summit Blade did: only for the rumours)
		var real := dmg + blade * (1.0 - clampf(float(LEARN.get("blade", 1.0)), 0.0, 1.0))
		out["blade"] = snappedf(clampf(blade / maxf(real, 0.01), 0.0, 1.0), 0.01)
	for key in ["ess", "forms", "parts"]:
		var d: Dictionary = tally.get(key, {})
		for k in d:
			var s := clampf(float(d[k]) / dmg, 0.0, 1.0)
			if s >= float(LEARN["min_share"]):
				out[key][String(k)] = snappedf(s, 0.01)
	return out


## The lessons kept: tower -> lesson.
static func lessons(prof) -> Dictionary:
	if prof == null:
		return {}
	var g = prof.get("guardians")
	if not (g is Dictionary):
		return {}
	return g


## A guardian fell (main.gd on_enemy_killed): its lesson is kept (the latest
## kill of each guardian replaces its own). Returns the lesson ({} for none).
static func learn(main, e) -> Dictionary:
	if not is_guardian(main, e):
		return {}
	var prof = main.profile
	var tw := String(main.get("tower"))
	if tw == "" or not Towers.TOWERS.has(tw):
		return {}
	var l := lesson(_tally(e), _beast_name(tw))
	if l.is_empty():
		return {}
	l["climb"] = int(prof.climbs)
	prof.guardians[tw] = l
	if main.has_method("tip"):
		main.tip("guardians_talk")  # (the first time: the guardians talk when one falls)
	return l


static func _beast_name(tw: String) -> String:
	return String(Towers.TOWERS.get(tw, {}).get("beast", tw))  # ("the Gryphon": a line that starts with it is capitalised in rumour)


## What a tower's guardian has learned from the others' deaths (every
## lesson but its own, adding up, each capped): {"resist": {kind: r},
## "part": {part: r}, "guard": {group: r}, "sidestep", "keep", "press",
## "timing", "count"}.
static func effects(prof, tower: String) -> Dictionary:
	var out := {"resist": {}, "part": {}, "guard": {}, "sidestep": 0.0, "keep": 0.0, "press": 0.0, "timing": 0.0, "count": 0}
	var all := lessons(prof)
	var cap := float(LEARN["cap"])
	for tw in all:
		if String(tw) == tower or not (all[tw] is Dictionary):
			continue
		var l: Dictionary = all[tw]
		out["count"] = int(out["count"]) + 1
		for k in l.get("ess", {}):
			out["resist"][k] = minf(cap, float(out["resist"].get(k, 0.0)) + float(LEARN["resist"]) * float(l["ess"][k]))
		for p in l.get("parts", {}):
			out["part"][p] = minf(cap, float(out["part"].get(p, 0.0)) + float(LEARN["part"]) * float(l["parts"][p]))
		var forms: Dictionary = l.get("forms", {})
		for g in forms:
			if LEARN["guard"].has(g):
				out["guard"][g] = minf(cap, float(out["guard"].get(g, 0.0)) + float(LEARN["guard"][g]) * float(forms[g]))
		out["sidestep"] = minf(float(LEARN["sidestep_cap"]), float(out["sidestep"]) + float(LEARN["sidestep"]) * float(forms.get("shot", 0.0)))
		var near := float(l.get("near", 0.5))
		var m := clampf((near - float(LEARN["melee_at"])) / maxf(0.01, 1.0 - float(LEARN["melee_at"])), 0.0, 1.0)
		var r := clampf((float(LEARN["ranged_at"]) - near) / maxf(0.01, float(LEARN["ranged_at"])), 0.0, 1.0)
		out["keep"] = minf(float(LEARN["steer_cap"]), float(out["keep"]) + float(LEARN["keep"]) * m)
		out["press"] = minf(float(LEARN["steer_cap"]), float(out["press"]) + float(LEARN["press"]) * r)
		var pa := minf(1.0, float(l.get("parries", 0)) / float(LEARN["parries_full"]))
		var ro := minf(1.0, float(l.get("rolls", 0)) / float(LEARN["rolls_full"])) * float(LEARN["roll_weight"])
		out["timing"] = minf(float(LEARN["timing_cap"]), float(out["timing"]) + float(LEARN["timing"]) * minf(1.0, pa + ro))
	return out


## The share of a blow its lessons take off (0 to "cap"): the blow's
## essences, its Node or mark, its form group.
static func reduction(fx: Dictionary, c: Dictionary) -> float:
	if fx.is_empty():
		return 0.0
	var red := 0.0
	var kinds: Dictionary = c.get("kinds", {})
	var sum := 0.0
	for k in kinds:
		sum += maxf(0.0, float(kinds[k]))
	if sum > 0.0:
		for k in kinds:
			red += float(fx["resist"].get(k, 0.0)) * maxf(0.0, float(kinds[k])) / sum
	red += float(fx["part"].get(String(c.get("part", "")), 0.0))
	red += float(fx["guard"].get(String(c.get("form", "")), 0.0))
	return clampf(red, 0.0, float(LEARN["cap"]))


## The guardian's lessons (worked out once, the first time it's asked).
static func of(main, e) -> Dictionary:
	if not is_guardian(main, e):
		return {}
	var fx = e.get("lessons")
	if fx is Dictionary and not fx.is_empty():
		return fx
	fx = effects(main.profile, String(main.get("tower")))
	e.set("lessons", fx)
	return fx


# --- in the fight (enemy.gd) ----------------------------------------------------------------

## A blow on a guardian (enemy.gd take_hit): noted for its lesson, then its
## lessons take their share; a shot may be sidestepped (never while it's
## staggered or recovering). Returns what's left of the blow.
static func taken(main, e, amount: float) -> float:
	if not is_guardian(main, e):
		return amount
	var c := ctx_of(main, e)
	note_blow(main, e, minf(amount, maxf(0.0, float(e.hp))), c)  # (an overkill counts only what it took)
	var fx := of(main, e)
	if fx.is_empty() or int(fx.get("count", 0)) <= 0:
		return amount
	if String(c.get("blade", "")) != "":
		# A Summit Blade keeps its edge: never sidestepped, and the lessons
		# take only a share of their toll (LEARN "blade_keep").
		return amount * (1.0 - reduction(fx, c) * clampf(float(LEARN.get("blade_keep", 1.0)), 0.0, 1.0))
	if String(c.get("form", "")) == "shot" and float(e.stun) <= 0.0 and float(e.open_t) <= 0.0 and randf() < float(fx["sidestep"]):
		_say(main, e, TEXT["sidestep"], Color(0.8, 0.85, 0.95))
		return 0.0
	var red := reduction(fx, c)
	if red >= 0.08:
		var g := String(c.get("form", ""))
		_say(main, e, TEXT["braced"] if float(fx["guard"].get(g, 0.0)) >= red * 0.5 else TEXT["resist"], Color(0.78, 0.74, 0.66))
	return amount * (1.0 - red)


## A wind-up's length: against a parrier, it may run a little longer (the
## glint still comes GLINT_LEAD before the blow).
static func wind(main, e, duration: float) -> float:
	var fx := of(main, e)
	if fx.is_empty() or float(fx.get("timing", 0.0)) <= 0.0:
		return duration
	return duration * (1.0 + randf() * float(fx["timing"]))


## Between attacks: backs off from a melee killer's style, presses in on a
## ranged one (enemy.gd, after its own moves; never during an attack).
static func steer(main, e, dir: Vector2, dist: float) -> void:
	if e.is_attacking() or dir == Vector2.ZERO:
		return
	var fx := of(main, e)
	if fx.is_empty():
		return
	if float(fx["keep"]) > 0.0 and dist < 130.0:
		e.velocity -= dir * float(e.speed) * 0.6 * float(fx["keep"])
	elif float(fx["press"]) > 0.0 and dist > 190.0 and dist < 9000.0:
		e.velocity += dir * float(e.speed) * 0.5 * float(fx["press"])


## A short flat word over the guardian, at most every 1.5 s.
static func _say(main, e, text: String, col: Color) -> void:
	var now := Time.get_ticks_msec()
	if now < int(e.get_meta("lesson_said", 0)):
		return
	e.set_meta("lesson_said", now + 1500)
	if main.has_method("fx_text"):
		main.fx_text(e.global_position + Vector2(0, -float(e.radius) - 46.0), text, col)


# --- rumours -------------------------------------------------------------------------------

## A rumour of what the guardians have learned ("" when they've learned
## nothing yet): a lesson picked, a guardian that learned it, and one true
## thing about it. `pick` steers the choice (tests; -1: at random).
static func rumour(prof, pick := -1) -> String:
	var facts := rumour_facts(prof)
	if facts.is_empty():
		return ""
	var f: Dictionary = facts[(pick if pick >= 0 else randi()) % facts.size()]
	var pool: Array = RUMOURS.get(String(f["kind"]), [])
	if pool.is_empty():
		return ""
	var text := String(pool[(pick if pick >= 0 else randi()) % pool.size()])
	for k in f:
		text = text.replace("{" + String(k) + "}", str(f[k]))
	if text.begins_with("\"") and text.length() > 1:
		text = "\"" + text.substr(1, 1).to_upper() + text.substr(2)  # ("the Kraken..." at the start of a line)
	return text


## Every true thing the rumours could say now: [{kind, beast, teacher, essence, group, node}].
static func rumour_facts(prof) -> Array:
	var out: Array = []
	var all := lessons(prof)
	var Ess = load("res://scripts/essence.gd")
	for tw in all:
		var l = all[tw]
		if not (l is Dictionary):
			continue
		var others: Array = Towers.ORDER.filter(func(o): return String(o) != String(tw))
		if others.is_empty():
			continue
		var beast := _beast_name(String(others[hash(String(tw) + str(l.get("climb", 0))) % others.size()]))
		var base := {"beast": beast, "teacher": String(l.get("beast", _beast_name(String(tw))))}
		var ess: Dictionary = l.get("ess", {})
		for k in ess:
			if float(ess[k]) >= 0.25:
				var f := base.duplicate()
				f["kind"] = "essence"
				f["essence"] = Ess.display(String(k))
				out.append(f)
		var forms: Dictionary = l.get("forms", {})
		for g in ["shot", "rush", "weapon", "close"]:
			if float(forms.get(g, 0.0)) >= 0.3:
				var f2 := base.duplicate()
				f2["kind"] = g
				f2["group"] = String(TEXT["group"].get(g, g))
				out.append(f2)
		var near := float(l.get("near", 0.5))
		if near >= float(LEARN["melee_at"]) + 0.15:
			var f3 := base.duplicate()
			f3["kind"] = "keep"
			out.append(f3)
		elif near <= float(LEARN["ranged_at"]) - 0.15:
			var f4 := base.duplicate()
			f4["kind"] = "press"
			out.append(f4)
		if int(l.get("parries", 0)) >= int(float(LEARN["parries_full"]) * 0.5):
			var f5 := base.duplicate()
			f5["kind"] = "timing"
			out.append(f5)
		var parts: Dictionary = l.get("parts", {})
		for p in parts:
			if float(parts[p]) >= 0.4:
				var f6 := base.duplicate()
				f6["kind"] = "part"
				f6["node"] = String(load("res://scripts/bonds.gd").PART_NAMES.get(p, p)).to_lower()
				out.append(f6)
		if float(l.get("blade", 0.0)) >= float(LEARN["min_share"]):
			var f7 := base.duplicate()
			f7["kind"] = "blade"  # (a Summit Blade did much of it, and taught little)
			out.append(f7)
	return out


## A rumour with a lead-in, for a talker ("" when there's none).
static func told(prof) -> String:
	var r := rumour(prof)
	if r == "":
		return ""
	return String(TEXT["lead"][randi() % TEXT["lead"].size()]) + " " + r
