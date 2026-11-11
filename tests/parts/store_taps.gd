extends RefCounted
## The Outfitter's Car on a phone: a finger tap on every shelf item, rack
## piece, today's piece and (selling) every pack and stash piece shows its
## card at once, and the game keeps running (the owner saw a freeze when
## tapping some icons; these pin it down if it comes back).

const Gear := preload("res://scripts/gear.gd")
const Train := preload("res://scripts/train.gd")

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
	for store in ["shop", "sell"]:
		menu.train_car = "store"
		menu.train_store = store
		menu.inv_sel = ""
		menu.open("train")
		await t._frames(4)
		var keys: Array = []
		for b in t._all_buttons(menu.train_page.roots["store"]):
			var k := String(b.get_meta("slot", ""))
			if k != "" and not keys.has(k):
				keys.append(k)
		var missed: Array = []
		var slow: Array = []
		for k in keys:
			var btn = null
			for b in t._all_buttons(menu.train_page.roots["store"]):
				if String(b.get_meta("slot", "")) == k and b.is_visible_in_tree():
					btn = b
			if btn == null:
				missed.append(k)
				continue
			var pane = menu.train_page.car_scrolls.get("store")
			if pane != null:
				pane.ensure_control_visible(btn)
				await t._frames(2)
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
		t._check(keys.size() > (20 if store == "shop" else 10) and missed.is_empty(), "a tap on every %s slot shows its card (%d slots; missed %s)" % [store, keys.size(), missed])
		t._check(slow.is_empty(), "...each at once (%s)" % [slow])
	main.touch._set_active(false)
	main.apply_view_scale()
	t.root.size = was
	menu.close()
	t.paused = false
	main.on_train = false
	await t._frames(2)
