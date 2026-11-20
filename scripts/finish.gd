extends Node2D
## The screen's finishing pass: one full-screen draw over the world (above
## the darkness and its glow, under world text and the HUD) that grades the
## picture the way a painter would finish it:
##   * a gentle contrast and saturation lift, so the code-drawn colours
##     read rich instead of flat under the tower's dim light;
##   * each tower's own grade (palette.gd TOWER_GRADE): its tint lifted
##     into the shadows and a warmth or coolness in the light;
##   * on High, bloom: bright things (torch flames, essence, spells, the
##     open stair) bleed a soft halo into the dark, read from two blurred
##     levels of the screen in the same pass.
## Settings -> Lighting: Low has none of it (no extra pass at all), Medium
## grades (one screen copy and one cheap pass), High grades and blooms.
## It reads the screen (hint_screen_texture), which the Compatibility
## renderer supports on desktop, the web and phones.

const Palette := preload("res://scripts/palette.gd")

const SHADER := """
shader_type canvas_item;
render_mode unshaded;
{DEFINES}
#ifdef BLOOM
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform float bloom = 0.5;
uniform float bloom_cut = 0.66;  // only what's brighter than this glows (flames, essence, spells), not a lit floor
#else
uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
#endif
uniform vec3 lift = vec3(0.0);  // the tower's tint lifted into the shadows
uniform vec3 gain = vec3(1.0);  // and its warmth or coolness in the light
uniform float contrast = 1.1;
uniform float saturation = 1.1;
uniform float pivot = 0.22;  // contrast turns round this brightness (a dark game)

void fragment() {
	vec3 c = textureLod(screen_tex, SCREEN_UV, 0.0).rgb;
#ifdef BLOOM
	vec3 b1 = textureLod(screen_tex, SCREEN_UV, 2.5).rgb;
	vec3 b2 = textureLod(screen_tex, SCREEN_UV, 4.5).rgb;
	float l1 = max(max(b1.r, b1.g), b1.b);
	float l2 = max(max(b2.r, b2.g), b2.b);
	vec3 hot = b1 * (max(l1 - bloom_cut, 0.0) / max(l1, 0.001)) * 0.8 + b2 * (max(l2 - bloom_cut * 0.8, 0.0) / max(l2, 0.001)) * 1.1;
	c += hot * bloom;
#endif
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, saturation);
	c = (c - pivot) * contrast + pivot;
	c = c * gain + lift * (1.0 - clamp(c, 0.0, 1.0));
	COLOR = vec4(clamp(c, 0.0, 1.0), 1.0);
}
"""

## How strong each Lighting level's finish is (Low: off).
const LEVELS := {
	"low": {"on": false},
	"medium": {"on": true, "bloom": false, "contrast": 1.08, "saturation": 1.08},
	"high": {"on": true, "bloom": true, "contrast": 1.1, "saturation": 1.1, "bloom_k": 0.55},
}

var half := Vector2(800, 500)  # the rect's half size (lighting.gd keeps it covering the screen)
var _plain: Shader
var _bloom: Shader
var mat := ShaderMaterial.new()
var level := "medium"


func _ready() -> void:
	z_index = 42  # over the darkness (40) and its glow (41)
	z_as_relative = false
	_plain = Shader.new()
	_plain.code = SHADER.replace("{DEFINES}", "")
	_bloom = Shader.new()
	_bloom.code = SHADER.replace("{DEFINES}", "#define BLOOM")
	mat.shader = _plain
	material = mat
	set_tower("kraken")


func set_level(q: String) -> void:
	level = q if LEVELS.has(q) else "medium"
	var lv: Dictionary = LEVELS[level]
	visible = bool(lv["on"])
	if not visible:
		return
	mat.shader = _bloom if bool(lv.get("bloom", false)) else _plain
	mat.set_shader_parameter("contrast", float(lv["contrast"]))
	mat.set_shader_parameter("saturation", float(lv["saturation"]))
	if lv.has("bloom_k"):
		mat.set_shader_parameter("bloom", float(lv["bloom_k"]))
	set_tower(_tower)


var _tower := "kraken"


func set_tower(tower: String) -> void:
	_tower = tower
	var g: Array = Palette.TOWER_GRADE.get(tower, Palette.TOWER_GRADE["other"])
	var lf: Color = g[0]
	var gn: Color = g[1]
	mat.set_shader_parameter("lift", Vector3(lf.r, lf.g, lf.b))
	mat.set_shader_parameter("gain", Vector3(gn.r, gn.g, gn.b))


func set_half(h: Vector2) -> void:
	if not h.is_equal_approx(half):
		half = h
		queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(-half, half * 2.0), Color.WHITE)
