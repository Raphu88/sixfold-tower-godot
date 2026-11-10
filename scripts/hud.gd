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
const Lost := preload("res://scripts/lost.gd")
const Secret := preload("res://scripts/secret.gd")
const Nav := preload("res://scripts/nav.gd")
## Where each part sits (Arrange mode moves them): every block below is drawn
## where it always was, under its element's transform (layout.gd).
const Layout := preload("res://scripts/layout.gd")
## The rings (spells, items; secret_tools.gd's tools too) draw over the touch
## buttons; on a phone they keep clear of the thumb (this big a circle) and
## leave room under them for the chosen one's name and words.
const RING_Z := 60
const RING_THUMB := 46.0
const RING_TEXT := 90.0

static var GOLD: Color:  # (UI.GOLD, read each time: the Data editor can change it)
	get: return UI.GOLD
static var TEXT: Color:  # (UI.TEXT, read each time: the Data editor can change it)
	get: return UI.TEXT
static var DIM_TEXT: Color:  # (UI.DIM, read each time: the Data editor can change it)
	get: return UI.DIM

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
## Poison tints the health bar this way.
const POISONED := Color(0.5, 0.78, 0.25)

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
var tip_box: StyleBox
var card_box: StyleBox  # the big cards (towers, camps, the gear at your feet): ui.gd card
var card_box_on: StyleBox
var core: Node2D  # the always-there part, drawn under this node
var rings: Node2D  # the spell and item rings, drawn over the touch buttons
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
	card_box = UI.card()
	card_box_on = UI.card(UI.GOLD)
	# The tooltip: a small ornate card, a gilt hairline inside its edge.
	var tb := UI.Ornate.new()
	tb.top = Color(0.13, 0.115, 0.17, 0.98)
	tb.bottom = Color(0.06, 0.052, 0.082, 0.98)
	tb.edge = Color(UI.GILT, 0.5)
	tb.inner = Color(UI.GILT, 0.14)
	tb.glow = Color(UI.GILT, 0.05)
	tb.radius = 6.0
	tb.shadow = 6.0
	tb.highlight = true
	tip_box = tb
	# The card screens' cards: gilt flourishes at their corners, a hairline inside.
	for cb in [card_box, card_box_on]:
		cb.inner = Color(UI.GILT, 0.1)
		cb.corners = Color(UI.GILT, 0.5)
	# The core goes just under this node, in the same layer.
	core = Node2D.new()
	core.name = "HudCore"
	core.draw.connect(_draw_core)
	add_sibling.call_deferred(core)
	(func(): if core.get_parent() != null: get_parent().move_child(core, get_index())).call_deferred()
	# The rings go over everything in this layer, the touch buttons included,
	# so no button hides a spoke.
	rings = Node2D.new()
	rings.name = "HudRings"
	rings.z_index = RING_Z
	rings.draw.connect(_draw_rings)
	add_child(rings)


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
	redraw_t -= Nav.real_delta(delta) if Engine.time_scale == 0.0 else delta  # (a ring stops the game's time: real time then)
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
	if main.flow_shown():
		held += main.run_flow
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
	var s := [true, hud_scale, get_viewport_rect().size, Layout.version, main.touch_active, main.pad_active, main.pad_ps,
		int(ceil(p.hp)), int(round(p.max_health())), p.max_hp, int(p.sta), p.max_sta, p.poison_t > 0.0,
		snappedf(hp_trail, 0.004), snappedf(sta_trail, 0.01), int(ceil(p.barrier_hp)),
		p.weapon, snappedf(p.reload_t, 0.05) if p.wkind() == "crossbow" else 0.0,
		p.selected_item(), p.item_count(p.selected_item()) if p.selected_item() != "" else 0,
		main.profile.path, main.profile.flow_step(), int(main.profile.flow),
		int(p.vessel.get("amount", 0.0)) if p.item_count("vessel") > 0 else -1]  # (the vessel's gauge)
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
		or not main.regard.is_empty() or not main.victory.is_empty() or main.choosing_tower or main.camp_choosing or (p.dead and not main.first_climb) \
		or p.pick_open or p.ring_open or not main.loot_notice.is_empty() or (main.stair_open and not main.climbing) or _tip_over >= 0 or _boss_alive() \
		or (p.has_bond("hunter") and p.quarry != null) or (main.wings != null and main.wings.challenge_live()) \
		or (main.door_view != null and not main.door_view.lock_status().is_empty())


## What this layer shows that doesn't move: it's redrawn when this changes.
func _top_signature() -> Array:
	var p = main.player
	return [show_help, main.pad_active, main.pad_ps, main.touch_active, hud_scale, get_viewport_rect().size, Layout.version,
		main.gear_here.get("id", ""), p.gear_signature() if p != null else [], p != null and p.dead,
		main.title_showing(), main.menu_open(), main.overlay_showing(), show_perf, main.fall_note.size(), main.pay_line]


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
	var view := hud_view()
	var unit := Transform2D(0.0, Vector2(hs, hs), 0.0, Vector2.ZERO)
	var mono := UI.font("mono")  # (numbers that change in place: tabular figures)
	# Health and stamina: gilt-framed gauges, the health number on its bar
	# (poison turns its fill sickly green).
	var bx := Layout.xform("hud.bars", view)
	var b := Draw.Batch.new()
	var hp_k: float = p.hp / p.max_hp
	var hp_col := UI.HEALTH.lerp(POISONED, 0.6) if p.poison_t > 0.0 else UI.HEALTH
	UI.gauge_into(b, Rect2(BAR_X, BAR_Y, BAR_W, 12), hp_k, hp_col, hp_trail)
	UI.gauge_into(b, Rect2(BAR_X, BAR_Y + 18.0, BAR_W * p.max_sta / 100.0, 6), p.sta / p.max_sta, UI.STAMINA, sta_trail, Color(0.95, 0.95, 0.7, 0.7), 0)
	if p.barrier_hp > 0.0:
		# The Warden's barrier: a band of gilded glass over the health bar.
		var bw: float = BAR_W * clampf(p.barrier_hp / p.max_hp, 0.0, 1.0)
		UI.vgrad_into(b, UI.chamfer(Rect2(BAR_X, BAR_Y - 1.0, bw, 6.0), 2.0), Color(1.0, 0.93, 0.62, 0.95), Color(0.85, 0.62, 0.25, 0.75))
		b.rect(Rect2(BAR_X + 2.0, BAR_Y + 4.0, maxf(bw - 4.0, 0.0), 1.0), Color(1.0, 0.97, 0.8, 0.8))
	if p.max_health() < p.max_hp:
		# A burned heart caps your health: the lost part shows scorched (the
		# Proving's wound: bruised violet), hatched like an engraving.
		var cap_x: float = BAR_X + BAR_W * p.max_health() / p.max_hp
		UI.hatch_into(b, Rect2(Vector2(cap_x, BAR_Y), Vector2(BAR_X + BAR_W - cap_x, 12)), Color(0.6, 0.45, 0.95, 0.6) if p.wound > 0.0 else Color(1.0, 0.4, 0.22, 0.55))
	if p.poison_t > 0.0:  # a drop of poison at the bar's start
		UI.diamond_into(b, Vector2(BAR_X + BAR_W - 9.0, BAR_Y + 6.0), 4.6, UI.OUTLINE, 0.8)
		UI.diamond_into(b, Vector2(BAR_X + BAR_W - 9.0, BAR_Y + 6.0), 3.4, POISONED.lightened(0.2), 0.75)
	var bars_rect := Rect2(BAR_X - 4, BAR_Y - 4, BAR_W + 8, 32)
	c.draw_set_transform_matrix(unit * bx)
	b.flush(c)
	var hp_text := "%d / %d" % [int(ceil(p.hp)), int(round(p.max_health()))]
	c.draw_string_outline(mono, Vector2(BAR_X + 6, BAR_Y + 10.5), hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, 3, Color(0, 0, 0, 0.85))
	c.draw_string(mono, Vector2(BAR_X + 6, BAR_Y + 10.5), hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 0.95, 0.92))
	var wound_text: String = main.proving.wound_text() if main.proving != null else ""
	if wound_text != "":  # the Proving's lingering wound, small at the bar's end
		var tag: String = main.proving.TEXT["wound_tag"]
		c.draw_string_outline(font, Vector2(BAR_X + BAR_W - 56, BAR_Y + 10), tag, HORIZONTAL_ALIGNMENT_RIGHT, 52, 10, 3, Color(0, 0, 0, 0.85))
		c.draw_string(font, Vector2(BAR_X + BAR_W - 56, BAR_Y + 10), tag, HORIZONTAL_ALIGNMENT_RIGHT, 52, 10, Color(0.82, 0.74, 1.0))
	tips.append([bx * bars_rect, "Health %s" % hp_text, ["Stamina %d / %d: rolls, strikes and parries use it" % [int(p.sta), int(p.max_sta)]] + ([wound_text] if wound_text != "" else [])])
	# Your path's gem (secret.gd), once its banked flow reaches the first step,
	# and the vessel you carry, and how full (vessel.gd).
	var gx := Layout.xform("hud.gem", view)
	var flow_rect := Rect2()
	if main.flow_shown() or p.item_count("vessel") > 0:
		var gb := Draw.Batch.new()
		var t0 := tips.size()
		if main.flow_shown():
			flow_rect = _flow_gem_into(gb, Vector2(BAR_X + BAR_W + 22.0, BAR_Y + 8.0))
		if p.item_count("vessel") > 0:
			load("res://scripts/vessel.gd").hud_into(gb, p, Vector2(BAR_X + BAR_W + (52.0 if flow_rect.size.x > 0.0 else 22.0), BAR_Y + 8.0), tips)
		for i in range(t0, tips.size()):
			tips[i][0] = gx * Rect2(tips[i][0])
		c.draw_set_transform_matrix(unit * gx)
		gb.flush(c)
		if flow_rect.size.x > 0.0:
			tips.append([gx * flow_rect, Secret.TEXT["hud_tip"] % [Secret.display(main.profile.path), main.profile.flow_step()], _flow_tip_lines()])
	# The weapon in hand and the quick item: two small slots.
	var wx := Layout.xform("hud.weapon", view)
	var wb := Draw.Batch.new()
	var wr := Rect2(BAR_X, ROW_Y, SLOT, SLOT)
	var slot_i: int = p.slots().find(p.weapon)
	UI.slot_into(wb, wr, true, Gear.color(p.weapon))
	Gear.icon_into(wb, p.weapon_rec(), wr.get_center(), 10.5, Gear.color(p.weapon))  # (cracked when badly worn)
	if p.reload_t > 0.0 and p.wkind() == "crossbow":
		var rk: float = clampf(p.reload_t / float(p.wdata()["reload"]), 0.0, 1.0)
		wb.rect(Rect2(wr.position + Vector2(2, 2), Vector2(SLOT - 4, (SLOT - 4) * rk)), Color(0, 0, 0, 0.45))
	tips.append([wx * wr, Gear.display(p.weapon), _gear_tip(p.weapon, maxi(slot_i, 0))])
	c.draw_set_transform_matrix(unit * wx)
	wb.flush(c)
	if slot_i >= 0 and not main.touch_active:
		c.draw_string_outline(mono, wr.position + Vector2(3, 11), str(slot_i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, 3, Color(0, 0, 0, 0.8))
		c.draw_string(mono, wr.position + Vector2(3, 11), str(slot_i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 11, GOLD)
	var x := wr.end.x + 6.0
	var sel: String = p.selected_item()
	if sel != "":
		var ix := Layout.xform("hud.item", view)
		var ib := Draw.Batch.new()
		var ir := Rect2(x, ROW_Y, SLOT, SLOT)
		UI.slot_into(ib, ir, false, Color(Items.color(sel), 0.6))
		Items.icon_into(ib, sel, ir.get_center() + Vector2(0, -1), 10.5)
		# Its count on a small gilt-ringed coin at the corner.
		ib.dot(ir.end - Vector2(3, 3), 7.2, UI.OUTLINE)
		ib.dot(ir.end - Vector2(3, 3), 6.0, UI.STONE)
		UI.ring_into(ib, ir.end - Vector2(3, 3), 6.0, 1.0, Color(UI.GILT, 0.8))
		tips.append([ix * ir, Items.ITEMS[sel]["name"], [_sentence(Items.ITEMS[sel]["desc"]),
			"Carrying %d  ·  %s to use it%s" % [p.item_count(sel), _use_key(), "" if p.carried().size() < 2 else "  ·  %s picks another" % _next_key()]]])
		c.draw_set_transform_matrix(unit * ix)
		ib.flush(c)
		c.draw_string(mono, ir.end + Vector2(-9, 0.5), str(p.item_count(sel)), HORIZONTAL_ALIGNMENT_CENTER, 12, 10, UI.GILT_HI)
		if not main.touch_active:
			UI.draw_key(c, ir.position + Vector2(-3, -5), _use_key(), 8)
	# Marks: a medallion each, its ring filling with essence; bright once it
	# can cast. (They follow the weapon when there's no quick item, unless
	# arranged.)
	if sel != "" or Layout.moved("hud.marks"):
		x += SLOT + 6.0
	var mkx := Layout.xform("hud.marks", view)
	var mb := Draw.Batch.new()
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
		UI.seal_into(mb, mc, MARK_R, col if ready else col.darkened(0.45), bd.data()["affinity"], bd.essence / bd.capacity(), ready, bd.faint, bd.burned)
		if bd.has_method("hud_into"):
			bd.hud_into(mb, mc, MARK_R)  # (an Unbound's technique: its part's strain)
		var key := _cast_key(part)
		var mr := mkx * Rect2(mc - Vector2(MARK_R + 3, MARK_R + 3), Vector2(MARK_R * 2 + 6, MARK_R * 2 + 6))
		if bd.has_method("tip_lines"):  # (an Unbound's technique: technique_bond.gd)
			tips.append([mr, bd.display_name(), bd.tip_lines(_cast_key(part), main.touch_active)])
			mx += MARK_R * 2.0 + 8.0
			continue
		tips.append([mr, "%s  (%s)" % [bd.display_name(), BondScript.PART_NAMES[part]],
			["%s: %s" % [bd.spell_name(), bd.spell_desc()],
			"Essence %d / %d  ·  costs %d" % [int(bd.essence), int(bd.capacity()), int(round(bd.cost()))],
			("%s burned: overdraw again and it tears (costs health)" % BondScript.PART_NAMES[part]) if bd.burned else ("Press %s to cast%s" % [key, ", hold it to pick a spell" if bd.spells().size() > 1 else ""] if not main.touch_active else "Its button is on the right"),
			"Tab: the climber screen has every spell"]])
		mx += MARK_R * 2.0 + 8.0
	c.draw_set_transform_matrix(unit * mkx)
	mb.flush(c)
	if not main.touch_active:
		mx = x + MARK_R + 4.0
		for part in marks:
			var bd = p.bonds[part]
			var ready: bool = bd.essence >= bd.cost()
			UI.draw_key(c, Vector2(mx + 3.0, my + 3.0), _cast_key(part), 8, bd.color().lightened(0.2) if ready else DIM_TEXT)
			mx += MARK_R * 2.0 + 8.0
	c.draw_set_transform_matrix(Transform2D.IDENTITY)


## The screen in HUD units (the HUD size setting divides it): what the HUD's
## corner elements are laid out on.
func hud_view() -> Vector2:
	return get_viewport_rect().size / hud_scale


## Your path's gem by the health bar: a glowing gem in its colour, four pips
## under it for the flow's steps. Returns the rect it covers (for its tooltip).
func _flow_gem_into(b, c: Vector2) -> Rect2:
	var path: String = main.profile.path
	var st: int = main.profile.flow_step()
	var col := Secret.color(path)
	UI.glow_into(b, c, 16.0, col, 1.1 + 0.15 * st)
	# Set in a gilt hexagonal bezel, like a jewel in a mount.
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 6:
		var d := Vector2.from_angle(-PI / 2.0 + TAU * i / 6.0)
		outer.append(c + d * 10.6)
		inner.append(c + d * 8.8)
	var back := PackedVector2Array()
	for v in outer:
		back.append(c + (v - c) * 1.18)
	UI.vgrad_into(b, back, Color(UI.OUTLINE, 0.9), Color(UI.OUTLINE, 0.9))
	UI.frame_into(b, outer, inner, UI.GILT_HI, UI.GILT_DEEP.lerp(UI.GILT, 0.35))
	UI.vgrad_into(b, inner, UI.STONE_2, UI.VOID)
	UI.gem_into(b, c, 7.0, col)
	# Its steps: four small gems on a gilt bar under it, lit as they're reached.
	b.rect(Rect2(c + Vector2(-11.5, 13.2), Vector2(23, 3.6)), Color(UI.OUTLINE, 0.9))
	b.rect(Rect2(c + Vector2(-10.5, 14.4), Vector2(21, 1.2)), Color(UI.GILT, 0.55))
	for i in Secret.STEPS.size():
		var at := c + Vector2(-8.25 + 5.5 * i, 15.0)
		UI.diamond_into(b, at, 3.0, UI.OUTLINE)
		UI.diamond_into(b, at, 2.1, Secret.KINDS[path]["light"] if i < st else Color(col.darkened(0.5), 0.9))
	return Rect2(c - Vector2(12, 12), Vector2(24, 30))


func _flow_tip_lines() -> Array:
	var prof = main.profile
	var st: int = prof.flow_step()
	var out: Array = []
	for i in st:
		out.append("%d  %s" % [i + 1, Secret.STEP_TEXT[prof.path][i]])
	var need: float = Secret.next_need(prof.flow)
	out.append(Secret.TEXT["next"] % [int(prof.flow), int(ceil(need - prof.flow)), st + 1] if need > 0.0 else Secret.TEXT["full"] % int(prof.flow))
	return out


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
	var unit := Transform2D(0.0, Vector2(hs, hs), 0.0, Vector2.ZERO)
	draw_set_transform_matrix(unit)
	# The weapon row pops up under the weapon; the essence counter goes under
	# it (unless either is arranged elsewhere).
	var y := ROW_Y + SLOT + 8.0
	var own_place := Layout.moved("hud.weapon") or Layout.moved("hud.essence")
	if swap_t > 0.0:
		draw_set_transform_matrix(unit * Layout.xform("hud.weapon", size))
		var sh := _draw_swap(p, Vector2(BAR_X, y), font, _fade(swap_t, SWAP_SHOW)) + 6.0
		if not own_place:
			y += sh
	if essence_t > 0.0:
		draw_set_transform_matrix(unit * Layout.xform("hud.essence", size))
		_draw_essence(Vector2(BAR_X, y), font, _fade(essence_t, ESSENCE_SHOW))

	# Controls, top right.
	draw_set_transform_matrix(unit * Layout.xform("hud.hints", size))
	if main.touch_active:
		pass  # the touch buttons are labelled; no keyboard help needed
	elif show_help:
		_draw_help(size, font)
	elif hints_t > 0.0:
		_draw_screen_hints(size, font, _fade(hints_t, HINTS_SHOW))
	draw_set_transform_matrix(unit)
	if not main.gear_here.is_empty() and not main.camp_choosing and main.fade <= 0.0 and not main.overlay_showing() and not main.menu_open():
		_draw_gear_prompt(p, main.gear_here["rec"], size, font)
	if show_perf:
		_draw_perf(size, font)
	_draw_tip(font)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	size = real_size

	# The floor's title on arrival, top centre, fading out.
	draw_set_transform_matrix(Layout.xform("hud.floor", size))
	if floor_t > 0.0 or stair_t > 0.0:
		var fa := _fade(maxf(floor_t, stair_t), FLOOR_SHOW)
		var floor_text: String = main._floor_title()
		# A soft band between gilt rules behind it, rules flanking the title.
		var tw := UI.font("display").get_string_size(UI.title_case(floor_text), HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		var fb := Draw.Batch.new()
		var bw := minf(size.x, maxf(tw + 260.0, 420.0))
		UI.band_into(fb, Rect2((size.x - bw) * 0.5, 4.0, bw, 52.0), fa * 0.8, UI.GILT, 0.5)
		UI.flank_into(fb, size.x * 0.5, 21.0, tw * 0.5 + 12.0, 64.0, Color(UI.GILT, 0.75 * fa))
		fb.flush(self)
		draw_string_outline(UI.font("display"), Vector2(0, 30), UI.title_case(floor_text), HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, 5, Color(0, 0, 0, 0.8 * fa))
		draw_string(UI.font("display"), Vector2(0, 30), UI.title_case(floor_text), HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, Color(GOLD, fa))
		var sub_text := "%s  ·  best %d" % [main.tower_data()["short"], main.best_floor]
		draw_string_outline(font, Vector2(0, 48), sub_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, 3, Color(0, 0, 0, 0.6 * fa))
		draw_string(font, Vector2(0, 48), sub_text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 14, Color(DIM_TEXT, fa))
	if stair_t > 0.0 and main.stair_open and not main.climbing:
		var sa := _fade(stair_t, STAIR_SHOW)
		var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.005)
		var left: int = main.enemies().size()
		var stair_text := "The stair is open"
		if left > 0:
			stair_text += "  ·  %d %s left" % [left, "foe" if left == 1 else "foes"]
		var sw := UI.font("display").get_string_size(stair_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x + 44.0
		var sb := Draw.Batch.new()
		UI.cartouche_into(sb, Rect2((size.x - sw) * 0.5, 53.0, sw, 23.0), Color(UI.GILT, 0.55 + 0.3 * pulse), sa)
		sb.flush(self)
		UI.draw_label(self, Vector2(0, 69), stair_text, 19, Color(1.0, 0.88, 0.6, pulse * sa), HORIZONTAL_ALIGNMENT_CENTER, size.x, 4, Color(0, 0, 0, 0.7 * sa))

	# A new floor: its number and what changed, fading out.
	draw_set_transform_matrix(Layout.xform("hud.banner", size))
	if not main.banner.is_empty():
		var bn: Dictionary = main.banner
		var a: float = clampf(bn["t"] / 0.6, 0.0, 1.0)
		var top := size.y * 0.3
		# A soft band between gilt rules, fading to both sides.
		var bb := Draw.Batch.new()
		var bw2 := minf(size.x, 820.0)
		UI.band_into(bb, Rect2((size.x - bw2) * 0.5, top - 46.0, bw2, 62.0 + 22.0 * bn["lines"].size()), a, UI.GILT, 0.62)
		bb.flush(self)
		draw_string_outline(UI.font("display"), Vector2(0, top), UI.title_case(bn["title"]), HORIZONTAL_ALIGNMENT_CENTER, size.x, 46, 7, Color(0, 0, 0, 0.8 * a))
		draw_string(UI.font("display"), Vector2(0, top), UI.title_case(bn["title"]), HORIZONTAL_ALIGNMENT_CENTER, size.x, 46, Color(GOLD, a))
		var ly := top + 30.0
		# Words written in the world (a room's rule, a door's ask: the banner's
		# "inscribed", true or its first so many lines) in the fine italic of
		# inscriptions; anything else as plain text.
		var ins = bn.get("inscribed", 0)
		var ins_n: int = (99 if ins else 0) if ins is bool else int(ins)
		for li in bn["lines"].size():
			var line: String = bn["lines"][li]
			var lf: Font = UI.font("inscription") if li < ins_n else font
			var ls := 20 if li < ins_n else 17
			draw_string_outline(lf, Vector2(0, ly), line, HORIZONTAL_ALIGNMENT_CENTER, size.x, ls, 4, Color(0, 0, 0, 0.8 * a))
			draw_string(lf, Vector2(0, ly), line, HORIZONTAL_ALIGNMENT_CENTER, size.x, ls, Color(TEXT, a))
			ly += 23.0
	draw_set_transform_matrix(Transform2D.IDENTITY)

	# Messages: a banner across the middle.
	var msg := ""
	var sub := ""
	if p.dead and not main.first_climb:
		# Back to the train in a moment, or at once (main.gd FALL_WAIT).
		msg = Lost.TEXT["fell"] % main.floor_num
		var left := maxi(1, ceili(main.FALL_WAIT - maxf(main.fall_t, 0.0)))
		var now: Array = Lost.TEXT["now"]
		sub = (Lost.TEXT["back"] % [main.best_floor, left]) + "  ·  " + _say(now[0], now[1], now[2])
	# What the fall took (main.fall_note, lost.gd), under the banner's words.
	var note: Array = main.fall_note.duplicate() if p.dead and not main.first_climb else []
	var paid_at := -1  # (the outfitter's pay for the climb, in gold, last)
	if p.dead and not main.first_climb and main.pay_line != "":
		paid_at = note.size()
		note.append(main.pay_line)
	var note_w := minf(size.x - 32.0, 760.0)
	var note_h := 0.0
	for line in note:
		note_h += font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_CENTER, note_w, 17).y + 4.0
	if msg != "":
		var band := Rect2(0, size.y / 2.0 - 70.0, size.x, 90.0 + (note_h + 8.0 if note_h > 0.0 else 0.0))
		var db := Draw.Batch.new()
		db.rect(band, Color(UI.VOID, 0.3))
		UI.band_into(db, band, 1.0, UI.BLOOD if p.dead else UI.GILT, 0.7)
		db.flush(self)
		var col := Color(0.9, 0.3, 0.25) if p.dead else GOLD
		draw_string_outline(UI.font("display"), Vector2(0, band.position.y + 48), UI.title_case(msg), HORIZONTAL_ALIGNMENT_CENTER, size.x, 40, 6, Color(0, 0, 0, 0.8))
		draw_string(UI.font("display"), Vector2(0, band.position.y + 48), UI.title_case(msg), HORIZONTAL_ALIGNMENT_CENTER, size.x, 40, col)
		draw_string(font, Vector2(0, band.position.y + 74), sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, 17, TEXT)
		var ny := band.position.y + 100.0
		for i in note.size():
			var col_n := GOLD if i == paid_at else (Color(0.95, 0.72, 0.62) if i == 0 else Color(TEXT, 0.75))
			draw_multiline_string(font, Vector2((size.x - note_w) / 2.0, ny), note[i], HORIZONTAL_ALIGNMENT_CENTER, note_w, 17, -1, col_n)
			ny += font.get_multiline_string_size(note[i], HORIZONTAL_ALIGNMENT_CENTER, note_w, 17).y + 4.0

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
	rings.queue_redraw()  # (the rings: _draw_rings, over the touch buttons)
	_draw_loot_notice(size, font)


## Swapping weapons: the three slots for a moment, the one in hand lit and named.
## Returns its height.
func _draw_swap(p, pos: Vector2, font: Font, a: float) -> float:
	var have: Array = p.slots()
	var r := Rect2(pos, Vector2(16.0 + 40.0 * have.size(), 62))
	var b := Draw.Batch.new()
	UI.plate_into(b, r, a)
	for i in have.size():
		var id: String = have[i]
		var c := r.position + Vector2(28.0 + 40.0 * i, 22)
		var on: bool = id == p.weapon and id != ""
		UI.slot_into(b, Rect2(c - Vector2(14, 14), Vector2(28, 28)), on, Gear.color(id) if on else Color(0, 0, 0, 0), a)
		if id != "":
			Gear.icon_into(b, id, c, 10.0, Color(Gear.color(id), (1.0 if on else 0.45) * a))
		else:
			b.arc(c, 9.0, 0.0, TAU, 20, Color(UI.FAINT, 0.6 * a), 1.2)
	b.flush(self)
	for i in have.size():
		var c := r.position + Vector2(28.0 + 40.0 * i, 22)
		var on: bool = have[i] == p.weapon and have[i] != ""
		if not main.touch_active:
			draw_string(UI.font("mono"), c + Vector2(-13, -3), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(UI.GILT_HI if on else DIM_TEXT, a))
	UI.draw_label(self, Vector2(r.position.x, r.end.y - 7.0), Gear.display(p.weapon), 16, Color(TEXT, a), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
	return r.size.y


## Essence gathered since the last stair (lost if you fall before it): gems and counts.
func _draw_essence(pos: Vector2, font: Font, a: float) -> void:
	var held: Array = Essence.KINDS.keys().filter(func(k): return main.run_essence.get(k, 0.0) > 0.0)
	# Your path's unbanked flow leads, once its gem shows (secret.gd).
	var flow: bool = main.flow_shown() and main.run_flow >= 0.5
	if flow:
		held.push_front(main.profile.path)
	if held.is_empty():
		return
	var pill := Rect2(pos, Vector2(16.0 + 44.0 * held.size() + 62.0, 22))
	var gems := Draw.Batch.new()
	UI.plate_into(gems, pill, a)
	for gi in held.size():
		var col := Secret.color(held[gi]) if Secret.is_kind(held[gi]) else Essence.color(held[gi])
		if Secret.is_kind(held[gi]):
			UI.glow_into(gems, pos + Vector2(14 + 44.0 * gi, 11), 10.0, col, a)
		UI.gem_into(gems, pos + Vector2(14 + 44.0 * gi, 11), 5.0, Color(col, a))
	gems.flush(self)
	var ex := pos.x + 8.0
	for kind in held:
		var amount: float = main.run_flow if Secret.is_kind(kind) else main.run_essence[kind]
		draw_string(UI.font("mono"), Vector2(ex + 14, pos.y + 16), str(int(amount)), HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(Secret.KINDS[kind]["light"] if Secret.is_kind(kind) else TEXT, a))
		ex += 44.0
	UI.draw_eyebrow(self, Vector2(ex + 2, pos.y + 15), "unbanked", Color(DIM_TEXT, a), 12)


## The keyboard (or controller) controls, top right (H, or the Controls setting).
func _draw_help(size: Vector2, font: Font) -> void:
	var help: Array = []
	var key_w := 0.0
	for row in Controls.HELP:
		var k: String = Controls.pad_text(row[2], main.pad_ps) if main.pad_active else row[1]
		if k == "-":
			continue
		help.append([k, row[0]])
		key_w = maxf(key_w, font.get_string_size(k, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x)
	var box_w := key_w + 176.0
	var box := Rect2(size.x - box_w - 16.0, 14, box_w, 20 + help.size() * 17)
	var pb := Draw.Batch.new()
	UI.plate_into(pb, box)
	pb.flush(self)
	for i in help.size():
		var row_y := box.position.y + 24 + i * 17
		draw_string(font, Vector2(box.position.x + 12, row_y), help[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, GOLD)
		draw_string(font, Vector2(box.position.x + key_w + 22, row_y), help[i][1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TEXT)


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
		draw_string(font, r.position + Vector2(8, 16 + 15 * i), perf_text[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.75, 1.0, 0.75))


## Top right, for the first seconds of a floor: the keys (or buttons) for the
## menu, climber screen and inventory.
func _draw_screen_hints(size: Vector2, font: Font, a := 1.0) -> void:
	var hints: Array = [["Esc", "{start}", "menu"], ["Tab", "{back}", "climber"], ["I", "D-pad up", "inventory"], ["H", "-", "keys"]]
	var parts: Array = []
	var w := 0.0
	var mono := UI.font("mono")
	for h in hints:
		var k: String = Controls.pad_text(h[1], main.pad_ps) if main.pad_active else h[0]
		if k == "-":
			continue
		parts.append([k, h[2]])
		w += maxf(mono.get_string_size(k, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x + 8.0, 15.0) + font.get_string_size(h[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 20.0
	var r := Rect2(size.x - 16.0 - w - 10.0, 12, w + 10.0, 26)
	var b := Draw.Batch.new()
	UI.plate_into(b, r, a)
	b.flush(self)
	# Each key on its badge, then what it opens.
	var x := r.position.x + 10.0
	for pt in parts:
		var kw: float = UI.draw_key(self, Vector2(x, 17), pt[0], 10, Color(GOLD, a)).x
		x += kw + 5.0
		draw_string(font, Vector2(x, 30), pt[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(DIM_TEXT, a))
		x += font.get_string_size(pt[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 15.0


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
		var w := UI.font("display").get_string_size(UI.title_case(t[1]), HORIZONTAL_ALIGNMENT_LEFT, -1, 17).x
		for l in lines:
			w = maxf(w, font.get_string_size(l, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x)
		var size := get_viewport_rect().size / hud_scale
		var box := Rect2(m + Vector2(16, 14), Vector2(w + 40.0, 26.0 + 16.0 * lines.size()))
		box.position.x = minf(box.position.x, size.x - box.size.x - 6.0)
		if box.end.y > size.y - 6.0:
			box.position.y = m.y - box.size.y - 10.0
		box.size.y += 8.0
		draw_style_box(tip_box, box)
		# The Entity tells you what it is (its small face in the corner).
		Entity.draw_face(self, box.position + Vector2(box.size.x - 14.0, 15.0), 7.0, 0.0)
		UI.draw_label(self, box.position + Vector2(12, 20), t[1], 17, GOLD)
		# A gilt rule under the title, fading to the right.
		draw_polyline_colors(PackedVector2Array([box.position + Vector2(12, 27), box.position + Vector2(box.size.x - 30.0, 27)]), PackedColorArray([Color(UI.GILT, 0.7), Color(UI.GILT, 0.0)]), 1.0)
		for i in lines.size():
			draw_string(font, box.position + Vector2(12, 42 + 16 * i), lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TEXT)
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
	draw_style_box(card_box, r)
	var col: Color = Gear.color(id)
	var rim: Color = Gear.rarity_color(id) if Gear.rarity(id) != "common" else col
	draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 4)), Color(rim, 0.85))
	var head: String = "%s  ·  %s" % [Gear.TEXT["on_floor"], String(Gear.SLOT_NAMES.get(slot_id, slot_id))]
	if Gear.rarity(id) != "common":
		head += "  ·  " + Gear.rarity_name(id)
	UI.draw_eyebrow(self, r.position + Vector2(12, 20), head, DIM_TEXT, 14)
	Gear.draw_icon(self, id, r.position + Vector2(w - 26, 24), 11.0, col)
	UI.draw_label(self, r.position + Vector2(12, 39), Gear.display(id), 20, rim.lightened(0.2), HORIZONTAL_ALIGNMENT_LEFT, w - 50)
	for i in traits.size():
		draw_string(font, r.position + Vector2(12, 53 + 14 * i), traits[i][0], HORIZONTAL_ALIGNMENT_LEFT, w - 24, 13, Color(traits[i][1], 0.95))
	var held_name: String = Gear.display(held) if has_held else (Gear.TEXT["none"] if slot_id == "armor" else Gear.TEXT["empty"])
	var x1 := r.position.x + 12.0
	var x2 := r.position.x + 128.0
	var x3 := r.position.x + 232.0
	var y := r.position.y + 58.0 + 14.0 * traits.size()
	draw_string(font, Vector2(x2, y), "this", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, DIM_TEXT)
	draw_string(font, Vector2(x3, y), held_name.to_lower(), HORIZONTAL_ALIGNMENT_LEFT, w - (x3 - r.position.x) - 6.0, 13, DIM_TEXT)
	var arrows := Draw.Batch.new()
	for row in rows:
		y += 17.0
		draw_string(font, Vector2(x1, y), row[0], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, TEXT)
		var better: int = row[3]
		var vcol := UI.GOOD if better > 0 else (UI.BAD if better < 0 else TEXT)
		draw_string(font, Vector2(x2, y), row[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, vcol)
		draw_string(font, Vector2(x3, y), row[2], HORIZONTAL_ALIGNMENT_LEFT, -1, 14, DIM_TEXT)
		if better != 0:
			UI.arrow_into(arrows, Vector2(x2 - 8.0, y - 4.0), 3.5, better > 0, vcol)
	arrows.flush(self)
	var how: String = _say(Gear.TEXT["take_key"], Gear.TEXT["take_pad"], Gear.TEXT["take_tap"])
	if has_held:
		how += "  " + (Gear.TEXT["to_pack"] if p.pack_room() else Gear.TEXT["drops"]) % Gear.display(held)
	draw_string(font, Vector2(r.position.x, r.end.y - 8.0), how, HORIZONTAL_ALIGNMENT_CENTER, w, 14, GOLD)


## The Regard: the beast's eye opens on you, and your first mark takes hold.
func _draw_regard(size: Vector2, font: Font) -> void:
	var rg: Dictionary = main.regard
	if rg.get("refused", false):
		_draw_refused(size, font)
		return
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
	draw_string_outline(UI.font("display"), Vector2(0, size.y * 0.3 - 110), "The Regard", HORIZONTAL_ALIGNMENT_CENTER, size.x, 42, 7, Color(0, 0, 0, 0.8 * title_a))
	draw_string(UI.font("display"), Vector2(0, size.y * 0.3 - 110), "The Regard", HORIZONTAL_ALIGNMENT_CENTER, size.x, 42, Color(GOLD, title_a))
	var ty := size.y * 0.3 + 190.0
	for i in texts.size():
		var a := clampf((t - 1.4 - i * 0.45) / 0.5, 0.0, 1.0)
		var tc := col.lightened(0.2) if i == 2 else TEXT
		draw_string(font, Vector2(0, ty), texts[i], HORIZONTAL_ALIGNMENT_CENTER, size.x, 20 if i == 2 else 17, Color(tc, a))
		ty += 26.0
	_draw_regard_pay(size, font, ty, t - 1.4 - texts.size() * 0.45)
	if main.regard_done():
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
		var prompt := _say("Press Space, Enter or click", "Press {a}", "Tap") + " to begin your next climb"
		draw_string(font, Vector2(0, size.y - 40), prompt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color(DIM_TEXT, 0.5 + 0.5 * pulse))


## Under the Regard's words: what the outfitter paid for the first climb
## (in gold), when there's room above the prompt.
func _draw_regard_pay(size: Vector2, font: Font, y: float, since: float) -> void:
	if main.pay_line == "" or y > size.y - 62.0:
		return
	var a := clampf(since / 0.5, 0.0, 1.0)
	draw_string(font, Vector2(0, y + 4.0), main.pay_line, HORIZONTAL_ALIGNMENT_CENTER, size.x, 17, Color(GOLD, a))


const UnboundData := preload("res://scripts/unbound.gd")
const RAW_ESSENCE := Color(0.92, 0.9, 1.0)


## The Regard refused (a barrier broken on the first climb): the eye opens,
## looks you over, and turns away; no mark forms. Then the words.
func _draw_refused(size: Vector2, font: Font) -> void:
	var rg: Dictionary = main.regard
	var t: float = rg["t"]
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.03, _overlay_shade(rg, 0.96)))
	var c := Vector2(size.x / 2.0, size.y * 0.3)
	# The eye opens, then narrows and looks aside.
	var open := clampf((t - 0.4) / 1.0, 0.0, 1.0)
	open = open * open * (3.0 - 2.0 * open)
	var shut := clampf((t - 1.5) / 0.7, 0.0, 1.0)
	var w := minf(size.x * 0.36, 300.0)
	var h := 70.0 * open * (1.0 - 0.75 * shut)
	var lid := PackedVector2Array()
	for i in 33:
		var k := float(i) / 32.0
		lid.append(c + Vector2(lerpf(-w, w, k), -sin(PI * k) * h))
	for i in 33:
		var k := float(i) / 32.0
		lid.append(c + Vector2(lerpf(w, -w, k), sin(PI * k) * h))
	draw_colored_polygon(lid, Color(0.75, 0.72, 0.8, 0.08 + 0.08 * open))
	draw_polyline(lid + PackedVector2Array([lid[0]]), Color(0.85, 0.82, 0.9, 0.7 * open + 0.1), 2.5, true)
	if open > 0.2 and h > 6.0:
		var look := c + Vector2(w * 0.55 * shut, 0)
		var iris := minf(52.0 * minf(1.0, open * 1.2), h * 0.95)
		draw_circle(look, iris, Color(0.55, 0.52, 0.6, 0.6))
		draw_circle(look, iris * 0.28, Color(0.02, 0.02, 0.03, 0.95))
	# Where a mark would grow: nothing takes hold; raw essence instead.
	var mk := clampf((t - 1.8) / 1.0, 0.0, 1.0)
	if mk > 0.0:
		var mc := c + Vector2(0, 130)
		draw_arc(mc, 18.0, 0.0, TAU, 32, Color(0.6, 0.58, 0.65, 0.5 * mk), 2.0, true)
		for i in 6:
			var a := float(i) * TAU / 6.0 + t * 0.6
			draw_circle(mc + Vector2.from_angle(a) * (6.0 + 8.0 * mk), 2.0, Color(RAW_ESSENCE, 0.7 * mk))
	var lines: Array = UnboundData.TEXT["refused_lines"].duplicate()
	lines[1] = lines[1] % main.beast_name().capitalize()
	var title: String = UnboundData.TEXT["refused_title"]
	var title_a := clampf((t - 0.2) / 0.6, 0.0, 1.0)
	draw_string_outline(UI.font("display"), Vector2(0, size.y * 0.3 - 110), UI.title_case(title), HORIZONTAL_ALIGNMENT_CENTER, size.x, 40, 7, Color(0, 0, 0, 0.8 * title_a))
	draw_string(UI.font("display"), Vector2(0, size.y * 0.3 - 110), UI.title_case(title), HORIZONTAL_ALIGNMENT_CENTER, size.x, 40, Color(RAW_ESSENCE, title_a))
	var ty := size.y * 0.3 + 190.0
	for i in lines.size():
		var a2 := clampf((t - 1.4 - i * 0.45) / 0.5, 0.0, 1.0)
		var tc := RAW_ESSENCE if i == 2 else TEXT
		draw_string(font, Vector2(0, ty), lines[i], HORIZONTAL_ALIGNMENT_CENTER, size.x, 20 if i == 2 else 17, Color(tc, a2))
		ty += 26.0
	_draw_regard_pay(size, font, ty, t - 1.4 - lines.size() * 0.45)
	if main.regard_done():
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
		var prompt := _say("Press Space, Enter or click", "Press {a}", "Tap") + " to begin your next climb"
		draw_string(font, Vector2(0, size.y - 40), prompt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color(DIM_TEXT, 0.5 + 0.5 * pulse))


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
	draw_string_outline(UI.font("display"), Vector2(0, top_y - 46.0), UI.title_case(title), HORIZONTAL_ALIGNMENT_CENTER, size.x, 38, 6, Color(0, 0, 0, 0.8))
	draw_string(UI.font("display"), Vector2(0, top_y - 46.0), UI.title_case(title), HORIZONTAL_ALIGNMENT_CENTER, size.x, 38, GOLD)
	var sub := "Each tower's monsters and essence shape the marks you'll form."
	draw_string(font, Vector2(0, top_y - 20.0), sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, DIM_TEXT)
	for i in TowersData.ORDER.size():
		var id: String = TowersData.ORDER[i]
		var t: Dictionary = TowersData.TOWERS[id]
		var r := tower_card_rect(i, size)
		var ec := Essence.color(t["essence"])
		var last: bool = id == main.profile.last_tower
		var box := card_box_on if last else card_box
		draw_style_box(box, r)
		var focused := _card_focused(i)
		if focused:
			_draw_card_focus(r)
		draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 5)), Color(t["torch"], 0.7))
		var x := r.position.x + 14.0
		var y := r.position.y + 34.0
		var narrow := r.size.x < 200.0 or r.size.y < 200.0  # many cards, or a phone
		UI.draw_label(self, Vector2(x, y), t["short"] if narrow else t["name"], 22, TEXT, HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28.0)
		y += 24.0
		draw_circle(Vector2(x + 6, y - 5), 6.0, ec)
		draw_string(font, Vector2(x + 18, y), "%s essence" % Essence.display(t["essence"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, ec)
		y += 18.0
		draw_multiline_string(font, Vector2(x, y + 4), t["blurb"], HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28.0, 13 if narrow else 15, 4 if r.size.y < 200.0 else 7, DIM_TEXT)
		var hint := _card_hint(i)
		draw_string(font, Vector2(r.position.x, r.end.y - 14.0), hint, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, GOLD if last or focused else DIM_TEXT)


# --- hold to pick ----------------------------------------------------------------

## The open ring (if any), on its own node over the touch buttons.
func _draw_rings() -> void:
	var p = main.player
	if p == null or main.title_showing():
		return
	var font := ThemeDB.fallback_font
	if p.pick_open:
		_draw_spell_ring(p, font, rings)
	if p.ring_open:
		_draw_item_ring(p, font, rings)


## The ring of a mark's spells, around the climber (or, on a phone, beside
## the thumb on its button). The highlighted one is cast when you let go.
func _draw_spell_ring(p, font: Font, ci: CanvasItem) -> void:
	var b = p.bonds.get(p.pick_part)
	if b == null:
		return
	var known: Array = b.spells()
	var ring_r := 78.0
	var c: Vector2 = p.get_global_transform_with_canvas().origin
	if main.touch_active:
		c = Nav.ring_center(main.pick_anchor, ring_r + 34.0, get_viewport_rect().size, RING_THUMB, RING_TEXT)  # (beside the thumb, never under it)
	_paint_spell_ring(ci, p, b, known, c, ring_r)


## The spell ring's look (ui.gd draw_wheel): each spell in a medallion with
## its bond's emblem and its name, its cost as a gem; the pointed-at one
## named and described under the wheel.
func _paint_spell_ring(ci: CanvasItem, p, b, known: Array, c: Vector2, ring_r: float) -> void:
	var col: Color = b.color()
	var aff: String = b.data()["affinity"]
	var opts: Array = []
	for sp in known:
		var cost := int(round(b.spell_cost(sp)))
		opts.append({"name": sp["name"], "col": col, "gems": [[col, cost]] if cost > 0 else [],
			"icon": func(bt, at: Vector2, s: float, ic: Color): UI.emblem_into(bt, at, s, aff, ic, 1.0)})
	UI.draw_wheel(ci, c, ring_r, opts, p.pick_index, col, get_viewport_rect().size)
	if p.pick_index >= 0 and p.pick_index < known.size():
		var sp: Dictionary = known[p.pick_index]
		UI.draw_wheel_caption(ci, c.x, c.y + ring_r + 56.0, 340.0, sp["name"], sp["desc"], col)


## The ring of belt items, around the climber (or, on a phone, beside the
## thumb on the Item button). The highlighted one is used when you let go.
func _draw_item_ring(p, font: Font, ci: CanvasItem) -> void:
	var have: Array = p.carried()
	if have.is_empty():
		return
	var c: Vector2 = p.get_global_transform_with_canvas().origin
	var ring_r := 78.0
	var view := get_viewport_rect().size
	c = Vector2(clampf(c.x, ring_r + 40.0, view.x - ring_r - 40.0), clampf(c.y, ring_r + 40.0, view.y - ring_r - 100.0))
	if main.touch_active:
		# On a phone the ring sits beside your thumb on the Item button (never
		# under it); you point by sliding from the button.
		c = Nav.ring_center(main.pick_anchor, ring_r + 34.0, view, RING_THUMB, RING_TEXT)
	_paint_item_ring(ci, p, have, c, ring_r)


## The item ring's look (ui.gd draw_wheel): each item in a medallion with
## its icon, its name and how many you carry; the pointed-at one named and
## described under the wheel.
func _paint_item_ring(ci: CanvasItem, p, have: Array, c: Vector2, ring_r: float) -> void:
	var opts: Array = []
	for id in have:
		opts.append({"name": Items.info(id)["name"], "col": Items.color(id), "badge": str(p.item_count(id)),
			"icon": func(bt, at: Vector2, s: float, _ic: Color): Items.icon_into(bt, id, at, s * 1.05)})
	UI.draw_wheel(ci, c, ring_r, opts, p.ring_index, UI.GILT, get_viewport_rect().size)
	if p.ring_index >= 0 and p.ring_index < have.size():
		var d: Dictionary = Items.info(have[p.ring_index])
		UI.draw_wheel_caption(ci, c.x, c.y + ring_r + 56.0, 340.0, d["name"], _sentence(String(d["desc"])), d["color"])


## A Rare (or better) find: a short notice fades in under the floor title.
func _draw_loot_notice(size: Vector2, font: Font) -> void:
	var n: Dictionary = main.loot_notice
	if n.is_empty():
		return
	var a := _fade(float(n["t"]), 3.5)
	var col: Color = n["color"]
	var y := 96.0
	var w := UI.font("display").get_string_size(UI.title_case(n["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x + 36.0
	var r := Rect2(Vector2((size.x - w) / 2.0, y - 18.0), Vector2(w, 26.0))
	draw_rect(r, Color(0.03, 0.025, 0.05, 0.7 * a))
	draw_rect(Rect2(r.position, Vector2(r.size.x, 2.0)), Color(col, 0.9 * a))
	UI.draw_label(self, Vector2(0, y), n["text"], 19, Color(col.lightened(0.2), a), HORIZONTAL_ALIGNMENT_CENTER, size.x, 4, Color(0, 0, 0, 0.8 * a))


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
	if not main.stair_open or main.climbing or main.player == null or main.camp_choosing:
		return
	var sp: Vector2 = main.get_viewport().get_canvas_transform() * main.stair_pos
	var margin := 40.0
	if Rect2(Vector2.ZERO, size).grow(-margin).has_point(sp):
		return
	# It rides the edge of its ring (layout.gd "hud.stair": by default the
	# screen less a margin, and below the floor counter and stair line at the
	# top), on the line from the screen's centre (or the ring's) to the stair.
	var ring := Layout.box("hud.stair", size)
	var center := size * 0.5
	if not ring.has_point(center):
		center = ring.get_center()
	var d := (sp - center).normalized()
	var reach_x: float = (ring.end.x - center.x) if d.x > 0.0 else (center.x - ring.position.x)
	var reach_y: float = (ring.end.y - center.y) if d.y > 0.0 else (center.y - ring.position.y)
	var at := center + d * minf(reach_x / maxf(absf(d.x), 0.001), reach_y / maxf(absf(d.y), 0.001))
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.006)
	var tip := at + d * 14.0
	# A gilt arrowhead, outlined and lit along one side, with a stud behind it.
	var side := d.orthogonal()
	var head := PackedVector2Array([tip, at - d * 8.0 + side * 10.0, at - d * 3.0, at - d * 8.0 - side * 10.0])
	var b := Draw.Batch.new()
	UI.glow_into(b, at, 22.0, UI.GILT, 0.6 * pulse)
	b.poly(head, Color(UI.GILT_DEEP.lerp(UI.GILT, 0.6), 0.6 + 0.4 * pulse), 1.4)
	b.polygon(PackedVector2Array([tip, at - d * 8.0 + side * 10.0, at - d * 3.0]), Color(UI.GILT_HI, 0.55 + 0.45 * pulse))
	UI.diamond_into(b, at - d * 13.0, 3.4, UI.OUTLINE)
	UI.diamond_into(b, at - d * 13.0, 2.2, Color(UI.GILT_HI, pulse))
	b.flush(self)
	UI.draw_label(self, at - d * 28.0 + Vector2(-20, 4), "Stair", 16, Color(1.0, 0.85, 0.5, pulse), HORIZONTAL_ALIGNMENT_LEFT, -1, 3, Color(0, 0, 0, 0.7))


func _draw_boss_bar(size: Vector2, font: Font) -> void:
	for e in main.enemies():
		if not e.is_boss():
			continue
		var w := minf(460.0, size.x - 120.0)
		var r := Rect2(Vector2((size.x - w) / 2.0, 86), Vector2(w, 12))
		var name: String = UI.titled(main.beast_name())
		if e.shade:  # the Proving's shadow of the beast
			name = UI.titled(String(main.proving.TEXT["shadow_bar"]) % main.beast_name())
		var k := clampf(e.hp / e.max_hp, 0.0, 1.0)
		# The chunk just lost lingers, then drains down to it.
		var now := Time.get_ticks_msec()
		var dt := clampf((now - _boss_t) / 1000.0, 0.0, 0.1)
		_boss_t = now
		if e != _boss_seen:
			_boss_seen = e
			_boss_trail = k
		_boss_trail = k if _boss_trail < k else move_toward(_boss_trail, k, dt * 0.35)
		var col := Color(0.62, 0.42, 0.9) if e.shade else Color(0.86, 0.26, 0.2)
		draw_set_transform_matrix(Layout.xform("hud.beast", size))
		var b := Draw.Batch.new()
		# A dark band behind, the name between gilt rules, the bar in a gilt
		# frame with horned finials and studs at the quarters.
		UI.band_into(b, Rect2(r.position.x - 70.0, 52.0, w + 140.0, 60.0), 1.0, UI.GILT, 0.7)
		var tw := UI.font("display").get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 26).x
		UI.flank_into(b, size.x * 0.5, 70.0, tw * 0.5 + 12.0, minf(110.0, w * 0.5 - tw * 0.5 - 16.0), Color(UI.GILT, 0.8))
		for side in [-1.0, 1.0]:
			var tip := Vector2(r.get_center().x + side * (w * 0.5 + 22.0), r.get_center().y)
			var base := Vector2(r.get_center().x + side * (w * 0.5 + 3.0), r.get_center().y)
			var horn := PackedVector2Array([base + Vector2(0, -8.5), tip, base + Vector2(0, 8.5), base + Vector2(side * 5.0, 0)])
			b.poly(horn, UI.GILT_DEEP.lerp(UI.GILT, 0.5), 1.2)
			b.polygon(PackedVector2Array([base + Vector2(0, -8.5), tip, base + Vector2(side * 5.0, 0)]), UI.GILT_HI)
			UI.diamond_into(b, tip + Vector2(side * 5.0, 0), 2.6, UI.GILT_HI)
		UI.gauge_into(b, r, k, col, _boss_trail, Color(1.0, 0.82, 0.55, 0.9), 4)
		for i in range(1, 4):
			var sx := r.position.x + w * i / 4.0
			UI.diamond_into(b, Vector2(sx, r.position.y - 2.6), 2.4, UI.OUTLINE)
			UI.diamond_into(b, Vector2(sx, r.position.y - 2.6), 1.5, UI.GILT_HI)
		b.flush(self)
		UI.draw_title(self, Vector2(0, 79), name, 26, UI.GILT_HI if not e.shade else Color(0.85, 0.78, 1.0), HORIZONTAL_ALIGNMENT_CENTER, size.x, 0.8)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		return


var _boss_trail := 1.0  # the beast bar's lingering chunk
var _boss_seen = null
var _boss_t := 0


## A sealed wing's question (wings.gd): its condition, kept or broken, the
## wave and the clock; and a champion's health bar.
func _draw_wing_status(size: Vector2, font: Font) -> void:
	if main.wings == null or main.fade > 0.0 or main.overlay_showing() or main.camp_choosing:
		return
	draw_set_transform_matrix(Layout.xform("hud.plates", size))
	_draw_plates(size, font)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## The lock-in room's plate and a challenge's (in the default layout's places).
func _draw_plates(size: Vector2, font: Font) -> void:
	# Shut in a lock-in room (doors.gd): say so, and how many foes are left.
	var ls: Dictionary = main.door_view.lock_status() if main.door_view != null else {}
	var y := 84.0
	if not ls.is_empty() and not _boss_alive():  # (a beast's shadow has its own bar there)
		var t1: String = main.door_view.LOCK_TEXT["status"]
		var t2: String = main.door_view.LOCK_TEXT["left"] % int(ls["left"])
		var lw := maxf(UI.font("display").get_string_size(t1, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x, font.get_string_size(t2, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x) + 56.0
		var lb := Draw.Batch.new()
		UI.cartouche_into(lb, Rect2((size.x - lw) * 0.5, 67.0, lw, 42.0), Color(UI.BLOOD, 0.85))
		lb.flush(self)
		UI.draw_label(self, Vector2(0, 84), t1, 20, Color(0.9, 0.55, 0.45), HORIZONTAL_ALIGNMENT_CENTER, size.x, 4)
		draw_string_outline(font, Vector2(0, 102), t2, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, 3, Color(0, 0, 0, 0.7))
		draw_string(font, Vector2(0, 102), t2, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, TEXT)
		y += 48.0  # (a challenge's words go under it)
	var st: Dictionary = main.wings.status()
	if st.is_empty():
		return
	var champ = st.get("champ")
	if champ != null:
		var w := minf(360.0, size.x - 140.0)
		var r := Rect2(Vector2((size.x - w) / 2.0, y + 8.0), Vector2(w, 8))
		var name: String = UI.titled(String(main.wings.TEXT["champion"]))
		var cb := Draw.Batch.new()
		var nw := UI.font("display").get_string_size(name, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		UI.flank_into(cb, size.x * 0.5, y - 6.0, nw * 0.5 + 10.0, 60.0, Color(UI.GILT, 0.7))
		UI.gauge_into(cb, r, clampf(champ.hp / champ.max_hp, 0.0, 1.0), Color(0.95, 0.72, 0.3), -1.0, Color(), 4)
		cb.flush(self)
		UI.draw_label(self, Vector2(0, y), name, 19, GOLD, HORIZONTAL_ALIGNMENT_CENTER, size.x, 4)
		y += 40.0
	if champ != null and st["line"] == "":
		return
	var col := GOLD if st["ok"] else Color(0.9, 0.42, 0.35)
	var head: String = UI.title_case(st["title"]) + ("" if st["ok"] else "  ·  broken")
	var hw := maxf(UI.font("display").get_string_size(head, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x, font.get_string_size(st["line"], HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x if st["line"] != "" else 0.0) + 56.0
	var wb := Draw.Batch.new()
	UI.cartouche_into(wb, Rect2((size.x - hw) * 0.5, y - 17.0, hw, 42.0 if st["line"] != "" else 25.0), Color(col, 0.85))
	wb.flush(self)
	UI.draw_label(self, Vector2(0, y), head, 20, col, HORIZONTAL_ALIGNMENT_CENTER, size.x, 4)
	if st["line"] != "":
		draw_string_outline(font, Vector2(0, y + 19.0), st["line"], HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, 3, Color(0, 0, 0, 0.7))
		draw_string(font, Vector2(0, y + 19.0), st["line"], HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, TEXT)


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
	draw_string_outline(UI.font("display"), Vector2(0, top), UI.title_case(head), HORIZONTAL_ALIGNMENT_CENTER, size.x, 48, 7, Color(0, 0, 0, 0.8 * a))
	draw_string(UI.font("display"), Vector2(0, top), UI.title_case(head), HORIZONTAL_ALIGNMENT_CENTER, size.x, 48, Color(GOLD, a))
	draw_string(font, Vector2(0, top + 34), sub, HORIZONTAL_ALIGNMENT_CENTER, size.x, 21, Color(TEXT, a))
	var ly := top + 70.0
	for line in v["lines"]:
		draw_string(font, Vector2(0, ly), line, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color(DIM_TEXT, a))
		ly += 22.0
	if main.overlay_done():
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.004)
		var prompt := _say("Press Space, Enter or click", "Press {a}", "Tap") + " to climb again"
		draw_string(font, Vector2(0, size.y - 40), prompt, HORIZONTAL_ALIGNMENT_CENTER, size.x, 16, Color(DIM_TEXT, 0.5 + 0.5 * pulse))


# --- items and camps ---------------------------------------------------------------

static func _sentence(t: String) -> String:
	return t.left(1).to_upper() + t.substr(1) + "."


## Cards to a row on the card screens: one row of up to five, else two rows
## (the heirloom choice can offer a card for every slot).
func camp_per_row() -> int:
	var n: int = main.camp.get("choices", []).size()
	return n if n <= 5 else int(ceil(n / 2.0))


func camp_card_rect(i: int, size: Vector2) -> Rect2:
	if main.camp.get("stage", "") == "path":
		return path_card_rect(i, size)
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


## The path choice's two cards (Life, Unmaking): bigger than a camp's, side
## by side, under the Entity's words.
func path_card_rect(i: int, size: Vector2) -> Rect2:
	var gap := 26.0 if size.x > 700.0 else 12.0
	var w := minf(330.0, (size.x - 32.0 - gap) / 2.0)
	var head := 110.0 if size.y > 560.0 else 92.0  # the title and the Entity's words above
	var h := minf(380.0, size.y - head - 24.0)
	var top := maxf(head, (size.y - h) * 0.5 + head * 0.45)
	h = minf(h, size.y - top - 12.0)
	var x0 := (size.x - (w * 2.0 + gap)) / 2.0
	return Rect2(Vector2(x0 + i * (w + gap), top), Vector2(w, h))


## The path choice: the Entity says what's at stake, each card shows its
## shadow alive at the last step, what it does and what each step brings.
## A card is taken with a second press (main.gd _take_path_pick).
func _draw_path_choice(size: Vector2, font: Font) -> void:
	var t := Time.get_ticks_msec() * 0.001
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.01, 0.008, 0.02, 0.86))
	var r0 := path_card_rect(0, size)
	var narrow := r0.size.x < 260.0
	# The two colours, faint behind their cards.
	var bg := Draw.Batch.new()
	for i in 2:
		var kind := String(main.camp["choices"][i]).substr(5)
		var r := path_card_rect(i, size)
		UI.glow_into(bg, r.get_center(), r.size.x * 0.75, Secret.color(kind), 0.5)
	bg.flush(self)
	# The title, and the Entity's words beside its face.
	var title: String = main.camp.get("title", "")
	var ty := maxf(28.0, r0.position.y - (92.0 if size.y > 560.0 else 74.0))
	draw_string_outline(UI.font("display"), Vector2(0, ty), UI.title_case(title), HORIZONTAL_ALIGNMENT_CENTER, size.x, 34 if not narrow else 27, 6, Color(0, 0, 0, 0.8))
	draw_string(UI.font("display"), Vector2(0, ty), UI.title_case(title), HORIZONTAL_ALIGNMENT_CENTER, size.x, 34 if not narrow else 27, GOLD)
	var lines: Array = main.camp.get("lines", [])
	var tw := minf(size.x - 80.0, 640.0)
	var tx := (size.x - tw) / 2.0 + 24.0
	var face_r := 13.0 if not narrow else 10.0
	Entity.draw_face(self, Vector2(tx - face_r - 10.0, ty + 14.0 + face_r), face_r, t)
	var ly := ty + 22.0
	for line in lines:
		var fs := 15 if not narrow else 13
		draw_multiline_string(font, Vector2(tx, ly), line, HORIZONTAL_ALIGNMENT_LEFT, tw - 24.0, fs, 2, Color(TEXT, 0.92))
		ly += font.get_multiline_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, tw - 24.0, fs).y + 2.0
	var armed: int = int(main.camp.get("armed", -1))
	var ready: bool = float(main.camp.get("t", 0.0)) >= main.PATH_GRACE
	for i in 2:
		var card: Dictionary = main.camp_card(i)
		var kind: String = card["secret"]
		var r := path_card_rect(i, size)
		var col: Color = card["color"]
		var light: Color = Secret.KINDS[kind]["light"]
		draw_style_box(card_box, r)
		draw_rect(Rect2(r.position + Vector2(1, 1), Vector2(r.size.x - 2, 5)), Color(col, 0.9))
		if armed == i:
			var pulse := 0.6 + 0.4 * sin(t * 6.0)
			draw_rect(r.grow(4.0), Color(col.lightened(0.3), 0.95 * pulse), false, 3.0)
		elif _card_focused(i):
			_draw_card_focus(r)
		# A climber's silhouette, its shadow alive as at the last step.
		var tall := r.size.y >= 340.0
		var sh_h := clampf(r.size.y * (0.3 if tall else 0.24), 56.0, 112.0)
		var sc := Vector2(r.get_center().x, r.position.y + 14.0 + sh_h * 0.85)
		var sb := Draw.Batch.new()
		# Its essence drifting up through the card: spores of Life, shards of Unmaking.
		for m in 14:
			var ph := fposmod(t * (0.07 + 0.012 * float(m % 5)) + float(m) * 0.618, 1.0)
			var mx: float = r.position.x + 14.0 + fposmod(float(m) * 0.383 + 0.05 * sin(t * 0.7 + float(m)), 1.0) * (r.size.x - 28.0)
			var my: float = r.end.y - 30.0 - ph * (r.size.y - 50.0)
			var ma := sin(PI * ph) * 0.5
			if kind == "life":
				sb.dot(Vector2(mx, my), 1.6, Color(light, ma))
				sb.dot(Vector2(mx, my), 3.6, Color(col, ma * 0.25))
			else:
				var q := 1.4 + 0.6 * float(m % 3)
				sb.rect(Rect2(Vector2(mx, my) - Vector2(q, q) * 0.5, Vector2(q, q)), Color(light, ma))
		Secret.draw_shadow(sb, sc, sh_h * 0.3, kind, 4, t + i * 0.37, 1.0)
		Secret.draw_figure(sb, sc, sh_h * 0.66, col, t + i * 1.3)
		sb.flush(self)
		var y := sc.y + sh_h * 0.3 + (26.0 if tall else 18.0)
		UI.draw_label(self, Vector2(r.position.x, y), card["name"], 25 if not narrow else 21, light, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 4)
		y += 18.0 if not narrow else 15.0
		# (its motto: an inscription)
		UI.draw_inscription(self, Vector2(r.position.x, y), card["desc"], 17 if not narrow else 15, Color(col.lightened(0.15), 0.95), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		y += 18.0 if not narrow else 14.0
		var steps: Array = card["steps"]
		var fs := 14 if not narrow else 12
		var lw := r.size.x - 40.0
		var hint_y := r.end.y - 12.0
		for si in steps.size():
			if y > hint_y - 14.0:
				break
			var pc := Vector2(r.position.x + 18.0, y - 4.0)
			draw_circle(pc, 7.0 if not narrow else 6.0, Color(col, 0.25))
			draw_string(UI.font("mono"), pc + Vector2(-8, 4), str(si + 1), HORIZONTAL_ALIGNMENT_CENTER, 16, fs - 1, light)
			draw_multiline_string(font, Vector2(r.position.x + 30.0, y), steps[si], HORIZONTAL_ALIGNMENT_LEFT, lw, fs, 2, TEXT)
			y += font.get_multiline_string_size(steps[si], HORIZONTAL_ALIGNMENT_LEFT, lw, fs).y + (5.0 if not narrow else 2.0)
		if y < hint_y - 22.0:
			draw_string(font, Vector2(r.position.x, hint_y - 18.0), card["note"], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 12, DIM_TEXT)
		var hint := _path_hint(i, armed == i)
		draw_string(font, Vector2(r.position.x, hint_y), hint, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, Color(light if armed == i else GOLD, 1.0 if ready else 0.35))


## Under a path card: how to take it (twice: it's for good).
func _path_hint(i: int, armed: bool) -> String:
	if main.touch_active:
		return Secret.TEXT["tap_again"] if armed else Secret.TEXT["tap_choose"]
	if main.pad_active:
		return Controls.pad_text(Secret.TEXT["pad_again"] if armed else Secret.TEXT["pad_choose"], main.pad_ps) if armed or _card_focused(i) else ""
	return Secret.TEXT["press_again"] if armed else Secret.TEXT["press_choose"] % (i + 1)


## A camp: pick one of the cards (like choosing a tower).
func _draw_camp_choice(size: Vector2, font: Font) -> void:
	if main.camp.get("stage", "") == "path":
		_draw_path_choice(size, font)
		return
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.02, 0.015, 0.03, 0.9 if main.camp["stage"] == "unbind" else 0.72))  # (the refusal hides the Regard behind it)
	var rune: bool = main.camp["stage"] == "rune"
	var top_y := camp_card_rect(0, size).position.y
	var title: String = Items.CAMP["rune_title"] if rune else Items.CAMP["choose"]
	if main.camp["stage"] == "heirloom":
		title = Gear.HEIRLOOM_TEXT["title"]
	elif main.camp["stage"] in ["vault", "belt", "unbind", "condense", "secret"]:
		title = main.camp.get("title", "")
	draw_string_outline(UI.font("display"), Vector2(0, top_y - 62.0), UI.title_case(title), HORIZONTAL_ALIGNMENT_CENTER, size.x, 36, 6, Color(0, 0, 0, 0.8))
	draw_string(UI.font("display"), Vector2(0, top_y - 62.0), UI.title_case(title), HORIZONTAL_ALIGNMENT_CENTER, size.x, 36, GOLD)
	var sub: Array = main.camp.get("lines", [])
	var sy := top_y - 38.0
	for line in sub.slice(0, 2):
		draw_string(font, Vector2(0, sy), line, HORIZONTAL_ALIGNMENT_CENTER, size.x, 15, DIM_TEXT)
		sy += 17.0
	var p = main.player
	for i in main.camp["choices"].size():
		var card: Dictionary = main.camp_card(i)
		var r := camp_card_rect(i, size)
		var col: Color = card["color"]
		var rim: Color = card.get("rim", col)  # gear: its rarity's colour
		draw_style_box(card_box, r)
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
		UI.draw_label(self, Vector2(r.position.x + 6, y), card["name"], 19 if r.size.x > 180 else 17, (rim if card.has("rim") else col).lightened(0.2), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 12.0)
		# As many lines of its text as fit above the note.
		var dy := y + (15.0 if small else 20.0)
		var lines := 4 if not small else clampi(int((r.end.y - 46.0 - dy) / 16.0) + 1, 1, 4)
		draw_multiline_string(font, Vector2(r.position.x + 8, dy), card["desc"], HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 16.0, 13 if small else 14, lines, TEXT)
		if card.has("note"):
			draw_string(font, Vector2(r.position.x, r.end.y - 34.0), card["note"], HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13, DIM_TEXT)
		if card["item"] != "" and p != null and not card.has("belt"):
			var n: int = p.item_count(card["item"])
			var have := "carrying %d of %d" % [n, p.max_stack(card["item"])]
			var full: bool = p.item_room(card["item"]) != ""
			if p.item_room(card["item"]) == "belt":
				have = "belt full: left at your feet"
			draw_string(font, Vector2(r.position.x, r.end.y - 34.0), have, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 13, Color(1.0, 0.5, 0.4) if full else DIM_TEXT)
		draw_string(font, Vector2(r.position.x, r.end.y - 14.0), _card_hint(i), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 15, GOLD)


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
	# A gilt outline with a soft glow round it.
	var loop := UI.rounded(r.grow(3.0), 8.0)
	loop.append(loop[0])
	draw_polyline(loop, Color(UI.GILT, 0.22), 6.0, true)
	draw_polyline(loop, Color(UI.GILT_HI, 0.95), 2.0, true)


## Under a card: how to take it.
func _card_hint(i: int) -> String:
	if main.touch_active:
		return "Tap"
	if main.pad_active:
		return Controls.pad_text("Press {a}", main.pad_ps) if _card_focused(i) else ""
	if i >= main.CARD_KEYS:
		return "Press Enter" if _card_focused(i) else ""
	return "Press %d%s" % [i + 1, " or Enter" if _card_focused(i) else ""]
