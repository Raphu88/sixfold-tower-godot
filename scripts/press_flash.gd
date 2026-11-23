extends Control
## A short flash on the button or card just pressed, when something was
## bought, sold, chosen, equipped or learned (menu.gd feedback): a flat
## rounded light in a UI colour that fades in a blink (TIME). It's drawn
## over the page (which is often built again under it, its scroll kept, so
## the new button sits where the old one was), never takes a click, and is
## kept to a single flash at a time.

const UI := preload("res://scripts/ui.gd")

const TIME := 0.32  # seconds
const GROW := 4.0  # px it swells by as it fades

var rect := Rect2()
var col := Color.WHITE
var t := 0.0  # time left
var flashes := 0  # how many it has shown (tests)


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


## Flashes `r` (a global rect) in `c`.
func flash(r: Rect2, c: Color) -> void:
	if r.size.x < 2.0 or r.size.y < 2.0:
		return
	rect = Rect2(get_global_transform().affine_inverse() * r.position, r.size)
	col = c
	t = TIME
	flashes += 1
	queue_redraw()


func active() -> bool:
	return t > 0.0


func _process(delta: float) -> void:
	if t > 0.0:
		t = maxf(0.0, t - delta)
		queue_redraw()


func _draw() -> void:
	if t <= 0.0:
		return
	var k := t / TIME  # 1 -> 0
	var e := k * k
	var r := rect.grow(GROW * (1.0 - k))
	var st := StyleBoxFlat.new()
	st.bg_color = Color(col, 0.34 * e)
	st.border_color = Color(col, 0.95 * e)
	st.set_border_width_all(2)
	st.set_corner_radius_all(7)
	st.anti_aliasing = true
	draw_style_box(st, r)
