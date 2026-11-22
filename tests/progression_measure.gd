extends SceneTree
## A measure, not a check: how many climbs a typical climber needs for each
## step of their first mark, and for a second mark (tests/progression_model.gd
## runs the game's own bookkeeping over climbs of measured essence).
##
## Run: godot --headless -s tests/progression_measure.gd
##   "plans": measure the essence per floor again from real floor plans
##   (every tower, several plans a floor) and print the tables to copy into
##   progression_model.gd (ESSENCE, KILLS, MIX).

const Model := preload("res://tests/progression_model.gd")


func _init() -> void:
	if "plans" in OS.get_cmdline_user_args():
		_plans()
	else:
		report()
	quit()


static func report() -> void:
	var P = load("res://scripts/profile.gd")
	print("STEP_XP (depth) %s  use %s  burn %s  (tinctures: STEP_RATE %.3f  AFFINITY %.2f  OTHER %.2f)" % [P.STEP_XP, load("res://scripts/mark_use.gd").USE, load("res://scripts/mark_use.gd").BURN, P.STEP_RATE, P.AFFINITY_WEIGHT, P.OTHER_WEIGHT])
	print("pattern    earned | step2 step3 step4 step5 step6 step12 | 2nd mark | growth after climbs 1,3,5,10,20,30")
	for pat in Model.PATTERNS:
		for earned in [false, true]:
			var r: Dictionary = Model.run(pat, 40, earned)
			var c: Dictionary = Model.climbs_to_steps(r["steps"])
			var xp: Array = r["xp"]
			print("%-10s %-6s |  %3s   %3s   %3s   %3s   %3s   %3s   |   %3s    | %d %d %d %d %d %d" % [pat, "yes" if earned else "no",
				_n(c[2]), _n(c[3]), _n(c[4]), _n(c[5]), _n(c.get(6, 0)), _n(c.get(12, 0)), _n(r["second"]),
				xp[0], xp[2], xp[4], xp[9], xp[19], xp[29]])
	var push: Dictionary = Model.tincture_push()
	var bits := []
	for st in push:
		bits.append("step %d->%d: %d%%" % [st, st + 1, roundi(float(push[st]) * 100.0)])
	print("one tincture of its own kind: ", ", ".join(bits))


static func _n(v) -> String:
	return "-" if int(v) <= 0 else str(v)


func _plans() -> void:
	var Floors = load("res://scripts/floors.gd")
	var Towers = load("res://scripts/towers.gd")
	var Items = load("res://scripts/items.gd")
	var Essence = load("res://scripts/essence.gd")
	var RR = load("res://scripts/room_rewards.gd")
	var reps := 6
	seed(777)
	var per_floor := {}
	var kills_floor := {}
	var mix := {}
	for f in range(1, 13):
		per_floor[f] = 0.0
		kills_floor[f] = 0.0
	var n := 0
	for tid in Towers.ORDER:
		var tw: Dictionary = Towers.TOWERS[tid]
		mix[tid] = {}
		for r in reps:
			n += 1
			for f in range(1, 13):
				var kinds: Array = []
				var chests := 0
				if f == 6:
					kinds = [tw["sentinel"], tw["sentinel_adds"], tw["sentinel_adds"], tw["beast_kind"]]
				elif f == 12:
					kinds = [tw["beast_kind"]]
				else:
					var plan: Dictionary = Floors.rooms_floor(f, tw, false)
					for m in plan.get("monsters", []):
						kinds.append(m[0])
					chests = plan.get("chests", []).size()
				var e := 0.0
				for k in kinds:
					var d: Array = Essence.drop_for(k, f)
					e += float(d[1]) + Towers.ESSENCE_BONUS
					mix[tid][d[0]] = float(mix[tid].get(d[0], 0.0)) + float(d[1])
					mix[tid][tw["essence"]] = float(mix[tid].get(tw["essence"], 0.0)) + Towers.ESSENCE_BONUS
					e += float(Items.DROPS["essence_chance"]) * (float(Items.DROPS["essence_base"]) + float(Items.DROPS["essence_per_floor"]) * f)
				for c in chests:
					var ess: float = float(RR.RULES["chest_base"]) + float(RR.RULES["chest_per_floor"]) * f
					e += ess * (float(RR.RULES["item_chance"]) + (1.0 - float(RR.RULES["item_chance"])) * float(RR.RULES["no_item"]))
				per_floor[f] += e
				kills_floor[f] += kinds.size()
	var es := []
	var ks := []
	for f in range(1, 13):
		es.append("%.1f" % snappedf(per_floor[f] / n, 1.0))
		ks.append("%.1f" % (kills_floor[f] / n))
	print("const ESSENCE := [", ", ".join(es), "]")
	print("const KILLS := [", ", ".join(ks), "]")
	for tid in mix:
		var tot := 0.0
		for k in mix[tid]:
			tot += mix[tid][k]
		var parts := []
		for k in mix[tid]:
			parts.append("\"%s\": %.2f" % [k, mix[tid][k] / tot])
		print("\t\"%s\": {%s}," % [tid, ", ".join(parts)])
