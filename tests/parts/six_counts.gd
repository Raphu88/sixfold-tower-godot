extends RefCounted
## Counts by sixes, the floors-and-progression side (the owner's rule: every
## count of things the player collects or chooses from divides by six, or
## is exactly three): puzzle kinds, floor tasks, room themes, renown ranks,
## medal drills and training lessons, tournament brackets, titles, camp
## cards, synergies, deeds and inscriptions. Then the twelve puzzles' four
## newest (the lanterns, the bells, the crucible, the pods: their solvers,
## each tower's two favourites) and the four newest floor tasks in play
## (the marked, the rifts, the urns, the wisp), the five new ranks (an old
## save moved across) and the two new brackets.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const Catalog := preload("res://scripts/puzzles/catalog.gd")
const Objectives := preload("res://scripts/objectives.gd")
const Themes := preload("res://scripts/themes.gd")
const Renown := preload("res://scripts/renown.gd")
const Stations := preload("res://scripts/stations.gd")
const Training := preload("res://scripts/training.gd")
const Synergies := preload("res://scripts/synergies.gd")
const Deeds := preload("res://scripts/deeds.gd")
const Ins := preload("res://scripts/inscriptions.gd")
const Items := preload("res://scripts/items.gd")
const Floors := preload("res://scripts/floors.gd")
const Towers := preload("res://scripts/towers.gd")
const Entity := preload("res://scripts/entity.gd")
const Notes := preload("res://scripts/entity_notes.gd")
const Shop := preload("res://scripts/shop.gd")
const Tournaments := preload("res://scripts/tournaments.gd")
const NEW_PUZZLES := ["lanterns", "bells", "crucible", "pods"]
const NEW_TASKS := ["marked", "rifts", "urns", "wisp"]

var t


func run(smoke) -> void:
	t = smoke
	_counts()
	_puzzles()
	await t._fresh_main()
	var main = t.main
	main.profile.regarded = true
	main.first_climb = false
	_ranks()
	await _tasks_in_play()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


static func sixes(n: int) -> bool:
	return n > 0 and (n % 6 == 0 or n == 3)


## Every list's size follows the rule.
func _counts() -> void:
	print("counts by sixes: floors and progression")
	var shared: Array = Objectives.KINDS.keys().filter(func(k): return Objectives.KINDS[k].get("towers", []).is_empty())
	var own: Array = Objectives.KINDS.keys().filter(func(k): return not Objectives.KINDS[k].get("towers", []).is_empty())
	var ins := 0
	for k in Ins.INSCRIPTIONS:
		ins += Ins.INSCRIPTIONS[k].size()
	var lists := {
		"puzzle kinds": Catalog.TYPES.size(), "floor tasks": Objectives.KINDS.size(), "shared floor tasks": shared.size(), "towers' own floor tasks": own.size(),
		"room themes": Themes.THEMES.size(), "renown ranks": Renown.RANKS.size(), "what each rank opens": Renown.RANK_OPENS.size(),
		"medal drills": Stations.DRILLS.size(), "drills in order": Stations.DRILL_ORDER.size(), "basic lessons": Stations.LESSON_ORDER.size(), "basic training steps": load("res://scripts/tutorial.gd").STEPS.size(),
		"advanced lessons": Training.ADVANCED_ORDER.size(), "mark lessons": Training.MARK_ORDER.size(), "advanced tiers": Training.TIERS.size(),
		"tournament brackets": Stations.BRACKETS.size(), "titles": Renown.TITLES.size(), "titles in order": Renown.TITLE_ORDER.size(),
		"camp cards": int(Items.CAMP_CARDS), "synergies": Synergies.SYNERGIES.size(),
		"deeds": Deeds.DEEDS.size(), "inscriptions": ins, "the outfitter's stock rows": Shop.RANK_STOCK.size(),
	}
	var off: Array = []
	for name in lists:
		if not sixes(int(lists[name])):
			off.append("%s %d" % [name, int(lists[name])])
	_check(off.is_empty(), "every list counts by sixes, or is exactly three (%s)" % [lists if off.is_empty() else off])
	_check(Catalog.TYPES.size() == 12 and shared.size() == 12 and own.size() == 6 and Themes.THEMES.size() == 66 and Renown.RANKS.size() == 12
		and Stations.DRILLS.size() == 12 and Stations.BRACKETS.size() == 6 and Renown.TITLES.size() == 18,
		"the agreed targets: 12 puzzles, 12 shared tasks and 6 of the towers' own, 66 themes, 12 ranks, 12 drills, 6 brackets, 18 titles")
	_check(Renown.RANK_OPENS.size() == Renown.RANKS.size() and Shop.RANK_STOCK.size() == Renown.RANKS.size(), "a row of openings and of stock for every rank")
	_check(Stations.DRILL_ORDER.all(func(id): return Stations.DRILLS.has(id)) and Renown.TITLE_ORDER.all(func(id): return Renown.TITLES.has(id)), "the orders list every drill and title")


## The new puzzles: in every tower, at every tier; solvable by their own
## solvers; each tower's two favourites; themes, door emblems and the Entity's words.
func _puzzles() -> void:
	print("counts by sixes: the twelve puzzles")
	var ok_plan := true
	var why: Array = []
	for kind in NEW_PUZZLES:
		Catalog.forced = kind
		for i in 6:
			var fl: int = [2, 5, 9][i % 3]
			var tid: String = Towers.ORDER[i]
			var plan: Dictionary = Floors.rooms_floor(fl, Towers.TOWERS[tid])
			var pz: Dictionary = plan.get("puzzle", {})
			var good: bool = pz.get("type", "") == kind and int(pz.get("tier", 0)) == Catalog.tier_for(fl)
			if good:
				var gi: int = plan["room_info"].map(func(ri): return ri["role"]).find("gallery")
				good = plan["themes"][gi] == "puzzle_" + kind
			if good:
				good = _solvable(kind, pz)
			if not good:
				why.append("%s %s %d" % [kind, tid, fl])
			ok_plan = ok_plan and good
	Catalog.forced = ""
	_check(ok_plan, "the lanterns, the bells, the crucible and the pods fit in every tower's halls, at every tier, and their solvers find the answer %s" % [why])
	var fav := true
	var all_favs := {}
	for tid in Towers.ORDER:
		var two: Array = Catalog.SIGNATURE.get(tid, [])
		fav = fav and two.size() == 2 and two.all(func(k): return Catalog.TYPES.has(k))
		for k in two:
			all_favs[k] = true
	_check(fav and all_favs.size() == Catalog.TYPES.size(), "each tower favours two of the twelve puzzles, and every puzzle is some tower's favourite")
	var words := true
	for kind in NEW_PUZZLES:
		var s = Catalog.TYPES[kind]
		words = words and Themes.THEMES.has("puzzle_" + kind) and Entity.TIPS.has("puzzle_" + kind) and Notes.TIDBITS.has("puzzle:" + kind)
		words = words and String(Themes.THEMES["puzzle_" + kind].get("emblem", "")) != "" and not s.TEXT.get("rule", []).is_empty()
	for kind in NEW_TASKS:
		var k: Dictionary = Objectives.KINDS[kind]
		words = words and Notes.TIDBITS.has("task:" + kind) and String(k.get("hint", "")) != "" and String(k.get("name", "")) != ""
	_check(words, "each new puzzle has its hall, door emblem, rule, Entity tip and tidbit; each new task its name, hint and tidbit")
	var lairs := true
	for id in ["roost", "wreck", "tomb", "ashcrypt", "kennel"]:
		lairs = lairs and Themes.THEMES.has(id) and Themes.THEMES[id]["kind"] == "bad" and Themes.THEMES[id]["towers"].size() == 1 and Notes.TIDBITS.has("theme:" + id)
	_check(lairs, "five towers' own lairs: a den or an ambush in that tower only, each with the Entity's word")


## A puzzle spec has an answer, by the puzzle's own solver (as the floor bot plays it).
func _solvable(kind: String, pz: Dictionary) -> bool:
	match kind:
		"lanterns":
			var lit: Array = pz["lanterns"].map(func(q): return q["lit"])
			var s = Catalog.TYPES[kind].solve(lit, int(pz["cols"]), int(pz["rows_n"]))
			if s == null or s.is_empty():
				return false
			for i in s:
				Catalog.TYPES[kind]._press(lit, int(pz["cols"]), int(pz["rows_n"]), i)
			return lit.all(func(v): return v)
		"bells":
			return pz["song"].size() >= 3 and pz["song"].all(func(b): return int(b) >= 0 and int(b) < pz["bells"].size())
		"crucible":
			var rk := {}
			for r in pz["rocks"]:
				rk[r] = true
			var s = Catalog.TYPES[kind].solve(pz["start"], pz["goal"], rk, int(pz["cols"]), int(pz["rows_n"]))
			var least: int = int(Catalog.TYPES[kind].GRID[int(pz["tier"])][3])
			return s != null and s.size() >= least
		"pods":
			return pz["pods"].size() == Catalog.TYPES[kind].PODS and String(pz["want"]) in Catalog.TYPES[kind].HEADS
	return false


## Twelve ranks: the old seven keep their thresholds, the steps widen, and
## an old save's rank and brackets won are moved across.
func _ranks() -> void:
	print("counts by sixes: renown ranks, drills and brackets")
	var widen := true
	for i in range(4, Renown.RANKS.size()):  # (from Known up: the first steps were set before)
		widen = widen and int(Renown.RANKS[i][2]) - int(Renown.RANKS[i - 1][2]) >= int(Renown.RANKS[i - 1][2]) - int(Renown.RANKS[i - 2][2])
	var kept := true
	var old_pts := [0, 25, 60, 120, 200, 320, 480]
	for i in Renown.OLD_RANKS.size():
		kept = kept and int(Renown.RANKS[Renown.OLD_RANKS[i]][2]) == int(old_pts[i])
	_check(widen and kept, "the ranks' steps widen as you rise from Known, and the seven older ranks keep their thresholds (slow growth)")
	var drills := true
	for i in Renown.RANK_OPENS.size():
		for e in Renown.RANK_OPENS[i]:
			if String(e.get("kind", "")) == "drill":
				drills = drills and Stations.DRILLS.has(String(e["id"])) and int(Stations.DRILLS[e["id"]]["rank"]) == i and Renown.open_text(e).contains(String(Stations.DRILLS[e["id"]]["name"]))
			if String(e.get("kind", "")) == "bracket":
				drills = drills and int(Stations.bracket(String(e["id"])).get("rank", -1)) == i
	_check(drills, "each new rank opens something: a medal drill or a bracket, said in words, matching the drill's and bracket's own ranks")
	var ranked := true
	for i in range(1, Stations.BRACKETS.size()):
		var a: Dictionary = Stations.BRACKETS[i - 1]
		var b: Dictionary = Stations.BRACKETS[i]
		ranked = ranked and int(b["rank"]) > int(a["rank"]) and int(b["floor"]) > int(a["floor"]) and int(b["renown"]) > int(a["renown"]) and int(b["fee"]) > int(a["fee"])
		ranked = ranked and Tournaments.BRACKET_CREATURES.has(String(b["id"]))
	_check(ranked, "the six brackets climb in rank, toughness, fee and prize, each with its first round's creatures")
	var medals := true
	for id in ["bullseye", "shell", "perfect", "hunted", "dance"]:
		var d: Dictionary = Stations.DRILLS[id]
		var m: Array = d["medals"]
		medals = medals and Stations.medal_for(id, float(m[2])) == 3 and Stations.medal_for(id, float(m[0])) == 1 and Stations.drill_goal(id).find("%") < 0
	_check(medals, "the five new drills score bronze to gold at their marks, their goals' numbers filled in")
	# An old save: Respected (old rank 3) was shown, the Masters' Bracket (old 3) won.
	var prof = t.main.profile if t.main != null else null
	if prof == null:
		return
	var keep = prof.renown
	prof.renown = {"points": 130, "rank_seen": 3, "tiers": {"1": true, "3": true, "3_n": 2}}
	var r := Renown.state(prof)
	_check(int(r["rank_seen"]) == 4 and Renown.rank(prof) == 4 and Renown.unseen_rank(prof) < 0, "an old save's rank moment stays shown on the new ladder (Respected: %d)" % int(r["rank_seen"]))
	var masters := str(Stations.bracket_number("masters"))
	_check(bool(r["tiers"].get("1", false)) and bool(r["tiers"].get(masters, false)) and int(r["tiers"].get(masters + "_n", 0)) == 2 and not r["tiers"].has("3"),
		"...and the brackets it won keep their names (the Masters' Bracket is now bracket %s)" % masters)
	Renown.state(prof)
	_check(r["tiers"].has(masters) and int(r["ladder"]) == Renown.LADDER, "...moved only once")
	prof.renown = keep


## The four new floor tasks, each played to done by hand.
func _tasks_in_play() -> void:
	print("counts by sixes: the four new floor tasks in play")
	var main = t.main
	var p = main.player
	for kind in NEW_TASKS:
		Objectives.forced = kind
		main._start_floor(4)
		Objectives.forced = ""
		await t._frames(2)
		var ob = main.objective
		_check(ob.kind == kind and main.ward and not ob.pieces.is_empty() and ob.status_line() != "", "%s: the floor's task, warding the stair (%s)" % [kind, ob.status_line()])
		if ob.kind != kind:
			continue
		match kind:
			"marked":
				var marked: Array = main.enemies().filter(func(e): return e.has_meta("marked"))
				_check(marked.size() == ob.pieces.size(), "marked: a marked creature for every piece (%d)" % marked.size())
				for e in marked:
					t._slay(e)
				await t._frames(3)
			"rifts", "urns":
				for e in main.enemies():
					e.queue_free()
				await t._frames(1)
				for pc in ob.pieces.duplicate():
					if ob.done:
						break
					var n: int = int(Objectives.KINDS["rifts"]["strikes"]) if kind == "rifts" else 1
					for i in n:
						p.global_position = pc["pos"] + Vector2(0, 36)
						ob.strike(p.global_position, Vector2.UP, 50.0, 60.0)
					if kind == "urns" and ob.pieces.find(pc) == ob.key_urn:
						_check(ob.done, "urns: breaking the one with the key finishes it at once")
				for e in main.enemies():
					e.queue_free()
				await t._frames(2)
			"wisp":
				for e in main.enemies():
					e.queue_free()
				await t._frames(1)
				var w: Dictionary = ob.pieces[0]
				p.global_position = w["pos"]
				await t._frames(3)
				_check(ob.wisp_state == "follow", "wisp: it follows once you come close")
				var spook = main.spawn_enemy("slime", w["pos"] + Vector2(40, 0))
				await t._frames(3)
				_check(ob.wisp_state == "hide", "wisp: it hides while a creature is near it")
				spook.queue_free()
				await t._frames(2)
				p.global_position = ob.pedestal
				w["pos"] = ob.pedestal + Vector2(0, 50)
				for i in 120:
					if ob.done:
						break
					await t._frames(1)
		_check(ob.done and not main.ward, "%s: done, the ward lifts" % kind)
		if main.camp_choosing:
			main.choose_camp(0)
		await t._frames(1)
