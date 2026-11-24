extends RefCounted
## Portals, pocket dimensions, pocket vaults and the floor map (portals.gd,
## vaults.gd, floor_map.gd, floors.gd _portals, wings.gd's secret rooms):
## where the floor's portals stand (reachable, never past a lock), asleep
## until a challenge is done or the floor is cleared, travel through the map
## (keys, clicks, a finger: tap to choose, hold to ask), the hidden wall's
## portal to a pocket dimension and back (the floor waits, the fog shows only
## where you are), the vault's three chests (gear a rarity up, crystals, a
## mimic, a lead) and its guards (a Tithe Stone, runes, a Keeper), a Maker's
## portal, and the Entity's words for all of it. Everything is seeded or
## driven directly, so nothing here depends on luck.
## Run by smoke_test.gd (_part_tests); `t` is the smoke test.

const Floors := preload("res://scripts/floors.gd")
const Reach := preload("res://scripts/reach.gd")
const Towers := preload("res://scripts/towers.gd")
const Portals := preload("res://scripts/portals.gd")
const Vaults := preload("res://scripts/vaults.gd")
const Entity := preload("res://scripts/entity.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const Help := preload("res://scripts/entity_help.gd")
const Gear := preload("res://scripts/gear.gd")
const Proving := preload("res://scripts/proving.gd")

var t
var main


func run(smoke) -> void:
	t = smoke
	_plans()
	await t._fresh_main()
	main = t.main
	main.grant_test_bonds()
	main.player.iframes = 9999.0
	await _asleep_and_waking()
	await _travel()
	await _map_screen()
	await _pocket()
	await _vault()
	await _guards()
	await _maker_portal()
	await _none_on_six()
	_words()
	await t._fresh_main()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


# --- where they stand ----------------------------------------------------------------------

func _plans() -> void:
	print("portals: where they stand on planned floors")
	var floors := 0
	var bad := {}
	var with_entrance := 0
	var with_stair := 0
	var counts := {}
	for tid in Towers.ORDER:
		for i in 18:
			seed(4100 + i * 7 + tid.length())
			var n := 2 + i % 10
			if n == 6:
				n = 7
			var plan: Dictionary = Floors.rooms_floor(n, Towers.TOWERS[tid])
			if not plan.has("room_info"):
				continue
			floors += 1
			var pts: Array = plan.get("portals", [])
			counts[pts.size()] = int(counts.get(pts.size(), 0)) + 1
			if pts.size() > Floors.portal_count(n):
				bad["no more than the floor's count (3, or 6 from floor 10)"] = true
			var info: Array = plan["room_info"]
			var rooms: Array = pts.map(func(p): return int(p["room"]))
			if 0 in rooms:
				with_entrance += 1
			for p in pts:
				var r: int = p["room"]
				if String(info[r]["role"]) == "gallery" or String(info[r]["theme"]) == "strongroom":
					bad["never in the gallery or a strongroom"] = true
				if not info[r]["rect"].has_point(p["pos"]):
					bad["inside its room"] = true
				for s in plan.get("secrets", []):
					if s["rect"].grow(40.0).has_point(p["pos"]):
						bad["never in a pocket dimension"] = true
			for j in info.size():
				if String(info[j]["role"]) == "stair" and j in rooms:
					with_stair += 1
			var chk: Dictionary = Reach.plan_check(plan)
			if not chk.get("portals", []).is_empty():
				bad["every portal can be walked to"] = true
			# Through no locked or barred door from the start.
			var grid: Dictionary = Reach.plan_grid(plan)
			var doors: Array = []
			for d in plan.get("doors", []):
				doors.append({"tiles": d["tiles"], "lock": String(d.get("lock", "")), "lock_id": int(d.get("lock_id", 0))})
			for w in plan.get("wings", []):
				doors.append({"tiles": w["door"], "lock": String(w.get("lock", "")), "lock_id": int(w.get("lock_id", 0))})
			var f: Dictionary = Reach.flood(grid["size"], grid["solid"], Reach.tile(plan["start"]), doors, {})
			for p in pts:
				if not Reach.near_reached(f["reach"], grid["size"], p["pos"]) and plan.get("gates", []).is_empty():
					bad["walked to from the start through no lock"] = true
			# Pocket dimensions: no way in on foot.
			for s in plan.get("secrets", []):
				if s["corridor"].size != Vector2(Floors.CELL, Floors.CELL) or not s["corridor"].has_point(Floors.ORIGIN + (Vector2(s["mouth"][0]) + Vector2(0.5, 0.5)) * Floors.CELL):
					bad["a pocket's only carved tile is its hidden spot"] = true
	_check(floors >= 90, "planned floors to look at (%d)" % floors)
	_check(bad.is_empty(), "the floor's portals: %s" % ("in rooms you can walk to through no lock, never in the gallery, a strongroom or a pocket, no more than the count" if bad.is_empty() else "FAILED " + str(bad.keys())))
	_check(with_entrance >= floors * 0.9 and with_stair >= floors * 0.9, "...one in the entrance (%d of %d) and one in the stair hall (%d)" % [with_entrance, floors, with_stair])
	_check(int(counts.get(0, 0)) == 0, "...and every floor of rooms has some (%s)" % [counts])
	seed(Time.get_ticks_usec())


## A floor of the current tower with portals (and a secret room if
## `secret`, of guard `content` when given), its monsters gone.
func _floor(secret := false, content := "", clear := true, wing := false) -> Dictionary:
	for n in 160:
		seed(9000 + n)
		var fl := 3 + n % 6
		if fl == 6:
			fl = 7
		main._start_floor(fl)
		await t._frames(1)
		var W = main.wings
		if main.portals.list.size() < 3 or (wing and W.wings.is_empty()):
			continue
		if secret and (W.secrets.is_empty() or (content != "" and String(W.secrets[0]["content"]) != content)):
			continue
		if clear:
			await t._clear_foes()
		main.open_all_doors()
		main.banner = {}
		main.camp_choosing = false
		main.player.set_physics_process(true)
		seed(Time.get_ticks_usec())
		return W.secrets[0] if secret else {"ok": true}
	return {}


func _stand(at: Vector2) -> void:
	main.portals._move_player(at)
	main.player.velocity = Vector2.ZERO


# --- asleep, and waking ----------------------------------------------------------------------

func _asleep_and_waking() -> void:
	print("portals: asleep until a challenge is done or the floor cleared")
	var P = main.portals
	P.auto_travel = true
	var ok := not (await _floor(false, "", false)).is_empty()
	_check(ok, "a floor with portals")
	if not ok:
		return
	_check(not P.awake, "they sleep as the floor begins")
	_stand(P.list[0]["pos"])
	P.armed = true
	await t._frames(3)
	_check(not P.map_open() and not P.awake and String(main.banner.get("title", "")) == String(Portals.TEXT["asleep"]).to_upper(), "stepping onto a sleeping one says it sleeps, and nothing opens")
	# The floor's task done: they wake.
	main.lift_ward()
	_check(P.awake and P.woke_why in ["task", "puzzle"] and Portals.TEXT["wake_also"] in main.banner.get("lines", []), "the floor's task done: every portal wakes, said under the task's own banner (%s)" % P.woke_why)
	# Every creature slain.
	await _floor(false, "", false)
	_check(not P.awake and not main.enemies().is_empty(), "(a new floor: asleep again)")
	await t._clear_foes()
	await t._frames(3)
	_check(P.awake and P.woke_why == "cleared", "every creature slain: they wake")
	# A sealed wing's challenge met.
	var found := not (await _floor(false, "", false, true)).is_empty()
	var W = main.wings
	_check(found, "a floor with a sealed wing")
	if found:
		var w: Dictionary = W.wings[0]
		w["state"] = "waves"
		W._finish(w, "open", "")
		_check(P.awake and P.woke_why == "wing", "the Regard's challenge in a sealed wing met: they wake")
		await _floor(false, "", false, true)
		w = W.wings[0]
		w["state"] = "waves"
		W._finish(w, "lesser", W.TEXT["failsafe"])
		_check(not P.awake, "...but not when the room gives up its question")
	_check(not P.wake("nonsense") and not P.awake, "nothing else wakes them")


# --- travel ----------------------------------------------------------------------------------

func _travel() -> void:
	print("portals: travel by the floor map")
	var P = main.portals
	await _floor()
	await t._frames(3)
	_check(P.awake, "(the floor cleared: awake)")
	_stand(P.list[0]["pos"] + Vector2(0, 80))
	await t._frames(2)
	_check(P.armed, "away from every portal, they answer")
	_stand(P.list[0]["pos"])
	await t._frames(3)
	_check(P.map_open() and t.paused and P.map.from == 0 and not (0 in P.map.targets()) and P.map.targets().size() == P.list.size() - 1,
		"stepping onto a woken portal opens the map to travel: the game waits, every other portal a choice")
	var m = P.map
	m.go(2 if P.list.size() > 2 else 1)
	var to: int = 2 if P.list.size() > 2 else 1
	await t._frames(2)
	_check(not P.map_open() and not t.paused and main.player.global_position.distance_to(P.list[to]["pos"]) < 2.0 and P.travels == 1,
		"choosing one steps you out of it, and the game goes on")
	await t._frames(3)
	_check(not P.map_open() and not P.armed, "...standing on it, it doesn't answer until you step off")
	# Keys: the arrows choose, Enter travels.
	_stand(P.list[to]["pos"] + Vector2(0, 90))
	await t._frames(2)
	_stand(P.list[to]["pos"])
	await t._frames(3)
	m = P.map
	_check(P.map_open(), "(the map again)")
	if P.map_open():
		var first: int = m.focus
		Input.action_press("ui_right")
		await t._frames(2)
		Input.action_release("ui_right")
		_check(m.focus != first and m.focus in m.targets(), "the arrows move the choice")
		var dest: int = m.focus
		Input.action_press("ui_accept")
		await t._frames(2)
		Input.action_release("ui_accept")
		await t._frames(1)
		_check(not P.map_open() and main.player.global_position.distance_to(P.list[dest]["pos"]) < 2.0, "...and Enter travels")
	# Esc stays.
	_stand(P.list[0]["pos"] + Vector2(0, 90))
	await t._frames(2)
	var here: Vector2 = P.list[0]["pos"]
	_stand(here)
	await t._frames(3)
	if P.map_open():
		Input.action_press("ui_cancel")
		await t._frames(2)
		Input.action_release("ui_cancel")
		await t._frames(1)
	_check(not P.map_open() and main.player.global_position.distance_to(here) < 2.0 and not main.menu_open(), "Esc closes it and you stay (the menu doesn't open)")
	# A shut room keeps you.
	main.door_view.lock_rooms[999] = {"state": "shut", "gates": [], "bodies": [], "mobs": [], "t": 0.0}
	_check(P.travel_block() == Portals.TEXT["shut"] and not P.travel(1), "while a room's doors are shut, the portals won't answer")
	main.door_view.lock_rooms.erase(999)
	# A tap travels; a held finger asks instead.
	_stand(P.list[0]["pos"] + Vector2(0, 90))
	await t._frames(2)
	_stand(P.list[0]["pos"])
	await t._frames(3)
	m = P.map
	if P.map_open():
		m._fit()
		var at: Vector2 = m.to_map(P.list[1]["pos"])
		var held := InputEventScreenTouch.new()
		held.index = 0
		held.position = at
		held.pressed = true
		m._input(held)
		m._press["t"] = m.t - 1.0
		await t._frames(2)
		_check(m.hover == "portal:1" and m.help_text() == m.TEXT["help_awake"], "holding a finger on a portal: the Entity says what it is")
		held.pressed = false
		m._input(held)
		await t._frames(1)
		_check(P.map_open(), "...and letting go after a hold chooses nothing")
		var tap := InputEventScreenTouch.new()
		tap.index = 0
		tap.position = at
		tap.pressed = true
		m._input(tap)
		tap.pressed = false
		m._input(tap)
		await t._frames(2)
		_check(not P.map_open() and main.player.global_position.distance_to(P.list[1]["pos"]) < 2.0, "a tap on a portal travels to it")
	P.auto_travel = false


# --- the map ---------------------------------------------------------------------------------

func _map_screen() -> void:
	print("portals: the floor map")
	var P = main.portals
	await _floor(false, "", false)
	_stand(main.player_start)
	await t._frames(3)
	_check(P.map_ready(), "on a floor of rooms the map can be opened")
	Input.action_press("floor_map")
	await t._frames(1)
	Input.action_release("floor_map")
	await t._frames(3)
	var m = P.map
	_check(P.map_open() and m.from == -1 and m.targets().is_empty() and t.paused, "O opens it to look: nothing to choose, the game waits")
	if P.map_open():
		m._fit()
		_check(m._room_seen(0) and not m._tiles.is_empty(), "it shows the rooms you've seen")
		var secret_tiles := 0
		for s in main.wings.secrets:
			var r: Rect2i = Floors.tile_rect(s["rect"])
			secret_tiles += m._tiles.filter(func(k): return r.has_point(k)).size()
		_check(secret_tiles == 0, "...never a pocket dimension")
		var mv := InputEventMouseMotion.new()
		mv.position = m.close_rect().get_center()
		m._input(mv)
		_check(m.hover == "close" and m.help_text() == m.TEXT["help_close"], "hovering Close: the Entity says what it does")
		m.hover = "portal:0"
		_check(m.help_text() == m.TEXT["help_asleep"], "...and of a sleeping portal: how they wake")
		m.hover = "you"
		_check(m.help_text() == m.TEXT["help_you"], "...and where you are")
		_check(m._at(m.to_map(main.player.global_position)) in ["you", "portal:0"], "(you show where you stand)")
		var vs: Vector2 = m._view()
		_check(Rect2(Vector2.ZERO, vs).encloses(m.close_rect()) and m._map_area().size.x > 100.0 and m._map_area().size.y > 100.0, "its buttons and map fit the screen")
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = true
		click.position = m.close_rect().get_center()
		m._input(click)
		await t._frames(2)
	_check(not P.map_open() and not t.paused, "Close shuts it, and the game goes on")
	# The pause menu's Floor map, and a phone's Map button.
	main.menu.open("pause")
	await t._frames(2)
	var btn = null
	for b in main.menu.find_children("*", "Button", true, false):
		if b.has_meta("help") and b.get_meta("help") == "floor_map":
			btn = b
	_check(btn != null and Help.HELP.has("floor_map"), "the pause menu has Floor map, and the Entity explains it")
	if btn != null:
		btn.emit_signal("pressed")
		await t._frames(4)
		_check(P.map_open() and not main.menu_open(), "...which opens the map")
		P.close_map()
		await t._frames(2)
	var tb: Dictionary = t._touch_btn("map")
	_check(not tb.is_empty() and tb["action"] == "floor_map", "a phone has a Map button")
	main.portals.open_map()
	await t._frames(2)
	main.portals.close_map()
	await t._frames(2)
	main.climbing = true
	_check(not P.map_ready() and t._touch_btn("map").is_empty(), "...not while climbing a stair")
	main.climbing = false


# --- pocket dimensions -----------------------------------------------------------------------

func _pocket() -> void:
	print("portals: a pocket dimension")
	var P = main.portals
	var s := await _floor(true)
	_check(not s.is_empty(), "a floor with a secret room")
	if s.is_empty():
		return
	var W = main.wings
	var mouth: Vector2i = s["mouth"][0]
	_check(main.is_solid(s["portal_out"]) and main.is_solid(s["rect"].get_center()), "its hidden spot is wall, its room rock")
	# A finishing blow breaks the hidden spot open.
	var front: Vector2 = W._tile_center(mouth) - Vector2(s["into"]) * 40.0
	W.strike(front, Vector2(s["into"]), 60.0, 50.0, false)
	_check(not s["open"], "a lighter blow only knocks")
	W.strike(front, Vector2(s["into"]), 60.0, 50.0, true)
	_check(s["open"] and not main.is_solid(s["portal_out"]) and not main.is_solid(s["rect"].get_center()), "a finishing blow breaks it: a portal in the wall, the pocket open")
	var c0: Vector2 = s["rect"].get_center()
	_check(main.astar.get_id_path(main._tile_of(front), main._tile_of(c0)).is_empty(), "...and still no way to the pocket on foot")
	# A monster of the floor, to see that the floor waits.
	var foe = main.spawn_enemy("slime", front + Vector2(0, 0) - Vector2(s["into"]) * 120.0)
	foe.aware = true
	await t._frames(2)
	_stand(front)
	await t._frames(2)
	P.armed = true
	_stand(s["portal_out"])
	await t._frames(3)
	var pos: Vector2 = main.player.global_position
	_check(P.in_pocket() and s["rect"].has_point(pos), "stepping into its portal: you're in the pocket")
	await t._frames(3)
	var st: Vector2i = main._tile_of(main.player_start)
	var si: int = st.y * main.grid_size.x + st.x
	_check(main.fog.pocket.has_area() and main.fog.shade[si] >= 0.99, "...the fog shows only the pocket")
	_check(not foe.is_physics_processing(), "...and the floor waits: its monsters stand still")
	_check(main.check_stuck().is_empty(), "...(no lock gives way because the stair is out of reach from here)")
	# Back out.
	_stand(s["portal_in"] + Vector2(0, -80))
	await t._frames(2)
	_check(P.armed, "(stepped away from the portal back)")
	_stand(s["portal_in"])
	await t._frames(3)
	pos = main.player.global_position
	_check(not P.in_pocket() and pos.distance_to(front) < 60.0 and not main.fog.pocket.has_area(), "its portal leads back to where you came in")
	await t._frames(2)
	_check(foe.is_physics_processing(), "...and the floor goes on")
	var ci: Vector2i = main._tile_of(c0)
	_check(main.fog.shade[ci.y * main.grid_size.x + ci.x] >= 0.99, "from the floor the pocket stays dark")
	foe.queue_free()


# --- the vault -------------------------------------------------------------------------------

func _vault() -> void:
	print("portals: the pocket vault")
	var V = main.vaults
	var s := await _floor(true, "open")
	_check(not s.is_empty(), "an unguarded pocket vault")
	if s.is_empty():
		return
	var kinds: Array = s["chests"].map(func(c): return String(c["kind"]))
	_check(s["chests"].size() == 3 and "gear" in kinds and "crystals" in kinds and (kinds.has("small") or kinds.has("mimic")), "three chests: gear, crystals, and a small crystal or a mimic (%s)" % [kinds])
	main.wings._open_secret(s)
	main.portals.armed = true
	_stand(s["portal_out"])
	await t._frames(3)
	_check(main.portals.in_pocket() and s["vault"] == "open", "(in, unguarded)")
	for c in s["chests"]:
		c["kind"] = ["gear", "crystals", "small"][s["chests"].find(c)]
	s["lead"] = true
	var lead0 := Vaults.lead_count(main.profile, String(main.tower))
	var drops0: int = main.gear_drops.size()
	V.open_chest(s, s["chests"][0])  # (from where you arrived: walking up would take the piece straight into an empty slot)
	var got: Array = main.gear_drops.slice(drops0)
	_check(s["chests"][0]["taken"] and got.size() == 1 and Gear.rarity(got[0]["rec"]) != "common", "the gear chest: a piece a rarity up, Fine at the least (%s)" % (Gear.rarity(got[0]["rec"]) if got.size() == 1 else "none"))
	_stand(s["chests"][1]["pos"] + Vector2(0, 12))
	await t._frames(3)
	_check(main.camp_choosing and main.camp.get("choices", []).size() >= 3, "the crystal chest: a choice of crystals")
	if main.camp_choosing:
		main.choose_camp(0)
	var kind: String = main.tower_data()["essence"]
	var before: float = main.profile.crystal_total(kind)
	_stand(s["chests"][2]["pos"] + Vector2(0, 12))
	await t._frames(3)
	var gain: float = main.profile.crystal_total(kind) - before
	_check(s["chests"][2]["taken"] and gain > 0.0 and gain <= main.wings.crystal_amount() * 0.5, "the third: a small crystal of the tower's essence (%d, modest)" % int(gain))
	_check(Vaults.lead_count(main.profile, String(main.tower)) == lead0 + 1 and s["taken"], "a lead to the Summit Blade, kept in the profile, once the vault is emptied")
	# A mimic.
	var c: Dictionary = {"pos": s["rect"].get_center(), "kind": "mimic", "taken": false}
	s["chests"].append(c)
	var foes0: int = main.enemies().size()
	V.open_chest(s, c)
	await t._frames(2)
	_check(c["taken"] and main.enemies().size() == foes0 + 1 and main.enemies().any(func(e): return e.kind == "mimic"), "a mimic among them springs when opened")
	await t._clear_foes()
	s["chests"].erase(c)
	main.portals.armed = true
	_stand(s["portal_in"])
	await t._frames(2)


# --- guarded vaults --------------------------------------------------------------------------

func _guarded(content: String) -> Dictionary:
	var s := await _floor(true)
	if s.is_empty():
		return s
	s["content"] = content
	Vaults.lay_out(s, main.floor_num, false, Floors.CELL)
	main.wings._open_secret(s)
	main.portals.armed = true
	_stand(s["portal_out"])
	await t._frames(3)
	return s


func _guards() -> void:
	print("portals: guarded vaults")
	var V = main.vaults
	# A Tithe Stone.
	var s := await _guarded("tithe")
	if not s.is_empty():
		_check(s["vault"] == "sealed" and main.is_solid(s["tithe_pos"]), "a Tithe Stone stands in the pocket, the chests chained")
		_stand(s["chests"][0]["pos"] + Vector2(0, 12))
		await t._frames(3)
		_check(not s["chests"][0]["taken"], "...chained chests don't open")
		main.run_essence = {"fire": 5.0}
		_check(not V.pay_tithe(s) and s["vault"] == "sealed", "it won't take less than it asks (%d)" % int(s["cost"]))
		main.run_essence = {"fire": float(s["cost"]) + 4.0}
		_check(main.wings.pay_tithe(s) and s["vault"] == "open" and not main.is_solid(s["tithe_pos"]) and absf(float(main.run_essence["fire"]) - 4.0) < 0.01, "paid from unbanked essence: the stone sinks and the chains fall")
		main.run_essence = {}
	# The runes.
	s = await _guarded("puzzle")
	if not s.is_empty():
		_check(s["vault"] == "sealed" and float(s["show_t"]) >= 0.0 and s["runes"].size() == 3, "three runes light in an order as you arrive")
		s["show_t"] = -1.0
		var order: Array = s["order"]
		V.step_rune(s, order[1])
		_check(int(s["step"]) == 0 and float(s["show_t"]) >= 0.0 and s["vault"] == "sealed", "a wrong rune shows the order again")
		s["show_t"] = -1.0
		_stand(s["runes"][order[0]]["pos"])
		await t._frames(3)
		_check(s["runes"][order[0]]["lit"] and int(s["step"]) == 1, "stepping on the first one lights it")
		V.step_rune(s, order[1])
		V.step_rune(s, order[2])
		_check(s["vault"] == "open", "...all three in order: the chains fall")
	# A Keeper.
	s = await _guarded("keeper")
	if not s.is_empty():
		s["keeper_t"] = 0.0
		await t._frames(3)
		var k = s.get("keeper")
		_check(k != null and is_instance_valid(k) and k.champion and s["rect"].has_point(k.global_position) and s["vault"] == "sealed", "a Keeper rises in the vault, the chests chained")
		if k != null and is_instance_valid(k):
			t._slay(k)
		await t._frames(4)
		_check(s["vault"] == "open" and s["keeper_state"] == "done", "beaten, the chains fall")
		await t._clear_foes()
	main.portals.armed = true


# --- a Maker's portal ------------------------------------------------------------------------

func _maker_portal() -> void:
	print("portals: a Maker's portal")
	await _floor(false, "", true)
	var mk = main.makers
	mk.interrupt_chance = 0.0
	mk.start_meeting("towers")
	var v = mk.view
	await t._frames(3)
	_check(mk.meeting_live() and t.paused, "a Maker draws you into its pocket (the meeting shows)")
	mk.end_meeting({})
	await t._frames(1)
	_check(not mk.meeting_live() and not main.portals.closing.is_empty(), "...and lets you go through a portal that closes behind you")
	await t._frames(1)


# --- the Entity's words ----------------------------------------------------------------------

func _words() -> void:
	print("portals: the Entity explains them")
	for id in ["portal", "portal_awake", "pocket", "pocket_vault", "vault_guard", "floor_map", "maker_portal"]:
		_check(Entity.TIPS.has(id) and String(Entity.TIPS[id].get("tip", "")) != "" and String(Entity.TIPS[id].get("more", "")) != "", "the Entity's first-time word and fuller answer: %s" % id)
	_check(Talk.DIALOGUE.has("how_portals") and "how_portals" in Talk.DIALOGUE["how"]["choices"], "\"How does it work?\" asks about portals, pockets and the map")
	var bad: Array = []
	for table in [Portals.TEXT, Vaults.TEXT, load("res://scripts/floor_map.gd").TEXT]:
		for k in table:
			var w := String(table[k]).to_lower()
			for word in ["attunement", "spire", "trial", "judgment", "mana"]:
				if (" " + w + " ").contains(" " + word) and not w.contains("manag"):
					bad.append(k)
	_check(bad.is_empty(), "none of the forbidden words (%s)" % [bad])


# --- none on floor 6 ----------------------------------------------------------------------------

## Floor 6 (the Proving's, where the first climb's Regard opens too) is a set
## piece walked in order: no portals, planned or in play, whether it's the
## Proving's own layout or an ordinary floor of rooms (the Proving already won
## this climb). Floor 1, a camp and the summit have none either; floors 5 and
## 7 still do.
func _none_on_six() -> void:
	print("portals: none on floor 6, the Proving's and the Regard's floor")
	var six := int(Towers.PROVING["floor"])
	_check(Floors.portal_count(six) == 0 and Floors.portal_count(1) == 0 and Floors.portal_count(5) == 3 and Floors.portal_count(7) == 3,
		"the count: none on floor 6 or floor 1, three on floors 5 and 7")
	var planned := 0
	var near := 0
	for tid in Towers.ORDER:
		for i in 3:
			seed(7700 + i * 13 + tid.length())
			var plan: Dictionary = Floors.rooms_floor(six, Towers.TOWERS[tid])
			planned += plan.get("portals", []).size()
			planned += Proving.build_plan(Towers.TOWERS[tid]).get("portals", []).size()
			seed(7700 + i * 13 + tid.length())
			near += Floors.rooms_floor(7, Towers.TOWERS[tid]).get("portals", []).size()
	seed(Time.get_ticks_usec())
	_check(planned == 0 and near > 0, "no floor 6 plan holds a portal, the Proving's nor an ordinary one (%d), while floor 7's do (%d)" % [planned, near])
	await t._fresh_main()
	main = t.main
	main.grant_test_bonds()
	main.player.iframes = 9999.0
	var P = main.portals
	main.proving.enabled = true
	main._start_floor(six)
	await t._frames(2)
	_check(main.floor_plan.get("proving", false) and P.list.is_empty(), "the Proving's floor in play: no portals")
	P.wake("dev")
	_check(not P.awake, "...and nothing there to wake")
	main.proving.enabled = false
	main._start_floor(six)
	await t._frames(2)
	_check(main.layout_on and not main.floor_plan.get("proving", false) and P.list.is_empty(), "floor 6 as an ordinary floor of rooms: no portals either")
	main.floor_num = 3
	main._enter_camp([])
	await t._frames(2)
	_check(main.in_camp and P.list.is_empty(), "a camp: none")
	main.camp_choosing = false
	main.in_camp = false
	main.player.set_physics_process(true)
	main._start_floor(1)
	await t._frames(2)
	_check(P.list.is_empty(), "floor 1: none")
	main.dev_beast(main.tower)
	await t._frames(2)
	_check(main.floor_plan.get("summit", false) and P.list.is_empty(), "the summit: none")
