extends RefCounted
# TEMPORARY debug.

var t


func run(smoke) -> void:
	t = smoke
	await t._fresh_main()
	var main = t.main
	t.paused = false
	main.touch._set_active(false)
	main.grant_test_bonds()
	t.root.size = Vector2i(1280, 720)
	main.apply_view_scale()
	main.open_train()
	await t._frames(3)
	var menu = main.menu
	var h = menu.helper
	await t._wait(0.8)
	print("DBG pos=", h.pos, " rest=", h.rest, " active=", h.active())
	var orig = menu.get_script()
	t._mouse_button(h.pos, MOUSE_BUTTON_LEFT, true)
	await t._frames(2)
	print("DBG eaten=", h._mouse_eaten, " page=", menu.page, " mouse=", h.get_local_mouse_position(), " vp=", menu.get_viewport().get_mouse_position())
	t._mouse_button(h.pos, MOUSE_BUTTON_LEFT, false)
	await t._frames(2)
	print("DBG page=", menu.page)
	menu.close()
	main.on_train = false
