extends RefCounted
## The play screen's notifications in one scheme (notices.gd, hud.gd,
## guide.gd): banners take turns in the top-middle lane and expire; the
## status chips stack under them; pickups and news go to the left feed; the
## Entity's sphere, bubble and panel keep to the right; nothing overlaps
## anything else, the top-right buttons or the touch buttons, and nothing
## sits in the middle of the screen, on a computer and a phone at every
## Interface size. The Entity's log takes every kind of event (never
## damage), batches essence and keeps its cap; its panel opens and closes by
## click, tap and key; every tower has a tidbit and no lore. A puzzle's rule
## is said in the lane and read again at its "?" plaque. Run by
## smoke_test.gd (_part_tests).

const N := preload("res://scripts/notices.gd")
const L := preload("res://scripts/layout.gd")
const Notes := preload("res://scripts/entity_notes.gd")
const Guide := preload("res://scripts/guide.gd")
const Entity := preload("res://scripts/entity.gd")
const Towers := preload("res://scripts/towers.gd")
const UI := preload("res://scripts/ui.gd")
const Essence := preload("res://scripts/essence.gd")
const BANNED := ["attunement", "spire", "trial", "judgment", "mana"]

var t
var M = load("res://scripts/menu.gd")
var keep_ui := ""
var keep_size := Vector2i.ZERO
var keep_guide := {}
var keep_layout := {}


func run(smoke) -> void:
	t = smoke
	await _begin()
	await _banners()
	await _arrival()
	await _feed_and_log()
	await _floating()
	await _layout_ids()
	await _everywhere()
	await _panel()
	await _tidbits()
	await _puzzle_notes()
	await _end()


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _begin() -> void:
	keep_ui = String(M.settings["ui_size"])
	keep_size = t.root.size
	keep_guide = Guide.state.duplicate(true)
	keep_layout = L.snapshot()
	await t._fresh_main()
	t.paused = false
	var main = t.main
	main.touch._set_active(false)
	main.pad._set_active(false)
	main.grant_test_bonds()
	t.root.size = Vector2i(1280, 720)
	M.settings["ui_size"] = "normal"
	main.apply_view_scale()
	await t._frames(3)


func _end() -> void:
	var main = t.main
	Engine.remove_meta("sixfold_tips")
	Guide.state = keep_guide
	Guide.queue.clear()
	L.restore(keep_layout)
	main.touch._set_active(false)
	main.pad._set_active(false)
	M.settings["ui_size"] = keep_ui
	t.root.size = keep_size
	main.apply_view_scale()
	await t._frames(2)


## Banners: one at a time in the lane, taking turns, expiring.
func _banners() -> void:
	print("lanes: banners take turns in the top lane, and expire")
	var main = t.main
	var NS = main.notices
	main.banner = {}
	await t._frames(2)
	_check(NS.current.is_empty() and not NS.busy(), "an empty lane to start with")
	main.banner = {"title": "FIRST", "lines": ["One."], "t": 0.5}
	_check(NS.current.get("title", "") == "FIRST" and main.banner.get("title", "") == "FIRST", "a banner goes to the top lane at once")
	await t._frames(4)
	var r: Rect2 = main.hud.lane_rects()["banner"]
	var view: Vector2 = main.hud.get_viewport_rect().size
	_check(r.has_area() and r.end.y < view.y * 0.2 and absf(r.get_center().x - view.x * 0.5) < view.x * 0.12, "...at the top, in the middle (%s)" % r)
	_check(r.size.y <= 70.0, "...and compact: a title and a short line, not the old centre banner (%d px tall)" % int(r.size.y))
	await t._until(func(): return main.banner.is_empty(), 3.0)
	_check(main.banner.is_empty() and NS.current.is_empty(), "banners expire")
	# A second waits its turn; main.banner reads as the last one set.
	main.banner = {"title": "A", "lines": ["a"], "t": 3.0}
	main.banner = {"title": "B", "lines": ["b"], "t": 3.0}
	_check(NS.current.get("title", "") == "A" and NS.queue.size() == 1 and main.banner.get("title", "") == "B", "a second banner waits for the one showing")
	# A more important one takes its place.
	main.banner = {"title": "RESTART?", "lines": [], "t": 3.0, "pri": 2}
	_check(NS.current.get("title", "") == "RESTART?", "a more important banner replaces the one showing")
	var shown: int = NS.shown
	main.banner = {"title": "RESTART?", "lines": [], "t": 3.0, "pri": 2}
	_check(NS.shown == shown and NS.queue.size() == 1, "the same banner again (asked every frame) isn't shown twice")
	# A room's name never pushes another aside.
	main.banner = {"title": "DART HALL", "lines": ["The walls are watching."], "t": 2.8, "room": true}
	_check(NS.current.get("title", "") == "RESTART?" and N.pri(main.banner) == 0, "a room's name waits its turn")
	# The one showing gives way soon when another waits.
	main.banner = {}
	main.banner = {"title": "A", "lines": ["a"], "t": 3.0}
	main.banner = {"title": "B", "lines": ["b"], "t": 3.0}
	await t._until(func(): return NS.current.get("title", "") == "B", 2.6)
	_check(NS.current.get("title", "") == "B", "with another waiting, the banner showing gives way within a couple of seconds")
	# One too many waiting: the least important goes.
	main.banner = {}
	main.banner = {"title": "NOW", "lines": [], "t": 3.0}
	main.banner = {"title": "ROOM", "lines": [], "t": 3.0, "room": true}
	for i in N.QUEUE_MAX:
		main.banner = {"title": "NEXT %d" % i, "lines": [], "t": 3.0}
	_check(NS.queue.size() == N.QUEUE_MAX and not NS.queue.any(func(b): return b.get("title", "") == "ROOM"), "at most %d wait; the least important is dropped" % N.QUEUE_MAX)
	# Held a few seconds at most (a task a little longer).
	main.banner = {}
	main.banner = {"title": "LONG", "lines": ["x"], "t": 30.0}
	await t._frames(3)
	var plain := float(main.banner["t"])
	main.banner = {}
	main.banner = {"title": "TASK", "lines": ["x"], "t": 30.0, "long": true}
	await t._frames(3)
	_check(plain <= N.BANNER_MAX and float(main.banner["t"]) > plain and float(main.banner["t"]) <= N.BANNER_LONG, "a banner holds about three seconds, a floor's task a little longer")
	# Its other lines go to the left feed.
	main.banner = {}
	NS.feed_lines.clear()
	main.banner = {"title": "FLOOR 3", "lines": ["Rested: +12 health", "Banked 9 essence", "Light the Braziers"], "line": "Light the Braziers", "t": 3.0}
	await t._frames(3)
	var fed: Array = NS.feed_lines.map(func(f): return f["text"])
	_check("Rested: +12 health" in fed and "Banked 9 essence" in fed and not ("Light the Braziers" in fed) and NS.current["_rows"] == ["Light the Braziers"],
		"the lane shows one line; a banner's other lines go to the left feed")
	main.banner = {}
	NS.feed_lines.clear()
	await t._frames(2)


## A floor arrival by the stair: the floor and its task in the lane, what
## the stair gave in the feed and the log.
func _arrival() -> void:
	print("lanes: a floor arrival")
	var main = t.main
	var NS = main.notices
	main._start_floor(2)
	await t._frames(2)
	for e in main.enemies():
		e.set_physics_process(false)
	main.banner = {}
	NS.new_climb()
	main.run_essence["air"] = 14.0
	main._arrive()
	main.fade = 0.0
	await t._frames(3)
	var b: Dictionary = main.banner
	_check(b.get("title", "") == main._floor_title() and main.floor_num == 3, "arriving shows the floor in the lane (%s)" % b.get("title", ""))
	var task: bool = main.ward and main.objective != null and main.objective.kind != ""
	if task:
		_check(String(b.get("line", "")).contains(String(main.objective.spec.get("name", "?"))) and b.get("long", false), "...with the floor's task as its one line: %s" % b.get("line", ""))
		_check(NS.log.any(func(e): return e["kind"] == "task"), "...and the task is in the Entity's log")
	var banked: Array = NS.log.filter(func(e): return e["kind"] == "banked")
	_check(banked.size() == 1 and String(banked[0]["text"]).begins_with("Banked") and NS.feed_lines.any(func(f): return f["text"] == banked[0]["text"]),
		"what was banked at the stair goes to the left feed and the log, in the same words (%s; feed %s)" % [banked.map(func(e): return e["text"]), NS.feed_lines.map(func(f): return f["text"])])
	_check(NS.log.any(func(e): return e["kind"] == "floor"), "the floor reached is in the log")
	await t._frames(3)
	var chips: Array = main.hud.status_chips()
	_check(not task or chips.any(func(c): return c["id"] == "task"), "the task's progress is a status chip under the banner")
	main.banner = {}
	NS.feed_lines.clear()


## The feed and the Entity's log share one event source.
func _feed_and_log() -> void:
	print("lanes: the left feed and the log")
	var main = t.main
	var NS = main.notices
	var p = main.player
	NS.new_climb()
	for kind in N.KINDS:
		main.note_event(kind, "test " + kind)
	_check(N.KINDS.keys().all(func(k): return NS.log.any(func(e): return e["kind"] == k)), "an event of every kind lands in the log")
	_check(NS.feed_lines.size() <= N.FEED_MAX, "the feed keeps a few lines at most (%d)" % NS.feed_lines.size())
	NS.new_climb()
	main.note_event("room", "Entered Dart Hall")
	_check(NS.feed_lines.is_empty() and NS.log.size() == 1, "a room entered goes to the log, not the feed")
	main.note_event("item", "+ Healing Draught")
	main.loot_notice = {"text": "RARE: Axe of the Riposte", "color": Color(0.4, 0.6, 1.0), "t": 3.5}
	_check(NS.feed_lines.size() == 2 and NS.log.size() == 3 and NS.log[-1]["kind"] == "gear", "pickups and a Rare find go to both")
	main.loot_notice = {}
	await t._wait(0.2)
	var fr: Array = main.hud.lane_rects()["feed"]
	var corner: Rect2 = main.hud._corner_box(main.hud.get_viewport_rect().size)
	_check(fr.size() == 2 and fr.all(func(r): return r.position.y >= corner.end.y and r.end.x < main.hud.get_viewport_rect().size.x * 0.31) and fr[1].position.y >= fr[0].end.y,
		"the feed stacks down the left side, under the bars and slots")
	await t._until(func(): return NS.feed_lines.is_empty(), N.FEED_SHOW + 2.0)
	_check(NS.feed_lines.is_empty() and NS.log.size() == 3, "feed lines fade after a few seconds; the log keeps them")
	# Damage is never an event.
	NS.new_climb()
	var foes: Array = main.enemies()
	if not foes.is_empty():
		foes[0].take_hit(3.0, Vector2.RIGHT, 0.0)
	p.iframes = 0.0
	p.hurt_t = 0.0
	p.parry_t = 0.0
	var hp0: float = p.hp
	p.receive_attack(6.0, null)
	await t._frames(3)
	_check(p.hp < hp0 and NS.log.is_empty() and NS.feed_lines.is_empty(), "damage dealt and taken never reaches the log or the feed")
	# Essence is batched: one line per burst and kind.
	for i in 5:
		main.gather_essence("air", 3.0, p.global_position)
	var ess: Array = NS.log.filter(func(e): return e["kind"] == "essence")
	_check(ess.size() == 1 and ess[0]["text"] == String(N.TEXT["essence"]) % [15, Essence.display("air")], "five motes of essence are one log line: %s" % (ess[0]["text"] if not ess.is_empty() else "none"))
	main.gather_essence("water", 2.0, p.global_position)
	NS.tick(N.ESSENCE_BATCH + 0.1)
	main.gather_essence("air", 4.0, p.global_position)
	ess = NS.log.filter(func(e): return e["kind"] == "essence")
	_check(ess.size() == 3 and ess[2]["text"] == String(N.TEXT["essence"]) % [4, Essence.display("air")], "another kind, or a later burst, is its own line")
	_check(NS.feed_lines.is_empty(), "essence gathered isn't repeated in the feed (the unbanked counter shows it)")
	# Once a floor.
	NS.new_climb()
	main.note_event("reaction", "Reaction: Conduct", null, false, "reaction:conduct")
	main.note_event("reaction", "Reaction: Conduct", null, false, "reaction:conduct")
	_check(NS.log.size() == 1, "the first reaction of a kind on a floor is logged, not every one")
	NS.new_floor()
	main.note_event("reaction", "Reaction: Conduct", null, false, "reaction:conduct")
	_check(NS.log.size() == 1 and int(NS.log[0]["n"]) == 2, "...and the same thing twice running is counted, not repeated")
	# The cap.
	NS.new_climb()
	for i in N.LOG_KEEP + 30:
		main.note_event("item", "thing %d" % i)
	_check(NS.log.size() == N.LOG_KEEP and NS.recent().size() == N.LOG_SHOWN and NS.recent()[0]["text"] == "thing %d" % (N.LOG_KEEP + 29),
		"the log keeps its cap (%d kept, the last %d shown, newest first)" % [N.LOG_KEEP, N.LOG_SHOWN])
	NS.new_climb()


## Floating words in the world are short-lived and capped.
func _floating() -> void:
	print("lanes: floating combat text is capped")
	var main = t.main
	var p = main.player
	main.fx.texts.clear()
	for i in 30:
		main.fx_text(p.global_position + Vector2(i * 24.0, 0), "Parried %d" % i, Color.WHITE)
	_check(main.fx.text_count() <= main.fx.TEXT_MAX and main.fx.texts.all(func(x): return float(x["t"]) <= main.fx.TEXT_LIFE) and main.fx.TEXT_LIFE <= 1.0,
		"at most %d floating words show at once (%d of 30), each under a second" % [main.fx.TEXT_MAX, main.fx.text_count()])
	main.fx.texts.clear()
	main.fx_text(p.global_position, "Staggered", Color.WHITE)
	main.fx_text(p.global_position, "Staggered", Color.WHITE)
	main.fx_text(p.global_position, "12", Color.WHITE)
	main.fx_text(p.global_position, "12", Color.WHITE)
	_check(main.fx.texts.size() == 3, "the same word twice at once shows once; two hits are two numbers")
	main.fx.texts.clear()


## The lanes are layout elements; the old banner's ids are gone.
func _layout_ids() -> void:
	print("lanes: the layout's elements")
	var main = t.main
	_check(["hud.lane", "hud.status", "hud.feed", "hud.entity"].all(func(id): return L.has(id)) and not L.DROPPED.any(func(id): return L.has(id)),
		"the lane, the status lines, the feed and the Entity can be arranged; the old banner, floor title, beast bar and plate are gone")
	var parsed = L.parse('{"format":1,"desktop":{"hud.banner":{"anchor":"t","x":0,"y":200,"scale":1},"hud.feed":{"anchor":"tl","x":20,"y":130,"scale":1}},"touch":{"hud.floor":{"anchor":"t","x":0,"y":9,"scale":1}}}')
	_check(parsed != null and not parsed["desktop"].has("hud.banner") and parsed["desktop"].has("hud.feed") and parsed["touch"].is_empty(), "an old arrangement of a dropped element is left out when it's read")
	# Arranged, the lane stays where it's put.
	L.set_override("hud.lane", {"anchor": "t", "x": 0.0, "y": 150.0, "scale": 1.0})
	main.banner = {"title": "MOVED", "lines": ["Here."], "t": 3.0}
	await t._wait(0.5)
	var r: Rect2 = main.hud.lane_rects()["banner"]
	_check(r.has_area() and absf(r.position.y - 150.0 * main.hud.hud_scale) < 3.0, "an arranged lane draws its banner where it was put (%s)" % r)
	L.restore(keep_layout)
	main.banner = {}
	await t._frames(3)


func _circle_hits(c: Vector2, rad: float, r: Rect2) -> bool:
	var near := Vector2(clampf(c.x, r.position.x, r.end.x), clampf(c.y, r.position.y, r.end.y))
	return near.distance_to(c) < rad - 0.5


## A banner, a status chip, three feed lines and the Entity's sphere and
## bubble, all at once: nothing overlaps, nothing in the middle, at a
## computer's and a phone's size and every Interface size.
func _everywhere() -> void:
	print("lanes: everything at once, at every size")
	var main = t.main
	var NS = main.notices
	var hud = main.hud
	Engine.set_meta("sixfold_tips", true)
	Guide.state["on"] = true
	for id in Entity.TIPS:  # (the first-time tips have all been heard: only what this test says shows)
		Guide.state["told"][id] = true
		Guide.state["known"][id] = true
	main._start_floor(2)
	await t._frames(2)
	for e in main.enemies():
		e.set_physics_process(false)
	var side := {}
	# (the last: the tightest of all, a phone at the biggest Interface size AND the biggest HUD)
	for cfg in [["a computer", Vector2i(1280, 720), false, 1.0], ["a phone", Vector2i(915, 412), true, 1.0], ["a computer with a large HUD", Vector2i(1280, 720), false, 1.2],
			["a phone with a large HUD", Vector2i(915, 412), true, 1.2]]:
		for ui in UI.UI_SIZE_ORDER:
			hud.hud_scale = cfg[3]
			t.root.size = cfg[1]
			main.touch._set_active(cfg[2])
			main.pad._set_active(false)
			M.settings["ui_size"] = ui
			main.apply_view_scale()
			main.banner = {}
			NS.new_climb()
			Guide.queue.clear()
			main.entity.current = {}
			main.entity.lane = false
			main.entity.gap_t = 0.0
			main.entity.new_climb()
			main.entity.bit_at = -1000000
			main.entity.open = false
			await t._frames(4)
			main.banner = {"title": "THE DOORS GRIND SHUT", "lines": ["Slay what's inside."], "t": 3.0}
			main.note_event("item", "+ Healing Draught")
			main.note_event("gear", "+ Fine Leather Gloves")
			main.note_event("renown", "Renown: +8")
			var said: bool = main.entity.remark("pact")
			await t._until(func(): return main.entity.showing(), 2.0)
			await t._wait(0.6)
			var view: Vector2 = hud.get_viewport_rect().size
			var rects: Dictionary = hud.lane_rects()
			var parts: Array = [["banner", rects["banner"]]]
			for i in rects["chips"].size():
				parts.append(["chip %d" % i, rects["chips"][i]])
			for i in rects["feed"].size():
				parts.append(["feed %d" % i, rects["feed"][i]])
			parts.append(["sphere", main.entity.orb_rect])
			var beside: bool = main.entity.showing() and not main.entity.lane and main.entity.rect.has_area()
			if beside:
				parts.append(["bubble", main.entity.rect])
			side["%s %s" % [cfg[0], ui]] = beside
			var bad: Array = []
			if not said or not main.entity.showing():
				bad.append("the Entity said nothing")
			if not main.entity.lane and not beside:
				bad.append("no bubble")
			if not rects["banner"].has_area():
				bad.append("no banner")
			if rects["chips"].is_empty():
				bad.append("no status chip")
			if rects["feed"].size() != 3 and not NS.left_mode:  # (the lane on the left of a tiny screen: as many as fit under it)
				bad.append("%d feed lines" % rects["feed"].size())
			if not main.entity.orb_rect.has_area():
				bad.append("no sphere")
			var centre := Rect2(view * 0.3, view * 0.4)
			var screen := Rect2(Vector2.ZERO, view)
			for i in parts.size():
				var r: Rect2 = parts[i][1]
				if not r.has_area():
					continue
				if not screen.grow(1.0).encloses(r):
					bad.append("%s off the screen %s" % [parts[i][0], r])
				if centre.intersects(r):
					bad.append("%s in the middle %s" % [parts[i][0], r])
				for j in range(i + 1, parts.size()):
					if parts[j][1].has_area() and r.grow(-0.5).intersects(parts[j][1]):
						bad.append("%s over %s" % [parts[i][0], parts[j][0]])
				if cfg[2]:
					main.touch._layout()
					for b in main.touch.buttons:
						if _circle_hits(b["c"], float(b["r"]), r):
							bad.append("%s over the %s button" % [parts[i][0], b["id"]])
				else:
					var hs: float = hud.hud_scale
					var hb: Rect2 = L.box("hud.hints", view / hs)
					hb = Rect2(hb.position * hs, hb.size * hs)
					if hb.intersects(r):
						bad.append("%s over the top-right keys" % parts[i][0])
			# The sphere is on the right, under the top-right buttons.
			var orb: Rect2 = main.entity.orb_rect
			if orb.get_center().x < view.x * 0.56 or orb.get_center().y > view.y * 0.45:
				bad.append("the sphere isn't top right %s" % orb)
			if beside and main.entity.rect.position.x < view.x * 0.5:
				bad.append("the bubble isn't on the right")
			_check(bad.is_empty(), "%s, Interface size %s (%dx%d): a banner, a chip, three feed lines, the Entity's sphere and its line; nothing overlaps, nothing in the middle, clear of every button%s" % [
				cfg[0], UI.UI_SIZE_NAMES[ui], int(view.x), int(view.y), "" if bad.is_empty() else ": " + ", ".join(bad)])
	hud.hud_scale = 1.0
	_check(UI.UI_SIZE_ORDER.all(func(ui): return side["a computer " + ui]), "on a computer the Entity's line is always a bubble beside its sphere")
	_check(side["a phone normal"], "on a phone at the usual size, a short line fits beside the sphere too (longer ones are said in the top lane)")
	# A phone with six marks: no room beside the sphere, so it speaks in the lane.
	M.settings["ui_size"] = "normal"
	main.apply_view_scale()
	main.dev_set_mark("heart", "deepcaller", 1)
	main.dev_set_mark("brow", "warden", 1)
	main.dev_set_mark("throat", "warden", 1)
	main.dev_set_mark("back", "hunter", 1)
	main.banner = {}
	Guide.queue.clear()
	main.entity.current = {}
	main.entity.lane = false
	main.entity.new_climb()
	main.entity.bit_at = -1000000
	await t._frames(4)
	main.entity.remark("doors")
	await t._until(func(): return main.entity.showing(), 2.0)
	await t._wait(0.5)
	main.touch._layout()
	var orb6: Rect2 = main.entity.orb_rect
	var clear: bool = orb6.has_area() and not main.touch.buttons.any(func(b): return _circle_hits(b["c"], float(b["r"]), orb6))
	_check(main.player.bonds.size() == 6 and clear, "with six cast buttons on a phone the sphere still finds a place clear of them all (%s)" % orb6)
	_check(main.entity.lane and NS.current.get("who", "") == "entity" and main.entity.rect == hud.lane_rects()["banner"],
		"...and with no room beside it, the Entity speaks in the top lane instead (never over a button)")
	main.entity.dismiss()
	await t._until(func(): return not main.entity.showing() and NS.current.get("who", "") != "entity", 2.0)
	_check(not main.entity.showing() and NS.current.get("who", "") != "entity", "dismissed, its words leave the lane")
	for part in ["heart", "brow", "throat", "back"]:
		main.dev_set_mark(part, "", 1)
	main.touch._set_active(false)
	t.root.size = Vector2i(1280, 720)
	main.apply_view_scale()
	main.banner = {}
	Guide.queue.clear()
	main.entity.current = {}
	await t._frames(3)


## The Entity's panel: a click, a tap, the key and the right stick open and
## close it; it shows the log; Esc closes it without opening the menu.
func _panel() -> void:
	print("the Entity: its sphere and its panel")
	var main = t.main
	var NS = main.notices
	var en = main.entity
	NS.new_climb()
	for i in 26:
		main.note_event("item", "thing %d" % i)
	main.fx.texts.clear()
	await t._frames(4)
	_check(en.orb_on() and en.orb_rect.has_area() and not en.open, "the sphere lingers on the right while you play, its panel shut")
	_check(InputMap.has_action("entity") and main.Controls.HELP.any(func(row): return String(row[0]).contains("Entity's log")), "its panel has a key (L) and the right stick, listed with the controls")
	# A click on the sphere.
	await t._click_at(en.orb_rect.get_center())
	await t._wait(0.4)
	var view: Vector2 = en.get_viewport_rect().size
	_check(en.open and en.quip != "" and en.panel_rect.has_area() and en.ate_at > 0, "a click on the sphere opens its panel, with a quip: %s" % en.quip)
	_check(en.log_shown >= 10 and en.log_shown <= N.LOG_SHOWN, "the panel shows the last things that happened (%d lines, 20 at most)" % en.log_shown)
	_check(en.panel_rect.position.x >= view.x * 0.7 - 1.0 and Rect2(Vector2.ZERO, view).grow(1.0).encloses(en.panel_rect), "...in the right-side lane, clear of the middle (%s)" % en.panel_rect)
	_check(not t.paused and main.player.is_physics_processing(), "...and the game goes on under it")
	await t._click_at(en.orb_rect.get_center())
	await t._frames(3)
	_check(not en.open, "a click again closes it")
	# The key.
	await t._key_tap(KEY_L)
	_check(en.open, "L opens it")
	await t._key_tap(KEY_ESCAPE)
	await t._frames(2)
	_check(not en.open and not main.menu.is_open(), "Esc closes it (and doesn't open the pause menu)")
	await t._key_tap(KEY_L)
	await t._key_tap(KEY_L)
	_check(not en.open and en.opened == 3, "L again closes it")
	# The right stick: the panel when no tip is waiting; a tip's dismissal when one is.
	await t._pad_tap(JOY_BUTTON_RIGHT_STICK)
	_check(en.open, "the right stick opens it on a controller")
	await t._pad_tap(JOY_BUTTON_RIGHT_STICK)
	_check(not en.open, "...and closes it")
	Guide.state["told"].erase("glint")
	main.tip("glint")
	await t._until_bubble()
	await t._pad_tap(JOY_BUTTON_RIGHT_STICK)
	await t._until_no_bubble()
	_check(not en.showing() and not en.open, "while a first-time tip shows, the right stick dismisses the tip instead")
	main.pad._set_active(false)
	# A first-time tip still sits top right, beside the sphere, and a click dismisses it.
	Guide.state["told"].erase("essence")
	main.tip("essence")
	await t._until_bubble()
	await t._wait(0.4)
	_check(en.current.get("kind", "") == "tip" and not en.lane and en.rect.has_area() and en.rect.end.x <= en.orb_rect.position.x + 6.0 and not en.rect.intersects(en.orb_rect.grow(-4.0)),
		"a first-time tip's bubble sits beside the sphere (%s by %s)" % [en.rect, en.orb_rect])
	await t._key_tap(KEY_ENTER)
	await t._until_no_bubble()
	_check(not en.showing(), "Enter still dismisses a first-time tip")
	# A tap, on a phone.
	t.root.size = Vector2i(915, 412)
	main.touch._set_active(true)
	main.apply_view_scale()
	await t._wait(0.3)
	await t._tap_at(en.orb_rect.get_center())
	await t._wait(0.4)
	view = en.get_viewport_rect().size
	_check(en.open and main.touch.held.is_empty(), "a tap on the sphere opens the panel on a phone (and no button takes the tap)")
	_check(en.log_shown >= 10 and en.panel_rect.position.x > view.x * 0.6 and not en.panel_rect.has_point(view * 0.5), "...showing ten lines or more on the right, the climber still in view (%d lines, %s)" % [en.log_shown, en.panel_rect])
	await t._tap_at(en.panel_rect.get_center())
	await t._frames(3)
	_check(not en.open and main.touch.held.is_empty(), "a tap on the panel closes it")
	main.touch._layout()
	_check(not main.touch.buttons.any(func(b): return _circle_hits(b["c"], float(b["r"]), en.orb_rect)), "shut, the sphere is clear of every touch button")
	main.touch._set_active(false)
	t.root.size = Vector2i(1280, 720)
	main.apply_view_scale()
	NS.new_climb()
	await t._frames(3)


## Tidbits: true lines in data for every tower, creature, task, scenario
## and reaction; said once a climb; no lore.
func _tidbits() -> void:
	print("the Entity: tidbits")
	var main = t.main
	var en = main.entity
	var Obj = load("res://scripts/objectives.gd")
	var Scn = load("res://scripts/scenarios.gd")
	var Th = load("res://scripts/themes.gd")
	var Cat = load("res://scripts/puzzles/catalog.gd")
	var R = load("res://scripts/reactions.gd")
	var En = load("res://scripts/enemy.gd")
	# The data.
	var bad: Array = []
	for key in Notes.TIDBITS:
		var lines: Array = Notes.TIDBITS[key]
		if lines.is_empty():
			bad.append(key + ": empty")
		for l in lines:
			var s := String(l)
			if s.length() < 12 or s.length() > 100:
				bad.append("%s: %d letters" % [key, s.length()])
			for w in BANNED:
				if s.to_lower().contains(w):
					bad.append("%s: %s" % [key, w])
		var kind: String = String(key).get_slice(":", 0)
		var id: String = String(key).get_slice(":", 1) if String(key).contains(":") else ""
		match kind:
			"tower":
				if not Towers.TOWERS.has(id): bad.append(key)
			"task":
				if not Obj.KINDS.has(id) and id != "puzzle": bad.append(key)
			"scenario":
				if not Scn.SCENARIOS.has(id): bad.append(key)
			"theme":
				if not Th.THEMES.has(id): bad.append(key)
			"puzzle":
				if id != "" and not Cat.TYPES.has(id): bad.append(key)
			"creature":
				if not En.TYPES.has(id): bad.append(key)
	_check(bad.is_empty(), "every tidbit is a short line about something the game has, in allowed words (%d keys; bad: %s)" % [Notes.TIDBITS.size(), bad])
	_check(Towers.ORDER.all(func(id): return Notes.lines("tower:" + id).size() >= 1 and Notes.arrival_keys(id).size() >= 3 and Notes.arrival_keys(id).all(func(k): return not Notes.lines(k).is_empty())),
		"every tower has tidbits of its own, and one for each of its own systems")
	_check(Obj.KINDS.keys().all(func(k): return not Notes.lines("task:" + k).is_empty()) and Scn.SCENARIOS.keys().all(func(k): return not Notes.lines("scenario:" + k).is_empty())
		and Cat.TYPES.keys().all(func(k): return Notes.TIDBITS.has("puzzle:" + k)), "every task, scenario and puzzle has one")
	_check(R.REACTIONS.keys().all(func(k): return Notes.lines("reaction:" + k).size() == 1 and String(Notes.lines("reaction:" + k)[0]).contains(R.REACTIONS[k]["name"])),
		"a reaction's tidbit is what the reaction does, in the reactions' own words")
	_check(Notes.lines("lock:key").size() >= 1 and Notes.lines("lock:nonsense") == Notes.TIDBITS["lock"] and Notes.lines("nonsense").is_empty(), "a kind with no line of its own falls back to its family's")
	_check(Towers.ORDER.all(func(id): return Notes.LORE.has(id) and Notes.LORE[id].is_empty()), "every tower has a lore list, and each is empty (the story is the owner's to write)")
	_check(Notes.QUIPS.size() >= 6 and Notes.QUIPS.all(func(q): return not BANNED.any(func(w): return String(q).to_lower().contains(w))), "it has a pool of quips for opening its panel")
	# In play: a tidbit for each tower on arriving.
	Guide.state["on"] = true
	var keep_tower: String = main.tower
	var ok := true
	for id in Towers.ORDER:
		main.tower = id
		Guide.queue.clear()
		en.new_climb()
		en.remark_arrival()
		ok = ok and Guide.queue.size() == 1 and Guide.queue[0]["kind"] == "bit" and (String(Guide.queue[0]["key"]) in Notes.arrival_keys(id))
		ok = ok and en.lore_line() == ""
	_check(ok, "arriving in each tower queues one tidbit about that tower; with no lore written, none is said or shown")
	# With lore written, it's said first and shown in the panel.
	Notes.LORE["kraken"] = ["A line the owner wrote."]
	main.tower = "kraken"
	Guide.queue.clear()
	en.new_climb()
	en.remark_arrival()
	_check(Guide.queue.size() == 1 and Guide.queue[0]["text"] == "A line the owner wrote." and en.lore_line() == "A line the owner wrote.", "a lore line, once written, is said on arriving and shown in the panel")
	Notes.LORE["kraken"] = []
	main.tower = keep_tower
	# One shows as a short bubble and goes by itself; not twice in a climb.
	Guide.queue.clear()
	en.current = {}
	en.lane = false
	en.gap_t = 0.0
	en.new_climb()
	en.bit_at = -1000000
	var bits0: int = en.bits
	_check(en.remark("stair") and not en.remark("stair"), "a tidbit is queued once")
	await t._until(func(): return en.showing(), 2.0)
	await t._wait(0.4)
	_check(en.current.get("kind", "") == "bit" and en.current["text"] == Notes.TIDBITS["stair"][0] and en.bits == bits0 + 1 and en.rect.has_area() and en.rect.size.y < 70.0,
		"it shows as one short line beside the sphere (%s)" % en.rect)
	_check(en.life < Guide.LIFE_MIN, "...for a few seconds, less than a first-time tip")
	en.shown_t = en.life
	await t._until_no_bubble()
	_check(not en.showing() and en.last_note.get("text", "") == Notes.TIDBITS["stair"][0], "it goes by itself; the panel keeps it as the last thing said")
	en.key_at.clear()
	_check(not en.remark("stair"), "the same line isn't said again this climb")
	en.new_climb()
	_check(en.remark("stair"), "...a new climb may hear it again")
	_check(en.remark("doors") and Guide.queue.size() == 2, "another key queues its own")
	en.key_at["wing"] = Time.get_ticks_msec()
	_check(not en.remark("wing"), "a key that just spoke waits before it speaks again")
	Guide.state["on"] = false
	Guide.queue.clear()
	_check(not en.remark("pact") and Guide.queue.is_empty(), "with the Entity's tips turned off it keeps quiet")
	Guide.state["on"] = true
	# Triggers in play: a named room, shut doors, a creature's first notice.
	Guide.queue.clear()
	en.new_climb()
	main.remark("theme:den")
	main.remark("creature:slime")
	main.remark("task:levers")
	main.remark("reaction:steam")
	_check(Guide.queue.map(func(q): return q["key"]) == ["theme:den", "creature:slime", "task:levers", "reaction:steam"], "rooms, creatures, tasks and reactions each ask for theirs")
	Guide.queue.clear()
	en.current = {}
	Engine.remove_meta("sixfold_tips")
	_check(not en.remark("pact"), "tests that don't ask for the Entity hear nothing")
	Engine.set_meta("sixfold_tips", true)


## A puzzle's rule: said in the lane as you step in, read again at its "?"
## plaque, never drawn over the puzzle.
func _puzzle_notes() -> void:
	print("lanes: a puzzle's rule and its ? plaque")
	Engine.remove_meta("sixfold_tips")
	var main = t.main
	var NS = main.notices
	var p = main.player
	for kind in ["mirrors", "lock"]:
		await t._puzzle_floor(kind, 3)
		var pz = main.puzzle
		main.banner = {}
		NS.feed_lines.clear()
		p.global_position = pz.room.get_center()
		await t._until(func(): return NS.current.get("note", false), 2.0)
		var b: Dictionary = NS.current
		var want: String = String(pz.cur.riddles[0]) if kind == "lock" else String(pz.cur.TEXT["rule"][0])
		_check(b.get("note", false) and b.get("title", "") == pz.display_name().to_upper() and want in b.get("lines", []), "%s: stepping in says its rule in the top lane (%s)" % [pz.display_name(), want])
		_check(pz.plaques.size() == 1 and pz.room.has_point(pz.plaques[0]), "...and leaves a small ? plaque in the room")
		await t._frames(4)
		var r: Rect2 = main.hud.lane_rects()["banner"]
		var view: Vector2 = main.hud.get_viewport_rect().size
		_check(r.has_area() and r.end.y < view.y * 0.3, "...the words at the top of the screen, not over the puzzle (%s)" % r)
		if kind == "lock":
			_check(pz.plaques[0].distance_to(pz.cur.lock) > 12.0, "the Essence Lock's riddle no longer sits over the lock and its sparks")
		# Away from the plaque nothing is said again; by it, the rule comes back and stays.
		main.banner = {}
		var away: Vector2 = pz.plaques[0] + Vector2(0, pz.PLAQUE_REACH + 60.0)
		if not pz.room.grow(-10.0).has_point(away):
			away = pz.plaques[0] - Vector2(0, pz.PLAQUE_REACH + 60.0)
		p.global_position = away
		await t._frames(8)
		_check(main.banner.is_empty(), "away from the plaque the rule isn't said again")
		p.global_position = pz.plaques[0] + (away - pz.plaques[0]).normalized() * 30.0
		await t._until(func(): return NS.current.get("note", false), 1.5)
		_check(NS.current.get("note", false) and want in NS.current.get("lines", []), "standing by the ? says it again")
		await t._wait(1.6)
		_check(NS.current.get("note", false) and float(NS.current.get("t", 0.0)) > 0.3, "...for as long as you stand there")
		p.global_position = away
		await t._until(func(): return main.banner.is_empty(), 3.0)
		_check(main.banner.is_empty(), "...and it fades when you walk away")
