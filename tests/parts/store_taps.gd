extends RefCounted
## The Outfitter's Car on a phone: a finger tap on every shelf item, rail
## piece, charm, today's piece, every pack and stash piece in the Sell
## section, and every node of the upgrade tree shows its card at once, and
## the game keeps running (the owner saw a freeze when tapping some icons;
## these pin it down if it comes back). At a phone's size the goods are a
## list that scrolls (store_page.gd): every row is scrolled into view and
## tapped, at the first rank and at the top rank, and the tree is tapped in
## its own view. (Before the one-page store this tapped the shelf's and the
## rail's pages in turn.)

const Gear := preload("res://scripts/gear.gd")
const Train := preload("res://scripts/train.gd")
const Renown := preload("res://scripts/renown.gd")

var t


func run(smoke) -> void:
	t = smoke
	print("the store, tapped on a phone")
	await t._fresh_main()
	var main = t.main
	var menu = main.menu
	var prof = main.profile
	for k in ["air", "water", "iron", "fire", "stone", "blade"]:
		prof.add_crystal(k, 500.0)
	var names: Array = Gear.NAMED.keys()
	for i in 12:
		var d: Dictionary = Gear.NAMED[names[i % names.size()]]
		prof.chest.append(Gear.make(d["base"], d["rarity"], [], 0, names[i % names.size()]))
	for i in 2:
		prof.pack.append(Gear.make("sword", "fine"))
	main.open_train()
	await t._frames(3)
	var was: Vector2i = t.root.size
	t.root.size = Vector2i(915, 412)
	main.touch._set_active(true)
	main.apply_view_scale()
	for which in ["shop", "top", "tree"]:
		if which != "shop" and Renown.rank(prof) < Renown.RANKS.size() - 1:
			# (the top rank: the longest rail, the fullest shelf, a title's line)
			Renown.earn(prof, Renown.needed(Renown.RANKS.size() - 1), "")
			Renown.state(prof)["titles"] = ["contender"]
			Renown.state(prof)["worn"] = "contender"
			prof.store = {}
			Train.stock(prof)
		menu.train_car = "store"
		menu.train_store = "tree" if which == "tree" else "shop"
		menu.inv_sel = ""
		menu.open("train")
		await t._frames(4)
		var listed: bool = menu.train_page.store.listed
		if which != "tree":
			t._check(listed and menu.train_page.store.goods_scroll != null, "on a phone the %s store's goods are a list that scrolls" % which)
		var keys: Array = []
		for b in t._all_buttons(menu.train_page.roots["store"]):
			var k := String(b.get_meta("slot", ""))
			if k != "" and not keys.has(k):
				keys.append(k)
		var missed: Array = []
		var slow: Array = []
		for k in keys:
			var btn = _button(menu, k)
			if btn == null:
				missed.append(k)
				continue
			await _reveal(menu, btn)
			var at: Vector2 = btn.get_global_transform_with_canvas() * (btn.size / 2.0)
			var t0 := Time.get_ticks_msec()
			t._touch(0, at, true)
			await t._frames(2)
			t._touch(0, at, false)
			await t._frames(3)
			if menu.inv_sel != k:
				missed.append(k)
			if Time.get_ticks_msec() - t0 > 2000:
				slow.append(k)
		var least: int = {"shop": 14, "top": 30, "tree": 25}[which]
		t._check(keys.size() >= least and missed.is_empty(), "a tap on every %s slot shows its card (%d slots; missed %s)" % [which, keys.size(), missed])
		t._check(slow.is_empty(), "...each at once (%s)" % [slow])
		if which == "top":
			# A row far down the list is bought by taps alone: its row, then Buy.
			var rail: Array = keys.filter(func(k): return String(k).begins_with("outfit:") and not Train.outfit(prof)[int(String(k).get_slice(":", 1))].is_empty())
			var key: String = rail.back() if not rail.is_empty() else ""
			var before: int = prof.pack.size() + prof.chest.size()
			var row = _button(menu, key)
			if row != null:
				await _reveal(menu, row)
				await t._tap_at(row.get_global_transform_with_canvas() * (row.size / 2.0))
				await t._frames(3)
			var chosen: String = menu.inv_sel
			var buy = null
			for b in t._all_buttons(menu.train_page.roots["store"]):
				if b.is_visible_in_tree() and String(b.get_meta("buy", "")) == key + ":chest":
					buy = b
			var found: bool = buy != null and not buy.disabled
			if found:
				menu.train_page.reveal_card()
				var sc = menu.train_page.card_scrolls.get("store")
				if sc != null:
					sc.ensure_control_visible(buy)
				await t._frames(3)
				await t._tap_at(buy.get_global_transform_with_canvas() * (buy.size / 2.0))  # (the card is built again: this button is gone after)
				await t._frames(3)
			t._check(key != "" and chosen == key and found and prof.pack.size() + prof.chest.size() == before + 1 and Train.outfit(prof)[int(key.get_slice(":", 1))].is_empty(),
				"on a phone, the last rail row (%s) is chosen (%s) and bought into the stash by taps (its Buy: %s)" % [key, chosen, "found" if found else "missing or off"])
	main.touch._set_active(false)
	main.apply_view_scale()
	t.root.size = was
	menu.train_store = "shop"
	menu.close()
	t.paused = false
	main.on_train = false
	await t._frames(2)


func _button(menu, k: String):
	var btn = null
	for b in t._all_buttons(menu.train_page.roots["store"]):
		if String(b.get_meta("slot", "")) == k and b.is_visible_in_tree():
			btn = b
	return btn


## Scrolls every box a button sits in (the goods' list, the tree, the car) so it shows.
func _reveal(menu, btn: Control) -> void:
	for pass_n in 2:
		var p: Node = btn.get_parent()
		while p != null and p != menu.train_view:
			if p is ScrollContainer:
				p.ensure_control_visible(btn)
			p = p.get_parent()
		await t._frames(2)
