extends Node2D
## Screen overlay, kept small so the tower gets the screen.
##
## Always there (top left, the "core"): a slim health bar and stamina bar,
## the weapon in hand, the quick item, and a small medallion per mark that
## glows once it can cast. The core is drawn on its own canvas item and only
## redrawn when one of its values changes.
##
## Fading in and out when they matter (this node): the essence you've
## gathered since the last stair, a popup of your weapons when you swap, the
## floor's title on arrival, the open stair, the keys for the menus, banners,
## and the big overlays (the Regard, choosing a tower, camps). This layer is
## only redrawn while something on it is showing.
##
## The rest lives in the Climber screen (Tab) and the Inventory (I): every
## weapon slot and the armor, attributes, and where your next mark is forming.

const BondScript := preload("res://scripts/bond.gd")
const Palette := preload("res://scripts/palette.gd")
const Essence := preload("res://scripts/essence.gd")
const Items := preload("res://scripts/items.gd")
const Gear := preload("res://scripts/gear.gd")
const Controls := preload("res://scripts/controls.gd")

const UI := preload("res://scripts/ui.gd")
const Draw := preload("res://scripts/draw_util.gd")
const Entity := preload("res://scripts/entity.gd")

const GOLD := UI.GOLD
const TEXT := UI.TEXT
const DIM_TEXT := UI.DIM

## The core's layout, in HUD units (times the HUD size setting).
const BAR_X := 16.0
const BAR_Y := 14.0
const BAR_W := 210.0
const SLOT := 34.0  # the weapon and item slots
const ROW_Y := 44.0  # their row, under the bars
const MARK_R := 13.0  # a mark's medallion
## How long the fading bits stay (seconds).
const ESSENCE_SHOW := 3.0
const SWAP_SHOW := 1.5
const FLOOR_SHOW := 5.0
const STAIR_SHOW := 5.0
const HINTS_SHOW := 8.0

var main
var vignette: GradientTexture2D  # (the hurt flash)
var panel: StyleBoxFlat
var slot: StyleBoxFlat
var slot_on: StyleBoxFlat
var hp_trail := 1.0  # the lagging "damage taken" chunk
var sta_trail := 1.0
var show_help := false  # the keyboard controls panel (a setting)
var hud_scale := 1.0  # the HUD size setting (ui.gd HUD_SCALES)
var tips: Array = []  # [rect, title, lines] of what the mouse can hover for a tooltip
var tip_box: StyleBoxFlat
var core: Node2D  # the always-there part, drawn under this node
var core_redraws := 0  # times the core was drawn (tests, dev readout)
var top_redraws := 0  # times this layer was drawn
var show_perf := false  # the dev readout (menu.gd's dev tools)
# The fading bits: seconds left for each.
var essence_t := 0.0
var swap_t := 0.0
var floor_t := 0.0
var stair_t := 0.0
var hints_t := 0.0
var _core_state := []
var _top_state := []
var _was_live := false
var _last_weapon := ""
var _last_essence := 0.0
var _last_floor := []
var _last_stair := false
var _tip_over := -1
var redraw_t := 0.0
var perf_t := 0.0
var perf_text: Array = []


func _ready() -> void:
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0))
	g.set_color(1, Color(0, 0, 0, 1))
	g.add_point(0.55, Color(0, 0, 0, 0))
	vignette = GradientTexture2D.new()
	vignette.gradient = g
	vignette.fill = GradientTexture2D.FILL_RADIAL
	vignette.fill_from = Vector2(0.5, 0.5)
	vignette.fill_to = Vector2(1.0, 1.0)
	vignette.width = 128
	vignette.height = 128
	panel = UI.panel()
	slot = UI.slot()
	slot_on = UI.slot(true)
	tip_box = UI.box(Color(0.06, 0.055, 0.08, 0.96), Color(UI.GOLD, 0.45), 6)
	tip_box.shadow_color = Color(0, 0, 0, 0.5)
	tip_box.shadow_size = 6
	# The core goes just under this node, in the same layer.
	core = Node2D.new()
	core.name = "HudCore"
	core.draw.connect(_draw_core)
	add_sibling.call_deferred(core)
	(func(): if core.get_parent() != null: get_parent().move_child(core, get_index())).call_deferred()


func _box(bg: Color, border: Color, radius: int) -> StyleBoxFlat:
	var b := StyleBoxFlat.new()
	b.bg_color = bg
	b.border_color = border
	b.set_border_width_all(1)
	b.set_corner_radius_all(radius)
	b.anti_aliasing = true
	return b


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("toggle_help"):
		show_help = not show_help
	var p = main.player
	if p != null:
		# The trail holds for a moment, then drains down to the real value.
		hp_trail = move_toward(hp_trail, p.hp / p.max_hp, delta * (0.6 if hp_trail > p.hp / p.max_hp else 10.0))
		sta_trail = move_toward(sta_trail, p.sta / p.max_sta, delta * (0.8 if sta_trail > p.sta / p.max_sta else 10.0))
		_notice_changes(p)
	essence_t = maxf(0.0, essence_t - delta)
	swap_t = maxf(0.0, swap_t - delta)
	floor_t = maxf(0.0, floor_t - delta)
	stair_t = maxf(0.0, stair_t - delta)
	hints_t = maxf(0.0, hints_t - delta)
	if not main.loot_notice.is_empty():
		main.loot_notice["t"] -= delta
		if main.loot_notice["t"] <= 0.0:
			main.loot_notice = {}
	# The core: only when something on it changed.
	var cs := _core_signature()
	if cs != _core_state:
		_core_state = cs
		if core != null:
			core.queue_redraw()
	# This layer: 30 times a second while something moves on it, once more
	# when it all goes, and otherwise only when what it shows changes.
	_update_tip()
	var live := _top_live()
	var ts := _top_signature()
	redraw_t -= delta
	if live and redraw_t <= 0.0:
		redraw_t = 1.0 / 30.0
		queue_redraw()
	elif (_was_live and not live) or ts != _top_state:
		queue_redraw()
	_top_state = ts
	_was_live = live
	if show_perf:
		perf_t -= delta
		if perf_t <= 0.0:
			perf_t = 0.25
			perf_text = main.perf_lines() if main.has_method("perf_lines") else []
			queue_redraw()


## Starts the fading bits when what they show changes.
func _notice_changes(p) -> void:
	if p.weapon != _last_weapon:
		if _last_weapon != "":
			swap_t = SWAP_SHOW
		_last_weapon = p.weapon
	var held := 0.0
	for k in main.run_essence:
		held += float(main.run_essence[k])
	if held > _last_essence + 0.01:
		essence_t = ESSENCE_SHOW
	_last_essence = held
	var fk := [main.floor_num, main.tower, main.in_camp]
	if fk != _last_floor:
		_last_floor = fk
		floor_t = FLOOR_SHOW
		hints_t = HINTS_SHOW
	var st: bool = main.stair_open and not main.climbing
	if st and not _last_stair:
		stair_t = STAIR_SHOW
	_last_stair = st


## Everything the core shows; it's redrawn when this changes.
func _core_signature() -> Array:
	var p = main.player
	if p == null or main.title_showing():
		return [false]
	var s := [true, hud_scale, get_viewport_rect().size, main.touch_active, main.pad_active, main.pad_ps,
		int(ceil(p.hp)), int(round(p.max_health())), p.max_hp, int(p.sta), p.max_sta,
		snappedf(hp_trail, 0.004), snappedf(sta_trail, 0.01), int(ceil(p.barrier_hp)),
		p.weapon, snappedf(p.reload_t, 0.05) if p.wkind() == "crossbow" else 0.0,
		p.selected_item(), p.item_count(p.selected_item()) if p.selected_item() != "" else 0]
	for part in BondScript.Bonds.PARTS:
		var b = p.bonds.get(part)
		if b != null:
			s.append_array([part, b.id, int(b.essence), b.capacity(), b.essence >= b.cost(), b.burned, b.faint])
	return s


## True while something on this layer moves (it's redrawn 30 times a second).
func _top_live() -> bool:
	var p = main.player
	if p == null:
		return false
	return main.fade > 0.0 or main.hurt_flash > 0.0 or not main.banner.is_empty() \
		or essence_t > 0.0 or swap_t > 0.0 or floor_t > 0.0 or stair_t > 0.0 or (hints_t > 0.0 and not main.touch_active) \
		or not main.regard.is_empty() or not main.victory.is_empty() or main.choosing_tower or main.camp_choosing \
		or p.pick_open or p.ring_open or not main.loot_notice.is_empty() or (main.stair_open and not main.climbing) or _tip_over >= 0 or _boss_alive() \
		or (p.has_bond("hunter") and p.quarry != null) or (main.wings != null and main.wings.challenge_live()) \
		or (main.door_view != null and not main.door_view.lock_status().is_empty())


## What this layer shows that doesn't move: it's redrawn when this changes.
func _top_signature() -> Array:
	var p = main.player
	return [show_help, main.pad_active, main.pad_ps, main.touch_active, hud_scale, get_viewport_rect().size,
		main.gear_here.get("id", ""), p.gear_signature() if p != null else [], p != null and p.dead,
		main.title_showing(), main.menu_open(), main.overlay_showing(), show_perf, main.fall_note.size()]


func _boss_alive() -> bool:
	for e in main.enemies():
		if e.is_boss():
			return true
	return false


## Which tooltip the mouse is over (-1 for none).
func _update_tip() -> void:
	var over := -1
	if not (main.touch_active or main.pad_active or main.menu_open()):
		var m := get_local_mouse_position() / hud_scale
		for i in tips.size():
			if tips[i][0].has_point(m):
				over = i
				break
	_tip_over = over


## A fading bit's alpha: fades in over its first quarter second, out over its last half.
static func _fade(t: float, total: float) -> float:
	return clampf(minf(t / 0.5, (total - t) / 0.25), 0.0, 1.0)


# --- the core (always there) ---------------------------------------------------------

func _draw_core() -> void:
	core_redraws += 1
	tips.clear()
	var p = main.player
	if p == null or main.title_showing():
		return
	var c := core
	var font := ThemeDB.fallback_font
	var hs := hud_scale
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2(hs, hs))
	var b := Draw.Batch.new()
	# Health and stamina: slim bars, the health number on its bar.
	var hp_k: float = p.hp / p.max_hp
	UI.bar_into(b, Rect2(BAR_X, BAR_Y, BAR_W, 12), hp_k, UI.HEALTH, hp_trail)
	UI.bar_into(b, Rect2(BAR_X, BAR_Y + 18.0, BAR_W * p.max_sta / 100.0, 6), p.sta / p.max_sta, UI.STAMINA, sta_trail, Color(0.95, 0.95, 0.7, 0.7))
	if p.barrier_hp > 0.0:
		# The Warden's barrier: a gold band over the health bar.
		var bw: float = BAR_W * clampf(p.barrier_hp / p.max_hp, 0.0, 1.0)
		UI.capsule(b, BAR_X, BAR_X + bw, BAR_Y + 3.0, 2.5, Color(1.0, 0.85, 0.45, 0.9))
	if p.max_health() < p.max_hp:
		# A burned heart caps your health: the lost part shows scorched (the
		# Proving's wound: bruised violet).
		var cap_x: float = BAR_X + BAR_W * p.max_health() / p.max_hp
		b.rect(Rect2(Vector2(cap_x, BAR_Y), Vector2(BAR_X + BAR_W - cap_x, 12)), Color(0.6, 0.45, 0.95, 0.4) if p.wound > 0.0 else Color(1.0, 0.35, 0.2, 0.35))
	var bars_rect := Rect2(BAR_X - 4, BAR_Y - 4, BAR_W + 8, 32)
	# The weapon in hand and the quick item: two small slots.
	var wr := Rect2(BAR_X, ROW_Y, SLOT, SLOT)
	var slot_i: int = p.slots().find(p.weapon)
	c.draw_style_box(slot_on, wr)
	UI.glow_into(b, wr.get_center(), SLOT * 0.42, Gear.color(p.weapon), 0.6)
	Gear.icon_into(b, p.weapon_rec(), wr.get_center(), 10.5, Gear.color(p.weapon))  # (cracked when badly worn)
	if p.reload_t > 0.0 and p.wkind() == "crossbow":
		var rk: float = clampf(p.reload_t / float(p.wdata()["reload"]), 0.0, 1.0)
		b.rect(Rect2(wr.position + Vector2(2, 2), Vector2(SLOT - 4, (SLOT - 4) * rk)), Color(0, 0, 0, 0.45))
	tips.append([wr, Gear.display(p.weapon), _gear_tip(p.weapon, maxi(slot_i, 0))])
	var x := wr.end.x + 6.0
	var sel: String = p.selected_item()
	var ir := Rect2()
	if sel != "":
		ir = Rect2(x, ROW_Y, SLOT, SLOT)
		c.draw_style_box(slot, ir)
		Items.icon_into(b, sel, ir.get_center() + Vector2(0, -1), 10.5)
		tips.append([ir, Items.ITEMS[sel]["name"], [_sentence(Items.ITEMS[sel]["desc"]),
			"Carrying %d  ·  %s to use it%s" % [p.item_count(sel), _use_key(), "" if p.carried().size() < 2 else "  ·  %s picks another" % _next_key()]]])
		x = ir.end.x + 6.0
	# Marks: a medallion each, its ring filling with essence; bright once it can cast.
	var marks: Array = []
	for part in BondScript.Bonds.PARTS:
		if p.bonds.has(part):
			marks.append(part)
	var mx := x + MARK_R + 4.0
	var my := ROW_Y + SLOT * 0.5
	for part in marks:
		var bd = p.bonds[part]
		var col: Color = bd.color()
		var ready: bool = bd.essence >= bd.cost()
		var mc := Vector2(mx, my)
		UI.medallion_into(b, mc, MARK_R, col if ready else col.darkened(0.45), bd.data()["affinity"], bd.essence / bd.capacity(), 0, 0.7 if ready else 0.0, bd.faint)
		if bd.burned:
			b.arc(mc, MARK_R + 3.0, 0.0, TAU, 28, Color(1.0, 0.4, 0.3, 0.9), 2.0)
		var key := _cast_key(part)
		tips.append([Rect2(mc - Vector2(MARK_R + 3, MARK_R + 3), Vector2(MARK_R * 2 + 6, MARK_R * 2 + 6)), "%s  (%s)" % [bd.display_name(), BondScript.PART_NAMES[part]],
			["%s: %s" % [bd.spell_name(), bd.spell_desc()],
			"Essence %d / %d  ·  costs %d" % [int(bd.essence), int(bd.capacity()), int(round(bd.cost()))],
			("%s burned: overdraw again and it tears (costs health)" % BondScript.PART_NAMES[part]) if bd.burned else ("Press %s to cast%s" % [key, ", hold it to pick a spell" if bd.spells().size() > 1 else ""] if not main.touch_active else "Its button is on the right"),
			"Tab: the climber screen has every spell"]])
		mx += MARK_R * 2.0 + 8.0
	b.flush(c)
	# Words last, over the shapes.
	var hp_text := "%d / %d" % [int(ceil(p.hp)), int(round(p.max_health()))]
	c.draw_string_outline(font, Vector2(BAR_X + 6, BAR_Y + 10.5), hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, 3, Color(0, 0, 0, 0.85))
	c.draw_string(font, Vector2(BAR_X + 6, BAR_Y + 10.5), hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(1, 0.95, 0.92))
	var wound_text: String = main.proving.wound_text() if main.proving != null else ""
	if wound_text != "":  # the Proving's lingering wound, small at the bar's end
		var tag: String = main.proving.TEXT["wound_tag"]
		c.draw_string_outline(font, Vector2(BAR_X + BAR_W - 56, BAR_Y + 10), tag, HORIZONTAL_ALIGNMENT_RIGHT, 52, 8, 3, Color(0, 0, 0, 0.85))
		c.draw_string(font, Vector2(BAR_X + BAR_W - 56, BAR_Y + 10), tag, HORIZONTAL_ALIGNMENT_RIGHT, 52, 8, Color(0.82, 0.74, 1.0))
	tips.append([bars_rect, "Health %s" % hp_text, ["Stamina %d / %d: rolls, strikes and parries use it" % [int(p.sta), int(p.max_sta)]] + ([wound_text] if wound_text != "" else [])])
	if slot_i >= 0 and not main.touch_active:
		c.draw_string_outline(font, wr.position + Vector2(3, 11), str(slot_i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, 3, Color(0, 0, 0, 0.8))
		c.draw_string(font, wr.position + Vector2(3, 11), str(slot_i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, GOLD)
	if sel != "":
		var n := str(p.item_count(sel))
		c.draw_string_outline(font, ir.end + Vector2(-9, -3), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0, 0, 0, 0.9))
		c.draw_string(font, ir.end + Vector2(-9, -3), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GOLD)
		if not main.touch_active:
			UI.draw_key(c, ir.position + Vector2(-3, -5), _use_key(), 8)
	if not main.touch_active:
		mx = x + MARK_R + 4.0
		for part in marks:
			var bd = p.bonds[part]
			var ready: bool = bd.essence >= bd.cost()
			UI.draw_key(c, Vector2(mx + 3.0, my + 3.0), _cast_key(part), 8, bd.color().lightened(0.2) if ready else DIM_TEXT)
			mx += MARK_R * 2.0 + 8.0
	c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The key (or controller button) that casts a part's mark.
func _cast_key(part: String) -> String:
	if main.pad_active:
		return Controls.pad_name(Controls.PART_PAD[part], main.pad_ps, true)
	return BondScript.Bonds.PART_KEYS[part]


func _use_key() -> String:
	if main.touch_active:
		return "Item"
	return Controls.pad_name("x", main.pad_ps, true) if main.pad_active else "G"


func _next_key() -> String:
	if main.touch_active:
		return "the arrow by Item"
	return "D-pad down" if main.pad_active else "T"


# --- this layer (fading bits and overlays) ---------------------------------------------

func _draw() -> void:
	top_redraws += 1
	var p = main.player
	if p == null or main.title_showing():
		return  # (the title screen covers everything)
	var font := ThemeDB.fallback_font
	var size := get_viewport_rect().size

	# Getting hurt flashes the screen edges red. (The darkness layer draws the vignette.)
	if main.hurt_flash > 0.0:
		draw_texture_rect(vignette, Rect2(Vector2.ZERO, size), false, Color(0.9, 0.08, 0.05, main.hurt_flash / 0.35))

	# The small fading bits are drawn at the HUD size setting, under the core.
	var real_size := size
	var hs := hud_scale
	size = real_size / hs
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(hs, hs))
	var y := ROW_Y + SLOT + 8.0
	if swap_t > 0.0:
		y += _draw_swap(p, Vector2(BAR_X, y), font, _fade(swap_t, SWAP_SHOW)) + 6.0
	if essence_t > 0.0:
		_draw_essence(Vector2(BAR_X, y), font, _fade(essence_t, ESSENCE_SHOW))

	# Controls, top right.
	if main.touch_active:
		pass  # the touch buttons are labelled; no keyboard help needed
	elif show_help:
		_draw_help(size, font)
	elif hints_t > 0.0:
		_draw_screen_hints(size, font, _fade(hints_t, HINTS_SHOW))
	if not main.gear_here.is_empty() and not main.camp_choosing and main.fade <= 0.0 and not main.overlay_showing() and not main.menu_open():
		_draw_gear_prompt(p, main.gear_here["rec"], size, font)
	if show_perf:
		_draw_perf(size, font)
	_draw_tip(font)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	size = real_size

	# The floor's title on arrival, top centre, fading out.
	if floor_t > 0.0 or stair_t > 0.0:
		var fa := _fade(maxf(floor_t, stair_t), FLOOR_SHOW)
		var floor_text: String = main._floor_title()
		draw_string_outline(font, Vector2(0, 30), floor_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, 5, Color(0, 0, 0, 0.8 * fa))
		draw_string(font, Vector2(0, 30), floor_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 20, Color(GOLD, fa))
		var sub_text := "%s  ·  best %d" % [main.tower_data()["short"], main.best_floor]
		draw_string_outline(font, Vector2(0, 48), sub_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, 3, Color(0, 0, 0, 0.6 * fa))
		draw_string(font, Vector2(0, 48), sub_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 12, Color(DIM_TEXT, fa))
	if stair_t > 0.0 and main.stair_open and not main.climbing:
		var sa := _fade(stair_t, STAIR_SHOW)
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.005)
		var left: int = main.enemies().size()
		var stair_text := "The stair is open"
		if left > 0:
			stair_text += "  ·  %d %s left" % [left, "foe" if left == 1 else "foes"]
		draw_string_outline(font, Vector2(0, 68), stair_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, 4, Color(0, 0, 0, 0.7 * sa))
		draw_string(font, Vector2(0, 68), stair_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(1.0, 0.88, 0.6, pulse * sa))

	# A new floor: its number and what changed, fading out.
	if not main.banner.is_empty():
		var bn: Dictionary = main.banner
		var a: float = clampf(bn["t"] / 0.6, 0.0, 1.0)
		var top := size.y * 0.3
		draw_string_outline(font, Vector2(0, top), bn["title"], HORIZONTAL_ALIGNMENT_CENTER, size.x, 40, 7, Color(0, 0, 0, 0.8 * a))
		draw_string(font, Vector2(0, top), bn["title"], HORIZONTAL_ALIGNMENT_CENTER, size.x, 40, Color(GOLD, a))
		var ly := top + 30.0
		for line in bn["lines"]:
			draw_string_outline(font, Vector2(0, ly), line, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, 4, Color(0, 0, 0, 0.8 * a))
			draw_string(font, Vector2(0, ly), line, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, Color(TEXT, a))
			ly += 22.0

	# Messages: a banner across the middle.
	var msg := ""
	var sub := ""
	if p.dead and not main.first_climb:
		msg = "YOU FELL ON FLOOR %d" % main.floor_num
		sub = "Best: floor %d.  %s to climb again" % [main.best_floor, _say("Press R", "Press {back}", "Tap Menu, then Restart,")]
	# What the fall took (main.fall_note, lost.gd), under the banner's words.
	var note: Array = main.fall_note if p.dead and not main.first_climb else []
	var note_w := minf(size.x - 32.0, 760.0)
	var note_h := 0.0
	for line in note:
		note_h += font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_CENTER, note_w, 15).y + 4.0
	if msg != "":
		var band := Rect2(0, size.y / 2.0 - 70.0, size.x, 90.0 + (note_h + 8.0 if note_h > 0.0 else 0.0))
		draw_rect(band, Color(0, 0, 0, 0.55))
		draw_line(band.position, Vector2(band.end.x, band.position.y), Color(GOLD, 0.4), 1.0)
		draw_line(Vector2(0, band.end.y), band.end, Color(GOLD, 0.4), 1.0)
		var col := Color(0.9, 0.3, 0.25) if p.dead else GOLD
		draw_string_outline(font, Vector2(0, band.position.y + 48), msg, HORIZONTAL_ALIGNMENT_CENTER, size.x, 34, 6, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(0, band.position.y + 48), msg, HORIZONTAL_ALIGNMENT_CENTER, size.x, 34, col)
		draw_string(font, Vector2(0, band.position.y + 74), sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, TEXT)
		var ny := band.position.y + 100.0
		for i in note.size():
			var col_n := Color(0.95, 0.72, 0.62) if i == 0 else Color(TEXT, 0.75)
			draw_multiline_string(font, Vector2((size.x - note_w) / 2.0, ny), note[i], HORIZONTAL_ALIGNMENT_CENTER, note_w, 15, -1, col_n)
			ny += font.get_multiline_string_size(note[i], HORIZONTAL_ALIGNMENT_CENTER, note_w, 15).y + 4.0

	# Between floors the screen fades to black.
	if main.fade > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(0, 0, 0, main.fade))

	_draw_boss_bar(size, font)
	_draw_wing_status(size, font)
	if not main.regard.is_empty():
		_draw_regard(size, font)
	if not main.victory.is_empty():
		_draw_victory(size, font)
	if main.choosing_tower and not main.on_train:
		_draw_tower_choice(size, font)
	if main.camp_choosing:
		_draw_camp_choice(size, font)
	_draw_quarry(p, size, font)
	_draw_stair_arrow(size, font)
	if p.pick_open:
		_draw_spell_ring(p, font)
	if p.ring_open:
		_draw_item_ring(p, font)
	_draw_loot_notice(size, font)


## Swapping weapons: the three slots for a moment, the one in hand lit and named.
## Returns its height.
func _draw_swap(p, pos: Vector2, font: Font, a: float) -> float:
	var have: Array = p.slots()
	var r := Rect2(pos, Vector2(16.0 + 40.0 * have.size(), 62))
	draw_style_box(panel, r)
	var b := Draw.Batch.new()
	for i in have.size():
		var id: String = have[i]
		var c := r.position + Vector2(28.0 + 40.0 * i, 22)
		var on: bool = id == p.weapon and id != ""
		if on:
			UI.glow_into(b, c, 17.0, Gear.color(id), 0.8 * a)
		if id != "":
			Gear.icon_into(b, id, c, 10.0, Color(Gear.color(id), (1.0 if on else 0.45) * a))
		else:
			b.arc(c, 9.0, 0.0, TAU, 20, Color(UI.FAINT, 0.6 * a), 1.2)
	b.flush(self)
	for i in have.size():
		var c := r.position + Vector2(28.0 + 40.0 * i, 22)
		var on: bool = have[i] == p.weapon and have[i] != ""
		if not main.touch_active:
			draw_string(font, c + Vector2(-18, -6), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(GOLD if on else DIM_TEXT, a))
	draw_string(font, Vector2(r.position.x, r.end.y - 9.0), Gear.display(p.weapon), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 12, Color(TEXT, a))
	return r.size.y


## Essence gathered since the last stair (lost if you fall before it): gems and counts.
func _draw_essence(pos: Vector2, font: Font, a: float) -> void:
	var held: Array = Essence.KINDS.keys().filter(func(k): return main.run_essence.get(k, 0.0) > 0.0)
	if held.is_empty():
		return
	var pill := Rect2(pos, Vector2(16.0 + 44.0 * held.size() + 62.0, 22))
	draw_style_box(panel, pill)
	var gems := Draw.Batch.new()
	for gi in held.size():
		UI.gem_into(gems, pos + Vector2(14 + 44.0 * gi, 11), 5.0, Color(Essence.color(held[gi]), a))
	gems.flush(self)
	var ex := pos.x + 8.0
	for kind in held:
		draw_string(font, Vector2(ex + 14, pos.y + 16), str(int(main.run_essence[kind])), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(TEXT, a))
		ex += 44.0
	draw_string(font, Vector2(ex + 4, pos.y + 15), "unbanked", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(DIM_TEXT, a))


## The keyboard (or controller) controls, top right (H, or the Controls setting).
func _draw_help(size: Vector2, font: Font) -> void:
	var help: Array = []
	var key_w := 0.0
	for row in Controls.HELP:
		var k: String = Controls.pad_text(row[2], main.pad_ps) if main.pad_active else row[1]
		if k == "-":
			continue
		help.append([k, row[0]])
		key_w = maxf(key_w, font.get_string_size(k, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x)
	var box_w := key_w + 176.0
	var box := Rect2(size.x - box_w - 16.0, 14, box_w, 20 + help.size() * 17)
	draw_style_box(panel, box)
	for i in help.size():
		var row_y := box.position.y + 24 + i * 17
		draw_string(font, Vector2(box.position.x + 12, row_y), help[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, GOLD)
		draw_string(font, Vector2(box.position.x + key_w + 22, row_y), help[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT)


## The dev readout (dev tools): frame rate, draw calls and what's in the room.
func _draw_perf(size: Vector2, font: Font) -> void:
	if perf_text.is_empty():
		return
	var w := 230.0
	var r := Rect2(size.x - w - 16.0, size.y - 22.0 - 15.0 * perf_text.size(), w, 12.0 + 15.0 * perf_text.size())
	if main.touch_active:
		r.position = Vector2(BAR_X, ROW_Y + SLOT + 74.0)  # (the buttons have the bottom right)
	draw_rect(r, Color(0, 0, 0, 0.6))
	for i in perf_text.size():
		draw_string(font, r.position + Vector2(8, 16 + 15 * i), perf_text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.75, 1.0, 0.75))


## Top right, for the first seconds of a floor: the keys (or buttons) for the
## menu, climber screen and inventory.
func _draw_screen_hints(size: Vector2, font: Font, a := 1.0) -> void:
	var hints: Array = [["Esc", "{start}", "menu"], ["Tab", "{back}", "climber"], ["I", "D-pad up", "inventory"], ["H", "-", "keys"]]
	var parts: Array = []
	var w := 0.0
	for h in hints:
		var k: String = Controls.pad_text(h[1], main.pad_ps) if main.pad_active else h[0]
		if k == "-":
			continue
		parts.append([k, h[2]])
		w += font.get_string_size(k, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + font.get_string_size(h[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 22.0
	var r := Rect2(size.x - 16.0 - w - 8.0, 14, w + 8.0, 22)
	var pb: StyleBoxFlat = panel.duplicate() if a < 0.999 else panel
	if a < 0.999:
		pb.bg_color.a *= a
		pb.border_color.a *= a
	draw_style_box(pb, r)
	var x := r.position.x + 10.0
	for pt in parts:
		draw_string(font, Vector2(x, 29), pt[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(GOLD, a))
		x += font.get_string_size(pt[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 5.0
		draw_string(font, Vector2(x, 29), pt[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(DIM_TEXT, a))
		x += font.get_string_size(pt[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x + 17.0


## A weapon's key numbers, for its tooltip.
func _gear_tip(id: String, slot_i: int) -> Array:
	var lines: Array = []
	if slot_i < 3:
		var key := str(slot_i + 1)
		lines.append("Slot %s%s" % [key, "  ·  in hand" if id == main.player.weapon else "  ·  press %s to hold it" % key])
	for row in Gear.stats(main.player.weapon_rec() if id == main.player.weapon else id):
		lines.append("%s  %s" % [row[0], row[1]])
	lines.append("I: the inventory has everything you wear")
	return lines


## Hovering the mouse over a HUD slot or mark: a small card with what it is.
func _draw_tip(font: Font) -> void:
	if main.touch_active or main.pad_active or main.menu_open():
		return
	var m := get_local_mouse_position() / hud_scale
	for t in tips:
		var r: Rect2 = t[0]
		if not r.has_point(m):
			continue
		var lines: Array = t[2]
		var w := font.get_string_size(t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
		for l in lines:
			w = maxf(w, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x)
		var size := get_viewport_rect().size / hud_scale
		var box := Rect2(m + Vector2(16, 14), Vector2(w + 40.0, 26.0 + 16.0 * lines.size()))
		box.position.x = minf(box.position.x, size.x - box.size.x - 6.0)
		if box.end.y > size.y - 6.0:
			box.position.y = m.y - box.size.y - 10.0
		draw_style_box(tip_box, box)
		# The Entity tells you what it is (its small face in the corner).
		Entity.draw_face(self, box.position + Vector2(box.size.x - 13.0, 14.0), 7.0, 0.0)
		draw_string(font, box.position + Vector2(11, 19), t[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, GOLD)
		for i in lines.size():
			draw_string(font, box.position + Vector2(11, 37 + 16 * i), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT)
		return


## Standing on gear you'd have to swap for: a card naming its slot and
## comparing it with what you wear there, and how to take it.
func _draw_gear_prompt(p, id, size: Vector2, font: Font) -> void:
	var slot_id := Gear.slot_of(id)
	var held = p.gear.get(p.slot_for(id), {})
	var has_held: bool = Gear.is_gear(held)
	var rows: Array = Gear.compare(id, held if has_held else ({} if slot_id != "armor" else ""), 6)
	var traits: Array = Gear.trait_lines(id)
	var w := 330.0
	var h := 86.0 + 17.0 * rows.size() + 14.0 * traits.size()
	# Bottom centre; on a phone, bottom left of centre, clear of the buttons.
	var r := Rect2(Vector2((size.x - w) / 2.0, size.y - h - 24.0), Vector2(w, h))
	if main.touch_active:
		r.position = Vector2(clampf(size.x * 0.5 - w - 10.0, 110.0, size.x), size.y - h - 12.0)
	draw_style_box(panel, r)
	var col: Color = Gear.color(id)
	var rim: Color = Gear.rarity_color(id) if Gear.rarity(id) != "common" else col
	draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 4)), Color(rim, 0.85))
	var head: String = "%s  ·  %s" % [Gear.TEXT["on_floor"], String(Gear.SLOT_NAMES.get(slot_id, slot_id)).to_upper()]
	if Gear.rarity(id) != "common":
		head += "  ·  " + Gear.rarity_name(id).to_upper()
	draw_string(font, r.position + Vector2(12, 20), head, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, DIM_TEXT)
	Gear.draw_icon(self, id, r.position + Vector2(w - 26, 24), 11.0, col)
	draw_string(font, r.position + Vector2(12, 38), Gear.display(id), HORIZONTAL_ALIGNMENT_LEFT, w - 50, 15, rim.lightened(0.2))
	for i in traits.size():
		draw_string(font, r.position + Vector2(12, 53 + 14 * i), traits[i][0], HORIZONTAL_ALIGNMENT_LEFT, w - 24, 11, Color(traits[i][1], 0.95))
	var held_name: String = Gear.display(held) if has_held else (Gear.TEXT["none"] if slot_id == "armor" else Gear.TEXT["empty"])
	var x1 := r.position.x + 12.0
	var x2 := r.position.x + 128.0
	var x3 := r.position.x + 232.0
	var y := r.position.y + 58.0 + 14.0 * traits.size()
	draw_string(font, Vector2(x2, y), "this", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, DIM_TEXT)
	draw_string(font, Vector2(x3, y), held_name.to_lower(), HORIZONTAL_ALIGNMENT_LEFT, w - (x3 - r.position.x) - 6.0, 11, DIM_TEXT)
	var arrows := Draw.Batch.new()
	for row in rows:
		y += 17.0
		draw_string(font, Vector2(x1, y), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, TEXT)
		var better: int = row[3]
		var vcol := UI.GOOD if better > 0 else (UI.BAD if better < 0 else TEXT)
		draw_string(font, Vector2(x2, y), row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, vcol)
		draw_string(font, Vector2(x3, y), row[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, DIM_TEXT)
		if better != 0:
			UI.arrow_into(arrows, Vector2(x2 - 8.0, y - 4.0), 3.5, better > 0, vcol)
	arrows.flush(self)
	var how: String = _say(Gear.TEXT["take_key"], Gear.TEXT["take_pad"], Gear.TEXT["take_tap"])
	if has_held:
		how += "  " + (Gear.TEXT["to_pack"] if p.pack_room() else Gear.TEXT["drops"]) % Gear.display(held)
	draw_string(font, Vector2(r.position.x, r.end.y - 8.0), how, HORIZONTAL_ALIGNMENT_CENTER, w, 12, GOLD)


## The Regard: the beast's eye opens on you, and your first mark takes hold.
func _draw_regard(size: Vector2, font: Font) -> void:
	var rg: Dictionary = main.regard
	var t: float = rg["t"]
	var info: Dictionary = BondScript.Bonds.BONDS[rg["id"]]
	var col: Color = info["color"]
	var fell: bool = rg["fell"]
	var part_name: String = BondScript.PART_NAMES[rg["part"]]
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.03, _overlay_shade(rg, 0.96)))
	var c := Vector2(size.x / 2.0, size.y * 0.3)
	# The eye opens.
	var open := clampf((t - 0.4) / 1.2, 0.0, 1.0)
	open = open * open * (3.0 - 2.0 * open)
	var w := minf(size.x * 0.36, 300.0)
	var h := 70.0 * open
	var lid := PackedVector2Array()
	for i in 33:
		var k := float(i) / 32.0
		lid.append(c + Vector2(lerpf(-w, w, k), -sin(PI * k) * h))
	for i in 33:
		var k := float(i) / 32.0
		lid.append(c + Vector2(lerpf(w, -w, k), sin(PI * k) * h))
	draw_colored_polygon(lid, Color(0.95, 0.85, 0.55, 0.12 + 0.1 * open))
	draw_polyline(lid + PackedVector2Array([lid[0]]), Color(1.0, 0.85, 0.5, 0.8 * open + 0.1), 2.5, true)
	if open > 0.2:
		var iris := 52.0 * minf(1.0, open * 1.2)
		draw_circle(c, iris, Color(col, 0.55))
		draw_circle(c, iris * 0.62, Color(col.lightened(0.3), 0.8))
		draw_circle(c, iris * 0.28, Color(0.02, 0.02, 0.03, 0.95))
		draw_arc(c, iris, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 2.0, true)
	# The mark grows beneath it.
	var mk := clampf((t - 1.6) / 1.0, 0.0, 1.0)
	if mk > 0.0:
		var mc := c + Vector2(0, 130)
		var mcol := Color(col, (0.55 if fell else 1.0) * mk)
		draw_circle(mc, 10.0, mcol)
		var lines := 3 if fell else 6
		for i in lines:
			var a := -PI / 2.0 + TAU * float(i) / float(lines)
			draw_line(mc + Vector2.from_angle(a) * 14.0, mc + Vector2.from_angle(a) * (14.0 + 26.0 * mk), mcol, 3.0)
	var texts: Array = []
	if fell:
		texts = [
			"You fell, but %s was watching." % main.beast_name(),
			"Essence takes hold in your %s, faintly." % part_name,
			"You bear a faint %s mark." % info["name"],
			"It will grow once it has soaked up more essence.",
		]
	else:
		texts = [
			"You reached the top. %s has watched you climb." % main.beast_name().capitalize(),
			"Essence takes hold in your %s." % part_name,
			"You bear the %s mark." % info["name"],
			"%s: %s." % [info["spells"][0]["name"], BondScript.PART_FILLS[rg["part"]]],
		]
	var title_a := clampf((t - 0.2) / 0.6, 0.0, 1.0)
	draw_string_outline(font, Vector2(0, size.y * 0.3 - 110), "THE REGARD", HORIZONTAL_ALIGNMENT_CENTER, size.x, 34, 7, Color(0, 0, 0, 0.8 * title_a))
	draw_string(font, Vector2(0, size.y * 0.3 - 110), "THE REGARD", HORIZONTAL_ALIGNMENT_CENTER, size.x, 34, Color(GOLD, title_a))
	var ty := size.y * 0.3 + 190.0
	for i in texts.size():
		var a := clampf((t - 1.4 - i * 0.45) / 0.5, 0.0, 1.0)
		var tc := col.lightened(0.2) if i == 2 else TEXT
		draw_string(font, Vector2(0, ty), texts[i], HORIZONTAL_ALIGNMENT_CENTER, size.x, 17 if i == 2 else 15, Color(tc, a))
		ty += 26.0
	if main.regard_done():
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
		var prompt := _say("Press Space, Enter or click", "Press {a}", "Tap") + " to begin your next climb"
		draw_string(font, Vector2(0, size.y - 40), prompt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(DIM_TEXT, 0.5 + 0.5 * pulse))


# --- choosing a tower --------------------------------------------------------------

const TowersData := preload("res://scripts/towers.gd")


func tower_card_rect(i: int, size: Vector2) -> Rect2:
	var total := TowersData.ORDER.size()
	var rows := 2 if total > 4 else 1
	var n := int(ceil(float(total) / rows))  # cards per row
	var w := minf(260.0, (size.x - 40.0 - 16.0 * (n - 1)) / n)
	var h := 230.0 if rows == 1 else minf(160.0, (size.y - 170.0) / 2.0)
	var x0 := (size.x - (w * n + 16.0 * (n - 1))) / 2.0
	var row := i / n
	var col := i % n
	var top := size.y * 0.5 - (h * rows + 12.0 * (rows - 1)) * 0.5 + 30.0
	return Rect2(Vector2(x0 + col * (w + 16.0), top + row * (h + 12.0)), Vector2(w, h))


## Which tower card is under a point on screen (-1 for none).
func tower_card_at(pos: Vector2) -> int:
	var size := get_viewport_rect().size
	for i in TowersData.ORDER.size():
		if tower_card_rect(i, size).has_point(pos):
			return i
	return -1


func _unhandled_input(event: InputEvent) -> void:
	# The mouse over a card highlights it, like the arrow keys do.
	if main != null and event is InputEventMouseMotion and (main.choosing_tower or main.camp_choosing):
		var at := get_local_mouse_position()
		var over := tower_card_at(at) if main.choosing_tower else camp_card_at(at)
		if over >= 0:
			main.card_focus = over
	if main != null and main.choosing_tower and not main.on_train and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := tower_card_at(get_local_mouse_position())
		if i >= 0:
			main.choose_tower(TowersData.ORDER[i])
	elif main != null and main.camp_choosing and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := camp_card_at(get_local_mouse_position())
		if i >= 0:
			main.choose_camp(i)


func _draw_tower_choice(size: Vector2, font: Font) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.03, 0.88))
	var title := "CHOOSE A TOWER"
	var top_y := tower_card_rect(0, size).position.y
	draw_string_outline(font, Vector2(0, top_y - 46.0), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 32, 6, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(0, top_y - 46.0), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 32, GOLD)
	var sub := "Each tower's monsters and essence shape the marks you'll form."
	draw_string(font, Vector2(0, top_y - 20.0), sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, DIM_TEXT)
	for i in TowersData.ORDER.size():
		var id: String = TowersData.ORDER[i]
		var t: Dictionary = TowersData.TOWERS[id]
		var r := tower_card_rect(i, size)
		var ec := Essence.color(t["essence"])
		var last: bool = id == main.profile.last_tower
		var box := slot_on if last else panel
		draw_style_box(box, r)
		var focused := _card_focused(i)
		if focused:
			_draw_card_focus(r)
		draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 5)), Color(t["torch"], 0.7))
		var x := r.position.x + 14.0
		var y := r.position.y + 34.0
		var narrow := r.size.x < 200.0 or r.size.y < 200.0  # many cards, or a phone
		draw_string(font, Vector2(x, y), t["short"] if narrow else t["name"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28.0, 17, TEXT)
		y += 24.0
		draw_circle(Vector2(x + 6, y - 5), 6.0, ec)
		draw_string(font, Vector2(x + 18, y), "%s essence" % Essence.display(t["essence"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, ec)
		y += 18.0
		draw_multiline_string(font, Vector2(x, y + 4), t["blurb"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28.0, 11 if narrow else 13, 4 if r.size.y < 200.0 else 7, DIM_TEXT)
		var hint := _card_hint(i)
		draw_string(font, Vector2(r.position.x, r.end.y - 14.0), hint, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13, GOLD if last or focused else DIM_TEXT)


# --- hold to pick ----------------------------------------------------------------

## The ring of a mark's spells, around the climber (or the held button on a
## phone). The highlighted one is cast when you let go.
func _draw_spell_ring(p, font: Font) -> void:
	var b = p.bonds.get(p.pick_part)
	if b == null:
		return
	var known: Array = b.spells()
	var c: Vector2 = main.pick_anchor if main.touch_active else p.get_global_transform_with_canvas().origin
	var ring_r := 78.0
	draw_circle(c, ring_r + 34.0, Color(0, 0, 0, 0.45))
	var col: Color = b.color()
	for i in known.size():
		var a := -PI / 2.0 + TAU * float(i) / float(known.size())
		var at := c + Vector2.from_angle(a) * ring_r
		var on: bool = i == p.pick_index
		draw_circle(at, 25.0 if on else 21.0, Color(0.05, 0.04, 0.07, 0.92))
		draw_arc(at, 25.0 if on else 21.0, 0.0, TAU, 28, Color(col, 1.0 if on else 0.45), 3.0 if on else 1.5, true)
		var words: PackedStringArray = known[i]["name"].split(" ")
		for w in words.size():
			draw_string(font, at + Vector2(-30, 4 + (w - (words.size() - 1) / 2.0) * 11.0), words[w], HORIZONTAL_ALIGNMENT_CENTER, 60, 10, Color(col.lightened(0.3), 1.0) if on else DIM_TEXT)
	if p.pick_index >= 0 and p.pick_index < known.size():
		var sp: Dictionary = known[p.pick_index]
		draw_string_outline(font, c + Vector2(-160, ring_r + 54.0), sp["name"], HORIZONTAL_ALIGNMENT_CENTER, 320, 15, 4, Color(0, 0, 0, 0.8))
		draw_string(font, c + Vector2(-160, ring_r + 54.0), sp["name"], HORIZONTAL_ALIGNMENT_CENTER, 320, 15, col.lightened(0.2))
		draw_multiline_string_outline(font, c + Vector2(-170, ring_r + 72.0), sp["desc"], HORIZONTAL_ALIGNMENT_CENTER, 340, 12, 2, 4, Color(0, 0, 0, 0.8))
		draw_multiline_string(font, c + Vector2(-170, ring_r + 72.0), sp["desc"], HORIZONTAL_ALIGNMENT_CENTER, 340, 12, 2, TEXT)


## The ring of belt items, around the climber (or the held Item button on
## a phone). The highlighted one is used when you let go.
func _draw_item_ring(p, font: Font) -> void:
	var have: Array = p.carried()
	if have.is_empty():
		return
	var c: Vector2 = p.get_global_transform_with_canvas().origin
	var ring_r := 78.0
	var view := get_viewport_rect().size
	if main.touch_active:
		# On a phone the ring sits left of the buttons, clear of them and of
		# your thumb; you point by sliding from the Item button.
		c = Vector2(view.x * 0.4, view.y * 0.42)
	c = Vector2(clampf(c.x, ring_r + 40.0, view.x - ring_r - 40.0), clampf(c.y, ring_r + 40.0, view.y - ring_r - 100.0))
	draw_circle(c, ring_r + 34.0, Color(0, 0, 0, 0.6))
	var b := Draw.Batch.new()
	for i in have.size():
		var a := -PI / 2.0 + TAU * float(i) / float(have.size())
		var at := c + Vector2.from_angle(a) * ring_r
		var on: bool = i == p.ring_index
		var col := Items.color(have[i])
		b.dot(at, 25.0 if on else 21.0, Color(0.05, 0.04, 0.07, 0.92))
		b.arc(at, 25.0 if on else 21.0, 0.0, TAU, 28, Color(col, 1.0 if on else 0.45), 3.0 if on else 1.5)
		Items.icon_into(b, have[i], at + Vector2(0, -2), 11.0 if on else 9.5)
	b.flush(self)
	for i in have.size():
		var a := -PI / 2.0 + TAU * float(i) / float(have.size())
		var at := c + Vector2.from_angle(a) * ring_r
		var n := "%d" % p.item_count(have[i])
		draw_string_outline(font, at + Vector2(6, 18), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0, 0, 0, 0.85))
		draw_string(font, at + Vector2(6, 18), n, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, TEXT)
	if p.ring_index >= 0 and p.ring_index < have.size():
		var d: Dictionary = Items.info(have[p.ring_index])
		var col: Color = d["color"]
		draw_string_outline(font, c + Vector2(-160, ring_r + 54.0), d["name"], HORIZONTAL_ALIGNMENT_CENTER, 320, 15, 4, Color(0, 0, 0, 0.8))
		draw_string(font, c + Vector2(-160, ring_r + 54.0), d["name"], HORIZONTAL_ALIGNMENT_CENTER, 320, 15, col.lightened(0.2))
		var line := _sentence(String(d["desc"]))
		draw_multiline_string_outline(font, c + Vector2(-170, ring_r + 72.0), line, HORIZONTAL_ALIGNMENT_CENTER, 340, 12, 2, 4, Color(0, 0, 0, 0.8))
		draw_multiline_string(font, c + Vector2(-170, ring_r + 72.0), line, HORIZONTAL_ALIGNMENT_CENTER, 340, 12, 2, TEXT)


## A Rare (or better) find: a short notice fades in under the floor title.
func _draw_loot_notice(size: Vector2, font: Font) -> void:
	var n: Dictionary = main.loot_notice
	if n.is_empty():
		return
	var a := _fade(float(n["t"]), 3.5)
	var col: Color = n["color"]
	var y := 96.0
	var w := font.get_string_size(n["text"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x + 36.0
	var r := Rect2(Vector2((size.x - w) / 2.0, y - 18.0), Vector2(w, 26.0))
	draw_rect(r, Color(0.03, 0.025, 0.05, 0.7 * a))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2.0)), Color(col, 0.9 * a))
	draw_string_outline(font, Vector2(0, y), n["text"], HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, 4, Color(0, 0, 0, 0.8 * a))
	draw_string(font, Vector2(0, y), n["text"], HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, Color(col.lightened(0.2), a))


## Hunter's Quarry: the last foe you struck is always marked, and an arrow at
## the screen edge points to it when it's out of sight.
func _draw_quarry(p, size: Vector2, font: Font) -> void:
	if not p.has_bond("hunter") or p.quarry == null or not is_instance_valid(p.quarry) or p.quarry.dead:
		return
	var at: Vector2 = p.quarry.get_global_transform_with_canvas().origin
	var col := Color(0.85, 0.63, 0.42)
	var inner := Rect2(Vector2(24, 24), size - Vector2(48, 48))
	if inner.has_point(at):
		var top := at + Vector2(0, -p.quarry.radius * 1.6 - 14.0)
		draw_colored_polygon(PackedVector2Array([top + Vector2(-6, -8), top + Vector2(6, -8), top]), Color(col, 0.9))
	else:
		var center := size / 2.0
		var dir := (at - center).normalized()
		var edge := Vector2(clampf(at.x, inner.position.x, inner.end.x), clampf(at.y, inner.position.y, inner.end.y))
		var side := dir.orthogonal()
		draw_colored_polygon(PackedVector2Array([edge + dir * 10.0, edge - dir * 6.0 + side * 8.0, edge - dir * 6.0 - side * 8.0]), Color(col, 0.9))


# --- bosses ------------------------------------------------------------------------

## A beast's health, as a long bar under the floor counter.
## Rooms floors are bigger than the screen: once the stair opens, an arrow at
## the screen edge points the way to it.
func _draw_stair_arrow(size: Vector2, font: Font) -> void:
	if not main.stair_open or main.climbing or main.player == null:
		return
	var sp: Vector2 = main.get_viewport().get_canvas_transform() * main.stair_pos
	var margin := 40.0
	if Rect2(Vector2.ZERO, size).grow(-margin).has_point(sp):
		return
	var center := size * 0.5
	var d := (sp - center).normalized()
	# Keep it below the floor counter and stair line at the top.
	var top := 104.0
	var at := center + d * minf((size.x * 0.5 - margin) / maxf(absf(d.x), 0.001), ((size.y * 0.5 - margin) if d.y > 0.0 else (size.y * 0.5 - top)) / maxf(absf(d.y), 0.001))
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.006)
	var tip := at + d * 14.0
	draw_colored_polygon(PackedVector2Array([tip, at - d * 8.0 + d.orthogonal() * 10.0, at - d * 8.0 - d.orthogonal() * 10.0]), Color(1.0, 0.85, 0.5, pulse))
	draw_string_outline(font, at - d * 26.0 + Vector2(-20, 4), "stair", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color(0, 0, 0, 0.7))
	draw_string(font, at - d * 26.0 + Vector2(-20, 4), "stair", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1.0, 0.85, 0.5, pulse))


func _draw_boss_bar(size: Vector2, font: Font) -> void:
	for e in main.enemies():
		if not e.is_boss():
			continue
		var w := minf(460.0, size.x - 120.0)
		var r := Rect2(Vector2((size.x - w) / 2.0, 84), Vector2(w, 12))
		var name: String = main.beast_name().to_upper()
		if e.shade:  # the Proving's shadow of the beast
			name = (String(main.proving.TEXT["shadow_bar"]) % main.beast_name()).to_upper()
		draw_string_outline(font, Vector2(0, 78), name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, 4, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(0, 78), name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, GOLD)
		draw_rect(r.grow(2.0), Color(0, 0, 0, 0.8))
		draw_rect(r, Color(0.3, 0.1, 0.08, 0.9))
		draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(e.hp / e.max_hp, 0.0, 1.0), r.size.y)), Color(0.85, 0.3, 0.22))
		draw_line(Vector2(r.position.x + r.size.x * 0.5, r.position.y), Vector2(r.position.x + r.size.x * 0.5, r.end.y), Color(1, 1, 1, 0.35), 1.0)
		return


## A sealed wing's question (wings.gd): its condition, kept or broken, the
## wave and the clock; and a champion's health bar.
func _draw_wing_status(size: Vector2, font: Font) -> void:
	if main.wings == null or main.fade > 0.0 or main.overlay_showing() or main.camp_choosing:
		return
	# Shut in a lock-in room (doors.gd): say so, and how many foes are left.
	var ls: Dictionary = main.door_view.lock_status() if main.door_view != null else {}
	if not ls.is_empty() and not _boss_alive():  # (a beast's shadow has its own bar there)
		var t1: String = main.door_view.LOCK_TEXT["status"]
		var t2: String = main.door_view.LOCK_TEXT["left"] % int(ls["left"])
		draw_string_outline(font, Vector2(0, 84), t1, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, 4, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(0, 84), t1, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, Color(0.9, 0.55, 0.45))
		draw_string_outline(font, Vector2(0, 102), t2, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, 3, Color(0, 0, 0, 0.7))
		draw_string(font, Vector2(0, 102), t2, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, TEXT)
	var st: Dictionary = main.wings.status()
	if st.is_empty():
		return
	var y := 84.0
	var champ = st.get("champ")
	if champ != null:
		var w := minf(360.0, size.x - 140.0)
		var r := Rect2(Vector2((size.x - w) / 2.0, y + 6.0), Vector2(w, 10))
		var name: String = String(main.wings.TEXT["champion"]).to_upper()
		draw_string_outline(font, Vector2(0, y), name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, 4, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(0, y), name, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, GOLD)
		draw_rect(r.grow(2.0), Color(0, 0, 0, 0.8))
		draw_rect(r, Color(0.3, 0.1, 0.08, 0.9))
		draw_rect(Rect2(r.position, Vector2(r.size.x * clampf(champ.hp / champ.max_hp, 0.0, 1.0), r.size.y)), Color(0.95, 0.72, 0.3))
		y += 40.0
	if champ != null and st["line"] == "":
		return
	var col := GOLD if st["ok"] else Color(0.9, 0.42, 0.35)
	var head: String = st["title"] + ("" if st["ok"] else "  ·  broken")
	draw_string_outline(font, Vector2(0, y), head, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, 4, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(0, y), head, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, col)
	if st["line"] != "":
		draw_string_outline(font, Vector2(0, y + 18.0), st["line"], HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, 3, Color(0, 0, 0, 0.7))
		draw_string(font, Vector2(0, y + 18.0), st["line"], HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, TEXT)


## How dark the Regard's or the victory's backdrop is. One that begins while
## the screen is black between floors starts fully dark, so the room doesn't
## flash into view as the black fades out and the backdrop fades in.
func _overlay_shade(o: Dictionary, most: float) -> float:
	if o.get("dark", false):
		return most
	return clampf(float(o["t"]) / 0.8, 0.0, most)


## The climb is complete: the beast has fallen.
func _draw_victory(size: Vector2, font: Font) -> void:
	var v: Dictionary = main.victory
	var t: float = v["t"]
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.03, _overlay_shade(v, 0.94)))
	var a := clampf((t - 0.3) / 0.6, 0.0, 1.0)
	var top := size.y * 0.32
	# (A recall scroll read: you left the tower, the climb not won.)
	var recall: bool = v.get("recall", false)
	var head: String = Items.RECALL["title"] if recall else "CLIMB COMPLETE"
	var sub: String = Items.RECALL["sub"] % String(v["beast"]).capitalize() if recall else "%s yields." % String(v["beast"]).capitalize()
	draw_string_outline(font, Vector2(0, top), head, HORIZONTAL_ALIGNMENT_CENTER, size.x, 40, 7, Color(0, 0, 0, 0.8 * a))
	draw_string(font, Vector2(0, top), head, HORIZONTAL_ALIGNMENT_CENTER, size.x, 40, Color(GOLD, a))
	draw_string(font, Vector2(0, top + 34), sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, 18, Color(TEXT, a))
	var ly := top + 70.0
	for line in v["lines"]:
		draw_string(font, Vector2(0, ly), line, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(DIM_TEXT, a))
		ly += 22.0
	if main.overlay_done():
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
		var prompt := _say("Press Space, Enter or click", "Press {a}", "Tap") + " to climb again"
		draw_string(font, Vector2(0, size.y - 40), prompt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(DIM_TEXT, 0.5 + 0.5 * pulse))


# --- items and camps ---------------------------------------------------------------

static func _sentence(t: String) -> String:
	return t.left(1).to_upper() + t.substr(1) + "."


## Cards to a row on the card screens: one row of up to five, else two rows
## (the heirloom choice can offer a card for every slot).
func camp_per_row() -> int:
	var n: int = main.camp.get("choices", []).size()
	return n if n <= 5 else int(ceil(n / 2.0))


func camp_card_rect(i: int, size: Vector2) -> Rect2:
	var n: int = main.camp["choices"].size()
	var per := maxi(camp_per_row(), 1)
	var rows := int(ceil(float(n) / per))
	var gap := 16.0 if rows == 1 else 10.0
	var w := minf(230.0, (size.x - 40.0 - gap * (per - 1)) / per)
	var h := minf(230.0, size.y * 0.5) if rows == 1 else minf(180.0, (size.y - 170.0 - gap) / 2.0)
	var row := i / per
	var in_row := mini(per, n - row * per)
	var x0 := (size.x - (w * in_row + gap * (in_row - 1))) / 2.0
	var top := size.y * 0.5 - (h * rows + gap * (rows - 1)) * 0.5 + 40.0
	return Rect2(Vector2(x0 + (i % per) * (w + gap), top + row * (h + gap)), Vector2(w, h))


## Which camp card is under a point on screen (-1 for none).
func camp_card_at(pos: Vector2) -> int:
	if not main.camp_choosing:
		return -1
	var size := get_viewport_rect().size
	for i in main.camp["choices"].size():
		if camp_card_rect(i, size).has_point(pos):
			return i
	return -1


## A camp: pick one of the cards (like choosing a tower).
func _draw_camp_choice(size: Vector2, font: Font) -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.03, 0.72))
	var rune: bool = main.camp["stage"] == "rune"
	var top_y := camp_card_rect(0, size).position.y
	var title: String = Items.CAMP["rune_title"] if rune else Items.CAMP["choose"]
	if main.camp["stage"] == "heirloom":
		title = Gear.HEIRLOOM_TEXT["title"]
	elif main.camp["stage"] in ["vault", "belt"]:
		title = main.camp.get("title", "")
	draw_string_outline(font, Vector2(0, top_y - 62.0), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, 6, Color(0, 0, 0, 0.8))
	draw_string(font, Vector2(0, top_y - 62.0), title, HORIZONTAL_ALIGNMENT_CENTER, size.x, 30, GOLD)
	var sub: Array = main.camp.get("lines", [])
	var sy := top_y - 38.0
	for line in sub.slice(0, 2):
		draw_string(font, Vector2(0, sy), line, HORIZONTAL_ALIGNMENT_CENTER, size.x, 13, DIM_TEXT)
		sy += 17.0
	var p = main.player
	for i in main.camp["choices"].size():
		var card: Dictionary = main.camp_card(i)
		var r := camp_card_rect(i, size)
		var col: Color = card["color"]
		var rim: Color = card.get("rim", col)  # gear: its rarity's colour
		draw_style_box(panel, r)
		if _card_focused(i):
			_draw_card_focus(r)
		draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 5)), Color(rim, 0.85))
		if card.has("rim") and rim != Gear.RARITIES["common"]["color"]:
			draw_rect(r.grow(-1.0), Color(rim, 0.55), false, 1.5)
		var small := r.size.y < 200.0  # two rows of smaller cards
		var ir := 15.0 if small else 22.0
		var ic := Vector2(r.get_center().x, r.position.y + (28.0 if small else 48.0))
		draw_circle(ic, ir * 1.27, Color(col, 0.1))
		if card.has("gear"):
			Gear.draw_icon(self, card["gear"], ic, ir, col)
		elif card.has("crystal"):
			Items.draw_crystal_icon(self, col, ic, ir)
		elif card["item"] != "":
			Items.draw_icon(self, card["item"], ic, ir)
		else:
			Items.draw_rune_icon(self, col, ic, ir)
		var y := r.position.y + (58.0 if small else 100.0)
		draw_string(font, Vector2(r.position.x + 6, y), card["name"], HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 12.0, 15 if r.size.x > 180 else 13, (rim if card.has("rim") else col).lightened(0.2))
		# As many lines of its text as fit above the note.
		var dy := y + (15.0 if small else 20.0)
		var lines := 4 if not small else clampi(int((r.end.y - 46.0 - dy) / 16.0) + 1, 1, 4)
		draw_multiline_string(font, Vector2(r.position.x + 8, dy), card["desc"], HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 16.0, 11 if small else 12, lines, TEXT)
		if card.has("note"):
			draw_string(font, Vector2(r.position.x, r.end.y - 34.0), card["note"], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 11, DIM_TEXT)
		if card["item"] != "" and p != null and not card.has("belt"):
			var n: int = p.item_count(card["item"])
			var have := "carrying %d of %d" % [n, p.max_stack(card["item"])]
			var full: bool = p.item_room(card["item"]) != ""
			if p.item_room(card["item"]) == "belt":
				have = "belt full: left at your feet"
			draw_string(font, Vector2(r.position.x, r.end.y - 34.0), have, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 11, Color(1.0, 0.5, 0.4) if full else DIM_TEXT)
		draw_string(font, Vector2(r.position.x, r.end.y - 14.0), _card_hint(i), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13, GOLD)


# --- prompts for the device in use ---------------------------------------------------

## The words for a prompt: keys, a controller ({a}, {start}... become button
## names) or touch, whichever was used last.
func _say(keys: String, pad: String, tap: String) -> String:
	if main.touch_active:
		return tap
	if main.pad_active:
		return Controls.pad_text(pad, main.pad_ps)
	return keys


## The highlighted card (keys and controller choose with left/right).
func _card_focused(i: int) -> bool:
	return not main.touch_active and i == main.card_focus


func _draw_card_focus(r: Rect2) -> void:
	draw_rect(r.grow(3.0), Color(GOLD, 0.95), false, 2.0)


## Under a card: how to take it.
func _card_hint(i: int) -> String:
	if main.touch_active:
		return "Tap"
	if main.pad_active:
		return Controls.pad_text("Press {a}", main.pad_ps) if _card_focused(i) else ""
	if i >= main.CARD_KEYS:
		return "Press Enter" if _card_focused(i) else ""
	return "Press %d%s" % [i + 1, " or Enter" if _card_focused(i) else ""]
