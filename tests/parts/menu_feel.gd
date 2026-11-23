extends RefCounted
## How the menus feel (scroller.gd, confirm_pop.gd, press_flash.gd, menu.gd
## open / feedback / ask):
##   - a page built again after a press keeps its scroll: the Library page
##     (a tap on a phone, and Enter with the keys, the focus kept) and the
##     Outfitter's list on the train (a tap);
##   - buying, selling and choosing play their sound and flash the button;
##   - a former two-press action opens the pop-up: Cancel does nothing,
##     Esc closes it, Confirm does it; the focus starts on Cancel; it fits
##     an 800x400 screen;
##   - the wheel moves further a notch than Godot's own; a finger drag
##     follows the finger (fractions of a pixel kept) and presses nothing;
##     a flick glides on; Page Down jumps.
## Run by smoke_test.gd (_part_tests).

const Scroller := preload("res://scripts/scroller.gd")
const Guide := preload("res://scripts/guide.gd")
const Entity := preload("res://scripts/entity.gd")
const G := preload("res://scripts/gear.gd")
const Essence := preload("res://scripts/essence.gd")

var t
var main
var menu
var was_size: Vector2i


func run(smoke) -> void:
	t = smoke
	print("the menus' feel: the scroll kept, answers, asking first, fast scrolling")
	await t._fresh_main()
	main = t.main
	menu = main.menu
	main.profile.saving = false
	main.grant_test_bonds()
	main.profile.regarded = true
	main.first_climb = false
	was_size = t.root.size
	# Every Archive entry met, so the Library is long enough to scroll.
	Guide.load_state()
	var known: Dictionary = Guide.state["known"].duplicate()
	for id in Entity.TIPS:
		Guide.state["known"][id] = true
	await _library_kept()
	await _wheel_and_drag()
	Guide.state["known"] = known
	await _train_kept()
	await _answers_and_asking()
	await _start_over_pop()
	main.touch._set_active(false)
	main.apply_view_scale()
	t.root.size = was_size
	menu.close()
	await t._frames(2)


func _check(cond: bool, what: String) -> void:
	t._check(cond, what)


func _phone(on: bool) -> void:
	t.root.size = Vector2i(844, 390) if on else was_size
	main.touch._set_active(on)
	main.apply_view_scale()


## A button with `meta` wholly inside a scroll's view (the nearest the middle).
func _shown(sc: ScrollContainer, meta: String) -> Button:
	var view := sc.get_global_rect()
	var best: Button = null
	var best_d := INF
	for b in t._all_buttons(sc):
		if not b.has_meta(meta) or b.is_queued_for_deletion() or not b.is_visible_in_tree() or b.disabled:
			continue
		var r: Rect2 = b.get_global_rect()
		if not view.grow(-2.0).encloses(r):
			continue
		var d := absf(r.get_center().y - view.get_center().y)
		if d < best_d:
			best_d = d
			best = b
	return best


func _drag_by(pos: Vector2, rel: Vector2) -> void:
	var ev := InputEventScreenDrag.new()
	ev.index = 0
	ev.position = t._to_window(pos)
	ev.relative = t.root.get_final_transform().basis_xform(rel)
	Input.parse_input_event(ev)


# --- the scroll kept ----------------------------------------------------------------

func _library_kept() -> void:
	_phone(true)
	menu.archive_open = ""
	menu.open_archive()
	await t._frames(4)
	var sc: ScrollContainer = menu.scroll
	_check(Scroller.can_scroll(sc), "the Library page scrolls on a phone (%d to scroll)" % int(Scroller.top(sc)))
	sc.scroll_vertical = int(Scroller.top(sc) * 0.5)
	await t._frames(2)
	var at: int = sc.scroll_vertical
	var b := _shown(sc, "archive")
	var id: String = String(b.get_meta("archive")) if b != null else ""
	if b != null:
		await t._tap_at(b.get_global_rect().get_center())
	await t._frames(6)
	_check(id != "" and menu.archive_open == id and at > 0 and absi(sc.scroll_vertical - at) <= 2,
		"a tap on an Archive entry in the scrolled Library opens it where you were (scroll %d, was %d)" % [sc.scroll_vertical, at])
	# The keys: Enter on the open entry closes it, the page and the focus stay put.
	_phone(false)
	menu.archive_open = ""
	menu.open_archive()
	await t._frames(4)
	sc.scroll_vertical = int(Scroller.top(sc) * 0.5)
	await t._frames(2)
	at = sc.scroll_vertical
	b = _shown(sc, "archive")
	id = String(b.get_meta("archive")) if b != null else ""
	if b != null:
		b.grab_focus()
		await t._frames(2)
		at = sc.scroll_vertical
		await t._key_tap(KEY_ENTER)
		await t._frames(6)
	var f: Control = t._focus_now()
	_check(id != "" and menu.archive_open == id and absi(sc.scroll_vertical - at) <= 2 and f != null and f.get_meta("archive", "") == id,
		"Enter on an entry: the page stays where it was (scroll %d, was %d) and the focus on the entry" % [sc.scroll_vertical, at])
	# Another tab starts at its top.
	menu._set_library_tab("bestiary")
	await t._frames(3)
	_check(sc.scroll_vertical == 0, "another tab starts at its top")
	menu.library_tab = "archive"
	menu.archive_open = ""


func _train_kept() -> void:
	_phone(true)
	var prof = main.profile
	for k in Essence.KINDS:
		prof.add_crystal(k, 400.0)
	main.await_tower()
	main.open_train()
	await t._frames(3)
	menu.train_car = "store"
	menu.train_store = "shop"
	menu.inv_sel = ""
	menu.open("train")
	await t._frames(6)
	var sc: ScrollContainer = menu.train_page.store.goods_scroll
	var ok: bool = sc != null and is_instance_valid(sc) and Scroller.can_scroll(sc)
	_check(ok, "on a phone the Outfitter's goods are a list that scrolls")
	if not ok:
		return
	sc.scroll_vertical = int(Scroller.top(sc) * 0.6)
	await t._frames(2)
	var at: int = sc.scroll_vertical
	var b := _shown(sc, "slot")
	var key: String = String(b.get_meta("slot")) if b != null else ""
	if b != null:
		await t._tap_at(b.get_global_rect().get_center())
	await t._frames(6)
	var sc2: ScrollContainer = menu.train_page.store.goods_scroll
	_check(key != "" and menu.inv_sel == key and sc2 != null and is_instance_valid(sc2) and at > 0 and absi(sc2.scroll_vertical - at) <= 2,
		"a tap on a piece in the scrolled list shows its card, the list where it was (scroll %d, was %d)" % [sc2.scroll_vertical if sc2 != null else -1, at])


# --- answers and asking first ------------------------------------------------------------

func _answers_and_asking() -> void:
	_phone(false)
	var prof = main.profile
	var audio = main.audio
	# Buy: coins and a flash.
	menu.train_car = "store"
	menu.train_store = "shop"
	menu.inv_sel = "supply:draught"
	menu.open("train")
	await t._frames(3)
	var buys: Array = t._all_buttons(menu.train_page.roots["store"]).filter(func(b): return b.has_meta("buy") and not b.disabled and b.is_visible_in_tree())
	var t0 := Time.get_ticks_msec()
	var log0: int = menu.feedback_log.size()
	var fl0: int = menu.flash.flashes
	if not buys.is_empty():
		buys[0].grab_focus()
		buys[0].pressed.emit()
	await t._frames(1)
	_check(not buys.is_empty() and menu.feedback_log.slice(log0).has("buy") and menu.flash.flashes > fl0 and int(audio.last_played.get("buy", -1)) >= t0,
		"buying plays the coins and flashes the button")
	# Sell: the pop-up first; Cancel sells nothing; Confirm sells, with coins and a flash.
	prof.pack = [G.make("leather_cap")]
	menu.inv_sel = "pack:0"
	menu.open("train")
	await t._frames(3)
	var sell: Array = t._car_buttons("sell", "pack:0")
	if sell.size() == 1:
		sell[0].grab_focus()
		sell[0].pressed.emit()
	await t._frames(2)
	_check(sell.size() == 1 and menu.asking() and prof.pack.size() == 1, "Sell asks first: the confirmation pop-up")
	_check(menu.asking() and t._focus_now() == menu.pop.no, "...the keys start on Cancel")
	await t._confirm(false)
	await t._frames(1)
	_check(not menu.asking() and prof.pack.size() == 1, "...Cancel sells nothing")
	sell = t._car_buttons("sell", "pack:0")
	if sell.size() == 1:
		sell[0].pressed.emit()
	await t._frames(2)
	await t._key_tap(KEY_ESCAPE)
	_check(not menu.asking() and prof.pack.size() == 1 and menu.page == "train", "...Esc closes it, nothing sold, still on the train")
	sell = t._car_buttons("sell", "pack:0")
	if sell.size() == 1:
		sell[0].pressed.emit()
	await t._frames(2)
	t0 = Time.get_ticks_msec()
	log0 = menu.feedback_log.size()
	fl0 = menu.flash.flashes
	await t._confirm(true)
	_check(prof.pack.is_empty() and menu.feedback_log.slice(log0).has("sell") and menu.flash.flashes > fl0 and int(audio.last_played.get("sell", -1)) >= t0,
		"...Confirm sells it, with the coins and a flash")
	# Choose: wearing a piece from the stash answers with its sound and a flash.
	prof.chest = [G.make("leather_cap")]
	menu.train_car = "personal"
	menu.inv_sel = "chest:0"
	menu.open("train")
	await t._frames(3)
	var eq: Array = t._all_buttons(menu.train_page.roots["personal"]).filter(func(b): return String(b.get_meta("equip", "")).begins_with("chest:0") and b.is_visible_in_tree())
	log0 = menu.feedback_log.size()
	fl0 = menu.flash.flashes
	if not eq.is_empty():
		eq[0].pressed.emit()
	await t._frames(1)
	_check(not eq.is_empty() and menu.feedback_log.slice(log0).has("choose") and menu.flash.flashes > fl0, "wearing a piece is a choice: its sound and a flash")
	t0 = Time.get_ticks_msec()
	await t._wait(0.2)  # (the sound bank won't stack one sound too close)
	menu.feedback("choose")
	_check(int(audio.last_played.get(String(menu.FEEDBACK["choose"]["sound"]), -1)) > t0 and menu.FEEDBACK["choose"]["sound"] != menu.FEEDBACK["buy"]["sound"], "a choice has its own softer sound (%s), not the coins" % menu.FEEDBACK["choose"]["sound"])


func _start_over_pop() -> void:
	# An 800x400 phone: the pop-up fits, its buttons big enough for a thumb.
	t.root.size = Vector2i(800, 400)
	main.touch._set_active(true)
	main.apply_view_scale()
	menu.train_car = "settings"
	menu.open("train")
	await t._frames(4)
	var brake: Array = t._car_buttons("over", true)
	if not brake.is_empty():
		brake[0].pressed.emit()
	await t._frames(3)
	var view: Rect2 = t.root.get_visible_rect()
	var card: Rect2 = menu.pop.card.get_global_rect()
	_check(menu.asking() and view.encloses(card) and menu.pop.yes.size.y >= 40.0 and menu.pop.no.size.y >= 40.0,
		"Start over asks in the pop-up, which fits an 800x400 phone (%s in %s)" % [card, view])
	if menu.asking():
		await t._tap_at(Vector2(view.position.x + 4.0, view.position.y + 4.0))  # (a tap outside the card)
		await t._frames(2)
	_check(not menu.asking() and main.profile.regarded and not main.profile.bonds.is_empty(), "a tap outside it cancels: nothing lost")


# --- fast scrolling ------------------------------------------------------------------------

func _wheel_and_drag() -> void:
	_phone(false)
	menu.archive_open = ""
	menu.open_archive()
	await t._frames(4)
	var sc: ScrollContainer = menu.scroll
	sc.scroll_vertical = 0
	await t._frames(2)
	var step: float = Scroller.wheel_step(sc)
	_check(step > sc.size.y * Scroller.GODOT_WHEEL_SHARE * 1.5 and step >= Scroller.WHEEL_STEP, "a notch of the wheel moves %d px (Godot's own: %d)" % [int(step), int(sc.size.y * Scroller.GODOT_WHEEL_SHARE)])
	var at := sc.get_global_rect().get_center()
	t._mouse_button(at, MOUSE_BUTTON_WHEEL_DOWN, true)
	await t._frames(1)
	t._mouse_button(at, MOUSE_BUTTON_WHEEL_DOWN, false)
	await t._wait(0.35)
	var want := minf(step, Scroller.top(sc))
	_check(absf(sc.scroll_vertical - want) <= 2.0, "...and it does, eased (%d of %d)" % [sc.scroll_vertical, int(want)])
	var y0: int = sc.scroll_vertical
	await t._key_tap(KEY_PAGEDOWN)
	await t._wait(0.35)
	_check(sc.scroll_vertical >= mini(int(Scroller.top(sc)), y0 + int(sc.size.y * 0.5)), "Page Down jumps most of a view (%d from %d)" % [sc.scroll_vertical, y0])
	# A finger on a phone: it follows the finger, fractions of a pixel kept.
	_phone(true)
	await t._frames(3)
	sc.scroll_vertical = int(Scroller.top(sc) * 0.3)
	await t._frames(2)
	var start: int = sc.scroll_vertical
	var b := _shown(sc, "archive")
	var p: Vector2 = b.get_global_rect().get_center() if b != null else sc.get_global_rect().get_center()
	t._touch(0, p, true)
	await t._frames(1)
	for i in 80:
		p.y -= 0.5
		_drag_by(p, Vector2(0, -0.5))
		await t._frames(1)
	var moved: int = sc.scroll_vertical - start
	_check(moved >= 40 - int(Scroller.DRAG) - 3 and moved <= 40 + 2, "a slow drag follows the finger (%d px for 40, after the %d px before a drag starts)" % [moved, int(Scroller.DRAG)])
	t._touch(0, p, false)
	await t._frames(3)
	_check(menu.archive_open == "", "...and letting go presses nothing under the finger")
	# A flick glides on after the finger has gone.
	sc.scroll_vertical = int(Scroller.top(sc) * 0.2)
	await t._frames(2)
	p = sc.get_global_rect().get_center() + Vector2(0, sc.size.y * 0.3)
	t._touch(0, p, true)
	await t._frames(1)
	for i in 6:
		p.y -= 16.0
		_drag_by(p, Vector2(0, -16.0))
		await t._frames(1)
	var let_go: int = sc.scroll_vertical
	t._touch(0, p, false)
	await t._wait(0.4)
	_check(sc.scroll_vertical > let_go + 20 or sc.scroll_vertical >= int(Scroller.top(sc)) - 1, "a flick glides on once the finger lets go (%d, let go at %d)" % [sc.scroll_vertical, let_go])
	_phone(false)
