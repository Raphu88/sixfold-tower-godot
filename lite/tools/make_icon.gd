extends SceneTree
## Draws Six Towers LITE's icon (icon.png: the home screen's app icon and the
## loading screen) with the game's own drawings: a tower in the night with
## the Gryphon in its round window, and a mark glowing over it. Run from the
## lite folder:
##   xvfb-run -a godot --rendering-driver opengl3 -s tools/make_icon.gd

const Art := preload("res://scripts/art.gd")
const Data := preload("res://scripts/data.gd")
const SIZE := 512


func _init() -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var n := Node2D.new()
	n.draw.connect(_draw_icon.bind(n))
	vp.add_child(n)
	root.add_child(vp)
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	vp.get_texture().get_image().save_png("res://icon.png")
	print("icon.png saved")
	quit()


func _draw_icon(c: Node2D) -> void:
	var s := float(SIZE)
	c.draw_rect(Rect2(0, 0, s, s), Color(0.09, 0.08, 0.16))
	for k in 30:
		c.draw_circle(Vector2(fmod(k * 137.0, s), fmod(k * 71.0, s * 0.6)), 3.0, Color(1, 1, 1, 0.5))
	var col := Data.tower_color("gryphon")
	var stone: Color = Data.TOWERS["gryphon"]["floor"]
	Art.glow(c, Vector2(s / 2, s * 0.55), s * 0.5, col, 1.2)
	var body := Rect2(s * 0.24, s * 0.22, s * 0.52, s * 0.78)
	c.draw_rect(body.grow(8), Art.OUT)
	c.draw_rect(body, stone)
	c.draw_rect(Rect2(body.position, Vector2(body.size.x * 0.25, body.size.y)), stone.lightened(0.1))
	var bw := body.size.x / 5.0
	for k in 3:
		var b := Rect2(body.position + Vector2(bw * 2.0 * k, -bw), Vector2(bw, bw))
		c.draw_rect(b.grow(8), Art.OUT)
		c.draw_rect(b, stone)
	var face := Vector2(s / 2, s * 0.6)
	var fr := s * 0.2
	c.draw_circle(face, fr + 8, Art.OUT)
	c.draw_circle(face, fr, col.darkened(0.55))
	Art.beast(c, face + Vector2(0, fr * 0.75), "gryphon", 0.6, 0.0, 0.0, false, fr / 85.0)
	Art.glow(c, Vector2(s / 2, s * 0.13), 70, Color(1.0, 0.85, 0.4), 1.6)
	Art.star(c, Vector2(s / 2, s * 0.13), 34, Color(1.0, 0.85, 0.35))
