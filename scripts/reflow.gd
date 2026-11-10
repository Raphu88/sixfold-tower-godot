extends RefCounted
## Fits a page built for a wider screen into a narrower one (a phone at a
## big Interface size: ui.gd UI_SIZES), without each page knowing about it.
##
## fit(node, width) walks the page from the top: a row (an HBoxContainer)
## wider than the room becomes a row that wraps (an HFlowContainer with the
## same children, spacing and alignment), so what doesn't fit moves to the
## next line; a grid wider than the room loses columns until it fits. Inside
## a panel or a column it goes on with the room less the panel's margins.
## The page's own scroll then takes the extra height (menu.gd, the train's
## cars: train_page.gd).
##
## Only what is too wide changes, so on a computer (or a phone at a small
## size) every page stays exactly as it was built.

## The gap between wrapped lines.
const LINE_GAP := 6
## A row's grids may grow (losing columns) to this share of the height.
const GRIDS_H := 0.8


## Makes `node`'s contents fit `width` (view px) across. A row first tries
## its grids with fewer columns (if it then stays under `height`: the
## pieces stay side by side), and only then wraps. True if anything changed.
static func fit(node: Control, width: float, height := INF) -> bool:
	var changed := false
	for c in node.get_children():
		if c is Control and c.visible and not c.is_queued_for_deletion():
			changed = _fit_node(c, width, height) or changed
	return changed


static func _fit_node(ctl: Control, width: float, height: float) -> bool:
	if ctl.get_combined_minimum_size().x <= width + 0.5:
		return false
	if ctl is ScrollContainer and ctl.horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
		return false  # (it scrolls across: it fits itself)
	if ctl is HBoxContainer and ctl.get_child_count() > 1:
		if _narrow_grids(ctl, width, height):
			return true
		var f := _wrap(ctl)
		for k in f.get_children():
			if k is Control and k.visible:
				_fit_node(k, width, height)
		return true
	if ctl is GridContainer and ctl.columns > 1:
		var g: GridContainer = ctl
		while g.columns > 1 and g.get_combined_minimum_size().x > width + 0.5:
			g.columns -= 1
		for k in g.get_children():
			if k is Control and k.visible:
				_fit_node(k, width / g.columns, height)
		return true
	# A panel or a column: the room less its own margins.
	var widest := 0.0
	for k in ctl.get_children():
		if k is Control and k.visible:
			widest = maxf(widest, k.get_combined_minimum_size().x)
	return fit(ctl, width - maxf(ctl.get_combined_minimum_size().x - widest, 0.0), height)


## Takes columns off the grids in a row (the widest first) until the row
## fits across, as long as the grids together stay under GRIDS_H of
## `height` (their own heights: a wrapping label's isn't known till it's laid
## out). False (and the grids as they were) if that can't make it fit.
static func _narrow_grids(row: Control, width: float, height: float) -> bool:
	var grids: Array = row.find_children("*", "GridContainer", true, false).filter(func(g): return g.is_visible_in_tree() and g.columns > 1)
	if grids.is_empty():
		return false
	var was: Array = grids.map(func(g): return g.columns)
	while row.get_combined_minimum_size().x > width + 0.5:
		var best: GridContainer = null
		for g in grids:
			if g.columns > 1 and (best == null or g.get_combined_minimum_size().x > best.get_combined_minimum_size().x):
				best = g
		if best == null:
			break
		best.columns -= 1
		if _grids_h(grids) > height * GRIDS_H:
			break
	if row.get_combined_minimum_size().x <= width + 0.5 and _grids_h(grids) <= height * GRIDS_H:
		return true
	for i in grids.size():
		grids[i].columns = was[i]
	return false


## Swaps a row for a row that wraps, keeping its children, place, sizing,
## spacing, alignment and metadata. Returns the new row.
static func _wrap(row: HBoxContainer) -> HFlowContainer:
	var f := HFlowContainer.new()
	f.name = row.name
	f.size_flags_horizontal = row.size_flags_horizontal
	f.size_flags_vertical = row.size_flags_vertical
	f.size_flags_stretch_ratio = row.size_flags_stretch_ratio
	f.custom_minimum_size = Vector2(0.0, row.custom_minimum_size.y)
	f.mouse_filter = row.mouse_filter
	f.alignment = row.alignment as FlowContainer.AlignmentMode
	f.add_theme_constant_override("h_separation", row.get_theme_constant("separation"))
	f.add_theme_constant_override("v_separation", LINE_GAP)
	for m in row.get_meta_list():
		f.set_meta(m, row.get_meta(m))
	f.set_meta("reflowed", true)
	var parent := row.get_parent()
	var at := row.get_index()
	parent.add_child(f)
	parent.move_child(f, at)
	for k in row.get_children():
		row.remove_child(k)
		f.add_child(k)
	parent.remove_child(row)
	row.queue_free()
	return f


static func _grids_h(grids: Array) -> float:
	var t := 0.0
	for g in grids:
		t += g.get_combined_minimum_size().y
	return t
