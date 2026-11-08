extends Node2D
## On-screen controls for phones and tablets. They appear the first time
## the screen is touched and hide again if a keyboard or mouse is used.
##
## Left side: a floating joystick (appears under your thumb). Right side: attack (hold to draw a bow), roll,
## parry, both bond casts and weapon switch, and Take while you stand on
## gear. Top right: fullscreen, music,
## restart. The controls press the same input actions as the keyboard, so
## the rest of the game doesn't need to know about touch at all.

const Palette := preload("res://scripts/palette.gd")

const STICK_RADIUS := 55.0
## While touch is active the whole game is drawn bigger, so the world and
## text are readable on a small screen.
const PHONE_SCALE := 1.5
const ONE_SHOT := ["weapon", "menu", "item_next", "take", "climber", "inventory"]
## Held buttons a quick tap still has to reach the game with: let go a
## moment later (Item: a tap uses the quick item, a hold opens the ring).
const HOLD_TAP := ["item"]
## The top bar: always there, also while fallen.
const TOP_BAR := ["menu", "fullscreen", "climber", "inventory"]
const Items := preload("res://scripts/items.gd")
const UI := preload("res://scripts/ui.gd")
const Draw := preload("res://scripts/draw_util.gd")

var main
var active := false
var stick_touch := -1
var stick_origin := Vector2.ZERO
var stick_pos := Vector2.ZERO
var held := {}  # touch index -> button id
var held_since := {}  # touch index -> when it went down (ms)
var buttons: Array = []  # {id, action, center, radius, label}


## Every action a touch can hold down (released when screens change, since
## input state outlives a scene reload).
const HELD_ACTIONS := ["move_left", "move_right", "move_up", "move_down", "attack", "roll", "parry", "jump",
	"cast_hand", "cast_legs", "cast_heart", "cast_brow", "cast_throat", "cast_back", "weapon_next", "pause", "interact",
	"climber", "inventory", "use_item", "item_next"]


func _ready() -> void:
	set_process_input(true)
	_release_all()


func _layout() -> void:
	var s := get_viewport_rect().size
	# Laid out for the scaled-up phone view; k keeps buttons thumb-sized.
	var k := 0.75
	var br := Vector2(s.x, s.y)  # bottom-right corner
	var tr := Vector2(s.x, 0)  # top-right corner
	buttons = [
		{"id": "attack", "action": "attack", "c": br + Vector2(-130, -130) * k, "r": 62.0 * k},
		{"id": "roll", "action": "roll", "c": br + Vector2(-268, -86) * k, "r": 44.0 * k},
		{"id": "jump", "action": "jump", "c": br + Vector2(-36, -36) * k, "r": 30.0 * k},
		{"id": "parry", "action": "parry", "c": br + Vector2(-150, -278) * k, "r": 42.0 * k},
		{"id": "weapon", "action": "weapon_next", "c": br + Vector2(-290, -330) * k, "r": 28.0 * k},
		{"id": "fullscreen", "action": "", "c": tr + Vector2(-40, 40) * k, "r": 24.0 * k},
		{"id": "menu", "action": "pause", "c": tr + Vector2(-104, 40) * k, "r": 28.0 * k},
		# The climber screen and the inventory, beside Menu.
		{"id": "climber", "action": "climber", "c": tr + Vector2(-172, 40) * k, "r": 26.0 * k},
		{"id": "inventory", "action": "inventory", "c": tr + Vector2(-236, 40) * k, "r": 26.0 * k},
		# Items: bottom middle-right, clear of roll and the cast buttons.
		{"id": "item", "action": "use_item", "c": br + Vector2(-395, -48) * k, "r": 34.0 * k},
		{"id": "item_next", "action": "item_next", "c": br + Vector2(-478, -48) * k, "r": 22.0 * k},
	]
	# Take: only while you stand on gear you'd swap for (Y on a keyboard).
	if not main.gear_here.is_empty():
		buttons.append({"id": "take", "action": "interact", "c": br + Vector2(-400, -372) * k, "r": 34.0 * k})
	# One cast button per mark you carry, in these spots around attack.
	var spots := [Vector2(-282, -222), Vector2(-52, -262), Vector2(-48, -368), Vector2(-405, -150), Vector2(-160, -400), Vector2(-395, -265)]
	var i := 0
	var p = main.player
	for part in main.BondScript.Bonds.PARTS:
		if p != null and p.bonds.has(part):
			buttons.append({"id": "cast_" + part, "action": "cast_" + part, "c": br + spots[i] * k, "r": 34.0 * k, "part": part})
			i += 1


func _input(event: InputEvent) -> void:
	# A menu is open: its own buttons take the touches.
	if main.menu_open():
		if event is InputEventScreenTouch and not active:
			_set_active(true)
		return
	# At a camp: a tap on a card takes it.
	if main.camp_choosing:
		if event is InputEventScreenTouch:
			if not active:
				_set_active(true)
			if event.pressed and main.hud != null:
				var c: int = main.hud.camp_card_at(event.position)
				if c >= 0:
					main.choose_camp(c)
			get_viewport().set_input_as_handled()
		return
	# Choosing a tower: a tap on a card picks it (on the train, its menu does).
	if main.choosing_tower and not main.on_train:
		if event is InputEventScreenTouch:
			if not active:
				_set_active(true)
			if not event.pressed:
				_release_all()  # a thumb lifted while this screen took the touch
			if event.pressed and main.hud != null:
				var i: int = main.hud.tower_card_at(event.position)
				if i >= 0:
					main.choose_tower(main.Towers.ORDER[i])
			get_viewport().set_input_as_handled()
		return
	# During the Regard, a tap (once it has played) begins the next climb.
	if main.overlay_showing():
		if event is InputEventScreenTouch:
			if not active:
				_set_active(true)
			if not event.pressed:
				_release_all()
			if event.pressed and main.overlay_done():
				main.end_regard()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		if not active:
			_set_active(true)
		if event.pressed:
			_touch_down(event.index, event.position)
		else:
			_touch_up(event.index)
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag:
		if event.index == stick_touch:
			stick_pos = event.position
			_update_stick()
		elif held.has(event.index) and String(held[event.index]).begins_with("cast_"):
			# Holding a mark's button: slide to pick a spell from its ring.
			for bt in buttons:
				if bt["id"] == held[event.index]:
					main.pick_anchor = bt["c"]
					main.player.pick_dir_override = event.position - bt["c"]
		elif held.has(event.index) and held[event.index] == "item":
			# Holding Item: slide to pick from the ring of belt items.
			for bt in buttons:
				if bt["id"] == "item":
					main.pick_anchor = bt["c"]
					main.player.item_dir_override = event.position - bt["c"]
		get_viewport().set_input_as_handled()
	elif active and (event is InputEventKey or event is InputEventMouseButton or event is InputEventMouseMotion):
		# Someone picked up a keyboard or mouse: hand control back to them.
		if not (event is InputEventMouseMotion and event.relative.length() < 2.0):
			_set_active(false)


func _set_active(on: bool) -> void:
	active = on
	main.touch_active = on
	get_tree().root.content_scale_factor = PHONE_SCALE if on else 1.0
	if main.player != null:
		main.player.touch_aim = on
	if not on:
		_release_all()
	elif main.pad != null and main.pad.active:
		main.pad._set_active(false)  # a touch: touch prompts, not controller ones
	queue_redraw()


func _touch_down(index: int, pos: Vector2) -> void:
	_layout()
	# Fallen (after the Regard): only the top bar answers; a tap anywhere
	# else goes back to the train.
	var fallen: bool = main.fallen()
	for b in buttons:
		if fallen and not (b["id"] in TOP_BAR):
			continue
		if pos.distance_to(b["c"]) <= b["r"] + 12.0:
			held[index] = b["id"]
			held_since[index] = Time.get_ticks_msec()
			if b["id"] == "fullscreen":
				var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
				DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
			elif b["action"] != "":
				if String(b["id"]).begins_with("cast_") or b["id"] == "item":
					main.pick_anchor = b["c"]
				Input.action_press(b["action"])
				if b["id"] in ONE_SHOT:
					# Taps: release on the next frame so the next tap registers too.
					get_tree().create_timer(0.05, true, false, true).timeout.connect(Input.action_release.bind(b["action"]))
			return
	if fallen:
		main.fall_tapped()
		return
	# Anywhere on the left side starts the joystick under the thumb.
	if stick_touch == -1 and pos.x < get_viewport_rect().size.x * 0.5:
		stick_touch = index
		stick_origin = pos
		stick_pos = pos
		_update_stick()


func _touch_up(index: int) -> void:
	if index == stick_touch:
		stick_touch = -1
		_set_move(Vector2.ZERO)
	elif held.has(index):
		var id: String = held[index]
		held.erase(index)
		var quick: bool = Time.get_ticks_msec() - int(held_since.get(index, 0)) < 60
		held_since.erase(index)
		for b in buttons:
			if b["id"] == id and b["action"] != "" and not (id in ONE_SHOT):
				if id in HOLD_TAP and quick:
					# (a tap shorter than a frame: let go a moment later, so it counts)
					get_tree().create_timer(0.05, true, false, true).timeout.connect(Input.action_release.bind(b["action"]))
				else:
					Input.action_release(b["action"])


func _update_stick() -> void:
	var off := stick_pos - stick_origin
	# Past the ring's edge the stick follows your thumb.
	if off.length() > FOLLOW_RADIUS:
		stick_origin = stick_pos - off.normalized() * FOLLOW_RADIUS
		off = stick_pos - stick_origin
	_set_move((off / STICK_RADIUS).limit_length(1.0))


## The joystick: past a light tilt you walk at full speed (there is no sprint).
const STICK_DEAD := 0.15
const STICK_FULL := 0.45
const FOLLOW_RADIUS := STICK_RADIUS * 1.4


func _set_move(v: Vector2) -> void:
	var m := v.length()
	if m < STICK_DEAD:
		_axis("move_right", "move_left", 0.0)
		_axis("move_down", "move_up", 0.0)
		return
	var strength := clampf((m - STICK_DEAD) / (STICK_FULL - STICK_DEAD), 0.25, 1.0)
	var d := v / m * strength
	_axis("move_right", "move_left", d.x)
	_axis("move_down", "move_up", d.y)


func _axis(pos_action: String, neg_action: String, value: float) -> void:
	if value > 0.0:
		Input.action_press(pos_action, value)
		Input.action_release(neg_action)
	elif value < 0.0:
		Input.action_press(neg_action, -value)
		Input.action_release(pos_action)
	else:
		Input.action_release(pos_action)
		Input.action_release(neg_action)


func release_all() -> void:
	_release_all()


func _release_all() -> void:
	for a in HELD_ACTIONS:
		Input.action_release(a)
	stick_touch = -1
	_set_move(Vector2.ZERO)
	for b in buttons:
		if b["action"] != "":
			Input.action_release(b["action"])
	held.clear()
	held_since.clear()


## The buttons are drawn again only when something on them changes (a
## press, the stick, a mark filling, the item count...): redrawing them every
## frame cost a phone more than the rest of the HUD.
var _drawn := []
var redraws := 0  # (tests)


func _process(_delta: float) -> void:
	if not active:
		if not _drawn.is_empty():
			_drawn = []
			queue_redraw()
		return
	var s := _signature()
	if s != _drawn:
		_drawn = s
		queue_redraw()


func _signature() -> Array:
	var p = main.player
	var s := [get_viewport_rect().size, held.duplicate(), stick_touch, stick_origin, stick_pos, main.gear_here.is_empty(),
		main.choosing_tower, main.camp_choosing, main.overlay_showing(), main.menu_open()]
	if p != null:
		s.append_array([p.dead, p.weapon, snappedf(p.draw_t, 0.04) if p.drawing else -1.0, snappedf(p.reload_t, 0.05),
			p.selected_item(), p.item_count(p.selected_item()) if p.selected_item() != "" else 0])
		for part in p.bonds:
			var b = p.bonds[part]
			s.append_array([part, b.id, snappedf(b.essence / b.capacity(), 0.01), b.essence >= b.cost(), b.selected])
	return s


func _draw() -> void:
	redraws += 1
	if not active or main.choosing_tower or main.camp_choosing or main.overlay_showing() or main.menu_open():
		return  # nothing to press while choosing a tower or during the Regard
	_layout()
	var font := ThemeDB.fallback_font
	var size := get_viewport_rect().size
	if size.x < size.y:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, 0.85))
		draw_string(font, Vector2(0, size.y / 2.0), "Turn your phone sideways", HORIZONTAL_ALIGNMENT_CENTER, size.x, 28, Color(0.95, 0.8, 0.5))
		return

	if stick_touch != -1:
		draw_circle(stick_origin, STICK_RADIUS, Color(0, 0, 0, 0.3))
		draw_arc(stick_origin, STICK_RADIUS, 0.0, TAU, 40, Color(1, 1, 1, 0.25), 2.0, true)
		var knob := stick_origin + (stick_pos - stick_origin).limit_length(STICK_RADIUS)
		draw_circle(knob, 28.0, Color(1, 1, 1, 0.35))
	else:
		if main.gear_here.is_empty() and not (main.player != null and main.player.dead):  # (the gear card sits here while you stand on gear)
			draw_string(font, Vector2(30, size.y - 30), "touch here to move", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(1, 1, 1, 0.3))

	var p = main.player
	var down := held.values()
	for b in buttons:
		if p != null and p.dead and not (b["id"] in TOP_BAR):
			continue  # fallen: only Menu (to restart) matters, and the message stays clear
		var c: Vector2 = b["c"]
		var r: float = b["r"]
		var pressed: bool = b["id"] in down
		var col := Color(1, 1, 1)
		var fill := 0.0
		var label := ""
		var ready := false  # a mark with enough essence to cast: its button lights up
		match b["id"]:
			"attack":
				label = p.Weapons.WEAPONS[p.weapon]["name"] if p != null else "Attack"
				if p != null and p.drawing:
					fill = clampf(p.draw_t / p.wdata()["draw_time"], 0.0, 1.0)
				elif p != null and p.reload_t > 0.0 and p.wkind() == "crossbow":
					# Reloading: the ring fills as the crossbow is wound.
					fill = 1.0 - clampf(p.reload_t / float(p.wdata()["reload"]), 0.0, 1.0)
					col = Color(0.7, 0.7, 0.75)
			"roll":
				label = "Roll"
			"jump":
				label = "Jump"
			"parry":
				label = "Parry"
			"cast_hand", "cast_legs", "cast_heart", "cast_brow", "cast_throat", "cast_back":
				var bond = p.bonds.get(b["part"]) if p != null else null
				if bond != null:
					col = bond.color()
					fill = bond.essence / bond.capacity()
					label = bond.spell_name().split(" ")[0]
					ready = bond.essence >= bond.cost()
			"weapon":
				label = "Swap"
			"take":
				label = "Take"
				col = Color(1.0, 0.85, 0.5)
			"item":
				var id: String = p.selected_item() if p != null else ""
				if id != "":
					col = Items.color(id)
					Items.draw_icon(self, id, c + Vector2(0, -5), r * 0.42)
					label = "%d" % p.item_count(id)
				else:
					label = "Item"
					col = Color(1, 1, 1, 0.5)
			"item_next":
				label = ">"
			"fullscreen":
				label = "[ ]"
			"menu":
				label = "Menu"
			"climber":
				label = "Climber"
			"inventory":
				label = "Bag"
		# A dark glassy disc with a coloured rim and a glint; a mark's button
		# carries its emblem.
		var bt := Draw.Batch.new()
		if ready:
			UI.glow_into(bt, c, r * 1.35, col, 0.9)
		bt.dot(c, r + 1.6, Color(0, 0, 0, 0.3))
		bt.dot(c, r, Color(0.035, 0.03, 0.05, 0.5 if not pressed else 0.68))
		bt.arc(c, r - 1.2, 0.0, TAU, 40, Color(col, 0.95 if pressed or ready else 0.55), 3.5 if ready else 2.5)
		bt.arc(c, r - 5.0, PI * 1.08, PI * 1.5, 10, Color(1, 1, 1, 0.13), 2.0)
		var bond_aff := ""
		if b.has("part") and p != null and p.bonds.has(b["part"]):
			bond_aff = p.bonds[b["part"]].data()["affinity"]
			UI.emblem_into(bt, c + Vector2(0, -r * 0.2), r * 0.34, bond_aff, Color(col, 0.85), 0.0)
		bt.flush(self)
		if fill > 0.0:
			draw_arc(c, r - 4.0, -PI / 2.0, -PI / 2.0 + TAU * fill, 40, Color(col, 0.9), 4.0, true)
		if pressed:
			draw_circle(c, r - 3.0, Color(col, 0.18))
		var fsize := 13 if r > 30.0 else 10
		if b["id"] == "climber" or b["id"] == "inventory":
			_draw_top_icon(b["id"], c + Vector2(0, -4), r, Color(col, 0.85))
			draw_string(font, c + Vector2(-r, r * 0.62), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 8, Color(col, 0.9))
			continue
		if bond_aff != "":
			draw_string(font, c + Vector2(-r, r * 0.55), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 10, Color(col, 0.95))
			continue
		if b["id"] == "item" and label != "Item":
			draw_string(font, c + Vector2(-r, r * 0.75), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 11, Color(col, 0.95))
			continue
		draw_string(font, c + Vector2(-r, fsize * 0.35), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, fsize, Color(col, 0.9))


## The little pictures on the Climber (a figure) and Bag (a satchel) buttons.
func _draw_top_icon(id: String, c: Vector2, r: float, col: Color) -> void:
	var u := r / 20.0
	if id == "climber":
		draw_circle(c + Vector2(0, -5) * u, 3.2 * u, col)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-5, 6) * u, c + Vector2(-3, -1) * u, c + Vector2(3, -1) * u, c + Vector2(5, 6) * u]), col)
	else:
		draw_rect(Rect2(c + Vector2(-6, -2) * u, Vector2(12, 9) * u), col)
		draw_arc(c + Vector2(0, -2) * u, 3.5 * u, PI, TAU, 8, col, maxf(1.0, 1.4 * u), true)
