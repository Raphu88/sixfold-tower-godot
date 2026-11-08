extends Node2D
## The tower's darkness, as ONE layer over the world (like the web version's
## drawLight): a single rect the size of the screen, drawn with a shader
## that darkens everything in the tower's fog colour and cuts soft holes of
## light around every light on screen. The line-of-sight fog (fog.gd) is
## read from its tiny texture in the same pass, and a vignette is added.
##
## One draw call, whatever the number of lights, and no 2D light nodes at
## all (each of those made every lit thing draw again on a phone).
##
## Lights come from a simple registry: the climber's own glow, the room's
## torches, the stair, the cache, the campfire, puzzle eyes, burning floor,
## and short flashes (main.light_flash). Other code can add its own with
## add_light() / remove_light().
##
## Each light also adds a little coloured glow (additive) where it matters,
## so the eye goes to the open stair, lit eyes, the cache and the ward.

const Palette := preload("res://scripts/palette.gd")
const Essence := preload("res://scripts/essence.gd")

## Most lights sent to the shader in a frame (it loops over them per pixel).
const MAX_LIGHTS := 48
## Flashes alive at once (hits, parries, spells).
const MAX_FLASHES := 16
## Flashes are toned down (owner's request): this much as strong and as wide as asked.
const FLASH_ENERGY := 0.5
const FLASH_SIZE := 0.75
## A light_flash of size 1.0 lights this far (world pixels).
const FLASH_REACH := 128.0
## The climber's own light, and with Keen Eyes or Smokeborn.
const PLAYER_REACH := 330.0
const PLAYER_REACH_KEEN := 480.0
const TORCH_REACH := 230.0

const SHADER := """
shader_type canvas_item;
render_mode blend_premul_alpha, unshaded;

uniform sampler2D fog_tex : filter_linear, repeat_disable;
uniform bool fog_on = false;
uniform vec4 fog_rect = vec4(0.0, 0.0, 1.0, 1.0);  // world position and size of the fog grid
uniform vec4 dark_color = vec4(0.03, 0.03, 0.06, 0.8);  // the tower's fog colour; a = how dark unlit places are
uniform vec3 fog_color = vec3(0.015, 0.012, 0.03);  // places out of sight
uniform float vignette = 0.4;
uniform int light_count = 0;
uniform vec4 light_pos[48];  // x, y, reach, glow
uniform vec4 light_col[48];  // r, g, b, strength

varying vec2 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
}

void fragment() {
	float keep = 1.0;  // how much of the darkness is left here
	vec3 glow = vec3(0.0);
	for (int i = 0; i < 48; i++) {
		if (i >= light_count) {
			break;
		}
		vec4 lp = light_pos[i];
		vec2 d = world - lp.xy;
		float q = dot(d, d) / (lp.z * lp.z);
		if (q < 1.0) {
			// A wide bright middle with a soft edge (1 at the centre, ~0.9
			// halfway, ~0.45 at four fifths, 0 at the rim).
			float f = 1.0 - smoothstep(0.12, 1.0, q);
			vec4 lc = light_col[i];
			keep *= 1.0 - lc.a * f;
			glow += lc.rgb * (lp.w * f * f);
		}
	}
	float fog = 0.0;
	if (fog_on) {
		vec2 uv = (world - fog_rect.xy) / fog_rect.zw;
		if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
			fog = 1.0;
		} else {
			fog = texture(fog_tex, uv).r;
		}
	}
	float dark = dark_color.a * keep;
	vec2 v = (SCREEN_UV - 0.5) * 2.0;
	float vig = vignette * smoothstep(0.55, 1.45, length(v));
	float a = 1.0 - (1.0 - dark) * (1.0 - fog) * (1.0 - vig);
	// Out of sight reads as the fog's own near-black; elsewhere the tower's colour.
	vec3 col = mix(dark_color.rgb, fog_color, clamp(fog / max(a, 0.001), 0.0, 1.0));
	COLOR = vec4(col * a + glow * (1.0 - fog), a);
}
"""

var main
var mat: ShaderMaterial
var lights := {}  # id -> {pos, r, color, k, glow, node, offset}: added by other code
var flashes: Array = []  # {pos, r, color, k, t, dur}
var _next_id := 1
var on_screen := 0  # lights sent to the shader last frame (the dev readout shows it)
var dark_color := Color(0.03, 0.03, 0.06, 0.8)
var _half := Vector2.ZERO  # half the drawn rect
var _pos := PackedColorArray()
var _col := PackedColorArray()


func _ready() -> void:
	z_index = 40  # over the floor, the monsters and the climber; world text and the HUD go above
	z_as_relative = false
	process_priority = 100  # after main has moved the camera this frame
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF  # moved every frame, with the camera
	var sh := Shader.new()
	sh.code = SHADER
	mat = ShaderMaterial.new()
	mat.shader = sh
	material = mat
	_pos.resize(MAX_LIGHTS)
	_col.resize(MAX_LIGHTS)
	set_tower_look("kraken")


## The tower's darkness colour (palette.gd) and how dark its unlit places are.
func set_tower_look(tower: String) -> void:
	dark_color = Palette.TOWER_FOG.get(tower, Palette.TOWER_FOG["kraken"])
	mat.set_shader_parameter("dark_color", dark_color)
	var fc: Color = Palette.FOG_UNSEEN
	mat.set_shader_parameter("fog_color", Vector3(fc.r, fc.g, fc.b))
	mat.set_shader_parameter("vignette", Palette.VIGNETTE)


# --- the registry ------------------------------------------------------------

## Adds a lasting light; returns its id (for move_light and remove_light).
## With `node` set, the light follows that node (plus `offset`) until it's freed.
func add_light(pos: Vector2, reach: float, color: Color, strength := 0.8, glow := 0.0, node: Node2D = null, offset := Vector2.ZERO) -> int:
	var id := _next_id
	_next_id += 1
	lights[id] = {"pos": pos, "r": reach, "color": color, "k": strength, "glow": glow, "node": node, "follows": node != null, "offset": offset}
	return id


func move_light(id: int, pos: Vector2) -> void:
	if lights.has(id):
		lights[id]["pos"] = pos


func remove_light(id: int) -> void:
	lights.erase(id)


func clear_lights() -> void:
	lights.clear()
	flashes.clear()


## A brief burst of light: lightning, parries, crits, burns. It fades out over `dur`.
func flash(pos: Vector2, color: Color, size := 1.5, energy := 1.6, dur := 0.25) -> void:
	if flashes.size() >= MAX_FLASHES:
		flashes.pop_front()  # the oldest gives way
	flashes.append({"pos": pos, "r": FLASH_REACH * size * FLASH_SIZE, "color": color,
		"k": clampf(energy * FLASH_ENERGY, 0.0, 1.0), "t": dur, "dur": maxf(dur, 0.01)})


## How far the climber's own light reaches (Keen Eyes and Smokeborn see farther).
func player_reach() -> float:
	var p = main.player if main != null else null
	if p != null and (p.has_bond("hunter") or p.has_bond("ashwalker")):
		return PLAYER_REACH_KEEN
	return PLAYER_REACH


# --- each frame ----------------------------------------------------------------

func _process(delta: float) -> void:
	for f in flashes:
		f["t"] -= delta
	if not flashes.is_empty():
		flashes = flashes.filter(func(f): return f["t"] > 0.0)
	if main == null or main.camera == null:
		return
	# Cover the screen (with room to spare for shake and the camera's glide).
	var cam: Camera2D = main.camera
	var view: Vector2 = get_viewport_rect().size / cam.zoom
	var half := view * 0.5 * 1.15 + Vector2(64, 64)
	if not half.is_equal_approx(_half):
		_half = half
		queue_redraw()
	var center := cam.get_screen_center_position() + cam.offset
	position = center
	_gather(Rect2(center - view * 0.5, view))
	_fog_params()


func _draw() -> void:
	draw_rect(Rect2(-_half, _half * 2.0), Color.WHITE)


func _fog_params() -> void:
	var fog = main.fog
	var on: bool = fog != null and fog.visible and fog.tex != null and fog.grid != Vector2i.ZERO
	mat.set_shader_parameter("fog_on", on)
	if on:
		mat.set_shader_parameter("fog_tex", fog.tex)
		var c: float = main.Floors.CELL
		mat.set_shader_parameter("fog_rect", Color(main.room.position.x, main.room.position.y, fog.grid.x * c, fog.grid.y * c))


## Every light that reaches the screen this frame, most important first.
func _gather(view: Rect2) -> void:
	var n := 0
	var t := Time.get_ticks_msec() * 0.001
	# The climber's own light (where the climber is drawn, between physics ticks).
	if main.player != null:
		var pp: Vector2 = main.cam_prev.lerp(main.cam_curr, Engine.get_physics_interpolation_fraction())
		var k := 0.5 if main.player.dead else 0.94
		n = _put(n, view, pp, player_reach(), Palette.PLAYER_LIGHT, k, 0.03)
	for f in flashes:
		var e: float = f["t"] / f["dur"]
		n = _put(n, view, f["pos"], f["r"], f["color"], f["k"] * e, 0.35 * f["k"] * e * e)
	# The stair: dim while sealed, bright and glowing once open; the ward glows violet.
	var rv = main.room_view
	if main.stair_open:
		n = _put(n, view, main.stair_pos, 190.0 + 10.0 * sin(t * 3.0), Palette.STAIR_LIGHT, 0.85, 0.22 + 0.06 * sin(t * 3.0))
	elif main.ward and main.layout_on:
		n = _put(n, view, main.stair_pos, 140.0, Palette.WARD_LIGHT, 0.6, 0.2 + 0.05 * sin(t * 2.0))
	else:
		n = _put(n, view, main.stair_pos, 120.0, Palette.STAIR_LIGHT, 0.45, 0.0)
	if not main.cache.is_empty() and not main.cache.get("taken", true):
		n = _put(n, view, main.cache["pos"], 150.0, Essence.color(main.cache["kind"]), 0.8, 0.25 + 0.06 * sin(t * 2.4))
	if main.campfire != null and is_instance_valid(main.campfire) and main.campfire.is_inside_tree():
		n = _put(n, view, main.campfire.global_position + Vector2(0, -10), 420.0 + 12.0 * sin(t * 4.0), Palette.TORCH, 1.0, 0.16 + 0.02 * sin(t * 6.0))
	# The puzzle's own lights: eyes, the mirrors' beam, lit stones (puzzles/).
	var pz = main.puzzle
	if pz != null:
		for l in pz.light_list():
			n = _put(n, view, l[0], l[1], l[2], l[3], l[4])
	# Torches: a slow, soft flicker (a fast one lights the floor like a failing screen).
	if rv != null:
		for torch in rv.torches:
			var ph: float = torch["phase"]
			var flick := 0.88 + 0.08 * sin(t * 7.0 + ph) + 0.04 * sin(t * 12.0 + ph * 2.0)
			n = _put(n, view, torch["pos"] + Vector2(0, torch.get("below", 20.0)), TORCH_REACH * (0.97 + 0.03 * sin(t * 5.0 + ph)), rv.torch_color, 0.85 * flick, 0.09 * flick)
	# Burning floor.
	for fl in main.flames:
		n = _put(n, view, fl["pos"], fl["r"] * 2.4, Palette.FIRE_LIGHT, 0.6 * clampf(fl["t"] / 0.5, 0.0, 1.0), 0.12)
	# Traps warning or firing glow in their colour, so the warning reads in the dark.
	var tv = main.trap_view
	if tv != null:
		for tr in main.traps:
			var st: String = tr["state"]
			if st != "warn" and st != "fire":
				continue
			var tc: Color = main.Traps.KINDS[tr["kind"]]["color"]
			n = _put(n, view, tr["pos"], tv.reach_of(tr) + 50.0, tc, 0.45 if st == "warn" else 0.7, 0.1 if st == "warn" else 0.18)
	# Anything else that registered a light.
	for id in lights.keys():
		var l: Dictionary = lights[id]
		var node = l["node"]
		if l["follows"]:
			if not is_instance_valid(node):
				lights.erase(id)
				continue
			l["pos"] = node.global_position + l["offset"]
		n = _put(n, view, l["pos"], l["r"], l["color"], l["k"], l["glow"])
	on_screen = n
	mat.set_shader_parameter("light_count", n)
	mat.set_shader_parameter("light_pos", _pos)
	mat.set_shader_parameter("light_col", _col)


## Adds one light to this frame's list if it reaches the screen and there's room.
func _put(n: int, view: Rect2, pos: Vector2, reach: float, color: Color, strength: float, glow: float) -> int:
	if n >= MAX_LIGHTS or strength <= 0.01 or reach <= 1.0:
		return n
	if pos.x < view.position.x - reach or pos.y < view.position.y - reach or pos.x > view.end.x + reach or pos.y > view.end.y + reach:
		return n
	_pos[n] = Color(pos.x, pos.y, reach, glow)
	_col[n] = Color(color.r, color.g, color.b, clampf(strength, 0.0, 1.0))
	return n + 1


## Every light reaching the screen right now, as [pos, reach] pairs (tests).
func live_lights() -> Array:
	var out: Array = []
	for i in on_screen:
		out.append([Vector2(_pos[i].r, _pos[i].g), _pos[i].b])
	return out
