extends RefCounted
## The wheels (wheel.gd; player.gd _update_item_hold / _update_pick; hud.gd
## wheel_spot): hold the belt button and the belt wheel opens while the game
## slows; pointing and letting go (or a click, or a number key) makes an item
## current and never uses it; a tap uses the current item. A mark's button
## works the same way with its spells: choosing never casts, by keys, the
## controller or touch. On a phone the wheel sits by the thumb, a slide and
## let go chooses, a tap uses, and the joystick still moves. A pause, a menu
## or a fall closes it, using nothing. The Entity explains it once, and in
## its talk; the words and numbers are in the Data editor; Arrange mode can
## move it. Run by smoke_test.gd (_part_tests).

const Wheel := preload("res://scripts/wheel.gd")
const L := preload("res://scripts/layout.gd")
const Guide := preload("res://scripts/guide.gd")
const Entity := preload("res://scripts/entity.gd")
const Talk := preload("res://scripts/entity_talk.gd")
const DR := preload("res://scripts/data_registry.gd")
const AUI := preload("res://scripts/arrange_ui.gd")

var t
var M = load("res://scripts/menu.gd")
var keep_ui := ""
var keep_size := Vector2i.ZERO
var keep_guide := {}
var keep_layout := {}


func run(smoke) -> void:
	t = smoke
	print("the wheels: hold to choose, tap to use")
	keep_ui = String(M.settings["ui_size"])
	keep_size = t.root.size
	keep_guide = Guide.state.duplicate(true)
	keep_layout = L.snapshot()
	t.root.size = Vector2i(1280, 720)
	M.settings["ui_size"] = "normal"
	await _belt_keys()
	await _belt_mouse_and_numbers()
	await _belt_pad()
	await _spells()
	await _phone()
	await _closes()
	await _entity_and_data()
	await _arrange()
	Engine.remove_meta("sixfold_tips")
	Guide.state = keep_guide
	Guide.queue.clear()
	L.restore(keep_layout)
	t.main.touch._set_active(false)
	t.main.pad._set_active(false)
	M.settings["ui_size"] = keep_ui
	t.root.size = keep_size
	t.main.apply_view_scale()
	Engine.time_scale = 1.0
	await t._frames(2)


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


## A fresh climb with three kinds on the belt, two of each; no monsters.
func _fresh(touch := false) -> void:
	await t._fresh_main()
	t.paused = false
	var main = t.main
	main.touch._set_active(touch)
	main.pad._set_active(false)
	main.apply_view_scale()
	for e in main.enemies():
		e.queue_free()
	await t._frames(2)
	var p = main.player
	p.mouse_aim = false
	p.iframes = 9999.0
	p.items = {"draught": 2, "tonic": 2, "haste": 2}
	p.item_sel = "draught"
	p.hp = 60.0


func _counts(p) -> Dictionary:
	return p.items.duplicate()


## A direction pointing at option `i` of `n` (the first at the top, clockwise).
func _toward(i: int, n: int) -> Vector2:
	return Vector2.from_angle(-PI / 2.0 + TAU * i / float(n)) * 60.0


func _phys(n := 2) -> void:
	for i in n:
		await t.physics_frame


# --- the belt: keys --------------------------------------------------------------------

func _belt_keys() -> void:
	await _fresh()
	var main = t.main
	var p = main.player
	var before := _counts(p)
	# Hold G: the wheel opens and the game slows (not stops).
	Input.action_press("use_item")
	await t._wait(0.45)
	_check(p.ring_open and main.slowmo and absf(Engine.time_scale - Wheel.slow()) < 0.01 and Wheel.slow() > 0.0 and Wheel.slow() < 1.0,
		"holding G opens the belt wheel and slows the game to %d%% (%.2f)" % [int(Wheel.slow() * 100.0), Engine.time_scale])
	_check(p.ring_index == p.carried().find("draught"), "...pointing at the current item to begin with")
	var have: Array = p.carried()
	var target := have.find("haste")
	p.item_dir_override = _toward(target, have.size())
	await _phys()
	_check(p.ring_index == target, "pointing picks an item on the wheel (%d)" % p.ring_index)
	Input.action_release("use_item")
	await _phys()
	_check(not p.ring_open and not main.slowmo and Engine.time_scale == 1.0, "letting go closes the wheel and time runs again")
	_check(p.selected_item() == "haste" and _counts(p) == before and p.haste_t <= 0.0, "letting go makes it the current item and uses nothing (%s, %s)" % [p.selected_item(), p.items])
	# A tap uses the current item.
	Input.action_press("use_item")
	await _phys()
	Input.action_release("use_item")
	await _phys(3)
	_check(p.item_count("haste") == 1 and p.haste_t > 0.0 and not p.ring_open, "a tap of G uses the current item (and never opens the wheel)")
	# Hold and let go without pointing: nothing changes, nothing is used.
	before = _counts(p)
	Input.action_press("use_item")
	await t._wait(0.45)
	Input.action_release("use_item")
	await _phys()
	_check(p.selected_item() == "haste" and _counts(p) == before, "holding and letting go without pointing keeps the current item and uses nothing")
	# T / the d-pad down: a tap picks the next (nothing used); a hold opens the wheel too.
	p.item_sel = "draught"
	before = _counts(p)
	Input.action_press("item_next")
	await _phys()
	Input.action_release("item_next")
	await _phys()
	_check(p.selected_item() != "draught" and _counts(p) == before and not p.ring_open, "a tap of T picks the next item and uses nothing (%s)" % p.selected_item())
	Input.action_press("item_next")
	await t._wait(0.45)
	_check(p.ring_open, "holding T opens the wheel too")
	have = p.carried()
	p.item_dir_override = _toward(have.find("tonic"), have.size())
	await _phys()
	Input.action_release("item_next")
	await _phys()
	_check(p.selected_item() == "tonic" and _counts(p) == before, "...and letting go chooses without using")
	# One kind on the belt: no wheel; a hold still just uses it.
	p.items = {"draught": 2}
	p.item_sel = "draught"
	Input.action_press("use_item")
	await t._wait(0.45)
	_check(not p.ring_open and not main.slowmo, "with one kind on the belt there's no wheel")
	Input.action_release("use_item")
	await _phys(3)
	_check(p.item_count("draught") == 1, "...and letting go uses it, as a tap does")


# --- the belt: the mouse, a click, number keys, the mouse wheel ---------------------------------

func _belt_mouse_and_numbers() -> void:
	await _fresh()
	var main = t.main
	var p = main.player
	var before := _counts(p)
	var have: Array = p.carried()
	t._mouse_move(Vector2(640, 360))
	await _phys()
	Input.action_press("use_item")
	await t._wait(0.45)
	_check(p.ring_open, "the wheel is open (the mouse)")
	var target := have.find("tonic")
	var at: Vector2 = main.hud.wheel_option_pos(target, have.size())
	t._mouse_move(at)
	await _phys()
	_check(p.ring_index == target, "the mouse points at an item by where it is on the wheel (%d, want %d)" % [p.ring_index, target])
	# A click chooses (it doesn't strike).
	var cd: float = p.attack_cd
	Input.action_press("attack")
	await _phys()
	Input.action_release("attack")
	await _phys()
	_check(not p.ring_open and p.selected_item() == "tonic" and _counts(p) == before and p.attack_cd <= cd + 0.001, "a click chooses the pointed item, closes the wheel, strikes nothing, uses nothing (%s, %s, %s, cd %.2f -> %.2f)" % [p.ring_open, p.selected_item(), p.items, cd, p.attack_cd])
	Input.action_release("use_item")
	await _phys(3)
	_check(_counts(p) == before and not p.ring_open, "...and letting go of G afterwards uses nothing")
	# Number keys choose directly (choose, not use), and don't switch weapons.
	var weapon: String = p.weapon
	Input.action_press("use_item")
	await t._wait(0.45)
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_3
	ev.keycode = KEY_3
	ev.pressed = true
	Input.parse_input_event(ev)
	await _phys()
	_check(not p.ring_open and p.selected_item() == have[2] and _counts(p) == before, "with the wheel open, 3 chooses the third item and uses nothing (%s)" % p.selected_item())
	var up := ev.duplicate()
	up.pressed = false
	Input.parse_input_event(up)
	Input.action_release("use_item")
	await _phys(3)
	_check(p.weapon == weapon and p.pending_weapon == "" and _counts(p) == before, "...and it switches no weapon")
	# The mouse wheel (the weapon buttons) steps the pointer round instead of switching weapons.
	Input.action_press("use_item")
	await t._wait(0.45)
	var from: int = p.ring_index
	Input.action_press("weapon_next")
	await _phys()
	Input.action_release("weapon_next")
	await _phys()
	_check(p.ring_index == posmod(from + 1, have.size()) and p.pending_weapon == "" and p.weapon == weapon, "with the wheel open the mouse wheel steps round the wheel, not the weapons")
	Input.action_release("use_item")
	await _phys(3)
	_check(p.selected_item() == have[posmod(from + 1, have.size())] and _counts(p) == before, "...and letting go chooses that one, using nothing")


# --- the belt: a controller -------------------------------------------------------------------

func _belt_pad() -> void:
	await _fresh()
	var main = t.main
	var p = main.player
	var before := _counts(p)
	var have: Array = p.carried()
	t._pad_button(JOY_BUTTON_X, true)
	await t._wait(0.45)
	_check(main.pad.active and p.stick_aim and p.ring_open and absf(Engine.time_scale - Wheel.slow()) < 0.01, "holding X on a controller opens the belt wheel, slowed")
	# The right stick points (straight right: the item at the right of the wheel).
	var target := have.find("tonic")
	var d := _toward(target, have.size()).normalized()
	t._pad_axis(JOY_AXIS_RIGHT_X, d.x)
	t._pad_axis(JOY_AXIS_RIGHT_Y, d.y)
	await _phys(3)
	_check(p.ring_index == target, "the right stick points at an item (%d, want %d)" % [p.ring_index, target])
	t._pad_button(JOY_BUTTON_X, false)
	await _phys(3)
	t._pad_axis(JOY_AXIS_RIGHT_X, 0.0)
	t._pad_axis(JOY_AXIS_RIGHT_Y, 0.0)
	await _phys()
	_check(not p.ring_open and p.selected_item() == "tonic" and _counts(p) == before, "letting go of X chooses it and uses nothing")
	t._pad_button(JOY_BUTTON_X, true)
	await _phys(2)
	t._pad_button(JOY_BUTTON_X, false)
	await _phys(3)
	_check(p.item_count("tonic") == 1, "a tap of X uses the current item")
	main.pad._set_active(false)
	await _phys()


# --- the spell wheel: choosing never casts ---------------------------------------------------

func _cast_count(p, b) -> Array:
	return [snappedf(b.essence, 0.01), p.spells_cast, p.cast_t > 0.0]


func _spells() -> void:
	await _fresh()
	t._mark("hand", "stormcaller", 5)
	var main = t.main
	var p = main.player
	for e in main.enemies():
		e.queue_free()
	p.iframes = 9999.0
	await _phys()
	var b = p.bonds["hand"]
	var n: int = b.spells().size()
	_check(n >= 2, "a step-5 mark knows several spells (%d): its button has a wheel" % n)
	b.select(0)
	var was := _cast_count(p, b)
	# Keys: hold Q, point, let go.
	Input.action_press("cast_hand")
	await t._wait(0.45)
	_check(p.pick_open and absf(Engine.time_scale - Wheel.slow()) < 0.01, "holding a mark's key opens its spell wheel, slowed")
	p.pick_dir_override = _toward(1, n)
	await _phys()
	Input.action_release("cast_hand")
	await t._wait(0.4)
	_check(b.selected == 1 and not p.pick_open and Engine.time_scale == 1.0, "letting go puts the pointed spell on the button (%d)" % b.selected)
	_check(_cast_count(p, b) == was and p.buffered != "cast_hand", "...and casts nothing (%s, was %s)" % [_cast_count(p, b), was])
	# A click chooses too, and casts nothing (no strike either).
	Input.action_press("cast_hand")
	await t._wait(0.45)
	p.pick_dir_override = _toward(2, n)
	await _phys()
	Input.action_press("attack")
	await _phys()
	Input.action_release("attack")
	await _phys()
	Input.action_release("cast_hand")
	await t._wait(0.4)
	_check(b.selected == 2 and _cast_count(p, b) == was, "a click on the spell wheel chooses, casting nothing")
	# A tap casts the spell on the button.
	Input.action_press("cast_hand")
	await _phys()
	Input.action_release("cast_hand")
	await t._wait(0.8)
	_check(_cast_count(p, b) != was, "a tap of the key casts the spell on the button (%s, was %s)" % [_cast_count(p, b), was])
	await t._wait(0.8)
	b.essence = b.capacity()
	was = _cast_count(p, b)
	# A controller: hold LB + X, point with the right stick, let go.
	t._pad_button(JOY_BUTTON_LEFT_SHOULDER, true)
	t._pad_button(JOY_BUTTON_X, true)
	await t._wait(0.45)
	_check(p.pick_open, "holding LB + X opens the hand's spell wheel on a controller")
	var d := _toward(3, n).normalized()
	t._pad_axis(JOY_AXIS_RIGHT_X, d.x)
	t._pad_axis(JOY_AXIS_RIGHT_Y, d.y)
	await _phys(3)
	t._pad_button(JOY_BUTTON_X, false)
	t._pad_button(JOY_BUTTON_LEFT_SHOULDER, false)
	await t._wait(0.4)
	t._pad_axis(JOY_AXIS_RIGHT_X, 0.0)
	t._pad_axis(JOY_AXIS_RIGHT_Y, 0.0)
	_check(b.selected == 3 and _cast_count(p, b) == was, "...letting go chooses the pointed spell and casts nothing (%d)" % b.selected)
	# The weapon swap while the wheel is open steps the pointer (never a cast, never a swap).
	var weapon: String = p.weapon
	Input.action_press("cast_hand")
	await t._wait(0.45)
	var from: int = p.pick_index
	Input.action_press("weapon_next")
	await _phys()
	Input.action_release("weapon_next")
	await _phys()
	Input.action_release("cast_hand")
	await t._wait(0.4)
	_check(b.selected == posmod(from + 1, n) and p.weapon == weapon and p.pending_weapon == "" and _cast_count(p, b) == was, "Swap with the spell wheel open steps to the next spell: no swap, no cast")
	main.pad._set_active(false)
	# A phone: hold the mark's button, slide onto a spell, let go.
	main.touch._set_active(true)
	main.apply_view_scale()
	await t._frames(3)
	main.touch._layout()
	var btn: Dictionary = main.touch.buttons.filter(func(x): return x["id"] == "cast_hand")[0]
	t._touch(5, btn["c"], true)
	await t._wait(0.45)
	_check(p.pick_open, "holding the hand's button on a phone opens its spell wheel")
	var spot: Vector2 = main.hud.wheel_option_pos(0, n)
	t._drag(5, (btn["c"] + spot) * 0.5)
	await _phys()
	t._drag(5, spot)
	await _phys()
	_check(p.pick_index == 0, "sliding a finger onto a spell points at it (%d)" % p.pick_index)
	t._touch(5, spot, false)
	await t._wait(0.4)
	_check(b.selected == 0 and not p.pick_open and _cast_count(p, b) == was, "letting go chooses it and casts nothing")
	t._touch(5, btn["c"], true)
	await _phys()
	t._touch(5, btn["c"], false)
	await t._wait(0.8)
	_check(_cast_count(p, b) != was, "a quick tap of the button casts")
	main.touch._set_active(false)
	main.apply_view_scale()
	await t._frames(2)


# --- a phone: the belt wheel by the thumb, and the joystick ------------------------------------------

func _phone() -> void:
	t.root.size = Vector2i(915, 412)
	await _fresh(true)
	var main = t.main
	var p = main.player
	await t._frames(3)
	var before := _counts(p)
	main.touch._layout()
	var btn: Dictionary = main.touch.buttons.filter(func(x): return x["id"] == "item")[0]
	t._touch(6, btn["c"], true)
	await t._wait(0.45)
	_check(p.ring_open and absf(Engine.time_scale - Wheel.slow()) < 0.01, "holding the phone's Item button opens the belt wheel, slowed")
	var view: Vector2 = main.hud.get_viewport_rect().size
	var spot: Array = main.hud.wheel_spot()
	var c: Vector2 = spot[0]
	var r: float = (main.hud.WHEEL_R + main.hud.WHEEL_RIM) * float(spot[1])
	_check(c.distance_to(btn["c"]) >= r + main.hud.RING_THUMB - 1.0 and Rect2(Vector2.ZERO, view).grow(1.0).encloses(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)),
		"on a phone the wheel sits beside the thumb, never under it, and wholly on screen (%s, r %.0f, view %s)" % [c, r, view])
	# The joystick still moves while the wheel is open.
	var x0: float = p.global_position.x
	t._touch(2, Vector2(90, view.y - 90), true)
	await _phys()
	t._drag(2, Vector2(150, view.y - 90))
	await t._wait(0.6)
	_check(Input.get_action_strength("move_right") > 0.0 and p.global_position.x > x0 + 2.0 and p.ring_open, "the joystick still moves the climber (slowly) while the wheel is open (%.1f px)" % (p.global_position.x - x0))
	t._touch(2, Vector2(150, view.y - 90), false)
	await _phys()
	var have: Array = p.carried()
	var target := have.find("haste")
	var at: Vector2 = main.hud.wheel_option_pos(target, have.size())
	t._drag(6, (btn["c"] + at) * 0.5)
	await _phys()
	t._drag(6, at)
	await _phys()
	_check(p.ring_index == target, "sliding a finger onto an item points at it (%d, want %d)" % [p.ring_index, target])
	t._touch(6, at, false)
	await _phys(3)
	_check(not p.ring_open and p.selected_item() == "haste" and _counts(p) == before, "letting go chooses it, using nothing")
	t._touch(6, btn["c"], true)
	await _phys()
	t._touch(6, btn["c"], false)
	await t._wait(0.2)
	_check(p.item_count("haste") == 1 and p.haste_t > 0.0 and not p.ring_open, "a quick tap of the Item button uses the current item")
	# The wheel fits a phone at every Interface size.
	var fits := true
	for ui in ["small", "normal", "large", "larger"]:
		M.settings["ui_size"] = ui
		main.apply_view_scale()
		await t._frames(2)
		view = main.hud.get_viewport_rect().size
		main.touch._layout()
		main.pick_anchor = main.touch.buttons.filter(func(x): return x["id"] == "item")[0]["c"]
		spot = main.hud.wheel_spot()
		var k: float = spot[1]
		var top: Vector2 = Vector2(spot[0]) - Vector2(main.hud.WHEEL_CAPTION_W * 0.5, main.hud.WHEEL_R + main.hud.WHEEL_RIM) * k
		var size := Vector2(main.hud.WHEEL_CAPTION_W, 2.0 * (main.hud.WHEEL_R + main.hud.WHEEL_RIM) + main.hud.WHEEL_CAPTION) * k
		if not Rect2(Vector2.ZERO, view).grow(1.0).encloses(Rect2(top, size)) or k < 0.6:
			fits = false
			print("    the wheel doesn't fit at ", ui, ": ", Rect2(top, size), " in ", view, " (scale ", k, ")")
	_check(fits, "the wheel and its words fit a phone's screen at every Interface size")
	# Every item's and every spell's words fit under the wheel (three lines at most).
	var Bonds = load("res://scripts/bonds.gd")
	var Items = load("res://scripts/items.gd")
	var texts: Array = []
	for id in Items.ITEMS:
		texts.append(String(Items.ITEMS[id].get("desc", "")))
	for bid in Bonds.BONDS:
		for sp in Bonds.BONDS[bid].get("spells", []):
			texts.append(String(sp.get("desc", "")))
	var body: Font = load("res://scripts/ui.gd").font("body")
	var long: Array = []
	var floor_size: int = main.hud.WHEEL_TEXT_SIZES[-1]
	for tx in texts:
		var lines := int(round(body.get_multiline_string_size(tx, HORIZONTAL_ALIGNMENT_LEFT, main.hud.WHEEL_CAPTION_W, floor_size).y / body.get_height(floor_size)))
		if lines > main.hud.WHEEL_TEXT_LINES:
			long.append(tx.left(40))
	_check(long.is_empty(), "every item's and spell's words fit under the wheel (%d checked; too long: %s)" % [texts.size(), long])
	M.settings["ui_size"] = "normal"
	main.touch._set_active(false)
	t.root.size = Vector2i(1280, 720)
	main.apply_view_scale()
	await t._frames(2)


# --- a pause, a menu or a fall closes it, using nothing ------------------------------------------

func _closes() -> void:
	await _fresh()
	var main = t.main
	var p = main.player
	var before := _counts(p)
	Input.action_press("use_item")
	await t._wait(0.45)
	_check(p.ring_open, "the wheel is open (before the pause)")
	main.menu.open("pause")
	await t._frames(2)
	_check(not p.ring_open and not main.slowmo and p.item_hold_src == "", "opening the pause menu closes the wheel")
	Input.action_release("use_item")
	main.menu.close()
	t.paused = false
	await t._wait(0.3)
	_check(_counts(p) == before and Engine.time_scale == 1.0, "...and nothing is used, then or after the menu closes (%s)" % [p.items])
	# A mark's wheel and the menu.
	t._mark("hand", "stormcaller", 5)
	p = main.player
	var b = p.bonds["hand"]
	var was := _cast_count(p, b)
	Input.action_press("cast_hand")
	await t._wait(0.45)
	_check(p.pick_open, "the spell wheel is open (before the menu)")
	main.menu.open("inventory")
	await t._frames(2)
	_check(not p.pick_open and not main.slowmo and p.pick_part == "", "opening a menu closes the spell wheel")
	Input.action_release("cast_hand")
	main.menu.close()
	t.paused = false
	await t._wait(0.5)
	_check(_cast_count(p, b) == was, "...and nothing is cast")
	# A fall.
	p.items = {"draught": 2, "tonic": 2}
	before = _counts(p)
	Input.action_press("use_item")
	await t._wait(0.45)
	_check(p.ring_open, "the wheel is open (before the fall)")
	p.dead = true
	await _phys(3)
	_check(not p.ring_open and not main.slowmo, "falling closes the wheel")
	Input.action_release("use_item")
	await _phys(3)
	_check(_counts(p) == before, "...using nothing")
	Engine.time_scale = 1.0


# --- the Entity, its talk, the Data editor -----------------------------------------------------

func _entity_and_data() -> void:
	await _fresh()
	var main = t.main
	var p = main.player
	_check(Entity.TIPS.has("belt_wheel") and Entity.TIPS.has("spell_wheel") and not Entity.TIPS.has("item_ring"), "the Entity has tips for the belt wheel and the spell wheel (the old item ring's is gone)")
	var words := Entity.fill_keys(String(Entity.TIPS["belt_wheel"]["tip"]), "keys")
	_check(words.contains("Hold G") and words.contains("tap G") and words.to_lower().contains("choos"), "its first line says hold to choose, tap to use: %s" % words)
	Engine.set_meta("sixfold_tips", true)
	Guide.forget()
	Guide.queue.clear()
	p.items = {"draught": 1}
	p.add_item("tonic")
	main._note_belt()
	var n := Guide.queue.filter(func(q): return q.get("id", "") == "belt_wheel").size()
	_check(n == 1, "the first time the belt holds two kinds, the Entity explains the wheel")
	p.add_item("haste")
	main._note_belt()
	n = Guide.queue.filter(func(q): return q.get("id", "") == "belt_wheel").size()
	_check(n == 1, "...only once while it waits")
	Guide.queue.clear()
	Guide.state["told"]["belt_wheel"] = true
	_check(not main.tip("belt_wheel"), "...and never again once said")
	Engine.remove_meta("sixfold_tips")
	Guide.forget()
	Guide.queue.clear()
	# The talk: "How does the belt wheel work?" under "How do things work here?".
	_check("how_wheel" in Talk.DIALOGUE["how"]["choices"] and String(Talk.DIALOGUE["how_wheel"]["ask"]) == "How does the belt wheel work?", "the Entity's talk has \"How does the belt wheel work?\"")
	var said := Talk.line_for(main, "how_wheel")
	_check(not said.contains("{") and said.contains("%d%%" % int(round(Wheel.slow() * 100.0))) and said.contains("G"), "...answered with the real speed and the keys in use: %s" % said)
	# The words and numbers are in the Data editor.
	var tables: Array = []
	for sec in DR.SECTIONS:
		tables.append_array(sec.get("tables", []))
	_check("wheel/TEXT" in tables and "wheel/RULES" in tables, "the wheel's words and numbers are in the Data editor")
	var lines: Array = Wheel.TEXT.values() + [String(Entity.TIPS["belt_wheel"]["more"]), String(Entity.TIPS["spell_wheel"]["more"]), String(Talk.DIALOGUE["how_wheel"]["lines"][0])]
	var bad: Array = []
	for line in lines:
		for w in ["attunement", "spire", "trial", "judgment", "mana"]:
			if String(line).to_lower().contains(w):
				bad.append(w)
	_check(bad.is_empty(), "no banned words in the wheel's words (%s)" % [bad])


# --- Arrange mode can move it ---------------------------------------------------------------------

func _arrange() -> void:
	await _fresh()
	var main = t.main
	var p = main.player
	_check(L.has("hud.wheel") and L.display_name("hud.wheel") == "Item and spell wheel" and AUI.NAMES.get("hud.wheel", "") == "Item and spell wheel", "the wheel is an Arrange block: \"Item and spell wheel\"")
	var view: Vector2 = main.hud.get_viewport_rect().size
	_check(not main.arrange._showing("hud.wheel"), "Arrange mode outlines it faintly while it's shut")
	L.set_override("hud.wheel", {"anchor": "c", "x": 220.0, "y": -40.0, "scale": 0.9})
	Input.action_press("use_item")
	await t._wait(0.45)
	var box: Rect2 = L.box("hud.wheel", view)
	var spot: Array = main.hud.wheel_spot()
	_check(p.ring_open and Vector2(spot[0]).distance_to(box.get_center()) < 1.0 and absf(float(spot[1]) - 0.9) < 0.02,
		"arranged, the wheel opens where Arrange put it, at its size (%s, box %s, scale %.2f)" % [spot[0], box, spot[1]])
	_check(main.arrange._showing("hud.wheel"), "...and Arrange mode counts it as showing while it's open")
	Input.action_release("use_item")
	await _phys(3)
	L.reset("hud.wheel")
